---
title: RxJava 使用及解析
date: 2019-01-10 11:56:21
tags: Hide
top: 10
---

<!--dispose做了啥 flatMap和Map有什么区别 如何进行线程切换-->

## RxJava基本知识

> RxJava是一个在JVM上使用可观测的序列来组成异步的、基于事件的程序的库。

通常情况下使用`Handler、AsyncTask`完成异步任务操作，当任务比较多的时候，使用这种方式就会变得相当繁琐，尤其是嵌套式的执行任务(需要上一项先完成)。

RxJava可以实现异步任务执行的前提下保持代码的清晰。通过创建一个`Observable`来完成异步任务，然后组合各种操作符实现不同的链式操作，最终将任务直执行结果发射到`Observer`进行处理。

{% fullimage /images/RxJava基础流程图.png,RxJava基础流程图,RxJava基础流程%}

### 简单示例

```java
 Observable<Integer> observable = Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                emitter.onNext(1);
                emitter.onNext(2);
                emitter.onComplete();
            }
        });
        observable.subscribe(new Observer<Integer>() {
            @Override
            public void onSubscribe(Disposable d) {
                System.err.println("onSubscribe");
            }

            @Override
            public void onNext(Integer integer) {
                System.out.println("onNext()"+integer);
            }

            @Override
            public void onError(Throwable e) {
                System.err.println("onError");
            }

            @Override
            public void onComplete() {
                System.err.println("onComplete");
            }
        });

输出结果：
onSubscribe
onNext1
onNext2
onComplete
```

`Observable`发射出一个事件，通过`subscribe()`建立与`Observer`的关联，然后回调到具体事件内(`onNext()、onError()、onComplete()`)。

除了`Observable`外，还提供了适用其他场景的基础类：

- `Flowable`：多个流，响应式流和背压

- `Single`：只能发射一条单一的数据，或者一条异常通知，无法发射完成通知。*数据与通知只能发射一个。*

  ```java
    Single<Integer> single = Single.create(new SingleOnSubscribe<Integer>() {
            @Override
            public void subscribe(SingleEmitter<Integer> singleEmitter) throws Exception {
                //发射数据
                singleEmitter.onSuccess(111);
                //发射异常通知
                singleEmitter.onError(new IllegalArgumentException("qwe"));
            }
        });
        single.subscribe(new SingleObserver<Integer>() {
            @Override
            public void onSubscribe(Disposable disposable) {
  
            }
  
            @Override
            public void onSuccess(Integer integer) {
  
            }
  
            @Override
            public void onError(Throwable throwable) {
  
            }
        });
  ```

  

- `Completeable`：只发射一条完成通知，或者一条异常通知，不能发射数据。*完成通知与异常通知只能发射一个。*

  ```java
   Completable completable = Completable.create(new CompletableOnSubscribe() {
           @Override
           public void subscribe(CompletableEmitter completableEmitter) throws Exception {
               //发射完成通知
               completableEmitter.onComplete();
               //发射错误通知
               completableEmitter.onError(new IllegalArgumentException("qwe"));
           }
       });
       completable.subscribe(new CompletableObserver() {
           @Override
           public void onSubscribe(Disposable disposable) {
               
           }
  
           @Override
           public void onComplete() {
  
           }
  
           @Override
           public void onError(Throwable throwable) {
  
           }
       });
  ```

  

- `Maybe`：可发射一条单一的数据，以及一条完成通知，或者一条异常通知.*完成通知和异常通知只能发射一个，且发射数据必须在发射通知之前。*

  ```
  Maybe<Integer> maybe = Maybe.create(new MaybeOnSubscribe<Integer>() {
      @Override
      public void subscribe(MaybeEmitter<Integer> maybeEmitter) throws Exception {
          //发射数据
          maybeEmitter.onSuccess(11);
          //发射完成通知
          maybeEmitter.onComplete();
          //发射错误通知
          maybeEmitter.onError(new IllegalArgumentException("qwe"));
      }
  });
  maybe.subscribe(new MaybeObserver<Integer>() {
      @Override
      public void onSubscribe(Disposable disposable) {
          
      }
  
      @Override
      public void onSuccess(Integer integer) {
  
      }
  
      @Override
      public void onError(Throwable throwable) {
  
      }
  
      @Override
      public void onComplete() {
  
      }
  });
  ```

### 事件类型

`Observable`是通过`ObservableEmitter`来发射事件的，可以发出的事件类型有三种：`onNext()、onError()，onComplete()`。

#### onNext()

> 对应`Observer.onNext()`，用于发射数据

#### onComplete()

> 对应`Observer.onComplete()`，用于发射完成通知

#### onError()

> 对应`Observer.onError()`，用于发射异常通知

他们三者之间满足一定的规则：

- `ObservableEmitter`可以发射无数的`onNext()`事件，`Observer`也可以处理无数`onNext()`事件
- 当`ObservableEmitter`发射出`onComplete()`事件，`Observer`接收到这个事件后，**不会再继续接收后续事件**。
- 当`ObservableEmitter`发射出`onError()`事件，`Observer`接收到这个事件后，**不会再继续接收后续事件**。
- `onComplete()`与`onError()`是**唯一且互斥**的。不能发射分多个`onComplete()`或`onError()`，也不能发射`onComplete()`后再跟上`onError()`。

### 取消订阅

通过`Disposable`实现，在`Observer`的`onSubsccribe()`中返回对象，他有两个方法`isDisposed()`——判断是否停止了观察指定的流，`dispose()`——放弃观察指定的流。

执行`Disposeable.dispose()`后，并不会影响`ObservableEmitter`继续发送事件，但是`Observer`中不会继续接收事件，相当于切断了两者的联系。

## RxJava操作符

如上节示例所示，通过`Observable.create()`就可以创建出一个`Observable`对象，除了`create`外，还有其他的操作符方便我们完成链式操作，下面详解介绍这些操作符。

### 创建操作符

> 用于创建Observable对象，并填充数据

