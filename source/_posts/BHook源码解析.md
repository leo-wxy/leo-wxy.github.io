---
title: BHook源码解析
typora-root-url: ../
date: 2025-10-02 09:18:44
tags: 源码解析
top: 10
---

# BHook源码解析



> 基于 ByteHook 1.1.1（main 分支实现思路）分析，侧重 Android Native Hook 的基础原理与核心源码链路。



## ByteHook

ByteHook（也常写作 BHook）是字节开源的 Android PLT Hook 框架。

它提供三类 Hook 能力：

- `bytehook_hook_single`：只 Hook 指定 caller so。
- `bytehook_hook_partial`：按过滤器 Hook 部分 caller so。
- `bytehook_hook_all`：Hook 全部 caller so。

并支持：

- 自动对新加载 so 补 Hook。
- 多个 Hook/Unhook 互不冲突（automatic 模式）。
- 递归/环形调用保护。
- 记录 Hook 操作日志（records）。



## ByteHook使用示例

https://github.com/bytedance/bhook/blob/main/doc/quickstart.zh-CN.md



## 主要源码分析

主要是从 init 到修改GOT的顺序看核心链路

### 初始化入口(bytehook_init)

> 负责运行时的基础设置

```c++
// bytehook/src/main/cpp/bytehook.c
int bytehook_init(int mode, bool debug) {
#define GOTO_END(errnum)          \
  do {                            \
    bytehook_init_errno = errnum; \
    goto end;                     \
  } while (0)

  bool do_init = false;
  if (__predict_true(BYTEHOOK_STATUS_CODE_UNINIT == bytehook_init_errno)) {
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&lock);
    if (__predict_true(BYTEHOOK_STATUS_CODE_UNINIT == bytehook_init_errno)) {
      do_init = true;
      bh_log_set_debug(debug);
      if (__predict_false(BYTEHOOK_MODE_AUTOMATIC != mode && BYTEHOOK_MODE_MANUAL != mode))
        GOTO_END(BYTEHOOK_STATUS_CODE_INITERR_INVALID_ARG);
      bytehook_mode = mode;
      if (__predict_false(0 != bh_linker_init())) GOTO_END(BYTEHOOK_STATUS_CODE_INITERR_SYM);
      if (__predict_false(0 != bytesig_init(SIGSEGV))) GOTO_END(BYTEHOOK_STATUS_CODE_INITERR_SIG);
      if (__predict_false(0 != bytesig_init(SIGBUS))) GOTO_END(BYTEHOOK_STATUS_CODE_INITERR_SIG);
      if (__predict_false(0 != bh_cfi_disable_slowpath())) GOTO_END(BYTEHOOK_STATUS_CODE_INITERR_CFI);
      if (__predict_false(0 != bh_safe_init())) GOTO_END(BYTEHOOK_STATUS_CODE_INITERR_SAFE);
      if (BYTEHOOK_IS_AUTOMATIC_MODE) {
        if (__predict_false(0 != bh_hub_init())) GOTO_END(BYTEHOOK_STATUS_CODE_INITERR_HUB);
      }

#undef GOTO_END

      bytehook_init_errno = BYTEHOOK_STATUS_CODE_OK;
    }
  end:
    pthread_mutex_unlock(&lock);
  }

  BH_LOG_ALWAYS_SHOW("%s: bytehook init(mode: %s, debuggable: %s), return: %d, real-init: %s",
                     bytehook_get_version(), BYTEHOOK_MODE_AUTOMATIC == mode ? "AUTOMATIC" : "MANUAL",
                     debug ? "true" : "false", bytehook_init_errno, do_init ? "yes" : "no");
  return bytehook_init_errno;
}
```

主要做了以下事情：

- 初始化linker适配层 - bh_linker_init
- 初始化signal保护 - bytesig_init (SIGSEGV / SIGBUS)
- 处理 cfi 兼容 - bh_cfi_disable_slowpath
- 初始化 hub 和 trampoline - bh_hub_init



### 注册Hook请求(bytehook_hook_*)

> 业务可以调用的hook api

