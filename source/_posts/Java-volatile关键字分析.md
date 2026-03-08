---
title: Java-volatile原理及解析
date: 2018-12-17 15:53:52
tags: Java
top: 10
---

<!--缓存一致性 指令重排序概念-->

{% fullimage /images/volatile.png,volatile相关概念,volatile相关概念%}

## volatile基础概念

***volatile的主要作用是保证可见性以及有序性，不一定保证原子性。***

**JVM提供的最轻量级的同步机制。**

更准确地说，`volatile`更擅长解决的是**线程之间的通信问题**，例如一个线程修改状态、另外一个线程及时感知这个状态变化。它并不提供互斥访问能力，因此不能替代锁去保护一段需要整体保持一致性的临界区代码。

当一个变量被`volatile`关键字修饰后，就会具备两层语义：

- **保证此变量对所有线程的可见性，这里指  当一条线程修改了这个变量的值，新值对于其他线程来说是立即可得知的。**
- **禁止进行指令重排序优化**

如果从Java内存模型的角度来表述，还可以进一步记成一条规则：

- **对一个`volatile`变量的写，happens-before 于后续任意线程对这个变量的读**

这条规则的含义是：前一个线程在写这个`volatile`变量之前对共享数据做的操作，对于后面读取到这个`volatile`新值的线程来说，也是可见的。

### volatile 保证可见性

在使用`volatile`关键字修饰一个变量后，该变量在一个线程中被修改后，会发生如下事情：

1. 修改后，修改的变量值会强制立即写入主内存中
2. 然后强制过期其他线程中工作内存中的缓存，使缓存无效
3. 由于缓存无效，其他线程需要读取该变量值时，会强制重新从主内存中读取

> 当访问共享变量时，多个线程也会在自己的工作内存中有一份共享变量的副本。当某个线程更改了自己工作内存中的数据时，由于某些原因（线程阻塞）没有及时的刷新数据至主内存，然后其他线程的工作内存中的数据还是老数据。就会导致`缓存一致性`问题。
>
> **缓存一致性**：当其他线程读取该变量时，发现该缓存是无效的，就会从主内存中重新读取。

这里要注意：**可见性并不等于线程安全。**`volatile`能保证“一个线程写入后，其他线程尽快看到这个新值”，但如果多个线程围绕这个值做复合操作，结果依然可能出错。

例如：

- `volatile boolean flag` 这种状态位，很适合用来做线程间通知。
- `volatile int count` 再配合 `count++` 这类读-改-写操作，就不能仅靠 `volatile` 保证正确性。

这也是`volatile`最典型的使用姿势：**一个线程负责写状态，其他线程负责观察状态变化。**只要业务语义能收敛到这种“发布-观察”模型，`volatile`通常就比较合适。

{% fullimage /images/volatile-process.png,volatile可见性,volatile可见性%}



### volatile 保证有序性

`volatile`禁止指令重排序，可以在一定程度上保证有序性。

**指令重排序**：JVM为了优化指令，提高程序运行效率，在不影响**单线程**执行结果的前提下，尽可能的提高并行度。

volatile关键字通过提供“**内存屏障(重排序时不能把后面的指令重排序到内存屏障之前的位置)**”的方式来防止指令被重排序，为了实现volatile的内存语义，编译器在生成字节码时，会在指令序列中插入内存屏障来禁止特定类型的处理器重排序。`加入volatile关键字的代码会多出一个lock前缀指令`。

这里的“禁止重排序”也有边界：它并不是让整个方法中的所有指令都完全不能重排，而是**禁止那些会破坏`volatile`读/写内存语义的重排序**。也就是说，约束的重点是“`volatile`变量读写前后”的关键顺序，而不是把所有优化都彻底关掉。

内存屏障提供如下功能：

- 重排序时不会把后面的指令重排序到内存屏障之前的位置—`有序性`
- 本CPU的Cache立即写入内存，并且会引起别的CPU或者别的内核无效化其Cache，可以是对volatile变量的修改对其他CPU可见—`可见性`

`内存屏障`在`volatile`读写时是不同位置插入`lock`指令

- `volatile读`

  在`volatile读`操作后分别插入`LoadLoad`和`LoadStore`屏障

  {% fullimage /images/volatile读.webp,volatile读,volatile读%}

  `LoadLoad`屏障：禁止`volatile读`与后面的普通读进行重排序

  `LoadStore`屏障：禁止`volatile读`与后面的普通写进行重排序

- `volatile写`

  在`volatile写`操作前后分别插入`StoreStore`和`StoreLoad`屏障

  {% fullimage /images/volatile写.webp,volatile写,volatile写%}

  `StoreStore`屏障：保证`volatile写`之前的普通写操作已经对所有线程可见，该屏障保证**前面的所有普通写操作的值都刷新到主内存。**

  `StoreLoad`屏障：禁止`volatile写`与后面可能存在的`volatile读/写`进行重排序。

