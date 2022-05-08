---
title: Android性能优化-内存优化详解
date: 2020-03-23 21:04:05
tags: Android
typora-root-url: ../
top: 10
---



## 内存的概念

内存是计算机中最重要的部件之一，是硬盘与CPU之间沟通的桥梁，所有程序都是运行其上，会对程序的性能造成很大的影响。



## Why 内存优化？

### 减少Crash

> 减少因为内存问题引起的Crash，其中最典型的就是**OOM**

### 运行流畅

> 当内存紧张时，就会导致频繁触发`GC`。当触发`GC`时，所有线程都要停止，会导致所有运行被搁置，导致运行卡顿。

### 延长后台运行时间

> Android会按照特定的机制进行进程清理，按照`前台进程-可见进程-服务进程-后台进程-空进程`的顺序优先清理后面的进程。
>
> 当应用占用内存过多时，切到后台时有更高的几率被Kill。

## 内存管理机制

### 系统层面

<!--进程优先级-->

`LowMemoryKiller`

> 每隔一段时间检查一次，当系统剩余可用内存较低时，便会触发杀进程的策略。
>
> 按照`进程优先级`来回收资源，如果进程优先级一致的情况下，会优先Kill消耗内存更多的进程。

#### 进程优先级

##### 前台进程(Foreground Process)

> **优先级最高的进程**，正处于用户交互的进程。
>
> *优先级最高，基本不会被回收。*

判断条件：

- 持有一个与用户交互的Activity
- 持有一个Service(`startForeground() / 与可交互Activity绑定`)

##### 可见进程(Visible Process)

> 不含任何前台组件，但是依然可见
>
> *除非前台进程内存耗尽，否则不会轻易终止。*

判断条件：

- 持有一个处于`pause`状态的Activity，例如显示了一个Dialog
- 持有一个与可见Activity绑定的Service

##### 服务进程(Service Process)

> 可能在播放音乐或者下载文件
>
> *除非系统内存不足，否则系统尽量维持服务进程运行*

判断条件：

- 持有一个Service，且是通过`startService()`启动的

##### 后台进程(Background Process)

> 处于用户不可见的状态，例如切到后台的应用
>
> *通过LruCache进行管理，系统会适当清理后台进程。占用内存越大越容易被清理*

判断条件：

- 持有一个处于`stop`状态的Activity，但尚未调用`onDestroy()`

##### 空进程(Empty Process)

> 不包含任何活跃的应用组件

主要为了`加快下次启动进程的速度`。

### 进程层面

> 每个进程都是一个单独的虚拟机，使用的内存空间都是独立的。

不管是哪种虚拟机类型{% post_link Android中的GC分析-Dalvik和ART虚拟机 Dalvik和Art虚拟机%}，当分配对象所占用的内存空间不足时会触发GC。

#### GC类型

- `GC_FOR_MALLOC`：表示在堆上分配对象时内存不足触发的GC
- `GC_CONCURRENT`：当应用程序的堆内存达到一定量时，系统自动触发的GC操作
- `GC_EXPLICIT`：调用了`System.gc()`时触发的GC
- `GC_BEFORE_OOM`：在准备抛出`OOM`异常前进行的GC

#### 内存分配过程

//TODO



## 内存监听

### 获取系统内存信息

> Android提供了`ActivityManager.getMemoryInfo()`去获取系统的内存信息。

```kotlin
private fun getSystemMemoryInfo():ActivityManager.MemoryInfo{
        val am: ActivityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return ActivityManager.MemoryInfo().also { mi ->
            am.getMemoryInfo(mi)
        }  
}
```

最终得到的就是`MemoryInfo`对象

```java
    public static class MemoryInfo implements Parcelable {
      //系统的可用内存
      public long availMem;
      //系统的总内存
      public long totalMem;
      //可用内存阈值，低于阈值会判断为低内存状态
      public long threshold;
      //当前是否处于 低内存状态
      public boolean lowMemory;
    }
```



### 获取应用内存信息

