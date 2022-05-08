---
title: Glide源码解析要点
date: 2018-03-18 19:36:39
tags: 源码解析
top: 11
---
<!-- TODO Glide如何加载大图 BitmapPool的使用-->

> 该源码解析是基于最新的Glide 4.8.0进行的

## Glide基本流程分析

Glide的基本使用代码

```java
Glide.with(context).load($img$).apply(RequestOptions().transform(MultiTransformation(CenterCrop(),CircleCrop())).placeholder(R.drawable.ic_default_avatar)).into(imageView);
```

按照上述的基本使用代码，Glide的加载过程可以分为以下几步：

### `Glide对象初始化`

初始化代码是从`Glide.get()`开始的，在其中主要做了一些事情

```java Glide.java
 @NonNull
  public static Glide get(@NonNull Context context) {
    //Glide对象时一个单例模式
    if (glide == null) {
      synchronized (Glide.class) {
        if (glide == null) {
          checkAndInitializeGlide(context);
        }
      }
    }

    return glide;
  }

//检查Glide对象是否初始化完毕
private static void checkAndInitializeGlide(@NonNull Context context) {
    // In the thread running initGlide(), one or more classes may call Glide.get(context).
    // Without this check, those calls could trigger infinite recursion.
    if (isInitializing) {
      throw new IllegalStateException("You cannot call Glide.get() in registerComponents(),"
          + " use the provided Glide instance instead");
    }
    isInitializing = true;
    //真正初始化Glide的代码
    initializeGlide(context);
    isInitializing = false;
  }
```

初始化Glide时再调用到`initializeGlide()`去进行真正的初始化工作

```java Glide.java
  private static void initializeGlide(@NonNull Context context) {
    initializeGlide(context, new GlideBuilder());
  }

  private static void initializeGlide(@NonNull Context context, @NonNull GlideBuilder builder) {
    Context applicationContext = context.getApplicationContext();
    GeneratedAppGlideModule annotationGeneratedModule = getAnnotationGeneratedGlideModules();
    List<com.bumptech.glide.module.GlideModule> manifestModules = Collections.emptyList();
    //是否使用Manifest配置的GlideModule
    if (annotationGeneratedModule == null || annotationGeneratedModule.isManifestParsingEnabled()) {
      manifestModules = new ManifestParser(applicationContext).parse();
    }

    if (annotationGeneratedModule != null
        && !annotationGeneratedModule.getExcludedModuleClasses().isEmpty()) {
      Set<Class<?>> excludedModuleClasses =
          annotationGeneratedModule.getExcludedModuleClasses();
      Iterator<com.bumptech.glide.module.GlideModule> iterator = manifestModules.iterator();
      while (iterator.hasNext()) {
        com.bumptech.glide.module.GlideModule current = iterator.next();
        if (!excludedModuleClasses.contains(current.getClass())) {
          continue;
        }
        if (Log.isLoggable(TAG, Log.DEBUG)) {
          Log.d(TAG, "AppGlideModule excludes manifest GlideModule: " + current);
        }
        iterator.remove();
      }
    }

    if (Log.isLoggable(TAG, Log.DEBUG)) {
      for (com.bumptech.glide.module.GlideModule glideModule : manifestModules) {
        Log.d(TAG, "Discovered GlideModule from manifest: " + glideModule.getClass());
      }
    }

    RequestManagerRetriever.RequestManagerFactory factory =
        annotationGeneratedModule != null
            ? annotationGeneratedModule.getRequestManagerFactory() : null;
    builder.setRequestManagerFactory(factory);
    for (com.bumptech.glide.module.GlideModule module : manifestModules) {
      //循环调用Module中的 applyOptions方法
      //applyOptions的作用是 配置Glide加载时的图片缓存路径以及缓存空间大小
      module.applyOptions(applicationContext, builder);
    }
    if (annotationGeneratedModule != null) {
      //调用注解配置Module中的 applyOptions方法
      //applyOptions的作用是 配置Glide加载时的图片缓存路径以及缓存空间大小
      annotationGeneratedModule.applyOptions(applicationContext, builder);
    }
    //创建Glide对象
    Glide glide = builder.build(applicationContext);
    //循环调用Module中的 registerComponents()
    //registerComponents的作用是 注册指定类型的数据源，以及加载图片使用ModelLoader
    for (com.bumptech.glide.module.GlideModule module : manifestModules) {
      module.registerComponents(applicationContext, glide, glide.registry);
    }
    //调用注解配置Module中的 registerComponents()
    //registerComponents的作用是 注册指定类型的数据源，以及加载图片使用ModelLoader
    if (annotationGeneratedModule != null) {
      annotationGeneratedModule.registerComponents(applicationContext, glide, glide.registry);
    }
    applicationContext.registerComponentCallbacks(glide);
    Glide.glide = glide;
  }
```

源码中发现`GlideModule`分为两种`manifestModules`和`annotationGeneratedModule`，其中`manifestModules`是为了兼容V3版本，以前的都是配置在`AndroidManifest.xml`中，而V4版本采用注解的方式，取消了清单文件中的配置。

```java 示例配置文件
@GlideModule
public class CustomGlideModule extends AppGlideModule {
    @Override
    public void applyOptions(Context context, GlideBuilder builder) {

        MemorySizeCalculator calculator = new MemorySizeCalculator.Builder(context).build();
        int defaultMemoryCacheSize = calculator.getMemoryCacheSize();
        int defaultBitmapPoolSize = calculator.getBitmapPoolSize();

        int customMemoryCacheSize = (int) (1.2 * defaultMemoryCacheSize);
        int customBitmapPoolSize = (int) (1.2 * defaultBitmapPoolSize);

        builder.setMemoryCache(new LruResourceCache(customMemoryCacheSize));
        builder.setBitmapPool(new LruBitmapPool(customBitmapPoolSize));
    }

    @Override
    public void registerComponents(Context context, Glide glide, Registry registry) {
        registry.replace(GlideUrl.class, InputStream.class, new OkHttpUrlLoader.Factory(ProgressManager.getOkHttpClient()));
    }

    @Override
    public boolean isManifestParsingEnabled() {
        return false;
    }
}

```

配置好`GlideModule`文件后，就需要去调用其中的`applyOptions()`设置Glide加载基本配置项，然后调用到了`GlideBuilder.build()`去构造Glide对象，最后调用其中的`regeisterComponents()`设置加载器。

接下来分析构造Glide对象的方法——`GlideBuilder.build()`

```java
  @NonNull
  Glide build(@NonNull Context context) {
    //设置加载图片的线程池
    if (sourceExecutor == null) {
      sourceExecutor = GlideExecutor.newSourceExecutor();
    }
    //写入本地磁盘缓存的线程池
    if (diskCacheExecutor == null) {
      diskCacheExecutor = GlideExecutor.newDiskCacheExecutor();
    }
    //执行动画的线程池
    if (animationExecutor == null) {
      animationExecutor = GlideExecutor.newAnimationExecutor();
    }
    //计算内存缓存大小
    if (memorySizeCalculator == null) {
      memorySizeCalculator = new MemorySizeCalculator.Builder(context).build();
    }

    if (connectivityMonitorFactory == null) {
      connectivityMonitorFactory = new DefaultConnectivityMonitorFactory();
    }
    //bitmap缓存池
    if (bitmapPool == null) {
      int size = memorySizeCalculator.getBitmapPoolSize();
      if (size > 0) {
        bitmapPool = new LruBitmapPool(size);
      } else {
        bitmapPool = new BitmapPoolAdapter();
      }
    }

    if (arrayPool == null) {
      arrayPool = new LruArrayPool(memorySizeCalculator.getArrayPoolSizeInBytes());
    }
    //内存缓存
    if (memoryCache == null) {
      memoryCache = new LruResourceCache(memorySizeCalculator.getMemoryCacheSize());
    }
    //硬盘缓存
    if (diskCacheFactory == null) {
      diskCacheFactory = new InternalCacheDiskCacheFactory(context);
    }
    
    if (engine == null) {
      engine =
          new Engine(
              memoryCache,
              diskCacheFactory,
              diskCacheExecutor,
              sourceExecutor,
              GlideExecutor.newUnlimitedSourceExecutor(),
              GlideExecutor.newAnimationExecutor(),
              isActiveResourceRetentionAllowed);
    }

    if (defaultRequestListeners == null) {
      defaultRequestListeners = Collections.emptyList();
    } else {
      defaultRequestListeners = Collections.unmodifiableList(defaultRequestListeners);
    }

    RequestManagerRetriever requestManagerRetriever =
        new RequestManagerRetriever(requestManagerFactory);

    return new Glide(
        context,
        engine,
        memoryCache,
        bitmapPool,
        arrayPool,
        requestManagerRetriever,
        connectivityMonitorFactory,
        logLevel,
        defaultRequestOptions.lock(),
        defaultTransitionOptions,
        defaultRequestListeners,
        isLoggingRequestOriginsEnabled);
  }
```

当`GlideBuilder.build()`执行完毕后，最终调用到`new Glide()`完成初始化。其中关键参数为`Registry`后续的操作都需要用到该参数。

### `with()`

> 对Glide的生命周期进行管理。

Glide对象初始化完毕后，首先会调用到的就是`with()`

```java Glide.java
@NonNull
  public static RequestManager with(@NonNull Context context) {
    return getRetriever(context).get(context);
  }

  @NonNull
  public static RequestManager with(@NonNull Activity activity) {
    return getRetriever(activity).get(activity);
  }

  @NonNull
  public static RequestManager with(@NonNull FragmentActivity activity) {
    return getRetriever(activity).get(activity);
  }

  @NonNull
  public static RequestManager with(@NonNull Fragment fragment) {
    return getRetriever(fragment.getActivity()).get(fragment);
  }

  @NonNull
  public static RequestManager with(@NonNull View view) {
    return getRetriever(view.getContext()).get(view);
  }
```

`with()`有5种重载方法，最后调用到的都是`getRetriever(context).get()`

