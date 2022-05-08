---
title: Android性能优化-LeakCanary
typora-root-url: ../
date: 2020-10-14 14:45:26
tags: Android
top: 9
---



{% blockquote %}
LeakCanary主要用来**进行内存泄漏检测**，并且可以直观的展示泄漏的路径
{% endblockquote %}

## 如何使用

```groovy
dependencies {
  // debugImplementation because LeakCanary should only run in debug builds.
  debugImplementation 'com.squareup.leakcanary:leakcanary-android:2.5'
}
```

配置完成后，`LeakCanary`通过`ContentProvider`进行注册以及初始化。

```kotlin
//AppWatcherInstaller.kt
internal sealed class AppWatcherInstaller : ContentProvider() {

  override fun onCreate(): Boolean {
    val application = context!!.applicationContext as Application
    AppWatcher.manualInstall(application)
    return true
  }
  
}
```

涉及的部分Activity启动过程源码：

```java
//ActivityThread.java
private void handleBindApplication(AppBindData data) {
  ...
  //获取LoaderApk对象
  data.info = getPackageInfoNoCheck(data.appInfo, data.compatInfo);
  //创建进程对应的Android运行环境ContextImpl
  final ContextImpl appContext = ContextImpl.createAppContext(this, data.info);
  ...
  try {
            //准备创建Application对象
            Application app = data.info.makeApplication(data.restrictedBackupMode, null);
            mInitialApplication = app;
            ...
             //加载对应进程中的ContentProvider
            installContentProviders(app, data.providers);
            try {
                mInstrumentation.onCreate(data.instrumentationArgs);
            }
            catch (Exception e) {
                throw new RuntimeException(
                    "Exception thrown in onCreate() of "
                    + data.instrumentationName + ": " + e.toString(), e);
            }

            try {
                //调用Application的onCreate方法
                mInstrumentation.callApplicationOnCreate(app);
            } catch (Exception e) {
                if (!mInstrumentation.onException(app, e)) {
                    throw new RuntimeException(
                        "Unable to create application " + app.getClass().getName()
                        + ": " + e.toString(), e);
                }
            }
        } finally {
            StrictMode.setThreadPolicy(savedPolicy);
        }
}

```

在`handleBindApplication()`进行`ContentProvider`的启动，此时`AppWatcherInstaller`会在此时启动。

向下调用到`AppWatcher.manualInstall(application)`

```kotlin
//AppWatcher.kt
  fun manualInstall(application: Application) {
    InternalAppWatcher.install(application)
  }

//InternalAppWatcher.kt
//开始了初始化流程
  fun install(application: Application) {
    //初始化
  }

```

到此基本的`LeakCanary`初始化完毕

### 主动添加内存泄漏监控

```kotlin
AppWatcher.objectWatcher.watch(watchObject,reason)
```



## 源码解析

### 注册监听

在初始化过程执行的`注册监听`过程

```kotlin
//InternalAppWatcher.kt
//开始了初始化流程
  fun install(application: Application) {
    checkMainThread()
    if (this::application.isInitialized) {
      return
    }
    InternalAppWatcher.application = application
    if (isDebuggableBuild) {
      SharkLog.logger = DefaultCanaryLog()
    }

    val configProvider = { AppWatcher.config }
    ActivityDestroyWatcher.install(application, objectWatcher, configProvider)
    FragmentDestroyWatcher.install(application, objectWatcher, configProvider)
    onAppWatcherInstalled(application)
  }
```

#### 监听Activity

`ActivityDestroyWatcher.install`

```kotlin
internal class ActivityDestroyWatcher private constructor(
  private val objectWatcher: ObjectWatcher,
  private val configProvider: () -> Config
) {

  private val lifecycleCallbacks =
    object : Application.ActivityLifecycleCallbacks by noOpDelegate() {
      override fun onActivityDestroyed(activity: Activity) {
        //监听Activity onDestroy()生命周期
        if (configProvider().watchActivities) {
          objectWatcher.watch(
              activity, "${activity::class.java.name} received Activity#onDestroy() callback"
          )
        }
      }
    }

  companion object {
    fun install(
      application: Application,
      objectWatcher: ObjectWatcher,
      configProvider: () -> Config
    ) {
      val activityDestroyWatcher =
        ActivityDestroyWatcher(objectWatcher, configProvider)
      //往Application添加Activity生命周期回调监听
      application.registerActivityLifecycleCallbacks(activityDestroyWatcher.lifecycleCallbacks)
    }
  }
}
```

主要是为了注册Activity的生命周期回调，监测到`onActivityDestroyed()`之后，将Activity加入到`objectWatcher`中

#### 监听Fragment

`FragmentDestroyWatcher.install`

