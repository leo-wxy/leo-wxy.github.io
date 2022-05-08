---
title: Gradle学习笔记-Groovy基础
date: 2019-04-23 17:59:25
tags: Gradle
top: 10
---

> Groovy是基于JVM的一种动态语言，语法与Java相近，上手较快。**Groovy完全兼容Java。**又增加了很多动态类型和灵活的特性，是一门比较灵活的动态脚本语言。

## 变量

Groovy中通过`def`定义变量，无需指定变量类型，自动判断。

### 数据类型

```groovy
task printDef << {
//字符串
def str1 = "str"
def str2 = 'str'
def str3 = '''str
    23
        45''' //三引号字符串可以保留文本的换行及缩进
//数值
def intV = 1
def doubleV = 2.0
def floatV = 3.0f

println("字符串 ${str1} ${str2} 数值 ${intV} ${doubleV} ${floatV}")
}

//在控制台输出结果
./gradlew printDef
```

> `println`输出到控制台，只有双引号标记的`${ }`才可以生效。

### 集合

#### List

> Groovy在Java的集合类基础上进行了拓展与增强，并对原有集合完美兼容。

```groovy
task printList << {
  //初始化一个数组 默认ArrayList类型
  def numList = [1,2,3,4,5,6,7]
  //设置List类型为 LinkedList
  def linkList = [1,2,3] as LinkedList
  //输出第一个元素
  println numList[0]
  //输出最后一个元素
  println numList[-1]
  //输出第一到第三个元素
  println numList[0..2]
  //输出倒数第一到倒数第三个元素
  println numList[-1..-3]
  //添加元素
  numList << 5
  numList.add(5)
  //移除元素
  numList.remove(1) //移除第二个元素
  //遍历输出
  numList.each{ print "${it}," }
  //显示索引
  numList.eachWithIndex{ it,i -> print("${i},") }
  //Collect语法
  //查找list元素
  println numList.find{ it>3 }
  //查找list所有符合条件元素
  println numList.findAll{ it>3 }
  //查找list元素并返回下标
  println numList.findIndexOf{ it ==4 }
  println numList.findFirstIndexOf{it==4}
  println numList.findLastIndexOf{it==4}
  //List排序
  numList.sort()
  //List去重
  numList.unique()
}
```

#### Map

> Map用法与List类似，只不过它的值是一个KV键值对。

```groovy
task PrintMap << {
  //初始化Map 默认LinkedHashMap
  def map = [one:"111",two:"222",three:"333"]
  //根据key输出value
  println map["one"] //111
  println map.one //111
  //遍历Map
  map.each {
    println "Key：${it.key} value：${it.value}"
  }
  //判定Map中存在key
  println map.containKey("one") //true
  //判定Map中存在value
  println map.containValue("222")
  //清除Map的内容
  map.clear()
}
```

#### Range

> Groovy提供的一种容器类，是对List的拓展

```groovy
task printRange << {
  //定义一个Range
  def range = 1..5
  
  print range //[1,2,3,4,5]
  //获取range长度
  println range.size() //5
  //获取index为1的元素
  println range.get(1) //2
  //是否包含元素3
  println range.contains(3) //true
  //获取第一个元素
  println range.first()//1
  println range.from()//1
  //获取最后一个元素
  println range.last()//5
  println range.to()//5
  //添加新元素
  range.add(6)
  //移除元素
  range.remove(0)
  //清空数据
  range.clear()
  //遍历range
  range.each {println it}
}
```

## 操作符

### `**`运算符

> 等同于 2^3 = 8

```groovy
2 ** 3 = 8
```

### `?.`占位符

> 用于避免空指针异常

```groovy
def person = new Person()
println person?.name?:"" //为null 则返回空
```

### `.@`操作符

> 直接跳过写的`getXX()`获取对应值

```groovy
class Person {
    String name
    Integer age = 10
    int getAge() { age+10 }
}

task printClass << {
    Person p = new Person();

    p.name = "wxy"
    println p.name //wxy
    println p.@age //10
    println p.age //20
}
```

