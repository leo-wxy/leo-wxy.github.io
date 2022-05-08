---
title: Jetpack-ViewModel简析
date: 2019-02-15 17:01:05
tags: 源码解析
top: 9
typora-root-url: ../
---



源码分析基于`androidx`版本

![ViewModel原理分析](/images/ViewModel原理分析.png)

## ViewModel简介

> ViewModel是用来存储和管理Lifecycle创建数据的组件，在配置发生改变或者屏幕旋转时数据仍然不会丢失。**ViewModel可以负责组件间的通信，可以高效解决Activity与Fragment的通信问题。**

主要的功能还是在非手动关闭以及系统回收条件下进行 Activity/Fragment的数据保存。

具有以下优势：

- 与UI层低耦合
- 可以在Fragment间共享ViewModel
- 数据一致保存在内存中，即使Activity重建

## ViewModel使用示例

> 系统默认提供两种`ViewModel`
>
> - `ViewModel`：抽象类实现
> - `AndroidViewModel`：相对于`ViewModel`多提供一个`application`的入参，可以通过`application`获取资源或者应用信息。
>
> **ViewModel绝不能引用View、Lifecycle或者Activity上下文引用的任何类。**



在`build.gradle`引入`ViewModel`

```groovy
dependencies {
  implementation 'androidx.lifecycle:lifecycle-viewmodel:2.1.0'
  implementation 'androidx.lifecycle:lifecycle-extensions:2.1.0'
}
```



创建一个类实现`ViewModel/AndroidViewModel`

```kotlin
class MyViewModel : ViewModel() {
        private val users: MutableLiveData<List<User>> by lazy {
            MutableLiveData().also {
                loadUsers()
            }
        }

        fun getUsers(): LiveData<List<User>> {
            return users
        }

        private fun loadUsers() {
            // Do an asynchronous operation to fetch users.
        }
}
    

class XXAndroidViewModel : AndroidViewModel(MyApp.getContext()){

}

```



创建完成后，需要在`Activity/Fragment`中调用

```kotlin
    class MyActivity : AppCompatActivity() {

        override fun onCreate(savedInstanceState: Bundle?) {

            val viewModel = ViewModelProviders.of(this).get(MyViewModel::class.java)
            model.getUsers().observe(this, Observer<List<User>>{ users ->
                // update UI
            })
        }
    }
    
```



上述为最简单的使用示例。



## ViewModel源码解析

![源码分析](/images/ViewModel-源码分析.png)

### ViewModel-结构

![ViewModel-结构](/images/ViewModel-结构.png)

#### ViewModel

> 抽象类，主要提供`onCleared()`可以清理一些自定义数据

```java
public abstract class ViewModel {
  //自定义清理
    protected void onCleared() {
    }  
  
    @MainThread
    final void clear() {
        mCleared = true;
        if (mBagOfTags != null) {
            synchronized (mBagOfTags) {
                for (Object value : mBagOfTags.values()) {
                    //针对 协程作用域的关闭
                    closeWithRuntimeException(value);
                }
            }
        }
      // 清理ViewModel相关数据
        onCleared();
    }  
}
```

还提供了`AndroidViewModel`，支持传入`Application`

```java
public class AndroidViewModel extends ViewModel {
    @SuppressLint("StaticFieldLeak")
    private Application mApplication;

  //添加对 Application的支持
    public AndroidViewModel(@NonNull Application application) {
        mApplication = application;
    }

    /**
     * Return the application.
     */
    @SuppressWarnings("TypeParameterUnusedInFormals")
    @NonNull
    public <T extends Application> T getApplication() {
        //noinspection unchecked
        return (T) mApplication;
    }
}

```



#### ViewModelProvider

> 为Activity、Fragment提供ViewModel的工具类，主要是**创建ViewModel**

![ViewModel-ViewModelProvider](/images/ViewModel-ViewModelProvider.png)

##### 内部参数

