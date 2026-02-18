# NCM Audio Player 面试知识点

基于 Project.md 整理的面试知识点清单，涵盖架构设计、多线程、音频基础、高级特性等核心技术。

---

## 1. 架构设计类

### 1.1 跨平台架构设计

**问题**: 如何设计一个支持 Android/iOS/macOS 的跨平台音频引擎？

**答案要点**:
- 核心逻辑用 C++ 实现，保证代码复用
- 平台接口层分离：Android 用 JNI，iOS/Mac 用 ObjC++
- 音频设备抽象：定义 `AudioDevice` 基类，各平台实现子类
- 数据源抽象：`INCMSourceIO` 接口屏蔽文件/网络差异
- 工厂模式创建：`CMediaPlayerFactory` 创建播放器，`CAudioDeviceFactory` 创建设备

### 1.2 分层架构设计

```
Application Layer (App)
       ↓
Platform Interface Layer (JNI / ObjC++)
  - AndroidAudioPlayer / NTESMAudioPlayer
  - AudioSourceAndroid / CNTESMSource
       ↓
Core Engine Layer (C++)
  - CNCMAudioPlayer (状态机 + 双线程调度)
  - CNCMAudioStream (解码管线)
  - CNCMAudioProcess (音效/变速/淡入淡出)
  - CNCMAudioTimeInfo (时间管理)
  - CNCMAudioNormlizer (格式归一化)
       ↓
Device Layer (平台音频输出)
  - Android: AudioTrack / USBAudioDevice
  - iOS: AudioQueue / AudioBufferRender
  - Mac: NTESMAudioOutputDevice
```

**设计原则**:
- 上层依赖下层，下层不依赖上层（通过 Observer 回调）
- 通过抽象接口解耦，便于单元测试和平台扩展
- 平台相关代码隔离在 Interface 和 Device 层

### 1.3 核心接口抽象

| 接口 | 职责 | 关键方法数 | 设计意图 |
|------|------|-----------|----------|
| `INCMPlayer` | 播放器控制 | 50+ | 统一播放 API |
| `INCMSourceIO` | 数据源读取 | 14 | 屏蔽文件/网络差异 |
| `AudioDevice` | 音频输出 | 30+ | 屏蔽平台差异 |
| `INCMPlayerObserver` | 播放器事件回调 | 1 | 上层事件通知 |
| `INCMStreamObserver` | 解码流事件回调 | 5 | 缓冲/Seek 通知 |
| `INCMProcessObserver` | 处理器事件回调 | 3 | 淡入淡出/数据拉取 |
| `INCMDeviceObserver` | 设备事件回调 | 4 | 设备数据拉取/错误 |

### 1.4 三路数据源并行架构

**问题**: 为什么播放器要同时持有三个数据源和三个解码流？

```
mSource / mAudioStream          ← 当前播放
mPreSource / mAudioPreLoadStream ← Gapless 预加载下一首
mFadeSource / mAudioFadeStream   ← CrossFade 淡入淡出
```

**答案**:
- **mSource**: 当前正在播放的歌曲
- **mPreSource**: 无缝播放时预加载的下一首，减少切歌间隔
- **mFadeSource**: CrossFade 时旧歌曲的数据源，需要同时解码两首歌
- 三路使用 `unique_ptr` 管理生命周期，独立锁保护（mLockStream/mLockSource）

**追问**: CrossFade 时内存是不是翻倍？如何控制？
- 是的，会同时有两个解码实例和帧队列
- 通过限制 CrossFade 缓存时长控制内存上限
- CrossFade 结束后及时释放旧数据源


---

## 2. 多线程与消息系统

### 2.1 五线程模型

```
主线程 (App)          → API 调用入口（SetDataSource, Play, Pause 等）
MsgThread (事件通知)  → PlayerNotifyEvent, 位置通知, 缓冲状态
ControlThread (控制)  → doInitStart, doPrepareAsync, doPlay, doStop, doSeek
DecThread (解码)      → doDecoder, doSeek, AI超分处理
ProcessThread (处理)  → processAudio, processFade, TempoProcessor
RenderThread (渲染)   → BufferFill 回调, AudioTrack.write / AudioQueue 回调
```

**问题**: 为什么需要分 MsgThread 和 ControlThread 两个线程？

**答案**:
- **ControlThread** 处理耗时控制操作（PrepareAsync 需要打开文件、解析格式；DeviceOpen 需要初始化硬件）
- **MsgThread** 负责向上层发送事件通知，保证回调在固定线程
- 如果合并，耗时操作会阻塞事件通知，上层收不到及时回调
- 两线程分离体现了 **命令执行与事件通知分离** 的设计原则

**追问**: 如果 ControlThread 的 doPlay 还没执行完，用户又点了 Pause，怎么办？

**答案**:
- ControlThread 基于消息队列（CNCMMsgThread），Play 和 Pause 都是消息
- 消息按顺序投递，先执行 doPlay 再执行 doPause
- 通过 `mLockControl` 互斥锁保证控制操作的原子性

### 2.2 消息系统详解

**问题**: 描述播放器的消息分类体系。

| 类别 | 消息范围 | 线程归属 | 代表消息 |
|------|----------|----------|----------|
| 播放器事件 | 1-8 | MsgThread | AMsgPlayPrepared, AMsgPlayEOS, AMsgFristFrame |
| 控制命令 | 10-28 | ControlThread | AMsgPlaying, AMsgPause, AMsgSeeking |
| 解码器 | 50-52 | DecThread | AMsgDecoder, AMsgDecSeek, AMsgDecIF |
| 音频处理 | 60-62 | ProcessThread | AMsgProcess, AMsgProcessFlush |
| 渲染 | 80-82 | RenderThread | AMsgRender, AMsgRenderFlush, AMsgRenderPause |
| 错误 | 100-101 | MsgThread | AMsgError, AMsgFrameError |
| 性能监控 | 800-3002 | MsgThread | AMsgDecFrameTime, AMsgAudioRenderLagTime |
| USB 异常 | 5000-5001 | MsgThread | AMsgAudioUSBTransferTimeout |

**问题**: AMsgHeadSetChanged (26) 消息的完整处理流程是什么？

**答案**:
1. Android 层检测到耳机插拔事件
2. 通过 JNI 调用 `SetHeadSetType(headSetType)`
3. 投递 `AMsgHeadSetChanged` 到 ControlThread
4. `doHeadSetChanged()` 处理：
   - 蓝牙耳机：可能需要重新创建 AudioTrack（采样率/编码格式变化）
   - 有线耳机：暂停播放（Android 系统行为）
5. 如果设备重建，投递 `AMsgAudioDeviceChanged` 通知上层

### 2.3 CNCMMsgThread 消息线程实现

**问题**: CNCMMsgThread 的核心实现原理？

**答案**:
- 内部维护一个消息队列（`std::list<shared_ptr<ThreadMsg>>`）
- 使用条件变量（CNCMCondition）实现等待/唤醒
- PostMsg 向队列添加消息并唤醒线程
- 线程循环取出消息，调用回调函数处理
- 支持设置线程优先级（解码线程需要较高优先级）

```cpp
// 消息投递模型
void PostMsg(int msgType, int arg1 = 0, int arg2 = 0) {
    auto msg = make_shared<ThreadMsg>(msgType, arg1, arg2);
    mQueue.push_back(msg);
    mCondition.Signal();  // 唤醒等待线程
}

// 消息处理循环
while (!mStop) {
    shared_ptr<ThreadMsg> msg = WaitForMsg();  // 条件变量等待
    mCallback(mObj, msg);  // 回调处理
}
```

