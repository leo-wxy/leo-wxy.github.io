---
title: Android-DataBinding-GradlePlugin分析
typora-root-url: ../
date: 2022-05-10 21:13:03
tags: 源码解析
top: 9
---

> DataBinding 中 Gradle Plugin相关分析，主要实现了以下功能
>
> - 生成了 `xx.xml`以及`xx-layout.xml`
> - 生成了`xxBinding.java`和`xxBindingImpl.java`
> - 生成了`BR.java`和`DataBinderMapperImpl.java`
>
> 以上的文件为后面的Library分析提供了基础保障

## 相关模块

```
compiler`、 `compilerCommon`、`baseLibrary
```

## 资源合并流程

通过Debug GradlePlugin 起点为 `MergeResource`

相关源码：`build-system/gradle-core/src/main/java/com/android/build/gradle/tasks/MergeResources.kt`



## 核心类

### baselibrary/注解释义

以上标记的注解均来自于`baseLibrary`下，接下来对他们进行一些简单的介绍

#### *Bindable



#### *BindingAdapter

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

#### BindingMethods

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

#### BindingConversion

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

#### InverseBindingAdapter

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

#### InverseBindingMethods

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

#### InverseMethod

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

#### BindingBuildInfo

> DataBinding生成相关代码时，主要用来生成相关的dataBinding信息

```java
@Target({ElementType.TYPE})
public @interface BindingBuildInfo {
}
```

#### Untaggable

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



### ProcessDataBinding

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

```mermaid
flowchart LR
A[ProcessDataBinding] --> B[ProcessMethodAdapters]
A[ProcessDataBinding] --> C[ProcessExpressions]
A[ProcessDataBinding] --> D[ProcessBindable]
B --> E[收集特定注解的类,解析后数据存放在BindingAdapterStore中\n生成 -setter_store.json文件]
C --> F[解析layout下xml文件,得到LayoutFileBundle对象\n期间生成了xx.xml xx-layout.xml \n生成了xxBinding.java xxBindingImpl.java]
D --> G[生成BR文件]
```



### ProcessMethodAdapters

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
> 找到以上注解类后，将解析后的信息放在`BindingAdapterStore`中，最后通过Json格式将其保存在`-setter_store.json`文件中



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

#### addBindingAdapters

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

#### SetterStore.addBindingAdapter

##### 单入参处理

```java 
    public void addBindingAdapter(ProcessingEnvironment processingEnv, String attribute,
            ExecutableElement bindingMethod, boolean takesComponent) {
        attribute = stripNamespace(attribute);

        List<? extends VariableElement> parameters = bindingMethod.getParameters();
        final int viewIndex = takesComponent ? 1 : 0;
        TypeMirror viewType = eraseType(processingEnv, parameters.get(viewIndex).asType());
        String view = getQualifiedName(viewType);
        TypeMirror parameterType = eraseType(processingEnv, parameters.get(viewIndex + 1).asType());
        String value = getQualifiedName(parameterType);

        AccessorKey key = new AccessorKey(view, value);
        MethodDescription desc = new MethodDescription(bindingMethod, 1, takesComponent);

        mStore.addBindingAdapter(attribute, key, desc);
    }
```

相关的两个类为`AccessorKey`、`MethodDescription`，决定在`-setter_store.json`保存的数据格式

```java
//SetterStore.java 
    static class AccessorKey implements Serializable, Comparable<AccessorKey> {
        //作用的View类型
        public final String viewType;
        //设置的参数类型
        public final String valueType;

        public AccessorKey(String viewType, String valueType) {
            this.viewType = viewType;
            this.valueType = valueType;
        }
      ...
    }

    static class MethodDescription implements Serializable, Comparable<MethodDescription> {
        //注解方法所在类
        public final String type;
        //注解方法名
        public final String method;
        
        public final boolean requiresOldValue;

        public final boolean isStatic;

        public final String componentClass;

        public MethodDescription(String type, String method) {
            this.type = type;
            this.method = method;
            this.requiresOldValue = false;
            this.isStatic = true;
            this.componentClass = null;
        }
      ...
    }
```



对应生成的json格式

```json
  "adapterMethods": {
    "setShape": [
      [
        {
          "viewType": "android.view.View",
          "valueType": "com.example.behaviordemo.bindingadapter.ShapeBuilder"
        },
        {
          "type": "com.example.behaviordemo.bindingadapter.ViewExpressionKt",
          "method": "setShape",
          "requiresOldValue": false,
          "isStatic": true,
          "componentClass": null
        }
      ]
    ]
  }
```



##### 多入参处理

```java
    public void addBindingAdapter(ProcessingEnvironment processingEnv, String[] attributes,
            ExecutableElement bindingMethod, boolean takesComponent, boolean requireAll) {
        L.d("STORE add multi-value BindingAdapter %d %s", attributes.length, bindingMethod);
        MultiValueAdapterKey key = new MultiValueAdapterKey(processingEnv, bindingMethod,
                attributes, takesComponent, requireAll);
        testRepeatedAttributes(key, bindingMethod);
        MethodDescription methodDescription = new MethodDescription(bindingMethod,
                attributes.length, takesComponent);
        mStore.addMultiValueAdapter(key, methodDescription);
    }
```

相关的两个类为`MethodDescription`、`MultiValueAdapterKey`