```c++
bytehook_stub_t bytehook_hook_single(const char *caller_path_name, const char *callee_path_name,
                                     const char *sym_name, void *new_func, bytehook_hooked_t hooked,
                                     void *hooked_arg) {
  const void *caller_addr = __builtin_return_address(0);
  if (NULL == caller_path_name || NULL == sym_name || NULL == new_func) return NULL;
  if (BYTEHOOK_STATUS_CODE_OK != bytehook_init_errno) return NULL;

  bh_task_t *task = bh_task_create_single(caller_path_name, callee_path_name, sym_name, new_func, hooked,
                                          hooked_arg, false);
  if (NULL != task) {
    bh_task_manager_add(task);
    bh_task_manager_hook(task);
    bh_recorder_add_hook(task->status_code, caller_path_name, sym_name, (uintptr_t)new_func, (uintptr_t)task,
                         (uintptr_t)caller_addr);
  }
  return (bytehook_stub_t)task;
}

bytehook_stub_t bytehook_hook_partial(bytehook_caller_allow_filter_t caller_allow_filter,
                                      void *caller_allow_filter_arg, const char *callee_path_name,
                                      const char *sym_name, void *new_func, bytehook_hooked_t hooked,
                                      void *hooked_arg) {
  const void *caller_addr = __builtin_return_address(0);
  if (NULL == caller_allow_filter || NULL == sym_name || NULL == new_func) return NULL;
  if (BYTEHOOK_STATUS_CODE_OK != bytehook_init_errno) return NULL;

  bh_task_t *task = bh_task_create_partial(caller_allow_filter, caller_allow_filter_arg, callee_path_name,
                                           sym_name, new_func, hooked, hooked_arg, false);
  if (NULL != task) {
    bh_task_manager_add(task);
    bh_task_manager_hook(task);
    bh_recorder_add_hook(BYTEHOOK_STATUS_CODE_MAX, "PARTIAL", sym_name, (uintptr_t)new_func, (uintptr_t)task,
                         (uintptr_t)caller_addr);
  }
  return (bytehook_stub_t)task;
}

bytehook_stub_t bytehook_hook_all(const char *callee_path_name, const char *sym_name, void *new_func,
                                  bytehook_hooked_t hooked, void *hooked_arg) {
  const void *caller_addr = __builtin_return_address(0);
  if (NULL == sym_name || NULL == new_func) return NULL;
  if (BYTEHOOK_STATUS_CODE_OK != bytehook_init_errno) return NULL;

  bh_task_t *task = bh_task_create_all(callee_path_name, sym_name, new_func, hooked, hooked_arg, false);
  if (NULL != task) {
    bh_task_manager_add(task);
    bh_task_manager_hook(task);
    bh_recorder_add_hook(BYTEHOOK_STATUS_CODE_MAX, "ALL", sym_name, (uintptr_t)new_func, (uintptr_t)task,
                         (uintptr_t)caller_addr);
  }
  return (bytehook_stub_t)task;
}
```

#### hook单个调用者(bytehook_hook_single)

- 在已加载的所有 ELF 中寻找目标调用者。如果找到，则执行 hook task，然后将 task 标记为已完成，最后执行 hooked 回调通知外部。
- 如果未找到调用者，则将 task 标记为未完成。
- 未来某一时刻，目标调用者被加载到内存中，此时 ByteHook 会自动对它执行 hook task，然后将 task 标记为已完成，最后执行 hooked 回调通知外部。

#### hook部分调用者(bytehook_hook_partial)

- 此类任务永远处于未完成状态。
- 在已加载的所有 ELF 中使用 `caller_allow_filter` 过滤函数进行匹配，对匹配成功的调用者们，逐个执行 hook task，同时逐个执行 hooked 回调通知外部。
- 未来有任何新的 ELF 被加载到内存时，ByteHook 都会自动的用 `caller_allow_filter` 过滤函数去尝试匹配，一旦匹配成功，就会对它执行 hook task，再执行 hooked 回调通知外部。

#### hook全部调用者(bytehook_hook_all)

- 和 hook 部分调用者（`bytehook_hook_partial()`）的情况类似，区别仅在于不需要过滤函数了，而是“来者不拒”的对“所有已加载的 ELF”和“未来加载的 ELF”都执行 hook task，以及 hooked 回调。



上述方法的核心对象是 `bh_task_t`。表示一个Hook请求

```c++
// bytehook/src/main/cpp/bh_task.h
typedef struct bh_task {
  bh_task_type_t type;
  bh_task_status_t status;
  int status_code;  // for recorder, single type only
  bool is_invisible;

  // caller
  char *caller_path_name;                              // for single
  uintptr_t caller_load_bias;                          // for single
  bytehook_caller_allow_filter_t caller_allow_filter;  // for partial
  void *caller_allow_filter_arg;                       // for partial

  // callee
  char *callee_path_name;
  void *callee_addr;

  // symbol
  char *sym_name;

  // new function address
  void *new_func;

  // callback
  bytehook_hooked_t hooked;
  void *hooked_arg;

  TAILQ_ENTRY(bh_task, ) link;
} bh_task_t;
```

