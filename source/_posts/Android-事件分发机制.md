---
title: Android-事件分发机制
typora-root-url: ../
date: 2020-11-20 10:29:32
tags: Android
top: 9
---

> 当用户触摸屏幕或者按键操作。
>
> 1. 首先触发硬件驱动，驱动收到事件后，将相应事件写入到输入设备节点
> 2. 输入系统取出内核事件，封装成为KeyEvent或MotionEvent
> 3. 交付给对应的Window消费该事件。

![事件分发机制xmind](/images/Android事件分发机制xmind.png)

![input](/images/真·事件分发)

## 硬件中断

![硬件中断](/images/事件分发-硬件中断.png)

物理设备将数据发送给内核是通过`设备驱动`传输的，在`dev/input/`目录下有几个设备文件`eventX`。

其中`event0`对应的就是触摸屏，当触摸屏的驱动被挂载后，驱动程序就会进行初始化。

当触发对应的硬件中断后，就会调用对应的处理方法，把对应事件写到`设备节点(/dev/input/event0)`中.

![img](/images/硬件中断流程.png)



## IMS获取内核事件

### IMS启动过程

![启动IMS](/images/事件分发-启动IMS.png)

在{% post_link Android-系统启动过程%}有介绍系统的启动流程，其中`IMS`属于`system_server`，随着`system_server`的启动而启动。

```java
//SystemServer.java
    private void startOtherServices() {
      ...
        InputManagerService inputManager = null;
      ...
            traceBeginAndSlog("StartInputManagerService");
      //新建IMS对象
            inputManager = new InputManagerService(context);
            traceEnd();        
      
      //启动IMS
            traceBeginAndSlog("StartInputManager");
            inputManager.setWindowManagerCallbacks(wm.getInputMonitor());//与window进行绑定
            inputManager.start();
            traceEnd();      
      
    }
```

```java
//InputManagerService.java
    public InputManagerService(Context context) {
        this.mContext = context;
        this.mHandler = new InputManagerHandler(DisplayThread.get().getLooper());
      ...
        //初始化Native对象
        mPtr = nativeInit(this, mContext, mHandler.getLooper().getQueue());

        LocalServices.addService(InputManagerInternal.class, new LocalService());
    }
```

`nativeInit()`执行在Native层

```c++
//services/core/jni/com_android_server_input_InputManagerService.cpp
static jlong nativeInit(JNIEnv* env, jclass /* clazz */,
        jobject serviceObj, jobject contextObj, jobject messageQueueObj) {
  //获取Native的消息队列
    sp<MessageQueue> messageQueue = android_os_MessageQueue_getMessageQueue(env, messageQueueObj);
  ...
    //创建Native的 InputManager对象
    NativeInputManager* im = new NativeInputManager(contextObj, serviceObj,
            messageQueue->getLooper());
    //增加强引用
    im->incStrong(0);
   //返回 NativeInputManager的指针
    return reinterpret_cast<jlong>(im);
}
```

```java
//services/core/jni/com_android_server_input_InputManagerService.cpp
NativeInputManager::NativeInputManager(jobject contextObj,
        jobject serviceObj, const sp<Looper>& looper) :
        mLooper(looper), mInteractive(true) {
    JNIEnv* env = jniEnv();

    mContextObj = env->NewGlobalRef(contextObj);
    mServiceObj = env->NewGlobalRef(serviceObj);//IMS对象

    {
        AutoMutex _l(mLock);
        mLocked.systemUiVisibility = ASYSTEM_UI_VISIBILITY_STATUS_BAR_VISIBLE;
        mLocked.pointerSpeed = 0;
        mLocked.pointerGesturesEnabled = true;
        mLocked.showTouches = false;
        mLocked.pointerCapture = false;
    }
    mInteractive = true;
   //初始EventHub对象
    sp<EventHub> eventHub = new EventHub();
   //初始InputManager对象
    mInputManager = new InputManager(eventHub, this, this);
}
```

#### 初始EventHub

![EventHub](/images/IMS-EventHub.png)

`EventHub`主要用于**监控设备节点是否更新**

```c++
//frameworks/native/services/inputflinger/EventHub.cpp
static const char *WAKE_LOCK_ID = "KeyEvents";
static const char *DEVICE_PATH = "/dev/input";//设备文件

EventHub::EventHub(void) :
        mBuiltInKeyboardId(NO_BUILT_IN_KEYBOARD), mNextDeviceId(1), mControllerNumbers(),
        mOpeningDevices(0), mClosingDevices(0),
        mNeedToSendFinishedDeviceScan(false),
        mNeedToReopenDevices(false), mNeedToScanDevices(true),
        mPendingEventCount(0), mPendingEventIndex(0), mPendingINotify(false) {
    acquire_wake_lock(PARTIAL_WAKE_LOCK, WAKE_LOCK_ID);
//创建epoll实例
    mEpollFd = epoll_create(EPOLL_SIZE_HINT);

//创建iNotify实例
    mINotifyFd = inotify_init();
//iNotify实例 监听 DEVICE_PATH 
    int result = inotify_add_watch(mINotifyFd, DEVICE_PATH, IN_DELETE | IN_CREATE);
          
    struct epoll_event eventItem;
    memset(&eventItem, 0, sizeof(eventItem));
    eventItem.events = EPOLLIN;
    eventItem.data.u32 = EPOLL_ID_INOTIFY;
//epoll 监听 iNotify实例
    result = epoll_ctl(mEpollFd, EPOLL_CTL_ADD, mINotifyFd, &eventItem);

    int wakeFds[2];
    result = pipe(wakeFds);//创造管道

    mWakeReadPipeFd = wakeFds[0];
    mWakeWritePipeFd = wakeFds[1];

//切换非阻塞方式进行读写
    result = fcntl(mWakeReadPipeFd, F_SETFL, O_NONBLOCK);
    result = fcntl(mWakeWritePipeFd, F_SETFL, O_NONBLOCK);

    eventItem.data.u32 = EPOLL_ID_WAKE;
//epoll监听 管道实例
    result = epoll_ctl(mEpollFd, EPOLL_CTL_ADD, mWakeReadPipeFd, &eventItem);

    int major, minor;
    getLinuxRelease(&major, &minor);
    // EPOLLWAKEUP was introduced in kernel 3.5
    mUsingEpollWakeup = major > 3 || (major == 3 && minor >= 5);
}
```

`EventHub`主要执行了以下几步：

1. 初始化`epoll`实例
2. 初始化`iNotify`实例，用于监控`/dev/input`目录的变化。若发生变化，意味设备发生变化，需要处理。`epoll`添加`iNotify实例`监听
3. 创建非阻塞模式的管道(`pipe`)，epoll监听管道的内容。(主要用于 唤醒InputReader线程)



#### 初始InputManager

![InputManager](/images/IMS-InputManager.png)

```c++
//frameworks/native/services/inputflinger/InputManager.cpp
InputManager::InputManager(
        const sp<EventHubInterface>& eventHub,
        const sp<InputReaderPolicyInterface>& readerPolicy,
        const sp<InputDispatcherPolicyInterface>& dispatcherPolicy) {
    mDispatcher = new InputDispatcher(dispatcherPolicy);
    mReader = new InputReader(eventHub, readerPolicy, mDispatcher);
    initialize();
}
```



##### InputDispatcher

```c++
//frameworks/native/services/inputflinger/InputDispatcher.cpp
InputDispatcher::InputDispatcher(const sp<InputDispatcherPolicyInterface>& policy) :
    mPolicy(policy),
    mPendingEvent(NULL), mLastDropReason(DROP_REASON_NOT_DROPPED),
    mAppSwitchSawKeyDown(false), mAppSwitchDueTime(LONG_LONG_MAX),
    mNextUnblockedEvent(NULL),
    mDispatchEnabled(false), mDispatchFrozen(false), mInputFilterEnabled(false),
    mInputTargetWaitCause(INPUT_TARGET_WAIT_CAUSE_NONE) {
    //新建Looper对象
    mLooper = new Looper(false);

    mKeyRepeatState.lastKeyEntry = NULL;

    policy->getDispatcherConfiguration(&mConfig);
}
```



##### InputReader

```c++
//frameworks/native/services/inputflinger/InputReader.cpp
InputReader::InputReader(const sp<EventHubInterface>& eventHub,
        const sp<InputReaderPolicyInterface>& policy,
        const sp<InputListenerInterface>& listener) :
        mContext(this), mEventHub(eventHub), mPolicy(policy),
        mGlobalMetaState(0), mGeneration(1),
        mDisableVirtualKeysTimeout(LLONG_MIN), mNextTimeout(LLONG_MAX),
        mConfigurationChangesToRefresh(0) {
    //listener 对象 就是 InputDispatcher
    mQueuedListener = new QueuedInputListener(listener);

    { // acquire lock
        AutoMutex _l(mLock);

        refreshConfigurationLocked(0);
        updateGlobalMetaStateLocked();
    } // release lock
}
```

负责监听`InputDispatcher`对象



##### initalize()

```java
//frameworks/native/services/inputflinger/InputManager.cpp
void InputManager::initialize() {
    mReaderThread = new InputReaderThread(mReader);
    mDispatcherThread = new InputDispatcherThread(mDispatcher);
}

//frameworks/native/services/inputflinger/InputDispatcher.cpp
InputDispatcherThread::InputDispatcherThread(const sp<InputDispatcherInterface>& dispatcher) :
        Thread(/*canCallJava*/ true), mDispatcher(dispatcher) {
}

//frameworks/native/services/inputflinger/InputReader.cpp
InputReaderThread::InputReaderThread(const sp<InputReaderInterface>& reader) :
        Thread(/*canCallJava*/ true), mReader(reader) {
}
```

`initalize()`主要是创建两个能访问Java代码的native线程。

> 1.The InputReaderThread (called "InputReader") reads and preprocesses raw input events,applies policy, and posts messages to a queue managed by the DispatcherThread.
>
> 2.The InputDispatcherThread (called "InputDispatcher") thread waits for new events on the queue and asynchronously dispatches them to applications.



#### IMS启动——start()

![IMS启动](/images/IMS-start.png)

`IMS`初始化完毕就准备启动

```java
//InputManagerService.java
    public void start() {
        Slog.i(TAG, "Starting input manager");
        nativeStart(mPtr);
      ...
    }
```

```c++
//services/core/jni/com_android_server_input_InputManagerService.cpp
static void nativeStart(JNIEnv* env, jclass /* clazz */, jlong ptr) {
    NativeInputManager* im = reinterpret_cast<NativeInputManager*>(ptr);

    status_t result = im->getInputManager()->start();
}
```

```c++
//frameworks/native/services/inputflinger/InputManager.cpp
status_t InputManager::start() {
  //启动InputDispatcherThread
    status_t result = mDispatcherThread->run("InputDispatcher", PRIORITY_URGENT_DISPLAY)
  //启动InputReaderThread
    result = mReaderThread->run("InputReader", PRIORITY_URGENT_DISPLAY);

    return OK;
}
```

`IMS`启动，会带着`InputDispatcherThread`和`InputReaderThread`一起启动。



#### 总结

![IMS结构体系](/images/IMS结构体系.png)

IMS启动过程重点在于Native的初始化，分别创建以下对象：

- **EventHub**

  监听并记录`/dev/input`的变化

- **InputManager**

  创建`InputReader`和`InputDispatcher`对象

初始化完毕上述对象后，然后启动以下线程：

- **InputReaderThread**：从`EventHub`取出事件并处理，再转发给`InputDispatcher`
- **InputDispatcherThread**：接收来自`InputReader`的事件，并派发事件到合适的窗口(window)去处理

![img](/images/event1_4.png)



### 内核事件转发APP进程过程

`IMS`启动之后，`InputDispatcherThread`与`InputReaderThread`随之启动。

补充：一次触摸从内核到View的大致主链路如下。

`/dev/input -> EventHub -> InputReader -> NotifyMotionArgs -> InputDispatcher(mInboundQueue) -> InputChannel -> WindowInputEventReceiver -> ViewRootImpl -> DecorView -> Activity -> ViewGroup -> View`

排查问题时可先判断“卡在哪一段”：

- Native采集阶段（EventHub/InputReader）
- Native分发阶段（InputDispatcher + window命中）
- App消费阶段（ViewRootImpl输入阶段链 + View树分发）

#### InputReaderThread

![InputReaderThread](/images/InputReaderThread.png)