```java
//SetterStore.java
//MethodDescription 与上节一致

    static class MultiValueAdapterKey implements Serializable,
            Comparable<MultiValueAdapterKey> {
        private static final long serialVersionUID = 1;

        public final String viewType;

        public final String[] attributes;

        public final String[] parameterTypes;

        public final boolean requireAll;

        public final TreeMap<String, Integer> attributeIndices = new TreeMap<>();
    }
```



对应生成的json格式

```json
  "multiValueAdapters": [
    [
      {
        "viewType": "android.widget.TextView",
        "attributes": [
          "android:beforeTextChanged",
          "android:onTextChanged",
          "android:afterTextChanged",
          "android:textAttrChanged"
        ],
        "parameterTypes": [
          "androidx.databinding.adapters.TextViewBindingAdapter.BeforeTextChanged",
          "androidx.databinding.adapters.TextViewBindingAdapter.OnTextChanged",
          "androidx.databinding.adapters.TextViewBindingAdapter.AfterTextChanged",
          "androidx.databinding.InverseBindingListener"
        ],
        "requireAll": false,
        "attributeIndices": {
          "android:afterTextChanged": 2,
          "android:beforeTextChanged": 0,
          "android:onTextChanged": 1,
          "android:textAttrChanged": 3
        }
      },
      {
        "type": "com.example.behaviordemo.bindingadapter.ViewExpressionKt",
        "method": "setTextChange",
        "requiresOldValue": false,
        "isStatic": true,
        "componentClass": null
      }
    ]
  ]
```

生产对应的类后，需要将他们写入json文件进行存储

#### SetterStore.write

```java
//SetterStore.java
    public void write(String projectPackage)
            throws IOException {
        Preconditions.checkNotNull(mStore.getCurrentModuleStore(),
                "current module store should not be null");
        GenerationalClassUtil.get().write(
                projectPackage,
                GenerationalClassUtil.ExtensionFilter.SETTER_STORE_JSON,
                mStore.getCurrentModuleStore());
    }
```

调用`GenerationalClassUtil`的write()写入文件

```java
    fun write(pkg:String, ext : ExtensionFilter, item: Any) {
        L.d("writing output file for %s, %s into %s", pkg, ext, outputDir)
        try {
            Preconditions.checkNotNull(outputDir,
                    "incremental out directory should be" + " set to aar output directory.")
            outputDir!!.mkdirs()
            val outFile = File(outputDir, "$pkg${ext.ext}")
            if (ext.isJson) {
                outFile.bufferedWriter(Charsets.UTF_8).use {
                    GSON.toJson(item, it)
                }
            } else {
                outFile.outputStream().use {
                    ObjectOutputStream(it).use {
                        it.writeObject(item)
                    }
                }
            }
            L.d("done writing output file %s into %s", pkg, outFile.canonicalPath)
        } catch (t : Throwable) {
            L.e(t, "cannot write file $pkg $ext")
        }
    }
```

参数主要有三个

- pkg 插件所在module/project包名

- ext ExtensionFilter 枚举记录的是DataBinding处理后的存储文件名

  ```java
      enum class ExtensionFilter(val ext : String, val isJson : Boolean) {
          SETTER_STORE_JSON("-setter_store.json", true),
          BR("-br.bin", false),
          LAYOUT("-layoutinfo.bin", false),
          SETTER_STORE("-setter_store.bin", false);
      }
  ```

  

- item 需要转换成json的对象

  在当前场景下记录的对象为 `BindingAdapterStore`

  ```java
  internal class BindingAdapterStore : Intermediate {
      @Suppress("unused")
      @field:SerializedName("version")
      private var version = 5
      // Intermediate V1
      @field:SerializedName("adapterMethods")
      private val adapterMethods = TreeMap<String, TreeMap<SetterStore.AccessorKey, MethodDescription>>()
      @field:SerializedName("renamedMethods")
      private val renamedMethods = TreeMap<String, TreeMap<String, MethodDescription>>()
      @field:SerializedName("conversionMethods")
      private val conversionMethods = TreeMap<String, TreeMap<String, MethodDescription>>()
      @field:SerializedName("untaggableTypes")
      private val untaggableTypes = TreeMap<String, String>()
      @field:SerializedName("multiValueAdapters")
      private val multiValueAdapters = TreeMap<MultiValueAdapterKey, MethodDescription>()
      // Intermediate V2
      @field:SerializedName("inverseAdapters")
      private val inverseAdapters = TreeMap<String, TreeMap<AccessorKey, InverseDescription>>()
      @field:SerializedName("inverseMethods")
      private val inverseMethods = TreeMap<String, TreeMap<String, InverseDescription>>()
      // Intermediate V3
      @field:SerializedName("twoWayMethods")
      private val twoWayMethods = TreeMap<InverseMethodDescription, String>()
  ```

最终生成的`-setter_sotre.json`格式如下，存储路径为`./build/intermediates/data_binding_artifact/debug/kaptDebugKotlin/XX-setter_store.json`

```json
{
  "version": 5,
  "adapterMethods": {},
  "renamedMethods": {},
  "conversionMethods": {},
  "untaggableTypes": {},
  "multiValueAdapters": {},
  "inverseAdapters": {},
  "inverseMethods": {},
  "twoWayMethods": {},
  "useAndroidX": true
}
```

