---
title: Android屏幕的刷新机制
date: 2020-05-30 15:04:12
tags: Android
typora-root-url: ../
top: 10
---

![View屏幕刷新](/images/View屏幕刷新xmind.png)

## 基础概念

在显示系统中，一般包含三个部分`CPU、GPU，屏幕`。

`CPU`：执行View的绘制流程`measure,layout.draw`

`GPU`：进一步处理数据，对图形数据进行渲染并放到`buffer缓冲区`中缓存

`屏幕`：将`buffer缓冲区`的数据取出来填充屏幕像素点



**CPU绘制后提交数据，GPU进一步处理和缓存数据、最后屏幕从缓冲区获取数据并显示。**

![img](/images/webp-20200911191007410)

### 屏幕刷新频率

> 一秒内屏幕刷新的次数也即显示了多少帧的图像，单位`Hz`。一般都是60Hz。*该值取决于屏幕参数*

### 逐行扫描

> 屏幕不是一次性进行画面显示，而是从左到右，从上到下的进行`逐行扫描`。

### 帧率

> **GPU一秒内绘制操作的帧数。**Android系统默认60fps

帧率是动态变化的。

### 丢帧

> 在下一个`Vsync`信号到来时，由于下一帧数据尚未准备就绪，缓存没有交换，此时显示的上一帧的数据。该情况就为**丢帧(Jank)**

![丢帧](/images/丢帧.png)

### 双缓冲(`Double Buffer`)

> 为了解决`画面撕裂`提出的概念
>
> 画面撕裂：在GPU向缓冲区写入数据的同时，屏幕也在从`buffer缓冲区`读取数据，导致屏幕显示了不同帧的画面，产生`画面撕裂`。

由绘制和屏幕拥有各自的`buffer缓冲区`：

`GPU`处理完数据后，将图形数据写入`Back Buffer`。

`屏幕`从`Frame Buffer`读取图形数据。

当屏幕刷新(Vsync信号到来)时，`FrameBuffer`与`BackBuffer`的数据进行交换(**交换各自的内存地址**)，然后屏幕进行绘制。与`屏幕刷新频率`保持一个交换频率。

![双缓冲示意](/images/双缓冲)

### 垂直同步(`VSync`)

> **通过屏幕硬件中断告诉系统应该什么时候刷新屏幕。**
>
> 开启后GPU会等待显示器的VSync信号发出后再进行新的一帧渲染和缓冲区更新。
>
> 在显卡帧率大于屏幕帧率时有效解决显示问题。

配合`双缓冲`可以使`CPU/GPU`有充分时间处理数据，减少`jank(丢帧)`

![VSync](/images/VSync.png)

每次收到`VSync`信号时，CPU开始处理各帧数据。

### 三缓冲(`Triple Buffer`)

> 在`双缓冲`机制基础上增加了一个`Graphic Buffer`缓冲区，最大限度利用空闲时间，但是会多占用一个`Graphic buffer`缓冲区内存。

![三缓存](/images/三缓冲.png)

1. 第一个`Jank`时无可避免的，在第二个时间段，CPU/GPU使用第三个`Graphic Buffer`完成`C帧`的计算，避免`Jank`问题频发
2. 在第三段时，`A帧`计算完成，需要到第四个`Vsync`信号才会显示。
3. 第二段中，`C帧`需要在第四段才可以显示，相当于多了16ms延迟。

> **三缓冲**有效利用等待`vsync`的时间，减少了`jank`，但是增加了延迟。
>
> **`Graphic Buffer`不是越多越好，一般还是两个，出现`jank`以后可以三个。**



### Project Buffer(黄油计划)

前面提到的`VSYnc`、`双缓冲/三缓冲`都是`Project Buffer`的关键点，还有下面提到的`Choreographer`.

- 核心关键：**VSync**实现定时中断
- `双缓冲/三缓冲`：一般情况下`双缓冲`足矣，当出现`jank`时，可以添加一块`Graphic Buffer`缓冲区，实现`三缓冲`
- `Choreographer`：统一管理应用的绘制工作



## Choreographer

![View屏幕刷新-Choreographer](/images/View屏幕刷新-Choreographer.png)

> Android4.1 之后加入的`Choreographer`控制`Input输入`、`Animation动画`，`Draw绘制`三个UI操作。
>
> 每隔16.6ms，`VSync`信号到来时，马上开始下一帧的渲染，**CPU和GPU立即开始计算把数据写入Buffer中。**



![img](/images/15722752299458.jpg)

### 入口

既然说`Choreographer`与`View`的显示有关，`View的绘制过程`起点位于`ViewRootImpl.setView()`，此处为*Activity执行到`onResume()`后，`window`添加到Activity上*。通过调用到`ViewRootImpl.setView()`开始绘制布局

```java
//ActivityThread.java
public void handleResumeActivity(IBinder token, boolean finalStateRequest, boolean isForward,
            String reason) {
  ...
    if (a.mVisibleFromClient) {
                if (!a.mWindowAdded) {//尚未添加window
                    a.mWindowAdded = true;
                    wm.addView(decor, l);//准备添加View
                } else {
                    // The activity will get a callback for this {@link LayoutParams} change
                    // earlier. However, at that time the decor will not be set (this is set
                    // in this method), so no action will be taken. This call ensures the
                    // callback occurs with the decor set.
                    a.onWindowAttributesChanged(l);
                }
            }
  ...
  
}

//WindowManagerGlobal.java WindowManager实现类
    public void addView(View view, ViewGroup.LayoutParams params,
            Display display, Window parentWindow) {
      ...
        ViewRootImpl root;
      ...
        root = new ViewRootImpl(view.getContext(), display);
      ...
        try {
                root.setView(view, wparams, panelParentView);
            } catch (RuntimeException e) {
                // BadTokenException or InvalidDisplayException, clean up.
                if (index >= 0) {
                    removeViewLocked(index, true);
                }
                throw e;
            }
      ...
    }

//ViewRootImpl.java
   public void setView(View view /*DecorView*/, WindowManager.LayoutParams attrs, View panelParentView) {
     ...
       requestLayout();//刷新布局
     ...
       view.assignParent(this); //设置DecorView 父类为 ViewRootImpl，此时将ViewRootImpl与DecorView进行绑定
     ...
   }
//View.java
    void assignParent(ViewParent parent) {
        if (mParent == null) {
            mParent = parent;
        } else if (parent == null) {
            mParent = null;
        } else {
            throw new RuntimeException("view " + this + " being added, but"
                    + " it already has a parent");
        }
    }

//ViewRootImpl.java
    @Override
    public void requestLayout() {
        if (!mHandlingLayoutInLayoutRequest) {
            checkThread();
            mLayoutRequested = true;
            scheduleTraversals();
        }
    }
```

