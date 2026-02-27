---
title: Android硬件加速
typora-root-url: ../
date: 2020-10-27 19:51:58
tags: Android
top: 10
---

![Android硬件加速xmind](/images/Android硬件加速.png)

## 软硬件绘制的分歧点

绘制过程入口位于`ViewRootImpl.performDraw()`中

```java
//viewRootImpl.java
    private void performDraw() {
      ...
        try {
            //调用draw()执行实际的绘制工作
            boolean canUseAsync = draw(fullRedrawNeeded);
            if (usingAsyncReport && !canUseAsync) {
                mAttachInfo.mThreadedRenderer.setFrameCompleteCallback(null);
                usingAsyncReport = false;
            }
        } finally {
            mIsDrawing = false;
            Trace.traceEnd(Trace.TRACE_TAG_VIEW);
        }
    }
```

`ViewRootImpl.draw()`实际执行的绘制工作

```java
//ViewRootImpl.java
private boolean draw(boolean fullRedrawNeeded) {
  ...
    final Rect dirty = mDirty;//需要重新绘制的区域
  ...
    if (!dirty.isEmpty() || mIsAnimating || accessibilityFocusDirty) {
            //是否支持硬件加速
            if (mAttachInfo.mThreadedRenderer != null && mAttachInfo.mThreadedRenderer.isEnabled()) {
              ...
                mAttachInfo.mThreadedRenderer.draw(mView, mAttachInfo, this, callback);//硬件绘制
            } else {
              ...
                //软件绘制
                if (!drawSoftware(surface, mAttachInfo, xOffset, yOffset,
                        scalingRequired, dirty, surfaceInsets)) {
                    return false;
                }
            }
      ...
    }
  ...
  
}
```

## 软件绘制

![Android绘制-软件绘制](/images/Android绘制-软件绘制.png)

### ViewRootImpl软件绘制相关

> 未开启`硬件加速`时，执行到`drawSoftware()`

```java
    private boolean drawSoftware(Surface surface, AttachInfo attachInfo, int xoff, int yoff,
            boolean scalingRequired, Rect dirty, Rect surfaceInsets) {
        // Draw with software renderer.
        final Canvas canvas;
      
       canvas = mSurface.lockCanvas(dirty);//获取用于绘制的Canvas
       ...
       mView.draw(canvas);//将mView的内容绘制到Canvas
       ...
       //将Canvas的内容显示到屏幕上,向SurfaceFlinger服务Queue一个Graphic Buffer
       surface.unlockCanvasAndPost(canvas);
    }
```

此处的`mView`对应的就是`DecorView`

```java
//DecorView.java
    @Override
    public void draw(Canvas canvas) {
        super.draw(canvas);

        if (mMenuBackground != null) {
            mMenuBackground.draw(canvas);
        }
    }
```

执行到`super.draw()`，`DecorView`继承自`FrameLayout`，等价于执行到`ViewGroup.draw()`。

```java
//View.java
    public void draw(Canvas canvas) {
      ...
        if (!dirtyOpaque) {
          //绘制背景
            drawBackground(canvas);
        }
        //绘制自身
        if (!dirtyOpaque) onDraw(canvas);
        //绘制子View 只有ViewGroup会实现该方法
        dispatchDraw(canvas);
        //绘制前景
        onDrawForeground(canvas);
      ...
    }
```

```java
//ViewGroup.java
    protected void dispatchDraw(Canvas canvas) {
      ...
        final ArrayList<View> preorderedList = usingRenderNodeProperties
                ? null : buildOrderedChildList();//绘制顺序按照Z值从大到小排列
        final boolean customOrder = preorderedList == null
                && isChildrenDrawingOrderEnabled();//允许自定义绘制顺序
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

            final int childIndex = getAndVerifyPreorderedIndex(childrenCount, i, customOrder);//根据自定义顺序获取当前绘制的View的绘制顺序
            final View child = getAndVerifyPreorderedView(preorderedList, children, childIndex);
            if ((child.mViewFlags & VISIBILITY_MASK) == VISIBLE || child.getAnimation() != null) {
                more |= drawChild(canvas, child, drawingTime);
            }
        }
    }
    //绘制子View
    protected boolean drawChild(Canvas canvas, View child, long drawingTime) {
        return child.draw(canvas, this, drawingTime);
    }
```

`DecorView`是最顶层的View，自`drawSoftware()`开始绘制。

### View软件绘制相关

上一节后面执行到了`child.draw()`，`child`为`View`

```java
//View.java
boolean draw(Canvas canvas, ViewGroup parent, long drawingTime) {
        final boolean hardwareAcceleratedCanvas = canvas.isHardwareAccelerated();
        //是否支持硬件绘制 显然当前情况不支持
        boolean drawingWithRenderNode = mAttachInfo != null
                && mAttachInfo.mHardwareAccelerated
                && hardwareAcceleratedCanvas;
  
         ...
           //后续绘制缓存会分析
          if (layerType == LAYER_TYPE_SOFTWARE || !drawingWithRenderNode) {
             if (layerType != LAYER_TYPE_NONE) {
                 // If not drawing with RenderNode, treat HW layers as SW
                 layerType = LAYER_TYPE_SOFTWARE;
                 buildDrawingCache(true);
            }
            cache = getDrawingCache(true);
         }
         //缓存可用 且 非硬件绘制条件下
         final boolean drawingWithDrawingCache = cache != null && !drawingWithRenderNode;
         ...
         if (!drawingWithDrawingCache) {
            if (drawingWithRenderNode) {
                mPrivateFlags &= ~PFLAG_DIRTY_MASK;
                ((DisplayListCanvas) canvas).drawRenderNode(renderNode);
            } else {
                // ViewGroup 不需要绘制背景直接 绘制子View
                if ((mPrivateFlags & PFLAG_SKIP_DRAW) == PFLAG_SKIP_DRAW) {
                    mPrivateFlags &= ~PFLAG_DIRTY_MASK;
                    dispatchDraw(canvas);
                } else {
                    draw(canvas);
                }
            }
        }
       ...
}
```



```java
//View.java
        if ((changed & DRAW_MASK) != 0) {
            if ((mViewFlags & WILL_NOT_DRAW) != 0) {
                if (mBackground != null
                        || mDefaultFocusHighlight != null
                        || (mForegroundInfo != null && mForegroundInfo.mDrawable != null)) {
                    mPrivateFlags &= ~PFLAG_SKIP_DRAW;
                } else {
                    mPrivateFlags |= PFLAG_SKIP_DRAW;
                }
            } else {
                mPrivateFlags &= ~PFLAG_SKIP_DRAW;
            }
            requestLayout();
            invalidate(true);
        }
```

### 软件绘制流程



![软件绘制流程](/images/软件绘制流程.jpg)



### Surface绘制流程

![软件绘制-Surface绘制过程](/images/软件绘制-Surface绘制过程.png)

执行到`drawSoftware()`时，开始在`Surface`上进行绘制。

#### 申请`GraphicBuffer`

执行的是`mSurface.lockCanvas()`

```java
//ViewRootImpl.java
canvas = mSurface.lockCanvas()
  
//Surface.java
    public Canvas lockCanvas(Rect inOutDirty)
            throws Surface.OutOfResourcesException, IllegalArgumentException {
        synchronized (mLock) {
            checkNotReleasedLocked();
            if (mLockedObject != 0) {
                // Ideally, nativeLockCanvas() would throw in this situation and prevent the
                // double-lock, but that won't happen if mNativeObject was updated.  We can't
                // abandon the old mLockedObject because it might still be in use, so instead
                // we just refuse to re-lock the Surface.
                throw new IllegalArgumentException("Surface was already locked");
            }
            mLockedObject = nativeLockCanvas(mNativeObject, mCanvas, inOutDirty);
            return mCanvas;
        }
    }
```

执行到`nativeLockCanvas()`进入JNI代码层

```c++
// core/jni/android_view_Surface.cpp
static jlong nativeLockCanvas(JNIEnv* env, jclass clazz,
        jlong nativeObject, jobject canvasObj, jobject dirtyRectObj) {
    sp<Surface> surface(reinterpret_cast<Surface *>(nativeObject));
  ...
    //申请buffer
    ANativeWindow_Buffer outBuffer;
    status_t err = surface->lock(&outBuffer, dirtyRectPtr);
  ...
    //构建Bitmap对象
    SkImageInfo info = SkImageInfo::Make(outBuffer.width, outBuffer.height,
                                         convertPixelFormat(outBuffer.format),
                                         outBuffer.format == PIXEL_FORMAT_RGBX_8888
                                                 ? kOpaque_SkAlphaType : kPremul_SkAlphaType,
                                         GraphicsJNI::defaultColorSpace());

    SkBitmap bitmap;
    ssize_t bpr = outBuffer.stride * bytesPerPixel(outBuffer.format);
    bitmap.setInfo(info, bpr);
    if (outBuffer.width > 0 && outBuffer.height > 0) {
        bitmap.setPixels(outBuffer.bits);
    } else {
        // be safe with an empty bitmap.
        bitmap.setPixels(NULL);
    }
    //canvas设置bitmap
    Canvas* nativeCanvas = GraphicsJNI::getNativeCanvas(env, canvasObj);
    nativeCanvas->setBitmap(bitmap);
    
    sp<Surface> lockedSurface(surface);
    lockedSurface->incStrong(&sRefBaseOwner);
    return (jlong) lockedSurface.get();
}
```

