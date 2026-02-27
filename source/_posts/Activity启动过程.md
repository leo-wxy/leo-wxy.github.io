---
title: Activity启动过程
date: 2019-01-02 21:35:26
tags: Android
top: 11
typora-root-url: ../
---

<!--ams是怎么找到启动的那个activity 从framework的角度讲activity的启动流程(冷启动) Application attach之前干了些什么？APP启动进程的时候，会处理些什么？ onResume的时候，已经是第一帧绘制了吗？如果不是，那什么时候是呢？-->

> 下列源码分析是基于 Android 8.0源码

Activity的启动过程分为两种：

- **根Activity的启动过程**  -  指代根Activity的启动过程，也可以认为是应用程序的启动过程
- **普通Activity的启动过程**  -  除启动应用程序启动的第一个Activity之外Activity的启动过程

### 术语与范围约定（补充）

- 根Activity：Manifest 中声明了`MAIN + LAUNCHER`的入口 Activity。
- 普通Activity：应用进程已经存在时，由当前前台组件触发的后续 Activity 启动。
- 冷启动：目标进程不存在，需要从 Zygote fork 新进程并完成 Application 绑定。
- 温启动：目标进程存在，但目标 Activity 需要重新创建。
- 热启动：目标 Activity 已在任务栈中，主要是前后台切换后的恢复展示。

本文主体源码仍以 Android 8.0 为主，文末会补充新版本中类职责迁移与关键差异。

## 根Activity启动过程


### 根Activity启动主链路总览（补充）

根Activity的启动可以抽象为 6 个阶段：

1. `Launcher`通过`startActivity`发起启动请求。
2. 请求经`Instrumentation -> IActivityManager`跨进程进入`AMS`。
3. `AMS/ActivityStarter`完成权限校验、任务栈决策、目标进程决策。
4. 若目标进程不存在，`AMS`通过`Zygote`创建应用进程并进入`ActivityThread.main()`。
5. 新进程回调`attachApplication`，`AMS`通过`ApplicationThread`触发`bindApplication`。
6. `ActivityThread`收到`LAUNCH_ACTIVITY`后执行`performLaunchActivity + handleResumeActivity`，最终完成可见。



![根Activity启动过程-冷启动](/images/根Activity启动过程.png)

> 点击桌面的应用程序图标就是启动根Activity的入口，当我们点击某个应用程序图标时，就会通过Launcher请求AMS来启动该应用程序。
>
> 其中涉及了三个进程间的通信：`Launcher组件`，`AMS`，`Activity组件`。

### Launcher请求AMS过程

当我们在应用程序启动器Launcher上点击一个应用的图标时，Launcher组件就会调用`startActivitySafely()`启动该App的根Activity。

配置根Activity，需要在AndroidManifest.xml中配置 相关属性

```xml
 <activity
            android:name=".MainActivity"
            android:label="@string/app_name"
            android:theme="@style/AppTheme.NoActionBar">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

```

Launcher组件中`startActivitySafely()`相关操作

```java
// packages/apps/Launcher3/src/com/android/Launcher3/Launcher.java
public boolean startActivitySafely(View v,Intent intent,ItemInfo item){
  ...
  
  intent.addFlags(Intent.FFLAG_ACTIVITY_NEW_TASK);
  try{
    if(Utilities.ATLEAST_MARSHMELLOW
      &&(item instanceof ShortcutInfo)
      &&(item.itemType == Favorites.ITEM_TYPE_SHORTCUT
      ||item.itemType == Favorites.ITEM_TYPE_DEEP_SHORTCUT)
       && !((ShortcutInfo)item).isPromise()){
      startShortcutIntentSafely(intent,optsBundle,item);
    } else if(user ==null || user.equals(Process.myUserHandle())){
      startActivity(intent,optsBundle);
    } else{
      LauncherAppsCompat.getInstance(this).startActivityForProfile(intent.getComponent(),
                                    user,intent.getSourceBounds(),optsBundle);
    }
    return true;
  }catch(ActivityNotFoundException|SecurityException e){
    ...
  }
  return false;
}
```

设置启动Activity为`FLAG_ACTIVITY_NEW_TASK`，保证根Activity在一个新任务栈中启动。`Launcher.java`继承了`Activity`，接下来就到了`Activity.startActivity()`中。

```java
// ../android/app/Activity.java
    @Override
    public void startActivity(Intent intent, @Nullable Bundle options) {
        if (options != null) {
            startActivityForResult(intent, -1, options);
        } else {
            startActivityForResult(intent, -1);
        }
    }
```

接下来会走到`startActivityForResult()`，第二个参数设为`-1`，表明*Launcher不需要知道返回结果*。

```java
// ../android/app/Activity.java
 Activity mParent;

 public void startActivityForResult(@RequiresPermission Intent intent, int requestCode,
            @Nullable Bundle options) {
        if (mParent == null) {
            options = transferSpringboardActivityOptions(options);
            Instrumentation.ActivityResult ar =
                mInstrumentation.execStartActivity(
                    this, 
              mMainThread.getApplicationThread(), /*ApplicationThread*/
              mToken, 
              this,
                    intent, requestCode, options);
          ...
        }else{
          ...
        }
   ...
 }
```

`mParent`代表当前Activity的父类，由于`根Activity`还未创建出来，所以`mParent==null`成立。后续向下走就会调用到`Instrumentation.execStartActivity()`去继续启动Activity组件。

> Instrumentation用于监控应用程序和系统间的交互。

```java
// ../android/app/Instrumentation.java
public ActivityResult execStartActivity(
            Context who, IBinder contextThread, IBinder token, Activity target,
            Intent intent, int requestCode, Bundle options) {
        ...
        try {
            intent.migrateExtraStreamToClipData();
            intent.prepareToLeaveProcess(who);
            int result = ActivityManager.getService()
                .startActivity(whoThread, who.getBasePackageName(), intent,
                        intent.resolveTypeIfNeeded(who.getContentResolver()),
                        token, target != null ? target.mEmbeddedID : null,
                        requestCode, 0, null, options);
            //检查启动Activity是否存在
            checkStartActivityResult(result, intent);
        } catch (RemoteException e) {
            throw new RuntimeException("Failure from system", e);
        }
        return null;
    }
```

<!--`contenxtThread`是一个`IBinder对象`，实际指向的是`ApplicationThread`，用于进程间通信的Binder对象，可以-->

`ActivityManager.getService()`用于获取`AMS`的代理对象。实质上是把启动过程转移到了`AMS`上去执行

```java
// ../android/app/ActivityManager.java
    public static IActivityManager getService() {
        return IActivityManagerSingleton.get();
    }

    private static final Singleton<IActivityManager> IActivityManagerSingleton =
            new Singleton<IActivityManager>() {
                @Override
                protected IActivityManager create() {
                    final IBinder b = ServiceManager.getService(Context.ACTIVITY_SERVICE);
                    final IActivityManager am = IActivityManager.Stub.asInterface(b);
                    return am;
                }
            };

//../android/util/Singleton.java
public abstract class Singleton<T> {
    private T mInstance;

    protected abstract T create();

    public final T get() {
        synchronized (this) {
            if (mInstance == null) {
                mInstance = create();
            }
            return mInstance;
        }
    }
}

```

第一次调用到`getService()`时，就会调用到`IActivityManagerSingleton.get()`，由源码可知，该类是一个单例类。

在其中先去获取名为`activity`的一个代理对象(`IBinder`)，后续实现利用了`AIDL`，根据`asInterface()`可以获得`IActivityManager`对象，他是AMS在本地的代理对象。然后就可以直接调用到`AMS`的`startActivity()`。

![Launcher请求AMS时序图](/images/Launcher请求AMS时序图.png)

总结：

- 用户点击桌面图标触发`startActivitySafely()`开始调用打开根Activity流程。
- `Launcher组件`会调用到`Activity.startActivity()`后调用到`Activity.startActivityForResult()`
- 由于从Launcher启动，根Activity尚未建立，就会走到`Instrumentation.execStartActivity()`中
- 在`Instrumentation.execStartActivity()`中，实际调用的是`ActivityManager.getService()`去继续启动Activity
- 跟踪到`ActivityManager.getService()`实际返回的是一个`AMS`的本地代理对象`IActivityManager`，由前面学到的Binder机制中，这个代理对象是可以直接调用到`AMS`中的方法，所以`execStartActivity()`最终指向的是`AMS.startActivity()`