### 2.4 生产者-消费者模型

```
[DecThread] ──生产──▶ [mAudioFrameList 帧队列] ──消费──▶ [ProcessThread]
                              │                                │
                         mListLock 保护                     mListLock 保护
                              │                                │
                      getAudioFrame()                    [mAudioFrameList]
                      freeAudioFrameList()                     │
                                                     ──消费──▶ [RenderThread]
                                                         BufferFill() 回调
```

**问题**: 帧队列满了或空了分别怎么处理？

**答案**:
- **队列满** (缓冲超过 `CACHE_PACKAGE_DURATION_MAX` 7000ms)：
  - 解码线程通过 `doCheckStatus()` 检查
  - 暂停解码，等待消费者消费后继续
- **队列空** (缓冲低于 `CACHE_BUFFERING_MIN_DURATION` 1000ms)：
  - 触发 `BufferStart` 回调
  - 上报 `AMsgBufferingInfo (MEDIA_INFO_BUFFERING_START = 701)` 到上层
  - 进入 Buffering 状态，UI 显示加载中
  - 缓冲恢复到 `CACHE_BUFFERING_POP_DURATION` 1500ms 后触发 `BufferEnd`

### 2.5 线程同步机制

| 锁 | 保护对象 | 使用场景 |
|------|----------|----------|
| `mLockStatus` | mStatus (播放状态) | 状态读写 |
| `mLockControl` | 控制操作 | Play/Pause/Stop 互斥 |
| `mLockParams` | 参数设置 | 音量/速度等参数 |
| `mLockStream` | mAudioStream | 解码流操作 |
| `mLockSource` | mSource | 数据源操作 |
| `mLockDevice` | mAudioDevices | 设备操作 |
| `mLockPreload` | mPreSource | 预加载操作 |
| `mLockCrossFade` | mFadeSource | CrossFade 操作 |

**问题**: 为什么用这么多锁而不是一把大锁？

**答案**:
- 细粒度锁降低竞争，提高并发性能
- 解码线程操作 Stream，渲染线程操作 Device，互不阻塞
- 如果用一把大锁，设备回调（高优先级、实时性要求）可能被解码操作阻塞
- 缺点是增加了死锁风险，需要严格的加锁顺序


---

## 3. 观察者模式与数据流

### 3.1 四层观察者架构

**问题**: 描述播放器的观察者模式设计，为什么需要四种观察者？

```
┌─────────────────────────────────────────────────────────────┐
│                    CNCMAudioPlayer                           │
│  实现了: INCMStreamObserver (解码回调)                       │
│         INCMDeviceObserver (设备回调)                        │
│         INCMProcessObserver (处理回调)                       │
│  持有: INCMPlayerObserver* (向上层回调)                      │
└─────────────────────┬────────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
┌──────────────┐ ┌──────────┐ ┌──────────┐
│CNCMAudioStream│ │CNCMAudio │ │AudioDevice│
│ 上报:         │ │ Process  │ │ 上报:     │
│ BufferStart   │ │ 上报:    │ │ BufferFill│
│ BufferEnd     │ │ FadeFinish│ │ FrameFill│
│ BufferCount   │ │ FillProc │ │ DeviceErr │
│ SeekDone      │ │ UpdateDur│ │ DeviceEvt │
│ StreamEvent   │ │          │ │           │
└──────────────┘ └──────────┘ └──────────┘
```

**答案**:
- **职责分离**：每个观察者只关心自己模块的事件，接口精简
- **数据流方向**：Stream → Player → Process → Player → Device → Player → App
- **Player 作为中枢**：汇聚所有子模块事件，统一决策后向上层通知
- 如果所有回调放一个接口，会导致接口臃肿（God Interface 反模式）

### 3.2 Pull 模型 vs Push 模型

**问题**: 播放器的音频数据流采用了什么模型？

**答案**: **Pull（拉取）模型**

```
硬件设备需要数据时:
  AudioDevice → 调用 BufferFill() → Player
  Player → 调用 FillProcessFrame() → Process
  Process → 调用 bufferFill() → Stream
  Stream → 从帧队列取数据
```

- 设备回调是 Pull 模型的驱动源头（AudioTrack.write 返回、AudioQueue 回调）
- 优点：数据按需产生，不会积压，延迟可控
- 对比 Push 模型：如果解码线程主动推送数据，可能导致设备来不及消费

**追问**: 那解码线程不是 Push 吗？

**答案**: 是的，解码端是 Push（主动解码往队列里放数据），消费端是 Pull（设备回调拉取）。这是典型的 **Push-Pull 混合模型**，帧队列作为解耦缓冲区。

### 3.3 PlayerNotifyEvent 分发机制

**问题**: INCMPlayerObserver 只有一个方法，如何区分不同事件？

```cpp
void PlayerNotifyEvent(int aMsg, std::string aSourceID, int aArg1, int aArg2);
```

**答案**:
- 通过 `aMsg` 参数传递 MessageType 枚举值
- `aSourceID` 标识是哪首歌的事件（支持多曲并行时区分）
- `aArg1/aArg2` 携带附加信息（如错误码、缓冲百分比）
- 单方法设计的优点：接口简单，扩展性好（新增消息类型不需要改接口）
- 缺点：上层需要 switch-case 分发

---

## 4. 状态机设计

### 4.1 完整状态定义

```cpp
enum NCMPlayStatus {
    kPlayerIdle = 1,           // 空闲（初始状态）
    kPlayerInitialized,        // 已设置数据源
    kPlayerPreparing,          // 准备中（异步）
    kPlayerPrepared,           // 准备完成
    kPlayerStarted,            // 播放中
    kPlayerPaused,             // 已暂停
    kPlayerPlaybackCompeted,   // 播放完成
    kPlayerStopped,            // 已停止
    kPlayerError,              // 错误
    kPlayerEnd,                // 结束（资源已释放）
    kPlayerCancel,             // 取消（操作被中断）
};
```

### 4.2 状态转换图

```
                     SetDataSource()
  kPlayerIdle ──────────────────────▶ kPlayerInitialized
       ▲                                     │
       │ Reset()/Stop()              PrepareAsync()
       │                                     │
  kPlayerStopped ◀── Stop()                  ▼
       ▲                            kPlayerPreparing
       │                                     │
       │                             doPrepareAsync()
       │                                     │
       │                                     ▼
       │                            kPlayerPrepared
       │                                     │
       │                              Play()│
       │                                     ▼
       │           Pause()         kPlayerStarted ──────▶ kPlayerPlaybackCompeted
       │       ┌────────────────────  │                            │
       │       ▼                      │                            │
       │  kPlayerPaused ─────────────▶│ Play()                     │
       │                              │                            │
       └──────────────────────────────┴────────────────────────────┘
                            Stop()
       
  任意状态 ── 发生错误 ──▶ kPlayerError ──▶ Reset() ──▶ kPlayerIdle
  任意状态 ── 用户取消 ──▶ kPlayerCancel
```

### 4.3 状态转换合法性

**问题**: 哪些状态转换是非法的？如何处理？