创建完`ANativeWindowBuffer`之后，需要与`surface`进行绑定

```c++
//native/libs/gui/Surface.cpp
status_t Surface::lock(
        ANativeWindow_Buffer* outBuffer, ARect* inOutDirtyBounds)
{
  ...
    ANativeWindowBuffer* out;
    int fenceFd = -1;
    status_t err = dequeueBuffer(&out, &fenceFd);  
  ...
     if (err == NO_ERROR) {
        sp<GraphicBuffer> backBuffer(GraphicBuffer::getSelf(out));
        const Rect bounds(backBuffer->width, backBuffer->height);
       ...
     }
  //返回GraphicBuffer
     return err;
}
```

调用到`lock()`之后，将`ANativeWindowBuffer`转化为`GraphicBuffer`。再通过`dequeueBuffer`分配内存

```c++
//native/libs/gui/Surface.cpp
int Surface::dequeueBuffer(android_native_buffer_t** buffer, int* fenceFd) {
  ...
    FrameEventHistoryDelta frameTimestamps;
    status_t result = mGraphicBufferProducer->dequeueBuffer(&buf, &fence, reqWidth, reqHeight,
                                                            reqFormat, reqUsage, &mBufferAge,
                                                            enableFrameTimestamps ? &frameTimestamps
                                                                                  : nullptr);    
  
  ...
    if ((result & IGraphicBufferProducer::BUFFER_NEEDS_REALLOCATION) || gbuf == nullptr) {
        if (mReportRemovedBuffers && (gbuf != nullptr)) {
            mRemovedBuffers.push_back(gbuf);
        }
      //
        result = mGraphicBufferProducer->requestBuffer(buf, &gbuf);
        if (result != NO_ERROR) {
            ALOGE("dequeueBuffer: IGraphicBufferProducer::requestBuffer failed: %d", result);
            mGraphicBufferProducer->cancelBuffer(buf, fence);
            return result;
        }
    }
  //获取buffer
     *buffer = gbuf.get();
  ...
}
```

```c++
//native/libs/gui/BufferQueueProducer.cpp
status_t BufferQueueProducer::dequeueBuffer(int* outSlot, sp<android::Fence>* outFence,
                                            uint32_t width, uint32_t height, PixelFormat format,
                                            uint64_t usage, uint64_t* outBufferAge,
                                            FrameEventHistoryDelta* outTimestamps) {
 ...
    while (found == BufferItem::INVALID_BUFFER_SLOT) {
      //找到可用的slot，并指定状态为FREE slot:BufferSlot——用来存储GraphicBuffer
            status_t status = waitForFreeSlotThenRelock(FreeSlotCaller::Dequeue,
                    &found);
            if (status != NO_ERROR) {
                return status;
            }
      ...
    }
          *outSlot = found;
        ATRACE_BUFFER_INDEX(found);

        attachedByConsumer = mSlots[found].mNeedsReallocation;
        mSlots[found].mNeedsReallocation = false;
       //转化可用slot的GraphicBuffer状态为DEQUEUED
        mSlots[found].mBufferState.dequeue();
  ...
      if (returnFlags & BUFFER_NEEDS_REALLOCATION) {
        BQ_LOGV("dequeueBuffer: allocating a new buffer for slot %d", *outSlot);
        sp<GraphicBuffer> graphicBuffer = new GraphicBuffer(
                width, height, format, BQ_LAYER_COUNT, usage,
                {mConsumerName.string(), mConsumerName.size()});

        status_t error = graphicBuffer->initCheck();

            if (error == NO_ERROR && !mCore->mIsAbandoned) {
                graphicBuffer->setGenerationNumber(mCore->mGenerationNumber);
              //对应outSlot申请GraphicBuffer
                mSlots[*outSlot].mGraphicBuffer = graphicBuffer;
            }
  ...
}
  
status_t BufferQueueProducer::waitForFreeSlotThenRelock(FreeSlotCaller caller,
        int* found) const {
  ...
    //当前是否 队列太多
        bool tooManyBuffers = mCore->mQueue.size()
                            > static_cast<size_t>(maxBufferCount);
        if (tooManyBuffers) {
            BQ_LOGV("%s: queue size is %zu, waiting", callerString,
                    mCore->mQueue.size());
        } else {
            // If in shared buffer mode and a shared buffer exists, always
            // return it.
            if (mCore->mSharedBufferMode && mCore->mSharedBufferSlot !=
                    BufferQueueCore::INVALID_BUFFER_SLOT) {
                *found = mCore->mSharedBufferSlot;
            } else {
                if (caller == FreeSlotCaller::Dequeue) {
                    // If we're calling this from dequeue, prefer free buffers
                  //寻找处于 FREE 状态的GraphicBuffer
                    int slot = getFreeBufferLocked();
                    if (slot != BufferQueueCore::INVALID_BUFFER_SLOT) {
                        *found = slot;                      
                    } else if (mCore->mAllowAllocation) {
                        *found = getFreeSlotLocked();
                    }                                    
                } else {
                    // If we're calling this from attach, prefer free slots
                    int slot = getFreeSlotLocked();
                    if (slot != BufferQueueCore::INVALID_BUFFER_SLOT) {
                        *found = slot;
                    } else {
                        *found = getFreeBufferLocked();
                    }
                }
            }
        }    
  ...
        tryAgain = (*found == BufferQueueCore::INVALID_BUFFER_SLOT) ||
                   tooManyBuffers;
         if (tryAgain) {
           //找不到可用的slot或者buffer太多，需要等待空闲
         }
}
```

`BufferSlot`：用来存储`GraphicBuffer`

`waitForFreeSlotThenRelock()`返回可用的`slot`分为两种：

- `getFreeBufferLocked()`：直接关联了`GraphicBuffer`，直接可用
- `getFreeSlotLocked()`：找到可用的`BufferSlot`，新建`GraphicBuffer`后，直接与其关联。

`lockCanvas()`最终通过`BufferQueueProducer.dequeueBuffer()`申请用来绘制的`GraphicBuffer`

> 尝试找到一个`BufferSlot`，并完成`GraphicBuffer`与`BufferSlot`的关联，途中切换`BufferSlot`状态`FREE->DEQUEUED`，最后返回对应的`BufferSlot`索引。





#### `SurfaceFlinger`消费`GraphicBuffer`

当`Cavans`绘制完毕后，调用`surface.unlockAndPostCanvas()`发送`GraphicBuffer`

```java
//Surface.java
    public void unlockAndPostCanvas(Canvas canvas) {
        synchronized (mLock) {
            checkNotReleasedLocked();

            if (mHwuiContext != null) {
              //硬件绘制流程
                mHwuiContext.unlockAndPost(canvas);
            } else {
              //软件绘制流程
                unlockSwCanvasAndPost(canvas);
            }
        }
    }

    private void unlockSwCanvasAndPost(Canvas canvas) {
      ... 
        try {
            nativeUnlockCanvasAndPost(mLockedObject, canvas);
        } finally {
            nativeRelease(mLockedObject);
            mLockedObject = 0;
        }
    }
```

```c++
// core/jni/android_view_Surface.cpp
static void nativeUnlockCanvasAndPost(JNIEnv* env, jclass clazz,
        jlong nativeObject, jobject canvasObj) {
  ...

    // 绘制完成后，将Canvas从surface上脱离
    Canvas* nativeCanvas = GraphicsJNI::getNativeCanvas(env, canvasObj);
    nativeCanvas->setBitmap(SkBitmap());

    // unlock surface
    status_t err = surface->unlockAndPost();
    if (err < 0) {
        doThrowIAE(env);
    }
}
```

```c++
//native/libs/gui/Surface.cpp
status_t Surface::unlockAndPost()
{
  ...
    err = queueBuffer(mLockedBuffer.get(), fd);
    ALOGE_IF(err, "queueBuffer (handle=%p) failed (%s)",
            mLockedBuffer->handle, strerror(-err));

    mPostedBuffer = mLockedBuffer;
    mLockedBuffer = 0;
    return err;
}
```

```c++
//native/libs/gui/Surface.cpp
int Surface::queueBuffer(android_native_buffer_t* buffer, int fenceFd) {
  ...
    //根据Buffer获取slot
    int i = getSlotFromBufferLocked(buffer);
  ...
    //GraphicBufferQueue 插入 GraphicBuffer
    status_t err = mGraphicBufferProducer->queueBuffer(i, input, &output);
  ...
    //插入Buffer后通知
    mQueueBufferCondition.broadcast();
} 

//根据传入buffer获取slot
int Surface::getSlotFromBufferLocked(
        android_native_buffer_t* buffer) const {
  //NUM_BUFFER_SLOTS 64
    for (int i = 0; i < NUM_BUFFER_SLOTS; i++) {
        if (mSlots[i].buffer != NULL &&
                mSlots[i].buffer->handle == buffer->handle) {
            return i;
        }
    }
    ALOGE("getSlotFromBufferLocked: unknown buffer: %p", buffer->handle);
    return BAD_VALUE;
}
```

