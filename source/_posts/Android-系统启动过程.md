---
title: Android系统启动过程
typora-root-url: ../
date: 2020-11-12 21:37:13
tags: Android
top: 9
---

## 启动总览

Android 启动链路可以先按 7 个节点记忆：

1. BootROM
2. BootLoader
3. Linux Kernel
4. init（用户空间 1 号进程）
5. Zygote
6. SystemServer
7. Launcher（Home）

补充：从 framework 视角，真正高频关注的是 `init -> Zygote -> SystemServer -> Launcher` 这条链路。

### 启动阶段关键产物（补充）

- `BootLoader`阶段：完成硬件初始化与内核加载。
- `Kernel`阶段：驱动初始化、挂载关键文件系统、拉起`init`。
- `init`阶段：解析`rc`脚本并启动系统基础服务。
- `Zygote`阶段：预加载 + 等待孵化请求 + fork `SystemServer`。
- `SystemServer`阶段：启动 Java 系统服务并进入 system ready。
- `Launcher`阶段：Home 进程拉起并进入可交互首屏。

从稳定性角度看，每个阶段的输出都是下一阶段的输入，任何前序阻塞都会向后放大。



## 从内核到 init

- 内核启动后挂载根文件系统，启动用户空间的 `init`。
- `init` 会解析 `init.rc` 及 import 的 rc 脚本，按触发器（`on xxx`）执行动作。
- 关键系统服务（含 zygote）在这个阶段由 `init` 拉起。

补充：`init`通常可以理解为两阶段：

1. **first-stage init**：早期挂载、设备节点准备、基础安全环境建立。
2. **second-stage init**：解析`rc`并驱动完整服务编排（含属性服务与事件触发）。

常见触发链可简化理解为：`early-init -> init -> late-init -> zygote-start`。

补充：`init` 是 Android 用户空间“总调度入口”，后续很多系统能力都由它托管生命周期。



## init 拉起 Zygote

典型 rc 里会定义 zygote service（32/64 位机型可能不同）：

- 可执行入口：`app_process`（如 `app_process64`）
- 参数：`--zygote --start-system-server`

补充：

- `--zygote` 代表进入孵化器模式
- `--start-system-server` 代表 zygote 启动后会 fork 出 SystemServer

在 64 位设备上，通常还会看到`zygote64/zygote32`协同形态（具体以机型与系统配置为准），用于兼容不同 ABI 的应用进程创建。



## Zygote 关键流程

Zygote 启动后主要做三件事：

1. 创建 Server Socket，等待 AMS 的创建进程请求
2. 预加载常用类/资源（preload），降低后续 App 冷启动成本
3. fork 出 `SystemServer`，进入系统服务启动阶段

补充：预加载本质是“用启动时空间换运行时时间”，减少每个 App 进程重复初始化。

### Zygote 内存优化核心（补充）

核心思路：Zygote 把“公共部分”提前加载成可共享内存，`fork` 后依赖 `COW`，子进程只做个性化初始化，尽量少把共享页写脏。

- `fork + COW`：子进程初始不复制父进程页，只有写入时才复制，显著降低启动时内存开销。
- `预加载并共享`：Zygote 预加载 framework 类、资源、部分 so，子进程直接复用这些页，避免重复加载。
- `ART 映像共享`：`boot.art/oat/vdex` 这类映射页多为只读，可跨进程共享，降低每个 App 私有内存。
- `控制脏页`：预加载后通过 `GC/Finalize/trim` 尽量保持静态对象稳定；共享页一旦写脏会触发 COW，内存随之上升。
- `fork 前后钩子`：`preFork/postFork` 会暂停/恢复运行时关键线程，降低 fork 时状态复杂度与内存扰动。
- `子进程专有初始化后置`：`UID/权限/ClassLoader/应用逻辑` 放到 child 做，减少对 Zygote 公共页的污染。

可直接总结为：Zygote 省内存的关键不只是 `fork`，而是“共享页尽量不被写脏”；写脏越多，COW 复制越多，`PSS` 就越高。

### 应用进程创建链路（补充）

应用冷启动时，常见路径可以抽象为：

1. AMS判定目标进程不存在，进入`startProcessLocked`。
2. 通过`ZygoteProcess`向 zygote socket 发送创建参数。
3. Zygote 执行`forkAndSpecialize`，子进程完成 UID/GID/SELinux 等专有设置。
4. 子进程进入`ActivityThread.main()`，绑定 Application 并进入主线程消息循环。

这条链路里，真正“贵”的步骤往往不在 fork 本身，而在 fork 后子进程的类加载、资源初始化与主线程阻塞。

### 共享页写脏的典型来源（补充）

