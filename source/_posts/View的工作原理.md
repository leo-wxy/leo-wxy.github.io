---
title: View的工作原理
date: 2018-12-14 16:47:21
tags: Android
top: 10
typora-root-url: ../
---



<!--MeasureSpec是什么？有什么作用？，自定义View/ViewGroup需要注意什么？invalidate()和postInvalidate()的区别？,invalidate和postInvalidate的区别及使用 Requestlayout，onlayout，onDraw，DrawChild区别与联系  View刷新机制  View绘制流程  计算一个view的嵌套层级（递归）  onMeasure的具体过程，先measure子view还是自己  onDraw的具体过程，先draw子view还是自己  实现一个自定义view，其中含有若干textview，textview文字可换行且自定义- - view的高度可自适应拓展 view的工作原理及measure、layout、draw流程。哪一个流程可以放在子线程中去执行？draw方法中需要注意的问题？Invalidate、postInvalidate、requestLayout应用场景 TextView.setText()调用什么方法去刷新 -->

![View工作原理](/images/View工作原理xmind.png)

<!-- more -->



## PhoneWindow

![View工作原理-PhoneWindow](/images/View工作原理-PhoneWindow.png)

`Window`是一个抽象类，提供了各种窗口操作方法。每个Activity都会持有一个`Window`。

`PhoneWindow`是`Window`唯一实现类，在Activity被创建时`Activity.attach()`进行初始化

```java
//ActivityThread.java
//Activity开始启动
public Activity handleLaunchActivity(ActivityClientRecord r,
            PendingTransactionActions pendingActions, Intent customIntent) {
 ... 
   final Activity a = performLaunchActivity(r, customIntent);
}

    private Activity performLaunchActivity(ActivityClientRecord r, Intent customIntent) {
      //创建Application对象
            Application app = r.packageInfo.makeApplication(false, mInstrumentation);      
      //Activity初始化
       activity.attach(appContext, this, getInstrumentation(), r.token,
                        r.ident, app, r.intent, r.activityInfo, title, r.parent,
                        r.embeddedID, r.lastNonConfigurationInstances, config,
                        r.referrer, r.voiceInteractor, window, r.configCallback);
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
            Window window, ActivityConfigCallback activityConfigCallback) {
      ...
        //初始化PhoneWindow对象
        mWindow = new PhoneWindow(this, window, activityConfigCallback);
        mWindow.setWindowControllerCallback(this);
      //绑定Window对象
        mWindow.setCallback(this);
      
    }
```

```java
//PhoneWindow.java
public class PhoneWindow extends Window implements MenuBuilder.Callback {
    // This is the top-level view of the window, containing the window decor.
    private DecorView mDecor;//对应DecorView  
}
```



## DecorView

![View工作原理-DecorView](/images/View工作原理-DecorView.png)

**DecorView是整个Window界面的最顶层View。** *可以使用Android Studio自带的Layout Inspector查看页面层级*

### DecorView的布局结构

一般情况下`DecorView`会包含一个竖直方向的LinearLayout，该LinearLayout分为上下两个部分，上面是标题栏(`titlebar`)，下面是内容栏(`继承自FrameLayout 且id为content`)。因此我们设置Activity的布局方法叫做`setContentView()`，因为他们都被加进了`id为content的FrameLayout`中。

我们可以利用`ViewGroup content = findViewById(R.android.id.content)`获取conetnt。使用`content.getChildAt(0)`获取设置的Activity布局。

```java
// ../android/app/Activity.java
    public <T extends View> T findViewById(@IdRes int id) {
        //从Window中去获取View
        return getWindow().findViewById(id);
    }

// ../android/view/Window.java
    public <T extends View> T findViewById(@IdRes int id) {
        //从DecorView获取View
        return getDecorView().findViewById(id);
    }
```

所有的View都会从DecorView中开始检索，所以**View层的事件都会先经过DecorView，再传递到我们定义的View上**。

### setContentView()过程

> 通过`setContentView()`将需要加载的布局放到`DecorView`中

```java
//Activity.java
public void setContentView(@LayoutRes int layoutResID) {
        getWindow().setContentView(layoutResID);
        initWindowDecorActionBar();
    }
```

`Activity.setContentView()`调用`PhoneWindow.setContentView()`

```java
    public void setContentView(int layoutResID) {
        // Note: FEATURE_CONTENT_TRANSITIONS may be set in the process of installing the window
        // decor, when theme attributes and the like are crystalized. Do not check the feature
        // before this happens.
        if (mContentParent == null) {
            //创建DecorView
            installDecor();
        } else if (!hasFeature(FEATURE_CONTENT_TRANSITIONS)) {
            mContentParent.removeAllViews();
        }

        if (hasFeature(FEATURE_CONTENT_TRANSITIONS)) {
            final Scene newScene = Scene.getSceneForLayout(mContentParent, layoutResID,
                    getContext());
            transitionTo(newScene);
        } else {
          //开始加载对应布局
            mLayoutInflater.inflate(layoutResID, mContentParent);
        }
        mContentParent.requestApplyInsets();
        final Callback cb = getCallback();
        if (cb != null && !isDestroyed()) {
            cb.onContentChanged();
        }
        mContentParentExplicitlySet = true;
    }
```

`setContentView()`主要执行以下两步：

#### `installDecor()`——创建DecorView

> 基础`DecorView`主要包含两部分，标题`title_bar`和内容`content`

```java
//PhoneWindow.java
 private void installDecor() {
        mForceDecorInstall = false;
        if (mDecor == null) {
            //生成DecoeView
            mDecor = generateDecor(-1);
            ...
        } else {
            mDecor.setWindow(this);
        }
        if (mContentParent == null) {
           //根据DecorView生成子View
            mContentParent = generateLayout(mDecor);
          ...
        }
 }

    protected DecorView generateDecor(int featureId) {
        Context context;
        if (mUseDecorContext) {
            Context applicationContext = getContext().getApplicationContext();
            if (applicationContext == null) {
                context = getContext();
            } else {
                context = new DecorContext(applicationContext, getContext());
                if (mTheme != -1) {
                    context.setTheme(mTheme);
                }
            }
        } else {
            context = getContext();
        }
      // 生成DecorView对象
        return new DecorView(context, featureId, this, getAttributes());
    }

    protected ViewGroup generateLayout(DecorView decor) {
      ...
        int layoutResource;
        int features = getLocalFeatures();
        if ((features & (1 << FEATURE_SWIPE_TO_DISMISS)) != 0) {
            layoutResource = R.layout.screen_swipe_dismiss;
            setCloseOnSwipeEnabled(true);     
        }...
         else{
           layoutResource = R.layout.screen_simple; //默认布局
         }
         mDecor.startChanging();
         //开始加载布局
         mDecor.onResourcesLoaded(mLayoutInflater, layoutResource);
         //根据id找到 content
         ViewGroup contentParent = (ViewGroup)findViewById(ID_ANDROID_CONTENT);//com.android.internal.R.id.content
         ...
         return contentParent;
    }

//DecorView.java
    void onResourcesLoaded(LayoutInflater inflater, int layoutResource) {
        final View root = inflater.inflate(layoutResource, null);
        if (mDecorCaptionView != null) {
            if (mDecorCaptionView.getParent() == null) {
                addView(mDecorCaptionView,
                        new ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT));
            }
            mDecorCaptionView.addView(root,
                    new ViewGroup.MarginLayoutParams(MATCH_PARENT, MATCH_PARENT));
        } else {
            //解析得到的View放到DecorView中
            addView(root, 0, new ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT));
        }
        mContentRoot = (ViewGroup) root;
    }

```

`installDecor()`主要负责创建`DecorView`并执行`generateLayout()`生成`contentParent`将自定义的布局放入其中。



#### inflate(layoutResID, mContentParent)——加载布局

`inflate()`主要将`layoutResID`加载成具体的View，并加入到`mContentParent`中，进行显示。



![执行流程](/images/setContentView流程.png)

## ViewRootImpl

![View工作原理-ViewRootImpl](/images/View工作原理-ViewRootImpl.png)

> *ViewRoot对应于ViewRootImpl类，是连接WindowManager和DecorView的纽带，View的三大流程均需通过ViewRoot完成。*

### ViewRootImpl创建时机

当Activity创建时，最终是调用到`ActivityThread`的`handleLaunchActivity`来创建Activity。

```java
// ../android/app/ActivityThread.java
private void handleLaunchActivity(ActivityClientRecord r, Intent customIntent, String reason) {
 ...
      //创建一个Activity 会调用到onCreate()方法 从而完成DecroView的创建
      Activity a = performLaunchActivity(r, customIntent);
        if (a != null) {
            r.createdConfig = new Configuration(mConfiguration);
            reportSizeConfigurations(r);
            Bundle oldState = r.state;
            
            handleResumeActivity(r.token, false, r.isForward,
                    !r.activity.mFinished && !r.startsNotResumed, r.lastProcessedSeq, reason);
            ...
        }
    ...
}
```

上述方法后续调用到了`handleResumeActivity()`,在这个方法中调用到了`WindowManager.addView()`将View传递至WindowManager

```java
// ../android/app/ActivityThread.java
final void handleResumeActivity(IBinder token,
            boolean clearHide, boolean isForward, boolean reallyResume, int seq, String reason) {
         ActivityClientRecord r = mActivities.get(token);
        if (!checkAndUpdateLifecycleSeq(seq, r, "resumeActivity")) {
            return;
        }
        unscheduleGcIdler();
        mSomeActivitiesChanged = true;

        // 在这里会调用到生命周期中的onResume方法
        r = performResumeActivity(token, clearHide, reason);
        ...
            if(r!=null){
                ...
                final Activity a = r.activity;
                ...
                //获得当前Activty的Window对象
                r.window = r.activity.getWindow();
                //获得当前Window的DecorView
                View decor = r.window.getDecorView();
                decor.setVisibility(View.INVISIBLE);
                //获得当前Activity的WindowManager对象
                ViewManager wm = a.getWindowManager();
                WindowManager.LayoutParams l = r.window.getAttributes();
                a.mDecor = decor;
                l.type = WindowManager.LayoutParams.TYPE_BASE_APPLICATION;
                l.softInputMode |= forwardBit;
                if (r.mPreserveWindow) {
                    a.mWindowAdded = true;
                    r.mPreserveWindow = false;
                    ViewRootImpl impl = decor.getViewRootImpl();
                    if (impl != null) {
                        impl.notifyChildRebuilt();
                    }
                }
                if (a.mVisibleFromClient) {
                    if (!a.mWindowAdded) {
                        a.mWindowAdded = true;
                        //将DecorView添加到PhoneWindow中
                        wm.addView(decor, l);
                    } else {
                        a.onWindowAttributesChanged(l);
                    }
                }

            // If the window has already been added, but during resume
            // we started another activity, then don't yet make the
            // window visible.
            } else if (!willBeVisible) {
                if (localLOGV) Slog.v(
                    TAG, "Launch " + r + " mStartedActivity set");
                r.hideForNow = true;
            }    
            }
        if (!r.activity.mFinished && willBeVisible && r.activity.mDecor != null && !r.hideForNow) {
...
            if (r.activity.mVisibleFromClient) {
              //显示DecorView
                r.activity.makeVisible();
            }
        }
...
    }

//Activity.java
    void makeVisible() {
        if (!mWindowAdded) {
            ViewManager wm = getWindowManager();
            wm.addView(mDecor, getWindow().getAttributes());
            mWindowAdded = true;
        }
      //显示DecorView及其内容
        mDecor.setVisibility(View.VISIBLE);
    }
```

后续调用到了`wm.addView()`。将对应的DecorView传递进去。

```java
// ../android/view/WindowManagerImpl.java
public final class WindowManagerImpl implements WindowManager {
    private final WindowManagerGlobal mGlobal = WindowManagerGlobal.getInstance();
    private final Window mParentWindow;
    ...
    @Override
    public void addView(@NonNull View view, @NonNull ViewGroup.LayoutParams params) {
        applyDefaultToken(params);
        //调用到了WindowManagerGlobal中的addView
        mGlobal.addView(view, params, mContext.getDisplay(), mParentWindow);
    }   
    ...
}

// ../android/view/WindowManagerGlobal.java
public void addView(View view, ViewGroup.LayoutParams params,
            Display display, Window parentWindow) {
        ...

        ViewRootImpl root;
        View panelParentView = null;
        synchronized (mLock) {
            ...
            //创建了ViewRootImpl实例
            root = new ViewRootImpl(view.getContext(), display);//初始化了ViewRootImpl对象
            view.setLayoutParams(wparams);
            mViews.add(view);
            mRoots.add(root);
            mParams.add(wparams);
            // do this last because it fires off messages to start doing things
            try {
                //调用setView 将传进来的DecorView添加到PhoneWindow中。 
                root.setView(view, wparams, panelParentView);
            } catch (RuntimeException e) {
                // BadTokenException or InvalidDisplayException, clean up.
                if (index >= 0) {
                    removeViewLocked(index, true);
                }
                throw e;
            }
        }
    }
```

经过`ActivityThread.handleResumeActivity() -> WindowManagerGlobal.addView() `创建了`ViewRootImpl`对象

### 与DecorView的关系

上述流程走完后，就把DecorView加载到了Window中。**这个流程中将ViewRootImpl对象与DecorView进行了关联**。

```java
//view 表示 DecorView 
public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
     synchronized(this){
         //传进来的DecorView作为全局变量使用
          mView = view;
         ...
          // Schedule the first layout -before- adding to the window
                // manager, to make sure we do the relayout before receiving
                // any other events from the system.
          //绘制整个布局
          requestLayout();   
         ...
          //设置ViewRootImpl为DecorView的parentView 
          view.assignParent(this);
     }   
 }
```

执行到`ViewRootImpl.setView()`设置`DecorView,assignParent(root)`。表示**ViewRootImpl是DecorView的parent**。

![三者关系](/images/三者关系.png)

> `Activity`、`Window(PhoneWindow)`、`View(DecorView)`、`ViewRootImpl`之间的关系？
>
> `PhoneWindow`是`Window`的唯一子类，在`Activity.attach()`构建的实例，是**Activity与View交互的中间层**
>
> `DecorView`是`所有View`的最顶层，`ViewRootImpl`是`DecorView`的`parent`，负责`WindowManagerService`与`DecorView`的通信。**掌管View的各种事件，例如`刷新、点击`事件等**



