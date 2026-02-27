---
title: Handler机制源码解析(二)
date: 2018-10-07 11:08:24
tags: 源码解析
top : 9
typora-root-url: ../
---

# 主要包括Handler其他使用知识点

![Handler拓展知识](/images/Handler拓展知识点.png)

## 1. 子线程创建Handler对象

![Handler-子线程创建Handler对象](/images/Handler-子线程创建Handler对象.png)

> 不可以直接在子线程创建Handler对象，因为Handler对象必须要绑定一个Looper，才可以使用。
>
> 若在子线程需要使用Handler，则需要先创建一个Looper对象即执行`Looper.prepare()`然后再创建Handler对象时调用`Looper.myLooper()`获取Looper对象传入方法，最后调用`Looper.loop()`开始运行。

```kotlin
class MyActivity : Activity{
    lateinit var mThread: MyThread
    lateinit var mHandler: MyHandler
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.act_main)
        //初始化子线程
        mThread = MyThread()
        mThread.start()
        //需要发出的消息
        val message = Message.obtain()
        message.obj = "test"
        //初始化Handler
        mHandler = MyHandler(this, mThread.childLooper)
        //发送消息
        mHandler.sendMessage(message)
    }
    
    //子线程
    class MyThread : Thread() {
        var childLooper: Looper? = null
        override fun run() {
            Looper.prepare()
            childLooper = Looper.myLooper()
            Looper.loop()
        }
    }
    
    //安全的Handler写法
     class MyHandler(activity: MyActivity, looper: Looper?) : Handler(looper) {
        var mWeakRe: WeakReference<MyActivity> = WeakReference(activity)

        override fun handleMessage(msg: Message?) {
            super.handleMessage(msg)
            val activity: MyActivity? = mWeakRe.get()
            if (activity!=null){
                //添加handleMessage需要处理的逻辑
            }
        }
    }
}
```

以上代码执行完毕后就可以在子线程调用Handler对象。

**但是，在多次执行过程中，会有<font color = 'red'>java.lang.NullPointerException: Attempt to read from field 'android.os.MessageQueue android.os.Looper.mQueue' on a null object reference</font>空指针导致应用崩溃。**调试过程中发现是由于Looper对象为空导致的异常。由于**在子线程`run()`初始化了Looper对象，Handler对象的初始化依然继续执行，Looper对象此时尚未初始化好，导致空指针异常。**

由于这种情况的出现是随机的，不是百分百重现，为了保证应用的运行就需要引入`HandlerThread`这个类，可以帮我们解决这个问题。

```kotlin
//HandlerThread示例代码
class MyActivity : Activity{
    lateinit var mHandler: MyHandler
    var mHandlerThread: HandlerThread?=null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.act_main)
        //初始化HandlerThread并指定线程名字为test
        mHandlerThread = HandlerThread("test",Process.THREAD_PRIORITY_BACKGROUND)
        mHandlerThread?.start()
        //需要发出的消息
        val message = Message.obtain()
        message.obj = "test"
        //初始化Handler
        mHandler = MyHandler(this, mHandlerThread?.looper)
        //发送消息
        mHandler.sendMessage(message)
    }
    
    //安全的Handler写法
    class MyHandler(activity: MyActivity, looper: Looper?) : Handler(looper) {
        var mWeakRe: WeakReference<MyActivity> = WeakReference(activity)

        override fun handleMessage(msg: Message?) {
            super.handleMessage(msg)
            val activity: MyActivity? = mWeakRe.get()
            if (activity!=null){
                //添加handleMessage需要处理的逻辑
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        //结束时停止thread
        mHandlerThread?.quit()
    }
}
```

以上代码执行完毕后，即可在`HandlerThread`中使用`Handler`对象。

我们需要从源码去分析为什么使用`HandlerThread`可以避免上述异常，是怎样一个机制实现的。

