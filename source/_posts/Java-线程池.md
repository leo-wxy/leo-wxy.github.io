---
title: Java-线程池
date: 2019-09-13 10:19:28
tags: Java
top: 9
typora-root-url: ../
---



![Java线程池](/images/Java-线程池mind.png)

### 基础概念

- **线程**：进程中负责执行的执行单元，一个进程中至少有一个线程,**操作系统能够进行调度的最小单位**
- **进程**：一个执行中的程序的实例
- **多线程**：解决多任务同时执行的需求，合理使用CPU资源。多线程的运行时根据CPU切换完成，如何切换由CPU确定，因此多线程具有不确定性
- **线程池**： 基本思想是一种对象池的思想，开辟一块内存空间，里面存放了众多（未死亡）的线程，池中线程执行调度由池管理器来处理，当有线程任务时，从池中取一个，执行完成后线程对象回归池中，避免反复创建线程对象所带来的性能开销，节省系统资源。

###  线程池的概念

在执行一个异步任务或并发任务时，往往会通过`new Thread()`方法去开启一个子线程去执行任务，等到子线程操作完成后在利用`Handler`切换至主线程。但是利用这种方法我们无法对自己创建的子线程进行有效的管理，然后由于过多的创建子线程，他们之间相互竞争会导致资源的过度占用。线程池的出现就是为了来对子线程进行管理。

### 为什么要使用线程池

- **降低资源消耗。**通过重复利用已创建的线程降低线程创建和销毁造成的消耗
- **提高响应速度。**当任务到达时，任务可以不需要等到线程创建就可以立即执行
- **提高线程的可管理性。**线程是稀缺资源，大量创建会导致系统资源过度消耗且会降低系统的稳定性，线程池可以有效控制线程数，并进行统一的分配、调优和监控。

###  线程池的构造参数与对象成员变量

![线程池构造参数](/images/Java-线程池构造参数.png)

`Executors`提供了基础的四类线程池方法，最终都是通过`ThreadPoolExecutor`类完成。对于这个类的描述`他维护了一个线程池，对于提交Executor中的任务，不是创建新的线程而是使用池内的线程来执行任务。可以显著减少对于任务执行的开销。`

