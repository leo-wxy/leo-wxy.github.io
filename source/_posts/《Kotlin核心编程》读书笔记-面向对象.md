---
title: 《Kotlin核心编程》读书笔记-面向对象
date: 2019-06-23 21:41:16
tags: Kotlin
top: 10
---

> 内容摘自《Kotlin核心编程》第3章，在其基础上对一些概念进行拓展了解

本章主要讲Kotlin中一些面向对象的类和方法讲解以及一些相对Java的优化点。

## 类和构造方法

### 定义类

与Java相同使用`class结构体`来声明一个类

```kotlin
class Bird{
  //颜色
  val color :String ="blue"
  //年纪
  var age : Int = 1
  //动作
  fun fly()
}
```

上述代码就定义了一个鸟对象（蓝色、1岁、会飞）。

Kotlin声明类的语法非常类似于Java，但还是存在一些不同

- **不可变属性成员**：通过`val`声明引用不可变的属性成员，在反编译成class时，该参数是由`final`进行修饰
- **属性默认值**：除非显式的声明参数延迟初始化，否则必须指定属性的默认值
- **不同的访问修饰符**：Kotlin类中的成员默认是`public`的，Java的默认可见域是`protected`

### 定义接口

Kotlin中的接口与Java 8类似，既包含抽象方法的声明也包含实现。在Java 8引入了一个新特性-**接口方法支持默认实现**。而Kotlin是兼容Java 6，也提供了这种实现。

Java 8中接口的实现

```Java
interface Flyer{
    public String kind();
    int speed = 0;
    //默认实现
    default public void fly(){
        System.out.println("I can fly");
    }
}
```

其中`fly()`是一个默认方法，其他继承该接口的类都不需要实现该方法。



Kotlin中接口的实现

```kotlin
interface Flyer{
    val speed:Int
    fun kind()
    fun fly(){
        print("I can fly")
    }
}
```

拓展知识：

Kotlin是如何支持接口的默认方法？

首先对Kotlin定义的接口进行转换，转成容易理解的Java代码

```java
public interface Flyer {
   int getSpeed();
   void kind();
   void fly();

   public static final class DefaultImpls {
      public static void fly(Flyer $this) {
         String var1 = "I can fly";
         boolean var2 = false;
         System.out.print(var1);
      }
   }
}
```

Kotlin内部通过一个`DefaultImpls`这个静态内部类提供了`fly()`的默认实现。



Kotlin的方法中还支持声明属性，但内部通过观察反编译的Java代码可知是提供了一个`get()`提供支持，但是无法对接口定义的属性直接进行赋值，也是因为这个原因。

```kotlin
interface Flyer{
  //可通过该方法进行实现
  val speed
     get() = 100
}
```



### 构造类对象

```kotlin
val bird = Bird()
```

在Kotlin中并不会使用到`new`关键字，可以直接进行类的声明

如果构造方法中需要添加参数，直接在`Bird()`内添加参数即可，不需要进行方法的重载而产生多个方法。

要实现这种功能，需要依赖下面提到的Kotlin中的相关构造语法



#### 主从构造函数

Kotlin中的每个类最多存在一个**主构造函数**以及多个**从构造函数**。

##### 主构造函数

`主构造函数`：是类头的一部分，跟在类名之后

```Kotlin
class Person(name:String) {}
或
class Person constructor(name:String){}
```

一般情况下`constructor`可进行省略即第一种方式，特殊情况下必须显示（`存在注解或者可见性修饰符`）。`class Person @Deprecated(message = "111") public constructor(name: String)`(一般不会这样写~)

主构造函数中不能包含任何代码，如果需要初始化要在`init语句块`中实现，在主构造函数中`()`内的属性有两种定义方式：

- `class Person(name:String)`此时的name是局部变量，无法在其他方法中直接进行使用，只可以在`init语句块或属性声明`进行使用

  ```kotlin
  class Person(name:String){
    init{
      val length1 = name.length
    }
    val length2 = name.length
    fun test(){
      // name.length 无法调用
    }
  }
  ```

  将上述代码反编译成Java代码

  ```java
  public final class Person{
    private final int length2;
    public Person(String name){
      int length1 = name.length();
      this.length2 = name.length();
    }
    
    public final void test{
      //name.length 无法调用
    }
  }
  ```

  观察Java代码可知 `init{}`以及声明时相关逻辑都会在`Person(String name)`中执行，所以不会出错。

