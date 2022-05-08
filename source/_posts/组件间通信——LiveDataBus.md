---
title: 组件间通信——LiveDataBus
date: 2019-03-21 20:27:58
tags: Android
top: 10
---

> `LiveData`是一个可以被观察的数据持有类，可以感知并遵循`Activity、Fragment，Service`等组件的生命周期。由于这种特性可以使他做到在特定生命周期执行特定的操作。

`LiveData`优点：

- **UI和实时数据保持一致**：可以在数据发生改变时立即响应到
- **避免内存泄漏**：当绑定的组件被销毁时，会自动清理数据以及移除引用，避免泄漏



根据上述优点，就可以利用`LiveData`去实现一个组件间通信的方案，这套方案相对于`EventBus`、`RxBus`有着明显的优势，不需要显式的去调用反注册方法(*以免内存泄漏*)，而且其自带生命周期感知，可以在Activity等组件处于前台状态时，进行UI更改，避免浪费资源。



## LiveDataBus的组成

- **消息**：用于在组件中通信所传递的数据，可能是基本类型也可能是自定义Model
- **消息通道**：用消息通道来甄别不同的LiveData(*处理对象*)
- **订阅者**：通过消息通道获取对应的`LiveData`，调用`observe()`进行订阅
- **发布者**：通过消息通道获取对应的`LiveData`，调用`postValue()、setValue()`进行消息发送

{% fullimage /images/LiveDataBus结构.png,LiveDataBus结构,LiveDataBus结构%}



## LiveDataBus的实现

按照上述结构图，可以马上就写出一个大致结构

```kotlin
class LiveDataBus private constructor() {
    //用于存放消息通道
    private val map: MutableMap<String, MutableLiveData<Any>?>

    init {
        map = HashMap()
    }

    fun <T> getChannel(target: String, type: Class<T>): MutableLiveData<T> {
        if (!map.containsKey(target)) {
            map[target] = MutableLiveData()
        }
        return map[target] as MutableLiveData<T>
    }

    fun getChannel(target: String): MutableLiveData<Any> {
        return getChannel(target, Any::class.java)
    }

    companion object {
        val instance: LiveDataBus by lazy { LiveDataBus() }
    }
}
```

对应发送数据方法

```kotlin
//同步发送
LiveDataBus.instance.getChannel("web", String::class.java).value = "ssa"
//异步发送
LiveDataBus.instance.getChannel("web",String::class.java).postValue("ssa")
```

对应接收数据方法

```kotlin
LiveDataBus.instance.getChannel("web", String::class.java)
           .observe(this@MainActivity, Observer { s ->
                Log.e("web", s)
           })
```

但是在实际的使用过程中发现了另一个问题，再打开一个新页面时，如果也存在监听者，就会收到该页面打开前所发送的消息，类似*粘性事件*，但大部分场景下是不需要这样的，所以需要针对这个问题进行改进。

## LiveDataBus改进

根据{% post_link LiveData简析%}这部分源码分析可知，LiveData中的数据分发流程如下图所示：

{% fullimage /images/LiveData-dispatch.png,LiveData Dispatch,LiveData Dispatch%}

根据上述流程分析：调用到`setValue()/postValue()`将用户数据进行发送，然后进入到`dispatchValue()`下进行分发，设置`mVersion++(mVersion表示调用方法次数)`，想下调用到`considerNotify()`内部需要判断`observer.mLastVersion(Observer注册次数)`与`mVersion`大小，如果小于就会调用到对应`Observer.onChanged()`事件进行分发。

*由于初始化时，先会调用到`postValue()/setValue()`此时mVersion+1，就比`mLastVersion`要大，就会触发事件的分发。*

### 改进方案

**只要可以设置`mLastVersion`与`mVersion`保持一致，就不会进行事件的分发。**

此时需要利用**反射**的方式对`LiveData`中的数据进行改变，首先按照需求，先要找到`Observer`，然后修改其中的`mLastVersion`即可。

```java LiveData.java
 @MainThread
    public void observe(@NonNull LifecycleOwner owner, @NonNull Observer<T> observer) {
        if (owner.getLifecycle().getCurrentState() == DESTROYED) {
            // ignore
            return;
        }
        LifecycleBoundObserver wrapper = new LifecycleBoundObserver(owner, observer);
        //存储所有的Observer对象
        ObserverWrapper existing = mObservers.putIfAbsent(observer, wrapper);
        if (existing != null && !existing.isAttachedTo(owner)) {
            throw new IllegalArgumentException("Cannot add the same observer"
                    + " with different lifecycles");
        }
        if (existing != null) {
            return;
        }
        owner.getLifecycle().addObserver(wrapper);
    }
```

