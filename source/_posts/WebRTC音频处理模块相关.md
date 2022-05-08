---
title: WebRTC音频处理模块相关
date: 2020-08-14 09:50:00
tags: WebRTC
top: 9
---

**[WebRTC源码](https://webrtc.googlesource.com/src/)**基于提交版本`4c2f9c9`

WebRTC音频处理模块，负责在传输音频时对音频进行一定的处理，例如`降噪、增益、回声消除`，整体模块代码位于`modules/audio_processing`。

按照以下模块分别介绍，各模块的功能以及相关配置和源码解析

默认音频处理配置如下：

```c++
 AudioOptions options;
    options.echo_cancellation = true;//回声消除
    options.auto_gain_control = true;//自动增益
    options.noise_suppression = true;//降噪
    options.highpass_filter = true;//高通滤波器开启 
    options.stereo_swapping = false;//立体声
    options.audio_jitter_buffer_max_packets = 200;//jitter_buffer相关配置
    options.audio_jitter_buffer_fast_accelerate = false;
    options.audio_jitter_buffer_min_delay_ms = 0;
    options.audio_jitter_buffer_enable_rtx_handling = false;
    options.typing_detection = true;//键盘声音检测
    options.experimental_agc = false;//实验性增益控制
    options.experimental_ns = false;//实验性降噪
    options.residual_echo_detector = true;//残留回声检测
```

> 高通滤波器：只允许某一频率以上的信号无衰减的通过滤波器，去掉了信号中低于该概率的不必要成分或者说去掉了低于该频率的干扰信号。

## WebRTCVoiceEngine初始化过程

> 在配置后面的可选项之前，需要先行初始化`WebRTCVoiceEngine`，保证配置参数可以生效。 



## AEC(回声消除)

> WebRTC中的`AEC`模块分为这几部分：`AECM(移动设备使用)`、`AEC3(实验模块)`、`AEC(PC使用)`，源码位于`modules/audio_processing/aec3、./aecm`

### 硬件AEC

> 由硬件设备提供的`AEC`功能，当开启该功能时会主动屏蔽掉软件实现的`AEC`功能.

通过配置`JavaAudioDeviceModule`实现硬件回声消除功能

```java
return JavaAudioDeviceModule.builder(context)
                .setUseHardwareAcousticEchoCanceler(true)//开启硬件降噪
                .createAudioDeviceModule();

# org.webrtc.audio.WebRtcEffects
//判断是否支持硬件AEC
public static boolean isAcousticEchoCancelerSupported() {
        return VERSION.SDK_INT < 18 ? false : isEffectTypeAvailable(AudioEffect.EFFECT_TYPE_AEC, AOSP_ACOUSTIC_ECHO_CANCELER);
    }
```



### 软件AEC

```java
return JavaAudioDeviceModule.builder(context)
                .setUseHardwareAcousticEchoCanceler(false)//开启硬件降噪
                .createAudioDeviceModule();
```



### AEC Native代码

```java
//Native获取当前是否开启硬件AEC    
@CalledByNative
    boolean isAcousticEchoCancelerSupported() {
        return this.isAcousticEchoCancelerSupported;
    }
```

在此处获取Java层配置的参数

```c++
// 源码位置：/sdk/android/src/jni/audio_device/audio_record_jni.cc
bool AudioRecordJni::IsAcousticEchoCancelerSupported() const {
  RTC_DCHECK(thread_checker_.IsCurrent());
  return Java_WebRtcAudioRecord_isAcousticEchoCancelerSupported(
      env_, j_audio_record_);
}
```

```c++
//源码位置：/sdk/android/src/jni/audio_device/audio_device/audio_device_module.cc
  bool BuiltInAECIsAvailable() const override {
    RTC_LOG(INFO) << __FUNCTION__;
    if (!initialized_)
      return false;
    bool isAvailable = input_->IsAcousticEchoCancelerSupported();
    RTC_LOG(INFO) << "output: " << isAvailable;
    return isAvailable;
  }
```

判断是否启用硬件AEC

```c++
pc/peer_connection_factory.cc -> channel_manager.cc -> media_engine.cc ->webrtc_voice_engine.cc
从media_engine.cc调用
//WebRTCVoiceEngine初始化
void WebRtcVoiceEngine::Init() {
  RTC_DCHECK(worker_thread_checker_.IsCurrent());
  RTC_LOG(LS_INFO) << "WebRtcVoiceEngine::Init";

  // TaskQueue expects to be created/destroyed on the same thread.
  low_priority_worker_queue_.reset(
      new rtc::TaskQueue(task_queue_factory_->CreateTaskQueue(
          "rtc-low-prio", webrtc::TaskQueueFactory::Priority::LOW)));

  // Load our audio codec lists.
  RTC_LOG(LS_VERBOSE) << "Supported send codecs in order of preference:";
  send_codecs_ = CollectCodecs(encoder_factory_->GetSupportedEncoders());
  for (const AudioCodec& codec : send_codecs_) {
    RTC_LOG(LS_VERBOSE) << ToString(codec);
  }

  RTC_LOG(LS_VERBOSE) << "Supported recv codecs in order of preference:";
  recv_codecs_ = CollectCodecs(decoder_factory_->GetSupportedDecoders());
  for (const AudioCodec& codec : recv_codecs_) {
    RTC_LOG(LS_VERBOSE) << ToString(codec);
  }

#if defined(WEBRTC_INCLUDE_INTERNAL_AUDIO_DEVICE)
  // No ADM supplied? Create a default one.
  if (!adm_) {
    adm_ = webrtc::AudioDeviceModule::Create(
        webrtc::AudioDeviceModule::kPlatformDefaultAudio, task_queue_factory_);
  }
#endif  // WEBRTC_INCLUDE_INTERNAL_AUDIO_DEVICE
  RTC_CHECK(adm());
  webrtc::adm_helpers::Init(adm());

  // Set up AudioState.
  {
    webrtc::AudioState::Config config;
    if (audio_mixer_) {
      config.audio_mixer = audio_mixer_;
    } else {
      config.audio_mixer = webrtc::AudioMixerImpl::Create();
    }
    config.audio_processing = apm_;
    config.audio_device_module = adm_;
    audio_state_ = webrtc::AudioState::Create(config);
  }

  // Connect the ADM to our audio path.
  adm()->RegisterAudioCallback(audio_state()->audio_transport());

  // Set default engine options.
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

  initialized_ = true;
}

//源码位置：/sdk/android/src/meida/engine/webrtc_voice_engine.cc
webrtc::AudioDeviceModule* WebRtcVoiceEngine::adm() {
  RTC_DCHECK(worker_thread_checker_.IsCurrent());
  RTC_DCHECK(adm_);
  return adm_.get();
}

//指向AudioProcessing配置
webrtc::AudioProcessing* WebRtcVoiceEngine::apm() const {
  RTC_DCHECK(worker_thread_checker_.IsCurrent());
  return apm_.get();
}
webrtc::AudioProcessing* ap = engine()->apm();
...
bool WebRtcVoiceEngine::ApplyOptions(const AudioOptions& options_in) {
  ...
//默认配置 options.echo_cancellation 为true
  if (options.echo_cancellation) {
    // Check if platform supports built-in EC. Currently only supported on
    // Android and in combination with Java based audio layer.
    const bool built_in_aec = adm()->BuiltInAECIsAvailable();//开启硬件AEC就为true
    if (built_in_aec) {
      // Built-in EC exists on this device. Enable/Disable it according to the
      // echo_cancellation audio option.
      const bool enable_built_in_aec = *options.echo_cancellation;
      if (adm()->EnableBuiltInAEC(enable_built_in_aec) == 0 &&
          enable_built_in_aec) {
        // Disable internal software EC if built-in EC is enabled,
        // i.e., replace the software EC with the built-in EC.
        options.echo_cancellation = false;
        RTC_LOG(LS_INFO)
            << "Disabling EC since built-in EC will be used instead";
      }
    }
  }
...
  //如果编译android源码，默认启用AECM
  #elif defined(WEBRTC_ANDROID)
  use_mobile_software_aec = true;
#endif
...
  //配置apm(AudioDeviceModule)参数
  if (options.echo_cancellation) {
    apm_config.echo_canceller.enabled = *options.echo_cancellation;
    apm_config.echo_canceller.mobile_mode = use_mobile_software_aec;
  }
...
  ap->ApplyConfig(apm_config);
  return true;
}
```

`options.echo_cancellation`参数配置完毕后需要应用参数

```c++
//源码位置：modules/audio_processing/audio_processing_impl.cc
void AudioProcessingImpl::ApplyConfig(const AudioProcessing::Config& config) {
  ...
  if (aec_config_changed) {
    InitializeEchoController();
  }
  ...
}

//初始化 AEC配置 
void AudioProcessingImpl::InitializeEchoController() {
  //是否启动回声消除
   bool use_echo_controller =
      echo_control_factory_ ||
      (config_.echo_canceller.enabled && !config_.echo_canceller.mobile_mode);
  
  if (use_echo_controller) {
    // Create and activate the echo controller.
    if (echo_control_factory_) {
      submodules_.echo_controller = echo_control_factory_->Create(
          proc_sample_rate_hz(), num_reverse_channels(), num_proc_channels());
      RTC_DCHECK(submodules_.echo_controller);
    } else {
      //AEC3模块
      EchoCanceller3Config config =
          use_setup_specific_default_aec3_config_
              ? EchoCanceller3::CreateDefaultConfig(num_reverse_channels(),
                                                    num_proc_channels())
              : EchoCanceller3Config();
      submodules_.echo_controller = std::make_unique<EchoCanceller3>(
          config, proc_sample_rate_hz(), num_reverse_channels(),
          num_proc_channels());
    }
    ...
  }

 ...
   //移动端AECM模块设置
   if (config_.echo_canceller.mobile_mode) {
    // Create and activate AECM.
    size_t max_element_size =
        std::max(static_cast<size_t>(1),
                 kMaxAllowedValuesOfSamplesPerBand *
                     EchoControlMobileImpl::NumCancellersRequired(
                         num_output_channels(), num_reverse_channels()));

    std::vector<int16_t> template_queue_element(max_element_size);

    aecm_render_signal_queue_.reset(
        new SwapQueue<std::vector<int16_t>, RenderQueueItemVerifier<int16_t>>(
            kMaxNumFramesToBuffer, template_queue_element,
            RenderQueueItemVerifier<int16_t>(max_element_size)));

    aecm_render_queue_buffer_.resize(max_element_size);
    aecm_capture_queue_buffer_.resize(max_element_size);

    submodules_.echo_control_mobile.reset(new EchoControlMobileImpl());

    submodules_.echo_control_mobile->Initialize(proc_split_sample_rate_hz(),
                                                num_reverse_channels(),
                                                num_output_channels());
    return;
  }
  submodules_.echo_control_mobile.reset();
  aecm_render_signal_queue_.reset();
  
}
```

#### AEC3

> TODO 简单算法介绍

参考类为`src/api/audio/echo_canceller3/echo_canceller3_config.cc`(AEC3配置项)

`echo_canceller3.cc`实际生效类



#### AECM

> AEC的移动端精简版，降低了计算的复杂度，相比于原版会有更明显的回声

参考类为`echo_control_mobile_impl.cc`

提供了如下配置项：

```c++
int16_t MapSetting(EchoControlMobileImpl::RoutingMode mode) {
  switch (mode) {
    case EchoControlMobileImpl::kQuietEarpieceOrHeadset:
      return 0;
    case EchoControlMobileImpl::kEarpiece:
      return 1;
    case EchoControlMobileImpl::kLoudEarpiece:
      return 2;
    case EchoControlMobileImpl::kSpeakerphone:
      return 3;
    case EchoControlMobileImpl::kLoudSpeakerphone:
      return 4;
  }
  RTC_NOTREACHED();
  return -1;
}
```





## NS(降噪)

> 主要源代码位于`modules/audio_processing/ns`

### 硬件NS

> 由硬件设备提供的NS功能，开启硬件降噪时，软件降噪关闭

通过配置`JavaAudioDeviceModule`实现硬件降噪功能

```java
return JavaAudioDeviceModule.builder(context)
                .setUseHardwareNoiseSuppressor(true)//开启硬件降噪
                .createAudioDeviceModule();

# org.webrtc.audio.WebRtcEffects
//判断是否支持硬件NS
    public static boolean isNoiseSuppressorSupported() {
        return VERSION.SDK_INT < 18 ? false : isEffectTypeAvailable(AudioEffect.EFFECT_TYPE_NS, AOSP_NOISE_SUPPRESSOR);
    }
```



### 软件NS

```java
return JavaAudioDeviceModule.builder(context)
                .setUseHardwareNoiseSuppressor(false)//开启硬件降噪
                .createAudioDeviceModule();
```



### NS Native代码

```java
//Native获取当前是否支持 硬件NS
@CalledByNative
    boolean isNoiseSuppressorSupported() {
        return this.isNoiseSuppressorSupported;
    }
```

获取Java端配置的参数

```c++
// 源码位置：/sdk/android/src/jni/audio_device/audio_record_jni.cc
bool AudioRecordJni::IsNoiseSuppressorSupported() const {
  RTC_DCHECK(thread_checker_.IsCurrent());
  return Java_WebRtcAudioRecord_isNoiseSuppressorSupported(env_,
                                                           j_audio_record_);
}

//源码位置：/sdk/android/src/jni/audio_device/audio_device/audio_device_module.cc
bool BuiltInNSIsAvailable() const override {
    RTC_LOG(INFO) << __FUNCTION__;
    if (!initialized_)
      return false;
    bool isAvailable = input_->IsNoiseSuppressorSupported();
    RTC_LOG(INFO) << "output: " << isAvailable;
    return isAvailable;
  }
```

判断是否启用硬件NS





## AGC(音频增益)

gain_controller1、gain_controller2

## VAD(静音检测)

 Voice_detection

## Other(其他模块)

### HighPassFilter(高通滤波）

## jitter_buffer



## WebRTC内部消息模型



## 相关链接

[AEC原理与实现](https://www.cnblogs.com/LXP-Never/p/11703440.html)