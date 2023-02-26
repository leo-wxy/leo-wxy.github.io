---
title: Rust初识
typora-root-url: ../
date: 2023-02-26 14:51:13
tags: Rust
mathjax: true
top: 10
---

> Rust——一门赋予每个人构建可靠且高效软件能力的语言。
>
> **Rust编译器教你写代码！**

## 为什么选择Rust？

- **高性能**：速度惊人且内存利用率极高
- **可靠性**：保证内存安全和线程安全，可以在编译期消除各种各样的错误。
- **生产力**：出色的文档，友好的编译器和清晰的错误提示信息

## 安装Rust

以下皆以mac OS平台为主

```shell
# 下载脚本并安装rustup工具
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh

# 查看rust版本
rustc --version
```

### Rust更新与卸载

```shell
# rust更新
rustup update

# rust卸载
rustup self uninstall
```





### 使用Cargo

> Cargo是Rust的构建系统和包管理器

#### Cargo创建项目

```shell
cargo new hello_cargo
```

#### Cargo构建并运行项目

```shell
//构建
cargo build 
//运行
cargo run

//Release构建
cargo build --release 
```

## Rust编程概念

> 下述的示例代码均在[IDEA](https://www.jetbrains.com/idea/)下进行编译开发，需要安装[Rust插件](https://plugins.jetbrains.com/plugin/8182-rust)即可使用。

### 变量和可变性(`Variables`)

> 变量默认是**不可改变(immutable)**的。
>
> 可通过变量前添加`mut`使变量可变。

```rust
fn main(){
  let x = 5;
  x = 6 ;
} 

//编译时直接报错，因为x默认是不可变的
//要使代码生效，需要添加mut

fn main(){
  let mut x = 5;
  x = 6;
}

//编译成功
```

#### 常量(`Const`)

> 常量在整个程序的生命周期中都有效，而且永不可变。

```rust
const ONE_HOUR_IN_SECOND = 60 * 60;
```

#### 隐藏(`Shadowing`)

> 可以定义一个与之前变量同名的新变量，此时第一个变量被第二个变量**隐藏**了，编译器只会看到第二个变量。

```rust
fn main(){
  let a = 100;
  println!("before a = {a}"); //输出100

    {
        let a = "sss";
        println!("a = {a}"); //输出 sss

        let a = true;
        println!("a = {a}"); //输出 true
    }

    println!("after a = {a}"); //输出100
}
```

上述代码简单示例了`Scope`及`Shadowing`，此时进入`{}`中，表示新开了个作用域(Scope)，此时`a`的逻辑仅在`{}`有效，后续定义的`let a = true;`表示之前的`let a = sss`已被隐藏。



### 数据类型

> 每一个值都属于`数据类型`，必须明确每个值的数据类型，保证功能正常。

#### 标量类型(Scalar Type)

> 代表一个单独的值。

##### 整型(`integers`)

> 默认为`i32`

|                                                              | 类型                                  | 示例               |
| ------------------------------------------------------------ | ------------------------------------- | ------------------ |
| 有符号整型(以`i`开头)<br />存储包含 **-(2^(n-1)) ~ 2^(n-1) -1** 之内的数字 | `i8`,`i16`,`i32`,`i64`,`i128`,`isize` | -10,0,1_000,123i64 |
| 无符号整型(以`u`开头)<br />存储包含 **0 ~ 2^n -1** 之内的数字 | `u8`,`u16`,`u32`,`u64`,`u128`,`usize` | 0,123,10u16        |

其中`isize`,`usize`依赖运行程序的计算机架构：`64位架构上则为64位，32位架构则为32位。`

> 整型溢出：定义的数据类型，无法承载所设置的值。
>
> 系统默认处理方式：比此类型能容纳的最大值还大的值会绕到最小值，例如定义`u8`最大为256，设置值为`256`，则输出的值为`0`。

```rust
let a:i32 = 100;
```



##### 浮点型(floating-point)

> 默认为`f64`

|        | 类型        | 示例      |
| ------ | ----------- | --------- |
| 浮点型 | `f32`,`f64` | 3.14,2f32 |

参考[运算符](https://kaisery.github.io/trpl-zh-cn/appendix-02-operators.html)可以使用所有数字类型进行运算。

```rust
let x:f32 = 2.0;
```



##### 布尔型(bool)

|        | 类型   | 示例        |
| ------ | ------ | ----------- |
| 布尔型 | `bool` | true ,false |

```rust
let x : bool = true;
```



##### 字符型(char)

|        | 类型   | 示例        |
| ------ | ------ | ----------- |
| 字符型 | `char` | 'a','ℤ','😻' |

使用`''`声明`char`字面量。

```rust
let x:char = 'z';
```



##### 字符串类型(String)

|          | 类型   | 示例  |
| -------- | ------ | ----- |
| 字符串型 | `&str` | "wxy" |

```rust
let x: &str = "Hello World";
```

#### 复合类型(Compound Type)

> 将多个值组合成一个类型

##### 元组类型(tuple)

> 将多个其他类型的值组合进一个复合类型的主要方式。
>
> **元组长度固定，一旦声明，长度不会增大或缩小。**

|          | 类型                                                         | 示例                |
| -------- | ------------------------------------------------------------ | ------------------- |
| 元组类型 | `()`,`(T)`,`(T1,T2)`<br />其中T表示具体数据类型，例如`(i32, f64, u8)` | (123),(500, 6.4, 1) |

使用包含在`()`中的`,`分割的值列表来创建一个元组，每一个位置都有一个对应的类型。

```rust
fn main(){
  let t: (i8, bool, &str) = (7, true, "hello");
  
  let (x,y,z) = t; //此时x 对应 7
  
  //也可通过 t.0 输出 7 
  let a = t.0 //此时a为7
}
```

> 单元元组`()`：不带任何值的元组，表示空值或空的返回类型。
> **可类比Java中的`void`**



##### 数组类型(array)

> 数组中每个元素的类型必须相同。
>
> **数组长度是固定的。**

|          | 类型                                                         | 示例              |
| -------- | ------------------------------------------------------------ | ----------------- |
| 数组类型 | `[T;N]`<br />其中T表示具体数据类型，N表示数组个数，例如`(i32;5)` | [0;3],[1,2,3,4,5] |

存在两种写法

```rust
let a : [i32;5] = [1,2,3,4,5]

let a : [i32;5] = [3;5] 
// 等价于 [3,3,3,3,3]
```

与其他语言访问数组元素方法一致

```rust
let a : [i32;5] = [1,2,3,4,5]

a[0] // 1
```

数组的打印方式与一般类型打印方式不同

```rust
    let mut a: [i8; 10] = [42; 10];
    println!("a:{a:?}");
    //或者如下方式
    println!("a:{a:#?}"); //打印出来更好看
```



### 函数(`Functions`)





### 控制流(`Control Flow`)





## 参考资料

[Rust官网](https://www.rust-lang.org/)

[Rust程序设计语言](https://kaisery.github.io/trpl-zh-cn/title-page.html)

[给Android开发者的Rust综合学习(Google出品)](https://google.github.io/comprehensive-rust/welcome.html)

