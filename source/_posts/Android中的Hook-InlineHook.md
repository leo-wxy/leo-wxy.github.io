---
title: Android中的Hook-InlineHook
typora-root-url: ../
date: 2025-10-02 11:10:44
tags: Hook
top: 10
---

![InlineHook](/images/InlineHook.png)

# Inline Hook

> 本文定位：面向 Android 开发者的 Inline Hook 原理入门，重点是理解“为什么要用、怎么工作、如何验证生效”。
>

在 `{% post_link Android中的Hook-PLTHook %}` 里，PLT Hook 的切入点是“导入方模块的 GOT 表项”。 
这意味着它拦截的是**调用路径**，不是**函数本体**。

## 与 PLT Hook 的边界差异

PLT Hook 生效的前提是：目标调用必须经过动态链接导入表（PLT/GOT）。因此：

- 能拦截：跨 so 的外部符号调用。
- 常拦不到：同一 so 内部直接调用、`static` 函数、被内联后不存在的调用点。
- 可能失效：`-Bsymbolic`、LTO、符号裁剪、符号版本不匹配等场景。

Inline Hook 的切入点是“目标函数入口指令”。  
只要执行流进入该函数入口，就会先跳转到 Hook 函数，因此覆盖范围通常更大。

## 典型适用场景（为什么必须用 Inline）

1. 目标函数是 so 内部实现，不经过导入表，PLT Hook 没有命中点。  
2. 需要拦截库内高频逻辑（编解码、渲染、加解密等）做行为观测。  
3. 需要在不改业务源码的前提下注入逻辑、定位问题或灰度防护。  
4. 需要保留原函数能力，在 Hook 函数中按条件回调原逻辑。  

一句话：**PLT Hook 改“调用入口”，Inline Hook 改“函数入口”。**

# Inline Hook 核心原理

从 Android 开发者角度，Inline Hook 可以抽象成三个动作：**改写入口、搭建跳板、回跳原流程**。主要理解这条主链路

## 1. 函数入口改写（Patch Prologue）

在目标函数起始地址覆盖若干条机器指令，写入“跳转到 Hook 函数”的指令序列。  
改写后，任何进入该函数入口的执行流都会先进入 Hook 函数。

关键点：

- 覆盖长度必须满足最小跳转需求，并按指令边界覆盖（AArch64 固定 4 字节）。  
- 不能覆盖半条指令，否则通常直接崩溃。

## 2. 跳板函数（Trampoline）

被覆盖的原始指令不能丢弃，否则“调用原函数”会断链。  
通常会申请一段可执行内存作为 trampoline，写入：

1) 被覆盖的原始指令（必要时重定位修复）；  
2) 一条回跳指令，跳回 `target + patched_len` 继续执行。

这样 Hook 函数就可以通过 trampoline 调用原函数剩余逻辑。

## 3. 指令重定位（概念了解）

Inline Hook 最难的不是“写跳转”，而是“搬指令”。  
如果被搬走的指令包含 PC 相对寻址（如 `ADR/ADRP/LDR literal/B/BL`），直接复制到 trampoline 会因为地址变化而语义错误。

入门阶段先记住结论：实现里通常要做“指令重定位”，把这类指令在 trampoline 中改写成等价逻辑，保证地址语义不变。

## 4. 内存权限与缓存一致性

代码段通常是只读可执行（RX），写入前后要处理权限和缓存：

1. 页对齐后用 `mprotect` 临时把代码页改为可写（通常会保持可执行权限）；  
2. 写入补丁指令；  
3. 刷新 I-Cache（如 `__builtin___clear_cache`），确保 CPU 能执行到新指令；  
4. 恢复为只读可执行（通常 `RX`）。

否则会出现“写入成功但仍执行旧指令”或权限异常。

## 5. 调用链闭环

一个完整调用链通常是：

`caller -> target(入口已改写) -> hook -> (可选) trampoline -> target+N -> return`

如果继续做工程化，通常还会补这些能力：

