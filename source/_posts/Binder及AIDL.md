---
title: IPC机制
date: 2018-12-11 14:24:06
tags: Android
top: 11
---

# IPC机制

{% fullimage /images/IPC机制.png,IPC机制,IPC机制%}

> IPC是Inter-Process Communication的缩写。含义为进程间通信或者跨进程通信，指代两个进程间进行数据交换的过程、

还需要理解进程以及线程的区别和联系

> 进程：一般指一个执行单元，在设备上一般代指应用程序。
>
> 线程：CPU调度的最小单元且线程是有限资源。
>
> 一个进程可以包含多个线程，即一个应用内部可以执行多个任务。在Android中就会区分为`主线程(UI线程)`和`子线程`，一般会在子线程上做耗时操作，主线程不可。

由于IPC的使用场景是在多进程模式下。多进程的使用情况主要分为两种：`一个应用因为某些原因需要采用多进程模式来实现，比如获取更大内存空间`,`当前应用需要向其他应用来获取数据`。

## 1.  多进程模式

   1. 开启多进程模式

      - 通过JNI在native层fork一个新的进程
      - 在`AndroidManifest.xml`中给四大组件指定属性`android:process`。

   2. 进程名的命名

      ```xml
      <activity 
                android:name="com.wxy.test.AActivity"
                android:process=":remote"/>
      <activity
                android:name="com.wxy.text.BActivity"
                android:process="com.wxy.test.remote"/>
      ```

      上述代码为两种命名方案

      - 省略包名以:开头：代指进程名为`com.wxy.test:remote`为**私有进程**，其他应用的组件不可以和他跑到同一个进程中
      - 完整命名：如上述`com.wxy.test.remote`为**全局进程**，其他应用可以通过`ShareUID方式与他在同一进程中运行。`

      Android系统会为每一个应用分配一个唯一的UID，具有相同UID的应用才能共享数据。

      上述通过ShareUID将两个应用跑在同一个进程间是有要求的，**必须是两个应用具有相同的ShareUID且签名相同才可以**。达成上述要求时就可以 **共享两者间的data目录、组件信息以及内存数据**。

      拓展知识：当两者签名不同时，会触发安装错误[INSTALL_FAILED_SHARED_USER_INCOMPATIBLE]

   3. 查看进程信息

      `adb shell ps|grep $packageName`

   4. 运行机制

      Android为每一个应用分配了一个独立的虚拟机，或者说为了每一个进程分配一个独立的虚拟机，不同的虚拟机在内存分配上就会有不同的地址空间，就会导致不同的虚拟机访问同一个类的对象会产生多分副本。

      **所有运行在不同进程的四大组件，只要他们通过内存共享数据，就会共享失败。**

   5. 多进程的优点

      - Android系统对每个应用占用内存是有限制的，占用内存越大越容易被杀死。可以提出组件运行于单独的进程中，减少主进程占用内存，降低被杀死几率。
      - 子进程如果因为某种原因崩溃不会影响到主进程的使用。
      - 独立进程的启动与退出不依赖于用户的使用，可以完全独立的控制，不会因为主进程的退出而结束。

   6. 多进程造成的问题

      - 静态成员变量和单例模式完全失效
      - 线程同步机制失败
      - SharedPreferences的可靠性下降 `不支持多进程读写`
      - Application会多次创建`分配了独立的虚拟机`

   一个应用内的多进程：**相当于两个不同的应用采用了ShareUId模式**。虽说不能直接共享内存数据，但是可以通过跨进程通信来实现数据交互。

## 2. 序列化

>  当我们需要跨进程通信时，传递的数据就需要进行序列化传递，然后接受方在反序列化得到传递数据

   > 什么是序列化？
   >
   > 将对象转化为可以传输的二进制流的过程，就可以通过序列化，转化为可以在网络传输或者保存到本地的流，从而进行传输数据。反序列化即为从二进制流转化为对象的过程。
   >
   > 也为了解决对象的持久化问题。当你在程序中声明一个类后，程序关闭则释放对象，持久化就是为了应用关闭后类的内容依然存在。

   1. `Serializable`

      > 由Java提供的一个序列化接口，为对象提供标准的序列化以及反序列化操作。

      使用方式相当简单

      ```java
      public class User implements Serializable{
          //该参数是用来辅助序列化以及反序列化的过程，原则上该值相同才可以进行序列化以及反序列化的操作.
          //不指定时 系统也会自动生成 但是容易因为变量的数量和类型发生改变而导致序列化失败。
          private static final long serialVersionUID = 123123L;
          
          public String name;
          ...
      } 
      ```

      优缺点：使用简单但是效率较低，在序列化(ObjectOutputStream)以及反序列化(ObjectInputStream)类调用中会有大量的I/O操作。

      适用场景：将对象类序列化存储到设备或者需要网络传输。

   2. `Parcelable`

      > Android提供的序列化接口，使用起来较为繁琐

      ```java
      import android.os.Parcel;
      import android.os.Parcelable;
      
      public class User implements Parcelable {
      
          public String name;
      
          protected User(Parcel in) {
              name = in.readString();
          }
      
          public static final Creator<User> CREATOR = new Creator<User>() {
              @Override
              public User createFromParcel(Parcel in) {
                  return new User(in);
              }
      
              @Override
              public User[] newArray(int size) {
                  return new User[size];
              }
          };
      
          @Override
          public int describeContents() {
              return 0;
          }
      
          @Override
          public void writeToParcel(Parcel dest, int flags) {
              dest.writeString(name);
          }
      }
      ```

      序列化功能由`writeToParcel`实现，反序列化由`Parcel的read`实现。

      优缺点：传递效率高效使用较为繁琐，主要序列化都在内存上进行。由于Parcelabel是Android提供的方法，可能会由于版本更新而会有些许改动。

      适用场景：在内存的序列化中使用。

