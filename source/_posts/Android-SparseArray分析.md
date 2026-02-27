---
title: SparseArray简析
date: 2019-01-28 12:00:25
tags: 源码解析
top: 10
---

> HashMap在Android开发中是一种常用的数据结构类型，但是占用内存方面相对会比较大，而且复杂的机制导致运行效率也不高。所以Android系统提供了`SparseArray`以及`ArrayMap`来对其进行替代。这也是Android性能优化的一种手段。

## SparseArray

> `SparseArray`可以对key为`Integer`类型的HashMap进行替代。还有
>
> - `LongSparseArray`对key为`Long`型的HashMap
> - `SparseIntArray`对key为`Integer`类型，value为`Integer`类型
> - `SparseLongArray`对key为`Integer`类型，value为`Long`类型
> - `SparseBooleanArray`对key为`Integer`类型，value为`Boolean`类型
>
> 等这些类型。内部实现都是相似的，只是可支持的类型不同。
>
> `SparseArray`允许value为null，并且是*线程不安全的*。

### SparseArray使用场景

- 数据量不大
- 空间比时间重要
- 需要使用到Map型结构，且key为`int`类型

补充：经验上更适合“中小规模、读多写少”的场景。

- 读路径依赖二分查找，规模增大后常数项与数组搬移成本会逐步放大。
- 写入/删除高频场景下，`gc()`压缩与数组移动可能成为额外开销。



### SparseArray重要参数分析

```java SparseArray.java
	//需要删除的标记    
	private static final Object DELETED = new Object();
	//设置回收标记 实质执行了 删除后的index置为null，协助回收
	private boolean mGarbage = false;
	//保存每个Item的key
    private int[] mKeys;
	//保存每个Item的value，容量和mKeys一致
    private Object[] mValues;
    //保存的数据容量
    private int mSize;
```



### SparseArray源码解析

#### 初始化

```java
//无初始值
SparseArray<String> stringSparseArray = new SparseArray<>();
//设置初始值
SparseArray<String> stringSparseArray = new SparseArray<>(5);
```

对应源码

```java
    //默认构造器 初始化容量为10
	public SparseArray() {
        this(10);
    }

	public SparseArray(int initialCapacity) {
        if (initialCapacity == 0) {
            mKeys = EmptyArray.INT;
            mValues = EmptyArray.OBJECT;
        } else {
            //初始化长度的数组
            mValues = ArrayUtils.newUnpaddedObjectArray(initialCapacity);
            mKeys = new int[mValues.length];
        }
        mSize = 0;
    }
```

存放的键值对分别放在两个数组`mKeys`、`mValues`，数据是一一对应的。

#### 插入数据

```java
stringSparseArray.put(1,"android");
```

对应源码

```java
public void put(int key, E value) {
        //利用二分查找，找到key应该插入的位置
        int i = ContainerHelpers.binarySearch(mKeys, mSize, key);

        if (i >= 0) {
            //找到已存在的值  直接进行覆盖
            mValues[i] = value;
        } else {
            //返回负数  需要取反获取插入的位置
            i = ~i;
            //当前没有越界 且原先该位置的数据已被删除 可以进行复用
            if (i < mSize && mValues[i] == DELETED) {
                mKeys[i] = key;
                mValues[i] = value;
                return;
            }

            if (mGarbage && mSize >= mKeys.length) {
                //压缩空间
                gc();①

                // Search again because indices may have changed.
                //
                i = ~ContainerHelpers.binarySearch(mKeys, mSize, key);
            }
            //插入数据，可能需要扩容
            mKeys = GrowingArrayUtils.insert(mKeys, mSize, i, key);②
            mValues = GrowingArrayUtils.insert(mValues, mSize, i, value);
            //存储数据+1
            mSize++;
        }
    }
```

①`gc()`：垃圾回收，对数组进行压缩

```java
private void gc() {
        int n = mSize;
        int o = 0;
        int[] keys = mKeys;
        Object[] values = mValues;
        //遍历values
        for (int i = 0; i < n; i++) {
            Object val = values[i];
            //对应值不为删除标记
            if (val != DELETED) {
                if (i != o) {
                    keys[o] = keys[i];
                    values[o] = val;
                    //防止内存泄漏，使用过后置空
                    values[i] = null;
                }
                //重新统计数据量
                o++;
            }
        }
        //标识 GC结束
        mGarbage = false;
        mSize = o;
    }
```

`gc()`实质是内部一个for循环，将value不为`DELETED`的数据重新插入数组中，以实现**对数组的压缩**，同时重置GC标志。

补充：`gc()`并非每次`remove`后立即触发，而是“延迟到后续关键操作时再集中处理”。

- 这种策略减少了删除时的即时成本。
- 但在`keyAt/valueAt/indexOf...`或插入扩容前，可能一次性支付压缩开销。

②`GrowingArrayUtils.insert(mKeys, mSize, i, key)`：插入数据 可能需要扩容

