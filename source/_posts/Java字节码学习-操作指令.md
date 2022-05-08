---
title: Java字节码学习-操作指令
date: 2019-11-14 15:12:37
tags: Java
top: 10
---

> 对常见的字节码操作指令进行整理，方便日后进行查询。为了在字节码应用时可以进行合理利用。

JVM采用基于栈的架构，操作指令由**操作码和操作数**组成。`操作码`决定要完成的操作，`操作数`指参加运算的数据及其所在的单元地址。

操作码：一个字节长度（0～299），操作码个数不能不能超过256

操作数：一条指令可以包含0个或多个操作数。

> 为了提升传输效率，减少数据量。字节码指令放弃了 操作数对齐，减少了填充与间隔符号的使用。但是如果操作码处理超过一个字节的数据时，必须在运行时从字节码里构建出具体的数据结构，占用CPU，导致解释执行字节码会损失部分性能。



## 操作指令（按功能分类）

**大部分数据类型相关指令，都没有支持byte、short、char数据类型，并且没有任何支持boolean类型的指令。**

编译器会在编译期或运行期将`byte、short`转为**带符号拓展的int型数据**，将`char、boolean`转为**零位拓展的int型数据**。

### 加载存储指令

{% fullimage /images/字节码-操作指令-加载指令.jpg,字节码-操作指令-加载指令,字节码-操作指令-加载指令%}

{% fullimage /images/操作指令-加载指令.png,操作指令-加载指令,操作指令-加载指令%}

> 主要用于*局部变量与操作数栈交换数据*、*常量装载到操作数栈*。

#### 局部变量与操作数栈交换数据

##### load

> 加载局部变量表指定位置的相应类型变量到操作数栈栈顶

`iload、iload_<n>`：将`第n+1`个`int`变量推到栈顶

`lload、lload_<n>`：将`第n+1`个`long`变量推到栈顶

`fload、fload_<n>`：将`第n+1`个`float`变量推到栈顶

`dload、dload_<n>`：将`第n+1`个`double`变量推到栈顶

`aload、aload_<n>`：将`第n+1`个`引用`变量推到栈顶



##### store

> 将操作数栈栈顶的相应类型数据保存到局部变量的指定位置

`istore、istore_<n>`：将栈顶的`int`类型数值保存到`n+1`的局部变量中

`lstore、lstore_<n>`：将栈顶的`long`类型数值保存到`n+1`的局部变量中

`fstore、fstore_<n>`：将栈顶的`float`类型数值保存到`n+1`的局部变量中

`dstore、dstore_<n>`：将栈顶的`double`类型数值保存到`n+1`的局部变量中

`astore、astore_<n>`：将栈顶的`引用`类型数值保存到`n+1`的局部变量中



`XXX_<n>`，其中`n`表示非负整数，范围在0~3之间，超过这个范围则表示成`XXX n`

例 `iload 4`，将第5个`int`类型数值推到栈顶。



####  常量装载到操作数栈

##### push

> 相应类型常量数值放入栈顶

`bipush`：单字节的常量值(-128~127)进栈
例：	`static final int a = 123`

`sipush`：短整型常量值(-32768~32767)进栈
例：	`static final int a =456`

对应上述操作码的操作数为 **常量的数值**，例 `bipush 123`



##### const

> 将相应的数值类型放入栈顶，无对应操作数

`iconst_m1、iconst_<n>`：`int`型常量进栈，`m1`指代-1，n为`1~5`

例 `int a = -1`,若`int a=6 `则对应`bipush 6`

`lconst_0,lconst_1`：`long`型常量进栈，只有0L、1L有效

例 `long a = 0L`

`fconst_0,fconst_1,fconst_2`：`float`型常量进栈，只有0F、1F、2F有效

例 `float a = 0f`

`dconst_0,dconst_1`：`double`型常量进栈，只有0D、1D有效

例 `double a = 0d`

`aconst_null`：对象`null`进栈，只有`null`有效

例 `String a = null`



##### ldc

> 把数值常量或String型常量从常量池中推送至栈顶，`操作数为常量池索引`

**所有不是通过new方式创建的String都是放在常量池中的。**

`ldc`：`int、float或String型常量`推送至栈顶

例 `int a = 66666`，对应`ldc #18`，18代指了常量池中的位置，*索引为8位*

