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

当一个变量被`volatile`关键字修饰后，就会具备两层语义：

- **保证此变量对所有线程的可见性，这里指  当一条线程修改了这个变量的值，新值对于其他线程来说是立即可得知的。**
- **禁止进行指令重排序优化**

### volatile 保证可见性

在使用`volatile`关键字修饰一个变量后，该变量在一个线程中被修改后，会发生如下事情：

1. 修改后，修改的变量值会强制立即写入主内存中
2. 然后强制过期其他线程中工作内存中的缓存，使缓存无效
3. 由于缓存无效，其他线程需要读取该变量值时，会强制重新从主内存中读取

> 当访问共享变量时，多个线程也会在自己的工作内存中有一份共享变量的副本。当某个线程更改了自己工作内存中的数据时，由于某些原因（线程阻塞）没有及时的刷新数据至主内存，然后其他线程的工作内存中的数据还是老数据。就会导致`缓存一致性`问题。
>
> **缓存一致性**：当其他线程读取该变量时，发现该缓存是无效的，就会从主内存中重新读取。

{% fullimage /images/volatile-process.png,volatile可见性,volatile可见性%}



### volatile 保证有序性

`volatile`禁止指令重排序，可以在一定程度上保证有序性。

**指令重排序**：JVM为了优化指令，提高程序运行效率，在不影响**单线程**执行结果的前提下，尽可能的提高并行度。

volatile关键字通过提供“**内存屏障(重排序时不能把后面的指令重排序到内存屏障之前的位置)**”的方式来防止指令被重排序，为了实现volatile的内存语义，编译器在生成字节码时，会在指令序列中插入内存屏障来禁止特定类型的处理器重排序。`加入volatile关键字的代码会多出一个lock前缀指令`。

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

要想保证原子性，只能借助于`synchronized、Lock和java.util.concurrent.atomic包下的原子操作类`保证这些操作时原子性操作。



## volatile应用场景

`volatile`由于无法保证原子性，所以要使用必须具备以下两个条件：

- 对变量的写操作不依赖于当前值 

  ```java
  volatile int a = 0 ;
  a = a * 2;
  ```

- 该变量没有包含在具有其他变量的不变式中



  ***在多线程场景下，这两种情况即时使用`volatile`修饰，也有可能会有同步问题。***

## volatile使用实例

1. 状态量标记

   ```java
   volatile bool flag = true;
   
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
       
       public static Singleton getInstence(){
           if(sInstance == null){
               synchronized(Sineleton.class){
                   if(sInstance == null){
                       sInstance = new Singleton();
                     /**
                     * 1.内存中创建对象
                     * 2.分配内存，并将指针指向内存区域
                     * 如果此时发生指令重排序，可能导致构造函数在初始化对象完成就赋值完成，导致其他线程获取对象为空，所以使用volatile进行修饰，避免指令重排序
                     */
                   }
               } 
           }
            return sInstance;
       }
   }
   ```

## volatile和 synchronized区别

- `volatile`仅能使用在变量级别，`synchronized`适用于变量、方法和类
- `volatile`仅能实现变量修改可见性，不保证原子性；`synchronized`可以保证可见性及原子性
- `volatile`不会造成线程的阻塞；`synchronized`会造成阻塞(`阻塞同步`)
- `volatile`由于禁止指令重排序，不会被编译器优化；`synchronized`会被优化



## 参考链接

[volatile](https://juejin.im/post/5ea913d35188256d4576d199#heading-17)