#### create

> 用于从头到尾创建一个Observable对象，发射器内部会调用`onNext()、onComplete()，onError()`方法

```java
public static <T> Observable<T> create(ObservableOnSubscribe<T> source) 
  
 Observable<Integer> observable = Observable.create(new ObservableOnSubscribe<Integer>() {
          @Override
          public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
              emitter.onNext(1);
              emitter.onNext(2);
              emitter.onComplete();
          }
      });
```

*不推荐使用，使用较为繁琐且不方便操作。*

#### from系列

> 从指定的数据源中获取一个Observable对象

- `fromArray(T... items)`：从数组中获取
- `fromCallable(Callable<? extends T> supplier)`：从Callable对象中获取
- `fromFuture(Future<? extends T> future)`：从Future对象中获取
- `fromIterable(Iterable<? extends T> source)`：从Iterable中获取
- `formPublisher(Publisher<? extends T> publisher)`：从Publisher中获取

```java
Observable<Integer> observable = Observable.fromArray(1,2,3,4);
```

#### just

> 支持发送不同格式的参数，个数从1~10个

```java
public static <T> Observable<T> just(T item) 
 
Observable<Integer> observable = Observable.just(1,2);
```

#### interval&intervalRange

> 每隔指定时间就发射一个Observable对象

`interval`

```java
/**
* initialDelay 发射第一个对象之前的停顿时间
* period 表示每个发射之间停顿多少时间
* unit 时间单位
* scheduler 指定数据发射的线程
*/
public static Observable<Long> interval(long initialDelay, long period, TimeUnit unit, Scheduler scheduler)
其他重载方法：
public static Observable<Long> interval(long initialDelay, long period, TimeUnit unit)
public static Observable<Long> interval(long period, TimeUnit unit)  
   
Observable observable = Observable.interval(1, TimeUnit.SECONDS);
```

`intervalRange`：控制发射的序列在一个范围之内，发射最后一位时停止

```java
/**
* start 发射数据的起始值
* count 需要发射的总个数，且为递增
*/
public static Observable<Long> intervalRange(long start, long count, long initialDelay, long period, TimeUnit unit, Scheduler scheduler)
  
Observable<Long> observable =Observable.intervalRange(1,10,1,1, TimeUnit.SECONDS, Schedulers.trampoline());
```

#### range&rangeLong

> 发射指定范围内的连续整数的Observable对象

```java
/**
* start 指定生成序列的开始值
* count 指定生成序列包含的个数
*/
public static Observable<Integer> range(final int start, final int count)
Observable<Integer> observable = Observable.range(1,5);

public static Observable<Long> rangeLong(long start, long count) 
Observable<Long> observable = Observable.range(1,5);  
```

`range`与`rangeLong`的区别在于：前者返回int，后者返回long

#### defer

> 直到有观察者订阅是才创建的`Observable`对象，并未每一个订阅者都创建一个新的`Observable`对象。

```java
public static <T> Observable<T> defer(Callable<? extends ObservableSource<? extends T>> supplier) 
  
Observable<Long> deferObservable = Observable.defer(() -> Observable.just(11L));
```

**可以使用`defer`封装需要被多次执行的函数**

#### empty & never & error

`empty`：创建一个不发射任何数据但是能正常终止的`Observable`对象

```java
public static <T> Observable<T> empty()
  
Observable<Integer> observable = Observable.empty();
```

`error`：创建一个不发射任何数据但是能发出错误的`Observable`对象

```java
public static <T> Observable<T> error(Callable<? extends Throwable> errorSupplier)
  
Observable<Integer> observable = Observable.error(new IllegalArgumentException("qwe"));
```

`never`：创建一个不发射任何数据也不能终止的`Observable`对象

```java
public static <T> Observable<T> never()
  
Observable<Integer> observable = Observable.never()
```

#### repeat&repeatWhen

> 并不是创建一个`Observable`对象，而是重复发射原始的`Observable`数据序列，可能是无限的，如果设置`repeat(n)`可以限制重复次数

```java
//不限次数 
public final Observable<T> repeat()
//限制发射 times 次   
public final Observable<T> repeat(long times)
  
Observable<Integer> observable = Observable.just(1).repeat(3);
```

`repeatWhen`：重复执行同一操作

```java
public final Observable<T> repeatWhen(final Function<? super Observable<Object>, ? extends ObservableSource<?>> handler)

Observable<Long> observable = Observable.just(1L).repeatWhen(objectObservable -> Observable.just(1).repeat(3));

```

#### timer

> 创建一个在制定延迟时间后发射一条数据的`Observable`对象

```java
/**
* delay 设置延时时长
*/
public static Observable<Long> timer(long delay, TimeUnit unit) 
  
Observable<Long> observable = Observable.timer(3,TimeUnit.SECOND);
```

### 变换操作符

#### map

> 将发射的原始`Observable`对象转成一个新的`Observable`对象。

```java
/**
* 泛型T 指代原始数据类型
* 泛型R 指代要转换的数据类型
*/
public final <R> Observable<R> map(Function<? super T, ? extends R> mapper) 

Observable<String> observable = Observable.just(1L)/*这时发射出的是Long型*/.map(aLong -> aLong.toString()/*转化为String型*/);
```

*在定义的`Function()`中进行数据类型转换*

#### flatMap

> 将一个发送事件的原始`Observable`变换为多个发送事件的`Observables`，然后把这些合并到一个单独的`Observable`里。**`flatMap`并不保证事件的顺序，实现的是一对多的转化**

```java
public final <R> Observable<R> flatMap(Function<? super T, ? extends ObservableSource<? extends R>> mapper) 

Observable<String> observable = Observable.just(1L,2L,3L,4L,5L)
              .flatMap((Function<Long, ObservableSource<String>>) aLong -> 
                      Observable.just("flatMap"+aLong.toString()));
```

#### concatMap