```java
//native/libs/gui/BufferQueueProducer.cpp
status_t BufferQueueProducer::queueBuffer(int slot,
        const QueueBufferInput &input, QueueBufferOutput *output) {
    BufferItem item;
  ...
    //判断slot 以及 buffer状态是否正常
        if (slot < 0 || slot >= BufferQueueDefs::NUM_BUFFER_SLOTS) {
            BQ_LOGE("queueBuffer: slot index %d out of range [0, %d)",
                    slot, BufferQueueDefs::NUM_BUFFER_SLOTS);
            return BAD_VALUE;
        } else if (!mSlots[slot].mBufferState.isDequeued()) {
            BQ_LOGE("queueBuffer: slot %d is not owned by the producer "
                    "(state = %s)", slot, mSlots[slot].mBufferState.string());
            return BAD_VALUE;
        } else if (!mSlots[slot].mRequestBufferCalled) {
            BQ_LOGE("queueBuffer: slot %d was queued without requesting "
                    "a buffer", slot);
            return BAD_VALUE;
        }
  ...
    //构建BufferItem对象，等待传递
        item.mAcquireCalled = mSlots[slot].mAcquireCalled;
        item.mGraphicBuffer = mSlots[slot].mGraphicBuffer;
        item.mCrop = crop;
        item.mTransform = transform &
                ~static_cast<uint32_t>(NATIVE_WINDOW_TRANSFORM_INVERSE_DISPLAY);
        item.mTransformToDisplayInverse =
                (transform & NATIVE_WINDOW_TRANSFORM_INVERSE_DISPLAY) != 0;
        item.mScalingMode = static_cast<uint32_t>(scalingMode);
        item.mTimestamp = requestedPresentTimestamp;
        item.mIsAutoTimestamp = isAutoTimestamp;
        item.mDataSpace = dataSpace;
        item.mHdrMetadata = hdrMetadata;
        item.mFrameNumber = currentFrameNumber;
        item.mSlot = slot;
        item.mFence = acquireFence;
        item.mFenceTime = acquireFenceTime;
        item.mIsDroppable = mCore->mAsyncMode ||
                mCore->mDequeueBufferCannotBlock ||
                (mCore->mSharedBufferMode && mCore->mSharedBufferSlot == slot);
        item.mSurfaceDamage = surfaceDamage;
        item.mQueuedBuffer = true;
        item.mAutoRefresh = mCore->mSharedBufferMode && mCore->mAutoRefresh;
        item.mApi = mCore->mConnectedApi;
  
    //切换 BufferSlot状态到 QUEUED
        mSlots[slot].mFence = acquireFence;
        mSlots[slot].mBufferState.queue();
    //将item插入队列
        if (mCore->mQueue.empty()) {
            mCore->mQueue.push_back(item);
            frameAvailableListener = mCore->mConsumerListener;          
        }else{
            const BufferItem& last = mCore->mQueue.itemAt(
                    mCore->mQueue.size() - 1);
            if (last.mIsDroppable) {
              ...
               mCore->mQueue.editItemAt(mCore->mQueue.size() - 1) = item;
               frameReplacedListener = mCore->mConsumerListener;
            }else{
               mCore->mQueue.push_back(item);
               frameAvailableListener = mCore->mConsumerListener;              
            }
        }
  ...
    //回调frameAvaliableListener 通知消费者有数据入队了
        if (frameAvailableListener != NULL) {
            frameAvailableListener->onFrameAvailable(item);
        } else if (frameReplacedListener != NULL) {
            frameReplacedListener->onFrameReplaced(item);
        }    
}
```

//TODO 这里有个问题 如何和`BufferLayer`绑定



```c++
//native/services/surfaceflinger/BufferLayer.cpp
void BufferQueueLayer::onFrameAvailable(const BufferItem& item) {
  ...
   mFlinger->signalLayerUpdate();
}
```

```c++
//SurfaceFlinger.cpp
void SurfaceFlinger::signalLayerUpdate() {
    mScheduler->resetIdleTimer();
    mPowerAdvisor.notifyDisplayUpdateImminent();
    mEventQueue->invalidate();
}
```

> `unlockAndPost()`主要调用到`queueBuffer()`。
>
> 上节在`dequeueBuffer()`获取`slot`之后，就在对应的`slot`生成了`GraphicBuffer`。就可以继续Draw填充过程。
>
> 填充完成后，调用`queueBuffer()`根据`slot`获取对应的`GraphicBuffer`，封装成`BufferItem`对象，在回调`onFrameAvailable()`传入。通知`BufferQueueConsumer`有新数据传入。

![img](/images/关系图.png)

#### BufferQueue

> **Android显示系统的核心**。遵循`生产者-消费者`模型，只要往`BufferQueue`填充数据，就被认为是`生产者`。从`BufferQueue`获取数据，就被认为是`消费者`。
>
> `SurfaceFlinger`在合成并显示UI内容时，UI负责生产内容，`SurfaceFlinger`作为`消费者`消费内容。
>
> 在截屏时，`SurfaceFlinger`作为生产者，将当前的UI内容填充到另一个`BufferQueue`内，截屏作为`消费者`从`BufferQueue`获取数据

![img](/images/v2-6a617ddb116d922b24f416582a5bf013_1440w.jpg)

如图所示执行步骤如下所示：

1. 初始化一个`BufferQueue`
2. `BufferQueueProducer`调用`dequeueBuffer`向`BufferQueue`申请一块空的`GRaphicBuffer`
3. 可以通过`requestBuffer`获取对应的`GraphicBuffer`
4. 向`GraphicBuffer`填充完数据后，调用`queueBuffer`向`BufferQueue`添加`GraphicBuffer`
5. 添加数据完成后，`BufferQueue`通过回调通知消费者，有新数据加入——`onFrameAvaliable()`
6. `BufferQueueConsumer`调用`acquireBuffer`从`BufferQueue`获取`GraphicBuffer`
7. 待`GraphicBuffer`使用完毕后，调用`releaseBuffer`将空的`GraphicBuffer`还给`BufferQueue`以便重复利用
8. 空的数据返回后，`BufferQueue`通过回调通知生产者，有空闲数据。后续生产者可以继续获取空的`GraphicBuffer`进行使用——`onBufferReleased()`
9. 在`2~8`之间循环，形成一整套图形数据的生产-消费过程。



##### GraphicBuffer--BufferState

上面有提到，调用`dequeueBuffer()`需要获取空的`GraphicBuffer`，通过`getFreeBufferLocked()`寻找。

其中`GraphicBuffer`有以下几种状态(`BufferSlot.BufferState`)：

- `FREE`：当前`GraphicBuffer`可用，且位于`BufferQueue`内
- `DEQUEUED`：当前`GraphicBuffer`被生产者获取了，该buffer当前属于生产者
- `QUEUED`：当前`GraphicBuffer`被生产者填充了数据，该buffer当前属于`BufferQueue`
- `ACQUIRED`：当前`GraphicBuffer`被消费者获取了，该buffer当前属于消费者





## 硬件绘制



> 默认开启`硬件加速`，可以通过配置`android:hardwareAccelerated="false"`关闭硬件加速
>
> `把View中绘制的计算工作交给GPU来处理，就是把drawXX()相关的方法进行转换。`

`硬件绘制`主要包含两步：

- `构建阶段`

  > 遍历所有View，将需要绘制的操作缓存下来，构建`DisplayList`。交给`RenderThread`使用GPU进行硬件加速渲染。

- `绘制阶段`

  > 构建好的`DisplayList`交给`RenderThread`使用GPU进行硬件加速渲染，绘制的内容保存在`Graphic Buffer`并交由`SurfaceFlinger`显示。



### 控制硬件加速

![硬件绘制-控制硬件加速](/images/硬件绘制-控制硬件加速.png)

> 硬件绘制需要在`开启硬件加速`的条件下才可以执行

可以在以下级别控制`硬件加速`：

- **应用**

  在`AndroidManifest.xml`配置如下属性

  ```xml
  <application android:hardwareAccelerated="true" ...>
  ```

  

- **Activity**

  在`AndroidManifest.xml`配置如下属性

  ```xml
    <application android:hardwareAccelerated="true">
          <activity ... />
          <activity android:hardwareAccelerated="false" /> //控制某个Activity关闭硬件加速
      </application>
  ```

  

- **窗口Window**

  配置如下代码

  ```java
      getWindow().setFlags(
          WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
          WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
  ```

  

- **视图View**

  为单个视图停用硬件加速

  ```java
  myView.setLayerType(View.LAYER_TYPE_SOFTWARE, null);
  ```

补充：硬件加速开关有三个常见粒度。

- Application级：`android:hardwareAccelerated="true"`（默认多数应用开启）。
- Activity级：可在清单中按页面控制，适合做兼容验证。
- View级：通过`setLayerType(LAYER_TYPE_NONE/SOFTWARE/HARDWARE)`做局部策略。

`setLayerType`使用建议：