根据上述源码可以得出以下结论：

- Activity走完`onResume()`之后会进行`window的添加`
- `window添加`过程中在`ViewRootImpl.setView()`中将`DecorView`与`ViewRootImpl`进行绑定
- `ViewRootImpl`与`DecorView`绑定后开始进行View的绘制任务

> 为什么`onCreate()`无法获取View宽高？
>
> 此时未执行到`onResume()`尚未开始绘制，也还没开始执行`measure -> layout -> draw`过程，也就无法获取。

以上只是`Activity启动`时相关的绘制过程，此外还有`属性动画、View.invalidate()`都会影响到`UI变化`。

**所有的UI变化都是走到`ViewRootImpl.scheduleTraversals()`。**



#### ViewRootImpl.scheduleTraversals()

`UI变化`最终都会走到此处。

```java
//ViewRootImpl.java
    final ViewRootHandler mHandler = new ViewRootHandler();

    void scheduleTraversals() {
        if (!mTraversalScheduled) {
          //保证多次调用UI刷新，只走一次绘制流程
            mTraversalScheduled = true;
          //添加同步屏障，屏蔽同步消息，保证Vsync到来时优先绘制流程
            mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
          //使用到了 Choreographer
            mChoreographer.postCallback(
                    Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
            ...
        }
    }

    final class TraversalRunnable implements Runnable {
        @Override
        public void run() {
            doTraversal();
        }
    }
    final TraversalRunnable mTraversalRunnable = new TraversalRunnable();

    void doTraversal() {
        if (mTraversalScheduled) {
          //执行任务时，恢复状态
            mTraversalScheduled = false;
          //移除同步屏障
            mHandler.getLooper().getQueue().removeSyncBarrier(mTraversalBarrier);

            if (mProfile) {
                Debug.startMethodTracing("ViewAncestor");
            }
           //开始View的绘制流程
            performTraversals();

            if (mProfile) {
                Debug.stopMethodTracing();
                mProfile = false;
            }
        }
    }

```

`scheduleTraversals()`主要有以下逻辑：

1. 设置`mTraversalScheduled)`保证同时多次请求只会进行一次`View刷新`
2. 在`getLooper().getQueue()当前消息队列`添加**同步屏障**，保证`Vsync信号`到来时，可以立即执行对应任务。暂时屏蔽掉`同步消息`的处理。
3. 调用`Choreographer.postCallback(,mTraversalRunnable,)`，在下一次`VSync信号到来时`，会执行`doTraversal()`，继续向下调用`performTraversals()`开始绘制流程。

### 构造函数

```java
//Choreographer.java
    public static Choreographer getInstance() {
        return sThreadInstance.get();
    }

    private static final ThreadLocal<Choreographer> sThreadInstance =
            new ThreadLocal<Choreographer>() {
        @Override
        protected Choreographer initialValue() {
            //获取当前线程的Looper对象
            Looper looper = Looper.myLooper();
            if (looper == null) {
                throw new IllegalStateException("The current thread must have a looper!");
            }
            Choreographer choreographer = new Choreographer(looper, VSYNC_SOURCE_APP);
            if (looper == Looper.getMainLooper()) {
                mMainInstance = choreographer;
            }
            return choreographer;
        }
    };
```

`Choreographer`和`Handler`中的`Looper`一致，都是每个线程持有一个`Choreographer`，通过`ThreadLocal`进行获取。

接下来是`Choreographer`的构造方法

```java
//Choreographer.java    
private Choreographer(Looper looper, int vsyncSource) {
        mLooper = looper;
       //创建Handler对象
        mHandler = new FrameHandler(looper);
       //接收Vsync信号
        mDisplayEventReceiver = USE_VSYNC //USE_VSYNC在4.1以上默认 true，表示可以接收VSync信号
                ? new FrameDisplayEventReceiver(looper, vsyncSource)
                : null;
        //上一次帧绘制的时间点
        mLastFrameTimeNanos = Long.MIN_VALUE;
        //每帧的差值，一般为16.6ms
        mFrameIntervalNanos = (long)(1000000000 / getRefreshRate());
        //初始化回调队列
        mCallbackQueues = new CallbackQueue[CALLBACK_LAST + 1];
        for (int i = 0; i <= CALLBACK_LAST; i++) {
            mCallbackQueues[i] = new CallbackQueue();
        }
        // b/68769804: For low FPS experiments.
        setFPSDivisor(SystemProperties.getInt(ThreadedRenderer.DEBUG_FPS_DIVISOR, 1));
    }

```

`Choreographer`在构造时分别执行了以下几步：

- 初始化`FrameHandler(接收并处理消息)`
- 初始化`FrameDisplayEventReceiver(接收VSync信号)`
- 初始化`mLastFrameTimeNanos(上一次绘制帧时间点)`、`mFrameIntervalNanos(帧率)`
- 初始化`mCallbackQueues(回调队列)`

#### FrameHandler

> 发送异步消息（设置了同步屏障）。有延迟的任务发送延迟消息，不在主线程的任务发到主线程。

```java
    private final class FrameHandler extends Handler {
        public FrameHandler(Looper looper) {
            super(looper);
        }

        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case MSG_DO_FRAME:
                //执行绘制过程
                    doFrame(System.nanoTime(), 0);
                    break;
                case MSG_DO_SCHEDULE_VSYNC:
                //当需要执行绘制任务时，申请VSync信号
                    doScheduleVsync();
                    break;
                case MSG_DO_SCHEDULE_CALLBACK:
                //执行需要延迟的任务
                    doScheduleCallback(msg.arg1);
                    break;
            }
        }
    }
```

主要处理以下类型的消息：

- `MSG_DO_FRAME`：开始绘制流程
- `MSG_DO_SCHEDULE_VSYNC`：请求VSync信号
- `MSG_DO_SCHEDULE_CALLBACK`：请求执行`Callback`



#### FrameDisplayEventReceiver

> 主要用来接收`VSync信号`，控制系统的同步操作