> 将一个发送事件的原始`Observable`变换为多个发送事件的`Observables`，然后把这些合并到一个单独的`Observable`里。**concatMap可以保证事件的顺序，实现的是一对多的转化**

```java
 public final <R> Observable<R> concatMap(Function<? super T, ? extends ObservableSource<? extends R>> mapper, int prefetch)
   
Observable<String> observable = Observable.just(1L,2L,3L,4L,5L)
              .concatMap((Function<Long, ObservableSource<String>>) aLong -> 
                      Observable.just("flatMap"+aLong.toString()));
```

在使用`concatMap`的时候，内部会新建一个队列对象，会把先发射的数据放入队列中，内部是利用了`AtomicInteger`实现自增，然后输出数据的时候就可以按照顺序。

#### cast

> 将原始的`Observable`对象中的所有数据都强制转换为一个指定的类型(**多态，只能由父类对象转为子类对象**)，然后发射数据

```java
public final <U> Observable<U> cast(final Class<U> clazz) 
  
Observable<String> observable = Observable.just(1L).cast(String.class);
//这样子的转换方式就会抛出异常
```

#### flatMapIterable

> 将原始的任意一个元素转换成一个`Iterable`对象，直接在内部以`Iterable`接口接收数据。

```java
public final <U> Observable<U> flatMapIterable(final Function<? super T, ? extends Iterable<? extends U>> mapper)

Observable<String> observable = Observable.just(1L,2L,3L,4L,5L)
          .flatMapIterable(new Function<Long, Iterable<? extends String>>() {
              @Override
              public Iterable<? extends String> apply(Long aLong) throws Exception {
                  ArrayList<String> list = new ArrayList<>();
                  list.add(aLong.toString());
                  return list;
              }
          });
```

#### buffer

>  对整个流进行分组，将原先的`Observable`对象转换为一个新的`Observable`对象，每次发生一组值，而不是原先的一个个发送。

```java
/**
* count 成组的个数
* skip 隔几个输出一次 比如 1，2，3 设置skip=1,count=3 输出则为 [1,2,3],[2,3],[3]
*/
public final Observable<List<T>> buffer(int count, int skip)
public final Observable<List<T>> buffer(int count)//skip = count
  
Observable<String> observable = Observable.range(1, 20)
                .buffer(3, 1)
                .map(new Function<List<Integer>, String>() {
                    @Override
                    public String apply(List<Integer> lists) throws Exception {
                        return lists.toString();
                    }
                });
```

#### window

> 与`buffer`功能类似，但它发射出的是`Observable`，这些`Observable`在单独发射数据，都发送完毕后，发出`onComplete()`通知。

```java
public final Observable<Observable<T>> window(long count)
  
Observable.range(1, 10).window(3).subscribe(
        observable -> observable.subscribe(integer -> System.out.println(observable.hashCode() + " : " + integer)));
```



### 过滤操作符

#### filter

> 根据指定规则对发送数据进行过滤

```java
public final Observable<T> filter(Predicate<? super T> predicate)
 
Observable.range(1,10).filter(new Predicate<Integer>() {
            @Override
            public boolean test(Integer integer) throws Exception {
                //只输出大于5的值
                return integer>5;
            }
        })
```



#### elementAt&firstElement&lastElement

> `elementAt`：用于获取数据源中的指定位置的数据
>
> `firstElement`：用于获取数据源中的第一个元素
>
> `lastElement`：用于获取数据源中的最后一个元素

```java
public final Maybe<T> elementAt(long index)

Observable.range(0, 5).elementAt(3);
```



#### distinct&distinctUntilChanged

> `distinct`：对数据源中的重复数据进行过滤
>
> `distinctUntilChanged`：只会过滤相邻的两个相同元素

```java
public final Observable<T> distinct()
  
Observable.just(1,2,3,4,5,6,5).distinct() => 1,2,3,4,5,6  
Observable.just(1,2,3,4,5,6,5).distinctUntilChanged() => 1,2,3,4,5,6,5
```



#### skip&skipLast

> `skip`：对数据源中的前几项进行过滤
>
> `skipLast`：对数据源中的后几项进行过滤，以及最后的一段时间不发射数据。

```java
public final Observable<T> skip(long count)
Observable.just(1,2,3,4,5,6,5).skip(3) => 4,5,6,5
  
//隔一段时间后，开始输出数据  
public final Observable<T> skip(long time, TimeUnit unit)
Observable.just(1,2,3,4,5,6,5).skip(1,TimeUnit.SECONDS) => 1,2,3,4,5,6,5
  
public final Observable<T> skipLast(long count)
Observable.just(1,2,3,4,5,6,5).skipLast(3) => 1,2,3,4
```

#### take&takeLast

> `take`：取出数据源的前几项数据
>
> `takeLast`：取出数据源的后几项数据

```java
public final Observable<T> take(long count)
Observable.just(1,2,3,4,5,6,5).take(3) =>1,2,3
//取出前time秒中输出的数据
public final Observable<T> take(long time, TimeUnit unit)
Observable.just(1,2,3,4,5,6,5).repeat(1).take(100,TimeUnit.MILLISECONDS) => 1,2,3,4,5,6,5

public final Observable<T> takeLast(long count)
Observable.just(1,2,3,4,5,6,5).takeLast(3)
```



#### ignoreElements

> 过滤所有Observable对象发射的数据，只允许`onError()`或`onComplete()`发送

```java
public final Completable ignoreElements()
  
Observable.just(1,2,3,4,5,6,5).ignoreElements().subscribe(new CompletableObserver() {
            @Override
            public void onSubscribe(Disposable disposable) { }
            @Override
            public void onComplete() { }
            @Override
            public void onError(Throwable throwable) { }
        });
```



#### throttleFirst & throttleLast&throttleLatest

> `throttleFirst`：对输出的数据进行限制，按照指定的参数对时间进行分片，然后选择每个时间片中的第一条数据
>
> `throttleLast`：对输出的数据进行限制，按照指定的参数对时间进行分片，然后选择每个时间片中的最后一条数据
>
> `throttleLatest`：读书处的数据进行限制，按照指定的参数对时间进行分片，然后选择每个时间片中的最近数据

