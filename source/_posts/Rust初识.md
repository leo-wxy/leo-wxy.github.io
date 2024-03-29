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

##### 字符串(&str/String)

###### &str / &String

> 字符串字面量类型为`&str`。
>
> `&String`是String的borrow类型，可以看作`&str`
>
> 不可变的固定长度的字符串。

```rust
fn main(){
  let s: &str = "hello, world";
}
```



###### String

> `String`是定义在标准库中的类型，分配在`堆`上，可以动态的增长。底层存储为`动态字节数组`。
>
> **String是 UTF-8编码的。**

- 新建字符串

  > 主要有如下方式
  >
  > - **String::new()**
  > - **String::from("")**
  > - **"".to_string()**

  ```rust
  fn main() {
      // let mut s = String::new(); //新建一个空的String
      let mut s = String::from(""); //从字符串创建String
      // let mut s = "".to_string(); //同上
      s.push_str("hello, world");
      s.push('!');
  
      assert_eq!(s, "hello, world!");
  }
  ```

  

- 更新字符串

  > 主要有如下方式
  >
  > - **push( ch: char)**
  > - **push_str(string: &str)**
  > - **+string:&str**
  > - **replace(string: &str)**
  > - **format!()**

  ```rust
  fn main(){
      let mut s2: String = String::from("Hello "); //Hello
      s2.push('W'); //Hello W
      s2.push_str("or"); //Hello Wor
      s2+="ld"; //Hello World
      s2 = s2.replace("W","w"); //Hello world
      println!("s2: {s2}");
  }
  
  fn main1(){
      let ss1 = String::from("tic");
      let ss2 = String::from("toc");
      let ss3 = String::from("toe");
  
      let hh = format!("{ss1}-{ss2}-{ss3}");
      println!("hh: {hh}"); //tic-toc-toe
  
  }
  ```

  注意事项：

  > 当使用`+`进行字符串拼接时，只能用`String`与`&str`进行拼接，并且此时的`String`的所有权会在此过程中被move(后续所有权会介绍)

  ```rust
  fn main() {
      let s1 = String::from("hello,");
      let s2 = String::from("world!");
      let s3 = s1 + &s2; //需要使用& 将String转换为&str
      assert_eq!(s3,"hello,world!");
      println!("{}",s1); //报错 value borrowed here after move
      println!("{}",s2);
  }
  ```

  

- 索引字符串

  > 例如`s[0]`在Rust下是无法使用的，主要由于底层为`Vec<u8>`的封装，按照字节长度进行返回。
  >
  > 想要实现索引功能，就需要依赖后面介绍的`Slice`相关，此处先写上示例代码

  ```rust
  fn main() {
      let s1 = String::from("hi,中国");
      let h = s1[0..1]; //  `h` 字符在 UTF-8 格式中只需要 1 个字节来表示
      assert_eq!(h, "h");
  
      let h1 = &s1[3..6];//  `中` 字符在 UTF-8 格式中需要 3 个字节来表示
      assert_eq!(h1, "中");
  }
  ```

  

- 遍历字符串

  > 按照字符(char)或字节(byte)对字符串进行便利
  >
  > - chars：字符
  > - bytes：字节

  ```rust
  fn main() {
      // 填空，打印出 "你好，世界" 中的每一个字符
      for c in "你好，世界".chars() {
          println!("{}", c)
      }
  }
  ```

###### &str与String相互转换

- &str => String

  ```rust
  fn test_str_to_string() {
      let a: &str = "Hello";
      let b = a.to_string();
      let c = String::from(a);
      let d = a.to_owned();
  }
  ```

  

- String => &str

  ```rust
  fn test_string_to_str() {
      let a = String::from("Hello");
      let b = a.as_str();
      let c = &a;
  
      let d = &String::from("Hello");
  }
  ```

###### &str与String的使用场景

> 如果只想要一个字符串的只读视图，或者作为一个函数的参数，首选 **`&str`**
>
> 如果想拥有所有权，或者修改字符串就使用 **`String`**

##### 切片(Slice)

> 跟数组类似，但是切片的长度无法在编译期得知。

###### 其他类型Slice

```rust
fn test_other_slice() {
    let a = [1, 2, 3, 4, 5];
    let slice = &a[0..3]; //[0,3)
    let slice2 = &a[..3];
    assert_eq!(slice,slice2);
    println!("{slice:?}")
}
```