#### `startActivity`请求参数语义（补充）

从`Instrumentation.execStartActivity()`到`AMS.startActivity()`这一步，核心参数有以下作用：

- `caller/whoThread`：调用方进程在系统侧的 Binder 身份（即调用者是谁）。
- `token`：调用方 Activity 的窗口令牌，用于建立结果回传与生命周期关联。
- `requestCode`：用于`startActivityForResult`回传链路，根Activity启动时常为`-1`。
- `options`：承载动画、启动窗口、跨任务切换等附加参数。
- `FLAG_ACTIVITY_NEW_TASK`：根Activity通常要求在新的任务栈语义下启动。

这些参数不会直接创建 Activity 对象，而是作为`ActivityStarter`后续任务栈决策与调度的输入。

### AMS到ApplicationThread的调用过程

Launcher请求到AMS后，后续逻辑由AMS继续执行。继续执行的是`AMS.startActivity()`

```java
// ../core/java/com/android/server/am/ActivityManagerService.java
    public final int startActivity(IApplicationThread caller, String callingPackage,
            Intent intent, String resolvedType, IBinder resultTo, String resultWho, int requestCode,
            int startFlags, ProfilerInfo profilerInfo, Bundle bOptions) {
        return startActivityAsUser(caller, callingPackage, intent, resolvedType, resultTo,
                resultWho, requestCode, startFlags, profilerInfo, bOptions,
                UserHandle.getCallingUserId()/*获取调用者的UserId*/);
    }

    //检测调用是否合法
    @Override
    public final int startActivityAsUser(IApplicationThread caller, String callingPackage,
            Intent intent, String resolvedType, IBinder resultTo, String resultWho, int requestCode,
            int startFlags, ProfilerInfo profilerInfo, Bundle bOptions, int userId) {
        //判断调用者进程是否被隔离
        enforceNotIsolatedCaller("startActivity");
        //检测调用者权限
        userId = mUserController.handleIncomingUser(Binder.getCallingPid(), Binder.getCallingUid(),
                userId, false, ALLOW_FULL_ONLY, "startActivity", null);
        // TODO: Switch to user app stacks here.
        return mActivityStarter.startActivityMayWait(caller, -1, callingPackage, intent,
                resolvedType, null, null, resultTo, resultWho, requestCode, startFlags,
                profilerInfo, null, null, bOptions, false, userId, null, null,
                "startActivityAsUser");
    }

    void enforceNotIsolatedCaller(String caller) {
        if (UserHandle.isIsolated(Binder.getCallingUid())) {
            throw new SecurityException("Isolated process not allowed to call " + caller);
        }
    }
```

进入到`AMS.startActivity()`中，会调用到`startActivityAsUser()`，在这个方法中需要去判断调用是否合法。需要先`检测调用者进程是否被隔离`以及`调用者权限是否正确`。

前面都通过的话，就会调用到`ActivityStarter.startActivityMayWait()`。没有通过校验的话就会抛出`SecurityException`异常。

```java
// ../core/java/com/android/server/am/ActivityStarter.java
 final int startActivityMayWait(IApplicationThread caller, int callingUid,
            String callingPackage, Intent intent, String resolvedType,
            IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
            IBinder resultTo, String resultWho, int requestCode, int startFlags,
            ProfilerInfo profilerInfo, WaitResult outResult,
            Configuration globalConfig, Bundle bOptions, boolean ignoreTargetSecurity, int userId,
            IActivityContainer iContainer, TaskRecord inTask/*Activity所在任务栈*/, String reason/*启动理由*/) {
   ...
                 //指向 startActivityLocked 方法
                 int res = startActivityLocked(caller, intent, ephemeralIntent, resolvedType,
                    aInfo, rInfo, voiceSession, voiceInteractor,
                    resultTo, resultWho, requestCode, callingPid,
                    callingUid, callingPackage, realCallingPid, realCallingUid, startFlags,
                    options, ignoreTargetSecurity, componentSpecified, outRecord, container,
                    inTask, reason);
   ...
   
 }

 int startActivityLocked(IApplicationThread caller, Intent intent, Intent ephemeralIntent,
            String resolvedType, ActivityInfo aInfo, ResolveInfo rInfo,
            IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
            IBinder resultTo, String resultWho, int requestCode, int callingPid, int callingUid,
            String callingPackage, int realCallingPid, int realCallingUid, int startFlags,
            ActivityOptions options, boolean ignoreTargetSecurity, boolean componentSpecified,
            ActivityRecord[] outActivity, ActivityStackSupervisor.ActivityContainer container,
            TaskRecord inTask, String reason) {
        //判断启动理由不可为空
        if (TextUtils.isEmpty(reason)) {
            throw new IllegalArgumentException("Need to specify a reason.");
        }
        mLastStartReason = reason;
        mLastStartActivityTimeMs = System.currentTimeMillis();
        mLastStartActivityRecord[0] = null;
        //指向 startActivity 方法
        mLastStartActivityResult = startActivity(caller, intent, ephemeralIntent, resolvedType,
                aInfo, rInfo, voiceSession, voiceInteractor, resultTo, resultWho, requestCode,
                callingPid, callingUid, callingPackage, realCallingPid, realCallingUid, startFlags,
                options, ignoreTargetSecurity, componentSpecified, mLastStartActivityRecord,
                container, inTask);

        if (outActivity != null) {
            // mLastStartActivityRecord[0] is set in the call to startActivity above.
            outActivity[0] = mLastStartActivityRecord[0];
        }
        return mLastStartActivityResult;
    }


```

`ActivityStarter`是Android7.0新加入的类，他是加载Activity的控制类，会收集所有的逻辑来决定如何将`Intent和Flags`转换为Activity，并将Activity和Task以及Stark相关联。

调用`startActivityLocked()`之后继续走向`ActivityStarter.startActivity()`过程

```java
    /** DO NOT call this method directly. Use {@link #startActivityLocked} instead. */
    private int startActivity(IApplicationThread caller, Intent intent, Intent ephemeralIntent,
            String resolvedType, ActivityInfo aInfo, ResolveInfo rInfo,
            IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
            IBinder resultTo, String resultWho, int requestCode, int callingPid, int callingUid,
            String callingPackage, int realCallingPid, int realCallingUid, int startFlags,
            ActivityOptions options, boolean ignoreTargetSecurity, boolean componentSpecified,
            ActivityRecord[] outActivity, ActivityStackSupervisor.ActivityContainer container,
            TaskRecord inTask) {
        int err = ActivityManager.START_SUCCESS;
        // Pull the optional Ephemeral Installer-only bundle out of the options early.
        final Bundle verificationBundle
                = options != null ? options.popAppVerificationBundle() : null;
        ProcessRecord callerApp = null;
        //这个caller是一直从Launcher启动时就传下来的
        if (caller != null) {
            callerApp = mService.getRecordForAppLocked(caller);
            if (callerApp != null) {
                callingPid = callerApp.pid;
                callingUid = callerApp.info.uid;
            } else {
                Slog.w(TAG, "Unable to find app for caller " + caller
                        + " (pid=" + callingPid + ") when starting: "
                        + intent.toString());
                err = ActivityManager.START_PERMISSION_DENIED;
            }
         }
    ...
        
        ActivityRecord r = new ActivityRecord(mService, callerApp, callingPid, callingUid,
                callingPackage, intent, resolvedType, aInfo, mService.getGlobalConfiguration(),
                resultRecord, resultWho, requestCode, componentSpecified, voiceSession != null,
                mSupervisor, container, options, sourceRecord);
        if (outActivity != null) {
            outActivity[0] = r;
        }
    ...
        doPendingActivityLaunchesLocked(false);
        return startActivity(r, sourceRecord, voiceSession, voiceInteractor, startFlags, true,
                options, inTask, outActivity);
    }
```

第16行代码 `caller!=null` 这个`caller`对象是从Launcher启动时就一直传递下来的，指向的是`Launcher所在的应用程序进程的ApplicationThread对象`。

第17行代码 `mService.getRecordForAppLocked(caller)` 得到的就是一个`ProgreeRecord`对象(`用于描述一个应用程序进程`)。该对象指的就是 *Launcher组件所运行的应用程序进程*。

