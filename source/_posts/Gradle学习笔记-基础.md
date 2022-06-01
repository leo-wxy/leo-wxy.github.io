---
title: Gradle学习笔记-基础
date: 2019-04-22 21:21:30
typora-root-url: ../
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

![Gradle工作流程](/images/Gradle-workflow.png)



### Initialization phase(初始化阶段)

> **初始化构建**
>
> 此处创建了`Setting`以及各Module的`Project`对象

#### 执行`Init Script`

> 读取全局脚本，主要是**初始化一些全局通用属性**，例如获取`Gradle Version`等

位于`GRADLE_USER_HOME`目录，API主要分为三部分：

- 获取全局属性
- 项目配置
- 生命周期Hook：身为**最早执行的脚本**，几乎可以监听到所有的事件

#### 执行`settings.gradle`

> **初始化了一次构建中参与的所有模块**，主要负责`组织和管理一个项目中的所有模块的脚本*build.gradle*`

内部主要有以下两个操作

##### 设置参与构建的模块

> 进行项目的描述

```groovy
//按照模块名引入
include ':app'
include ':lib'

//若子项目不在根目录下，需要使用路径引入
include(":anotherLibrary")
project(":anotherLibrary").projectDir = File(rootDir, "../another-library")
```

所有`include`的项目，都可以在`DefaultProjectRegistry.projects`中找到

可以通过`rootProject.project("lib")`找到Project相关配置

##### Plugin管理

> Plugin的相关配置

Plugin仓库设置

```groovy
//settings.gradle
pluginManagement {
    repositories {
        maven(url = "../maven-repo")
    }
}
```



Plugin模块替换

```groovy
pluginManagement {
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == "org.gradle.sample") {
               //  useVersion("1.4") //根据模块名使用指定版本
               //   useModule("org.gradle.sample:sample-plugins:1.0.0") 使用指定插件 可替换
            }
        }
    }
}
```

`resolutionStrategy`唯一回调`eachPlugin`返回的对象为`PluginResolveDetails`,其中的`PluginRequest`记录了插件信息。主要有以下内容:

[PluginRequest](https://docs.gradle.org/6.0.1/javadoc/org/gradle/plugin/management/PluginRequest.html)

- id：对应`PluginId`
  - id
  - name
  - namespace`
- module：对应`ModuleVersionSelector`
  - name
  - group
- version：版本

### Configuration phase(配置阶段)

> 加载项目中所有模块的`build.gradle`，实际就是执行`build.gradle`，再然后根据执行创建对应的**Task**。最终生成一个`Task组成的有向无环图`，记录Task之间的依赖关系。

#### `build.gradle`主要职能

主要有两部分

##### 插件引入

> `Gradle`本身不提供任何编译打包的功能，只是一个**负责定义流程和规则的框架**，具体的编译打包工作都有**Task**完成。
>
> 插件(Plugin)：**定义Task，并具体执行这些Task的模版**

`Plugin`主要分为两种类型：

- `脚本插件`：存在于另一个脚本文件中的一段脚本代码
- `二进制插件`：实现`Plugin`接口

```groovy
//build.gradle
//引入内置插件
apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'
apply plugin: 'kotlin-android-extensions'

//非内置插件引入 需要配置到classpath下
//root build.gradle
buildscript {
    repositories {
        google()
        jcenter()
    }
    dependencies {
        classpath "XX:core_dolphin_parse_plugin:1.0.18-SNAPSHOT"
    }
}

//module build.gradle
//引入非内置插件
apply plugin: 'dolphin-parse-plugin'

```



##### 属性配置

> 引入了插件之后，就可以使用插件提供的DSL进行配置 ，配置执行过程

以`com.android.application`插件为例

```groovy
apply plugin: 'com.android.application'

android {
    compileSdk 32
    //编译时配置
    defaultConfig {
        applicationId "com.example.gradleplugindemo"
        minSdk 23
        targetSdk 32
        versionCode 1
        versionName "1.0"

        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }
    //构建类型配置
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    //编译选项配置
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = '1.8'
    }
}
```

额外`Project`也提供了`repositories`,`dependencies`等配置项，后续会介绍他们的作用

#### 根目录 Root build.gradle

> 一般是对`Module build.gradle`进行统一的配置

```groovy
buildscript {
  repositories {
    google()
    jcenter()
  }
  dependencies {
    classpath 'com.android.tools.build:gradle:4.1.3'
  }
}

allprojects{
    repositories {
      google()
      jcenter()
    }
}

task clean(type: Delete) {
    delete rootProject.buildDir
}

ext {
    compileSdkVersion = 29
    buildToolsVersion = "29.0.3"
}

