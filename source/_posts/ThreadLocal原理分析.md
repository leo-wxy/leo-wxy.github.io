---
title: ThreadLocal原理分析
date: 2018-12-09 14:04:59
tags: 源码分析
top: 9
typora-root-url: ../
---

# ThreadLocal详解

> 在前几节Handler详解中介绍 如何获取Looper对象时提及了是利用ThreadLocal来进行Looper的存储与获取。

![ThreadLocal解析](/images/ThreadLocal解析.png)



## 1.初步理解ThreadLocal



ThreadLocal，线程本地存储区(Thread Local Storage，简称为TLS)

ThreadLocal的定义为：**用于提供线程变量，在多线程环境中可以保证各个线程的变量独立于其他线程里的变量。**主要用于将私有线程和该线程存放的副本对象做一个映射，各个线程之间的变量不会互相干扰，适用于`高并发状态下实现无状态的调用即各个线程依赖不同的变量完成操作`。

ThreadLocal的另一个使用场景是**复杂逻辑下的对象传递**。

> ThreadLocal保证的是多线程环境下的独立性，同步机制则保证多线程下数据的一致性。

## 2.使用样例

```java
public class ThreadLocalTest {
    private static String label;
    private static ThreadLocal<String> threadLocal = new ThreadLocal<>();

    public static void main(String[] args) {
        label = "main";
        threadLocal.set("main");
        //new Thread
        Thread thread = new Thread() {
            @Override
            public void run() {
                super.run();
                label = "new";
                threadLocal.set("new");
            }
        };
        thread.start();

        try {
            thread.join();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        System.err.println("label = " + label);
        System.err.println("threadLocal = " + threadLocal.get());
    }
}

//console.log
label = new
threadLocal = main
```

对于ThreadLocal中的变量，在一个线程中修改它的值，并不会影响到在其他线程中的值。**ThreadLocal中的值在每个线程中都是独立的。**

## 3.深入理解ThreadLocal

ThreadLocal类中提供了以下几个方法来进行变量的操作：

- `public T get()`获取ThreadLocal在当前线程中保存的变量副本
- `public void set(T value)`设置当前线程中的变量副本
- `public void remove()`移除当前线程中的变量副本
- `protected T initialValue()`设置ThreadLocal的初始值，该方法为延迟加载

接下来具体查看上述方法的内部实现。加深理解

### `get()`

```java
//返回当前线程中存储的变量副本
public T get() {
        //获取当前线程
        Thread t = Thread.currentThread();
        //获取到持有变量副本的map
        ThreadLocalMap map = getMap(t);
        //map存在则返回存储值
        if (map != null) {
            //该map key为ThreadLocal 故获取value用的是this
            ThreadLocalMap.Entry e = map.getEntry(this);
            if (e != null) {
                @SuppressWarnings("unchecked")
                T result = (T)e.value;
                return result;
            }
        }
        //不存在则返回默认值
        return setInitialValue();
    }
```

### `set(T value)`

```java
//设置当前线程的变量副本
public void set(T value){
   Thread t = Thread.currentThread();
   ThreadLocalMap map = getMap(t);
    //map不为null 则保存value
    if(map!=null){
        map.set(this,value);
    }
    //否则创建一个ThreadLocalMap后保存value
    else{
        createMap(t,value);
    }
}
```

### `remove()`

```java
//移除保存的变量副本
public void remove(){
    ThreadLocalMap map = getMap(Thread.currentThread);
    //map不为空 则移除当前ThreadLocal对应的变量副本
    if(map!=null)
        map.remove(this);
}
```

### `initialValue()`

```java
//子类可重写该方法 进行默认值的设置
protected T initialValue() {
        return null;
    }

对应有setInitialValue()
private T setInitialValue(){
   T value = initialValue();
   Thread t = Thread.currentThread();
   ThreadLocalMap map = getMap(t);
    if(map!=null){
        map.set(this,value);
    }else{
        createMap(t,value);
    }
    return value;
}
```