第30行代码 `new ActivityRecord()` `ActivityRecord用来记录一个Activity的所有信息。`在这里`ActivityRecord`指的就是将要启动的Activity即根Activity。

第39行代码 继续调用`startActivity()`并传递当前记录的Activity信息。

```java
    private int startActivity(final ActivityRecord r, ActivityRecord sourceRecord,
            IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
            int startFlags, boolean doResume, ActivityOptions options, TaskRecord inTask,
            ActivityRecord[] outActivity) {
        int result = START_CANCELED;
        try {
            mService.mWindowManager.deferSurfaceLayout();
            result = startActivityUnchecked(r, sourceRecord, voiceSession, voiceInteractor,
                    startFlags, doResume, options, inTask, outActivity);
        } finally {
            if (!ActivityManager.isStartResultSuccessful(result)
                    && mStartActivity.getTask() != null) {
                mStartActivity.getTask().removeActivity(mStartActivity);
            }
            mService.mWindowManager.continueSurfaceLayout();
        }
        
       
        postStartActivityProcessing(r, result, mSupervisor.getLastStack().mStackId,  mSourceRecord,
                mTargetStack);

        return result;
    }

    private int startActivityUnchecked(final ActivityRecord r, ActivityRecord sourceRecord,
            IVoiceInteractionSession voiceSession, IVoiceInteractor voiceInteractor,
            int startFlags, boolean doResume, ActivityOptions options, TaskRecord inTask,
            ActivityRecord[] outActivity) {
      ...
        if (mStartActivity.resultTo == null && mInTask == null && !mAddingToTask
                && (mLaunchFlags & FLAG_ACTIVITY_NEW_TASK) != 0) {
            //如果是使用 singleTask模式启动 会新建一个任务栈用来存储Activity
            newTask = true;
            result = setTaskFromReuseOrCreateNewTask(
                    taskToAffiliate, preferredLaunchStackId, topStack);
        } else if (mSourceRecord != null) {
            result = setTaskFromSourceRecord();
        } else if (mInTask != null) {
            result = setTaskFromInTask();
        } else {
            // This not being started from an existing activity, and not part of a new task...
            // just put it in the top task, though these days this case should never happen.
            setTaskToCurrentTopOrCreateNewTask();
        }
        if (result != START_SUCCESS) {
            return result;
        }  
      
      ...
         if (mDoResume) {
            final ActivityRecord topTaskActivity =
                    mStartActivity.getTask().topRunningActivityLocked();
            if (!mTargetStack.isFocusable()
                    || (topTaskActivity != null && topTaskActivity.mTaskOverlay
                    && mStartActivity != topTaskActivity)) {
                mTargetStack.ensureActivitiesVisibleLocked(null, 0, !PRESERVE_WINDOWS);
                mWindowManager.executeAppTransition();
            } else {
                if (mTargetStack.isFocusable() && !mSupervisor.isFocusedStack(mTargetStack)) {
                    mTargetStack.moveToFront("startActivityUnchecked");
                }
                mSupervisor.resumeFocusedStackTopActivityLocked(mTargetStack, mStartActivity,
                        mOptions);
            }
        } else {
            mTargetStack.addRecentActivityLocked(mStartActivity);
        }
      ...
    }
```

第30行代码 由于我们从Launcher启动根Activity时，设置启动标志为`FLAG_ACTIVITY_NEW_TASK`，所以就会走到`setTaskFromReuseOrCreateNewTask()`，这个方法主要是*管理任务栈，如果没有就会创建一个新的任务栈。*

第62代码 最终调用`ActivityStackSupervisor.resumeDocusedStackTopActivityLocked()`继续启动Activity的流程。

```java
// ../core/java/com/android/server/am/ActivityStackSupervisor.java
    boolean resumeFocusedStackTopActivityLocked(
            ActivityStack targetStack, ActivityRecord target, ActivityOptions targetOptions) {
        //判断当前的任务栈是否相同
        if (targetStack != null && isFocusedStack(targetStack)) {
            return targetStack.resumeTopActivityUncheckedLocked(target, targetOptions);
        }
        //获取要启动Activity的所在栈的栈顶Activity且不处于停止状态
        final ActivityRecord r = mFocusedStack.topRunningActivityLocked();
        //由于Activity尚未启动 满足要求
        if (r == null || r.state != RESUMED) {
            mFocusedStack.resumeTopActivityUncheckedLocked(null, null);
        } else if (r.state == RESUMED) {
            // Kick off any lingering app transitions form the MoveTaskToFront operation.
            mFocusedStack.executeAppTransition(targetOptions);
        }
        return false;
    }

```

由于要启动的Activity尚未启动，所以会继续调用`ActivityStack.resumeTopActivityUncheckedLocked()`

```java
// ../core/java/com/android/server/am/ActivityStack.java
    boolean resumeTopActivityUncheckedLocked(ActivityRecord prev, ActivityOptions options) {
        if (mStackSupervisor.inResumeTopActivity) {
            // Don't even start recursing.
            return false;
        }

        boolean result = false;
        try {
            // Protect against recursion.
            mStackSupervisor.inResumeTopActivity = true;
            result = resumeTopActivityInnerLocked(prev, options);
        } finally {
            mStackSupervisor.inResumeTopActivity = false;
        }
        mStackSupervisor.checkReadyForSleepLocked();

        return result;
    }

   private boolean resumeTopActivityInnerLocked(ActivityRecord prev, ActivityOptions options) {
     ...
       //需要启动Activity
       mStackSupervisor.startSpecificActivityLocked(next, true, true);
     ...
     return true;
   }
```



```java
// ../core/java/com/android/server/am/ActivityStackSupervisor.java


    void startSpecificActivityLocked(ActivityRecord r,
            boolean andResume, boolean checkConfig) {
        // 获取即将启动Activity所在的应用程序进程
        ProcessRecord app = mService.getProcessRecordLocked(r.processName,
                r.info.applicationInfo.uid, true);

        r.getStack().setLaunchTime(r);

        if (app != null && app.thread != null) {
           //进程已经启动
            try {
                if ((r.info.flags&ActivityInfo.FLAG_MULTIPROCESS) == 0
                        || !"android".equals(r.info.packageName)) {
                    app.addPackage(r.info.packageName, r.info.applicationInfo.versionCode,
                            mService.mProcessStats);
                }
                realStartActivityLocked(r, app, andResume, checkConfig);
                return;
            } catch (RemoteException e) {
                Slog.w(TAG, "Exception when starting activity "
                        + r.intent.getComponent().flattenToShortString(), e);
            }
        }
        //启动应用进程
        mService.startProcessLocked(r.processName, r.info.applicationInfo, true, 0,
                "activity", r.intent.getComponent(), false, false, true);
    }


```



![AMS-应用程序进程通信](/images/AMS-应用程序进程通信.png)

这一节主要是从`ActivityManagerService`经过层层调用到达`ApplicationThread`的Activity启动方法。



![AMS-ApplicationThread调用过程](/images/AMS-ApplicationThread调用过程.png)

`ActivityStack`:Activity的任务栈，从中获取需要进行操作的`ActivityRecord`进行操作。*在启动过程中，它的作用是检测当前栈顶Activity是否为要启动的Activity,不是就启动新Activity，是的话就重启，在这之前需要标记一下前Activity处于Pause状态。*

`ActivityStackSupervisor`:管理整个手机任务栈，管理着所有的`ActivityStack`。*在启动过程中，它负责检查是否已有对应的应用进程在运行，如果有就直接启动Activity，没有的话则需新建一个应用进程。*

总结：

