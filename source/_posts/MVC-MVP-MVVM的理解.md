---
title: MVC,MVP,MVVM的理解 
date: 2018-04-15 14:58:03
tags: 设计模式
top: 10
---



{% fullimage /images/MVC+-+MVP+-MVVM简析.png,MVC、MVP、MVVM,MVC、MVP、MVVM%}

> 使用架构的目的是：**模块内部的高内聚，模块之间的低耦合。**

## 1.MVC模式

MVC(Model-View-Controller，模型-视图-控制器)是20世纪80年代出现的一种设计模式。他用一种业务逻辑、数据、界面显示分离的方法组织代码。在Android中MVC的角色定义如下：

- Model(模型层)：针对业务模型，建立的数据结构和相关的类，就可以理解为Model。与View无关，与业务相关。主要负责网络请求、数据库处理、I/O操作。

- View(视图层)：一般采用XML文件或者Java代码进行界面的描述。

- Controller(控制器)：Android的控制层一般在Activity，Fragment中或者在由他们控制的其他业务类中。

  {% fullimage /images/pattern/mvc_pattern.png, MVC,MVC %}

优点：

- 实现简单，不需要过于复杂的逻辑以及文件分层

缺点：

- 在Android开发中，Activity不是一个标准的Controller，首要职责为加载应用的布局和初始化界面，并接受用户的请求。随着界面以及代码逻辑的复杂，Activity会越来越庞大。

## 2.MVP模式

MVP(Model-View-Presenter)是MVC的演化版本，对于Android来说，Model层和MVC模式是一种概念，activity或者fragment对应的就是View层，所有用户相关事件处理由Presenter处理。使用Presenter进行解耦操作。

- Model：主要提供数据的存取功能。

- View：负责处理用户事件和视图部分的展示。在Android中可能是Activity、fragment或者View组件

- Presenter：作为View和Model沟通的桥梁，从Model层检索数据并返回给View层，使得View和Model层完全解耦。Presenter与View可以通过接口来实现通信，只要View层去实现定义好的接口。

  {% fullimage /images/pattern/mvp_pattern.png, MVP,MVP %}

优点：

- View与Model完全分离，修改不会互相影响逻辑
- Presenter可以进行复用，应用于多个View上
- 可以预先定义好Presenter，方便理解结构

缺点：

- View层和Presenter层会交互过于频繁，若Presenter过多的渲染了View，往往导致过于紧密，若View发生改动，Presenter也要发生变更。
- 随着业务的复杂，Presenter的接口会越来越多，有其他的View引用到该Presenter时，也要去实现这些接口


## 3.MVVM模式

MVVM(Model-View-ViewModel)是2015由微软提出的一个UI架构概念。将Presenter改为ViewModel，同时实现View和ViewModel的双向绑定（View的变动，自动反映在ViewModel，反之亦然）。

- Model：主要提供数据的存储过程

- View：负责处理用户事件和视图部分的展示。在Android中可能是Activity、fragment或者View组件

- ViewModel：功能和Presenter类似，与View和Model双向绑定。只做业务逻辑与业务数据相关的事，内部不持有任何View，也不会引用View中的控件进行UI更新。

  {% fullimage /images/pattern/mvvm_pattern.png, MVVM,MVVM %}

优点：

- 低耦合。View可以独立于Model变化和修改，ViewModel可以绑定不同的View
- 可重用性。把许多的试图逻辑处理放在一个ViewModel中，许多View可以使用该ViewModel
- 独立开发。开发人员可以专注于逻辑和数据的处理
- 可测试性。可以直接针对ViewModel进行单独测试。

缺点：

- 使得Bug很难调试，由于View和Model的双向绑定

> 可以使用Google官方提供的 `LiveData、ViewModel`去实现这套模式。

## 4.如何进行选择

1. 如果项目简单，没什么复杂性，可以使用MVC架构，注意好封装各模块。
2. 对于偏向展示型的App，业务逻辑多在后端实现，可以使用MVVM。
3. 对于业务逻辑复杂且量级比较大的，推荐使用MVVM。