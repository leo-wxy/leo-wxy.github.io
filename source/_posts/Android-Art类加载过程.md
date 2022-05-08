---
title: Android-Art类加载过程
date: 2019-12-19 13:45:11
tags: Android
top: 10
---

## Dex文件加载

> 加载Dex文件后会生成`DexFile`对象，里面储存了多个类文件信息。

通过`PathClassLoader`或者`DexClassLoader`去加载`Dex`文件，最后还是调用到`BaseDexClassLoader`的加载方法

```java
class BaseDexClassLoader extends ClassLaoder{
      public BaseDexClassLoader(String dexPath, File optimizedDirectory,
            String librarySearchPath, ClassLoader parent) {
        super(parent);
        this.pathList = new DexPathList(this, dexPath, librarySearchPath, null);
				...
    }
}
```

- DexPathList

  ```java DexPathList.java
  final class DexPathList{
    private Element[] dexElements;
    private final NativeLibraryElement[] nativeLibraryPathElements;
    
    ...
        public DexPathList(ClassLoader definingContext, String dexPath,
              String librarySearchPath, File optimizedDirectory) {
     ...
     // 记录所有的dexFile
     this.dexElements = makeDexElements(splitDexPath(dexPath), optimizedDirectory,                       suppressedExceptions, definingContext);
      
     //记录app目录的Native库
     this.nativeLibraryDirectories = splitPaths(librarySearchPath, false);
     //记录系统使用的Native库
     this.systemNativeLibraryDirectories =                splitPaths(System.getProperty("java.library.path"), true);
     //记录所有使用的Native库
     this.nativeLibraryPathElements = makePathElements(allNativeLibraryDirectories);
    }
  }
  ```

  为了初始化以下两个字段：

  - `dexElements`：记录所有的DexFile，按照`;`进行路径分割
  - `nativeLibraryPathElements`：记录所有的Native代码库，包括`app`和`系统`使用的Native库

- makeDexElements

  ```java
      private static Element[] makeDexElements(List<File> files, File optimizedDirectory,
              List<IOException> suppressedExceptions, ClassLoader loader) {
        Element[] elements = new Element[files.size()];
       for (File file : files) {
        ...
          //以 dex 文件名结尾
          if (name.endsWith(DEX_SUFFIX)) {
            try {
              //加载Dex文件
               DexFile dex = loadDexFile(file, optimizedDirectory, loader, elements);
               if (dex != null) {
                   elements[elementsPos++] = new Element(dex, null);
               }
               } catch (IOException suppressed) {
  
               }
          }else{
            dex = loadDexFile(file, optimizedDirectory, loader, elements);              
                if (dex == null) {
                    elements[elementsPos++] = new Element(file);
                } else {
                    elements[elementsPos++] = new Element(dex, file);
                }
          }
       }
       ... 
      }
  ```

  根据传入的Dex文件路径转换`Element`数组

- loadDexFile

  ```java
      private static DexFile loadDexFile(File file, File optimizedDirectory, ClassLoader loader,
                                         Element[] elements)
              throws IOException {
         //优化后Dex文件 存放地址是否为空
          if (optimizedDirectory == null) {
              //为空创建DexFile对象
              return new DexFile(file, loader, elements);
          } else {
              String optimizedPath = optimizedPathFor(file, optimizedDirectory);
            //不为空将优化后的Dex文件存放到指定目录
              return DexFile.loadDex(file.getPath(), optimizedPath, 0, loader, elements);
          }
      }
  ```

  此处为了加载Dex文件

- DexFile

  ```java
  public final class DexFile {
       DexFile(File file, ClassLoader loader, DexPathList.Element[] elements)
              throws IOException {
          this(file.getPath(), loader, elements);
      }
    
    ...
          DexFile(String fileName, ClassLoader loader, DexPathList.Element[] elements) throws IOException {
          mCookie = openDexFile(fileName, null, 0, loader, elements);
          mInternalCookie = mCookie;
          mFileName = fileName;
      }
    ...
          static DexFile loadDex(String sourcePathName, String outputPathName,
          int flags, ClassLoader loader, DexPathList.Element[] elements) throws IOException {
          return new DexFile(sourcePathName, outputPathName, flags, loader, elements);
      }
    ...
  }
  ```

  `loadDex`本质也是调用了`new DexFile(...)`去加载Dex文件的。

- openDexFile

  ```java
      private static Object openDexFile(String sourceName, String outputName, int flags,
              ClassLoader loader, DexPathList.Element[] elements) throws IOException {
          // Use absolute paths to enable the use of relative paths when testing on host.
          //加载Dex文件
          return openDexFileNative(new File(sourceName).getAbsolutePath(),
                                   (outputName == null)
                                       ? null
                                       : new File(outputName).getAbsolutePath(),
                                   flags,
                                   loader,
                                   elements);
      }
  ```

  `openDexFile`为了加载Dex文件