- `class Person(val name:String)`此时的name是全局变量，可以在任意地方进行使用。

  ```kotlin
  class Person constructor(val name: String) {
      init {
          val length1 = name.length
      }
      val length2 = name.length
      fun test() {
          val length3 = name.length
      }
  }
  ```

  将上述代码反编译成Java代码

  ```java
  public final class Person {
     private final int length2;
     @NotNull
     private final String name;
       @NotNull
     public final String getName() {
        return this.name;
     }
    
     public final void callName() {
        int length3 = this.name.length();
     }
  
     public Person(@NotNull String name) {
        Intrinsics.checkParameterIsNotNull(name, "name");
        super();
        this.name = name;
        int var2 = this.name.length();
        this.length2 = this.name.length();
     }
  }
  ```

   此时的`name`就是一个全局变量，可以在任意地方使用。




##### 从构造函数

`从构造函数`：由两部分组成：对其他构造方法的委托；另一部分由`{}`构成的代码块。**如果存在主构造函数，从构造函数都需要直接或间接委托给主构造函数（通过`this(...)`）。**

```kotlin
class Person constructor(val name: String){
    //委托主构造函数
    constructor(name:String,age:Int):this(name){
       
  }
}
```

`从构造函数`参数不能声明`val/var`。

```kotlin
class KotlinView : View {
      constructor(context:Context):this(context,null){ }
      constructor(context:Context,attrs:AttributeSet?):this(context,attrs,0){ }
      constructor(context:Context,attrs:AttributeSet?，defStyleAttr:Int):super(context,attrs,defStyleAttr){ }
    }
```



#### 构造方法默认参数

Java在方法重载时需要额外的添加方法，导致方法过多。在Kotlin中可以通过给构造方法中的参数指定默认值，从而避免不必要的方法重载。**当省略相应的参数时需要使用默认值**。

```kotlin
class Bird(val weight:Double = 0.00,val age:Int = 1,val color:String = "blue"){}

//调用Bird对象
val bird1 = Bird()//全部是默认值
val bird2 = Bird(weight = 1000.00,color="white") //重1kg 1岁的 白鸟
```

由于参数默认值的存在，在创建一个类对象时，*最好指定参数的名称*（命名参数），否则必须按照实际参数的顺序进行赋值。

例如上述代码中的`weight=1000.00`，就是对`weight`参数进行指定赋值

> `命名参数`：在函数调用时使用命名的函数参数，在函数有大量参数或者默认参数时使用方便。



#### `init`语句块

由于`主构造函数`不能包含任何的代码，所以引入了`init语句块`的语法，可以作为实例的初始化方法。

```kotlin
class Bird(var weight:Double = 0.00,var age:Int = 1,var color:String = "blue"){
    init {
        color = "Bird color is $color"
        println(color)
    }
}
```

对`color`属性在初始化时进行操作。

在构造方法中还可以拥有多个`init语句块`，他们会在对象创建时按照类从上到下的顺序先后执行。

```kotlin
class Bird(var weight:Double = 0.00,var age:Int = 1,var color:String = "blue"){
  init {
    color = "Bird's color is $color"
    println("$color")
  }
  
  init{
    println(weight)
  }
  
  init{
    println(age)
  }
  
}

//输出结果
Bird color is blue
0.0
1
```

多个`init语句块`有利于对初始化的操作进行职能分离，在复杂的业务开发中可以起到很大的作用。

#### 变量延迟初始化

一般地，属性声明为非空类型必须在构造函数中进行初始化，否则无法正常编译。Kotlin可以不用在类对象初始化的时候就必须有值。提供了`by lazy、lateinit`两种语法来实现延迟初始化的效果。

##### `by lazy（懒初始化）`

如果是用`val`声明的变量，可以用该语法来修饰

```kotlin
class Bird(var weight:Double = 0.00,var age:Int = 1,var color:String = "blue"){
  val sex : String by lazy{
    if(color=="yellow") "male" else "female"
  } 
}
```

语法特点如下：

- 修饰变量必须是`val`
- 只有再被首次调用时，才会进行赋值操作，一旦被赋值不会再被修改

