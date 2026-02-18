# NCM Audio Player 项目文档

## 1. 项目概述

NCM Audio Player 是网易云音乐的跨平台音频播放器核心引擎，采用 C++ 实现核心逻辑，支持 Android、iOS 和 macOS 三大平台。项目提供了完整的音频解码、处理、渲染管线，支持多种高级播放功能。

### 1.1 支持平台
- **Android** - 通过 JNI 接口暴露给 Java/Kotlin
- **iOS** - 通过 Objective-C++ 封装暴露给 Swift/ObjC
- **macOS** - 通过 Objective-C++ 封装

### 1.2 核心特性
- 多格式音频解码（基于 FFmpeg）
- 无缝播放（Gapless Playback）
- 淡入淡出切歌（CrossFade）
- 变速播放（0.5x - 2.0x）
- 音效处理管线
- AI 音频超分处理
- Audio Vivid 沉浸式音频支持
- 卡拉OK模式（人声/伴奏分离）
- USB 音频设备支持（Android）

---

## 2. 项目目录结构

```
ncmaudioplayer/
├── cpp/                            # 核心 C++ 实现
│   ├── CNCMAudioPlayer.cpp/.h      #   播放器核心（状态机、线程调度、播放控制）
│   ├── CNCMAudioPlayerFactory.cpp  #   播放器工厂类 (CMediaPlayerFactory)
│   ├── CNCMAudioStream.cpp/.h      #   解码管线（解码线程、帧队列、缓冲管理）
│   ├── CNCMAudioTrackStream.cpp/.h #   多轨音频流处理（STFT 频域人声分离）
│   ├── CNCMAudioKaraokeStream.cpp/.h#  卡拉OK流（实时人声/伴奏分离）
│   ├── CNCMAudioProcess.cpp/.h     #   音频处理器（音效、变速、淡入淡出）
│   ├── CNCMAudioDevice.cpp/.h      #   音频设备抽象基类
│   ├── CNCMAudioTimeInfo.cpp/.h    #   播放时间管理器
│   ├── CNCMAudioNormlizer.cpp/.h   #   音频格式归一化/重采样
│   ├── CNCMAudioLocalSource.cpp/.h #   本地文件数据源实现
│   ├── CNCMAudioSourceIO.cpp/.h    #   通用数据源 IO 封装
│   ├── CNCMFFDecoder.cpp/.h        #   FFmpeg 解码器
│   ├── CNCMProperty.h              #   核心数据结构定义（CAudioDescription, CAudioFrame 等）
│   ├── CTrackPlayedTimeData.h      #   轨道播放时间数据
│   ├── INCMDefs.h                  #   枚举定义（状态、模式、标志位）
│   ├── INCMErrDefs.h               #   错误码定义
│   ├── INCMMsgType.h               #   消息类型枚举
│   ├── INCMObserver.h              #   观察者接口（Player/Stream/Device/Process）
│   ├── INCMPlayer.h                #   播放器公共接口
│   ├── INCMSourceIO.h              #   数据源接口
│   ├── dec/                        #   解码器实现
│   │   ├── CAudioDec.cpp/.h        #     音频解码器基类
│   │   └── CVividDec.cpp/.h        #     Audio Vivid 解码器
│   ├── stft/                       #   短时傅里叶变换
│   │   └── NESTFT.cpp/.h           #     STFT 实现（频域分析/合成）
│   └── util/                       #   工具类
│       ├── audio_jni_helper.cpp/.h #     JNI 辅助工具
│       ├── CNCMABTestKey.cpp/.h    #     AB 测试 Key 管理
│       ├── CNCMAudioConfig.cpp/.h  #     音频配置管理
│       ├── CNCMCondition.cpp/.h    #     条件变量封装
│       ├── CNCMCritical.cpp/.h     #     临界区/互斥锁封装
│       ├── CNCMLog.cpp/.h          #     日志封装
│       ├── CNCMMsgThread.cpp/.h    #     消息线程封装
│       ├── CNCMSemaphore.cpp/.h    #     信号量封装
│       ├── CNCMSysTime.cpp/.h      #     系统时间工具
│       └── CNCMThread.cpp/.h       #     线程基类封装
├── device/                         # 音频设备抽象层
│   ├── CNCMAudioDeviceFactory.cpp  #   音频设备工厂类 (CAudioDeviceFactory)
│   ├── Android/                    #   Android 音频设备
│   │   ├── audio_track.cpp/.h      #     AudioTrack 设备（高层封装，含渲染线程）
│   │   ├── audio_device_android_audiotrack.cpp/.h # AudioTrack JNI 底层封装
│   │   ├── usb_audio_device.cpp/.h #     USB 音频设备
│   │   └── USB/                    #     USB 底层实现
│   │       ├── libusb/             #       libusb 库
│   │       └── UAC/                #       USB Audio Class 实现
│   ├── iOS/                        #   iOS 音频设备
│   │   ├── CNCMAudioQueueDevice.h/.mm    # AudioQueue 设备实现
│   │   ├── CNCMAudioBufferRenderer.h     # AudioBuffer 渲染器接口
│   │   └── CNCMAudioBufferRenderImpl.h/.mm # AudioBuffer 渲染器实现
│   └── Mac/                        #   macOS 音频设备
│       └── Output/
│           ├── NTESMAudioOutputDevice.h/.m   # 音频输出设备
│           └── NTESMAudioOutputManager.h/.m  # 音频输出管理器
├── interface/                      # 平台接口层
│   ├── Android/                    #   Android JNI 接口
│   │   ├── android_audioplayer.cpp/.h    # AndroidAudioPlayer 封装类
│   │   ├── audio_player_jni.cpp          # JNI_OnLoad 及方法注册
│   │   ├── audio_source_android.cpp/.h   # Android 数据源实现 (AudioSourceAndroid)
│   │   └── bizfuncs.map                  # 符号导出映射
│   └── iOS/                        #   iOS ObjC 接口
│       ├── NTESMAudioPlayer.h/.mm        # ObjC 播放器封装
│       ├── NTESMSourceIO.h               # ObjC 数据源协议
│       └── CNTESMSouce.h/.mm             # ObjC 数据源实现
├── ext/                            # 第三方依赖
│   ├── audiocommon/                #   音频通用库（FFT、SVM 等）
│   ├── audiovivid/                 #   Audio Vivid 解码（5.1/7.1/7.1.4 声道渲染）
│   ├── audiosr/                    #   AI 音频超分基础接口
│   ├── effects/                    #   音效处理库（IAudioEffects, TempoProcessor）
│   ├── ffmpeg/                     #   FFmpeg 库（include/lib/ncmffmpegios）
│   ├── tempofx/                    #   变速处理库
│   ├── nblog4c/                    #   跨平台日志库
│   ├── neaudioaiinference/         #   AI 音频推理引擎（模型推理、人声分离等）
│   └── nm_common_cache/            #   通用缓存模块（android/ios/mac 三端）
├── Demo/                           # 示例工程
│   ├── Android/                    #   Android Demo（含 AudioHook、ncmaudioaiinference 模块）
│   ├── iOS/                        #   iOS Demo（TestAudioPlayer、NCMMusicPlayer）
│   └── Mac/                        #   macOS Demo（TestAudioPlayer、NCMMusicPlayer）
├── projects/                       # 构建脚本
│   ├── android/                    #   Android CMake/NDK 构建
│   ├── ios/                        #   iOS Xcode 构建
│   └── mac/                        #   macOS Xcode 构建
├── CMakeLists.txt                  # 根 CMake 配置
├── bizfuncs.map                    # 符号导出映射
└── .gitmodules                     # Git 子模块配置
```

---

## 3. 核心架构

### 3.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Application Layer                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│  │  Android App    │  │    iOS App      │  │   macOS App     │          │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘          │
└───────────┼─────────────────────┼─────────────────────┼─────────────────┘
            │                     │                     │
