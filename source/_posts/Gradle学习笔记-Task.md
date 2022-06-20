---
title: Gradle学习笔记-Task
date: 2019-05-08 21:30:44
typora-root-url: ../
tags: Gradle
top: 10
---

> Gradle的两个重要的概念：`Project`和`Task`，一个`Project`由多个`Task`组成。

## Task

> Gradle脚本中的最小执行单元，也是Gradle中的一个原子操作。

### Task Result(任务结果)

当Task执行时，最终控制台都会输出执行的结果，后面都会带有一个标签，这些标签表示了*是否有Task需要执行，是否执行了Task*等状态。

| 结果标签             | 结果描述                   | 如何触发                                                     |
| -------------------- | -------------------------- | ------------------------------------------------------------ |
| 没有标签<br>EXECUTED | 任务执行完毕               | 任务有动作且被执行                                           |
| UP-TO-DATE           | 任务输出没有改变           | 任务没有动作也没有依赖<br>任务有输入输出但是没有发生变化<br>任务没有动作但存在依赖，且依赖非执行完毕 |
| NO-SOURCE            | 任务不需要执行             | 包含了输入输出，但是没有Sources？？？                        |
| FROM-CACHE           | 在缓存中找到了任务执行结果 | 构建缓存中已存在构建结果                                     |
| SKIPPED              | 任务没有执行               | 指定跳过该任务<br>任务设置了`onlyIf`且返回false<br>任务被禁用`enabled=false` |



### Task Create(创建任务)

```groovy
task createTask1 << {
  println "doLast in createTask1"
}

task createTask2 doLast {
  println "doLast in createTask2"
}

//三种方式皆可
project.task("createTask3").doLast {
  println "doLast in createTask3"
}
project.task("createTask3") doLast {
  println "doLast in createTask3"
}
project.task("createTask3") << {
  println "doLast in createTask3"
}
//通过TaskContainer创建Task
project.tasks.create("createTask4").doLast {
   println "doLast in createTask4"
}
project.tasks.create("createTask4") doLast {
   println "doLast in createTask4"
}
project.tasks.create("createTask4") << {
   println "doLast in createTask4"
}

```

> 其中`<< `等价于`doLast`，但是在`Gradle 5.0`之后该方法已被废弃。

上述只是基础的创建方法，创建时还包括了其他的参数。

| 参数名          | 含义                     | 参数属性                                   |
| --------------- | ------------------------ | ------------------------------------------ |
| name            | 任务名称                 | 必须有值，不能为空                         |
| description     | 任务描述                 | 可以为空                                   |
| group           | 任务所属分组名           | 可以为空                                   |
| type            | 任务的父类               | 默认为`org.gradle.api.DefaultTask`         |
| **dependsOn**   | 任务依赖的其他Task       | 可以为空                                   |
| overwrite       | 是否覆盖已存在的同名任务 | false                                      |
| constructorArgs | 任务构造函数参数         | 可以为空(若依赖父类有构造参数，需要设置值) |
| **action**      | 任务的顺序执行序列       | `doLast(最后执行)`、`doFirst(最先执行)`    |



### Task Action(执行序列)

> 一个`Task`由一系列`Action`组成的，通过设置`action`，实质上就是在创建Task时调用到的`doFirst`、`doLast`这两个方法。

```groovy
task Task1 {
  println "Task configure"
  doFirst {
    println "Task doFirst"
  }
  doLast {
    println "Task doLast"
  }
}
```

上述代码不同的执行方式结果不同

- 执行整个`gradle`文件：

  ```xml
  Task configure
  ```

- 执行`Task1`：`./gradlew Task1`

  ```xml
  Task configure
  Task doFirst
  Task doLast
  ```

观察上述结果，得出以下结论

> 在创建Task时，除了`doFirst`、`doLast`之外的代码，都定义为`Task`的配置项，在脚本的配置阶段都会执行；而`doFirst`、`doLast`代码只会在`Task`真正执行时才会调用(gradle 指定运行该`Task`)。



### Task DependsOn(执行依赖)

> Gradle中的任务执行顺序是不确定的，需要通过task之间的依赖关系，保证被依赖的task优先执行，可通过`dependsOn`来确定依赖关系。

![Task执行顺序](/images/Task执行顺序.webp)

```groovy
task first doLast {
    println("first")
}

task second doLast {
    println("second")
}
//second 依赖于 first
second.dependsOn(first)

//third 依赖于 first,second
task third(dependsOn:[first, second]) doLast {
    println("third")
}

```

