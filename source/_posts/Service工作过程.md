---
title: Service工作过程
date: 2019-01-10 11:53:00
tags: Android
top: 11
---


## Service工作过程

Service分为两种工作状态，一种是`启动状态`，主要用于执行后台计算；另一种是`绑定状态`，主要用于其他组件和Service的交互。

Service的这两种状态是可以共存的，即Service既可以处于启动状态也可以同时处于绑定状态。

```java
//启动Service
Intent intent= new Intent(this,MyService.class);
startService(intent);

//绑定Service
Intent intent= new Intent(this,MyService.class);
bindService(intent,mServiceConnection,BIND_AUTO_CREATE);
```

### Service启动过程 - startService

Service的启动过程从`ContextWrapper.startService()`开始

```java
// ../android/content/ContextWrapper.java
    Context mBase;
    @Override
    public ComponentName startService(Intent service) {
        return mBase.startService(service);
    }
```

在Activity启动的`performLaunchActivity`阶段，会创建上下文对象`Context`，然后在`Activity.attach()`调用`attachBaseContext()`完成context赋值。最终操作的是`ContextImpl`。

```java
// ../android/app/ContextImpl.java
    @Override
    public ComponentName startService(Intent service) {
        warnIfCallingFromSystemProcess();
        return startServiceCommon(service, false, mUser);
    }

    private ComponentName startServiceCommon(Intent service, boolean requireForeground,
            UserHandle user) {
        try {
            validateServiceIntent(service);
            service.prepareToLeaveProcess(this);
            //启动Service
            ComponentName cn = ActivityManager.getService().startService(
                mMainThread.getApplicationThread(), service, service.resolveTypeIfNeeded(
                            getContentResolver()), requireForeground,
                            getOpPackageName(), user.getIdentifier());
            if (cn != null) {
                 ...
            }
            return cn;
        } catch (RemoteException e) {
            throw e.rethrowFromSystemServer();
        }
    }
```

`ActivityManager.getService()`在Activity启动过程中有介绍，它拿到的是`IActivityManager`，实际指向`AMS`的一个Binder代理对象，随后调用`AMS.startService()`。

> 主链路：`ContextImpl.startServiceCommon() -> AMS.startService() -> ActiveServices.startServiceLocked() -> bringUpServiceLocked() -> realStartServiceLocked() -> ActivityThread.handleCreateService()`

```java
// ../core/java/com/android/server/am/ActivityManagerService.java
    @Override
    public ComponentName startService(IApplicationThread caller, Intent service,
            String resolvedType, boolean requireForeground, String callingPackage, int userId)
            throws TransactionTooLargeException {
        enforceNotIsolatedCaller("startService");
        // Refuse possible leaked file descriptors
        if (service != null && service.hasFileDescriptors() == true) {
            throw new IllegalArgumentException("File descriptors passed in Intent");
        }

        if (callingPackage == null) {
            throw new IllegalArgumentException("callingPackage cannot be null");
        }

        if (DEBUG_SERVICE) Slog.v(TAG_SERVICE,
                "*** startService: " + service + " type=" + resolvedType + " fg=" + requireForeground);
        synchronized(this) {
            final int callingPid = Binder.getCallingPid();
            final int callingUid = Binder.getCallingUid();
            final long origId = Binder.clearCallingIdentity();
            ComponentName res;
            try {
                res = mServices.startServiceLocked(caller, service,
                        resolvedType, callingPid, callingUid,
                        requireForeground, callingPackage, userId);
            } finally {
                Binder.restoreCallingIdentity(origId);
            }
            return res;
        }
    }


```

`mServices`的类型是`ActiveServices`.*`ActiveServices`是一个辅助`AMS`进行Service管理的类，其中包括Service的启动，绑定和停止等功能。*

```java
// ../core/java/com/android/server/am/ActiveServices.java
ComponentName startServiceLocked(IApplicationThread caller, Intent service, String resolvedType,
            int callingPid, int callingUid, boolean fgRequired, String callingPackage, final int userId)
            throws TransactionTooLargeException {
   ...
        //去查找是否有与参数 service 对应的ServiceRecord。
        ServiceLookupResult res =
            retrieveServiceLocked(service, resolvedType, callingPackage,
                    callingPid, callingUid, userId, true, callerFg, false);
        if (res == null) {
            return null;
        }
        if (res.record == null) {
            return new ComponentName("!", res.permission != null
                    ? res.permission : "private to package");
        }
        //封装一个ServiceRecord对象
        ServiceRecord r = res.record;
   ...
     
     ComponentName cmp = startServiceInnerLocked(smap, service, r, callerFg, addToStarting);
 }
```

`ServiceRecord`描述的是一个Service记录，一直贯穿着整个Service的启动过程。

