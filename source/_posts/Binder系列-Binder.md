---
title: Binder系列-Binder
date: 2019-01-06 15:13:51
tags: Android
top: 11
typora-root-url: ../
---

# Android Binder机制相关以及AIDL介绍

{% fullimage /images/Android-Binder机制.png,Android-Binder机制,Android-Binder机制%}

> 在Linux中，为了避免一个进程对其他进程的干扰，进程之间是相互独立的。
>
> Android的进程间通信采用了Binder基于**性能,稳定和安全**方面的考虑：。
>
> 性能：在移动设备上对性能的要求是比较严苛的，在Linux上通信方式例如管道，Socket都需要复制两次数据，Binder只需一次。
>
> `对于消息队列、Socket和管道而言，数据先从发送方的缓存区拷贝到内核开辟的缓存区中，再从内核缓存区拷贝至接收方缓存区，需要两次拷贝过程；Binder是从发送方缓存区到内核的缓存区，而接受方的缓存区与内核缓存区映射在同一块物理地址上，节省了一次数据拷贝的过程。`
>
> 安全：传统的Linux通信是不包含通信双方的身份验证的，Binder自带身份验证，提高了安全性。
>
> `Android提供了UID机制，可以有效的鉴别用户身份。`
>
> 稳定：Binder基于C/S架构，Client有什么需求就丢给Server去完成，职责明确又独立，稳定性更好。

概念：

- 直观来说，Binder是Android中的一个类，实现了IBinder接口。
- IPC角度来说，Binder是Android中的一种跨进程通信方式。
- Android Framework角度来说，Binder是ServiceManager连接各种Manager和相应ManagerService的桥梁。
- 应用层来说，Binder是客户端和服务端进行通信的媒介。

## 1.Linux下传统的进程间通信原理

> Binder通信原理也是基于Linux 下的IPC机制实现的。

### 基本概念

{% fullimage /images/Linux-IPC-Basics.png,Linux进程结构,Linux进程结构%}

上图展示的结构中涉及了一些基础概念：

#### 进程隔离

> 保护系统中进程互不干扰而设计的。在操作系统中，进程与进程间的内存是不共享的，进程1是无法直接访问进程2的数据，来保证数据的安全性。
>
> 进程隔离的条件下，进程之间传递数据就要依靠`IPC机制`进行进程间通信。

进程隔离的实现是利用了`虚拟地址空间`。

#### 进程空间划分

为了保护用户进程不能直接操作内核，保证内核的安全性，所以操作系统从逻辑上将虚拟空间划分为 *内核空间*，*用户空间*。

- **内核空间** 一般占1GB

  系统内核运行的空间，

- **用户空间** 一般占3GB

  用于用户程序执行的空间

*用户空间在不同进程之间是不能共享的，内核空间是各个进程之间共享的*。

#### 系统调用

由于用户空间的权限低于内核空间，但当用户空间需要访问内核资源时(文件操作，访问网络等)，就需要其他方式实现。

**唯一的方式就是通过操作系统提供的`系统调用`接口**。可以做到所有的资源访问都是在内核的控制下进行的，避免用户程序对系统资源的越权访问，提升系统安全和稳定性。

当一个进程执行`系统调用`使用内核代码时，该进程就进入了**内核态**，此时处理器处于特权最高的**0级**内核代码中执行。

当进程执行用户自己的代码时，进程就处于**用户态**。此时处理器处于**3级**用户代码中执行。

#### 传统IPC通信实现

{% fullimage /images/Linux-IPC.png,Linux IPC,Linux IPC%}

根据上述流程，传统IPC机制基本是以下两步：

- 发送方通过`系统调用 copy_from_user`把要发送的数据拷贝到`内核缓存区`中
- 接收方需要开辟一块内存空间，内核通过`系统调用 copy_to_user`将内核缓存区的数据拷贝至接收方开辟的空间中。

以上流程有两个明显的缺点：

1. 性能低下，因为数据需要经历`发送方内存缓存区 -> 内核缓存区 -> 接收方内存缓存区`，就需要两次拷贝过程。
2. 接收方需要开辟一块空间用于存储数据，但并不知道要开辟多大的空间存储数据。因此只能开辟尽量大的空间或者先行获取数据的大小，可能存在时间和空间上的浪费。



#### Linux中的进程通信手段

