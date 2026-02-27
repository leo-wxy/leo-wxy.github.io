---
title: Android-Binder分析
date: 2026-02-16 10:30:00
tags: Android
top: 11
typora-root-url: ../
---

<!--基于先前的学习内容，重新进行Binder理论知识的整理-->

## Linux传统的进程间通信原理

![Linux进程结构](/images/Linux-IPC-Basics.png)

### 进程隔离

> 保护系统中进程互不干扰。在操作系统中，进程之间数据是不互通的，相互之间无法访问数据，保证数据的安全星。

在`进程隔离`的条件下，需要通过`IPC(Inter Process Communication)机制`进行进程间的通信。

### 进程空间划分

> 操作系统的核心是**内核**，独立于普通的应用程序，可以访问受保护的内存空间以及底层的硬件设备。

为了使用户进程不能操作内核，保证内核的安全性。所以操作系统将虚拟空间划分为两部分：

- **内核空间**(一般占1GB)

  系统内核运行的空间

- **用户空间**(一般占3GB)

  用于用户程序执行的空间

**用户空间在不同进程之间不能共享，内核空间是各个进程之间共享的。**

### 系统调用

> 用户空间的权限低于内核空间，导致用户空间无法直接访问内核资源(例如文件操作、网络访问等)，就需要借助**系统调用**实现内核资源访问。

**系统调用**是用户空间访问内核的唯一方式，保证了所有资源访问都是在内核的控制下进行，避免用户程序对系统资源的越级访问，提升系统的安全和稳定性。

Linux采用两级保护机制：

- 0级供系统内核使用
- 3级供用户程序使用

当进程使用`系统调用`执行内核代码时，进程就进入了**内核态**，此时处理器处于`0级`；当进程执行自己的代码时，进程就进入**用户态**，此时处理器位于`3级`。

`系统调用`主要通过以下两个函数实现：

- `copy_from_user`：将数据从用户空间拷贝到内核空间
- `copy_to_user`：将数据从内核空间拷贝到用户空间



### 传统IPC功能实现

![Linux-IPC](/images/Linux-IPC.png)

1. 发送进程通过`系统调用 copy_from_user`把自己的`内存缓存区(发送进程)`的数据拷贝到`内核缓存区`中
2. 内核程序通过`系统调用 copy_to_user`把内核缓存区的数据拷贝到接收进程的`内存缓存区`中

传统IPC通信过程中暴露了两个明显的缺点：

1. **性能低下**，需要经历两次数据拷贝过程：`发送进程内存缓存区 -> 内核缓存区 -> 接收进程内存缓存区`
2. **空间、时间浪费**，接收方需要事先开辟一块内存空间准备接受发送方的数据，由于不能确定数据的大小。所以只能开辟一块较大的空间(`空间浪费`)或者先行获取发送数据的大小(`时间浪费`)。

### 传统Linux进程通信手段

- 管道
- 消息队列
- **共享内存**：无需复制，共享缓冲区直接附加到进程的虚拟地址，速度快。*但是无法解决进程间同步问题*
- **套接字(Socket)**：接口通用，但是传输效率低，主要用于不同机器间的通信
- **信号量(semaphore)**：作为一种锁机制，防止某进程正在访问共享资源时，其他进程也在访问该资源。
- 信号



## Binder基本原理



### 动态内核可加载模块

`模块`是具有独立功能的程序，可以被单独编译但是无法独立运行。利用`动态内核可加载模块`机制，动态的添加一个内核模块到内核空间内，用户进程就可以通过这个模块实现通信。

**在Android系统中，加载进内核空间的模块就是`Binder驱动`。**



### 内存映射-mmap

`Binder驱动`添加完毕后，就需要开始进程间通信。接下来就需要用到`mmap()——内存映射`。

`mmap`用于文件或者其他对象映射进内存，通常用在有物理介质的文件系统上的，比如磁盘之类。

在Binder中，通过`mmap`将用户空间内的一块内存区域映射进内存空间，当映射关系建立完毕后，任何一方对内存区域的改动都会被反映到另一方。



Binder建立了一个虚拟设备`/dev/binder`，然后在内核空间创建了一块数据接收的缓冲区，这块`数据接收缓冲区`与`内核缓冲区`和`接收数据的用户空间`建立映射，减少了一次*数据拷贝*。



### 实现原理



![Binder流程](/images/Binder-IPC.png)

1. `Binder驱动`在`内核空间`建立一个`数据接收缓存区`
2. 接着在`内核空间`开辟一块`内核缓存区`，建立起`内核缓存区和内核数据接收缓存区`之间的映射关系，以及`数据接收缓存区和用户空间`的映射关系
3. 发送方进程通过`系统调用copy_from_user`将数据复制到`内核缓存区`，由于各自之间存在映射，等价于`直接把数据传递到了接收进程`。

### Binder优势

- 性能

  > Linux上的通信方式例如`管道、Socket`都需要复制两次数据。而Binder只要一次
  >
  > 拷贝两次过程：发送方数据通过`系统调用copy_from_user`拷贝到`内核缓存区`，再由`内核缓存区`调用`系统调用copy_to_user`拷贝至接收方。
  >
  > Binder执行过程：在内核中建立`数据接收缓存区`，发送方数据通过`系统调用copy_from_user`拷贝到`内核缓存区`，此时`内核缓存区`已与`数据接收缓存区`和`接收进程数据缓存区`建立映射，相当于发送方的数据直接到接收方。

