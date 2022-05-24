---
title: Android-DataBinding-Library分析
typora-root-url: ../
date: 2022-05-10 21:13:37
tags: 源码解析
top: 9
---



{% post_link Android-DataBinding-GradlePlugin分析 %}

回顾上节内容，GradlePlugin主要产出了以下文件，以便后续API功能调用

- **xx.xml**：正常的资源编译文件，后续apk中保留为这份文件。主要是将原始的xml文件中的 <layout> <data>标签移除，并未每个view设置`tag`
- **xx-layout.xml**：记录组件的绑定信息，如<data>标签内容，以及xml使用的表达式
- **XXBinding.java**：记录`View的id`以及`<data>定义的<variable>参数`，后文会有详细介绍
- **XXBindingImpl.java**：基于`XXBinding`的实现类，双向绑定参数的赋值逻辑均在内部实现，后文会有详细介绍
- **BR.java**：记录`@Bindable`以及`<variable>`相关参数
- **DataBinderMapperImpl.java**
  - 包名为 `androidx.databinding.library`：记录项目中ViewDataBinding的映射表，内部主要为 其他module里的`DataBinderMapperImpl.java`
  - 包名为`module 或 app`name：记录`module或app`中哪些布局文件使用了`DataBinding`，即使用`<layout>`包裹

## 相关模块

`baseLibrary`、`extensions/library`、`extensions/baseAdapters`

## 核心类

- `DataBindingUtil`
- `XXBindingImpl`
- `DataBinderMapperImpl`


## 执行流程

### 布局与Binding绑定

在代码中通常用以下代码获取Binding对象

```kotlin
//在Activity中
var binding: ActivityMainBinding = ActivityMainBinding.inflate(layoutInflater)

var binding: ActivityMainBinding = DataBindingUtil.setContentView<ActivityMainBinding>(this,R.layout.activity_main)

//在Fragment或View中
var fBinding : FragmentTestDBBinding = FragmentTestDbBinding.inflate(inflater)

var fBinding : FragmentTestDBBinding = FragmentTestDbBinding.inflate(inflater, container, false)

var fBinding : FragmentTestDBBinding = DataBindingUtil.inflate(inflater, R.layout.fragment_test_db, container, false)
```

主要由两个类来操作：

- XXBinding
- DataBindingUtil

#### XXBinding

> 以`FragmentTestDBBinding`为例分析

```java
public abstract class FragmentTestDbBinding extends ViewDataBinding {
  //xml中定义view的id，方便通过binding直接调用对应的View
  @NonNull
  public final TextView tvTxt;

  //xml中定义的<variable>，方便直接调用赋值
  @Bindable
  protected Book mBook;
  ...
    
  @NonNull
  public static FragmentTestDbBinding inflate(@NonNull LayoutInflater inflater) {
    return inflate(inflater, DataBindingUtil.getDefaultComponent());
  }
  
  @NonNull
  public static FragmentTestDbBinding inflate(@NonNull LayoutInflater inflater,
      @Nullable ViewGroup root, boolean attachToRoot) {
    return inflate(inflater, root, attachToRoot, DataBindingUtil.getDefaultComponent());
  }
  
  public static FragmentTestDbBinding inflate(@NonNull LayoutInflater inflater,
      @Nullable ViewGroup root, boolean attachToRoot, @Nullable Object component) {
    return ViewDataBinding.<FragmentTestDbBinding>inflateInternal(inflater, R.layout.fragment_test_db, root, attachToRoot, component);
  }
  
}
```

`XXBinding.inflate()`最后都指向` ViewDataBinding.inflateInternal()`

```java
//ViewDataBinding.java

    @RestrictTo(RestrictTo.Scope.LIBRARY_GROUP)
    protected static <T extends ViewDataBinding> T inflateInternal(
            @NonNull LayoutInflater inflater, int layoutId, @Nullable ViewGroup parent,
            boolean attachToParent, @Nullable Object bindingComponent) {
        return DataBindingUtil.inflate(
                inflater,
                layoutId,
                parent,
                attachToParent,
                checkAndCastToBindingComponent(bindingComponent)
        );
    }
```