`lazy()`接收一个`lambda表达式`并返回一个`lazy<T>`实例的函数，第一次访问该属性时，会执行对应的`lazy`中的`lambda表达式`并记录结果，后续访问时只是返回所记录的值。

另外可以对`lazy`属性进行设置，共支持三种属性：

- `LazyThreadSafetyMode.SYNCHRONIZED(默认属性)`：加上同步锁，在同一时刻只允许一个线程对`lazy`属性进行初始化，所以是**线程安全**。
- `LazyThreadSafetyMode.PUBLICATION`：允许多个线程进行初始化操作
- `LazyThreadSafetyMode.NONE`：若确定初始化总是发生单线程上，可以设置该参数，就不会存在线程方面的开销。

`by lazy`内部实现原理涉及到**属性委托**相关概念，后面会讲到相关内容。

##### `lateinit（延迟初始化）`

`lateinit`允许编译器识别非空类型属性的值然后跳过空检查，使之正常编译。

`lateinit`主要用于`var`声明变量，然而**不支持修饰基本类型(Int,Long)，因为基本类型的属性在类加载后的准备阶段会被初始化为默认值。需要用`Integer`这类包装类来替代。**

```kotlin
class Bird(var weight:Double = 0.00,var age:Int = 1,var color:String = "blue"){
    lateinit var sex : String
}
```

> 使用`lateinit`关键字的时候，只是跳过了编译器的校验，如果在使用时没有进行赋值还是会出错。

##### 拓展

除了`by lazy`还有一种方案可以实现变量延迟初始化，通过使用`Delegates.notNull<T>`，也是利用了`委托`这个概念实现的。

```kotlin
var a by Delegates.notNull<String>()
fun setValue(){
  a="test"
}
```



## 不同的访问控制原则

与Java一样，Kotlin也提供了各种修饰符来描述*类、方法，属性的可见性*。

### 限制修饰符

> 用于指定`类、方法或属性`的修改或者重写权限，就会用到`限制修饰符`。

Kotlin定义的类是默认`final`即不可继承和修改，使程序变得更加安全，但是会在开发过程中带来很多的不便。在Java中类是默认可以被继承，除非主动添加`final`修饰符。

Kotlin提供了`open`修饰符使类可以被继承，若需要一个方法可以被重写，也需要添加`open`修饰。

```kotlin
open class Bird {
  val weight : Double = 500.0
  val age = 1
  open fun fly(){}
}

class Maque : Bird(){
  override fun fly()
}
```

除了`open`限制修饰符，Kotlin提供了`final、abstract`，两者的效果与Java对应修饰符一致。

| 修饰符   | 含义                           | 与Java比较                  |
| -------- | ------------------------------ | --------------------------- |
| open     | 允许被继承或重写               | Java默认类设置              |
| abstract | 抽象类或抽象方法               | 效果一致                    |
| final    | 不允许被继承与重写（默认设置） | 与Java`fianl`修饰符效果一致 |



### 可见性修饰符

> 不管是`类、对象、接口、方法、属性`都具有`可见性修饰符`，Kotlin提供了以下四种修饰符，在不同的场景下有不同的功能。

#### `public`

Kotlin的默认修饰符，表示**声明随处可用**。与Java中的`public`功能一致

#### `protected`

Kotlin设置该修饰符后，只允许`类及子类`访问，在Java中还允许同`包`下类文件访问

#### `private`

表示该类私有，只能在当前文件中进行访问，Java中不允许对类进行`private`修饰

#### `internal`

Kotlin特有修饰符，只允许在**模块中进行访问**。

> 模块：一起编译的Kotlin文件的集合。包括以下几种：
>
> - 一个Eclipse项目
> - 一个Intellij IDEA项目
> - 一个Maven项目
> - 一个Gradle项目
> - 由Ant任务执行编译的代码

提供该修饰符的原因：保证类的安全性，保证只在当前模块中调用，外部如果需要调用只能拷贝源码。



