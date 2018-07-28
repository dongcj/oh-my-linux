
# 编程原则

    幂等性：所有部署操作都要求可重复执行。
    正确性：所有部署操作需要最终的结果校验，也就是postcheck，通常用脚本来进行校验，且作为部署工作的必备步骤之一，在校验失败时，脚本退出码必须为非零。
    可追踪：所有部署操作必须有日志输出，在失败时可以被追踪。



# 目录功能

    bin:    启动脚本文件
    conf:   配置文件
    data:   虚拟机及软件
    doc:    文档
    lib:    库文件(函数文件)
    log:    日志文件
    run:    运行过程中产生的配置文件
    script: 维护脚本
    test:   性能测试文件
    tmp:    临时文件




# 已完成功能:

    > 自动化部署: 支持任意数量节点部署，自动检测MON, OSD，MDS等组件要求；可实现安装、卸载、扩容、升级
    > 自定义安装: 支持自定义主机名、自定全局磁盘设置、自定单主机磁盘设置、自定义Ceph集群名及集群端口
    > 磁盘自优化: 如有SSD则使用优化算法选择合适SSD做为journal disk和PRIMARY AFFINITY disk; 无SSD则使用"shareMode"
    > 存储自调优: 操作系统内核调优、CEPH架构优化、磁盘参数优化、primary affinity disk、XFS fragmentation
    > 存储自测试: 基于dd、fio的自动化存储性能测试跑分系统，针对不对配置不同负载进行跑分。
    > 其它优化点: 基于rack级别的自动化主机名、IP、自动分配；个性化安装方式与极简化配置


# 未完成功能：

    > 自动化部署: 支持断点续装功能
    > 自定义性能: 预置多场景配置文件，读多写少、读少写多、大小文件优化等、SSD cache自动cache等(未完成)
    > 网络高可用: 自动化修改网卡名、自动化网络Bonding、网络参数调优

    > 需要物理机上配置qemu-nbd功能, 以便于修改IP

    > 自动化测试：


        # 测试之前进行此项操作
        # First disable the write cache on the disk:
        $ sudo hdparm -W 0 /dev/hda 0

        # Disable the controller cache, assuming your controller is from HP, in slot 2 and your logical drive is the number 1:
        $ sudo hpacucli ctrl slot=2 modify dwc=disable
        $ sudo hpacucli controller slot=2 logicaldrive 1 modify arrayaccelerator=disable

        # Now you can start benchmarking your SSD correctly using two different methods. The FIO way:
        $ sudo fio --filename=/dev/sda --direct=1 --sync=1 --rw=write --bs=4k --numjobs=1 --iodepth=1 --runtime=60 --time_based --group_reporting --name=journal-test



# 部署

## 硬件要求
    部署服务器: 安装CentOS7操作系统, 支持KVM虚拟化，可使用任意服务器，确保网络和要部署的Ceph网络能连通即可
    Ceph服务器: 安装CentOS7操作系统, 部署为OSD节点的服务器至少需要一块单独的磁盘

## 部署流程
    1. 在部署服务器上部署安装虚拟机
    2. 进入安装虚拟机, 输入 ./Ceph_AI/bin/install
    3. enjoy