1. ThreadPoolExecutor构造函数介绍

   ```java
   public ThreadPoolExecutor(int corePoolSize,
                                 int maximumPoolSize,
                                 long keepAliveTime,
                                 TimeUnit unit,
                                 BlockingQueue<Runnable> workQueue,
                                 ThreadFactory threadFactory,
                                 RejectedExecutionHandler handler)
   ```

   参数介绍：

   - **`corePoolSize 核心线程数`** 表示线程池中的基本线程数量即核心线程数量。一般情况下核心线程会一直存活在线程池中，即便他们处于闲置状态。只有在`ThreadPoolExecutor的allowCoreThreadTimeOut设置为true`的时候，会有一个超时策略（超过设置好的超时时间，闲置的核心线程会被终止）。**当创建的线程数小于corePoolSize时，不管有没有空闲线程都会创建新的线程**。

   - **`maximumPoolSize 最大线程数`**  表示线程池中允许的最大创建线程数，当活动的线程数达到数值后，后续新任务会被阻塞。**使用有界队列时，未达到该值则会创建新的线程，使用无界队列时该值无效。**

   - **`keepAliveTime 非核心线程闲置时的超时时长`** 表示空闲非核心线程的最大存活时间，一旦超过即被销毁。**当`ThreadPoolExecutor的allowCoreThreadTimeOut设置为true`的时候，该参数也可作用于核心线程**

   - **`unit 存活时间的时间单位`** 用于指定keepAliveTime参数的时间单位，为一个枚举类型。包含下列参数：`NANOSECONDS（纳秒）`,`MICROSECONDS（微秒）`,`MILLSECONDS（毫秒）`,`SECONDS（）秒`,`MINUTES（分）`,`HOURS（时）`,`DAYS（天）`

   - **`workQueue 线程池中的任务队列`** 该队列是`java.util.BlockingQueue<E>`的一个实例，是一种阻塞队列用来存放等待执行的任务。通过`execute()`方法将提交的Runnable对象存储进去。根据具体实现类的不同可以分为以下三种队列策略：

     - `容量为0即直接提交策略--SynchronousQueue`：等待队列容量为0 ，所有需要阻塞的任务必须等待池内的某个线程有空闲才可以继续执行，否则阻塞。`CachedThreadPool`使用该队列策略。
     - `容量无限即无界队列策略--LinkedBlockingQueue`：等待队列的长度无穷大，在这种策略下不会出现多余corePoolSize的线程被创建，所以maximumPoolSize以及handler无效，因为不存在队列满的情况。不过也有缺点：**线程的执行速度会比提交速度慢，会导致无界队列快速增长，直到系统资源耗尽。**`fixedThreadPool`采用了这种队列策略。
     - `容量有限即有界队列策略--指定了容量的任何BlockingQueue`：等待队列的长度为限制长度，指定了容量后可以**防止过多的资源被消耗**。 

   - **`threadFactory 线程工厂`**：是一个接口可以为线程池提供新线程的创建。由同一个threadFactory创建的线程同属于一个ThreadGroup，优先级都为Thread.NORM_PRIORITY，以及为非进程守护状态。默认都是采用`Executors.defaultThreadFactory()`返回值。

   - **`handler 拒绝策略`**：当**使用有界队列时且队列任务被填满后并且线程数也达到了最大值，就会触发拒绝策略**。如果任务被拒绝执行，则会调用`RejectedExecutionHandler.rejectedExecution()`方法，默认调用`AbortPolicy`拒绝策略，也可以由用户自定义。JDK中定义了4种拒绝策略：

     - `AbortPolicy`**处理程序遭到拒绝则直接抛出`RejectedExecutionException`异常然后丢弃该任务。**

       实现源码：

       ```java
        public static class AbortPolicy implements RejectedExecutionHandler {
               /**
                * Creates an {@code AbortPolicy}.
                */
               public AbortPolicy() { }
               public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
                   throw new RejectedExecutionException("Task " + r.toString() +
                                                        " rejected from " +
                                                        e.toString());
               }
           }
       ```

       样例演示：

       ```java
        static class TestRunnable implements Runnable {
               private int id;
       
               TestRunnable(int id) {
                   this.id = id;
               }
       
               @Override
               public void run() {
                   System.err.println(Thread.currentThread().getName()+" 当前线程id="+ this.id);
                   try {
                       Thread.sleep(1000);
                   } catch (InterruptedException e) {
                       e.printStackTrace();
                   }
               }
           }
       
       public static void abortPolicyDemo() {
               ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(
                       1, 1, 60, TimeUnit.SECONDS,
                       new ArrayBlockingQueue<Runnable>(1), new ThreadPoolExecutor.AbortPolicy());
       
               threadPoolExecutor.submit(new TestRunnable(1));
               threadPoolExecutor.submit(new TestRunnable(2));
               threadPoolExecutor.submit(new TestRunnable(3));
               threadPoolExecutor.shutdown();
           }
       
       运行结果：添加进程时直接抛出异常但是没有影响后续的进行
       pool-1-thread-1 当前线程id=1
       Exception in thread "main" java.util.concurrent.RejectedExecutionException: Task java.util.concurrent.FutureTask@4b1210ee rejected from java.util.concurrent.ThreadPoolExecutor@4d7e1886[Running, pool size = 1, active threads = 1, queued tasks = 1, completed tasks = 0]
           at java.util.concurrent.ThreadPoolExecutor$AbortPolicy.rejectedExecution(ThreadPoolExecutor.java:2047)
           at java.util.concurrent.ThreadPoolExecutor.reject(ThreadPoolExecutor.java:823)
           at java.util.concurrent.ThreadPoolExecutor.execute(ThreadPoolExecutor.java:1369)
           at java.util.concurrent.AbstractExecutorService.submit(AbstractExecutorService.java:112)
           at threadpool.ThreadPoolDemo.abortPolicyDemo(ThreadPoolDemo.java:140)
           at threadpool.ThreadPoolDemo.main(ThreadPoolDemo.java:13)
       pool-1-thread-1 当前线程id=2
       ```

     - `CallerRunsPolicy`**在调用`execute`方法的调用者所在线程来执行被拒绝的任务，提供简单的反馈控制机制，可以减缓新任务的提交速度。**

       实现源码：

       ```java
       public static class CallerRunsPolicy implements RejectedExecutionHandler {
               /**
                * Creates a {@code CallerRunsPolicy}.
                */
               public CallerRunsPolicy() { }
               public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
                   if (!e.isShutdown()) {
                       r.run();
                   }
               }
           }
       ```

       样例演示：

       ```java
         public static void callerRunsPolicyDemo(){
               ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(
                       1, 1, 60, TimeUnit.SECONDS,
                       new ArrayBlockingQueue<Runnable>(1), new ThreadPoolExecutor.CallerRunsPolicy());
       
               threadPoolExecutor.submit(new TestRunnable(1));
               threadPoolExecutor.submit(new TestRunnable(2));
               threadPoolExecutor.submit(new TestRunnable(3));
               threadPoolExecutor.shutdown();
           }
       
       运行结果：task2执行在了主线程，由于被拒绝执行所以在调用者线程执行了任务
       pool-1-thread-1 当前线程id=1
       main 当前线程id=3
       pool-1-thread-1 当前线程id=2
       ```

     - `DiscardPolicy`**被拒绝即无法执行的任务被直接删除**

       实现源码：   

       ```java
       public static class DiscardPolicy implements RejectedExecutionHandler {
                     /**
                      * Creates a {@code DiscardPolicy}.
                      */
                     public DiscardPolicy() { }
                     public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
                     }
                 }
       ```

       样例演示：

       ```java
           public static void discardPolicyDemo(){
               ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(
                       1, 1, 60, TimeUnit.SECONDS,
                       new ArrayBlockingQueue<Runnable>(1), new ThreadPoolExecutor.DiscardPolicy());
       
               threadPoolExecutor.submit(new TestRunnable(1));
               threadPoolExecutor.submit(new TestRunnable(2));
               threadPoolExecutor.submit(new TestRunnable(3));
               threadPoolExecutor.shutdown();
           }
       
       运行结果：由于被拒绝执行在该策略下被直接抛弃
       pool-1-thread-1 当前线程id=1
       pool-1-thread-1 当前线程id=2
       ```

     - `DiscardOldestPolicy`**判断线程池是否被关闭，没有则丢弃最老的一个请求，再尝试提交当前任务。**

       实现源码：

       ```java
        public static class DiscardOldestPolicy implements RejectedExecutionHandler {
                     /**
                      * Creates a {@code DiscardOldestPolicy} for the given executor.
                      */
                     public DiscardOldestPolicy() { }
                     public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
                         if (!e.isShutdown()) {
                             e.getQueue().poll();
                             e.execute(r);
                         }
                     }
                 }
       ```

       样例演示：

       ```java
           public static void discardOldestPolicyDemo(){
               ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(
                       1, 1, 60, TimeUnit.SECONDS,
                       new ArrayBlockingQueue<Runnable>(1), new ThreadPoolExecutor.DiscardOldestPolicy());
       
               threadPoolExecutor.submit(new TestRunnable(1));
               threadPoolExecutor.submit(new TestRunnable(2));
               threadPoolExecutor.submit(new TestRunnable(3));
               threadPoolExecutor.submit(new TestRunnable(4));
               threadPoolExecutor.shutdown();
           }
       
       运行结果：???
       pool-1-thread-1 当前线程id=1
       pool-1-thread-1 当前线程id=4
       ```

     - `CustomRejectPolicy 自定义拒绝策略`**可以用来记录运行日志或者记录无法处理的任务**

       样例演示：

       ```java
       /**
       * 自定义拒绝策略，实现RejectedExecutionHandler接口即可
       */
       static class CustomRejectedPolicy implements RejectedExecutionHandler{
               @Override
               public void rejectedExecution(Runnable r, ThreadPoolExecutor executor) {
                   if (!executor.isShutdown()){
                           System.err.println("自定义异常日志记录:  "+  r.toString());
                   }
               }
           }
       
       public static void customPolicyDemo(){
               ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(
                       1, 1, 60, TimeUnit.SECONDS,
                       new ArrayBlockingQueue<Runnable>(2), new CustomRejectedPolicy());
       
           //使用execute是因为使用submit时会被封装成RunnableFuture对象
               threadPoolExecutor.execute(new TestRunnable(1));
               threadPoolExecutor.execute(new TestRunnable(2));
               threadPoolExecutor.execute(new TestRunnable(3));
               threadPoolExecutor.execute(new TestRunnable(4));
       
               threadPoolExecutor.shutdown();
           }
       
       运行结果：由于4号被拒绝，记录日志
       自定义异常日志记录:  java.util.concurrent.FutureTask@4b1210ee
       pool-1-thread-1 当前线程id=1
       pool-1-thread-1 当前线程id=2
       pool-1-thread-1 当前线程id=3
       ```

     - 额外参数扩展 `allowCoreThreadTimeOut 允许核心线程过期 `默认值为false（线程池已不被使用，但是其中还有活着的线程，则该线程池无法被回收，会造成内存泄露）。所以用户可以显式调用`shutDown()`或者该值设置为true，则会被回收。

