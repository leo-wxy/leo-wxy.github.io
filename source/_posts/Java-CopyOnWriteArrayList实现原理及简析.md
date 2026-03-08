---
title: 数据结构--CopyOnWriteArrayList实现原理及简析
date: 2019-01-18 09:53:29
tags: 数据结构
top: 10

---

{% fullimage /images/CopyOnWriteArrayList简析.png,CopyOnWriteArrayList简析,CopyOnWriteArrayList简析%}

## CopyOnWriteArrayList定义

> ArrayList本身不是线程安全的，在读线程读取ArrayList的数据时，此时在去写入数据，就会触发`fast-fail`机制，抛出`ConcurrentModificationException`异常。也可以使用`Vector`去代替`ArrayList`使用，或者使用`Collections.synchronizeList()`包裹ArrayList。但他们都是使用`synchronized`进行修饰，执行效率不高。
>
> 针对运行效率情况，有了`CopyOnWriteArrayList`。
>
> 适用场景：**读多写少**。

更准确地说，`CopyOnWriteArrayList`并不是“高并发场景下万能的List”，而是通过**写时复制**把读路径变得足够简单：读取尽量无锁，写入则接受更高的复制成本。

和`Vector`、`Collections.synchronizedList()`这种“读写都加锁”的思路相比，`CopyOnWriteArrayList`更像是：

- 读线程：直接读一个稳定数组快照
- 写线程：复制旧数组，修改新数组，再一次性发布新引用

## CopyOnWrite容器

`CopyOnWrite`容器即`写时复制`的容器。*当我们往一个容器添加元素的时候，不直接往当前容器添加，而是先将当前容器进行copy，复制出一个新的容器，然后往新的容器添加元素，添加完元素之后，再将原容器的引用指向新的容器。*

对`CopyOnWrite容器`进行并发读的时候，不需要加锁，因为当前容器不会添加任何元素。所以`CopyOnWrite容器`也是一种**读写分离**的思想，读和写采用不同的容器。*放弃了数据实时性。*

这里的关键不是“读线程完全看不到写入”，而是：**读线程读到的是某一个时刻已经完成发布的数组快照。**后续即使别的线程继续写入，当前读线程手里的这个快照也不会被原地修改，因此读到的数据虽然不一定最新，但一定是自洽的。



## CopyOnWriteArrayList源码解析

### 重要参数分析

```java
    //利用Lock实现读写分离
    final transient ReentrantLock lock = new ReentrantLock();

    //设置初始化数组引用
    private transient volatile Object[] array;
```

这里`array`使用`volatile`修饰很关键：写线程在完成新数组构造后，只需要把新数组引用写回去，其他线程随后读到的就是一份完整发布的新快照。

### 初始化

```java
    public CopyOnWriteArrayList() {
        //设置空数组
        setArray(new Object[0]);
    }    

    public CopyOnWriteArrayList(E[] toCopyIn) {
        setArray(Arrays.copyOf(toCopyIn, toCopyIn.length, Object[].class));
    }

    public CopyOnWriteArrayList(Collection<? extends E> c) {
        Object[] elements;
        if (c.getClass() == CopyOnWriteArrayList.class)
            elements = ((CopyOnWriteArrayList<?>)c).getArray();
        else {
            elements = c.toArray();
            // c.toArray might (incorrectly) not return Object[] (see 6260652)
            if (elements.getClass() != Object[].class)
                elements = Arrays.copyOf(elements, elements.length, Object[].class);
        }
        setArray(elements);
    }

```

### 插入数据 - add(E e)

```java
    public boolean add(E e) {
        final ReentrantLock lock = this.lock;
        //锁住写线程，保证同一时刻只有一个线程可以操作
        lock.lock();
        try {
            //获取旧数组引用
            Object[] elements = getArray();
            int len = elements.length;
            //复制旧数组数据到新数组中
            Object[] newElements = Arrays.copyOf(elements, len + 1);
            //添加新的数据
            newElements[len] = e;
            //设置新数据的引用到旧数组上
            setArray(newElements);
            return true;
        } finally {
            //操作完成 解锁
            lock.unlock();
        }
    }
```

1. 采用`ReentrantLock`，保证同一时刻只有一个线程正在进行数组的复制，否则的话内存中会有多份被复制的数据。
2. `volatile`修饰的数组引用，在调用`setArray()`时，线程对数组引用的修改是对其他线程可见的。
3. 插入数据时插到新的数组中的，可以保证读和写操作在两个数组中执行，不会影响数据。

