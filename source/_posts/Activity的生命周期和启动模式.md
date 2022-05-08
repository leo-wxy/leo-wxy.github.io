---
title: Activity的生命周期和启动模式
date: 2019-01-04 10:47:04
tags: Android
top: 11
---

# Activity的生命周期和启动模式

<!--standard，singleTop，singleTask，singleInstance  什么时候会用到singleTask？Activity之间的通信方式 横竖屏切换的时候，Activity 各种情况下的生命周期 Activity上有Dialog的时候按Home键时的生命周期 两个Activity 之间跳转时必然会执行的是哪几个方法？activity栈 下拉状态栏是不是影响activity的生命周期，如果在onStop的时候做了网络请求，onResume的时候怎么恢复-->



{% fullimage /images/Activity生命周期和启动模式.png,Activity生命周期和启动模式,Activity生命周期和启动模式 %}

<!-- more -->

## Activity的生命周期

{% fullimage /images/study_plan/activity_lifecycle.jpeg, Activity生命周期,Activity生命周期 %}

### 正常情况下的Activity生命周期

正常情况下，Activity会经历如下生命周期

#### onCreate(Bundle savedInstanceState) --创建

> **表示Activity正在被创建，是生命周期的第一个方法**
>
> 可以做一些初始化工作，调用`setContentView()`加载布局，初始化Activity需要的数据
>
> *onCreate 入参的 savedInstanceState其实就是 由于Activity异常销毁存储下来的数据*

#### onRestart() -- 重启

> **表示Activity正在重新启动，当当前Activity从不可见切换到可见时，就会触发**
>
> 随后就会调用到`onStart()`方法

#### onStart() -- 可见

> **表示Activity正在启动，这时Activity已经可见了，但没有出现在前台无法与用户交互**

#### onResume() --可交互

> **表示Activity已经可见了，并且出现在前台且可以与用户交互。**

#### onPause() -- 不可交互

> **表示Activity正在停止，此时可以做一些`存储数据、停止动画`等操作**
>
> *`onPause` 中不能执行过于耗时操作，会影响到下一个新Activity的显示。旧Activity必须执行完`onPause()`后，新Activity的`onResume()`才可以执行。*

#### onStop() -- 不可见

> **表示Activity即将停止，此时Activity已经不可见，可以做一些稍微重量级的回收工作(`取消网络连接，注销广播监听器等`)，同样不能太耗时。**
>
> *当新Activity为透明主题即旧Activity依然可见，或者弹出一个框，都不会执行旧Activity的`onStop()`*

#### onDestroy() -- 销毁

> **表示Activity即将被销毁，这时可以做一些回收工作以及资源的释放。**

拓展

*Activity在处于`onPause(),onStop(),onDestroy()`状态下，进程优先级较低，容易被回收，所以需要保存一些数据时，<font color = 'red'>必须在onPause中存储</font>，其他两个周期不一定能调用到。*

### Activity生命周期的阶段

可以分为以下3个阶段：

- 完整生命周期

  > 从`onCreate() 初始化`开始直到`onDestroy() 释放资源`结束

- 可见生命周期

  > 从`onStart() 可见`到`onStop() 不可见`结束

- 前台生命周期

  > 从`onResume() 可交互`到`onPause() 无法交互`结束

### Activity生命周期的切换过程

- 启动Activity

  `onCreate() -> onStart() -> onResume()`

- 打开新的Activity

  `旧Activity.onPause() -> Activity.onCreate() -> Activity.onStart() -> Activity.onResume()-> 旧Activity.onStop()`

- 返回上一个Activity

  `新Activity.onPause() -> 旧Activity.onRestart() -> 旧Activity.onStart() -> 旧Activity.onResume() -> 新Activity.onStop() -> 新Activity.onDestroy()`

- 弹出对话框

  - 自身调用弹出  `不会有生命周期变化`
  - 外部调用弹出  `当前Activity.onPause()`

- 关闭屏幕/按Home键

  - `onPause() -> onStop()`
  - 新Activity显示，旧Activity依然可见 `新Activity.onPause() -> 新Activity.onStop() -> 旧Activity.onStop()`

- 点亮屏幕/回到应用

  - `onRestart() -> onStart() -> onResume()`
  - 新Activity显示，旧Activity依然可见 `新Activity.onRestart() -> 新Acticvity.onStart() -> 旧Activity.onRestart() ->旧Activity.onStart() -> 新Activity.onResume()`