┌───────────┼─────────────────────┼─────────────────────┼─────────────────┐
│           ▼                     ▼                     ▼                 │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐         │
│  │AndroidAudioPlayer│ │NTESMAudioPlayer  │ │NTESMAudioPlayer  │         │
│  │     (JNI)        │ │   (ObjC++)       │ │   (ObjC++)       │         │
│  │AudioSourceAndroid│ │ CNTESMSource     │ │ CNTESMSource     │         │
│  └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘         │
│           │     Platform Interface Layer    │                           │
└───────────┼─────────────────────┼───────────┼───────────────────────────┘
            │                     │           │
            └─────────────────────┼───────────┘
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Core Engine (C++)                                 │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                CMediaPlayerFactory (工厂创建)                     │   │
│  └──────────────────────────┬───────────────────────────────────────┘   │
│                              ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    CNCMAudioPlayer                                │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐  │   │
│  │  │ MsgThread   │  │ControlThread │  │   State Machine         │  │   │
│  │  │ (事件通知)   │  │ (播放控制)   │  │ (NCMPlayStatus)         │  │   │
│  │  └─────────────┘  └──────────────┘  └─────────────────────────┘  │   │
│  │  ┌──────────────────────────────────────────────────────────┐    │   │
│  │  │              CNCMAudioTimeInfo (时间管理)                  │    │   │
│  │  └──────────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│  ┌───────────────────────────────┼───────────────────────────────────┐  │
│  │                               ▼                                    │  │
│  │  ┌───────────────────┐ ┌────────────────────┐ ┌────────────────┐   │  │
│  │  │  CNCMAudioStream  │ │ CNCMAudioProcess   │ │ AudioDevice    │   │  │
│  │  │   (解码管线)      │ │   (音频处理)       │ │  (音频输出)    │   │  │
│  │  │                   │ │                    │ │                │   │  │
│  │  │ CNCMAudioTrack-   │ │ - 音效处理         │ │ CAudioDevice-  │   │  │
│  │  │  Stream(多轨)     │ │ - 变速/TempoFX     │ │  Factory(工厂) │   │  │
│  │  │ CNCMAudioKaraoke- │ │ - 淡入淡出         │ │                │   │  │
│  │  │  Stream(卡拉OK)   │ │ - AI超分           │ │                │   │  │
│  │  │                   │ │                    │ │                │   │  │
│  │  │ CNCMAudioNormlizer│ │                    │ │                │   │  │
│  │  │  (格式归一化)     │ │                    │ │                │   │  │
│  │  └────────┬──────────┘ └────────┬───────────┘ └────────┬───────┘   │  │
│  │           │                     │                      │           │  │
│  └───────────┼─────────────────────┼──────────────────────┼───────────┘  │
│              │                     │                      │              │
└──────────────┼─────────────────────┼──────────────────────┼──────────────┘
               │                     │                      │
               ▼                     ▼                      ▼
┌────────────────────────┐ ┌──────────────────┐ ┌──────────────────────────┐
│    Decoder Layer       │ │  Effects Layer   │ │      Device Layer        │
│  ┌──────────────────┐  │ │ ┌──────────────┐ │ │ ┌──────────────────────┐ │
│  │  CNCMFFDecoder   │  │ │ │ IAudioEffects│ │ │ │ Android:             │ │
│  │    (FFmpeg)      │  │ │ │TempoProcessor│ │ │ │  AudioTrack          │ │
│  │  CVividDec       │  │ │ │   AI-IF      │ │ │ │  USBAudioDevice      │ │
│  │    (AudioVivid)  │  │ │ │              │ │ │ │ iOS:                 │ │
│  │  CAudioDec       │  │ │ │              │ │ │ │  CNCMAudioQueueDevice│ │
│  │    (解码器基类)  │  │ │ │              │ │ │ │  AudioBufferRender   │ │
│  └──────────────────┘  │ │ └──────────────┘ │ │ │ Mac:                 │ │
│                        │ │                  │ │ │  NTESMAudioOutput    │ │
│                        │ │                  │ │ └──────────────────────┘ │
└────────────────────────┘ └──────────────────┘ └──────────────────────────┘
```

### 3.2 音频数据流转流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Audio Data Pipeline                             │
└─────────────────────────────────────────────────────────────────────────┘

┌────────────────┐   ┌────────────────┐   ┌──────────────────┐   ┌────────────┐
│ INCMSourceIO   │──▶│ CNCMFFDecoder  │──▶│ CNCMAudioStream  │──▶│ AudioFrame │
│ (数据源)       │   │ (FFmpeg解码)   │   │ (解码管线)       │   │   队列     │
│                │   │                │   │                  │   │            │
│ LocalSource    │   │ CVividDec      │   │ CNCMAudioNorm-   │   │            │
│ AudioSource-   │   │ (Vivid解码)   │   │  lizer(重采样)   │   │            │
│  Android       │   │                │   │                  │   │            │
│ CNCMAudioSrc-  │   │                │   │ CNCMAudioTrack-  │   │            │
│  IO            │   │                │   │  Stream(多轨)    │   │            │
│                │   │                │   │ CNCMAudioKaraoke-│   │            │
│                │   │                │   │  Stream(卡拉OK)  │   │            │
└────────────────┘   └────────────────┘   └──────────────────┘   └──────┬─────┘
                                                                        │
                     ┌──────────────────────────────────────────────────┘
                     │
                     ▼
┌────────────────┐   ┌────────────────┐   ┌──────────────────┐   ┌────────────┐
│  AudioDevice   │◀──│CNCMAudioProcess│◀──│   音效处理       │◀──│  AI超分/   │
│  (音频输出)    │   │  (音频处理器)  │   │  IAudioEffects   │   │  变速处理  │
│                │   │                │   │  TempoProcessor  │   │            │
│ AudioTrack     │   │  淡入淡出      │   │                  │   │            │
│ USBAudioDevice │   │  (FadeStatus)  │   │                  │   │            │
│ AudioQueue     │   │                │   │                  │   │            │
│ AudioBuffer    │   │                │   │                  │   │            │
└────────────────┘   └────────────────┘   └──────────────────┘   └────────────┘
```

---

## 4. 核心模块详解

### 4.1 播放器状态机 (NCMPlayStatus)

```cpp
// 文件: cpp/INCMDefs.h
enum NCMPlayStatus {
    kPlayerIdle = 1,              // 空闲状态
    kPlayerInitialized,           // 已初始化（设置了数据源）
    kPlayerPreparing,             // 准备中（解析音频信息）
    kPlayerPrepared,              // 准备完成（可以播放）
    kPlayerStarted,               // 播放中
    kPlayerPaused,                // 已暂停
    kPlayerPlaybackCompeted,      // 播放完成
    kPlayerStopped,               // 已停止
    kPlayerError,                 // 错误状态
    kPlayerEnd,                   // 结束状态
    kPlayerCancel,                // 取消状态
};
```

```
状态转换图:
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
       │            Pause()        kPlayerStarted ──────▶ kPlayerPlaybackCompeted
       │         ┌────────────────── │                            │
       │         ▼                   │                            │
       │    kPlayerPaused ──────────▶│ Play()                     │
       │                             │                            │
       └─────────────────────────────┴────────────────────────────┘
                            Stop()
       
  任意状态 ──── 发生错误 ──▶ kPlayerError
```

### 4.2 播放模式标志 (NCMAudioPlayerFlag)

```cpp
// 文件: cpp/INCMDefs.h
typedef enum {
    kAudioPlayerFlagNone = 0,     // 普通播放
    kAudioPlayerFlagGapless = 1,  // 无缝播放
    kAudioPlayerFlagCrossFade = 2 // 淡入淡出切歌
} NCMAudioPlayerFlag;

// 配合宏定义使用：
#define FLAG_PLAYER_SOURCE_GAPLESS     0X00000001  // gapless 标志
#define FLAG_PLAYER_SOURCE_CROSSFADE   0X00000002  // crossfade 标志
```

### 4.3 音乐模式 (NCMMusicMode)

```cpp
typedef enum {
    kMusicNormal = 0,            // 普通模式
    kMusicKaraoke = 1,           // 卡拉OK模式（实时分离）
    kMusicKaraokeFile = 2,       // 卡拉OK文件模式
} NCMMusicMode;
```

### 4.4 淡入淡出状态 (NCMPlayFadeStatus)

```cpp
typedef enum {
    kPlayerFadeNone = 0,     // 无淡入淡出
    kPlayerFadePausing,      // 暂停淡出中
    kPlayerFadeStopping,     // 停止淡出中
    kPlayerFadeInning,       // 淡入中
    kPlayerCrossFading,      // 交叉淡入淡出中
} NCMPlayFadeStatus;
```

### 4.5 播放回放模式 (NCMPlayBackMode)

```cpp
typedef enum {
    kPlayerBackNormal = 0,          // 普通模式
    kPlayerBackHighQuality = 1,     // 高品质模式
    kPlayerBackAllHighQuality = 2,  // 全高品质模式
} NCMPlayBackMode;
```

### 4.6 Audio Vivid 声道配置 (NCMVividChannelConfig)

```cpp
typedef enum {
    STEREO = 1,          // 立体声 (2.0)
    CHANNEL5_1 = 2,      // 5.1 声道
    CHANNEL7_1 = 3,      // 7.1 声道
    CHANNEL7_1_2 = 9,    // 7.1.2 声道
    CHANNEL7_1_4 = 10,   // 7.1.4 声道
} NCMVividChannelConfig;
```

### 4.7 数据源模式 (NCMSourceMode)

```cpp
typedef enum {
    kSourceModeNormal = 0,    // 普通模式
    kSourceModePreLoad = 1,   // 预加载模式
} NCMSourceMode;
```