```mermaid
flowchart TD
    A[ProcessMethodAdapters.onHandlerStep] --> B[addBindingAdapters]
    B --> C[bindingAdapter.getAttributes 获取入参个数]
    C --> D[入参个数>1]
    D --> | 个数为1| E[SetterStore.addBindingAdapter String attribute]
    D --> | 个数大于1| F[SetterStore.addBindingAdapter String数组 attribute]
    E --> G[得到AccessorKey & MethodDescription]
    G --> H[单入参Json格式]
    F --> I[得到MultiValueAdapterKey & MethodDescription]
    I --> J[多入参Json格式]
    H --> K[SetterStore.write]
    J --> K
    K --> L[GenerationClassUtil.write]
    L --> M[写入路径为 -setter_store.json 写入内容为 BingingAdapterStore Json格式]
```



### ProcessExpressions

> 检索所有`layout`目录下的xml文件，把这个xml文件拆分为两个文件 //找到xml中最外层为`<layout></layout>`的xml文件?
>
> - XX.xml 正常的布局文件 路径`./build/intermediates/incremental/debug/mergeDebugResources/stripped.dir/layout/fragment_test_db.xml`
> - XX-layout.xml 包含了绑定信息的xml文件 `./build/intermediates/data_binding_layout_info_type_merge/debug/out/fragment_test_db-layout.xml`
>
> 生成上述两个文件后，继续生成以下文件
>
> - XXBinding.java 抽象类 路径`./build/generated/data_binding_base_class_source_out/debug/out/com/example/behaviordemo/databinding/FragmentTestDbBinding.java`
> - XXBindingImpl.java 继承自 XXBinding `./build/generated/source/kapt/debug/com/example/behaviordemo/databinding/FragmentTestDbBindingImpl.java`

```java
public class ProcessExpressions extends ProcessDataBinding.ProcessingStep {
  ...
        @Override
    public boolean onHandleStep(RoundEnvironment roundEnvironment,
            ProcessingEnvironment processingEnvironment, CompilerArguments args)
            throws JAXBException {
        try {
            ResourceBundle resourceBundle;
            resourceBundle = new ResourceBundle(
                    args.getModulePackage(),
                    ModelAnalyzer.getInstance().libTypes.getUseAndroidX());
            L.d("creating resource bundle for %s", args.getModulePackage());
            final List<IntermediateV2> intermediateList;
            GenClassInfoLog infoLog = null;
            @Nullable
            CompilerChef v1CompatChef = null;
           ...
            IntermediateV2 mine = createIntermediateFromLayouts(args.getLayoutInfoDir(),
                    intermediateList);
            if (mine != null) {
                if (!args.isEnableV2()) {
                    mine.updateOverridden(resourceBundle);
                    intermediateList.add(mine);
                    saveIntermediate(args, mine);
                }
                mine.appendTo(resourceBundle, true);
            }
            // generate them here so that bindable parser can read
            try {
                writeResourceBundle(resourceBundle, args, infoLog, v1CompatChef);
            } catch (Throwable t) {
                L.e(t, "cannot generate view binders");
            }
        } catch (LoggedErrorException e) {
            // This will be logged later
        }
        return true;
    }
}
```

#### 收集Xml中expression信息

> 主要为了得到`LayoutFileBundle`对象，用于后续生成相关文件



##### LayoutXmlProcessor.processResources

```java
//LayoutXmlProcessor.java
//todo 待确定如何调用到 processResources 方法 通过Debug Gradle Task方式测试
    private static final FilenameFilter LAYOUT_FOLDER_FILTER = (dir, name)
            -> name.startsWith("layout");

    private static final FilenameFilter XML_FILE_FILTER = (dir, name)
            -> name.toLowerCase().endsWith(".xml");

    public boolean processResources(
            ResourceInput input, boolean isViewBindingEnabled, boolean isDataBindingEnabled)
            throws ParserConfigurationException, SAXException, XPathExpressionException,
            IOException {
               final URI inputRootUri = input.getRootInputFolder().toURI();
            ProcessFileCallback callback = new ProcessFileCallback() {
              
            private File convertToOutFile(File file) {
                final String subPath = toSystemDependentPath(inputRootUri
                        .relativize(file.toURI()).getPath());
                return new File(input.getRootOutputFolder(), subPath);
            }

            @Override
            public void processLayoutFile(File file)
                    throws ParserConfigurationException, SAXException, XPathExpressionException,
                    IOException {
                      //处理单个layout文件
                processSingleFile(RelativizableFile.fromAbsoluteFile(file, null),
                        convertToOutFile(file), isViewBindingEnabled, isDataBindingEnabled);
            }
              
            @Override
            public void processLayoutFolder(File folder) {
                //创建文件输出目录
                convertToOutFile(folder).mkdirs();
            }
              ...
        if (input.isIncremental()) {
          //增量文件处理
            processIncrementalInputFiles(input, callback);
        } else {
          //全量文件处理
            processAllInputFiles(input, callback);
        }
              ...
    //处理所有 文件              
    private static void processAllInputFiles(ResourceInput input, ProcessFileCallback callback)
            throws IOException, XPathExpressionException, SAXException,
            ParserConfigurationException {
        FileUtils.deleteDirectory(input.getRootOutputFolder());
        //noinspection ConstantConditions
        for (File firstLevel : input.getRootInputFolder().listFiles()) {
            if (firstLevel.isDirectory()) {
              //找到 layout文件夹
                if (LAYOUT_FOLDER_FILTER.accept(firstLevel, firstLevel.getName())) {
                    //创建生成文件输出目录
                    callback.processLayoutFolder(firstLevel);
                  //找到xml结尾文件
                    for (File xmlFile : firstLevel.listFiles(XML_FILE_FILTER)) {
                        //处理 layout xml文件
                        callback.processLayoutFile(xmlFile);
                    }
                } else {
                  ...
                }
            } else {
                callback.processOtherRootFile(firstLevel);
            }

        }
    }
}
              
```