```java
private final class FrameDisplayEventReceiver extends DisplayEventReceiver
            implements Runnable {
        private boolean mHavePendingVsync;
        private long mTimestampNanos;
        private int mFrame;

        public FrameDisplayEventReceiver(Looper looper, int vsyncSource) {
            super(looper, vsyncSource);
        }

  //此处接收 VSync信号
        @Override
        public void onVsync(long timestampNanos, int builtInDisplayId, int frame) {
            if (builtInDisplayId != SurfaceControl.BUILT_IN_DISPLAY_ID_MAIN) {
                Log.d(TAG, "Received vsync from secondary display, but we don't support "
                        + "this case yet.  Choreographer needs a way to explicitly request "
                        + "vsync for a specific display to ensure it doesn't lose track "
                        + "of its scheduled vsync.");
                scheduleVsync();
                return;
            }
          
            long now = System.nanoTime();
            if (timestampNanos > now) {
                Log.w(TAG, "Frame time is " + ((timestampNanos - now) * 0.000001f)
                        + " ms in the future!  Check that graphics HAL is generating vsync "
                        + "timestamps using the correct timebase.");
                timestampNanos = now;
            }

            if (mHavePendingVsync) {
                Log.w(TAG, "Already have a pending vsync event.  There should only be "
                        + "one at a time.");
            } else {
                mHavePendingVsync = true;
            }
          //VSync信号到来的时间
            mTimestampNanos = timestampNanos;
            mFrame = frame;
          //构建异步消息，传入本身作为任务的执行者，需要执行的任务就是 run()
            Message msg = Message.obtain(mHandler, this);
            msg.setAsynchronous(true);
            mHandler.sendMessageAtTime(msg, timestampNanos / TimeUtils.NANOS_PER_MS);
        }

  //需要执行的任务
        @Override
        public void run() {
            mHavePendingVsync = false;
            doFrame(mTimestampNanos, mFrame);
        }
    }
```

接收到`VSync信号`后，回调到`onVsync()`方法，在其中构造一个`异步消息`，传入`FrameDisplayEventReceiver`为`runnable`，通过`FrameHandler`发送该消息，等到消息触发时就执行`doFrame()`。



#### CallbackQueue

> 存储对应任务类型的队列，在执行任务时从对应队列中获取任务

```java
    private final class CallbackQueue {
        private CallbackRecord mHead;

      //当前是否有等待执行的任务
        public boolean hasDueCallbacksLocked(long now) {
            return mHead != null && mHead.dueTime <= now;
        }

      //获取队列任务
        public CallbackRecord extractDueCallbacksLocked(long now) {
            CallbackRecord callbacks = mHead;
            if (callbacks == null || callbacks.dueTime > now) {
                return null;
            }

            CallbackRecord last = callbacks;
            CallbackRecord next = last.next;
            while (next != null) {
                if (next.dueTime > now) {
                    last.next = null;
                    break;
                }
                last = next;
                next = next.next;
            }
            mHead = next;
            return callbacks;
        }

      //添加消息
        public void addCallbackLocked(long dueTime, Object action, Object token) {
            CallbackRecord callback = obtainCallbackLocked(dueTime, action, token);
            CallbackRecord entry = mHead;
            if (entry == null) {
                mHead = callback;
                return;
            }
            if (dueTime < entry.dueTime) {
                callback.next = entry;
                mHead = callback;
                return;
            }
            while (entry.next != null) {
                if (dueTime < entry.next.dueTime) {
                    callback.next = entry.next;
                    break;
                }
                entry = entry.next;
            }
            entry.next = callback;
        }

      //删除消息
        public void removeCallbacksLocked(Object action, Object token) {
            CallbackRecord predecessor = null;
            for (CallbackRecord callback = mHead; callback != null;) {
                final CallbackRecord next = callback.next;
                if ((action == null || callback.action == action)
                        && (token == null || callback.token == token)) {
                    if (predecessor != null) {
                        predecessor.next = next;
                    } else {
                        mHead = next;
                    }
                    recycleCallbackLocked(callback);
                } else {
                    predecessor = callback;
                }
                callback = next;
            }
        }
    }
```

`CallbackQueue`存储的元素为`CallbackRecord`

```java
    private static final class CallbackRecord {
        public CallbackRecord next;
        public long dueTime;
        public Object action; // Runnable or FrameCallback
        public Object token;

        public void run(long frameTimeNanos) {
            if (token == FRAME_CALLBACK_TOKEN) {
              //执行了postFrameCallback()或 postFrameCallbackDelayed 执行此处
                ((FrameCallback)action).doFrame(frameTimeNanos);
            } else {
              //否则执行 run
                ((Runnable)action).run();
            }
        }
    }
```

根据源码`CallbackRecord`执行`run()`有两种情况：

- token不为null且`FRAME_CALLBACK_TOKEN`

  > 执行`doFrame()`，实际这种情况只会执行`postFrameCallback()`或`postFrameCallbackDelayed()`。
  >
  > 这两个方法在{% post_link Android动画-属性动画%}都会被调用到

- token为其他

  > 执行`run()`，此时`action`对应的就是`ViewRootImpl的mTraversalRunnable`也就会开始执行绘制流程

### 设置任务-postCallback()

`ViewRootImpl.scheduleTraversals()`通过`postCallback(Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null)`添加绘制任务

```java
//Choreographer.java 
private void postCallbackDelayedInternal(int callbackType,
            Object action, Object token, long delayMillis) {
        ...
        synchronized (mLock) {
          //当前时间
            final long now = SystemClock.uptimeMillis();
          //延迟时间
            final long dueTime = now + delayMillis;
          //将任务添加到回调队列
            mCallbackQueues[callbackType].addCallbackLocked(dueTime, action, token);

            if (dueTime <= now) {
              //任务立即开始执行
                scheduleFrameLocked(now);
            } else {
              //封装异步消息等待执行
                Message msg = mHandler.obtainMessage(MSG_DO_SCHEDULE_CALLBACK, action);
                msg.arg1 = callbackType;
                msg.setAsynchronous(true);
                mHandler.sendMessageAtTime(msg, dueTime);
            }
        }
    }

  private final class FrameHandler extends Handler {
     ...
     @Override
     public void handleMessage(Message msg) {
       ...
        case MSG_DO_SCHEDULE_CALLBACK:
           doScheduleCallback(msg.arg1);
           break;
     }
    }

    void doScheduleCallback(int callbackType) {
        synchronized (mLock) {
            if (!mFrameScheduled) {
                final long now = SystemClock.uptimeMillis();
                if (mCallbackQueues[callbackType].hasDueCallbacksLocked(now)) {
                    scheduleFrameLocked(now);
                }
            }
        }
    }
```

