---
title: Java - 泛型
date: 2019-01-02 16:39:03
tags: Java
top: 10
---

{% fullimage /images/泛型.png,泛型,泛型%}

## 泛型基本概念

> Java泛型是JDK 5中引入的一个新特性，允许在定义类和接口的时候使用类型参数(`type parameter`)。声明的类型参数在使用时用具体的类型来替换。
>
> **本质上是编译器为了提供更好的可读性而提供的一种方式，JVM中是不存在泛型的概念的。**

泛型的出现在很大程度上是为了方便集合的使用，使其能够记住元素的数据类型。泛型是对Java语言类型系统的一种拓展，可以把类型参数看作是使用参数化类型时指定的类型的一个占位符。

### 泛型的好处

1. **类型安全**。类型错误可以在编译期直接被捕获到，而不是在运行时抛出`ClassCastException(类型转换错误)`，有助于开发者方便找到错误，提高可靠性。
2. **减少代码中的强制类型转换**。增强代码可读性

## 泛型的类型通配符

> 匹配任意类型的类型实参。**通配符往往用于方法的形参中，不允许在定义和调用中使用。**

### 无界通配符(非限定通配符)——`?`

通配任意一种类型，可以用任意类型进行替代。

```java
public class GenericTest {
    public static void main(String[] args){
        List<? extends Number> list = new ArrayList<Integer>();
        test(list);
    }

    //可以传入任意类型的List
    public static void test(List<?> list){
        for (Object o : list) {
            System.err.println(o);
        }
    }
}
```

### 带限通配符(限定通配符)

> 限制泛型的类型参数的类型，使其满足条件，限制在一些类中。

#### 上限通配符——`? extends T`

> 确保泛型类型必须是T的子类来设定类型的上界。**使用`extends`关键字制定这个类型必须是继承某个类或者实现某个接口，也可以是这个类或者接口本身。**
>
> 使用时

```java
public class GenericTest {
    public static void main(String[] args){
        List<Integer> upList = new ArrayList<>();
        upTest(upList);
    }
    //设定集合中的所有元素必须是Number的子类，例如Integer
    public static void upTest(List<? extends Number> list){
        for (Number number : list) {
            System.err.println(number);
        }
    }
}
```

> 在Java中父类型可以持有子类型。如果一个父类的容器可以持有子类的容器，那么就称之为**协变**。
>
> 可以利用`上限通配符`实现`协变`。

#### 下限通配符——`? super T`

> 确保泛型类型必须是T的父类来设定类型的下界。**使用`super`关键字指定这个类型必须是某个类的父类或者某个接口的父接口，也可以是这个类或者接口本身。**

```java
public class GenericTest {
    public static void main(String[] args){
        List<Number> downList = new ArrayList<>();
        downTest(downList);
    }
    //设定集合中的所有元素必须是Integer的父类，例如Number
    public static void downTest(List<? super Integer> list){
        for (Object o : list) {
            System.err.println(o);
        }
    }
}
```

> 如果一个类的父类型容器可以持有该类的子类型的容器，那么称之为**逆变**。
>
> 可以利用`下限通配符`实现`逆变`。

### PECS原则

> **Producter Extends ，Consumer Super**。

`Producter Extends`：如果你只需要一个只读List，那么使用`? extends T`。

> 无法确定写入类型，所以禁止写入会编译错误。只能对外提供数据。

`Consumer Super`：如果你只需要一个只写List，那么使用`? super T`

> 写入类型都是其父类，是可以确定的。但是无论怎样取出的值都会是`Object`型，是无意义的。

**如果需要同时读取以及写入，就不能使用通配符。**

### 通配符的只读性

通配符代表了不确定的类型，无法了解到这个容器中放的是什么类型的数据，所有只有只读性，不能往里面去添加元素。

## 泛型的类型擦除

> 泛型只能用于在编译期间的静态类型检查，然后编译器生成的代码会擦除相应的类型信息。成功编译过后的Class文件是不会包含任何泛型信息的，泛型信息不会进入到运行时阶段。
>
> 例如`List<String>`在运行时用`List`表示，为了确保Java 5之前的版本可以进行兼容。

### 实例分析

```java
    public static void typeErasure(){
        Class c1 = new ArrayList<Integer>().getClass();
        Class c2 = new ArrayList<String>().getClass();
        System.err.println(c1 == c2);
    }

运行结果：
true
```

反编译即观察得到的.class

```java
    public static void typeErasure() {
        Class c1 = (new ArrayList()).getClass();
        Class c2 = (new ArrayList()).getClass();
        System.err.println(c1 == c2);
    }
都被转成为ArrayList的类型，原先的泛型都被擦除。
```

### 类型擦除基本过程