> 主要流程如下：
>
> 1. 找到layout文件夹
> 2. 创建文件输出目录
> 3. 寻找 layout目录下以xml结尾的文件
> 4. 处理xml文件，继续调用到`processSingleFile`

##### LayoutFileParser.parseXml

```java
    public static ResourceBundle.LayoutFileBundle parseXml(@NonNull final RelativizableFile input,
            @NonNull final File outputFile, @NonNull final String pkg,
            @NonNull final LayoutXmlProcessor.OriginalFileLookup originalFileLookup,
            boolean isViewBindingEnabled, boolean isDataBindingEnabled)
            throws ParserConfigurationException, IOException, SAXException,
            XPathExpressionException {
              ...
              //生成正常的xx.xml文件
              stripFile(inputFile, outputFile, encoding, originalFileLookup);
              //解析原始的xml文件
              return parseOriginalXml(
                RelativizableFile.fromAbsoluteFile(originalFile, input.getBaseDir()),
                pkg, encoding, isViewBindingEnabled, isDataBindingEnabled);
            }

//根据传入的文件进行处理
    private static void stripFile(File xml, File out, String encoding,
            LayoutXmlProcessor.OriginalFileLookup originalFileLookup)
            throws ParserConfigurationException, IOException, SAXException,
            XPathExpressionException {
              ...
        // now if file has any binding expressions, find and delete them
        boolean changed = isBindingLayout(doc, xPath);
        if (changed) {
            stripBindingTags(xml, out, binderId, encoding);
        } else if (!xml.equals(out)){
            FileUtils.copyFile(xml, out);
        } 
    }

    private static void stripBindingTags(File xml, File output, String newTag, String encoding)
            throws IOException {
      //分离xml里的 layout data 标签，然后再给view设置 android:tag 
        String res = XmlEditor.strip(xml, newTag, encoding);
        Preconditions.checkNotNull(res, "layout file should've changed %s", xml.getAbsolutePath());
        if (res != null) {
            L.d("file %s has changed, overwriting %s",
                    xml.getAbsolutePath(), output.getAbsolutePath());
          //处理后的文件 写入指定目录
            FileUtils.writeStringToFile(output, res, encoding);
        }
    }

//对原始的xml文件进行解析
    private static ResourceBundle.LayoutFileBundle parseOriginalXml(
            @NonNull final RelativizableFile originalFile, @NonNull final String pkg,
            @NonNull final String encoding, boolean isViewBindingEnabled,
            boolean isDataBindingEnabled)
            throws IOException {
      ...
           //创建LayoutFileBundle对象
           ResourceBundle.LayoutFileBundle bundle =
                new ResourceBundle.LayoutFileBundle(
                    originalFile, xmlNoExtension, original.getParentFile().getName(), pkg,
                    isMerge, isBindingData, rootViewType, rootViewId);

            final String newTag = original.getParentFile().getName() + '/' + xmlNoExtension;
           //解析 <data></data> 标签格式
            parseData(original, data, bundle);
           //解析 xml中的 @{} 表达式
            parseExpressions(newTag, rootView, isMerge, bundle);

    }
```

> 主要流程如下：
>
> 调用到`parseXml`执行如下两步
>
> - stripFile 
>   - stripBindingTags
>   - XmlEditor.strip 去除xml中 <layout> <data>标签，并且给View设置tag
>   - writeStringToFile 将执行以上操作后的xml文件 写入`build/intermediates/incremental/debug/mergeDebugResources/stripped.dir/layout`
>
> - parseOriginXml
>   - new LayoutFileBundle对象
>   - parseData 解析<data>标签 ，主要是内部的 <import> <variable> <class>属性
>   - parseExpressions 解析表达式 ，主要是循环遍历View，主要处理 id、tag binding_id 以及 @{} 这类表达式
> - 得到`LayoutFileBundle`对象，里面主要记录了 xml文件中的 Variables Imports 等核心信息
>   - 详细信息可查看 `compilerCommon/src/main/java/android/databinding/tool/store/ResourceBundle.java`



#### 生成Layout xml文件

> 根据得到的`LayoutFileBundle`对象生成`xx-layout.xml`文件

##### MergeResources.xx.end

```kotlin
            @Throws(JAXBException::class)
            override fun end() {
                processor
                    .writeLayoutInfoFiles(
                        dataBindingLayoutInfoOutFolder.get().asFile
                    )
            }
//dataBindingLayoutInfoOutFolder 即为生成的 xx-layout.xml 存储目录

            artifacts.setInitialProvider(taskProvider) { obj: MergeResources -> obj.dataBindingLayoutInfoOutFolder }
                .withName("out")
                .on(
                    if (mergeType === TaskManager.MergeType.MERGE) DATA_BINDING_LAYOUT_INFO_TYPE_MERGE else DATA_BINDING_LAYOUT_INFO_TYPE_PACKAGE
                )
//指向了 data_binding_layout_info_type_merge 或 data_binding_layout_info_type_package目录

```

