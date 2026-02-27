---
title: Android-SharedPreferences简析
typora-root-url: ../
date: 2020-11-18 10:40:52
tags: Android
top: 9
---

![SharedPreferences原理-xmind](/images/SharedPreferences原理.png)

`SharedPreferences`是系统提供的一种简易数据持久化手段，适合**单进程、小批量**的数据存储与访问。以键值对形式存储在`xml`文件中。
文件存储路径为`data/data/package_name/shared_prefs/`目录。

## 源码解析

![源码解析](/images/SP-源码解析.png)

### 获取SharedPreferences对象

![获取SharedPreferences对象](/images/SP-源码解析1.png)

获取方法从`getSharedPreferences(name,mode)`开始，此时就需要去加载对应name的`xml`文件

```java
class MainActivity : AppCompatActivity() {
    lateinit var sharedPreferences: SharedPreferences
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        sharedPreferences = getSharedPreferences("test", MODE_PRIVATE);
    }
}
```

`test`表示生成的xml文件名为`test.xml`

`mode`对应的是xml文件的访问权限以及数据的写入方式

| 权限控制格式                   | 作用                                                         | 备注                        |
| ------------------------------ | ------------------------------------------------------------ | --------------------------- |
| Context.MODE_PRIVATE           | **代表该文件是私有数据，只能被当前应用访问。**<br>写入的内容会覆盖源文件的内容。 | 默认操作模式                |
| Context.MODE_WORLD_READABLE    | 表示当前文件可以被其他应用读取                               |                             |
| Context.MODE_WORLD_WRITEABLE   | 表示当前文件可以被其他应用写入                               |                             |
| Context.MODE_APPEND            | 会检查当前是否有文件存在？<br>在后面追加内容<br>不存在则创建新文件 |                             |
| ~~Context.MODE_MULTI_PROCESS~~ | 部分支持跨进程使用                                           | 原理就是重新读取xml文件内容 |

```java
//ContextImpl.java

private static ArrayMap<String, ArrayMap<File, SharedPreferencesImpl>> sSharedPrefsCache;
private ArrayMap<String, File> mSharedPrefsPaths;

    public SharedPreferences getSharedPreferences(String name, int mode) {
      
        File file;
        synchronized (ContextImpl.class) {
            if (mSharedPrefsPaths == null) {
                mSharedPrefsPaths = new ArrayMap<>();
            }
            file = mSharedPrefsPaths.get(name);
            if (file == null) {
              //根据名字 获取对应路径文件
                file = getSharedPreferencesPath(name);
                mSharedPrefsPaths.put(name, file);
            }
        }
        return getSharedPreferences(file, mode);
    }

    @Override
    public File getSharedPreferencesPath(String name) {
        return makeFilename(getPreferencesDir(), name + ".xml");
    }

    public SharedPreferences getSharedPreferences(File file, int mode) {
        SharedPreferencesImpl sp;
      //保证创建过程线程安全
        synchronized (ContextImpl.class) {
            final ArrayMap<File, SharedPreferencesImpl> cache = getSharedPreferencesCacheLocked();
          //获取缓存sp
            sp = cache.get(file);
            if (sp == null) {
                checkMode(mode);
              ...
                //新建SP对象
                sp = new SharedPreferencesImpl(file, mode);
              //存入缓存
                cache.put(file, sp);
                return sp;
            }
        }
        if ((mode & Context.MODE_MULTI_PROCESS) != 0 ||
            getApplicationInfo().targetSdkVersion < android.os.Build.VERSION_CODES.HONEYCOMB) {
          //重新加载XML文件
            sp.startReloadIfChangedUnexpectedly();
        }
        return sp;
    }
```

主要执行了三步：

1. 根据传入的`name`在对应路径下生成对应的xml文件，并存入`mSharedPrefsPaths`进行缓存。
2. 创建文件完毕后，再去创建对应的`SharedPreferencesImpl`对象，创建完成后缓存到`cache`中。*每一个xml文件都会对应一个SP对象*
3. 若设置了`mode`为`Context.MODE_MULTI_PROCESS`，就需要重新去加载一次`xml`文件。

### 初始化

SP对象最后都是由`SharedPreferencesImpl`进行构建

