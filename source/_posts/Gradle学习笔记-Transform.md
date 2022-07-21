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
> 尽量避免重复执行相同的工作。

存在两个标志位：

##### Transform.isIncremental

> `Transform`增量构建的开发

若为`true`，对应的`TransformTask`依然会执行，有可能触发增量构建

##### TransformInvocation.isIncremental

> 当前`Transform`对应的`Task`是否增量执行

若为`true`，对应的`TransformTask`表示增量模式。

在增量模式下，所有的`Input`都是带`Status`的。

```java
public enum Status {
    /**
     * The file was not changed since the last build.
     */
    NOTCHANGED, //不需要任何处理
    /**
     * The file was added since the last build.
     */
    ADDED,//按照正常处理流程并复制
    /**
     * The file was modified since the last build.
     */
    CHANGED,//按照正常处理流程并复制
    /**
     * The file was removed since the last build.
     */
    REMOVED;//同步删除outputProvider对应的文件
}
```



#### * transform

> 在这个方法中获取输入的Class文件，经过中间过程的修改，最后输出修改的Class文件。



##### TransformInvocation - 提供输入&输出相关信息

```java
public interface TransformInvocation {

    /**
     * Returns the context in which the transform is run.
     * @return the context in which the transform is run.
     */
    @NonNull
    Context getContext();

    /**
     * Returns the inputs/outputs of the transform.
     * @return the inputs/outputs of the transform.
     */
    @NonNull
    Collection<TransformInput> getInputs();

    /**
     * Returns the referenced-only inputs which are not consumed by this transformation.
     * @return the referenced-only inputs.
     */
    @NonNull Collection<TransformInput> getReferencedInputs();
    /**
     * Returns the list of secondary file changes since last. Only secondary files that this
     * transform can handle incrementally will be part of this change set.
     * @return the list of changes impacting a {@link SecondaryInput}
     */
    @NonNull Collection<SecondaryInput> getSecondaryInputs();

    /**
     * Returns the output provider allowing to create content.
     * @return he output provider allowing to create content.
     */
    @Nullable
    TransformOutputProvider getOutputProvider();


    /**
     * Indicates whether the transform execution is incremental.
     * @return true for an incremental invocation, false otherwise.
     */
    boolean isIncremental();
}
```

主要包括以下方法：

- **getContext**：返回`Transform`运行相关信息
- **getInputs**：返回`TransformInput`对象，主要是输入内容信息
- **getOutputProvider**：返回`TransformOutputProvider`对象，主要是返回输出文件
- **isIncremental**：当前`Transform`对应Task是否增量构建



###### TransformInput - 输入文件信息

```java
public interface TransformInput {

    /**
     * Returns a collection of {@link JarInput}.
     */
    @NonNull
    Collection<JarInput> getJarInputs();

    /**
     * Returns a collection of {@link DirectoryInput}.
     */
    @NonNull
    Collection<DirectoryInput> getDirectoryInputs();
}

```

主要包括以下两个方法：

- getJarInputs:Collection<JarInput>：以jar和aar的依赖方式参与构建的输入文件，包含本地依赖和远程依赖
- getDirectoryInputs:Collection<DirectoryInput>：以源码方式参与项目编译的所有目录结构及其中的源码文件



###### TransformOutputProvider - 输出信息

```java
public interface TransformOutputProvider {

    /**
     * Delete all content. This is useful when running in non-incremental mode
     *
     * @throws IOException if deleting the output failed.
     */
    void deleteAll() throws IOException;


     /**
     * Returns the location of content for a given set of Scopes, Content Types, and Format.
     *
     * <p>If the format is {@link Format#DIRECTORY} then the result is the file location of the
     * directory.<br>
     * If the format is {@link Format#JAR} then the result is a file representing the jar to create.
     */
    @NonNull
    File getContentLocation(
            @NonNull String name,
            @NonNull Set<QualifiedContent.ContentType> types,
            @NonNull Set<? super QualifiedContent.Scope> scopes,
            @NonNull Format format);
}
```

主要包括以下两个方法：

- **deleteAll**：清空输出目录下所有文件，用于非增量构建的情况下(`TransformInvocation.isIncremental == false `)

- **getContentLocation**：获取指定范围(`Scope`)以及指定类型(`ContentType`)还有文件类型(`Format：目前只有Directory，JAR`)的输出目标路径

  

##### 执行流程

###### 获取输入文件

主要对象为`TransformInput`，对应的文件分为两种：

- 源码文件 / `DirectoryInput`
- 依赖的Jar/aar文件 / `JarInput`

###### 获取输出路径