### 4.8 音频处理淡入淡出状态 (AudioFadeStatus)

```cpp
// 文件: cpp/CNCMAudioProcess.h
// 区别于播放器层的 NCMPlayFadeStatus，这是处理层内部使用的淡入淡出状态
enum AudioFadeStatus {
    AudioFadeNone,           // 无淡入淡出
    AudioFadeIn,             // 淡入
    AudioFadeOut,            // 淡出
    AudioFadeCross,          // 交叉淡入淡出
};
```

---


## 5. 核心数据结构

### 5.1 音频描述 (CAudioDescription)

```cpp
// 文件: cpp/CNCMProperty.h
typedef struct {
    uint32_t        nFormatID;        // 格式标识（PCM/MP3/AAC/FLAC）
    uint32_t        nSamplerate;      // 采样率 (44100, 48000, 96000...)
    uint32_t        nChannel;         // 声道数 (1=单声道, 2=立体声)
    uint32_t        nWavFormat;       // 采样格式 (AUSampleFormat)
    uint64_t        nChannelLayout;   // 声道布局掩码
    uint32_t        nSampleBits;      // 每样本位深 (16, 24, 32)
    uint32_t        nReserved;        // 保留字段
} CAudioDescription;
```

### 5.2 音频帧 (CAudioFrame)

```cpp
// 文件: cpp/CNCMProperty.h
typedef struct {
    int             nFlag;            // 帧标志 (CBUFFER_FLAG 组合)
    int             nSize;            // 当前数据大小
    uint8_t*        pBuffer;          // PCM 数据缓冲区
    int64_t         llTime;           // 时间戳 (毫秒)
    int             nDuration;        // 帧时长
    int             nOffset;          // 读取偏移
    int             nSampleNum;       // 样本数
    int             nCapacity;        // 缓冲区容量
    int             nCode;            // 错误码
    int             nFrameBlock;      // 帧块标记
    CAudioDescription audioDescription; // 音频格式信息
    uint8_t*        pConfigData;      // 编码器配置数据
    int             pConfigSize;      // 配置数据大小
    void*           pUserData;        // 用户自定义数据
    void*           pRawData;         // 原始音频数据（多声道）
} CAudioFrame;
```

### 5.3 缓冲区标志 (CBUFFER_FLAG)

```cpp
typedef enum {
    FLAG_BUFFER_NEW_FORMAT  = 0x00000001,  // 音频格式变更
    FLAG_BUFFER_FLUSH       = 0x00000002,  // 需要刷新解码器
    FLAG_BUFFER_TRACK       = 0x00000010,  // 包含多轨数据
    FLAG_BUFFER_RAWDATA     = 0x00000020,  // 包含原始数据
    FLAG_BUFFER_EOS         = 0x00000100,  // 流结束标志
    FLAG_BUFFER_PLAYRATE    = 0x00000200,  // 播放速率变更
    FLAG_BUFFER_TIMERESET   = 0x00000400,  // 时间戳重置
    FLAG_BUFFER_ERROR       = 0x00010000,  // 错误帧
    FLAG_BUFFER_MAX         = 0x7FFFFFFF,  // 最大值
} CBUFFER_FLAG;
```

### 5.4 音频原始数据 (CAudioRawData)

```cpp
typedef struct {
    void*           pRawData;         // 原始音频数据指针
    uint32_t        nRawLen;          // 数据长度
    uint32_t        nSamples;         // 样本数
    uint32_t        nCapacity;        // 容量
    uint32_t        nChannel;         // 声道数
    uint32_t        nWavFormat;       // 采样格式
    uint64_t        nChannelLayout;   // 声道布局
} CAudioRawData;
```

### 5.5 多轨频域数据 (CAudioTrackData)

```cpp
typedef struct {
    float*          pRawFeqData;      // 原始频域数据
    uint32_t        nRawLen;          // 原始数据长度
    float*          pMaskFeqData;     // 掩码频域数据
    uint32_t        nMaskLen;         // 掩码数据长度
} CAudioTrackData;
```

### 5.6 系统音量 (CAudioSystemVolume)

```cpp
typedef struct {
    uint32_t        maxVolume;        // 系统最大音量
    uint32_t        minVolume;        // 系统最小音量
    uint32_t        curVolume;        // 当前系统音量
    uint32_t        nReserved;        // 保留字段
} CAudioSystemVolume;
```

### 5.7 采样格式 (AUSampleFormat)

```cpp
enum AUSampleFormat {
    AU_SAMPLE_FMT_NONE = -1,
    AU_SAMPLE_FMT_U8,        // unsigned 8 bits
    AU_SAMPLE_FMT_S16,       // signed 16 bits (默认格式)
    AU_SAMPLE_FMT_S32,       // signed 32 bits
    AU_SAMPLE_FMT_FLT,       // float
    AU_SAMPLE_FMT_DBL,       // double
    AU_SAMPLE_FMT_U8P,       // unsigned 8 bits, planar
    AU_SAMPLE_FMT_S16P,      // signed 16 bits, planar
    AU_SAMPLE_FMT_S32P,      // signed 32 bits, planar
    AU_SAMPLE_FMT_FLTP,      // float, planar
    AU_SAMPLE_FMT_DBLP,      // double, planar
    AU_SAMPLE_FMT_NB,        // 格式数量
};
```

### 5.8 媒体类型标识

```cpp
static const uint32_t KMediaTypeAudioCodePCM  = MAKEFOURCC('P', 'C', 'M', 'V');
static const uint32_t KMediaTypeAudioCodeMP3  = MAKEFOURCC('M', 'P', '3', 'V');
static const uint32_t KMediaTypeAudioCodeAAC  = MAKEFOURCC('A', 'A', 'C', 'V');
static const uint32_t KMediaTypeAudioCodeFLAC = MAKEFOURCC('F', 'L', 'A', 'C');
```

### 5.9 缓冲策略常量

```cpp
#define CACHE_PACKAGE_DURATION_MAX_LIMIT  15000   // 最大缓存上限 (ms)
#define CACHE_PACKAGE_DURATION_MAX         7000   // 默认最大缓存 (ms)
#define CACHE_PACKAGE_SIGNAL_DURATION      4000   // 信号触发缓存时长 (ms)
#define CACHE_BUFFERING_MIN_DURATION       1000   // 最小缓冲时长 (ms)
#define CACHE_BUFFERING_POP_DURATION       1500   // 弹出缓冲时长 (ms)
#define CACHE_BUFFERING_FIRST_DURATION     2000   // 首次缓冲时长 (ms)

#define KAUDIO_RENDERBUFFER_SIZE  64 * 1024        // 渲染缓冲区大小
#define KMAX_BUFFER_COUNT         3                // 最大缓冲块数
```

---

## 6. 核心接口定义

### 6.1 播放器接口 (INCMPlayer)

播放器的公共 API 接口，所有平台通过此接口控制播放行为。

