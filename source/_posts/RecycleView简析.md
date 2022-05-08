---
title: RecyclerView简析
date: 2018-12-20 11:49:27
tags: Android
top: 10
---
{% fullimage /images/RecyclerView机制.png,RecyclerView机制,RecyclerView机制%}
## RecyclerView定义

> RecyclerView是一个新的组件，用来代替ListView组件的。

相比于ListView来说，RecyclerView的最大一个特性就是**灵活性**，主要体现在以下几个方面：

- `多样式`：可以对数据展示进行定制，可以显示成列表，表格或者是瀑布流，你还可以自定义成任何显示样式。
- `局部刷新`：可以刷新指定的Item或者区域
- `刷新动画`：支持对Item的添加和移除添加动画
- `添加装饰`：支持自定义Item之间的分割线效果

相比ListView还有其他的优点：

- 默认实现View的复用，不需要判断`if(convertView == null)`的实现，回收机制更加完善。
- 容易实现拖拽，侧滑删除等效果。(利用`ItemTouchHelper`)

RecyclerView是一个插件式的实现，对各个功能进行解耦，从而扩展性比较好。

## RecyclerView用法

RecyclerView的标准实现流程如下：

- 创建Adapter：

  ```java
  public class DemoAdapter extends RecyclerView.Adapter<DemoAdapter.VH> {
  ...
  }
  ```

  创建一个继承`RecyclerView.Adapter`的Adapter类

- 创建ViewHolder：

  ```java
      static class VH extends RecyclerView.ViewHolder {
          final TextView title;
  
          VH(@NonNull View itemView) {
              super(itemView);
              title = itemView.findViewById(R.id.title);
          }
      }
  ```

  创建一个继承`RecyclerView.ViewHolder`的静态内部类，记为`VH`。内部实现类似`ListView的ViewHolder`。

- 完善以下方法：

  - `VH onCreateViewHolder(ViewGroup parent,int viewType)`：绑定对应的layout id并创建`VH`返回

    ```java
        public DemoAdapter.VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_demo, parent, false);
            return new VH(view);
        }
    ```

  - `void onBindViewHolder(VH holder,int position)`：为`VH`设置事件以及数据

    ```java
        public void onBindViewHolder(@NonNull VH holder, int position) {
            holder.title.setText(mData.get(position));
            holder.itemView.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    //设置item点击事件
                }
            });
        }
    ```

  - `int getItemCount()`：返回item个数

    ```java
    	  public int getItemCount() {
            return mData.size();
        }
    ```

    

Adapter创建完成后，需要把Adapter设置到RecyclerView上。一般来说需要为RecyclerView进行四大设置：

- **设置Adapter(必须设置)**：给RecyclerView绑定数据源 
- **设置LayoutManager(必须设置)**：给RecyclerView设置显示样式
- **设置Item Decoration(可以设置)**：给RecyclerView设置Item间的分割线
- **设置Item Animator(可以设置)**：给RecyclerView设置Item的添加和删除动画

设置实例：

```java
List<String> data = new ArrayList<>();

RecyclerView rv_demo = (RecyclerView)findViewById(R.id.rv_demo);
rv_demo.setAdapter(new DemoAdapter(data));
rv_demo.setLayoutManager(new LinearLayoutManager(this));//默认竖向显示
```

更新数据：

```java
rv_demo.notifyDataSetChanged();//更新整个视图
//更新局部视图
rv_demo.notifyitemInserted();
rv_demo.notifyItemRemoved();
rv_demo.notifyitemChanged();
```

## RecyclerView源码解析

> RecyclerView的四大组成部分：**Adapter、LayoutManager、ItemAnimator，ItemDecoration**。

### Adapter

> 主要为了给RecyclerView提供数据，将Data与View进行绑定。创建ViewHolder以及数据变化时通知到RecyclerView。通知RecyclerView使用的是*观察者模式*。

在`setAdapter()`时，就会给Adapter注册一个观察者，去通知RecyclerView数据变化

```java
    public void setAdapter(Adapter adapter) {
        // bail out if layout is frozen
        setLayoutFrozen(false);
        setAdapterInternal(adapter, false, true);
        requestLayout();
    }

    private void setAdapterInternal(Adapter adapter, boolean compatibleWithPrevious,
            boolean removeAndRecycleViews) {
        ...
        if (adapter != null) {
            //注册观察者
            adapter.registerAdapterDataObserver(mObserver);
            adapter.onAttachedToRecyclerView(this);
        }
        ...
    }
```

<br>

### LayoutManager

> 负责RecyclerView的布局，其中包含了Item View的获取与回收。后面会分析它的缓存机制。

还是按照绘制流程来看，LayoutManager在RecyclerView中是如何使用的？

> Measure流程

```java
LayoutManager mLayout;   
@Override
    protected void onMeasure(int widthSpec, int heightSpec) {
      if (mLayout.mAutoMeasure) {
            final int widthMode = MeasureSpec.getMode(widthSpec);
            final int heightMode = MeasureSpec.getMode(heightSpec);
            final boolean skipMeasure = widthMode == MeasureSpec.EXACTLY
                    && heightMode == MeasureSpec.EXACTLY;
            mLayout.onMeasure(mRecycler, mState, widthSpec, heightSpec);
       ... 
      }
      ...
    }
```

在`RecyclerView.onMeasure()`中调用到了`LayoutManager.onMeasure()`，然后其中执行到了`RecyclerView.defaultOnMeasure()`

```java
    void defaultOnMeasure(int widthSpec, int heightSpec) {
        // calling LayoutManager here is not pretty but that API is already public and it is better
        // than creating another method since this is internal.
        final int width = LayoutManager.chooseSize(widthSpec,
                getPaddingLeft() + getPaddingRight(),
                getMinimumWidth());
        final int height = LayoutManager.chooseSize(heightSpec,
                getPaddingTop() + getPaddingBottom(),
                getMinimumHeight());

        setMeasuredDimension(width, height);
    }

// LayoutManager.java
        public static int chooseSize(int spec, int desired, int min) {
            final int mode = View.MeasureSpec.getMode(spec);
            final int size = View.MeasureSpec.getSize(spec);
            switch (mode) {
                case View.MeasureSpec.EXACTLY:
                    return size;
                case View.MeasureSpec.AT_MOST:
                    return Math.min(size, Math.max(desired, min));
                case View.MeasureSpec.UNSPECIFIED:
                default:
                    return Math.max(desired, min);
            }
        }
```

