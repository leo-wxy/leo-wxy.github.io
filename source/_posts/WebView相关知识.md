---
title: WebView相关知识
date: 2019-03-12 10:45:39
tags: Android
top: 10
---

<!--webview-->

> WebView是一个基于WebKit引擎，展现Web页面的控件。
>
> 主要提供以下功能：
>
> - 显示和渲染Web页面
> - 直接使用html文件做布局
> - 可以和js进行交互

## WebView基本使用

### 添加权限

```xml AndroidManifest.xml
<uses-permission android:name="android.permission.INTERNET"/>
```



### 生成一个WebView组件

直接引入

```java
WebView webView = new WebView(this);
```

写在xml中引入

```xml
<WebView
    android:id="@+id/wv"
    android:width="match_parent"
    android:height = "match_parent"
      />

WebView webview = (WebView) findViewById(R.id.wv);
```



### 设置WebView基本信息

主要利用`WebSetting、WebViewClient，WebChromeClient`

#### `WebSetting`

> 进行基本属性配置

```java
//声明WebSettings子类
WebSettings webSettings = webView.getSettings();

//如果访问的页面中要与Javascript交互，则webview必须设置支持Javascript
webSettings.setJavaScriptEnabled(true);  

//支持插件
webSettings.setPluginsEnabled(true); 

//设置自适应屏幕，两者合用
webSettings.setUseWideViewPort(true); //将图片调整到适合webview的大小 
webSettings.setLoadWithOverviewMode(true); // 缩放至屏幕的大小

//缩放操作
webSettings.setSupportZoom(true); //支持缩放，默认为true。是下面那个的前提。
webSettings.setBuiltInZoomControls(true); //设置内置的缩放控件。若为false，则该WebView不可缩放
webSettings.setDisplayZoomControls(false); //隐藏原生的缩放控件

//其他细节操作
webSettings.setCacheMode(WebSettings.LOAD_CACHE_ELSE_NETWORK); //关闭webview中缓存 
webSettings.setAllowFileAccess(true); //设置可以访问文件 
webSettings.setJavaScriptCanOpenWindowsAutomatically(true); //支持通过JS打开新窗口 
webSettings.setLoadsImagesAutomatically(true); //支持自动加载图片
webSettings.setDefaultTextEncodingName("utf-8");//设置编码格式
```



#### `WebViewClient`

> 处理各种通知以及请求事件

```java
webView.setWebViewClient(new WebViewClient(){
      @Override
      public boolean shouldOverrideUrlLoading(WebView view, String url) {①
          view.loadUrl(url);
          return true;
      }
  
      @Override
      public void  onPageStarted(WebView view, String url, Bitmap favicon) {②
         
      }
  
      @Override
      public void onPageFinished(WebView view, String url) {③
         
      }
  
      @Override
      public boolean onLoadResource(WebView view, String url) {④
         
      }
  
  		@Override
      public void onReceivedError(WebView view, int errorCode, String description, String failingUrl){⑤
					//errorCode表示了 加载错误对应的错误码
      }
  
  		@Override    
      public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {⑥

       }    
  });
```

##### `shouldOverrideUrlLoading`

> 复写该方法，避免打开外部浏览器

```java
@Override
      public boolean shouldOverrideUrlLoading(WebView view, String url) {①
          view.loadUrl(url);
          return true;
      }
```



##### `onPageStarted`

> 开始载入页面时回调该方法

##### `onPageFinished`

> 页面载入结束时回调该方法

##### `onLoadResource`

> 页面资源开始加载时调用，并且每次加载时都会调用

##### `onReceivedError`

> 加载页面出现错误时回调，可用于显示不同错误码的展示页面

##### `onReceivedSslError`

> WebView默认是不处理HTTPs请求的，页面会显示空白

```java
		@Override    
    public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {    
        handler.proceed();    //表示等待证书响应
     // handler.cancel();      //表示挂起连接，为默认方式
     // handler.handleMessage(null);    //可做其他处理
    }   
```



#### `WebChromeClient`

> 辅助WebView处理js、网站标题等属性

```java
webview.setWebChromeClient(new WebChromeClient(){

      @Override
      public void onProgressChanged(WebView view, int newProgress) {①
           //newProgress 当前加载进度
      });
  
   		@Override
    	public void onReceivedTitle(WebView view, String title) {②
       	  //title 当前页面标题
    	}
}
```

##### `onProgressChanged`

> 获得当前页面的加载进度

##### `onReceivedTitle`

> 获得当前页面的标题

### 设置WebView要显示的网页

```java
//load本地
webView.loadUrl("file:///android_asset/hellotest.html");
//load在线
webView.loadUrl("http://www.google.com");
```

### 结束时销毁WebView

```java
@Override
    protected void onDestroy() {
        if (webView != null) {
            webView.loadDataWithBaseURL(null, "", "text/html", "utf-8", null);
            webView.clearHistory();

            ((ViewGroup) webView.getParent()).removeView(webView);
            webView.destroy();
            webView = null;
        }
        super.onDestroy();
    }
```

