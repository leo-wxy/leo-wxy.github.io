---
title: Handler机制源码解析
date: 2018-05-14 23:13:32
tags: 
  - 源码解析
  - Android
top : 9
typora-root-url: ../
---

> 主要的内容包括Handler的机制以及四个组成部分和源码的分析
>
> 下面的代码分析都是基于Android8.0 - Oreo的源代码

![Handler机制](/images/Handler机制xmind.png)

<!-- more -->

## 1.  消息机制简介

在应用启动时，会执行`main()`方法，`main()`会创建一个Looper对象，然后开启一个死循环，目的是**不断从消息队列`MessageQueue`里面取出`Message`对象并处理。**

在Android中使用消息机制，会优先想到的是Handler。Handler可以轻松的将一个任务切换到Handler所在的线程去执行。在多线程的应用场景中，**可以将工作线程中需要更新UI的操作信息传递到主线程去执行**，从而实现工作线程更新UI的操作，最终实现异步消息的处理。



![Handler执行流程](/images/study_plan/handler_process.png)

## 2. Handler机制模型

![Handler机制模型](/images/Handler-机制模型.png)

消息机制主要包含**Handler、Message、MessageQueue，Looper**这四个类。

### Handler：消息辅助类

主要功能将`Message`对象发送到`MessageQueue`中，同时将自己的引用赋值给`Message#target`(Handler.sendMessage())。也可以实现`handleMessage()`方法处理回调。

### Message：消息实体

需要传递的消息也可以传递数据。

`Message`分为三种：

- 同步消息(`默认消息`)
- 异步消息(`setAsynchronous(true)`)
- 同步屏障消息

### MessageQueue：消息队列

**内部实现并不是队列，而是利用单链表去实现因为在插入和删除数据有优势。**用于存储Handler发给来的消息(`Message`)以及取出。`内部使用单链表实现`

### Looper：消息循环

与线程绑定，不止局限于主线程，绑定的线程来处理`Message`。不断循环执行`Looper.loop()`，从`MessageQueue`中读取`Message`，按分发机制将消息分发出去给目标处理(将`Message`发到`Handler.dispatchMessage`方法去处理)。

补充：

- `Looper`通过`ThreadLocal`与线程绑定，`Looper.myLooper()`拿到的是当前线程专属实例。
- 一个线程最多只有一个`Looper`和一个`MessageQueue`，但可以创建多个`Handler`共享同一个队列。
- 主线程`Looper`由`ActivityThread.main()`自动创建；子线程若要收发消息，通常使用`HandlerThread`而不是手写`prepare()/loop()`。

## 3. Handler运行流程

![handler运行流程](/images/Handler基本原理) ![运行流程](/images/Handler-运行流程.png)

工作流程：**异步通信准备 => 消息入队 => 消息循环 => 消息处理**

1. **异步通信准备**

   > 假定在主线程创建Handler，则会直接在主线程中创建`Looper`,`MessageQueue`和`Handler`对象。**Looper和MessageQueue对象均属于其`创建线程`（由主线程创建则属于主线程）。**创建`Looper`时会自动创建`MessageQueue`对象，创建好`MessageQueue`对象后，`Looper`自动进入循环。`Handler`自动绑定`Looper`以及`MessageQueue`。
   >
   > `Looper`对象的创建方法一般通过`Looper.prepareMainLooper()`和`Looper.prepare()`方法。

2. **消息入队**

   > 工作线程通过`Handler`发送`Message`到`MessageQueue`中。消息内容一般是UI操作，通过`Handler.sendMessage(Message message)`或`Handler.post(Runnable r)`发送。加入`MessageQueue`一般通过`MessageQueue.enqueueMessage(Message msg,long when)`操作。

3. **消息循环**

   > 分为**消息出队**和**消息分发**两个步骤
   >
   > - 消息出队：`Looper`从`MessageQueue`中循环取出`Message`——`MessageQueue.next()`
   > - 消息分发：`Looper`将取出的`Message`分发给创建消息的`Handler`——`Message.target.dispatchMessage()`
   >
   > **消息循环过程中，`MessageQueue`为空，则线程阻塞**

4. **消息处理**

   > `Handler`接受发过来的`Message`并处理。

## 4. Handler使用过程的注意点

1. 在工作线程中创建自己的消息队列时必须要调用`Looper.prepare()`,并且**在一个线程中只可以调用一次**，然后需要调用`Looper.loop()`,开启消息循环。

   > 在开发过程中基本不会调用上述方法，因为默认会调用主线程的Looper，然后一个线程中只能有一个Looper对象和一个MessageQueue。

2. 子线程消息处理建议优先使用`HandlerThread`模型

   ```java
   HandlerThread worker = new HandlerThread("io-worker");
   worker.start();

   Handler ioHandler = new Handler(worker.getLooper());
   ioHandler.post(() -> {
       // do background work
   });

   // 结束时建议优先使用quitSafely，允许已到期消息先执行完
   worker.quitSafely();
   ```

   > 要点：`getLooper()`必须在`start()`后调用；`quit()`会清空队列直接退出，`quitSafely()`会让已到期消息先执行再退出。


## 5. Handler源码解析

![源码分析](/images/Handler-源码分析.png)

### 1.**创建循环器对象（`Looper`）和创建消息队列对象(`MessageQueue`)**

![创建Looper和MessageQueue](/images/Handler-源码1.png)

> 创建Looper对象主要有两个方法：`Looper.prepareMainLooper()`和`Looper.prepare()`
>
> 创建MessageQueue对象方法：**创建Looper对象时会自动创建MessageQueue**
>
> **一个线程最多对应一个Looper、一个MessageQueue，但可以对应多个Handler**

```java
// 源码位置:../core/java/android/os/Looper.java

final MessageQueue mQueue;
final Thread mThread;
//Looper对象创建时会自动创建一个MessageQueue对象。
private Looper(boolean quitAllowed) {
     mQueue = new MessageQueue(quitAllowed);
     mThread = Thread.currentThread();
    }

//为当前线程(子线程)创建一个Looper对象 需要在子线程中主动调用该方法
public static void prepare() {
        prepare(true);
    }

private static void prepare(boolean quitAllowed) {
    //判断sThreadLocal是否为null，不为空则直接抛出异常 可以保证一个线程只可以调用一次prepare方法
    if (sThreadLocal.get() != null) {
          throw new RuntimeException("Only one Looper may be created per thread");
       }
    sThreadLocal.set(new Looper(quitAllowed));
    }

//为主线程创建一个Looper对象 该方法会在主线程创建时自动调用
public static void prepareMainLooper() {
        prepare(false);
        synchronized (Looper.class) {
            if (sMainLooper != null) {
                throw new IllegalStateException("The main Looper has already been prepared.");
            }
            sMainLooper = myLooper();
        }
    }
```

总结：

1. 创建`Looper`对象时会自动创建`MessageQueue`对象

2. 主线程的Looper对象是自动生成的，而子线程需要调用`Looper.prepare()`创建`Looper`对象

   > 创建主线程是调用了`ActivityThread`的`main()`方法。
   >
   > 然后按照流程调用了`Looper.prepareMainLooper()`和`Looper.loop()`。所以主线程不需要调用代码生成Looper对象。
    ```java
    //源码位置: ../core/java/android/app/ActivityThread.java
     public static void main(String[] args) {
         ...
          Looper.prepareMainLooper();
          Looper.loop();
         ...
     }
    ```

3. Handler的主要作用是(`在主线程更新UI`)，所以**Handler主要是在主线程创建的**。

4. Looper与Thread是通过`ThreadLocal`关联的。由于`ThreadLocal`是与线程直接关联的，参考`prepare()`。

5. 子线程创建Handler对象:无法在子线程直接调用Handler无参构造方法**Handler创建时需要绑定Looper对象** 。需要使用`HandlerThread`。