```java
    ComponentName startServiceInnerLocked(ServiceMap smap, Intent service, ServiceRecord r,
            boolean callerFg, boolean addToStarting) throws TransactionTooLargeException {
        ...
        String error = bringUpServiceLocked(r, service.getFlags(), callerFg, false, false);
        if (error != null) {
            return new ComponentName("!!", error);
        }

        ...

        return r.name;
    }

    private String bringUpServiceLocked(ServiceRecord r, int intentFlags, boolean execInFg,
            boolean whileRestarting, boolean permissionsReviewRequired)
            throws TransactionTooLargeException {
      ...
        //获取Service想在那个进程中运行  process
        final String procName = r.processName;
        String hostingType = "service";
        ProcessRecord app;
        //当前不止一个进程
        if (!isolated) {
            //查询是否存在一个 与Service类型对应的ProcessRecord对象的app进程
            app = mAm.getProcessRecordLocked(procName, r.appInfo.uid, false);
            if (DEBUG_MU) Slog.v(TAG_MU, "bringUpServiceLocked: appInfo.uid=" + r.appInfo.uid
                        + " app=" + app);
            //Service的运行进程已经存在
            if (app != null && app.thread != null) {
                try {
                    app.addPackage(r.appInfo.packageName, r.appInfo.versionCode, mAm.mProcessStats);
                    //启动service
                    realStartServiceLocked(r, app, execInFg);
                    return null;
                } catch (TransactionTooLargeException e) {
                    throw e;
                } catch (RemoteException e) {
                    Slog.w(TAG, "Exception when starting service " + r.shortName, e);
                }
            }
        } else {
            app = r.isolatedProc;
            if (WebViewZygote.isMultiprocessEnabled()
                    && r.serviceInfo.packageName.equals(WebViewZygote.getPackageName())) {
                hostingType = "webview_service";
            }
        }

        //没有对应的运行进程启动
        if (app == null && !permissionsReviewRequired) {
            //需要新启动一个应用进程 承载Service
            if ((app=mAm.startProcessLocked(procName, r.appInfo, true, intentFlags,
                    hostingType, r.name, false, isolated, false)) == null) {
                String msg = "Unable to launch app "
                        + r.appInfo.packageName + "/"
                        + r.appInfo.uid + " for service "
                        + r.intent.getIntent() + ": process is bad";
                Slog.w(TAG, msg);
                bringDownServiceLocked(r);
                return msg;
            }
            if (isolated) {
                r.isolatedProc = app;
            }
        }
      ...
    }
```

在`bringUpServiceLocked()`中，优先获取`Service需要的运行进程--通过android:process设置`，然后去判断当前进程中是否存在符合要求的

- 不存在，调用`AMS.startProcessLocked()`去新建对应应用进程，这个函数在Activity启动过程中有讲解
- 存在，直接调用`realStartServiceLocked()`去启动Service，*命名方法类似Activity启动过程中的`realStartActivityLocked()`*

```java
    private final void realStartServiceLocked(ServiceRecord r,
            ProcessRecord app, boolean execInFg) throws RemoteException {
      ...
        boolean created = false;
        try {
          ...
            app.thread.scheduleCreateService(r, r.serviceInfo,
                    mAm.compatibilityInfoForPackageLocked(r.serviceInfo.applicationInfo),
                    app.repProcState);
            r.postNotification();
            created = true;
        } catch (DeadObjectException e) {
            Slog.w(TAG, "Application dead when creating service " + r);
            mAm.appDiedLocked(app);
            throw e;
        } finally {
            if (!created) {
                // Keep the executeNesting count accurate.
                final boolean inDestroying = mDestroyingServices.contains(r);
                serviceDoneExecutingLocked(r, inDestroying, inDestroying);

                // Cleanup.
                if (newService) {
                    app.services.remove(r);
                    r.app = null;
                }

                // Retry.
                if (!inDestroying) {
                    scheduleServiceRestartLocked(r, false);
                }
            }
        }
      
      ...
        //由于 必须startRequested 参数为true
        if (r.startRequested && r.callStart && r.pendingStarts.size() == 0) {
            r.pendingStarts.add(new ServiceRecord.StartItem(r, false, r.makeNextStartId(),
                    null, null, 0));
        }
        //调用Service中的其他方法，例如 onStartCommand
        sendServiceArgsLocked(r, execInFg, true);

    }


    private final void sendServiceArgsLocked(ServiceRecord r, boolean execInFg,
            boolean oomAdjusted) throws TransactionTooLargeException {
      ...
        //通知ActivityThread初始化已经完成，然后调用后续方法
        r.app.thread.scheduleServiceArgs(r, slice);
      ...
    }
```

`app.thread`是`IApplicationThread`类型的，实际上是一个Binder对象，它的实现是`ApplicationThread`，用于和`ActivityThread`进行通信。

```java
// ../android/app/ActivityThread.java       
public final void scheduleCreateService(IBinder token,
                ServiceInfo info, CompatibilityInfo compatInfo, int processState) {
            updateProcessState(processState, false);
            CreateServiceData s = new CreateServiceData();
            s.token = token;
            s.info = info;
            s.compatInfo = compatInfo;

            sendMessage(H.CREATE_SERVICE, s);
        }
```

这里与`Activity启动过程`是一致的，通过`ActivityThread.H`这个Handler对象发送消息，切换到主线程去处理消息。这个发送的是`CREATE_SERVICE`，最后调用到了`ActivityThread.handleCreateService()`去启动Service

```java
final ArrayMap<IBinder, Service> mServices = new ArrayMap<>();    
private void handleCreateService(CreateServiceData data) {
        // If we are getting ready to gc after going to the background, well
        // we are back active so skip it.
        unscheduleGcIdler();
        //获取LoadedApk对象，是一个Apk文件的描述器
        LoadedApk packageInfo = getPackageInfoNoCheck(
                data.info.applicationInfo, data.compatInfo);
        Service service = null;
        try {
            java.lang.ClassLoader cl = packageInfo.getClassLoader();
            service = (Service) cl.loadClass(data.info.name).newInstance();
        } catch (Exception e) {
            if (!mInstrumentation.onException(service, e)) {
                throw new RuntimeException(
                    "Unable to instantiate service " + data.info.name
                    + ": " + e.toString(), e);
            }
        }

        try {
            if (localLOGV) Slog.v(TAG, "Creating service " + data.info.name);
            //创建Service的ContextImpl对象
            ContextImpl context = ContextImpl.createAppContext(this, packageInfo);
            context.setOuterContext(service);

            Application app = packageInfo.makeApplication(false, mInstrumentation);
            //初始化Service
            service.attach(context, this, data.info.name, data.token, app,
                    ActivityManager.getService());
            //调用 onCreate 生命周期
            service.onCreate();
            mServices.put(data.token, service);
            try {
                ActivityManager.getService().serviceDoneExecuting(
                        data.token, SERVICE_DONE_EXECUTING_ANON, 0, 0);
            } catch (RemoteException e) {
                throw e.rethrowFromSystemServer();
            }
        } catch (Exception e) {
            if (!mInstrumentation.onException(service, e)) {
                throw new RuntimeException(
                    "Unable to create service " + data.info.name
                    + ": " + e.toString(), e);
            }
        }
    }

```