2. ThreadPoolExecutor的使用

   向线程池提交一个任务的方式有两种：

   - `execute`：这种方法提交任务，是没有返回值的即无法判断在线程池中是否完成该任务

     ```java
      threadPoolExecutor.execute(new TestRunnable(1));
     ```

   - `submit`：使用`submit`方法提交任务时，会返回一个future，可以通过这个future来判断任务是否执行成功也可以根据`future的get()`方法获取返回值。**若子线程任务没完成，`get()`方法会阻塞直到任务完成，若使用`get(long timeout,TimeUnit unit)`则会阻塞一段时间后返回，可能尚未完成任务。**

     ```java
      Future<Integer> future = fixedThreadPool.submit(new Callable<Integer>() {
     
                     @Override
                     public Integer call() throws Exception {
                         System.err.println(Thread.currentThread().getName() + " , index = " + index);
                         return 2;
                     }
                 });
     
                 try {
                     System.err.println("Future return :" + future.get().toString());
                 } catch (Exception e) {
                     e.printStackTrace();
                 }
     ```

3. 线程池的关闭

   线程池关闭方法有两种：

   - `shutdown()`：将线程池的状态置为SHUTDOWN状态，然后中断没有正在执行的线程。

     ```java
     public void shutdown() {
             final ReentrantLock mainLock = this.mainLock;
             mainLock.lock();
             try {
                 checkShutdownAccess();
                 advanceRunState(SHUTDOWN);
                 interruptIdleWorkers();
                 onShutdown(); // hook for ScheduledThreadPoolExecutor
             } finally {
                 mainLock.unlock();
             }
             tryTerminate();
         }
     ```

   - `shutdownNow()`：将线程池的状态设为STOP状态，中断所有任务包括执行中的线程，并返回等待执行的任务列表。

     ```java
     public List<Runnable> shutdownNow() {
             List<Runnable> tasks;
             final ReentrantLock mainLock = this.mainLock;
             mainLock.lock();
             try {
                 checkShutdownAccess();
                 advanceRunState(STOP);
                 interruptWorkers();
                 tasks = drainQueue();
             } finally {
                 mainLock.unlock();
             }
             tryTerminate();
             return tasks;
         }
     ```

     中断线程需要采用`interrput`方法，**无法响应中断的任务可能永远无法终止。**

     当需要立即中断所有线程并且不在乎任务是否执行完成时，可以使用`shutdownNow`方法。

4. 线程池的拓展

   `ThreadPoolExecutor`默认提供三个空方法，可以通过重写这三个方法来监控线程池。

   ```java
   //任务执行前 记录任务开始前时间
   protected void beforeExecute(Thread t, Runnable r) { }
   //任务执行后 记录任务结束时间
   protected void afterExecute(Runnable r, Throwable t) { }
   //线程池关闭 记录线程池关闭事件以及执行过的线程数量
   protected void terminated() { }
   ```

   样例演示：

   ```java
   class CustomThreadPoolExecutor extends ThreadPoolExecutor{
   
           public CustomThreadPoolExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue) {
               super(corePoolSize, maximumPoolSize, keepAliveTime, unit, workQueue);
           }
   
           @Override
           protected void beforeExecute(Thread t, Runnable r) {
               super.beforeExecute(t, r);
               System.err.println("beforeExecute"+r.toString());
           }
   
           @Override
           protected void afterExecute(Runnable r, Throwable t) {
               super.afterExecute(r, t);
               System.err.println("afterExecute"+r.toString());
           }
   
           @Override
           protected void terminated() {
               super.terminated();
               System.err.println("线程关闭");
           }
       }
   ```

###  线程池的分类以及各自的特性

![Java-常见线程池](/images/Java-常见线程池.png)

利用`Executors`类提供了四种不同的线程池，他们都是直接或者间接配置`ThreadPoolExecutor`来实现功能。下面分别介绍着四个线程池

####  `newFixedThreadPool` 

> 创建固定大小的线程池，每次提交一个任务就创建一个线程，直到线程达到线程池的最大大小，线程池的大小一旦达到最大值就不会发生变化，如果某个线程因为异常而结束，则会补充一个新进程。
>
> 由于只设置核心线程大小，所以可以**更快的响应外界请求**
>
> 线程池的大小设置，可以使用`Runtime.getRuntime().availableProcessors()`

- 实现源码

  ```java
  /**
  * 设置了核心线程，并且没有超时机制，使用LinkedBlockingQueue则任务队列大小是无上限的
  */
  public static ExecutorService newFixedThreadPool(int nThreads) {
          return new ThreadPoolExecutor(nThreads, nThreads,
                                        0L, TimeUnit.MILLISECONDS,
                                        new LinkedBlockingQueue<Runnable>());
      }
  ```

