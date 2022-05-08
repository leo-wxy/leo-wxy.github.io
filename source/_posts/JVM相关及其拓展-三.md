---
title: JVM相关及其拓展(三) -- 虚拟机类加载器
date: 2018-04-16 13:29:36
tags: JVM
top: 9
---

# 虚拟机类加载器

## 定义：

在类加载阶段中的“通过一个类的全限定名来获取描述此类的二进制字节流”这个动作放到Java虚拟机外部去实现，以便让应用程序自己决定如何去获取所需要的类，实现这个动作的代码块称为“类加载器”。

例如：编写的是.java文件，代码运行后变成.class文件，类加载器就是加载.class文件。

**不同的类加载器加载同一个类时，得到的两个类也是不相等的。**



## Java类加载器分类：

### 1.系统提供的类加载器

{% fullimage /images/类加载器.png,类加载器分类,类加载器分类%}

- **Bootstrap ClassLoader(启动类加载器)**：由C/C++实现的加载器，用于加载虚拟机运行时所需要的系统类，如`java.lang.*、java.uti.*`等系统类。它负责将存放在`<JAVA_HOME>\lib`目录中的，或者被-Xbootclasspath参数所指定的路径中的，并且是虚拟机识别的类库加载到虚拟机内存中。

  这个加载器由于是C实现的，所以**无法被Java程序直接引用**。并且不继承`java.lang.ClassLoader`。

- **Extension ClassLoader(扩展类加载器)**：这个加载器由sun.misc.Launcher$ExtClassLoader实现，负责加载<JAVA_HOME>\lib\ext目录中的，或者被`javax.ext.dirs`系统变量所指定的路径中的所有类库。

  **开发者可以直接进行引用。**

- **Application ClassLoader(应用程序类加载器)**：这个加载器由sun.misc.Launcher$AppClassLoader实现。可以加载用户类路径上的指定类库，通过`ClassLoader.getSystemClassLoader()`方式获取，没有定义过自己的类加载器，则默认是这个。

- **Custom ClassLoader(自定义加载器)**：通过集成`java.lang.ClassLoader`来实现自己的加载器。

  

### 2.双亲委托模型

{% fullimage /images/jvm/parent_loader.png, alt,双亲委托模型 %}

- 工作流程：如果一个类加载器收到了类加载的请求，不会自己去尝试加载这个类，而把这个请求委派给父类加载器去完成，每一层都是如此，依次向上递归，直到委托到最顶层的`Bootstrap ClassLoader`，若父加载器无法处理加载请求（它的搜索范围内没有找到所需的类时），则交由子加载器去加载。

  > 简单流程介绍
  >
  > 1. 自定义类加载器先从缓存中查看Class文件是否被加载，如果加载则返回Class，没有加载则委托给父类加载
  > 2. 一直委托到`Bootstrap ClassLoader`,在`Bootstrap ClassLoader`没有找到Class文件，则在自己的规定路径<JAVA_HOME>\lib或者-Xbootclasspath选项指定路径的jar包进行查询，找到则返回Class，没有就交由子加载器去加载。
  > 3. 最后交由我们自定义的类加载器去加载，还找不到则抛出`ClassNotFoundException`异常。
- 代码模型实现：


```java
 protected Class<?> loadClass(String name, boolean resolve)
        throws ClassNotFoundException
    {
        synchronized (getClassLoadingLock(name)) {
            // 检查请求的类是否已被加载过
            Class<?> c = findLoadedClass(name);
            //对应的类已被加载则不会往下进行
            if (c == null) {
                long t0 = System.nanoTime();
                try {
                    if (parent != null) {
                    //父加载器不为null，调用父加载器的load方法
                        c = parent.loadClass(name, false);
                    } else {
                    //父加载器为null，则调用系统的BootstrapClassLoader
                        c = findBootstrapClassOrNull(name);
                    }
                } catch (ClassNotFoundException e) {
                    // ClassNotFoundException thrown if class not found
                    // from the non-null parent class loader
                    //父类加载器无法加载则抛出ClassNotFoundException异常
                }

                if (c == null) {
                    // If still not found, then invoke findClass in order
                    // to find the class.
                    //父类加载器无法加载则调用本身的findClass()方法去加载
                    long t1 = System.nanoTime();
                    c = findClass(name);

                    // this is the defining class loader; record the stats
                    sun.misc.PerfCounter.getParentDelegationTime().addTime(t1 - t0);
                    sun.misc.PerfCounter.getFindClassTime().addElapsedTimeFrom(t1);
                    sun.misc.PerfCounter.getFindClasses().increment();
                }
            }
            if (resolve) {
                resolveClass(c);
            }
            return c;
        }
    }
```