### 三目运算符

```groovy
def name
//类Java写法
def result = name==null?"null":name
//Groovy写法
def result = name?:"null"
print result
```

###`asType`

> 数据类型转换

```groovy
String string = "23"
//转成int
def toInt = string as int
def toInt = string.asType(Integer)
```

### `<=>`比较操作符

```groovy
assert (1 <=> 1) == 0
assert (1 <=> 2) == -1
assert (2 <=> 1) == 1
```

### `*.`展开运算符

> 得到原集合中各元素的组合后的集合

```groovy
class Person {
  String name
  int age
}

def persons = [new Person("a",1),new Person("b",2),new Person("c",3)]
def names = persons*.name  // [a,b,c]

def names = persons.collect{it.name} //[a,b,c]
```

`*.`操作符是空安全的，支持传入`null`

### `with`操作符

> 简化对同一对象进行赋值的操作

```groovy
class Person {
  String name
  int age
  int score
}

task testWith << {
  Person person = new Person()
  person.with {
    name="a"
    age=12
    score=60
  }
}
```

## 方法

> Groovy中的方法与Java方法相似，但是提供了更便利的实现。

```groovy
task printMethod << {
    add(1,3)
    add 1,4  //1
    println minus (5,2)
}

def add(int a,int b){
    println a+b
}

static int minus(a,b){//3
  println "a=${a} b=${b}"
    a-b //2
}
```

1. 语句后面的分号可以省略
2. 方法中的括号可以省略 *类似注释1*
3. return 可以省略掉 *类似注释2* **最后一行代码为返回值的最终结果**
4. 参数类型可以忽略掉 *类似注释3*

默认方法修饰符为`public`。

## 类

> Groovy类类似于Java类

```groovy
task printClass << {
    Person p = new Person();
    p.increaseAge(2)

    p.name="wxy"
    println p.name
    println p.age
}

class Person {
    String name
    Integer age =10
    int getAge(){ age }
    def increaseAge(Integer years){
        this.age+=years
    }
}
```

1. 默认类的修饰符为`public`
2. 没有可见修饰符的会自动生成对应的`getter/setter`方法
3. 类不需要与它的源文件有相同的名称，建议采用相同的名称



## 语句

### 断言

> 用于进行单元测试

```groovy
tasl test << {
  assert 1+2==6 //进行测试
}
```



### for语句

> 循环语句

```groovy
task testFor << {
  def x= 0
  for(i in 0..3){
    x+=i
  }
  //效果等同于 0..3
  for(i in 0..<4){
    x+=i
  }
  println x //6
  
  x = 0
  def list = [0,1,2,3]
  for (i in list){
    x+=i
  }
  println x //6
  
  x = 0;
  def map =[a:1,b:2,c:3]
  for( i in map.values){
    x+=i
  }
  println x //6
}
```

### time语句

> 用于进行循环输出

```groovy
4.times {
  print it
}

输出0 1 2 3
```

### switch语句

> 选择语句

```groovy
static def returnSwitch(x){
    def result = ""
    switch(x){
        case "ok":
            result = "found ok"
            break
        case String:
            result = "isString"
            break
        case 1..10:
            result = "in range"
            break
        case Integer:
            result = "is Integer"
            break
        case [1,2,3,4]:
            result = "is List"
            break
        default:
            result = "default"
        return result
    }
}
```

`switch`除了Java支持的数据类型`Integer、String`以外，还支持数组类型、区间、列表等

### 捕获异常

> 写法同Java一致

```groovy
    try {
        // do sth
    } catch (EOFException e) {
        e.printStackTrace()
    }

//Groovy写法
    try {
        // do sth
    } catch (e) {//可忽略类型
        e.printStackTrace()
    }
```



## I/O操作

> 对原有Java I/O操作进行了封装，简化了使用方法

### 文件读取