`handleCreateService()`执行了以下几件事：

- 通过类加载器创建`Service`实例，*Activity启动过程是利用`Instrumentation.newActivity()`执行类似的实例化逻辑*
- `makeApplication()`创建`Application`对象并调用其`onCreate`
- 创建`ContextImpl`对象并调用`Service.attach()`建立关系
- 最后调用`Service.onCreate()`开始创建过程，并存储至`ArrayMap<IBinder,Service>`中，在下一节会介绍这里存储数据的作用
- 调用`onCreate()`后，若是`startService`路径会继续走`onStartCommand()`；若是纯`bindService`路径则不会触发`onStartCommand()`。

#### startId与stopSelf(startId)

`startService`每到一次`onStartCommand()`，系统都会分配一个递增`startId`。这意味着：

- 多次`startService`会多次回调`onStartCommand()`。
- 任务并发时建议使用`stopSelf(startId)`，避免旧任务提前结束Service。
- 仅调用`stopSelf()`在竞态下可能误停尚未处理完的新请求。

{% fullimage /images/Service启动过程.png,Service启动过程,Service启动过程%}

### Service绑定过程 - bindService

和Service的启动过程一样，Service的绑定过程也是从`ContextWrapper`开始

```java
// ../android/content/ContextWrapper.java    
@Override
    public boolean bindService(Intent service, ServiceConnection conn,
            int flags) {
        return mBase.bindService(service, conn, flags);
    }
```

```java
// ../android/app/ContextImpl.java
    @Override
    public boolean bindService(Intent service, ServiceConnection conn,
            int flags) {
        warnIfCallingFromSystemProcess();
        return bindServiceCommon(service, conn, flags, mMainThread.getHandler(),
                Process.myUserHandle());
    }

    private boolean bindServiceCommon(Intent service, ServiceConnection conn, int flags, Handler
            handler, UserHandle user) {
        IServiceConnection sd;
        if (conn == null) {
            throw new IllegalArgumentException("connection is null");
        }
        if (mPackageInfo != null) {
            sd = mPackageInfo.getServiceDispatcher(conn, getOuterContext(), handler, flags);
        } else {
            throw new RuntimeException("Not supported in system context");
        }
        validateServiceIntent(service);
        try {
           ...
            service.prepareToLeaveProcess(this);
            int res = ActivityManager.getService().bindService(
                mMainThread.getApplicationThread(), getActivityToken(), service,
                service.resolveTypeIfNeeded(getContentResolver()),
                sd, flags, getOpPackageName(), user.getIdentifier());
            if (res < 0) {
                throw new SecurityException(
                        "Not allowed to bind to service " + service);
            }
            return res != 0;
        } catch (RemoteException e) {
            throw e.rethrowFromSystemServer();
        }
    }

```

在`bindServiceCommon()`主要做了两件事情：

> 主链路：`ContextImpl.bindServiceCommon() -> AMS.bindService() -> ActiveServices.bindServiceLocked() -> requestServiceBindingLocked() -> ActivityThread.handleBindService()`

- `getServiceDispatcher()` 将传进来的`ServiceConnection`转化成`IServiceConnection`，通过Binder对象进行通信。使得Service的绑定支持跨进程调用。

  ```java
  // ../android/app/LoadedApk.java    
  public final IServiceConnection getServiceDispatcher(ServiceConnection c,
              Context context, Handler handler, int flags) {
          synchronized (mServices) {
              LoadedApk.ServiceDispatcher sd = null;
              ArrayMap<ServiceConnection, LoadedApk.ServiceDispatcher> map = mServices.get(context);
              if (map != null) {
                  if (DEBUG) Slog.d(TAG, "Returning existing dispatcher " + sd + " for conn " + c);
                  sd = map.get(c);
              }
              if (sd == null) {
                  sd = new ServiceDispatcher(c, context, handler, flags);
                  if (DEBUG) Slog.d(TAG, "Creating new dispatcher " + sd + " for conn " + c);
                  if (map == null) {
                      map = new ArrayMap<>();
                      mServices.put(context, map);
                  }
                  map.put(c, sd);
              } else {
                  sd.validate(context, handler);
              }
              return sd.getIServiceConnection();
          }
      }
  ```

  `mServices`存储了一个应用当前活动的`ServiceConnection和ServiceDispatcher`的映射关系。`ServiceDispatcher`的作用是*连接ServiceConnection和IServiceConnection。*

- `bindService()`开始Service的绑定流程

  ```java
  // ../core/java/com/android/server/am/ActivityManagerService.java
      public int bindService(IApplicationThread caller, IBinder token, Intent service,
              String resolvedType, IServiceConnection connection, int flags, String callingPackage,
              int userId) throws TransactionTooLargeException {
          enforceNotIsolatedCaller("bindService");
  
          // Refuse possible leaked file descriptors
          if (service != null && service.hasFileDescriptors() == true) {
              throw new IllegalArgumentException("File descriptors passed in Intent");
          }
  
          if (callingPackage == null) {
              throw new IllegalArgumentException("callingPackage cannot be null");
          }
  
          synchronized(this) {
              return mServices.bindServiceLocked(caller, token, service,
                      resolvedType, connection, flags, callingPackage, userId);
          }
      }
  
  ```

存储好对应的`ServiceConnection`和`ServiceDispatcher`映射的关系，之后开始继续绑定流程