##### 管道

> 在创建时分配一个page大小的内存，缓存区大小比较有限

##### 消息队列

> 信息需要复制两次，带来额外的CPU消耗；不适合频繁或信息量大的通信

##### 共享内存

> 无需复制，共享缓冲区直接附加到进程的虚拟地址空间，速度快；**但是无法解决进程间同步问题**。

##### 套接字(Socket)

> 接口通用但是传输效率低，主要用于不同机器之间的通信。

##### 信号量

> 常作为一种锁机制，防止某进程正在访问共享资源时，其他进程也访问该资源。**主要作为进程间以及不同线程线程间的数据同步手段。**

##### 信号

> 不适用于信息交换，更适用于进程中断控制，比如非法内存访问。

## 2.Binder基本原理

### Binder底层原理

#### 动态内核可加载模块和内存映射(`mmap()`)

传统的IPC机制例如`管道、Socket`都是内核的一部分，天生就是支持通过内核来实现进程间通信。Binder机制并不是内核中的一部分，这就依赖于`动态内核可加载模块`机制。

*由于模块是具有独立功能的程序，他可以被单独编译但无法独立运行。所以可以利用该机制，动态的将一个内核模块添加至内核空间内，用户进程之间就可以通过这个内核模块实现通信。*

> 在Android系统中，加载进内核空间的模块就是 **Binder驱动**。

Binder机制是如何利用这个模块`Binder驱动`进行进程间通信的呢？

这个时候就涉及到了另一个概念：**内存映射**。

`内存映射`是通过`mmap()`来实现的，`mmap()`是操作系统中的一种内存映射的方法。`内存映射`就是将用户空间内的一块内存区域映射进内核空间。当映射关系建立完成后，用户对这块区域的修改可以直接反映到内核空间，而内核空间对映射区域的修改也可以直接反馈至用户空间。

#### 实现原理

`Binder借助了内存映射的方法，建立内存映射后，发送方发过来的数据拷贝到内核缓存区数据后，对应用户空间的映射区域也能接收到传递的数据，相当于少了一次拷贝过程。`

{% fullimage /images/Binder-IPC.png,Binder IPC,Binder IPC%}

根据流程图分析：

1. `Binder驱动`首先会在内核空间创建一个`数据接收缓存区`
2. 内核空间中有一块`内核缓存区`，利用`内存映射`将`内核缓存区`与`数据接收缓存区`建立映射关系，以及建立与`接收方用户空间`的映射关系。
3. 发送进程将调用`系统调用 copy_from_user`将数据`copy`到`内核缓存区`，由于已经建立了映射关系，相当于数据直接`copy`进接收进程的用户空间。

## 3.Binder通信模型

Binder通信采用了**C/S架构**。在Android系统的Binder机制中，由一系列系统组件组成，分别是

- `Client` 需要自己实现，客户端进程
- `Server` 需要自己实现，服务端进程
- `Service Manager` 由系统提供，将字符形式的Binder名字转化为Client中对该Binder的引用，使得Client可以通过Binder名字获得Server中Binder实体的引用。
- `Binder 驱动` 由系统提供，负责建立进程间的Binder连接，将Client请求转发到具体的Server中执行，并将Server返回值传回给Client。还有进程间的数据交互等底层操作

{% fullimage /images/IPC-Binder.jpg, Binder架构图, Binder架构图 %}

![Binder架构图](/images/IPC-Binder.jpg)

Client,Server,Service Manager处于用户空间，Binder驱动位于内核空间。

下面介绍四个组成部分的作用：

- **Service Manager：**服务的管理者，指代的是Native层的ServiceManager(C++)，是整个Binder通信机制的大管家，是Android进程间通信机制的守护进程。将Binder的名字转换为Client中对该Binder的引用，使得Client可以通过Binder名字来获取Service中的引用。

  `ServiceManager`其实就是一个进程，里面维护了一张表，表里存储的是向它注册过的进程信息。

- **Binder驱动：**主要是驱动设备的**初始化(binder_init)，打开 (binder_open)，映射(binder_mmap)，数据操作(binder_ioctl)**。

  和硬件设备没有任何关系。它工作于内核态，以misc设备注册在设备目录/dev下，用户可以通过/dev/binder访问它。负责进程之间binder通信的建立、传递、计数管理和数据的传递交互等底层支持。主要功能由`ioctl()/*主要负责在两个进程间收发IPC和IPC reply数据，常用命令为BINDER_WRITE_READ*/`实现。