```java
// 源码位置:../core/java/android/os/HandlerThread.java
public class HandlerThread extends Thread {
    ...
     //设置线程优先级 优先级主要分为UI线程和后台线程(Background)
    int mPriority;
    public HandlerThread(String name) {
        super(name);
        //默认标准App线程优先级
        mPriority = Process.THREAD_PRIORITY_DEFAULT;
    }
    
    public HandlerThread(String name, int priority) {
        super(name);
        mPriority = priority;
    }
    
    //可以重写这个方法，在内部新建Handler对象
    protected void onLooperPrepared() {
    }
    
    @Override
    public void run() {
        //获取到线程ID
        mTid = Process.myTid();
        //创建对应的Looper，MessageQueue对象
        Looper.prepare();
        synchronized (this) {
            //对mLooper进行赋值
            mLooper = Looper.myLooper();
            //唤醒等待Looper赋值而阻塞的所有线程
            notifyAll();
        }
        Process.setThreadPriority(mPriority);
        onLooperPrepared();
        Looper.loop();
        mTid = -1;
    }
    
    public Looper getLooper() {
        //判断当前线程是否存活 关闭则返回空
        if (!isAlive()) {
            return null;
        }
        
        // If the thread has been started, wait until the looper has been created.
        synchronized (this) {
            //mLooper==null表明当前Looper对象尚未初始化
            while (isAlive() && mLooper == null) {
                try {
                    //调用线程等待 直至初始化完成 阻塞其他线程
                    wait();
                } catch (InterruptedException e) {
                }
            }
        }
        //返回Looper对象
        return mLooper;
    }
    
    //内嵌一个可以直接引用的Handler对象，外部可以直接使用
    @NonNull
    public Handler getThreadHandler() {
        if (mHandler == null) {
            mHandler = new Handler(getLooper());
        }
        return mHandler;
    }
    
    //HandlerThread退出 同步于Looper.quit()
    public boolean quit() {
        Looper looper = getLooper();
        if (looper != null) {
            looper.quit();
            return true;
        }
        return false;
    }
    
    //HandlerThread退出 同步于Looper.quitSafely()
    public boolean quitSafely() {
        Looper looper = getLooper();
        if (looper != null) {
            looper.quitSafely();
            return true;
        }
        return false;
    }
}
```

总结：

- `HandlerThread`内嵌了Handler,Looper,MessageQueue对象
- `HandlerThread`内部使用`wait(),notifyAll()`等线程同步方式保证`mLooper`对象不会为空，`wait()`当Looper对象尚未初始化完成时阻塞其他线程，`notifyAll()`当mLooper对象不为空时，通知其他线程使用mLooper。

补充：`HandlerThread`与手写`Looper`的边界

- 手写`Looper.prepare()` + `Looper.loop()`的问题不在于“不能用”，而在于容易出现初始化时序和退出时机管理不当。
- `HandlerThread.getLooper()`内部用`wait()/notifyAll()`等待`mLooper`完成初始化，天然规避“先取Looper后初始化”的竞态。
- 若使用手写Looper模型，必须额外设计“初始化完成通知 + 退出协议”，否则容易出现空指针或线程泄漏。

补充：`quit`与`quitSafely`选择

- `quit()`：立即退出，队列中的未处理消息会被移除，适合“任务已无意义”的快速收尾场景。
- `quitSafely()`：只移除未来消息，允许已到期消息执行完，适合“希望平滑结束后台任务”的场景。
- 生命周期结束时，除停止`HandlerThread`外，还建议同步清理`removeCallbacksAndMessages(null)`，避免页面销毁后仍有回调。

## 2. IdleHandler

![Handler-IdleHandler](/images/Handler-IdleHandler.png)

> 当Looper里面的Message暂时处理完毕即**全部消息处理完毕或者阻塞等待新消息**时会调用`IdleHandler`这个类去处理一些空闲时间的消息。
>
> 继承`IdleHandler`这个接口，需要设置`queueIdle()`的返回值。若返回`false`则调用一次后会移除，为`true`则继续持有，空闲时依然会调用。
>
> 概括就是：**优先级别较低的`Message`，只有当`Looper`中没有消息要处理时，才会去处理`IdleHandler`。**