- 好处：
  - 避免重复加载，若该Class已加载则从缓存中直接读取
  - 更加安全，例如`java.lang.Object`，无论哪一个类加载器去加载这个类，最终都会委派给Bootstrap ClassLoader去进行加载，所以我们自定义的Object类并不会被加载而导致系统中出现多个Object类。

###  3.破坏双亲委托模型

双亲委派模型并不是一个强制性的约束模型，而是Java设计者推荐给开发者的类加载实现方式。

- 在JDK1.2发布之前，还没有双亲委托机制
- 由模型自身缺陷所导致的
- 用户对于程序动态性导致的，例如代码热替换，模块热部署



### 4.自定义ClassLoader
- 自定义需要加载的类

  ```java
  public class Jobs {
          public void say() {
          System.err.println("自定义加载器加载");
      }
  }
  ```

  自定义完成后需调用`javac Jobs.java`去生成对应的`Jobs.class`文件以用来加载。

- 实现自定义的ClassLoader

  ```java
  import java.io.*;

  public class DiskClassLoader extends ClassLoader {
      private String path;

      public DiskClassLoader(String path) {
          this.path = path;
      }

      @Override
      protected Class<?> findClass(String name) throws ClassNotFoundException {
          Class clazz = null;
          byte[] classData = loadClassData(name);
          if (classData == null) {
              throw new ClassNotFoundException();
          } else {
              //用来将获取的字节码数组转为class的实例
              clazz = defineClass(name, classData, 0, classData.length);
          }
          return clazz;
      }

      /**
       * 获得class文件的字节码数组
       * @param name
       * @return
       */
      private byte[] loadClassData(String name) {
          String fileName = getFileName(name);
          File file = new File(path, fileName);
          System.err.println(fileName);
          InputStream inputStream = null;
          ByteArrayOutputStream byteArrayOutputStream = null;
          try {
              inputStream = new FileInputStream(file);
              byteArrayOutputStream = new ByteArrayOutputStream();
              byte[] buffer = new byte[1024];
              int length = 0;
              while ((length = inputStream.read(buffer)) != -1) {
                  byteArrayOutputStream.write(buffer, 0, length);
              }
              return byteArrayOutputStream.toByteArray();
          } catch (IOException e) {
              e.printStackTrace();
          } finally {
              //读取流后需要关闭，以免造成内存泄露
              try {
                  if (inputStream != null) {
                      inputStream.close();
                  }
              } catch (IOException e) {
                  e.printStackTrace();
              }
              try {
                  if (byteArrayOutputStream != null) {
                      byteArrayOutputStream.close();
                  }
              } catch (IOException e) {
                  e.printStackTrace();
              }
          }
          return null;
      }

      private String getFileName(String name) {
          int index = name.indexOf('.');
          if (index == -1) {
              return name + ".class";
          } else {
              return name.substring(index + 1) + ".class";
          }
      }
  }

  ```

  自定义的ClassLoader需要读取对应Class的字节流数组，以便产生实例。注意不要忘记对流的关闭。

- 使用自定义的ClassLoader去加载类

  ```java
  import java.lang.reflect.InvocationTargetException;
  import java.lang.reflect.Method;

  public class CustomClassLoaderTest{
       public static void main(String[] args) {
        DiskClassLoader diskClassLoader = new DiskClassLoader("需要加载的class的地址");
          try {
              //对class文件进行加载
              Class c = diskClassLoader.loadClass("Jobs");
              if (c != null) {
                  try {
                      Object object = c.newInstance();
                      System.err.println(object.getClass().getClassLoader());
                      Method method = c.getDeclaredMethod("say", null);
                      method.invoke(object, null);
                  } catch (IllegalAccessException e) {
                      e.printStackTrace();
                  } catch (InstantiationException e) {
                      e.printStackTrace();
                  } catch (NoSuchMethodException e) {
                      e.printStackTrace();
                  } catch (InvocationTargetException e) {
                      e.printStackTrace();
                  }
              }
          } catch (ClassNotFoundException e) {
              e.printStackTrace();
          }
       }
  }
  ```

  在对应的文件夹下是否已存在Jobs.java文件：

  - ```java
    //存在要加载的Java文件
    sun.misc.Launcher$AppClassLoader@18b4aac2
    自定义加载器加载
    ```

  - ```java
    //不存在对应的Java文件
    DiskClassLoader@d716361
    自定义加载器加载
    ```

​          以上就为自定义ClassLoader的基本步骤，也是热修复框架中ClassLoader的雏形。