```c++
//frameworks/native/services/inputflinger/InputReader.cpp
bool InputReaderThread::threadLoop() {
    mReader->loopOnce();
    return true;
}

void InputReader::loopOnce() {
  ...
    //从EventHub获取事件列表，返回的是 事件的个数。无事件时将阻塞 
    size_t count = mEventHub->getEvents(timeoutMillis, mEventBuffer, EVENT_BUFFER_SIZE);

    { // acquire lock
        AutoMutex _l(mLock);
        mReaderIsAliveCondition.broadcast();

        if (count) {
          //处理获取的事件
            processEventsLocked(mEventBuffer, count);
        }

    } // release lock
    ...
   //处理完毕后发送到 InputDispatcher
    mQueuedListener->flush();
}
```

##### EventHub->getEvents() 获取事件

![EventHub-getEvents](/images/EventHub-getEvents.png)

```c++
//frameworks/native/services/inputflinger/EventHub.cpp
size_t EventHub::getEvents(int timeoutMillis, RawEvent* buffer, size_t bufferSize) {
  //原始事件构造
    RawEvent* event = buffer;
    size_t capacity = bufferSize;  
  for (;;) {//开启循环
    ...
        if (mNeedToScanDevices) {
            mNeedToScanDevices = false;
            scanDevicesLocked();//开始扫描设备
            mNeedToSendFinishedDeviceScan = true;
        }    
    ...
        while (mOpeningDevices != NULL) {
            Device* device = mOpeningDevices;
            ALOGV("Reporting device opened: id=%d, name=%s\n",
                 device->id, device->path.string());
            mOpeningDevices = device->next;
            event->when = now;
            event->deviceId = device->id == mBuiltInKeyboardId ? 0 : device->id;
            event->type = DEVICE_ADDED;//添加设备
            event += 1;
            mNeedToSendFinishedDeviceScan = true;
            if (--capacity == 0) {
                break;
            }
        }      
    ...
        while (mPendingEventIndex < mPendingEventCount) {
          ...
            ssize_t deviceIndex = mDevices.indexOfKey(eventItem.data.u32);          
          ...
            Device* device = mDevices.valueAt(deviceIndex);
            if (eventItem.events & EPOLLIN) {
             ...
                    int32_t deviceId = device->id == mBuiltInKeyboardId ? 0 : device->id;

                    size_t count = size_t(readSize) / sizeof(struct input_event);
                    for (size_t i = 0; i < count; i++) {
                      //获取readBuffer的数据
                        struct input_event& iev = readBuffer[i];
                      //封装成RawEvent对象
                        event->deviceId = deviceId;
                        event->type = iev.type;
                        event->code = iev.code;
                        event->value = iev.value;
                        event += 1;
                        capacity -= 1;                      
                      
                    }
            }
        }
          ...
            //等待input事件
           int pollResult = epoll_wait(mEpollFd, mPendingEventItems, EPOLL_MAX_EVENTS, timeoutMillis);
    
    ...
        // readNotify() will modify the list of devices so this must be done after
        // processing all other events to ensure that we read all remaining events
        // before closing the devices.
        if (mPendingINotify && mPendingEventIndex >= mPendingEventCount) {
            mPendingINotify = false;
          //从INotify事件 读取发生的事件
            readNotifyLocked();
            deviceChanged = true;
        }
  }
  ...
      // 返回读取的事件个数
    return event - buffer;
}
```

`getEvents()`采用`INotify + epoll`监听`/dev/input/`目录下的设备节点，再转换`deviceId + input_event`为`RawEvent`

```c++
// frameworks/native/services/inputflinger/EventHub.h
struct RawEvent {
    nsecs_t when;//事件发生的时间点
    int32_t deviceId;//设备id
    int32_t type;//事件类型
    int32_t code;
    int32_t value;
};
```

`type`可以为以下几种

- `DEVICE_ADDED`：添加设备
- `DEVICE_REMOVED`：移除设备
- `FINISHED_DEVICE_SCAN`：扫描完成
- `type < FIRST_SYNTHETIC_EVENT`：其他事件



`getEvents()`大概执行流程：

当`设备节点(/dev/input)`发生变化时，`epoll_wait()`会响应到对应的变化，然后`getEvents()`可以知道对应的变化。继续从`mINotifyFd`读取`iNotify事件`，进行输入设备的操作，最后生成相应的`RawEvent`



> 此时，EventHub从设备节点获取到了事件，并转化为`RawEvent`向下处理。

##### processEventsLocked() 处理事件

![InputReaderThread-processEventsLocked](/images/InputReaderThread-processEventsLocked.png)

```c++
void InputReader::processEventsLocked(const RawEvent* rawEvents, size_t count) {
    for (const RawEvent* rawEvent = rawEvents; count;) {
        int32_t type = rawEvent->type;
        size_t batchSize = 1;
        if (type < EventHubInterface::FIRST_SYNTHETIC_EVENT) {
            int32_t deviceId = rawEvent->deviceId;
            while (batchSize < count) {
                if (rawEvent[batchSize].type >= EventHubInterface::FIRST_SYNTHETIC_EVENT
                        || rawEvent[batchSize].deviceId != deviceId) {
                    break;
                }
                batchSize += 1;
            }
          //处理其他事件的数据
            processEventsForDeviceLocked(deviceId, rawEvent, batchSize);
        } else {
            switch (rawEvent->type) {
            case EventHubInterface::DEVICE_ADDED:
                //设备增加
                addDeviceLocked(rawEvent->when, rawEvent->deviceId);
                break;
            case EventHubInterface::DEVICE_REMOVED:
                //设备移除
                removeDeviceLocked(rawEvent->when, rawEvent->deviceId);
                break;
            case EventHubInterface::FINISHED_DEVICE_SCAN:
                //设备扫描完成
                handleConfigurationChangedLocked(rawEvent->when);
                break;
            default:
                ALOG_ASSERT(false); // can't happen
                break;
            }
        }
        count -= batchSize;
        rawEvent += batchSize;
    }
}

```



###### addDeviceLocked() 添加设备

```c++
void InputReader::addDeviceLocked(nsecs_t when, int32_t deviceId) {
    ssize_t deviceIndex = mDevices.indexOfKey(deviceId);

  //根据deviceId 创建设备
    InputDevice* device = createDeviceLocked(deviceId, controllerNumber, identifier, classes);
    device->configure(when, &mConfig, 0);
    device->reset(when);

  //添加设备
    mDevices.add(deviceId, device);
    bumpGenerationLocked();

}
```

```c++
InputDevice* InputReader::createDeviceLocked(int32_t deviceId, int32_t controllerNumber,
        const InputDeviceIdentifier& identifier, uint32_t classes) {
    InputDevice* device = new InputDevice(&mContext, deviceId, bumpGenerationLocked(),
            controllerNumber, identifier, classes);
...
    // Keyboard-like devices.  
    if (keyboardSource != 0) {
        device->addMapper(new KeyboardInputMapper(device, keyboardSource, keyboardType));
    }

    // Cursor-like devices.
    if (classes & INPUT_DEVICE_CLASS_CURSOR) {
        device->addMapper(new CursorInputMapper(device));
    }

    // Touchscreens and touchpad devices.
    if (classes & INPUT_DEVICE_CLASS_TOUCH_MT) {
        device->addMapper(new MultiTouchInputMapper(device));
    } else if (classes & INPUT_DEVICE_CLASS_TOUCH) {
        device->addMapper(new SingleTouchInputMapper(device));
    }
...

    return device;
}
```

`addDeviceLocked()`主要创建`InputDevice`，并且根据不同的设备类型来创建相应的`InputMapper`。

根据上述代码列举对应关系：

- `Keyboard-like`：键盘类设备 --> KeyboardInputMapper
- `Cursor-like`：鼠标类设备 --> CursorInputMapper
- `TouchScreens`：触摸屏设备 --> MultiTouchInputMapper(多点触控) / SingleTouchInputMapper(单点触控)

![InputMapper对应关系](/images/InputMapper对应关系.png)

###### processEventsForDeviceLocked() 处理设备事件

```c++
void InputReader::processEventsForDeviceLocked(int32_t deviceId,
        const RawEvent* rawEvents, size_t count) {
    ssize_t deviceIndex = mDevices.indexOfKey(deviceId);
//获取输入设备
    InputDevice* device = mDevices.valueAt(deviceIndex);

    device->process(rawEvents, count);
}
```

```c++
//frameworks/native/services/inputflinger/InputReader.cpp
void InputDevice::process(const RawEvent* rawEvents, size_t count) {

    size_t numMappers = mMappers.size();
    for (const RawEvent* rawEvent = rawEvents; count != 0; rawEvent++) {

        if (mDropUntilNextSync) {

        } else if (rawEvent->type == EV_SYN && rawEvent->code == SYN_DROPPED) {

        } else {
            for (size_t i = 0; i < numMappers; i++) {
                InputMapper* mapper = mMappers[i];
              //获取mapper继续执行process任务
                mapper->process(rawEvent);
            }
        }
        --count;
    }
}
```

以触摸屏为例，`mapper`指向`MultiTouchInputMapper`

```c++
void MultiTouchInputMapper::process(const RawEvent* rawEvent) {
    TouchInputMapper::process(rawEvent);

    mMultiTouchMotionAccumulator.process(rawEvent);
}

void TouchInputMapper::process(const RawEvent* rawEvent) {
    mCursorButtonAccumulator.process(rawEvent);
    mCursorScrollAccumulator.process(rawEvent);
    mTouchButtonAccumulator.process(rawEvent);

    if (rawEvent->type == EV_SYN && rawEvent->code == SYN_REPORT) {
        sync(rawEvent->when);
    }
}

void TouchInputMapper::dispatchPointerSimple(nsecs_t when, uint32_t policyFlags,
        bool down, bool hovering) {
  ...
    if (mPointerSimple.down && !down) {
        mPointerSimple.down = false;

        // Send up.
        NotifyMotionArgs args(when, getDeviceId(), mSource, policyFlags,
                 AMOTION_EVENT_ACTION_UP, 0, 0, metaState, mLastRawState.buttonState, 0,
                 mViewport.displayId, /* deviceTimestamp */ 0,
                 1, &mPointerSimple.lastProperties, &mPointerSimple.lastCoords,
                 mOrientedXPrecision, mOrientedYPrecision,
                 mPointerSimple.downTime);
        getListener()->notifyMotion(&args);
    }
  
    if (down) {
        if (!mPointerSimple.down) {
            mPointerSimple.down = true;
            mPointerSimple.downTime = when;

            // Send down.
            NotifyMotionArgs args(when, getDeviceId(), mSource, policyFlags,
                    AMOTION_EVENT_ACTION_DOWN, 0, 0, metaState, mCurrentRawState.buttonState, 0,
                    mViewport.displayId, /* deviceTimestamp */ 0,
                    1, &mPointerSimple.currentProperties, &mPointerSimple.currentCoords,
                    mOrientedXPrecision, mOrientedYPrecision,
                    mPointerSimple.downTime);
            getListener()->notifyMotion(&args);
        }

        // Send move.
        NotifyMotionArgs args(when, getDeviceId(), mSource, policyFlags,
                AMOTION_EVENT_ACTION_MOVE, 0, 0, metaState, mCurrentRawState.buttonState, 0,
                mViewport.displayId, /* deviceTimestamp */ 0,
                1, &mPointerSimple.currentProperties, &mPointerSimple.currentCoords,
                mOrientedXPrecision, mOrientedYPrecision,
                mPointerSimple.downTime);
        getListener()->notifyMotion(&args);
    }  
  
}
```

`getListener()`指的就是`mQueuedListener`

```c++
//frameworks/native/services/inputflinger/InputListener.cpp
void QueuedInputListener::notifyMotion(const NotifyMotionArgs* args) {
    mArgsQueue.push(new NotifyMotionArgs(*args));
}
```

将触摸事件放入`mArgsQueue`，此时事件加工完成。

##### QueuedInputListener.flush() 发送事件

![InputReaderThread-分发事件](/images/InputReaderThread-分发事件.png)

```c++
//frameworks/native/services/inputflinger/InputListener.cpp
void QueuedInputListener::flush() {
    size_t count = mArgsQueue.size();
    for (size_t i = 0; i < count; i++) {
        NotifyArgs* args = mArgsQueue[i];
        args->notify(mInnerListener);
        delete args;
    }
    mArgsQueue.clear();
}
```

`NotifyArgs`主要有以下几类：

- NotifyConfigurationChangedArgs：配置变化
- NotifyKeyArgs：键盘事件
- NotifyMotionArgs：触摸事件
- NotifySwitchArgs：切换事件
- NotifyDeviceResetArgs：设备重置事件



根据上节可知`args`为`NotifyMotionArgs`

```c++
void NotifyMotionArgs::notify(const sp<InputListenerInterface>& listener) const {
    listener->notifyMotion(this);
}
```

`listener`指的就是`InputDispatcher`

