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

##### ${moduleName}.DataBinderMapperImpl

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
graph TD

```



![DataBinderMapper](/images/DatraBindMapper.svg)



> 总结如下：
>
> 1. `DataBindingUtil`内部持有`sMapper`变量，对应的就是`androidx.databinding.DataBinderMapperImpl(编译期生成)`
> 2. `androidx.databinding.DataBinderMapperImpl`内部记录了`${moduleName}.DataBinderMapperImpl(实现类)`

### 给View设置数据

初始化`FragmentTestDbBindingImpl`时，执行如下代码

```java
    public FragmentTestDbBindingImpl(@Nullable androidx.databinding.DataBindingComponent bindingComponent, @NonNull View root) {
        this(bindingComponent, root, mapBindings(bindingComponent, root, 9, sIncludes, sViewsWithIds));
    }    

    private FragmentTestDbBindingImpl(androidx.databinding.DataBindingComponent bindingComponent, View root, Object[] bindings) {
        super(bindingComponent, root, 2
            , (android.widget.TextView) bindings[1]
            );
        this.mboundView0 = (androidx.constraintlayout.widget.ConstraintLayout) bindings[0];
        this.mboundView0.setTag(null);
        this.mboundView01 = (bindings[7] != null) ? com.example.behaviordemo.databinding.SsBinding.bind((android.view.View) bindings[7]) : null;
        this.mboundView02 = (bindings[8] != null) ? com.example.behaviordemo.databinding.AaBinding.bind((android.view.View) bindings[8]) : null;
        this.mboundView2 = (android.widget.ImageView) bindings[2];
        this.mboundView2.setTag(null);
        this.mboundView3 = (android.widget.ImageView) bindings[3];
        this.mboundView3.setTag(null);
        this.mboundView4 = (android.widget.TextView) bindings[4];
        this.mboundView4.setTag(null);
        this.mboundView5 = (android.widget.TextView) bindings[5];
        this.mboundView5.setTag(null);
        this.mboundView6 = (android.widget.TextView) bindings[6];
        this.mboundView6.setTag(null);
        this.tvTxt.setTag(null);
        setRootTag(root);
        // listeners
        invalidateAll();
    }
```

#### mapBindings

> 取出设置了`tag`的组件，记录在`ViewDataBinding`中的`bindings`中，可以在外部直接获取不需要执行`find`

```java
//ViewDataBinding.java
    protected static Object[] mapBindings(DataBindingComponent bindingComponent, View[] roots,
            int numBindings, IncludedLayouts includes, SparseIntArray viewsWithIds) {
        Object[] bindings = new Object[numBindings];
        for (int i = 0; i < roots.length; i++) {
            mapBindings(bindingComponent, roots[i], bindings, includes, viewsWithIds, true);
        }
        return bindings;
    }

```



#### super(XX) -> ViewDataBinding

> 先执行的`super()`向上走到`FragmentTestDbBinding`，最后执行到`ViewDataBinding`中

```java
//ViewDataBinding.java
public abstract class ViewDataBinding extends BaseObservable implements ViewBinding {

    static {
        if (VERSION.SDK_INT < VERSION_CODES.KITKAT) {
            ROOT_REATTACHED_LISTENER = null;
        } else {
            ROOT_REATTACHED_LISTENER = new OnAttachStateChangeListener() {
                @TargetApi(VERSION_CODES.KITKAT)
                @Override
                public void onViewAttachedToWindow(View v) {
                    // execute the pending bindings.
                    final ViewDataBinding binding = getBinding(v);
                    binding.mRebindRunnable.run();
                    v.removeOnAttachStateChangeListener(this);
                }

                @Override
                public void onViewDetachedFromWindow(View v) {
                }
            };
        }
    }
 ... 
}
```

当View`attachedToWindow`时，调用`mRebindRunable.run`

#### invalidateAll

```java
//FragmentTestDbBindingImpl.java
    @Override
    public void invalidateAll() {
        synchronized(this) {
                mDirtyFlags = 0x40L;
        }
        requestRebind();
    }