```java
    SharedPreferencesImpl(File file, int mode) {
        mFile = file;
      //构建备份文件
        mBackupFile = makeBackupFile(file);
        mMode = mode;
        mLoaded = false;
      //缓存当前SP存储的键值对
        mMap = null;
        mThrowable = null;
      //开始加载磁盘的xml文件
        startLoadFromDisk();
    }
```

### 加载文件

![加载文件](/images/SP-源码解析2.png)

开启一个异步线程去加载xml文件，防止阻塞主线程

```java
    private void startLoadFromDisk() {
      //上锁保证线程安全
        synchronized (mLock) {
            mLoaded = false;
        }
        new Thread("SharedPreferencesImpl-load") {
            public void run() {
                loadFromDisk();
            }
        }.start();
    }
```

`loadFromDisk()`时，需要判断当前是否存在备份文件，`若存在备份文件就意味着上一次写入文件的过程出现了异常，导致写入失败`。

```java
    private void loadFromDisk() {
        synchronized (mLock) {
            if (mLoaded) {
                return;
            }
            if (mBackupFile.exists()) {
              //删除源文件
                mFile.delete();
              //备份文件重命名为 源文件
                mBackupFile.renameTo(mFile);
            }
        }
      ...
        synchronized (mLock) {
            mLoaded = true;
            mThrowable = thrown;
                    try {
                if (thrown == null) {
                    if (map != null) {
                      //解析成功 赋值到mMap进行缓存
                        mMap = map;
                        mStatTimestamp = stat.st_mtim;
                        mStatSize = stat.st_size;
                    } else {
                        mMap = new HashMap<>();
                    }
                }
            } catch (Throwable t) {
                mThrowable = t;
            } finally {
                //释放锁 通知其他线程可以开始使用SP对象
                mLock.notifyAll();
            }
      }
    }
```

这里就表现了SP的**文件损坏时的备份机制**，当文件写入异常时，启用备份文件保证之前的数据不会出现异常。



### 获取数据

![获取数据](/images/SP-源码解析3.png)

```java
... 初始化完成 sp对象
sp.getString("a","b"); //从sp获取a的值
```

`获取数据`支持部分数据类型，例如`int`、`long`、`String`等



```java
//SharedPreferencesImpl.java
public String getString(key){}
public Set<String> getStringSet(key){}
public int getInt(key){}
public long getLong(key){}
public float getFloat(key){}
public boolean getBoolean(key){}

//以下拿 getString() 举例分析获取数据流程
    public String getString(String key, @Nullable String defValue) {
        synchronized (mLock) {
            awaitLoadedLocked();
            String v = (String)mMap.get(key);
            return v != null ? v : defValue;
        }
    }

    private void awaitLoadedLocked() {
        while (!mLoaded) {
            try {
              //等待mLock释放
                mLock.wait();
            } catch (InterruptedException unused) {
            }
        }
        if (mThrowable != null) {
            throw new IllegalStateException(mThrowable);
        }
    }
```

`getXX()`都是运行在主线程的，并且想要获取数据就必须等待`加载文件`这一步完成。等待`mLock.notifyAll()`才可以继续向下执行。

> 如果需要读取一个很大的文件，在调用`getXX()`之后，就需要一直进行等待，而导致主线程发生阻塞。

xml文件加载完毕后，`getXX()`从`mMap`获取数据，就不需要重新读取文件。



#### 获取数据异常

SP中进行存储时，可能会导致同一个key存储不同类型的值，导致获取数据的时候抛出`ClassCastException`异常。



### 写入数据

![写入数据](/images/SP-源码解析4.png)

```java
... 初始化完成 sp对象
SharedPreferences.Editor mEditor = sharedPreferences.edit();
//写入数据
mEditor.putString("a","c");
```

`写入数据`同样支持部分数据类型。*但是不是通过SP对象，而是通过`Editor`对象进行数据的写入*

#### Editor对象

写入数据的相关操作都要通过`Editor`，本体是一个接口

```java
//SharedPreferences.java
public interface Editor {
  //放入对应类型的对象
  Editor putString(String key, @Nullable String value);
  Editor putStringSet(String key, @Nullable Set<String> values);
  Editor putInt(String key, int value);
  Editor putLong(String key, long value);
  Editor putFloat(String key, float value);
  Editor putBoolean(String key, boolean value);
  //删除数据
  Editor remove(String key);
  Editor clear();
  //提交数据
  boolean commit();
  void apply();
}
```

