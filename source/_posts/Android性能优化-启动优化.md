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

  补充理解：

  - `ThisTime/TotalTime/WaitTime`更偏系统统计口径，适合观察启动链路整体变化趋势。
  - 它们能够帮助判断“系统从接收到启动请求到目标Activity拉起”花了多久，但不完全等同于用户真实感知到的“页面已经可用”时间。
  - 当页面首屏很快显示，但后续还有大量数据绑定、首屏交互卡顿时，单看`TotalTime`可能会低估真实体验问题。

- `logcat`

  在Android 4.4之后，logcat可以输出启动时间，只要筛选`Displayed`的值。

  ```logcat
  I/ActivityManager: Displayed com.example.pigai/.MainActivity: +2s241ms
  ```

  其中`+2s241ms`就是冷启动的时间

  `Displayed`更接近“首个界面已经显示出来”的时间点，但它不一定代表页面已经完全可交互、所有首屏数据都准备完毕。因此实际排查启动体验时，通常要把`adb`统计、`Displayed`日志、首帧耗时以及主线程阻塞情况一起看。

- 代码插桩方式

  

### 冷启动启动过程

在冷启动开始时，系统有三个任务，他们是：

1. 加载并启动应用——对应`Launcher startActivity()`过程，即`点击桌面图标`
2. 在启动后立即显示应用的空白启动窗口——对应`AMS startActivity`过程
3. 创建应用进程——对应`AMS startProcessLocked() -> Zygote fork进程`

上述三步都是开发者无法进行干预的系统过程

如果换一个角度，可以把冷启动拆成两个阶段：

- 系统侧：`Launcher -> AMS/ATMS -> Zygote fork -> 启动窗口展示`
- 应用侧：`ActivityThread.main() -> bindApplication -> Application.onCreate() -> Activity创建 -> 首帧绘制`

真正可优化的重点，通常集中在应用侧。系统侧链路开发者基本无法改变，但可以通过减少应用初始化负担、降低主线程阻塞、减少首帧前必须执行的工作，间接缩短整体冷启动耗时。

在`AMS.startProcessLocked()`之后，调用到了`Process.start()`继续向下到`ZygoteProcess.start()`，然后通过`ZygoteSocket(是为LocalSocket).connect()`与`ZygoteServer`进行连接，接收到`ZygoteSocket`发送的消息后，执行`ZygoteConnection.processOneCommand()`执行到`Zygote.forkAndSpecialize()`孵化应用进程。

冷启动过程中，系统通常还会先展示一个`Starting Window`（启动窗口/启动页过渡窗口）。它的作用不是提前把真实页面画出来，而是在应用首帧尚未准备好之前，先给用户一个过渡界面，减少黑屏或白屏的体感。

因此要区分两个时刻：

- 启动窗口出现：系统为了过渡体验而展示的临时界面。
- 应用首帧出现：应用自己的`Activity`完成首轮绘制后，用户真正看到业务页面。

如果启动窗口主题与首页视觉差异很大，就容易出现明显“闪一下”的跳变感，所以启动页主题、背景色和首屏风格尽量保持一致。





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

更严格地说，热启动通常满足两个条件：

- 应用进程仍然存在
- 目标Activity实例通常也还在内存中，只需要从后台恢复到前台

这类启动一般不需要重新创建进程，也不需要完整重走首个Activity的创建流程，因此成本最低。



## 温启动——Warm Start

> 应用已经启动，返回键退出

温启动通常介于冷启动和热启动之间，典型特征是：

- 应用进程仍然存在
- 但目标Activity需要重新创建，或者需要重新走部分界面恢复流程

因此它不像冷启动那样要重新 fork 进程、绑定 Application，但也不像热启动那样只是简单恢复显示。

## 启动优化

启动优化主要目标不是“把所有初始化都删除”，而是把**首帧前必须做的事**压缩到最少，把**不影响首屏可见的工作**尽量延后。

可以从以下几个方向入手：

1. 缩短首帧前的关键路径

   - 只保留首屏真正依赖的初始化逻辑
   - 减少`Application`、首屏`Activity`中的大块同步任务

2. 延后非关键初始化

   - 统计、埋点、分享、广告、推送、部分三方SDK不必全部堵在启动主链路上
   - 可以放到首帧后、空闲时机或后台线程执行

3. 异步化与懒加载

   - 磁盘IO、配置读取、部分数据预处理尽量放到后台线程
   - 首页用不到的模块不要在启动阶段一次性全部初始化

4. 降低首屏布局与绘制成本

   - 减少首屏层级
   - 避免过度绘制
   - 控制首屏自定义View、复杂列表和大图加载成本

5. 谨慎对待自动初始化

   - 很多组件会通过`ContentProvider`在应用启动早期自动初始化
   - 这类初始化会直接占用冷启动时间，应评估是否真的需要在启动时完成

优化之后还需要验证是否真的生效，常见做法包括：

- 对比优化前后的`TotalTime/Displayed`
- 观察首帧时间是否下降
- 借助`trace/systrace/perfetto`查看主线程、RenderThread、绘制阶段耗时
- 区分“指标更好看”和“用户真实体验更流畅”是否一致

如果只是把工作从首帧前挪到首帧后，导致页面虽然更早显示但马上出现明显卡顿，这种优化并不算真正完成。




## 参考链接

[应用启动时间](https://developer.android.com/topic/performance/vitals/launch-time)

{% post_link Activity启动过程 Activity启动过程%}
