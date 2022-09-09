---
title: Gradle学习笔记-Android打包过程
typora-root-url: ../
date: 2022-03-18 21:54:32
tags: Gradle
top: 9
---

## 概述

### APK组成

> 对`Apk文件`进行解压处理，本质是`Zip`，解压后可以看到若干文件。

主要由以下部分组成：

| 文件/目录           | 描述                                                         |
| ------------------- | ------------------------------------------------------------ |
| lib/                | 存放`so文件`，一般情况下包含`armeabi-v7a`、`arm64-v8a`这两个目录，其他还有`x86`、`armeabi`等。 |
| res/                | 存放编译后的资源文件，例如`drawable`、`layout`等             |
| META_INF/           | 一般存在于已经签名的Apk中，记录`签名摘要`等信息              |
| assets/             | 应用程序的资源，可通过`AssetManager`来检索对应资源           |
| classes(n).dex      | `classes`对应`Java Class`，被编译成`Dex`后，可以被`Dalvik/ART`虚拟机所理解 |
| resources.arsc      | 打包过程中产生的资源索引文件。**用于包体积优化，可对重复资源、资源文件名混淆提供分析** |
| AndroidManifest.xml | 用于描述`App名称、版本、所需权限以及注册的四大组件`。        |

后续打包流程的介绍，也会分析具体部分生成的时机以及内容。

### 打包流程

![Apk构建流程](/images/Android_Build_Process.svg)

流程中的椭圆形部分为打包过程中所需要用到的工具，下面简单的介绍下

> 主要执行文件的位置在${ANDROID_SDK_HOME}/build-tools/XX/

| 名称                    | 功能介绍                        |
| ----------------------- | ------------------------------- |
| aapt(`aapt2`)           | Android资源打包工具             |
| aidl                    | Android接口描述语言 -> Java文件 |
| javac                   | Java编译器                      |
| dex(`d8`)               | 打包`class文件`为`dex`          |
| apkbuilder(`apkfinger`) | 生成apk                         |
| zipalign                | 字节码对齐工具                  |

根据上图可以得出，Android打包流程主要分为两部分：

- **编译**
  - 资源文件编译 - 通过`AAPT2`编译
  - aidl文件编译 - 编译成Java文件
  - kotlin/java文件编译 - `javac`编译成class文件 
  - jni相关文件编译 - 编译成so文件
- **打包**
  - 打包class为dex文件 - 使用`D8 R8`编译
  - 打包dex和编译后资源为apk - 使用`ApkFlinger`打包
  - 给apk签名 - 使用`v2/v3/v4`方式签名



### 打包相关Task

通过执行`./gradlew assembleRelease` 观察执行哪些Task

```ruby
=========TaskExecutionGraph:app:buildKotlinToolingMetadata=========
=========TaskExecutionGraph:app:preBuild=========
=========TaskExecutionGraph:app:preReleaseBuild=========
=========TaskExecutionGraph:app:compileReleaseAidl=========
=========TaskExecutionGraph:app:compileReleaseRenderscript=========
=========TaskExecutionGraph:app:generateReleaseBuildConfig=========
=========TaskExecutionGraph:app:checkReleaseAarMetadata=========
=========TaskExecutionGraph:app:generateReleaseResValues=========
=========TaskExecutionGraph:app:generateReleaseResources=========
=========TaskExecutionGraph:app:mergeReleaseResources=========
=========TaskExecutionGraph:app:packageReleaseResources=========
=========TaskExecutionGraph:app:mapReleaseSourceSetPaths=========
=========TaskExecutionGraph:app:parseReleaseLocalResources=========
=========TaskExecutionGraph:app:createReleaseCompatibleScreenManifests=========
=========TaskExecutionGraph:app:extractDeepLinksRelease=========
=========TaskExecutionGraph:app:processReleaseMainManifest=========
=========TaskExecutionGraph:app:processReleaseManifest=========
=========TaskExecutionGraph:app:processReleaseManifestForPackage=========
=========TaskExecutionGraph:app:processReleaseResources=========
=========TaskExecutionGraph:app:compileReleaseKotlin=========
=========TaskExecutionGraph:app:javaPreCompileRelease=========
=========TaskExecutionGraph:app:compileReleaseJavaWithJavac=========
=========TaskExecutionGraph:app:extractProguardFiles=========
=========TaskExecutionGraph:app:lintVitalAnalyzeRelease=========
=========TaskExecutionGraph:app:lintVitalReportRelease=========
=========TaskExecutionGraph:app:lintVitalRelease=========
=========TaskExecutionGraph:app:mergeReleaseJniLibFolders=========
=========TaskExecutionGraph:app:mergeReleaseNativeLibs=========
=========TaskExecutionGraph:app:stripReleaseDebugSymbols=========
=========TaskExecutionGraph:app:extractReleaseNativeSymbolTables=========
=========TaskExecutionGraph:app:mergeReleaseNativeDebugMetadata=========
=========TaskExecutionGraph:app:checkReleaseDuplicateClasses=========
=========TaskExecutionGraph:app:transformReleaseClassesWithAsm=========
=========TaskExecutionGraph:app:dexBuilderRelease=========
=========TaskExecutionGraph:app:desugarReleaseFileDependencies=========
=========TaskExecutionGraph:app:mergeExtDexRelease=========
=========TaskExecutionGraph:app:mergeDexRelease=========
=========TaskExecutionGraph:app:mergeReleaseArtProfile=========
=========TaskExecutionGraph:app:compileReleaseArtProfile=========
=========TaskExecutionGraph:app:mergeReleaseShaders=========
=========TaskExecutionGraph:app:compileReleaseShaders=========
=========TaskExecutionGraph:app:generateReleaseAssets=========
=========TaskExecutionGraph:app:mergeReleaseAssets=========
=========TaskExecutionGraph:app:compressReleaseAssets=========
=========TaskExecutionGraph:app:processReleaseJavaRes=========
=========TaskExecutionGraph:app:mergeReleaseJavaResource=========
=========TaskExecutionGraph:app:optimizeReleaseResources=========
=========TaskExecutionGraph:app:collectReleaseDependencies=========
=========TaskExecutionGraph:app:sdkReleaseDependencyData=========
=========TaskExecutionGraph:app:writeReleaseAppMetadata=========
=========TaskExecutionGraph:app:writeReleaseSigningConfigVersions=========
=========TaskExecutionGraph:app:packageRelease=========
=========TaskExecutionGraph:app:createReleaseApkListingFileRedirect=========
=========TaskExecutionGraph:app:assembleRelease=========

```

