---
title: Java - 反射
date: 2018-12-14 16:41:02
tags: Java
top: 10
---

## Java反射机制基础

{% fullimage /images/反射-基础概念.png,反射-基础概念,反射-基础概念%}

### 反射机制定义

反射(`Reflection`)是Java的特征之一，它允许运行中的Java程序获取自身的信息，并且可以操作类或对象的内部属性。对于任何一个类，能够知道这个类中的所有属性和方法；对于任何一个对象，都能够调用它的任意一个方法和属性。

### 反射机制功能

通过反射，可以在运行时获取程序中的每一个类型的成员和成员信息。利用Java的反射机制可以动态的创建对象并调用其属性。反射可以提供运行时的类信息，并且可以支持这个类在运行过程中加载进来，甚至在编译时也没有加入编译的类。

主要提供了如下功能：

- 在运行时判断任意一个对象所属的类
- 在运行时构造任意一个类的对象
- 在运行时判断任意一个类所具有的成员变量和方法
- 在运行时调用任意一个对象的方法
- 生成动态代理

**一切都是在运行时而不是编译时。**

### 反射机制支持

由`java.lang.reflect`提供反射机制的支持，主要包含了三个类：

- `Field`：使用`getField()`和`setField()`读取和修改Field对象关联的字段
- `Method`：使用`invoke()`调用`Method`对象关联的方法
- `Constructor`：创建新的对象

### 反射机制优点

- **可拓展性**：应用程序可以利用全限定名创建可扩展对象的实例，来使用来自外部的用户自定义类
- **类浏览器和可视化开发环境**：可以枚举类的成员
- **调试器和调试工具**：可以调用类中的`private`或者`protected`的对象。

### 反射机制缺点

- **性能开销**：反射涉及了动态类型的解析，所以JVM无法对这些代码进行优化。导致效率低
- **安全限制**：使用反射要求在没有安全限制的环境下去进行
- **内部暴露**：由于反射允许代码执行一些正常情况下无法执行的操作(*访问私有变量或方法*)，反射代码也破坏了抽象性，当内部代码发生改变时，反射的代码也需要进行相应调整。

## Java反射机制使用场景

- 用于逆向代码，反编译
- 与注解相结合的框架 例如`Retrofit`使用的运行时注解
- 单纯的利用反射机制的框架 例如`EventBus`所以那些Event都不能被混淆
- 动态代理

## Java反射机制的基本运用

{% fullimage /images/反射-基本运用.png,反射-基本运用,反射-基本运用%}

### 获得Class对象

> 每个类被加载后，系统都会为其生成一个对应的Class对象，通过该Class对象就可以访问到JVM中的这个类

获取Class对象的方法有如下三种

#### 使用`Class.forName(String className/*必须完整包名*/)`获取对象。

```java
Class<?> clazz = Class.forName("com.example.wxy.FieldUtil");
```

#### 调用类的class属性来获取该类对应的Class对象

```java
Class<?> clazz = FieldUtil.class;
```

#### 调用某个对象的`getClass()`，

```java
Person person = new Person();
Class<?> class = Person.getClass();
```



### 获取Class对象的方法

主要有以下几个方法：

#### `getDeclaredMethods()`

> 返回类或接口声明的所有方法，包括`public(公共)、private(私有)、protected(保护)，default(默认)`，但不包括继承的方法

```java
public Method[] getDeclaredMethods() throws SecurityException
```

#### `getMethods()`

> 返回类或接口所有的`公共(public)`方法，包括父类的`公共(public)`方法

```java
public Method[] getMethods() throws SecurityException
```

#### `getDeclaredMethod()`

> 返回Class对象对应类的且带指定形参列表的所有方法

```java
/**
* name 方法名称
* parameterTypes 参数对应的Class对象
*/
public Method getDeclaredMethod(String name, Class<?>... parameterTypes)
```

#### `getMethod()`

> 返回Class对象对应类的且带指定形参列表的`公共(public)`方法

```java
/**
* name 方法名称
* parameterTypes 参数对应的Class对象
*/
private Method getMethod(String name, Class<?>... parameterTypes)
```

#### 实例分析

