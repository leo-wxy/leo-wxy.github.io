---
title: View的事件体系
date: 2018-12-25 10:48:42
tags: Android
top: 9
typora-root-url: ../
---

<!--MeasureSpec是什么？有什么作用？，自定义View/ViewGroup需要注意什么？invalidate()和postInvalidate()的区别？,invalidate和postInvalidate的区别及使用 Requestlayout，onlayout，onDraw，DrawChild区别与联系 View刷新机制 View绘制流程 计算一个view的嵌套层级 onMeasure的具体过程，先measure子view还是自己 onDraw的具体过程，先draw子view还是自己 实现一个自定义view，其中含有若干textview，textview文字可换行且自定义- - view的高度可自适应拓展 view的工作原理及measure、layout、draw流程。哪一个流程可以放在子线程中去执行？draw方法中需要注意的问题？Invalidate、postInvalidate、requestLayout应用场景-->



![View的事件体系](/images/View的事件体系.png)



> 在Android中任何一个与用户交互或者展示内容的控件都是由View拓展实现的。

## View的基础知识

View是Android中所有控件的基类，也包括ViewGroup。ViewGroup可以理解为View的组合，内部可以包含很多View以及ViewGroup，通过这种关系就形成了一个View树。

![ViewTree](/images/View-Tree.png)

上层的控件主要负责测量与绘制下层的控件，并传递交互事件。

### 1. View的位置参数

#### 1.Android坐标系

> 在Android中，将屏幕左上角的顶点作为坐标原点，向右为X轴增大方向，向下为Y轴增大方向

![ViewTree](/images/Android-Position.png)

#### 2.View坐标系

> View的位置由它的四个顶点决定，分别对应View的4个属性：`left(左上角横坐标)、top(左上角纵坐标)、right(右下角横坐标)，bottom(右下角纵坐标)`。
>
> **这些坐标都是相对于View的父容器决定的。**

![](/images/View-Position.png)

```java
Left = getLeft();
Right = getRight();
Top = getTop();
Bottom = getBottom();
width = Right - Left;
height = Bottom - Top;
```

在Android3.0之后添加了几个新参数`x,y,translationX,translationY`。

```java
//X对应左上角横坐标 translationX指代x轴偏移量
x = left + translationX;
//y对应左上角纵坐标 translationY指代y轴偏移量
y = top + translationY;

```

`left是View的初始坐标，不会改变的；x是View偏移后的坐标，偏移后就会发生变化`

Android系统也提供了相应的方法可以直接获取对应参数。但是，不能在初始时就去获取，由于那时View还没有开始绘制，获取的都是0；

如何获取可以参考这个 {% post_link Android-Study-Plan-V %}

### 2.View触控

#### 1.MotionEvent

`MotionEvent`：提供点击事件的事件行为以及事件发生的x,y坐标，典型事件由：

- **ACTION_DOWN**：监听用户手指按下的操作，一次按下标志触摸事件的开始。
- **ACTION_MOVE**：用户按压屏幕后，在抬起之前，如果移动的距离超过一定数值，就判定为移动事件。
- **ACTION_UP**：监听用户手指离开屏幕的操作，一次抬起标志触摸事件的结束。
- **ACTION_CANCEL**：当用户保持按下操作，并把手指移动到了控件外部局域时且父View处理事件触发。

> 事件列：从手指接触屏幕到离开屏幕，产生的一系列事件。
>
> 任何事件列都是**从ACTION_DOWN开始到ACTION_UP结束，中间会穿插着ACTION_MOVE事件**

![View-Touch-Position](/images/View-Touch-Position.png)

```java
getX 以及 getY 返回当前触摸点距离View左上角的x，y坐标 -- 相对坐标
getRawX 以及 getRawY 返回当前触摸点距离整个屏幕的x,y坐标 -- 绝对坐标
```

#### 2.TouchSlop

`TouchSlop`：系统所能识别的被人误是**滑动的最小距离**。当手指在屏幕上滑动时，如果滑动的距离小于这个值，就不会认为在进行滑动操作。

利用`ViewConfiguration.get(getContext()).getScaledTouchSlop()`获取该常亮

#### 3.VelocityTracker

`VelocityTracker`：速度追踪，用于追踪在手指滑动过程中的速度，包括水平和垂直方向的速度

样例演示:

```java
//创建速度追踪对象
VelocityTracker velocityTracker = VelocityTracker.obtain();
velocityTracker.addMovement(event);
//计算速度
velocityTracker.computeCurrentVelocity(1000);
//获取水平速度
float xVelocity = velocityTracker.getXVelocity();
//获取垂直速度
float yVelocity = velocityTracker.getYVelocity();
//重置并回收内存
velocityTracker.clear();
velocityTracker.recycle();
```

#### 4.GestureDetector

`GestureDetector`：手势检测，用于辅助检测用户的单击、滑动、长按，双击等行为。

样例演示：

```java
GestureDetector mGestureDetector = new GestureDetector(this);//实例化一个GestureDetector对象
mGestureDetector.setIsLongpressEnabled(false);// 解决长按屏幕后无法拖动的现象

//接管目标View的onTouchEvent事件
public boolean onTouchEvent(MotionEvent event){
    ...
    boolean consume = mGestureDetector.onTouchEvent(event);
    return consume
}

```



