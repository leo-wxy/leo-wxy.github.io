# FFmpeg 相关内容提取（来自 audio_knowledge / audio_struct）

## 来源文件

- `source/_posts/backup/audio_knowledge.md`
- `source/_posts/backup/audio_struct.md`

---

## 一、来自 `audio_struct.md` 的 FFmpeg 相关内容

### 1) 项目定位中的 FFmpeg

- 核心特性明确写到：多格式音频解码（基于 FFmpeg）。

### 2) 目录结构中的 FFmpeg 相关模块

- `cpp/CNCMFFDecoder.cpp/.h`：FFmpeg 解码器封装。
- `ext/ffmpeg/`：FFmpeg 库目录（include/lib/ncmffmpegios）。

### 3) 架构图中的 FFmpeg 位置

- Decoder Layer 中包含 `CNCMFFDecoder (FFmpeg)`。

### 4) 数据流中的 FFmpeg 位置

```text
INCMSourceIO(数据源)
  -> CNCMFFDecoder(FFmpeg 解码)
  -> CNCMAudioStream(解码管线)
  -> AudioFrame 队列
```

### 5) `CNCMAudioStream` 与 FFmpeg 的关系

- `CNCMAudioStream` 依赖：`CNCMFFDecoder`、`CNCMAudioNormlizer`、`INEAIAudioBase`。
- 核心职责之一：管理 FFmpeg 解码器（`CNCMFFDecoder`）。

### 6) `CNCMFFDecoder` 的职责（原文要点）

- 封装 FFmpeg 音频解码能力，支持 MP3/AAC/FLAC/OGG 等格式。
- 核心功能包括：
  - 音频文件打开与格式探测
  - 音频流信息获取（采样率、声道数、时长）
  - 逐帧解码
  - Seek 操作
  - 编解码器黑名单

### 7) 第三方依赖中的 FFmpeg

- 依赖表中明确：`FFmpeg` 位于 `ext/ffmpeg/`。
- 说明包含：`libavcodec`、`libavformat`、`libswresample` 等。

---

## 二、来自 `audio_knowledge.md` 的 FFmpeg 相关内容

### 1) 采样格式与 FFmpeg 输出

- `AU_SAMPLE_FMT_FLTP` 被标记为 “FFmpeg 常见输出”。
- 文档强调：
  - FFmpeg 解码常见输出为 Planar（平面）
  - AudioTrack/AudioQueue 需要 Interleaved（交错）
  - 需要通过 `CNCMAudioNormlizer` 做格式转换

### 2) 基于 FFmpeg 的时间戳换算

```cpp
int64_t pts_ms = pts * av_q2d(timeBase) * 1000;
```

### 3) FFmpeg 解码流程（原文流程）

```text
INCMSourceIO (数据源)
    -> Open / Read / Seek
CNCMFFDecoder (FFmpeg 封装)
    -> avformat_open_input
    -> avformat_find_stream_info
    -> avcodec_find_decoder
    -> avcodec_open2
    -> av_read_frame
    -> avcodec_send_packet
    -> avcodec_receive_frame
    -> CNCMAudioNormlizer (重采样/格式转换/声道转换)
    -> mAudioFrameList
```

### 4) FFmpeg 自定义 IO

- FFmpeg 可通过 `AVIOContext` 使用自定义 IO 回调。
- `CNCMFFDecoder` 把 `INCMSourceIO` 的 `Read/Seek` 注册给 FFmpeg。
- 解码器与数据来源解耦（本地/网络/加密数据源都可统一处理）。

### 5) FFmpeg 关键数据结构（深度原理篇）

```cpp
AVFormatContext *formatCtx;  // 封装格式信息
AVCodecContext *codecCtx;    // 解码器状态
AVPacket *packet;            // 压缩数据包
AVFrame *frame;              // 解码后的原始帧
```

### 6) FFmpeg 关键 API（深度原理篇）

| API | 作用 | 返回值含义 |
| --- | --- | --- |
| `av_read_frame` | 读取一个压缩包 | `0` 成功，`<0` 失败或 EOF |
| `avcodec_send_packet` | 发送包到解码器 | `EAGAIN` 表示需先 receive |
| `avcodec_receive_frame` | 获取解码帧 | `EAGAIN` 表示需更多输入 |

### 7) `EAGAIN` 处理语义（原文结论）

- `avcodec_send_packet` 返回 `EAGAIN`：解码器内部缓冲满，需要先 `receive_frame`。
- `avcodec_receive_frame` 返回 `EAGAIN`：解码器需要更多压缩数据，继续 `send_packet`。
- 属于 FFmpeg 4.x 异步解码模型，一个 packet 可能产出多个 frame。

### 8) 重采样（`SwrContext`）示例

```cpp
SwrContext *swr = swr_alloc_set_opts(NULL,
    AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16, 44100,  // 目标
    srcLayout, srcFormat, srcRate,                  // 源
    0, NULL);
swr_init(swr);
swr_convert(swr, outBuffer, outSamples, inBuffer, inSamples);
```

### 9) FFmpeg Seek 相关点

- 文档提到：`av_seek_frame` 配合 `AVSEEK_FLAG_BACKWARD` 可覆盖大部分音频 Seek 场景。
- Seek 排查中强调：
  - 时间戳单位换算要准确（毫秒/微秒/timebase）
  - 检查是否使用 `AVSEEK_FLAG_BACKWARD`
  - 确认 `avcodec_flush_buffers` 已正确调用

### 10) 与 FFmpeg 相关的工程排查清单

- 内存泄漏检查项包含：`AVFormatContext/AVCodecContext/AVFrame/AVPacket` 是否释放。
- 解码器黑名单机制（`SetBlackCodecIds`）：用于规避有缺陷的解码器实现，必要时回落软解。
