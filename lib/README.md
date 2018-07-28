# 规则
    如果是INI类型的配置文件, 后缀为 .ini
    如果是shell类型的配置文件，后缀为 .conf
    如果是yaml类型的配置文件，后缀为 .yaml



# 更新记录
    2016-09-09: 去掉了exitcode, returncode, infocode, 因为使用它们使脚本失去了灵活性
        替代方案：用一个Log函数

   