```kotlin
internal object FragmentDestroyWatcher {
  
  //AndroidX fragment相关配置
    private const val ANDROIDX_FRAGMENT_CLASS_NAME = "androidx.fragment.app.Fragment"
    private const val ANDROIDX_FRAGMENT_DESTROY_WATCHER_CLASS_NAME =
    "leakcanary.internal.AndroidXFragmentDestroyWatcher"
  
  
  //supprt fragment相关配置
    private val ANDROID_SUPPORT_FRAGMENT_CLASS_NAME =
    StringBuilder("android.").append("support.v4.app.Fragment")
        .toString()
  private const val ANDROID_SUPPORT_FRAGMENT_DESTROY_WATCHER_CLASS_NAME =
    "leakcanary.internal.AndroidSupportFragmentDestroyWatcher"

  
  ...
   fun install(
    application: Application,
    objectWatcher: ObjectWatcher,
    configProvider: () -> AppWatcher.Config
  ) {
    val fragmentDestroyWatchers = mutableListOf<(Activity) -> Unit>()

     //Android 8.0及以上 直接构造 AndroidOFragmentDestroyWatcher
    if (SDK_INT >= O) {
      fragmentDestroyWatchers.add(
          AndroidOFragmentDestroyWatcher(objectWatcher, configProvider)
      )
    }

     //androidx fragment对象 
    getWatcherIfAvailable(
        ANDROIDX_FRAGMENT_CLASS_NAME,
        ANDROIDX_FRAGMENT_DESTROY_WATCHER_CLASS_NAME,
        objectWatcher,
        configProvider
    )?.let {
      fragmentDestroyWatchers.add(it)
    }

     //fragment相关配置
    getWatcherIfAvailable(
        ANDROID_SUPPORT_FRAGMENT_CLASS_NAME,
        ANDROID_SUPPORT_FRAGMENT_DESTROY_WATCHER_CLASS_NAME,
        objectWatcher,
        configProvider
    )?.let {
      fragmentDestroyWatchers.add(it)
    }

    if (fragmentDestroyWatchers.size == 0) {
      return
    }

    application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks by noOpDelegate() {
      override fun onActivityCreated(
        activity: Activity,
        savedInstanceState: Bundle?
      ) {
        //在Activity创建时 添加Fragment的监听
        for (watcher in fragmentDestroyWatchers) {
          //调用到 对应的 invoke()
          watcher(activity)
        }
      }
    })
  }
  
}
```

根据上述源码，`FragmentDestroyWatcher`按照三种情况进行区分：

- Android O 及以上版本的fragment：`AndroidOFragmentDestroyWatcher`
- AndroidX 的fragment：`AndroidXFragmentDestroyWatcher`
- Android support 的 fragment：`AndroidSupportFragmentDestroyWatcher`



上述三种实现基本一致，只是对引用的`fragment`进行了区分，下面拿`AndroidSupportFragmentDestroyWatcher`进行分析

```kotlin
//AndroidSupportFragmentDestroyWatcher.kt
internal class AndroidSupportFragmentDestroyWatcher(
  private val objectWatcher: ObjectWatcher,
  private val configProvider: () -> Config
) : (Activity) -> Unit {

  private val fragmentLifecycleCallbacks = object : FragmentManager.FragmentLifecycleCallbacks() {

    override fun onFragmentViewDestroyed(
      fm: FragmentManager,
      fragment: Fragment
    ) {
      //添加了对fragment引用的View的泄漏监听
      val view = fragment.view
      if (view != null && configProvider().watchFragmentViews) {
        objectWatcher.watch(
            view, "${fragment::class.java.name} received Fragment#onDestroyView() callback " +
            "(references to its views should be cleared to prevent leaks)"
        )
      }
    }

    override fun onFragmentDestroyed(
      fm: FragmentManager,
      fragment: Fragment
    ) {
      if (configProvider().watchFragments) {
        //添加对 fragment的泄漏监听
        objectWatcher.watch(
            fragment, "${fragment::class.java.name} received Fragment#onDestroy() callback"
        )
      }
    }
  }

  override fun invoke(activity: Activity) {
    if (activity is FragmentActivity) {
      //针对 fragmentManager 添加 fragmentlifecyclecallback监听
      val supportFragmentManager = activity.supportFragmentManager
      supportFragmentManager.registerFragmentLifecycleCallbacks(fragmentLifecycleCallbacks, true)
    }
  }
}
```

主要是在`FragmentManager`调用`registerFragmentLifecycleCallbacks()`添加生命周期监听。

- 在`onFragmentViewDestroyed()`添加`View`的监听
- 在`onFragmentDestroyed()`添加`Fragment`的监听



最后在`registerActivityLifecycleCallbacks()`的每个Activity的`onActivityCreated()`中执行`Fragment`的生命周期监听。



此时`objectWatcher`对象就已经监听到了如下实例：

- Activity
- Fragment
- Fragment中的View

#### InternalLeakCanary

```kotlin
//InternalappWatcher.kt
  init {
    val internalLeakCanary = try {
      val leakCanaryListener = Class.forName("leakcanary.internal.InternalLeakCanary")
      leakCanaryListener.getDeclaredField("INSTANCE")
          .get(null)
    } catch (ignored: Throwable) {
      NoLeakCanary
    }
    @kotlin.Suppress("UNCHECKED_CAST")
    onAppWatcherInstalled = internalLeakCanary as (Application) -> Unit
  }
```

最后执行的`onAppWatcherInstalled()`的实现类就是`InternalLeakCanary`

