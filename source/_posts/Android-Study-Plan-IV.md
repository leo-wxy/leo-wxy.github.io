---
title: Android Study Plan IV
date: 2018-03-18 17:47:55
tags:  Android
---
# Android学习计划
 话题：关于startActivityForResult
1、startActivityForResult的使用场景是什么？onActivityResult回调里面的resultCode和requestCode以及intent含义是什么？
2、Activity A启动B的时候，在B中何时该执行setResult ？setResult可以位于Activity的finish方法之后吗？

# 答案
## 1.  startActivityForResult 使用场景是什么？ requestCode、 resultCode 含义是什么？

### 1.1  使用场景
- 用户开始新的活动，并且希望得到新活动的某些信息。比如选择照片、选择联系人、选择收货地址、进行某块数据编辑工作等。

### 1.2  requestCode
- 解决的是「区分多个异步任务」的问题。与其他异步 API 的设计类似，如果没有这个信息，那么 Activity 在收到响应时会进入混乱的状态。比如他不知道自己得到的是选择照片还是选择联系人的结果。
- 该信息会发送到 AMS 那边的 ActivityRecord.requestCode 变量进行记录，Client 端新 Activity 并不知道这个信息。
-   为什么 `requestCode`\< 0 时收不到结果？
	- ActivityStarter 收到 startActivityLocked 时，写入ActivityRecord.resultTo 变量为空[对应源码][1]
``` java
        ActivityRecord sourceRecord = null;
        ActivityRecord resultRecord = null;
        if (resultTo != null) {
            sourceRecord = mSupervisor.isInAnyStackLocked(resultTo);
            if (DEBUG_RESULTS) Slog.v(TAG_RESULTS,
                    "Will send result to " + resultTo + " " + sourceRecord);
            if (sourceRecord != null) {
                if (requestCode >= 0 && !sourceRecord.finishing) {
                    resultRecord = sourceRecord;
                }
            }
        }
```
-  在 ActivityStack 收到 finishActivityResultsLocked 时，读取 ActivityRecord.resultTo 变量为空，结果数据不会添加到源 ActivityRecord.results 变量
-  在 ActivityStack 收到 resumeTopActivityInnerLocked 时，读取 ActivityRecord.results 数组为空，不会分发结果数据，这样源 Activity 也就没有结果回调了

### 1.3 resultCode
- 异步调用结果码，告诉调用者成功/失败/其它信息
- 该信息由被调用 Activity / framework 写入，并经过 AMS 传递给源 Activity
- `RESULT_CANCELED=0` `RESULT_OK=-1` `RESULT_FIRST_USER=1`
### 1.4 intent
- 用于存储需要传递的数据
- 大小不得大于1M

## 2. A 启动 B ，B 中何时执行 setResult ? setResult 是否可以位于 finish 之后？
### 2.1 setResult 在 finish 之前执行，只是把数据记录在 Activity.mResultCode 和 Activity.mResultData 变量中
Activity 构造器阶段
大部分在显示调用finish()或者onBackPressed()
	```java
	  public final void setResult(int resultCode, Intent data) {//进行赋值
	       synchronized (this) {
	           mResultCode = resultCode;
	          mResultData = data;
	       }
	    }
	
	 // Home 键 + 不保留后台 Activity 可触发 onDestroy
	protected void onDestroy() {
	        if (DEBUG_LIFECYCLE) Slog.v(TAG, "onDestroy " + this);
	        mCalled = true;
	
	        // dismiss any dialogs we are managing.
	        if (mManagedDialogs != null) {
	            final int numDialogs = mManagedDialogs.size();
	            for (int i = 0; i < numDialogs; i++) {
	                final ManagedDialog md = mManagedDialogs.valueAt(i);
	                if (md.mDialog.isShowing()) {
	                    md.mDialog.dismiss();
	                }
	            }
	            mManagedDialogs = null;
	        }
	
	        // close any cursors we are managing.
	        synchronized (mManagedCursors) {
	            int numCursors = mManagedCursors.size();
	            for (int i = 0; i < numCursors; i++) {
	                ManagedCursor c = mManagedCursors.get(i);
	                if (c != null) {
	                    c.mCursor.close();
	                }
	            }
	            mManagedCursors.clear();
	        }
	
	        // Close any open search dialog
	        if (mSearchManager != null) {
	            mSearchManager.stopSearch();
	        }
	
	        if (mActionBar != null) {
	            mActionBar.onDestroy();
	        }
	
	        getApplication().dispatchActivityDestroyed(this);
	    }
	
	 private void finish(int finishTask) {
	        if (mParent == null) {
	            int resultCode;
	            Intent resultData;
	            synchronized (this) {
	                resultCode = mResultCode;
	                resultData = mResultData;
	            }
	            if (false) Log.v(TAG, "Finishing self: token=" + mToken);
	            try {
	                if (resultData != null) {
	                    resultData.prepareToLeaveProcess(this);
	                }
	                if (ActivityManager.getService()
	                        .finishActivity(mToken, resultCode, resultData, finishTask)) {
	                    mFinished = true;
	                }
	            } catch (RemoteException e) {
	                // Empty
	            }
	        } else {
	            mParent.finishFromChild(this);
	        }
	    } 
	    ```
