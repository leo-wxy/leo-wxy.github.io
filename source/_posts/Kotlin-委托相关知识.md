---
title: Kotlin-委托相关知识
date: 2019-07-09 22:53:12
tags: Kotlin
top: 10
---

> 委托：有两个对象参与处理同一个请求，接受请求的对象将请求委托给另一个对象来处理。

在Kotlin中，对`委托`进行了简化，通过`by`就可以实现委托的效果。例如前面提到的`by lazy`延迟初始化就是利用了`委托`。

Kotlin中主要分为两种：**类委托、委托属性**。

基本语法:

```kotlin
val/var <属性名>:<类型> by <表达式> //<表达式> 指向委托
```

## 类委托

> 在不使用继承的情况下，拓展一个类的功能，使之提供更多的功能。类似`装饰模式`。
> 
> `装饰模式`的缺点就是需要较多的样板代码，装饰类需要实现接口的全部方法，并需要调用到原始对象的方法。

Kotlin可以**零样板代码进行原生支持**，通过`by`关键字进行实现。

```kotlin
interface Base {
    fun print()
}

class BaseImpl(val x: Int) : Base {
    override fun print() {
        print(x)
    }
}

class Derived(b: Base) : Base by b

fun main(args: Array<String>) {
    val b = BaseImpl(10)
    Derived(b).print()
}
```

利用`by`，将新类的接口委托给原始对象，生成后的新类会自动生成接口方法，并默认返回原始类的具体实现。

```java
public final class Derived implements Base {
   // $FF: synthetic field
   private final Base $$delegate_0;

   public Derived(@NotNull Base b) {
      Intrinsics.checkParameterIsNotNull(b, "b");
      super();
      this.$$delegate_0 = b;
   }

   public void print() {
      this.$$delegate_0.print();
   }
}
```

观察上述反编译后的Java代码，看到实际生成的`Derived`已经默认实现了接口方法。可以按照需求去重载某些方法，而不必写过多的样板代码。

## 委托属性

> 将属性的访问器(`get()、set()`)委托给一个符合属性委托约定规则的对象。

委托属性对象规则：

- 对于一个**只读属性(`val`声明)**，委托必须提供一个名为`getValue()`的函数。
  
  ```kotlin
  /**
  * 只读属性
  */
  interface ReadOnlyProperty<in R, out T> { 
    /**
    * [thisRef] 必须与属性所有者类型相同或者是它的超类
    * [property] 必须是KProperty<*>或其超类
    * [T] 返回与属性相同的类型
    */
    operator fun getValue(thisRef: R, property: KProperty<*>): T 
  }
  ```
  
  `ReadOnlyProperty`由Kotlin提供的接口，方便开发者使用于`val`声明变量

- 对于一个**可变属性(`var`声明)**，委托必须额外提供一个`setValue()`
  
  ```kotlin
  /**
  * 可变属性
  */
  interface ReadWriteProperty<in R, T> { 
    operator fun getValue(thisRef: R, property: KProperty<*>): T 
    /**
    * [value] 必须与属性同类型或者超类
    */
    operator fun setValue(thisRef: R, property: KProperty<*>, value: T) 
  }
  ```
  
  `ReadWriteProperty`由Kotlin提供的接口，方便开发者使用于`var`声明变量

使用示例：

```kotlin
class Person{
    var name:String by MyDelegate()
}

class MyDelegate : ReadWriteProperty<Any?,String>{

    override fun getValue(thisRef: Any?, property: KProperty<*>): String {
        return "Kotlin"
    }

    override fun setValue(thisRef: Any?, property: KProperty<*>, value: String) {

    }
}
```

## Kotlin自带委托

### 延迟初始化

> 利用`变量 by lazy`可以实现 延迟初始化。

#### 使用示例

```kotlin
class Demo(){
        val sex: String by lazy {
        "male"
    }
}
```

