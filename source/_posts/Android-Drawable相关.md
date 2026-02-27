---

title: Android - Drawable相关
date: 2019-01-10 11:54:23
tags: Android
top: 9
typora-root-url: ../
---

## Drawable简介

> Drawable是一种 可以在Canvas上进行绘制的对象，即**可绘制物**。与`View`不同，`Drawable`没有事件和交互的方法。

在实际开发中，Drawable通常被用作View的背景，一般通过XML进行定义，也支持通过代码去实现(*例如动画样式的Drawable*)。

Drawable是一个抽象类，是所有Drawable的基类。例如常用的`ShapeDrawable、BitmapDrawable，LayerDrawable`等。



![Drawable-xmind](/images/Drawable相关.png)

<!--Drawable绘制流程与View有什么区别？实现动画有什么区别？View为什么还要Drawable-->

### Drawable使用方式

- `XML引入`：创建所需Drawable根节点的`XML`，再通过调用`@drawable/xx`引入页面布局中

  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <shape xmlns:android="http://schemas.android.com/apk/res/android"
      android:shape="oval">
      <solid android:color="#fff3c3" />
      <size
          android:width="@dimen/x16"
          android:height="@dimen/x16" />
  </shape>
  
  android:background = "@drawable/xx"
  ```

- `Java代码`：new一个所需Drawable并设置相关属性，最后设置到布局中。

  ```java
  //自定义一个 Drawable对象 ，需要继承 Drawable基类
  class HomeWaterRippleDrawable(private val context: Context) : Drawable()
  //动态为布局设置 Drawable属性
  lav_camera.setImageDrawable(HomeWaterRippleDrawable(mActivity))
  ```


#### Drawable宽高

Drawable可以通过`getIntrinsicWidth()和getIntrinsicHeight()`获取内部宽高。*其实在View工作原理的`measure`过程中有用到这个方法，就是为了View设置背景时可以精确的确定其宽高*。

> 不是所有的Drawable都有宽高
>
> - 图片所形成的Drawable内部宽高就是图片的宽高
> - 颜色所形成的Drawable没有内部宽高的概念

Drawable没有大小的概念，当用作View的背景时，Drawable会被拉伸至View的同等大小。

#### Drawable使用范围

- 作为ImageView的图像显示——`ImageView.setImageDrawable()`
- 作为View的背景——`View.setBackgroundDrawable()`

## Drawable的种类

![常用Drawable](/images/Drawable-常用Drawable.png)

| Drawable种类                       | 对应tag    | 描述                                                         |
| ---------------------------------- | ---------- | ------------------------------------------------------------ |
| **BitmapDrawable**                 | bitmap     | 表示一张图片                                                 |
| **ColorDrawable**                  | color      | 表示一个纯色的Drawable                                       |
| NinePatchDrawable                  | nine-patch | 表示一张.9格式的图片                                         |
| **ShapeDrawable/GradientDrawable** | shape      | 可表示纯色、有渐变效果的基础几何图形（例如矩形、圆形等）     |
| **LayerDrawable**                  | layer-list | 表示一种层次性的Drawable集合，实现一种叠加效果。<br>下层的item会覆盖上层 |
| **StateListDrawable**              | selector   | 表示Drawable的集合，每个Drawable对应着一种View的状态         |
| LevelListDrawable                  | level-list | 表示Drawable的集合，每个Drawable对应着一种层级               |
| TransitionDrawable                 | transition | 表示两个Drawable间的淡入淡出效果                             |
| InsetDrawable                      | inset      | 表示把一个Drawable嵌入到内部，并留有间隙                     |
| ScaleDrawable                      | scale      | 表示将Drawable缩放到一定比例                                 |
| ClipDrawable                       | clip       | 表示裁剪一个Drawable                                         |
| RotateDrawable                     | rotate     | 表示旋转一个Drawable                                         |
| VectorDrawable                     | vector     | 表示一个SVG的Drawable                                        |



### 1.BitmapDrawable

> 表示一张图片

根节点为`bitmap`。在使用过程中，我们可以直接引用原始图片即可，也可以通过XML的方式来描述他。

```xml
<bitmap 
   xmlns:android="http://schemas.android.com/apk/res/android"
   android:src=""
   android:antialias="[true | false]"
   android:dither="[true | false]"
   android:filter="[true | false]"
   android:tileMode="[disabled | clamp | repeat | mirror]"
   android:gravity="[top | bottom | left | right | center_vertical |
                    |fill_vertical | center_horizontal | fill_horizontal |
                    |center | fill | clip_vertical | clip_horizontal]"
   >
</bitmap>
```

下面是各个属性的含义：

`android:src`：图片的资源id

`android:antialias`：是否开启抗锯。，开启会让图片变得平滑。*可能导致图片清晰度下降，基本可以忽略，应该开启。*

`android:dither`：是否开启抖动效果。可以让高质量的图片在低质量的屏幕上还能保持较好的显示效果，是图片显示不过于失真。*应该开启。*

`android:filter`：是否开启过滤效果。当图片被拉伸或者压缩时，开启可以保持较好的显示效果。*应该开启*。

`android:tileMode`：平铺模式。开启平铺模式时，`gravity`属性会被忽略。

|  可选项  |                       含义                       |
| :------: | :----------------------------------------------: |
| disabled |               关闭平铺模式*默认值*               |
|  clamp   | 图片四周的像素会拓展到周围区域*就是边缘像素拉伸* |
|  repeat  |                水平和竖直方向平铺                |
|  mirror  |              水平和竖直方向镜像显示              |

`android:gravity`：对图片位置进行定位。可以通过"|"进行组合使用。

|      可选项       |                含义                |
| :---------------: | :--------------------------------: |
|        top        |      不改变大小，置于容器顶部      |
|      bottom       |      不改变大小，置于容器底部      |
|       left        |      不改变大小，置于容器左部      |
|       right       |      不改变大小，置于容器右部      |
|  center_vertical  |    不改变大小，置于容器竖直居中    |
|   fill_vertical   |        图片竖直拉伸填满容器        |
| center_horizontal |    不改变大小，置于容器水平居中    |
|  fill_horizontal  |        图片水平拉伸填满容器        |
|      center       | 不改变大小，置于容器水平和竖直居中 |
|       fill        |  水平竖直方向拉伸填满容器*默认值*  |
|   clip_vertical   |          竖直方向进行裁剪          |
|  clip_horizontal  |          水平方向进行裁剪          |

##### 应用代码

```xml
//repeat_bitmap.xml
<?xml version="1.0" encoding="utf-8"?>
<bitmap xmlns:android="http://schemas.android.com/apk/res/android"
    android:dither="true"
    android:src="@mipmap/ic_launcher"
    android:tileMode="repeat"
    >
</bitmap>

//布局文件引用
android:background="@drawable/repeat_bitmap"
```

```java
	Bitmap bitmap = BitmapFactory.decodeResource(getResources(),R.mipmap.ic_launcher);
	BitmapDrawable bitDrawable = new BitmapDrawable(bitmap);
	bitDrawable.setDither(true);
	bitDrawable.setTileModeXY(Shader.TileMode.REPEAT, Shader.TileMode.REPEAT);

	view.setBackground(bitmapDrawable);
```

### 2.NinePatchDrawable

> 表示一张.9格式的图片

```xml
<nine-patch xmlns:android="http://schemas.android.com/apk/res/android"
    android:dither="[true|false]"
    android:src="">
</nine-patch>
```

`android:src`：图片的资源id

`android:dither`：是否开启抖动效果。可以让高质量的图片在低质量的屏幕上还能保持较好的显示效果，是图片显示不过于失真。*应该开启。*

##### 应用代码

```xml
//对应 ninepatch.9.png   ninepatch.xml
<?xml version="1.0" encoding="utf-8"?>
<nine-patch xmlns:android="http://schemas.android.com/apk/res/android"
    android:dither="true"
    android:src="@drawable/ninepatch"
    >