### 2.**开启Looper即消息循环**

![开启消息循环](/images/Handler-源码2.png)

> 创建了`Looper和MessageQueue`对象后，自动进入消息循环，使用`Looper.loop()`方法开始消息循环。

```java
//源码位置：../core/java/android/os/Looper.java
public static void loop(){
    //现获取Looper实例，保证调用loop时已有Looper，否则抛出异常
    final Looper me = myLooper();
    if (me == null) {
            throw new RuntimeException("No Looper; Looper.prepare() wasn't called on this thread.");
       }
    //获取对应Looper实例创建的MessageQueue对象
    final MessageQueue queue = me.mQueue;
    ...
     //开启消息循环-无限循环   
     for (;;) {
            //从MessageQueue取出Message对象
            Message msg = queue.next(); // might block
            //取出消息为null，则退出循环
            if (msg == null) {
                // No message indicates that the message queue is quitting.
                return;
            }
         //把Message分发给相应的target
         try {
                msg.target.dispatchMessage(msg);
                end = (slowDispatchThresholdMs == 0) ? 0 : SystemClock.uptimeMillis();
            } finally {
                if (traceTag != 0) {
                    Trace.traceEnd(traceTag);
                }
            }
         //释放消息占据的资源
          msg.recycleUnchecked();
     }
}

```

`loop()`方法是一个死循环，唯一跳出循环的方法是从`MessageQueue`获取的消息对象为空。

### **3.创建Handler对象**

![创建Handler](/images/Handler-源码3.png)

>创建Handler对象即可以进行消息的发送与处理

```java
//源码位置：.../core/java/android/os/Handler.java 
//Handler默认构造方法
public Handler() {
        this(null, false);
 }

public Handler(Callback callback, boolean async) {
        if (FIND_POTENTIAL_LEAKS) {
            final Class<? extends Handler> klass = getClass();
            if ((klass.isAnonymousClass() || klass.isMemberClass() || klass.isLocalClass()) &&
                    (klass.getModifiers() & Modifier.STATIC) == 0) {
                Log.w(TAG, "The following Handler class should be static or leaks might occur: " +
                    klass.getCanonicalName());
            }
        }
        //从当前线程的ThreadLocal获取Looper对象
        mLooper = Looper.myLooper();
        if (mLooper == null) {
            throw new RuntimeException(
                "Can't create handler inside thread that has not called Looper.prepare()");
        }
        //获取当前Looper的消息队列
        mQueue = mLooper.mQueue;
        mCallback = callback;
        //设置消息是否为异步处理方式
        mAsynchronous = async;
    }

public Handler(Looper looper, Callback callback, boolean async) {
        mLooper = looper;
        mQueue = looper.mQueue;
        mCallback = callback;
        mAsynchronous = async;
    }

```

`Handler的无参构造方法会默认关联当前线程的Looper对象和MessageQueue对象，设置callback回调方法为null，且消息处理方式为同步处理。`

`async`为true，所有发出的消息都是`异步消息`。

### **4.创建消息对象**

![创建Message](/images/Handler-源码4.png)

>Handler发送Message并且进入MessageQueue循环，创建方式分为两种`new Message()`和`Message.obtain()`。通常使用`Message.obtain()`。这种方式**有效避免创建重复Message对象**。

```java
//创建消息对象
Message msg = Message.obtain();
msg.what = 1;
msg.obj = "test";

//源码位置 .../core/java/android/os/Message.java
    /** Constructor (but the preferred way to get a Message is to call {@link #obtain() Message.obtain()}).
    */
//new Message 方法
public Message() {
    }

private static final Object sPoolSync = new Object();
//维护一个Message池，用于复用Message对象
private static Message sPool;
//最多维护50个
    private static final int MAX_POOL_SIZE = 50;
//obtain方法 直接从池内获取Message对象，避免new占用内存
public static Message obtain() {
        synchronized (sPoolSync) {
            if (sPool != null) {
                Message m = sPool;
                sPool = m.next;
                m.next = null;
                m.flags = 0; // clear in-use flag
                sPoolSize--;
                //直接从池中取出
                return m;
            }
        }
        //无可复用对象，则重新new获取
        return new Message();
    }
```

还可以通过`handler.obtainMessage()`创建消息

```java
//Handler.java
    public final Message obtainMessage()
    {
        return Message.obtain(this);
    }

    public final Message obtainMessage(int what)
    {
        return Message.obtain(this, what);
    }
```

实质还是调用了`Message.obtain()`构建消息实例.

### **5.发送消息(Message)**

![发送消息](/images/Handler-源码5.png)

> Handler主要有以下几种发送消息的方式:
>
> - `sendMessage(Message msg)`
> - `sendMessageDelayed(int what, long delayMillis)`
> - `post(Runnable r)`
> - `postDelayed(Runnable r, long delayMillis)`
> - `sendMessageAtTime(Message msg, long uptimeMillis) `
>
> 最终都是会调用到`sendMessageAtTime(Message msg, long uptimeMillis)`然后继续调用到`enqueueMessage(MessageQueue queue, Message msg, long uptimeMillis)`放入MessageQueue

```java
//源码位置：.../core/java/android/os/Handler.java 
//post方法
public final boolean post(Runnable r)
    {
       return  sendMessageDelayed(getPostMessage(r), 0);
    }
public final boolean postAtTime(Runnable r, long uptimeMillis)
    {
        return sendMessageAtTime(getPostMessage(r), uptimeMillis);
    }
public final boolean postAtTime(Runnable r, Object token, long uptimeMillis)
    {
        return sendMessageAtTime(getPostMessage(r, token), uptimeMillis);
    }
public final boolean postDelayed(Runnable r, long delayMillis)
    {
        return sendMessageDelayed(getPostMessage(r), delayMillis);
    }
//利用post()方式发送消息，需要转换为Message向下传递
private static Message getPostMessage(Runnable r, Object token) {
        Message m = Message.obtain();
        m.obj = token;
        //将runnable赋值到callback上 以便后续判断是post还是sendMessage方式发送的消息
        m.callback = r;
        return m;
    }

//sendMessage方法
public final boolean sendMessage(Message msg)
    {
        return sendMessageDelayed(msg, 0);
    }

public final boolean sendMessageDelayed(Message msg, long delayMillis)
    {
        if (delayMillis < 0) {
            delayMillis = 0;
        }
        return sendMessageAtTime(msg, SystemClock.uptimeMillis() + delayMillis);
    }

//所有的发送消息有关方法 都会调用到这个方法
public boolean sendMessageAtTime(Message msg, long uptimeMillis) {
        //获取MessageQueue对象 
        MessageQueue queue = mQueue;
        //获取对象为空 抛出异常
        if (queue == null) {
            RuntimeException e = new RuntimeException(
                    this + " sendMessageAtTime() called with no mQueue");
            Log.w("Looper", e.getMessage(), e);
            return false;
        }
        //对象不为空 调用enqueueMessage方法
        return enqueueMessage(queue, msg, uptimeMillis);
    }

//该方法为了 向MessageQueue插入Message
private boolean enqueueMessage(MessageQueue queue, Message msg, long uptimeMillis) {
        // 把当前的Handler设置为 消息标记位 即把消息派发给相对应的Handler实例
        msg.target = this;
        if (mAsynchronous) {
            msg.setAsynchronous(true);
        }
        //调用MessageQueue的enqueueMessage方法
        return queue.enqueueMessage(msg, uptimeMillis);
    }
```

总结：

- 发送消息时`Message.when`表示期望该消息被分发的时间即`SystemClock.uptimeMillis() + delayMillis`。`SystemClock.uptimeMillis`代表自系统开机到调用该方法的时间差。
- `uptimeMillis`不包含深度休眠时间，所以“延时多久执行”是以`uptime`为基准，不是自然时钟时间。
- 使用`sendMessageDelayed()`发送消息时，消息会先进入`MessageQueue`并按`when`有序排队，不会立即执行。

