---
title: Jetpack-LiveData简析
date: 2019-02-15 17:00:17
tags: 源码解析
top: 9
typora-root-url: ../
---

## LiveData简介

本质上是一个观察者模式，在Activity/Fragment中实现观察者，LiveData是被观察者，在LiveData存储的数据变更时触发事件。

LiveData还具有**生命周期感知**能力，可以控制在应用可见时去更新UI，不可见时不执行操作，减少了内存泄露问题。

## LiveData示例

一般情况下`LiveData`要配合着`ViewModel`一起使用，ViewModel负责触发数据更新，LiveData负责通知观察者数据更新。

引入LiveData三方库

```groovy
dependencies {
    def lifecycle_version = "2.0.0"
    implementation "androidx.lifecycle:lifecycle-livedata:$lifecycle_version"
    implementation "androidx.lifecycle:lifecycle-runtime:$lifecycle_version"
 }
```

新建ViewModel类并包含LiveData

```java
public class LiveDataViewModel extends ViewModel {

    private MutableLiveData<String> currentText;

    public MutableLiveData<String> getCurrentText() {
        if (currentText == null)
            return new MutableLiveData<>();
        return currentText;
    }
}
```

在Activity/Fragment中添加监听

```java
public class NewActivity extends AppCompatActivity {
    private LiveDataViewModel viewModel;
    private TextView textView;
    private Button button;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        textView = findViewById(R.id.text);
        button = findViewById(R.id.btn1);

        viewModel = ViewModelProviders.of(NewActivity.this).get(LiveDataViewModel.class);
        final Observer<String> testObserver = new Observer<String>() {
            @Override
            //监听回调
            public void onChanged(String s) {
                textView.setText(s);
            }
        };
        //注册监听
        viewModel.getCurrentText().observe(this, testObserver);
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                viewModel.getCurrentText().setValue("12" + System.currentTimeMillis());
            }
        });
    }
}
```

这样即可以实现监听功能。

