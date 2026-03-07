---
title: JVM相关及其拓展(八) — 静态分派&动态分派
date: 2019-02-21 13:10:28
tags: JVM
top: 11
---



## 方法调用

方法调用不同于方法执行，方法调用阶段唯一的任务就是**确定被调用方法的版本(即调用哪一个方法)**。

从字节码指令的角度看，Java中常见的方法调用指令有`invokestatic、invokespecial、invokevirtual、invokeinterface`（以及更偏动态语言支持的`invokedynamic`）。其中“解析”更偏向于在满足条件时把常量池里的符号引用提前确定下来；“分派”则更偏向于在多态语义下决定最终应该落到哪个方法版本上。

## 解析

> 调用目标在代码程序写好、编译器进行编译时就必须确定下来。

在Java语言中符合“编译期可知，运行期不可变”这个要求的方法，主要包括`静态方法`和`私有方法`两大类。前者与类型直接关联，后者在外部不可访问，这两种方法各自的特点决定了它们都不可能通过继承或别的方式重写其他版本，因此它们都适合在类加载阶段进行解析。

在解析阶段中可以唯一确定的调用版本，符合这个条件的有`静态方法、私有方法、实例构造器，父类方法`四种。

换句话说，解析强调的是：**调用目标在真正执行之前就已经稳定确定**。这一类调用通常更接近`invokestatic`和`invokespecial`这类“目标版本相对固定”的指令；而像`invokevirtual`、`invokeinterface`更多会进入后面要说的分派过程。


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
        Human man = new Man();
    }
}
```

在`Human man =  new Man()`中，`Human`对应的变量的静态类型——**(引用类型)不会被改变，在编译期可知**。`Man`对应着变量的动态类型——**(实例对象类型)会发生变化，在运行期才可以确定**。

对于实例方法调用来说，真正参与运行期选择的其实是**接收者(Receiver)**。也就是这个方法最终是由哪个实际对象来接收并执行的。静态类型决定编译器“先按哪个范围去找候选方法”，动态类型则决定运行时“最终落到哪个实现版本”。

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

重载方法的选择并不是简单地“能调哪个就调哪个”，编译器会按更具体的匹配规则去选择更合适的版本。通常可以粗略理解为：

- 精确匹配优先，例如参数类型完全一致的方法版本会优先被选中。
- 其次才会考虑基本类型的拓宽转换，如`int -> long`。
- 再往后才会涉及自动装箱、拆箱。
- 可变参数方法通常属于更靠后的兜底选择。

另外还需要注意：**方法返回值并不参与重载决议**。也就是说，仅靠返回值不同并不能构成合法的方法重载。

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

如果把这个过程再展开一点，可以理解为：

1. 先拿到方法接收者在运行期的真实类型。
2. 从这个真实类型开始，按照继承关系向上查找签名匹配且可访问的方法。
3. 找到的第一个合适版本，就是这次调用最终要执行的方法实现。

因此，方法重写之所以能够成立，本质上就是：**虽然变量的静态类型可能是父类，但运行时查找方法时是从实际对象类型开始往上找的。**

从分派的角度再向上总结一层：

- 方法重载更接近**静态多分派**，因为编译器会综合“方法接收者的静态类型 + 参数的静态类型”来决定重载版本。
- 方法重写更接近**运行时单分派**，因为运行时真正起决定作用的，主要是接收者的实际类型。