```kotlin
    //使用示例代码
    val message = Message.obtain()
    message.obj = "1234"
    handler.sendMessage(message)

    val delayMessage=Message.obtain()
    delayMessage.obj="12344"
    handler.sendMessageDelayed(delayMessage,3000)

    //子线程添加IdleHandler 限制API23以上使用
    mHandlerThread?.looper?.queue?.addIdleHandler(OnceIdleHandler())
    mHandlerThread?.looper?.queue?.addIdleHandler(ForeverIdleHandler())
    //主线程添加IdleHandler
    Looper.myQueue().addIdleHandler(OnceIdleHandler())
    Looper.myQueue().addIdleHandler(ForeverIdleHandler())

    //只使用一次的IdleHandler
    class OnceIdleHandler : MessageQueue.IdleHandler {
        override fun queueIdle(): Boolean {
            LogUtils.e("idle once")
            return false
        }
    }

    //一直持续存在的IdleHandler
    class ForeverIdleHandler : MessageQueue.IdleHandler {
        override fun queueIdle(): Boolean {
            LogUtils.e("idle forever")
            return true
        }
    }

    //需要移除IdleHandler 调用
     Looper.myQueue().removeIdleHandler(OnceIdleHandler())
     Looper.myQueue().removeIdleHandler(ForeverIdleHandler())
```

接入上述代码即可测试`IdleHandler`的使用，接下来分析它的源码实现以及使用场景。

补充：`IdleHandler`执行语义

- 触发条件并不只是在“队列完全为空”，当队头消息`when`尚未到达时也可能触发。
- `queueIdle()`运行在Looper绑定线程（主线程场景最常见），因此必须保证逻辑短小且可快速返回。
- 返回`true`会持续驻留，若逻辑较重应改为一次性任务（返回`false`）或转移到后台线程。

```java
// 源码位置:../core/java/android/os/MessageQueue.java
   /**
     * IdleHandler定义
     * Callback interface for discovering when a thread is going to block
     * waiting for more messages.
     */
    public static interface IdleHandler {
        /**
         * Called when the message queue has run out of messages and will now
         * wait for more.  Return true to keep your idle handler active, false
         * to have it removed.  This may be called if there are still messages
         * pending in the queue, but they are all scheduled to be dispatched
         * after the current time.
         */
        boolean queueIdle();
    }
   //mIdleHandlers 是ArrayList型 故可以重复添加
   private final ArrayList<IdleHandler> mIdleHandlers = new ArrayList<IdleHandler>();
   //往MessageQueue中添加一个IdleHandler对象
   public void addIdleHandler(@NonNull IdleHandler handler) {
        if (handler == null) {
            throw new NullPointerException("Can't add a null IdleHandler");
        }
        synchronized (this) {
            //添加IdleHandler是线程安全的 
            mIdleHandlers.add(handler);
        }
    }
   
    //移除一个IdleHandler
    public void removeIdleHandler(@NonNull IdleHandler handler) {
        synchronized (this) {
            mIdleHandlers.remove(handler);
        }
    }

    //调用上述方法往mIdleHandlers添加或移除IdleHandler对象后 需要在next()方法中 去使用mIdleHandlers中的对象
   Message next() {
       //无限循环
       for(;;){
           ...
                // If first time idle, then get the number of idlers to run.
                // Idle handles only run if the queue is empty or if the first message
                // in the queue (possibly a barrier) is due to be handled in the future.
                if (pendingIdleHandlerCount < 0
                        && (mMessages == null || now < mMessages.when)) {
                    pendingIdleHandlerCount = mIdleHandlers.size();
                }
                if (pendingIdleHandlerCount <= 0) {
                    // 判断当前没有空闲线程可执行 则继续阻塞
                    mBlocked = true;
                    continue;
                }

                if (mPendingIdleHandlers == null) {
                    mPendingIdleHandlers = new IdleHandler[Math.max(pendingIdleHandlerCount, 4)];
                }
                mPendingIdleHandlers = mIdleHandlers.toArray(mPendingIdleHandlers);
       }
       
       // Run the idle handlers.
            // We only ever reach this code block during the first iteration.
            for (int i = 0; i < pendingIdleHandlerCount; i++) {
                final IdleHandler idler = mPendingIdleHandlers[i];
                mPendingIdleHandlers[i] = null; // release the reference to the handler

                boolean keep = false;
                try {
                    //获取继承接口定义的queueIdle()返回值 判定后续是否需要继续执行
                    keep = idler.queueIdle();
                } catch (Throwable t) {
                    Log.wtf(TAG, "IdleHandler threw exception", t);
                }

                if (!keep) {
                    //不需要继续执行 则自动移除对象
                    synchronized (this) {
                        mIdleHandlers.remove(idler);
                    }
                }
            }
   }
```