```c++
//frameworks/native/services/inputflinger/InputDispatcher.cpp
void InputDispatcher::notifyMotion(const NotifyMotionArgs* args) {
...
    if (!validateMotionEvent(args->action, args->actionButton,
                args->pointerCount, args->pointerProperties)) {
        return;
    }

    uint32_t policyFlags = args->policyFlags;
    policyFlags |= POLICY_FLAG_TRUSTED;

    android::base::Timer t;
    mPolicy->interceptMotionBeforeQueueing(args->eventTime, /*byref*/ policyFlags);

    bool needWake;
    { // acquire lock
        mLock.lock();

      //拦截事件分发
        if (shouldSendMotionToInputFilterLocked(args)) {
            mLock.unlock();

            MotionEvent event;//初始化MotionEvent对象
            event.initialize(args->deviceId, args->source, args->action, args->actionButton,
                    args->flags, args->edgeFlags, args->metaState, args->buttonState,
                    0, 0, args->xPrecision, args->yPrecision,
                    args->downTime, args->eventTime,
                    args->pointerCount, args->pointerProperties, args->pointerCoords);

            policyFlags |= POLICY_FLAG_FILTERED;
            if (!mPolicy->filterInputEvent(&event, policyFlags)) {
                return; // event was consumed by the filter
            }

            mLock.lock();
        }

        // Just enqueue a new motion event.
        MotionEntry* newEntry = new MotionEntry(args->eventTime,
                args->deviceId, args->source, policyFlags,
                args->action, args->actionButton, args->flags,
                args->metaState, args->buttonState,
                args->edgeFlags, args->xPrecision, args->yPrecision, args->downTime,
                args->displayId,
                args->pointerCount, args->pointerProperties, args->pointerCoords, 0, 0);

        needWake = enqueueInboundEventLocked(newEntry);
        mLock.unlock();
    } // release lock

    if (needWake) {
      //唤醒消息队列
        mLooper->wake();
    }
}
```

```c++
bool InputDispatcher::enqueueInboundEventLocked(EventEntry* entry) {
    bool needWake = mInboundQueue.isEmpty();
    mInboundQueue.enqueueAtTail(entry);//将事件放入`mInBoundQueue`的尾部，等待处理
    traceInboundQueueLengthLocked();

    switch (entry->type) {

    case EventEntry::TYPE_MOTION: {

        MotionEntry* motionEntry = static_cast<MotionEntry*>(entry);
        if (motionEntry->action == AMOTION_EVENT_ACTION_DOWN
                && (motionEntry->source & AINPUT_SOURCE_CLASS_POINTER)
                && mInputTargetWaitCause == INPUT_TARGET_WAIT_CAUSE_APPLICATION_NOT_READY
                && mInputTargetWaitApplicationHandle != NULL) {
            int32_t displayId = motionEntry->displayId;
            int32_t x = int32_t(motionEntry->pointerCoords[0].
                    getAxisValue(AMOTION_EVENT_AXIS_X));
            int32_t y = int32_t(motionEntry->pointerCoords[0].
                    getAxisValue(AMOTION_EVENT_AXIS_Y));
            sp<InputWindowHandle> touchedWindowHandle = findTouchedWindowAtLocked(displayId, x, y);
            if (touchedWindowHandle != NULL
                    && touchedWindowHandle->inputApplicationHandle
                            != mInputTargetWaitApplicationHandle) {
                // User touched a different application than the one we are waiting on.
                // Flag the event, and start pruning the input queue.
                mNextUnblockedEvent = motionEntry;
                needWake = true;
            }
        }
        break;
    }
    }

    return needWake;
}
```



##### 总结

![img](/images/v2-196591e61a6bed7189d68d7a72a07f4a_1440w.jpg)



`InputReaderThread`主要负责**事件封装转换**

- `EventHub.getEvents()`：通过`epoll`监听`iNotify实例(监听 /dev/input/ 目录)`读取事件放入`mEventBuffer`，然后转换成`RawEvent`
- `processEventsLocked()`：对`RawEvent`进行加工，转换成`NotifyMotionArgs`
- `flush()`：将事件`NotifyMotionArgs`发送到`InputDispatcher`进行处理，最后转换成`MotionEntry`并写入到`InputDispatcher.mInBoundQueue`



![InputReaderThread](/images/InputReaderThread.jpg)

#### InputDispatcherThread

![InputDispatcherThread](/images/InputDispatcherThread.png)

```c++
// frameworks/native/services/inputflinger/InputDispatcher.cpp
bool InputDispatcherThread::threadLoop() {
    mDispatcher->dispatchOnce();
    return true;
}

void InputDispatcher::dispatchOnce() {
    nsecs_t nextWakeupTime = LONG_LONG_MAX;
    { // acquire lock
        AutoMutex _l(mLock);
      //唤醒等待线程，监听当前是否发生死锁
        mDispatcherIsAliveCondition.broadcast();

       //派发输入事件，`nextWakeUpTime`决定下次派发线程执行时间
        if (!haveCommandsLocked()) {
            dispatchOnceInnerLocked(&nextWakeupTime);
        }

        // Run all pending commands if there are any.
        // If any commands were run then force the next poll to wake up immediately.
        if (runCommandsLockedInterruptible()) {
            nextWakeupTime = LONG_LONG_MIN;
        }
    } // release lock

   //派发线程进入休眠状态
    nsecs_t currentTime = now();
    int timeoutMillis = toMillisecondTimeoutDelay(currentTime, nextWakeupTime);
    mLooper->pollOnce(timeoutMillis);
}
```

##### dispatchOnceInnerLocked() 获取事件

![InputDispatcher-dispatchOnceInnerLocked](/images/InputDispatcher-dispatchOnceInnerLocked.png)

```c++
void InputDispatcher::dispatchOnceInnerLocked(nsecs_t* nextWakeupTime) {
    nsecs_t currentTime = now();

    // Ready to start a new event.
    // If we don't already have a pending event, go grab one.
    if (! mPendingEvent) {
        if (mInboundQueue.isEmpty()) {
          //派发队列为空，进入线程休眠状态
          ...
            // Nothing to do if there is no pending event.
            if (!mPendingEvent) {
                return;
            }
        } else {
            // 从 mInBoundQueue获取事件 实质就是上一步的 MotionEntry
            mPendingEvent = mInboundQueue.dequeueAtHead();
            traceInboundQueueLengthLocked();
        }
      ...
        // 重置ANR时间
        resetANRTimeoutsLocked();
    }

    // Now we have an event to dispatch.
    // All events are eventually dequeued and processed this way, even if we intend to drop them.
    ALOG_ASSERT(mPendingEvent != NULL);
    bool done = false;
    DropReason dropReason = DROP_REASON_NOT_DROPPED;
  //检查事件是否需要丢弃
    if (!(mPendingEvent->policyFlags & POLICY_FLAG_PASS_TO_USER)) {
        dropReason = DROP_REASON_POLICY;
    } else if (!mDispatchEnabled) {
        dropReason = DROP_REASON_DISABLED;
    }

    switch (mPendingEvent->type) {
    case EventEntry::TYPE_CONFIGURATION_CHANGED: {
       ...
        break;
    }

    case EventEntry::TYPE_DEVICE_RESET: {
       ...
        break;
    }

    case EventEntry::TYPE_KEY: {
       ...
        break;
    }

    case EventEntry::TYPE_MOTION: {
        MotionEntry* typedEntry = static_cast<MotionEntry*>(mPendingEvent);
        if (dropReason == DROP_REASON_NOT_DROPPED && isAppSwitchDue) {
            dropReason = DROP_REASON_APP_SWITCH;
        }
        if (dropReason == DROP_REASON_NOT_DROPPED
                && isStaleEventLocked(currentTime, typedEntry)) {
            dropReason = DROP_REASON_STALE;
        }
        if (dropReason == DROP_REASON_NOT_DROPPED && mNextUnblockedEvent) {
            dropReason = DROP_REASON_BLOCKED;
        }
      //分发触摸事件
        done = dispatchMotionLocked(currentTime, typedEntry,
                &dropReason, nextWakeupTime);
        break;
    }


        //准备派发下一个事件
    if (done) {
        if (dropReason != DROP_REASON_NOT_DROPPED) {
            dropInboundEventLocked(mPendingEvent, dropReason);
        }
        mLastDropReason = dropReason;

        releasePendingEventLocked();
        *nextWakeupTime = LONG_LONG_MIN;  // force next poll to wake up immediately
    }
}

```

```c++
bool InputDispatcher::dispatchMotionLocked(
        nsecs_t currentTime, MotionEntry* entry, DropReason* dropReason, nsecs_t* nextWakeupTime) {

    bool isPointerEvent = entry->source & AINPUT_SOURCE_CLASS_POINTER;

    // 保存触摸事件的发送目标
    Vector<InputTarget> inputTargets;

    bool conflictingPointerActions = false;
    int32_t injectionResult;
    if (isPointerEvent) {
        // 基于坐标点的形式，如触屏，根据坐标点获取目标窗口
        injectionResult = findTouchedWindowTargetsLocked(currentTime,
                entry, inputTargets, nextWakeupTime, &conflictingPointerActions);
    } else {
        // 无坐标点的触摸事件，例如 轨迹球
        injectionResult = findFocusedWindowTargetsLocked(currentTime,
                entry, inputTargets, nextWakeupTime);
    }

    addMonitoringTargetsLocked(inputTargets);
   //将 entry 分发到 对应window上
    dispatchEventLocked(currentTime, entry, inputTargets);
    return true;
}
```

补充：窗口命中规则

- 指针类事件（触摸）优先走`findTouchedWindowTargetsLocked()`，核心依据是当前坐标命中窗口。
- 非指针类事件（如按键）通常走`findFocusedWindowTargetsLocked()`，核心依据是焦点窗口。
- 命中窗口后，事件会以`InputTarget`形式封装偏移、缩放、pointerId集合等信息，再投递到对应`InputChannel`。

`InputTarget`的结构

```c++
//frameworks/native/services/inputflinger/InputDispatcher.h
struct InputTarget {
    // 连接InputDispatcher与Window的通信管道
    sp<InputChannel> inputChannel;

    // Flags for the input target.
    int32_t flags;

    // The x and y offset to add to a MotionEvent as it is delivered.
    // (ignored for KeyEvents)
    float xOffset, yOffset;

    // Scaling factor to apply to MotionEvent as it is delivered.
    // (ignored for KeyEvents)
    float scaleFactor;

    // The subset of pointer ids to include in motion events dispatched to this input target
    // if FLAG_SPLIT is set.
    BitSet32 pointerIds;  
}
```

##### dispatchEventLocked() 发送事件

