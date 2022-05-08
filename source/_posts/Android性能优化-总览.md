---
title: Android性能优化
date: 2018-12-20 11:12:25
tags: Android
top: 9
typora-root-url: ../
---

<!--简要解释一下 ANR？为什么会发生 ANR？如何避免发生 ANR？如何定位 ANR？ANR发生条件？如何分析ANR-->

<!--bitmap高效加载，三级缓存等。-->

<!--android性能优化：布局优化、绘制优化、内存泄露优化、bitmap、内存泄露等。-->

<!--内存泄露的概念？android中发生的场景？怎么解决？讲了handler、动画等。-->

<!--Android性能优化工具使用（这个问题建议配合Android中的性能优化）-->

<!--App启动优化，如何检测启动耗时 -->

{% fullimage /images/Android性能优化.png,Android性能优化,Android性能优化%}

针对Android中的性能优化，主要有以下几个有效的优化方法：

> **布局优化、绘制优化、内存泄漏优化、响应速度优化、ListView/RecyclerView及Bitmap优化、线程优化、其他**

## 布局优化

> 核心思想就是：**减少布局文件的层级。**



### 删除布局中无用的控件和层次，其次有选择的使用性能比较低的ViewGroup。

可以使用RelativeLayout来减少嵌套，从而达到减少层级的目的。*如果层级相同的情况，可以使用LinearLayout相比更高效。*

> 如果LinearLayout需要实现`android:weight`那么就需要绘制两次，还是用RelativeLayout好。

<br>

### 采用`<include>、<merge>、ViewStub，Space`优化布局

`<include>`：主要用于布局复用

`<merge>`：一般和`<include>`配合使用，可以减少布局的层级

`ViewStub`：提供了按需加载的功能，提高初始化效率。

`Space`：主要用于进行空白占位，本身`onDraw()`不实现。

{% post_link include、merge-ViewStub相关%}

#### 尽可能少用`wrap_content`

会增加布局测量时的计算成本，应尽可能少用。



### 布局优化工具

#### Hierarchy Viewer

> Android SDK自带的可视化调试工具，用来检查布局嵌套和绘制的时间。

#### Android Lint

> 可以利用其中的 XML布局检查 ，是否出现布局层级问题。

## 绘制优化

> 核心思想是：
>
> - **避免在`View.onDraw()`执行大量操作。**
> - **避免过度绘制**

### `onDraw()`中不要创建新的局部对象

`onDraw()`会被频繁调用，就会在一瞬间产生大量的临时对象，占用过多的内存并且导致系统频繁的发生GC，降低系统的执行效率。

### `onDraw()`不要做耗时的任务或者执行大量的循环操作

Google官方推荐的标准是：**View的绘制帧率保证60fps**。尽量降低`onDraw()`的复杂度可以有效提高帧率。



### 避免过度绘制

> 在屏幕上某个像素在同一帧的时间的被绘制多次。在多层次重叠的UI结构里面，如果不可见的UI也在做绘制的操作，会导致某些像素区被绘制多次，同时也会浪费大量的CPU和GPU资源。

产生这一情况主要有两个原因：

- 在XML布局中，控件有重叠且都设置了背景。
- View的`onDraw()`在同一区域绘制了多次

{% fullimage /images/GPU过度绘制.png,GPU过度绘制,GPU过度绘制%}

#### 过度绘制优化原则

- 一些过度绘制是无法避免的。例如文字和背景导致的过度绘制
- 尽可能将过度绘制控制在2次及以下，原色和蓝色最佳
- 尽可能避免粉色和红色，或者尽可能减少这些区域
- 不允许存在面积超过屏幕1/4区域的3次(`粉色`)及以上过度绘制

#### 过度绘制优化方法

1. 移除默认的Window背景

   > 需要在项目初期就做好，有可能因为某些界面忘记设置背景色，而导致显示了黑色的背景。

2. 移除不必要的背景

   > 例如在ListView中如果设置了ListView的背景色，且Item背景与其一致，就不需要去设置背景了。

3. 优化布局，减少层级

4. 自定义View中，在`onDraw()`利用`clipRect()及quickReject()`进行重叠布局的优化绘制

   > `clipRect()`：设置需要绘制的区域，当某个View的部分区域不可见时，就不进行绘制。
   >
   > `quickReject()`：判断是否和某个矩形相交，跳过相交局域减少绘制层级。