- 某些`Paint`效果或机型兼容问题时，可局部切到`LAYER_TYPE_SOFTWARE`。
- 动画频繁变化且绘制复杂时，可评估`LAYER_TYPE_HARDWARE`减少重复录制。
- 硬件层会增加图形内存占用，不建议无差别全局开启。

  

### DisplayList

![硬件绘制-DisplayList](/images/硬件绘制-DisplayList.png)

> 本质上是一个**缓冲区**，里面`记录即将执行的绘制命令序列`。

`DisplayList`的存在有两个好处：

1. 在绘制下一帧时，若View没有发生变化，就不必执行相关绘制API，直接复用上次的`DisplayList`。

2. 在绘制下一帧时，若View发生变化，但只是一些简单属性发生变化，就不需重建`DisplayList`，直接修改`DisplayList`相关属性即可。

   针对以下属性，都不需重建`DisplayList`

   - `alpha`：更改层的不透明度
   - `x`、`y`、`translationX`、`translationY`：更改层的位置
   - `scaleX`、`scaleY`：更改层的大小
   - `rotation`、`rotationX`、`rotationY`：更改层在 3D 空间里的方向
   - `pivotX`、`pivotY`：更改层的转换原点

以上在使用`DisplayList`的过程都不需要执行`onDraw()`。

补充：不是所有变化都会导致DisplayList重录制。

- 内容变化（例如文本、路径、位图内容变化）通常需要重新录制DisplayList。
- 仅属性变化（平移、缩放、透明度）更多是更新RenderNode属性，可能复用已有DisplayList。

![img](/images/DisplayList结构.png)

### RenderNode

> 在Android 5.0后引入，是对`DisplayList`以及`View显示属性`的封装。

**通常一个`RenderNode`对应一个`View`，包含了View自身及其子View的所有DisplayList。**

其中还有一个`RootRenderNode`，里面包含着`View层次结构中所有View的DisplayList信息`。

补充：RenderNode失效类型可粗分两类。

- 属性失效：变换矩阵、alpha等变化，通常不需要重新执行Java层`onDraw()`。
- 内容失效：绘制内容变化，通常需要重新录制DisplayList。

这也是“属性动画常不触发完整`onDraw`”的核心原因。

### ViewRootImpl硬件绘制相关

> 只有当前View支持`硬件加速`时，才可以进入`硬件绘制`
>
> `if (mAttachInfo.mThreadedRenderer != null && mAttachInfo.mThreadedRenderer.isEnabled())`

![硬件绘制-构建DisplayList](/images/硬件绘制-构建DisplayList.png)

#### ThreadedRenderer.draw()

> `ThreadedRenderer`在UI线程创建，主要执行了两步：
>
> - 构建View的DrawOp树，就是`DisplayList`。`DrawOp 表示 Drawing Operations`
> - 与渲染线程(`RenderThread`)进行通信

```java
  //ThreadedRenderer.java
    void draw(View view, AttachInfo attachInfo, DrawCallbacks callbacks,
            FrameDrawingCallback frameDrawingCallback) {
        attachInfo.mIgnoreDirtyState = true;

        final Choreographer choreographer = attachInfo.mViewRootImpl.mChoreographer;
        choreographer.mFrameInfo.markDrawStart();
        //构建View的DrawOp树
        updateRootDisplayList(view, callbacks);

        ...
        final long[] frameInfo = choreographer.mFrameInfo.mFrameInfo;
        if (frameDrawingCallback != null) {
            nSetFrameCallback(mNativeProxy, frameDrawingCallback);
        }
        //通知RenderThread线程绘制
        int syncResult = nSyncAndDrawFrame(mNativeProxy, frameInfo, frameInfo.length);
        ...
    }
```

#### updateRootDisplayList()

> 构建`DrawOp`树，构建`RootDisplayList`

```java
    private void updateRootDisplayList(View view, DrawCallbacks callbacks) {
       //更新View的displayList
        updateViewTreeDisplayList(view);

        if (mRootNodeNeedsUpdate || !mRootNode.isValid()) {
           //获取DisplayCanvas
            DisplayListCanvas canvas = mRootNode.start(mSurfaceWidth, mSurfaceHeight);
            try {
                final int saveCount = canvas.save();
                canvas.translate(mInsetLeft, mInsetTop);
                callbacks.onPreDraw(canvas);

                canvas.insertReorderBarrier();
               //displayListCanvas缓存View对应的drawOp节点
                canvas.drawRenderNode(view.updateDisplayListIfDirty());
                canvas.insertInorderBarrier();

                callbacks.onPostDraw(canvas);
                canvas.restoreToCount(saveCount);
                mRootNodeNeedsUpdate = false;
            } finally {
               //RootRenderNode填充所有节点
                mRootNode.end(canvas);
            }
        }
    }

    private void updateViewTreeDisplayList(View view) {
        view.mPrivateFlags |= View.PFLAG_DRAWN;
        view.mRecreateDisplayList = (view.mPrivateFlags & View.PFLAG_INVALIDATED)//invalidate()对应标记
                == View.PFLAG_INVALIDATED;//初始DecorView默认为 true
        view.mPrivateFlags &= ~View.PFLAG_INVALIDATED;
        view.updateDisplayListIfDirty();//更新节点
        view.mRecreateDisplayList = false;
    }
```

#### DecorView.updateDisplayListIfDirty()

> `updateRootDisplayList()`中对应的View就是`DecorView`，是所有View的顶层。

```java
//View.java
@NonNull
    public RenderNode updateDisplayListIfDirty() {
      ...
        if ((mPrivateFlags & PFLAG_DRAWING_CACHE_VALID) == 0
                || !renderNode.isValid()
                || (mRecreateDisplayList)) {
          ...
          final DisplayListCanvas canvas = renderNode.start(width, height);
          try {
                if (layerType == LAYER_TYPE_SOFTWARE) {//是否强制软件绘制
                    buildDrawingCache(true);
                    Bitmap cache = getDrawingCache(true);//获取绘制缓存
                    if (cache != null) {//缓存有效，复用缓存
                        canvas.drawBitmap(cache, 0, 0, mLayerPaint);
                    }
                } else {
                    // Fast path for layouts with no backgrounds
                    //ViewGroup不需要绘制，直接调用dispatchDraw
                    if ((mPrivateFlags & PFLAG_SKIP_DRAW) == PFLAG_SKIP_DRAW) {
                        dispatchDraw(canvas);
                        drawAutofilledHighlight(canvas);
                         ...
                    } else {
                      //ViewGroup(需要绘制) / View 直接调用draw
                        draw(canvas);
                    }
                }
            } finally {
               //缓存构建完成，放入渲染节点
                renderNode.end(canvas);
                setDisplayListProperties(renderNode);
            }
          
        }
      
    }
```

`DecorView`执行`updateDisplayListIfDirty()`，调用到`draw(Canvas)`，然后向下递归调用到`child.draw()`

`updateRootDisplayList()`主要执行以下几步：

- 更新`DecorView`操作缓存(DisplayList)——`updateViewTreeDisplayList(decorView)`
- 利用`DisplayCanvas`构建并缓存所有的`DrawOp(View的绘制操作)`——`mRootNode.start()`
- 将`DisplayListCanvas`缓存的`DrawOp`填充到`RenderNode(View)`——`View.updateDisplayListIfDirty()`
- 将`DecorView`的缓存`DrawOp`填充到`RootRenderNode`中——`mRootNode.end()`



![硬件绘制-updateDisplayListIfDirty()](/images/硬件绘制-updateDisplayListIfDirty.png)















### View硬件绘制相关

上一节中，通过`DecorView`递归调用`子View.updateDisplayListIfDirty()`不断填充`DisplayList`到对应View的`RenderNode`