```c++
void InputDispatcher::dispatchEventLocked(nsecs_t currentTime,
        EventEntry* eventEntry, const Vector<InputTarget>& inputTargets) {

    pokeUserActivityLocked(eventEntry);

    for (size_t i = 0; i < inputTargets.size(); i++) {
        const InputTarget& inputTarget = inputTargets.itemAt(i);
       //根据InputTarget的InputChannel 获取 connection
        ssize_t connectionIndex = getConnectionIndexLocked(inputTarget.inputChannel);
        if (connectionIndex >= 0) {
            sp<Connection> connection = mConnectionsByFd.valueAt(connectionIndex);
          //准备分发消息
            prepareDispatchCycleLocked(currentTime, connection, eventEntry, &inputTarget);

        }
    }
}

void InputDispatcher::prepareDispatchCycleLocked(nsecs_t currentTime,
        const sp<Connection>& connection, EventEntry* eventEntry, const InputTarget* inputTarget) {
     ...

    // 将事件添加到Connections的发送队列
    enqueueDispatchEntriesLocked(currentTime, connection, eventEntry, inputTarget);
}


void InputDispatcher::enqueueDispatchEntriesLocked(nsecs_t currentTime,
        const sp<Connection>& connection, EventEntry* eventEntry, const InputTarget* inputTarget) {
    bool wasEmpty = connection->outboundQueue.isEmpty();
  ...

    // If the outbound queue was previously empty, start the dispatch cycle going.
    if (wasEmpty && !connection->outboundQueue.isEmpty()) {
        startDispatchCycleLocked(currentTime, connection);
    }
}

//开始循环
void InputDispatcher::startDispatchCycleLocked(nsecs_t currentTime,
        const sp<Connection>& connection) {

    while (connection->status == Connection::STATUS_NORMAL
            && !connection->outboundQueue.isEmpty()) {
        DispatchEntry* dispatchEntry = connection->outboundQueue.head;
        dispatchEntry->deliveryTime = currentTime;

        // Publish the event.
        status_t status;
        EventEntry* eventEntry = dispatchEntry->eventEntry;
        switch (eventEntry->type) {


        case EventEntry::TYPE_MOTION: {
            MotionEntry* motionEntry = static_cast<MotionEntry*>(eventEntry);

            PointerCoords scaledCoords[MAX_POINTERS];
            const PointerCoords* usingCoords = motionEntry->pointerCoords;

            // Set the X and Y offset depending on the input source.
            float xOffset, yOffset;
            if ((motionEntry->source & AINPUT_SOURCE_CLASS_POINTER)
                    && !(dispatchEntry->targetFlags & InputTarget::FLAG_ZERO_COORDS)) {
                float scaleFactor = dispatchEntry->scaleFactor;
                xOffset = dispatchEntry->xOffset * scaleFactor;
                yOffset = dispatchEntry->yOffset * scaleFactor;
                if (scaleFactor != 1.0f) {
                    for (uint32_t i = 0; i < motionEntry->pointerCount; i++) {
                        scaledCoords[i] = motionEntry->pointerCoords[i];
                        scaledCoords[i].scale(scaleFactor);
                    }
                    usingCoords = scaledCoords;
                }
            } else {
                xOffset = 0.0f;
                yOffset = 0.0f;

                // We don't want the dispatch target to know.
                if (dispatchEntry->targetFlags & InputTarget::FLAG_ZERO_COORDS) {
                    for (uint32_t i = 0; i < motionEntry->pointerCount; i++) {
                        scaledCoords[i].clear();
                    }
                    usingCoords = scaledCoords;
                }
            }

            // Publish the motion event.
            status = connection->inputPublisher.publishMotionEvent(dispatchEntry->seq,
                    motionEntry->deviceId, motionEntry->source, motionEntry->displayId,
                    dispatchEntry->resolvedAction, motionEntry->actionButton,
                    dispatchEntry->resolvedFlags, motionEntry->edgeFlags,
                    motionEntry->metaState, motionEntry->buttonState,
                    xOffset, yOffset, motionEntry->xPrecision, motionEntry->yPrecision,
                    motionEntry->downTime, motionEntry->eventTime,
                    motionEntry->pointerCount, motionEntry->pointerProperties,
                    usingCoords);
            break;
        }

        // 回收队列
        connection->outboundQueue.dequeue(dispatchEntry);
        traceOutboundQueueLengthLocked(connection);
        // 等待执行队列
        connection->waitQueue.enqueueAtTail(dispatchEntry);
        traceWaitQueueLengthLocked(connection);
    }
}
 
```

```c++
//frameworks/native/libs/input/InputTransport.cpp
status_t InputPublisher::publishMotionEvent(
        uint32_t seq,
        int32_t deviceId,
        int32_t source,
        int32_t displayId,
        int32_t action,
        int32_t actionButton,
        int32_t flags,
        int32_t edgeFlags,
        int32_t metaState,
        int32_t buttonState,
        float xOffset,
        float yOffset,
        float xPrecision,
        float yPrecision,
        nsecs_t downTime,
        nsecs_t eventTime,
        uint32_t pointerCount,
        const PointerProperties* pointerProperties,
        const PointerCoords* pointerCoords) {


    InputMessage msg;
    msg.header.type = InputMessage::TYPE_MOTION;
    msg.body.motion.seq = seq;
    msg.body.motion.deviceId = deviceId;
    msg.body.motion.source = source;
    msg.body.motion.displayId = displayId;
    msg.body.motion.action = action;
    msg.body.motion.actionButton = actionButton;
    msg.body.motion.flags = flags;
    msg.body.motion.edgeFlags = edgeFlags;
    msg.body.motion.metaState = metaState;
    msg.body.motion.buttonState = buttonState;
    msg.body.motion.xOffset = xOffset;
    msg.body.motion.yOffset = yOffset;
    msg.body.motion.xPrecision = xPrecision;
    msg.body.motion.yPrecision = yPrecision;
    msg.body.motion.downTime = downTime;
    msg.body.motion.eventTime = eventTime;
    msg.body.motion.pointerCount = pointerCount;
    for (uint32_t i = 0; i < pointerCount; i++) {
        msg.body.motion.pointers[i].properties.copyFrom(pointerProperties[i]);
        msg.body.motion.pointers[i].coords.copyFrom(pointerCoords[i]);
    }
    return mChannel->sendMessage(&msg);
}

```

```c++
//frameworks/native/libs/input/InputTransport.cpp
status_t InputChannel::sendMessage(const InputMessage* msg) {
 ...
}
```

最终通过`InputChannel.sendMessage()`发送包装好的触摸事件

> 这里的关键点是：`InputDispatcher`并不是直接调用App侧Java代码，而是先通过`InputChannel(socket pair)`把事件写到目标窗口对应的通道。App进程的`WindowInputEventReceiver`从通道读到事件后，再回调到`ViewRootImpl`进入Java层分发流程。



##### handleReceiveCallback 接收事件

这一节的触发条件会在后面讲到，简单来说就是

后面Java层的事件分发结束，调用到`InputEventReceiver.finishInputEvent()`，会向UI进程持有的`InputChannel`写入数据，然后唤醒`InputDispatcher`线程被唤醒后执行`handleReceiveCallback()`

```c++
//frameworks/native/services/inputflinger/InputDispatcher.cpp
int InputDispatcher::handleReceiveCallback(int fd, int events, void* data) {
  ...
        sp<Connection> connection = d->mConnectionsByFd.valueAt(connectionIndex);
  ...
            for (;;) {
                uint32_t seq;
                bool handled;
              //从 connection 获取消息
                status = connection->inputPublisher.receiveFinishedSignal(&seq, &handled);
                if (status) {
                    break;
                }
              
                d->finishDispatchCycleLocked(currentTime, connection, seq, handled);
                gotOne = true;
            }    
}

void InputDispatcher::finishDispatchCycleLocked(nsecs_t currentTime,
        const sp<Connection>& connection, uint32_t seq, bool handled) {

    connection->inputPublisherBlocked = false;

    if (connection->status == Connection::STATUS_BROKEN
            || connection->status == Connection::STATUS_ZOMBIE) {
        return;
    }

    // Notify other system components and prepare to start the next dispatch cycle.
    onDispatchCycleFinishedLocked(currentTime, connection, seq, handled);
}

void InputDispatcher::onDispatchCycleFinishedLocked(
        nsecs_t currentTime, const sp<Connection>& connection, uint32_t seq, bool handled) {
  //发送命令到 doDispatchCycleFinishedLockedInterruptible
    CommandEntry* commandEntry = postCommandLocked(
            & InputDispatcher::doDispatchCycleFinishedLockedInterruptible);
    commandEntry->connection = connection;
    commandEntry->eventTime = currentTime;
    commandEntry->seq = seq;
    commandEntry->handled = handled;
}

void InputDispatcher::doDispatchCycleFinishedLockedInterruptible(
        CommandEntry* commandEntry) {
  ...
        if (dispatchEntry == connection->findWaitQueueEntry(seq)) {
          //事件执行完毕后，从waitQueue移除事件
            connection->waitQueue.dequeue(dispatchEntry);
            traceWaitQueueLengthLocked(connection);
        }

        // 开始下一次发送循环
        startDispatchCycleLocked(now(), connection);  
}
```



##### 总结

![img](/images/event1_5.png)

`InputReader`发送触摸事件到`InputDispatcher`，通过`findFocusedWindowTargetsLocked()`寻找触摸事件对应的窗口，如果没有找到就使用第一个`Window`。把结果写入`inputTargets`中，然后通过`publishMotionEvent`分发触摸事件，再通过`InputChannel`发送消息到UI线程。

![InputDispatche](/images/InputDispatcherThread.jpg)

### 触摸事件发送至Activity

![事件分发-触摸事件发送至Activity](/images/事件分发-触摸事件发送至Activity.png)

`InputDispatcher`负责分发触摸事件，最后通过`InputChannel->sendMessage()`发出消息

```c++
//frameworks/native/libs/input/InputTransport.cpp
status_t InputChannel::sendMessage(const InputMessage* msg) {
    const size_t msgLength = msg->size();
    InputMessage cleanMsg;
    msg->getSanitizedCopy(&cleanMsg);
    ssize_t nWrite;
    do {
        nWrite = ::send(mFd, &cleanMsg, msgLength, MSG_DONTWAIT | MSG_NOSIGNAL);
    } while (nWrite == -1 && errno == EINTR);

    return OK;
}
```

`InputChannel`通过`socket`发送消息。

既然存在`sendMessage()`就需要找到相对的`receiveMessage()`调用的地方。

> 当前是`InputDispatcher`调用的`sendMessage()`，对应就需要去`Window`找`receiveMessage()`

#### InputChannel的理解

![InputChannel](/images/事件分发-InputChannel.png)

本质是`SocketPair(非网络套接字)`。`SocketPair`用于实现本机内的进程间通信。

`SocketPair`提供方法：

- `socketPair()`：创建SocketPair，返回一对相互连接的fd
- `send()`：写入数据，可在另一个fd读取
- `recv()`：读取数据

**非常适合用来进行进程间的交互式通讯。**



`InputChannel`就是`SocketPair`的封装，分别分配给`InputDispatcher`与`Window`。

`InputDispatcher`写入的事件，`Window`可以从自己持有的`InputChannel`获取；反向也是如此。

`InputChannel`提供方法：位于`InputTransport.cpp`中

- `openInputChannelPair()`：封装`socketPair()`
- `sendMessage()`：封装`send()`
- `receiveMessage()`：封装`recv()`



![InputChannel原理](/images/InputChannel原理.png)





最后屏幕的触摸事件都需要反映到一个Activity上，然后再一步步传递到对应的View上。所以需要先从Activity开始分析触摸事件的传递流程。

#### InputChannel注册

![事件分发-InputChannel注册](/images/事件分发-InputChannel注册.png)

```java
//ActivityThread.java
    public void handleResumeActivity(IBinder token, boolean finalStateRequest, boolean isForward,
            String reason) {
      ...
        wm.addView(decor, l);
      ...
    }

// ==> WindowManagerGlobal.java
      public void addView(View view, ViewGroup.LayoutParams params,
            Display display, Window parentWindow) {
        //新建ViewRootImpl
            root = new ViewRootImpl(view.getContext(), display);        
        
        root.setView(view, wparams, panelParentView);
      }
  
// ==> ViewRootImpl.java
    public void setView(View view, WindowManager.LayoutParams attrs, View panelParentView) {
      //创建InputChannel对象
        if ((mWindowAttributes.inputFeatures
                 & WindowManager.LayoutParams.INPUT_FEATURE_NO_INPUT_CHANNEL) == 0) {
            mInputChannel = new InputChannel();
        } 
      //创建Socket的服务端
       res = mWindowSession.addToDisplay(mWindow, mSeq, mWindowAttributes,
             getHostVisibility(), mDisplay.getDisplayId(), mWinFrame,
             mAttachInfo.mContentInsets, mAttachInfo.mStableInsets,
             mAttachInfo.mOutsets, mAttachInfo.mDisplayCutout, mInputChannel);      
      
      //创建Socket的客户端
        if (mInputChannel != null) {
            if (mInputQueueCallback != null) {
                mInputQueue = new InputQueue();
                mInputQueueCallback.onInputQueueCreated(mInputQueue);
            }
          //创建WindowEventReceiver对象
            mInputEventReceiver = new WindowInputEventReceiver(mInputChannel,
                    Looper.myLooper());
        }
    }
```

##### addToDisplay()

```java
//Session.java
    @Override
    public int addToDisplay(IWindow window, int seq, WindowManager.LayoutParams attrs,
            int viewVisibility, int displayId, Rect outFrame, Rect outContentInsets,
            Rect outStableInsets, Rect outOutsets,
            DisplayCutout.ParcelableWrapper outDisplayCutout, InputChannel outInputChannel) {
        return mService.addWindow(this, window, seq, attrs, viewVisibility, displayId, outFrame,
                outContentInsets, outStableInsets, outOutsets, outDisplayCutout, outInputChannel);
    }
```

其中`mService`指的就是`WindowManagerService`

```java
//frameworks/base/services/core/java/com/android/server/wm/WindowManagerService.java
    public int addWindow(Session session, IWindow client, int seq,
            LayoutParams attrs, int viewVisibility, int displayId, Rect outFrame,
            Rect outContentInsets, Rect outStableInsets, Rect outOutsets,
            DisplayCutout.ParcelableWrapper outDisplayCutout, InputChannel outInputChannel) {
      ...
            final WindowState win = new WindowState(this, session, client, token, parentWindow,
                    appOp[0], seq, attrs, viewVisibility, session.mUid,
                    session.mCanAddInternalSystemWindow);
      ...
            final boolean openInputChannels = (outInputChannel != null
                    && (attrs.inputFeatures & INPUT_FEATURE_NO_INPUT_CHANNEL) == 0);
            if  (openInputChannels) {
                win.openInputChannel(outInputChannel);
            }      
      
    }
```

