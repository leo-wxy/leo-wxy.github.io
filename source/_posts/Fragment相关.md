---
title: Fragment相关
date: 2018-01-10 11:52:04
tags: Android
top: 10
---

<!--Activity和Fragment数据交互 Fragment初始化参数调用哪个方法？ Fragment懒加载怎么实现？Fragment重叠问题-->

> Android中展示界面一般是通过`Activity`去实现的，当要实现类似商城类的首页时，就会拿出`Fragment`去实现对应的每个标签页，由`Activity`进行管理。

## Fragment介绍

`Fragment`存在必须依附于`FragmentActivity`使用，并且与`FragmentActivity`一样，拥有自己独立生命周期，同时可以处理用户的交互动作。并且可以在一个`Activity`中动态的添加、替换，移除不同的`Fragment`，同样`Fragment`也可以拥有多个子`Fragment`并对他们进行控制，对于信息的显示有很大的便利性。

## Fragment使用方式

### Fragment初始化

默认提供两种初始化方式：

- `new XXFragment()`

  ```java 
  DemoFragment fragment = new DemoFragment()
  ```

- `xml 引入`

  ```xml
  <fragment
            android:layout_width="match_parent"
            android:layout_height="match_parent"
            class="com.demo.fragment.DemoFragment"/>
  ```

主流使用的是第一种方法，但是并不是推荐的标准用法，如果需要有参数传入的情况下。

在`Fragment`中添加`newInstance()`，然后方法里面传入参数，以后获取Fragment就调用该方法，不要使用`new`方法。

```java DemoFragment.java
public static DemoFragment newInstance(Bundle args) {
    DemoFragment f = new DemoFragment();
    f.setArguments(args);
    return f;
}
```

```java DemoActivity.java
Bundle args = new Bundle();
args.putString(text,Hello);
MyFragment f = MyFragment.newInstance(args)
```

补充建议：

- 不要依赖带参构造函数传值，进程重建后系统只保证无参构造 + arguments恢复。
- 运行期参数统一走`newInstance() + setArguments()`，可减少重建后状态丢失问题。

> Fragment会被重新销毁(可能因为内存不足、手机发生了配置变化)，重新创建时会默认调用无参构造函数。
>
> 通过`setArguments()`传递的Bundle也会被保留下来。

### 操作Fragment

```java
//获取FragmentManager对象 这是Activity方式
FragmentManager fragmentManager = getSupportFragmentManager();

//从Fragment中获取 FragmentManager
FragmentManager fragmentManager = getChildFragmentManager()
//开启事务，通过 FragmentTransaction 进行add()、remove()等操作
FragmentTransaction ft = fragmentManager.beginTransaction();
//添加Fragment
ft.add(R.id.fragment,DemoFragment.newInstance());
//提交事务
ft.commit();
```

涉及到了以下类：

`FragmentManager`

在Activity通过`getSupportManager`获取该对象，在`Fragment`中通过`getChildFragmentManager()`获取

`FragmentTransaction`：Fragment操作事务

通过`beginTransaction()`开启事务，事务开启后就可以对`Fragment`进行操作

以下为几种常用的操作方法：

`add()`：添加Fragment到Activity或Fragment中

`hide()/show()`：隐藏和显示Fragment

`remove()`：移除指定Fragment

`replace()`：内部实质是调用`remove()`和`add()`完成Fragment修改过程

`addToBackStack()`：添加当前Fragment到回退栈中，当按下返回键时可以根据回退栈进行操作

`commit()`：提交事务，对Fragment进行操作后都需要`commit()`完成提交后可以生效

`commitAllowingStateLoss()`：也是提交事务的一种，但是不会在其中抛出异常，只是跳过了检测`mStateSaved`是否进行了保存

补充：三种提交方式的边界。

- `commit()`：异步入队，绝大多数场景优先使用。
- `commitNow()`：立即执行，不能配合`addToBackStack()`，适合初始化阶段。
- `commitAllowingStateLoss()`：仅在可接受状态丢失的非关键场景使用，不建议常态化替代`commit()`。

> 确保`commit()`在`Activity.onPostResume()`或者`FragmentActivity.onResumeFragments()`内调用，而且不要随意使用`commitAllowingStateLoss()`进行代替，不能滥用该方法。因为忽略状态丢失，Activity意外崩溃时就无法还原之前保存的数据。

