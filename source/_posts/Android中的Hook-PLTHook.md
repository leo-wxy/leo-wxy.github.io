---
title: Android中的Hook-PLTHook
typora-root-url: ../
date: 2025-10-02 11:10:38
tags: Hook
top: 10
mermaid: true
---



![PLTHook](/images/PLTHook.png)

# 基本原理

Linux在执行 动态链接的ELF时候，为了优化性能会使用一个 **延迟绑定** 的策略。

（延迟绑定：为了解决原本静态编译时要把各种系统API的具体实现代码都编译进ELF文件导致文件巨大臃肿的问题。）

当动态链接的ELF程序调用共享库的函数时，会去查找PLT表中的对应项目，PLT表在跳跃到GOT表中找到执行函数的实际地址，后续再调用的时候会直接去执行GOT表中对应的目标函数。(通过 _dl_runtime_solve()执行)，

**PLT Hook通过直接修改GOT表，使得在调用对应共享库的函数时跳转到用户自定义的Hook功能代码。**



# ELF

> 需要真正了解 PLT Hook的原理，需要从ELF开始，逐步的了解 linker（动态链接器）以及加载ELF文件的过程。

## ELF格式

> 行业标准的二进制数据封装格式，主要用于封装可执行文件、动态库、object和coew dumps文件。
>
> so库就是ELF格式的文件，了解了ELF结构是PLT Hook的基础知识。
>
> 用 **readelf** 可以查看ELF文件的基本信息。
>
> 用 **objdump** 可以查看ELF文件的反汇编输出。

![ELF结构](/images/ELF结构.awebp)



### ELF文件头

> 固定格式的定长文件头（32位架构为 52字节，64位架构为 64字节）。

```shell
> aarch64-linux-android-readelf -h libbytehook.so
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              DYN (Shared object file)
  Machine:                           AArch64
  Version:                           0x1
  Entry point address:               0x55ec
  Start of program headers:          64 (bytes into file)
  Start of section headers:          319720 (bytes into file)
  Flags:                             0x0
  Size of this header:               64 (bytes)
  Size of program headers:           56 (bytes)
  Number of program headers:         9
  Size of section headers:           64 (bytes)
  Number of section headers:         34
  Section header string table index: 32

```



#### 固定头字符 

7f 45 4c 46 （后三个字符对应 E L F）

### PHT(Program header table) - 对应执行视图

> ELF被加载到内存时，以`segment`为单位，一个`segment`包含一个或多个`section`。
>
> PHT则是用来记录所有 segment的基本信息。
>
> 主要包括如下信息：
>
> - segment类型
> - 文件中的偏移量
> - 大小
> - 加载到内存后的虚拟内存相对地址
> - 内存中字节对齐方式

```shell
aarch64-linux-android-readelf -l libbytehook.so

Elf file type is DYN (Shared object file)
Entry point 0x55ec
There are 9 program headers, starting at offset 64

Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000000040 0x0000000000000040
                 0x00000000000001f8 0x00000000000001f8  R      8
  LOAD           0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x000000000000d7a0 0x000000000000d7a0  R E    4000
  LOAD           0x000000000000d7a0 0x00000000000117a0 0x00000000000117a0
                 0x0000000000000638 0x0000000000000638  RW     4000
  LOAD           0x000000000000ddd8 0x0000000000015dd8 0x0000000000015dd8
                 0x0000000000000054 0x00000000000004c8  RW     4000
  DYNAMIC        0x000000000000d8c0 0x00000000000118c0 0x00000000000118c0
                 0x00000000000001e0 0x00000000000001e0  RW     8
  GNU_RELRO      0x000000000000d7a0 0x00000000000117a0 0x00000000000117a0
                 0x0000000000000638 0x0000000000000860  R      1
  GNU_EH_FRAME   0x0000000000002d70 0x0000000000002d70 0x0000000000002d70
                 0x0000000000000884 0x0000000000000884  R      4
  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000000 0x0000000000000000  RW     0
  NOTE           0x0000000000000238 0x0000000000000238 0x0000000000000238
                 0x00000000000000bc 0x00000000000000bc  R      4

 Section to Segment mapping:
  Segment Sections...
   00     
   01     .note.android.ident .note.gnu.build-id .dynsym .gnu.version .gnu.version_r .gnu.hash .hash .dynstr .rela.dyn .rela.plt .rodata .eh_frame_hdr .eh_frame .text .plt 
   02     .data.rel.ro .fini_array .init_array .dynamic .got .got.plt 
   03     .data .bss 
   04     .dynamic 
   05     .data.rel.ro .fini_array .init_array .dynamic .got .got.plt 
   06     .eh_frame_hdr 
   07     
   08     .note.android.ident .note.gnu.build-id 

```

其中类型（Type）为 **LOAD**的segment都会被 linker 通过mmap 映射到内存中。

### * SHT(Section header table) - 对应连接视图

