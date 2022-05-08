---
title: 数据结构--HashMap实现原理及解析
date: 2018-05-09 13:03:31
mathjax: true
tags: 
  - Java源码
  - 数据结构
top: 11
---

<!--主要是对HashMap，ArrayMap，ConcurrentHashmap-->

<!-- HashMap和HashTable的区别 , HashMap和ConcurrentHashMap的区别，HashMap的底层源码,HashMap的原理,ConcurrentHashMap，ArrayMap,SparseArray,hashmap线程不安全，请问为什么线程不安全？答，并发时会成环。什么时候成环？比如我有两个数据要装入hashmap。hashset和hashmap的区别，写代码使用hashmap实现一个简单的hashset。-->

<!-- https://juejin.im/post/59e86f9351882521ad0f4147, https://juejin.im/post/5a7592f4f265da4e8d42ded2 -->

<!-- hashmap实现的数据结构，数组、桶等。hashmap的哈希冲突解决方法：拉链法等。拉链法的优缺点。hashmap的参数及影响性能的关键参数：加载因子和初始容量。Resize操作的过程。hashmap容量为2次幂的原因。hashtable线程安全、synchronized加锁。hashtable和hashmap异同。为什么hashtable被弃用？-->

<!--关于HashMap扩容，1.8之前，如果不发生Hash冲突不会触发扩容，1.8之后，只要HashMap中的元素个数大于阈值，就发生扩容。（欢迎纠正）expectedSize / 0.75F + 1.0F  equals 和 hashcode 关系,HashMap遍历原理 -->

{% fullimage /images/HashMap结构.png,HashMap基础结构,HashMap基础结构%}

## HashMap定义

`HashMap`是基于`Map`接口实现的一种`键-值对<key,value>`的存储结构。内部允许`null`值，同时非有序，非同步(*线程不安全*)。它存储和查找数据时，是根据`key`的`hashcode`计算出具体的存储位置。内部最多允许一条记录的`key`为`null`。

`HashMap`的底层实现是**数组+链表+红黑树(Java 8新增的)**。

- 数组是HashMap的主体  *所以HashMap的容量指的就是 数组的长度。HashMap的size指的就为存储键值对数量。*

- 链表主要为了解决`Hash冲突`而存在的

  > 常用解决Hash冲突的方法有四种：
  >
  > - `开放地址法--线性探测` ：一般是在散列函数的基础上采取另一种算法，从而找到下一个空的数组位置，再将新数据填充进去。从而有效利用原数组空间。**若整个空间都找不到空余的地址，则产生溢出。**
  > - `链地址法（拉链法）`：基本思路是`全部具有同样哈希地址的而不同的Key的数据元素连接到同一个链表中`。加入在某个位置发生`Hash冲突`，就将新数据以链表的形式接在已有数据的后面。**HashMap1.7 是头插法，冲突的数据放在链表前端；HashMap在1.8之后是尾插法，冲突的数据放在链表尾端。**
  >   - 优点：无堆积现象存在，平均查找长度较短；节点空间是动态申请的，适用于无法缺点表长的情况；装填因子较大时，拉链法中增加的指针空间可忽略不计；删除节点的操作易于实现。
  >   - 缺点：指针需要额外的空间。
  > - `再哈希法`：同时构造多个不同的hash函数，直到不出现冲突为止。
  > - `建立公共溢出区`：将哈希表分为两部分：基本表和溢出表。所有冲突的数据都放到溢出表中。

- 当链表长度大于阈值(*一般为8*)时，会转换成红黑树，减少搜索时间(*最坏时间复杂度为 $ O(nlogn) $*)

## HashMap中的重要参数分析

```java
    static final int DEFAULT_INITIAL_CAPACITY = 1 << 4; // 初始容量 左移4位得到16
    static final int MAXIMUM_CAPACITY = 1 << 30; // 最大容量
```

`capacity 容量`：必须是2的幂 并且小于 `MAXIMUM_CAPACITY`$2^{30}$。默认容量为16，如果不设置初始容量的话。

