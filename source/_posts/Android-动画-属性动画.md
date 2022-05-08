---
title: Android动画-属性动画
typora-root-url: ../
date: 2020-10-12 14:28:46
tags: Android
top: 9
---

> 对作用对象进行了扩展，可以对任何对象做动画，甚至可以没有对象。

![属性动画简析xmind](/images/属性动画简析xmind.png)

## 1.与View动画进行比较

- View动画的作用对象`只能是View`，属性动画可以作用于`所有Java对象`
- View动画并没有改变View的属性，只是改变了View的视觉效果，并不具有交互性(*例如：无法响应动画后的点击事件。*)；属性动画是真正的对View的属性进行了修改，可以方便后续的交互操作。
- View动画的效果比较单一，只能实现一些`平移，缩放，旋转等简单动画效果`，复杂的效果可能就需要`自定义View动画`去实现；属性动画拓展性强，可以基本实现所有的动画效果。

## 2.使用属性动画

> 使用XML方式

``` xml
<set
  android:ordering=["together" | "sequentially"]>
    <objectAnimator
        android:propertyName="string"
        android:duration="int"
        android:valueFrom="float | int | color"
        android:valueTo="float | int | color"
        android:startOffset="int"
        android:repeatCount="int"
        android:repeatMode=["repeat" | "reverse"]
        android:valueType=["intType" | "floatType"]/>

    <animator
        android:duration="int"
        android:valueFrom="float | int | color"
        android:valueTo="float | int | color"
        android:startOffset="int"
        android:repeatCount="int"
        android:repeatMode=["repeat" | "reverse"]
        android:valueType=["intType" | "floatType"]/>

</set>
```

`<set>`：表示动画集合，对应`AnimatorSet`

`android:ordering`：表示子动画的播放顺序

- `together`：子动画同时播放
- `sequentially`：子动画按照定义顺序先后播放

### 使用`ObjectAnimator`实现

> XML方式

`<objectAnimator>`：对象动画，对应`ObjectAnimator`

- `android:propertyName`：属性动画作用的属性名称

  | 属性         | 作用                   | 数值类型 |
  | ------------ | ---------------------- | -------- |
  | alpha        | 控制View的透明度       | float    |
  | translationX | 控制View的水平方向位移 | float    |
  | translationY | 控制View的竖直方向位移 | float    |
  | rotation     | 控制View的Z轴旋转度数  | float    |
  | rotationX    | 控制View的X轴旋转度数  | float    |
  | rotationY    | 控制View的Y轴旋转度数  | float    |
  | scaleX       | 控制View的X轴缩放倍数  | float    |
  | scaleY       | 控制View的Y轴缩放倍数  | float    |

- `android:duration`： 动画持续时长。

- `android:startOffset`：设置动画执行之前的等待时长。

- `android:repeatCount`：动画重复执行的次数。

  - 默认为**0**，表示只播放一次。
  - 设置为**-1或infinite**，表示无限重复。

- `android:repeatMode`：动画重复执行的模式。可选值：

  -  **restart**：表示连续重复，为默认值。
  -  **reverse** ：表示逆向重复。

- `android:valueFrom`：动画初始值。

- `android:valueTo`：动画结束值。

- `android:valueType`：动画值类型。可选值：

  - intType：表示属性的类型为 整形
  - floatType：表示属性的类型为浮点型 *默认值*
  - 不设置：如果表示颜色，无需设置

> Java创建

```java
ObjectAnimator mObjectAnimator = ObjectAnimator.ofFloat(view,propertyName/*对应属性操作，可以为任意值*/,float... values/*动画的初始值以及结束值，不定长度*/);

mObjectAnimator.setDuration(duration);
mObjectAnimator.setStartDelay(delay);
mObjectAnimator.setRepeatCount(repeatCount);
mObjectAnimator.setRepeatMode(repeatMode);
mObjectAnimator.start();
```

##### 应用代码

> XML方式

```xml
// objectAnim.xml
<objectAnimator xmlns:android="http://schemas.android.com/apk/res/android"  
    android:valueFrom="1"   // 初始值
    android:valueTo="0"  // 结束值
    android:valueType="floatType"  // 变化值类型 ：floatType & intType
    android:propertyName="alpha" // 对象变化的属性名称

/>
```

```java
// 载入XML动画
Animator animator = AnimatorInflater.loadAnimator(context, R.animator.objectAnim);  
// 设置执行动画对象
animator.setTarget(view);  
animator.start();
```

> Java方式

```java
ObjectAnimator mObjectAnimator = ObjectAnimator.ofFloat(view,"alpha",0,1);

mObjectAnimator.setDuration(1000);
mObjectAnimator.setStartDelay(100);
mObjectAnimator.setRepeatCount(0);
mObjectAnimator.setRepeatMode(ValueAnimator.RESTART);
mObjectAnimator.start();
```



### 使用`ValueAnimator`实现

`<animator>`：对应`ValueAnimator`

相比于`<objectAnimator>`少了一个`android:propertyName`，其他含义相同。

> Java创建

```java
ValueAnimator anim = ValueAnimator.ofInt(int... values);
//ValueAnimator anim = ValueAnimator.ofFloat(float... values);
//ValueAnimator anim = ValueAnimator.ofObject(TypeEvaluator evaluator, Object... values);

anim.setDuration(duration);
anim.setStartDelay(delay);
anim.setRepeatCount(repeatCount);
anim.setRepeatMode(repeatMode);
anim.start();
```