```java RequestManagerRetriever.java
  @NonNull
  public RequestManager get(@NonNull Context context) {
    if (context == null) {
      throw new IllegalArgumentException("You cannot start a load on a null Context");
    } else if (Util.isOnMainThread() && !(context instanceof Application)) {
      if (context instanceof FragmentActivity) {
        return get((FragmentActivity) context);
      } else if (context instanceof Activity) {
        return get((Activity) context);
      } else if (context instanceof ContextWrapper) {
        return get(((ContextWrapper) context).getBaseContext());
      }
    }

    return getApplicationManager(context);
  }

  @NonNull
  public RequestManager get(@NonNull FragmentActivity activity) {
    if (Util.isOnBackgroundThread()) {
      return get(activity.getApplicationContext());
    } else {
      assertNotDestroyed(activity);
      FragmentManager fm = activity.getSupportFragmentManager();
      return supportFragmentGet(
          activity, fm, /*parentHint=*/ null, isActivityVisible(activity));
    }
  }

  @NonNull
  public RequestManager get(@NonNull Fragment fragment) {
    Preconditions.checkNotNull(fragment.getActivity(),
          "You cannot start a load on a fragment before it is attached or after it is destroyed");
    if (Util.isOnBackgroundThread()) {
      return get(fragment.getActivity().getApplicationContext());
    } else {
      FragmentManager fm = fragment.getChildFragmentManager();
      return supportFragmentGet(fragment.getActivity(), fm, fragment, fragment.isVisible());
    }
  }

  @SuppressWarnings("deprecation")
  @NonNull
  public RequestManager get(@NonNull Activity activity) {
    if (Util.isOnBackgroundThread()) {
      return get(activity.getApplicationContext());
    } else {
      assertNotDestroyed(activity);
      android.app.FragmentManager fm = activity.getFragmentManager();
      return fragmentGet(
          activity, fm, /*parentHint=*/ null, isActivityVisible(activity));
    }
  }

  public RequestManager get(@NonNull View view) {
    if (Util.isOnBackgroundThread()) {
      return get(view.getContext().getApplicationContext());
    }

    Preconditions.checkNotNull(view);
    Preconditions.checkNotNull(view.getContext(),
        "Unable to obtain a request manager for a view without a Context");
    Activity activity = findActivity(view.getContext());
    // The view might be somewhere else, like a service.
    if (activity == null) {
      return get(view.getContext().getApplicationContext());
    }

    // Support Fragments.
    if (activity instanceof FragmentActivity) {
      Fragment fragment = findSupportFragment(view, (FragmentActivity) activity);
      return fragment != null ? get(fragment) : get(activity);
    }

    // Standard Fragments.
    android.app.Fragment fragment = findFragment(view, activity);
    if (fragment == null) {
      return get(activity);
    }
    return get(fragment);
  }

```

简单分析上述源码可知，调用流程如下：

- 首先判断当前调用是否在子线程，在子线程的话，直接调用`ApplicationContext`获取`ReqeustManager`
- 不在子线程即运行在主线程时，需要判断`context`类型
  - `support.Fragment或者support.FragmentActivity`：调用`supportFragmentGet()`
  - `app.Activity或者app.fragment`：调用`fragmentGet()`
  - `Application`：调用`getApplicationManager()`
  - `view.getContext`：需要判断view的context类型，然后再走一次上面的步骤

根据流程分析，监听生命周期的方式主要是通过`监听一个无UI的Fragment(位于主线程且有对应的context存在)`和`监听Application(当位于后台线程或者contxt为Application)`。

其中`无UI的Fragment`对应源码中的两个类`RequestManagerFragment`、`SupportRequestFragment`在其中构造了`ActivityFragmentLifecycle`对象，在其中的关键生命周期进行联动，就可以对应的去进行加载和取消加载操作了。

```java RequestManagerFragment.java
 @Override
  public void onStart() {
    super.onStart();
    lifecycle.onStart();
  }

  @Override
  public void onStop() {
    super.onStop();
    lifecycle.onStop();
  }

  @Override
  public void onDestroy() {
    super.onDestroy();
    lifecycle.onDestroy();
    unregisterFragmentWithRoot();
  }
```

然后最后返回的`RequestManager`对象自身也会实现`LifecycleListener`接口，就可以根据对应调用跳转加载过程

```java RequestManager.java
//实现了LifecycleListener接口
public class RequestManager implements LifecycleListener{
 
  //主线程中执行
private final Runnable addSelfToLifecycle = new Runnable() {
    @Override
    public void run() {
      lifecycle.addListener(RequestManager.this);
    }
  };
...
  @Override
  public void onStart() {
    resumeRequests();
    targetTracker.onStart();//targetTracker监听
  }
  
  @Override
  public void onStop() {
    pauseRequests();
    targetTracker.onStop();//targetTracker监听
  }
  
  public void resumeRequests() {
    Util.assertMainThread();
    requestTracker.resumeRequests();//requestTracker监听
  }
  
  public void pauseRequests() {
    Util.assertMainThread();
    requestTracker.pauseRequests();//requestTracker监听
  }
  
  @Override
  public void onDestroy() {
    targetTracker.onDestroy();//targetTracker监听
    for (Target<?> target : targetTracker.getAll()) {
      clear(target);
    }
    targetTracker.clear();//targetTracker监听
    requestTracker.clearRequests();//requestTracker监听
    lifecycle.removeListener(this);
    lifecycle.removeListener(connectivityMonitor);
    mainHandler.removeCallbacks(addSelfToLifecycle);
    glide.unregisterRequestManager(this);
  }
}
```

完成上述流程后，RequestManager就可以实现对Fragment的监听，也就等同于实现了Glide的生命周期。

{% fullimage /images/Glide的with.png,Glide的with过程,Glide的with过程%}

### `load()`

> 传入需要加载的图片信息，通过`with()`得到的`RequestManager`进行加载。

```java RequestManager.java
 @NonNull
  @CheckResult
  @Override
  public RequestBuilder<Drawable> load(@Nullable Bitmap bitmap) {
    return asDrawable().load(bitmap);
  }

  @NonNull
  @CheckResult
  @Override
  public RequestBuilder<Drawable> load(@Nullable Drawable drawable) {
    return asDrawable().load(drawable);
  }

  @NonNull
  @CheckResult
  @Override
  public RequestBuilder<Drawable> load(@Nullable String string) {
    return asDrawable().load(string);
  }

  @NonNull
  @CheckResult
  @Override
  public RequestBuilder<Drawable> load(@Nullable Uri uri) {
    return asDrawable().load(uri);
  }

  @NonNull
  @CheckResult
  @Override
  public RequestBuilder<Drawable> load(@Nullable File file) {
    return asDrawable().load(file);
  }

  @SuppressWarnings("deprecation")
  @NonNull
  @CheckResult
  @Override
  public RequestBuilder<Drawable> load(@RawRes @DrawableRes @Nullable Integer resourceId) {
    return asDrawable().load(resourceId);
  }

  @SuppressWarnings("deprecation")
  @CheckResult
  @Override
  @Deprecated
  public RequestBuilder<Drawable> load(@Nullable URL url) {
    return asDrawable().load(url);
  }

  @NonNull
  @CheckResult
  @Override
  public RequestBuilder<Drawable> load(@Nullable byte[] model) {
    return asDrawable().load(model);
  }

  @NonNull
  @CheckResult
  @Override
  public RequestBuilder<Drawable> load(@Nullable Object model) {
    return asDrawable().load(model);
  }
```

经过`load()`分析，Glide加载的类型支持`Bitmap`、`Drawable`、`String(图片地址)`、`Uri`、`File(图片文件)`、`Integer(图片ResourceId)`、`URL`、`byte`，`Object`。

实际内部调用到的是`asDrawable.load()`

```java
  public RequestBuilder<Drawable> asDrawable() {
    return as(Drawable.class);
  }

  @NonNull
  @CheckResult
  public RequestBuilder<Bitmap> asBitmap() {
    return as(Bitmap.class).apply(DECODE_TYPE_BITMAP);
  }

  @NonNull
  @CheckResult
  public RequestBuilder<GifDrawable> asGif() {
    return as(GifDrawable.class).apply(DECODE_TYPE_GIF);
  }

  @NonNull
  @CheckResult
  public <ResourceType> RequestBuilder<ResourceType> as(
      @NonNull Class<ResourceType> resourceClass) {
    return new RequestBuilder<>(glide, this, resourceClass, context);
  }
```

通过`asDrawable()`得到`RequestBuilder`对象，接下来走到`ReqeustBuilder.load()`

```java RequestBuilder.java
public RequestBuilder<TranscodeType> load(@Nullable Bitmap bitmap) {
    return loadGeneric(bitmap)
        .apply(diskCacheStrategyOf(DiskCacheStrategy.NONE));
  }
  
  public RequestBuilder<TranscodeType> load(@Nullable Drawable drawable) {
    return loadGeneric(drawable)
        .apply(diskCacheStrategyOf(DiskCacheStrategy.NONE));
  }
  
  public RequestBuilder<TranscodeType> load(@Nullable String string) {
    return loadGeneric(string);
  }
  
  public RequestBuilder<TranscodeType> load(@Nullable Uri uri) {
    return loadGeneric(uri);
  }
  
  public RequestBuilder<TranscodeType> load(@Nullable File file) {
    return loadGeneric(file);
  }
  
  private RequestBuilder<TranscodeType> loadGeneric(@Nullable Object model) {
    this.model = model;
    isModelSet = true;
    return this;
  }
  
  public RequestBuilder<TranscodeType> load(@Nullable Object model) {
    return loadGeneric(model);
  }
```

上述的`load()`都调用到了`loadGeneric()`然后进行了赋值操作，确定了`model`数据，然后完成了load流程。

//TODO 流程图

### `apply()`

> 设置一些额外配置，例如占位图、加载错误图片、图片显示类型，圆角什么的

`load()`流程结束后就得到了`RequestBuilder`对象，调用其中的`apply()`

```java
  public class RequestBuilder<TranscodeType> extends BaseRequestOptions<RequestBuilder<TranscodeType>> implements Cloneable, ModelTypes<RequestBuilder<TranscodeType>> {
      ...
  @NonNull
  @CheckResult
  @Override
  public RequestBuilder<TranscodeType> apply(@NonNull BaseRequestOptions<?> requestOptions) {
    Preconditions.checkNotNull(requestOptions);
    return super.apply(requestOptions);
  }
      
      ...
}
```

调用到了`super.apply()`其实就是`BaseRequestOptions.apply()`

```java BaseRequestOptions.java
 @NonNull
  @CheckResult
  public T apply(@NonNull BaseRequestOptions<?> o) {
    if (isAutoCloneEnabled) {
      return clone().apply(o);
    }
    BaseRequestOptions<?> other = o;

    if (isSet(other.fields, SIZE_MULTIPLIER)) {
      sizeMultiplier = other.sizeMultiplier;
    }
    ...
    fields |= other.fields;
    options.putAll(other.options);

    return selfOrThrowIfLocked();
  }
```

`isSet()`是判断该属性是否设置，若已设置过则替换，设置完毕后，得到一个`RequestBuilder`对象，不过已经设置了`RequestOptions`里面包含了一些显示上以及缓存上的配置。

### `into()`——最关键步骤

> 进行图片的加载与显示

#### 创建请求`Request`

起点是从`RequestBuilder.into()`开始