> 为什么要转换为 $2^n$？
>
> - `可以提高取余的效率`。为了防止链表过长，要保证键值对在数组中尽可能均匀分布。确定元素位置的方法是通过`hash%length(table长度)`计算得出的。但是单纯的取余方式消耗相对较大，由于通过位运算`hash & (length-1)`得到的结果是一样的。**一个数对$ 2^n $取余，就是要去这个数二进制的最低n位。**
> - `有利于提高计算元素存放位置的效率`。可以有效降低`Hash冲突`几率。

<br>

```java
    final float loadFactor; // 实际负载因子
    static final float DEFAULT_LOAD_FACTOR = 0.75f; //默认负载因子
    
    int threshold;//扩容阈值 = 容量 * 负载因子
```

`loadFactor`：HashMap在其容量增加前可达到的最大负载。

> **LoadFactor取值范围为0~∞，当为0时会抛出IllegalArgumentException异常。**
>
> 主要分两种情况分析：
>
> - `loadFactory偏大`：则`HashMap`装载程度就会越高。意味着可以容纳更多的元素，空间利用率就会变高。但元素多了，发生`Hash冲突`的几率就会越大，从而链表会拉长，查询效率就会变低。
> - `loadFactory偏小`：则`HashMap`装载程度就会变低，容纳的元素就会变少，空间利用率就会变低。但是发生`Hash冲突`的几率变低，并且链表长度也会较短，提高查询效率。由于会发生频繁的扩容操作，对性能也会有影响。
>
> 合理的设置`loadFactory`：
>
> - 关心内存的话，采用`时间换空间策略`，适当的加大加载因子，牺牲查询速度，来换取更大的使用空间。
> - 关心时间的话，采用`空间换时间策略`，适当的减小加载因子，从而提高查询性能，但需要考虑到频繁扩容带来的性能消耗。

`threshold`：扩容阈值。当哈希表的大小 >= 扩容阈值时，就会进行扩容操作。例如`capacity设置16，loadFactory设置0.75，则阈值为12。当存储元素个数>12时，触发扩容。`

> 计算方式为`capacity * loadFactor`。
>
> `扩容`：对哈希表进行`resize`操作，扩大到原先的两倍表格大小。

<br>

```java
    static final int TREEIFY_THRESHOLD = 8; //桶的树化阈值
    static final int UNTREEIFY_THRESHOLD = 6; //桶的链表还原阈值
    static final int MIN_TREEIFY_CAPACITY = 64; //最小树形化容量阈值
```

`TREEIFY_THRESHOLD`：当链表长度大于该值时，链表就会转换成红黑树。

`UNTREEIFY_THRESHOLD`：当红黑树节点小于该值时，红黑树会转换回聊表。发生在`resize()`扩容时。

`MIN_TREEIFY_CAPACITY`：当哈希表中的容量大于该值时，才允许链表转换红黑树。

<br>

```java
    transient Node<K,V>[] table;  // 存储数据的Node类型 数组，长度 = 2的幂；数组的每个元素 = 1个单链表
    transient int size;// HashMap的大小，即 HashMap中存储的键值对的数量
```

## HashMap源码解析

### HashMap初始化

```java
public class HashMap<K,V> extends AbstractMap<K,V>
    implements Map<K,V>, Cloneable, Serializable {
  ...  
    /**
    * capacity = initialCapacity , loadFactory = loadFactor
    */   
    public HashMap(int initialCapacity, float loadFactor) {
        //初始容量不得 < 0
        if (initialCapacity < 0)
            throw new IllegalArgumentException("Illegal initial capacity: " +initialCapacity);
        //初始容量最大就是 MAXIMUM_CAPACITY    
        if (initialCapacity > MAXIMUM_CAPACITY)
            initialCapacity = MAXIMUM_CAPACITY;
        //负载因子必须 > 0
        if (loadFactor <= 0 || Float.isNaN(loadFactor))
            throw new IllegalArgumentException("Illegal load factor: " +
                                               loadFactor);
        this.loadFactor = loadFactor;
        //设置 扩容阈值
        this.threshold = tableSizeFor(initialCapacity);
    }
    
    /**
    * capacity = initialCapacity , loadFactory = 0.75
    */
    public HashMap(int initialCapacity) {
        this(initialCapacity, DEFAULT_LOAD_FACTOR);
    }
    
    /**
    * capacity = 16 , loadFactory = 0.75
    */
    public HashMap() {
        this.loadFactor = DEFAULT_LOAD_FACTOR;
    }
    
    /**
    * capacity = 16 , loadFactory = 0.75
    */
    public HashMap(Map<? extends K, ? extends V> m) {
        this.loadFactor = DEFAULT_LOAD_FACTOR;
        //将传入的子Map中的数据逐个添加到 HashMap中
        putMapEntries(m, false);
    }
  ...
 }
```