```java
//View.java
public View(Context context) {
  ...
     //初始化渲染节点
     mRenderNode = RenderNode.create(getClass().getName(), new ViewAnimationHostBridge(this));
  ...
}

    boolean draw(Canvas canvas, ViewGroup parent, long drawingTime) {
       final boolean hardwareAcceleratedCanvas = canvas.isHardwareAccelerated();

        boolean drawingWithRenderNode = mAttachInfo != null
                && mAttachInfo.mHardwareAccelerated
                && hardwareAcceleratedCanvas;
        ...
        if (drawingWithRenderNode) {
           //继续执行到updateDisplayListIfDirty
            renderNode = updateDisplayListIfDirty();
            if (!renderNode.isValid()) {
                renderNode = null;
                drawingWithRenderNode = false;
            }
        }
    }

    public RenderNode updateDisplayListIfDirty() {
        final RenderNode renderNode = mRenderNode;
        if (!canHaveDisplayList()) {
            // can't populate RenderNode, don't try
            return renderNode;
        }

        if ((mPrivateFlags & PFLAG_DRAWING_CACHE_VALID) == 0 //绘制缓存无效
                || !renderNode.isValid() //渲染节点没有DisplayList
                || (mRecreateDisplayList)) { //需要刷新DisplayList
            // Don't need to recreate the display list, just need to tell our
            // children to restore/recreate theirs
            if (renderNode.isValid() //只要draw过一次后，一直返回true
                    && !mRecreateDisplayList) {//调用一些只需要displayList属性修改的方法
                //不需要重建 DisplayList
                mPrivateFlags |= PFLAG_DRAWN | PFLAG_DRAWING_CACHE_VALID;
                mPrivateFlags &= ~PFLAG_DIRTY_MASK;
                dispatchGetDisplayList();

                return renderNode; // no work needed
            }

            // If we got here, we're recreating it. Mark it as such to ensure that
            // we copy in child display lists into ours in drawChild()
            mRecreateDisplayList = true;

            int width = mRight - mLeft;
            int height = mBottom - mTop;
            int layerType = getLayerType();
           //获取DisplayListCanvas
            final DisplayListCanvas canvas = renderNode.start(width, height);

            try {
                if (layerType == LAYER_TYPE_SOFTWARE) {//软件绘制，绘制缓存存在直接复用
                    buildDrawingCache(true);
                    Bitmap cache = getDrawingCache(true);
                    if (cache != null) {
                        canvas.drawBitmap(cache, 0, 0, mLayerPaint);
                    }
                } else {
                    computeScroll();

                    canvas.translate(-mScrollX, -mScrollY);
                    //添加 缓存有效标记
                    mPrivateFlags |= PFLAG_DRAWN | PFLAG_DRAWING_CACHE_VALID;
                    mPrivateFlags &= ~PFLAG_DIRTY_MASK;

                    //ViewGroup不需要绘制，直接调用dispatchDraw
                    if ((mPrivateFlags & PFLAG_SKIP_DRAW) == PFLAG_SKIP_DRAW) {
                        dispatchDraw(canvas);
                        drawAutofilledHighlight(canvas);
                         ...
                    } else {
                      //ViewGroup(需要绘制) / View 直接调用draw
                        draw(canvas);
                    }
                }
            } finally {
               //RenderNode 收集DisplayList
                renderNode.end(canvas);
                setDisplayListProperties(renderNode);
            }
        } else {
            mPrivateFlags |= PFLAG_DRAWN | PFLAG_DRAWING_CACHE_VALID;
            mPrivateFlags &= ~PFLAG_DIRTY_MASK;
        }
        return renderNode;
    }

    //是否会有DisplayList = 是否开启硬件加速
    public boolean canHaveDisplayList() {
        return !(mAttachInfo == null || mAttachInfo.mThreadedRenderer == null);
    }

    //只有flag标记为 PFLAG_INVALIDATED ，调用需要 重建DisplayList
    mRecreateDisplayList = (mPrivateFlags & PFLAG_INVALIDATED) != 0;
```

根据上述源码可判断`View需要重新构建DisplayList(执行draw())`有以下条件：

1. `(mPrivateFlags & PFLAG_DRAWING_CACHE_VALID) == 0`当前View绘制缓存无效

   **mPrivateFlags没有`PFLAG_DRAWING_CACHE_VALID`标记**

2. `renderNode.isValid()==false` View对应的`DisplayList`尚未构建或者被销毁

   **只要View绘制过一次，就会一直返回true。除非`detached`**

3. `mRecreateDisplayList==true` View需要重新构建`DisplayList`

   **mPrivateFlags持有`PFLAG_INVALIDATED`标记**

能满足以上条件的就是调用`View.invalidate()`

```java
//View.java
    public void invalidate() {
        invalidate(true);
    }

    public void invalidate(boolean invalidateCache) {
        invalidateInternal(0, 0, mRight - mLeft, mBottom - mTop, invalidateCache, true);
    }

    void invalidateInternal(int l, int t, int r, int b, boolean invalidateCache,
            boolean fullInvalidate) {
      ...
            if (invalidateCache) {
                mPrivateFlags |= PFLAG_INVALIDATED; //添加PFLAG_INVALIDATED标志
                mPrivateFlags &= ~PFLAG_DRAWING_CACHE_VALID;//移除PFLAG_DRAWING_CACHE_VALID标志
            }
      
    }
```



#### dispatchGetDisplayList()

只会在不重建`DisplayList`情况下调用

```java
//View.java
// 只会在ViewGroup下实现，更新子View的DisplayList
    protected void dispatchGetDisplayList() {}


//ViewGroup.java
    @Override
    protected void dispatchGetDisplayList() {
        final int count = mChildrenCount;
        final View[] children = mChildren;
        for (int i = 0; i < count; i++) {
            final View child = children[i];
           //View可见 || 设置动画
            if (((child.mViewFlags & VISIBILITY_MASK) == VISIBLE || child.getAnimation() != null)) {
                recreateChildDisplayList(child);//调用子
            }
        }
        ...
    }

    private void recreateChildDisplayList(View child) {
        child.mRecreateDisplayList = (child.mPrivateFlags & PFLAG_INVALIDATED) != 0;//没有PFLAG_INVALIDATED 返回true
        child.mPrivateFlags &= ~PFLAG_INVALIDATED; //移除 PFLAG_INVALIDATED标志
        child.updateDisplayListIfDirty();
        child.mRecreateDisplayList = false; //执行完后 重置状态
    }
```

### RenderThread渲染UI

构建完`RootRenderNode`的`DisplayList——DrawOp树`之后，就需要准备渲染。*利用GPU将DisplayList绘制到屏幕上*。

#### ThreadedRenderer#nSyncAndFrame

构建DisplayList完毕后，向下执行到`nSyncAndDrawFrame()`

```java
//ThreadedRenderer.java
    void draw(View view, AttachInfo attachInfo, DrawCallbacks callbacks,
            FrameDrawingCallback frameDrawingCallback) {
      ...
        //构建DisplayList
        updateRootDisplayList(view, callbacks);
      ...
      //开始绘制DisplayList
        int syncResult = nSyncAndDrawFrame(mNativeProxy, frameInfo, frameInfo.length);
    }

    private static native int nSyncAndDrawFrame(long nativeProxy, long[] frameInfo, int size);
```

`nSyncAndDrawFrame()`切换到`Native`层执行

```cpp
//core/jni/android_view_ThreadedRenderer.cpp
static int android_view_ThreadedRenderer_syncAndDrawFrame(JNIEnv* env, jobject clazz,
        jlong proxyPtr, jlongArray frameInfo, jint frameInfoSize) {
    LOG_ALWAYS_FATAL_IF(frameInfoSize != UI_THREAD_FRAME_INFO_SIZE,
            "Mismatched size expectations, given %d expected %d",
            frameInfoSize, UI_THREAD_FRAME_INFO_SIZE);
    RenderProxy* proxy = reinterpret_cast<RenderProxy*>(proxyPtr);
    env->GetLongArrayRegion(frameInfo, 0, frameInfoSize, proxy->frameInfo());
    return proxy->syncAndDrawFrame();
}
```

通过`RenderProxy`继续执行

```cpp
//libs/hwui/renderthread/RenderProxy.cpp
int RenderProxy::syncAndDrawFrame() {
    return mDrawFrameTask.drawFrame();
}
```

#### DrawFrameTask#drawFrame()

调用了`DrawFrameTask#drawFrame()`

```cpp
//libs/hwui/renderthread/DrawFrameTask.cpp
int DrawFrameTask::drawFrame() {
    LOG_ALWAYS_FATAL_IF(!mContext, "Cannot drawFrame with no CanvasContext!");

    mSyncResult = SyncResult::OK;
    mSyncQueued = systemTime(CLOCK_MONOTONIC);
    postAndWait();

    return mSyncResult;
}

void DrawFrameTask::postAndWait() {
    AutoMutex _lock(mLock);
    mRenderThread->queue().post([this]() { run(); });
    mSignal.wait(mLock);
}

void DrawFrameTask::run() {
    ATRACE_NAME("DrawFrame");

    bool canUnblockUiThread;
    bool canDrawThisFrame;
    {
        TreeInfo info(TreeInfo::MODE_FULL, *mContext);
      //同步帧状态
        canUnblockUiThread = syncFrameState(info);
        canDrawThisFrame = info.out.canDrawThisFrame;

        if (mFrameCompleteCallback) {
            mContext->addFrameCompleteListener(std::move(mFrameCompleteCallback));
            mFrameCompleteCallback = nullptr;
        }
    }

    // Grab a copy of everything we need
    CanvasContext* context = mContext;
    std::function<void(int64_t)> callback = std::move(mFrameCallback);
    mFrameCallback = nullptr;

    // From this point on anything in "this" is *UNSAFE TO ACCESS*
    if (canUnblockUiThread) {
        unblockUiThread();
    }

    // Even if we aren't drawing this vsync pulse the next frame number will still be accurate
    if (CC_UNLIKELY(callback)) {
        context->enqueueFrameWork([callback, frameNr = context->getFrameNumber()]() {
            callback(frameNr);
        });
    }

    if (CC_LIKELY(canDrawThisFrame)) {
      //执行绘制流程
        context->draw();
    } else {
        // wait on fences so tasks don't overlap next frame
        context->waitOnFences();
    }

    if (!canUnblockUiThread) {
        unblockUiThread();
    }
}
```

主要执行过程为两步：

- 调用`syncFrameState()`同步Frame信息
- 调用`CanvasContext.draw()`开始绘制

##### syncFrameState