- 销毁Activity

  - `onPause() -> onStop() -> onDestroy()`
  - 新Activity显示，旧Activity依然可见，销毁新Acticvity `新Activity.onPause() -> 旧Activity.onResume() -> 旧Activity.onStop() -> 旧Activity.onDestroy()`

- 弹出对话框样式的Activity

  `旧Activity.onPause() -> 新Activity.onCreate() -> 新Activity.onStart() -> 新Activity.onResume()`

- 状态栏下拉

  `不会有生命周期变化,如果需要监听可以 使用 onWindowFocusChanged()`

- 横竖屏切换下的生命周期

  这是一个 销毁重建的过程

  `onPause() -> onStop() -> onDestroy() -> onCreate() -> onStart() -> onResume()`

### 异常情况下的生命周期分析

> Activity除了上述正常情况下执行的生命周期调度，还会有一些异常情况会导致Activity被杀死。
>
> 例如在执行到`onPause()`或`onStop()`时，Activity进入了Finish状态，表示被异常终止。

#### 由于资源相关的系统配置发生改变导致Activity被杀死并重新构建

例如：当Activity发生横竖屏切换时，发了系统配置的改变，在默认情况下Activity就会被销毁并重建。

> 如何避免配置改变导致Activity重新创建？
>
> 可以在`AndroidManifest.xml`中指定对应的系统属性，这样在触发对应改变时，不会再杀死并重建，会调用到`onConfigurationChanged()`，只需重写该方法即可。
>
> 例如配置了`android:configChanges="orientation"`，横竖屏切换时就不会触发重建。

#### 由于系统资源不足，导致优先级低的Activity被杀死

这里需要先了解Activity的优先级情况。按照从高到低分为以下三种：

1. **前台Activity**：正在和用户交互的Activity
2. **可见但非前台Activity**：前台的Activity弹出一个Dialog，导致无法交互
3. **后台Activity**：已经被暂停的Activity，比如切到后台或者切换应用

**当系统内存不足时，系统就会按照上述描述的优先级去杀死目标Activity所在进程。**

如果一个进程中没有四大组件在执行，进程很快被系统杀死。



当上述两种情况发生时，Activity的生命周期会发生如下变化：

- Activity被杀死：

  在`Android 9.0`之前`onPause() -> onSaveInstanceState() -> onStop() -> onDestroy()`

  在`Android 9.0`之后`onPause() -> onStop() -> onSaveInstanceState() -> onDestroy()`

  系统异常终止时，调用`onSaveInstanceState()`保存数据。该方法调用在`onStop()`之前。

  保存数据过程是利用一种`委托`的思想，上层委托下层。

- Activity重建：`onCreate() -> onStart() -> onRestoreInstanceState() -> onResume()`

  重新创建时，调用`onRestoreInstanceState()`，调用在`onStart()`之后，该方法会把`onSaveInstanceState()`存储的Bundle对象拿出来解析。

  *`onCreate和onRestoreInstanceState`都可以获取存储的对象，推荐使用`onRestoreInstanceState`不需要额外的去判断是否为空。*

**系统只有在异常终止的情况下才会调用`onSaveInstanceState和onRestoreInstanceState`进行存储和恢复数据。**

拓展：

1. 还有一些会在Activity运行过程中的触发方法，这里简单的提及一下：
   - `onPostCreate()`：在`onCreate()`执行完毕后回调
   - `onUserInteraction()`：所有Activity上的触摸事件 优先调用该方法
   - `onUserLeaveHint()`：用户主动离开Activity调用该方法，例如点击Home
   - `onContentChanged()`：Activity 调用`setContentView()`完成后调用

## Activity的启动模式

### Activity的任务栈

> 当我们多次启动一个Activity的时候，系统会创建多个实例并放入任务栈中，当我们触发`finish`时，Activity会一一回退。**任务栈是一种先进后出的栈结构。**
>
> 任务栈又分为`前台任务栈`和`后台任务栈`。`后台任务栈`中的Activity位于暂停状态.

- 程序在创建时就会创建一个Activity任务栈，存储当前程序的Activity
- 任务栈是Activity的集合，只有位于栈顶的Activity可以和用户交互
- 任务栈可以移动到后台并保留了Activity的状态
- 退出应用程序时，任务栈会被清空，然后会被系统回收。

利用`adb shell dumpsys activity`查看当前任务栈

### Activity的LaunchMode

> LaunchMode为了减少Activity实例的创建优化