`ldc_w`：`int、float或String型常量`推送至栈顶，**宽索引**

例`宽索引`：表示常量池的行号，索引的字段长度。*索引为16位*

`ldc2_w`：`long、double型常量`推送至栈顶，**宽索引**

例 `doubla a = 2.3`，对应`ldc2_w #19`，#19表示了`double 2.3`



### 操作数栈管理指令

{% fullimage /images/操作指令-操作数栈管理指令.png,操作指令-操作数栈管理指令,操作指令-操作数栈管理指令%}

> 对操作数栈进行直接操作：**出栈、复制栈顶元素、交换栈顶元素**

#### 操作数栈栈顶出栈

##### pop

> 操作数栈栈顶元素出栈 **不能是long、double**，只支持一个字节的数据

##### pop2

> 操作数栈栈顶元素出栈 ，支持两个字节的数据，例如`long/double`一个数值，其他类型是两个数值

#### 操作数栈栈顶复制

以下三个操作指令支持的数据类型 不包括**long、double**，其他类型例如`int、returnAddress、refrence`都支持

##### dup

> 复制栈顶一个字节长度的元素，复制后的数据重新压入栈顶

原始操作数栈    …->value3->value2->value1

dup操作后         …->value3->value2->value1->value1

例 `int a = 0; a= ++a;` 对应字节码为 `dup`

##### dup_x1

> 复制栈顶一个字节长度的元素，弹出栈顶两个字节长度元素后，压入复制的数据，再将弹出的两个字节长度元素压入栈顶

原始操作数栈    …->value3->value2->value1

dup_x1操作后    …->value3->value1->value2->value1

##### dup_x2

> 复制栈顶一个字节长度的元素，弹出栈顶三个字节长度元素后，压入复制的数据，再将弹出的三个字节长度元素压入栈顶

原始操作数栈    …->value3->value2->value1

dup_x2操作后    …->value1->value3->value2->value1



<br>

以下三个操作指令支持所有数据类型

##### dup2

> 复制栈顶两个字节长度的元素，复制后的数据重新压入栈顶

原始操作数栈    …->value3->value2->value1

dup2操作后        …->value3->value2->value1->value2->value1

若value1为`long/double` …->value3->value2->value1->value1

例 `long a = 0L; a= ++a;` 对应字节码为 `dup2`

##### dup2_x1

> 复制栈顶两个字节长度的元素，弹出栈顶三个字长的数据，压入复制的数据，再将弹出的三个字长的数据压入栈顶

原始操作数栈    …->value3->value2->value1

dup2_x1操作后  …->value2->value1->value3->value2->value1

若value1 为`long/double` 	…->value3->value1->value2->value1

##### dup2_x2

> 复制栈顶两个字节长度的元素，弹出栈顶四个字长的数据，压入复制的数据，再将弹出的四个字长的数据压入栈顶

原始操作数栈    …->value4->value3->value2->value1

dup2_x2操作后  …->value2->value1->value4->value3->value2->value1

若value1、value2为`long/double`  …->value4->value3->value2->value1->value2->value1

#### 操作数栈栈顶元素交换

##### swap

> 栈顶的两个数值互换，且不能是**long、double**

原始操作数栈    …->value3->value2->value1

swap操作后		 …->value3->value1->value2



### 对象操作指令

{% fullimage /images/操作指令-对象操作指令.png,操作指令-对象操作指令,操作指令-对象操作指令%}

> 主要是操作对象（主要指类）的创建与访问，例如`新建对象实例，访问对象实例变量与类变量等`

#### 创建对象实例

##### new

> 创建新对象实例

例 `String a = new String("new")` 对应指令为 `new`

#### 访问类变量（实例变量、静态变量）

##### getField

> 从常量池中获取对象的字段，并压入栈顶

例 `getField #18`，取出常量池中索引为18的字段

##### putField

> 给从常量池中获取的对象赋值

例 `putField #18`，给常量池索引为18的字段赋值

##### getStatic

> 获取类的静态(static)变量，并压入栈顶

例 `getStatic #19`，取出常量池索引为19的静态变量

##### putStatic

> 给类的静态(static)变量进行赋值

例 `putStatic #19`，给常量池索引为19的静态变量赋值

#### 对象类型操作

##### checkcast

> 类型转换检测

##### instanceof

> 判断类型是否相符，操作数为常量池索引

