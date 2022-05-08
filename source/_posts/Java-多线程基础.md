---
title: Java多线程基础
date: 2018-12-19 10:22:33
tags: Java
top: 10
---

<!--生成者-消费者模式 创建线程 为什么要使用多线程？会有什么问题 线程池概念以及实现原理、四种初始化方案 开线程影响那块区域 进程与线程 多线程断点续传 线程关闭以及防止线程的内存泄漏 线程池上限 为什么要有线程 并发 线程模型 wait和sleep的区别 控制允许并发访问的个数 自己实现线程安全类-->

# Java多线程基础

{% fullimage /images/多线程基础.png,多线程基础,多线程基础%}

## 基础概念

### 进程

> 操作系统结构的基础，是程序在一个数据集合上运行的过程，是系统进行资源分配和调度的基本单位。`进程就是程序的实体`

### 线程

> 线程是进程的一个实体，是CPU调度和分配的基本单位，线程是一个比进程更小的执行单位，一个进程在执行期间可以产生多个线程。`一个进程至少一个线程`。一般应用于高并发场景，可以提高CPU的利用率。

### 多进程

> 每个进程都拥有自己独立的资源，多个进程可在单核处理器上并发执行，在多核处理器并行执行。

### 多线程

> 一个进程可由多个线程组成，多个线程共享进程内资源，多个线程可在单核处理器上并发执行，在多核处理器并行执行。解决多任务同时执行的需求，合理使用CPU资源。**多线程具有不稳定性**

### 并发

> 在一段时间内多个任务同时执行，或者说在一段时间内可以执行多条指令，微观上看起来就是同时运行多个进程。**偏重于多个任务交替执行，有可能串行执行**

### 并行

> 在同一时刻内多个任务同时执行，多核处理器才可以做到。**偏重于同时执行。**

## 线程基础

{% fullimage /images/线程基础.png,线程基础,线程基础%}

### 1. 进程与线程

两者的区别：

- 多个进程间的内部数据和状态都是完全独立的，而多线程是共享一块内存空间和一组系统资源，有可能互相影响
- 线程本身的数据通常只有寄存器数据，以及一个程序执行时使用的堆栈，所以**线程的切换负担比进程的切换负担小**
- 进程是重量级的任务，需要分配给他们独立的地址空间，进程间通信以及切换时很复杂的。

### 2. 线程的实现

线程的实现一般有以下3中方法，前面两种比较常见：