> 通过`ActivityManager`也可以获取到应用可用的内存信息

```kotlin
        fun getAppMemoryInfo(context: Application) {
            val runtime = Runtime.getRuntime()
            val maxMemory = runtime.maxMemory().toMB() //应用可申请的最大内存

            val am: ActivityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val canUseMemory = am.memoryClass //应用使用到的内存
            val maxUseMemory = am.largeMemoryClass //应用使用的最大内存
          
        }
```



##### 实时获取应用使用内存

上述操作获取的都是系统为应用配置的属性，但是无法实时的获取应用使用内存

```kotlin
        fun getAppMemoryUsage(context: Application):Float {
            var mem = 0.0f
            val am: ActivityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            try {
                var memInfo: Debug.MemoryInfo? = null
                //28 为Android P
                if (Build.VERSION.SDK_INT > 28) {
                    // 统计进程的内存信息 totalPss
                    memInfo = Debug.MemoryInfo()
                    Debug.getMemoryInfo(memInfo)
                } else {
                    //As of Android Q, for regular apps this method will only return information about the memory info for the processes running as the caller's uid;
                    // no other process memory info is available and will be zero. Also of Android Q the sample rate allowed by this API is significantly limited, if called faster the limit you will receive the same data as the previous call.
                    val memInfos: Array<Debug.MemoryInfo>? = am.getProcessMemoryInfo(intArrayOf(Process.myPid()))
                    if (memInfos != null && memInfos.isNotEmpty()) {
                        memInfo = memInfos[0]
                    }
                }
                val totalPss = memInfo!!.totalPss
                if (totalPss >= 0) {
                    // Mem in MB
                    mem = totalPss / 1024.0f
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            return mem
        }
```

其中的`memInfo`结构如下：

```java
    public static class MemoryInfo implements Parcelable {
      //dalvik 使用的内存 Pss表示实际使用的物理内存
      public int dalvikPss;
      //非共享内存，该部分内存不会被释放
      public int dalvikPrivateDirty;
      //共享内存，该部分内存不会被释放
      public int dalvikSharedDirty;
      //native堆使用的内存 Pss表示实际使用的物理内存
      public int nativePss;

      //除上述两者外使用的内存 Pss表示实际使用的物理内存
      public int otherPss;
      
      //基本可以判断为应用使用的全部内存
        public int getTotalPss() {
            return dalvikPss + nativePss + otherPss + getTotalSwappedOutPss();
        }
      
    }
```

### 获取应用内存状态

实现需要获取状态的`Activity`或`Application`的`onTrimMemory()`

```java
void onTrimMemory(level:Int){
  //根据对应Level去执行操作
  when(level){
    
  }
  
}
//对应的level主要有以下几种
    @IntDef(prefix = { "TRIM_MEMORY_" }, value = {
           //系统内存非常低，且应用位于 LRU的边缘，极有可能被回收
            TRIM_MEMORY_COMPLETE,
           //系统内存非常低，且应用位于 LRU的中间，有可能被回收
            TRIM_MEMORY_MODERATE,
           //系统内存非常低，应用刚进入后台，回收可能性低
            TRIM_MEMORY_BACKGROUND,
           //应用处于后台
            TRIM_MEMORY_UI_HIDDEN,
           //应用正常运行，但是系统内存非常低
            TRIM_MEMORY_RUNNING_CRITICAL,
           //应用正常运行，但是系统内存非常低
            TRIM_MEMORY_RUNNING_LOW,
           ////应用正常运行，但是系统内存有点低
            TRIM_MEMORY_RUNNING_MODERATE,
    })
```



## 优化目标

**减少内存的占用。**

内存问题大致可以分为两类：

- 无用的数据依然占用内存——**内存泄漏**
- 有用的数据占用内存过多——**图片加载/内存抖动**

上述两类问题最后都容易导致**内存溢出(OOM)**

### 内存泄漏