## 3. IPC方式

> 本节主要讲述各种跨进程通信方式，目前有以下六种：
>
> {% fullimage /images/IPC-mode.png,IPC方式, IPC方式 %}
>
> 上述方式实际都是通过Binder来实现的

### 1.Bundle

> 支持在`Activity、Service和Receiver`之间通过Intent来传递Bundle数据(调用`intent.putExtra()`)，由于Bundle实现了Parcelable接口，所以可以方便的在不同进程间传递(`传输的数据必须可以被序列化，不然无法进行传递`)。可以看做为一个特殊的Map类型。
>
> **最简单的进程间通信方式。**

拓展：当A进程计算后的结果无法通过Bundle传递至B进程时，可以将计算的过程用B进程的一个Service进行操作，然后在回调给B进程。

> 为什么Bundle不直接使用HashMap呢？
>
> 1. Bundle内部是由ArrayMap实现的，ArrayMap实质内部为两个数组，一个是`int[]`用于保存每个item的`hashCode`，另一个`Object[]`用于保存`key/value`键值对，容量为上一个数组的2倍。在添加、查找数据时，只要用二分查找法找到对应位置进行操作即可。占用内存也会小于`HashMap`。
> 2. 在Android中如果需要使用Intent传递数据的话，需要的数据类型必须为`基本类型`或`可序列化类型`，`HashMap`采用`Serializable`进行序列化，`Bundle`采用了`Paracelable`进行序列化，更加适合于Android平台，在内存中完成序列化功能，开销更小。

### 2.文件共享

> **两个进程间通过读/写一个文件来进行数据传递**，适用于对数据同步要求不高的进程间通信，并且需要对**并发读/写**进行妥善处理

拓展：Android中的SharedPreferences也是文件共享方案的一种，但由于系统提供了一种缓存策略(内存中会有一份该文件的缓存)，导致它在多进程模式下，读/写并不可靠，甚至丢失数据。

### 3.Messenger

> 轻量级的IPC方案，可以在不同的进程间传递Message对象。调用`Messenger.send(Message message)`传递Message对象。
>
> Messager的底层实现是`AIDL`。它对AIDL做了封装，由于它一次只可以处理一个请求**（串行请求）**，因此不需考虑线程同步的问题。不过不能直接调用服务端的方法，只能通过传递消息处理。
>
> 由于主要传递的都是Message对象，导致无法实现远程调用。

Messenger的构造函数分以下两种：

 ```java
 public Messenger(IBinder target){
     mTarget = IMessenger.Stub.asInterface(target);
 }
 
 public Messenger(Handler target){
     mTarget = target.getImessenger();
 }
 ```
>
> 拓展：**Handler主要用于线程间通信，Messenger用于进程间通信**

实现一个Messenger需要以下两步：

- **服务端进程**：

  ①创建一个Service来处理客户端的连接请求

  ②创建一个Handler并由他构造一个Messenger对象

  ③然后在Service的onBind方法中返回该Messenger对象中的Binder。

  代码示例：

  ```java
  //MessengerServcice.java
  public class MessengerService extends Service {
      private static class MessengerHanler extends Handler {
          @Override
          public void handleMessage(Message msg) {
             //处理返回的Message消息
              ...
                  //获取Client返回的Messenger对象
                      Messenger client = msg.replyTo;
                      if (client != null) {
                          //拼接数据 发送消息
                      }
              
          }
      }
      //通过Handler构造一个Messenger对象
      private final Messenger mMessenger = new Messenger(new MessengerHanler());
     
      @Override
      public IBinder onBind(Intent intent) {
          //返回IBinder对象 将消息交由对应Handler处理
          return mMessenger.getBinder();
      }
  }
  ```

