---
title: 数据结构--ArrayList实现原理及简析
date: 2019-01-15 11:16:50
tags: 数据结构
top: 10
---

{% fullimage /images/ArrayList结构.png,ArrayList结构,ArrayList结构%}

## ArrayList定义

ArrayList是基于`List`接口实现的大小可变的数组，元素允许为任意属性包括`null`。同时非有序，非同步(线程不安全)。主要用于装载数据。

`ArrayList`底层实现是**数组**。

## ArrayList的重要参数分析

```java
//ArrayList 默认容量为10
private static final int DEFAULT_CAPACITY = 10;
//用于ArrayList 空实例时的共享空数组
private static final Object[] EMPTY_ELEMENTDATA = {};
//用于默认大小 共享空数组实例
private static final Object[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA={};
//存储ArrayList元素的数据缓冲区，ArrayList的容量是此数据缓冲区的长度
transient Object[] elementData();
//ArrayList包含的元素个数
private int size;
```

## ArrayList初始化

```java
    public ArrayList(int initialCapacity) {
        if (initialCapacity > 0) {
          //创建初始容量为 initialCapacity 的数组
            this.elementData = new Object[initialCapacity];
        } else if (initialCapacity == 0) {
           // 初始容量为0  引用空数组实例s
            this.elementData = EMPTY_ELEMENTDATA;
        } else {
            throw new IllegalArgumentException("Illegal Capacity: "+
                                               initialCapacity);
        }
    }

    //构造一个默认10位的数组
    public ArrayList() {
        //初始默认 空数组
        this.elementData = DEFAULTCAPACITY_EMPTY_ELEMENTDATA;
    }

    public ArrayList(Collection<? extends E> c) {
        elementData = c.toArray();
        if ((size = elementData.length) != 0) {
            //将要插入到集合的元素 复制到数组中
            // c.toArray might (incorrectly) not return Object[] (see 6260652)
            if (elementData.getClass() != Object[].class)
                elementData = Arrays.copyOf(elementData, size, Object[].class);
        } else {
            // replace with empty array.         
            this.elementData = EMPTY_ELEMENTDATA;
        }
    }
```

在`ArrayList`初始化中，如果不是设置了初始容量，那么数据并不会进行初始化，等到第一次`add()`时进行初始化。

## ArrayList插入数据 - add()

```java
ArrayList<String> list =new ArrayList<>();
list.add("Android");
```

`add(E e)`源码

```java
    public boolean add(E e) {
        ensureCapacityInternal(size + 1);  // Increments modCount!!
        //在数组对应位置 放入数据
        elementData[size++] = e;
        return true;
    }

```

`ensureCapacitInternal()`用来判定是否需要扩充来存储数据

```java
    private void ensureCapacityInternal(int minCapacity) {
        ensureExplicitCapacity(calculateCapacity(elementData, minCapacity));
    }

   //未初始化则 返回10  初始化完成 则是传递进来的值
    private static int calculateCapacity(Object[] elementData, int minCapacity) {
        //此时用的是默认构造器 构造的ArrayList
        if (elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
            return Math.max(DEFAULT_CAPACITY, minCapacity);
        }
        return minCapacity;
    }

    private void ensureExplicitCapacity(int minCapacity) {
       //修改数量 +1 
        modCount++;

        // 确保数组的容量，如果不够需要进行扩容 未初始化时 elementData.length == 0
        if (minCapacity - elementData.length > 0)
            grow(minCapacity);
    }

```

`grow()`用来进行数组扩容

```java
    private void grow(int minCapacity) {
        // 当前数组的容量
        int oldCapacity = elementData.length;
        //新数组扩容至原来的1.5倍
        int newCapacity = oldCapacity + (oldCapacity >> 1);
        //未初始化 min为10
        if (newCapacity - minCapacity < 0)
            newCapacity = minCapacity;
        //超出上限 则长度变为 Integer.MAX_VALUE
        if (newCapacity - MAX_ARRAY_SIZE > 0)
            newCapacity = hugeCapacity(minCapacity);
        // 复制元素到新的数组中
        elementData = Arrays.copyOf(elementData, newCapacity);
    }
```

### `add(int index,E element)`

```java
public void add(int index, E element) {
    // 判断 index 有没有超出索引的范围
    rangeCheckForAdd(index);
    // 和之前的操作是一样的，都是保证数组的容量足够
    ensureCapacityInternal(size + 1);  // Increments modCount!!
    // 将指定位置及其后面数据向后移动一位
    System.arraycopy(elementData, index, elementData, index + 1,size - index);
    // 将该元素添加到指定的数组位置
    elementData[index] = element;
    // ArrayList 的大小改变
    size++;
}
```

`rangeCheckForAdd()` 判断要插入数据的index是否超过当前存储数据的上限`size`

```java
    private void rangeCheckForAdd(int index) {
        if (index > size || index < 0)
            throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
    }
```



{% fullimage /images/ArrayList-add过程.png,ArrayList-add过程,ArrayList-add过程%}



## ArrayList获取数据 - get()

```java
list.get(0);
```

`get()`源码

```java
    public E get(int index) {
        //判定index位置是否在范围内
        rangeCheck(index);

        return elementData(index);
    }
```