主要是下面几个参数：

- sym_name：目标符号
- new_func：新函数地址
- caller / callee ：限定条件
- 状态与回调信息



### Task管理与调度(bh_task_mamager)

> 主要有以下两个任务：
>
> - 对当前进程中已加载的 ELF 执行 Task
> - 后续新加载的ELF，补充执行Task

```c++
// bytehook/src/main/cpp/bh_task_manager.c

void bh_task_manager_add(bh_task_t *task) {
  pthread_rwlock_wrlock(&bh_tasks_lock);
  TAILQ_INSERT_TAIL(&bh_tasks, task, link);
  pthread_rwlock_unlock(&bh_tasks_lock);
}

void bh_task_manager_hook(bh_task_t *task) {
  ...

#if BH_LINKER_MAYBE_NOT_SUPPORT_DL_INIT_FINI_MONITOR
  bh_dl_monitor_dlclose_rdlock();
#endif
  bh_task_hook(task);
#if BH_LINKER_MAYBE_NOT_SUPPORT_DL_INIT_FINI_MONITOR
  bh_dl_monitor_dlclose_unlock();
#endif
}
```

### ELF缓存管理(bh_elf_manager)

> 维护进程内的ELF列表，支持增删与生命周期同步

- bh_elf_manager_load：初次加载缓存
- bh_elf_manager_refresh：刷新所有ELF
- bh_elf_manager_add / bh_elf_manager_del：增加/删除缓存

- bh_elf_manager_find_elf：从维护的 ELF缓存里，按照so名称/路径返回一个可用的ELF对象

```c++
// bytehook/src/main/cpp/bh_task.c

static void bh_task_handle(bh_task_t *self) {
  switch (self->type) {
    case BH_TASK_TYPE_SINGLE: {
      bh_elf_t *caller_elf = bh_elf_manager_find_elf(self->caller_path_name);
      if (NULL != caller_elf) {
        bh_task_hook_or_unhook(self, caller_elf);
        bh_elf_decrement_ref_count(caller_elf);
      }
      break;
    }
    case BH_TASK_TYPE_ALL:
    case BH_TASK_TYPE_PARTIAL:
      bh_elf_manager_iterate(bh_task_elf_iterate_cb, (void *)self);
      break;
  }
}

// bytehook/src/main/cpp/bh_elf_manager.c
bh_elf_t *bh_elf_manager_find_elf(const char *pathname) {
  bh_elf_t *elf = NULL;

  pthread_rwlock_rdlock(&bh_elfs_lock);
  TAILQ_FOREACH(elf, &bh_elfs, link_list) {
    if (0 == elf->abandoned_ts && !elf->error && bh_elf_is_match(elf, pathname)) break;
  }
  if (NULL != elf) bh_elf_increment_ref_count(elf);
  pthread_rwlock_unlock(&bh_elfs_lock);

  return elf;
}
```

### ELF信息(bh_elf)

> 主要是两件事情：
>
> - ELF动态信息解析
> - 符号定位与GOT表收集

```c++
// bytehook/src/main/cpp/bh_elf.c
static void bh_elf_parse_dynamic_unsafe(bh_elf_t *self, ElfW(Dyn) *dynamic) {
  // 解析 .dynamic
case DT_JMPREL: self->rel_plt = ...;
case DT_PLTRELSZ: self->rel_plt_cnt = ...;
case DT_REL/DT_RELA: self->rel_dyn = ...;
case DT_RELSZ/DT_RELASZ: self->rel_dyn_cnt = ...;
case DT_SYMTAB: self->dynsym = ...;
case DT_STRTAB: self->dynstr = ...;
case DT_HASH/DT_GNU_HASH: ...
}
```

主要是处理 如下字段

- .rel.plt / .rela.plt
- .rel.dyn / .rela.dyn
- .dynsym
- .dynstr
- .rel.dyn / .rela.dyn (APS2 format) - Android对重定位表做的‘私有压缩格式’，主要为了减少so体积

