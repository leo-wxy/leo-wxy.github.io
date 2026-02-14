---
title: ANR分析
date: 2019-01-28 09:56:42
tags: Android
top: 10
---

<!--简要解释一下 ANR？为什么会发生 ANR？如何避免发生 ANR？如何定位 ANR？ANR发生条件？如何分析ANR-->

## ANR概述

> ANR：`Application Not Responding`应用程序未响应，Android会要求一些事件需要在规定时间内处理完成，如果超过预定事件内未能得到有效响应或者响应时间过长，就会造成ANR。

ANR由**消息处理机制**保证，Android在系统层实现了发现ANR的机制，核心原理是**消息调度和超时处理**。

ANR本质是**性能问题**。实际上是对应用程序主线程的限制，要求主线程在限定时间内处理完一些最常见的操作(*启动服务，处理广播，处理输入*)，如果处理超时，则认为主线程已经失去了响应其他操作的能力。

## ANR发生场景

- **输入事件(按键和触摸事件)5s内未处理**：Input event dispatching timed out
- **BroadcastReceiver的`onReceive()`在规定时间内没处理完(*前台广播为10s，后台广播为60s*)**：Timeout of broadcast BoradcastRecord
- **Service在*前台20s后台200s*时间内为启动完成**：Timeout executing service
- **ContentProvider的`publish()`在10s内没有执行完成**：Timeout publishing content providers

## ANR机制

> ANR机制主要分为两部分：**ANR监测机制**，**ANR报告机制**。
>
> - ANR监测机制：Android对于不同的ANR类型(*Broadcast,Service,InputEvent*)都有一套监测机制。
> - ANR报告机制：在监测到ANR后，需要显示ANR对话框，输出日志等

### 输入事件超时监测

#### 输入系统简介

内核将原始事件写入到设备节点中，`InputReader`在期限错循环不断的从`EventHub`中抽取原始输入事件，进行加工处理后将加工所得的事件放入`InputDispatcher`的派发队列中。`InputDispatcher`在其线程循环中将派发队列中的事件取出，查找合适的窗口，将事件写入到窗口的事件接收管道中。

#### 超时监测

{% fullimage /images/输入事件超时监测.webp,输入事件超时监测,输入事件超时监测%}

`InputDispaycher::dispatchOnceInnerLocked()`：根据事件类型选择不同事件的处理方法

`InputDispaycher::findFocusedWindowTargetsLocked()`：内部调用`checkWindowReadyForMoreInputLocked()`检查窗口是否有新能力在接受新的输入事件。

`InputDispatcher::handleTargetsNotReadyLocked()`：进行判断事件5s之内是否分发完毕

当应用主线程被卡住时，再点击其他组件也是无响应，因为事件派发是串行的，上一事件未处理完毕，下一事件不会向下执行。

在`Activity.onCreate()`执行耗时操作，不管用户如何操作都不会发生ANR，因为输入事件相关监听机制尚未建立起来。

输入事件由`InputDispatcher`调度，待处理的输入输出事件都会进入队列中等待，设计了一个等待超时的判断。

#### Input ANR的子类型

Input ANR本质是：`InputDispatcher`将事件投递给目标窗口后，在超时时间（默认5s）内没有收到窗口“处理完成”的回执（`finish signal`），最终触发`appNotResponding`。

##### Input dispatching timed out

- 含义：目标窗口存在，但窗口在超时时间内没有完成输入事件处理。
- 典型日志关键字：`Input dispatching timed out`、`focused window has not finished processing`、`touched window has not finished processing`。
- 常见根因：主线程执行耗时任务、主线程被锁阻塞、主线程同步Binder/IO调用、CPU资源被其他进程抢占。
- 机制特征：输入分发是串行推进的，前一条事件未完成会阻塞后续输入，用户体感就是“点哪里都没反应”。

##### No focused window

- 含义：系统存在`focused app`，但没有可接收输入的`focused window`。
- 典型日志关键字：`No focused window`、`no window has focus but there is a focused application`。
- 常见根因：Activity启动阶段窗口尚未建立完成、窗口焦点切换异常、窗口被设置为不可获取焦点（如`FLAG_NOT_FOCUSABLE`）。
- 场景特点：冷启动或页面切换阶段更容易出现该类型。

### Service超时监测

本身有分析过`Service的启动流程`，在其中了解到`ActiveServices.realStartServiceLocked()`是真正的Service启动流程。