`Editor`只是一个接口，`EditorImpl`才是具体的实现类。

```java
//SharedPreferencesImpl.java
    public final class EditorImpl implements Editor {
        private final Object mEditorLock = new Object();

        @GuardedBy("mEditorLock")
        private final Map<String, Object> mModified = new HashMap<>();
      
              @Override
        public Editor putString(String key, @Nullable String value) {
          //通过synchronized修饰保证线程安全。
            synchronized (mEditorLock) {
              //存入临时map中，后续有用
                mModified.put(key, value);
                return this;
            }
        }
    }
```

`mModified`保存的是用户通过`putXX()`新增的数据，数据有效期位于`第一次putXX()`到`commit()/apply()`之间。



### 提交数据

上面`写入数据`完毕后，最后要调用一次`commit()/apply()`准备把数据写入到对应xml文件中。



#### "半同步"提交数据——commit

![commit](/images/SP-commit.png)

```java
... 初始化完成 sp对象
SharedPreferences.Editor mEditor = sharedPreferences.edit();
//写入数据
mEditor.putString("a","c");
//提交数据
mEditor.commit(); 
```

```java
//SharedPreferencesImpl.java
        @Override
        public boolean commit() {
            long startTime = 0;

            if (DEBUG) {
                startTime = System.currentTimeMillis();
            }

            MemoryCommitResult mcr = commitToMemory();//写入内存

            SharedPreferencesImpl.this.enqueueDiskWrite(
                mcr, null /* sync write on this thread okay */);//写入磁盘
            try {
              //等待写入磁盘任务执行完毕 此处可能导致主线程阻塞
                mcr.writtenToDiskLatch.await();
            } catch (InterruptedException e) {
                return false;
            } finally {
            }
            notifyListeners(mcr);//通知监听
            return mcr.writeToDiskResult;
        }

```

`commit()`先后调用了`commitToMemory()/*写入数据到mMap中，等待写入磁盘*/`、`enqueueDiskWrite()/*将数据写入到磁盘中*/`，通过`writeToFile()`写入到磁盘中并会返回对应写入结果。

`commit()`如果当前没有线程在写入文件时，就会直接在当前线程开启写入磁盘任务，导致主线程阻塞(*可能发生ANR*)，等待线程执行完毕。如果在写入文件，就会通过`QueuedWork`开启异步执行。(*这就是半同步的原因*)

**`commit()`执行都是同步的，而且每次都是写入全量的数据，会导致主线程阻塞。**

![SharedPreferences-commit](/images/SharedPreferences-commit.jpg)

#### 异步提交数据——apply

![apply](/images/SP-apply.png)

```java
... 初始化完成 sp对象
SharedPreferences.Editor mEditor = sharedPreferences.edit();
//写入数据
mEditor.putString("a","c");
//提交数据
mEditor.apply(); 
```



```java
        @Override
        public void apply() {
            final long startTime = System.currentTimeMillis();

            final MemoryCommitResult mcr = commitToMemory();//写入内存
            final Runnable awaitCommit = new Runnable() {
                    @Override
                    public void run() {
                        try {
                            mcr.writtenToDiskLatch.await();//等待磁盘写入任务完成
                        } catch (InterruptedException ignored) {
                        }
                    }
                };

          //添加 QueuedWork执行完毕的回调监听
            QueuedWork.addFinisher(awaitCommit);

            Runnable postWriteRunnable = new Runnable() {
                    @Override
                    public void run() {
                        awaitCommit.run();
                        QueuedWork.removeFinisher(awaitCommit);
                    }
                };
          //开启异步线程执行写入任务
            SharedPreferencesImpl.this.enqueueDiskWrite(mcr, postWriteRunnable);

            notifyListeners(mcr);
        }
```

`apply()`也先调用`commitToMemory()`将更改提交到内存，之后调用`enqueueDiskWrite()`开启写入磁盘任务。

`apply()`是提交任务到线程池后立即返回，不等待磁盘写入完成；它只保证内存中的最新值立即可见。

**虽然`apply()`是异步执行，但在生命周期关键路径上仍可能触发等待，后文会分析。**

#### 缓存写入内存

![写入内存](/images/SP-commitToMemory.png)

将缓存文件写入内存

