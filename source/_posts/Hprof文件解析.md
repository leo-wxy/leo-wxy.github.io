---
title: Hprof文件解析
typora-root-url: ../
date: 2020-12-14 14:45:43
tags: Java
top: 9
---

> Hprof对应的就是**内存快照**。可以方便的凭借`Hprof`进行`OOM分析`以及`异常治理`。

- `OOM治理`

  `内存快照`保存的`对象信息`和`依赖关系`也是静态分析内存泄漏的关键。

- `Crash治理`

  保存的数据，也可用于分析异常问题。



![Hprof文件解析](/images/Hprof文件解析.png)



## Hprof文件格式

Hprof文件格式有明确组织方式，Android在Java的基础上新增了部分Tag。

### Java Hprof格式

![Java Hprof格式](/images/Java Hprof格式.png)

整体分为`Header`和`Record数组`两部分。

#### Header

> 记录hprof的元信息

![Hprof-Header](/images/Hprof-Header)

- 格式名和版本号：JAVA PROFILE 1.0.2 (`18byte`)
- 标识符大小：`4byte`
- 高位时间戳：`4byte`
- 地位时间戳：`4byte`

`Header`总共占了`18 + 4 + 4 + 4 = 32byte `

#### Record数组

> 记录各个类型对应的数据

![Hprof-Record](/images/Hprof-Record)

- **类型(`TAG`)**：表示Record对应的类型(`1Byte`)
- 时间戳(`TIME`)：发生时间(`4byte`)
- 长度(`LENGTH`)：记录数据的长度(`4byte`)
- 记录数据(`BODY`)：记录的数据(`${LENGTH}Byte`)

单条`Record`总共占了`1 + 4 + 4 + LENGTH byte`



#### 支持的TAG类型

##### 一级Tag

- STRING_IN_UTF8 = 0x01
- LOAD_CLASS = 0x02
- UNLOAD_CLASS = 0x03
- STACK_FRAME = 0x04
- STACK_TRACE = 0x05
- ALLOC_SITES = 0x06
- HEAP_SUMMARY = 0x07
- START_THREAD = 0x0a
- END_THREAD = 0x0b
- **HEAP_DUMP = 0x0c**
- CPU_SAMPLES = 0x0d
- CONTROL_SETTINGS = 0x0e
- **HEAP_DUMP_SEGMENT = 0x1c**
- HEAP_DUMP_END = 0x2c

##### 二级Tag

主要位于`HEAP_DUMP`或`HEAP_DUMP_SEGMENT`中

- ROOT_UNKNOWN = 0xff
- ROOT_JNI_GLOBAL = 0x01
- ROOT_JNI_LOCAL = 0x02
- ROOT_JAVA_FRAME = 0x03
- ROOT_NATIVE_STACK = 0x04
- ROOT_STICKY_CLASS = 0x05
- ROOT_THREAD_BLOCK = 0x06
- ROOT_MONITOR_USED = 0x07
- ROOT_THREAD_OBJECT = 0x08
- **CLASS_DUMP = 0x20**
- **INSTANCE_DUMP = 0x21**
- **OBJECT_ARRAY_DUMP = 0x22**
- **PRIMITIVE_ARRAY_DUMP = 0x23**：占据到80%以上

### Android Hprof格式

![Android Hprof格式](/images/Android Hprof格式.png)

#### Header

格式与Java的Header一致

#### Record数组

格式与Java的Record一致

#### 支持的TAG类型

##### 一级Tag

- STRING_IN_UTF8 = 0x01
- LOAD_CLASS = 0x02
- STACK_FRAME = 0x04
- STACK_TRACE = 0x05
- HEAP_DUMP_SEGMENT = 0x1c
- HEAP_DUMP_END = 0x2c

##### 二级Tag

主要位于`HEAP_DUMP_SEGMENT`中

- Java所有的二级Tag
- HEAP_DUMP_INFO = 0xfe：存储的是`堆空间的类型`，主要有以下三种
  - HEAP_ZYGOTE = 0x5A `Z` 系统堆空间
  - **HEAP_APP** = 0x41 `A` 应用堆空间
  - HEAP_IMAGE = 0x49 `I` 图片堆空间