```cpp
// 文件: cpp/INCMPlayer.h
namespace ncm_audioplayer {

class INCMPlayer {
public:
    // ==================== 数据源管理 ====================
    
    // 设置数据源（首次设置，触发初始化）
    virtual int SetDataSource(INCMSourceIO *source) = 0;
    
    // 设置内容与数据源（支持 Gapless/CrossFade 标志）
    // nFlag: FLAG_PLAYER_SOURCE_GAPLESS | FLAG_PLAYER_SOURCE_CROSSFADE
    virtual int SetContentWithSource(INCMSourceIO *source, int nFlag) = 0;

    // ==================== 播放控制 ====================
    
    // 异步准备（解析音频格式、初始化解码器）
    virtual int PrepareAsync() = 0;
    
    // 播放（可选淡入效果）
    virtual void Play(bool fadein = false) = 0;
    
    // 暂停（可选淡出效果）
    virtual void Pause(bool fadeout) = 0;
    
    // 跳转到指定时间（毫秒），返回实际跳转位置
    virtual int64_t Seek(int64_t time) = 0;
    
    // 停止播放（auto_stop: 0=手动, 1=自动停止）
    virtual void Stop(int auto_stop = 0) = 0;
    
    // 销毁播放器实例
    virtual void Destroy() = 0;
    
    // 重置到初始状态
    virtual int Reset() = 0;

    // ==================== 音量控制 ====================
    
    // 设置音量 (0.0 ~ 1.0)
    virtual int SetVolume(float volume) = 0;
    
    // 设置音量并指定渐变时间（秒）
    virtual int SetVolume(float volume, double interval) = 0;
    
    // 获取当前音量
    virtual float GetVolume() = 0;
    
    // 设置系统音量信息（用于内部音量计算）
    virtual void SetAudioSystemVolume(int maxVolume, int minVolume, int curVolume) = 0;

    // ==================== 状态查询 ====================
    
    // 获取播放器状态 (NCMPlayStatus)
    virtual int GetState() = 0;
    
    // 获取当前播放位置（毫秒）
    virtual int64_t GetPlayingTime() = 0;
    
    // 获取指定歌曲的播放结束时间
    virtual int64_t GetPlayEndTime(string songID) = 0;
    
    // 获取指定歌曲的已播放时长
    virtual int64_t GetPlayedTime(string songID) = 0;
    
    // 获取指定歌曲已播放时长（考虑变速）
    virtual int64_t GetPlayedTimeWithSpeed(string songID) = 0;
    
    // 获取音频总时长（毫秒）
    virtual int64_t GetDuration() = 0;
    
    // 设置获取播放时间的方式
    virtual void SetGetPlayedTimeType(int nType) = 0;
    
    // 是否正在缓冲
    virtual bool IsBuffering() = 0;

    // ==================== 淡入淡出设置 ====================
    
    // 设置播放开始淡入时间（毫秒）
    virtual void SetStartFadeTime(int64_t time) = 0;
    
    // 设置暂停淡出时间（毫秒）
    virtual void SetPauseFadeTime(int64_t time) = 0;
    
    // 设置交叉淡入淡出时间（毫秒）
    virtual void SetCrossFadeTime(int64_t time) = 0;

    // ==================== 音频处理 ====================
    
    // 设置音效处理器 (IAudioEffects*)
    virtual void SetAudioEffect(void* audio_effect) = 0;
    
    // 设置音频监听器 (IAudioListener*)
    virtual void SetAudioListener(void* audio_listener) = 0;
    
    // 设置播放速度 (0.5 ~ 2.0)
    virtual bool SetPlaySpeed(double speed) = 0;
    
    // 设置缓冲区长度（毫秒）
    virtual void SetBufferLength(int64_t time) = 0;
    
    // 启用浮点 PCM 输出
    virtual void EnableFloatPCM(bool enable) = 0;

    // ==================== AI 音频超分 ====================
    
    // 设置 AI 超分开关 (0=关, 1=开)
    virtual void SetAudioIFEnable(int nStatus) = 0;
    
    // 设置 AI 超分处理器
    virtual void SetAudioIFProcess(void* audio_if_process) = 0;
    
    // 设置 AI 超分比率
    virtual void SetAudioIFRatio(int nRatio) = 0;

    // ==================== 卡拉OK模式 ====================
    
    // 设置人声模式 (NCMMusicMode)
    virtual void SetMusicVoiceMode(int nMode) = 0;
    
    // 设置人声音量 (0.0 ~ 1.0)
    virtual void SetVoiceVolume(float curVolume) = 0;
    
    // 设置伴奏音量 (0.0 ~ 1.0)
    virtual void SetBackMusicVolume(float curVolume) = 0;

    // ==================== Audio Vivid ====================
    
    // 设置播放回放模式 (NCMPlayBackMode)
    virtual void SetPlaybackMode(int playbackMode) = 0;
    
    // 设置 Vivid 解码信息
    // modePath: 模型文件路径
    // channelConfig: 声道配置
    // nChanmapIdx: 声道映射索引
    virtual void SetVividDecInfo(string modePath, string channelConfig, int nChanmapIdx) = 0;

    // ==================== 音频设备 ====================
    
    // 设置音频设备类型 (AudioDeviceType_AudioTrack / AudioDeviceType_USBAudio 等)
    virtual void SetAudioDeviceType(int audiodeviceType) = 0;
    
    // 获取音频设备类型
    virtual int GetAudioDeviceType() = 0;
    
    // 获取音频延迟（毫秒）
    virtual int GetAudioLatence() = 0;
    
    // 获取 AudioSession ID
    virtual int GetAudioSessionId() = 0;
    
    // 获取音频渲染格式信息
    virtual void GetAudioRenderFormatInfo(int& sampleRate, int& channel, int& format) = 0;
    
    // 设置耳机类型 (0=普通, 1=蓝牙)
    virtual void SetHeadSetType(int headSetType) = 0;
    
    // 获取 AudioTrack 对象（Android，返回 Java 对象引用）
    virtual int64_t GetAudioTrack() = 0;

    // ==================== 缓冲与缓存 ====================
    
    // 设置播放缓存参数
    virtual void SetPlaybackCacheParams(double cache_min, double cache_max,
                                        double buffering_min, double buffering_max) = 0;
    
    // 设置解码器黑名单
    virtual void SetBlackCodecIds(const std::vector<int> ids) = 0;

    // ==================== 通知与测量 ====================
    
    // 设置位置变更通知间隔（毫秒）
    virtual void setPositionNotification(int periodicInMS) = 0;
    
    // 设置最小位置通知间隔（毫秒）
    virtual void setPositionMinNotification(int periodicInMinMS) = 0;
    
    // 启用音量测量
    virtual void setMeteringEnabled(bool meteringEnabled) = 0;
    
    // 更新测量数据
    virtual void updateMeters() = 0;
    
    // 获取指定声道峰值功率
    virtual float peakPowerForChannel(int channelNumber) = 0;
    
    // 获取指定声道平均功率
    virtual float averagePowerForChannel(int channelNumber) = 0;
    
    // 获取整体峰值功率
    virtual float peakPower() = 0;
    
    // 获取整体平均功率
    virtual float averagePower() = 0;

    // ==================== 调试 ====================
    
    // 清除消息队列
    virtual void clearMessage() = 0;
    
    // 设置 PCM Dump 输出路径
    virtual void SetDumpUrl(const char* dumpUrl) = 0;
};

// ==================== 工厂类 ====================

class CMediaPlayerFactory {
public:
    // 创建播放器实例
    static INCMPlayer* NewL(INCMPlayerObserver* aPlayerObserver);
};

}
```

### 6.2 数据源接口 (INCMSourceIO)

```cpp
// 文件: cpp/INCMSourceIO.h
namespace ncm_audioplayer {

class INCMSourceIO {
public:
    // 数据源操作状态码
    enum AudioSourceCode {
        ASC_BUSY = -2,              // 数据源忙
        ASC_EOF = -1,               // 已到末尾
        ASC_SUCCESS = 0,            // 成功
        ASC_PARAM_ERROR = 1,        // 参数错误
        ASC_OPEN_NOT_EXIST,         // 文件不存在
        ASC_OPEN_NOT_READ_ERROR,    // 无法读取
        ASC_READ_ERROR,             // 读取错误
        ASC_IO_EXCETPION,           // IO 异常
        ASC_SEEK_ERROR,             // 跳转错误
        ASC_ABORT,                  // 操作中断
        ASC_CLOSE,                  // 已关闭
    };

    virtual ~INCMSourceIO() {}
    
    // 获取会话 ID
    virtual int SessionId() = 0;
    
    // 打开数据源
    virtual int Open() = 0;
    
    // 读取数据到缓冲区
    virtual int64_t Read(unsigned char *buffer, unsigned long* size) = 0;
    
    // 跳转到指定偏移量
    virtual int64_t Seek(int64_t* offset, unsigned long origin) = 0;
    
    // 获取音频增益值
    virtual double GetGain() = 0;
    
    // 停止读取
    virtual void Stop() = 0;
    
    // 中断操作
    virtual void Abort() = 0;
    
    // 关闭数据源
    virtual void Close() = 0;
    
    // 获取数据总大小
    virtual int64_t Size() = 0;
    
    // 获取已缓存大小
    virtual int64_t CacheSize() const = 0;
    
    // 是否支持快速跳转
    virtual bool SupportFastSeek() = 0;
    
    // 获取最后错误码
    virtual unsigned long GetLastError() = 0;
    
    // 获取数据源标识（歌曲 ID）
    virtual std::string GetId() = 0;
    
    // 设置数据源模式 (NCMSourceMode)
    virtual void SetSourceMode(int modeType) = 0;
};

}
```

---

## 7. 观察者接口 (Observer Pattern)

项目使用观察者模式实现各模块间的异步通信，共定义四种观察者接口。

### 7.1 播放器观察者 (INCMPlayerObserver)

```cpp
// 文件: cpp/INCMObserver.h
class INCMPlayerObserver {
public:
    // 播放器事件通知
    // aMsg: MessageType 枚举值
    // aSourceID: 歌曲 ID
    // aArg1, aArg2: 附加参数
    virtual void PlayerNotifyEvent(int aMsg, std::string aSourceID, int aArg1, int aArg2) = 0;
};
```

### 7.2 解码流观察者 (INCMStreamObserver)

