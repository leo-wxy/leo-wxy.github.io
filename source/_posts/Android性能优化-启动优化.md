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

  如果想进一步缩小定位范围，通常还会在这些节点做分阶段打点：

  - 点击图标 / 收到启动意图
  - `Application.onCreate()`
  - 首屏`Activity.onCreate()/onStart()/onResume()`
  - 首帧绘制完成
  - 首屏关键数据可用、页面真正可交互

  这样做的价值在于：**启动优化的最终目标不是“首帧更早”，而是“首屏更早可用”。**如果页面虽然更快显示出来，但用户仍然要等很久才能操作或看到有效内容，那么体验上仍然不算真正优化完成。

  

### 冷启动启动过程

在冷启动开始时，系统有三个任务，他们是：

1. 加载并启动应用——对应`Launcher startActivity()`过程，即`点击桌面图标`
2. 在启动后立即显示应用的空白启动窗口——对应`AMS startActivity`过程
3. 创建应用进程——对应`AMS startProcessLocked() -> Zygote fork进程`

上述三步都是开发者无法进行干预的系统过程

如果换一个角度，可以把冷启动拆成两个阶段：

- 系统侧：`Launcher -> AMS/ATMS -> Zygote fork -> 启动窗口展示`
- 应用侧：`ActivityThread.main() -> bindApplication -> Application.onCreate() -> Activity创建 -> 首帧绘制`

如果从排查视角再细化一些，还可以把应用侧继续拆成几个更容易定位问题的阶段：

- 进程初始化阶段：`ActivityThread.main()`、主线程消息循环建立
- 应用初始化阶段：`ContentProvider`、`Application.onCreate()`
- 首屏页面阶段：首屏`Activity`创建、布局加载、业务初始化
- 渲染绘制阶段：`ViewRootImpl`、首轮测量布局绘制、首帧提交

这样拆分之后，排查启动慢时就不会停留在“App启动慢”这一层，而能继续追问：**到底是进程起来慢、Application慢、首屏页面慢，还是首帧绘制慢。**

真正可优化的重点，通常集中在应用侧。系统侧链路开发者基本无法改变，但可以通过减少应用初始化负担、降低主线程阻塞、减少首帧前必须执行的工作，间接缩短整体冷启动耗时。

在`AMS.startProcessLocked()`之后，调用到了`Process.start()`继续向下到`ZygoteProcess.start()`，然后通过`ZygoteSocket(是为LocalSocket).connect()`与`ZygoteServer`进行连接，接收到`ZygoteSocket`发送的消息后，执行`ZygoteConnection.processOneCommand()`执行到`Zygote.forkAndSpecialize()`孵化应用进程。

冷启动过程中，系统通常还会先展示一个`Starting Window`（启动窗口/启动页过渡窗口）。它的作用不是提前把真实页面画出来，而是在应用首帧尚未准备好之前，先给用户一个过渡界面，减少黑屏或白屏的体感。

因此要区分两个时刻：

- 启动窗口出现：系统为了过渡体验而展示的临时界面。
- 应用首帧出现：应用自己的`Activity`完成首轮绘制后，用户真正看到业务页面。

如果启动窗口主题与首页视觉差异很大，就容易出现明显“闪一下”的跳变感，所以启动页主题、背景色和首屏风格尽量保持一致。

在应用初始化阶段，还有一个经常被忽略的顺序问题：

- 很多`ContentProvider`会早于`Application.onCreate()`执行
- `Application`又通常早于首屏`Activity`创建

这意味着如果某些三方SDK或组件通过`ContentProvider`自动初始化，它们占用的时间会直接落在冷启动最前面，甚至比你在`Application`里看到的初始化还要更早。因此实际治理启动问题时，不能只盯`Application.onCreate()`，还要先检查`Provider`链路里到底做了什么。





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

这里最容易出现的误区是：用户动作上看起来像“重新打开App”，并不一定就是真正意义上的冷启动。返回桌面再点图标，也可能只是热启动；只有进程已经不存在，或者必须重建更完整的启动链路时，才会落到冷启动或温启动。



## 温启动——Warm Start

> 应用已经启动，返回键退出

温启动通常介于冷启动和热启动之间，典型特征是：

- 应用进程仍然存在
- 但目标Activity需要重新创建，或者需要重新走部分界面恢复流程

因此它不像冷启动那样要重新 fork 进程、绑定 Application，但也不像热启动那样只是简单恢复显示。

所以判断冷/温/热启动时，关键不要只看“用户怎么点的”，而是要看：

- 进程还在不在
- 目标Activity需不需要重建
- 是否需要重走完整应用初始化链路

## 启动优化

启动优化主要目标不是“把所有初始化都删除”，而是把**首帧前必须做的事**压缩到最少，把**不影响首屏可见的工作**尽量延后。

但更进一步说，启动优化真正追求的不是“只让首帧更早出现”，而是让用户**更早看到可用内容、并尽快开始交互**。如果只是把页面框架更早画出来，却把真正重要的数据绑定、列表填充、交互初始化全部堆到首帧后，最终用户感受到的可能只是“更早看到一个空壳页面”。

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

启动阶段最常见的耗时来源，通常集中在下面几类：

- 多个三方SDK扎堆初始化
- `ContentProvider`自动初始化链路过长
- 磁盘IO、SP读取、数据库预热
- 反射、类加载、动态代理、Dex优化相关开销
- 首屏布局过深、大图解码、自定义View初始化过重
- 把网络请求、配置拉取、解析计算直接放到首屏关键路径

因此启动优化的第一步往往不是“立即异步化”，而是先把耗时来源分门别类，找出真正占据关键路径的部分。

延迟初始化本身也有边界，常见误区包括：

- 把真正首屏依赖的逻辑误判成“非关键逻辑”而盲目延后
- 只是把任务从首帧前挪到首帧后一瞬间，导致页面刚展示就立刻卡顿
- 把任务简单切到后台线程，但结果又在主线程集中回调，反而把卡顿推迟到更难察觉的位置

所以“延后”本身不是目标，关键是：**不能破坏依赖顺序，不能制造首屏后的集中回切，不能把问题从启动前挪到启动后。**

优化之后还需要验证是否真的生效，常见做法包括：

- 对比优化前后的`TotalTime/Displayed`
- 观察首帧时间是否下降
- 借助`trace/systrace/perfetto`查看主线程、RenderThread、绘制阶段耗时
- 区分“指标更好看”和“用户真实体验更流畅”是否一致

如果从工程闭环角度看，一个更完整的验证流程通常是：

1. 先建立优化前的基线数据
2. 分阶段打点，确定主要耗时落在哪一段
3. 做有针对性的优化，而不是同时改一大堆地方
4. 对比优化前后的`TotalTime/Displayed/首帧/可交互时间`
5. 观察是否引入新的首屏后卡顿、空白态过长或数据延迟问题
6. 最后再结合线上分位数据确认收益是否稳定，而不是只看单次样本

很多“假优化”都出现在没有闭环验证的时候，例如：

- 指标上的`Displayed`变小了，但首屏内容仍然空白很久
- 启动页更早消失了，但页面马上因为数据绑定和列表初始化卡住
- 冷启动耗时看起来下降了，但实际把耗时转移成了首屏后明显掉帧

这类优化从统计上可能好看一些，但从用户体验上并没有真正解决问题。

如果只是把工作从首帧前挪到首帧后，导致页面虽然更早显示但马上出现明显卡顿，这种优化并不算真正完成。




## 参考链接

[应用启动时间](https://developer.android.com/topic/performance/vitals/launch-time)

{% post_link Activity启动过程 Activity启动过程%}
