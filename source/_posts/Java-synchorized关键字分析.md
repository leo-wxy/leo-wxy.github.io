---
title: Java-synchronized原理及解析
date: 2018-12-18 15:07:11
tags: Java
top: 10
---

# synchronized

## `synchronized`场景

一般用在以下场景

### 修饰实例方法（锁定当前对象实例）

```java
public class SynchronizedInstance{
  public synchronized void test(){
    //...
  }
}
```

> 锁定的是访问该方法的实例对象，如果在多个线程中的不同对象访问该方法，则不可保证互斥同步效果



### 修饰静态方法(锁定当前类Class对象)

```java
public class SynchronizedStatic{
  public synchronized static void test(){
    //...
  }
}
```

> 由于静态方法是类方法，所以锁的是包含这个方法的类，也就是类对象；如果多个线程调用不同实例对象，也会有互斥同步效果



### 修饰代码块(锁定指定对象)

```java
public class Singleton{
  private static volatile Suingleton mInstance;
  public static Singleton getInstance(){
    if(mInstance==null){
      synchronized(Singleton.class){
        if(mInstance==null){
          mInstance = new Singleton();
        }
      }
    }
    return mInstance;
  }
}
```

> 



>`synchronized`可作用于一段代码或方法，既可以保证可见性也可以保证原子性。
>
>**可见性**：通过`synchronized`能保证同一个时刻只有一个线程获取锁然后执行同步代码，并且在释放锁之前将会对变量的修改刷新到主存中。
>
>**原子性**：要么不执行，要么执行到底。
>
>锁类型为：**可重入锁，非公平锁，独占锁，互斥锁**

{% fullimage /images/synchronized.png,synchronized关键字,synchronized关键字%}

## `synchronized`作用

- 确保线程互斥的访问代码块，同一时刻只有一个方法进入临界区，其他线程必须等到当前线程执行完毕才能使用。
- 保证共享变量的修改能即时可见
- 有效解决重排序问题

## `synchronized`使用

### 修饰实例方法，锁的是当前对象实例(this)

> 一个对象中的加锁方法只允许一个线程访问。但要注意这种情况下锁的是访问该方法的实例对象， 如果多个线程不同对象访问该方法，则无法保证同步。

```java
public class SynchronizedMethodTest { 
   public synchronized void method1(){
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.err.println("method1 finish" + System.currentTimeMillis());
    }

    public synchronized void method2(){
        try {
            Thread.sleep(2000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.err.println("method2 finish"+ System.currentTimeMillis());
    }

    public static void main(String[] args){
        final SynchronizedMethodTest test =new SynchronizedMethodTest();
        new Thread(test::method1).start();
        new Thread(test::method2).start();
    }
}

输出结果：
method1 finish 1545188801152
method2 finish 1545188803157
```



### 修饰静态方法，锁的是当前Class对象(静态方法属于类，而不是对象) 

> 由于静态方法是类方法， 所以这种情况下锁的是包含这个方法的类，也就是类对象；这样如果多个线程不同对象访问该静态方法，也是可以保证同步的。

```java
public class SynchronizedStaticMethodTest {
    public synchronized static void method1() {
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.err.println("method1 finish" + System.currentTimeMillis());
    }

    public synchronized static void method2() {
        try {
            Thread.sleep(2000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.err.println("method2 finish" + System.currentTimeMillis());
    }

    public static void main(String[] args) {
        new Thread(SynchronizedStaticMethodTest::method1).start();
        new Thread(SynchronizedStaticMethodTest::method2).start();
    }
}

输出结果
method1 finish 1545189344322
method2 finish 1545189346327
```



### 修饰代码块，锁的是括号里的对象

> 修饰代码块 其中普通代码块 如`synchronized（obj）` 这里的obj 可以为类中的一个属性、也可以是当前的对象，它的同步效果和修饰普通方法一样；
> Synchronized方法控制范围较大， 它会同步对象中所有Synchronized方法的代码。
> Synchronized代码块控制范围较小， 它只会同步代码块中的代码， 而位于代码块之外的代码是可以被多个线程访问的。
>
> **就是 Synchronized代码块更加灵活精确。**

```java
public class SynchronizedCodeBlockTest {
    public void method1() {
        synchronized (this) {
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.err.println("method1 finish" + System.currentTimeMillis());
        }
    }

    public void method2() {
        synchronized (this) {
            try {
                Thread.sleep(2000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.err.println("method2 finish" + System.currentTimeMillis());
        }
    }

    public static void main(String[] args) {
        final SynchronizedCodeBlockTest test =new SynchronizedCodeBlockTest();
        new Thread(test::method1).start();
        new Thread(test::method2).start();
    }
}

输出结果：
method1 finish 1545189694303
method2 finish 1545189696308
```