```java
    public static int[] insert(int[] array, int currentSize, int index, int element) {
        assert currentSize <= array.length;
        //不需要扩容
        if (currentSize + 1 <= array.length) {
            //将插入位置后的数据向后移一位
            System.arraycopy(array, index, array, index + 1, currentSize - index);
            array[index] = element;
            return array;
        }
        //需要进行扩容操作
        int[] newArray = ArrayUtils.newUnpaddedIntArray(growSize(currentSize));
        System.arraycopy(array, 0, newArray, 0, index);
        newArray[index] = element;
        System.arraycopy(array, index, newArray, index + 1, array.length - index);
        return newArray;
    }
    //重新设置数组容量
    public static int growSize(int currentSize) {
        return currentSize <= 4 ? 8 : currentSize * 2;
    }
```

`insert()`内部执行了两段操作：

- 不需要扩容：将需要插入位置的数据向后移一位，然后数据插入到对应位置。
- 需要扩容：扩容数据为原容量的2倍(*容量<=4时，扩容至8，其他情况下为2倍。*)，然后将原数组对应位置前的数据以及之后的数据分别插入扩容后数组。



> `put()`需要通过**二分查找法**找到可以插入的位置，如果当前位置的key相同，则直接覆盖原数据。如果key不相同但是`value`为`DELETED`，可以拿新的数据直接覆盖；如果不是，需要先判断`mGarbage`为true，就需要执行`gc()`压缩数组空间(*有效的数据按照顺序重新排布*)，然后再去插入新数据，过程中可能需要扩容。

补充：`append(key, value)`在“key严格递增”场景下更高效。

- `append`可避免中间插入导致的数组搬移。
- 若传入key并非递增，内部会退化回`put()`路径。

#### 获取数据

```java
//获取key对应的数据
stringSparseArray.get(1)
stringSparseArray.get(1,"iOS")
//获取key对应的下标
stringSparseArray.indexOfKey(1)  
//根据下标获取key
stringSparseArray.keyAt(0)
```

对应源码

##### 根据key获取value

```java
	public E get(int key) {
        return get(key, null);
    }

    @SuppressWarnings("unchecked")
    public E get(int key, E valueIfKeyNotFound) {
        //寻找key对应位置
        int i = ContainerHelpers.binarySearch(mKeys, mSize, key);

        if (i < 0 || mValues[i] == DELETED) {
            return valueIfKeyNotFound;
        } else {
            return (E) mValues[i];
        }
    }
```



##### 根据index获取key/value

```java
 	public int keyAt(int index) {
        //需要先判断是否GC
        if (mGarbage) {
            gc();
        }

        return mKeys[index];
    }

    public E valueAt(int index) {
        if (mGarbage) {
            gc();
        }

        return (E) mValues[index];
    }
```



##### 根据key/value获取index

```java
	public int indexOfKey(int key) {
     //查询下标时，也需要考虑是否先GC
        if (mGarbage) {
            gc();
        }
        //二分查找返回 对应的下标 ,可能是负数
        return ContainerHelpers.binarySearch(mKeys, mSize, key);
    }
    public int indexOfValue(E value) {
     //查询下标时，也需要考虑是否先GC
        if (mGarbage) {
            gc();
        }
        //不像key一样使用二分查找，而是线性遍历；比较方式是`==`而非`equals`
        //如果有多个key 对应同一个value，则这里只会返回一个更靠前的index
        for (int i = 0; i < mSize; i++)
            if (mValues[i] == value)
                return i;

        return -1;
    }

```



#### 删除数据

```java
//删除对应key的数据
stringSparseArray.remove(1);
//删除对应index的数据
stringSparseArray.removeAt(0);
//删除对应区间的数据
stringSparseArray.removeAtRange(0,1);
```

对应源码

##### 根据key删除数据

```java
public void remove(int key) {
        delete(key);
    }

public void delete(int key) {
    //二分查找到对应的index
        int i = ContainerHelpers.binarySearch(mKeys, mSize, key);
        //找到了对应位置
        if (i >= 0) {
            if (mValues[i] != DELETED) {
                //打上已删除标记
                mValues[i] = DELETED;
                //标记需要执行 gc()
                mGarbage = true;
            }
        }
    }
```



##### 根据index删除数据

```java
public void removeAt(int index) {
        if (mValues[index] != DELETED) {
            mValues[index] = DELETED;
            mGarbage = true;
        }
    }
```



##### 根据区间删除数据

```java
    public void removeAtRange(int index, int size) {
        final int end = Math.min(mSize, index + size);
        for (int i = index; i < end; i++) {
            removeAt(i);
        }
    }
```



`remove()`相关方法并不是直接删除数据，而是使用`DELETED`占据被删除数据的位置，同时设置`mGarbage=true`，等待调用`gc()`进行数据压缩。

> 设置`DELETED`的目的：如果`put()`时也要用到该位置，就可以不用进行数据复制，而直接放入数据即可。

### SparseArray拓展

- `SparseArray`的key是按照顺序从小到大排列的
- 由于压缩数组的原因，所以占用空间会比`HashMap`小，当数据量上来时，二分查找将会成为其性能瓶颈，所以适合数据量小的情况
- key为`int`类型，省去`Integer`拆箱的性能消耗。
- 由于`SparseArray`没有实现`Serializable`接口，所以不支持序列化即无法进行传递。

补充：选型时可按key类型与数据规模快速决策。

- `int -> Object`：优先`SparseArray`。
- `long -> Object`：优先`LongSparseArray`。
- 规模继续增大且操作复杂时，再评估`HashMap`与可读性/维护成本。
