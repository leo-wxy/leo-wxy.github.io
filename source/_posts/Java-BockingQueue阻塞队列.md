---
title: Java-BockingQueue阻塞队列
date: 2018-12-24 15:16:57
tags: Java
top: 9
typora-root-url: ../
---

![BlockingQueue阻塞队列](/images/BlockingQueue 阻塞队列xmind.png)

## Queue接口

`Queue队列`的特征是`FIFO——先进先出`。只有队尾可以进行插入操作，只有队头可以进行删除操作。

![img](/images/822721-20200318104019498-382557009.png)



Java中的`Queue`继承了`Collection`接口，并额外实现了以下方法

```java
public interface Queue<E> extends Collection<E> {
  boolean add(E e); 
  boolean offer(E e);
  E remove();
  E poll();
  E element();
  E peek();
}
```



### 队列插入数据操作(`add/offer`)

> 将新数据插入队尾

`add`：如果队列满时，插入队尾数据，就会抛出`IllegalStateExecption`

`offer`：如果队列满时，插入队尾数据，不会抛出异常，会返回`false`

### 队列删除数据操作(`remove/poll`)

> 获取队头元素并删除

`remove`：当队列为空时，删除元素时，会抛出`NoSuchElementException`

`poll`：当队列为空时，删除元素时，不会抛出异常，只会返回`null`

### 队列检查数据操作(`element/peek`)

> 获取队头元素但并不删除

`element`：当队列为空时，获取队头元素，会抛出`NoSuchElementException`

`peek`：当队列为空时，获取队头元素，不会抛出异常，只会返回`null`



|                | 抛出异常    | 特殊值                 |
| -------------- | ----------- | ---------------------- |
| 插入           | `add()`     | `offer()` 返回 `false` |
| 删除           | `remove()`  | `poll()` 返回`null`    |
| 获取数据(检查) | `element()` | `peek()` 返回`null`    |



## BlockingQueue接口

**系统提供的用于多线程环境下存、取共享变量的一种容器。**

`BlockingQueue阻塞队列`实现了`Queue接口`，相比于`Queue`提供了额外的功能：

- 获取队头元素时，如果队列为空，执行线程会处于阻塞状态，直到队列非空——`对应删除和检查操作`
- 添加队尾元素时，如果队列已满，执行线程会处于阻塞状态，直到队列不满——`对应插入操作`

当触发上述两种情况的出现时，按照不同的设置方式，提供了以下几种处理方案：

- 抛出异常
- 返回特殊值(返回`null`或`false`)
- 阻塞当前线程直到可以执行
- 阻塞线程设置最大超时时间，若超过该时间，线程就会继续执行，放弃当次操作



### 阻塞队列插入数据操作(`put/offer(time)`)

> 对应阻塞队列在队列已满插入数据时的`阻塞`或者`超时处理`

`put`：如果队列满时，插入队尾数据，会阻塞当前线程`直到队列非满`

`offer(time)`：如果队列满时，插入队尾数据，会阻塞当前线程`直到队列非满或者达到了超时时间`,达到超时时间则返回`false`

### 阻塞队列删除数据操作(`take()/poll(time)`)

> 对应阻塞队列在队列为空时获取数据时的`阻塞`或`超时处理`

`take()`：当队列为空时，删除元素时，会阻塞当前线程`直到队列非空`

`poll(time)`：当队列为空时，删除元素时，会阻塞当前线程`直到队列非空或者达到了超时时间`，达到超时时间返回`null`



### ~~阻塞队列检查数据操作~~



|                | 抛出异常    | 特殊值                 | 阻塞     | 超时                     |
| -------------- | ----------- | ---------------------- | -------- | ------------------------ |
| 插入           | `add()`     | `offer()` 返回 `false` | `put()`  | `offer(time)`返回`false` |
| 删除           | `remove()`  | `poll()` 返回`null`    | `take()` | `poll(time)`返回`null`   |
| 获取数据(检查) | `element()` | `peek()` 返回`null`    | /        | /                        |



### 注意点

1. 阻塞队列无法插入`null`，否则抛出空指针异常
2. 可以访问阻塞队列中的任意元素，尽量避免使用`remove(object)`移除对象



## `BlockingQueue`实现类

在{% post_link Java-线程池%}中的`workQueue`设置的就是`BlockingQueue`接口的实现类，