- ROOT_INTERNED_STRING = 0x89
- ROOT_FINALIZING = 0x8a
- ROOT_DEBUGGER = 0x8b
- ROOT_REFERENCE_CLEANUP = 0x8c
- ROOT_VM_INTERNAL = 0x8d
- ROOT_JNI_MONITOR = 0x8e
- ROOT_UNREACHABLE = 0x90
- PRIMITIVE_ARRAY_NODATA = 0xc3

## Hprof文件生成原理

![Hprof文件生成原理](/images/Hprof文件生成原理.png)

### Debug.dumpHprofData()

通过调用`Debug.dumpHprofData()`去生成Hprof文件

```java
//frameworks/base/core/java/android/os/Debug.java
    public static void dumpHprofData(String fileName) throws IOException {
        VMDebug.dumpHprofData(fileName);
    }

//libcore/dalvik/src/main/java/dalvik/system/VMDebug.java
    public static void dumpHprofData(String filename) throws IOException {
        if (filename == null) {
            throw new NullPointerException("filename == null");
        }
        dumpHprofData(filename, null);
    }

    private static native void dumpHprofData(String fileName, int fd)
            throws IOException;
```

执行到Native层的`vmDebug`中

```c
//art/runtime/native/dalvik_system_VMDebug.cc
static void VMDebug_dumpHprofData(JNIEnv* env, jclass, jstring javaFilename, jint javaFd) {
  // Only one of these may be null.
  if (javaFilename == nullptr && javaFd < 0) {
    ScopedObjectAccess soa(env);
    ThrowNullPointerException("fileName == null && fd == null");
    return;
  }

  std::string filename;
  if (javaFilename != nullptr) {
    ScopedUtfChars chars(env, javaFilename);
    if (env->ExceptionCheck()) {
      return;
    }
    filename = chars.c_str();
  } else {
    filename = "[fd]";
  }

  int fd = javaFd;

  hprof::DumpHeap(filename.c_str(), fd, false);
}
```

`hprof`指的就是`hprof.cc`

### Hprof::DumpHeap()

```c
//art/runtime/hprof/hprof.cc
void DumpHeap(const char* filename, int fd, bool direct_to_ddms) {
  CHECK(filename != nullptr);
  Thread* self = Thread::Current();
  // Need to take a heap dump while GC isn't running. See the comment in Heap::VisitObjects().
  // Also we need the critical section to avoid visiting the same object twice. See b/34967844
  // 此时需要停止所有进程等待dump文件完成
  gc::ScopedGCCriticalSection gcs(self,
                                  gc::kGcCauseHprof,
                                  gc::kCollectorTypeHprof);
  ScopedSuspendAll ssa(__FUNCTION__, true /* long suspend */);
  Hprof hprof(filename, fd, direct_to_ddms);
  hprof.Dump();
}

  void Dump()
    REQUIRES(Locks::mutator_lock_)
    REQUIRES(!Locks::heap_bitmap_lock_, !Locks::alloc_tracker_lock_) {
    ...
    // First pass to measure the size of the dump.
    size_t overall_size;
    size_t max_length;
    {
      EndianOutput count_output;
      output_ = &count_output;
      ProcessHeap(false);//执行heap读取
      overall_size = count_output.SumLength();
      max_length = count_output.MaxLength();
      output_ = nullptr;
    }

    bool okay;
    visited_objects_.clear();
    ...
      //写入文件
      okay = DumpToFile(overall_size, max_length);
    
    ...
  }
```

#### ScopedSuspendAll

![Hprof-ScopedSuspendAll](/images/Hprof-ScopedSuspendAll.png)

```c
//art/runtime/thread_list.cc
ScopedSuspendAll::ScopedSuspendAll(const char* cause, bool long_suspend) {
  Runtime::Current()->GetThreadList()->SuspendAll(cause, long_suspend);
}

ScopedSuspendAll::~ScopedSuspendAll() {
  Runtime::Current()->GetThreadList()->ResumeAll();
}
```

##### SuspendAll

> **主要负责暂停所有Java线程的操作**