##### 应用代码

```java
ValueAnimator anim = ValueAnimator.ofInt(0, 3);
        // 设置动画运行的时长
        anim.setDuration(500);       
        // 设置动画延迟播放时间
        anim.setStartDelay(500);
        // 设置动画重复播放次数 = 重放次数+1    
        anim.setRepeatCount(0); 
        anim.setRepeatMode(ValueAnimator.RESTART);
        anim.addUpdateLinstener(new ValueAnimator.AnimatorUpdateListener(){
  				@Override
  				public void onAnimationUpdate(ValueAnimator animation){
    				int currentValue = (Integer)animation.getAnimatedValue；
            //在其中对View进行相关属性设置 利用currentValue
              ...
            view.requestLayout();
  				}
				})
        anim.start();
```



### 使用动画集合`AnimatiorSet`实现

> 利用集合类`AnimatorSet`，内部可以随意组合继承`Animator类`的子类，而且可以定制顺序。

##### 应用代码

```java
// 平移动画
ObjectAnimator translation = ObjectAnimator.ofFloat(mButton, "translationX", curTranslationX, 300,curTranslationX);  
// 旋转动画
ObjectAnimator rotate = ObjectAnimator.ofFloat(mButton, "rotation", 0f, 360f);  
// 透明度动画
ObjectAnimator alpha = ObjectAnimator.ofFloat(mButton, "alpha", 1f, 0f, 1f);  

AnimatorSet animSet = new AnimatorSet();  
// 设置动画执行顺序
animSet.play(translation).with(rotate).before(alpha);  
animSet.setDuration(5000);  
animSet.start();
```



### 使用`ViewPropertyAnimator`实现

> 专门针对VIew操作的属性动画，可以直接由view进行调用，相当于一个简单的实现方式。

##### 应用代码

```java
//设置View 透明度以及平移
view.animate().alpha(0).translationX(100).setDuration(500).start(); 
```

### 注意内存泄露

> 在使用属性动画中的无限循环动画(`setRepeatCount(ValueAnimator.INFINITE)`)时，需要在合适的场合(`Activity关闭、View的detach`)取消动画

```java
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if(animator.isRunning()){
          animator.cancel();
        }
    }
```

## 3.理解插值器和估值器

### 1.插值器(`Interpolator`)

> 根据时间流逝的百分比计算出当前属性值改变的百分比。确定了动画效果变化的模式，如匀速变化、加速变化等。

系统内部预置了一些常用的插值器：

- `LinearInterpolator` : 线性插值器 - 匀速运动
- `AccelerateDecelerateInterpolator`：加速减速插值器 - 两头慢中间快
- `DecelerateInterpolator`：减速插值器 - 越来越慢

可以应用的对象：

- View动画： 上文有提到，对应设置属性为`android:interpolator`
- 属性动画：实现*非匀速运动*的方法

自定义插值器：

> 可以高度定制化自己需要的运行轨迹。

实现：需要实现`Interpolator/TimeInterpolator`接口并复写`getInterpolation()`方法。

> 1. 补间动画 实现 `Interpolator`接口；属性动画实现`TimeInterpolator`接口
> 2. `TimeInterpolator`接口是属性动画中新增的，用于兼容`Interpolator`接口，这使得所有过去的`Interpolator`实现类都可以直接在属性动画使用。

接口说明：

```java
public interface TimeInterpolator {    
    float getInterpolation(float input);  
}  

public interface Interpolator extends  TimeInterpolator{  
}

input 变化范围为0~1 
返回值float型的  用于估值器计算的
```



实现示例：*自定义插值器的关键在于`input`根据动画的进度(0%~100%)通过逻辑计算，得到当前属性值改变的百分比。*

```java
public class DecelerateAccelerateInterpolator implements TimeInterpolator {

    @Override
    public float getInterpolation(float input) {
        float result;
        if (input <= 0.5) {
            result = (float) (Math.sin(Math.PI * input)) / 2;
        } else {
            result = (float) (2 - Math.sin(Math.PI * input)) / 2;
        }
        return result;
    }
```



### 2.估值器(`Evaluator`)

> 根据当前属性改变的百分比来计算改变后的属性值

系统提供了一些估值器：

- `IntEvaluator`：整形估值器
- `FloatEvaluator`：浮点型估值器
- `ArgbEvaluator`：Color属性估值器

可以应用的对象：

**属性动画专属**

使用方法：

```java
ValueAnimator anim = ValueAnimator.ofInt(int... values);  //使用的是 IntEvaluator
ValueAnimator anim = ValueAnimator.ofFloat(float... values); //使用的是 FloatEvaluator
ValueAnimator anim = ValueAnimator.ofArgb(int... values);// 使用的是 ArgbEvaluator
//需要自定义 估值器
ValueAnimator anim = ValueAnimator.ofObject(TypeEvaluator evaluator, Object... values);
```



自定义估值器：

> 除了`int,float,color`类型之外的类型做动画，需要用到自定义估值器

接口说明：

