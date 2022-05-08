---
title: WindowManagerService简析
date: 2019-01-30 22:10:04
tags: Android
top: 10
---

## WindowManagerService的职责

>  Window的相关操作都是借由`WindowManagerService`实现的，而且它是`WindowManager`的管理者。

### 1.窗口管理

负责窗口的启动、添加和删除。另外窗口的大小和层级也是交由WMS进行管理的。

核心成员：`DisplayContent、WindowToken，WindowState`。

### 2.窗口动画

窗口间进行切换时，窗口动画由WMS的动画子系统来负责，动画子系统的管理者为`WindowAnimator`。

### 3.输入系统的中转站

### 4.Surface管理