### **6.消息入队**

![消息入队](/images/Handler-源码6.png)

发送消息最后调用到的是`MessageQueue.enqueueMessage()`将发送的消息加入到`MessageQueue`中

```java
//源码位置：..core/java/android/os/MessageQueue.java
//内部是一个单链表有序序列，由 Message.when 作为排序依据，该值为一个相对时间。
boolean enqueueMessage(Message msg, long when) {
    ...
    synchronized (this) {
            //正在退出 回收Message
            if (mQuitting) {
                IllegalStateException e = new IllegalStateException(
                        msg.target + " sending message to a Handler on a dead thread");
                Log.w(TAG, e.getMessage(), e);
                msg.recycle();
                return false;
            }

            msg.markInUse();
            msg.when = when;
            Message p = mMessages;
            boolean needWake;
            // p == null判断当前队列中是否有消息，插入消息作为队列头 
            // when == 0||when < p.when 队列当前处于等待状态 唤醒队列
            if (p == null || when == 0 || when < p.when) {
                // New head, wake up the event queue if blocked.
                msg.next = p;
                mMessages = msg;
                needWake = mBlocked;
            } else {
                // Inserted within the middle of the queue.  Usually we don't have to wake
                // up the event queue unless there is a barrier at the head of the queue
                // and the message is the earliest asynchronous message in the queue.
                //当前队列有消息，按照消息创建时间插入到队列中
                needWake = mBlocked && p.target == null && msg.isAsynchronous();
                Message prev;
                //从队列头部开始遍历
                for (;;) {
                    prev = p;
                    p = p.next;
                    //循环到队列尾部或者出现一个when小于当前Message的when
                    if (p == null || when < p.when) {
                        break;
                    }
                    //如果是异步消息 且 存在同步屏障
                    if (needWake && p.isAsynchronous()) {
                        needWake = false;//不需要唤醒 队列
                    }
                }
                msg.next = p; // invariant: p == prev.next
                prev.next = msg;
            }

            // We can assume mPtr != 0 because mQuitting is false.
            if (needWake) {
                nativeWake(mPtr);
            }
        }
        return true;
  }
```

总结：

- 新消息进入时，优先判定当前队列中是否有消息
  - 没有消息，则新进入消息放入队列头部
  - 有消息，则对新消息以及原消息队列的头消息进行执行时间比较，若小于则置于队列头部
- 消息进入消息队列后，会唤醒消息队列(`nativeWake()`)进行等待
- 执行到`enqueueMessage()`时通过添加`synchronized`保证线程安全

### **7.获取消息**

![获取消息](/images/Handler-源码7.png)

> 发送了消息后，MessageQueue维护了消息队列，在Looper中通过`loop()`不断获取Message。通过`next()`获取Message.

```java
//源码位置：..core/java/android/os/MessageQueue.java
Message next(){
    //该参数用于确定消息队列中是否有消息 下一个消息到来前需要等待的时长
    int nextPollTimeoutMillis = 0;
     for (;;) {
            if (nextPollTimeoutMillis != 0) {
                Binder.flushPendingCommands();
            }
            //该方法位于native层 若nextPollTimeoutMillis为-1 代表消息队列处于等待状态 阻塞操作
            nativePollOnce(ptr, nextPollTimeoutMillis);
            ...
            synchronized (this) {
                ...
                 Message msg = mMessages;
                 if (msg != null) {
                    if (now < msg.when) {
                        // 下一条消息尚未准备完毕，需要等待 nextPollTimeoutMillis 之后可以执行
                        nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
                    } else {
                        // Got a message.
                        mBlocked = false;
                        if (prevMsg != null) {
                            prevMsg.next = msg.next;
                        } else {
                            mMessages = msg.next;
                        }
                        msg.next = null;
                        //标记消息使用状态 flag |= FLAG_IN_USE
                        msg.markInUse();
                        //返回一条消息
                        return msg;
                    }
                } else {
                    // No more messages.
                    nextPollTimeoutMillis = -1;
                }
                //消息正在退出
                if (mQuitting) {
                    dispose();
                    return null;
                }
            }
     }
}
```

`nativePollOnce()`：在当前无消息可执行的时候，阻塞等待，直到对应消息的触发时间。

有可用消息时，直接返回可用消息。

补充：

- `MessageQueue.next()`在没有可执行消息时会走`nativePollOnce()`阻塞，属于事件驱动等待，不是CPU忙等循环。
- 队头消息若`when`尚未到达，会计算`nextPollTimeoutMillis`并按该超时进入等待。



### **8.分发消息**

![分发消息](/images/Handler-源码8.png)

> 分发消息到对应的Handler实例并根据传入的Message做对应的操作

```java
//源码位置：.../core/java/android/os/Handler.java 

public void dispatchMessage(Message msg) {
        //若callback不为空，则代表使用了post(Runnable r)方式发送了消息，执行handleCallback方法
        if (msg.callback != null) {
            handleCallback(msg);
        } else {
            //代表使用了sendMessage()方式发送了消息，调用handleMessage方法
            if (mCallback != null) {
                if (mCallback.handleMessage(msg)) {
                    return;
                }
            }
            handleMessage(msg);
        }
    }

//创建Handler实例时复写 自定义消息处理方法
public void handleMessage(Message msg) {
    }

//直接回调runnable对象的run()
private static void handleCallback(Message message) {
        message.callback.run();
    }
```

总结：

- `msg.target.dispatchMessage(msg)`中`msg.target`指向的就是对应Handler实例，

- 消息分发的优先级：
  
  ![消息分发](/images/Handler-源码9.png)
  
  1. Message的回调方法`message.callback.run()`
  
     ```java
     handler.post(new Runnable() {
       @Override
       public void run(){
         //todo
       }
     })
     ```
  
     
  
  2. Handler中Callback的回调方法`mCallback.handleMessage(msg)`
  
     **拥有优先处理消息的能力，可以拦截消息提前进行处理。**
  
     ```java
     Handler handler = new Handler(Looper.getMainLooper(),this);
     
         @Override
         public boolean handleMessage(Message msg) {
             return false; //可以继续执行到 handleMessage()
           //return true;不向下传递消息
         }
     ```
  
     
  
  3. Handler的默认方法`handleMessage()`
  
     ```java
     Handler handler= new Handler(Looper.getMainLooper()){
                 @Override
                 public void handleMessage(Message msg) {
                     super.handleMessage(msg);
                 }
             };
     ```

### **9.Message回收**

> 上面讲到了新建Message推荐使用`obtain()`，因为可以有效的复用消息，其中里面复用的就是`sPool`变量，它是在Message回收的时候进行赋值的。

```java
//源码位置 .../core/java/android/os/Message.java
/*package*/ boolean isInUse() {
        return ((flags & FLAG_IN_USE) == FLAG_IN_USE);
    }

public void recycle() {
        //正在使用 无法回收
        if (isInUse()) {
            if (gCheckRecycle) {
                throw new IllegalStateException("This message cannot be recycled because it "
                        + "is still in use.");
            }
            return;
        }
        recycleUnchecked();
    }

void recycleUnchecked() {
        // Mark the message as in use while it remains in the recycled object pool.
        // Clear out all other details.
        //置为使用标记
        flags = FLAG_IN_USE;
        what = 0;
        arg1 = 0;
        arg2 = 0;
        obj = null;
        replyTo = null;
        sendingUid = -1;
        when = 0;
        target = null;
        callback = null;
        data = null;

        //将Message放在了列表里，缓存的对象由obtain()拿出来复用
        synchronized (sPoolSync) {
            if (sPoolSize < MAX_POOL_SIZE) {
                next = sPool;
                sPool = this;
                sPoolSize++;
            }
        }
    }
```