> 1. 在初始化`HashMap`中，只是进行了初始变量的赋值，还未进行`table`的设置
> 2. **真正初始化哈希表(table)是在第一次调用`put()`时。这个就是`lazy-load 懒加载`，直到被首次使用时，才会进行初始化。**

### HashMap插入数据 - put()

> 向`HashMap`中插入数据

```java
//调用示例
HashMap map = new HashMap();
map.put("Android","Best");
```

> `put()` 源码

```java
public V put(K key, V value) {
        return putVal(hash(key), key, value, false, true);
    }
```

在`put()`中，实现分为了两步：

- `hash()`：将`key`转化成`hash值`。通过`扰动函数`生成对应`hash值`。

  ```java
  static final int hash(Object key) {
          int h;
          return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
      }
  ```

  当`key==null`时，`hash值`为0 ，所以可以允许`key`设置为null，不过后续都会覆盖原值。

  当`key!=null`时，先获取原key的`hashcode()`，然后对其进行扰动处理： 按位异或(^) 再自身右移16位。

  > 所有处理的根本目的：**为了提高 存储键值对 的数组下标位置的随机性&分布均匀性，尽量避免出现Hash冲突。**

- `putVal()`：添加`key-value`的实际方法

  ```java
  final V putVal(int hash, K key, V value, boolean onlyIfAbsent,boolean evict) {
    //记录当前的hash表
    Node<K,V>[] tab; 
    //记录当前的链表节点
    Node<K,V> p; 
    //n 记录hash表长度 i 记录当前操作的index
    int n, i;
    //tab 为空则创建
    if ((tab = table) == null || (n = tab.length) == 0)
      // 初始化hash表，并把初始化后的hash表长度值赋值给n
      n = (tab = resize()).length;
     
    //通过hash & (length -1 ) 确定最后的元素存储位置
    if ((p = tab[i = (n - 1) & hash]) == null)
          //计算得出位置没有元素存在，则新建节点
          tab[i] = newNode(hash, key, value, null);
    else {
          //当前位置已存在节点，可能是修改或者发生了Hash冲突
          Node<K,V> e; 
          K k;
          //得到的Hash值相同 且 定义的key也相同 可以判定为修改操作
          if (p.hash == hash &&((k = p.key) == key || (key != null && key.equals(k))))
              //将结果赋值给 e
              e = p;
          // 当前节点是树节点
          else if (p instanceof TreeNode)
              //往红黑树结构中 插入新节点或者更新对应节点 如果是新增节点返回值为 null
              e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
          // 当前节点为链表节点
          else {
              for (int binCount = 0; ; ++binCount) {
                  //遍历链表到尾端也没有找到对应key值相同节点
                  if ((e = p.next) == null) {
                      //向尾端插入新节点
                      p.next = newNode(hash, key, value, null);
                      //如果链表长度大于 阈值，就会转换成红黑树结构
                      if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                          treeifyBin(tab, hash);
                      break;
                  }
                  //如果链表中存在key相同且hash值相同的节点，则更新对应值
                  if (e.hash == hash &&((k = e.key) == key || (key != null && key.equals(k))))
                      break;
                  p = e;
              }
          }
          // 发现对应的key，直接用新的value替换旧value，并返回旧value
          if (e != null) { // existing mapping for key
              V oldValue = e.value;
              if (!onlyIfAbsent || oldValue == null)
                  e.value = value;
              //默认空实现，但是 LinkedHashMap有 实现该方法
              afterNodeAccess(e);
              return oldValue;
          }
          
          ++modCount;
          //当前存储的键值对大于 阈值 则进行扩容操作。
          if (++size > threshold)
              resize();
          afterNodeInsertion(evict);
          //证明该操作为新增操作
          return null;
      }
    
  }
  
  
  ```

  {% fullimage /images/HashMap-put流程.png,HashMap-put流程,HashMap-put流程%}

  总结流程：

  1. 先判断`Node<K,V>[] table`是否为空或者null，是则执行`resize()`进行扩容
  2. 根据插入的键值`key`的`hash值`，通过`(length-1) & hash值`得到需要的存储位置`index`，如果该位置上没有数据，则直接新建节点插入该位置。
  3. 如果存储位置已有元素存在，就需要判断`index`上的元素的`hash值和key`是否和当前要操作的一致，一致则判定为`修改操作`，覆盖原元素的value即可
  4. 当前存储位置既有元素，并且`key`也不一致，则判定该位置发生了`hash冲突`。接下来去判断当前头节点是否为树节点(*红黑树*)，如果是就以红黑树的方式插入或修改节点。
  5. 如果头节点不是树节点，则为默认的链表节点，将新增节点直接插入至链表的尾端，然后继续判断当前链表的长度是否大于`TREEIFY_THRESHOLD-1`，大于则转化为`红黑树`。遍历过程中发现`key`已经存在，则直接覆盖`value`。
  6. 插入成功后，在判断当前存储的键值对数量是否大于 `threshold阈值`，大于则触发扩容`resize()`操作。