## LayoutInflater

> `LayoutInflater`是一个抽象类，具体实现类为`PhoneLayoutInflater`。主要用于进行`布局加载`。

### PhoneLayoutInflater

![View工作原理-LayoutInflater-PhoneLayoutInflater](/images/View工作原理-LayoutInflater-PhoneLayoutInflater.png)

>  通过系统注册服务可以得到`LayoutInflater`的实现类`PhoneLayoutInflater`

```java
//LayoutInflater.java
public static LayoutInflater from(Context context) {
    LayoutInflater LayoutInflater =
            (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);//获取系统配置的加载服务
    if (LayoutInflater == null) {
        throw new AssertionError("LayoutInflater not found.");
    }
    return LayoutInflater;
}

//ContextThemeWrapper.java
    @Override
    public Object getSystemService(String name) {
        if (LAYOUT_INFLATER_SERVICE.equals(name)) {
          //单例获取 LayoutInflater
            if (mInflater == null) {
                mInflater = LayoutInflater.from(getBaseContext()).cloneInContext(this);
            }
            return mInflater;
        }
        return getBaseContext().getSystemService(name);
    }

//SystemServerRegistry.java
//系统设置 PhoneInflater 为加载类
registerService(Context.LAYOUT_INFLATER_SERVICE, LayoutInflater.class,
            new CachedServiceFetcher<LayoutInflater>() {
        @Override
        public LayoutInflater createService(ContextImpl ctx) {
            return new PhoneLayoutInflater(ctx.getOuterContext());
        }});
```
`PhoneLayoutInflater`设置的`context`为`ContextImpl.getOuterContext()`

```java
//ContextImpl.java
    final void setOuterContext(Context context) {
        mOuterContext = context;
    }

    final Context getOuterContext() {
        return mOuterContext;
    }

//ActivityThread.java
    private Activity performLaunchActivity(ActivityClientRecord r, Intent customIntent) {
      ...
        appContext.setOuterContext(activity);//设置外部context为Activity
    }
```

**一般从`Activity、View、Dialog，Fragment`获取的`layoutInflater.getContext()`为Activity**

> 无论是哪种方式获取`LayoutInflater`，都是通过`ContextImpl.getSystemService()`获取的。

### inflate()-加载布局

![LayoutInflater-inflate](/images/LayoutInflater-inflate.png)

> `source`：需要加载的layout id
>
> `root`：根布局(`为null则表示创建的是最顶层的布局`)
>
> *`attachToRoot`：是否添加到`root`中

```java
//LayoutInflater.java
   public View inflate(@LayoutRes int resource, @Nullable ViewGroup root) {
        return inflate(resource, root, root != null);
   }   

   public View inflate(@LayoutRes int resource, @Nullable ViewGroup root, boolean attachToRoot) {
        final Resources res = getContext().getResources();
        ...
        //构造xml解析器
        final XmlResourceParser parser = res.getLayout(resource);
        try {
            return inflate(parser, root, attachToRoot);
        } finally {
            parser.close();
        }
    }

    public View inflate(XmlPullParser parser, @Nullable ViewGroup root, boolean attachToRoot) {
        synchronized (mConstructorArgs) {
            Trace.traceBegin(Trace.TRACE_TAG_VIEW, "inflate");

            final Context inflaterContext = mContext;
            final AttributeSet attrs = Xml.asAttributeSet(parser);
            Context lastContext = (Context) mConstructorArgs[0];
            mConstructorArgs[0] = inflaterContext;
            View result = root;

            try {
                // Look for the root node.
                int type;
                //非xml起始与结尾标记
                while ((type = parser.next()) != XmlPullParser.START_TAG &&
                        type != XmlPullParser.END_DOCUMENT) {
                }
            
                if (type != XmlPullParser.START_TAG) {
                    throw new InflateException(parser.getPositionDescription()
                            + ": No start tag found!");
                }

                final String name = parser.getName();
                //处理<merge>标签
                if (TAG_MERGE.equals(name)) {
                    if (root == null || !attachToRoot) {
                        throw new InflateException("<merge /> can be used only with a valid "
                                + "ViewGroup root and attachToRoot=true");
                    }
                    //传入rootview 解析得到的布局直接加入rootView中
                    rInflate(parser, root, inflaterContext, attrs, false);
                } else {
                    // Temp is the root view that was found in the xml
                    //根据Tag创建对应的View 例如<TextView>
                    final View temp = createViewFromTag(root, name, inflaterContext, attrs);

                    ViewGroup.LayoutParams params = null;

                    if (root != null) {
                        // Create layout params that match root, if supplied
                        params = root.generateLayoutParams(attrs);
                        if (!attachToRoot) {
                            // Set the layout params for temp if we are not
                            // attaching. (If we are, we use addView, below)
                            temp.setLayoutParams(params);
                        }
                    }

                    // Inflate all children under temp against its context.
                    //创建temp子View
                    rInflateChildren(parser, temp, attrs, true);

                    // We are supposed to attach all the views we found (int temp)
                    // to root. Do that now.
                    if (root != null && attachToRoot) {
                        //将temp添加到rootView中
                        root.addView(temp, params);
                    }

                    // Decide whether to return the root that was passed in or the
                    // top view found in xml.
                    if (root == null || !attachToRoot) {
                        //attachToRoot：将View添加到RootView中，非就是直接返回解析的子View
                        result = temp;
                    }
                }

            } catch (XmlPullParserException e) {
                final InflateException ie = new InflateException(e.getMessage(), e);
                ie.setStackTrace(EMPTY_STACK_TRACE);
                throw ie;
            } catch (Exception e) {
                final InflateException ie = new InflateException(parser.getPositionDescription()
                        + ": " + e.getMessage(), e);
                ie.setStackTrace(EMPTY_STACK_TRACE);
                throw ie;
            } finally {
                // Don't retain static reference on context.
                mConstructorArgs[0] = lastContext;
                mConstructorArgs[1] = null;

                Trace.traceEnd(Trace.TRACE_TAG_VIEW);
            }

            return result;
        }
    }

    void rInflate(XmlPullParser parser, View parent, Context context,
            AttributeSet attrs, boolean finishInflate) throws XmlPullParserException, IOException {

        final int depth = parser.getDepth();
        int type;
        boolean pendingRequestFocus = false;

        while (((type = parser.next()) != XmlPullParser.END_TAG ||
                parser.getDepth() > depth) && type != XmlPullParser.END_DOCUMENT) {

            if (type != XmlPullParser.START_TAG) {
                continue;
            }

            final String name = parser.getName();

            if (TAG_REQUEST_FOCUS.equals(name)) {
                pendingRequestFocus = true;
                consumeChildElements(parser);
            } else if (TAG_TAG.equals(name)) {
                parseViewTag(parser, parent, attrs);
            } else if (TAG_INCLUDE.equals(name)) {//<include>
                if (parser.getDepth() == 0) {
                    throw new InflateException("<include /> cannot be the root element");
                }
                parseInclude(parser, context, parent, attrs);
            } else if (TAG_MERGE.equals(name)) {//<merge>
                throw new InflateException("<merge /> must be the root element");
            } else {
                //创建View
                final View view = createViewFromTag(parent, name, context, attrs);
                final ViewGroup viewGroup = (ViewGroup) parent;
                final ViewGroup.LayoutParams params = viewGroup.generateLayoutParams(attrs);
                //递归创建子View
                rInflateChildren(parser, view, attrs, true);
                //创建的子View添加会parent
                viewGroup.addView(view, params);
            }
        }

        if (pendingRequestFocus) {
            parent.restoreDefaultFocus();
        }

        if (finishInflate) {
            parent.onFinishInflate();
        }
    }
```

`layoutInflater.inflate()`主要是调用`createViewFromTag()`从xml生成view的。

#### * createViewFromTag()

> 主要负责将`<tag>`创建成`View`对象

```java
//LayoutInflater.java
View createViewFromTag(View parent, String name, Context context, AttributeSet attrs,
            boolean ignoreThemeAttr) {
        /**
        * view标签 取class 做为name
        */
        if (name.equals("view")) {
            name = attrs.getAttributeValue(null, "class");
        }

        // 设置View的Theme
        if (!ignoreThemeAttr) {
            final TypedArray ta = context.obtainStyledAttributes(attrs, ATTRS_THEME);
            final int themeResId = ta.getResourceId(0, 0);
            if (themeResId != 0) {
                context = new ContextThemeWrapper(context, themeResId);
            }
            ta.recycle();
        }
        //处理 <blink>标签
        if (name.equals(TAG_1995)) {
            // Let's party like it's 1995!
            return new BlinkLayout(context, attrs);
        }

        try {
            View view;
            //通过Factory /Factory2  进行View的实例化
            if (mFactory2 != null) {
                view = mFactory2.onCreateView(parent, name, context, attrs);
            } else if (mFactory != null) {
                view = mFactory.onCreateView(name, context, attrs);
            } else {
                view = null;
            }
            //通过 mPrivateFactory实例化View
            if (view == null && mPrivateFactory != null) {
                view = mPrivateFactory.onCreateView(parent, name, context, attrs);
            }
            //未设置 Factory，走默认创建View的流程
            if (view == null) {
                final Object lastContext = mConstructorArgs[0];
                mConstructorArgs[0] = context;
                try {
                    //<tag>中存在 . 可以判断为自定义View，走View自身的创建流程
                    if (-1 == name.indexOf('.')) {
                        view = onCreateView(parent, name, attrs);
                    } else {
                        view = createView(name, null, attrs);
                    }
                } finally {
                    mConstructorArgs[0] = lastContext;
                }
            }

            return view;
        } 
        ,,,
    }
}
      
```

`createViewFromTag()`主要做了以下几步：

1. 如果为`<view>`标签，读取`class`属性做为类名

   ```xml
   <view class="LinearLayout"/> 等价于<LinearLayout></LinearLayout>
   ```

   

2. 应用`ContenxtThemeWrapper`为View设置主题`Theme`

3. 使用`Factory/Factory2/mPrivateFactory`实例化`View`，相当于**拦截**

   > 实例化`View`的优先顺序为`Factory2 > Factory > mPrivateFactory > PhoneLayoutInflater`

4. 未设置`以上factory`，执行`View`的默认创建流程

   > 主要通过`PhoneLayoutInflater`执行



### Factory/Factory2-拦截View创建

![LayoutInflater-Factory2](/images/LayoutInflater-Factory2.png)

> 在上节有说到`Factory/Factory2`执行相当于拦截的功能，`hook`View创建的流程
>
> `mPrivateFactory`实现了`Factory2`接口，主要用于拦截`<fragment>`标签处理

```java
    private Factory mFactory;
    private Factory2 mFactory2;
    private Factory2 mPrivateFactory;

    public interface Factory {
        public View onCreateView(String name, Context context, AttributeSet attrs);
    }

    public interface Factory2 extends Factory {
        public View onCreateView(View parent, String name, Context context, AttributeSet attrs);
    }
```

`Factory2`相对于`Factory`在`onCreateView()`多传入了`parent`

#### Factroy2

设置`Factroy2`的方法

```java
    public void setFactory2(Factory2 factory) {
        if (mFactorySet) { //只允许设置一次 Factory2
            throw new IllegalStateException("A factory has already been set on this LayoutInflater");
        }
        if (factory == null) {//设置的factory不能为null
            throw new NullPointerException("Given factory can not be null");
        }
        mFactorySet = true;
        if (mFactory == null) {
            mFactory = mFactory2 = factory;
        } else {
            //控制factory调用顺序
            mFactory = mFactory2 = new FactoryMerger(factory, factory, mFactory, mFactory2);
        }
    }
```

```java
    private static class FactoryMerger implements Factory2 {
        private final Factory mF1, mF2;
        private final Factory2 mF12, mF22;

        FactoryMerger(Factory f1, Factory2 f12, Factory f2, Factory2 f22) {
            mF1 = f1;
            mF2 = f2;
            mF12 = f12;
            mF22 = f22;
        }

      //此处对应Factory
        public View onCreateView(String name, Context context, AttributeSet attrs) {
            View v = mF1.onCreateView(name, context, attrs);
            if (v != null) return v;
            return mF2.onCreateView(name, context, attrs);
        }
       //此处对应Factory2
        public View onCreateView(View parent, String name, Context context, AttributeSet attrs) {
            View v = mF12 != null ? mF12.onCreateView(parent, name, context, attrs)
                    : mF1.onCreateView(name, context, attrs);
            if (v != null) return v;
            return mF22 != null ? mF22.onCreateView(parent, name, context, attrs)
                    : mF2.onCreateView(name, context, attrs);
        }
    }
```

最终都是通过`FactoryMerger`执行的`onCreateView`

##### 何处调用setFactory2()

```java
//AppCompatActivity.onCreate() -> AppCompatDelegate.installViewFactory() ->
//AppCompatDelegateImpl.installViewFactory()
    public void installViewFactory() {
        LayoutInflater layoutInflater = LayoutInflater.from(this.mContext);
        if (layoutInflater.getFactory() == null) {
            LayoutInflaterCompat.setFactory2(layoutInflater, this);
        } else if (!(layoutInflater.getFactory2() instanceof AppCompatDelegateImpl)) {
            Log.i("AppCompatDelegate", "The Activity's LayoutInflater already has a Factory installed so we can not install AppCompat's");
        }
    }

//设置Factory2执行到 onCreateView()
    public final View onCreateView(View parent, String name, Context context, AttributeSet attrs) {
        return this.createView(parent, name, context, attrs);
    }

    public View createView(View parent, String name, @NonNull Context context, @NonNull AttributeSet attrs) {
        if (this.mAppCompatViewInflater == null) {
            TypedArray a = this.mContext.obtainStyledAttributes(styleable.AppCompatTheme);
            String viewInflaterClassName = a.getString(styleable.AppCompatTheme_viewInflaterClass);
            if (viewInflaterClassName != null && !AppCompatViewInflater.class.getName().equals(viewInflaterClassName)) {
                try {
                    Class viewInflaterClass = Class.forName(viewInflaterClassName);
                    this.mAppCompatViewInflater = (AppCompatViewInflater)viewInflaterClass.getDeclaredConstructor().newInstance();
                } catch (Throwable var8) {
                    Log.i("AppCompatDelegate", "Failed to instantiate custom view inflater " + viewInflaterClassName + ". Falling back to default.", var8);
                    this.mAppCompatViewInflater = new AppCompatViewInflater();
                }
            } else {
                this.mAppCompatViewInflater = new AppCompatViewInflater();
            }
        }

        ...
        return this.mAppCompatViewInflater.createView(...);
    }

```