- **Client&Service：**在Binder驱动和Service Manager提供的基础设施上进行C-S之间的通信。`Server进程启动时，将在本进程内运行的Service注册到Service Manager中，并且启动一个Binder线程池，用来接收Client请求。然后Client进程向Service Manager查询所需要的Service，并获得一个Binder代理对象，通过该代理对象向Service发出请求。`

四大组件彼此之间不是直接交互的，都是通过Binder驱动进行交互，从而实现IPC通信方式。**系统需要启动了Service Manager之后，Client端和Server端需要现获取了Service Manager接口后，才可以开始通信服务。**



## 4.Binder通信过程

1. 一个进程通过`BINDER_SET_CONTEXT_MGR`命令将自己注册成`ServiceManager`，`Binder驱动`就会给他创建一个Binder实体
2. `Server`通过`Binder驱动`向`ServiceManager`中注册Binder实体及其名字，声明可以对外提供服务。`Binder驱动`会为这个Binder创建位于内核中的实体节点以及`ServiceManager`中对实体的引用，将名字以及新建的引用打包给`ServiceManager`,`ServiceManager`将其填入查找表。
3. `Server`向`ServiceManager`中注册了Binder实体以及名字后，`Client`就可以通过`Binder驱动`请求`ServiceManager`根据名字获得`Server`的Binder引用。
4. 获得`Server`的Binder引用后，`Client`就可以通过`Binder驱动`直接和对应的Server通信。
5. `Server`接收请求后，需要通过`Binder驱动`将请求结果返回到`Client`中。

{%fullimage /images/Binder通信过程.png,Binder通信过程,Binder通信过程%}

![](/images/Binder通信过程.png)



## 5.Binder代理机制

`Client`通过`ServiceManager`拿到`Server`的Binder引用后，`Client`就可以向`Server`发起请求。

在这一步骤中，`Client`得到的`Server`的Binder引用，其实是一个`Object`，在这个`Object`实现了一些方法；`Client`拿到这个`Object`后就可以直接调用内部的方法了。

实际上，`Client`拿到的并不是`Server`在`ServiceManager`注册的Binder实体，由于经过了`Binder驱动`，在其中做了一次**对象转换**，将Binde实体包装成了一个代理对象(`ProxyObject`)，`ProxyObject`有着和`Object`一样的方法，但是这些方法的内部实现都是**空方法，唯一能做的就是把`Client`的请求参数交给`Binder驱动`。**

`Binder驱动`收到`ProxyObject`传递的方法以及参数后，会在`ServiceManager`中查询是否存在该方法，如果存在*`Binder驱动`就会把代理对象(`ProxyObject`)转换成实际`Server`对象(`Object`)*。然后调用对应的方法，经由`Binder驱动`把返回结果发回给`Client`。

上述流程就是`Binder的代理机制`。



![Binder代理机制](/images/Binder代理机制.png)



## 6.Binder完整定义

根据上述流程，可以对`Binder`进行一个简单的总结：*Binder是基于C/S结构的一种面向对象的IPC机制。包含`Client、Server、Binder驱动和ServiceManager`四大组成部分。*

在不同场景下，Binder有着不同的含义：

- 通常意义上来说，`Binder`指的就是Android的进程间通信机制
- 对于`Server`来说，Binder是提供具体实现的本地对象，在`ServiceManager`注册得到
- 对于`Client`来说，Binder是`Server`本地对象的一个引用，这个引用实际是是有`Binder驱动`进行`对象转换`得到的一个代理对象`ProxyObject`，`Client`通过`ProxyObject`访问`Server`的本地对象。
- 对于传输过程来说，Binder就是一个可以跨进程传输的对象。

## 7.Binder工作机制

> 需要配合客户端的实现分析，主要实现方式就是利用AIDL

### AIDL

> **Android接口定义语言 -- Android Interface Definition Language**
>
> 在Messenger中讲到它是基于AIDL的，但是只能处理串行的消息，如果有大量的消息同时发送进来，也只能一个个处理，而且不支持跨进程调用服务端的方法，就需要用到AIDL来处理上述情况。
>
> **AIDL默认是同步调用的，若需要异步调用--可以添加一个异步回调接口执行结果异步回调给调用方，需要使用RemoteCallbackList**
>
> **AIDL本质上就是系统为我们提供了一种快速实现Binder的工具，我们可以不依赖于AIDL，自己去完全实现一个Binder。**

