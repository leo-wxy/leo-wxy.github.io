---
title: Android-动画分析
date: 2018-06-11 09:39:17
tags: Android
top: 10
---

> Android的动画就可以分为3种：
>
> - View动画 `View Animation`
> - 帧动画 `Drawable Animation`
> - 属性动画 `Property Animation`

## 1.View动画

> View动画的作用对象是View。**View动画的View移动只是视觉效果，并不能真正的改变位置。**

### View动画的种类

| 种类       | 标签          | 子类               | 效果             |
| ---------- | ------------- | ------------------ | ---------------- |
| 平移动画   | `<translate>` | TranslateAnimation | 平移View         |
| 缩放动画   | `<scale>`     | ScaleAnimation     | 放大或者缩小View |
| 旋转动画   | `<rotate>`    | RotateAnimation    | 旋转View         |
| 透明度动画 | `<alpha>`     | AlphaAnimation     | View的透明度变化 |

### 使用View动画

要使用View动画，需要先创建动画的XML文件，这个文件的路径为`res/anim/animateFile.xml`。

```xml
<?xml version="1.0" encoding="utf-8"?>
<set xmlns:android="http://schemas.android.com/apk/res/android"
    android:interpolator=""
    android:shareInterpolator="[true | false]"
    android:fillAfter="true"
    android:duration='integar'>
    
    <translate
        android:fromXDelta="float"
        android:toXDelta="float"
        android:fromYDelta="float"
        android:toYDelta="float"/>
     <scale
        android:fromXScale="float"
        android:toXScale="float"
        android:fromYScale="float"
        android:toYScale="float"
        android:pivotX="float"
        android:pivotY="float"/>    
     <rotate
        android:fromDegrees="float"
        android:toDegrees="float"
        android:pivotY="float"
        android:pivotX="float"/>
    <alpha 
        android:fromAlpha="float"
        android:toAlpha="float"/>

</set>
```

*View动画既可以是单个动画，也可以由一系列动画组成。*

`<set>`：表示动画集合，对应`AnimationSet`，可以包含若干个动画，并且内部也可以嵌套其他动画集合。

- `android:interpolator`：表示动画集合所采用的插值器，插值器会影响到动画的速度。
- `android:shareInterpolator`：是否共享插值器。*如果不指定，子动画就需要单独指定插值器或者使用默认值。*
- `android:fillAfter`：表示动画结束时是否保持动画结束的状态。`false`回到动画初始样式
- `android:integar`：表示动画持续时长

`<translate>`：表示平移动画，对应`TranslateAnimation`

- `android:fromXDelta`：动画起始时X坐标上的位置。
- `android:toXDelta`：动画结束时X坐标上的位置。
- `android:fromYDelta`：动画起始时Y坐标上的位置。
- `android:toYDelta`：动画结束时Y坐标上的位置。

> 以上4个属性的取值可能为`数值，百分数，百分数P`，他们的含义有所区别：
>
> `数值`： 50 --> 以View左上角为原点，向正方向偏移50px
>
> `百分数` 50% --> 以View左上角为原点，向正方向偏移View宽/高的50%
>
> `百分数P` 50%P -> 以View左上角为原点，向正方向偏移父布局(parent)宽/高的50%；

`<scale>`：表示缩放动画，对应`ScaleAnimation`

- `android:fromXScale`动画起始时水平方向伸缩值。 
-  `android:toXScale`：动画结束时水平方向伸缩值。
-  `android:fromYScale`：动画起始时竖直方向伸缩值。
-  `android:toYScale`：动画结束时水平方向伸缩值。

> 以上4个属性的取值有不同的含义
>
> `值为0.0`  缩放比为0  代表缩放到原来的0 即消失
>
> `值<1.0`  缩放比小于1 代表缩小
>
> `值为1.0` 缩放比等于1 代表与原来相同
>
> `值>1.0` 缩放比大于1 代表放大

- `android:pivotX`：缩放轴点的X坐标。
- `android:pivotY`：缩放轴点的Y坐标。

> 以上两个属性表示 ，缩放的起始坐标，**取值为%**，*默认View的中心点，即50%,50%*。举个例子：如果`pivotX和pivotY`设置为0，即为左上角坐标，缩放时就是以左上角为原点向外向内。

`<rotate>`：表示旋转动画，对应`RotateAnimation`

