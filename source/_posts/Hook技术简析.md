---
title: Hook技术简析
date: 2019-02-06 09:04:47
tags: Java
top: 10
---

说到Hook技术需要先提到逆向工程，主要目的是**在不能轻易获得必要生产信息的情况下，直接从成品分析，推导出产品的设计原理**。

逆向分析又分为

- 静态分析：不执行程序的情况下对程序行为进行分析的技术
- 动态分析：在程序运行时对程序进行调试的技术。*Hook属于动态分析。*

## 代理模式

{% post_link 动态代理模式原理及实现 %}

## Hook技术概述

{% fullimage /images/正常的调用与回调.png,正常的调用与回调,正常的调用与回调%}

对象A直接调用B，对象B结果直接回调给A。

{% fullimage /images/Hook后的调用与回调.png,Hook后的调用与回调,Hook后的调用与回调%}

Hook可以是一个方法或者对象，它位于对象A和B之间，当对象A调用对象B时会在之前做一些处理。也可以用于应用进程调用系统进程时做一些处理，更改他们间的关系。

其中被Hook的对象B，称作**Hook点**。

整个Hook的过程分为三步：

1. **寻找Hook点**。原则上是静态变量或者单例对象(**容易找到并且不易变化的对象**)，尽量Hook Public的对象和方法，非Public不保证每个版本保持一致，可能需要适配。
2. **选择合适的代理方式**。如果是接口可以使用动态代理方式，类的话多考虑使用静态模式。
3. **用代理对象替换原始对象。**

## Hook实例简析

### Hook `startActivity()`

Activity的启动方式有两种

- 一个Activity启动另一个Activity

  ```java
  startActivity(new Intent(this,XXActivity.class));
  ```

  

- 通过Service或者其他非Activity类进行启动Activity(*必须设置 FLAG_NEW_TASK*)

  ```java
   Intent intent = new Intent(this, XXActivity.class);
   intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
   context.startActivity(intent);
  ```

  

#### 1.Hook `Activity.startActivity()`

从源码分析上需要从`startActivity()`开始

```java ../android/app/Activity.java
    @Override
    public void startActivity(Intent intent) {
        this.startActivity(intent, null);
    }

    @Override
    public void startActivity(Intent intent, @Nullable Bundle options) {
        if (options != null) {
            startActivityForResult(intent, -1, options);
        } else {
            startActivityForResult(intent, -1);
        }
    }

 public void startActivityForResult(@RequiresPermission Intent intent, int requestCode,
            @Nullable Bundle options) {
        if (mParent == null) {
            options = transferSpringboardActivityOptions(options);
            Instrumentation.ActivityResult ar =
                mInstrumentation.execStartActivity(
                    this, mMainThread.getApplicationThread(), mToken, this,
                    intent, requestCode, options);
          ...
        }
 }
```

最终调用到的是`Instrumentation.execStartActivity()`执行启动下一个Activity的逻辑。

按照Hook过程分析，需要先找到`Hook点`。由于要Hook的就是Activity的启动，所以我们可以设置`Instrumentation`为Hook点，然后使用静态代理模式生成代理对象，最后替换掉原始的`Instrumentation`继续执行启动逻辑。

> 先创建`Instrumentation`代理对象`InstrumentationProxy`

```java
public class InstrumentationProxy extends Instrumentation {
    private static final String TAG = "InstrumentationProxy";
    Instrumentation mInstrumentation;

    public InstrumentationProxy(Instrumentation _instrumentation) {
        mInstrumentation = _instrumentation;
    }
  
    //为了兼容9.0添加该方法
    public Activity newActivity(ClassLoader cl, String className,
                                Intent intent)
            throws InstantiationException, IllegalAccessException,
            ClassNotFoundException {
        return mInstrumentation.newActivity(cl, className, intent);
    }

    public ActivityResult execStartActivity(Context who, IBinder contextThread, IBinder token, Activity target,
                                            Intent intent, int requestCode, Bundle options) {
        Log.e(TAG, "hook success" + who);
        // 开始调用原始的方法, 调不调用随你,但是不调用的话, 所有的startActivity都失效了.
        // 由于这个方法是隐藏的,因此需要使用反射调用;首先找到这个方法
        try {
            @SuppressLint("PrivateApi") Method execStartActivity = Instrumentation.class.getDeclaredMethod(
                    "execStartActivity",
                    Context.class, IBinder.class, IBinder.class, Activity.class,
                    Intent.class, int.class, Bundle.class);
            execStartActivity.setAccessible(true);
            return (ActivityResult) execStartActivity.invoke(mInstrumentation, who,
                    contextThread, token, target, intent, requestCode, options);
        } catch (Exception e) {
            throw new RuntimeException("do not support!!! pls adapt it");
        }
    }
}
```

> 在需要使用的Activity中实现Hook方法

