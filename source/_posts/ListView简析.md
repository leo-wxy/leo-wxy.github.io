---
title: ListView简析
date: 2019-01-04 10:12:32
tags: Android
top: 10
---



{% fullimage /images/ListView机制.png,ListView机制,ListView机制%}

## ListView定义

> 专门用于处理那种内容元素很多，手机屏幕无法展示出所有的内容的情况。可以使用列表的形式来展示内容，超出屏幕部分的内容只需要通过手指滑动就可以移到屏幕内了。

ListView相比RecyclerView，有一些优点：

- `addHeaderVew()`，`addFooterView()`添加头尾视图
- `android:divider`设置自定义分割线
- `setOnItemClickListener`设置点击事件

上述功能没有直接在RecyclerView直接提供，要自己实现。*如果只是简单的展示内容，使用ListView相对更简单。*

## ListView用法

- 创建Adapter：在ListView和数据源之间起到了一个桥梁的作用，ListView借用Adapter和数据去打交道。

  > 常见的Adapter有以下几类：
  >
  > - `BaseAdapter`：基础数据适配器。
  > - `SimpleAdapter`：简单适配器，系统自定义了一些方法。
  > - `ArrayAdapter`：数据和UI一对一。
  > - `SimpleCursorAdapter`：用于游标类型的数据源适配。

  一般都会去继承`BaseAdapter`自定义实现功能

  ```java
  public class ListViewAdapter extends BaseAdapter {
      Context context;
      List<String> data;
      LayoutInflater mInflater;
  
      public ListViewAdapter(Context _context, List<String> _data) {
          this.context = _context;
          this.data = _data;
          mInflater = LayoutInflater.from(context);
      }
  
      @Override
      public int getCount() {
          return data == null ? 0 : data.size();
      }
  
      @Override
      public Object getItem(int position) {
          return null;
      }
  
      @Override
      public long getItemId(int position) {
          return position;
      }
      
      //在其中完善 Item的创建以及数据绑定流程
      @Override
      public View getView(int position, View convertView, ViewGroup parent) {
          ViewHolder viewHolder;
          if (convertView == null) {
              convertView = mInflater.inflate(R.layout.item_demo, null);
              viewHolder = new ViewHolder();
              viewHolder.title = convertView.findViewById(R.id.title);
              convertView.setTag(viewHolder);
          } else {
              viewHolder = (ViewHolder) convertView.getTag();
          }
          viewHolder.title.setText(data.get(position));
          return convertView;
      }
  
      private class ViewHolder {
          TextView title;
      }
  }
  ```

- ListView绑定Adapter

  ```java
  listView.addHeaderView(headerView);
  listView.addFooterView(footerView);
  listView.setAdapter(new ListViewAdapter(Activity.this,datas));
  //设置ListView 的 item点击事件
  listView.setOnItemClickListener(new AdapterView.OnItemClickListener() {
              @Override
              public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                  
              }
          });
  ```

## ListView源码解析

### 缓存机制

> ListView是以`View`作为单位进行回收。`RecycleBin`是ListView缓存机制的实现类。

RecycleBin实现的是**二级缓存**。

- `View[] mActiveViews`：缓存屏幕上的View，在该缓存中的View不需要调用`getView()`
- `ArrayList<View>[] mScrapViews`：对应了每个`ItemType`，缓存由于滚动而消失的View，此处的View如果被复用，会以参数的形式传给`getView()`。



ListView通过调用`layoutChildren()`对子Item进行布局，一般发生在滑动时刻。

```java
protected void layoutChildren() {
  ...
    final int firstPosition = mFirstPosition;
    final RecycleBin recycleBin = mRecycler;
    //如果数据源发生了改变，就将所有的itemView都回收至scrapView
    if (dataChanged) {
        for (int i = 0; i < childCount; i++) {
            recycleBin.addScrapView(getChildAt(i), firstPosition+i);
        }
    } else {
        //没有发生改变 ，缓存至mActiveViews
        recycleBin.fillActiveViews(childCount, firstPosition);
    }
    //清空所有View 防止第二次layout过程产生一份重复数据
    detachAllViewsFromParent();
    //填充子Item
    switch (mLayoutMode) {
           case LAYOUT_SET_SELECTION:
                if (newSel != null) {
                    sel = fillFromSelection(newSel.getTop(), childrenTop, childrenBottom);
                } else {
                    sel = fillFromMiddle(childrenTop, childrenBottom);
                }
                break;
           ...
    }
    //回收多余的ActiveView
    recycleBin.scrapActiveViews();
}
```

`layoutChildren()`调用`fillXX()`在不同位置填充item。其中的主要实现方法是`makeAndAddView()`实现填充View逻辑。