| 当前状态 | 允许的操作 | 禁止的操作 |
|----------|-----------|-----------|
| Idle | SetDataSource | Play, Pause, Seek |
| Initialized | PrepareAsync, Reset | Play, Pause, Seek |
| Preparing | Reset | Play, Pause, Seek |
| Prepared | Play, Stop, Reset, Seek | Pause |
| Started | Pause, Stop, Seek, Reset | SetDataSource |
| Paused | Play, Stop, Seek, Reset | SetDataSource |
| Completed | Play, Stop, Reset, Seek | Pause |
| Stopped | Reset | Play, Pause, Seek |
| Error | Reset | 其他所有 |

**非法操作返回** `kAudioPlayerErrorState (12)`

### 4.4 双层淡入淡出状态

**问题**: 为什么有两层 Fade 状态？NCMPlayFadeStatus 和 AudioFadeStatus 的区别？

**答案**:
- **NCMPlayFadeStatus**（Player 层）：描述播放器级别的淡入淡出意图
  - `kPlayerFadePausing`：暂停时淡出
  - `kPlayerFadeStopping`：停止时淡出
  - `kPlayerFadeInning`：播放时淡入
  - `kPlayerCrossFading`：两首歌交叉淡入淡出
- **AudioFadeStatus**（Process 层）：描述音频处理器的实际淡入淡出执行
  - `AudioFadeIn`：正在执行淡入
  - `AudioFadeOut`：正在执行淡出
- Player 层根据业务逻辑设置 Fade 意图，Process 层负责实际的音量曲线计算
- 分层后 Process 层不需要知道"为什么淡出"，只需要执行淡出即可


---

## 5. 核心数据结构设计

### 5.1 CAudioFrame 设计考量

**问题**: CAudioFrame 的字段设计有什么考虑？

```cpp
typedef struct {
    int      nFlag;            // 帧标志 (CBUFFER_FLAG 组合)
    int      nSize;            // 当前数据大小
    uint8_t* pBuffer;          // PCM 缓冲区
    int64_t  llTime;           // 时间戳 (ms)
    int      nDuration;        // 帧时长
    int      nOffset;          // 读取偏移（已消费到哪里）
    int      nSampleNum;       // 样本数
    int      nCapacity;        // 缓冲区容量
    int      nCode;            // 错误码
    int      nFrameBlock;      // 帧块标记
    CAudioDescription audioDescription;  // 音频格式
    uint8_t* pConfigData;      // 编码器配置数据
    int      pConfigSize;      // 配置数据大小
    void*    pUserData;        // 用户自定义数据
    void*    pRawData;         // 原始多声道数据
} CAudioFrame;
```

**答案**:
- **nOffset 字段**：支持部分消费。设备一次可能只需要 4096 字节，但帧有 8192 字节，nOffset 记录已读位置
- **nFlag 位域**：通过 OR 组合多个标志（如 `FLAG_BUFFER_EOS | FLAG_BUFFER_TRACK`）
- **audioDescription 内嵌**：每帧自带格式信息，支持格式动态变化（如 Gapless 衔接不同格式的歌曲）
- **pRawData**：Audio Vivid 等多声道场景需要保留原始数据
- **pUserData**：扩展字段，不修改结构体即可附加自定义数据

### 5.2 CBUFFER_FLAG 标志位

**问题**: CBUFFER_FLAG 各标志位的使用场景？

| 标志 | 值 | 使用场景 |
|------|-----|----------|
| `FLAG_BUFFER_NEW_FORMAT` | 0x01 | 音频格式变更，设备需要重新配置 |
| `FLAG_BUFFER_FLUSH` | 0x02 | Seek 后标记，通知处理器刷新状态 |
| `FLAG_BUFFER_TRACK` | 0x10 | 包含多轨频域数据（卡拉OK模式） |
| `FLAG_BUFFER_RAWDATA` | 0x20 | 包含原始多声道数据（Vivid模式） |
| `FLAG_BUFFER_EOS` | 0x100 | 流结束标志，通知后续模块播放完成 |
| `FLAG_BUFFER_PLAYRATE` | 0x200 | 变速标记，处理器需调整 Tempo |
| `FLAG_BUFFER_TIMERESET` | 0x400 | 时间戳重置（Gapless 切歌） |
| `FLAG_BUFFER_ERROR` | 0x10000 | 帧解码错误 |

**问题**: 为什么用位域而不是枚举？

**答案**: 一个帧可以同时拥有多个标志（如 `EOS + TIMERESET` 表示当前歌曲结束且即将无缝切歌），位域支持 OR 组合。

### 5.3 CAudioDescription 格式描述

**问题**: nChannelLayout 和 nChannel 为什么同时存在？

**答案**:
- `nChannel` 是声道数（2），`nChannelLayout` 是声道布局掩码（`AU_CH_LAYOUT_STEREO = 0x03`）
- 相同声道数可以有不同布局（2声道可以是立体声或双单声道）
- Audio Vivid 的 7.1.4 声道有特定的布局要求
- 设备层用 `nChannel` 创建 AudioTrack，重采样用 `nChannelLayout` 做声道映射

---

## 6. 音频基础知识

### 6.1 核心参数

| 参数 | 说明 | 常见值 |
|------|------|--------|
| 采样率 | 每秒采样次数 | 44100Hz, 48000Hz, 96000Hz |
| 位深 | 每个采样的位数 | 16bit, 24bit, 32bit float |
| 声道数 | 通道数量 | 1(单声道), 2(立体声), 5.1, 7.1.4 |

### 6.2 PCM 数据计算

**公式**: `数据量 = 采样率 × 位深/8 × 声道数 × 时长`

**示例**: 1秒 44100Hz/16bit/双声道
```
44100 × 16/8 × 2 × 1 = 176400 bytes ≈ 172KB
```

**面试追问**: 播放一首 4 分钟的歌，PCM 缓冲区最多占多少内存？
```
最大缓存 = CACHE_PACKAGE_DURATION_MAX(7s) × 176400/s ≈ 1.2MB
```

### 6.3 采样格式与转换

```cpp
enum AUSampleFormat {
    AU_SAMPLE_FMT_S16,   // 有符号16位 (Android 默认)
    AU_SAMPLE_FMT_FLT,   // 32位浮点 (iOS 偏好, 处理精度高)
    AU_SAMPLE_FMT_S16P,  // 16位 Planar (多声道分离存储)
    AU_SAMPLE_FMT_FLTP,  // 浮点 Planar (FFmpeg 常见输出)
};
```

**问题**: Interleaved 和 Planar 格式有什么区别？

```
Interleaved (交错): L R L R L R L R ...  ← AudioTrack 要求
Planar (平面):      L L L L ... R R R R ... ← FFmpeg 解码输出
```

**答案**: FFmpeg 解码常输出 Planar 格式，但 AudioTrack/AudioQueue 需要 Interleaved，因此 CNCMAudioNormlizer 需要做格式转换。

### 6.4 时间戳计算

```cpp
// 基于采样数
int64_t time_ms = (sampleCount * 1000) / sampleRate;

// 基于字节数
int64_t time_ms = (byteCount * 1000) / (sampleRate * channels * bytesPerSample);

// 基于 FFmpeg PTS
int64_t pts_ms = pts * av_q2d(timeBase) * 1000;
```


---

## 7. 解码与数据流

### 7.1 FFmpeg 解码流程