最终RecyclerView的`Measure流程`依赖`LayoutManager.chooseSize()`来确定最后的RecyclerView宽高。

> Layout流程

```java
    @Override
    protected void onLayout(boolean changed, int l, int t, int r, int b) {
        Trace.beginSection(TRACE_ON_LAYOUT_TAG);
        dispatchLayout();
        Trace.endSection();
        mFirstLayoutComplete = true;
    }

    void dispatchLayout() {
       ...
        mState.mIsMeasuring = false;
        //第一次开始布局
        if (mState.mLayoutStep == State.STEP_START) {
            //存储ziView状态并确定是否要执行动画
            dispatchLayoutStep1();
            mLayout.setExactMeasureSpecsFrom(this);
            dispatchLayoutStep2();
          //发生了数据变化(notifyDataSetChanges)或者布局变化
        } else if (mAdapterHelper.hasUpdates() || mLayout.getWidth() != getWidth()
                || mLayout.getHeight() != getHeight()) {
            // First 2 steps are done in onMeasure but looks like we have to run again due to
            // changed size.
            mLayout.setExactMeasureSpecsFrom(this);
            //Item布局过程
            dispatchLayoutStep2();
        } else {
            // always make sure we sync them (to ensure mode is exact)
            mLayout.setExactMeasureSpecsFrom(this);
        }
        //执行Item 动画
        dispatchLayoutStep3();
    }
```

观察上述源码发现，涉及布局过程的只有`dispatchLayoutStep2()`，从这个方法继续向下看

```java
    private void dispatchLayoutStep2() {
        ...
        // Step 2: Run layout
        mState.mInPreLayout = false;
        mLayout.onLayoutChildren(mRecycler, mState);
        ...
    }
```

这里涉及到了`LayoutManager.onLayoutChildren()`，由于默认是空实现，我们就拿`LinearLayoutManager`这个子类继续分析

```java
// LinearLayoutManager.java
    @Override
    public void onLayoutChildren(RecyclerView.Recycler recycler, RecyclerView.State state) {
     ...
        int startOffset;
        int endOffset;
        final int firstLayoutDirection;
        if (mAnchorInfo.mLayoutFromEnd) {
            firstLayoutDirection = mShouldReverseLayout ? LayoutState.ITEM_DIRECTION_TAIL
                    : LayoutState.ITEM_DIRECTION_HEAD;
        } else {
            firstLayoutDirection = mShouldReverseLayout ? LayoutState.ITEM_DIRECTION_HEAD
                    : LayoutState.ITEM_DIRECTION_TAIL;
        }

        onAnchorReady(recycler, state, mAnchorInfo, firstLayoutDirection);
        detachAndScrapAttachedViews(recycler);
        mLayoutState.mInfinite = resolveIsInfinite();
        mLayoutState.mIsPreLayout = state.isPreLayout();
        //是否从底部布局
        if (mAnchorInfo.mLayoutFromEnd) {  
           // 向上布局
            updateLayoutStateToFillStart(mAnchorInfo);
            mLayoutState.mExtra = extraForStart;
            //填充item
            fill(recycler, mLayoutState, state, false);
            startOffset = mLayoutState.mOffset;
            final int firstElement = mLayoutState.mCurrentPosition;
            if (mLayoutState.mAvailable > 0) {
                extraForEnd += mLayoutState.mAvailable;
            }
            //向下布局
            updateLayoutStateToFillEnd(mAnchorInfo);
            mLayoutState.mExtra = extraForEnd;
            mLayoutState.mCurrentPosition += mLayoutState.mItemDirection;
            fill(recycler, mLayoutState, state, false);
            endOffset = mLayoutState.mOffset;

            if (mLayoutState.mAvailable > 0) {
                // end could not consume all. add more items towards start
                extraForStart = mLayoutState.mAvailable;
                updateLayoutStateToFillStart(firstElement, startOffset);
                mLayoutState.mExtra = extraForStart;
                fill(recycler, mLayoutState, state, false);
                startOffset = mLayoutState.mOffset;
            }
        }else{
          ...
          
        }
      ...
    }
```

确定布局方向后，就需要填充子View，利用`fill()`实现。

```java
    int fill(RecyclerView.Recycler recycler, LayoutState layoutState,
            RecyclerView.State state, boolean stopOnFocusable) {
       //存储当前可用空间
       final int start = layoutState.mAvailable;
       ...
        //计算可用布局宽高
        int remainingSpace = layoutState.mAvailable + layoutState.mExtra;
        LayoutChunkResult layoutChunkResult = mLayoutChunkResult;
       //迭代填充Item
        while ((layoutState.mInfinite || remainingSpace > 0) && layoutState.hasMore(state)) {
            layoutChunkResult.resetInternal();
            //布局item
            layoutChunk(recycler, state, layoutState, layoutChunkResult);
            if (layoutChunkResult.mFinished) {
                break;
            }
          layoutState.mOffset += layoutChunkResult.mConsumed * layoutState.mLayoutDirection;
           //子View的回收工作
        }
      ...
    }
```

在`fill()`中循环调用`layoutChunk()`进行布局。每次布局完成后需要计算剩余空间，之后判断是否需要继续布局Item。

向下看Item的布局方法`layoutChunk()`

