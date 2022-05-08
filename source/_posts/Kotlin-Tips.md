---
title: Kotlin-Tips
typora-root-url: ../
date: 2020-10-06 15:20:19
tags: Kotlin
top: 9
---



{% blockquote %}
主要用来记录Kotlin的一些关键概念
{% endblockquote %}



### Kotlin lazy关键字

> `lazy`用在懒初始化的场景下，在参数不使用时无需进行初始化过程。

```kotlin
class Bird(var weight:Double = 0.00,var age:Int = 1,var color:String = "blue"){
  val sex : String by lazy{
    //内部进行赋值操作，会在第一次调用时执行
    if(color=="yellow") "male" else "female"
  } 
}
```

语法特点如下：

- 修饰变量必须是`val`
- 只有被首次调用时才可以赋值，后续不能进行修改



另外可以对`lazy`属性进行设置。共支持三种属性：

- `LazyThreadSafetyMode.SYNCHRONIZED(默认属性)`：加上同步锁，在同一时刻只允许一个线程对`lazy`属性进行初始化，所以是**线程安全**。
- `LazyThreadSafetyMode.PUBLICATION`：允许多个线程进行初始化操作
- `LazyThreadSafetyMode.NONE`：若确定初始化总是发生单线程上，可以设置该参数，就不会存在线程方面的开销。



#### lateinit

> `lateinit`用在`延迟初始化`的场景下，允许编译器识别非空类型属性的值然后跳过空检查，使之正常编译。

```kotlin
class Bird(var weight:Double = 0.00,var age:Int = 1,var color:String = "blue"){
    lateinit var sex : String
}
```

使用`lateinit`时，切记后续一定要进行初始化，否则还是会报错。



#### `Delegates.notNull<T>`

可以针对`var`修饰变量进行延迟初始化。

```kotlin
var a by Delegates.notNull<String>()
fun setValue(){
  a="test"
}
```





### Kotlin 作用域函数

主要有`let`、`run`、`with`、`apply`和`also`

他们之间的主要区别在于

- `引用上下文对象的方式`
- `返回值`

#### 上下文对象

> 做为`lambda表达式`的 接收者`this` 或者 参数`it`。

`this`

`run`、`with`以及`apply`通过`this`引用上下文对象

```kotlin
val adam = Person("Adam").apply { 
    this.age = 20                       // 和 this.age = 20 或者 adam.age = 20 一样
    city = "London"
}
println(adam)
```



`it`

`let`和`also`将上下文对象做为`lambda表达式`参数。

```kotlin
fun getRandomInt(): Int {
    return Random.nextInt(100).also {
        writeToLog("getRandomInt() generated value $it")
    }
}

val i = getRandomInt()
```

#### 作用域函数

##### `let`

> `上下文对象`为`it`，`返回值`为lambda表达式的结果

`let`经常用于`仅使用非空值执行代码块`。

```kotlin
val numbers = mutableListOf("one", "two", "three", "four", "five")
numbers.map { it.length }.filter { it > 3 }.let { 
    println(it)
    // 如果需要可以调用更多函数
} 
```



另一种情况就是`引入作用域受限的局部变量以提高代码的可读性`

```kotlin
val numbers = listOf("one", "two", "three", "four")
val modifiedFirstItem = numbers.first().let { firstItem -> //firstItem 就是局部变量
    println("The first item of the list is '$firstItem'")
    if (firstItem.length >= 5) firstItem else "!" + firstItem + "!"
}.toUpperCase()
```



##### `with`

> `上下文对象`为`this`，`返回值`为lambda表达式的结果

`with`可以理解为`对于这个对象，执行以下操作`

```kotlin
val numbers = mutableListOf("one", "two", "three")
with(numbers) {
    println("'with' is called with argument $this")
    println("It contains $this.size elements")
}
```

`with`需要显式的传入参数

##### `run`

> `上下文对象`为`this`，`返回值`为lambda表达式的结果

功能与`with`基本一致

```kotlin
val result = service.run {
    port = 8080
    query(prepareRequest() + " to port $port")
}

```

##### `apply`

> `上下文对象`为`this`，`返回值`为上下文对象本身