```c
void ThreadList::SuspendAll(const char* cause, bool long_suspend) {
  Thread* self = Thread::Current();

  {
    ScopedTrace trace("Suspending mutator threads");
    const uint64_t start_time = NanoTime();

    SuspendAllInternal(self, self);
    // All threads are known to have suspended (but a thread may still own the mutator lock)
    // Make sure this thread grabs exclusive access to the mutator lock and its protected data.
}

void ThreadList::SuspendAllInternal(Thread* self,
                                    Thread* ignore1,
                                    Thread* ignore2,
                                    SuspendReason reason) {
  ...
    for (const auto& thread : list_) {
      if (thread == ignore1 || thread == ignore2) {
        continue;
      }
      VLOG(threads) << "requesting thread suspend: " << *thread;
      //使thread进入 suspend状态
      bool updated = thread->ModifySuspendCount(self, +1, &pending_threads, reason);
      DCHECK(updated);

      // Must install the pending_threads counter first, then check thread->IsSuspend() and clear
      // the counter. Otherwise there's a race with Thread::TransitionFromRunnableToSuspended()
      // that can lead a thread to miss a call to PassActiveSuspendBarriers().
      if (thread->IsSuspended()) {
        // Only clear the counter for the current thread.
        thread->ClearSuspendBarrier(&pending_threads);
        pending_threads.FetchAndSubSequentiallyConsistent(1);
      }
    }
  
}
```



##### ResumeAll

> **主要负责唤醒暂停的Java线程**

```c
void ThreadList::ResumeAll() {
  Thread* self = Thread::Current();
  ...

  Locks::mutator_lock_->ExclusiveUnlock(self);
  {
    MutexLock mu(self, *Locks::thread_list_lock_);
    MutexLock mu2(self, *Locks::thread_suspend_count_lock_);
    // Update global suspend all state for attaching threads.
    --suspend_all_count_;
    // Decrement the suspend counts for all threads.
    for (const auto& thread : list_) {
      if (thread == self) {
        continue;
      }
      //解除suspend状态
      bool updated = thread->ModifySuspendCount(self, -1, nullptr, SuspendReason::kInternal);
      DCHECK(updated);
    }

    // Broadcast a notification to all suspended threads, some or all of
    // which may choose to wake up.  No need to wait for them.
    if (self != nullptr) {
      VLOG(threads) << *self << " ResumeAll waking others";
    } else {
      VLOG(threads) << "Thread[null] ResumeAll waking others";
    }
    Thread::resume_cond_->Broadcast(self);
  }

}
```



### Hprof::ProcessHeap()

![Hprof-ProcessHeap](/images/Hprof-ProcessHeap.png)

```c
//art/runtime/hprof/hprof.cc
  void ProcessHeap(bool header_first)
      REQUIRES(Locks::mutator_lock_) {
    current_heap_ = HPROF_HEAP_DEFAULT;
    objects_in_segment_ = 0;

    if (header_first) {
      ProcessHeader(true);
      ProcessBody();
    } else {
      ProcessBody();
      ProcessHeader(false);
    }
  }

```

#### ProcessHeader()

> 主要就是生成了Hprof对应的几个Tag的`Record`以及`Hprof Header`

```c
  void ProcessHeader(bool string_first) REQUIRES(Locks::mutator_lock_) {
    // Write the header.
    WriteFixedHeader();
    // Write the string and class tables, and any stack traces, to the header.
    // (jhat requires that these appear before any of the data in the body that refers to them.)
    // jhat also requires the string table appear before class table and stack traces.
    // However, WriteStackTraces() can modify the string table, so it's necessary to call
    // WriteStringTable() last in the first pass, to compute the correct length of the output.
    if (string_first) {
      WriteStringTable();
    }
    WriteClassTable();
    WriteStackTraces();
    if (!string_first) {
      WriteStringTable();
    }
    output_->EndRecord();
  }
```

##### WriteFixedHeader

> 生成`Hprof Header`

##### WriteClassTable

> 生成Tag为`LOAD_CLASS`的`Record`

##### WriteStackTraces

> 生成Tag为`STACK_FRAME`和`STACK_TRACE`的`Record`

##### WriteStringTable

> 生成Tag为`String`的`Record`

#### ProcessBody()

> 主要为了生成Tag为`HEAP_DUMP_SEGMENT`和`HEAP_DUMP_END`的Record。
>
> 还有生成`HEAP_DUMP_SEGMENT`下的`子Record`。

```c
  void ProcessBody() REQUIRES(Locks::mutator_lock_) {
    Runtime* const runtime = Runtime::Current();
    // Walk the roots and the heap.
    output_->StartNewRecord(HPROF_TAG_HEAP_DUMP_SEGMENT, kHprofTime);

    simple_roots_.clear();
    runtime->VisitRoots(this);
    runtime->VisitImageRoots(this);
    auto dump_object = [this](mirror::Object* obj) REQUIRES_SHARED(Locks::mutator_lock_) {
      DCHECK(obj != nullptr);
      //Dump内存对象
      DumpHeapObject(obj);
    };
    runtime->GetHeap()->VisitObjectsPaused(dump_object);
    output_->StartNewRecord(HPROF_TAG_HEAP_DUMP_END, kHprofTime);
    output_->EndRecord();
  }

```