## 3. Handler常见问题

### 1. 消息机制中的主要引用对象及其关系

> `Looper ，MessageQueue，Message，ThreadLocal，Handler `

1. Looper对象有一个MessageQueue，MessageQueue为一个消息队列来存储Message
2. Message中带有一个Handler对象，从Looper中取出消息后，可以直接调用到Handler的相关方法
3. Handler发送消息时会把自身封装进Message：`Message.obtain(Handler h, int what, int arg1, int arg2, Object obj)`
4. Handler通过获取Looper对象中的MessageQueue插入消息来发送Message
5. Looper创建对象时会把自己保存至ThreadLocal中，并提供一个`public static Looper myLooper()`方法来返回一个Looper对象

### 2. Android主线程不会因为`Looper.loop()`死循环卡死

当线程中的可执行代码执行完成后，线程生命周期便该终止，线程就要退出。通过**死循环**的方式可以保证线程一直存活。



简单来说就是**循环里有阻塞`阻塞的原理是利用Linux的管道机制(PIPE/EPOLL)机制实现`，所以死循环不会一直执行，由于大部分时间都是没有消息的，所以主线程大部分处于休眠状态，也不会过度消耗CPU资源导致卡死。**

先说明进程和线程的区别：

> **进程**：每个App运行时首先会创建一个进程，该进程是由zygote fork出来的，用于承载运行App上的Activity/Service等组件。进程对于上层应用来说是完全透明的，目的是为了`让App都运行在Android Runtime`。大多数情况下一个App运行在一个进程中，除非配置了`android:process`属性，或者通过native fork进程。
>
> **线程**：线程比较常见，每次`new Thread().start()`都会创建一个新线程。并且与当前App所在进程之间资源共享。`在CPU看来进程或线程无非是一段可执行的代码，CPU采用CFS调度算法，保证每个task尽可能公平享有CPU时间片`。
>
> 拓展知识：CFS调度算法是一种完全公平调度算法，基本设计思路是根据各个进程的权重来分配运行时间**。

当进入死循环时又该如何处理其他事务呢？**需要创建新的线程去处理**。

主线程进入Looper的死循环后，还需要处理Activity的各个生命周期回调(`在同一个线程下，代码是按顺序执行的，如果死循环阻塞了，后续该如何执行`)。

```java
//源码地址 android/app/ActivityThread.java 
public static void main(String[] args){
    ...
    //Looper初始化
    Looper.prepareMainLooper();
    //new 一个ActivityThread并调用了attach方法
    ActivityThread thread = new ActivityThread();
    thread.attach(false);

    if (sMainThreadHandler == null) {
        sMainThreadHandler = thread.getHandler();
    }

    if (false) {
       Looper.myLooper().setMessageLogging(new
             LogPrinter(Log.DEBUG, "ActivityThread"));
       }

       // End of event ActivityThreadMain.
       Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
       Looper.loop();

       throw new RuntimeException("Main thread loop unexpectedly exited");
}
```

源码中在初始化ActivityThread时也会初始化一个`H类型的成员，它继承了Handler`。

源码中调用`thread.attach(false)`时，**会创建对应的Binder通信链路（例如ApplicationThread作为Binder服务端，用于接收系统AMS发出的事件），再由Handler线程发送Message至主线程。**

所以在主线程开启Looper死循环之前，就已经启动了一个Binder线程并且准备了`H 这一个Handler类`，就可以用于处理一些死循环之外的事务。`仅需通过Binder线程向H发送消息即可`。