> ELF 以 section 为单位来组织和管理各种信息。使用 **SHT** 来记录所有section的基本信息。
>
> 主要包括：
>
> - section类型
> - 文件中的偏移量
> - 大小
> - 加载内存后的虚拟内存相对地址
> - 内存中的字节对齐方式

```shell
> aarch64-linux-android-readelf -S libbytehook.so
There are 34 section headers, starting at offset 0x4e0e8:

Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .note.android.ide NOTE             0000000000000238  00000238
       0000000000000098  0000000000000000   A       0     0     4
  [ 2] .note.gnu.build-i NOTE             00000000000002d0  000002d0
       0000000000000024  0000000000000000   A       0     0     4
  [ 3] .dynsym           DYNSYM           00000000000002f8  000002f8
       0000000000000900  0000000000000018   A       8     1     8
  [ 4] .gnu.version      VERSYM           0000000000000bf8  00000bf8
       00000000000000c0  0000000000000002   A       3     0     2
  [ 5] .gnu.version_r    VERNEED          0000000000000cb8  00000cb8
       0000000000000040  0000000000000000   A       8     2     4
  [ 6] .gnu.hash         GNU_HASH         0000000000000cf8  00000cf8
       0000000000000094  0000000000000000   A       3     0     8
  [ 7] .hash             HASH             0000000000000d8c  00000d8c
       0000000000000308  0000000000000004   A       3     0     4
  [ 8] .dynstr           STRTAB           0000000000001094  00001094
       0000000000000598  0000000000000000   A       0     0     1
  [ 9] .rela.dyn         RELA             0000000000001630  00001630
       00000000000004f8  0000000000000018   A       3     0     8
  [10] .rela.plt         RELA             0000000000001b28  00001b28
       0000000000000828  0000000000000018  AI       3    21     8
  [11] .rodata           PROGBITS         0000000000002350  00002350
       0000000000000a20  0000000000000000 AMS       0     0     8
  [12] .eh_frame_hdr     PROGBITS         0000000000002d70  00002d70
       0000000000000884  0000000000000000   A       0     0     4
  [13] .eh_frame         PROGBITS         00000000000035f8  000035f8
       0000000000001ff4  0000000000000000   A       0     0     8
  [14] .text             PROGBITS         00000000000055ec  000055ec
       0000000000007c18  0000000000000000  AX       0     0     4
  [15] .plt              PROGBITS         000000000000d210  0000d210
       0000000000000590  0000000000000000  AX       0     0     16
  [16] .data.rel.ro      PROGBITS         00000000000117a0  0000d7a0
       00000000000000f8  0000000000000000  WA       0     0     8
  [17] .fini_array       FINI_ARRAY       0000000000011898  0000d898
       0000000000000010  0000000000000000  WA       0     0     8
  [18] .init_array       INIT_ARRAY       00000000000118a8  0000d8a8
       0000000000000018  0000000000000000  WA       0     0     8
  [19] .dynamic          DYNAMIC          00000000000118c0  0000d8c0
       00000000000001e0  0000000000000010  WA       8     0     8
  [20] .got              PROGBITS         0000000000011aa0  0000daa0
       0000000000000068  0000000000000000  WA       0     0     8
  [21] .got.plt          PROGBITS         0000000000011b08  0000db08
       00000000000002d0  0000000000000000  WA       0     0     8
  [22] .data             PROGBITS         0000000000015dd8  0000ddd8
       0000000000000054  0000000000000000  WA       0     0     8
  [23] .bss              NOBITS           0000000000015e30  0000de2c
       0000000000000470  0000000000000000  WA       0     0     8
  [24] .comment          PROGBITS         0000000000000000  0000de2c
       0000000000000125  0000000000000001  MS       0     0     1
  [25] .debug_loc        PROGBITS         0000000000000000  0000df51
       000000000000f965  0000000000000000           0     0     1
  [26] .debug_abbrev     PROGBITS         0000000000000000  0001d8b6
       000000000000332c  0000000000000000           0     0     1
  [27] .debug_info       PROGBITS         0000000000000000  00020be2
       0000000000013a92  0000000000000000           0     0     1
  [28] .debug_ranges     PROGBITS         0000000000000000  00034674
       0000000000001d80  0000000000000000           0     0     1
  [29] .debug_str        PROGBITS         0000000000000000  000363f4
       0000000000005705  0000000000000001  MS       0     0     1
  [30] .debug_line       PROGBITS         0000000000000000  0003baf9
       000000000000ac7d  0000000000000000           0     0     1
  [31] .symtab           SYMTAB           0000000000000000  00046778
       0000000000005970  0000000000000018          33   859     8
  [32] .shstrtab         STRTAB           0000000000000000  0004c0e8
       0000000000000157  0000000000000000           0     0     1
  [33] .strtab           STRTAB           0000000000000000  0004c23f
       0000000000001ea8  0000000000000000           0     0     1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  p (processor specific)

```

其中 `starting at offset 0x4e0e8` 对应 header中  `Start of section headers:          319720 (bytes into file)`

其中与 PLT Hook相关的Section如下：

##### .dynstr