- 防递归（TLS guard），避免 Hook 内再次命中自己；  
- 线程安全（安装/卸载加锁）；  
- 可回滚（保存原始字节，支持 unhook）。





# ARCH_ARM64（arm64-v8a / AArch64）最小知识集

在 Android 上，`ARCH_ARM64` 对应 ABI `arm64-v8a`，执行状态是 `AArch64`。  
Inline Hook 在该架构下的实现与 `ARMv7(A32/Thumb)` 有明显差异，必须分开理解。

这一节只保留和 Android 开发面试/排障最相关的概念。

## 1. AArch64 基础模型

### 执行状态与 ABI

- `arm64-v8a` 是 Android NDK 的 64 位 ABI，对应 CPU 运行在 `AArch64` 状态，执行 `A64` 指令。
- `armeabi-v7a` 是 32 位 ABI（A32/Thumb），Inline Hook 的很多细节不可直接复用。
- 工程里常用 `__aarch64__` / `__arm__` 做编译分支（有些实现会抽象成 `ARCH_ARM64` 宏）：

```c++
#if defined(__aarch64__)
// ARM64 inline hook path
#elif defined(__arm__)
// ARM32/Thumb inline hook path
#endif

```

### 寄存器与调用约定（AAPCS64）

- 通用寄存器：`X0 ~ X30`（`W0 ~ W30` 是低 32 位视图）。
- `X0 ~ X7`：参数与返回值（返回通常在 `X0`）。
- `X30`：链接寄存器（LR，保存返回地址），`SP` 需要 16 字节对齐。

> 对 Hook 的意义：保存/恢复现场、构造 trampoline、回调原函数都依赖这些约定。



## 2. 指令集差异（A64 vs A32/Thumb）

| 维度 | ARM64 (A64) | ARMv7 (A32/Thumb) | 对 Inline Hook 的影响 |
| :-- | :-- | :-- | :-- |
| 指令长度 | 固定 4 字节 | Thumb 2/4 字节混合 | ARM64 更容易按指令边界覆盖入口 |
| 状态位 | 无 Thumb | 需要区分 ARM/Thumb（函数地址 bit0 常携带状态） | ARM64 不需要处理 Thumb bit |
| PC 相对指令 | `ADR/ADRP/LDR literal/B/BL` 很常见 | 编码与语义不同 | trampoline 的重定位逻辑不能复用 ARM32 |



## 3. ARM64 中与 Hook 最相关的指令

Inline Hook 里常见且需要优先记住的就是下面三类：

- `B` / `BL`：分支/调用指令，PC 相对跳转，范围约 `±128MB`
- `ADR` / `ADRP`：生成地址（常用于取全局/常量地址），属于 PC 相对寻址
- `LDR (literal)`：从常量池取值/地址，属于 PC 相对寻址

其它如 `B.cond` / `CBZ` / `TBZ` 等本质也是“短距 PC-relative 分支”，搬运到 trampoline 时同样需要重定位处理。

> 这些指令一旦被“搬到 trampoline”，若不重算偏移，通常会直接跑偏。



## 4. 指令差异对 Inline Hook 的直接影响

### 入口改写（Patch Prologue）

ARM64 固定 4 字节指令，让入口覆盖更可控，但仍要满足：

- `patch_len` 必须是 4 的倍数；
- 必须覆盖完整跳转模板；
- 不能覆盖半条指令。

### 近跳与远跳策略

- 目标地址在 `±128MB` 内，可用单条 `B`（4B）近跳；
- 超出范围通常使用“寄存器间接跳转”模板（常见 16B 或 20B）。

示意（远跳）：

```asm
LDR X17, [PC, #8]
BR  X17
.quad hook_addr
```



### Trampoline 不是“简单复制”

被覆盖指令若包含 `ADR/ADRP/LDR literal/B/BL/...`，直接复制会失效。
正确做法是：**按指令类型重定位**，保证在新地址执行时仍指向原目标。

