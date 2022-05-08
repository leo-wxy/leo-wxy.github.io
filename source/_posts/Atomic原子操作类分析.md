---
title: CAS操作&Atomic原子操作类分析
date: 2018-12-18 14:50:08
tags: 
  - JVM
  - Java
top: 10
typora-root-url: ../../themes/next-t/source/images
---



{% fullimage /images/CAS.png,CAS基本知识,CAS基本知识%}



# CAS与原子操作

## 乐观锁与悲观锁

### 悲观锁

认为每次访问共享资源时都会发生冲突，必须对每次对象操作进行上锁，以保证临界区的程序同时只能有一个线程执行。

### 乐观锁

假设对共享资源的访问不会发生冲突，线程可以不停的执行，无需加锁。

**一旦发生线程冲突，通常都会采用`CAS操作`保证线程执行的安全性**



> `悲观锁`适用于**写多读少**的环境，避免频繁失败和重试影响性能。
>
> `乐观锁`适用于**写少读多**的环境，避免频繁加锁影响性能。



## CAS操作

> CAS是乐观锁技术，当多个线程尝试使用CAS更新同一个变量时，只有其中一个线程能更新变量的值，而其他线程都失败，失败的线程不会被挂起，而是告知竞争失败，并尝试再次发起请求。

CAS指令需要有三个操作数：

- **内存位置(V)**：简单的理解为变量的内存地址
- **旧的预期值(A)**
- **新值(B)**

执行CAS操作，当且仅当`V`符合旧预期`A`时，处理器就会更新`B`到`V`上。否则处理器不做任何操作。

```java
//伪代码实现
boolean compareAndSwap(V,A,B){
    if(V!=A){
        return false;//CAS操作失败
    }else{
        V=B;//替换内存中的值为新值
        return true;//CAS操作成功
    }
}
```

**由于CAS是一种原子操作，当多个线程同时使用CAS操作一个变量时，只有一个会成功，并且更新变量，其他线程都会失败。但失败的线程不会被挂起，只是告知失败，并且继续尝试操作变量。**

### CAS原理

> `compareAndSet()`内部是调用Java本地方法`compareAndSwapInt()`实现的，虚拟机内部对这些方法做了特殊处理，借助C来调用CPU的底层指令保证硬件层面实现原子操作。
>
> Intel CPU 利用**cmpxchg**指令实现CAS

CAS操作是由`sun.misc.Unsafe`类里面的`computeAndSwapXX()`实现的

```java
boolean compareAndSwapObject(Object o, long offset,Object expected, Object x);
boolean compareAndSwapInt(Object o, long offset,int expected,int x);
boolean compareAndSwapLong(Object o, long offset,long expected,long x);
```

`Unsafe`主要提供一些用于执行低级别，不安全操作的方法，如直接访问系统内存资源、自主管理内存资源等，这些方法在提升Java运行效率、增强Java语言等底层资源操作能力方法面起到了很大的作用。