例如

- `ArrayBlockingQueue`：数组构成的有界阻塞队列
- `LinkedBlockingQueue`：链表构成的有界阻塞队列，如果不设置大小的话，近似`无界阻塞队列`
- `SynchronousQueue`：不存储任何元素的阻塞队列
- `PriorityBlockingQueue`：支持优先级排序的无界阻塞队列




## `BlockingQueue`原理

`BlockingQueue`只是一个接口，真正的实现都是在`XXBloxckingQueue`中的，想要分析对应的原理就需要从实现类进行分析



#### `ArrayBlockingQueue`

> 由数组实现的有界阻塞队列，大小一旦确定就无法改变队列的长度。

##### 关键成员变量

```java
    /** The queued items 维护队列元素的数组*/
    final Object[] items; 

    /** items index for next take, poll, peek or remove 移除数据的数组下标*/
    int takeIndex;

    /** items index for next put, offer, or add 插入数据的数组下标*/
    int putIndex;

    /** Number of elements in the queue 数组长度*/
    int count;

    /** Main lock guarding all access 数据并发控制类*/
    final ReentrantLock lock;

    /** Condition for waiting takes 控制take操作是否让线程等待*/
    private final Condition notEmpty;

    /** Condition for waiting puts 控制put操作是否让线程等待*/
    private final Condition notFull;
```

`ArrayBlockingQueue`阻塞功能的实现就是依赖了`ReentrantLock`以及`Condition`实现了`等待机制`。

具体可参考{% post_link Java-ReentrantLock原理及解析%}

##### 构造函数

```java
public ArrayBlockingQueue(int capacity) {
        this(capacity, false);
    }    

public ArrayBlockingQueue(int capacity, boolean fair) {
        if (capacity <= 0)
            throw new IllegalArgumentException();
        this.items = new Object[capacity];
        lock = new ReentrantLock(fair);
        notEmpty = lock.newCondition();
        notFull =  lock.newCondition();
    }
```

`capacity`：设置阻塞队列的数组容量

`fair`：设置线程并发是否公平(`默认配置非公平锁`)

> 当前锁被一个线程持有时，其他线程会被挂起等待锁的释放，等待时加入等待队列。
>
> `公平锁`：当锁释放时，等待队列的前端线程会优先获取锁
>
> `非公平锁`：当锁释放时，等待队列中的所有线程都会去尝试获取锁

在`ArrayBlockingQueue`初始化时，构造`ReentrantLock`锁以及两个`Condition`对象控制数据插入、删除时的阻塞。

##### 实现方法

`offer()` 非阻塞添加数据

```java
 public boolean offer(E e) {
        Objects.requireNonNull(e);//检查将要添加的数据是否为null
        final ReentrantLock lock = this.lock;
        lock.lock();//上锁
        try {
            if (count == items.length)//队列已满
                return false;
            else {
                enqueue(e);//数据加入队列
                return true;
            }
        } finally {
            lock.unlock();//解锁
        }
    }

//数据入队
    private void enqueue(E x) {
        // assert lock.getHoldCount() == 1;
        // assert items[putIndex] == null;
        final Object[] items = this.items;
        items[putIndex] = x;//数组赋值
        //如果此时放入的是最后一个下标的数据，重置下标为0，下一次从第一个开始放元素
        if (++putIndex == items.length) putIndex = 0;
        count++;
        notEmpty.signal();//通知 数组非空 
    }
```

`offer()`添加数据时，将当前线程上锁。

- 在当前队列已满时，直接返回`false`
- 当前队列未满时，调用`enqueue()`添加数据，`putIndex`设置对应数据且`putIndex++`。 然后通知阻塞的消费线程`notEmpty`



`poll()` 非阻塞取出数据

```java
    public E poll() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return (count == 0) ? null : dequeue();//当前队列非空 取出数据
        } finally {
            lock.unlock();
        }
    }

    private E dequeue() {
        // assert lock.getHoldCount() == 1;
        // assert items[takeIndex] != null;
        final Object[] items = this.items;
        @SuppressWarnings("unchecked")
        E x = (E) items[takeIndex];
        items[takeIndex] = null;
        //如果此时取出的是最后一个下标的数据，重置下标为0，下一次从第一个开始取出元素
        if (++takeIndex == items.length) takeIndex = 0;
        count--;
        if (itrs != null)
            itrs.elementDequeued();//数据迭代减少，保证遍历线程安全
        notFull.signal();//通知 数组不满
        return x;
    }
```