### 32 位时代常见坑在 ARM64 的变化

- ARM32/Thumb 常见“bit0 表示 Thumb 状态”，ARM64 不存在该问题；
- 但 ARM64 对 PC-relative 指令使用更频繁，重定位工作量反而更集中在“偏移修复”。

## 5. 进阶注意点（可选展开）

以下内容偏工程化，入门阶段可以先略过：

- Hook 框架通常会处理更多边界（并发安装、递归保护、cache flush、回滚）；
- 自研实现建议先收敛 `arm64 + 最小指令集子集`，再扩展到复杂指令重定位。


# InlineHook基础流程（原理向）

基础可运行的 Inline Hook，可以压缩为 5 步：

1. 准备输入：拿到 `target_addr`、`hook_addr`，并确定入口覆盖长度 `hook_len`。
2. 构建 trampoline：备份目标入口指令，复制到 trampoline，末尾追加跳回 `target + hook_len`。
3. 刷新 trampoline 缓存：对 trampoline 写入区执行指令缓存刷新。
4. 改写目标入口：临时放开页写权限，写入跳到 hook 的指令，并刷新目标入口缓存。
5. 恢复与收尾：恢复页权限并返回结果；失败时回滚原始字节并释放 trampoline。


# InlineHook开发实践（Demo 验证）

## Demo 结构（按模块理解）

![Demo结构](/images/InlineHookDemo.png)

### App

> 加载目标 so 与 hook so，并触发待 Hook 函数调用。

```cmake
cmake_minimum_required(VERSION 3.10)
project("plthook_combined")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (${ANDROID_ABI} STREQUAL "arm64-v8a")
    add_definitions(-DARCH_ARM64)
elseif (${ANDROID_ABI} STREQUAL "armeabi-v7a")
    add_definitions(-DARCH_ARM32)
endif ()

# 生成 libcombined.so
add_library(combined SHARED combined.cpp)

# hook 库
add_library(plthook SHARED plthook.cpp)

# inlinehook 库
add_library(inlinehook SHARED inlinehook.cpp)

# 链接库
target_link_libraries(combined
        android
        log
        inlinehook)

target_link_libraries(plthook
        android
        log
        dl)

target_link_libraries(inlinehook
        android
        log
        dl)

```



### 目标SO

> 提供待 Hook 的 native 函数（建议 `noinline`，避免被编译器优化掉调用点）。

```c++
#include <jni.h>
#include <android/log.h>

#include <jni.h>
#include <android/log.h>
#include "inlinehook.h"

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "Inline_COMBINED", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "PLT_COMBINED", __VA_ARGS__)

// ----------------------------
// target_function（待 hook）
// ----------------------------
extern "C" __attribute__((noinline)) int target_function(int x) {
    LOGI("target_function called with %d", x);
    return x + 1;
}

// 保存原函数指针
static int (*orig_target_function)(int) = nullptr;

// ✅ 保存 hook 上下文，用于 unhook
static hook_context_t* g_hook_ctx = nullptr;

// Hook 函数
extern "C" __attribute__((noinline)) int hook_target_function(int x) {
    LOGI("hook_target_function called with %d (intercepted!)", x);
    // 调用原函数，修改参数或返回值
//  int result = orig_target_function(x);
    int result = x;
    LOGI("hook_target_function: original returned %d, we return %d", result, result * 100);
    return x * 100;  // 修改返回值
}

// ----------------------------
// callTarget 调用 target_function
// ----------------------------
extern "C" JNIEXPORT jint JNICALL
Java_com_example_plthookdemo_MainActivity_callTarget(JNIEnv* env, jobject thiz, jint v) {
    LOGI("callTarget: before calling target_function");
    int r = target_function((int)v);  // 通过 PLT 调用
    LOGI("callTarget: after calling target_function, result=%d", r);
    return r;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_plthookdemo_MainActivity_installHook(JNIEnv* env, jobject thiz) {
    LOGI("Installing inline hook...");
    g_hook_ctx = inline_hook((void*)target_function, (void*)hook_target_function, (void**)&orig_target_function);
    if(g_hook_ctx == nullptr){
        LOGI("inline_hook failed");
        return -1;
    }
    LOGI("inline_hook orig_target_function=%p", orig_target_function);
    return 0;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_plthookdemo_MainActivity_uninstallHook(JNIEnv *env, jobject thiz) {
    LOGI("Installing inline hook...");
    if (g_hook_ctx == nullptr) {
        LOGI("inline_unhook failed, g_hook_ctx is nullptr");
        return -1;
    }
    int ret = inline_unhook(g_hook_ctx);
    if (ret == 0) {
        g_hook_ctx = nullptr;
        orig_target_function = nullptr;
        LOGI("inline_unhook success");
    } else {
        LOGI("inline_unhook failed, ret=%d", ret);
    }
    return ret;
}
```