`MergeResources`执行到`end`后调用`writeLayoutInfoFiles`



##### LayoutXmlProcesser.writeLayoutInfoFiles

```java
    public void writeLayoutInfoFiles(File xmlOutDir) throws JAXBException {
        writeLayoutInfoFiles(xmlOutDir, mFileWriter);
    }

    public void writeLayoutInfoFiles(File xmlOutDir, JavaFileWriter writer) throws JAXBException {
        // For each layout file, generate a corresponding layout info file
        for (ResourceBundle.LayoutFileBundle layout : mResourceBundle
                .getAllLayoutFileBundlesInSource()) {
            writeXmlFile(writer, xmlOutDir, layout);
        }
      ...
    }

    private void writeXmlFile(JavaFileWriter writer, File xmlOutDir,
            ResourceBundle.LayoutFileBundle layout)
            throws JAXBException {
        String filename = generateExportFileName(layout);
        writer.writeToFile(new File(xmlOutDir, filename), layout.toXML());
    }

    public static String generateExportFileName(String fileName, String dirName) {
      //生成名为 xx-layout.xml
        return fileName + '-' + dirName + ".xml";
    }
```

> 主要流程如下：
>
> 1. 遍历LayoutFileBundle对象，并写入文件
> 2. generateExportFileName 设置生成的文件名 xx-layout.xml
> 3. 得到的LayoutFileBundle对象 toXML，后写入 xx-layout.xml文件中

生成的 xx-layout.xml文件内容

```xml
//build/intermediates/data_binding_layout_info_type_merge/debug/out/fragment_test_db-layout.xml
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<Layout directory="layout" filePath="app/src/main/res/layout/fragment_test_db.xml" isBindingData="true" isMerge="false" layout="fragment_test_db"
    modulePackage="com.example.behaviordemo" rootNodeType="androidx.constraintlayout.widget.ConstraintLayout">
    //参数
    <Variables name="text" declared="true" type="String">
        <location endLine="14" endOffset="27" startLine="12" startOffset="8" />
    </Variables>
    ...
    //引用
    <Imports name="ShapeBuilder" type="com.example.behaviordemo.bindingadapter.ShapeBuilder">
        <location endLine="8" endOffset="77" startLine="8" startOffset="8" />
    </Imports>
    ...
    //作用对象
     <Targets>
        <Target tag="layout/fragment_test_db_0" view="androidx.constraintlayout.widget.ConstraintLayout">
            <Expressions />
            <location endLine="57" endOffset="55" startLine="22" startOffset="4" />
        </Target>
         <Target id="@+id/tv_txt" tag="binding_1" view="TextView">
            <Expressions>
              //xml里写的表达式信息
                <Expression attribute="android:text" text="text, default = 23456">
                    <Location endLine="30" endOffset="50" startLine="30" startOffset="12" />
                    <TwoWay>false</TwoWay>
                    <ValueLocation endLine="30" endOffset="48" startLine="30" startOffset="28" />
                </Expression>
            </Expressions>
            <location endLine="32" endOffset="55" startLine="26" startOffset="8" />
        </Target>
     </Targets> 
    
</Layout>
```



#### 生成Binding文件

> 得到`LayoutFileBundle`之后，继续生成xxBinding.java文件

##### ProcessExpressions.writeResourceBundle

```java
private void writeResourceBundle(
            ResourceBundle resourceBundle,
            CompilerArguments compilerArgs,
            @Nullable GenClassInfoLog classInfoLog,
            @NonNull CompilerChef v1CompatChef) {
  //生成DataBindingComponent对象
        if (compilerArgs.isLibrary()
                || (!compilerArgs.isTestVariant() && !compilerArgs.isFeature())) {
            compilerChef.writeComponent();
        }
  //生成 xml文件
        if (compilerChef.hasAnythingToGenerate()) {
          //不是V2版本 xxBinding.java 由代码生成 XXBindingImpl.java 不生成
            if (!compilerArgs.isEnableV2()) {
                compilerChef.writeViewBinderInterfaces(compilerArgs.isLibrary()
                        && !compilerArgs.isTestVariant());
            }
          //V2版本 xxBinding.java由插件生成 xxBindingImpl.java 由代码生成
            if (compilerArgs.isApp() != compilerArgs.isTestVariant()
                    || (compilerArgs.isEnabledForTests() && !compilerArgs.isLibrary())
                    || compilerArgs.isEnableV2()) {
                compilerChef.writeViewBinders(compilerArgs.getMinApi());
            }
        }
}
```

##### CompilerChef -> DataBinder -> LayoutBinder

```java
//CompilerChef.java 
public void writeViewBinderInterfaces(boolean isLibrary) {
        ensureDataBinder();
        mDataBinder.writerBaseClasses(isLibrary);
    }

    public void writeViewBinders(int minSdk) {
        ensureDataBinder();
        mDataBinder.writeBinders(minSdk);
    }
//构造Databinder对象
    public void ensureDataBinder() {
        if (mDataBinder == null) {
            LibTypes libTypes = ModelAnalyzer.getInstance().libTypes;
            mDataBinder = new DataBinder(mResourceBundle, mEnableV2, libTypes);
            mDataBinder.setFileWriter(mFileWriter);
        }
    }

//DataBinder.java
    public DataBinder(ResourceBundle resourceBundle, boolean enableV2, LibTypes libTypes) {
      ...
        for(ResourceBundle.LayoutFileBundle bundle :
                    resourceBundle.getLayoutFileBundlesInSource()) {
                try {
                    mLayoutBinders.add(new LayoutBinder(bundle, true));
                } catch (ScopedException ex) {
                    Scope.defer(ex);
                }
            }
    }

```

