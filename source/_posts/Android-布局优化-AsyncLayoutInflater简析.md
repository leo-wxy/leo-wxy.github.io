---
title: Android布局优化-AsyncLayoutInflater简析
typora-root-url: ../
date: 2020-11-02 19:46:03
tags: Android
top: 9
---

![AsyncLayoutInflater](/images/AsyncLayoutInflater.png)

布局加载过程中存在两个耗时点：

1. 布局文件读取慢，涉及IO操作
2. 根据`<tag>`创建View慢(`createViewFromTag()`)，使用反射的方式创建View。*布局嵌套层数越多，控件个数越多，反射的次数就会越多*。

当XML文件过大、嵌套过深时，就会导致页面发生卡顿甚至ANR。

解决方案有两种：

1. **直接解决**：不使用IO操作以及反射
2. **侧面缓解**：把耗时操作放到子线程，等待加载完毕返回主线程展示即可。下面提到的`AsyncLayoutInflater`就是使用这个方案。

## AsyncLayoutInflater

采用**异步加载**的方式去加载布局，可以节省主线程时间，并且在异步加载完毕后回到主线程。

## 使用方法

```java
        new AsyncLayoutInflater(this).inflate(R.layout.XX, null, new AsyncLayoutInflater.OnInflateFinishedListener() {
            @Override
            public void onInflateFinished(@NonNull View view, int i, @Nullable ViewGroup viewGroup) {
                setContentView(view);
            }
        });
```

## 基本原理

### 构造方法

```java
public final class AsyncLayoutInflater {
    LayoutInflater mInflater;//布局加载器
    Handler mHandler;//处理加载完成消息
    InflateThread mInflateThread;//执行加载任务

     public AsyncLayoutInflater(@NonNull Context context) {
        mInflater = new BasicInflater(context);
        mHandler = new Handler(mHandlerCallback);
        mInflateThread = InflateThread.getInstance();
    }
}
```

#### BasicInflater

自定义加载器。实现类似`PhoneLayoutInflater(默认布局加载器)`

```java

    private static class BasicInflater extends LayoutInflater {
      //优先在这三个包下加载
        private static final String[] sClassPrefixList = {
            "android.widget.",
            "android.webkit.",
            "android.app."
        };

        BasicInflater(Context context) {
            super(context);
        }

        @Override
        public LayoutInflater cloneInContext(Context newContext) {
            return new BasicInflater(newContext);
        }

        @Override
        protected View onCreateView(String name, AttributeSet attrs) throws ClassNotFoundException {
            for (String prefix : sClassPrefixList) {
                try {
                  //加载View
                    View view = createView(name, prefix, attrs);
                    if (view != null) {
                        return view;
                    }
                } catch (ClassNotFoundException e) {
                    // In this case we want to let the base class take a crack
                    // at it.
                }
            }

            return super.onCreateView(name, attrs);
        }
    }
```



#### InflateThread

创建子线程，将`布局加载`请求加入`阻塞队列`中，按照插入顺序执行`LayoutInflater.inflate()`加载过程

```java
    private static class InflateThread extends Thread {
        private static final InflateThread sInstance;
        static {
            sInstance = new InflateThread();
            sInstance.start();
        }
      //阻塞队列 最多支持10个加载请求
        private ArrayBlockingQueue<InflateRequest> mQueue = new ArrayBlockingQueue<>(10);
      //对象池，缓存InflateThread对象
        private SynchronizedPool<InflateRequest> mRequestPool = new SynchronizedPool<>(10);    
      //对象池获取缓存对象
        public InflateRequest obtainRequest() {
            InflateRequest obj = mRequestPool.acquire();
            if (obj == null) {
                obj = new InflateRequest();
            }
            return obj;
        }
      //对象池回收对象，便于下次复用
        public void releaseRequest(InflateRequest obj) {
            obj.callback = null;
            obj.inflater = null;
            obj.parent = null;
            obj.resid = 0;
            obj.view = null;
            mRequestPool.release(obj);
        }      
      //将inflate请求添加到 阻塞队列中
        public void enqueue(InflateRequest request) {
            try {
                mQueue.put(request);
            } catch (InterruptedException e) {
                throw new RuntimeException(
                        "Failed to enqueue async inflate request", e);
            }
        }
      //需要执行的任务
        public void runInner() {
            InflateRequest request;
            try {
              //阻塞队列获取 任务，没任务则阻塞
                request = mQueue.take();
            } catch (InterruptedException ex) {
                // Odd, just continue
                Log.w(TAG, ex);
                return;
            }

            try {
              //调用BasicInflater去加载布局
                request.view = request.inflater.mInflater.inflate(
                        request.resid, request.parent, false);
            } catch (RuntimeException ex) {
                // Probably a Looper failure, retry on the UI thread
                Log.w(TAG, "Failed to inflate resource in the background! Retrying on the UI"
                        + " thread", ex);
            }
          //构建消息发送到Handler
            Message.obtain(request.inflater.mHandler, 0, request)
                    .sendToTarget();
        }

        @Override
        public void run() {
            while (true) {
                runInner();
            }
        }      
    }
```