通过`AppCompatViewInflater`去执行View的创建

```java
//AppCompatViewInflater.java
    final View createView(View parent, String name, @NonNull Context context, @NonNull AttributeSet attrs, boolean inheritContext, boolean readAndroidTheme, boolean readAppTheme, boolean wrapContext) {
  ...
     switch (name) {
            case "TextView":
                view = createTextView(context, attrs);
                verifyNotNull(view, name);
                break;
         ...
     }
}

    @NonNull
    protected AppCompatTextView createTextView(Context context, AttributeSet attrs) {
        return new AppCompatTextView(context, attrs);
    }


```

此处可以在使用到`AppCompatActivity`时，将原先的`<TextView>`转换为`AppCompatTextView`



#### mPrivateFactory

> 系统hide对象，无法被外界使用，主要处理`<fragment>`

```java
    public void setPrivateFactory(Factory2 factory) {
        if (mPrivateFactory == null) {
            mPrivateFactory = factory;
        } else {
            mPrivateFactory = new FactoryMerger(factory, factory, mPrivateFactory, mPrivateFactory);
        }
    }
```

##### 何处调用setPrivateFactory()

```java
//Activity.java
final void attach(Context context, ActivityThread aThread,
            Instrumentation instr, IBinder token, int ident,
            Application application, Intent intent, ActivityInfo info,
            CharSequence title, Activity parent, String id,
            NonConfigurationInstances lastNonConfigurationInstances,
            Configuration config, String referrer, IVoiceInteractor voiceInteractor,
            Window window, ActivityConfigCallback activityConfigCallback) {
  ...
    mWindow.getLayoutInflater().setPrivateFactory(this); //this 表示当前Activity
  ...
}

    public View onCreateView(View parent, String name, Context context, AttributeSet attrs) {
        if (!"fragment".equals(name)) {
            return onCreateView(name, context, attrs);
        }
       //<fragment>标签直接解析执行 onCreateView
        return mFragments.onCreateView(parent, name, context, attrs);
    }

```

#### 拓展使用

系统通过`Factory`提供`hook`方法，方便拦截`LayoutInflater`创建View的过程。支持以下应用场景：

- 支持对自定义标签名称的处理
- 全局替换系统控件为自定义View
- **替换字体**
- **全局换肤**
- **获取控件加载耗时**

针对以上场景，实现部分关键代码以供参考

##### 获取控件加载耗时

```java
//XXActivity.java
    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
      //设置自定义Factory
        setFactory2();
        super.onCreate(savedInstanceState);
        setContentView(R.layout.act_xx);
    }

    private void setFactory2(){
        LayoutInflaterCompat.setFactory2(getLayoutInflater(), new LayoutInflater.Factory2() {
            @Override
            public View onCreateView(View parent, String name, Context context, AttributeSet attrs) {
                long startTime = System.currentTimeMillis();//加载开始时间
                View view = getDelegate().createView(parent, name, context, attrs);//开始加载
                long costTime = System.currentTimeMillis() - startTime;//加载结束时间
                Log.e("costTime",costTime+"");
                return view;
            }

            @Override
            public View onCreateView(String name, Context context, AttributeSet attrs) {
                return null;
            }
        });
    }
```

`setFactory2()`不可以放到`super.onCreate()`之后，会触发`A factory has already been set on this LayoutInflater`异常，原因就在于`setFactory2()`最多支持设置一个。



##### 替换字体

```java
    private void setFontFactory2() {
        LayoutInflaterCompat.setFactory2(getLayoutInflater(), new LayoutInflater.Factory2() {
            @Override
            public View onCreateView(View parent, String name, Context context, AttributeSet attrs) {
                View view = getDelegate().createView(parent, name, context, attrs);
                if (view instanceof TextView ) {
                    ((TextView) view).setTypeface(XX);//设置对应字体
                }
                return view;
            }

            @Override
            public View onCreateView(String name, Context context, AttributeSet attrs) {
                return null;
            }
        });
    }
```



只要执行了`getDelegate().createView()`可以保证`原生控件->兼容控件`功能正常。

### View默认创建流程

![LayoutInflater-默认View创建流程](/images/LayoutInflater-默认View创建流程.png)

> 未设置`Factory/Factory2`就会执行默认的View创建流程

```java
//LayoutInflater.java
    View createViewFromTag(View parent, String name, Context context, AttributeSet attrs,
            boolean ignoreThemeAttr) {
      ...
        if (view == null) {
                final Object lastContext = mConstructorArgs[0];
                mConstructorArgs[0] = context;
                try {
                    if (-1 == name.indexOf('.')) {
                        view = onCreateView(parent, name, attrs);//系统提供View
                    } else {
                        view = createView(name, null, attrs);//自定义View
                    }
                } finally {
                    mConstructorArgs[0] = lastContext;
                }
            }
      ...
    }
```

#### 系统提供View

> 例如`<TextView/>、<Button/>`等

```java
public class PhoneLayoutInflater extends LayoutInflater {
     private static final String[] sClassPrefixList = {
        "android.widget.",
        "android.webkit.",
        "android.app."
    };

     @Override protected View onCreateView(String name, AttributeSet attrs) throws ClassNotFoundException {
        for (String prefix : sClassPrefixList) {
            try {
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

//LayoutInflater.java
    protected View onCreateView(String name, AttributeSet attrs)
            throws ClassNotFoundException {
        return createView(name, "android.view.", attrs);
    }

```

优先判断

- `android.widget.*` 例如`android.widget.TextView`
- `android.webkit.*` 例如`android.webkit.WebView`
- `android.app.*` 例如`android.app.ActionBar`

是否有对应`nmae`的View实例存在

都不存在，就在`android.view.*`找寻对应View实例 例如`android.view.ViewStub`

#### 自定义View

> 例如`android.support.v7.widget.RecyclerView`等

```java
public final View createView(String name, String prefix, AttributeSet attrs)
            throws ClassNotFoundException, InflateException {
       //构建缓存，缓存已加载的View
        Constructor<? extends View> constructor = sConstructorMap.get(name);
        if (constructor != null && !verifyClassLoader(constructor)) {
            constructor = null;
            sConstructorMap.remove(name);
        }
        Class<? extends View> clazz = null;

        try {
            Trace.traceBegin(Trace.TRACE_TAG_VIEW, name);
            //新建View构造器
            if (constructor == null) {
                // 得到全限定名 例如android,widget.TextView
                clazz = mContext.getClassLoader().loadClass(
                        prefix != null ? (prefix + name) : name).asSubclass(View.class);

                if (mFilter != null && clazz != null) {
                    boolean allowed = mFilter.onLoadClass(clazz);
                    if (!allowed) {
                        failNotAllowed(name, prefix, attrs);
                    }
                }
                constructor = clazz.getConstructor(mConstructorSignature);
                constructor.setAccessible(true);
                sConstructorMap.put(name, constructor);
            } else {
                // If we have a filter, apply it to cached constructor
                if (mFilter != null) {
                    // Have we seen this name before?
                    Boolean allowedState = mFilterMap.get(name);
                    if (allowedState == null) {
                        // New class -- remember whether it is allowed
                        clazz = mContext.getClassLoader().loadClass(
                                prefix != null ? (prefix + name) : name).asSubclass(View.class);

                        boolean allowed = clazz != null && mFilter.onLoadClass(clazz);
                        mFilterMap.put(name, allowed);
                        if (!allowed) {
                            failNotAllowed(name, prefix, attrs);
                        }
                    } else if (allowedState.equals(Boolean.FALSE)) {
                        failNotAllowed(name, prefix, attrs);
                    }
                }
            }

            Object lastContext = mConstructorArgs[0];
            if (mConstructorArgs[0] == null) {
                // Fill in the context if not already within inflation.
                mConstructorArgs[0] = mContext;
            }
            Object[] args = mConstructorArgs;
            args[1] = attrs;
            //根据得到的 constuctor 实例化View对象
            final View view = constructor.newInstance(args);
            //针对ViewStub特殊处理
            if (view instanceof ViewStub) {
                // Use the same context when inflating ViewStub later.
                final ViewStub viewStub = (ViewStub) view;
                viewStub.setLayoutInflater(cloneInContext((Context) args[0]));
            }
            mConstructorArgs[0] = lastContext;
            return view;

        } 
  ...
    }
```

#### 执行流程

`View默认创建`流程分为：

- `<tag>`不包含`.`，用于处理`<TextView>、<WebView>`等标签，此时需要拼接`android.widget. 或 android.webkit. 或 android.app. `前缀(**实现位于`PhoneLayoutInflater`**)，都没有找到对应的`View实例`时，就会在添加`android.view.`再去加载。
- `<tag>`包含`.`，此时的实例View分为以下几步：
  - 构建View的缓存，缓存的是`constructor`，根据`name`获取`constructor`
  - 缓存中不存在时，需要根据`prefix+name`获取View的`constructor`，并存入缓存中
  - 根据`constructor`构造`View实例`——`constructor.newInstance()`
  - 如果需要处理`ViewStub`，为`ViewStub`指定加载类



### 总结

![LayoutInflater过程](/images/LayoutInflater过程.jpg)



## View的绘制流程触发

调用了`ViewRootImpl.setView(decorView)`将DecorView与ViewRootImpl进行了关联。View的绘制流程就是从ViewRoot开始的。

```java
 public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
     synchronized(this){
         //传进来的DecorView作为全局变量使用
          mView = view;
         ...
          // Schedule the first layout -before- adding to the window
                // manager, to make sure we do the relayout before receiving
                // any other events from the system.
          //绘制整个布局
          requestLayout();   
         ...
          //设置ViewRootImpl为DecorView的parentView 
          view.assignParent(this);
     }   
 }

//请求刷新整个布局
    @Override
    public void requestLayout() {
        if (!mHandlingLayoutInLayoutRequest) {
            checkThread();
            mLayoutRequested = true;
            scheduleTraversals();
        }
    }

    void scheduleTraversals() {
        if (!mTraversalScheduled) {
            mTraversalScheduled = true;
            //添加同步屏障
            mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
            mChoreographer.postCallback(
                    Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
            if (!mUnbufferedInputDispatch) {
                scheduleConsumeBatchedInput();
            }
            notifyRendererOfFramePending();
            pokeDrawLockIfNeeded();
        }
    }

    final class TraversalRunnable implements Runnable {
        @Override
        public void run() {
            doTraversal();
        }
    }
    final TraversalRunnable mTraversalRunnable = new TraversalRunnable();

    void doTraversal() {
        if (mTraversalScheduled) {
            mTraversalScheduled = false;
            //移除同步屏障
            mHandler.getLooper().getQueue().removeSyncBarrier(mTraversalBarrier);

            if (mProfile) {
                Debug.startMethodTracing("ViewAncestor");
            }
            //这里开始View的绘制流程
            performTraversals();

            if (mProfile) {
                Debug.stopMethodTracing();
                mProfile = false;
            }
        }
    }
```

`ViewRootImpl.setView()`中最后调用到了`performTraversals()`在这个方法中开始View的绘制流程

```java
private void performTraversals() {
  ...
   boolean layoutRequested = mLayoutRequested && (!mStopped || mReportNextDraw);
   
   ...
   if (!mStopped || mReportNextDraw) {
      int childHeightMeasureSpec = getRootMeasureSpec(mHeight, lp.height);
	  int childHeightMeasureSpec = getRootMeasureSpec(mHeight, lp.height);
      ...
        if(layoutRequested){
          //开始Measure过程，定义View的宽高
          performMeasure(childWidthMeasureSpec, childHeightMeasureSpec);
          ...
        }
   }
  
    final boolean didLayout = layoutRequested && (!mStopped || mReportNextDraw);
    if(didLayout){
        //开始Layout过程，决定View的位置
        performLayout(lp, mWidth, mHeight);
        ...
    }
    
     if (!cancelDraw && !newSurface) {
            if (mPendingTransitions != null && mPendingTransitions.size() > 0) {
                for (int i = 0; i < mPendingTransitions.size(); ++i) {
                    mPendingTransitions.get(i).startChangingAnimations();
                }
                mPendingTransitions.clear();
            }
            //开始Draw过程，决定了View的显示，这个过程结束才可以看到内容
            performDraw();
     }
}        
```

通过以上流程分析：**View的绘制流程是从`ViewRootImpl`中开始的，先调用`performTraversals()`开始绘制，随后调用内部的`performMeasure()`开始Measure过程，调用`performLayout()`，开始Layout过程，最后调用`performDraw()`开始Draw，完成后就可以现在在屏幕上。**



![View绘制流程](/images/View绘制流程.png)

如上图所示，`performTraversals()`依次调用`performMeasure()，performLayout(),performDraw()`完成View的绘制。



## View工作流程

> 主要是指`measure(测量)`,`layout(布局)`,`draw(绘制)`三大流程。

### measure-测量



> 起点位于`performMeasure()`。

```java
//ViewRootImpl.java
    private void performMeasure(int childWidthMeasureSpec, int childHeightMeasureSpec) {
       ...
        try {
            mView.measure(childWidthMeasureSpec, childHeightMeasureSpec);
        } finally {
            Trace.traceEnd(Trace.TRACE_TAG_VIEW);
        }
    }
```



#### MeasureSpec

![measure-MeasureSpec](/images/measure-MeasureSpec.png)

> MeasureSpec代表一个32位int值，高2位代表SpecMode(测量模式)，低30位代表SpecSize(某种测量模式下的规格大小)。

作用：父控件提供给子View的一个参数，作为设定自身大小参考，实际大小还是有子View自身决定。

