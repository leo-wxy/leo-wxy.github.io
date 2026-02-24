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



## 知识点速记（Hook 全链路）

> 建议按 3 条线组织理解与排查：**SO 加载与时序** -> **Hook 原理与边界** -> **验证与排障**。

### 1) SO 加载原理：`JNI_OnLoad()` 是如何被调用的

- 主链路：`System.loadLibrary` -> ART(`JavaVMExt::LoadNativeLibrary`) -> NativeLoader(`OpenNativeLibrary`) -> `android_dlopen_ext` -> linker(`do_dlopen/find_libraries/mmap/relocate/call_constructors`) -> 返回 `handle`。
- 关键结论：`JNI_OnLoad` 不是 linker 调用的；而是 **`dlopen` 成功返回后**，ART 通过 `dlsym/FindSymbol("JNI_OnLoad")` 找到并调用。
- 返回值约束：`JNI_OnLoad` 必须返回合法 JNI 版本（如 `JNI_VERSION_1_6`），否则会报 `JNI_ERR returned from JNI_OnLoad`。
- 时序记忆点：`constructor/.init_array` 在 `dlopen` 内执行；`JNI_OnLoad` 在 `dlopen` 返回后执行。
- 关联文章：{% post_link Android中so加载流程 %}

### 2) linker namespace（Android 7+）：为什么“绝对路径也可能加载失败”

- Android N+ 引入 linker namespace；Java 的 `System.loadLibrary` 会把 ClassLoader 绑定到 namespace，并用 `android_dlopen_ext(ANDROID_DLEXT_USE_NAMESPACE)` 在该 namespace 内加载。
- `not accessible for the namespace` 通常不是 not found，而是 **可访问性规则拒绝**（依赖链不可见/误依赖系统私有库等）。
- 补充：即使 `dlopen("/system/lib64/libxxx.so")` 给绝对路径，也可能被 public NDK libraries/允许路径限制拦住。
- 对 Hook 的影响：可能出现“同名库多份实例/另一个 namespace 里后续加载新 so”，导致 hook 命中偏差或漏补。
- 关联文章：{% post_link Android中so加载流程 %}

### 3) PLT/GOT Hook（ByteHook/BHook 的主战场）：改哪里、何时生效

- 改动点：PLT Hook 改的是“调用方的导入重定位写回地址”（常见 GOT 表项），把 `orig_func` 替换为 `new_func`；不改函数本体。
- 生效前提：调用必须经过导入重定位项（不经过 GOT/PLT 就 hook 不到）。
- 快速自检：在调用方 so 里确认存在目标符号重定位项：`readelf -rW libcaller.so | rg "symbol"`。
- 常见失效原因（先判定调用路径）：同库直调 / `-Bsymbolic` / inline/LTO / `dlsym` 指针直调。
- 关联文章：{% post_link Android中的Hook-PLTHook %}、{% post_link BHook源码解析 %}

### 4) ByteHook automatic：多 SDK 共存为什么不打架

- hub/proxy：首次把 GOT 指到 hub trampoline，后续 hook 追加 proxy 链。
- 调用原函数：用 `BYTEHOOK_CALL_PREV` 动态取“下一跳”，避免多方 hook 下 orig 指针失真。
- unhook 语义：先删 proxy；仅最后一个 proxy 移除时才恢复 GOT 为 `orig_addr`。
- 关联文章：{% post_link BHook源码解析 %}

### 5) 为什么要监控 `dlopen/android_dlopen_ext/__loader_*`（增量补 Hook）

- 只扫一次会漏：插件化/动态特性会在运行期加载新 so；只在启动时 `dl_iterate_phdr` 扫一遍不够。
- 版本差异：N+ 常走 `android_dlopen_ext + namespace`；O+ 入口变为 `__loader_dlopen/__loader_android_dlopen_ext`。
- 工程闭环：`post_dlopen -> refresh ELF list -> 对新 ELF 重放 task`。
- 关联文章：{% post_link BHook源码解析 %}、{% post_link Android中so加载流程 %}

### 6) Inline Hook 原理（最小闭环）

- Patch Prologue：覆盖目标函数入口指令，写入跳转到 hook 的指令模板。
- Trampoline：把被覆盖的原始指令搬到 trampoline，末尾回跳到 `target + patched_len`，用于“还能调用原逻辑”。
- 页权限与缓存：`mprotect` 临时放开写权限；写完必须 flush I-Cache（`__builtin___clear_cache`），否则可能仍执行旧指令。
- 难点一句话：生产级难点在“PC-relative 指令重定位 + 并发 patch 窗口 + 兼容性”。
- 关联文章：{% post_link Android中的Hook-InlineHook %}

### 7) 如何验证 Hook 生效（验证要点）

- PLT/ByteHook：先用 `readelf -rW` 证明调用方确实有重定位项；运行时记录 `caller/symbol/reloc_type/got_addr/old/new/status/errno`，再做行为对比（返回值/副作用/日志）。
- Inline：按 5 步闭环验证：行为（安装前后变化）-> 字节（入口 prologue 是否变成跳转模板）-> trampoline（original 是否可调）-> 回滚（unhook 恢复）-> 归属（`dladdr` 确认目标模块）。



# 参考地址

[Android中Hook盘点](https://zhuanlan.zhihu.com/p/109157321)
