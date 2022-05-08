---
title: Android Study Plan VIII - Java引用类型
date: 2018-03-18 17:48:20
tags: Android
---
# Android学习计划
话题：Java基础知识学习
1、Java中有哪几种引用？它们的含义和区别是什么？
2、请用Java实现一个线程安全且高效的单例模式。

# 答案
## 1. Java中有哪几种引用？它们的含义和区别是什么？
- 强引用（StrongReference）：`无论内存是否充足，都不会被回收`强引用指的是在代码中普遍存在的类似`Object object=new Object();`这类的引用，只要有这类的存在，垃圾回收器永远不会回收该对象，这也是导致OOM异常出现的主要原因。若想中断强引用可以把对象置为`null`。
- 弱引用（WeakReference）：`内存不足时，会被回收`弱引用用来修饰非必需对象，弱引用所关联的对象生命周期只到下一次垃圾回收前，无论内存是否充足都会被回收关联对象。
```java
String s=new String("abc");
WeakReference<String> weakReference=new WeakReference<>(s);
//当内存回收时 调用weakRefrence=null 并且 System.gc();
```
- 软引用（SoftReference）：`无论内存是否充足，都会被回收`软引用用来修饰一些有用但非必需的对象，软引用所关联的对象将会在系统即将发生OOM前，会把对象进行二次回收，若回收完内存还是不足则会发生OOM异常。`可实现内存敏感的高速缓存`
```java
	String s=new String("abc");
	SoftReference<String> softReference=new SoftReference<>(s);
	//当内存不足时 会调用 softRefrence=null  并且 System.gc();
```
- 虚引用（PhantomReference）：`任何时候都会被回收`虚引用不会决定对象的生命周期，虚引用关联的对象任何时候都可能被垃圾回收器回收。虚引用的作用是：跟踪对象被垃圾回收器回收的活动，虚引用本身加入引用队列中，记录引用对象是都被回收。

## 2. 请用Java实现一个线程安全且高效的单例模式。
> 单例：一个类有且仅有一个实例，并且自行实例化向整个系统提供。目的为
>
> - 减少内存的占用
> - 阻止对象实例化自己的单例对象副本，从而确保所有对象访问统一实例
> - 控制了实例化过程所以可以灵活化控制实例过程。
>
>  线程安全：再多线程访问时采用加锁机制，当一个线程访问该数据时，其他线程不能访问该数据，直到读取完毕才可以访问。不会出现数据不一致和数据污染。

> 双重校验锁（DCL）

```java
public class Singleton {
    private static volatile Singleton mInstance;
    private Singleton() {
    }

    public static Singleton getInstance() {
        if (mInstance == null) {
            synchronized (Singleton.class) {
                if (mInstance == null) {
                    mInstance = new Singleton();
                }
            }
        }
        return mInstance;
    }
}
```
> 在JVM中，并不限制处理器的执行顺序，在不影响运行结果的情况下，顺序可能会被打乱。volatile 关键字的作用是防止执行命令不会被重新排序。如若没有volatile 修饰，则`mInstance = new Singleton(); `可能出现`mInstance `尚未被初始化的异常。
> `mInstance = new Singleton(); `包括三步：`为对象分配内存`，`执行构造方法，初始化实例对象`，`把mInstance的引用指向分配的内存空间`。在JVM的执行过程中并不是原子性的。
> 保护序列化与反序列化安全的写法：
```java
/**
*反序列化提供的一个特殊方法，可以控制对象的反序列化。
*/
private Object readResolve(){
        return mInstance;//返回实例对象
    }
```

> 静态内部类：
>
> `为何可以保证线程安全？`虚拟机可以保证一个类的类构造器 `<clinit>()`在多线程环境中被正确的加锁、同步。如果多个线程同时去初始化一个类，只有一个线程可以去执行类构造方法，其他线程都会阻塞等待，直到构造方法执行完毕。**同一个类加载器下，一个类型只会被初始化一次。**

```java
public class Singleton {
    private Singleton() {
    }

    public static Singleton getInstance() {
        return SingletonHolder.sInstance;
    }

    private static class SingletonHolder {
        private static Singleton sInstance = new Singleton();
    }
}
```

> 枚举写法（在Android中不推荐使用，对内存的消耗较大）
枚举法的好处：1.实例创建线程安全 2.防止被反射创建多个实例 3. 没有序列化的问题

```java
public enum Singleton{
    INSTANCE;
    
    public void fun() {
       //do sth
    }
}
```


## 3. 拓展知识
- Kotlin实现的单例模式：`object Singleton{}`，本质是饿汉加载，在类加载时就会创建单例。问题在于构造方法过多时，初始化会变慢以及资源的浪费。

- Kotlin实现懒汉式加载：
```kotlin
class Singleton private constructor(){
    companion object {
        val instance: Singleton by lazy { Singleton() }
    }
}
```