```kotlin
//InternalLeakCanary.kt
  override fun invoke(application: Application) {
    _application = application

    checkRunningInDebuggableBuild()

    //注册监听对象 可能泄漏的消息
    AppWatcher.objectWatcher.addOnObjectRetainedListener(this)

    val heapDumper = AndroidHeapDumper(application, createLeakDirectoryProvider(application))

    val gcTrigger = GcTrigger.Default

    val configProvider = { LeakCanary.config }

    val handlerThread = HandlerThread(LEAK_CANARY_THREAD_NAME)
    handlerThread.start()
    val backgroundHandler = Handler(handlerThread.looper)

    //dump内存
    heapDumpTrigger = HeapDumpTrigger(
        application, backgroundHandler, AppWatcher.objectWatcher, gcTrigger, heapDumper,
        configProvider
    )
    application.registerVisibilityListener { applicationVisible ->
      this.applicationVisible = applicationVisible
      heapDumpTrigger.onApplicationVisibilityChanged(applicationVisible)
    }
    registerResumedActivityListener(application)
    //添加桌面的快捷入口
    addDynamicShortcut(application)

    // We post so that the log happens after Application.onCreate()
    Handler().post {
      SharkLog.d {
        when (val iCanHasHeap = HeapDumpControl.iCanHasHeap()) {
          is Yup -> application.getString(R.string.leak_canary_heap_dump_enabled_text)
          is Nope -> application.getString(
              R.string.leak_canary_heap_dump_disabled_text, iCanHasHeap.reason()
          )
        }
      }
    }
  }
```

`InternalLeakCanary`主要负责接收`objectWatcher`通知的`可能存在的内存泄漏`消息并驱动`heapDumpTrigger`进行`Dump`过程。

得到最终产出的`Hprof文件`去进行分析的流程。

![LeakCanary初始化](/images/LeakCanary初始化.jpg)





### 泄漏检测

根据上节分析可知，所有需要监控的对象都会通过`objectWatcher.watch()`进行对象监听

```kotlin
//监测引用队列间隔
val watchDurationMillis: Long = TimeUnit.SECONDS.toMillis(5),

private val checkRetainedExecutor = Executor {
    mainHandler.postDelayed(it, AppWatcher.config.watchDurationMillis)
  }

val objectWatcher = ObjectWatcher(
      clock = clock,
      checkRetainedExecutor = checkRetainedExecutor,
      isEnabled = { true }
  )

```

实现类是`ObjectWatcher`

#### ObjectWatcher

```kotlin
class ObjectWatcher constructor(
  private val clock: Clock,
  private val checkRetainedExecutor: Executor,
  /**
   * Calls to [watch] will be ignored when [isEnabled] returns false
   */
  private val isEnabled: () -> Boolean = { true }
) {
  //需要监听的弱引用对象实例
  private val watchedObjects = mutableMapOf<String, KeyedWeakReference>()
  //引用队列
  private val queue = ReferenceQueue<Any>()
  
  ...
  
    @Synchronized fun watch(
    watchedObject: Any,
    description: String
  ) {
    if (!isEnabled()) {
      return
    }
    removeWeaklyReachableObjects()
    val key = UUID.randomUUID()
        .toString()
    val watchUptimeMillis = clock.uptimeMillis()
      //将需要监听的对象 构建一个弱引用实例
    val reference =
      KeyedWeakReference(watchedObject, key, description, watchUptimeMillis, queue){}

    watchedObjects[key] = reference
      //执行 checkExecutor任务
    checkRetainedExecutor.execute {
      moveToRetained(key)
    }
  }
}
```

调用`watch()`之后，将需要监听的对象添加弱引用(`WeakReference`)，再通过关联一个引用队列(`ReferenceQueue`)判断监听对象是否被回收。

> 为什么选用弱引用？
>
> 除了强引用不会被回收外，还存在着`软引用`和`虚引用`。其中`软引用`必须在内存将满时才会被回收并加入到`ReferenceQueue`中，而`虚引用`在加入到`ReferenceQueue`时，内置的引用无法被清空。



包装成弱引用对象后，执行`checkRetainedExecutor`的线程池，本质上执行的是**等待5s后执行对象是否回收的判断。**

```kotlin
  @Synchronized private fun moveToRetained(key: String) {
    removeWeaklyReachableObjects()
    val retainedRef = watchedObjects[key]
    if (retainedRef != null) {
      retainedRef.retainedUptimeMillis = clock.uptimeMillis()
      onObjectRetainedListeners.forEach { it.onObjectRetained() }
    }
  }

  private fun removeWeaklyReachableObjects() {
    // WeakReferences are enqueued as soon as the object to which they point to becomes weakly
    // reachable. This is before finalization or garbage collection has actually happened.
    var ref: KeyedWeakReference?
    do {
      ref = queue.poll() as KeyedWeakReference?
      if (ref != null) {
        watchedObjects.remove(ref.key)
      }
    } while (ref != null)
  }
```

`watchedObjects`存放的就是`被观察的对象引用`，每次调用`watch()`都会发送一个延时5s的消息。

延时消息主要执行`moveToRetained()`，内部主要执行如下过程：

1. 遍历`queue(引用队列)`，将其中存在的对象从`watchedObjects`中移除，因为已经被回收
2. 如果对象没有从`watchedObjects`中移除，就表示该对象发生了`内存泄漏`

### Dump出Hprof文件

如果存在未被回收的对象，此时就会回调到`OnObjectRetainedListener.onObjectRetained()`

```kotlin
internal object InternalLeakCanary : (Application) -> Unit, OnObjectRetainedListener {
  ...
    override fun invoke(application: Application) {
      //添加回调监听注册
      AppWatcher.objectWatcher.addOnObjectRetainedListener(this)
      ...
    }
  
  //实现的方法
  override fun onObjectRetained() = scheduleRetainedObjectCheck()  
  
  
  fun scheduleRetainedObjectCheck() {
    //初始化完毕
    if (this::heapDumpTrigger.isInitialized) {
      heapDumpTrigger.scheduleRetainedObjectCheck()
    }
  }  
}
```

切换到`HeapDumpTrigger`继续执行

