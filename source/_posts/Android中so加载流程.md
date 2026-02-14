---
title: Android中so加载流程
typora-root-url: ../
date: 2025-10-06 13:22:44
tags: Android
top: 10
---

在 `{% post_link Android中的Hook-PLTHook %}` 和 `{% post_link Android中的Hook-InlineHook %}` 里，Hook 的生效点分别在 GOT 表项和函数入口。
要真正理解 Hook 的时机、边界和稳定性，必须先搞清楚 SO 是怎么被系统加载起来的。

# SO 加载流程总览

一句话先记住：**Java 层发起加载 -> ART/NativeLoader 处理 ClassLoader 与 namespace -> linker 映射 + 重定位 -> 执行构造函数 -> 调用 JNI_OnLoad。**

典型调用链如下：

```text
System.loadLibrary("demo")
  -> Runtime.loadLibrary0(...)
  -> Runtime.nativeLoad(...)
  -> JVM_NativeLoad(...)
  -> JavaVMExt::LoadNativeLibrary(...)
  -> OpenNativeLibrary(...)
  -> android_dlopen_ext(...)
  -> linker: do_dlopen(...)
      -> find_libraries
      -> mmap PT_LOAD
      -> prelink_image
      -> link_image (relocate)
      -> call_constructors
  -> dlsym("JNI_OnLoad")
  -> JNI_OnLoad(JavaVM*, ...)
```



# 1. Java 层入口：System.loadLibrary

平时最常见的是：

```kotlin
System.loadLibrary("demo")
```

它会先把名字补全为标准库名（例如 `libdemo.so`），再进入 native 流程。

这里有两个容易混淆的方法：

- `System.loadLibrary("demo")`：参数为 so 库名称。系统会按 ClassLoader/namespace 的搜索路径定位 so；常见情况下来自应用 native lib 目录，`android:extractNativeLibs="false"` 且 APK 中 so 满足对齐要求时也可直接从 APK 映射加载。
- `System.load("/data/.../libdemo.so")`：参数为 so 库在磁盘中的完整路径，可以加载自定义外部 so 库文件。

