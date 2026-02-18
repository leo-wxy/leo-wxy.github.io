---
title: Android音频技术攻略-FFmpeg相关
date: 2026-02-16 20:45:02
tags: 音视频
mermaid: true
---

FFmpeg 是一个开源跨平台多媒体框架，提供音视频的解封装、编解码、转码与流媒体处理能力。
待实现大纲（能力 → FFmpeg 知识点）

文档边界与能力清单
只聚焦 FFmpeg 能力：多格式解码、自定义数据源、重采样、时间线、Seek/FastSeek、稳定性、性能与裁剪。


多格式音频播放需要的 FFmpeg 基础
容器 vs 编码格式、demuxer/decoder/parser/protocol 的关系。
avformat_open_input、avformat_find_stream_info、av_find_best_stream 的职责与坑点。


自定义数据源能力（网络/加密/非标准来源）
AVIOContext 回调模型（read/seek）。
可随机访问能力与快速拖动能力的关系（是否可 FastSeek）。


稳定解码能力（核心 API 模式）
avcodec_send_packet / avcodec_receive_frame 标准范式。
EAGAIN / EOF 语义与正确处理。
drain、flush、异常恢复的基本规则。

PCM 统一输出能力（重采样与重排）
SwrContext、swr_alloc_set_opts2、swr_convert。
采样率/声道/sample_fmt 统一策略。
Planar vs Interleaved（FLTP/S16P -> S16）与常见杂音根因。

时间线与进度能力
PTS/DTS/time_base 基本概念与换算。
best_effort_timestamp 的使用场景。
音频进度计算与误差来源。

Seek 与 FastSeek 能力
av_seek_frame vs avformat_seek_file。
AVSEEK_FLAG_BACKWARD 的实战意义。
快速拖动与精确定位的二段式策略（拖动中快、松手后准）。
MP3 VBR 的 Xing/VBRI 对定位精度影响。

连续播放与切换平滑能力（FFmpeg 侧）
编码延迟/填充样本（gapless 关键知识）。
seek 后首帧爆音、时间跳变的 FFmpeg 侧处理点。

兼容性与降级能力
解码器不兼容场景与黑名单思路。
不支持格式、损坏流、参数异常时的降级策略。

可观测性与排障能力（FFmpeg 维度）
最小日志字段：codec/sample_rate/sample_fmt/ch_layout/pts/error code。
典型问题定位：无声、杂音、卡顿、Seek 偏移。
内存与生命周期能力
AVFormatContext/AVCodecContext/AVPacket/AVFrame/SwrContext 的创建/复用/释放。
正常路径与异常路径都要覆盖释放。

移动端交付能力（体积与性能）
--disable-everything 按需启用策略。
组件最小集合（音频常用格式）与版本兼容点（如 AVChannelLayout 迁移）。


## 导读：实现播放能力所需的 FFmpeg 能力地图（合并版）

> 本节按“能力 -> FFmpeg 知识点”组织，合并自 `audio_knowledge.md` 与 `audio_struct.md` 的 FFmpeg 相关内容，用于指导正文落地。

### 必需能力（实现可用播放器的最小集合）

| 能力 | 必须掌握的 FFmpeg 知识点 | 关键 API/组件 |
| --- | --- | --- |
| 多格式音频解码 | 容器与编码的关系、音频流选择、解码循环 | `avformat_open_input` `av_find_best_stream` `avcodec_send_packet/receive_frame` |
| 自定义数据源接入 | 回调式读写与随机访问能力 | `AVIOContext` `read/seek` 回调 |
| PCM 统一输出 | 采样率/声道/sample_fmt 统一、planar 转 packed | `SwrContext` `swr_alloc_set_opts2` `swr_convert` |
| 时间线与进度 | `PTS/time_base` 换算与进度误差控制 | `av_q2d` `best_effort_timestamp` |
| Seek/FastSeek | 回退 seek、flush、快拖与精确定位二段式 | `av_seek_frame` `AVSEEK_FLAG_BACKWARD` `avcodec_flush_buffers` |
| 稳定性与资源管理 | 返回码语义、异常恢复、对象生命周期 | `EAGAIN/EOF`、`AVFormatContext/AVCodecContext/AVPacket/AVFrame` |