![App运行过程](/images/activity_binder.png)

**system_server进程即为系统进程**，里面运行了大量的系统服务，比如上图提供了`ApplicationThreadProxy以及ActivityManagerService`，这两者都基于IBinder接口，都是Binder线程。

**App进程即为我们常说的应用程序**，主线程主要负责Activity等组件的生命周期以及UI绘制。每个App进程中至少会包括两个Binder线程：`ApplicationThread和ActivityManagerProxy`。

**Binder用于不同进程间的通信，由一个进程的Binder客户端向另一个进程的服务端发送事务。**

**Handler则用于同一进程间不同线程的通信。**

### 3.主线程的消息模型

![Handler-主线程消息模型](/images/Handler-主线程消息模型.png)

上图中绘制出主线程(ActivityThread)是如何循环的,简单的文字表达就是

> `ActivityManagerService(AMS)` ==直接调用==>`ApplicationThreadProxy(ATP)`==Binder==>`ApplicationThread`==Handler方式==>`ActivityThread`
>
> 主线程(ActivityThread)通过`ApplicationThread`和`ActivityManagerService`进行进程间通信，AMS以进程间通信的方式完成`ActivityThread`的请求后回调`ApplicationThread`中的Binder方法。然后由`ApplicationThread`向`ActivityThread`中的`H`发送消息，然后收到消息后 把处理逻辑发送至`ActivityThread`中去执行。



### 4.Message的触发统计

> Message是在MessageQueue中进行存放，事件的分发需要通过Looper.loop()从`MessageQueue`中获取Message，`BlockCanary`就是通过计算事件分发的时间间隔来判断当前是否出现卡顿。

```java
//Looper.java
    public void setMessageLogging(@Nullable Printer printer) {
        mLogging = printer;
    }

    public static void loop() {
      for (;;) {
        //读取设置的 logging
            final Printer logging = me.mLogging;
            if (logging != null) {
                logging.println(">>>>> Dispatching to " + msg.target + " " +
                        msg.callback + ": " + msg.what);
            }
        
        ...
          //事件分发
            if (logging != null) {
                logging.println("<<<<< Finished to " + msg.target + " " + msg.callback);
            }
      }
    }
```

可以通过给Handler中的Looper对象设置`setMessageLogging()`，对事件的分发进行监听。

```java
Looper.getMainLooper().setMessageLogging(new Printer(){
  @Override
  public void println(String x){
    //x 包含了以下内容  Message.target Message.callback  Message.what
  }
})
```



### 5.View.post()和Handler.post()有什么区别？

![Handler-View.post](/images/Handler-View.post.png)

```java
//View.java
    public boolean post(Runnable action) {
        final AttachInfo attachInfo = mAttachInfo;
        if (attachInfo != null) {
            return attachInfo.mHandler.post(action);
        }

        // Postpone the runnable until we know on which thread it needs to run.
        // Assume that the runnable will be successfully placed after attach.
        getRunQueue().post(action);
        return true;
    }
```

需要判断`attachInfo`是否为null，不为null直接执行`handler.post()`去执行任务；否则，插入到`getRunQueue()`中。

现在需要分为两部分进行分析：

#### AttachInfo

```java
//View.java
    void dispatchAttachedToWindow(AttachInfo info, int visibility) {
      //在此处进行赋值
      mAttachInfo = info;
      ...
    }
```

这时需要知道何时调用了`dispatchAttachedToWindow()`，需要向上看

```java
//ViewGroup.java
    void dispatchAttachedToWindow(AttachInfo info, int visibility) {
       ...
        final int count = mChildrenCount;
        final View[] children = mChildren;
        for (int i = 0; i < count; i++) {
            final View child = children[i];
            child.dispatchAttachedToWindow(info,
                    combineVisibility(visibility, child.getVisibility()));
        }
        final int transientCount = mTransientIndices == null ? 0 : mTransientIndices.size();
        for (int i = 0; i < transientCount; ++i) {
            View view = mTransientViews.get(i);
            view.dispatchAttachedToWindow(info,
                    combineVisibility(visibility, view.getVisibility()));
        }
    }
```