主要对象为`TransformOutputProvider`，需要采用指定方法获取，输出路径主要是两种：

- 源码文件输出路径 

  ```kotlin
          val dest = outputProvider.getContentLocation(
              dirInput.name,
              dirInput.contentTypes,
              dirInput.scopes,
              Format.DIRECTORY
          )
  ```

  

- 依赖的Jar/aar文件输出路径

  ```kotlin
              val dest = outputProvider.getContentLocation(
                  jarInput.name,
                  jarInput.contentTypes,
                  jarInput.scopes,
                  Format.JAR
              )
  ```

主要区别在设置的`Format`上。

###### 处理输入文件

处理上按照输入文件类型分开处理

```kotlin
    override fun transform(transformInvocation: TransformInvocation) {
      val context = transformInvocation.context
      val inputs = transformInvocation.inputs
      val outputProvider = transformInvocation.outputProvider
      val isIncremental = transformInvocation.isIncremental
      
      
     if (!isIncremental) {
            //删除所有
            outputProvider.deleteAll()
        }
        inputs.forEach { input ->
            //遍历 src下文件
            input.directoryInputs.forEach { directoryInput ->
                foreachDirectory(context, outputProvider, directoryInput, isIncremental)
            }
            //遍历jar/aar内文件
            input.jarInputs.forEach { jarInput ->
                foreachJar(context, outputProvider, jarInput, isIncremental)
            }
        } 
      
    }
```



- 源码文件(src下编译生成的class文件)

  ```kotlin
  private  fun foreachDirectory(context: Context, outputProvider: TransformOutputProvider, input: DirectoryInput, isIncremental: Boolean) {
      //
          val dir = input.file
          val dest = outputProvider.getContentLocation(
              input.name,
              input.contentTypes,
              input.scopes,
              Format.DIRECTORY
          )
          FileUtils.forceMkdir(dest)
          val srcDicPath = dir.absolutePath
          val destDicPath = dest.absolutePath
    
       //增量模式处理
       if (isIncremental) {
              val fileStatus = input.changedFiles
              fileStatus.forEach { file, status ->
                  val destFilePath = file.absolutePath.replace(srcDicPath, destDicPath)
                  val destFile = File(destFilePath)       
                  when (status) {
                      Status.ADDED, Status.CHANGED -> {
                          println("File is Updated name： ${file.name} and path ${file.absolutePath}")
                          transformDir(context,dir,inputFile,destFilePath)
                      }
                      Status.REMOVED               -> {
                          println("File is Removed name： ${file.name}")
                          if (destFile.exists()) {
                              destFile.delete()
                          }
                      }
                      else                         -> {
  
                      }
                  }        
       }else{
              FileUtils.copyDirectory(dir, dest)
              dir.walk().asSequence().filter {//按照指定格式筛选文件
                  it.isFile && checkDicClassFile(it.name)
              }.forEach { file ->
                  transformDir(context, dir, file, file.absolutePath.replace(srcDirPath, destDirPath))
              }
       }
    
       //非增量模式处理
    
  }
    
      private fun transformDir(context: Context, dir: File, inputFile: File, destFilePath: String) {
          val destFile = File(destFilePath)
          if (destFile.exists()) {
              destFile.delete()
          }
        //编辑class文件
          val modifiedFile = modifyClassFile(dir,inputFile,context.temporaryDir)
          if (modifiedFile != null) {
              FileUtils.copyFile(modifiedFile, destFile)
              modifiedFile.delete()
          } else {
              FileUtils.copyFile(inputFile, destFile)
          }
  
      }
    
  ```

  > 注意⚠️：就算不想修改class文件，也需要**原样拷贝过去**。否则该文件就会丢失！

- Jar/aar文件

  > 相比于class文件多了解压缩过程，解压后得到的class文件处理方式与上面一致，最后需要将处理后的class文件重新压缩即可。
  
  ```kotlin
      private fun foreachJar(context: Context, outputProvider: TransformOutputProvider, input: JarInput, isIncremental: Boolean) {
          if (input.file.absolutePath.endsWith("jar")) {
              var jarName = input.file.name
              val md5Name = DigestUtils.md5Hex(input.file.absolutePath)
              if (jarName.endsWith(".jar")) {
                  jarName = jarName.substring(0, jarName.length - 4)
              }
              val dest = outputProvider.getContentLocation(
                  "${jarName}_${md5Name}",
                  input.contentTypes,
                  input.scopes,
                  Format.JAR
              )
              if (isIncremental) {
                  when (input.status) {
                      Status.ADDED, Status.CHANGED -> {
                          println("Jar is Updated name： ${input.file.name}")
                          transformJar(context, dest, input)
                      }
                      Status.REMOVED               -> {
                          println("Jar is Removed and ${input.file.name}")
                          if (dest.exists()) {
                              FileUtils.forceDelete(dest)
                          }
                      }
                      else                         -> {
  
                      }
                  }
              } else {
                  transformJar(context, dest, input)
              }
  
          }
      }
  
      private fun transformJar(context: Context, dest: File, input: JarInput) {
          var modifyJar: File? = null
          modifyJar = modifyJarFile(input.file, context.temporaryDir)
          if (modifyJar == null) {
              modifyJar = input.file
          }
        //操作完成后，最后需要拷贝回去 避免文件丢失
          FileUtils.copyFile(modifyJar, dest)
      }
  ```
  