例 `str instanceof String` 对应`instanceof #13`

### 数组操作指令

{% fullimage /images/数组操作指令.png,操作指令-数组操作指令,操作指令-数组操作指令%}

> 主要是对数组对象的操作，包括**创建数组、加载数组元素、获取数组长度**等

#### 创建数组

##### newarray

> 创建数组且**类型必须是基础数据类型**，操作数为**基础数据类型**

例 `int[] a = new int[2]` 对应操作指令为 `newarray int`

##### anewarray

> 创建数组且**类型为引用类型**，操作数为**常量池类名索引**

例 `String[] a=new String[2]` 对应操作指令为 `anewarray #18`

##### multianewarray

> 创建多维度的数组，操作数为**常量池类名索引以及维度**

例`int[][] a = new int[2][3]` 对应操作指令为 `multianewarray #2,2`代表类来自索引为2的类名以及维度为2，有两层嵌套

#### 数组元素与操作数栈交换数据

> 由于数组也是对象，故前缀为`a`，

##### (X)aload

> 数组元素加载到操作数栈栈顶，X可以为**b(byte)、c(char)、s(short)、i(int)、l(long)、f(float)、d(double)、a(refrence)**

例 `int c = a[2]`，对应操作指令为

```java
        41: aload_0 //加载数组对象
        42: iconst_2 //设置取索引为2的值
        43: iaload //获取对应值
```

##### (X)astore

> 操作数栈的值给对应数组元素赋值，X可以为**b(byte)、c(char)、s(short)、i(int)、l(long)、f(float)、d(double)、a(refrence)**

例 `a[5] = 5`，对应操作指令为

```java
  aload_0 //加载数组对象
  iconst_5 //设置常量为5
  bipush 6 //赋值对应元素为6
  iastore  //保存赋值
  
```



#### 数组长度

##### arraylength

> 获取对应数组的长度，无操作数



### 方法操作指令

{% fullimage /images/操作指令-方法操作指令.png,操作指令-方法操作指令,操作指令-方法操作指令%}

> 主要是对方法进行操作，包括**方法调用、方法返回**

#### 方法调用

> 调用类中不同的方法指令

##### invokevirtual

> 调用实例方法，操作数为**常量池的索引，索引的值为 方法符号引用** 属于静态分派

例 `System.out.println("aaa")`对应操作指令为

```java
 invokevirtual #9                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
```



##### invokestatic

> 调用类的静态(static)方法，操作数为**常量池的索引，索引的值为 方法符号引用** 

例 `Test.test(int a,boolean b)` 对应操作指令为

```java
 invokestatic  #11                 // Method test:(IZ)V
```



##### invokeinterface

> 调用接口方法，运行时搜索由特定对象所实现的接口方法，并找到合适的进行调用，操作数为**常量池的索引，索引值为 接口方法符号引用**。还有个`count`???

例`new ArrayList<String>().add("sd");` 对应操作指令为

```java
invokeinterface #16,  2           // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
```



##### invokespecial

> 调用一些需要特殊处理的实例方法，包括**实例初始化方法、私有方法、父类方法**。操作数为 **常量池的索引且值为 方法符号引用**



##### *invokedynamic？？

> Java7中引入，在Java8中允许调用
>
> 调用动态链接方法 ，用于`lambda`表达式中

//TODO 拓展一节

#### 方法返回

> 方法的返回指令根据返回数据类型进行区分

##### ireturn

> 返回数据类型为 `boolean、byte、short、char、int`时调用

例 `int getResult()`，对应操作指令为`ireturn`

##### lreturn

> 返回数据类型为`long`

##### freturn

> 返回数据类型为`float`

##### dreturn

> 返回数据类型为`double`

##### areturn

> 返回数据类型为`reference`

##### return

> 返回`void`



### 控制转移指令

{% fullimage /images/操作指令-控制转移指令.png,操作指令-控制转移指令,操作指令-控制转移指令%}

> 让JVM有条件或无条件的从指定位置的指令继续执行程序，而不是当前控制转移指令的下一条，从而达到**控制流程**目标。

#### 条件跳转指令

> 对栈顶元素进行判断，操作数为**可能跳转的指令行号**

##### ifeq、ifne

> 若栈顶int元素值【=0或!=0】则跳转

```java
a==0 //ifne 11
a!=0 //ifeg 11
```

##### iflt、ifle