使用方法：

- 在`AndroidManifest.xml`中给对应Activity配置属性 `android:launchMode="standard | singltTop | singleTask | singleInstance"`
- `startActivity`时添加`intent.addFlags(FLAG)`

#### standard 标准模式(默认这个)

> 每次启动一个新的Activity都会创建一个新的Activity实例。
>
> *若启动Activity的是除了Activity之外的context对象就需要指定`FLAG_ACTIVITY_NEW_TASK`标记位，创建一个新的任务栈。因为standard默认进入启动方的任务栈，由于他们是没有自身的任务栈，所以需要新建。*

{% fullimage /images/study_plan/launchmode_standard.png, alt,Standard %}

#### singleTop 栈顶复用模式

> 如果要启动的Activity位于栈顶，就不会重新创建，并且调用`onNewIntent(Intent intent)`取出当前请求的信息。
>
> *还会调用`onPause()以及onResume()`。*

{% fullimage /images/study_plan/launchmode_singletop.png, alt,SingleTop %}

A位于栈顶，B位于栈底。如果A的启动模式为`singleTop`，再次启动A，栈内情况不会发生变化，依然为AB

如果启动B，则会创建新的实例，不论是否为`singleTop`。

#### singleTask 栈内复用模式

> 栈内只要存在Activity实例，再次启动都不会重新创建实例，只会回调`onNewIntent()`，并从栈内弹出该实例上的所有Activity。
>
> 适合作为应用主入口，因为只会启动一次。

列举3个实例加深理解：

- {% fullimage /images/study_plan/launchmode_singletask3.png, alt, SingleTask %}

  目前S1中由ABC三个实例，这时D以`singleTask`模式请求启动且所需任务栈为`S2`，由于`S2`和`D`实例均不存在，所以系统会创建`S2`任务栈并把实例`D`入栈到`S2`。

- {% fullimage /images/study_plan/launchmode_singletask1.png, alt,SingleTask %}

  目前S1中由ABC三个实例，这时D以`singleTask`模式请求启动且所需任务栈为`S1`，由于`S1`已经存在，所以直接入栈并置于栈顶。

- {% fullimage /images/study_plan/launchmode_singletask2.png, alt, SingleTask %}

  目前S1中由ABCD四个实例，这时B以`singleTask`模式请求启动且所需任务栈为`S1`，此时B不会重新创建，将直接回调`onNewIntent()`并置于栈顶。*原先位于B实例上的CD都被清除，因为默认具有clear_top 效果，最终就变成了AB*

#### singleInstance 单实例模式

> 加强的singleTask模式，除了singleTask拥有的特性外，还加强了一点。使用了这个模式启动的Activity只能单独的位于一个任务栈中。启动时会新开一个任务栈并直接创建实例压入栈中。
>
> *即使设置了相同的任务栈名，也不能放在一个栈中。*

#### TaskAffinity -- 栈亲和性

> taskAffinity：标识了一个Activity所需要任务栈的名字，默认情况下，所有Activity所需的任务栈名字为应用的包名。我们也可以为每个Activity指定任务栈，利用`android:taskAffinity`属性标记。

- 配合`singleTask`使用

  新Activity启动时默认被加载进启动该Activity的对象所在任务栈中。如果给启动的Activity设置`FLAG_ACTIVITY_NEW_TASK`标记或者设置`singleTask`启动模式，再配合`taskAffinity`设置任务栈名字，该实例就会被加载进相同名字的任务栈中，如果不存在相同就创建新的任务栈并压入实例。

- 配合`allowTaskReparenting`使用

  > allowTaskReparenting 作用是 是否允许Activity更换从属任务。true表示可以更换，默认为false

  简单描述： 有两个APP，A和B，此时应用A去启动应用B中的一个Activity，并且该Activity设置`allowTaskReparenting = true`，此时这个Activity的任务栈就会位于应用A中，当去启动B时，会优先展示已被启动的Activity，由于设置了`allowTaskReparenting`该Activity的任务栈又回到了B中。

  <!--？？？ allowTaskReparenting = true 且两个Activity的TaskAffinity 相同会如何-->

> 拓展知识：
>
> 

### Activity的行为标志和属性

#### Activity的Flag

> 有些标记位可以设置启动模式，还有的可以影响Activity的运行状态。

##### FLAG_ACTIVITY_NEW_TASK

> 作用等同 `singleTask`启动模式