```
INCMSourceIO (数据源)
    │
    ▼ Open() / Read() / Seek()
CNCMFFDecoder (FFmpeg 封装)
    │
    ├── avformat_open_input → 打开输入（自定义 IO 回调读取 SourceIO）
    ├── avformat_find_stream_info → 获取流信息
    ├── avcodec_find_decoder → 找到解码器
    ├── avcodec_open2 → 打开解码器
    │
    ├── 解码循环:
    │   ├── av_read_frame → 读取压缩包
    │   ├── avcodec_send_packet → 发送到解码器
    │   └── avcodec_receive_frame → 获取 PCM 帧
    │
    ▼
CNCMAudioNormlizer (格式归一化)
    │
    ├── 重采样（44100 → 48000）
    ├── 格式转换（FLTP → S16）
    ├── 声道转换（多声道 → 立体声）
    │
    ▼
mAudioFrameList (帧队列)
```

### 7.2 自定义 IO 回调

**问题**: FFmpeg 如何从自定义数据源（网络/加密文件）读取数据？

**答案**:
- FFmpeg 支持自定义 IO（`AVIOContext`），通过回调函数读取数据
- 项目中 CNCMFFDecoder 将 INCMSourceIO 的 Read/Seek 方法注册为 FFmpeg 的回调
- 这样 FFmpeg 不需要知道数据来源（本地/网络/加密），SourceIO 负责数据获取

### 7.3 缓冲策略

```cpp
// 缓存控制常量
CACHE_PACKAGE_DURATION_MAX_LIMIT = 15000   // 绝对上限 15s
CACHE_PACKAGE_DURATION_MAX       =  7000   // 默认最大缓存 7s
CACHE_PACKAGE_SIGNAL_DURATION    =  4000   // 信号触发阈值 4s
CACHE_BUFFERING_MIN_DURATION     =  1000   // 最小缓冲 1s
CACHE_BUFFERING_POP_DURATION     =  1500   // 恢复播放阈值 1.5s
CACHE_BUFFERING_FIRST_DURATION   =  2000   // 首次缓冲 2s
```

**问题**: 为什么首次缓冲（2s）比恢复缓冲（1.5s）大？

**答案**:
- 首次缓冲需要更多数据保证播放启动流畅
- 二次缓冲已有部分数据，1.5s 恢复足够避免再次 buffering
- 如果都用 2s，网络不好时用户等待时间过长
- 通过 `SetPlaybackCacheParams` 可动态调整这些参数

### 7.4 解码器黑名单

**问题**: SetBlackCodecIds 是什么作用？

**答案**:
- 某些机型的硬件解码器存在 Bug（崩溃、花屏、输出异常）
- 通过黑名单机制跳过这些解码器，使用软件解码替代
- 参数通过服务端下发，无需发版即可修复

### 7.5 格式归一化 (CNCMAudioNormlizer)

**问题**: 什么场景需要格式归一化？

| 场景 | 输入 | 输出 | 操作 |
|------|------|------|------|
| 不同采样率 | 96000Hz | 48000Hz | 下采样 |
| Planar → Interleaved | S16P | S16 | 格式转换 |
| 多声道 Downmix | 5.1声道 | 立体声 | 声道混缩 |
| AI 超分后适配 | 超分输出 | 设备格式 | 格式匹配 |
| Gapless 切歌 | 歌A: 44100Hz | 歌B: 48000Hz | 统一为设备格式 |

---

## 8. 高级播放功能

### 8.1 无缝播放 (Gapless Playback)

**问题**: 无缝播放的完整实现流程？

```
歌曲A 播放中
    │
    ├── 上层调用 SetContentWithSource(source, FLAG_PLAYER_SOURCE_GAPLESS)
    │   ├── 保存到 mPreSource / mInitPreSource
    │   ├── 设置 mPreLoadFlag
    │   └── 投递 AMsgPreload 消息
    │
    ├── doGaplessSource():
    │   ├── 创建 mAudioPreLoadStream
    │   ├── 打开预加载解码流
    │   ├── 开始预解码
    │   └── 通知上层 AMsgPreLoadStatus
    │
    ├── 歌曲A 播放到 EOS:
    │   ├── doNextSource():
    │   │   ├── mAudioStream = move(mAudioPreLoadStream)
    │   │   ├── mSource = move(mPreSource)
    │   │   ├── 标记 FLAG_BUFFER_TIMERESET
    │   │   └── 无缝衔接，设备不暂停
    │   │
    │   └── 上报 AMsgPlayPrepared (新歌已准备)
    │
    └── 继续播放歌曲B
```

**问题**: 如果歌曲A和B采样率不同怎么办？

**答案**:
- CNCMAudioNormlizer 会将所有歌曲归一化到设备支持的格式
- 帧中标记 `FLAG_BUFFER_NEW_FORMAT`，设备层检测到后重新配置
- 如果需要重新打开 AudioTrack，可能有极短的间断

### 8.2 淡入淡出 (CrossFade)

**问题**: CrossFade 的数据流如何实现两首歌混音？

```
歌曲A (mAudioStream):   ██████████████████╲ 淡出
                                           ╲
歌曲B (mAudioFadeStream):                  ╱ 淡入
                                           ╱
                          |← CrossFade 时间 →|
```

**实现细节**:
1. 上层调用 `SetContentWithSource(source, FLAG_PLAYER_SOURCE_CROSSFADE)`
2. `doCrossFadeSource()` 创建 mFadeSource + mAudioFadeStream
3. 设备回调时 `doBufferFill()` 检测到 CrossFade 状态
4. 分别从两个 Stream 拉取数据
5. `doCrossBufferMix()` 按比例混合：

```cpp
void doCrossBufferMix(void* buf1, int len1, void* buf2, int len2) {
    float scale = mCrossBufferScale;  // 0.0 → 1.0 渐变
    int16_t* pcm1 = (int16_t*)buf1;   // 旧歌
    int16_t* pcm2 = (int16_t*)buf2;   // 新歌
    
    for (int i = 0; i < samples; i++) {
        pcm1[i] = pcm1[i] * (1.0 - scale) + pcm2[i] * scale;
    }
    // 更新 scale
    mCrossBufferIdx++;
    mCrossBufferScale = (float)mCrossBufferIdx / mCrossBufferCount;
}
```

### 8.3 变速不变调

**问题**: 如何实现变速播放？

**答案**: 使用 `TempoProcessor`（基于 WSOLA/PSOLA 时域拉伸算法）

```
原始 PCM → TempoProcessor → 变速后 PCM
           speed = 1.5x
           - 时间轴压缩为 2/3
           - 基频保持不变
           - 通过相位对齐避免杂音
```

**速度范围**: 0.5x ~ 2.0x

**追问**: 变速后时间戳怎么处理？

**答案**:
- Process 层维护 `mTotalWriteBytesSpeeded`（变速后的总写入量）
- `GetPlayedTimeWithSpeed()` 根据变速后的字节数计算实际播放时长
- 与 `GetPlayedTime()`（原始时长）分开管理

### 8.4 音效处理管线

**问题**: 音效处理的接口设计是怎样的？

**答案**: 通过 `IAudioEffects` 抽象接口，支持插件式音效处理

```cpp
// 音效接口 (ext/effects/)
class IAudioEffects {
    virtual int process(void* buffer, int samples, AUDIOFX_SAMPLEFORMAT fmt) = 0;
};

// 处理流程
CNCMAudioProcess::processAudio() {
    // 1. 从帧队列拉取数据
    FillProcessFrame(buffer, len, time, flag);
    
    // 2. 变速处理
    if (mSpeed != 1.0) mTempo->process(buffer, len);
    
    // 3. 音效处理
    if (mAudioEffect) mAudioEffect->process(buffer, len, fmt);
    
    // 4. 音频监听（可视化等）
    if (mAudioListener) mAudioListener->process(buffer, len, fmt);
    
    // 5. 淡入淡出
    processFade(len);
}
```