```

`requestRebind()`向上调用到`ViewDataBinding`中

```java
//ViewDataBinding.java
    protected void requestRebind() {
        if (mContainingBinding != null) {
            mContainingBinding.requestRebind();
        } else {
            final LifecycleOwner owner = this.mLifecycleOwner;
            if (owner != null) {
                Lifecycle.State state = owner.getLifecycle().getCurrentState();
                if (!state.isAtLeast(Lifecycle.State.STARTED)) {
                    return; // wait until lifecycle owner is started
                }
            }
            synchronized (this) {
                if (mPendingRebind) {
                    return;
                }
                mPendingRebind = true;
            }
            if (USE_CHOREOGRAPHER) {
                mChoreographer.postFrameCallback(mFrameCallback);
            } else {
                mUIThreadHandler.post(mRebindRunnable);
            }
        }
    }
```

最后也是调用到`mRebindRunnable`



#### mRebindRunnable

```java
    private final Runnable mRebindRunnable = new Runnable() {
        @Override
        public void run() {
            synchronized (this) {
                mPendingRebind = false;
            }
            processReferenceQueue();
            if (VERSION.SDK_INT >= VERSION_CODES.KITKAT) {
                // Nested so that we don't get a lint warning in IntelliJ
                if (!mRoot.isAttachedToWindow()) {
                    // Don't execute the pending bindings until the View
                    // is attached again.
                    mRoot.removeOnAttachStateChangeListener(ROOT_REATTACHED_LISTENER);
                    mRoot.addOnAttachStateChangeListener(ROOT_REATTACHED_LISTENER);
                    return;
                }
            }
            executePendingBindings();
        }
    };
```

`mRebindRunnable.run` 主要执行如下：

1. 判断`mRoot`是否已经绑定在Window上，已绑定则执行`executePendingBindings`
2. 没有绑定，先添加监听，等绑定时，再次调用`mRebindRunnable.run()`，向下继续执行到`executePendingBindings`

#### executeBindings

```java
//ViewDataBinding.java
public void executePendingBindings() {
       
        if (mContainingBinding == null) {
            executeBindingsInternal();
        } else {
          //包含了 <include>引入的 layout ，通过引入的 layout对应的binding执行数据处理
            mContainingBinding.executePendingBindings();
        }
    }

//交由子类实现
    protected abstract void executeBindings();

    private void executeBindingsInternal() {
        if (mIsExecutingPendingBindings) {
            requestRebind();
            return;
        }
        if (!hasPendingBindings()) {
            return;
        }
        mIsExecutingPendingBindings = true;
        mRebindHalted = false;
        if (mRebindCallbacks != null) {
            mRebindCallbacks.notifyCallbacks(this, REBIND, null);

            // The onRebindListeners will change mPendingHalted
            if (mRebindHalted) {
                mRebindCallbacks.notifyCallbacks(this, HALTED, null);
            }
        }
        if (!mRebindHalted) {
            executeBindings();
            if (mRebindCallbacks != null) {
                mRebindCallbacks.notifyCallbacks(this, REBOUND, null);
            }
        }
        mIsExecutingPendingBindings = false;
    }
```

此处`executeBindings()`的实现在`FragmentTestDbBindingImpl`中

```java
    @Override
    protected void executeBindings() {
        long dirtyFlags = 0;
        synchronized(this) {
            dirtyFlags = mDirtyFlags;
            mDirtyFlags = 0;
        }
        androidx.databinding.ObservableField<java.lang.String> bookName = null;
        java.lang.String bookNameGet = null;
        com.example.behaviordemo.bindingadapter.JavaBook javaBook = mJavaBook;
        java.lang.String javaBookName = null;
      ...
        if ((dirtyFlags & 0x40L) != 0) {
            // api target 1

            com.example.behaviordemo.bindingadapter.ViewExpressionKt.setShape(this.mboundView2, com.example.behaviordemo.bindingadapter.ShapeBuilder.create().setCornerRadius(10).setColors(android.graphics.Color.RED).setShapeType(0));
            androidx.databinding.adapters.ViewBindingAdapter.setBackground(this.mboundView3, com.example.behaviordemo.bindingadapter.ViewExpressionKt.colorToDrawable("#00ff00"));
        }
        if ((dirtyFlags & 0x48L) != 0) {
            // api target 1

            androidx.databinding.adapters.TextViewBindingAdapter.setText(this.mboundView4, text);
            androidx.databinding.adapters.TextViewBindingAdapter.setText(this.tvTxt, text);
        }        
      
    }