- openDexFileNative

  ```c dalvik_system_DexFile.cc
  // art/runtime/native/dalvik_system_DexFile.cc
  static jobject DexFile_openDexFileNative(JNIEnv* env,
                                           jclass,
                                           jstring javaSourceName,
                                           jstring javaOutputName ATTRIBUTE_UNUSED,
                                           jint flags ATTRIBUTE_UNUSED,
                                           jobject class_loader,
                                           jobjectArray dex_elements) {
    ScopedUtfChars sourceName(env, javaSourceName);
    if (sourceName.c_str() == nullptr) {
      return 0;
    }
  
    Runtime* const runtime = Runtime::Current();
    ClassLinker* linker = runtime->GetClassLinker();
    std::vector<std::unique_ptr<const DexFile>> dex_files;
    std::vector<std::string> error_msgs;
    const OatFile* oat_file = nullptr;
  
    dex_files = runtime->GetOatFileManager().OpenDexFilesFromOat(sourceName.c_str(),
                                                                 class_loader,
                                                                 dex_elements,
                                                                 /*out*/ &oat_file,
                                                                 /*out*/ &error_msgs);
  
  ...
  
      return nullptr;
    }
  }
  ```

  `openDexFileNative`主要处理dex文件，并生成`odex`到`optimizedDirectory`里

- openDexFilesFromOat

  //TODO 版本差异较大

  ```c
  //art/runtime/oat_file_manager.cc
  
  std::vector<std::unique_ptr<const DexFile>> OatFileManager::OpenDexFilesFromOat(
      const char* dex_location,
      const char* oat_location,
      jobject class_loader,
      jobjectArray dex_elements,
      const OatFile** out_oat_file,
      std::vector<std::string>* error_msgs) {
    
  }
  
  oat_file_manager.cc
    
  oat_file_assistant.cc
  ```



{% fullimage /images/jvm/Dex加载过程.png, Dex加载过程,Dex加载过程 %}



## Dex中的类文件加载

> Dex文件是由多个Class类文件组成，Android加载类需要从Dex中找到对应类进行加载，实际`从DexFile找到Class`

```java
public class BaseDexClassLoader extends ClassLoader {
 ...
   private final DexPathList pathList;
   
     @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        // First, check whether the class is present in our shared libraries.
        //加载需要使用的Native库
        if (sharedLibraryLoaders != null) {
            for (ClassLoader loader : sharedLibraryLoaders) {
                try {
                    return loader.loadClass(name);
                } catch (ClassNotFoundException ignored) {
                }
            }
        }
        // Check whether the class in question is present in the dexPath that
        // this classloader operates on.
        List<Throwable> suppressedExceptions = new ArrayList<Throwable>();
        // 找寻Dex中对应class
        Class c = pathList.findClass(name, suppressedExceptions);
        if (c == null) {
            ClassNotFoundException cnfe = new ClassNotFoundException(
                    "Didn't find class \"" + name + "\" on path: " + pathList);
            for (Throwable t : suppressedExceptions) {
                cnfe.addSuppressed(t);
            }
            throw cnfe;
        }
        return c;
    }

}
```

- DexPathList - findClass

  ```java
      public Class<?> findClass(String name, List<Throwable> suppressed) {
          for (Element element : dexElements) {
              Class<?> clazz = element.findClass(name, definingContext, suppressed);
              if (clazz != null) {
                  return clazz;
              }
          }
  
          if (dexElementsSuppressedExceptions != null) {
              suppressed.addAll(Arrays.asList(dexElementsSuppressedExceptions));
          }
          return null;
      }
  ```

  `findClass`为了找到Dex文件中的对应类

  > `dexElements`是由`Dex`文件加载后得到的`DexFile`组装成的`Element`集合形成的。
  >
  > `findClass`实质是去遍历已加载完成的`Dex`文件中的Class，只要找到对应的Class就会结束循环。
  >
  > **当两个相同的类出现在不同的Dex时，系统会优先处理排在前面的Dex文件中的类，后面出现的就不会被加载。**
  >
  > 热修复的核心逻辑：`将需要修复的类所打包的Dex文件插入到dexElements的首位`。

  

- Element - findClass

  ```java
         public Class<?> findClass(String name, ClassLoader definingContext,
                  List<Throwable> suppressed) {
              return dexFile != null ? dexFile.loadClassBinaryName(name, definingContext, suppressed)
                      : null;
          }
  ```

  

- DexFile - loadClassBinaryName

  ```java
      public Class loadClassBinaryName(String name, ClassLoader loader, List<Throwable> suppressed) {
          return defineClass(name, loader, mCookie, this, suppressed);
      }
  
      private static Class defineClass(String name, ClassLoader loader, Object cookie,
                                       DexFile dexFile, List<Throwable> suppressed) {
          Class result = null;
          try {
              //定义Class
              result = defineClassNative(name, loader, cookie, dexFile);
          } catch (NoClassDefFoundError e) {
              if (suppressed != null) {
                  suppressed.add(e);
              }
          } catch (ClassNotFoundException e) {
              if (suppressed != null) {
                  suppressed.add(e);
              }
          }
          return result;
      }
  ```

  