### **10.Looper退出**

![Looper退出](/images/Handler-源码10.png)

> `Looper.loop()`内部由一个无限循环组成，默认情况下不会退出循环。需要退出就需要调用`quit()`或者`quitSafely()`。

```java
//源码位置 .../core/java/android/os/Looper.java
    public void quit() {
        mQueue.quit(false);
    }

    public void quitSafely() {
        mQueue.quit(true);
    }

//源码位置 .../core/java/android/os/MessageQueue.java
void quit(boolean safe) {
        if (!mQuitAllowed) {
            throw new IllegalStateException("Main thread not allowed to quit.");
        }

        synchronized (this) {
            if (mQuitting) {
                return;
            }
            mQuitting = true;

            if (safe) {
                removeAllFutureMessagesLocked();
            } else {
                removeAllMessagesLocked();
            }

            // We can assume mPtr != 0 because mQuitting was previously false.
            //唤醒等待线程
            nativeWake(mPtr);
        }
    }

//直接移除MessageQueue中的所有消息
 private void removeAllMessagesLocked() {
        Message p = mMessages;
        while (p != null) {
            Message n = p.next;
            //回收未被处理的消息
            p.recycleUnchecked();
            p = n;
        }
        //由于消息为null 则return 出无限循环
        mMessages = null;
    }

//直接移除未处理的消息 已经在执行的继续处理
private void removeAllFutureMessagesLocked() {
        final long now = SystemClock.uptimeMillis();
        Message p = mMessages;
        if (p != null) {
            //还未处理的Message
            if (p.when > now) {
                removeAllMessagesLocked();
            } else {
                Message n;
                for (;;) {
                    n = p.next;
                    if (n == null) {
                        return;
                    }
                    if (n.when > now) {
                        break;
                    }
                    p = n;
                }
                //不接收后续消息
                p.next = null;
                do {
                    p = n;
                    n = p.next;
                    p.recycleUnchecked();
                } while (n != null);
            }
        }
    }
```



## 6. Handler异步消息与同步屏障

![异步消息](/images/Handler-异步消息.png)

### 异步消息

`Handler`构造函数

```java
 public Handler() {
        this(null, false);
    }   
 
 public Handler(Callback callback, boolean async/*是否异步*/) {
        if (FIND_POTENTIAL_LEAKS) {
            final Class<? extends Handler> klass = getClass();
            if ((klass.isAnonymousClass() || klass.isMemberClass() || klass.isLocalClass()) &&
                    (klass.getModifiers() & Modifier.STATIC) == 0) {
                Log.w(TAG, "The following Handler class should be static or leaks might occur: " +
                    klass.getCanonicalName());
            }
        }

        mLooper = Looper.myLooper();
        if (mLooper == null) {
            throw new RuntimeException(
                "Can't create handler inside thread " + Thread.currentThread()
                        + " that has not called Looper.prepare()");
        }
        mQueue = mLooper.mQueue;
        mCallback = callback;
        mAsynchronous = async;//设置异步标志
    }
```

`mAsynchronous`异步标志默认为`false`，在以下代码中使用

```java
    private boolean enqueueMessage(MessageQueue queue, Message msg, long uptimeMillis) {
        msg.target = this;
        if (mAsynchronous) {
            msg.setAsynchronous(true);//设置异步消息
        }
        return queue.enqueueMessage(msg, uptimeMillis);
    }

```

设置消息为`异步消息`有两种方式：

- `new Handler(true)`：所有发出去的消息都会`setAsynchronous(true)`**对应方法都为@hide，不推荐使用**
- `msg.setAsynchronous(true)`：手动设置消息为异步

#### 使用场景

- View的刷新(`Choreographer`发送的都是异步消息)



### 同步屏障

![同步屏障](/images/Handler-同步屏障.png)

> `同步屏障`：挡住普通消息，使得`异步消息`可以被更快处理

#### 添加同步屏障

```java
//MessageQueue.java
    public int postSyncBarrier() {
        return postSyncBarrier(SystemClock.uptimeMillis());
    }

    private int postSyncBarrier(long when) {
        // Enqueue a new sync barrier token.
        // We don't need to wake the queue because the purpose of a barrier is to stall it.
        synchronized (this) {
            final int token = mNextBarrierToken++;
            //没有赋值target，后面需要通过判断target == null，判断是否为同步屏障消息
            final Message msg = Message.obtain();
            msg.markInUse();
            msg.when = when;
            msg.arg1 = token;

            Message prev = null;
            Message p = mMessages;//mMessages 是 队头消息
            if (when != 0) {
                while (p != null && p.when <= when) {
                    prev = p;
                    p = p.next;
                }
            }
            //插入同步屏障
            if (prev != null) { // invariant: p == prev.next
                msg.next = p;
                prev.next = msg;
            } else {
                msg.next = p;
                mMessages = msg;
            }
            return token;//用来取消同步屏障
        }
    }
```

`同步屏障`也是消息的一种，特殊之处在于`target==null`。`target`表示了`消息需要分发的对象`，而`同步屏障`不需要被分发。而且不会唤醒`消息队列`。

补充：

- `ViewRootImpl`在`scheduleTraversals()`中会配合`Choreographer`使用同步屏障，让`vsync`相关异步消息优先执行。
- 屏障必须成对移除；若长期不移除，普通同步消息会持续饥饿，表现为主线程任务堆积。