- 样例演示

  ```java
  public static void fixedThreadPoolDemo(){
          ExecutorService fixedThreadPool= Executors.newFixedThreadPool(3);
          for (int i = 0; i <6 ; i++) {
              final int index=i;
              fixedThreadPool.execute(new Runnable() {
                  @Override
                  public void run() {
                      System.err.println(Thread.currentThread().getName()+" , index = "+index);
                  }
              });
  
              try{
                  Thread.sleep(1000);
              }catch(Exception e){
                  e.printStackTrace();
              }
          }
      }
  
  运行结果：整个过程都在pool-1的线程池中运行,然后复用线程
  pool-1-thread-1 , index = 0
  pool-1-thread-2 , index = 1
  pool-1-thread-3 , index = 2
  pool-1-thread-1 , index = 3
  pool-1-thread-2 , index = 4
  pool-1-thread-3 , index = 5
  ```

- 适用场景

  用于负载比较重的服务器，为了资源的合理利用，需要限制当前线程数量。

#### `newCachedThreadPool`

> 可根据需要创建新线程的线程池，但是在一起构造的线程可用时将重用他们。对于很多短期异步任务的程序而言，这类线程池可以提高性能。
>
> 如果现有线程没有可用的，则会创建一个新的线程并添加到池中，终止并从缓存中移除那些超过60s没有使用的线程。**因此，长时间保持空闲的newCachedThreadPool线程池是不存在任何线程的，所以这时候几乎不占用系统资源。**

- 实现源码

  ```java
  /**
  * 核心线程数为0 线程最大为Int的最大值所以可以认定为线程池最大线程无限大，设置了超时时间为60s。任务队列采用了阻塞队列(必须池内有空闲线程才可以执行)
  */
  public static ExecutorService newCachedThreadPool() {
          return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                        60L, TimeUnit.SECONDS,
                                        new SynchronousQueue<Runnable>());
      }
  ```

- 样例演示

  ```java
  public static void cachedThreadPoolDemo(){
          ExecutorService cachedThreadPool= Executors.newCachedThreadPool();
          for (int i = 0; i <6 ; i++) {
              final int index=i;
              cachedThreadPool.execute(new Runnable() {
                  @Override
                  public void run() {
                      System.err.println(Thread.currentThread().getName()+" , index = "+index);
                  }
              });
  
              try{
                  Thread.sleep(1000);
              }catch(Exception e){
                  e.printStackTrace();
              }
          }
      }
  
  运行结果：整个过程都在同一个线程pool-1-thread-1中执行，后面线程复用前面的线程
  pool-1-thread-1 , index = 0
  pool-1-thread-1 , index = 1
  pool-1-thread-1 , index = 2
  pool-1-thread-1 , index = 3
  pool-1-thread-1 , index = 4
  pool-1-thread-1 , index = 5
  ```

- 适用场景

  并发执行大量短期的小任务，或者负载较轻的服务器

####  `newScheduledThreadPool`

> 创建一个大小无限的线程池，此线程池支持定时以及周期性执行任务的需求。

- 实现源码

  ```java
  public static ScheduledExecutorService newScheduledThreadPool(int corePoolSize) {
      return new ScheduledThreadPoolExecutor(corePoolSize);
  }
  /**
  * 核心线程数固定，非核心线程数为无限大，当非核心数处于闲置状态的时候会被立即回收
  */
  public ScheduledThreadPoolExecutor(int corePoolSize) {
      super(corePoolSize, Integer.MAX_VALUE, 0, NANOSECONDS,
            new DelayedWorkQueue());
  }
  ```

- 样例演示

  ```java
   public static void scheduleThreadPoolDemo() {
          ScheduledExecutorService scheduledThreadPool = Executors.newScheduledThreadPool(3);
       //延迟一定时间后执行Runnable任务
          scheduledThreadPool.schedule(new Runnable() {
              @Override
              public void run() {
                  System.err.println(Thread.currentThread().getName() + " delay 2s");
              }
          }, 2, TimeUnit.SECONDS);
       //延迟一定时间后执行Callable任务
          scheduledThreadPool.schedule(new Callable<Object>() {
              @Override
              public Object call() throws Exception {
                  return null;
              }
          }, 2, TimeUnit.SECONDS);
       //延迟一定时间（initialDelay）后,以(period)时间间隔执行任务
          scheduledThreadPool.scheduleAtFixedRate(new Runnable() {
              @Override
              public void run() {
                  System.err.println(Thread.currentThread().getName() + " every 3s");
              }
          }, 1, 1, TimeUnit.SECONDS);
       //延迟一定时间（initialDelay）后,以(delay即上一个任务执行结束到下一个任务开始的间隔)执行
          scheduledThreadPool.scheduleWithFixedDelay(new Runnable() {
              @Override
              public void run() {
                  System.err.println(Thread.currentThread().getName() + " delay 3s");
              }
          }, 1, 1, TimeUnit.SECONDS);
      }
  
  运行结果：
  pool-1-thread-1 every 3s
  pool-1-thread-2 delay 3s
  pool-1-thread-3 delay 3s 1
  pool-1-thread-2 every 3s
  ```

- 适用场景

  用于需要多个后台线程执行周期任务，同时需要限制线程数量

####  `newSingleThreadExecutor`

> 创建一个单线程池，该线程池中只有一个线程在工作，其他任务都会依次在任务中排列中等候依次执行，任务是串行执行的。此线程池保证所有的任务的执行顺序按照任务提交顺序执行(FIFO-先进先出)。

- 实现源码

  ```java
  /**
  * 只有一个核心线程，对任务队列没有大小限制，将所有外界任务统一到一个线程执行所有我们不需要处理线程同步的问题。
  */
  public static ExecutorService newSingleThreadExecutor() {
          return new FinalizableDelegatedExecutorService
              (new ThreadPoolExecutor(1, 1,
                                      0L, TimeUnit.MILLISECONDS,
                                      new LinkedBlockingQueue<Runnable>()));
      }
  ```

