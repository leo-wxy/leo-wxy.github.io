#!/bin/bash
beginTime=$(date "+%Y-%m-%d %H:%M")

git add .
git commit -m "MarkDown源文件更新 $begintime"
git push origin source