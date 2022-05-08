---
title: Java-ReentrantLock原理及解析
date: 2018-12-19 15:06:32
tags: Java
top: 9
---





一般的锁都是配合`synchronized`使用的，实际上在`java.util.concurrent.locks`还提供了其他几个锁的实现，拥有更加强大的功能和更好的性能。

## 锁的分类

### 可重入锁

> `可重入锁`：任意线程在获取该锁后能够再次获取锁时不会被阻塞。
>
> **当前线程恶可以反复加锁，但必须释放同样多次数的锁，否则会导致锁不会释放。可以避免`死锁`**

#### 原理

通过组合自定义同步器(`AQS`)实现锁的获取与释放

- 再次进行`lock()`，需要判断当前是否为已获得锁的线程，如果是，计数+1
- 执行`unlock()`，计数-1

在释放锁后，如果计数不为0，就会导致程序卡死。

#### 分类

- `synchronized`修饰的方法或代码块
- `ReentrantLock`

### 公平锁与非公平锁

#### 公平锁

**多个线程按照申请锁的先后顺序获取锁**。内部持有一个等待队列，按照`FIFO`取出线程获取锁。

实现：`ReentrantLock(true)`

#### 非公平锁

**多个线程不是按照申请锁的先后顺序去获取锁。**

`非公平锁`的性能高于`公平锁`，但是可能发生**线程饥饿(某个线程长时间无法获得锁)**。

实现：`synchronized`和`ReentrantLock(false)默认非公平`

### 读写锁和排他锁

#### 读写锁

**同一时刻允许多个读线程访问。**分为了**读锁**和**写锁**，`读锁`允许多个线程获取读锁，访问同一个资源；`写锁`只允许一个线程获取写锁，不允许同时访问同一资源。

**在读多写少的情况下，大大提高了性能。**

> 即使用读写锁，在写线程访问时，所有读线程和其他写线程都会被阻塞。

实现：`ReentrantReadWhiteLock`

#### 排他锁

**同一时刻只允许一个线程访问**。

实现：`ReentrantLock`、`synchronized`



### 死锁

> 两个或两个以上的进程在执行过程中，由于竞争资源或者由于彼此通信而造成的一种阻塞现象，若无外力作用，他们都将无法推进下去。

死锁形成必须要求四个条件：

- **互斥条件**：一个资源每次只能被一个线程使用

- **请求与保持条件**：一个线程引请求资源而阻塞时，对已获得的资源保持不放
- **不剥夺条件**：线程已获得的资源，在未使用完之前，不能强行剥夺
- **循环等待条件**：若干进程之间形成一种头尾相接的循环等待资源关系



## Lock接口

>  在Java中锁是用来控制多个线程访问共享资源的方式。在Java SE5.0之后新增Lock接口。提供了与`synchronized`关键字类似的同步功能，只是在使用时需要显式的获取和释放锁，缺点就是无法像`synchronized`可以隐式的释放锁，但是可以自由操作获取锁和释放锁。

### `synchronized`的不足之处

- 如果只是只读操作，应该多线程一起执行会更好，但是`synchronized`在**同一时间只能一个线程执行**。
- `synchronized`无法知道线程是否获取锁，而且无法主动进行释放锁
- 使用`synchronized`获取锁后，如果发生阻塞，就会导致所有线程等待锁释放

### 提供方法

#### `lock()`-获取锁

> 执行时，如果锁处于空闲状态，当前线程获得锁。如果锁已被其他线程持有，将禁用当前线程，直到该线程获取锁。
>
> **不会响应中断，直到获取锁成功才会进行响应。**

#### `lockInterruptibly()`-获取锁，响应中断

> **获取锁时，优先响应中断，而不是先去进行获取。**

#### `tryLock()`-非阻塞获取锁

> 非阻塞获取锁，立即返回获取锁结果，`true`-成功，`false`-失败

#### `tryLock(time,unit)`-指定时间获取锁

> 指定时间获取锁，会响应中断
>
> - `time`内获取锁立即返回`true`
> - `time`内线程中断会立即返回获取锁结果
> - `time`时间结束后，立即返回获取锁结果

#### `unlock()`-释放锁

> 当前线程释放持有锁，**锁只能由持有者释放，如果并未持有锁，执行解锁方法，就会抛出异常**。