### 拓展

前进/后退网页

```java
@Override
public boolean onKeyDown(int keyCode, KeyEvent event) {  
  if (keyCode == KeyEvent.KEYCODE_BACK && webView.canGoBack()) {    
     webView.goBack();// 返回前一个页面   
     return true;   
 	}    
		return super.onKeyDown(keyCode, event);
}
..................................
//是否可以前进                     
Webview.canGoForward()
//前进网页
Webview.goForward()
```



## Android与Js的交互

>  Android与JS间的交互唯一桥梁就是`WebView`。

```html
<!DOCTYPE html>
<html>
   <head>
      <meta charset="utf-8">
      <title>WebView Test</title>  
      <script>
         //用于调用Android中方法
         function callAndroid(){
            myObj.hello("js调用了android中的hello方法");
         }
         //用于测试第二种调用方法 
         function callAndroidWithLoadUrl(){
           document.location="js://showMsg?msg=android"
         }
         //用于调用js方法
         function callJS(){
      			alert("Android调用了JS的callJS方法");
   			 }
         function callJsWithParams(params){
            alert("Android调用了JS的callJsWithParams方法" + params); 
         }
         function callJsWithParamsAndResult(params){
            alert("Android调用了JS的callJsWithParamsAndResult" + params);
            return "Success";
         }
      </script>
   </head>
   <body>
      <button type="button" id="button1" onclick="callAndroid()"></button>
   </body>
</html>
```



### Android调用JS

#### 通过`WebView.loadUrl()`调用

> **Js的调用一定要在`onPageFinished()`回调之后才可调用，否则会导致失败。**

```java
webView.loadUrl("javascript:callJS()");

webView.loadUrl("javascript:callJsWithParams("+params+")")
```

在4.4之前并没有直接提供调用js函数并获取返回值的方法，需要操作的是 **Android调用Js，Js执行完毕后，再通过Js继续调用Android方法返回值。**

#### 通过`WebView.evaluateJavascript()`调用(4.4后新增)

> 该方法效率高于`loadUrl()`，不会导致页面的刷新。

```java
mWebView.evaluateJavascript（"javascript:callJsWithParamsAndResult("+params+")", new ValueCallback<String>() {
        @Override
        public void onReceiveValue(String value) {
            // value 为 Success
        }
    });
```



在具体使用时，可以将两者进行结合使用

```java
// Android版本变量
final int version = Build.VERSION.SDK_INT;
// 因为该方法在 Android 4.4 版本才可使用，所以使用时需进行版本判断
if (version < 18) {
    mWebView.loadUrl("javascript:callJS()");
} else {
    mWebView.evaluateJavascript（"javascript:callJS()", new ValueCallback<String>() {
        @Override
        public void onReceiveValue(String value) {
            
        }
    });
}
```



### JS调用Android

#### 通过`WebView.addJavascriptInterface()`进行对象映射

```java
public class MyObject extends Object{
  @JavascriptInterface
  public void hello(String msg){
    
  }
}
//将Java对象映射到Js上
webView.addJavascriptInterface(new MyObject(), "myObj");
```

**该方法在4.2以下存在严重的安全漏洞问题，下一节中会有相关的解决方法。**

#### 利用`WebViewClient.shouldOverrideUrlLoading()`拦截url

```java
mWebView.setWebViewClient(new WebViewClient() {
                                      @Override
                                      public boolean shouldOverrideUrlLoading(WebView view, String url) {

                                          // 步骤2：根据协议的参数，判断是否是所需要的url
                                          // 一般根据scheme（协议格式） & authority（协议名）判断（前两个参数）
                                          //假定传入进来的 url = "js://webview?arg1=111&arg2=222"（同时也是约定好的需要拦截的）

                                          Uri uri = Uri.parse(url);                                 
                                          // 如果url的协议 = 预先约定的 js 协议
                                          // 就解析往下解析参数
                                          if ( uri.getScheme().equals("js")) {

                                              // 如果 authority  = 预先约定协议里的 webview，即代表都符合约定的协议
                                              // 所以拦截url,下面JS开始调用Android需要的方法
                                              if (uri.getAuthority().equals("webview")) {

                                                 //  步骤3：
                                                  // 执行JS所需要调用的逻辑
                                                  System.out.println("js调用了Android的方法");
                                                  // 可以在协议上带有参数并传递到Android上
                                                  HashMap<String, String> params = new HashMap<>();
                                                  Set<String> collection = uri.getQueryParameterNames();

                                              }

                                              return true;
                                          }
                                          return super.shouldOverrideUrlLoading(view, url);
                                      }
                                  }
        );
   }
```



#### 利用`WebChromeClient`回调接口的三个方法拦截消息

> 对相关的接口进行拦截，这里拦截的是 Js中的几个提示方法，也就是几种样式的对话框。