```java
void layoutChunk(RecyclerView.Recycler recycler, RecyclerView.State state,
		LayoutState layoutState, LayoutChunkResult result) {
	// 获取item view
	View view = layoutState.next(recycler);
	// 获取布局参数
	LayoutParams params = (LayoutParams) view.getLayoutParams();
	if (layoutState.mScrapList == null) {
		if (mShouldReverseLayout == (layoutState.mLayoutDirection== LayoutState.LAYOUT_START)) {
			// 增加item view
			addView(view);
		} else {
			addView(view, 0);
		}
	} 
	// 测量item
	measureChildWithMargins(view, 0, 0);
	// 计算item使用的空间
	result.mConsumed = mOrientationHelper.getDecoratedMeasurement(view);
	int left, top, right, bottom;
	// 竖直方向布局，计算Item坐标
	if (mOrientation == VERTICAL) {
    //设置了从右向左的布局方式
		if (isLayoutRTL()) {
			right = getWidth() - getPaddingRight();
			left = right - mOrientationHelper.getDecoratedMeasurementInOther(view);
		} else {
			left = getPaddingLeft();
			right = left + mOrientationHelper.getDecoratedMeasurementInOther(view);
		}
		if (layoutState.mLayoutDirection == LayoutState.LAYOUT_START) {
			bottom = layoutState.mOffset;
			top = layoutState.mOffset - result.mConsumed;
		} else {
			top = layoutState.mOffset;
			bottom = layoutState.mOffset + result.mConsumed;
		}   
	} 
  //水平方向布局，计算Item坐标
  else {
     top = getPaddingTop();
     bottom = top + mOrientationHelper.getDecoratedMeasurementInOther(view);

     if (layoutState.mLayoutDirection == LayoutState.LAYOUT_START) {
          right = layoutState.mOffset;
          left = layoutState.mOffset - result.mConsumed;
     } else {
          left = layoutState.mOffset;
          right = layoutState.mOffset + result.mConsumed;
     }	   
	}
  	// item布局
	layoutDecoratedWithMargins(view, left, top, right, bottom);
  ...
}

//测量子View的布局
        public void measureChildWithMargins(View child, int widthUsed, int heightUsed) {
            final LayoutParams lp = (LayoutParams) child.getLayoutParams();

            final Rect insets = mRecyclerView.getItemDecorInsetsForChild(child);
            widthUsed += insets.left + insets.right;
            heightUsed += insets.top + insets.bottom;

            final int widthSpec = getChildMeasureSpec(getWidth(), getWidthMode(),
                    getPaddingLeft() + getPaddingRight()
                            + lp.leftMargin + lp.rightMargin + widthUsed, lp.width,
                    canScrollHorizontally());
            final int heightSpec = getChildMeasureSpec(getHeight(), getHeightMode(),
                    getPaddingTop() + getPaddingBottom()
                            + lp.topMargin + lp.bottomMargin + heightUsed, lp.height,
                    canScrollVertically());
            if (shouldMeasureChild(child, widthSpec, heightSpec, lp)) {
               //子View测量
                child.measure(widthSpec, heightSpec);
            }
        }

        public void layoutDecoratedWithMargins(View child, int left, int top, int right,
                int bottom) {
            final LayoutParams lp = (LayoutParams) child.getLayoutParams();
            final Rect insets = lp.mDecorInsets;
            //子view布局
            child.layout(left + insets.left + lp.leftMargin, top + insets.top + lp.topMargin,
                    right - insets.right - lp.rightMargin,
                    bottom - insets.bottom - lp.bottomMargin);
        }
```

在`layoutChunk()`中完成了子View的`measure以及layout`过程。

> Draw过程

Draw过程就是下文描述到的`ItemDecoration`，主要完成的就是绘制分割线的过程。

<br>

### ItemAnimator

> RecyclerView能够通过`RecyclerView.setItemAnimator(ItemAnimator animator)`设置添加、删除、移动、改变的动画效果。提供了默认的动画效果`DefaultItemAnimator`。

```java
class CustomItemAnimator : RecyclerView.ItemAnimator(){

  override fun isRunning(): Boolean {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }
    
    override fun animatePersistence(
        viewHolder: RecyclerView.ViewHolder,
        preLayoutInfo: ItemHolderInfo,
        postLayoutInfo: ItemHolderInfo
    ): Boolean {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun runPendingAnimations() {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun endAnimation(item: RecyclerView.ViewHolder) {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun animateDisappearance(
        viewHolder: RecyclerView.ViewHolder,
        preLayoutInfo: ItemHolderInfo,
        postLayoutInfo: ItemHolderInfo?
    ): Boolean {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun animateChange(
        oldHolder: RecyclerView.ViewHolder,
        newHolder: RecyclerView.ViewHolder,
        preLayoutInfo: ItemHolderInfo,
        postLayoutInfo: ItemHolderInfo
    ): Boolean {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun animateAppearance(
        viewHolder: RecyclerView.ViewHolder,
        preLayoutInfo: ItemHolderInfo?,
        postLayoutInfo: ItemHolderInfo
    ): Boolean {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun endAnimations() {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

}
```

- `animateAppearance()`：当ViewHolder出现在屏幕上时被调用(*可能是add或move*)
- `animateDisappearance()`：当ViewHolder消失在屏幕上时被调用(*可能是remove或move*)
- `animatePersistence()`：在没调用`notifyItemChanged()`和`notifyDataSetChanged()`的情况下发生布局改变时被调用
- `animateChange()`：在调用`notifyItemChanged()`或`notifyDataSetChanged()`的情况下发生布局改变时被调用
- `runPendingAnimations()`：RecyclerView的执行方式是每帧执行一次，如果在帧之间添加了多个Item，就会保存Pending动画，等到下一帧一起执行。**前面定义的`animateXXX()`返回true。**
- `isRunning()`：是否有动画要执行或正在执行
- `dispatchAnimationsFinished()`：当全部动画执行完毕时调用

> 对于`ItemAnimator`，最常见的是*闪屏问题* ——当Item中存在图片和文字时，刷新RecyclerView时会出现闪烁问题。
>
> 出现原因是由于调用`notifyDataSetChanged()`，会调用到`DefaultAnimator.animateChangeImpl()`执行change动画，导致透明度发生0-1的变化，发生闪烁。
>
> 解决方法：在`setAdapter()`之前调用`((SimpleItemAnimator)rv.getItemAnimator()).setSupportsChangeAnimations(false)`禁用change动画。

<br>

### ItemDecoration

> RecyclerView通过`addItemDecoration()`添加Item之间的分割线。