```java
public class reflect {
    public static void main(String[] args) {
        try {
            Class<?> methodClass = MethodClass.class;
            //获取所有共用方法，且包含父类方法
            Method[] methods = methodClass.getMethods();
            //获取所有方法，不包含父类方法
            Method[] declaredMethods = methodClass.getDeclaredMethods();
            //反射得到私有add()
            Method addMethod = methodClass.getDeclaredMethod("add", int.class, int.class);
            //反射得到共有sub()
            Method subMethod = methodClass.getMethod("sub", int.class, int.class);
            System.err.println("Declared Method "+addMethod);
            System.err.println("public Method "+subMethod);
            for (Method method : methods) {
                System.err.println("Public Methods "+method);
            }
            for (Method method : declaredMethods) {
                System.err.println("Declared Methods "+method);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

class MethodClass {
    public final int a = 4;
    private int add(int a, int b) {
        return a + b;
    }
    public int sub(int a, int b) {
        return a - b;
    }
}

运行结果为:

Declared Method private int MethodClass.add(int,int)
Public Method public int MethodClass.sub(int,int)
//获取到的所有公共方法 包含了父类 Object中的公共方法
Public Methods public int MethodClass.sub(int,int)
Public Methods public final void java.lang.Object.wait(long,int) throws java.lang.InterruptedException
Public Methods public final native void java.lang.Object.wait(long) throws java.lang.InterruptedException
Public Methods public final void java.lang.Object.wait() throws java.lang.InterruptedException
Public Methods public boolean java.lang.Object.equals(java.lang.Object)
Public Methods public java.lang.String java.lang.Object.toString()
Public Methods public native int java.lang.Object.hashCode()
Public Methods public final native java.lang.Class java.lang.Object.getClass()
Public Methods public final native void java.lang.Object.notify()
Public Methods public final native void java.lang.Object.notifyAll()
//获取到当前类的所有方法，不包含父类
Declared Methods private int MethodClass.add(int,int)
Declared Methods public int MethodClass.sub(int,int)
```

### 获取Class对象的成员变量

主要有以下方法：

#### `getFields()`

> 获取Class对象的public属性的所有变量

```java
 public Field[] getFields() throws SecurityException 
```

#### `getField()`

> 获取Class对象的指定public属性变量

```java
public Field getField(String name) throws NoSuchFieldException {
```

#### `getDeclardFields()`

> 获取Class对象的所有变量

```java
public native Field[] getDeclaredFields();
```

#### `getDeclardField()`

> 获取Class对象的指定属性变量

```java
public native Field getDeclaredField(String name) throws NoSuchFieldException
```

#### 实例分析

```java
public class reflect {
    public static void main(String[] args) {
        try {
            Class<?> methodClass = MethodClass.class;
            //返回所有public属性变量
            Field[] fields = methodClass.getFields();
            //返回所有变量
            Field[] declaredFields = methodClass.getDeclaredFields();
            Field field = methodClass.getField("a");
            Field declaredField = methodClass.getDeclaredField("c");
            for (Field f : fields) {
                System.err.println("Public Fields " + f);
            }
            for (Field f : declaredFields) {
                System.err.println("Declared Fields " + f);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

class MethodClass {
    public final int a = 4;
    private final int c = 5;
}

运行结果为：
Public Fields public final int MethodClass.a
Declared Fields public final int MethodClass.a
Declared Fields private final int MethodClass.c
```

### 获取Class对象的构造函数

#### `getConstructors()`

> 获取Class对象的Public构造函数

```java
public Constructor<?>[] getConstructors() throws SecurityException 
```

#### `getDeclaredConstructors()`

> 获取Class对象的所有构造函数

```java
public Constructor<?>[] getDeclaredConstructors() throws SecurityException
```

#### `getConstructor()`

> 获取指定声明的public构造函数

```java
/**
* parameterTypes 参数对应的Class对象
*/
public Constructor<T> getConstructor(Class<?>... parameterTypes) throws NoSuchMethodException, SecurityException
```

#### `getDeclaredConstructor()`

> 获取指定声明的构造函数

```java
/**
* parameterTypes 参数对应的Class对象
*/
public Constructor<T> getDeclaredConstructor(Class<?>... parameterTypes) throws NoSuchMethodException, SecurityException
```

#### 实例分析