```java RequestBuilder.java
  @NonNull
  public ViewTarget<ImageView, TranscodeType> into(@NonNull ImageView view) {
    Util.assertMainThread();
    Preconditions.checkNotNull(view);
    //获取apply()设置的 RequestOptions
    BaseRequestOptions<?> requestOptions = this;
    //是否设置了RequestOptions的ScaleType，未设置则使用ImageView的android:scaleType
    if (!requestOptions.isTransformationSet()
        && requestOptions.isTransformationAllowed()
        && view.getScaleType() != null) {
      switch (view.getScaleType()) {
        case CENTER_CROP:
          requestOptions = requestOptions.clone().optionalCenterCrop();
          break;
        case CENTER_INSIDE:
          requestOptions = requestOptions.clone().optionalCenterInside();
          break;
        case FIT_CENTER:
        case FIT_START:
        case FIT_END:
          requestOptions = requestOptions.clone().optionalFitCenter();
          break;
        case FIT_XY:
          requestOptions = requestOptions.clone().optionalCenterInside();
          break;
        case CENTER:
        case MATRIX:
        default:
          // Do nothing.
      }
    }

    return into(
        glideContext.buildImageViewTarget(view, transcodeClass),
        /*targetListener=*/ null,
        requestOptions,
        Executors.mainThreadExecutor());
  }

  private <Y extends Target<TranscodeType>> Y into(
      @NonNull Y target,
      @Nullable RequestListener<TranscodeType> targetListener,
      BaseRequestOptions<?> options,
      Executor callbackExecutor) {
    Preconditions.checkNotNull(target);
    if (!isModelSet) {
      throw new IllegalArgumentException("You must call #load() before calling #into()");
    }
    //构建Request请求对象
    Request request = buildRequest(target, targetListener, options, callbackExecutor);
    
    Request previous = target.getRequest();
    if (request.isEquivalentTo(previous)
        && !isSkipMemoryCacheWithCompletePreviousRequest(options, previous)) {
      request.recycle();
      if (!Preconditions.checkNotNull(previous).isRunning()) {
        previous.begin();
      }
      return target;
    }

    requestManager.clear(target);
    //给当前View设置请求
    target.setRequest(request);
    requestManager.track(target, request);

    return target;
  }
```

通过`buildRequest()`构建图片加载请求对象。

```java RequestBuilder.java
 private Request buildRequest(
      Target<TranscodeType> target,
      @Nullable RequestListener<TranscodeType> targetListener,
      BaseRequestOptions<?> requestOptions,
      Executor callbackExecutor) {
    return buildRequestRecursive(
        target,
        targetListener,
        /*parentCoordinator=*/ null,
        transitionOptions,
        requestOptions.getPriority(),
        requestOptions.getOverrideWidth(),
        requestOptions.getOverrideHeight(),
        requestOptions,
        callbackExecutor);
  }

  private Request buildRequestRecursive(...) {
    
    ErrorRequestCoordinator errorRequestCoordinator = null;
    //判断当前是否设置了 RequestBuilder.error()
    if (errorBuilder != null) {
      errorRequestCoordinator = new ErrorRequestCoordinator(parentCoordinator);
      parentCoordinator = errorRequestCoordinator;
    }
    //生成可能带有缩略图显示的Request
    Request mainRequest =
        buildThumbnailRequestRecursive(...);
    
    if (errorRequestCoordinator == null) {
      return mainRequest;
    }
    //生成带有错误处理的Request
    Request errorRequest =
        errorBuilder.buildRequestRecursive(...);
    errorRequestCoordinator.setRequests(mainRequest, errorRequest);
    return errorRequestCoordinator;
    ...
      
  }

private Request buildThumbnailRequestRecursive(...) {
    //是否设置了 RequestBuilder.thumbnailBuilder(RequestBuilder thumbnailBuilder)
    if (thumbnailBuilder != null) {
      if (isThumbnailBuilt) {
        throw new IllegalStateException("You cannot use a request as both the main request and a "
            + "thumbnail, consider using clone() on the request(s) passed to thumbnail()");
      }

      TransitionOptions<?, ? super TranscodeType> thumbTransitionOptions =
          thumbnailBuilder.transitionOptions;

      // Apply our transition by default to thumbnail requests but avoid overriding custom options
      // that may have been applied on the thumbnail request explicitly.
      if (thumbnailBuilder.isDefaultTransitionOptionsSet) {
        thumbTransitionOptions = transitionOptions;
      }

      Priority thumbPriority = thumbnailBuilder.isPrioritySet()
          ? thumbnailBuilder.getPriority() : getThumbnailPriority(priority);

      int thumbOverrideWidth = thumbnailBuilder.getOverrideWidth();
      int thumbOverrideHeight = thumbnailBuilder.getOverrideHeight();
      if (Util.isValidDimensions(overrideWidth, overrideHeight)
          && !thumbnailBuilder.isValidOverride()) {
        thumbOverrideWidth = requestOptions.getOverrideWidth();
        thumbOverrideHeight = requestOptions.getOverrideHeight();
      }

      ThumbnailRequestCoordinator coordinator = new ThumbnailRequestCoordinator(parentCoordinator);
ThumbnailRequestCoordinator coordinator = new ThumbnailRequestCoordinator(parentCoordinator);
      Request fullRequest =
          obtainRequest(...);
      isThumbnailBuilt = true;
      // Recursively generate thumbnail requests.
      Request thumbRequest =
          thumbnailBuilder.buildRequestRecursive(...);
      isThumbnailBuilt = false;
      coordinator.setRequests(fullRequest, thumbRequest);
      return coordinator;
    }
  //是否设置了 RequestBuilder.thumbnailBuilder(floar thumbSizeMultiplier)  对应的缩放比例
  else if (thumbSizeMultiplier != null) {
      // Base case: thumbnail multiplier generates a thumbnail request, but cannot recurse.
      ThumbnailRequestCoordinator coordinator = new ThumbnailRequestCoordinator(parentCoordinator);
      Request fullRequest = obtainRequest(...);
      BaseRequestOptions<?> thumbnailOptions =
          requestOptions.clone().sizeMultiplier(thumbSizeMultiplier);

      Request thumbnailRequest =
          obtainRequest(...);

      coordinator.setRequests(fullRequest, thumbnailRequest);
      return coordinator;
    } else {
      // 没有设置 thunbmail相关参数
      return obtainRequest(...);
    }
  }

 private Request obtainRequest(
      Target<TranscodeType> target,
      RequestListener<TranscodeType> targetListener,
      BaseRequestOptions<?> requestOptions,
      RequestCoordinator requestCoordinator,
      TransitionOptions<?, ? super TranscodeType> transitionOptions,
      Priority priority,
      int overrideWidth,
      int overrideHeight,
      Executor callbackExecutor) {
    return SingleRequest.obtain(...);
  }
```

{% fullimage /images/Glide创建请求.png,Glide创建请求,Glide创建请求%}

总结一下创建请求的流程，最后调用的是`SingleRequest`对象。

- 通过`RequestBuilder.buildRequest()`创建`Request`对象，调用到`buildRequestRecursive()`执行创建逻辑

- 先判断设置过`RequestBuilder.error()`参数，如果设置过`errorRequest`，需要通过`errorRequest`和`mainRequest`得到`ErrorRequestCoordinator(实现Request接口)`对象。

- 没设置过`RequestBuilder.error()`参数，则向下判断是否设置过`ReqeustBuilder.thumbnail()`参数，设置`ReqeustBuilder.thumbnail()`有两种方法：

  - `ReqeustBuilder.thumbnail(RequestBuilder thumbnailBuilder)`：自定义要显示的缩略图
  - `ReqeustBuilder.thumbnail(float thumbSizeMultiper)`：设置原图缩放比例

  只要设置了其中的一种，就会产生`thumbRequest`对象，然后与`fullRequest`得到`ThumbnailRequestCoordinator(实现Request接口)`对象。

- `ReqeustBuilder.thumbnail()`也未设置，则最终调用`SingleRequest.obtain()`得到`SingleRequest(实现Request接口)`对象。

>  `errorRequest`表示了加载错误的请求
>
>  `thumbRequest`表示了缩略图加载请求
>
>  `mainRequest`和`fullRequest`都代表了原始图片加载请求。

上述创建请求流程执行完毕后，就是发送请求。

#### 发送请求

> 发送请求通过调用`Request`实现。