`CallbackType`表示回调任务的类型，目前分为4种类型

- `CALLBACK_INPUT`：输入回调，接收到`VSync信号`时首先运行，如处理Move事件
- `CALLBACK_ANIMATION`：动画回调
- `CALLBACK_TRAVERSAL`：Traversal回调，执行`measure->layout->draw`
- `CALLBACK_COMMIT`：Commit回调，处理帧绘制完成后的操作，如整理应用内存，属性动画起始时间调整

`postCallback()`最后都会执行到`scheduleFrameLocked()`

```java
 private void scheduleFrameLocked(long now) {
        if (!mFrameScheduled) {//当前是否有帧在执行
            mFrameScheduled = true;
            if (USE_VSYNC) {//支持VSync，默认true
                if (DEBUG_FRAMES) {
                    Log.d(TAG, "Scheduling next frame on vsync.");
                }
              
                //当前运行在Looper所在的线程，立即执行申请VSync信号
                if (isRunningOnLooperThreadLocked()) {
                    scheduleVsyncLocked();
                } else {
                  //通过 mHandler发送异步消息到原线程，申请VSync信号
                    Message msg = mHandler.obtainMessage(MSG_DO_SCHEDULE_VSYNC);
                    msg.setAsynchronous(true);
                    mHandler.sendMessageAtFrontOfQueue(msg);
                }
            } else {//不支持 VSync
                final long nextFrameTime = Math.max(
                        mLastFrameTimeNanos / TimeUtils.NANOS_PER_MS + sFrameDelay, now);
                if (DEBUG_FRAMES) {
                    Log.d(TAG, "Scheduling next frame in " + (nextFrameTime - now) + " ms.");
                }
                //执行 doFrame()
                Message msg = mHandler.obtainMessage(MSG_DO_FRAME);
                msg.setAsynchronous(true);
                mHandler.sendMessageAtTime(msg, nextFrameTime);
            }
        }
    }

    private final class FrameHandler extends Handler {
      ...
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case MSG_DO_FRAME:
                    doFrame(System.nanoTime(), 0);
                    break;
                case MSG_DO_SCHEDULE_VSYNC:
                    doScheduleVsync();
                    break;
                ...
            }
        }
    }

    void doScheduleVsync() {
        synchronized (mLock) {
            if (mFrameScheduled) {
                scheduleVsyncLocked();
            }
        }
    }
```

`postCallback()`主要执行了以下几步：

1. 实际执行的为`postCallbackDelayedInternal()`，先将任务通过`addCallbackLocked()`添加到`CallbackQueue`中
2. 判断任务执行时间与当前时间的差值
   - 执行时间在当前时间之前：直接执行`scheduleFrameLocked()`
   - 执行时间在当前时间之后：将任务封装成`异步消息`，通过`mHandler`发送消息，且消息为`MSG_CO_SCHEDULE_CALLBACK`。到达执行时间之后，也是执行`scheduleFrameLocked()`
3. 执行`scheduleFrameLocked()`，需要先判断`mFrameSchduled`，在执行跳过此次任务；未执行，继续判断`是否支持VSync`
   - 不支持`VSync`：封装异步消息，且消息为`MSG_DO_FRAME`，发送消息到主线程，执行`doFrame()`
   - 支持`VSync`：需要判断当前是否为UI线程
     - 是UI线程：立即执行`scheduleVsyncLocked()`
     - 非UI线程：封装异步消息，且消息为`MSG_DO_SCHEDULE_VSYNC`，发送消息到主线程，后执行`scheduleVsyncLocked()`
4. 执行`scheduleVsyncLocked()`去申请`Vsync信号`。

> 简单总结`postCallback()`
>
> 

### 申请和接收信号-onVsync()

上一节调用的`scheduleVsyncLocked()`申请`VSync信号`

```java
    private void scheduleVsyncLocked() {
        mDisplayEventReceiver.scheduleVsync();
    }

//DisplayEventReceiver.java
    public void scheduleVsync() {
        if (mReceiverPtr == 0) {
            Log.w(TAG, "Attempted to schedule a vertical sync pulse but the display event "
                    + "receiver has already been disposed.");
        } else {
            nativeScheduleVsync(mReceiverPtr);
        }
    }
```

`nativeScheduleVsync()`调用native方法申请`VSync信号`



```java
//DisplayEventReceiver.java
    // Called from native code.
    @SuppressWarnings("unused")
    private void dispatchVsync(long timestampNanos, int builtInDisplayId, int frame) {
        onVsync(timestampNanos, builtInDisplayId, frame);
    }
```

通过native调用`dispatchVsync()`回调`onVsync()`



```java
//Chorgegrapher.FrameDisplayEventReceiver.java
    private final class FrameDisplayEventReceiver extends DisplayEventReceiver
            implements Runnable {
      ...
      @Override
      public void onVsync(long timestampNanos, int builtInDisplayId, int frame) {
       ...
            Message msg = Message.obtain(mHandler, this);
            msg.setAsynchronous(true);
            mHandler.sendMessageAtTime(msg, timestampNanos / TimeUtils.NANOS_PER_MS);
      }
      
        @Override
        public void run() {
            mHavePendingVsync = false;
            doFrame(mTimestampNanos, mFrame);
        }
    }
```

将本身作为`runnable`对象，执行的就是`run()`，最终执行的就是`doFrame()`

### 执行任务-doFrame()

> 最终在接收到`VSync`信号时，执行`doFrame()`