- `android:fromDegrees`：动画起始时旋转的角度 。
- `android:toDegrees`：动画结束时旋转的角度。

> 以上两个属性共同确定旋转方向，原则是：当角度为**负**数时表示**逆时针**旋转，反之。
>
> 故共存在以下四种情况： 
>
> - from=负数 -> to=正数：表示顺时针旋转
> - from=负数 ->to =负数：表示逆时针旋转
> - from=正数 ->to =正数：表示顺时针旋转
> - from=正数 ->to=负数：表示逆时针旋转

- `android:pivotX`：旋转轴点的X坐标。
- `android:pivotY`：旋转轴点的Y坐标。

`<alpha>`：表示透明度动画，对应`AlphaAnimation`

- `android:fromAlpha`：动画起始时透明度。
- `android:toAlpha`动画结束时透明度。

> 以上两个属性取值范围为 0~1
>
> `值<=0` 代表完全透明
>
> `值>=1` 代表完全不透明

### 应用代码

> 通过XML文件构建

```xml
<!-- animationset.xml -->
<?xml version="1.0" encoding="utf-8"?>
<set xmlns:android="http://schemas.android.com/apk/res/android"
    android:shareInterpolator="true" >
    
    <translate
        android:duration="2000"
        android:fromXDelta="0"
        android:fromYDelta="0"
        android:toXDelta="100%"
        android:toYDelta="100%"> />
    <scale
       android:duration="2000"
       android:fromXScale="1.0"
       android:fromYScale="1.0"
       android:pivotX="50%"
       android:pivotY="50%"
       android:toXScale="0.5"
       android:toYScale="0.5" /> 
    <rotate
        android:duration="2000"
        android:fromDegrees="0"
        android:toDegrees="360"
        android:pivotX="50%"
        android:pivotY="50%"/>
     <alpha
       android:duration="2000"
       android:fromAlpha="1.0"
       android:toAlpha="0"/>   
</set>
```

```java
Animation animation = AnimationUtils.loadAnimation(this,R.anim.animationet);
view.startAnimation(animation);
animation.setAnimationListener(new AnimationListener(){
  void onAnimationStart(Animation animation){
    //动画开始
  }
  
  void onAnimationEnd(Animation animation){
    //动画结束
  }
  
  void onAnimationRepeat(Animation animation){
    //动画重复 设置 android:repeatMode="[restart | reverse]" 时触发
  }
})
```

> 通过Java构建

```java
AlphaAnimation alphaAnimation = new AlphaAnimation(1, 0);
alphaAnimation.setDuration(2000);

AnimationSet animationSet = new AnimationSet(true);
animationSet.addAnimation(alphaAnimation);

view.startAnimation(animationSet);
```

### 自定义View动画

> 自定义View动画是为了 实现系统提供的无法满足的动画情况，例如`3D翻转效果`，无法简单组合就能实现，就需要用到自定义View动画。

实现步骤：`继承Animation -> 重写initialize()以及applyTransformation()方法 `

- `inltialize()`：初始化工作
- `allpyTransformation()`：进行相应的矩阵变换

#### 自定义View动画实例

TODO

### View动画特殊使用场景

#### 1. LayoutAnimation

> 作用于ViewGroup，为ViewGroup指定一个动画，当它的子元素出场时都会具有这样的效果。

```xml
<layoutAnimation xmlns:android="http://schemas.android.com/apk/res/android"
                 android:delay=""
                 android:animationOrder=""
                 android:animation="" />                
```

`android:delay`：表示子元素开始动画的延迟时间。

> 比如，设置子元素入场动画的周期为 300ms，delay设置为0.5意味着，每个子元素都需要延迟150ms播放动画

`android:animationOrder` ：表示子元素动画的顺序

- normal 正序显示，按照排列顺序播放
- random 随机显示
- reverse 逆序显示

`android:animation`：表示设置的子元素动画

##### 应用代码

> XML定义

```xml
// anim_layout.xml
<layoutAnimation 
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:animation="@anim/anim_layout_item"
    android:delay="0.5"
    android:animationOrder="normal">
</layoutAnimation>

//anim_layout_item.xml
<set 
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:duration="500"
    android:shareInterpolator="true"
    android:interpolator="@android:anim/accelerate_interpolator">
    <alpha
        android:fromAlpha="0"
        android:toAlpha="1" />
    <scale
        android:fromXScale="1"
        android:toXScale="0" />
</set>

<ListView 
          android:layoutAnimation ="@anim/anim_layout" />
```

