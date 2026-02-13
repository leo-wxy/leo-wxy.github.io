---
title: Gradle学习笔记-基础
date: 2019-04-22 21:21:30
tags: Gradle
top: 10
---

> Gradle是一种自动化构建语言，是一种`DSL(Domain Specific Language 特点领域语言)`，目前是Android的默认构件构建工具，是一个编程框架。

## 作用

> 将`Java/Kotlin(逻辑代码)`、`XML(界面代码)`、`NDK C/C++(JNI)`、`资源文件`，*`RenderScript(并行运算)`*这些文件通过编译过程打包成一个`Apk`。

- 解决自己的问题
- 帮助其他人优化开发流程
- 可以分享出自己的插件

## 特性

| 语言         | **Groovy**先编译成Java类字节码，然后通过JVM来执行该类 |
| ------------ | ----------------------------------------------------- |
| 支持的环境   | Android Studio及命令行调用                            |
| 构建粒度     | 支持多个Project/Module、多个版本、多种构建类型        |
| 可拓展性     | 丰富的API及插件架构                                   |
| 其他构建工具 | Ant、Maven                                            |

## 概念

### GradleWrapper

一个Gradle的封装体，即便机器上没有安装Gradle，也可以执行Gradle的构建工作。在Android项目下分为`gradlew(Mac、Linux下使用)`，`gradlew.bat(Win下使用)`

通过`gradle.properties`配置Gradle参数

```properties
#Fri Feb 15 15:39:54 CST 2019
#Gradle解包后的存储目录
distributionBase=GRADLE_USER_HOME
#Gradle解包后存放位置
distributionPath=wrapper/dists
#Gradle压缩包存储目录
zipStoreBase=GRADLE_USER_HOME
#Gradle压缩包存放位置
zipStorePath=wrapper/dists
#Gradle压缩包下载地址
distributionUrl=https\://services.gradle.org/distributions/gradle-4.10.1-all.zip
```



分别的执行命令为

```bash
//Mac、Linux使用
./gradlew ...task
//win下使用
./gradlew.bat ...task
```



### Closure(闭包)

```gradle build.gradle
repositories {
   google()
   jcenter()
}
```

  `闭包`省略了表达式中的括号，`Groovy`表达式省略括号的规范：

- 所有顶级表达式的括号可以省略
- 当闭包是一个顶级表达式的最后一个参数时，可以省略括号
- 当函数嵌套调用已经有函数没有参数时不能省略

> 闭包和函数的区别：
>
> 闭包：`def addNumbers = { left , right -> left+right }`
>
> 函数：`def addNumbers( left , right ){ left+right }`



###  Project

Gradle为每个`build.gradle`创建一个相应的Project领域对象，在编写Gradle脚本时，实际是在操作诸如Project这样的Gradle领域对象。

一个完整项目中一般包含：

- `settings.gradle`：一个，一般包含了`module及app的引用`

- `build.gradle`：一个`root project`及多个`module project`



`dependencies`：设置Gradle依赖库

- `implememtation`：加入的依赖，表示这个依赖库只能自己用，其他依赖该module的无法引用该库。(*可以提高编译速度。*)
- `api`：加入的依赖，其他引用该Module的也可以使用该库，类似于以前的`compile`

### Tasks

一个Project由一个或多个`Task`组成，它是构建过程中的原子任务，可以是编译Class，上传jar包等。

> 可以在 Gradle文件目录下查看所有Task 或者通过执行 `./gradlew tasks`来查看

task包含以下内容

| 参数        | 含义                 | 默认量             |
| ----------- | -------------------- | ------------------ |
| name        | task名字             | 不能为空，必须指定 |
| type        | task父类             | DefaultTask        |
| overwrite   | 是否替换已存在的task | false              |
| dependsOn   | task依赖的task集合   | []                 |
| group       | task属于哪个组       | null               |
| description | task的描述           | null               |



### Hooks



### Plugin

Gradle插件打包了可以复用的构建逻辑块，这些逻辑可以在不同的项目中构建使用。



 

## Gradle工作流程

{% fullimage /images/Gradle-workflow.png,Gradle工作流程,Gradle工作流程%}

- `Initialzation phase(初始化阶段)`：就是执行`setting.gradle`
- `Configuration phase(配置阶段)`：解析每个`project`中的`build.gradle`，可以在此期间添加一些`Hook`，需要通过API进行添加。配置完成后，内部建立一个有向图来描述Task之间的依赖关系。
- `Execution phase(执行阶段)`：执行任务



## 自定义插件