![MeasureSpec结构](/images/MeasureSpec结构)

##### 结构

```java
 public static class MeasureSpec {
        private static final int MODE_SHIFT = 30;
        private static final int MODE_MASK  = 0x3 << MODE_SHIFT;

        /** @hide */
        @IntDef({UNSPECIFIED, EXACTLY, AT_MOST})
        @Retention(RetentionPolicy.SOURCE)
        public @interface MeasureSpecMode {}
     
      public static final int UNSPECIFIED = 0 << MODE_SHIFT;
      public static final int EXACTLY     = 1 << MODE_SHIFT;
      public static final int AT_MOST     = 2 << MODE_SHIFT;

      @MeasureSpecMode
       public static int getMode(int measureSpec) {
            //noinspection ResourceType
            return (measureSpec & MODE_MASK);
        }
          
       public static int getSize(int measureSpec) {
            return (measureSpec & ~MODE_MASK);
        }
```

`SpecMode`分为三类：

- `UNSPECIFIED`：**未指定模式**。父控件不对子控件添加束缚，子元素可以为任意大小，一般用于系统内部的测量。比如`ScrollView`
- `EXACTLY`：**精确模式**。父控件为子View指定精确大小，希望子View完全按照自己给的尺寸处理大小。一般是设置了`明确的值`或是`MATCH_PARENT`
- `AT_MOST`：**最大模式**。父控件为子View指定最大尺寸，希望子View不要超过这个尺寸。一般对应`WRAP_CONTENT`



##### MeasureSpec与LayoutParams的关系

每一个View，都持有一个MeasureSpec，里面保存了View的尺寸。我们也可以使用`LayoutParams`指定View的尺寸。所以在View测量的时候，系统会将`LayoutParams`在父容器的约束下转换成`MeasureSpec`，然后根据转换后的值确定宽高。

**转换后的MeasureSpec是由LayoutParams和父容器的MeasureSpec一起决定的。**

| 下：childLayoutParams 右：parentSpecMode | EXACTLY                                    | AT_MOST                                    | UNSPECIFIED                                         |
| ---------------------------------------- | ------------------------------------------ | ------------------------------------------ | --------------------------------------------------- |
| 固定大小                                 | Exactly<br>childSize                       | Exactly<br/>childSize                      | Exactly<br/>childSize                               |
| match_parent                             | Exactly<br/>parentSize(父容器剩余空间)     | AT_MOST<br/>parentSize(最大父容器剩余空间) | UNSPECIFIED<br>0 或 parentSize(最大父容器剩余空间)  |
| wrap_content                             | AT_MOST<br/>parentSize(最大父容器剩余空间) | AT_MOST<br/>parentSize(最大父容器剩余空间) | UNSPECIFIED<br/>0 或 parentSize(最大父容器剩余空间) |

根据`ViewGroup.getChildMeasureSpec()`得出上表。

###### DecorView转换MeasureSpec

> DecorView的转换由Window的尺寸和自身的LayoutParams决定。

```java
// ../android/view/ViewRootImpl.java
private void performTraversals() {
    ...
       //DecorView Measure过程
       int childWidthMeasureSpec = getRootMeasureSpec(mWidth, lp.width);
       int childHeightMeasureSpec = getRootMeasureSpec(mHeight, lp.height);
       performMeasure(childWidthMeasureSpec,childHeightMeasureSpec)
    ...  
}

//在方法中生成了DecoeView的MeasureSpec 根据Window的尺寸和自身的LayoutParams
private static int getRootMeasureSpec(int windowSize/*Window尺寸*/, int rootDimension) {
        int measureSpec;
        switch (rootDimension) {
       
        case ViewGroup.LayoutParams.MATCH_PARENT:
            //MeasureSpec中的specSize就是窗口尺寸,specMode为EXACTLY 精确模式
            measureSpec = MeasureSpec.makeMeasureSpec(windowSize, MeasureSpec.EXACTLY);
            break;
        case ViewGroup.LayoutParams.WRAP_CONTENT:
            //MeasureSpec中的specSize为窗口尺寸,specMode为aT_MOST 最大模式，最大值为窗口尺寸
            measureSpec = MeasureSpec.makeMeasureSpec(windowSize, MeasureSpec.AT_MOST);
            break;
        default:
            //MeasureSpec中的specSize为固定尺寸,specMode为EXACTLY 精确模式
            measureSpec = MeasureSpec.makeMeasureSpec(rootDimension, MeasureSpec.EXACTLY);
            break;
        }
        return measureSpec;
    }

```



#### View的measure过程

![measure-View的measure过程](/images/measure-View的measure过程.png)

主要是由`measure()`方法完成

```java
// ../android/view/View.java
    public final void measure(int widthMeasureSpec, int heightMeasureSpec) {
      ...
        //需要执行onMeasure
        final boolean forceLayout = (mPrivateFlags & PFLAG_FORCE_LAYOUT) == PFLAG_FORCE_LAYOUT;
        // 布局发生变化
        final boolean needsLayout = specChanged
                && (sAlwaysRemeasureExactly || !isSpecExactly || !matchesSpecSize);      
      ...
        if (forceLayout/*强制测量*/ || needsLayout/*需要测量*/) {
          ...
          int cacheIndex = forceLayout ? -1 : mMeasureCache.indexOfKey(key);
          //需要强制测量布局 或者。缓存无效
            if (cacheIndex < 0 || sIgnoreMeasureCache) {
                // measure ourselves, this should set the measured dimension flag back
                onMeasure(widthMeasureSpec, heightMeasureSpec);
                mPrivateFlags3 &= ~PFLAG3_MEASURE_NEEDED_BEFORE_LAYOUT;
            } else {
                long value = mMeasureCache.valueAt(cacheIndex);
                // Casting a long to int drops the high 32 bits, no mask needed
                setMeasuredDimensionRaw((int) (value >> 32), (int) value);
              //需要在layout 再次执行 onMeasure
                mPrivateFlags3 |= PFLAG3_MEASURE_NEEDED_BEFORE_LAYOUT;
            }
          ...
            //添加 PFLAG_LAYOUT_REQUIRED标记，表示需要执行 layout流程
             mPrivateFlags |= PFLAG_LAYOUT_REQUIRED;
        }
    }
```

在`measure()`中调用`onMeasure()`去进行实际的测量

```java
//../android/view/View.java
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        setMeasuredDimension(
            getDefaultSize(getSuggestedMinimumWidth(), widthMeasureSpec),
            getDefaultSize(getSuggestedMinimumHeight(), heightMeasureSpec));
    }

   //设置View的宽高
   protected final void setMeasuredDimension(int measuredWidth, int measuredHeight) {
        boolean optical = isLayoutModeOptical(this);
        if (optical != isLayoutModeOptical(mParent)) {
            Insets insets = getOpticalInsets();
            int opticalWidth  = insets.left + insets.right;
            int opticalHeight = insets.top  + insets.bottom;

            measuredWidth  += optical ? opticalWidth  : -opticalWidth;
            measuredHeight += optical ? opticalHeight : -opticalHeight;
        }
        setMeasuredDimensionRaw(measuredWidth, measuredHeight);
    }

    private void setMeasuredDimensionRaw(int measuredWidth, int measuredHeight) {
        mMeasuredWidth = measuredWidth;
        mMeasuredHeight = measuredHeight;
        mPrivateFlags |= PFLAG_MEASURED_DIMENSION_SET;
    }

    //返回View的MeasureSpec中的specSize
    public static int getDefaultSize(int size, int measureSpec) {
        int result = size;
        int specMode = MeasureSpec.getMode(measureSpec);
        int specSize = MeasureSpec.getSize(measureSpec);

        switch (specMode) {
        case MeasureSpec.UNSPECIFIED:
            result = size;
            break;
        case MeasureSpec.AT_MOST://wrap_content
        case MeasureSpec.EXACTLY://match_parent / XX 
        //这段代码中可以分析得出 一个直接继承View的自定义View 定义为wrap_content和match_parent大小都是一致的.
            result = specSize;
            break;
        }
        return result;
    }

    protected int getSuggestedMinimumHeight() {
        return (mBackground == null) ? mMinHeight : max(mMinHeight, mBackground.getMinimumHeight());
    }

//如果View没有设置背景，返回minWidth值，默认为0。若设置了背景就取背景宽度和最小宽度中的最大值返回。
    protected int getSuggestedMinimumWidth() {
        return (mBackground == null) ? mMinWidth : max(mMinWidth, mBackground.getMinimumWidth());
    }

    
// ../android/graphics/drawable/Drawable.java
public int getMinimumWidth(){
    final int intrinsicWidth = getIntrinsicWidth();
    return intrinsicWidth > 0 ? intrinsicWidth : 0;
}


```



![View-Measure](/images/View-Measure.png)

结合上述流程图，简单分析View的Measure过程

- 系统在绘制开始时回去调用`View.measure()`，这个类是final的们无法被重写
- 后续调用`View.onMeasure()`,自定义View时可以按照自己的需求对这个方法进行重写
- `onMeasure()`中调用到`setMeasureDimension()`对View进行宽高的设置
- 需要使用`getDefaultSize()`去获取最终显示出的宽高
- 在`getDefaultSize()`中需要对传进来的`MeasureSpec`进行分析处理
  - SpecMode若为`UNSPECIFIED`，则最终尺寸为传进来的`SpecSize`
  - SpecMode为`AT_MOST`,`EXACTLY`，还需要额外判断View是否有背景
    - 有背景，最终尺寸就为View的最小尺寸和背景尺寸的最大值
    - 没背景，最终尺寸就为View的最小尺寸
- 取到最终尺寸后，数据回溯到`onMeasure()`中，即完成测量(`Measure`)过程

在上述分析中，自定义View中使用`wrap_content`时，specMode为`AT_MOST`，尺寸为父控件剩余大小，效果与使用`match_parent`一致。这也是自定义View中常碰到的问题 *为何自定义View是wrap_content无效？* 解决方法就是 自己重写`onMeasure()`对`wrap_content`特殊处理。

```java
public void onMeasure(int widthMeasureSpec,int heightMeasureSpec){
    super.onMeasure(widthMeasureSpec,heightMeasureSpec);
    int widthSpecMode = MeasureSpec.getMode(widthMeasureSpec);
    int heightSpecMode = MeasureSpec.getMode(heightMeasureSpec);
    int widthSpecSize = MeasureSpec.getSize(widthMeasureSpec);
    int heightSpecSize = MeasureSpec.getSize(heightMeasureSpec);
    
    if(widthSpecMode = MeasureSpec.AT_MOST && heightSpecMode = MeasureSpec.AT_MOST){
        setMeasureDimension(mWidth,mHeight);
    }else if(widthSpecMode = MeasureSpec.AT_MOST){
        setMeasureDimension(mWidth,heightSpecSize);
    }else if(heightSpecMode = MeasureSpec.AT_MOST){
        setMeasureDimension(widthSpecSize,mHeight);
    }
    
}
```

#### ViewGroup的measure过程

![measure-ViewGroup的measure过程](/images/measure-ViewGroup的measure过程.png)

> 除了完成自身的measure过程之外，还要去遍历调用所有子元素的measure方法，各个子元素再去递归执行这个过程。
>
> **先Measure子View，再Measure自己**

ViewGroup中没有定义`onMeasure()`，定义了一个`measureChildren()`。

```java
// ../android/view/ViewGroup.java
protected void measureChildren(int widthMeasureSpec, int heightMeasureSpec) {
        final int size = mChildrenCount;
        final View[] children = mChildren;
        for (int i = 0; i < size; ++i) {
            final View child = children[i];
            if ((child.mViewFlags & VISIBILITY_MASK) != GONE) {
                //遍历对每一个子元素进行测量过程
                measureChild(child, widthMeasureSpec, heightMeasureSpec);
            }
        }
    }
```

循环调用`measureChild()`

```java
// ../android/view/ViewGroup.java
protected void measureChild(View child, int parentWidthMeasureSpec,
            int parentHeightMeasureSpec) {
        //获得子View的LayoutParams
        final LayoutParams lp = child.getLayoutParams();
        //
        final int childWidthMeasureSpec = getChildMeasureSpec(parentWidthMeasureSpec,
                mPaddingLeft + mPaddingRight, lp.width);
        final int childHeightMeasureSpec = getChildMeasureSpec(parentHeightMeasureSpec,
                mPaddingTop + mPaddingBottom, lp.height);

        child.measure(childWidthMeasureSpec, childHeightMeasureSpec);
    }

 //子View的MEasureSpec由父View的MEasureSpec以及自身的LayoutParams共同决定
    public static int getChildMeasureSpec(int spec, int padding, int childDimension) {
        int specMode = MeasureSpec.getMode(spec);
        int specSize = MeasureSpec.getSize(spec);

        //padding代指父View已占用的空间，子View无法使用，所以子View的空间需要减去padding部分
        int size = Math.max(0, specSize - padding);

        int resultSize = 0;
        int resultMode = 0;

        switch (specMode) {
        // Parent has imposed an exact size on us
        case MeasureSpec.EXACTLY:
            if (childDimension >= 0) {
                resultSize = childDimension;
                resultMode = MeasureSpec.EXACTLY;
            } else if (childDimension == LayoutParams.MATCH_PARENT) {
                // Child wants to be our size. So be it.
                resultSize = size;
                resultMode = MeasureSpec.EXACTLY;
            } else if (childDimension == LayoutParams.WRAP_CONTENT) {
                // Child wants to determine its own size. It can't be
                // bigger than us.
                resultSize = size;
                resultMode = MeasureSpec.AT_MOST;
            }
            break;

        // Parent has imposed a maximum size on us
        case MeasureSpec.AT_MOST:
            if (childDimension >= 0) {
                // Child wants a specific size... so be it
                resultSize = childDimension;
                resultMode = MeasureSpec.EXACTLY;
            } else if (childDimension == LayoutParams.MATCH_PARENT) {
                // Child wants to be our size, but our size is not fixed.
                // Constrain child to not be bigger than us.
                resultSize = size;
                resultMode = MeasureSpec.AT_MOST;
            } else if (childDimension == LayoutParams.WRAP_CONTENT) {
                // Child wants to determine its own size. It can't be
                // bigger than us.
                resultSize = size;
                resultMode = MeasureSpec.AT_MOST;
            }
            break;

        // Parent asked to see how big we want to be
        case MeasureSpec.UNSPECIFIED:
            if (childDimension >= 0) {
                // Child wants a specific size... let him have it
                resultSize = childDimension;
                resultMode = MeasureSpec.EXACTLY;
            } else if (childDimension == LayoutParams.MATCH_PARENT) {
                // Child wants to be our size... find out how big it should
                // be
                resultSize = View.sUseZeroUnspecifiedMeasureSpec ? 0 : size;
                resultMode = MeasureSpec.UNSPECIFIED;
            } else if (childDimension == LayoutParams.WRAP_CONTENT) {
                // Child wants to determine its own size.... find out how
                // big it should be
                resultSize = View.sUseZeroUnspecifiedMeasureSpec ? 0 : size;
                resultMode = MeasureSpec.UNSPECIFIED;
            }
            break;
        }
        //noinspection ResourceType
        return MeasureSpec.makeMeasureSpec(resultSize, resultMode);
    }
```