## View的滑动

> Android由于手机屏幕比较小，为了呈现更多的内容就需要滑动来展示。

### 1.使用scrollTo()/scrollBy()

> `scrollTo()`以及`scrollBy()`是由View本身提供的滑动方法。**只对View的内容进行滑动，而不能使View本身滑动。**

```java
    public void scrollTo(int x, int y) {
        if (mScrollX != x || mScrollY != y) {
            int oldX = mScrollX;
            int oldY = mScrollY;
            mScrollX = x;
            mScrollY = y;
            invalidateParentCaches();
            onScrollChanged(mScrollX, mScrollY, oldX, oldY);
            if (!awakenScrollBars()) {
                postInvalidateOnAnimation();
            }
        }
    }

    public void scrollBy(int x, int y) {
        scrollTo(mScrollX + x, mScrollY + y);
    }
```

`scrollTo(x,y)`表示移动到一个具体的坐标点 绝对滑动

`scrollBy(x,y)`表示移动的增量为x,y，即在原有位置上移动x,y的距离 相对滑动

`mScrollX和mScrollY分别表示View在X,Y方向的滚动距离。`

`mScrollX`：View的左边缘减去View的内容的左边缘  **从右向左为正，反之为负**

`mScrollY`：View的上边缘减去View的内容的上边缘  **从下向上为正，反之为负** 

### 2.使用动画

> 通过动画给View增加平移效果。通过改变View自身的`translationX`和`translationY`属性达到滑动效果。

普通动画：新建`translate.xml`动画文件，定义好tranlate属性即可实现滑动动画。

普通动画并不能修改View的位置参数，只是执行了一个动画，实际位置还是初始地方。

属性动画：`ObjectAnimator.ofFloat(view,"translationX",0,300).setDuration(1000).start();`即可实现动画

属性动画真正对View的位置参数进行修改，所以对应时间都是跟随的。

### 3.改变布局参数

> 改变View的`LayoutParams`使得View重新布局。

滑动时，可以对`LaqyoutParams`的`margin`相关参数进行加减就可以实现滑动。

### 4.*弹性滑动

> 上述提到的方案除了动画，滑动都是很生硬的，就是闪烁过去的。所以需要实现弹性滑动(渐进式滑动)。

#### 1. *`Scroller`

使用实例：

```java
Scroller scroller = new Scroller(mContext); //实例化一个Scroller对象

private void smoothScrollTo(int dstX, int dstY) {
  int scrollX = getScrollX();//View的左边缘到其内容左边缘的距离
  int scrollY = getScrollY();//View的上边缘到其内容上边缘的距离
  int deltaX = dstX - scrollX;//x方向滑动的位移量
  int deltaY = dstY - scrollY;//y方向滑动的位移量
  scroller.startScroll(scrollX, scrollY, deltaX, deltaY, 1000); //开始滑动
  invalidate(); //刷新界面
}

@Override//计算一段时间间隔内偏移的距离，并返回是否滚动结束的标记
public void computeScroll() {
  if (scroller.computeScrollOffset()) { 
    scrollTo(scroller.getCurrX(), scroller.getCurY());
    postInvalidate();//通过不断的重绘不断的调用computeScroll方法
  }
}

```

工作原理：

构造`Scroller`对象时，内部没有做什么，只是保存了我们传递的参数

```java
public Scroller(Context context) {
        this(context, null);
    }
public Scroller(Context context, Interpolator interpolator) {
        this(context, interpolator,
                context.getApplicationInfo().targetSdkVersion >= Build.VERSION_CODES.HONEYCOMB);
    }
public Scroller(Context context, Interpolator interpolator, boolean flywheel) {
        mFinished = true;
        if (interpolator == null) {
            mInterpolator = new ViscousFluidInterpolator();
        } else {
            mInterpolator = interpolator;
        }
        mPpi = context.getResources().getDisplayMetrics().density * 160.0f;
        mDeceleration = computeDeceleration(ViewConfiguration.getScrollFriction());
        mFlywheel = flywheel;

        mPhysicalCoeff = computeDeceleration(0.84f); // look and feel tuning
    }
```

保存完参数后，就需要调用`Scroller`的`startScroll()`方法，传入对应参数进行滑动

```java
public void startScroll(int startX, int startY, int dx, int dy, int duration) {
        mMode = SCROLL_MODE;
        mFinished = false;
        //滑动持续时间
        mDuration = duration;
        //滑动开始时间
        mStartTime = AnimationUtils.currentAnimationTimeMillis();
        //滑动起点
        mStartX = startX;
        mStartY = startY;
        //滑动终点
        mFinalX = startX + dx;
        mFinalY = startY + dy;
        //滑动距离
        mDeltaX = dx;
        mDeltaY = dy;
        mDurationReciprocal = 1.0f / (float) mDuration;
    }
```

