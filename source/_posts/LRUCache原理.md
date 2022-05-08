---
title: LruCache原理
date: 2018-12-14 16:40:15
tags: 源码分析
---

# LruCache

> 一般来说，缓存的策略主要包含缓存的`添加、获取和删除`。但由于缓存的大小都是有上限的。缓存慢了之后，要想继续添加 ，就需要删除一些旧的缓存以提供空间。
>
> 所以使用到了`LruCache`缓存算法，即**最近最少使用**算法，当缓存满时，会优先淘汰掉 最近最少使用的缓存对象。

**LruCache的核心原理就是利用了LinkedHashMap**。

## LruCache的使用

```java
        int maxMemory = (int)(Runtime.getRuntime().totalMemory()/1024);
        //设置LruCache缓存的大小
        int cacheSize = maxMemory/8;
        LruCache memoryCache = new LruCache<String,Bitmap>(cacheSize){
            @Override
            protected int sizeOf(@NonNull String key, @NonNull Bitmap value) {
                //重写sizeof方法，计算需要缓存的图片大小
                return value.getRowBytes() * value.getHeight() / 1024;
            }
        };
```

## LruCache的实现原理

`LruCache内部需要维护好一个缓存对象列表，其中对象的排列方式应该按照访问顺序排列的，即一直没访问的对象，要放在队尾，最近访问的对象就会放在对头，最晚被淘汰。`

查看源码中发现内部是利用了`LinkedHashMap`去缓存对象的。

```java
//LruCache构造方法
private final LinkedHashMap<K, V> map;    
public LruCache(int maxSize) {
        if (maxSize <= 0) {
            throw new IllegalArgumentException("maxSize <= 0");
        } else {
            this.maxSize = maxSize;
            this.map = new LinkedHashMap(0, 0.75F, true);
        }
    }

//LinkedHashMap的构造方法
public LinkedHashMap(/*map初始化大小*/int initialCapacity,
                         /*初始负载因子*/float loadFactor,
                         /*accessOrder意为访问顺序，若为true按照访问顺序排列，false则为插入顺序排列*/
                     boolean accessOrder) {
        super(initialCapacity, loadFactor);
        this.accessOrder = accessOrder;
    }

```

在`LruCache`构造方法中，设置了`maxSize`以及创建一个`LinkedHashMap`对象用来存储对象。

`LruCache`中需要移除最近最少使用的对象，即为优先删除访问最早对象，所以应该按照访问顺序排列，为true。

```java
//LruCache获取key对应的value 
public final V get(K key) {
        if (key == null) {
            throw new NullPointerException("key == null");
        }

        V mapValue;
        synchronized (this) {
            //返回不为null，就将其移到队列头部
            mapValue = map.get(key);
            if (mapValue != null) {
                hitCount++;
                return mapValue;
            }
            missCount++;
        }
        //当获取不到value的时候，会调用create()
        V createdValue = create(key);
        if (createdValue == null) {
            return null;
        }

        synchronized (this) {
            createCount++;
            mapValue = map.put(key, createdValue);

            if (mapValue != null) {
                // There was a conflict so undo that last put
                map.put(key, mapValue);
            } else {
                size += safeSizeOf(key, createdValue);
            }
        }

        if (mapValue != null) {
            entryRemoved(false, key, createdValue, mapValue);
            return mapValue;
        } else {
            trimToSize(maxSize);
            return createdValue;
        } 
   
 }
```

LruCache的`get()`实际调用的就是`LinkedHashMap`对应的`get(key)`

```java
public V get(Object key) {
        Node<K,V> e;
        if ((e = getNode(hash(key), key)) == null)
            return null;
        //如果按照访问顺序排列 则需要将该get对象移到尾部
        if (accessOrder)
            afterNodeAccess(e);
        return e.value;
    }

    /**
     * The head (eldest) of the doubly linked list.
     */
transient LinkedHashMapEntry<K,V> head;

    /**
     * The tail (youngest) of the doubly linked list.
     */
transient LinkedHashMapEntry<K,V> tail;
//将节点移到双端链表的尾部
void afterNodeAccess(Node<K,V> e) { // move node to last
        LinkedHashMap.Entry<K,V> last;
        if (accessOrder && (last = tail) != e) {
            LinkedHashMap.Entry<K,V> p =
                (LinkedHashMap.Entry<K,V>)e, b = p.before, a = p.after;
            p.after = null;。 
            if (b == null)
                head = a;
            else
                b.after = a;
            
            if (a != null)
                a.before = b;
            else
                last = b;
            
            if (last == null)
                head = p;
            else {
                p.before = last;
                last.after = p;
            }
            tail = p;
            ++modCount;
        }
    }
```

先调用`getNode()`获取key对应节点，如果不存在则返回null。若存在并且需要按照访问顺序排列，就把找到的节点移到双端链表的尾部。

 ```java
public final V put(K key, V value) {
        if (key == null || value == null) {
            throw new NullPointerException("key == null || value == null");
        }

        V previous;
        synchronized (this) {
            putCount++;
            //增加已有缓存大小
            size += safeSizeOf(key, value);
            //返回关键过这个key的对象
            previous = map.put(key, value);
            //若存在已关联对象 则恢复原先缓存大小
            if (previous != null) {
                size -= safeSizeOf(key, previous);
            }
        }

        if (previous != null) {
            entryRemoved(false, key, previous, value);
        }
        //每次put后，需要重新调整缓存大小避免超过上限
        trimToSize(maxSize);
        return previous;
    }

 ```

在调用`put`过后，需要调用一次`trimToSize()`调整缓存对象。

```java
    public void trimToSize(int maxSize) {
        while(true) {
            Object key;
            Object value;
            synchronized(this) {
                if (this.size < 0 || this.map.isEmpty() && this.size != 0) {
                    throw new IllegalStateException(this.getClass().getName() + ".sizeOf() is reporting inconsistent results!");
                }
                //直到缓存大小size<=最大缓存值maxSize
                if (this.size <= maxSize || this.map.isEmpty()) {
                    return;
                }
                //取出双链表中的头元素
                Entry<K, V> toEvict = (Entry)this.map.entrySet().iterator().next();
                key = toEvict.getKey();
                value = toEvict.getValue();
                //移除头部元素
                this.map.remove(key);
                this.size -= this.safeSizeOf(key, value);
                ++this.evictionCount;
            }

            this.entryRemoved(true, key, value, (Object)null);
        }
    }
```

原理总结：

内部是利用了`LinkedHashMap`来实现一个`最近最少使用算法`，在每次调用`put`和`get`时，都会算作一次对`LinkedHashMap`的访问，当设置`accessOrder`为`true`时，就会按照访问顺序排列，就会把每次访问的元素放在尾部，当缓存值达到阈值`maxSzie`后，就会去删除`LinkedHashMap`的首部元素，来降低内存占用。

`LinkedHashMap`在`HashMap`基础上使用了一个双端链表维持有序的节点。



## 自定义LRUCache