添加Fragment有两种方法：

通过`replace()`

```java
ft.replace(R.id.fragment,DemoFragment.newInstance())
```

通过`add()`配合`show()、hide()`

```java
ft.add(R.id.fragment,DemoFragment.newInstance());
//显示时调用
ft.show();
//显示其他Fragment时调用
ft.hide()
```

> `replace()`不会保留Fragment的状态，会销毁视图并重新加载，调用时保存的数据都会消失。
>
> `hide()/show()`只是对Fragment进行隐藏/显示，不会影响存储的数据

## Fragment生命周期

{% fullimage /images/Fragment生命周期.png,Fragment生命周期,Fragment生命周期%}

`onAttach()`：Fragment和Activity绑定时调用。**Fragment附加到Activity之后，无法再次调用`setArguments()`**

`onCreate()`：此时可以获取到`setArguments()`传递过来的参数，通过Bundle获取

`onCreateView()`：在Fragment加载布局时调用

```java
 public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        return inflater.inflate(getLayoutResId(), container, false/*不要把View主动添加到container,这个是自动关联的*/);
}

```

`onActivityCreated()`：当Activity的`onCreate()`执行完成后调用

`onDestoryView()`：Fragment中布局被移除时调用

`onDetach()`：Fragmen和Activity解绑时调用

补充：Fragment生命周期与View生命周期需要分开看。

- Fragment实例可能仍在，但View可能已在`onDestroyView()`后销毁。
- 持有ViewBinding/控件引用时，建议在`onDestroyView()`中置空，避免泄漏。
- 观察UI数据优先使用`viewLifecycleOwner`，避免View销毁后继续回调。



其中还有一个`setRetainInstance()`当调用到该方法时，在Actiivity重新创建时可以完全不销毁`Fragment`，以便Fragment中恢复数据。调用了

`setRetainInstance(true)`后，Fragment恢复时就会跳过`onCreate()`、`onDestroy()`生命周期回调，因此在使用该方法时，`onCreate()`中不要做初始化逻辑。

版本建议：`setRetainInstance(true)`在新版本Fragment库中已不推荐继续使用，跨重建保留数据更建议用`ViewModel + SavedStateHandle`。

> 当因为设备配置发生变化时，`FragmentManager`首先销毁队列中的fragment的视图，接着`FragmentManager`会检查`Fragment`中的`retainInstance`属性，如果为false，直接销毁Fragment实例；若设置为true，fragment的视图会被销毁，但fragment本身不会被销毁，处于短暂的保留状态。当Activity需要时会对其进行恢复。

## Fragment通信

### Fragment与Activity通信

1. 如果Activity中包含自己管理的Fragment的引用，可以通过该引用直接访问所有public方法

2. Activity中未保存任何Fragment的引用，通过给每个Fragment设置`Tag或ID`，后面通过调用`FragmentManager.findFragmentByTag()或FragmentManager.findFragmentById()`获取对应Fragment实例

3. 在Fragment通过`getActivity()`获取Activity实例，然后执行操作。

   通过`getActivity()`获取Activity实例，可能会返回`null`导致异常。该方法返回结果只会在`onAttach()`及`onDetach()`会非空，其他时候都有可能为空，所以可以先使用`getContext()`去进行替代，这样比较安全。

   还有一种就是定义一个全局变量，当触发`onAttach()`进行赋值，后续调用直接使用该全局变量

   ```java DemoFragment.java
   Context context ;
   @Override
   public void onAttach(Context context){
     super.onAttach(context);
     this.context = context;
   }
   ```

   

4. **使用接口方式(推荐做法)**

   ```java DemoFragment.java
   //Fragment中定义接口
   public interface ShowMsgListener{
           void showMsg(String str);
       }
   private ShowMsgListener msgListener; 
   
   @Override
       public void onAttach(Activity activity) {
           super.onAttach(activity);
           try {
               if(activity!=null){
                   //获取Activity中实现的接口
                   msgListener=(DemoActivity)activity;
               }
           } catch (ClassCastException e) {
               throw new ClassCastException(activity.toString()
                       + " must implement showMsgListener");
           }
       }
   
   //调用接口
   msgListener.showMsg("From fragment")；
   ```

   ```java DemoActivity.java
   public DemoActivity extends FragmentActivity implements ShowMsgListener{
     @Override
     public void showMsg(String str){
       //拿来做事
     }
   }
   ```