</nine-patch>

//布局文件引用
android:background="@drawable/ninepatch"
```



### 3.ShapeDrawable — 实际为`GradientDrawable`

> 可表示纯色，有渐变效果的基础几何图形(例如矩形，圆形等)

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="[rectangle | oval | line | ring]">
    <corners
        android:radius="integer"
        android:topLeftRaidus="integer"
        android:topRightRaidus="integer"
        android:bottomLeftRaidus="integer"
        android:bottomRightRaidus="integer" />
    <gradient
        android:angle="integer"
        android:centerX="integer"
        android:centerY="integer"
        android:centerColor="color"
        android:endColor="color"
        android:gradientRadius="integer"
        android:startColor="color"
        android:type="[linear | radial | sweep]"
        android:useLevel="[true | false]" />
    <padding
        android:left="integer"
        android:top="integer"
        android:right="integer"
        android:bottom="integer" />
    <size
        android:width="integer"
        android:height="integer" />
    <solid
        android:color="color" />
    <stroke
        android:width="integer"
        android:color="color"
        android:dashWidth="integer"
        android:dashGap="integer" />
</shape>
```

`android:shape`：图形的形状。

- `rectabgle`：矩形
- `oval`：椭圆
- `line`：横线。必须设置`<stroke>`属性指定直线宽度及颜色
- `ring`：圆环。必须设置`<stroke>`属性指定圆环宽度及颜色

`<corners>`：表示四个圆角的角度，只适合矩形。`android:radius`这个属性的设置优先级低于单独设置各个圆角角度。

`<gradient>`：可以设置渐变效果

- `android:angle`：设置渐变角度。默认为0，且要求值必须为45的倍数，*0表示从左到右，90表示从下到上*
- `android:centerX`：渐变的中心点的X坐标。
- `android:centerY`：渐变的中心点的Y坐标。
- `android:startColor`：渐变的起始色。
- `android:centerColor`：渐变的中间色。
- `android:endColor`：渐变的结束色。
- `android:gradient`：渐变半径。仅当**android:type="radial"**时有效。
- `android:type`：渐变的类型
  - linear：线性渐变
  - radial：径向渐变。类似扩散效果
  - sweep：扫描线渐变。类似雷达效果。

`<padding>`：设置四周空白距离

`<size>`：设置图形的固有大小，但不是最终的大小。*作为View背景时，大小还是跟着View走的*

`<solid>`：设置纯色填充

`<stroke>`：设置描边

| stroke属性        | 作用                       |
| :---------------- | -------------------------- |
| android:width     | 描边的宽度，越大边缘越明显 |
| android:color     | 描边的颜色                 |
| android:dashwidth | 虚线的宽度                 |
| android:dashGap   | 虚线的空隙间隔             |

*如果android:dashWidth或android:dashGap*有任何一个为0，则虚线效果无法生效。

##### 应用代码

```xml
//shpae.xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">

    <solid android:color="#ffffff" />

    <padding
        android:bottom="7dp"
        android:left="7dp"
        android:right="7dp"
        android:top="7dp" />
    <stroke
        android:width="3dp"
        android:color="#FFFF00" />
    <corners
        android:radius="3dp"/>

</shape>

android:background="@drawable/shape"
```

### 4.LayerDrawable

> 表示一种层次性的Drawable集合，通过将不同的Drawable放置在不同的层上面从而达到一种叠加的效果。

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android"
    >
  <item
        android:drawable=""
        android:id="@+id"
        android:left="integer"
        android:right="integer"
        android:top="integer"
        android:bottom="integer" >
  </item>
</layer-list>
```

`android:drawable`：引用的背景资源

`android:id`：层id

`android:top`：layer相对于容器的上边距

`android:bottom`：layer相对于容器的下边距

`android:left`：layer相对于容器的左边距

`android:right`：layer相对于容器的右边距

*Layer-list有层次的概念，下面的item会覆盖上面的item*。

##### 应用代码

```xml
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:drawable="@drawable/red_color"
        android:bottom="10dp"
        android:left="10dp"
        android:right="10dp"
        android:top="10dp"/>
    <item
        android:drawable="@drawable/green_color"
        android:bottom="20dp"
        android:left="20dp"
        android:right="20dp"
        android:top="20dp"/>
    <item
        android:drawable="@drawable/blue_color"
        android:bottom="30dp"
        android:left="30dp"
        android:right="30dp"
        android:top="30dp"/>
</layer-list>

```

![绘制结果](/images/LayerDrawable)

### 5.StateListDrawable

> 对应着`<selector>`标签，也表示Drawable集合，每个Drawable对应着View的一种状态。

```xml
<selector xmlns:android="http://schemas.android.com/apk/res/android"
          android:constantSize="[true | false]"
          android:dither="[true|false]"
          android:variablePadding="[true|false]"
          >
  <item 
        android:drawable=""
        android:state_pressed="[true | false]"
        android:state_focused="[true | false]"
        android:state_selected="[true | false]"
        android:state_hovered="[true | false]"
        android:state_checked="[true | false]"
        android:state_checkable="[true | false]"
        android:state_enabled="[true | false]"
        android:state_activated="[true | false]"
        android:state_window_focused="[true | false]"
        >
  </item>
</selector>
```

`android:constantSize`：固有大小是否不随着其状态的改变而改变。由于状态改变会导致`StateListDrawable`切换到对应的Drawable，导致大小发生变化。

- 设置为 true  固有大小是固定值，就是所有item中的最大值
- 设置为 false  固有大小跟着切换的item发生变化  *默认值*

`android:variblePadding`：`padding`是否随着状态改变而改变

- true `padding`随着状态改变而改变
- false  `padding`是固定值，取内部所有item中padding的最大值   *默认值*

`<item>`

| 状态                   | 含义                               |
| ---------------------- | ---------------------------------- |
| android:state_pressed  | 表示手指按下的状态                 |
| android:state_focused  | 表示获取焦点的状态                 |
| android:state_selected | 表示选中的状态                     |
| android:state_checked  | 表示选中的状态。一般用与`CheckBox` |
| android:state_enabled  | 表示当前可用的状态                 |

##### 应用代码

```xml
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:state_pressed="true"
        android:drawable="@drawable/state_pressed"/>
  <item android:state_focused="true"
        android:drawable="@drawable/state_focused"/>
  <item android:drawable="@drawable/state_normal"/>
</selector>
```

### 6.LevelListDrawable

> 表示一个Drawable集合，集合中的每一个Drawable都有**等级**的概念。

```xml
<level-list xmlns:android="http://schemas.android.com/apk/res/android" >
    <item android:drawable=""
          android:maxLevel="integer"
          android:minLevel="integer"/>
</level-list>
```

`android:maxLevel`：对应的最大值，取值范围为0~10000，默认0 *常用该属性*

`android:minLevel`：对应的最小值，取值范围为0~10000，默认0

使用方法：无论是用xml还是代码实现

- 作为View背景：都需要在Java代码中调用`setLevel()`
- 作为图片前景：需要调用`setImageLevel()`

##### 应用代码

```xml
//level.xml
<?xml version="1.0" encoding="utf-8"?>
<level-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:maxLevel="1" android:drawable="@drawable/image1" />
    <item android:maxLevel="2" android:drawable="@drawable/image2" />
</level-list>

<View android:background="@drawable/level"/>
<ImageView android:src="@drawable/level"/>

// 设置View背景
view.setLevel(1)
//设置ImageView
imageView.setImageLevel(1);

```

> 拓展：ImageView的`android:setBackground`和`android:src`有什么区别？
>
> `android:setBackground`：会根据ImageView控件的宽高去拉伸图片
>
> `android:src`：保持原图大小

### 7.TransitionDrawable

> 表示两个Drawable之间的淡入淡出效果

```xml
<?xml version="1.0" encoding="utf-8"?>
<transition xmlns:android="http://schemas.android.com/apk/res/android">
  <item
        android:drawable=""
        android:id="@+id"
        android:left="integer"
        android:right="integer"
        android:top="integer"
        android:bottom="integer"
        >
  </item>