---

## 9. AI 超分 / Audio Vivid / 卡拉OK

### 9.1 AI 音频超分 (Audio Super Resolution)

**问题**: 什么是音频超分？播放器中如何集成？

**答案**: 将低采样率/低码率音频提升为高质量音频（类似图像超分辨率）。

**三步配置流程**:
```cpp
// 1. 设置 AI 处理器
player->SetAudioIFProcess(neAiAudioProcess);  // 传入 AI 推理引擎

// 2. 设置超分比率
player->SetAudioIFRatio(2);  // 2x 超分

// 3. 开启/关闭
player->SetAudioIFEnable(1);  // 1=开启, 0=关闭
```

**处理流程** (在 CNCMAudioStream 解码线程中):
```
解码帧 → doProcess() → doIFProcess() → AI 推理 → 超分帧
                            │
                            ├── initIFProcess() 初始化模型
                            ├── INEAIAudioBase 接口调用
                            └── updateIFTime() 统计耗时
```

**性能监控**: 
- `AMsgAudioIFStatus (600)`: AI 超分状态（初始化成功/失败）
- `AMsgAudioIFTime (601)`: AI 单帧处理耗时
- `kAudioPlayerAIInitError (22)`: AI 初始化失败
- `kAudioPlayerAIOverTime (23)`: AI 处理超时

**面试追问**: AI 超分处理超时怎么办？
- 设置超时阈值，超时则自动关闭超分功能
- 降级为普通播放，上报 `kAudioPlayerAIOverTime` 告知上层
- 监控平均处理时间，动态调整超分比率

### 9.2 Audio Vivid 沉浸式音频

**问题**: Audio Vivid 是什么？播放器如何支持？

**答案**: Audio Vivid 是华为主导的下一代沉浸式音频标准，支持基于对象和声道的空间音频。

**声道配置**:
```cpp
enum NCMVividChannelConfig {
    STEREO     = 1,   // 2.0 立体声
    CHANNEL5_1 = 2,   // 5.1 环绕声
    CHANNEL7_1 = 3,   // 7.1 环绕声
    CHANNEL7_1_2 = 9, // 7.1.2 带顶置声道
    CHANNEL7_1_4 = 10, // 7.1.4 完整 Atmos 声道
};
```

**配置方式**:
```cpp
player->SetVividDecInfo(
    "/path/to/vivid/model",  // 模型文件路径
    "7.1.4",                 // 声道配置
    0                        // 声道映射索引
);
player->SetPlaybackMode(kPlayerBackHighQuality);  // 高品质模式
```

**技术要点**:
- 使用独立的 `CVividDec` 解码器（ext/audiovivid/）
- 输出多声道 PCM，通过 `pRawData` 携带原始多声道数据
- 帧标记 `FLAG_BUFFER_RAWDATA` 表示包含原始数据
- 设备层根据 `nChannelLayout` 配置多声道输出

**面试追问**: 如果用户没有多声道耳机，Vivid 数据怎么处理？
- 通过 CNCMAudioNormlizer 做 Downmix（7.1.4 → 立体声）
- 保留空间感的同时适配双声道输出

### 9.3 卡拉OK 模式 (人声/伴奏分离)

**问题**: 播放器的卡拉OK模式有几种实现方案？

**答案**: 两种方案，适用不同场景：

#### 方案一: STFT 频域分离 (CNCMAudioTrackStream)

```
PCM 帧 → STFT 变换 → 频域分析 → 掩码分离 → ISTFT 合成
                          │
                ┌─────────┴──────────┐
                ▼                    ▼
         人声频谱掩码          伴奏频谱掩码
         (pMaskFeqData)       (pRawFeqData)
                │                    │
                ▼                    ▼
         人声 PCM              伴奏 PCM
         × mVoiceVolume       × mBackMusicVolume
```

- 基于频域的传统信号处理方法
- 使用 `NESTFT` 类做短时傅里叶变换
- 帧标记 `FLAG_BUFFER_TRACK`，携带 `CAudioTrackData`
- 优点: 实时性好，CPU 消耗低
- 缺点: 分离效果一般

#### 方案二: AI 模型分离 (CNCMAudioKaraokeStream)

```
PCM 帧 → AI 推理引擎 → 人声/伴奏分离
              │
     neaudioaiinference
     (深度学习模型)
```

- 基于深度学习的音源分离
- 使用 `neaudioaiinference` AI 推理引擎
- 分离效果更好，但 CPU/GPU 消耗更高
- 适合设备性能较好的场景

**模式切换**:
```cpp
player->SetMusicVoiceMode(kMusicNormal);     // 正常播放
player->SetMusicVoiceMode(kMusicKaraoke);    // AI 卡拉OK
player->SetMusicVoiceMode(kMusicKaraokeFile);// 文件模式卡拉OK

player->SetVoiceVolume(0.0f);      // 静音人声 = 纯伴奏
player->SetBackMusicVolume(0.0f);  // 静音伴奏 = 纯人声
```

---

## 10. 错误码体系与异常恢复

### 10.1 错误码分类

| 分类 | 错误码范围 | 代表错误 |
|------|-----------|----------|
| IO 错误 | 1, 15, 17 | IOError, IORead, FilePath |
| 格式错误 | 2, 4, 5 | UnSupportFormat, NoAudioStream, UnSupportCodec |
| 解码错误 | 3, 6, 7, 10 | OpenStreamError, OpenCodecError, SeekError |
| 设备错误 | 8, 9 | USBAudioError, AudioDeviceError |
| 资源错误 | 14, 16 | SwrError, NoMemory |
| AI 错误 | 22, 23, 24 | AIInitError, AIOverTime, VividModeError |
| 状态错误 | 12, 13 | ErrorState, ErrorDuration |
| 流控制 | 18, 19, 20, 21 | EOS, BufferEmpty, FormatChanged, SourceAbort |

### 10.2 错误恢复策略

**问题**: 不同类型的错误如何恢复？

| 错误 | 恢复策略 |
|------|----------|
| kAudioPlayerIOError (1) | 重试读取 → 报错 → 切歌 |
| kAudioPlayerUnSupportStreamFormat (2) | 报错 → 跳过该歌曲 |
| kAudioPlayerOpenAudioCodecError (6) | 尝试软解码 → 报错 |
| kAudioPlayerUSBAudioError (8) | 切换回 AudioTrack → 报错 |
| kAudioPlayerAudioDeviceError (9) | 重新创建设备 → 报错 |
| kAudioPlayerErrorSwr (14) | 降级格式 → 报错 |
| kAudioPlayerAIInitError (22) | 关闭 AI 超分 → 正常播放 |
| kAudioPlayerAIOverTime (23) | 关闭 AI 超分 → 正常播放 |
| kAudioPlayerAudioFormatChanged (20) | 重新配置设备 → 继续播放 |
| kAudioPlayerSourceAbout (21) | 正常处理（用户操作导致） |

### 10.3 错误上报流程

```
解码线程发现错误
    │
    ├── StreamEvent(AMsgError, songID, errCode, 0)
    │       ↓
    │   CNCMAudioPlayer::StreamEvent()
    │       ↓
    │   投递 AMsgError 到 MsgThread
    │       ↓
    │   PlayerNotifyEvent(AMsgError, songID, errCode, 0)
    │       ↓
    │   上层收到回调，展示错误提示
    │
    └── 播放器状态 → kPlayerError
        └── 等待上层调用 Reset() 恢复
```