`inflateInternal()`调用到`DataBindingUtil.inflate()`

#### DataBindingUtil

##### inflate/setContentView

```java
    public static <T extends ViewDataBinding> T inflate(
            @NonNull LayoutInflater inflater, int layoutId, @Nullable ViewGroup parent,
            boolean attachToParent, @Nullable DataBindingComponent bindingComponent) {
        final boolean useChildren = parent != null && attachToParent;
        final int startChildren = useChildren ? parent.getChildCount() : 0;
        final View view = inflater.inflate(layoutId, parent, attachToParent);
        if (useChildren) {
            return bindToAddedViews(bindingComponent, parent, startChildren, layoutId);
        } else {
          //单组件直接调用 bind
            return bind(bindingComponent, view, layoutId);
        }
    }

    public static <T extends ViewDataBinding> T setContentView(@NonNull Activity activity,
            int layoutId, @Nullable DataBindingComponent bindingComponent) {
        activity.setContentView(layoutId);
        View decorView = activity.getWindow().getDecorView();
        ViewGroup contentView = (ViewGroup) decorView.findViewById(android.R.id.content);
        return bindToAddedViews(bindingComponent, contentView, 0, layoutId);
    }
```

最后都调用到`bindToAddedViews`

##### bindToAddedViews

```java
    private static <T extends ViewDataBinding> T bindToAddedViews(DataBindingComponent component,
            ViewGroup parent, int startChildren, int layoutId) {
        final int endChildren = parent.getChildCount();
        final int childrenAdded = endChildren - startChildren;
        if (childrenAdded == 1) {
            final View childView = parent.getChildAt(endChildren - 1);
            return bind(component, childView, layoutId);
        } else {
            final View[] children = new View[childrenAdded];
            for (int i = 0; i < childrenAdded; i++) {
                children[i] = parent.getChildAt(i + startChildren);
            }
            return bind(component, children, layoutId);
        }
    }
```

##### bind

```java
//DataBinderMapperImpl 包名为 androidx.databinding

private static DataBinderMapper sMapper = new DataBinderMapperImpl();    

    static <T extends ViewDataBinding> T bind(DataBindingComponent bindingComponent, View[] roots,
            int layoutId) {
        return (T) sMapper.getDataBinder(bindingComponent, roots, layoutId);
    }

    static <T extends ViewDataBinding> T bind(DataBindingComponent bindingComponent, View root,
            int layoutId) {
        return (T) sMapper.getDataBinder(bindingComponent, root, layoutId);
    }
```

最后调用到`DataBinderMapperImpl.getDataBinder()`

#### DataBinderMapperImpl

##### androidx.databinding.DataBinderMapperImpl

```java
//记录使用的 DataBinding信息
public class DataBinderMapperImpl extends MergedDataBinderMapper {
  DataBinderMapperImpl() {
    addMapper(new com.example.behaviordemo.DataBinderMapperImpl());
  }
}
```

##### MergedDataBinderMapper

```java
//添加映射    
public void addMapper(DataBinderMapper mapper) {
        Class<? extends DataBinderMapper> mapperClass = mapper.getClass();
        if (mExistingMappers.add(mapperClass)) {
            mMappers.add(mapper);
            final List<DataBinderMapper> dependencies = mapper.collectDependencies();
            for(DataBinderMapper dependency : dependencies) {
                addMapper(dependency);
            }
        }
    }

    @Override
    public ViewDataBinding getDataBinder(DataBindingComponent bindingComponent, View view,
            int layoutId) {
        for(DataBinderMapper mapper : mMappers) {
            ViewDataBinding result = mapper.getDataBinder(bindingComponent, view, layoutId);
            if (result != null) {
                return result;
            }
        }
        return null;
    }

```

其中`mMappers`之一对应就为`com.example.behaviordemo.DataBinderMapperImpl()`

##### ${packageName}.DataBinderMapperImpl

```java
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
```

最终返回的就是`FragmentTestDbBindingImpl`

```mermaid
```



### View与Model绑定



### View与Model双向更新



## 参考链接

[DataBinding原理](https://mdnice.com/writing/518996ef89c5413fb26025054edd9e6c)