- 样例演示

  ```java
   public static void singleThreadPoolDemo(){
          ExecutorService singleThreadExecutor=Executors.newSingleThreadExecutor();
          for (int i = 0; i < 6; i++) {
              final int index = i;
              singleThreadExecutor.execute(new Runnable() {
                  @Override
                  public void run() {
                      System.err.println(Thread.currentThread().getName() + " , index = " + index);
                  }
              });
  
              try {
                  Thread.sleep(1000);
              } catch (Exception e) {
                  e.printStackTrace();
              }
          }
      }
  
  运行结果：所有的任务都是在pool-1-thread-1中依次运行
  pool-1-thread-1 , index = 0
  pool-1-thread-1 , index = 1
  pool-1-thread-1 , index = 2
  pool-1-thread-1 , index = 3
  pool-1-thread-1 , index = 4
  pool-1-thread-1 , index = 5
  ```

- 适用场景

  用于串行执行任务的场景，每个任务需要顺序执行



|                                  | newCachedThreadPool                                         | newFixedThreadPool                                           | newSingleThreadExecutor                                     | newScheduledThreadPool                                       |
| -------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------- | ------------------------------------------------------------ |
| corePoolSize/<br>maximumPoolSize | 0/Integer.MAX<br> `创建非核心线程`执行任务                  | n/n<br>`创建核心线程`执行任务                                | 1/1<br>`只创建1个核心线程`执行任务                          | n/Integer.MAX                                                |
| workQueue                        | SynchronousQueue                                            | LinkedBlockingQueue(Integer.MAX)                             | LinkedBlockingQueue(Integer.MAX)                            | DelayedQueue                                                 |
| keepAliveTime                    | 60s<br />即使没有任务进来，线程也会被很快回收               | 0ms<br />没有任务的情况下，线程会一直被阻塞等待任务          | 0ms<br />没有任务的情况下，线程会一直被阻塞等待任务         | 10s                                                          |
| 适用场景                         | 并发执行大量短期的小任务，或者负载较轻的服务器              | 用于负载较重的服务器，合理的利用服务器资源                   | 用于串行执行任务的场景，每个任务按照**先来先执行**的原则    | 用于执行后台周期性任务                                       |
| 缺点                             | 最大线程数为`Integer.MAX`，导致创建大量请求，消耗服务器资源 | 等待队列长度为`Integer.MAX`，导致大量请求堆积，消耗服务器资源 | 最大线程数为`Integer.MAX`，导致创建大量请求，消耗服务器资源 | 等待队列长度为`Integer.MAX`，导致大量请求堆积，消耗服务器资源 |



### 线程池的生命周期

> 线程池的生命周期是**伴随线程池的运行，由内部进行维护的**。
>
> 由两个值进行维护
>
> - `runState`：运行状态
> - `workerCount`：线程数量

```java
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));
```

`ctl`结合两个关键参数，来保证运行状态的一致。

高三位：`runState`，低29位：`workerCount`，两个变量互相不干扰。

![图3 线程池生命周期](/images/582d1606d57ff99aa0e5f8fc59c7819329028.png)



| 运行状态                      | 描述                                                         |
| ----------------------------- | ------------------------------------------------------------ |
| RUNNING(`线程池运行状态`)     | 可以接受新任务，并且也能处理阻塞队列的任务                   |
| SHUTDOWN(`线程池关闭状态`)    | 不再接受新的任务，但是依然可以处理阻塞队列的任务             |
| STOP(`线程池停止状态`)        | 不再处理阻塞队列的任务，并且中断正在进行的任务               |
| TIDYING(`线程池正在终止状态`) | 所有任务都已停止，`workerCount`为0                           |
| TERMINATED(`线程池终止状态`)  | 线程池已停止运行，所有工作线程都被销毁，所有任务都已被清空或执行完毕 |

源码内部提供了如下方法去获取当前线程池的状态

```java ThreadPoolExecutor.java
    private static int runStateOf(int c)     { return c & ~CAPACITY; } //运行状态
    private static int workerCountOf(int c)  { return c & CAPACITY; } //工作线程数量
    private static int ctlOf(int rs, int wc) { return rs | wc; } //当前runstate与workercount的和
```

![img](/images/640)



### 线程池的执行流程

![图2 ThreadPoolExecutor运行流程](/images/77441586f6b312a54264e3fcf5eebe2663494.png)

1. 判断`corePoolSize(核心线程数)`是否已到达，没到达则可以创建一个新线程执行任务
2. 判断`workQueue(工作队列)`是否已满，没满则添加入阻塞队列等待执行
3. 判断`maximumPoolSize(最大线程数)`是否已到达，没到达则创建一个新线程执行任务。
4.  已经达到了`maximumPoolSize(最大线程数)`或者线程池不处于`RUNNABLE`状态，执行`handler(任务拒绝策略)`

### 线程池实现原理

![Java线程池原理](/images/Java-线程池原理.png)

#### 添加任务

线程池通过调用`submit()`或`execute()`提交线程任务，其中`submit()`可以拿到线程执行结果，内部通过`execute()`实现。

```java
public void execute(Runnable command) {
        if (command == null)
            throw new NullPointerException();
        int c = ctl.get();
        //1.当前工作线程 < 核心线程时
        if (workerCountOf(c) < corePoolSize) {
            //直接创建新的Worker执行任务
            if (addWorker(command, true))
                return;
            //重新获取运行状态
            c = ctl.get();
        }
        //2.线程池处于running状态，任务加入 工作队列
        if (isRunning(c) && workQueue.offer(command)) {
            int recheck = ctl.get();
            //线程不处于running状态，直接执行拒绝任务策略
            if (! isRunning(recheck) && remove(command))
                reject(command);
            //当无可用工作线程时，创建新的工作线程执行任务
            else if (workerCountOf(recheck) == 0)
                addWorker(null, false);
        }
        //无法添加任务，可能线程池被终止，或者最大线程已经满了
        else if (!addWorker(command, false))
            //执行拒绝策略
            reject(command);
    }
```

> 为什么执行`isRunning()`两次？
>
> 多线程环境下，线程池状态时刻发生变化，很可能刚获取的线程池状态突然就发生改变了。
>
> 万一线程池处于非`RUNNING`状态，那么任务永远不会执行。

添加任务都是通过`addWorker()`执行

