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

如果从实现取舍上再总结一层，可以简单理解为：

- `CAS`更适合**单个共享状态**在低竞争下的快速更新
- `synchronized/Lock`更适合**多个步骤必须整体保持一致**的临界区保护

也就是说，乐观并发并不是来替代所有锁的，而是在合适场景下用“失败重试”换“线程挂起与唤醒”的成本。



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

所以CAS真正解决的是：**单个共享状态在并发更新时，如何基于“比较旧值是否仍然成立”来完成一次原子替换。**它并不能天然解决多个变量之间的一致性问题，也不能自动保证一整段业务逻辑的线程安全。

另外还要注意：

- `CAS`成功，并不代表过程中完全没有竞争，只代表当前这次比较交换成功提交了
- `CAS`失败，也不代表程序出错，很多时候只是说明“预期值已经过期，需要重试或放弃”

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

从并发语义角度看，原子类之所以不仅有“原子替换”，还具备可见性，原因通常来自两个层面：

- 原子类内部的关键值一般都由`volatile`修饰，保证可见性
- `compareAndSet()`这类CAS操作本身也带有相应的内存语义，保证成功更新后的结果能够被其他线程正确观察到

 [Java魔法类：Unsafe应用解析](https://tech.meituan.com/2019/02/14/talk-about-java-magic-class-unsafe.html)

从JDK演进角度看，早期很多原子操作能力都直接建立在`Unsafe`之上；而在JDK 9之后，又引入了`VarHandle`这类更正式的底层原子访问机制。理解这一点的意义在于：原子类背后的核心思想没有变，变化更多体现在底层访问入口和JDK提供能力的形式上。



### CAS问题

#### ABA问题

因为CAS需要在操作值的时候检查值是否发生变化，如果没有发生变化则更新，但如果一个值原来是A，变成了B，再变成了A，对于CAS检查而言就是没有发生过变化，实际已经发生变化。

不过ABA并不是所有场景下都会造成真正问题。是否需要解决它，关键看你关心的是：

- **当前值是不是我预期的值**
- 还是**这个值在中间有没有被别人改过**

如果业务只关心“最终值是否仍然等于预期值”，那么ABA未必会破坏语义；但如果中间变化过程本身就很重要，比如链表节点、栈顶引用、资源版本状态等，就需要借助版本号或标记位去识别“看起来没变，但其实被改过”的情况。

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

这也是为什么说CAS更适合低竞争场景：一旦竞争很激烈，线程会不断读取旧值、计算新值、CAS失败、再次重试，CPU时间会大量消耗在失败重试上。

#### 只能保证一个变量的原子操作

当对多个变量进行操作时，CAS无法保证原子性操作，这时可以用锁或者`AtomicReference`保证引用对象之间的原子性，就可以把多个变量放在一个对象里进行操作。

所以从工程角度看，可以这样做取舍：

- 单字段状态位、计数器、引用切换：优先考虑原子类
- 多字段一致性、多个步骤必须整体成功：优先考虑锁或更高层同步方案



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

其中比较容易混淆的几类，可以这样理解：

- `AtomicReference`：适合原子替换整个对象引用
- `AtomicStampedReference`：适合在引用上附带版本号，解决ABA
- `AtomicMarkableReference`：适合只关心“是否被改过”这类布尔标记场景
- `AtomicIntegerFieldUpdater / AtomicReferenceFieldUpdater`：适合不想额外再包一层原子对象，而是直接对类中的某个`volatile`字段做原子更新

如果继续补一层使用边界，`FieldUpdater`通常还要满足这些约束：

- 被更新字段必须是`volatile`
- 访问权限要满足反射访问要求
- 它更适合“大量对象共享同一个updater”的场景，这样能避免为每个字段单独再包一层原子对象

而`AtomicReference`一个很典型的使用模式是：**不可变对象 + 原子替换引用**。当对象内部状态较多、但每次更新都可以构造一个新快照时，直接原子切换整个引用，往往比让多个字段分别做原子更新更容易保证一致性。

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

把它和`AtomicLong`放在一起看就更容易理解：

- `AtomicLong`是在同一个热点值上反复CAS，竞争越高，失败重试越频繁
- `LongAdder`会把更新压力分散到多个槽位上，显著降低热点冲突

但它的代价是：求和要把多个槽位汇总，因此`sum()`更适合统计场景，不应该机械地把它理解成每个瞬间都绝对强一致的单点值。

而`LongAccumulator`、`DoubleAccumulator`则是在这个思路上更进一步：它们不只支持“求和”，还允许你传入自定义的累积函数。也就是说，`LongAdder`更像“高并发加法计数器”，而`LongAccumulator`更像“可自定义累积规则的高并发聚合器”。



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

而像`incrementAndGet()`、`getAndIncrement()`这类高频方法，本质上并不是“硬件直接提供了自增原语”，而是依赖一条典型的CAS重试主线：

1. 先读取当前旧值
2. 基于旧值计算新值
3. 调用CAS尝试把旧值替换成新值
4. 如果失败，说明有其他线程已经改过值，则重新读取并再次尝试

也就是说，原子类的很多复合操作，本质上是“**读取 -> 计算 -> CAS提交 -> 失败重试**”的循环。

同一类API里，返回值语义也值得顺手区分一下：

- `incrementAndGet()`：先更新，再返回新值
- `getAndIncrement()`：先返回旧值，再更新
- `getAndSet()`：原子替换并返回旧值
- `updateAndGet()` / `getAndUpdate()`：通过函数式更新值，本质上也仍然是CAS重试

这些方法名字看起来只是顺序差异，但如果放在业务逻辑里，返回旧值还是新值往往会直接影响后续判断。

另外还有两个经常被忽略的API语义：

- `weakCompareAndSet()`：弱CAS，可能出现伪失败，因此更适合放在循环重试的底层场景中理解
- `lazySet()`：并不是普通`set()`的简单别名，它更偏“最终会对其他线程可见”的有序写，适合某些不要求立刻强可见、但要求最终发布顺序的场景

## 常见误用

- 误以为用了Atomic类就能自动保证多个字段的一致性
- 把`get()`和后续业务逻辑拆开后，仍然想当然地认为整个流程线程安全
- 在高竞争场景下无脑使用CAS循环，却忽略了失败重试带来的CPU消耗
- 把`LongAdder.sum()`当成某个时刻绝对强一致的精确瞬时值
- 明明是复杂共享状态，却硬要用多个原子变量拼装，导致代码难以维护且语义并不真正安全

## 适用场景总结

Atomic原子类最适合的场景通常包括：

- 计数器、自增序列、统计值
- 布尔状态位切换
- 对象引用的原子替换
- 高并发统计场景下的热点计数（如`LongAdder`）

而不太适合的场景包括：

- 多字段需要保持一致性
- 需要跨多个步骤维持临界区语义
- 冲突非常频繁、重试成本很高的复杂共享状态更新

如果用一句话概括这篇的核心结论，可以记成：

- `CAS`适合做“单点状态原子提交”
- `Atomic`适合做“基于CAS封装好的常见无锁原子操作”
- 复杂一致性问题，依然要回到锁或更高层同步方案

如果把实践建议再说得更直白一点，可以记成：

- Atomic类优先用于“小而明确”的并发状态
- 状态一复杂，就优先考虑不可变对象 + 原子替换，或者直接使用锁
- 不要为了追求“无锁”而无锁，真正合适的并发模型比“看起来更高级”的实现方式更重要