- 子进程在早期大量修改静态缓存对象。
- 预加载后又在子进程改写本应稳定的全局结构。
- 初始化阶段引入高频写操作，导致共享页快速私有化。

优化方向就是一句话：把“可共享内容”尽量做成只读或稳定结构，把“个性化可变内容”后置到子进程并限制写放大。



## SystemServer 启动三阶段

`SystemServer` 主流程可概括为：

- `startBootstrapServices()`
- `startCoreServices()`
- `startOtherServices()`

其中会陆续启动：

- AMS（ActivityManagerService）
- PMS（PackageManagerService）
- WMS（WindowManagerService）等核心服务

补充：AMS/WMS/PMS 的 ready 时序决定了“何时可拉起桌面、何时可响应应用启动”。

### SystemServer 编排方式（补充）

`SystemServer`内部通常通过`SystemServiceManager`统一管理服务生命周期，核心动作包括：

- 创建服务实例
- 调用`onStart()`完成注册
- 在系统阶段切换时分发`boot phase`回调

这使得服务启动具备可编排性：不仅“启动顺序”可控，“阶段行为”也可控。

从排障角度看，若某核心服务在早期 phase 卡住，后续依赖服务会级联延迟。



## Launcher 启动到可交互

- SystemServer 在关键服务 ready 后，通过 AMS 拉起 Home（Launcher）。
- Launcher 完成 `onCreate/onStart/onResume` 后进入首帧绘制。
- 用户可见“系统启动完成”通常以 Launcher 可交互为标志。

补充：生命周期到 `onResume` 不等于像素已上屏，首帧可见还要经过渲染/合成。

可把“可见”再细分为两层：

- **生命周期可见**：组件回调已进入前台态（如`onResume`）。
- **图像可见**：首帧完成`measure/layout/draw`并经合成后真正显示到屏幕。

启动体验优化通常以第二层为目标，因为这是用户真正感知的时间点。



## 启动链路里的角色分工

- `init`：进程与服务生命周期托管（用户空间根进程）
- `Zygote`：进程孵化与预加载
- `SystemServer`：Java 系统服务宿主
- `Launcher`：用户交互入口



## 启动排障观测点（补充）

- 看阶段完成标记：例如`sys.boot_completed`是否置位。
- 看事件日志时间线：关注`boot_progress_*`类关键点是否长时间停顿。
- 看 SystemServer 主线程是否被慢初始化阻塞。
- 看 Launcher 首帧之前是否存在主线程重活或 IO 抖动。

实战建议：先判定“卡在哪个阶段”，再下钻到该阶段内的关键线程与关键服务，避免全链路盲查。



## 常见问题（补充）

1. 为什么 App 进程创建快？

   因为大多数是 Zygote fork，复用预加载成果。

2. 为什么系统服务都在 SystemServer？

   统一管理、统一调度，降低跨进程组织复杂度。

3. 启动慢先看哪里？

   先看 `init -> zygote -> system_server` 是否有阻塞，再看 Launcher 首帧路径。

4. 为什么有些机型同样流程但内存占用差异大？

   关键看共享页是否被大量写脏。写脏越多，COW复制越多，进程私有页与PSS都会上升。



## 后续追问与答题要点（补充）

- **为什么需要 Zygote？** 统一预加载 + `fork` 孵化，减少每个 App 重复初始化成本。
- **Zygote 省内存关键是什么？** 不是只靠`fork`，而是尽量避免共享页写脏，减少 COW 复制。
- **Zygote 预加载了什么？** framework 常用类、资源、部分 so 与运行时映像。
- **App 进程怎么创建？** AMS `startProcessLocked` -> zygote socket 请求 -> `forkAndSpecialize` -> `ActivityThread.main()`。
- **SystemServer 为什么关键？** 它是 Java 系统服务宿主，AMS/PMS/WMS 等核心服务都在此启动。
- **SystemServer 启动怎么分段？** `startBootstrapServices`、`startCoreServices`、`startOtherServices`。
- **什么时候算启动完成？** 系统口径看`boot_completed`，用户口径看 Launcher 首帧可交互。
- **启动慢先看哪里？** 先分段定位 `init -> zygote -> system_server -> launcher`，再下钻具体线程与服务。
- **冷启动和热启动差异？** 冷启动要新建进程并走完整初始化，热启动更多是复用现有进程与状态。
- **同链路下内存差异来源？** 共享页写脏程度不同，COW 复制量不同，最终 PSS 不同。



## 小结

Android 启动是分层接力模型：

- 底层完成硬件与内核准备
- `init` 建立用户空间服务框架
- `Zygote` 负责孵化
- `SystemServer` 拉起系统服务
- `Launcher` 对外提供可交互桌面
