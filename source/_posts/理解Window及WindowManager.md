---
title: 理解Window及WindowManager
date: 2019-01-10 11:48:59
tags: Android
top: 10
---

{% fullimage /images/WindowWindowManager.png,Window&WindowManager,Window&WindowManager%}

## 1.基本概念

`Window`：他是一个抽象类，具体的实现类为`PhoneWindow`，它对View进行管理。每个Window都会对应一个`View`和一个`ViewRootImpl`，Window通过`ViewRootImpl`与View建立联系。

`WindowManager`：是一个接口类，继承`ViewManager`，主要用于管理Window，具体实现类为`WindowManagerImpl`。实际使用中无法直接访问Window，需要通过`WindowManager`进行操作。

`WindowManagerService`：`WindowManager`的具体工作都会通过`WindowManagerService`进行处理，他们之间通过`Binder`进行跨进程通信，`WindowManager`无法直接调用WMS中的API。



{% fullimage /images/Window&WindowManager&WMS.png,Window&WindowManager&WMS,Window&WindowManager&WMS%}



## 2.Window的属性

### Window的类型(*Type*)

Window有三种类型：

- **Application Window(应用窗口)**：对应一个Activity  `层级范围为1~99`

- **Sub Window(子窗口)**：不能独立存在，需要附着在其他窗口上才行，例如*Dialog,PopupWindow*   `层级范围为1000~1999`
- **System Window(系统窗口)**：需要声明权限才能创建的Window，例如*Toast*   `层级范围为2000~2999`



Window是分层的，层级大的Window会覆盖在层级小的Window上面，上面描述的层级范围对应的是`WindowManager.LayoutParams的type参数`。

通过`layoutParams.type = LayoutParams.TYPE_XXX`可以设置层级。**同时需要声明`<user-permission android:name="android:permission.SYSTEM_ALERT_WINDOW">`**就可以设置系统窗口的type。



### Window的标志(*Flag*)

Window的标志用于控制Window的显示，同时被定义在`WindowManager.LayoutParams`中，以下列举比较常用的：

| FLAG                  | 描述                                                         |
| --------------------- | ------------------------------------------------------------ |
| FLAG_NOT_FOCUSABLE    | 表示Window不需要获取焦点，也不需要接收各种输入事件，同时会设置`FLAG_NOT_TOUCH_MODAL`标记，最终事件会传递到下层具有焦点的Window |
| FLAG_NOT_TOUCH_MODAL  | 系统会将当前区域以外的触摸事件向下传递，Window以内的事件自己处理。*一般需要开启，否则其他Window无法接受时间。* |
| FLAG_SHOW_WHEN_LOCKED | 表示Window可显示在锁屏界面。(*例如XX助手*)                   |
| FLAG_KEEP_SCREEN_ON   | 只要窗口可见，屏幕就会一直亮着                               |
| FLAG_FULLSCREEN       | 隐藏所有的屏幕装饰窗口，进入全屏显示                         |

设置Windwo的Flag有三种方法：

1. 通过Window的`addFlags()`

   ```java
   Window mWindow = getWindow();
   window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
   ```

2. 通过Window的`setFlags()`

   ```java
   Window mWindow = getWindow();
   window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,WindowManager.LayoutParams.FLAG_FULLSCREEN);
   ```

   > `addFlags()`内部实现调用的还是`setFlags()`，两者区别不大。

3. 设置`LayoutParams.flags=XX`，并通过`addView()`添加进Window

   ```java
   WindowManager.LayoutParams mLayoutParams = new WindowManager.LayoutParams();
   mLayoutParams.flags = WindowManager.LayoutParams.FLAG_FULLSCREEN;
   WindowManager mWindowManager = (WindowManager)getSystemService(Context.WINDOW_SERVICE);
   TextView tv = new TextView(this);
   mWindowManager.addView(tv,mLayoutParams);
   ```



### Window的位置(*Gravity*)

默认位于屏幕中间

```java
mLayoutParams.gravity = Gravity.LEFT | Gravity.TOP;//配置gravity 居于左上位置
mLayoutParams.x = 100;//相对于gravity 居左100
mLayoutParams.y = 300;//相对于gravity 居上300
```

设置的`x、y`是相对于gravity的位置



### Window软键盘相关模式