```java
public class reflect {
    public static void main(String[] args) {
        try {
            Class<?> methodClass = MethodClass.class;
            Constructor<?>[] constructors = methodClass.getConstructors();
            Constructor<?>[] declaredConstructors = methodClass.getDeclaredConstructors();
            Constructor<?> constructor = methodClass.getConstructor(int.class,int.class);
            Constructor<?> declaredConstructor = methodClass.getDeclaredConstructor(int.class,int.class,int.class);

            for (Constructor f : constructors) {
                System.err.println("Public Constructors " + f);
            }
            for (Constructor f : declaredConstructors) {
                System.err.println("Declared Constructors " + f);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

class MethodClass {
    public MethodClass(int a ,int b){

    }

    private MethodClass(int a,int b,int c){

    }
}

运行结果：
Public Constructors public MethodClass(int,int)
Declared Constructors public MethodClass(int,int)
Declared Constructors private MethodClass(int,int,int)
```

### 创建Class对象实例

#### `newInstance()`

> 创建对象的实例 **需要对应Class有无参构造函数**

```java
public native T newInstance() throws InstantiationException, IllegalAccessException;
```

#### `Constructor.newInstance()`

> 通过构造器去创建对象实例

```java
public T newInstance(Object ... initargs) throws InstantiationException, IllegalAccessException, IllegalArgumentException, InvocationTargetException
```

#### 实例分析

```java
public class reflect {
    public static void main(String[] args) {
        try {
            Class<?> methodClass = MethodClass.class;
            Object object = methodClass.newInstance();

            Constructor<?> constructor = methodClass.getConstructor(int.class,int.class);
            Object object1 = constructor.newInstance(1,2);
            System.err.println("newInstance() "+object.getClass());
            System.err.println("Constructor.newInstance() "+object1.getClass());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

class MethodClass {
    public int a = 4;
    private int b = 6;
    private int c = 5;
    public MethodClass(){
    }
    public MethodClass(int a, int b) {
        this(a, b, 0);
    }
    private MethodClass(int a, int b, int c) {
        this.a = a;
        this.b = b;
        this.c = c;
    }
}

运行结果：
newInstance() class MethodClass
Constructor.newInstance()  class MethodClass
```

### 调用Class对象方法

#### `invoke()`

> 传入方法名和参数，就可以调用到对应方法

```java
@CallerSensitive
@FastNative
public native Object invoke(Object obj, Object... args)
            throws IllegalAccessException, IllegalArgumentException, InvocationTargetException;
```

> `@FastNative`：Android 8.0新增加的注解，可以更快速的进行原生调用
>
> `@CallserSensitive`：跳过检查直接确定调用的对象

#### 实例分析

```java
public class reflect {
    public static void main(String[] args) {
        try {
            Class<?> methodClass = MethodClass.class;
            Object object = methodClass.newInstance();

            Method addMethod = methodClass.getDeclaredMethod("add", int.class, int.class);
            addMethod.setAccessible(true);
            addMethod.invoke(object,1,2);
          
            Method subMethod = methodClass.getMethod("sub", int.class, int.class);
            subMethod.invoke(object,2,1);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

class MethodClass {
    public MethodClass(){

    }
    private int add(int a, int b) {
        System.err.println("I`m reflect private method " + a+b);
        return a + b;
    }
    public int sub(int a,int b){
        System.err.println("I`m reflect public method" + a-b);
        return a - b;
    }
}

运行结果：
I`m reflect private method 3
I`m reflect public method 1
```

> 当通过`Method.invoke()`调用对应方法时，要求程序必须拥有调用该方法的权限。如果程序调用了private方法，就需要设置`setAccessible(boolean flag)`，设置`flag`为true则取消访问权限检查；false继续执行检查，则会报错`Class reflect can not access a member of class MethodClass with modifiers "private"`。

### 设置Class对象变量值

#### `Field.set()/Field.get()`

> 设置/获取任意变量值*Object*

```java
public native void set(Object obj, Object value) throws IllegalArgumentException, IllegalAccessException;