如果我们要自己实现一个分割线效果，需要自己创建一个类并继承`RecyclerView.ItemDecoration`，重写一下两个方法：

- `onDraw()`：绘制分割线
- `getItemOffsets()`：设置分割线的宽高

```java
 class CustomDecoration : RecyclerView.ItemDecoration() {
     override fun onDraw(c: Canvas, parent: RecyclerView, state: RecyclerView.State) {
         //调用在Item绘制完毕前，绘制分割线
     }

     override fun getItemOffsets(outRect: Rect, view: View, parent: RecyclerView, state: RecyclerView.State) {
         //定义分割线的宽/高，在不同的显示模式下
     }

     override fun onDrawOver(c: Canvas, parent: RecyclerView, state: RecyclerView.State) {
        //调用在Item绘制完毕后，绘制分割线
     }
 }
```

接下来分析RecyclerView是如何调用到分割线？

回顾View的绘制流程是*measure->layout->draw*，我们开始分析分割线的调用流程。

由于RecyclerView继承自`ViewGroup`，分割线是作为Item之间的间隔使用，那就要从`measureChild()`开始查看

```java
        public void measureChild(View child, int widthUsed, int heightUsed) {
            final LayoutParams lp = (LayoutParams) child.getLayoutParams();
            //获取设置的分割线
            final Rect insets = mRecyclerView.getItemDecorInsetsForChild(child);
            widthUsed += insets.left + insets.right;
            heightUsed += insets.top + insets.bottom;
            //都需要在原基础上 加上分割线的宽/高
            final int widthSpec = getChildMeasureSpec(getWidth(), getWidthMode(),
                    getPaddingLeft() + getPaddingRight() + widthUsed, lp.width,
                    canScrollHorizontally());
            final int heightSpec = getChildMeasureSpec(getHeight(), getHeightMode(),
                    getPaddingTop() + getPaddingBottom() + heightUsed, lp.height,
                    canScrollVertically()); 
            if (shouldMeasureChild(child, widthSpec, heightSpec, lp)) {
                child.measure(widthSpec, heightSpec);
            }
        }

 Rect getItemDecorInsetsForChild(View child) {
        ...
            //调用到设置的 getItemOffsets()
            mItemDecorations.get(i).getItemOffsets(mTempRect, child, this, mState);
        ...
    }
```

在`measureChild()`找到了引用分割线并设置宽高的地方，接下啦需要找到引用绘制(`onDraw`)的地方

```java
    @Override
    public void onDraw(Canvas c) {
        //调用到父类的 onDraw 即 View.onDraw
        super.onDraw(c);

        final int count = mItemDecorations.size();
        for (int i = 0; i < count; i++) {
            mItemDecorations.get(i).onDraw(c, this, mState);
        }
    }

    @Override
    public void draw(Canvas c) {
        //调用到父类的 draw() 即  View.draw()
        super.draw(c);

        final int count = mItemDecorations.size();
        for (int i = 0; i < count; i++) {
            mItemDecorations.get(i).onDrawOver(c, this, mState);
        }
      ...
    }

// View.java
 public void draw(Canvas canvas) {
  ...
    if (!dirtyOpaque) onDraw(canvas);
  ...
 }
```

上面找到了两个引用了`ItemDecoration`的绘制方法。这里回顾一下`ViewGroup`的Draw流程，先调用自身的`draw()`，然后`drawBackground()`，向下到`onDraw()`，绘制子View`disaptchDraw()`。

根据Draw流程分析，先调用到`RecyclerView.draw()`，发现调用到了`super.draw()`即指向了`View.draw()`这时View调用到自身的`onDraw()`，而RecyclerView重写了该方法，就调用到了`ItemDecoration.onDraw()`，然后走向`dispatchDraw()`绘制子View。绘制完毕后，最后调用到了`ItemDecoration.onDrawOver()`。

综上所述：**`onDraw()`调用在子View绘制前，`onDrawOver()`在绘制之后执行**。

<br>

### 缓存机制

> RecyclerView是以`RecyclerView.ViewHolder`作为单位进行回收。Recycler是RecyclerView回收机制的实现类。

Recycler实现的是**四级缓存**：

- `mAttachedScrap`：缓存已在屏幕上的ViewHolder。   *一级缓存*
- `mCacheViews`：缓存屏幕外的ViewHolder，默认为2个。  *一级缓存*
- `mViewCacheExtension`：需要用户定制，默认不实现。  *二级缓存*
- `mRecyclerPool`：缓存池，`mCacheViews`集合中装满时，会放到这里。技术上可以实现所有`RecyclerViewPool`共用。默认为5个。 *三级缓存*
- `createViewHolder`：创建ViewHolder。*‌四级缓存*

缓存机制主要分为两段流程：**复用机制和回收机制。**

#### 复用机制

>  从`Recycler`获取一个`ViewHolder`

`LayoutManager`通过调用`Recycler.getViewForPosition(pos)`获取`pos`位置上的`view`。

