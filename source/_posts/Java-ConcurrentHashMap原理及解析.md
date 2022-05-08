---
title: 数据结构--ConcurrentHashMap原理及解析
date: 2019-01-16 14:21:26
tags: 数据结构
top: 10

---

<!--主要是对HashMap，ArrayMap，ConcurrentHashmap-->

<!-- HashMap和HashTable的区别 , HashMap和ConcurrentHashMap的区别，HashMap的底层源码,HashMap的原理,ConcurrentHashMap，ArrayMap,SparseArray,hashmap线程不安全，请问为什么线程不安全？答，并发时会成环。什么时候成环？比如我有两个数据要装入hashmap。hashset和hashmap的区别，写代码使用hashmap实现一个简单的hashset。-->

<!-- https://juejin.im/post/59e86f9351882521ad0f4147, https://juejin.im/post/5a7592f4f265da4e8d42ded2 -->

<!-- hashmap实现的数据结构，数组、桶等。hashmap的哈希冲突解决方法：拉链法等。拉链法的优缺点。hashmap的参数及影响性能的关键参数：加载因子和初始容量。Resize操作的过程。hashmap容量为2次幂的原因。hashtable线程安全、synchronized加锁。hashtable和hashmap异同。为什么hashtable被弃用？-->

<!--关于HashMap扩容，1.8之前，如果不发生Hash冲突不会触发扩容，1.8之后，只要HashMap中的元素个数大于阈值，就发生扩容。（欢迎纠正）expectedSize / 0.75F + 1.0F  equals 和 hashcode 关系,HashMap遍历原理-->

{% fullimage /images/ConcurrentHashMap结构.png,ConcurrentHashMap结构,ConcurrentHashMap结构%}

> HashMap本身不是线程安全的，通常在多线程情况下可以去使用`HashTable`替代`HashMap`使用，该类中基本所有的操作方法都采用`synchronized`进行修饰，所以在高并发的情况下，每次只能有一个线程获取`对象监视器锁`，并发性能太低。
>
> 针对上述情况，就产生了`ConcurrentHashMap`这个类去解决上述问题，提高效率。

## ConcurrentHashMap重要参数分析

`table`：默认为`null`，初始化发生在第一次插入操作，默认大小为16的数组，用来存储Node节点数据，扩容时大小总是2的幂次方

```java
transient volatile Node<K,V>[] table;
```



<br>

`nextTable`：默认为null，扩容时使用，大小为原数组的2倍。

```java
private transient volatile Node<K,V>[] nextTable;
```

<br>

`sizeCtl`：该属性用来控制`table`的初始化和扩容操作。

- **-1**：表示当前数组正在初始化
- **-N**：表示当前争优`N-1`个线程进行扩容操作
- **0**：数组还未初始化
- **N**：1. table未初始化，表示table需要初始化的大小；2. table初始化完成，表示扩容阈值。**源码观察可知该值始终是 table容量的0.75倍**。

```java
volatile int sizeCtl;

// sizeCtl = n - (n>>>2)
```

<br>

`sun.misc.Unsage U`：利用该类实现`CAS算法`，实现一种乐观锁的操作。

<br>

`Node`：主要存放 key-value对，并且具有next域。可以保存`key、value、hash值`的数据结构。

```java
    static class Node<K,V> implements Map.Entry<K,V> {
        final int hash;
        final K key;
        //使用 volatile进行修饰 保证可见性
        volatile V val;
        volatile Node<K,V> next;
     ... 
    }
```

<br>

`ForwardingNode`：一个特殊的节点，`key、value、hash值`均为`null`，存储着对`nextTable`的引用

```java
    static final class ForwardingNode<K,V> extends Node<K,V> {
        final Node<K,V>[] nextTable;
        ForwardingNode(Node<K,V>[] tab) {
            super(MOVED, null, null, null);
            this.nextTable = tab;
        }
      ...
    }
```

只有table发生扩容的时候，`ForwardingNode`才有作用，作为一个占位符放在`table`中表示当前节点为`null`或者已经被移动。

<br>

## ConcurrentMap源码解析

### ConcurrentHashMap初始化

