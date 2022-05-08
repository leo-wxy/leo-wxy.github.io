---
title: Android-线程相关
date: 2018-12-21 11:22:00
tags: Android
top: 10
---

<!--AsyncTask 内部实现-->

{% fullimage /images/Android中的线程.png,Android线程,Android线程%}

在Android中进程一般指代App，线程又分为

- 主线程：进程所拥有的线程，默认情况下一个进程只有一个线程，这个线程就是主线程。Android中对应UI线程
- 子线程：工作线程，除主线程以外的线程都是工作线程。Android中的子线程的作用是处理耗时任务，比如网络请求，IO操作。

## Thread

{% post_link Java多线程基础%}

## AsyncTask

> 轻量级的异步任务，可以在线程池中执行后台任务，然后把执行的进度和最终结果传递给主线程并在主线程更新UI。

在Android中实现异步任务机制机制有两种方式：`Handler`和`AsyncTask`。

- Handler机制存在的问题：代码相对臃肿；多任务同时执行时不易控制线程。

AsyncTask的优点：创建异步任务更简单，直接继承它可以方便实现后台异步任务的执行科进度的回调更新UI，而无需编写任务线程和Handler实例就能完成相同的任务。

### AsyncTask的重要参数及方法

AsyncTask是抽象的泛型类

```java
public abstract class AsyncTask<Params,Progress,Result>{
  ...
}
```

三个泛型参数：

- `Params`：表示执行AsyncTask需要传入的参数，可用于在后台任务中使用
- `Progress`：后台执行任务的进度的类型
- `Result`：后台任务的返回结果的类型

不需要传递具体的参数，都可以用`void`代替。

五个核心方法：

- `onPreExecute()`：在主线程中执行，在异步任务执行之前调用，一般可以做一些初始化工作。
- `doInBackground(Params... params)`：在线程池中执行，可用于处理所有的耗时任务。可以通过调用`publishProgress()`来更新任务进度。
- `onProgrssUpdate(Progress... values)`：在主线程中执行，后台任务执行进度发生改变时调用此方法。
- `onPostExecute(Result result)`：在主线程中执行，在异步任务执行完毕并通过return语句返回时被调用。
- `onCancelled()`：在主线程中执行，当异步任务取消时被调用，可用于取消任务时的界面更新。

**不要直接调用上述方法，并且AsyncTask对象必须在主线程创建。一个AsyncTask对象只能执行一次，否则会报异常。**



### AsyncTask使用

实现一个下载文件的AsyncTask

```java
class DownloadTask extends AsyncTask<String, Integer, Boolean> {  
  
    @Override//初始化一个ProgressDialog  
    protected void onPreExecute() {  
        progressDialog.show();  
    }  
  
    @Override//具体的下载逻辑
    protected Boolean doInBackground(String... params) {  
        try {  
            while (true) {  
                int downloadPercent = doDownload(params[0]);  
                publishProgress(downloadPercent);  
                if (downloadPercent >= 100) {  
                    break;  
                }  
            }  
        } catch (Exception e) {  
            return false;  
        }  
        return true;  
    }  
  
    @Override//显示当前的下载进度
    protected void onProgressUpdate(Integer... values) {  
        progressDialog.setMessage("当前下载进度：" + values[0] + "%");  
    }  
  
    @Override//提示任务的执行结果  
    protected void onPostExecute(Boolean result) {  
        progressDialog.dismiss();  
        if (result) {  
            Toast.makeText(context, "下载成功", Toast.LENGTH_SHORT).show();  
        } else {  
            Toast.makeText(context, "下载失败", Toast.LENGTH_SHORT).show();  
        }  
    }  
}
```



```java
DownlaodTask task = new DownloadTask();
//任务启动
task.execute("downloadUrl")；
//任务取消
task.cancel(true);
```

`execute(Params... params)`：必须在主线程中调用，表示开始一个异步任务。**一个AsyncTask只能调用一次该方法**。

`cancel(boolean mayInterruptIfRunning)`：必须在主线程中调用，表示停止一个异步任务。`mayInterruptIfRunning`表示是否立即停止任务，true立即停止，false则等待执行完毕。

