---
title: include、merge及ViewStub相关
date: 2019-01-03 12:13:11
tags: 
  - Android
  - 性能优化
top: 10
---

# 主要解析include、merge及ViewStub

{% fullimage /images/布局优化之xml方面.png,布局优化之xml方面,布局优化之xml方面%}

## include

> 主要为了解决重复定义相同布局的问题。把一套布局封装起来，需要使用时使用<include/>标签引入。提高代码复用性
>
> 使用注意事项：
>
> 1. 如若我们在<include/>中设置了android:id属性，这个id会覆盖原先`<include/>中layout设置的布局id，所以在引用该id时需要注意
> 2. 如果需要在<include/>中需要使用andrdoid:**属性，必须要设置layout_width以及layout_height属性

源码分析：

从Activity创建开始，调用`setContentView()`传入对应xml文件，然后开始解析并绘制。

```java
// ../android/app/Activity.java
public void setContentView(@LayoutRes int layoutResID){
  //getWindow() 对应的就是PhoneWindow 
  getWindow().setContentView(layoutResID);
  initWindowDecorActionBar();
}

// ../com/android/internal/policy/PhoneWindow.java
    @Override
    public void setContentView(int layoutResID) {
        // Note: FEATURE_CONTENT_TRANSITIONS may be set in the process of installing the window
        // decor, when theme attributes and the like are crystalized. Do not check the feature
        // before this happens.
        if (mContentParent == null) {
            //初始化 DecorView
            installDecor();
        } else if (!hasFeature(FEATURE_CONTENT_TRANSITIONS)) {
            mContentParent.removeAllViews();
        }

        if (hasFeature(FEATURE_CONTENT_TRANSITIONS)) {
            final Scene newScene = Scene.getSceneForLayout(mContentParent, layoutResID,
                    getContext());
            transitionTo(newScene);
        } else {
           //渲染传进来的xml
            mLayoutInflater.inflate(layoutResID, mContentParent);
        }
        mContentParent.requestApplyInsets();
        final Callback cb = getCallback();
        if (cb != null && !isDestroyed()) {
            cb.onContentChanged();
        }
        mContentParentExplicitlySet = true;
    }

// ../android/view/LayoutInflater.java
    public View inflate(XmlPullParser parser, @Nullable ViewGroup root) {
        return inflate(parser, root, root != null);
    }

    public View inflate(@LayoutRes int resource, @Nullable ViewGroup root, boolean attachToRoot) {
        final Resources res = getContext().getResources();
        final XmlResourceParser parser = res.getLayout(resource);
        try {
            return inflate(parser, root, attachToRoot);
        } finally {
            parser.close();
        }
    }

    public View inflate(XmlPullParser parser, @Nullable ViewGroup root, boolean attachToRoot) {
        synchronized (mConstructorArgs) {
          ...
            final String name = parser.getName();
            //如果是merge标签
            if (TAG_MERGE.equals(name)) {
                    if (root == null || !attachToRoot) {
                        throw new InflateException("<merge /> can be used only with a valid "
                                + "ViewGroup root and attachToRoot=true");
                    }

                    rInflate(parser, root, inflaterContext, attrs, false);
            } else {
              ...
                    rInflateChildren(parser, temp, attrs, true);
            }
          ...
        }
    }