以上几步串联了`CompilerChef` 与 `LayoutBinder`的关系

```java
//LayoutBinder.java
public class LayoutBinder implements FileScopeProvider {
  public LayoutBinder(ResourceBundle.LayoutFileBundle layoutBundle, boolean enableV2) {
   ...
            for (ResourceBundle.VariableDeclaration variable : mBundle.getVariables()) {
                addVariable(variable.name, variable.type, variable.location, variable.declared);
                names.add(variable.name);
            }

            for (ResourceBundle.NameTypeLocation userImport : mBundle.getImports()) {
                mExprModel.addImport(userImport.name, userImport.type, userImport.location);
                names.add(userImport.name);
            }
    ...
  }
}
```



##### LayoutBinderWriter.writeBaseClass - V1 版本生成xxBinding.java文件

```kotlin
public fun writeBaseClass(forLibrary: Boolean, variations: List<LayoutBinder>) : String = 
  ...

//按照规则生成文件
```



BaseLayoutBinderWriter.write - V2 版本生成XXBinding.java文件

> //build-system/gradle-core/src/main/java/com/android/build/gradle/internal/tasks/databinding/DataBindingGenBaseClassesTask.kt

```kotlin
@CacheableTask
abstract class DataBindingGenBaseClassesTask : AndroidVariantTask() {
      @TaskAction
    fun writeBaseClasses(inputChanges: InputChanges) {

        recordTaskAction(analyticsService.get()) {
            val args = buildInputArgs(inputChanges)
            CodeGenerator(
                args,
                sourceOutFolder.get().asFile,
                Logger.getLogger(DataBindingGenBaseClassesTask::class.java),
                encodeErrors,
                collectResources()).run()
        }
    }
  
      class CodeGenerator @Inject constructor(
        val args: LayoutInfoInput.Args,
        private val sourceOutFolder: File,
        private val logger: Logger,
        private val encodeErrors: Boolean,
        private val symbolTables: List<SymbolTable>? = null
    ) : Runnable, Serializable {
         override fun run() {
            try {
                initLogger()
                BaseDataBinder(
                        LayoutInfoInput(args),
                        if (symbolTables != null) this::getRPackage else null)
                    .generateAll(DataBindingBuilder.GradleFileWriter(sourceOutFolder.absolutePath))
            } finally {
                clearLogger()
            }
        }
        
      }

}
```

```kotlin
//BaseDataBinder.java
    fun generateAll(writer : JavaFileWriter) {
           if (variations.first().isBindingData) {
                check(input.args.enableDataBinding) {
                    "Data binding is not enabled but found data binding layouts: $variations"
                }

                val binderWriter = BaseLayoutBinderWriter(layoutModel, libTypes)
                javaFile = binderWriter.write()
                classInfo = binderWriter.generateClassInfo()
            } else {
                check(input.args.enableViewBinding) {
                    "View binding is not enabled but found non-data binding layouts: $variations"
                }

                val viewBinder = layoutModel.toViewBinder()
                javaFile = viewBinder.toJavaFile(useLegacyAnnotations = !useAndroidX)
                classInfo = viewBinder.generatedClassInfo()
            }
    }

```



##### LayoutBinderWriter.write - 生成xxBindingImpl.java文件

```java
//LayoutBinderWriter.kt
fun write(minSdk: kotlin.Int): String {
  ..
}
//按照规则生成文件
```

//todo 流程图



### ProcessBindable

> 主要是生成`BR`和`DataBinderMapperImpl`
>
> 位置分别在：
>
> - `BR.java`   `./build/generated/source/kapt/debug/${module.package}/BR.java`
>
> - `DataBinderMapperImpl`
>
>   - 包括其他module的 DataBinderMapperImpl 映射文件只在`app`中 ：
>
>     `BehaviorDemo/app/build/generated/source/kapt/debug/androidx/databinding/DataBinderMapperImpl.java`
>
>   - 包括module中 XXBindingImpl 映射文件 `./build/generated/source/kapt/debug/${module.package}/DataBinderMapperImpl.java`

#### 生成BR文件

> 主要包含根据`<variable>`和`@Bindable`注解的字段生成的id