主要是提供 注册/卸载 hook的方法

### Hook SO

> 安装 Inline Hook，保存原函数地址，并在 Hook 函数里按需回调原函数。

```c++
//
// Created by 王晓勇 on 2025-10-14.
//

#include "inlinehook.h"

/**
 *  修改内存页保护属性
 */
static int change_page_protection(void *addr, size_t len, int prot) {
    size_t page_size = sysconf(_SC_PAGESIZE);
    // 计算页对齐地址
    void *page_addr = (void *)((uintptr_t)addr & ~(page_size - 1));
    size_t page_len = (((uintptr_t)addr + len - (uintptr_t)page_addr +
                        page_size - 1) / page_size) * page_size;

    // 修改保护属性
    return mprotect(page_addr, page_len, prot);
}

/**
* 刷新指令缓存
*/
static void cache_flush(void *addr, size_t len) {
#ifdef ARCH_ARM32
    __builtin___clear_cache((char *)addr, (char *)addr + len);
#elif defined(ARCH_ARM64)
    __builtin___clear_cache((char *)addr, (char *)addr + len);
#endif
}

/**
* 判断指令集模式
 *ARM64 只有一种指令集模式
 * A64指令集
 * ARM64 (AArch64) = A64 指令集（64位）
- 所有指令固定 32 位（4 字节）
- 没有 Thumb 模式
- 不需要模式切换
 *
// ARM 有两种主要指令集模式:

// 1. ARM 模式 (32位指令) - a32
// - 所有指令固定32位长度
// - 性能高但代码体积大

// 2. Thumb 模式 (16位指令) - t16 / t32
// - 指令16位或32位混合
// - Thumb-1只支持16位指令
// - Thumb-2扩展支持32位指令
// - 代码密度高
*/
static int is_thumb_mode(void *addr) {
    return ((uintptr_t)addr & 1) != 0;
}

#ifdef ARCH_ARM32
/**
 * ARM指令集跳转指令
 * @param dest
 * @param target
 */
static void build_arm_jump(void *dest, void *target) {
  uint32_t *code = (uint32_t *)dest;
  // 构造跳转指令序列:
  // LDR PC, [PC, #-4]   ; 加载地址到PC
  // .word target        ; 目标地址
  code[0] = 0xe51ff004; // ldr pc, [pc, #-4]
  code[1] = (uint32_t)(target);
}

/**
 * thumb指令集
 */
static void build_thumb_jump(void *dest, void *target) {
  uint16_t *code = (uint16_t *)dest;

  // ✅ 适用于任意对齐的地址
  // PUSH {R0}              ; 保存 R0
  // LDR R0, [PC, #4]       ; 加载目标
  // STR R0, [SP, #4]       ; 替换栈上的返回地址
  // POP {R0, PC}           ; 恢复 R0 并跳转

  code[0] = 0xB401;      // PUSH {R0}
  code[1] = 0x4801;      // LDR R0, [PC, #4]
  code[2] = 0x9001;      // STR R0, [SP, #4]
  code[3] = 0xBD01;      // POP {R0, PC}
  *((uint32_t *)&code[4]) = (uint32_t)target;
}

/**
 * thumb2指令集
 */
static void build_thumb2_jump(void *dest, void *target) {
  uint16_t *code = (uint16_t *)dest;
  // 构造跳转指令序列:
  // LDR.W PC, [PC]      ; Thumb-2指令
  // NOP                 ; 对齐
  // .word target        ; 目标地址

  code[0] = 0xF8DF;      // LDR.W PC, [PC]
  code[1] = 0xF000;      // 偏移为0
  code[2] = 0xBF00;      // NOP
  code[3] = 0xBF00;      // NOP
  *((uint32_t *)&code[4]) = (uint32_t)target;
}

#endif

#ifdef ARCH_ARM64
/**
 * 构建Arm64跳转指令
 * A64指令集
 */
static void build_arm64_jump(void *dest, void *target) {
  uint32_t *code = (uint32_t *)dest;

  // 构造跳转指令序列:
  // LDR X16, #8         ; 加载目标地址到X16
  // BR X16              ; 跳转到X16
  // .quad target        ; 64位目标地址

  code[0] = 0x58000050;  // LDR X16, #8
  code[1] = 0xD61F0200;  // BR X16
  *((uint64_t *)&code[2]) = (uint64_t)target;
}

static int arm64_hook_install(hook_context_t *ctx) {
  void *target = ctx->target_addr;
  void *hook = ctx->hook_addr;
  // 固定16字节
  ctx->hook_len = 16;

  //从 target读取数据，复制 hook_len长度 到 original_code 中，实际就是备份 target
  memcpy(ctx->original_code, target, ctx->hook_len);

  //分配 跳板内存
  ctx->trampoline_addr = mmap(NULL, 4096, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (ctx->trampoline_addr == MAP_FAILED) {
	return -1;
  }

  // 从 original_code 实际就是target读取数据到 trampoline_addr 中
  memcpy(ctx->trampoline_addr, ctx->original_code, ctx->hook_len);

  // 跳回原函数
  void *return_addr = (void *)((uintptr_t)target + ctx->hook_len);
  build_arm64_jump((char *)ctx->trampoline_addr + ctx->hook_len, return_addr);

  //Arm64缓存行大小通常为 64字节，可以保证覆盖完整
  cache_flush(ctx->trampoline_addr, 64);

  // 修改目标函数
  // 修改内存页保护属性 - 可写
  change_page_protection(target, ctx->hook_len, PROT_READ | PROT_WRITE | PROT_EXEC);
  build_arm64_jump(target, hook);
  // 刷新缓存
  cache_flush(target, 64);
  // 恢复内存页保护属性 - 只读
  change_page_protection(target, ctx->hook_len, PROT_READ | PROT_EXEC);

  return 0;
}
#endif

hook_context_t *inline_hook(void *target, void *hook, void **original) {
    hook_context_t *ctx = (hook_context_t *)malloc(sizeof(hook_context_t));
    if (!ctx) {
        return nullptr;
    }
    ctx->target_addr = target;
    ctx->hook_addr = hook;

#ifdef ARCH_ARM64
    if (arm64_hook_install(ctx) != 0) {
	free(ctx);
	return nullptr;
  }
#endif

    if (original) {
        *original = ctx->trampoline_addr;
    }
    return ctx;
}

int inline_unhook(hook_context_t *ctx) {
    if (!ctx) {
        return -1;
    }
    void *target = ctx->target_addr;

    change_page_protection(target, ctx->hook_len, PROT_READ | PROT_WRITE | PROT_EXEC);
    memcpy(target, ctx->original_code, ctx->hook_len);
    cache_flush(target, 64);
    change_page_protection(target, ctx->hook_len, PROT_READ | PROT_EXEC);

    if (ctx->trampoline_addr) {
        munmap(ctx->trampoline_addr, 4096);
    }
    free(ctx);
    return 0;
}
```