在上述四个方法中都会涉及到一个类**`ThreadLocalMap`**，该类是ThreadLocal的核心机制实现。`在使用ThreadLocal的方法对存储变量进行操作时都需要获得当前线程对应的ThreadLocalMap来对变量进行操作`。**每个线程都会有专属的ThreadLocalMap，其中维护的value也是对应当前线程的。就保证了ThreadLocal中存储的变量都是相互独立的，不会受到多线程环境的影响。**

### **`ThreadLocalMap`**

> 该类为ThreadLocal中的内部类，没有实现Map接口，内部自己实现了Map的功能。

1. 构造方法

   ```java
    ThreadLocalMap(ThreadLocal<?> firstKey, Object firstValue) {
               table = new Entry[INITIAL_CAPACITY];
               int i = firstKey.threadLocalHashCode & (INITIAL_CAPACITY - 1);
               table[i] = new Entry(firstKey, firstValue);
               size = 1;
               setThreshold(INITIAL_CAPACITY);
           }
   ```

2. 初始对象

   ```java
   // 初始容量，必须是 2 的幂
   private static final int INITIAL_CAPACITY = 16;
   
   // 存储数据的哈希表
   private Entry[] table;
   
   // table 中已存储的条目数
   private int size = 0;
   
   // 表示一个阈值，当 table 中存储的对象达到该值时就会扩容
   private int threshold;
   
   // 设置 threshold 的值
   private void setThreshold(int len) {
       threshold = len * 2 / 3;
   }
   ```

   由内部实现了一套Map机制

3. Entry

   > table中存储的都为Entry对象，用于保存K-V数据结构

   ```java
           static class Entry extends WeakReference<ThreadLocal<?>> {
               /** The value associated with this ThreadLocal. */
               Object value;
   
               Entry(ThreadLocal<?> k, Object v) {
                   super(k);
                   value = v;
               }
           }
   ```

   Entry继承自`WeakRefrence<ThreadLocal<?>>`为弱引用类型并且限制了`K`只能为ThreadLocal对象，但是对应的`V`为强引用类型，则可能导致**内存泄漏**。

4. 保存key-value

   ```java
   //调用set方法将 key-value类型进行存储
   private void set(ThreadLocal<?> key, Object value) {
   
               // We don't use a fast path as with get() because it is at
               // least as common to use set() to create new entries as
               // it is to replace existing ones, in which case, a fast
               // path would fail more often than not.
   
               Entry[] tab = table;
               int len = tab.length;
               //计算要存储的索引位置
               int i = key.threadLocalHashCode & (len-1);
               //判断要存储的索引位置是否已经存在Entry 存在则继续向下
               for (Entry e = tab[i];
                    e != null;
                    e = tab[i = nextIndex(i, len)]) {
                   ThreadLocal<?> k = e.get();
                   //key相同则更新
                   if (k == key) {
                       e.value = value;
                       return;
                   }
                   //key为空 代表该位置对应的Entry已失效，需要直接进行替换
                   if (k == null) {
                       replaceStaleEntry(key, value, i);
                       return;
                   }
               }
               //若不存在 则将Entry保存到该位置
               tab[i] = new Entry(key, value);
               int sz = ++size;
               //超过当前负载 则需进行扩容机制 重新调整table
               if (!cleanSomeSlots(i, sz) && sz >= threshold)
                   rehash();
           }
   ```

   使用当前的ThreadLocal中对应的threadLocalHashCode来计算该键值对要存储的索引位置。该值是由ThreadLocal对象自动生成的，创建时就会进行赋值。

   ```java
   private final int threadLocalHashCode = nextHashCode();
   
       /**
        * The next hash code to be given out. Updated atomically. Starts at
        * zero.
        * 使用AtomicInteger用来保证多线程环境下不会受到影响
        */
       private static AtomicInteger nextHashCode =
           new AtomicInteger();
   
       /**
        * The difference between successively generated hash codes - turns
        * implicit sequential thread-local IDs into near-optimally spread
        * multiplicative hash values for power-of-two-sized tables.
        */
       private static final int HASH_INCREMENT = 0x61c88647;
   
       /**
        * Returns the next hash code.
        */
       private static int nextHashCode() {
           return nextHashCode.getAndAdd(HASH_INCREMENT);
       }
   
   ```

   当table中的条目超出阈值时就需要进行扩容

   ```java
   //扩容是 新table的容量为原先的两倍 触发条件为table中的条目数超出了阈值的3/4
   private void resize(){
       Entry[] oldTab = table;
       int oldLen = oldTab.length;
       int newLen = oldLen * 2;
       Entry[] newTab = new Entry[newLen];
       int count = 0;
       for(int j = 0;j<oldLen;++j){
           Entry e = oldTab[j];
           if(e!=null){
              ThreadLocal<?> k =e.get();
               if(k == null){
                   e.value = null;
               } else{
                   //重新计算扩容后的Hash值
                   int h = k.threadLocalHashCode & (newLen - 1);
                   while(newTab[h]!=null){
                       h = nextIndex(h,newLen);
                   }
                   newTab[h] = e;
                   count ++;
               }
           }
       }
       //重新设定当前容量
       setThreshold(newLen);
       size = count;
       table = newTab;
   }
   ```