```java
        public View getViewForPosition(int position) {
            return getViewForPosition(position, false);
        }

        View getViewForPosition(int position, boolean dryRun) {
            return tryGetViewHolderForPositionByDeadline(position, dryRun, FOREVER_NS).itemView;
        }
        //复用机制的主要方实现
				ViewHolder tryGetViewHolderForPositionByDeadline(int position,
                boolean dryRun, long deadlineNs) {
            //判断位置是否正常
            if (position < 0 || position >= mState.getItemCount()) {
                throw new IndexOutOfBoundsException("Invalid item position " + position
                        + "(" + position + "). Item count:" + mState.getItemCount());
            }
            boolean fromScrapOrHiddenOrCache = false;
            ViewHolder holder = null;
            // 是否设置动画
            if (mState.isPreLayout()) {
                holder = getChangedScrapViewForPosition(position);
                fromScrapOrHiddenOrCache = holder != null;
            }

            if (holder == null) {
                //从 mAttcherScrap 或者 mCachedViews 获取holder
                holder = getScrapOrHiddenOrCachedHolderForPosition(position, dryRun);①
                if (holder != null) {
                    //判定ViewHolder是否有效
                    if (!validateViewHolderForOffsetPosition(holder)) {②
                        // recycle holder (and unscrap if relevant) since it can't be used
                        if (!dryRun) {
                            //设置回收标记
                            holder.addFlags(ViewHolder.FLAG_INVALID);
                            if (holder.isScrap()) {
                                removeDetachedView(holder.itemView, false);
                                holder.unScrap();
                            } else if (holder.wasReturnedFromScrap()) {
                                holder.clearReturnedFromScrapFlag();
                            }
                            recycleViewHolderInternal(holder);
                        }
                        holder = null;
                    } else {
                        fromScrapOrHiddenOrCache = true;
                    }
                }
            }
            
            if (holder == null) {
                final int offsetPosition = mAdapterHelper.findPositionOffset(position);
                if (offsetPosition < 0 || offsetPosition >= mAdapter.getItemCount()) {
                    throw new IndexOutOfBoundsException("Inconsistency detected. Invalid item "
                            + "position " + position + "(offset:" + offsetPosition + ")."
                            + "state:" + mState.getItemCount());
                }
                //获取item设置的type
                final int type = mAdapter.getItemViewType(offsetPosition);
                // stable id 就是标识一个viewholder的唯一性
                if (mAdapter.hasStableIds()) {
                    holder = getScrapOrCachedViewForId(mAdapter.getItemId(offsetPosition),③
                            type, dryRun);
                    if (holder != null) {
                        // update position
                        holder.mPosition = offsetPosition;
                        fromScrapOrHiddenOrCache = true;
                    }
                }
                //从用户自己设置的 mViewCacheExtension 去寻找对应ViewHolder·
                if (holder == null && mViewCacheExtension != null) {
                    // We are NOT sending the offsetPosition because LayoutManager does not
                    // know it.
                    final View view = mViewCacheExtension
                            .getViewForPositionAndType(this, position, type);
                    if (view != null) {
                        //包装成一个ViewHolder
                        holder = getChildViewHolder(view);
                        if (holder == null) {
                            throw new IllegalArgumentException("getViewForPositionAndType returned"
                                    + " a view which does not have a ViewHolder");
                        } else if (holder.shouldIgnore()) {
                            throw new IllegalArgumentException("getViewForPositionAndType returned"
                                    + " a view that is ignored. You must call stopIgnoring before"
                                    + " returning this view.");
                        }
                    }
                }
                //从 RecyclerViewPool去寻找对应的ViewHolder
                if (holder == null) { // fallback to pool
                    if (DEBUG) {
                        Log.d(TAG, "tryGetViewHolderForPositionByDeadline("
                                + position + ") fetching from shared pool");
                    }
                    holder = getRecycledViewPool().getRecycledView(type);④
                    if (holder != null) {
                        holder.resetInternal();⑤
                        if (FORCE_INVALIDATE_DISPLAY_LIST) {
                            invalidateDisplayListInt(holder);
                        }
                    }
                }
                //从以上三级缓存中都没有找到对应的ViewHolder就只能自己创建了
                if (holder == null) {
                    long start = getNanoTime();
                    if (deadlineNs != FOREVER_NS
                            && !mRecyclerPool.willCreateInTime(type, start, deadlineNs)) {
                        // abort - we have a deadline we can't meet
                        return null;
                    }
                    //创建对应的ViewHolder
                    holder = mAdapter.createViewHolder(RecyclerView.this, type);
                    if (ALLOW_THREAD_GAP_WORK) {
                        // only bother finding nested RV if prefetching
                        RecyclerView innerView = findNestedRecyclerView(holder.itemView);
                        if (innerView != null) {
                            holder.mNestedRecyclerView = new WeakReference<>(innerView);
                        }
                    }

                    long end = getNanoTime();
                    mRecyclerPool.factorInCreateTime(type, end - start);
                    if (DEBUG) {
                        Log.d(TAG, "tryGetViewHolderForPositionByDeadline created new ViewHolder");
                    }
                }
            }

            // This is very ugly but the only place we can grab this information
            // before the View is rebound and returned to the LayoutManager for post layout ops.
            // We don't need this in pre-layout since the VH is not updated by the LM.
            if (fromScrapOrHiddenOrCache && !mState.isPreLayout() && holder
                    .hasAnyOfTheFlags(ViewHolder.FLAG_BOUNCED_FROM_HIDDEN_LIST)) {
                holder.setFlags(0, ViewHolder.FLAG_BOUNCED_FROM_HIDDEN_LIST);
                if (mState.mRunSimpleAnimations) {
                    int changeFlags = ItemAnimator
                            .buildAdapterChangeFlagsForAnimations(holder);
                    changeFlags |= ItemAnimator.FLAG_APPEARED_IN_PRE_LAYOUT;
                    final ItemHolderInfo info = mItemAnimator.recordPreLayoutInformation(mState,
                            holder, changeFlags, holder.getUnmodifiedPayloads());
                    recordAnimationInfoIfBouncedHiddenView(holder, info);
                }
            }

            boolean bound = false;
            if (mState.isPreLayout() && holder.isBound()) {
                // do not update unless we absolutely have to.
                holder.mPreLayoutPosition = position;
            } else if (!holder.isBound() || holder.needsUpdate() || holder.isInvalid()) {
                if (DEBUG && holder.isRemoved()) {
                    throw new IllegalStateException("Removed holder should be bound and it should"
                            + " come here only in pre-layout. Holder: " + holder);
                }
                final int offsetPosition = mAdapterHelper.findPositionOffset(position);
                bound = tryBindViewHolderByDeadline(holder, offsetPosition, position, deadlineNs);
            }
            //设置对应ViewHolder的 layoutparams
            final ViewGroup.LayoutParams lp = holder.itemView.getLayoutParams();
            final LayoutParams rvLayoutParams;
            if (lp == null) {
                rvLayoutParams = (LayoutParams) generateDefaultLayoutParams();
                holder.itemView.setLayoutParams(rvLayoutParams);
            } else if (!checkLayoutParams(lp)) {
                rvLayoutParams = (LayoutParams) generateLayoutParams(lp);
                holder.itemView.setLayoutParams(rvLayoutParams);
            } else {
                rvLayoutParams = (LayoutParams) lp;
            }
            rvLayoutParams.mViewHolder = holder;
            rvLayoutParams.mPendingInvalidate = fromScrapOrHiddenOrCache && bound;
            return holder;
        }
```