## ArrayList删除数据 - remove()

```java
list.remove(0);
//删除内容
list.remove("Android")
```

`remove(int index)`源码

```java
    public E remove(int index) {
        //检查index有没有超出范围
        rangeCheck(index);

        modCount++;
        //保存需要删除的数据 可以返回旧值
        E oldValue = elementData(index);

        int numMoved = size - index - 1;
        if (numMoved > 0)
            //把删除的位置后一位数据 向前移
            System.arraycopy(elementData, index+1, elementData, index, numMoved);
        //设置原位置元素为null  方便释放内存
        elementData[--size] = null; // clear to let GC do its work

        return oldValue;
    }
```

`remove(Object o)`源码

```java
    public boolean remove(Object o) {
        if (o == null) {
            for (int index = 0; index < size; index++)
                if (elementData[index] == null) {
                    fastRemove(index);
                    return true;
                }
        } else {
            //如果有元素值 == o 找到对应的位置 并移除
            for (int index = 0; index < size; index++)
                if (o.equals(elementData[index])) {
                    fastRemove(index);
                    return true;
                }
        }
        return false;
    }

    private void fastRemove(int index) {
        modCount++;
        int numMoved = size - index - 1;
        if (numMoved > 0)
            System.arraycopy(elementData, index+1, elementData, index,
                             numMoved);
        elementData[--size] = null; // clear to let GC do its work
    }
```

## ArrayList清空数据 - clear()

```java
list.clear()
```

`clear()`源码

```java
    public void clear() {
        modCount++;

        // 数组内所有元素置null
        for (int i = 0; i < size; i++)
            elementData[i] = null;

        size = 0;
    }
```

## 拓展

#### ArrayList和LinkedList的区别?

> ArrayList
>
> - 基于**数组**实现，可以用索引实现快速查找。是动态数组，相比于数组容量可以实现动态增长。
> - ArrayList可以插入`null`。
> - ArrayList初始容量为10，以1.5倍大小进行扩容。
> - ArrayList不是线程安全。如果想线程安全可以通过`Collections.synchronizeList()`包裹ArrayList，实质上是对ArrayList的所有操作加了锁。推荐使用`CopyOnWriteArrayList`。
> - 在顺序添加数据以及查找和访问数据上有优势，再删除和插入数据上 需要进行数组复制操作。

<br>

>LinkdedList
>
>- 基于**链表**实现，是双向链表，增删速度快。是一个双向循环链表，也可以被当做堆栈、队列使用。
>- LinkedList比ArrayList更占内存，由于节点存储了数据以及前后两节点的引用
>- LinkedList是线程不安全，也可以通过`Collections.synchronizeList()`包括LinkedList，推荐使用`ConcurrentLinkedQueue`
>- 在数据的删除和插入上有优势

#### ArrayList及LinkedList在插入数据上的比较

- 在头部插入数据：`ArrayList`需要进行一次数组复制(`System.arrayCopy`)而`LinkedList`只要遍历找到头部为止即可。所以`LinkedList`高效。
- 在中部插入数据
  - 插入位置越靠前：`LinkedList`效率越高
  - 插入位置靠中间：`LinkedList`的遍历是从两边开始的，往中靠效率越低。
  - 插入位置越靠后：`ArrayList`效率越高
- 在尾部插入数据：`ArrayList`可能需要触发扩容操作，导致速度不如`LinkedList`。当数据量大时，`ArrayList`不会去频繁的进行扩容，效率就会高于`LinkedList`。

#### ArrayList的序列化

> `transient`可以关闭被修饰字段的序列化。

`elementData`是通过`transient`修饰的，那么内部的`elementData`是无法被序列化的。所以ArrayList内部实现了序列化及反序列化的一系列工作。

```java
    //保存ArrayList中的实例状态到序列中
    private void writeObject(java.io.ObjectOutputStream s)
        throws java.io.IOException{
        // Write out element count, and any hidden stuff
        int expectedModCount = modCount;
        s.defaultWriteObject();

        // Write out size as capacity for behavioural compatibility with clone()
        s.writeInt(size);

        // Write out all elements in the proper order.
        for (int i=0; i<size; i++) {
            s.writeObject(elementData[i]);
        }

        if (modCount != expectedModCount) {
            throw new ConcurrentModificationException();
        }
    }

    private void readObject(java.io.ObjectInputStream s)
        throws java.io.IOException, ClassNotFoundException {
        elementData = EMPTY_ELEMENTDATA;

        // Read in size, and any hidden stuff
        s.defaultReadObject();

        // Read in capacity
        s.readInt(); // ignored

        if (size > 0) {
            // be like clone(), allocate array based upon size not capacity
            int capacity = calculateCapacity(elementData, size);
            SharedSecrets.getJavaOISAccess().checkArray(s, Object[].class, capacity);
            ensureCapacityInternal(size);

            Object[] a = elementData;
            // Read in all elements in the proper order.
            for (int i=0; i<size; i++) {
                a[i] = s.readObject();
            }
        }
    }
```

观察源码可知，只是序列化了`ArrayList中已存在的元素，而非整个数组`。