`apply`可以理解为`将以下赋值操作应用于对象`，并且可以返回对象。

```kotlin
val adam = Person("Adam").apply {
    age = 32
    city = "London"        
}
println(adam)
```



##### `also`

> `上下文对象`为`it`，`返回值`为上下文对象本身

`also`对于执行一些上下文对象做为参数的操作很有用

```kotlin
val numbers = mutableListOf("one", "two", "three")
numbers
    .also { println("The list elements before adding new one: $it") }
    .add("four")
```



#### 使用场景

- 对一个非空（non-null）对象执行 lambda 表达式：`let`
- 将表达式作为变量引入为局部作用域中：`let`
- 对象配置：`apply`
- 对象配置并且计算结果：`run`
- 在需要表达式的地方运行语句：非扩展的 `run`
- 附加效果：`also`
- 一个对象的一组函数调用：`with`

### Kotlin object关键字

在Kotlin代码中没有出现过`static`关键字。

在Java中，`static`是非常重要的特性，可以用来修饰类、方法或属性。

> `static`修饰的内容都是属于类的，代码结构无法清晰区分，而且不是`面对对象`的。
>
> 违背了面向对象思想、`static`修饰的静态类、静态对象很难被GC。

#### 伴生对象

> 伴随某个类的对象，属于这个类。并且全局只有一个单例，被声明在类的内部，在类装载时会初始化。

利用`companion object`实现`伴生对象`

```kotlin
class XX {
  companion object {
    // ...
  }
}
```

`伴生对象`就是Kotlin中用来代替`static`的。

#### 单例模式

> 在系统中只能存在一个实例对象。

```java
public class SingleInstance {
  private SingleInstance(){
    
  }
  
  private static volatile SingleInstance INSTANCE ;
  public SingleInstance getInstance(){
    if(INSTANCE==null){
      synchronized(SingleInstance.class){
        if(INSTANCE == null){
          INSTANCE = new SingleInstace();
        }
      }
    }
    return INSTANCE;
  }
  
      //反序列化提供的一个特殊方法，可以控制对象的反序列化
    private Object readResolve(){
        return mInstance;//返回实例对象
    }
}
```

上述为Java通用的单例写法——`双重校验锁`。

在Kotlin中，只要以下代码

```kotlin
object SingleInstance {
  //...
}
```

`object`的实现为`饿汉式`，需要提前初始化。

#### 声明匿名内部类

`object`表达式可以赋值给一个变量，减少很多重复代码。

```kotlin
    private val sThreadLocal = object : ThreadLocal<DNSThreadLocalModel>() {
        override fun initialValue(): DNSThreadLocalModel {
            //...
        }
    }

```



### Kotlin 空安全机制

在使用Kotlin前，Java都一般通过如下方法去解决`NPE`

1. 函数内对于无效值，倾向于抛异常处理
2. 采用`@NotNull/@Nullable`标注
3. 使用专门的`Optional`对可能为null的变量进行装箱。



#### 可空类型

```kotlin
var a : Int? = null
```

在任何类型后面加上`?`就表示对象可为空。

`?.`：安全调用，只有对象存在时，才可以继续调用方法

`?:`：合并运算符，如果非空就使用它，为空则使用一个默认值

`!!.`：类似`Assert`，当对象为空时，继续抛出NPE



#### 实现原理

针对`?`相关的代码进行反编译查看，内部是通过在参数上标注了`@Nullable`，然后调用时，采用了`if..else`进行非空判断，保证安全。

可能出于以下原因：

- 兼容Java老版本
- 实现Java与Kotlin的100%转换





### Kotlin inline、noinline、crossinline

#### `inline`

> 函数进行内联，将`inline fun`直接插入到调用函数的代码内，优化代码结构，从而减少函数类型对象的创建。

```kotlin
fun main(args:Array<String>){
  testInline()
  print("world")
}

inline fun testInline(){
  print("Hello")
}

输出结果：
HelloWorld

实际编译结果：
fun main(args:Array<String>){
  print("Hello")
  print("world")
}
```



#### `noinline`

> 局部关掉函数内联优化，摆脱`inline不能使用函数类型的参数当对象用`的限制。作用于**函数的参数且参数必须为函数类型**