但由于`Unsafe`可以操作内存空间，增加了程序发生指针问题的风险。

 [Java魔法类：Unsafe应用解析](https://tech.meituan.com/2019/02/14/talk-about-java-magic-class-unsafe.html)



### CAS问题

#### ABA问题

因为CAS需要在操作值的时候检查值是否发生变化，如果没有发生变化则更新，但如果一个值原来是A，变成了B，再变成了A，对于CAS检查而言就是没有发生过变化，实际已经发生变化。

解决思路就是利用版本号，在变量前添加版本号，并每次更新时加1，则A->B->A 会变为 1A->2B->3A。

可以利用`AtomicStampedReference`来解决，它内部的`compareAndSwap()`首先会去检查当前引用是否等于预期引用，并且当前标志是否等于预期标志，全部相等才会替换值。

```java
public boolean compareAndSet(V   expectedReference,
                             V   newReference,
                             int expectedStamp,
                             int newStamp) {
    Pair<V> current = pair;
    return
        expectedReference == current.reference &&
        expectedStamp == current.stamp && //比较标志是否等于预期标志
        ((newReference == current.reference &&
          newStamp == current.stamp) ||
         casPair(current, Pair.of(newReference, newStamp)));
}
```

也可使用`AtomicMarkableReference`主要关心的是**引用变量是否发生变化**。

```java
    public boolean compareAndSet(V       expectedReference,
                                 V       newReference,
                                 boolean expectedMark,
                                 boolean newMark) {
        Pair<V> current = pair;
        return
            expectedReference == current.reference &&
            expectedMark == current.mark &&
            ((newReference == current.reference &&
              newMark == current.mark) ||
             casPair(current, Pair.of(newReference, newMark)));
    }
```



#### 循环时间长开销大

相对于`synchronized`省去了挂起线程以及恢复线程的开销。CAS是非阻塞同步，不会将线程挂起，会进行自旋（`死循环`），时间过长会对性能造成很大的消耗。`Pause`指令

#### 只能保证一个变量的原子操作

当对多个变量进行操作时，CAS无法保证原子性操作，这时可以用锁或者`AtomicReference`保证引用对象之间的原子性，就可以把多个变量放在一个对象里进行操作。



## Atomic原子操作类

> 方便在多线程环境下，无锁的进行原子操作。**提供非阻塞的线程安全编程**

### 类摘要

| 类                          | 描述                                                    |
| --------------------------- | ------------------------------------------------------- |
| AtomicInteger               | 更新int                                                 |
| AtomicBoolean               | 更新boolean                                             |
| AtomicLong                  | 更新long                                                |
| AtomicIntegerArray          | 更新int数组                                             |
| AtomicIntegerFieldUpdater   | 基于反射，可以对指定类的指定``volatile int`字段进行更新 |
| AtomicLongArray             | 更新long数组                                            |
| AtomicLongFieldUpdater      | 基于反射，可以对指定类的指定`volatile long`字段进行更新 |
| AtomicMarkableReference     | 维护带有标记的对象引用，可以更新                        |
| AtomicReference             | 更新对象引用                                            |
| AtomicReferenceArray        | 更新对象引用数组                                        |
| AtomicReferenceFieldUpdater | 基于反射，可以对指定类的指定volatile 字段进行更新       |
| AtomicStampedReference      | 维护带有整数标志的对象引用，可以更新                    |

Java 8之后新增了4个新的原子操作类

| 类                | 描述       |
| ----------------- | ---------- |
| LongAdder         | 更新long   |
| DoubleAdder       | 更新double |
| LongAccumulator   | 更新long   |
| DoubleAccumulator | 更新double |

上述四个类引用`多段锁`的概念。**通过CAS保证原子性，通过自旋保证当次修改的最终修改成功，通过降低锁粒度（多段锁）增加并发性能。** 他们**属于原子累加器，适用于数据统计以及高并发环境，不适用于其他粒度的应用。**

> `原子累加器`使用了**热点分离**思想
>
> **热点分离**：①将竞争的数据进行分解成多个单元，在每个单元中分别进行数据处理 ②各单元处理完成后，通过`Hash算法`进行求和，从而得到最终结果
>
> `热点分离`减小了锁的粒度，提供并发环境下的吞吐量，但需要额外空间存储数据，增大空间消耗。



### 如何保证原子操作

内部都实现了一个`compareAndSet()`方法

```java
    
 // setup to use Unsafe.compareAndSwapInt for updates
    private static final Unsafe unsafe = Unsafe.getUnsafe();
    private static final long valueOffset;

    static {
        try {
            valueOffset = unsafe.objectFieldOffset
                (AtomicInteger.class.getDeclaredField("value"));
        } catch (Exception ex) { throw new Error(ex); }
    }
    //用volatile修饰 value 保证可见性
    private volatile int value;

public final boolean compareAndSet(int expect, int update) {
        return unsafe.compareAndSwapInt(this, valueOffset/*V 内存地址*/, expect/*A 旧的预期值*/, update/*B 修改值*/);
    }

```

`compareAndSwap()`涉及了两个重要对象，一个是`unsafe`另一个是`valueOffset`。

`unsafe`是JVM提供的一个后门，用来执行 **硬件级别的原子操作**。

`valueOffset`是通过`unsafe`获取到的，代表 **AtomicInteger对象value成员变量在内存中的偏移量**。可以简单的认为是*value变量的内存地址*。