> 一般采用`可达性分析`做为内存对象是否存活的判断方式，通过与`GC Roots对象`是否有关联判断是否需要进行回收。
>
> `内存泄漏`：当前的对象已经不再使用，但是依然被`GC Roots`对象所引用，导致无法进行回收，依然占用内存。

#### 触发原因

- `静态变量导致`

  静态变量会一直持有外部类的引用，导致外部类对象无法被回收。

- `单例模式导致`

  单例传入了外部参数，例如传入`Activity的context`，就会持有对`Activity`的引用

- `属性动画导致`

  播放无限循环动画时，没有在Activity关闭时及时停止，导致View持有了Activity

- `Handler导致`

  Handler的Message会持有Handler的引用，而Handler持有Looper的引用，Looper由`sThreadLocal 这个静态对象`管理。所以导致内存泄漏的`GC Roots`对象为`sThreadLocal`。

- `匿名内部类/非静态内部类`

  `匿名内部类`会隐式持有对所在Activity的引用

- `资源对象没关闭`

  一般资源对象都使用了缓冲，不及时关闭的话，缓冲依然存在。

### 图片加载

> 图片资源基本是占用内存最多的，如果使用图片不当的话就很容易会导致OOM的发生。
>
> 本地或者网络图片最终都会转换成`bitmap`。

#### 支持图片格式

目前移动端Android平台原生支持的图片格式主要有以下几种：

- `JPEG`

  > 广泛使用的有损压缩图像标准格式，不支持透明度和多帧动画，只有`RGB`三个通道。

- `PNG`

  > 无损压缩图像标准格式，支持完整的透明通道。支持`ARGB`四个通道

- `WebP`

  > 支持`有损压缩`和`无损压缩`，也支持透明度。
  >
  > 在Andorid4.0之后添加的系统支持，在4.3之后支持了无损和透明的WebP展示。



#### Bitmap占用内存

> **所有像素的内存占用总和。**

可以通过`getByteCount()`和`getAllocationByteCount()`去获取Bitmap所占用的内存。

一般情况下Bitmap占用内存大小计算公式为：

**图片长度 x 图片宽度 x 单位像素占用的字节数**。

其中`单位像素占用的字节数`来自`颜色深度`。

> 颜色深度：每个像素显示的颜色数，显示的越多，色彩就越丰富。
>
> Android系统提供如下几种：
>
> | 颜色深度                  | 每个像素占用内存 |
> | ------------------------- | ---------------- |
> | ARGB_8888(`默认颜色深度`) | 4 byte / 32 bit  |
> | ARGB_4444                 | 2 byte / 16 bit  |
> | RGB_565                   | 2 byte / 16 bit  |
> | ALPHA_8                   | 1 byte / 8 bit   |
>
> 实际应用中建议使用`ARGB_8888(需要透明度)`和`RGB_565(不需要透明度)`
>
> 但`RGB565`在部分场景下显示效果较差，例如`大图展示`。



##### 加载网络或者本地图片(非Drawable文件夹)

占用内存大小：`图片宽度 * 图片长度 * 单位像素占用字节数`。

假设`100 * 100`且颜色深度为`ARGB_8888`的本地图片，转换Bitmap占用大小为`100 * 100 * 4`。

##### 加载Drawable下文件资源(/res/drawable/)

占用内存大小：`图片宽度 * 图片长度 * (inTargetDensity / inDensity) ^ 2 * 单位像素占用字节数`。

`inDensity`：图片所在文件夹对应的密度

`inTargetDensity`：当前系统的屏幕密度



##### 占用内存存储位置

在Android 2.3 之前 占用内存是在 native上分配的，并且生命周期不可控，还需要用户自己回收。

在Android 2.3 - 7.1 之间，占用内存位于Java堆上

在Android 8.0 之后，占用内存重新在native上分配，并且不需要主动执行回收。



### 内存抖动

> 短时间内有大量的对象被创建与回收，有短时间内快递的上升和下落的趋势，内存呈锯齿状。
>
> *此时频繁触发GC，造成卡顿，甚至OOM*

