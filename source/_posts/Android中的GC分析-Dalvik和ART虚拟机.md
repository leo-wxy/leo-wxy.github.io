---
title: Android中的GC分析-Dalvik和ART虚拟机
date: 2018-05-13 10:10:54
tags: Android
top: 10
---

<!--如何对JVM进行优化 class文件如何转成dex文件-->

## Dalvik虚拟机

> `Dalvik Virtual Machine`，简称Dalvik VM或者 DVM。DVM是Google专门为Android平台开发的虚拟机，是Android的重要组成部分，支持`dex格式`的Java应用程序运行。
>
> `dex格式`是专门为DVM设计的一种压缩格式，适合内存和处理器速度有限的系统。

{% fullimage /images/Android系统架构图.jpg,Android系统架构图,Android系统架构图%}

从架构图中可知，DVM运行在Android的运行时库层。

### DVM与JVM的区别

#### 基于的架构不同

JVM是基于栈的，意味着需要去栈中读写数据，所需的指令会更多，会导致速度变慢，不适用于性能有限的移动设备。

DVM是基于寄存器的，不会有基于栈的虚拟机在复制数据时，使用大量的出入栈指令，同时指令更紧凑，简洁。

#### 执行的字节码不同

Java类被编译成一个或多个.class文件，并打包成jar文件，JVM通过对应的.class和jar文件获取相应的字节码。

**执行顺序为： .java文件 -> .class文件 -> .jar文件**

DVM运行的是Dalvik字节码，所有的Dalvik字节码由Java字节码转换而来，并被打包到一个dex文件中。DVM通过dex文件执行字节码。

**执行顺序为： .java文件 -> .class文件 -> .dex文件**



**dex文件体积小。Android SDK中有一个`dx`工具将Java字节码转换为Dalvik字节码。**

dx工具对Java类文件重新排序，消除在类文件中出现的所有冗余信息，避免虚拟机在初始化时反复进行文件加载与解析。**消除其中的冗余信息，重新组合成一个常量池，所有类文件共享同一个常量池。由于dx工具对常量池的压缩，使得相同的字符串，常量在dex文件中只出现一次，从而减小文件体积。并把所有的.class文件整合到.dex文件中，减少了I/O操作，加快类查找速度。**

{% fullimage /images/执行的字节码区别.png,执行的字节码区别,执行的字节码区别%}

简单来讲，dex格式文件就是将多个class文件中共有的部分统一存放，取出冗余信息。

#### DVM允许在有限的内存中同时允许多个进程

在Android中的每一个应用都运行在一个DVM实例中，每一个DVM实例都运行在一个独立的进程空间中，独立的进程可以防止在虚拟机崩溃时导致所有程序关闭。

#### DVM由Zygote创建和初始化

每当系统需要创建一个应用程序时，Zygote就会fork自身，快速的创建和初始化一个DVM实例，用于应用程序的运行。

#### DVM拥有共享机制

不同应用之间可以在运行时共享相同的类，拥有更高的效率。JVM不支持这种共享机制，不同的程序都是彼此独立的。

#### JIT编译

`Just In Time Compiler`即时编译器，从Android2.2开始支持了`JIT`。

*JIT会对多次运行的代码进行编译，生成相当精简的本地机器码，这样在下次执行相同的逻辑时，直接使用编译之后的本地机器码，而不是每次都需要编译。*

**每次重新打开应用程序，都需要JIT编译。**



### DVM架构

DVM源码位于dalvik/目录下。

{% fullimage /images/DVM架构.png,DVM架构,DVM架构%}

首先Java编译器的.class文件经过`DX工具`转换为.dex文件，.dex文件由类加载器进行处理，接着解释器根据指令集对Dalvik字节码进行解释、执行，最后交于Linux处理。



### DVM运行时堆

DVM运行时堆使用**标记-清除**算法进行GC，它由两个Space以及多个辅助数据结构组成，两个Space分别是`Zygote Space(Zygote Heap)`和`Allocation Space(Active Heap)`。

`Zygote Space`用来管理Zygote进程在启动过程中预加载和创建的各种对象，`Zygote Space`不会触发GC。所有进程都共享该区域，比如系统资源。

`Allocation Space`是在Zygote进程fork第一个子进程之前创建的，它是一种私有进程，Zygote进程及fork的子进程在`Allocation Space`进行对象分配和释放。

还有以下数据结构：

`Card Table`：记录垃圾信息

`Heap Bitmap`：用来记录上次GC存活的对象，另一个用来记录这次GC存活的对象

`Mark Stack`：遍历存活的对象。



### DVM-GC过程

1. 当GC被触发的时候，会去查找所有活动的对象，这个时候整个程序与虚拟机内部的所有线程就会挂起，可以在较少的堆栈里找到所引用的对象。**回收动作和应用程序是同时执行的(非并发执行)。**
2. GC对符合条件的对象进行标记
3. GC对标记的对象进行回收
4. 恢复所有线程的执行现场继续执行

GC的执行会相当快速，但如果出现频繁GC并且内存资源少，就会导致UI卡顿，掉帧。因为是和应用程序同时执行的。

## ART虚拟机

> ART虚拟机是在Android4.4发布的，用来替换Dalvik虚拟机。5.0之后默认采用ART虚拟机。

### ART和DVM的区别