```java
    void doFrame(long frameTimeNanos, int frame) {
        final long startNanos;
        synchronized (mLock) {//
            if (!mFrameScheduled) {//当前有任务在执行
                return; // no work to do
            }
            ...
            //预期执行时间
            long intendedFrameTimeNanos = frameTimeNanos;
            //实际frame执行时间
            startNanos = System.nanoTime();
            //预期与实际时间差
            final long jitterNanos = startNanos - frameTimeNanos;
            if (jitterNanos >= mFrameIntervalNanos) {//时间差大于一帧执行时长，当前为16.6ms
                final long skippedFrames = jitterNanos / mFrameIntervalNanos;//计算跳过的帧数
                if (skippedFrames >= SKIPPED_FRAME_WARNING_LIMIT) {//默认30
                    //跳过的帧数超出了30时，打印日志
                    Log.i(TAG, "Skipped " + skippedFrames + " frames!  "
                            + "The application may be doing too much work on its main thread.");
                }
                //重新计算实际执行与当前时间的偏差值
                final long lastFrameOffset = jitterNanos % mFrameIntervalNanos;
                if (DEBUG_JANK) {
                    Log.d(TAG, "Missed vsync by " + (jitterNanos * 0.000001f) + " ms "
                            + "which is more than the frame interval of "
                            + (mFrameIntervalNanos * 0.000001f) + " ms!  "
                            + "Skipping " + skippedFrames + " frames and setting frame "
                            + "time to " + (lastFrameOffset * 0.000001f) + " ms in the past.");
                }
                //修正偏差值，方便后续同步工作
                frameTimeNanos = startNanos - lastFrameOffset;
            }

          //当前时间小于上一次绘制时间，就等待下一次绘制时机到老
            if (frameTimeNanos < mLastFrameTimeNanos) {
                if (DEBUG_JANK) {
                    Log.d(TAG, "Frame time appears to be going backwards.  May be due to a "
                            + "previously skipped frame.  Waiting for next vsync.");
                }
                scheduleVsyncLocked();
                return;
            }

            if (mFPSDivisor > 1) {
                long timeSinceVsync = frameTimeNanos - mLastFrameTimeNanos;
                if (timeSinceVsync < (mFrameIntervalNanos * mFPSDivisor) && timeSinceVsync > 0) {
                    scheduleVsyncLocked();
                    return;
                }
            }

            mFrameInfo.setVsync(intendedFrameTimeNanos, frameTimeNanos);
            mFrameScheduled = false;
          //记录上一次绘制时间
            mLastFrameTimeNanos = frameTimeNanos;
        }

        try {
           //按类型顺序执行任务
            Trace.traceBegin(Trace.TRACE_TAG_VIEW, "Choreographer#doFrame");
            AnimationUtils.lockAnimationClock(frameTimeNanos / TimeUtils.NANOS_PER_MS);

            mFrameInfo.markInputHandlingStart();
            //输入
            doCallbacks(Choreographer.CALLBACK_INPUT, frameTimeNanos);

            mFrameInfo.markAnimationsStart();
            //动画
            doCallbacks(Choreographer.CALLBACK_ANIMATION, frameTimeNanos);

            mFrameInfo.markPerformTraversalsStart();
            //绘制
            doCallbacks(Choreographer.CALLBACK_TRAVERSAL, frameTimeNanos);
            //遍历完成的提交操作
            doCallbacks(Choreographer.CALLBACK_COMMIT, frameTimeNanos);
        } finally {
            AnimationUtils.unlockAnimationClock();
            Trace.traceEnd(Trace.TRACE_TAG_VIEW);
        }

        if (DEBUG_FRAMES) {
            final long endNanos = System.nanoTime();
            Log.d(TAG, "Frame " + frame + ": Finished, took "
                    + (endNanos - startNanos) * 0.000001f + " ms, latency "
                    + (startNanos - frameTimeNanos) * 0.000001f + " ms.");
        }
    }
```

`doFrame()`主要执行了两步：

1. 修正`frame`执行时间
2. 按照顺序，从`callbackQueue`获取`CallbackRecord`执行

```java
void doCallbacks(int callbackType, long frameTimeNanos) {
        CallbackRecord callbacks;
        synchronized (mLock) {
            // We use "now" to determine when callbacks become due because it's possible
            // for earlier processing phases in a frame to post callbacks that should run
            // in a following phase, such as an input event that causes an animation to start.
            final long now = System.nanoTime();
            //根据回调类型获取可执行回调(已到达执行时间)
            callbacks = mCallbackQueues[callbackType].extractDueCallbacksLocked(
                    now / TimeUtils.NANOS_PER_MS);
            if (callbacks == null) {
                return;
            }
            mCallbacksRunning = true;

            ...
            //属于 提交任务类型
            if (callbackType == Choreographer.CALLBACK_COMMIT) {
                final long jitterNanos = now - frameTimeNanos;
                Trace.traceCounter(Trace.TRACE_TAG_VIEW, "jitterNanos", (int) jitterNanos);
                if (jitterNanos >= 2 * mFrameIntervalNanos) {
                    final long lastFrameOffset = jitterNanos % mFrameIntervalNanos
                            + mFrameIntervalNanos;
                    if (DEBUG_JANK) {
                        Log.d(TAG, "Commit callback delayed by " + (jitterNanos * 0.000001f)
                                + " ms which is more than twice the frame interval of "
                                + (mFrameIntervalNanos * 0.000001f) + " ms!  "
                                + "Setting frame time to " + (lastFrameOffset * 0.000001f)
                                + " ms in the past.");
                        mDebugPrintNextFrameTimeDelta = true;
                    }
                    frameTimeNanos = now - lastFrameOffset;
                    mLastFrameTimeNanos = frameTimeNanos;
                }
            }
        }
        try {
            Trace.traceBegin(Trace.TRACE_TAG_VIEW, CALLBACK_TRACE_TITLES[callbackType]);
            //迭代执行对应 callbackType队列的任务
            for (CallbackRecord c = callbacks; c != null; c = c.next) {
                if (DEBUG_FRAMES) {
                    Log.d(TAG, "RunCallback: type=" + callbackType
                            + ", action=" + c.action + ", token=" + c.token
                            + ", latencyMillis=" + (SystemClock.uptimeMillis() - c.dueTime));
                }
              //回调CallbackRecord的run()
                c.run(frameTimeNanos);
            }
        } finally {
            synchronized (mLock) {
                mCallbacksRunning = false;
                do {
                    final CallbackRecord next = callbacks.next;
                    recycleCallbackLocked(callbacks);
                    callbacks = next;
                } while (callbacks != null);
            }
            Trace.traceEnd(Trace.TRACE_TAG_VIEW);
        }
    }

private static final class CallbackRecord {
        ...
        public void run(long frameTimeNanos) {
            if (token == FRAME_CALLBACK_TOKEN) {
              //执行了postFrameCallback()或 postFrameCallbackDelayed 执行此处
                ((FrameCallback)action).doFrame(frameTimeNanos);
            } else {
              //否则执行 run
                ((Runnable)action).run();
            }
        }
    }
```

`doCallbacks()`主要执行了以下几步：

1. `extractDueCallbacksLocked(now/TimeUtils.NANOS_PER_MS)`获取当前时间之前所有可执行的Callback，保存在单链表中。