```kotlin
inline fun test(noinline a : Int) {
   //Modifier 'noinline' is allowed only for function parameters of an inline function
   //错误使用方法 `noinline`只能使用在函数参数上
}

inline fun test(a: Int,  b: (Int) -> Unit): (Int) -> Unit {
    return b
  //Illegal usage of inline-parameter 'b' 
  //错误使用方法 不能直接返回 函数类型，因为经过内联后，函数类型无法被调用，失去了存在意义
  //这种错误写法，编译器可以直接检测出来
}

inline fun test(a:Int , noinline b :(String)->Unit) : (String) -> Unit {
  println(a)
  b("World")
  return b
}

fun main(args:Array<String>){
  println("Hello")
  test(3){ it->
    println(it)
  }
}

输出结果：
Hello
3
World

实际编辑结果：
fun main(args:Array<String>){
  println("Hello")
  println(3)
  b.invoke("World")
}
```



#### `crossinline`

> 局部加强函数内联优化，将内联函数里的函数类型参数可以当作对象使用。

首先声明两个概念：

- Lambda表达式不允许使用`return`，可以使用`return@XX`来指定返回位置

  ```kotlin
  fun test(a:()->Unit){
    ...
  }
  
  fun main(args:Array<String>){
   test {
     ...
     return //这个是不被允许使用的
   //return@test 这个是可以的  
   } 
  }
  ```

- 只有被`inline`修饰的内联函数的`Lambda表达式`可以使用return。在`间接调用`是被禁止的操作

  ```kotlin
  inline fun test(action:()->Unit){
    println("Hello")
    action()
  }
  
  fun main(args:Array<String>){
    test{
      println("World")
      return //是被允许这么做的
    }
  }
  ```

`crossinline`实质为了**声明函数参数的`lambda`不能写`return`，避免lambda中的return影响外部的执行流程**。



使用`inline`修饰函数时需要注意以下几点：

- `inline`修饰函数，最好函数参数也是`函数类型`，否则无法获得性能提升

- **避免内联大型函数**，因为`inline`会增加代码的生成量

- `inline`修饰的函数不持有函数的对象引用，也不能将函数参数传递给另一个函数

  ```kotlin
  fun test123(a:()->Unit){
  
  }
  
  inline fun test12(a:()->Unit){
      test123(a) //无法编译
  }
  ```

### Kotlin Java与Kotlin互相调用

#### Java调用Kotlin

##### 文件名

> 当文件包含顶级函数或属性时，需要使用`@file:JvmName("XX")`对其进行注释，可以在`XX`调用到具体方法和属性

```kotlin
//定义类名为AAA，且提供方法为 call

@file:JvmName("AAA")
package com.xx.xx;

fun call(){}

//在Java中调用方法call
void test(){
  AAA.call()
}
```



##### 成员变量

> 一般情况下调用Kotlin的成员变量时，默认会自动生成`get`、`set`方法，并不能直接去使用对应变量。

```kotlin
//定义 数据类 
data class Data(
  val a:String,
  @JvmField val b:String )

//Java中调用
Data data = new Data("a","b");
String a = data.getA();//无法直接使用 data.a
String b = data.b; //可以直接使用到 data.b
```

观察编译后源码就知道原因

```java
public final class A {
   @NotNull
   private final String a;

   @NotNull
   public String b;
  
   public final String getA() {
      return this.a;
   }
}
```

相对的设置`@JvmField`就没有`get和set`。



还可以通过`@get:JvmName`和`@set:JvmName`去指定对应方法

```kotlin
data class Data(
@get:JvmName("getAA")
  val a:String,
@set:JvmName("setBB")
  var b:String
)

//Java中调用
Data data = new Data("a","b");
data.getAA();
data.setBB("bb")
```



##### 伴生函数/伴生常量

> `companion object`中定义的函数与对象

```kotlin
class KotlinClass{
  companion object{
    //常量值
    const val CONST = "const"
    //常量
    val value = "Value"
    //方法
    fun doWork(){...}
  }
}

//Java中调用
public static void main(String[] args){
  KotlinClass.Companion.getValue();
  String value = KotlinClass.CONST;
  KotlinClass.Companion.doWork();
}
```