### 修饰代码块，但是指定了修饰类，此时锁的是括号里的Class类对象

> Synchronized方法 （obj.class）静态代码块它的同步效果和修饰静态方法类似。

```java
public class Test{
    public void method(){
        synchronized(Test.class){
            try{
                Thread.sleep(500);
            }catch(Exception e){
                e.printStackTrace();
            }
        }
    }
}
```



## `synchronized`锁的区别

### 对象锁

> 类似`synchronized(this)`就为对象锁的一种，其他的还包括`synchronized`修饰的实例方法`public synchronized void method() `。

**控制方法间的同步。**Java中的所有对象都包含一个`互斥锁`，这个锁由JVM自动获取和释放。当线程进入`synchronized`的时候会获取该对象的锁，如果有其他线程已经获得了这个对象锁，当前线程就需要等待其他线程执行完毕——`synchronized`正常返回或者抛出异常终止。JVM就会自动释放该锁。

### 类锁

> 类似`synchronized(obj.class)`就为类锁的一种，其他还包括`synchronized`修饰的静态方法`public synchronized static void method()`。

**控制静态方法之间的同步。**由于Java类中只会有一个Class对象，类的不同实例之间共享该类的Class对象。类锁对应的锁数量也就只有一个，就是锁住Class对象。



| 类型                   | 锁对象   | 锁的数量                       | 实现形式                                                     | 使用场景             |
| ---------------------- | -------- | ------------------------------ | ------------------------------------------------------------ | -------------------- |
| 对象锁(包括实例方法锁) | 实例对象 | 多个<br>类的对象实例可以有多个 | `synchronized void method()`<br>`synchronized(this){}`       | 控制方法间的同步     |
| 类锁(包括静态方法锁)   | 类对象   | 1个<br>一个类只会有一个类对象  | `synchronized static void method()`<br>`synchronized(obj.class)` | 控制静态方法间的同步 |



## `synchronized`原理

JVM基于进入和退出`monitor`对象来实现**代码块同步**和**方法同步**。

- **代码块同步**

  在编译后通过`monitorenter`插入到同步代码的开始处，将`monitorexit`插入到代码结束处和异常处，反编译字节码时就可以看到相关指令。**JVM要保证每个monitorenter必须有对应的monitorexit。**

  `monitorenter`：每个对象都有一个监视器锁(`monitor`)，当某个monitir被某个线程占用时就会处于锁定状态，线程执行`monitorenter`指令时会尝试获取`monitor`的所有权，尝试获取对象的锁。

  - monitor进入数为0，则该进程进入monitor，然后将进入数置为1，该进程即为monitor的持有者
  - 如果线程已占有monitor，只是重新进入，则monitor进入数+1
  - 如果其他线程已占用monitor，则该线程处于堵塞状态，直至monitor进入数为0，在尝试重新获取monitor的所有权

  `monitorexit`：执行`monitorexit`的线程必须是objectref所对应的monitor持有者。指令执行时，monitor进入数-1，如果-1后进入数为0，则线程退出monitor，不再是monitor持有者。其他被这个monitor阻塞的线程就可以尝试去获取monitor。

  > 反编译命令 `javap -v **.class`

  ```java
           3: monitorenter
           4: ldc2_w        #16                 // long 2000l
           7: invokestatic  #4                  // Method java/lang/Thread.sleep:(J)V
            ...
          45: aload_1
          46: monitorexit
          47: goto          55
          50: astore_3
          51: aload_1
          52: monitorexit
  
  ```

- **方法同步**

  `synchronized`在`method_info`会添加`ACC_synchronized`标记，线程执行会识别该标记，获取对应的锁。

  ```java
  public synchronized void method2();
      descriptor: ()V
      flags: ACC_PUBLIC, ACC_SYNCHRONIZED
      Code:
        stack=4, locals=2, args_size=1
           0: ldc2_w        #16                 // long 2000l
           3: invokestatic  #4                  // Method java/lang/Thread.sleep:(J)V
  
  ```

两者实现细节不同，**本质上都是对一个对象的监视器(monitor)获取，任意一个对象都拥有自己的监视器。**当这个对象由代码块同步或者方法同步调用时，**执行方法的线程必须先获取对象的监视器才能进入同步块或同步方法，没有获取到对象监视器的线程就会被堵塞在入口处，变为Blocked堵塞状态。当成功获取监视器线程释放了锁后，会唤醒堵塞的同步队列的线程，使其重新尝试获取监视器。**