subprojects { sub ->
    if (sub.name != 'app' ) {
        apply plugin: 'XX'
    }
}
```

`Root build.gradle`主要分为以下几部分

##### buildscript

> Gradle默认是自顶向下执行，但是无论`buildscript`在哪，都会是第一个执行
>
> **buildscript声明的是gradle脚本自身需要使用的资源**

- repositories：`dependencies`声明的依赖去哪些仓库寻找
- dependencies：表示Gradle的执行需要哪些依赖

> 非`buildscript`配置的依赖等 均为项目自身运行所需要的资源

##### allprojects

> 配置对所有Module生效

- repositories：`dependencies`声明的依赖去哪些仓库寻找

##### ext

> 用于Project间的数据共享，主要统一各Module的依赖版本

##### subprojects

> 主要统一Module之间的重复配置，并可针对特定Module进行设置

##### other

#### 子模块 Module build.gradle

> 指定Module的配置

```groovy
apply plugin 'com.android.application'

android {
    compileSdk 32

    defaultConfig {
        applicationId "com.example.gradleplugindemo"
        minSdk 23
        targetSdk 32
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = '1.8'
    }
}

repositories{

}

dependencies {
    implementation 'androidx.core:core-ktx:1.7.0'
    implementation 'androidx.appcompat:appcompat:1.4.1'
    implementation 'com.google.android.material:material:1.6.0'
    testImplementation 'junit:junit:4.13.2'
    androidTestImplementation 'androidx.test.ext:junit:1.1.3'
    androidTestImplementation 'androidx.test.espresso:espresso-core:3.4.0'
}
```

##### apply plugin

> **应用插件**
>
> 当插件应用成功后，就会创建一系列的*Task*

比如`apply plugin 'com.android.application' `，就会创建出`assembleRelease`这类的Task，通过这些Task，最终生成APK

##### android

> 插件提供的配置项，允许对Task进行修改

##### repositories

> `dependencies`声明的依赖去哪些仓库寻找

##### dependencies

> 表示Gradle的执行需要哪些依赖

### Execution phase(执行阶段)

> **真正进行编译和打包动作**，会执行`Task`
>
> 可以通过执行`./gradlew <TaskName>`直接执行对应Task

`配置阶段`结束后，Gradle生成一个Task的有向无环图，可以通过`getTaskGraph`来获取具体的Task以及执行的通知

```groovy
gradle.getTaskGraph().addTaskExecutionGraphListener(new TaskExecutionGraphListener() {
    @Override
    void graphPopulated(TaskExecutionGraph taskExecutionGraph) {

    }
})
```

后续就是具体的任务执行，会在后续分析中介绍Task的执行流程。



## Gradle工作流程Hook

> 在`初始化阶段`、`配置阶段`，`执行阶段`每阶段可以获取到的信息都有不同，可以通过`Hook`获取到每阶段的情况

### Initialization Hook

#### gradle.settingsEvaluated(settings.gradle执行结束)

> 可以得到`settings.gradle`转化的`Settings`对象

```groovy
//settings.gradle
settingsEvaluated { settings ->
  //添加统一仓库地址
    settings.pluginManagement {
        repositories {
            maven(url = "../maven-repo")
        }
    }
}
```

#### gradle.projectsLoaded(Project对象创建)

> 可以获取到各Module创建的`Project`对象

```groovy
//settings.gradle
gradle.projectsLoaded {
   ...
}
```

此时获取的`Project`对象只包含一些通用的基本信息，其他信息要在`配置阶段`执行之后才可获取

### Configuration Hook

#### project.beforeEvaluate

> 各Module的`build.gradle`执行前回调

```groovy
//settings.gradle
gradle.projectsLoaded {
    println("projectsLoaded " + it)
    gradle.allprojects({
        beforeEvaluate {
            println("beforeEvaluate " + it)
        }
    })
}

```

此时`build.gradle`尚未执行，所以hook点需要在`settings.gradle`添加

#### project.afterEvaluate

> 各Module的`build.gradle`执行完毕后，回调`afterEvaluate`
>
> **此时Project对象完整了**

```groovy
//build.gradle
project.afterEvaluate {
    println("afterEvaluate " + project.android)
}
```

>  此时可以添加**动态任务**到构建中

####  gradle.addListener( DependencyResolutionListener )

> `DependencyResolutionListener`——监听构建过程中依赖的关系

##### beforeResolve

> 依赖处理前回调
>
> **可在此处进行依赖版本统一**

##### afterResolve

> 依赖处理后回调
>
> **一般在此处进行依赖的检测，包括版本信息以及是否Release**

```groovy
//settings.gradle
gradle.addListener(new DependencyResolutionListener() {
    @Override
    void beforeResolve(ResolvableDependencies resolvableDependencies) {
        println("DependencyResolutionListener:beforeResolve:=====${resolvableDependencies}=====")
    }

    @Override
    void afterResolve(ResolvableDependencies resolvableDependencies) {
        gradle.println "DependencyResolutionListener:afterResolve:=====${resolvableDependencies}====="

        def projectPath = resolvableDependencies.path.toLowerCase()
        println(projectPath)

        if (projectPath.contains("releasecompile")) {
            gradle.println "[DependencyResolutionListener] release detect:${resolvableDependencies.path}"
            resolvableDependencies.resolutionResult.allDependencies.each { dependency ->
                if (dependency instanceof org.gradle.api.internal.artifacts.result.DefaultUnresolvedDependencyResult) {
                    gradle.println "DefaultUnresolvedDependencyResult reason: ${dependency.reason}"
                    gradle.println "DefaultUnresolvedDependencyResult failure: ${dependency.failure}"
                } else if (dependency instanceof org.gradle.api.internal.artifacts.result.DefaultResolvedDependencyResult) {
                    String selected = dependency.selected
                    def from = dependency.from
                    gradle.println "[DependencyResolutionListener] current dependency : ${selected} which is from:${from}"
                    if (selected != null && (selected.toLowerCase().contains("snapshot") || selected.toLowerCase().contains("beta"))) {
                        String errorMessage = "[DependencyResolutionListener] [Error] ${selected} from ${from} contains a snapshot or beta version. you must fix it."
                        gradle.println errorMessage
                        throw new IllegalStateException(errorMessage)
                    }
                }
            }
        }
    }
})
```

上面代码示例 用于检测打包Release时，若存在`snapshot`版本依赖则提示构建失败

`DependencyResolutionListener`回调的对象为`ResolvableDependencies`，主要使用的是`ResolutionResult`

```java
//ResolvableDependencies
public interface ResolvableDependencies extends ArtifactView {
 ...
       ResolutionResult getResolutionResult();
  ...
  
}

