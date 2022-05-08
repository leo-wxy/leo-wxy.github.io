---
title: Android Study Plan IX - ClassLoaderß
date: 2018-03-18 17:48:29
tags: Android
---
# Android学习计划
话题：Android中的ClassLoader
1、Android中有哪几种ClassLoader？它们的作用和区别是什么？
2、简述ClassLoader的双亲委托模型
3、简述双亲委托模型在热修复领域的应用
# 答案
## 1.Android中有哪几种ClassLoader？它们的作用和区别是什么？

> 在Android程序中，.dex文件就是一群.class文件。

{% fullimage /images/study_plan/android_classloader.png, alt,SingleTop %}

- **BootClassLoader**

  > BootClassLodaer是ClassLoader内部实现类，是只能包内可见，我们是无法调用的。在无父构造器传入的情况下，默认构建一个PathClassLoader且父构造器为BootClassLoader
  >
   ```java
   private static ClassLoader createSystemClassLoader() {
           String classPath = System.getProperty("java.class.path", ".");
           String librarySearchPath = System.getProperty("java.library.path", "");
           return new PathClassLoader(classPath, librarySearchPath, BootClassLoader.getInstance());
       }
   ```

- **URLClassLoader**

  > 只能用于加载jar文件，但是在dalvik（Android5.0之前的虚拟机）无法直接识别jar，所以Android中无法使用这个加载器。

- **BaseDexClassLoader**

  > 用于加载各种dex中的类
  >
   ```java
   public class BaseDexClassLoader extends ClassLoader {
       public BaseDexClassLoader(String dexPath, File optimizedDirectory, String librarySearchPath, ClassLoader parent) {
           throw new RuntimeException("Stub!");
       }
       ...
   }
   ```
  >
  > 主要构造函数介绍：
  >
  > - dexPath：指`目标类所在的apk、dex或jar文件的路径，也可以是SD卡的路径`，类加载器从该路径加载目标类。如果包含多个路径，路径之间必须用特定的分隔符去分隔，特定的分隔符从`System.getProperty("path.separtor")`获取（默认分割符为":"）。最终将路径上的文件ODEX优化到optimizedDirectory，然后进行加载。
  > - optimizedDirectory：解压出的dex文件路径，这个路径必须为内部路径，一般情况下的路径为`/data/data/<Package_Name>/`
  > - librarySearchPath：存放目标类中使用的native文件库，也以":"分割
  > - parent：父加载器，在Android中以`context.getClassLoader`作为父加载器。

- **DexClassLoader**

  > 继承自BaseDexClassLoader，支持加载包含classes.dex的jar、apk，zip文件，可以是SD卡的路径。是实现热修复的关键。**注意不要把优化后的文件放在外部存储，可能导致注入攻击。**

- **PathClassLoader**

  > 用来加载Android系统类和应用程序的类，**在dalvik上只能加载已安装apk的dex(/data/app目录)，在ART虚拟机上则没有这个限制**。

    ```java
  public class PathClassLoader extends BaseDexClassLoader {
    public PathClassLoader(String dexPath, ClassLoader parent) {
        super((String)null, (File)null, (String)null, (ClassLoader)null);
        throw new RuntimeException("Stub!");
    }

    public PathClassLoader(String dexPath, String librarySearchPath, ClassLoader parent) {
        super((String)null, (File)null, (String)null, (ClassLoader)null);
        throw new RuntimeException("Stub!");
    }
  }
    ```

    > 在PathDexClassLoader的构造方法中optimizedDirectory为null，因为默认参数为`/data/dalvik-cache`目录。

- **InMemoryDexClassLoader**

  > 用于加载内存中的dex文件(在API26中添加)
  >
   ```java
   public final class InMemoryDexClassLoader extends BaseDexClassLoader {
      public InMemoryDexClassLoader(ByteBuffer[] dexBuffers, ClassLoader parent) {
          super((String)null, (File)null, (String)null, (ClassLoader)null);
          throw new RuntimeException("Stub!");
      }
       public InMemoryDexClassLoader(ByteBuffer dexBuffer, ClassLoader parent) {
           super((String)null, (File)null, (String)null, (ClassLoader)null);
           throw new RuntimeException("Stub!");
       }
   }
   ```


- **DelegateClassLoader**

  > 是一个先查找在委托的类加载器(API27添加)，按照以下顺序实现加载：
  >
  > 1. 首先判断该类是否被加载
  > 2. 搜索此类的类加载器是否加载过这个类
  > 3. 使用当前加载器去尝试加载类
  > 4. 最后委托给父加载器加载


## 2.简述ClassLoader的双亲委托模型 

{% post_link JVM相关及其拓展-三 %}

## 3.简述双亲委托模型在热修复领域的应用

一个ClassLoader文件可以有多少Dex文件，每个Dex文件是一个Element，多个Dex文件组成一个有序数组DexElements，当找类的时候会按照顺序遍历Dex文件，然后在当前遍历的Dex文件中找出类。由于双亲委托模型机制的存在，只要找到类就会停止检索并返回，找不到就会查询下一个Dex，所以只要我们先找到并加载修复Bug的文件，则有bug的Dex文件不会被加载。

注意点：假设有个A类，引用了B类。发布过程中发现B类有bug，若想要发个新的B类，需要阻止A加上这个类标志CLASS_ISPREVERIFIED。

##  4. 基本热修复代码实现 