### HashMap扩容 - resize()

#### 为什么需要扩容

  > 当需要存储的数据量大于HashMap的初始容量时，就会造成部分数据出现在链表或红黑树上，性能比直接通过数组下表查询数据差很多，就需要扩容来减少此类数据，提供查询性能。

#### 如何触发扩容

> 1. `初始化哈希表`。上文分析`put()`时看到，如果哈希表为null或空，就会触发扩容进行哈希表初始化。
> 2. `当前数组容量过小，需要进行扩容`。HashMap存储的键值对大于`threshold`时，会触发扩容。

#### 源码解析

```java
    final Node<K,V>[] resize() {
        //扩容操作前的数组
        Node<K,V>[] oldTab = table;
        //扩容前的数组长度
        int oldCap = (oldTab == null) ? 0 : oldTab.length;
        //扩容前的扩容阈值
        int oldThr = threshold;
        //新容量及新阈值初始
        int newCap, newThr = 0;
        
        //触发扩容的条件为  原数组容量过小
        if (oldCap > 0) {
            //扩容前的数组长度已经达到最大值，则无法继续扩容
            if (oldCap >= MAXIMUM_CAPACITY) {
                threshold = Integer.MAX_VALUE;
                return oldTab;
            }
            //扩容后数组长度依然满足条件 则进行扩容
            else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                     oldCap >= DEFAULT_INITIAL_CAPACITY)
                //调整扩容阈值为原先2倍
                newThr = oldThr << 1; // double threshold
        }
        //触发扩容条件为 初始化哈希表
        else if (oldThr > 0) 
            newCap = oldThr;
        
        else {               
            newCap = DEFAULT_INITIAL_CAPACITY;
            newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
        }
        //计算新的扩容阈值上限
        if (newThr == 0) {
            float ft = (float)newCap * loadFactor;
            newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                      (int)ft : Integer.MAX_VALUE);
        }
        
        threshold = newThr;
        @SuppressWarnings({"rawtypes","uncheck ed"})
            Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
        //替换当前在用的数组
        table = newTab;
        
        //将扩容前的数据迁移到新表中
        if (oldTab != null) {
            for (int j = 0; j < oldCap; ++j) {
                Node<K,V> e;
                if ((e = oldTab[j]) != null) {
                    oldTab[j] = null;
                    if (e.next == null)
                        //数据是直接在数组上，直接进行赋值
                        newTab[e.hash & (newCap - 1)] = e;
                    else if (e instanceof TreeNode)
                        //数据在红黑树上，需要用红黑树的迁移方法
                        ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                    else { 
                        //数据在链表上 进行链表结构的扩容
                        Node<K,V> loHead = null, loTail = null;
                        Node<K,V> hiHead = null, hiTail = null;
                        Node<K,V> next;
                        do {
                            next = e.next;
                            //原索引
                            if ((e.hash & oldCap) == 0) {
                                if (loTail == null)
                                    loHead = e;
                                else
                                    loTail.next = e;
                                loTail = e;
                            }
                            //原索引 + oldcap
                            else {
                                if (hiTail == null)
                                    hiHead = e;
                                else
                                    hiTail.next = e;
                                hiTail = e;
                            }
                        } while ((e = next) != null);
                        //原索引值放到新数组中
                        if (loTail != null) {
                            loTail.next = null;
                            newTab[j] = loHead;
                        }
                        //原索引 + oldcap 放到新数组中
                        if (hiTail != null) {
                            hiTail.next = null;
                            newTab[j + oldCap] = hiHead;
                        }
                    }
                }
            }
        }
        return newTab;
    }

//树结构的扩容操作
 final void split(HashMap<K,V> map, Node<K,V>[] tab, int index, int bit) {
            TreeNode<K,V> b = this;
            // Relink into lo and hi lists, preserving order
            TreeNode<K,V> loHead = null, loTail = null;
            TreeNode<K,V> hiHead = null, hiTail = null;
            int lc = 0, hc = 0;
            for (TreeNode<K,V> e = b, next; e != null; e = next) {
                next = (TreeNode<K,V>)e.next;
                e.next = null;
                //bit 指向了 oldcap
                if ((e.hash & bit) == 0) {
                    if ((e.prev = loTail) == null)
                        loHead = e;
                    else
                        loTail.next = e;
                    loTail = e;
                    ++lc;
                }
                else {
                    if ((e.prev = hiTail) == null)
                        hiHead = e;
                    else
                        hiTail.next = e;
                    hiTail = e;
                    ++hc;
                }
            }

            if (loHead != null) {
                //小于树还原阈值，就需要重新变回链表样式
                if (lc <= UNTREEIFY_THRESHOLD)
                    tab[index] = loHead.untreeify(map);
                else {
                    tab[index] = loHead;
                    if (hiHead != null) // (else is already treeified)
                        loHead.treeify(tab);
                }
            }
            if (hiHead != null) {
                if (hc <= UNTREEIFY_THRESHOLD)
                    tab[index + bit] = hiHead.untreeify(map);
                else {
                    tab[index + bit] = hiHead;
                    if (loHead != null)
                        hiHead.treeify(tab);
                }
            }
        }
```

