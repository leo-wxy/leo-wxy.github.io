---
title: Gradle操作小记
date: 2018-04-03 16:24:22
tags: Gradle
---

> 显示所有依赖关系解析树
```gradle
./gradlew app:dependencies
```

> 生成项目
```gradle
./gradlew clean assembleEnvTestReleaseChannels -PchannelList=default
```
> 清理项目

```groovy
./gradlew clean
```

> api与implementation的区别
`api`：完全等同于原先的`compile`指令，使用了该命令编译的依赖项目，其他项目依赖于该项目时也可以使用该命令编译的依赖项目。
`implementation`：使用了该命令编译的依赖项目，其他项目依赖于该项目时无法使用该命令编译的依赖项目。即该依赖是隐藏在项目内部的，不会对外开放。

```groovy
./gradlew build --refresh-dependencies
```

