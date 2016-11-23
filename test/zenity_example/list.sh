#!/bin/sh

zenity --list \
  --title="选择您想查看的 Bugs" \
  --column="Bug 编号" --column="严重" --column="描述" \
    992383 Normal "多选时 GtkTreeView 崩溃" \
    293823 High "GNOME 字典不能使用代理" \
    393823 Critical "菜单编辑器在 GNOME 2.0 中不能运行"