想了解更多实例可参考[LiveData官方示例](<https://developer.android.google.cn/topic/libraries/architecture/livedata#java>)

## LiveData源码解析

### LiveData

```java
public abstract class LiveData<T> {
    ...
}
```

`LiveData`是一个抽象类无法直接使用，一般都是应用其子类`MutableLiveData`

```java
public class MutableLiveData<T> extends LiveData<T> {
    @Override
    public void postValue(T value) {
        super.postValue(value);
    }

    @Override
    public void setValue(T value) {
        super.setValue(value);
    }
}

```

`MutableLiveData`多了设置数据的方法，以便开发者对内容进行修改。若不想有人进行修改，可以返回`LiveData`保证安全。



### Observer

构建LiveData完毕后，需要对其添加监听。

```java
public interface Observer<T> {
    /**
     * Called when the data is changed.
     * @param t  The new data
     */
    void onChanged(T t);
}
```

`Observer`只提供数据变化的监听并返回修改后的结果。

```java LiveData.java
private SafeIterableMap<Observer<? super T>, ObserverWrapper> mObservers =
            new SafeIterableMap<>();   

@MainThread
    public void observe(@NonNull LifecycleOwner owner, @NonNull Observer<? super T> observer) {
        //监测是否在主线程操作
        assertMainThread("observe");
        // Activity/Frgment已被销毁就无需添加监听
        if (owner.getLifecycle().getCurrentState() == DESTROYED) {
            // ignore
            return;
        }
        //关键点
        LifecycleBoundObserver wrapper = new LifecycleBoundObserver(owner, observer);
        //取出对应的Observer
        ObserverWrapper existing = mObservers.putIfAbsent(observer, wrapper);
        if (existing != null && !existing.isAttachedTo(owner)) {
            throw new IllegalArgumentException("Cannot add the same observer"
                    + " with different lifecycles");
        }
        //已存在就无需重复添加
        if (existing != null) {
            return;
        }
        //添加对应监听 而且只在UI可见时会有回调
        owner.getLifecycle().addObserver(wrapper);
    }

    //支持监听永久存在，不会因为Activity/Fragment销毁而消失
    @MainThread
    public void observeForever(@NonNull Observer<? super T> observer) {
        assertMainThread("observeForever");
        AlwaysActiveObserver wrapper = new AlwaysActiveObserver(observer);
        ObserverWrapper existing = mObservers.putIfAbsent(observer, wrapper);
        if (existing != null && existing instanceof LiveData.LifecycleBoundObserver) {
            throw new IllegalArgumentException("Cannot add the same observer"
                    + " with different lifecycles");
        }
        if (existing != null) {
            return;
        }
        //无需理会 宿主状态
        wrapper.activeStateChanged(true);
    }
```

- 当宿主组件已经Destroy时，就无需添加监听
- 需要新建一个`LifecycleBoundObserver`保存`owner以及observer`
- 从`mObservers.putIfAbsent()`中去获取或者插入对应observer
- 返回为null，则对`owner`添加该监听。

### LifecycleBoundObserver

```java LiveData.java
    //LiveData激活时回掉
    protected void onActive() {}
    //LiveData销毁时回掉
    protected void onInactive() {}

    private abstract class ObserverWrapper {
        final Observer<? super T> mObserver;
        boolean mActive;
        int mLastVersion = START_VERSION;

        ObserverWrapper(Observer<? super T> observer) {
            mObserver = observer;
        }

        abstract boolean shouldBeActive();

        boolean isAttachedTo(LifecycleOwner owner) {
            return false;
        }

        void detachObserver() {
        }

        void activeStateChanged(boolean newActive) {
            if (newActive == mActive) {
                return;
            }
            // immediately set active state, so we'd never dispatch anything to inactive
            // owner
            mActive = newActive;
            //mActiveCount 表示当前处于active的observer数量
            boolean wasInactive = LiveData.this.mActiveCount == 0;
            LiveData.this.mActiveCount += mActive ? 1 : -1;
            if (wasInactive && mActive) {
                onActive();
            }
            //激活数量为0  说明都被销毁
            if (LiveData.this.mActiveCount == 0 && !mActive) {
                onInactive();
            }
            if (mActive) {
                //分发数据
                dispatchingValue(this);
            }
        }
    }

    //绑定了生命周期
    class LifecycleBoundObserver extends ObserverWrapper implements GenericLifecycleObserver {
        @NonNull
        final LifecycleOwner mOwner;

        LifecycleBoundObserver(@NonNull LifecycleOwner owner, Observer<? super T> observer) {
            super(observer);
            mOwner = owner;
        }

        @Override
        boolean shouldBeActive() {
            //至少是用户可见状态即 onStart() ~ onStop()
            return mOwner.getLifecycle().getCurrentState().isAtLeast(STARTED);
        }

        @Override
        public void onStateChanged(LifecycleOwner source, Lifecycle.Event event) {
            if (mOwner.getLifecycle().getCurrentState() == DESTROYED) {
                //处于销毁态时 及时移除监听防止内存泄露
                removeObserver(mObserver);
                return;
            }
            activeStateChanged(shouldBeActive());
        }

        @Override
        boolean isAttachedTo(LifecycleOwner owner) {
            return mOwner == owner;
        }

        @Override
        void detachObserver() {
            mOwner.getLifecycle().removeObserver(this);
        }
    }
```

### 发布修改

设置数据完毕后，需要通知到监听者进行响应

```java LiveData.java
public abstract class LiveData<T> {

    // 同步修改数据
    protected void setValue(T value);

    // 会用 Handler post 一个 runnable，然后在 runnable 里面 setValue
    protected void postValue(T value);
}
```

`postValue()及setValue()`都是`protected`只有本身及子类才可以调用，又由于`LiveData`为`abstract`不可用`new `即使用子类才可以修改数据。

#### setValue()：同步调用

```java 
	private volatile Object mData = NOT_SET;    
	//需要执行在主线程
    @MainThread
    protected void setValue(T value) {
        //监测是否运行在主线程
        assertMainThread("setValue");
        //每修改一次数据，就添加一次版本号
        mVersion++;
        //即将发送的数据
        mData = value;
        dispatchingValue(null);
    }

	void dispatchingValue(@Nullable ObserverWrapper initiator) {
        if (mDispatchingValue) {
            //在onChanged的回调中 再次调用 setValue()时触发
            //final Observer<String> testObserver = new Observer<String>() {
            //@Override
            //public void onChanged(String s) {
            //    textView.setText(s);
            //    viewModel.getCurrentText().setValue("12" + System.currentTimeMillis());
            //}
            //};
            mDispatchInvalidated = true;
            return;
        }
        //为了防止循环调用
        mDispatchingValue = true;
        do {
            mDispatchInvalidated = false;
            if (initiator != null) {
                considerNotify(initiator);
                initiator = null;
            } else {
                for (Iterator<Map.Entry<Observer<? super T>, ObserverWrapper>> iterator =
                        mObservers.iteratorWithAdditions(); iterator.hasNext(); ) {
                    //回调到对应方法
                    considerNotify(iterator.next().getValue());
                    if (mDispatchInvalidated) {
                        break;
                    }
                }
            }
        } while (mDispatchInvalidated);
        mDispatchingValue = false;
    }	

    //该方法可能在生命周期发送变更时被多次调用 但是数据却没有变化
    private void considerNotify(ObserverWrapper observer) {
        if (!observer.mActive) {
            return;
        }
        // Check latest state b4 dispatch. Maybe it changed state but we didn't get the event yet.
        //
        // we still first check observer.active to keep it as the entrance for events. So even if
        // the observer moved to an active state, if we've not received that event, we better not
        // notify for a more predictable notification order.
        if (!observer.shouldBeActive()) {
            observer.activeStateChanged(false);
            return;
        }
        //判定当前的分发是否有setValue()触发 利用mVersion 
        if (observer.mLastVersion >= mVersion) {
            return;
        }
        //重置成当前记录的mVersion
        observer.mLastVersion = mVersion;
        //回调到设置的 onChanged()
        observer.mObserver.onChanged((T) mData);
    }
```

##### 源码简述

调用`setValue()`：

- 先监测当前是否在主线程运行，否则抛出异常结束运行
- 设置当前存储的`mVersion+1`，以待后用
- 调用`dispatchValue()`进行数据分发
- 首先判断当前是否存在循环调用，在`dispatchValue()`中设置`mDispatchingValue`为true，操作结束完毕再设置false。还有一个`mDispatchInvalidated`标志位，如果该标志为true，表明已经发生了循环调用，需要重新开始。
- `considerNotify()`将消息发送到对应的观察者上，需要判定当前是否是因为调用`setValue()`导致的分发，因为在UI不可见时也不会调用分发，只有可见时才会调用，就可能导致重复分发，需要使用到`mVersion`来进行一次判定，如果小于记录的`mVersion`。即进行分发结束一次分发过程。

> 当Activity/Fragment挂在后台时，LiveData不会分发数据，`setValue()`的值就会被缓存到`mData`中，但是只能缓存一个值，所以当再次回到前台时，最终打到的就是最新的一次`setValue()`的数据。

#### postValue()：异步调用

```java
    // 使用volatile进行修饰，因为mPendingData 可能被其他线程进行修改
    private volatile Object mPendingData = NOT_SET;

    private final Runnable mPostValueRunnable = new Runnable() {
        @Override
        public void run() {
            Object newValue;
            synchronized (mDataLock) {
                newValue = mPendingData;
                mPendingData = NOT_SET;
            }
            //本质还是调用到了setValue()
            setValue((T) newValue);
        }
    };    

    protected void postValue(T value) {
        boolean postTask;
        synchronized (mDataLock) {
            postTask = mPendingData == NOT_SET;
            mPendingData = value;
        }
        //表明此时已有Runnable在执行，无需重复执行
        if (!postTask) {
            return;
        }
        //切换到主线程
        ArchTaskExecutor.getInstance().postToMainThread(mPostValueRunnable);
    }

```

`postValue()`利用`ArchTaskExecutor`将发送消息逻辑切换到主线程上，实质执行的还是`setValue()`。

```java
public class ArchTaskExecutor extends TaskExecutor {
    private static volatile ArchTaskExecutor sInstance;
    
    @NonNull
    private TaskExecutor mDefaultTaskExecutor;
    
    private ArchTaskExecutor() {
        mDefaultTaskExecutor = new DefaultTaskExecutor();
        mDelegate = mDefaultTaskExecutor;
    }
    
    @Override
    public void postToMainThread(Runnable runnable) {
        mDelegate.postToMainThread(runnable);
    }
}
```

`archTaskExecutor`实质调用的是`DefaultTaskExecutor`去执行切换主线程任务

```java DefaultTAskExecutor.java
    @Override
    public void postToMainThread(Runnable runnable) {
        if (mMainHandler == null) {
            synchronized (mLock) {
                if (mMainHandler == null) {
                    //获取主线程Looper 并生成对应Handler
                    mMainHandler = new Handler(Looper.getMainLooper());
                }
            }
        }
        //noinspection ConstantConditions
        mMainHandler.post(runnable);
    }
```

通过`Handler`进行了主线程切换。

##### 源码简述

`postValue()`调用过程：

- 先根据`mPendingData`的值判定是否需要执行任务，当已有任务在执行时，不需要重复执行
- 调用`ArchArchTaskExecutor`实质调用了`DefaultTaskExecutor`去执行`postToMainThread()`
- 本质通过`Handler`进行了线程切换任务
- 最后切换主线程完毕后，去调用`setValue()`发送数据



## LiveData拓展

1. 根据源码分析，LiveData的数据接受的生命周期只在`onStart()`-> `onPause()`中，其他时间无法分发消息，只有等到回到用户可见时重新开始分发过程。
2. `LiveData`是通过`Lifecycle`与Activity/Fragment进行生命周期绑定的。
3. 由于`LiveData`是与生命周期进行绑定的，即使宿主被销毁，也不会造成内存泄露。



## 内容引用

[Jekton-LiveData](<https://jekton.github.io/2018/07/14/android-arch-LiveData/>)

[LiveData的工作原理](<https://juejin.im/post/5baee5205188255c930dea8a>)