```java
public class ConcurrentHashMap<K,V> extends AbstractMap<K,V>
    implements ConcurrentMap<K,V>, Serializable {
    //构造一个空的map ，初始容量为默认值 16
    public ConcurrentHashMap() {
    
    }
    //设定map的初始容量
    public ConcurrentHashMap(int initialCapacity) {
        //小于0 直接抛出异常
        if (initialCapacity < 0)
            throw new IllegalArgumentException();
        //计算过程类比于 1.5 * initialCapacity + 1
        int cap = ((initialCapacity >= (MAXIMUM_CAPACITY >>> 1)) ?
                   MAXIMUM_CAPACITY :
                   tableSizeFor(initialCapacity + (initialCapacity >>> 1) + 1));
        //计算出的最终容量进行赋值
        this.sizeCtl = cap;
    }
    //插入一个map
    public ConcurrentHashMap(Map<? extends K, ? extends V> m) {
        this.sizeCtl = DEFAULT_CAPACITY;
        putAll(m);
    }    
    //设定map的初始容量及加载因子
    public ConcurrentHashMap(int initialCapacity, float loadFactor) {
        this(initialCapacity, loadFactor, 1);
    }        
    //设定map的初始容量，加载因子以及并发度 - 预计同事可操作数据的线程数
    public ConcurrentHashMap(int initialCapacity,
                             float loadFactor, int concurrencyLevel) {
        if (!(loadFactor > 0.0f) || initialCapacity < 0 || concurrencyLevel <= 0)
            throw new IllegalArgumentException();
        //容量会根据并发度进行调整
        if (initialCapacity < concurrencyLevel)   // Use at least as many bins
            initialCapacity = concurrencyLevel;   // as estimated threads
        long size = (long)(1.0 + (long)initialCapacity / loadFactor);
        int cap = (size >= (long)MAXIMUM_CAPACITY) ?
            MAXIMUM_CAPACITY : tableSizeFor((int)size);
        this.sizeCtl = cap;
    }
    
    /**
    * 对传入的初始容量进行操作，向上取整 得到最接近初始值的 符合2的幂次
    */
    private static final int tableSizeFor(int c) {
        int n = c - 1;
        n |= n >>> 1;
        n |= n >>> 2;
        n |= n >>> 4;
        n |= n >>> 8;
        n |= n >>> 16;
        return (n < 0) ? 1 : (n >= MAXIMUM_CAPACITY) ? MAXIMUM_CAPACITY : n + 1;
    }
  ...    
}
```

此时ConcurrentHashMap的初始化只是初始化了 table的容量，还未直接初始化`table`。需要等到第一次调用`put()`后执行。

### ConcurrentHashMap插入数据 - put()

> 向ConcurrentHashMap中插入数据

```java
ConcurrentHashMap concurrentHashMap = new ConcurrentHashMap();
concurrentHashMap.put("Android","best");
```

> `put()`源码

```java
    public V put(K key, V value) {
        return putVal(key, value, false);
    }

    final V putVal(K key, V value, boolean onlyIfAbsent) {
        //如果key或者value为null 直接抛出异常
        if (key == null || value == null) throw new NullPointerException();
        //计算出key对应的hash值
        int hash = spread(key.hashCode());①
        int binCount = 0;
        for (Node<K,V>[] tab = table;;) {
            Node<K,V> f; int n, i, fh;
            //当前table没有初始化
            if (tab == null || (n = tab.length) == 0)
                //table开始初始化
                tab = initTable();②
            else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) {③
                //利用CAS方式 直接插入值
                if (casTabAt(tab, i, null,new Node<K,V>(hash, key, value, null)))④
                    break;                   // no lock when adding to empty bin
            }
            //表示当前正在扩容
            else if ((fh = f.hash) == MOVED)
                tab = helpTransfer(tab, f);⑤
            else {
                V oldVal = null;
                //获取头节点的监视器锁
                synchronized (f) {
                    //在节点插入之前，在进行判断，防止被其他线程修改
                    if (tabAt(tab, i) == f) {
                        //当前为链表，在链表中插入新的键值对
                        if (fh >= 0) {
                            //记录链表长度
                            binCount = 1;
                            //开始遍历链表
                            for (Node<K,V> e = f;; ++binCount) {
                                K ek;
                                //如果找到了相等的key
                                if (e.hash == hash &&((ek = e.key) == key ||
                                     (ek != null && key.equals(ek)))) {
                                    //直接覆盖旧值
                                    oldVal = e.val;
                                    if (!onlyIfAbsent)                         
                                        e.val = value;
                                    break;
                                }
                                //到了链表末端，直接数据插到链表末端
                                Node<K,V> pred = e;
                                if ((e = e.next) == null) {
                                    pred.next = new Node<K,V>(hash, key, value, null);
                                    break;
                                }
                            }
                        }
                        //当前数据结构为 红黑树
                        else if (f instanceof TreeBin) {
                            Node<K,V> p;
                            binCount = 2;
                            if ((p = ((TreeBin<K,V>)f).putTreeVal(hash, key, value)) != null) {
                                oldVal = p.val;
                                if (!onlyIfAbsent)
                                    p.val = value;
                            }
                        }
                    }
                }
                //插入数据后再根据实际大小判断是否需要转换成红黑树
                if (binCount != 0) {
                    if (binCount >= TREEIFY_THRESHOLD)
                        //这个方法中不一定会进行红黑树的变换，如果当前数据的长度小于64 (MIN_TREEIFY_CAPACITY)
                        //就会执行扩容操作，而不是进行红黑树转化。
                        treeifyBin(tab, i);⑥
                    if (oldVal != null)
                        return oldVal;
                    break;
                }
            }
        }
        //对当前数组容量进行检查，超过了临界值，就需要扩容
        addCount(1L, binCount);⑦
        return null;
    }
```