`addWindow()`主要创建了`WindowState`对象，然后继续调用到`openInputChannels()`

```java
//frameworks/base/services/core/java/com/android/server/wm/WindowState.java
    void openInputChannel(InputChannel outInputChannel) {
        if (mInputChannel != null) {
            throw new IllegalStateException("Window already has an input channel.");
        }
        String name = getName();
        InputChannel[] inputChannels = InputChannel.openInputChannelPair(name);
        mInputChannel = inputChannels[0];
        mClientChannel = inputChannels[1];
        mInputWindowHandle.inputChannel = inputChannels[0];
        if (outInputChannel != null) {
            mClientChannel.transferTo(outInputChannel);
            mClientChannel.dispose();
            mClientChannel = null;
        } else {
            // If the window died visible, we setup a dummy input channel, so that taps
            // can still detected by input monitor channel, and we can relaunch the app.
            // Create dummy event receiver that simply reports all events as handled.
            mDeadWindowEventReceiver = new DeadWindowEventReceiver(mClientChannel);
        }
        mService.mInputManager.registerInputChannel(mInputChannel, mInputWindowHandle);
    }
```

##### registerInputChannel()

```java
//InputManagerService.java 
public void registerInputChannel(InputChannel inputChannel,
            InputWindowHandle inputWindowHandle) {
       //通过Native层完成注册
        nativeRegisterInputChannel(mPtr, inputChannel, inputWindowHandle, false);
    }

```

```c++
status_t NativeInputManager::registerInputChannel(JNIEnv* /* env */,
        const sp<InputChannel>& inputChannel,
        const sp<InputWindowHandle>& inputWindowHandle, bool monitor) {
    ATRACE_CALL();
  //再通过 InputDispatcher 继续注册
    return mInputManager->getDispatcher()->registerInputChannel(
            inputChannel, inputWindowHandle, monitor);
}
```

```c++
//frameworks/native/services/inputflinger/InputDispatcher.cpp
status_t InputDispatcher::registerInputChannel(const sp<InputChannel>& inputChannel,
        const sp<InputWindowHandle>& inputWindowHandle, bool monitor) {


    { // acquire lock
        AutoMutex _l(mLock);

      //为传入的 InputChannel 创建Connection对象
        sp<Connection> connection = new Connection(inputChannel, inputWindowHandle, monitor);

        int fd = inputChannel->getFd();
      //监听connection的变化
        mConnectionsByFd.add(fd, connection);

        if (monitor) {
            mMonitoringChannels.push(inputChannel);
        }

      //如果发生变化，回调handleReceiveCallback方法
        mLooper->addFd(fd, 0, ALOOPER_EVENT_INPUT, handleReceiveCallback, this);
    } // release lock

    // Wake the looper because some connections have changed.
    mLooper->wake();
    return OK;
}
```

![InputChannel执行过程](/images/InputChannel执行过程.png)



![InputChannel对应关系](/images/v2-1e1273f15cfdd7b81aa7a2cb819d8890_1440w.jpg)



`addToDisplay()`主要处理两部分内容

- 创建Socket pair，作为`InputChannel`

  `socket服务端`保存在`WidnowState`中的`mInputChannel`中

  `socket客户端`通过`binder`传到`ViewRootImpl`中的`mInputChannel`

- 通过`IMS.registerInputChannel()`注册`InputChannel`，监听socket服务端，收到消息后回调`InputDispatcher::handleReceiveCallback()`

##### WindowInputEventReceiver

```java
//ViewRootImpl.java
    final class WindowInputEventReceiver extends InputEventReceiver {
        public WindowInputEventReceiver(InputChannel inputChannel, Looper looper) {
            super(inputChannel, looper);
        }
      ...
        @Override
        public void onInputEvent(InputEvent event, int displayId) {
            enqueueInputEvent(event, this, 0, true);
        }        
    }

//InputeventReceiver.java
    public InputEventReceiver(InputChannel inputChannel, Looper looper) {

        mInputChannel = inputChannel;
        mMessageQueue = looper.getQueue();
        mReceiverPtr = nativeInit(new WeakReference<InputEventReceiver>(this),
                inputChannel, mMessageQueue);

        mCloseGuard.open("dispose");
    }

//Native层调用该方法
    private void dispatchInputEvent(int seq, InputEvent event, int displayId) {
        mSeqMap.put(event.getSequenceNumber(), seq);
        onInputEvent(event, displayId);
    }
```



初始化 InputEventReceiver

```c++
//frameworks/base/core/jni/android_view_InputEventReceiver.cpp
static jlong nativeInit(JNIEnv* env, jclass clazz, jobject receiverWeak,
        jobject inputChannelObj, jobject messageQueueObj) {
    sp<InputChannel> inputChannel = android_view_InputChannel_getInputChannel(env,
            inputChannelObj);
    if (inputChannel == NULL) {
        jniThrowRuntimeException(env, "InputChannel is not initialized.");
        return 0;
    }

  //获取消息队列
    sp<MessageQueue> messageQueue = android_os_MessageQueue_getMessageQueue(env, messageQueueObj);
    if (messageQueue == NULL) {
        jniThrowRuntimeException(env, "MessageQueue is not initialized.");
        return 0;
    }

  //创建NativeInputEventReceiver对象
    sp<NativeInputEventReceiver> receiver = new NativeInputEventReceiver(env,
            receiverWeak, inputChannel, messageQueue);
    status_t status = receiver->initialize();

    receiver->incStrong(gInputEventReceiverClassInfo.clazz); // retain a reference for the object
    return reinterpret_cast<jlong>(receiver.get());
}

```

```c++
status_t NativeInputEventReceiver::initialize() {
    setFdEvents(ALOOPER_EVENT_INPUT);
    return OK;
}

void NativeInputEventReceiver::setFdEvents(int events) {
    if (mFdEvents != events) {
        mFdEvents = events;
        int fd = mInputConsumer.getChannel()->getFd();
        if (events) {
            mMessageQueue->getLooper()->addFd(fd, 0, events, this, NULL);
        } else {
            mMessageQueue->getLooper()->removeFd(fd);
        }
    }
}
```

```c++
//system/core/libutils/Looper.cpp
int Looper::addFd(int fd, int ident, int events, const sp<LooperCallback>& callback, void* data) {
  //构造native Request消息
          Request request;
        request.fd = fd;
        request.ident = ident;
        request.events = events;
        request.seq = mNextRequestSeq++;
        request.callback = callback; //NativeInputReceiver
        request.data = data;
        if (mNextRequestSeq == -1) mNextRequestSeq = 0; // reserve sequence number -1
  
        struct epoll_event eventItem;
        request.initEventItem(&eventItem);
       ...
         //在epoll实例 添加native request监听
        int epollResult = epoll_ctl(mEpollFd, EPOLL_CTL_ADD, fd, & eventItem);         
  
       //唤醒线程
        scheduleEpollRebuildLocked();  
}

void Looper::scheduleEpollRebuildLocked() {
    if (!mEpollRebuildRequired) {
        mEpollRebuildRequired = true;
        wake();
    }
}
```

这一部分涉及`looper`在`Handler`就有详细介绍，`wake`之后，`native request`相关消息触发后会回调到`callback->handleEvent()`

```c++
//frameworks/base/core/jni/android_view_InputEventReceiver.cpp
int NativeInputEventReceiver::handleEvent(int receiveFd, int events, void* data) {
  ...
    if (events & ALOOPER_EVENT_INPUT) { //events 就是 ALOOPER_EVENT_INPUT
        JNIEnv* env = AndroidRuntime::getJNIEnv();
        status_t status = consumeEvents(env, false /*consumeBatches*/, -1, NULL);
        mMessageQueue->raiseAndClearException(env, "handleReceiveCallback");
        return status == OK || status == NO_MEMORY ? 1 : 0;
    }
  ...
}

status_t NativeInputEventReceiver::consumeEvents(JNIEnv* env,
        bool consumeBatches, nsecs_t frameTime, bool* outConsumedBatch) {
  for (;;) {
        status_t status = mInputConsumer.consume(&mInputEventFactory,
                consumeBatches, frameTime, &seq, &inputEvent, &displayId);
    //将事件进行打包，避免量过大
        if (status) {
            if (status == WOULD_BLOCK) {
                if (!skipCallbacks && !mBatchedInputEventPending
                        && mInputConsumer.hasPendingBatch()) {
                    // There is a pending batch.  Come back later.
                    if (!receiverObj.get()) {
                        receiverObj.reset(jniGetReferent(env, mReceiverWeakGlobal));
                        if (!receiverObj.get()) {
                            ALOGW("channel '%s' ~ Receiver object was finalized "
                                    "without being disposed.", getInputChannelName().c_str());
                            return DEAD_OBJECT;
                        }
                    }

                    mBatchedInputEventPending = true;
                    if (kDebugDispatchCycle) {
                        ALOGD("channel '%s' ~ Dispatching batched input event pending notification.",
                                getInputChannelName().c_str());
                    }
                  //调用 InputReceiver.dispatchBatchedInputEventPending()
                    env->CallVoidMethod(receiverObj.get(),
                            gInputEventReceiverClassInfo.dispatchBatchedInputEventPending);
                    if (env->ExceptionCheck()) {
                        ALOGE("Exception dispatching batched input events.");
                        mBatchedInputEventPending = false; // try again later
                    }
                }
                return OK;
            }
            ALOGE("channel '%s' ~ Failed to consume input event.  status=%d",
                    getInputChannelName().c_str(), status);
            return status;
        }    
    ...
        if (!skipCallbacks) {

            jobject inputEventObj;
            switch (inputEvent->getType()) {

            case AINPUT_EVENT_TYPE_MOTION: {
                if (kDebugDispatchCycle) {
                    ALOGD("channel '%s' ~ Received motion event.", getInputChannelName().c_str());
                }
              //封装MotionEvent对象
                MotionEvent* motionEvent = static_cast<MotionEvent*>(inputEvent);
                if ((motionEvent->getAction() & AMOTION_EVENT_ACTION_MOVE) && outConsumedBatch) {
                    *outConsumedBatch = true;
                }
                inputEventObj = android_view_MotionEvent_obtainAsCopy(env, motionEvent);
                break;
            }

            default:
                assert(false); // InputConsumer should prevent this from ever happening
                inputEventObj = NULL;
            }

            if (inputEventObj) {
                if (kDebugDispatchCycle) {
                    ALOGD("channel '%s' ~ Dispatching input event.", getInputChannelName().c_str());
                }
              //回调到Java层的 dispatchInputEvent() 
                env->CallVoidMethod(receiverObj.get(),
                        gInputEventReceiverClassInfo.dispatchInputEvent, seq, inputEventObj,
                        displayId);
                if (env->ExceptionCheck()) {
                    ALOGE("Exception dispatching input event.");
                    skipCallbacks = true;
                }
                env->DeleteLocalRef(inputEventObj);
            } else {
                ALOGW("channel '%s' ~ Failed to obtain event object.",
                        getInputChannelName().c_str());
                skipCallbacks = true;
            }
        }    
    
  }
  
}
```

```c++
//frameworks/native/libs/input/InputTransport.cpp
status_t InputConsumer::consume(InputEventFactoryInterface* factory,
        bool consumeBatches, nsecs_t frameTime, uint32_t* outSeq, InputEvent** outEvent,
        int32_t* displayId) {
    while (!*outEvent) {
            mMsgDeferred = false;
        } else {
            // 收到新消息
            status_t result = mChannel->receiveMessage(&mMsg);
            if (result) {
                if (consumeBatches || result != WOULD_BLOCK) {
                    result = consumeBatch(factory, frameTime, outSeq, outEvent, displayId);
                    if (*outEvent) {
                        break;
                    }
                }
                return result;
            }
        }  
  
}
```





`WindowInputEventReceiver`主要执行了以下几步：

- 初始化了`NativeInputReceiver`，调用了`sendFdEvents()`发出了消息
- 往主线程Looper添加了一条`Native Request`，且`callback`为`NativeInputReceiver`
- 向Looper的`mEpollFd`添加了监听，只要收到触摸事件的消息就会调用到`callback->handleEvent()`
- `NativeInputReceiver::handleEvent()`主要回调到Java层的`dispatchInputEvent()`且携带`InputEvent`回去(在触摸场景下，实际为`MotionEvent`)。

#### 回调到Activity

![事件分发-回调到Activity](/images/事件分发-回调到Activity.png)