#### 触发原因

1. 频繁创建对象，例如在`for循环`创建对象

#### 解决方案

1. 尽量避免在循环体中创建对象
2. 尽量不要在`onDraw()`中创建对象
3. 对于能够复用的对象，考虑使用`对象池`进行缓存以便复用

### 内存溢出

> `OutOfMemoryError`，应用申请的内存超出单个应用的最大可用内存。`可用最大内存配置位于/system/build.prop下的 dalvik.vm.heapgrowthlimit`

#### 触发原因

1. 内存泄漏积累到一定量之后导致OOM
2. 一次性申请很多内存，例如`一次创建大的数组或者显示大型文件(图片)`

### 其他问题

##### 数据容器

使用了`HashMap`之类的容器，针对每一个键值对，都需要额外的`Entry`对象

##### 强引用

针对某些低频使用对象使用强引用，当GC触发时不能去回收这些对象

##### 数据相关

使用SP存储数据时，第一次读取时都需要将所有数据缓存到内存中，有时为了一些数据，就需要缓存整个SP。

##### 缓存

针对一些大量重复使用对象，但是很快就要被替代，导致频繁发生GC。

## 优化工具

主要是针对`内存泄漏`场景的优化分析。

### Lint分析

主要是扫描静态代码，从代码实现方面进行内存泄漏分析。

识别不太准确且覆盖率不高，**不推荐使用**。

### Memory Profiler

> AS 提供的性能分析工具，包含了CPU、内存、网络以及电量的分析信息。
>
> 可以实时观测应用的内存使用情况，用于查看是否发生内存抖动(上下波动明显)，内存泄漏(切换Activity时内存明显上升)
>
> 一般情况下会结合下面的`MAT`一起使用。

#### ![Memory-Profiler.png](/images/Memory-Profiler.png)



主要有以下作用：

1. 实时图表展示应用内存使用量
2. 用于识别内存泄漏、内存抖动等
3. 提供捕获堆转储、强制GC以及查看内存分配详情



![堆转储.png](/images/Memory堆转储)



多次点击强制GC后，再点击`堆转储`，等待一会儿会得到`hprof`文件，如果想用MAT查看该文件，还需要执行一次转换。

```shell
cd platform-tools //切换Android SDK目录
./hprof-conv XX.hprof mat.hprof
```

转换得到的`mat.hprof`就可以通过MAT打开。

### Memory Analyzer Tool

> `Memory Profiler`只能查看对应内存的分配，不能判断是否发生了内存泄漏。
>
> `MAT`可以提供完整的`Java Heap`分析功能，并可以生成对应的内存分配报告以及分析内存问题。

#### 如何使用

使用Mat打开的上一步生成的`mat.hprof`文件，打开后会显示一个预览页。

预览页上主要显示以下组件：

- `Histogram`

  列举内存中所有`实例类型对象`和`个数以及大小`，并在顶部的`regex`区域支持`正则表达式`查找。

  主要显示以下内容：

  - `Shallow Heap`：对象自身占用的内存
  - `Retained Heap`：对象自身占用的内存 + 对象引用对象所占用内存
  - `Objects`：对象个数

- `Dominator Tree`

  列举`最大的对象及其依赖存活的Object`。相比`Histogram`可以更方便的看出引用关系

- `Top Consumers`

  通过`图形`的方式列出`占用内存比较多的对象`

- `Leak Suspects`

  列出`有内存泄漏的地方`

#### 排查方式

1. 找到当前Activity(`任何猜测可能发生内存泄漏的类`)

   通过顶部的`Regex`输入具体类名，或使用`group by package`查找对应包下的类

2. 在`Histogram`选择对应类的`List Objects`的`with incoming reference`就可以查看类的实例

   - `with incoming reference`：哪些对象引用了它
   - `with outgoing reference`：它引用了哪些对象

3. 看到实例后，右键点击，选择`Path to GC Roots`的`exclude all phantom/weak/soft etc references`

   排除掉`虚 / 弱 / 软`引用，剩下的就是强引用