```java
public interface TypeEvaluator<T> {
    /**
    * @param fraction   估值小数 插值器的返回值
    * @param startValue 起始值
    * @param endValue   结束值
    */
    public T evaluate(float fraction, T startValue, T endValue);
}
```

实现实例：

先定义自定义对象

```java
class Point {
    // 设置两个变量用于记录坐标的位置
    private float x;
    private float y;

    // 构造方法用于设置坐标
    public Point(float x, float y) {
        this.x = x;
        this.y = y;
    }

    // get方法用于获取坐标
    public float getX() {
        return x;
    }

    public float getY() {
        return y;
    }
}
```

定义估值器

```java
class PointEvaluator implements TypeEvaluator<Point> {

    @Override
    public Point evaluate(float fraction, Point startValue, Point endValue) {
        float x = startValue.getX() + fraction * (endValue.getX() - startValue.getX());
        float y = startValue.getY() + fraction * (endValue.getY() - startValue.getY());
        return new Point(x, y);
    }
}
```

使用估值器

```java
Point startPoint = new Point(100, 100);// 初始点为圆心(100, 100)
Point endPoint = new Point(300, 300);// 结束点为(300, 300)
ValueAnimator anim = ValueAnimator.ofObject(new PointEvaluator(), startPoint, endPoint);
anim.setDuration(5000);
anim.start();
```

## 4.属性动画监听器

> 可以监听属性动画的播放过程，包括`起始，结束，取消，重复`。

```java
public static interface AnimatorListener {
  //动画开始
  void onAnimationStart(Animation animation);
  //动画结束
  void onAnimationEnd(Animation animation);
  //动画取消
  void onAnimationCancel(Animation animation);
  //动画重复
  void onAnimationRepeat(Animation animation);
}

调用方式
animator.addListener(new AnimatorListener(){
 ...
})；
```

拓展：

`AnimatorListenerAdapter`：`AnimatorListener`的适配器类，主要为了解决**实现接口繁琐**的问题。在大多数情况下，我们可能只要监听动画的开始和结束事件。如果直接继承`AnimatorListener`接口，就需要实现额外的方法。

```java
public abstract class AnimatorListenerAdapter implements Animator.AnimatorListener,
        Animator.AnimatorPauseListener {

    @Override
    public void onAnimationCancel(Animator animation) {
    }

    @Override
    public void onAnimationEnd(Animator animation) {
    }

    @Override
    public void onAnimationRepeat(Animator animation) {
    }

    @Override
    public void onAnimationStart(Animator animation) {
    }

    @Override
    public void onAnimationPause(Animator animation) {
    }

    @Override
    public void onAnimationResume(Animator animation) {
    }
}

使用方式
animator.addListener(new AnimatorListenerAdapter(){
    @Override
    public void onAnimationStart(Animator animation) {
      //只实现开始监听
    }
})
```



#### `AnimatorUpdateListener`：监听整个动画过程，每播放一帧，就会回调一次。

```java
public static interface AnimatorUpdateListener {
   void onAnimationUpdate(ValueAnimator animation)；
}
```

利用这个特性，我们可以去对得到的数据进行处理。

上文中，自定义估值器，我们设置了一个`Point`对象，它的动画过程就是`Point`对象内部`x,y`变化的过程，我们就可以利用这个接口实时的去获取内部`x,y`进行操作。利用`ValueAnimator.getAnimatedValue()`就可以获取到对应的对象。

## 5.对任意属性做动画

上文中我们提到`android:propertyName`里面填的就是 属性动画可以支持的属性，假如我们要对View的宽度做动画，应该如何实现？

**属性动画的原理：属性动画要求动画作用的对象必须提供该属性的`get()和set()`方法，属性动画根据外界传递的该属性的初始值和结束值，以动画的效果多次去调用`set()`，每次传入的值不一样，随着时间推移，会越来越接近结束值。**

根据上述原理，我们可以得出一个结果。要想动画生效，必须支持两个条件：

- `Object`必须提供`set()`，如果动画没有传递初始值，那么还要提供`get()`，因为系统要去获取初始值，计算最终值。（*不满足则直接Crash*）
- `Object`设置的`set()`必须可以让View产生变化，比如UI上会发生变化。(*不满足则不会发生变化*)

针对上述条件，可以有3种解决方法：

1. #### 给你的对象加上`get(),set()`，如果你有权限的话

   > 继承原始类，直接给继承类加上`get(),set()`，从而实现给对象加上该属性的`get(),set()`

2. #### 用一个类来包装原始对象，间接提供`get(),set()`

   > 本质上是采用了设计模式中的装饰模式，即通过包装拓展对象的功能。

   示例：一开始就提到了对View的宽度进行动画效果，用这种方案就是找一个类来进行包装。

   ```java
   public class AnimActivity extends Activity {
     ImageView imageView;
     ViewWrapper wrapper;
     
     @Override
       protected void onCreate(Bundle savedInstanceState) {
           super.onCreate(savedInstanceState);
           setContentView(R.layout.activity_main);
           imageView = (ImageView) findViewById(R.id.imageView);        
           // 创建包装类,并传入动画作用的对象
           wrapper = new ViewWrapper(imageView);        
           imageView.setOnClickListener(new View.OnClickListener() {
               @Override
               public void onClick(View v) {
                   ObjectAnimator.ofInt(wrapper, "width"/*对应我们设置的getWidth()和setWidth()*/, 500).setDuration(3000).start();
               }
           });
       }
     
       // 提供ViewWrapper类,用于包装View对象
       private static class ViewWrapper {
           private View mTarget;
   
           // 构造方法:传入需要包装的对象
           public ViewWrapper(View target) {
               mTarget = target;
           }
   
           // 为宽度设置get（） & set（）
           public int getWidth() {
               return mTarget.getLayoutParams().width;
           }
   
           public void setWidth(int width) {
               mTarget.getLayoutParams().width = width;
               //对View重新布局
               mTarget.requestLayout();
           }
       }
   }
   ```

