---
title: Android-DataBinding-Library分析
typora-root-url: ../
date: 2022-05-10 21:13:37
tags: 源码解析
top: 9
---



{% post_link Android-DataBinding-GradlePlugin分析 %}

回顾上节内容，GradlePlugin主要产出了以下文件，以便后续API功能调用

- **xx.xml**：正常的资源编译文件，后续apk中保留为这份文件。主要是将原始的xml文件中的 <layout> <data>标签移除，并未每个view设置`tag`
- **xx-layout.xml**：记录组件的绑定信息，如<data>标签内容，以及xml使用的表达式
- **XXBinding.java**：记录`View的id`以及`<data>定义的<variable>参数`，后文会有详细介绍
- **XXBindingImpl.java**：基于`XXBinding`的实现类，双向绑定参数的赋值逻辑均在内部实现，后文会有详细介绍
- **BR.java**：记录`@Bindable`以及`<variable>`相关参数
- **DataBinderMapperImpl.java**
  - 包名为 `androidx.databinding.library`：记录项目中ViewDataBinding的映射表，内部主要为 其他module里的`DataBinderMapperImpl.java`
  - 包名为`module 或 app`name：记录`module或app`中哪些布局文件使用了`DataBinding`，即使用`<layout>`包裹

## 相关模块

`baseLibrary`、`extensions/library`、`extensions/baseAdapters`

## 核心类

- `DataBindingUtil`
- `XXBindingImpl`
- `DataBinderMapperImpl`


## 执行流程

## 参考链接
[DataBinding原理](https://mdnice.com/writing/518996ef89c5413fb26025054edd9e6c)