由于ViewGroup有不同布局的需要，很难统一，所以没有提供统一的`onMeasure()`方法，而是让子类自己去实现`onMeasure()`。



![ViewGroup-Measure](/images/ViewGroup-Measure.png)

根据上述流程图，简单总结一下：

- ViewGroup调用自身的`measureChildren()`，里面遍历自己的子View
- 遍历后调用`measureChild()`，准备给每一个子View计算它的`MeasureSpec`
- 调用`getChildMeasureSpec()`计算子View的`MeasureSpec`，需要结合父布局的`MeasureSpec`以及子View的`LayoutParams`共同得出结果
- 调用子View的`measure()`，完成子View的测量过程。
- 合并子View的测量值，得到ViewGroup的测量值

#### 拓展

1. 在Activity启动时获取View的尺寸？
   - 在 Activity#onWindowFocusChanged 回调中获取宽高。<br>`当Activity得到焦点或失去焦点的时候，这个方法都会被频繁调用`
   - view.post(runnable)，在 runnable 中获取宽高。
     `利用Handler通信机制，发送一个Runnable在MessageQuene中，当layout处理结束时则会发送一个消息通知UI线程，可以获取到实际宽高。`
   - ViewTreeObserver 添加 OnGlobalLayoutListener，在 onGlobalLayout 回调中获取宽高。
     `监听全局View的变化事件，使用后需要注意移除OnGlobalLayoutListener 监听，以免造成内存泄露`
   - 调用 view.measure()，再通过 getMeasuredWidth 和 getMeasuredHeight 获取宽高<br>`手动对view进行measure来得到View的尺寸。`
   
2. 不同ViewGroup实现的`getChildMeasureSpec()`可能导致不同结果

   > 每种ViewGroup的子类测量策略(`getChildMeasureSpec()`)不尽相同，就会导致显示结果不一致。
   
   ```xml
       <FrameLayout
           android:layout_width="match_parent"
           android:layout_height="300dp"
           android:background="@color/colorAccent">
   
           <Button
               android:layout_width="match_parent"
               android:layout_height="400dp" />
       </FrameLayout>
   
       <RelativeLayout
           android:layout_width="match_parent"
           android:layout_height="300dp">
   
           <Button
               android:layout_width="match_parent"
               android:layout_height="400dp" />
       </RelativeLayout>
   ```
   
   在`FrameLayout`和`RelativeLayout`中，`Button`显示效果不一致，
   
   - `FrameLayout`中`Button`高度为`400dp`
   - `RelativeLayout`中`Button`高度为`300dp`
   
   `FrameLayout`遵循默认的`ViewGroup.getChildMeasureSpec()`，`RelativeLayout`重写`getChildMeasureSpec()`。

### layout-布局

>ViewGroup用来确定子元素的位置，当ViewGroup位置被确定后，在`onLayout()`中遍历所有子View，并调用其`layout()`。
>
>**先layout自身后layout子元素。**
>
>起点位于`performLayout()`

```java
    private void performLayout(WindowManager.LayoutParams lp, int desiredWindowWidth,
            int desiredWindowHeight) {
       //正在执行layout流程
       mInLayout = true;

       final View host = mView;//对应DecorView
      //执行DecorView的layout过程
      host.layout(0, 0, host.getMeasuredWidth(), host.getMeasuredHeight());
       //在layout过程中 尚未执行requestLayout的view
       int numViewsRequestingLayout = mLayoutRequesters.size();
       if (numViewsRequestingLayout > 0) {
          //寻找mPrivateFlags为PFLAG_FORCE_LAYOUT的View
           ArrayList<View> validLayoutRequesters = getValidLayoutRequesters(mLayoutRequesters,
                        false);
                if (validLayoutRequesters != null) {
                  //当前View重新measure
                     measureHierarchy(host, lp, mView.getContext().getResources(),
                            desiredWindowWidth, desiredWindowHeight);     
                  //重新执行layout
                     host.layout(0, 0, host.getMeasuredWidth(), host.getMeasuredHeight());  
                  ...
                    //寻找尚未设置 PFLAG_FORCE_LAYOUT的View
                     validLayoutRequesters = getValidLayoutRequesters(mLayoutRequesters, true);                   
                     if (validLayoutRequesters != null) {
                        final ArrayList<View> finalRequesters = validLayoutRequesters;
                        // 执行requestLayout在下一帧执行时
                        getRunQueue().post(new Runnable() {
                            @Override
                            public void run() {
                                int numValidRequests = finalRequesters.size();
                                for (int i = 0; i < numValidRequests; ++i) {
                                    final View view = finalRequesters.get(i);
                                    Log.w("View", "requestLayout() improperly called by " + view +
                                            " during second layout pass: posting in next frame");
                                    view.requestLayout();
                                }
                            }
                        });
                    }                 
                }
       }
      
    }
```

主要执行了三步：

- 执行`DecorView`的`layout`过程
- 执行调用过`requestLayout()`的View(包含`PFLAG_FORCE_LAYOUT`标志)的`measure`和`layout`
- 还没调用过`requestLayout()`的View加入到队列中，等待下一帧绘制时执行

#### View的layout过程

![layout-View的layout过程](/images/layout-View的layout过程.png)

主要是由View的`layout()`方法实现

```java
// ../android/view/View.java   
public void layout(int l, int t, int r, int b) {
        if ((mPrivateFlags3 & PFLAG3_MEASURE_NEEDED_BEFORE_LAYOUT) != 0) {
          //需要再次测量 可能缓存无效
            onMeasure(mOldWidthMeasureSpec, mOldHeightMeasureSpec);
            mPrivateFlags3 &= ~PFLAG3_MEASURE_NEEDED_BEFORE_LAYOUT;
        }
        
        //左上角顶点距父容器左边的距离
        int oldL = mLeft;
        //左上角顶点距父容器上边的距离
        int oldT = mTop;
        //右下角顶点距父容器上边的距离
        int oldB = mBottom;
        //右下角顶点距父容器上边的距离
        int oldR = mRight;
        //判断本次布局流程是否发生了布局的变化
        boolean changed = isLayoutModeOptical(mParent) ?
                setOpticalFrame(l, t, r, b) : setFrame(l, t, r, b);

        if (changed || (mPrivateFlags & PFLAG_LAYOUT_REQUIRED) == PFLAG_LAYOUT_REQUIRED) {
          //通知View进行布局过程
            onLayout(changed, l, t, r, b);
            ...
              //通知View布局发生变化
            listenersCopy.get(i).onLayoutChange(this, l, t, r, b, oldL, oldT, oldR, oldB);              
        }
        ...
    }

//由于子View下是没有子类了，所以该方法内不没有任何代码实现 一般自定义View是不需要重写该方法的
protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
    
    }

private boolean setOpticalFrame(int left, int top, int right, int bottom) {
        Insets parentInsets = mParent instanceof View ?
                ((View) mParent).getOpticalInsets() : Insets.NONE;
        Insets childInsets = getOpticalInsets();
        //根据特效边框重新计算四个顶点的位置，然后调用setFrame重新计算
        return setFrame(
                left   + parentInsets.left - childInsets.left,
                top    + parentInsets.top  - childInsets.top,
                right  + parentInsets.left + childInsets.right,
                bottom + parentInsets.top  + childInsets.bottom);
    }

//保存本次布局信息
protected boolean setFrame(int left, int top, int right, int bottom) {
             boolean changed = false;

        if (mLeft != left || mRight != right || mTop != top || mBottom != bottom) {
            changed = true;

            // Remember our drawn bit
            int drawn = mPrivateFlags & PFLAG_DRAWN;

            int oldWidth = mRight - mLeft;
            int oldHeight = mBottom - mTop;
            int newWidth = right - left;
            int newHeight = bottom - top;
            boolean sizeChanged = (newWidth != oldWidth) || (newHeight != oldHeight);

            // 布局发生变化 需要执行重绘流程
            invalidate(sizeChanged);
            //重新计算View的四个顶点距父布局左上边框的距离
            mLeft = left;
            mTop = top;
            mRight = right;
            mBottom = bottom;
            mRenderNode.setLeftTopRightBottom(mLeft, mTop, mRight, mBottom);
            ...
        }
}


//判断当前View是否存在阴影或者外发光等边框效果
public static boolean isLayoutModeOptical(Object o) {
        return o instanceof ViewGroup && ((ViewGroup) o).isLayoutModeOptical();
    }
```



![View-Layout](/images/View-Layout.png)

按照流程图总结一下：

- View调用`layout()`开始布局过程(`确定最终宽高以及四个顶点的位置`)
- 根据是否有边缘效果(`例如发光，阴影`)
  - 有边缘效果，调用`setOpticalFrame()`去除边缘的影响，最终还是调用`setFrame()`设立自己的四个顶点
  - 无边缘效果，调用`setFrame()`设立自己的四个顶点
- 最后调用`onLayout()`最终确立宽高以及四点坐标。



#### ViewGroup的layout过程

![layout-ViewGroup的layout过程](/images/layout-ViewGroup的layout过程.png)

当有子View存在的时候，需要遍历子View进行`layout`过程。即需要在`onLayout()`方法实现子View的`layout`。

```java
//ViewGroup.java
    @Override
    public final void layout(int l, int t, int r, int b) {
        if (!mSuppressLayout && (mTransition == null || !mTransition.isChangingLayout())) {
            if (mTransition != null) {
                mTransition.layoutChange(this);
            }
          //调用View.layout()
            super.layout(l, t, r, b);
        } else {
            // record the fact that we noop'd it; request layout when transition finishes
            mLayoutCalledWhileSuppressed = true;
        }
    }

    @Override
    protected abstract void onLayout(boolean changed,
            int l, int t, int r, int b);

//源码与上述相同 由于ViewGroup中所有子View的layout都需要实现，所以需要实现 onLayout() 方法
protected void onLayout(boolean changed,int left,int top,int right,int bottom){
    //遍历子View
    for (int i =0 ; i <getChildCount();i++){
        View child = getChildAt(i);
        
        //在这里可以添加 顶点变化逻辑
        int childTop = Top;
        int childLeft = Left;
        int childBottom = Bottom;
        int childRight = Right;
         
        ...
        setChildFrame(child,childLeft,childTop,childRight,childBottom);
    }
}

private void setChildFrame(child,int l,int t,int r,int b){
    //按照上一节流程走
    child.layout(l,t,r,b);
}
```

![ViewGroup-Layout](/images/ViewGroup-Layout.png)

按照流程图简单总结一下：

- 先调用ViewGroup的`layout()`，先对ViewGroup进行布局过程
- 在ViewGroup的`onLayout()`中实现子View的遍历布局过程
- 对遍历的子View按照ViewGroup的要求进行顶点坐标的计算，计算完成后调用子View的`layout()`



拓展：

1. View的测量宽/高(`getMeasureWidth()/getMeasureHeight()`)与最终得到的宽/高(`getWidth()/getHeight()`)有什么区别？

   ![layout-getMeasureWidth() 与 getWidth()区别](/images/layout-getMeasureWidth() 与 getWidth()区别.png)
   
   ```java
   //	获得View在测量过程中的宽
   public final int getMeasuredWidth() {
           return mMeasuredWidth & MEASURED_SIZE_MASK;
       }
   //	获得View在测量过程中的高
   public final int getMeasuredHeight() {
           return mMeasuredHeight & MEASURED_SIZE_MASK;
       }
   //	上节 measure 源码分析中就是调用了该方法 进行View的测量
   private void setMeasuredDimensionRaw(int measuredWidth, int measuredHeight) {
           mMeasuredWidth = measuredWidth;
           mMeasuredHeight = measuredHeight;
           mPrivateFlags |= PFLAG_MEASURED_DIMENSION_SET;
       }
   //获得View最终宽
   public final int getWidth() {
           return mRight - mLeft;
       }
   //获得View最终高
   public final int getHeight() {
           return mBottom - mTop;
    }
   ```
   
   

> 两者的比较

| 类型                                                      | 何时赋值            | 赋值方法                                  | 使用场景                        |
| :-------------------------------------------------------- | ------------------- | ----------------------------------------- | ------------------------------- |
| View测量结束宽/高<br>getMeasureWidth()/getMeasureHeight() | View的`measure`过程 | `setMeasureDimension()`                   | 在`onLayout()`获取View的宽/高   |
| View最终宽/高<br>getWidth()/getHeight()                   | View的`layout`过程  | `layout()`对top,left,right,bottom进行操作 | `onLayout()`结束后获取最终宽/高 |

   **一般情况下，二者返回的数据是相同的，除非人为对View的`layout()`进行重写。**

   ```java
   public void layout(int l,int t,int r,int b){
       super.layout(j,t,r+100,b+100);
   }
   ```

   上述代码就会导致View最终结果与测量时不同。

### draw-绘制

> draw作用主要将View绘制在屏幕上面
>
> **draw过程，先draw自身再draw子View**
>
> 起点是`performDraw()`

