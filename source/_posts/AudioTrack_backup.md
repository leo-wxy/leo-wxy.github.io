# AudioTrack 文档备份

- 备份时间: 2026-02-17
- 原文件: `source/_posts/Android音频技术攻略-AudioTrack相关.md`
- 补充信息来源: `/Users/wxy/Downloads/归档/audio_knowledge.md`

## A. 当前文件内容快照

````markdown
---
title: Android音频技术攻略-AudioTrack相关
date: 2026-02-16 20:44:46
tags: 音视频
mermaid: true
---

## 一、文档定位

### 1.1 本篇目标

- 这篇只讲 AudioTrack 本身：概念、参数、状态、写入、时钟、排障。
- 目标是建立可复用的分析方法，而不是只记 API 名称。

### 1.2 参考边界

- `/Users/wxy/Downloads/111/Project.md` 仅作为“项目里有哪些 AudioTrack 使用点”的参考。
- 本篇主线仍是通用 AudioTrack 分析，不以项目实现细节为主叙事。

## 二、AudioTrack 在音频链路中的位置

### 2.1 音频栈关系

```mermaid
flowchart LR
  A[App/Player] --> B[AudioTrack API]
  B --> C[AudioFlinger]
  C --> D[Audio HAL]
  D --> E[输出设备]
```

- 应用层真正可控的输出入口是 `AudioTrack`。
- 混音、部分重采样、设备路由由系统层完成。

### 2.2 AudioTrack 在播放器里的职责

- 承接解码后的 PCM 数据。
- 维持稳定写入节拍，避免 underrun。
- 提供播放状态、位置和部分时钟能力，支撑进度与同步。

## 三、AudioTrack 创建参数拆解

### 3.1 `sampleRateInHz`

- 定义每秒采样点数量，常见 `44100`、`48000`。
- 设备实际工作采样率可能不同，系统可能介入重采样。

### 3.2 `channelConfig` / `channelMask`

- 定义声道布局（单声道、立体声等）。
- 声道配置与输入 PCM 不一致时，容易出现声道错位或异常静音。

### 3.3 `audioFormat`

- 常用 `ENCODING_PCM_16BIT` 和 `ENCODING_PCM_FLOAT`。
- 选择格式时要同时考虑设备支持、CPU 开销和上游处理链路。

### 3.4 `bufferSizeInBytes`

- 过小：延迟低但容易卡顿。
- 过大：稳定但时延变大，响应变慢。
- `minBufferSize` 是下限，不是最终生产值。

### 3.5 `AudioAttributes`

- 建议明确 `usage` 与 `contentType`，让系统在路由和策略上更可预期。
- 音乐场景通常使用 `USAGE_MEDIA`。

## 四、播放模式与生命周期

### 4.1 `MODE_STREAM` 与 `MODE_STATIC`

| 模式 | 场景 | 特点 |
| --- | --- | --- |
| `MODE_STREAM` | 音乐/播客/长音频 | 边生产边写入，播放器主链路常用 |
| `MODE_STATIC` | 短音效 | 一次性装载，控制简单但不适合长流 |

### 4.2 生命周期动作

- 创建并初始化。
- `play()` 开始消费缓冲。
- `pause()` 暂停但保留上下文。
- `stop()` 停止当前播放。
- `flush()` 清空待播缓存。
- `release()` 释放底层资源。

### 4.3 状态一致性

- AudioTrack 状态和播放器业务状态必须同源更新。
- 常见问题是“UI 播放中，但设备层已停”。

## 五、写入模型与线程策略

### 5.1 写入主循环

```text
decoder/process output PCM
  -> writer thread fetch chunk
  -> AudioTrack.write(...)
  -> check written bytes
  -> continue/retry/sleep by policy
```

### 5.2 阻塞与非阻塞

- 阻塞写：逻辑简单，但可能拉长写线程等待时间。
- 非阻塞写：更灵活，但更依赖上层调度与重试策略。

### 5.3 短写处理

- 短写不一定是错误，核心是后续补写与节拍维护。
- 推荐记录 `requested`、`written`、`costMs` 三个指标。

### 5.4 underrun 风险点

- 上游解码速度跟不上。
- 写入线程被锁竞争或调度延迟阻塞。
- 缓冲配置激进且缺少动态调节。

## 六、时钟、进度与延迟

### 6.1 三类常见时间概念

- 解码时间：上游帧时间戳。
- 写入时间：应用提交给 AudioTrack 的时间。
- 播放时间：设备真实发声对应时间。

### 6.2 为什么“写入进度”不等于“发声进度”

- 中间存在系统缓冲、混音队列和硬件路径。
- 路由变化或设备切换时，时间偏差会被放大。

### 6.3 延迟分析建议