①`getScrapOrHiddenOrCachedHolderForPosition()`：从`mAttchedScrap`或者`mCachedViews`去获取ViewHolder

```java
 ViewHolder getScrapOrHiddenOrCachedHolderForPosition(int position, boolean dryRun) {  
   //先从 mAttachedScrap 获取对应的ViewHolder
   for (int i = 0; i < scrapCount; i++) {
                final ViewHolder holder = mAttachedScrap.get(i);
                if (!holder.wasReturnedFromScrap() && holder.getLayoutPosition() == position
                        && !holder.isInvalid() && (mState.mInPreLayout || !holder.isRemoved())) {
                    holder.addFlags(ViewHolder.FLAG_RETURNED_FROM_SCRAP);
                    return holder;
                }
            }
    //从隐藏的View中去寻找ViewHolder
    if (!dryRun) {
                View view = mChildHelper.findHiddenNonRemovedView(position);
                if (view != null) {
                    // This View is good to be used. We just need to unhide, detach and move to the
                    // scrap list.
                    final ViewHolder vh = getChildViewHolderInt(view);
                    mChildHelper.unhide(view);
                    int layoutIndex = mChildHelper.indexOfChild(view);
                    if (layoutIndex == RecyclerView.NO_POSITION) {
                        throw new IllegalStateException("layout index should not be -1 after "
                                + "unhiding a view:" + vh);
                    }
                    mChildHelper.detachViewFromParent(layoutIndex);
                    scrapView(view);
                    vh.addFlags(ViewHolder.FLAG_RETURNED_FROM_SCRAP
                            | ViewHolder.FLAG_BOUNCED_FROM_HIDDEN_LIST);
                    return vh;
                }
            }
     //从mCachedViews去获取对应的ViewHolder
     final int cacheSize = mCachedViews.size();
            for (int i = 0; i < cacheSize; i++) {
                final ViewHolder holder = mCachedViews.get(i);
                // invalid view holders may be in cache if adapter has stable ids as they can be
                // retrieved via getScrapOrCachedViewForId
                if (!holder.isInvalid() && holder.getLayoutPosition() == position) {
                    if (!dryRun) {
                        mCachedViews.remove(i);
                    }
                    if (DEBUG) {
                        Log.d(TAG, "getScrapOrHiddenOrCachedHolderForPosition(" + position
                                + ") found match in cache: " + holder);
                    }
                    return holder;
                }
            }
 }
```

根据`position`从`mAttachedScrap -> hideView -> mCachedViews`的顺序向下获取。

**mCachedViews里面存放的都是已存在的ViewHolder，新位置的是没法获取的。**

②`validateViewHolderForOffsetPosition(holder)`：校验获取的ViewHolder是否有效

```java
        boolean validateViewHolderForOffsetPosition(ViewHolder holder) {
            // if it is a removed holder, nothing to verify since we cannot ask adapter anymore
            // if it is not removed, verify the type and id.
            if (holder.isRemoved()) {
                if (DEBUG && !mState.isPreLayout()) {
                    throw new IllegalStateException("should not receive a removed view unless it"
                            + " is pre layout");
                }
                return mState.isPreLayout();
            }
            if (holder.mPosition < 0 || holder.mPosition >= mAdapter.getItemCount()) {
                throw new IndexOutOfBoundsException("Inconsistency detected. Invalid view holder "
                        + "adapter position" + holder);
            }
            if (!mState.isPreLayout()) {
                // don't check type if it is pre-layout.
                final int type = mAdapter.getItemViewType(holder.mPosition);
                if (type != holder.getItemViewType()) {
                    return false;
                }
            }
            if (mAdapter.hasStableIds()) {
                return holder.getItemId() == mAdapter.getItemId(holder.mPosition);
            }
            return true;
        }
```

判断获取的ViewHolder存在和位置是否正确。

③`getScrapOrCachedViewForId()`：根据`position`获取对应的`itemId`然后获取ViewHolder

```java
ViewHolder getScrapOrCachedViewForId(long id, int type, boolean dryRun) {
            // Look in our attached views first
            final int count = mAttachedScrap.size();
            for (int i = count - 1; i >= 0; i--) {
                final ViewHolder holder = mAttachedScrap.get(i);
                if (holder.getItemId() == id && !holder.wasReturnedFromScrap()) {
                    if (type == holder.getItemViewType()) {
                        holder.addFlags(ViewHolder.FLAG_RETURNED_FROM_SCRAP);
                        if (holder.isRemoved()) {
                            if (!mState.isPreLayout()) {
                                holder.setFlags(ViewHolder.FLAG_UPDATE, ViewHolder.FLAG_UPDATE
                                        | ViewHolder.FLAG_INVALID | ViewHolder.FLAG_REMOVED);
                            }
                        }
                        return holder;
                    } else if (!dryRun) {
                        mAttachedScrap.remove(i);
                        removeDetachedView(holder.itemView, false);
                        quickRecycleScrapView(holder.itemView);
                    }
                }
            }
```

利用转化的`itemId`从`mAttachedScrap`获取对应的ViewHolder

④`getRecycledViewPool().getRecycledView()`：从`mRecyclerViewPool`去获取对应的ViewHolder

```java
        public ViewHolder getRecycledView(int viewType) {
            final ScrapData scrapData = mScrap.get(viewType);
            if (scrapData != null && !scrapData.mScrapHeap.isEmpty()) {
                final ArrayList<ViewHolder> scrapHeap = scrapData.mScrapHeap;
                return scrapHeap.remove(scrapHeap.size() - 1);
            }
            return null;
        }
```