此时调用`./gradlew third`

```xml
输出结果
> Task :plugin:first
first

> Task :plugin:second
second

> Task :plugin:third
third
```

由于`third`依赖于`first、second`所以在执行`third`时，`first、second`也需要执行。

以上属于**静态依赖**。

相对的还存在**动态依赖**。

```groovy
task forth {
    dependsOn this.tasks.findAll { task ->
        return task.name.startsWith("third")
    }
    doLast {
        println "This is forth"
    }
}
```



此外可通过`shouldRunAfter`和`mustRunAfter`来控制任务之间的执行顺序

### Task Type(任务类型)

> 默认Type为`DefaultTask`，系统还提供了几种常用的类型以供使用，也可以通过自定义Type来实现功能。

#### [Copy](https://docs.gradle.org/current/dsl/org.gradle.api.tasks.Copy.html)

> 将文件复制到目标目录，此任务在复制时也可以执行重命名和过滤文件操作。

```groovy
task CopyFile(type:Copy){
    //源文件目录
    from '../app/src/main'
    //目标目录
    into './src/main/java'
}
```

`from`、`into`是最基础的配置，其他常用包括以下：

| 配置项           | 释义                   | 示例                                                         |
| ---------------- | ---------------------- | ------------------------------------------------------------ |
| include          | 只包含配置的文件       | `include '**/*.java',   '**/*.kt'`                           |
| exclude          | 排除配置的文件         | ` exclude '**/*.xml'`                                        |
| includeEmptyDirs | 是否包括空文件夹       | `true`文件夹下的所有文件夹也会被拷贝进来<br>`false`不会存在空文件夹 |
| rename           | 对指定的文件进行重命名 | `rename 'activity_*.xml' 'rename'`                           |
| with             | 执行一个闭包           | def dataContent = copySpec {<br>     from ('../src/main') { <br>        include '**/*.xml'    <br> } }<br>with dataContent |



#### [Sync](https://docs.gradle.org/current/dsl/org.gradle.api.tasks.Sync.html)

> 与Copy任务类似，不同的是**将源目录中的文件复制到目标目录中，但是会删除目标目录中非复制过来的文件。**

```groovy
task syncFile(type:Sync){
    from '../app/src/main/java'
    rename 'Main*', 'SSS'
    into './src/main/java'

    includeEmptyDirs = false
}
```

可通过设置`preverse`属性，控制哪些文件不会被覆盖

```groovy
task syncFile(type:Sync){
    from '../app/src/main/java'
    rename 'Main*', 'SSS'
    into './src/main/java'

    includeEmptyDirs = false
    preserve {
        include '**/*.xml'
    }
}
```

那么目标目录原有的`xml`不会被删除

#### 其他类型