3. #### 采用`ValueAnimator`，监听动画过程，利用返回值动态调整View属性

   > `ValueAnimator`本身不作用于任何对象，直接使用它不会有任何效果。做到的就是对一个View的属性进行变化。在动画过程中修改属性值，就类似于对对象做了动画。

   ```java
   public class AnimActivity extends Activity{
     @Override
     protected void onCreate(Bundle savedInstanceState){
       setContentView(R.layout.main);
       view.post(new Runnable(){
         @Override
         public void run(){
           performAnimator(view,view.getWidth,500);
         }
       })
     }
     
     private void performAnimatior(final View target,final int start,final int end){
       ValueAnimator valueAnimator = ValueAnimator.ofInt(1,100);
       valueAnimator.addUpdateListener(new AnimatorUpdateListener(){
          private IntEvaluator mEvaluator = new IntEvaluator();
          @Override
         public void onAnimationUpdate(ValueAnimator animator){
           int currentValue = (Integer)animator.getAnimatedValue();
           float fraction = animator.getAnimatedFraction();
           target.getLayoutParams().width = mEvaluator.evaluate(fraction,start,end);
           target.requestLayout();
         }
       });
       valueAnimator.setDuration(5000).start();
     }
   }
   ```

## 6.属性动画工作原理

![属性动画执行流程](/images/属性动画执行流程.png)

> 属性动画要求动画作用的对象必须提供该属性的`set()`方法，属性动画就会根据你传递的该属性的初始值和最终值，以动画的效果多次去调用`set()`。每次传递给`set()`的值都不一样，确切的来说是随着时间的推移，传递的值越来越接近最终值。如果动画不提供初始值，那就需要定义`get()`，以供系统去获取初始值。

接下来就从入口处开始分析。



`ObjectAnimator.ofFloat(view,"alpha",0f,1f).start()`意味着动画开始。

```java
// ../android/animation/ObjectAnimator.java
public void start() {
  //如果动画已经执行，则停止动画
  AnimationHandler.getInstace().autoCancelBasedOn(this);
  super.start()
}
```

`super.start()`就调用到父类`ValueAnimator.start()`

### ValueAnimator.start()

> 属性动画执行

```java
// ../android/animation/ValueAnimator.java
public void start(){
  start(false);
}

    private void start(boolean playBackwards) {
        if (Looper.myLooper() == null) {
            throw new AndroidRuntimeException("Animators may only be run on Looper threads");
        }
        mReversing = playBackwards;
        mSelfPulse = !mSuppressSelfPulseRequested;
        // Special case: reversing from seek-to-0 should act as if not seeked at all.
        if (playBackwards && mSeekFraction != -1 && mSeekFraction != 0) {
            if (mRepeatCount == INFINITE) {
                // Calculate the fraction of the current iteration.
                float fraction = (float) (mSeekFraction - Math.floor(mSeekFraction));
                mSeekFraction = 1 - fraction;
            } else {
                mSeekFraction = 1 + mRepeatCount - mSeekFraction;
            }
        }
        mStarted = true;
        mPaused = false;
        mRunning = false;
        mAnimationEndRequested = false;
        mLastFrameTime = -1;
        mFirstFrameTime = -1;
        mStartTime = -1;
        addAnimationCallback(0);

        if (mStartDelay == 0 || mSeekFraction >= 0 || mReversing) {
            startAnimation();//开始动画并回调`onAnimationStart`
            if (mSeekFraction == -1) {
                setCurrentPlayTime(0);
            } else {
                setCurrentFraction(mSeekFraction);
            }
        }
    }
```

#### startAnimation()

> 初始化一些变量以及回调`onAnimationStart()`

```java
    private void startAnimation() {
        ...
        mAnimationEndRequested = false;
        initAnimation();
        mRunning = true;
        if (mSeekFraction >= 0) {
            mOverallFraction = mSeekFraction;
        } else {
            mOverallFraction = 0f;
        }
        if (mListeners != null) {
            notifyStartListeners();
        }
    }

    private void notifyStartListeners() {
        if (mListeners != null && !mStartListenersCalled) {
            ArrayList<AnimatorListener> tmpListeners =
                    (ArrayList<AnimatorListener>) mListeners.clone();
            int numListeners = tmpListeners.size();
            for (int i = 0; i < numListeners; ++i) {
                tmpListeners.get(i).onAnimationStart(this, mReversing);//回调onAnimationStart
            }
        }
        mStartListenersCalled = true;
    }
```



### addAnimationCallback(0)

> 真正执行动画的部分代码

