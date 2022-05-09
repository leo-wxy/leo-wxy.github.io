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

### 相关模块

```
compiler`、 `compilerCommon`、`baseLibrary
```

### 核心类

#### ProcessDataBinding

根据一般插件开发流程，插件处理类配置在`META_INF`下

```java
public class ProcessDataBinding extends AbstractProcessor {
    @Override
    public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
        try {
            return doProcess(roundEnv);
        } finally {
            if (roundEnv.processingOver()) {
                Context.fullClear(processingEnv);
            }
        }
    }

    private boolean doProcess(RoundEnvironment roundEnv) {
        if (mProcessingSteps == null) {
            readArguments();
            initProcessingSteps(processingEnv);
        }
        if (mCompilerArgs == null) {
            return false;
        }
        ...
    }

    private void initProcessingSteps(ProcessingEnvironment processingEnv) {
        final ProcessBindable processBindable = new ProcessBindable();
        mProcessingSteps = Arrays.asList(
                new ProcessMethodAdapters(),
                new ProcessExpressions(),
                processBindable
        );
       ...
     }

}
```

将流程拆分成以下三部分分别进行处理

#### baselibrary/注解释义

以上标记的注解均来自于`baseLibrary`下，接下来对他们进行一些简单的介绍

##### *Bindable



##### *BindingAdapter

> **属性设置预处理，主要对View的属性进行赋值**
> 
> 可以对某些属性需要自定义处理逻辑时调用

```java
@Target(ElementType.METHOD)
public @interface BindingAdapter {

    String[] value();

    boolean requireAll() default true;
}

```

参数

- value 需要处理的属性

- requireAll 默认为true，需要处理`value`所有属性才可以正常编译；设置为false，处理部分属性即可

使用场景

- 对View已有属性进行自定义逻辑处理
  
  > 例如设置 @BindingAdapter("android:text") 

- 自定义属性进行逻辑处理
  
  > 如下示例所示

示例代码

```java
@BindingAdapter(value = {"imageUrl", "placeholder", "error"},requireAll = false)
public static oid loadImage(ImageView view, String url, Drawable placeholder, Drawable error) {    
    RequestOptions options = new RequestOptions();    
    options.placeholder(placeholder);    
    options.error(error);    
    Glide.with(view).load(url).apply(options).into(view);
}


//调用xml实现
 <ImageView    
   android:layout_width="100dp"    
   android:layout_height="100dp"    
   android:layout_marginTop="10dp"    
   app:imageUrl="@{`https://goss.veer.com/creative/vcg/veer/800water/veer-136599950.jpg`}"    
   app:placeholder="@{@drawable/icon}"/>

```

##### BindingMethods

> **当View中某个属性与该属性对应的set方法名称不对应时可以进行映射**
> 
> `BindingMethods`只是一个容器，需要配合`BindingMethod`进行使用

```java
@Target({ElementType.TYPE})
public @interface BindingMethods {
    BindingMethod[] value();
}


@Target(ElementType.ANNOTATION_TYPE)
public @interface BindingMethod {

    /**
     * @return the View Class that the attribute is associated with.
     */
    Class type();

    /**
     * @return The attribute to rename. Use android: namespace for all android attributes or
     * no namespace for application attributes.
     */
    String attribute();

    /**
     * @return The method to call to set the attribute value.
     */
    String method();
}