{% fullimage /images/synchronized-monitor.png,同步方法关系,同步方法关系%}







理解Java中的synchronized关键字。
指标：理解synchronized的含义、明确synchronized关键字修饰普通方法、静态方法和代码块时锁对象的差异。

有如下一个类A

```java
class A {
    public synchronized void a() {
    }

    public synchronized void b() {
    }
}
```

然后创建两个对象

```java
A a1 = new A();
A a2 = new A();
```

然后在两个线程中并发访问如下代码：
Thread1                       Thread2
a1.a();                       a2.a();

请问二者能否构成线程同步？

如果A的定义是下面这种呢？

```java
class A {
    public static synchronized void a() {
    }

    public static synchronized void b() {
    }
}
```

# 答案

Java多线程中的同步机制会对资源进行加锁，保证在同一时间只有一个线程可以操作对应资源，避免多程同时访问相同资源发生冲突。Synchronized是Java中的关键字，它是一种同步锁，可以实现同步机制。

> Synchronized作用:

- 确保线程互斥的访问同步代码块
- 保证共享变量的修改能够及时可见
- 有效解决重排序问题

> wait(),notify(),notifyAll(),sleep()作用

- wait 调用线程 释放锁，然后进入休眠
- sleep thread的一个操作方法，不释放锁直接进入休眠
- notify 唤醒等待队列中的第一个相关进程
- notifyAll 唤醒所有

> Synchronized主修修饰对象为以下三种：

1. 修饰普通方法 一个对象中的加锁方法只允许一个线程访问。但要注意这种情况下锁的是访问该方法的实例对象， 如果多个线程不同对象访问该方法，则无法保证同步。
2. 修饰静态方法 由于静态方法是类方法， 所以这种情况下锁的是包含这个方法的类，也就是类对象；这样如果多个线程不同对象访问该静态方法，也是可以保证同步的。
3. 修饰代码块 其中普通代码块 如Synchronized（obj） 这里的obj 可以为类中的一个属性、也可以是当前的对象，它的同步效果和修饰普通方法一样；Synchronized方法 （obj.class）静态代码块它的同步效果和修饰静态方法类似。
   Synchronized方法控制范围较大， 它会同步对象中所有Synchronized方法的代码。
   Synchronized代码块控制范围较小， 它只会同步代码块中的代码， 而位于代码块之外的代码是可以被多个线程访问的。

简单来说 就是 Synchronized代码块更加灵活精确。

> 示例代码

```java
public class SyncThread implements Runnable {
    private static int count;
    public SyncThread() {
        count = 0;
    }
    @Override
    public void run() {
        synchronized (this) {
            for (int i = 0; i < 5; i++) {
                try {
                    System.err.println(Thread.currentThread().getName() + " " + (count++));
                    Thread.sleep(100);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }
    }
    public static int getCount() {
        return count;
    }
}
```

# 修饰代码块

```java
 public static void main(String[] args) {
        SyncThread syncThread = new SyncThread();
        Thread thread1 = new Thread(syncThread, "sync1");
        Thread thread2 = new Thread(syncThread, "sync2");
        thread1.start();
        thread2.start();
    }
```

访问的同一个对象时，同一时刻只能有一个线程执行，执行代码块是会锁定当前对象，所以需要执行完才能释放，下一个线程才能继续执行并锁定对象

> 运行结果

```log
sync1 0
sync1 1
sync1 2
sync1 3
sync1 4
sync2 5
sync2 6
sync2 7
sync2 8
sync2 9
```

# 修饰对象

```java
 public static void main(String[] args) {
        Thread thread1 = new Thread(new SyncThread(), "sync1");
        Thread thread2 = new Thread(new SyncThread(), "sync2");
        thread1.start();
        thread2.start();
    }
```

这时创建了两个SyncThread对象，线程1执行对象1中的同步代码，线程2执行的是对象2的代码，这时两把锁分别锁定SyncThread1和SyncThread2对象，两把锁互不干扰也不互斥，所以同时执行。

> 运行结果

```log
sync1 0
sync2 1
sync1 2
sync2 3
sync1 4
sync2 5
sync1 6
sync2 7
sync1 8
sync2 9
```

问题1 ：不能同步

- a1.a()锁是a1 a2.b()锁是a2 不是同一把锁 所以不同步
  问题2：能同步
- 锁都为A.class对象，是统一把锁