窗口之间的叠加是常见的场景，如果弹出窗口为软键盘的话，可能会有显示问题，默认弹出软键盘会覆盖用户的输入框。`WindowManager.LayoutParams`中定义了相关的软键盘弹出模式，下面列举常用的几个：

| SoftInputMode                  | 描述                                                 |
| ------------------------------ | ---------------------------------------------------- |
| SOFT_INPUT_STATE_UNSPECIFIED   | 没有指定状态，系统会自动选择一个                     |
| SOFT_INPUT_STATE_UNCHANGED     | 不会改变软键盘状态                                   |
| SOFT_INPUT_STATE_HIDDEN        | 用户进入窗口，软键盘默认隐藏                         |
| SOFT_INPUT_STATE_ALWAYS_HIDDEN | 窗口获取焦点时，软键盘总是隐藏                       |
| SOFT_INPUT_ADJUST_RESIZE       | 软键盘弹出时，窗口会调整大小                         |
| SOFT_INPUT_ADJUST_PAN          | 软键盘弹出时，窗口不需要调整大小，确保输入焦点是可见 |

```java
getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN)
```

或者设置在`AndroidManifest.xml`中

```xml
<activity
          android:windowSoftInputMode="SOFT_INPUT_ADJUST_PAN"
          />
```



## 3.Window的操作

对Window的访问必须通过`WindowManager`，主要有三大操作：**添加、更新、删除**。这三个方法主要定义在`ViewManger`中

```java
public interface ViewManager
{
    public void addView(View view, ViewGroup.LayoutParams params);
    public void updateViewLayout(View view, ViewGroup.LayoutParams params);
    public void removeView(View view);
}
```

`WindowManager`也是一个接口继承自`ViewManager`

```java
public interface WindowManager extends ViewManager 
```

`WindowManagerImpl`就是`WindowManager`的具体实现类

```java
public final class WindowManagerImpl implements WindowManager {
 ...
    @Override
    public void addView(@NonNull View view, @NonNull ViewGroup.LayoutParams params) {
        applyDefaultToken(params);
        mGlobal.addView(view, params, mContext.getDisplay(), mParentWindow);
    }

    @Override
    public void updateViewLayout(@NonNull View view, @NonNull ViewGroup.LayoutParams params) {
        applyDefaultToken(params);
        mGlobal.updateViewLayout(view, params);
    }
  
      @Override
    public void removeView(View view) {
        mGlobal.removeView(view, false);
    }
  ...
}
```

最终`WindowManagerImpl`对View的操作交由`WindowManagerGlobal`去实现。

{% fullimage /images/WindowManager关系.png,WindowManager关系,WindowManager关系%}

`WindowManagerGlobal`通过`ViewRootImpl`操作Window，`ViewRootImpl`通过`IWindowSession`这个Binder对象与`WindowManagerService`进程间通信去操作Window。

{% post_link WindowManagerService简析%}

### Window添加

> 添加过程需要通过`WindowManager.addView()`来实现，它的真正实现需要通过`WindowManagerGlobal`

```java
    //存储所有Window对应的View
    private final ArrayList<View> mViews = new ArrayList<View>();
    //所有Window对应的ViewRootImpl
    private final ArrayList<ViewRootImpl> mRoots = new ArrayList<ViewRootImpl>();
    //所有Window对应的布局参数 LayoutParams
    private final ArrayList<WindowManager.LayoutParams> mParams =
            new ArrayList<WindowManager.LayoutParams>();
    //存储那些正在被删除的对象
    private final ArraySet<View> mDyingViews = new ArraySet<View>();    

public void addView(View view, ViewGroup.LayoutParams params,
            Display display, Window parentWindow) {
        //检测参数是否合法
        if (view == null) {
            throw new IllegalArgumentException("view must not be null");
        }
        if (display == null) {
            throw new IllegalArgumentException("display must not be null");
        }
        if (!(params instanceof WindowManager.LayoutParams)) {
            throw new IllegalArgumentException("Params must be WindowManager.LayoutParams");
        } 
      
        final WindowManager.LayoutParams wparams = (WindowManager.LayoutParams) params;
        //如果是子Window还需要调整参数
        if (parentWindow != null) {
            parentWindow.adjustLayoutParamsForSubWindow(wparams);
        } else {
            
            final Context context = view.getContext();
            if (context != null
                    && (context.getApplicationInfo().flags
                            & ApplicationInfo.FLAG_HARDWARE_ACCELERATED) != 0) {
                wparams.flags |= WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED;
            }
        }
      
      ...
        //创建ViewRootImpl
        root = new ViewRootImpl(view.getContext(), display);
        view.setLayoutParams(wparams);
        //保存当前界面的参数
        mViews.add(view);
        mRoots.add(root);
        mParams.add(wparams);
      ...
        try {
            //调用 ViewRootImpl.setView() 更新界面并完成Window的添加过程
                root.setView(view, wparams, panelParentView);
            } catch (RuntimeException e) {
                // BadTokenException or InvalidDisplayException, clean up.
                if (index >= 0) {
                    removeViewLocked(index, true);
                }
                throw e;
            }
    }
```