```java
    private void addAnimationCallback(long delay) {
        if (!mSelfPulse) {
            return;
        }
        getAnimationHandler().addAnimationFrameCallback(this, delay);
    }

    public AnimationHandler getAnimationHandler() {
        return AnimationHandler.getInstance();
    }
```

#### addAnimationFrameCallback()

```java
//AnimationHandler.java
    private final Choreographer.FrameCallback mFrameCallback = new Choreographer.FrameCallback() {
        @Override
        public void doFrame(long frameTimeNanos) {
            doAnimationFrame(getProvider().getFrameTime());
            if (mAnimationCallbacks.size() > 0) {//回调为0时候
                getProvider().postFrameCallback(this);//注册下一次的刷新事件监听
            }
        }
    };

    public void addAnimationFrameCallback(final AnimationFrameCallback callback, long delay) {
        if (mAnimationCallbacks.size() == 0) {
            getProvider().postFrameCallback(mFrameCallback);
        }
        if (!mAnimationCallbacks.contains(callback)) {
            mAnimationCallbacks.add(callback);
        }

        if (delay > 0) {
            mDelayedCallbackStartTime.put(callback, (SystemClock.uptimeMillis() + delay));
        }
    }

    private AnimationFrameCallbackProvider getProvider() {
        if (mProvider == null) {
            mProvider = new MyFrameCallbackProvider();
        }
        return mProvider;
    }
```

注册`mFrameCallback`到`Choreographer`的待执行队列里，并向底层注册一个屏幕刷新信号事件`onVsync()`

此时的`mAnimationCallbacks`持有的是`ValueAnimator`集合

#### postFrameCallback()

> 注册监听

```java
//AnimationHandler.java
    private class MyFrameCallbackProvider implements AnimationFrameCallbackProvider {

        final Choreographer mChoreographer = Choreographer.getInstance();

        @Override
        public void postFrameCallback(Choreographer.FrameCallback callback) {
            mChoreographer.postFrameCallback(callback);
        }

        @Override
        public void postCommitCallback(Runnable runnable) {
            mChoreographer.postCallback(Choreographer.CALLBACK_COMMIT, runnable, null);
        }

        @Override
        public long getFrameTime() {
            return mChoreographer.getFrameTime();
        }

        @Override
        public long getFrameDelay() {
            return Choreographer.getFrameDelay();
        }

        @Override
        public void setFrameDelay(long delay) {
            Choreographer.setFrameDelay(delay);
        }
    }
```

`AnimationHandler`通过`Choreographer`向底层注册监听下一个`屏幕刷新信号`，接收到信号时`mFrameCallback`执行，调用`doAnimationFrame()`。如果还有动画未执行完毕，继续注册监听下一个`屏幕刷新信号`。

### Choreographer.postFrameCallback()

> 动画的核心类

```java
//Choreographer.java
    public void postFrameCallback(FrameCallback callback) {
        postFrameCallbackDelayed(callback, 0);
    }

    public void postFrameCallbackDelayed(FrameCallback callback, long delayMillis) {
        if (callback == null) {
            throw new IllegalArgumentException("callback must not be null");
        }

        postCallbackDelayedInternal(CALLBACK_ANIMATION,
                callback, FRAME_CALLBACK_TOKEN, delayMillis);
    }

```

其中`postCallbackDelayedInternal()`内部相关的代码可以参考{% post_link View的刷新机制%}



### AnimationHandler.doAnimationFrame()

> 每次在`Vsync`信号来临时会执行到`doFrame()`对应执行到`doAnimationFrame()`

```java
    private void doAnimationFrame(long frameTime) {
        long currentTime = SystemClock.uptimeMillis();
        final int size = mAnimationCallbacks.size();
        for (int i = 0; i < size; i++) {
            final AnimationFrameCallback callback = mAnimationCallbacks.get(i);
            if (callback == null) {
                continue;
            }
            if (isCallbackDue(callback, currentTime)) {
                callback.doAnimationFrame(frameTime);
                if (mCommitCallbacks.contains(callback)) {
                    getProvider().postCommitCallback(new Runnable() {
                        @Override
                        public void run() {
                            commitAnimationFrame(callback, getProvider().getFrameTime());
                        }
                    });
                }
            }
        }
        cleanUpList();
    }

        @Override
        public void postCommitCallback(Runnable runnable) {
            mChoreographer.postCallback(Choreographer.CALLBACK_COMMIT, runnable, null);
        }
```

#### cleanUpList()

> 清理已经执行完毕的动画

```java
    private void cleanUpList() {
        if (mListDirty) {
            for (int i = mAnimationCallbacks.size() - 1; i >= 0; i--) {
                if (mAnimationCallbacks.get(i) == null) {
                    mAnimationCallbacks.remove(i);
                }
            }
            mListDirty = false;
        }
    }
```



#### ValueAnimator.commitAnimationFrame()

> `callback`有效时，执行对应callback的`commitAnimationFrame()`，此时`callback`为`ValueAnimator`

```java
    public void commitAnimationFrame(long frameTime) {
        if (!mStartTimeCommitted) {
            mStartTimeCommitted = true;
            long adjustment = frameTime - mLastFrameTime;
            if (adjustment > 0) {
                mStartTime += adjustment;
                if (DEBUG) {
                    Log.d(TAG, "Adjusted start time by " + adjustment + " ms: " + toString());
                }
            }
        }
    }
```