| 修饰符      | 含义                                                         | 与Java比较                           |
| ----------- | ------------------------------------------------------------ | ------------------------------------ |
| `public`    | **Kotlin默认修饰符**<br>全局可见                             | 等同于Java中的`public`效果           |
| `private`   | **私有修饰符**<br>类内修饰，只有本类可见<br>类外修饰，文件内可见 | 只有类内可见                         |
| `protected` | **受保护修饰符**<br>本类及子类可见                           | 作用域除了本类与子类，还包括包内可见 |
| `internal`  | **内部可见修饰符**<br>模块内可见                             | 无                                   |

`private`修饰符功能代码解释

```kotlin
class Book(val bookName: String) {
    //类内修饰
    private val privateBook = 1

    fun main(args: Array<String>) {
        val bird = Maque()
    }
}

//类外修饰
private val privateOutVal = 2

private class Maque : Bird() {
    private val aaa = 1

    override fun fly() {
        println("Maque fly"+ privateOutVal) // Maquefly2
    }
}
```



## 解决多继承问题

Java是不支持类的多继承，Kotlin亦是如此。但是Kotlin可以通过特殊的语法提供多种不同的多继承解决方案。**多继承最大的问题就是导致继承关系的语义混淆**。

### 多继承困惑

容易导致**钻石问题(菱形继承问题)**，在类的多重继承下，会在继承关系下产生歧义。并且会导致代码维护上的困扰以及代码的耦合性增加。

### 接口实现多继承

一个类可以实现多个接口，在Java中是很常见的。Kotlin中的接口还可以`声明抽象的属性`，这个可以帮助Kotlin来通过接口实现多继承。

```kotlin
interface NewFlyer{
    fun fly()
    fun kind() = "flying animals"
}

interface NewAnimal{
    fun eat()
    fun kind() = "flying new animals"
}

class NewBird(val name:String):NewFlyer,NewAnimal{
    override fun fly() {
        println("I can fly")
    }

    override fun kind(): String {
        return super<NewAnimal>.kind()
    }

    override fun eat() {
        println("I can eat")
    }
}

fun main(args:Array<String>){
    val bird = NewBird("Maque")
    println(bird.kind())
}

//输出
flying new animals
```

上述定义的`NewFlyer、NewAnimal`接口，都设置了`kind()`，就会引起继承上的歧义问题。Kotlin通过提供`super<T>`用来指定继承哪个父类接口方法。

### 内部类实现多继承

> 内部类：将一个类的定义放在另一个类的内部，内部类可以继承一个与外部类无关的类，保证了内部类的独立性。内部类会带有一个对外部类对象的引用。

#### Kotlin实现内部类

在Java中是如下实现内部类的

```java
public class OuterJava{
  private String name = "inner class"
  class InnerJava {
    public void printName(){
      System.out.println(name) //inner class
    }
  }
}
```

Kotlin仿照上述实现

```kotlin
class OuterKotlin{
  private val name = "inner class"
  class InnerKotlin {
    fun printName(){
      print("$name") //Unresolved reference ：name
    }
  }
}
```

这个时候，`InnerKotlin`属于嵌套类。

> 嵌套类：不包含对外部类实例的引用，无法调用其外部类的属性。

真正的实现方案

```kotlin
class OuterKotlin{
  private val name = "inner class"
  inner class InnerKotlin {
    fun printName(){
      print("$name") //inner class
    }
  }
}
```

利用`inner`关键字就可以实现内部类。

#### 内部类多继承方案

```kotlin
open class Horse{
    fun runFast(){
        println("like horse runFast")
    }
}

open class Donkey{
    fun runFast(){
        println("like Donkey runFast")
    }
}

class Mule{
    private inner class HorseC:Horse()
    private inner class DonkeyC:Donkey()

    fun runFast(){
        HorseC().runFast()
    }

    fun runSlow(){
        DonkeyC().runFast()
    }
}

fun main(args:Array<String>){
    val mule = Mule()
    mule.runFast()
    mule.runSlow()
}
```

1. 可以在一个类内部定义多个内部类，每个内部类的实例都有自己的独立状态并且与外部的信息相互独立
2. 通过内部类继承外部类，可以在实例对象中获得外部类不同的状态和行为
3. 可以通过`private`修饰内部类，避免其他类访问内部类，保证封装性。

### 使用委托代替多继承

**委托**是Kotlin新引入的语法

## 参考链接

[Kotlin懒加载语法](https://zhuanlan.zhihu.com/p/65914552)

  