```java
public final Observable<T> throttleFirst(long skipDuration, TimeUnit unit, Scheduler scheduler)
 Observable.just(1,2,3,4,5,6,5).delay(50,TimeUnit.MILLISECONDS,Schedulers.trampoline()).
                throttleFirst(100,TimeUnit.MILLISECONDS) => 1,3,5,5
  
public final Observable<T> throttleLast(long skipDuration, TimeUnit unit, Scheduler scheduler)   Observable.just(1,2,3,4,5,6,5).delay(50,TimeUnit.MILLISECONDS,Schedulers.trampoline()).
                throttleLast(100,TimeUnit.MILLISECONDS) => 2,4,6,5
  
public final Observable<T> throttleLatest(long skipDuration, TimeUnit unit, Scheduler scheduler)   
Observable.just(1,2,3,4,5,6,5).delay(50,TimeUnit.MILLISECONDS,Schedulers.trampoline()).
                throttleLatest(100,TimeUnit.MILLISECONDS) => 1,3,5,6
```



#### throttleWithTomeOut

> 数据源发射数据时，如果两次数据的发射间隔小于指定时间，就会丢弃前一次的数据,直到指定时间内都没有新数据发射时才进行发射 

```java
public final Observable<T> throttleWithTimeout(long timeout, TimeUnit unit, Scheduler scheduler)

 Observable.just(1,2,3,4,5,6,5).delay(120,TimeUnit.MILLISECONDS,Schedulers.trampoline()).
                throttleWithTimeout(200,TimeUnit.MILLISECONDS) => 5  
  
```



#### debounce

> 限制发射频率过快的，它仅在过了一段指定的时间还没发射数据时才发射一个数据。功能与`throttleWithTimeout`相似

```java
public final Observable<T> throttleWithTimeout(long timeout, TimeUnit unit) {
        return debounce(timeout, unit);
    }    

public final Observable<T> debounce(long timeout, TimeUnit unit) {
        return debounce(timeout, unit, Schedulers.computation());
    }
```



### 组合操作符

#### startWith&startWithArray

> `startWith`：在指定数据源之前插入数据
>
> `startWithArray`：在指定数据之前插入数组

```java
//插入单个数据
public final Observable<T> startWith(T item)
//插入实现Iterable接口的对象
public final Observable<T> startWith(Iterable<? extends T> items)
  
Observable.just(1,2,3,4).startWith(0) => 0,1,2,3,4

//插入多个数据
public final Observable<T> startWithArray(T... items)
Observable.just(1,2,3,4).startWithArray(0,0,0) => 0,0,0,1,2,3,4
```

#### merge&mergeArray

> `merge`：可以将多个数据源的数据合并起来进行发射，可能导致合并后的数据交错发射。
>
> `mergeArray`：插入的是一个`Observable`数组

```java
public static <T> Observable<T> merge(Iterable<? extends ObservableSource<? extends T>> sources)
  
  
Observable<String > ob1 = Observable.just(1,2,3,4);
Observable<String > ob2 = Observable.just(1,2,3,4);
Observable.mergeArray(ob1,ob2)
```

`mergeError`是一个特殊示例，会等到所有数据发射完毕，才抛出`onError`事件

#### concat&concatArray

> 会将多个`Observable`对象合并到一个`Observable`对象中进行发送且**严格按照顺序发射**。

{% fullimage /images/RxJava-concat.webp,conact操作符,conact操作符%}

```java
Observable<String > ob1 = Observable.just(1,2,3,4);
Observable<String > ob2 = Observable.just(1,2,3,4);
Observable.concatArray(ob1,ob2)
```

#### zip&zipArray&zipIterable

> 按顺序结合两个或多个`Observable`对象，然后返回结果。**严格按照顺序进行发射，他的总发射数与数据项最少的`Observable`对象数据相同。**

```java
Observable.zip(Observable.range(1, 6), Observable.range(1, 5),(integer, integer2) -> integer*integer2).subscribe(o -> System.err.println(o));

1,4,9,16,25
```

{% fullimage /images/RxJava-zip.webp,zip操作符,zip操作符%}

#### combineLastest

> 当两个Observable中的任何一个发送了数据时，使用一个函数结合每个`Observable`的最近数据项，并且基于这个结果发送数据。

{% fullimage /images/RxJava-combineLatest.png,combineLatest操作符,combineLatest操作符%}

```java
Observable.combineLatest(Observable.range(1, 6),Observable.range(1,5),(integer, integer2) -> integer*integer2).subscribe(o -> System.err.println(o));

//此时第一个Observable输出完毕，最终得到6，在与后续的增加数据相乘
6,12,18,24,32
```



### 辅助操作符

#### delay

> 设置数据发射前的停顿时间

```java
public final Observable<T> delay(long delay, TimeUnit unit)

Observable.just(1,2,3,4).delay(200,TimeUnit.MILLISECONDS)
```



#### do系列

> 用于监听数据回调

- `doAfterNext`：在`onNext()`之后回调
- `doOnNext`：调用`onNext()`时回调
- `doOnSubscribe`：观察者订阅时触发
- `doOnError`：调用`onError()`时触发
- `doOnComplete`：调用`onComplete()`时触发
- `doOnTerminate`：Observable终止前触发
- `doOnEach`：每次调用`onNext()`时触发
- `doOnDispose`：调用`Disposable.dispose()`时触发
- `doFinally`：调用`onError()`或`onComplete()`时触发
- `doAfterTerminate`：Observable终止后触发

#### subscribeOn

> 指定发射器所在的线程，即`Observable.onScuscribe`的所处线程，或者叫做事件产生的线程

```java
Observable.just(1).subscribeOn(Schedules.io)
```



#### observeOn

> 指定Subscriber所在线程，或者叫做事件消费的线程。