```c++
// bytehook/src/main/cpp/bh_elf.c

ElfW(Sym) *bh_elf_find_symbol_and_gots_by_symbol_name(bh_elf_t *self, const char *sym_name, void *callee_addr,
                                                      bh_array_t *gots, bh_array_t *prots) {
  if (self->error) return NULL;
  if (0 != bh_elf_parse_dynamic(self)) return NULL;

  ElfW(Sym) *sym = NULL;

  BH_SIG_TRY(SIGSEGV, SIGBUS) {
    sym = bh_elf_find_symbol_and_gots_by_symbol_name_unsafe(self, sym_name, callee_addr, gots, prots);
  }
  BH_SIG_CATCH() {
    self->error = true;
    sym = NULL;
  }
  BH_SIG_EXIT

  return sym;
}

static ElfW(Sym) *bh_elf_find_symbol_and_gots_by_symbol_name_unsafe(bh_elf_t *self, const char *sym_name,
                                                                    void *callee_addr, bh_array_t *gots,
                                                                    bh_array_t *prots) {
  ElfW(Sym) *sym = NULL;

  // From: SYSV hash (.hash -> .dynsym -> .dynstr), O(x) + O(1) + O(1)
  // Notice: If ELF is linked as "-Wl,--hash-style=gnu", there will be no .hash section.
  //         The SYSV hash contains both imported and exported symbols.
  if (self->sysv_hash.buckets_cnt > 0) sym = bh_elf_find_symbol_by_name_use_sysv_hash(self, sym_name);

  // From: GNU hash (.gnu.hash -> .dynsym -> .dynstr), O(x) + O(1) + O(1)
  // Notice: If ELF is linked as "-Wl,--hash-style=sysv", there will be no .gnu.hash section.
  //         The GNU hash only contains exported symbols.
  if (NULL == sym && self->gnu_hash.buckets_cnt > 0)
    sym = bh_elf_find_symbol_by_name_use_gnu_hash(self, sym_name);

  // If we have already found "sym" at this moment, then we do not need to use "strcmp()" to
  // compare "sym_name" in the following linear search, and the following search will be faster.

  // linear Search sym and GOTS in .rel.plt
  for (size_t i = 0; i < self->rel_plt_cnt; i++)
    if (0 != bh_elf_check_reloc(self, &(self->rel_plt[i]), sym_name, callee_addr, gots, prots, &sym, true))
      return NULL;

  // linear Search sym and GOTS in .rel.dyn
  for (size_t i = 0; i < self->rel_dyn_cnt; i++)
    if (0 != bh_elf_check_reloc(self, &(self->rel_dyn[i]), sym_name, callee_addr, gots, prots, &sym, false))
      return NULL;

  // linear Search sym and GOTS in .rel.dyn (APS2 format)
  uintptr_t pkg[6] = {(uintptr_t)self, (uintptr_t)sym_name, (uintptr_t)callee_addr,
                      (uintptr_t)gots, (uintptr_t)prots,    (uintptr_t)&sym};
  if (NULL != self->rel_dyn_aps2) {
    bh_sleb128_decoder_t decoder;
    bh_sleb128_decoder_init(&decoder, self->rel_dyn_aps2, self->rel_dyn_aps2_sz);
    bh_elf_iterate_aps2(&decoder, bh_elf_find_got_by_sym_unsafe_aps2_cb, pkg);
  }

  return sym;
}
```

执行以下逻辑：

- 用 SYSV / GNU hash 定位符号
- 线性扫描重定位项，筛选对应符号
- 收集所有要改写的地址 (GOT)和页保护属性



### 改写地址(bh_elf_relocator)

> 在这里进行最终的替换逻辑

