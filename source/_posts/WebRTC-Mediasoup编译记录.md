---
title: WebRTC-Mediasoup编译记录
typora-root-url: ../
date: 2020-09-24 16:32:21
tags: WebRTC
top: 9
---



### 下载相关文件

- [libmediasoupclient](https://github.com/versatica/libmediasoupclient)
- [webrtc](https://webrtc.googlesource.com/src)

### 参考文档

[compile_webrtc](https://github.com/mail2chromium/Compile_WebRTC_Library_For_Android)

[mediasoup doc](https://mediasoup.org/documentation/v3/libmediasoupclient/installation/)



### 编译webrtc

```shell
//编译工具下载
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATh="$PATH:${HOME}/depot_tools" //配置环境变量

//下载webrtc源码
mkdir webrtc_android
cd webrtc_android
git clone https://webrtc.googlesource.com/src
fetch --nohooks webrtc_android
gclient sync

//编译webrtc源码
cd src
./build/install-build-deps.sh

gn gen out/Debug --args='target_os="android" target_cpu="arm"'
// gn gen out/Release --args='is_debug=false is_component_build=false rtc_include_tests=false target_os="android" target_cpu="arm"'

autoninja -C out/Debug
//autoninja -C out/Release
```

对应文件输出目录：

./out/Debug/lib_java/sdk/android/libwebrtc.jar 

./out/Debug/libjingle_peerconnection_so.so

上面这俩是Android需要用到的sdk

./out/Debug/lib.unstripped/libjingle_peerconnection_so.so

./out/Debug/obj/libwebrtc.a //静态链接




### 编译libmediasoupclient

#### 下载代码

git clone https://github.com/versatica/libmediasoupclient

cd libmediasoupclient/

#### 编译配置

```shell
cmake . -Bbuild \
-DLIBWEBRTC_INCLUDE_PATH:PATH=PATH_TO_LIBWEBRTC_SOURCES \     # src源代码目录
-DLIBWEBRTC_BINARY_PATH:PATH=PATH_TO_LIBWEBRTC_BINARY         # 编译出libwebrtc.a目录
```

示例配置

cmake . -Bbuild   -DLIBWEBRTC_INCLUDE_PATH:PATH=/home/zaze/Desktop/webrtc_android/src   -DLIBWEBRTC_BINARY_PATH:PATH=/home/zaze/Desktop/webrtc_android/src/out/Debug/obj

运行命令后，再执行

```shell
make -C build/
```

在`./build/`目录下会生成`libmediasoupclient.a`文件取出备用



### 获取libmediasoupclient sdk

基于[mediasoup-client-android](https://github.com/haiyangwu/mediasoup-client-android)进行编译，注意以下关键点：

- clone后的项目里面的`mediasoup-client/deps/webrtc/lib`里面的`libwebrtc.a`文件都是有误的，需要从`https://github.com/haiyangwu/webrtc-android-build`获取对应版本的文件，下载完成后替换原有的`libs`目录



TODO:后续替换为最新版的`libmediasoupclient`和`webrtc`