2. 关于`CALLBACK_COMMIT`的处理，如果当前`frame`渲染时间超出了两个`Vsync`间隔，将当前提交时间修正为上一次`VSync信号`发出时间。**为了保证下一个frame的提交时间和当前frame的时间相差为1且不重复**。

   `CALLBACK_COMMIT`是为了解决`属性动画`的问题引入的，有时候可能因遍历时间或绘制时间过长，导致动画启动时间过长，发生跳帧，在此处**修正动画的第一帧时间**。

   ![img](/images/CALLBACK_COMMIT作用)

   修正了动画启动时间，保证动画执行时间的正确性。

3. 最后取出`CallbackRecord`，执行`run()`



![View刷新过程](/images/View刷新过程.jpg)



## Vsync申请和回调流程(Native)

### 申请Vsync信号



`frameworks/base/core/jni/android_view_DisplayEventReceiver.cpp`

`frameworks/native/libs/gui/DisplayEventDispatcher.cpp`

> 从`nativeScheduleVsync()`开始监听`VSync信号`

```java
//DisplayEventReceiver.java
    private static native void nativeScheduleVsync(long receiverPtr);

    //初始化
    public DisplayEventReceiver(Looper looper, int vsyncSource) {
        if (looper == null) {
            throw new IllegalArgumentException("looper must not be null");
        }

        mMessageQueue = looper.getQueue();
        mReceiverPtr = nativeInit(new WeakReference<DisplayEventReceiver>(this), mMessageQueue,
                vsyncSource);

        mCloseGuard.open("dispose");
    }
```

> 执行`nativeInit()`初始化并创建`DisplayEventReceiver`

```c++
//android_view_DisplayEventReceiver.cpp
static jlong nativeInit(JNIEnv* env, jclass clazz, jobject receiverWeak,
        jobject messageQueueObj, jint vsyncSource, jint configChanged) {
    sp<MessageQueue> messageQueue = android_os_MessageQueue_getMessageQueue(env, messageQueueObj);
    if (messageQueue == NULL) {
        jniThrowRuntimeException(env, "MessageQueue is not initialized.");
        return 0;
    }
    //创建NAtiveDisplayEventReceiver，与SurfaceFlinger建立连接
    sp<NativeDisplayEventReceiver> receiver = new NativeDisplayEventReceiver(env,
            receiverWeak, messageQueue, vsyncSource, configChanged);
    status_t status = receiver->initialize();
    if (status) {
        String8 message;
        message.appendFormat("Failed to initialize display event receiver.  status=%d", status);
        jniThrowRuntimeException(env, message.string());
        return 0;
    }

    receiver->incStrong(gDisplayEventReceiverClassInfo.clazz); // retain a reference for the object
    return reinterpret_cast<jlong>(receiver.get());
}

NativeDisplayEventReceiver::NativeDisplayEventReceiver(JNIEnv* env,
        jobject receiverWeak, const sp<MessageQueue>& messageQueue, jint vsyncSource,
        jint configChanged) :
        DisplayEventDispatcher(messageQueue->getLooper(),
                static_cast<ISurfaceComposer::VsyncSource>(vsyncSource),
                static_cast<ISurfaceComposer::ConfigChanged>(configChanged)),
        mReceiverWeakGlobal(env->NewGlobalRef(receiverWeak)),
        mMessageQueue(messageQueue) {
    ALOGV("receiver %p ~ Initializing display event receiver.", this);
}
```



新建完`DisplayEventReceiver`，由`DisplayEventDispatcher`进行后续操作

```c++
//DisplayEventReceiver.h
class DisplayEventDispatcher : public LooperCallback {
  public:
    explicit DisplayEventDispatcher(
            const sp<Looper>& looper,
            ISurfaceComposer::VsyncSource vsyncSource = ISurfaceComposer::eVsyncSourceApp,
            ISurfaceComposer::ConfigChanged configChanged =
                    ISurfaceComposer::eConfigChangedSuppress);
   ...
     
    private:
    sp<Looper> mLooper;
    DisplayEventReceiver mReceiver;
    ...
      
}


//DisplayEventDispatcher.cpp
DisplayEventDispatcher::DisplayEventDispatcher(const sp<Looper>& looper,
                                               ISurfaceComposer::VsyncSource vsyncSource,
                                               ISurfaceComposer::ConfigChanged configChanged)
      : mLooper(looper), mReceiver(vsyncSource, configChanged), mWaitingForVsync(false) {
    ALOGV("dispatcher %p ~ Initializing display event dispatcher.", this);
}
```

```c++
//DisplayEventReceiver.cpp
DisplayEventReceiver::DisplayEventReceiver(ISurfaceComposer::VsyncSource vsyncSource,
                                           ISurfaceComposer::ConfigChanged configChanged) {
    sp<ISurfaceComposer> sf(ComposerService::getComposerService());
    if (sf != nullptr) {
        //为客户端创建显示连接，通过该连接请求SurfaceFlinger发送及接收Vsync信号
        mEventConnection = sf->createDisplayEventConnection(vsyncSource, configChanged);
        if (mEventConnection != nullptr) {
            //创建BitTube
            mDataChannel = std::make_unique<gui::BitTube>();
            //通过Binder获取对应Connection的Socket
            mEventConnection->stealReceiveChannel(mDataChannel.get());
        }
    }
}
```

#### createDisplayEventConnection

`createDisplayEventConnection()`是一个Binder IPC

```c++
//ISurfaceComposer.cpp
    virtual sp<IDisplayEventConnection> createDisplayEventConnection(VsyncSource vsyncSource,
                                                                     ConfigChanged configChanged) {
        Parcel data, reply;
        sp<IDisplayEventConnection> result;
        int err = data.writeInterfaceToken(
                ISurfaceComposer::getInterfaceDescriptor());
        if (err != NO_ERROR) {
            return result;
        }
        data.writeInt32(static_cast<int32_t>(vsyncSource));
        data.writeInt32(static_cast<int32_t>(configChanged));
        //请求SurfaceLinger处理 CREATE_DISPLAY_EVENT_CONNECTION
        err = remote()->transact(
                BnSurfaceComposer::CREATE_DISPLAY_EVENT_CONNECTION,
                data, &reply);
        if (err != NO_ERROR) {
            ALOGE("ISurfaceComposer::createDisplayEventConnection: error performing "
                    "transaction: %s (%d)", strerror(-err), -err);
            return result;
        }
        result = interface_cast<IDisplayEventConnection>(reply.readStrongBinder());
        return result;
    }
```

在`onTransact()`处理发过来的`CREATE_DISPLAY_EVENT_CONNECTION`