### AsyncTask工作原理

#### 新建AsyncTask实例

必须要先新建一个AsyncTask实例，后续才可以去执行启动或停止等操作。

```java
 public AsyncTask() {
        this((Looper) null);
    }

 public AsyncTask(@Nullable Looper callbackLooper) {
        mHandler = callbackLooper == null || callbackLooper == Looper.getMainLooper()
            ? getMainHandler()
            : new Handler(callbackLooper);

        mWorker = new WorkerRunnable<Params, Result>() {
            public Result call() throws Exception {
                //表示当前任务已被调用
                mTaskInvoked.set(true);
                Result result = null;
                try {
                    //设置线程优先级为  后台线程
                    Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND);
                    //开始调用后台任务执行
                    result = doInBackground(mParams);
                    Binder.flushPendingCommands();
                } catch (Throwable tr) {
                    //出错取消任务
                    mCancelled.set(true);
                    throw tr;
                } finally {
                    //发送任务执行结果
                    postResult(result);
                }
                return result;
            }
        };
        //实现了 Runnable 和Future接口，因此可以包装 Runnble和 Callable
        mFuture = new FutureTask<Result>(mWorker) {
            @Override
            protected void done() {
                try {
                    postResultIfNotInvoked(get());
                } catch (InterruptedException e) {
                    android.util.Log.w(LOG_TAG, e);
                } catch (ExecutionException e) {
                    throw new RuntimeException("An error occurred while executing doInBackground()",
                            e.getCause());
                } catch (CancellationException e) {
                    postResultIfNotInvoked(null);
                }
            }
        };
    }
    
    //一个Callable对象
    private static abstract class WorkerRunnable<Params, Result> implements Callable<Result> {
        Params[] mParams;
    }
```

新建实例过程中，只是初始化了两个变量`mWorker，mFuture`。

#### 启动AsyncTask

新建实例完成后，就要开始启动任务去执行。

```java
    //标记主线程执行
    @MainThread
    //启动异步任务
    public final AsyncTask<Params, Progress, Result> execute(Params... params) {
        return executeOnExecutor(sDefaultExecutor, params);
    }

    @MainThread
    public final AsyncTask<Params, Progress, Result> executeOnExecutor(Executor exec,
            Params... params) {
        //如果在任务执行或结束时 重复调用执行 会出错
        if (mStatus != Status.PENDING) {
            switch (mStatus) {
                case RUNNING:
                    throw new IllegalStateException("Cannot execute task:"
                            + " the task is already running.");
                case FINISHED:
                    throw new IllegalStateException("Cannot execute task:"
                            + " the task has already been executed "
                            + "(a task can be executed only once)");
            }
        }
        //标记运行状态
        mStatus = Status.RUNNING;
        //异步开始前的准备
        onPreExecute();

        mWorker.mParams = params;
        //开始执行任务
        exec.execute(mFuture);

        return this;
    }
 
```

`exec`是传递的一个数据，它指向一个串行线程池。

```java
   public static final Executor SERIAL_EXECUTOR = new SerialExecutor();    
    private static volatile Executor sDefaultExecutor = SERIAL_EXECUTOR;
    //串行线程池
    private static class SerialExecutor implements Executor {
        final ArrayDeque<Runnable> mTasks = new ArrayDeque<Runnable>();
        Runnable mActive;

        public synchronized void execute(final Runnable r) {
            //FutureTask 插入 mTasks中
            mTasks.offer(new Runnable() {
                public void run() {
                    try {
                        r.run();
                    } finally {
                        scheduleNext();
                    }
                }
            });
            if (mActive == null) {
                scheduleNext();
            }
        }

        protected synchronized void scheduleNext() {
            if ((mActive = mTasks.poll()) != null) {
                THREAD_POOL_EXECUTOR.execute(mActive);
            }
        }
    }
```