```java
// ../core/java/com/android/server/am/ActiveServices.java
    int bindServiceLocked(IApplicationThread caller, IBinder token, Intent service,
            String resolvedType, final IServiceConnection connection, int flags,
            String callingPackage, final int userId) throws TransactionTooLargeException {
        // 获取应用进程信息  
        final ProcessRecord callerApp = mAm.getRecordForAppLocked(caller);
        if (callerApp == null) {
            throw new SecurityException(
                    "Unable to find app for caller " + caller
                    + " (pid=" + Binder.getCallingPid()
                    + ") when binding service " + service);
        }
        //获取绑定Activity信息
        ActivityRecord activity = null;
        if (token != null) {
            activity = ActivityRecord.isInStackLocked(token);
            if (activity == null) {
                Slog.w(TAG, "Binding with unknown activity: " + token);
                return 0;
            }
        }
        //获取Service相关信息
        ServiceRecord s = res.record;
        //启动Activity成功后 ，再启动Service
        if (mAm.mPermissionReviewRequired) {
            if (mAm.getPackageManagerInternalLocked().isPermissionsReviewRequired(
                    s.packageName, s.userId)) {
              RemoteCallback callback = new RemoteCallback(
                        new RemoteCallback.OnResultListener() {
                    @Override
                    public void onResult(Bundle result) {
                        synchronized(mAm) {
                            final long identity = Binder.clearCallingIdentity();
                            try {
                                ...
                                if (...) {
                                    try {
                                        // 启动 Service
                                        bringUpServiceLocked(...);
                                    } catch (RemoteException e) {
                                        /* ignore - local call */
                                    }
                                } else {
                                    ...
                                }
                            } finally {
                                ...
                            }
                        }
                    }
                });

                final Intent intent = new Intent(Intent.ACTION_REVIEW_PERMISSIONS);
                // 注意 callback
                intent.putExtra(Intent.EXTRA_REMOTE_CALLBACK, callback);
                
                // 启动 Activity，成功启动后回调 callback 
                mAm.mHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        mAm.mContext.startActivityAsUser(intent, new UserHandle(userId));
                    }
                });
            }
        }
      try{
        // 如果设置了绑定后自动启动
        if ((flags&Context.BIND_AUTO_CREATE) != 0) { 
                s.lastActivity = SystemClock.uptimeMillis();
                // 启动 Service
                if (bringUpServiceLocked(s, service.getFlags(), callerFg, false,
                        permissionsReviewRequired) != null) {
                    return 0;
                }
           }
            // Service 已经在运行中，直接回调 onServiceConnected 即可
            if (s.app != null && b.intent.received) { 
                // Service is already running, so we can immediately
                // publish the connection.
                try {
                    // 回调 onServiceConnected
                    c.conn.connected(s.name, b.intent.binder, false);
                } catch (Exception e) {
                    ...
                }
                //
                if (b.intent.apps.size() == 1 && b.intent.doRebind) {
                    requestServiceBindingLocked(s, b.intent, callerFg, true);
                }
                ...
                  //没有进行过绑定Service请求
            } else if (!b.intent.requested) { 
                // 回调 onBind，内部调用了 scheduleBindService
                requestServiceBindingLocked(s, b.intent, callerFg, false);
            }
        ...
      } finally {
         Binder.restoreCallingIdentity(origId);
      }
      return 1;
    }
```

> 介绍几个与Service有关的对象类型：
>
> - ServiceRecord：描述一个Service
> - ProcessRecord：描述一个进程的信息
> - ConnectionRecord：描述应用程序进程和Service建立的一次通信。
> - AppBindRecord：维护Service与应用程序进程之间的关联。
> - IntentBindRecord：描述绑定Service的Intent

`bindServiceLocked()`内部会通过`bringUpServiceLocked()`自动启动Service。然后向下走`启动Service流程`。

还会多调用一个`requestServiceBindingLocked()`请求绑定过程

```java
// ../core/java/com/android/server/am/ActiveServices.java
    private final boolean requestServiceBindingLocked(ServiceRecord r, IntentBindRecord i,
            boolean execInFg, boolean rebind/*是否重新绑定*/) throws TransactionTooLargeException {
        if (r.app == null || r.app.thread == null) {
            // If service is not currently running, can't yet bind.
            return false;
        }
        if (DEBUG_SERVICE) Slog.d(TAG_SERVICE, "requestBind " + i + ": requested=" + i.requested
                + " rebind=" + rebind);
        //是否发送过 绑定Service的请求 
        if ((!i.requested || rebind) && i.apps.size() > 0) {
            try {
                bumpServiceExecutingLocked(r, execInFg, "bind");
                r.app.forceProcessStateUpTo(ActivityManager.PROCESS_STATE_SERVICE);
                r.app.thread.scheduleBindService(r, i.intent.getIntent(), rebind,
                        r.app.repProcState);
                if (!rebind) {
                    i.requested = true;
                }
                i.hasBound = true;
                i.doRebind = false;
            } catch (... ) {//最大通常限制为1M.
               ...
            }
        }
        return true;
    }
```

`app.thread`把逻辑切换到了 `ActivityThread`中了

```java
// ../android/app/ActivityThread.java       
public final void scheduleBindService(IBinder token, Intent intent,
                boolean rebind, int processState) {
            updateProcessState(processState, false);
            BindServiceData s = new BindServiceData();
            s.token = token;
            s.intent = intent;
            s.rebind = rebind;

            if (DEBUG_SERVICE)
                Slog.v(TAG, "scheduleBindService token=" + token + " intent=" + intent + " uid="
                        + Binder.getCallingUid() + " pid=" + Binder.getCallingPid());
            sendMessage(H.BIND_SERVICE, s);
        }

// 处理绑定Service流程
private void handleBindService(BindServiceData data) {
        //获取要绑定的Service对象
        Service s = mServices.get(data.token);
        if (DEBUG_SERVICE)
            Slog.v(TAG, "handleBindService s=" + s + " rebind=" + data.rebind);
        if (s != null) {
            try {
                data.intent.setExtrasClassLoader(s.getClassLoader());
                data.intent.prepareToEnterProcess();
                try {
                   //绑定Service
                    if (!data.rebind) {
                        //调用 onBind 方法，此时已绑定Service
                        IBinder binder = s.onBind(data.intent);
                        //通知绑定成功
                        ActivityManager.getService().publishService(
                                data.token, data.intent, binder);
                    } else {
                        //执行重新绑定流程
                        s.onRebind(data.intent);
                        ActivityManager.getService().serviceDoneExecuting(
                                data.token, SERVICE_DONE_EXECUTING_ANON, 0, 0);
                    }
                    ensureJitEnabled();
                } catch (RemoteException ex) {
                    throw ex.rethrowFromSystemServer();
                }
            } catch (Exception e) {
                if (!mInstrumentation.onException(s, e)) {
                    throw new RuntimeException(
                            "Unable to bind to service " + s
                            + " with " + data.intent + ": " + e.toString(), e);
                }
            }
        }
    }
```