</transition>
```

##### 应用代码

```xml
// transition.xml
<?xml version="1.0" encoding="utf-8"?>
<transition xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:drawable="@drawable/bg1" />
  <item android:drawable="@drawable/bg2" />
</transition>

<view android:background="@drawable/transition"/>
```

```java
TransitionDrawable drawable = (TransitionDrawable)view.getBackground();
drawable.startTransition(1000); //正向调用
// drawable.reverseTransition(1000);  反向调用
```



### 8.InsetDrawable

> 表示把一个Drawable嵌入到另一个Drawable的内部，并在四周留一些间距

```xml
<?xml version="1.0" encoding="utf-8"?>
<insert xmlns:android="http://schemas.android.com/apk/res/android"
        android:drawable=""
        android:visible="[true | false]"
        android:insertLeft="integer"
        android:insertRight="integer"
        android:insertTop="integer"
        android:insertBottom="integer"
        >
</transition>
```

`android:visible`：是否保留边距。默认保留

##### 应用代码

```xml
<?xml version="1.0" encoding="utf-8"?>
<inset xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable="@drawable/image"
    android:insetBottom="20dp"
    android:insetLeft="20dp"
    android:insetRight="20dp"
    android:insetTop="20dp"
    android:visible="true">
</inset>
```



### 9.ScaleDrawable

> 表示将Drawable缩放到一定比例

```xml
<?xml version="1.0" encoding="utf-8"?>
<scale xmlns:android="http://schemas.android.com/apk/res/android"
        android:drawable=""
        android:scaleWidth="percentage"
        android:scaleHeight="percentage"
        android:scaleGravity="[top | bottom | left | right |
        center_vertical | center_horizontal | center |
        fill_vertical | fill_horizontal | fill |
        clip_vertical | clip_horizontal]"
        >
</scale>
```

`android:scaleGravity`：效果同`android:gravity`

`android:scaleWidth/android:scaleHeight`：指定宽/高缩放比例。以百分比形式展示(`25%`)。

##### 应用代码

```xml
// scale.xml
<?xml version="1.0" encoding="utf-8"?>
<scale xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable="@drawable/drawable_test"
    android:scaleGravity="center"
    android:scaleHeight="70%"
    android:scaleWidth="70%"/>

<ImageView android:background="@drawable/scale"></ImageView>
```

```java
ScaleDrawable scaleDrawable = (ScaleDrawable) imageView.getDrawable();
scaleDrawable.setLevel(1);
```

`setLevel`填值不可以为0，取值范围为`0~10000`，0表示不可见。

### 10.ClipDrawable

> 表示裁剪一个Drawable

```xml
<?xml version="1.0" encoding="utf-8"?>
<clip xmlns:android="http://schemas.android.com/apk/res/android"
        android:drawable=""
        android:clipOrientation="[horizonal | vertical]"
        android:scaleGravity="[top | bottom | left | right |
        center_vertical | center_horizontal | center |
        fill_vertical | fill_horizontal | fill |
        clip_vertical | clip_horizontal]" >
</clip>
```

`android:clipOrientation`：表示裁剪方向 可选值为 `horizonal 水平`，`vertical 竖直`

`android:gravity`：表示对齐方式
|      可选项       |                             含义                             |
| :---------------: | :----------------------------------------------------------: |
|        top        | 放在容器的顶部，不改变大小<br>若为竖直裁剪，则从底部开始裁剪 |
|      bottom       | 放在容器的底部，不改变大小<br/>若为竖直裁剪，则从顶部开始裁剪 |
|       left        | 放在容器的左边，不改变大小<br/>若为水平裁剪，则从右部开始裁剪 |
|       right       | 放在容器的右边，不改变大小<br/>若为水平裁剪，则从左边开始裁剪 |
|  center_vertical  | 放在容器的竖直居中，不改变大小<br/>若为竖直裁剪，则从上下开始裁剪 |
|   fill_vertical   |  竖直方向填充容器<br/>若为竖直裁剪，仅当level为0才开始裁剪   |
| center_horizontal | 放在容器的水平居中，不改变大小<br/>若为水平裁剪，则从左右同时开始裁剪 |
|  fill_horizontal  |  水平方向填充容器<br/>若为水平裁剪，仅当level为0才开始裁剪   |
|      center       | 放在容器的中心，不改变大小<br/>若为竖直裁剪，则从上下开始裁剪<br>若为水平裁剪，则从左右开始裁剪 |
|       fill        | 放在容器的顶部，不改变大小<br/>若为竖直裁剪，则从底部开始裁剪* |
|   clip_vertical   |                       竖直方向进行裁剪                       |
|  clip_horizontal  |                       水平方向进行裁剪                       |

##### 应用代码

```xml
// clip.xml
<?xml version="1.0" encoding="utf-8"?>
<clip xmlns:android="http://schemas.android.com/apk/res/android"
        android:drawable="@drawable/bg1"
        android:clipOrientation="vertical"
        android:scaleGravity="bottom" >
</clip>

<ImageView 
           android:backgrounf="@drawable/clip"/>
```

```java
ClipDrawable clipDrawable = (ClipDrawable) imageView.getDrawable();
clipDrawable.setLevel(5000)

```

`setLevel()`数值范围为`0~10000`，0代表完全裁剪，8000代表裁剪20%

### 11.RotateDrawable

> 表示旋转Drawable

```xml
<?xml version="1.0" encoding="utf-8"?>
<rotate xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable=""
    android:fromDegrees="integer"
    android:pivotX="percentage"
    android:pivotY="percentage"
    android:toDegrees="integer"
    android:visible="[true | false]">
</rotate>
```

`android:fromDegrees` RotateDrawable实例起始角度,大于0是顺时针旋转,小于0是逆时针旋转;
`android:toDegrees` RotateDrawable实例最终角度,大于0是顺时针旋转,小于0是逆时针旋转;
`android:pivotX` RotateDrawable实例旋转中心点X轴坐标相对自身位置;
`android:pivotY` RotateDrawable实例旋转中心点Y轴坐标相对自身位置;

##### 应用代码

```xml
//rotate.xml
<?xml version="1.0" encoding="utf-8"?>
<rotate xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable="@mipmap/rotate_round"
    android:fromDegrees="0"
    android:pivotX="50%"
    android:pivotY="50%"
    android:toDegrees="360"
    android:visible="true">
</rotate>

<view android:background="@drawable/rotate"
```

```java
RotateDrawable rotateDrawable = (RotateDrawable) view.getDrawable();
rotateDrawable.setLevel(5000) //设置旋转角度 0~10000  ==  0~360
```





### 自定义Drawable

![自定义Drawable](/images/Drawable-自定义Drawable.png)

> 需要去复合实现 Drawable 效果。

```java
//自定义Drawable
public class CustomDrawable extends Drawable {
   
    private Paint mPaint;

    public CustomDrawable(int color) {
        mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mPaint.setColor(color);
    }

    @Override
    public void draw(Canvas canvas) {
        final Rect rect =  getBounds();
        float cx = rect.exactCenterX();
        float cy = rect.exactCenterY();
        canvas.drawCircle(cx, cy, Math.min(cx, cy), mPaint);
    }

    @Override
    public void setAlpha(int alpha) {
        mPaint.setAlpha(alpha);
        invalidateSelf();
    }

    @Override
    public void setColorFilter(ColorFilter colorFilter) {
        mPaint.setColorFilter(colorFilter);
        invalidateSelf();
    }