```java
    private View makeAndAddView(int position, int y, boolean flow, int childrenLeft,
            boolean selected) {
        if (!mDataChanged) {
            // 获取缓存在 mActiveViews中的view
            final View activeView = mRecycler.getActiveView(position);
            if (activeView != null) {
                //重新布局子View
                setupChild(activeView, position, y, flow, childrenLeft, selected, true);
                return activeView;
            }
        }

        //从 mCraspViews中去获取或者 重新生成一个View
        final View child = obtainView(position, mIsScrap);

        // This needs to be positioned and measured.
        setupChild(child, position, y, flow, childrenLeft, selected, mIsScrap[0]);

        return child;
    }
```

如果从`mActiveViews`中获取到了对应的View，就直接取出来，然后调用`setUpChild()`把子View重新attach到ListView上。

如果没有找到合适的View，就需要调用到`obtainView()`，重新执行`getView()`流程生成对应布局，影响加载效率。

```java
View obtainView(int position, boolean[] outMetadata) {
  ...
     //获取刚刚因为滑动而消失的View
     final View transientView = mRecycler.getTransientStateView(position);
        if (transientView != null) {
            final LayoutParams params = (LayoutParams) transientView.getLayoutParams();

            // If the view type hasn't changed, attempt to re-bind the data.
            if (params.viewType == mAdapter.getItemViewType(position)) {
                final View updatedView = mAdapter.getView(position, transientView, this);

                // If we failed to re-bind the data, scrap the obtained view.
                if (updatedView != transientView) {
                    setItemViewLayoutParams(updatedView, position);
                    mRecycler.addScrapView(updatedView, position);
                }
            }

            outMetadata[0] = true;

            // Finish the temporary detach started in addScrapView().
            transientView.dispatchFinishTemporaryDetach();
            return transientView;
        }
      
     //从RecycleBin获取可复用的View
     final View scrapView = mRecycler.getScrapView(position);
        //实质调用 我们自定义的getView事件 scrapView 对应的 就是 convertView ,如果为null ，就需要重新 inflate重新加载布局
        final View child = mAdapter.getView(position, scrapView, this);
        if (scrapView != null) {
            if (child != scrapView) {
                // 生成了一个新的View  要重新插入缓存中
                mRecycler.addScrapView(scrapView, position);
            } else if (child.isTemporarilyDetached()) {
                outMetadata[0] = true;

                // Finish the temporary detach started in addScrapView().
                child.dispatchFinishTemporaryDetach();
            }
        }
  ...
}
```

接下来介绍`getScrapView(position)`的实现，该方法通过`position`得到`ItemType`，然后根据`ItemType`从`mScrapViews`获取可复用的View，如果获取不到，则返回null，

```java
        View getScrapView(int position) {
            final int whichScrap = mAdapter.getItemViewType(position);
            if (whichScrap < 0) {
                return null;
            }
            if (mViewTypeCount == 1) {
                return retrieveFromScrap(mCurrentScrap, position);
            } else if (whichScrap < mScrapViews.length) {
                return retrieveFromScrap(mScrapViews[whichScrap], position);
            }
            return null;
        }

 private View retrieveFromScrap(ArrayList<View> scrapViews, int position) {
            final int size = scrapViews.size();
            if (size > 0) {
                // See if we still have a view for this position or ID.
                // Traverse backwards to find the most recently used scrap view
                for (int i = size - 1; i >= 0; i--) {
                    final View view = scrapViews.get(i);
                    final AbsListView.LayoutParams params =
                            (AbsListView.LayoutParams) view.getLayoutParams();

                    if (mAdapterHasStableIds) {
                        final long id = mAdapter.getItemId(position);
                        if (id == params.itemId) {
                            return scrapViews.remove(i);
                        }
                    } else if (params.scrappedFromPosition == position) {
                        final View scrap = scrapViews.remove(i);
                        clearScrapForRebind(scrap);
                        return scrap;
                    }
                }
                //取出缓存列表的最后一条数据进行复用
                final View scrap = scrapViews.remove(size - 1);
                clearScrapForRebind(scrap);
                return scrap;
            } else {
                return null;
            }
        }
```

得到需要显示的View后，再调用`setUpChild()`显示在界面上