> `Service.onRebind()`执行条件为：前一次`onUnbind()`返回`true`，并且后续再次发生绑定。常见场景是先`startService()`再`bindService()`，页面退出后Service仍存活，后续页面再次`bindService()`会触发`onRebind()`。
>
> **当多次绑定同一个Service时，`onBind()`只会执行一次，除非Service被终止。**

{% fullimage /images/Service绑定过程.png,Service绑定过程,Service绑定过程%}

#### Service绑定通知

发现Service未绑定时，就会调用到`onBind()`，Service就处于绑定状态，但是客户端无法感知到Service已经连接成功，所以需要`AMS`进行通知。

```java
// ../core/java/com/android/server/am/ActivityManagerService.java
    public void publishService(IBinder token, Intent intent, IBinder service) {
        // Refuse possible leaked file descriptors
        if (intent != null && intent.hasFileDescriptors() == true) {
            throw new IllegalArgumentException("File descriptors passed in Intent");
        }

        synchronized(this) {
            if (!(token instanceof ServiceRecord)) {
                throw new IllegalArgumentException("Invalid service token");
            }
            mServices.publishServiceLocked((ServiceRecord)token, intent, service);
        }
    }


```

`mServices`就是`ActiveServices`对象，调用其内部的`publishServiceLocked()`

```java
// ../core/java/com/android/server/am/ActiveServices.java
void publishServiceLocked(ServiceRecord r, Intent intent, IBinder service) {
        final long origId = Binder.clearCallingIdentity();
        try {
             ...
                    for (int conni=r.connections.size()-1; conni>=0; conni--) {
                        ArrayList<ConnectionRecord> clist = r.connections.valueAt(conni);
                        for (int i=0; i<clist.size(); i++) {
                            ConnectionRecord c = clist.get(i);
                            try {
                                c.conn.connected(r.name, service, false);
                            } catch (Exception e) {
                                Slog.w(TAG, "Failure sending service " + r.name +
                                      " to connection " + c.conn.asBinder() +
                                      " (in " + c.binding.client.processName + ")", e);
                            }
                        }
                    }
                }

                serviceDoneExecutingLocked(r, mDestroyingServices.contains(r), false);
            }
        } finally {
            Binder.restoreCallingIdentity(origId);
        }
    }
```

`c.conn`指向`IServiceConnection`，它是`ServiceConnection`在本地的代理对象，用于解决当前应用程序进程和Service跨进程通信的问题。

它的具体实现为`ServiceDispatcher.InnerConnection`。

```java
// ../android/app/LoadedApk.java
static final class ServiceDispatcher {
 ...
        private static class InnerConnection extends IServiceConnection.Stub {
            final WeakReference<LoadedApk.ServiceDispatcher> mDispatcher;

            InnerConnection(LoadedApk.ServiceDispatcher sd) {
                mDispatcher = new WeakReference<LoadedApk.ServiceDispatcher>(sd);
            }

            public void connected(ComponentName name, IBinder service, boolean dead)
                    throws RemoteException {
                LoadedApk.ServiceDispatcher sd = mDispatcher.get();
                if (sd != null) {
                    sd.connected(name, service, dead);
                }
            }
        }
  
        public void connected(ComponentName name, IBinder service, boolean dead) {
            if (mActivityThread != null) {
                mActivityThread.post(new RunConnection(name, service, 0, dead));
            } else {
                doConnected(name, service, dead);
            }
        }
  
  			...
}
```

`mActivityThread`是一个Handler对象，指向的就是`ActivityThread.H`。因此可以通过调用`post()`将`RunConnection`切换到主线程执行。

```java
private final class RunConnection implements Runnable {
            RunConnection(ComponentName name, IBinder service, int command, boolean dead) {
                mName = name;
                mService = service;
                mCommand = command;
                mDead = dead;
            }

            public void run() {
                if (mCommand == 0) {
                    doConnected(mName, mService, mDead);
                } else if (mCommand == 1) {
                    doDeath(mName, mService);
                }
            }

            final ComponentName mName;
            final IBinder mService;
            final int mCommand;
            final boolean mDead;
        }
```

调用了`RunConnection`实际上还是调用了`doConnected()`

```java
ServiceConnection mConnection;
public void doConnected(ComponentName name, IBinder service, boolean dead) {
            ServiceDispatcher.ConnectionInfo old;
            ServiceDispatcher.ConnectionInfo info;

            synchronized (this) {
            ...
            // 如果存在老Service 会优先断掉连接
            if (old != null) {
                mConnection.onServiceDisconnected(name);
            }
            // Service已消失 死亡回调
            if (dead) {
                mConnection.onBindingDied(name);
            }
            // 全新的Service 通知绑定成功
            if (service != null) {
                mConnection.onServiceConnected(name, service);
            }
        }
```

```java
//使用场景 
private ServiceConnection mConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
           //绑定成功回调
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            
        }
    };
```

<!-- 为什么bindService不会触发onStartCommand -->



### Service解绑过程 - unbindService()

Service的解绑过程也是从`ContextWrapper`开始

> 主链路：`ContextImpl.unbindService() -> AMS.unbindService() -> ActiveServices.unbindServiceLocked() -> removeConnectionLocked() -> ActivityThread.handleUnbindService()`