`put()`操作主要包括以下几项：

①` int hash = spread(key.hashCode());`：计算Hash值

```java
    static final int spread(int h) {
        return (h ^ (h >>> 16)) & HASH_BITS;
    }
```

②`tab = initTable();`：如果table尚未初始化，就需要进行初始化操作

```java
private final Node<K,V>[] initTable() {
    Node<K,V>[] tab; int sc;
    while ((tab = table) == null || tab.length == 0) {
        // 当一个线程发现sizeCtl<0即正在初始化时，意味着另外的线程正在执行初始化操作，其他线程只能让出CPU等待table初始化完成
        if ((sc = sizeCtl) < 0)
            Thread.yield();
        // CAS 一下，将 sizeCtl 设置为 -1，代表抢到了锁 
        else if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
            try {
                if ((tab = table) == null || tab.length == 0) {
                    // DEFAULT_CAPACITY 默认初始容量是 16
                    int n = (sc > 0) ? sc : DEFAULT_CAPACITY;
                    // 初始化数组，长度为 16 或初始化时提供的长度
                    Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                    // 将这个数组赋值给 table，table 是 volatile 的
                    table = tab = nt;
                    // 如果 n 为 16 的话，那么这里 sc = 12
                    // 其实就是 0.75 * n
                    sc = n - (n >>> 2);
                }
            } finally {
                // 设置 sizeCtl 为 sc
                sizeCtl = sc;
            }
            break;
        }
    }
    return tab;
}
```

*table初始化的操作有且只有一个线程能够操作，其他线程通过`Thread.yield()`让出CPU时间片等待初始化完成。*

③`f = tabAt(tab, i = (n - 1) & hash))`：获取hash值转换后得到的存储位置的头节点`f`。*无论链表头节点还是红黑树的根节点都是在数组上的。*

```java
    static final <K,V> Node<K,V> tabAt(Node<K,V>[] tab, int i) {
        return (Node<K,V>)U.getObjectVolatile(tab, ((long)i << ASHIFT) + ABASE);
    }
```

在`JMM`中，每个线程都有他自己的工作内存，里面存储着数据的副本，虽然`table`是`volatile`修饰的，但不能绝对保证拿到的就是最新的数据，利用`U.getObjectVolatile`是直接取得指定内存的数据，可以保证每次拿到的都是最新的。

④`casTabAt(tab, i, null,new Node<K,V>(hash, key, value, null))`：由于发现存储位置上没有元素，则利用CAS直接插入新节点

```java
    static final <K,V> boolean casTabAt(Node<K,V>[] tab, int i,Node<K,V> c, Node<K,V> v) {
        return U.compareAndSwapObject(tab, ((long)i << ASHIFT) + ABASE, c, v);
    }
```

利用`CAS操作`直接将节点放入table对应位置中。但是如果CAS插入失败，意味着是一个并发操作，直接向下继续执行。

⑤`helpTransfer()`：帮助数据迁移

