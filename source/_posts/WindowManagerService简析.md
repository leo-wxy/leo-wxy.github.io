---
title: WindowManagerService简析
date: 2019-01-30 22:10:04
tags: Android
top: 10
---

## WindowManagerService的职责

> Window相关操作最终都在系统进程侧由`WindowManagerService`落地执行。应用进程通过`WindowManager`发起请求，再经`IWindowSession`与WMS通信。

## 一条主链路

`WindowManagerImpl.addView/updateViewLayout/removeView -> WindowManagerGlobal -> ViewRootImpl -> IWindowSession(addToDisplay/relayout/remove) -> WindowManagerService`

这条链路可以帮助快速定位问题到底出在：`应用侧View树`、`跨进程调用`，还是`系统侧窗口状态`。

### 1.窗口管理

WMS负责窗口的`添加、更新、删除、层级与焦点`等核心管理逻辑。

- `addWindow()`：校验`WindowToken/type/权限`，创建`WindowState`并挂到对应`DisplayContent`。
- `relayoutWindow()`：处理尺寸、可见性、Insets、软键盘模式等变化，并决定是否更新`Surface`。
- `removeWindow()`：移除窗口并清理输入通道、动画状态与相关引用。

除三大操作外，窗口焦点、可触摸区域和Z序变化，也都在这一层维护。

核心成员：`DisplayContent、WindowToken，WindowState`。

### 2.窗口动画

窗口切换、显示隐藏、层级变化等过程会触发动画调度，历史上主要由`WindowAnimator`体系管理。

- 动画执行会影响窗口可见状态与层级变更时机。
- 在过渡阶段，WMS需要保证“视觉状态”和“输入命中”尽量一致，避免出现可见但不可点、或可点但不可见等错位。

### 3.输入系统的中转站

WMS不直接消费触摸事件，但负责给输入系统提供“窗口命中依据”。

- `InputDispatcher`会基于WMS维护的窗口信息（焦点窗口、触摸区域、可见性等）选择目标窗口。
- WMS通过`InputMonitor`维护输入窗口列表，并在窗口状态变化时同步给输入子系统。
- 命中目标后，事件经`InputChannel`投递到应用进程，再由`ViewRootImpl`进入View树分发。

因此输入问题经常需要同时看：`窗口状态` + `View分发`两条链路。

### 4.Surface管理

WMS负责窗口与`Surface`生命周期的协调，但不直接负责最终合成。

- 在`relayoutWindow()`阶段，WMS会根据窗口状态决定`Surface`的创建、更新或回收。
- WMS管理的是窗口几何信息、层级、可见性和事务时机；最终图层合成由图形系统（如`SurfaceFlinger`）完成。
- 若窗口频繁`relayout`，可能带来额外绘制与合成开销。

## 关键数据结构速查表

| 对象 | 作用 | 典型关系 | 常见变化点 |
| --- | --- | --- | --- |
| `DisplayContent` | 描述一个显示设备上的窗口容器 | 持有该Display下的窗口树 | 屏幕旋转、多窗口模式切换 |
| `WindowToken` | 标识一组相关窗口的归属与合法性 | 关联多个`WindowState` | Activity切换、Dialog附着与销毁 |
| `WindowState` | 单个窗口在WMS中的运行时实体 | 挂在`DisplayContent`/`WindowToken`下 | add/remove/relayout、焦点变化 |
| `Session` | 应用进程到WMS的会话通道 | 对应`IWindowSession`服务端 | 进程死亡、窗口批量清理 |

## 常见问题与定位点

1. `BadTokenException`
   - 常见原因：`token`无效、Context不匹配、Activity已销毁后继续addWindow。
   - 首查：窗口归属与生命周期是否对齐。

2. `WindowLeaked`
   - 常见原因：页面退出前未及时`removeView/dismiss`。
   - 首查：是否在`onDestroy`或等价时机回收窗口。

3. 窗口遮挡或层级异常
   - 常见原因：`type/flag`配置不当或窗口层级预期错误。
   - 首查：窗口类型、焦点状态、可见区域。

4. 触摸不响应或误响应
   - 常见原因：焦点窗口错误、触摸区域变更未同步、上层窗口拦截。
   - 首查：输入命中窗口是否符合预期，再查View分发链路。

## 版本差异观察点

- 早期文章常见`AppWindowToken`等概念；新版本更强调`WindowContainer`层次化模型。
- Android高版本在多窗口、手势导航、刘海屏/折叠屏场景下，对窗口布局和Insets处理更复杂。
- 阅读WMS源码时应先确认系统版本，避免把旧版本结论直接套到新版本。

## 小结

WMS是窗口系统的核心调度者：向上承接应用进程的窗口请求，向下协调输入与渲染相关子系统。理解`add/relayout/remove`主链路和几个关键数据结构，通常就能覆盖大多数窗口问题排查场景。