```java
// ../core/java/com/android/server/am/ActiveServices.java  
// How long we wait for a service to finish executing.
    static final int SERVICE_TIMEOUT = 20*1000;

    // How long we wait for a service to finish executing.
    static final int SERVICE_BACKGROUND_TIMEOUT = SERVICE_TIMEOUT * 10;

//真正启动Service
private final void realStartServiceLocked(ServiceRecord r,
            ProcessRecord app, boolean execInFg) throws RemoteException {
        ...
        // 主要是为了设置ANR超时，可以看出在正式启动Service之前开始ANR监测；
        bumpServiceExecutingLocked(r, execInFg, "create");
       // 启动过程调用scheduleCreateService方法,最终会调用Service.onCreate方法；
        app.thread.scheduleCreateService(r, r.serviceInfo,
        // 绑定过程中，这个方法中会调用app.thread.scheduleBindService方法
        requestServiceBindingsLocked(r, execInFg);
        // 调动Service的其他方法，如onStartCommand，也是IPC通讯
        sendServiceArgsLocked(r, execInFg, true);
    }

//设置超时监测                                         
void scheduleServiceTimeoutLocked(ProcessRecord proc) {
        if (proc.executingServices.size() == 0 || proc.thread == null) {
            return;
        }
        Message msg = mAm.mHandler.obtainMessage(
                ActivityManagerService.SERVICE_TIMEOUT_MSG);
        msg.obj = proc;
        // 在serviceDoneExecutingLocked中会remove该SERVICE_TIMEOUT_MSG消息，
        // 当超时后仍没有remove SERVICE_TIMEOUT_MSG消息，则执行ActiveServices. serviceTimeout()方法；
        mAm.mHandler.sendMessageDelayed(msg,
                proc.execServicesFg ? SERVICE_TIMEOUT : SERVICE_BACKGROUND_TIMEOUT);
        // 前台进程中执行Service，SERVICE_TIMEOUT=20s；后台进程中执行Service，SERVICE_BACKGROUND_TIMEOUT=200s
    }

//在AMS中收到了  SERVICE_TIMEOUT_MSG Message就会触发该方法                                       
void serviceTimeout(ProcessRecord proc) {
    ...
    final long maxTime =  now -
              (proc.execServicesFg ? SERVICE_TIMEOUT : SERVICE_BACKGROUND_TIMEOUT);
    ...
    // 寻找运行超时的Service
    for (int i=proc.executingServices.size()-1; i>=0; i--) {
        ServiceRecord sr = proc.executingServices.valueAt(i);
        if (sr.executingStart < maxTime) {
            timeout = sr;
            break;
        }
       ...
    }
    ...
    // 判断执行Service超时的进程是否在最近运行进程列表，如果不在，则忽略这个ANR
    if (timeout != null && mAm.mLruProcesses.contains(proc)) {
        anrMessage = "executing service " + timeout.shortName;
    }
    ...
    if (anrMessage != null) {
        // 当存在timeout的service，则执行appNotResponding，报告ANR
        mAm.appNotResponding(proc, null, null, false, anrMessage);
    }
}
```

Service启动前会先启动超时监测，如果在指定时间内(*前台20s后台200s*)没有启动完毕，就会调用到`ActiveServices.serviceTimeout()`报告ANR；如果执行完毕，会调用到`ActiveServices.serviceDoneExecutingLocked()`在其中`removeMessages(SERVICE_TIMEOUT_MSG)`移除超时消息。

### ANR报告机制

无论哪种类型的ANR发生后，最终都会调用到`AppErrors.appNotResponding()`。这个方法主要的功能就是**向用户或开发者报告ANR发生了。**最终的表现就是弹出一个对话框，告诉用户当前程序无法响应；并且会输出ANR日志，以供开发者分析。

- **event log**：通过检索"am_anr"关键字，可以找到发生ANR的应用
- **main log**：通过检索"ANR in"关键字，可以找到ANR的信息，日志的上下文会包含CPU的使用情况
- **dropbox**：通过检索"anr"类型，可以找到ANR的信息
- **traces**：发生ANR时，各进程的函数调用栈信息 (*可以通过`adb pull data.anr/traces.txt`导出trace文件*)

ANR报告相关内容主要为以上四种，后续如果需要分析ANR问题，分析ANR往往是从`main log中的CPU使用情况和导出的traces.txt文件`进行分析。

## ANR分析

ANR问题的产生是由于主线程的任务无法在规定事件内无法完成。造成这种情况的原因大致会有以下几点：

- 主线程在做一些耗时的工作
- 主线程被其他线程锁
- cpu被其他线程占用，导致该进程没有被分配到足够的CPU资源

分析思路主要是:

1. `从log中找到ANR发生的信息`：在log中搜索`am_anr或ANR in`找到ANR发生的log，包含了ANR发生的时间，进程，ANRtype。
2. `继续分析CPU usage的信息`：表明了CPU在ANR前后的用量，从各种CPU usage信息中可以分析几点：
   - 如果其他进程占用CPU较多，而发生ANR的进程占用较低，可以认为是 因为CPU资源未分配足够，导致的ANR
   - 如果ANR进程占用CPU较多，可以怀疑是内部一些不合理的代码导致CPU资源大量消耗，如出现了死循环或者后台有大量线程在执行任务，或者存在频繁的文件读写(*iowait*)
   - CPU总用量都不高，该进程和其他线程的占用过高，可能是由于主线程的操作耗时过长，或者主线程被锁导致。
