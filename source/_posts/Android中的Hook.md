---
title: Android中的Hook
typora-root-url: ../
date: 2025-10-02 10:24:38
tags: Hook
top: 10
---

> Hook主要使用场景是
>
> - 绕过系统限制，修改已经实现的代码
> - 动态化，调用隐藏的API
> - 插件化、组件化

主要有如下几种Hook类型，会特别针对几类进行详细分析

## Android进程结构

![img](https://pic3.zhimg.com/v2-4671179da1589c1220fdc848d6e601a0_1440w.jpg)

- Linux进程

  - Art/Dalvik虚拟机 (为Java提供运行时环境)

    - Java Framework / Java App

    - ClassLoader
    - 内存管理

  - Native区

    - native代码 
    - 动态链接库

- Linux内核

  - 进程通信接口
    - Binder通信
    - Socket通信

hook就是针对上述Android进程中的组件，进行处理。

针对不同的组件，有不同的Hook方式：

- A点（Java层）：反射/动态代理
- B点（JNI）：JNI Hook
- C点（ClassLoader）：ClassLoader Hook
- D点（Method）：Xposed
- E点（So入口函数）：PLT/GOT Hook
- F点（So内部函数）：Inline Hook



## 反射/动态代理

{% post_link Hook技术简析 %}

### 优点

稳定性好，调用反射/动态代理并不存在兼容性问题

### 缺点

只能在Java层使用，通过替换对象方式来实现。

## ClassLoader

> 主要应用在热修复场景，通过**双亲委派机制**进行实现

{% post_link 热修复基本原理 %}

双亲委派：如果一个类加载器收到了类加载的请求，不会自己去尝试加载这个类，而把这个请求委派给父类加载器去完成，每一层都是如此，依次向上递归，直到委托到最顶层的`Bootstrap ClassLoader`，若父加载器无法处理加载请求（它的搜索范围内没有找到所需的类时），则交由子加载器去加载。

### 优点

稳定性高

### 缺点

需要使用已编译完成的class进行替换，灵活性低



## PLT/GOT Hook

{% post_link Android中的Hook-PLTHook %}

### 优点

- 所有so的入口函数都可以被hook
- 修改一次，全局生效
- 不需要写汇编指令

### 缺点

- 只能hook动态链接函数
- 无法hook静态链接函数/内部函数



## Inline Hook

{% post_link Android中的Hook-InlineHook %}

### 优点

- 可以hook几乎任意函数
- 进行精细控制

### 缺点

- 对CPU架构高度依赖
- 对汇编能力、内存保护等有要求
- 由于兼容性问题，导致稳定性较低



## Xposed

修改了ART/Davilk虚拟机，将需要hook的函数注册为Native层函数。当执⾏到这⼀函数是虚拟机会优先执⾏Native层函
数，然后再去执⾏Java层函数，这样完成函数的hook。

![xposed](/images/xposed.png)

### 优点

- Java层所有Class都可以进行修改
- 灵活性高

### 缺点

- 需要对每个Android大版本进行适配
- 兼容性差



[1](https://www.infoq.cn/article/android-in-depth-xposed)

[2](https://blog.csdn.net/codehxy/article/details/131906514)



# 参考地址

[Android中Hook盘点](https://zhuanlan.zhihu.com/p/109157321)