#### `newCondition()`-获取锁条件

> 返回该锁的`Condition`实例，实现**多线程通信**。该组件会与当前锁绑定，当前线程只有获取了锁，才能调用组件的`await()`方法，调用后，线程释放锁。





## ReentrantLock

> 一个可重入的互斥锁，具备一样的线程重入特性







#### 特性

- 尝试获得锁
- 获取到锁的线程能够响应中断

## 读写锁

> ReentrantLock是完全互斥排他的，这样其实效率不高

## 使用方式

```java
public class ReenTrantLockTest implements Runnable {
    private Lock lock = new ReentrantLock();
    private Condition condition = lock.newCondition();

    public void test() {
        try {
            //获得同步锁
            lock.lock();
            System.err.println("获取锁" + System.currentTimeMillis());
            condition.await();
            System.err.println();
        } catch (
                InterruptedException e) {
            e.printStackTrace();
        } finally {
            //释放同步锁
            lock.unlock();
        }
    }

    public static void main(String[] args) throws InterruptedException {
        ReenTrantLockTest test = new ReenTrantLockTest();
        Thread t1 = new Thread(test);
        Thread t2 = new Thread(test);
        t1.start();
        t2.start();
        t1.join();
        t2.join();
        System.err.println("结束");
    }

    @Override
    public void run() {
        test();
    }
}
```

相比`synchronized`增加了一些高级功能：

- **等待可中断**：当持有锁的线程长期不释放锁的时候，正在等待的线程可以选择放弃等待，去操作其他事情。

- **公平锁**：`多个线程在等待同一个锁时，必须按照申请锁的时间来依次获得锁。` `synchronized`是非公平锁，即`在锁被释放时，任何一个等待锁的线程都有机会获得锁。`这样就有可能会产生 **饥饿现象(有些线程可能永远无法获得锁)**。`ReenTrantLock`默认非公平锁，在构造时修改参数即可变为公平锁。

  ```java
  public class LockFairTest implements Runnable {
      //true为公平锁  false为非公平锁 默认false
      private static Lock lock = new ReentrantLock(true);
      AtomicInteger iii = new AtomicInteger(0);
  
      @Override
      public void run() {
          while (iii.get() < 20) {
              lock.lock();
              iii.getAndIncrement();
              try {
                  System.err.println(Thread.currentThread().getName() + "获得锁");
              } finally {
                  lock.unlock();
              }
          }
      }
  
      public static void main(String[] args) {
          LockFairTest test = new LockFairTest();
  
          Thread t1 = new Thread(test);
          Thread t2 = new Thread(test);
          Thread t3 = new Thread(test);
          Thread t4 = new Thread(test);
  
          t1.start();
          t2.start();
          t3.start();
          t4.start();
      }
  }
  输出结果：
  公平锁：
  Thread-0获得锁
  Thread-1获得锁
  Thread-2获得锁
  Thread-3获得锁
  非公平锁：
  Thread-2获得锁
  Thread-2获得锁
  Thread-2获得锁
  Thread-2获得锁
  ```

- **锁绑定多个条件**：一个`ReenTrantLock`对象可以通过多次调用`newCondition()`同时绑定多个`Condition`对象。在`synchronized`只能实现一个隐含的条件，要多关联只能额外添加锁。

## 总结

- Lock类可以实现线程同步，获得锁需要执行`lock`，释放锁使用`unlock`
- Lock分为公平锁(按照顺序)和不公平锁(不按顺序)
- Lock还有读锁和写锁。**读读共享，写写互斥，读写互斥**。

## 自定义重入锁

```java
public class CustomReetrantLock {
    boolean isLocked = false;
    Thread lockedBy = null;
    int lockedCount = 0;

    public synchronized void lock() throws InterruptedException {
        Thread callThread = Thread.currentThread();
        while (isLocked && lockedBy != Thread.currentThread()) {
            wait();
        }
        isLocked = true;
        lockedCount++;
        lockedBy = callThread;
    }

    public synchronized void unLock() {
        if (Thread.currentThread() == this.lockedBy) {
            lockedCount--;
            if (lockedCount == 0) {
                isLocked = false;
                notify();
            }
        }
    }
}

```