5. 获取Entry对象

   ```java
   //根据传递进来的ThreadLocal 获取对应的entry
   private Entry getEntry(ThreadLocal<?> key) {
              //重新计算threadLocal对应的index
               int i = key.threadLocalHashCode & (table.length - 1);
               Entry e = table[i];
               if (e != null && e.get() == key)
               //entry不为空且对应位置key相同 则返回Entry
                   return e;
               else
               //否则 寻找临近的位置是否存在对应的值
                   return getEntryAfterMiss(key, i, e);
           }
   
   private Entry getEntryAfterMiss(ThreadLocal<?> key, int i, Entry e) {
       Entry[] tab = table;
       int len = tab.length;
       //当前传递的entry不为空 则开始循环
       while (e != null) {
           ThreadLocal<?> k = e.get();
           if (k == key)
               //相同则返回对应的 entry
               return e;
           if (k == null)
               //key消失 则移除对应的Entry
               expungeStaleEntry(i);
           else
               //继续向下寻找
               i = nextIndex(i, len);
           e = tab[i];
       }
       return null;
   }
   
   //寻找到最后也没找到就从头部开始重新匹配
           private static int nextIndex(int i, int len) {
               return ((i + 1 < len) ? i + 1 : 0);
           }
   ```

   调用`getEntryAfterMiss()`时，大部分由于哈希冲突(`Hash slot`)导致的。由于ThreadLocalMap没有使用链表的方式实现,所以解决Hash冲突的方式也只能使用一种**线性探测**的方式。`线性探测意为根据初始key的hashcode来确定元素在表中的位置，若发现位置已被占用，则会利用固定算法找到下一个位置，直到找到可以存放的位置。`

   ThreadLocalMap解决Hash冲突的方法就是 `步长+1或-1`,寻找下一个相邻的位置。

6. 移除指定的Entry

   ```java
   //根据threadLocal移除对应位置的Entry
   private void remove(ThreadLocal<?> key) {
       Entry[] tab = table;
       int len = tab.length;
       int i = key.threadLocalHashCode & (len-1);
       for (Entry e = tab[i];
            e != null;
            e = tab[i = nextIndex(i, len)]) {
           if (e.get() == key) {
               e.clear();
               expungeStaleEntry(i);
               return;
           }
       }
   }
   ```

7. 其他知识点

   在上述`set(),get(),remove()`方法中都涉及到了一个点，都会去进行一次判断当前位置的Entry是否无效并清除的操作，主要是为了**降低内存泄漏发生的可能性**。

   上面分析中就有提到ThreadLocalMap的key为弱引用型，而value为强引用型，就可能导致内存泄漏发生。

   **所以当我们使用ThreadLocal时，每次使用完毕都需要主动调用一次remove()方法来防止内存泄漏的发生。**