###### 字符串Slice

```rust
```





##### 枚举(Enum)



##### 集合体(Struct)



### 函数(`Functions`)

> 使用`fn`来声明函数，其中`fn main()`是程序的入口点。

#### 参数

> 是函数签名的一部分，**必须声明每个参数的类型。**

```rust
fn another_function(x: i32) {
    println!("The value of x is: {x}");
}
```



#### 语句&表达式

> 函数体由一系列的语句和一个可选的结尾表达式构成。

- **语句**：执行一些操作但不返回值的指令
- **表达式**：计算并产生一个值。

主要区分最后有无`;`

```rust
fn main() {
    let y = {
        let x = 3; //语句
        x + 1 //表达式
    };

    println!("The value of y is: {y}");
}
```



#### 返回值

> 不对返回值命名，需要在`->`后声明返回值类型

```rust
fn plus_one(x: i32) -> i32 {
    x + 1
}
```



### 流程控制(`Control Flow`)

> 根据条件来决定是否执行某些代码。

#### if / while / for

主要就是一些`if`，`while`，`for`，这些的使用方式与Java的一致，不做细节说明

```rust
// if
fn main() {
    let mut x = 10;
    x = if x % 2 == 0 {
        x / 2
    } else {
        3 * x + 1
    };
}

//while
fn main() {
    let mut x = 10;
    while x != 1 {
        x = if x % 2 == 0 {
            x / 2
        } else {
            3 * x + 1
        };
    }
    println!("Final x: {x}");
}

//for
fn main() {
    let v = vec![10, 20, 30];

    for x in v {
        println!("x: {x}");
    }
    
    for i in (0..10).step_by(2) {
        println!("i: {i}");
    }
}
```

#### loop

> 重复执行代码，直到某些条件停止(执行到`break`)

```rust
fn main() {
    let mut counter = 0;

    let result = loop {
        counter += 1;

        if counter == 10 {
            break counter * 2; //返回该值到result
        }
    };

    println!("The result is {result}");
}
```

##### 循环标签

> 如果存在多重嵌套循环，通过在循环上指定循环标签用于退出

```rust
fn main() {
    let mut count = 0;
    'counting_up: loop {
        println!("count = {count}");
        let mut remaining = 10;

        loop {
            println!("remaining = {remaining}");
            if remaining == 9 {
                break; //退出当前loop
            }
            if count == 2 {
                break 'counting_up; //退出 counting_up对应的loop
            }
            remaining -= 1;
        }

        count += 1;
    }
    println!("End count = {count}");
}
```



### 模式匹配(Match)

#### [match](https://kaisery.github.io/trpl-zh-cn/ch06-02-match.html)

> 将一个值与一系列的模式进行比较，并根据匹配的模式执行相应的代码。
>
> 功能类似Java的`when`

```rust
enum Coin {
    YIFEN,
    WUFEN,
    WUMAO,
    YIYUAN(String),
}

fn value_in_cents(coin: Coin) {
    match coin {
        Coin::YIFEN => { println!("1") }
        Coin::WUFEN => { println!("5") }
        Coin::WUMAO => {
            println!("50")
        }
        Coin::YIYUAN(str) => {
            println!("100 {str}")
        }
    }
}
```

#### matches

> 功能与`match`差不多，支持多条件匹配

```rust
fn value_in_cents(coin: Coin) {
    if matches!(coin,Coin::YIFEN | Coin::WUFEN) { //coin匹配上 yifen / wufen
        println!("1")
    } else if matches!(coin,Coin::YIYUAN(str) if str > 130) { //coin匹配上 yiyuan 且 数值>130
        println!("100");
    } else {
        println!("50")
    }
}
```



#### if let

> `if let`属于`match`的一种语法糖，简化了使用。
>
> 只能匹配某一模式

```rust
fn value_in_cents(coin: Coin) {
     if let Coin::YIYUAN(str) = coin {
        println!("100 {str}")
    } else{
        println!("1")
    }
}    
```





### 常见集合

#### Vector

#### HashMap









## 参考资料

[Rust官网](https://www.rust-lang.org/)

[Rust程序设计语言](https://kaisery.github.io/trpl-zh-cn/title-page.html)

[给Android开发者的Rust综合学习(Google出品)](https://google.github.io/comprehensive-rust/welcome.html)

[Rust在线练习](https://zh.practice.rs/why-exercise.html)