`poll()`取出数据时，将当前线程上锁

- 当前队列为空的时候，直接返回null
- 当前队列非空的时候，调用`dequeue()`将`takeIndex`元素出队，设置`takeIndex`处元素为`null`且`takeIndex--`。然后通知阻塞的生产线程`notFull`



`offer(time)`不超时阻塞添加数据

```java
    public boolean offer(E e, long timeout, TimeUnit unit)
        throws InterruptedException {

        Objects.requireNonNull(e);
        long nanos = unit.toNanos(timeout);
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        try {
            while (count == items.length) {
                if (nanos <= 0L)
                    return false;
                nanos = notFull.awaitNanos(nanos);
            }
            enqueue(e);
            return true;
        } finally {
            lock.unlock();
        }
    }
```

`offer(time)`添加数据时，将当前线程上锁

- 在当前队列已满时，阻塞生产线程`notFull`，超过`time`后，队列还是满的话，直接返回`false`
- 当前队列未满时，调用`enqueue()`添加数据，`putIndex`设置对应数据且`putIndex++`。 然后通知阻塞的消费者`notEmpty`



`poll(time)`不超时阻塞取出数据

```java
    public E poll(long timeout, TimeUnit unit) throws InterruptedException {
        long nanos = unit.toNanos(timeout);
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        try {
            while (count == 0) {
                if (nanos <= 0L)
                    return null;
                nanos = notEmpty.awaitNanos(nanos);
            }
            return dequeue();
        } finally {
            lock.unlock();
        }
    }
```

`poll(time)`取出数据时，将当前线程上锁

- 当前队列为空的时候，阻塞消费线程`notEmpty`，超过`time`后，队列还是空的话，直接返回`null`
- 当前队列非空的时候，调用`dequeue()`将`takeIndex`元素出队，设置`takeIndex`处元素为`null`且`takeIndex--`。然后通知阻塞的生产者`notFull`



###### `put()`阻塞添加数据

```java
    public void put(E e) throws InterruptedException {
        Objects.requireNonNull(e);
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();//生产者线程上锁
        try {
            while (count == items.length)
                notFull.await();//等待消费者线程通知
            enqueue(e);
        } finally {
            lock.unlock();
        }
    }
```

`put()`添加数据时

- 当前队列已满时，阻塞当前线程，等待`notFull`通知(`队列未满`)
- 当前队列未满时，调用`enqueue()`添加数据，`putIndex`设置对应数据且`putIndex++`。 然后通知阻塞的消费者`notEmpty`



###### `take()`阻塞获取数据

```java
    public E take() throws InterruptedException {
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();//消费者线程上锁
        try {
            while (count == 0)
                notEmpty.await();//等待生产者线程通知
            return dequeue();
        } finally {
            lock.unlock();
        }
    }
```

`take()`获取数据时

- 当前队列为空时，阻塞当前线程，等待`notEmpty`通知(`队列新增数据`)
- 当前队列非空的时候，调用`dequeue()`将`takeIndex`元素出队，设置`takeIndex`处元素为`null`且`takeIndex--`。然后通知阻塞的生产者`notFull`



其中`Condition`的`await/signal`类似于`Object`的`wait/notify`实现等待与通知的功能。

在分析`enqueue()`和`dequeue()`时，发现底层数组不会进行扩容，而是在到达边缘时，重置`index`为0，重复利用数组。

![ArrayBlockingQueue循环数组](/images/ArrayBlockingQueue循环数组.jpg)

从上述源码对`ArrayBlockingQueue`进行总结：

**底层数据结构是一个 数组，生产者和消费者由同一个锁(`ReetrantLock`)控制，生产和消费效率低。**



#### LinkedBlockingQueue

> 由链表实现的阻塞队列，默认最大长度为`Integer.MAX`。

##### 关键成员变量