### 增强能力（提升体验与线上稳定性）

| 能力 | 关键知识点 | 典型收益 |
| --- | --- | --- |
| 精准 Seek 体验 | MP3 VBR 的 Xing/VBRI 索引影响定位精度 | 拖动定位更准，回弹更少 |
| 兼容性降级 | 解码器黑名单与软解回退策略 | 降低机型相关崩溃/异常 |
| 可观测性 | 解码、重采样、渲染三段最小日志 | 线上问题定位路径更短 |
| 体积与性能交付 | `--disable-everything` 按需裁剪组件 | 降低 so 体积，减少冷启动成本 |

### 能力与正文映射（如何阅读本篇）

1. 先看“三、解复用与解码主流程”拿到解码主链路。
2. 再看“四、重采样与格式统一”解决可播 PCM 输出。
3. 接着看“五、时间戳、音频时钟与 Seek”打通进度与拖动。
4. 最后看“七、常见线上问题”与“九、面试问题补充”形成排障闭环。

## 一、FFmpeg 在 Android 音频链路中的定位

### 1.1 先回答一个核心问题：FFmpeg 到底负责什么

- 在播放器里，FFmpeg 主要负责**解封装、解码、重采样/格式转换**。
- Android 系统侧（`AudioTrack/AudioFlinger/HAL`）主要负责**混音、路由、设备输出**。
- 因此 FFmpeg 是“把压缩音频变成可播 PCM”的中间层，而不是最终发声层。

### 1.2 典型链路图

```mermaid
flowchart LR
  A[网络/本地文件] --> B[avformat_open_input]
  B --> C[Demux: AVPacket]
  C --> D[Decode: AVFrame]
  D --> E[SwrContext 重采样/重排]
  E --> F[PCM Queue]
  F --> G[AudioTrack write]
  G --> H[AudioFlinger/HAL]
  H --> I[Speaker/Bluetooth/Headset]
```

### 1.3 模块边界（排障时非常有用）

| 分层 | 核心职责 | 常见问题 | 排查入口 |
| --- | --- | --- | --- |
| FFmpeg Demux/Decode | 产出音频帧（`AVFrame`） | 无帧、PTS 异常、解码错误 | `av_read_frame/send_packet/receive_frame` 返回码 |
| Swresample | 输出统一 PCM 格式 | 音调异常、杂音、声道错位 | `swr_init/swr_convert` 参数 |
| AudioTrack | 消费 PCM 并播放 | 卡顿、无声、短写 | `write` 返回值、`getPlayState` |
| 系统路由层 | 路由与设备输出 | 蓝牙切换后无声 | 路由回调与重建时序 |

## 二、Android 集成 FFmpeg：编译与裁剪

### 2.1 为什么要裁剪

- 默认全量 FFmpeg 体积大、冷启动慢、无关编解码器太多。
- 移动端建议按业务场景裁剪，只保留需要的 demuxer/decoder/parser/protocol。

### 2.2 典型裁剪思路

| 目标 | 推荐策略 |
| --- | --- |
| 减少 so 体积 | `--disable-everything` 后按需 `--enable-*` |
| 保留常见音频 | 启用 `aac/mp3/flac/opus` 对应 decoder + demuxer |
| 降低符号暴露 | 结合 `-fvisibility=hidden` 与 strip |
| 避免无用网络协议 | 只开 `file/http/https`（按业务） |

### 2.3 常见 configure 片段（示例）

```bash
./configure \
  --target-os=android \
  --arch=arm64 \
  --enable-cross-compile \
  --cross-prefix=aarch64-linux-android- \
  --cc=$CC \
  --sysroot=$SYSROOT \
  --disable-programs \
  --disable-doc \
  --disable-everything \
  --enable-avformat \
  --enable-avcodec \
  --enable-swresample \
  --enable-protocol=file,http,https \
  --enable-demuxer=mov,mp3,flac,ogg,wav,aac \
  --enable-decoder=aac,mp3,flac,opus,pcm_s16le \
  --enable-parser=aac,mpegaudio,opus
```