```groovy
task testFileRead << {
    def filePath = "$path"
    def file = new File(filePath)
 //基础使用方式
    //输出所有文本内容
    println file.text 
    //逐行输出
    file.eachLine {
        println it
    }
 //Reader操作方式 
    def line = ""
    file.withReader {reader ->
       while(line = reader.readLine()){
           println line
       }
    }
    //设置编码格式
    file.withReader("utf-8"){reader->
        while(line = reader.readLine()){
            println line
        }
    }
 //InputStream 
    def is = file.newInputStream()
    is.eachLine {
        println it
    }
    //使用完后 需要及时关闭
    is.close()
    // 使用 withInputStream 不需要close流
    file.withInputStream { stream ->
        stream.eachLine {
            println it
        }
    }
}
```

`Reader`：即使读取过程中抛出异常也可以自动关闭IO操作

### 文件写入

```groovy
task testFileWrite << {
  def file = new File("%path")
//基础使用方式
  file.withWriter("utf-8"){writer->
    writer.writeLine "Hello"
    writer.writeLine ","
    writer.writeLine "World"
  }
  file << '''Hello
  ,
  World'''
//OutputStream
    def bytes = [66,22,11] as byte[]
    def out = file.newOutputStream()
    out.write(bytes)
    out.flush()
    out.close()
  
    file.withOutputStream {stream->
        stream.write(bytes)
        stream.write(bytes)
    }
//PrintWriter
    def out = file.newPrintWriter()
    out.write("sasd")
    out.write("sdds")
    out.flush()
    out.close()
  
    file.withPrintWriter { writer ->
        writer.append("ssss")
        writer.println("dfff")
        writer.write("12333")
    }
}
```

### 文件遍历

> 可用于检测文件是否重复，例如代码中的重复资源引用

```groovy
task testFileEach << {
  def file = new File("$path")
  //遍历目录下的文件
  file.eachFile { file->
    println file.name //打印文件名包括文件夹名字，不能嵌套处理
  }
  //遍历嵌套目录
  file.eachFileRecurse{file->
    println file.name //打印文件名 包含嵌套目录及文件
  }
  //按照文件类型 遍历目录
  file.eachFileRecurse(FileType.FILES){file->
    println file.name //只会打印出文件
  }
  //按照正则匹配文件
  
  
}
```

`FileType`包含以下三种类型：

- `FileType.ANY`：可获取所有类型，包含文件、目录
- `FileType.FILES`：只能获取文件类型
- `FileType.DIRECTORIES`：只能获取文件夹类型

## **闭包**

> Groovy中一个重要的特性，是**DSL**的基础。使得代码变得*灵活、轻量、可复用*。

### 基础样式

```groovy
task testClosure << {
    //闭包单参数 默认it 也称为隐含参数 可以指定名称
    customEach{ iii->
        print iii
    }
   /*
    *customEach{
    *   print it
    *}
    */
}

static def customEach(closure/*闭包*/){
    for(int i in 1..10){
        closure(i)
    }
}
```

### 多参数

> 如果闭包中只有一个参数，默认可以使用`it`。也可以自己指定名称。*多参数情况时，就需要列举出所有参数*

```groovy
task testClosure << {
    //闭包多参数
    eachMap{k,v->
        print "${k} : ${v}"
    }
}

static def eachMap(closure){
    def map =["1":1,"2":2]
    map.each {
        closure(it.key,it.value)
    }
}
```

### 闭包调用

```groovy
def closure1 = {
  //定义了闭包的参数
  String name,int age -> 
  println "${name} is ${age}"
}

//调用方式
closure1("wxy",111)
或
closure1.call("wxy",111)

特殊实例：
//无参闭包
def closureSpecial = {
  -> println "special"
}

//调用方式
closureSpecial.call()
closureSpecial()
```

### 闭包委托

> Groovy的闭包有`thisObject、owner、delegate`三个属性，当你在闭包内调用方法时，由他们来确定使用哪个对象来处理。