```java
        // Returns true if any changes were made
        private MemoryCommitResult commitToMemory() {
            long memoryStateGeneration;
            List<String> keysModified = null;
            Set<OnSharedPreferenceChangeListener> listeners = null;
            Map<String, Object> mapToWriteToDisk;

            synchronized (SharedPreferencesImpl.this.mLock) {
                if (mDiskWritesInFlight > 0) {
                    mMap = new HashMap<String, Object>(mMap);
                }
              //软拷贝
                mapToWriteToDisk = mMap;
                mDiskWritesInFlight++;

                synchronized (mEditorLock) {
                    boolean changesMade = false;
                   //调用了 clear() 清理的是所有数据
                    if (mClear) {
                        if (!mapToWriteToDisk.isEmpty()) {
                            changesMade = true;
                            mapToWriteToDisk.clear();
                        }
                        mClear = false;
                    }

                  //mModified的值写入到 mapToWriteToDisk中，准备写入到文件中
                    for (Map.Entry<String, Object> e : mModified.entrySet()) {
                        String k = e.getKey();
                        Object v = e.getValue();
                        // "this" is the magic value for a removal mutation. In addition,
                        // setting a value to "null" for a given key is specified to be
                        // equivalent to calling remove on that key.
                        if (v == this || v == null) {
                            if (!mapToWriteToDisk.containsKey(k)) {
                                continue;
                            }
                            mapToWriteToDisk.remove(k);
                        } else {
                            if (mapToWriteToDisk.containsKey(k)) {
                                Object existingValue = mapToWriteToDisk.get(k);
                                if (existingValue != null && existingValue.equals(v)) {
                                    continue;
                                }
                            }
                            mapToWriteToDisk.put(k, v);
                        }
                      //发生了变化
                      changesMade = true;
                    }
                  //执行完毕后 mMap和 mapToWriteToDisk内容一致

                  //写入内存后，清除原先未写入的数据
                    mModified.clear();
                  
                    if (changesMade) {
                      //差异计数 +1 
                        mCurrentMemoryStateGeneration++;
                    }                  
                }
            }
            return new MemoryCommitResult(memoryStateGeneration, keysModified, listeners,
                    mapToWriteToDisk);
        }
```

将`mModified`的值写入到`mapToWriteToDisk`，其实`mMap`中也是一样的内容，然后清空`mModified`的数据，拼接得到一个`MemoryCommitResult`对象，里面持有的就是要写入`xml`文件的内容。



#### 内存写入磁盘

![写入磁盘](/images/SP-enqueueDiskWrite.png)

把存入内存的数据`mapToWriteToDisk`写入到对应的`xml`文件。

```java
private void enqueueDiskWrite(final MemoryCommitResult mcr,
                               //commit() 传入为null apply() 传入不为null 
                                  final Runnable postWriteRunnable) {
        final boolean isFromSyncCommit = (postWriteRunnable == null);//commit 为 true apply为false

        final Runnable writeToDiskRunnable = new Runnable() {
                @Override
                public void run() {
                    synchronized (mWritingToDiskLock) {
                      //写入内容到文件
                        writeToFile(mcr, isFromSyncCommit);
                    }
                    synchronized (mLock) {
                        mDiskWritesInFlight--;
                    }
                    if (postWriteRunnable != null) {
                      //直接执行传入的 任务
                        postWriteRunnable.run();
                    }
                }
            };
       //当前为 commit()
        if (isFromSyncCommit) {
            boolean wasEmpty = false;
            synchronized (mLock) {
              //当前是否只有一个写入硬盘的需求
                wasEmpty = mDiskWritesInFlight == 1;
            }
            if (wasEmpty) {
              //只有一个硬盘写入请求，在当前线程执行任务
                writeToDiskRunnable.run();
                return;
            }
        }
       //存在多个写入硬盘请求，都要通过 QueuedWork 执行写入任务
        QueuedWork.queue(writeToDiskRunnable, !isFromSyncCommit);
    }
```