`InflateThread`不管最后`inflate()`执行成功或失败，都会把结果发回到Handler进行处理。

```java
    private Handler.Callback mHandlerCallback = new Handler.Callback() {
        @Override
        public boolean handleMessage(Message msg) {
          //获取加载结果
            InflateRequest request = (InflateRequest) msg.obj;
            if (request.view == null) {
              //异步加载失败，在主线程进行加载过程
                request.view = mInflater.inflate(
                        request.resid, request.parent, false);
            }
          //加载完成回调
            request.callback.onInflateFinished(
                    request.view, request.resid, request.parent);
          //回收加载请求
            mInflateThread.releaseRequest(request);
            return true;
        }
    };
```

`Handler`收到消息后，根据`InflateRequest.view`是否为空，判断接下执行步骤：

如果为空，回到主线程进行布局加载任务，加载完成后回调`onInflateFinished()`

不为空，直接回调`onInflateFinished()`

### inflate()

发起异步加载布局请求

```java
    @UiThread
    public void inflate(@LayoutRes int resid, @Nullable ViewGroup parent,
            @NonNull OnInflateFinishedListener callback) {
        if (callback == null) {
            throw new NullPointerException("callback argument may not be null!");
        }
      //构建InflateRequest对象
        InflateRequest request = mInflateThread.obtainRequest();
        request.inflater = this;
        request.resid = resid;
        request.parent = parent;
        request.callback = callback;
      //插入加载请求到阻塞队列
        mInflateThread.enqueue(request);
    }
```

#### InflateRequest

主线程和子线程之间传递的数据模型，主要封装了`异步加载`需要的参数

```java
    private static class InflateRequest {
        AsyncLayoutInflater inflater;//加载器
        ViewGroup parent;//父布局
        int resid;//布局id
        View view;//加载完成的View
        OnInflateFinishedListener callback;//加载完成回调

        InflateRequest() {
        }
    }
```

#### OnInflateFinishedListener

布局加载完成后回调

```java
    public interface OnInflateFinishedListener {
        void onInflateFinished(@NonNull View view, //加载完成的View
                               @LayoutRes int resid,
                @Nullable ViewGroup parent);
    }
```



> 使用`AsyncLayoutInflater`加载布局后，将需要加载的`layoutId`以及`OnInflateFinishedListener`构造成`InflateRequest`，插入到`InflateThread`的阻塞队列中，等待执行。任务执行完毕后，返回执行结果(`成功返回加载后的View，失败返回null`)。
>
> 通过`Handler`发送结果回到主线程，返回结果为`null`，则在主线程再次执行`布局加载`，得到结果后直接回调`onInflateFinished()`。

## 局限及改进

### 局限

1. `AsyncLayoutInflater`构造的`View`，无法直接使用`handler`或者调用`looper.myLooper`，因为没有进行初始化
2. `AsyncLayoutInflater`构造的`View`，不会自动加到`parent`中，需要手动加入
3. `AsyncLayoutInflater`不支持设置`Factory/Factory2`，未设置`mPrivateFactory`所以不支持包含`<fragment>`的布局
4. 最多支持10个布局加载，超出的布局需要等待。



### 改进

> `AsyncLayoutInflater`是`final`的，无法被继承。需要`copy`一份代码进行修改。

针对`4`可以内部替换成线程池，将加载布局请求放入线程池管理

针对`3`可以修改`BasicInflater`实现，内部支持`factory`设置

```java
        BasicInflater(Context context) {
            super(context);
            if (context instanceof AppCompatActivity) {
                // 加上这些可以保证AppCompatActivity的情况下，super.onCreate之前
                // 使用AsyncLayoutInflater加载的布局也拥有默认的效果
                AppCompatDelegate appCompatDelegate = ((AppCompatActivity) context).getDelegate();
                if (appCompatDelegate instanceof LayoutInflater.Factory2) {
                    LayoutInflaterCompat.setFactory2(this, (LayoutInflater.Factory2) appCompatDelegate);
                }
            }
        }
```



## 参考链接

[AsyncLayoutInfalter](https://www.jianshu.com/p/8548db25a475)