#### 1.AIDL支持的数据类型

- 基本数据类型：`byte、int、long、float、double、boolean，char`
- String 和 CharSequence
- ArrayList，HashMap(**包括key，每个元素必须可以被AIDL支持**)
- 实现了Parcelabe接口的对象 **必须要显示Import进来**
- 所有AIDL接口本身也会被调用**必须要显示Import进来**

#### 2.定向tag

> 除了基本数据类型，其他类型的参数必须加上方向 **in,out,inout**，用于表示在跨进程通信中的数据流向。

- `in`：表示数据只能由客户端流向服务端。服务端会收到这个对象的完整数据，**但在服务端对对象进行修改不会对客户端传递进来的对象造成影响。**
- `out`：表示数据只能由服务端传递到客户端。服务端会接受到这个对象的空对象，**但在服务端接收到的空对象有任何修改之后客户端会同步发生变化。**
- `inout`：表示数据可以在服务端和客户端之间双向流通。服务端会收到这个对象的完整数据，**且客户端会同步服务端对该对象的任何改动。**

#### 3.关键类和方法

> 添加完AIDL文件后，会自动帮我们生成对应的Java文件。本质上是为我们提供了一种快速实现Binder的工具而已。

1. 定义一个AIDL文件

   ```java
   //Book.aidl
   //书的实体类
   parcelable Book;
   
   //IOnNewBookArrivedListener.aidl
   //监听新增书本事件
   import com.example.wxy.ipc.Book;
   interface IOnNewBookArrivedListener {
       void onNewBookArrived(in Book newBook);
   }
   
   //IBookManager.aidl
   //书籍管理类
   import com.example.wxy.ipc.Book;
   import com.example.wxy.ipc.IOnNewBookArrivedListener;
   interface IBookManager {
       //获取书本总数
       List<Book> getBookList();
       //插入新书
       Book addBook(in Book book);
       //注册监听
       void registerListener(IOnNewBookArrivedListener listener);
       //解注册监听
       void unregisterListener(IOnNewBookArrivedListener listener);
   }
   ```

   根据上述代码发现，aidl文件中引用到的AIDL接口或者Model对象，无论是否在同一个Package目录下，都必须**显示引用**。

