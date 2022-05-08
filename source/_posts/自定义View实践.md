---
title: 自定义View实践
date: 2019-01-02 14:16:26
tags: Android
top: 10
---

<!--实现一个自定义view，其中含有若干textview，textview文字可换行且自定义- - view的高度可自适应拓展-->

> Android系统默认提供大量的View，但是会因为需求的改动导致原生View不能符合需求，就需要进行自定义控件去使用。
## 实现方式
- 继承特定View

  > 拓展某种已有View的功能就可以在原有View的基础上增加新功能，而且这种实现方式就不需要自己去处理那些注意事项，例如`wrap_content、pandding`等属性。

- 继承View并重写`onDraw()`

  > 当需要实现一些不规则的效果，比如绘制一些图案，按照不同的需求需要实现更多的功能。这种实现方式就需要注意以下事项：
  >
  > - 需要自己支持`wrap_content、padding`
  > - 注意`onDraw()`绘制的性能问题



## 注意事项
在实现过程中会有详细的实现介绍
- 自定义View支持`wrap_content`

  > 在自定View中使用`wrap_content`在显示结果上总是和`match_parent`效果一致，原因在于源码中对View的实现有一种默认处理。

  ```java View.java
  public static int getDefaultSize(int size, int measureSpec) {
          int result = size;
          int specMode = MeasureSpec.getMode(measureSpec);
          int specSize = MeasureSpec.getSize(measureSpec);
  
          switch (specMode) {
          case MeasureSpec.UNSPECIFIED:
              result = size;
              break;
          case MeasureSpec.AT_MOST:
          case MeasureSpec.EXACTLY:
          //这段代码中可以分析得出 一个直接继承View的自定义View 定义为wrap_content和match_parent大小都是一致的.
              result = specSize;
              break;
          }
          return result;
      }
  ```
- 有必要需要支持`padding、margin`属性

  > `android:padding`该属性控制View内部边距，`android:margin`属性控制与父布局的边距。
  >
  > 都需要在`onDraw()`过程中去进行特殊处理。

- 尽量不要在View中使用Handler

  > View内部提供了`post()`可以发送事件，完全替代Handler作用，使用还方便。

- 自定义View如果有线程或动画，需要及时停止

  > 当View中使用了`线程或动画`时，可能因为忘记及时释放，使他们持有了View，从而导致Activity出现内存泄漏问题。

- 需要注意滑动冲突

  > View中使用了滑动时，需要注意滑动冲突问题。

  解决滑动冲突两种方案：`外部拦截法`、`内部拦截法`。



## 实现步骤

### 创建View

#### 继承View

```java
class CustomView extends View{
    /**
    * 自动调用——用于在Java代码new使用的
    */
    public CustomView(Context context){
        super(context);
    }
    /**
    * 自动调用——用于View在xml里使用时调用的
    */
    public CustomView(Context context,AttributeSet attrs/*xml中传进来的属性*/){
        super(context,attrs);
    }
    /**
    * 非自动调用——用于View设置看style属性时，大部分情况下都是调用的双参数函数
    * defStyleAttr 指的时当前Application或Activity所用Theme的默认style
    */
    public CustomView(Context context,AttributeSet attrs,int defStyleAttr){
        super(context,attrs,defStyleAttr);
    }
    /**
    * 在API21 以上时添加的函数
    * 非自动调用
    */
    public CustomView(Context context,AttributeSet attrs,int defStyleAttr,int defStyleRes){
        super(context,attrs,defStyleAttr,defStyleRes)
    }
}
```

继承View之后，系统提供了4个构造函数，每个函数的参数也不尽相同。

```java
public CustomView(Context context)
```

在Activity中进行调用时`CustomView view= new CustomView(this)`

<br>

```java
public CustomView(Context context,AttributeSet attrs/*xml中传进来的属性*/)
```

在xml中调用时触发

```xml
<CustomView
    android:layout_width"wrap_content"
  android:layout_height"wrap_content"/>
```

<br>

```java 
public CustomView(Context context,AttributeSet attrs,int defStyleAttr)
```

这个方法需要第二个构造函数进行显式调用方可生效，传入自定义的Theme

```java
public CustomView(Context context,AttributeSet attrs/*xml中传进来的属性*/){
    this(context,attrs,R.style.theme)
}
```

> 该构造函数的作用：**为View的子类提供该类的基础样式**。

<br>

```java
public CustomView(Context context,AttributeSet attrs,int defStyleAttr,int defStyleRes)
```



#### 定义自定义属性