```mermaid
flowchart TB
id1((开始))
id2(transform)
id1 --> id2
id3{isIncremental}
id2--> id3
id4(outputProvider.deleteAll)
id3--非增量模式/false-->id4
id5(遍历transformInvocation.inputs)
id4-->id5
id3--增量模式/true-->id5
id7(遍历\ndirectoryInputs)
id6(遍历\njarInputs)
id5-->id6
id5-->id7
id71(遍历\nsrc下class文件)
id72(执行hook)
id73(拷贝修改后class文件到\noutputProvider.getContentLocation位置)
id7-->id71-->id72-->id73
id61(遍历jarinput下jar/aar文件)
id62(解压jar/aar文件)
id63(遍历内部class文件)
id64(执行hook)
id65(修改完的class文件打包成jar文件)
id66(拷贝修改后jar文件到\noutputProvider.getContentLocation位置)
id6-->id61-->id62-->id63-->id64-->id65-->id66
id8((transform\n结束))
id66-->id8
id73-->id8

```



#### 注册Transform

> 实现一个`Transform`后，需要注册才可以功能生效。

```kotlin
class CustomPlugin : Plugin<Project> {
    override fun apply(project: Project) {
      //处理extension等信息
      ...
       //判定当前为 app module
        val appExtension = project.extensions.findByType(AppExtension::class.java)
        if (appExtension != null) {
            appExtension.registerTransform(MethodTraceTransform(project, true))
        } else {
          //判定当前为 library module
            val libExtension = project.extensions.findByType(LibraryExtension::class.java)
            libExtension?.registerTransform(MethodTraceTransform(project, false))
        }
    }
}
```



### 工作原理

#### 注册Transform

> 主要是将`Transform`注册在`BaseExtension`中。

```kotlin
abstract class BaseExtension protected constructor(
  ...
    private val _transforms: MutableList<Transform> = mutableListOf()
    private val _transformDependencies: MutableList<List<Any>> = mutableListOf()
  ...
  
    fun registerTransform(transform: Transform, vararg dependencies: Any) {
        dslServices.deprecationReporter.reportDeprecatedApi(
            newApiElement = null,
            oldApiElement = "android.registerTransform",
            url = "https://developer.android.com/studio/releases/gradle-plugin-api-updates#transform-api",
            deprecationTarget = DeprecationReporter.DeprecationTarget.TRANSFORM_API
        )
        _transforms.add(transform)
        _transformDependencies.add(listOf(dependencies))
    }
  
    override val transforms: List<Transform>
        get() = ImmutableList.copyOf(_transforms)

    override val transformsDependencies: List<List<Any>>
        get() = ImmutableList.copyOf(_transformDependencies)
  
  }
```

内部的`transforms`由外部调用，`GlobalTaskCreationConfigImpl`使用到了`transforms`

```kotlin
    override val transforms: List<Transform>
        get() = oldExtension.transforms
```

`GlobalTaskCreationConfigImpl`为`GlobalTaskCreationConfig`实现类，所以`GlobalTaskCreationConfig`对应的`transforms`即为`BaseExtension`注册进来的`Transform`。



#### 创建TransformTask

由{%post_link Gradle学习笔记-AGP原理%}可知Task的构建流程

都是由`BasePlugin.createAndroidTasks`开始的，其他细节在{%post_link Gradle学习笔记-AGP原理%}有详细介绍

##### BasePlugin.createAndroidTasks

```java
    final void createAndroidTasks() {
        GlobalTaskCreationConfig globalConfig = variantManager.getGlobalTaskCreationConfig();
     ...
        TaskManager<VariantBuilderT, VariantT> taskManager =
                createTaskManager(
                        project,
                        variants,
                        variantManager.getTestComponents(),
                        variantManager.getTestFixturesComponents(),
                        globalConfig,
                        taskManagerConfig,
                        extension);

        taskManager.createTasks(variantFactory.getVariantType(), createVariantModel(globalConfig));
    }
```