**为了修正动画的第一帧时间**

`Choreographer`内部持有多个队列，分别是`CALLBACK_INPUT(输入事件)`、`CALLBACK_ANIMATION(动画事件)`、`CALLBACK_TRAVERSAL(绘制事件)`，`CALLBACK_COMMIT(完成后的提交操作)`。此时`commitAnimationFrame()`执行在`CALLBACK_COMMIT`队列中，位于最后。

当有事件来后，先执行的是`动画事件`，如果页面太复杂，导致绘制时间过长，就可能导致下一个`Vsync`信号到来时，动画执行时会丢失前面几帧，利用`commitAnimationFrame`就可以及时修正第一帧的时间，使动画完整执行。

### ValueAnimator.doAnimationFrame()

> `callback`有效时，执行对应callback的`doAnimationFrame()`，此时`callback`为`ValueAnimator`

```java
//ValueAnimator.java 
public final boolean doAnimationFrame(long frameTime) {
        if (mStartTime < 0) {
            // First frame. If there is start delay, start delay count down will happen *after* this
            // frame.
            mStartTime = mReversing //动画是否反复
                    ? frameTime
                    : frameTime + (long) (mStartDelay * resolveDurationScale());
        }

        // Handle pause/resume
        if (mPaused) {
            mPauseTime = frameTime;
            removeAnimationCallback();
            return false;
        } else if (mResumed) {
            mResumed = false;
            if (mPauseTime > 0) {
                // Offset by the duration that the animation was paused
                mStartTime += (frameTime - mPauseTime);
            }
        }

        //动画尚未执行时
        if (!mRunning) {
            // If not running, that means the animation is in the start delay phase of a forward
            // running animation. In the case of reversing, we want to run start delay in the end.
            if (mStartTime > frameTime && mSeekFraction == -1) {
                // This is when no seek fraction is set during start delay. If developers change the
                // seek fraction during the delay, animation will start from the seeked position
                // right away.
                return false;
            } else {
                // If mRunning is not set by now, that means non-zero start delay,
                // no seeking, not reversing. At this point, start delay has passed.
                mRunning = true;
                startAnimation();//开始动画
            }
        }

        if (mLastFrameTime < 0) {
            if (mSeekFraction >= 0) {
                long seekTime = (long) (getScaledDuration() * mSeekFraction);
                mStartTime = frameTime - seekTime;
                mSeekFraction = -1;
            }
            mStartTimeCommitted = false; // allow start time to be compensated for jank
        }
        mLastFrameTime = frameTime;
        // The frame time might be before the start time during the first frame of
        // an animation.  The "current time" must always be on or after the start
        // time to avoid animating frames at negative time intervals.  In practice, this
        // is very rare and only happens when seeking backwards.
        final long currentTime = Math.max(frameTime, mStartTime);//判断当前动画执行的时间
        boolean finished = animateBasedOnTime(currentTime);//动画是否执行完毕

        if (finished) {
            endAnimation();
        }
        return finished;
    }
```

#### endAnimation()

> 动画执行完毕后的清理工作，并且回调`onAnimationEnd`监听

```java
private void endAnimation() {
        if (mAnimationEndRequested) {
            return;
        }
        removeAnimationCallback();

        mAnimationEndRequested = true;
        mPaused = false;
        boolean notify = (mStarted || mRunning) && mListeners != null;
        if (notify && !mRunning) {
            // If it's not yet running, then start listeners weren't called. Call them now.
            notifyStartListeners();
        }
        mRunning = false;
        mStarted = false;
        mStartListenersCalled = false;
        mLastFrameTime = -1;
        mFirstFrameTime = -1;
        mStartTime = -1;
        if (notify && mListeners != null) {
            ArrayList<AnimatorListener> tmpListeners =
                    (ArrayList<AnimatorListener>) mListeners.clone();
            int numListeners = tmpListeners.size();
            for (int i = 0; i < numListeners; ++i) {
                tmpListeners.get(i).onAnimationEnd(this, mReversing);//回调 onAnimationEnd
            }
        }
        // mReversing needs to be reset *after* notifying the listeners for the end callbacks.
        mReversing = false;
    }

//AnimationHelper.java
//移除动画执行监听
    public void removeCallback(AnimationFrameCallback callback) {
        mCommitCallbacks.remove(callback);
        mDelayedCallbackStartTime.remove(callback);
        int id = mAnimationCallbacks.indexOf(callback);
        if (id >= 0) {
            mAnimationCallbacks.set(id, null);
            mListDirty = true;
        }
    }
```



#### ValueAnimator.animateBasedOnTime()

> 根据当前时间计算并实现当前帧的动画

