---
title: WebRTC相关记录
date: 2020-08-06 13:56:15
tags: WebRTC
top: 10
---

## WebRTC连接流程

![连接过程](https://pic4.zhimg.com/80/v2-02ce0ae8a59238a1d4303268ad5f76a5_1440w.jpg)



当前采用服务端框架为 `LiCode`





## WebRTC通话原理及相关概念

### 媒体协商

> 彼此了解对方支持的媒体格式



#### SDP

##### 参数含义



### 网络协商





## WebRTC源码相关





## WebRTC业务SDK功能

1.消息推送（语音电话提醒、新消息接收、对方挂断、支持拓展额外参数）

2.本地长连接（WebRTC dataChannel、保活）

3.语音通话（音频采集、降噪、回声消除、静音）

4.各种状态封装（连接成功、超时、失败、重连等）



## WebRTC待完成

单独编译VAD（静音检测）、NS（降噪）、AECM（回声消除）三模块

NS：`RNNoise`和`WebRTC-NS`



## WebRTC随手记

`SamplesReadyCallback`：在采集音频时可以获取音频信息

`setAudioProcessingFactory()`：设置音频处理相关配置



`webrtc_voice_engine.cc`音频控制

```c++
//音频处理默认配置
  {
    AudioOptions options;
    options.echo_cancellation = true;
    options.auto_gain_control = true;
    options.noise_suppression = true;
    options.highpass_filter = true;
    options.stereo_swapping = false;
    options.audio_jitter_buffer_max_packets = 200;
    options.audio_jitter_buffer_fast_accelerate = false;
    options.audio_jitter_buffer_min_delay_ms = 0;
    options.audio_jitter_buffer_enable_rtx_handling = false;
    options.typing_detection = true;
    options.experimental_agc = false;
    options.experimental_ns = false;
    options.residual_echo_detector = true;
    bool error = ApplyOptions(options);
    RTC_DCHECK(error);
  }


//降噪等级默认为 High  
if (options.noise_suppression) {
    const bool enabled = *options.noise_suppression;
    apm_config.noise_suppression.enabled = enabled;
    apm_config.noise_suppression.level =
        webrtc::AudioProcessing::Config::NoiseSuppression::Level::kHigh;
    RTC_LOG(LS_INFO) << "NS set to " << enabled;
  }


```



`audio_processing_impl.cc` Audio_processing处理类，包含回声消除、降噪等功能