在[创建请求](#创建请求)中，创建完成后会调用到`requestManager.track(target, request);`去发送请求

```java RequestManager.java
  synchronized void track(@NonNull Target<?> target, @NonNull Request request) {
    //监听target的生命周期
    targetTracker.track(target);
    //开启请求
    requestTracker.runRequest(request);
  }
```

```java  RequestTracker.java
  public void runRequest(@NonNull Request request) {
    requests.add(request);
    if (!isPaused) {
      //开始启动
      request.begin();
    } else {
      request.clear();
      if (Log.isLoggable(TAG, Log.VERBOSE)) {
        Log.v(TAG, "Paused, delaying request");
      }
      pendingRequests.add(request);
    }
  }
```

接下来就是调用到`Request.begin()`，`Request`是一个接口，`singleRequest`是具体的实现类，即调用到`SingleRequest.begin()`

```java SingleRequest.java
  @Override
  public synchronized void begin() {
    assertNotCallingCallbacks();
    stateVerifier.throwIfRecycled();
    startTime = LogTime.getLogTime();
    if (model == null) {
      if (Util.isValidDimensions(overrideWidth, overrideHeight)) {
        width = overrideWidth;
        height = overrideHeight;
      }
      int logLevel = getFallbackDrawable() == null ? Log.WARN : Log.DEBUG;
      //返回加载失败
      onLoadFailed(new GlideException("Received null model"), logLevel);
      return;
    }
    
    if (status == Status.RUNNING) {
      throw new IllegalArgumentException("Cannot restart a running request");
    }
    //加载完成
    if (status == Status.COMPLETE) {
      onResourceReady(resource, DataSource.MEMORY_CACHE);
      return;
    }
    
    status = Status.WAITING_FOR_SIZE;
    //判断设置大小是否合理
    if (Util.isValidDimensions(overrideWidth, overrideHeight)) {
      onSizeReady(overrideWidth, overrideHeight);
    } else {
      //不合理 获取ImageView的size
      target.getSize(this);
    }

    if ((status == Status.RUNNING || status == Status.WAITING_FOR_SIZE)
        && canNotifyStatusChanged()) {
      //回调Target onLoadStarted()
      target.onLoadStarted(getPlaceholderDrawable());
    }
    if (IS_VERBOSE_LOGGABLE) {
      logV("finished run method in " + LogTime.getElapsedMillis(startTime));
    }
  }

@Override
  public synchronized void onSizeReady(int width, int height) {
    stateVerifier.throwIfRecycled();
    if (IS_VERBOSE_LOGGABLE) {
      logV("Got onSizeReady in " + LogTime.getElapsedMillis(startTime));
    }
    if (status != Status.WAITING_FOR_SIZE) {
      return;
    }
    //更新请求状态为 请求中
    status = Status.RUNNING;

    float sizeMultiplier = requestOptions.getSizeMultiplier();
    this.width = maybeApplySizeMultiplier(width, sizeMultiplier);
    this.height = maybeApplySizeMultiplier(height, sizeMultiplier);

    if (IS_VERBOSE_LOGGABLE) {
      logV("finished setup for calling load in " + LogTime.getElapsedMillis(startTime));
    }
    //开始加载图片
    loadStatus = engine.load(...);
    if (status != Status.RUNNING) {
      loadStatus = null;
    }
    if (IS_VERBOSE_LOGGABLE) {
      logV("finished onSizeReady in " + LogTime.getElapsedMillis(startTime));
    }
  }

```

上述流程主要是去计算得到 被加载图片的尺寸信息，如果手动设置了尺寸通过`override`那么通过合法性校验后，加载的图片大小就会为用户设置尺寸，否则使用`Target`的尺寸信息。

> `Target`是一个接口，主要意义是提供View的确切尺寸信息以及对回调结果进行处理。

{% fullimage /images/Glide发送请求.png,Glide发送请求,Glide发送请求%}

#### 加载图片

接下来调用`Engine.load()`开始加载图片，包括三级缓存的部分。

```java Engine.java
public synchronized <R> LoadStatus load(...) {
    long startTime = VERBOSE_IS_LOGGABLE ? LogTime.getLogTime() : 0;

    EngineKey key = keyFactory.buildKey(model, signature, width, height, transformations,
        resourceClass, transcodeClass, options);
    //读取内存中的弱引用
    EngineResource<?> active = loadFromActiveResources(key, isMemoryCacheable);
    if (active != null) {
      cb.onResourceReady(active, DataSource.MEMORY_CACHE);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Loaded resource from active resources", startTime, key);
      }
      return null;
    }
    //读取内存缓存
    EngineResource<?> cached = loadFromCache(key, isMemoryCacheable);
    if (cached != null) {
      cb.onResourceReady(cached, DataSource.MEMORY_CACHE);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Loaded resource from cache", startTime, key);
      }
      return null;
    }
    
    EngineJob<?> current = jobs.get(key, onlyRetrieveFromCache);
    if (current != null) {
      current.addCallback(cb, callbackExecutor);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Added to existing load", startTime, key);
      }
      return new LoadStatus(cb, current);
    }

    EngineJob<R> engineJob =
        engineJobFactory.build(
            key,
            isMemoryCacheable,
            useUnlimitedSourceExecutorPool,
            useAnimationPool,
            onlyRetrieveFromCache);

    DecodeJob<R> decodeJob =
        decodeJobFactory.build(...);

    jobs.put(key, engineJob);

    engineJob.addCallback(cb, callbackExecutor);
    //若从两级内存缓存中 都没有找到 则开启DecodeJob去加载图片
    engineJob.start(decodeJob);

    if (VERBOSE_IS_LOGGABLE) {
      logWithTimeAndKey("Started new load", startTime, key);
    }
    return new LoadStatus(cb, engineJob);
  }
```

在`Engine.load()`，主要执行逻辑是：先从`一级内存缓存-弱引用`中查找指定资源，找不到则去`二级内存缓存-LRUCache`中去查找，再没有就转到`DecodeJob`去加载图片。

加载图片的具体实现细节会单独在[Glide缓存实现原理](#Glide缓存实现原理)说明。

#### 显示图片

当图片从三级缓存中取出后，最终得到的是一个`Resource`对象，然后再回调到`SingleRequest.onResourceReady()`中

```java SingleRequest.java
  @Override
  public synchronized void onResourceReady(Resource<?> resource, DataSource dataSource) {
    stateVerifier.throwIfRecycled();
    loadStatus = null;
    if (resource == null) {
      //回调加载失败事件
      onLoadFailed(exception);
      return;
    }

    Object received = resource.get();
    if (received == null || !transcodeClass.isAssignableFrom(received.getClass())) {
      //回收资源
      releaseResource(resource);

      onLoadFailed(exception);
      return;
    }

    if (!canSetResource()) {
      releaseResource(resource);
      // 设置加载状态完成
      status = Status.COMPLETE;
      return;
    }

    onResourceReady((Resource<R>) resource, (R) received, dataSource);
  }

  private synchronized void onResourceReady(Resource<R> resource, R result, DataSource dataSource) {
    // We must call isFirstReadyResource before setting status.
    boolean isFirstResource = isFirstReadyResource();
    status = Status.COMPLETE;
    this.resource = resource;

    if (glideContext.getLogLevel() <= Log.DEBUG) {
      Log.d(GLIDE_TAG, "Finished loading " + result.getClass().getSimpleName() + " from "
          + dataSource + " for " + model + " with size [" + width + "x" + height + "] in "
          + LogTime.getElapsedMillis(startTime) + " ms");
    }

    isCallingCallbacks = true;
    try {
      boolean anyListenerHandledUpdatingTarget = false;
      if (requestListeners != null) {
        for (RequestListener<R> listener : requestListeners) {
          anyListenerHandledUpdatingTarget |=
              listener.onResourceReady(result, model, target, dataSource, isFirstResource);
        }
      }
      anyListenerHandledUpdatingTarget |=
          targetListener != null
              && targetListener.onResourceReady(result, model, target, dataSource, isFirstResource);

      if (!anyListenerHandledUpdatingTarget) {
        Transition<? super R> animation =
            animationFactory.build(dataSource, isFirstResource);
        target.onResourceReady(result, animation);
      }
    } finally {
      isCallingCallbacks = false;
    }
    
    notifyLoadSuccess();
  }
```

在`SingleRequest.onSourceReady()`主要回调了`Target.onResourceReady()`，把`Resource`显示到`Target`上，实质就是`into()`传入的Target对象。

```java ImageViewTarget.java
  @Override
  public void onResourceReady(@NonNull Z resource, @Nullable Transition<? super Z> transition) {
    if (transition == null || !transition.transition(resource, this)) {
      setResourceInternal(resource);
    } else {
      maybeUpdateAnimatable(resource);
    }
  }

  private void setResourceInternal(@Nullable Z resource) {
    // Order matters here. Set the resource first to make sure that the Drawable has a valid and
    // non-null Callback before starting it.
    setResource(resource);
    maybeUpdateAnimatable(resource);
  }

 protected abstract void setResource(@Nullable Z resource);
```

其中有两个类继承了`ImageViewTarget`用于实现不同的功能。分别是`DrawableImageViewTarget`、`BitmapImageViewTarget`。

```java DrawableImageViewTarget.java
public class DrawableImageViewTarget extends ImageViewTarget<Drawable> {

  public DrawableImageViewTarget(ImageView view) {
    super(view);
  }

  /**
   * @deprecated Use {@link #waitForLayout()} instead.
   */
  // Public API.
  @SuppressWarnings({"unused", "deprecation"})
  @Deprecated
  public DrawableImageViewTarget(ImageView view, boolean waitForLayout) {
    super(view, waitForLayout);
  }

  @Override
  protected void setResource(@Nullable Drawable resource) {
    view.setImageDrawable(resource);
  }
}
```

最终通过`ImageView.setImageDrawable()`将图片显示在ImageView上。

{% fullimage /images/Glide显示图片.png,Glide显示图片,Glide显示图片%}

## Glide缓存实现原理

> Glide的缓存主要分成了两个模块，一个是**内存缓存**，另一部分是**硬盘缓存**。
>
> **内存缓存**：防止应用重复将图片数据读取到内存当中
>
> **硬盘缓存**：防止应用重复从网络或其他地方重复下载和读取数据

### 缓存配置

1.在自定义的`GlideModule`中的`applyOptions()`中设置具体的缓存参数

```java
@GlideModule
public class CustomGlideModule extends AppGlideModule {
    @Override
    public void applyOptions(Context context, GlideBuilder builder) {
        MemorySizeCalculator calculator = new MemorySizeCalculator.Builder(context).build();
        int defaultMemoryCacheSize = calculator.getMemoryCacheSize();
        int defaultBitmapPoolSize = calculator.getBitmapPoolSize();
        int customMemoryCacheSize = (int) (1.2 * defaultMemoryCacheSize);
        int customBitmapPoolSize = (int) (1.2 * defaultBitmapPoolSize);
        builder.setMemoryCache(new LruResourceCache(customMemoryCacheSize));
        builder.setBitmapPool(new LruBitmapPool(customBitmapPoolSize));
    }
}
```

2.在具体请求中设置缓存参数

```java
//设置 不在磁盘中进行缓存且内存中也不缓存
val requestBuilder =Glide.with(this).asBitmap().apply(RequestOptions().diskCacheStrategy(DiskCacheStrategy.NONE).skipMemoryCache(true)).load(path)
```

### 缓存Key

缓存功能，就需要有对应的缓存Key，应用可以根据这个Key找到对应的缓存文件。Glide的缓存Key生成代码如下

```java Engine.java
public synchronized <R> LoadStatus load(...）{
      EngineKey key = keyFactory.buildKey(model, signature, width, height, transformations,resourceClass, transcodeClass, options);
...
}
```

`model`对应的就是`load()`过程中传入的参数，例如传入`String(图片加载地址)`，那么对应的就是加载地址。决定生成Key的参数有很多。

如果设置了`override`修改了加载尺寸，那也会有不同的key生成。

### 内存缓存

默认情况下，内存缓存是自动开启的，加载图片完成后，就会默认在内存中缓存，然后下次再调用时就会从内存中直接读取显示，无需重新加载。

> 可以通过设置`skipMemoryCache(true)`来关闭内存缓存功能。

Glide中的内存缓存主要分为两部分处理：**弱引用复用机制**和**LRUCache**。

#### 弱引用复用 —— ActiveResources

> 从正在活动的资源中取出缓存进行复用

```java Engine.java
public synchronized <R> LoadStatus load(...){
  ...
    EngineResource<?> active = loadFromActiveResources(key, isMemoryCacheable);
    if (active != null) {
      cb.onResourceReady(active, DataSource.MEMORY_CACHE);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Loaded resource from active resources", startTime, key);
      }
      return null;
    }
  ...
}

  @Nullable
 private EngineResource<?> loadFromActiveResources(Key key, boolean isMemoryCacheable) {
    if (!isMemoryCacheable) {
      return null;
    }
    EngineResource<?> active = activeResources.get(key);
    if (active != null) {
      active.acquire();
    }
    return active;
  }
```

对应的Resource文件要从`ActiveResource`中获取

```java ActiveResource.java
final Map<Key, ResourceWeakReference> activeEngineResources = new HashMap<>();

  synchronized void deactivate(Key key) {
    ResourceWeakReference removed = activeEngineResources.remove(key);
    if (removed != null) {
      removed.reset();
    }
  }

@Nullable
  synchronized EngineResource<?> get(Key key) {
    //获取Key对应的弱引用对象
    ResourceWeakReference activeRef = activeEngineResources.get(key);
    if (activeRef == null) {
      return null;
    }
    EngineResource<?> active = activeRef.get();
    if (active == null) {
      cleanupActiveReference(activeRef);
    }
    return active;
  }

  //清除当前被GC的对象
  void cleanupActiveReference(@NonNull ResourceWeakReference ref) {
    synchronized (listener) {
      synchronized (this) {
        activeEngineResources.remove(ref.key);
        if (!ref.isCacheable || ref.resource == null) {
          return;
        }
        //创建新的Resource对象 ref.resource是强引用类型
        EngineResource<?> newResource =
            new EngineResource<>(ref.resource, /*isCacheable=*/ true, /*isRecyclable=*/ false);
        newResource.setResourceListener(ref.key, listener);
        //将ref缓存进内存中
        listener.onResourceReleased(ref.key, newResource);
      }
    }
  }

 @VisibleForTesting
  static final class ResourceWeakReference extends WeakReference<EngineResource<?>> {
    @SuppressWarnings("WeakerAccess") @Synthetic final Key key;
    @SuppressWarnings("WeakerAccess") @Synthetic final boolean isCacheable;
    @Nullable @SuppressWarnings("WeakerAccess") @Synthetic Resource<?> resource;
    @Synthetic
    @SuppressWarnings("WeakerAccess")
    ResourceWeakReference(
        @NonNull Key key,
        @NonNull EngineResource<?> referent,
        @NonNull ReferenceQueue<? super EngineResource<?>> queue,
        boolean isActiveResourceRetentionAllowed) {
      super(referent, queue);
      this.key = Preconditions.checkNotNull(key);
      this.resource =
          referent.isCacheable() && isActiveResourceRetentionAllowed
              ? Preconditions.checkNotNull(referent.getResource()) : null;
      isCacheable = referent.isCacheable();
    }
    //清除强引用部分，方便回收
    void reset() {
      resource = null;
      clear();
    }
  }
```

`listener`对应的就是`Engine`对象，调用到`Engine.onResourceReleased()`

```java Engine.java
  @Override
  public synchronized void onResourceReleased(Key cacheKey, EngineResource<?> resource) {   
    //清除该key的强引用
    activeResources.deactivate(cacheKey);
    if (resource.isCacheable()) {
      //缓存数据到内存缓存LRUCache中
      cache.put(cacheKey, resource);
    } else {
      resourceRecycler.recycle(resource);
    }
  }
```

`ActivieResources`采用`HashMap + WeakReference`来保存`EngineResource`，不会有上限。然后`get()`从`activeEngineResources`弱引用HashMap中获取数据，这里分为两种情况：

1. 获取到弱引用关联对象`EngineResource`，则直接返回结果
2. 获取不到关联对象，则需进行清除工作调用`cleanupActiveResource()`，在`activeEngineResources`移除对应的key和引用，在判断是否开启缓存，若开启则缓存至`LRUCache`中。

总结：

`ActiveResources`采用弱引用的方式，里面存储的是`EngineResource`，同时采用强引用保存`EngineResource.resource`，在`ActiveResources`中还会有一个清理线程在运行，负责当`EngineResource`被回收时，就去取出对应的`EngineResource.resource`，然后创建一个新的`EngineResource`对象，回调到`Engine.onResourceReleased()`中，在其中做内存缓存，之后调用`ActivityResources.deactivate()`移除对应的强引用。

{% fullimage /images/内存缓存-弱引用机制.png,内存缓存-弱引用机制,内存缓存-弱引用机制%}

#### LRUCache

> 在当前活动资源中没有对应的缓存时，就要从内存中去进行读取

```java Engine.java
public synchronized <R> LoadStatus load(...){
  ...
    EngineResource<?> cached = loadFromCache(key, isMemoryCacheable);
    if (cached != null) {
      cb.onResourceReady(cached, DataSource.MEMORY_CACHE);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Loaded resource from cache", startTime, key);
      }
      return null;
    }
}

  private EngineResource<?> loadFromCache(Key key, boolean isMemoryCacheable) {
    //不允许缓存 直接返回null
    if (!isMemoryCacheable) {
      return null;
    }

    EngineResource<?> cached = getEngineResourceFromCache(key);①
    if (cached != null) {
      cached.acquire();
      //存入活动资源中
      activeResources.activate(key, cached);②
    }
    return cached;
  }

  private EngineResource<?> getEngineResourceFromCache(Key key) {
    Resource<?> cached = cache.remove(key);③

    final EngineResource<?> result;
    if (cached == null) {
      result = null;
    } else if (cached instanceof EngineResource) {
      result = (EngineResource<?>) cached;
    } else {
      result = new EngineResource<>(cached, true /*isMemoryCacheable*/, true /*isRecyclable*/);
    }
    return result;
  }
```

`loadFromCache()`实际调用到`getEngineResourceFromCache()`获取内存缓存中的资源，如果找到，缓存数量+1，然后会把`cached`放入`ActiveResources`中，变为活动资源，对应的要在`内存缓存`中移除引用。

①`getEngineResourceFromCache(key)`：从内存缓存中根据缓存key获取缓存

②`activeResources.activate(key, cached)`：取出的缓存数据存入到活动资源中

```java ActiveResources.java
  synchronized void activate(Key key, EngineResource<?> resource) {
    //构件新的 弱引用对象
    ResourceWeakReference toPut =
        new ResourceWeakReference(
            key, resource, resourceReferenceQueue, isActiveResourceRetentionAllowed);
    
    ResourceWeakReference removed = activeEngineResources.put(key, toPut);
    //如果存在替换，也需要把旧数据回收
    if (removed != null) {
      removed.reset();
    }
  }
```

③`cache.remove(key)`：从内存缓存中移除对应缓存

`cache`对应的是`MemoryCache`是一个接口，实现类为`LruResourceCache`

```java LruResourceCache.java
public class LruResourceCache extends LruCache<Key, Resource<?>> implements MemoryCache {
  private ResourceRemovedListener listener;

  public LruResourceCache(long size) {
    super(size);
  }

  //监听资源移除
  @Override
  public void setResourceRemovedListener(@NonNull ResourceRemovedListener listener) {
    this.listener = listener;
  }

  //当前缓存被淘汰是调用
  @Override
  protected void onItemEvicted(@NonNull Key key, @Nullable Resource<?> item) {
    if (listener != null && item != null) {
      listener.onResourceRemoved(item);
    }
  }
  //获取当前缓存大小
  @Override
  protected int getSize(@Nullable Resource<?> item) {
    if (item == null) {
      return super.getSize(null);
    } else {
      return item.getSize();
    }
  }

  @SuppressLint("InlinedApi")
  @Override
  //内存不足时 触发
  public void trimMemory(int level) {
    if (level >= android.content.ComponentCallbacks2.TRIM_MEMORY_BACKGROUND) {
      clearMemory();
    } else if (level >= android.content.ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN
        || level == android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL) {
      trimToSize(getMaxSize() / 2);
    }
  }
}
```

`LruResourceCache`继承自`LruCache`，不过内部计算缓存大小是通过`Resource`对象的大小累计，还增加了资源移除监听，为了和`ActiveResources`进行联动。

`LruResourceCache`的`size`是在自定义`GlideModule`中的 `applyOptions()`时设置进来的，如果未设置会采用`MemorySizeCalculator.getMemoryCacheSize()`设置。

当前在内存中缓存的对象都是`Resource`，而不是通常认为的Bitmap，下面会介绍到转码的过程。

{% fullimage /images/内存缓存-LruCache.png,内存缓存-LruCache,内存缓存-LruCache%}

#### 小结

在`内存缓存`中，分为两种方案：**从弱引用中获取**、**从内存缓存中获取**。两者的关系简单概括就是：

> 读取内存缓存时，会优先从`ActiveResources`中读取，读取到的话，需要判断当前包装`Resource`的弱引用对象是否被回收，未回收则直接返回。被回收的话，需要重新包装`EngineResource.resource`然后存入到内存缓存中并需要移除`ActiveResources`对其的引用。
>
> 从`ActiveResources`中没有获取到对应缓存时，就从`LruResourceCache`中去获取，获取到的话，就需要从当前内存缓存中移除对应缓存引用，并存入到`ActiveResources`中。
>
> **实现了正在使用的图片通过弱引用进行缓存，未使用的图片通过LruCache进行缓存。**
>
> `ActiveResources`优先级高于`LruResourceCache`。

比较两者之间的区别：

|          | 弱引用获取                                     | 内存缓存获取                    |
| -------- | ---------------------------------------------- | ------------------------------- |
| 基础实现 | HashMap                                        | LinkedHashMap(*LruCache*)       |
| 可否禁用 | 用户无法禁用                                   | 通过`skipMemoryCache(true)`禁用 |
| 运行位置 | 内存                                           | 内存                            |
| 释放时机 | 依赖垃圾回收机制<br>**弱引用实现，GC时被回收** | 采用**最近最少使用**来淘汰数据  |

### 磁盘缓存

> 当内存中不存在缓存时，就会向下从硬盘中去读取缓存数据
>
> 通过设置`diskCacheStrategy(DiskCacheStrategy.NONE)`来关闭硬盘缓存功能。

```java Engine.java
public synchronized <R> LoadStatus load(...){
  ...
    //判断当前是否存在该任务 EngineJob
    // private final Map<Key, EngineJob<?>> jobs = new HashMap<>();
    EngineJob<?> current = jobs.get(key, onlyRetrieveFromCache);
    if (current != null) {
      //资源加载完毕通知回调
      current.addCallback(cb, callbackExecutor);
      if (VERBOSE_IS_LOGGABLE) {
        logWithTimeAndKey("Added to existing load", startTime, key);
      }
      return new LoadStatus(cb, current);
    }
    //内部维护线程池，用来管理资源加载
    EngineJob<R> engineJob =
        engineJobFactory.build(...);
    //用来进行资源加载
    DecodeJob<R> decodeJob =
        decodeJobFactory.build(... , engineJob);
    //插入任务列表中
    jobs.put(key, engineJob);

    engineJob.addCallback(cb, callbackExecutor);
    //开始进行加载
    engineJob.start(decodeJob);

}
```

从内存中读取不到缓存时，`Engine`尝试从`jobs`读取对应的`EngineJob`缓存，如存在就去回调`加载成功或加载失败`。不存在的话，就需要新建一个`EngineJob`以及`DecodeJob`去加载图片。

```java EngineJob.java
  public synchronized void start(DecodeJob<R> decodeJob) {
    this.decodeJob = decodeJob;
    GlideExecutor executor = decodeJob.willDecodeFromCache()
        ? diskCacheExecutor
        : getActiveSourceExecutor();
    executor.execute(decodeJob);
  }
```

通过线程池去执行`decodeJob`，`DecodeJob`实现了`Runnable`接口，`execute()`直接调用到`run()`

```java DecodeJob.java
 @SuppressWarnings("PMD.AvoidRethrowingException")
  @Override
  public void run() {
    //统计执行时长
    GlideTrace.beginSectionFormat("DecodeJob#run(model=%s)", model);
    DataFetcher<?> localFetcher = currentFetcher;
    try {
      if (isCancelled) {
        notifyFailed();
        return;
      }
      //实际执行逻辑
      runWrapped();
    } catch (CallbackException e) {
      throw e;
    } catch (Throwable t) {
      if (stage != Stage.ENCODE) {
        throwables.add(t);
        notifyFailed();
      }
      if (!isCancelled) {
        throw t;
      }
      throw t;
    } finally {
      // Keeping track of the fetcher here and calling cleanup is excessively paranoid, we call
      // close in all cases anyway.
      if (localFetcher != null) {
        localFetcher.cleanup();
      }
      GlideTrace.endSection();
    }
  }

  private void runWrapped() {
    switch (runReason) {
      case INITIALIZE:
        stage = getNextStage(Stage.INITIALIZE);
        currentGenerator = getNextGenerator();
        runGenerators();
        break;
      case SWITCH_TO_SOURCE_SERVICE:
        runGenerators();
        break;
      case DECODE_DATA:
        //解析数据并解码
        decodeFromRetrievedData();
        break;
      default:
        throw new IllegalStateException("Unrecognized run reason: " + runReason);
    }
  }

  private enum RunReason {
    //第一次执行
    INITIALIZE,
    //从Cache中去读取数据失败，则从其他渠道读取
    SWITCH_TO_SOURCE_SERVICE,
    //解析数据
    DECODE_DATA,
  }

```

调用`DecodeJob.run()`开始加载资源，内部调用`runWrapped()`，此时`runWrapped()`中会根据`runReason`执行不同的操作，`runReason`就是用于控制当前执行到的任务。

> `INITIALIZE`：第一次调用`run()`，执行目的是从`diskcache`中获取缓存
>
> `SWITCH_TO_SOURCE_SERVICE`：从`diskcache`中获取缓存失败，需要从数据源获取
>
> `DECODE_DATA`：缓存数据成功，对数据进行解析

#### 获取硬盘缓存数据

```java DecodeJob.java
//通过 RequestOptions.diskCacheStrategy() 设置
private DiskCacheStrategy diskCacheStrategy;

private void runGenerators() {
    currentThread = Thread.currentThread();
    startFetchTime = LogTime.getLogTime();
    boolean isStarted = false;
    while (!isCancelled && currentGenerator != null
        && !(isStarted = currentGenerator.startNext())) {
      stage = getNextStage(stage);
      currentGenerator = getNextGenerator();

      if (stage == Stage.SOURCE) {
        reschedule();
        return;
      }
    }
    // We've run out of stages and generators, give up.
    if ((stage == Stage.FINISHED || isCancelled) && !isStarted) {
      notifyFailed();
    }
  }

  private Stage getNextStage(Stage current) {
    switch (current) {
      case INITIALIZE:
        //支持转换后的图片缓存 返回状态就是RESOURCE_CACHE
        return diskCacheStrategy.decodeCachedResource()
            ? Stage.RESOURCE_CACHE : getNextStage(Stage.RESOURCE_CACHE);
      case RESOURCE_CACHE:
        //支持转换后的图片缓存 返回状态就是DATA_CACHE
        return diskCacheStrategy.decodeCachedData()
            ? Stage.DATA_CACHE : getNextStage(Stage.DATA_CACHE);
      case DATA_CACHE:
        //如果缓存已存在 就返回结束 否则去加载远程图片
        return onlyRetrieveFromCache ? Stage.FINISHED : Stage.SOURCE;
      case SOURCE:
      case FINISHED:
        return Stage.FINISHED;
      default:
        throw new IllegalArgumentException("Unrecognized stage: " + current);
    }
  }

  //根据不同的步骤 调用不同的Generator对象
  private DataFetcherGenerator getNextGenerator() {
    switch (stage) {
      case RESOURCE_CACHE:
        return new ResourceCacheGenerator(decodeHelper, this);
      case DATA_CACHE:
        return new DataCacheGenerator(decodeHelper, this);
      case SOURCE:
        return new SourceGenerator(decodeHelper, this);
      case FINISHED:
        return null;
      default:
        throw new IllegalStateException("Unrecognized stage: " + stage);
    }
  }

  private enum Stage {
    //加载初始状态
    INITIALIZE,
    //转换后图片的缓存
    RESOURCE_CACHE,
    //原图缓存
    DATA_CACHE,
    //远程图片
    SOURCE,
    //解析图片
    ENCODE,
    //加载完成
    FINISHED,
  }
```

`stage`对应`Stage`枚举类，可以通过`DiskCacheStrategy`得到`Stage`。

> `DiskCacheStrategy`参数解释：
>
> - `NONE`：表示不缓存任何内容
> - `DATA`：只缓存原始图片
> - `RESOURCE`：只缓存转换后的图片
> - `ALL`：原始图片和转换后的图片都进行缓存
> - `AUTOMATIC`：尝试选择最佳策略。针对加载数据类型进行区分：
>   - 加载本地图片：缓存原始图片
>   - 加载网络图片：缓存转换后的图片

`stage`默认尽量就是`INITIALIZE`，通过递归调用`getNextStage()`向下推进，并改变`stage`表示进行状态。`stage`的推进过程也表示了硬盘缓存的查找顺序。

| Stage          | 描述                                    |
| -------------- | --------------------------------------- |
| INITIALIZE     | 初始状态                                |
| RESOURCE_CACHE | 转换后缓存 调用`ResourceCacheGenerator` |
| DATA_CACHE     | 原图缓存 调用`DataCacheGenerator`       |
| SOURCE         | 远程获取图片 调用`SourceGenerator`      |
| ENCODE         | 解析资源，生成`Resource`对象            |
| FINISHED       | 解析完成                                |

查找缓存从`初始查找开始`->`查找转换后图片缓存`->`查找原图图片缓存`->`前面都没找到就去进行远程加载`->`加载完成后就开始解析数据`->`解析完成`。

查找缓存从`currentGenerator.startNext()`开始，就先从`ResourceCacheGenerator`开始

```java ResourceCacheGenerator.java
  private File cacheFile;
  public boolean startNext() {
    List<Key> sourceIds = helper.getCacheKeys();
    if (sourceIds.isEmpty()) {
      return false;
    }
    List<Class<?>> resourceClasses = helper.getRegisteredResourceClasses();
    if (resourceClasses.isEmpty()) {
      if (File.class.equals(helper.getTranscodeClass())) {
        return false;
      }
      throw new IllegalStateException(
         "Failed to find any load path from " + helper.getModelClass() + " to "
             + helper.getTranscodeClass());
    }
    while (modelLoaders == null || !hasNextModelLoader()) {
      resourceClassIndex++;
      if (resourceClassIndex >= resourceClasses.size()) {
        sourceIdIndex++;
        if (sourceIdIndex >= sourceIds.size()) {
          return false;
        }
        resourceClassIndex = 0;
      }

      Key sourceId = sourceIds.get(sourceIdIndex);
      Class<?> resourceClass = resourceClasses.get(resourceClassIndex);
      Transformation<?> transformation = helper.getTransformation(resourceClass);
      //构建磁盘缓存key
      currentKey =
          new ResourceCacheKey(// NOPMD AvoidInstantiatingObjectsInLoops
              helper.getArrayPool(),
              sourceId,
              helper.getSignature(),
              helper.getWidth(),
              helper.getHeight(),
              transformation,
              resourceClass,
              helper.getOptions());
      //根据Key去获取cacheFile
      cacheFile = helper.getDiskCache().get(currentKey);
      if (cacheFile != null) {
        sourceKey = sourceId;
        modelLoaders = helper.getModelLoaders(cacheFile);
        modelLoaderIndex = 0;
      }
    }

    loadData = null;
    boolean started = false;
    while (!started && hasNextModelLoader()) {
      //使用FileLoader去加载对应cache文件
      ModelLoader<File, ?> modelLoader = modelLoaders.get(modelLoaderIndex++);
      loadData = modelLoader.buildLoadData(cacheFile,
          helper.getWidth(), helper.getHeight(), helper.getOptions());
      if (loadData != null && helper.hasLoadPath(loadData.fetcher.getDataClass())) {
        started = true;
        loadData.fetcher.loadData(helper.getPriority(), this);
      }
    }

    return started;
  }
```

根据相关参数生成对应的`cacheKey`，然后从`DiskCache`中取出对应的`cacheFile`，然后使用`FileLoader`解析该文件。

> `helper.getDiskCache()`对应的就是`DiskLruCacheWrapper`类，内部包装了`DiskLruCache`，内部实现了整套的文件读写功能。

#### 远程获取数据

若为初次加载的数据，肯定不会在`diskCache`中获取到，就需要远程加载。

```java SourceGenerator.java
  public boolean startNext() {
    //判断当前是否存在缓存
    if (dataToCache != null) {
      Object data = dataToCache;
      dataToCache = null;
      
      cacheData(data);
    }
    //存在缓存
    if (sourceCacheGenerator != null && sourceCacheGenerator.startNext()) {
      return true;
    }
    sourceCacheGenerator = null;

    loadData = null;
    boolean started = false;
    while (!started && hasNextModelLoader()) {
      loadData = helper.getLoadData().get(loadDataListIndex++);
      if (loadData != null && (helper.getDiskCacheStrategy().isDataCacheable(loadData.fetcher.getDataSource())
          || helper.hasLoadPath(loadData.fetcher.getDataClass()))) {
        started = true;
        //加载远程图片
        loadData.fetcher.loadData(helper.getPriority(), this);
      }
    }
    return started;
  }
//缓存至磁盘中
private void cacheData(Object dataToCache) {
    long startTime = LogTime.getLogTime();
    try {
      Encoder<Object> encoder = helper.getSourceEncoder(dataToCache);
      DataCacheWriter<Object> writer =
          new DataCacheWriter<>(encoder, dataToCache, helper.getOptions());
      originalKey = new DataCacheKey(loadData.sourceKey, helper.getSignature());
      helper.getDiskCache().put(originalKey, writer);
      if (Log.isLoggable(TAG, Log.VERBOSE)) {
        Log.v(TAG, "Finished encoding source to cache"
            + ", key: " + originalKey
            + ", data: " + dataToCache
            + ", encoder: " + encoder
            + ", duration: " + LogTime.getElapsedMillis(startTime));
      }
    } finally {
      loadData.fetcher.cleanup();
    }

    sourceCacheGenerator =
        new DataCacheGenerator(Collections.singletonList(loadData.sourceKey), helper, this);
  }

  @Override
  public void onDataReady(Object data) {
    DiskCacheStrategy diskCacheStrategy = helper.getDiskCacheStrategy();
    if (data != null && diskCacheStrategy.isDataCacheable(loadData.fetcher.getDataSource())) {
      //上面判断是否cache
      dataToCache = data;
      cb.reschedule();
    } else {
      cb.onDataFetcherReady(loadData.sourceKey, data, loadData.fetcher,
          loadData.fetcher.getDataSource(), originalKey);
    }
  }
```

在`SourceGenerator.startNext()`会优先判断数据是否在`DiskCache`中，若存在调用`cacheData()`创建`DataCacheGenerator`调用其`startNext()`。不存在则循环去获取`loadData`，通过`DecodeHelper.getLoadData()`，然后继续执行`loadData.fetch.loadData()`去加载数据，加载成功后回调到`onDataReady()`。

现在开始按步骤分析：

##### 加载远程数据——地址加载(`HttpUrlFetcher`)

```java HttpUrlFetcher.java
 public void loadData(Priority priority, DataCallback<? super InputStream> callback) {
    try {
      InputStream result = loadDataWithRedirects(glideUrl.toURL(), 0, null, glideUrl.getHeaders());
      callback.onDataReady(result);
    } catch (IOException e) {
      callback.onLoadFailed(e);
    } finally {
    }
  }

```

##### 加载本地数据——本地文件加载(`ByteBufferFetcher`)

```java ByteBufferFileLoader.java
private static final class ByteBufferFetcher implements DataFetcher<ByteBuffer> {
  ...
     @Override
    public void loadData(@NonNull Priority priority,
        @NonNull DataCallback<? super ByteBuffer> callback) {
      ByteBuffer result;
      try {
        result = ByteBufferUtil.fromFile(file);
      } catch (IOException e) {
        if (Log.isLoggable(TAG, Log.DEBUG)) {
          Log.d(TAG, "Failed to obtain ByteBuffer for file", e);
        }
        callback.onLoadFailed(e);
        return;
      }

      callback.onDataReady(result);
    }
}
```

`loadData()`成功后，回调到`SourceGenerator.onDataReady()`中。这时需要判断是否开启了硬盘缓存，如果关闭了直接回调到`DecodeJob.onDataFetcherReady()`，开启了的话，就继续调用到`DecodeJob.reschedule()`。

```jave DecodeJob.java
 @Override
  public void reschedule() {
    runReason = RunReason.SWITCH_TO_SOURCE_SERVICE;
    callback.reschedule(this);
  }

  @Override
  public void onDataFetcherReady(Key sourceKey, Object data, DataFetcher<?> fetcher,
      DataSource dataSource, Key attemptedKey) {
    this.currentSourceKey = sourceKey;
    this.currentData = data;
    this.currentFetcher = fetcher;
    this.currentDataSource = dataSource;
    this.currentAttemptingKey = attemptedKey;
    if (Thread.currentThread() != currentThread) {
      //向下执行 数据解析
      runReason = RunReason.DECODE_DATA;
      //再次调用到 runWrapped() 此时会走向 decodeFromRetrievedData()
      callback.reschedule(this);
    } else {
      GlideTrace.beginSection("DecodeJob.decodeFromRetrievedData");
      try {
        // 解析数据的真正逻辑
        decodeFromRetrievedData();
      } finally {
        GlideTrace.endSection();
      }
    }
  }
  
  private void runWrapped() {
    switch (runReason) {
      case INITIALIZE:
        stage = getNextStage(Stage.INITIALIZE);
        currentGenerator = getNextGenerator();
        runGenerators();
        break;
      case SWITCH_TO_SOURCE_SERVICE:
        runGenerators();
        break;
      case DECODE_DATA:
        //解析数据并解码
        decodeFromRetrievedData();
        break;
      default:
        throw new IllegalStateException("Unrecognized run reason: " + runReason);
    }
  }
```

在`reschedule()`，把`runReason`设为`SWITCH_TO_SOURCE_SERVICE`，继续调用到`EngineJob.reschedule()`，再次执行到`DecodeJob.run()`不过已经在一个新的线程池中继续执行。

在`onDataFetcherReady()`中，会判断当前线程是否相同，不同的话，设置`runReason`为`DECODE_DATA`，重新执行`EngineJob.reschedule()`还会走到`run()`中，继续执行到` decodeFromRetrievedData()`，线程相同则直接执行。

#### 解析数据

> 此时拿到的数据类型还是`InputStream`或者`ByteBuffer`，需要解析成常用的`File`或者`Bitmap`。

此时`runReason`为`DECODE_DATA`，调用到`decodeFromRetrievedData()`

```java DecodeJob.java
private Object currentData;  
private void decodeFromRetrievedData() {
    ...
    Resource<R> resource = null;
    try {
      resource = decodeFromData(currentFetcher, currentData, currentDataSource);
    } catch (GlideException e) {
      e.setLoggingDetails(currentAttemptingKey, currentDataSource);
      throwables.add(e);
    }
    if (resource != null) {
      notifyEncodeAndRelease(resource, currentDataSource);
    } else {
      runGenerators();
    }
  }

  private <Data> Resource<R> decodeFromData(DataFetcher<?> fetcher, Data data,
      DataSource dataSource) throws GlideException {
    try {
      ...
      Resource<R> result = decodeFromFetcher(data, dataSource);
      return result;
    } finally {
      fetcher.cleanup();
    }
  }

  @SuppressWarnings("unchecked")
  private <Data> Resource<R> decodeFromFetcher(Data data, DataSource dataSource)
      throws GlideException {
    LoadPath<Data, ?, R> path = decodeHelper.getLoadPath((Class<Data>) data.getClass());
    return runLoadPath(data, dataSource, path);
  }

  private <Data, ResourceType> Resource<R> runLoadPath(Data data, DataSource dataSource,
      LoadPath<Data, ResourceType, R> path) throws GlideException {
    Options options = getOptionsWithHardwareConfig(dataSource);
    DataRewinder<Data> rewinder = glideContext.getRegistry().getRewinder(data);
    try {
      return path.load(
          rewinder, options, width, height, new DecodeCallback<ResourceType>(dataSource));
    } finally {
      rewinder.cleanup();
    }
  }
```

调用`decodeFromRetrievedData`开始解析加载返回的数据，数据格式可能为`InputSteam`、`ByteBuffer`。向下调用到`decodeFromData()`，再到`decodeFromFetcher()`，最终通过`DecodeHelper.getLoadPath()`得到的`LoadPath`去对获取的数据进行解析。

```java LoadPath.java
  public Resource<Transcode> load(DataRewinder<Data> rewinder, @NonNull Options options, int width,
      int height, DecodePath.DecodeCallback<ResourceType> decodeCallback) throws GlideException {
    List<Throwable> throwables = Preconditions.checkNotNull(listPool.acquire());
    try {
      return loadWithExceptionList(rewinder, options, width, height, decodeCallback, throwables);
    } finally {
      listPool.release(throwables);
    }
  }

private Resource<Transcode> loadWithExceptionList(DataRewinder<Data> rewinder,
      @NonNull Options options,
      int width, int height, DecodePath.DecodeCallback<ResourceType> decodeCallback,
      List<Throwable> exceptions) throws GlideException {
    Resource<Transcode> result = null;
    //noinspection ForLoopReplaceableByForEach to improve perf
    for (int i = 0, size = decodePaths.size(); i < size; i++) {
      DecodePath<Data, ResourceType, Transcode> path = decodePaths.get(i);
      try {
        //又传递到DecodePath上
        result = path.decode(rewinder, width, height, options, decodeCallback);
      } catch (GlideException e) {
        exceptions.add(e);
      }
      if (result != null) {
        break;
      }
    }

    if (result == null) {
      throw new GlideException(failureMessage, new ArrayList<>(exceptions));
    }

    return result;
  }
```

```java DecodePath.java
  public Resource<Transcode> decode(DataRewinder<DataType> rewinder, int width, int height,
      @NonNull Options options, DecodeCallback<ResourceType> callback) throws GlideException {
    Resource<ResourceType> decoded = decodeResource(rewinder, width, height, options);
    Resource<ResourceType> transformed = callback.onResourceDecoded(decoded);
    return transcoder.transcode(transformed, options);
  }

  @NonNull
  private Resource<ResourceType> decodeResource(DataRewinder<DataType> rewinder, int width,
      int height, @NonNull Options options) throws GlideException {
    List<Throwable> exceptions = Preconditions.checkNotNull(listPool.acquire());
    try {
      return decodeResourceWithList(rewinder, width, height, options, exceptions);
    } finally {
      listPool.release(exceptions);
    }
  }

 @NonNull
  private Resource<ResourceType> decodeResourceWithList(DataRewinder<DataType> rewinder, int width,
      int height, @NonNull Options options, List<Throwable> exceptions) throws GlideException {
    Resource<ResourceType> result = null;
    //noinspection ForLoopReplaceableByForEach to improve perf
    for (int i = 0, size = decoders.size(); i < size; i++) {
      ResourceDecoder<DataType, ResourceType> decoder = decoders.get(i);
      try {
        //数据解析器
        DataType data = rewinder.rewindAndGet();
        if (decoder.handles(data, options)) {
          data = rewinder.rewindAndGet();
          result = decoder.decode(data, width, height, options);
        }
      } catch (IOException | RuntimeException | OutOfMemoryError e) {

      }

      if (result != null) {
        break;
      }
    }

    if (result == null) {
      throw new GlideException(failureMessage, new ArrayList<>(exceptions));
    }
    return result;
  }
```

`LoadPath.load()`通过调用`loadWithExceptionList()`，循环获取`DecodePath`对象，然后调用其自身的`decode()`进行数据解析。`DecodePath`与`LoadPath`逻辑相似，最终在`DecodePath.decodeResourceWithList()`中循环获取`ResourceDecoder`对象，通过`DateRewinder.rewindAndGet()`获取要解析数据的格式(比如`ByteBuffer，InputStream`)，然后调用`decoder.decode`继续解析数据。

##### 获取数据格式

由上述流程可知，我们能获得的数据类型为`InputStream`和`ByteBuffer`，对应的就会有两种`DataRewinder`

```java InputStreamRewinder.java
 private final RecyclableBufferedInputStream bufferedStream;
@NonNull
  @Override
  public InputStream rewindAndGet() throws IOException {
    bufferedStream.reset();
    return bufferedStream;
  }
```

```java ByteBufferRewinder.java
  @NonNull
  @Override
  public ByteBuffer rewindAndGet() {
    buffer.position(0);
    return buffer;
  }
```

将传进来的data可以转换成对应的数据格式。

##### 根据格式转换相应类型

得到对应数据格式后，就需要通过`ResourceDecoder.decode()`去解析数据。

```java ResourceDecoder.java
public interface ResourceDecoder<T, Z> {
  //判断这两个组合参数是否能进行解析
  boolean handles(@NonNull T source, @NonNull Options options) throws IOException;

   */
  @Nullable
  Resource<Z> decode(@NonNull T source, int width, int height, @NonNull Options options)
      throws IOException;
}
```

`T`代表需要被解析的类型(例如InputStream、ByteBuffer)，`Z`代表解析的结果类型(例如Bitmap、Drawable)。

`ResourceDecoder`在原码中有很多实现类，`StreamBitmapDecoder`、`ButeBufferBitmapDecoder`，此处拿出常用的`StreamBitmapDecoder`进行分析。

```java StreamBitmapDecoder.java
  @Override
  public boolean handles(@NonNull InputStream source, @NonNull Options options) {
    return downsampler.handles(source);
  }

  @Override
  public Resource<Bitmap> decode(@NonNull InputStream source, int width, int height,
      @NonNull Options options)
      throws IOException {

    // Use to fix the mark limit to avoid allocating buffers that fit entire images.
    final RecyclableBufferedInputStream bufferedStream;
    final boolean ownsBufferedStream;
    if (source instanceof RecyclableBufferedInputStream) {
      bufferedStream = (RecyclableBufferedInputStream) source;
      ownsBufferedStream = false;
    } else {
      bufferedStream = new RecyclableBufferedInputStream(source, byteArrayPool);
      ownsBufferedStream = true;
    }
    ExceptionCatchingInputStream exceptionStream =
        ExceptionCatchingInputStream.obtain(bufferedStream);

    MarkEnforcingInputStream invalidatingStream = new MarkEnforcingInputStream(exceptionStream);
    UntrustedCallbacks callbacks = new UntrustedCallbacks(bufferedStream, exceptionStream);
    try {
      return downsampler.decode(invalidatingStream, width, height, options, callbacks);
    } finally {
      exceptionStream.release();
      if (ownsBufferedStream) {
        bufferedStream.release();
      }
    }
  }
```

`ResourceDecode.decode()`内部是通过`Downsampler.decode()`进行解析

```java Downsampler.java
  @SuppressWarnings({"resource", "deprecation"})
  public Resource<Bitmap> decode(InputStream is, int requestedWidth, int requestedHeight,
      Options options, DecodeCallbacks callbacks) throws IOException {
    ...
    try {
      Bitmap result = decodeFromWrappedStreams(is, bitmapFactoryOptions,
          downsampleStrategy, decodeFormat, isHardwareConfigAllowed, requestedWidth,
          requestedHeight, fixBitmapToRequestedDimensions, callbacks);
      return BitmapResource.obtain(result, bitmapPool);
    } finally {
      releaseOptions(bitmapFactoryOptions);
      byteArrayPool.put(bytesForOptions);
    }
  }

 private Bitmap decodeFromWrappedStreams(InputStream is,
      BitmapFactory.Options options, DownsampleStrategy downsampleStrategy,
      DecodeFormat decodeFormat, boolean isHardwareConfigAllowed, int requestedWidth,
      int requestedHeight, boolean fixBitmapToRequestedDimensions,
      DecodeCallbacks callbacks) throws IOException {
   
      Bitmap downsampled = decodeStream(is, options, callbacks, bitmapPool);
      callbacks.onDecodeComplete(bitmapPool, downsampled);
 }

 private static Bitmap decodeStream(InputStream is, BitmapFactory.Options options,
      DecodeCallbacks callbacks, BitmapPool bitmapPool) throws IOException {
    ...
    TransformationUtils.getBitmapDrawableLock().lock();
    try {
      result = BitmapFactory.decodeStream(is, null, options);
    } catch (IllegalArgumentException e) {
      ...
      throw bitmapAssertionException;
    } finally {
      TransformationUtils.getBitmapDrawableLock().unlock();
    }
   ...
  }
```

`Downsampler.decode()`内部主要实现依靠`decodeFromWrapperStreams()`，内部主要是配置`BitmapFactory.Options`。去控制图片的缩放(scale)、旋转(rotate)、复用(inBitmap)等方面配置。最后通过`decodeStream`解析输入流，最后生成Bitmap对象返回。

##### 获取图片后继续处理(例如圆角)

```java DecodePath.java
  public Resource<Transcode> decode(DataRewinder<DataType> rewinder, int width, int height,
      @NonNull Options options, DecodeCallback<ResourceType> callback) throws GlideException {
    //上述步骤已完成
    Resource<ResourceType> decoded = decodeResource(rewinder, width, height, options);
    //加载完成的回调 调用Transform
    Resource<ResourceType> transformed = callback.onResourceDecoded(decoded);
    return transcoder.transcode(transformed, options);
  }
```

`decodeResource`最终会调到`DecodeJob.onResourceDecoded()`进行`Transform`处理。

```java
 <Z> Resource<Z> onResourceDecoded(DataSource dataSource,
      @NonNull Resource<Z> decoded) {
    @SuppressWarnings("unchecked")
    Class<Z> resourceSubClass = (Class<Z>) decoded.get().getClass();
    Transformation<Z> appliedTransformation = null;
    Resource<Z> transformed = decoded;
    if (dataSource != DataSource.RESOURCE_DISK_CACHE) {
      //获取到的是 RequestOptions.getTransformations()这个集合
      appliedTransformation = decodeHelper.getTransformation(resourceSubClass);
      transformed = appliedTransformation.transform(glideContext, decoded, width, height);
    }
    // TODO: Make this the responsibility of the Transformation.
    if (!decoded.equals(transformed)) {
      decoded.recycle();
    }
if (diskCacheStrategy.isResourceCacheable(isFromAlternateCacheKey, dataSource,
        encodeStrategy)) {
      if (encoder == null) {
        throw new Registry.NoResultEncoderAvailableException(transformed.get().getClass());
      }
      final Key key;
      switch (encodeStrategy) {
        case SOURCE:
          key = new DataCacheKey(currentSourceKey, signature);
          break;
        case TRANSFORMED:
          key =
              new ResourceCacheKey(
                  decodeHelper.getArrayPool(),
                  currentSourceKey,
                  signature,
                  width,
                  height,
                  appliedTransformation,
                  resourceSubClass,
                  options);
          break;
        default:
          throw new IllegalArgumentException("Unknown strategy: " + encodeStrategy);
      }
    ...
    }
    return result;
  }

```

> 从这里可看出 保存原图和保存转换后图片的缓存key是不一致的。
>
> 缓存原图用的是`DataCacheKey`，保存转换后图片用的是`ResourceCacheKey`

上述数据处理完毕后，层层回溯到达了`decodeFromRetrievedData`()

```java DecodeJob.java
private void decodeFromRetrievedData() {
    ...
    Resource<R> resource = null;
    try {
      resource = decodeFromData(currentFetcher, currentData, currentDataSource);
    } catch (GlideException e) {
      e.setLoggingDetails(currentAttemptingKey, currentDataSource);
      throwables.add(e);
    }
    //这时Resource已经赋值完毕
    if (resource != null) {
      notifyEncodeAndRelease(resource, currentDataSource);
    } else {
      runGenerators();
    }
  }

  private void notifyEncodeAndRelease(Resource<R> resource, DataSource dataSource) {
    if (resource instanceof Initializable) {
      ((Initializable) resource).initialize();
    }

    notifyComplete(result, dataSource);
    //加载完毕后 回到初始状态
    stage = Stage.ENCODE;
    ...
  }

  private void notifyComplete(Resource<R> resource, DataSource dataSource) {
    setNotifiedOrThrow();
    callback.onResourceReady(resource, dataSource);
  }
```

经过解析数据那一套流程下来后，数据已经加载完成，然后回到`DecodeJob.decodeFromRetrieveData()`，这时Resource对象不为空，向下继续调用`notifyEncodeAndRelease()`，内部调用到`notifyComplete()`再回调到`EngineJob.onResourceReady()`。

```java EngineJob.java
  @Override
  public void onResourceReady(Resource<R> resource, DataSource dataSource) {
    synchronized (this) {
      this.resource = resource;
      this.dataSource = dataSource;
    }
    notifyCallbacksOfResult();
  }

  void notifyCallbacksOfResult() {
    ResourceCallbacksAndExecutors copy;
    Key localKey;
    EngineResource<?> localResource;

    listener.onEngineJobComplete(this, localKey, localResource);

    for (final ResourceCallbackAndExecutor entry : copy) {
      entry.executor.execute(new CallResourceReady(entry.cb));
    }
    decrementPendingCallbacks();
  }
```

`EngineJob.onResourceReady()`资源加载完成后，通过`notifyCallbacksOfResulr()`调用到`Engine.onEngineJobComplete()`

```java Engine.java
  public synchronized void onEngineJobComplete(
      EngineJob<?> engineJob, Key key, EngineResource<?> resource) {
    // A null resource indicates that the load failed, usually due to an exception.
    if (resource != null) {
      resource.setResourceListener(key, this);

      if (resource.isCacheable()) {
        activeResources.activate(key, resource);
      }
    }

    jobs.removeIfCurrent(key, engineJob);
  }


```

加载完成后，把对应资源插入到`ActiveResources`中作为活动资源。

{% fullimage /images/Glide-硬盘缓存.png,Glide-硬盘缓存,Glide-硬盘缓存%}

## Glide高级用法

处理带有后缀的图片类型，可能为了保证安全，不同的用户获取的图片除了图片地址外还会有一段标识用户的token。而且token并不一定是固定的，这样我们再去加载图片时，由于缓存key不一致，导致重复加载。

这里涉及到了[缓存key](#缓存key)的生成，其中有一个重要参数为远程图片加载地址，对于上述情况，因为地址的变化，key不同则查找缓存时也无法命中，解决这个情况就需要排除掉变化的部分。

```java
class MyGlideUrl extends GlideUrl{

    private String mUrl;

    public MyGlideUrl(String url) {
        super(url);
        mUrl = url;
    }

    @Override
    public String getCacheKey() {
        return mUrl.replace(replaceTokenParam(),"");
    }
    
    private String replaceTokenParam(){
        String tokenParam="";
        int tokenIndex = mUrl.contains("?.token") ? mUrl.indexOf("?token"):mUrl.indexOf("&token");
        if(tokenIndex!=-1){
            int nextAndIndex = mUrl.indexOf("&",tokenIndex+1);
            if (nextAndIndex!=-1){
                tokenParam = mUrl.substring(tokenIndex+1,nextAndIndex+1);
            }else{
                tokenParam = mUrl.substring(tokenIndex);
            }
        }
        return tokenParam;
    }
}


Glide.with(mContext).load(MyGlideUrl(imgUrl)).into(imageView);
```

## 内容引用

[Glide主流源码分析](https://juejin.im/post/5c31fbdff265da610e803d4e#heading-14)

[Glide4.8源码拆解（二）核心加载流程](<https://juejin.im/post/5c2dffa8f265da611d66c8b6#heading-2>)