在Java中调用`伴生对象`相关内容时，需要额外添加`Companion`才可以使用。

这时需要添加`@JvmStatic`注释，就可以直接调用对应参数

```kotlin
class KotlinClass{
  companion object{
    //常量值
    const val CONST = "const"
    //常量
   @JvmStatic val value = "Value" //推荐使用 @JvmField
    //方法
   @JvmStatic fun doWork(){...}
  }
}

//Java中调用
public static void main(String[] args){
  KotlinClass.getValue(); //若使用@JvmField KotlinClass.value
  String value = KotlinClass.CONST;
  KotlinClass.doWork();
}
```

编译后源码如下

```java
public final class KotlinClass{
     @NotNull
   public static final String CONST = "const";
   @NotNull
   private static final String value = "Value";
  
   public static final void doWork() {
      Companion.doWork();
   }
  
     public static final class Companion {
      @NotNull
      public final String getValue() {
         return KotlinClass.value;
      }
       
      @JvmStatic
      public final void doWork() {
        //...
      }       
     }
}
```

被`@JvmStatic`修饰后的方法/变量，会被提取到被伴生的类上，就可以直接被调用了。





##### 方法默认参数值

> Kotlin实现的方法可以通过在参数后面写上`= XX`设置默认值，后续Kotlin的方法去调用时就不需要设置相关参数就可以使用

```kotlin
//定义默认参数的方法
class Greeting {
    fun sayHello(prefix: String = "Mr.", name: String) {
        println("Hello, $prefix $name")
    }
}

//Kotlin中调用
fun test(){
  Greeting().sayHello("wxy")//不需要设置前面的参数
}

//Java调用
public static void main(String[] args){
  Greeting greeting = new Greeting();
  greeting.sayHello("Mr.","wxy");
}
```

在Java中该设置是无法生效的，此时就需要`@JvmOverloads`去修饰

```kotlin
class Greeting {
  @JvmOverloads
    fun sayHello(prefix: String = "Mr.", name: String) {
        println("Hello, $prefix $name")
    }
}

//Java调用
public static void main(String[] args){
  Greeting greeting = new Greeting();
  greeting.sayHello("wxy");
}
```

实现原理就是实现了两个重载方法。

还有其他示例，例如自定义View

```kotlin
@JvmOverloads
constructor(context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0) :
    View(context, attrs, defStyleAttr) {
}
```



##### 异常实现

实现`@Throws()`

```kotlin
@Throws(IOException::class)
fun ex() {
    throw IOException("")
}
```

##### synchronized

实现`@Synchronized`

```kotlin
    @Synchronized
    fun test(){
        
    }
```

##### volatile

实现`@Volatile`

```
@Volatile
var abc : String = ""
```



##### 不允许Java调用

实现`@JvmSynthetic`

```kotlin
    @JvmSynthetic
    fun forbiden(){

    }
```



#### Kotlin调用Java

##### 不得使用硬关键字

> **请勿将Kotlin的任何硬关键字用做方法或字段的名称**。例如`is`、`when`、`object`等
>
> 若要使用必须用反引号进行转义（ 反引号 ``）

```kotlin
public Object object;
//使用kotlin中关键字命名的方法
public void is() {

}

//Kotlin调用
testJava.`is`()
```



##### 可为null性注释

> 如果要求Kotlin不能设置参数为null，在Java中就需要对对应参数添加`@NonNull`

```kotlin
class JavaClass{
  public void needNotNull(@NonNull String a);
  public void needNull(@Nullable String a);
}

//Kotlin调用
fun main(){
  JavaClass().needNotNull(null)//这种写法是错误的
}
```



##### 可变长度参数

> Java中实现可变参数为`String...strs `，对应Kotlin的实现为`vararg`，但是两者不能互传

```kotlin
class JavaClass{
  void test(String... args){

  }
}

//Kotlin调用
fun main(){
  //  JavaClass().test(arrayOf<String>("1"))//这种写法就是错误的
  // 需要使用以下写法
  JavaClass().test(*arrayOf<String>("1"))
}
```