> 自定义View中通常需要支持更多的设置，例如背景颜色，文字内容等属性，设置完毕后就可以对应的显示出来。

通常将所需的自定义属性配置到`res/values/attrs.xml`中，等待自定义View进行引用。

```xml
<declare-styleable name="CustomView">
 	<attr name="color_attr" format="color"/>
    <attr name="boolean_attr" format="boolean"/>
    <attr name="string_attr" format="string"/>
    <!--自定义属性支持组合使用-->
    <attr name="reference_attr" format="color | reference"/>
</declare-styleable>
```

主要介绍常用的几种属性：

| format    | 作用                     | 使用方法                                   |
| --------- | ------------------------ | ------------------------------------------ |
| color     | 设置颜色值例如 `#ffffff` | app:color_attr="#ffffff"                   |
| boolean   | 布尔值                   | app:boolean_attr = "true"                  |
| string    | 字符串                   | app:string_attr="android"                  |
| dimension | 尺寸值                   | app:dimension_attr="36dp"                  |
| float     | 浮点值                   | app:float_attr="1.0"                       |
| integer   | 整型值                   | app:intege_attr="100"                      |
| fraction  | 百分数                   | app:fraction_attr="100%"                   |
| reference | 获取某一资源ID           | app:reference_attr="@drawable/ic_launcher" |
| enum      | 枚举值                   | app:enum_attr="enum_1"                     |

其中`enum`的实现比较特殊：

```xml
<attr name="enum_attr" >
     <enum name="enum_1" value="0"/>
     <enum name="enum_2" value="1"/>
</attr>
```

声明自定义属性完毕后，需要在xml中进行引用

```xml
<CustomView
      android:layout_width="wrap_content"
      android:layout_height="wrap_content"
      app:color_attr="#ffffff"
      app:float_attr="12f"
      app:enum_attr="enum_1"
      app:integer_attr="10"
      app:reference_attr="@color/colorAccent"
      app:dimension_attr="36dp"
      app:boolean_attr="true"
      app:string_attr="android"
/>
```



#### 获取自定义属性

在xml中设置自定义属性完毕后，就需要在自定义View中去获取对应属性的值。

```java
//加载自定义属性集合
TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.CustomView);
...  获取具体属性值
// 使用完毕需要进行回收
typedArray.recycle();
```

根据上节中定义的自定义属性，获取方式也不尽相同。

| format    | 如何获取                                                     |
| --------- | ------------------------------------------------------------ |
| color     | typedArray.getColor(R.styleable.CustomView_color_attr, Color.RED); |
| boolean   | typedArray.getBoolean(R.styleable.CustomView_boolean_attr, true); |
| string    | typedArray.getString(R.styleable.CustomView_string_attr);    |
| dimension | floar dimension = typedArray.getDimension(R.styleable.CustomView_dimension_attr,20);*完整结果*<br>int dimension = typedArray.getDimensionPixelOffset(R.styleable.CustomView_dimension_attr,20);*舍弃末尾小数*<br>int dimension = typedArray.getDimensionPixelSize(R.styleable.CustomView_dimension_attr,20);*四舍五入* |
| float     | typedArray.getFloat(R.styleable.CustomView_float_attr, 1f);  |
| integer   | typedArray.getInteger(R.styleable.CustomView_integer_attr, 1); |
| fraction  | typedArray.getFraction(R.styleable.CustomView_fraction_attr,4,5,1); |
| reference | typedArray.getResourceId(R.styleable.CustomView_reference_attr, R.drawable.ic_launcher_background); |
| enum      | typedArray.getInt(R.styleable.CustomView_enum_attr, 0);      |



#### 添加设置属性事件

上述自定义的属性只能在View初始化时可以获取并在xml中进行设置，如果后续想修改对应属性，就需要针对设置属性事件来进行修改和获取。

```java
public boolean getBooleanAttr(){
    return boolean_attr;
}

public void setBooleanAttr(boolean boolean_attr){
    this.boolean_attr= boolean_attr;
    //根据不同的需求去选择刷新界面方法。
    //postInvalidate(); 重新进行绘制
    //invalidate(); 重新进行绘制
    //requestLayout() 对整个布局进行测量-布局-绘制过程
}
```



### 处理View的布局

#### 测量View大小

> 为了让自定义View可以根据不同的情况以合适的宽高进行展示

这里要做的就是对`onMeasure()`进行重写，View是通过该方法确定对应宽高。