| 对象       | 含义                                                         | 方法              |
| ---------- | ------------------------------------------------------------ | ----------------- |
| thisObject | 对应于定义闭包的那个类<br>如果在内部类中定义，指向的是内部类 | `getThisObject()` |
| owner      | 对应于定义闭包的那个类或闭包<br>如果在闭包中定义，对应闭包，与`thisObject`一致 | `getOwner()`      |
| delegate   | 默认与`owner`一致<br>可以进行自定义拓展更多功能              | `getDelegate()`   |



```groovy
class OuterClass {
    class InnerClass {
        def outerClosure = {
            def innerClosure = {

            }
            printMsg("innerClosure", innerClosure)
            printMsg("outerClosure", outerClosure)
        }

        void printMsg(flag,closure){
            def thisObject = closure.getThisObject()
            def ownerObject = closure.getOwner()
            def delegate = closure.getDelegate()

            println("${flag} this : ${thisObject.toString()}")
            println("${flag} owner : ${ownerObject.toString()}")
            println("${flag} delegate : ${delegate.toString()}")
        }
    }

    def callInnerMethod(){
        def innerClass = new InnerClass()
        innerClass.outerClosure.call()
        println("outerClosure toString ${innerClass.outerClosure.toString()}")
    }
}

//打印闭包
task printBibao << {
    new OuterClass().callInnerMethod()
}


.....................输出结果.........................
> Task :CustomPlugin:printBibao
innerClosure this : OuterClass$InnerClass@4ee95fee
innerClosure owner : OuterClass$InnerClass$_closure1@1177369d
innerClosure delegate : OuterClass$InnerClass$_closure1@1177369d

outerClosure this : OuterClass$InnerClass@4ee95fee
outerClosure owner : OuterClass$InnerClass@4ee95fee
outerClosure delegate : OuterClass$InnerClass@4ee95fee

outerClosure toString OuterClass$InnerClass$_closure1@1177369d
```

根据上述的输出结果可以对应出上面的表格。

#### **delegate**

> 委托中最关键的就是**delegate**，它负责`将闭包和一个具体的对象关联起来`。

```groovy
task printClosure << {
    Main main = new Main()
    Man man = new Man(name:"sd",age:11)
    println man.toString()

    main.cc.delegate = man
  //main.cc.setResolveStrategy(Closure.DELEGATE_FIRST)
    main.cc.call()
    println man.toString()
}

class Man {
    String name
    int age

    static void eat(food) {
        println "eat ${food}"
    }

    @Override
    String toString() {
        return "Man{ name = ${name} age = ${age} }"
    }
}

class Main {
    static void eat(food){
        println "Main eat $food"
    }

    def cc = {
        name = "wxy"
        age = 12
        eat("ss")
    }
}

输出结果：
Man{ name = sd age = 11 }
Main eat ss
Man{ name = wxy age = 12 }

//设置了 setResolveStrategy(Closure.DELEGATE_FIRST)时
Man{ name = sd age = 11 }
eat ss
Man{ name = wxy age = 12 }
```

上述的执行结果，最终调用到了`Main.eat()`而不是`Man.eat()`，考虑到这个情况，`Closure`提供了`setResolveStrategy()`来控制调用同名方法的来源。

| `setResolveStrategy()`设置对应属性 | 参数含义                                  |
| ---------------------------------- | ----------------------------------------- |
| Closure.OWNER_FIRST(*默认值*)      | 优先在owner中寻找，没有就去delegate中寻找 |
| Closure.DELEGATE_FIRST             | 优先在delegate中寻找，没有就去owner中寻找 |
| Closure.OWNER_ONLY                 | 只在owner中寻找                           |
| Closure.DELEGATE_ONLY              | 只在delegate中寻找                        |
| Closure.TO_SELF                    | ???                                       |

> 在上述实例中，`owner`相当于`Main`，`delegate`相当于`Man`





## 引用

[Apache-Groovy](http://groovy-lang.org/documentation.html#languagespecification)

[搞定Groovy闭包](https://www.jianshu.com/p/6dc2074480b8)

[Groovy 使用完全解析](https://blog.csdn.net/zhaoyanjun6/article/details/70313790)