- 分层看延迟：应用缓冲 + AudioTrack 阻塞 + 系统输出链路。
- 先定性“哪一层抖动”，再做定量优化。

## 七、路由切换与恢复策略

### 7.1 高频切换场景

- 有线耳机插拔。
- 蓝牙断连/重连。
- 前后台切换触发的系统路由调整。

### 7.2 `flush` 还是重建

| 情况 | 处理建议 |
| --- | --- |
| 参数未变，仅短暂中断 | 可优先 `pause/flush` 后续播 |
| 采样率/声道/格式或设备能力变化 | 优先重建 AudioTrack |
| 出现持续无声或状态异常 | 重建并重置关键状态 |

### 7.3 恢复链路一致性

- 先确定路由与设备状态。
- 再恢复写入和播放器状态。
- 最后同步 UI、通知、会话状态。

## 八、常见问题排查小节

### 8.1 无声但进度在走

- 查路由是否已变更。
- 查参数是否匹配（采样率/声道/格式）。
- 查写入是否长期短写或写入中断。

### 8.2 爆音/破音

- 查切歌点是否缺少 `flush` 或重建。
- 查混音或淡入淡出边界处理。

### 8.3 卡顿与延迟抖动

- 查写线程阻塞分布。
- 查缓冲块大小是否与机型能力匹配。

### 8.4 路由恢复慢

- 查是否仍向旧设备写入。
- 查重建后状态恢复是否完整。

## 九、项目使用点参考映射（辅助）

| 参考点 | 项目体现 | 本篇对应知识 |
| --- | --- | --- |
| AudioTrack 封装 | `device/Android/audio_track.cpp/.h` | 生命周期、写入线程、状态流转 |
| JNI AudioTrack 桥接 | `device/Android/audio_device_android_audiotrack.cpp/.h` | 参数映射、调用边界 |
| 设备类型选择 | `SetAudioDeviceType(AudioDeviceType_AudioTrack)` | 路由策略与重建设计 |
| AudioTrack 引用透出 | `GetAudioTrack()` | Session 与扩展能力调试 |
| 延迟查询 | `GetAudioLatence()` | 延迟观测与进度校准 |
| 设备变化消息 | `AMsgAudioTrackChanged` | 切换时序与恢复流程 |

## 十、学习节奏建议（按小节打卡）

### 10.1 第一阶段：建模

- 先掌握第 2、3、4 节，形成 AudioTrack 参数与状态心智模型。

### 10.2 第二阶段：实战

- 按第 5、6、7 节做两组实验：缓冲调优、路由切换回归。

### 10.3 第三阶段：排障

- 用第 8 节 SOP 处理真实问题，沉淀故障案例库。

## 十一、小结

本篇先把 AudioTrack 分析框架立住，再用项目里的使用点做映射验证。这样既不丢通用性，也能直接落到你当前内核的工程实践。
````

## B. 待补充信息（AudioTrack 相关）

以下内容来自 `/Users/wxy/Downloads/归档/audio_knowledge.md`，已筛选出 AudioTrack 强相关点，供后续改稿直接使用。

### B1. 直接章节

- `audio_knowledge.md:934` - `11.3 Android AudioTrack`（Buffer 大小、经验值）
- `audio_knowledge.md:1125` - `13.2 Android AudioTrack 深入`（架构、延迟、underrun）
- `audio_knowledge.md:1147` - `AudioTrack Underrun 检测`（`write` 返回值判定）

### B2. 强关联知识点

- `audio_knowledge.md:93` - `RenderThread -> BufferFill -> AudioTrack.write`
- `audio_knowledge.md:255` - Pull 模型链路：`AudioDevice -> BufferFill -> Player`
- `audio_knowledge.md:475` - AudioTrack 需要 Interleaved，需处理 Planar 转换
- `audio_knowledge.md:939` - `AudioTrack.getMinBufferSize(...)` 参数选择
- `audio_knowledge.md:949` - 总延迟拆解：App Buffer + AudioTrack Buffer + AudioFlinger + HAL
- `audio_knowledge.md:133` - 路由变化可能重建 AudioTrack
- `audio_knowledge.md:978` - 蓝牙切换场景的重建/恢复逻辑
- `audio_knowledge.md:963` - USB 失败回退到 AudioTrack

### B3. 可补充到正文的小节建议

1. `AudioTrack Buffer 调优策略`：`minBuffer` 下限、`x2/x4` 经验值及适用场景。
2. `Underrun 观测指标`：`requested/written/costMs` 统一日志结构。
3. `路由切换时机`：`flush` 与重建的判定条件及恢复顺序。
4. `时钟与延迟分层`：上层写入时间与真实发声时间的偏差来源。
5. `格式边界`：Planar/Interleaved、采样率和声道变更时的重配置策略。