> 若栈顶int元素值【小于(<)0或小于等于(<=)0】则跳转

```java
a>=0 //iflt 11
a>0 //ifle 11
```

##### ifgt、ifge

> 若栈顶int元素值【大于(>)0或大于等于(>=)0】则跳转

```java
a<=0 //ifgt 11
a<0 //ifge 11
```

##### ifnull、ifnotnull

> 若栈顶引用值为【==null或!=null】则跳转

```java
a==null //ifnotnull 11
a!=null //ifnull 11
```



#### 无条件跳转指令

##### goto

> 无条件跳转指定位置，操作数为**指定行数**

还有`goto_w`，无条件跳转不过`w`表示宽索引

##### jsr（Java7及以后不使用）

> Java 6之前 finally语句生成，跳转到子例程序

##### ret（Java7及以后不使用）

> Java 6之前 返回由指定局部变量所给出的指令地址

##### athrow

> 显式抛出异常

#### 复合条件跳转指令

##### tableswitch

> 通过索引访问跳转表，并跳转

例

```java
switch (a) {
            case 0:
                return 0;
            case 1:
                return 1;
            case 2:
                return 2;
            case 5:
                return 5;
            default:
                return -1;
        }
```

对应操作指令为

```java
 tableswitch   { // 0 to 5
                       0: 40
                       1: 42
                       2: 44
                       3: 48
                       4: 48
                       5: 46
                 default: 48
            }
```

其中源码未出现的3,4都跳转默认指令行数

##### lookupswitch

> 通过键值访问跳转表，并跳转

例

```java
switch (a) {
            case -5:
                return 0;
            case 1:
                return 1;
            case 2:
                return 2;
            case 5:
                return 5;
            default:
                return -1;
        }
```

对应操作指令为

```java
 lookupswitch  { // 4
                      -5: 44
                       1: 46
                       2: 48
                       5: 50
                 default: 52
            }
```



> 为何后续`switch`可以支持`String`类型，由于在字节码的过程中会被转换成`str.hashcode`，根据对应的`hashcode`进行判断。



#### 比较指令

> 比较操作数栈栈顶两个元素的大小，然后根据比较结果压入操作数栈中

##### dcmpg、dcmpl

> 比较栈顶两double类型值，
>
> **前者大，1入栈<br>都相等，0入栈<br>后者大，-1入栈<br>存在NaN，则-1入栈**

例

```java
double da = 1f;
double db = 2f;
double dc = Double.NaN;
double dd = 1f;

System.err.println(da>db); //dcmpl  (-1)  ifle
System.err.println(db<da); //dcmpg  ( 1)  ifge
System.err.println(da=dd); //dcmpl  ( 0)  ifne
System.err.println(da>dc); //dcmpl  (-1)  ifle
System.err.println(da<dc); //dcmpg  (-1)  ifge
```



##### fcmpg、fcmpl

> 比较栈顶两float类型值，
>
> **前者大，1入栈<br>都相等，0入栈<br>后者大，-1入栈<br>存在NaN，则-1入栈**

例

```java
float fa = 1f;
float fb = 2f;
float fc = Float.NaN;

System.err.println(fa>fb); //fcmpl  (-1)  ifle
System.err.println(fa<fb); //fcmpg  (-1)  ifge
System.err.println(fb<fa); //fcmpg  ( 1)  ifge
System.err.println(fa>fc); //fcmpl  (-1)  ifle
System.err.println(fa<fc); //fcmpg  (-1)  ifge
```



##### lcmp

> 比较栈顶两long类型值
>
> **前者大，1入栈<br>都相等，0入栈<br>后者大，-1入栈**



上述的比较指令是只针对于`float、double、long`型的数据，剩下的还有`int、refrence`

##### if_icmpeq、if_icmpne

> 栈顶两int类型值是否相等

```java
int a =1;
int b =2;

a==b //if_icmpne 11
a!=b //if_icmpeq 11
```



##### if_icmplt、if_icmple

> 栈顶两int类型是否前者【小于(<)或小于等于(<=)】后者

```java
int a =1;
int b =2;

a>=b //if_icmplt 11
a>b //if_icmple 11
```



##### if_icmpgt、if_icmpge

> 栈顶两int类型是否前者【大于(>)或大于等于(>=)】后者

```java
int a =1;
int b =2;

a<=b //if_icmplt 11
a<b //if_icmple 11
```



