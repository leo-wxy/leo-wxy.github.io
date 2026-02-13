---
title: Java线程相关合集整理
date: 2020-05-02 10:15:01
tags: Java
top: 11
---

## 基础概念

### 进程

> 应用程序在内存中分配的空间，也就是正在运行的程序。进程是系统运行程序的基本单位。

CPU采用`时间片轮转`的方式运行进程：CPU为每个进程分配一个时间段，称作它的时间片。

如果在这个时间片结束进程还在进行，则暂停这个进程的运行，并且CPU会被分配到另一个进程(**上下文切换**)。

进程让操作系统的并发成为了可能。`进程就是程序的实体`。

### 线程

> 线程与进程类似，但线程比进程更小，是CPU调度和分配的基本单位。一个进程在其执行的过程中可以产生多个线程。

线程让进程内部并发成为了可能。

#### 与进程的区别

- `进程`是一个独立的运行环境，线程只是在进程中执行的一个任务。本质区别是**是否单独占有内存地址空间和其他系统资源。**
- `进程`间存在内存隔离，数据是分开的，数据共享复杂但是同步简单，各个进程之间互相不干扰；`线程`共享进程的数据，同步复杂。
- `进程`崩溃不会影响其他进程，不会影响主进程的稳定性；线程崩溃影响整个进程的稳定性，可靠性较低。
- `进程`创建和销毁需要保存`寄存器和栈信息`，还需要资源的回收和调度，开销较大；`线程`只需要保存`寄存器和栈信息`，开销较小。

### 多进程

> 每个进程拥有独立的资源，每个进程在单核处理器并发执行，在多核处理器并行执行。

### 多线程

> 一个进程可以包含多个线程，多个线程共享进程资源。可以合理利用CPU资源。

相比于`多进程`有如下好处：

- 进程间通信比较复杂，线程间的通信相对简单，通常情况下，进程共享资源的使用比较简单。
- 进程是重量级的，线程是轻量级的，系统开销更小。

### 并发

> 同一时间段，多个任务都在执行。`多个任务交替执行，也可能串行执行。`

### 并行

> 同一时间段，多个任务同时执行，只有多核处理器可以做到。



### 上下文切换

> CPU从一个进程(线程)切换到另一个进程(线程)，需要先存储当前进程(线程)的状态，然后载入另一个进程(线程)的数据，然后开始执行另一个进程(线程)。
>
> `上下文`指的就是切换时需要保存的数据，例如**本地数据，程序指针等**。

CPU通过为每个线程分配CPU时间片来实现多线程机制。CPU通过时间片分配算法来循环执行任务，当前任务执行完一个时间片后切换到下一个任务。*如果线程在时间片结束前阻塞或结束，则CPU立即进行切换。*

`上下文切换`通常是`计算密集型`的，意味着**消耗大量的CPU时间，线程越多造成的压力越大。**

#### 计算机密集型(CPU密集型)

> 进行大量的计算，消耗CPU资源。

#### IO密集型

> 涉及到网络、磁盘IO的任务较多，CPU消耗较少。





## 线程相关

### 使用线程

#### 继承Thread类

```Java
public class ThreadTest extends Thread{
    public void run(){
        System.out.println("Hello Thread");
    }
    
    public static void main(String[] args){
        Thread thread = new ThreadTest();
        thread.start();
    }
}
```

**调用`start()`后线程才算启动。**如果只调用`run()`就是普通的方法调用。

> 调用了`start()`后，虚拟机会先创建一个线程，当线程获取`时间片`后再调用`run()`。
>
> **不可多次调用`start()`，否则后续调用会抛出异常`java.lang.IllegalThreadStateException`。**

#### 实现Runnable接口

```java
public class MyRunnable implements Runnable {
    @Override
    public void run() {
        // ...
    }
}

public static void main(String[] args) {
    MyRunnable instance = new MyRunnable();
    Thread thread = new Thread(instance);
    thread.start();
}
```

调用`start()`后线程才算启动。

#### 实现Callable接口

> 需要重写`call()`并配合`Future`或`FutureTask`使用。