```java
public class LoadActivity extends AppCompatActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.act_load);
        //Hook当前Activity使用的Instrumentation
        replaceActivityInstrumentation(LoadActivity.this);
        Button btn_jump = findViewById(R.id.btn_jump);
        btn_jump.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startActivity(new Intent(LoadActivity.this, MainActivity.class));
            }
        });
    }

    public void replaceActivityInstrumentation(Activity activity) {
        try {
            Field field = Activity.class.getDeclaredField("mInstrumentation");
            field.setAccessible(true);
            Instrumentation instrumentation = (Instrumentation) field.get(activity);
            Instrumentation instrumentationProxy = new InstrumentationProxy(instrumentation);
            field.set(activity, instrumentationProxy);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

> 理论上来说`Hook操作`越早越好，`handleLaunchActivity()`内部开始执行启动流程，然后会调用到`Activity.attach()`内部继续执行。`attachBaseContext()`是最早执行的，但是其中无法去执行Hook操作
>
> ```java
>  final void attach(Context context, ActivityThread aThread,
>             Instrumentation instr, IBinder token, int ident,
>             Application application, Intent intent, ActivityInfo info,
>             CharSequence title, Activity parent, String id,
>             NonConfigurationInstances lastNonConfigurationInstances,
>             Configuration config, String referrer, IVoiceInteractor voiceInteractor,
>             Window window, ActivityConfigCallback activityConfigCallback) {
>         attachBaseContext(context);
>    ...
>       //在这个方法后面又会继续执行赋值，则Hook失效
>       mInstrumentation = instr;
>    ...
>  }
>    
> ```

#### 2.Hook `Context.startActivity()` 

`Context`的具体实现类为`ContextImpl`，`ContextImpl.startActivity()`如下所示

```java ./android/app/ContextImpl.java
    @Override
    public void startActivity(Intent intent) {
        warnIfCallingFromSystemProcess();
        startActivity(intent, null);
    }

    public void startActivity(Intent intent, Bundle options) {
        warnIfCallingFromSystemProcess();
        if ((intent.getFlags()&Intent.FLAG_ACTIVITY_NEW_TASK) == 0
                && options != null && ActivityOptions.fromBundle(options).getLaunchTaskId() == -1) {
            throw new AndroidRuntimeException(
                    "Calling startActivity() from outside of an Activity "
                    + " context requires the FLAG_ACTIVITY_NEW_TASK flag."
                    + " Is this really what you want?");
        }
        mMainThread.getInstrumentation().execStartActivity(
                getOuterContext(), mMainThread.getApplicationThread(), null,
                (Activity) null, intent, -1, options);
    }
```

`getInstrumentation()`去获取对应的`Instrumentation`不过这个是可以全局生效的，`ActivityThread`是主线程的管理类，`Instrumentation`是其成员变量，一个进程中只会存在一个`ActivityThread`，因此依然设置`Instrumentation`为Hook点。

可以在`Application`中或者`Activity`中去设置Hook方法

```java
public class App extends Application {

    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);
        replaceContextInstrumentation();
    }

    @Override
    public void onCreate() {
        super.onCreate();

    }

    public void replaceContextInstrumentation() {
        try {
           //获取ActivityThread类
            @SuppressLint("PrivateApi") Class<?> activityThreadClazz = Class.forName("android.app.ActivityThread");
            //获取其中的静态变量 sCurrentActivityThread 它对应着当前的ActivityThread对象
            Field activityThreadField = activityThreadClazz.getDeclaredField("sCurrentActivityThread");
            activityThreadField.setAccessible(true);
            //获取到 sCurrentActivityThread 对象
            Object currentActivityThread = activityThreadField.get(null);
            Field mInstrumentationField = activityThreadClazz.getDeclaredField("mInstrumentation");
            mInstrumentationField.setAccessible(true);
            Instrumentation mInstrumentation = (Instrumentation) mInstrumentationField.get(currentActivityThread);
            Instrumentation instrumentationProxy = new InstrumentationProxy(mInstrumentation);
            //执行替换操作
            mInstrumentationField.set(currentActivityThread, instrumentationProxy);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```



#### 可能出现的问题

1. 无法进行Hook操作

   ```xml
   E/Instrumentation: Uninitialized ActivityThread, likely app-created Instrumentation, disabling AppComponentFactory
   ```

   出现上述提示，发生的情况是在Android P上运行应用时。

   主要是因为在Android P的源代码中对`Instrumentation.newActivity()`进行了调整

   ```java
   private ActivityThread mThread = null;    
   public Activity newActivity(ClassLoader cl, String className,
             Intent intent)
             throws InstantiationException, IllegalAccessException,
                     ClassNotFoundException {
                 String pkg = intent != null && intent.getComponent() != null
                         ? intent.getComponent().getPackageName() : null;
                 return getFactory(pkg).instantiateActivity(cl, className, intent);
             }
          
             private AppComponentFactory getFactory(String pkg) {
                 if (pkg == null) {
                     Log.e(TAG, "No pkg specified, disabling AppComponentFactory");
                     return AppComponentFactory.DEFAULT;
                 }
                 
                 if (mThread == null) {
                     Log.e(TAG, "Uninitialized ActivityThread, likely app-created Instrumentation,"
                             + " disabling AppComponentFactory", new Throwable());
                     return AppComponentFactory.DEFAULT;
                 }
                 LoadedApk apk = mThread.peekPackageInfo(pkg, true);
                 // This is in the case of starting up "android".
                 if (apk == null) apk = mThread.getSystemContext().mPackageInfo;
                 return apk.getAppFactory();
             }
   ```

   因为只是hook了`execStartActivity()`而`newActivity()`就会抛出如上异常，解决方案就是在我们自定义的`InstrumentationProxy`中去重写`newActivity()`

   ```java
   public Activity newActivity(ClassLoader cl, String className,
                                   Intent intent)
               throws InstantiationException, IllegalAccessException,
               ClassNotFoundException {
   
           return mBase.newActivity(cl, className, intent);
       }
   ```

   

## 内容引用

[Android 9.0相关源码](http://androidxref.com/9.0.0_r3/xref/frameworks/base/core/java/android/app/Instrumentation.java)

[Android插件化原理解析](http://weishu.me/2016/02/16/understand-plugin-framework-binder-hook/)