- Dalvik_system_DexFile.cc - DexFile_defineClassNative

  ```c
  static jclass DexFile_defineClassNative(JNIEnv* env,
                                          jclass,
                                          jstring javaName,
                                          jobject javaLoader,
                                          jobject cookie,
                                          jobject dexFile) {
    std::vector<const DexFile*> dex_files;
    const OatFile* oat_file;
    if (!ConvertJavaArrayToDexFiles(env, cookie, /*out*/ dex_files, /*out*/ oat_file)) {
      VLOG(class_linker) << "Failed to find dex_file";
      DCHECK(env->ExceptionCheck());
      return nullptr;
    }
  
    ScopedUtfChars class_name(env, javaName);
    if (class_name.c_str() == nullptr) {
      VLOG(class_linker) << "Failed to find class_name";
      return nullptr;
    }
    const std::string descriptor(DotToDescriptor(class_name.c_str()));
    const size_t hash(ComputeModifiedUtf8Hash(descriptor.c_str()));
    for (auto& dex_file : dex_files) {
      const DexFile::ClassDef* dex_class_def =
          OatDexFile::FindClassDef(*dex_file, descriptor.c_str(), hash);
      if (dex_class_def != nullptr) {
        ScopedObjectAccess soa(env);
        ClassLinker* class_linker = Runtime::Current()->GetClassLinker();
  			...
          return nullptr;
        }
        //创建目标类对象
        ObjPtr<mirror::Class> result = class_linker->DefineClass(soa.Self(),
                                                                 descriptor.c_str(),
                                                                 hash,
                                                                 class_loader,
                                                                 *dex_file,
                                                                 *dex_class_def);
        // Add the used dex file. This only required for the DexFile.loadClass API since normal
        // class loaders already keep their dex files live.
        class_linker->InsertDexFileInToClassLoader(soa.Decode<mirror::Object>(dexFile),
                                                   class_loader.Get());
        if (result != nullptr) {
          VLOG(class_linker) << "DexFile_defineClassNative returning " << result
                             << " for " << class_name.c_str();
          return soa.AddLocalReference<jclass>(result);
        }
      }
    }
    VLOG(class_linker) << "Failed to find dex_class_def " << class_name.c_str();
    return nullptr;
  }
  ```

- Class_linker.cc  - DefineClass

  ```c
  mirror::Class* ClassLinker::DefineClass(Thread* self,
                                          const char* descriptor,
                                          size_t hash,
                                          Handle<mirror::ClassLoader> class_loader,
                                          const DexFile& dex_file,
                                          const DexFile::ClassDef& dex_class_def) {
    ...
    if (klass == nullptr) {
      //加载类实例
      klass.Assign(AllocClass(self, SizeOfClassWithoutEmbeddedTables(dex_file, dex_class_def)));
    }
    ObjPtr<mirror::DexCache> dex_cache = RegisterDexFile(*new_dex_file, class_loader.Get());
    if (dex_cache == nullptr) {
      self->AssertPendingException();
      return nullptr;
    }
    //设置Dex缓存，后续数据从缓存中读取
    klass->SetDexCache(dex_cache);
    //设置Class信息
    SetupClass(*new_dex_file, *new_class_def, klass, class_loader.Get());
    // 把 Class 插入 ClassLoader 的 class_table 中做一个缓存
    ObjPtr<mirror::Class> existing = InsertClass(descriptor, klass.Get(), hash);
    // 加载类属性
    LoadClass(self, *new_dex_file, *new_class_def, klass);
  
  }
  ```

  每当一个类被加载时，ART运行时都会检查该类所属的Dex文件是否已经关联一个`dex_cache`。

  如果尚未关联，就会创建一个`dex_cache`与Dex文件建立关联，建立关联后，通过调用`RegisterDexFile`注册到aRT运行时中去，后续可以直接使用。

  `dex_cache`用来缓存包含在一个Dex文件里的`类型(Type)、方法(Method)、域(Field)、字符串(String)和静态存储区(Static Storage)`等信息。

  `通过dex_cache间接调用类方法，可以做到延时解析类方法(只有方法第一次调用才会被解析，可以避免解析永远不调用的方法)；一个类方法只会被解析一次，解析的结果存在dex_cache中，下次调用时可以直接从dex_cache进行调用。`



### 加载类成员







## 参考链接

[Android类加载器ClassLoader](http://gityuan.com/2017/03/19/android-classloader/)

[相关源码](cs.android.com)

[谈谈 Android 中的 PathClassLoader 和 DexClassLoader](https://juejin.im/post/5d6a79de5188256c3920b8f7#heading-4)