### 应用卡顿

> 在16ms内无法完成界面的渲染、计算和绘制，就会产生丢帧的现象，丢帧就会造成应用的卡顿。

造成应用卡顿的原因主要有以下几点：

- `过度绘制`：加重CPU与GPU渲染压力，导致渲染时间过长。
- `布局嵌套过多`：导致CPU与GPU压力变大
- `动画执行次数过多`：导致CPU与GPU压力变大
- `频繁GC`：执行GC，所有操作需要暂停，GC完成才可以继续操作。阻塞了渲染过程。
- `执行耗时操作`：会阻塞线程

### 绘制性能分析工具

#### Profile GPU Rendering

> 是Android系统提供的开发辅助功能，在屏幕上会显示出彩色的柱状图。

绿色的横线为警戒线，超过这条线就以为着渲染时间超过了16ms。**尽量要保持垂直彩色柱不要超过警戒线。**

#### TraceView

> Android SDK自带的工具，用于对Android的应用程序以及Frtamework层代码进行性能分析。

使用方式：

`在代码中加入调试语句`：在开始监控的地方调用`Debug.startMethodTracing()`，结束监控的地方调用`Debug.stopMethodTracing()`。系统会在SD卡生成trace文件，将trace文件导出SD卡中，通过`traceView`命令对trace文件进行分析。**注意设置内存卡访问权限。**

## 内存优化

### 内存泄漏优化

> `内存泄漏(Memory Leak)`：程序在申请内存后，无法释放已申请的内存空间。是造成应用OOM的主要原因之一。
>
> `内存溢出(out of memory)`：程序在申请内存时，没有足够的内存空间可以使用。

#### `静态变量导致的内存泄漏`

> 一个静态变量又是非静态内部类会一直持有对外部类的引用，导致外部类Activity无法被回收。*例如静态context、静态View*

示例代码：

```java
public class MainActivity extends Activity {
  private static Context context;
  
  @Override
  protected void onCreate(Bundle savedInstanceState){
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_main);
    sContext = this;
  }
}
```

解决方法：可以将内部类设为静态内部类或独立出来；使用`context.getApplicationContext()`。

#### `单例模式导致的内存泄漏`

> 单例传入的参数来自Activity，使得持有对Activity的引用。
>
> **不同生命周期的不要放在一起使用。**

示例代码：

```java
public class SingleInstance {
  private static volatile SingleInstance sInstance;
  private Context context;
  
  private SingleInstance(Context _context){
    this.context = _context;
  }
  
  public SingleInstance getInstance(Context _context){
    if(sInstance==null){
      synchronized(SingleInstance.class){
        if(sInstance==null){
          sInstance= new SingleInstance(_context);
        }
      }
    }
  }
}
```

解决方法：传入的`context`修正成`ApplicationContext`。

#### `属性动画导致的内存泄漏`

> 在Activity中播放无限循环动画且没有在`onDestroy()`中去停止动画，使得View持有了Activity

示例代码：

```java
objectAnimator.setRepeatCount(ValueAnimator.InFINITE);

protected void onDestroy(){
  super.onDestroy();
}
```

解决方法：在`onDestroy()`或其他时机调用`animator.cancel()`及时取消动画。

#### `Handler导致的内存泄漏`

> Handler的`Message`被存储在`MessageQueue`中，有些`Message`并不能马上被处理，就会存在的时间很长。导致Handler无法被回收。
>
> Handler又是非静态的匿名内部类的实例，会隐式持有对外部类Activity的引用，使得引用关系会持续到消息被全部处理，导致内存泄漏。

示例代码：

```java
public class HandlerActivity extends Activity{
  
  @Override 
  protected void onCreate(Bundle savedInstanceState){
    super.onCreate(savedInstanceState);
    setContentView(R.layout.act_handler);
    Button button = findViewById(R.id.btn);
    final Handler mHandler = new Hnadler() {
      @Override
      public void handleMessage(Message msg){
        super.handleMessage(msg);
      }
    }
    btn.setOnClickListener(new View.OnClickListener(){
      @Override
      public void onClick(View v){
        mHandler.sendEmptyMessage(1);
      }
    })
  }
}
```

解决方法：