```java
    final Node<K,V>[] helpTransfer(Node<K,V>[] tab, Node<K,V> f) {
        Node<K,V>[] nextTab; int sc;
        if (tab != null && (f instanceof ForwardingNode) &&
            (nextTab = ((ForwardingNode<K,V>)f).nextTable) != null) {
            int rs = resizeStamp(tab.length);
            while (nextTab == nextTable && table == tab &&
                   (sc = sizeCtl) < 0) {
                if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1 ||
                    sc == rs + MAX_RESIZERS || transferIndex <= 0)
                    break;
                if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1)) {
                    transfer(tab, nextTab);
                    break;
                }
            }
            return nextTab;
        }
        return table;
    }
```

⑥`treeifyBin()`：当完成数据新节点插入后，会进一步对当前链表大小进行调整。当链表长度大于`TREEIFY_THRESHOLD`阈值，默认8，会进行链表转换红黑树，也可能是仅仅做数组扩容。

```java
private final void treeifyBin(Node<K,V>[] tab, int index) {
    Node<K,V> b; int n, sc;
    if (tab != null) {
        // MIN_TREEIFY_CAPACITY 为 64
        // 所以，如果数组长度小于 64 的时候，其实也就是 32 或者 16 或者更小的时候，会进行数组扩容
        if ((n = tab.length) < MIN_TREEIFY_CAPACITY)
            //扩容
            tryPresize(n << 1);
        // b 是头结点
        else if ((b = tabAt(tab, index)) != null && b.hash >= 0) {
            // 加锁
            synchronized (b) {

                if (tabAt(tab, index) == b) {
                    // 下面就是遍历链表，建立一颗红黑树
                    TreeNode<K,V> hd = null, tl = null;
                    for (Node<K,V> e = b; e != null; e = e.next) {
                       //链表节点转换树节点
                        TreeNode<K,V> p = new TreeNode<K,V>(e.hash, e.key, e.val, null, null);
                        if ((p.prev = tl) == null)
                            hd = p;
                        else
                            tl.next = p;
                        tl = p;
                    }
                    // 将红黑树设置到数组相应位置中
                    setTabAt(tab, index, new TreeBin<K,V>(hd));
                }
            }
        }
    }
}
```

⑦`addCount(1L, binCount)`：table存储键值对数量增加，然后需要判断是否超过扩容阈值，若超过需要进行扩容操作。

```java
private final void addCount(long x, int check) {
        CounterCell[] as; long b, s;
        if ((as = counterCells) != null ||
            !U.compareAndSwapLong(this, BASECOUNT, b = baseCount, s = b + x)) {
            CounterCell a; long v; int m;
            boolean uncontended = true;
            if (as == null || (m = as.length - 1) < 0 ||
                (a = as[ThreadLocalRandom.getProbe() & m]) == null ||
                !(uncontended = U.compareAndSwapLong(a, CELLVALUE, v = a.value, v + x))) {
                fullAddCount(x, uncontended);
                return;
            }
            if (check <= 1)
                return;
            s = sumCount();
        }
        if (check >= 0) {
            Node<K,V>[] tab, nt; int n, sc;
            while (s >= (long)(sc = sizeCtl) && (tab = table) != null &&
                   (n = tab.length) < MAXIMUM_CAPACITY) {
                int rs = resizeStamp(n);
                if (sc < 0) {
                    if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1 ||
                        sc == rs + MAX_RESIZERS || (nt = nextTable) == null ||
                        transferIndex <= 0)
                        break;
                    if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
                        transfer(tab, nt);
                }
                else if (U.compareAndSwapInt(this, SIZECTL, sc,
                                             (rs << RESIZE_STAMP_SHIFT) + 2))
                    transfer(tab, null);
                s = sumCount();
            }
        }
    }
```

### ConcurrentHashMap扩容操作 - tryPresize()

> 由上述源码可知，触发扩容动作的情况有两个：
>
> 1. 新增节点后，链表长度达到了8，就会调用`treeifyBin()`对其进行转换，但是如果此时存储的键值对数量如果未到64(`最小树形化阈值`)，就会触发`tryPresize()`扩大数组长度至原来的两倍，并调用`transfer()`进行数据迁移。
> 2. 新增节点后，会调用`addCount()`使存储数量 +1 ，还会去检测是否达到扩容阈值，达到时会触发`transfer()`，重新调整节点的位置。