```cpp
class INCMStreamObserver {
public:
    // 开始缓冲
    virtual void BufferStart(std::string songID, int sourceID) = 0;
    
    // 缓冲完成
    virtual void BufferEnd(std::string songID, int sourceID) = 0;
    
    // 缓冲数据包计数
    virtual void BufferCount(std::string songID, int count) = 0;
    
    // Seek 操作完成
    virtual void SeekDone(std::string songID, int nCode) = 0;
    
    // 解码流事件通知
    virtual void StreamEvent(int aMsg, std::string songID, int aArg1, int aArg2) = 0;
};
```

### 7.3 音频处理观察者 (INCMProcessObserver)

```cpp
class INCMProcessObserver {
public:
    // 淡入淡出完成回调
    virtual void FadeFinish(std::string songID, int fadeType) = 0;
    
    // 填充处理帧数据（从解码帧队列拉取数据）
    virtual int FillProcessFrame(void* buffer, int& inlen, int64_t &time, int &nFlag) = 0;
    
    // 更新缓冲区时长
    virtual void UpdataBufferDuration(int64_t time) = 0;
};
```

### 7.4 音频设备观察者 (INCMDeviceObserver)

```cpp
class INCMDeviceObserver {
public:
    // 填充渲染缓冲区（设备回调拉取 PCM 数据）
    virtual int BufferFill(void* buffer, int& inlen, int64_t &time) = 0;
    
    // 填充渲染帧（帧模式）
    virtual int FrameFill(CAudioFrame* dstBuffer) = 0;
    
    // 设备错误通知
    virtual void DeviceError(int nCode) = 0;
    
    // 设备事件通知
    virtual void DeviceEvent(int aMsg, int aArg1 = 0, int aArg2 = 0) = 0;
};
```

### 7.5 观察者关系图

```
┌─────────────────────────────────────────────────────────────────┐
│                    CNCMAudioPlayer                               │
│  实现了: INCMStreamObserver + INCMDeviceObserver +               │
│         INCMProcessObserver                                      │
│                                                                  │
│  持有: INCMPlayerObserver* (上层回调)                            │
└─────────────────────┬────────────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
┌──────────────┐ ┌──────────┐ ┌──────────┐
│CNCMAudioStream│ │CNCMAudio │ │AudioDevice│
│ ↑回调Stream- │ │ Process  │ │ ↑回调     │
│  Observer    │ │ ↑回调    │ │ Device-   │
│              │ │ Process- │ │ Observer  │
│              │ │ Observer │ │           │
└──────────────┘ └──────────┘ └──────────┘

数据流向:
Stream → [BufferStart/End/Count/StreamEvent] → Player
Process → [FadeFinish/FillProcessFrame/UpdateDuration] → Player
Device → [BufferFill/FrameFill/DeviceError/DeviceEvent] → Player
Player → [PlayerNotifyEvent] → Application Layer
```


---

## 8. 消息系统 (MessageType)

播放器内部通过消息线程实现异步控制，所有消息类型定义在 `INCMMsgType.h` 中。

### 8.1 完整消息类型定义

```cpp
// 文件: cpp/INCMMsgType.h
enum MessageType {
    // ====== 播放器事件通知（上报给应用层） ======
    AMsgPlayPrepared      = 1,     // 准备完成，可以播放
    AMsgPlayEOS           = 2,     // 播放到文件末尾
    AMsgBufferingUpdate   = 3,     // 缓冲进度更新
    AMsgSeekCompleted     = 4,     // Seek 操作完成
    AMsgFristFrame        = 5,     // 首帧渲染完成
    AMsgAudioFormat       = 6,     // 音频格式信息
    AMsgAudioDuration     = 7,     // 音频时长信息
    AMsgAudioOffset       = 8,     // 音频偏移信息

    // ====== 播放器控制命令（内部线程调度） ======
    AMsgInitStart         = 10,    // 初始化开始
    AMsgPreparing         = 11,    // 准备中
    AMsgPlaying           = 12,    // 播放命令
    AMsgPause             = 13,    // 暂停命令
    AMsgStop              = 14,    // 停止命令
    AMsgReset             = 15,    // 重置命令
    AMsgSeeking           = 16,    // Seek 命令
    AMsgPreload           = 17,    // 预加载命令
    AMsgDeviceCreate      = 18,    // 创建音频设备
    AMsgFadeFinish        = 19,    // 淡入淡出完成
    AMsgDoSeekCompleted   = 20,    // 内部 Seek 完成处理
    AMsgDoSetFadeVolume   = 21,    // 设置淡入淡出音量
    AMsgDoReSetCrossFade  = 22,    // 重置交叉淡入淡出
    AMsgDoSetCacheParams  = 23,    // 设置缓存参数
    AMsgAudioDeviceChanged= 24,    // 音频设备变更
    AMsgAudioDeviceVolume = 25,    // 设备音量变更
    AMsgHeadSetChanged    = 26,    // 耳机状态变更（插拔/蓝牙）
    AMsgAIIFProcess       = 27,    // AI 超分处理事件
    AMsgSetSpeed          = 28,    // 设置播放速度

    // ====== 解码器消息 ======
    AMsgDecoder           = 50,    // 解码命令
    AMsgDecSeek           = 51,    // 解码器 Seek
    AMsgDecIF             = 52,    // AI 超分解码

    // ====== 音频处理消息 ======
    AMsgProcess           = 60,    // 处理命令
    AMsgProcessFlush      = 61,    // 刷新处理管线
    AMsgProcessUpdate     = 62,    // 处理状态更新

    // ====== 渲染消息 ======
    AMsgRender            = 80,    // 渲染命令
    AMsgRenderFlush       = 81,    // 刷新渲染缓冲
    AMsgRenderPause       = 82,    // 渲染暂停

    // ====== 错误消息 ======
    AMsgError             = 100,   // 错误通知
    AMsgFrameError        = 101,   // 帧错误

    // ====== 缓冲信息 ======
    AMsgBufferingInfo     = 200,   // 缓冲信息 (MEDIA_INFO_BUFFERING_START/END)

    // ====== 状态变更 ======
    AMsgStatusChanged     = 300,   // 播放状态变更

    // ====== 预加载状态 ======
    AMsgPreLoadStatus     = 400,   // 预加载状态通知

    // ====== USB 音频 ======
    AMsgUSBAudioStatus    = 500,   // USB 音频状态

    // ====== AI 超分状态 ======
    AMsgAudioIFStatus     = 600,   // AI 超分处理状态
    AMsgAudioIFTime       = 601,   // AI 超分处理耗时

    // ====== 解码性能 ======
    AMsgDecFrameTime      = 800,   // 单帧解码耗时
    AMsgDecThreadTime     = 801,   // 解码线程耗时

    // ====== AudioTrack 变更 ======
    AMsgAudioTrackChanged = 1000,  // AudioTrack 切换

    // ====== 播放位置通知 ======
    AMsgAudioPositionChanged    = 2000,  // 位置变更通知
    AMsgAudioLastPosition       = 2001,  // 最后播放位置
    AMsgAudioPositionMinChanged = 2002,  // 最小精度位置通知

    // ====== 渲染性能 ======
    AMsgAudioRenderTimeRatio    = 3000,  // 渲染时间比率
    AMsgAudioRenderLagTime      = 3001,  // 渲染延迟时间
    AMsgAudioRenderBlockTime    = 3002,  // 渲染阻塞时间

    // ====== USB 传输异常 ======
    AMsgAudioUSBTransferTimeout = 5000,  // USB 传输超时
    AMsgAudioUSBTransferError   = 5001,  // USB 传输错误

    // ====== 资源释放 ======
    AMsgRelease           = 1219,  // 释放资源
};
```

### 8.2 消息分类概览

| 类别 | 消息范围 | 说明 |
|------|----------|------|
| 播放器事件 | 1-8 | 上报给应用层的事件 |
| 控制命令 | 10-28 | Player 内部控制线程消息 |
| 解码器 | 50-52 | 解码线程消息 |
| 音频处理 | 60-62 | 处理线程消息 |
| 渲染 | 80-82 | 渲染线程消息 |
| 错误 | 100-101 | 错误消息 |
| 缓冲信息 | 200 | 缓冲状态 |
| 状态变更 | 300 | 状态机通知 |
| 预加载 | 400 | 预加载状态 |
| USB 音频 | 500 | USB 设备状态 |
| AI 超分 | 600-601 | AI 处理状态和耗时 |
| 解码性能 | 800-801 | 解码性能监控 |
| AudioTrack | 1000 | AudioTrack 变更 |
| 位置通知 | 2000-2002 | 播放位置回调 |
| 渲染性能 | 3000-3002 | 渲染性能监控 |
| USB 传输 | 5000-5001 | USB 传输异常 |
| 资源释放 | 1219 | 资源释放 |

---

## 9. 错误码定义

