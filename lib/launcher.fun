#!/usr/bin/env bash

# 作用：显示欢迎信息，及版本信息
# 使用方法：Show_Welcome
######################################################################
Show_Welcome() {

    # cat the version file
    cat ${LIB_DIR}/version
    cat ${LIB_DIR}/copyright
    sleep 2
    clear

}





# 作用：跳到上次安装的脚本
# 使用方法：StraightInto_Last_Install
######################################################################
StraightInto_Last_Install() {
    # if has the .run file
    runfile=`ls ${RUN_DIR} | grep .*.run`
    # 如果有runfile, 则证明有异常退出的情况
    if [ $? -eq 0 ]; then
        # get the runname
        runname=${runfile%.run}
        # 如果runname可以在launcher中找到
        lastrun=`grep "^\[" ${CONF_DIR}/${LAUNCHER} | tr -d "[]" | grep -w $runname`
        if [ $? -eq 0 ] ; then
            log $0 "Found last install to $lastrun, continue install..."
            sleep 1
            if [ -f ${BIN_DIR}/${runname}.sh ]; then
                exec ${BIN_DIR}/${runname}.sh
            else
                exec ${SCRIPT_DIR}/${runname}.sh
            fi
            return 2
        
        # 如果找不到
        else
            # 删除.run file后退出
            rm -rf ${RUN_DIR}/$runfile
            return 0
        fi
    fi

}










# 作用：输入Chapter, 输出所属的functions
# 使用方法：Get_Functions_From_Chapter <CHAPTERNAME>
# 注意：
######################################################################
Get_Functions_From_Chapter() {
    if [ "$#" -ne 1 ]; then
        echo -e "   Function Get_Functions_From_Chapter() error! Usage: Get_Functions_From_Chapter <$CHAPTERNAME>\n"
        $EXIT 250
    fi

    chaptername=$1
    
    # if the Chapter not in 
    
    
}







# 作用：主启动器
# 使用方法：Start_Launcher
# 注意:
######################################################################
Start_Launcher() {

    # 首先循环chapter, 
    
    
    
        # 循环func
        
    # 打印 Launcher Tree
    :
    
    # 实例化 Launcher Tree

}





# 作用：按Launcher中的顺序执行脚本, launcher_disable中的项目将被过滤
# 使用方法：Start_Launcher $0
######################################################################

Start_DaemonLauncher() {

    # 获得所有要运行的脚本列表
    
    # 去掉disable中脚本
    
    # 去掉当前正在运行的脚本
    
    
    # 检查所有要运行的脚本是否存在
    
    # 检查是否要运行，如果要运行，就调用timeout进行运行
    
    

    :
}