需要从`mObservers`中入手，然后找到对应`Observer`即可。

> 除了`observer()`外，还有一个`observerForever()`，该方法是一直存在监听的，而且不会绑定对应的组件，所以可以在任意组件中监听到事件，如果使用时，需要注意销毁。

### 改进代码

```kotlin
package com.wxy.router.eventbus.utils

import android.arch.lifecycle.LifecycleOwner
import android.arch.lifecycle.LiveData
import android.arch.lifecycle.MutableLiveData
import android.arch.lifecycle.Observer

import android.icu.lang.UCharacter.GraphemeClusterBreak.T
import java.lang.Exception
import java.lang.NullPointerException
import java.util.*


class LiveDataBus private constructor() {

    //用于存放消息通道
    private val map: MutableMap<String, BusMutableLiveData<Any>?>

    init {
        map = HashMap()
    }

    fun <T> getChannel(target: String, type: Class<T>): BusMutableLiveData<T> {
        if (!map.containsKey(target)) {
            map[target] = BusMutableLiveData()
        }
        return map[target] as BusMutableLiveData<T>
    }

    fun getChannel(target: String): BusMutableLiveData<Any> {
        return getChannel(target, Any::class.java)
    }

    companion object {
        val instance: LiveDataBus by lazy { LiveDataBus() }
    }

    //Observer装饰类
    class ObserverWrapper<T>() : Observer<T> {

        private var observer: Observer<T>? = null

        constructor(observer: Observer<T>) : this() {
            this.observer = observer
        }

        override fun onChanged(t: T?) {
            observer?.let {
                if (isCallOnObserve()) return@let
                it.onChanged(t)
            }

        }
        //判断当前 Observer类型是否为永久存在，如果是则不予处理
        private fun isCallOnObserve(): Boolean {
            val stackTrace = Thread.currentThread().stackTrace
            if (stackTrace.isNotEmpty()) {
                stackTrace.forEach { stackTraceElement ->
                    if ("android.arch.lifecycle.LiveData" == stackTraceElement.className &&
                        "observeForever" == stackTraceElement.methodName
                    ) {
                        return true
                    }
                }
            }
            return false
        }
    }

    class BusMutableLiveData<T> : MutableLiveData<T>() {
        private val observerMap: MutableMap<Observer<T>, Observer<T>> = hashMapOf()

        override fun observe(owner: LifecycleOwner, observer: Observer<T>) {
            super.observe(owner, observer)
            try {
                hook(observer)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        override fun observeForever(observer: Observer<T>) {
            if (!observerMap.containsKey(observer)) {
                observerMap[observer] = LiveDataBus.ObserverWrapper(observer)
            }
            super.observeForever(observer)
        }
        
        override fun removeObserver(observer: Observer<T>) {
            val realObserver: Observer<T>? = if (observerMap.containsKey(observer)) {
                observerMap.remove(observer)
            } else {
                observer
            }
            realObserver?.let { super.removeObserver(it) }
        }

        private fun hook(observer: Observer<T>) {
            try {
                val classLiveData = LiveData::class.java
                //获取LiveData中的 mObservers 对象
                val fieldObservers = classLiveData.getDeclaredField("mObservers")
                fieldObservers.isAccessible = true

                val objectObservers = fieldObservers.get(this)
                val classObservers = objectObservers.javaClass
                val methodGet = classObservers.getDeclaredMethod("get", Object::class.java)
                methodGet.isAccessible = true
                val objectWrapperEntry = methodGet.invoke(objectObservers, observer)
                var objectWrapper: Any? = null
                if (objectWrapperEntry is Map.Entry<*, *>) {
                    objectWrapper = objectWrapperEntry.value
                }
                if (objectWrapper == null)
                    throw NullPointerException("wrapper can not be null")
                //获取对应Observer对象
                val classObserverWrapper = objectWrapper.javaClass.superclass
                //获取其中 mLastVersion数据
                val fieldLastVersion = classObserverWrapper.getDeclaredField("mLastVersion")
                fieldLastVersion.isAccessible = true
                //获取其中mVersion数据
                val fieldVersion = classLiveData.getDeclaredField("mVersion")
                fieldVersion.isAccessible = true

                val objectVersion = fieldVersion.get(this)
                //重新赋值 使两者相等则事件不会进行分发
                fieldLastVersion.set(objectWrapper, objectVersion)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
```