1. DVM每次运行应用时，字节码都需要JIT编译器译为机器码，会使得应用程序运行效率降低。在ART中采用**AOT(ahead of time Compilation，预编译)**，将字节码预先编译成机器码并存储在本地，这样应用程序每次运行就不需要执行编译了，大大提升运行效率。

   `AOT`优点：

   - 系统性能提升明显
   - 应用启动更快，体验更流畅
   - 设备的耗电量降低

   `AOT`缺点：

   - 使得应用程序安装时间变长，尤其是复杂的应用
   - 由于字节码预先编译成机器码，机器码需要的存储空间会多一些，会占用较多的存储空间

   在Android 7.0中加入了`JIT`，不会把字节码全部编译成机器码，而是在运行中将热点代码编译成机器码。从而缩短安装时间及减少安装空间。

2. DVM是为32位CPU设计的，而ART支持64位并兼容32位

3. ART对GC进行了改进，比如更频繁的执行并行垃圾收集，减少GC暂停次数

4. ART的运行时堆空间划分和DVM不同。

### ART的运行时堆

ART的GC类型有多种，主要分为`Mark-Sweep GC(标记-整理)`和`Compacting GC()`。ART运行时堆得空间根据不同的GC类型也有不同的划分，默认采用CMS方案。

{% fullimage /images/ART运行时堆.png,ART运行时堆,ART运行时堆 %}

### ART-GC过程 - 提高内存使用，减少碎片化

1. GC将会锁住Java堆，扫描并进行标记
2. 标记完毕释放Java堆的锁，并且挂起所有线程
3. GC对标记的对象进行回收
4. 恢复所有线程的执行线程继续运行
5. 重复步骤2-4直到结束

Art改善了GC过程：**将其非并发过程改成了部分并发，还有就是堆内存的重新分配管理。**



DVM内存管理特点：**内存碎片化严重，这也是由于标记-清除算法导致的。**

ART的解决方案：在ART中，它将Java分了一块空间`Large Object Space`，专门用来存放大对象。同时ART引入了`moving collector`技术，将不连续的物理内存块进行对其，对齐后碎片问题得到了很好的解决。

使用`Large Object Space`是因为`moving collector`对大块内存的位移时间过长，需要降低时间并提高内存利用率。



### Apk打包流程

{% fullimage /images/android_apk_build.png,android_apk_build,android_apk_build%}

根据流程图可知，apk打包流程分为7步：

1. 通过aapt打包res资源文件，生成`R.java、resource.asrc,res文件`
2. 处理.aidl文件，生成对应的Java接口文件
3. 通过Java Compiler编译R.java、Java源文件，生成.class文件
4. 通过 dx工具，将.class文件以及三方库中的.class文件合并生成 classes.dex
5. 通过apkbuilder工具，将aapt生成的resource.arsc和res文件、assets文件以及classes.dex一起打包生成apk
6. 通过Jarsigner工具，对上面的apk进行debug或release签名
7. 通过Zipalign工具，将签名后的apk进行对齐处理。(*帮助操作系统更高效率的根据请求索引资源，按着有利于系统处理的方式对apk征用的资源文件进行排列*)

### Apk安装流程

Apk开始安装时会执行以下几步：*(例如安装包名为 com.example.wxy 应用名为Demo的apk)*

- 解析APK中的`AndroidManifest.xml`，解析的内容会被存储到`/data/system/packages.xml`和`/data/system/package.list`中。

- `packages.list`中会指名了该apk包应用的默认存储的位置`/data/data/com.example.wxy`,`package.xml`会包含该应用申请的全新，签名和代码所在位置等信息

  ```xml
  /data/system/packages.list
  com.example.wxy.ipc 10021 1 /data/user/0/com.example.wxy.ipc default:targetSdkVersion=28 3003
  ```

  ```xml
   /data/system/packages.xml   
  <package name="com.example.wxy.ipc" codePath="/data/app/com.example.wxy.ipc-OTMEWujgopdNrmJevxTbaA==" nativeLibraryPath="/data/app/com.example.wxy.ipc-OTMEWujgopdNrmJevxTbaA==/lib" publicFlags="810073926" privateFlags="0" ft="1673c5a86e8" it="1673ae27837" ut="1673c5a8ab8" version="1" userId="10021">
          <sigs count="1" schemeVersion="2">
              <cert index="15" />
          </sigs>
          <perms>
              <item name="android.permission.INTERNET" granted="true" flags="0" />
              <item name="android.permission.ACCESS_NETWORK_STATE" granted="true" flags="0" />
              <item name="com.example.wxy.permission.checkBook" granted="true" flags="0" />
          </perms>
          <proper-signing-keyset identifier="16" />
      </package>
  ```

  标记了一个`userId`，Android系统可以利用该值来管理应用

- 根据`packages.xml`指定的`codePath`，创建一个目录，apk被命名为`base.apk`并拷贝到此，其中lib目录用在存放native库。

- 此时应用就可以运行了。为了提升效率，Android系统在应用安装时还会做些优化操作，把所有可运行的dex文件单独提取放在一块并做些优化。

  - 在DVM时，会使用dexopt把base.apk中的dex文件优化为odex，存储在`/data/dalvik-cache`中.
  - 在ART时，则会使用dex2oat优化成oat文件也存储在该目录下，并且文件名一样，但是文件会大很多，因为ART会把dex优化成机器码，所以运行更快。