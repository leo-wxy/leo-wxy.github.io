---
title: Java字节码学习
date: 2019-09-24 23:27:38
tags: Java
top: 10
---

<!-- https://tech.meituan.com/2019/09/05/java-bytecode-enhancement.html https://juejin.im/post/5d884c766fb9a06ae76444dc https://www.cnblogs.com/zzlove2018/p/9097885.html -->



{% fullimage /images/字节码结构大纲.png,字节码结构大纲,字节码结构大纲%}

<!-- more -->

> Java的最大特性——**一次编译，到处运行**。Java的`跨平台性`非常强大，如此强大的`跨平台性`主要依赖了两部分：**JVM（执行器）**、**字节码**。
>
> `JVM`：主要是翻译功能，将`字节码`翻译成对应平台的计算机指令。
>
> `字节码`：Java源代码拓展名为`.java`经过编译后变成`.class`文件，该文件中包含的内容就是`字节码`。
>
> 现在大热的`Kotlin`也是通过最终编译成`字节码`实现了与Java的兼容性。

{% fullimage /images/Java运行流程.png,字节码执行过程,字节码执行过程%}

`字节码`由`十六进制值`组成，JVM以字节为单位进行读取。如上图所示，通过Java编译器(`javac`)编译后得到了`.class`文件，里面包含的就是字节码，可通过`javap -verbose`获得完整字节码文件。

获得字节码文件后，就需要交由JVM进行加载。

## JVM类加载机制

{% post_link JVM相关及其拓展-二%}



## 字节码结构分析

先编写一个简单的Java文件，用以分析字节码的基本结构，后续通过拓展方法来展现其他字节码结构。

```java
public class BytecodeDemo {
    int a = 1;
    public static void main(String[] args){
        System.out.println("Hello World");
    }
}

```

通过`javac`编译该类，得到`BytecodeDemo.class`

使用例如`010Editor`或者`VSCode(安装hexdump for VSCode插件)`就可以查看`.class`文件原始代码。

{% fullimage /images/BytecodeDemo字节码.png,字节码,字节码%}

