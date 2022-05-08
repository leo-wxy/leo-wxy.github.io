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

## CopyOnWrite容器

`CopyOnWrite`容器即`写时复制`的容器。*当我们往一个容器添加元素的时候，不直接往当前容器添加，而是先将当前容器进行copy，复制出一个新的容器，然后往新的容器添加元素，添加完元素之后，再将原容器的引用指向新的容器。*

对`CopyOnWrite容器`进行并发读的时候，不需要加锁，因为当前容器不会添加任何元素。所以`CopyOnWrite容器`也是一种**读写分离**的思想，读和写采用不同的容器。*放弃了数据实时性。*



## CopyOnWriteArrayList源码解析

### 重要参数分析

```java
    //利用Lock实现读写分离
    final transient ReentrantLock lock = new ReentrantLock();

    //设置初始化数组引用
    private transient volatile Object[] array;
```

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

**和ArrayList相比，效率比较低，每次插入一个数组 都需要进行数组复制操作，随着元素的增加，修改代价会越来越大。**

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

## 拓展

#### CopyOnWriteArrayList的缺点

- **内存占用问题**：在进行写操作时，内存里会有两份数组对象的内存，旧对象和新写入的对象。*可以通过压缩容器中元素的方法来减少大对象的内存消耗。*

- **数据一致性问题**：只能保证最终数据的一致性，不能保证实时一致性。

  [^什么可以用]: 可以保证实时一致性的ArrayList