- 调用`AMS.startActivity()`实质调用其内部的`startActivityAsUser()`并在方法内部进行验证，判定*调用者进程是否隔离以及调用者权限是否正确*
- 通过验证后，就到了`ActivityStarter.startActivityMayWait()`,并设置启动理由为`startActivityAsUser`
- 向下调用到了`startActivityLocked()`，方法内部会去判定`reason`是否为空
- 不为空则走到`startActivity()`，该方法中主要*caller(`指向Launcher组件所运行进程的ApplicationThread对象`)*、*callerApp(`指向Launcher组件所运行的应用程序进程`)*，基于`callerApp`生成对应的`ActivityRecord(记录即将要启动的Activity)`并存入`ActivityRecord[]`中备用。
- 对应参数传入`startActivity()`的重载函数中，向下继续调用`startActivityUnchecked()`
- `startActivityUnchecked()`主要是 创建新的`TaskRecord(记录任务栈信息)`
- 向下切换到`ActivityStackSupervisor.resumeFocusedStackTopActivityLocked()`，这个方法主要实现的是`寻找需要恢复的栈顶Activity`。
- 内部实现由`ActivityStack.resumeTopActivityUncheckedLocked()`完成，这里又继续调用到`resumeTopActivityInnerLocked()`。
- 后续又切换回到`ActivityStackSupervisor.startSpecificActivityLocked()`，在该方法中`获取即将启动的Activity所在应用程序进程`，已启动的话调用`realStartActivityLocked()`，未启动的话就调用`startProcessLocked()`去启动进程

#### `ActivityStarter`关键决策点（补充）

`ActivityStarter`在调度阶段主要做三类决策：

1. 任务栈决策：是否复用现有`TaskRecord`，以及是否需要清理栈顶 Activity。
2. 目标实例决策：是否复用现有`ActivityRecord`，还是创建新的记录对象。
3. 进程决策：目标进程是否已存在，已存在走`realStartActivityLocked`，否则走`startProcessLocked`。

换句话说，`startActivity`在 AMS 阶段的核心不是“立刻创建 Activity”，而是“先完成调度与状态机合法性”。

补充：启动模式与任务栈行为可以拆成两层判断：

- 先判断任务栈归属（是否受`FLAG_ACTIVITY_NEW_TASK/taskAffinity`影响）。
- 再判断目标实例复用（`standard/singleTop/singleTask`）。
- `singleTop`只在目标实例位于栈顶时复用，否则仍会创建新实例。
- `singleTask`命中已存在实例时，会复用该实例并清理其上的Activity。

### AMS启动应用进程

由于启动是根Activity，这时应用进程尚未启动，需要通过`AMS.startProcessLocked()`创建一个应用程序进程

```java
// ../core/java/com/android/server/am/ActivityManagerService.java
    final ProcessRecord startProcessLocked(String processName,
            ApplicationInfo info, boolean knownToBeDead, int intentFlags,
            String hostingType, ComponentName hostingName, boolean allowWhileBooting,
            boolean isolated, boolean keepIfLarge) {
        return startProcessLocked(processName, info, knownToBeDead, intentFlags, hostingType,
                hostingName, allowWhileBooting, isolated, 0 /* isolatedUid */, keepIfLarge,
                null /* ABI override */, null /* entryPoint */, null /* entryPointArgs */,
                null /* crashHandler */);
    }  

    final ProcessRecord startProcessLocked(String processName, ApplicationInfo info,
            boolean knownToBeDead, int intentFlags, String hostingType, ComponentName hostingName,
            boolean allowWhileBooting, boolean isolated, int isolatedUid, boolean keepIfLarge,
            String abiOverride, String entryPoint, String[] entryPointArgs, Runnable crashHandler) {
        long startTime = SystemClock.elapsedRealtime();
        ProcessRecord app;
        ...
        startProcessLocked(
             app, hostingType, hostingNameStr, abiOverride, entryPoint, entryPointArgs);
    }    


    private final void startProcessLocked(ProcessRecord app, String hostingType,
            String hostingNameStr, String abiOverride, String entryPoint, String[] entryPointArgs) {
      ...
        //
        boolean isActivityProcess = (entryPoint == null);
            if (entryPoint == null) entryPoint = "android.app.ActivityThread";
          
        Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "Start proc: " +
                    app.processName);
            checkTime(startTime, "startProcess: asking zygote to start proc");
            ProcessStartResult startResult;
            if (hostingType.equals("webview_service")) {
                startResult = startWebView(entryPoint,
                        app.processName, uid, uid, gids, debugFlags, mountExternal,
                        app.info.targetSdkVersion, seInfo, requiredAbi, instructionSet,
                        app.info.dataDir, null, entryPointArgs);
            } else {
                startResult = Process.start(entryPoint,
                        app.processName, uid, uid, gids, debugFlags, mountExternal,
                        app.info.targetSdkVersion, seInfo, requiredAbi, instructionSet,
                        app.info.dataDir, invokeWith, entryPointArgs);
            }
      ...
    }
```

调用到`Process`的静态成员函数`start()`启动一个新的应用进程，指定了该进程的入口函数为`ActivityThread.main()`；因此创建应用进程结束时，逻辑就转移到了`ActivityThread.main()`上。

#### `startProcessLocked`关键参数与进程属性（补充）

`startProcessLocked`除了“拉起进程”本身，还同时确定了进程运行环境：

- `processName`：目标进程名（可与包名一致，也可通过`android:process`声明子进程）。
- `uid/gid`：Linux 进程身份，决定文件权限与沙箱边界。
- `targetSdkVersion`：影响运行时兼容行为分支。
- `abi/instructionSet`：决定使用的指令集与 native 代码运行环境。
- `entryPoint`：普通应用进程默认是`android.app.ActivityThread`。

因此这一步不仅是“创建进程”，也是“确定进程运行画像”的关键阶段。

```java 
Process.start() => ZygoteProcess.start() == LocalSocket连接 => ZygoteServer.runSelectLoop() => ZygoteConnection.processOneCommand() => 
// 源码路径：java/com/android/internal/os/ZygoteConnection.java
Runnable processOneCommand(ZygoteServer zygoteServer) {
...
  //从Zygote孵化一个新进程并赋予 pid
          pid = Zygote.forkAndSpecialize(parsedArgs.uid, parsedArgs.gid, parsedArgs.gids,
                parsedArgs.runtimeFlags, rlimits, parsedArgs.mountExternal, parsedArgs.seInfo,
                parsedArgs.niceName, fdsToClose, fdsToIgnore, parsedArgs.startChildZygote,
                parsedArgs.instructionSet, parsedArgs.appDataDir);

        try {
            if (pid == 0) {
                // in child
                zygoteServer.setForkChild();

                zygoteServer.closeServerSocket();
                IoUtils.closeQuietly(serverPipeFd);
                serverPipeFd = null;

                return handleChildProc(parsedArgs, descriptors, childPipeFd,
                        parsedArgs.startChildZygote);
            } else {
                // In the parent. A pid < 0 indicates a failure and will be handled in
                // handleParentProc.
                IoUtils.closeQuietly(childPipeFd);
                childPipeFd = null;
                handleParentProc(pid, descriptors, serverPipeFd);
                return null;
            }
        } finally {
            IoUtils.closeQuietly(childPipeFd);
            IoUtils.closeQuietly(serverPipeFd);
        }
}
  
=> ZygoteConnection.handleChildProc()
  
private Runnable handleChildProc(Arguments parsedArgs, FileDescriptor[] descriptors,
            FileDescriptor pipeFd, boolean isZygote) {
  ...
             if (!isZygote) {
                return ZygoteInit.zygoteInit(parsedArgs.targetSdkVersion, parsedArgs.remainingArgs,
                        null /* classLoader */);
            } else {
                return ZygoteInit.childZygoteInit(parsedArgs.targetSdkVersion,
                        parsedArgs.remainingArgs, null /* classLoader */);
            }
}

=> ZygoteInit.zygoteInit()
  
    public static final Runnable zygoteInit(int targetSdkVersion, String[] argv, ClassLoader classLoader) {
        if (RuntimeInit.DEBUG) {
            Slog.d(RuntimeInit.TAG, "RuntimeInit: Starting application from zygote");
        }

        Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "ZygoteInit");
        RuntimeInit.redirectLogStreams();

        RuntimeInit.commonInit();
        ZygoteInit.nativeZygoteInit();
        
        return RuntimeInit.applicationInit(targetSdkVersion, argv, classLoader);
    }

=> RuntimeInit.applicationInit()
  
 protected static Runnable applicationInit(int targetSdkVersion, String[] argv,
            ClassLoader classLoader) {
 ...
           // Remaining arguments are passed to the start class's static main
        return findStaticMain(args.startClass, args.startArgs, classLoader);
}

=> RuntimeInit.findStaticMain()//此时完成了对   android.app.ActivityThread.main()的反射调用

      protected static Runnable findStaticMain(String className, String[] argv,
            ClassLoader classLoader) {
        Class<?> cl;
        try {
            cl = Class.forName(className, true, classLoader);
        } catch (ClassNotFoundException ex) {
            throw new RuntimeException(
                    "Missing class when invoking static main " + className,
                    ex);
        }

        Method m;
        try {
            m = cl.getMethod("main", new Class[] { String[].class });
        } catch (NoSuchMethodException ex) {
            throw new RuntimeException(
                    "Missing static main on " + className, ex);
        } catch (SecurityException ex) {
            throw new RuntimeException(
                    "Problem getting static main on " + className, ex);
        }
  ...
}
  
```