##### FLAG_ACTIVITY_SINGLE_TOP

> 作用等同`singleTop`启动模式

##### FLAG_ACTIVITY_CLEAR_TOP

> 当用这个标记启动对应Activity时，在同一个任务栈中的且位于它上面的Activity实例都会被消除。一般配合`singleTask`使用

##### FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS

> 对应的配置为在`AndroidManifest.xml`中使用`android:excludeFromRecents="true"`
>
> 具有这个标记的Activity不会出现在后台任务列表中

#### IntenFilter的匹配规则

> 启动Activity方法分为两种：`显式调用(可以清楚指出被启动组件的信息，例如类名)`，`隐式调用(没有明确的指出组件信息，通过IntentFilter找到符合要求的组件)`。

匹配规则：

1. 一个intent只有同时匹配某个Activity定义的`<intent-filter>`中定义的`action,category,data`才可以完全匹配，打开对应的Activity
2. 一个Activity可以定义多个<intent-filter>，只要匹配任意一组就可以启动该Activity

##### action匹配规则

> 只要传递过来的Intent中定义的`action`可以匹配`<intent-filter>`定义的任一`action`，必须要完全相同且区分大小写。

##### category匹配规则

> 传递过来的Intent中不包含`categroy`，那么就会启用默认的`categroy`，由于系统在启动Activity的时候默认会加上`android.intent.categroy.DEFAULT`属性
>
> 如果包含`categroy`，那必须匹配`<intent-filter>`定义的任一`categroy`

##### data匹配规则

> 传递过来的Intent定义的`data`可以匹配`<intent-filter>`定义的任一`data`

data主要分为两部分：

- `mimeType`：媒体类型，例如`text/plain`这类，还包括图片，视频类型
- `URL`：地址 包含了`host(主机名)，scheme(模式)，port(端口号)，path(路径信息)`等



*隐式启动时，如果无法找到要启动的组件，就会抛出异常。我们就可以利用`PackageManager.resolveActivity()`或者`Intent.resolveActivity()`避免异常出现。*

#### 清理任务栈

> 当用户离开一个任务时间很长时，系统将会清除除了根Activity之外的所有Activity，当用户重新回到应用时，只能看到根Activity。

系统提供了几种机制来调整这个规则：

- `android:alwaysRetainTaskState`

  标记应用的Task是否保持原来的状态，若为`true`，系统尝试保留所有Activity

- `android:clearTaskOnLaunch`

  标记是否从Task清除所有Activity除了根Activity，用户每次重新打开只会看到根Activity

- `android:finishOnTaskLaunch`

  只作用于单个Activity，若设置true，用户离开后回来就会消失



### 启动模式源码分析

> 关键节点在 `ActivityStarter.java`类下



### standard



### singleTop



### singleTask



### singleInstance



## 拓展

1. 何时会调用`onNewIntent()`?

   - LaunchMode设置为`singleTop`，且要启动的Activity已经处于栈顶
   - LaunchMode设置为`singleTask`或者`singleInstance`，且实例已存在

   需要注意的是：*当调用到`onNewIntent(intent)`的时候，需要在内部调用`setNewIntent(intent)`赋值给当前Activity的Intent，否则后续的getIntent()得到的都是老Intent*
   
2. 监控应用回到桌面或者应用退出

   ```java
    registerActivityLifecycleCallbacks(new ActivityLifecycleCallbacks() {
               int createdActivityCount = 0;
               int startedActivityCount = 0;
   
               @Override
               public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
                   createdActivityCount++;
               }
   
               @Override
               public void onActivityStarted(Activity activity) {
                   startedActivityCount++;
               }
   
               @Override
               public void onActivityResumed(Activity activity) {
   
               }
   
               @Override
               public void onActivityPaused(Activity activity) {
   
               }
   
               @Override
               public void onActivityStopped(Activity activity) {
                   startedActivityCount--;
                   // isChangingConfigurations 避免因为应用配置变化导致的退出使统计失误
                   if (startedActivityCount == 0 && !activity.isChangingConfigurations() && !activity.isFinishing()) {
                       Log.e("Home", "回到桌面");
                   }
               }
   
               @Override
               public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
   
               }
   
               @Override
               public void onActivityDestroyed(Activity activity) {
                   createdActivityCount--;
                   if (createdActivityCount == 0 && !activity.isChangingConfigurations()) {
                       Log.e("Exit", "应用退出");
                   }
               }
           });
   ```

   

3. s