```java
//ViewRootImpl.java
    private void performDraw() {
      ...
        boolean canUseAsync = draw(fullRedrawNeeded);
    }

    private boolean draw(boolean fullRedrawNeeded) {
        if (!dirty.isEmpty() || mIsAnimating || accessibilityFocusDirty) {
            if (mAttachInfo.mThreadedRenderer != null && mAttachInfo.mThreadedRenderer.isEnabled()) {
              //硬件绘制
              ...
                mAttachInfo.mThreadedRenderer.draw(mView, mAttachInfo, this, callback);              
            } else {
              //软件绘制
              ...
              if (!drawSoftware(surface, mAttachInfo, xOffset, yOffset,
                        scalingRequired, dirty, surfaceInsets)) {
                    return false;
                }
            }
          ...
    }
```



#### View的draw过程

![draw-View的draw过程](/images/draw-View的draw过程.png)

View的draw过程，从`View.draw()`开始

```java
// ../android/view/View.java
public void draw(Canvas canvas) {
    //标记当前View是否背景透明
    final boolean dirtyOpaque = (privateFlags & PFLAG_DIRTY_MASK) == PFLAG_DIRTY_OPAQUE &&
                (mAttachInfo == null || !mAttachInfo.mIgnoreDirtyState);
    
    int saveCount;
        //1. 绘制背景
    if (!dirtyOpaque) {
            drawBackground(canvas);
        }
    final int viewFlags = mViewFlags;
    //是否有水平边缘
    boolean horizontalEdges = (viewFlags & FADING_EDGE_HORIZONTAL) != 0;
    //是否有竖直边缘
    boolean verticalEdges = (viewFlags & FADING_EDGE_VERTICAL) != 0;
    if(!horizontalEdges && !verticalEdges){
       // 3.绘制View本身
          if (!dirtyOpaque) onDraw(canvas);

       // 4.绘制子View
          dispatchDraw(canvas);
        
       // 6.绘制装饰 例如滚动条
          onDrawForeground(canvas);
        
    ...
       return; 
    }
    
    //如果有竖直边缘或者水平边缘 例如divide
    
    // 2. 保存当前Canvas层
        saveCount = canvas.getSaveCount();
        int solidColor = getSolidColor();
        if (solidColor == 0) {
            final int flags = Canvas.HAS_ALPHA_LAYER_SAVE_FLAG;
            if (drawTop) {
                canvas.saveLayer(left, top, right, top + length, null, flags);
            }
            if (drawBottom) {
                canvas.saveLayer(left, bottom - length, right, bottom, null, flags);
            }
            if (drawLeft) {
                canvas.saveLayer(left, top, left + length, bottom, null, flags);
            }
            if (drawRight) {
                canvas.saveLayer(right - length, top, right, bottom, null, flags);
            }
        } else {
            scrollabilityCache.setFadeColor(solidColor);
        }
    ...
        // 3.绘制View本身
          if (!dirtyOpaque) onDraw(canvas);

       // 4.绘制子View
          dispatchDraw(canvas);
    
    ...
        // 5.绘制边缘效果 例如阴影
        canvas.restoreToCount(saveCount);
    ...
        
       // 6.绘制装饰 例如滚动条
          onDrawForeground(canvas);
    ...
    
}

//绘制View本身的背景
private void drawBackground(Canvas canvas) {
        final Drawable background = mBackground;
        if (background == null) {
            return;
        }
        //设置View的背景边界
        setBackgroundBounds();
        ...
          
        final int scrollX = mScrollX;
        final int scrollY = mScrollY;
        if ((scrollX | scrollY) == 0) {
            background.draw(canvas);
        } else {
            //将画布偏移 然后在偏移后的画布上进行背景绘制
            canvas.translate(scrollX, scrollY);
            background.draw(canvas);
            canvas.translate(-scrollX, -scrollY);
        }
    }

//绘制View本身的内容
protected void onDraw(Canvas canvas) {
    // 默认空实现 需要子类复写该方法以实现内容的绘制 ，自定义View中必须执行该方法
    }

//绘制子View的内容
protected void dispatchDraw(Canvas canvas) {
    //由于View不存在子View，所以不需要实现
    }

//绘制装饰 例如滚动条 前景图片
public void onDrawForeground(Canvas canvas) {
        onDrawScrollIndicators(canvas);
        onDrawScrollBars(canvas);

        final Drawable foreground = mForegroundInfo != null ? mForegroundInfo.mDrawable : null;
        if (foreground != null) {
            if (mForegroundInfo.mBoundsChanged) {
                mForegroundInfo.mBoundsChanged = false;
                final Rect selfBounds = mForegroundInfo.mSelfBounds;
                final Rect overlayBounds = mForegroundInfo.mOverlayBounds;

                if (mForegroundInfo.mInsidePadding) {
                    selfBounds.set(0, 0, getWidth(), getHeight());
                } else {
                    selfBounds.set(getPaddingLeft(), getPaddingTop(),
                            getWidth() - getPaddingRight(), getHeight() - getPaddingBottom());
                }

                final int ld = getLayoutDirection();
                Gravity.apply(mForegroundInfo.mGravity, foreground.getIntrinsicWidth(),
                        foreground.getIntrinsicHeight(), selfBounds, overlayBounds, ld);
                foreground.setBounds(overlayBounds);
            }

            foreground.draw(canvas);
        }
    }
```

![View-Draw](/images/View-Draw.png)

结合上述流程图分析Draw过程：

- 先调用`View.draw()`方法开始Draw流程
- 如果需要`dirtyOpaque`，就绘制背景`drawBackground()`
- 如果需要显示边缘效果，就进行保存画布`canvas.saveLayer()`
- 如果需要`dirtyOpaque`，绘制自身的内容`onDraw()` -- **自定义View必须实现**
- 调用`dispatchDraw()`绘制子View
- 如果需要显示边缘效果，绘制后，还原画布`canvas.restore()`
- 调用`drawForeground()`绘制装饰，例如滚动条或前景

#### ViewGroup的draw过程

![draw-ViewGroup的draw过程](/images/draw-ViewGroup的draw过程.png)

ViewGroup的draw过程主要调整了上述源码中的`dispatchDraw()`，在其内部进行了子View的遍历以及绘制过程

```java
 // ../android/view/ViewGroup.java
protected void dispatchDraw(Canvas canvas) {
        boolean usingRenderNodeProperties = canvas.isRecordingFor(mRenderNode);
        final int childrenCount = mChildrenCount;
        final View[] children = mChildren;
    ...
        for (int i = 0; i < childrenCount; i++) {
            while (transientIndex >= 0 && mTransientIndices.get(transientIndex) == i) {
                final View transientChild = mTransientViews.get(transientIndex);
                if ((transientChild.mViewFlags & VISIBILITY_MASK) == VISIBLE ||
                        transientChild.getAnimation() != null) {
                    more |= drawChild(canvas, transientChild, drawingTime);
                }
                transientIndex++;
                if (transientIndex >= transientCount) {
                    transientIndex = -1;
                }
            }

            final int childIndex = getAndVerifyPreorderedIndex(childrenCount, i, customOrder);
            final View child = getAndVerifyPreorderedView(preorderedList, children, childIndex);
            if ((child.mViewFlags & VISIBILITY_MASK) == VISIBLE || child.getAnimation() != null) {
                more |= drawChild(canvas, child, drawingTime);
            }
        }
    ...
}

//绘制子View
protected boolean drawChild(Canvas canvas, View child, long drawingTime) {
      //调用子View的draw方法
      return child.draw(canvas, this, drawingTime);
}


```

![ViewGroup-Draw](/images/ViewGroup-Draw.png)

结合上述流程图分析ViewGroup的Draw过程：

- draw过程与上述`View的draw过程一致`
- `dispatchDraw()`默认实现，内部包含了子View的遍历以及绘制

拓展：

1. `View.setWillNotDraw()`有什么意义?

   ```java
       public void setWillNotDraw(boolean willNotDraw) {
           //设置 不需绘制 标记位
           setFlags(willNotDraw ? WILL_NOT_DRAW : 0, DRAW_MASK);
       }
   ```

   如果一个View不需要绘制任何内容，设置这个标记为`true`，系统就会进行相应优化。

   ***View默认不开启`willNotDraw`标记位，ViewGroup默认开启。***
   
2. `ViewGroup`修改子View绘制顺序

   ![draw-ViewGroup自定义绘制顺序](/images/draw-ViewGroup自定义绘制顺序.png)
   
   ```java ViewGroup.java
   protected void dispatchDraw(Canvas canvas){
     ...
       //设置自定义绘制顺序
      final ArrayList<View> preorderedList = usingRenderNodeProperties
                   ? null : buildOrderedChildList();
           //是否允许自定义绘制顺序
           final boolean customOrder = preorderedList == null
                   && isChildrenDrawingOrderEnabled();
           for (int i = 0; i < childrenCount; i++) {
               while (transientIndex >= 0 && mTransientIndices.get(transientIndex) == i) {
                   final View transientChild = mTransientViews.get(transientIndex);
                   if ((transientChild.mViewFlags & VISIBILITY_MASK) == VISIBLE ||
                           transientChild.getAnimation() != null) {
                       more |= drawChild(canvas, transientChild, drawingTime);
                   }
                   transientIndex++;
                   if (transientIndex >= transientCount) {
                       transientIndex = -1;
                   }
               }
   
               final int childIndex = getAndVerifyPreorderedIndex(childrenCount, i, customOrder);
               final View child = getAndVerifyPreorderedView(preorderedList, children, childIndex);
               if ((child.mViewFlags & VISIBILITY_MASK) == VISIBLE || child.getAnimation() != null) {
                   more |= drawChild(canvas, child, drawingTime);
               }
           }
    ...
   }
   
       protected boolean isChildrenDrawingOrderEnabled() {
           return (mGroupFlags & FLAG_USE_CHILD_DRAWING_ORDER) == FLAG_USE_CHILD_DRAWING_ORDER;
       }
   //设置是否允许自定义绘制顺序
       protected void setChildrenDrawingOrderEnabled(boolean enabled) {
           setBooleanFlag(FLAG_USE_CHILD_DRAWING_ORDER, enabled);
       }
   
    //初始子View的绘制顺序 按照z轴的值调整绘制顺序，z轴从大到小绘制
       ArrayList<View> buildOrderedChildList() {
           final int childrenCount = mChildrenCount;
           if (childrenCount <= 1 || !hasChildWithZ()) return null;
   
           if (mPreSortedChildren == null) {
               mPreSortedChildren = new ArrayList<>(childrenCount);
           } else {
               // callers should clear, so clear shouldn't be necessary, but for safety...
               mPreSortedChildren.clear();
               mPreSortedChildren.ensureCapacity(childrenCount);
           }
   
           final boolean customOrder = isChildrenDrawingOrderEnabled();
           for (int i = 0; i < childrenCount; i++) {
               // add next child (in child order) to end of list
               final int childIndex = getAndVerifyPreorderedIndex(childrenCount, i, customOrder);
               final View nextChild = mChildren[childIndex];
               final float currentZ = nextChild.getZ();
   
               // insert ahead of any Views with greater Z
               int insertIndex = i;
               while (insertIndex > 0 && mPreSortedChildren.get(insertIndex - 1).getZ() > currentZ) {
                   insertIndex--;
               }
               mPreSortedChildren.add(insertIndex, nextChild);
           }
           return mPreSortedChildren;
       }
   
       //确定当前子View的绘制顺序
       private int getAndVerifyPreorderedIndex(int childrenCount, int i, boolean customOrder) {
           final int childIndex;
           if (customOrder) {
               final int childIndex1 = getChildDrawingOrder(childrenCount, i);
               if (childIndex1 >= childrenCount) {
                   throw new IndexOutOfBoundsException("getChildDrawingOrder() "
                           + "returned invalid index " + childIndex1
                           + " (child count is " + childrenCount + ")");
               }
               childIndex = childIndex1;
           } else {
               childIndex = i;
           }
           return childIndex;
       }
   //需要重写该方法，调整绘制顺序
       protected int getChildDrawingOrder(int childCount, int i) {
           return i;
       }
   
   //调整当前子View顺序
       private static View getAndVerifyPreorderedView(ArrayList<View> preorderedList, View[] children,
               int childIndex) {
           final View child;
           if (preorderedList != null) {
               child = preorderedList.get(childIndex);
               if (child == null) {
                   throw new RuntimeException("Invalid preorderedList contained null child at index "
                           + childIndex);
               }
           } else {
               child = children[childIndex];
           }
           return child;
       }
   ```
   
   根据上述源码，默认的绘制**按照z轴从大到小的顺序**进行绘制，如果需要修改绘制顺序的话，需要执行以下两步：
   
   1. `setChildrenDrawingEnabled(true)`打开自定义设置开关
   2. 继承`ViewGroup`后，重写`getChildDrawingOrder()`方法，设置对应的绘制顺序
   
   常用的`RecyclerView`、`ViewPager`都实现了该方法，其中`RecyclerView`通过设置`ChildDrawingOrderCallback`也可以实现这个功能。

如果在`addView()`的场景下，可通过`setElevation()`或`setTranslationZ()`或`setZ()`去修改Z轴的坐标值。



## 自定义View

![自定义View](/images/自定义View.png)

> 自定义View需要了解View的层次、View的事件分发机制以及View的工作流程。

### 分类

#### 1.继承View重写`onDraw()`

> 主要用于实现一些不规则的效果，不方便通过布局的组合方法可以直接实现，往往需要静态或者动态的显示一些不规则图形(圆形啥的)。
>
> 特殊形状的这种就需要重写`onDraw()`实现。**一般需要额外支持wrtap_content，并且也需要处理padding方法。**

#### 2.继承ViewGroup派生特殊的Layout

> 主要用于实现自定义的布局，除了常用的一些布局外。实现的是几种View的组合形式
>
> **实现稍微复杂，需要合适的处理ViewGroup的`onMeasure()，onLayout()`以及子View的`onMeasure()，onLayout()`**

#### 3.继承特定的View(例如TextView)

> 这种比较常见，一般用于拓展已有View的功能。
>
> **实现比较简单，无需自己处理wrap_content以及padding**

#### 4.继承特定的ViewGroup(例如LinearLayout)