上面有说到[获取消息](#7-获取消息)通过`MessageQueue.next()`

```java
//MessageQueue.java
Message next() {
        // Return here if the message loop has already quit and been disposed.
        // This can happen if the application tries to restart a looper after quit
        // which is not supported.
        final long ptr = mPtr;
        if (ptr == 0) {
            return null;
        }

        int pendingIdleHandlerCount = -1; // -1 only during first iteration
        int nextPollTimeoutMillis = 0;
        for (;;) {
            if (nextPollTimeoutMillis != 0) {
                Binder.flushPendingCommands();
            }
            //唤醒队列
            nativePollOnce(ptr, nextPollTimeoutMillis);

            synchronized (this) {
                // Try to retrieve the next message.  Return if found.
                final long now = SystemClock.uptimeMillis();
                Message prevMsg = null;
                Message msg = mMessages;
                if (msg != null && msg.target == null) {
                    //同步屏障，找到下一个 异步消息
                    // Stalled by a barrier.  Find the next asynchronous message in the queue.
                    do {
                        prevMsg = msg;
                        msg = msg.next;
                    } while (msg != null && !msg.isAsynchronous());
                }
                if (msg != null) {
                    if (now < msg.when) {
                        // Next message is not ready.  Set a timeout to wake up when it is ready.
                        nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
                    } else {
                        // Got a message.
                        mBlocked = false;
                        if (prevMsg != null) {
                          //取出异步消息
                            prevMsg.next = msg.next;
                        } else {
                            mMessages = msg.next;
                        }
                        msg.next = null;
                        if (DEBUG) Log.v(TAG, "Returning message: " + msg);
                        msg.markInUse();
                        return msg;
                    }
                } else {
                    // No more messages.
                    nextPollTimeoutMillis = -1;
                }

                // Process the quit message now that all pending messages have been handled.
                if (mQuitting) {
                    dispose();
                    return null;
                }
               ...
            }
           ...
        }
    }
```

`Looper`通过循环调用`MessageQueue.next()`不断获取队头的`Message`，执行一个再去取下一个。当`next()`获取队头消息为`同步屏障`时，就会向后遍历队列，获取`异步消息`优先执行，如果没有找到`异步消息`，就会让`next()`进入阻塞状态，主线程也会处于`空闲状态`，直到有`异步消息`进入队列，或者`移除同步屏障`。

#### 移除同步屏障

添加完`同步屏障`后，如果一直都没有消息处理，主线程就会进入空闲状态并且无法处理其他普通消息，此时就需要移除`同步屏障`，保证正常的消息处理。

```java
//MessageQueue.java
public void removeSyncBarrier(int token) {
        // Remove a sync barrier token from the queue.
        // If the queue is no longer stalled by a barrier then wake it.
        synchronized (this) {
            Message prev = null;
            Message p = mMessages;
            //根据token找到对应的 同步屏障消息，并移除
            while (p != null && (p.target != null || p.arg1 != token)) {
                prev = p;
                p = p.next;
            }
            if (p == null) {
                throw new IllegalStateException("The specified message queue synchronization "
                        + " barrier token has not been posted or has already been removed.");
            }
            final boolean needWake;
            if (prev != null) {
                prev.next = p.next;
                needWake = false;
            } else {
                mMessages = p.next;
                needWake = mMessages == null || mMessages.target != null;
            }
            p.recycleUnchecked();

            // If the loop is quitting then it is already awake.
            // We can assume mPtr != 0 when mQuitting is false.
            if (needWake && !mQuitting) {
                nativeWake(mPtr);
            }
        }
    }
```

移除`同步屏障`消息后，再次唤醒消息队列。

## 7. 主线程的消息循环

Android的主线程就是`ActivityThread`，主线程的入口方法为`main()`。

```java
// ../android/app/ActivityThread.java
public static void main(String[] args) {
 ...
        //创建主线程的Looper对象
        Looper.prepareMainLooper();

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
        //该方法后 不能在写方法因为会被阻塞  开启主线程的消息循环
        Looper.loop();
}

//主要处理四大组件的启动和停止等过程
 private class H extends Handler {
  ...
    public void handleMessage(Message msg) {
     ...
     //处理主线程消息
    }
 }
```



> 主线程间的消息循环模型：

`ActivityThread`通过`ApplicationThread`和`AMS(ActivityManagerService)`进行进程间通信，`AMS`以进程间通信的方式完成`ActivityThread`的请求后回调`ApplicationThread`中的`Binder()`，然后`ApplicationThread`向`ActivityThread.H`发送消息，`H`收到消息后会把`ApplicationThread`中的逻辑切换到`ActivityThread`中去执行，这时就切换到了主线程。

补充：`MessageQueue.IdleHandler`会在队列“暂时空闲”时执行，常见触发有两种：

1. 队列完全没有消息。
2. 队头消息存在但`when`尚未到达，线程进入等待前会先跑一轮`IdleHandler`。

`IdleHandler`适合轻量级延后初始化，不适合重任务。







## 8. Native层分析

在一个常见的面试题`为什么Looper死循环不会导致应用卡死`中，一般会回答`内部采用epoll机制，当没有消息时就会进入休眠状态，直到新消息到来时，通过epoll唤醒主线程继续执行消息。`

上述的回答就需要涉及到`Handler`在`Native`层的实现，包括`阻塞等待、唤醒，epoll机制`相关。



### MessageQueue的Native实现

`Message(消息)`的处理都是位于`MessageQueue(消息队列)`中。

Java层的`MessageQueue`在上面已经分析过了，主要在于`enqueueMessage()——添加消息`和`next()——获取消息`。在Native层对应的就是`nativeWake()——唤醒`和`nativePollOnce()——阻塞`。

对应位置为`android_os_MessageQueue.cpp`

#### nativeInit()——初始化

![初始化](/images/Handler-nativeInit.png)

```c++
//android_os_MessageQueue.cpp
static jlong android_os_MessageQueue_nativeInit(JNIEnv* env, jclass clazz) {
    NativeMessageQueue* nativeMessageQueue = new NativeMessageQueue();
    if (!nativeMessageQueue) {
        jniThrowRuntimeException(env, "Unable to allocate native queue");
        return 0;
    }
  //强引用计数 应用于内存管理
    nativeMessageQueue->incStrong(env);
  //强制类型转换，保存在java层
    return reinterpret_cast<jlong>(nativeMessageQueue);
}

NativeMessageQueue::NativeMessageQueue() :
        mPollEnv(NULL), mPollObj(NULL), mExceptionObj(NULL) {
   //获取当前线程的Looper对象
    mLooper = Looper::getForThread();
    if (mLooper == NULL) {
      //创建Native层的looper对象
        mLooper = new Looper(false);
      //将Looper对象存入当前线程
        Looper::setForThread(mLooper);
    }
}
```

执行`nativeInit()`进行初始化时，一并初始化了`Looper`对象

```c++
//system/core/libutils/Looper.cpp
Looper::Looper(bool allowNonCallbacks) :
        mAllowNonCallbacks(allowNonCallbacks), mSendingMessage(false),
        mPolling(false), mEpollFd(-1), mEpollRebuildRequired(false),
        mNextRequestSeq(0), mResponseIndex(0), mNextMessageUptime(LLONG_MAX) {
   //构造唤醒事件的文件描述符 fd  
    mWakeEventFd = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
    LOG_ALWAYS_FATAL_IF(mWakeEventFd < 0, "Could not make wake event fd: %s",
                        strerror(errno));

    AutoMutex _l(mLock);
   //重建epoll事件
    rebuildEpollLocked();
}

void Looper::rebuildEpollLocked() {
    // Close old epoll instance if we have one.
    if (mEpollFd >= 0) {
#if DEBUG_CALLBACKS
        ALOGD("%p ~ rebuildEpollLocked - rebuilding epoll set", this);
#endif
      //关闭旧的epoll实例
        close(mEpollFd);
    }

    // 创建新的epoll实例，并注册wake管道
    mEpollFd = epoll_create(EPOLL_SIZE_HINT);
    LOG_ALWAYS_FATAL_IF(mEpollFd < 0, "Could not create epoll instance: %s", strerror(errno));

    struct epoll_event eventItem;
    memset(& eventItem, 0, sizeof(epoll_event)); // zero out unused members of data field union
    eventItem.events = EPOLLIN;//可读事件
    eventItem.data.fd = mWakeEventFd;
  //添加唤醒事件到 epoll实例中
    int result = epoll_ctl(mEpollFd, EPOLL_CTL_ADD, mWakeEventFd, & eventItem);
    LOG_ALWAYS_FATAL_IF(result != 0, "Could not add wake event fd to epoll instance: %s",
                        strerror(errno));

    for (size_t i = 0; i < mRequests.size(); i++) {
        const Request& request = mRequests.valueAt(i);
        struct epoll_event eventItem;
        request.initEventItem(&eventItem);
       //将各种事件如键盘、鼠标等事件添加到 mEpollFd中，进行监听
        int epollResult = epoll_ctl(mEpollFd, EPOLL_CTL_ADD, request.fd, & eventItem);
        if (epollResult < 0) {
            ALOGE("Error adding epoll events for fd %d while rebuilding epoll set: %s",
                  request.fd, strerror(errno));
        }
    }
}
```

初始化Looper对象，主要执行两步：

1. 构建唤醒事件文件描述符`mWakeEventFd`
2. 执行`rebuildEpollLocked`,主要用到了`epoll机制`
   - 通过`epoll_create()`创建epoll文件描述符`mEpollFd`
   - 创建管道监听`EPOLLIN`事件
   - 通过`epoll_ctl()`添加`mWakeEventFd`添加到`epoll`监听范围内。*当mWakeEventFd发生了写入后，epoll可以监听到事件的发生*
   - 最后通过`epoll_ctl()`监听一些其他事件，例如`键盘、鼠标输入事件`。

> 总结：
>
> `nativeInit()`阶段就把`Java MessageQueue`和`NativeMessageQueue`绑定在一起，并提前准备好`epoll + eventfd`这套阻塞/唤醒基础设施。
>
> 后续Java层调用`nativePollOnce()`会进入阻塞等待，调用`nativeWake()`会通过`eventfd`写入触发`epoll_wait()`返回，最终实现`无消息休眠、有消息唤醒`。

#### * nativePollOnce()——阻塞

![阻塞](/images/Handler-nativePollOnce.png)

> 在`MessageQueue.next()`中调用

```c++
//android_os_MessageQueue.cpp
static void android_os_MessageQueue_nativePollOnce(JNIEnv* env, jobject obj,
        jlong ptr, jint timeoutMillis) {
    NativeMessageQueue* nativeMessageQueue = reinterpret_cast<NativeMessageQueue*>(ptr);
    nativeMessageQueue->pollOnce(env, obj, timeoutMillis);
}

void NativeMessageQueue::pollOnce(JNIEnv* env, jobject pollObj, int timeoutMillis) {
    mPollEnv = env;
    mPollObj = pollObj;
    mLooper->pollOnce(timeoutMillis);
  //使用完毕及时置空
    mPollObj = NULL;
    mPollEnv = NULL;
    ...
}
```

```c++
//system/core/libutils/Looper.cpp
int Looper::pollOnce(int timeoutMillis, int* outFd, int* outEvents, void** outData) {
    int result = 0;
    for (;;) {
      //先处理没有Callback方法的Response事件
        while (mResponseIndex < mResponses.size()) {
            const Response& response = mResponses.itemAt(mResponseIndex++);
            int ident = response.request.ident;
            if (ident >= 0) {
                int fd = response.request.fd;
                int events = response.events;
                void* data = response.request.data;
#if DEBUG_POLL_AND_WAKE
                ALOGD("%p ~ pollOnce - returning signalled identifier %d: "
                        "fd=%d, events=0x%x, data=%p",
                        this, ident, fd, events, data);
#endif
                if (outFd != NULL) *outFd = fd;
                if (outEvents != NULL) *outEvents = events;
                if (outData != NULL) *outData = data;
                return ident;
            }
        }

      //跳出循环，回到Java层
        if (result != 0) {
#if DEBUG_POLL_AND_WAKE
            ALOGD("%p ~ pollOnce - returning result %d", this, result);
#endif
            if (outFd != NULL) *outFd = 0;
            if (outEvents != NULL) *outEvents = 0;
            if (outData != NULL) *outData = NULL;
            return result;
        }
       //向下执行内部轮询
        result = pollInner(timeoutMillis);
    }
}
```

`pollOnce()`参数说明：

- `timeoutMillis`：超时时间
- `outFd`：发生事件的文件描述符
- `outEvents`：在当前fd发生的事件
  - `EVENT_INPUT`：可读
  - `EVENT_OUTPUT`：可写
  - `EVENT_ERROR`：错误
  - `EVENT_HANGUP`：中断
  - `EVENT_INVALID`：刷新
- `outData`：上下文数据

`先处理不带Callback的Response事件，再继续调用pollInner()`

```c++
//system/core/libutils/Looper.cpp
int Looper::pollInner(int timeoutMillis) {
  ...
    int result = POLL_WAKE;
    mResponses.clear();
    mResponseIndex = 0;

    // We are about to idle.
    mPolling = true;

    struct epoll_event eventItems[EPOLL_MAX_EVENTS];//16 最大接收事件
    int eventCount = epoll_wait(mEpollFd, eventItems, EPOLL_MAX_EVENTS, timeoutMillis);
  
    // Acquire lock.
    mLock.lock();

    // epoll发生错误
    if (eventCount < 0) {
      ...
        result = POLL_ERROR;
      //跳转到Done
        goto Done;
    }

    // epoll发生超时
    if (eventCount == 0) {
      ...
        result = POLL_TIMEOUT;
      //跳转到Done
        goto Done;
    }  
  
  //遍历事件集合
    for (int i = 0; i < eventCount; i++) {
      //获取文件描述符
        int fd = eventItems[i].data.fd;
        uint32_t epollEvents = eventItems[i].events;
        if (fd == mWakeEventFd) {//当前为唤醒事件
            if (epollEvents & EPOLLIN) {//唤醒事件类型为 EPOLLIN
                awoken();//当前已处于唤醒状态。不断的读取管道数据，直到清空管道
            } else {
                ALOGW("Ignoring unexpected epoll events 0x%x on wake event fd.", epollEvents);
            }
        } else {
          //其他事件类型 。例如鼠标键盘事件等
          //只有符合对应的消息类型，消息才会被分发
            ssize_t requestIndex = mRequests.indexOfKey(fd);
            if (requestIndex >= 0) {
                int events = 0;
              ...
              //处理对应的Request
                pushResponse(events, mRequests.valueAt(requestIndex));
            } else {
              ...
            }
        }
    }  
  
Done: ;
    // Invoke pending message callbacks.
    mNextMessageUptime = LLONG_MAX;
    while (mMessageEnvelopes.size() != 0) {
        nsecs_t now = systemTime(SYSTEM_TIME_MONOTONIC);
        const MessageEnvelope& messageEnvelope = mMessageEnvelopes.itemAt(0);
        if (messageEnvelope.uptime <= now) {
            { // obtain handler
                sp<MessageHandler> handler = messageEnvelope.handler;
              //获取 消息
                Message message = messageEnvelope.message;
                mMessageEnvelopes.removeAt(0);
                mSendingMessage = true;
              //解锁
                mLock.unlock();
              //回调handleMessage处理消息
                handler->handleMessage(message);
            } // release handler

            mLock.lock();
            mSendingMessage = false;
          //表示 监听事件被触发
            result = POLL_CALLBACK;
        } else {
            // 消息还没到达执行时间
            mNextMessageUptime = messageEnvelope.uptime;
            //进入下一次循环
            break;
        }
    }

    // Release lock.
    mLock.unlock();

    ... //处理带有callback的response事件
          for (size_t i = 0; i < mResponses.size(); i++) {
        Response& response = mResponses.editItemAt(i);
        if (response.request.ident == POLL_CALLBACK) {
            int fd = response.request.fd;
            int events = response.events;
            void* data = response.request.data;

            // Invoke the callback.  Note that the file descriptor may be closed by
            // the callback (and potentially even reused) before the function returns so
            // we need to be a little careful when removing the file descriptor afterwards.
            int callbackResult = response.request.callback->handleEvent(fd, events, data);
            if (callbackResult == 0) {
                removeFd(fd, response.request.seq);
            }

            // Clear the callback reference in the response structure promptly because we
            // will not clear the response vector itself until the next poll.
            response.request.callback.clear();
            result = POLL_CALLBACK;
        }
    }
    
    return result;
}

void Looper::awoken() {
    uint64_t counter;
   //不断读取管道，为了清空管道数据
    TEMP_FAILURE_RETRY(read(mWakeEventFd, &counter, sizeof(uint64_t)));
}

//system/core/libutils/include/utils/Looper.h
    struct MessageEnvelope {
        MessageEnvelope() : uptime(0) { }

        MessageEnvelope(nsecs_t u, const sp<MessageHandler> h,
                const Message& m) : uptime(u), handler(h), message(m) {
        }

        nsecs_t uptime;
        sp<MessageHandler> handler; //处理消息
        Message message;//消息内容
    };
```

`pollInner()`是`pollOnce()`最关键的方法，主要执行了以下三步：

1. 执行了`epoll_wait()`，等待`mEpollFd`事件发生返回或者超时返回。*mEpollFd上只要发生任何事，epoll_wait就会监听到，返回发生的事件数目(eventCount)。如果在`timeoutMillis`之间没有发生事件，到达时间后就会唤醒并返回0*

2. 遍历`eventCount(发生事件的数目)`，判断**当前是哪一个文件描述符发生了事件**

   - 是`mWakeEventFd`：调用`awoken()`不断读取管道数据，直到清空管道
   - 其他fd：处理`request`，生成对应的`response`，并push到`mResponses`

3. 进入`Done`代码段

   - 先处理`Native Message`，通过调用`MessageEnvelope.handler`执行消息(`handleMessage`)
   - 在处理`mResponses`，只有返回值为`POLL_CALLBACK`才需要处理消息，通过`handleEvent()`进行消息的处理

4. 返回`result`

   主要有以下几种类型：

   - `POLL_WAKE`：触发`wake()`表示有内容写入管道
   - `POLL_CALLBACK`：表示某个监听fd被触发
   - `POLL_TIMEOUT`：等待超时
   - `POLL_ERROR`：等待期间发生错误



> Android事件类型：
>
> `Native Message`：Native层发送的消息
>
> `Native request-response`：一些系统事件，例如键盘、鼠标事件
>
> `Java Message`：普通的Java层消息，例如`Handler发送接收的消息`
>
> 执行优先级为：**Native Message > Native request > Java Message **



#### nativeWake()——唤醒

![唤醒](/images/Handler-nativeWake.png)

> 在`MessageQueue.enqueueMessage()`调用
>
> 其他执行条件：`MessageQueue.quit()`和`MessageQueue.removeSyncBarrier()`

```c++
//frameworks/base/core/jni/android_os_MessageQueue.cpp
static void android_os_MessageQueue_nativeWake(JNIEnv* env, jclass clazz, jlong ptr) {
    NativeMessageQueue* nativeMessageQueue = reinterpret_cast<NativeMessageQueue*>(ptr);
    nativeMessageQueue->wake();
}

void NativeMessageQueue::wake() {
    mLooper->wake();
}
```

```c++
//system/core/libutils/Looper.cpp
void Looper::wake() {
    uint64_t inc = 1;
  //通过mWakeEventFd向管道中写入 1
    ssize_t nWrite = TEMP_FAILURE_RETRY(write(mWakeEventFd, &inc, sizeof(uint64_t)));
    if (nWrite != sizeof(uint64_t)) {
        if (errno != EAGAIN) {
            LOG_ALWAYS_FATAL("Could not write wake signal to fd %d: %s",
                    mWakeEventFd, strerror(errno));
        }
    }
}
```

`TEMP_FAILURE_RETRY`是一个宏定义，执行`write()`失败后，会不断重复执行，直到执行成功为止。

`wake()`主要执行了以下几步：

- 不断重复执行`write()`通过`mWakeEventFd`向管道写入字符`inc——1`直到执行成功为止。

在`nativeInit()`中已经通过`epoll`监听`mWakeEventFd`的事件，当`mWakeEventFd`有事件发生时，就可以在`epoll_wait`读取事件并返回，返回后可以执行消息处理逻辑。

主要起到一个**通知唤醒**的作用。



#### nativeDestroy()——销毁

![销毁](/images/Handler-nativeDestroy.png)

当`Looper.quit()`时对应的`MessageQueue`也会退出，执行`MessageQueue.quit()`

```java
//Looper.java
    public void quit() {
        mQueue.quit(false);
    }

//MessageQueue.java
    void quit(boolean safe) {
        if (!mQuitAllowed) {
            throw new IllegalStateException("Main thread not allowed to quit.");
        }

        synchronized (this) {
            if (mQuitting) {
                return;
            }
          //表示需要退出
            mQuitting = true;

            if (safe) {
              //在运行的消息继续执行，后续不添加新消息
                removeAllFutureMessagesLocked();
            } else {
              //移除所有消息
                removeAllMessagesLocked();
            }

            // We can assume mPtr != 0 because mQuitting was previously false.
            nativeWake(mPtr);
        }
    }

    Message next() {
     ...
       if (mQuitting) {
          dispose();
          return null;
       }
      ...
    }

    private void dispose() {
        if (mPtr != 0) {
          //执行退出流程
            nativeDestroy(mPtr);
            mPtr = 0;
        }
    }
```

```c++
//frameworks/base/core/jni/android_os_MessageQueue.cpp
static void android_os_MessageQueue_nativeDestroy(JNIEnv* env, jclass clazz, jlong ptr) {
    NativeMessageQueue* nativeMessageQueue = reinterpret_cast<NativeMessageQueue*>(ptr);
    nativeMessageQueue->decStrong(env);
}

//system/core/libutils/RefBase.cpp
void RefBase::decStrong(const void* id) const
{
    weakref_impl* const refs = mRefs;
    refs->removeStrongRef(id);//移除强引用
    const int32_t c = refs->mStrong.fetch_sub(1, std::memory_order_release);

    if (c == 1) {
        std::atomic_thread_fence(std::memory_order_acquire);
        refs->mBase->onLastStrongRef(id);
        int32_t flags = refs->mFlags.load(std::memory_order_relaxed);
        if ((flags&OBJECT_LIFETIME_MASK) == OBJECT_LIFETIME_STRONG) {
            delete this;
            // The destructor does not delete refs in this case.
        }
    }
  //移除弱引用
    refs->decWeak(id);
}
```

最终通过调用`decStrong()`移除`nativeInit()`时增加的强引用`incStrong()`。



### 总结

> Java层的MessageQueue 和 Native层的MessageQueue 通过JNI建立关联，使得MessageQueue成为Java层和Native层的枢纽。
>
> `既能处理上层消息，也可以处理Java消息`。

![Java和Native对应关系](/images/handler_arch.png)

#### 整体的执行流程

创建Java层的`MessageQueue`调用`nativeInit()`构造native层的`MessageQueue`，并且同时创建native层的`Looper`，并且保存到`TLS`中。

创建native的`Looper`后，通过`epoll与管道`建立一套native的消息机制。

创建唤醒事件描述符`mWakeEventFd`，调用`epoll_create()`创建`mEpollFd和管道`，在调用`epoll_ctl()`监听`mWakeEventFd`的事件

Java层发送消息时，调用到`MessageQueue.enqueueMessage()`，继续调用到`nativeWake()`唤醒阻塞线程，此时会通过`mWakeEventFd`往`管道`写入`1`，唤醒阻塞的线程处理消息。

Java层获取消息时，调用到`MessageQueue.next()`，继续调用到`nativePollOnce()`阻塞线程，通过`epoll_wait()`等待事件发生或超时，当`mEpollFd`监听的任何fd发生事件时，`epoll_wait()`就会返回。返回之后按照`Native Message -> Native Request -> Java Message`的顺序处理消息。



![MessageQueue-Native](/images/MessageQueue-Native.jpg)

## 9. epoll机制

![epoll机制](/images/epoll机制.png)

> `epoll机制`是一种高效的**IO多路复用机制**。
>
> 使用`一个文件描述符管理多个文件描述符`，将用户关心的文件描述符存放到内核的一个事件表中，这样用户空间和内核空间的拷贝只需一次。
>
> 利用`mmap()`映射内核空间，加速了用户空间与内核空间的消息传递。

### 操作过程

![主要方法](/images/epoll-主要方法.png)

`epoll_create(int size)`

- `size`：需要监听的文件描述符上限。*不是能监听的最大值*

创建一个`epoll`的文件描述符`epollFd`。



`epoll_ctl(int epfd,int op,int fd,struct epoll_event *event)`

- `epfd`：`epoll_create`的返回值
- `op`：表示操作，有这三种类型：
  - EPOLL_CTL_ADD：添加对`fd`的监听事件
  - EPOLL_CTL_DEL：删除对`fd`的监听事件
  - EPOLL_CTL_MOD：修改对`fd`的监听事件
- `fd`：需要监听的fd
- `event`：需要监听的事件，常用的有以下几种
  - EPOLLIN：fd可读
  - EPOLLOUT：fd可写
  - EPOLLERR：fd发生错误
  - EPOLLHUP：fd被挂断

对于需要监听的`fd`执行`op`操作

例如`epoll_ctl(epollfd,EPOLL_CTL_ADD,mWakeEventFd,EPOLLIN)`，就表示对`mWakeEventFd`添加`可读`事件监听



`epoll_wait(int epfd,struct epoll_event *events,int maxevents,int timeout)`

- `epfd`：`epoll_create`的返回值
- `events`：从内核得到的事件集合
- `maxevents`：通知内核`events`的大小
- `timeout`：等待超时时间

等待`epfd`上的事件，最多返回`maxEvents`个事件。

返回`0`表示等待超时；返回`-1`表示等待发生错误。



> 通过`epoll_create()`创建一个`epollFd`去监听事件。通过`epoll_ctl()`注册监听哪些`fd`以及需要监听的`event`。一旦`fd`就绪，内核就会采用类似回调的机制激活`fd`。最后通过`epoll_wait()`等待通知。

### 工作模式

![工作模式](/images/epoll-工作模式.png)

#### LT模式(默认)

> 当`epoll_wait()`监听到事件时会通知到应用程序，**应用程序不需要立即处理事件**，在下次`epoll_wait()`监听到事件时，会再次通知应用程序。

同时支持`blocking socket`和`non-blocking socket`。

#### ET模式

> 当`epoll_wait()`监听到事件时会通知到应用程序，**应用程序需要立即处理事件**，否则，在下次`epoll_wait()`监听到事件时，不会再次通知到应用程序。

虽然`减少了epoll事件被重复触发的次数，因此效率要高于LT模式`。但是`必须使用non-blocking socket`。避免因为阻塞读写导致处理多个fd的任务饿死。





### 与其他多路复用机制的比较

![多路复用](/images/epoll-其他多路复用机制.png)

除了`epoll`以外，其他的还有`inotify、select,poll`

`IO多路复用`：内核一旦发现进程指定的一个或多个IO条件准备读取，内核就会通知该进程。



#### inotify

> 允许打开一个独立的文件描述符，可以监控一个或多个文件。例如：打开、创建，删除等事件。
>
> `FileObserver`就是采用`inotify`进行文件的监控

`inotify_init()`：创建一个监听文件变动的`inotify`实例，并返回指向该文件的fd

`inotify_add_watch()`：增加对文件或目录的监控，并指定监控事件

`inotify_rm_watch()`：移除对文件或目录的监控



`iNotify`可以监听到的文件事件：

- access：读取文件
- modify：文件内容被修改
- attrib：文件元数据被修改
- move：文件发生了移动
- create：生成新文件
- open：文件打开
- close：文件关闭
- delete：文件被删除



#### select

> **良好的跨平台支持**，调用`select`后会阻塞，直到有描述符就绪，或者超时，`select`函数返回，最后通过遍历`fdset`，判断是哪个描述符就绪。

支持的文件描述符有三类：writefds、readfds、exceptfds。

<br>

缺点：

- 单个进程能够监视的文件描述符存在最大数量限制，一般为`1024`，在64位系统上为`2048`
- 扫描时采用的是线性扫描，即**轮询**，效率较低
- 需要维护一个存放`fd`的数据结构，导致用户空间与内核空间传递过程复制开销大



#### poll

> 本质和`select`差不多，后面都需要通过`轮询`判断哪个描述符已经就绪

可支持多种文件描述符，且没有最大数量限制。

缺点：

- 扫描时采用的是线性扫描，即**轮询**，效率较低
- 采用`LT-水平触发`，若没有处理，下次执行会继续报告该fd已就绪



> 表面上看`epoll`的效率是最高的，但是`在连接数很少且连接都十分活跃的情况下`select和poll的效率都更高。毕竟`epoll`的通知机制需要很多回调。
>
> `select`和`poll`效率相对较低的原因就在于`需要轮询`。



## 10. Handler内存泄漏原因

> 更准确地说，风险通常来自`MessageQueue`中的延迟消息持有`Handler`，`Handler`再间接持有`Activity/Fragment`引用。

![Handler-内存泄漏分析](/images/Handler-内存泄漏分析.png)

**匿名内部类默认会持有外部对象**

```java
class MainActivity extends Activity{
  
  private final Handler mHandler = new Handler(){        
    @Override
    public void handleMessage(Message msg) {            
        super.handleMessage(msg);
       }
    };
  
}
```

此时`handler`持有`Activity`

发生内存泄漏，需要找到`GCRoots`对象

> GCRoots分类：
>
> - 虚拟机栈引用的对象
> - 本地方法栈JNI引用的对象
> - 方法区中 静态属性引用的对象
> - 方法区中 常量引用的对象



当有延迟消息尚未处理时，`Message.target(Handler)`会让外部页面对象继续被间接引用，页面销毁后也可能无法及时回收。

`sThreadLocal`是线程与`Looper`的绑定容器，但通常不是“匿名Handler泄漏”的直接根因。



错误的写法:

```java
private final Handler mHandler = new Handler(){        
    @Override
    public void handleMessage(Message msg) {            
        super.handleMessage(msg);
       }
    };

```

**非静态的内部类和匿名内部类都会隐式的持有其外部类的引用，而静态内部类不会持有外部类的引用。**

正确的写法：

> 继承`Handler`时候要么放在单独的类文件中，要么直接使用静态内部类。

```java
//需要在静态内部类中调用外部类时，可以直接使用  `弱引用`  进行处理
private static final class MyHandler extends Handler{
    private final WeakReference<MyActivity> mWeakReference;
    public MyHandler(MyActivity activity){
         mWeakReference = new WeakReference<>(activity);
    }
    @Override
    public void handleMessage(Message msg){
        super.handleMessage(msg);
        MyActivity activity = mWeakReference.get();
    }
}
//调用方法
private MyHandler mHandler = new MyHandler(this);
```

> 在`Activity.onDestroy()`时移除所有消息

```java
    @Override
    protected void onDestroy() {
        super.onDestroy();
        mHandler.removeCallbacksAndMessages(null);
    }
```



## 11. 其他Tip

### Handler的同步方法(`runWithScissors()`)

```java
//Handler.java
    public final boolean runWithScissors(final Runnable r, long timeout) {
        if (r == null) {
            throw new IllegalArgumentException("runnable must not be null");
        }
        if (timeout < 0) {
            throw new IllegalArgumentException("timeout must be non-negative");
        }

        if (Looper.myLooper() == mLooper) {
            r.run();
            return true;
        }

      //等待任务执行完毕 再返回
        BlockingRunnable br = new BlockingRunnable(r);
        return br.postAndWait(this, timeout);
    }
```

### 版本差异速览

- Android P(API 28)开始提供`Handler.createAsync(...)`，可方便创建异步`Handler`。
- Android R(API 30)起，无参`Handler()`构造方法被标记为`@Deprecated`，建议显式传入`Looper`，避免线程绑定歧义。
- 新版本系统更强调“显式线程归属”，写法上推荐`new Handler(Looper.getMainLooper())`或基于`HandlerThread`创建。

## 参考链接

<!-- https://www.jianshu.com/p/57a426b8f145 -->

[Linux IO模式及 select、poll、epoll详解](https://segmentfault.com/a/1190000003063859)

[Handler 这些知识点你都知道吗](https://juejin.im/post/6879376888360501262#heading-0)

[Handler(Native)](http://gityuan.com/2015/12/27/handler-message-native/)

[Android源码](https://cs.android.com/android/platform/superproject/+/android-9.0.0_r34:system/core/libutils/Looper.cpp)

[Android消息机制](https://juejin.cn/post/6844903961133072398#heading-4)
