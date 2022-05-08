---
title: Android Study Plan VI
date: 2018-03-18 17:48:09
tags: Android
---
# Android学习计划
话题：关于Gradle的知识
1、如何理解Gradle？Grade在Android的构建过程中有什么作用？
2、实践如下问题。

问题：我们都知道，Android中时常需要发布渠道包，需要将渠道信息附加到apk中，然后在程序启动的时候读取渠道信息。
动态指定一个渠道号（比如1001），那么构建的apk中，请在它的AndroidManifest.xml文件里面的application节点下面添加如下meta-data，请写一段Gradle脚本来自动完成：
```xml
 <application android:allowBackup="false" android:supportsRtl="true">
        <meta-data android:name=“channel" android:value=“1001" />
</application>
```

要求：当通过如下命令来构建渠道包的时候，将渠道号自动添加到apk的manifest中。
./gradlew clean assembleRelease -P channel=1001