```java
    /*
     *  写入数据到磁盘中
     *  把已存在的文件进行重命名 添加.bak后缀，作为备份文件存在。删除源文件
     *  新建 源文件，重新写入所有数据，同时记录写入时间
     *  如果写入文件失败，删除新建的文件，并返回失败
     *  如果写入文件成功，删除备份文件，返回成功
     */
    private void writeToFile(MemoryCommitResult mcr, boolean isFromSyncCommit) {
      //把当前文件做一份备份文件
           if (!backupFileExists) {
                if (!mFile.renameTo(mBackupFile)) {
                    Log.e(TAG, "Couldn't rename file " + mFile
                          + " to backup file " + mBackupFile);
                    mcr.setDiskWriteResult(false, false);
                    return;
                }
            } else {
                mFile.delete();
            }    
      ...
        
    }

        void setDiskWriteResult(boolean wasWritten, boolean result) {
            this.wasWritten = wasWritten;
            writeToDiskResult = result;
          //比较两次请求的版本号，版本号不一致表示发生了改变
            if (mDiskStateGeneration < mcr.memoryStateGeneration) {
                if (isFromSyncCommit) {
                    needsWrite = true;
                } else {
                    synchronized (mLock) {
                        // No need to persist intermediate states. Just wait for the latest state to
                        // be persisted.
                        if (mCurrentMemoryStateGeneration == mcr.memoryStateGeneration) {
                            needsWrite = true;
                        }
                    }
                }
            }
           //版本号一致，就不重复执行写入磁盘任务
            if (!needsWrite) {
                mcr.setDiskWriteResult(false, true);
                return;
            }          
          
          //执行完毕一次任务 自动-1
            writtenToDiskLatch.countDown();
        }
```

写入到`xml`文件之前，会把原有的数据保存在`.bak`文件进行备份，用于**写入磁盘过程中发生任何异常都可以恢复原有数据。**

根据上述流程`commit()/apply()提交数据 -> 写入内存 -> 写入硬盘`，每次调用都会走一遍完整流程，导致频繁的IO使用。

官方更建议**将数据的更新合并到一次写操作中，即多次写入一次提交。**

#### commit与apply的比较

- `apply()`没有返回值，`commit()`有返回值可以知道文件是否写入成功
- `apply()`将修改提交内存，再异步写入文件；`commit()`同步写入文件。
- 并发`commit()`时，需要等待正在执行的数据写入到文件后才会继续往下执行；`apply()`先更新到内存，后面再次调用会覆盖原有的内存数据，接下来再异步写入文件即可。

### 删除数据

```java
SharedPreferences sp = getSharedPreferences("a",MODE_PRIVATE);
SharedPreferences.Editor editor =  sp.edit();
//写入数据
editor.putString("a","b");
//通过remove 清除单个数据
editor.remove("a");
//提交数据
editor.commit();

//清除所有数据
editor.clear();
editor.commit();
```

```java
        private MemoryCommitResult commitToMemory() {
          Map<String, Object> mapToWriteToDisk;
          ...
          synchronized (SharedPreferencesImpl.this.mLock) {
            //赋值原有数据
            mapToWriteToDisk = mMap;
            ...
              synchronized (mEditorLock) {
                        boolean changesMade = false;
                        if (!mapToWriteToDisk.isEmpty()) {
                            changesMade = true;
                          //清除原有数据
                            mapToWriteToDisk.clear();
                        }
                        mClear = false;              
            }
          }
          
        }
//最后写入的就是一个空map，导致所有存储的数据都被清空
```



### 数据改变监听

SP支持监听数据的改变，返回的是修改的内容

```java
SharedPreferences sp = getSharedPreferences("a",MODE_PRIVATE);
SharedPreferences.Editor editor =  sp.edit();

SharedPreferences.OnSharedPreferenceChangeListener listener =  new SharedPreferences.OnSharedPreferenceChangeListener() {
            @Override
            public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
                //打印发生了改变的值
            }
        };

//对应的需要在 页面销毁时，及时取消监听
sp.unregisterOnSharedPreferenceChangeListener(listener);
```

