---
title: Android9.0源码编译记录
typora-root-url: ../
date: 2020-11-11 10:51:14
tags: 源码
top: 9
---

> 下述操作系统均为 **Manjaro 20.02**。编译源码版本为**Android 9.0**. 内核版本为**goldfish-4.14**

## Android源码编译

### 下载源码



### 编译配置

```shell
#在ArchLinux下需要主动配置

export LC_ALL=C

#在 /usr/lib/locale 目录下生成C.UTF-8文件夹
locale_gen


#在Ubuntu下 不需要执行改操作
```



### 编译环境

#### ArchLinux

```shell
# 在ArchLinux下的配置
sudo pacman -S jdk8-openjdk

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk

sudo pacman -S aosp-devel # 自动安装源码编译所依赖的库
```

#### Ubuntu18.04

```shell
# 在Ubuntu下配置
sudo add-apt-repository ppa:openjdk-r/ppa
sudo apt-get update
sudo apt-get install openjdk-8-jdk

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

sudo apt-get install git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses5-dev:i386 x11proto-core-dev libx11-dev:i386 libreadline6-dev:i386  libgl1-mesa-dev g++-multilib tofrodos python-markdown libxml2-utils xsltproc zlib1g-dev:i386 dpkg-dev

```



### 编译过程

#### ArchLinux

```shell
# 进入Android源码目录
cd /source

#设置python虚拟环境
virtualenv2 --system-site-packages venv
source venv/bin/activate

#此时在 (venv) 下继续执行编译流程
# 开始编译
source build/envsetup.sh

# 选择平台
lunch 
# 一般选择 aosp_x86-eng

#开始编译 根据CPU配置而定
make -j16 
```



#### Ubuntu

```shell
# 进入Android源码目录
cd /source

# 开始编译
source build/envsetup.sh

# 选择平台
lunch 
# 一般选择 aosp_x86-eng

#开始编译 根据CPU配置而定
make -j16
```

### 启动虚拟机

#### ArchLinux

```shell
# 编译完成后
emulator
```

#### Ubuntu

```shell
#第一次启动时可能会遇到KVM异常
Please ensure KVM is properly installed and usable.
CPU acceleration status: This user doesn't have permissions to use KVM (/dev/kvm)

# 或者如下异常


#需要使用如下解决方案 参考 https://blog.csdn.net/csusunxgg/article/details/81060890
#（1）安装 Qemu-KVM 和 cpu-checker

sudo apt-get install qemu-kvm cpu-checker
#（2）查看系统 KVM 是否可用

$ kvm-ok
  INFO: /dev/kvm exists
  KVM acceleration can be used
#（3）创建 kvm 用户组并把当前登录用户（如 king ）添加到 kvm 用户组

sudo addgroup kvm
sudo usermod -a -G kvm king
#（4）改变 /dev/kvm 用户组为 kvm

sudo chgrp kvm /dev/kvm
#（5）创建 udev rule，并写入 KERNEL=="kvm", GROUP="kvm", MODE="0660"

sudo gedit /etc/udev/rules.d/60-qemu-kvm.rules
KERNEL=="kvm", GROUP="kvm", MODE="0660"
#（6）重启电脑再运行 emulator


#电脑重启后，继续执行
emulator
```

## 内核编译

### 下载源码

```shell
mkdir kernel
# 下面镜像任选其一
# Android原始镜像 自己想办法下
git clone https://android.googlesource.com/kernel/goldfish.git
```

### 编译源码

```shell
cd goldfish

# 列出当前支持的分支
git branch -a 

# 查询当前虚拟机的内核版本为4.4
git checkout remotes/origin/android-goldfish-4.4-dev
```

分支切换完成后，需要实现一个编译脚本

```shell
# 命名为build.sh 放于goldfish目录下

#指定编译平台 上一步编译的虚拟机为 x86
export ARCH=x86
#指定的gcc编译器的前缀, 就是下面PATH中的x86_64-linux-android-4.9的前缀
export CROSS_COMPILE=x86_64-linux-android-
export REAL_CROSS_COMPILE=x86_64-linux-android-
#这里android_root要写是android根目录的绝对地址例如: ~/google/android-9.0
PATH=$PATH:android_root/prebuilts/gcc/linux-x86/x86/x86_64-linux-android-4.9/bin
#编译的配置,在arch/x86/configs目录下,
make x86_64_ranchu_defconfig
#编译内核命令
make

```

执行`./build.sh`开始编译

编译完成后会生成一个文件在`arch/x86/boot/bzImage`



### 启动虚拟机(设置内核)

```shell
emulator -kernel kernel/goldfish/arch/x86/boot/bzImage
```



## 虚拟机相关



## Native Debug 调试Android源码



## 内核Debug





## 其他异常记录

问题记录:

Android Studio “/dev/kvm device: permission denied”

解决方案:
https://blog.csdn.net/firestart/article/details/80527672

zhenghuan@zhenghuan-MS-7B53:~$ sudo chown zhenghuan -R /dev/kvm

## 参考链接

[Arch Wiki](https://wiki.archlinux.org/index.php/android#Building_the_code)