```java
    @Override
    public void unbindService(ServiceConnection conn) {
        mBase.unbindService(conn);
    }
```

实际调用的是`ContextImpl.unbindService()`

```java
// ../android/app/ContextImpl.java
    @Override
    public void unbindService(ServiceConnection conn) {
        if (conn == null) {
            throw new IllegalArgumentException("connection is null");
        }
        if (mPackageInfo != null) {
            IServiceConnection sd = mPackageInfo.forgetServiceDispatcher(
                    getOuterContext(), conn);
            try {
                ActivityManager.getService().unbindService(sd);
            } catch (RemoteException e) {
                throw e.rethrowFromSystemServer();
            }
        } else {
            throw new RuntimeException("Not supported in system context");
        }
    }
```

这里主要分为两部分：

- `LoadedApk.forgetServiceDispatcher()`

  ```java
  // ../android/app/LoadedApk.java
  public final IServiceConnection forgetServiceDispatcher(Context context,
              ServiceConnection c) {
          synchronized (mServices) {
              //获取当前存储的ServiceConnection
              ArrayMap<ServiceConnection, LoadedApk.ServiceDispatcher> map
                      = mServices.get(context);
              LoadedApk.ServiceDispatcher sd = null;
              if (map != null) {
                  //获取对应的ServiceDispatcher
                  sd = map.get(c);
                  if (sd != null) {
                      if (DEBUG) Slog.d(TAG, "Removing dispatcher " + sd + " for conn " + c);
                      map.remove(c);
                      sd.doForget();
                      if (map.size() == 0) {
                          mServices.remove(context);
                      }
                      if ((sd.getFlags()&Context.BIND_DEBUG_UNBIND) != 0) {
                          ArrayMap<ServiceConnection, LoadedApk.ServiceDispatcher> holder
                                  = mUnboundServices.get(context);
                          if (holder == null) {
                              holder = new ArrayMap<ServiceConnection, LoadedApk.ServiceDispatcher>();
                              mUnboundServices.put(context, holder);
                          }
                          RuntimeException ex = new IllegalArgumentException(
                                  "Originally unbound here:");
                          ex.fillInStackTrace();
                          sd.setUnbindLocation(ex);
                          holder.put(c, sd);
                      }
                      return sd.getIServiceConnection();
                  }
              }
          ...
            
      }
  ```

  在这个函数中移除掉存储的映射关系

- `AMS.unbindService()`

  ```java
  // ../core/java/com/android/server/am/ActivityManagerService.java
      public boolean unbindService(IServiceConnection connection) {
          synchronized (this) {
              return mServices.unbindServiceLocked(connection);
          }
      }
  ```

  

调用到`ActiveServices.unbindServiceLocked()`

```java
// ../core/java/com/android/server/am/ActiveServices.java
 boolean unbindServiceLocked(IServiceConnection connection) {
        IBinder binder = connection.asBinder();
        if (DEBUG_SERVICE) Slog.v(TAG_SERVICE, "unbindService: conn=" + binder);
        ArrayList<ConnectionRecord> clist = mServiceConnections.get(binder);
        if (clist == null) {
            Slog.w(TAG, "Unbind failed: could not find connection for "
                  + connection.asBinder());
            return false;
        }

        final long origId = Binder.clearCallingIdentity();
        try {
            while (clist.size() > 0) {
                ConnectionRecord r = clist.get(0);
                //移除掉对应Service的绑定
                removeConnectionLocked(r, null, null);
                
                ...
                //从映射表中移除对应的ServiceConnection
              
            }

            mAm.updateOomAdjLocked();

        } finally {
            Binder.restoreCallingIdentity(origId);
        }

        return true;
    }

 void removeConnectionLocked(
        ConnectionRecord c, ProcessRecord skipApp, ActivityRecord skipAct) {
        IBinder binder = c.conn.asBinder();
        AppBindRecord b = c.binding;
        ServiceRecord s = b.service;
        ArrayList<ConnectionRecord> clist = s.connections.get(binder);
        if (clist != null) {
            clist.remove(c);
            if (clist.size() == 0) {
                s.connections.remove(binder);
            }
        }
        b.connections.remove(c);
        ...
        if (!c.serviceDead) {
            if (DEBUG_SERVICE) Slog.v(TAG_SERVICE, "Disconnecting binding " + b.intent
                    + ": shouldUnbind=" + b.intent.hasBound);
            if (s.app != null && s.app.thread != null && b.intent.apps.size() == 0
                    && b.intent.hasBound) {
                try {
                    bumpServiceExecutingLocked(s, false, "unbind");
                    if (b.client != s.app && (c.flags&Context.BIND_WAIVE_PRIORITY) == 0
                            && s.app.setProcState <= ActivityManager.PROCESS_STATE_RECEIVER) {
                        // If this service's process is not already in the cached list,
                        // then update it in the LRU list here because this may be causing
                        // it to go down there and we want it to start out near the top.
                        mAm.updateLruProcessLocked(s.app, false, null);
                    }
                    mAm.updateOomAdjLocked(s.app, true);
                    b.intent.hasBound = false;
                    // Assume the client doesn't want to know about a rebind;
                    // we will deal with that later if it asks for one.
                    b.intent.doRebind = false;
                    s.app.thread.scheduleUnbindService(s, b.intent.intent.getIntent());
                } catch (Exception e) {
                    Slog.w(TAG, "Exception when unbinding service " + s.shortName, e);
                    serviceProcessGoneLocked(s);
                }
            }

          ...
          //如果是利用 BIND_AUTO_CREATE的flag就会向下调用
          if ((c.flags&Context.BIND_AUTO_CREATE) != 0) {
                boolean hasAutoCreate = s.hasAutoCreateConnections();
                if (!hasAutoCreate) {
                    if (s.tracker != null) {
                        s.tracker.setBound(false, mAm.mProcessStats.getMemFactorLocked(),
                                SystemClock.uptimeMillis());
                    }
                }
                //这里走的是stopService的流程
                bringDownServiceIfNeededLocked(s, true, hasAutoCreate);
            }
        }
    }
```