```c++
//ISurfaceComposer.cpp
status_t BnSurfaceComposer::onTransact(
    uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
{
  ...
          case CREATE_DISPLAY_EVENT_CONNECTION: {
            CHECK_INTERFACE(ISurfaceComposer, data, reply);
            auto vsyncSource = static_cast<ISurfaceComposer::VsyncSource>(data.readInt32());
            auto configChanged = static_cast<ISurfaceComposer::ConfigChanged>(data.readInt32());

            sp<IDisplayEventConnection> connection(
                    createDisplayEventConnection(vsyncSource, configChanged));
            reply->writeStrongBinder(IInterface::asBinder(connection));
            return NO_ERROR;
        }
  ...
}
```

通过`SurfaceFlinger`处理请求

```c++
sp<IDisplayEventConnection> SurfaceFlinger::createDisplayEventConnection(
        ISurfaceComposer::VsyncSource vsyncSource, ISurfaceComposer::ConfigChanged configChanged) {
    const auto& handle =
            vsyncSource == eVsyncSourceSurfaceFlinger ? mSfConnectionHandle : mAppConnectionHandle;

    return mScheduler->createDisplayEventConnection(handle, configChanged);
}
```

```c++
//EventThread.cpp
sp<EventThreadConnection> Scheduler::createConnectionInternal(
        EventThread* eventThread, ISurfaceComposer::ConfigChanged configChanged) {
    return eventThread->createEventConnection([&] { resync(); }, configChanged);
}

sp<IDisplayEventConnection> Scheduler::createDisplayEventConnection(
        ConnectionHandle handle, ISurfaceComposer::ConfigChanged configChanged) {
    RETURN_IF_INVALID_HANDLE(handle, nullptr);
    return createConnectionInternal(mConnections[handle].thread.get(), configChanged);
}

sp<EventThreadConnection> EventThread::createEventConnection(
        ResyncCallback resyncCallback, ISurfaceComposer::ConfigChanged configChanged) const {
    return new EventThreadConnection(const_cast<EventThread*>(this), std::move(resyncCallback),
                                     configChanged);
}
```

最后生成`EventConnection`对象，主要有两个作用：

- 处理客户的的Vsync申请请求
- 向客户端发送事件(Vsync)

```c++
//EventThread.cpp
EventThreadConnection::EventThreadConnection(EventThread* eventThread,
                                             ResyncCallback resyncCallback,
                                             ISurfaceComposer::ConfigChanged configChanged)
      : resyncCallback(std::move(resyncCallback)),
        mConfigChanged(configChanged),
        mEventThread(eventThread),
        mChannel(gui::BitTube::DefaultSize) {}
```

`BitTube`是一个`Socket pair`，主要有两个作用：

- 封装用于显示时间的Socket通信
- 跨进程传递Socket文件描述符(`fd`)

```c++
void EventThreadConnection::onFirstRef() {
    // NOTE: mEventThread doesn't hold a strong reference on us
    mEventThread->registerDisplayEventConnection(this);
}

status_t EventThread::registerDisplayEventConnection(const sp<EventThreadConnection>& connection) {
    std::lock_guard<std::mutex> lock(mMutex);

    // this should never happen
    auto it = std::find(mDisplayEventConnections.cbegin(),
            mDisplayEventConnections.cend(), connection);
    if (it != mDisplayEventConnections.cend()) {
        ALOGW("DisplayEventConnection %p already exists", connection.get());
        mCondition.notify_all();
        return ALREADY_EXISTS;
    }
    //添加连接到集合中
    mDisplayEventConnections.push_back(connection);
    mCondition.notify_all();
    return NO_ERROR;
}

```

`EventThread`与`EventThreadConnection`采用`观察者模式`，当有显示事件发生时，`EventThread`向`EventThreadConnection`传递事件。

#### stealReceiveChannel

通过一系列操作得到`EventConnection`，在向下执行到`stealReceiveChannel()`

```c++
class BpDisplayEventConnection : public SafeBpInterface<IDisplayEventConnection> {
  ...
        status_t stealReceiveChannel(gui::BitTube* outChannel) override {
        return callRemote<decltype(
                &IDisplayEventConnection::stealReceiveChannel)>(Tag::STEAL_RECEIVE_CHANNEL,
                                                                outChannel);
    }
  ...
}
  
status_t BnDisplayEventConnection::onTransact(uint32_t code, const Parcel& data, Parcel* reply,
                                              uint32_t flags) {
    if (code < IBinder::FIRST_CALL_TRANSACTION || code > static_cast<uint32_t>(Tag::LAST)) {
        return BBinder::onTransact(code, data, reply, flags);
    }
    auto tag = static_cast<Tag>(code);
    switch (tag) {
        case Tag::STEAL_RECEIVE_CHANNEL:
            return callLocal(data, reply, &IDisplayEventConnection::stealReceiveChannel);
        ...
    }
}
```



监听`mReceivcer`所获的文件句柄，一旦有数据到来，回调给`this`即`DisplayEventDispatcher`的`handleEvent()`

```c++
status_t DisplayEventDispatcher::initialize() {
    status_t result = mReceiver.initCheck();
    if (result) {
        ALOGW("Failed to initialize display event receiver, status=%d", result);
        return result;
    }

    if (mLooper != nullptr) {
        int rc = mLooper->addFd(mReceiver.getFd(), 0, Looper::EVENT_INPUT, this, NULL);
        if (rc < 0) {
            return UNKNOWN_ERROR;
        }
    }

    return OK;
}
```



#### DisplayEventReceiver#scheduleVsync 

`DisplayEventReceiver`初始化完毕后，继续执行`scheduleVsync()`

```cpp
//libs/androidfw/DisplayEventDispatcher.cpp
status_t DisplayEventDispatcher::scheduleVsync() {
    if (!mWaitingForVsync) {
        ALOGV("dispatcher %p ~ Scheduling vsync.", this);
      
        status_t status = mReceiver.requestNextVsync();
        if (status) {
            ALOGW("Failed to request next vsync, status=%d", status);
            return status;
        }

        mWaitingForVsync = true;
    }
    return OK;
}
```

回调到`DisplayEventReceiver`

```cpp
//frameworks/native/libs/gui/DisplayEventReceiver.cpp
status_t DisplayEventReceiver::requestNextVsync() {
    if (mEventConnection != NULL) {
        mEventConnection->requestNextVsync();
        return NO_ERROR;
    }
    return NO_INIT;
}

```