```java
//fromActiveView  isAttachedToWindow为true

private void setupChild(View child, int position, int y, boolean flowDown, int childrenLeft,
            boolean selected, boolean isAttachedToWindow/*这个View当前是否已显示*/) {
    ...
          if ((isAttachedToWindow && !p.forceAdd) || (p.recycledHeaderFooter
                && p.viewType == AdapterView.ITEM_VIEW_TYPE_HEADER_OR_FOOTER)) {
            attachViewToParent(child, flowDown ? -1 : 0, p);

            if (isAttachedToWindow
                    && (((AbsListView.LayoutParams) child.getLayoutParams()).scrappedFromPosition)
                            != position) {
                child.jumpDrawablesToCurrentState();
            }
        } else {
            p.forceAdd = false;
            if (p.viewType == AdapterView.ITEM_VIEW_TYPE_HEADER_OR_FOOTER) {
                p.recycledHeaderFooter = true;
            }
            addViewInLayout(child, flowDown ? -1 : 0, p, true);
            // add view in layout will reset the RTL properties. We have to re-resolve them
            child.resolveRtlPropertiesIfNeeded();
        }
    
}
```



观察上述源码可知，缓存机制简单分为以下几步：

- ListView滑动时，会调用到`layoutChildren()`对子View进行重新布局，如果数据源没有发生改变，需要把当前屏幕上存在的View缓存至`mActiveViews`中；发生了改变的话，就都缓存至`mScrapViews`中。
- 清除掉ListView的所有子View
- 开始进行数据填充，主要实现逻辑是`makeAndAddView()`。这里分为两部分：如果可以从`mActiveViews`获取到View，就直接插入该View；没有获取到合适的View，需要调用`obtainView()`从`mScrapViews`获取可复用的View，然后重新走加载布局(`getView()`)的流程。

{% fullimage /images/ListView缓存过程.png,ListView缓存过程,ListView缓存过程%}

## ListView优化

- `ConverView重用机制`：在`getView()`中使用`convertView`，就不需要每次都去inflate一个View出来，减少内存损耗。
- `ViewHolder`：使用ViewHolder，避免在`getView()`频繁调用使用`findViewById()`，节省内存
- `滑动时不载入图片`：给ListView设置`setOnScrollListener()`，在其中`onScrollStateChanged()`判断是否为滑动状态，是的话就停止加载图片。
- `getView()不执行耗时操作`：`getView()`是执行在主线程的，需要减少耗时操作。
- `设置scrollingCache和animateCache为false`：默认都是开启的，会消耗大量内存。
- `降低Item的层级`

## ListView拓展

### ListView局部刷新

> 平常用到ListView的时候，如果需要对单个Item进行刷新，我们就会调用到`notifyDataSetChanged()`去进行全量刷新，效率很低。

ListView局部刷新有3种方案可以实现：

1. 更新对应View内容

   > 通过`listView.getChildAt(pos)`拿到需要更新的item布局，然后通过`findViewById()`去找到对应的控件进行设置

   ```java
   private void updateItemView(ListView listView,int pos,Data data/*需要更新的内容*/){
     int firstVisiblePosition = listView.getFirstVisiblePosition();
     int lastVisiblePosition = listView.getLastVisiblePosition();
     
     if(pos>=firstVisiblePosition && pos<= lastVisiblePosition){
       View view = listView.getChildAt(pos-firstVisiblePosition);
       TextView textView= view.findViewById(R.id.textView);
       textView.setText(data.getXX());
     }
   }
   ```

2. 通过ViewHolder去设置

   > 通过Item找到对应ViewHolder，通过ViewHolder设置数据

   ```java
   private void updateItemView(ListView listView,int pos,Data data/*需要更新的内容*/){
     int firstVisiblePosition = listView.getFirstVisiblePosition();
     int lastVisiblePosition = listView.getLastVisiblePosition();
     
     if(pos>=firstVisiblePosition && pos<= lastVisiblePosition){
       View view = listView.getChildAt(pos-firstVisiblePosition);
       ViewHolder viewHolder = (ViewHolder)view.getTag();
       TextView textView= iewHolder.textView;
       textView.setText(data.getXX());
     }
   }
   ```

3. 再调用一次`getView()`

   > 调用Adapter的`getView()`，对内部的View进行刷新。*Google官方推荐做法。*

   ```java
   //外部对数据源进行变化，内部自动去更新
   private void updateItemView(ListView listView,int pos,Data data/*需要更新的内容*/){
     int firstVisiblePosition = listView.getFirstVisiblePosition();
     int lastVisiblePosition = listView.getLastVisiblePosition();
     
     if(pos>=firstVisiblePosition && pos<= lastVisiblePosition){
       View view = listView.getChildAt(pos-firstVisiblePosition);
       listViewAdapter.getView(pos,view,listView)
     }
   }
   ```

   

## 内容引用

[RecyclerView必知必会](https://mp.weixin.qq.com/s/CzrKotyupXbYY6EY2HP_dA?)

[Android ListView工作原理完全解析，带你从源码的角度彻底理解](https://blog.csdn.net/guolin_blog/article/details/44996879)