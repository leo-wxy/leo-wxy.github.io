---
title: Activity,Window,View的关联与理解
date: 2018-04-01 17:27:58
tags: Android
top: 11
---
# Activity,Window,View相关

{% fullimage /images/ActivityWindowView的联系.png,Activity&Window&View,Activity&Window&View%}

## 1. 什么是Activity,Window,View以及职能简介
- Activity：不负责视图控制，只是控制生命周期和处理事件，真正控制视图的是Window，一个Activity包含一个Window，Window真正代表一个窗口。`Activity是一个控制器，控制视图的添加与显示以及通过回调方法来进行Window与View的交互。`
- Window：Window是视图的承载器，内部持有一个DecorView，DecorView才是view的根布局，Window为抽象类，实际是Activity中的其子类PhoneWindow，其中有个内部类DecorView，通过创建DecorView来加载`R.layout.*`，Window通过WindowManager加载DecorView，并将DecorView和ViewRoot关联，进行视图控制与交互。
- View：DecorView继承自FrameLayout,DecorView作为顶级View，一般其内部包含一个竖直方向的LinearLayout，里面包含ViewStub，标题栏（titleView），内容栏（contentView）。Activity通过`setContentView()`将布局文件加载进内容栏中。
- ViewRoot：ViewRoot的实现类是ViewRootImpl，是WindowService和DecorView之间的纽带。ViewRoot不属于View节点，和View之间没有直接联系，不过实现了ViewParent接口。
{% fullimage /images/study_plan/activity_window_view.png, alt,流程图 %}

## 2. Activity如何和Window，View关联（附源码）
### Activity和Window关联

{% post_link Activity启动过程%}

在此简述下Activity的启动过程：

- 调用`ContextImpl.startActivity()`实质调用`ContextImpl.startActivityForResult()`
- 执行到`performLaunchActivity()`在其中完成启动流程
- 通过`Instrumentation.newActivity`使用类加载器创建Activity对象
- 通过`LoadedApk.makeApplication()`尝试创建Application对象(*Application已被创建则跳过*)
- 创建`ContextImpl`对象，并执行`Activity.attach()`完成一些重要数据的初始化
- 最终调用`Activity.onCreate()`完成启动流程。

其中`Activity和Window的关联`发生在`Activity.attach()`中

```java
 final void attach(Context context, ActivityThread aThread,
            Instrumentation instr, IBinder token, int ident,
            Application application, Intent intent, ActivityInfo info,
            CharSequence title, Activity parent, String id,
            NonConfigurationInstances lastNonConfigurationInstances,
            Configuration config, String referrer, IVoiceInteractor voiceInteractor,
            Window window, ActivityConfigCallback activityConfigCallback) {
        attachBaseContext(context);

        mFragments.attachHost(null /*parent*/);
        //进行了PhoneWindow的初始化并进行关联
        mWindow = new PhoneWindow(this, window, activityConfigCallback);
        mWindow.setWindowControllerCallback(this);
        mWindow.setCallback(this);
        mWindow.setOnWindowDismissedCallback(this);
        mWindow.getLayoutInflater().setPrivateFactory(this);
        ...
 }
```

其中`PhoneWindow`就是Activity的根Window，可以在其上添加其他的Window(*例如Dialog*)，`PhoneWindow`就是`Activity`与`View`之间的桥梁，Activity无法直接操作View。

### Window和View关联

Activity无法直接和View交互，需要通过Window管理

```java
    public void setContentView(@LayoutRes int layoutResID) {
        getWindow().setContentView(layoutResID);
        initWindowDecorActionBar();
    }

    public Window getWindow() {
        return mWindow;
    }
```

Activity通过`setContentView()`加载要显示的布局，观察源码可知还是通过`Window`进行了加载操作。

### 加载View

```java
 @Override
 public void setContentView(int layoutResID) {
        if (mContentParent == null) {
            installDecor();
        } else if (!hasFeature(FEATURE_CONTENT_TRANSITIONS)) {
            mContentParent.removeAllViews();
        }

        if (hasFeature(FEATURE_CONTENT_TRANSITIONS)) {
            final Scene newScene = Scene.getSceneForLayout(mContentParent, layoutResID,
                    getContext());
            transitionTo(newScene);
        } else {
            mLayoutInflater.inflate(layoutResID, mContentParent);
        }
        mContentParent.requestApplyInsets();
        final Callback cb = getCallback();
        if (cb != null && !isDestroyed()) {
            cb.onContentChanged();
        }
        mContentParentExplicitlySet = true;
    }

private void installDecor() {
    if (mDecor == null) {
        mDecor = generateDecor(); //生成DecorView
        mDecor.setDescendantFocusability(ViewGroup.FOCUS_AFTER_DESCENDANTS);
        mDecor.setIsRootNamespace(true);
        if (!mInvalidatePanelMenuPosted && mInvalidatePanelMenuFeatures != 0) {
            mDecor.postOnAnimation(mInvalidatePanelMenuRunnable);
        }
    }
    if (mContentParent == null) {
        mContentParent = generateLayout(mDecor); // 为DecorView设置布局格式，并返回mContentParent
        ...
        } 
    }
}

    protected DecorView generateDecor(int featureId) {
        Context context;
        if (mUseDecorContext) {
            Context applicationContext = getContext().getApplicationContext();
            if (applicationContext == null) {
                context = getContext();
            } else {
                context = new DecorContext(applicationContext, getContext().getResources());
                if (mTheme != -1) {
                    context.setTheme(mTheme);
                }
            }
        } else {
            context = getContext();
        }
        return new DecorView(context, featureId, this, getAttributes());
    }
```

Activity通过`setContentView()`调用到`PhoneWindow.setContentView()`执行DecorView的创建流程。

> `DecorView`直接和`PhoneWindow`进行关联，其内部包含了我们定义的布局(*ContentView*)以及一个`titlebar`。

### 显示View

上述方法只是创建了一个`DecorView`，而没有执行显示流程。这就涉及到了`Activity的生命周期`，其中有讲到在`onResume()`才对用户可见。

{% post_link View的工作原理 %}



**View需要通过Window才能展示在Activity上。**

## 3.总结

> Activity就像个控制器，不负责视图部分；
>
> Window像个承载器，装着内部视图；
>
> DecorView就是个顶层视图，是所有View的最外层布局；
>
> ViewRoot就是个连接器，负责沟通，是WindowManager和View之间的桥梁。



Activity包含了一个PhoneWindow，而PhoneWindow就是继承于Window的，Activity通过`setContentView`将View设置到了PhoneWindow上，而View通过WindowManager的`addView()、removeView()、updateViewLayout()`对View进行管理。Window的添加过程以及Activity的启动流程都是一次IPC的过程。Activity的启动需要通过AMS完成；Window的添加过程需要通过WindowSession完成。