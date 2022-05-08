---
title: 自定义ViewGroup实践
date: 2019-01-02 14:21:44
tags: Android
top: 10
---

# 自定义ViewGrouop - FlowLayout

## 实现方式

- 继承特定ViewGroup，例如`LinearLayout`

  > 比较常见，效果类似于一堆View的组合。
  >
  > **实现比较简单，无需自己处理测量与布局的过程。**

- 继承`ViewGroup`派生特殊layout

  > 主要用于实现自定义的布局，按照自身需求制定不同的显示方法。
  >
  > **实现稍微复杂，还需要对ViewGroup进行处理，主要是自身的`onMeasure()、onLayout()`以及子View的`measure`过程**

## 注意事项

- 注意`wrap_content`的影响
- 注意`margin、pandding`的实现

## 实现步骤

### 创建ViewGroup

##### 继承ViewGroup

```java
public class FlowLayout extends ViewGroup {

    public FlowLayout(Context context) {
        this(context,null);
    }

    public FlowLayout(Context context, AttributeSet attrs) {
        super(context, attrs);
    }
}
```



#### 处理ViewGroup布局

##### 测量ViewGroup大小

通过`onMeasure()`进行ViewGroup的测量，其中需要先对子View进行测量，然后根据子View的结果确认最终ViewGroup的大小。

```java

```



##### 确定ViewGroup位置