又看到了熟悉的`app.thread`就知道切换回到了`ActivityThread`

```java
// ../android/app/ActivityThread.java
public final void scheduleUnbindService(IBinder token, Intent intent) {
            BindServiceData s = new BindServiceData();
            s.token = token;
            s.intent = intent;

            sendMessage(H.UNBIND_SERVICE, s);
        }

private void handleUnbindService(BindServiceData data) {
        Service s = mServices.get(data.token);
        if (s != null) {
            try {
                data.intent.setExtrasClassLoader(s.getClassLoader());
                data.intent.prepareToEnterProcess();
                //调用到 onUnbind() 生命周期
                boolean doRebind = s.onUnbind(data.intent);
                try {
                    if (doRebind) {
                        //需要重新绑定
                        ActivityManager.getService().unbindFinished(
                                data.token, data.intent, doRebind);
                    } else {
                        //取消绑定
                        ActivityManager.getService().serviceDoneExecuting(
                                data.token, SERVICE_DONE_EXECUTING_ANON, 0, 0);
                    }
                } catch (RemoteException ex) {
                    throw ex.rethrowFromSystemServer();
                }
            } catch (Exception e) {
                ...
            }
        }
    }
```

当Service调用`onUnbind()`之后，还需要做一件事情，如果是靠`bindService()`并配置`flag`为`BIND_AUTO_CREATE`。那么后续还会执行到`stopService()`中的流程，即会调用到`Service.onDestroy()`。

```java
// ../core/java/com/android/server/am/ActiveServices.java
 void removeConnectionLocked(
//如果是利用 BIND_AUTO_CREATE的flag就会向下调用
          if ((c.flags&Context.BIND_AUTO_CREATE) != 0) {
                boolean hasAutoCreate = s.hasAutoCreateConnections();
                if (!hasAutoCreate) {
                    if (s.tracker != null) {
                        s.tracker.setBound(false, mAm.mProcessStats.getMemFactorLocked(),
                                SystemClock.uptimeMillis());
                    }
                }
                //这里走的是stopService的流程
                bringDownServiceIfNeededLocked(s, true, hasAutoCreate); //true true
            }
   }
```

```java
private final void bringDownServiceIfNeededLocked(ServiceRecord r, boolean knowConn,
            boolean hasConn) {
        //由于bindService过程中的Service不是由startService()进行启动的，所有这里可以向下执行
        if (isServiceNeededLocked(r, knowConn, hasConn)) {
            return;
        }
        // Are we in the process of launching?
        if (mPendingServices.contains(r)) {
            return;
        }
        bringDownServiceLocked(r);
    }

private final boolean isServiceNeededLocked(ServiceRecord r, boolean knowConn,
            boolean hasConn) {
        // 是否由startService()执行
        if (r.startRequested) {
            return true;
        }
        // Is someone still bound to us keeping us running?
        if (!knowConn) {
            hasConn = r.hasAutoCreateConnections();
        }
        if (hasConn) {
            return true;
        }
        return false;
    }

```

{% fullimage /images/Service解绑过程.png,Service解绑过程,Service解绑过程%}

### Service停止过程 - stopService()

还是由`ContextWrapper.stopService()`开始执行

> 主链路：`ContextImpl.stopServiceCommon() -> AMS.stopService() -> ActiveServices.stopServiceLocked() -> bringDownServiceLocked() -> ActivityThread.handleStopService()`

```java
    @Override
    public boolean stopService(Intent name) {
        return mBase.stopService(name);
    }
```

向下执行到`ContextImpl.stopService()`中

```java
    @Override
    public boolean stopService(Intent service) {
        warnIfCallingFromSystemProcess();
        return stopServiceCommon(service, mUser);
    }

    private boolean stopServiceCommon(Intent service, UserHandle user) {
        try {
            validateServiceIntent(service);
            service.prepareToLeaveProcess(this);
            int res = ActivityManager.getService().stopService(
                mMainThread.getApplicationThread(), service,
                service.resolveTypeIfNeeded(getContentResolver()), user.getIdentifier());
            if (res < 0) {
                throw new SecurityException(
                        "Not allowed to stop service " + service);
            }
            return res != 0;
        } catch (RemoteException e) {
            throw e.rethrowFromSystemServer();
        }
    }

```

`ActivityManager.getService()`实际就是指向`ActivityManagerService`的一个Binder对象

```java
// ../core/java/com/android/server/am/ActivityManagerService.java   
@Override
    public int stopService(IApplicationThread caller, Intent service,
            String resolvedType, int userId) {
        enforceNotIsolatedCaller("stopService");
        // Refuse possible leaked file descriptors
        if (service != null && service.hasFileDescriptors() == true) {
            throw new IllegalArgumentException("File descriptors passed in Intent");
        }

        synchronized(this) {
            return mServices.stopServiceLocked(caller, service, resolvedType, userId);
        }
    }
```

`mServices`是`ActiveServices`的一个实际对象。

```java
int stopServiceLocked(IApplicationThread caller, Intent service,
            String resolvedType, int userId) {
        ...
        // If this service is active, make sure it is stopped.
        ServiceLookupResult r = retrieveServiceLocked(service, resolvedType, null,
                Binder.getCallingPid(), Binder.getCallingUid(), userId, false, false, false);
        if (r != null) {
            if (r.record != null) {
                final long origId = Binder.clearCallingIdentity();
                try {
                    stopServiceLocked(r.record);
                } finally {
                    Binder.restoreCallingIdentity(origId);
                }
                return 1;
            }
            return -1;
        }

        return 0;
    }

    private void stopServiceLocked(ServiceRecord service) {
        ...
        service.startRequested = false;
        if (service.tracker != null) {
            service.tracker.setStarted(false, mAm.mProcessStats.getMemFactorLocked(),
                    SystemClock.uptimeMillis());
        }
        service.callStart = false;
        bringDownServiceIfNeededLocked(service, false, false);
    }

    private final boolean isServiceNeededLocked(ServiceRecord r, boolean knowConn,
            boolean hasConn) {
        // Are we still explicitly being asked to run?
        if (r.startRequested) {
            return true;
        }

        if (!knowConn) {
            hasConn = r.hasAutoCreateConnections();
        }
        if (hasConn) {
            return true;
        }

        return false;
    }

    private final void bringDownServiceIfNeededLocked(ServiceRecord r, boolean knowConn,
            boolean hasConn) {
        if (isServiceNeededLocked(r, knowConn, hasConn)) {
            return;
        }

        if (mPendingServices.contains(r)) {
            return;
        }

        bringDownServiceLocked(r);
    }
```