#### HeapDumpTrigger

```kotlin
//HeapDumpTrigger.kt 
fun scheduleRetainedObjectCheck(
    delayMillis: Long = 0L
  ) {
    val checkCurrentlyScheduledAt = checkScheduledAt
    if (checkCurrentlyScheduledAt > 0) {
      return
    }
    checkScheduledAt = SystemClock.uptimeMillis() + delayMillis
    backgroundHandler.postDelayed({
      checkScheduledAt = 0
      checkRetainedObjects()
    }, delayMillis)
  }

  private fun checkRetainedObjects() {
   ... 
    //获取未释放的对象数
    var retainedReferenceCount = objectWatcher.retainedObjectCount

    if (retainedReferenceCount > 0) {
      //手动执行一次GC
      gcTrigger.runGc()
      //在获取一次 
      retainedReferenceCount = objectWatcher.retainedObjectCount
    }

    //判断是否超过阈值，避免重复调用dump
    if (checkRetainedCount(retainedReferenceCount, config.retainedVisibleThreshold)) return
    
    //dump内存生成 Hprof文件
        dumpHeap(retainedReferenceCount, retry = true)
    
  }

//GcTrigger.kt
  object Default : GcTrigger {
    override fun runGc() {
      Runtime.getRuntime()
          .gc()
      enqueueReferences()
      System.runFinalization()
    }

    private fun enqueueReferences() {
      // Hack. We don't have a programmatic way to wait for the reference queue daemon to move
      // references to the appropriate queues.
      try {
        Thread.sleep(100)
      } catch (e: InterruptedException) {
        throw AssertionError()
      }
    }
  }
```

`scheduleRetainedObjectCheck()`并不是直接去dump，而是先手动调用一次GC，然后再触发GC后等待`100ms`之后再去检测一次是否有对象未被回收。

其中判断过程还添加了`阈值(5)`，避免频繁触发`dumpHeap()`导致卡顿。

#### dumpHeap()

主要负责dump 出 Hprof文件

```kotlin
//InternalLeakCanary.kt
    val heapDumper = AndroidHeapDumper(application, createLeakDirectoryProvider(application))

//HeapDumpTrigger.kt
  private fun dumpHeap(
    retainedReferenceCount: Int,
    retry: Boolean
  ) {
    saveResourceIdNamesToMemory()
    val heapDumpUptimeMillis = SystemClock.uptimeMillis()
    KeyedWeakReference.heapDumpUptimeMillis = heapDumpUptimeMillis
    //开始执行dump过程
    when (val heapDumpResult = heapDumper.dumpHeap()) {
      is NoHeapDump -> {
        ...
      }
      is HeapDump -> {
        lastDisplayedRetainedObjectCount = 0
        lastHeapDumpUptimeMillis = SystemClock.uptimeMillis()
        //生成hprof文件
        objectWatcher.clearObjectsWatchedBefore(heapDumpUptimeMillis)
        //hprof文件生成完毕后，发送到HeapAnalyzeSerview
        HeapAnalyzerService.runAnalysis(
            context = application,
            heapDumpFile = heapDumpResult.file,
            heapDumpDurationMillis = heapDumpResult.durationMillis
        )
      }
    }
  }
```

通过`AndroidHeapDumper`去执行dump过程

```kotlin
//AndroidHeapDumper.kt
  override fun dumpHeap(): DumpHeapResult {
    ...
     return try {
      val durationMillis = measureDurationMillis {
        //执行dump过程
        Debug.dumpHprofData(heapDumpFile.absolutePath)
      }
      if (heapDumpFile.length() == 0L) {
        SharkLog.d { "Dumped heap file is 0 byte length" }
        NoHeapDump
      } else {
        HeapDump(file = heapDumpFile, durationMillis = durationMillis)
      }
    } catch (e: Exception) {
      SharkLog.d(e) { "Could not dump heap" }
      // Abort heap dump
      NoHeapDump
    } finally {
      cancelToast(toast)
      notificationManager.cancel(R.id.leak_canary_notification_dumping_heap)
    }
    
  }
```

主要是执行`Debug.dumpHprofData()`得到`Hprof文件`去进行内存分析。

#### HeapAnalyzerService.runAnalysis()

主要负责去分析Hprof文件

```kotlin
//HeapAnalyzerService.kt
    fun runAnalysis(
      context: Context,
      heapDumpFile: File,
      heapDumpDurationMillis: Long? = null
    ) {
      val intent = Intent(context, HeapAnalyzerService::class.java)
      //携带文件地址 到 HeapAnalyzerService去进行分析
      intent.putExtra(HEAPDUMP_FILE_EXTRA, heapDumpFile)
      heapDumpDurationMillis?.let {
        intent.putExtra(HEAPDUMP_DURATION_MILLIS, heapDumpDurationMillis)
      }
      startForegroundService(context, intent)
    }
```

接下来切换到`HeapAnalyzerService`开始进行Hprof文件解析流程。

### Hprof解析

在`HeapAnalyzerService`收到传过来的Hprof文件地址后，就要开始解析

```kotlin
//HeapAnalyzerService  
private fun analyzeHeap(
    heapDumpFile: File,
    config: Config
  ): HeapAnalysis {
    val heapAnalyzer = HeapAnalyzer(this)

    val proguardMappingReader = try {
      ProguardMappingReader(assets.open(PROGUARD_MAPPING_FILE_NAME))
    } catch (e: IOException) {
      null
    }
    return heapAnalyzer.analyze(
        heapDumpFile = heapDumpFile,
        leakingObjectFinder = config.leakingObjectFinder,
        referenceMatchers = config.referenceMatchers,
        computeRetainedHeapSize = config.computeRetainedHeapSize,
        objectInspectors = config.objectInspectors,
        metadataExtractor = config.metadataExtractor,
        proguardMapping = proguardMappingReader?.readProguardMapping()
    )
  }

```

