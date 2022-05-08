---
title: Android需要的必备知识
date: 2018-12-09 14:05:46
tags: Android
top: 10
---

第一关：Binder、AIDL、多进程（建议学习时间：2周）
知识点：Binder原理、AIDL的使用、多进程的定义和特性
学习资料：
① Android开发艺术探索第2章【推荐理由】地球人都知道学Android要看艺术探索。
② [Android Bander设计与实现 - 设计篇 - universus的专栏 - CSDN博客](https://blog.csdn.net/universus/article/details/6211589) 【推荐理由】Binder底层史上最牛逼分析，没有之一。
③ 艺术探索第2章的例子，请一定手动运行一遍并仔细理解，地址：[GitHub - singwhatiwanna/android-art-res: the sourc...](https://github.com/singwhatiwanna/android-art-res)。
第二关：View的绘制（建议学习时间：3天）
知识点：View的measure、layout和draw，View的工作原理
学习资料：
① Android开发艺术探索第4章【推荐理由】地球人都知道学Android要看艺术探索。
② [图解View测量、布局及绘制原理 - 简书](https://www.jianshu.com/p/3d2c49315d68) 【推荐理由】配有流程图，比艺术探索好理解一些。
③ [android ListView 工作原理 - Android - 掘金](https://juejin.im/entry/5819968bda2f60005dda6a2d)【推荐理由】帮大家了解ListView的工作过程，很有价值。
第三关：事件分发（建议学习时间：1周）
知识点：事件分发原理和规则
学习资料：
① Android开发艺术探索第3章【推荐理由】地球人都知道学Android要看艺术探索。
② [Android事件分发机制，大表哥带你慢慢深入 - 简书](https://www.jianshu.com/p/fc0590afb1bf) 【推荐理由】通过实际的例子来讲事件分发，好理解。
③ [Android ViewGroup事件分发机制 - Hongyang - CSDN博客](https://blog.csdn.net/lmj623565791/article/details/39102591) 【推荐理由】张鸿洋写的。
第四关：消息队列（建议学习时间：1天）
要求：Handler、Looper、Thread三者之间的关系；得知道子线程创建Handler为什么会报错，如何才能不报错
学习资料：
① Android开发艺术探索第10章【推荐理由】这块内容不难，艺术探索就够了。
② [源码角度讲解子线程创建Handler报错的原因 - 曹银飞的专栏 - CSDN博客](https://blog.csdn.net/dfskhgalshgkajghljgh/article/details/52601802)【推荐理由】一个实际的例子帮助大家更好地理解。
第五关：Activity难点（建议学习时间：1天）
① setResult和finish的顺序关系
② onSaveInstanceState()和onRestoreInstanceState()
③ onNewIntent()和onConfigurationChanged()
学习资料：
① [setResult()的调用时机 - 沙翁 - 博客园](https://www.cnblogs.com/shaweng/p/3875825.html)【推荐理由】清晰易懂，直接了当。
② [onSaveInstanceState()和onRestoreInstanceState()使用详解...](https://www.jianshu.com/p/27181e2e32d2)【推荐理由】简单好懂。
③ [关于onConfigurationChanged方法及常见问题解决 - 朱小姐。的博客 - CSDN...](https://blog.csdn.net/qq_27570955/article/details/55046934)【推荐理由】简单好懂，文章在郭霖公号投稿了。
④ 艺术探索第1章【推荐理由】地球人都知道学Android要看艺术探索。
第六关：Service难点（建议学习时间：2天）
① 先start再bind，如何停止一个Service
② Service onStartCommand的返回值
③ bindService后，ServiceConnection里面的回调方法运行在哪个线程？它们的调用时机分别是什么？
④ Service的onCreate运行在哪个线程？
学习资料：
① [Android中startService和bindService的区别 - 简书](https://www.jianshu.com/p/d870f99b675c)【推荐理由】详细全面地回答了上面的问题。
② [Service: onStartCommand 诡异的返回值 - CodingMan - CSDN博...](https://blog.csdn.net/veryitman/article/details/7600008)【推荐理由】通过实例来演示onStartCommand那诡异的返回值。
③ Service的onCreate、onStartCommand、onDestory等全部生命周期方法都运行在UI线程，ServiceConnection里面的回调方法也是运行在UI线程，大家一定要记住。【推荐理由】任玉刚说的，你们自己可以打log验证一下
第七关：ContentProvider难点(建议学习时间：3天)
① ContentProvider的生命周期
② ContentProvider的onCreate和CRUD运行在哪个线程？它们是线程安全的吗？
③ ContentProvider的内部存储只能是sqlite吗？
学习资料：
① 艺术探索第9章中ContentProvider的启动、艺术探索第二章中ContentProvider的介绍【推荐理由】详细了解下，艺术探索的内容无需解释
② [android ContentProvider onCreate()在 Application......](https://www.jianshu.com/p/0f1e36507b9d)【推荐理由】此文明确说明了ContentProvider的onCreate早于Application的onCreate而执行。
③ [ContentProvider总结 - 简书](https://www.jianshu.com/p/cfa46bea6d7b)【推荐理由】此文明确说明了ContentProvider的onCreate和CRUD所在的线程
注意：ContentProvider的底层是Binder，当跨进程访问ContentProvider的时候，CRUD运行在Binder线程池中，不是线程安全的，而如果在同一个进程访问ContentProvider，根据Binder的原理，同进程的Binder调用就是直接的对象调用，这个时候CRUD运行在调用者的线程中。另外，ContentProvider的内部存储不一定是sqlite，它可以是任意数据。
第八关：AsyncTask原理(建议学习时间：3天)
要求：知道AsyncTask的工作原理，知道其串行和并行随版本的变迁
① [Android源码分析—带你认识不一样的AsyncTask - 任玉刚 - CSDN博客](https://blog.csdn.net/singwhatiwanna/article/details/17596225) 【推荐理由】只看这一篇文章就够了
② [https://android.googlesource.com/platform/frameworks/base/ /android-8.1.0_r46/core/java/android/os/AsyncTask.java](https://android.googlesource.com/platform/frameworks/base/+/android-8.1.0_r46/core/java/android/os/AsyncTask.java) 【推荐理由】阅读AsyncTask 8.1版本的源码，看看是否有更新

第九关：RemoteViews(建议学习时间：7天)
要求：熟悉RemoteViews并了解其原理
① Android开发艺术探索 第5章【推荐理由】艺术探索是高级工程师进阶必备
② [关于 RemoteViews 跨进程资源访问的勘误 - 掘金](https://juejin.im/post/5c3b588be51d4551de1da844) 【推荐理由】进一步理解RemoteViews的实现，通过它可以实现资源的跨进程访问，艺术探索中的担心是多余的
第十关：Window和ViewRootImpl(建议学习时间：14天)
要求：熟悉Window、WMS和ViewRootImpl的原理
① Android开发艺术探索 第8章【推荐理由】艺术探索是高级工程师进阶必备
② Android进阶解密 第8章 【推荐理由】进阶必备
③ [Android窗口机制（四）ViewRootImpl与View和WindowManager - 简书](https://www.jianshu.com/p/9da7bfe18374)【推荐理由】另一个优秀作者对Window的描述
④ [Android中MotionEvent的来源和ViewRootImpl - 任玉刚 - CSDN博客](https://blog.csdn.net/singwhatiwanna/article/details/50775201) 【推荐理由】另一个角度理解下输入事件和ViewRootImpl的关联
第十一关：刁钻问题汇总 (建议学习时间：一周)
① 子线程访问 UI 却不报错的原因：[Android中子线程真的不能更新UI吗？ - yinhuanxu - CSDN博客](https://blog.csdn.net/xyh269/article/details/52728861)
② 主线程的消息循环是一个死循环，为何不会卡死：[Android中为什么主线程不会因为Looper.loop()里的死循环卡死？ - 知乎](https://www.zhihu.com/question/34652589)
③ Binder、IBinder、IInterface的关系：[把玩Android多进程.pdf_免费高速下载|百度网盘-分享无限制](https://pan.baidu.com/s/1VImj3EXesFXAqT3pskcSig)
注意：主线程的消息循环背后，一切皆是消息，消息机制和Binder是Android系统的两大核心机制，屏幕触摸消息、键盘消息、四大组件的启动等均是由消息驱动。
第十二关：Retrofit原理分析 (建议学习时间：14天)
要求：熟悉Retrofit/OKHttp的工作原理
① [OKHttp源码解析 - 简书](https://www.jianshu.com/p/27c1554b7fee)【推荐理由】okhttp源码分析
② [Retrofit原理解析最简洁的思路 - 知乎](https://zhuanlan.zhihu.com/p/35121326) 【推荐理由】retrofit原理分析
③ [Retrofit是如何工作的？ - 简书](https://www.jianshu.com/p/cb3a7413b448)【推荐理由】另一个retrofit原理分析
④ 自行阅读okhttp/retrofit的源码，并写出一篇原理分析的文章 【推荐理由】源码一定要亲自读一读，并沉淀为自己的知识
第十三关：RxJava原理分析 (建议学习时间：14天)
① [友好 RxJava2.x 源码解析（一）基本订阅流程 - 掘金](https://juejin.im/post/5a209c876fb9a0452577e830)【推荐理由】基本订阅流程，已在玉刚说投稿
② [友好 RxJava2.x 源码解析（二）线程切换 - 掘金](https://juejin.im/post/5a248206f265da432153ddbc) 【推荐理由】线程切换，已在玉刚说投稿
③ [友好 RxJava2.x 源码解析（三）zip 源码分析 - 掘金](https://juejin.im/post/5ac16a2d6fb9a028b617a82a)【推荐理由】zip，已在玉刚说投稿
④ 自行阅读RxJava源码，并写出一篇原理分析的文章 【推荐理由】源码一定要亲自读一读，并沉淀为自己的知识

第十四关：Glide原理分析 (建议学习时间：14天)
① [Android图片加载框架最全解析（二），从源码的角度理解Glide的执行流程 - 郭霖的专栏 - ...](https://blog.csdn.net/guolin_blog/article/details/53939176)【推荐理由】glide工作原理，文章很长，郭霖出品
② 自行阅读 glide 4 源码，并写出一篇原理分析的文章 【推荐理由】源码一定要亲自读一读，并沉淀为自己的知识
第十五关：Groovy (建议学习时间：3天)
要求：熟悉groovy的常见语法
① [Gradle从入门到实战 - Groovy基础 - 任玉刚 - CSDN博客](https://blog.csdn.net/singwhatiwanna/article/details/76084580)【推荐理由】groovy语法基础，任玉刚出品
② [The Apache Groovy programming language - Documenta...](http://www.groovy-lang.org/documentation.html) 【推荐理由】官方文档，可当做字典来查阅
第十六关：Gradle插件基础 (建议学习时间：7天)
要求：熟悉gradle语法，可以书写简单的gradle插件
① [全面理解Gradle - 执行时序 - 任玉刚 - CSDN博客](https://blog.csdn.net/singwhatiwanna/article/details/78797506)【推荐理由】gradle执行时序，任玉刚出品
② [全面理解Gradle - 定义Task - 任玉刚 - CSDN博客](https://blog.csdn.net/singwhatiwanna/article/details/78898113)【推荐理由】task定义，任玉刚出品
③ [一篇文章带你了解Gradle插件的所有创建方式](https://mp.weixin.qq.com/s/KCpl0CNgwMv0CgvbadNK6A)【推荐理由】gradle插件的三种创建方式，已在玉刚说投稿
④ [写给 Android 开发者的 Gradle 系列（三）撰写 plugin - 掘金](https://juejin.im/post/5b02113a5188254289190671) 【推荐理由】一个简单的小例子，让大家理解gradle插件的价值
第十七关：设计模式 (建议学习时间：30-60天)
要求：熟悉6大基本原则、23种设计模式，并能在实际中灵活使用
① 《大话设计模式》【推荐理由】强烈建议买一本设计模式的书，好好看看，这事急不得
② [23种设计模式全解析 - 龙鱼鹿 - CSDN博客](https://blog.csdn.net/longyulu/article/details/9159589) 【推荐理由】这是一篇文章，涵盖了全部设计模式，我收藏了好几年了，拿出来给大家看，但是只看这篇文章是远远不够的
③  <https://t.zsxq.com/QzZZZNj>【推荐理由】学习设计模式的精神，任玉刚出品
④ [如何通俗理解设计模式及其思想? - 掘金](https://juejin.im/post/5b3cddb6f265da0f8145c049) 【推荐理由】学习设计模式的精神，却把青梅嗅出品
第十八关：MVC、MVP、MVVM (建议学习时间：14天)
要求：熟悉它们并会灵活使用
① [MVC、MVP、MVVM，我到底该怎么选？ - 掘金](https://juejin.im/post/5b3a3a44f265da630e27a7e6)【推荐理由】3M，理论结合小例子，好理解，玉刚说写作平台文章
② [全面理解Gradle - 定义Task - 任玉刚 - CSDN博客](https://blog.csdn.net/singwhatiwanna/article/details/78898113)【推荐理由】讲解MVP，理论结合小例子，好理解，玉刚说写作平台文章
③ <https://juejin.im/post/5b44d50de51d451925627900>【推荐理由】3M，Mr.S的作品，玉刚说写作平台文章
第十九关：组件化 (建议学习时间：7天)
① [Android 组件化最佳实践 - 掘金](https://juejin.im/post/5b5f17976fb9a04fa775658d)【推荐理由】一篇长文搞定，包括所有内容，分析+实例
第二十关：jni和ndk基础 (建议学习时间：30-60天)
要求：熟悉jni和ndk语法，能进行简单的开发
① 《Android开发艺术探索》第14章【推荐理由】这是最最基本的jni和ndk入门
② [JNI/NDK开发指南 - 技术改变生活（为理想而奋斗，为目标而努力！） - xyang0917 -...](https://blog.csdn.net/xyang81/column/info/blogjnindk)【推荐理由】找了半天，找到一个还凑合的教程，真是资源匮乏呀
③ <https://developer.android.com/ndk/guides/>【推荐理由】官方的ndk入门指南，讲了很多配置选项，推荐看看
④ [Android JNI 编程实践 - 简书](https://www.jianshu.com/p/9b83cc5a5ba8)【推荐理由】讲解了如何注册jin函数表，也需要大家看一下
⑤ 书籍《Android C++高级编程 使用NDK》 【推荐理由】如果要系统学习ndk，还是推荐看看书

第二十一关：安全 (建议学习时间：14天)
要求：熟悉各种发编译+二次打包工具，了解smali
① [浅析Android沙箱模型 - ljheee的博客 - CSDN博客](https://blog.csdn.net/ljheee/article/details/53191397)【推荐理由】了解沙盒机制
② [Smali语法介绍 - 任玉刚 - CSDN博客](https://blog.csdn.net/singwhatiwanna/article/details/19019547)【推荐理由】smali入门，很简单，之前我写的
③ [Smali 介绍 - CTF Wiki](https://ctf-wiki.github.io/ctf-wiki/android/basic_operating_mechanism/java_layer/smali/smali/)【推荐理由】复杂点的smali入门
④ [android逆向分析之smali语法 - L25000的专栏 - CSDN博客](https://blog.csdn.net/L25000/article/details/46842013)【推荐理由】各种工具的使用，以及一个使用apktool进行破解的例子
备注：各种工具软件大家网上自己找，反编译的话推荐jadx，比dex2jar+jd-gui更方便，smali有点复杂，如果不是特别需要，不建议深入学习，事实上，很多人私下研究安全其实就是为了破解。
第二十二关：动态化 (建议学习时间：30-60天)
要求：阅读VirtualAPK的源码，熟悉常见的热修复和插件化原理
① [Android 热修复Nuwa的原理及Gradle插件源码解析 - 区长的专栏 - CSDN博客](https://blog.csdn.net/sbsujjbcy/article/details/50812674)【推荐理由】nuwa原理浅析
② [Android 热修复 Tinker接入及源码浅析 - Hongyang - CSDN博客](https://blog.csdn.net/lmj623565791/article/details/54882693)【推荐理由】Tinker原理解析，鸿洋出品
③ [滴滴插件化方案 VirtualApk 源码解析 - Hongyang - CSDN博客](https://blog.csdn.net/lmj623565791/article/details/75000580)【推荐理由】VirtualAPK四大组件原理解析，鸿洋出品
④ [Notion – The all-in-one workspace for your notes, ...](https://www.notion.so/VirtualAPK-1fce1a910c424937acde9528d2acd537)【推荐理由】VirtualAPK资源加载机制
⑤ [GitHub - tiann/understand-plugin-framework: demos ...](https://github.com/tiann/understand-plugin-framework) 【推荐理由】插件化技术的方方面面，作者是田维术，必看的文章
⑥ [GitHub - didi/VirtualAPK: A powerful and lightweig...](https://github.com/didi/VirtualAPK) 【推荐理由】VirtualAPK引擎和构建部分，必看

应用双开与系统分身