拓展：为什么不用Binder而是采用Socket进行 ZygoteProcess与AMS间的通信。

1. 父进程binder线程有锁，然后子进程的主线程一直在等其子线程(从父进程拷贝过来的子进程)的资源，但是其实父进程的子进程并没有被拷贝过来，造成死锁，所以**fork不允许存在多线程**。而非常巧的是**Binder通讯偏偏就是多线程，所以干脆父进程（Zgote）这个时候就不使用binder线程**
2. `fork()`不支持多线程，可能导致binder调用的时候，多个service发起fork请求，导致部分service创建失败

> Zygote进程孵化出新的应用进程后，通过反射执行`ActivityThread.main()`，在该方法中会事先准备好`Looper以及MessageQueue`，继续调用`attach()`用进程绑定到`AMS`，然后开始消息循环，不断读取队列消息，并分发消息。

```java
// ../android/app/ActivityThread.java
	public static void main(String[] args) {
        //准备主线程Looper 以便Handler调用
        Looper.prepareMainLooper();
        //创建主进程的 ActivityThread
        ActivityThread thread = new ActivityThread();
        //将该进程进行绑定
        thread.attach(false);

        if (sMainThreadHandler == null) {
            //保存进程对应的主线程Handler
            sMainThreadHandler = thread.getHandler();
        }

        // End of event ActivityThreadMain.
        Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
        //主线程开始消息循环
        Looper.loop();
    
  }
  final ApplicationThread mAppThread = new ApplicationThread();
  private void attach(boolean system) {
      ...
        if (!system) {
          ...
            final IActivityManager mgr = ActivityManager.getService();
            try {
                mgr.attachApplication(mAppThread);
            } catch (RemoteException ex) {
                throw ex.rethrowFromSystemServer();
            }
        }else{
          ...
        }
      ...
  }
```

`AMS`attach的是`ActivityThread`的代理对象`ApplicationThread`，然后`AMS`就可以通过代理对象对主线程进行操作。

**至此，应用进程创建完毕，并且已建立主线程完毕并开启了消息循环。**

### 创建并绑定Application

这时应用进程以及主线程已经创造完毕，接下来就是要创建`Application`

```java
// ../core/java/com/android/server/am/ActivityManagerService.java
    @Override
    public final void attachApplication(IApplicationThread thread) {
        synchronized (this) {
            //获取当前进程的id
            int callingPid = Binder.getCallingPid();
            final long origId = Binder.clearCallingIdentity();
            attachApplicationLocked(thread, callingPid);
            Binder.restoreCallingIdentity(origId);
        }
    }

    private final boolean attachApplicationLocked(IApplicationThread thread,
            int pid) {
        
        ProcessRecord app;
        long startTime = SystemClock.uptimeMillis();
        if (pid != MY_PID && pid >= 0) {
            synchronized (mPidsSelfLocked) {
                app = mPidsSelfLocked.get(pid);
            }
        } else {
            app = null;
        }
       // 如果获取进程信息为空 直接杀死进程并退出
       if (app == null) {
            if (pid > 0 && pid != MY_PID) {
                killProcessQuiet(pid);
            } else {
                try {
                    thread.scheduleExit();
                } catch (Exception e) {
                    // Ignore exceptions.
                }
            }
            return false;
        }
        //创建死亡代理，被kill后可以通知AMS
        try {
            AppDeathRecipient adr = new AppDeathRecipient(
                    app, pid, thread);
            thread.asBinder().linkToDeath(adr, 0);
            app.deathRecipient = adr;
        } catch (RemoteException e) {
            app.resetPackageList(mProcessStats);
            startProcessLocked(app, "link fail", processName);
            return false;
        }
      
        try {
         ...
           if (app.instr != null) {
                //绑定Application
                thread.bindApplication(processName, appInfo, providers,
                        app.instr.mClass,
                        profilerInfo, app.instr.mArguments,
                        app.instr.mWatcher,
                        app.instr.mUiAutomationConnection, testMode,
                        mBinderTransactionTrackingEnabled, enableTrackAllocation,
                        isRestrictedBackupMode || !normalMode, app.persistent,
                        new Configuration(getGlobalConfiguration()), app.compat,
                        getCommonServicesLocked(app.isolated),
                        mCoreSettingsObserver.getCoreSettingsLocked(),
                        buildSerial);
            } else {
                thread.bindApplication(processName, appInfo, providers, null, profilerInfo,
                        null, null, null, testMode,
                        mBinderTransactionTrackingEnabled, enableTrackAllocation,
                        isRestrictedBackupMode || !normalMode, app.persistent,
                        new Configuration(getGlobalConfiguration()), app.compat,
                        getCommonServicesLocked(app.isolated),
                        mCoreSettingsObserver.getCoreSettingsLocked(),
                        buildSerial);
            }
        }catch(Exception e){
          ...
          //启动失败 重启当前进程
          startProcessLocked(app, "bind fail", processName);
          return false;
        }
        //准备启动根Activity
         try {
                if (mStackSupervisor.attachApplicationLocked(app)) {
                    didSomething = true;
                }
            } catch (Exception e) {
                Slog.wtf(TAG, "Exception thrown launching activities in " + app, e);
                badApp = true;
         }
      
       //绑定Service以及BroadCast的Application
       ...
       if (badApp) {
            //如果以上组件启动出错，则需要杀死进程并移除记录
            app.kill("error during init", true);
            handleAppDiedLocked(app, false, true);
            return false;
        }

        //如果以上没有启动任何组件，那么didSomething为false
        if (!didSomething) {
            //调整进程的oom_adj值， oom_adj相当于一种优先级
            //如果应用进程没有运行任何组件，那么当内存出现不足时，该进程是最先被系统“杀死”
            updateOomAdjLocked();
        }
        return true;

    }

```

在`AMS.attachApplicationLocked()`主要做了两步：

#### `attachApplicationLocked`职责拆分（补充）

这一阶段可以拆成 3 个职责块：

1. 进程身份确认：根据`pid`找到`ProcessRecord`并建立死亡回调`linkToDeath`。
2. 运行时绑定：通过`thread.bindApplication()`把应用运行时参数发送到`ActivityThread`主线程。
3. 组件继续调度：在应用侧完成绑定后，再继续触发根Activity/Service/Broadcast等组件启动。

其中第 2 步与第 3 步是“先绑定运行时，再启动组件”的顺序关系。

#### `thread.bindApplication()`：绑定Application到ActivityThread上

```java
// ../android/app/ActivityThread.java
public final void bindApplication(String processName, ApplicationInfo appInfo,
                List<ProviderInfo> providers, ComponentName instrumentationName,
                ProfilerInfo profilerInfo, Bundle instrumentationArgs,
                IInstrumentationWatcher instrumentationWatcher,
                IUiAutomationConnection instrumentationUiConnection, int debugMode,
                boolean enableBinderTracking, boolean trackAllocation,
                boolean isRestrictedBackupMode, boolean persistent, Configuration config,
                CompatibilityInfo compatInfo, Map services, Bundle coreSettings,
                String buildSerial) {

            if (services != null) {
                // Setup the service cache in the ServiceManager
                ServiceManager.initServiceCache(services);
            }

            setCoreSettings(coreSettings);

            AppBindData data = new AppBindData();
            //设置Data参数
            ...
            sendMessage(H.BIND_APPLICATION, data);
        }

private class H extends Handler {
    public static final int BIND_APPLICATION         = 110;
  ...
    public void handleMessage(Message msg) {
            if (DEBUG_MESSAGES) Slog.v(TAG, ">>> handling: " + codeToString(msg.what));
            switch (msg.what) {
                 case BIND_APPLICATION:
                    Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "bindApplication");
                    AppBindData data = (AppBindData)msg.obj;
                    handleBindApplication(data);
                    Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
                    break;
                ...
            }
    ...
}
```