```java
    boolean animateBasedOnTime(long currentTime) {
        boolean done = false;
        if (mRunning) {
            final long scaledDuration = getScaledDuration();
            final float fraction = scaledDuration > 0 ?
                    (float)(currentTime - mStartTime) / scaledDuration : 1f; 
            final float lastFraction = mOverallFraction;
            final boolean newIteration = (int) fraction > (int) lastFraction;
            final boolean lastIterationFinished = (fraction >= mRepeatCount + 1) &&
                    (mRepeatCount != INFINITE);
            if (scaledDuration == 0) {
                // 0 duration animator, ignore the repeat count and skip to the end
                done = true;
            } else if (newIteration && !lastIterationFinished) {
                // Time to repeat
                if (mListeners != null) {
                    int numListeners = mListeners.size();
                    for (int i = 0; i < numListeners; ++i) {
                        mListeners.get(i).onAnimationRepeat(this);
                    }
                }
            } else if (lastIterationFinished) {
                done = true;
            }
            mOverallFraction = clampFraction(fraction);
            float currentIterationFraction = getCurrentIterationFraction(
                    mOverallFraction, mReversing);
            animateValue(currentIterationFraction);
        }
        return done;
    }
```

##### clampFraction()

> 根据当前时间以及动画第一帧时间还有动画持续的时长来计算当前的动画进度。
>
> 确保动画进度的取值在`0-1`之间。

```java
    private float clampFraction(float fraction) {
        if (fraction < 0) {
            fraction = 0;
        } else if (mRepeatCount != INFINITE) {
            fraction = Math.min(fraction, mRepeatCount + 1);//得到重复执行后的累加进度
        }
        return fraction;
    }

    //保证返回值位于 0-1之间
    private float getCurrentIterationFraction(float fraction, boolean inReverse) {
        fraction = clampFraction(fraction);
        int iteration = getCurrentIteration(fraction);
        float currentFraction = fraction - iteration;
        return shouldPlayBackward(iteration, inReverse) ? 1f - currentFraction : currentFraction;
    }
```



### ValueAnimator.animateValue()

> 前面计算得到当前动画进度后，需要应用该值到View上

```java
    void animateValue(float fraction) {
        fraction = mInterpolator.getInterpolation(fraction);
        mCurrentFraction = fraction;
        int numValues = mValues.length;
        for (int i = 0; i < numValues; ++i) {
            mValues[i].calculateValue(fraction);
        }
        if (mUpdateListeners != null) {
            int numListeners = mUpdateListeners.size();
            for (int i = 0; i < numListeners; ++i) {
                mUpdateListeners.get(i).onAnimationUpdate(this);//通知动画的监听回调
            }
        }
    }
```

#### getInterpolation()

> 根据设置的插值器获取应当达到的进度

### PropertyValuesHolder.calculateValue()

> 根据进度计算最终需要用到的数值

```java
    Keyframes mKeyframes = null; //关键帧   

    void calculateValue(float fraction) {
        Object value = mKeyframes.getValue(fraction);
        mAnimatedValue = mConverter == null ? value : mConverter.convert(value);
    }
```

在执行`ObjectAnimator.start()`之前，需要先执行`ObjectAnimator.ofFloat(float... values)`

```java
//ValueAnimator.java
    public void setFloatValues(float... values) {
        if (values == null || values.length == 0) {
            return;
        }
        if (mValues == null || mValues.length == 0) {
            setValues(PropertyValuesHolder.ofFloat("", values));
        } else {
            PropertyValuesHolder valuesHolder = mValues[0];
            valuesHolder.setFloatValues(values);
        }
        // New property/values/target should cause re-initialization prior to starting
        mInitialized = false;
    }

//PropertyValuesHolder.java
    public void setFloatValues(float... values) {
        mValueType = float.class;
        mKeyframes = KeyframeSet.ofFloat(values);
    }
```

所以`mKeyFrames.getValue(XX)`中的`mKeyFrames`为`KeyframeSet.ofFloat()`

#### KeyframeSet.ofFloat()

> `KeyframeSet`关键帧集合，根据传入的节点，生成`FloatkeyframeSet`

```java
//KeyframeSet.java
    public static KeyframeSet ofFloat(float... values) {
        boolean badValue = false;
        int numKeyframes = values.length;
        FloatKeyframe keyframes[] = new FloatKeyframe[Math.max(numKeyframes,2)];//关键帧集合
        if (numKeyframes == 1) {//只有一个关键帧，生成两个一致的帧
            keyframes[0] = (FloatKeyframe) Keyframe.ofFloat(0f);
            keyframes[1] = (FloatKeyframe) Keyframe.ofFloat(1f, values[0]);
            if (Float.isNaN(values[0])) {
                badValue = true;
            }
        } else {//超过一个关键帧，按照传入数量，生成对应数量的帧集合
            keyframes[0] = (FloatKeyframe) Keyframe.ofFloat(0f, values[0]);
            for (int i = 1; i < numKeyframes; ++i) {
                keyframes[i] =
                        (FloatKeyframe) Keyframe.ofFloat((float) i / (numKeyframes - 1), values[i]);
                if (Float.isNaN(values[i])) {
                    badValue = true;
                }
            }
        }
        if (badValue) {
            Log.w("Animator", "Bad value (NaN) in float animator");
        }
        return new FloatKeyframeSet(keyframes);
    }

```

#### FloatKeyframeSet.getValue()

> 根据当前进度，返回关键帧数值

