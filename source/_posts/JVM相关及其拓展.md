---
title: JVM相关及其拓展（一）-- JVM内存区域
date: 2018-04-10 15:22:34
tags: JVM
top: 11
---
# 1. JVM内存区域

{% fullimage /images/jvm/jvm_data.png, JVM运行时数据区,JVM运行时数据区 %}
JVM在执行Java程序的过程中会把管理的内存分为若干个数据局域。
- **程序计数器(Program Counter Register)**：一块较小的内存空间，可看作为**当前线程所执行的字节码的行号指示器**。每条线程都需要一个独立的程序计数器，所以为线程私有区域。`没有规定任何OutOfMemoryError情况的区域`。`线程执行Java方法，则记录正在执行的虚拟机字节码指令地址，若为Native方法，则计数器值则为Undefined`

  

- **Java虚拟机栈(VM Stack)**：虚拟机栈是线程私有的，生命周期与线程相同。描述的是**Java方法执行的内存模型**：每个方法在执行时都会创建一个栈帧用于存储局部变量表(存放编译器可知的各种基本数据类型`boolean,byte,char,int,long,float,double,short`,对象引用和returnAddress类型)，操作树栈，动态链接，方法出口等信息。每一个方法从调用直至执行完成的过程，就对应着一个栈帧在虚拟机中从入栈到出栈的过程。这个区域存在两种异常情况：`StackOverflowError：请求栈深度大于虚拟机所允许的深度`，`OutOfMemoryError：无法申请到足够的内存`

  

- **本地方法栈(Native Method Stack)**：本地方法栈是线程私有的，虚拟机执行Native方法的服务，和虚拟机栈类似存在两个异常情况。

- **Java堆(Heap)**：JVM管理内存中最大的一块。是被所有线程共享的一块区域，在虚拟机启动时创建。唯一目的`存放对象实例`，几乎所有对象实例都在这里分配内存。Java堆是垃圾收集器管理的主要区域，因此很多时候也被称为”GC堆”。如果在堆中没有内存完成实例分配，并且堆也无法再扩展时，则抛出OutOfMemoryError异常。

- **方法区(Method Area)**：方法区与Java堆一样，是各个线程共享的内存区域。**用于存储已被虚拟机加载的类信息、常量、静态变量、即时编译器编译后的代码等数据**。同Java堆一样会抛出OutOfMemoryError异常。

- **运行时常量池(Runtime Constant Pool)**：运行时常量池是方法区的一部分。Class文件中除了有类的版本、字段、方法、接口等描述信息外，还有一个是常量池（存放编译器生成的各种字面量和符号引用）。有一个重要特征是具有动态性，运行期也可以将新的常量放入池中。受到方法区内存的限制，也会抛出OutOfMemoryError异常。

- **直接内存(Direct Memory)**：不属于虚拟机运行时数据区的一部分。

> 拓展：
> -  程序计数器，虚拟机栈，本地方法栈随着线程生命周期变化，生则生，死则死。
> -  程序计数器，虚拟机栈，本地方法栈不需要过多考虑内存回收问题，随着方法结束或者线程结束时，内存随着就会回收。
> 堆和栈在操作系统内的区别？
> 都是内存存放数据的地方。具体区别在于：
> - 栈内存：主要用于存放**基本数据类型和局部变量**；在代码块中定义一个变量时，便会在栈中为这个变量分配内存空间，超过变量的作用域后块空间就会被自动释放掉。
> - 堆内存：用于存放**‌运行时创建的对象**，比如通过`new`创建出的对象，需要交由GC来对其进行回收。

简述：JVM的内存区域主要有以下5类：

1. 程序计数器：线程私有，当前线程所执行的字节码的行号指示器
2. 虚拟机栈：线程私有，存放基本数据类型、对象引用和returnAddress类型，会发生内存溢出异常
3. 本地方法栈：线程私有，为JVM中用到的Native方法服务，会发生内存溢出异常
4. Java堆：线程共享，存放对象的实例，也是GC回收管理器的主要区域，会发生内存溢出异常
5. 方法区：线程共享，存储已被JVM加载的类信息、常量、静态变量、即时编译后的代码等数据，会发生内存溢出异常




# 2.HotSpot虚拟机对象创建，布局以及访问
## 对象的创建
   在语言层面上，创建对象只需要一个`new`关键字。
   在虚拟机中，分为以下几步：