---

## 11. 音频设备层

### 11.1 设备抽象与工厂模式

**问题**: AudioDevice 的工厂模式如何根据平台选择设备？

```cpp
// CAudioDeviceFactory::NewAudioDevice(int &DeviceType)
AudioDevice* CAudioDeviceFactory::NewAudioDevice(int &DeviceType) {
    #if defined(__ANDROID__)
    if (DeviceType == AudioDeviceType_USBAudio) {
        return new USBAudioDevice(...);
    }
    return new AudioTrackDevice(...);  // 默认
    
    #elif defined(__APPLE__)
    if (DeviceType == AudioDeviceType_AudioBuffer) {
        return new CNCMAudioBufferRenderImpl(...);
    }
    return new CNCMAudioQueueDevice(...);  // 默认
    #endif
}
```

### 11.2 设备状态管理

**问题**: AudioDevice 的 Pause 方法为什么需要 type 参数？

```cpp
virtual int Pause(int type = 0);
// type 0: 正常暂停（用户操作）
// type 1: 结束暂停（EOS 到达）
// type 2: 重置暂停（Reset 操作）
```

**答案**: 不同暂停原因的后续处理不同：
- type 0: 保留设备状态，恢复 Play 可继续
- type 1: 可能需要清理资源，等待下一首
- type 2: 需要完全重置设备状态

### 11.3 Android AudioTrack

**问题**: AudioTrack 的 Buffer 大小如何确定？

```java
int bufferSize = AudioTrack.getMinBufferSize(
    sampleRate,
    channelConfig,
    AudioFormat.ENCODING_PCM_16BIT
);
int actualBufferSize = bufferSize * 2;  // 建议 2-4 倍
```

**延迟分析**:
```
总延迟 = App Buffer + AudioTrack Buffer + AudioFlinger + HAL
       = 20-50ms   + bufferSize相关    + ~20ms       + 10-50ms
       ≈ 80-200ms
```

### 11.4 USB 音频设备

**问题**: 为什么需要专门的 USB 音频设备支持？

**答案**:
- USB DAC（数字-模拟转换器）支持更高的采样率和位深（如 96kHz/24bit）
- Android 系统 AudioTrack 的 USB 支持可能有兼容性问题
- 项目通过 libusb + UAC (USB Audio Class) 直接控制 USB 设备
- 错误处理：`AMsgAudioUSBTransferTimeout (5000)` 和 `AMsgAudioUSBTransferError (5001)`
- 失败回退：USB 不可用时自动切换回 AudioTrack（`kAudioPlayerUSBAudioError → doDeviceChanged`）

### 11.5 耳机切换处理

**问题**: 蓝牙耳机断开时播放器如何处理？

**流程**:
```
系统检测到耳机断开
    ↓
SetHeadSetType(kHeadSetNormal)  // 0=普通, 1=蓝牙
    ↓
AMsgHeadSetChanged → ControlThread
    ↓
doHeadSetChanged():
    ├── 蓝牙→有线/外放: 可能需要重建 AudioTrack
    ├── 有线→无: Android 系统自动暂停
    └── 外放→蓝牙: 需要配置蓝牙音频参数
```

### 11.6 iOS AudioQueue

**问题**: AudioQueue 为什么用 3 个 Buffer？

**答案**:
```
Buffer1: 正在播放
Buffer2: 等待播放（已填充）
Buffer3: 正在被回调填充

三个 Buffer 的流转保证了:
- 播放永远有数据可用（Buffer2 候补）
- 填充有充足时间（Buffer3 不赶进度）
- 2 个 Buffer 可能来不及填充，4 个浪费内存
```

### 11.7 音量测量 (Metering)

**问题**: peakPower 和 averagePower 有什么区别？

```cpp
player->setMeteringEnabled(true);   // 开启测量
player->updateMeters();             // 更新数据
float peak = player->peakPower();   // 峰值功率（最大瞬时值）
float avg  = player->averagePower();// 平均功率（均方根）

// 按声道获取
float leftPeak  = player->peakPowerForChannel(0);
float rightPeak = player->peakPowerForChannel(1);
```

**应用场景**: 音频可视化（波形图、频谱图）、音量指示器

---

## 12. 平台适配

### 12.1 Android JNI

**注册方式**:
```cpp
// audio_player_jni.cpp
jint JNI_OnLoad(JavaVM* vm, void* reserved) {
    // 注册 native 方法
    RegisterNatives(env, className, gMethods, numMethods);
}
```

**关键注意事项**:
- JNIEnv 不能跨线程使用，新线程需要 `AttachCurrentThread`
- 回调 Java 方法要用全局引用（`NewGlobalRef`），用完 `DeleteGlobalRef`
- 局部引用在 native 方法返回后自动释放，但循环中要手动释放
- C++ 异常不能跨 JNI 边界传播，需要 catch 后转 Java 异常

**AudioSourceAndroid 数据源**:
```
Java SourceIO
    ↓ JNI 回调
AudioSourceAndroid (实现 INCMSourceIO)
    ↓ Open/Read/Seek/Close
CNCMFFDecoder (FFmpeg 自定义 IO)
```

### 12.2 iOS ObjC++ 适配

**NTESMAudioPlayer** 封装:
```objc
@interface NTESMAudioPlayer : NSObject
// 内部持有 C++ 的 INCMPlayer*
// .mm 文件支持 ObjC/C++ 混编
@end
```

**CNTESMSource** 数据源适配:
```
ObjC 数据源协议 (NTESMSourceIO)
    ↓ ObjC++ 适配
CNTESMSource (实现 INCMSourceIO)
    ↓
CNCMFFDecoder
```

### 12.3 跨平台兼容性

| 差异 | Android | iOS |
|------|---------|-----|
| 默认格式 | S16 (16bit 整型) | Float32 (浮点) |
| 默认采样率 | 44100Hz 最通用 | 48000Hz |
| 音频设备 | AudioTrack / USB | AudioQueue / AudioBuffer |
| 线程优先级 | SCHED_FIFO + 优先级设置 | pthread_set_qos_class |
| 浮点 PCM | `EnableFloatPCM(true)` 开启 | 默认支持 |

**问题**: `EnableFloatPCM(bool enable)` 在两端分别做了什么？

**答案**:
- Android: 默认 S16 输出，开启后切换到 Float32（需要 Android 5.0+）
- iOS: 默认即 Float32，关闭后降级为 S16
- 浮点的优点: 处理精度高、动态范围大、音效处理不失真
- 浮点的缺点: 数据量翻倍（32bit vs 16bit）


---

## 13. 深度原理篇

### 13.1 FFmpeg 解码原理

#### 核心数据结构

```cpp
AVFormatContext *formatCtx;  // 封装格式信息（MP3/FLAC/AAC 容器）
AVCodecContext *codecCtx;    // 解码器状态
AVPacket *packet;            // 压缩数据包
AVFrame *frame;              // 解码后的原始帧
```

#### 关键 API

| API | 作用 | 返回值含义 |
|-----|------|-----------|
| `av_read_frame` | 读取一个压缩包 | 0成功，<0失败或EOF |
| `avcodec_send_packet` | 发送包到解码器 | EAGAIN=需先receive |
| `avcodec_receive_frame` | 获取解码帧 | EAGAIN=需更多数据 |

#### 音频重采样 (SwrContext)