//解析所有子控件
    final void rInflateChildren(XmlPullParser parser, View parent, AttributeSet attrs,
            boolean finishInflate) throws XmlPullParserException, IOException {
        rInflate(parser, parent, parent.getContext(), attrs, finishInflate);
    }

    void rInflate(XmlPullParser parser, View parent, Context context,
            AttributeSet attrs, boolean finishInflate) throws XmlPullParserException, IOException {

        final int depth = parser.getDepth();
        int type;
        boolean pendingRequestFocus = false;

        while (((type = parser.next()) != XmlPullParser.END_TAG ||
                parser.getDepth() > depth) && type != XmlPullParser.END_DOCUMENT) {

            if (type != XmlPullParser.START_TAG) {
                continue;
            }

            final String name = parser.getName();
            
            if (TAG_REQUEST_FOCUS.equals(name)) {
                pendingRequestFocus = true;
                consumeChildElements(parser);
            } else if (TAG_TAG.equals(name)) {
                parseViewTag(parser, parent, attrs);
              //解析到<include>标签
            } else if (TAG_INCLUDE.equals(name)) {
                if (parser.getDepth() == 0) {
                    throw new InflateException("<include /> cannot be the root element");
                }
               //解析include中包含的布局
                parseInclude(parser, context, parent, attrs);
            } else if (TAG_MERGE.equals(name)) {
                throw new InflateException("<merge /> must be the root element");
            } else {
                final View view = createViewFromTag(parent, name, context, attrs);
                final ViewGroup viewGroup = (ViewGroup) parent;
                final ViewGroup.LayoutParams params = viewGroup.generateLayoutParams(attrs);
                rInflateChildren(parser, view, attrs, true);
                viewGroup.addView(view, params);
            }
        }

        if (pendingRequestFocus) {
            parent.restoreDefaultFocus();
        }

      //当系统解析完View之后调用
        if (finishInflate) {
            parent.onFinishInflate();
        }
    }

    private void parseInclude(XmlPullParser parser, Context context, View parent,
            AttributeSet attrs) throws XmlPullParserException, IOException {
      // include标签必须在ViewGroup中使用
      if (parent instanceof ViewGroup) {
         ...
           //解析android:layout 属性
           int layout = attrs.getAttributeResourceValue(null, ATTR_LAYOUT, 0);
            if (layout == 0) {
                final String value = attrs.getAttributeValue(null, ATTR_LAYOUT);
                if (value == null || value.length() <= 0) {
                    throw new InflateException("You must specify a layout in the"
                            + " include tag: <include layout=\"@layout/layoutID\" />");
                }
                layout = context.getResources().getIdentifier(
                        value.substring(1), "attr", context.getPackageName());

            }
        
        if (layout == 0) {
            final String value = attrs.getAttributeValue(null, ATTR_LAYOUT);
            throw new InflateException("You must specify a valid layout "
                        + "reference. The layout ID " + value + " is not valid.");
            } else {
          if (TAG_MERGE.equals(childName)) {
              rInflate(childParser, parent, context, childAttrs, false);
          } else {
             //继续渲染子布局
              rInflateChildren(childParser, view, childAttrs, true);
              //覆盖原有id
              if (id != View.NO_ID) {
                      view.setId(id);
              }
           }
          ...
          group.addView(view);
        }
      }
    }
```

若存在`<include>`标签，会去解析`<include>`标签中的layout，解析完成后，会把解析得到的View加回到原有布局中。

## merge

> 减少层级布局，可以将<merge>标签下的子View直接添加到<merge>标签的parent中，可以减少不必要的层级。添加的子View遵循父布局的布局方式。
>
> `<merge>`标签一般和`<include>`标签搭配使用，`<merge>`标签不支持设置`android:**`属性，因为它不是View，只是声明了一些View。
>
> *使用`LayoutInflate.inflate(resId,viewroot,attachToRoot)`渲染时，第二个viewroot必须设置，且第三个参数必须为true。*
>
> **<merge>标签最好是替代FlameLayout或者与父布局方向一致的LinearLayout**

上述源码中，`inflate()`执行时判断`name`为`TAG_MERGE`时就会直接调用`rInflate()`

```java
在普通xml中引用merge布局都是 通过include引用的 
 private void parseInclude(XmlPullParser parser, Context context, View parent,
            AttributeSet attrs) throws XmlPullParserException, IOException {
  ...
               final View view = createViewFromTag(parent, name, attrs);  
               // 获取merge标签的parent  
               final ViewGroup viewGroup = (ViewGroup) parent;  
               // 获取布局参数  
               final ViewGroup.LayoutParams params = viewGroup.generateLayoutParams(attrs);  
               // 递归解析每个子元素  
               rInflate(parser, view, attrs, true);  
               // 将子元素直接添加到merge标签的parent view中  
               viewGroup.addView(view, params);  
  ...
}