- #### 继承Thread类，重写`run()`方法

  > `Thread`本质上是实现了`Runnable`接口的一个实例。**调用`start()`后并不是立即执行代码，而是是线程的状态变为`Runnable`可运行态，何时运行由操作系统决定。**

  主要步骤：

  1. 定义Thread类的子类，重写`run()`方法，`run()`方法内部代表了线程需要完成的任务，所以该方法又称`执行体`
  2. 创建Thread类子类实例，即创建线程对象
  3. 调用线程对象的`start()`启动线程

  ```java
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

  拓展：

  只调用`run()`和执行普通方法是一致的。

- ####  实现Runnable接口，并实现`run()`方法

  主要步骤：

  1. 自定义类实现`Runnable`，实现`run()`方法
  2. 创建Thread类子类实例，即创建Thread对象
  3. 调用实例的`start()`

  ```java
  public class RunnableTest implements Runnable{
      public void run(){
          System.out.println("Hello Runnable");
      }
      public static void main(String[] args){
          RunnableTest runnable = new RunnableTest();
          Thread thread = new Thread(runnable);
          thread.start();
      }
  }
  ```

- #### 实现Callable接口，重写`call()`方法需配合`Future`或者`FutureTask`

  主要步骤：

  1. 创建`Callable`接口实现类，并实现`call()`方法
  2. 创建`Callable`实现类的实例，使用`FutureTask`包装`Callable`对象
  3. 使用`FutureTask`对象作为Thread对象的target创建并启动新线程
  4. 调用`FutureTask`对象的`get()`方法获得子线程执行结束后的返回值，**调用`get()`会阻塞线程**

  ```java
  public class TestCallable {
      public static class MyTestCallable implements Callable<String>{
          @Override
          public String call() throws Exception {
              return "Hello Callable";
          }
      }
  
      public static void main(String[] args){
          MyTestCallable myTestCallable = new MyTestCallable();
          //利用futuretask 
          FutureTask<String> futureTask = new FutureTask<>(myTestCallable);
          Thread t =new Thread(futureTask);
          t.start();
          try {
              System.err.println(futureTask.get());
          } catch (InterruptedException | ExecutionException e) {
              e.printStackTrace();
          }
          //利用ExecutorService产生一个线程 结合future
          ExecutorService executorService = Executors.newSingleThreadExecutor();
          Future future = executorService.submit(myTestCallable);
          try {
              System.err.println(future.get());
              executorService.shutdown();
          } catch (InterruptedException | ExecutionException e) {
              e.printStackTrace();
          }
          //利用ExecutorService产生一个线程 结合futureTask
          executorService.submit(futureTask);
          try {
              System.err.println(futureTask.get());
              executorService.shutdown();
          } catch (InterruptedException | ExecutionException e) {
              e.printStackTrace();
          }
      }
  }
  ```

  `Runnable`与`Callable`不同点：

  - `Runnable`不返回执行结果，`Callable`可返回结果
  - `Callable`可以抛出异常
  - `Runnable`可直接由`Thread构造`或者`EXecutorService.submit()`执行

  运行`Callable`可以得到一个Future对象，表示异步计算的结果。提供了检查计算是否完成的方法以等待计算的完成，并检查计算结果。

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

  #### 三种方法的比较



| 方式             | 优点                                                         | 缺点                                                         |
| ---------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 继承Thread类     | 编写简单，可以使用`this`直接访问当前线程                     | 1.受限于Java类的单继承，无法继承其他类；<br>2.多个线程之间无法共享方法或实例变量 |
| 实现Runnable接口 | 多个线程可共享一个实现了`Runnable`接口的类，非常适合多个线程处理同一任务 | 1.`run()`没有返回值<br/>2.不能直接捕获运行过程中的异常，需要使用`setDefaultUncaughtExceptionHandler()`捕获子线程的异常 |
| 实现Callable接口 | 多个线程可共享一个实现了`Callable`接口的类，非常适合多个线程处理同一任务；可以有返回值；可以抛出异常 | 编写略微复杂，要访问当前线程需要使用`Thread.currentThread()` |

#### 线程创建的内存代价

> 每当有线程创建时，JVM就需要在内存中分配`虚拟机栈`和`本地方法栈`来记录调用方法的内容，分配`程序计数器`记录指令执行的位置，这样的`内存消耗`就是创建线程的内存代价。

### 3. 线程的状态

Java线程在运行的生命周期中可能处于6种不同的状态：

- #### New(创建)

  线程被创建，还没有调用`start()`，还没有运行

- #### Runnable(可运行)

  一旦调用`start()`，线程处于`Runnable`状态，一个可运行的线程可能处于正在运行或没有运行状态，这取决与操作系统给系统提供运行的时间

- #### Blocked(阻塞)

  表示线程被锁阻塞而等待监视锁(`monitor`)，暂时不能活动

- #### Waiting(等待)

  线程暂时不活动，并不运行任何代码，消耗最少资源并等待线程调度器重新激活它。

- #### Timed Waiting(超时等待)

  在指定等待时间内等待另一个线程执行特定的方法的线程状态

- #### Terminated(终止)

  表示当前线程已执行完毕。导致线程处于终止态有两种情况：

  - `run()`执行完毕正常退出
  - 一个没有捕获的异常终止了`run()`，导致线程终止

{% fullimage /images/Thread-State.png,线程状态,线程状态%}

### 4. 线程的分类

- #### 普通线程(用户线程)

  运行在前台，执行具体的任务，如程序的主线程，链接网络的子线程都是用户线程

- #### 守护线程

  运行在后台，为其他线程提供服务，如果所有的前台线程都死亡，守护线程也随之死亡。当整个虚拟机只剩下后台线程，虚拟机也就退出了。

  应用：JVM虚拟机启动后的后台检测线程，数据库连接池中的检测线程

  最常见的守护线程：`虚拟机中的垃圾回收线程`

### 5. 线程中的常见方法

- #### `start()`

  `start()`方法执行后，表示该线程到达了`Runnable`状态，何时运行还要等待线程调度器调度

  **线程死亡后，不可再次调用`start()`，只能对`New`状态的线程调用且只能调用一次`start()`**

- #### `run()`

  直接调用`run()`，只是调用线程中的代码，多个线程无法并发执行

- #### *`join()`

  主要作用是**等待该线程终止**。`主线程需要等待子线程执行完成之后再结束，也就是在子线程调用了join()方法后面的代码只有子线程结束了才可以执行。` 

- #### *`sleep(long mills)`

  主动放弃占用的处理器资源，进入`Blocked`。使当前执行的线程以指定的毫秒数休眠（`暂时停止执行`），具体取决于定时器和调度程序的精度和准确性。当超过了指定的睡眠时间后，线程进入`Runnable`，等待线程调度器调用。

- #### *`yield()`

  主动放弃占用的处理器资源，进入`Runnable`状态，等待线程调度器调用。**这个方法要注意的是它只会让步给比它优先级高的或者和它优先级相同并处在就绪状态的线程。放弃的时间不确定，可能一会就回重新获取CPU，线程调度器重新调用。**

- #### *`interrupt()`和`isInterrupted()`

  `interrupted()`：请求线程终止，实际线程并不一定会终止，执行后可以将中断标识位设置为false。线程会时不时的检测中断标识位，以判断线程是否应该被中断。

  `isInterrupted()`：检测当前线程是都已经是中断状态，检测中断标识位

- #### `setPriority()`

  设置线程的优先级，**理论上说：线程优先级高的更容易被执行，但也要结合具体的系统。**

  使用`getPriority()`可以查看当前线程的优先级。

- #### `isAlive()`

  检查线程是否处于活动状态，如果线程处于`Runnable(就绪或运行),Blocked(阻塞)`返回`true`，若处于`New(新建),Terminated(终止)`返回`false`

- #### *`wait()/wait(long mills)`

  导致线程进入等待状态，并释放锁。`mills`为等待时间，超过这个时间没有对当前线程进行唤醒(调用`notify()/notifyAll()`)即会自动唤醒。未设置`mills`，则直到被唤醒为止。**只能在同步方法或者同步块内调用，例如`synchronized(lockobj) {...} `**

- #### *`notify()`

  让当前线程通知那些处于等待(`Waiting`)的线程，当前线程执行完毕后释放锁，随机选择一个在该对象上调用`wait()`的线程，解除其阻塞状态。**只能在同步方法或者同步块内调用，例如`synchronized(lockobj) {...} `**

- #### *`notifyAll()`

  让当前线程通知那些处于等待(`Waiting`)的线程，当前线程执行完毕后释放锁，唤醒所有在该对象上调用`wait()`的线程，解除其阻塞状态。**只能在同步方法或者同步块内调用，例如`synchronized(lockobj) {...} `**

> `wait()`和`sleep()`的区别
>
> - `sleep()`来自于Thread类方法，`wait()`来自Object类
> - `sleep()`不会释放锁，`wait()`释放锁，使得其他线程可以使用同步控制块或者方法
>
> - `sleep()`让当前正在执行的线程休眠，等待一定的时间之后，会重新进入`Runnable`。`wait()`使实体所处线程暂停运行，直到被`notify()/notifyAll()`唤醒或者`wait()`的时间到达。

### 6. 线程安全中断

```java
public class InterruptThreadTest extends Thread {
   