public interface ResolutionResult {
 ...
       Set<? extends DependencyResult> getAllDependencies();
}

public interface DependencyResult {
    ComponentSelector getRequested();

    ResolvedComponentResult getFrom();

    boolean isConstraint();
}
```

`DependencyResult`主要实现类有两个：

- DefaultUnresolvedDependencyResult 加载失败依赖

  ```java
  public class DefaultUnresolvedDependencyResult extends AbstractDependencyResult implements UnresolvedDependencyResult {
      private final ComponentSelectionReason reason; //失败原因
      private final ModuleVersionResolveException failure; //失败详情
  }
  ```

- DefaultResolvedDependencyResult 加载成功依赖

  ```java
  public class DefaultResolvedDependencyResult extends AbstractDependencyResult implements ResolvedDependencyResult {
      private final ResolvedComponentResult selectedComponent;//加载成功依赖信息
      private final ResolvedVariantResult selectedVariant;//
  }
  ```

  

#### gradle.projectsEvaluated

> 所有`build.script`文件执行完毕后回调
>
> 此时可以获取到 gradle settings 以及各Module的Project对象

```groovy
//settings.gradle
gradle.projectsEvaluated {
    println("projectsEvaluated "+it)
}

```

#### gradle.taskGraph.whenReady

> 根据所有`Task`生成依赖有向无环图之后回调
>
> 此时可以根据`taskGraph`获取所有执行的Task详情

```groovy
//settings.gradle
gradle.taskGraph.whenReady {
    TaskExecutionGraph taskGraph ->
        taskGraph.allTasks.each {
            Task task ->
                gradle.println "=========whenReady:taskGraph:${task.getName()}========="
        }
}

//或者通过addListener方式处理
gradle.addListener(new TaskExecutionGraphListener() {
    @Override
    void graphPopulated(TaskExecutionGraph graph) {
        gradle.println "=========from gradle.addListener graphPopulated========="
        graph.allTasks.each {
            Task task ->
                gradle.println "=========TaskExecutionGraph:${task.getName()}========="
        }
    }
})
```



### Execution Hook

#### gradle.addListener( TaskExecutionListener)

> 针对每个`Task`执行前后的Hook点

```groovy
//settings.gradle
gradle.addListener(new TaskExecutionListener() {
    @Override
    void beforeExecute(Task task) {
        println("beforeExecute " + task.getName())
    }

    @Override
    void afterExecute(Task task, TaskState taskState) {
        println("afterExecute " + task.getName())
    }
})
```

对应的是`Task`添加的

```groovy
task clean(type: Delete) {
    delete rootProject.buildDir
    beforeEvaluate {

    }
    afterEvaluate {

    }
}
```



####  gradle.addListener( TaskActionListener)

> `Task`内部是由很多`Action`进行集合，`Action`才是真正要执行的功能。
>
> 针对`Task`内`Action`执行前后的Hook点

```groovy
//settings.gradle
gradle.addListener(new TaskActionListener() {
    @Override
    void beforeActions(Task task) {
        println("beforeActions " + task.actions)
    }

    @Override
    void afterActions(Task task) {
        println("afterActions " + task.actions)
    }
})
```



#### gradle.buildFinished 

> 所有`Task`都执行完毕回调

```groovy
//settings.gradle

gradle.buildFinished {
    println("整个流程构建完成")
}
```



### 只Hook关键节点-BuildListener

> `BuildListener`在

## 自定义插件



## 参考链接

[Mastering Gradle](https://juejin.cn/book/6844733819363262472/section/6844733819421999118)
