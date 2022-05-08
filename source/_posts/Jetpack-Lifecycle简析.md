---
title: Jetpack-Lifecycle简析
date: 2019-02-15 17:01:05
tags: 源码解析
top: 9
typora-root-url: ../
---

![Lifecycle原理分析](/images/Lifecycle原理分析.png)

## Lifecycle简介

Google官方提供的一个**生命周期感知组件**。可以由引用组件自己进行生命周期管理，从而减少内存泄露以及异常的可能性。

**让我们自己创建的对象也可以感知到Android组件的生命周期。**

核心设计模式**观察者模式**。

## Lifecycle使用示例

先构建需要监听生命周期的组件

```java
public class LifeCycleComponent implements LifecycleObserver {
    @OnLifecycleEvent(Lifecycle.Event.ON_CREATE)
    void onCreate(){

    }

    @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    void onPause(){

    }
}
```

在Activity/Fragment中引用该组件并绑定生命周期

```java
public class NewActivity extends AppCompatActivity {
   protected void onCreate(@Nullable Bundle savedInstanceState) {
   		super.onCreate(savedInstanceState);
        getLifecycle().addObserver(new LifeCycleComponent());
   }
}
```

更多使用示例可参考[官方Lifecycle示例](<https://developer.android.google.cn/topic/libraries/architecture/lifecycle#codelabs>)

## Lifecycle源码解析

![源码解析](/images/Lifecycle-源码解析.png)

### LifecycleObserver 

![Lifecycle-LifecycleObserver](/images/Lifecycle-LifecycleObserver.png)

> 属于观察者模式的**观察者**，负责接受生命周期事件。需要监听生命周期的组件都需要实现该接口。

```java LifecycleObserver.java
/**
 * Marks a class as a LifecycleObserver. It does not have any methods, instead, relies on
 * {@link OnLifecycleEvent} annotated methods.
 */
public interface LifecycleObserver {

}
```

内部未提供任何方法，需要监听生命周期的话就采用`OnLifecycleEvent`去实现

```java
//运行时注解
@Retention(RetentionPolicy.RUNTIME)
//只支持注解方法
@Target(ElementType.METHOD)
public @interface OnLifecycleEvent {
    Lifecycle.Event value();
}
```

至此定义完成了需要取得监听结果的对象以及需要监听的生命周期

### Lifecycle

![Lifecycle-Lifecycle](/images/Lifecycle-Lifecycle.png)

> 属于观察者模式中的**被观察者**，负责接受生命周期监听事件，并分发到观察者`LifecycleObserver`中。

```java Lifecycle.java
public abstract class Lifecycle {
    //添加观察者
    @MainThread
    public abstract void addObserver(@NonNull LifecycleObserver observer);
    //移除观察者
    @MainThread
    public abstract void removeObserver(@NonNull LifecycleObserver observer);
    //获取当前生命周期状态
    @MainThread
    @NonNull
    public abstract State getCurrentState();

    public enum Event {
        /**
         * Constant for onCreate event of the {@link LifecycleOwner}.
         */
        ON_CREATE,
        /**
         * Constant for onStart event of the {@link LifecycleOwner}.
         */
        ON_START,
        /**
         * Constant for onResume event of the {@link LifecycleOwner}.
         */
        ON_RESUME,
        /**
         * Constant for onPause event of the {@link LifecycleOwner}.
         */
        ON_PAUSE,
        /**
         * Constant for onStop event of the {@link LifecycleOwner}.
         */
        ON_STOP,
        /**
         * Constant for onDestroy event of the {@link LifecycleOwner}.
         */
        ON_DESTROY,
        /**
         * An {@link Event Event} constant that can be used to match all events.
         */
        ON_ANY
    }

    /**
     * Lifecycle states. You can consider the states as the nodes in a graph and
     * {@link Event}s as the edges between these nodes.
     */
    public enum State {
        /**
         * Destroyed state for a LifecycleOwner. After this event, this Lifecycle will not dispatch
         * any more events. For instance, for an {@link android.app.Activity}, this state is reached
         * <b>right before</b> Activity's {@link android.app.Activity#onDestroy() onDestroy} call.
         */
        DESTROYED,

        /**
         * Initialized state for a LifecycleOwner. For an {@link android.app.Activity}, this is
         * the state when it is constructed but has not received
         * {@link android.app.Activity#onCreate(android.os.Bundle) onCreate} yet.
         */
        INITIALIZED,

        /**
         * Created state for a LifecycleOwner. For an {@link android.app.Activity}, this state
         * is reached in two cases:
         * <ul>
         *     <li>after {@link android.app.Activity#onCreate(android.os.Bundle) onCreate} call;
         *     <li><b>right before</b> {@link android.app.Activity#onStop() onStop} call.
         * </ul>
         */
        CREATED,

        /**
         * Started state for a LifecycleOwner. For an {@link android.app.Activity}, this state
         * is reached in two cases:
         * <ul>
         *     <li>after {@link android.app.Activity#onStart() onStart} call;
         *     <li><b>right before</b> {@link android.app.Activity#onPause() onPause} call.
         * </ul>
         */
        STARTED,

        /**
         * Resumed state for a LifecycleOwner. For an {@link android.app.Activity}, this state
         * is reached after {@link android.app.Activity#onResume() onResume} is called.
         */
        RESUMED;

        /**
         * Compares if this State is greater or equal to the given {@code state}.
         *
         * @param state State to compare with
         * @return true if this State is greater or equal to the given {@code state}
         */
        public boolean isAtLeast(@NonNull State state) {
            return compareTo(state) >= 0;
        }
    }
}
```





![生命周期状态示意图](/images/lifecycle-states.svg)

### LifecycleOwner

![Lifecycle-LifecycleOwner](/images/Lifecycle-LifecycleOwner.png)

定义好自定义组件后就需要将其与Activity/Fragment进行绑定。此时就需要去获取其内部的`lifecycle`对象

```java
public interface LifecycleOwner {
    Lifecycle getLifecycle();
}
```

`LifecycleOwner`只提供一个`getLifecycle()`获取`lifecycle`对象。

在Activity/Fragment中，可以直接调用到`getLifecycle()`进行获取

```java 
public class FragmentActivity extends ComponentActivity implements
    ViewModelStoreOwner{
    ...
}

public class ComponentActivity extends Activity
        implements LifecycleOwner, KeyEventDispatcher.Component {
    ...
    private LifecycleRegistry mLifecycleRegistry = new LifecycleRegistry(this);
    ...
    @Override
    public Lifecycle getLifecycle() {
        return mLifecycleRegistry;
    }
}
```

```java
public class Fragment implements ComponentCallbacks, OnCreateContextMenuListener, LifecycleOwner,
ViewModelStoreOwner {
    ...
    LifecycleRegistry mLifecycleRegistry = new LifecycleRegistry(this);
    ...
    @Override
    public Lifecycle getLifecycle() {
        return mLifecycleRegistry;
    }
}
```

在`FragmentActivity`及`Fragment`中都已默认实现了`LifecycleOwner`接口，就无需开发者自己实现。

### LifecycleRegistry

![Lifecycle-LifecycleRegistry](/images/Lifecycle-LifecycleRegistry.png)

> Lifecycle抽象类的唯一核心功能实现类，由它实现了生命周期绑定及添加/移除监听功能。

```java
public class LifecycleRegistry extends Lifecycle {
  //观察者集合
    private FastSafeIterableMap<LifecycleObserver, ObserverWithState> mObserverMap =
            new FastSafeIterableMap<>();
  //当前lifecycle状态
    private State mState;
  //弱引用包住 lifecycleOwner ，避免发生内存泄漏
    private final WeakReference<LifecycleOwner> mLifecycleOwner;
  
  ...
}
```





![四个类的关系](/images/Lifecycle四个类的关系.jpg)



### 关键流程分析

先分析在Activity/Fragment中是如何使用`LifecycleRegistry`，后续分析功能实现。

![Lifecycle-关键流程分析](/images/Lifecycle-关键流程分析.png)

#### Fragment绑定

![Fragment绑定](/images/Lifecycle-Fragment绑定流程.png)

```java
public class Fragment implements ComponentCallbacks, OnCreateContextMenuListener, LifecycleOwner,
        ViewModelStoreOwner {
    ...
    LifecycleRegistry mLifecycleRegistry = new LifecycleRegistry(this);
    ...
    @Override
    public Lifecycle getLifecycle() {
        return mLifecycleRegistry;
    }
            
    ...
    void performCreate(Bundle savedInstanceState) {
        if (mChildFragmentManager != null) {
            mChildFragmentManager.noteStateNotSaved();
        }
        //标记当前Lifecycle.State为CREATED
        mState = CREATED;
        mCalled = false;
        onCreate(savedInstanceState);
        mIsCreated = true;
        //回调 ON_CREATE
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE);
    }
            
    void performStart() {
        mState = STARTED;
        mCalled = false;
        onStart();
        if (mChildFragmentManager != null) {
            mChildFragmentManager.dispatchStart();
        }
        //回调ON_START
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START);
        if (mView != null) {
            mViewLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START);
        }
    }        
}
```

`Fragment`通过`LifecycleRegistry.handleLifecycleEvent()`进行了生命周期绑定。

#### Activity绑定

![Lifecycle-Activity绑定流程](/images/Lifecycle-Activity绑定流程.png)

```java
public class ComponentActivity extends Activity
        implements LifecycleOwner, KeyEventDispatcher.Component {
        ...
    private LifecycleRegistry mLifecycleRegistry = new LifecycleRegistry(this);
        @Override
    @SuppressWarnings("RestrictedApi")
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ReportFragment.injectIfNeededIn(this);
    }

    @CallSuper
    @Override
    protected void onSaveInstanceState(Bundle outState) {
        mLifecycleRegistry.markState(Lifecycle.State.CREATED);
        super.onSaveInstanceState(outState);
    }
    ...
}
```

如果绑定在Activity上，就需要通过动态添加一个`ReportFragment`去绑定生命周期

```java ReportFragment.java
public class ReportFragment extends Fragment {
public static void injectIfNeededIn(Activity activity) {
        // ProcessLifecycleOwner should always correctly work and some activities may not extend
        // FragmentActivity from support lib, so we use framework fragments for activities
        android.app.FragmentManager manager = activity.getFragmentManager();
        //创建自身并加入宿主Activity
        if (manager.findFragmentByTag(REPORT_FRAGMENT_TAG) == null) {
            manager.beginTransaction().add(new ReportFragment(), REPORT_FRAGMENT_TAG).commit();
            // Hopefully, we are the first to make a transaction.
            manager.executePendingTransactions();
        }
    }

    static ReportFragment get(Activity activity) {
        //获取自身实例
        return (ReportFragment) activity.getFragmentManager().findFragmentByTag(
                REPORT_FRAGMENT_TAG);
    }
    
    @Override
    public void onActivityCreated(Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);
        dispatchCreate(mProcessListener);
        //分发ON_CREATE事件
        dispatch(Lifecycle.Event.ON_CREATE);
    }

    @Override
    public void onStart() {
        super.onStart();
        dispatchStart(mProcessListener);
        //分发ON_START事件
        dispatch(Lifecycle.Event.ON_START);
    }
    
    private void dispatch(Lifecycle.Event event) {
        Activity activity = getActivity();
        if (activity instanceof LifecycleRegistryOwner) {
            ((LifecycleRegistryOwner) activity).getLifecycle().handleLifecycleEvent(event);
            return;
        }
        //指代了 ComponentActivity
        if (activity instanceof LifecycleOwner) {
            Lifecycle lifecycle = ((LifecycleOwner) activity).getLifecycle();
            if (lifecycle instanceof LifecycleRegistry) {
                ((LifecycleRegistry) lifecycle).handleLifecycleEvent(event);
            }
        }
    }
}
```

Activity的生命周期监听需要依赖动态添加进的`ReportFragment`的生命周期进行回调。



#### 注册/注销观察者

![Lifecycle-注册监听流程](/images/Lifecycle-注册监听流程.png)

通过`addObserver()/removeObserver()`控制观察者的添加与移除

```java
 @Override
    public void addObserver(@NonNull LifecycleObserver observer) {
        //计算初始状态 默认初始状态是 INITALIZED
        State initialState = mState == DESTROYED ? DESTROYED : INITIALIZED;
        //封装ObserverWithState状态
        ObserverWithState statefulObserver = new ObserverWithState(observer, initialState);
        //从缓存中获取 observer这个key对应的值
        ObserverWithState previous = mObserverMap.putIfAbsent(observer, statefulObserver);
        //防止重复加入
        if (previous != null) {
            return;
        }
        LifecycleOwner lifecycleOwner = mLifecycleOwner.get();
        if (lifecycleOwner == null) {
            // it is null we should be destroyed. Fallback quickly
            return;
        }

        boolean isReentrance = mAddingObserverCounter != 0 || mHandlingEvent;
        //计算当前lifecycle的状态
        State targetState = calculateTargetState(observer);
        mAddingObserverCounter++;
        while ((statefulObserver.mState.compareTo(targetState) < 0
                && mObserverMap.contains(observer))) {
            pushParentState(statefulObserver.mState);
          //分发Event
            statefulObserver.dispatchEvent(lifecycleOwner, upEvent(statefulObserver.mState));
          //删除自身状态
            popParentState();
            // 在回调时可能用户操作导致发生变化
            targetState = calculateTargetState(observer);
        }
        //是否重入，
        if (!isReentrance) {
            // we do sync only on the top level.
            sync();
        }
        mAddingObserverCounter--;
    }

    private State calculateTargetState(LifecycleObserver observer) {
        Entry<LifecycleObserver, ObserverWithState> previous = mObserverMap.ceil(observer);

        State siblingState = previous != null ? previous.getValue().mState : null;
        State parentState = !mParentStates.isEmpty() ? mParentStates.get(mParentStates.size() - 1)
                : null;
        // 返回最小的 state
        return min(min(mState, siblingState), parentState);
    }


static class ObserverWithState {
    //保存当前Observer的状态
    State mState;
    //源Observer的包装类
    GenericLifecycleObserver mLifecycleObserver;

    ObserverWithState(LifecycleObserver observer, State initialState) {
        //生成一个原Observer的包装类
        mLifecycleObserver = Lifecycling.getCallback(observer);
        mState = initialState;
    }
    //该方法将生命周期事件分发到LifecycleObserver中
    void dispatchEvent(LifecycleOwner owner, Event event) {
        State newState = getStateAfter(event);
        mState = min(mState, newState);
        //调用包装类的onStateChanged方法，传递生命周期事件到Observer中
        mLifecycleObserver.onStateChanged(owner, event);
        mState = newState;
    }
}
```

`addObserver()`主要执行以下几步：

1. 封装`ObserverWithState`类型，包括`State`和`LifecycleObserver`
2. 判断`isReentrance`，表示`是否重入`，理解为*当前是否有执行`addObserver()`或有其他Event在处理*
3. 执行`while循环`负责**对齐观察者和宿主的生命周期**，将`observer`的`State`对齐`LifecycleOwner`的`State`。(例如在`onPause()`注册的`LifecycleOwner`，可以在注册的时候，立刻回调到`ON_CREATE`事件。)——**建议在`onCreate()`调用`addObserver()`**
4. 若`isReentrance==false`，继续向下执行`sync()`



#### 生命周期事件的分发

![Lifecycle-事件分发流程](/images/Lifecycle-事件分发流程.png)

观察上述源码发现，每触发一个生命周期都会响应到`LifecycleRegistry.handleLifecycleEvent()`

```java LifecycleRegistry.java
    public void handleLifecycleEvent(@NonNull Lifecycle.Event event) {
        //根据当前收到的生命周期状态获取事件发生后的后续状态
        State next = getStateAfter(event);
        moveToState(next);
    }

    private void moveToState(State next) {
        if (mState == next) {
            return;
        }
        mState = next;
        //处于未同步状态则返回
        if (mHandlingEvent || mAddingObserverCounter != 0) {
            mNewEventOccurred = true;
            // we will figure out what to do on upper level.
            return;
        }
        mHandlingEvent = true;
        //执行同步方法，把所有的State转成Event
        sync();
        mHandlingEvent = false;
    }

    static State getStateAfter(Event event) {
        switch (event) {
            case ON_CREATE:
            case ON_STOP:
                return CREATED;
            case ON_START:
            case ON_PAUSE:
                return STARTED;
            case ON_RESUME:
                return RESUMED;
            case ON_DESTROY:
                return DESTROYED;
            case ON_ANY:
                break;
        }
        throw new IllegalArgumentException("Unexpected event value " + event);
    }
```

`handleLifecycleEvent()`主要执行以下几步：

1. 通过`getStateAfter()`将传进来的`Event`转化为`State`
2. 再通过`moveToState()`调用到`sync()`同步状态



#### 同步状态——`sync()`

![Lifecycle-同步状态流程](/images/Lifecycle-同步状态流程.png)

设置状态完毕后需要同步所有的状态(`Status`)。

```java
    //Lifecycle自定义的数据结构，类似HashMap
    private FastSafeIterableMap<LifecycleObserver, ObserverWithState> mObserverMap =
            new FastSafeIterableMap<>();


    // happens only on the top of stack (never in reentrance),
    // so it doesn't have to take in account parents
    private void sync() {
        LifecycleOwner lifecycleOwner = mLifecycleOwner.get();
        if (lifecycleOwner == null) {
            Log.w(LOG_TAG, "LifecycleOwner is garbage collected, you shouldn't try dispatch "
                    + "new events from it.");
            return;
        }
        while (!isSynced()) {
            // mNewEventOccurred 是为了在 observer 触发状态变化时让 backwardPass/forwardPass()
            // 提前返回用的。我们刚准备调他们，这里设置为 false 即可。
            mNewEventOccurred = false;
            // no need to check eldest for nullability, because isSynced does it for us.
            if (mState.compareTo(mObserverMap.eldest().getValue().mState) < 0) {
                // mObserverMap 里的元素的状态是非递增排列的，也就是说，队头的 state 最大
                // 如果 mState 小于队列里最大的那个，说明有元素需要更新状态
                // 为了维持 mObserverMap 的 Invariant，这里我们需要从队尾往前更新元素的状态
                backwardPass(lifecycleOwner);
            }
            Entry<LifecycleObserver, ObserverWithState> newest = mObserverMap.newest();
            // 如果 mNewEventOccurred，说明在上面调用 backwardPass() 时，客户触发了状态修改
            if (!mNewEventOccurred && newest != null
                    && mState.compareTo(newest.getValue().mState) > 0) {
                forwardPass(lifecycleOwner);
            }
        }
        mNewEventOccurred = false;
    }

    // 如果所有的 observer 的状态都已经同步完，则返回 true
    private boolean isSynced() {
        if (mObserverMap.size() == 0) {
            return true;
        }
        //获取最大状态
        State eldestObserverState = mObserverMap.eldest().getValue().mState;
        //获取最小状态
        State newestObserverState = mObserverMap.newest().getValue().mState;
        // 因为我们保证队头的 state >= 后面的元素的 state，所以只要判断头尾就够了
        return eldestObserverState == newestObserverState && mState == newestObserverState;
    }

```

`sync()`时发现状态不一致，就需要进行向前或向后的变化。



使用当前Lifecycle的`mState`和`mObserverMap`的最大值进行比较，如果当前`mState`较小，需要进行递减状态`backwardPass()`

使用当前Lifecycle的`mState`和`mObserverMap`的最小值进行比较，如果当前`mState`较大，需要进行递增状态`forwardPass()`

```java
private ArrayList<State> mParentStates = new ArrayList<>();


    private void forwardPass(LifecycleOwner lifecycleOwner) {
        // 从队头开始迭代
        Iterator<Entry<LifecycleObserver, ObserverWithState>> ascendingIterator =
                mObserverMap.iteratorWithAdditions();
        while (ascendingIterator.hasNext() && !mNewEventOccurred) {
            Entry<LifecycleObserver, ObserverWithState> entry = ascendingIterator.next();
            ObserverWithState observer = entry.getValue();
            //当前observer的state值小于mState，则需递增当前状态到mState
            while ((observer.mState.compareTo(mState) < 0 && !mNewEventOccurred
                    // 可能在回调客户代码的时候，客户把自己移除了
                    && mObserverMap.contains(entry.getKey()))) {
                pushParentState(observer.mState);
                //递增其状态
                observer.dispatchEvent(lifecycleOwner, upEvent(observer.mState));
                popParentState();
            }
        }
    }

    private void backwardPass(LifecycleOwner lifecycleOwner) {
        // 从队尾开始迭代
        Iterator<Entry<LifecycleObserver, ObserverWithState>> descendingIterator =
                mObserverMap.descendingIterator();
        while (descendingIterator.hasNext() && !mNewEventOccurred) {
            Entry<LifecycleObserver, ObserverWithState> entry = descendingIterator.next();
            ObserverWithState observer = entry.getValue();
            //当前observer的state值大于mState，则需递减当前状态到mState
            while ((observer.mState.compareTo(mState) > 0 && !mNewEventOccurred
                    && mObserverMap.contains(entry.getKey()))) {
                //递减其状态
                Event event = downEvent(observer.mState);
                pushParentState(getStateAfter(event));
                observer.dispatchEvent(lifecycleOwner, event);
                popParentState();
            }
        }
    }

    private void popParentState() {
        mParentStates.remove(mParentStates.size() - 1);
    }

    private void pushParentState(State state) {
        mParentStates.add(state);
    }

    private static Event downEvent(State state) {
        switch (state) {
            case INITIALIZED:
                throw new IllegalArgumentException();
            case CREATED:
                return ON_DESTROY;
            case STARTED:
                return ON_STOP;
            case RESUMED:
                return ON_PAUSE;
            case DESTROYED:
                throw new IllegalArgumentException();
        }
        throw new IllegalArgumentException("Unexpected state value " + state);
    }

    private static Event upEvent(State state) {
        switch (state) {
            case INITIALIZED:
            case DESTROYED:
                return ON_CREATE;
            case CREATED:
                return ON_START;
            case STARTED:
                return ON_RESUME;
            case RESUMED:
                throw new IllegalArgumentException();
        }
        throw new IllegalArgumentException("Unexpected state value " + state);
    }
```

`forwardPass()`首先获取一个`mObserverMap`的迭代器，然后遍历每一子元素，递增其状态并通过`dispatchEvent()`分发事件，直到状态递增到`mState`为止。

假设`mObserverMap`中的所有都处于`CREATED`状态，当收到一个`ON_START`事件时，表示需要进入`STARTED`状态，由于`STARTED`较大，需要进行`forwardPass()`来递增`mObserverMap`中的状态，其内部调用到`upEvent()`升至了`STARTED`，再发送出去，外部接受到的就是`ON_START`事件。

![upEvent/downEvent](/images/upEvent-downEvent.jpg)



### 总结

> `Lifecycle`原理简述：
>
> 实现`LifecycleObserver`接口，在需要监听对应生命周期(`Lifecycle.Event`)的方法添加`@OnLifecycleEvent()`注解。
>
> 通过`LifecycleOwner.getLifecycle()`调用`addObserver()`添加监听，添加到`LifecycleRegistry.mObserverMap`中。(如果未在初始生命周期添加的监听，添加时会先执行之前生命周期的事件。)
>
> `LifecycleRegistry`就是`Lifecycle`的唯一实现类，上面说到的都是通过它实现的。当`LifecyleOwner`执行到对应的生命周期，就会通过`handleLifecycleEvent()`进行对应生命周期事件的分发，内部通过`sync()`负责**同步`LifecycleOwner`与`mObserverMap`的状态**，如果状态不统一，就需要通过`upEvent()`与`downEvent()`进行统一，并且通过`dispatchEvent()`分发未统一的事件。

## 拓展

`@OnLifecycleEvent`采用**运行时注解**方式，需要通过反射来执行逻辑。`Lifecycle`对于该注解采用了 **一次查找后续从缓存中获取**的形式，降低了反射时的性能消耗。详情可参考 *androidx.lifecycle.ClassInfoCache*内部有具体的逻辑实现。

上面执行到了`LifecycleObserver.dispatchEvent()`分发对应事件到使用了`@OnLifecycleEvent()`的方法中。

```java
//LifecycleRegistry.java
        void dispatchEvent(LifecycleOwner owner, Event event) {
            State newState = getStateAfter(event);
            mState = min(mState, newState);
            mLifecycleObserver.onStateChanged(owner, event);
            mState = newState;
        }


//ReflectiveGenericLifecycleObserver.java LifecycleObserver的实现类
    @Override
    public void onStateChanged(LifecycleOwner source, Event event) {
        mInfo.invokeCallbacks(source, event, mWrapped);
    }

//ClassesInfoCache.java
//缓存Event相关处理
final Map<Lifecycle.Event, List<MethodReference>> mEventToHandlers;

        void invokeCallbacks(LifecycleOwner source, Lifecycle.Event event, Object target) {
            invokeMethodsForEvent(mEventToHandlers.get(event), source, event, target);
            invokeMethodsForEvent(mEventToHandlers.get(Lifecycle.Event.ON_ANY), source, event,
                    target);
        }

        private static void invokeMethodsForEvent(List<MethodReference> handlers,
                LifecycleOwner source, Lifecycle.Event event, Object mWrapped) {
            if (handlers != null) {
                for (int i = handlers.size() - 1; i >= 0; i--) {
                    handlers.get(i).invokeCallback(source, event, mWrapped);
                }
            }
        }
```



## 内容引用

[Jekton-Lifecycle](https://jekton.github.io/2018/07/06/android-arch-lifecycle/)

[Android Developer 生命周期感知组件](https://developer.android.google.cn/topic/libraries/architecture/lifecycle#java)