```java
//InputEventReceiver.java
private void dispatchInputEvent(int seq, InputEvent event, int displayId) {
        mSeqMap.put(event.getSequenceNumber(), seq);
        onInputEvent(event, displayId);
    }

    private void dispatchBatchedInputEventPending() {
        onBatchedInputEventPending();
    }


//ViewRootImpl.java

    final class WindowInputEventReceiver extends InputEventReceiver {
        @Override
        public void onInputEvent(InputEvent event, int displayId) {
            enqueueInputEvent(event, this, 0, true);
        }
      
        @Override
        public void onBatchedInputEventPending() {
            if (mUnbufferedInputDispatch) {
                super.onBatchedInputEventPending();
            } else {
                scheduleConsumeBatchedInput();//按照Vsync信号进行分发
            }
        }
      
    }

//事件
    void scheduleConsumeBatchedInput() {
        if (!mConsumeBatchedInputScheduled) {
            mConsumeBatchedInputScheduled = true;
          //根据Vsync信号 进行触摸事件的回调
            mChoreographer.postCallback(Choreographer.CALLBACK_INPUT,
                    mConsumedBatchedInputRunnable, null);
        }
    }

    // 默认模式下，输入批处理会挂到 CALLBACK_INPUT 对齐帧节奏
    // 若开启 mUnbufferedInputDispatch，会偏向即时分发以降低输入延迟

    void enqueueInputEvent(InputEvent event,
            InputEventReceiver receiver, int flags, boolean processImmediately) {
        adjustInputEventForCompatibility(event);
        QueuedInputEvent q = obtainQueuedInputEvent(event, receiver, flags);

        if (processImmediately) {
            doProcessInputEvents();
        } else {
            scheduleProcessInputEvents();
        }
    }

    void doProcessInputEvents() {
        // Deliver all pending input events in the queue.
        while (mPendingInputEventHead != null) {
            QueuedInputEvent q = mPendingInputEventHead;
            mPendingInputEventHead = q.mNext;
            if (mPendingInputEventHead == null) {
                mPendingInputEventTail = null;
            }
            q.mNext = null;

            if (q.mEvent instanceof MotionEvent) {
                MotionEvent me = (MotionEvent)q.mEvent;
                if (me.getHistorySize() > 0) {
                    oldestEventTime = me.getHistoricalEventTimeNano(0);
                }
            }
            mChoreographer.mFrameInfo.updateInputEventTime(eventTime, oldestEventTime);

            deliverInputEvent(q);
        }
    }

    private void deliverInputEvent(QueuedInputEvent q) {

        InputStage stage;
        if (q.shouldSendToSynthesizer()) {
            stage = mSyntheticInputStage;
        } else {
            stage = q.shouldSkipIme() ? mFirstPostImeInputStage : mFirstInputStage;
        }

        if (stage != null) {
            handleWindowFocusChanged();
            stage.deliver(q);
        } else {
          //事件分发完成后 执行
            finishInputEvent(q);
        }
    }

    abstract class InputStage {
        public final void deliver(QueuedInputEvent q) {
            if ((q.mFlags & QueuedInputEvent.FLAG_FINISHED) != 0) {
                forward(q);
            } else if (shouldDropInputEvent(q)) {
                finish(q, false);
            } else {
                apply(q, onProcess(q));
            }
        }      
    }

```

此处`stage`是`ViewPostImeInputStage`，向下继续调用到`onProcess()`

`ViewPostImeInputStage`：**视图处理阶段**，主要处理按键、手指触摸等事件，分发的对象是View。

```java
//viewRootImpl.java
    final class ViewPostImeInputStage extends InputStage {
        protected int onProcess(QueuedInputEvent q) {
          //按键事件
            if (q.mEvent instanceof KeyEvent) {
                return processKeyEvent(q);
            } else {
              //触摸事件
                final int source = q.mEvent.getSource();
                if ((source & InputDevice.SOURCE_CLASS_POINTER) != 0) {
                    return processPointerEvent(q);
                }
            }
        }
      
        private int processPointerEvent(QueuedInputEvent q) {
            final MotionEvent event = (MotionEvent)q.mEvent;

            mAttachInfo.mUnbufferedDispatchRequested = false;
            mAttachInfo.mHandlingPointerEvent = true;
          //向下分发到View
            boolean handled = mView.dispatchPointerEvent(event);
  
            return handled ? FINISH_HANDLED : FORWARD;
        }      
      
    }
```

此时`mView`表示的就是`DecorView`，本质就是View

```java
//view.java    
public final boolean dispatchPointerEvent(MotionEvent event) {
        if (event.isTouchEvent()) {
            return dispatchTouchEvent(event);
        } else {
            return dispatchGenericMotionEvent(event);
        }
    }

//DecorView.java
    public boolean dispatchTouchEvent(MotionEvent ev) {
        final Window.Callback cb = mWindow.getCallback();
        return cb != null && !mWindow.isDestroyed() && mFeatureId < 0
                ? cb.dispatchTouchEvent(ev) : super.dispatchTouchEvent(ev);
    }
```

`mWindow.getCallback()`就是与Window绑定的Activity

```java
//Activity.java
    public boolean dispatchTouchEvent(MotionEvent ev) {
        if (ev.getAction() == MotionEvent.ACTION_DOWN) {
            onUserInteraction();
        }
        if (getWindow().superDispatchTouchEvent(ev)) {
            return true;
        }
        return onTouchEvent(ev);
    }
```

所以经过一系列操作 让用户的屏幕触摸操作，最终走到了`Activity.dispatchTouchEvent()`



![img](/images/触摸事件真实顺序.jpg)



## 事件分发

### MotionEvent

![MotionEvent](/images/MotionEvent.png)

> 当用户点击View或ViewGroup的时候，将会产生一个事件对象，就是`MotionEvent`。

`MotionEvent`记录了`事件的类型(action)、触摸的位置(x,y)以及触摸的时间等`。

事件的类型主要分为以下几种：

- `ACTION_DOWN`：监听用户手指按下的操作，一次按下标志触摸事件的开始。
- `ACTION_MOVE`：用户按压屏幕后，在抬起之前，如果移动的距离超过一定数值，就判定为移动事件。
- `ACTION_UP`：监听用户手指离开屏幕的操作，一次抬起标志触摸事件的结束。
- `ACTION_CANCEL`：当用户保持按下操作，并把手指移动到了控件外部区域时且父View处理事件触发。

多指触摸下还需要关注：

- `ACTION_POINTER_DOWN/ACTION_POINTER_UP`：表示非首指的按下/抬起，不会重置整段手势。
- `actionIndex`表示“本次变化的是哪根手指”，`pointerId`用于跨事件稳定标识同一手指。
- 多指处理应基于`pointerId`而不是临时索引，避免索引变化导致手指错位。



用户手指触摸到屏幕到离开屏幕可能产生的事件序列如下：

`ACTION_DOWN` -> `ACTION_MOVE` -> `ACTION_MOVE` -> ... `ACTION_MOVE` -> `ACTION_UP`

![事件分发顺序](/images/事件分发顺序.jpg)

### MotionEvent产生时机

![产生时机](/images/MotionEvent产生时机.png)

在`ViewRootImpl.setView()`时，创建了`WindowInputReceiver`，当IMS写入事件(通过EventHub监听到`/dev/input/`)，通过一系列的操作回调到`dispatchInputEvent()`，最后走到了`processPointerEvent()`，此时把从Native层传递过来的`InputEvent`强转成`MotionEvent`，然后继续向下传递。

### MotionEvent传递顺序-事件分发顺序

![事件分发顺序](/images/事件分发顺序.png)

事件分发本质就是`MotionEvent`的传递过程。

```java
//ViewRootImpl.java
        private int processPointerEvent(QueuedInputEvent q) {
            final MotionEvent event = (MotionEvent)q.mEvent;

            mAttachInfo.mUnbufferedDispatchRequested = false;
            mAttachInfo.mHandlingPointerEvent = true;
          //向下分发到View
            boolean handled = mView.dispatchPointerEvent(event);
  
            return handled ? FINISH_HANDLED : FORWARD;
        }      
      

```

`mView`就是`DecorView`

```java
//DecorView.java
没有实现对应方法。。。
向上寻找父类
  
//View.java
    public final boolean dispatchPointerEvent(MotionEvent event) {
        if (event.isTouchEvent()) {
            return dispatchTouchEvent(event);
        } else {
            return dispatchGenericMotionEvent(event);
        }
    }
  

//DecorView.java
    @Override
    public boolean dispatchTouchEvent(MotionEvent ev) {
        final Window.Callback cb = mWindow.getCallback();
        return cb != null && !mWindow.isDestroyed() && mFeatureId < 0
                ? cb.dispatchTouchEvent(ev) : super.dispatchTouchEvent(ev);
    }
```

此时`mWindow.getCallback()`指的就是`Activity`

#### Activity事件分发

```java
    public boolean dispatchTouchEvent(MotionEvent ev) {
        if (ev.getAction() == MotionEvent.ACTION_DOWN) {
          //在此处可以监听到 用户触摸屏幕的操作
            onUserInteraction();
        }
       //若dispatchTouchEvent返回true，事件到此结束，返回false，继续向下传递
      //对应PhoneWindow
        if (getWindow().superDispatchTouchEvent(ev)) {
            return true;
        }
      //没有任何View去处理，交给Activity自身的onTouchEvent处理
        return onTouchEvent(ev);
    }
```

`getWindow()`对应唯一实现类`PhoneWindow`

```java
//PhoneWindow.java
    @Override
    public boolean superDispatchTouchEvent(MotionEvent event) {
      //mDecor 是DecorView的一个实例，DecoeView就是顶层View中的实例对象
        return mDecor.superDispatchTouchEvent(event);
    }
```

`mDecor`指的就是`DecorView`

```java
//DecorView.java
    public boolean superDispatchTouchEvent(MotionEvent event) {
      //调用父类的方法即FrameLayout.dispatchTouchEvent = ViewGroup.dispatchTouchEvent()，由父类去处理事件分发
        return super.dispatchTouchEvent(event);//指向了 ViewGroup
    }
```

![Activity事件分发](/images/Activity-Dispatch.png)

总结一下：按照上述流程图，当一个点击事件进来时，Activity上的事件流程如下：

- 调用`Activity.dispatchTouchEvent()`，然后调用`onUserInteraction()`
- 调用`getWindow()即PhoneWindow.superDispatchTouchEvent()`
- 调用`mDecor即DecorView.superDispatchTouchEvent()`
- 调用DecorView父类即**`ViewGroup.dispatchTouchEvent()`** 在这里实现了事件从Activity传递至ViewGroup



#### ViewGroup事件分发

![ViewGroup事件分发](/images/事件分发-ViewGroup.png)

上述Activity分发后，执行到`ViewGroup.dispatchTouchEvent()`