```java
//FloatKeyframeSet.java
class FloatKeyframeSet extends KeyframeSet implements Keyframes.FloatKeyframes {
    public FloatKeyframeSet(FloatKeyframe... keyframes) {
        super(keyframes);
    }

    @Override
    public Object getValue(float fraction) {
        return getFloatValue(fraction);
    }

   @Override
    public float getFloatValue(float fraction) {
        if (fraction <= 0f) {//初始点
            final FloatKeyframe prevKeyframe = (FloatKeyframe) mKeyframes.get(0);//第一帧
            final FloatKeyframe nextKeyframe = (FloatKeyframe) mKeyframes.get(1);//第二帧
            ...
            return mEvaluator == null ?
                    prevValue + intervalFraction * (nextValue - prevValue) :
                    ((Number)mEvaluator.evaluate(intervalFraction, prevValue, nextValue)).
                            floatValue();
        } else if (fraction >= 1f) {//终点
            final FloatKeyframe prevKeyframe = (FloatKeyframe) mKeyframes.get(mNumKeyframes - 2);//倒数第二帧
            final FloatKeyframe nextKeyframe = (FloatKeyframe) mKeyframes.get(mNumKeyframes - 1);//倒数第一帧
            ...
            return mEvaluator == null ?
                    prevValue + intervalFraction * (nextValue - prevValue) :
                    ((Number)mEvaluator.evaluate(intervalFraction, prevValue, nextValue)).
                            floatValue();
        }
        FloatKeyframe prevKeyframe = (FloatKeyframe) mKeyframes.get(0);
        for (int i = 1; i < mNumKeyframes; ++i) {//其中位置
            FloatKeyframe nextKeyframe = (FloatKeyframe) mKeyframes.get(i);
            if (fraction < nextKeyframe.getFraction()) {
                ...
                return mEvaluator == null ?
                        prevValue + intervalFraction * (nextValue - prevValue) :
                        ((Number)mEvaluator.evaluate(intervalFraction, prevValue, nextValue)).
                            floatValue();
            }
            prevKeyframe = nextKeyframe;
        }
        // shouldn't get here
        return ((Number)mKeyframes.get(mNumKeyframes - 1).getValue()).floatValue();
    }
  
  ...
}
```

`getFloatValue()`根据以下情况返回不同结果：

- `起点`：取出第一和第二帧，得到对应进度
- `终点`：取出倒数第二和第一帧，得到对应进度
- `中间点`：遍历找到输入进度`fraction`位于第一帧和第几关键帧之间，然后计算关键帧转换得到的进度



### ObjectAnimator.animateValue()

> `ValueAnimator`子类`ObjectAnimator`重写了该方法

```java
    void animateValue(float fraction) {
        final Object target = getTarget();
        if (mTarget != null && target == null) {
            // We lost the target reference, cancel and clean up. Note: we allow null target if the
            /// target has never been set.
            cancel();
            return;
        }

        super.animateValue(fraction);
        int numValues = mValues.length;
        for (int i = 0; i < numValues; ++i) {
            mValues[i].setAnimatedValue(target);
        }
    }
```

`super.animaterValue()`指的就是前面的`ValueAnimator.animateValue()`，在计算得到进度之后，`ObjectAnimator`是对对象生效的，接下来

需要将值赋予`target`

#### PropetryValuesHolder.setAnimatedValue()

> 针对`target`进行赋值操作

```java
    void setAnimatedValue(Object target) {
        if (mProperty != null) {
            mProperty.set(target, getAnimatedValue());
        }
        if (mSetter != null) {
            try {
                mTmpValueArray[0] = getAnimatedValue();
                mSetter.invoke(target, mTmpValueArray);
            } catch (InvocationTargetException e) {
                Log.e("PropertyValuesHolder", e.toString());
            } catch (IllegalAccessException e) {
                Log.e("PropertyValuesHolder", e.toString());
            }
        }
    }
```

拿`ObjectAnimator.ofFloat(view,View.SCALE_X,0f,1f)`为例，分析`setAnimatedValue()`执行结果

```java
    void setupSetter(Class targetClass) {
        Class<?> propertyType = mConverter == null ? mValueType : mConverter.getTargetType();
        mSetter = setupSetterOrGetter(targetClass, sSetterPropertyMap, "set", propertyType);
    }

    private Method setupSetterOrGetter(Class targetClass,
            HashMap<Class, HashMap<String, Method>> propertyMapMap,
            String prefix, Class valueType) {
      ...
        setterOrGetter = getPropertyFunction(targetClass, prefix, valueType);
      ...
    }

    private Method getPropertyFunction(Class targetClass, String prefix, Class valueType) {
        Method returnVal = null;
        String methodName = getMethodName(prefix, mPropertyName); //方法名setScaleX() 
        ... //反射获取方法
       
    }
```

> `PropertyValuesHolder`负责**保存动画过程中所需要操作的属性和值**。`ObjectAnimator.ofFloat(Object target,String propertyName.float... values)`内部的参数会被封装成`PropertyValuesHolder`实例。

![属性动画执行过程](/images/属性动画执行过程.jpg)



## 7.View.setXX()

- `alpha`：更改View的不透明度
- `x`、`y`、`translationX`、`translationY`：更改View的位置
- `scaleX`、`scaleY`：更改View的缩放
- `rotation`、`rotationX`、`rotationY`：更改View在3D空间的方向
- `pivotX`、`pivotY`：更改View的转换原点



## 8.参考链接

[源码解读Android属性动画](http://gityuan.com/2015/09/06/android-anaimator-4/)