```cpp
// 文件: cpp/INCMErrDefs.h
const int kAudioPlayerSuccess              = 0;   // 成功
const int kAudioPlayerIOError              = 1;   // SourceIO 错误
const int kAudioPlayerUnSupportStreamFormat = 2;  // 不支持的文件格式
const int kAudioPlayerUnkownOpenStreamError = 3;  // 打开文件失败
const int kAudioPlayerNoAudioStreamInfo    = 4;   // 没有音频流信息
const int kAudioPlayerUnSupportAuidoCodec  = 5;   // 不支持的编码格式
const int kAudioPlayerOpenAudioCodecError  = 6;   // 解码器打开失败
const int kAudioPlayerSeekUnkownError      = 7;   // Seek 失败
const int kAudioPlayerUSBAudioError        = 8;   // USB 音频设备错误
const int kAudioPlayerAudioDeviceError     = 9;   // 音频设备打开失败
const int kAudioPlayerAudioDecodeUnkown    = 10;  // 未知解码错误
const int kAudioPlayerUnkown               = 11;  // 未知播放错误
const int kAudioPlayerErrorState           = 12;  // 错误的状态操作
const int kAudioPlayerErrorDuration        = 13;  // 获取 Duration 失败
const int kAudioPlayerErrorSwr             = 14;  // 重采样失败
const int kAudioPlayerErrorIORead          = 15;  // SourceIO 读取失败
const int kAudioPlayerErrorNoMemory        = 16;  // 内存分配失败
const int kAudioPlayerErrorFilePath        = 17;  // 错误的文件路径
const int kAudioPlayerEOS                  = 18;  // 播放完成
const int kAudioPlayerBufferEmpty          = 19;  // 缓存为空
const int kAudioPlayerAudioFormatChanged   = 20;  // 音频格式切换
const int kAudioPlayerSourceAbout          = 21;  // Source 被取消
const int kAudioPlayerAIInitError          = 22;  // AI 初始化错误
const int kAudioPlayerAIOverTime           = 23;  // AI 处理超时
const int kAudioPlayerVividModeError       = 24;  // Vivid 模式错误
```


---

## 10. 核心类详解

### 10.1 CNCMAudioPlayer — 播放器核心

```
文件: cpp/CNCMAudioPlayer.cpp/.h
继承: INCMPlayer, INCMStreamObserver, INCMDeviceObserver, INCMProcessObserver
```

播放器核心类，负责：
- **状态机管理**：管理 NCMPlayStatus 状态转换
- **双线程调度**：MsgThread（事件通知线程）+ ControlThread（播放控制线程）
- **多数据源管理**：支持当前数据源、预加载数据源、淡入淡出数据源三路并行
- **Gapless/CrossFade 逻辑**：无缝衔接和交叉淡入淡出的完整实现
- **观察者中枢**：作为 Stream/Process/Device 的观察者，汇聚所有事件并向上层分发

**关键成员变量：**

| 变量 | 类型 | 说明 |
|------|------|------|
| `mMsgThread` | CNCMMsgThread* | 事件通知消息线程 |
| `mControlThread` | CNCMMsgThread* | 播放控制消息线程 |
| `mSource` / `mPreSource` / `mFadeSource` | unique_ptr\<INCMSourceIO\> | 当前/预加载/淡入淡出数据源 |
| `mAudioStream` / `mAudioPreLoadStream` / `mAudioFadeStream` | unique_ptr\<CNCMAudioStream\> | 三路解码流 |
| `mAudioDevices` | AudioDevice* | 音频设备实例 |
| `mAudioProcess` | CNCMAudioProcess* | 音频处理器 |
| `mAudioTimeInfo` | CNCMAudioTimeInfo* | 时间管理器 |
| `mPlayerObserver` | INCMPlayerObserver* | 上层回调 |
| `mStatus` | int | 当前状态 (NCMPlayStatus) |
| `mFadeStatus` | int | 淡入淡出状态 (NCMPlayFadeStatus) |
| `mCrossFadeTime` | int64_t | 交叉淡入淡出时间 |
| `mPlaySpeed` | double | 播放速度 |
| `mNEAiAudioIF` | void* | AI 超分处理器指针 |

**关键内部方法（protected）：**

```cpp
// 播放控制
int  doInitStart();                    // 初始化启动
int  doPrepareAsync();                 // 异步准备
int  doPlay(bool fadeIn);              // 执行播放
int  doPause(bool fadeOut);            // 执行暂停
int  doSeek(int64_t time);             // 执行跳转
int  doStop();                         // 执行停止
int  doReset();                        // 执行重置

// 音频设备
int  doDeviceOpen(int64_t time, bool forceSeek = false);  // 打开设备
void doDeviceChanged(int audiodeviceType);                 // 设备变更
int  doDeviceReCreate(int audiodeviceType);                // 重新创建设备
void doHeadSetChanged(int headSetType);                    // 耳机状态变更

// Gapless & CrossFade
int  doGaplessSource();                // 处理 Gapless 下一曲
int  doNextSource();                   // 切换到下一数据源
int  doCrossFadeSource();              // 处理 CrossFade
void doResetFadeSource();              // 重置淡入淡出数据源
int  doSetContentWithSource(int nFlag); // 设置内容数据源

// 淡入淡出
int  doFadeFinish(string songID, int fadeType); // 淡入淡出完成
void doSetFadeVolume(int fadeMsg = 0);           // 设置淡入淡出音量

// 缓冲
void doSetCacheParams();               // 设置缓存参数
void doSetSystemVolume();              // 设置系统音量
void doAudioSpeed();                   // 设置播放速度

// 数据填充（设备回调）
virtual int doBufferFill(void* buffer, int& inlen, int64_t &time, int &nFlag);
virtual int doCrossBufferFill(void* buffer, int& inlen, int64_t &time);
virtual void doCrossBufferMix(void* buf1, int inlen1, void* buf2, int inlen2);

// AI 超分
void doAIIFProcess();                  // AI 超分处理

// 消息处理
static void OnMsgFunc(void* obj, shared_ptr<ThreadMsg>);
void doMsgFunc(shared_ptr<ThreadMsg>);
static void OnControlFunc(void* obj, shared_ptr<ThreadMsg>);
void doControlFunc(shared_ptr<ThreadMsg>);
```

### 10.2 CNCMAudioStream — 解码管线

```
文件: cpp/CNCMAudioStream.cpp/.h
依赖: CNCMFFDecoder, CNCMAudioNormlizer, INEAIAudioBase
```

负责音频数据的解码、格式归一化和帧队列管理。

**核心功能：**
- 管理 FFmpeg 解码器（CNCMFFDecoder）
- 管理音频格式归一化（CNCMAudioNormlizer）
- AI 音频超分处理（INEAIAudioBase）
- 解码帧队列管理（生产者-消费者模型）
- 缓冲策略控制

**关键方法：**

```cpp
// 数据源管理
int open(const char* filePath, int type);        // 文件路径方式打开
int openSource(INCMSourceIO *source, int type);  // Source 方式打开

// 播放控制
int start();           // 启动解码线程
void pause();          // 暂停解码
void resume();         // 恢复解码
int stop();            // 停止解码
void abort();          // 中断
int close();           // 关闭

// 数据读取
int bufferFill(void* buffer, int& inlen, int64_t &time);   // PCM 缓冲填充
int frameFill(CAudioFrame* dstBuffer);                       // 帧数据填充
int bufferFillLen(void* buffer, int& inlen, int64_t &time); // 指定长度填充

// Seek
int seek(int64_t time, int nFlag = 0);

// 格式查询
void getAudioDescription(CAudioDescription &audioDescription);
void setAudioDescription(CAudioDescription audioDescription);
int64_t getDuration();
string getSourceID();
double GetGain();

// AI 超分
int SetAudioIFEnable(int nEnable);
void SetAudioIFProcess(void* audio_if_process);
void SetAudioIFRatio(int nRatio);
int GetAudioIFEnable();
int getAudioIFTime();

// 卡拉OK
void SetMusicVoiceMode(int nMode);
void SetVoiceVolume(float curVolume);
void SetBackMusicVolume(float curVolume);

// 缓存设置
void SetPlaybackCacheParams(int64_t cache_min, int64_t cache_max,
                            int64_t buffering_min, int64_t buffering_max);
void setStepSize(int stepSize);
void setBufferLength(int64_t time);
void setProcessBufferTime(int64_t time);

// Audio Vivid (静态方法)
static void SetVividDecInfo(string modePath, string channelConfig, int nChanmapIdx);
static void SetBlackCodecIds(const std::vector<int>& ids);
```

### 10.3 CNCMAudioTrackStream — 多轨音频流

```
文件: cpp/CNCMAudioTrackStream.cpp/.h
继承: CNCMAudioStream
```

在解码管线基础上增加了 **STFT 频域处理** 能力，支持实时多轨音频分析。用于卡拉OK模式下的人声/伴奏分离。