```java
    private static class InternalHandler extends Handler {
        public InternalHandler(Looper looper) {
            super(looper);
        }

        @SuppressWarnings({"unchecked", "RawUseOfParameterizedType"})
        @Override
        public void handleMessage(Message msg) {
            AsyncTaskResult<?> result = (AsyncTaskResult<?>) msg.obj;
            switch (msg.what) {
                case MESSAGE_POST_RESULT:
                    // 通知任务结束 调用结束之后事件
                    result.mTask.finish(result.mData[0]);
                    break;
                case MESSAGE_POST_PROGRESS:
                    //通知进度更新
                    result.mTask.onProgressUpdate(result.mData);
                    break;
            }
        }
    }

```

**内部静态Handler**。负责将环境从线程池中切换到主线程；通过他来发送任务执行的进度以及执行结束等消息。

```java
    private static final int CPU_COUNT = Runtime.getRuntime().availableProcessors(); // CPU核数
    private static final int CORE_POOL_SIZE = Math.max(2, Math.min(CPU_COUNT - 1, 4));// 核数为2 核心线程数为 2
    private static final int MAXIMUM_POOL_SIZE = CPU_COUNT * 2 + 1;//核数为2 最大允许 5
    private static final int KEEP_ALIVE_SECONDS = 30;// 最多存活30s

    private static final ThreadFactory sThreadFactory = new ThreadFactory() {
        private final AtomicInteger mCount = new AtomicInteger(1);

        public Thread newThread(Runnable r) {
            return new Thread(r, "AsyncTask #" + mCount.getAndIncrement());
        }
    };

    private static final BlockingQueue<Runnable> sPoolWorkQueue =
            new LinkedBlockingQueue<Runnable>(128);

    /**
     * An {@link Executor} that can be used to execute tasks in parallel.
     */
    public static final Executor THREAD_POOL_EXECUTOR;

    static {
        ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(
                CORE_POOL_SIZE, MAXIMUM_POOL_SIZE, KEEP_ALIVE_SECONDS, TimeUnit.SECONDS,
                sPoolWorkQueue, sThreadFactory);
        threadPoolExecutor.allowCoreThreadTimeOut(true);
        THREAD_POOL_EXECUTOR = threadPoolExecutor;
    }

```

**真正执行异步任务的线程池。**



`AsyncTask`的任务都是串行执行的，如果需要并行执行，可以使用如下代码：

```java
task.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR,"");
```

还可以使用自己定义的线程池

```java

Executor exec = new ThreadPoolExecutor(15, 200, 10,
		TimeUnit.SECONDS, new LinkedBlockingQueue<Runnable>());
new DownloadTask().executeOnExecutor(exec);

```

## HandlerThread

> HandlerThread是一个线程类，它继承自Thread。
>
> 它比普通Thread多了**消息循环**效果。

```java
    @Override
    public void run() {
        mTid = Process.myTid();
        Looper.prepare();
        synchronized (this) {
            mLooper = Looper.myLooper();
            notifyAll();
        }
        Process.setThreadPriority(mPriority);
        onLooperPrepared();
        Looper.loop();
        mTid = -1;
    }
```

内部就已经实现了`Looper`，通过`Looper.prepare()`创建消息队列，通过`Looper.loop()`开启循环效果。

使用实例

```java
private HandlerThread myHandlerThread ;  
private Handler handler ;  
@Override  
protected void onCreate(Bundle savedInstanceState) {  
    super.onCreate(savedInstanceState);  
   setContentView(R.layout.activity_main);  
   //实例化HandlerThread
   myHandlerThread = new HandlerThread("myHandler") ;  
   //开启HandlerThread
   myHandlerThread.start();  
   //将Handler对象与HandlerThread线程绑定
   handler =new Handler(myHandlerThread.getLooper()){  
       @Override  
        publicvoid handleMessage(Message msg) {  
           super.handleMessage(msg);  
           // do something
        }  
    };  
   
   handler.sendEmptyMessage(1) ;  
   new Thread(new Runnable() {  
       @Override  
        publicvoid run() {  
           handler.sendEmptyMessage(2) ;  
        }  
    }).start();  
}  
@Override  
protected void onDestroy() {  
   super.onDestroy();  
   //终止HandlerThread运行
   myHandlerThread.quit() ;  //立马退出
  //myHandlerThread.quitSafely() //执行完毕后退出
}
```