- 这个片段仅用于思路示例，真实配置要结合你们线上格式覆盖率。

## 三、解复用与解码主流程

### 3.1 核心对象速查

| 对象 | 作用 | 生命周期建议 |
| --- | --- | --- |
| `AVFormatContext` | 输入源与流信息 | 会话级，播放结束统一释放 |
| `AVCodecContext` | 解码器上下文 | 音轨级，切轨/重建时释放 |
| `AVPacket` | 压缩包（demux 输出） | 循环复用，`av_packet_unref` |
| `AVFrame` | 解码后音频帧 | 循环复用，`av_frame_unref` |
| `SwrContext` | 重采样/格式转换 | 参数变更时重建 |

### 3.2 打开输入并初始化音频解码器

```cpp
AVFormatContext* fmt = nullptr;
int ret = avformat_open_input(&fmt, url, nullptr, nullptr);
if (ret < 0) return ret;

ret = avformat_find_stream_info(fmt, nullptr);
if (ret < 0) return ret;

int aidx = av_find_best_stream(fmt, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
if (aidx < 0) return aidx;

AVStream* astream = fmt->streams[aidx];
const AVCodec* dec = avcodec_find_decoder(astream->codecpar->codec_id);
if (!dec) return AVERROR_DECODER_NOT_FOUND;

AVCodecContext* dec_ctx = avcodec_alloc_context3(dec);
if (!dec_ctx) return AVERROR(ENOMEM);

ret = avcodec_parameters_to_context(dec_ctx, astream->codecpar);
if (ret < 0) return ret;

ret = avcodec_open2(dec_ctx, dec, nullptr);
if (ret < 0) return ret;
```

### 3.3 `send_packet/receive_frame` 标准循环

```cpp
AVPacket* pkt = av_packet_alloc();
AVFrame* frame = av_frame_alloc();

while (av_read_frame(fmt, pkt) >= 0) {
    if (pkt->stream_index != aidx) {
        av_packet_unref(pkt);
        continue;
    }

    ret = avcodec_send_packet(dec_ctx, pkt);
    av_packet_unref(pkt);
    if (ret < 0) {
        // send 失败通常是参数/状态异常，记录后按策略恢复
        continue;
    }

    while (true) {
        ret = avcodec_receive_frame(dec_ctx, frame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) break;

        // frame -> swr_convert -> PCM queue
        av_frame_unref(frame);
    }
}

// drain：文件读完后继续拉残留帧
avcodec_send_packet(dec_ctx, nullptr);
while (avcodec_receive_frame(dec_ctx, frame) >= 0) {
    // drain frames
    av_frame_unref(frame);
}
```

### 3.4 返回码处理建议

| 返回码 | 含义 | 处理动作 |
| --- | --- | --- |
| `AVERROR(EAGAIN)` | 当前阶段暂时不可继续 | 回到外层循环继续喂数据 |
| `AVERROR_EOF` | 解码器无更多输出 | 进入结束态 |
| `< 0` 其他错误 | 参数/状态/数据损坏 | 上报 + 降级或重建 |

## 四、重采样与格式统一（`swresample`）

### 4.1 为什么必须做格式统一

- 上游解码输出的 `sample_fmt/sample_rate/ch_layout` 不稳定。
- 下游 `AudioTrack` 更希望固定参数（例如 `48kHz + Stereo + PCM_16BIT`）。
- 统一参数后，播放链路更稳定，排障也更容易。

### 4.2 建议的输出 PCM 目标

| 场景 | 输出采样率 | 输出声道 | 输出格式 |
| --- | --- | --- | --- |
| 音乐/视频通用 | `48000` | `2`（stereo） | `AV_SAMPLE_FMT_S16` |
| 低延迟语音 | `16000` 或 `48000` | `1`（mono） | `AV_SAMPLE_FMT_S16` |
| 高精度处理链路 | 视设备能力 | `2` | `AV_SAMPLE_FMT_FLT`（谨慎） |