**核心原理：**
1. 解码后的 PCM 数据进行 STFT（短时傅里叶变换）
2. 在频域上进行人声/伴奏的频谱分离
3. 通过掩码 (mask) 分别提取人声和伴奏
4. ISTFT 合成回时域，调整各自音量

### 10.4 CNCMAudioKaraokeStream — 卡拉OK流

```
文件: cpp/CNCMAudioKaraokeStream.cpp/.h
继承: CNCMAudioStream (推测)
```

专门用于卡拉OK模式的流处理，支持 AI 模型驱动的实时人声分离。

### 10.5 CNCMAudioProcess — 音频处理器

```
文件: cpp/CNCMAudioProcess.cpp/.h
依赖: IAudioEffects, TempoProcessor, IAudioListener
```

负责解码后音频数据的后处理管线。

**核心功能：**
- 音效处理（IAudioEffects）
- 变速处理（TempoProcessor）
- 音频监听（IAudioListener）
- 淡入淡出处理（AudioFadeStatus）
- 播放时间统计

**关键方法：**

```cpp
// 打开/关闭
int open(const std::string& songID);
int close();
int start();

// 音频处理
int processAudio(void* data, int& length, int64_t time, int maxLength, int& eos);
int processFrame(CAudioFrame* dstBuffer);
void processFade(int length);

// 音效设置
void SetAudioEffect(void* audio_effect);    // 设置音效
void SetAudioListener(void* audio_listener); // 设置监听
bool SetPlaySpeed(double speed);             // 设置速度

// 淡入淡出
void SetFadeTime(int64_t fadeTime);
void setFadeStatus(AudioFadeStatus aStatus);
AudioFadeStatus getFadeStatus();
float getFadeScale();

// 时间管理
int64_t GetFrameTime();
int64_t GetPlayEndTime(const string& songID);
int64_t GetPlayedTime(const string& songID);
int64_t GetPlayedTimeWithSpeed(const string& songID);
int64_t GetCurPlayEndTime();
int64_t GetCurPlayedTime();
int64_t GetCurPlayedTimeWithSpeed();
int64_t GetFadeOutStepTime();
int64_t GetFadeOutStepSize();
```

### 10.6 CNCMAudioTimeInfo — 时间管理器

```
文件: cpp/CNCMAudioTimeInfo.cpp/.h
```

专门管理播放时间相关的信息，包括当前播放位置、已播放时长、各种时间通知等。被 CNCMAudioPlayer 持有，用于精确的时间追踪和上报。

### 10.7 CNCMAudioNormlizer — 格式归一化

```
文件: cpp/CNCMAudioNormlizer.cpp/.h
```

音频格式归一化/重采样处理器。用于将解码器输出的各种格式（不同采样率、声道数、位深）统一转换为设备需要的目标格式。

**使用场景：**
- 不同采样率歌曲切换时的重采样（如 44100Hz → 48000Hz）
- 多声道到立体声的 Downmix
- 位深转换（如 24bit → 16bit）
- AI 超分后的格式适配

### 10.8 CNCMAudioLocalSource — 本地数据源

```
文件: cpp/CNCMAudioLocalSource.cpp/.h
实现: INCMSourceIO
```

本地文件的数据源实现，通过标准文件 I/O 读取本地音频文件。

### 10.9 CNCMAudioSourceIO — 通用数据源

```
文件: cpp/CNCMAudioSourceIO.cpp/.h
实现: INCMSourceIO
```

通用数据源封装，可能用于适配不同来源的数据（如网络流、加密文件等）。

### 10.10 CNCMFFDecoder — FFmpeg 解码器

```
文件: cpp/CNCMFFDecoder.cpp/.h
```

封装 FFmpeg 的音频解码功能。支持 MP3、AAC、FLAC、OGG 等常见格式。

**核心功能：**
- 音频文件打开与格式探测
- 音频流信息获取（采样率、声道数、时长）
- 逐帧解码
- Seek 操作
- 编解码器黑名单

### 10.11 CVividDec — Audio Vivid 解码器

```
文件: cpp/dec/CVividDec.cpp/.h
```

Audio Vivid 沉浸式音频解码器。支持 5.1、7.1、7.1.2、7.1.4 等多声道配置。

### 10.12 CAudioDec — 解码器基类

```
文件: cpp/dec/CAudioDec.cpp/.h
```

音频解码器抽象基类，定义解码器的通用接口。


---

## 11. 音频设备层

### 11.1 AudioDevice — 设备抽象基类

```
文件: cpp/CNCMAudioDevice.cpp/.h
继承: AudioDriverInfo, AudioDeviceInfo
```

音频设备的抽象基类，定义了所有平台设备的统一接口。

**设备类型宏定义：**

```cpp
// Android
#define AudioDeviceType_AudioTrack   0   // Android AudioTrack 设备
#define AudioDeviceType_USBAudio     1   // Android USB 音频设备

// Apple (iOS/macOS)
#define AudioDeviceType_AudioQueue   0   // iOS AudioQueue 设备
#define AudioDeviceType_AudioBuffer  1   // iOS AudioBuffer 渲染设备
```

**设备状态：**

```cpp
enum PlayState {
    kPlaying = 1,    // 播放中
    kPause,          // 已暂停
    kStop,           // 已停止
};

enum DeviceState {
    kDeviceFormatSupportError = -6,  // 格式不支持
    kDeviceOpenError = -5,           // 打开失败
    kDevicePrepareBufferError = -4,  // 缓冲区准备失败
    kDevicePlayError = -3,           // 播放失败
    kDeviceWaitError = -2,           // 等待失败
    kDeviceCloseError = -1,          // 关闭失败
    kDeviceSuccess = 0,              // 成功
};
```

**完整接口方法：**

```cpp
class AudioDevice {
public:
    // 设备能力
    virtual int Support() = 0;
    static std::list<AudioDeviceInfo> EnumDevices();

    // 生命周期
    virtual int Init() = 0;
    virtual void Destroy() = 0;
    virtual int Open(int id, CAudioDescription* input) = 0;
    virtual int Close() = 0;

    // 播放控制
    virtual int Play() = 0;
    virtual int Pause(int type = 0) = 0;  // 0=正常暂停, 1=结束暂停, 2=重置暂停
    virtual int Stop() = 0;

    // 音量
    virtual void SetVolume(float volume) = 0;
    virtual void SetVolume(float volume, double interval) = 0;
    virtual void SetSystemVolume(int maxVolume, int minVolume, int curVolume) {}

    // 时间与位置
    virtual int64_t GetPostion() = 0;
    virtual int Seek(int64_t time) = 0;

    // 速度
    virtual void SetPlaySpeed(float speed);

    // 格式查询
    virtual void GetAudioRenderFormat(CAudioDescription* param, bool *need_resample);
    virtual void GetAudioInputFormat(CAudioDescription* input);

    // 设备信息
    virtual int GetAudioDeviceType() = 0;
    virtual int GetRenderStepSize() = 0;
    virtual int GetSessionId() = 0;
    virtual int64_t GetAudioBlockTime();
    virtual int64_t GetAudioTimeOffset();

    // 声道处理
    virtual uint64_t ChannelLayoutExtractChannel(uint64_t channel_layout, int index);
    virtual uint16_t GetChannelsByLayout(uint64_t layout);

    // 音量测量
    virtual void  setMeteringEnabled(bool meteringEnabled);
    virtual void  updateMeters();
    virtual float peakPowerForChannel(int channelNumber);
    virtual float averagePowerForChannel(int channelNumber);
    virtual float peakPower();
    virtual float averagePower();
    virtual int64_t getAudioTrack();

    // 缓冲刷新
    virtual void Flush() = 0;

    // 观察者
    virtual void SetOberver(INCMDeviceObserver* aObserver);

    // 播放模式
    virtual void SetPlaybackMode(int playbackMode);

    // 浮点 PCM
    static void EnableFloatPCM(bool enable);
};
```

### 11.2 CAudioDeviceFactory — 设备工厂

```cpp
class CAudioDeviceFactory {
public:
    static AudioDevice* NewAudioDevice(int &DeviceType);
};
```

根据平台和设备类型自动创建合适的音频设备实例。

### 11.3 Android 音频设备实现

#### AudioDeviceAudioTrack (audio_track.cpp/.h)
高层 AudioTrack 封装，包含：
- 渲染线程管理
- AudioTrack 创建/配置/释放
- PCM 数据写入

#### audio_device_android_audiotrack.cpp/.h
底层 Android AudioTrack JNI 封装，直接调用 Java `AudioTrack` API。

#### USBAudioDevice (usb_audio_device.cpp/.h)
USB 音频设备实现，基于 libusb + UAC (USB Audio Class)。

### 11.4 iOS 音频设备实现

#### CNCMAudioQueueDevice (CNCMAudioQueueDevice.h/.mm)
基于 AudioQueue 的音频输出设备。使用 AudioQueueNewOutput + AudioQueueEnqueueBuffer 实现回调驱动的音频渲染。