```java
public class ViewModelProvider {
  //创建ViewModel的工厂
    private final Factory mFactory;
  //存储ViewModel对象
    private final ViewModelStore mViewModelStore;  
  //构建ViewModel对象 默认key，在ViewModelStore根据key获取ViewModel
    private static final String DEFAULT_KEY =
            "androidx.lifecycle.ViewModelProvider.DefaultKey";
}
```

##### 构造方法

```java
    public ViewModelProvider(@NonNull ViewModelStoreOwner owner, @NonNull Factory factory) {
        this(owner.getViewModelStore(), factory);
    }

    public ViewModelProvider(@NonNull ViewModelStore store, @NonNull Factory factory) {
        mFactory = factory;
        mViewModelStore = store;
    }
```

提供两个构造方法，最终还是从`ViewModelStore`获取缓存的ViewModel

##### 获取ViewModel

```java
    public <T extends ViewModel> T get(@NonNull Class<T> modelClass) {
        String canonicalName = modelClass.getCanonicalName();
        if (canonicalName == null) {
            throw new IllegalArgumentException("Local and anonymous classes can not be ViewModels");
        }
        return get(DEFAULT_KEY + ":" + canonicalName, modelClass);
    }

    public <T extends ViewModel> T get(@NonNull String key, @NonNull Class<T> modelClass) {
        ViewModel viewModel = mViewModelStore.get(key);

        if (modelClass.isInstance(viewModel)) {
            //noinspection unchecked
            return (T) viewModel;
        } else {
            //noinspection StatementWithEmptyBody
            if (viewModel != null) {
                // TODO: log a warning.
            }
        }
      //创建ViewModel
        if (mFactory instanceof KeyedFactory) {
            viewModel = ((KeyedFactory) (mFactory)).create(key, modelClass);
        } else {
            viewModel = (mFactory).create(modelClass);
        }
      //创建完毕后 缓存起来 
        mViewModelStore.put(key, viewModel);
        //noinspection unchecked
        return (T) viewModel;
    }
```

主要从`ViewModelStore`中获取`ViewModel`数据

##### Factory

`Factory`主要用来创建ViewModel

```java
    public interface Factory {
        @NonNull
        <T extends ViewModel> T create(@NonNull Class<T> modelClass);
    }
```

系统提供的`Factroy`主要有以下几类

- `NewInstanceFactory`：通过`Class.newInstance()`直接创建ViewModel实例
- `AndroidViewModelFactory`：针对`AndroidViewModel`，通过`Class.getConstructor()`传入`Application`实例

#### ViewModelStore

> 内部主要缓存ViewModel

![ViewModel-ViewModelStore](/images/ViewModel-ViewModelStore.png)

```java
public class ViewModelStore {

    private final HashMap<String, ViewModel> mMap = new HashMap<>();

    final void put(String key, ViewModel viewModel) {
        ViewModel oldViewModel = mMap.put(key, viewModel);
        if (oldViewModel != null) {
            oldViewModel.onCleared();
        }
    }

    final ViewModel get(String key) {
        return mMap.get(key);
    }

    Set<String> keys() {
        return new HashSet<>(mMap.keySet());
    }

  //当内部ViewModel不使用时，及时清理内存
    public final void clear() {
        for (ViewModel vm : mMap.values()) {
            vm.clear();
        }
        mMap.clear();
    }
}
```

内部主要维护一个`mMap`，缓存ViewModel。

##### ViewModelStoreOwner

```java
public interface ViewModelStoreOwner {
    @NonNull
    ViewModelStore getViewModelStore();
}
```

是一个接口，表示`ViewModelStore`的作用域，主要实现类为`ComponentActivity`和`androidx.fragment.app.Fragment`。

### ViewModel-生命周期绑定

![ViewModel-生命周期绑定](/images/ViewModel-生命周期绑定.png)

`ViewModel`对象存在的时间范围是获取`ViewModel`时传递给`ViewModelProvider`的`Lifecycle`。`ViewModel`通过`Lifecycle`与`Activity/Fragment`进行绑定的。