5. Fragment从Activity获取数据



### Fragment与Fragment通信

> Fragment之间的通信需要通过Activity进行关联，不应该是直接的进行通信。

实现通信步骤主要有以下三步：

1. 定义接口
2. Activity实现接口
3. 在接口方法中Activity调用对应Fragment

## Fragment常见问题

### Fragment重叠

当`宿主Activity`因为被系统回收或者配置发生改变导致销毁重建时，会重新执行`onCreate()`，就有可能重新执行一次`Fragment`创建过程，然后又会新建一个`Fragment`。

```java DemoActivity.java
@Override
public void onCreate(Bundle savedInstanceState){
  super.onCreate(savedInstanceState);
  setContentView(R.layout.act_demo);
  FragmentManager fm = getSupportFragmentManager();
  FragmentTransaction ft = fm.beginTransaction();
  DemoFragment demoFragment;
  
  //可能触发 内存重启
  if(savedInstanceState!=null){
    List<Fragment> fragmentList = getSupportFragmentManager().getFragments();
    for(Fragment fragment : fragmentList){
      if(fragment instanceof DemoFragment)
      	demoFragment = (DemoFragment)fragment
    }
    //直接显示已存在的fragment
    ft.show(demoFragment).commit();
  }else{
    demoFragment = DemoFragment.newInstance();
    ft.add(R.id.fragment,demoFragment);
    ft.commit();
  }
}
```

补充：重建后`FragmentManager`会自动恢复已存在Fragment，`onCreate()`里要避免无条件`add()`。

- 常用判重：`savedInstanceState == null`时才首次`add()`。
- 或使用`findFragmentByTag()/findFragmentById()`判断是否已存在。

### Fragment懒加载

> 懒加载：只在要使用时才去加载数据，而不是在初始化时就加载完毕。

在加载数据前需要先判断三种状态：

- 数据是否已经加载过
- Fragment是否已经调用到`onCreate()`
- 界面对于用户是否可见



### Fragment.startActivityForResult()

#### Fragment启动，Activity获取结果

```java DemoFragment.java
getActivity().startActivityForResult(...)
```

```java DemoActivity.java
@Override
public void onActivityResult(int requestCode,int resultCode,Intent data){
  super.onActivityResult(requestCode,resultCode,data);
}
```



#### Fragment启动，Fragment获取结果

```java DemoFragment.java
startActivityForResult()
  
@Override
public void onActivityResult(int requestCode,int resultCode,Intent data){
  super.onActivityResult(requestCode,resultCode,data);
}
```

```java DemoActivity.java
@Override
public void onActivityResult(int requestCode,int resultCode,Intent data){
  super.onActivityResult(requestCode,resultCode,data);
}
```

> 要求父Activity必须覆写了`onActivityResult()`且调用了`super.onActivityResult()`。

补充：`startActivityForResult/onActivityResult`在新API中逐步弱化，推荐迁移到`Activity Result API`或`FragmentResult API`。

### Fragment配合ViewPager使用

一般类似资讯类、新闻类App首页都会分成多个标签，在不同的标签会有不同的内容，这个时候就需要配合ViewPager来实现内容展示，关键在于对应的fragment是否需要进行销毁。

可用的Adapter分为两种：

- `FragmentPagerAdapter`：对于不再需要的fragment，选择调用`detach()`，仅销毁视图并不会销毁fragment实例。
- `FragmentStatePagerAdapter`：再切换不同fragment的时候，会把前面的fragment进行销毁，但是在系统销毁前，会存储其Fragment的Bundle，倒是需要重新创建Fragment时，可以从`onSaveInstanceState()`获取保存的数据。

使用`FragmentStatePagerAdapter`比较省内存，但是销毁重建的过程也是需要时间的，如果页面较少可以使用`FragmentPageAdapter`，很多的话还是推荐`FragmentStatePagerAdapter`。

补充：在`ViewPager2`场景下，通常使用`FragmentStateAdapter`并结合`setMaxLifecycle()`控制可见页生命周期。

懒加载建议基于`Lifecycle`与可见状态组合判断，不依赖已废弃的可见性回调。