在`WindowManagerGlobal.addView()`主要完成了以下三步：

- 检查参数是否合法，如果是子Window，还需要调整参数
- 创建ViewRootImpl，然后保存当前界面参数
- 调用`ViewRootImpl.setView()`继续完成Window的添加过程

````java
// ../android/view/ViewRootImpl.java
public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
  synchronized (this) {
    ...
      //刷新当前界面
      requestLayout();
    ...
       try {
                    mOrigWindowType = mWindowAttributes.type;
                    mAttachInfo.mRecomputeGlobalAttributes = true;
                    collectViewAttributes();
                    //最终添加Window实现过程
                    res = mWindowSession.addToDisplay(mWindow, mSeq, mWindowAttributes,
                            getHostVisibility(), mDisplay.getDisplayId(),
                            mAttachInfo.mContentInsets, mAttachInfo.mStableInsets,
                            mAttachInfo.mOutsets, mInputChannel);
                } catch (RemoteException e) {
                    mAdded = false;
                    mView = null;
                    mAttachInfo.mRootView = null;
                    mInputChannel = null;
                    mFallbackEventHandler.setView(null);
                    unscheduleTraversals();
                    setAccessibilityFocus(null, null);
                    throw new RuntimeException("Adding window failed", e);
                } finally {
                    if (restore) {
                        attrs.restore();
                    }
                }
  }
}
````

`mWindowSession`的类型是`IWindowSession`是一个Binder对象，用于进行进程间通信，它是`Session`代理对象。

添加完成后，需要通过返回值`res`来判断是否添加成功。若是`WindowManagerGlobal.ADD_PKAY`说明添加成功。

```java
// ../core/java/com/android/server/wm/Session.java
    final WindowManagerService mService;
    @Override
    public int addToDisplay(IWindow window, int seq, WindowManager.LayoutParams attrs,
            int viewVisibility, int displayId, Rect outContentInsets, Rect outStableInsets,
            Rect outOutsets, InputChannel outInputChannel) {
        return mService.addWindow(this, window, seq, attrs, viewVisibility, displayId,
                outContentInsets, outStableInsets, outOutsets, outInputChannel);
    }
```

`addToDisplay()`最终调用到`WindowManagerService.addWindow()`实现Window添加过程。

{% fullimage /images/Window添加过程.png,Window添加过程,Window添加过程%}

### Window更新

> 更新过程需要通过`WindowManager.updateViewLayout()`，它的真正实现需要通过`WindowManagerGlobal`

```java
// ../android/view/WindowManagerGlobal.java   
public void updateViewLayout(View view, ViewGroup.LayoutParams params) {
        if (view == null) {
            throw new IllegalArgumentException("view must not be null");
        }
        if (!(params instanceof WindowManager.LayoutParams)) {
            throw new IllegalArgumentException("Params must be WindowManager.LayoutParams");
        }

        final WindowManager.LayoutParams wparams = (WindowManager.LayoutParams)params;
        //更新View的LayoutParams
        view.setLayoutParams(wparams);

        synchronized (mLock) {
            int index = findViewLocked(view, true);
            ViewRootImpl root = mRoots.get(index);
            mParams.remove(index);
            mParams.add(index, wparams);
            root.setLayoutParams(wparams, false);
        }
    }
```

更新View的LayoutParams之后，还需要更新`ViewRootImpl.setLayoutParams()`