```cpp
SwrContext *swr = swr_alloc_set_opts(NULL,
    AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16, 44100,  // 目标
    srcLayout, srcFormat, srcRate,                     // 源
    0, NULL);
swr_init(swr);
swr_convert(swr, outBuffer, outSamples, inBuffer, inSamples);
```

**面试题**: `avcodec_send_packet` 返回 EAGAIN 和 `avcodec_receive_frame` 返回 EAGAIN 分别怎么处理？

**答案**:
- `send_packet` 返回 EAGAIN: 解码器内部缓冲区满了，需要先 `receive_frame` 取出数据
- `receive_frame` 返回 EAGAIN: 解码器需要更多压缩数据，需要继续 `send_packet`
- 这是 FFmpeg 4.x 的异步解码 API，一个 packet 可能产生多个 frame

### 13.2 Android AudioTrack 深入

#### 架构层次

```
App (Java AudioTrack)
    ↓ JNI
Native AudioTrack (共享内存 cblk)
    ↓ Binder IPC
AudioFlinger (MixerThread 混音)
    ↓
Audio HAL (硬件驱动)
```

#### Buffer 策略对延迟的影响

| 场景 | Buffer 大小 | 延迟 | 风险 |
|------|------------|------|------|
| 低延迟 | getMinBufferSize() | ~80ms | 容易 underrun |
| 平衡 | minBuffer × 2 | ~120ms | 推荐 |
| 高稳定 | minBuffer × 4 | ~200ms | 内存占用高 |

#### AudioTrack Underrun 检测

**问题**: 如何检测和处理 AudioTrack underrun？

```cpp
// write 返回值 < 请求值，说明可能 underrun
int written = audioTrack.write(buffer, offset, size);
if (written < size) {
    // 可能发生了 underrun
    LOG("AudioTrack underrun: wrote %d/%d", written, size);
}
```

**处理**: 项目通过 `AMsgAudioRenderBlockTime (3002)` 监控渲染阻塞时间

### 13.3 iOS AudioQueue 深入

#### 工作流程

```
1. AudioQueueNewOutput(&format, callback, self, ...)
2. AudioQueueAllocateBuffer(queue, bufferSize, &buffer) × 3
3. 初始填充 + AudioQueueEnqueueBuffer()
4. AudioQueueStart(queue, NULL)
5. 回调循环:
   callback(userData, queue, buffer) {
       // 从 Player 拉取 PCM 数据
       player->BufferFill(buffer->mAudioData, &len, &time);
       buffer->mAudioDataByteSize = len;
       AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
   }
```

#### 常见问题与解决

| 问题 | 原因 | 解决 |
|------|------|------|
| 播放中断 | 回调填充太慢 | 增大 Buffer 或预缓冲 |
| 延迟高 | Buffer 太大 | 减小 Buffer |
| 杂音 | Buffer 未填满 | 填零（静音）处理 |
| 打断恢复 | 电话等中断 | 监听 AVAudioSession notification |

### 13.4 Seek 实现原理

**问题**: 音频文件 Seek 有关键帧的概念吗？

**答案**:
- **MP3**: 有关键帧概念。VBR 编码时需要 Xing/VBRI 头做精确定位
- **AAC**: 每帧独立可解码，但有 priming samples 需要跳过
- **FLAC**: 无损格式，每帧可独立解码
- 实际上 `av_seek_frame` 配合 `AVSEEK_FLAG_BACKWARD` 可以处理大部分场景

**完整 Seek 流程**:
```cpp
int CNCMAudioPlayer::doSeek(int64_t time) {
    // 1. 暂停解码线程
    mAudioStream->pause();
    
    // 2. 清空帧队列
    // 通过 seek() 内部处理
    
    // 3. FFmpeg Seek
    mAudioStream->seek(time);
    
    // 4. Flush 音频处理器
    mAudioProcess->Reset();
    
    // 5. Flush 设备缓冲
    mAudioDevices->Flush();
    
    // 6. 重置时间
    // 通过 AMsgDoSeekCompleted 通知
    
    // 7. 恢复解码
    mAudioStream->resume();
}
```


---

## 14. 场景问题排查案例

### 14.1 播放卡顿

**排查流程**:
```
播放卡顿
    │
    ├── 网络问题?
    │   ├── Buffering 频率 → AMsgBufferingInfo (200)
    │   ├── IO 读取耗时 → SourceIO.Read() 耗时
    │   └── → 增大缓冲参数 SetPlaybackCacheParams()
    │
    ├── 解码性能?
    │   ├── 单帧解码耗时 → AMsgDecFrameTime (800)
    │   ├── 解码线程耗时 → AMsgDecThreadTime (801)
    │   └── → 降低音质 / 关闭 AI 超分
    │
    ├── 渲染阻塞?
    │   ├── 渲染延迟 → AMsgAudioRenderLagTime (3001)
    │   ├── 渲染阻塞 → AMsgAudioRenderBlockTime (3002)
    │   └── → 增大设备 Buffer / 降低优先级竞争
    │
    └── AI 超分导致?
        ├── AI 处理耗时 → AMsgAudioIFTime (601)
        └── → 关闭超分 SetAudioIFEnable(0)
```

### 14.2 播放无声

**排查流程**:
```
播放无声
    │
    ├── 系统音量?
    │   ├── mAudioSystemVolume.curVolume == 0
    │   └── → 提示用户调整
    │
    ├── 播放器音量?
    │   ├── mVolume, mVoiceVolume, mBackMusicVolume 检查
    │   ├── 淡出卡住: mFadeStatus == kPlayerFadeStopping
    │   └── → 重置 FadeStatus
    │
    ├── PCM 全零?
    │   ├── 解码输出: SetDumpUrl() 抓取 PCM 文件
    │   ├── 音效处理后全零: 音效 bug
    │   └── → 关闭音效 SetAudioEffect(nullptr)
    │
    ├── 设备问题?
    │   ├── DeviceState: kDeviceOpenError 等
    │   ├── USB 设备: AMsgUSBAudioStatus (500)
    │   └── → 切换回默认设备
    │
    └── 音频焦点?
        ├── Android: AudioFocus 被抢占
        ├── iOS: AVAudioSession 中断
        └── → 正确处理焦点回调
```

### 14.3 首帧延迟过高

**各阶段耗时分析**:
```
[T1] SetDataSource     → SourceIO 创建           (~5ms)
[T2] PrepareAsync      → 打开文件 + 解析格式     (~50-200ms)
[T3] 首次缓冲          → 缓冲 2s 数据            (~200-2000ms)
[T4] 设备初始化        → AudioTrack/AudioQueue    (~20-50ms)
[T5] 首帧渲染          → 数据写入设备             (~10-30ms)
─────────────────────────────────────────────────────────────
总计                                              (~300-2300ms)
```

**优化策略**:
| 阶段 | 优化方案 |
|------|----------|
| T2 | 预创建解码器、缓存格式信息 |
| T3 | 降低 CACHE_BUFFERING_FIRST_DURATION (2000→1000) |
| T4 | 预热 AudioTrack、复用设备实例 |
| T5 | 减小设备 Buffer |
| 全局 | 预加载 (PreLoad) 下一首歌 |

### 14.4 内存泄漏

