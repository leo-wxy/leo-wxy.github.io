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

更准确地说，`synchronized`建立的是一组**获取锁 -> 执行临界区 -> 释放锁**的同步语义：线程进入同步块前，需要先成功获取同一把锁；线程退出同步块时，会把临界区内对共享变量的修改刷新出去。后续再次获取**同一把锁**的线程，才能可靠地看到这些结果。

因此它保证的是**同步范围内**的复合操作正确性，而不是“某段代码只要写过一次`synchronized`，整个对象就天然线程安全”。

## `synchronized`使用

判断两个线程之间会不会互斥，关键不是它们都写了`synchronized`，而是**它们争用的是不是同一个monitor**。如果锁对象不同，即使代码长得很像，也不会形成互斥；如果最终落到的是同一个对象锁或同一个`Class`锁，就会互斥执行。

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

再看一个更直接的判断例子：

```java
class A {
    public synchronized void a() {
    }

    public synchronized void b() {
    }
}

A a1 = new A();
A a2 = new A();
```

如果两个线程分别执行`a1.a()`和`a2.a()`，它们**不能**构成同步，因为这里争用的是两把不同的对象锁：一把是`a1`，另一把是`a2`。



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

如果把上面的类改成：

```java
class A {
    public static synchronized void a() {
    }

    public static synchronized void b() {
    }
}
```

那么即使通过不同实例去触发调用，最终竞争的也都是`A.class`这一把类锁，因此会形成同步。



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

如果把`synchronized(this)`放到`Runnable`实现中，也很容易看出“同一把锁”和“不同锁对象”的区别：

```java
public class SyncThread implements Runnable {
    private static int count;

    @Override
    public void run() {
        synchronized (this) {
            for (int i = 0; i < 5; i++) {
                System.err.println(Thread.currentThread().getName() + " " + (count++));
            }
        }
    }
}
```

当两个线程共享同一个`SyncThread`实例时，争用的是同一个`this`，因此会串行执行；如果两个线程分别持有不同的`SyncThread`实例，那么锁对象不同，就不会互斥。

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

对象锁的本质是：**锁跟着具体实例走**。因此“同一个类的两个对象”并不天然互斥，只有访问的是同一个实例，才是在竞争同一把对象锁。

### 类锁

> 类似`synchronized(obj.class)`就为类锁的一种，其他还包括`synchronized`修饰的静态方法`public synchronized static void method()`。

**控制静态方法之间的同步。**由于Java类中只会有一个Class对象，类的不同实例之间共享该类的Class对象。类锁对应的锁数量也就只有一个，就是锁住Class对象。

这也是为什么`public static synchronized`和`synchronized(SomeClass.class)`的同步范围会跨越所有实例：它们最终竞争的都是同一个类对象监视器。



| 类型                   | 锁对象   | 锁的数量                       | 实现形式                                                     | 使用场景             |
| ---------------------- | -------- | ------------------------------ | ------------------------------------------------------------ | -------------------- |
| 对象锁(包括实例方法锁) | 实例对象 | 多个<br>类的对象实例可以有多个 | `synchronized void method()`<br>`synchronized(this){}`       | 控制方法间的同步     |
| 类锁(包括静态方法锁)   | 类对象   | 1个<br>一个类只会有一个类对象  | `synchronized static void method()`<br>`synchronized(obj.class)` | 控制静态方法间的同步 |



## `synchronized`原理

JVM基于进入和退出`monitor`对象来实现**代码块同步**和**方法同步**。

从对象实现上看，普通Java对象的对象头中会有`Mark Word`这一部分运行时数据，锁状态的变化会先体现在这里。无锁、偏向锁、轻量级锁这些状态，本质上都和对象头标记有关；只有当竞争进一步加剧时，锁才会膨胀并关联到重量级`monitor`。所以`synchronized`既有字节码层面的`monitorenter/monitorexit`，也有对象头层面的状态切换。

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

另外，`synchronized`还是**可重入锁**。同一个线程在已经持有对象监视器的前提下，再次进入该对象的同步方法或同步块是允许的，只不过monitor的进入计数会继续增加，退出时再逐步减回去。

和`monitor`直接相关的几个方法也很容易混淆：

- `wait()`必须在已经持有该对象监视器时调用，调用后会释放当前monitor，并进入等待队列。
- `notify()/notifyAll()`同样要求在线程持有monitor时调用，它们只是发出通知，被唤醒线程还需要重新竞争锁。
- `sleep()`只是让当前线程休眠，不会释放已经持有的对象锁。

{% fullimage /images/synchronized-monitor.png,同步方法关系,同步方法关系%}
