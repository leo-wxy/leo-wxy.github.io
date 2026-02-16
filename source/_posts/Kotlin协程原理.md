---
title: Kotlin协程原理
date: 2020-09-04 10:15:08
tags: Kotlin
top: 9
typora-root-url: ../
---

在{% post_link Kotlin-协程%}介绍了大部分概念，现在需要针对这些概念进行详细的说明以及分析。

{% blockquote %}
协程是轻量级的线程
{% endblockquote %}

## 阅读地图（按问题定位）

- [1. 协程是什么：概念与术语](#sec-1)
- [2. 协程怎么运行：核心组件与调度](#sec-2)
- [3. 协程怎么用好：构造、启动、取消](#sec-3)
- [4. 协程为什么能挂起：原理实现](#sec-4)
- [5. 知识点总结（可口述）](#sec-5)
- [6. 参考与延伸](#sec-6)

<details>
  <summary>展开子目录（细分知识点）</summary>

  - [协程概念](#sec-1-concept)
  - [概念介绍](#sec-1-terms)
  - [协程与线程的关系（易混点）](#sec-1-thread-vs-coroutine)
  - [协程作用域—CoroutineScope](#sec-2-scope)
  - [协程上下文-CoroutineContext](#sec-2-context)
  - [协程执行任务-Job](#sec-2-job)
  - [协程调度器-CoroutineDispatcher](#sec-2-dispatcher)
  - [调度器与性能（补充）](#sec-2-dispatcher-performance)
  - [协程拦截器-ContinuationInterceptor](#sec-2-interceptor)
  - [协程异常处理-CoroutineExceptionHandler](#sec-2-exception)
  - [异常语义深水区（补充）](#sec-2-exception-deep)
  - [结构化并发决策（补充）](#sec-3-structured)
  - [协程工具选型（launch / async / withContext）](#sec-3-choice)
  - [Flow 体系（Flow / StateFlow / SharedFlow / Channel）](#sec-3-flow)
  - [并发原语（Mutex / Semaphore / Channel / select）](#sec-3-primitives)
  - [协程构造器-CoroutineBuilder](#sec-3-builder)
  - [协程启动模式-CoroutineStart](#sec-3-start)
  - [协程取消-Cancel](#sec-3-cancel)
  - [取消语义深水区（补充）](#sec-3-cancel-deep)
  - [Android 使用建议（工程实践）](#sec-3-android-practice)
  - [常见反模式与修正建议](#sec-3-antipatterns)
  - [Dispatchers原理](#sec-4-dispatcher-principle)
  - [协程启动流程](#sec-4-start-flow)
  - [协程挂起/恢复原理](#sec-4-suspend-resume)
  - [协程并发](#sec-4-concurrency)
  - [测试与可观测性（补充）](#sec-4-test-observability)
  - [协程原理速答（30秒）](#sec-5-principle-30)
  - [协程原理展开（2分钟）](#sec-5-principle-2m)
  - [高频追问知识点（补充）](#sec-5-faq)

</details>

<a id="sec-1"></a>
## 一、协程是什么（概念与术语）

<a id="sec-1-concept"></a>
### 协程概念

> `非抢占式或协作式`的计算机并发调度的实现，程序可以主动挂起或者恢复执行，
>
> 避免在异步程序中使用大量的回调，**使用阻塞的方式写出非阻塞的代码。**

一种全新处理并发的方式，可以在Android平台上简化异步执行的代码。

`协程`主要用来解决两个问题：

- **处理耗时任务**
- **保证主线程安全**

在后面的原理介绍中，会介绍与这两个问题相关的概念。

<a id="sec-1-terms"></a>
### 概念介绍

> 在执行过程中会涉及的一些概念，在后续源码分析也会涉及。

`协程体`

协程中要执行的操作，是一个被`suspend`修饰的`lambda表达式`

`挂起函数`

由`suspend`修饰的函数，只能在`挂起函数`或者`协程体`中调用。可以通过调用其他`挂起函数`挂起执行代码，而不阻塞当前执行线程。

`挂起点`

一般对应`挂起函数`被调用的位置

`续体-Continuation`

挂起的协程在`挂起点`时的状态。概念上表示`挂起点之后的剩余应该执行的代码`。

<a id="sec-1-thread-vs-coroutine"></a>
### 协程与线程的关系（易混点）

协程常被描述为“轻量级线程”，更准确地说：协程是运行在线程之上的任务抽象，线程仍然是最终执行载体。

| 维度 | 线程 | 协程 |
| --- | --- | --- |
| 调度单位 | 操作系统调度 | 用户态（库/运行时）调度 |
| 创建与切换成本 | 相对更高 | 相对更低 |
| 阻塞影响 | 阻塞会占住线程 | 挂起不会阻塞线程 |
| 并发规模 | 数量受限（线程资源） | 可创建大量任务（但不是无限） |
| 生命周期管理 | 需手动管理 | 借助`CoroutineScope`结构化管理 |

补充：

- 协程“轻量”不等于“无成本”，大量协程仍会带来调度和内存开销。
- 协程是否切线程，取决于`CoroutineDispatcher`和挂起点恢复位置。
- 挂起函数是“让出执行权”，不是“停止线程运行”。

<a id="sec-2"></a>
## 二、协程怎么运行（核心组件与调度）

<a id="sec-2-scope"></a>
### 协程作用域—CoroutineScope

> 追踪每一个通过`launch`或`async`创建的协程。并且任何时候都可以通过`scope.cancel()`取消正在执行的协程。
>
> 可以通过`CoroutineScope`控制协程的生命周期，当Activity/Fragment关闭时，调用`cancel()`及时关闭。

`协程作用域`主要有三种：

#### 阻塞协程作用域

调用`runBlocking()`的线程会被阻塞直到内部协程任务执行完毕。

#### 全局协程作用域

`GlobalScope`作用于整个应用生命周期，不会随页面生命周期自动取消。它并非“无法取消”，但如果缺少显式管理，在界面上使用时很容易导致任务泄漏或状态错乱。

```kotlin

 public object GlobalScope : CoroutineScope {  
     // 重写coroutineContext，返回一个空的协程上下文  
     override val coroutineContext: CoroutineContext  
         get() = EmptyCoroutineContext  
 }  
 public interface CoroutineScope {  
     // 协程上下文  
     public val coroutineContext: CoroutineContext  
 }
```



#### 自定义作用域

自定义协程作用域，可以针对性的控制避免内存泄漏。

```kotlin
val coroutineContext : CoroutineContext = Dispatchers.Main + Job()//协程上下文
val coroutineScope = CoroutineScope(coroutineContext)//自定义作用域
```

需要自定义`协程作用域`时，需要构造一个`CoroutineContext`作为参数。

`CoroutineContext`会在下面重点介绍。



##### 内置的自定义作用域

###### MainScope

> 为了方便开发使用，Kotlin标准库提供了`MainScope`用于快速生成`CoroutineScope`

```kotlin
public fun MainScope(): CoroutineScope = ContextScope(SupervisorJob() + Dispatchers.Main)
```



###### viewModelScope

> 在AndroidX中引入的`viewModelScope`，在ViewModel销毁时会自动取消协程任务

```kotlin
val ViewModel.viewModelScope: CoroutineScope
        get() {
            val scope: CoroutineScope? = this.getTag(JOB_KEY)
          //缓存中读取 对应scope
            if (scope != null) {
                return scope
            }
           //对应了ViewModel内部的实现代码
            return setTagIfAbsent(JOB_KEY,
                CloseableCoroutineScope(SupervisorJob() + Dispatchers.Main.immediate))
        }
//自动取消 coroutineScope
internal class CloseableCoroutineScope(context: CoroutineContext) : Closeable, CoroutineScope {
    override val coroutineContext: CoroutineContext = context

    override fun close() {
        coroutineContext.cancel()
    }
}
```



<a id="sec-2-context"></a>
### 协程上下文-CoroutineContext

> 一组定义协程行为的元素，本体是一个数据结构，类似于`Map`，内部实现为`单链表`

由如下几项构成：

- Job：执行的任务
- CoroutineDispatcher：协程调度器
- CoroutineName：协程的名称，主要用于调试
- CoroutineExceptionHandler：处理未被捕获的异常。

```kotlin
public interface CoroutineContext {
    public operator fun <E : Element> get(key: Key<E>): E?

    public fun <R> fold(initial: R, operation: (R, Element) -> R): R

    public operator fun plus(context: CoroutineContext): CoroutineContext =
        //空实现直接返回
        if (context === EmptyCoroutineContext) this else 
           // 遍历context集合
            context.fold(this) { acc, element -> //acc 当前上下文集合 element context集合的元素
                val removed = acc.minusKey(element.key) //移除对应集合的元素
                if (removed === EmptyCoroutineContext) element else { 
                    val interceptor = removed[ContinuationInterceptor] //获取拦截器
                    if (interceptor == null) CombinedContext(removed, element) //生成最后的CombinedContext节点
                  else {
                    //拦截器永远位于 链表尾部
                        val left = removed.minusKey(ContinuationInterceptor)
                        if (left === EmptyCoroutineContext) CombinedContext(element, interceptor) else
                            CombinedContext(CombinedContext(left, element), interceptor)
                    }
                }
            }

    public fun minusKey(key: Key<*>): CoroutineContext

}

```

#### 自定义CoroutineContext

```kotlin
val coroutineContext : CoroutineContext = Dispatchers.Main + Job() + CoroutineName("name")//协程上下文
```

`CoroutineContext`通过`+`进行元素的合并，`+`右侧的元素会覆盖左侧的元素。

`CoroutineContext`存储方式为`左向链表`，链表的每一个节点都是`CombinedContext`，当存在`协程拦截器`时，永远处于链表的最后。

经过上述的`plus`操作后，最后得到一个完整的`CoroutineContext`对象。



#### CoroutineContext的父子关系

> 每个协程都会有一个父对象，协程的父级`CoroutineContext`和父协程的`CoroutineContext`是不一致的。

**父级上下文 = 默认值 + 继承的`CoroutineContext`+参数**

`默认值`：一些元素包含的默认值，例如默认`Dispatcher`就是`Dispatchers.Default`

`继承的CoroutineContext`：父协程的`CoroutineContenxt`

`参数`：后续子协程配置的参数，如上文所示组成部分，新添加的参数会覆盖前面的对应配置。



<a id="sec-2-job"></a>
### 协程执行任务-Job

> 用于处理协程，封装了协程需要执行的代码逻辑，并且负责管理协程的生命周期。
>
> 通过`协程构造器`创建的协程都会返回一个`Job实例`。

主要有以下几种生命周期：

- `New` 新建任务
- `Active` 任务活跃
- `Completing` 任务完成中
- `Cancelling` 任务取消中
- `Cancelled` 任务已取消
- `Completed` 任务已完成



![Job生命周期](/images/Job生命周期.jpg)



`Job`内提供了`isActive()`、`isCancelled()`和`isCompleted()`等属性用于判断协程的状态。

[协程取消](#sec-3-cancel)会更多的分析`Job`相关。



<a id="sec-2-dispatcher"></a>
### 协程调度器-CoroutineDispatcher

> `Dispatchers`是协程中提供的`线程调度器`，用来切换线程，指定协程运行的线程。

默认提供了四种调度器

#### Dispatchers.Default

> 默认调度器，适合处理后台运算，为`CPU密集型`任务调度器



#### Dispatchers.IO(仅JVM可用)

> 适合执行IO相关操作，例如`读写文件`等，为`IO密集型`任务调度器



#### Dispatchers.Main

> UI调度器，根据执行平台的不同会初始化为对应平台的UI线程调度器。
>
> 在Android中，就会通过`Handler`调度任务到`UI线程`执行。

```kotlin
//加载各平台下定义的MainDispatcherFactory
private fun loadMainDispatcher(): MainCoroutineDispatcher {
        return try {
            val factories = if (FAST_SERVICE_LOADER_ENABLED) {
                FastServiceLoader.loadMainDispatcherFactory()
            } else {
                // We are explicitly using the
                // `ServiceLoader.load(MyClass::class.java, MyClass::class.java.classLoader).iterator()`
                // form of the ServiceLoader call to enable R8 optimization when compiled on Android.
                ServiceLoader.load(
                        MainDispatcherFactory::class.java,
                        MainDispatcherFactory::class.java.classLoader
                ).iterator().asSequence().toList()
            }
            @Suppress("ConstantConditionIf")
            factories.maxBy { it.loadPriority }?.tryCreateDispatcher(factories)
                ?: createMissingDispatcher()
        } catch (e: Throwable) {
            // Service loader can throw an exception as well
            createMissingDispatcher(e)
        }
    }

    internal fun loadMainDispatcherFactory(): List<MainDispatcherFactory> {
        val clz = MainDispatcherFactory::class.java
        if (!ANDROID_DETECTED) {
            return load(clz, clz.classLoader)
        }

        return try {
            val result = ArrayList<MainDispatcherFactory>(2)
          //加载对应类名的类
            createInstanceOf(clz, "kotlinx.coroutines.android.AndroidDispatcherFactory")?.apply { result.add(this) }
            createInstanceOf(clz, "kotlinx.coroutines.test.internal.TestMainDispatcherFactory")?.apply { result.add(this) }
            result
        } catch (e: Throwable) {
            // Fallback to the regular SL in case of any unexpected exception
            load(clz, clz.classLoader)
        }
    }
```

按照类名去加载，Android下的名为`kotlinx.coroutines.android.AndroidDispatcherFactory`的类

```kotlin
//在Android编译完成后，可以读取到该类
internal class AndroidDispatcherFactory : MainDispatcherFactory {
    override fun createDispatcher(allFactories: List<MainDispatcherFactory>) = HandlerContext(Looper.getMainLooper().asHandler(async = true), "Main")
}
internal class HandlerContext private constructor(
    private val handler: Handler,
    private val name: String?,
    private val invokeImmediately: Boolean
) : HandlerDispatcher(), Delay {
    public constructor(
        handler: Handler,
        name: String? = null
    ) : this(handler, name, false)

    //android中需要向主looper进行提交调度
    override fun isDispatchNeeded(context: CoroutineContext): Boolean {
        return !invokeImmediately || Looper.myLooper() != handler.looper
    }

    //通过持有主线程looper的handler进行调度
    override fun dispatch(context: CoroutineContext, block: Runnable) {
        handler.post(block)
    }
    ...
}
```

##### Dispatchers.Main.immediate

> 适用于`响应UI事件后立即执行后续逻辑`的场景：当当前线程已经是`Main`线程时会立刻执行而不是再次分发；如果不在`Main`线程，行为与`Dispatchers.Main`一致。



#### Dispatchers.Unconfined

> 非限制的调度器，在遇到第一个挂起函数前的代码运行在原线程中，执行挂起函数后，就切换线程运行。



![调度器间的差异](/images/协程调度器间的差异)

#### 自定义调度器

> `Default`和`IO`的底层实现都依赖于`线程池`，执行到`挂起函数`时还是会发生线程的切换，可以通过`自定义调度器`减少这类切换的发生。

```kotlin
val myDispatcher= Executors.newSingleThreadExecutor{ r -> Thread(r, "MyThread") }.asCoroutineDispatcher() //转换线程池到 Dispatcher

```



<a id="sec-2-dispatcher-performance"></a>
### 调度器与性能（补充）

- `Dispatchers.Default` 与 `Dispatchers.IO` 都基于共享调度体系，IO 任务过量会影响整体调度公平性。
- `withContext` 每次切换都存在调度开销，细粒度频繁切换会放大性能损耗。
- 对高并发 IO 场景建议限流，避免把线程池和下游资源（DB/网络）同时打满。
- `Dispatchers.Main.immediate` 适合“已经在主线程且希望避免二次分发”的场景。
- `Dispatchers.Unconfined` 更适合调试/框架层场景，业务代码中应谨慎使用。

```kotlin
// 限制并发度，避免 IO 峰值放大
val dbDispatcher = Dispatchers.IO.limitedParallelism(4)
```

<a id="sec-2-interceptor"></a>
### 协程拦截器-ContinuationInterceptor

> `ContinuationInterceptor`是一个拦截器的接口定义，用于控制协程的执行流程。
>
> 在`CoroutineContext`中，实现了`ContinuationInterceptor`接口的类，永远会处于最后一位，保证不会被其他类覆盖。
>
> **协程拦截器只能存在一个！**

```kotlin
// ContinuationInterceptor.kt
   public interface ContinuationInterceptor : CoroutineContext.Element {  
     // 实现CoroutineContext.Element接口，说明自身是CoroutineContext上下文集合的一个元素类型  
     // 定义伴生对象Key作为集合中的索引key，可直接通过类名访问该伴生对象  
     companion object Key : CoroutineContext.Key<ContinuationInterceptor>  
   
     // 传入一个Continuation对象，并返回一个新的Continuation对象  
     // 在协程中，这里的传参continuation就是协程体编译后Continuation对象  
     public fun <T> interceptContinuation(continuation: Continuation<T>): Continuation<T>  
   
     public fun releaseInterceptedContinuation(continuation: Continuation<*>) {  
         
     ...  
 }  
```

其中`CoroutineDispatcher`就是基于`ContinuationInterceptor`所实现的。



<a id="sec-2-exception"></a>
### 协程异常处理-CoroutineExceptionHandler

> **所有未被捕获的异常一定会抛出，无论使用哪种Job!!!**

当一个协程由于一个异常而运行失败时，它会传播这个异常并传递给他的父级。

![△ 协程中的异常会通过协程的层级不断传播](/images/协程异常传递流程)

主要执行以下几步：

1. 取消它的子级任务
2. 取消自己的任务
3. 把异常继续向上传递到自己的父级



#### SupervisorJob

使用`Job`时，若发生异常会导致异常传递，使得所有的任务都会被取消。

使用`SupervisorJob`，一个子协程运行失败不会传播异常，`只会影响自身`，其他任务都不会受到影响。

**SupervisorJob只有在`supervisorScope`或`CoroutineScope(SupervisorJob())`内执行才可以生效。**

![SupervisorJob 不会取消它其他的子级](/images/SuperVisorJob不取消)



`CoroutineScope(SupervisorJob())`

```kotlin
val scope = CoroutineScope(SupervisorJob())
scope.launch{
  //child 1
}
scope.launch{
  //child 2
}
//若child1 发生异常不会影响 child2
```

`supervisorScope`

```kotlin
            supervisorScope {
                launch {
                    throw NullPointerException("123")
                }
                launch {
                    System.err.println(3)
                }
            }

```

使用这两种方式都可以保证异常不向上传播

#### Job VS SupervisorJob

> 如果想在出现错误时不会退出父级和其他平级的协程，就要使用`SupervisorJob`或`supervisorScope`



#### 局部异常捕获

根据不同的`协程构造器`，处理方式也不尽相同

##### `launch()`

主要采用`try{}catch{}`的形式进行异常捕获

```kotlin
scope.launch {
    try {
        codeThatCanThrowExceptions()
    } catch(e: Exception) {
        // 处理异常
    }
}
```

**`launch()`时，异常会在第一时间被抛出。**



##### `async/await()`

**只有当`async()`作为根协程时，不会自动抛出异常，而是要等到`await()`执行时才抛出异常。**

`根协程`：`coroutineScope`或`supervisorScope`的直接子协程，或者类似`scope.async()`这种实现。

这种情况下可以通过`try{}catch{}`捕获异常

```kotlin
//supervisorScope
coroutineScope{
  val deferred = async{
    throw NullPointerException("123")
  }
}
```

此时不会执行任何

只有在调用`.await()`时才会抛出异常，此时就可以添加`try{}catch{}`捕获异常。



**针对`async()`这种情况，最有效的方式就是`async()`内部进行`try{}catch{}`**



#### 全局异常捕获

> 类似Java，协程也提供了捕获全局异常(`未声明捕获异常`)的方式

Java的全局异常捕获方式

```java
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(Thread t, Throwable e) {
                //TODO 异常处理
            }
        });
```



##### 协程内全局异常捕获方式

主要使用的是`CoroutineExceptionHandler`，可以帮助处理一些`未捕获的异常`。

```kotlin
val exceptionHandler = CoroutineExceptionHandler { coroutineContext, throwable ->
    log("Throws an exception with message: ${throwable.message}")
}

val context = Dispatchers.Main + Job() + exceptionHandler
val scope = CoroutineScope(context)

fun main(){
        scope.launch {
            launch {
                throw NullPointerException("1234")
            }
            delay(1000)
        }
}

```

此时就会捕获到`NPE`。



需要`CoroutineExceptionHandler`生效通常需要两个条件：

1. 异常是`未被捕获`的异常（协程体内没有被`try/catch`处理）。
2. 异常发生在会向外抛出的协程上（典型是`launch`根协程）。`async`会把异常封装到`Deferred`，通常需要在`await()`时处理。



##### 真·全局异常捕获

上面说到的`CoroutineExceptionHandler`只能在协程内部使用，无法兼顾其他协程的异常情况。此时就需要使用另一种方式，使用`ServiceLoader`实现全局内协程异常捕获

实现这个功能需要如下几步：

1. 新建全局`CoroutineExceptionHandler`类
2. 在`classPath`中注册该类
   - 在`src/main/`目录下的，`resources/META-INF/services`文件夹
   - 新建`kotlinx.coroutines.CoroutineExceptionHandler`文件
   - 文件内写入自定义的全局`CoroutineExceptionHandler`完整类名

**同样，这种配置方式只处理未被捕获异常；`async`的异常仍需通过`await()`或局部`try/catch`处理。**



这里主要应用了**SPI机制**

> 全称为`Service Provider Interface`，JDK内置的一种服务提供发现机制，主要源码实现在`java.util.ServiceLoader`

使用过程：

需要在`resources/META-INF/services`目录下创建与服务同名的**全限定名**相同的文件，然后在文件中写入**服务提供者的全限定名**。

原理简介：

主要通过反射调用配置的类进行实例化，反射成功后存入缓存，后续使用直接从缓存重新读取。



##### 总结

1. **协程内部异常处理流程**

   - 在作用域内使用`try..catch`可以直接捕获子线程中的异常。

     ```kotlin
     try{
       launch{
         
       }
       
       async{
         
       }
     }catch{...}{
       
     }
     ```

     

    - 如果未做局部异常处理，未被捕获异常会走`全局异常捕获流程`（典型是`launch`根协程）

      - 若设置`CoroutineExceptionHandler`则处理。**通常需要在根协程（或最终汇聚到根协程的上下文）配置才可生效**
      - 没配置，向`GlobalExceptionHandler`进行处理，该配置是全局的，对所有协程任务生效

2. **异常传播在不同作用域的表现**

   - `GlobalScope`：异常不会向外传递，因为已经是`根协程`
   - `coroutineScope`：异常进行`双向传递`，父协程和子协程都会被取消
   - `supervisorScope`：异常进行`单向传递`，只有父协程向子协程传递异常，子协程会被取消，父协程不受影响

3. `launch/join`和`async/await`表现不同

   `launch/join`关注的是**任务是否执行完成**，`async/await`关注的是**任务的执行结果**，所以在局部异常捕获的时候，两种创建方式的异常捕获也会有区别

4. 想要避免异常传播，就要使用`SupervisorJob`；不在意就用`Job`

<a id="sec-2-exception-deep"></a>
### 异常语义深水区（补充）

| 场景 | 结果 | 处理建议 |
| --- | --- | --- |
| `launch` 根协程未捕获异常 | 立即向上抛出，触发父级取消链路 | 局部`try/catch`优先，必要时配合`CoroutineExceptionHandler` |
| `async` 未 `await()` | 异常会留在 `Deferred`，调用方感知可能延后 | 确保`await()`或在`async`内部处理异常 |
| 抛出 `CancellationException` | 视为正常取消语义，不等同业务失败 | 清理资源后继续向外抛，避免误吞取消信号 |
| `supervisorScope` 子协程异常 | 默认不取消其他同级子协程 | 适用于“局部失败可接受”的聚合任务 |

补充：异常处理顺序建议是“局部处理 -> 作用域处理 -> 全局兜底”，避免把业务异常全部压到全局处理器。



<a id="sec-3"></a>
## 三、协程怎么用好（构造、启动与取消）

<a id="sec-3-structured"></a>
### 结构化并发决策（补充）

| 目标 | 推荐作用域/模型 | 失败行为 |
| --- | --- | --- |
| 全部成功才算成功 | `coroutineScope` + `async/awaitAll` | 一个失败，整体快速失败 |
| 允许部分失败继续执行 | `supervisorScope` + 独立异常处理 | 失败子任务不影响其他子任务 |
| 长生命周期后台任务 | 显式 `CoroutineScope(Job/SupervisorJob + Dispatcher)` | 由作用域统一管理取消 |

实践要点：

- 子任务必须可追踪（有作用域、有`Job`、可取消）。
- 作用域退出前应完成“等待、取消、清理”三件事。
- 不要在业务层随意创建新的根作用域，避免协程漂移。

<a id="sec-3-choice"></a>
### 协程工具选型（launch / async / withContext）

| 场景 | 推荐方式 | 原因 | 返回值 |
| --- | --- | --- | --- |
| 只关心执行，不关心结果 | `launch` | 语义直接，便于通过`Job`取消 | `Job` |
| 需要并发并汇总结果 | `async` + `await/awaitAll` | 可并行执行并拿到结果 | `Deferred<T>` |
| 单段任务切线程并返回结果 | `withContext` | 结构清晰，避免不必要并发 | 直接返回 `T` |

常见误区：

- `withContext`不是并发模型，它是“切上下文执行一段代码”。
- `async`不是默认更快，若没有并发需求，`withContext`更简单可控。
- 在父协程中混用过多`launch`而不追踪`Job`，容易导致状态不可控。

推荐写法：

```kotlin
// 单任务切线程
val user = withContext(Dispatchers.IO) { api.loadUser() }

// 并发聚合
val result = coroutineScope {
    val a = async(Dispatchers.IO) { api.a() }
    val b = async(Dispatchers.IO) { api.b() }
    awaitAll(a, b)
}
```

<a id="sec-3-flow"></a>
### Flow 体系（Flow / StateFlow / SharedFlow / Channel）

| 类型 | 冷/热 | 数据语义 | 典型用途 |
| --- | --- | --- | --- |
| `Flow<T>` | 冷流 | 每次收集重新执行上游 | 请求链路、转换流水线 |
| `StateFlow<T>` | 热流 | 始终持有最新状态（`value`） | UI 状态驱动 |
| `SharedFlow<T>` | 热流 | 广播事件，可配置`replay` | 一次性事件、多订阅分发 |
| `Channel<T>` | 热通道 | 点对点发送接收（队列） | 生产者-消费者模型 |

使用建议：

- 状态流优先用`StateFlow`，事件流优先用`SharedFlow`。
- 高频流场景按需使用`buffer`、`conflate`、`collectLatest`降低背压影响。
- UI 收集前可结合`distinctUntilChanged`减少重复渲染。

```kotlin
private val _state = MutableStateFlow(UiState.Loading)
val state: StateFlow<UiState> = _state

private val _events = MutableSharedFlow<UiEvent>(extraBufferCapacity = 1)
val events: SharedFlow<UiEvent> = _events
```

<a id="sec-3-primitives"></a>
### 并发原语（Mutex / Semaphore / Channel / select）

| 原语 | 作用 | 适用场景 |
| --- | --- | --- |
| `Mutex` | 互斥访问共享资源 | 保护共享可变状态 |
| `Semaphore` | 限制并发数量 | 批量请求限流 |
| `Channel` | 协程间消息通道 | 生产消费、任务管道 |
| `select` | 多路等待与竞速 | 超时竞速、多个源择优 |

```kotlin
val mutex = Mutex()
var counter = 0

suspend fun incSafely() {
    mutex.withLock {
        counter++
    }
}
```

<a id="sec-3-builder"></a>
### 协程构造器-CoroutineBuilder

> 主要负责构造一个协程并启动它

常用的有两种方法

#### launch(重点分析)

> 默认创建一个新的协程，并返回`Job`对象，通过`Job`管理协程。

```kotlin
public fun CoroutineScope.launch(
    context: CoroutineContext = EmptyCoroutineContext,
    start: CoroutineStart = CoroutineStart.DEFAULT,
    block: suspend CoroutineScope.() -> Unit
): Job {
    val newContext = newCoroutineContext(context)
    val coroutine = if (start.isLazy)
        LazyStandaloneCoroutine(newContext, block) else
        StandaloneCoroutine(newContext, active = true)
    coroutine.start(start, coroutine, block)
    return coroutine
}
```

主要有三个参数：

- `context`：就是前面介绍的`CoroutineContext`
- `start`：[协程启动模式](#sec-3-start)
- `block`：需要执行的任务，由`suspend`修饰



##### newCoroutineContext

> 将传参的`context`与`ContextScope`配置的`context`进行合并，并返回一个新的`context`。

```kotlin
public actual fun CoroutineScope.newCoroutineContext(context: CoroutineContext): CoroutineContext {
    val combined = coroutineContext + context
    val debug = if (DEBUG) combined + CoroutineId(COROUTINE_ID.incrementAndGet()) else combined
    return if (combined !== Dispatchers.Default && combined[ContinuationInterceptor] == null)
        debug + Dispatchers.Default else debug
}
```



##### StandaloneCoroutine/LazyStandaloneCoroutine

```kotlin
private open class StandaloneCoroutine(
    parentContext: CoroutineContext,
    active: Boolean
) : AbstractCoroutine<Unit>(parentContext, active) {
    override fun handleJobException(exception: Throwable): Boolean {
        handleCoroutineException(context, exception)
        return true
    }
}
```

继承`AbstractCoroutine`且重写了`handleJobException()`，这也是为什么`CoroutineExceptionHandler`可以监听到异常的原因。



```kotlin
private class LazyStandaloneCoroutine(
    parentContext: CoroutineContext,
    block: suspend CoroutineScope.() -> Unit
) : StandaloneCoroutine(parentContext, active = false) {
    private var block: (suspend CoroutineScope.() -> Unit)? = block

    override fun onStart() {
        val block = checkNotNull(this.block) { "Already started" }
        this.block = null
        block.startCoroutineCancellable(this, this)
    }
}
```

`LazyStandaloneCoroutine`重写了`onStart()`，只有在调用到`start()/join()`等方法才会执行。



##### start()

> 启动协程任务

```kotlin
//AbstractCoroutine.kt
    public fun <R> start(start: CoroutineStart, receiver: R, block: suspend R.() -> T) {
        initParentJob()
        start(block, receiver, this)
    }
```

调用到`CoroutineStart.invoke()`

```kotlin
//CoroutineStart.kt
    public operator fun <R, T> invoke(block: suspend R.() -> T, receiver: R, completion: Continuation<T>) =
        when (this) {
            CoroutineStart.DEFAULT -> block.startCoroutineCancellable(receiver, completion)
            CoroutineStart.ATOMIC -> block.startCoroutine(receiver, completion)
            CoroutineStart.UNDISPATCHED -> block.startCoroutineUndispatched(receiver, completion)
            CoroutineStart.LAZY -> Unit // will start lazily
        }

```

默认使用`CoroutineStart.DEFAULT`，以这个作为示例分析

```kotlin
//Cancellable.kt
internal fun <R, T> (suspend (R) -> T).startCoroutineCancellable(receiver: R, completion: Continuation<T>) =
    runSafely(completion) {
        createCoroutineUnintercepted(receiver, completion)
      .intercepted()
      .resumeCancellable(Unit)
    }

```

主要流程分为三步：

###### createCoroutineUninterecpted

```kotlin
//IntrinsicsJvm.kt
@SinceKotlin("1.3")
public actual fun <T> (suspend () -> T).createCoroutineUnintercepted(
    completion: Continuation<T>
): Continuation<Unit> {
    val probeCompletion = probeCoroutineCreated(completion)
    return if (this is BaseContinuationImpl)
        create(probeCompletion)
    else
        createCoroutineFromSuspendFunction(probeCompletion) {
            (this as Function1<Continuation<T>, Any?>).invoke(it)
        }
}
```

主要是为了创建`Continuation`对象

###### intercepted

```kotlin
public actual fun <T> Continuation<T>.intercepted(): Continuation<T> =
    (this as? ContinuationImpl)?.intercepted() ?: this


//ContinuationImpl.kt
    public fun intercepted(): Continuation<Any?> =
        intercepted
            ?: (context[ContinuationInterceptor]?.interceptContinuation(this) ?: this)
                .also { intercepted = it }
```

如果设置了`ContinuationInterceptor`，就获取并执行`interceptContinuation()`。



###### resumeCancellable

```kotlin
internal fun <T> Continuation<T>.resumeCancellable(value: T) = when (this) {
    is DispatchedContinuation -> resumeCancellable(value)
    else -> resume(value)
}
```

进行线程调度或者事件拦截处理，然后协程就开始启动了。



#### async



<a id="sec-3-start"></a>
### 协程启动模式-CoroutineStart

> 控制协程创建后的调用规则

#### CoroutineStart.DEFAULT

> 协程的默认启动模式，为`饿汉式调用`。在调用协程后，会立即进入调度状态。
>
> *可以在调度前被取消。*



#### CoroutineStart.LAZY

> `懒汉式调用`，只有需要执行时才会执行。
>
> 通过调用以下方法就可以进入调度状态。
>
> - `job.start()`：启动协程
> - `job.join`：启动协程并等待任务执行结束
> - `job.await()`



#### CoroutineStart.ATOMIC

> 协程创建后，立即开始调度。
>
> **在执行到第一个挂起点之前不会响应`cancel()`**



#### CoroutineStart.UNDISPATCHED

> 协程创建后，立即开始调度
>
> **直到遇到第一个挂起点之前，都会在当前线程中执行。**



<a id="sec-3-cancel"></a>
### 协程取消-Cancel

> 取消协程可以针对`CoroutineScope`或`Job`去执行。

#### 取消作用域下所有协程

> 调用`CoroutineScope.cancel()`

```kotlin
val scope = CoroutineScope(context)

...
if(scope.isActive){ //判断当前scope是否活跃
  scope.cancel()
}

```

适用于页面关闭时，需要回收资源的情况

**不能在已取消的作用域中再次启动新的协程。**

#### 取消单个协程

> 针对`Job`进行取消，调用`cancel()`可以取消正在运行的协程

```kotlin
//官方示例代码
val job = launch {
    repeat(1000) { i ->
        println("I'm sleeping $i ...")
        delay(500L)
    }
}
delay(1300L) // 等待一段时间
println("main: I'm tired of waiting!")
job.cancel() // 取消 job
job.join() // 等待 job 结束
println("main: Now I can quit.")
```

##### 协程之间的关系

> 协程是存在着父子关系的，**取消父协程时，也会取消所有子协程**

主要有以下三种关系：

1. `父协程`调用`cancel()`或触发异常时，会立即取消所有`子协程`；`子协程`调用`cancel()`不影响父协程及兄弟协程的执行

   > 在底层实现中，子协程通过抛出异常的方式将取消的情况通知到父协程。
   >
   > 父协程通过传入的异常来决定是否处理异常，如果异常为`CancellationException`就不做处理。

2. `父协程`必须等到所有`子协程`完成才算完成

3. `子协程`抛出未捕获的异常时，默认情况下会取消`父协程`(`superVisorJob`和`CancellationException`除外)



#### 使协程可以取消

> 协程处理任务的代码必须是**协作式**的，需要配合`协程取消`进行了处理。



需要在任务处理期间`定期检查协程是否已被取消`，或者在处理耗时任务之前就`检查当前协程是否已取消`。

目前只有`kotlinx.coroutines`所有的挂起函数都是`可取消的`，例如`delay()`、`yield()`等，这些都不需要去检查协程是否已取消。

因此要使`协程可以被取消`，可以使用以下两种方法：

- 通过`job.isActive`或`ensureActive()`检查协程状态
- 内部使用`delay()`或`yield()`等挂起函数——核心在于`suspendCoroutineUninterceptedOrReturn`



##### 检查Job的活跃状态-isActive

> 在协程执行过程中，添加`isActive`检查协程状态，若`!isActive`就不向下执行任务。

```kotlin
val job = scope.launch{
  var i = 0
  while(i < 5 && isActive){
    Log.e("test","now value = ${i++}")
  }
}

...
job.cancel()
```

还有一种方式就是`ensureActive()`

```kotlin
public fun Job.ensureActive(): Unit {
    if (!isActive) throw getCancellationException()
}
```

使用`ensureActive()`可以不用手动去检测`isActive`，通过直接抛出异常来结束任务。

##### 使用挂起函数

> `挂起函数`：`delay()`、`yield()`等函数，内部核心实现为`suspendCancellableCoroutine`

###### delay()

> 让协程挂起，而且不会阻塞CPU。类似于`Thread.sleep()`

```kotlin
public suspend fun delay(timeMillis: Long) {
    if (timeMillis <= 0) return // don't delay
    return suspendCancellableCoroutine sc@ { cont: CancellableContinuation<Unit> ->
        cont.context.delay.scheduleResumeAfterDelay(timeMillis, cont)
    }
}
```



###### yield()

> 挂起当前协程，然后将协程分发到`Dispatcher`队列，可以让该协程所在线程或线程池可以运行其他协程逻辑，然后等待`Dispatcher`空闲的时候继续执行原来的协程任务。类似于`Thread.yield()`

```kotlin
public suspend fun yield(): Unit = suspendCoroutineUninterceptedOrReturn sc@ { uCont ->
    val context = uCont.context
    context.checkCompletion()
    val cont = uCont.intercepted() as? DispatchedContinuation<Unit> ?: return@sc Unit
    if (!cont.dispatcher.isDispatchNeeded(context)) {
        return@sc if (cont.yieldUndispatched()) COROUTINE_SUSPENDED else Unit
    }
    cont.dispatchYield(Unit)
    COROUTINE_SUSPENDED
}

internal fun CoroutineContext.checkCompletion() {
    val job = get(Job)
    if (job != null && !job.isActive) throw job.getCancellationException()
}
```

执行`yield()`时，会优先检测任务的完成状态，如果`!job.isActive`直接抛出`CancellableException`

###### suspendCoroutineUninterceptedOrReturn

> 主要作用为`获取当前协程的实例，并且挂起当前协程或者不挂起直接返回结果`。

根据上述源码发现，`挂起函数`的关键在于`suspendCoroutineUninterceptedOrReturn`，只要使用了该方法，就可以成为`挂起函数`。

通过做转换的时候，可以使用系统提供的两个转换函数：

- `suspendCoroutine`
- `suspendCancellableCoroutine`*推荐使用*

#### 相关源码

##### suspendCoroutine

```kotlin 
    suspend fun test() = suspendCoroutine<String> { continuation ->
        if (...) {
            continuation.resume("11")
        } else {
            continuation.resumeWithException(NullPointerException("123"))
        }
    }
```



##### suspendCancellableCoroutine

```kotlin
val aa = 0
suspend fun ttt() = suspendCancellableCoroutine<Int> { cancellableContinuation ->
    if (aa == 0) {
        //执行完毕抛出结果
        cancellableContinuation.resume(1) {
            // 执行过程异常捕获
            log("aaa ${it.message}")
        }
    } else {
        cancellableContinuation.resumeWithException(IllegalArgumentException("123"))
    }

    cancellableContinuation.invokeOnCancellation {
       //协程任务执行cancel时，回调该方法
        log("我被取消了")
    }
}
```

可以通过`continuation.invokeCancellation()`执行取消操作

```kotlin
public suspend inline fun <T> suspendCancellableCoroutine(
    crossinline block: (CancellableContinuation<T>) -> Unit
): T =
    suspendCoroutineUninterceptedOrReturn { uCont ->
        val cancellable = CancellableContinuationImpl(uCont.intercepted(), resumeMode = MODE_CANCELLABLE)
        /*
         * For non-atomic cancellation we setup parent-child relationship immediately
         * in case when `block` blocks the current thread (e.g. Rx2 with trampoline scheduler), but
         * properly supports cancellation.
         */
        cancellable.initCancellability()
        block(cancellable)
        cancellable.getResult()
    }
```



#### 禁止取消

> 当任务被取消时，挂起函数会收到`CancellationException`后续如果需要执行一些其他的挂起函数任务将无法执行。

对挂起函数调用`withContext(NonCancellable)`，保证挂起函数正常执行。

关键在于`isActive`永远为`true`

#### 超时取消

> 大部分取消协程的原因都是**超出了预期的执行时间**，此时就会去触发取消的操作。

对挂起函数调用`withTimeout(XX)`或`withTimeoutOrNull(XX)`，唯一的区别就是后者会返回`null`而不是抛出异常。

<a id="sec-3-cancel-deep"></a>
### 取消语义深水区（补充）

- 取消是**协作式**的：可取消挂起点或主动检查`isActive`后，协程才会及时停止。
- `CancellationException`通常代表控制流，不建议当成普通业务异常吞掉。
- 在`finally`中调用挂起函数时，默认仍会受取消影响，需要`withContext(NonCancellable)`兜底。
- 使用`suspendCancellableCoroutine`对接回调时，务必实现`invokeOnCancellation`释放资源。

```kotlin
try {
    doWork()
} finally {
    withContext(NonCancellable) {
        closeResource()
    }
}
```

<a id="sec-3-android-practice"></a>
### Android 使用建议（工程实践）

- 页面生命周期相关任务优先使用`viewModelScope`或`lifecycleScope`，避免`GlobalScope`。
- UI 更新统一放在`Dispatchers.Main`，IO/网络放在`Dispatchers.IO`。
- 对关键请求增加超时边界：`withTimeout`或`withTimeoutOrNull`。
- 对可并发任务优先用`coroutineScope + async/awaitAll`，对“局部失败可接受”场景用`supervisorScope`。
- 长循环或计算任务增加`isActive/ensureActive`检查，提升取消响应速度。
- `Flow`收集优先使用`repeatOnLifecycle`，避免页面不可见时持续收集。
- Compose 场景区分`LaunchedEffect`与`rememberCoroutineScope`的职责边界。

示例：

```kotlin
viewModelScope.launch {
    val profile = withContext(Dispatchers.IO) { repository.loadProfile() }
    _uiState.value = UiState.Success(profile)
}
```

<a id="sec-3-antipatterns"></a>
### 常见反模式与修正建议

| 反模式 | 风险 | 建议 |
| --- | --- | --- |
| 页面层直接用`GlobalScope` | 生命周期失控、任务泄漏 | 使用`viewModelScope/lifecycleScope` |
| `async`创建后不`await` | 异常与结果丢失 | 明确`await`或改用`launch` |
| 高频小任务频繁`withContext` | 调度开销放大 | 合并批处理，减少切换次数 |
| 吞掉`CancellationException` | 取消链路被破坏 | 仅清理资源后向外抛出 |
| 多处随意新建根`CoroutineScope` | 并发关系不可追踪 | 统一作用域入口，结构化管理 |



<a id="sec-4"></a>
## 四、协程为什么能挂起（原理实现）

<a id="sec-4-dispatcher-principle"></a>
### Dispatchers原理

无论是`Dispatchers.Default`或者`IO`都是`CoroutineDispatcher`的子类。

```kotlin
public abstract class CoroutineDispatcher :
    AbstractCoroutineContextElement(ContinuationInterceptor), ContinuationInterceptor {
    //线程调度，指定协程在某一线程上运行
    public abstract fun dispatch(context: CoroutineContext, block: Runnable)      
    //封装 Continuation 为 DispatchedContinuation
    public final override fun <T> interceptContinuation(continuation: Continuation<T>): Continuation<T> =
        DispatchedContinuation(this, continuation)
    }
```

`CoroutineDispatacher`继承`AbstractCoroutineContextElement`类，还实现了`ContinuationInterceptor`接口。

#### DispatchedContinuation

> 代理协程体Continuation对象并持有线程调度器，负责**使用线程调度器将协程体调度到执行的线程执行**。

```kotlin
internal class DispatchedContinuation<in T>(
    @JvmField val dispatcher: CoroutineDispatcher,
    @JvmField val continuation: Continuation<T>
) : DispatchedTask<T>(MODE_ATOMIC_DEFAULT), CoroutineStackFrame, Continuation<T> by continuation {
  
  
     override fun resumeWith(result: Result<T>) {  
         val context = continuation.context  
         val state = result.toState()  
         // 是否需要线程调度  
         if (dispatcher.isDispatchNeeded(context)) {  
             _state = state  
             resumeMode = MODE_ATOMIC_DEFAULT  
             // dispatch 调度线程，第二个参数是一个Runnable类型，这里传参this也就是DispatchedContinuation自身  
             // DispatchedContinuation实际上也是一个Runnable对象，调用调度器的dispatch方法之后就可以使这个runnable在指定的线程运行了  
             dispatcher.dispatch(context, this)  
         } else {  
             executeUnconfined(state, MODE_ATOMIC_DEFAULT) {  
                 withCoroutineContext(this.context, countOrElement) {  
                     // 不需要调度，执行协程体的resumeWith  
                     continuation.resumeWith(result)  
                 }  
             }  
         }  
     }  
      // 默认启动模式  
      inline fun resumeCancellableWith(result: Result<T>) {  
         val state = result.toState()  
         if (dispatcher.isDispatchNeeded(context)) {  
             _state = state  
             resumeMode = MODE_CANCELLABLE  
             dispatcher.dispatch(context, this)  
         } else {  
             executeUnconfined(state, MODE_CANCELLABLE) {  
                 if (!resumeCancelled()) {  
                     resumeUndispatchedWith(result)  
                 }  
             }  
         }  
     }    
  
}
```

`DispatchedContinuation`用两个参数构建

- `dispatcher`：拦截器
- `continuation`：协程体类对象



其中`resumeWith()`和`resumeCancellableWith()`负责协程的启动。

补充：`resumeWith()`用于普通恢复；`resumeCancellableWith()`会在恢复前额外检查取消状态，并按可取消模式进行调度。



<a id="sec-4-start-flow"></a>
### 协程启动流程

1. 通过`CoroutineScope.launch()`创建一个协程，默认启动模式为`CoroutineStart.DEFAULT`，创建一个`StandaloneCoroutine`协程对象
2. 执行`StandaloneCoroutine.start()`实质执行到`AbstractCoroutine.start()`，继续触发到`CoroutineStart.invoke()`
3. 由于默认调度器为`Dispatchers.Default`，所以执行到了`startCoroutineCancellable()`
4. `startCoroutineCancellable()`内部主要有三次调用
   - `createCoroutineUnintercepted()`：创建一个协程体类对象
   - `intercepted`：将协程体类包装成`DispatchedContinuation`对象
   - `resumeCancellableWith()`：通过`Default`调用到`resumeCancellableWith()`
5. 实际调用到了`DispatchedContinuation.resumeCancellableWith()`，最后执行到`Continuation.resumeWith()`执行协程任务。



<a id="sec-4-suspend-resume"></a>
### 协程挂起/恢复原理

> 挂起的特点：**不阻塞线程**。挂起的本质**切线程**，并且在相应逻辑处理完毕之后，再重新切回线程。

```kotlin
suspend fun loginUser(userId: String, password: String): String {
  val user = logUserIn(userId, password)
  val userDb = logUserIn(user)
  return userDb
}

suspend fun logUserIn(userId: String, password: String): String

suspend fun logUserIn(userId: String): String
```

反编译后得到

```kotlin

fun loginUser(userId: String, password: String, completion: Continuation<Any?>) {
  val user = logUserIn(userId, password)
  val userDb = logUserIn(user)
  completion.resume(userDb)
}
```



调用`挂起函数`或者`suspend lambda表达式`时，都会一个`隐式参数`传入，这个参数是`Continuation`类型。

> CPS：续体传递风格
>
> 在每个`挂起函数`与`suspend lambda表达式`都会附加一个`Continuation`参数，并且是用来代替`suspend`

#### Continuation接口

`挂起函数`通过`Continuation`在方法间互相通信，基本实现如下：

```kotlin
interface Continuation<in T> {
  public val context: CoroutineContext
  public fun resumeWith(value: Result<T>)
}

public inline fun <T> Continuation<T>.resume(value: T): Unit =
    resumeWith(Result.success(value))

public inline fun <T> Continuation<T>.resumeWithException(exception: Throwable): Unit =
    resumeWith(Result.failure(exception))

```

后续添加`resume(value)`和`resumeWithException(exception)`可以方便的获取结果，而不需要从`Result`解析。

`Continuation`主要有以下参数和方法

- `context`：内部使用的`CoroutineContext`
- `resumeWith()`：恢复协程的执行，同时传入一个`Result`。内部包括了`计算结果`或`过程中发生的异常`



#### 状态机

> Kotlin编译器会确定函数何时可以在内部挂起，每个挂起点都会被声明为有限状态机的一个状态，每个状态用`label`表示

查看反编译后源码，内部源码大概如下

```java
 @Nullable
   public final Object loginUser(@NotNull String userId, @NotNull String password, @NotNull Continuation $completion) {
      Object $continuation;
      label27: {
         if ($completion instanceof <undefinedtype>) {
            $continuation = (<undefinedtype>)$completion;
            if ((((<undefinedtype>)$continuation).label & Integer.MIN_VALUE) != 0) {
               ((<undefinedtype>)$continuation).label -= Integer.MIN_VALUE;
               break label27;
            }
         }

         $continuation = new ContinuationImpl($completion) {
            // $FF: synthetic field
            Object result;
            int label;
            Object L$0;
            Object L$1;
            Object L$2;
            Object L$3;

            @Nullable
            public final Object invokeSuspend(@NotNull Object $result) {
               this.result = $result;
               this.label |= Integer.MIN_VALUE;
               return MyClass.this.loginUser((String)null, (String)null, this);
            }
         };
      }

      Object var10000;
      label22: {
         Object $result = ((<undefinedtype>)$continuation).result;
         Object var8 = IntrinsicsKt.getCOROUTINE_SUSPENDED();
         String user;
         switch(((<undefinedtype>)$continuation).label) {
         case 0:
             //错误检查
            ResultKt.throwOnFailure($result);
            ((<undefinedtype>)$continuation).L$0 = this;
            ((<undefinedtype>)$continuation).L$1 = userId;
            ((<undefinedtype>)$continuation).L$2 = password;
             //设置 label为1 下次执行切换到 case 1
            ((<undefinedtype>)$continuation).label = 1;
             //当前状态机执行的流程
            var10000 = this.logUserIn(userId, password, (Continuation)$continuation);
            if (var10000 == var8) {
               return var8;
            }
            break;
         case 1:
            password = (String)((<undefinedtype>)$continuation).L$2;
            userId = (String)((<undefinedtype>)$continuation).L$1;
            this = (MyClass)((<undefinedtype>)$continuation).L$0;
            ResultKt.throwOnFailure($result);
            user = (String)var10000;
            ((<undefinedtype>)$continuation).L$0 = this;
            ((<undefinedtype>)$continuation).L$1 = userId;
            ((<undefinedtype>)$continuation).L$2 = password;
            ((<undefinedtype>)$continuation).L$3 = user;
            ((<undefinedtype>)$continuation).label = 2;
             var10000 = this.logUserIn(user, (Continuation)$continuation);
            if (var10000 == var8) {
               return var8;
            }             
            var10000 = $result;
            break;
         case 2:
            user = (String)((<undefinedtype>)$continuation).L$3;
            password = (String)((<undefinedtype>)$continuation).L$2;
            userId = (String)((<undefinedtype>)$continuation).L$1;
            MyClass var9 = (MyClass)((<undefinedtype>)$continuation).L$0;
            ResultKt.throwOnFailure($result);
            var10000 = $result;
            break label22;
         default:
            throw new IllegalStateException("call to 'resume' before 'invoke' with coroutine");
         }

      }

      String userDb = (String)var10000;
      return userDb;
   }
```

> Kotlin编译器将每个`挂起函数`转换为一个状态机，在每次函数需要挂起时使用回调并进行优化。

观察上述源码发现主要有几个关键点

##### ContinuationImpl

```kotlin
internal abstract class ContinuationImpl(
    completion: Continuation<Any?>?,
    private val _context: CoroutineContext?
) : BaseContinuationImpl(completion) {
    constructor(completion: Continuation<Any?>?) : this(completion, completion?.context)

    public override val context: CoroutineContext
        get() = _context!!

    @Transient
    private var intercepted: Continuation<Any?>? = null

    public fun intercepted(): Continuation<Any?> =
        intercepted
            ?: (context[ContinuationInterceptor]?.interceptContinuation(this) ?: this)
                .also { intercepted = it }

}

//其中 invokeSuspend()是由BaseContinuationImpl实现

```

```Kotlin
internal abstract class BaseContinuationImpl(
    public val completion: Continuation<Any?>?
) : Continuation<Any?>, CoroutineStackFrame, Serializable {
    public final override fun resumeWith(result: Result<Any?>) {
        var current = this
        var param = result
        while (true) {
            probeCoroutineResumed(current)
            with(current) {
                val completion = completion!! 
                val outcome: Result<Any?> =
                    try {
                      //调用 invokeSuspend 真正执行协程体
                        val outcome = invokeSuspend(param)
                      //如果返回值为 CORPUTINE_SUSPENDED ，需要执行挂起操作
                        if (outcome === COROUTINE_SUSPENDED) return
                      //协程体执行成功
                        Result.success(outcome)
                    } catch (exception: Throwable) {
                      //协程体执行异常
                        Result.failure(exception)
                    }
                releaseIntercepted() // this state machine instance is terminating
                if (completion is BaseContinuationImpl) {
                    // unrolling recursion via loop
                    current = completion
                    param = outcome
                } else {
                   //此处表示 StandaloneCoroutine
                    completion.resumeWith(outcome)
                    return
                }
            }
        }
    }

    protected abstract fun invokeSuspend(result: Result<Any?>): Any?
  ...
}
```

`invokeSuspend()`执行的就是`协程体`，当`invokeSuspend()`返回值为`COROUTINE_SUSPENDED`时，执行`return操作`，协程体的操作也会被结束，所以`COROUTINE_SUSPENDED`也表示**协程发生挂起**。

#### 协程挂起

> 通过挂起函数将协程挂起，此处拿`withContext()`进行分析

```kotlin
public suspend fun <T> withContext(
    context: CoroutineContext,
    block: suspend CoroutineScope.() -> T
): T = suspendCoroutineUninterceptedOrReturn sc@ { uCont ->

    val oldContext = uCont.context
    val newContext = oldContext + context
   //检查协程是否活跃
    newContext.checkCompletion()

    if (newContext === oldContext) {
        val coroutine = ScopeCoroutine(newContext, uCont) // MODE_DIRECT
        return@sc coroutine.startUndispatchedOrReturn(coroutine, block)
    }

    if (newContext[ContinuationInterceptor] == oldContext[ContinuationInterceptor]) {
        val coroutine = UndispatchedCoroutine(newContext, uCont) // MODE_UNDISPATCHED
        // There are changes in the context, so this thread needs to be updated
        withCoroutineContext(newContext, null) {
            return@sc coroutine.startUndispatchedOrReturn(coroutine, block)
        }
    }

    val coroutine = DispatchedCoroutine(newContext, uCont) // MODE_CANCELLABLE
    coroutine.initParentJob()
   //coroutine 为 DispatchedCoroutine，持有需要恢复的协程                                                 
    block.startCoroutineCancellable(coroutine, coroutine)
    //返回结果为 挂起 还是完成                                              
    coroutine.getResult()
}
```

```Kotlin
//DispatchedCoroutine.kt
    fun getResult(): Any? {
      //需要挂起，则返回COROUTINE_SUSPENDED
        if (trySuspend()) return COROUTINE_SUSPENDED
        // otherwise, onCompletionInternal was already invoked & invoked tryResume, and the result is in the state
        val state = this.state.unboxState()
        if (state is CompletedExceptionally) throw state.cause
        @Suppress("UNCHECKED_CAST")
        return state as T
    }

    private fun trySuspend(): Boolean {
        _decision.loop { decision ->
            when (decision) {
                UNDECIDED -> if (this._decision.compareAndSet(UNDECIDED, SUSPENDED)) return true
                RESUMED -> return false
                else -> error("Already suspended")
            }
        }
    }
```

> 协程是否挂起，关键在于**是否返回COROUTINE_SUSPENDED**，在`getResult()`中就是判断`trySuspend()`是否返回`true`。

![协程挂起](/images/协程挂起流程.png)

#### 协程恢复

在`withContext()`中调用`startCoroutine()`传入了两个参数，其中第二个表示`协程完成的回调`。

当协程完成的时候会调用`resumeWith()`，然后层层传递到`JobSupport.afterCompletion()`，最后执行到`DispatchedCoroutine`

```kotlin
    override fun afterCompletionInternal(state: Any?, mode: Int) {
        if (tryResume()) return // completed before getResult invocation -- bail out
        // otherwise, getResult has already commenced, i.e. completed later or in other thread
        super.afterCompletionInternal(state, mode)
    }

    private fun tryResume(): Boolean {
        _decision.loop { decision ->
            when (decision) {
                UNDECIDED -> if (this._decision.compareAndSet(UNDECIDED, RESUMED)) return true
                SUSPENDED -> return false
                else -> error("Already resumed")
            }
        }
    }
```

在`afterCompletionInternal()`判断协程是否被挂起，若挂起则恢复已被挂起的协程。

然后再回到执行线程上，就会继续执行`invokeSuspend()`直到执行结束。

![协程恢复](/images/协程恢复流程.png)

<a id="sec-4-concurrency"></a>
### 协程并发

协程并发建议优先使用`结构化并发`：在同一个作用域内启动并行任务，并在作用域退出前统一等待结果或处理异常。

```kotlin
suspend fun loadAll(): List<String> = coroutineScope {
    val a = async(Dispatchers.IO) { requestA() }
    val b = async(Dispatchers.IO) { requestB() }
    awaitAll(a, b)
}
```

- 并发任务推荐放在`coroutineScope`中，失败会自动取消同级任务，避免悬挂任务。
- 如果希望“一个子任务失败不影响其他子任务”，可使用`supervisorScope`。
- IO 并发建议配合限流（如`limitedParallelism`或`Semaphore`），避免无限并发导致线程池拥塞。

<a id="sec-4-test-observability"></a>
### 测试与可观测性（补充）

- 单元测试推荐使用`runTest`与`StandardTestDispatcher`，通过虚拟时间驱动挂起逻辑。
- 对延时与超时场景，使用`advanceTimeBy`/`advanceUntilIdle`验证行为。
- 为关键协程增加`CoroutineName`，方便日志与问题定位。
- 调试复杂并发问题时，可结合协程调试工具或协程 dump 快照观察挂起链路。

```kotlin
@Test
fun timeout_case() = runTest {
    val result = withTimeoutOrNull(1000) {
        delay(2000)
        1
    }
    assert(result == null)
}
```



<a id="sec-5"></a>
## 五、知识点总结（可口述）

<a id="sec-5-principle-30"></a>
### 协程原理速答（30秒）

协程原理可以概括为：**编译期状态机 + 运行时调度**。

- `suspend`函数会被编译器转换为 CPS 形式，增加`Continuation`参数。
- 每个挂起点会被拆成状态机的一个`label`分支。
- 执行到挂起点返回`COROUTINE_SUSPENDED`，协程挂起但线程不阻塞。
- 异步结果返回后，通过`resumeWith`恢复执行，并按`label`继续后续逻辑。
- `CoroutineDispatcher`通过`ContinuationInterceptor`决定恢复在哪个线程执行。

<a id="sec-5-principle-2m"></a>
### 协程原理展开（2分钟）

可以按这条主线理解：

1. **创建阶段**：`launch/async`创建协程对象，绑定`CoroutineContext`（`Job + Dispatcher + ...`）。
2. **编译转换**：`suspend`函数被转成状态机，挂起点对应`label`，本质是可恢复的函数调用链。
3. **启动执行**：协程启动时会创建并包装`Continuation`，必要时被`Dispatcher`拦截调度。
4. **挂起时机**：遇到可挂起点返回`COROUTINE_SUSPENDED`，当前调用栈退出，线程可执行其他任务。
5. **恢复执行**：回调或结果就绪后触发`resumeWith`，状态机按上次`label`继续执行。
6. **生命周期管理**：`Job`树维护父子协程关系，取消是协作式，异常按层级传播（`SupervisorJob`可隔离子任务失败）。

<a id="sec-5-faq"></a>
### 高频追问知识点（补充）

- **挂起 vs 阻塞**：挂起是让出执行权，不占线程；阻塞会占住线程直到完成。
- **协程为什么轻量**：创建与切换主要在用户态完成，通常比线程上下文切换成本低。
- **为什么`async`异常常在`await()`暴露**：异常被封装在`Deferred`中，读取结果时才抛出。
- **取消为什么不一定立刻生效**：取消是协作式，需要挂起点或主动检查`isActive/ensureActive`。
- **`Main.immediate`意义**：已在主线程时避免二次分发，减少一跳调度延迟。

<a id="sec-6"></a>
## 六、参考与延伸

[Kotlin/Keep](https://github.com/Kotlin/KEEP/blob/master/proposals/coroutines.md)

[Android_开发者](https://juejin.cn/user/2277843822969863)

[Kotlin协程原理解析](https://mp.weixin.qq.com/s?__biz=MzUyMDAxMjQ3Ng==&mid=2247495170&idx=1&sn=b54e233699fd7bba0e940e2837258002&chksm=f9f279d1ce85f0c741857443332c20a82caedc24d8ea798219c2098c2d09ee58e11a6aba9296&mpshare=1&scene=23&srcid=1212Jz0IsITrVDTTTBRNCn0j&sharer_sharetime=1607751713936&sharer_shareid=65073698ab9ac2983b955fa53b4ff585%23rd)

[图解协程：suspend](https://juejin.cn/post/6883652600462327821#heading-10)

<!-- https://juejin.cn/post/6890348438873964551#heading-1 -->