| Js中方法    | 作用       | 返回值                   | 对应拦截方法    |
| ----------- | ---------- | ------------------------ | --------------- |
| `alert()`   | 弹出警告框 | 没有                     | `onJsAlert()`   |
| `confirm()` | 弹出确认框 | true/false               | `onJsConfirm()` |
| `prompt()`  | 弹出输入框 | 任意设置返回值*输入内容* | `onJsPrompt()`  |

只有在`onJsPrompt()`中可以返回任意字段，可以在其中进行拦截判断，以调用对应方法。

## WebView执行漏洞

### 任意代码执行漏洞

#### WebView中的`addJavascriptInterface()`接口

> 当Js获取到这个对象后，就可以调用到该对象的所有方法，导致漏洞产生。



#### WebView内置导出的`searchBoxJavaBridge_`对象

> Android3.0以下 系统默认通过`searchBoxJavaBridge_`给WebView添加一个Js映射对象：`searchBoxJavaBridge_`对象

#### WebView内置导出的`accessibility`和`accessibilityTraversal`对象

### 密码明文存储漏洞

当WebView开启密码保存功能时导致漏洞`webView.setSavePassword(true)`，密码会被明文保存到`/data/data/com.package.name/databases/webview.db `中，有泄漏危险。

通过设置`webView.setSavePassword(false)`关闭密码保存提醒功能。

### 域控制不严格漏洞

A应用可以通过B应用导出的Activity让B应用家在一个恶意的file协议的url，从而获取到B应用的内部私有文件，带来数据泄露威胁。

对于不需要使用 file 协议的应用，禁用 file 协议；

```java
// 禁用 file 协议；
setAllowFileAccess(false); 
setAllowFileAccessFromFileURLs(false);
setAllowUniversalAccessFromFileURLs(false);
```

对于需要使用 file 协议的应用，禁止 file 协议加载 JavaScript。

```java
// 需要使用 file 协议
setAllowFileAccess(true); 
setAllowFileAccessFromFileURLs(false);
setAllowUniversalAccessFromFileURLs(false);

// 禁止 file 协议加载 JavaScript
if (url.startsWith("file://") {
    setJavaScriptEnabled(false);
} else {
    setJavaScriptEnabled(true);
}
```

## WebView优化

### WebView内存泄漏

**最好是可以去开启一个单独的进程去使用WebView并且当这个进程结束时，手动调用`System.exit(0)`**。

### 后台无法释放js导致耗电

在Js中可能会有一些动画或音频播放会一直执行，即时WebView挂在后台，这些资源也会继续使用，导致耗电加快。

```java
@Override
public void onResume(){
  super.onResume();
  webView.setJavascriptEnabled(true);
}

@Override
public void onStop(){
  super.onStop();
  webView.setJavascriptEnabled(false);
}
```

### `setBuiltInZoomControls`引起的Crash

当调用`setsetBuiltInZoomControls(true)`时去触摸屏幕，然后显示一个缩放控制图标，这图标几秒后会自动消失，这时去主动退出Activity，就会发生`ZoomButton`找不到依附Window导致异常使程序崩溃。

```java
@Override
public void onDestroy(){
  super.onDestroy();
  //手动进行隐藏，就不会导致崩溃了
  webView.setVisibility(View.GONE);
}
```



### 底部空白

当WebView嵌套在ScrollView里的时候，如果WebView先加载了一个高度很高的网页，再加载一个高度很低的网页，就会造成WebView的高度无法自适应，导致底部出现大量空白的情况。

通过JS注入的方式，获取页面内容的高度，获取到后赋值到WebView的高度上。

```java
mWebView.setWebViewClient(new WebViewClient() {
    @Override
    public void onPageFinished(WebView view, String url) {
        mWebView.loadUrl("javascript:App.resize(document.body.getBoundingClientRect().height)");
        super.onPageFinished(view, url);
    }
});
mWebView.addJavascriptInterface(this, "App");


@JavascriptInterface
public void resize(final float height) {
    getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
            //Toast.makeText(getActivity(), height + "", Toast.LENGTH_LONG).show();
            //此处的 layoutParmas 需要根据父控件类型进行区分，这里为了简单就不这么做了
            
            mWebView.setLayoutParams(new LinearLayout.LayoutParams(getResources().getDisplayMetrics().widthPixels, (int) (height * getResources().getDisplayMetrics().density)));
        }
    });
}
```



## WebView独立进程

> WebView容易导致OOM问题，内存占用很大，还容易有内存泄漏的风险
>
> 由于Android版本的不同，4.0之前用的WebKit的内核，4.0之后就换了 chromium做内核了，内核的不同导致兼容性Crash
>
> WebView和Native版本也不一致，导致Crash

多进程的好处：

- Android每个应用的内存占用是有限制的，占用内存越大越容易被杀死。实现多进程时，可有效减少主进程内存占用
- 子进程的崩溃不会影响到主进程的使用
- 独立的进程的启动与退出不依赖于用户的使用，可以完全独立控制，主进程的退出不影响其使用

//TODO 代码