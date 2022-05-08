---
title: JVM相关及其拓展(八) — 静态分派&动态分派
date: 2019-02-21 13:10:28
tags: JVM
top: 11
---



## 方法调用

方法调用不同于方法执行，方法调用阶段唯一的任务就是**确定被调用方法的版本(即调用哪一个方法)**。

## 解析

> 调用目标在代码程序写好、编译器进行编译时就必须确定下来。

在Java语言中符合“编译期可知，运行期不可变”这个要求的方法，主要包括`静态方法`和`私有方法`两大类。前者与类型直接关联，后者在外部不可访问，这两种方法各自的特点决定了它们都不可能通过继承或别的方式重写其他版本，因此它们都适合在类加载阶段进行解析。

在解析阶段中可以唯一确定的调用版本，符合这个条件的有`静态方法、私有方法、实例构造器，父类方法`四种。


## 分派
Java具备面向对象的3个特性：**继承、封装和多态**。分派就体现了*多态*这一特征。

{% fullimage /images/方法分派.png,方法分派,方法分派%}

### 变量的静态&动态类型

```java
public class Test{
    static abstract class Human{
        
    }
    
    static class Man extends Human{
        
    }
    
    static class Woman extends Human{
        
    }
    public static void main(String[] args){
        Human man = new Human();
    }
}
```

在`Human man =  new Man()`中，`Human`对应的变量的静态类型——**(引用类型)不会被改变，在编译期可知**。`Man`对应着变量的动态类型——**(实例对象类型)会发生变化，在运行期才可以确定**。

### 静态分派

> **根据变量的静态类型来定位方法执行版本的分派动作**。静态分派发送在编译阶段，因此确定静态分派的动作实际上是不由虚拟机来执行的。

#### 应用场景

方法重载(`Overload`)

#### 实例说明

```java
public class TestStatic {
    static abstract class Human{}
    static  class Man extends Human{}
    static  class Woman extends Human{}

    public void sayHello(Human human){
        System.err.println("hello human");
    }
    public void sayHello(Man man){
        System.err.println("hello man");
    }
    public void sayHello(Woman woman){
        System.err.println("hello woman");
    }
    public static void main(String[] args){
        Human man = new Man() ;
        Man man1 = new Man();
        Woman woman = new Woman();
        Human human = new Woman();

        TestStatic testStatic = new TestStatic();
        testStatic.sayHello(man);
        testStatic.sayHello(man1);
        testStatic.sayHello(woman);
        testStatic.sayHello(human);
    }
}
```

得到的最终结果是：

```java
hello human
hello man
hello woman
hello human
```

观察发现，最终得到的结果是根据变量的`静态类型`最终得出的。这是由于*编译器虽然能确定方法的重载版本，但是很多情况下重载方法并不唯一，最终仍需确认一个合适的版本，就选用到了 变量的静态类型作为 实际参数。*

#### 注意事项

##### 变量的静态类型发生变化

> 通过`强制类型转换`改变变量的静态类型

```Java
Human man = new Man()
   
test.sayHello((Man)man)
```

得到的最终结果就会变为`hello man`。

##### 匹配优先级

> 当程序中没有显示指定变量的静态类型时，程序需要根据`静态类型的优先级`确定`优先的静态类型`进行方法分配。

### 动态分派

> **根据变量的动态类型进行方法分派**。动态分派发生在运行阶段。

#### 应用场景

方法重写(`Override`)

#### 实例说明

```java
class Human{
    public void sayHello(){
        System.out.println("hello human");
    }
}

class Man extends Human {
    @Override
    public void sayHello() {
        System.err.println("hello man");
    }
}

class Woman extends Human {
    @Override
    public void sayHello() {
        System.err.println("hello woman");
    }
}

public class Test{
    public static void main(String[] args){
        Human man = new Man();
        man.sayHello();
        
        Human human = new Human();
        human.sayHello();
        
        Woman woman = new Woman();
        woman.sayHello();
    }
}
```

运行结果：

```java
hello man
hello human
hello woman
```

观察发现，最终得出的结果是根据变量的`动态类型`最终得出的。利用`invokevirtual`指令来执行动态分派。执行步骤分为两步：

1. 确定接受者的动态类型
2. 将 常量池中的 类方法符号引用 解析到不同的直接引用上。