### volatile不保证原子性

`volatile`只能保证对单个volatile变量的读/写具有原子性，但是对于`volatile++`这样的复合操作没办法。

自增操作 `volatile++`实际执行了三步：

1. 读取变量的初始值
2. 在CPU中加1
3. 重新写入工作内存，在写入主内存

问题就在于：两个线程可能先后都读到同一个旧值，比如都读到`5`，然后各自在本地加1，最后都写回`6`。虽然每一次写回对其他线程都是可见的，但其中一次更新还是会把另一次更新覆盖掉，这就是典型的**丢失更新**问题。

要想保证原子性，只能借助于`synchronized、Lock和java.util.concurrent.atomic包下的原子操作类`保证这些操作时原子性操作。

所以如果从选型角度来看，可以这样粗略区分：

- **只需要可见性和顺序约束**：可以优先考虑`volatile`
- **需要复合操作原子性或临界区一致性**：需要锁或原子类



## volatile应用场景

`volatile`由于无法保证原子性，所以要使用必须具备以下两个条件：

- 对变量的写操作不依赖于当前值 

  ```java
  volatile int a = 0 ;
  a = a * 2;
  ```

- 该变量没有包含在具有其他变量的不变式中



  ***在多线程场景下，这两种情况即时使用`volatile`修饰，也有可能会有同步问题。***

把它再总结成“适合”和“不适合”的模式会更直观：

适合`volatile`的场景通常包括：

- 线程结束标记、开关位、停止信号
- 配置发布、状态发布
- DCL中的对象引用发布
- 单写多读、且读取方不需要做复合更新的场景

不适合`volatile`的场景通常包括：

- `count++` 这类读-改-写复合操作
- 多个字段之间需要保持一致性
- “先检查再执行”的流程控制
- 需要把一整段代码当作临界区保护的场景

## volatile使用实例

1. 状态量标记

   ```java
   volatile boolean flag = true;
   
   public void write(){
       flag = false;
   }
   
   public void modify(){
       if(flag){
           doSth();
       }
   }
   ```

2. 单例模式的实现(DCL)

   ```java
   class Singleton{
       private Singleton(){
           
       }
       
       private volatile static Singleton sInstance;
       
       public static Singleton getInstance(){
           if(sInstance == null){
               synchronized(Singleton.class){
                   if(sInstance == null){
                       sInstance = new Singleton();
                   }
               } 
           }
            return sInstance;
       }
   }
   ```

   `new Singleton()`在字节码和底层执行上并不是一个不可分割的单步骤，通常可以粗略理解为：

   1. 分配对象所需内存
   2. 初始化对象
   3. 把引用赋值给`instance`

   如果这里发生了重排序，就可能出现“引用已经对外可见，但对象还没有完成初始化”的情况。DCL里给实例引用加上`volatile`，核心目的就是**禁止对象初始化与对象发布之间的重排序**，避免其他线程拿到一个“半初始化”对象。

3. 引用可见性场景

   ```java
   class Holder {
       int a;
       int b;
   }

   volatile Holder holder;
   ```

   这里要特别注意：`volatile`修饰的是**引用本身**。也就是说，它能保证一个线程把新的`holder`引用写进去后，其他线程能及时看到这个新引用；但这并不等于“对`holder`内部字段的任意复合操作天然线程安全”。

   如果对象内部状态本身还会被多个线程并发修改，那么仍然需要额外的同步手段去保护内部一致性。

## volatile和 synchronized区别

- `volatile`仅能使用在变量级别，`synchronized`适用于变量、方法和类
- `volatile`仅能实现变量修改可见性，不保证原子性；`synchronized`可以保证可见性及原子性
- `volatile`不会造成线程的阻塞；`synchronized`会造成阻塞(`阻塞同步`)
- `volatile`由于禁止指令重排序，不会被编译器优化；`synchronized`会被优化

如果从使用目标来看，还可以进一步概括成：

- `volatile`更像一种**轻量级状态同步手段**
- `synchronized`更像一种**临界区互斥保护手段**

前者解决“看不看得到”和“发布顺序是否安全”，后者解决“能不能把这一段逻辑作为整体保护起来”。

## 常见误用

- 把`volatile`当作轻量锁，试图保护一整段复合逻辑
- 认为“变量一旦加了`volatile`，围绕它的所有操作都线程安全”
- 在多个字段存在不变式约束时，只给其中一个字段加`volatile`
- 写出`if (flag) { doSomething(); }`这类检查再执行逻辑，却忽略中间状态可能已变化
- 误以为`volatile`修饰对象引用后，对象内部所有状态更新都自动安全

如果用一句话总结`volatile`最容易踩坑的地方，就是：

**它能帮助线程看到“最新值”，但不能替你保证“整个过程正确”。**



## 参考链接

[volatile](https://juejin.im/post/5ea913d35188256d4576d199#heading-17)