根据源码发现，扩容机制会在原基础上扩大两倍的容量进行存储。*扩容后就会把原先在链表以及红黑树上的数据，重新分配到新的数组上去。*

由于我们使用的2次幂的扩展(*每次扩容为原大小的2倍*)，所以元素在扩容后数组的位置要不在原位置（`index`），要不就在原位置加上扩容前的数组长度(`index + olcCap`)。

{% fullimage /images/扩容前后对比.png,扩容前后对比,扩容前后对比%}

简单的描述下，在链表上的数据如何进行扩容处理：

- 遍历旧表，如果元素的next为空(`node.nect == null`)，直接取余后放入新数组
- 元素后面接了一个链表，那么需要新建两条链表，`hi链和lo链`
- 开始遍历链表，计算每个元素的`hash值 & oldcap`的值，如果为0则插入`lo链末端`，不为0则插入`hi链末端`
- 遍历完成后，将两条链的头节点放入新数组中。`iohead`放入原来的位置，`hihead`放入原位置加上`oldcap`处。

{% fullimage /images/HashMap扩容过程.png,HashMap扩容过程,HashMap扩容过程%}

>  扩容后的元素移动方式就是**要不在原位置，要不就是原位置加上旧容量值的位置。** 

### HashMap获取数据 - get()

> 从HashMap获取数据

```java
map.get("Android");
```

> `get()`源码

