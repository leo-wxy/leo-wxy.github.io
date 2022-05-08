---
title: Android性能优化-启动优化
typora-root-url: ../
date: 2020-10-08 21:18:08
tags: Android
top: 9
---



> App启动分为三种：`冷启动`、`热启动`、`温启动`
>
> 启动优化主要在`冷启动`时进行。

## 冷启动——Cold Start

> 开机后第一次启动应用 或者 应用被杀死后再次启动。

### 冷启动耗时检测

- `adb命令`

  ```shell
  adb [-d|-e|-s <serialNumber>] shell am start -S -W
      com.example.app/.MainActivity
      -c android.intent.category.LAUNCHER
      -a android.intent.action.MAIN
  ```

  执行adb命令后，返回如下内容

  ```shell
  Starting: Intent
      Activity: com.example.app/.MainActivity
      ThisTime: 2044 
      TotalTime: 2044
      WaitTime: 2054
      Complete
  ```

  ![curTime/displayStartTime/mLaunchStartTime](/images/ThisTime-TotalTime.png)

  - `ThisTime`：最后一个Activity的启动耗时
  - `TotalTime`：表示新应用启动的耗时，包括新进的启动和Activity的启动。
  - `WaitTime`：应用进程的创建过程 + TotalTime

  **主要关注`TotalTime`就可以。**

- `logcat`

  在Android 4.4之后，logcat可以输出启动时间，只要筛选`Displayed`的值。

  ```logcat
  I/ActivityManager: Displayed com.example.pigai/.MainActivity: +2s241ms
  ```

  其中`+2s241ms`就是冷启动的时间

- 代码插桩方式

  

### 冷启动启动过程

在冷启动开始时，系统有三个任务，他们是：

1. 加载并启动应用——对应`Launcher startActivity()`过程，即`点击桌面图标`
2. 在启动后立即显示应用的空白启动窗口——对应`AMS startActivity`过程
3. 创建应用进程——对应`AMS startProcessLocked() -> Zygote fork进程`

上述三步都是开发者无法进行干预的系统过程

在`AMS.startProcessLocked()`之后，调用到了`Process.start()`继续向下到`ZygoteProcess.start()`，然后通过`ZygoteSocket(是为LocalSocket).connect()`与`ZygoteServer`进行连接，接收到`ZygoteSocket`发送的消息后，执行`ZygoteConnection.processOneCommand()`执行到`Zygote.forkAndSpecialize()`孵化应用进程。





在`创建应用进程`之后，应用进程继续执行后续流程

`ActivityThread.main()`

1. 创建应用对象

   对应`ActivityThread.attach() -> AMS.attachApplication() -> ActivityThread.handleBindApplication() -> LoadApk.makeApplication() -> Application.onCreate()`过程

2. 启动主线程

   对应`ActivityThread.main() -> Looper.loop()`过程，主线程开始循环

3. 创建主Activity

   对应`ActivityThread.handleLaunchActivity()`过程

4. 加载布局

   对应`Activity.onCreate() -> setContentView()`过程

5. 布局屏幕

   对应`Activity.onStart()`过程

6. 执行初始绘制

   对应`Activity.handleResumeActivity() -> Activity.onResume()`过程



![冷启动启动过程](/images/冷启动启动过程.png)

## 热启动——Hot Start

> 应用退回到后台再次启动



## 温启动——Warm Start

> 应用已经启动，返回键退出

## 启动优化





## 参考链接

[应用启动时间](https://developer.android.com/topic/performance/vitals/launch-time)

{% post_link Activity启动过程 Activity启动过程%}