```c++
// bytehook/src/main/cpp/bh_elf_relocator.c
int bh_elf_relocator_reloc(bh_elf_t *elf, bh_task_t *task, bh_array_t *gots, bh_array_t *prots,
                           uintptr_t new_addr, uintptr_t *orig_addr) {
  // get original address
  uintptr_t real_orig_addr = 0;
  BH_SIG_TRY(SIGSEGV, SIGBUS) {
    real_orig_addr = (uintptr_t)(*((void **)gots->data[0]));
  }
  BH_SIG_CATCH() {
    return BYTEHOOK_STATUS_CODE_READ_ELF;
  }
  BH_SIG_EXIT

  if (NULL != orig_addr) *orig_addr = real_orig_addr;

  // do callback with BYTEHOOK_STATUS_CODE_ORIG_ADDR for manual-mode
  //
  // In manual mode, the caller needs to save the original function address
  // in the hooked callback, and then may call the original function through
  // this address in the proxy function. So we need to execute the hooked callback
  // first, and then execute the address replacement in the GOT, otherwise it
  // will cause a crash due to timing issues.
  bh_task_do_orig_func_callback(task, elf->pathname, (void *)real_orig_addr);

  for (size_t i = 0; i < gots->count; i++) {
    void *got = (void *)gots->data[i];
    int prot = (int)prots->data[i];

    // add write permission
    if (0 == (prot & PROT_WRITE)) {
      if (0 != bh_util_set_addr_protect(got, prot | PROT_WRITE)) return BYTEHOOK_STATUS_CODE_SET_PROT;
    }

    // replace the target function address by "new_func"
    BH_SIG_TRY(SIGSEGV, SIGBUS) {
      __atomic_store_n((uintptr_t *)got, (uintptr_t)new_addr, __ATOMIC_SEQ_CST);
    }
    BH_SIG_CATCH() {
      return BYTEHOOK_STATUS_CODE_SET_GOT;
    }
    BH_SIG_EXIT

    // delete write permission
    //    if (0 == (prot & PROT_WRITE)) bh_util_set_addr_protect(got, prot);
  }

  return BYTEHOOK_STATUS_CODE_OK;
}

```

主要执行了以下几步：

- 读取原地址：real_orig_addr
- mprotect 设置写权限：bh_util_set_addr_protect(got, prot | PROT_WRITE)
- 写入新地址：__atomic_store_n



### 模式切换(bh_switch)

> 支持两种模式切换：
>
> - manual
> - automatic

```c++
// bytehook/src/main/cpp/bh_switch.c

int bh_switch_hook(bh_elf_t *elf, bh_task_t *task, ElfW(Sym) *sym, bh_array_t *gots, bh_array_t *prots,
                   uintptr_t new_addr, uintptr_t *orig_addr) {
  int r;
  if (BYTEHOOK_IS_MANUAL_MODE)
    r = bh_switch_hook_unique(elf, task, sym, gots, prots, new_addr, orig_addr);
  else
    r = bh_switch_hook_shared(elf, task, sym, gots, prots, new_addr, orig_addr);

  if (0 == r)
    BH_LOG_INFO("switch: hook in %s mode OK: sym %" PRIxPTR ", new_addr %" PRIxPTR ", orig_addr %" PRIxPTR,
                BYTEHOOK_IS_MANUAL_MODE ? "MANUAL" : "AUTOMATIC", (uintptr_t)sym, new_addr, *orig_addr);

  return r;
}

static int bh_switch_hook_unique(bh_elf_t *elf, bh_task_t *task, ElfW(Sym) *sym, bh_array_t *gots,
                                 bh_array_t *prots, uintptr_t new_addr, uintptr_t *orig_addr) {
 ...
     if (0 != (r = bh_elf_relocator_reloc(elf, task, gots, prots, new_addr, &self->orig_addr))) {
    TAILQ_REMOVE(&mgr->switches, self, link);
    useless = self;
    goto end;
  }
}


static int bh_switch_hook_shared(bh_elf_t *elf, bh_task_t *task, ElfW(Sym) *sym, bh_array_t *gots,
                                 bh_array_t *prots, uintptr_t new_addr, uintptr_t *orig_addr) {
  ...
        // do reloc & return original-address
    if (0 != (r = bh_elf_relocator_reloc(elf, task, gots, prots, hub_trampo,
                                         bh_hub_get_orig_addr_addr(self->hub)))) {
      TAILQ_REMOVE(&mgr->switches, self, link);
      useless = self;
      goto end;
    }
    self->orig_addr = bh_hub_get_orig_addr(self->hub);
    *orig_addr = self->orig_addr;
}
```

manual模式执行 `bh_switch_hook_unique`，GOT表直接写`new_func`

automatic模式执行`bh_switch_hook_shared`，GOT表写入`hub_trampo`

#### automatic模式下的参数(bh_hub)

> 负责 automatic 模式下运行时参数分发

- bh_hub_push_stack
- bh_hub_add_proxy
- bh_hub_get_prev_func
- bh_hub_pop_stack

这套机制主要是为了解决如下问题：

- 多proxy链式执行
- 避免调用形成递归



### SO加载监控(bh_dl_monitor)



# 参考地址

[ByteHook 仓库](https://github.com/bytedance/bhook)

[项目介绍和原理概述](https://github.com/bytedance/bhook/blob/main/doc/overview.zh-CN.md)

[Android bionic linker 源码](https://cs.android.com/android/platform/superproject/main/+/main:bionic/linker/)