```java
    /** The capacity bound, or Integer.MAX_VALUE if none 链表最大长度*/
    private final int capacity;

    /** Current number of elements 当前元素个数*/
    private final AtomicInteger count = new AtomicInteger();

    /**
     * Head of linked list.
     * Invariant: head.item == null
     * 链表头节点
     */
    transient Node<E> head;

    /**
     * Tail of linked list.
     * Invariant: last.next == null
     * 链表尾节点
     */
    private transient Node<E> last;

    /** Lock held by take, poll, etc 控制消费并发*/
    private final ReentrantLock takeLock = new ReentrantLock();

    /** Wait queue for waiting takes 控制take线程等待 非空条件*/
    private final Condition notEmpty = takeLock.newCondition();

    /** Lock held by put, offer, etc 控制生产并发*/
    private final ReentrantLock putLock = new ReentrantLock();

    /** Wait queue for waiting puts 控制put线程等待 非满条件*/
    private final Condition notFull = putLock.newCondition();
```

`LinkedBlockingQueue`采用了两把锁`putLock、takeLock`，分别进行控制，提高了并发性能。

##### 构造函数

```java
    public LinkedBlockingQueue() {
        this(Integer.MAX_VALUE);
    }

    public LinkedBlockingQueue(int capacity) {
        if (capacity <= 0) throw new IllegalArgumentException();
        this.capacity = capacity;
        last = head = new Node<E>(null);
    }
```

`capacity`：设置单链表长度上限，若不设置该值，默认为`Integer.MAX`

构造函数初始化了底层的链表结构。

##### 实现方法

`offer()`非阻塞添加数据

```java
    public boolean offer(E e) {
        if (e == null) throw new NullPointerException();
        final AtomicInteger count = this.count;
        if (count.get() == capacity) //达到上限直接返回false
            return false;
        int c = -1;
        Node<E> node = new Node<E>(e);
        final ReentrantLock putLock = this.putLock;
        putLock.lock();//线程上锁
        try {
            if (count.get() < capacity) {
                enqueue(node);//插入链表
                c = count.getAndIncrement();
                if (c + 1 < capacity)
                    notFull.signal();//唤醒 等待的入队线程
            }
        } finally {
            putLock.unlock();
        }
        if (c == 0)
            signalNotEmpty();//唤醒等待的 出队线程
        return c >= 0;
    }

    private void enqueue(Node<E> node) {
        // assert putLock.isHeldByCurrentThread();
        // assert last.next == null;
        last = last.next = node;//赋值操作
    }
```

`offer`添加数据时，当队列已满时，直接返回`false`。未满时，插入新数据后，`count`自加后唤醒`notFull、notEmpty`。

`poll()`非阻塞获取数据

```java
    public E poll() {
        final AtomicInteger count = this.count;
        if (count.get() == 0)
            return null;//队列为空返回null
        E x = null;
        int c = -1;
        final ReentrantLock takeLock = this.takeLock;
        takeLock.lock();
        try {
            if (count.get() > 0) {
                x = dequeue();//出队
                c = count.getAndDecrement();
                if (c > 1)
                    notEmpty.signal();//通知非空线程
            }
        } finally {
            takeLock.unlock();
        }
        if (c == capacity)
            signalNotFull();//通知非满线程
        return x;
    }

    private E dequeue() {
        // assert takeLock.isHeldByCurrentThread();
        // assert head.item == null;
        Node<E> h = head;
        Node<E> first = h.next;
        h.next = h; // help GC
        head = first;
        E x = first.item;
        first.item = null;
        return x;
    }
```

`poll`获取数据时，队列为空时，直接返回`null`。队列非空时，获取数据后，数据出队，`count`自减后，先后唤醒`notEmpty`、`notFull`。



###### `put()`阻塞添加数据

```java
    public void put(E e) throws InterruptedException {
        if (e == null) throw new NullPointerException();
        // Note: convention in all put/take/etc is to preset local var
        // holding count negative to indicate failure unless set.
        int c = -1;
        Node<E> node = new Node<E>(e);
        final ReentrantLock putLock = this.putLock;
        final AtomicInteger count = this.count;
        putLock.lockInterruptibly();
        try {
            while (count.get() == capacity) {
                notFull.await();//队列已满时，等待非满通知
            }
            enqueue(node);//插入新数据
            c = count.getAndIncrement();//数据自增
            if (c + 1 < capacity)
                notFull.signal();//通知非满线程
        } finally {
            putLock.unlock();
        }
        if (c == 0)
            signalNotEmpty();//通知非空线程
    }
```

