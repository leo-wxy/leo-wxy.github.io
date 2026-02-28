---
title: ArrayMap简析
date: 2019-03-08 09:42:51
tags: Android
typora-root-url: ../
---

## ArrayMap

`ArrayMap`是Android提供的轻量级Map实现，核心目标是用更低的内存开销替代部分`HashMap`场景。

典型特点：

- `key/value`存储在数组中，避免`HashMap.Entry`对象开销
- 查询依赖`hash`有序数组 + 二分查找
- 更适合中小规模数据，且对内存敏感的场景

### 适用场景

- 数据量中小（例如几十到几百）
- 读多写少，结构相对稳定
- 运行在内存敏感路径（UI层、短生命周期对象）

不适用：

- 大规模高频写入
- 多线程并发读写

### 核心数据结构

`ArrayMap`（基于`SimpleArrayMap`）主要维护两组数组：

- `mHashes`：按升序保存key的hash值（`int[]`）
- `mArray`：交替存储`key/value`（`Object[]`，`[k0,v0,k1,v1,...]`）

这种结构减少对象数量，但插入/删除中间位置时需要数组搬移。

### 关键操作流程

#### put

1. 通过二分查找定位hash位置
2. hash冲突时线性探测相邻区间比对key
3. 找到则覆盖value；未找到则插入并可能触发扩容/搬移

#### get

1. 二分定位hash
2. 冲突区间按`equals`比对key
3. 返回对应value

#### remove

- 删除后会进行数组搬移，必要时触发容量收缩

### 扩容与缓存池（补充）

`ArrayMap`内部对小数组（常见4/8容量）有复用池策略，减少频繁分配带来的GC压力。

注意：

- 复用池是实现细节，不应依赖其行为做业务假设
- 高频增删场景仍可能出现明显搬移成本

### 与HashMap / SparseArray对比

- `HashMap`：大数据量、写入频繁时通常更稳
- `ArrayMap`：中小数据量下更省内存
- `SparseArray`：当key为`int`时，通常优先于`ArrayMap<Integer, V>`

### 使用注意事项

- 非线程安全：多线程场景需要外部同步
- 遍历过程中修改结构，可能触发`ConcurrentModificationException`
- 不要在热路径里盲目替换`HashMap`，应结合真实数据规模做压测

## 小结

`ArrayMap`本质是“以时间换空间”的中小规模Map实现。选型关键看三点：

1. 数据规模
2. 读写比例
3. 是否内存敏感