```java
//SharedPreferencesImpl.java
    public void registerOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
        synchronized(mLock) {
            mListeners.put(listener, CONTENT);
        }
    }

        private MemoryCommitResult commitToMemory() {
          ...
                boolean hasListeners = mListeners.size() > 0;
                if (hasListeners) {
                    keysModified = new ArrayList<String>();
                  //转化 去重
                    listeners = new HashSet<OnSharedPreferenceChangeListener>(mListeners.keySet());
                }            
          ...
            //作为参数 传入 MCR
            return new MemoryCommitResult(memoryStateGeneration, keysModified, listeners,
                    mapToWriteToDisk);            
        }

//发生变化后通知回调
        private void notifyListeners(final MemoryCommitResult mcr) {
            if (mcr.listeners == null || mcr.keysModified == null ||
                mcr.keysModified.size() == 0) {
                return;
            }
            if (Looper.myLooper() == Looper.getMainLooper()) {
              //在主线程直接回调
                for (int i = mcr.keysModified.size() - 1; i >= 0; i--) {
                    final String key = mcr.keysModified.get(i);
                    for (OnSharedPreferenceChangeListener listener : mcr.listeners) {
                        if (listener != null) {
                            listener.onSharedPreferenceChanged(SharedPreferencesImpl.this, key);
                        }
                    }
                }
            } else {
                // 不在主线程切换到主线程回调
                ActivityThread.sMainThreadHandler.post(() -> notifyListeners(mcr));
            }
        }
```

`commit()`需要在数据写入文件后，才可以回调到`notifyListeners()`通知数据发生变化。

`apply()`只要数据在写入内存后，就会直接回调。



### QueuedWork

![SP-QueuedWork](/images/SP-QueuedWork.png)

系统提供的异步工具类，内部通过`HandlerThread`作为工作线程，用于**跟踪那些未完成或尚未结束的全局任务**。

#### 初始化

```java
    private static Handler getHandler() {
        synchronized (sLock) {
            if (sHandler == null) {
              //新建HandlerThread执行任务
                HandlerThread handlerThread = new HandlerThread("queued-work-looper",
                        Process.THREAD_PRIORITY_FOREGROUND);
                handlerThread.start();

                sHandler = new QueuedWorkHandler(handlerThread.getLooper());
            }
            return sHandler;
        }
    }
```



#### queue()

向QueuedWork中添加任务

```java
    public static void queue(Runnable work, boolean shouldDelay) {
        Handler handler = getHandler();

        synchronized (sLock) {
            sWork.add(work);

            if (shouldDelay && sCanDelay) {
                handler.sendEmptyMessageDelayed(QueuedWorkHandler.MSG_RUN, DELAY);
            } else {
                handler.sendEmptyMessage(QueuedWorkHandler.MSG_RUN);
            }
        }
    }
```

`commit()`时，`shouldDelay`为false，直接发送消息

`apply()`时，`shouldDelay`为true，需要延迟100ms再发送消息，**避免频繁的磁盘写入操作**



#### addFinisher()

添加完成任务完成回调

```java
    @GuardedBy("sLock")
    private static final LinkedList<Runnable> sFinishers = new LinkedList<>();

    public static void addFinisher(Runnable finisher) {
        synchronized (sLock) {
          //将完成任务后的Runnable添加进去，等待任务完成后执行
            sFinishers.add(finisher);
        }
    }
```



#### processPendingWork()

执行写入磁盘任务

```java
    private static void processPendingWork() {
        long startTime = 0;

        synchronized (sProcessingWork) {
            LinkedList<Runnable> work;

            synchronized (sLock) {
                work = (LinkedList<Runnable>) sWork.clone();
                sWork.clear();
                getHandler().removeMessages(QueuedWorkHandler.MSG_RUN);
            }

            if (work.size() > 0) {
                for (Runnable w : work) {
                  //执行任务
                    w.run();
                }
            }
        }
    }
```



![QueuedWork执行流程](/images/QueuedWork执行流程.jpg)



#### * waitToFinish()

等待任务完成。这里也就是`ANR`发生的根本原因

```java
//主线程调用 
public static void waitToFinish() {
        long startTime = System.currentTimeMillis();
        boolean hadMessages = false;

        Handler handler = getHandler();

        try {
          //执行未完成的任务
            processPendingWork();
        } finally {
            StrictMode.setThreadPolicy(oldPolicy);
        }

        try {
            while (true) {
                Runnable finisher;

                synchronized (sLock) {
                    finisher = sFinishers.poll();//取出 任务完成后的回调
                }

                if (finisher == null) {
                    break;
                }
              //此处会导致阻塞的发生
                finisher.run();//执行 任务完成后的回调  对应执行的就是 writtenToDiskLatch.await()
            }
        } finally {
            sCanDelay = true;
        }

    }


//SharedPreferencesImpl.java
apply(){
              final Runnable awaitCommit = new Runnable() {
                    @Override
                    public void run() {
                        try {
                          //需要等待主线程写入任务完毕
                            mcr.writtenToDiskLatch.await();//等待磁盘写入任务完成
                        } catch (InterruptedException ignored) {
                        }
                    }
                };

          //添加 QueuedWork执行完毕的回调监听
            QueuedWork.addFinisher(awaitCommit);
}
```