##### TaskManager.createTasks

```kotlin
    fun createTasks(
            variantType: VariantType, variantModel: VariantModel) {
      ...
        // Create tasks for all variants (main, testFixtures and tests)        
        for (variant in variants) {
            createTasksForVariant(variant)
        }
    }

    private fun createTasksForVariant(
            variant: ComponentInfo<VariantBuilderT, VariantT>,
    ){
      ...
        doCreateTasksForVariant(variant)
    }

    protected abstract fun doCreateTasksForVariant(
            variantInfo: ComponentInfo<VariantBuilderT, VariantT>)
```

##### TaskManager.doCreateTasksForVariant

> `TaskManager`是抽象类，主要实现类为
>
> - `ApplicationTaskManager`：对应 app module
> - `LibraryTaskManager`：对应 library module

以`LibraryTaskManager`为例

```java
    @Override
    protected void doCreateTasksForVariant(
            @NotNull ComponentInfo<LibraryVariantBuilderImpl, LibraryVariantImpl> variantInfo) {
      //创建其他Task
      ...
      TransformManager transformManager = libraryVariant.getTransformManager();
      
      //对应的BaseExtension 注册的Transform
       List<Transform> customTransforms = globalConfig.getTransforms();
       List<List<Object>> customTransformsDependencies = globalConfig.getTransformsDependencies();
      
       for (int i = 0, count = customTransforms.size(); i < count; i++) {
            Transform transform = customTransforms.get(i);
         //library module 只支持 PROJECT_ONLY
            Sets.SetView<? super Scope> difference =
                    Sets.difference(transform.getScopes(), TransformManager.PROJECT_ONLY);
            if (!difference.isEmpty()) {
                String scopes = difference.toString();
                issueReporter.reportError(
                        Type.GENERIC,
                        String.format(
                                "Transforms with scopes '%s' cannot be applied to library projects.",
                                scopes));
            }            
         //创建TransformTask
            transformManager.addTransform(
                    taskFactory,
                    libraryVariant,
                    transform,
                    null,
                    task -> {
                        if (!deps.isEmpty()) {
                            task.dependsOn(deps);
                        }
                    },
                    taskProvider -> {
                        // if the task is a no-op then we make assemble task
                        // depend on it.
                        if (transform.getScopes().isEmpty()) {
                            TaskFactoryUtils.dependsOn(
                                    libraryVariant.getTaskContainer().getAssembleTask(),
                                    taskProvider);//依赖assembleXXTask后执行
                        }
                    });                
       }
    }
```

##### TransformManager.addTransform

```java
    @NonNull
    public <T extends Transform> Optional<TaskProvider<TransformTask>> addTransform(
            @NonNull TaskFactory taskFactory,
            @NonNull VariantCreationConfig creationConfig,
            @NonNull T transform, //the transform to add
            @Nullable PreConfigAction preConfigAction,
            @Nullable TaskConfigAction<TransformTask> configAction,
            @Nullable TaskProviderCallback<TransformTask> providerCallback) {
      //设置Task name   transform[getInputTypes]With[getName]For[creationConfig.name]
      //示例名称 transform[Classes]With[MethodTrace]For[Release]
        String taskName = creationConfig.computeTaskName(getTaskNamePrefix(transform), "");      
      
      //创建TransformTask
        return Optional.of(
                taskFactory.register(//注册创建的TransformTask
                        new TransformTask.CreationAction<>(
                                creationConfig.getName(),
                                taskName,
                                transform,
                                inputStreams,
                                referencedStreams,
                                outputStream),
                        preConfigAction,
                        wrappedConfigAction,
                        providerCallback));      
    }

//最终得到的TaskName格式为 
    static String getTaskNamePrefix(@NonNull Transform transform) {
        StringBuilder sb = new StringBuilder(100);
        sb.append("transform");

        sb.append(
                transform
                        .getInputTypes()
                        .stream()
                        .map(
                                inputType ->
                                        CaseFormat.UPPER_UNDERSCORE.to(
                                                CaseFormat.UPPER_CAMEL, inputType.name()))
                        .sorted() // Keep the order stable.
                        .collect(Collectors.joining("And")));
        sb.append("With");
        StringHelper.appendCapitalized(sb, transform.getName());
        sb.append("For");

        return sb.toString();
    }

```

##### TransformTask.CreationAction