```java
//ViewGroup.java
    @Override
    public boolean dispatchTouchEvent(MotionEvent ev) {
      ...
        
            if (actionMasked == MotionEvent.ACTION_DOWN) {
              //发生ACTION_DOWN事件，取消并清除之前的触摸
                cancelAndClearTouchTargets(ev);
                resetTouchState();
            }        
      ...
          //判定当前事件是否需要拦截
            final boolean intercepted;
            if (actionMasked == MotionEvent.ACTION_DOWN
                    || mFirstTouchTarget != null) {//只有ACTION_DOWN才可以触发拦截
                //FLAG_DISALLOW_INTERCEPT：禁止ViewGroup拦截除了DOWN以外的事件
                //可由View调用requestDisallowInterceptTouchEvent设置标记
                final boolean disallowIntercept = (mGroupFlags & FLAG_DISALLOW_INTERCEPT) != 0;
                if (!disallowIntercept) {
                  //调用拦截方法
                    intercepted = onInterceptTouchEvent(ev);
                    ev.setAction(action); // restore action in case it was changed
                } else {
                    intercepted = false;
                }
            } else {
               //没有触摸targets 且 非ACTION_DOWN 需要拦截
                intercepted = true;
            }   
      ...
           //非取消事件 且 没被拦截
            if (!canceled && !intercepted) {
                if (actionMasked == MotionEvent.ACTION_DOWN
                        || (split && actionMasked == MotionEvent.ACTION_POINTER_DOWN)
                        || actionMasked == MotionEvent.ACTION_HOVER_MOVE) {//当前为 DOWN 事件
                    final int actionIndex = ev.getActionIndex(); // always 0 for down
                   //存在子View
                    if (newTouchTarget == null && childrenCount != 0) {
                        final float x = ev.getX(actionIndex);
                        final float y = ev.getY(actionIndex);
                      //从上往下 寻找能处理触摸事件的子View
                        final ArrayList<View> preorderedList = buildTouchDispatchChildList();
                        final boolean customOrder = preorderedList == null
                                && isChildrenDrawingOrderEnabled();
                        final View[] children = mChildren;
                        for (int i = childrenCount - 1; i >= 0; i--) {
                            final int childIndex = getAndVerifyPreorderedIndex(
                                    childrenCount, i, customOrder);
                            final View child = getAndVerifyPreorderedView(
                                    preorderedList, children, childIndex);
                           //无法获取焦点，跳过循环
                            if (childWithAccessibilityFocus != null) {
                                if (childWithAccessibilityFocus != child) {
                                    continue;
                                }
                                childWithAccessibilityFocus = null;
                                i = childrenCount - 1;
                            }
                          //View不可见 或者 触摸的坐标点不在View的范围内，跳过循环
                            if (!canViewReceivePointerEvents(child)
                                    || !isTransformedTouchPointInView(x, y, child, null)) {
                                ev.setTargetAccessibilityFocus(false);
                                continue;
                            }

                            newTouchTarget = getTouchTarget(child);
                          //当前正在循环 ，退出当前循环
                            if (newTouchTarget != null) {
                                // Child is already receiving touch within its bounds.
                                // Give it the new pointer in addition to the ones it is handling.
                                newTouchTarget.pointerIdBits |= idBitsToAssign;
                                break;
                            }

                            resetCancelNextUpFlag(child);
                          ////事件传递下来后，调用dispatchTransformedTouchEvent，事件就会传递到View/ViewGroup中       
                            if (dispatchTransformedTouchEvent(ev, false, child, idBitsToAssign)) {
                                // Child wants to receive touch within its bounds.
                                mLastTouchDownTime = ev.getDownTime();
                                if (preorderedList != null) {
                                    // childIndex points into presorted list, find original index
                                    for (int j = 0; j < childrenCount; j++) {
                                        if (children[childIndex] == mChildren[j]) {
                                            mLastTouchDownIndex = j;
                                            break;
                                        }
                                    }
                                } else {
                                    mLastTouchDownIndex = childIndex;
                                }
                                mLastTouchDownX = ev.getX();
                                mLastTouchDownY = ev.getY();
                              //添加新的 touchtarget
                                newTouchTarget = addTouchTarget(child, idBitsToAssign);
                                alreadyDispatchedToNewTouchTarget = true;
                                break;
                            }
                            ev.setTargetAccessibilityFocus(false);
                        }
                        if (preorderedList != null) preorderedList.clear();
                    }

                    if (newTouchTarget == null && mFirstTouchTarget != null) {
                        newTouchTarget = mFirstTouchTarget;
                        while (newTouchTarget.next != null) {
                            newTouchTarget = newTouchTarget.next;
                        }
                        newTouchTarget.pointerIdBits |= idBitsToAssign;
                    }                  
                }
            }
      
            // mFirstTouchTarget赋值是在通过addTouchTarget方法获取的；
            // 只有处理ACTION_DOWN事件，才会进入addTouchTarget方法。
            // 这也正是当View没有消费ACTION_DOWN事件，则不会接收其他MOVE,UP等事件的原因
            if (mFirstTouchTarget == null) {
                // ViewGroup处理事件 当无人可以响应触摸事件
                handled = dispatchTransformedTouchEvent(ev, canceled, null,
                        TouchTarget.ALL_POINTER_IDS);
            } else {
               //如果View消费ACTION_DOWN事件，那么MOVE,UP等事件相继开始执行
                TouchTarget predecessor = null;
                TouchTarget target = mFirstTouchTarget;
                while (target != null) {
                    final TouchTarget next = target.next;
                    if (alreadyDispatchedToNewTouchTarget && target == newTouchTarget) {
                        handled = true;
                    } else {
                        final boolean cancelChild = resetCancelNextUpFlag(target.child)
                                || intercepted;
                      //子View/ViewGroup 处理触摸事件
                        if (dispatchTransformedTouchEvent(ev, cancelChild,
                                target.child, target.pointerIdBits)) {
                            handled = true;
                        }
                        if (cancelChild) {
                            if (predecessor == null) {
                                mFirstTouchTarget = next;
                            } else {
                                predecessor.next = next;
                            }
                            target.recycle();
                            target = next;
                            continue;
                        }
                    }
                    predecessor = target;
                    target = next;
                }
            }    
              ...
        }
        return handled;
      
    }
```

##### onInterceptTouchEvent()

```java
    public boolean onInterceptTouchEvent(MotionEvent ev) {
        if (ev.isFromSource(InputDevice.SOURCE_MOUSE)
                && ev.getAction() == MotionEvent.ACTION_DOWN
                && ev.isButtonPressed(MotionEvent.BUTTON_PRIMARY)
                && isOnScrollbarThumb(ev.getX(), ev.getY())) {
            return true;
        }
        return false;
    }
```

可以通过重写该方法，进行事件分发的拦截。

- 返回true，事件被拦截，执行当前View的`onTouchEvent()`
- 返回false，事件继续向下分发

##### buildTouchDispatchChildList()

```java
    public ArrayList<View> buildTouchDispatchChildList() {
        return buildOrderedChildList();
    }

    ArrayList<View> buildOrderedChildList() {
        final int childrenCount = mChildrenCount;
        if (childrenCount <= 1 || !hasChildWithZ()) return null;

      //z
        final boolean customOrder = isChildrenDrawingOrderEnabled();
        for (int i = 0; i < childrenCount; i++) {
            // add next child (in child order) to end of list
            final int childIndex = getAndVerifyPreorderedIndex(childrenCount, i, customOrder);
            final View nextChild = mChildren[childIndex];
            final float currentZ = nextChild.getZ();

            // 按z轴，从小到大排序所有的子视图，即z轴大的View先响应事件
            int insertIndex = i;
            while (insertIndex > 0 && mPreSortedChildren.get(insertIndex - 1).getZ() > currentZ) {
                insertIndex--;
            }
            mPreSortedChildren.add(insertIndex, nextChild);
        }
        return mPreSortedChildren;
    }

//View.java
    public float getZ() {
        return getElevation() + getTranslationZ();
    }
```

默认的事件分发顺序与绘制顺序一致，按照`view.getZ()`从大到小排序，Z值大的先绘制且先响应事件。

当然，这个事件分发的顺序也可以修改，只需要实现两个方法：

- `setChildrenDrawingOrderEnabled(true)`：允许自定义顺序。*isChildrenDrawingOrderEnabled()返回true*
- `getChildDrawingOrder()`：自定义当前View的顺序

也可以通过`setElevation()`、`setTranslationZ()`或者`setZ()`去修改Z轴的坐标值。

##### dispatchTransformedTouchEvent()

```java
    private boolean dispatchTransformedTouchEvent(MotionEvent event, boolean cancel,
            View child, int desiredPointerIdBits) {
        final boolean handled;

       //发生取消事件后，不再执行后续的任何操作
        final int oldAction = event.getAction();
        if (cancel || oldAction == MotionEvent.ACTION_CANCEL) {
            event.setAction(MotionEvent.ACTION_CANCEL);
            if (child == null) {
                handled = super.dispatchTouchEvent(event);
            } else {
                handled = child.dispatchTouchEvent(event);
            }
            event.setAction(oldAction);
            return handled;
        }

        final MotionEvent transformedEvent;
        if (newPointerIdBits == oldPointerIdBits) {
            if (child == null || child.hasIdentityMatrix()) {
                if (child == null) {
                  //不存在子视图，调用View.dispatchTouchEvent()
                    handled = super.dispatchTouchEvent(event);
                } else {
                    final float offsetX = mScrollX - child.mLeft;
                    final float offsetY = mScrollY - child.mTop;
                    event.offsetLocation(offsetX, offsetY);
                   //调用子View/ViewGroup的 dispatchTouchEvent()
                    handled = child.dispatchTouchEvent(event);

                    event.offsetLocation(-offsetX, -offsetY);
                }
                return handled;
            }
            transformedEvent = MotionEvent.obtain(event);
        } else {
            transformedEvent = event.split(newPointerIdBits);
        }

        // Done.
        transformedEvent.recycle();
        return handled;
    }
```

`dispatchTransformedTouchEvent()`分为两套处理方式：

- `child==null`：发生的情况：`事件被拦截`或`真的没有可执行触摸事件的子View`。执行`View.dispatchTouchEvent()`
- `child!=null`：向下执行子View/ViewGroup的`dispatchTouchEvent()`



##### addTouchTarget()

```java
    private TouchTarget addTouchTarget(@NonNull View child, int pointerIdBits) {
        final TouchTarget target = TouchTarget.obtain(child, pointerIdBits);
        target.next = mFirstTouchTarget;
        mFirstTouchTarget = target;
        return target;
    }
```

`TouchTarget`结构如下：

```java
    private static final class TouchTarget {
        // The touched child view.
        public View child;

        // The combined bit mask of pointer ids for all pointers captured by the target.
        public int pointerIdBits;

        // The next target in the target list.
        public TouchTarget next;
    }
```

`TouchTarget`是一个单链表结构，记录的是**事件分发链**。每一个元素表示`真正对事件消费的View`。

![ViewGroup事件分发](/images/ViewGroup-Dispatch.png)

根据上述流程图，总结一下：

- 点击事件从上层传递到ViewGroup，先调用`ViewGroup.dispatchTouchEvent()`
- 判断`ViewGroup.onInterceptTouchEvent()`是否拦截点击事件
  - 默认不拦截，则将事件继续向子View传递，然后调用`View.dispatchTouchEvent()`
  - 被拦截返回`true`，调用`super.dispatchTouchEvent()`返给父布局处理，并且ViewGroup自身也处理事件，比如`onTouch(),onClick(),onTouchEvent()`等事件

> 通常情况下ViewGroup的`onInterceptTouchEvent()`返回false，不会拦截用户操作。
>
> 不过要注意的是 拦截的是 一个用户的操作序列：*从用户手指按下到手指抬起为止。*
>
> - 拦截了Down事件，后续的事件都会交由`ViewGroup.onTouchEvent()`处理
> - 拦截了其他事件，会给之前序列头部的`ACTION_DOWN`事件发送一个`ACTION_CANCEL`类型事件，通知子View无法执行后续事件，回归初始状态。(**例如点击ListView中的一个Item的Button，再滑动ListView，Button就会恢复初始状态。**)

#### View事件分发

![View事件分发](/images/事件分发-View.png)

ViewGroup事件分发完毕后，由子View继续执行事件分发

```java
//View.java    
public boolean dispatchTouchEvent(MotionEvent event) {

        boolean result = false;

        if (onFilterTouchEventForSecurity(event)) {
            if ((mViewFlags & ENABLED_MASK) == ENABLED && handleScrollBarDragging(event)) {
                result = true;
            }
            //noinspection SimplifiableIfStatement
            ListenerInfo li = mListenerInfo;
            if (li != null && li.mOnTouchListener != null //View设置了touch事件
                    && (mViewFlags & ENABLED_MASK) == ENABLED //View是可以操作的
                    && li.mOnTouchListener.onTouch(this, event)) { //View.onTouch返回true
                result = true;
            }

          //上述任一条件不满足，就会执行 onTouchEvent()
            if (!result && onTouchEvent(event)) {
                result = true;
            }
        }

        return result;
    }
```

`dispatchTouchEvent()`按照如下顺序执行：

1. `onTouchListener.ouTouch()`开始执行，返回`true`表示当前事件已被消费，不需要向上执行。否则继续向下执行
2. `onTouchEvent()`返回`true`表示消费事件。

补充：`onTouch()`返回`true`后，事件通常不会再触发`onClick()`。



```java
//View.java
    public boolean onTouchEvent(MotionEvent event) {
        final boolean clickable = ((viewFlags & CLICKABLE) == CLICKABLE //有点击事件 调用setOnClickListener()
                || (viewFlags & LONG_CLICKABLE) == LONG_CLICKABLE) //有长按事件 调用setOnLongClickListener()
                || (viewFlags & CONTEXT_CLICKABLE) == CONTEXT_CLICKABLE;
      
        if ((viewFlags & ENABLED_MASK) == DISABLED) {
            if (action == MotionEvent.ACTION_UP && (mPrivateFlags & PFLAG_PRESSED) != 0) {
                setPressed(false);
            }
            mPrivateFlags3 &= ~PFLAG3_FINGER_DOWN;
          //当View不可用时 直接消费事件
            return clickable;
        }
      
      if (clickable || (viewFlags & TOOLTIP) == TOOLTIP) {
            switch (action) {
                case MotionEvent.ACTION_UP:
                        if (!mHasPerformedLongPress && !mIgnoreNextUpEvent) {
                            // This is a tap, so remove the longpress check
                            removeLongPressCallback();

                            if (!focusTaken) {
                                if (mPerformClick == null) {
                                    mPerformClick = new PerformClick();
                                }
                                if (!post(mPerformClick)) {
                                  //调用View.onClckListener
                                    performClickInternal();
                                }
                            }
                        }                
            }
      }
    }

    private boolean performClickInternal() {

        return performClick();
    }

    public boolean performClick() {

        final boolean result;
        final ListenerInfo li = mListenerInfo;
        if (li != null && li.mOnClickListener != null) {
            playSoundEffect(SoundEffectConstants.CLICK);
            li.mOnClickListener.onClick(this);
            result = true;
        } else {
            result = false;
        }

        return result;
    }
```