```java
private final void tryPresize(int size) {
    // c：size 的 1.5 倍，再加 1，再往上取最近的 2 的 n 次方。
    int c = (size >= (MAXIMUM_CAPACITY >>> 1)) ? MAXIMUM_CAPACITY :
        tableSizeFor(size + (size >>> 1) + 1);
    int sc;
    //跳出循环的判断 需要依赖 transfer的操作结束
    while ((sc = sizeCtl) >= 0) {
        Node<K,V>[] tab = table; int n;

        // 初始化数组
        if (tab == null || (n = tab.length) == 0) {
            n = (sc > c) ? sc : c; //取大值
            if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
                try {
                    if (table == tab) {
                        @SuppressWarnings("unchecked")
                        Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                        table = nt;
                        sc = n - (n >>> 2); // 0.75 * n
                    }
                } finally {
                    sizeCtl = sc;
                }
            }
        }
        //已经超过最大上限 就不需要扩容了
        else if (c <= sc || n >= MAXIMUM_CAPACITY)
            break;
        else if (tab == table) {
            int rs = resizeStamp(n);

            if (sc < 0) {
                Node<K,V>[] nt;
                if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1 ||
                    sc == rs + MAX_RESIZERS || (nt = nextTable) == null ||
                    transferIndex <= 0)
                    break;
                // 2. 用 CAS 将 sizeCtl 加 1，然后执行 transfer 方法
                //    此时 nextTab 不为 null
                if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
                    transfer(tab, nt);
            }
            // 1. 将 sizeCtl 设置为 (rs << RESIZE_STAMP_SHIFT) + 2)
            //  调用 transfer 方法，此时 nextTab 参数为 null
            else if (U.compareAndSwapInt(this, SIZECTL, sc,
                                         (rs << RESIZE_STAMP_SHIFT) + 2))
                transfer(tab, null);
        }
    }
}
```



#### ConcurrentHashMap迁移数据 - transfer() **重要**

> 将原来旧表的数据迁移至新表中。

迁移过程涉及并发操作。原数组长度为n，所以会出现n个迁移任务，让每个线程单独去负责每一个迁移任务，每做完一个任务在检测是否有其他没做完的任务。

`transfer()`中利用了一个`stride(步长)`，每个线程负责迁移一部分。

再调用到`transfer()`的函数中观察到`transfer(tab, null)`在一次调用过程中只会存在一次，然后其他调用的时候`nextTable`已经初始化完毕，就不会在调用到空。