4. 根据引用链分析是否发生内存泄漏

   

#### 高级使用

有两个hprof文件中，通过`Compare Basket`进行比较，可以快速生成对比结果，直接进行对应实例对象的比较。



#### hprof文件介绍

{% post_link Hprof文件解析%}



### LeakCanary

{% post_link Android性能优化-LeakCanary%}

## 优化技巧

### 图片高效加载方式

图片的主要载体形式为`Bitmap`，一般通过`BitmapFactory.decodeFile()或`BitmapFactory.decodeResource()去进行加载。

```java
//加载本地文件
BitmapFactory.decodeFile(filePath, new BitmapFactory.Options());
//加载res资源文件
BitmapFactory.decodeResource(getResources(),resId,new BitmapFactory.Options());
```

其中最主要的就是`BitmapFactory.Options`。通过设置其中的参数进行高效加载

```java
public static class Options {
    public Options() {
        inScaled = true;
        inPremultiplied = true;
    }
    ...      
   public Bitmap inBitmap; //用于实现Bitmap的复用
   public Bitmap.Config inPreferredConfig = Bitmap.Config.ARGB_8888;  //默认颜色深度 ARGB_8888
   public int inSampleSize;  //采样率 
   public boolean inJustDecodeBounds; //只解析边界，可以得出图片的宽高
   public boolean inDither;  //是否开启抖动
   public int inDensity; // 图片所属文件夹对应的dpi
   public int inTargetDensity;  // 目标设备屏幕的dpi           
   public boolean inScaled;    //是否支持缩放
   public int outWidth;   //图片的原始宽度
   public int outHeight;  //图片的原始高度
   ...
}
```

#### Options关键参数

##### inPreferredConfig

> 根据需求选择合适的`颜色深度`，可以有效减少占用内存。