1. 找到用来替换类型参数的具体类，一般都是`Object`。如果指定类类型参数的上界话，就会采用上界。

   ```java
   未设置上界：List<Integer>  -->  List<Object>
   设置上界：List<T extends Number> --> List<Number>
   ```

   > 设置边界：重用了 `extends`关键字。可以将类型参数的范围限制到一个子集中。
   >
   > 设置边界时有两个注意事项：
   >
   > - 类必须写在接口之前
   > - 只能设置一个类做边界，其他只能是接口

2. 把代码中的类型参数都替换成具体的类，同时去掉出现的类型声明，即去掉`<>`内容。

   ```java
   List<Integer> --> List
   ```

3. 再生成一些桥接方法。这是由于擦除了类型之后的类可能缺少某些必须方法。

### 类型擦除基本原理

在编译过程中，类型变量的信息是可以拿到的。所以在`set()`中编译器可以做类型检查，非法类型无法通过编译。对于`get()`，由于擦除机制，得到的大部分都为`Object`，编译器会在`get()`之后做一个类型转换，转成对应的类型。

### 类型擦除缺陷

#### 无法创建泛型数组

> Array无法提供编译期的类型安全保障，由于运行期就把泛型擦除了，编译器无法判断类型。

一般是无法创建的，推荐使用`ArrayList`来实现数组。如果硬要创建，就需要用到反射去实现。

```java
class GenericArrayWithType<T> {
    T[] array;

    @SuppressWarnings("unchecked")
    public GenericArrayWithType(Class<T> type, int size) {
        //使用反射中的Array类型 newInstance创建实例对象
        array = (T[]) Array.newInstance(type, size);
    }

    public void put(int index, T item) {
        array[index] = item;
    }
}

GenericArrayWithType<Integer> genericArrayWithType = new GenericArrayWithType<>(Integer.class, 10);
genericArrayWithType.put(0, 2);
```



#### 泛型不能显式地运用在运行时类型的操作当中，例如`instanceOf、new`

> 由于系统中并不会真正生成泛型类，而且在运行时，所有参数的类型信息都已经被擦除。

可以使用显式工厂模式，避免上述问题。



#### 泛型的类型参数不能用在`catch`中

> 异常处理是由JVM在运行时刻进行的。由于类型擦除，JVM无法区分异常类型。对于JVM来说他们是没有区别的，也就无法正常执行对应的`catch`语句。

## 泛型的基本使用

#### 泛型类

> 基本格式 ： 
>
> **访问修饰符 class 类名<限定类型变量名>**
>
> 例如 ： `public class Box<T>`

首先定义一个简单的Box类

```java
public class Box{
  private String object;
  public void set(String object){this.object = object;}
  public String get() {return object;}
}
```

这时的Box类内部只能接收`String`型参数，如果需要其他类型就需要重写另外一个，这时就可以用泛型类解决这个问题。

```java
public class Box<T>{
  private T t;
  public void set(T t){this.t=t;}
  public T get() {return t;}
}
```

这时的Box类便可以支持其他类型参数，可以把`T`折换成任意类型

```java
Box<Integer> integerBox = new Box<Integer>();
Box<String> stringBox = new Box<String>();
```



#### 泛型接口

> 基本格式 ： 
>
> **访问修饰符 interface 接口名<限定类型变量名>**
>
> 例如 ： `public interface Box<T>`

```java
interface Box<T>{
    T create();
}

class IntegerBox implements Box<Integer>{

    @Override
    public Integer create() {
        return null;
    }
}

class StringBox implements Box<String>{

    @Override
    public String create() {
        return null;
    }
}
```

#### 泛型方法

> 基本格式 ： 
>
> **访问修饰符 <T,S> 返回值类型 方法名 (形参列表)**
>
> 例如 ： `public <T> void showBox(T t)`

```java
    public static <T> void show(T t) {
        System.err.println(t);
    }

    //支持返回泛型类型
    public static <T> T show(T t) {
        System.err.println(t);
      return t;
    }
```

泛型方法中定义的形参只能在该方法中使用，但是接口、类中定义的形参可以在这个接口、类中使用。



#### 泛型构造器

> 基本格式 ： 
>
> **访问修饰符 class 类名 {**
>
>   **访问修饰符 <T> 类名 (形参列表){}** 
>
> **}**
>
> 例如 ： `public class Box{`
>
> `public <T> Box (T t){}`
>
> `}`

使用泛型构造器有两种方式：

1. 显式指定泛型参数

   ```java
   new <String>Box("a")
   ```

2. 隐式推断

   ```java
   new Box("a")
   ```

   

### 泛型注意事项

- **任何基本类型都不能作为类型参数**

-  **无法进行重载**

  > 由于擦除的原因，重载方法将产生相同的类型签名。避免这种问题的方法就是换个方法名

  

  

### 内容引用

[Java泛型详解](http://www.importnew.com/24029.html)

[Java泛型进阶](https://www.jianshu.com/p/4caf2567f91d)