以上是执行`assembleRelease`相关的Task，与上述打包流程相关的主要是以下Task，重点分析的也是这些关联Task



- **编译**

  - 资源文件编译 - 通过`AAPT2`编译

    > generateBuildConfig - 生成BuildConfig.java
    >
    > mergeResources - merge资源文件
    >
    > mergeAssets - merge assets/下资源文件
    >
    > processManifest - merge AndroidManifest.xml文件
    >
    > processResources -  生成R.java文件 处于AAPT2链接阶段

  - aidl文件编译 - 编译成Java文件 

    > compileAidl - 编译aidl文件

  - kotlin/java文件编译 - `javac`编译成class文件 

    > compileKotlin - 编译kotlin文件
    >
    > compileJavaWithJavac - 编译java文件为class文件

  - jni相关文件编译 - 编译成so文件

    > externalNativeBuild - 编译C/C++等文件为so
    >
    > mergeJniLibFolders - 合并依赖的Native库
    >
    > stripDebugSymbols - 剔除debug符号

  - class文件处理 - 类似`Transform`进行字节码操作

    > transformClassesWithAsm - 实现`AsmClassVisitorFactory`

- **打包**

  - 打包class为dex文件 - 使用`D8 R8`编译

    > dexBuilder - 打包class

  - 打包dex和编译后资源为apk - 使用`ApkFlinger`打包

    > package - 打包Apk

  - 给apk签名 - 使用`v2/v3/v4`方式签名



## 主流程分析

### 资源与代码编译

#### 资源文件编译

> Apk资源主要包含以下几种：
>
> - `res`目录下所有文件，例如`drawable`、`layout`等文件目录下
> - `assets`目录下文件
> - 各Module下的`AndroidManifest.xml`

##### mergeAssets&packageAssets-合并assets文件

> - mergeAssets：合并所有的`assets`文件
> - packageAssets：合并**子module**中的`assets`文件

上述Task对应的源码实现类位于`com.android.build.gradle.tasks.MergeSourceSetFolders`中

```kotlin
    class MergeAppAssetCreationAction(creationConfig: ComponentCreationConfig) :
        MergeAssetBaseCreationAction(
            creationConfig,
            true
        ) {

        override val name: String
            get() = computeTaskName("merge", "Assets")

        override fun handleProvider(
            taskProvider: TaskProvider<MergeSourceSetFolders>
        ) {
            super.handleProvider(taskProvider)

            creationConfig.artifacts.use(taskProvider)
                .wiredWith { it.outputDir }
                .toAppendTo(MultipleArtifact.ASSETS)
        }
    }

    class LibraryAssetCreationAction(creationConfig: ComponentCreationConfig) :
        MergeAssetBaseCreationAction(
            creationConfig,
            false
        ) {

        override val name: String
            get() = computeTaskName("package", "Assets")

        override fun handleProvider(
            taskProvider: TaskProvider<MergeSourceSetFolders>
        ) {
            super.handleProvider(taskProvider)

            creationConfig.artifacts.setInitialProvider(
                taskProvider,
                MergeSourceSetFolders::outputDir
            ).withName("out").on(InternalArtifactType.LIBRARY_ASSETS)
        }
    }
```

最终合并完成的`assets`位于`build/intermediates/assets`下。



> 以`MergeAssets`Task为契机，可以实现类似`assets`文件压缩或者无用文件删除功能。

//todo 示例

##### processManifest-合并AndroidManifest.xml文件 

> - processManifest - 处理`子module`的`AndroidManifest.xml`文件
> - processMainManifest - 处理`app module`的`AndroidManifest.xml`文件
> - processManifestForPackage - 处理`merged_manifests`，位于`build/intermediates/merged_manifests`。最后合并得到打到Apk里的`AndroidManifest.xml`，位于`build/intermediates/packaged_manifest`

上述Task对应源码分别如下：

processManifest - `ProcessLibraryManifest`

```kotlin
```

processMainManifest - `ProcessApplicationManifest`

```kotlin

```

processManifestForPackage - `ProcessPackagedManifestTask`

```kotlin
```



> 以`processManifestForPackage`为契机，可以实现类似`隐私权限检测`、`新增页面检查`等功能

//todo 示例

##### *mergeResources&processResources-处理res下资源文件



#### AIDL文件编译

##### compileAidl-编译aidl为java

#### Kotlin/Java文件编译

##### compileKotlin

##### compileJavaWithJavac

#### jni相关文件编译

##### externalNativeBuild

##### mergeNativeLibs

### 打包流程

#### 打包成Dex

##### dexBuilder

#### 打包成Apk

##### package



## 相关链接

[Apk构建流程](http://tools.android.com/tech-docs/new-build-system/build-workflow)

[Android签名相关](https://source.android.com/docs/security/apksigning?hl=zh-cn)