保存所有字符串常量信息

##### .dynsym

保存符号（symbol）的信息。

- 符号的类型
- 符号起始地址
- 符号大小
- 符号名称在 `.dynstr`中的索引编号

##### .text

代码经过编译后生成的二进制机器指令

##### .data

已初始化的非只读数据

##### **.dynamic**

专门为`linker`设计的，记录了当前ELF的外部依赖，各个重要的section起始位置。

linker解析和加载ELF会用到的各项数据的索引信息。

##### .got.plt

给plt用的函数地址表，存储真实使用的函数地址

##### .got (Global Offset Table)

用于记录外部调用的入口地址，当linker执行 relocate 之后，表里会记录真实的外部调用绝对地址。

##### .plt (Procedure Linkage Table)

外部调用的跳板，主要用于支持 Lazy binding 方式的外部调用重定位。（目前只有MIPS架构支持）

.plt 会从 `.got`,`.data`,`.data.rel.ro`中查询符号的绝对地址，然后执行跳转。



### 连接视图 - Linking View

> ELF 未被加载到内存执行前，以section为单位的数据组织形式

![Linking View](/images/LinkingView.png)

### *执行视图 - Execution View

> ELF 被加载到内存后，以 segment 为单位的数据组织形式
>
> PLT Hook主要关心 **执行视图**。

![Execution View](/images/executionview.png)

PLT Hook的执行时机是在 linker 使用 mmap 将ELF加载到内存中，再通过执行 relocation 把外部引用的绝对地址填入 GOT表和 DATA中。



### * .dynamic section

> 专门为 `linker` 设计的，其中包含了 linker解析和加载ELF会用到的各项数据的索引信息。
>
> 对应 PHT中 type为 `DYNAMIC`的segment，再通过这个 segment 找到 .dynamic session。

```shell
aarch64-linux-android-readelf -d libbytehook.so

Dynamic section at offset 0xd8c0 contains 30 entries:
  Tag        Type                         Name/Value
 0x0000000000000001 (NEEDED)             Shared library: [liblog.so]
 0x0000000000000001 (NEEDED)             Shared library: [libshadowhook.so]
 0x0000000000000001 (NEEDED)             Shared library: [libm.so]
 0x0000000000000001 (NEEDED)             Shared library: [libdl.so]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so]
 0x000000000000000e (SONAME)             Library soname: [libbytehook.so]
 0x000000000000001e (FLAGS)              BIND_NOW
 0x000000006ffffffb (FLAGS_1)            Flags: NOW
 0x0000000000000007 (RELA)               0x1630
 0x0000000000000008 (RELASZ)             1272 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x000000006ffffff9 (RELACOUNT)          47
 0x0000000000000017 (JMPREL)             0x1b28
 0x0000000000000002 (PLTRELSZ)           2088 (bytes)
 0x0000000000000003 (PLTGOT)             0x11b08
 0x0000000000000014 (PLTREL)             RELA
 0x0000000000000006 (SYMTAB)             0x2f8
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000005 (STRTAB)             0x1094
 0x000000000000000a (STRSZ)              1432 (bytes)
 0x000000006ffffef5 (GNU_HASH)           0xcf8
 0x0000000000000004 (HASH)               0xd8c
 0x0000000000000019 (INIT_ARRAY)         0x118a8
 0x000000000000001b (INIT_ARRAYSZ)       24 (bytes)
 0x000000000000001a (FINI_ARRAY)         0x11898
 0x000000000000001c (FINI_ARRAYSZ)       16 (bytes)
 0x000000006ffffff0 (VERSYM)             0xbf8
 0x000000006ffffffe (VERNEED)            0xcb8
 0x000000006fffffff (VERNEEDNUM)         2
 0x0000000000000000 (NULL)               0x0

```





### 参考文献

[ELF概述](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format)