```java
class Task implements Callable<Integer>{
    @Override
    public Integer call() throws Exception {
        // 模拟计算需要一秒
        Thread.sleep(1000);
        return 2;
    }
    public static void main(String args[]){
        // 使用
        ExecutorService executor = Executors.newCachedThreadPool();
        Task task = new Task();
        Future<Integer> result = executor.submit(task);
        // 注意调用get方法会阻塞当前线程，直到得到结果。
        // 所以实际编码中建议使用可以设置超时时间的重载get方法。
        System.out.println(result.get()); 
    }
}
```

`Callable`一般配合`ExecutorService`来使用的，可以返回`call()`结果。



##### Future接口

```java
public interface Future<V> {
    //试图取消任务的执行。mayInterruptIfRunning确定是否应该以试图停止任务的方式中断执行任务流程。true 直接中断 false等待执行完成 
    boolean cancel(boolean mayInterruptIfRunning);
    //任务正常完成前将其取消，返回true
    boolean isCancelled();
    //任务已完成或者因为正常终止、异常，取消而完成，返回true
    boolean isDone();
    //等待计算结果的返回，如果被取消则抛出异常
    V get() throws InterruptedException, ExecutionException;
    //设定执行时间，超过时间则抛出Timeout异常
    V get(long timeout, TimeUnit unit)
        throws InterruptedException, ExecutionException, TimeoutException;
}
```

通过`Callable`可以得到一个`Future`对象，表示异步计算的结果。

##### FutureTask

```java
public interface RunnableFuture<V> extends Runnable, Future<V> {
    /**
     * Sets this Future to the result of its computation
     * unless it has been cancelled.
     */
    void run();
}
```

`FutureTask`实现了`RunnableFuture`接口，`FutureTask`可以简化使用。

| 方式             | 优点                                                         | 缺点                                                         |
| ---------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 继承Thread类     | 编写简单，可以使用`this`直接访问当前线程                     | 1.受限于Java类的单继承，无法继承其他类；<br>2.多个线程之间无法共享方法或实例变量 |
| 实现Runnable接口 | 多个线程可共享一个实现了`Runnable`接口的类，非常适合多个线程处理同一任务 | 1.`run()`没有返回值<br/>2.不能直接捕获运行过程中的异常，需要使用`setDefaultUncaughtExceptionHandler()`捕获子线程的异常 |
| 实现Callable接口 | 多个线程可共享一个实现了`Callable`接口的类，非常适合多个线程处理同一任务；可以有返回值；可以抛出异常 | 编写略微复杂，要访问当前线程需要使用`Thread.currentThread()` |

### 线程状态

{% fullimage /images/Thread-State.png,线程状态,线程状态%}

如上图所示，线程共有6种状态

#### NEW(新建状态)

线程此时尚未启动，还未调用`Thread.start()`

> 反复调用`start()`会抛出`IllegalThreadStateException`，就算线程执行完毕，进入`Terminated`状态，也无法调用`start()`重新启动线程。
>
> ```java
> public synchronized void start() {
>   //第一次start之后，threadStatus不为0，后续再次调用出错
>     if (threadStatus != 0)
>         throw new IllegalThreadStateException();
> 
>     group.add(this);
> 
>     boolean started = false;
>     try {
>         start0();
>         started = true;
>     } finally {
>         try {
>             if (!started) {
>                 group.threadStartFailed(this);
>             }
>         } catch (Throwable ignore) {
> 
>         }
>     }
> }
> ```

#### RUNNABLE(可运行状态)

当前线程正在运行中，也可能等待其他系统资源(IO资源)，资源调度完成就进入运行状态。

**可以被运行，无法知道是否正在运行。**

包含`Ready`和`running`两个状态。



#### BLOCKED(阻塞状态)

当前线程被阻塞，等待其他线程释放锁(`monitor lock`)，暂时不能运行。



#### WAITING(无限期等待状态)

当前线程处于等待状态，需要其他线程显式唤醒。

与`BLOCKED`的区别在于，`阻塞`是被动的，`等待`是主动的。

