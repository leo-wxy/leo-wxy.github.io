#!/bin/bash
git add .
git commit -m "MarkDown源文件更新"
git push origin source


hexo clean 
hexo g
hexo d