为了更容易看懂这份 Hook SO 代码，可以按“安装/卸载链路”拆成 5 个小节：

#### 1) 前置能力：改页权限 + 刷缓存

- `change_page_protection`：对目标地址做页对齐后调用 `mprotect`，解决代码段默认不可写的问题。
- `cache_flush`：写入新指令后刷新 I-Cache，避免 CPU 继续执行旧指令。

这两个函数是 Inline Hook 的基础设施，后面的 trampoline 写入和入口改写都会依赖它们。

#### 2) 跳转模板：`build_arm64_jump`

ARM64 分支里用的是“间接跳转”模板：

- `LDR X16, #8`
- `BR X16`
- 紧跟 8 字节目标地址（`.quad target`）

这样可以稳定跳到任意 64 位地址，不受近跳范围限制。

#### 3) 安装核心：`arm64_hook_install`

这个函数基本对应 Inline Hook 的主流程：

1. 固定 `hook_len = 16`（覆盖 4 条 A64 指令）。
2. 备份目标函数入口到 `original_code`。
3. `mmap` 一页 RXW 内存作为 trampoline。
4. 把备份指令写入 trampoline，并在末尾追加“跳回 `target + hook_len`”。
5. 刷新 trampoline 缓存。
6. 临时放开目标页写权限，把入口改写为“跳到 hook 函数”。
7. 刷新目标入口缓存并恢复页权限。