    @Override
    public int getOpacity() {
        return PixelFormat.TRANSLUCENT;
    }
}
```

一般自定义Drawable作为`ImageView的图像或者View的背景去使用`。

需要实现自定义Drawable的话，就必须要实现`draw(),setAlpha(),setColorFilter(),getOpacity()`这几个方法。

如果自定义的Drawable设置了固有大小，最好重写`getInstrinsicWidrh()和getInstrinsicHeight()`，因为会影响到`wrap_content`属性。



### Drawable相关

1. android中的dp、px、dip、sp，dpi相关概念

   `px`：就是像素单位，例如手机分辨率`1080*1920`单位就是px

   `dp`：设备独立像素，不同的设备有不同的效果，在不同的像素密度的设备上会自动适配

   `dpi`：每英寸像素树，有设备决定是固定的。计算方法：`横向分辨率/横向英寸数`

   `sp`：同dp相似，*会根据用户的字体大小偏好进行缩放*

2. Drawable文件过多如何整理

   - 自定义View，实现常用的Drawable属性

   - [参考该库](https://github.com/JavaNoober/BackgroundLibrary) 

     给LayoutInflater添加了一个LayoutInflater.Factory类。而Android的Activity在创建过程（也就是`setContentView`）中实际上是通过把xml转换成View的对象。而LayoutInflater.Factory相当于这中间的一个后门，它是xml解析创建成View的必经方法，google中的v7support包里很多内容就是通过LayoutInflater.Factory来实现向下兼容的。加入一个自定义的LayoutInflater.Factory，去解析添加的自定义属性，



## Drawable原理

![Drawable原理](/images/Drawable-Drawable原理.png)

### Drawable和View的关系

![Drawable-Drawable与View的关系](/images/Drawable-Drawable与View的关系.png)

在`View`执行到`draw过程`时，出现了`Drawable`的身影，在`measure、layout`过程中都不涉及。

```java
//View.java
    public void draw(Canvas canvas) {
      ...
      if (!dirtyOpaque) {
        //绘制背景
            drawBackground(canvas);
        }
      ...
    }

    private void drawBackground(Canvas canvas) {
       final Drawable background = mBackground;
      setBackgroundBounds();
      ...
        background.draw(canvas);
      ...
    }

//设置Drawable的显示区域
    void setBackgroundBounds() {
        if (mBackgroundSizeChanged && mBackground != null) {
            mBackground.setBounds(0, 0, mRight - mLeft, mBottom - mTop);
            mBackgroundSizeChanged = false;
            rebuildOutline();
        }
    }
```

要使用`Drawable`的话，必须调用`setBounds()`否则无法使用，接下来调用`draw()`进行绘制任务。

```java
    public void setBackground(Drawable background) {
        //noinspection deprecation
        setBackgroundDrawable(background);
    }

    public void setBackgroundDrawable(Drawable background) {
      ...
        //销毁原先设置的drawable
        if (mBackground != null) {
            if (isAttachedToWindow()) {
                mBackground.setVisible(false, false);
            }
          //断开连接
            mBackground.setCallback(null);
            unscheduleDrawable(mBackground);
        }
      ...
       if (background != null) {
         //View 与 drawable建立联系
         background.setCallback(this);
         //背景大小发生变化，需要重新布局
            if (mBackground == null
                    || mBackground.getMinimumHeight() != background.getMinimumHeight()
                    || mBackground.getMinimumWidth() != background.getMinimumWidth()) {
                requestLayout = true;
            }
         ...      
       } else {
            mBackground = null;
         //去除背景，需要重新布局
            requestLayout = true;
       }
        if (requestLayout) {
            requestLayout();
        }

        mBackgroundSizeChanged = true;
      //重新绘制
        invalidate(true);
        invalidateOutline();      
    }
```

调用`drawable.setCallback(view)`建立联系

```java
//Drawable.java
    public final void setCallback(@Nullable Callback cb) {
        mCallback = cb != null ? new WeakReference<>(cb) : null;
    }

    public interface Callback {
        //刷新drawable
        void invalidateDrawable(@NonNull Drawable who);
        //执行动画drawable
        void scheduleDrawable(@NonNull Drawable who, @NonNull Runnable what, long when);
        //取消执行动画drawable
        void unscheduleDrawable(@NonNull Drawable who, @NonNull Runnable what);
    }

//触发drawable重绘
    public void invalidateSelf() {
        final Callback callback = getCallback();
        if (callback != null) {
            callback.invalidateDrawable(this);
        }
    }

//View.java
    public void invalidateDrawable(@NonNull Drawable drawable) {
        if (verifyDrawable(drawable)) {
            final Rect dirty = drawable.getDirtyBounds();
            final int scrollX = mScrollX;
            final int scrollY = mScrollY;

            invalidate(dirty.left + scrollX, dirty.top + scrollY,
                    dirty.right + scrollX, dirty.bottom + scrollY);
            rebuildOutline();
        }
    }
```

`setCallback()`将传进去的`View实例`，通过`弱引用`包装起来，防止`Drawable`长时间不释放，导致`内存泄漏`。最好还是不用`drawable`的时候，调用`setCallback(null)`解除引用。

`setCallback()`的主要作用是让`invalidateDrawable()`在`Drawable`发生变化时，及时回调`View.invalidate()`进行重绘。



### Drawable获取

![Drawable-Drawable获取](/images/Drawable-Drawable获取.png)

一般通过`getResources().getDrawable()`根据`drawableId`获取对应Drawable对象。后来添加了`getDrawableForDensity()`，可以根据密度返回对应的Drawable。

```java
//Resource.java    
   public Drawable getDrawable(@DrawableRes int id, @Nullable Theme theme)
            throws NotFoundException {
        return getDrawableForDensity(id, 0, theme);
    }

    public Drawable getDrawableForDensity(@DrawableRes int id, int density, @Nullable Theme theme) {
        final TypedValue value = obtainTempTypedValue();
        try {
            final ResourcesImpl impl = mResourcesImpl;
          //寻找对应drawable-XX下的对应文件，寻找失败，直接抛出异常
            impl.getValueForDensity(id, density, value, true);
            return impl.loadDrawable(this, value, id, density, theme);
        } finally {
            releaseTempTypedValue(value);
        }
    }
```

向下继续调用到`ResourcesImpl.loadDrawable()`

![Drawable-loadDrawable](/images/Drawable-loadDrawable.png)

```java
//ResourcesImpl.java
    Drawable loadDrawable(@NonNull Resources wrapper, @NonNull TypedValue value, int id,
            int density, @Nullable Resources.Theme theme)
            throws NotFoundException {
      //是否使用缓存
      final boolean useCache = density == 0 || value.density == mMetrics.densityDpi;
      
            final boolean isColorDrawable;
            final DrawableCache caches;
            final long key;
            //以 # 开头，可以判断为ColorDrawable
            if (value.type >= TypedValue.TYPE_FIRST_COLOR_INT
                    && value.type <= TypedValue.TYPE_LAST_COLOR_INT) {
                isColorDrawable = true;
                caches = mColorDrawableCache;
                key = value.data;
            } else {
                isColorDrawable = false;
                caches = mDrawableCache;
                key = (((long) value.assetCookie) << 32) | value.data;
            }
            //缓存有效，直接返回缓存
            if (!mPreloading && useCache) {
              //缓存的并非drawable对象 而是ConstantState对象
                final Drawable cachedDrawable = caches.getInstance(key, wrapper, theme);
                if (cachedDrawable != null) {
                    cachedDrawable.setChangingConfigurations(value.changingConfigurations);
                    return cachedDrawable;
                }
            }
           
            final Drawable.ConstantState cs;
            if (isColorDrawable) {
                cs = sPreloadedColorDrawables.get(key);
            } else {
                cs = sPreloadedDrawables[mConfiguration.getLayoutDirection()].get(key);
            }
      
            Drawable dr;
            boolean needsNewDrawableAfterCache = false;
            if (cs != null) {
              //调用子类的 newDrawable生成新的drawable对象
                dr = cs.newDrawable(wrapper);
            } else if (isColorDrawable) {
              //颜色背景 直接返回ColorDrawable
                dr = new ColorDrawable(value.data);
            } else {
              //加载 drawable文件
                dr = loadDrawableForCookie(wrapper, value, id, density);
            }
      
      ...
        //缓存drawable
        cacheDrawable(value, isColorDrawable, caches, theme, canApplyTheme, key, dr);
      ...
      return dr;
    }