```java
// ../android/view/ViewRootImpl.java
void setLayoutParams(WindowManager.LayoutParams attrs, boolean newView) {
  synchronized(this){
    ...
            if (newView) {
                mSoftInputMode = attrs.softInputMode;
                requestLayout();
            }

            if ((attrs.softInputMode & WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST)
                    == WindowManager.LayoutParams.SOFT_INPUT_ADJUST_UNSPECIFIED) {
                mWindowAttributes.softInputMode = (mWindowAttributes.softInputMode
                        & ~WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST)
                        | (oldSoftInputMode & WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST);
            }

            mWindowAttributesChanged = true;
            //开始View的测量，布局，绘制流程
            scheduleTraversals();
  }
}
```

在`scheduleTraversals()`调用到`performTraversals()`继续执行更新过程

```java
private void performTraversals() {
  ...
    relayoutResult = relayoutWindow(params, viewVisibility, insetsPending);
  ...
    if(!mStopped){
      int childWidthMeasureSpec = getRootMeasureSpec(mWidth, lp.width);
      int childHeightMeasureSpec = getRootMeasureSpec(mHeight, lp.height); 
      //开始测量过程
      performMeasure(childWidthMeasureSpec, childHeightMeasureSpec);
    }
    ...
    //layoutRequested 是否需要重新执行布局过程
    final boolean didLayout = layoutRequested && (!mStopped || mReportNextDraw);
    if(didLayout){
      //开始布局过程
      performLayout(lp, mWidth, mHeight);
    }
    ...
    if (!cancelDraw && !newSurface) {
            if (mPendingTransitions != null && mPendingTransitions.size() > 0) {
                for (int i = 0; i < mPendingTransitions.size(); ++i) {
                    mPendingTransitions.get(i).startChangingAnimations();
                }
                mPendingTransitions.clear();
            }
            //开始绘制过程
            performDraw();
        } 
  ...
  
}
```

`performTraversals()`内部实现了Window更新以及View的整个工作过程(*测量-布局-绘制*)。

```java
    private int relayoutWindow(WindowManager.LayoutParams params, int viewVisibility,
            boolean insetsPending) throws RemoteException {
      ...
         int relayoutResult = mWindowSession.relayout(
                mWindow, mSeq, params,
                (int) (mView.getMeasuredWidth() * appScale + 0.5f),
                (int) (mView.getMeasuredHeight() * appScale + 0.5f),
                viewVisibility, insetsPending ? WindowManagerGlobal.RELAYOUT_INSETS_PENDING : 0,
                mWinFrame, mPendingOverscanInsets, mPendingContentInsets, mPendingVisibleInsets,
                mPendingStableInsets, mPendingOutsets, mPendingBackDropFrame,
                mPendingMergedConfiguration, mSurface);
      ...
    }
```

`mWindowSession`的类型是`IWindowSession`是一个Binder对象，用于进行进程间通信，它是`Session`代理对象。

`mWindow`即`W extends IWindow.Stub`发送给WindowManagerService，用来接受WMS信息。

```java
// ../core/java/com/android/server/wm/Session.java
    final WindowManagerService mService;
    public int relayout(IWindow window, int seq, WindowManager.LayoutParams attrs,
            int requestedWidth, int requestedHeight, int viewFlags,
            int flags, Rect outFrame, Rect outOverscanInsets, Rect outContentInsets,
            Rect outVisibleInsets, Rect outStableInsets, Rect outsets, Rect outBackdropFrame,
            MergedConfiguration mergedConfiguration, Surface outSurface) {

        int res = mService.relayoutWindow(this, window, seq, attrs,
                requestedWidth, requestedHeight, viewFlags, flags,
                outFrame, outOverscanInsets, outContentInsets, outVisibleInsets,
                outStableInsets, outsets, outBackdropFrame, mergedConfiguration, outSurface);

        return res;
    }

```

`relayout()`最终调用到`WindowManagerService.relayoutWindow()`实现Window更新过程。

{% fullimage /images/Window更新过程.png,Window更新过程,Window更新过程%}

### Window删除

> 删除过程需要通过`WindowManager.removeView()`来实现，它的真正实现需要通过`WindowManagerGlobal`