> `H`相当于`ApplcationThread`与`ActivityThread`的中间人，其中`AMS与ActivityThread通信靠 ApplicationThread，ActivityThread与ApplicationThread通信靠Handler`。
>
> 这里涉及的就是**`Android的主线程消息循环模型`**。

在`ApplicationThread`发送`BIND_APPLICATION`标识的消息时，`H`接收到消息，调用`handleBindApplication()`

```java
Instrumentation mInstrumentation;
private void handleBindApplication(AppBindData data) {
  ...
  //获取LoaderApk对象
  data.info = getPackageInfoNoCheck(data.appInfo, data.compatInfo);
  //创建进程对应的Android运行环境ContextImpl
  final ContextImpl appContext = ContextImpl.createAppContext(this, data.info);
  
  final InstrumentationInfo ii;
   if (ii != null) {
     ...
   }else{
     //Activity中所有的生命周期方法都会被Instrumentation监控
     //只要是执行Activity生命周期的相关方法前后一定会调用Instrumentation相关方法
     mInstrumentation = new Instrumentation();
   }
  
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

`handleBindApplicaiton()`主要是**为了让一个Java的进程可以加入到Android中**。

主要执行步骤有以下几步：

1. 设置进程的基本参数，例如进程名，时区等，配置资源以及兼容性设计。
2. 创建进程对应的`ContextImpl、LoaderApk以及Application`对象，并初始化`ContentProvide以及Application`。
3. 创建`Instrumentation`监听Activity的生命周期。(**一个进程对应一个Instrumentation实例**)

#### `handleBindApplication`执行顺序补全（补充）

这里有一个关键顺序容易被忽略：

1. 创建`ContextImpl/LoadedApk/Application`。
2. 安装`ContentProvider`（`installContentProviders`）。
3. 回调`Application.onCreate()`。

也就是说，`ContentProvider`初始化通常先于`Application.onCreate()`，这也是很多库在 Provider 中做自动初始化的基础。

#### `mStackSupervisor.attachApplicationLocked()`：启动根Activity

在该方法中`Application`已经绑定到进程上，接下来就是启动根Activity

```java
// ../core/java/com/android/server/am/ActivityStackSupervisor.java
boolean attachApplicationLocked(ProcessRecord app) throws RemoteException {
        final String processName = app.processName;
        boolean didSomething = false;
        //ActivityStackSupervisor里面维护着所有ActivityStack
        //通过循环 找到前台任务栈顶端的Activity
        for (int displayNdx = mActivityDisplays.size() - 1; displayNdx >= 0; --displayNdx) {
            ArrayList<ActivityStack> stacks = mActivityDisplays.valueAt(displayNdx).mStacks;
            for (int stackNdx = stacks.size() - 1; stackNdx >= 0; --stackNdx) {
                final ActivityStack stack = stacks.get(stackNdx);
                if (!isFocusedStack(stack)) {
                    continue;
                }
                ActivityRecord hr = stack.topRunningActivityLocked();
                if (hr != null) {
                    //前台待启动的Activity与当前新建的进程一致时，启动这个Activity
                    if (hr.app == null && app.uid == hr.info.applicationInfo.uid
                            && processName.equals(hr.processName)) {
                        try {
                            if (realStartActivityLocked(hr, app, true, true)) {
                                didSomething = true;
                            }
                        } catch (RemoteException e) {
                            throw e;
                        }
                    }
                }
            }
        }
        if (!didSomething) {
            ensureActivitiesVisibleLocked(null, 0, !PRESERVE_WINDOWS);
        }
        return didSomething;
    }
```

需要启动的Activity所在进程已经启动时，开始准备启动根Activity `realStartActivityLocked()`

补充：这里也是“是否需要拉起进程”的关键分叉点：

- 进程不存在：`startProcessLocked()` -> `attachApplicationLocked()` -> `realStartActivityLocked()`。
- 进程已存在：可直接进入`realStartActivityLocked()`，省去进程创建成本。

因此同一启动请求在冷、热两种进程状态下，链路长度和耗时会明显不同。

```java
final boolean realStartActivityLocked(ActivityRecord r, ProcessRecord app,
            boolean andResume, boolean checkConfig) throws RemoteException {    
  ...
app.thread.scheduleLaunchActivity(new Intent(r.intent), r.appToken,
                    System.identityHashCode(r), r.info,
                    // TODO: Have this take the merged configuration instead of separate global and
                    // override configs.
                    mergedConfiguration.getGlobalConfiguration(),
                    mergedConfiguration.getOverrideConfiguration(), r.compat,
                    r.launchedFromPackage, task.voiceInteractor, app.repProcState, r.icicle,
                    r.persistentState, results, newIntents, !andResume,
                    mService.isNextTransitionForward(), profilerInfo);
  ...
}
```

这里的`app.thread`的类型为`IApplicationThread`，它的实现是`ActivityThread`的内部类`ApplicationThread`。`app`指代的是要启动的Acttvity所在的应用进程。因此这段代码指的就是要在目标应用程序进程中启动Activity。



![AMS启动进程并绑定Application](/images/AMS启动进程并绑定Application.png)



### ActivityThread启动Activity过程

这时Activity的启动过程从`AMS`切换到了`ApplicationThread`中，最后是调用到了`ApplicationThread.scheduleLaunchActivity()`

```java
// ../android/app/ActivityThread.java        
@Override
        public final void scheduleLaunchActivity(Intent intent, IBinder token, int ident,
                ActivityInfo info, Configuration curConfig, Configuration overrideConfig,
                CompatibilityInfo compatInfo, String referrer, IVoiceInteractor voiceInteractor,
                int procState, Bundle state, PersistableBundle persistentState,
                List<ResultInfo> pendingResults, List<ReferrerIntent> pendingNewIntents,
                boolean notResumed, boolean isForward, ProfilerInfo profilerInfo) {

            updateProcessState(procState, false);

            ActivityClientRecord r = new ActivityClientRecord();

            r.token = token;
            r.ident = ident;
            r.intent = intent;
            r.referrer = referrer;
            r.voiceInteractor = voiceInteractor;
            r.activityInfo = info;
            r.compatInfo = compatInfo;
            r.state = state;
            r.persistentState = persistentState;

            r.pendingResults = pendingResults;
            r.pendingIntents = pendingNewIntents;

            r.startsNotResumed = notResumed;
            r.isForward = isForward;

            r.profilerInfo = profilerInfo;

            r.overrideConfig = overrideConfig;
            updatePendingConfiguration(curConfig);

            sendMessage(H.LAUNCH_ACTIVITY, r);
        }
```

将需要启动Activity的参数封装成`ActivityClientRecord`，在调用`sendMessage()`设置类型为`LAUNCH_ACTIVITY`，并将`ActivityClientRecord`传递过去。

```java
final H mh = new H();
private void sendMessage(int what, Object obj, int arg1, int arg2, boolean async) {
        if (DEBUG_MESSAGES) Slog.v(
            TAG, "SCHEDULE " + what + " " + mH.codeToString(what)
            + ": " + arg1 + " / " + obj);
        Message msg = Message.obtain();
        msg.what = what;
        msg.obj = obj;
        msg.arg1 = arg1;
        msg.arg2 = arg2;
        if (async) {
            msg.setAsynchronous(true);
        }
        mH.sendMessage(msg);
    }
