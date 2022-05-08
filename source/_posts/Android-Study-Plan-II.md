---
title: Android Study Plan II - Service
date: 2018-03-18 17:38:40
tags: Android
---
# Android学习计划
话题：清晰地理解Service。
1、Service的start和bind状态有什么区别？
2、同一个Service，先startService，然后再bindService，如何把它停止掉？
3、你有注意到Service的onStartCommand方法的返回值吗？不同返回值有什么区别？
4、Service的生命周期方法onCreate、onStart、onBind等运行在哪个线程？

# 答案
{% fullimage /images/study_plan/service_lifecycle.png, alt,Service生命周期 %}
## 1.Service的start和bind状态有什么区别？
start启动Service,service有独立的生命周期，不依赖启动组件；
多次调用start方法，会重复调用onStartCommand方法；（判断service是否正在运行以避免多次调用）
start启动的Service，需要stopService或stopSelf来停止（IntentService会自动调用）。
> 生命周期:onCreate()-\>onStartCommand()-\>onDestory()

bind绑定的Service，依赖于启动组件，销毁后随之消失；
多次bind，只会调用一次onBind方法
> 生命周期:onCreate()-\>onBind()-\>onUnBind()-\>onDestory()

## 2.同一个Service，先startService，然后再bindService，如何把它停止掉？
调用stopService和unbindService方法，顺序无关，当最后一次调用时，会进入Service的onDestory方法
## 3.你有注意到Service的onStartCommand方法的返回值吗？不同返回值有什么区别？
4种返回值
```java
//版本兼容，在Service被杀死后，并不保证onStartCommand会被再一次调用
//Service被kill后，Service被重建，即会调用onCreate()
public static final int START_STICKY_COMPATIBILITY = 0;

/**在Service被杀死后，系统会尝试重启Service但不保存intent，会用一个null对象调用  
onStartCommand方法（注意intent判空），除非有一些被发送的Intent对象在等待   Service被kill后，Service被重建、重启，即会调用onCreate()>onStartCommand()，intent对象为null。
启动服务，试用于媒体播放器之类，无限期等待*/
public static final int START_STICKY = 1;

/**常规操作，除非被杀死之前还有组件调用startService，否则不保留状态并重启Service  
直到接受到新的Intent对象，这个服务才会被重新创建
Service被kill后，Service没有重启*/
public static final int START_NOT_STICKY = 2;

/**Service被杀死后，系统将会组织一次重启Service，在杀死前的最后一次传递的intent会被重新执行，不会传递空的intent  
任意等待中的Intent对象会依次被发送。这适用于那些应该立即恢复正在执行的工作的服务，如下载文件。 */
public static final int START_REDELIVER_INTENT = 3;
```
## 4.Service的生命周期方法onCreate、onStart、onBind等运行在哪个线程？
Service默认运行在主线程，所以生命周期的方法都会运行在主线程
## 5.Service种类
> 按运行地点分类：`本地服务`和`远程服务`
> 本地服务：依附主进程，主进程被kill后就会自动销毁
> 远程服务：运行在一个独立进程，需要利用AIDL通信需要占用一定资源而且是常驻形式

> 按运行类型分类：`前台服务`和`后台服务`
> 前台服务：会在通知栏显示相关通知，当服务终止时通知栏消息即消失起到一定通知作用
> 后台服务：不会显示在前台，用户无感知，服务终止也不会有任何提示

> 按使用方式分类：`startService`，`bindService`和`混合使用`
> startService：用于启动服务执行后台任务，不需要通信，停止需要stopService
> bindService：启动的服务需要进行通信，unbindService停止
> 混合使用：停止服务需同时调用stopService，unbindService
## 6.IntentService介绍
继承Service的一个异步请求类，在IntentService有一个工作进程处理耗时操作，启动方式和普通Service一样。任务执行完毕后，IntentService会自动关闭。每次只会执行一个而不至于堵塞UI线程。