```java
 private final void transfer(Node<K,V>[] tab, Node<K,V>[] nextTab) {
        int n = tab.length, stride;
        //设置任务执行区域 NCPU代指CPU核数
        if ((stride = (NCPU > 1) ? (n >>> 3) / NCPU : n) < MIN_TRANSFER_STRIDE)
            stride = MIN_TRANSFER_STRIDEC;  //最小长度为 16
        //先进行一次 nextTable初始化 
        //这个过程只会发生一次
        if (nextTab == null) {            
            try {
                @SuppressWarnings("unchecked")
                //容量翻倍
                Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n << 1];
                //进行赋值 即 nextTable长度为旧表的两倍
                nextTab = nt;
            } catch (Throwable ex) {      // try to cope with OOME
                sizeCtl = Integer.MAX_VALUE;
                return;
            }
            nextTable = nextTab;
            //用于控制迁移的位置
            transferIndex = n;
        }
        
        int nextn = nextTab.length;
        //初始化 ForwardNode 代表正在被迁移的Node hash值 = MOVED
        ForwardingNode<K,V> fwd = new ForwardingNode<K,V>(nextTab);
        //表明该位置的迁移工作已经完成
        boolean advance = true;
        //所有迁移工作中是否完成
        boolean finishing = false; // to ensure sweep before committing nextTab
        // i 代表当前处理的槽位序号  bound 代表要处理的槽位边界 是从后向前的循环方式
        for (int i = 0, bound = 0;;) {
            Node<K,V> f; int fh;
            while (advance) {
                int nextIndex, nextBound;
                if (--i >= bound || finishing)
                    advance = false;
                //表明原数组的所有位置都有相应的线程进行处理
                else if ((nextIndex = transferIndex) <= 0) {
                    i = -1;
                    advance = false;
                }
                else if (U.compareAndSwapInt
                         (this, TRANSFERINDEX, nextIndex,
                          nextBound = (nextIndex > stride ?
                                       nextIndex - stride : 0))) {
                    //nextBound代表这次迁移任务的边界，当为0时，代表已经在处理了
                    bound = nextBound;
                    i = nextIndex - 1;
                    advance = false;
                }
            }
            //表明迁移任务已经结束
            if (i < 0 || i >= n || i + n >= nextn) {
                int sc;
                // 表明迁移任务结束
                if (finishing) {
                    nextTable = null;
                    table = nextTab;
                    //重新调整 sizeCtl 为新数组长度 0.75倍
                    sizeCtl = (n << 1) - (n >>> 1);
                    return;
                }
                // 迁移任务开始前 sizeCtl 会被设置为 rs << RESIZE_STAMP_SHIFT) + 2
                // 每有一个线程参与迁移任务 sizeCtl + 1
                // CAS对其进行 -1操作
                if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
                    if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
                        return;
                    //当sizeCtl 与初始值相同时 意味着所有的迁移已经完毕
                    finishing = advance = true;
                    i = n; // recheck before commit
                }
            }
            //位置 i 没有元素存在，那么直接放入初始化好的 ForwardingNode , 然后告知其他线程该位置已经迁移完毕
            else if ((f = tabAt(tab, i)) == null)
                advance = casTabAt(tab, i, null, fwd);
            //位置 i 上是 ForwardingNode 代表该位置已经迁移完毕
            else if ((fh = f.hash) == MOVED)
                advance = true; // already processed
            else {
                //需要对该位置节点操作加锁
                synchronized (f) {
                    if (tabAt(tab, i) == f) {
                        Node<K,V> ln, hn;
                        //代表当前结构是链表结构
                        if (fh >= 0) {
                            //将该位置的链表一分为二 按照
                            int runBit = fh & n;
                            Node<K,V> lastRun = f;
                            for (Node<K,V> p = f.next; p != null; p = p.next) {
                                int b = p.hash & n;
                                if (b != runBit) {
                                    runBit = b;
                                    lastRun = p;
                                }
                            }
                            if (runBit == 0) {
                                ln = lastRun;
                                hn = null;
                            }
                            else {
                                hn = lastRun;
                                ln = null;
                            }
                            for (Node<K,V> p = f; p != lastRun; p = p.next) {
                                int ph = p.hash; K pk = p.key; V pv = p.val;
                                if ((ph & n) == 0)
                                    ln = new Node<K,V>(ph, pk, pv, ln);
                                else
                                    hn = new Node<K,V>(ph, pk, pv, hn);
                            }
                            //将 ln 放在新数组的 i(即在旧数组的原位置) 上
                            setTabAt(nextTab, i, ln);
                            //将 hn 放在新数组的 i+oldCap 上
                            setTabAt(nextTab, i + n, hn);
                            //设置原数组上该位置的点为 ForwardingNode 代表该位置已经迁移完毕
                            setTabAt(tab, i, fwd);
                            //标记迁移完毕
                            advance = true;
                        }
                        //结构为 红黑树
                        else if (f instanceof TreeBin) {
                            TreeBin<K,V> t = (TreeBin<K,V>)f;
                            TreeNode<K,V> lo = null, loTail = null;
                            TreeNode<K,V> hi = null, hiTail = null;
                            int lc = 0, hc = 0;
                            for (Node<K,V> e = t.first; e != null; e = e.next) {
                                int h = e.hash;
                                TreeNode<K,V> p = new TreeNode<K,V>
                                    (h, e.key, e.val, null, null);
                                if ((h & n) == 0) {
                                    if ((p.prev = loTail) == null)
                                        lo = p;
                                    else
                                        loTail.next = p;
                                    loTail = p;
                                    ++lc;
                                }
                                else {
                                    if ((p.prev = hiTail) == null)
                                        hi = p;
                                    else
                                        hiTail.next = p;
                                    hiTail = p;
                                    ++hc;
                                }
                            }
                            // 如果一分为二后，节点数少于 8，那么将红黑树转换回链表
                            ln = (lc <= UNTREEIFY_THRESHOLD) ? untreeify(lo) :
                                (hc != 0) ? new TreeBin<K,V>(lo) : t;
                            hn = (hc <= UNTREEIFY_THRESHOLD) ? untreeify(hi) :
                                (lc != 0) ? new TreeBin<K,V>(hi) : t;
                            setTabAt(nextTab, i, ln);
                            setTabAt(nextTab, i + n, hn);
                            setTabAt(tab, i, fwd);
                            advance = true;
                        }
                    }
                }
            }
        }
    }
```