```

从上述源码分析中可得 <merge>标签对应的View会直接添加至父容器中，减少一层布局。

拓展：

1. 如果Activity布局的根节点为`FlameLayout`，可以直接替换为`<merge>`标签，执行`setContentView()`后可以减少一层布局
2. 自定义View如果继承`LinearLayout`，可以把自定义View的布局文件根节点设置为`<merge>`

## ViewStub

> ViewStub继承了View，非常轻量级且宽高都为0，因为本身不参与任何的布局和绘制过程。主要用于 一些不常出现的界面可以按需加载，提高加载效率。

源码分析：

```java
// ../android/view/ViewStub.java
public final class ViewStub extends View {
     
     //初始化ViewStub
     public ViewStub(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context);

        final TypedArray a = context.obtainStyledAttributes(attrs,
                R.styleable.ViewStub, defStyleAttr, defStyleRes);
        mInflatedId = a.getResourceId(R.styleable.ViewStub_inflatedId, NO_ID);
        mLayoutResource = a.getResourceId(R.styleable.ViewStub_layout, 0);
        mID = a.getResourceId(R.styleable.ViewStub_id, NO_ID);
        a.recycle();
        //默认隐藏
        setVisibility(GONE);
        //阻止View的绘制
        setWillNotDraw(true);
    }
  
  ...
    //设置宽高为0
      @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        setMeasuredDimension(0, 0);
    }

  //空实现 不会绘制任何内容
    @Override
    public void draw(Canvas canvas) {
    }

    @Override
    protected void dispatchDraw(Canvas canvas) {
    }
  
    public void setVisibility(int visibility) {
        if (mInflatedViewRef != null) {
          //如果已经渲染完成 与普通View逻辑相同
            View view = mInflatedViewRef.get();
            if (view != null) {
                view.setVisibility(visibility);
            } else {
                throw new IllegalStateException("setVisibility called on un-referenced view");
            }
        } else {
            super.setVisibility(visibility);
            if (visibility == VISIBLE || visibility == INVISIBLE) {
                //需要渲染View
                inflate();
            }
        }
    }
  
  //渲染代码
    public View inflate() {
        final ViewParent viewParent = getParent();

        if (viewParent != null && viewParent instanceof ViewGroup) {
            if (mLayoutResource != 0) {
                final ViewGroup parent = (ViewGroup) viewParent;
                //添加并渲染View
                final View view = inflateViewNoAdd(parent);
                //移除原来定义的ViewStub 替换渲染的View上去
                replaceSelfWithView(view, parent);

                mInflatedViewRef = new WeakReference<>(view);
                if (mInflateListener != null) {
                    //监听渲染完成
                    mInflateListener.onInflate(this, view);
                }

                return view;
            } else {
                throw new IllegalArgumentException("ViewStub must have a valid layoutResource");
            }
        } else {
            throw new IllegalStateException("ViewStub must have a non-null ViewGroup viewParent");
        }
    }
  
      private View inflateViewNoAdd(ViewGroup parent) {
        final LayoutInflater factory;
        if (mInflater != null) {
            factory = mInflater;
        } else {
            factory = LayoutInflater.from(mContext);
        }
        //渲染View
        final View view = factory.inflate(mLayoutResource, parent, false);

        if (mInflatedId != NO_ID) {
          //赋值设置的id到ViewStub渲染的View上
            view.setId(mInflatedId);
        }
        return view;
    }

    private void replaceSelfWithView(View view, ViewGroup parent) {
        final int index = parent.indexOfChild(this);
        //移除本身存在的ViewStub
        parent.removeViewInLayout(this);

        final ViewGroup.LayoutParams layoutParams = getLayoutParams();
        //以ViewStub自身设置的 LayoutParams为准 
        if (layoutParams != null) {
            parent.addView(view, index, layoutParams);
        } else {
            parent.addView(view, index);
        }
    }
}
```

根据上述源码发现，`inflate()`只可以调用一次，否则会因移除ViewStub出错。