```

参数

- value `BindingMethod`
  
  - type 作用对象 例如`TextView`
  
  - attribute 对应xml设置方法 例如`android:inputType`
  
  - method 映射方法 例如`setRawInputType`

示例代码

```java
@BindingMethods({
        @BindingMethod(type = TextView.class, attribute = "android:autoLink", method = "setAutoLinkMask"),
        @BindingMethod(type = TextView.class, attribute = "android:drawablePadding", method = "setCompoundDrawablePadding"),
        @BindingMethod(type = TextView.class, attribute = "android:editorExtras", method = "setInputExtras"),
        @BindingMethod(type = TextView.class, attribute = "android:inputType", method = "setRawInputType"),
        @BindingMethod(type = TextView.class, attribute = "android:scrollHorizontally", method = "setHorizontallyScrolling"),
        @BindingMethod(type = TextView.class, attribute = "android:textAllCaps", method = "setAllCaps"),
        @BindingMethod(type = TextView.class, attribute = "android:textColorHighlight", method = "setHighlightColor"),
        @BindingMethod(type = TextView.class, attribute = "android:textColorHint", method = "setHintTextColor"),
        @BindingMethod(type = TextView.class, attribute = "android:textColorLink", method = "setLinkTextColor"),
        @BindingMethod(type = TextView.class, attribute = "android:onEditorAction", method = "setOnEditorActionListener"),
})
public class TextViewBindingAdapter {
...
}
```

##### BindingConversion

> **可以对数据、类型进行转换**

```java
@Target({ElementType.METHOD})
public @interface BindingConversion {
}
```

参数

无

示例代码

```kotlin
/**
* 支持传入色值，转换成Drawable对象
*/
@BindingConversion
fun colorToDrawable(color:String):ColorDrawable{
    val colorInt = Color.parseColor(color)
    return ColorDrawable(colorInt)
}


//调用Xml实现
        <ImageView
            android:layout_width="100dp"
            android:layout_height="50dp"
            android:background='@{"#00ff00"}'/>
```

##### InverseBindingAdapter

> 与`BindingAdapter`相反，`InverseBindingAdapter`是从View中获取对应属性的值

```java
@Target({ElementType.METHOD, ElementType.ANNOTATION_TYPE})
public @interface InverseBindingAdapter {

    /**
     * The attribute that the value is to be retrieved for.
     */
    String attribute();

    /**
     * The event used to trigger changes. This is used in {@link BindingAdapter}s for the
     * data binding system to set the event listener when two-way binding is used.
     */
    String event() default "";
}

```

需要配合`InverseBindingListener`进行使用，可以监听到属性的变化

参数

- attribute 监听的属性

- event 获取值的触发条件

示例代码

```java

```

##### InverseBindingMethods

> todo

```java
@Target(ElementType.TYPE)
public @interface InverseBindingMethods {
    InverseBindingMethod[] value();
}


@Target(ElementType.ANNOTATION_TYPE)
public @interface InverseBindingMethod {

    /**
     * The View type that is associated with the attribute.
     */
    Class type();

    /**
     * The attribute that supports two-way binding.
     */
    String attribute();

    /**
     * The event used to notify the data binding system that the attribute value has changed.
     * Defaults to attribute() + "AttrChanged"
     */
    String event() default "";

    /**
     * The getter method to retrieve the attribute value from the View. The default is
     * the bean method name based on the attribute name.
     */
    String method() default "";
}

```

##### InverseMethod

> todo

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME) // this is necessary for java analyzer to work
public @interface InverseMethod {
    /**
     * @return The name of the method on this class to use as the inverse.
     */
    String value();
}

```