实质用的就是上面介绍的[颜色深度](#Bitmap占用内存)

```kotlin
        val options = BitmapFactory.Options()
        options.inPreferredConfig = Bitmap.Config.ARGB_4444
```

##### inJustDecodeBounds

> 是否去加载图片。
>
> - 设置`true`：只会去加载图片的原始宽高信息，但不会真正加载图片到内存。
> - 设置`false`：图片加载到内存中

```kotlin
        val options = BitmapFactory.Options()
        options.inJustDecodeBounds = true //只加载布局
        BitmapFactory.decodeFile(fileName, options)
        val picWidth = options.outWidth //加载图片的宽度
        val picHeight = options.outHeight //加载图片的高度
```

一般配合`inSampleSize`使用，可以提前设置`采样率`



##### inDensity/inTargetDensity

> `inDensity`默认表示`图片资源文件夹的densityDpi`
>
> `inTargetDensity`默认表示`设备的densityDpi`

上面讲到`加载Drawable下文件资源`时，计算占用内存大小时，需要用到上述两个参数。

所以可以通过调整这两个参数，优化一部分的图片内存占用。

##### inSampleSize

> 设置图片的采样率，同时作用于图片的宽和高

`inSampleSize`取值总是`2的指数`，如果传进来的值不为`2的次方`，就会向下取整并取到`2的次方`的值来代替。

```java
public static Bitmap decodeSampledBitmapTromResource(Resource res,int rresId,int reqWidth,int reqHeight){
  final BitmapFactory.Options options = new BitmapFactory.Options();
  options.inJustDecodeBounds = true;
  
  BitmapFacory.decodeResource(res,resId,options);
  options.inSampleSize = calculateInSampleSize(options,reqWidth,reqHeight);
  options.inJustDecodeBounds = false;
  return BitmapFactory.decodeResource(res,resId,options);
}

public static int calculateInSampleSize(BitmapFactory.Options options,int reqWidth,int reqHeight){
  final int height = options.outHeight;
  final int width = options.outWidth;
  int inSampleSize = 1;
  
  //不断 /2 计算得出一个 合适的值
  if(height > reqHeight || width > reqWidth){
     final int halfWidth = width /2;
     final int halfHeight = height/2;
     while((halfHeight / inSampleSize) >= reqHeight 
           && (halfWidth / inSampleSize) >= reqWidth){
       inSampleSize = inSampleSize << 1;
     }
  }
  return inSampleSize;
}

//使用示例
iv.setImageBitmap(decodeSampledBitmapTromResource(getResources(),R.drawable.bitmap,100,100))
```

### 使用优化的数据容器

**可以使用`SparseArray`和`ArrayMap`替换`HashMap`。**

如果`key`为int，可以直接使用`SparseArray`

### AutoBoxing的处理

核心就是**基础数据类型转换成对应的复杂类型**，例如`int <=> Integer`。

在自动装箱发生时，每次都会产生一个新的对象，就会导致更多的内存占用和性能开销。

**尽量使用基础数据类型，减少自动装箱。**

#### 减少使用枚举类型

一般情况下使用枚举类型的`dex size`是普通常量定义的`dex size`的13倍以上，同时运行时的内存分配，一个`enum`值的生命也会消耗至少20Bytes。

**建议使用`IntDef`和`StringDef`替代枚举类型。简单的枚举的话，可以直接使用静态常量代替。**

[Android 中的 Enum 到底占多少内存](https://www.liaohuqiu.net/cn/posts/android-enum-memory-usage/)

#### 内存复用

- 资源复用：通用的字符串、颜色定义、简单页面布局的复用(`<merge>、<include>`)
- 视图复用：使用ViewHolder实现ConvertView复用
- 对象池：创建对象池，实现复用逻辑，对相同类型的数据使用同一块内存空间。*不要使用new Message()而是使用Message.obtain()以复用Message对象*
- Bitmap复用：使用`inBitmap`属性告知BitmapDecoder尝试使用已经存在的内存区域。*在Android 4.4之前只能重用相同大小的Bitmap内存，4.4之后的只要后来的Bitmap比之前的小即可。*

#### 可用内存过低主动清理

通过实现`onTrimMemory()`或`onLowMemory()`在其中去执行`释放资源`的操作以减少内存占用。


## 自动化内存检测

[](https://github.com/hehonghui/mmat/blob/master/README.md)

![img](/images/20190814160744769.png)

## 参考链接

[管理应用内存](https://developer.android.com/topic/performance/memory)

[探索Android内存优化方法](https://juejin.cn/post/6844903897958449166)

[探索Android内存优化](https://juejin.im/post/5e780257f265da575209652c#heading-6)

[Android 如何获取App内存大小](https://blog.csdn.net/wangbaochu/article/details/45581875)

[内存优化实战秘籍](https://mp.weixin.qq.com/s?__biz=MzUyMDAxMjQ3Ng==&mid=2247491618&idx=1&sn=ec8774712e93ec4a61197648bffd8473&chksm=f9f277f1ce85fee74dbeab1e51a68c19b668dfc63c22a8b5de52953f1cdbc65e8f9377deedfe&mpshare=1&scene=23&srcid=1212w21N5TwHQy6Ea5g3P0fD&sharer_sharetime=1607751741389&sharer_shareid=65073698ab9ac2983b955fa53b4ff585%23rd)

[抖音Android性能优化系列:Java内存优化篇](https://mp.weixin.qq.com/s?__biz=MzI1MzYzMjE0MQ==&mid=2247487267&idx=1&sn=64858e39d3c0ac3b3444213856f0d9a3&chksm=e9d0c4c1dea74dd72482c94f936fa31d5609eff5f09b7ee2405e95eecba7ce00bbbb5657730b&mpshare=1&scene=23&srcid=1222g3BpOggvZ2gUY7fgOwUr&sharer_sharetime=1608602832041&sharer_shareid=65073698ab9ac2983b955fa53b4ff585%23rd)

[MAT使用详解](https://juejin.cn/post/6911624328472133646#heading-11)