```java
//ProcessBinder.java
public class ProcessBindable extends ProcessDataBinding.ProcessingStep implements BindableHolder {
    @Override
    public boolean onHandleStep(RoundEnvironment roundEnv, ProcessingEnvironment processingEnv,
            CompilerArguments args) {
          if (mProperties == null) {
            mProperties = new IntermediateV1(args.getModulePackage());
            mergeLayoutVariables();
            ...
            for (Element element : AnnotationUtil
                    .getElementsAnnotatedWith(roundEnv, libTypes.getBindableClass())) {
              //解析 @Bindable注解对象
              Element parentElement = element.getEnclosingElement();
              ...
                
            }
          }
            GenerationalClassUtil.get().write(mProperties.getPackage(),
                    GenerationalClassUtil.ExtensionFilter.BR, mProperties);
           //生成BR.java
            generateBRClasses(processingEnv, args, mProperties.getPackage());
    }
  
  //解析layout中的 <variable>标签
    private void mergeLayoutVariables() {
        for (String containingClass : mLayoutVariables.keySet()) {
            for (String variable : mLayoutVariables.get(containingClass)) {
                mProperties.addProperty(containingClass, variable);
            }
        }
    }
  
    private void generateBRClasses(
            ProcessingEnvironment processingEnv,
            CompilerArguments compilerArgs,
            String pkg) {
        try {
            CompilerArguments.Type artifactType = compilerArgs.getArtifactType();

            HashSet<String> properties = new HashSet<>();
            mProperties.captureProperties(properties);
            BindableBag bindableBag = new BindableBag(
                    compilerArgs,
                    getProperties(mProperties),
                    processingEnv);
            final JavaFileWriter writer = getWriter();
            boolean useFinal = compilerArgs.isApp()
                    || compilerArgs.isFeature()
                    || compilerArgs.isTestVariant();
            BRWriter brWriter = new BRWriter(useFinal);
            bindableBag.getToBeGenerated().forEach(brWithValues -> {
                String out = brWriter.write(brWithValues);
              //写入BR.java文件
                writer.writeToFile(brWithValues.getPkg() + ".BR", out);
            });
          //兜回到 ProcessDataBinding
            mCallback.onBrWriterReady(
                    bindableBag.getVariableIdLookup(),
                    bindableBag.getWrittenPackages());
        } catch (LoggedErrorException e) {
            // This will be logged later
        }
    }
}

```

`BR.java`文件内容如下

```java
public class BR {
  public static final int _all = 0;

  public static final int map = 1;

  public static final int text = 2;
}
```



#### 生成DataBinderMapperImpl文件

> 主要存储`tag`对应的`xml文件`，`BR文件`中`id`到`属性名`的映射

```java
//ProcessBindable.java

    private void generateBRClasses(
            ProcessingEnvironment processingEnv,
            CompilerArguments compilerArgs,
            String pkg) {
      //生成BR.java文件
      ...
        mCallback.onBrWriterReady(
                    bindableBag.getVariableIdLookup(),
                    bindableBag.getWrittenPackages());
    }
```

`mCallback`位于`ProcessingStep`中，在`ProcessDataBinding.initProcessingSteps `中赋值

```java
//ProcessDataBinding.java
    private void initProcessingSteps(ProcessingEnvironment processingEnv) {
        final ProcessBindable processBindable = new ProcessBindable();
      //需要处理的流程
        mProcessingSteps = Arrays.asList(
                new ProcessMethodAdapters(),
                new ProcessExpressions(),
                processBindable
        );
        Callback dataBinderWriterCallback = new Callback() {
            CompilerChef mChef;
            List<String> mModulePackages;
            BindableBag.BRMapping mBRVariableLookup;
            boolean mWrittenMapper = false;

          //在 ProcessExpressions中回调
            @Override
            public void onChefReady(
                    @NonNull CompilerChef chef,
                    @Nullable GenClassInfoLog classInfoLog) {
                Preconditions.checkNull(mChef, "Cannot set compiler chef twice");
                chef.addBRVariables(processBindable);
                mChef = chef;
                considerWritingMapper();
            }

            private void considerWritingMapper() {
                if (mWrittenMapper || mChef == null || mBRVariableLookup == null) {
                    return;
                }
                boolean justLibrary = mCompilerArgs.isLibrary()
                        && !mCompilerArgs.isTestVariant();
                if (justLibrary && !mCompilerArgs.isEnableV2()) {
                    return;
                }
                mWrittenMapper = true;
                mChef.writeDataBinderMapper(processingEnv, mCompilerArgs, mBRVariableLookup,
                        mModulePackages);
            }

          //在 ProcessBindable中回调
            @Override
            public void onBrWriterReady(BindableBag.BRMapping brWithValues, List<String> brPackages) {
                Preconditions.checkNull(mBRVariableLookup, "Cannot set br writer twice");
                mBRVariableLookup = brWithValues;
                mModulePackages = brPackages;
                considerWritingMapper();
            }
        };
        AnnotationJavaFileWriter javaFileWriter = new AnnotationJavaFileWriter(processingEnv);
        for (ProcessingStep step : mProcessingSteps) {
            step.mJavaFileWriter = javaFileWriter;
            step.mCallback = dataBinderWriterCallback;
        }
    }
```

##### CompilerChef.writeDataBinderMapper

```java
    public void writeDataBinderMapper(
            ProcessingEnvironment processingEnv,
            CompilerArguments compilerArgs,
            BindableBag.BRMapping brValueLookup,
            List<String> modulePackages) {
      if (compilerArgs.isEnableV2()) {
       ...
           if (generateMapper) {
              //为每个moule 包括 app生成 DataBinderMapperImpl
                writeMapperForModule(compilerArgs, brValueLookup, availableDependencyModules);
           }
         ...
           if (generateMergedMapper) {
          ...  //只为app生成 DataBinderMapperImpl
                writeMergedMapper(compilerArgs);
            }
      }
      
    }
```

###### writeMapperForModule

> 为`module&app`生成`DataBinderMapperImpl.java`，其中包含`tag`和`layout`的映射关系，可以根据tag找到`XXBindingImpl`实现类

