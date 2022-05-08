---
title: Java-AbstractQueuedSynchronizer简介
typora-root-url: ../
date: 2020-09-13 17:28:19
tags: Java
top: 9
---

![AQS原理](/images/AQS原理xmind.png)

## AQS简介

AQS全称为`AbstractQueuedSynchronizer`，意为`抽象队列同步器`。

- `Abstract`：抽象类，只实现主要逻辑，其他交由子类实现
- `Queued`：`FIFO`队列存储数据
- `Synchronizer`：同步

在`Lock`中，是非常重要的核心组件。`AQS`是用来构建锁和同步器的框架，使用`AQS`可以简单且高效构建同步器。我们常见的`ReentrantLock、CountdownLatch`都是基于`AQS`构建的。

`AQS`主要做了三件事情：

1. 同步状态的管理
2. 线程的阻塞和唤醒
3. 同步队列的维护

## AQS同步方式

从使用层面来讲，AQS同步方式分为以下两种：

### 独占模式(Exclusive)

资源是独占的，一次只能有一个线程获取。

例如`ReentrantLock`



### 共享模式(Share)

资源是共享的，可以被多个线程同时获取并访问，还可以指定允许访问的资源个数。

例如`CountdownLatch`、`Semaphore`



### 混合模式(mixed)

将两种模式混合在一起进行使用，可以在特定条件下进行`独占`或`共享`资源。

例如`ReentrantReadWhiteLock`



## AQS的数据结构

AQS依赖内部的一个`FIFO双端队列`实现同步状态(`state`)的管理，并且使用了`head`和`tail`分别表示队列的首尾节点。

![AQS-等待队列](/images/AQS-等待队列.png)

队列中储存的是`Node`节点，其中包含了**当前线程以及等待状态信息**。

### state

> 表示资源当前状态。

```java
private volatile int state; //资源标识
```

同时定义了了几个关于`state`的方法，提供给子类覆盖实现自身逻辑。

例如：

`ReentrantLock`：表示的资源为`独占锁`，`state=0`表示没持有锁，`state=1`表示锁被占用，`state>1`表示了锁重入次数。

`CountdownLatch`：表示的资源为`计数`，`state=0`表示计数器归零，可以被其他线程访问资源，`state>0`表示所有线程访问资源时都需要阻塞。

```java
getState()//获取同步状态
  
setState(int newState)//设置同步状态
  
compareAndSetState(int expect,int update)//基于CAS，原子设置当前状态
```



### Node

> AQS内部等待队列的节点

```java
    /*     
     * <pre>
     *      +------+  prev +-----+       +-----+
     * head |      | <---- |     | <---- |     |  tail
     *      +------+       +-----+       +-----+
     * </pre>
     */  
static final class Node {
   //标记当前节点(线程)位于共享模式下等待
   static final Node SHARED = new Node();
   //标记当前节点(线程)位于独占模式下等待
   static final Node EXCLUSIVE = null;
   //表示当前线程状态是取消的
   static final int CANCELLED =  1;
   //表示当前线程正在等待锁，需要被唤醒
   static final int SIGNAL    = -1;
   //表示当前线程等待某一条件
   static final int CONDITION = -2;
   //表示当前线程有资源可用，需要继续唤醒后续节点(CountdownLatch下使用)
   static final int PROPAGATE = -3;
   //节点中线程的状态，默认为0
   volatile int waitStatus;
   //当前节点的前一个节点
   volatile Node prev;
   //当前节点的后一个节点
   volatile Node next;
   //当前节点封装的线程信息
   volatile Thread thread;
   //等待队列中的下一个等待节点
   Node nextWaiter;
   
   //判断是否为共享模式
   final boolean isShared() {
            return nextWaiter == SHARED;
        }
  
   Node(Thread thread, Node mode) {     // Used by addWaiter
            this.nextWaiter = mode;
            this.thread = thread;
        }
  
}
```

![AQS-Node](/images/AQS-Node.png)

`prev`：当前节点的上一个节点

`next`：当前节点的下一个节点

`thread`：当前节点持有的线程

`waitStatus`：当前节点的状态

`nextWaiter`：下一个处于`CONDITION`状态的节点