```java
Observable.just(1).subscribeOn(Schedules.io).obServerOn(AndroidSchedulers.mainThread())
```



#### timeout

> 用来设置一个超时时间，如果在指定时间内没有任何数据被发送出来，就会执行指定的数据项。

```java
Observable.just(1L,2L,3L)
      .timeout(500, TimeUnit.MILLISECONDS, Observable.rangeLong(1, 5))
      .subscribe(System.out::print);
输出结果：123

Thread.sleep(2000);
输出结果：12345
```



### 错误处理操作符

#### catch

> 拦截原始的`onError`通知，把它进行替换为其他的Observable对象，使原来的可以正常终止甚至不终止。

- `onErrorReturn`：在触发`onError`时，调用用户自定义的返回请求，实质上就是在调用一次`onNext`之后结束请求。

  ```java
  Observable.create(new ObservableOnSubscribe<Object>() {
              @Override
              public void subscribe(ObservableEmitter<Object> observableEmitter) throws Exception {
                  observableEmitter.onNext(1);
                  observableEmitter.onNext(2);
                  observableEmitter.onError(new IllegalArgumentException("11"));
                  observableEmitter.onNext(1);
              }
          }).onErrorReturn(new Function<Throwable, Object>() {
  
              @Override
              public Object apply(Throwable throwable) throws Exception {
                  return 123;
              }
          })
    
  输出结果：1 2 123
  ```

  

- `onErrorResumeNext`：在触发`onError`时，立即停止原Observable的数据发射，并采用新的Observable对象进行新的数据发射

  ```java
          Observable.create(observableEmitter -> {
              observableEmitter.onNext(1);
              observableEmitter.onNext(2);
              observableEmitter.onError(new IllegalArgumentException("11"));
              observableEmitter.onNext(1);
          }).onErrorResumeNext(Observable.range(1,3))
            
  输出结果： 1 2 1 2 3
  ```

  

- `onExceptionResumeNext`：如果`onError`触发时收到的不是`Exception`，就会将错误正确传递下去，而不是用用户自定义的Observable对象

  ```java
   Observable.create(observableEmitter -> {
              observableEmitter.onNext(1);
              observableEmitter.onNext(2);
              //observableEmitter.onError(new IllegalArgumentException("11"));
              // 输出结果为 抛出异常
              observableEmitter.onError(new NoSuchMethodError("11"));
              //输出结果为 1 2 1 2 3
              observableEmitter.onNext(1);
          }).onExceptionResumeNext(Observable.range(1,3))
  ```

  

#### retry

> 实现了一种错误重试机制，再出现错误的时候进行重试，可以通过参数指定重试的条件。

{% fullimage /images/RxJava-retry.webp,retry操作符,retry操作符%}

- `retry()`：无限次重试

- `retry(long times)`：指定次数的重试

  ```java
   Observable.create(observableEmitter -> {
              observableEmitter.onNext(1);
              observableEmitter.onNext(2);
              observableEmitter.onError(new IllegalArgumentException("11"));
              observableEmitter.onNext(123);
          }).retry(2);
  输出结果： 1 2 1 2 抛出异常
  ```

  

- `retry(BiPredicate<? super Integer, ? super Throwable> predicate)`：指定一定规则进行重试

  ```java
   Observable.create(observableEmitter -> {
              observableEmitter.onNext(1);
              observableEmitter.onNext(2);
              observableEmitter.onError(new IllegalArgumentException("11"));
              observableEmitter.onNext(123);
          }).retry(new BiPredicate<Integer, Throwable>() {
              @Override
              public boolean test(Integer integer, Throwable throwable) throws Exception {
                  //integer 为重试次数 return true代表继续重试 false 代表抛出异常
                  return integer<2;
              }
          })
  ```



### 条件操作符

#### all&any

> `all`：判断数据源中是否所有数据都满足指定要求，可以使用一个函数表示
>
> `any`：判断数据源中是否存在满足要求的数据

```java
public final Single<Boolean> all(Predicate<? super T> predicate)
Observable.just(1,2,3,4).all(integer -> integer < 5) => true
  
public final Single<Boolean> any(Predicate<? super T> predicate)
Observable.just(1,2,3,4).all(integer -> integer < 2) => true 
```



#### contains&isEmpty

> `contains`：判断数据源中是否包含指定项
>
> `isEmpty`：数据源是否为空

```java
public final Single<Boolean> contains(final Object element)
Observable.just(1,2,3,4).contains(2) => true
  
public final Single<Boolean> isEmpty()
Observable.just(1,2,3,4).isEmpty() => false 
```



#### sequenceEqual

> 用来判断两个Observable对象的发射序列是否相等(*包含数据，发射顺序，终止状态等*)

```java
public static <T> Single<Boolean> sequenceEqual(ObservableSource<? extends T> source1, ObservableSource<? extends T> source2) 

Observable.sequenceEqual(Observable.range(1,6),
                Observable.range(1,5))
                .subscribe(new Consumer<Boolean>() {
                    @Override
                    public void accept(Boolean aBoolean) throws Exception {
                        System.err.println(aBoolean);
                    }
                });

输出结果：false
```



#### amb

> 作用于两个或多个`Observable`对象，但是只会发射最初的Observable对象数据。

{% fullimage /images/RxJava-amb.webp,amb操作符,amb操作符%}

```java
Observable.amb(Arrays.asList(Observable.range(1,6),
                Observable.range(1,5)))
   
输出结果： 1 2 3 4 5 6
```

#### defaultIfEmpty

> 当数据源的数据为空时指定发送一个数据

```java
Observable.create(observableEmitter -> {
    observableEmitter.onComplete();
  }).defaultIfEmpty(777)
   
输出结果： 777   
```



### 转换操作符

#### toList&toSortedList

> 将数据发射序列转成列表，`toSortedList`转成升序列表