```java
    public V get(Object key) {
        Node<K,V> e;
        return (e = getNode(hash(key), key)) == null ? null : e.value;
    }
    //根据计算出的Hash值 去获取对应结果
    final Node<K,V> getNode(int hash, Object key) {
        //记录当前的hash表
        Node<K,V>[] tab;
        //first 记录对应hash位置的第一个节点
        Node<K,V> first, e; 
        int n; 
        K k;
        //判断当前元素的存储位置是否有元素存在
        if ((tab = table) != null && (n = tab.length) > 0 &&
            (first = tab[(n - 1) & hash]) != null) {
            //头结点的hash值和要获取key的hash值相同 且 key相等
            if (first.hash == hash && // always check first node
                ((k = first.key) == key || (key != null && key.equals(k))))
                //返回头结点
                return first;
            //数组中不存在相等节点
            if ((e = first.next) != null) {
                //当前位置结构是 红黑树
                if (first instanceof TreeNode)
                    return ((TreeNode<K,V>)first).getTreeNode(hash, key);
                do {
                    //当前位置结构是 链表
                  /**
                   * 遍历单链表，逐一比较链表节点，链表节点的hash值与key的hash值相等，并且key也相等
                   */
                    if (e.hash == hash &&((k = e.key) == key || (key != null && key.equals(k))))
                        //返回对应节点
                        return e;
                } while ((e = e.next) != null);
            }
        }
        //经过上述方式都没找到 就返回null
        return null;
    }
```

{% fullimage /images/HashMap-get流程.png,HashMap-get流程,HashMap-get流程%}

总结流程：

- 先调用`key.hashcode ^ (h>>>16)`计算出`key`的`hash值`
- 根据计算出的`hash值`，通过`(length-1) & hash值`计算出存储位置`table[i]`，判断位置上是否有元素存在
- 存储位置上没有元素存在，则直接返回null。
- 存储位置上存在元素，首先比较头节点(`头节点在数组上`)，如果头节点的`key hash值`和要获取`key hash值`相同并且`first.key == key`，则返回该位置的头节点。
- 头节点元素不是要找的元素，就需要判定头节点的结构
- 头节点结构为 红黑树 (`first instanceof TreeNode`)，按照红黑树的方式遍历查找节点，有就返回，没有返回null
- 头节点结构为 链表(`first instanceof Node`)，遍历单链表，逐一进行比较，当链表节点的`key hash值`和要获取`key hash值`相同并且`first.key == key`，则返回该节点；遍历结束都没找到，就返回null。



## 拓展

### HashMap和HashTable以及HashSet的区别

> HashMap
>
> - 基于`AbstractMap`类，实现`Map、Cloneable(被克隆)、Serializable(序列化)`接口
>
> - HashMap的`key,value`都可以为`null`，`HashMap`遇到`key == null`时，数据会放在`table[0]`上
> - HashMap初始容量为16，负载因子默认0.75,并且容器长度一定是2次幂。扩容时，也已2倍大小进行扩容。
> - HashMap是先将`key`经过`key.hashcode() ^ (h>>>16)`计算出`hash值`，在拿`hash值`经过`hash & (length -1 )`得到最终存储位置
> - HashMap不是线程安全，如果想线程安全，可以通过`Collections.synchronizedMap()`包裹HashMap，实质上是对HashMap的所有操作加了锁(*用synchronized进行修饰*)。导致运行效率下降，推荐使用`ConcurrentHashMap`。

<br>

> HashTable
>
> - 基于`Map`接口和`Dictionry`类
>
> - HashTable的`key,value`不允许为`null`，如果`key ==null`，抛出空指针异常
> - HashTable初始容量为11，负载因子默认0.75，扩容时是以原容量的两倍加1进行扩容，即`newCap = (oldCap << 1)+1`
> - HashTable用的是除留余数法计算存储位置的.`int index = (hash & 0x7FFFFFFF) % tab.length`
> - HashTable是线程安全的，每个操作方法都用`synchronized`进行修饰保证同步，运行效率低，建议使用`ConcurrentHashMap`替换。

<br>

