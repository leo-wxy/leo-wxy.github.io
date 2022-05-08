---
title: Android-Study-Plan-XV -- 四大组件
date: 2018-05-13 09:50:49
tags: Android
---

# Android学习计划

## Android中的四大组件每个组件的作用是什么？他们都可以开启多进程吗？

### Android四大组件：

1. **`Activity`**

   > Activity的主要作用是展示一个界面并和用户直接交互。

   activity的启动由Intent触发（**需要在AndroidManifest.xml中注册**）。Intent分为两种：

   - 显示Intent：直接跳转至指定的Activity类

     ```java
     // 构造方法中直接传入Component
     Intent intent=new Intent(this,Activity.class);
     startActivity(intent);
     
     // 调用SetComponent方法
     ComponentName componentName=new Component(this,Activity.class);
     Intent intent=new Intent();
     intent.setComponentName(componentName);
     startActivity(intent);
     
     // 使用setClass方法
     Intent intent=new Intent();
     intent.setClassName(this,Activity.class);
     startActivity(intent);
     ```

   - 隐式Intent：不明确指定启动哪个Activity，而是利用Activity配置的Action，Data，Category来让系统进行选择(`筛选是根据所有的<intent-filter>来筛选`)

     ```java
      <activity android:name=".MainActivity">
                 <intent-filter>
                     <action android:name="TestActivity" />
                     <category android:name="android.intent.category.DEFAULT" />
                 </intent-filter>
     </activity>
     
     // setAction方法
     Intent intent=new Intent();
     intent.setAction("TestActivity");
     startActivity(intent);
     
     //直接构造Action
     Intent intent=new Intent("TestActivity");
     startActivity(intent);
     
     //在使用隐式调用时需要注意该Action是否存在,所以需要做try-catch防止异常发生
     //利用这个方法可以判断是否有处理该Action的Activity存在
     intent.resolveActivity(getPackageManager())
     ```

2. **`Service`**

   Service主要用于在后台执行一系列需要耗时的任务，需要单独的线程去完成，因为Service本身是运行在主线程的。Service不会与UI进行交互，其他的组件也可以启动Service，即便用户切换了应用，Service依然后台运行。（**需要在AndroidManifest.xml中注册**），Service有两种启动方式：

   - `startService`：启动一个Service，系统回调`onStartCommand()方法`，需要调用`stopService()`来停止Service
   - `bindService`：绑定一个Service，调用`unBindService()`来取消绑定，或者关闭绑定的组件也可以停止

3. **`BroadcastReceiver`**

   [完整介绍](https://www.jianshu.com/p/ca3d87a4cdf3)

   广播主要用于在不同的组件甚至不用的应用间进行消息传递，不与用户产生交互，工作在系统内部。

   广播的注册方式有两种：

   - 静态注册 （**需要在AndroidManifest.xml中注册**）

     ```xml 
     <receiver android:name=".MyReceiver"
               android:enabled=["true" | "false"]
     <!--此broadcastReceiver能否接收其他App的发出的广播-->
     //默认值是由receiver中有无intent-filter决定的：如果有intent-filter，默认值为true，否则为false
         android:exported=["true" | "false"]
         android:label="string resource"
     <!--具有相应权限的广播发送者发送的广播才能被此BroadcastReceiver所接收-->
         android:permission="string"
               >
     <intent-filter>
         <action android:name="com.test"/>
     </intent-filter>
     </receiver>
     ```

   - 动态注册

     ```java
     //最好在onResume中注册广播  
     @Override
       protected void onResume(){
           super.onResume();
           
           mBroadcastReceiver=new BroadcastReceiver();
           IntentFilter intentFilter=new IntentFilter();
           intentFilter.addAction("com.test");
           this.registerReceiver(mBroadcastReceiver,intentFilter);
       }
     
     //在onPause中取消注册
     @Override
     protected void onPause(){
         super.onPause();
         
         this.unregisterReceiver(mBroadcastReceiver);
     }
     
     ```

4. **`ContentProvider`**

   [相关链接](https://www.jianshu.com/p/ea8bc4aaf057)

   主要用于给不同的应用提供共享数据,（**需要在AndroidManifest.xml中注册**）

   ```xml
   <provider 
             android:name="wxy.provider.MyContentProvider"
             android:authorities="wxy.provider"
             android:exported="true" 
             <!--是否可被其他应用使用 -->
             >
   </provider>
   ```

   ContentProvider默认执行在主线程，需要实现以下方法

   - `onCreate()`：初始化Provider
   - `query()`：查询数据 **需异步操作**
   - `insert()`：插入数据
   - `update()`：更新Provider的数据
   - `delete()`：删除Provider的数据
   - `getType()`：返回指定Uri中的数据MIME类型

   相关的操作可能会被多个线程并发调用需要注意线程安全。



### 开启多进程

Android的四大组件都可以开启多进程，只要在AndroidManifest.xml中配置`android:process="any"`，需要配置`android:exported`属性