> 比较常见，当某种效果看起来很像几种View组合在一起的时候
>
> **实现比较简单，无需自己处理测量以及布局过程**

### 注意事项

![自定义View-注意事项](/images/自定义View-注意事项.png)

#### 1.让View支持wrap_content

> 直接继承View或ViewGroup的控件，不重写`onMeasure()`并对`AT_MOST`进行处理，就无法达到需要的显示效果。

#### 2.需要的话，让View支持padding

> 直接继承View的控件，需要在`draw`过程处理padding属性，不然padding属性无法起作用。
>
> 直接继承ViewGroup的控件，需要在`onMeasure()，onLayout()`处理自身的padding以及子View的margin`measureChildWithMargin()`

#### 3.尽量不要在View中使用Handler

> View内部提供了`post`方法，可以替代Handler使用

#### 4.View中如果有线程或动画，需要及时停止

> 1. 不处理有可能造成内存泄漏，View不可见时也需要停止线程和动画
> 2. 包含View的Activity启动时，View的`onAccachedToWindow()`会调用
> 3. 包含View的Activity退出或当前View被移除时，调用`View.onDetachedFromWindow()`时关闭线程和动画

#### 5.View若有滑动冲突情况，需要处理

> 滑动冲突处理方法：
>
> - `外部拦截法`：点击事件都先经过**父容器的拦截处理**，如果父容器需要此事件就拦截，不需要就放行
>
>   重写父容器的`onInterceptTouchEvent()`，在方法内部拦截
>
> - `内部拦截法`：父容器不拦截任何事件，所有事件交由子容器进行处理，如果子容器需要就消耗事件，不需要就返给父容器处理。
>
>   重写父容器的`onInterceptTouchEvent()`，以及子容器的`dispatchTouchEvent()`。关键在于调用`requestDisallowInterceptTouchEvent()`控制父布局是否进行拦截。
>
> 一般推荐使用`外部拦截法`，符合事件分发流程。

### 实例

{% post_link 自定义View实践%}

{% post_link 自定义ViewGroup实践%}

## 拓展

### 如何触发View的重新绘制？

通过调用`invalidate()/postInvalidate()`或`requestLayout()`实现。

![View工作原理-触发View的重新绘制](/images/View工作原理-触发View的重新绘制.png)

#### requestLayout

![View工作原理-requestLayout](/images/View工作原理-requestLayout.png)

> 在需要刷新`View`的布局时会调用该函数。不应该在布局的过程中调用这个函数。
>
> 这个请求可能会在以下场景执行：当前布局结束、当前帧绘制完成，下次布局发生时

```java
//View.java
    public void requestLayout() {
        if (mMeasureCache != null) mMeasureCache.clear();

        if (mAttachInfo != null && mAttachInfo.mViewRequestingLayout == null) {
            // Only trigger request-during-layout logic if this is the view requesting it,
            // not the views in its parent hierarchy
            ViewRootImpl viewRoot = getViewRootImpl();
            if (viewRoot != null && viewRoot.isInLayout()) {
                if (!viewRoot.requestLayoutDuringLayout(this)) {
                  //如果当前在layout过程中，且调用了 requestLayout，就需要直接返回
                  //等待下一次信号到来时执行
                    return;
                }
            }
            mAttachInfo.mViewRequestingLayout = this;
        }
        //设置强制刷新标记
        mPrivateFlags |= PFLAG_FORCE_LAYOUT;//该标记可执行onMeasure()
        mPrivateFlags |= PFLAG_INVALIDATED;//

        if (mParent != null && !mParent.isLayoutRequested()) {
            //向父布局继续请求刷新布局
            mParent.requestLayout();
        }
        if (mAttachInfo != null && mAttachInfo.mViewRequestingLayout == this) {
            mAttachInfo.mViewRequestingLayout = null;
        }
    }


```

`mParent`对应父节点，一层层向上递归调用父节点`requestLayout()。`直到调用`ViewRootImpl.requestLayout()`结束.

```java
//ViewRootImpl.java
    @Override
    public void requestLayout() {
        if (!mHandlingLayoutInLayoutRequest) {
          //检查当前是否主线程
            checkThread();
          //需要执行measure、layout
            mLayoutRequested = true;
            scheduleTraversals();
        }
    }
```

调用到`scheduleTraversals()`就是开始了`View的绘制流程`。

```java
//ViewRootImpl.java 
private void performTraversals() {
  //是否执行measure、layout过程
   boolean layoutRequested = mLayoutRequested && (!mStopped || mReportNextDraw);
  ...
    if (!mStopped || mReportNextDraw) {
         if (focusChangedDueToTouchMode || mWidth != host.getMeasuredWidth()
                  || mHeight != host.getMeasuredHeight() || contentInsetsChanged ||
                   updatedConfiguration) { 
                  //执行测量流程
                    performMeasure(childWidthMeasureSpec, childHeightMeasureSpec);
         }
    }
  ...
    final boolean didLayout = layoutRequested && (!mStopped || mReportNextDraw);
     if (didLayout) {
       //执行布局流程
            performLayout(lp, mWidth, mHeight);
     }
  ...
        boolean cancelDraw = mAttachInfo.mTreeObserver.dispatchOnPreDraw() || !isViewVisible;

        if (!cancelDraw && !newSurface) {
            if (mPendingTransitions != null && mPendingTransitions.size() > 0) {
                for (int i = 0; i < mPendingTransitions.size(); ++i) {
                    mPendingTransitions.get(i).startChangingAnimations();
                }
                mPendingTransitions.clear();
            }
          //执行绘制流程
            performDraw();
        }    
 }
```



一开始调用的`performMeasure()`

```java
//ViewRootImpl.java
    private void performMeasure(int childWidthMeasureSpec, int childHeightMeasureSpec) {
       ...
        try {
            mView.measure(childWidthMeasureSpec, childHeightMeasureSpec);
        } finally {
            Trace.traceEnd(Trace.TRACE_TAG_VIEW);
        }
    }


//View.java
    public final void measure(int widthMeasureSpec, int heightMeasureSpec) {
      ...
        //需要执行onMeasure
        final boolean forceLayout = (mPrivateFlags & PFLAG_FORCE_LAYOUT) == PFLAG_FORCE_LAYOUT;
      ...
        if (forceLayout || needsLayout) {
          ...
            onMeasure(widthMeasureSpec, heightMeasureSpec);
          ...
            //添加 PFLAG_LAYOUT_REQUIRED标记，表示需要执行 layout流程
             mPrivateFlags |= PFLAG_LAYOUT_REQUIRED;
        }
    }
```

继续向下调用`performLayout()`

```java
//ViewRootImpl.java
    private void performLayout(WindowManager.LayoutParams lp, int desiredWindowWidth,
            int desiredWindowHeight) {
       //正在执行layout流程
       mInLayout = true;

       final View host = mView;//对应DecorView
       //在layout过程中 尚未执行requestLayout的view
       int numViewsRequestingLayout = mLayoutRequesters.size();
       if (numViewsRequestingLayout > 0) {
          //寻找mPrivateFlags为PFLAG_FORCE_LAYOUT的View
           ArrayList<View> validLayoutRequesters = getValidLayoutRequesters(mLayoutRequesters,
                        false);
                if (validLayoutRequesters != null) {
                  //当前View重新measure
                     measureHierarchy(host, lp, mView.getContext().getResources(),
                            desiredWindowWidth, desiredWindowHeight);     
                  //重新执行layout
                     host.layout(0, 0, host.getMeasuredWidth(), host.getMeasuredHeight());  
                  ...
                    //寻找尚未设置 PFLAG_FORCE_LAYOUT的View
                     validLayoutRequesters = getValidLayoutRequesters(mLayoutRequesters, true);                   
                     if (validLayoutRequesters != null) {
                        final ArrayList<View> finalRequesters = validLayoutRequesters;
                        // 执行requestLayout在下一帧执行时
                        getRunQueue().post(new Runnable() {
                            @Override
                            public void run() {
                                int numValidRequests = finalRequesters.size();
                                for (int i = 0; i < numValidRequests; ++i) {
                                    final View view = finalRequesters.get(i);
                                    Log.w("View", "requestLayout() improperly called by " + view +
                                            " during second layout pass: posting in next frame");
                                    view.requestLayout();
                                }
                            }
                        });
                    }                 
                }
       }
      
    }
```

主要执行了三步：

- 执行`DecorView`的`layout`过程
- 执行调用过`requestLayout()`的View(包含`PFLAG_FORCE_LAYOUT`标志)的`measure`和`layout`
- 还没调用过`requestLayout()`的View加入到队列中，等待下一帧绘制时执行

```java
//View.java
    public void layout(int l, int t, int r, int b) {
      //判断当前位置是否发生变化
        boolean changed = isLayoutModeOptical(mParent) ?
                setOpticalFrame(l, t, r, b) : setFrame(l, t, r, b);      
      //位置发生变化。或 需要layout
        if (changed || (mPrivateFlags & PFLAG_LAYOUT_REQUIRED) == PFLAG_LAYOUT_REQUIRED) {
          //回调onLayout()
            onLayout(changed, l, t, r, b);
          ...
         //移除 PFLAG_LAYOUT_REQUIRED标志 在measure过程添加   
          mPrivateFlags &= ~PFLAG_LAYOUT_REQUIRED;
          ...
        }
      ...
        //layout过程完成后 移除 PFLAG_FORCE_LAYOUT标志
        mPrivateFlags &= ~PFLAG_FORCE_LAYOUT;        
      
    }

    protected boolean setFrame(int left, int top, int right, int bottom) {
      //位置发生变化时，就需要执行 invalidate()重绘View
      if (mLeft != left || mRight != right || mTop != top || mBottom != bottom) {
         boolean sizeChanged = (newWidth != oldWidth) || (newHeight != oldHeight);
          //需要重绘视图
            invalidate(sizeChanged);
      }
    }
```



>`requestLayout()`主要执行了以下几步：
>
>- 添加`PFLAG_FORCE_LAYOUT`和`PFLAG_INVALIDATED`标记
>- `measure`执行需要判断`PFLAG_FORCE_LAYOUT`标记是否存在
>- `measure`执行后，添加`PFLAG_LAYOUT_REQUIRED`标记，可以去执行`onLayout()`
>- `layout`执行后，移除`PFLAG_LAYOUT_REQUIRED`和`PFLAG_FORCE_LAYOUT`标记
>- 在`layout`过程中，如果位置发生了变化，会执行到`invalidate()`，可能会执行`draw`过程；如果未发生变化，就不会执行`draw`过程

#### invalidate/postInvalidate

![View工作原理-Invalidate](/images/View工作原理-Invalidate.png)

> `invalidate()`必须在主线程调用。`postInvalidate()`可以在子线程调用(通过handler发送消息到主线程调用)
>
> 主要用于请求View的重绘，只会影响到View的`draw`过程

```java
//View.java
    public void postInvalidate() {
        postInvalidateDelayed(0);
    }

    public void dispatchInvalidateDelayed(View view, long delayMilliseconds) {
        Message msg = mHandler.obtainMessage(MSG_INVALIDATE, view);
        mHandler.sendMessageDelayed(msg, delayMilliseconds);
    }

    @Override
    public void handleMessage(Message msg) {
            switch (msg.what) {
                case MSG_INVALIDATE:
                    ((View) msg.obj).invalidate();//继续执行到invalidate()
                    break;
                ...
            }
    }

    public void invalidate() {
        invalidate(true);
    }
```

最终执行到`invalidateInternal()`

```java
//View.java
    void invalidateInternal(int l, int t, int r, int b, boolean invalidateCache,
            boolean fullInvalidate) {
        ...
        //当前View不可见
        if (skipInvalidate()) {
            return;
        }

        if ((mPrivateFlags & (PFLAG_DRAWN | PFLAG_HAS_BOUNDS)) == (PFLAG_DRAWN | PFLAG_HAS_BOUNDS)
                || (invalidateCache && (mPrivateFlags & PFLAG_DRAWING_CACHE_VALID) == PFLAG_DRAWING_CACHE_VALID)
                || (mPrivateFlags & PFLAG_INVALIDATED) != PFLAG_INVALIDATED//当前没有执行invalidate
                || (fullInvalidate && isOpaque() != mLastIsOpaque)) {
          //需要全量重绘
            if (fullInvalidate) {
                mLastIsOpaque = isOpaque();
              //添加重绘标记
                mPrivateFlags &= ~PFLAG_DRAWN;
            }
           //添加当前View重绘标记
            mPrivateFlags |= PFLAG_DIRTY;
           //是否刷新缓存
            if (invalidateCache) {
                mPrivateFlags |= PFLAG_INVALIDATED;
                mPrivateFlags &= ~PFLAG_DRAWING_CACHE_VALID;
            }

            // Propagate the damage rectangle to the parent view.
            final AttachInfo ai = mAttachInfo;
            final ViewParent p = mParent;
            if (p != null && ai != null && l < r && t < b) {
                final Rect damage = ai.mTmpInvalRect;
                damage.set(l, t, r, b);
              //设置重绘区域 并把自身传递到父布局
                p.invalidateChild(this, damage);
            }
          ...
        }
    }
```

上述代码修改标记完成后，调用父类的`invalidateChild()`将需要重绘的区域(`脏区域`)传入。(`ViewGroup以及ViewRootImpl都继承自ViewParent类`)

> 脏区域：*为了保证绘制的效率，控件树仅对需要绘制的区域进行重绘，需要重绘的区域成为`脏区域`*。