```java
public final Single<List<T>> toList()
Observable.just(1,2,5,6,4,3).toList() => 1,2,5,6,4,3
  
public final Single<List<T>> toSortedList()
Observable.just(1,2,5,6,4,3).toSortedList() => 1,2,3,4,5,6

//支持自定义比较规则
public final Single<List<T>> toSortedList(final Comparator<? super T> comparator)
Observable.just(1,2,5,6,4,3).toSortedList(Comparator.comparingInt(value -> -value)) => 6,5,4,3,2,1
```



#### toMap&toMultiMap

> 将发射的数据转换成另一个类型的值，转换过程是针对每一个数据项的。**源Observable的每一项数据作为value，然后用户自定义生成key的函数，最终得到Map型的结果。**
>
> `toMultiMap`可以转换成一个集合对象

{% fullimage /images/RxJava-toMap.webp,toMap操作符,toMap操作符%}

```java
Observable.just(1,2,5)
        .toMap(new Function<Integer, Object>() {
            @Override
            public Object apply(Integer integer) throws Exception {
                return integer + 1;
            }
        })
  
输出结果：[2=1，3=2，6=5]

Observable.just(1,2,3)
               .toMultimap(new Function<Integer, Object>() {
                   @Override
                   public Object apply(Integer integer) throws Exception {
                       return integer+1;
                   }
               })
  
输出结果：{2=[1], 3=[2], 4=[3]}
```

#### toFlowable

> 用于讲一个`Observable`对象转成`Flowable`对象。

#### to

> 可以将一个`Observable`对象转成任意类型



## RxJava线程类型

RxJava的线程控制是通过`subscribeOn`以及`observeOn`来进行控制的。接下来列举一下RxJava中提供的线程调度器以及`RxAndroid`提供的主线程调度器。

- `Schedulers.io()`：适用于io操作(*在Android中指代子线程*)，增长或缩减来自适应的线程池，通常用于访问网络，读写文件等操作。采用的线程池是`CachedThreadPool`，是无限制的，但是大量创建线程就会影响性能。
- `Schedulers.computation()`：计算工作默认的调度器，与I/O操作无关
- `Schedulers.newThread()`：代表常规的一个新线程
- `Schedulers.immdiate()`：允许你立即在当前线程执行任务
- `Schedulers.trampoline()`：当我们想执行一个任务时，并非立即执行，使用`trampoline()`执行入队。*将会处理它的队列并且按序运行队列中每一个任务*
- `AndroidSchedulers.mainThread()`：指代Android系统中的主线程

## RxJava基本流程分析

```java
 Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> observableEmitter) throws Exception {
                observableEmitter.onNext(123);
                observableEmitter.onComplete();
            }
        }).subscribeOn(AndroidSchedulers.mainThread())
   .observerOn(Schedulers.io())
   .subscribe(new Observer<Integer>() {
            @Override
            public void onSubscribe(Disposable disposable) {

            }

            @Override
            public void onNext(Integer integer) {
                System.err.println(integer);
            }

            @Override
            public void onError(Throwable throwable) {

            }

            @Override
            public void onComplete() {

            }
        });
```

以上是最基础的RxJava使用流程，从这段代码中进行原理分析。

### 创建Observable

从`Observable.create()`开始

```java
    public static <T> Observable<T> create(ObservableOnSubscribe<T> source) {
        ObjectHelper.requireNonNull(source, "source is null");
        //大致流程就是 新建了一个ObservableCreate对象
        return RxJavaPlugins.onAssembly(new ObservableCreate<T>(source));
    }
```

1. Observable先调用`create()`
2. `create()`中传入`ObservableOnSubscribe`对象
3. 通过`new ObservableCreate()`得到最终Observable对象

```java ObservableCreate.java
   //外部传进来的 ObservableOnSubscribe实例 
   final ObservableOnSubscribe<T> source;
 
    public ObservableCreate(ObservableOnSubscribe<T> source) {
        this.source = source;
    }

    @Override
    protected void subscribeActual(Observer<? super T> observer) {
        CreateEmitter<T> parent = new CreateEmitter<T>(observer);
        observer.onSubscribe(parent);

        try {
            source.subscribe(parent);
        } catch (Throwable ex) {
            Exceptions.throwIfFatal(ex);
            parent.onError(ex);
        }
    }
```

{% fullimage /images/Observable创建流程.png,Observable创建流程,Observable创建流程%}

### Observable订阅

通过`Observable.subscribe()`执行订阅流程

```java
 public final void subscribe(Observer<? super T> observer) {
        ObjectHelper.requireNonNull(observer, "observer is null");
        try {
            observer = RxJavaPlugins.onSubscribe(this, observer);

            ObjectHelper.requireNonNull(observer, "The RxJavaPlugins.onSubscribe hook returned a null Observer. Please change the handler provided to RxJavaPlugins.setOnObservableSubscribe for invalid null returns. Further reading: https://github.com/ReactiveX/RxJava/wiki/Plugins");

            subscribeActual(observer);①
        } catch (NullPointerException e) { // NOPMD
            throw e;
        } catch (Throwable e) {
            Exceptions.throwIfFatal(e);
            RxJavaPlugins.onError(e);
            NullPointerException npe = new NullPointerException("Actually not, but can't throw other exceptions due to RS");
            npe.initCause(e);
            throw npe;
        }
    }

protected abstract void subscribeActual(Observer<? super T> observer);

//ObservableCreate.java 子类实现该方法
protected void subscribeActual(Observer<? super T> observer) {
        CreateEmitter<T> parent = new CreateEmitter<T>(observer);
        //执行Observer的onSubscribe()进行事件分发
        observer.onSubscribe(parent);

        try {
            //向上调用上层的Observer的subscribe()
            source.subscribe(parent);
        } catch (Throwable ex) {
            Exceptions.throwIfFatal(ex);
            parent.onError(ex);
        }
    }
```

在`subscribe()`中会调用到抽象方法`subscribeActual()`，就拿上节的`ObservableCreate`来说，他的内部就实现了`subscribeActual()`。