- **遇到一条new指令时，先去检查指令对应参数是否在常量池中可以定位到一个符号的引用，并且检查指令的参数是否已被加载、解析和初始化过。若无则需要执行相应的类加载过程。**
- **类加载检查通过后，将为新生对象分配内存。**对象所需的内存大小在类加载完成后便可确定，这块内存由Java堆中划分出来。内存的分配方式由Java堆中内存是否规整决定（`已使用的内存和空闲内存是否相互交错`）。规整则使用 **指针碰撞**（`把指针向空闲空间挪动对象大小的距离`），不规整则使用**空闲列表**（`虚拟机内维护一个列表用来记录内存块中的可用区域，然后找到一块足够大的空间划分给对象实例`）。
- **处理并发安全问题。**除了如何分配内存，还需要考虑虚拟机中对象创建是非常频繁的行为，就会涉及到线程安全。解决这个问题有两种方案：
  - 对分配内存空间的行为进行同步处理
  - 把内存分配的动作按照线程划分在不同的空间之中进行，即每个线程在Java堆中预先分配一小块内存，称为`本地线程分配缓存(TLAB)`。哪个线程需要分配内存就在哪个TLAB上分配，只有TLAB用完了，才同步申请另一块内存。
- **内存分配完成后，虚拟机将需要分配到的内存空间都初始化为零值（不包括对象头）。**这一步操作保证了对象的实例字段在Java代码中可以不赋值就直接使用，程序能访问到这些字段的数据类型所对应的零值。
- **虚拟机对对象进行设置，将`类的元数据信息、对象的哈希码、对象的GC分代年龄信息`存入对象头中。**
- **执行init方法初始化。**从虚拟机角度来说，对象已经产生完成，从Java方面来说才刚刚开始，要等到new指令执行并\<init\>方法执行后，把对象按照意愿初始化后，真正可用的对象生成完毕。

{%fullimage /images/Jvm对象创建过程.png,Jvm对象创建过程,Jvm对象创建过程%}

## 对象的内存布局
在HotSpot虚拟机中，对象在内存中存储的布局可以分为3块区域：`对象头(Header)`、`实例数据(Instance Data)`和`对齐填充(Padding)`
### 对象头
**存储自身的运行时数据**

| 存储内容 | 标志位 | 状态 |
|---|---|---|
| 对象哈希码、对象分代年龄 | 01 | 未锁定 |
| 指向锁记录的指针 | 00 | 轻量级锁定 |
| 指向重量级锁的指针 | 10 | 膨胀(重量锁) |
| 空，不需要记录信息 | 11 | GC标记 |
| 偏向线程ID，偏向时间戳，对象分代年龄 | 01 | 可偏向 |

**类型指针**
对象指向它的类元数据的指针，虚拟机通过这个指针来确定这个对象是哪个类的实例。如果对象为一个Java数组，则对象头中还必须有一块用于记录数组长度的数据，因为虚拟机可以通过普通Java对象的元数据信息确定Java对象的大小，但是从数组的元数据中无法确定数组的大小。

### 实例数据
里面是对象真正存储的有效信息，也是在程序代码中所定义的各种类型的字段内容。存储顺序会受到虚拟机分配策略参数和字段在Java源码中定义顺序的影响。在分配策略中，相同宽度的字段总是会被分配在一起。
### 对齐填充
并非必然存在的，也没有特别的含义。仅仅起着占位符的作用。当实例数据部分没有对齐时，需要对齐填充来补全。
## 对象的访问
Java程序需要通过栈上的reference数据来操作堆上的具体对象。目前主流的访问方式是`句柄访问`和`直接指针访问`。
- 使用句柄访问：Java堆中会划分出一块内存来作为句柄池，`refrence中存储的对象就是对象的句柄地址`，而句柄中包含了对象实例数据与类型数据各自的具体地址信息。
	**句柄访问的最大好处是refrence中存储的是稳定的句柄地址，在对象被移动时只会改变句柄中的实例数据指针，refrence本身不会有修改。**
 {% fullimage /images/jvm/get_object_by_handle.png, alt,流程图 %}
- 使用直接指针访问：Java堆对象需要考虑如何放置访问类型数据的相关信息，而`refrence中存储的直接就是对象地址`。
	**直接访问的最大好处是速度快，节省了一次指针定位的时间开销，在Java HotSpot虚拟机中很常用。**
 {% fullimage /images/jvm/get_object_direct.png, alt,流程图 %}