```

> 通过判断`dirtyFlags`是否有变化，根据他的变化执行对应的赋值语句。



```mermaid
```



### View与Model双向更新

#### Model -> View Model变化通知View修改

> 支持监听Model数据变化的方式有两种
>
> - 在Model中参数的`getXX`添加`@Bindable`注解，在`setXX`内调用`notifyPropertyChanged()`
> - 直接设置Model参数为`ObservableField<T>`

通过设置`ObservableField`，当值发生变化时，会调用到`ViewDataBinding.updateRegistration()`，后续继续调用最终也会执行到`notifyPropertyChanged`

##### BaseObservable.notifyPropertyChanged

```java
private transient PropertyChangeRegistry mCallbacks;

public void notifyPropertyChanged(int fieldId) {
        synchronized (this) {
            if (mCallbacks == null) {
                return;
            }
        }
        mCallbacks.notifyCallbacks(this, fieldId, null);
    }

```

此时`mCallbacks`为`PropertyChangeRegistry`

```java
public class PropertyChangeRegistry extends
        CallbackRegistry<Observable.OnPropertyChangedCallback, Observable, Void> {

    private static final CallbackRegistry.NotifierCallback<Observable.OnPropertyChangedCallback, Observable, Void> NOTIFIER_CALLBACK = new CallbackRegistry.NotifierCallback<Observable.OnPropertyChangedCallback, Observable, Void>() {
        @Override
        public void onNotifyCallback(Observable.OnPropertyChangedCallback callback, Observable sender,
                int arg, Void notUsed) {
            callback.onPropertyChanged(sender, arg);
        }
    };
  
}
```

对应的callback就为`ViewDataBinding.WeakPropertyListener`

##### WeakPropertyListener.onPropertyChanged

```java
//ViewBinding.java
    private static class WeakPropertyListener extends Observable.OnPropertyChangedCallback
            implements ObservableReference<Observable> {
      ...
        @Override
        public void onPropertyChanged(Observable sender, int propertyId) {
            ViewDataBinding binder = mListener.getBinder();
            if (binder == null) {
                return;
            }
            Observable obj = mListener.getTarget();
            if (obj != sender) {
                return; // notification from the wrong object?
            }
            binder.handleFieldChange(mListener.mLocalFieldId, sender, propertyId);
        }
      
    }

    @RestrictTo(RestrictTo.Scope.LIBRARY_GROUP)
    protected void handleFieldChange(int mLocalFieldId, Object object, int fieldId) {
        if (mInLiveDataRegisterObserver || mInStateFlowRegisterObserver) {
            return;
        }
        boolean result = onFieldChange(mLocalFieldId, object, fieldId);
        if (result) {
            requestRebind();
        }
    }
```



##### requestRebind

```java
//ViewDataBinding.java
    protected void requestRebind() {
        if (mContainingBinding != null) {
            mContainingBinding.requestRebind();
        } else {
           ...
            if (USE_CHOREOGRAPHER) {
                mChoreographer.postFrameCallback(mFrameCallback);
            } else {
                mUIThreadHandler.post(mRebindRunnable);
            }
        }
    }
```

此处就续上了上一节中`mRebindRunnable`后续的执行流程，最终走到`executeBindings`刷新View中的显示数据。



#### View -> Model View变化修改Model

> 相对使用较少

### 避免冗余UI更新

> 由于DataBinding是`Viwe与Model是双向绑定的`，所以修改了model，View也会更新，再导致Model的修改。
> 可能就会存在冗余更新，`DataBinding`内部会对此进行处理。

```java
//更新文字
    @Override
    protected void executeBindings() {
      ...
      androidx.databinding.adapters.TextViewBindingAdapter.setText(this.mboundView6, javaBookName);
    }
```

内部并非直接调用`TextView.setText()`，而是通过`TextViewBindingAdapter.setText`进行设置

```java
public class TextViewBindingAdapter {
      @BindingAdapter("android:text")
    public static void setText(TextView view, CharSequence text) {
        final CharSequence oldText = view.getText();
      //优先判断文字是否相同，相同则不执行后续setText
        if (text == oldText || (text == null && oldText.length() == 0)) {
            return;
        }
        if (text instanceof Spanned) {
            if (text.equals(oldText)) {
                return; // No change in the spans, so don't set anything.
            }
        } else if (!haveContentsChanged(text, oldText)) {
            return; // No content changes, so don't set anything.
        }
        view.setText(text);
    }
  
}
```



## 参考链接

[DataBinding原理](https://mdnice.com/writing/518996ef89c5413fb26025054edd9e6c)

[DataBinding-绑定原理](https://juejin.cn/post/6984281996457902110)

<!-- https://www.jianshu.com/p/70bca3376957 -->