`Node`是一个变体`CLH`的节点，`CLH`应用了自旋锁，节点保存了当前阻塞线程的信息。如果他的前驱节点释放了，就需要通过修改`waitStatus`字段出队前驱节点，让当前节点尝试获取锁。若有新的等待线程要入队，就会加入到队列的尾部。

其中`waitStatus`有以下几种状态：

| waitStatus | 值   | 描述                                                         |
| ---------- | ---- | ------------------------------------------------------------ |
| SIGNAL     | -1   | 表示当前节点的后续节点被阻塞或即将被阻塞，当前节点释放或取消后需要唤醒后续节点。*一般是后续节点来设置前驱节点的。* |
| CANCELLED  | 1    | 表示当前节点超时或被中断，需要移出等待队列                   |
| CONDITION  | -2   | 表示当前节点在`Condition`队列中，阻塞等待某个条件唤醒        |
| PROPAGATE  | -3   | 适用于共享模式(连续的操作节点依次进入临界区)，用于将唤醒后续线程传递下去，**为了完善和增强锁的唤醒机制。** |
| INIT       | 0    | 节点初始创建处于该状态                                       |

[CLH队列](https://blog.csdn.net/HalfImmortal/article/details/107432756)

> 通过`Node`可以实现两个队列
>
> - 通过`prev`、`next`实现双向队列
> - 通过`nextWaiter`实现`Condition`的单向等待队列

### ConditionObject

> 用于实现`Condition`功能的内部类，直接作用于线程，对线程进行调度

```java
    public class ConditionObject implements Condition, java.io.Serializable {
        private static final long serialVersionUID = 1173984872572414699L;
        /** First node of condition queue. */
        private transient Node firstWaiter;
        /** Last node of condition queue. */
        private transient Node lastWaiter;
      ...
    }
```

由`Node`组成的单向队列。

<!--后续原理描述会分析内部实现。 -->

## AQS原理解析

### 子类实现方法

`AQS`的设计是基于**模板方法模式(定义基本功能后，将一些实现延迟到子类)**的，所以其中一些方法必须交由子类去实现。

#### isHeldExclusively()-是否独占资源

该线程是否正在独占资源。*只有需要用到`Condition`才需要去实现该方法*

#### tryAcquire()-获取独占资源

**独占方式**获取资源，成功获取返回`true`，失败返回`false`

#### tryRelease()-释放独占资源

**独占方式**释放资源，成功释放返回`true`，失败返回`false`

#### tryAcquireShared()-获取共享资源

**共享方式**获取资源

- 返回`负数`，表示资源获取失败
- 返回`0`，表示获取成功，但没有多余资源可获取
- 返回`>0`，表示获取成功，且有剩余资源

#### tryReleaseShared()-释放共享资源

**共享方式**释放资源

- 释放资源后，允许唤醒后续等待节点，返回`true`
- 释放资源后，没有后续等待节点，返回`false`



子类主要实现上述几个方法，主要逻辑还是在`AQS`内部进行实现。



### 获取资源-独占模式

![AQS-独占模式-获取资源](/images/AQS-独占模式-获取资源.png)

获取资源的入口是`acquire(int arg)`。`arg`是要获取资源的个数

- `独占模式`：arg = 1
- `共享模式`：arg >= 0

```java
    public final void acquire(int arg) {
        if (!tryAcquire(arg) && //1⃣️
            acquireQueued( //2⃣️
              addWaiter(Node.EXCLUSIVE), arg) //3⃣️
            )
            selfInterrupt();
    }
```

#### tryAcquire(int arg)

子类实现的模板方法，在介绍`ReentrantLock`时会分析内部实现

#### addWaiter(Node.EXCLUSIVE)

只有在`tryAcquire()`获取资源失败时，才会执行到该方法，将当前线程初始化为一个`Node`节点，加入到`等待队列`中。其中`Node.EXCLUSIVE`表示当前锁是独占的。

```java
static final Node EXCLUSIVE = null;

//为当前线程创建指定模式的节点
   private Node addWaiter(Node mode) {
       //生成对应的Node节点
        Node node = new Node(Thread.currentThread(), mode);
        // Try the fast path of enq; backup to full enq on failure
        Node pred = tail;
        if (pred != null) {
            //采用尾插法
            node.prev = pred;
          //使用CAS尝试交换节点
            if (compareAndSetTail(pred, node)) {
                pred.next = node;
                return node;
            }
        }
     //等待队列为空，或者CAS交换失败，插入队列
        enq(node);
        return node;
    }

//插入数据到队列中
    private Node enq(final Node node) {
        for (;;) {
            Node t = tail;
            if (t == null) { // Must initialize
                if (compareAndSetHead(new Node()))
                    tail = head;//初始化等待队列
            } else {
                node.prev = t;//新进节点放在队列尾部
                if (compareAndSetTail(t, node)) {//交换尾节点与插入节点
                    t.next = node;
                    return t;
                }
            }
        }
    }
```

这一步的操作是为了，在等待队列的尾部插入新`Node`节点，但是可能存在多个线程同时争夺资源的情况，因为在插入节点时需要做线程安全操作，这里就是通过`CAS`保证线程操作的安全性。

![AQS-独占模式-等待队列](/images/AQS-独占模式-等待队列.jpg)



1. 执行`tryAcquire()`失败后，将当前线程初始化为一个`Node`节点，加入到`AQS`等待队列中-调用`addWaiter()`
2. 第一次加入等待队列，此时尚未初始化完成，`head`，`tail`都为`null`
3. 就需要在执行`enq()`将等待队列初始化，并插入`Node`节点，**头节点为空线程**
4. 后续再有新的申请进来后，`Node`节点直接插入到等待队列的尾部

> 为什么头节点为空线程？
>
> 此处的头节点`head`起到了一个**哨兵**的作用，`免去后续查找过程中的越界判断`。

#### acquireQueued(node,arg)

经过`addWaiter()`之后，线程加入到等待队列中，但是线程还没有被挂起等待，而`acquireQueued()`去执行线程挂起的相关操作。

```java
    final boolean acquireQueued(final Node node, int arg) {
        boolean failed = true;
        try {
            boolean interrupted = false;
            for (;;) {
                final Node p = node.predecessor();//获取前一个节点
              //前一个节点是 head，再尝试获取一次锁  
              if (p == head && tryAcquire(arg)) {
                    setHead(node);//获取资源后，设置当前节点为头节点
                    p.next = null; // 原先头节点置为null，移出等待队列
                    failed = false;
                    return interrupted;
                }
              //获取锁失败了，就将自己挂起进入`waiting`状态，直到`unpark`调用
                if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                    interrupted = true;
            }
        } finally {
            if (failed)
                cancelAcquire(node);
        }
    }
```

若前一个节点是`head`，那么再次调用`tryAcquire()`去竞争锁；竞争失败了，就执行`shouldParkAfterFailedAcquire()`判断是否将自己的线程挂起

```java
    private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
        int ws = pred.waitStatus;//前一个节点的状态
        if (ws == Node.SIGNAL)//前一个节点处于 阻塞挂起状态，当前线程可以挂起
            return true;
        if (ws > 0) {//前一个节点处于取消状态
            do {
                node.prev = pred = pred.prev;//移出已被取消的节点
            } while (pred.waitStatus > 0);
            pred.next = node;
        } else {//前一个节点处于 初始化或者 PRPPAGATE，当前需要一个信号才能将当前线程挂起。
            compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
        }
        return false;
    }
```

> 线程能否挂起的判断条件：
>
> **前一个节点的`waitStatus`必须是`SIGNAL(-1)`，因为后面`unlock()`会去唤醒`waitStatus`为`SIGNAL`的线程去争夺锁。**

若`shouldParkAfterFailedAcquire()`判断需要将当前线程挂起，则继续执行`parkAndCheckInterrupt()`挂起当前线程。

```java
    private final boolean parkAndCheckInterrupt() {
        LockSupport.park(this);//当前线程被挂起
        return Thread.interrupted();//返回中断标记并对当前线程进行复位
    }
```

`parkAndCheckInterrupt()`内部调用到了`LockSupport.park()`，该方法主要用于中断一个线程。

> `LockSupport`是`Java 6`后引入的一个类，提供了基本的`线程同步原语`。
>
> 内部实际调用了`Unsafe`的函数。
>
> 主要提供了两个方法：
>
> - `park()`：阻塞当前线程
> - `unpark(thread)`：使`thread`停止阻塞

在后续新增的节点进入`AQS等待队列`后，是通过`LockSupport.park()`使线程进入阻塞状态。

`LockSupport.park()`遇到以下情况时，会立即中断阻塞状态

- 其他线程调用了`unpark()`停止了当前线程的阻塞状态
- 其他线程中断了当前线程

```java
    public static void main(String[] args) throws InterruptedException{
        Thread t1 = new Thread(()->{
            LockSupport.park();
            System.err.println("当前park无效 "+Thread.currentThread().isInterrupted());
            LockSupport.park();
            System.err.println("park无效");
           
        },"t1");
        t1.start();
        Thread.sleep(1000);
        t1.interrupt();
    }

输出结果：
  当前park无效 true
  park无效
```

结合以上代码的运行结果可知以下几点：

- 当一个线程`park()`时，其他线程中断该线程时，线程会立即恢复，且中断标记为`true`还不会抛出`InterruptedException`异常
- 当一个线程的中断标记为`true`时，调用`park()`无法挂起线程

所以这就是为什么`parkAndCheckInterrupt()`返回了`Thread.interrupted()`去重置中断标记。

> `interrupt()`：打一个中断标记，但不会中断当前线程
>
> `isInterrupted()`：返回当前线程的中断标记，如果执行过`interrupt()`则返回`true`，表示当前线程被中断过
>
> `interrupted()`：返回当前线程的中断标记，如果执行过`interrupt()`则返回`true`，表示当前线程被中断过。**但是多执行了一步复位操作，后续调用`isInterrupted()`返回`false`。**

若不执行`线程复位`操作，后续对当前线程执行`LockSupport.park()`时，挂起操作无法生效，就会导致发生死循环，耗尽资源。

![AQS-获取资源](/images/AQS-获取资源.jpg)

> 简单文字概述`AQS-获取资源过程`
>
> 1. 尝试获取资源——`tryAcquire()`
> 2. 获取资源失败，请求入队列——`addWaiter(Node.EXCLUSIVE)`
>    1. 根据传入的模式(`EXCUSIVE`)创造节点(`Node`)
>    2. 判断尾节点(`tail`)是否存在，不存在使用`enq(node)`初始化节点`head、tail`；存在`tail`，请求节点插入尾部
>    3. 使用`CAS自旋`插入请求到尾端，插入失败的话，调用`enq(node)`自旋插入直到成功
> 3. 请求入队列后，需要不断去获取资源——`acquireQueued(node)`
>    1. 不断获取当前节点的上一个节点是否为`head`，若是，则表示当前节点为`请求节点`
>    2. 若是`请求节点`，不断的调用`tryAcquire()`获取资源，获取成功执行`setHead()`
>    3. 若当前非`head`后的第一个`请求节点`或者`tryAcquire()`请求资源失败，需要通过`shouldParkAfterFailedAcquire()`判断当前节点是否需要阻塞(`判断前一个节点waitStatus == NODE.SIGNAL`)
>    4. 若需要阻塞则执行`parkAndCheckInterrupt()`实质执行`LockSupport.park()`

#### cancelAcquire()

`acquireQueued()`执行到`finally`时就会执行该方法

```java
private void cancelAcquire(Node node) {
        // Ignore if node doesn't exist
        if (node == null)
            return;

        node.thread = null;

        // 已被取消的节点都移出等待队列
        Node pred = node.prev;
        while (pred.waitStatus > 0)
            node.prev = pred = pred.prev;
        //找到有效节点的下一个节点
        Node predNext = pred.next;
        //设置当前节点为取消
        node.waitStatus = Node.CANCELLED;

        // If we are the tail, remove ourselves.
        if (node == tail && compareAndSetTail(node, pred)) {
            //当前为尾节点 直接移除
            compareAndSetNext(pred, predNext, null);
        } else {
            int ws;
            if (pred != head && //不是头节点
                ((ws = pred.waitStatus) == Node.SIGNAL || //处于SIGNAL状态
                 (ws <= 0 && compareAndSetWaitStatus(pred, ws, Node.SIGNAL))) &&//pred设置为SIGNAL状态成功
                pred.thread != null) { //并且有 等待线程
                Node next = node.next;
                if (next != null && next.waitStatus <= 0)
                    compareAndSetNext(pred, predNext, next);
            } else {
              //当前为头节点的下一个有效节点
                unparkSuccessor(node);
            }

            node.next = node; // help GC
        }
    }
```

//TODO 补齐流程分析

### 释放资源-独占模式

![AQS-独占模式-释放资源](/images/AQS-独占模式-释放资源.png)

释放资源的入口是`release(int arg)`，`arg`为释放资源的个数

```java
    public final boolean release(int arg) {
        if (tryRelease(arg)) {
            Node h = head;
            if (h != null && h.waitStatus != 0)//头节点不为空，且状态不为新建
                unparkSuccessor(h);//唤醒后续节点
            return true;
        }
        return false;
    }
```

#### tryRelease()

子类实现的模板方法，在介绍`ReentrantLock`时会分析内部实现

#### unparkSuccessor()

`tryRelease()`解锁成功后，执行该方法

```java
private void unparkSuccessor(Node node) {
       //获取当前节点的等待状态
        int ws = node.waitStatus;
        if (ws < 0)
          //小于0 ，则重置为0
            compareAndSetWaitStatus(node, ws, 0);

        Node s = node.next;
        if (s == null || s.waitStatus > 0) {//节点不存在或被取消
            s = null;
           //唤醒后续节点,如果还存在挂起的节点
            for (Node t = tail; t != null && t != node; t = t.prev)//等待队列从后往前遍历
                if (t.waitStatus <= 0)
                    s = t;
        }
        if (s != null)
          //取消对应线程的挂起状态
            LockSupport.unpark(s.thread);
    }
```

如果不存在后续节点或后续节点被取消，就会从`AQS等待队列`的末尾从后往前遍历，就是为了**避免找不到节点的情况**，有可能在构造节点时，尚未构造`next`的值，导致无法继续向后遍历，但是向前的话一开始节点构造时就会设置`prev`节点数据。

找到了需要被唤醒的节点(`waitStatus == SIGNAL(-1)`)后，执行`LockSupport.unpark()`唤醒节点对应线程。

#### acquireQueued()

上面的方法执行到`LockSupport.unpark()`后，就会唤醒对应的线程

```java
 private final boolean parkAndCheckInterrupt() {
        LockSupport.park(this);//当前线程被挂起
        return Thread.interrupted();//返回中断标记并对当前线程进行复位
    }

 final boolean acquireQueued(final Node node, int arg) {
        boolean failed = true;
        try {
            boolean interrupted = false;
            for (;;) {
                final Node p = node.predecessor();//获取前一个节点
              //前一个节点是 head，再尝试获取一次锁  
              if (p == head && tryAcquire(arg)) {
                    setHead(node);//获取资源后，设置当前节点为头节点
                    p.next = null; // 原先头节点置为null，移出等待队列
                    failed = false;
                    return interrupted;
                }
              //获取锁失败了，就将自己挂起进入`waiting`状态，直到`unpark`调用
                if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                    interrupted = true;
            }
        } finally {
            if (failed)
                cancelAcquire(node);
        }
    }
```

此时`parkAndCheckInterrupt()`会继续执行，代码执行回到`acquireQueued()`的for循环中

此时资源已被释放，后续线程执行`tryAcquire()`就会获取资源成功，向下执行到`setHead()`并跳出了当前的循环

```java
    private void setHead(Node node) {
        head = node;
        node.thread = null;
        node.prev = null;
    }
```

`setHead()`重置了一下`head`节点的属性，将当前节点置为了`head`节点，原先的就移出队列，等待回收。

`return interrupted`继续回到上层方法`acquire()`中，中断掉当前线程，`release()`执行完毕。

![AQS-独占模式-释放资源](/images/AQS-独占模式-释放资源.jpg)

> 简单文字描述AQS-资源释放过程
>
> 1. 通过`tryRelease()`释放资源，返回`true`表示资源已经被释放了，通知其他节点可以获取资源
> 2. 释放成功后，执行`unparkSuccessor()`取消其他线程的阻塞状态
> 3. 通过`从后往前遍历(入队列采用尾插法)`直到找到一个`有效节点(waitStatus<=0)`，在执行`LockSupport.unpark()`取消对应节点`thread`的阻塞状态



### 获取资源-共享模式

![AQS-共享模式-获取资源](/images/AQS-共享模式-获取资源.png)

获取共享资源的入口是`acquireShared()/acquireSharedInterruptibly()`

```java
    public final void acquireShared(int arg) {
        if (tryAcquireShared(arg) < 0)
            doAcquireShared(arg);
    }

    public final void acquireSharedInterruptibly(int arg)
            throws InterruptedException {
        if (Thread.interrupted())
            throw new InterruptedException();
        if (tryAcquireShared(arg) < 0)
            doAcquireSharedInterruptibly(arg);
    }
```

其中`acquireShared()`和`acquireSharedInterruptibly()`的区别在于后者可以**响应中断**，请求线程被中断时，就会抛出异常结束请求。

#### tryAcquireShared()

子类实现的模板方法，在介绍`CountdownLatch`时会分析内部实现

#### doAcquireShared()

只有在`tryAcquireShared()`返回值小于0(`获取共享资源失败`)时执行，`tryAcquireShared()`有三种返回结果：

- `小于0`：获取共享资源失败
- `等于0`：获取共享资源成功，但后续节点无法获取共享资源
- `大于0`：获取共享资源成功，后续节点也可能继续获取共享资源。*需要检查后续节点请求的可用性*

```java
    private void doAcquireShared(int arg) {
        final Node node = addWaiter(Node.SHARED);//添加共享节点
        boolean failed = true;//判断是否需要取消节点
        try {
            boolean interrupted = false;
            for (;;) {
                final Node p = node.predecessor();//获取前一个节点
                if (p == head) {
                    int r = tryAcquireShared(arg);//再次尝试获取共享资源
                    if (r >= 0) {//请求共享资源成功
                        //设置当前节点为头节点，并尝试唤醒后续节点
                        setHeadAndPropagate(node, r);
                        p.next = null; // help GC
                        if (interrupted)
                            selfInterrupt();
                        failed = false;
                        return;
                    }
                }
                //是否需要阻塞当前节点请求
                if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                    interrupted = true;
            }
        } finally {
            if (failed)
                cancelAcquire(node);
        }
    }
```

获取共享资源失败后，先调用`addWaiter(Node.SHARED)`添加共享节点到等待队列，在循环中不断判断`preNode == head`，如果符合继续尝试获取共享资源，若获取成功，执行`setHeadAndPropagate()`去设置头节点并唤醒后续节点；获取失败，则当前线程判断是否需要挂起(`preNode.waitStatus == Node.SIGNAL(-1)`)，需要挂起执行`LockSupport.park()`。

#### setHeadAndPropagate()

获取到共享资源后调用该方法，主要的作用是`设置当前节点为头节点，同时唤醒后续节点`

```java
    private void setHeadAndPropagate(Node node, int propagate) {
        Node h = head; // Record old head for check below
        setHead(node);//设置头节点
        
        if (propagate > 0 //后续节点可以获取资源
            || h == null || h.waitStatus < 0 ||
            (h = head) == null || h.waitStatus < 0) { //后续的节点可以被唤醒
            Node s = node.next;
            if (s == null || s.isShared())//后续节点为共享状态
                doReleaseShared();//释放共享资源
        }
    }
```

`propagate > 0`是`tryAcquireShared()`的返回值，`>0`表示后续节点可以继续获取资源

`waitStatus < 0`此时存在两种情况

- `waitStatus == SIGNAL(-1)`下一个节点可以被唤醒
- `waitStatus == PROPAGATE(-3)`继续传播状态



#### doReleaseShared()

获取共享资源后且`tryAcquireShared()> 0 `表示后续节点也可以获取资源，并且`waitStatus < 0 即 -1`可以唤醒后续等待的线程

```java
    private void doReleaseShared() {
        for (;;) {
            Node h = head;
            //等待队列已初始化
            if (h != null && h != tail) {//队列至少存在了2个节点
                int ws = h.waitStatus;
                if (ws == Node.SIGNAL) {//后续线程可以被唤醒
                    if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                        continue;            // loop to recheck cases
                    unparkSuccessor(h);//唤醒后续节点
                }
                else if (ws == 0 &&
                         !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))//当前节点为最后一个节点，将唤醒状态继续向下传播
                    continue;                // loop on failed CAS
            }
            //头节点没有发生变化，直接结束当前循环
            if (h == head)                   // loop if head changed
                break;
        }
    }
```

在等待队列存在后续线程的情况下，继续唤醒后续线程(`unparkSuccessor()`)。或者由于多个线程同时释放，导致`head.waitStatus==0`，需要设置`waitStatus`为`PROPAGATE`将唤醒状态继续向下传递，保证后续其他线程执行`setHeadAndPropagate()`时可以继续释放等待线程。

![AQS-获取共享锁](/images/AQS-获取共享锁.jpg)

> 简单文字描述AQS-获取共享资源
>
> 1. 通过`tryAcquireShared()`尝试获取资源
> 2. 若`tryAcquireShared()`返回值`<0`表示获取资源失败，向下继续调用`doAcquireShared()`
> 3. 请求入队列执行`addWaiter(Node.SHARED)`，操作步骤同`AQS获取资源过程`
> 4. 请求入队列后，需要不断去获取资源
>    1. 不断获取当前节点的上一个节点是否为`head`，若是，则表示当前节点为`请求节点`
>    2. 若是`请求节点`，不断调用`tryAcquireShared()`继续获取共享资源
>       - 获取成功，执行`setHeadAndPropagate()`去设置头节点，并且唤醒后续节点——`doReleaseShared()`
>       - 获取失败，执行`LockSupport.unpark()`挂起当前线程



### 释放资源-共享模式

![AQS-共享模式-释放资源](/images/AQS-共享模式-释放资源.png)

释放共享资源的入口是`releaseShared()`

```java
    public final boolean releaseShared(int arg) {
        if (tryReleaseShared(arg)) {
            doReleaseShared();
            return true;
        }
        return false;
    }
```

#### tryReleaseShared()

子类实现的模板方法，在介绍`CountdownLatch`时会分析内部实现

#### doReleaseShared()

参考 [doReleaseShared](#doReleaseShared)

### Condition

{%post_link Java-AQS-Condition原理及解析%}

## 总结

1. AQS到底是什么？

   > `AQS`内部维护一个`CLH队列(FIFO)`来管理锁，将`当前线程(thread)以及等待状态信息(waitStatus)`封装成一个`Node节点`添加到`等待队列`中。
   >
   > 提供了`tryAcquire(),tryRelease(),tryAcquireShared(),tryReleaseShare()`等模板方法交由子类实现，去控制`资源的获取与释放`。
   >
   > `AQS`默认实现子类获取/释放资源后的操作，包括`Node节点的出入队列`。

2. AQS获取资源失败的操作

   > 线程尝试获取锁失败后，，将`当前线程(thread)以及等待状态信息(waitStatus)`封装成一个`Node节点`添加到`等待队列`中。接着会不断循环尝试获取锁(`前置节点为head`)，如果不是进入阻塞状态，直至被唤醒。

3. AQS等待队列数据结构

   > `CLH队列`：
   >
   > - CLH锁是一个自旋锁，可以保证无饥饿性，提供`FIFO`的公平性。基于链表实现。
   > - 不断轮询`前置节点`的状态，如果前置节点被释放就结束自旋。
   
4. AQS等待队列插入节点顺序

   > **尾插法**
   >
   > `addWaiter(node)`就是插入节点的主方法
   >
   > ```java
   >     private Node addWaiter(Node mode) {
   >         Node node = new Node(Thread.currentThread(), mode);
   >         // Try the fast path of enq; backup to full enq on failure
   >         Node pred = tail;
   >         if (pred != null) {
   >             node.prev = pred;//node.prev = tail
   >             if (compareAndSetTail(pred, node)) { //tail = node 大致如此
   >                 pred.next = node;
   >                 return node;
   >             }
   >         }
   >         enq(node);
   >         return node;
   >     }
   > ```
   >
   > 先执行的是`node.prev = pred(实际为tail)`，然后再是CAS操作，这是由于**CAS在执行过程中可能存在一瞬间的需要替换的值为null**，会使得一瞬间的队列数据不一致。

## 参考链接

[JUC必知ReentrantLock和AQS同步队列实现原理分析](https://juejin.im/post/6878135436561088520#heading-28)

[AbstractQueuedSynchronizer源码解读](https://www.cnblogs.com/micrari/p/6937995.html)

