---
title: Gradle学习笔记-Transform & TransformAction
typora-root-url: ../
date: 2022-03-10 21:54:06
tags: Gradle
top: 9
---

`Transform API`存在于`AGP`中，存在版本为`4.2-7.0+`，后续在8.0时就会被移除。

## Transform

> `AGP 1.5`引入的特性，**主要用于在构建过程中，在`Class->Dex`修改Class字节码，通过Transform可以获得Class文件。**
>
> 再通过`Javassist`或`ASM`对字节码进行修改，插入自定义逻辑。

[AGP插件版本说明](https://developer.android.com/studio/releases/gradle-plugin?hl=zh-cn#groovy)

后面的分析基于以下版本：

- AGP：[7.2.1](https://android.googlesource.com/platform/tools/base/+/studio-master-dev/build-system/README.md) 本次采用依赖 "com.android.tools.build:gradle:7.2.1"来分析
- Gradle：[7.3.3 ](https://github.com/gradle/gradle/tree/v7.3.3)

### 使用场景

- **埋点统计**：在页面展现和退出等生命周期中插入埋点统计代码，以统计页面展现数据
- **耗时监控**：在指定方法的前后插入耗时计算，以观察方法执行时间
- **方法替换**：将方法调用替换为调用另一个方法 
- 信息读取：解析编译产生的.class文件，得到一些有用的数据，做其他操作

### 工作机制

> 使用`Transform`无需关注相关task的生成与执行，主要在于处理输入的`资源文件`

#### 工作时机

工作在Android构建过程中的`.class Files -> Dex`节点

#### 处理对象

- javac 编译后的Class文件
- resource资源
- 本地/远程依赖的jar/aar文件

#### Transform Task

每个Transform都对应一个Task，对应名称为 `transform${inputTypes}With${TransformName}For${Variant}`，例如`transformClassesWithMethodTraceForRelease`

*Transform 内的输入输出实际对应的就是Task 的输入输出。*

最后`Transform`输出的内容都会存储在`${moduleName}/build/intermediates/transforms/${TransformName}/${Variant}`，例如`app/build/intermediates/transforms/MethodTrace/release`

#### Transform链

`TaskManager`将每个`Transform Task`串连起来，前一个的输出会做为下一个的输入信息。



### 相关API

以下为Transform中的核心方法

```kotlin
class TestTransform : Transform() {
    override fun getName(): String {
        TODO("Not yet implemented")
    }

    override fun getInputTypes(): MutableSet<QualifiedContent.ContentType> {
        TODO("Not yet implemented")
    }
 
    override fun getOutputTypes(): MutableSet<QualifiedContent.ContentType> {
        return super.getOutputTypes()
    }

    override fun getScopes(): MutableSet<in QualifiedContent.Scope> {
        TODO("Not yet implemented")
    }

    override fun isIncremental(): Boolean {
        TODO("Not yet implemented")
    }

    override fun transform(transformInvocation: TransformInvocation?) {
        super.transform(transformInvocation)
    }
    
}
```

#### getName

> 指定`Transform`名称，后续也是对应的Task名称
>
> Task命名规则为：**transform${inputTypes}With${TransformName}For${Variant}**

#### getInputTypes/getOutputTypes

> 指定`Transform`输入/输出类型，对象为`ContentType`。
>
> 其中`getOutputTypes`默认与`getInputTypes`一致

##### ContentType——内容类型

> 输入或输出的内容类型。

###### * DefaultContentType(自定义时使用)

```java
enum DefaultContentType implements ContentType {
        /**
         * The content is compiled Java code. This can be in a Jar file or in a folder. If
         * in a folder, it is expected to in sub-folders matching package names.
         */
        CLASSES(0x01),

        /** The content is standard Java resources. */
        RESOURCES(0x02);
}
```

- **CLASSES**：Java字节码，包括Jar文件
- **RESOURCES**：Java资源文件



###### ExtendedContentType(内部Transform使用)

```java
public enum ExtendedContentType implements ContentType {
    /**
     * The content is dex files.
     */
    DEX(0x1000),

    /**
     * Content is a native library.
     */
    NATIVE_LIBS(0x2000),

    /**
     * Instant Run '$override' classes, which contain code of new method bodies.
     *
     * <p>This stream also contains the AbstractPatchesLoaderImpl class for applying HotSwap
     * changes.
     */
    CLASSES_ENHANCED(0x4000),

    /**
     * The content is an artifact exported by the data binding compiler.
     */
    DATA_BINDING(0x10000),


    /** The content is a dex archive. It contains a single DEX file per class. */
    DEX_ARCHIVE(0x40000)
  
}
```

> 通常使用`TransformManager`设置类型

```java
    public static final Set<ContentType> CONTENT_CLASS = ImmutableSet.of(CLASSES);
    public static final Set<ContentType> CONTENT_JARS = ImmutableSet.of(CLASSES, RESOURCES);
    public static final Set<ContentType> CONTENT_RESOURCES = ImmutableSet.of(RESOURCES);
```

##### 示例代码

```kotlin
    override fun getInputTypes(): MutableSet<QualifiedContent.ContentType> {
        return TransformManager.CONTENT_CLASS
    }
```



#### getScopes

> 指定`Transform`处理哪些作用域的输入文件

##### Scope——处理范围

###### * Scope(自定义时使用)

```java
    enum Scope implements ScopeType {
        /** Only the project (module) content */
        PROJECT(0x01),
        /** Only the sub-projects (other modules) */
        SUB_PROJECTS(0x04),
        /** Only the external libraries */
        EXTERNAL_LIBRARIES(0x10),
        /** Code that is being tested by the current variant, including dependencies */
        TESTED_CODE(0x20),
        /** Local or remote dependencies that are provided-only */
        PROVIDED_ONLY(0x40)
    }
```

- **PROJECT**：当前模块

- **SUB_PROJECTS**：子模块

- **EXTERNAL_LIBRARIES**：外部依赖，包括当前和子模块所依赖的Jar/AAR

- **TESTED_CODE**：测试代码

- **PROVIDED_ONLY**：本地和远程依赖的Jar/AAR

**若为子Module注册Transform，则只能使用`Scope.PROJECT`。**

> 通常使用`TransformManager`设置作用域

```java
    public static final Set<ScopeType> PROJECT_ONLY = ImmutableSet.of(Scope.PROJECT); 
    public static final Set<ScopeType> SCOPE_FULL_PROJECT =
            ImmutableSet.of(Scope.PROJECT, Scope.SUB_PROJECTS, Scope.EXTERNAL_LIBRARIES);//通常使用较多，若为子Module就别用这个
```



###### InternalScope(内部Transform使用)

```java
public enum InternalScope implements QualifiedContent.ScopeType {

    /**
     * Scope to package classes.dex files in the main split APK in InstantRun mode. All other
     * classes.dex will be packaged in other split APKs.
     */
    MAIN_SPLIT(0x10000),

    /**
     * Only the project's local dependencies (local jars). This is to be used by the library plugin
     * only (and only when building the AAR).
     */
    LOCAL_DEPS(0x20000),

    /** Only the project's feature or dynamic-feature modules. */
    FEATURES(0x40000),
    ;
}
```



##### 示例代码

```kotlin
    override fun getScopes(): MutableSet<in QualifiedContent.Scope> {
        val set = mutableSetOf<QualifiedContent.Scope>()
        set.add(QualifiedContent.Scope.PROJECT)
        if (isApp) { //是否为app module
            set.add(QualifiedContent.Scope.EXTERNAL_LIBRARIES)
        }
        return set
    }
```



#### isIncremental

> 当前`Transform`是否支持增量编译
>
> 

#### transform

##### TransformOutputProvider

##### TransformInput



### 工作原理

## TransformAction