存储时会根据不同的`itemType`进行存储，然后取对应ViewHolder时，就不像前面获取ViewHodler需要通过`position或itemId`完整的匹配，只要找到对应`ViewType`并有值，直接取出最后一个ViewHolder缓存进行复用即可。

⑤`holder.resetInternal()`：对从`mRecyclerViewPool`取出的ViewHolder重新进行设置，变成一个全新的ViewHolder

```java
        void resetInternal() {
            mFlags = 0;
            mPosition = NO_POSITION;
            mOldPosition = NO_POSITION;
            mItemId = NO_ID;
            mPreLayoutPosition = NO_POSITION;
            mIsRecyclableCount = 0;
            mShadowedHolder = null;
            mShadowingHolder = null;
            clearPayload();
            mWasImportantForAccessibilityBeforeHidden = View.IMPORTANT_FOR_ACCESSIBILITY_AUTO;
            mPendingAccessibilityState = PENDING_ACCESSIBILITY_STATE_NOT_SET;
            clearNestedRecyclerViewIfNotNested(this);
        }
```

由于取出的ViewHolder进行了重新设置，所以后续就需要调用`bindViewHolder()`重新进行数据绑定



观察上述源码可知，复用机制简单分为以下几步：

- 从`mAttachedScrap`或`mCachedViews`(*一级缓存*)去获取可复用的ViewHolder
- 如果没有找到可复用的ViewHolder，就会从`mViewacheExtension`(*二级缓存*)去获取可复用的ViewHolder。`如果用户没有定义就跳过这一级。`
- 用户未定义货没有找到可复用的ViewHolder，就会从`mRecyclerPool`(*三级缓存*)去获取可复用的ViewHolder。**这时需要调用`onBindViewHolder()`**
- 从上面三步中都没有获取到，就只能自己调用`createViewHolder`(*四级缓存*)去重新创建一个ViewHolder以供使用，然后在调用`bindViewHolder()`绑定数据。最后调整`ViewHolder。itemView`的布局参数。
- 返回最终得到的ViewHolder。

{% fullimage /images/RecyclerView复用机制.png,RecyclerView复用机制,RecyclerView复用机制%}



#### 回收机制

> 由`Recycler`进行View的回收

```java
        public void recycleView(View view) {
            //传入对应的View 然后通过View获取ViewHolder
            ViewHolder holder = getChildViewHolderInt(view);
            //标记该View要移除
            if (holder.isTmpDetached()) {
                removeDetachedView(view, false);
            }
            //该ViewHolder来自缓存可见的数组
            if (holder.isScrap()) {
                //清除缓存
                holder.unScrap();
            } //holder来自缓存的不可见ViewHolder
            else if (holder.wasReturnedFromScrap()) {
                //清除缓存
                holder.clearReturnedFromScrapFlag();
            }
            //开始回收流程
            recycleViewHolderInternal(holder);
        }
```

回收流程的真正执行逻辑是在`recyclerViewHolderInternal()`

```java
        void recycleViewHolderInternal(ViewHolder holder) {
            ...
            //noinspection unchecked
            final boolean transientStatePreventsRecycling = holder
                    .doesTransientStatePreventRecycling();
            final boolean forceRecycle = mAdapter != null
                    && transientStatePreventsRecycling
                    && mAdapter.onFailedToRecycleView(holder);
            boolean cached = false;
            boolean recycled = false;
            if (DEBUG && mCachedViews.contains(holder)) {
                throw new IllegalArgumentException("cached view received recycle internal? "
                        + holder);
            }
            if (forceRecycle || holder.isRecyclable()) {
                //要求缓存数量>0，并且ViewHolder的标志是有效的额，且非REMOVED或UPDATE，进行缓存
                if (mViewCacheMax > 0 /*大小默认为2*/
                        && !holder.hasAnyOfTheFlags(ViewHolder.FLAG_INVALID
                                | ViewHolder.FLAG_REMOVED
                                | ViewHolder.FLAG_UPDATE
                                | ViewHolder.FLAG_ADAPTER_POSITION_UNKNOWN)) {
                    // Retire oldest cached view
                    int cachedViewSize = mCachedViews.size();
                    //mCacheViews已经满了，就把最前面缓存的ViewHolder放到RecyclerViewPool中
                    if (cachedViewSize >= mViewCacheMax && cachedViewSize > 0) {
                        //移除 mCachedViews的第一条缓存数据
                        recycleCachedViewAt(0);①
                        cachedViewSize--;
                    }

                    int targetCacheIndex = cachedViewSize;
                    if (ALLOW_THREAD_GAP_WORK
                            && cachedViewSize > 0
                            && !mPrefetchRegistry.lastPrefetchIncludedPosition(holder.mPosition)) {
                        // when adding the view, skip past most recently prefetched views
                        int cacheIndex = cachedViewSize - 1;
                        while (cacheIndex >= 0) {
                            int cachedPos = mCachedViews.get(cacheIndex).mPosition;
                            //缓存的时候不能覆盖最近经常使用的缓存 利用LFU算法 -- 最少使用策略
                            if (!mPrefetchRegistry.lastPrefetchIncludedPosition(cachedPos)) {
                                break;
                            }
                            cacheIndex--;
                        }
                        targetCacheIndex = cacheIndex + 1;
                    }
                    //将最新的ViewHolder缓存数据插入到mCacheViews中复用
                    mCachedViews.add(targetCacheIndex, holder);
                    cached = true;
                }
                //如果没有触发缓存的话 就放进RecyclerViewPool中
                if (!cached) {
                    addViewHolderToRecycledViewPool(holder, true);
                    recycled = true;
                }
            } else {
                // NOTE: A view can fail to be recycled when it is scrolled off while an animation
                // runs. In this case, the item is eventually recycled by
                // ItemAnimatorRestoreListener#onAnimationFinished.

                // TODO: consider cancelling an animation when an item is removed scrollBy,
                // to return it to the pool faster
                if (DEBUG) {
                    Log.d(TAG, "trying to recycle a non-recycleable holder. Hopefully, it will "
                            + "re-visit here. We are still removing it from animation lists");
                }
            }
            // even if the holder is not removed, we still call this method so that it is removed
            // from view holder lists.
            mViewInfoStore.removeViewHolder(holder);
            if (!cached && !recycled && transientStatePreventsRecycling) {
                holder.mOwnerRecyclerView = null;
            }
        }
```

