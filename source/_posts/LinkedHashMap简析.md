---
title: LinkedHashMap简析
date: 2019-03-08 09:49:05
tags:
---

# LinkedHashMap简析

`LinkedHashMap`可以理解为：**在`HashMap`的基础上，再额外维护了一条双向链表来记录节点顺序。**

也正因为如此，它既保留了`HashMap`基于哈希桶定位元素的能力，又能让遍历结果具备稳定顺序。

## LinkedHashMap是什么

`LinkedHashMap`本质上还是一个`Map`结构：

- 允许`key`和`value`为`null`
- 默认不是线程安全的
- 平均情况下查询、插入、删除复杂度仍然可以看作接近`O(1)`

它和`HashMap`最大的区别不在于“查得更快”，而在于**遍历有序**。

更准确地说，`LinkedHashMap`维护的是：

- 哈希表结构：负责按`key`快速定位
- 双向链表结构：负责维护节点顺序

所以它并不是“排序Map”。如果你需要的是按大小、字典序等规则排序，通常应该看的是`TreeMap`，而不是`LinkedHashMap`。

## LinkedHashMap和HashMap的区别

两者的核心差异可以概括为：

- `HashMap`：不保证遍历顺序
- `LinkedHashMap`：可以保证插入顺序，或者访问顺序

代价也很直接：

- `LinkedHashMap`的每个节点要额外维护前驱、后继指针
- 插入、访问、删除时除了维护哈希桶结构，还要维护链表关系

但换来的好处是结果更稳定、可预测，特别适合：

- 需要按插入顺序输出配置
- 需要保留请求参数原有顺序
- 需要实现简单的最近最少使用淘汰(LRU)

## 底层结构

`LinkedHashMap`继承自`HashMap`，它并没有推翻`HashMap`的主体结构，而是在节点层和钩子方法上做了扩展。

核心思路是：

- 哈希桶定位逻辑仍然沿用`HashMap`
- 节点除了`hash/key/value/next`之外，还多了`before/after`
- 整个Map内部再通过`head`和`tail`把所有节点串成一条双向链表

可以把节点结构简单理解为：

```java
static class Entry<K,V> extends HashMap.Node<K,V> {
    Entry<K,V> before, after;
}
```

所以一个元素既属于某个桶，也属于整条顺序链表。

这也是为什么`LinkedHashMap`的遍历顺序稳定：遍历时并不是重新按哈希桶“扫一遍数组猜顺序”，而是直接沿着双向链表从`head`走到`tail`。

## 两种顺序模式

`LinkedHashMap`支持两种顺序模式：

### 1. 插入顺序

这是默认模式，对应构造参数里的`accessOrder = false`。

在这种模式下：

- 谁先插入，谁就更靠前
- 遍历顺序与插入顺序一致
- 如果某个`key`已经存在，再次`put`只是覆盖旧值，**不会因为覆盖而改变它原来的插入位置**

也就是说，插入顺序更强调“第一次进Map的先后”。

### 2. 访问顺序

如果构造时传入：

```java
new LinkedHashMap<>(16, 0.75f, true)
```

那么它会按访问顺序维护链表。

此时，最近被访问的节点会被移动到链表尾部，越久没被访问的节点越靠近头部。

这类“访问”通常包括：

- `get()`
- `getOrDefault()`
- 命中已有`key`的`put()`
- `putIfAbsent()`
- `compute/computeIfPresent/computeIfAbsent`
- `merge`

而像普通的遍历、集合视图迭代，并不会因为“看了一眼”就自动改变访问顺序。

这也是`LinkedHashMap`能够用来实现简单LRU缓存的核心原因：**链表头部更接近“最久未访问”，链表尾部更接近“最近访问”。**

## 核心钩子方法

`HashMap`内部其实预留了一些空钩子，供子类在节点访问、插入、删除后扩展行为。`LinkedHashMap`正是通过重写这些钩子，把“顺序维护”织进了`HashMap`原有流程里。

最重要的几个方法有：

- `afterNodeAccess()`
- `afterNodeInsertion()`
- `afterNodeRemoval()`

它们分别负责：