- **客户端进程**：

  ①绑定服务端Service --`bindService`

  ②绑定后使用Service返回的IBinder对象创建一个Messenger对象

  ③通过Messenger对象向服务端发送Message  **完成单向通信**

  ④创建一个Handler由此创建一个Messenger对象，然后将Messenger对象放入Message的**replyTo**字段传递给Server。  **完成双向通信**

  代码示例：

  ```java
  public class MessengerActivity extends Activity {
      @Override
      protected void onCreate(Bundle savedInstanceState) {
          super.onCreate(savedInstanceState);
          setContentView(R.layout.activity_messenger);
          Intent intent = new Intent(this, MessengerService.class);
          bindService(intent, mConnection, Context.BIND_AUTO_CREATE);
      }
  
      private Messenger mService;
      private ServiceConnection mConnection = new ServiceConnection() {
          @Override
          public void onServiceConnected(ComponentName name, IBinder service) {
              mService = new Messenger(service);
              Message msg = Message.obtain(null, 1);
              Bundle data = new Bundle();
              data.putString("msg", "it is from client");
              msg.setData(data);
              //若存在则形成了双向通信
              msg.replyTo = mGetReplyMessenger;
              try {
                  mService.send(msg);
              } catch (RemoteException e) {
                  e.printStackTrace();
              }
          }
  
          @Override
          public void onServiceDisconnected(ComponentName name) {
  
          }
      };
  
      private Messenger mGetReplyMessenger = new Messenger(new MessengerHanler());
      private static class MessengerHanler extends Handler {
          @Override
          public void handleMessage(Message msg) {
             //处理消息
          }
      }
  
      @Override
      protected void onDestroy() {
          //取消绑定service
          unbindService(mConnection);
          super.onDestroy();
      }
  }
  ```

Messenger的工作原理：

{% fullimage /images/Messenger-principle.png,Messenger工作原理,Messenger工作原理 %}

### 4.AIDL

{% post_link Binder系列-Binder%}

### 5.ContentProvider

> ContentProvider是专门用于不同应用间进行数据共享的方式，底层同样是由Binder实现。**主要是提供了一个统一的接口为了存储和获取数据。**

[ContentProvide](https://www.jianshu.com/p/9048b47bb267)

### 6.Socket

> Socket也称为"套接字"，是网络通信中的概念，分为流式套接字(`基于TCP协议，采用流的方式提供可靠的字节流服务`)和用户数据报套接字（`基于UDP协议，采用数据报文提供数据打包发送的服务`）两种。**Socket不仅可以跨进程通信还可以跨设备通信。**

`TCP协议是面向连接的协议，提供稳定的双向通信功能，因为连接的建立需要经过'三次握手'才能完成，由于本身提供了超时重传机制，因此具有很高的稳定性。`

`UDP是无连接的，提供不稳定的单向通信功能，在性能上拥有良好的效率，但数据不一定能够有效传输。`

1. 实现方法：

   服务端：

   - 创建一个Service，在线程中建立TCP服务，监听相应的端口等待客户端连接请求
   - 与客户端连接时，会生成新的Socket对象，利用它可与客户端进行数据传输
   - 断开连接时，关闭相应的socket并结束线程

   客户端：

   - 开启一个线程，通过Socket发起连接请求
   - 连接成功后，读取服务端消息
   - 断开连接，关闭Socket

2. 注意事项：

   - 需要声明网络权限



以上6种IPC方式比较：

| 名称            | 优点                                                         | 缺点                                                | 适用场景                                                   |
| --------------- | ------------------------------------------------------------ | --------------------------------------------------- | ---------------------------------------------------------- |
| Bundle          | 简单易用                                                     | 只能传输Bundle支持的数据类型                        | 四大组件的进程间通信                                       |
| 文件共享        | 简单易用                                                     | 不适合高并发场景，且无法做到实时通信                | 无并发访问情形，数据简单且实时性不高                       |
| AIDL            | 功能强大，支持一对多并发通信，支持实时通信                   | 使用稍复杂，需要处理好线程同步                      | 一对多通信且支持远程调用                                   |
| Messenger       | 功能强大，支持一对多串行通信，支持实时通信                   | 不能很好处理高并发场景，数据只能通过Message进行传输 | 低并发的一对多即时通信，并且不需要返回结果，不需要远程调用 |
| ContentProvider | 在数据访问方面功能强大，支持一对多数据共享，可通过Call方法扩展其他操作 | 受约束的AIDL实现，主要提供对数据的CRUD操作          | 一对多的进程间数据共享                                     |
| Socket          | 功能强大，可以通过网络传输字节流，支持一对多并发通信         | 实现细节稍微麻烦                                    | 网络数据交换                                               |