主要用于在子线程中创建Handler时使用。

## IntentService

> 继承了Service并且是一个抽象类。
>
> IntentService可用于执行后台耗时任务，任务执行完毕后会自动停止，同时由于IntentService是服务的原因，优先级高于线程，更不容易被杀死。

#### 使用实例

```java
public class LocalIntentService extends Service{
  private static final String TAG = "LocalIntentService";
  
  public LocalIntentService(){
    super(TAG);
  }
  
  @Override
  protected void onHandleIntent(Intent intent){
    String action = intent.getExtras().getString("action");
    switch(action){
      case "action1":
        Log.i(TAG,"action1");
        break;
      default:
        break;
    }
  }
  
  @Override
  public void onCreate(){
    Log.i(TAG,"onCreate");
    super.onCreate();
  }
  
  @Override
  public void onStartCommand(Intent intent, int flags, int startId){
    Log.i(TAG,"onStartCommand");
    return super.onStartCommand(intent, flags, startId);
  }
  
  @Override
  public void onDestroy(){
    Log.i(TAG,"onDestroy");
    super.onDestroy();
  }
}
```

在AndroidManifest.xml 中注册

```java
<service android:name=".LocalIntentService">
            <intent-filter >
                <action android:name="com.wxy.service"/>
            </intent-filter>
        </service>
```

在Activity中使用

```java
Intent i = new Intent("com.wxy.service");
Bundle bundle = new Bundle();
bundle.putString("action","action1");
i.putExtras(bundle);
startService(i);
```

#### 源码分析

从IntentService启动开始

```java
 @Override
    public void onCreate() {

        super.onCreate();
        //利用HandlerThread创建线程并启动
        HandlerThread thread = new HandlerThread("IntentService[" + mName + "]");
        thread.start();
      
        mServiceLooper = thread.getLooper();
        //handler与handlerThread创建的Looper进行绑定
        mServiceHandler = new ServiceHandler(mServiceLooper);
    }

    private final class ServiceHandler extends Handler {
        public ServiceHandler(Looper looper) {
            super(looper);
        }

        @Override
        public void handleMessage(Message msg) {
            //获取的消息 交由 onHandleIntent 进行处理
            onHandleIntent((Intent)msg.obj);
            //消息处理完毕后 关闭Service
            stopSelf(msg.arg1);
        }
    }

    @WorkerThread
    protected abstract void onHandleIntent(@Nullable Intent intent);
```

上述源码完成了一次工作线程的创建。

```java

    @Override
    public void onStart(@Nullable Intent intent, int startId) {
        Message msg = mServiceHandler.obtainMessage();
        msg.arg1 = startId;
        msg.obj = intent;
        //把请求发送至消息队列中
        mServiceHandler.sendMessage(msg);
    }

    /**
     * You should not override this method for your IntentService. Instead,
     * override {@link #onHandleIntent}, which the system calls when the IntentService
     * receives a start request.
     * @see android.app.Service#onStartCommand
     */
    @Override
    public int onStartCommand(@Nullable Intent intent, int flags, int startId) {
        onStart(intent, startId);
        return mRedelivery ? START_REDELIVER_INTENT : START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        //退出循环 并清空消息
        mServiceLooper.quit();
    }
```

通过`onStartCommand()`将消息(`intent`)依次插入到消息队列中。

从源码中我们可以得知以下要点：

1. **工作任务是顺序执行的**

   由于每执行一个后台任务都必须去启动一次IntentSercvice，每启动一次都会想IntentService中的消息队列插入消息，也就只能按照顺序去执行后台任务。

2. **不建议通过`bindService()`启动IntentService**

   `bindService()`启动的Service不会触发`onStart()/onStartCommand()`执行，所以无法将消息插入到队列中，自然也无法执行任务。

{% fullimage /images/IntentService执行流程.png,IntentService执行流程,IntentService执行流程 %}