```java
    private boolean addWorker(Runnable firstTask, boolean core/*是否核心线程*/) {
        retry:
        for (;;) {
            int c = ctl.get();
            int rs = runStateOf(c);

            // 当线程池处于 STOP、TIDYING、TERMINATED状态时，无法添加新任务
            // 或者处于SHUTDOWN时，阻塞队列还有任务就需要继续执行完毕
            if (rs >= SHUTDOWN &&
                ! (rs == SHUTDOWN &&
                   firstTask == null &&
                   ! workQueue.isEmpty()))
                return false;

            for (;;) {
                //获取工作线程数量
                int wc = workerCountOf(c);
                //比较工作线程数量，若超出不予执行
                if (wc >= CAPACITY ||
                    wc >= (core ? corePoolSize : maximumPoolSize))
                    return false;
                if (compareAndIncrementWorkerCount(c))
                    break retry;
                c = ctl.get();  // Re-read ctl
                if (runStateOf(c) != rs)
                    continue retry;
                // else CAS failed due to workerCount change; retry inner loop
            }
        }

        boolean workerStarted = false;
        boolean workerAdded = false;
        Worker w = null;
        try {
            //新建工作对象
            w = new Worker(firstTask);
            final Thread t = w.thread;
            if (t != null) {
                final ReentrantLock mainLock = this.mainLock;
                mainLock.lock();
                try {
                    // Recheck while holding lock.
                    // Back out on ThreadFactory failure or if
                    // shut down before lock acquired.
                    int rs = runStateOf(ctl.get());

                    if (rs < SHUTDOWN ||
                        (rs == SHUTDOWN && firstTask == null)) {
                        if (t.isAlive()) // precheck that t is startable
                            throw new IllegalThreadStateException();
                        workers.add(w);
                        int s = workers.size();
                        if (s > largestPoolSize)
                            largestPoolSize = s;
                        workerAdded = true;
                    }
                } finally {
                    mainLock.unlock();
                }
                if (workerAdded) {
                  //启动新任务
                    t.start();
                    workerStarted = true;
                }
            }
        } finally {
            //线程启动失败，移除worker
            if (! workerStarted)
                addWorkerFailed(w);
        }
        return workerStarted;
    }
```

1. 线程池处于`RUNNABLE状态`或者`SHUTDOWN状态并且阻塞队列还有任务`，需要添加新线程执行任务
2. `Worker`封装了线程对象
3. 线程启动失败，则移除对应`Worker`

##### `Worker`

> 内部封装了`线程`对象，并且本身也是一个`Runnable`对象。

```java
   private final class Worker
        extends AbstractQueuedSynchronizer
        implements Runnable
    {

        /** Worker实际执行的线程 */
        final Thread thread;
        /** 初始化的任务，可以为null */
        Runnable firstTask;
        /** Per-thread task counter */
        volatile long completedTasks;

        Worker(Runnable firstTask) {
            setState(-1); // inhibit interrupts until runWorker
            this.firstTask = firstTask;
            this.thread = getThreadFactory().newThread(this);
        }

        /** Delegates main run loop to outer runWorker. */
        public void run() {
            runWorker(this);
        }
     
    ...
    }
```

`Worker`持有两个对象：

- `thread`：用来执行任务
- `firstTask`：保存传入的第一个任务，如果该值非空，则优先执行该任务。若为空，就需要创建一个工作线程去执行`workQueue`中的任务

`Worker`继承了`AQS`来实现`独占锁`功能，可以保证线程的执行状态是正确的。

获取独占锁，表示**当前线程正在执行中，任务不可以被中断**。

未获取独占锁，表示**当前线程没有处理任务，可以进行线程中断**。中断后就可以安全的进行线程回收。

#### 执行任务

`addWorker()`添加任务完毕后，就需要执行任务`runWorker()`

```java
final void runWorker(Worker w) {
        Thread wt = Thread.currentThread();
        Runnable task = w.firstTask;
        w.firstTask = null;
        w.unlock(); // allow interrupts
        boolean completedAbruptly = true;
        try {
           //存在firstTask则先执行，否则从getTasks()获取阻塞队列的任务
            while (task != null || (task = getTask()) != null) {
                w.lock();
                //检测线程池状态
                if ((runStateAtLeast(ctl.get(), STOP) ||
                     (Thread.interrupted() &&
                      runStateAtLeast(ctl.get(), STOP))) &&
                    !wt.isInterrupted())
                    wt.interrupt();
                try {
                   //可重写该方法监听任务执行状态
                    beforeExecute(wt, task);
                    Throwable thrown = null;
                    try {
                      //执行任务
                        task.run();
                    } catch (RuntimeException x) {
                        thrown = x; throw x;
                    } catch (Error x) {
                        thrown = x; throw x;
                    } catch (Throwable x) {
                        thrown = x; throw new Error(x);
                    } finally {
                       //可重写该方法监听任务执行状态
                        afterExecute(task, thrown);
                    }
                } finally {
                    task = null;
                    w.completedTasks++;
                    w.unlock();
                }
            }
            completedAbruptly = false;
        } finally {
          //线程池无任务可以执行
            processWorkerExit(w, completedAbruptly);
        }
    }
```

若`firstTask`不为null，则优先执行`firstTak`。`fistTask`未设置时，从`getTasks()`获取`workQueue`中的任务去执行。

```java
    private Runnable getTask() {
        boolean timedOut = false; // Did the last poll() time out?

        for (;;) {
            int c = ctl.get();
            int rs = runStateOf(c);

            // Check if queue empty only if necessary.
            if (rs >= SHUTDOWN && (rs >= STOP || workQueue.isEmpty())) {
                decrementWorkerCount();
                return null;
            }

            int wc = workerCountOf(c);

            // 是否允许核心线程超时释放 或者 当前工作线程数大于核心线程
            boolean timed = allowCoreThreadTimedout || wc > corePoolSize;

            if ((wc > maximumPoolSize || (timed && timedOut))
                && (wc > 1 || workQueue.isEmpty())) {
                if (compareAndDecrementWorkerCount(c))
                    return null;
                continue;
            }

            try {
                Runnable r = timed ?
                    workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS) : //等待 keepAliveTime 后释放线程
                    workQueue.take(); //使用take()获取任务，阻塞线程，直到拿到任务为止
                if (r != null)
                    return r;
                timedOut = true;
            } catch (InterruptedException retry) {
                timedOut = false;
            }
        }
    }
```