```java
//ViewGroup.java
    public final void invalidateChild(View child, final Rect dirty) {
      //开启硬件加速
        if (attachInfo != null && attachInfo.mHardwareAccelerated) {
            // 更新DisplayList
            onDescendantInvalidated(child, child);
            return;
        }      
         //当前View是否 不透明
        final boolean isOpaque = child.isOpaque() && !drawAnimation &&
                    child.getAnimation() == null && childMatrix.isIdentity(); 
        //全不透明 标记为 PFLAG_DIRTY_OPAQUE
        //部分透明 标记为 PFLAG_DIRTY
        int opaqueFlag = isOpaque ? PFLAG_DIRTY_OPAQUE : PFLAG_DIRTY;
      ...
        do {
                View view = null;
                if (parent instanceof View) {
                    view = (View) parent;
                }

                if (drawAnimation) {
                    if (view != null) {
                        view.mPrivateFlags |= PFLAG_DRAW_ANIMATION;
                    } else if (parent instanceof ViewRootImpl) {
                        ((ViewRootImpl) parent).mIsAnimating = true;
                    }
                }

                // If the parent is dirty opaque or not dirty, mark it dirty with the opaque
                // flag coming from the child that initiated the invalidate
                if (view != null) {
                    if ((view.mViewFlags & FADING_EDGE_MASK) != 0 &&
                            view.getSolidColor() == 0) {
                        opaqueFlag = PFLAG_DIRTY;
                    }
                    if ((view.mPrivateFlags & PFLAG_DIRTY_MASK) != PFLAG_DIRTY) {
                        view.mPrivateFlags = (view.mPrivateFlags & ~PFLAG_DIRTY_MASK) | opaqueFlag;
                    }
                }
                //递归调用父布局的重绘方法
                parent = parent.invalidateChildInParent(location, dirty);
                //计算需要重绘区域
                dirty.set((int) Math.floor(boundingRect.left),
                                (int) Math.floor(boundingRect.top),
                                (int) Math.ceil(boundingRect.right),
                                (int) Math.ceil(boundingRect.bottom));                
          ...
            } while (parent != null);
      
    }

//ViewGroup.java
    public ViewParent invalidateChildInParent(final int[] location, final Rect dirty) {
        if ((mPrivateFlags & (PFLAG_DRAWN | PFLAG_DRAWING_CACHE_VALID)) != 0) {
          //将子View转换为当前View显示的位置
          ...
        }
    }
```

当`parent==null`时，表示已经到了最顶层`ViewRootImpl`

```java
//ViewRootImpl.java
    public ViewParent invalidateChildInParent(int[] location, Rect dirty) {
      //检查当前是否主线程
        checkThread();
        if (DEBUG_DRAW) Log.v(mTag, "Invalidate child: " + dirty);

        if (dirty == null) {
            invalidate();
            return null;
        } else if (dirty.isEmpty() && !mIsAnimating) {
            return null;
        }
       ...
      //更新屏幕对应脏区域
        invalidateRectOnScreen(dirty);

        return null;
    }

    private void invalidateRectOnScreen(Rect dirty) {
        final Rect localDirty = mDirty;
        if (!localDirty.isEmpty() && !localDirty.contains(dirty)) {
            mAttachInfo.mSetIgnoreDirtyState = true;
            mAttachInfo.mIgnoreDirtyState = true;
        }

        // Add the new dirty rect to the current one
        localDirty.union(dirty.left, dirty.top, dirty.right, dirty.bottom);
        // Intersect with the bounds of the window to skip
        // updates that lie outside of the visible region
        final float appScale = mAttachInfo.mApplicationScale;
        final boolean intersected = localDirty.intersect(0, 0,
                (int) (mWidth * appScale + 0.5f), (int) (mHeight * appScale + 0.5f));
        if (!intersected) {
            localDirty.setEmpty();
        }
        if (!mWillDrawSoon && (intersected || mIsAnimating)) {
          //执行绘制流程
            scheduleTraversals();
        }
    }
```

通过`scheduleTraversals()`执行绘制流程，由于未设置`mLayoutRequested = true`，所以无法进入`performMeasure()`和`performLayout()`只能执行到`performDraw()`。



```java
//ViewRootImpl.java
    private void performDraw() {
      ...
        boolean canUseAsync = draw(fullRedrawNeeded);
    }

    private boolean draw(boolean fullRedrawNeeded) {
        if (!dirty.isEmpty() || mIsAnimating || accessibilityFocusDirty) {
            if (mAttachInfo.mThreadedRenderer != null && mAttachInfo.mThreadedRenderer.isEnabled()) {
              //硬件绘制
              ...
                mAttachInfo.mThreadedRenderer.draw(mView, mAttachInfo, this, callback);              
            } else {
              //软件绘制
              ...
              if (!drawSoftware(surface, mAttachInfo, xOffset, yOffset,
                        scalingRequired, dirty, surfaceInsets)) {
                    return false;
                }
            }
          ...
    }
```

向下调用到`View.draw()`

```java
//View.java
    public void draw(Canvas canvas) {
        final boolean dirtyOpaque = (privateFlags & PFLAG_DIRTY_MASK) == PFLAG_DIRTY_OPAQUE &&
                (mAttachInfo == null || !mAttachInfo.mIgnoreDirtyState);
        if (!dirtyOpaque) {
            drawBackground(canvas);//绘制背景
        }
        if (!dirtyOpaque) onDraw(canvas);//绘制自身
        dispatchDraw(canvas); //绘制子View 
        onDrawForeground(canvas);//绘制前景
    }
```

关键在于是否持有`PFLAG_DIRTY_OPAQUE`标志，这个标志主要是在`invalidate()`打上的。

> `invalidate()`通过设置`PFLAG_INVALIDATED`和`PFLAG_DRAWING_CACHE_VALID`标记，然后执行`invalidateChild()`通过层层向上调用`parent.invalidateChildInParent()`把需要重新绘制的区域传递上去，直到达到`ViewRootImpl`为止。最后调用到`invalidateRectOnScreen()`传入最终需要重新绘制的区域，开始执行绘制流程。
>
> **invalidate()会打上`PFLAG_DIRTY_OPAQUE`标记，只有这个标记才会执行`onDraw()`。**

#### 两者区别

`rquestLayout()`和`invalidate()`都可以触发整个绘制流程，但是触发`measure`、`layout`、`draw`各条件都不同

- `measure`过程触发：`mPrivateFlags`包含`PFLAG_FORCE_LAYOUT`
- `layout`过程触发：`mPrivateFlags`包含`PFLAG_LAYOUT_REQUIRED(measure执行后添加)`或者`位置发生变化`
- `draw`过程触发：`mPrivateFlags`包含`PFLAG_DIRTY_OPAQUE`

`requestLayout()`主要用来设置`PFLAG_FORCE_LAYOUT`标志以及设置`mLayoutRequested=true`，会执行到`measure、layout`过程，如果位置发生变化则可能执行`draw`过程。

`invalidate()`主要用来设置`PFLAG_DIRTY_OPAQUE`标志，可以在执行`performTraversal()`时，调用到`performDraw()`后到`draw()`时，可以进行绘制过程。

![区别](/images/View重绘.png)



#### 同时调用

> 在某些情况下，需要`requestLayout`和`invalidate`配合使用，得到最终的结果。

拿`TextView`举例：

![TextView.setText()](/images/TextView.setText.png)

当`TextView`执行`setText()`后，TextView可能布局发生改变，也可能需要进行重绘。需要区分不同情况实现对应功能。

```java
//TextView.java
    private void setText(CharSequence text, //文本
                         BufferType type, //缓存类型 NORMAL 默认样式 SPANNABLE 自定义样式 EDITABLE 可以追加字符
                         boolean notifyBefore, //是否通知之前
                         int oldlen //旧文本长度
) {
      ...
        if (mLayout != null) {
            checkForRelayout();
        }
      ...
    }

    private void checkForRelayout() {
      //TextView的宽度以及高度固定不变
        if ((mLayoutParams.width != LayoutParams.WRAP_CONTENT//宽度固定
                || (mMaxWidthMode == mMinWidthMode && mMaxWidth == mMinWidth))
                && (mHint == null || mHintLayout != null)
                && (mRight - mLeft - getCompoundPaddingLeft() - getCompoundPaddingRight() > 0)) {
            // Static width, so try making a new text layout.

            int oldht = mLayout.getHeight();
            int want = mLayout.getWidth();
            int hintWant = mHintLayout == null ? 0 : mHintLayout.getWidth();

            /*
             * No need to bring the text into view, since the size is not
             * changing (unless we do the requestLayout(), in which case it
             * will happen at measure).
             */
            makeNewLayout(want, hintWant, UNKNOWN_BORING, UNKNOWN_BORING,
                          mRight - mLeft - getCompoundPaddingLeft() - getCompoundPaddingRight(),
                          false);

          //非跑马灯格式
            if (mEllipsize != TextUtils.TruncateAt.MARQUEE) {
                // In a fixed-height view, so use our new text layout.
                if (mLayoutParams.height != LayoutParams.WRAP_CONTENT 
                        && mLayoutParams.height != LayoutParams.MATCH_PARENT) {//高度为>0的值
                    autoSizeText();
                    invalidate();
                    return;
                }

                // 除非主动设置高度，否则高度与行数相关，不会为0
                if (mLayout.getHeight() == oldht
                        && (mHintLayout == null || mHintLayout.getHeight() == oldht)) {//高度没有发生变化
                    autoSizeText();
                    invalidate();
                    return;
                }
            }

            // We lose: the height has changed and we have a dynamic height.
            // Request a new view layout using our new text layout.
            requestLayout();
            invalidate();
        } else {
            // Dynamic width, so we have no choice but to request a new
            // view layout with a new text layout.
            nullLayouts();
            requestLayout();
            invalidate();
        }
    }
```

根据上述源码分析：

> `TextView.setText()`根据不同的情况会执行不同的重绘方法：
>
> - `width!=wrap_content`
>   - 非跑马灯格式(`mEllipsize!=MARQUEE`) && (`height > 0` || `height == oldht/*高度没有变化*/`)：执行`invalidate()`
>   - others：执行`requestLayout()`和`invalidate()`
> - `width=wrap_content`：需要执行`requestLayout()`和`invalidate()`

#### 拓展

##### forceLayout()

> 标记当前View需要重新执行`测量-布局-绘制`流程。一般父ViewGroup调用`requestLayout()`，子View不会触发整套流程。
>
> 调用后，子View也可以执行整套流程。

```java
//View.java   
public void forceLayout() {
        if (mMeasureCache != null) mMeasureCache.clear();

        mPrivateFlags |= PFLAG_FORCE_LAYOUT;//标记 执行measure
        mPrivateFlags |= PFLAG_INVALIDATED;
    }
```

`forceLayout`若要生效，需要`直系父View`调用`requestLayout`。

### include、merge、ViewStub作用以及实现

{% post_link include、merge-ViewStub相关%}

### View的层级计算

```java
//实际形成一个二叉树 递归计算深度    
private int maxViewDeep(View view) {
        if (!(view instanceof ViewGroup)) {
            return 0;
        }

        ViewGroup vp = (ViewGroup) view;
        if (vp.getChildCount() == 0) {
            return 0;
        }

        int max = 0;
        int count = vp.getChildCount();
        for (int i = 0; i < count; i++) {
            int deep = maxViewDeep(vp.getChildAt(i)) + 1;
            if (deep > max) {
                max = deep;
            }
        }
        return max;
    }
```



### AsyncLayoutInflater异步加载

{% post_link Android-布局优化-AsyncLayoutInflater简析 AsyncLayoutInflater%}

### inflate()时，`root`与`attachToRoot`的结果源码

```java
//LayoutInflater.java
    public View inflate(XmlPullParser parser, @Nullable ViewGroup root, boolean attachToRoot) {
            View result = root;
      
                    if (root != null) {
                        // Create layout params that match root, if supplied
                        params = root.generateLayoutParams(attrs);
                        if (!attachToRoot) {
                            // Set the layout params for temp if we are not
                            // attaching. (If we are, we use addView, below)
                            temp.setLayoutParams(params);
                        }
                    }      
                    // We are supposed to attach all the views we found (int temp)
                    // to root. Do that now.
                    if (root != null && attachToRoot) {
                        //将temp添加到rootView中
                        root.addView(temp, params);
                    }

                    // Decide whether to return the root that was passed in or the
                    // top view found in xml.
                    if (root == null || !attachToRoot) {
                        //attachToRoot：将View添加到RootView中，非就是直接返回解析的子View
                        result = temp;
                    }      
      return result;
    }

```



根据源码分析到，`root`与`attachToRoot`会对`infalte()`结果产生影响以及实现代码会有差异

| `root`与`attachToRoot`参数                    | 表现                                                         | `inflate()`返回结果        |
| --------------------------------------------- | ------------------------------------------------------------ | -------------------------- |
| `root == nuill && attachToRoot == false/true` | 直接显示`source`加载的结果，而且设置的`宽高属性`也会失效     | `source`加载后的`View实例` |
| `root != null && attachToRoot == false`       | 直接显示`source`加载的结果，且设置的`宽高属性`保持           | `source`加载后的`View实例` |
| `root != null && attachToRoot == true`        | 直接显示`root`并且`source`已被`add`进去且设置的`宽高属性`保持 | `root`                     |



**`root`不为null，无论`attachToRoot`，都会保持需要加载布局的宽高属性。`root`为null，无论`attachToRoot`，都不会持有原有的宽高属性。**



### `MeasureSpec.UNSPECIFIED`使用场景

> `UNSPECIFIED`就是未指定的意思，在这个模式下 父控件不会干涉子控件的尺寸。
>
> **一般用于支持滚动的布局中，例如`ScrollView`、`RecyclerView`中。**
>
> 在可滚动的`ViewGroup`中，不应该限制子View的尺寸。有可能子View会超出父布局的尺寸，在`AT_MOST/EXACTLY`都会对子View的尺寸进行限制。

拿`ScrollView`举例

```java
//ScrollView.java
    protected void measureChild(View child, int parentWidthMeasureSpec,
            int parentHeightMeasureSpec) {
        ViewGroup.LayoutParams lp = child.getLayoutParams();

        int childWidthMeasureSpec;
        int childHeightMeasureSpec;

        childWidthMeasureSpec = getChildMeasureSpec(parentWidthMeasureSpec, mPaddingLeft
                + mPaddingRight, lp.width);
        final int verticalPadding = mPaddingTop + mPaddingBottom;
      //强制设置子View的测量模式为`UNSPECIFIED`
        childHeightMeasureSpec = MeasureSpec.makeSafeMeasureSpec(
                Math.max(0, MeasureSpec.getSize(parentHeightMeasureSpec) - verticalPadding),
                MeasureSpec.UNSPECIFIED);

        child.measure(childWidthMeasureSpec, childHeightMeasureSpec);
    }
```