```

#### Drawable缓存

##### 写入缓存

最后通过`cacheDrawable()`写入缓存

```java
    private void cacheDrawable(TypedValue value, boolean isColorDrawable, DrawableCache caches,
            Resources.Theme theme, boolean usesTheme, long key, Drawable dr) {
        final Drawable.ConstantState cs = dr.getConstantState();
        if (cs == null) {
            return;
        }

      //提前加载
        if (mPreloading) {
            final int changingConfigs = cs.getChangingConfigurations();
            if (isColorDrawable) {
                if (verifyPreloadConfig(changingConfigs, 0, value.resourceId, "drawable")) {
                    sPreloadedColorDrawables.put(key, cs);//缓存的为ConstantState
                }
            } else {
                if (verifyPreloadConfig(
                        changingConfigs, ActivityInfo.CONFIG_LAYOUT_DIRECTION, value.resourceId, "drawable")) {
                    if ((changingConfigs & ActivityInfo.CONFIG_LAYOUT_DIRECTION) == 0) {
                        sPreloadedDrawables[0].put(key, cs);
                        sPreloadedDrawables[1].put(key, cs);
                    } else {
                        sPreloadedDrawables[mConfiguration.getLayoutDirection()].put(key, cs);
                    }
                }
            }
        } else {
            synchronized (mAccessLock) {
                caches.put(key, theme, cs, usesTheme);
            }
        }
    }
```

根据上述源码，实际缓存的不是`Drawable`，而是`Drawable.ConstantState`对象

`caches`指的就是`DrawableCache`，由这个类负责`Drawable缓存`的处理

```java
class DrawableCache extends ThemedResourceCache<Drawable.ConstantState> {
  ...
}

abstract class ThemeResourceCache<T> {
  //设置Theme的Drawable.ConstantState 
    private ArrayMap<ThemeKey, LongSparseArray<WeakReference<T>>> mThemedEntries;
  //未设置Theme的Drawable.ConstantState
    private LongSparseArray<WeakReference<T>> mUnthemedEntries;
  //无Theme的Drawable.ConstantState
    private LongSparseArray<WeakReference<T>> mNullThemedEntries;
  
      public void put(long key, @Nullable Theme theme, @NonNull T entry, boolean usesTheme) {
        if (entry == null) {
            return;
        }

        synchronized (this) {
            final LongSparseArray<WeakReference<T>> entries;
            if (!usesTheme) {
                entries = getUnthemedLocked(true);
            } else {
                entries = getThemedLocked(theme, true);
            }
            if (entries != null) {
                entries.put(key, new WeakReference<>(entry));
            }
        }
    }
  
  //懒加载，只会使用的时候进行初始化
      private LongSparseArray<WeakReference<T>> getUnthemedLocked(boolean create) {
        if (mUnthemedEntries == null && create) {
            mUnthemedEntries = new LongSparseArray<>(1);
        }
        return mUnthemedEntries;
    }

}
```

`写入缓存`——实质缓存的是`ConstantState`

##### 读取缓存

在缓存有效时，即`caches.getInstance()`不返回null

```java
    public Drawable getInstance(long key, Resources resources, Resources.Theme theme) {
        final Drawable.ConstantState entry = get(key, theme);
        if (entry != null) {
          //由ConstantState重新构建Drawable对象
            return entry.newDrawable(resources, theme);
        }

        return null;
    }
```

`读取缓存`——实质从缓存中读取的是`ConstantState`

#### Drawable.ConstantState

![Drawable-ConstantState](/images/Drawable-ConstantState.png)

> `ConstantState`是一个抽象类，具体的实现都交由`Drawable`的子类实现。 

```java
public static abstract class ConstantState {
  // Creates a new Drawable instance from its constant state.
        public abstract @NonNull Drawable newDrawable();
  // Creates a new Drawable instance from its constant state using the specified resources
        public @NonNull Drawable newDrawable(@Nullable Resources res) {
            return newDrawable();
        }
  // Creates a new Drawable instance from its constant state using the specified resources and theme
        public @NonNull Drawable newDrawable(@Nullable Resources res,
                @Nullable @SuppressWarnings("unused") Theme theme) {
            return newDrawable(res);
        }
 // eturn a bit mask of configuration changes that will impact this drawable
        public abstract @Config int getChangingConfigurations();
 // Return whether this constant state can have a theme applied
        public boolean canApplyTheme() {
            return false;
        }
    }
```

`ConstantState`的具体实现类都交由`Drawable`的子类实现，就拿常用的`BitmapDrawable`示例。*一般`getResources().getDrawable()`获取的也是这个对象。*

```java
public class BitmapDrawable extends Drawable {
  //自定义继承了 ConstantState 的类
   private BitmapState mBitmapState; 
  //构造函数
   public BitmapDrawable() {
        init(new BitmapState((Bitmap) null), null);
    }
  
   public BitmapDrawable(Resources res) {
        init(new BitmapState((Bitmap) null), res);
    }
  
  ...
    final static class BitmapState extends ConstantState {
        final Paint mPaint;

        // The density to use when looking up the bitmap in Resources. A value of 0 means use
        // the system's density.
        int mSrcDensityOverride = 0;

        // The density at which to render the bitmap.
        int mTargetDensity = DisplayMetrics.DENSITY_DEFAULT;

        boolean mAutoMirrored = false;

        @Config int mChangingConfigurations;
        boolean mRebuildShader;

        BitmapState(Bitmap bitmap) {
            mBitmap = bitmap;
            mPaint = new Paint(DEFAULT_PAINT_FLAGS);
        }

        BitmapState(BitmapState bitmapState) {
            mBitmap = bitmapState.mBitmap;
            mTint = bitmapState.mTint;
            mTintMode = bitmapState.mTintMode;
            mThemeAttrs = bitmapState.mThemeAttrs;
            mChangingConfigurations = bitmapState.mChangingConfigurations;
            mGravity = bitmapState.mGravity;
            mTileModeX = bitmapState.mTileModeX;
            mTileModeY = bitmapState.mTileModeY;
            mSrcDensityOverride = bitmapState.mSrcDensityOverride;
            mTargetDensity = bitmapState.mTargetDensity;
            mBaseAlpha = bitmapState.mBaseAlpha;
            mPaint = new Paint(bitmapState.mPaint);
            mRebuildShader = bitmapState.mRebuildShader;
            mAutoMirrored = bitmapState.mAutoMirrored;
        }

        @Override
        public boolean canApplyTheme() {
            return mThemeAttrs != null || mTint != null && mTint.canApplyTheme();
        }

        @Override
        public Drawable newDrawable() {
            return new BitmapDrawable(this, null);
        }

        @Override
        public Drawable newDrawable(Resources res) {
            return new BitmapDrawable(this, res);
        }

        @Override
        public @Config int getChangingConfigurations() {
            return mChangingConfigurations
                    | (mTint != null ? mTint.getChangingConfigurations() : 0);
        }
    }
  ...
    private void init(BitmapState state, Resources res) {
        mBitmapState = state;
        updateLocalState(res);

        if (mBitmapState != null && res != null) {
            mBitmapState.mTargetDensity = mTargetDensity;
        }
    }    
}
```

无论是从缓存中获取`Drawable`还是通过`newDrawable()`都需要从`ConstantState`开始创建Drawable对象，可以保证内部资源的一致，以达到**资源复用**的目的。*浅拷贝*

![效果图](/images/Drawable-ConstantState关系.jpg)



> `Drawable`共享了状态，一些配置的改变实质改变的是`ConstantState`，就会导致其中一个`Drawable`状态发生了变化，致使其他的`Drawable`变为同一状态。

##### `mutate()`

> 使`Drawable`变得可变，且操作无法还原。**一旦调用无法撤销。**
>
> 主要为了**复制一份`ConstantState`，让`newDrawable()`之后的`Drawable`拥有自己的`ConstantState`，不会受到其他Drawable的干扰**。*深拷贝*

```java
//Drawable.java
    public @NonNull Drawable mutate() {
        return this;
    }