```cpp
bool DrawFrameTask::syncFrameState(TreeInfo& info) {
    ATRACE_CALL();
    int64_t vsync = mFrameInfo[static_cast<int>(FrameInfoIndex::Vsync)];
    mRenderThread->timeLord().vsyncReceived(vsync);
    bool canDraw = mContext->makeCurrent();
    mContext->unpinImages();

    for (size_t i = 0; i < mLayers.size(); i++) {
        mLayers[i]->apply();
    }
    mLayers.clear();
    mContext->setContentDrawBounds(mContentDrawBounds);
  
    mContext->prepareTree(info, mFrameInfo, mSyncQueued, mTargetNode);
   ...
}
```



#### CanvasContext初始化

> CanvasContext是 渲染的上下文，可以选择不同的渲染模式。
>
> 目前分为三种:
>
> - OpenGL
> - SkiaGL
> - SkiaVulkan

先分析`CanvasContext#create()`判断使用哪种渲染模式

```cpp
CanvasContext* CanvasContext::create(RenderThread& thread, bool translucent,
                                     RenderNode* rootRenderNode, IContextFactory* contextFactory) {
    auto renderType = Properties::getRenderPipelineType();

    switch (renderType) {
        case RenderPipelineType::OpenGL:
            return new CanvasContext(thread, translucent, rootRenderNode, contextFactory,
                                     std::make_unique<OpenGLPipeline>(thread));
        case RenderPipelineType::SkiaGL:
            return new CanvasContext(thread, translucent, rootRenderNode, contextFactory,
                                     std::make_unique<skiapipeline::SkiaOpenGLPipeline>(thread));
        case RenderPipelineType::SkiaVulkan:
            return new CanvasContext(thread, translucent, rootRenderNode, contextFactory,
                                     std::make_unique<skiapipeline::SkiaVulkanPipeline>(thread));
        default:
            LOG_ALWAYS_FATAL("canvas context type %d not supported", (int32_t)renderType);
            break;
    }
    return nullptr;
}
```

就拿第一个`OpenGLPipeline`进行分析，其他的和他流程一致，不过绘制方式不同

##### OpenGLPipeline

```cpp
//libs/hwui/renderthread/OpenGLPipeline.cpp
OpenGLPipeline::OpenGLPipeline(RenderThread& thread)
        : mEglManager(thread.eglManager()), mRenderThread(thread) {}

```

创建了`OpenGLPipeline`之后，对应的也创建了`EglManager`对象。

##### EglManager

> 主要封装了 opengl相关的操作

###### 初始化

```cpp
void EglManager::initialize() {
    if (hasEglContext()) return;

    ATRACE_NAME("Creating EGLContext");

  //获取EglDisplay对象
    mEglDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    LOG_ALWAYS_FATAL_IF(mEglDisplay == EGL_NO_DISPLAY, "Failed to get EGL_DEFAULT_DISPLAY! err=%s",
                        eglErrorString());

    EGLint major, minor;
    initExtensions();

    // Now that extensions are loaded, pick a swap behavior
    if (Properties::enablePartialUpdates) {
        // An Adreno driver bug is causing rendering problems for SkiaGL with
        // buffer age swap behavior (b/31957043).  To temporarily workaround,
        // we will use preserved swap behavior.
        if (Properties::useBufferAge && EglExtensions.bufferAge) {
            mSwapBehavior = SwapBehavior::BufferAge;
        } else {
            mSwapBehavior = SwapBehavior::Preserved;
        }
    }

    loadConfigs();
   //创建egl上下文你
    createContext();
   //创建离屏渲染Buffer
    createPBufferSurface();
    makeCurrent(mPBufferSurface);
    DeviceInfo::initialize();
    mRenderThread.renderState().onGLContextCreated();
```

目前只是创建了`PBufferSurface`，在没有`WindowSurface`的时候是无法渲染显示在屏幕上的。

> `PBufferSurface`：在显存中开辟一块空间，存放渲染后的数据。
>
> `WindowSurface`：在屏幕上的一块显示区域的封装，渲染后就显示在屏幕上

###### 设置`WindowSurface`

> 主要是在`ViewRootImpl#performTraversals()`进行设置的

```java
//ViewRootImpl.java
    private void performTraversals() {
      
      ...
                        if (mAttachInfo.mThreadedRenderer != null) {
                            try {
                              //初始化ThreadedRenderer 并赋值surface 用于绘制显示
                                hwInitialized = mAttachInfo.mThreadedRenderer.initialize(
                                        mSurface);
                                if (hwInitialized && (host.mPrivateFlags
                                        & View.PFLAG_REQUEST_TRANSPARENT_REGIONS) == 0) {
                                    // Don't pre-allocate if transparent regions
                                    // are requested as they may not be needed
                                    mSurface.allocateBuffers();
                                }
                            } catch (OutOfResourcesException e) {
                                handleOutOfResourcesException(e);
                                return;
                            }
                        }      
    }
```

`ThreadedRenderer#initalize`

```java
    boolean initialize(Surface surface) throws OutOfResourcesException {
        boolean status = !mInitialized;
        mInitialized = true;
        updateEnabledState(surface);
      
        nInitialize(mNativeProxy, surface);
        return status;
    }
```

切换到Native层继续执行

```cpp
static void android_view_ThreadedRenderer_initialize(JNIEnv* env, jobject clazz,
        jlong proxyPtr, jobject jsurface) {
    RenderProxy* proxy = reinterpret_cast<RenderProxy*>(proxyPtr);
    sp<Surface> surface = android_view_Surface_getSurface(env, jsurface);
    proxy->initialize(surface);
}

//RenderProxy.cpp
void RenderProxy::initialize(const sp<Surface>& surface) {
    mRenderThread.queue().post(
            [ this, surf = surface ]() mutable { mContext->setSurface(std::move(surf)); });
}

//CanvasContext.cpp
void CanvasContext::setSurface(sp<Surface>&& surface) {
    ATRACE_CALL();

    mNativeSurface = std::move(surface);

    ColorMode colorMode = mWideColorGamut ? ColorMode::WideColorGamut : ColorMode::Srgb;
    bool hasSurface = mRenderPipeline->setSurface(mNativeSurface.get(), mSwapBehavior, colorMode);

    mFrameNumber = -1;

    if (hasSurface) {
        mHaveNewSurface = true;
        mSwapHistory.clear();
    } else {
        mRenderThread.removeFrameCallback(this);
        mGenerationID++;
    }
}
```

此处的`mRenderPipeline`为上节的`OpenGLPipeline`

```cpp
//libs/hwui/renderthread/OpenGLPipeline.cpp
bool OpenGLPipeline::setSurface(Surface* surface, SwapBehavior swapBehavior, ColorMode colorMode) {
    if (mEglSurface != EGL_NO_SURFACE) {
        mEglManager.destroySurface(mEglSurface);
        mEglSurface = EGL_NO_SURFACE;
    }

    if (surface) {
        const bool wideColorGamut = colorMode == ColorMode::WideColorGamut;
        mEglSurface = mEglManager.createSurface(surface, wideColorGamut);
    }

    return false;
}

```

执行到`createSurface()`创建`WindowSurface`

```cpp
EGLSurface EglManager::createSurface(EGLNativeWindowType window, bool wideColorGamut) {
  ...
    EGLSurface surface = eglCreateWindowSurface(
            mEglDisplay, wideColorGamut ? mEglConfigWideGamut : mEglConfig, window, attribs);
    return surface;
}
```

到此创建`WindowSurface`完毕。

#### CanvasContext#draw

```cpp
void CanvasContext::draw() {
  ...
    //开始绘制
    bool drew = mRenderPipeline->draw(frame, windowDirty, dirty, mLightGeometry, &mLayerUpdateQueue,
                                      mContentDrawBounds, mOpaque, mWideColorGamut, mLightInfo,
                                      mRenderNodes, &(profiler()));
  
  //交换缓冲区
    bool didSwap =
            mRenderPipeline->swapBuffers(frame, drew, windowDirty, mCurrentFrameInfo, &requireSwap);  
}
```

##### OpenGLPipeline#draw

```cpp
bool OpenGLPipeline::draw(const Frame& frame, const SkRect& screenDirty, const SkRect& dirty,
                          const FrameBuilder::LightGeometry& lightGeometry,
                          LayerUpdateQueue* layerUpdateQueue, const Rect& contentDrawBounds,
                          bool opaque, bool wideColorGamut,
                          const BakedOpRenderer::LightInfo& lightInfo,
                          const std::vector<sp<RenderNode>>& renderNodes,
                          FrameInfoVisualizer* profiler) {
    mEglManager.damageFrame(frame, dirty);

    bool drew = false;

    auto& caches = Caches::getInstance();
    FrameBuilder frameBuilder(dirty, frame.width(), frame.height(), lightGeometry, caches);

    frameBuilder.deferLayers(*layerUpdateQueue);
    layerUpdateQueue->clear();

    frameBuilder.deferRenderNodeScene(renderNodes, contentDrawBounds);

    BakedOpRenderer renderer(caches, mRenderThread.renderState(), opaque, wideColorGamut,
                             lightInfo);
    frameBuilder.replayBakedOps<BakedOpDispatcher>(renderer);
    ProfileRenderer profileRenderer(renderer);
    profiler->draw(profileRenderer);
  //调用GPU进行渲染
    drew = renderer.didDraw();

    // post frame cleanup
    caches.clearGarbage();
    caches.pathCache.trim();
    caches.tessellationCache.trim();
}
```