[TODO](https://medium.com/androiddevelopers/android-data-binding-inverse-functions-95aab4b11873)

##### BindingBuildInfo

> DataBinding生成相关代码时，主要用来生成相关的dataBinding信息

```java
@Target({ElementType.TYPE})
public @interface BindingBuildInfo {
}
```

##### Untaggable

> DataBinding默认通过给View设置`tag`的方式进行标记，后续再根据设置的`tag`找到对应的View。
> 
> 该注解的用处为：针对设置的View不去设置`tag`，避免后续操作异常

```java
@Target({ElementType.TYPE})
public @interface Untaggable {
    String[] value();
}
```

参数

- value 不需要设置tag的View

示例代码

```java
@RestrictTo(RestrictTo.Scope.LIBRARY)
@Untaggable({"android.view.ViewStub"})
@BindingMethods({
        @BindingMethod(type = android.view.ViewStub.class, attribute = "android:layout", method = "setLayoutResource")
})
public class ViewStubBindingAdapter {
    @BindingAdapter("android:onInflate")
    public static void setOnInflateListener(ViewStubProxy viewStubProxy,
            OnInflateListener listener) {
        viewStubProxy.setOnInflateListener(listener);
    }
}
```

#### ProcessMethodAdapters

> 搜索工程下的所有类，找出包含以下注解的相关类
> 
> - `@BindingAdapter`
> 
> - `@BindingMethods`
> 
> - `@BindingConversion`
> 
> - `@Untaggable`
> 
> - `@InverseBindingAdapter`
> 
> - `@InverseBindingMethods`
> 
> - `@InverseMethod`
> 
> 找到以上注解类后，将其保存在`-setter_store.bin`文件中



```java
public class ProcessMethodAdapters extends ProcessDataBinding.ProcessingStep {
    private final static String INVERSE_BINDING_EVENT_ATTR_SUFFIX = "AttrChanged";

    @Override
    public boolean onHandleStep(RoundEnvironment roundEnv,
                                ProcessingEnvironment processingEnvironment,
                                CompilerArguments args) {
        L.d("processing adapters");
        final ModelAnalyzer modelAnalyzer = ModelAnalyzer.getInstance();
        Preconditions.checkNotNull(modelAnalyzer, "Model analyzer should be"
                + " initialized first");
        SetterStore store = SetterStore.get();
        clearIncrementalClasses(roundEnv, store);
//对应BindingAdapter
        addBindingAdapters(roundEnv, processingEnvironment, store);
//对应BindingMethods
        addRenamed(roundEnv, store);
//对应BindingConversion
        addConversions(roundEnv, store);
//对应Untaggable
        addUntaggable(roundEnv, store);
//对应InverseAdapter
        addInverseAdapters(roundEnv, processingEnvironment, store);
//对应InverseBindingMethods
        addInverseBindingMethods(roundEnv, store);
//对应InverseMethod
        addInverseMethods(roundEnv, processingEnvironment, store);

        try {
            try {
                store.write(args.getModulePackage());
            } catch (IOException e) {
                L.e(e, "Could not write BindingAdapter intermediate file.");
            }
        } catch (LoggedErrorException e) {
            // This will be logged later
        }
        return true;
    }

...
}
```

拿出相对常用的`BindingAdapter`进行分析

##### addBindingAdapters

```java
private void addBindingAdapters(RoundEnvironment roundEnv, ProcessingEnvironment
            processingEnv, SetterStore store) {
        LibTypes libTypes = ModelAnalyzer.getInstance().libTypes;
        Class<? extends Annotation> adapterAnnotation = libTypes.getBindingAdapterClass();
        for (Element element : AnnotationUtil
                .getElementsAnnotatedWith(roundEnv, adapterAnnotation)) {
            try {
                if (element.getKind() != ElementKind.METHOD ||
                        !element.getModifiers().contains(Modifier.PUBLIC)) {
                    L.e(element, "@BindingAdapter on invalid element: %s", element);
                    continue;
                }
                //解析BindingAdapter 注解内参数
                BindingAdapterCompat bindingAdapter = BindingAdapterCompat.create(element);

                ExecutableElement executableElement = (ExecutableElement) element;
                List<? extends VariableElement> parameters = executableElement.getParameters();
                if (bindingAdapter.getAttributes().length == 0) {
                    L.e(element, "@BindingAdapter requires at least one attribute. %s",
                            element);
                    continue;
                }

                final boolean takesComponent = takesComponent(executableElement, processingEnv);
                final int startIndex = 1 + (takesComponent ? 1 : 0);
                final int numAttributes = bindingAdapter.getAttributes().length; //注解value个数
                final int numAdditionalArgs = parameters.size() - startIndex;
                ...
                try {
                    if (numAttributes == 1) {
                        //单参数处理
                        final String attribute = bindingAdapter.getAttributes()[0];
                        store.addBindingAdapter(processingEnv, attribute, executableElement,
                                takesComponent);
                    } else {
                        //多参数处理
                        store.addBindingAdapter(processingEnv, bindingAdapter.getAttributes(),
                                executableElement, takesComponent, bindingAdapter.getRequireAll());
                    }
                } catch (IllegalArgumentException e) {
                    L.e(element, "@BindingAdapter for duplicate View and parameter type: %s",
                            element);
                }
            } catch (LoggedErrorException e) {
                // This will be logged later
            }
        }
    }
```

##### SetterStore.addBindingAdapter

```java

```

##### SetterStore.write

#### ProcessExpressions

#### ProcessBindable

### 处理流程

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
