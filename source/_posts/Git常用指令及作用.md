---
title: Git常用指令及作用(速查)
date: 2019-12-06 13:13:52
tags: Git
top: 10
---

## log 
git log //显示提交信息
git log --oneline //简要日志输出
git log --oneline -5 //输出最近5次提交日志

## status
git status //显示当前git状态
git status -s //简要信息

git push origin HEAD:refs/for/master //推送代码

## tag
git tag //列举标签

git tag  version //给提交设置标签
git push origin ​version //推送设置标签的动作

## checkout
git checkout //切换分支
git checkout dev //切换本地分支
git checkout remote/master //切换远程分支
git checkout --track origin/master //基于远程分支创建本地分支并跟踪
git checkout -b dev //基于本地分支 创建新分支

## commit
git commit -m "XXX" //提交概要信息
git commit --amend //编辑提交信息
git commit --amend --no-edit //跳过编辑直接提交
git commit --no-verify -m "XXX" //跳过校验直接提交

## reset
git reset --hard commit_sha1 //丢弃回滚提交前的所有改动
git reset --soft commit_sha1 //回滚提交前的改动放回暂存区与工作区
git reset --mixed commit_sha1 //回滚提交前的改动放回工作区并清空暂存区

## revert
git revert commit-sha1 //回滚到某次提交

## rebase （慎用）
只对尚未推送的本地修改执行变基操作清理历史，从不对已推送至别处的提交执行变基操作。
git rebase 0i git-sha1|branch //进入交互变基模式

## merge 
git merge --ff branchName //合并分支并不创造新的commit节点

git merge --no-ff branchName //保留合并分支的提交记录

## pull

git pull //拉取代码

## push

git push origin HEAD:refs/for/BranchName //推送远程分支

git push -d origin BranchName //删除远程分支

git push -f origin BranchName //强制推送远程分支

git push --force-with-lease //远程分支与本地保持一致时，推送成功，否则失败

## remote

> 维护多个仓库源使用

git remote add origin url //关联远程仓库



## branch

> 操作分支命令

git branch //列举远程分支 

git branch -a //列举所有分支 包括本地分支

上述结果中 `*`表示当前使用分支

git branch -c [oldBranchName] branchName //复制分支

git branch -C [oldBranchName] branchName //强制复制分支

git branch -m [oldBranchName] branchName //移动分支

git branch -M [oldBranchName] branchName //强制移动分支

git branch -d branchName //删除分支

git branch -D branchName //强制删除分支



## stash

> 暂存当前修改的代码 **每次暂存的时候 设置一下描述信息**

git stash push -m “XX” //暂存文件并设置描述信息

git stash apply stash@{0} //使用但保留暂存记录

git stash pop stash@{0} //使用并删除暂存记录

git stash list //列举暂存记录

git stash drop stash@{0} //丢弃指定暂存记录

git stash show stash@{0} //查看指定暂存记录修改内容



## reflog

> 记录所有git操作行为

git reflog -5 //打印最近5次操作



## cherry-pick

> 从其他分支选择需要的commit合并到一个分支中

git cherry-pick commit-sha1 //合并其他分支的提交

git cherry-pick commit-sha1 commit-sha2 //合并多个提交

git cherry-pick startCommit-sha1…endCommitSha1 //按照提交区间进行合并

git cherry-pick (--continue | --skip | --abort | —quit) //后续的操作 继续合并｜跳过｜完全放弃恢复初始状态｜为冲突的合入，冲突的放弃

## rm（慎用）

> 移除版本控制中的文件

git rm —cache file_path //移除缓存中的索引



## diff

> 对提交记录进行比较



## add

> 添加工作目录中的文件到缓存区，缓存区中是需要提交的文件。

git add <file> //加入文件到缓存区

git add <dic> //加入目录到缓存区

git add -p //交互式加入文件

> 使用 `y` 缓存某一处更改，使用 `n` 忽略某一处更改，使用 `s` 将某一处分割成更小的几份，使用 `e` 手动编辑某一处更改，使用 `q` 退出编辑。

git add .

git add -A

> 上述两命令都表示 加入所有文件到缓存区 包括`New File(新增文件),Update File(有修改的文件),Deleted File(已删除文件)`

git add -u //只提交被修改和被删除的文件

## 附录



## 参考链接

[Git文档](https://git-scm.com/book/zh/v2)