##### OpenGLPipeline#swapBuffers

```cpp
bool OpenGLPipeline::swapBuffers(const Frame& frame, bool drew, const SkRect& screenDirty,
                                 FrameInfo* currentFrameInfo, bool* requireSwap) {
    GL_CHECKPOINT(LOW);

    // Even if we decided to cancel the frame, from the perspective of jank
    // metrics the frame was swapped at this point
    currentFrameInfo->markSwapBuffers();

    *requireSwap = drew || mEglManager.damageRequiresSwap();

    if (*requireSwap && (CC_UNLIKELY(!mEglManager.swapBuffers(frame, screenDirty)))) {
        return false;
    }

    return *requireSwap;
}
```



![img](/images/CPU GPU通信模型)

根据图示渲染过程主要分为5阶段：

1. UI线程创建OpenGL渲染需要的命令及数据——`构建DrawOp树`
2. CPU将数据共享给GPU，使用`匿名共享内存`
3. 通知GPU渲染
4. swapBuffers，并通知`SurfaceFlinger`开始合成图层
5. SurfaceFlinger开始合成图层



### 硬件绘制流程



![硬件绘制流程](/images/硬件绘制流程.jpg)

如上图所示：

> 硬件绘制的流程，主要包含两个步骤：**录制 、 回放**。
>
> `录制`：需要View的`draw()`参与，需要记录View的绘制步骤，并编译为**绘制指令**(`drawOp`)
>
> `回放`：还原绘制内容，只需要还原**绘制指令**，而且这个绘制指令是可以修改的，修改的过程是不需要重新触发`draw()`。



### 硬件渲染过程

![RenderThread渲染过程](/images/RenderThread渲染过程.jpg)

补充：硬件管线里常见高成本操作包括：

- 频繁`saveLayer`（离屏缓冲）
- 大面积半透明叠加
- 复杂裁剪/阴影效果
- 高频创建与销毁大纹理

这些操作容易推高GPU和合成负载，导致慢帧。







## 软件绘制VS硬件绘制

| 渲染场景                       | 软件绘制                 | 硬件绘制                                                     | 效果分析                                                 |
| ------------------------------ | ------------------------ | ------------------------------------------------------------ | -------------------------------------------------------- |
| 页面初始化                     | 绘制所有View             | 创建所有`DisplayList`                                        | GPU负责复杂的计算任务                                    |
| 调用背景透明TextView.setText() | 重绘脏区所有View         | TextView及每一级父View重建`DisplayList`                      | 重叠的兄弟节点不需要进行重绘，GPU会自行处理              |
| TextView逐帧播放动画           | 每帧动画都要重绘脏区View | 第一帧需要重建`DisplayList`<br>后续只要更新对应的`DisplayList`即可 | 刷新每帧性能提升                                         |
| 修改TextView透明度             | 重绘脏区所有View         | 直接调用`RenderNode.setAlpha()`即可                          | 只触发`DecorView.updateDisplayListIfDirty`，不再往下遍历 |

补充：主线程不卡并不代表一定流畅。

- UI线程负责遍历和录制DisplayList。
- RenderThread负责渲染命令提交与GPU协作。
- RenderThread/GPU/合成侧任一环节过载，都可能掉帧。



## 绘制缓存

![绘制缓存](/images/Android绘制-绘制缓存.png)

> 绘图缓存是指一个`Bitmap(软件绘制)`和`(硬件绘制)`，保存的是控件及其子控件的一个快照。
>
> 可以通过`View.setLayerType()`设置使用何种类型的缓存。
>
> `LAYER_TYPE_NONE`：视图正常渲染，不受屏幕外缓冲区支持。**默认值**
>
> `LAYER_TYPE_SOFTWARE`：标识这个View有一个`Software Layer`，在一定条件下，会变成`bitmap`对象。
>
> `LAYER_TYPE_HARDWARE`：标识这个VIew有一个`Hardware Layer`，通过GPU来实现。依赖`硬件加速`实现，如果未开启`硬件加速`，按照`Software Layer`实现。

### 软件绘制缓存

```java
//View.java
    boolean draw(Canvas canvas, ViewGroup parent, long drawingTime) {
     ...
        Bitmap cache = null;
        int layerType = getLayerType(); // layerType默认为LAYER_TYPE_NONE
        if (layerType == LAYER_TYPE_SOFTWARE || !drawingWithRenderNode) {//软件绘制条件
             if (layerType != LAYER_TYPE_NONE) {//必须设置 `LAYER_TYPE_SOFTWARE` 或 LAYER_TYPE_HARDWARE 缓存生效
                 // If not drawing with RenderNode, treat HW layers as SW
                 layerType = LAYER_TYPE_SOFTWARE;//设置 软件layer
                 buildDrawingCache(true);//构建缓存
            }
            cache = getDrawingCache(true);
        }
    }

    public void buildDrawingCache(boolean autoScale) {
       buildDrawingCacheImpl(autoScale);
    }

    private void buildDrawingCacheImpl(boolean autoScale) {
     ...
       quality = Bitmap.Config.ARGB_8888;//默认缓存bitmap图像类型
       bitmap = Bitmap.createBitmap(mResources.getDisplayMetrics(),
                        width, height, quality);
       bitmap.setDensity(getResources().getDisplayMetrics().densityDpi);
       if (autoScale) {
          mDrawingCache = bitmap;
       } else {
          mUnscaledDrawingCache = bitmap;
       }
      ...
    }
```

要启用`软件绘制缓存`，必须调用`View.setLayerType()`设置`LAYER_TYPE_HARDDWARE、LAYER_TYPE_SOFTWARE`。通过`buildDrawingCache()`生成`绘制缓存`，对应会生成两个缓存对象：

- `mDrawingCache`：根据兼容模式进行放大或缩小
- `mUnscaledDrawingCache`：反映了控件的真实尺寸，多用作控件截图。

后续通过`getDrawingCache()`获取缓存内容。

```java
//View.java
boolean draw(Canvas canvas, ViewGroup parent, long drawingTime) {
 final boolean drawingWithDrawingCache = cache != null && !drawingWithRenderNode; //是否使用缓存
 ...
 if(!drawingWithDrawingCache) {//未使用缓存
    if (drawingWithRenderNode) {//硬件绘制
        mPrivateFlags &= ~PFLAG_DIRTY_MASK;
        ((DisplayListCanvas) canvas).drawRenderNode(renderNode);
    } else {//软件绘制
        // 需要回调到`onDraw()`
        if ((mPrivateFlags & PFLAG_SKIP_DRAW) == PFLAG_SKIP_DRAW) {
            mPrivateFlags &= ~PFLAG_DIRTY_MASK;
            dispatchDraw(canvas);
        } else {
            draw(canvas);
        }
    }
 }else if(cache!=null){
   canvas.drawBitmap(cache...)//将缓存绘制于画布上
 }
}
```



### 硬件绘制缓存

`DisplayList`可以理解为缓存，开启`硬件加速`时，只要每次回放`DisplayList`即可。



### 绘制缓存的开启原则

- 不要为`十分轻量级的控件`启用绘制缓存。可能缓存绘制的开销 > 控件重绘开销
- 为`很少发生内容改变的控件`启用绘制缓存。避免`invalidate()`时产生额外的缓存绘制操作
- 当父控件需要频繁改变子控件的位置或变换时对`子控件`启用绘制缓存，避免频繁重绘子控件。通过`ViewGroup.setChildrenDrawingWithCache()`启用子控件绘制缓存。

补充：局部降级策略。

- 优先局部处理，不建议全局关闭硬件加速。
- 仅对存在兼容问题的View切`LAYER_TYPE_SOFTWARE`。
- 修复后应尽量恢复默认策略，避免长期性能损耗。



## 属性动画更新相关

![Android绘制-属性动画更新相关](/images/Android绘制-属性动画更新相关.png)

在{%post_link Android动画-属性动画%}中讲到最后通过反射调用`View.setXX()`去执行动画。

```java
//view.java
    public void setScaleX(float scaleX) {
        if (scaleX != getScaleX()) {
            scaleX = sanitizeFloatPropertyValue(scaleX, "scaleX");
            invalidateViewProperty(true, false);
            mRenderNode.setScaleX(scaleX);//更新对应View的displayList
            invalidateViewProperty(false, true);

            invalidateParentIfNeededAndWasQuickRejected();
            notifySubtreeAccessibilityStateChangedIfNeeded();
        }
    }
```

关键在于`invalidateViewProperty()`调用界面刷新

```java
    void invalidateViewProperty(boolean invalidateParent, boolean forceRedraw) {
        if (!isHardwareAccelerated()
                || !mRenderNode.isValid()
                || (mPrivateFlags & PFLAG_DRAW_ANIMATION) != 0) {//软件绘制
            if (invalidateParent) {
                invalidateParentCaches();
            }
            if (forceRedraw) {
                mPrivateFlags |= PFLAG_DRAWN; // force another invalidation with the new orientation
            }
            invalidate(false);
        } else {
            damageInParent();//硬件绘制
        }
    }

    protected void damageInParent() {
        if (mParent != null && mAttachInfo != null) {
            mParent.onDescendantInvalidated(this, this);//一层层向上层调用
        }
    }
```