### 2.2 否
-  如果位于 finish 之后执行，信息已经无法放到传递的数据中
-   从代码可以看出 setResult 和 finish 类似生产者/消费者模型，setResult 负责写入数据，finish 负责读取数据

### 2.3 线程安全问题
- Activity.mResultCode 和 Activity.mResultData 变量由 Activity 对象的锁进行保护
- 支持后台线程和 UI 线程分别进行 setResult 和 finish
- 但是为什么需要加锁保护这两个信息？需要「解决什么问题」？

### 2.4 API 设计/数据组装问题
 - 底层 AMS 提供的接口的参数是 setResult 和 finish 的参数的组合形式，但是 Activity 为什么把一个接口拆分成两个接口给开发者使用？

- 使用方便。很多情况下调用者只关心 finish ，不需要理解太多的信息

### 2.5 启动模式冲突
- 5.0以上 singleTask和singleInstance失效，重复启动时会重新创建实例
- 以下 则会直接收到`RESULT_CANCELED`

## 3. API 内部原理/数据处理流程
{% fullimage /images/study_plan/study_plan_4.png, alt,流程图 %}
> 关键节点：
-  Client 端通过 AMP 把数据发送给 Server 端 AMS Binder 实体
-  AMS 把数据包装成 ActivityResult 并保存在源 ActivityRecord 的 results 变量中
- AMS 通过 ApplicationThreadProxy 向 Client 端发送 pause 信息让栈顶 Activity 进入 paused 状态，并等待 Client 端回复或超时
- AMS 接收 Client 端已 paused 信息，恢复下一个获取焦点的 Activity ，读取之前保存在 ActivityRecord.results 变量的数据派发给 Client 端对应的 Activity
- Client 端数据经过 ApplicationThread 对象、ActivityThread 对象的分发最后到达 Activity

## 4. startActivityForResult 和 singleTask 导致源 Activity 收不到正确结果问题
### 4.1 基本原则
> 源 Activity 和目标 Activity 无法在跨 Task 情况下通过 onActivityResult 传递数据
### 4.2 Android 5.0 以上 AMS 在处理 manifest.xml 文件中的 singleTask 和 singleInstance 信息「不会」创建新的 Task，因此可以收到正常回调
 [源码链接][2]
### 4.3 Android 4.4.4 以下 AMS 在处理 manifest.xml 文件中的 singleTask 和 singleInstance 信息「会」创建新的 Task，因此在 startActivity 之后立即收到取消的回调
[源码链接][3]   
### 4.4 通过 dumpsys activity activities 命令查看 AMS 状态，验证两个 Activity 是否属于不同的 Task

[1]:	http://androidxref.com/7.0.0_r1/xref/frameworks/base/services/core/java/com/android/server/am/ActivityStarter.java#266
[2]:	http://androidxref.com/7.0.0_r1/xref/frameworks/base/services/core/java/com/android/server/am/ActivityStarter.java#1196
[3]:	http://androidxref.com/4.4.4_r1/xref/frameworks/base/services/java/com/android/server/am/ActivityStackSupervisor.java#1399