`put()`添加数据时，队列已满时，会进行阻塞等待直到队列非满。

###### `take()`阻塞获取数据

```java
    public E take() throws InterruptedException {
        E x;
        int c = -1;
        final AtomicInteger count = this.count;
        final ReentrantLock takeLock = this.takeLock;
        takeLock.lockInterruptibly();
        try {
            while (count.get() == 0) {
                notEmpty.await();//队列为空时，等待非空通知
            }
            x = dequeue();//出队
            c = count.getAndDecrement();
            if (c > 1)
                notEmpty.signal();//通知非空线程
        } finally {
            takeLock.unlock();
        }
        if (c == capacity)
            signalNotFull();//通知非满线程
        return x;
    }
```

`take()`获取数据时，队列为空时，会进行阻塞等到直到队列非空。

![img](/images/v2-8bc04760ad1133e7630717dbc38c1cc7_1440w.jpg)

从上述源码对`LinkedBlockingQueue`进行总结：

**`LinkedBlockingQueue`底层数据结构为`单链表`，内部持有两个`Lock：putLock、takeLock`，相互之间不会干扰执行，提高了并发性能。**

##### 与`ArrayBlockingQueue`比较

|              | ArrayBlockingQueue                               | LinkedBlockingQueue                                          |
| ------------ | ------------------------------------------------ | ------------------------------------------------------------ |
| 构造方法     | 必须指定构造大小<br>指定后无法修改               | 默认大小为`Integer.MAX`<br>可以指定大小                      |
| 底层数据结构 | 数组                                             | 单链表                                                       |
| 锁           | 出队入队使用同一把锁<br>数据的删除和添加操作互斥 | 出队使用`takeLock`，入队使用`putLock`<br>数据删除、添加操作不干扰，提升并发性能 |



#### SynchronousQueue

> 容量为0，无法储存数据的阻塞队列。提供了公平与非公平锁的设置。

##### 关键成员变量

```java
//针对不同操作定义的统一接口
private transient volatile Transferer<E> transferer;

    abstract static class Transferer<E> {
       //e为空则表示 需要获取数据；e不为空表示 需要添加数据
        abstract E transfer(E e, boolean timed, long nanos);
    }
```



##### 构造函数

```java
    public SynchronousQueue() {
        this(false);//默认非公平构造
    }

    public SynchronousQueue(boolean fair) {
        //公平与非公平对应两种实现形式
        transferer = fair ? new TransferQueue<E>() : new TransferStack<E>();
    }
```



##### 实现方法

数据操作`offer()/poll() put()/take()`

```java
    public boolean offer(E e) {
        if (e == null) throw new NullPointerException();
        return transferer.transfer(e, true, 0) != null;
    }

    public E poll() {
        return transferer.transfer(null, true, 0);
    }

    public void put(E e) throws InterruptedException {
        if (e == null) throw new NullPointerException();
        if (transferer.transfer(e, false, 0) == null) {
            Thread.interrupted();
            throw new InterruptedException();
        }
    }

    public E take() throws InterruptedException {
        E e = transferer.transfer(null, false, 0);
        if (e != null)
            return e;
        Thread.interrupted();
        throw new InterruptedException();
    }
```

上述的数据操作方法都涉及到了两部分内容：

- `transferer`：数据调度
- `transfer`：数据执行

###### TransferQueue

> `SynchronousQueue`的**公平**实现，内部实现使用队列，可以保证先进先出的特性。

基本实现方法：

当前队列为空的时候或者存在了与即将添加的`QNode`操作模式一致(`isData一致`)的节点，线程进行同步等待，`QNode`添加到队列中。

继续等待与队列头部`QNode`操作互补(`写操作(isData = true)，等待一个读操作(isData = false)`)的`QNode`节点

新添加的`QNode`节点与队头`QNode`操作互补时，尝试通过`CAS`更新等待节点的item字段，然后让队头等待节点出列，并返回节点元素和更新队头节点。

如果队列中的节点的`waiter`等待线程被取消，节点也会被清理出队列。

![TransferQueue公平队列](/images/TransferQueue.jpg)

`isData`：true 表示`put`操作，false表示`take`操作。

`next`：下一个节点

`waiter`：当前等待的线程