到这一步后，执行流进入 `target` 时会先进入 `hook`。

#### 4) 对外入口：`inline_hook`

- 分配并初始化 `hook_context_t`。
- 在 ARM64 下调用 `arm64_hook_install` 完成安装。
- 通过 `*original = ctx->trampoline_addr` 把“原函数可调用入口”返回给调用方。

也就是说，业务层保存的 `orig_target_function` 本质上是 trampoline 地址。

#### 5) 卸载回滚：`inline_unhook`

- 临时放开目标页写权限。
- 把 `original_code` 原样写回目标函数入口。
- 刷新缓存并恢复为 `RX`。
- 释放 trampoline（`munmap`）和上下文（`free`）。

这一步保证 Hook 可逆：安装后可恢复到未 Hook 状态。




## 最小调用链

`Java/Kotlin -> JNI wrapper -> target_func(入口已改写) -> hook_func -> (可选) trampoline/original -> target+N -> return`




# 要点总结

### 1. InlineHook功能简述

1. Inline Hook 改的是“函数入口指令”，PLT Hook 改的是“调用方 GOT 表项”，两者切入点不同。
2. Inline 的核心是：入口改写 + trampoline + 回跳 `target + N`。
3. 真正难点不是跳转，而是“被搬运指令的重定位”和“并发安装时机”。
4. 工程上必须处理页权限、I-Cache 刷新、回滚能力和线程安全。

### 2. 相关QA

**Q1：为什么要 trampoline？**

- 入口被覆盖后，原始前几条指令会丢失；trampoline 用来保留这些指令并回跳到 `target + hook_len`，保证“还能调用原函数”。

**Q2：为什么写完指令后必须 flush cache？**

- 因为 I-Cache / D-Cache 可能不一致，CPU 可能继续执行旧指令；刷新后才能保证新补丁生效。

**Q3：ARM64 下 `hook_len` 为什么常见是 16？**

- 常用远跳模板 `LDR + BR + .quad` 需要 16B，且 A64 固定 4B 指令，覆盖 16B 可保证按指令边界改写。

**Q4：为什么会崩溃？最常见原因是什么？**

- 覆盖半条指令、PC-relative 指令未重定位、页权限没放开/没恢复、并发线程命中 patch 窗口，都会导致 `SIGILL/SIGSEGV`。

**Q5：Inline Hook 一定比 PLT Hook 强吗？**

- 覆盖范围通常更大，但风险和复杂度也更高；若目标调用可被 PLT 命中，PLT Hook 往往更稳、更易维护。