//BitmapDrawable.java
    public Drawable mutate() {
        if (!mMutated && super.mutate() == this) {
            mBitmapState = new BitmapState(mBitmapState);//重新生成ConstanState对象
            mMutated = true;
        }
        return this;
    }
```

![mutate](/images/Drawable.mutate.jpg)

#### Drawable加载

无法获取缓存时，需要区分以下三种情况：

##### `ConstantState`不为null

>  调用缓存得到的`ConstantState.newDrawable()`构造`Drawable`对象



##### 是`ColorDrawable`类型

>  判断是否以`#`开头，是的话直接创建`ColorDrawable`对象。



##### 没有缓存`ConstantState`且非`ColorDrawable`，需要加载

![Drawable-Drawable加载](/images/Drawable-Drawable加载.png)

```java
    private Drawable loadDrawableForCookie(@NonNull Resources wrapper, @NonNull TypedValue value,
            int id, int density) {
      ...
            try {
                if (file.endsWith(".xml")) {//文件以xml结尾 例如自定义xml文件
                    final XmlResourceParser rp = loadXmlResourceParser(
                            file, id, value.assetCookie, "drawable");
                    dr = Drawable.createFromXmlForDensity(wrapper, rp, density, null);
                    rp.close();
                } else {//多为 图片类型，例如jpg、png啥的
                    final InputStream is = mAssets.openNonAsset(
                            value.assetCookie, file, AssetManager.ACCESS_STREAMING);
                    AssetInputStream ais = (AssetInputStream) is;
                    dr = decodeImageDrawable(ais, wrapper, value);
                }
            } finally {
                stack.pop();
            }      
      ...
    }
```

###### xml加载

```java
//Drawable.java
    public static Drawable createFromXmlForDensity(@NonNull Resources r,
            @NonNull XmlPullParser parser, int density, @Nullable Theme theme)
            throws XmlPullParserException, IOException {
        AttributeSet attrs = Xml.asAttributeSet(parser);
      ...
        //根据xml开始解析drawable
        Drawable drawable = createFromXmlInnerForDensity(r, parser, attrs, density, theme);

        return drawable;
    }

    static Drawable createFromXmlInnerForDensity(@NonNull Resources r,
            @NonNull XmlPullParser parser, @NonNull AttributeSet attrs, int density,
            @Nullable Theme theme) throws XmlPullParserException, IOException {
      //调用 DrawableInflater 加载对应<tag>
        return r.getDrawableInflater().inflateFromXmlForDensity(parser.getName(), parser, attrs,
                density, theme);
    }
```

```java
//Resources.java
    public final DrawableInflater getDrawableInflater() {
        if (mDrawableInflater == null) {
            mDrawableInflater = new DrawableInflater(this, mClassLoader);
        }
        return mDrawableInflater;
    }
```

```java
//DrawableInflater.java
Drawable inflateFromXmlForDensity(@NonNull String name, @NonNull XmlPullParser parser,
            @NonNull AttributeSet attrs, int density, @Nullable Theme theme)
            throws XmlPullParserException, IOException {
        //<drawable class="XXX"></drawable>
        if (name.equals("drawable")) {
            name = attrs.getAttributeValue(null, "class");
            if (name == null) {
                throw new InflateException("<drawable> tag must specify class attribute");
            }
        }
        //常用的tag 例如<shape></shape>
        Drawable drawable = inflateFromTag(name);
        if (drawable == null) {
          //自定义Drawable <CustomDrawable></CustomDrawable>
            drawable = inflateFromClass(name);
        }
        drawable.setSrcDensityOverride(density);
        drawable.inflate(mRes, parser, attrs, theme);
        return drawable;
    }

//根据不同的tag转为指定的子类
    private Drawable inflateFromTag(@NonNull String name) {
        switch (name) {
            case "selector":
                return new StateListDrawable();
            case "animated-selector":
                return new AnimatedStateListDrawable();
            case "level-list":
                return new LevelListDrawable();
            case "layer-list":
                return new LayerDrawable();
            case "transition":
                return new TransitionDrawable();
            case "ripple":
                return new RippleDrawable();
            case "adaptive-icon":
                return new AdaptiveIconDrawable();
            case "color":
                return new ColorDrawable();
            case "shape":
                return new GradientDrawable();
            case "vector":
                return new VectorDrawable();
            case "animated-vector":
                return new AnimatedVectorDrawable();
            case "scale":
                return new ScaleDrawable();
            case "clip":
                return new ClipDrawable();
            case "rotate":
                return new RotateDrawable();
            case "animated-rotate":
                return new AnimatedRotateDrawable();
            case "animation-list":
                return new AnimationDrawable();
            case "inset":
                return new InsetDrawable();
            case "bitmap":
                return new BitmapDrawable();
            case "nine-patch":
                return new NinePatchDrawable();
            case "animated-image":
                return new AnimatedImageDrawable();
            default:
                return null;
        }
    }

    @NonNull
    private Drawable inflateFromClass(@NonNull String className) {
        try {
            Constructor<? extends Drawable> constructor;
            synchronized (CONSTRUCTOR_MAP) {
                constructor = CONSTRUCTOR_MAP.get(className);
                if (constructor == null) {
                    final Class<? extends Drawable> clazz =
                            mClassLoader.loadClass(className).asSubclass(Drawable.class);
                  //反射调用Drawable构造函数
                    constructor = clazz.getConstructor();
                    CONSTRUCTOR_MAP.put(className, constructor);
                }
            }
            return constructor.newInstance();
        } 
      ...
    }
```

`Drawable.inflateFromXmlForDensity()`按照不同格式的`xml`分为三种加载方式：

- `<drawable class="CustonmDrawable">...</drawable>`

  从`<drawable>`读取`class`参数，得到`CustomDrawable`，向下调用到`inflateFromClass()`



- `<shape>...</shape>`

  根据`<tag>`对应的属性，调用`inflateFromTag()`新建具体的`Drawable`对象



- `<CustomDrawable>...</CustomDrawable>`

  直接调用`inflateFromClass()`加载`CustomDrawable`类



###### 图片文件加载

```java
//ResourcesImpl.java
    private Drawable decodeImageDrawable(@NonNull AssetInputStream ais,
            @NonNull Resources wrapper, @NonNull TypedValue value) {
        ImageDecoder.Source src = new ImageDecoder.AssetInputStreamSource(ais,
                            wrapper, value);
        try {
            return ImageDecoder.decodeDrawable(src, (decoder, info, s) -> {
                decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE);
            });
        } catch (IOException ioe) {
            // This is okay. This may be something that ImageDecoder does not
            // support, like SVG.
            return null;
        }
    }

//ImageDecoder.java
    public static Drawable decodeDrawable(@NonNull Source src,
            @Nullable OnHeaderDecodedListener listener) throws IOException {
        Bitmap bitmap = decodeBitmap(src, listener);
        return new BitmapDrawable(src.getResources(), bitmap);
    }

```

图片加载后，转换为`BitmapDrawable`对象。



#### 总结

![Drawable加载过程](/images/Draw加载过程.jpg)



### Drawable状态

在某些场景下`Drawable`需要切换不同的显示，例如`<selector></selector>`，需要根据View不同的状态切换显示。

![Drawable-Drawable状态](/images/Drawable-Drawable状态.png)

#### View的状态

常见的有以下几种：