- 安全性

  > 传统的Linux通信是不包含通信双方的身份验证，Binder自带身份验证，提高了安全性。
  >
  > [Binder权限验证](#Binder权限验证)

- 稳定性

  > Binder基于CS架构，Client的需求都交与Server去完成，职责明确。



## Binder通信模型

![Binder通信模型](/images/Binder通信模型.png)

![Binder架构图](/images/IPC-Binder.jpg)

### Client

> 客户端进程

`Client`负责向`ServiceManager`查询所需Service，并且获得一个`Binder代理对象`，再通过`Binder代理对象`向`Server`发起请求

### Server

> 服务端进程

`Server`进程启动时，会通过`Binder驱动`注册自身的服务到`Service Manager`中，并且启动一个`Binder线程池`，用来接收`Client`的请求。

### Service Manager

> 服务的管理者，指代的是`Native`层的`ServiceManager`，是整个Binder通信机制的大管家，也是Android进程间通信的守护进程。

主要有以下功能

- `Service`通过`Binder驱动`向`ServiceManager`注册Binder，表示可以对外提供服务。
- `Client`通过`Binder驱动`从`ServiceManager`获取Binder的引用。

`Service Manager`就是一个进程，内部维护了一张表，维护了`名字+Binder实体的引用`。

### Binder完整定义

在不同语境下，`Binder`有不同含义：

- 机制层：Android进程间通信机制。
- Server层：服务端提供能力的本地Binder实体。
- Client层：服务端实体在客户端的代理引用（由驱动转换得到）。
- 传输层：可跨进程传输的对象能力抽象。

#### 启动

`Service Manager`进程是在开机时启动的

1. init进程解析`servicemanager.rc`之后，找到对应可执行程序`/system/bin/servicemanager`
2. 继续执行到`service_manager.c`的`main()`

```c
//frameworks/native/cmds/servicemanager/service_manager.c
int main(int argc, char** argv)
{
    struct binder_state *bs;
    union selinux_callback cb;
    char *driver;

    if (argc > 1) {
        driver = argv[1];
    } else {
        driver = "/dev/binder";
    }

    bs = binder_open(driver, 128*1024);

    if (binder_become_context_manager(bs)) {
        ALOGE("cannot become context manager (%s)\n", strerror(errno));
        return -1;
    }
  
#ifdef VENDORSERVICEMANAGER
    sehandle = selinux_android_vendor_service_context_handle();
#else
    sehandle = selinux_android_service_context_handle();
#endif
    selinux_status_open(true);

    binder_loop(bs, svcmgr_handler);

    return 0;
}
```

##### binder_open()

> 打开设备驱动，位置为`/dev/binder`

```c
//frameworks/native/cmds/servicemanager/binder.c
struct binder_state *binder_open(const char* driver, size_t mapsize)
{
    struct binder_state *bs;
    struct binder_version vers;

    bs = malloc(sizeof(*bs));
    if (!bs) {
        errno = ENOMEM;
        return NULL;
    }
   //打开Binder设备驱动
    bs->fd = open(driver, O_RDWR | O_CLOEXEC);

    bs->mapsize = mapsize;
  //进行内存映射
    bs->mapped = mmap(NULL, mapsize, PROT_READ, MAP_PRIVATE, bs->fd, 0);

    return bs;

fail_map:
    close(bs->fd);
fail_open:
    free(bs);
    return NULL;
}
```

`binder_open()`总共执行了三步：

1. `open()`打开`/dev/binder`设备节点，最终调用到内核中的`binder驱动`，同样执行到`binder_open()`，创建了`binder_proc`，再放入`binder_procs`中
2. 调用`mmap()`进行内存映射，映射大小为`128k`，主要在`binder驱动`创建`Binder_buffer`对象
3. 返回`binder_state`，记录着如下变量：
   - fd：打开了`/dev/binder`的文件描述符
   - mapsize：内存映射大小
   - mapped：内存映射地址

##### binder_become_context_manager()

> 注册成为大管家。

```c
int binder_become_context_manager(struct binder_state *bs)
{
    return ioctl(bs->fd, BINDER_SET_CONTEXT_MGR, 0);
}
```

通过`ioctl`向`binder驱动`发出`BINDER_SET_CONTEXT_MGR`请求，成为上下文的管理者。

**向Binder驱动注册，它的handle句柄固定为0.**这个binder的引用固定为0。

一个Server若要向`Service Manager`注册自己的Binder就必需通过0这个引用号和`Service Manager`的Binder通信。*所有需要注册自己的Server对于Service Manager来说都是Client*

##### binder_loop()

> 不断循环，等待客户请求

```c
//frameworks/native/cmds/servicemanager/binder.c
void binder_loop(struct binder_state *bs, binder_handler func)
{
    int res;
    struct binder_write_read bwr;
    uint32_t readbuf[32];

    bwr.write_size = 0;
    bwr.write_consumed = 0;
    bwr.write_buffer = 0;

    readbuf[0] = BC_ENTER_LOOPER;
  //向Binder驱动发送 BC_ENTER_LOOPER 协议，让Service Manager进入循环状态
    binder_write(bs, readbuf, sizeof(uint32_t));

    for (;;) {
        bwr.read_size = sizeof(readbuf);
        bwr.read_consumed = 0;
       //读取Binder的数据 就会写到 readbuf中，此时就可以进行解析操作
        bwr.read_buffer = (uintptr_t) readbuf;
       //使Service Manager进入内核态
        res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr);
       //等待解析Client的请，收到消息切换用户态
        res = binder_parse(bs, 0, (uintptr_t) readbuf, bwr.read_consumed, func);
    }
}
```

`Service Manager`通过`binder_write()`向`binder驱动`发送`BC_ENTER_LOOPER`协议，然后`Service Manager`进入循环状态。开启for循环，接着通过`ioctl()`发送`BINDER_WRITE_READ`请求到`Binder驱动`，使`Service Manager`进入`内核态`，开始等待`Client`发起请求。未收到请求时，处于等待状态。收到请求后调用`binder_parse()`解析接收到的请求并切换到`用户态`。

`BINDER_WRITE_READ`：向`Binder驱动`进行`读取或写入操作`，参数分为两部分`write_size`和`read_size`

- `write_size`不为空，取出`write_buffer`的数据写入到`Binder`里。
- `read_size`不为空，`Binder`写数据到`read_buffer`。`read_buffer`没有数据，就处于等待状态。

`binder_write()`

```c
int binder_write(struct binder_state *bs, void *data, size_t len)
{
    struct binder_write_read bwr;
    int res;

    bwr.write_size = len;
    bwr.write_consumed = 0;
    bwr.write_buffer = (uintptr_t) data;
    bwr.read_size = 0;
    bwr.read_consumed = 0;
    bwr.read_buffer = 0;
    res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr);
    if (res < 0) {
        fprintf(stderr,"binder_write: ioctl failed (%s)\n",
                strerror(errno));
    }
    return res;
}
```

`binder_write()`实质调用`ioctl()`，负责的是向`Binder驱动`写入数据。除了`BC_ENTER_LOOP`，还有其他类型的命令(`以BC_开头`)

`BC`可以**理解为向Binder写入数据**。

```c
enum binder_driver_command_protocol {
  BC_TRANSACTION = _IOW('c', 0, struct binder_transaction_data), //Client向Server 发送请求数据，向Binder写入请求数据
  BC_REPLY = _IOW('c', 1, struct binder_transaction_data), //Server 向Client 返回数据，向Binder写入回复数据
  BC_ACQUIRE_RESULT = _IOW('c', 2, __s32),
  BC_FREE_BUFFER = _IOW('c', 3, binder_uintptr_t),//释放一块mmap映射的内存
  BC_INCREFS = _IOW('c', 4, __u32),
  BC_ACQUIRE = _IOW('c', 5, __u32),
  BC_RELEASE = _IOW('c', 6, __u32),
  BC_DECREFS = _IOW('c', 7, __u32),
  BC_INCREFS_DONE = _IOW('c', 8, struct binder_ptr_cookie),
  BC_ACQUIRE_DONE = _IOW('c', 9, struct binder_ptr_cookie),
  BC_ATTEMPT_ACQUIRE = _IOW('c', 10, struct binder_pri_desc),
  BC_REGISTER_LOOPER = _IO('c', 11),
  BC_ENTER_LOOPER = _IO('c', 12),
  BC_EXIT_LOOPER = _IO('c', 13),
  BC_REQUEST_DEATH_NOTIFICATION = _IOW('c', 14, struct binder_handle_cookie),
  BC_CLEAR_DEATH_NOTIFICATION = _IOW('c', 15, struct binder_handle_cookie),
  BC_DEAD_BINDER_DONE = _IOW('c', 16, binder_uintptr_t),
  BC_TRANSACTION_SG = _IOW('c', 17, struct binder_transaction_data_sg),
  BC_REPLY_SG = _IOW('c', 18, struct binder_transaction_data_sg),
};
```

其中和`linkToDeath`直接相关的是三条命令：

- `BC_REQUEST_DEATH_NOTIFICATION`：向驱动注册死亡通知。
- `BC_CLEAR_DEATH_NOTIFICATION`：取消死亡通知。
- `BC_DEAD_BINDER_DONE`：用户态处理完死亡回调后，回写完成确认。

`linkToDeath`在用户态是一次API调用，在驱动侧本质是“注册一条死亡监听关系”。



`binder_parse()`

```c
int binder_parse(struct binder_state *bs, struct binder_io *bio,
                 uintptr_t ptr, size_t size, binder_handler func)
{
    int r = 1;
    uintptr_t end = ptr + (uintptr_t) size;

    while (ptr < end) {
        switch(cmd) {
       ...
        case BR_TRANSACTION: {
          //当前是Binder驱动向 ServiceManager 发送请求数据，例如获取服务、注册服务
            struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
            if ((end - ptr) < sizeof(*txn)) {
                ALOGE("parse: txn too small!\n");
                return -1;
            }
            binder_dump_txn(txn);
            if (func) { //func 指的就是 ServiceManager初始化的时候 传进来的 svcmgr_handler 函数
                unsigned rdata[256/4];
                struct binder_io msg;
                struct binder_io reply;
                int res;

                bio_init(&reply, rdata, sizeof(rdata), 4);
                bio_init_from_txn(&msg, txn);
                res = func(bs, txn, &msg, &reply);
                if (txn->flags & TF_ONE_WAY) {
                    binder_free_buffer(bs, txn->data.ptr.buffer);
                } else {
                    binder_send_reply(bs, &reply, txn->data.ptr.buffer, res);//返回应答数据
                }
            }
            ptr += sizeof(*txn);
            break;
        }
        case BR_REPLY: {
          //当前是Binder驱动 向 ServiceManager发送 回复数据
            struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
            if ((end - ptr) < sizeof(*txn)) {
                ALOGE("parse: reply too small!\n");
                return -1;
            }
            binder_dump_txn(txn);
            if (bio) {
                bio_init_from_txn(bio, txn);
                bio = 0;
            } else {
                /* todo FREE BUFFER */
            }
            ptr += sizeof(*txn);
            r = 0;
            break;
        }
        case BR_DEAD_BINDER: {
            struct binder_death *death = (struct binder_death *)(uintptr_t) *(binder_uintptr_t *)ptr;
            ptr += sizeof(binder_uintptr_t);
            death->func(bs, death->ptr);
            break;
        }
        ...
    }

    return r;
}
```

`binder_parse()`负责解析`read_buffer`读取到的数据。

`binder_parse()`主要就是解析`BR_`开头的指令，上面重要的就是`BR_TRANSACTION`和`BR_REPLY`。除此之外还有其他的`BR_`指令

`BR`可以**理解为从Binder读取数据**。

```c
enum binder_driver_return_protocol {
  BR_ERROR = _IOR('r', 0, __s32),//发生内部错误
  BR_OK = _IO('r', 1), //操作完成
  BR_TRANSACTION = _IOR('r', 2, struct binder_transaction_data), //读取请求数据，从Binder读取请求数据 然后发送到Server
  BR_REPLY = _IOR('r', 3, struct binder_transaction_data), //读取回复数据，从Binder读取回复数据 然后发送到Client
  BR_ACQUIRE_RESULT = _IOR('r', 4, __s32),
  BR_DEAD_REPLY = _IO('r', 5), //对方进程或线程已死
  BR_TRANSACTION_COMPLETE = _IO('r', 6),
  BR_INCREFS = _IOR('r', 7, struct binder_ptr_cookie),
  BR_ACQUIRE = _IOR('r', 8, struct binder_ptr_cookie),
  BR_RELEASE = _IOR('r', 9, struct binder_ptr_cookie),
  BR_DECREFS = _IOR('r', 10, struct binder_ptr_cookie),
  BR_ATTEMPT_ACQUIRE = _IOR('r', 11, struct binder_pri_ptr_cookie),
  BR_NOOP = _IO('r', 12),
  BR_SPAWN_LOOPER = _IO('r', 13),
  BR_FINISHED = _IO('r', 14),
  BR_DEAD_BINDER = _IOR('r', 15, binder_uintptr_t),//向持有Binder引用的进程通知Binder已死
  BR_CLEAR_DEATH_NOTIFICATION_DONE = _IOR('r', 16, binder_uintptr_t),
  BR_FAILED_REPLY = _IO('r', 17),
};
```

`BR_DEAD_BINDER`就是`linkToDeath`对应的关键返回信号：

- 当远端Binder对象/进程失效时，驱动把`BR_DEAD_BINDER`投递给持有该引用的进程。
- 用户态解析到该命令后，会执行已注册的死亡回调（`DeathRecipient.binderDied()`）。

简化链路：

```text
linkToDeath()
  -> BC_REQUEST_DEATH_NOTIFICATION
remote binder dies
  -> BR_DEAD_BINDER
  -> binderDied()
  -> BC_DEAD_BINDER_DONE
```



其中`BR_TRANSACTION`需要进行特殊处理，实现`对外提供服务`功能。例如提供`获取服务、注册服务功能`。*后面会简单的讲解*

当`binder_parse()`收到`BR_TRANSACTION`之后，就会执行到`svcmgr_handler()`

```c
//frameworks/native/cmds/servicemanager/service_manager.c
int svcmgr_handler(struct binder_state *bs,
                   struct binder_transaction_data *txn,
                   struct binder_io *msg,
                   struct binder_io *reply)
{ 
    struct svcinfo *si;//记录着 服务信息
    uint16_t *s;
    size_t len;
    uint32_t handle;
    uint32_t strict_policy;  
  ...
    switch(txn->code) {
    case SVC_MGR_GET_SERVICE:
    case SVC_MGR_CHECK_SERVICE://获取服务 一般是Client发起获取服务请求
        s = bio_get_string16(msg, &len);//服务名
        if (s == NULL) {
            return -1;
        }
        handle = do_find_service(s, len, txn->sender_euid, txn->sender_pid);//获取对应服务
        if (!handle)
            break;
        bio_put_ref(reply, handle);
        return 0;

    case SVC_MGR_ADD_SERVICE://添加服务 一般是Server发起注册服务请求
        s = bio_get_string16(msg, &len);
        if (s == NULL) {
            return -1;
        }
        handle = bio_get_ref(msg);
        allow_isolated = bio_get_uint32(msg) ? 1 : 0;
        dumpsys_priority = bio_get_uint32(msg);
        if (do_add_service(bs, s, len, handle, txn->sender_euid, allow_isolated, dumpsys_priority,
                           txn->sender_pid))//注册服务
            return -1;
        break;

    case SVC_MGR_LIST_SERVICES: { //列举所有注册的服务
        uint32_t n = bio_get_uint32(msg);
        uint32_t req_dumpsys_priority = bio_get_uint32(msg);

        if (!svc_can_list(txn->sender_pid, txn->sender_euid)) {
            ALOGE("list_service() uid=%d - PERMISSION DENIED\n",
                    txn->sender_euid);
            return -1;
        }
        si = svclist;
        // walk through the list of services n times skipping services that
        // do not support the requested priority
        while (si) {
            if (si->dumpsys_priority & req_dumpsys_priority) {
                if (n == 0) break;
                n--;
            }
            si = si->next;
        }
        if (si) {
            bio_put_string16(reply, si->name);
            return 0;
        }
        return -1;
    }
    default:
        ALOGE("unknown code %d\n", txn->code);
        return -1;
    }

    bio_put_uint32(reply, 0);
    return 0;
}
```

`svcmgr_handler()`主要提供服务相关的功能，根据不同的`code`有对应的功能：

- `SVC_MGR_GET_SERVICE`，`SVC_MGR_CHECK_SERVICE`：获取服务
- `SVC_MGR_ADD_SERVICE`：注册服务
- `SVC_MGR_LIST_SERVICES`：列举所有服务

`Service Manager`存储的是一个`svclist`的一个链表结构，里面存储的对象为`svcinfo`

```c
struct svcinfo
{
    struct svcinfo *next; //下一个注册服务
    uint32_t handle; //服务的 句柄
    struct binder_death death;
    int allow_isolated;
    uint32_t dumpsys_priority;
    size_t len;
    uint16_t name[0]; //服务名
};
```

![ServiceManager启动过程](/images/5-2-2.start_service_manager.jpg)

##### 总结

`ServiceManager`启动过程主要执行以下几步：

1. `binder_open()`：打开驱动，`/dev/binder`
2. `binder_become_context_manager()`：成为管家，并准备进入循环
3. `binder_loop()`：开启循环，等待新消息并处理

![ServiceManager初始化](/images/ServiceManager初始化.png)



#### 获取Service Manager代理对象

```cpp
//frameworks/native/libs/binder/IServiceManager.cpp
[[clang::no_destroy]] static sp<IServiceManager> gDefaultServiceManager;

sp<IServiceManager> defaultServiceManager()
{
    if (gDefaultServiceManager != NULL) return gDefaultServiceManager;

    {
        AutoMutex _l(gDefaultServiceManagerLock);
        while (gDefaultServiceManager == NULL) {
            gDefaultServiceManager = interface_cast<IServiceManager>(
                ProcessState::self()->getContextObject(NULL));
            if (gDefaultServiceManager == NULL)
                sleep(1);
        }
    }

    return gDefaultServiceManager;
}

```

`gDefaultServiceManager`的创建过程主要分为以下几步：

##### `ProcessState::self()`

> 用于创建`ProcessState`对象，每个进程有且只有一个

```cpp
//frameworks/native/libs/binder/ProcessState.cpp
#define DEFAULT_BINDER_VM_SIZE ((1 * 1024 * 1024) - sysconf(_SC_PAGE_SIZE) * 2)
#define DEFAULT_MAX_BINDER_THREADS 15

sp<ProcessState> ProcessState::self()
{
    Mutex::Autolock _l(gProcessMutex);
    if (gProcess != NULL) {//采用单例模式，保证只有一个
        return gProcess;
    }
    gProcess = new ProcessState(DEFAULT_BINDER_VM_SIZE);//实例化ProcessState
    return gProcess;
}

ProcessState::ProcessState(const char *driver)
    : mDriverName(String8(driver))
    , mDriverFD(open_driver(driver)) //1⃣️ 打开binder驱动
    , mVMStart(MAP_FAILED)
    , mThreadCountLock(PTHREAD_MUTEX_INITIALIZER)
    , mThreadCountDecrement(PTHREAD_COND_INITIALIZER)
    , mExecutingThreadsCount(0)
    , mMaxThreads(DEFAULT_MAX_BINDER_THREADS)
    , mStarvationStartTimeMs(0)
    , mThreadPoolStarted(false)
    , mThreadPoolSeq(1)
    , mCallRestriction(CallRestriction::NONE)
{

    if (mDriverFD >= 0) {
        //3⃣️ 通过mmap 在 binder驱动映射一块内存，用来接收事务
        mVMStart = mmap(nullptr, BINDER_VM_SIZE, PROT_READ, MAP_PRIVATE | MAP_NORESERVE, mDriverFD, 0);
        if (mVMStart == MAP_FAILED) {
            // *sigh*
            ALOGE("Using %s failed: unable to mmap transaction memory.\n", mDriverName.c_str());
            close(mDriverFD);
            mDriverFD = -1;
            mDriverName.clear();
        }
    }
}

static int open_driver(const char *driver)
{
    int fd = open(driver, O_RDWR | O_CLOEXEC);
    if (fd >= 0) {
        int vers = 0;
      //获取Binder驱动版本
        status_t result = ioctl(fd, BINDER_VERSION, &vers);
        if (result == -1) {
            ALOGE("Binder ioctl to obtain version failed: %s", strerror(errno));
            close(fd);
            fd = -1;
        }

        size_t maxThreads = DEFAULT_MAX_BINDER_THREADS;
      //2⃣️ 通过 ioctl为 binder驱动设置 最大线程数，默认为15
        result = ioctl(fd, BINDER_SET_MAX_THREADS, &maxThreads);
        if (result == -1) {
            ALOGE("Binder ioctl to set max threads failed: %s", strerror(errno));
        }
    } else {
        ALOGW("Opening '%s' failed: %s\n", driver, strerror(errno));
    }
    return fd;
}
```

`ProcessState`可以保证每个进程打开`binder设备`一次，通过`mDriverFd`记录`binder驱动`的fd，可以用于后续访问Binder设备。

`ProcessState`的初始化过程主要执行了以下几步：

1. 1⃣️`open_driver()`：打开`binder驱动`设备，并且验证binder驱动版本是否一致。
2. 2⃣️`ioctl()`：为`binder驱动`设置最大线程数，默认为`15`。加上主binder线程，所以最多为`16`个。
3. 3⃣️`mmap()`：在`binder驱动`中分配一块`1016KB`大小的空间，用于处理事务。

##### `getContextObject()`

> 主要为了获取`BpBinder对象`

```cpp
sp<IBinder> ProcessState::getContextObject(const sp<IBinder>& /*caller*/)
{
  //打开handle 为 0 的IBinder对象
    sp<IBinder> context = getStrongProxyForHandle(0);

    return context;
}
```

获取`handle==0`的IBinder对象，实际就是`ServiceManager`的`BpBinder`对象。

```cpp
sp<IBinder> ProcessState::getStrongProxyForHandle(int32_t handle)
{
    sp<IBinder> result;

    AutoMutex _l(mLock);
   //根据 handle 查找对应的 handle_entry
    handle_entry* e = lookupHandleLocked(handle);

    if (e != nullptr) {
        IBinder* b = e->binder;
        if (b == nullptr || !e->refs->attemptIncWeak(this)) {
            if (handle == 0) {

                IPCThreadState* ipc = IPCThreadState::self();

                CallRestriction originalCallRestriction = ipc->getCallRestriction();
                ipc->setCallRestriction(CallRestriction::NONE);

                Parcel data;
              //验证binder是否就绪
                status_t status = ipc->transact(
                        0, IBinder::PING_TRANSACTION, data, nullptr, 0);

                ipc->setCallRestriction(originalCallRestriction);

                if (status == DEAD_OBJECT)
                   return nullptr;
            }
           //handle值对应的 IBinder不存在或无效时，新建一个 BpBinder对象
            b = BpBinder::create(handle);
            e->binder = b;
            if (b) e->refs = b->getWeakRefs();
            result = b;
        } else {
            result.force_set(b);
            e->refs->decWeak(this);
        }
    }

    return result;
}

```

`getContextObj()`主要执行了以下几步：

1. `getStrongProxyforHandle()`：获取`handle==0`的IBinder对象
2. `IPCThreadState::self()->transact()`：向`Binder驱动`传递对象，判断`Binder驱动`是否就绪
3. `BpBinder::create()`：创建`ServiceManager`的`BpBinder`对象

##### `interface_cast()`

> 创建BpServiceManager对象

```c
// IInterface.h
inline sp<INTERFACE> interface_cast(const sp<IBinder>& obj)
{
    return INTERFACE::asInterface(obj);
  //等价于 IServiceManager::asInterface
}
```

`interface_cast()`是一个模板函数，经过操作后最后得到

```cpp
const android::String16 IServiceManager::descriptor(“android.os.IServiceManager”);

const android::String16& IServiceManager::getInterfaceDescriptor() const
{
     return IServiceManager::descriptor;
}

 android::sp<IServiceManager> IServiceManager::asInterface(const android::sp<android::IBinder>& obj)
{
       android::sp<IServiceManager> intr;
        if(obj != NULL) {
           intr = static_cast<IServiceManager *>(
               obj->queryLocalInterface(IServiceManager::descriptor).get());
           if (intr == NULL) {
               intr = new BpServiceManager(obj); //创建BpServiceManager对象
            }
        }
       return intr;
}
```

此时初始化`BpServiceManager`对象

```cpp
    explicit BpServiceManager(const sp<IBinder>& impl)
        : BpInterface<IServiceManager>(impl)
    {
    }

// IInterface.h
inline BpRefBase<IServiceManager>::BpInterface(const sp<IBinder>& remote)
    :BpRefBase(remote)
{    }

// Binder.cpp
BpRefBase::BpRefBase(const sp<IBinder>& o)
    : mRemote(o.get()), mRefs(NULL), mState(0)
{
    extendObjectLifetime(OBJECT_LIFETIME_WEAK);
    if (mRemote) {
        mRemote->incStrong(this);
        mRefs = mRemote->createWeak(this);
    }
}
```

`BpServiceManager`初始化过程中，依次调用`BpRefBase`，`BpRefBase`，`BpServiceManager`的构造函数，赋予BpRefBase的mRemote的值为BpBinder(0)。

最后可知**defaultServiceManager 等价于 new BpServiceManager(new BpBinder(0))**

##### 总结

![获取ServiceManager代理](/images/5-2-4-get_service_manager.jpg)

- open: 创建binder_proc
- BINDER_SET_MAX_THREADS: 设置proc->max_threads
- mmap: 创建创建binder_buffer

##### `javaObjectForIBinder()`

> 主要为了获取`BinderProxy`对象

```cpp
//frameworks/base/core/jni/android_util_Binder.cpp
//负责创建一个 BinderProxy对象
jobject javaObjectForIBinder(JNIEnv* env, const sp<IBinder>& val)
{

    BinderProxyNativeData* nativeData = new BinderProxyNativeData();
    nativeData->mOrgue = new DeathRecipientList;
    nativeData->mObject = val;

    jobject object = env->CallStaticObjectMethod(gBinderProxyOffsets.mClass,
            gBinderProxyOffsets.mGetInstance, (jlong) nativeData, (jlong) val.get());
    if (env->ExceptionCheck()) {
        // In the exception case, getInstance still took ownership of nativeData.
        return NULL;
    }
    BinderProxyNativeData* actualNativeData = getBPNativeData(env, object);
    if (actualNativeData == nativeData) {
        // Created a new Proxy
        uint32_t numProxies = gNumProxies.fetch_add(1, std::memory_order_relaxed);
        uint32_t numLastWarned = gProxiesWarned.load(std::memory_order_relaxed);
        if (numProxies >= numLastWarned + PROXY_WARN_INTERVAL) {
            // Multiple threads can get here, make sure only one of them gets to
            // update the warn counter.
            if (gProxiesWarned.compare_exchange_strong(numLastWarned,
                        numLastWarned + PROXY_WARN_INTERVAL, std::memory_order_relaxed)) {
                ALOGW("Unexpectedly many live BinderProxies: %d\n", numProxies);
            }
        }
    } else {
        delete nativeData;
    }

    return object;
}
```

执行完成后`BinderInternal.getContextObject()`得到`BinderProxy`

继续调用到`ServiceManagerNative.asInterface()`

```java
//frameworks/base/core/java/android/os/ServiceManagerNative.java
    public static IServiceManager asInterface(IBinder obj) {
        if (obj == null) {
            return null;
        }

        // ServiceManager is never local
        return new ServiceManagerProxy(obj);
    }
```

等价于最后生成的代理对象就是`ServiceManagerProxy`。

#### Service Manager 注册服务

> Service 向 Service Manager 注册服务

```java
//ServiceManager.java
    public static void addService(String name, IBinder service, boolean allowIsolated,
            int dumpPriority) {
        try {
            getIServiceManager().addService(name, service, allowIsolated, dumpPriority);
        } catch (RemoteException e) {
            Log.e(TAG, "error in addService", e);
        }
    }

    private static IServiceManager getIServiceManager() {
        if (sServiceManager != null) {
            return sServiceManager;
        }

        // Find the service manager
        sServiceManager = ServiceManagerNative
                .asInterface(Binder.allowBlocking(BinderInternal.getContextObject()));
        return sServiceManager;
    }
```

`sServiceManager`最后得到的就是上节中的`BpServiceManager`对象

```cpp
//frameworks/native/libs/binder/IServiceManager.cpp
virtual status_t addService(const String16& name, const sp<IBinder>& service,
                                bool allowIsolated, int dumpsysPriority) {
        Parcel data, reply;
        data.writeInterfaceToken(IServiceManager::getInterfaceDescriptor());
        data.writeString16(name);//服务的name
        data.writeStrongBinder(service);//具体 服务
        data.writeInt32(allowIsolated ? 1 : 0);
        data.writeInt32(dumpsysPriority);
  //remote 表示 BpBinder对象
        status_t err = remote()->transact(ADD_SERVICE_TRANSACTION, data, &reply);
        return err == NO_ERROR ? reply.readExceptionCode() : err;
    }
```

`addService()`具体就是向`Service Manager`注册服务，将相关数据封装到`Parcel`对象。

接下来通过`BpBinder`调用`transact()`传输数据

```cpp
//frameworks/native/libs/binder/BpBinder.cpp
status_t BpBinder::transact(
    uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
{
    // Once a binder has died, it will never come back to life.
    if (mAlive) {
        status_t status = IPCThreadState::self()->transact(
            mHandle, code, data, reply, flags);
        if (status == DEAD_OBJECT) mAlive = 0;
        return status;
    }

    return DEAD_OBJECT;
}
```

##### IPCThreadState->transact

> 初始化IPCThreadState之后，向`Binder驱动`发送数据

```cpp
//frameworks/native/libs/binder/IPCThreadState.cpp
IPCThreadState* IPCThreadState::self()
{
    if (gHaveTLS) {
restart:
        const pthread_key_t k = gTLS;
        IPCThreadState* st = (IPCThreadState*)pthread_getspecific(k);
        if (st) return st;
        return new IPCThreadState;//初始IPCThreadState
    }

    pthread_mutex_lock(&gTLSMutex);
    if (!gHaveTLS) {
        int key_create_value = pthread_key_create(&gTLS, threadDestructor);
        if (key_create_value != 0) {
            pthread_mutex_unlock(&gTLSMutex);
            ALOGW("IPCThreadState::self() unable to create TLS key, expect a crash: %s\n",
                    strerror(key_create_value));
            return NULL;
        }
        gHaveTLS = true;
    }
    pthread_mutex_unlock(&gTLSMutex);
    goto restart;
}

IPCThreadState::IPCThreadState()
    : mProcess(ProcessState::self()),
      mStrictModePolicy(0),
      mLastTransactionBinderFlags(0)
{
    pthread_setspecific(gTLS, this);
    clearCaller();
    mIn.setDataCapacity(256);
    mOut.setDataCapacity(256);
}

void IPCThreadState::clearCaller()
{
    mCallingPid = getpid(); //初始化PID
    mCallingUid = getuid(); //初始化UID
}
```

每个线程都有一个`IPCThreadState`，内部包含如下参数：

- `mIn`：接收来自Binder设备的数据
- `mOut`：存储发送Binder设备的数据
- `mProcess`：当前进程的`ProcessState`
- `mCallingPid`：当前进程的Pid
- `mCallingUid`：当前进程的Uid



接下来执行`transact()`传输数据

```cpp
status_t IPCThreadState::transact(int32_t handle,
                                  uint32_t code, const Parcel& data,
                                  Parcel* reply, uint32_t flags)
{
    status_t err;

    flags |= TF_ACCEPT_FDS;
   //传输数据
    err = writeTransactionData(BC_TRANSACTION, flags, handle, code, data, NULL);

    if ((flags & TF_ONE_WAY) == 0) {

        if (reply) {
          //等待响应
            err = waitForResponse(reply);
        } else {
          //直接返回null
            Parcel fakeReply;
            err = waitForResponse(&fakeReply);
        }
      
        IF_LOG_TRANSACTIONS() {
            TextOutput::Bundle _b(alog);
            alog << "BR_REPLY thr " << (void*)pthread_self() << " / hand "
                << handle << ": ";
            if (reply) alog << indent << *reply << dedent << endl;
            else alog << "(none requested)" << endl;
        }
    } else {
      //直接返回null
        err = waitForResponse(NULL, NULL);
    }

    return err;
}
```

`transact()`主要过程：

1. 执行`writeTransactionData()`向`Parcel`中的`mOut`写入数据

   写入的数据主要是`BC_TRANSACTION`协议以及`binder_transaction_data`数据。

2. 执行`waitForResponse()`循环执行，等待应答消息。

   ```cpp
   status_t IPCThreadState::waitForResponse(Parcel *reply, status_t *acquireResult)
   {
       int32_t cmd;
       int32_t err;
       while (1) {
           if ((err=talkWithDriver()) < NO_ERROR) break;
           ...
           if (mIn.dataAvail() == 0) continue;
   
           cmd = mIn.readInt32();
           switch (cmd) {
               case BR_TRANSACTION_COMPLETE:
               //如果是 oneway 的请求方式，直接结束即可
                   if (!reply && !acquireResult) goto finish;
                   break;
               case BR_DEAD_REPLY: ...
               case BR_FAILED_REPLY: ...
               case BR_ACQUIRE_RESULT: ...
               case BR_REPLY: ...
                 //完整的执行一次通信过程
                   goto finish;
   
               default:
                   err = executeCommand(cmd);
                   if (err != NO_ERROR) goto finish;
                   break;
           }
       }
       ...
       return err;
   }
   ```

   

   



##### IPCThreadState.talkWithDrive()

> 负责与 `Binder驱动`进行通信

```cpp
status_t IPCThreadState::talkWithDriver(bool doReceive)
{
    ...
    binder_write_read bwr;
    //当mDataSize <= mDataPos，则有数据可读
    const bool needRead = mIn.dataPosition() >= mIn.dataSize();
    const size_t outAvail = (!doReceive || needRead) ? mOut.dataSize() : 0;

    bwr.write_size = outAvail;
    bwr.write_buffer = (uintptr_t)mOut.data(); // mData地址

    if (doReceive && needRead) {
        //接收数据缓冲区信息的填充。如果以后收到数据，就直接填在mIn中。
        bwr.read_size = mIn.dataCapacity();
        bwr.read_buffer = (uintptr_t)mIn.data();
    } else {
        bwr.read_size = 0;
        bwr.read_buffer = 0;
    }
    //当读缓冲和写缓冲都为空，则直接返回
    if ((bwr.write_size == 0) && (bwr.read_size == 0)) return NO_ERROR;

    bwr.write_consumed = 0;
    bwr.read_consumed = 0;
    status_t err;
    do {
        //通过ioctl不停的读写操作，跟Binder Driver进行通信
        if (ioctl(mProcess->mDriverFD, BINDER_WRITE_READ, &bwr) >= 0)
            err = NO_ERROR;
        ...
    } while (err == -EINTR);
    ...
    return err;
}
```



##### binder_ioctl()

> 与`Binder驱动进行通信`

- binder_ioctl()过程解析ioctl参数BINDER_WRITE_READ，则调用binder_ioctl_write_read()方法；
- binder_ioctl_write_read()过程将用户空间binder_write_read结构体拷贝到内核空间, 写缓存中存在数据，则调用binder_thread_write()方法；
- binder_thread_write()过程解析到传输协议为BC_TRANSACTION，则调用binder_transaction()方法；
- binder_transaction()过程将用户空间binder_transaction_data结构体拷贝到内核空间，内核创建一个binder_transaction结构体，



![服务注册过程](/images/5-3-5-add_service.jpg)

##### binder_parse()

> 解析`Binder驱动`返回的数据

前面讲到`Service Manager`的启动时，就介绍到在`binder_loop()`中负责接收消息，收到消息后通过`binder_parse`进行解析。

收到的指令为``

```cpp
        case BR_TRANSACTION: {
            struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
            if ((end - ptr) < sizeof(*txn)) {
                ALOGE("parse: txn too small!\n");
                return -1;
            }
            binder_dump_txn(txn);
            if (func) {
                unsigned rdata[256/4];
                struct binder_io msg;
                struct binder_io reply;
                int res;

                bio_init(&reply, rdata, sizeof(rdata), 4);
                bio_init_from_txn(&msg, txn);
                res = func(bs, txn, &msg, &reply);
                if (txn->flags & TF_ONE_WAY) {
                    binder_free_buffer(bs, txn->data.ptr.buffer);
                } else {
                    binder_send_reply(bs, &reply, txn->data.ptr.buffer, res);
                }
            }
            ptr += sizeof(*txn);
            break;
        }
```



```cpp
int svcmgr_handler(struct binder_state *bs,
                   struct binder_transaction_data *txn,
                   struct binder_io *msg,
                   struct binder_io *reply)
{
  ...
        case SVC_MGR_ADD_SERVICE:
        s = bio_get_string16(msg, &len);
        if (s == NULL) {
            return -1;
        }
        handle = bio_get_ref(msg);
        allow_isolated = bio_get_uint32(msg) ? 1 : 0;
        dumpsys_priority = bio_get_uint32(msg);
        if (do_add_service(bs, s, len, handle, txn->sender_euid, allow_isolated, dumpsys_priority,
                           txn->sender_pid))
            return -1;
        break;

  
}
```

##### do_add_service()

> 向Service Manager添加服务

```cpp
int do_add_service(struct binder_state *bs, const uint16_t *s, size_t len, uint32_t handle,
                   uid_t uid, int allow_isolated, uint32_t dumpsys_priority, pid_t spid) {
    struct svcinfo *si;

    //ALOGI("add_service('%s',%x,%s) uid=%d\n", str8(s, len), handle,
    //        allow_isolated ? "allow_isolated" : "!allow_isolated", uid);

    if (!handle || (len == 0) || (len > 127))
        return -1;

    if (!svc_can_register(s, len, spid, uid)) {
        ALOGE("add_service('%s',%x) uid=%d - PERMISSION DENIED\n",
             str8(s, len), handle, uid);
        return -1;
    }

    si = find_svc(s, len);
    if (si) {
        if (si->handle) {
            ALOGE("add_service('%s',%x) uid=%d - ALREADY REGISTERED, OVERRIDE\n",
                 str8(s, len), handle, uid);
            svcinfo_death(bs, si);
        }
        si->handle = handle;
    } else {
        si = malloc(sizeof(*si) + (len + 1) * sizeof(uint16_t));
        if (!si) {
            ALOGE("add_service('%s',%x) uid=%d - OUT OF MEMORY\n",
                 str8(s, len), handle, uid);
            return -1;
        }
        si->handle = handle;
        si->len = len;
        memcpy(si->name, s, (len + 1) * sizeof(uint16_t));
        si->name[len] = '\0';
        si->death.func = (void*) svcinfo_death;
        si->death.ptr = si;
        si->allow_isolated = allow_isolated;
        si->dumpsys_priority = dumpsys_priority;
        si->next = svclist;//svcList保存服务
        svclist = si;
    }

    binder_acquire(bs, handle);
    binder_link_to_death(bs, handle, &si->death);
    return 0;
}
```

这里的`binder_link_to_death()`说明：

- ServiceManager在“服务注册”阶段就挂上死亡监听。
- 一旦该服务进程死亡，`svcinfo_death`会被回调，ServiceManager可以及时清理`svclist`中的无效服务项。
- 这样可以避免客户端持续拿到失效句柄，属于系统服务治理的关键机制。



#### Java 注册服务

上面讲的都是Native层的相关过程，接下来简单分析下`Java层 如何注册服务`

一般都是通过`ServiceManager.addService()`去在`Service Manager`注册服务，这一类方式主要面向的是`系统服务`。

`系统服务`相关的分析完毕后，会简单介绍开发者自定义Service的注册过程。

注册服务的操作都是由`Server`执行的，所以下面的流程基本都是在`Server端操作的`。



##### 系统服务(SystemServer) 注册服务

> 系统服务：一般指的是由`SystemServer`进程启动的服务，例如`InputManagerService`、`WindowManagerService`

```java
//SystemServer.java
            inputManager = new InputManagerService(context);
            ServiceManager.addService(Context.INPUT_SERVICE, inputManager,
                    /* allowIsolated= */ false, DUMP_FLAG_PRIORITY_CRITICAL);
```

都是通过`ServiceManager.addService()`进行注册

```java
//core/java/android/os/ServiceManager.java
    public static void addService(String name, IBinder service, boolean allowIsolated,
            int dumpPriority) {
        try {
            getIServiceManager().addService(name, service, allowIsolated, dumpPriority);
        } catch (RemoteException e) {
            Log.e(TAG, "error in addService", e);
        }
    }

   private static IServiceManager getIServiceManager() {
        if (sServiceManager != null) {
            return sServiceManager;
        }

        // Find the service manager
        sServiceManager = ServiceManagerNative
                .asInterface(Binder.allowBlocking(BinderInternal.getContextObject()));
        return sServiceManager;
    }

    static public IServiceManager asInterface(IBinder obj)
    {
      //obj 为 BinderProxy对象
        if (obj == null) {
            return null;
        }
        IServiceManager in =
            (IServiceManager)obj.queryLocalInterface(descriptor);
        if (in != null) {
            return in;
        }

        return new ServiceManagerProxy(obj);
    }
```

前面有讲到具体的处理过程，这边直接贴一个结论：

`sServiceManager`最后得到的是`ServiceManagerProxy`对象，且`IBinder`对象为`BinderProxy`

```java
//core/java/android/os/ServiceManagerNative.java
class ServiceManagerProxy implements IServiceManager {
    public ServiceManagerProxy(IBinder remote) {
        mRemote = remote;
    }    

public void addService(String name, IBinder service, boolean allowIsolated, int dumpPriority)
            throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        data.writeInterfaceToken(IServiceManager.descriptor);
        data.writeString(name);
        data.writeStrongBinder(service);
        data.writeInt(allowIsolated ? 1 : 0);
        data.writeInt(dumpPriority);
  //mRemote为 BinderProxy对象
        mRemote.transact(ADD_SERVICE_TRANSACTION, data, reply, 0);
        reply.recycle();
        data.recycle();
    }
```

###### `writeStrongBinder()`

> 将`Binder实体`写入`Parcel`中，就可以传递到对端。

```java
    public final void writeStrongBinder(IBinder val) {
        nativeWriteStrongBinder(mNativePtr, val);
    }

```

```c
//core/jni/android_os_Parcel.cpp
static void android_os_Parcel_writeStrongBinder(JNIEnv* env, jclass clazz, jlong nativePtr, jobject object)
{
    Parcel* parcel = reinterpret_cast<Parcel*>(nativePtr);
    if (parcel != NULL) {
        const status_t err = parcel->writeStrongBinder(ibinderForJavaObject(env, object));
        if (err != NO_ERROR) {
            signalExceptionForError(env, clazz, err);
        }
    }
}
```

`ibinderForJavaObject()`

> 将`Binder(Java)`转化成`Binder(c++)`对象

```cpp
//core/jni/android_util_Binder.cpp
sp<IBinder> ibinderForJavaObject(JNIEnv* env, jobject obj)
{
    if (obj == NULL) return NULL;

    // Java层的Binder对象
    if (env->IsInstanceOf(obj, gBinderOffsets.mClass)) {
        JavaBBinderHolder* jbh = (JavaBBinderHolder*)
            env->GetLongField(obj, gBinderOffsets.mObject);
        return jbh->get(env, obj);
    }

    // Java层的BinderProxy对象
    if (env->IsInstanceOf(obj, gBinderProxyOffsets.mClass)) {
        return getBPNativeData(env, obj)->mObject;
    }

    ALOGW("ibinderForJavaObject: %p is not a Binder object", obj);
    return NULL;
}
```

```cpp
    sp<JavaBBinder> get(JNIEnv* env, jobject obj)
    {
        AutoMutex _l(mLock);
        sp<JavaBBinder> b = mBinder.promote();
        if (b == NULL) {
            b = new JavaBBinder(env, obj);
            mBinder = b;
            ALOGV("Creating JavaBinder %p (refs %p) for Object %p, weakCount=%" PRId32 "\n",
                 b.get(), b->getWeakRefs(), obj, b->getWeakRefs()->getWeakCount());
        }

        return b;
    }
```

`iBinderForJavaObject()`最后转换出一个`JavaBBinder`对象

![Java-Binder与Native-Binder](/images/Java-Binder与Native-Binder)

`parcel->writeStrongBinder()`

```cpp
//frameworks/native/libs/binder/Parcel.cpp
status_t Parcel::writeStrongBinder(const sp<IBinder>& val)
{
    return flatten_binder(ProcessState::self(), val, this);
}

status_t flatten_binder(const sp<ProcessState>& /*proc*/,
    const sp<IBinder>& binder, Parcel* out)
{
    flat_binder_object obj;

    if (IPCThreadState::self()->backgroundSchedulingDisabled()) {
        /* minimum priority for all nodes is nice 0 */
        obj.flags = FLAT_BINDER_FLAG_ACCEPTS_FDS;
    } else {
        /* minimum priority for all nodes is MAX_NICE(19) */
        obj.flags = 0x13 | FLAT_BINDER_FLAG_ACCEPTS_FDS;
    }

    if (binder != NULL) {
        IBinder *local = binder->localBinder();//本地binder对象
        if (!local) {
            BpBinder *proxy = binder->remoteBinder();//远程Binder对象
            if (proxy == NULL) {
                ALOGE("null proxy");
            }
            const int32_t handle = proxy ? proxy->handle() : 0;
            obj.hdr.type = BINDER_TYPE_HANDLE;
            obj.binder = 0; /* Don't pass uninitialized stack data to a remote process */
            obj.handle = handle;
            obj.cookie = 0;
        } else {
            obj.hdr.type = BINDER_TYPE_BINDER;
            obj.binder = reinterpret_cast<uintptr_t>(local->getWeakRefs());
            obj.cookie = reinterpret_cast<uintptr_t>(local);
        }
    } else {
        obj.hdr.type = BINDER_TYPE_BINDER;
        obj.binder = 0;
        obj.cookie = 0;
    }

  //写入 flat_binder_object到 out
    return finish_flatten_binder(binder, obj, out);
}
```

`writeStrongBinder()`负责转换`IBinder`对象到`flat_binder_object`

###### `mRemote.transact(ADD_SERVICE_TRANSACTION)`

> 通过`BinderProxy`传输`Binder对象`到`Binder驱动`

```java
mRemote.transact(ADD_SERVICE_TRANSACTION, data, reply, 0);
```



```java
//core/java/android/os/Binder.java
final class BinderProxy implements IBinder {
      public boolean transact(int code, Parcel data, Parcel reply, int flags) throws RemoteException {
        //检测 data 的数据是否大于 800k
        Binder.checkParcel(this, code, data, "Unreasonably large binder buffer");


        try {
          //通过Native层 向 Binder驱动传递消息
            return transactNative(code, data, reply, flags);
        } finally {
            if (tracingEnabled) {
                Trace.traceEnd(Trace.TRACE_TAG_ALWAYS);
            }
        }
    }
  
}

    public native boolean transactNative(int code, Parcel data, Parcel reply,
            int flags) throws RemoteException;
```

```cpp
//core/jni/android_util_Binder.cpp
static jboolean android_os_BinderProxy_transact(JNIEnv* env, jobject obj,
        jint code, jobject dataObj, jobject replyObj, jint flags) // throws RemoteException
{

  //解析传递数据
    Parcel* data = parcelForJavaObject(env, dataObj);
  //解析返回数据
    Parcel* reply = parcelForJavaObject(env, replyObj);

  //target 为 BpBinder
    IBinder* target = getBPNativeData(env, obj)->mObject.get();

    //printf("Transact from Java code to %p sending: ", target); data->print();
  //向 Binder驱动发送数据
    status_t err = target->transact(code, *data, reply, flags);
    //if (reply) printf("Transact from Java code to %p received: ", target); reply->print();

    signalExceptionForError(env, obj, err, true /*canThrowRemoteException*/, data->dataSize());
    return JNI_FALSE;
}


BinderProxyNativeData* getBPNativeData(JNIEnv* env, jobject obj) {
    return (BinderProxyNativeData *) env->GetLongField(obj, gBinderProxyOffsets.mNativeData);
}

struct BinderProxyNativeData {
    // Both fields are constant and not null once javaObjectForIBinder returns this as
    // part of a BinderProxy.

    // The native IBinder proxied by this BinderProxy.
    sp<IBinder> mObject;

    // Death recipients for mObject. Reference counted only because DeathRecipients
    // hold a weak reference that can be temporarily promoted.
    sp<DeathRecipientList> mOrgue;  // Death recipients for mObject.
};
```

继续执行的就是[IPCThreadState->transact](#IPCThreadState->transact)

###### 总结

`ServiceManager.addService()`主要执行了以下几步：

1. `Parcel.obtain()`：构建Native层的`Parcel`对象
2. `parcel.writeStrongBinder()`：构造`JavaBBinder`对象写入到`flat_binder_object`，准备传到`Binder驱动`
3. `BpBinder.transact(ADD_SERVICE_TRANSACTION)`：通过`IPCThreadState.talkWithDriver()`发送数据到`Binder驱动`





##### 自定义服务(CustomServer) 注册服务

> `ServiceManager.addService()`主要面向的是系统服务，应用自定义服务是无法通过这种方式注册的。

```cpp
//frameworks/native/cmds/servicemanager/service_manager.c

static int svc_can_register(const uint16_t *name, size_t name_len, pid_t spid, uid_t uid)
{
    const char *perm = "add";

    if (multiuser_get_app_id(uid) >= AID_APP) { // AID_APP 为 10000
        return 0; /* Don't allow apps to register services */
    }

    return check_mac_perms_from_lookup(spid, uid, perm, str8(name, name_len)) ? 1 : 0;
}
```

自定义Service被分配到的`uid`都是大于`10000`的，当自定义Service执行到的时候，会在这一步被拒绝。



一般情况下通过`startService()`启动服务，`bindService()`来绑定服务并与其他Service进行交互。





#### Service Manager 获取服务

> Client 向 Service Manager 获取服务

`获取服务`流程大致与`注册服务`流程一致

只是最后执行的`do_find_service()`方法，从`Service Manager`获取注册的服务。

![查询服务](/images/5-4-2-get_service.jpg)

#### Java 获取服务

> 一般通过`ServiceManager.getService()`获取服务。
>
> 由于`ServiceManager`无法被直接调用，就需要通过底层进行调用。

##### Context#getSystemService

> 最常用的就是`getSystemService`

```java
//Context.java
    public abstract @Nullable Object getSystemService(@ServiceName @NonNull String name);

//ContextImpl.java Context实现类
    @Override
    public Object getSystemService(String name) {
        return SystemServiceRegistry.getSystemService(this, name);
    }

```

接下来就切换到`SystemServiceRegistry`执行`SystemService`相关流程

```java
//base/core/java/android/app/SystemServiceRegistry.java
//缓存 SystemServerName 与 ServiceFetcher映射关系
    private static final HashMap<String, ServiceFetcher<?>> SYSTEM_SERVICE_FETCHERS =
            new HashMap<String, ServiceFetcher<?>>();

    static abstract interface ServiceFetcher<T> {
        T getService(ContextImpl ctx);
    }

    static {
      ...
        registerService(Context.LAYOUT_INFLATER_SERVICE, LayoutInflater.class,
                new CachedServiceFetcher<LayoutInflater>() {
            @Override
            public LayoutInflater createService(ContextImpl ctx) {
                return new PhoneLayoutInflater(ctx.getOuterContext());
            }});
      ...
        registerService(Context.CONNECTIVITY_SERVICE, ConnectivityManager.class,
                new StaticApplicationContextServiceFetcher<ConnectivityManager>() {
            @Override
            public ConnectivityManager createService(Context context) throws ServiceNotFoundException {
                IBinder b = ServiceManager.getServiceOrThrow(Context.CONNECTIVITY_SERVICE);
                IConnectivityManager service = IConnectivityManager.Stub.asInterface(b);
                return new ConnectivityManager(context, service);
            }});
      ...
        registerService(Context.WIFI_P2P_SERVICE, WifiP2pManager.class,
                new StaticServiceFetcher<WifiP2pManager>() {
            @Override
            public WifiP2pManager createService() throws ServiceNotFoundException {
                IBinder b = ServiceManager.getServiceOrThrow(Context.WIFI_P2P_SERVICE);
                IWifiP2pManager service = IWifiP2pManager.Stub.asInterface(b);
                return new WifiP2pManager(service);
            }});
      ...
        
    }
    //注册系统服务 在SYSTEM_SERVICE_FETCHERS 添加
    private static <T> void registerService(String serviceName, Class<T> serviceClass,
            ServiceFetcher<T> serviceFetcher) {
        SYSTEM_SERVICE_NAMES.put(serviceClass, serviceName);
        SYSTEM_SERVICE_FETCHERS.put(serviceName, serviceFetcher);
    }

    public static Object getSystemService(ContextImpl ctx, String name) {
        ServiceFetcher<?> fetcher = SYSTEM_SERVICE_FETCHERS.get(name);
        return fetcher != null ? fetcher.getService(ctx) : null;
    }


```

根据上述源码得知`ServiceFetcher`主要有以下3种实现类

- `CachedServiceFetcher`：进程内部缓存`SystemService`，切换进程需要重新获取
- `StaticServiceFetcher`：系统内部缓存，所有进程获取的都是同一个`SystemService`
- `StaticApplicationContextServiceFetcher`：应用内部缓存`SystemService`，其他应用需要重新获取。



在`ServiceFetcher`的实现类中，需要实现`createService()`，其中内部调用到了`ServiceManager.getServiceOrThrow()`

##### ServiceManager#getService()

```java
//core/java/android/os/ServiceManager.java
    public static IBinder getServiceOrThrow(String name) throws ServiceNotFoundException {
        final IBinder binder = getService(name);
        if (binder != null) {
            return binder;
        } else {
            throw new ServiceNotFoundException(name);
        }
    }

    public static IBinder getService(String name) {
        try {
          //缓存直接获取
            IBinder service = sCache.get(name);
            if (service != null) {
                return service;
            } else {
              
                return Binder.allowBlocking(rawGetService(name));
            }
        } catch (RemoteException e) {
            Log.e(TAG, "error in getService", e);
        }
        return null;
    }

    private static IBinder rawGetService(String name) throws RemoteException {
        final long start = sStatLogger.getTime();

        final IBinder binder = getIServiceManager().getService(name);
      ...
         }
```

`getIServiceManager()`最后指向的就是`ServiceManagerProxy`

```java
//core/java/android/os/ServiceManagerNative.java
    public IBinder getService(String name) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        data.writeInterfaceToken(IServiceManager.descriptor);
        data.writeString(name);
        mRemote.transact(GET_SERVICE_TRANSACTION, data, reply, 0);
      //读取Binder对象
        IBinder binder = reply.readStrongBinder();
        reply.recycle();
        data.recycle();
        return binder;
    }
```

##### `mRemote.transact(GET_SERVICE_TRANSACTION)`

通过`IPCThreadState.talkWithDriver()`发送数据`GET_SERVICE_TRANSACTION`到`Binder驱动`

##### `readStrongBinder()`

基本就是`writeStrongBinder()`的逆向过程

```cpp
static jobject android_os_Parcel_readStrongBinder(JNIEnv* env, jclass clazz, jlong nativePtr)
{
    Parcel* parcel = reinterpret_cast<Parcel*>(nativePtr);
    if (parcel != NULL) {
        return javaObjectForIBinder(env, parcel->readStrongBinder());
    }
    return NULL;
}

```

```cpp
//frameworks/native/libs/binder/Parcel.cpp
sp<IBinder> Parcel::readStrongBinder() const
{
    sp<IBinder> val;
    // Note that a lot of code in Android reads binders by hand with this
    // method, and that code has historically been ok with getting nullptr
    // back (while ignoring error codes).
    readNullableStrongBinder(&val);
    return val;
}

status_t Parcel::readNullableStrongBinder(sp<IBinder>* val) const
{
    return unflattenBinder(val);
}

status_t Parcel::unflattenBinder(sp<IBinder>* out) const
{
    const flat_binder_object* flat = readObject(false);

    if (flat) {
        switch (flat->hdr.type) {
            case BINDER_TYPE_BINDER: {
                sp<IBinder> binder = reinterpret_cast<IBinder*>(flat->cookie);
                return finishUnflattenBinder(binder, out);
            }
            case BINDER_TYPE_HANDLE: {
                sp<IBinder> binder =
                    ProcessState::self()->getStrongProxyForHandle(flat->handle);
                return finishUnflattenBinder(binder, out);
            }
        }
    }
    return BAD_TYPE;
}
```

从`flat_binder_obj`读取得到`IBinder`对象，实质就是`BpBinder`对象

```cpp
//core/jni/android_util_Binder.cpp
jobject javaObjectForIBinder(JNIEnv* env, const sp<IBinder>& val)
{
    if (val == NULL) return NULL;

    if (val->checkSubclass(&gBinderOffsets)) {
        // It's a JavaBBinder created by ibinderForJavaObject. Already has Java object.
        jobject object = static_cast<JavaBBinder*>(val.get())->object();
        LOGDEATH("objectForBinder %p: it's our own %p!\n", val.get(), object);
        return object;
    }

    // For the rest of the function we will hold this lock, to serialize
    // looking/creation/destruction of Java proxies for native Binder proxies.
    AutoMutex _l(gProxyLock);

    BinderProxyNativeData* nativeData = gNativeDataCache;
    if (nativeData == nullptr) {
        nativeData = new BinderProxyNativeData();
    }
    // gNativeDataCache is now logically empty.
    jobject object = env->CallStaticObjectMethod(gBinderProxyOffsets.mClass,
            gBinderProxyOffsets.mGetInstance, (jlong) nativeData, (jlong) val.get());
    if (env->ExceptionCheck()) {
        // In the exception case, getInstance still took ownership of nativeData.
        gNativeDataCache = nullptr;
        return NULL;
    }
    BinderProxyNativeData* actualNativeData = getBPNativeData(env, object);
    if (actualNativeData == nativeData) {
        // New BinderProxy; we still have exclusive access.
        nativeData->mOrgue = new DeathRecipientList;
        nativeData->mObject = val;
        gNativeDataCache = nullptr;
        ++gNumProxies;
        if (gNumProxies >= gProxiesWarned + PROXY_WARN_INTERVAL) {
            ALOGW("Unexpectedly many live BinderProxies: %d\n", gNumProxies);
            gProxiesWarned = gNumProxies;
        }
    } else {
        // nativeData wasn't used. Reuse it the next time.
        gNativeDataCache = nativeData;
    }

    return object;
}
```

经过`javaObjectForIBinder()`之后转换`BpBinder`对象到`BinderProxy`对象.

`nativeData->mOrgue = new DeathRecipientList`用于保存Java层死亡回调列表：

- App侧调用`linkToDeath`注册`DeathRecipient`，最终会挂到这个列表。
- 远端死亡后，框架会遍历列表分发`binderDied()`。
- 正常解绑时应`unlinkToDeath`，避免监听器泄漏和重复回调。

通过`ServiceManager.getService()`最后`Client`持有的就是`BinderProxy`对象。

### Binder驱动

*下面源码分析基于`android-goldfish-4.4-dev`内核版本*



> Android专用，主要以`misc`设备进行注册，节点是`/dev/binder`，直接操作设备内存。

`Binder驱动`源码位于`内核`，具体代码路径位于`/drivers/android/binder.c`

#### 加载过程

##### Binder初始化-binder_init()

> 注册misc设备

```c
//drivers/android/binder.c
static int __init binder_init(void){
  int ret;
  char * device_name, * device_names;
  struct binder_device * device;
  struct hlist_node * tmp;

  binder_alloc_shrinker_init();

  atomic_set(& binder_transaction_log.cur, ~0U);
  atomic_set(& binder_transaction_log_failed.cur, ~0U);
  //构建工作队列
  binder_deferred_workqueue = create_singlethread_workqueue("binder");
  if (!binder_deferred_workqueue)
    return -ENOMEM;

  while ((device_name = strsep(& device_names, ","))) {
    //注册binder设备
    ret = init_binder_device(device_name);
    if (ret)
       goto err_init_binder_device_failed;
  }

  return ret;
}
//执行过程异常处理
```

```c
static int __init init_binder_device(const char *name)
{
    int ret;
    struct binder_device *binder_device;

    binder_device->miscdev.fops = &binder_fops;
    binder_device->miscdev.minor = MISC_DYNAMIC_MINOR;
    binder_device->miscdev.name = name;

    binder_device->context.binder_context_mgr_uid = INVALID_UID;
    binder_device->context.name = name;
    mutex_init(&binder_device->context.context_mgr_node_lock);

  //注册misc设备
    ret = misc_register(&binder_device->miscdev);

    hlist_add_head(&binder_device->hlist, &binder_devices);

    return ret;
}
```

通过`misc_register`注册Binder设备，具体配置如下：

```cpp
miscdev.fops = &binder_fops;
miscdev.minor = MISC_DYNAMIC_MINOR;
miscdev.name = name //name为以下三个 binder hwbinder cdvbinder
  
static const struct file_operations binder_fops = {
    .owner = THIS_MODULE,
    .poll = binder_poll,
    .unlocked_ioctl = binder_ioctl,
    .compat_ioctl = binder_ioctl,
    .mmap = binder_mmap,
    .open = binder_open,
    .flush = binder_flush,
    .release = binder_release,
};
```



##### 打开Binder设备-binder_open()

> 打开binder驱动设备

```cpp
static int binder_open(struct inode *nodp, struct file *filp)
{
    struct binder_proc *proc;
    struct binder_device *binder_dev;

    binder_debug(BINDER_DEBUG_OPEN_CLOSE, "binder_open: %d:%d\n",
             current->group_leader->pid, current->pid);

    proc = kzalloc(sizeof(*proc), GFP_KERNEL);
    if (proc == NULL)
        return -ENOMEM;
    spin_lock_init(&proc->inner_lock);
    spin_lock_init(&proc->outer_lock);
    get_task_struct(current->group_leader);
    proc->tsk = current->group_leader;
    INIT_LIST_HEAD(&proc->todo);
  //记录进程优先级
    if (binder_supported_policy(current->policy)) {
        proc->default_priority.sched_policy = current->policy;
        proc->default_priority.prio = current->normal_prio;
    } else {
        proc->default_priority.sched_policy = SCHED_NORMAL;
        proc->default_priority.prio = NICE_TO_PRIO(0);
    }

    binder_dev = container_of(filp->private_data, struct binder_device,
                  miscdev);
    proc->context = &binder_dev->context;
    binder_alloc_init(&proc->alloc);

    binder_stats_created(BINDER_STAT_PROC);
    proc->pid = current->group_leader->pid;
    INIT_LIST_HEAD(&proc->delivered_death);
    INIT_LIST_HEAD(&proc->waiting_threads);
    filp->private_data = proc;

    mutex_lock(&binder_procs_lock);
    hlist_add_head(&proc->proc_node, &binder_procs);//创建好的binder_proc对象插入到 binder_procs中
    mutex_unlock(&binder_procs_lock);


    return 0;
}


```

创建`binder_proc`对象，并保存当前进程信息，内部结构如下：

```cpp
struct binder_proc {
    struct hlist_node proc_node;
    struct rb_root threads; //对应的binder线程
    struct rb_root nodes; //binder节点
    struct rb_root refs_by_desc;
    struct rb_root refs_by_node;
    struct list_head waiting_threads;
    int pid;
    struct task_struct *tsk;
    struct hlist_node deferred_work_node;
    int deferred_work;
    bool is_dead;

    struct list_head todo;//当前进程的任务
    struct binder_stats stats;
    struct list_head delivered_death;
    int max_threads; //最大并发线程数
    int requested_threads;
    int requested_threads_started;
    int tmp_ref;
    struct binder_priority default_priority;
    struct dentry *debugfs_entry;
    struct binder_alloc alloc;
    struct binder_context *context;
    spinlock_t inner_lock;
    spinlock_t outer_lock;
};
```

![binder_procs](/images/binder_procs.png)

##### Binder内存映射-binder_mmap()

> 首先申内核申请虚拟地址空间，申请一块与用户虚拟内存(`*vma`)相同大小的内存；
> 再申请一个1个page大小的物理内存，再将同一块物理内存分别映射到`内核虚拟地址空间`和`用户虚拟内存空间`。
>
> 从而实现了用户空间和内核空间的`buffer`同步操作。

```c
//drivers/android/binder.c
static int binder_mmap(struct file *filp/*Binder驱动的fd*/, struct vm_area_struct *vma/*用户虚拟内存*/)
{
    int ret;
    struct binder_proc *proc = filp->private_data;
    const char *failure_string;

  //保证映射内存大小不会超过4M
    if ((vma->vm_end - vma->vm_start) > SZ_4M)
        vma->vm_end = vma->vm_start + SZ_4M;

    vma->vm_flags = (vma->vm_flags | VM_DONTCOPY) & ~VM_MAYWRITE;
    vma->vm_ops = &binder_vm_ops;
    vma->vm_private_data = proc;

  
    ret = binder_alloc_mmap_handler(&proc->alloc, vma);

    return ret;
}
```

```c
int binder_alloc_mmap_handler(struct binder_alloc *alloc,
                  struct vm_area_struct *vma)
{
    mutex_lock(&binder_alloc_mmap_lock);
    if (alloc->buffer) {
        ret = -EBUSY;
        failure_string = "already mapped";
        goto err_already_mapped;
    }
//分配一个连续的内核虚拟空间
    area = get_vm_area(vma->vm_end - vma->vm_start, VM_IOREMAP);
  ...
    //分配物理页的指针数组
    alloc->pages = kzalloc(sizeof(alloc->pages[0]) *
                   ((vma->vm_end - vma->vm_start) / PAGE_SIZE),
                   GFP_KERNEL);
    if (alloc->pages == NULL) {
        ret = -ENOMEM;
        failure_string = "alloc page array";
        goto err_alloc_pages_failed;
    }
    alloc->buffer_size = vma->vm_end - vma->vm_start;

    buffer = kzalloc(sizeof(*buffer), GFP_KERNEL);
    if (!buffer) {
        ret = -ENOMEM;
        failure_string = "alloc buffer struct";
        goto err_alloc_buf_struct_failed;
    }

    buffer->data = alloc->buffer;
    list_add(&buffer->entry, &alloc->buffers);
    buffer->free = 1;
  //
    binder_insert_free_buffer(alloc, buffer);
  //异步可用空间大小为 buffer总大小的一半
    alloc->free_async_space = alloc->buffer_size / 2;
    barrier();
    alloc->vma = vma;
    alloc->vma_vm_mm = vma->vm_mm;
    /* Same as mmgrab() in later kernel versions */
    atomic_inc(&alloc->vma_vm_mm->mm_count);

    return 0;    
  
}
```

当把同一块物理页面同时映射到进程空间和内核空间时，当需要在两者之间传递数据时，只需要其中任意一方把数据拷贝到物理页面，另一方直接读取即可，也就是说，数据的跨进程传递，只需要一次拷贝就可以完成。



##### Binder内存管理-binder_ioctl()

> 负责在两个进程间收发`IPC 数据`和`IPC Reply`数据。

```cpp
static long binder_ioctl(struct file *filp/*binder驱动的fd*/, unsigned int cmd/*ioctl命令*/, unsigned long arg/*数据类型*/)
{
...
switch (cmd) {
    case BINDER_WRITE_READ:
        ret = binder_ioctl_write_read(filp, cmd, arg, thread);
        if (ret)
            goto err;
        break;
    case BINDER_SET_MAX_THREADS: {
        int max_threads;

        if (copy_from_user(&max_threads, ubuf,
                   sizeof(max_threads))) {
            ret = -EINVAL;
            goto err;
        }
        binder_inner_proc_lock(proc);
        proc->max_threads = max_threads;
        binder_inner_proc_unlock(proc);
        break;
    }
    case BINDER_SET_CONTEXT_MGR:
        ret = binder_ioctl_set_ctx_mgr(filp);
        if (ret)
            goto err;
        break;
    
}
  
}
```

`binder驱动`将业务分为多种不同的命令，再根据具体的命令执行不同的业务。常用命令有以下几种：

- **`BINDER_WRITE_READ`**：负责收发`Binder IPC`数据

  使用场景：`Service Manager`通过发送`BINDER_WRITE_READ`命令向`Binder驱动`读写数据

- `BINDER_SET_MAX_THREADS`：设置进程最大binder线程个数

  使用场景：在`ProcessState`初始化的时候，会设置当前进程支持的最大个数，默认为15，设置的命令为`BINDER_SET_MAX_THREADS`

- `BINDER_SET_CONTEXT_MGR`：设置Service Manager为大管家。

  使用场景：ServiceManager启动过程中调用`binder_become_context_manager()`命令为`BINDER_SET_CONTEXT_MGR`

使用最频繁的就是`BINDER_WRITE_READ`，下面简单的分析一下流程：

```cpp
static long binder_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
  ...
    switch (cmd) {
    case BINDER_WRITE_READ:
        ret = binder_ioctl_write_read(filp, cmd, arg, thread);
        if (ret)
            goto err;
        break;
      ...
  
}
```

```cpp
static int binder_ioctl_write_read(struct file *filp,
                unsigned int cmd, unsigned long arg,
                struct binder_thread *thread)
{
    int ret = 0;
    struct binder_proc *proc = filp->private_data;
    unsigned int size = _IOC_SIZE(cmd);
    void __user *ubuf = (void __user *)arg;
    struct binder_write_read bwr;

    if (size != sizeof(struct binder_write_read)) {
        ret = -EINVAL;
        goto out;
    }
  //从用户空间拷贝数据到 bwr(内核空间)
    if (copy_from_user(&bwr, ubuf, sizeof(bwr))) {
        ret = -EFAULT;
        goto out;
    }
  
    if (bwr.write_size > 0) {
    //存在写数据时，执行binder写操作
        ret = binder_thread_write(proc, thread,
                      bwr.write_buffer,
                      bwr.write_size,
                      &bwr.write_consumed);
        trace_binder_write_done(ret);
        if (ret < 0) {
            bwr.read_consumed = 0;
            if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
                ret = -EFAULT;
            goto out;
        }
    }
  
    if (bwr.read_size > 0) {
    //存在读数据，执行binder读操作
        ret = binder_thread_read(proc, thread, bwr.read_buffer,
                     bwr.read_size,
                     &bwr.read_consumed,
                     filp->f_flags & O_NONBLOCK);
        trace_binder_read_done(ret);
        binder_inner_proc_lock(proc);
        if (!binder_worklist_empty_ilocked(&proc->todo))
            binder_wakeup_proc_ilocked(proc);
        binder_inner_proc_unlock(proc);
        if (ret < 0) {
            if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
                ret = -EFAULT;
            goto out;
        }
    }

  //将内核数据 bwr 拷贝回 用户空间
    if (copy_to_user(ubuf, &bwr, sizeof(bwr))) {
        ret = -EFAULT;
        goto out;
    }
out:
    return ret;
}
```

`binder_write_read`时`内核层`定义的结构

```cpp
struct binder_write_read {//用在binder内部
    binder_size_t		write_size;	//用户空间写入数据的size
    binder_size_t		write_consumed;	//Binder读取了多少数据
    binder_uintptr_t	write_buffer;//用户空间写入数据
    binder_size_t		read_size;	//binder写入数据的size
    binder_size_t		read_consumed;	//用户空间读取了多少数据
    binder_uintptr_t	read_buffer; //Binder写入数据
};
```

![binder_transaction_data](/images/binder_transaction_data.jpg)

`binder_ioctl_write_read()`主要执行以下几步：

1. 通过`copy_from_user()`拷贝`用户空间数据`到`内核空间`
2. 存在`write_size > 0`，意味着外部有数据传入，需要执行`binder_thread_write()`，读取外部传入数据
3. 存在`read_size > 0`，意味着有数据要传出，需要执行`binder_thread_read()`，写入数据准备传到外部
4. 最后执行`copy_to_user()`拷贝`内核空间数据`到`用户空间`



![Binder_write_read过程](/images/Binder_binder_ioctl_write_read.png)



#### 总结

![Binder驱动加载](/images/Binder驱动加载过程.png)



## Binder通信过程

结合前面的源码与驱动流程，一次典型Binder调用链可以抽象成6步：

1. `Client`侧`Proxy`把方法参数写入`Parcel`，调用`transact()`。
2. `IPCThreadState`通过`ioctl(BINDER_WRITE_READ)`把`BC_TRANSACTION`送入驱动。
3. `Binder驱动`定位目标`binder_proc/binder_thread`，将事务投递到`Server`进程待处理队列。
4. `Server`侧`Stub.onTransact()`被唤醒并执行业务逻辑。
5. 执行结果写回`reply Parcel`，驱动回传`BR_REPLY`给`Client`。
6. `Client`线程收到响应并反序列化结果，方法调用返回。

`oneway`调用在第5步不会等待`BR_REPLY`，通常在收到`BR_TRANSACTION_COMPLETE`后即可返回。













![binder_ipc_process](/images/binder_ipc_process.jpg)

![Binder通信过程](/images/Binder通信过程.png)

### Binder权限验证

`进程A`通过Binder调用`进程B`，然后`进程B`又Binder调用`进程C`，此时进程C中的`IPCThreadState`存储的就是`进程A`的`PID和UID`。此时假如`进程B`想调用`进程C`，就会抛出异常`Bad call: specified package com.providers.xxx under uid 10032 but it is really 10001`。



*Binder的权限验证会导致进程A调用进程B后，进程B调用原进程方法时失败。*



上述流程就是`Binder权限验证`的流程。

`在被调用时进程会去检测是否与自身IPCThreadState存储的UID与PID一致，只有一致才会请求成功。否则抛出异常。`

#### 解决方案

```java
final long origId = Binder.clearCallingIdentity();
//远程调用过程
Binder.restoreCallingIdentity(origId);
```

`clearCallingIdentity()`

> 在当前线程中重置到来的IPC标识(`uid/pid`)，然后设置`mCallingUid`和`mCallingPid`为当前进程的值



`restoreCallingIdentity(id)`

> 还原前面存储的初始调用者的`mCallingPid`和`mCallingUid`

#### 组件级权限控制（Manifest）

除调用链身份校验外，还可以通过组件权限限制可绑定方：

```xml
<!-- AndroidManifest.xml -->
<permission
    android:name="com.example.wxy.permission.checkBook"
    android:protectionLevel="normal" />

<uses-permission android:name="com.example.wxy.permission.checkBook" />

<service
    android:name=".service.AIDLService"
    android:exported="true">
    <intent-filter>
        <action android:name="com.example.wxy" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</service>
```





## Binder-AIDL

> 全称为`Android Interface Definition Language`——Android接口定义语言。

`Messenger`是基于`AIDL`的，不过只能处理串行的消息，存在大量消息需要同时处理时，也只能一个个处理，这时就需要使用AIDL来处理多消息的情况。

`AIDL`本质就是系统提供的一种快速实现`Binder`的工具，不一定需要依赖`AIDL`去实现功能。

### AIDL支持的数据类型

- 基本数据类型：`byte、int、long、float、double、boolean，char`
- String 和 CharSequence
- ArrayList，HashMap(**包括key，每个元素必须可以被AIDL支持**)
- 实现了`Parcelable`接口的对象 **必须显式import进来**
- 所有AIDL接口本身也会被调用 **必须显式import进来**



### 定向tag

> 除了基本数据类型，其他类型的参数必须加上方向 **in,out,inout**，用于表示在跨进程通信中的数据流向。

- `in`：表示数据只能由客户端流向服务端。服务端会收到这个对象的完整数据，**但在服务端对对象进行修改不会对客户端传递进来的对象造成影响。**
- `out`：表示数据只能由服务端传递到客户端。服务端会接受到这个对象的空对象，**但在服务端接收到的空对象有任何修改之后客户端会同步发生变化。**
- `inout`：表示数据可以在服务端和客户端之间双向流通。服务端会收到这个对象的完整数据，**且客户端会同步服务端对该对象的任何改动。**



### 关键类与方法

`AIDL`文件代码

```java
interface BookManager {
    int getResult(int a,out List<String> b,inout List<String> c ,in String d);
}
```



`AIDL`文件便已完成后会得到一个Java文件，生成内容主要如下：

```java
public interface BookManager extends IInterface {
  public static abstract class Stub extends Binder implements BookManager {
        public static BookManager asInterface(IBinder obj) {
            if ((obj == null)) {
                return null;
            }
          //寻找本地的Binder对象
            IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            if (((iin != null) && (iin instanceof BookManager))) {
              //本地Binder对象存在，表示当前 Client与 Server处于同一进程，直接调用对应方法即可
                return ((BookManager) iin);
            }
          //不存在本地Binder对象，生成代理对象进行远程调用
            return new Proxy(obj);
        }
    
       //返回当前Binder对象
   // IBinder 这个代表了一种跨进程通信的能力。只要实现了这个接口，这个对象就可以跨进程传输。Client和Server进程都要实现该接口。
        @Override
        public android.os.IBinder asBinder() {
            return this;
        }
    
        @Override
        public boolean onTransact(int code, Parcel data, Parcel reply, int flags) throws RemoteException {
            switch (code) {
                case TRANSACTION_getResult: {
                    data.enforceInterface(descriptor);
                    int _arg0;
                    _arg0 = data.readInt();
                    java.util.List<java.lang.String> _arg1;
                    _arg1 = new java.util.ArrayList<java.lang.String>();
                    java.util.List<java.lang.String> _arg2;
                    _arg2 = data.createStringArrayList();
                    java.lang.String _arg3;
                    _arg3 = data.readString();
                    int _result = this.getResult(_arg0, _arg1, _arg2, _arg3);
                    reply.writeNoException();
                    reply.writeInt(_result);
                    reply.writeStringList(_arg1);
                    reply.writeStringList(_arg2);
                    return true;
                }   
            }
        }
    
        private static class Proxy implements BookManager {
            private android.os.IBinder mRemote;

            Proxy(android.os.IBinder remote) {
                mRemote = remote;
            }

            @Override
            public android.os.IBinder asBinder() {
                return mRemote;
            }    
          
            @Override
            public int getResult(int a, java.util.List<java.lang.String> b, java.util.List<java.lang.String> c, java.lang.String d) throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                int _result;
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    _data.writeInt(a);//int a 默认为 in
                    _data.writeStringList(c);//inout c 
                    _data.writeString(d);//in String d
                  //客户端调用 该方法传参到 服务端
                    mRemote.transact(Stub.TRANSACTION_getResult, _data, _reply, 0);
                    _reply.readException();
                    _result = _reply.readInt();
                    _reply.readStringList(b);//out b
                    _reply.readStringList(c);//inout c
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
                return _result;
            }
          
        static final int TRANSACTION_getResult = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);          
  }
  
    public int getResult(int a, List<String> b, List<String> c, String d) throws RemoteException;

}
```

根据上述生成的代码：

#### 类/接口

`IInterface`

表示`Server`进程需要具备什么功能，对应的就是`Client`进程可以调用的方法。

`Stub`

一个跨进程调用对象，继承自`Binder`，表示为`Server进程的本地Binder对象`，需要实现`Server`进程可以提供的功能。

`Proxy`

`Binder`代理对象，位于`Client`进程，由其发起`transact()`与Binder驱动进行通信。

#### 方法

`asBinder()`

返回当前进程的Binder对象。

- 对于`Client`进程：返回远端进程的`BinderProxy`代理对象
- 对于`Server`进程：返回当前进程的IBinder对象



`asInterface()`

通常用在`bindService()`之后，继续在`onServiceConnected()`调用该方法，就可以把`IBinder`对象转换成`IInterface`，就可以直接调用对应`Server`进程的方法。



`onTransact(int code, Parcel data, Parcel reply, int flags)`

参数说明：

- `code`：根据`code`确定`Client`端请求的方法
- `data`：`Client`方法请求参数
- `reply`：`Server`方法返回参数
- `flags`：设置IPC模式。
  - 0：双向流通(默认值)
  - 1：单向流程

对应的就是`Proxy`中各个方法内部调用的`mRemote.transact()`传递的参数。

#### 代理机制补充

`Client`通过`ServiceManager`拿到`Server`引用后，得到的通常不是`Server`端本地实体，而是一个代理对象（`Proxy` / `BinderProxy`）。

代理对象与本地对象对外暴露的方法看起来一致，但其核心职责是：

- 组装参数到`Parcel`
- 调用`transact()`把请求交给`Binder驱动`
- 等待并解析返回结果

因此，Binder代理机制的本质是：

`本地调用语义` + `跨进程传输实现` 的桥接。

![Binder代理机制](/images/Binder代理机制.png)

上图可以和AIDL生成代码对照理解：`Proxy`负责请求打包与发起，`Stub`负责解包与分发，两者通过`Binder驱动`完成跨进程桥接。







根据上述生成代码，可以大致分析出AIDL内部代码的工作机制

![Binder工作机制](/images/Binder-workflow.png)



- Client调用`远程Binder对象`，然后`Client`挂起，等待`Server`响应数据
- `Binder代理对象`将请求发送给`Binder驱动`
- `Binder驱动`转发请求给Server
- `Server`处理完请求后，返回结果到`Binder驱动`，再回到`Client`并唤醒

### AIDL实战常见问题

1. 可能产生ANR

   - 客户端同步调用耗时服务端方法，调用线程被挂起。
   - 在`onServiceConnected/onServiceDisconnected`中执行耗时逻辑。
   - 服务端回调客户端listener时，客户端`binder线程池`执行耗时任务。

   建议：远程调用放在非UI线程，Binder回调中避免重任务。

2. AIDL解注册失败

   跨进程listener经过序列化/反序列化后通常不是同一对象引用，服务端可能无法正确匹配原注册对象。

   建议：使用`RemoteCallbackList`管理远程回调，并确保`beginBroadcast()`与`finishBroadcast()`成对使用。

3. 性能损耗较大

   高频同步IPC会带来明显开销。可通过“变更通知 + 批量拉取”降低调用频率。



## Binder-系统调用

Binder用户态最终是通过`ioctl`进入内核驱动，不同命令码会路由到不同处理分支。

`ioctl`命令通常由`_IO/_IOR/_IOW/_IOWR`宏编码，包含了`方向(读/写)`、`类型`、`序号`、`数据结构大小`等信息，内核据此做参数校验与分发。

在Binder场景里最常见的是`BINDER_WRITE_READ`：

1. 用户态把`binder_write_read`结构体传给驱动。
2. 驱动在`binder_ioctl()`中根据`cmd`命中`BINDER_WRITE_READ`分支。
3. 进入`binder_ioctl_write_read()`，再按`write_size/read_size`分别处理`binder_thread_write()`和`binder_thread_read()`。

因此可以理解为：`ioctl`负责“路由到哪个驱动命令”，`binder_write_read`负责“本次事务要写什么、读什么”。



## Binder拓展知识

### Binder传输数据上限，以及超出会如何？

> Binder单进程映射缓冲区常见为约`1MB`（常见可用值约`1016KB`），异步事务可用空间通常受`free_async_space`限制（常见约一半）。

当单次事务数据过大时，应用层最常见异常是`TransactionTooLargeException`；在更底层场景也可能表现为`BR_FAILED_REPLY/FAILED_TRANSACTION`，极端情况下才可能看到`DeadObjectException`。

### 每个进程最大Binder线程数，以及超出会如何？

> 每个进程最多可以运行`16`个Binder线程

当所有的16个binder线程都在工作时，就会出现线程饥饿状态。如果此时有新的binder线程请求，就会进入阻塞状态。

### `oneway`的作用

**异步调用和串行化处理**

- `异步调用`：应用向`Binder驱动`发送数据后不等待`BR_REPLY`，通常在收到`BR_TRANSACTION_COMPLETE`后就返回。
- `串行化处理`：同一Binder对象上的`oneway`事务会按队列顺序处理，不是无限并发执行。



> `oneway`都是需要等待`BR_TRANSACTION_COMPLETE`消息。
>
> 不过`oneway`的请求方式在收到`BR_TRANSACTION_COMPLETE`消息后，立即返回；
>
> `非oneway`的请求方式，还需要等到`BR_REPLY`之后才返回，此时线程会处于阻塞等待状态，底层常见路径是`wait_event_interruptible()`。

```java
//XX.aidl
interface IXX {
  //定义该方法调用 为 oneway
  oneway void xx();
}
```

### Binder连接池（BinderPool）

当业务模块变多后，如果每个模块都创建独立`Service + AIDL`，会增加组件数量与连接治理成本。

`BinderPool`的核心思路：

- 统一一个远程Service作为入口。
- 通过`queryBinder(binderCode)`按标识返回不同业务Binder。
- 用一条连接管理多业务能力，降低重复建设成本。

工作原理：

{% fullimage /images/BinderPool.png,BinderPool工作原理, BinderPool工作原理%}

实现步骤（简版）：

- 定义各业务AIDL接口与实现。
- 定义`IBinderPool.aidl`。
- 实现`BinderPoolService`并在`onBind()`返回`BinderPool`。
- 在`queryBinder()`中根据`binderCode`分发。
- 客户端连接后按需获取目标Binder。

### Binder跨进程传输大文件

`Intent`和`Binder事务`都存在大小限制，大文件不建议直接走Binder事务。

可选方案：

- 文件共享（`FileProvider`）。
- 分块传输。
- 共享内存（如`ashmem`）。
- `ContentProvider`或流式读取。







## 参考链接

[Binder介绍](https://blog.hacktivesecurity.com/index.php?controller=post&action=view&id_post=48)

[Binder系列讲解](http://gityuan.com/)

[图解Android - Binder 和 Service](https://www.cnblogs.com/samchen2009/p/3316001.html)

[深入理解Binder通信原理及面试问题](https://blog.csdn.net/happylishang/article/details/62234127)

[Android Binder设计与实现-设计篇](https://blog.csdn.net/universus/article/details/6211589)

[Binder｜内存拷贝的本质和变迁](https://juejin.cn/post/6844904113046568973)