**检查清单**:
```
□ FFmpeg: AVFormatContext/AVCodecContext/AVFrame/AVPacket 是否释放
□ 帧队列: mAudioFrameList + mAudioFrameFreeList 是否清理
□ 三路数据源: mSource/mPreSource/mFadeSource unique_ptr 释放
□ 三路解码流: mAudioStream/mPreLoadStream/mFadeStream 释放
□ 线程: mMsgThread/mControlThread 正确销毁
□ JNI: GlobalRef 是否 DeleteGlobalRef
□ AI: mNEAiAudioIF 推理引擎是否释放
□ Dump: mDumpFile 文件句柄是否关闭
□ CrossFade: mCrossBuffer 是否释放
```

### 14.5 Seek 问题

**问题**: Seek 后播放位置不准确

**排查**:
1. 时间戳转换是否正确（毫秒 vs 微秒 vs FFmpeg timebase）
2. FFmpeg Seek 是否使用了 `AVSEEK_FLAG_BACKWARD`
3. Flush 解码器后是否丢弃了前几帧（priming samples）
4. 处理器和设备缓冲是否都 Flush 了
5. 时间戳是否重置

**问题**: Seek 后有杂音

**解决**: 
- Seek 后对首帧做短淡入（几毫秒），避免 PCM 数据不连续的爆音
- 确保 `avcodec_flush_buffers` 被正确调用

### 14.6 CrossFade 切歌异常

**问题**: 两首歌 CrossFade 时出现杂音或音量突变

**排查**:
```
1. 两首歌采样率是否一致?
   → 不一致需要 Normlizer 统一到设备格式
   
2. mCrossBufferScale 渐变是否线性?
   → 线性可能听感突兀，考虑 S 曲线

3. CrossFade 结束时 mFadeSource 是否及时释放?
   → 防止内存泄漏和残余数据

4. doResetFadeSource() 是否正确调用?
   → CrossFade 完成后必须清理
```

---

## 15. 性能优化

### 15.1 内存优化

| 策略 | 说明 | 应用位置 |
|------|------|----------|
| 帧复用池 | `mAudioFrameFreeList` 复用帧对象 | Stream/Process |
| 智能指针 | `unique_ptr` 管理数据源和解码流 | Player |
| 预分配 | `FRAME_DATA_LENGTH=128KB` 预分配帧缓冲 | CNCMProperty |
| 按需创建 | 预加载/CrossFade 流按需创建 | Player |

### 15.2 CPU 优化

| 策略 | 说明 |
|------|------|
| NEON/SIMD | 向量化 PCM 混音、淡入淡出计算 |
| 批量处理 | `mStepSize` 控制单次处理的数据量 |
| 线程优先级 | 渲染线程设置高优先级 |
| 条件处理 | AI 超分仅在启用时执行 |

### 15.3 延迟优化

| 策略 | 说明 |
|------|------|
| 预加载 | `SetContentWithSource(FLAG_GAPLESS)` 提前准备下一首 |
| 预热设备 | 设备初始化与准备并行 |
| 动态缓冲 | `SetPlaybackCacheParams` 根据网络状况调整 |
| 复用设备 | Gapless 切歌不重建 AudioTrack |

---

## 16. 设计模式应用

### 16.1 工厂模式

```cpp
// 播放器工厂
INCMPlayer* player = CMediaPlayerFactory::NewL(observer);

// 设备工厂
AudioDevice* device = CAudioDeviceFactory::NewAudioDevice(deviceType);
```

**面试题**: 为什么用工厂模式而不是直接 new？
- 隐藏具体实现类，上层只依赖接口
- 根据平台/配置自动选择实现
- 便于单元测试 Mock

### 16.2 观察者模式

```
四种观察者: INCMPlayerObserver / INCMStreamObserver / 
           INCMProcessObserver / INCMDeviceObserver
```

**面试题**: 为什么 Player 同时是观察者和被观察者？
- Player 实现三个 Observer 接口 → 接收子模块回调
- Player 持有 INCMPlayerObserver → 向上层发送通知
- 体现了 **中介者模式** 的思想：子模块不直接通信，通过 Player 中转

### 16.3 命令模式

```
所有操作封装为消息 (MessageType)
    → 投递到 CNCMMsgThread 消息队列
    → 按序执行
```

**优点**: 
- 操作可排队、可取消（`clearMessage`）
- 控制操作在统一线程执行，避免并发问题

### 16.4 策略模式

```
AudioDevice (抽象策略)
    ├── AudioTrackDevice (Android 策略)
    ├── USBAudioDevice (USB 策略)
    ├── CNCMAudioQueueDevice (iOS 策略)
    └── CNCMAudioBufferRenderImpl (iOS Buffer 策略)
```

### 16.5 适配器模式

```
AudioSourceAndroid: Java SourceIO → INCMSourceIO
CNTESMSource: ObjC SourceIO → INCMSourceIO
```

---

## 17. 重点面试题汇总

### 架构设计 (高频)

1. **描述播放器的整体架构分层设计**
2. **为什么核心用 C++ 而不是 Java/Swift？**
3. **三路数据源并行架构的设计考量是什么？**
4. **Player 为什么要同时实现三个 Observer 接口？**

### 线程与并发 (高频)

5. **描述播放器的五线程模型及各线程职责**
6. **MsgThread 和 ControlThread 为什么要分开？**
7. **为什么用细粒度锁（8把锁）而不是一把大锁？**
8. **帧队列满/空分别怎么处理？**
9. **设备回调 BufferFill 是在哪个线程执行的？**

### 状态机 (高频)

10. **画出播放器完整的状态转换图**
11. **非法状态转换如何处理？**
12. **NCMPlayFadeStatus 和 AudioFadeStatus 的区别？**

### 音频基础 (中频)

13. **计算 1 秒 48kHz/24bit/立体声的 PCM 数据量**
14. **Interleaved 和 Planar 格式的区别和转换**
15. **什么场景需要 CNCMAudioNormlizer 做格式归一化？**

### 高级特性 (中频)

16. **Gapless 无缝播放的完整流程**
17. **CrossFade 两首歌如何混音？**
18. **AI 超分处理超时怎么降级？**
19. **Audio Vivid 7.1.4 声道在双声道耳机上怎么播？**
20. **卡拉OK 的两种实现方案（STFT vs AI）的优劣？**

### 错误处理 (中频)

21. **25 个错误码可以分为哪几大类？**
22. **USB 音频设备失败如何回退？**
23. **AI 相关错误（22/23/24）的降级策略？**

### 平台适配 (中频)

24. **JNI 开发有哪些注意事项？**
25. **Android AudioTrack 和 iOS AudioQueue 的核心区别？**
26. **EnableFloatPCM 在两个平台分别做了什么？**

### 性能优化 (深度)

27. **如何优化首帧播放延迟？各阶段分别能优化多少？**
28. **帧复用池 (mAudioFrameFreeList) 如何避免内存碎片？**
29. **渲染线程为什么需要高优先级？**

### 场景排查 (深度)

30. **用户反馈播放 30 分钟后开始卡顿，怎么排查？**
31. **播放正常但无声，排查流程？**
32. **Seek 后有爆音（杂音），原因和解决方案？**
33. **CrossFade 切歌时音量突变，怎么排查？**
34. **长时间切歌后 OOM，内存泄漏检查清单？**

### 设计模式 (加分)

35. **项目中用了哪些设计模式？各解决什么问题？**
36. **PlayerNotifyEvent 单方法回调的优缺点？**
37. **消息队列命令模式的优点是什么？**

---

*文档基于 NCM Audio Player Project.md 全面整理，覆盖架构设计、核心实现、高级特性、平台适配、性能优化、场景排查六大领域，共 37 道面试题*