| 状态名称   | 对应属性                        | 含义                                               |
| ---------- | ------------------------------- | -------------------------------------------------- |
| `pressed`  | `<attr android:state_pressed>`  | 是否处于按下状态，一般通过按压表现                 |
| `enabled`  | `<attr android:state_enabled>`  | 是否可以点击，通过`setEnabled()`控制               |
| `focused`  | `<attr android:state_focused>`  | 是否处于聚焦状态，一般由按键操作引起                |
| `selected` | `<attr android:state_selected>` | 是否处于选择状态，通过`setSelected()`控制          |
| `checked`  | `<attr android:state_checked>`  | 是否处于选中状态，多用于`CheckBox`之类可以选择控件 |



#### Drawable跟随View状态切换

拿上面调用的`setSelected()`举例

```java
//View.java
    public void setSelected(boolean selected) {
        //noinspection DoubleNegation
        if (((mPrivateFlags & PFLAG_SELECTED) != 0) != selected) {
          //刷新View
            invalidate(true);
          //刷新Drawable的状态
            refreshDrawableState();
            dispatchSetSelected(selected);
        }
    }

    public void refreshDrawableState() {
        mPrivateFlags |= PFLAG_DRAWABLE_STATE_DIRTY;
        drawableStateChanged();

        ViewParent parent = mParent;
        if (parent != null) {
            parent.childDrawableStateChanged(this);
        }
    }

    protected void drawableStateChanged() {
      //获取不同状态对应的Drawable属性
        final int[] state = getDrawableState();
        boolean changed = false;

        final Drawable bg = mBackground;
        if (bg != null && bg.isStateful()) {
            changed |= bg.setState(state);
        }
      ...
    }
```

```java
//Drawable.java
    public boolean setState(@NonNull final int[] stateSet) {
        if (!Arrays.equals(mStateSet, stateSet)) {
            mStateSet = stateSet;
          //通知状态发生了变化
            return onStateChange(stateSet);
        }
        return false;
    }

    protected boolean onStateChange(int[] state) {
        return false;
    }
   //是否状态可变
    public boolean isStateful() {
        return false;
    }
```

`onStateChange()`交由子类实现。其中支持状态切换的子类，比如`ColorDrawable、BitmapDrawable、StateListDrawable`

```java
//StateListDrawable.java
    protected boolean onStateChange(int[] stateSet) {
        final boolean changed = super.onStateChange(stateSet);

        int idx = mStateListState.indexOfStateSet(stateSet);
        if (idx < 0) {
            idx = mStateListState.indexOfStateSet(StateSet.WILD_CARD);
        }

        return selectDrawable(idx) || changed;
    }


     //寻找第一个符合 state 的索引
        int indexOfStateSet(int[] stateSet) {
            final int[][] stateSets = mStateSets;
            final int N = getChildCount();
            for (int i = 0; i < N; i++) {
                if (StateSet.stateSetMatches(stateSets[i], stateSet)) {
                    return i;
                }
            }
            return -1;
        }

    public boolean selectDrawable(int index) {
      ...
         if (index >= 0 && index < mDrawableContainerState.mNumChildren) {
           //获取 对应索引的 Drawable
            final Drawable d = mDrawableContainerState.getChild(index);
           //记录当前显示的Drawable
            mCurrDrawable = d;
            mCurIndex = index;
            if (d != null) {
                if (mDrawableContainerState.mEnterFadeDuration > 0) {
                    mEnterAnimationEnd = now + mDrawableContainerState.mEnterFadeDuration;
                }
                initializeDrawableForDisplay(d);
            }
        } else {
            mCurrDrawable = null;
            mCurIndex = -1;
        }  
      //设置完毕 刷新自己
      invalidateSelf();
      ...
    }
```

当View的状态发生改变时，都会调用到`refreshDrawableList()`更新成对应状态的Drawable对象。



### Drawable着色

![Drawable-Drawable着色](/images/Drawable-Drawable着色.png)

Android需要做效果切换时，大多数都是UI提供多张效果图，可以在不同的效果进行切换。其实大多数情况下，只是切换图片颜色即可满足要求。

此时涉及`Drawable着色`。

```java
        ColorStateList state = ColorStateList.valueOf(Color.parseColor("#5a8386"));
        view.setBackgroundTintList(state);
        view.setBackgroundTintMode(PorterDuff.Mode.ADD);
```



主要涉及的是两个方法：

- `View.setBackgroundTintList()`：设置着色配置

  需要设置`setBackgroundTintList()`必须设置`background`才可以生效

- `View.setBackgroundTintMode()`：设置叠加模式

  系统提供如下叠加模式`PorterDuff.Mode`

  ![img](/images/原图与叠加图.jpg)

  Alpha合成模式

  ![img](/images/Alpha混合模式.jpg)

  混合模式

  ![img](/images/混合模式.jpg)



```java
//View.java
    public void setBackgroundTintList(@Nullable ColorStateList tint) {
        if (mBackgroundTint == null) {
            mBackgroundTint = new TintInfo();
        }
        mBackgroundTint.mTintList = tint;
        mBackgroundTint.mHasTintList = true;

        applyBackgroundTint();
    }

    private void applyBackgroundTint() {
        if (mBackground != null && mBackgroundTint != null) {
            final TintInfo tintInfo = mBackgroundTint;
            if (tintInfo.mHasTintList || tintInfo.mHasTintMode) {
                mBackground = mBackground.mutate();
              //是否设置TintList
                if (tintInfo.mHasTintList) {
                    mBackground.setTintList(tintInfo.mTintList);
                }
              //是否设置TintMode
                if (tintInfo.mHasTintMode) {
                    mBackground.setTintMode(tintInfo.mTintMode);
                }

              //是否可变
                if (mBackground.isStateful()) {
                    mBackground.setState(getDrawableState());
                }
            }
        }
    }
```

转调到`Drawable.setTintList()`和`Drawable.setTintMode()`

```java
//Drawable.java
    public void setTint(@ColorInt int tintColor) {
        setTintList(ColorStateList.valueOf(tintColor));
    }

    public void setTintList(@Nullable ColorStateList tint) {}
```

其中`setTintList()`交由子类实现

```java
//ColorDrawable.java
    @Override
    public void setTintList(ColorStateList tint) {
        mColorState.mTint = tint;
        mTintFilter = updateTintFilter(mTintFilter, tint, mColorState.mTintMode);
        invalidateSelf();
    }

    @Override
    public void setTintMode(Mode tintMode) {
        mColorState.mTintMode = tintMode;
        mTintFilter = updateTintFilter(mTintFilter, mColorState.mTint, tintMode);
        invalidateSelf();
    }

//Drawable.java
    @Nullable PorterDuffColorFilter updateTintFilter(@Nullable PorterDuffColorFilter tintFilter,
            @Nullable ColorStateList tint, @Nullable PorterDuff.Mode tintMode) {
        if (tint == null || tintMode == null) {
            return null;
        }

        final int color = tint.getColorForState(getState(), Color.TRANSPARENT);
        if (tintFilter == null) {
            return new PorterDuffColorFilter(color, tintMode);
        }

        tintFilter.setColor(color);
        tintFilter.setMode(tintMode);
        return tintFilter;
    }

//ColorDrawable.java
    public void draw(Canvas canvas) {
        final ColorFilter colorFilter = mPaint.getColorFilter();
        if ((mColorState.mUseColor >>> 24) != 0 || colorFilter != null || mTintFilter != null) {
            if (colorFilter == null) {
                mPaint.setColorFilter(mTintFilter);
            }
         ...
        }
    }
```



> View通过`setTintList()和setTintMode()`设置`Drawable`，配置完成后生成对应的`PorterDuffColorFilter`在`draw()`设置到对应的`paint`属性。
>
> **实质操作的是`Paint.setColorFilter()`**



## Drawable动画

![Drawable动画](/images/Drawable-Drawable动画.png)

基础的就是`AnimationDrawable`，通过一个接一个的加载一系列的Drawable来创建一个动画，将他们按照顺序播放。