2. AIDL文件定义完成后，会自动生成对应的Java文件，里面自动完成了Binder的逻辑。接下来进行结构分析

   `IBookManage` 主要声明了Client可以调用的Server方法

   ```java
   public interface IBookManager extends IInterafce{
     private static final java.lang.String DESCRIPTOR = "com.example.wxy.ipc.IBookManager";
     
     public java.util.List<com.example.wxy.ipc.Book> getBookList() throws android.os.RemoteException;
     public com.example.wxy.ipc.Book addBook(com.example.wxy.ipc.Book book) throws android.os.RemoteException;
     public void registerListener(com.example.wxy.ipc.IOnNewBookArrivedListener listener) throws android.os.RemoteException;
     public void unregisterListener(com.example.wxy.ipc.IOnNewBookArrivedListener listener) throws android.os.RemoteException;
     
     static final int TRANSACTION_getBookList = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
     static final int TRANSACTION_addBook = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);
     static final int TRANSACTION_registerListener = (android.os.IBinder.FIRST_CALL_TRANSACTION + 2);
     static final int TRANSACTION_unregisterListener = (android.os.IBinder.FIRST_CALL_TRANSACTION + 3);
   }
   ```

   `Iinterface`代表的是Server进程需要具备什么功能，对应的就是 `Client`进程可以调用的方法

   `IBookManager.Stub` 实现一个跨进程调用对象`Stub`。`Stub`继承自`Binder`，说明它是一个`Server进程`的Binder本地对象。需要实现`Server进程`提供的能力。

   ```java
   public static abstract class Stub extends android.os.Binder implements com.example.wxy.ipc.IBookManager {
     public Stub() {
        this.attachInterface(this, DESCRIPTOR);
     }
     
      //返回当前Binder对象
      // IBinder 这个代表了一种跨进程通信的能力。只要实现了这个接口，这个对象就可以跨进程传输。Client和Server进程都要实现该接口。
      @Override
      public android.os.IBinder asBinder() {
               return this;
      }  
    
   }
   ```

   关键方法: 

   1. `asInterface()` 通常用在Client `bindService()`成功后即在`onServiceConnected()`中调用该方法，可以把返回的IBinder对象转换为具体的`IIntergace`接口，就可以直接调用`Server`提供的对用方法。

      ```java
      public static com.example.wxy.ipc.IBookManager asInterface(android.os.IBinder obj) {
                  if ((obj == null)) {
                      return null;
                  }
                  android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
                  if (((iin != null) && (iin instanceof com.example.wxy.ipc.IBookManager))) {
                      return ((com.example.wxy.ipc.IBookManager) iin);
                  }
                  return new com.example.wxy.ipc.IBookManager.Stub.Proxy(obj);
         }
      
      ```

      生成的代码中调用到了`queryLocalInterface()`去查找本地的Binder对象，

      - 如果找到了就证明`Client和Server`当前在统一进程内，直接就返回Binder对象。
      - 如果没找到意味`Client和Server`不在统一进程内，就会返回一个Binder代理对象，即`ProxyObject`。

      当`Client`端在创建与服务端之间的连接时，调用`bindService()`需要创建一个`ServiceConnection`对象作为入参。在对应方法的回调`onServiceConnected()`需要调用`asInterface()`获取到对应对象。

      ```java
      // Client端实现 对应Android中的Activity
          private ServiceConnection mConnection = new ServiceConnection() {
              @Override
              public void onServiceConnected(ComponentName name, IBinder service) {
                  //获取到对应的BookManager对象
                  mBookManager = IBookManager.Stub.asInterface(service);
                  try {
                      List<Book> list = mBookManager.getBookList();
                      mBookManager.registerListener(onNewBookArrivedListener);
                  } catch (RemoteException e) {
                      e.printStackTrace();
                  }
              }
      
              @Override
              public void onServiceDisconnected(ComponentName name) {
                  Log.e("Client", "绑定失败");
              }
          };
      ```

   2. `onTransact()` 运行在服务器端的Binder线程池中，客户端发起跨进程请求时，远程请求会通过系统底层封装后交由此方法处理。参数介绍：

      - `code`：可以确定客户端所请求的方法是哪个
      - `data`：取出目标方法所需参数
      - `reply`：里面填写请求的返回值
      - `flags`：设置进行IPC的模式，0双向流通 1单向流通 **AIDL生成的.java文件均设置0

      ```java
      @Override
         public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException {  
            switch (code) {
                      case INTERFACE_TRANSACTION: {
                          reply.writeString(descriptor);
                          return true;
                      }
                      case TRANSACTION_getBookList: {
                          data.enforceInterface(descriptor);
                          java.util.List<com.example.wxy.ipc.Book> _result = this.getBookList();
                          reply.writeNoException();
                          reply.writeTypedList(_result);
                          return true;
                      }
                      case TRANSACTION_addBook: {
                          data.enforceInterface(descriptor);
                          com.example.wxy.ipc.Book _arg0;
                          if ((0 != data.readInt())) {
                              _arg0 = com.example.wxy.ipc.Book.CREATOR.createFromParcel(data);
                          } else {
                              _arg0 = null;
                          }
                          //实际内部实现 就交由 Stub类的 子类实现
                          com.example.wxy.ipc.Book _result = this.addBook(_arg0);
                          reply.writeNoException();
                          if ((_result != null)) {
                              reply.writeInt(1);
                              _result.writeToParcel(reply, android.os.Parcelable.PARCELABLE_WRITE_RETURN_VALUE);
                          } else {
                              reply.writeInt(0);
                          }
                          return true;
                      }
                ...
         }
      ```

      处理完由客户端调用的`transcat()`传递进来的`_data`，再将处理完的数据写入到`_reply`中。

      工作流程为：

      1. 获取由`transcat()`传入的数据，根据对应的`code`执行相应方法
      2. 执行方法后，解析对应传递过来的数据`_data`
      3. 将需要回传的数据写入`_reply`中，传回给客户端



     生成代码中 有调用到对应生成的`addBook()`等定义方法。这些方法的实际实现都要在`Server`端中实现。
    
      ```java
      // Server端  对应Android中的Service
      //需要注意并发处理
       private CopyOnWriteArrayList<Book> mBookList = new CopyOnWriteArrayList<>();
       private Binder mBinder = new IBookManager.Stub() {
              @Override
              public List<Book> getBookList() throws RemoteException {
                  return mBookList;
              }
      
              @Override
              public Book addBook(Book book) throws RemoteException {
                  book.setName("new Name in");
                  //实现了对应的 addBook方法
                  mBookList.add(book);
                  return book;
              }
         
              @Override
              public void registerListener(IOnNewBookArrivedListener listener) throws RemoteException {
                  mListenList.register(listener);
              }
      
              @Override
              public void unregisterListener(IOnNewBookArrivedListener listener) throws RemoteException {
                  mListenList.unregister(listener);
              }
          };
      ```



   `IBookManager.Stub.Proxy` 它并没有继承自Binder，而是包含了一个IBinder对象，这个对象其实是BinderProxy，说明它是Server在Client中的本地代理对象(`ProxyObject`)。这个类运行在`Client`，`Client`调用这个类来调用服务端的代码(涉及到了**代理模式**)

   ```java
    private static class Proxy implements com.example.wxy.ipc.IBookManager {
               private android.os.IBinder mRemote;
   
               Proxy(android.os.IBinder remote) {
                   mRemote = remote;
               }
   
               @Override
               public android.os.IBinder asBinder() {
                   return mRemote;
               }
   
               public java.lang.String getInterfaceDescriptor() {
                   return DESCRIPTOR;
               }
   
               /**
                * Demonstrates some basic types that you can use as parameters
                * and return values in AIDL.
                */
               @Override
               public java.util.List<com.example.wxy.ipc.Book> getBookList() throws android.os.RemoteException {
                   android.os.Parcel _data = android.os.Parcel.obtain();
                   android.os.Parcel _reply = android.os.Parcel.obtain();
                   java.util.List<com.example.wxy.ipc.Book> _result;
                   try {
                       _data.writeInterfaceToken(DESCRIPTOR);
                       mRemote.transact(Stub.TRANSACTION_getBookList, _data, _reply, 0);
                       _reply.readException();
                       _result = _reply.createTypedArrayList(com.example.wxy.ipc.Book.CREATOR);
                   } finally {
                       _reply.recycle();
                       _data.recycle();
                   }
                   return _result;
               }
   
               @Override
               public com.example.wxy.ipc.Book addBookIn(com.example.wxy.ipc.Book book) throws android.os.RemoteException {
                   android.os.Parcel _data = android.os.Parcel.obtain();
                   android.os.Parcel _reply = android.os.Parcel.obtain();
                   com.example.wxy.ipc.Book _result;
                   try {
                       _data.writeInterfaceToken(DESCRIPTOR);
                       if ((book != null)) {
                           _data.writeInt(1);
                           book.writeToParcel(_data, 0);
                       } else {
                           _data.writeInt(0);
                       }
                       mRemote.transact(Stub.TRANSACTION_addBookIn, _data, _reply, 0);
                       _reply.readException();
                       if ((0 != _reply.readInt())) {
                           _result = com.example.wxy.ipc.Book.CREATOR.createFromParcel(_reply);
                       } else {
                           _result = null;
                       }
                   } finally {
                       _reply.recycle();
                       _data.recycle();
                   }
                   return _result;
               }
      ...
        
    }
   ```

   分析上述生成的代码：

   - `_data _reply`：`_data`存储传参的数据，`_reply`存储方法的返回值数据
   - `transcat(int code, @NonNull Parcel data, @Nullable Parcel reply, int flags)`：客户端和服务端通信的核心方法。调用后会挂起当前线程，等候服务端执行任务完成通知并接受返回的`_reply`数据。
     - `code`：分配的方法ID是自动生成的

   工作流程为：

   1. 生成`_data` 和` _reply`数据，在`_data`中存入客户端数据
   2. 调用`transcat()`传递数据至服务端，并调用服务端中`onTranscat()`的指定方法
   3. 接收`_reply`数据，取出服务端返回的数据使用