调用如下方法可以进入`WAITING`状态

| 进入`WAITING`状态  | 退出`WAITING`状态                  |
| ------------------ | ---------------------------------- |
| Object.wait()      | Object.notify()/Object.notifyAll() |
| Thread.join()      | 被调用的线程执行完毕               |
| LockSupport.park() | LockSupport.unpark(thread)         |



#### TIMED_WAITING(超时等待状态)

当前线程等待一个具体时间，时间到后会被系统自动唤醒。

与`WAITING`的区别在于，`TIMED_WAITING`是有限时间的等待。

调用如下方法可以进入`TIMED_WAITING`状态

| 进入`TIMED_WAITING`状态              | 退出`TIMED_WAITING`状态                           |
| ------------------------------------ | ------------------------------------------------- |
| Thread.sleep(long mills)             | 时间结束                                          |
| Object.wait(long timeout)            | 时间结束<br>Object.notify()<br>Object.notifyAll() |
| Thread.join(long mills)              | 时间结束<br>调用线程执行完毕                      |
| LockSupport.parkNanos(long nanos)    | LockSupport.unpark(thread)                        |
| LockSupport.parkUntil(long deadline) | LockSupport.unpark(thread)                        |



#### TERMINATED(终止状态)

当前线程已经中止，可能是任务执行完毕或者发生了异常导致运行结束。



### 线程常见方法

#### `start`

线程启动，表示线程进入`RUNNABLE`状态，等待CPU时间片分配可以执行

#### `run`

只是调用线程中的执行代码

#### `join`

在线程中调用另一个线程的`join()`，会将当前线程挂起，而不是忙等待，直到目标线程结束。

`join(long)`设置等待时间

#### `sleep(long mills)`

主动放弃占用的CPU资源，进入`BLOCKED`状态，并进入休眠状态`mills`毫秒。当超过`mills`后，线程就会进入`RUNNABLE`状态，等待执行。

#### `yield()`

主动放弃占用的CPU资源，进入`RUNNABLE`状态，等待CPU时间片。

**建议让步给它优先级比它高或者相同的待运行(`RUNNABLE`)的线程运行。放弃的时间不确定，可能会自己获取CPU时间片继续执行任务。**

#### `interrupte()/interrupted()/isInterrupted()`

`interrupt()`：中断线程，不会立即停止线程，设置线程中断状态为`true`

如果该线程处于`BLOCKED、WAITING、TIMED_WAITING`状态，执行`interrupt()`会抛出`InterruptException`异常。

`interrupted()`：测试当前线程是否中断，线程的中断状态受到这个方法的影响。例如调用一次设置中断状态为`true`，设置两次为`false`。线程会去检测中断位，判断线程是否中断。

`isInterrupted()`：测试当前线程是否中断，调用这个方法不会影响线程中断状态。

> 线程中断只是设置线程中断状态为`true`，具体线程何时中断，由线程自己而定，可能不会发生中断。

#### `setPriority()`

设置线程的优先级。**高优先级的线程会更容易被执行，也需要视具体的系统决定。**

线程的调度策略采用**抢占式**，优先级高的线程比低的更大几率被执行。

线程优先级具有：

- `继承性`：A线程启动B线程，则B线程与A线程优先级一致
- `随机性`：优先级高的不一定先执行

优先级从`1~10`，越大优先级越高。

> 如果某个线程的优先级大于所属`线程组(ThreadGroup)`的最大优先级，就会采用`线程组`的最大优先级。

## 多线程

> 一个进程可以开启多个线程，多个线程共享进程资源，提高资源利用率。

优点：

- 资源利用率高
- 提高程序的执行效率(提高系统的整体的并发能力以及性能)
- 减少了线程`上下文切换`的开销(多个线程同时运行)

缺点：

- 设计更复杂

  线程间的执行是无序的，线程同步产生的错误是难以发现

- 线程死锁

- 更多的资源消耗

  除了`上下文切换`的开销，还有创建销毁线程的开销还有内存同步的开销



### 线程死锁