##### if_acmpeq、if_acmpne

> 栈顶两引用类型值是否相等

```java
String sa = "1";
String sb = "2";

sa==sb //if_acmpne 11
sa!=sb //if_acmpeq 11
```

### 类型转换指令

{% fullimage /images/操作指令-类型转换指令.png,操作指令-类型转换指令,操作指令-类型转换指令%}

> 对两种不同类型的数值进行转换。**一般用于实现用户代码中的显式类型转换操作，或者用来解决字节码指令集不完备的问题（例如byte、short、char、boolean需要转换为int）。**

#### 宽化类型转换

> **存储长度由小到大转换，无需显式的转换指令，并且是安全的操作。**
>
> 转换范围由小到大为：**int << long << float << double**

##### i2l、i2f、i2d

> `int`转换为`long、float、double`

##### l2f、l2d

> `long`转换为`float、double`

##### f2d

> `float`转换为`double`

#### 窄化类型转换

> **存储长度由大到小转换，需要显式的调用转换指令，很可能导致精度丢失。**
>
> 转换范围由大到小为：**double >> float >> long >> int**

##### d2f、d2l、d2i

> `double`转换为`float、long、int`

##### f2l、f2i

> `float`转换为`long、int`

##### l2i

> `long`转换为`int`

##### i2b、i2s、i2c

> `int`转换为`byte、short、char`。通过将栈顶`int`类型截断成对应类型，然后将对应类型通过`符号拓展`成int型。

`i2b`：`byte`占8位，就是取出int转换二进制后的低八位的补码即为结果

`i2s`：`short`占16位，取出int转换二进制后的低16位的补码即为结果

`i2c`：数字转换字符后，会当做`ASCII`编码来处理

> 当遭遇到`Float.NaN或者Double.NaN`就转换为对应类型的0！

### 运算指令

{% fullimage /images/操作指令-运算指令.png,操作指令-运算指令,操作指令-运算指令%}

> 对操作数栈的两个数值进行运算，并将结果重新存入操作数栈中。
>
> 只支持**整数类型与浮点类型**数据的运算。

#### 通用运算指令

> 包括一些**加、减、乘、除、求余、取反**等操作

##### Xadd

> 运算指令 ——加法，栈顶两数相加，结果入栈
>
> X为`i(int)、l(long)，f(float)、d(double)`

##### Xsub

> 运算指令 ——减法，栈顶两数相减，结果入栈
>
> X为`i(int)、l(long)，f(float)、d(double)`

##### Xmul

>运算指令 ——乘法，栈顶两数相乘，结果入栈
>
>X为`i(int)、l(long)，f(float)、d(double)`

##### Xdiv

>运算指令 ——除法，栈顶两数相除，结果入栈
>
>X为`i(int)、l(long)，f(float)、d(double)`

##### Xrem

> 运算指令 ——求余，栈顶两数取模，结果入栈
>
> X为`i(int)、l(long)，f(float)、d(double)`

例`a % b` 对应操作指令为`rem`

##### Xneg

> 运算指令 ——取反，栈顶数据取反，结果入栈
>
> X为`i(int)、l(long)，f(float)、d(double)`



#### 其他运算指令

> 包括一些**移位运算、按位布尔运算、自增运算**

##### Xshl、Xshr、Xushr

> 运算指令——移位运算，栈顶数据进行移位运算结果入栈
>
> X为`i(int)、l(long)`

`Xshl`：左移运算，**丢弃最高位，往左移位，右侧空位补0**

例 `5 << 2`，5 转换二进制为`0101` 向左移2位后，得到`01 0100`值为20

`Xshr`：算术右移运算，**丢弃最低位，往右移位，左侧空位补符号位**

例`5>>2`，5 转换二进制为`0101` ，向右移2位后，得到`0001`值为1

`Xushr`：无符号右移，逻辑右移运算，**丢弃最低位，向右移位，左边空出来的位置补0**

例`-7>>>2`，-7转换二进制为`11111111 11111111 11111111 11111001`，右移2位得到`00111111 11111111 11111111 11111110`得到`1073741822`

**在不大于自身数值类型最大位数的移位时，一个数左移n位，就是将这个数乘以2的n次幂；一个数右移n位，就是将这个数除2的n次幂，然后取整。**