> HashSet
>
> - 实现了Set接口
> - 由于HashSet底层由HashMap实现，所以扩容机制与HashMap相同
> - HashSet只能存储对象，无法存储键值对。利用`add(E e)`插入对象，实质使用的是`HashMap.put(e,new Object())`进行操作。
> - HashSet和HashMap一样是线程不安全的。

### HashMap非线程安全，应该如何处理多线程下操作？何时会发生线程不安全情况？

HashMap不是线程安全的，如果多个线程同时对 HashMap 进行数据更改的话，会导致数据不一致或者数据污染甚至数据丢失。

当出现线程不安全的操作时，HashMap尽可能抛出`ConcurrentModificationException`异常。

- 当我们在对HashMap进行遍历时，如果在遍历期间我们对HashMap进行`put()、remove()`操作，会导致`modCount`发生变化(`exceptedModCount != modCount`)，然后抛出`ConcurrentModificationException`异常，这就是**`fail-fast快速失败`**机制。
- 由于存在扩容机制，多线程操作HashMap时，调用`resize()`进行扩容可能会导致死循环的发生。

如果想要线程安全，还是推荐使用`ConcurrentHashMap`。

### 使用HashMap时，使用什么对象作为key比较好？

**最好选择不可变对象作为key，因为为了计算`hashcode()`，就要防止键值改变，如果键值在放入时和获取时返回不同的hashcode，就会导致无法正确的找到对象。**

`String和Interger`等包装类就很适合作为key，而且`String`最常用。因为`String`是不可变的且`final`修饰(*保证key的不可更改性*)，并且已经重写了`equals()和hashcode()`方法(*不容易出现hash值的计算错误*)。

不可变性还有其他的优点例如`线程安全`。

### 如何使用自定义对象作为key？

HashMap的`key`可以是任何类型的对象，只要它遵守了`equals()和hashCode()`的定义规则，并且当对象插入到Map之后将不再会改变了。如果这个自定义对象是不可变的，那么它已经满足了作为键的条件。

> `hashcode()`和`equals()`都是用来对比两个对象是否相等一致。
>
> 由于重写的`equals()`内部逻辑一般比较全面和复杂，效率就会比较低。利用`hashCode()`进行对比，只要生成一个对应的`hash值`就可以了，然后比较两者的`hash值`是否相同，不同肯定不相等。比较效率较高。
>
> 但是如果`hash值`相同的话，可能会有两个情况：
>
> 1. 他们真的是相同对象
> 2. 由于hash的计算过程导致可能生成相同的`hash值`。
>
> 这个时候就需要用到`equals()`去进行比较。
>
> 在改写`equals()`时，需要满足以下3点：
>
> - 自反性：a.equals(a) 必须为 true
> - 对称性：`a.equals(b)`为true，则`b.equals(a)`必须成立
> - 传递性：`a.equals(b)`为true，并且`b.equals(c)`也为true，那么`a.equals(c)`也为true。
>
> **每当需要对比的时候，首先用`hashCode()`进行比较，如果`hashCode()`不一样肯定不相等，就不需要调用`equals()`继续比较。如果`hashCode()`相同，再调用`equals()`继续比较，大大提高了效率也保证了数据的准确。**



```java
class User{
        private int userId;
        private String name;

        public int getUserId() {
            return userId;
        }

        public void setUserId(int userId) {
            this.userId = userId;
        }

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o)
                return true;
            User user = (User) o;
            return userId == user.userId &&
                    Objects.equals(name, user.name);
        }

        //设定userid为hashcode
        @Override
        public int hashCode() {
            return userId;
        }

    }
```

### HashMap遍历

```java
    public static void getMap3(Map<String,String> map){
        Set<Map.Entry<String, String>> set = map.entrySet();
        for (Map.Entry<String, String> entry : set) {
            String value = entry.getValue();
            }
    }

    public static void getMap4(Map<String,String> map){
        Set<String> set = map.keySet();
        for (String entry : set) {
        String value = map.get(entry);
        }
    }
```



## 内容引用

[深入接触HashMap线程安全性问题](<https://juejin.im/post/5c8910286fb9a049ad77e9a3>)