> 多个线程同时被阻塞，他们中的一个或多个都在等待某个资源释放，由于线程无限期堵塞，导致程序无法正常中止。

产生死锁的4个条件：

- 互斥条件：该资源任一时刻只能由一个线程占用
- 请求与保持条件：一个进程因请求资源阻塞时，对已获得的资源保持不放
- 不剥夺条件：线程获得的资源未使用完之前，无法被其他线程强行剥夺
- 循环等待条件：进程之间形成头尾相接的循环等待资源关系

```java
//死锁示例
public class DeadLockDemo{
  private static Object resource1 = new Object();
  private static Object resource2 = new Object();
  
  public static void main(String[] args){
             new Thread("线程1"){
            @Override
            public void run() {
                synchronized (resource1){
                    System.err.println("get resource1");
                    try {
                        Thread.sleep(1000);
                    }catch (InterruptedException e){
                        e.printStackTrace();
                    }
                    synchronized (resource2){
                        System.err.println("get resource2");
                    }
                }
            }
        }.start();

        new Thread("线程2"){
            @Override
            public void run() {
                synchronized (resource2){
                    System.err.println("get resource1");
                    try {
                        Thread.sleep(1000);
                    }catch (InterruptedException e){
                        e.printStackTrace();
                    }
                    synchronized (resource1){
                        System.err.println("get resource2");
                    }
                }
            }
        }.start();
  }
}
```

上述代码中的`线程1、线程2`都试图去获取对方的资源，进入`互相等待`的状态，也就会产生`死锁`。



#### 避免线程死锁

死锁产生的条件如上4种，只要破坏任意一个条件就可以解除死锁状态：

- 破坏`互斥条件`：无法达成，锁本身就是互斥的
- 破坏`请求与保持条件`：一次性申请所有资源
- 破坏`不剥夺条件`：占用部分资源的线程进一步申请资源时，如果申请不到，就主动释放资源
- 破坏`循环等待条件`：按序申请资源



### 线程安全

> 当多个线程访问同一个对象时，如果不用考虑这些线程在运行时环境下的调度和交替执行，也不需要进行额外的同步，或者在调用方进行任何其他的协调操作，调用这个对象的行为都可以获得正确的结果，那就表示这个对象是线程安全的。

线程安全有以下几种实现方式：

#### 不可变

**不可变得对象一定是线程安全的。**无论是对象的方法实现还是方法的调用者，都不需要进行任何线程安全保障措施。

不可变的类型：

- `final`关键字修饰的基本数据类型
- `String`用户调用方法，例如`subString()、replace()`都不会修改原值
- 枚举类型
- `Number`的部分子类，例如`Long、Double`等数值包装类型

对于集合类型，可以使用`Collections.unmodifiableXX()`获取一个不可变集合

```java
public class ImmutableExample {
    public static void main(String[] args) {
        Map<String, Integer> map = new HashMap<>();
        Map<String, Integer> unmodifiableMap = Collections.unmodifiableMap(map);//不可变map
        unmodifiableMap.put("a", 1);
    }
}
```

`Collections.unmodifiableXX()`本质是 对原始集合进行拷贝，当外部调用修改集合方法时，直接抛出异常`UnsupportedOperationException`。



#### 互斥同步

**最常见也是最主要的并发正确保障手段。**保证共享数据在同一时刻只被一条线程使用。

常用`互斥同步`手段如下：

##### synchronized

{%post_link Java-synchronized原理及解析%}

##### ReentrantLock

{%post_link Java-ReentrantLock原理及解析%}



#### 非阻塞同步

`互斥同步`面临的主要问题是**线程阻塞和唤醒所带来的性能问题**，所以也被称为**阻塞同步**。

> 基于冲突检测的乐观并发策略：`先进行操作，如果没有其他线程争用共享资源，那就直接操作成功；否则不断重试，知道成功为止。`

上述的`操作`和`重试检测`都依赖于`硬件指令集`的发展，不需要将线程阻塞。

##### CAS

{%post_link Atomic原子操作类分析%}





#### 无同步



### 线程间通信



### *线程池



### 多线程开发良好实践

## 锁优化