```java
@CacheableTask
public abstract class TransformTask extends StreamBasedTask {
  //TransformTask 输入
    @Input
    @NonNull
    public Set<? super QualifiedContent.Scope> getScopes() {
        return transform.getScopes();
    }
  
    @Input
    @NonNull
    public Set<QualifiedContent.ContentType> getInputTypes() {
        return transform.getInputTypes();
    }  
  
  //TransformTask 输出
    @OutputDirectory
    @Optional
    @NonNull
    public abstract DirectoryProperty getOutputDirectory();

    @OutputFile
    @Optional
    @NonNull
    public abstract RegularFileProperty getOutputFile();
  
 ...
   
    public static class CreationAction<T extends Transform>
            extends TaskCreationAction<TransformTask> {
        @NonNull
        private final String variantName;
        @NonNull
        private final String taskName;
        @NonNull
        private final T transform;
      
      ...
        @Override
        public void configure(@NonNull TransformTask task) {
            task.transform = transform;
            transform.setOutputDirectory(task.getOutputDirectory());
            transform.setOutputFile(task.getOutputFile());
        ...
      }
    }
  
}
```

最后创建一个名为`transform[getInputTypes]With[getName]For[creationConfig.name]`的Task，并注册到当前module中。

#### 执行TransfromTask(执行transform())

执行`Task`实际执行的是`自定义Task`内部实现了`@TaskAction`的方法

```java
//TransformTask.java
    @TaskAction
    void transform(final IncrementalTaskInputs incrementalTaskInputs)
            throws IOException, TransformException, InterruptedException {
      ...
        
                        transform.transform(
                                new TransformInvocationBuilder(context)
                                        .addInputs(consumedInputs.getValue())
                                        .addReferencedInputs(referencedInputs.getValue())
                                        .addSecondaryInputs(changedSecondaryInputs.getValue())
                                        .addOutputProvider(
                                                outputStream != null
                                                        ? outputStream.asOutput()
                                                        : null)
                                        .setIncrementalMode(isIncremental.getValue())
                                        .build());        
      
    }
```

最终执行到了`自定义Transform`的`transform()`。



#### 增量模式实现

> 若`isIncremental`为true，则返回的文件会携带状态，根据不同的状态执行不同的逻辑。

```java
//TransformTask.java
    private static void gatherChangedFiles(
            @NonNull Logger logger,
            @NonNull IncrementalTaskInputs incrementalTaskInputs,
            @NonNull final Map<File, Status> changedFileMap,
            @NonNull final Set<File> removedFiles) {
        logger.info("Transform inputs calculations based on following changes");
        incrementalTaskInputs.outOfDate(inputFileDetails -> {
            logger.info(inputFileDetails.getFile().getAbsolutePath() + ":"
                    + IntermediateFolderUtils.inputFileDetailsToStatus(inputFileDetails));
            if (inputFileDetails.isAdded()) {
                changedFileMap.put(inputFileDetails.getFile(), Status.ADDED);
            } else if (inputFileDetails.isModified()) {
                changedFileMap.put(inputFileDetails.getFile(), Status.CHANGED);
            }
        });

        incrementalTaskInputs.removed(
                inputFileDetails -> {
                        logger.info(inputFileDetails.getFile().getAbsolutePath() + ":REMOVED");
                        removedFiles.add(inputFileDetails.getFile());
                });
    }
```

由`Gradle`中的`TaskExecution.execute()`处理对应的文件。

会在{%post_link Gradle学习笔记-构建流程%}详细分析。

```mermaid
flowchart LR
id(compileReleaseJavaWithJavac\nTask产物)
id--->id1
id--->id2
id--->id3
subgraph JarInput
 id2(jar/aar)
end

 subgraph DirectoryInput
  id1(class)
  id3(resource)
 end
 
 id4(自定义Transform)
 id1-.->id4
 id2-.->id4
 id3-.->id4
 
 id4--->id5
 
 id5(自定义Transform)
 id5-.->id6
 
 id6(系统Transform)

```

基于上面分析，每个`Transform`都对应一个`TransformTask`，Android编译器中的`TaskManager`将每个`Transform`串连起来。

第一个`自定义Transform`接受来自`compileJavaWithJavac(对应源码 JavaCompileCreationAction)`Task的中间产物

- javac编译得到的class文件
- 远端/本地的第三方依赖
- resource资源

这些产物在`Transform链`上传递，处理完成后再向下一个进行传递。



## Transform模板

> 大部分功能代码是一致的，主要差异在于字节码的处理上，由此可以抽象出一套模板写法，实现方只要处理字节码部分即可。



## TransformAction

## 参考链接

[Transform-API](http://tools.android.com/tech-docs/new-build-system/transform-api)

[Gradle-Transform 分析](https://juejin.cn/post/7098752199575994405#heading-8)