总结流程：

- 构建一个`nextTable`，它的容量是原来的两倍，这个操作只会执行一次。
- 根据hash值 计算对应的存储位置，然后根据`tabAt(i)`获得对应位置的头节点。
- 如果头节点为null，就在原table[i]放入`ForwardingNode`，代表当前位置已经迁移完毕。
- 如果头节点为链表节点，就构造一个反序链表，把他们分别放在`nextTable`中的`i和i+oldCap`位置上。放入成功后，在table[i]放入`ForwardingNode`，代表迁移完毕。
- 如果头节点为树节点，也做一个反序操作，并且判断是否需要重新转换成链表，再把处理后的结果分别放到`nextTable`中的`i和i+oldCap`位置上。放入成功后，在table[i]放入`ForwardingNode`，代表迁移完毕
- 遍历所有的节点就完成了数据迁移工作，让nextTable替代ConcurrentHashMap中的table，并更新`sizeCtl`为新数据容量的0.75倍，完成扩容。

### ConcurrentHashMap获取数据 - get()

> concurrentHashMap.get("Android");

源码解析：

```java
public V get(Object key) {
    Node<K,V>[] tab; Node<K,V> e, p; int n, eh; K ek;
    //计算 hash值
    int h = spread(key.hashCode());
    //当前数组不能为空
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (e = tabAt(tab, (n - 1) & h)) != null) {
        // 判断头结点是否就是我们需要的节点
        if ((eh = e.hash) == h) {
            if ((ek = e.key) == key || (ek != null && key.equals(ek)))
                return e.val;
        }
        // 如果头结点的 hash 小于 0，说明 正在扩容 -1 ，或者该位置是红黑树
        else if (eh < 0)
            // 参考 ForwardingNode.find(int h, Object k) 和 TreeBin.find(int h, Object k)
            return (p = e.find(h, key)) != null ? p.val : null;

        // 遍历链表
        while ((e = e.next) != null) {
            if (e.hash == h &&
                ((ek = e.key) == key || (ek != null && key.equals(ek))))
                return e.val;
        }
    }
    return null;
}
```

总结流程：

- 首先计算key对应的`Hash值`，定为到`table`上的对应位置，如果直接是头节点就返回
- 此时需要判断头节点的`hash值`
  - `hash值等于-1`：说明该节点为`ForwardingNode`，表明此时正在执行扩容操作，调用其`find()`从`nextTable`寻找对应值
  - `hash值等于-2`：说明该节点是一个树节点，调用`TreeBin.find()`去寻找对应值,**内部存在着读写锁，可能红黑树正在旋转变色。**
  - `hash值大于等于0`：说明该节点是一个链表节点，直接进行链表遍历寻找对应值即可。
- 如果都没有找到，就返回null

> 为什么`get()`不需要加锁？
>
> 关键点在于`table`是由`volatile`进行修饰的，这个关键字可以保证可见性以及有序性。如果对其声明的变量进行了写操作，JVM就会向处理器发送一条指令，将这个变量所在的缓存行数据写回到主内存。基于**缓存一致性协议**，其他线程去读取时，就要强制从主内存中读取。**在数组进行扩容时可以保证可见性。**
>
> 对存储的节点`Node`的`元素val`以及`指针next`也是用`volatile`进行修饰的，再、在多线程环境下对他们进行改变对其他线程也是可见的。



## 引用参考

[**Java7/8 中的 HashMap 和 ConcurrentHashMap 全解析**](https://javadoop.com/post/hashmap#put%20%E8%BF%87%E7%A8%8B%E5%88%86%E6%9E%90)

[深入浅出ConcurrentHashMap1.8](https://www.jianshu.com/p/c0642afe03e0)

[ConcurrentHashMap&HashTable](https://juejin.im/post/5df8d7346fb9a015ff64eaf9)