在`subscribe()`传入的参数为`Observer`类型即观察者。

{% fullimage /images/Observable订阅流程.png,Observable订阅流程,Observable订阅流程%}

> `Observable.subscribe()`调用到`Observable.subscribeActual()`，由子类进行覆盖重写(**多态**)，在其中执行的代码主要分为两部分：
>
> `Observerable.subscribe`：真正的订阅流程从这里开始
>
> `Observer.onSubscribe`：在其中进行事件分发

### 线程切换

RxJava通过`subscribeOn()`和`observerOn()`来进行线程的切换。如果未去设置线程切换相关参数，那么执行的线程都会为当前线程。

#### Observable.observeOn

> 切换`subscribe()`的运行线程

从`Observable.observeOn()`开始进行分析

```java
public final Observable<T> observeOn(Scheduler scheduler) {
        return observeOn(scheduler, false, bufferSize());
    }

public final Observable<T> observeOn(Scheduler scheduler, boolean delayError, int bufferSize) {
        ObjectHelper.requireNonNull(scheduler, "scheduler is null");
        ObjectHelper.verifyPositive(bufferSize, "bufferSize");
        //this 指代了当前的Observable对象， scheduler就是指我们设置的 切换线程
        return RxJavaPlugins.onAssembly(new ObservableObserveOn<T>(this, scheduler, delayError, bufferSize));
    }
```

通过`Observable.observeOn()`运行之后得到了`ObservableObserveOn`对象。

```java ObservableObserveOn.java
    @Override
    protected void subscribeActual(Observer<? super T> observer) {
        if (scheduler instanceof TrampolineScheduler) {
            //无需执行任何线程操作
            source.subscribe(observer);
        } else {
            //scheduler指代传进来的线程调度对象
            Scheduler.Worker w = scheduler.createWorker();
            source.subscribe(new ObserveOnObserver<T>(observer, w, delayError, bufferSize));
        }
    }
```

调用`ObservableObserveOn.subscribeActual()`后，会生成`ObserveOnObserver`对象，由该对象对`ObserveableObserveOn`进行监听

```java ObservableObserveOn.java
  @Override
        public void onNext(T t) {
            if (done) {
                return;
            }
            if (sourceMode != QueueDisposable.ASYNC) {
                //添加当前事件到队列中
                queue.offer(t);
            }
            //执行线程切换
            schedule();
        }

        void schedule() {
            if (getAndIncrement() == 0) {
                worker.schedule(this);
            }
        }
```

例如发送一个`onNext()`事件，就会执行到`schedule()`进行线程切换(如果设置)。`worker`对应新建`ObserveOnObserve`对象时的传入参数——用户自定义的`Schedulers`。此处拿`IoScheduler`举例，用于子线程执行操作。

```java IoScheduler.java
//Scheduler.java
public abstract static class Worker implements Disposable
        @NonNull
        public Disposable schedule(@NonNull Runnable run) {
            return schedule(run, 0L, TimeUnit.NANOSECONDS);
        }
}

static final class EventLoopWorker extends Scheduler.Worker{
@NonNull
        @Override
        public Disposable schedule(@NonNull Runnable action, long delayTime, @NonNull TimeUnit unit) {
            if (tasks.isDisposed()) {
                // don't schedule, we are unsubscribed
                return EmptyDisposable.INSTANCE;
            }

            return threadWorker.scheduleActual(action, delayTime, unit, tasks);
        }
}

    static final class ThreadWorker extends NewThreadWorker {
        private long expirationTime;

        ThreadWorker(ThreadFactory threadFactory) {
            super(threadFactory);
            this.expirationTime = 0L;
        }

        public long getExpirationTime() {
            return expirationTime;
        }

        public void setExpirationTime(long expirationTime) {
            this.expirationTime = expirationTime;
        }
    }
```

假设设置子线程执行即`Schedulers.io()`，那么会优先调用到`Schedulers.schedule()`由于子类没有实现该方法，所以上溯到父类中的实现。

调用到`schedule()`之后，，就会调用到`IoScheduler.schedule()`中，再切换到了`NewThreadWorker.scheduleActual()`中

```java NewThreadWorker.java
    public ScheduledRunnable scheduleActual(final Runnable run, long delayTime, @NonNull TimeUnit unit, @Nullable DisposableContainer parent) {
        Runnable decoratedRun = RxJavaPlugins.onSchedule(run);
        ScheduledRunnable sr = new ScheduledRunnable(decoratedRun, parent);
        if (parent != null) {
            if (!parent.add(sr)) {
                return sr;
            }
        }

        Future<?> f;
        try {
            if (delayTime <= 0) {
              //executor 指代一个线程池对象
                f = executor.submit((Callable<Object>)sr);
            } else {
                f = executor.schedule((Callable<Object>)sr, delayTime, unit);
            }
            sr.setFuture(f);
        } catch (RejectedExecutionException ex) {
            if (parent != null) {
                parent.remove(sr);
            }
            RxJavaPlugins.onError(ex);
        }

        return sr;
    }
```

在`NewThreadWorker.scheduleActual()`主要执行的是使用线程池调用`submit()`或`execute()`去启动线程。经过层层传递最后调用到`ObserveableObserveOn.run()`

```java ObserveableObserveOn.java
        @Override
        public void run() {
            if (outputFused) {
                drainFused();
            } else {
                drainNormal();
            }
        }

void drainNormal() {
           ...
            for (;;) {
                if (checkTerminated(done, q.isEmpty(), a)) {
                    return;
                }

                for (;;) {
                    boolean d = done;
                  ...

                    a.onNext(v);
                }
             ...
            }
        }
```

层层回调到`run()`后，在其中会继续执行`onNext()`此时线程已经切换成功。

**最终实现的是将目标Observe中的`onNext()，onError(),onComplete()`置于指定线程中运行。**

//TODO 流程图

#### Observable.subscribeOn

> 切换`Observable`的运行线程

同上，先从`Observable.subscribeOn()`开始分析