public native Object get(Object obj) throws IllegalArgumentException, IllegalAccessException;
```

#### `Field.setXX()/Field.getXX()`

> 设置/获取基本类型变量*int,boolean.long,double,float,char,short,byte8种基本类型*

```java
public native boolean getBoolean(Object obj) throws IllegalArgumentException, IllegalAccessException;
public native void setBoolean(Object obj, boolean z) throws IllegalArgumentException, IllegalAccessException;
```

| 基本类型 | 对应名称(位数)                                               |
| -------- | ------------------------------------------------------------ |
| 整数型   | byte(8位)，short(16位)，int(32位)，long(64位)                |
| 浮点型   | float(32位)，double(64位) 默认为double，要设置成float，需要结尾加f |
| 字节型   | char(16位)                                                   |
| 布尔型   | boolean(1位)                                                 |

实例分析

```java
public class reflect {
    public static void main(String[] args) {
        try {
            Class<?> methodClass = MethodClass.class;
            Object object = methodClass.newInstance();

            Field field = methodClass.getField("a");
            Field declaredField = methodClass.getDeclaredField("b");
            field.setAccessible(true);
            declaredField.setAccessible(true);
            field.set(object,3);
            declaredField.set(object,5);

            Method addMethod = methodClass.getDeclaredMethod("add", int.class, int.class);
            addMethod.setAccessible(true);
            addMethod.invoke(object,1,2);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

class MethodClass {
    public int a = 4;
    private int b = 6;
    private int c = 5;

    public MethodClass(){
    }
    public MethodClass(int a, int b) {
        this(a, b, 0);
    }
    private MethodClass(int a, int b, int c) {
        this.a = a;
        this.b = b;
        this.c = c;
    }

    private int add(int a, int b) {
        System.err.println("reflect value a="+ this.a+" b="+ this.b);
        return a + b;
    }

    public int sub(int a, int b) {
        return a - b;
    }
}

运行结果：
reflect value a=3 b=5
```

## Java反射机制的高级运用

### 反射创建数组

> 数组是一个比较特殊的类型，在反射机制中有专门的处理类——`java.lang.reflect.Array`
>
> `newInstance()`：创建一个数组对象
>
> `get()/getXX()`：获取数组中对应位置的值
>
> `set()/setXX()`：设置数组中对应位置的值

#### 实例分析

```java
public class GenerateArray {
    public static void main(String[] args){
        try {
            Class<?> clazz = Class.forName("java.lang.String");
            //创建一个 String型数组
            Object array = Array.newInstance(clazz,20);
            Array.set(array,0,"12");
            Array.set(array,1,"23");
            System.err.println(Array.get(array,1));
        }catch (Exception e){
            e.printStackTrace();
        }
    }
}

运行结果：
23
```



### 反射获取泛型

{% post_link Java-泛型 %}

反射只能对普通类型的Field有效，如果该Field的类型是有泛型限制的类型，例如`Map<String,String>`类型，则无法准备取得该Field的泛型参数。

#### `ParameterizedType`

代表被参数化的类型，增加了泛型限制的类型。

#### `getRawType()`

返回没有泛型信息的原始类型

#### `getActualTypeArguments()`

返回泛型参数的类型

#### 实例分析

```java
public class GenerateArray {
    //使用泛型类型的Map
    private Map<String, Integer> map = new HashMap<>();

    public static void main(String[] args) {
        try {
            Class<GenerateArray> clazz = GenerateArray.class;
            //反射获取Map变量
            Field f = clazz.getDeclaredField("map");
            //直接获取Field类型
            Class<?> mapClazz = f.getType();
            System.err.println(mapClazz);
            //获取Field的泛型类型
            Type type = f.getGenericType();
            //判断是否为泛型类型
            if (type instanceof ParameterizedType) {
                //强制类型转换
                ParameterizedType pType = (ParameterizedType) type;
                //获取原始类型 这里得到的是Map
                Type rType = pType.getRawType();
                System.err.println("原始类型 ：" + rType);
                //获取泛型类型的泛型参数
                Type[] types = pType.getActualTypeArguments();
                System.err.println("泛型类型 ：");
                for (int i = 0; i < types.length; i++) {
                    System.err.println(types[i]);
                }
            } else {
                System.err.println("无法获取泛型类型");
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

## 反射使用注意事项

由于反射会额外的消耗一定的系统资源，如果不需要动态的创建一个对象，那么就不需要用到反射。

另外反射调用方法时会忽略权限检查，因此可能会破坏封装性导致安全问题。



只有在 `初始化直接赋值且非new(eg: final String aa = "123")`不能被反射修改`final值`。

## 反射优化

反射慢的原因主要在两点：

- 虽然javac不怎么优化代码，但反射导致JIT编译器无法有效做优化，使得反射执行慢
- 反射方法的检测，需要检测`类、方法是否存在，权限是否正确`



优化点如下：

- `setAccessible(true)`避免反射时的检测
- 若大量执行反射，对反射对象的反射结果进行缓存，可以后续反射时直接调用缓存
- 使用三方反射库，例如`ReflactASM`通过添加字节码的方式实现反射功能。





## 参考链接

[Java反射效率低原因](https://juejin.cn/post/6844903965725818887#heading-18)