`item`：元素信息





###### TransferStack

> `SynchronousQueue`非公平实现，内部实现使用**栈**，实现了`先进后出`的特性。

基本实现方法：

当前栈为空或者存在了与即将添加的`SNode`模式相同的节点(`mode一致`)，线程进行同步等待，`SNode`添加到栈中

继续等待与栈顶`SNode`操作互补(`写操作(mode = DATA)，读操作(mode=REQUEST)`)的节点

出现与栈顶`SNode`操作互补的节点后，新增`SNode`节点的`mode`会变为`FULFILLING`，与栈顶节点匹配，匹配完成后，将俩节点都弹出并返回匹配节点的结果。

如果栈顶元素找到匹配节点，就会继续向下帮助匹配(`此时上一个匹配操作还没结束又进入一个新的请求`)



![TranferStack](/images/TransferStack.jpg)

`next`：下一个元素

`item`：元素信息

`waiter`：当前等待的线程

`match`：匹配的节点

`mode`：`DATA(1)`-添加数据、`REQUEST(0)`-获取数据、`FULFILLING(2)`-互补模式



##### 特点

- `SynchronousQueue`容量为0，无法进行数据存储
- 每次写入数据时，写线程都需要等待；直到另一个线程执行读操作，写线程会返回数据。*写入元素不能为null*
- `peek()`返回`null`；`size()`返回`0`；无法进行迭代操作
- 提供了`公平`，`非公平`两种策略处理，分别是基于`Queue-TransferQueue`与`Stack-TransferStack`实现。



#### 原理介绍

绝大多数都是利用了**Lock锁的多条件(Condition)阻塞控制**。

拿`ArrayBlockigQueue`进行简单描述就是：

1. `put`和`take`操作都需要先**获取锁**，无法获取的话就要一直自旋拿锁，直到获取锁为止
2. 在拿到锁以后。还需要判断当前队列是否可用(`队列非满且非空`)，如果队列不可用就会被阻塞，并**释放锁**
3. 阻塞的线程被唤醒时，依然需要在拿到锁之后才可以继续执行，否则，自旋拿锁，拿到锁继续判断当前队列是否可用(**使用while判断**)



## 使用场景

##### 生产-消费模型

```java
public class PCDemo {
    private int queueSize = 10;
    private ArrayBlockingQueue<Integer> queue = new ArrayBlockingQueue<Integer>(queueSize, true);

    public static void main(String[] args) {

        PCDemo blockQueue = new PCDemo();
        Producter producter = blockQueue.new Producter();
        Customer customer = blockQueue.new Customer();

        producter.start();
        customer.start();
    }

    class Customer extends Thread {
        @Override
        public void run() {
            while (true) {
                try {
                    queue.take();
                    System.err.println("消费哦，剩余空间为" + queue.size());
                    Thread.sleep(100);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }
    }

    class Producter extends Thread {
        @Override
        public void run() {
            while (true) {
                try {
                    queue.put(1);
                    System.err.println("生产哦，剩余空间为" + (queueSize - queue.size()));
                    Thread.sleep(100);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }
    }
}
```

##### 线程池

{% post_link Java-线程池%}

## 拓展知识

### Guarded Suspension（保护性暂时挂起）

**当服务进程准备好时，才提供服务。**

![img](/images/java-concurrent-guarded-suspension.png)

本质是一种**等待唤醒机制的实现**，也称为**多线程的if**

基本实现代码

```java
public class GuardedObject<T>{
  private T obj;
  private final ReetrantLock lock = new ReentrantLock();
  private final Condition done = lock.newCondition();
  
  public T get(Predicate<T> p){
    lock.lock();
    try{
      while(!p.test(obj)){
        done.await(); //等待事件执行
      }
    }catch(Exception e){
      e.printStacktrace();
    }finally{
      lock.unlock();
    }
    return obj;
  }
  
  public void onChange(T obj){
    lock.lock();
    try{
      this.obj = obj;
      done.signAll();//数据发生变化，进行通知
    }finally{
      lock.unlock();
    }
  }
}
```



## 参考链接

[SynchronousQueue-公平模式](https://www.cnblogs.com/dwlsxj/archive/2004/01/13/Thread.html)

[SynchronousQueue](https://www.jianshu.com/p/a565b0b25c43)