> 若需要移位的数值大于32，等价于移位数和32取余得到的结果为移位数。

##### Xand、Xor、Xxor

> 运算指令——按位布尔运算，栈顶数据进行按位运算后结果入栈
>
> X为`i(int)、l(long)`

`Xand`：按位与运算，**都为1就是1，否则为0——同1为1**

例`4 & 2`，4的二进制为`0100`，2的二进制为`0010`，结果为`0000`得0

`Xor`：按位或运算，**有1得1，否则为0——有1为1**

例`4 | 2`，4的二进制为`0100`，2的二进制为`0010`，结果为`0110`得6

`Xxor`：按位异或运算，**数值相同为0，否则为1——同0异1**

例`4 ^ 2`，4的二进制为`0100`，2的二进制为`0010`，结果为`0110`得6



##### iinc

> 运算指令——自增运算。 指定数据进行自增后结果入栈。
>
> 操作数有两个，一个是操作数栈的索引(对应需要自增的数值)，一个是自增的步长(一次加多少)

例`b+=2`，对应操作指令为`iinc 1,2`，`1`对应的是操作数栈索引，`2`对应的是自增步长



> 还有非运算(`~`)，不过字节码中转换成为了`x xor -1`

例`~4` ，即`4 xor -1`，4的二进制为`0000 0100`，-1的二进制为`1111 1111`，结果为`1111 1011`再取一次补码得到`1111 1101`得到`-5`

### 同步与异常指令

#### 同步指令

{% fullimage /images/操作指令-同步指令.png,操作指令-同步指令,操作指令-同步指令%}

> 同步指令集序列，由`synchronized语句块`进行控制

##### monitorenter

> 进入并获得对象监视锁(**加锁**)

##### monitorexit

> 释放并退出对象监视锁(**释放锁**)



`synchronized`锁分为两种：**对象锁**、**类锁**。

未被锁定的对象的该计数器为0，当一个线程获得锁（执行`monitorenter`）后，该计数器自增变为 1 ，当同一个线程再次获得该对象的锁的时候，计数器再次自增。当同一个线程释放锁（执行`monitorexit`指令）的时候，计数器再自减。当计数器为0的时候。锁将被释放，其他线程便可以获得锁。

`synchronized`修饰方法时，通过`ACC_SYNCHRONIZED`进行隐式加锁。

#### 异常指令

{% fullimage /images/操作指令-异常指令.png,操作指令-异常指令,操作指令-异常指令%}

>显式抛出异常以及`throw`语句都是通过异常指令实现

##### athrow

> 显示的抛出异常
>
> *在JVM中，`catch`代码不由字节码指令来实现，需要通过异常表(Exception Table)表示*

关于`finally`块中的指令采用的是每个分支代码中冗余一份，就是`try`，n个`catch`方法中字节码部分都会冗余finally的代码。

如果出现未显式捕获的异常则通过`athrow`指令抛出。如果出现已声明捕获的异常，在前面的字节码中就会执行，不会走到`athrow`指令行数。

## 拓展知识

### 堆、栈的区别

> 最主要区别是：
>
> `栈内存`用来存储 **局部变量和方法调用**
>
> `堆内存`用来存储 **Java中的对象。无论是成员变量、局部变量、类变量 他们指向的对象都存储在堆内存中。**
>
> 额外补充：如果局部变量是 基本数据类型 ，那么局部变量的值 直接存储于栈中；如果局部变量是 对象 ，那么该变量的引用存在栈中，但是对象存储于堆中。