`mEventConnection`指向了`EventThreadConnection`

```cpp
//frameworks/native/services/surfaceflinger/Scheduler/EventThread.cpp
void EventThreadConnection::requestNextVsync() {
    ATRACE_NAME("requestNextVsync");
    mEventThread->requestNextVsync(this);
}

void EventThread::requestNextVsync(const sp<EventThreadConnection>& connection) {
    if (connection->resyncCallback) {
        connection->resyncCallback();
    }

    std::lock_guard<std::mutex> lock(mMutex);

    if (connection->vsyncRequest == VSyncRequest::None) {
        connection->vsyncRequest = VSyncRequest::Single;
        mCondition.notify_all();
    }
}
```

调用`mCondition.notify_all()`唤醒了等待的`EventThread`

就去获取一次`Vsync信号`



### 回调Vsync信号

收到`Vsync信号`后，回调到`DisplayEventDispatcher.handleEvent()`

```c++
int DisplayEventDispatcher::handleEvent(int, int events, void*) {
    if (events & (Looper::EVENT_ERROR | Looper::EVENT_HANGUP)) {
        ALOGE("Display event receiver pipe was closed or an error occurred.  "
              "events=0x%x",
              events);
        return 0; // remove the callback
    }

    if (!(events & Looper::EVENT_INPUT)) {
        ALOGW("Received spurious callback for unhandled poll event.  "
              "events=0x%x",
              events);
        return 1; // keep the callback
    }

    // Drain all pending events, keep the last vsync.
    nsecs_t vsyncTimestamp;
    PhysicalDisplayId vsyncDisplayId;
    uint32_t vsyncCount;
    if (processPendingEvents(&vsyncTimestamp, &vsyncDisplayId, &vsyncCount)) {
        ALOGV("dispatcher %p ~ Vsync pulse: timestamp=%" PRId64
              ", displayId=%" ANDROID_PHYSICAL_DISPLAY_ID_FORMAT ", count=%d",
              this, ns2ms(vsyncTimestamp), vsyncDisplayId, vsyncCount);
        mWaitingForVsync = false;
        dispatchVsync(vsyncTimestamp, vsyncDisplayId, vsyncCount);
    }

    return 1; // keep the callback
}
```

回调到`handleEvent()`在向下执行到`dispatchVsync()`

```c++
//android_view_DisplayEventReceiver.cpp
void NativeDisplayEventReceiver::dispatchVsync(nsecs_t timestamp, PhysicalDisplayId displayId,
                                               uint32_t count) {
    JNIEnv* env = AndroidRuntime::getJNIEnv();

    ScopedLocalRef<jobject> receiverObj(env, jniGetReferent(env, mReceiverWeakGlobal));
    if (receiverObj.get()) {
        ALOGV("receiver %p ~ Invoking vsync handler.", this);
        env->CallVoidMethod(receiverObj.get(),
                gDisplayEventReceiverClassInfo.dispatchVsync, timestamp, displayId, count);
        ALOGV("receiver %p ~ Returned from vsync handler.", this);
    }

    mMessageQueue->raiseAndClearException(env, "dispatchVsync");
}
```

此处调用到`DisplayEventReceiver.dispatchVsync()`



### SurfaceFlinger监听Vsync信号

上面讲到的都是从`SurfaceFlinger`去监听到`Vsync`信号，但是`SurfaceFlinger`的Vsync信号又是从哪里来的？

{% post_link Android-SurfaceFlinger解析 %}



## Handler异步消息与同步屏障

在`ViewRootImpl.schdeuleTraversals()`执行`mHandler.getLooper().getQueue().postSyncBarrier()`添加`同步屏障`，在`doTraversal()`执行`removeSyncBarrier()`移除`同步屏障`。

`同步屏障`：为了**提高异步消息优先级，保证Vsync信号和绘制的同步。**

{%post_link  Handler机制即源码解析%}



## 总结

![总结](/images/View屏幕刷新-总结.png)

**丢帧**：这一帧的内容延迟显示，因为只有收到`VSync信号`才会进行Buffer交换。主要原因一般都是：**布局层级较多或主线程耗时导致CPU/GPU执行时间变长，超出`16.6ms`就会导致丢帧**。

一般屏幕的固定刷新率是`60Hz`，换算就是`60帧`，即每`16.6ms`切换一帧。

屏幕内容的绘制也是如此，没有绘制任务(没执行`scheduleTraversals()`)就不会执行绘制流程，但是**底层仍然会每隔16.6ms切换下一帧画面，只不过一直显示相同的内容**。当有绘制任务时，执行完`measure->layout->draw`流程后，依然需要等待收到`VSync信号`界面才会刷新。

`VSync信号`发生在*扫描完一个屏幕后，需要从最下面回到第一行继续循环，此时会发出该信号保证双缓冲(CPU/GPU)数据交换*。

在同一时间多次调用`requestLayout()/invalidate()`不会导致多次页面刷新，由于`mTraversalScheduled`的设置，当存在任务的时候，就会过滤重复请求，因为**最后的请求都会执行到`ViewRootImpl.scheduleTraversals()`，只要一次绘制就可以刷新所有View**。

`Choreographer`主要为了**在VSync信号到来时开始处理消息即CPU/GPU绘制**。



## 其他

![其他](/images/View屏幕刷新-其他知识.png)

1. 利用`Choreographer.postFrameCallback(frameCallback)`统计丢帧状况

   `postFrameCallback()`会在每次frame渲染的时候回调一次，然后执行`frameCallback.doFrame()`，在`doFrame()`可以获取每一帧的渲染时间然后判断是否发生丢帧

   ```java
   Choreographer.getInstance().postFrameCallback(new TestFrameCallback())
   
   public class TestFrameCallback implements Choreographer.FrameCallback {
     @Override
     public void doFrame(long frameTimeNanos){
       ...
       //计算帧率 or others
         
       //注册下一帧回调  
       Choreographer.getInstance().postFrameCallback(this);
     }
   }
   ```

2. `Choreographer.CALLBACK_INPUT`使用场景？

   {%post_link Android事件分发%}

## 参考链接

{%post_link View的工作原理%}

[Choreographer原理](http://gityuan.com/2017/02/25/choreographer/)

[Android Code Search](cs.android.com)

[Android-Choreographer](https://androidperformance.com/2019/10/22/Android-Choreographer/)

[Android与SurfaceFlinger建立连接过程](https://www.jianshu.com/p/304f56f5d486)