```java
//CompilerChef.java
    private void writeMapperForModule(
            CompilerArguments compilerArgs,
            BindableBag.BRMapping brValueLookup,
            Set<String> availableDependencyModules) {
      ...
            BindingMapperWriterV2 v2 = new BindingMapperWriterV2(
                infoLogInThisModule,
                compilerArgs,
                libTypes,
                availableDependencyModules);
      ...
        try {
            JavaFile.builder(v2.getPkg(), spec).build().writeTo(sb);
            mFileWriter.writeToFile(v2.getQualifiedName(), sb.toString());
        } catch (IOException e) {
            Scope.defer(new ScopedException("cannot generate mapper class", e));
        }
    }
```

生成的`DataBinderMapperImpl`格式如下

```java
public class DataBinderMapperImpl extends DataBinderMapper {
  private static final int LAYOUT_FRAGMENTTESTDB = 1;

  private static final SparseIntArray INTERNAL_LAYOUT_ID_LOOKUP = new SparseIntArray(1);

  static {
    INTERNAL_LAYOUT_ID_LOOKUP.put(com.example.behaviordemo.R.layout.fragment_test_db, LAYOUT_FRAGMENTTESTDB);
  }

  @Override
  public ViewDataBinding getDataBinder(DataBindingComponent component, View view, int layoutId) {
    int localizedLayoutId = INTERNAL_LAYOUT_ID_LOOKUP.get(layoutId);
    if(localizedLayoutId > 0) {
      final Object tag = view.getTag();
      if(tag == null) {
        throw new RuntimeException("view must have a tag");
      }
      switch(localizedLayoutId) {
        case  LAYOUT_FRAGMENTTESTDB: {
          if ("layout/fragment_test_db_0".equals(tag)) {
            return new FragmentTestDbBindingImpl(component, view);
          }
          throw new IllegalArgumentException("The tag for fragment_test_db is invalid. Received: " + tag);
        }
      }
    }
    return null;
  }

  @Override
  public ViewDataBinding getDataBinder(DataBindingComponent component, View[] views, int layoutId) {
    if(views == null || views.length == 0) {
      return null;
    }
    int localizedLayoutId = INTERNAL_LAYOUT_ID_LOOKUP.get(layoutId);
    if(localizedLayoutId > 0) {
      final Object tag = views[0].getTag();
      if(tag == null) {
        throw new RuntimeException("view must have a tag");
      }
      switch(localizedLayoutId) {
      }
    }
    return null;
  }

  @Override
  public int getLayoutId(String tag) {
    if (tag == null) {
      return 0;
    }
    Integer tmpVal = InnerLayoutIdLookup.sKeys.get(tag);
    return tmpVal == null ? 0 : tmpVal;
  }

  @Override
  public String convertBrIdToString(int localId) {
    String tmpVal = InnerBrLookup.sKeys.get(localId);
    return tmpVal;
  }

  @Override
  public List<DataBinderMapper> collectDependencies() {
    ArrayList<DataBinderMapper> result = new ArrayList<DataBinderMapper>(1);
    result.add(new androidx.databinding.library.baseAdapters.DataBinderMapperImpl());
    return result;
  }

  private static class InnerBrLookup {
    static final SparseArray<String> sKeys = new SparseArray<String>(3);

    static {
      sKeys.put(0, "_all");
      sKeys.put(1, "map");
      sKeys.put(2, "text");
    }
  }

  private static class InnerLayoutIdLookup {
    static final HashMap<String, Integer> sKeys = new HashMap<String, Integer>(1);

    static {
      sKeys.put("layout/fragment_test_db_0", com.example.behaviordemo.R.layout.fragment_test_db);
    }
  }
}
```

具体的分析 会在DataBinding-API分析时具体描述

###### writeMergedMapper

> 为`app`生成`DataBinderMapperImpl.java`，其中包含对其他module中的`DataBinderMapperImpl.java`文件的映射

```java
    /**
     * Writes the mapper android.databinding.DataBinderMapperImpl which is a merged mapper
     * that includes all mappers from dependencies.
     */
    private void writeMergedMapper(CompilerArguments compilerArgs) {

        Set<String> featurePackageIds = loadFeaturePackageIds(compilerArgs);
        StringBuilder sb = new StringBuilder();
        LibTypes libTypes = ModelAnalyzer.getInstance().libTypes;
        MergedBindingMapperWriter mergedBindingMapperWriter =
                new MergedBindingMapperWriter(
                        compilerArgs,
                        featurePackageIds,
                        mV1CompatChef != null,
                        libTypes);
        TypeSpec mergedMapperSpec = mergedBindingMapperWriter.write();
        try {
            JavaFile.builder(mergedBindingMapperWriter.getPkg(), mergedMapperSpec)
                    .build().writeTo(sb);
            mFileWriter.writeToFile(mergedBindingMapperWriter.getQualifiedName(),
                    sb.toString());
        } catch (IOException e) {
            Scope.defer(new ScopedException("cannot generate merged mapper class", e));
        }
    }
```

生成`DataBinderMapperImpl`格式如下

```java
public class DataBinderMapperImpl extends MergedDataBinderMapper {
  DataBinderMapperImpl() {
    addMapper(new com.example.behaviordemo.DataBinderMapperImpl());
  }
}
```

//todo流程图





## 总结



## 参考链接

[DataBinding-注解详解](https://www.twblogs.net/a/5b8085ab2b71772165a81a8e)

[DataBinding构建过程分析](https://juejin.cn/post/6984282340205789191#heading-11)