解析前需要了解一下{% post_link Hprof文件解析 Hprof结构%}，在此基础上进行Hprof解析的相关流程分析。

> 简单说明一下Hprof的相关结构
>
> 主要分为两部分：
>
> - Header：主要包含一些元信息，例如`文件协议的版本`、`开始`和`结束的时间戳`，以及`标识符大小`
> - Record：主要结构为`TAG`、`TIME`、`LENGTH(BODY数据长度)`和`BODY`
>   - TAG：表示`Record`类型，重要的有`HEAP_DUMP_SEGMENT`和`STRING`等

#### Shark.HeapAnalyzer

> `Shark`是一款分析`Hprof文件`的工具，性能高且占用内存少，非常适合手机端的Hprof文件解析功能。
>
> 目的是**提供快速解析Hprof文件和分析的能力。**

```kotlin
//HeapAnalyzer.kt 
fun analyze(
    heapDumpFile: File,
    leakingObjectFinder: LeakingObjectFinder,
    referenceMatchers: List<ReferenceMatcher> = emptyList(),
    computeRetainedHeapSize: Boolean = false,
    objectInspectors: List<ObjectInspector> = emptyList(),
    metadataExtractor: MetadataExtractor = MetadataExtractor.NO_OP,
    proguardMapping: ProguardMapping? = null
  ): HeapAnalysis {
    ...
    return try {
      listener.onAnalysisProgress(PARSING_HEAP_DUMP)
      val sourceProvider = ConstantMemoryMetricsDualSourceProvider(FileSourceProvider(heapDumpFile))
      sourceProvider.openHeapGraph(proguardMapping).use { graph ->
       //                                                  
        val helpers =
          FindLeakInput(graph, referenceMatchers, computeRetainedHeapSize, objectInspectors)
        val result = helpers.analyzeGraph(
            metadataExtractor, leakingObjectFinder, heapDumpFile, analysisStartNanoTime
        )
        result.copy(metadata = result.metadata + ("Stats" to stats))
      }
    } catch (exception: Throwable) {

    }  
    
  }
```

##### openHeapGraph

主要用来按照格式解析Hprof文件

```kotlin
//HprofHeapGraph.kt
    fun DualSourceProvider.openHeapGraph(
      proguardMapping: ProguardMapping? = null,
      indexedGcRootTypes: Set<HprofRecordTag> = HprofIndex.defaultIndexedGcRootTags()
    ): CloseableHeapGraph {
      //主要负责解析 Hprof head部分的数据
      val header = openStreamingSource().use { HprofHeader.parseHeaderOf(it) }
      val index = HprofIndex.indexRecordsOf(this, header, proguardMapping, indexedGcRootTypes)
      return index.openHeapGraph()
    }

//HprofIndex.kt
    fun indexRecordsOf(
      hprofSourceProvider: DualSourceProvider,
      hprofHeader: HprofHeader,
      proguardMapping: ProguardMapping? = null,
      indexedGcRootTags: Set<HprofRecordTag> = defaultIndexedGcRootTags()
    ): HprofIndex {
      val reader = StreamingHprofReader.readerFor(hprofSourceProvider, hprofHeader)
      val index = HprofInMemoryIndex.indexHprof(
          reader = reader,
          hprofHeader = hprofHeader,
          proguardMapping = proguardMapping,
          indexedGcRootTags = indexedGcRootTags
      )
      return HprofIndex(hprofSourceProvider, hprofHeader, index)
    }
```

将Hprof中的`Record`解析成`HprofMemoryIndex`，将Record按照Tag进行分析和计数，并通过特定规则进行排序。



最终通过`openHeapGraph()`组合得到`HprofHeapGraph`对象，等价于`Hprof文件`转换成了`HprofHeapGraph`对象。

```kotlin
//HprofHeapGraph.kt
class HprofHeapGraph internal constructor(
  private val header: HprofHeader,
  private val reader: RandomAccessHprofReader,
  private val index: HprofInMemoryIndex
) : CloseableHeapGraph {
  
  ...
  //缓存可以成为 GC Roots的对象
  override val gcRoots: List<GcRoot>
    get() = index.gcRoots()
  
  //记录的是所有对象
  override val objects: Sequence<HeapObject>
  
  //对应TAG为 CLASS_DUMP
  override val classes: Sequence<HeapClass>
  
  //对应TAG为 INSTANCE_DUMP
  override val instances: Sequence<HeapInstance>
  
  
}
```



内部主要包括了`gcRoots`、`objects`、`classes`和`instances`几种集合，可以快速定位dump堆中的对象。



##### FindLeakInput

主要分析泄漏对象

```kotlin
///HeapAnalyzer.kt
  fun analyze(
    heapDumpFile: File,
    graph: HeapGraph,
    leakingObjectFinder: LeakingObjectFinder,
    referenceMatchers: List<ReferenceMatcher> = emptyList(),
    computeRetainedHeapSize: Boolean = false,
    objectInspectors: List<ObjectInspector> = emptyList(),
    metadataExtractor: MetadataExtractor = MetadataExtractor.NO_OP
  ): HeapAnalysis {

    return try {
      val helpers =
        FindLeakInput(graph, referenceMatchers, computeRetainedHeapSize, objectInspectors)
      helpers.analyzeGraph(
          metadataExtractor, leakingObjectFinder, heapDumpFile, analysisStartNanoTime
      )
    } catch (exception: Throwable) {
      )
    }
  }
```