```java 文件位置../android/view/WindowManagerGlobal.java  
// ../android/view/WindowManagerGlobal.java   
public void removeView(View view, boolean immediate) {
        if (view == null) {
            throw new IllegalArgumentException("view must not be null");
        }

        synchronized (mLock) {
            //找到需要删除的View索引
            int index = findViewLocked(view, true);
            View curView = mRoots.get(index).getView();
            removeViewLocked(index, immediate);
            if (curView == view) {
                return;
            }

            throw new IllegalStateException("Calling with view " + view
                    + " but the ViewAncestor is attached to " + curView);
        }
    }
```

实际调用`removeViewLocked()`执行删除Window操作，内部实现还是依赖了`ViewRootImpl`

```java ../android/view/WindowManagerGlobal.java
 private void removeViewLocked(int index, boolean immediate) {
        //从Window添加过程中保存的 ViewRootImpl数组中获取对应的ViewRootImpl对象
        ViewRootImpl root = mRoots.get(index);
        View view = root.getView();

        if (view != null) {
            InputMethodManager imm = InputMethodManager.getInstance();
            if (imm != null) {
                imm.windowDismissed(mViews.get(index).getWindowToken());
            }
        }
        //在die 中执行删除Window操作
        boolean deferred = root.die(immediate);
        if (view != null) {
            view.assignParent(null);
            if (deferred) {
                //存储即将删除的View
                mDyingViews.add(view);
            }
        }
    }
```

```java ../android/view/ViewRootImpl.java
    boolean die(boolean immediate/*是否同步执行删除*/) {
        // Make sure we do execute immediately if we are in the middle of a traversal or the damage
        // done by dispatchDetachedFromWindow will cause havoc on return.
        if (immediate && !mIsInTraversal) {
            //删除对应Window
            doDie();
            return false;
        }

        if (!mIsDrawing) {
            destroyHardwareRenderer();
        } else {
            Log.e(mTag, "Attempting to destroy the window while drawing!\n" +
                    "  window=" + this + ", title=" + mWindowAttributes.getTitle());
        }
        mHandler.sendEmptyMessage(MSG_DIE);
        return true;
    }
```

`die()`中分为两种移除Window方式：*同步执行、异步执行(通过Handler)*。最终都会执行到`doDie()`

```java ../android/view/ViewRootImpl.java
    void doDie() {
        checkThread();
        synchronized (this) {
            if (mRemoved) {
                return;
            }
            mRemoved = true;
            if (mAdded) {
                //已经添加成功的，需要进行删除
                dispatchDetachedFromWindow();
            }
            ...
            mAdded = false;
        }
        //从保存的那些参数中 移除该View的所有引用
        WindowManagerGlobal.getInstance().doRemoveView(this);
    }
```

`doDie()`主要实现了两个功能：

- `dispatchDetachedFromWindow()`：移除Window
- `doRemoveView()`：移除Window所对应的引用

```java ../android/view/ViewRootImpl.java
 void dispatchDetachedFromWindow() {
    //触发View的 onDetachedFromWindow()
        if (mView != null && mView.mAttachInfo != null) {
            mAttachInfo.mTreeObserver.dispatchOnWindowAttachedChange(false);
            mView.dispatchDetachedFromWindow();
        }
    ...
        try {
            //依靠Session去移除Window
            mWindowSession.remove(mWindow);
        } catch (RemoteException e) {
        }
    ...
        unscheduleTraversals();
 }
```

`mWindowSession`的类型是`IWindowSession`是一个Binder对象，用于进行进程间通信，它是`Session`代理对象。

```java ../core/java/com/android/server/wm/Session.java
    public void remove(IWindow window) {
        mService.removeWindow(this, window);
    }
```

`remove()`最终通过`WindowManagerService.removeView()`实现Window删除逻辑。

{% fullimage /images/Window删除过程.png,Window删除过程,Window删除过程%}

### 总结

> 上述Window的三大操作(*添加、更新和删除*)都会通过一个IPC过程调用`WindowManagerService`去实现具体逻辑。
>
> 三大操作过程也都需要通过`ViewRootImpl`来关联起Window和View，`ViewRootImpl`可以控制内部VIew的*测量、布局与绘制*。
>
> **在上述三大操作中，虽然说是由`WindowManagerGlobal`去实现，但内部是依靠的`ViewRootImpl`，实际执行的是`WindowManagerService`。**{% post_link WindowManagerService简析%}