##### 运算符过载

> Kotlin允许使用`特殊调用点语法`。可以有效缩短语法。

[运算符过载](https://kotlinlang.org/docs/reference/operator-overloading.html)



##### Lambda参数位于最后

> 在Kotlin中调用带有接口参数的方法时，如果接口只有一个方法，可以通过Lambda表达式实现`SAM转换`。
>
> `SAM转换`：只能应用于接口上。

```kotlin
public interface IListener{
  void test();
}

public class JavaClass{
  void singleFun(IListener listener){}
  
  void hasParamFun(int a,IListener listener){}
}

//Kotlin调用
fun main(){
  JavaClass().sinlgeFun{
    
  }
  
  JavaClass().hasParamFun(123){
    
  }
}
```

将Lambda参数置于最后，可以简化写法。



### Kotlin 泛型

#### 泛型的优势

- 类型检查，编译时就可以检测错误
- 自动类型转换，不用强制类型转换

#### Java中使用泛型

```java
//泛型接口
public interface Genertor<T>{
  public T get();
}

//泛型类
public class GenertorImpl<T> implements Gentor<T>{
  @Override
  public T get(){
    
  }
}

//泛型方法
public <T> T genericMethod(T t){
  //...
}

//设置泛型上界
private class C<T extends Number> {

}
```



##### 通配符

`? extends X`：表示`X`是方法传入类型的上界，即X或者X的父类

```java
public static void print2(GenericType<? extends Fruit> p){
	System.out.println(p.getData().getColor());
}

public static void use2(){
	GenericType<Fruit> a = new GenericType<>();
	print2(a);
	GenericType<Orange> b = new GenericType<>();
	print2(b);
}
```

`主要用于安全的访问数据，可以访问X及其子类型`





`? super X`：表示`X`是方法传入类型的下界，即X或者X的子类

```java
public static void printSuper(GenericType<? super Apple> p){
	System.out.println(p.getData());
}

public static void useSuper(){
	GenericType<Fruit> fruitGenericType = new GenericType<>();
	GenericType<Apple> appleGenericType = new GenericType<>();
	GenericType<HongFuShi> hongFuShiGenericType = new GenericType<>();
	GenericType<Orange> orangeGenericType = new GenericType<>();
	printSuper(fruitGenericType);
	printSuper(appleGenericType);
	printSuper(hongFuShiGenericType);
	printSuper(orangeGenericType);
}
```

`主要用于安全的写入数据，可以写入X及其子类型`



##### PECS原则

**Producer Extends,Consumer Super**

得出以下结论：

- 需要从数据类型获取数据，就使用`? extends `通配符
- 需要写入数据到数据类型，就使用`? super`通配符
- 如果既想存，又想取，就不要使用通配符

#### Kotlin中使用泛型

```kotlin
//泛型类
class SmartList<T> : ArrayList<T>(){
  fun find(t:T):T?{
    val index = super.indexOf(t)
    //
  }
}

//泛型方法
fun <T> singletonList(item: T): List<T> {
    // ……
}

//设置泛型上界
fun <T : Number> sum(vararg param: T) = param.sumByDouble { it.toDouble() }

```

##### `where`关键字

Java使用的就是`&`

```java
class ClassA { }

interface InterfaceB { }

public class MyClass<T extends ClassA & InterfaceB> {
    Class<T> variable;
}
```

对应Kotlin的实现，需要使用`where`关键字

```kotlin
open class ClassA

interface InterfaceB

class MyClass<T>(var variable: Class<T>) where T : ClassA, T : InterfaceB
```

##### 通配符

相对于Java使用的`? extends`和`? super`，Kotlin使用的是`out`、`in`

```kotlin
//Java
public static void print2(GenericType<? extends Fruit> p){
	System.out.println(p.getData().getColor());
}

//Kotlin
fun print2(p:GenericType<out Fruit>){}
```



```kotlin
//Java
public static void printSuper(GenericType<? super Apple> p){
	System.out.println(p.getData());
}

//Kotlin
fun printSuper(p:GenericType<in Apple>)
```

相对于`PECS`原则，对应起来就是**生产者使用 out，消费者使用 in**

##### 星投影

安全方式是定义泛型类型的这种投影，该泛型类型的每个具体实例化将是该投影的子类型。

- 对于 `Foo <out T : TUpper>`，其中 `T` 是一个具有上界 `TUpper` 的协变类型参数，`Foo <*>` 等价于 `Foo <out TUpper>`。 这意味着当 `T` 未知时，你可以安全地从 `Foo <*>` *读取* `TUpper` 的值。
- 对于 `Foo <in T>`，其中 `T` 是一个逆变类型参数，`Foo <*>` 等价于 `Foo <in Nothing>`。 这意味着当 `T` 未知时，没有什么可以以安全的方式*写入* `Foo <*>`。
- 对于 `Foo <T : TUpper>`，其中 `T` 是一个具有上界 `TUpper` 的不型变类型参数，`Foo<*>` 对于读取值时等价于 `Foo<out TUpper>` 而对于写值时等价于 `Foo<in Nothing>`。

##### 获取泛型类型

因为`类型擦除`的存在，导致无法获取到运行时的泛型参数的类型。

但是Kotlin提供`reified`关键字，可以获取到泛型的类型

```kotlin
inline fun <reified T> getType(){
  return T::class.java
}
```

在编译的时候，会讲具体的类型插入到字节码中，就可以在运行时获取泛型类型。

#### 泛型擦除

> 泛型只能用于在编译期间的静态类型检查，然后编译器生成的代码会擦除相应的类型信息。成功编译过后的Class文件是不会包含任何泛型信息的，泛型信息不会进入到运行时阶段。
>
> 例如`List<String>`在运行时用`List`表示，为了确保Java 5之前的版本可以进行兼容。

被擦除的泛型信息存放于`Signature`中

https://stackoverflow.com/questions/937933/where-are-generic-types-stored-in-java-class-files/937999#937999



### Collection & Sequence

> kotlin提供了基于不同执行方式的两种集合类型：
>
> - **立即执行的 Collection类型**
> - **延迟执行的 Sequence类型**

`立即执行`和`延迟执行`的区别在于`每次对集合进行转换时，这个操作会在何时真正执行。`



#### Collection

> 在每次操作时都是立即执行的，执行结果都会存储到一个新的集合中。

```kotlin
//_Collections.kt
public inline fun <T, R> Iterable<T>.map(transform: (T) -> R): List<R> {
    return mapTo(ArrayList<R>(collectionSizeOrDefault(10)), transform)
}
```

`Collection`内部的每一步操作都会生成一个新的集合。



#### Sequence

> 是延迟执行的，主要有两种类型：
>
> - **中间操作**：不会立即执行，所有中间操作的引用会存储起来
> - **末端操作**：立即执行，按照顺序执行存储的`中间操作`

```kotlin
//_Sequences.kt
//中间操作
public fun <T, R> Sequence<T>.map(transform: (T) -> R): Sequence<R> {
    return TransformingSequence(this, transform)
}

internal class TransformingSequence<T, R>
constructor(private val sequence: Sequence<T>, private val transformer: (T) -> R) : Sequence<R> {
    override fun iterator(): Iterator<R> = object : Iterator<R> {
        val iterator = sequence.iterator()
        override fun next(): R {
            return transformer(iterator.next())
        }

        override fun hasNext(): Boolean {
            return iterator.hasNext()
        }
    }
}

//末端操作
public inline fun <T> Sequence<T>.first(predicate: (T) -> Boolean): T {
    for (element in this) if (predicate(element)) return element
    throw NoSuchElementException("Sequence contains no element matching the predicate.")
}

```

最后调用`first()、count()`等`末端操作`之后，内部去遍历`Sequence`中的元素，挨个执行直到条件匹配为止。



#### 性能

##### 转换的顺序

`.filter{}.map{}` 性能是优于 `.map{}.filter{}`



##### 数据量的选择

`Collection`会为每次转换操作创建一个新的列表，而`Sequence`仅仅是保留对转换函数的引用。

> 根据需要处理的数据量大小，按照如下规则选择：
>
> - 数据量小 使用 Collection
> - 数据量大 使用 Sequence