接下来执行到`analyzeGraph`

```kotlin
  private fun FindLeakInput.analyzeGraph(
    metadataExtractor: MetadataExtractor,
    leakingObjectFinder: LeakingObjectFinder,
    heapDumpFile: File,
    analysisStartNanoTime: Long
  ): HeapAnalysisSuccess {
    listener.onAnalysisProgress(EXTRACTING_METADATA)
    val metadata = metadataExtractor.extractMetadata(graph)

    listener.onAnalysisProgress(FINDING_RETAINED_OBJECTS)
    val leakingObjectIds = leakingObjectFinder.findLeakingObjectIds(graph)

    val (applicationLeaks, libraryLeaks) = findLeaks(leakingObjectIds)
    
    return HeapAnalysisSuccess(
        heapDumpFile = heapDumpFile,
        createdAtTimeMillis = System.currentTimeMillis(),
        analysisDurationMillis = since(analysisStartNanoTime),
        metadata = metadata,
        applicationLeaks = applicationLeaks,
        libraryLeaks = libraryLeaks
    )    

  }

  private fun FindLeakInput.findLeaks(leakingObjectIds: Set<Long>): Pair<List<ApplicationLeak>, List<LibraryLeak>> {
    val pathFinder = PathFinder(graph, listener, referenceMatchers)
    val pathFindingResults =
      pathFinder.findPathsFromGcRoots(leakingObjectIds, computeRetainedHeapSize)
    //找寻最短路径
    val shortestPaths =
      deduplicateShortestPaths(pathFindingResults.pathsToLeakingObjects)
    val inspectedObjectsByPath = inspectObjects(shortestPaths)
    return buildLeakTraces(shortestPaths, inspectedObjectsByPath, retainedSizes)
  }
```

主要执行流程分为3步：

###### findLeakingObjectIds

> 寻找泄漏的对象

设置的`leakingObjectFinder`实际就是`KeyedWeakReferenceFinder`

```kotlin
//KeyedWeakReferenceFinder.kt
  override fun findLeakingObjectIds(graph: HeapGraph): Set<Long> =
    findKeyedWeakReferences(graph).map { it.referent.value }
        .toSet()

  internal fun findKeyedWeakReferences(graph: HeapGraph): List<KeyedWeakReferenceMirror> {
    return graph.context.getOrPut(KEYED_WEAK_REFERENCE.name) {
      val keyedWeakReferenceClass = graph.findClassByName("leakcanary.KeyedWeakReference")

      val keyedWeakReferenceClassId = keyedWeakReferenceClass?.objectId ?: 0
      val legacyKeyedWeakReferenceClassId =
        graph.findClassByName("com.squareup.leakcanary.KeyedWeakReference")?.objectId ?: 0

      val heapDumpUptimeMillis = heapDumpUptimeMillis(graph)

      val addedToContext: List<KeyedWeakReferenceMirror> = graph.instances
          .filter { instance ->
            instance.instanceClassId == keyedWeakReferenceClassId || instance.instanceClassId == legacyKeyedWeakReferenceClassId
          }
          .map {
            KeyedWeakReferenceMirror.fromInstance(
                it, heapDumpUptimeMillis
            )
          }
          .filter { it.hasReferent }
          .toList()
      graph.context[KEYED_WEAK_REFERENCE.name] = addedToContext
      addedToContext
    }
  }
```

主要就是实现了 找寻`instance`实例中的被`KeyedWeakReference`所包装的实例，因为在最前面`watch`的过程中，需要监控的对象都是被`KeyedWeakReference`所包装的，既然能在`isntance`中找到就意味着这些对象是发生了内存泄漏的。

###### findPathsFromGcRoots

> 寻找泄漏对象到GC Roots对象的引用路径

```kotlin
//PathFinder.kt 
fun findPathsFromGcRoots(
    leakingObjectIds: Set<Long>,
    computeRetainedHeapSize: Boolean
  ): PathFindingResults {
...
    val state = State(
        leakingObjectIds = leakingObjectIds.toLongScatterSet(),
        sizeOfObjectInstances = sizeOfObjectInstances,
        computeRetainedHeapSize = computeRetainedHeapSize,
        javaLangObjectId = javaLangObjectId,
        estimatedVisitedObjects = estimatedVisitedObjects
    )

    return state.findPathsFromGcRoots()
  }

//找寻泄漏对象 到 GC Roots对象的路径
  private fun State.findPathsFromGcRoots(): PathFindingResults {
    enqueueGcRoots()

    val shortestPathsToLeakingObjects = mutableListOf<ReferencePathNode>()
    visitingQueue@ while (queuesNotEmpty) {
      val node = poll()
      if (node.objectId in leakingObjectIds) {
        shortestPathsToLeakingObjects.add(node)
        // Found all refs, stop searching (unless computing retained size)
        if (shortestPathsToLeakingObjects.size == leakingObjectIds.size()) {
          if (computeRetainedHeapSize) {
            listener.onAnalysisProgress(FINDING_DOMINATORS)
          } else {
            break@visitingQueue
          }
        }
      }

      when (val heapObject = graph.findObjectById(node.objectId)) {
        is HeapClass -> visitClassRecord(heapObject, node)
        is HeapInstance -> visitInstance(heapObject, node)
        is HeapObjectArray -> visitObjectArray(heapObject, node)
      }
    }
    return PathFindingResults(
        shortestPathsToLeakingObjects,
        if (visitTracker is Dominated) visitTracker.dominatorTree else null
    )
  }
```