①`recycleCachedViewAt(0)`：移除`mCachedViews`中的第一条数据并放入到`mRecyclerViewPool`中

```java
        void recycleCachedViewAt(int cachedViewIndex) {
            ViewHolder viewHolder = mCachedViews.get(cachedViewIndex);
            addViewHolderToRecycledViewPool(viewHolder, true);
            mCachedViews.remove(cachedViewIndex);
        }
```

`mRecyclerPool`是根据`itemType`进行缓存的，最大上限为5。

观察上述源码可知，回收机制步骤如下：**回收机制是发生在 RecyclerView滚动时进行的。**

- 在RecyclerView滑动时，会调用到`LayoutManager.scrollVerticalBy()`去处理，在`LayoutManager.fill()`中会去完成`复用以及回收ViewHolder`的功能，最终调用到`recyclerView()`开始回收工作
- 回收时，先判断`mCachedViews`是否已满，未满直接放入。如果`mCachedViews`已满，则取出第一个缓存的ViewHolder放入`RecyclerViewPool`中，然后放入新的ViewHolder进行缓存
- 如果因为`ViewHolder`设置了`REMOVED或UPDATED`标志，无法加入`mCacheViews`中，就直接放入到`mRecyclerPool`中。

{% fullimage /images/RecyclerView回收机制.png,RecyclerView回收机制,RecyclerView回收机制%}

#### 拓展

1.RecyclerView的操作场景主要有三种：

- *有无到有*：RecyclerView中没有任何数据，然后调用`setAdapter()`添加数据源后。RecyclerView添加了数据并显示。

  > `Recycler`在这时只是调用到`createViewHolder()`不会发生缓存事件。

- *在原有数据的情况下刷新*：做了下拉刷新操作，只对屏幕上可见的数据源进行替换。

  > 这时ViewHolder会被标记`FLAG_TMP_DETACHED`，然后这时的Viewolder就会被保存到`mAttachedScrap`中等待复用。

- *RecyclerView发生滑动*：RecyclerView发生了上下或者左右滑动操作。

2.RecyclerView滑动场景下的回收复用涉及到的结构有以下两个：`mCachedViews`和`mRecyclerPool`

  `mCachedViews`的优先级高于`mRecyclerPool`，回收时最新的ViewHolder先放入到`mCachedViews`中，没位置了就移除最旧的那个给新的腾地方，最旧的就放到`mRecyclerPool`中。

  复用时也是一样，先从`mCachedViews`去获取对应的ViewHolder，需要匹配`position`，就是需要位置对应才能进行复用。找不到就去`mRecyclerPool`中找，在`mRecyclerPool`中的ViewHolder都跟新的一样，需要重新绑定数据(*bindViewHolder()*)。还没有就要自己创建了(*createViewHolder()*)。

3.`mCachedViews`上限是2

## RecyclerView优化

- **数据处理与视图绑定分离**

  > `bindViewHolder()`是在主线程中进行的，如果里面发生了耗时操作，会影响滑动的流畅性。
  >
  > **`onBindViewHolder()`中应该只进行数据的`set`操作，不需要做其他判断。**

- **数据优化**

  > 1. 分页加载远端数据，对拉取的数据进行缓存，提高二次加载的速度
  > 2. 对于新增或删除数据通过`DiffUtil`，来进行局部数据刷新，而不是每次都去进行全量刷新。

- **布局优化**

  > 1. `减少过度绘制`：减少布局层级，可以考虑使用自定义View来减少层级，或者设置更合理的布局。
  > 2. `减少xml文件`：`inflate`时间：去解析xml都需要经过耗时的IO操作，可以利用代码直接生成对应的布局，利用`new View()`生成。
  > 3. `减少View对象的创建`：需要尽可能简化ItemView，对多ViewType能够共用的部分尽量设计成自定义View，减少View的构造和嵌套。

- **其他优化**

  > 1. 设置高度固定：如果Item高度固定的话，可以使用`RecyclerView.setHasFixedSize(true)`，避免调用`requestLayout()`
  >
  > 2. 共用`RecycledViewPool`：具有相关的Adapter，就可以调用`RecyclerView.setRecycledViewPool(pool)`共用同一个。
  >
  > 3. 加大RecyclerView的缓存：空间换时间
  >
  >    ```java
  >    recyclerView.setItemViewCacheSize(20);
  >    recyclerView.setDrawingCacheEnabled(true);
  >    recyclerView.setDrawingCacheQuality(View.DRAWING_CACHE_QUALITY_HIGH);
  >    ```
  >
  > 4. 增加RecyclerView预留的额外空间：显示范围之外，增加额外的缓存空间。*默认为2。*
  >
  >    ```java
  >    new LinearLayoutManager(this) {
  >        @Override
  >        protected int getExtraLayoutSpace(RecyclerView.State state) {
  >            return size;
  >        }
  >    };
  >    ```
  >
  >    
  >
  > 5. 减少ItemView监听器的创建
  >
  >    > 不要对每个Item都去创建一个监听器，而是根据`android:id`设置不同的操作，共用一个监听器。
  >
  > 6. 优化滑动操作：设置`RecyclerView.addOnScrollListener()`在滑动过程中停止加载
  >
  > 7. 关闭默认动画效果：设置`((SimpleItemAnimator) rv.getItemAnimator()).setSupportsChangeAnimations(false)`

## RecyclerView拓展

是否需要将ListView替换成RecyclerView?

> 从性能上看，RecyclerView并没有带来明显的提升。如果需要支持动画，或者频繁更新，局部刷新，建议使用RecyclerView。只是单纯用于展示数据的话，ListView实现更加简单。

## 内容引用

[基于场景解析RecyclerView的回收复用机制原理](https://www.cnblogs.com/dasusu/p/7746946.html)

[RecyclerView必知必会](https://mp.weixin.qq.com/s/CzrKotyupXbYY6EY2HP_dA?)