结构拆分明确后，可以大概的理解内部的工作机制。



![Binder工作机制](/images/Binder-workflow.png)

- **Client调用远程Binder代理对象，Client线程挂起，等待Server响应数据**

  客户端要访问Binder的远程服务，就要获取远程服务的Binder对象在Binder驱动中的`mRemote`引用，获取到引用后既可以调用相关方法。

- **Binder代理对象将请求发送给`Binder驱动`**

  在服务端成功Binder对象后，Binder驱动会创建一个`mRemote`对象，客户端可以借助它调用`transcat()`向服务端发送消息

- **`Binder驱动`将请求派发给Server端**

  在Server端创建好一个Binder对象后，内部就会开启一个线程用于接收Binder驱动发送的消息，收到消息后就会执行`onTransact()`,然后按照参数执行不同的服务端代码。

- **唤醒Client线程，返回结果**

  `onTranscat()`处理完成后，将结果写入`_reply`中并返回至`Binder驱动`，唤醒被挂起的Client线程。

#### 4.可能产生的问题

1. 可能会产生ANR

   由于客户端在调用远程服务方法时，客户端线程会被挂起，如果服务端的方法执行比较耗时，就会导致客户端ANR，或者在`onServiceConnected`和`onServiceDisconnected`中调用了服务端的耗时方法也会导致ANR。

   当服务端调用客户端的listener方法时，该方法会运行在客户端的`binder线程池中`，若调用了耗时方法，也会导致ANR。

   **客户端调用放在非UI线程**