```

这里的`mh`指的就是`H`，这个`H`是`ActivityThread`的内部类并继承自`Handler`，是主线程的消息管理类。因为`ApplicationThread`是一个Binder，它的调用逻辑是在`Binder线程池`中。所以这里就要把执行逻辑切换到主线程中，就使用了`Handler`。

```java
private class H extends Handler {
 public static final int LAUNCH_ACTIVITY         = 100;
  ...
    public void handleMessage(Message msg) {
            if (DEBUG_MESSAGES) Slog.v(TAG, ">>> handling: " + codeToString(msg.what));
            switch (msg.what) {
                case LAUNCH_ACTIVITY: {
                    Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "activityStart");
                    //将传递过来的msg.obj转化为ActivityClientRecord
                    final ActivityClientRecord r = (ActivityClientRecord) msg.obj;
                    // 获得LoaderApk类型的对象并赋值到ActivityClientRecoed中
                    r.packageInfo = getPackageInfoNoCheck(
                            r.activityInfo.applicationInfo, r.compatInfo);
                    handleLaunchActivity(r, null, "LAUNCH_ACTIVITY");
                    Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
                } break;
                ...
            }
    ...
}
```

> 每一个Android程序都是打包在一个Apk文件中的，一个Apk文件包含了一个Android程序中的所有资源。应用程序进程在启动一个Activity组件时，需要将它所属的Apk文件加载进来，以便访问内部资源。`ActivityThread`内部使用`LoaderApk`描述一个已加载的Apk文件。

继续向下调用到`handleLauncheActivity()`

```java
 private void handleLaunchActivity(ActivityClientRecord r, Intent customIntent, String reason) {
 ...
   //Window开始初始化
   WindowManagerGlobal.initialize();
   //准备启动Activity
   Activity a = performLaunchActivity(r, customIntent);

   if (a != null) {
            r.createdConfig = new Configuration(mConfiguration);
            reportSizeConfigurations(r);
            Bundle oldState = r.state;
            //将要启动的Activity状态设为 Resumed 标记待激活
            handleResumeActivity(r.token, false, r.isForward,
                    !r.activity.mFinished && !r.startsNotResumed, r.lastProcessedSeq, reason);
            if (!r.activity.mFinished && r.startsNotResumed) {
                performPauseActivityIfNeeded(r, reason);
                if (r.isPreHoneycomb()) {
                    r.state = oldState;
                }
            }
        } else {
            // If there was an error, for any reason, tell the activity manager to stop us.
            try {
                //停止Activity启动
                ActivityManager.getService()
                    .finishActivity(r.token, Activity.RESULT_CANCELED, null,
                            Activity.DONT_FINISH_TASK_WITH_ACTIVITY);
            } catch (RemoteException ex) {
                throw ex.rethrowFromSystemServer();
            }
        }   
 }