[ELF完整结构](http://refspecs.linuxbase.org/elf/elf.pdf)



## linker（动态链接器）

![linker](/images/linker.awebp)

[linker源码](https://cs.android.com/android/platform/superproject/main/+/main:bionic/linker/)



### 大致步骤

#### 动态链接（dlopen）

```c++
void* do_dlopen(const char* name, int flags,
                const android_dlextinfo* extinfo,
                const void* caller_addr) {
 ... 
   // load ELF
 soinfo* si = find_library(ns, translated_name, flags, extinfo, caller);
  loading_trace.End();

  if (si != nullptr) {
    void* handle = si->to_handle();
    LD_LOG(kLogDlopen,
           "... dlopen calling constructors: realpath=\"%s\", soname=\"%s\", handle=%p",
           si->get_realpath(), si->get_soname(), handle);
    // 调用构造函数
    si->call_constructors();
    failure_guard.Disable();
    LD_LOG(kLogDlopen,
           "... dlopen successful: realpath=\"%s\", soname=\"%s\", handle=%p",
           si->get_realpath(), si->get_soname(), handle);
    return handle;
  }

  return nullptr;
}
```



#### 加载ELF

```c++
static soinfo* find_library(android_namespace_t* ns,
                            const char* name, int rtld_flags,
                            const android_dlextinfo* extinfo,
                            soinfo* needed_by) {
  soinfo* si = nullptr;

  if (name == nullptr) {
    si = solist_get_somain();
  } else if (!find_libraries(ns,
                             needed_by,
                             &name,
                             1,
                             &si,
                             nullptr,
                             0,
                             rtld_flags,
                             extinfo,
                             false /* add_as_children */)) {
    if (si != nullptr) {
      soinfo_unload(si);
    }
    return nullptr;
  }

  si->increment_ref_count();

  return si;
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
 ... 
}

```

##### prelink_image

> 加载ELF中的 .dynamic section 从里面读取外部以来的ELF列表信息
> 从PHT读取

```c++
bool soinfo::prelink_image(bool dlext_use_relro) {
  if (flags_ & FLAG_PRELINKED) return true;
  /* Extract dynamic section */
  ElfW(Word) dynamic_flags = 0;
  phdr_table_get_dynamic_section(phdr, phnum, load_bias, &dynamic, &dynamic_flags);
  
}

void phdr_table_get_dynamic_section(const ElfW(Phdr)* phdr_table, size_t phdr_count,
                                    ElfW(Addr) load_bias, ElfW(Dyn)** dynamic,
                                    ElfW(Word)* dynamic_flags) {
  *dynamic = nullptr;
  for (size_t i = 0; i<phdr_count; ++i) {
    const ElfW(Phdr)& phdr = phdr_table[i];
    if (phdr.p_type == PT_DYNAMIC) {
      *dynamic = reinterpret_cast<ElfW(Dyn)*>(load_bias + phdr.p_vaddr);
      if (dynamic_flags) {
        *dynamic_flags = phdr.p_flags;
      }
      return;
    }
  }
}
```

##### link_image

> 执行 relocation 操作
>
> 

```c++
bool soinfo::link_image(const SymbolLookupList& lookup_list, soinfo* local_group_root,
                        const android_dlextinfo* extinfo, size_t* relro_fd_offset) {
 
  
  if (this != solist_get_vdso() && !relocate(lookup_list)) {
    return false;
  }
...
  ++g_module_load_counter;
  notify_gdb_of_load(this);
  set_image_linked();
  return true;
  
}
```

```c++
// bionic/linker/linker_relocate.cpp
bool soinfo::relocate(const SymbolLookupList& lookup_list) {
  ...
      if (relr_ != nullptr && !is_linker()) {
    LD_DEBUG(reloc, "[ relocating %s relr ]", get_realpath());
    const ElfW(Relr)* begin = relr_;
    const ElfW(Relr)* end = relr_ + relr_count_;
    if (!relocate_relr(begin, end, load_bias, should_tag_memtag_globals())) {
      return false;
    }
  }
  ...
}
```

```c++
// Process relocations in SHT_RELR section (experimental).
// Details of the encoding are described in this post:
//   https://groups.google.com/d/msg/generic-abi/bX460iggiKg/Pi9aSwwABgAJ
bool relocate_relr(const ElfW(Relr) * begin, const ElfW(Relr) * end, ElfW(Addr) load_bias,
                   bool has_memtag_globals) {
  constexpr size_t wordsize = sizeof(ElfW(Addr));

  ElfW(Addr) base = 0;
  for (const ElfW(Relr)* current = begin; current < end; ++current) {
    ElfW(Relr) entry = *current;
    ElfW(Addr) offset;

    if ((entry&1) == 0) {
      // Even entry: encodes the offset for next relocation.
      offset = static_cast<ElfW(Addr)>(entry);
      apply_relr_reloc(offset, load_bias, has_memtag_globals);
      // Set base offset for subsequent bitmap entries.
      base = offset + wordsize;
      continue;
    }

    // Odd entry: encodes bitmap for relocations starting at base.
    offset = base;
    while (entry != 0) {
      entry >>= 1;
      if ((entry&1) != 0) {
        apply_relr_reloc(offset, load_bias, has_memtag_globals);
      }
      offset += wordsize;
    }

    // Advance base offset by 63 words for 64-bit platforms,
    // or 31 words for 32-bit platforms.
    base += (8*wordsize - 1) * wordsize;
  }
  return true;
}

```

执行重定位操作，这是最关键一步。

目的是为当前加载的ELF的每个`导入符号`找到对应的外部符号的绝对地址并写入到对应的位置里。

查询绝对地址

- `.rela.plt`,`.rel.plt`：用于关联`.got.plt`和`.dynsym`，就是`PLT表`
- `.rela.dyn`,`.rel.dyn`：关联`.data`,`.data.rel.ro`,`.dynsym`

写入位置

- `.got.plt`：保存外部函数的绝对地址，就是`GOT表`
- `.data`,`.data.rel.ro`：保存外部数据（函数指针）的绝对地址

> `.rela.*`只在64位架构做了实现，相比`.rel`多了`r_addend`字段。

`PLT`：Procedure Linkage Table - 过程链接表

`GOT`：Global Offset Table - 全局偏移表

## Hook原理

通过符号名，先在hash table中找到对应的符号信息(`.dynsym`)中，再从`PLT表`找到符号对应的信息，再从`GOT表`中找到绝对地址信息。**通过修改GOT表中的绝对地址值，替换为Hook函数的地址。**



### 作用边界（很重要）

PLT Hook 本质上是修改导入方模块中的 GOT 表项，因此它的生效范围有明确边界：

- 能拦截：**跨 so 的外部符号调用**（调用路径经过 PLT/GOT）。
- 通常不能拦截：同一 so 内部直接调用（不经过 PLT）、`static` 函数、被编译器内联/优化掉的调用。
- 需要注意：如果目标符号在链接期或运行期被特殊处理（如符号裁剪、`-Bsymbolic`、符号版本不匹配），可能无法命中 Hook。

一句话：**PLT Hook 拦截的是“导入调用点”，不是“函数本体的所有执行路径”。**



### 重定位类型：不只看 .rela.plt

很多资料只强调 `.rela.plt`，但工程里通常要同时关注多种重定位项：

- `JUMP_SLOT`：典型的函数导入调用，对应 PLT/GOT 路径（最常见的 PLT Hook 目标）。
- `GLOB_DAT`：全局数据或函数地址类导入，常落在 `.got/.data.rel.ro`，有些 Hook 框架也会处理它。
- `RELATIVE`：用于基址修正，通常不是符号级 Hook 目标。

不同架构的重定位记录格式不同：

- `arm64` 常见 `RELA`（带 `addend` 字段）。
- `arm32` 常见 `REL`（不带 `addend` 字段，附加值来自内存）。

因此在实现里建议按 `DT_PLTREL` / `DT_RELA` / `DT_REL` 分支解析，而不是写死只处理一种格式。



### Hook时机与内存保护（NOW/LAZY + RELRO）

PLT Hook 是否“马上生效”，与装载策略和内存保护强相关：

- `RTLD_NOW` / `BIND_NOW`：加载期完成大部分符号解析，GOT 很早就被填好。
- `RTLD_LAZY`：首次调用时才解析 `JUMP_SLOT`，如果 Hook 安装太晚，可能错过第一次调用。
- `RELRO`（尤其 `GNU_RELRO`）：重定位完成后，`.got/.got.plt/.data.rel.ro` 常被改为只读；写 GOT 前通常需要 `mprotect` 临时改写权限。

实践建议：

1. 尽量在目标 so 完成加载且首次关键调用前安装 Hook。  

2. 写入前做页对齐并 `mprotect(PROT_READ | PROT_WRITE)`，写入后恢复原权限。  

3. 记录 old/new 地址与返回码，失败时输出 `errno` 便于定位是时机问题还是权限问题。

   

### 常见失败场景（排查清单）

PLT Hook 失败通常不是“代码没执行”，而是“调用路径不经过你改写的表项”：

- `-Bsymbolic`：库内部对本库符号优先绑定，导致内部调用不走外部导入表。
- 符号被优化：`inline/static/LTO` 等导致目标调用点被消除或改写。
- 符号版本不匹配：同名符号存在版本差异，按名称匹配可能命中错误项或无法命中。
- linker namespace 隔离：目标库不在当前命名空间可见范围内，`dlopen/dlsym` 或遍历结果与预期不一致。
- 安装时机过晚：首次调用已发生，或已被其他框架先改写。
- 权限问题：`RELRO` 页未正确 `mprotect`，写入失败（通常伴随 `errno`）。

建议把“目标 so、符号名、重定位类型、旧地址/新地址、错误码”作为统一日志字段，优先确认“是否命中正确 GOT 表项”。



### 工程化最佳实践（稳定性）

PLT Hook 建议至少补齐这些工程化能力：

- 幂等安装：同一 `so + symbol` 多次安装时要检测并避免重复写入。
- 线程安全：改写 GOT 时加锁，避免并发安装/卸载导致地址撕裂或状态错乱。
- 防递归调用：Hook 函数里调用链可能再次命中自身，需线程局部标记（TLS guard）防止无限递归。
- 可恢复（unhook）：保存原始地址并支持回滚，便于灰度、故障止损和 A/B 对比。
- 白名单策略：只扫描和改写目标库/目标符号，避免全量遍历带来的性能与兼容性风险。

建议维护一张运行时状态表（目标库、符号、原地址、现地址、安装时间、状态码），用于排障与观测。



# PLT Hook实践

以下是基于 三个自己编译的so进行的处理，代码逻辑相对简单。只为了熟悉基础的hook流程。如果需要更稳定的hook,还是推荐使用 相关三方库里的。

![Demo层级](/images/PLTHookDemo-Tree.png)

## combined.cpp(待Hook类)

```c++
//
// Created by wxy on 2025/10/5.
//
#include <jni.h>
#include <android/log.h>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "PLT_COMBINED", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "PLT_COMBINED", __VA_ARGS__)

// ----------------------------
// target_function（待 hook）
// ----------------------------
extern "C" __attribute__((noinline)) int target_function(int x) {
    LOGI("target_function called with %d", x);
    return x + 1;
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

```

## plthook.cpp(PLTHook类)

```c++
#define _GNU_SOURCE
#include <dlfcn.h>         // dlopen/dlsym/dl_iterate_phdr
#include <link.h>          // dl_phdr_info, Elf headers
#include <elf.h>           // ELF 结构定义
#include <pthread.h>       // pthread_create
#include <unistd.h>        // sleep, sysconf
#include <sys/mman.h>      // mprotect
#include <android/log.h>   // Android 日志打印
#include <string.h>
#include <errno.h>
#include <stdint.h>

// -----------------------------
// 日志宏定义
// -----------------------------
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "PLT_HOOK", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "PLT_HOOK", __VA_ARGS__)

// -----------------------------
// 目标库与函数名
// -----------------------------
// 我们的目标是 hook libcombined.so 里的 target_function
static const char COMBINED_SO[] = "libcombined.so";
static const char TARGET_SYM[] = "target_function";

// -----------------------------
// 原始函数指针
// -----------------------------
typedef int (*target_fn_t)(int);
static target_fn_t original_target_fn = nullptr;

// -----------------------------
// Hook 替换后的函数实现
// -----------------------------
extern "C" int hooked_target_function(int x) {
    LOGI("[HOOK] hooked_target_function called, arg=%d", x);

    // 修改输入参数
    int new_arg = x + 200;
    int ret = 0;

    // 调用原始函数
    if (original_target_fn)
        ret = original_target_fn(new_arg);
    else
        LOGE("[HOOK] original_target_fn null!");

    LOGI("[HOOK] return %d", ret);
    return ret;
}

// ============================================================================
// 下面部分是 Hook 实现逻辑：遍历 ELF 段，定位 GOT 表，修改函数指针
// ============================================================================

// -----------------------------
// 将 GOT 所在内存页设置为可写
// -----------------------------
static bool make_writable(void* addr, size_t len) {
    long page_size = sysconf(_SC_PAGESIZE);  // 通常是 4096 bytes

    // 页对齐：mprotect 只能按页修改权限
    uintptr_t start = (uintptr_t)addr & ~(page_size - 1);
    uintptr_t end   = ((uintptr_t)addr + len + page_size - 1) & ~(page_size - 1);
    size_t size     = end - start;

    // 将 GOT 页改为读写
    if (mprotect((void*)start, size, PROT_READ | PROT_WRITE) != 0) {
        LOGE("mprotect failed: %s addr=%p size=%zu", strerror(errno), addr, size);
        return false;
    }

    LOGI("mprotect success: addr=%p size=%zu", addr, size);
    return true;
}

// -----------------------------
// 解析 64 位 ELF 动态段信息并修改 GOT
// -----------------------------
static bool process_relocations_64(uintptr_t base, const Elf64_Phdr* phdr, int phnum) {
    // 找到 PT_DYNAMIC 段（保存重定位表、符号表等）
    const Elf64_Dyn* dyn = nullptr;
    for (int i = 0; i < phnum; i++) {
        if (phdr[i].p_type == PT_DYNAMIC)
            dyn = (const Elf64_Dyn*)(base + phdr[i].p_vaddr);
    }
    if (!dyn) return false;

    // 动态段中保存的关键表指针
    const char* strtab = nullptr;     // 字符串表
    const Elf64_Sym* symtab = nullptr; // 符号表
    Elf64_Rela* rela = nullptr;        // PLT 重定位表
    size_t rela_size = 0;              // 重定位表大小

    // 从动态段中提取各个表的地址
    for (const Elf64_Dyn* d = dyn; d->d_tag != DT_NULL; d++) {
        switch (d->d_tag) {
            case DT_STRTAB:   strtab = (const char*)(base + d->d_un.d_ptr); break;
            case DT_SYMTAB:   symtab = (const Elf64_Sym*)(base + d->d_un.d_ptr); break;
            case DT_JMPREL:   rela = (Elf64_Rela*)(base + d->d_un.d_ptr); break;
            case DT_PLTRELSZ: rela_size = d->d_un.d_val; break;
            default: break;
        }
    }

    // 确保表都存在
    if (!strtab || !symtab || !rela || !rela_size) {
        LOGE("dyn info missing");
        return false;
    }

    // 计算重定位项数量
    size_t n = rela_size / sizeof(Elf64_Rela);
    LOGI("Scanning %zu PLT relocations", n);

    // 遍历所有 .rela.plt 表项
    for (size_t i = 0; i < n; i++) {
        Elf64_Rela* r = &rela[i];
        size_t symidx = ELF64_R_SYM(r->r_info);       // 符号索引
        const char* name = strtab + symtab[symidx].st_name;  // 符号名

        // 找到我们想 hook 的目标函数
        if (name && strcmp(name, TARGET_SYM) == 0) {
            uintptr_t got_addr = base + r->r_offset;   // GOT 条目地址
            LOGI("Found symbol %s -> GOT %p", name, (void*)got_addr);

            // GOT 表项里保存的是原始函数地址
            target_fn_t* got_entry = (target_fn_t*)got_addr;
            original_target_fn = *got_entry;
            LOGI("Original fn=%p", (void*)original_target_fn);

            // 修改 GOT 表项前需将该页改为可写
            if (!make_writable(got_entry, sizeof(void*))) return false;

            // 写入我们自己的函数地址
            *got_entry = (target_fn_t)&hooked_target_function;
            LOGI("Patched GOT to %p", (void*)hooked_target_function);
            return true;
        }
    }
    return false;
}

// -----------------------------
// dl_iterate_phdr 的回调函数
// 每个已加载的 so 都会调用一次
// -----------------------------
static int phdr_cb(struct dl_phdr_info* info, size_t sz, void*) {
    (void)sz;
    if (!info->dlpi_name || !info->dlpi_name[0]) return 0;

    // 提取 so 名称（去掉路径）
    const char* name = strrchr(info->dlpi_name, '/');
    if (name) name++; else name = info->dlpi_name;

    LOGI("Inspected: %s", name);

    // 匹配我们目标 so（libcombined.so）
    if (strcmp(name, COMBINED_SO) == 0) {
        LOGI("Matched combined: %s", info->dlpi_name);

        // 找到目标 so 的 ELF 头信息并处理其 PLT 重定位
        process_relocations_64(
                (uintptr_t)info->dlpi_addr,
                reinterpret_cast<const Elf64_Phdr*>(info->dlpi_phdr),
                info->dlpi_phnum
        );
    }
    return 0; // 继续遍历
}

// -----------------------------
// 安装 hook（核心流程）
// -----------------------------
static void install_hook() {
    LOGI("Installing PLT hook...");
    // 遍历进程中已加载的 ELF（so），执行 phdr_cb
    dl_iterate_phdr(phdr_cb, nullptr);
    LOGI("PLT hook installed");
}

// -----------------------------
// 异步延迟安装 hook（避免目标 so 尚未加载）
// -----------------------------
static void* delayed(void*) {
    sleep(1); // 等待 1 秒，确保 libcombined.so 已加载
    install_hook();
    return nullptr;
}

// -----------------------------
// 构造函数：so 加载时自动执行
// -----------------------------
__attribute__((constructor))
static void onload() {
    // 创建一个后台线程延迟执行 hook
    pthread_t t;
    pthread_create(&t, nullptr, delayed, nullptr);
    pthread_detach(t);
    LOGI("plthook constructor executed");
}

```

### dl_iterate_phdr(遍历加载的so)

> 遍历当前进程中加载的所有ELF模块(.so / 主程序)

```c++
// external/cronet/tot/third_party/llvm-libc/src/include/llvm-libc-types/struct_dl_phdr_info.h
struct dl_phdr_info {
  ElfW(Addr) dlpi_addr; // so加载基地址
  const char *dlpi_name; // so名称
  const ElfW(Phdr) * dlpi_phdr; // 对应ELF的 PHT
  ElfW(Half) dlpi_phnum;  // PH的数量

};


// bionic/libc/bionic/dl_iterate_phdr_static.cpp
int dl_iterate_phdr(int (*cb)(struct dl_phdr_info* info, size_t size, void* data), void* data) {
  ElfW(Ehdr)* ehdr = reinterpret_cast<ElfW(Ehdr)*>(&__executable_start);

  if (memcmp(ehdr->e_ident, ELFMAG, SELFMAG) != 0) {
    return -1;
  }

  // Dynamic binaries get their dl_iterate_phdr from the dynamic linker, but
  // static binaries get this. We don't have a list of shared objects to
  // iterate over, since there's really only a single monolithic blob of
  // code/data, plus optionally a VDSO.

  struct dl_phdr_info exe_info;
  exe_info.dlpi_addr = 0;
  exe_info.dlpi_name = NULL;
  exe_info.dlpi_phdr = reinterpret_cast<ElfW(Phdr)*>(reinterpret_cast<uintptr_t>(ehdr) + ehdr->e_phoff);
  exe_info.dlpi_phnum = ehdr->e_phnum;
  exe_info.dlpi_adds = 0;
  exe_info.dlpi_subs = 0;

  const TlsModules& tls_modules = __libc_shared_globals()->tls_modules;
  if (tls_modules.module_count == 0) {
    exe_info.dlpi_tls_modid = 0;
    exe_info.dlpi_tls_data = nullptr;
  } else {
    const size_t kExeModuleId = 1;
    const StaticTlsLayout& layout = __libc_shared_globals()->static_tls_layout;
    const TlsModule& tls_module = tls_modules.module_table[__tls_module_id_to_idx(kExeModuleId)];
    char* static_tls = reinterpret_cast<char*>(__get_bionic_tcb()) - layout.offset_bionic_tcb();
    exe_info.dlpi_tls_modid = kExeModuleId;
    exe_info.dlpi_tls_data = static_tls + tls_module.static_offset;
  }

  // Try the executable first.
  int rc = cb(&exe_info, sizeof(exe_info), data);
  if (rc != 0) {
    return rc;
  }

  // Try the VDSO if that didn't work.
  ElfW(Ehdr)* ehdr_vdso = reinterpret_cast<ElfW(Ehdr)*>(getauxval(AT_SYSINFO_EHDR));
  if (ehdr_vdso == nullptr) {
    // There is no VDSO, so there's nowhere left to look.
    return rc;
  }

  struct dl_phdr_info vdso_info;
  vdso_info.dlpi_addr = 0;
  vdso_info.dlpi_name = NULL;
  vdso_info.dlpi_phdr = reinterpret_cast<ElfW(Phdr)*>(reinterpret_cast<char*>(ehdr_vdso) + ehdr_vdso->e_phoff);
  vdso_info.dlpi_phnum = ehdr_vdso->e_phnum;
  vdso_info.dlpi_adds = 0;
  vdso_info.dlpi_subs = 0;
  vdso_info.dlpi_tls_modid = 0;
  vdso_info.dlpi_tls_data = nullptr;
  for (size_t i = 0; i < vdso_info.dlpi_phnum; ++i) {
    if (vdso_info.dlpi_phdr[i].p_type == PT_LOAD) {
      vdso_info.dlpi_addr = (ElfW(Addr)) ehdr_vdso - vdso_info.dlpi_phdr[i].p_vaddr;
      break;
    }
  }
  return cb(&vdso_info, sizeof(vdso_info), data);
}
```





## CMakeLists.txt(SO编译配置)

```cmake
cmake_minimum_required(VERSION 3.10)
project("plthook_combined")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 生成 libcombined.so
add_library(combined SHARED combined.cpp)

# hook 库
add_library(plthook SHARED plthook.cpp)

# 链接库
target_link_libraries(combined
        android
        log)

target_link_libraries(plthook
        android
        log
        dl)

```



## MainActivity(调用SO)

```kotlin
package com.example.plthookdemo

import android.app.Activity
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import com.example.plthookdemo.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {
    // native wrapper that calls into libcaller -> target_function
    external fun callTarget(v: Int): Int
    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.i("PLT_TEST", "Calling callTarget(5) ...")
        val r = callTarget(5)
        Log.i("PLT_TEST", "callTarget returned: " + r)

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.sampleText.text = "123"
        binding.sampleText.setOnClickListener {
//            testHook()
            val r = callTarget(5)
            Log.i("PLT_TEST11", "callTarget returned: " + r)
        }
    }

    companion object {
        init {
            // 加载顺序很重要：先加载 target + caller，然后加载 plthook
                System.loadLibrary("combined");
                System.loadLibrary("plthook");
        }
    }
}
```



## 总结

PLT Hook 的核心是：**通过改写导入方的 GOT 表项，将外部符号调用重定向到自定义函数**。  
它并不是“全能拦截”，而是基于 ELF 动态链接路径（PLT/GOT）生效，因此更适合做跨 so 的函数调用拦截与行为观测。

在 Android 场景下，要把 PLT Hook 从“能跑”做到“可用”，关键在于三点：

- **理解边界**：只能稳定拦截经过导入表的调用；库内直调、inline/LTO、`-Bsymbolic` 等路径可能拦不到。  
- **处理细节**：区分 `REL/RELA` 与重定位类型（如 `JUMP_SLOT/GLOB_DAT`），并正确解析 `.dynamic` 信息。  
- **保证稳定性**：关注 `RELRO`/`mprotect`、安装时机（`NOW/LAZY`）、线程安全、幂等与可回滚能力。



#### 相关要点

- **标准流程**：找目标 so -> 解析动态段 -> 匹配符号重定位项 -> 改 GOT -> 保存原函数并验证调用链。  
- **高频追问**：为什么有些函数 hook 不到？（因为调用不经过导入表，或被优化/符号绑定策略改变）  
- **架构差异**：`arm64` 常见 `RELA`，`arm32` 常见 `REL`。  
- **与 Inline Hook 对比**：PLT Hook 侵入低、兼容性好但覆盖有限；Inline 覆盖广但复杂度和风险更高。  
- **排障思路**：先确认是否命中目标 so/symbol，再看重定位类型、写入权限、old/new 地址与 `errno`。 





一句话概括：**PLT Hook 是“调用路径重定向”技术，价值在于低侵入拦截，难点在于边界识别与工程化稳定性。**



# 相关三方库

[bytedance/bhook](https://github.com/bytedance/bhook/tree/ecb90454a64137c1cde5d9d3866af6999e13e0fd)

[iqiyi/xhook](https://github.com/iqiyi/xhook)

# 参考地址

[字节跳动开源 Android PLT hook 方案 bhook](https://juejin.cn/post/6998403957697544205?from=search-suggest)