2. AIDL解注册失败

   > 服务端无法找到注册时使用的listener而导致解注册失败。**因为Binder客户端会把传递过来的对象重新转化并生成一个新的对象，而且对象是不能跨进程传输的，对象跨进程传输的本质就是序列化和反序列化的过程。**

   这时需要用到`RemoteCallBackList`，是系统专门提供用于删除跨进程的listener的接口，而且内部实现了线程同步的功能**(内部使用了`synchronized`)**。使用注意事项:**`beginBroadcast`和`finishBroadcast`必须要配对使用。**

3. 性能损耗较大

   > 客户端频繁调用服务端方法，就需要实现一个**观察者模式**，当客户端的数据发生变化时再去通知服务端操作，减少频繁查询。

#### 5.拓展

1. 权限验证

   > 默认情况下，远程服务所有人都可以进行连接并调用，所以应该需要加入权限验证系统来保证安全。

   ```xml
   //在AndroidManifest.xml中定义该权限    
   <permission android:name="com.example.wxy.permission.checkBook"
                   android:protectionLevel="normal"/>
   //如果注册了该权限，则可以绑定成功 否则失败
   <uses-permission android:name="com.example.wxy.permission.checkBook"/>
   
   
   <service
       android:name=".service.AIDLService"
       android:exported="true">
           <intent-filter>
               <action android:name="com.example.wxy"/>
               <category android:name="android.intent.category.DEFAULT"/>
           </intent-filter>
   </service>
   ```

## 8.Binder连接池

> 首先回顾一下AIDL的使用方式：①创建一个Service和AIDL接口②创建一个类继承自AIDL接口中的Stub类并实现Stub中的抽象方法③在Service的onBind中返回这个类的对象④客户端绑定Service后就可以直接访问服务端的方法。
>
> 当业务需求越来越多时，上述的创建方式就会产生很多Service类，导致系统资源耗费颜值、应用过度重量级的问题。所以产生了`Binder连接池`的概念。

> 主要作用为 **将每个业务模块的Binder请求统一转发到远程Service上去执行，从而避免重复创建Service**。   

工作原理：

{% fullimage /images/BinderPool.png,BinderPool工作原理, BinderPool工作原理%}

每个业务模块创建自己的AIDL接口并实现，然后向服务端传递自己的**唯一标识(BinderCode)及对应的Binder对象**。服务端只要一个Service，然后实现`queryBinder()`接口，根据唯一标识返回对应的Binder对象。

实现方式：

- 创建对应的AIDL文件并有具体实现
- 创建BinderPool.java以及IBinderPool.aidl文件
- 实现远程服务BinderPoolService，并在onBind()中返回实例化的BinderPool对象
- 实现BinderPool方法，并在`queryBinder()`中做好对应处理
- 客户端调用BinderPoolService



## 9.Binder跨进程传输大文件

Intent传递数据是有大小限制的，







## 参考链接

[一次Binder通信最多可以传输多大的数据](https://www.jianshu.com/p/ea4fc6aefaa8)

