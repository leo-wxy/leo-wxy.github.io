---
title: Android Study Plan V
date: 2018-03-18 17:48:03
tags: Android
---
# Android学习计划
话题：关于View的知识

1、View的getWidth()和getMeasuredWidth()有什么区别吗？
2、如何在onCreate中拿到View的宽度和高度？

# 答案
## 1. View的getWidth()和getMeasuredWidth()有什么区别吗？
- `getWidth()`通过`setFrame`方法来决定四个顶点位置，初始化`mLeft,mTop,mRight,mBottom`四个参数，这四个值固定则位置确定。必须在layout过程结束才有值。
```java
 /**
     * Return the width of the your view.
     *
     * @return The width of your view, in pixels.
     * 利用屏幕上的右坐标减去左边的坐标 
     */
    @ViewDebug.ExportedProperty(category = "layout")
    public final int getWidth() {
        return mRight - mLeft;
    }
 
   protected boolean setFrame(int left, int top, int right, int bottom) {
 ...
            mLeft = left;
            mTop = top;
            mRight = right;
            mBottom = bottom;
...
  }
```

- `getMeasuredWidth`是在view的绘制流程中的`measure`结束后有值，获取的是view的测量宽高。`mMeasuredWidth `是在`setMeasuredDimensionRaw `方法中赋值的
```java
public static final int MEASURED\_SIZE\_MASK = 0x00ffffff;  
/**
     * Like {@link #getMeasuredWidthAndState()}, but only returns the
     * raw width component (that is the result is masked by
     * {@link #MEASURED_SIZE_MASK}).
     *
     * @return The raw measured width of this view.
     */
    public final int getMeasuredWidth() {
        return mMeasuredWidth & MEASURED_SIZE_MASK;//与任何数字的运算得到的结果是mMeasuredWidth
    }
 
private void setMeasuredDimensionRaw(int measuredWidth, measuredHeight) {
        mMeasuredWidth = measuredWidth;
        mMeasuredHeight = measuredHeight;
 
        mPrivateFlags |= PFLAG_MEASURED_DIMENSION_SET;
    }
```

- 一般情况下 `getMeasuredWidth `和`getWidth`的值是相同的，从源码中可以看出`setMeasuredDimensionRaw `会对`mMeasuredWidth `进行赋值，当调用了`onMeasure`，会调用到`setMeasuredDimensionRaw `则获取的结果将会不相同
```java
public final void measure(int widthMeasureSpec, int heightMeasureSpec) {
  boolean optical = isLayoutModeOptical(this);
	if (optical != isLayoutModeOptical(mParent)) {
		Insets insets = getOpticalInsets();
	   int oWidth  = insets.left + insets.right;
		int oHeight = insets.top  + insets.bottom;
		widthMeasureSpec  = MeasureSpec.adjust(widthMeasureSpec,  optical ? -oWidth  : oWidth);
		heightMeasureSpec = MeasureSpec.adjust(heightMeasureSpec, optical ? -oHeight : oHeight);
	}
 ...
  if (forceLayout || needsLayout) {
		// first clears the measured dimension flag
		mPrivateFlags &= ~PFLAG_MEASURED_DIMENSION_SET;

	   resolveRtlPropertiesIfNeeded();

		int cacheIndex = forceLayout ? -1 : mMeasureCache.indexOfKey(key);
		if (cacheIndex < 0 || sIgnoreMeasureCache) {
			// measure ourselves, this should set the measured dimension flag back
			onMeasure(widthMeasureSpec, heightMeasureSpec);
		   mPrivateFlags3 &= ~PFLAG3_MEASURE_NEEDED_BEFORE_LAYOUT;
		} else {
			long value = mMeasureCache.valueAt(cacheIndex);
			// Casting a long to int drops the high 32 bits, no mask needed
		   setMeasuredDimensionRaw((int) (value >> 32), (int) value);
			mPrivateFlags3 |= PFLAG3_MEASURE_NEEDED_BEFORE_LAYOUT;
		}

		// flag not set, setMeasuredDimension() was not invoked, we raise
		// an exception to warn the developer
		if ((mPrivateFlags & PFLAG_MEASURED_DIMENSION_SET) != PFLAG_MEASURED_DIMENSION_SET) {
			throw new IllegalStateException("View with id " + getId() + ": "
				   + getClass().getName() + "#onMeasure() did not set the"
					+ " measured dimension by calling"
					+ " setMeasuredDimension()");
		}

		mPrivateFlags |= PFLAG_LAYOUT_REQUIRED;
  }
  ...
  }
  ```

- view的绘制流程`measure` `layout` `draw`
  {% fullimage /images/study_plan/view_process.png, alt,流程图 %}
  - `measure`为了计算出控件树中的各个控件要显示的内容以及大小，起点为`ViewRootImpl 的 measureHierarchy ()`。
	-  SpecMode : `EXACTLY(确切大小)` `AT_MOST(子view的大小不得超过SpecSize)` `UNSPECIFIED(对子view尺寸不做限制)`
		```java
		/**
		         * Measure specification mode: The parent has not imposed any constraint
		         * on the child. It can be whatever size it wants.
		         */
		        public static final int UNSPECIFIED = 0 << MODE_SHIFT;

		        /**
		         * Measure specification mode: The parent has determined an exact size
		         * for the child. The child is going to be given those bounds regardless
		         * of how big it wants to be.
		         */
		        public static final int EXACTLY     = 1 << MODE_SHIFT;

		        /**
		         * Measure specification mode: The child can be as large as it wants up
		         * to the specified size.
		         */
		        public static final int AT_MOST     = 2 << MODE_SHIFT;
		```
- `layout` 从根view开始，递归的完成控件树的布局工作，确定view的位置。先递归的对子view进行布局，在完成父布局的位置设置

  -  `draw` 从根view开始进行绘制，利用`Viwe.draw()`


## 2.如何在onCreate中拿到View的宽度和高度？
- 在 Activity#onWindowFocusChanged 回调中获取宽高。

- view.post(runnable)，在 runnable 中获取宽高。
	`利用Handler通信机制，发送一个Runnable在MessageQuene中，当layout处理结束时则会发送一个消息通知UI线程，可以获取到实际宽高。`
- ViewTreeObserver 添加 OnGlobalLayoutListener，在 onGlobalLayout 回调中获取宽高。
	`监听全局View的变化事件，使用后需要注意移除OnGlobalLayoutListener 监听，以免造成内存泄露`
- 调用 view.measure()，再通过 getMeasuredWidth 和 getMeasuredHeight 获取宽高。

## 补充知识点
- matchParent无法measure(在view的measure过程中，需要知道parentSize即父容器的剩余空间，所以无法得出measure的大小)
- [深入理解View绘制流程][1]

[1]:	https://www.cnblogs.com/jycboy/p/6219915.html#autoid-7-1-0