### 4.3 `swr_alloc_set_opts2` 初始化示例

```cpp
SwrContext* swr = nullptr;
AVChannelLayout dst_ch_layout;
av_channel_layout_default(&dst_ch_layout, 2); // stereo

ret = swr_alloc_set_opts2(
    &swr,
    &dst_ch_layout,
    AV_SAMPLE_FMT_S16,
    48000,
    &dec_ctx->ch_layout,
    dec_ctx->sample_fmt,
    dec_ctx->sample_rate,
    0,
    nullptr);
if (ret < 0) return ret;

ret = swr_init(swr);
if (ret < 0) return ret;
```

> FFmpeg 5/6 推荐使用 `AVChannelLayout`，旧版本常见 `channel_layout`（`uint64_t`）字段。

### 4.4 输出样本数与字节数计算

```cpp
int dst_nb_samples = av_rescale_rnd(
    swr_get_delay(swr, dec_ctx->sample_rate) + frame->nb_samples,
    48000,
    dec_ctx->sample_rate,
    AV_ROUND_UP);

int dst_buf_size = av_samples_get_buffer_size(
    nullptr,
    2,
    dst_nb_samples,
    AV_SAMPLE_FMT_S16,
    1);
```

- 不要直接用 `frame->nb_samples` 当输出长度，必须把 `swr_get_delay` 一起考虑。

### 4.5 Planar 与 Packed 的常见坑

| 输入格式 | 内存布局 | 易错点 |
| --- | --- | --- |
| `FLTP`（planar） | 每个声道独立平面 | 误当交错数据写给 AudioTrack，导致杂音 |
| `S16`（packed） | LRLR 交错 | 声道数计算错误导致长度错位 |

## 五、时间戳、音频时钟与 Seek

### 5.1 PTS 转秒公式

- `ptsSec = frame->best_effort_timestamp * av_q2d(stream->time_base)`
- 若 `pts` 缺失，可退化使用“已播放样本数”构建音频时钟。

### 5.2 音频时钟常见实现

`audioClockSec = writtenSamples / sampleRate`

- `writtenSamples` 指已送入渲染链路并确认消费的样本数。
- 音画同步通常以音频时钟为主时钟（尤其是视频可丢帧的场景）。

### 5.3 Seek 推荐流程

| 步骤 | 动作 | 目的 |
| --- | --- | --- |
| 1 | `av_seek_frame/avformat_seek_file` | 跳到目标时间附近 |
| 2 | `avcodec_flush_buffers` | 清空解码器旧状态 |
| 3 | 清空 PCM 队列 + `AudioTrack.flush` | 丢弃旧音频残留 |
| 4 | 从新位置重新解码 | 建立新的时间线 |

- Seek 后第一批帧可做“轻量丢弃策略”（例如丢到最近关键时间点）减少爆音概率。

### 5.4 FastSeek（快速拖动）策略

- `FastSeek` 的目标是“拖动时先快到附近”，不追求一次命中绝对精确采样点。
- 常见做法是先走快速路径保障响应，拖动结束后再补一次精确 seek。

| 维度 | FastSeek（快速） | Accurate Seek（精确） |
| --- | --- | --- |
| 用户体验 | 拖动反馈快 | 命中更准 |
| 代价 | 精度可能偏差几十到几百 ms | 解码/定位成本更高 |
| 适用场景 | 进度条持续拖动中 | 手指松开后最终定位 |

| 常见实现点 | 说明 |
| --- | --- |
| `INCMSourceIO.SupportFastSeek()` | 数据源声明是否支持快速跳转 |
| `av_seek_frame + AVSEEK_FLAG_BACKWARD` | 先跳到较稳妥的可解码位置 |
| 二段式策略 | 拖动中 fast，松手后 accurate |

```text
onSeekDragging(targetMs):
  if source.SupportFastSeek():
    fastSeek(targetMs)    // 低成本、快速响应
  else:
    throttle + normalSeek // 限频避免频繁重定位

onSeekRelease(targetMs):
  accurateSeek(targetMs)  // 最终精确定位
```

