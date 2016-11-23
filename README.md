
# 目录功能

    bin:    启动脚本文件
    conf:   配置文件
    data:   虚拟机及软件
    doc:    文档
    lib:    库文件(函数文件)
    log:    日志文件
    run:    运行过程中产生的配置文件
    script: 维护脚本
    test:   测试文件
    tmp:    临时文件




# 已完成功能:

    > 自动化部署: 支持任意数量节点部署，自动检测MON, OSD，MDS等组件要求；可实现安装、卸载、扩容、升级
    > 自定义安装: 支持自定义主机名、自定全局磁盘设置、自定单主机磁盘设置、自定义Ceph集群名及集群端口
    > 磁盘自优化: 如有SSD则使用优化算法选择合适SSD做为journal disk和PRIMARY AFFINITY disk; 无SSD则使用"shareMode"
    > 存储自调优: 操作系统内核调优、CEPH架构优化、磁盘参数优化、primary affinity disk、XFS fragmentation
    > 其它优化点: 基于rack级别的自动化主机名、IP、自动分配；个性化安装方式与极简化配置
    
    
# 未完成功能：
    > 自动化部署: 支持断点续装功能
    > 自定义性能: 预置多场景配置文件，读多写少、读少写多、大小文件优化等、SSD cache自动cache等(未完成)
    > 网络高可用: 自动化修改网卡名、自动化网络Bonding、网络参数调优
    > 存储自测试: 基于dd、fio的自动化存储性能测试跑分系统，针对不对配置不同负载进行跑分。
    


# 部署

## 硬件要求
    部署服务器: 支持KVM虚拟化即可，可使用任意服务器，确保网络和要部署的Ceph网络能连通即可
    Ceph服务器: 能安装CentOS7操作系统即可, 部署为OSD节点的服务器至少需要一块单独的磁盘
    
## 部署流程
    1. 在部署服务器上部署安装虚拟机
    2. 进入安装虚拟机, 输入/root/Ceph_AI/bin/install
    3. enjoy ~