通过[官网介绍](https://docs.gradle.org/current/dsl/)来查询其他系统支持类型

#### 自定义Type

```groovy
//设置父类
class ParentTask extends DefaultTask{
    String msg = "parent"
    int age
    int score

    @Inject
    ParentTask(int age,int score){
        this.age = age
        this.score = score
    }

    @TaskAction
    void sayHello(){
        println "hello $msg age is $age and score is $score"
    }

}

//设置type即父类为 ParentTask 设置参数为 30,100
task Task1(type:ParentTask,constructorArgs:[30,100])

task Task2(type: ParentTask,constructorArgs: [10,70]){
    msg="wxy"
}

输出结果：
> Task :plugin:Task1
hello parent age is 30 and score is 100

> Task :plugin:Task2
hello wxy age is 10 and score is 70
```

### Task Group(任务分组)&Task Description(任务描述)

> 对任务进行分组整理，使结构清晰明了
>
> 对任务进行描述，说明任务的作用

```groovy
task MyTask(description:"Task的介绍",group:"MyTaskGroup") doLast {
  println "group $group "
}

> Task :plugin:MyTask
group is MyTaskGroup and description is Task的介绍
```

可以通过执行`./gradlew -q tasks --all`查看所有task信息

```xml
MyTaskGroup tasks
-----------------
plugin:MyTask - Task的介绍
```

### Task Overwrite(任务重写)

> 对上面的任务进行覆盖，后续只会执行该任务

```groovy
task MyTask(description:"Task的介绍",group:"MyTaskGroup") doLast {
  println "group is $group and description is $description"
}

task MyTask(overwrite:true) doLast {
  println "Cover Same Task"
}
```

后续只会输出`Cover Same Task`



### Task Enable(任务启用)

> 通过设置`enabled`属性，用于启用和禁用任务，默认为`true`，表示启用。`false`则禁止该任务执行

```groovy
task MyTask {
  enabled false
}
```

运行会提示 `Task :plugin:zipFile SKIPPED`



### [TaskContainer(任务集合)](https://docs.gradle.org/current/javadoc/org/gradle/api/tasks/TaskContainer.html)

> 管理所有的Task实例，可通过`Project.getTasks()`或者`tasks`使用该实例

提供了以下常用的方法

| 方法                                                       | 介绍                          |
| ---------------------------------------------------------- | ----------------------------- |
| `create(name:String) : Task`                               | 创建任务                      |
| `create(name:String,configureClosure:Closure) : Task`      | 创建任务                      |
| `create(options: Map<String, ?>,configure: Closure): Task` | 创建任务                      |
| `findByPath(path: String): Task`                           | 查找任务                      |
| `getByName(name: String): Task`                            | 根据Task名字查找任务          |
| `withType(type: Class): TaskCollection`                    | 根据Type查找任务              |
| `register(String name):TaskProvider`                       | 按需加载任务                  |
| `replace(String name):Task`                                | 替换当前同名任务              |
| `remove(Task task)`                                        | 删除任务                      |
| `whenTaskAdded(action:Closure)`                            | task添加进TaskContainer时监听 |

```groovy
//创建Task
tasks.create("Task1"){}
tasks.create("Task2", Copy.class){
    from '../app/src/main/java'
    into './src/main/java'
}
tasks.create([name:"Task3",group:"customGroup",desription:"desc",dependsOn:["Task1"]]){
  
}

//查找Task
def task1 = tasks.findByName("Task1")
def task2 = tasks.withType(Copy.class)

//替换Task
tasks.replace("Task1"){
  
}

//监听Task添加
tasks.whenTaskAdded { task->
    if(task.name == "Task1" ){
        println "Task1 is added"
    }else{
      println "${task.name} is added"
    }
}
```



### Task增量构建

> Task会缓存每次运行的结果，在下次运行时会检查输出结果是否进行改变，没有发生变化就会跳过当次运行 。为了**提高Gradle的编译速度**。
>
> 在控制台会显示`up-to-date`表示跳过该次执行。

#### Task Input/Output(任务输入/输出)

> 任务需要接收

### Task Other

#### `onlyIf`断言

> `onlyIf`接收一个闭包作为参数，若闭包中返回`true`则执行任务，否则跳过该任务(`SKIPPED`)。**主要用于控制任务的执行场景。**

```groovy
task testOnlyIf{
    println "setOnlyIf"
    doLast{
        println "testOnlyIf run "
    }
}

testOnlyIf.onlyIf{
    if(project.hasProperty("skip")){
         !project.property("skip")
    }
    false
}
```

命令行中输入` ./gradlew testOnlyIf -Pskip=true`则提示`Task :testOnlyIf SKIPPED`。设置`-Pskip=false`则输出`testOnlyIf run `。

> 命令行中`-P`表示为`Project`指定`K-V`格式的属性键值对，使用格式为`-PK=V`

#### `finalizer`任务

> 监听任务结束状态，可以在结束后执行其他任务

```groovy
task taskx {
    doLast{
        println "taskx"
    }
}

task tasky {
    doLast{
        println "tasky"
    }
}

taskx.finalizedBy tasky
```

`./gradlew taskx -q `运行结果为 

```
> Task :plugin:taskx
taskx

> Task :plugin:tasky
tasky

taskx执行完毕就会执行tasky
```

> `Finalizer`即使运行过程中出现异常也不会影响到后续任务的执行，只有一种情况下会出现无法执行后续任务。**当前置任务根本没有执行时，不会触发后续任务执行。**



#### 判断正在执行的任务

> 监听正在执行的任务，触发需要监听的任务时，执行功能

```groovy
tasks.all {
    if("uploadArchives".equalsIgnoreCase(it.name)){
      it.doFrist{
        //触发任务前执行
      }
      
        it.doLast{
           //触发任务后执行
        }
    }
}
```



#### 挂载自定义Task在构建过程

> 在其他`Task`执行过程中，调用`自定义Task`的`execute`

```groo
task A{
 ...
}

task B{
  doFirst{
    A.execute()
  }
}
```





## 引用

[Gradle官方文档](https://docs.gradle.org/current/userguide/more_about_tasks.html)