```xml
<animation-list xmlns:android="http://schemas.android.com/apk/res/android"
    android:oneshot="true"> 
    <item android:drawable="@drawable/rocket_thrust1" android:duration="200" />
    <item android:drawable="@drawable/rocket_thrust2" android:duration="200" />
    <item android:drawable="@drawable/rocket_thrust3" android:duration="200" />
</animation-list>
```

```java
//AnimationDrawable.java
    public void run() {
      //不断执行下一帧展示
        nextFrame(false);
    }

    private void nextFrame(boolean unschedule) {
        int nextFrame = mCurFrame + 1;
        final int numFrames = mAnimationState.getChildCount();
        final boolean isLastFrame = mAnimationState.mOneShot && nextFrame >= (numFrames - 1);

        // Loop if necessary. One-shot animations should never hit this case.
        if (!mAnimationState.mOneShot && nextFrame >= numFrames) {
            nextFrame = 0;
        }

        setFrame(nextFrame, unschedule, !isLastFrame);
    }

    private void setFrame(int frame, boolean unschedule, boolean animate) {
        if (frame >= mAnimationState.getChildCount()) {
            return;
        }
        mAnimating = animate;
        mCurFrame = frame;
        selectDrawable(frame);
        if (unschedule || animate) {
            unscheduleSelf(this);
        }
        if (animate) {
            // Unscheduling may have clobbered these values; restore them
            mCurFrame = frame;
            mRunning = true;
            scheduleSelf(this, SystemClock.uptimeMillis() + mAnimationState.mDurations[frame]);
        }
    }

//Drawable.java
    public void scheduleSelf(@NonNull Runnable what, long when) {
        final Callback callback = getCallback();
        if (callback != null) {
          //回调到View的scheduleDrawable
            callback.scheduleDrawable(this, what, when);
        }
    }

```



### 自定义Drawable动画

![Drawable-自定义动画Drawable](/images/Drawable-自定义动画Drawable.png)

使用`AnimationDrawable`支持的都是`帧动画`类型，需要耗费大量的资源去进行每一帧的渲染，如果是一些简单的动效可以通过`自定义Drawable动画`去实现。

#### 实现Animatable接口

```java
public interface Animatable {
 //开始动画
    void start();
 //结束动画 
    void stop();
 //动画是否正在运行
    boolean isRunning();
}
```

后续还添加了`Animateble2`接口

```java
public interface Animatable2 extends Animatable {
  //注册动画监听
    void registerAnimationCallback(@NonNull AnimationCallback callback);
 //取消注册动画监听
    boolean unregisterAnimationCallback(@NonNull AnimationCallback callback);
 // 清除动画监听
    void clearAnimationCallbacks();

    public static abstract class AnimationCallback {
       //动画开始
        public void onAnimationStart(Drawable drawable) {};
       //动画结束
        public void onAnimationEnd(Drawable drawable) {};
    }
}

```

#### 自定义Drawable

```java
public class CircleAnimDrawable extends Drawable implements Animatable {
    @Override
    public void draw(@NonNull Canvas canvas) {
//主要绘制逻辑
    }

    @Override
    public void setAlpha(int alpha) {
//设置透明度
    }

    @Override
    public void setColorFilter(@Nullable ColorFilter colorFilter) {
//设置滤镜
    }

    @Override
  //返回是否透明
    public int getOpacity() {
        return PixelFormat.TRANSLUCENT;
    }

    @Override
    public void start() {
//开始动画
    }

    @Override
    public void stop() {
//结束动画
    }

    @Override
    public boolean isRunning() {
      //动画是否正在执行
        return false;
    }
}
```

现在需要实现一个`不断扩散的圆形动画,扩散到一定大小后消失，并开始循环播放`。这个时候就可以利用到`ValueAnimator`实现功能。

实现实例

```java
public class CircleAnimDrawable extends Drawable implements Animatable {
    int width = 0, height = 0;
    int center = 0;
    float radius = 0f;
    float maxRadius = 0f;
    Paint mPaint;
    private  ValueAnimator valueAnimator;//属性动画，负责提供百分比数值

    public CircleAnimDrawable() {
      //画笔配置
        mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mPaint.setColor(Color.parseColor("#1BA8FB"));
        mPaint.setStyle(Paint.Style.STROKE);
        mPaint.setStrokeWidth(5);
    }

    @Override
    public void draw(@NonNull Canvas canvas) {
      //根据radius 以及 paint属性 重绘
        canvas.drawCircle(center, center, radius, mPaint);
    }

    @Override
    public void setAlpha(int alpha) {
        mPaint.setAlpha(alpha);
    }

    @Override
    public void setColorFilter(@Nullable ColorFilter colorFilter) {
        mPaint.setColorFilter(colorFilter);
    }

    @Override
    public int getOpacity() {
        return PixelFormat.TRANSLUCENT;
    }

    @Override
    public void start() {
        if (valueAnimator != null) {
          //启动动画
            valueAnimator.start();
        }
    }

    @Override
    public void stop() {
        if (valueAnimator != null && valueAnimator.isRunning()) {
          //停止动画
            valueAnimator.end();
        }
    }

    @Override
    public boolean isRunning() {
        return valueAnimator != null && valueAnimator.isRunning();
    }

    @Override
    protected void onBoundsChange(Rect bounds) {
        super.onBoundsChange(bounds);
        center = getBounds().width() >> 1;
        maxRadius = getBounds().width() >> 1;
      //属性动画配置
        valueAnimator = ValueAnimator.ofFloat(0, 1f);
        valueAnimator.setRepeatCount(1);
        valueAnimator.setRepeatMode(ValueAnimator.RESTART);
        valueAnimator.setDuration(1000);
        valueAnimator.addUpdateListener(new ValueAnimator.AnimatorUpdateListener() {
            @Override
            public void onAnimationUpdate(ValueAnimator animation) {
              //根据动画执行位置 获取百分比
                float percent = (float) animation.getAnimatedValue();
                radius = maxRadius * percent;
                mPaint.setAlpha( (255-(int)(255*percent)));
              //重绘View
                invalidateSelf();
            }
        });
    }

    @Override
    public boolean setVisible(boolean visible, boolean restart) {
        boolean changed = super.setVisible(visible, restart);
        if (visible) {
            start();
        } else if (changed) {
          //不可见时 停止动画
            stop();
        }
        return changed;
    }
}
```





## 拓展

### View、Bitmap与Drawable的区别

`Bitmap`：位图信息的存储，存储每个像素信息。

`View`：Android系统的核心，主要有两个作用：`draw`绘制，`测量`

`Drawable`：存储的是对`Canvas`的一系列操作，但是仅仅支持绘制。`Drawable`和`Bitmap`通过`BitmapDrawable`建立联系，储存的是`把Bitmap绘制到Canvas这一操作`。

```java
//BitmapDrawable.java
//构造函数支持输入 Bitmap
    public BitmapDrawable(Resources res, Bitmap bitmap) {
        init(new BitmapState(bitmap), res);
    }

//文件路径转换为Bitmap
    public BitmapDrawable(Resources res, String filepath) {
        Bitmap bitmap = null;
        try (FileInputStream stream = new FileInputStream(filepath)) {
            bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(res, stream),
                    (decoder, info, src) -> {
                decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE);
            });
        } catch (Exception e) {
            /*  do nothing. This matches the behavior of BitmapFactory.decodeFile()
                If the exception happened on decode, mBitmapState.mBitmap will be null.
            */
        } finally {
            init(new BitmapState(bitmap), res);
            if (mBitmapState.mBitmap == null) {
                android.util.Log.w("BitmapDrawable", "BitmapDrawable cannot decode " + filepath);
            }
        }
    }

//从BitmapState获取 Bitmap对象
    public final Bitmap getBitmap() {
        return mBitmapState.mBitmap;
    }
```

通过`BitmapDrawable`建立起`Drawable`和`Bitmap`的关联。



## 参考链接

[PorterDuff.Mode](https://developer.android.google.cn/reference/android/graphics/PorterDuff.Mode?hl=en)

[Paint详解](https://hencoder.com/ui-1-2/)