##### DumpHeapObject

主要采用了`访问者模式`进行内存对象的转储

> 访问者模式：封装一些用于某种数据结构中的各元素的操作，可以在不改变这个数据结构的前提下定义作用于这些元素的新的操作。
>
> 适用于复杂的集合对象、XML文档解析等不易变的结构上。

```c
void Hprof::DumpHeapObject(mirror::Object* obj) {
  ...
    //记录堆空间位置
  if (heap_type != current_heap_) {
    HprofStringId nameId;

    // This object is in a different heap than the current one.
    // Emit a HEAP_DUMP_INFO tag to change heaps.
    __ AddU1(HPROF_HEAP_DUMP_INFO);
    __ AddU4(static_cast<uint32_t>(heap_type));   // uint32_t: heap type
    switch (heap_type) {
    case HPROF_HEAP_APP:
      nameId = LookupStringId("app");
      break;
    case HPROF_HEAP_ZYGOTE:
      nameId = LookupStringId("zygote");
      break;
    case HPROF_HEAP_IMAGE:
      nameId = LookupStringId("image");
      break;
    default:
      // Internal error
      LOG(ERROR) << "Unexpected desiredHeap";
      nameId = LookupStringId("<ILLEGAL>");
      break;
    }
    __ AddStringId(nameId);
    current_heap_ = heap_type;
  }

  mirror::Class* c = obj->GetClass();
  if (c == nullptr) {
    // This object will bother HprofReader, because it has a null
    // class, so just don't dump it. It could be
    // gDvm.unlinkedJavaLangClass or it could be an object just
    // allocated which hasn't been initialized yet.
  } else {
    if (obj->IsClass()) {
      DumpHeapClass(obj->AsClass());
    } else if (c->IsArrayClass()) {
      DumpHeapArray(obj->AsArray(), c);
    } else {
      DumpHeapInstanceObject(obj, c, visitor.GetRoots());
    }
  }    
  
}

void Hprof::DumpHeapClass(mirror::Class* klass) {
  ...
    AddU1(HPROF_PRIMITIVE_ARRAY_DUMP);
  ...
}

void Hprof::DumpHeapArray(mirror::Array* obj, mirror::Class* klass) {
  ...
    AddU1(HPROF_PRIMITIVE_ARRAY_DUMP);
  ...
}

void Hprof::DumpHeapInstanceObject(mirror::Object* obj,
                                   mirror::Class* klass,
                                   const std::set<mirror::Object*>& fake_roots) {
  ...
    AddU1(HPROF_PRIMITIVE_ARRAY_DUMP);
  ...
}
```

###### DumpHeapClass

> Dump内存的类信息
>
> 存放Tag为`CLASS_DUMP`的`Record`中

###### DumpHeapArray

> Dump内存的数组信息
>
> 存放Tag为`OBJECT_ARRAY_DUMP`的`Record`中

###### DumpHeapInstanceObject

> Dump内存的实例信息
>
> 存放Tag为`INSTANCE_DUMP`的`Record`中。*需要分析内存泄漏时一般都是分析其引用关系即实例间的联系。*
>
> **基本只要保留INSTANCE_DUMP这个Tag的Record信息，足以分析内存泄漏。**

###### Other

> 在Tag为`PRIMITIVE_ARRAY_DUMP`中基本存放的就是非·上述三种类型的数据.
>
> *所以这部分空间占用也是最大的！！！也是需要裁剪的*



## Hprof文件裁剪

![Hprof文件裁剪](/images/Hprof文件裁剪.png)

### Why 裁剪？

Hprof文件通常比较大，大文件在传输、解析、空间占用上都会产生很大的影响，因此需要进行裁剪。

- `存储`：通常Hprof文件较大，会占用很大的应用空间，如果空间不足够，将会导致无法`dump`进行解析。
- `传输`：假如需要dump用户的Hprof文件，就需要传回到服务端，耗费的流量也会比较大。
- `隐私`：Hprof文件存的是完整的内存数据，可能就包含很多隐私信息，这些都需要进行裁剪隐藏。