```

首先调用`performLaunchActivity()`开始准备启动Activity，内部会调用Activity的`Oncreate(),onStart(),onRestoreInstaceState()`

`performResumeActivity()`对应生命周期的`onResume()`，之后开始调用View的绘制，Activity的内容开始渲染到Window上面，直到我们看见绘制结果。

#### 生命周期与首帧绘制关系（补充）

`onResume()`不等于“首帧已经显示”。

- `onResume()`表示 Activity 进入前台交互阶段。
- 首帧可见发生在后续`Window`提交绘制、`ViewRootImpl`完成首轮`performTraversals`并被系统合成之后。

因此在启动分析中要区分“生命周期完成点”和“首帧可见点”两个时刻。

```java
private Activity performLaunchActivity(ActivityClientRecord r, Intent customIntent) {
  ...
}
```

`performLaunchActivity()`主要完成了如下几件事：

1. 从`ActivityClientRecord`中获取待启动的Activity的组件信息

   ```java
    ActivityInfo aInfo = r.activityInfo;
           if (r.packageInfo == null) {
               //获取LoadedApk对象
               r.packageInfo = getPackageInfo(aInfo.applicationInfo, r.compatInfo,
                       Context.CONTEXT_INCLUDE_CODE);
           }
           //获取组件信息
           ComponentName component = r.intent.getComponent();
           if (component == null) {
               component = r.intent.resolveActivity(
                   mInitialApplication.getPackageManager());
               r.intent.setComponent(component);
           }
   
           if (r.activityInfo.targetActivity != null) {
               component = new ComponentName(r.activityInfo.packageName,
                       r.activityInfo.targetActivity);
           }
   ```

   `ComponentName`包含了`Activity组件的包名及类名。`

2. 通过`Instrumentation.newActivity()`使用类加载器创建Activity对象

   ```java
    Activity activity = null;
           try {
               java.lang.ClassLoader cl = appContext.getClassLoader();
               //用类加载器创建该Activity的实例
               activity = mInstrumentation.newActivity(
                       cl, component.getClassName(), r.intent);
               StrictMode.incrementExpectedActivityCount(activity.getClass());
               r.intent.setExtrasClassLoader(cl);
               r.intent.prepareToEnterProcess();
               if (r.state != null) {
                   r.state.setClassLoader(cl);
               }
           } catch (Exception e) {
             ...
           }
   ```

   ```java
   // ../android/app/Instrumentation.java   
   public Activity newActivity(ClassLoader cl, String className,
               Intent intent)
               throws InstantiationException, IllegalAccessException,
               ClassNotFoundException {
           return (Activity)cl.loadClass(className).newInstance();
       }
   ```

3. 通过`LoadedApk.makeApplication()`创建Application对象（*实际是判空*）

   ```java
   Application app = r.packageInfo.makeApplication(false, mInstrumentation);
   
   // ../android/app/LoaderApk.java
       public Application makeApplication(boolean forceDefaultAppClass,
               Instrumentation instrumentation) {
           if (mApplication != null) {
               return mApplication;
           }
         
         //新建Application
         try {
               java.lang.ClassLoader cl = getClassLoader();
               if (!mPackageName.equals("android")) {
                   Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER,
                           "initializeJavaContextClassLoader");
                   initializeJavaContextClassLoader();
                   Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
               }
               ContextImpl appContext = ContextImpl.createAppContext(mActivityThread, this);
               app = mActivityThread.mInstrumentation.newApplication(
                       cl, appClass, appContext);
               appContext.setOuterContext(app);
           } catch (Exception e) {
               if (!mActivityThread.mInstrumentation.onException(app, e)) {
                   Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
                   throw new RuntimeException(
                       "Unable to instantiate application " + appClass
                       + ": " + e.toString(), e);
               }
           }
           mActivityThread.mAllApplications.add(app);
           mApplication = app;
       }
   ```

   由于在前面`创建并绑定Application`过程中的`bindApplication()`就已经创建好了`Application`，所以这一步只是起到了预防作用，并且不会重复创建。

4. 创建`ContextImpl`对象，并通过`Activity.attach()`完成一些重要数据的初始化

   ```java
   ContextImpl appContext = createBaseContextForActivity(r);
   appContext.setOuterContext(activity);
                   activity.attach(appContext, this, getInstrumentation(), r.token,
                           r.ident, app, r.intent, r.activityInfo, title, r.parent,
                           r.embeddedID, r.lastNonConfigurationInstances, config,
                           r.referrer, r.voiceInteractor, window, r.configCallback);
   
   ```

   > `ContextImpl`是一个很重要的数据结构，它是`Context`的具体实现，Context中大部分逻辑都是由`ContextImpl`完成的。`ContextImpl`是通过`Activity.attach()`与Activity进行关联的。除此之外，在`attach()`中，**Activity还会完成Window的创建并建立关联**，这样当Window接收到外部输入事件以后就可以将事件传递给Activity。

5. 调用`Activity.oncreate()`加载用户界面

   ```java
   mInstrumentation.callActivityOnCreate(activity, r.state);
   
   mInstrumentation.callActivityOnRestoreInstanceState(activity, r.state,
                                       r.persistentState);
   
   mInstrumentation.callActivityOnPostCreate(activity, r.state,
                                   r.persistentState);
   
   // ../android/app/Instrumentation.java  
   public void callActivityOnCreate(Activity activity, Bundle icicle) {
           prePerformCreate(activity);
           activity.performCreate(icicle);
           postPerformCreate(activity);
       }
   
   // ../android/app/Activity.java
   final void performCreate(Bundle icicle) {
           restoreHasCurrentPermissionRequest(icicle);
           onCreate(icicle);
           mActivityTransitionState.readState(icicle);
           performCreateCommon();
       }
   ```

   最终调用到`Activity.performCreate()`，后续调用到`Activity.onCreate()`，这时根Activity就启动了，完成了整个启动流程。
   需要注意的是，生命周期进入`onCreate()`不等于页面已经可见，首帧展示还要等待后续恢复与绘制合成完成。

![ActivityThread启动Activity过程](/images/ActivityThread启动Activity过程.png)

### 根Activity启动过程中涉及的进程

根Activity启动过程中涉及四个进程：**Zygote进程、Launcher进程、AMS所在进程（System Server进程），应用程序进程。**



![根启动Activity过程中的进程切换](/images/根启动Activity过程中的进程切换.png)

> 首先`Launcher进程`会向`AMS`发起`创建根Activity请求`，`AMS`会判断根Activity所需的应用程序进程是否存在并处于启动状态
>
> - `未启动`：请求`Zygote进程`创建应用程序进程
> - `已启动`：`AMS`直接启动Activity

### 根Activity关键数据结构（补充）

启动链路里最常见的几个结构体职责如下：

| 数据结构 | 所在侧 | 作用 |
| --- | --- | --- |
| `ProcessRecord` | System Server | 描述应用进程状态（pid、uid、组件状态、adj等） |
| `ActivityRecord` | System Server | 描述单个 Activity 的生命周期与调度状态 |
| `TaskRecord` | System Server | 描述任务栈（Task）及其栈内关系 |
| `ActivityClientRecord` | App 进程 | 应用侧启动参数快照，供`ActivityThread`创建 Activity |

把这四个对象串起来，就能更容易理解“系统侧调度”与“应用侧创建”的分工。

###  总结

经过上述章节的描述，可以基本厘清`根Activity的启动过程`

> 当我们按下桌面上的应用程序快捷启动方式时，`Launcher`会调用`Activity.startActivity()`并设置启动FLAG为`FLAG_ACTIVITY_NEW_TASK`给根Activity设置任务栈，实质上是调用`Instrumentation.execStartActivity()`尝试启动Activity，这是一个跨进程的过程，利用`IActivityManager`与`AMS`进行通信。
>
> `AMS`就会记录下要启动的Activity信息，并且跨进程通知Launcher进入`pause`状态，`Launcher`进入`pause`状态后，跨进程通知`AMS`自己已被`pause`。`AMS`会回调用自身的`startActivty()`去继续启动根Activity，这一步需要校验(调用者是否有权限调用)，检验通过后，发现此时应用进程尚未启动，`AMS`就会启动新的进程，并且在新进程中创建`ActivityThread`对象并执行`main()`进程初始化。
>
> 应用进程启动完毕后，`AMS`通知主线程绑定`Application`并启动根Activity。这时`AMS`会通过`ApplicationThread`回调到我们的进程，这一步也是一个跨进程的过程，利用`ApplicationThread`这个Binder对象。由于回调逻辑是在`Binder线程池`中进行的，所以需要通过`Handler H`将其切回主线程，发出的消息是`LAUNCH_ACTIVITY`，对应调用`handleLaunchActivity`，在这个方法中完成了根Activity的创建以及启动。接着在`handleResumeActivity()`中开始Activity的内容绘制，直到绘制完成被我们看见。

#### 启动耗时观察点（补充）

- 进程创建阶段：是否触发`startProcessLocked`，是否等待Zygote拉起。
- 主线程阶段：`bindApplication`、`handleLaunchActivity`中是否有阻塞初始化。
- 渲染阶段：`onResume`到首帧可见之间是否出现绘制/合成延迟。

## 普通Activity启动过程



![普通Activity启动过程](/images/普通Activity启动过程.png)

> 普通Activity启动过程相比于根Activity启动过程，只保留了两步：`AMS到Application的调用过程`,`ActivityThread启动Activity过程`。
>
> 涉及的进程也只剩：`AMS所在进程(System Server进程)，应用程序进程`。

### 普通Activity与根Activity差异矩阵（补充）

| 对比项 | 根Activity启动 | 普通Activity启动（同进程） |
| --- | --- | --- |
| 是否需要新建进程 | 可能需要（冷启动场景） | 一般不需要 |
| 是否执行`bindApplication` | 冷启动会执行 | 通常不执行 |
| 是否经过 Zygote | 冷启动会经过 | 不经过 |
| 核心跨进程链路 | Launcher -> AMS -> App | App -> AMS -> App |
| 应用侧创建入口 | `LAUNCH_ACTIVITY` | `LAUNCH_ACTIVITY` |

可以看出两者后半段（应用侧创建 Activity）高度一致，差异主要集中在前半段的“进程准备与运行时绑定”。

### 相同进程的启动过程

> 例如LoadingActivity -> MainActivity

1. LoadingActivity组件会向`AMS`发送一个启动MainActivity的请求，其实就是内部通过`Instrumentation`尝试启动Activity(`execStartActivity`)，这是一个跨进程过程，会调用`AMS`的`startActivity()`
2. `AMS`会保存下来`MainActivity`的组件信息，然后向`LoadingActivity`发送一个进入中止状态的进程间通信请求。*这也就是为什么老Activity的`onPause()`会执行在新Activity的启动之前的原因。*
3. `LoadingActivity`进入中止状态后会通知到`AMS`继续向下执行`MainActivity`的启动，由于发现应用进程已经存在，所以`AMS`直接通过`ApplicationThread`回调到应用进程，这也是一个跨进程过程。
4. 由于`ApplicationThread`是一个Binder对象，回调逻辑在`Binder线程池`中完成，需要通过`Handler H`切回到主线程，并发出`LAUNCH_ACTIVITY`消息，对应调用`handleLaunchActivity`。
5. 继续向下完成`MainActivity`的创建和启动，然后在`handleResumeActivity()`中完成View的绘制，直到绘制完成展示在用户面前结束。

### 新进程的启动过程

> 例如LoadingActivity -> MainActivity设置了`android:process=":remote"`
>
> 类似根Activity的启动过程，不过起始点是从`LoadingActivity`开始

1. LoadingActivity组件会向`AMS`发送一个启动MainActivity的请求，其实就是内部通过`Instrumentation`尝试启动Activity(`execStartActivity`)，这是一个跨进程过程，会调用`AMS`的`startActivity()`
2. `AMS`会保存下来`MainActivity`的组件信息，然后向`LoadingActivity`发送一个进入中止状态的进程间通信请求。*这也就是为什么老Activity的`onPause()`会执行在新Activity的启动之前的原因。*
3. `LoadingActivity`进入中止状态后会通知到`AMS`继续向下执行`MainActivity`的启动，此时发现用来运行的`:remote`进程不存在，就会调用`AMS`去启动新的应用进程，并且在新进程中创建`ActrivityThread(*主进程*)`并执行`main()`进行初始化。
4. 应用进程启动完毕之后，向`AMS`发送一个启动完成的请求，`AMS`就会通知主线程`ActivityThread`去创建并绑定`Application`，绑定完成后，通知`AMS`绑定完成。`AMS`直接通过`ApplicationThread`回调到应用进程，这也是一个跨进程过程。
5. 由于`ApplicationThread`是一个Binder对象，回调逻辑在`Binder线程池`中完成，需要通过`Handler H`切回到主线程，并发出`LAUNCH_ACTIVITY`消息，对应调用`handleLaunchActivity`。
6. <!--App启动优化，如何检测启动耗时 -->

### 版本差异映射（Android 10+）（补充）

本文主线是 Android 8.0，后续版本中类职责有迁移，阅读源码时可按以下映射理解：

- `AMS`中的 Activity/Task 调度职责逐步拆分到`ATMS(ActivityTaskManagerService)`。
- 任务栈与窗口管理的协作更紧密，更多逻辑由 WindowManager 侧结构承接。
- 启动窗口与系统过渡动画机制在新版本中不断加强，冷启动视觉链路与 8.0 有明显差异。

建议阅读新版本源码时，先按“职责迁移”定位类，再回到具体方法链。

### 启动链路观察点（补充）

为了验证启动时序，建议固定观察以下关键点：

1. 系统侧：`ActivityTaskManager/ActivityManager`相关日志中的`startActivity/attachApplication`。
2. 应用侧：`ActivityThread`的`BIND_APPLICATION`与`LAUNCH_ACTIVITY`消息时序。
3. 生命周期：`Application.onCreate -> Activity.onCreate/onStart/onResume`的先后。
4. 首帧：`onResume`之后到首帧可见之间的渲染耗时区间。

用同一套观察点反复验证，能更稳定地定位“慢在调度侧还是慢在应用侧”。





临时记录：

Andorid 9.0 源码添加了Sleeping状态，功能类似Stop

handleSleeping() 可能导致 onSaveInstanceState()存储异常