```java
@Override
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
    super.onMeasure(widthMeasureSpec, heightMeasureSpec);
        int widthMeasureSpecSize = MeasureSpec.getSize(widthMeasureSpec);      //取出宽度的确切数值 后30bit
        int widthMeasureSpecMode = MeasureSpec.getMode(widthMeasureSpec);      //取出宽度的测量模式 前2bit

        int heightMeasureSpecSize = MeasureSpec.getSize(heightMeasureSpec);    //取出高度的确切数值 后30bit
        int heightMeasureSpecMode = MeasureSpec.getMode(heightMeasureSpec);    //取出高度的测量模式 前2bit

        if (widthMeasureSpecMode == MeasureSpec.AT_MOST && heightMeasureSpecMode == MeasureSpec.AT_MOST) {
            setMeasuredDimension(400, 400);
        } else if (widthMeasureSpecMode == MeasureSpec.AT_MOST) {
            setMeasuredDimension(400, heightMeasureSpecSize);
        } else if (heightMeasureSpecMode == MeasureSpec.AT_MOST) {
            setMeasuredDimension(widthMeasureSpecSize, 400);
        }
}
```

代码中`widthMode/heightMode`对应的有3类，代表的是**测量模式**

| 测量模式    | 定义                                                         |
| ----------- | ------------------------------------------------------------ |
| UNSPECIFIED | 当前控件没有限制，想多大就多大，一般在系统中使用的           |
| EXACTLY     | 表示父控件指定了一个确切的大小，一般定义为`具体大小(20dp)`或`match_parent(父布局大小)` |
| AT_MOST     | 表示没有具体的大小限制，不过指定了上限，一般为父布局大小，一般定义为`wrap_content` |

代码中`widthSize/heightSize`指代的就是 **父布局期望的子View大小**。

代码中针对`AT_MOST`进行了特殊的处理，针对的情况就是使用了`wrap_content`，在Android源码中，系统的处理方案是`AT_MOST和EXACTLY`得到结果是一致的，而导致`wrap_content`属性失效。

> 如果后续也对View的宽高进行修改，就调用`setMeasureDimension()`执行修改。

#### 确定View大小

> View的大小不仅由自身控制，父布局也会有影响，因此获取View大小时最好通过`onSizeChanged()`获取。

```java
@Override
protected void onSizeChanged(int w, int h, int oldw, int oldh) {
    super.onSizeChanged(w, h, oldw, oldh);
}
```

其中`w、h`就是最终的宽、高。

### 绘制View

> 尺寸确定完毕后，接下来就要去绘制View所需的内容，直接把我们相要绘制的内容放在`canvas`上即可

```java
@Override
protected void onDraw(Canvas canvas) {
    super.onDraw(canvas);
    //这个应该放在init()时进行初始化 ，此处只为举例说明
    Paint paint = new Paint();
    paint.setColor(Color.GREEN);
    //开始绘制 画一个圆
    canvas.drawCircle(centerX, centerY, r, paint);
}
```

其中涉及了两个对象：

- **Canvas**：画布对象，决定了要去画什么
- **Paint**：画笔对象，决定了怎么画，比如颜色，粗细等

在注意事项中，还需要注意的是`padding`属性的处理，这部分处理就在`onDraw()`中执行。

```java
 @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        //获取xml中设置的padding属性值
        int paddingTop = getPaddingTop();
        int paddingBottom = getPaddingBottom();
        int paddingStart = getPaddingStart();
        int paddingEnd = getPaddingEnd();
        //得到的结果就是 该View实际可用的绘制大小
        int width = getWidth() - paddingStart - paddingEnd;
        int height = getHeight() - paddingTop - paddingBottom;

    }
```



> 在实现`onDraw()`过程中需要注意，最好不要去生成任何的局部对象，由于View的绘制过程是发生最频繁的，可能由于生成大量临时对象导致频繁GC，影响性能。

### 与用户进行交互

> 如果需要额外的对用户的触摸或者滑动事件去进行支持，这时就需要去实现一些触摸方法。

通过实现`onTouchEvent()`来实现触摸事件响应，实现`GestureDetector`相关接口去实现滑动功能。

**此时需要注意滑动冲突上的处理。**

### 优化自定义View

上述流程实现完毕后，就需要针对实现的自定义View去做一些优化处理，减少问题。

1. 避免不必要的代码

2. 在`onDraw()`中不要出现创建对象的方法

3. 尽可能减少`onDraw()`调用，提升绘制效率。

4. 如果设置了线程或者动画需要及时清理

   > 不处理可能导致内存泄漏的发生
   >
   > 此时可以在`onAttachedToWindow()`时去进行线程或动画初始化等工作
   >
   > 最后在`onDetachedFromWindow()`时去清理掉他们。