### How 裁剪？



主要有两套方案：

#### 先Dump后裁剪

![Dump文件后裁剪](/images/Dump文件后裁剪.png)

1. 通过`Debug.dumpHprofData()`得到一个完整的Hprof文件
2. 再分析Hprof文件，进行裁剪，去掉一些无用的数据
3. 裁剪完成后，得到一份精简的Hprof文件



缺陷：

- 直接dump出的Hprof文件过大，存储问题不好解决
- 裁剪过程涉及到文件IO和hprof文件解析，可能影响APP性能
- 裁剪过程不彻底，导致隐私数据的泄漏。

#### Dump过程实时裁剪(推荐)

![Dump实时裁剪](/images/Dump实时裁剪.png)

![Hprof实时裁剪流程](/images/Hprof实时裁剪流程.png)

1. 通过`xHook`对`open()`进行hook处理，替换成自身实现
2. 通过`xHook`对`write()`进行hook处理，替换成自身实现
3. 调用`Debug.dumpHprofData()`时，优先执行自身实现的`open()`，为了过滤出写入目标文件的fd；再然后调用到自身实现的`write`，对向目标文件写入的数据进行裁剪压缩。
4. 生成Hprof文件完毕后，清除之前的Hook内容。

#### 需要裁剪的内容

![Hprof-裁剪的内容](/images/Hprof-裁剪的内容.png)

需要裁剪掉全部基本类型数组的值，例如`char[](字符串)、byte[](图片)`，在处理`内存泄漏`相关问题时，一般也只关心`对象间的引用以及对象大小`，裁剪掉一些消息不会影响分析。

保证基本Hprof文件功能：

- 只对`HEAP_DUMP_SEGMENT`的`Record`下进行裁剪，其他保持不变。例如`STRING、LOAD_CLASS`等

- 在`HEAP_DUMP_SEGMENT`的`Record`下，主要删除`PRIMITIVE_ARRAY_DUMP`，这一块主要占用80%的内容

- 在裁剪`INSTANCE_DUMP(实例)`、`OBJECT_ARRAY_DUMP(对象数组)`，`CLASS_DUMP(类或接口)`和`HEAP_DUMP_INFO(记录当前堆位置)`时需要再去掉`Zygote Heap(系统堆)`和`Image Heap(图像堆)`

  主要通过判断`HEAP_DUMP_INFO`的`heapType`是否为`HEAP_ZYGOTE(Z)`和`HEAP_IMAGE(I)`



## 拓展知识

### 如何解决Dump hprof时暂停所有线程问题？

此时如果在主进程进行Dump操作，也就意味着**主进程上所有线程都会停止，也就无法进行任何操作。**此时就需要启动一个子进程，并且需要从主进程`fork`出一个子进程，需要遵循`COW机制(为了节省fork子进程的内存消耗和耗时，fork出的子进程并不会copy父进程的内存空间，而是共享。)`。

后续fork出的子进程在父进程修改时不受影响。

![fork子进程](/images/fork子进程)

头条解决方案

![子进程Dump内存流程图](/images/子进程Dump内存流程图)

## 参考链接

[hprof文件格式](http://hg.openjdk.java.net/jdk6/jdk6/jdk/raw-file/tip/src/share/demo/jvmti/hprof/manual.html#mozTocId848088)

[AS中的hprof文件解析](https://android.googlesource.com/platform/tools/base/+/studio-master-dev/perflib/src/main/java/com/android/tools/perflib/heap/HprofParser.java)

[Hprof裁剪](https://mp.weixin.qq.com/s?__biz=MzI1MzYzMjE0MQ==&mid=2247487203&idx=1&sn=182584b69910c843ae95f60e74127249&chksm=e9d0c501dea74c178e16f95a2ffc5007c5dbca89a02d56895ed9b05883cf0562da689ac6146b&mpshare=1&scene=23&srcid=1214vdTTpPyczmY38wlcDo94&sharer_sharetime=1607926324661&sharer_shareid=65073698ab9ac2983b955fa53b4ff585%23rd)

[Android线上OOM问题定位组件](https://tech.meituan.com/2019/11/14/crash-oom-probe-practice.html)

[KOOM](https://github.com/KwaiAppTeam/KOOM/blob/master/java-oom/src/main/cpp/hprof_dump.cpp)