#### CNCMAudioBufferRenderImpl (CNCMAudioBufferRenderImpl.h/.mm)
AudioBuffer 渲染器实现，提供另一种音频输出方式。

### 11.5 macOS 音频设备实现

#### NTESMAudioOutputDevice (NTESMAudioOutputDevice.h/.m)
macOS 音频输出设备。

#### NTESMAudioOutputManager (NTESMAudioOutputManager.h/.m)
macOS 音频输出管理器，管理设备选择和切换。

---

## 12. 平台接口层

### 12.1 Android 接口 (JNI)

#### AudioPlayerJNI (audio_player_jni.cpp)
JNI 入口，负责 JNI_OnLoad 方法注册和 Java ↔ C++ 方法映射。

#### AndroidAudioPlayer (android_audioplayer.cpp/.h)
Android 平台的播放器封装类，将 Java 调用转换为 INCMPlayer 接口调用。

```
Java 层
  │
  ├── JNI_OnLoad() → 注册 native 方法
  ├── nativeCreate() → CMediaPlayerFactory::NewL()
  ├── nativeSetDataSource() → player->SetDataSource()
  ├── nativePrepareAsync() → player->PrepareAsync()
  ├── nativePlay() → player->Play()
  ├── nativePause() → player->Pause()
  ├── nativeSeek() → player->Seek()
  ├── nativeStop() → player->Stop()
  └── ...
```

#### AudioSourceAndroid (audio_source_android.cpp/.h)
Android 数据源实现（实现 INCMSourceIO 接口），通过 JNI 回调 Java 层的 SourceIO 读取数据。

### 12.2 iOS/macOS 接口

#### NTESMAudioPlayer (NTESMAudioPlayer.h/.mm)
Objective-C++ 播放器封装类。

```objc
@interface NTESMAudioPlayer : NSObject

// 播放控制
- (void)play;
- (void)pause;
- (void)stop;
- (int64_t)seek:(int64_t)time;

// 数据源
- (void)setDataSource:(id<NTESMSourceIO>)source;

// 属性
@property (nonatomic, readonly) int64_t duration;
@property (nonatomic, readonly) int64_t currentTime;
@property (nonatomic, assign) float volume;
@property (nonatomic, assign) double playSpeed;

@end
```

#### NTESMSourceIO (NTESMSourceIO.h)
iOS/macOS 数据源协议。

#### CNTESMSource (CNTESMSource.h/.mm)
将 ObjC 协议适配为 C++ INCMSourceIO 接口。

---

## 13. 第三方依赖

| 依赖库 | 路径 | 说明 |
|--------|------|------|
| **FFmpeg** | `ext/ffmpeg/` | 音频解码基础库（libavcodec, libavformat, libswresample 等） |
| **audiocommon** | `ext/audiocommon/` | 音频通用算法库（FFT 变换、SVM 分类等） |
| **audiovivid** | `ext/audiovivid/` | Audio Vivid 沉浸式音频解码库 |
| **audiosr** | `ext/audiosr/` | AI 音频超分基础接口（NEAudioSR） |
| **effects** | `ext/effects/` | 音效处理库（IAudioEffects 接口、TempoProcessor） |
| **tempofx** | `ext/tempofx/` | 变速不变调处理库 |
| **nblog4c** | `ext/nblog4c/` | 跨平台日志库 |
| **neaudioaiinference** | `ext/neaudioaiinference/` | AI 音频推理引擎（模型推理、人声分离、超分等） |
| **nm_common_cache** | `ext/nm_common_cache/` | 通用缓存模块（支持 Android/iOS/Mac 三端） |

---

## 14. 线程模型

### 14.1 线程概览

播放器内部使用多个线程协同工作：

```
┌─────────────────────────────────────────────────────────────┐
│                    Thread Architecture                       │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │   MsgThread           │  │   ControlThread       │         │
│  │  (事件通知线程)       │  │  (播放控制线程)       │         │
│  │                      │  │                      │         │
│  │  - PlayerNotifyEvent │  │  - doInitStart       │         │
│  │  - StatusChanged     │  │  - doPrepareAsync    │         │
│  │  - PositionChanged   │  │  - doPlay/doPause    │         │
│  │  - BufferingInfo     │  │  - doStop/doReset    │         │
│  │                      │  │  - doSeek            │         │
│  │                      │  │  - doDeviceOpen      │         │
│  └──────────────────────┘  └──────────────────────┘         │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │   DecThread           │  │   ProcessThread       │         │
│  │  (解码线程)           │  │  (音频处理线程)       │         │
│  │                      │  │                      │         │
│  │  - doDecoder         │  │  - doProcess         │         │
│  │  - doSeek            │  │  - processAudio      │         │
│  │  - doIFProcess       │  │  - processFade       │         │
│  │  - AI超分处理        │  │  - TempoProcessor    │         │
│  └──────────────────────┘  └──────────────────────┘         │
│                                                              │
│  ┌──────────────────────┐                                    │
│  │   RenderThread        │                                   │
│  │  (渲染线程/设备回调)  │                                   │
│  │                      │                                    │
│  │  - BufferFill 回调   │                                    │
│  │  - AudioTrack.write  │                                    │
│  │  - AudioQueue回调    │                                    │
│  └──────────────────────┘                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 14.2 CNCMMsgThread — 消息线程

```
文件: cpp/util/CNCMMsgThread.cpp/.h
```

消息线程封装，基于条件变量的消息队列实现。支持：
- 消息发送（PostMsg）
- 消息处理回调
- 线程启动/停止/销毁

### 14.3 线程同步工具

| 工具类 | 文件 | 说明 |
|--------|------|------|
| CNCMCritical | CNCMCritical.cpp/.h | 互斥锁/临界区封装 |
| CNCMSemaphore | CNCMSemaphore.cpp/.h | 信号量封装 |
| CNCMCondition | CNCMCondition.cpp/.h | 条件变量封装 |
| CNCMThread | CNCMThread.cpp/.h | 线程基类封装 |

### 14.4 数据流与线程交互

```
DecThread (解码线程)
    │
    │ doDecoder() → 解码音频帧
    │ doProcess() → 格式归一化
    │ doIFProcess() → AI 超分
    │
    ▼
[解码帧队列 mAudioFrameList] ←── 临界区保护 (mListLock)
    │
    │ bufferFill() / frameFill()
    ▼
ProcessThread (处理线程)
    │
    │ processAudio() → 音效/变速/淡入淡出
    ▼
[处理帧队列] ←── 临界区保护
    │
    │ FillProcessFrame() 回调
    ▼
RenderThread (渲染线程)
    │
    │ BufferFill() → 设备回调拉取数据
    │
    ▼
[AudioDevice] → 音频硬件输出
```

---

## 15. 构建系统

### 15.1 CMake 构建

项目使用 CMake 作为主构建系统：

```
CMakeLists.txt (根配置)
├── projects/android/   # Android NDK CMake 配置
├── projects/ios/       # iOS Xcode 项目
└── projects/mac/       # macOS Xcode 项目
```

### 15.2 平台特定构建

| 平台 | 构建工具 | 说明 |
|------|----------|------|
| Android | CMake + NDK | 通过 JNI 编译为 .so 动态库 |
| iOS | Xcode | 编译为 Framework |
| macOS | Xcode | 编译为 Framework |

### 15.3 符号导出

通过 `bizfuncs.map` 控制导出符号，仅暴露必要的 API，减小二进制体积。

---

## 16. 其他工具类

### 16.1 CNCMABTestKey — AB 测试

```
文件: cpp/util/CNCMABTestKey.cpp/.h
```
AB 测试 Key 管理，用于特性灰度控制。

### 16.2 CNCMAudioConfig — 音频配置

```
文件: cpp/util/CNCMAudioConfig.cpp/.h
```
全局音频配置管理。

### 16.3 CNCMLog — 日志

```
文件: cpp/util/CNCMLog.cpp/.h
```
跨平台日志封装，底层使用 nblog4c。

### 16.4 CNCMSysTime — 系统时间

```
文件: cpp/util/CNCMSysTime.cpp/.h
```
跨平台系统时间获取工具。

### 16.5 audio_jni_helper — JNI 工具

```
文件: cpp/util/audio_jni_helper.cpp/.h
```
Android JNI 辅助工具类。

### 16.6 CTrackPlayedTimeData — 轨道播放时间

```
文件: cpp/CTrackPlayedTimeData.h
```
记录每首歌的播放时间数据，用于播放统计。

### 16.7 NESTFT — 短时傅里叶变换

```
文件: cpp/stft/NESTFT.cpp/.h
```
STFT/ISTFT 实现，用于卡拉OK模式下的频域音频分析与合成。