`lazy`接收初始化值的`lambda`，并返回一个`Lazy<T>`类型的委托对象。

#### 原理分析

先看一句话版本：`by lazy`会把属性访问交给`Lazy`委托对象，首次访问才执行初始化代码并缓存结果，后续读取直接返回缓存值。

`val sex: String by lazy { "male" }`编译后大致等价于：

```kotlin
private val sex$delegate: Lazy<String> = lazy { "male" }

val sex: String
    get() = sex$delegate.getValue(this, this::sex)
```

`Lazy`本身只定义了“取值”和“是否已初始化”两个核心能力：

```kotlin
public interface Lazy<out T> {
    public val value: T
    public fun isInitialized(): Boolean
}

public operator fun <T> Lazy<T>.getValue(thisRef: Any?, property: KProperty<*>): T = value
```

第一次访问`sex`时会触发`initializer`并缓存结果；之后再次访问会直接返回缓存值，不会重复执行初始化逻辑。

默认情况下，`lazy`使用`LazyThreadSafetyMode.SYNCHRONIZED`保证多线程安全。其核心思路是“双重判断 + synchronized”：

```kotlin
private class SynchronizedLazyImpl<T>(initializer: () -> T) : Lazy<T> {
    private var _value: Any? = UNINITIALIZED_VALUE
    private var initializer: (() -> T)? = initializer

    override val value: T
        get() {
            if (_value !== UNINITIALIZED_VALUE) return _value as T
            return synchronized(this) {
                if (_value === UNINITIALIZED_VALUE) {
                    _value = initializer!!()
                    initializer = null
                }
                _value as T
            }
        }
}
```

另外还可以根据场景指定线程模式：

- `SYNCHRONIZED`：默认模式，线程安全；
- `PUBLICATION`：可能并发执行多次初始化，但只发布一个结果；
- `NONE`：不做线程同步，性能最好，适合单线程场景（如主线程）。



### 属性改变通知

> 通过调用`value by Delegates.observable(value)`来监听`value`的数据变化。
> 
> 另外还提供了`value by Delegates.vetoable(value)`也同样起到监听的效果，但是该方法返回一个`Boolean`类型来**判断是否需要对value进行赋值。**

#### 使用示例

```kotlin
		//对age的数据变化进行监听   
		var age: Int by Delegates.observable(age) { property, oldValue, newValue ->
        println("${property.name} oldValue=>$oldValue newValue=>$newValue")
    }

		age = 3 //初始赋值
		age = 4 //age oldValue=>3 newValue=>4
		println(age) // 4

		var age: Int by Delegates.vetoable(age) { property, oldValue, newValue ->
        println("${property.name} oldValue=>$oldValue newValue=>$newValue")
        true// true代表监听并修改数据  false只监听不修改对应数据
    }

		age = 3 //初始赋值
		age = 4 //age oldValue=>3 newValue=>4
    println(age) //为true 4 为false 3
```

#### 原理分析

先分析`Delegates`相关代码的实现

```kotlin
public inline fun <T> observable(initialValue: T, crossinline onChange: (property: KProperty<*>, oldValue: T, newValue: T) -> Unit):
        ReadWriteProperty<Any?, T> = object : ObservableProperty<T>(initialValue) {
            override fun afterChange(property: KProperty<*>, oldValue: T, newValue: T) = onChange(property, oldValue, newValue)
        }

public inline fun <T> vetoable(initialValue: T, crossinline onChange: (property: KProperty<*>, oldValue: T, newValue: T) -> Boolean):
            ReadWriteProperty<Any?, T> =
        object : ObservableProperty<T>(initialValue) {
            override fun beforeChange(property: KProperty<*>, oldValue: T, newValue: T): Boolean = onChange(property, oldValue, newValue)
        }
```

`observable`通过`ObservableProperty.afterChange()`来监听变化，`vetoable`通过`ObservableProperty.beforeChange()`来监听变化并对数据的赋值进行拦截