> Java代码生成

```java
Animation animation = AnimationUtils.loadLayoutAnimation(this, R.anim.anim_item);
        LayoutAnimationController controller = new LayoutAnimationController(animation);//对应android:animation属性
        controller.setDelay(0.5);//对应android:delay属性      
        controller.setOrder(LayoutAnimationController.ORDER_NORMAL);//对应android:animationOrder属性
        listView.setLayoutAnimation(controller);//对应android:layoutAnimation属性
```



#### 2.Activity切换效果

> Activity有默认的切换效果，是由系统自己定义的。需要自定义切换效果就需要用到`oberridePendingTransition(int inAnim,int outAnim)`

```xml
// enter_anim.xml
<?xml version="1.0" encoding="utf-8"?>  
<set xmlns:android="http://schemas.android.com/apk/res/android"  
        android:interpolator="@android:anim/decelerate_interpolator">  
    <scale android:fromXScale="2.0" android:toXScale="1.0"  
           android:fromYScale="2.0" android:toYScale="1.0"  
           android:pivotX="50%p" android:pivotY="50%p"  
           android:duration="@android:integer/config_mediumAnimTime" />  
</set>  

//exit_anim.xml
<?xml version="1.0" encoding="utf-8"?>  
<set xmlns:android="http://schemas.android.com/apk/res/android"  
        android:interpolator="@android:anim/decelerate_interpolator"  
        android:zAdjustment="top">  
    <scale android:fromXScale="1.0" android:toXScale=".5"  
           android:fromYScale="1.0" android:toYScale=".5"  
           android:pivotX="50%p" android:pivotY="50%p"  
           android:duration="@android:integer/config_mediumAnimTime" />  
    <alpha android:fromAlpha="1.0" android:toAlpha="0"  
            android:duration="@android:integer/config_mediumAnimTime"/>   
</set>  
```



```java
Intent intent =new Intent(this,AnimActivity.class);
startActivityIntent(intent);
overridePendingTransition(R.anim.enter_anim,R.anim.exit_anim);
//退出时设置
finish();
overridePendingTransition(R.anim.enter_anim,R.anim.exit_anim);
```

**该方法必须在`startActivity()`或者`finish()`之后调用才生效。**

## 2.帧动画

> 帧动画是顺序播放一组预先定义好的图片，对应`AnimationDrawable`

```xml
<animation-list  xmlns:android="http://schemas.android.com/apk/res/android"
    android:oneshot="[true | false]">
    <item android:drawable="" android:duration="intreger"/>
</animation-list>
```

`android:oneshot`：表示是否播放一次

### 应用代码

> XML方式

```xml
// animationlist.xml
<animation-list  xmlns:android="http://schemas.android.com/apk/res/android"
    android:oneshot="false">
    <item android:drawable="@drawable/bg1" android:duration="500"/>
    <item android:drawable="@drawable/bg2" android:duration="500"/>
    <item android:drawable="@drawable/bg3" android:duration="500"/>
    <item android:drawable="@drawable/bg4" android:duration="500"/>
</animation-list>
```

```java
view.setBackgroundResource(R.drawable.animationlist);
AnimationDrawable animationDrawable = (AnimationDrawable)mView.getBackground();
animationDrawable.start();
```

> Java生成

```java
AnimationDrawable ad = new AnimationDrawable();//1.创建AnimationDrawable对象
    for (int i = 0; i < 4; i++) {//2.添加Drawable对象及其持续时间
        Drawable drawable = getResources().getDrawable(getResources().getIdentifier("bg" + i, "drawable", getPackageName()));
        ad.addFrame(drawable, 500);
    }
    ad.setOneShot(false);//3.设置是否执行一次
    mView.setBackgroundResource(ad);//4.将帧动画作为view背景
    ad.start();//5.播放动画
```

**使用帧动画时要注意不能使用尺寸过大的图片。否则容易造成OOM错误**

### 优化内存占用

> 由于图片全部是从xml中读取的，一定要全部读取下来动画才可以开始，因为要不断地替换图片去实现动画效果。一次性取出所有图片，就容易导致OOM

优化思路：**一次只取一个图片，开启一个线程去取下一张，达到一致的效果。**

## 3.属性动画

{% post_link Android动画-属性动画%}