- 节点被访问后，必要时把它移动到链表尾部
- 插入节点后，必要时触发“是否淘汰最老节点”的判断
- 删除节点后，把它从双向链表里摘掉

其中最关键的是`afterNodeAccess()`：
当`accessOrder=true`时，节点被访问后就会被移动到尾部；当`accessOrder=false`时，这个动作通常不会改变顺序。

## removeEldestEntry()与LRU

`LinkedHashMap`最经典的用法，就是通过重写`removeEldestEntry()`实现固定容量淘汰。

例如：

```java
class LruMap<K, V> extends LinkedHashMap<K, V> {
    private final int maxSize;

    LruMap(int maxSize) {
        super(16, 0.75f, true);
        this.maxSize = maxSize;
    }

    @Override
    protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
        return size() > maxSize;
    }
}
```

这里有几个很容易混淆的点：

- `removeEldestEntry()`通常是在**插入新节点之后**被调用判断是否淘汰
- 它不是“每次访问都自动做淘汰检查”
- 如果只是覆盖已有`key`的值，没有新增节点，一般不会走“新增后淘汰”的语义

所以它更准确地说是一个“插入后检查容量策略”的钩子，而不是一个独立的缓存淘汰线程。

如果要做简单LRU缓存，通常需要：

- `accessOrder = true`
- `removeEldestEntry()`按容量返回`true`

这样链表头部就是“最久未访问”的节点，新增元素后就可以优先淘汰头部。

## 复杂度与适用场景

从大方向看，`LinkedHashMap`的大部分基本操作复杂度仍然与`HashMap`接近：

- 查询：平均`O(1)`
- 插入：平均`O(1)`
- 删除：平均`O(1)`

但它比`HashMap`多了一层链表维护成本和额外内存开销。

它特别适合这些场景：

- 需要稳定遍历顺序
- 需要保留插入顺序
- 需要实现简单 LRU
- 需要比`TreeMap`更低的常规访问开销，同时又不需要按比较规则排序

另外还有一个常被忽略的点：
`LinkedHashMap`的遍历顺序是沿链表走，因此遍历复杂度更接近**与实际元素个数相关**，而不是像纯哈希桶扫描那样更容易受到容量布局影响。

## 常见误区

### 1. 有序不等于排序

`LinkedHashMap`维护的是“插入顺序”或“访问顺序”，不是按`key`大小排序。

### 2. 默认不是访问顺序

如果不显式传入`accessOrder=true`，那么它维护的是插入顺序。

### 3. 已存在key再次put，不一定改变顺序

- 插入顺序模式下，覆盖旧值通常不会改变原有位置
- 访问顺序模式下，命中已有`key`的访问/更新通常会把节点移动到尾部

### 4. removeEldestEntry()不是随时触发

它更接近“新增之后做一次容量检查”，而不是每一次读写都立刻触发淘汰。

### 5. 不是线程安全容器

`LinkedHashMap`和`HashMap`一样，都不是线程安全的。在并发场景下如果缺乏外部同步，顺序链表和哈希桶结构都可能被并发修改破坏。

### 6. 迭代器同样是fail-fast

它本质上仍然继承自`HashMap`体系，所以迭代过程中如果发生结构性并发修改，仍然可能抛出`ConcurrentModificationException`。

### 7. 适合做简单LRU，不等于适合高并发缓存

`LinkedHashMap`做简单容量淘汰很方便，但它本身不负责：

- 高并发读写协调
- 复杂过期策略
- 权重淘汰
- 后台刷新或统计治理

所以它更适合作为轻量场景下的简单缓存容器，而不是直接替代成熟缓存组件。

## 小结

可以把`LinkedHashMap`概括成一句话：

**它是在`HashMap`快速定位能力的基础上，增加了双向链表来维护顺序。**

因此它最大的价值不在“更快”，而在：

- 遍历结果稳定
- 顺序语义明确
- 能低成本实现简单LRU

如果继续深入相关内容，可以结合下面这些文章一起看：

- `{% post_link HashMap实现原理及解析 %}`
- `{% post_link LRUCache原理 %}`