调用`waitToFinish()`时，会主动调用`processPendingWork()`去执行任务，在HandlerThread执行写入磁盘任务。

`waitToFinish()`会一直等待写入任务执行完毕，其他什么都不做，当存在很多写入任务时，会依次执行，文件很大时效率很低，就有可能导致ANR。



## 线程安全

![线程安全](/images/SP-线程安全.png)

SP的线程安全分为两部分分析

### 读线程安全

```java
  @GuardedBy("mLock")
  private Map<String, Object> mMap;//通过注解的形式 告知该对象由哪把锁控制


public String getString(String key, @Nullable String defValue) {
    synchronized (mLock) {
        String v = (String)mMap.get(key);
        return v != null ? v : defValue;
    }
}
```

`读操作`主要是从`mMap`读取缓存的值，避免其他线程执行`写操作`导致线程不安全，通过`mLock`保证线程安全。

### 写线程安全

写操作，主要分为三步，每一步都有不同的锁进行控制。

#### 写入对象

```java
        @GuardedBy("mEditorLock")
        private final Map<String, Object> mModified = new HashMap<>();

        @Override
        public Editor putString(String key, @Nullable String value) {
            synchronized (mEditorLock) {
                mModified.put(key, value);
                return this;
            }
        }
```

第一把锁`mEditorLock`保证写入到`mModified`线程安全

#### 写入内存

```java
synchronized (SharedPreferencesImpl.this.mLock) {
  //控制mMap赋值
  if (mDiskWritesInFlight > 0) {
    mMap = new HashMap<String, Object>(mMap);
  }
  mapToWriteToDisk = mMap;
  synchronized (mEditorLock) {
    boolean changesMade = false;
    //保证mModified 与 mapToWriteToDisk的合并安全
    for (Map.Entry<String, Object> e : mModified.entrySet()) {
      mapToWriteToDisk.put(k, v);
    }
    
  }
```

写入内存时，需要把`mModify`待添加的数据合并到`mapToWriteToDisk`中，这时需要通过两把锁保证线程安全。

- 保证`mapToWriteToDisk`赋值时数据正确
- 保证`mModified`合并到`mapToWriteToDisk`时线程安全



#### 写入硬盘

```java
//将mapToWriteToDisk的内容写入到 xml文件中
synchronized (mWritingToDiskLock) {
   writeToFile(mcr, isFromSyncCommit);
}
```

写入硬盘时，保证写入时内容不会发生改变。





## 进程安全

![进程安全](/images/SP-进程安全.png)

**SharedPreferences不是进程安全的。**

### MODE_MULTI_PROCESS

```java
        if ((mode & Context.MODE_MULTI_PROCESS) != 0 ||
            getApplicationInfo().targetSdkVersion < android.os.Build.VERSION_CODES.HONEYCOMB) {
          //重新加载XML文件
            sp.startReloadIfChangedUnexpectedly();
        }
```

唯一的作用就是 切换进程时重新加载XML文件内容。

**当在频繁跨进程读写时就会有数据丢失的可能。**



### ContentProvider(官方推荐)

`ContentProvider`是Android提供的跨进程组件，可以把底层存储实现为SP/数据库，并在Provider层统一串行化读写，保证多进程一致性。

可落地的最小实践：

1. 仅在Provider进程执行真实读写，客户端进程只走`ContentResolver`。
2. 对写操作做单线程串行化，避免并发覆盖。
3. 对外只暴露必要URI与字段，避免无边界读写。



### 文件锁

SharedPreferences 本质是对xml文件的读写，可以通过对xml文件添加文件锁，就能保证进程安全。

> FileLock(文件锁)用来表示文件区域锁定标记，可以通过对一个可写文件加锁，保证同时只有一个进程可以拿到文件的锁，这个进程就可以对文件进行访问；其他拿不到锁的进程要么选择被挂起等待，要么去做一些其他的事情。
>
> 可以保证众进程可以顺序访问文件，并且可以通过`FileLock`进行并发控制，保证进程的顺序执行。

#### 获取锁

