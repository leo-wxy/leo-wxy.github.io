---
title: 《Kotlin核心编程》读书笔记-基础语法
date: 2019-06-19 15:51:51
tags: Kotlin
top: 10
---

> 内容摘自《Kotlin核心编程》第2章，在其基础上对一些概念进行拓展了解

本章主要讲Kotlin一些基础语法.

## 类型声明

### 声明变量

*尽可能采用`val`、不可变对象及纯函数来设计程序。*

```kotlin
val a = "Hello World"
或
val a:String = "Hello World"
```

> `val`：引用不可变。反编译后的Java代码中是通过`final`对变量进行修饰。**声明了只读变量，引用对象不可变，但是可以修改对象中的可变成员。**
> 
> Java中的变量默认是可变的，在开发过程中很容易因为使用方式导致变量发生变化出现不可预期的错误。
> 
> `var`：引用可变。**可以让程序的表达显得直接、易于理解。**

上述代码中的`:String`可以进行省略，由于Kotlin提供了更智能的`Smart Casts`，可以对类型自动进行推导，提升开发效率。

### 声明函数返回类型

```kotlin
//代码块函数体
fun sum(x:Int,y:Int) : Int {
  return x+y
}
或
//表达式函数体
fun sum(x:Int,y:Int):Int = x+y

fun show(text:String) /*: Unit*/{
  //do sth
}
```

函数如果没有指定返回值，默认使用`Unit`类型，如果需要指定返回值类型，就必须要进行声明，否则会抛出异常。

> 暂时可以把`Unit`认为类似于Java中的`void`

## 高阶函数与Lambda

Kotlin天然支持部分函数式特征。**函数是头等公民**

> `高阶函数`：以其他函数作为参数或返回值的函数，高阶函数是一种更加高级的抽象机制，极大的增强了语言的表达能力。

### 函数的类型

函数类型的声明格式非常简单：`(Int) -> Unit`

Kotlin的函数类型声明需要遵循以下几点：

- 通过`->`来组织参数类型和返回值类型，左边是参数类型，右边是返回值类型。
- 必须用一个括号来包裹参数类型
- 返回值类型即使是`Unit`也需要显式声明

`高阶函数`支持返回另一个函数：`(Int)->((Int)->Unit)`

### 方法和成员引用

Kotlin存在一种特殊的语法，可以通过`::`实现对于某个类的方法进行引用。

```kotlin
class Book(val bookName:String)

fun main(args:Array<String>){
    val getBook = ::Book
    println(getBook("Kotlin").bookName)
    //println(getBook("Kotlin")::bookName.get()) 输出Kotlin
}
```

`::Book`等价于`new Book()`  `getBook("Kotlin")`等价于`new Book("Kotlin")`

### 匿名函数

> 只能用在函数的参数中，不支持单独定义

Kotlin支持在缺省函数名的情况下，直接定义一个函数。

```kotlin
//empty其实就是一个入参为 String 出参为 Boolean的函数
fun showName(aName: String, empty: (String) -> Boolean): String {
    return if (empty(aName)) "Empty Name"
    else aName
}

showName("nihao", fun(name: String): Boolean {return name.isEmpty()})
```

其中`fun(name: String): Boolean {...}`就是一个匿名函数，避免创建大量方法

### Lambda表达式

本质是一个**简化表达后的匿名函数**。以表达式形式传递的未声明函数。

```kotlin
val sum: (Int, Int) -> Int = { x: Int, y: Int -> x + y }
简化：
val sum1 =  { x: Int, y: Int -> x + y }
val sum2: (Int, Int) -> Int = { x, y -> x + y }
```

上述都是Lambda表达式

总结下Lambda的语法：

- 一个Lambda表达式必须通过`{}`包裹
- 如果Lambda声明了参数的类型，且返回值支持类型推导，Lambda变量就可以忽略函数类型声明`类似sum1`
- 如果Lambda声明了函数类型，那么Lambda就可以忽略参数部分的类型声明

#### 单个参数的隐式名称

```kotlin
val list: List<String> = listOf("1", "2", "3")

fun printList(){
  list.forEach{it -> print(it)}
}
```

其中声明了`it`这个关键字，表示的就是`单个参数的隐式名称`。只针对于单个参数时使用

#### Function类型

Kotlin在JVM层设计了`Function类型`，主要就是为了**兼容Java端的Lambda表达式(在JDK8之后添加了支持)**。

后续的更新中会具体讲到该类型的使用

#### `invoke()`

高阶函数可以以`其他函数`作为参数或者返回值，我们调用的`其他函数`实质只是构造了一个`Function类型的对象`，需要调用到`invoke()`才能实质去执行该函数。

### 柯里化风格

> `柯里化`：接收多个参数的函数转变成接收一个单一参数(最初函数的第一个参数)的函数，并且返回接收余下的参数而返回结果的新函数。

```kotlin
fun sum(x:Int,y:Int,z:Int):Int = x+y+z
//柯里化换换
fun sum(x:Int) = {
  y:Int -> {
    z:Int -> x+y+z
  }
}
```

上述两种函数是等价的。

在Kotlin中柯里化只是一种近似的效果，并不是真正意义上的柯里化。

## 面向表达式编程

> 在Kotlin中利用了各种表达式来增强程序的表达以及流程控制能力。

`语句`：程序往往都是由一个个语句组成的。以一行作为一个语句