    //第一种 判定当前线程的中断标识位是否为true
    @Override
    public void run() {
        long l = 0;
        while (!Thread.currentThread().isInterrupted()) {
            l++;
            System.err.println("l = " + l);
        }
        System.err.println("线程已经停止");
    }
   //第二种 自己设置中断标识位 on
     private static volatile boolean on = true;
    @Override
    public void run() {
        long l = 0;
        while(on){
            l++;
            System.err.println("l = " + l);
        }
        System.err.println("线程已经停止");
    }

    private static void cancel(){
        on = false;
    }

    public static void main(String[] args) {
        try {
            InterruptThreadTest thread = new InterruptThreadTest();
            thread.start();
            TimeUnit.MILLISECONDS.sleep(10);
            //第一种 调用interrupt设置中断标识位为 true
            thread.interrupt();
            //第二种 自己设置中断标识位
            cancel();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}
```

### 7. 线程优先级

> 线程的优先级可以在程序中表明该线程的重要性，如果有很多线程处于就绪状态，系统会根据优先级来决定首先使用哪个线程进入运行状态。*低优先级的线程并不意味着不会被运行，只是运行几率会变小。*
>
> 线程优先级具有**继承特性**，比如A线程启动B线程，则B线程与A线程优先级一致
>
> 线程优先级具有**随机性**，线程优先级高的不一定每次都先执行完。
>
> 优先级从`1-10`，10为最高级，1为最低级

### 8. 线程调度策略

- #### 抢占式调度策略

  如果一个优先级比其他任何处于可运行状态的线程都高的线程都进入就绪状态，那么运行时系统就会选择该线程运行。

- #### 时间片轮转调度策略

  从所有处于就绪状态的线程中优先选择优先级最高的线程分配一定的CPU时间运行，该时间过后再去选择其他线程运行。`只有当线程运行结束或者放弃等原因进入阻塞状态，低优先级的线程才有机会执行。`若优先级相同，则调度程序以轮转的方式选择运行的线程。

## 多线程

### 1. 多线程的优缺点

优点：

> 1. 资源利用率好
> 2. 提高程序的执行效率(多个线程同时执行)
> 3. 程序响应更快

缺点：

> 1. 设计更复杂
>
>    多线程程序在访问共享数据时需要小心处理，否则会出现难以修复的bug。线程之间的交互往往非常复杂，不正确的线程同步产生的错误难以被发现并修复(由于线程调度的无序性，可能依赖于某种特殊的线程执行序列)。
>
> 2. 上下文切换的开销
>
>    线程是由CPU进行调度的，CPU的一个时间片内只执行一个线程上下文内的线程。**上下文切换**(`当CPU从执行一个线程切换到执行另一个线程时，需要先存储当前线程的本地数据，程序指针等，然后载入另一个线程的本地数据，程序指针等，最后开始执行另一个线程。`)这个过程并不廉价，如果没有必要，要尽量减少`上下文切换`的发生。
>
> 3. 更多的资源消耗
>
>    除了CPU执行`上下文切换`的消耗外，线程的执行还有其他的资源消耗。例如**内存同步的开销(线程需要一些内存维持本地栈去存储线程专用数据)**、**创建线程和终止的开销**，**线程调度的开销**等。

拓展：

- 引起**上下文切换**的原因
  - 时间片用完，CPU正常调度下一个任务
  - 被其他线程优先级更高的任务抢占
  - 执行任务遇到阻塞，调度器挂起当前任务，切换执行另一个任务
  - 用户主动挂起线程(`yield()`,`sleep()`)
  - 多任务抢占资源，没有抢到被挂起
  - 硬件中断

- 线程切换的性能代价

  > JVM需要先保存起被挂起线程的上下文环境：将线程执行位置保存在`程序计数器`中，调用方法的信息保存到`栈`中，待执行线程的`程序计数器`和`栈`中信息写入到处理器中。维护线程隔离数据区中的内容在**处理器中的导入导出**，就是线程切换的性能代价。

  减少线程上下文切换的方法：

  - 使用基于CAS的非拥塞算法
  - 无锁并发编程，尽量使用`ThreadLocal`或者不变量，而不是用锁 [安全共享策略](https://www.jianshu.com/p/bb36fee3e55c)
  - 使用`线程池+等待队列`的方式，控制线程数目

### 2. 线程同步

> 如果两个线程竞争统一资源时，并且每一个线程都调用了修改该对象的方法，这种情况通常称为**竞态条件**。导致竞态条件发生的代码区称为**临界区**。
>
> 若一个资源的创建、使用，销毁都在同一个线程内，且不会脱离该线程的控制，则无需同步。

- #### 同步方法 `synchronized`方法锁

- #### 同步代码块 `synvhronized`类锁

- #### wait()和notify() 

- #### volatile

- #### 重入锁 `Lock`

- #### 局部变量 `ThreadLocal`

- #### 阻塞队列 `BlockingQueue`

### 3. 线程通信

> 线程通信的目标是使线程间能够互相发送信号。另一方面，线程通信使线程能够等待其他线程的信号。

- #### wait()/notify()

  在`synchronized`修饰的同步方法或者同步代码块中使用Object类提供的`wait()、notify()，notifyAll()`这三个方法进行线程通信

- #### Condition

  当程序使用`Lock`类同步，系统不存在隐式的同步监视器，只能用Condition控制线程通信

- #### BlockingQueue

  `BlockingQueue`提供了`put(E e)`和`take()`支持阻塞的方法。

体现在`生产者-消费者模式`

生产者-消费者模式的实现

1. wait()/notify()实现

    ```java
   public class ProductCustomerWithWaitNotify{
       private final static int MAX_SIZE = 10;
       private static LinkedList<Object> linkedList = new LinkedList<>();
   
       public static void main(String[] args) {
           new Thread(ProductCustomerWithWaitNotify::produce).start();
           new Thread(ProductCustomerWithWaitNotify::produce).start();
           new Thread(ProductCustomerWithWaitNotify::produce).start();
           new Thread(ProductCustomerWithWaitNotify::produce).start();
           new Thread(ProductCustomerWithWaitNotify::consume).start();
           new Thread(ProductCustomerWithWaitNotify::consume).start();
           new Thread(ProductCustomerWithWaitNotify::consume).start();
           new Thread(ProductCustomerWithWaitNotify::consume).start();
       }
   
       public static void produce() {
           synchronized (linkedList) {
               while (linkedList.size() == MAX_SIZE) {
                   try {
                       linkedList.wait();
                   } catch (Exception e) {
                       e.printStackTrace();
                   }
               }
               linkedList.add(new Object());
               System.err.println("生成新产品，当前个数为" + linkedList.size());
               linkedList.notifyAll();
           }
       }
   
       public static void consume() {
           synchronized (linkedList) {
               while (linkedList.size() == 0) {
                   try {
                       linkedList.wait();
                   } catch (Exception e) {
                       e.printStackTrace();
                   }
               }
               linkedList.remove();
               System.err.println("消费了产品，当前个数为" + linkedList.size());
               linkedList.notifyAll();
           }
       }
   }
   ```

2. Condition()

   

3. BlockingQueue

   ```java
   public class ProductCustomerBlockQueue {
       private int queueSize = 10;
       private ArrayBlockingQueue<Integer> queue = new ArrayBlockingQueue<Integer>(queueSize,true);
   
       public static void main(String[] args) {
   
           ProductCustomerBlockQueue blockQueue = new ProductCustomerBlockQueue();
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
                       System.err.println("消费哦");
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
                       System.err.println("生产哦");
                   } catch (InterruptedException e) {
                       e.printStackTrace();
                   }
               }
           }
       }
   }
   ```


## 线程池

{% post_link Android-Study-Plan-XVII %}