总体思路

> 采用**广度优先遍历**从`GC Roots`开始遍历，直到`泄漏对象`为止。
>
> `广度优先遍历`：从根节点出发，沿着树宽度依此遍历树的每个节点。**借助队列结构实现**
>
>  
>
> 以`GC Roots对象`为树的根节点，然后从根节点开始遍历，对每个节点依据类型的不同采取对应的模式进行访问并得到对象，然后引用继续抽象成为`Node`加入队列以待后续遍历，直到遍历到`Node`为`leakObjectId`，期间经过的所有Node对象连在一起就是一次完整的引用路径。
>
> 最终得到的就是`泄漏对象 到 GC Roots对象`的引用路径。

###### deduplicateShortestPaths

> 根据多条引用路径，进行裁剪得到最短的引用路径

```kotlin
  private fun deduplicateShortestPaths(
    inputPathResults: List<ReferencePathNode>
  ): List<ShortestPath> {
    //根节点为0
    val rootTrieNode = ParentNode(0)

    inputPathResults.forEach { pathNode ->
      // Go through the linked list of nodes and build the reverse list of instances from
      // root to leaking.
      val path = mutableListOf<Long>()
      var leakNode: ReferencePathNode = pathNode
      while (leakNode is ChildNode) {
        path.add(0, leakNode.objectId)
        leakNode = leakNode.parent
      }
      path.add(0, leakNode.objectId)
      updateTrie(pathNode, path, 0, rootTrieNode)
    }

  }

  private fun updateTrie(
    pathNode: ReferencePathNode,
    path: List<Long>,
    pathIndex: Int,
    parentNode: ParentNode
  ) {
    val objectId = path[pathIndex]
    if (pathIndex == path.lastIndex) {
      parentNode.children[objectId] = LeafNode(objectId, pathNode)
    } else {
      val childNode = parentNode.children[objectId] ?: {
        val newChildNode = ParentNode(objectId)
        parentNode.children[objectId] = newChildNode
        newChildNode
      }()
      if (childNode is ParentNode) {
        updateTrie(pathNode, path, pathIndex + 1, childNode)
      }
    }
  }

```

总体思路：

> 一个对象被很多对象引用是很正常的行为，所以`泄漏对象`和`GC Roots对象`之间可能存在多条引用路径，此时就需要进行裁剪得到最短的引用路径方便分析。
>
>  
>
> 将路径反转成为`GC Roots对象 到 泄漏对象`的的引用路径，然后通过`updateTrie()`转化成为无效Node为根节点的树，最后经过`深度优先遍历`得到从`根节点`到`叶子节点`的所有路径，即为最终的`最短引用路径`。
>
> `深度优先遍历`：从树的根节点开始，先遍历左子树再遍历右子树。**借助栈结构实现**。



###### buildLeakTraces

> 建立泄漏路径

```kotlin
//HeapAnalzer.kt
  private fun buildLeakTraces(
    shortestPaths: List<ShortestPath>,
    inspectedObjectsByPath: List<List<InspectedObject>>,
    retainedSizes: Map<Long, Pair<Int, Int>>?
  ): Pair<List<ApplicationLeak>, List<LibraryLeak>> {
    ...
    shortestPaths.forEachIndexed { pathIndex, shortestPath ->
      val inspectedObjects = inspectedObjectsByPath[pathIndex]
      //构建内存泄漏对象
      val leakTraceObjects = buildLeakTraceObjects(inspectedObjects, retainedSizes)
      //构建引用路径
      val referencePath = buildReferencePath(shortestPath.childPath, leakTraceObjects)

      val leakTrace = LeakTrace(
          gcRootType = GcRootType.fromGcRoot(shortestPath.root.gcRoot),
          referencePath = referencePath,
          leakingObject = leakTraceObjects.last()
      )

      val firstLibraryLeakNode = if (shortestPath.root is LibraryLeakNode) {
        shortestPath.root
      } else {
        shortestPath.childPath.firstOrNull { it is LibraryLeakNode } as LibraryLeakNode?
      }

      if (firstLibraryLeakNode != null) {
        val matcher = firstLibraryLeakNode.matcher
        val signature: String = matcher.pattern.toString()
            .createSHA1Hash()
        libraryLeaksMap.getOrPut(signature) { matcher to mutableListOf() }
            .second += leakTrace
      } else {
        //添加到 应用内存泄漏列表中
        applicationLeaksMap.getOrPut(leakTrace.signature) { mutableListOf() } += leakTrace
      }
    }    
    
  }

```

最终构建得到`ApplicationLeak`和`LibraryLeak`，组装得到`HeapAnalysis`

- `ApplicationLeak`：在开发工程中应用自身导致的内存泄漏