线程池里的线程从`workQueue阻塞队列`里拿任务，如果存在非核心线程且`workQueue`没有任务，非核心线程就会等到`keppAliveTime`时间后被释放。如果当前仅有核心线程存在时，设置了`allowCoreThreadTimedout(true)`，核心线程也会被释放。否则就会通过`take()`一致阻塞直到拿到任务为止。

核心线程不会被释放的原因：**通过`workQueue.take()`一直阻塞线程**。

<br>

核心线程与非核心线程的区别：

这两者之间并没有明显的标志区分，根据上面的代码可以发现，两者的区别在于**核心线程可以无限等待获取任务(阻塞队列take())，非核心线程要限时获取任务(keepAliveTime之内)**。核心线程其实指代的就是`0~corePoolSize`之间创建的线程，`corePoolSize~maximumPoolSie`表示的就是非核心线程。







![图7 Worker执行任务](/images/03268b9dc49bd30bb63064421bb036bf90315.png)

通过调用`execute(runnable)`传进去的`runnable`对象不是直接通过`new Thread(runnable).start()`的方式去执行，而是通过一个**正在运行的线程**去执行`runnable.run()`。根据上述源码中的`runWorker()`，在执行完`firstTask`后就会调用`getTask()`获取任务去执行，如果`getTask()`没有获取到任务，就会在等待`keepAliveTime`之后关闭非核心线程，核心线程通过`workQueue.take()`阻塞线程避免自身被回收。

#### 线程回收

`getTask()`获取不到任务时，执行`processWorkerExit()`进行线程回收

```java
     private void processWorkerExit(Worker w, boolean completedAbruptly) {
        if (completedAbruptly) // If abrupt, then workerCount wasn't adjusted
            //减少工作线程数
            decrementWorkerCount();

        final ReentrantLock mainLock = this.mainLock;
        mainLock.lock();
        try {
            completedTaskCount += w.completedTasks;
            workers.remove(w);
        } finally {
            mainLock.unlock();
        }
        //尝试终止线程池
        tryTerminate();

        int c = ctl.get();
       //线程池处于RUNNABLE或SHUTDOWN状态
        if (runStateLessThan(c, STOP)) {
            if (!completedAbruptly) {
                //根据是否配置 allowCoreThreadTimeout 来判断线程池的最小保留线程数
                int min = allowCoreThreadTimeOut ? 0 : corePoolSize;
                //阻塞队列还有任务的话，至少保留一个线程去执行任务
                if (min == 0 && ! workQueue.isEmpty())
                    min = 1;
                if (workerCountOf(c) >= min)
                    return; // replacement not needed
            }
            //因为线程中断，导致没有线程执行阻塞队列任务
            //尝试新建线程去执行任务
            addWorker(null, false);
        }
    }
```



#### 任务拒绝

当线程池处于`非RUNNABLE`状态或者`workerCount > maximumPoolSize`时，就会执行`reject(runnable)`拒绝策略

```java
public void execute(Runnable command) {
        if (command == null)
            throw new NullPointerException();
        int c = ctl.get();
        if (workerCountOf(c) < corePoolSize) {
            if (addWorker(command, true))
                return;
            c = ctl.get();
        }
        if (isRunning(c) && workQueue.offer(command)) {
            int recheck = ctl.get();
            if (! isRunning(recheck) && remove(command)) //当前不是RUNNABLE，移除当前任务
                reject(command);
            else if (workerCountOf(recheck) == 0)
                addWorker(null, false);
        }
        else if (!addWorker(command, false))//添加非核心线程失败，表示已经超出了maximumPoolSize
            reject(command);
    }

    final void reject(Runnable command) {
        handler.rejectedExecution(command, this);
    }

    public static class AbortPolicy implements RejectedExecutionHandler {
        /**
         * Creates an {@code AbortPolicy}.
         */
        public AbortPolicy() { }

        public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
            throw new RejectedExecutionException("Task " + r.toString() +
                                                 " rejected from " +
                                                 e.toString());
        }
    }
```

通过自定义类实现`RejectedExecutionHandler`接口，执行对应的拒绝策略。默认拒绝策略是`AbortPolicy`。

#### 总结

![img](/images/640-1293801.)

线程里容纳了一定的`Worker(执行任务的线程)`。根据线程池状态的不同，有新任务加入时，执行不同的操作。

- 核心线程未满(`workerCount < corePoolSize`)，创建`核心线程`执行任务
- 核心线程已满(`workerCount>= corePoolSize`)，将任务添加到`workQueue`中
- `workQueue`已满(`workerCount< maximumPoolSize`)，创建`非核心线程`执行任务
- 最大任务队列已满(`workerCount = maximumPoolSize`)，执行`handler`拒绝策略



线程执行任务时，先执行`Worker的firstTask`，后续从`getTask()`获取任务去执行，根据线程池的容量区间获取任务的方式也不同

- 容量区间位于`0~corePoolSize(核心线程)`，执行`workQueue.take()`阻塞获取任务，不会被回收。*若设置`allowCoreThreadTimeout(true)`也会被回收*
- 容量区间位于`corePoolSize~maximumPoolSize(非核心线程)`，执行`workQueue.poll(keepAliveTime)`获取任务，超出`keepAliveTime`该线程就会被回收



### 线程池中的线程策略

#### 增长策略

默认情况下，线程池是根据任务先**创建足够核心线程数的线程去执行任务**，当核心线程满了时**将任务放入等待队列**。待队列满了的时候，继续**创建新线程执行任务直到达到最大线程数停止**。此时再进入新任务的话，那就只能**执行拒绝策略或是抛出异常**。

#### 收缩策略

当线程池内的线程数大于核心线程数并且当前存在空闲线程并且空闲线程的空闲时间大于`keepAliveTime`时，会对空闲线程进行回收，直到线程数量等于核心线程数(`corePoolSize`)为止。