![View事件分发](/images/View-Dispatch.png)



根据上述流程图，总结一下：

- 点击事件从ViewGroup传递到View，调用`View.dispatchTouchEvent()`
- 判断当前View是否设置`OnTouchListener`，并且设置了`onTouch()`返回值，默认返回false
  - 返回`true`，代表事件被`onTouch()`消费，不会继续往下传递
  - 返回`false`，事件继续向下传递，调用`View.onTouchEvent()`，后续若设置点击事件，则继续调用`performClick()`，最后执行`onClick()`事件

拓展：

> 1. 如果有一个控件是`DISABLED`，注册的`onTouch()`事件不会被执行。若要监听点击事件，只能实现它的`onTouchEvent()`
> 2. 点击事件优先级： `onTouch()` > `onTouchEvent()` > `performClick()` > `onClick()` 

### 总结

根据前几节分析得出完整的事件分发顺序：

**IMS -> WindowInputEventReceiver(ViewRootImpl) -> DecorView -> Activity -> DecorView -> ViewGroup -> View**



#### 事件分发核心方法

![事件分发核心方法](/images/事件分发核心方法.png)

`boolean dispatchTouchEvent()`

用来进行事件的分发。

- 返回`true`：事件被当前View所消费，不会向下传递
- 返回`false`：交由上一层的View的`onTouchEvent()`处理
- 返回`super.dispatchTouchEvent()`：继续向下分发事件



`boolean onInterceptTouchEvent()`

用来进行事件的拦截，在`dispatchOnTouchEvent()`中调用。**只有ViewGroup才可以调用**

- 返回`true`：拦截当前事件，并交由`onTouchEvent()`去处理

- 返回`false`：不拦截当前事件，继续向下传递

- 返回`super.onInterceptTouchEvent()`：调用父类的`onInterceptTouchEvent()`，大部分情况下是`false`。

  如果点击了子View区域，可以继续分发到`child.dispatchTouchEvent()`

  没有子View可以响应事件，执行`onTouchEvent()`

  

`boolean onTouchEvent()`

用来处理点击事件，在`dispatchOnTouchEvent()`中调用。

- 返回`true`：当前View处理当前事件

- 返回`false`：当前View无法处理事件，交由上一层View的`onTouchEvent()`处理

- 返回`super.onTouchEvent()`

  当前View设置了`clickable/longclickable`，等价于返回true，当前View处理事件

  当前View未设置`clickable/longclickable`，等价于返回false,交由上一层的`onTouchEvent()`处理。

  这也是“View不可点击时，`onTouchEvent()`默认可能返回false，事件向父层回传”的常见来源。



上述三个核心方法，可以用如下伪代码代替

```java
public boolean dispatchTouchEvent() {
    boolean res = false;

    // 是否不允许拦截事件
    // 如果设置了 FLAG_DISALLOW_INTERCEPT，不会拦截事件，所以在 child 里可以通过 requestDisallowInterceptTouchEvent 控制父 View 是否来拦截事件
    final boolean disallowIntercept = (mGroupFlags & FLAG_DISALLOW_INTERCEPT) != 0;

    if (!disallowIntercept && onInterceptTouchEvent()) { // View 不调用这里，直接执行下面的 touchlistener 判断
        if (touchlistener && touchlistener.onTouch()) {
            return true;
        }
        res = onTouchEvent(); // 里面会处理点击事件 -> performClick() -> clicklistener.onClick()
    } else if (DOWN) { // 如果是 DOWN 事件，则遍历子 View 进行事件分发
        // 循环子 View 处理事件
        for (childs) {
            res = child.dispatchTouchEvent();
        }
    } else {
        // 事件分发给 target 去处理，这里的 target 就是上一步处理 DOWN 事件的 View
        target.child.dispatchTouchEvent();
    }
    return res;
}
```



![事件分发](/images/TouchEvent-Transmit.png)



1. 点击事件传递从`dispatchTouchEvent()`开始，在不修改默认返回值时，事件会按照嵌套层次由外向内传递，到达最内层View时，由最内层`View.onTouchEvent()`处理
2. View的点击事件触发顺序为  `onTouch()` > `onTouchEvent()` > `performClick()` > `onClick()` 
3. *Touch事件的后续(例如`ACTION_MOVE`,`ACTION_UP`)层级传递*
   - 若`dispatchTouchEvent()`返回true，那么能收到`ACTION_DOWN`的函数也可以收到后续事件
   - 若`onTouchEvent()`返回true，那么其他事件不再往下传递，而是直接传给自己的`onTouchEvent()`并结束本次事件传递



> 事件分发核心在于`ViewGroup.dispatchTouchEvent()`的`ACTION_DOWN`过程中找到`mFirstTouchTarget`是否为空。
>
> 通过遍历子View寻找`view.disptachTouchEvent()`返回`true`，就设置`mFirstTouchTarget`为该子View。
>
> 如果`mFirstTarget`不为空，`ACTION_MOVE`和`ACTION_UP`才会向子View传递，如果中途被`ViewGroup`拦截了事件，子View就会收到`ACTION_CANCEL`，并且`mFirstTouchTarget`为null，后续的事件只会走到`ViewGroup`。

补充：`mFirstTouchTarget`通常在`ACTION_DOWN`阶段建立，后续`MOVE/UP`会按该目标持续分发；父容器中途改为拦截时，会向子View发送`ACTION_CANCEL`结束本次手势序列。

#### 事件分发特殊情况

![事件分发特殊情况](/images/事件分发特殊情况.png)

##### `ACTION_CANCEL`产生场景

1. 子View处理了Down事件，按照设定Move与Up的事件也会交给他处理。若此时，父View拦截了事件，此时子View就会收到一个Cancel事件，并且无法接收到后续的Move与Up事件。

   常见场景：ListView有一个Item带有Button，此时点击按钮(触发ACTION_DOWN)，再进行上下滑动，ListView就会拦截掉后续的Move事件，此时Button就会收到ACTION_CANCEL

2. 子View收到ACTION_DOWN，但是上一个事件还没有结束(因为APP切换、ANR导致后续事件丢失)，此时也会执行ACTION_CANCEL

`ACTION_CANCEL`本身不代表异常崩溃，更多是分发策略变化（父拦截、窗口切换、系统接管）的正常信号。



##### 子View拦截父View事件

子View通过使用`requestDisallowInterceptTouchEvent(true)`命令**指定ViewGroup不再针对事件序列进行拦截**，将事件交由子View去处理。

*设置`requestDisallowInterceptTouchEvent(true)`后，父类会在每次`ACTION_DOWN`的时候进行重置，避免影响其他子View的事件处理。*

也就是说，`requestDisallowInterceptTouchEvent(true)`只影响当前这次手势序列，下次`ACTION_DOWN`会重新开始判定。

上述方法也是解决`滑动冲突`的一种方法：

`内部拦截法`：通过在子类中调用`parent.requestDisallowInterceptTouchEvent()`来控制父类是否拦截事件。

还有一个是

`外部拦截法`：通过重写父类的`onInterceptTouchEvent()`拦截冲突的事件。



#### 长按事件原理

在`onTouchEvent()`收到`ACTION_DOWN`事件时，发送一个延时消息`mPendingCheckForLongPress()`，延迟`400ms`后执行。内部执行`performLongClick()`，再然后一步步调用到`performLongClickInternal()`内部执行到`mOnLongClickListener.onLongClick()`

`onLongClick()`返回`true`就会屏蔽`onClick()`执行。

## 事件分发完成

事件分发完毕后，执行到`finishInputEvent()`

```java
//ViewRootImpl.java
        protected void onDeliverToNext(QueuedInputEvent q) {
            if (DEBUG_INPUT_STAGES) {
                Log.v(mTag, "Done with " + getClass().getSimpleName() + ". " + q);
            }
            if (mNext != null) {
              //有任务继续执行
                mNext.deliver(q);
            } else {
              //无任务时 通知结束
                finishInputEvent(q);
            }
        }

    private void finishInputEvent(QueuedInputEvent q) {
        Trace.asyncTraceEnd(Trace.TRACE_TAG_VIEW, "deliverInputEvent",
                q.mEvent.getSequenceNumber());

        if (q.mReceiver != null) {
            boolean handled = (q.mFlags & QueuedInputEvent.FLAG_FINISHED_HANDLED) != 0;
            q.mReceiver.finishInputEvent(q.mEvent, handled);
        } else {
            q.mEvent.recycleIfNeededAfterDispatch();
        }

        recycleQueuedInputEvent(q);
    }
```

```java
//InputEventReceiver.java
    public final void finishInputEvent(InputEvent event, boolean handled) {
     ...
      nativeFinishInputEvent(mReceiverPtr, seq, handled);
     ...
    }
```

`nativeFinishInputEvent()`通知事件结束到Native层

```c++
//frameworks/base/core/jni/android_view_InputEventReceiver.cpp
static void nativeFinishInputEvent(JNIEnv* env, jclass clazz, jlong receiverPtr,
        jint seq, jboolean handled) {
    sp<NativeInputEventReceiver> receiver =
            reinterpret_cast<NativeInputEventReceiver*>(receiverPtr);
  ...
    status_t status = receiver->finishInputEvent(seq, handled);
}

status_t NativeInputEventReceiver::finishInputEvent(uint32_t seq, bool handled) {
  ...
    status_t status = mInputConsumer.sendFinishedSignal(seq, handled);
    if (status) {
        if (status == WOULD_BLOCK) {
          ...
            if (mFinishQueue.size() == 1) {
                setFdEvents(ALOOPER_EVENT_INPUT | ALOOPER_EVENT_OUTPUT);
            }
            return OK;
        }
    }
    return status;
}
```

```c++
//frameworks/native/libs/input/InputTransport.cpp
status_t InputConsumer::sendFinishedSignal(uint32_t seq, bool handled) {
    ...
    // Send finished signals for the batch sequence chain first.
    size_t seqChainCount = mSeqChains.size();
    if (seqChainCount) {
       ...
        status_t status = OK;
        while (!status && chainIndex > 0) {
            chainIndex--;
          
            status = sendUnchainedFinishedSignal(chainSeqs[chainIndex], handled);
        }

    }

    // Send finished signal for the last message in the batch.
    return sendUnchainedFinishedSignal(seq, handled);
}

```

```c++
status_t InputConsumer::sendUnchainedFinishedSignal(uint32_t seq, bool handled) {
    InputMessage msg;
    msg.header.type = InputMessage::TYPE_FINISHED;
    msg.body.finished.seq = seq;
    msg.body.finished.handled = handled;
  //通过 InputChannel.sendMessage()发送消息通知
     return mChannel->sendMessage(&msg);
}
```

`InputChannel.sendMessage()`之后，`InputDispatcher`线程被唤醒，回调到`handleReceiveCallback()`。执行到上面的`InputDispatcheThread`相关代码。

补充：`finishInputEvent`是输入消费闭环的关键点。

- `ViewRootImpl.finishInputEvent()`最终会走到`InputConsumer.sendFinishedSignal()`，通知`InputDispatcher`本次事件已处理。
- `InputDispatcher`收到finished信号后，会从`waitQueue`移除对应`DispatchEntry`并继续下一轮发送。
- 如果App侧长期不回传finished，`waitQueue`会堆积，可能触发输入超时与ANR判定。

补充：版本差异观察点。

- 新版本系统中`MotionEvent`与分发链路更强调`displayId`，多显示场景下必须关注事件所属display。
- 高刷新率设备上，输入批处理与Vsync协同更明显，卡顿排查要同时看输入阶段与绘制阶段。
- 建议把输入链路日志与`FrameTimeline`一起看，避免只看`View`层导致定位偏差。

## 相关示例



## 参考链接

[InputReaderThread](http://gityuan.com/2016/12/11/input-reader/)

[Android相关源码](https://cs.android.com)

[一次触摸，Android 到底干了啥](https://zhuanlan.zhihu.com/p/31210271)

[反思|Android 事件分发机制的设计与实现](https://juejin.cn/post/6844903926446161927#heading-14)

[深入理解Android卷-III](https://wizardforcel.gitbooks.io/deepin-android-vol3/content/5.html)