- `LibraryLeak`：`is a Leak caused by a known bug in third party code that you do not have control over. `已知的系统内存泄漏问题。

  [Explain Library Leaks in fundamentals](https://github.com/square/leakcanary/pull/1785)

```kotlin
//HeapAnalyzerService.kt

override fun onHandleIntentInForeground(intent: Intent?) {
    if (intent == null || !intent.hasExtra(HEAPDUMP_FILE_EXTRA)) {
      SharkLog.d { "HeapAnalyzerService received a null or empty intent, ignoring." }
      return
    }

    // Since we're running in the main process we should be careful not to impact it.
    Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
    val heapDumpFile = intent.getSerializableExtra(HEAPDUMP_FILE_EXTRA) as File
    val heapDumpDurationMillis = intent.getLongExtra(HEAPDUMP_DURATION_MILLIS, -1)
//获取 LeakCanary的配置
    val config = LeakCanary.config
    val heapAnalysis = if (heapDumpFile.exists()) {
      //解析 hprof文件
      analyzeHeap(heapDumpFile, config)
    } else {
      missingFileFailure(heapDumpFile)
    }
    val fullHeapAnalysis = when (heapAnalysis) {
      is HeapAnalysisSuccess -> heapAnalysis.copy(dumpDurationMillis = heapDumpDurationMillis)
      is HeapAnalysisFailure -> heapAnalysis.copy(dumpDurationMillis = heapDumpDurationMillis)
    }
    onAnalysisProgress(REPORTING_HEAP_ANALYSIS)
  //解析完成后 回调 onHeapAnalyzed
    config.onHeapAnalyzedListener.onHeapAnalyzed(fullHeapAnalysis)
  }
```

解析完成后，回调到`onHeapAnalyzedListener`中的`onHeapAnalyzed()`.

其中`config `配置的`onHeapAnalyzedListener`为`DefaultOnHeapAnalyzedListener`

```kotlin
//DefaultOnHeapAnalyzedListener.kt
  override fun onHeapAnalyzed(heapAnalysis: HeapAnalysis) {
    SharkLog.d { "\u200B\n${LeakTraceWrapper.wrap(heapAnalysis.toString(), 120)}" }

    val id = LeaksDbHelper(application).writableDatabase.use { db ->
      HeapAnalysisTable.insert(db, heapAnalysis)
    }

    val (contentTitle, screenToShow) = when (heapAnalysis) {
      is HeapAnalysisFailure -> application.getString(
          R.string.leak_canary_analysis_failed
      ) to HeapAnalysisFailureScreen(id)
      is HeapAnalysisSuccess -> {
        val retainedObjectCount = heapAnalysis.allLeaks.sumBy { it.leakTraces.size }
        val leakTypeCount = heapAnalysis.applicationLeaks.size + heapAnalysis.libraryLeaks.size
        application.getString(
            R.string.leak_canary_analysis_success_notification, retainedObjectCount, leakTypeCount
        ) to HeapDumpScreen(id)
      }
    }

    //显示通知 提示已经解析完毕
      showNotification(screenToShow, contentTitle)

  }
```

## 总结

1.LeakCanary整套流程从`注册监听Activity/Fragment对象生命周期`开始，当对应组件销毁时`添加对应组件的观察`。

- 在`onActivityDestroyed()`添加对`Activity`的观察
- 在`onFragmentViewDestroyed()`添加对`Fragment中的View`的观察
- 在`onFragmentDestroyed()`添加对`Fragment`的观察
- 可以通过`AppWatcher.objectWatcher.watch(XX)`添加自定义对象的观察。

2.在`泄漏检测`时，通过`WeakRefrence`包装`被观察的对象`，然后等待**5s**后，检查与`WeakReference`绑定的`ReferenceQueue`中是否包含`被观察对象`，若包含表示`被观察对象`已被回收；否则，判断对象可能泄漏。*5s并不一定是执行了GC，只是一个估值，一般都会触发GC。*

3.在`准备DumpHeap`前，还会再去`手动执行一次GC`，等待**100ms**后如果还存在`泄漏对象`，就需要准备dump内存数据。此时有一个阈值，如果泄漏对象超过**5个**，才会去dump，避免频繁执行dump流程。

4.通过执行`Debug.dumpHprofData()`去生成`Hprof文件`，等待`Hprof文件`生成后，发送到`HeapAnalyzerService`去处理该文件。

5.`HeapAnalyzerService`收到`Hprof文件`后，通过**Shark**对文件进行解析，按照`Hprof文件格式`进行解析，解析得到`HprofHeapGraph`对象，内部包含`gcRoots`、`instances`、`classes`、`objects`等集合，可以快速定位泄漏对象。

6.得到`HprofHeapGraph`对象后，开始分析内存泄漏的最短路径。*内存泄漏的对象仍然与GC Roots对象保持可达的引用路径，导致GC无法释放。——一般用的都是`可达性分析`*。

- `寻找内存泄漏对象`：在`instances`集合中寻找`instanceClassId`为`KeyedWeakReferences`的对象，这些就是前面所观察的对象。
- `寻找所有内存泄漏对象与GC Roots对象的引用路径`：采用`广度优先遍历`，从`Gc Roots对象`开始遍历到`内存泄漏对象`的所有引用路径
- `裁剪所有路径得到 最短引用路径`：采用`深度优先遍历`，得到`内存泄漏对象`到`GC Roots对象`的最短引用路径
- `通知内存泄漏检测完毕`：将`最短引用路径`包装成`LeakTrace`，按照**是否为应用自身导致的内存泄漏**分为两个对象：`ApplicationLeak`和`LibraryLeak`。



## 参考链接

[LeakCanary Wiki](https://square.github.io/leakcanary/getting_started/)

[LeakCanary解析](https://linjiang.tech/2019/12/25/leakcanary/)