```java
//ComponentActivity.java
        getLifecycle().addObserver(new LifecycleEventObserver() {
            @Override
            public void onStateChanged(@NonNull LifecycleOwner source,
                    @NonNull Lifecycle.Event event) {
              //当Activity结束的时候，销毁ViewModel
                if (event == Lifecycle.Event.ON_DESTROY) {
                    if (!isChangingConfigurations()) {
                      //ViewModel销毁
                        getViewModelStore().clear();
                    }
                }
            }
        });


```



![说明 ViewModel 随着 Activity 状态的改变而经历的生命周期。](/images/viewmodel-lifecycle.png)

### ViewModel-Activity销毁重建

![ViewModel-Activity销毁重建过程](/images/ViewModel-Activity销毁重建过程.png)

```java
//ComponentActivity.java
    public ViewModelStore getViewModelStore() {
        if (getApplication() == null) {
            throw new IllegalStateException("Your activity is not yet attached to the "
                    + "Application instance. You can't request ViewModel before onCreate call.");
        }
        if (mViewModelStore == null) {
          //核心逻辑 
            NonConfigurationInstances nc =
                    (NonConfigurationInstances) getLastNonConfigurationInstance();
            if (nc != null) {
                // Restore the ViewModelStore from NonConfigurationInstances
                mViewModelStore = nc.viewModelStore;
            }
            if (mViewModelStore == null) {
                mViewModelStore = new ViewModelStore();
            }
        }
        return mViewModelStore;
    }
```

当Activity创建时，并且调用`ViewModelProvider().get(XXModel::class.java)`时，会调用到`getViewModelStore()`此时会分为两种情况：

- `getLastNonConfigurationInstance()`不为null，直接从内部获取`ViewModelStore`
- `getLastNonConfigurationInstance()`为null，新建一个`ViewModelStore`对象

如何判断`getLastNonConfigurationInstance()`是否为null，就需要找到写入该数据的地方，判断在什么场景下会执行写入？

```java
    public final Object onRetainNonConfigurationInstance() {
        Object custom = onRetainCustomNonConfigurationInstance();

        ViewModelStore viewModelStore = mViewModelStore;
        if (viewModelStore == null) {
            NonConfigurationInstances nc =
                    (NonConfigurationInstances) getLastNonConfigurationInstance();
            if (nc != null) {
                viewModelStore = nc.viewModelStore;
            }
        }

        if (viewModelStore == null && custom == null) {
            return null;
        }

        NonConfigurationInstances nci = new NonConfigurationInstances();
        nci.custom = custom;
        nci.viewModelStore = viewModelStore;
        return nci;
    }
```

`ComponentActivity`重写了`onRetainNonConfigurationInstance()`方法，在其中存储了`ViewModelStore`。

##### 为什么`NonConfiguationInstance`可以在Activity重建时不被销毁？

`Activity`重建时的生命周期过程：`onPause -> onStop -> onDestroy -> onCreate -> onStart -> onResume`

那就需要在`onDestroy`时，存储`NonConfigurationInstances`，才可以在后续启动时重新获取到数据

```java
//ActivityThread.java
    ActivityClientRecord performDestroyActivity(IBinder token, boolean finishing,
            int configChanges, boolean getNonConfigInstance, String reason) {
      ActivityClientRecord r = mActivities.get(token);
      //默认 getNonConfigInstance为true
            if (getNonConfigInstance) {
                try {
                  //将写入的 NonConfigurationInstances 存到ActivityClientRecord中
                    r.lastNonConfigurationInstances
                            = r.activity.retainNonConfigurationInstances();
                } catch (Exception e) {
                    if (!mInstrumentation.onException(r.activity, e)) {
                        throw new RuntimeException(
                                "Unable to retain activity "
                                + r.intent.getComponent().toShortString()
                                + ": " + e.toString(), e);
                    }
                }
            }      
    }
```