还有使用第三方库 [ReLinker](https://github.com/KeepSafe/ReLinker)，有so加载成功、失败的回调，安全加载不崩溃。**推荐使用**

绝大多数场景都用 `loadLibrary`。



# 2. ART 与 NativeLoader：处理 ClassLoader 和 namespace

`Runtime.nativeLoad` 之后，会进入 ART 的 `JavaVMExt::LoadNativeLibrary`。

这一步不是简单地 `dlopen` 一下，而是会做几件关键的“安全与隔离”工作：

1. 记录并检查“库 - ClassLoader”关系，避免同一 so 被不同 ClassLoader 非法复用。
2. 基于 ClassLoader 找到对应 linker namespace（Android N 以后非常关键）。
3. 调用 `OpenNativeLibrary`，最终走到 `android_dlopen_ext`。

可以把它理解成：**ART 负责 Java 语义与隔离策略，linker 负责 ELF 技术细节。**

```c++
// https://cs.android.com/android/platform/superproject/main/+/main:art/runtime/jni/java_vm_ext.cc
bool JavaVMExt::LoadNativeLibrary(JNIEnv* env,
                                  const std::string& path,
                                  jobject class_loader,
                                  jclass caller_class,
                                  std::string* error_msg) {
                                  
  ...
  void* handle = android::OpenNativeLibrary(
      env,
      runtime_->GetTargetSdkVersion(),
      path_str,
      class_loader,
      (caller_location.empty() ? nullptr : caller_location.c_str()),
      library_path.get(),
      &needs_native_bridge,
      &nativeloader_error_msg);
  VLOG(jni) << "[Call to dlopen(\"" << path << "\", RTLD_NOW) returned " << handle << "]";

  if (handle == nullptr) {
    *error_msg = nativeloader_error_msg;
    android::NativeLoaderFreeErrorMessage(nativeloader_error_msg);
    VLOG(jni) << "dlopen(\"" << path << "\", RTLD_NOW) failed: " << *error_msg;
    return false;
  }
  ...                                  
}
```

```c++
// https://cs.android.com/android/platform/superproject/main/+/main:system/core/libnativeloader/native_loader.cpp
void* OpenNativeLibrary(JNIEnv* env,
                        int32_t target_sdk_version,
                        const char* path,
                        jobject class_loader,
                        const char* caller_location,
                        jstring library_path_j,
                        bool* needs_native_bridge,
                        char** error_msg) {
  ...
  if (caller_location != nullptr) {
      std::optional<NativeLoaderNamespace> ns = FindApexNamespace(caller_location);
      if (ns.has_value()) {
        const android_dlextinfo dlextinfo = {
            .flags = ANDROID_DLEXT_USE_NAMESPACE,
            .library_namespace = ns.value().ToRawAndroidNamespace(),
        };
        void* handle = android_dlopen_ext(path, RTLD_NOW, &dlextinfo);
        char* dlerror_msg = handle == nullptr ? strdup(dlerror()) : nullptr;
        ALOGD("Load %s using APEX ns %s for caller %s: %s",
              path,
              ns.value().name().c_str(),
              caller_location,
              dlerror_msg == nullptr ? "ok" : dlerror_msg);
        if (dlerror_msg != nullptr) {
          *error_msg = dlerror_msg;
        }
        return handle;
      }
    }
  ...
}
```



## 2.1 重复加载与 ClassLoader 行为（dlclose 边界）

在 Java 层，so 加载不仅取决于路径，还受到 ClassLoader 的约束。实战里可以先记下面这张 2x2 表：

| 场景 | 结果（常见） |
| :-- | :-- |
| 同一路径 + 同一 ClassLoader | 复用已加载 so，不重复初始化 |
| 同一路径 + 不同 ClassLoader | 常见报错：已被其他 ClassLoader 加载 |
| 不同路径 + 同一 ClassLoader | 可能复用也可能分别加载，取决于 realpath 与 namespace |
| 不同路径 + 不同 ClassLoader | 可能隔离加载，但仍受 namespace 可见性限制 |

补充两点：

- C/C++ 层 `dlopen/dlclose` 是引用计数模型；`dlclose` 计数归零才可能卸载。
- Java 业务代码通常不直接控制卸载，实践上一般按“进程常驻 so”去设计初始化与资源管理。



### dlclose 何时会被调用（小点）

- 主动调用：Native 代码显式执行 `dlclose(handle)`。
- 异常回滚：某些 `dlopen/android_dlopen_ext` 失败路径会触发内部清理。
- Java 场景：`System.loadLibrary` 没有公开 unload API，业务侧通常不会主动触发 `dlclose`。
- 关键区别：调用了 `dlclose` 不等于立刻卸载，只有引用计数归零且无依赖占用时才可能真正卸载。



## 2.2 android_dlopen_ext 参数速查

`android_dlopen_ext` 在 `dlopen` 基础上增加了 `android_dlextinfo`，用于 namespace、fd 加载、预留地址等高级能力。

| flag | 作用 | 常见场景 | 注意点 |
| :-- | :-- | :-- | :-- |
| `ANDROID_DLEXT_USE_NAMESPACE` | 指定 linker namespace | ClassLoader/APEX 隔离加载 | namespace 不可见会直接失败 |
| `ANDROID_DLEXT_USE_LIBRARY_FD` | 从已打开 fd 加载 so | 自定义容器或特殊打包 | 需保证 fd 指向合法 ELF |
| `ANDROID_DLEXT_USE_LIBRARY_FD_OFFSET` | 从 fd 指定偏移加载 | APK 内偏移映射 | offset 错误会导致 ELF 解析失败 |
| `ANDROID_DLEXT_RESERVED_ADDRESS` / `ANDROID_DLEXT_RESERVED_ADDRESS_HINT` | 指定映射地址范围 | 大库预留地址场景 | 地址冲突时可能回退或失败 |
| `ANDROID_DLEXT_FORCE_LOAD` | 强制执行加载路径 | 调试/特殊兼容场景 | 易引入重复映射风险，不建议业务滥用 |



# 3. linker：真正把 so 装入内存

从 `android_dlopen_ext` 开始，流程进入 bionic linker（核心函数通常是 `do_dlopen`）。

```c++
// https://cs.android.com/android/platform/superproject/main/+/main:bionic/linker/dlfcn.cpp

static void* dlopen_ext(const char* filename,
                        int flags,
                        const android_dlextinfo* extinfo,
                        const void* caller_addr) {
  ScopedPthreadMutexLocker locker(&g_dl_mutex);
  g_linker_logger.ResetState();
  void* result = do_dlopen(filename, flags, extinfo, caller_addr);
  if (result == nullptr) {
    __bionic_format_dlerror("dlopen failed", linker_get_error_buffer());
    return nullptr;
  }
  return result;
}

void* __loader_android_dlopen_ext(const char* filename,
                           int flags,
                           const android_dlextinfo* extinfo,
                           const void* caller_addr) {
  return dlopen_ext(filename, flags, extinfo, caller_addr);
}
```

```c++
// https://cs.android.com/android/platform/superproject/main/+/main:bionic/linker/linker.cpp
void* do_dlopen(const char* name, int flags,
                const android_dlextinfo* extinfo,
                const void* caller_addr) {
                
  ...
  // 去找已经加载过的SO
  const char* translated_name = name;
  if (g_is_asan && translated_name != nullptr && translated_name[0] == '/') {
    char original_path[PATH_MAX];
    if (realpath(name, original_path) != nullptr) {
      translated_name_holder = std::string(kAsanLibDirPrefix) + original_path;
      if (file_exists(translated_name_holder.c_str())) {
        soinfo* si = nullptr;
        if (find_loaded_library_by_realpath(ns, original_path, true, &si)) {
          DL_WARN("linker_asan dlopen NOT translating \"%s\" -> \"%s\": library already loaded", name,
                  translated_name_holder.c_str());
        } else {
          DL_WARN("linker_asan dlopen translating \"%s\" -> \"%s\"", name, translated_name);
          translated_name = translated_name_holder.c_str();
        }
      }
    }
  } else if (g_is_hwasan && translated_name != nullptr && translated_name[0] == '/') {
    char original_path[PATH_MAX];
    if (realpath(name, original_path) != nullptr) {
      // Keep this the same as CreateHwasanPath in system/linkerconfig/modules/namespace.cc.
      std::string path(original_path);
      auto slash = path.rfind('/');
      if (slash != std::string::npos || slash != path.size() - 1) {
        translated_name_holder = path.substr(0, slash) + "/hwasan" + path.substr(slash);
      }
      if (!translated_name_holder.empty() && file_exists(translated_name_holder.c_str())) {
        soinfo* si = nullptr;
        if (find_loaded_library_by_realpath(ns, original_path, true, &si)) {
          DL_WARN("linker_hwasan dlopen NOT translating \"%s\" -> \"%s\": library already loaded",
                  name, translated_name_holder.c_str());
        } else {
          DL_WARN("linker_hwasan dlopen translating \"%s\" -> \"%s\"", name, translated_name);
          translated_name = translated_name_holder.c_str();
        }
      }
    }
  }

  // 省略其他校验与命名空间处理后，真正进入 so 查找与加载
  soinfo* si = find_library(ns, translated_name, flags, extinfo, caller);
  if (si != nullptr) {
    si->call_constructors();
    return si->to_handle();
  }

  ...
   
             
}

bool find_libraries(android_namespace_t* ns,
                    soinfo* start_with,
                    const char* const library_names[],
                    size_t library_names_count,
                    soinfo* soinfos[],
                    std::vector<soinfo*>* ld_preloads,
                    size_t ld_preloads_count,
                    int rtld_flags,
                    const android_dlextinfo* extinfo,
                    bool add_as_children,
                    std::vector<android_namespace_t*>* namespaces) {
  // load so
}
```



## 3.1 查找目标库和依赖库

linker 会先定位目标 so，并递归解析 `DT_NEEDED` 依赖列表。

- 找不到库：直接 `dlopen failed: library "xxx.so" not found`
- 能找到但架构不匹配：常见 `wrong ELF class`

## 3.2 映射 ELF 到内存（mmap）

linker 会按 ELF 的 Program Header（尤其 `PT_LOAD`）把各个段映射到内存。

- 代码段通常是 `R-X`
- 数据段通常是 `RW-`
- 后续可能根据 `RELRO` 再调整为只读

到这一步，so 已经“在内存里”，但符号地址还不一定都可直接用。

## 3.3 prelink_image：解析 .dynamic

这一步会读取 `PT_DYNAMIC` / `.dynamic`，拿到后续链接要用的关键索引信息，例如：

- `DT_STRTAB` / `DT_SYMTAB`（字符串表、符号表）
- `DT_RELA` / `DT_REL` / `DT_RELR`（重定位表）
- `DT_JMPREL`（PLT 相关重定位）
- `DT_INIT_ARRAY`（构造函数数组）

## 3.4 link_image：执行重定位（核心）

这一步是 so 加载最关键的环节：

- 解析导入符号
- 在依赖库中做符号查找
- 把目标绝对地址写回 GOT / DATA 等位置

重定位完成后，代码里的外部调用才真正“指向正确地址”。

## 3.5 调用构造函数

当链接完成后，linker 会执行：

- `DT_INIT`（若存在）
- `.init_array`（常见）

并且通常会先保证依赖库构造函数先执行，再执行当前库构造函数。



# 4. JNI_OnLoad 的执行时机

很多人会把 `JNI_OnLoad` 和构造函数混在一起，实际顺序通常是：

1. linker 完成加载、重定位、构造函数调用。
2. 返回到 ART 的 `JavaVMExt::LoadNativeLibrary`。
3. ART 通过 `dlsym` 查找 `JNI_OnLoad` 并调用。

也就是说：**`JNI_OnLoad` 发生在 `dlopen` 成功返回之后。**

对应实现代码

```c++
// https://cs.android.com/android/platform/superproject/main/+/main:art/runtime/jni/java_vm_ext.cc
bool JavaVMExt::LoadNativeLibrary(JNIEnv* env,
                                  const std::string& path,
                                  jobject class_loader,
                                  jclass caller_class,
                                  std::string* error_msg) {
  ...
    // load so
  void* handle = android::OpenNativeLibrary(
      env,
      runtime_->GetTargetSdkVersion(),
      path_str,
      class_loader,
      (caller_location.empty() ? nullptr : caller_location.c_str()),
      library_path.get(),
      &needs_native_bridge,
      &nativeloader_error_msg);
  VLOG(jni) << "[Call to dlopen(\"" << path << "\", RTLD_NOW) returned " << handle << "]";
  ...
  void* sym = library->FindSymbol("JNI_OnLoad", nullptr, android::kJNICallTypeRegular);
  if (sym == nullptr) {
    VLOG(jni) << "[No JNI_OnLoad found in \"" << path << "\"]";
    was_successful = true;
  } else {
    // Call JNI_OnLoad.  We have to override the current class
    // loader, which will always be "null" since the stuff at the
    // top of the stack is around Runtime.loadLibrary().  (See
    // the comments in the JNI FindClass function.)
    ScopedLocalRef<jobject> old_class_loader(env, env->NewLocalRef(self->GetClassLoaderOverride()));
    self->SetClassLoaderOverride(class_loader);

    VLOG(jni) << "[Calling JNI_OnLoad in \"" << path << "\"]";
    using JNI_OnLoadFn = int(*)(JavaVM*, void*);
    JNI_OnLoadFn jni_on_load = reinterpret_cast<JNI_OnLoadFn>(sym);
    int version = (*jni_on_load)(this, nullptr);
    ...
  }
}
```





## 4.1 JNI_OnLoad / JNI_OnUnload 边界

- `JNI_OnLoad` 不是强制必须存在；不存在时 so 仍可加载成功。
- 如果实现了 `JNI_OnLoad`，返回值必须是合法 JNI 版本（如 `JNI_VERSION_1_6`）。
- `JNI_OnUnload` 在 Android App 中常常不会触发（so 往往跟随进程生命周期）。
- 因此关键资源释放不要只依赖 `JNI_OnUnload`，要有进程退出前兜底策略。



## 4.2 时序验证

可以用一组最小日志验证“constructor 在前，`JNI_OnLoad` 在后”：

```c++
__attribute__((constructor))
static void so_ctor() {
  __android_log_print(ANDROID_LOG_INFO, "SO_TRACE", "constructor");
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  __android_log_print(ANDROID_LOG_INFO, "SO_TRACE", "JNI_OnLoad");
  return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL
Java_com_example_demo_MainActivity_ping(JNIEnv*, jobject) {
  __android_log_print(ANDROID_LOG_INFO, "SO_TRACE", "first native call");
}
```

```kotlin
Log.i("SO_TRACE", "before loadLibrary")
System.loadLibrary("demo")
Log.i("SO_TRACE", "after loadLibrary")
ping()
```

预期日志顺序：

1. `before loadLibrary`
2. `constructor`
3. `JNI_OnLoad`
4. `after loadLibrary`
5. `first native call`



## 4.3 加载时序决定 Hook 安装窗口

这部分和 PLT Hook / Inline Hook 强相关：

- PLT Hook：通常在目标 so 完成重定位后安装更稳。
- Inline Hook：通常在目标代码段映射后、目标函数首次执行前安装。
- 过早安装会找不到目标模块，过晚安装会错过第一次关键调用。

推荐时序：

```text
System.loadLibrary(target)
  -> linker: map + relocate + constructors
  -> JNI_OnLoad(target)
System.loadLibrary(hook)
  -> install hook
业务线程首次调用目标函数
```



# 5. 常见报错与排查

## 5.1 高频报错

1. `dlopen failed: library "xxx.so" not found`

   - 库不在搜索路径
   - ABI 目录不匹配（如只打包了 `armeabi-v7a`，进程却是 `arm64-v8a`）

2. `dlopen failed: cannot locate symbol "xxx"`

   - 依赖库缺失
   - 符号被裁剪或版本不匹配

3. `UnsatisfiedLinkError: JNI_ERR returned from JNI_OnLoad`

   - `JNI_OnLoad` 返回版本非法
   - `RegisterNatives` 失败

4. `dlopen failed: wrong ELF class`

   - 32/64 位混用

## 5.2 namespace 访问失败专项

Android N 以后，namespace 是 so 加载失败的高频原因。典型报错如下：

```text
java.lang.UnsatisfiedLinkError: dlopen failed: library "libfoo.so" needed or
dlopened by "/data/app/.../libbar.so" is not accessible for the namespace
"classloader-namespace"
```

常见触发原因：

- 依赖 so 不在当前 ClassLoader 对应 namespace 的可见范围。
- 误链接了非 public NDK 的系统私有 so。
- 插件化/动态化场景中，加载方和被加载方不在同一 namespace。

排查建议：

1. 先用 `readelf -d` 看 `DT_NEEDED`，确认依赖链完整。
2. 再看 `adb logcat` 里 linker 具体拒绝的是哪个 namespace。
3. 优先改为 public NDK 依赖，统一加载路径与 ClassLoader。



## 5.3 常用排查命令

```bash
# 看 ELF 基本信息（位数/架构）
readelf -h libdemo.so

# 看依赖库列表（DT_NEEDED）
readelf -d libdemo.so

# 看动态符号（是否有 JNI_OnLoad / 目标符号）
readelf -Ws libdemo.so

# 结合日志看加载错误
adb logcat | rg -i "dlopen|linker|UnsatisfiedLinkError|JNI_OnLoad"
```



# 6. 总结

SO 加载可以理解为三层协作：

- Java/ART 层：处理 `System.loadLibrary`、ClassLoader 语义和 namespace 规则。
- linker 层：完成 ELF 映射、依赖解析、重定位、构造函数调用。
- JNI 层：在 `dlopen` 成功后执行 `JNI_OnLoad` 完成 native 注册。



# 7. 其他知识点补充（实战与原理）

## 7.1 RTLD 参数与加载策略

`dlopen` 的 flags 会直接影响符号解析时机与可见性：

- `RTLD_NOW`：加载阶段完成符号解析，问题暴露更早，失败更快。
- `RTLD_LAZY`：函数符号在首次调用时再解析，首调才可能暴露问题。
- `RTLD_GLOBAL`：把当前 so 导出的符号加入全局可见集合，后续库可见。
- `RTLD_LOCAL`：默认局部可见，不向后续库导出。

在 Android Java 场景，`System.loadLibrary` 典型路径通常以 `RTLD_NOW` 方式加载；而 Native 自己调用 `dlopen` 时，flags 由业务代码决定。



## 7.2 符号解析与可见性

加载成功不代表符号一定按预期命中。需要同时关注：

- 符号是否真的导出（`readelf -Ws` 可确认）。
- 编译可见性（如 `-fvisibility=hidden`）是否把符号隐藏了。
- 同名符号是否存在多个版本或多个来源库，导致解析命中偏差。

如果 so 主要给 JNI 使用，通常建议：

- 对外仅导出必要 JNI 接口；
- 其余符号尽量收敛可见性，减少冲突面。



## 7.3 Android 版本与 namespace 差异

SO 加载策略和 Android 版本强相关：

- Android 7.0+：引入 linker namespace，库可见性更严格。
- Android 8.0+（Treble）：`system/vendor` 边界更清晰，私有库访问限制更强。
- targetSdk 升级后：某些历史兼容路径会收紧，旧方案可能在新版本失效。

工程上要避免依赖“刚好可用”的私有库路径，优先使用 public NDK 能力。



## 7.4 JNI 注册方式与生命周期

JNI 常见两种注册方式：

- 静态注册：按命名规则导出 `Java_xxx_xxx` 函数。
- 动态注册：在 `JNI_OnLoad` 里通过 `RegisterNatives` 绑定。

动态注册更常用于工程化项目（函数名更可控、重构成本更低）。

生命周期上要注意：

- `JNI_OnLoad` 返回值必须合法（如 `JNI_VERSION_1_6`）。
- `JNI_OnUnload` 在 App 场景通常不可靠，不要把关键释放逻辑只放这里。



## 7.5 ABI 与打包链路

加载失败很多时候不是代码问题，而是打包链路问题：

- `abiFilters` 配置不完整，导致目标 ABI 的 so 未打包。
- AAB/拆包后设备拿到的 split 不含目标 so。
- 32/64 位混用，触发 `wrong ELF class`。
- `android:extractNativeLibs` 策略和包内 so 对齐不满足要求，影响加载路径。

建议每次发版都对目标 ABI 做一次 `readelf -h` 与真机验证。



## 7.6 一条固定排障路径

出现 native 加载问题时，建议按固定顺序处理：

1. 看错误原文：先抓完整 `UnsatisfiedLinkError` / linker 日志。
2. 看 ABI：`readelf -h` 确认位数与架构。
3. 看依赖：`readelf -d` 检查 `DT_NEEDED` 是否齐全。
4. 看符号：`readelf -Ws` 确认目标符号是否存在且可见。
5. 看 namespace：根据 logcat 判断是否被 namespace 拒绝。
6. 看初始化：确认 `constructor` / `JNI_OnLoad` 的执行顺序与返回值。

这套顺序能覆盖大多数线上常见问题，排障效率会明显提升。



# 参考地址

[bionic linker 源码](https://cs.android.com/android/platform/superproject/main/+/main:bionic/linker/)

[art JavaVMExt 源码](https://cs.android.com/android/platform/superproject/main/+/main:art/runtime/jni/java_vm_ext.cc)

[libnativeloader 源码](https://cs.android.com/android/platform/superproject/main/+/main:system/core/libnativeloader/)

[ELF 规范](https://refspecs.linuxfoundation.org/elf/elf.pdf)