- FileChannel.lock()：阻塞直至获得文件锁。*默认锁定整个文件*
- FileChannel.lock(position,size,shared)：阻塞直至获取文件的部分数据的文件锁
- FileChannel.tryLock()：立即返回，要么返回锁，要么返回null(获取锁失败)

#### 释放锁

- FileLock.release()：释放当前文件锁

#### 检测锁

- FileLock.isValid()：检测文件锁的有效性



文件锁方案也建议只作为兜底：

- 能保证互斥，但会引入额外阻塞与复杂度；
- 需要严格处理异常分支中的锁释放；
- 高频场景更建议使用官方推荐的`ContentProvider`或直接迁移`MMKV/DataStore`。

## ANR分析

![ANR分析](/images/SP-ANR分析.png)

在上面有提到`QueuedWork.waitToFinish()`是要在写入文件的操作完成后才会结束，且这个方法会运行在当前线程，极有可能导致阻塞/ANR。

### `waitToFinish()`调用场景

通过全局搜索`QueuedWork.waitToFinish()`找到在`ActivityThread`使用的较多

```java
//ActivityThread.java
    public void handleStopActivity(IBinder token, boolean show, int configChanges,
            PendingTransactionActions pendingActions, boolean finalStateRequest, String reason) {
      ...
        if (!r.isPreHoneycomb()) {
            QueuedWork.waitToFinish();
        }
    }

    private void handleSleeping(IBinder token, boolean sleeping) {
      ...
           if (sleeping) {
            if (!r.stopped && !r.isPreHoneycomb()) {
                callActivityOnStop(r, true /* saveState */, "sleeping");
            }

            // Make sure any pending writes are now committed.
            if (!r.isPreHoneycomb()) {
                QueuedWork.waitToFinish();
            }
    }
```



会在`onStop()`时调用`QueuedWork.waitToFinish()`等待当前未执行完毕的写入任务结束，才可以释放锁。此时就会阻塞主线程，可能导致ANR。



### 解决方案

- 避免在`onPause/onStop`前临时堆积大量`apply()`任务，写入尽量前移并做批量合并。
- 高频写入场景优先使用`MMKV/DataStore`，减少XML全量重写成本。
- 不建议通过反射清理`QueuedWork.sFinishers`，该方案依赖系统实现细节，兼容性与稳定性风险较高。
- 需要“立即拿到落盘结果”时才使用`commit()`，其余场景优先`apply()`。



## 使用注意事项

1. 建议不要在SP里存储特别大的key/value,因为内容都是一次性加载到内存中，过大会导致卡顿/ANR。
2. 不要频繁调用`commit()/apply()`，SP的数据每次都是全量写入文件，尤其是`commit()`直接同步操作，更容易卡顿。**建议批量写一次提交**
3. `MODE_MULTI_PROCESS`是在每次`getSharedPreferences`时检查磁盘上配置文件上次修改时间和文件大小，一旦有所修改则会重新从磁盘加载文件，所以并不能保证多进程数据的实时同步。
4. 高频写操作的key与高频读操作的key可以适当的拆分文件，减少同步锁的竞争。
5. **最好写入轻量级的数据，不要存储大量的数据。**



## 替换方案

### MMKV

> 通过`mmap`内存映射文件，提供一段可随时写入的内存块，APP只管往里写数据，由操作系统负责将内存回写到文件，而不必担心Crash导致数据丢失。
>
> 写入的数据格式为 `Protobuf`

[Github-MMKV](https://github.com/Tencent/MMKV)

[MMKV原理](https://github.com/Tencent/MMKV/wiki/design)

[MMKV for Android 多进程设计与实现](https://github.com/Tencent/MMKV/wiki/android_ipc)



## 参考链接

[全面解析SharedPreferences](http://gityuan.com/2017/06/18/SharedPreferences/)

[SharedPreferences的设计与实现](https://juejin.im/post/6884505736836022280#heading-9)

[Jetpack DataStore 分析](https://juejin.im/post/6881442312560803853#heading-4)

[剖析 SharedPreference apply 引起的 ANR 问题](https://mp.weixin.qq.com/s?__biz=MzI1MzYzMjE0MQ==&mid=2247484387&idx=1&sn=e3c8d6ef52520c51b5e07306d9750e70&scene=21#wechat_redirect)

[Android 源码仓库](https://cs.android.com/)