```java
//Activity.java
    NonConfigurationInstances retainNonConfigurationInstances() {
      //执行到 ComponentActivity.onRetainNonConfigurationInstance() ，返回了携带ViewModelStore的NonConfigurationInstances       
        Object activity = onRetainNonConfigurationInstance();

        HashMap<String, Object> children = onRetainNonConfigurationChildInstances();
        FragmentManagerNonConfig fragments = mFragments.retainNestedNonConfig();
...
        ArrayMap<String, LoaderManager> loaders = mFragments.retainLoaderNonConfig();


        NonConfigurationInstances nci = new NonConfigurationInstances();
        nci.activity = activity;
        nci.children = children;
        nci.fragments = fragments;

        return nci;
    }
```



Activity重启时

```java
//ActivityThread.java
    private Activity performLaunchActivity(ActivityClientRecord r, Intent customIntent) {
      ...
                activity.attach(appContext, this, getInstrumentation(), r.token,
                        r.ident, app, r.intent, r.activityInfo, title, r.parent,
                        r.embeddedID, r.lastNonConfigurationInstances/*ActivityClientRecord获取的数据*/, config,
                        r.referrer, r.voiceInteractor, window, r.configCallback,
                        r.assistToken);
        
    }
```

```java
//Activity.java
    final void attach(Context context, ActivityThread aThread,
            Instrumentation instr, IBinder token, int ident,
            Application application, Intent intent, ActivityInfo info,
            CharSequence title, Activity parent, String id,
            NonConfigurationInstances lastNonConfigurationInstances,
            Configuration config, String referrer, IVoiceInteractor voiceInteractor,
            Window window, ActivityConfigCallback activityConfigCallback, IBinder assistToken) {
      ...
        mWindow = new PhoneWindow(this, window, activityConfigCallback);
        mWindow.setWindowControllerCallback(this);
        mWindow.setCallback(this);        
      
      //赋值 mLastNonConfigurationInstances
        mLastNonConfigurationInstances = lastNonConfigurationInstances;      
    }
```

这样就回到了`ComponentActivity`的`getViewModelStore()`时，就可以获取写入的`NonConfigurationInstances`。

由于`NonConfigurationInstances`是写入到`ActivityClientRecord`中，与`Activity`生命周期无关。



### ViewModel-Fragment销毁重建

![ViewModel-Fragment销毁重建过程](/images/ViewModel-Fragment销毁重建过程.png)

```java
//androidx.fragment.app.Fragment.java    
    FragmentManagerImpl mFragmentManager;

public ViewModelStore getViewModelStore() {
        if (mFragmentManager == null) {
            throw new IllegalStateException("Can't access ViewModels from detached fragment");
        }
        return mFragmentManager.getViewModelStore(this);
    }

//FragmentManagerImpl.java

    private FragmentManagerViewModel mNonConfig;
    @NonNull
    ViewModelStore getViewModelStore(@NonNull Fragment f) {
        return mNonConfig.getViewModelStore(f);
    }


```

`mNonConfig`是一个`FragmentManagerViewModel`类型，意味着也是`ViewModel`的一种，对应的需要找到初始化的地方。

```java
//FragmentManagerViewModel.java
class FragmentManagerViewModel extends ViewModel {
  ...
    //需要 Retain的Fragment
    private final HashSet<Fragment> mRetainedFragments = new HashSet<>();
  //存储了childFragment的 FragmentManagerViewModel
    private final HashMap<String, FragmentManagerViewModel> mChildNonConfigs = new HashMap<>();
  //存储了childFragment的 ViewModelStore
    private final HashMap<String, ViewModelStore> mViewModelStores = new HashMap<>();  
  
}
```

![Fragment嵌套-ViewModel](/images/Fragment嵌套-ViewModel)