```kotlin
public abstract class ObservableProperty<T>(initialValue: T) : ReadWriteProperty<Any?, T> {
    private var value = initialValue
    //在值修改前调用
    protected open fun beforeChange(property: KProperty<*>, oldValue: T, newValue: T): Boolean = true

    //在值修改后调用
    protected open fun afterChange(property: KProperty<*>, oldValue: T, newValue: T): Unit {}

    public override fun getValue(thisRef: Any?, property: KProperty<*>): T {
        return value
    }

    public override fun setValue(thisRef: Any?, property: KProperty<*>, value: T) {
        val oldValue = this.value
        //返回false 则不进行赋值操作
        if (!beforeChange(property, oldValue, value)) {
            return
        }
        this.value = value
        //调用继承类复写的 afterChange() 对应外部的则是`onChange`
        afterChange(property, oldValue, value)
    }
}
```

### 可变属性延迟初始化

> `by lazy`只对`val变量`可用，当变量为`var`时则无法使用，这时可以用`var value: String by Delegates.notNull<String>()`来表示。

#### 使用示例

```kotlin
class Demo{
  var value: String by Delegates.notNull<String>()
  
  init{
    //延迟初始化
    value = "init"
  }
}
```



#### 原理分析

```kotlin
public fun <T : Any> notNull(): ReadWriteProperty<Any?, T> = NotNullVar()

private class NotNullVar<T : Any> : ReadWriteProperty<Any?, T> {
    private var value: T? = null

    override fun getValue(thisRef: Any?, property: KProperty<*>): T {
        return value ?: throw IllegalStateException(
            "Property ${property.name} should be initialized before get."
        )
    }

    override fun setValue(thisRef: Any?, property: KProperty<*>, value: T) {
        this.value = value
    }
}

```

`Delegates.notNull()`会返回一个`ReadWriteProperty`实现：

- 初始状态下内部值为`null`；
- 如果在赋值之前读取属性，会抛出`IllegalStateException`；
- 一旦完成赋值，后续读写行为与普通`var`一致。

它适合“对象创建后再注入数据”的场景，例如在`onCreate()`、`initData()`中初始化，再在后续逻辑里访问。



## 自定义委托

> 当内置委托（`lazy`、`observable`、`notNull`）不能满足需求时，可以自定义委托，把属性的读写逻辑抽离成可复用组件。

#### 使用示例

```kotlin
class PreferenceDelegate(
    private val storage: MutableMap<String, Any?>,
    private val defaultValue: String = ""
) : ReadWriteProperty<Any?, String> {

    override fun getValue(thisRef: Any?, property: KProperty<*>): String {
        return storage[property.name] as? String ?: defaultValue
    }

    override fun setValue(thisRef: Any?, property: KProperty<*>, value: String) {
        storage[property.name] = value
    }
}

class UserSettings(storage: MutableMap<String, Any?>) {
    var token: String by PreferenceDelegate(storage)
    var userName: String by PreferenceDelegate(storage, "Guest")
}
```

通过委托，业务类只保留属性声明，具体存取规则交给委托类统一处理，减少重复代码。

#### 进阶：`provideDelegate`

`getValue()/setValue()`是在属性读写时触发；而`provideDelegate()`可以在属性绑定阶段做约束检查：

```kotlin
class NameDelegate {
    operator fun provideDelegate(thisRef: Any?, property: KProperty<*>): ReadWriteProperty<Any?, String> {
        require(property.name.endsWith("Name")) {
            "Property ${property.name} must end with Name"
        }
        return object : ReadWriteProperty<Any?, String> {
            private var value: String = ""

            override fun getValue(thisRef: Any?, property: KProperty<*>) = value

            override fun setValue(thisRef: Any?, property: KProperty<*>, value: String) {
                this.value = value
            }
        }
    }
}
```

这样可以在声明属性时就发现不符合约束的写法，尽早暴露问题。