`表达式`：表达式可以是一个值、常量、变量、操作符、函数，或他们之间的组合，编程语言对其进行解释和计算，以求产生另一个值。

### 表达式比语句更安全

表达式目的是产生另一个值，相比于语句增加了安全性。

### 复合表达式

表达式具备更好的**隔离性**，在使用表达式时就可保证更好的安全性。

> 表达式由于返回的都是值，可以更好的进行组合，可以将一个表达式作为另一个表达式的组成部分，而后形成一个复合表达式。

#### 枚举类

```kotlin
//普通枚举类
enum class RGB { RED, GREEN, BLUE }

enum class RGB(val index:Int){
  RED(1),
  GREEN(2),
  BLUE(3);

  fun getColor():Int{
    return index;
  }
}
```

> 当在枚举类中存在额外的方法或属性定义时，必须强制加上`;`。

定义完成后，对枚举类进行调用

```kotlin
val color = Day.valueOf("GREEN").index //2
或
val color = enumValueOf<Day>("MON").index //2
```

#### `when`表达式

> `when`表达式类似`switch`语句，由`when`关键字开始，用`{}`包含多个逻辑分支，每个分支有`->`连接。按照条件由上到下匹配，直到匹配完为止。否则执行`else`分支的逻辑等价于`switch中的default`。

```kotlin
when(x){
  -2,-1 -> println("负数")
  0 -> println("是0")
  else -> println("其他值")
}
```

**后续会有`when`相关高级用法**

#### `for`循环

> `for`可以对任何提供迭代器(iterator)的对象进行遍历，例如`List、Map`。

```kotlin
for(i in 1..3) println(i) //1 2 3

val list = listOf<Int>(1,2,3)
for(i in list) println(i) // 1 2 3
```

##### 范围表达式

上面讲到的`1..3`就是`范围表达式`的一种。

> 范围表达式需要通过`rangeTo()`实现，通过`..`操作符与某种类型的对象组成，除了整型等基本类型之外，还需要去实现`Comparable`接口。

```kotlin
//顺序打印
for(i in 1..3) print(i) //1 2 3
//指定步长打印
for(i in 1..5 step 2)//1 3 5
//倒序打印
for(i in 5 downTo 1 step 2)//5 3 1
//半开区间
for(i in 1 until 4) //1 2 3
```

上述的`in`关键字除了可以在范围表达式中当做循环使用，还可以用于*检查一个元素是否是一个区间或集合中的成员*。

```kotlin
val list: List<String> = listOf("1", "2", "3")
"2" in list //true
```

补充：

1. 可以通过`withIndex()`输出一个键值元组
   
   ```kotlin
       for ((index, value) in list.withIndex()) {
             println("$index => $value")
       }
   // 0 => 1
   // 1 => 2
   // 2 => 3
   ```

#### 中缀表达式

> 上述讲到了一些`in downTo step`这些的调用方式与普通`.`不同，他们是直接忽略了`.以及()`，这些就称之为`中缀表达式`。

定义一个`中缀函数`必须满足以下要求：

- 必须是某个类型的**拓展函数或者成员方法**
- 只能有一个参数
- 参数必须不是**可变参数**且**参数不能有默认值**

> `可变参数`：支持接收可变数量的参数，在Java中用`Arg...`来进行表示且必须是放在最后一个参数，Kotlin采用的是`vararg`进行表示，可以放在任意位置。

```kotlin
val letters: Array<String> = arrayOf("a", "b", "c")

fun printLetters(vararg letters: String) {
    for (letter in letters)
        print(letter)
}
//使用*传入外部的变量作为可变参数的变量
printLetters(*letters)
```

示例：

```kotlin
class Person {
    infix fun called(name: String) {
        println("my name is $name")
    }

    fun callName(){
//      called("World")
        this called "World"//在接收者自身调用 中缀函数时 需要显式指定 this
    }
}

fun main(args: Array<String>) {
  val p = Person()
  //p.called("Hello")
  p called "Hello" //my name is Hello

  p.callName() //my name is World
}
```

### 字符串的定义和操作

#### 基础操作

```kotlin
val str = "Hello World"

str.length //11
str.subString(0,5)//Hello
str.replace("World","Kotlin") //Hello Kotlin

str[0] //H
str.first() //H
str.last() //d

//是否为空
str.isEmpty()//false
```

#### 进阶操作

1. 定义原生字符串
   
   ```kotlin
       val rawString = """Hello
   World
   """
   ```
   
   利用`""""""`包裹的内容最终打印出的格式与代码定义格式保持一致。

2. 字符串模板

> 字符串中可以包含`模板表达式(一小段代码)`，通过`$`做开头以标记，单纯放入一个参数(`$arg`)，或放置一个表达式(`${expression}`)。
> 
> **大大提升了代码的紧凑性与可读性。**

```kotlin
   val str = "Kotlin"

   print("It is $str") //It is Kotlin

   print("$str length is ${str.length}")//6
```

3. 字符串判等
   
   Koltin判断是否相等主要有两种类型：
   
   - **结构相等**：判断内容是否相等
     
     通过`==`来进行判断，否定是用`!=`表示
   
   - **引用相等**：判断两个对象的引用是否相等
     
     通过`===`进行判断，否定是用`!==`表示
   
   ```kotlin
   var a = "Java"
   var b = "Java"
   
   print(a==b)//true
   print(a===b)//false
   ```

更多操作可以参考[String API](https://kotlinlang.org/api/latest/jvm/stdlib/kotlin/-string/index.html)