## 4.实现原理

在每个`Thread`中维护一个`ThreadLocalMap`，存储中的key为`ThreadLocal`对象本身，value是需要存储的对象。

这样设计的好处在于

- `ThreadLocalMap`中存储的`Entry`数量会变少，数量由`ThreadLocal`对象的个数来决定。
- `Thread`销毁后其内部的`ThreadLocalMap`也会一并销毁，减少内存的使用。

## 拓展

### InheritableThreadLocal

> `ThreadLocal`中变量副本是线程私有的即其他线程无法对其进行访问。`InheritableThreadLocal`是可以支持**在子线程中访问到父线程的变量副本**。

```java
 private static ThreadLocal<String> threadLocal = new ThreadLocal<>();
private static InheritableThreadLocal<Integer> integerInheritableThreadLocal =
            new InheritableThreadLocal<>();

    public static void main(String[] args) {
        threadLocal.set("main");
        integerInheritableThreadLocal.set(123);

        Thread thread = new Thread() {
            @Override
            public void run() {
                super.run();
                System.err.println("threadLocal "+ threadLocal.get());
                System.err.println("inheritableThreadLocal "+ integerInheritableThreadLocal.get());
            }
        };
        thread.start();

        try {
            thread.join();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

运行结果：
threadLocal null
inheritableThreadLocal 123
```

实现原理：

在线程进行初始化时，子线程会拷贝父线程的`inheritableThreadLocals`到自己的变量中，故调用`get()`时，会读取到父线程所存储的变量副本。

### 堆与栈的区别

在Java中，栈内存归属于单个线程，每个线程都会有一个栈内存，储存的是**局部变量和方法调用**。**存储对象仅线程中可见**

堆内存中的对象对所有线程可见，储存的是**Java的对象，无论成员变量、类变量**。**所有线程都可访问储存对象**



当栈内存不足够`存储局部变量和方法调用`，就会抛出`StackOverflowError`

当堆内存不足够`存储生成的对象`时，就会抛出`OutOfMemoryError`



### ThreadLocal的实例及其值存放在堆还是栈上？

ThreadLocal创建的实例也是被其创建的类所持有，值也是。所以他们都是位于`堆`上的。

不过是在获取当前线程的对象(`ThreadLocal储存的实例`)时，都是通过线程中的`ThreadLocalMap`去获取值，这时取出的就是各个线程存储的数据副本，也就自然的相互隔离。



### ThreadLocal变量为何设置为static？

`ThreadLocal`变量是针对于一个线程内所有操作共享的，会在类第一次被使用时加载且只分配一块存储空间。

可以作为`GC Roots`对象而不被回收。

**缺点**：可能导致内存泄漏，例如`Handler`内存泄漏的原因就是`sThreadLocal`。



## 总结

- 每个ThreadLocal中只能保存一个变量副本，如果需要多个则需创建多个ThreadLocal
- 由于ThreadLocal内部中ThreadLocalMap的key实现为弱引用，可能导致内存泄漏，使用完成后需要及时调用`remove()`来避免泄漏
- 使用ThreadLocal时，需要先`set()`再`get()`避免发生空指针异常，若重写了`initialValue()`该方法，则没问题
- ThreadLocal的适用场景为无状态且副本变量独立后不影响业务逻辑的高并发场景。
- ThreadLocalMap的`Key`是`ThreadLocal`对象，`value`是传递进来的对象。

## 内容引用

[JAVA并发-自问自答学ThreadLocal](https://www.jianshu.com/p/807686414c11)

[ThreadLocal解析](<https://juejin.im/post/5c72805651882562276c49d6>)

[ThreadLocal原理解析](https://blog.csdn.net/Rain_9155/article/details/103447399)