---
title: Android-DataBinding分析
typora-root-url: ../
date: 2022-05-08 21:22:49
tags: Android
top: 9
---

> 分析基于 androidx.databinding 4.1.3版本进行

## 源码&编译

[源码地址](https://android.googlesource.com/platform/frameworks/data-binding/)

```shell
git clone https://android.googlesource.com/platform/tools/buildSrc

git clone https://android.googlesource.com/platform/frameworks/data-binding
```

基于分支 **studio-main**



分析用源xml文件 `fragment_test_db.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<layout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto">

    <data>

        <import type="java.util.HashMap" />

        <import type="com.example.behaviordemo.bindingadapter.ShapeBuilder" />

        <import type="android.graphics.Color" />

        <variable
            name="text"
            type="String" />

        <variable
            name="map"
            type="HashMap&lt;String,String>" />

    </data>

    <androidx.constraintlayout.widget.ConstraintLayout
        android:layout_width="match_parent"
        android:layout_height="match_parent">

        <TextView
            android:id="@+id/tv_txt"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="@{text, default = 23456}"
            app:layout_constraintLeft_toLeftOf="parent"
            app:layout_constraintTop_toTopOf="parent" />

        <ImageView
            setShape="@{ShapeBuilder.create().setCornerRadius(10).setColors(Color.RED).setShapeType(0)}"
            android:layout_width="100dp"
            android:layout_height="50dp"
            app:layout_constraintRight_toRightOf="parent"
            app:layout_constraintTop_toTopOf="parent" />

        <ImageView
            android:layout_width="100dp"
            android:layout_height="50dp"
            app:layout_constraintBottom_toBottomOf="parent"
            app:layout_constraintLeft_toLeftOf="parent"
            app:layout_constraintTop_toTopOf="parent"
            android:background='@{"#00ff00"}'/>

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="@{tvTxt.text}"
            app:layout_constraintBottom_toBottomOf="parent"
            app:layout_constraintRight_toRightOf="parent"
            app:layout_constraintTop_toTopOf="parent"/>

    </androidx.constraintlayout.widget.ConstraintLayout>
</layout>
```



```kotlin
@BindingAdapter("setShape")
fun setShape(view: View, builder: ShapeBuilder) {
    view.background = builder.mGradientDrawable
}

@BindingAdapter("setShape1")
fun setShape1(view: View, builder: ShapeBuilder) {
    view.background = builder.mGradientDrawable
}

@BindingAdapter(
    value = ["android:beforeTextChanged", "android:onTextChanged", "android:afterTextChanged", "android:textAttrChanged"],
    requireAll = false
)
fun setTextChange(
    view: TextView,
    before: TextViewBindingAdapter.BeforeTextChanged,
    on: TextViewBindingAdapter.OnTextChanged,
    after: TextViewBindingAdapter.AfterTextChanged,
    textAttrChanged: InverseBindingListener
) {

}

@BindingConversion
fun colorToDrawable(color: String): ColorDrawable {
    val colorInt = Color.parseColor(color)
    return ColorDrawable(colorInt)
}
```

用于分析生成后的文件



### 核心模块

- compiler
  
  > APT模块，负责layout下xml文件解析以及生成DataBinding所需文件
  > 对应artifactId `databinding-compiler`
- compilerCommon
  
  > 与`compiler`功能保持一致，有些许的差别
  > 对应artifactId `databinding-compiler-common`
- baseLibrary(`支持androidX`)/baseLibrarySuppor(`支持support`)
  
  > 对外提供`DataBinding`相关注解
  > 对应artifactId `databinding-common`
- extensions/baseAdapters
  
  > 封装相关View的属性改变方法，与实际View进行隔离
  > 对应artifactId `databinding-adapters`
- extensions/library
  
  > 提供可被观察的对象，例如`ObservableXX`
  > 对应artifactId `databinding-runtime`

### 其他模块

- extensions/viewbinding
  
  > ViewBinding相关实现
  > 对应artifactId `viewbinding`
- extensions/databindingKtx
  
  > ViewBinding Ktx拓展函数实现
  > 对应artifiactId `databinding-ktx`

## DataBinding Plugin——解析XML及生成相关文件

{% post_link Android-DataBinding-GradlePlugin分析 %}

## DataBinding 源码解析

### 相关模块

### 核心类

### 执行流程

## 相关小结

### ViewBinding与DataBinding区别？

### 新建Xml后DataBinding文件如何生成？不需要通过build去生成

https://cs.android.com/android-studio/platform/tools/adt/idea/+/mirror-goog-studio-main:android/src/com/android/tools/idea/databinding/
Android Studio 提供了DataBinding相关的文件生成与解析，待后续理解AS相关源码分析

### DataBinding针对ViewStub的处理

## DataBinding编译错误及临时解决方案记录

### 资源无法下载

在各个`build.gradle`添加如下配置

```groovy
buildscript{
  XXX
  repositories {  
    google()  
    jcenter()  
    mavenCentral()  
  }
}
```

### 找不到addRemoteRepos参数

修改`propLoader.gradle`

```groovy
//def addRemoteRepos = getBooleanValue(project, "addRemoteRepos", false)  
ext.dataBindingConfig.addRemoteRepos = true
```

修改`settings.gradle`

```groovy
include ':dataBinding:baseLibrary'  
project(':dataBinding:baseLibrary').projectDir = new File("baseLibrary")  
include ':dataBinding:baseLibrarySupport'  
project(':dataBinding:baseLibrarySupport').projectDir = new File("baseLibrarySupport")  
include ':dataBinding:compiler'  
project(':dataBinding:compiler').projectDir = new File("compiler")  
//include ':dataBinding:compilationTests'  
//project(':dataBinding:compilationTests').projectDir = new File("compilationTests")  
include ':dataBinding:compilerCommon'  
project(':dataBinding:compilerCommon').projectDir = new File("compilerCommon")  
//include ':dataBinding:exec'  
//project(':dataBinding:exec').projectDir = new File("exec")
```

注释掉的内容并不影响`data-binding`相关源码分析及查看



## 参考链接

[DataBinding注解详解](https://www.twblogs.net/a/5b8085ab2b71772165a81a8e)