3. `向下继续分析 trace文件`：trace文件记录了发生ANR前后该进程中各个线程的stack。对我们分析ANR问题最有价值的就是主线程的stack(`main`)。一般主线程trace中可能有如下几种情况：
   - 主线程是`running或native`而对应的栈对应了我们应用中的函数，则很有可能是执行该函数发生了超时
   - 主线程是`block`，主线程被锁，可以考虑进行优化代码，解除掉锁的状态。如果是死锁问题，需要及时处理

### Input ANR排查关键字

针对Input ANR，建议按“`ANR原因` -> `输入分发` -> `窗口焦点` -> `主线程堆栈`”顺序排查。

1. `ANR原因定位`：`am_anr`、`ANR in`、`Reason:`、`Input dispatching timed out`、`No focused window`
2. `输入分发状态`：`InputDispatcher`、`Wait queue`、`head age`、`has not finished processing`
3. `CPU负载信息`：`Load:`、`CPU usage from`、`TOTAL`、`iowait`、`faults major/minor`
4. `主线程阻塞特征`：`"main"`、`state=Blocked|Runnable|Native`、`waiting to lock`、`BinderProxy.transact`
5. `窗口与焦点状态`：`mCurrentFocus`、`mFocusedApp`、`FocusedWindow`、`FocusedApplication`

可直接使用以下命令快速检索：

```shell
adb logcat -b events -v threadtime | rg "am_anr|ANR in|Reason:"
adb logcat -v threadtime | rg "Input dispatching timed out|No focused window|InputDispatcher|Wait queue|head age|has not finished processing"
adb shell dumpsys window | rg "mCurrentFocus|mFocusedApp|hasFocus"
adb shell dumpsys input | rg "FocusedApplication|FocusedWindow|ANR|Wait queue"
adb pull /data/anr/traces.txt
```



## ANR避免和检测

默认情况下，Android应用程序通常在单线程上运行——**主线程**。ANR的发生场景主要是在主线程中进行了耗时操作。

> 哪些算作UI主线程？
>
> - Activity的所有生命周期回调都是执行在主线程的
> - Service默认执行在主线程
> - BoradcastReceiver的`onReceive()`回调在主线程
> - 没有使用子线程的Looper的Handler实现的`handleMessage()`
> - AsyncTask除了`doInBackground()`执行在主线程
> - View的`post(runnable)`执行在主线程

**主要原则是不要在主线程中做耗时操作。**



检测可以利用BlockCanary -- 基本原理是利用主线程的消息队列处理机制，通过对比消息分发开始和结束的时间点来判断是否超过设定的时间，超过则判断为线程卡顿。



## ANR日志分析

> 上面有说到，`发生ANR的时候，系统会产生一份anr日志（置于 /data/anr/ 目录下），一般称为trace文件`。



### `trace文件`获取

```shell
adb pull /data/anr/traces.txt
```

或者

```shell
adb bugreport
# 可以获取当前所有的错误报告
```



### `trace文件`结构

#### CPU负载

```java
Load: 2.62 / 2.55 / 2.25
CPU usage from 0ms to 1987ms later (2020-03-10 08:31:55.169 to 2020-03-10 08:32:17.156):
  41% 2080/system_server: 28% user + 12% kernel / faults: 76445 minor 180 major
  26% 9378/com.xiaomi.store: 20% user + 6.8% kernel / faults: 68408 minor 68 major
........省略N行.....
66% TOTAL: 20% user + 15% kernel + 28% iowait + 0.7% irq + 0.7% softirq

```



`Load`-**CPU负载**

> 后面三个数据分别表示 `1、5、15分钟`时的整体CPU负载
>
> 一般第一个数据参考价值最高。



`CPU usage`-**各进程CPU使用率**

> 各个进程占用的CPU情况

还有`Xms to Yms`表示发生ANR的时间点，其中`later`和`ago`主要区别如下：

- `later`：`CPU usage from 0ms to Xms later`表示ANR发生之后的一段时间内，各个进程的CPU使用率
- `ago`：`CPU usage from Xms to 0ms ago`表示ANR发生之前的一段时间内，各个进程的CPU使用率



剩余的就是各个进程的CPU使用率情况

主要涉及以下几个名词的含义

- `user`：用户空间 `kernel`：内核空间。`一般情况下 kernel CPU占用高于 user，则表示发生了大量的系统调用，一般情况都是IO操作`
- `fault`：内存缺页 `minor`：高速缓存中的缺页次数(`进程中的内存访问`) `major`：内存的缺页次数(`进程做IO操作`)



`TOTAL`-**CPU使用汇总**

最前是`总的CPU使用率`

关键的是这几部分：

- `iowait`：表明CPU在等待IO的时间，占用过高就表示`发生大量的IO操作`。**重点关注是否有进程的faults major占用比较多**
- `irq`：硬中断
- `softirq`：软中断



#### 内存信息



#### 堆栈信息



### 典型案例分析