```java Observable.java
    public final Observable<T> subscribeOn(Scheduler scheduler) {
        ObjectHelper.requireNonNull(scheduler, "scheduler is null");
        return RxJavaPlugins.onAssembly(new ObservableSubscribeOn<T>(this, scheduler));
    }
```

操作的对象为`ObservableSubscribeOn`

```java ObservableSubscribeOn.java
    @Override
    public void subscribeActual(final Observer<? super T> observer) {
        final SubscribeOnObserver<T> parent = new SubscribeOnObserver<T>(observer);
        //调用 onSubscribe() 回调
        observer.onSubscribe(parent);
        //此处调用线程切换
        parent.setDisposable(scheduler.scheduleDirect(new SubscribeTask(parent)));
    }
```

这里我们假设使用的是`IoScheduler`，就调用到`IoScheduler.scheduleDirect()`

```java Scheduler.java
public Disposable scheduleDirect(@NonNull Runnable run) {
        return scheduleDirect(run, 0L, TimeUnit.NANOSECONDS);
    }

    @NonNull
    public Disposable scheduleDirect(@NonNull Runnable run, long delay, @NonNull TimeUnit unit) {
        final Worker w = createWorker();
        final Runnable decoratedRun = RxJavaPlugins.onSchedule(run);
        DisposeTask task = new DisposeTask(decoratedRun, w);
        w.schedule(task, delay, unit);
        return task;
    }
```

最后调用到`DisposeTask.run()`方法去执行切换

```java Scheduler.java
static final class DisposeTask implements Disposable, Runnable, SchedulerRunnableIntrospection {
public void run() {
            runner = Thread.currentThread();
            try {
                decoratedRun.run();
            } finally {
                dispose();
                runner = null;
            }
        }
}
```

`decoratedRun`指的就是上面传进来的`SubscribeTask`，有执行到了它的`run()`

```java ObservableSubscribeOn.java
    final class SubscribeTask implements Runnable {
        private final SubscribeOnObserver<T> parent;

        SubscribeTask(SubscribeOnObserver<T> parent) {
            this.parent = parent;
        }

        @Override
        public void run() {
            source.subscribe(parent);
        }
    }
```

此时线程已经完成了切换工作。

> 第一次有效。

#### `AndroidSchedulers.mainThread()`

由RxAndroid提供的Android主线程切换器

```java AndroidSchedulers.java
    private static final class MainHolder {
        static final Scheduler DEFAULT
            = new HandlerScheduler(new Handler(Looper.getMainLooper()), false);
    }

    private static final Scheduler MAIN_THREAD = RxAndroidPlugins.initMainThreadScheduler(
            new Callable<Scheduler>() {
                @Override public Scheduler call() throws Exception {
                    return MainHolder.DEFAULT;
                }
            });

    /** A {@link Scheduler} which executes actions on the Android main thread. */
    public static Scheduler mainThread() {
        return RxAndroidPlugins.onMainThreadScheduler(MAIN_THREAD);
    }

    /** A {@link Scheduler} which executes actions on {@code looper}. */
    public static Scheduler from(Looper looper) {
        return from(looper, false);
    }
```

`mainThread()`里面新建了一个`Handler`对象用来切换至主线程，还支持通过`from()`设置自定义Looper来切换到其他线程。

RXJava设置线程切换时，需要通过`Scheduler.createWorker()`来生成对应线程切换器

```java HadnlerScheduler.java
final class HandlerScheduler extends Scheduler{
   @Override
    @SuppressLint("NewApi") // Async will only be true when the API is available to call.
    public Disposable scheduleDirect(Runnable run, long delay, TimeUnit unit) {
        if (run == null) throw new NullPointerException("run == null");
        if (unit == null) throw new NullPointerException("unit == null");

        run = RxJavaPlugins.onSchedule(run);
        ScheduledRunnable scheduled = new ScheduledRunnable(handler, run);
        Message message = Message.obtain(handler, scheduled);
        if (async) {
            message.setAsynchronous(true);
        }
        handler.sendMessageDelayed(message, unit.toMillis(delay));
        return scheduled;
    }

    @Override
    public Worker createWorker() {
        return new HandlerWorker(handler, async);
    }
}

private static final class HandlerWorker extends Worker {
   public Disposable schedule(Runnable run, long delay, TimeUnit unit) {
            ScheduledRunnable scheduled = new ScheduledRunnable(handler, run);
            Message message = Message.obtain(handler, scheduled);
            message.obj = this; // Used as token for batch disposal of this worker's runnables.
            if (async) {
                message.setAsynchronous(true);
            }
            handler.sendMessageDelayed(message, unit.toMillis(delay));
            if (disposed) {
                handler.removeCallbacks(scheduled);
                return Disposables.disposed();
            }
   }
  
         @Override
        public void dispose() {
            disposed = true;
            handler.removeCallbacksAndMessages(this /* token */);
        }
}
```

在`dispose()`时通过移除对应的消息来取消订阅

### 事件分发

### 取消订阅

通过`Disposable.dispose()`可以取消相关订阅

## 内容引用

[RxJava1](<https://www.jianshu.com/p/a9ebf730cd08>)

[RxJava2](https://juejin.im/post/5a248206f265da432153ddbc#heading-9)

[RxJava3](https://juejin.im/post/5b72f76551882561354462dd#heading-9)

[RxJava4](https://www.cherylgood.cn/?keyword=Rxjava)

[RxJava5](https://www.jianshu.com/p/88aa273d37be)

[RxJava6](https://mp.weixin.qq.com/s?__biz=MzIwMzYwMTk1NA==&mid=2247490701&idx=1&sn=a7cef1ae9c59c3c60af2b15f7939799d&chksm=96cdbdc0a1ba34d605cad73ba1dd0d81059ced9fc1c067b9593403a283414db07cca4d7459fe&mpshare=1&scene=23&srcid=1015rFqxIvHGW6R8HsZQpPwj%23rd)