调用`startScroll()`后，我们调用了`invalidate()`导致View进行了重绘，重绘过程中调用了`draw()`方法，`draw()`中调用了对应的`computeScroll()`方法。`computeScroll()`中又调用了`Scroller`的`computeScrollOffset()`方法，使`Scroller`对应的`mCurrX以及mCurrY`发生变化，配合View自身的`scrollTo()`产生滑动事件。后续继续调用了`postInvalidate()`使View重绘，按照上述流程继续执行，直到动画完成为止。

**关键方法为`startScroll()`及`computeScroll()`**



![Scroller-Process.png](/images/Scroller-Process.png)

总结一下原理：**Scroller并不能使View进行滑动，他需要配合View的computeScroll()方法才能完成滑动效果。在computeScroll()中不断让View进行重绘，每次重绘需要计算滑动持续的时间，根据这个时间计算出应该滑动到的位置，然后调用了View本身的scrollTo()配合位置进行滑动，多次的短距离滑动形成了弹性滑动的效果。**

#### 2. 动画

[动画](#2-使用动画)

#### 3. 延时策略

> 通过发生一系列延时消息而达到一种渐进式的效果，具体可以使用`Handler,View.postDelayed()或者Thread.sleep()`实现

*如果要求精确的话，不建议使用延时策略实现。*

## View的事件分发机制

{%post_link Android-事件分发机制%}



## View的滑动冲突

### 滑动冲突场景

#### 外部滑动和内部滑动方向不一致

*外层ViewGroup是可以横向滑动的，内层View是可以竖向滑动的。*例如：ViewPager嵌套ListView

#### 外部滑动和内部滑动方向一致

*外层ViewGroup是可以竖向滑动的，内层View是也可以竖向滑动的。*例如：ScrollView嵌套ListView

#### 两种情况的嵌套

### 滑动冲突处理规则

#### 内外滑动方向不一致 处理规则

**根据滑动是水平滑动还是竖直滑动来判断由谁来拦截事件。**可以得到滑动过程中两个点的坐标，依据滑动路径与水平方向形成的夹角(`斜率`)判断，或者水平和竖直方向滑动的距离差进行判断。*在ViewPager中当斜率小于0.5时判断为水平滑动。*

#### 内外滑动方向一致 处理规则

一般从业务上找突破点。根据业务需求，规定何时让外部View拦截事件何时由内部View拦截事件。

#### 嵌套滑动 处理规则

滑动规则更复杂，所以还是要从业务代码上下手。

### 滑动冲突解决方案

#### 外部拦截法

> 点击事件都先经过**父容器的拦截处理**，如果父容器需要此事件就拦截，不需要就放行

需要重写父容器的`onInterceptTouchEvent()`，在方法内部做相应的拦截。

```java
public boolean onInterceptTouchEvent(MotionEvent ev){
    boolean intercepted = false;
    int x = (int)ev.getX();
    int y = (int)ev.getY();
    
    switch(ev.getAction()){
        //ACTION_DOWN必须返回false，否则后续事件无法向下传递
        case MotionEvent.ACTION_DOWN:
        intercepted = false;
          break;
        case MotionEvent.ACTION_MOVE:
        if(父容器需要处理该事件){
            intercepted = true;
        }else{
            intercepted = false;
        }
          break;
        //ACTION_UP事件必须返回false，否则子容器无法相应 onClick事件
        case MotionEvent.ACTION_UP:
        intercepted = false;
          break;
        default:
          break;
    }
        return intercepted;
}
```

是否拦截需要在`ACTION_MOVE`中进行判断，父容器需要拦截事件返回true，反之返回false。

#### 内部拦截法

> 父容器不拦截任何事件，所有事件交由子容器进行处理，如果子容器需要就消耗事件，不需要就返给父容器处理。

需要同时重写父容器的`onInterceptTouchEvent()`以及子容器的`dispatchTouchEvent()`。需要配合**`requestDisallowInterceptTouchEvent`**

```java
//子View
public boolean dispatchTouchEvent(MotionEvent ev){
    int x= (int)ev.getX();
    int y= (int)ev.getY();
    
switch(ev.getAction()){
        //ACTION_DOWN必须返回false，否则后续事件无法向下传递
        case MotionEvent.ACTION_DOWN:
            //使父布局跳过所有拦截事件
        	parent.requestDisallowInterceptTouchEvent(true);
         	break;
        case MotionEvent.ACTION_MOVE:
          	int deltaX = x - mLastX;
            int deltaY = y- mLastY ;
    		if(父容器需要处理事件){
        		parent.requestDisallowInterceptTouchEvent(false);
            }
          	break;
        //ACTION_UP事件必须返回false，否则子容器无法相应 onClick事件
        case MotionEvent.ACTION_UP:
        	intercepted = false;
           	break;
        default:
         	break;
    }
    mLastX = x;
    mLastY = y;
    return super.dispatchTouchEvent(ev);
}

//父容器
public boolean onInterceptTouchEvent(MotionEvent event){
    int action = event.getAction();
    if(action == MotionEvent.ACTION_DOWN){
        return false;
    }else{
        return true;
    }
}


```

两种方法相比较而言，`外部拦截法`相比`内部拦截法`实现起来更加简单，而且符合View的事件分发，推荐使用`外部拦截法`。