最后调用到了`bringDownServiceLocked()`

```java
private final void bringDownServiceLocked(ServiceRecord r) {    
  ...
     if (r.app != null) {
            synchronized (r.stats.getBatteryStats()) {
                r.stats.stopLaunchedLocked();
            }
            r.app.services.remove(r);
            if (r.whitelistManager) {
                updateWhitelistManagerLocked(r.app);
            }
            if (r.app.thread != null) {
                updateServiceForegroundLocked(r.app, false);
                try {
                    bumpServiceExecutingLocked(r, false, "destroy");
                    mDestroyingServices.add(r);
                    r.destroying = true;
                    mAm.updateOomAdjLocked(r.app, true);
                    r.app.thread.scheduleStopService(r);
                } catch (Exception e) {
                    Slog.w(TAG, "Exception when destroying service "
                            + r.shortName, e);
                    serviceProcessGoneLocked(r);
                }
            } else {
                if (DEBUG_SERVICE) Slog.v(
                    TAG_SERVICE, "Removed service that has no process: " + r);
            }
        } else {
            if (DEBUG_SERVICE) Slog.v(
                TAG_SERVICE, "Removed service that is not running: " + r);
        }
  ...
}
```

`app.thread`切换到`ApplicationThread`继续执行流程

```java
// ../android/app/ActivityThread.java
public final void scheduleStopService(IBinder token) {
            sendMessage(H.STOP_SERVICE, token);
        }

private void handleStopService(IBinder token) {
        Service s = mServices.remove(token);
        if (s != null) {
            try {
                if (localLOGV) Slog.v(TAG, "Destroying service " + s);
                s.onDestroy();
                s.detachAndCleanUp();
                Context context = s.getBaseContext();
                if (context instanceof ContextImpl) {
                    final String who = s.getClassName();
                    ((ContextImpl) context).scheduleFinalCleanup(who, "Service");
                }

                QueuedWork.waitToFinish();

                try {
                    ActivityManager.getService().serviceDoneExecuting(
                            token, SERVICE_DONE_EXECUTING_STOP, 0, 0);
                } catch (RemoteException e) {
                    throw e.rethrowFromSystemServer();
                }
            } catch (Exception e) {
                ...
            }
        } else {
           ...
        }
      
    }
```

最后执行到`Service.onDestroy`完成停止流程。

{% fullimage /images/Service停止流程.png,Service停止流程,Service停止流程%}

## 知识点补全

### startService与bindService的本质差异

- `startService()`关注的是“启动请求计数”（`startRequested/startId`），对应回调是`onStartCommand()`。
- `bindService()`关注的是“连接关系计数”（`ConnectionRecord/AppBindRecord`），对应回调是`onBind()/onUnbind()`。
- 两者可共存：同一Service既被start又被bind时，必须同时满足“无启动请求 + 无绑定连接”才会销毁。

### 生命周期组合速览

1. 仅`startService()`：`onCreate -> onStartCommand(可多次) -> onDestroy`
2. 仅`bindService()`：`onCreate -> onBind -> onUnbind -> onDestroy`（最后一个连接断开后）
3. `start + bind`：先走start链路，再走bind链路；即使全部解绑，只要未stop仍可继续存活

### 为什么bind不会触发onStartCommand

- `onStartCommand()`对应的是“启动请求”，由`sendServiceArgsLocked -> scheduleServiceArgs`触发。
- 纯bind路径走的是`requestServiceBindingLocked -> scheduleBindService -> onBind`，没有`StartItem`入队。
- 因此“bind会拉起Service进程”与“触发onStartCommand”是两件不同的事。

### onRebind触发条件再确认

- 前提是`onUnbind()`返回`true`，系统才会记录后续可重绑。
- 下次有客户端重新绑定同一Service时，回调`onRebind()`而不是再次走`onBind()`。

### BIND_AUTO_CREATE与销毁时机

- `BIND_AUTO_CREATE`会在绑定时自动拉起Service。
- 当最后一个自动创建连接断开时，会进入`bringDownServiceIfNeededLocked()`判定是否可销毁。
- 若Service此前被`startService()`启动且尚未`stopService/stopSelf`，则不会仅因解绑而销毁。

### 主线程约束与ANR风险

- Service生命周期回调默认运行在主线程（`ActivityThread`）。
- `onCreate/onStartCommand/onBind`中执行重任务会阻塞主线程并放大ANR风险。
- 实践上应快速返回，把IO/CPU任务切到工作线程（线程池、协程、WorkManager等）。

### 前台服务版本差异

- Android 8.0(API 26)+引入`startForegroundService()`约束。
- Service启动后需在限定时间内调用`startForeground()`，否则系统会判定异常并终止。
- 新版本还叠加了后台启动限制，设计时应优先考虑可延迟任务与系统调度组件。

## 拓展

为什么Activity退出时`bindService()`的Service会一并销毁？

观察源码发现，`bindService()`也会去启动Service，但为什么没有回调到`onStartCommand()`？

核心原因是：`bindService()`拉起的是“绑定链路”，会走`onBind()`；`onStartCommand()`只属于“启动链路”，只有`startService()/startForegroundService()`写入启动请求后才会触发。