图片中就是一堆十六进制数并按字节为单位进行分割。这些十六进制符号长串是遵守[Java虚拟机规范](https://github.com/waylau/java-virtual-machine-specification)的。

下列结构全部是有规范的，此处规范[参考网址](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html)

### 魔数(magic)

> 占4个字节(u4)，且为固定值**0xCAFEBABE**。用于校验字节码文件是否符合虚拟机规范，符合继续执行。

### 版本号(version)

#### 次版本号(minor_version)

> 占两个字节(u2)，表示**生成字节码文件的次版本号**。

上图中为`0x0000`

#### 主版本号(major_version)

> 占两个字节(u2)，表示**编译该字节码文件的Java版本**，`低版本的虚拟机是无法运行高版本的字节码文件，但高版本虚拟机是兼容低版本编译的字节码文件。`

上图中为`0x0034`。对应实际的Java版本就为`JDK 1.8`

查询本机Java版本号为`java version "1.8.0_181"`符合上述描述。

### *常量池(constant_pool)

#### 常量池数(constant_pool_count)

> 占两个字节(u2)，表示**常量池中常量的数目**

上图中为`0x0026`，转换得到`38`。实际上常量数目为`37`。由于特殊的规定，第0位可以表示**类或接口中未出现的引用**。



#### *常量池数组(constant_pool[])

跟在`常量池数(0x0026)`后面的就是`常量池数组`

> 由`constant_pool_count-1`个`cp_info`结构组成，一个`cp_info`对应一个常量，规范规定了总共有14种类型。

```java
//cp_info结构
cp_info{
   u1 tag;
   u1 info[];
}
```

共14种类型如下：

{% fullimage /images/常量池类型.png,常量池结构,常量池结构%}



`BytecodeDemo`字节码解析出的常量池数据如下：

```java
Constant pool:
   #1 = Methodref          #12.#41        // java/lang/Object."<init>":()V
   #2 = Fieldref           #11.#42        // BytecodeDemo.a:I
   #3 = Fieldref           #43.#42        // LruCache.a:I
   #4 = Fieldref           #11.#44        // BytecodeDemo.b:I
   #5 = Fieldref           #11.#45        // BytecodeDemo.c:I
   #6 = Fieldref           #46.#47        // java/lang/System.out:Ljava/io/PrintStream;
   #7 = String             #48            // Hello World
   #8 = Methodref          #49.#50        // java/io/PrintStream.println:(Ljava/lang/String;)V
   #9 = Methodref          #11.#51        // BytecodeDemo.getResult:(II)I
  #10 = Methodref          #12.#52        // java/lang/Object.clone:()Ljava/lang/Object;
  #11 = Class              #53            // BytecodeDemo
  #12 = Class              #54            // java/lang/Object
  #13 = Class              #55            // java/lang/Cloneable
  #14 = Class              #56            // java/io/Serializable
  #15 = Utf8               a
  #16 = Utf8               I
  #17 = Utf8               b
  #18 = Utf8               c
  #19 = Utf8               <init>
  #20 = Utf8               ()V
  #21 = Utf8               Code
  #22 = Utf8               LineNumberTable
  #23 = Utf8               LocalVariableTable
  #24 = Utf8               this
  #25 = Utf8               LBytecodeDemo;
  #26 = Utf8               main
  #27 = Utf8               ([Ljava/lang/String;)V
  #28 = Utf8               args
  #29 = Utf8               [Ljava/lang/String;
  #30 = Utf8               getResult
  #31 = Utf8               (II)I
  #32 = Utf8               x
  #33 = Utf8               y
  #34 = Utf8               test
  #35 = Utf8               clone
  #36 = Utf8               ()Ljava/lang/Object;
  #37 = Utf8               Exceptions
  #38 = Class              #57            // java/lang/CloneNotSupportedException
  #39 = Utf8               SourceFile
  #40 = Utf8               BytecodeDemo.java
  #41 = NameAndType        #19:#20        // "<init>":()V
  #42 = NameAndType        #15:#16        // a:I
  #43 = Class              #58            // LruCache
  #44 = NameAndType        #17:#16        // b:I
  #45 = NameAndType        #18:#16        // c:I
  #46 = Class              #59            // java/lang/System
  #47 = NameAndType        #60:#61        // out:Ljava/io/PrintStream;
  #48 = Utf8               Hello World
  #49 = Class              #62            // java/io/PrintStream
  #50 = NameAndType        #63:#64        // println:(Ljava/lang/String;)V
  #51 = NameAndType        #30:#31        // getResult:(II)I
  #52 = NameAndType        #35:#36        // clone:()Ljava/lang/Object;
  #53 = Utf8               BytecodeDemo
  #54 = Utf8               java/lang/Object
  #55 = Utf8               java/lang/Cloneable
  #56 = Utf8               java/io/Serializable
  #57 = Utf8               java/lang/CloneNotSupportedException
  #58 = Utf8               LruCache
  #59 = Utf8               java/lang/System
  #60 = Utf8               out
  #61 = Utf8               Ljava/io/PrintStream;
  #62 = Utf8               java/io/PrintStream
  #63 = Utf8               println
  #64 = Utf8               (Ljava/lang/String;)V
```



##### 方法符号引用(CONSTANT_Methodref_info)

> 可用于表示**方法信息包含调用类、名称，入参及返回值类型**
>
> 由三部分组成：
>
> tag(偏移地址): 占1字节 **0x0A**
>
> index(类或接口描述符索引) : 占2字节 例`00 07`
>
> index(名称和类型描述符索引)：占2字节 例`00 17`

字节码文件解析出的整段格式为 `0A 00 07 00 17`

对应常量池 就为 #7，#23 最终执行的是`BytecodeDemo`初始化方法



##### 类或接口符号引用(CONSTANT_Class_info)

> 可用于表示**类的全限定名**
>
> 由两部分组成：
>
> tag(偏移地址): 占1字节 **0x07**
>
> index(全限定名常量项索引) : 占2字节 例`00 1E`

字节码文件解析出的整段格式为 `07 00 1E`

对应常量池 就为 #31 指向`java/lang/Object`



##### 名称和类型描述符索引(CONSTANT_NameAndType_info)

> 可用于表示**方法的名称、入参及返回值类型**
>
> 由三部分组成：
>
> tag(偏移地址): 占1字节 **0x0C**
>
> index(字段或方法 名称常量项索引--常量信息描述符索引) : 占2字节 例`00 0A`
>
> index(字段或方法 描述符索引--常量信息描述符索引)：占2字节 例`00 0B`

字节码文件解析出的整段格式为 `0C 00 0A 00 0B`

对应常量池为 #10 #11 表示 `<init> V`



##### 常量信息描述符索引(CONSTANT_Utf8_info)

> 可用于表示：**文本字符串、类或接口全限定名、字段名称和描述符，方法名称及描述符等常量信息。**
>
> 由三部分组成：
>
> tag(偏移地址): 占1字节 **0x01**
>
> length(字符串长度)：占2字节
>
> bytes(字符串内容)：占`length`字节

字节码文件解析出的整段格式为 `01 00 0B 48 65 6C 6C 6F 20 57 6F 72 6C 64`

字符串长度为11位，对应内容为`Hello World`



##### 参数信息描述符索引(CONSTANT_Fieldref_info)

> 可用于表示**类中的全局变量以及引用其他类中的参数信息**
>
> 由三部分组成：
>
> tag(偏移地址): 占1字节 **0x09**
>
> index(类或接口描述符索引)：占2字节 例`00 06`
>
> index(名称和类型描述符索引)：占2字节 例`00 18`

字节码文件解析出的整段格式为`09 00 06 00 18`

对应内容为：`ByteDemo.a(I)`



### 类访问标志(access_flags)

> 占2字节，紧随`常量池`结构。可用于**表示类或者接口层次的访问信息——Class是类还是接口，是否定义为public，是否为abstract类型。**

具体的标志位以及标志描述如下：

| 类修饰标志     | 标志值 | 描述                                  |
| -------------- | ------ | ------------------------------------- |
| ACC_PUBLIC     | 0x0001 | public类型                            |
| ACC_PRIVATE    | 0x0002 | private类型                           |
| ACC_PROTECTED  | 0x0004 | protected类型                         |
| ACC_STATIC     | 0x0008 | static类型                            |
| ACC_FINAL      | 0x0010 | final类型，表示类不允许被继承         |
| ACC_SUPER      | 0x0020 | 是否允许使用`invokespecail`字节码指令 |
| ACC_INTERFACE  | 0x0200 | 表示该class为一个接口                 |
| ACC_ABSTRACT   | 0x0400 | 表示抽象类                            |
| ACC_SYNTHETIC  | 0x1000 | 这个类不是由用户代码生成              |
| ACC_ANNOTATION | 0x2000 | 表示为注解类型                        |
| ACC_ENUM       | 0x4000 | 表示为枚举类型                        |

**实际的访问标志多是由上述几个标志进行` 或运算`组合而成。**

字节码文件紧随常量池数组后的为 `0x0021`，在上表中无法找出对应的标志，结果是由`ACC_PUBLIC，ACC_SUPER`组合得到。

当前对应的是类所设置的访问标志，后面会讲到`参数(field_info) 、方法(method_info)`中的访问标志，与类中会有些许不同。

### 当前类索引(this_class)

> 占2个字节，指向类的全限定名

字节码文件解析出`00 06`，指向了#6 BytecodeDemo

### 父类索引(super_class)

> 占2个字节，指向父类的全限定名

字节码文件解析出`00 07`，指向了#7 java/lang/Object

### 接口索引(interfaces)

{% fullimage /images/字节码-接口索引结构.png,字节码-接口索引结构,字节码-接口索引结构%}

> 可用于表示**类或接口引用到的接口信息**
>
> 由两部分组成：
>
> interfaces_count(接口引用数量)：占2字节 例`00 02`
>
> interfaces[interfaces_count] (接口名称常量索引)：占2*interfaces_count字节 例`00 0D 00 0E`

```java
.... 
#13 = Class              #55            // java/lang/Cloneable
#14 = Class              #56            // java/io/Serializable
```

字节码文件解析出`00 02 00 0D 00 0E`

对应内容为类实现了`Cloneable、Serializable`两个接口

### 字段表集合(fields)

{% fullimage /images/字节码-字段表结构.png,字节码-字段表结构,字节码-字段表结构%}

> 可用于表示**类或接口声明的变量，包含类级别的变量以及实例变量，但是不包含方法内部声明的局部变量**
>
> 由两部分组成：
>
> fields_count(字段个数)：占2字节 例`00 03`
>
> fields[fields_count] (字段信息)：占n字节，由fields_count个`field_info`组成

```java
field_info{
  u2          		access_flags;
  u2          		name_index;
  u2          		descriptor_index;
  u2          		attributes_count;
  attribute_info	attributes[attributes_count];
}
```

#### 字段访问标志(access_flags)

与上面的`类访问标志`相比基本是一致的，除了以下几项是字段所特有的

| 字段访问标志  | 标志值 | 描述                                                         |
| ------------- | ------ | ------------------------------------------------------------ |
| ACC_VOLATILE  | 0x0040 | 表示volatile，可实现`可见性、有序性`<br>不能完全实现`原子性` |
| ACC_TRANSIENT | 0x0080 | 不参与序列化过程                                             |
| ACC_ENUM      | 0x4000 | 表示 该字段为枚举的一个值                                    |

字节码文件解析出数据为`00 00`,为默认标志

#### 字段名称索引(name_index)

>  占2字节，指向常量池中`CONSTANT_Utf8_info`中的有效索引，表示字段名称

字节码文件解析出数据为`00 0F`，为`a`

#### 字段描述符索引(descriptor_index)

> 占2字节，指向常量池中`CONSTANT_Utf8_info`中的有效索引，表示字段属性

字节码文件解析出数据为`00 10`，为`I`

#### 字段额外属性个数(attributes_count)

> 占2字节，表示字段额外属性个数

字节码文件解析出数据为`00 00`，为0

#### 字段额外属性列表(attributes[attributes_count])

> 占n字节，描述字段的额外属性

字节码文件未解析出该字段

`field_info`支持的额外属性格式如下：

##### 常量值(ConstantValue)

> 由`static、final`关键字定义的常量值，在class文件中才有这个属性。

在类加载过程的`准备`阶段时，会直接由设置的值进行初始化，而不使用默认值，仅限`基本数值类型和String`。

```java
ConstantValue_attribute{
 u2 attribute_name_index;//固定 ConstanValue
 u4 attribute_length;
 u2 constantvalue_index;
}
```

###### 属性名称索引(attribute_name_index)

> 占2字节，指向常量池中`CONSTANT_Utf8_info`中的有效索引，表示属性名称

解析为`00 14`，指向#20 表示`ConstantValue`

###### 属性长度(attribute_length)

> 占4字节，值必定为`00 00 00 02`，表示2

###### 常量值索引(constantvalue_index)

> 占2字节，指向常量池中中的有效索引，表示常量值数值

解析为`00 15`，指向#21，表示了`Integer 3`，即常量值为3

| 字段类型                    | 常量池中类型     |
| --------------------------- | ---------------- |
| long                        | CONSTANT_Long    |
| float                       | CONSTANT_Float   |
| double                      | CONSTANT_Double  |
| int,short,char,byte,boolean | CONSTANT_Integer |
| String                      | CONSTANT_String  |



列举出字节码文件中的一部分字段表信息

```java
00 18 | 00 13 | 00 10 | 00 01 | 00 14 00 00 00 02 00 15
表示为
static final int d = 3
```



### 方法表集合(methods)

{% fullimage /images/字节码-方法表结构.png,字节码-方法表结构,字节码-方法表结构%}

> 可用于表示**类或接口中的方法**
>
> 由两部分组成：
>
> methods_count(方法个数)：占2字节，例如`00 05`
>
> methods[methods_count] (方法信息)：占n字节，由methods_count个`method_info`组成

```java
method_info{
  u2          		access_flags;
  u2          		name_index;
  u2          		descriptor_index;
  u2          		attributes_count;
  attribute_info	attributes[attributes_count];
}
```

#### 方法访问标志(access_flags)

相比于`类访问标志`，多了几项`方法访问标志`

| 字段访问标志     | 标志值 | 描述                                                         |
| ---------------- | ------ | ------------------------------------------------------------ |
| ACC_SYNCHRONIZED | 0x0020 | 方法为`synchronized`类型的，将方法包入到`monitor`中          |
| ACC_BRIDGE       | 0x0040 | 为桥接方法，是编译后自动生成的方法<br>在使用泛型时，编译器自动生成桥接方法用于校验泛型转换实际类型 |
| ACC_VARARGS      | 0x0080 | 声明了可变数量的参数                                         |
| ACC_NATIVE       | 0x0100 | 声明Native方法，不是由Java语言实现的                         |

字节码文件解析出数据为`00 01`,表示`public`

#### 方法名称索引(name_index)

> 占2字节，指向常量池中`CONSTANT_Utf8_info`中的有效索引，表示方法名称

字节码文件解析出数据为`00 13`,指向#19 ,表示`<init>`——初始化方法

#### 方法描述符索引(descriptor_index)

> 占2字节，指向常量池中`CONSTANT_Utf8_info`中的有效索引，表示方法属性

字节码文件解析出数据为`00 14`，指向#20,表示`()V`——没有入参，返回参数类型为`void`

#### 方法额外属性个数(attributes_count)

> 占2字节，表示方法额外属性个数

字节码文件解析出数据为`00 01`，有1个额外属性

#### 方法额外属性列表(attributes[attributes_count])

> 占n字节，描述方法的额外属性信息

字节码文件解析出的数据为`00 15`，指向`Code`

##### *Code

> 描述`method_info`相关信息，**method_info必有一个该属性，除了`native和abstract修饰的方法`**。
>
> `Code_attribute`组成了`Code`。

```java
Code_attribute{
 u2 attribute_name_index;//常量池索引，表示额外属性名称，此处为`Code`
 u4 attribute_length;
 u2 max_stack;//???
 u2 max_locals;//
 u4 code_length;//JVM操作指令个数 0<code_length<65535
 u1 code[code_length];//操作指令信息
 u2 exception_table_length;//异常集合长度
  {
    u2 start_pc;
    u2 end_pc;
    u2 handler_pc;
    u2 vatch_type;
  } exception_table[exception_table_length];
  u2 attributes_count;//Code内部属性个数
  attribute_info attributes[attribute_count];
}
```

###### 属性长度(attribute_length)

> 属性值长度，需要排除`attribute_name_index`以及`attribute_length`6个字节长度，其他的累加起来就得到结果。

###### 最大栈深度(max_stack)

> 最大操作数栈，

###### *局部变量最大空间数(max_locals)

> 描述当前方法的局部变量表。单位为`slot`,`long,double`占两个`slot`，其他类型都占一个`slot`

###### 操作指令集(code[])

> 表示当前方法编译后的字节码操作指令集合

主要内容参照 {% post_link Java字节码学习-操作指令%}

###### 异常表集合(exception_table[])

> 表示当前方法需要声明抛出的异常类型
>
> exception_info{
>  u2 start_pc; //异常判断包裹的起始位置(字节码行号) 指向try{
>  u2 end_pc; //异常判断包裹的结束位置(字节码行号) 指向}catch 不包含该位置
>
>  u2 handler_pc;//异常捕获时 处理的位置(字节码行号)
>  u2 catch_type;//捕获的异常类型 若不为0 则表示为 常量池中对应的索引位置 ；为0则表示 是任意 Throwable
> }

一个方法可以抛出的异常类型遵循三点：

- 抛出的异常是`RuntimeException`类型或其子类
- 抛出的异常是`Error`类型或其子类
- 抛出的异常是`Exception`类型或其子类

###### Code中额外属性(attributes[attributes_size])

> Code区块中的额外属性：主要有以下三种

- 行号表(LineNumberTable)

  > 将Code区的字节码操作指令与源代码行号对应，可以在Debug时定位对应源代码。

- 本地变量表(LocalVariableTable)

  > 包含This和局部变量，之所以每一个方法内部都可以调用this，是因为JVM将this作为方法的第一个参数隐式传入。**若为static方法就没有该特性**

- 栈表(StackMapTable)

  > 提高JVM在类型检查的验证过程的效率

  


### 属性表集合(attributes)

> 存放了在该文件中类或接口定义属性的基本信息
>
> attribute_info {
>
>  u2 attribute_name_index; //属性名称
>
>  u4 attribute_length; //属性值的字节长度
>
>  u1 info[attribute_length]; //属性的详细信息
>
> }

常用额外属性如下，按照可使用场景区分

| 属性               | 含义                                                         | 使用位置                               |
| ------------------ | ------------------------------------------------------------ | -------------------------------------- |
| SourceFile         | 记录和当前字节码对应的源代码文件                             | ClassFile                              |
| InnerClasses       | 记录当前类的所有内部类，包括在方法中定义的内部类             | ClassFile                              |
| EnclosingMethod    | 当且仅当一个类是匿名类或者本地类，该类才会包含该属性         | ClassFile                              |
| ConstantValue      | 每个常量字段(final，静态或实例常量)会包含该属性              | field_info                             |
| Code               | 包含一个方法的栈、局部变量，字节码以及与代码相关属性<br>不会在`abstract`,`native`方法中出现 | method_info                            |
| Exceptions         | 记录方法需要检查的异常类型                                   | method_info                            |
| Depreated          | 表示一种弃用状态                                             | ClassFile<br>method_info<br>field_info |
| LineNumberTable    | 获取字节码指令所对应的源码行号                               | Code                                   |
| LocalVariableTable | 获取方法运行时的局部变量                                     | Code                                   |
| StackMapTable      | 记录类型检查时需要用到的信息，如字节码的偏移量、局部变量的验证类型等 | Code                                   |



## 字节码操作指令

{% post_link Java字节码学习-操作指令%}



##  字节码应用

{% post_link Java字节码学习-应用场景%}



## 附录

### 描述符(Descriptor)

> 定义了字段或方法的类型。
>
> *A *descriptor* is a string representing the type of a field or method. Descriptors are represented in the `class` file format using modified UTF-8 strings*

#### 字段描述符(Field Descriptor)

> 定义了`字段、局部变量、返回参数等类型`的字符串，由`FieldType`组成

主要分为以下三种：

##### 基本类型（BaseType）

| 基本类型 | 对应字符 |
| -------- | -------- |
| byte     | B        |
| char     | C        |
| double   | D        |
| float    | F        |
| int      | I        |
| long     | J        |
| short    | S        |
| boolean  | Z        |

例如：I => int



##### 对象类型（ObjectType）

**L${fullClassName};**

例如：Ljava/lang/Object => Object;

嵌套表达：Ljava/util/List<Ljava/lang/String;>; => List&lt;String&gt;

##### 数组类型（ArrayType）

**[${BaseType}** **[${ObjectType}**

例如：[java/lang/String => String[]

嵌套表达：[[I => int[][]



#### 方法描述符(Method Descriptor)

> 定义了`方法参数、方法返回等信息`的字符串

**(${ParameterDescriptor}) ${ReturnDescriptor}**

##### 参数描述符（ParameterDescriptor）

由`FieldType`组成

##### 返回值描述符（ReturnDescriptor）

由`FieldType`组成或者`VoidDescriptor(代指void)`

例如：(IJD)V => void (int a,long b,double c)

## 参考链接

[The class File Format](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.4)

[字节码增强技术探索](https://tech.meituan.com/2019/09/05/java-bytecode-enhancement.html)

[认识class文件的字节码结构](https://www.jianshu.com/p/e5062d62a3d1)

[字节码格式详解](http://www.blogjava.net/DLevin/archive/2011/09/05/358034.html)