写操作之所以必须加锁，不是为了让读线程也跟着阻塞，而是为了串行化写路径：如果多个写线程同时基于同一个旧数组快照各自复制并修改，最后谁先发布、谁后发布，就可能把别人的更新直接覆盖掉。

**和ArrayList相比，效率比较低，每次插入一个数组 都需要进行数组复制操作，随着元素的增加，修改代价会越来越大。**

而且这种代价不只存在于`add()`：

- `add()`
- `set()`
- `remove()`

本质上都可能触发整数组复制。所以元素越多、写入越频繁，复制成本和内存抖动就越明显。

### 获取数据 - get(int index)

```java
public E get(int index) {
  //获取index对应数据
  return get(getArray(), index);
}

private E get(Object[] a, int index) {
  return (E) a[index];
}
```

`get()`没有添加线程安全控制，也没有加锁。因为**get()操作的是旧数组，也不会发生修改操作。**

这也是`CopyOnWriteArrayList`读性能的关键来源：读线程只需要拿到当前数组引用，再按下标读取即可，不需要参与写线程的锁竞争。

### 移除数据 - remove(int index)

```java
    public E remove(int index) {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            Object[] elements = getArray();
            int len = elements.length;
            E oldValue = get(elements, index);
            int numMoved = len - index - 1;
            if (numMoved == 0)
                //移除了最后一位 只要复制前面的数据即可
                setArray(Arrays.copyOf(elements, len - 1));
            else {
                //生成一个新数组
                Object[] newElements = new Object[len - 1];
                System.arraycopy(elements, 0, newElements, 0, index);
                System.arraycopy(elements, index + 1, newElements, index,
                                 numMoved);
                setArray(newElements);
            }
            return oldValue;
        } finally {
            lock.unlock();
        }
    }
```

删除和插入一样，都会走“复制旧数组 -> 生成新数组 -> 发布新数组引用”的流程，所以写少读多才是它真正合适的使用前提。

## 拓展

#### CopyOnWriteArrayList的迭代器

`CopyOnWriteArrayList`的迭代器不会像`ArrayList`那样走`fail-fast`路线。原因在于：迭代器在创建时就已经拿到了一份数组快照，后续遍历始终基于这份快照进行。

因此会出现两个现象：

- 遍历期间即使别的线程修改了容器，也不会抛出`ConcurrentModificationException`
- 但迭代器也看不到它创建之后发生的新写入

所以“不报错”并不等于“读到的是最新值”，而是“读到的是创建迭代器那一刻的稳定视图”。

#### CopyOnWriteArrayList的缺点

- **内存占用问题**：在进行写操作时，内存里会有两份数组对象的内存，旧对象和新写入的对象。*可以通过压缩容器中元素的方法来减少大对象的内存消耗。*

- **数据一致性问题**：只能保证最终数据的一致性，不能保证实时一致性。

  [^什么可以用]: 可以保证实时一致性的ArrayList

- **写放大问题**：每次写操作都可能触发整数组复制，元素越多成本越高。

#### CopyOnWriteArrayList适用场景

- 监听器列表、观察者列表
- 黑白名单、规则列表这类读远多于写的配置数据
- 订阅者集合、回调集合
- 遍历频繁、更新极少，并且能接受读到旧快照的场景

这些场景的共同点是：**更在意读取稳定、不希望读线程互相干扰，而不是追求每次读取都看到绝对最新值。**

#### 不适用场景

- 大量写入或频繁更新的场景
- 列表元素很多、每次复制成本很高的场景
- 强实时要求很高、读线程必须马上看到最新值的场景
- 需要依赖迭代器实时反映最新修改的场景

#### 和Vector、synchronizedList的区别

- `Vector` / `Collections.synchronizedList()`：通常是读写都加锁，强调互斥访问
- `CopyOnWriteArrayList`：写时加锁复制，读路径基本无锁

所以它们的差异不只是“谁线程安全”，而是：

- 前者更偏互斥同步
- 后者更偏快照读 + 串行写

#### 常见误区

- 线程安全不等于强实时一致，`CopyOnWriteArrayList`读到的可能是旧快照
- 读无锁不等于没有成本，写路径的复制和额外内存占用都是真实存在的
- 迭代器不抛异常不等于能看到最新数据，只能说明它遍历的是一个稳定快照