- 对 MP3 VBR 场景，是否有 Xing/VBRI 索引会直接影响快进定位精度。
- 若网络源不支持稳定的随机访问（range/缓存不足），FastSeek 容易退化成高抖动普通 seek。

## 六、FFmpeg 与 AudioTrack 对接实践

### 6.1 推荐线程模型

| 线程 | 主要职责 | 关键指标 |
| --- | --- | --- |
| Demux 线程 | `av_read_frame` 拉流/读文件 | 读取耗时、队列积压 |
| Decode 线程 | `send/receive + swr_convert` | 解码耗时、转换耗时 |
| Render 线程 | `AudioTrack.write` | `requested/written/writeCostMs` |

### 6.2 队列水位建议

| 水位 | 典型阈值（示例） | 动作 |
| --- | --- | --- |
| 低水位 | `< 40ms` PCM | 优先补帧，必要时短暂等待 |
| 目标水位 | `80~150ms` PCM | 平衡延迟与稳定 |
| 高水位 | `> 300ms` PCM | 限速解码或丢弃过旧数据 |

### 6.3 JNI/内存拷贝建议

- 优先复用 native PCM 缓冲，避免每帧重复 malloc/free。
- Java 层可优先 `ByteBuffer` 直传，减少额外拷贝。
- `write` 异常（尤其 `ERROR_DEAD_OBJECT`）时直接走重建路径，不在旧实例无限重试。

## 七、常见线上问题与定位手册

### 7.1 问题总表

| 现象 | 高概率根因 | 快速检查点 | 处理动作 |
| --- | --- | --- | --- |
| 进度在走但无声 | 路由错位/会话失效 | `write` 是否成功、当前 route 是否正确 | `stop -> flush -> release -> recreate` |
| 声音变尖/变慢 | 重采样参数错配 | `src_rate/dst_rate` 与时钟是否一致 | 修正 `swr` 参数并重建 |
| 爆音/杂音 | planar/packed 处理错误 | `sample_fmt` 与写入格式是否匹配 | 统一输出 `S16 packed` |
| 周期性卡顿 | `write` 阻塞或供数不足 | `fillCostMs` vs `writeCostMs` | 调整 buffer + 补写策略 |
| Seek 后短暂异响 | 旧缓冲未清 | 是否执行 `flush_buffers + AudioTrack.flush` | 严格执行 seek 清理流程 |

### 7.2 最小化日志字段（强烈建议）

- 解码层：`codec/sample_rate/sample_fmt/ch_layout/pts`。
- 重采样层：`src->dst 参数`、`dst_nb_samples`、`convert_cost_ms`。
- 渲染层：`requested/written/write_cost_ms/play_state/route`。
- 会话层：`sessionId/contentId/seek_target/focus_state`。

## 八、工程落地清单（可直接对照）

- 解码链路统一 `send/receive` 模式，禁用历史旧 API 习惯写法。
- 输出 PCM 参数固定一套默认值（建议 `48k + stereo + S16`）并支持降级。
- Seek、路由切换、`ERROR_DEAD_OBJECT` 三类场景统一走“清理 + 重建”模板。
- 指标先落地再优化：没有 `fillCostMs/writeCostMs` 就很难有效排障。
- 裁剪 FFmpeg 组件并持续回看线上格式覆盖率，避免功能和体积失衡。

## 九、FFmpeg 面试问题补充（来自 `audio_knowledge.md`）

### 9.1 问题：Interleaved 和 Planar 格式有什么区别？

- Interleaved（交错）常见布局是 `L R L R ...`，这是 `AudioTrack/AudioQueue` 更常见的消费形态。
- Planar（平面）常见布局是 `L L L ...` 与 `R R R ...` 分平面存储，这在 FFmpeg 解码输出中很常见。
- 工程上通常需要在解码后做一次格式归一化（如 `FLTP -> S16 interleaved`），再送渲染层。

### 9.2 问题：FFmpeg 如何从自定义数据源（网络/加密文件）读取？