###  线程池的使用注意

1. 线程池不要用`Executors`的方式去创建，应该利用`ThreadPoolExecutor`的方式，这样可以帮助更好理解实现方式以及避免资源消耗过度的问题。

   **`fixThreadPool以及singleThreadPool`,由于设置的等待队列长度为Integer.MAX_VALUE，导致大量请求堆积，消耗大量资源。**

   **`cachedThreadPool以及scheduledThreadPool`,由于运行允许创建的线程数量为Integer.MAX_VALUE，可能创建大量的请求，消耗大量资源。**

2. 针对具体情况去配置线程池参数，不同的任务类别应采用不同规模的线程池，任务类别分为3种：

   - **`CPU密集型任务(需要进行大量计算，处理)`**：线程池中线程个数尽量少，不应大于CPU核心数，避免出现每个线程都需要长时间使用但是线程过多去抢占资源。建议`corePoolSize`为**n+1**

   - **`IO密集型任务(主要时间都在IO，CPU空闲时间比较多)`**：线程池可以配置尽量多的线程，由于CPU大部分时间空闲，可以提高CPU的利用率。建议`corePoolSize`为**2n**

   - **`混合型任务`**：如果可以拆分，则拆分成一个CPU密集型以及IO密集型任务，只要执行任务效率相差不大。若相差太大则没必要拆分。

###  补充知识

1. `submit()`和`execute()`区别

   `submit()`返回一个`future`，根据`future`可以判断任务是否完成--实现`Callable`接口

   `execute()`无返回值。只是执行了任务，不知道结果如何 -- 实现`Runnable`接口

2. `BlockingQueue`介绍

   {% post_link Java-BockingQueue阻塞队列 %}

3. `AbstractQueuedSynchronizer`介绍

   {% post_link Java-AbstractQueuedSynchronizer简介 %}
   
4. 为什么存在`newSingleThreadExecutor`?不能使用`newFixedThreadPool(1)`代替

   再次对比一下两者的源码

   ```java
   /*     
   * Creates an Executor that uses a single worker thread operating
        * off an unbounded queue, and uses the provided ThreadFactory to
        * create a new thread when needed. Unlike the otherwise
        * equivalent {@code newFixedThreadPool(1, threadFactory)} the
        * returned executor is guaranteed not to be reconfigurable to use
        * additional threads.
          */
   public static ExecutorService newSingleThreadExecutor() {
           return new FinalizableDelegatedExecutorService
               (new ThreadPoolExecutor(1, 1,
                                       0L, TimeUnit.MILLISECONDS,
                                       new LinkedBlockingQueue<Runnable>()));
       }
   
   
   
       public static ExecutorService newFixedThreadPool(int nThreads) {//nThreads为1
           return new ThreadPoolExecutor(nThreads, nThreads,//1 , 1
                                         0L, TimeUnit.MILLISECONDS,
                                         new LinkedBlockingQueue<Runnable>());
       }
   ```

   两者之间最大的差异就在于包装类的区别：

   - `newSingleThreadExecutor`——FinalizableDelegatedExecutorService
   - `newFixedThreadPool`——ThreadPoolExecutor

   ```java
    private static class FinalizableDelegatedExecutorService
               extends DelegatedExecutorService {
           FinalizableDelegatedExecutorService(ExecutorService executor) {
               super(executor);
           }
           protected void finalize() {
               super.shutdown();
           }
       }
       private static class DelegatedExecutorService
               extends AbstractExecutorService {
           // Android-added: @ReachabilitySensitive
           // Needed for FinalizableDelegatedExecutorService below.
           @ReachabilitySensitive
           private final ExecutorService e;
           DelegatedExecutorService(ExecutorService executor) { e = executor; }
           public void execute(Runnable command) { e.execute(command); }
           public void shutdown() { e.shutdown(); }
           public List<Runnable> shutdownNow() { return e.shutdownNow(); }
           public boolean isShutdown() { return e.isShutdown(); }
           public boolean isTerminated() { return e.isTerminated(); }
          ...
       }
   
   ```

   `DelegatedExecutorService`就是`ExecutorService接口实现类`的包装类，包装后的对象仅仅暴露`ExecutorService`接口方法，而`FinalizableDelegatedExecutorService`屏蔽了大多数实现方法，避免被强制转换时修改配置导致行为出现问题。

   ```java
       private static void testFixed(){
           ExecutorService s = Executors.newFixedThreadPool(1);
           ((ThreadPoolExecutor)s).setCorePoolSize(2);
           System.err.println("ss "+((ThreadPoolExecutor) s).getCorePoolSize());
       }
   
       private static void testSingle(){
           ExecutorService s = Executors.newSingleThreadExecutor();
           ((ThreadPoolExecutor)s).setCorePoolSize(2);
           System.err.println("ss"+((ThreadPoolExecutor) s).getCorePoolSize());
       }
   
   输出结果：
     ss 2
   Exception in thread "main" java.lang.ClassCastException: java.util.concurrent.Executors$FinalizableDelegatedExecutorService cannot be cast to java.util.concurrent.ThreadPoolExecutor
   	at thread.TestThreadPool.testSingle(TestThreadPool.java:31)
   	at thread.TestThreadPool.main(TestThreadPool.java:20)
   
   ```

   观察上面的结果，可以看出`newSingleThreadExecutor`与`newFixedThreadPool`最大区别在于，前者不可配置参数，可以保证**任务的串行执行**，后者在运行的过程中可以通过强制类型转换得到`ThreadPoolExecutor`去进行参数的重新配置，导致**任务可能变成并行执行**。使应用的执行逻辑出现错误，导致应用异常。

   


###  内容引用

[线程池](https://juejin.im/post/5bdbbc3d6fb9a0224a5e486f#heading-14)

[线程池深入解析](https://mp.weixin.qq.com/s/HpMu_QI_N-J18fNJG96yzA)

[Java线程池实现原理及其在美团业务中的实践](https://tech.meituan.com/2020/04/02/java-pooling-pratice-in-meituan.html)