```java
    public void attachController(@NonNull FragmentHostCallback host,
            @NonNull FragmentContainer container, @Nullable final Fragment parent) {
      ...
        if (parent != null) {
          //当前为childFragment
            mNonConfig = parent.mFragmentManager.getChildNonConfig(parent);
        } else if (host instanceof ViewModelStoreOwner) {
          //当前为 FragmentActivity
            ViewModelStore viewModelStore = ((ViewModelStoreOwner) host).getViewModelStore();
            mNonConfig = FragmentManagerViewModel.getInstance(viewModelStore);
        } else {
          //都不是 就直接新建ViewModel对象
            mNonConfig = new FragmentManagerViewModel(false);
        }      
    }
```

接下来寻找`attachController`的调用

分为两处调用，一处位于`Fragment`，另一处位于`FragmentController`实际就是`FragmentActivity`

```java
//Fragment.java
    void performAttach() {
        mChildFragmentManager.attachController(mHost, new FragmentContainer() {...}, this);
        mCalled = false;
        onAttach(mHost.getContext());
    }


```

当从`Fragment`获取数据时，数据来源是`getChildNonconfig()`



```java
//FragmentActivity.java
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        mFragments.attachHost(null /*parent*/);
      ...
    }
```

此时初始化完成`FragmentManagerViewModel`并存入到`FragmentActivity`的`ViewModelStore`中。



![ViewModel-Fragment](/images/ViewModel-Fragment)



#### 总结

`Fragment`声明的`ViewModel`存储在`FragmentManagerImpl.mNonConfig`实际存储于`FragmentManagerViewModel`中，而`FragmentManagerViewModel`实际存储于`FragmentActivity.mViewModelStore`中。

所以`ViewModel`在Fragment中也不会因为重建而被销毁。

原因就是**Fragmen的ViewMode存储于FragmentManagerViewModel，而它存在于FragmentActivity的ViewModelStore中。FragmentActivity的ViewModelStore会在Activity销毁时存储于`NonConfigurationInstances`中，当然也会存到ActivityyClienrtRecord中。**

### ViewModel-Fragment间数据共享

![ViewModel-Fragment间数据共享](/images/ViewModel-Fragment间数据共享.png)

Fragment之间使用Activity范围共享的`ViewModel`处理Fragment间的数据共享。

```kotlin
//定义一个共享的ViewModel
class SharedViewModel : ViewModel() {
        val selected = MutableLiveData<Item>()

        fun select(item: Item) {
            selected.value = item
        }
    }


    class OneFragment : Fragment() {

        private lateinit var itemSelector: Selector

        private val model: SharedViewModel  = ViewModelProviders.of(activity).get(ShareViewModel::class.java)

        override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
            super.onViewCreated(view, savedInstanceState)
            itemSelector.setOnClickListener { item ->
                // Update the UI
            }
        }
    }

    class TwoFragment : Fragment() {

        private val model: SharedViewModel  = ViewModelProviders.of(activity).get(ShareViewModel::class.java)

        override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
            super.onViewCreated(view, savedInstanceState)
            model.selected.observe(viewLifecycleOwner, Observer<Item> { item ->
                // Update the UI
            })
        }
    }
```

当两个Fragment获取`ViewModel`时，都会从宿主Activity的`ViewModelStore`获取数据，又因为key一致，所以可以得到同一个ViewModel对象。

**只要保证作用域(ViewModelStore)相同，就可以获取相同的`ViewModel`实例**

## ViewModel拓展

### ViewModel与协程

Android 提供了`viewModelScope`这一拓展属性，可以在`ViewModel`销毁时退出，可以利用`viewModelScope`启动ViewModel

中的协程，而不用担心任务泄漏。

```kotlin
//示例代码
class MyViewModel() : ViewModel() {

    fun initialize() {
        viewModelScope.launch {
            processBitmap()
        }
    }

    suspend fun processBitmap() = withContext(Dispatchers.Default) {
        // 在这里做耗时操作
    }

}
```