再往上就是`DecorView`，`DecorView`继承自`ViewGroup`，所以最终就是到了`ViewRootImpl`

```java
//ViewRootImpl.java
private void performTraversals() {
   //mView 此处指的是 DecorView
   final View host = mView;
 ...
        if (mFirst) {
            mFullRedrawNeeded = true;
            mLayoutRequested = true;
         ...
            host.dispatchAttachedToWindow(mAttachInfo, 0);           
        }
  ...
    //绘制流程
    performMeasure()
    
    performLayout()
    
    performDtraw()
}
```

是从`ViewRootImpl.performTraversals()`向下执行到`DecorView.dispatchAttachedToWindow()`，最后执行到`View.dispatchAttachedToWindow()`。

```java
public ViewRootImpl(Context context, Display display) {
...
        mFirst = true; // true for the first time the view is added
        mAdded = false;
        mAttachInfo = new View.AttachInfo(mWindowSession, mWindow, display, this, mHandler, this,
                context);
  ...
  
}

final ViewRootHandler mHandler = new ViewRootHandler();
```

是在`ViewRootImpl`初始化的时候构建了`AttachInfo`对象，其中`attachInfo.handler`指的就是`ViewRootHandler`

所以最后通过`View.post()`执行的任务都会切换到`ViewRootHandler`上去执行。



#### HandlerActionQueue

当`mAttachInfo`未赋值时(`尚未执行 dispatchAttachedToWindow()`)，缓存当前无法执行的Runnable

```java
//HandlerActionQueue.java
public class HandlerActionQueue {
  private HandlerAction[] mActions;
  
  //缓存任务
    public void post(Runnable action) {
        postDelayed(action, 0);
    }

    public void postDelayed(Runnable action, long delayMillis) {
        final HandlerAction handlerAction = new HandlerAction(action, delayMillis);

        synchronized (this) {
            if (mActions == null) {
                mActions = new HandlerAction[4];
            }
            mActions = GrowingArrayUtils.append(mActions, mCount, handlerAction);
            mCount++;
        }
    }
  
  //执行缓存的任务
      public void executeActions(Handler handler) {
        synchronized (this) {
            final HandlerAction[] actions = mActions;
            for (int i = 0, count = mCount; i < count; i++) {
                final HandlerAction handlerAction = actions[i];
                handler.postDelayed(handlerAction.action, handlerAction.delay);
            }

            mActions = null;
            mCount = 0;
        }
    }
  
  //缓存runnable和执行时间
    private static class HandlerAction {
        final Runnable action;
        final long delay;

        public HandlerAction(Runnable action, long delay) {
            this.action = action;
            this.delay = delay;
        }

        public boolean matches(Runnable otherAction) {
            return otherAction == null && action == null
                    || action != null && action.equals(otherAction);
        }
    }  
}
```

当`mAttachInfo`尚未赋值时，就会缓存`View.post()`要执行的任务

```java
//View.java
    void dispatchAttachedToWindow(AttachInfo info, int visibility) {
      mAttachInfo = info;
      ...
        if (mRunQueue != null) {
            mRunQueue.executeActions(info.mHandler);
            mRunQueue = null;
        }     
      ...
    }
```

在`dispatchAttachedToWindow()`执行了关键的两步：

1. 赋值`mAttachInfo`
2. 执行`View.post()`未执行的任务



#### 总结

> `View.post()`内部自动分为两种情况：
>
> - 尚未执行`dispatchAttachedToWindow()`：尚未赋值`mAttachInfo`，将需要执行的任务缓存到`HandlerActionQueue`，等待`dispatchAttachedToWindow()`之后通过`ViewRootHandler`执行。
> - 已执行`dispatchAttachedToWindow()`：已赋值`mAttachInfo`，直接调用`ViewRootHandler`执行对应任务即可。
>
> `ViewRootHandler`绑定的Looper为`MainLooper`，所以通过`View.post()`的操作都会在主线程执行。
>
> `dispatchAttachedToWindow()`是在`ViewRootImpl.performTraversals()`中执行的。