`mParent`一般指向`ViewGroup`

```java
//ViewGroup.java
    public void onDescendantInvalidated(@NonNull View child, @NonNull View target) {
      ...
        if ((target.mPrivateFlags & ~PFLAG_DIRTY_MASK) != 0) {
            // We lazily use PFLAG_DIRTY, since computing opaque isn't worth the potential
            // optimization in provides in a DisplayList world.
            mPrivateFlags = (mPrivateFlags & ~PFLAG_DIRTY_MASK) | PFLAG_DIRTY;

            // simplified invalidateChildInParent behavior: clear cache validity to be safe...
            //标记缓存无效
            mPrivateFlags &= ~PFLAG_DRAWING_CACHE_VALID;
        }
      ...
        if (mParent != null) {
          //继续向顶层View请求
            mParent.onDescendantInvalidated(this, target);
        }
    }
```

在`onDescendantInvalidated()`主要移除了`PFLAG_DRAWING_CACHE_VALID`标志

最顶层的View是`DecorView`，而`ViewRootImpl`就是`DecorView的parent`

```java
//ViewRootImpl.java
    @Override
    public void onDescendantInvalidated(@NonNull View child, @NonNull View descendant) {
        if ((descendant.mPrivateFlags & PFLAG_DRAW_ANIMATION) != 0) {
            mIsAnimating = true;
        }
        invalidate();
    }

    void invalidate() {
        mDirty.set(0, 0, mWidth, mHeight);
        if (!mWillDrawSoon) {
            scheduleTraversals();//开始执行绘制流程
        }
    }
```

总结：属性动画最后反射调用`View.setXX()`更新View属性时，调用到`invalidateViewProperty()`，主要实现的功能就是`移除PFLAG_DRAWING_CACHE_VALID`标志。在执行绘制过程中，在回到`View.updateDisplayListIfDirty()`时

```java
 public RenderNode updateDisplayListIfDirty() {
   ...
      if ((mPrivateFlags & PFLAG_DRAWING_CACHE_VALID) == 0 //满足该条件
                || !renderNode.isValid()
                || (mRecreateDisplayList)) {
            // Don't need to recreate the display list, just need to tell our
            // children to restore/recreate theirs
            if (renderNode.isValid()
                    && !mRecreateDisplayList) {//未设置 PFLAG_INVALIDATED标志
                mPrivateFlags |= PFLAG_DRAWN | PFLAG_DRAWING_CACHE_VALID;
                mPrivateFlags &= ~PFLAG_DIRTY_MASK;
                dispatchGetDisplayList();//只要刷新DisplayList

                return renderNode; // no work needed
            }
        ...
 }
```

**在开启硬件加速的条件下，属性动画更新过程中不会回调`onDraw()`**



## 关键节点

### `DisplayList`初始化

`DisplayListCanvas.start()` -> `DisplayListCanvas.obtain()`->`nCreateDisplayListCanvas`

```c++
//android_view_DisplayListCanvas.cpp
static jlong android_view_DisplayListCanvas_createDisplayListCanvas(jlong renderNodePtr,
        jint width, jint height) {
    RenderNode* renderNode = reinterpret_cast<RenderNode*>(renderNodePtr);
    return reinterpret_cast<jlong>(Canvas::create_recording_canvas(width, height, renderNode));
}

//Canvas.cpp
Canvas* Canvas::create_recording_canvas(int width, int height, uirenderer::RenderNode* renderNode) {
    if (uirenderer::Properties::isSkiaEnabled()) {
        return new uirenderer::skiapipeline::SkiaRecordingCanvas(renderNode, width, height);
    }
    return new uirenderer::RecordingCanvas(width, height);
}

//Properrties.cpp
bool Properties::isSkiaEnabled() {
    auto renderType = getRenderPipelineType();//分为三种类型 SkiaGL SkiaVulkan OpenGL(默认)
    return RenderPipelineType::SkiaGL == renderType || RenderPipelineType::SkiaVulkan == renderType;
}
```

```c++
//RecordingCanvas.cpp
RecordingCanvas::RecordingCanvas(size_t width, size_t height)
        : mState(*this), mResourceCache(ResourceCache::getInstance()) {
    resetRecording(width, height);
}

void RecordingCanvas::resetRecording(int width, int height, RenderNode* node) {
    LOG_ALWAYS_FATAL_IF(mDisplayList, "prepareDirty called a second time during a recording!");
    mDisplayList = new DisplayList();//初始化DisplayList

    mState.initializeRecordingSaveStack(width, height);

    mDeferredBarrierType = DeferredBarrierType::InOrder;
}
```



### 插入DrawOp到DisplayList

`DisplayListCanvas`内部也包含了各种`drawXX()`，例如`drawLines()、drawText()`等。在调用这些方法后，会把对应的绘制操作转换为`drawOp`

```c++
//DisplayListCanvas.java
public final class DisplayListCanvas extends RecordingCanvas {
 ...
   //所有绘制方法由RecordCanvas实现
    public void drawCircle(CanvasProperty<Float> cx, CanvasProperty<Float> cy,
            CanvasProperty<Float> radius, CanvasProperty<Paint> paint) {
        nDrawCircle(mNativeCanvasWrapper, cx.getNativeContainer(), cy.getNativeContainer(),
                radius.getNativeContainer(), paint.getNativeContainer());
    }
}

//RecordingCanvas.java
    @Override
    public final void drawLine(float startX, float startY, float stopX, float stopY,
            @NonNull Paint paint) {
        nDrawLine(mNativeCanvasWrapper, startX, startY, stopX, stopY, paint.getNativeInstance());
    }

```

`drawCircle()`和`drawRoundRect()`由`DisplayListCanvas`实现。其他的绘制方法交由`RecordingCanvas`实现。

```c++
//android_view_DisplayListCanvas.cpp
static void android_view_DisplayListCanvas_drawCircleProps(jlong canvasPtr,
        jlong xPropPtr, jlong yPropPtr, jlong radiusPropPtr, jlong paintPropPtr) {
    Canvas* canvas = reinterpret_cast<Canvas*>(canvasPtr);
    CanvasPropertyPrimitive* xProp = reinterpret_cast<CanvasPropertyPrimitive*>(xPropPtr);
    CanvasPropertyPrimitive* yProp = reinterpret_cast<CanvasPropertyPrimitive*>(yPropPtr);
    CanvasPropertyPrimitive* radiusProp = reinterpret_cast<CanvasPropertyPrimitive*>(radiusPropPtr);
    CanvasPropertyPaint* paintProp = reinterpret_cast<CanvasPropertyPaint*>(paintPropPtr);
    canvas->drawCircle(xProp, yProp, radiusProp, paintProp);
}
```



```c++
//RecordingCanvas.h
    virtual void drawLine(float startX, float startY, float stopX, float stopY,
                          const SkPaint& paint) override {
        float points[4] = {startX, startY, stopX, stopY};
        drawLines(points, 4, paint);
    }

//RecordingCanvas.cpp
void RecordingCanvas::drawLines(const float* points, int floatCount, const SkPaint& paint) {
    if (CC_UNLIKELY(floatCount < 4 || paint.nothingToDraw())) return;
    floatCount &= ~0x3;  // round down to nearest four
 
    addOp(alloc().create_trivial<LinesOp>(
            calcBoundsOfPoints(points, floatCount), *mState.currentSnapshot()->transform,
            getRecordedClip(), refPaint(&paint), refBuffer<float>(points, floatCount), floatCount));
}
```

通过`addOp()`将`DrawLine`的绘制操作缓存到`displayList`。

### 调试闭环建议

可按以下顺序排查：

1. `Profile GPU Rendering`：先看是否存在连续慢帧。
2. `Debug GPU Overdraw`：确认是否有明显过度绘制。
3. `adb shell dumpsys gfxinfo <package> framestats`：定位帧耗时分布。
4. Perfetto/System Trace：联动观察UI线程、RenderThread、SurfaceFlinger时间线。



## 参考链接

{% post_link View的工作原理 View的绘制过程%}

[Android官方文档-硬件加速](https://developer.android.com/guide/topics/graphics/hardware-accel?hl=zh-cn)

[DisplayList构建过程分析](https://blog.csdn.net/Luoshengyang/article/details/45943255)

[Android硬件加速原理与实现简介](https://tech.meituan.com/2017/01/19/hardware-accelerate.html)

[RenderThread与OpenGL GPU渲染](https://www.jianshu.com/p/dd800800145b)

[Android 中的 Hardware Layer 详解](https://www.androidperformance.com/2019/07/27/Android-Hardware-Layer/)

[深入浅出Android BufferQueue](https://zhuanlan.zhihu.com/p/62813895)

[BufferQueue](https://www.jianshu.com/p/f808813880b0)

<!-- https://www.jianshu.com/p/abfaea892611 ， https://blog.csdn.net/jinzhuojun/article/details/54234354 https://www.jianshu.com/p/40f660e17a73 -->