- 使用 `AVIOContext` 挂接自定义 `read/seek` 回调。
- 在项目实现里，`CNCMFFDecoder` 会把 `INCMSourceIO` 的 `Read/Seek` 注册给 FFmpeg。
- 这样可把“数据来源”和“解码器”解耦，统一支持本地、网络、加密源。

### 9.3 问题：简述 FFmpeg 解码主流程。

```text
INCMSourceIO
  -> avformat_open_input
  -> avformat_find_stream_info
  -> avcodec_find_decoder
  -> avcodec_open2
  -> av_read_frame
  -> avcodec_send_packet
  -> avcodec_receive_frame
  -> 格式归一化/重采样
  -> PCM 队列
```

### 9.4 问题：`avcodec_send_packet` 和 `avcodec_receive_frame` 返回 `EAGAIN` 分别怎么处理？

- `send_packet` 返回 `EAGAIN`：说明解码器内部缓冲区当前“偏满”，要先 `receive_frame` 把可取帧拉出来。
- `receive_frame` 返回 `EAGAIN`：说明当前输入不够，需要继续 `send_packet` 喂更多压缩数据。
- 这是异步解码模型的常态，一个 `packet` 可能对应多个 `frame`。

### 9.5 问题：`SetBlackCodecIds` 是什么作用？

- 用于屏蔽已知有问题的解码器实现（常见于机型差异带来的硬解异常）。
- 命中黑名单后走可用替代路径（例如软解），优先保证稳定可播。
- 这类黑名单通常支持服务端下发，减少发版修复成本。

### 9.6 问题：音频 Seek 有“关键帧”概念吗？

- MP3/AAC/FLAC 在可定位能力和边界处理上存在差异，工程实现通常统一依赖 FFmpeg 的 seek 能力。
- 实战中常用 `av_seek_frame + AVSEEK_FLAG_BACKWARD` 作为稳妥默认策略。

### 9.7 问题：Seek 后播放位置不准确，优先排查什么？

1. 时间戳单位是否换算正确（毫秒/微秒/`time_base`）。
2. 是否使用了 `AVSEEK_FLAG_BACKWARD`。
3. `flush` 后是否还残留 priming 样本影响起播点。
4. 解码器、处理器、设备缓冲是否都完成清理。
5. 播放时钟是否已按新位置重置。

### 9.8 问题：Seek 后有杂音怎么处理？

- 首帧可加极短淡入，降低切点不连续导致的爆音感。
- 确保 `avcodec_flush_buffers` 在 seek 后正确执行。

### 9.9 问题：FFmpeg 相关内存泄漏如何做最小化自检？

- 重点检查对象：`AVFormatContext`、`AVCodecContext`、`AVPacket`、`AVFrame`。
- 确保异常分支和中断分支也走释放路径，不只覆盖“正常结束”路径。

### 9.10 问题：FastSeek 是什么？和普通 Seek 的差异是什么？

- FastSeek 核心是“速度优先”：先快速跳到接近位置，允许短暂误差。
- 普通 Seek 核心是“精度优先”：定位更准，但代价更高、响应更慢。
- 实战建议采用二段式：拖动过程 FastSeek，松手后再做一次精确 Seek 收敛。

### 9.11 问题：`SupportFastSeek()` 在工程里怎么用？

- 它是数据源能力开关：告诉播放器当前 source 是否适合快速跳转。
- 返回 `true`：可走高频拖动 seek 路径，增强交互流畅度。
- 返回 `false`：应降级为限频 seek 或松手后再 seek，避免频繁抖动与无效跳转。

### 9.12 问题：FastSeek 体验差时优先排查哪些点？

1. 数据源是否真的支持随机访问（`SupportFastSeek` 能力与实际一致性）。
2. 是否使用了稳妥的 seek flag（如 `AVSEEK_FLAG_BACKWARD`）。
3. 音频格式是否缺少有效索引（如 MP3 VBR 缺失 Xing/VBRI）。
4. 拖动过程是否做了节流/去抖，避免每个像素位移都触发重定位。
5. seek 后清理链路是否完整（解码器/队列/设备缓冲是否都 reset）。
