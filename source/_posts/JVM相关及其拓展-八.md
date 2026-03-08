---
title: JVM相关及其拓展(八) — 静态分派&动态分派
date: 2019-02-21 13:10:28
tags: JVM
top: 11
---



## 方法调用

方法调用不同于方法执行，方法调用阶段唯一的任务就是**确定被调用方法的版本(即调用哪一个方法)**。

从字节码指令的角度看，Java中常见的方法调用指令有`invokestatic、invokespecial、invokevirtual、invokeinterface`（以及更偏动态语言支持的`invokedynamic`）。其中“解析”更偏向于在满足条件时把常量池里的符号引用提前确定下来；“分派”则更偏向于在多态语义下决定最终应该落到哪个方法版本上。

如果先做一个粗粒度划分，可以这样理解：

- `invokestatic`：调用静态方法，更偏“类级别确定”
- `invokespecial`：常用于私有方法、构造器、父类方法调用，更偏“目标版本事先确定”
- `invokevirtual`：常见实例方法调用，最典型的动态分派入口
- `invokeinterface`：接口方法调用，也需要根据实际接收者类型在运行期确定实现

因此在分析“这次调用到底是解析还是分派”时，可以先看它更接近哪类字节码指令语义。

## 解析

> 调用目标在代码程序写好、编译器进行编译时就必须确定下来。

在Java语言中符合“编译期可知，运行期不可变”这个要求的方法，主要包括`静态方法`和`私有方法`两大类。前者与类型直接关联，后者在外部不可访问，这两种方法各自的特点决定了它们都不可能通过继承或别的方式重写其他版本，因此它们都适合在类加载阶段进行解析。

在解析阶段中可以唯一确定的调用版本，符合这个条件的有`静态方法、私有方法、实例构造器，父类方法`四种。

换句话说，解析强调的是：**调用目标在真正执行之前就已经稳定确定**。这一类调用通常更接近`invokestatic`和`invokespecial`这类“目标版本相对固定”的指令；而像`invokevirtual`、`invokeinterface`更多会进入后面要说的分派过程。

这里也可以顺手补一个很容易混淆的边界：

- `静态方法`属于类，不依赖对象动态类型
- `私有方法`不会被子类重写
- `构造器`本来就不是普通继承重写语义下的方法调用
- `父类方法显式调用`（如`super.xxx()`）目标版本也相对固定

这些调用从Java语义上都不会表现出“根据运行时实际对象类型重新挑选覆盖实现”的那种动态多态效果。

另外，`final`实例方法虽然在字节码层面未必和`private/static/构造器`完全等价，但由于它不能被子类重写，所以从Java语义上看，也不具备典型运行时覆盖分派所带来的多态效果。


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

如果把这件事压缩成一句最值得记住的话，就是：

- **重载看静态类型**
- **重写看实际接收者类型**

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

几个特别常见的重载陷阱也值得单独记一下：

- 传入`null`时，如果多个重载版本都能匹配引用类型，可能会出现二义性
- 基本类型拓宽、装箱/拆箱、可变参数之间是有优先级顺序的，不能只靠直觉判断
- 可变参数通常属于“最后兜底”方案，所以很多时候不会优先命中

因此分析重载时，除了看“哪个方法能调”，还要继续问一句：**编译器最终会认为哪个版本更具体。**

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

这也正好解释了一个最经典的问题：为什么“父类引用指向子类对象”时，仍然能调用到子类重写方法？

本质原因是：

- 编译阶段只检查“这个方法在父类引用类型上是否合法可调用”
- 运行阶段真正执行时，仍然会从实际对象类型开始查找实现

所以向上转型改变的是**编译器看到的可调用范围**，而不是实例对象在运行期的真实类型。

这里还要再补一个常见误区：**字段访问不具备和方法重写一样的动态分派语义。**

也就是说：

- 方法调用会体现多态，可能根据实际对象类型走到子类实现
- 字段访问更多取决于引用的静态类型，而不是运行期对象的实际类型

因此“方法可多态”不等于“字段也会像方法一样重写”。

从分派的角度再向上总结一层：

- 方法重载更接近**静态多分派**，因为编译器会综合“方法接收者的静态类型 + 参数的静态类型”来决定重载版本。
- 方法重写更接近**运行时单分派**，因为运行时真正起决定作用的，主要是接收者的实际类型。

如果最后再给这篇加一个实用收束，可以记成三句话：

- 看重载，先看声明类型和参数静态类型
- 看重写，先看实际接收者类型
- 看字节码，再判断这次调用更接近解析还是分派