- `使用静态内部类+WeakReference弱引用`

  ```java
  private static class MyHandler extends Handler {
    private final WeakReference<HandlerActivity> mActivity;
    public MyHandler (HandlerActivity activity){
      mActivity = new WeakReference<HandlerActivity>(activity);
    }
    
    @Oberride
    public void handleMessage(Message msg){
       // do sth
    }
  }
  ```

  

- `外部类生命周期结束时清空消息队列(MessageQueue)`

  ```java
  @Override
  public void onDestroy(){
    if(myHandler!=null){
      myHandler.removeCallbacksAndMessages(null);
    }
    super.onDestroy();
  }
  ```

  

#### `匿名内部类/非静态内部类导致的内存泄漏`

> AsyncTask/Runnable以*匿名内部类*的方式存在，会隐式持有对所在Activity的引用。

![静态内部类](/images/静态内部类比较)

解决方法：

- 将AysncTask和Runnable设置为静态内部类或独立出来；

  ```java
  private static class MyAsyncTask extends AsyncTask<Void,Void,Void>{
    @Override
    protected Void doInBackground(Void... params){
      // do Sth
    }
  }
  ```

  

- 在线程内部采用弱引用保存Context引用

  ```java
  private static class MyThread extends Thread{
    WeakReference<ThreadActivity> mThreadActivity;
    public MyThread(ThreadActivity activity){
      mThreadActivity = new WeakReference<ThreadActivity>(activity);
    }
    @Override
    public void run(){
      super.run();
      if(mThreadActivity == null)
        return;
      if(mThreadActivity.get()!=null){
        mThreadActivity.get().doSth();
      }
    }
  }
  ```

  > 使用静态内部类：切断Activity对于MyTherad的强引用
  >
  > 使用弱引用：切断MyThread对于Activity的强引用。

#### `资源对象没关闭导致的内存泄漏`

> 未及时注销资源导致内存泄漏，例如BroadcastReceiver、File、Cursor、Stream，Bitmap等。*往往都使用了缓冲，会造成内存泄漏。*

解决方法：在Activity销毁的时候需要及时关闭或者注销。还有在资源对象不使用时，一定要确保它们已经关闭并将引用置为null，通常在`finally`执行关闭。

> `BroadcastReceiver`：调用`unregisterReceiver()`
>
> `Cursor、Steam、File`：调用`close()`关闭

### 内存泄漏分析工具

#### MAT分析工具

> 利用DDMS生成堆存储文件，输出文件格式为`hprof`，利用MAT分析堆存储文件。

## 启动优化

{% post_link Android性能优化-启动优化%}



## 响应速度优化

> 核心思想：**避免在主线程中做耗时操作。**

将耗时操作放到线程中去执行，采用异步方式执行耗时操作。

> 如果在主线程中做太多事情，会导致Activity启动时出现黑屏现象，甚至出现**ANR**。
>
> 出现ANR的场景：
>
> - Activity5秒之内无法响应屏幕触摸事件或者键盘输入事件
> - BroadcaseReceiver在*前台广播10秒或后台广播60秒*未处理完操作
> - Service在*前台20秒后台200秒内*内无法执行完`onCreate()`操作

{% post_link ANR分析 %}

## ListView/RecyclerView优化和Bitmap优化

{% post_link ListView简析 %}

{% post_link RecycleView简析 %}

{% post_link Bitmap分析 %}

## 线程优化

> 核心思想：**采用线程池，避免程序中存在大量的Thread。**

线程池中可以重用内部的线程，从而避免了线程的创建和销毁所带来的性能开销，同时线程池还能有效控制线程池的最大并发数，避免大量的线程因为互相抢占系统资源从而导致阻塞现象的发生。

{% post_link Java-线程池 %}

## 其他性能优化建议

- 避免创建过多的对象
- 不要过度使用枚举，枚举占用的内存空间要比整型大（*大概4倍*）
- 常量请使用`static final`进行修饰
- 使用一些Android特有的数据结构，比如`SparseArray`(*减少了自动装箱和拆箱的消耗*)
- 适当使用弱引用和软引用
- 采用内存缓存和磁盘缓存
- 尽量采用静态内部类(*不会持有外部类的实例*)





## 参考链接

[应用启动时间](https://developer.android.com/topic/performance/vitals/launch-time)