#### 为什么可以获取宽高

前面有讲过在`onCreate()`调用`View.post()`可以获取View的宽和高，下面简单的分析原因。

```java
//ViewRootImpl.java
    private void performTraversals() {
      ...
        host.dispatchAttachedToWindow(mAttachInfo, 0);
      ...
        // 绘制流程
    }

    void doTraversal() {
        if (mTraversalScheduled) {
            mTraversalScheduled = false;
          ...
            performTraversals();

        }
    }

    final class TraversalRunnable implements Runnable {
        @Override
        public void run() {
            doTraversal();
        }
    }

    final TraversalRunnable mTraversalRunnable = new TraversalRunnable();

    void scheduleTraversals() {
        if (!mTraversalScheduled) {
            mTraversalScheduled = true;
            mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
          //交给Choreographer在收到Vsync信号后执行mTraversalRunnable，也就是performTraversals()
            mChoreographer.postCallback(
                    Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
           ...
        }
    }
```

这边转到`Choreographer`

```java
//Choreographer.java
    public static Choreographer getInstance() {
        return sThreadInstance.get();
    }

    private static final ThreadLocal<Choreographer> sThreadInstance =
            new ThreadLocal<Choreographer>() {
        @Override
        protected Choreographer initialValue() {
            Looper looper = Looper.myLooper();//此时looper对应的是MainLooper
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

    private Choreographer(Looper looper, int vsyncSource) {
        mLooper = looper;
        mHandler = new FrameHandler(looper);//由MainLooper构建的Handler
      ...
    }

    private void postCallbackDelayedInternal(int callbackType,
            Object action, Object token, long delayMillis) {
        if (DEBUG_FRAMES) {
            Log.d(TAG, "PostCallback: type=" + callbackType
                    + ", action=" + action + ", token=" + token
                    + ", delayMillis=" + delayMillis);
        }

        synchronized (mLock) {
            final long now = SystemClock.uptimeMillis();
            final long dueTime = now + delayMillis;
            mCallbackQueues[callbackType].addCallbackLocked(dueTime, action, token);

            if (dueTime <= now) {
                scheduleFrameLocked(now);
            } else {
                Message msg = mHandler.obtainMessage(MSG_DO_SCHEDULE_CALLBACK, action);
                msg.arg1 = callbackType;
                msg.setAsynchronous(true);//设置异步消息 把TraversalRunnable置于消息里
                mHandler.sendMessageAtTime(msg, dueTime);
            }
        }
    }
```

根据上述源码分析可得结论：`TraversalRunnable`也会运行到`FrameHandler`上。

`Handler`的`MessageQueue`是按顺序执行的，因此需要等`performTraversals()`执行完毕后，才可以执行后续任务（例如`HandlerActionQueue`中缓存的任务）。

补充：`View.post()`与`Handler.post()`核心差异

- `Handler.post()`直接向目标`Looper`入队，调用时就需要明确线程归属。
- `View.post()`在`View`未attach时会先缓存到`HandlerActionQueue`，attach后再切到`ViewRootHandler`执行。
- 因为`dispatchAttachedToWindow()`发生在`performTraversals()`链路中，所以`onCreate()`里调用`View.post()`常常能拿到宽高。

补充：主线程消息分发观察建议

- `Looper.setMessageLogging(Printer)`适合定位“哪类消息执行过久”，可用于卡顿初筛。
- 线上监控不建议长期打印完整日志，建议抽样、限频并做阈值上报，避免日志本身放大主线程负担。
- 结合`what/callback/target`维度统计，通常比只看单次耗时更容易定位高频慢消息来源。

补充：版本差异与写法建议

- Android R(API 30)起，无参`Handler()`被标记为`@Deprecated`，建议显式传入`Looper`。
- 需要异步消息通道时，可使用`Handler.createAsync(...)`或`Message.setAsynchronous(true)`。
- 在新项目里，`Handler`仍适合与系统消息循环深度交互的场景；纯业务异步任务可结合协程/线程池提升可维护性。
