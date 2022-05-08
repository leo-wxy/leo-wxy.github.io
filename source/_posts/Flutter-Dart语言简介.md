---
title: Flutter-Dart语言简介
typora-root-url: ../
date: 2021-02-10 11:11:32
tags: Flutter
top: 9
---



> `Dart`语言设计借鉴了`Java`和`JavaScript`，同时存在了两者的特性。



## Dart变量声明

```dart
var name = 'wxy';
```

表示`名字是name的变量包含一个指向值为 bob 的字符串对象引用`。

当前`name`的类型被推断为`String`，当然也可以通过直接指定`变量类型`，例如`String name ='wxy';`



### 内置类型

> 主要支持`数字、字符串、布尔、数组，集合`等数据类型。

#### 数字类型

```dart
int i = 0;
num i = 0;
double y = 20.1;
```



- `int`
- `double`
- `num`
- `long`
- ...

#### 字符串类型

```dart
String name = "wxy";
String a = "a"+"b";
String b= "${a}" //类似kotlin的表达式
```



#### 布尔类型

```dart
bool a = true;
```



#### 列表类型

> 主要是`List`和`Set`，其中`List`允许重复元素，`Set`不允许。
>
> `List`使用`[]`表示
>
> `Set`使用`{}`表示

```dart
List a = [1,2,3];

List b = [0,...a]; //将a添加到b中

Set c = {1,2};
Set<String> d = {"a","b"};
```

#### 集合类型

> 主要是`Map`，以`键值对`形式存储元素。

```dart
Map map = {
  'a' : 'b',
  'c' : 'd'
}
```



整体的使用方式与`Kotlin`类似，熟悉Kotlin的话可以很快上手`Dart`的使用。



### 变量声明

#### var 

> 可以接收任何类型的变量，但是一旦被赋值，类型就会确定且无法改变。

```dart
var t;
t = "aaa" ; //此时t已确定为 String，无法再被改变
t = 123; //无法更改
```



#### dynamic/Object

> `dynamic`表示**动态类型**，在编译期间不会进行任何的类型检查，而是在运行时进行检查

```dart
dynamic t ;

t = "123"
  
t = 123;

```



> `Object`是所有对象的基类，可以赋值任意对象。而且也支持在后期修改值。

```dart
Object a ;
a = "123";
a = 123;
```



`dynamic和Object`主要区别在于：

`dynamic`在声明的时候可以调用所有可能支持的方法，例如`length`之类

`Object`在声明的时候只能调用`Object`的方法，其他方法都无法调用

```dart
dynamic a ;
Object b;

a = "123";
b = "123";

print(a.length)； //可以调用
print(b.length)；//不可调用，只能调用Object相关的

```

**使用`dynamic`需要注意 可能引入的运行时错误。**

#### final/const

> 主要做**常量声明**。*被修饰的变量无法被修改。*
>
> `const`用于表示`编译时常量`
>
> `final`在`第一次使用时被初始化`。//需要到运行时才能确定值

```dart
final str = "wxy"; //等价于 final String str = "wxy"

const str1 = "haha"; //等价于 const String str1 ="haha"

//在使用const/final时可以省略变量类型。
```



## Dart逻辑语句与操作符

### 逻辑语句

- `if else`
- `switch`
- `while`

### 操作符

- `..`级联操作符

  > 对类的内部成员进行链式调用

  ```dart
  Event event = Event();
  event
    ..id = 1
    ..type = ""
  ```

  

- `??`赋值操作符

  ```dart
  a ?? "123" //a为空，返回123
  a ??= "123" //a为空，值为123
  a ~/ 2 //a整除2
  ```

- 重载操作符

  ```dart
  class A {
    int a, b;
  
    A(this.a, this.b);
  
    A operator +(A c) => A(a + c.a, b + c.b);
    
  }
  
  //使用示例
  void main(){
    var aa = A(1, 3);
    var bb = A(2, 3);
    print(aa + bb); //3,6
  }
  ```

  支持重载的操作符如下：

  |      |      |      |      |
  | ---- | ---- | ---- | ---- |
  | >    | /    | ^    | []=  |
  | <=   | ~/   | &    | ~    |
  | >=   | **   | <<   | ==   |
  | -    | %    | >>   |      |
  | <    | +    | \|   | []   |

  

## Dart函数

> **函数也是对象**
>
> `函数可以赋值给变量或作为参数传递给其他函数——函数式编程`。



### 函数声明

```dart
void getData(String name,int age){
  // ... 
}
```

### 作为变量/参数

```dart
  var say = (str){
    print(str);
  }; //等价于 void say(String str){...}

  void execute(void callback(str)) {
    callback("124");
  }

//调用示例
  execute((str) {
    print(str);
  });

```



### 可选位置/命名参数

```dart
void test(String a, b, [c]) {} //可以设置c

void test1(String a, b , {c : "123"}){} //不设置c，则值为123

void test3(String a, b, {String c}) {} //c为可选参数，若设置必须使用 c:"123"

//使用示例
test("1","2")
test("1","2","3") //都可以
  
test1("1","2")
test1("1","2",c:"3") //都可以
test2("1","2")
test2("1","2",c:"3") //都可以
  

```

**不能同时使用`可选位置参数`和`可选命名参数`。**

## Dart类、接口和继承

> 

## Dart线程操作





## 参考链接

[Dart代码风格参考](https://dart.dev/guides/language/effective-dart/design)