- `栈内存` 线程私有，`堆内存` 所有线程共享
- `栈内存` 抛出``StackOverflowError`，`堆内存` 抛出`OutOfMemoryError`

### 栈的组成

> 栈 主要用于存储 **栈帧**，栈帧也叫`过程活动记录`，一种用于支持JVM调用/执行程序方法的数据结构，每个方法被调用时都会创建一个栈帧存储所需的数据信息，`栈帧伴随方法的调用而创建，执行结束而销毁`。
>
> **每一个方法从调用开始到执行完成都对应着一个栈帧在JVM里面从入栈到出栈的过程。**

`栈帧`主要存储了以下四部分：

- 局部变量表：`用于存储方法参数和定义在方法体的局部变量，这些包含了各类原始数据类型、对象引用、returnAddress类型。`局部变量表的大小在编译期就已经确定，对应的是字节码中的`Code-LocalVariableTable`属性。

  局部变量表中最小的存储单元是`slot`，除了`double,float`占用两个`slot`，其他都是一个`slot`。

  `slot`是可以被重用的，用于`节省栈帧的占用空间`，当某个变量执行完毕时，它对应的`slot`就可以被其他变量所使用。

- 操作数栈：`通过入栈、出栈操作来完成一次数据访问。本质是个**临时数据存储区域**。`操作数栈的大小在编译期就已经确定，对应的是字节码中的`Code-maxStack`

  > 当一个方法开始执行时，操作数栈为空，在执行过程中由于`出栈、入栈`操作，往操作数栈中写入和提取内容。

- 动态链接：`表示指向运行时常量池中该栈帧所属方法的引用，为了支持当前方法的代码能够实现 动态连接`。主要用于`将编译期无法被确定的方法调用，在运行期符号引用转换为调用方法的直接引用`。

  - 静态链接：被调用的目标方法在编译期可知，且运行期保持不变时，那么这种情况下调用方法的符号引用转换为直接引用的过程为静态链接。

  > 两者主要区别在于：
  >
  > - 静态链接可以在类加载的解析阶段（编译期）将符号引用转为直接引用
  > - 动态链接在每一次运行时期（运行期）将符号引用转为直接引用

- 方法返回值：`记录方法被调用的位置，可以在方法执行结束后回到被调用处继续向下执行`。

  有两种方式可以退出方法调用：
  
  - 正常调用：执行引擎遇到了返回的字节码指令(例如`ireturn(int,boolean,byte,short,char)、lreturn(long)、freturn(float)、dreturn(double)、areturn(refrence)，return(void)`)，这时将返回值传递给上层的方法调用者。
  
  - 异常调用：在执行过程中遇到了异常，并且没有处理该异常，就会导致方法退出并且不会返回值。
  
  一般方法正常退出该值为`调用者的PC计数器的值`。

### 零位拓展与符号位拓展

符号位拓展

> 需要使用更多内存存储一个有符号数时，需要保持符号位一直在第一位。
>
> 当对一个负数进行符号位拓展时，**把拓展之后数的高位全部设置为1**；
>
> 例如二进制表示-1，10000001，需要使用十六位则表示为 1111111110000001，高位全补1
>
> 当对一个正数进行符号位拓展时，**把拓展之后数的高位全部设置为0**；
>
> 例如二进制表示1，00000001，需要使用十六位则表示为 0000000000000001，高位全补0

零位拓展

> 无论高位多少，拓展后全补0

**有符号数向其他类型进行转换时，需要用到符号位拓展；无符号数向其他类型进行转换时，使用零位拓展。**

### 二进制相关知识

`原码`：对于二进制值，最高位为符号位，0表示正数，1表示负数，剩余部分表示正值。

`补码`：对于二进制值，正数的补码为本身；负数的补码除符号位按位取反，末位加一。

`反码`：对于二进制值，正数的反码为本身；负数的反码除符号位按位取反。

**负数的二进制为 正数的补码= 正数的反码+1**

**补码还原原码为 补码的补码为原码**

例 `byte a = (byte)300;` 按照上述规则

- 300转换二进制为`01 1001 0000`
- 截取低八位为`1001 0000`
- 转换补码为 `1111 0000`为`-112`

| 基本类型 | 占字节数 | 最小值  | 最大值  |
| -------- | -------- | ------- | ------- |
| boolean  |          |         |         |
| char     | 16bit    |         |         |
| byte     | 8bit     | -2^7    | 2^7-1   |
| short    | 16bit    | -2^15   | 2^15-1  |
| int      | 32bit    | -2^31   | 2^31-1  |
| long     | 64bit    | -2^63   | 2^63-1  |
| float    | 32bit    | IEEE754 | IEEE754 |
| double   | 64bit    | IEEE754 | IEEE754 |
| void     | -        |         |         |



## 参考链接

[字节码指令](http://gityuan.com/2015/10/24/jvm-bytecode-grammar/)

[Java二进制指令代码解析](http://www.blogjava.net/DLevin/archive/2011/09/13/358497.html)

[java虚拟机 JVM字节码 指令集 bytecode 操作码 指令分类用法 助记符](https://www.cnblogs.com/noteless/p/9556928.html)

[Jvm官方文档](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.10.1.9.monitorenter)