```kotlin
//ViewModel.kt
public val ViewModel.viewModelScope: CoroutineScope
    get() {
        val scope: CoroutineScope? = this.getTag(JOB_KEY)
        if (scope != null) {
            return scope
        }
        return setTagIfAbsent(
            JOB_KEY,
            CloseableCoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        )
    }

```



## Activity销毁重建数据恢复方式

![ViewModel-Activity重建恢复数据方式](/images/ViewModel-Activity重建恢复数据方式.png)

### onSaveInstanceState() / onRestoreInstanceState()

当Activity开始停止时，系统会调用`onSaveInstanceState()`存储当前Activity的状态，执行于`onStop()`之后。

重建先前被销毁的Activity时，调用到`onRestoreInstanceState()`获取原先存储的Activity状态，在`onCreate()`也会获得同样的数据。数据对象是`Bundle`。

### Fragment.setRetainInstance(true)

当配置发生改变时，Fragment 会随着宿主 Activity 销毁与重建，当我们调用 Fragment 中的 setRetainInstance(true) 方法时，系统允许 Fragment 绕开销毁-重建的过程。使用该方法，将会发送信号给系统，让 Activity 重建时，保留 Fragment 的实例。需要注意的是：

- 使用该方法后，不会调用 Fragment 的 `onDestory() `方法，但仍然会调用 `onDetach()` 方法
- 使用该方法后，不会调用 Fragment 的 `onCreate(Bundle)` 方法。因为 Fragment 没有被重建。
- 使用该方法后，Fragment 的 `onAttach(Activity)` 与 `onActivityCreated(Bundle)` 方法仍然会被调用。



简述`setRetainInstance(true)`流程：

> 调用`setRetainInstance(true)`时，会将该Fragment存入到`FragmentManagerViewModel`中的`mRetainedFragment`中，等价于`Fragment`已经位于`FragmentActivity`的`ViewModelStore`中。也就是存储于`NonconfigurationInstance`中。
>
> 后续可以从`mLastConfiguationInstances`获取存储的`Fragment`，再调用到`FragmentManager.restoreSaveState()`就可以还原Fragment。**Fragment实例也没有发生改变。**

### onRetainNonConfigurationInstance()/getLastNonConfigurationInstance()

在 Activity 中提供了 `onRetainNonConfigurationInstance` 方法，用于处理配置发生改变时数据的保存。随后在重新创建的 Activity 中调用 `getLastNonConfigurationInstance` 获取上次保存的数据。我们不能直接重写上述方法，如果想在 Activity 中自定义想要恢复的数据，需要我们调用上述两个方法的内部方法：

- `onRetainCustomNonConfigurationInstance()`
- `getLastCustomNonConfigurationInstance()`

注意：`onRetainNonConfigurationInstance` 方法系统调用时机介于 onStop - onDestory 之间，`getLastNonConfigurationInstance` 方法可在 onCreate 与 onStart 方法中调用。



|                                                              | 存储位置     | 数据类型                           | 系统内存不足回收<br>数据是否存在 | 配置更改<br>数据是否存在 | 数据读写速度        |
| ------------------------------------------------------------ | ------------ | ---------------------------------- | -------------------------------- | ------------------------ | ------------------- |
| onSaveInstanceState() /<br> onRestoreInstanceState()         | 序列化到磁盘 | 支持`基础数据类型`和`可序列化对象` | 是                               | 是                       | 慢<br>有IO操作      |
| setRetainInstance(true)                                      | 内存         | `支持复杂对象`<br>受可用内存限制   | 否<br>实例已被销毁               | 是                       | 快<br>直接内存读写  |
| onRetainNonConfigurationInstance()/<br>getLastNonConfigurationInstance() | 内存         | `支持复杂对象`<br/>受可用内存限制  | 否<br/>实例已被销毁              | 是                       | 快<br/>直接内存读写 |



## 参考链接

[ViewModel知识点](https://juejin.cn/post/6844904079265644551#heading-1)

[AndroidDeveloper-ViewModel](https://developer.android.google.cn/topic/libraries/architecture/viewmodel)