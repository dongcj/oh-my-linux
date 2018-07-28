# 所有的密码区域全用base64或者使用openssl用指定密码进行加密
echo "dongcj" | base64				--- 使用base64 encode
ZG9uZ2NqCg==
# 解密 
echo "ZG9uZ2NqCg==" | base64 --decode		--- 使用base64 decode


# 后台整体框架名：krrish


# 网络
   |
   |	 上联外网
   |
———————— 中联虚机 
   |
   |	 下联存储
   |

### IP分配策略
  OPS区域分配末位小于149
  其他区域末位小于199
  网关固定247
  
### Vlan划分


### 网卡与桥接

VGW网络（上联）：
  eth0(千兆)  + eth1(千兆) <--> bond0 <--> VGW（每台Hyper上运行） <---转发 中联/下联 数据---> 

EGW网络（中联，使用C或B类IP）：
  eth0(万兆)  + eth1(万兆) <--> bond1 <--> EGW（每台Hyper上br0） <--> VGW

DGW网络（下联，使用B类IP）：
  eth2(万兆)  + eth3(万兆) <--> bond2 <--> DGW <--> VGW

OGW网络（带外）：
  IPMI管理口 <--> bond1 <--> OGW
  
Spare网络 ？？？？



# 各种不同功能节点配置
OPS区：
KS区：
Hyper区：分为ECS、DFS
SPAR区：


# 实例运行img存放和高可用， 结合青云和阿里云方案，采用SSD + SATA方案：

  采用一块SSD:
	分区1挂载至/安装操作系统
	分区2挂载至/cache做为ECS区的数据缓冲（是单块sas盘还是直接做sata+缓冲?，缓冲方案需验证性能。）
	分区3挂载至/swap
	
	mkdir -p /etc/dxcloud/
	mkdir -p /etc/init.d/dxcloud
	mkdir -p /home/dxcloud
	mkdir -p /var/lock/dxcloud 
	mkdir -p /var/run/dxcloud
	mkidr -p /var/log/dxcloud
	mkidr -p /var/www/dxcloud
	mkidr -p /etc/yum.repos.d/dxcloud
	
  mkdir -p /opt/dxcloud/krrish/baseimage/     (由rohit 同步至 krrrish)
	mkdir -p /opt/dxcloud/krrish/vmfile/       (存放images、vmcontainer、vmswap、vmxml等)
	mkdir -p /opt/dxcloud/krrish/snapshot/
	
  mkdir -p /opt/dxcloud/rohit/metadata
  mkdir -p /opt/dxcloud/rohit/dfsdata/imgrepo/

  
	mount /dev/sd[b-z] /mnt/sd[b-z]

  安装操作系统(vg-root: 100g, vg-swap: =MEM_SIZE, vg-srl: File or block cache)

                  |--> /dev/sdb1 放虚拟机container; 
  Write-->vg-srl--| 
                  |--> /dev/sdb2 做为分布式文件系统的存储设备；

  
  /dev/sdb1 和 /dev/sdb2 进行文件级别同步，只同步增量文件，虚机的backend file(镜像)不用同步 

  示例目录结构如下
    drwxr-xr-x  4 root root 4096 Oct 17 14:29 conf
    drwxr-xr-x  4 root root   28 Oct 17 14:29 hyper
    drwxr-xr-x  2 root root    6 Oct 17 14:30 notifier
    drwxr-xr-x  2 root root    6 Oct 17 14:30 template
    drwxr-xr-x 11 root root  132 Oct 17 14:30 data	 (存放images、vmcontainer、vmswap、vmxml等)
    drwxr-xr-x  2 root root 4096 Oct 17 14:30 log
    drwxrwxr-x  5 yop  yop   102 Oct 17 14:30 lib
    lrwxrwxrwx  1 root root   31 Oct 20 11:44 snapshot -> /pitrix/data/container/snapshot
    drwxr-xr-x  2 root root    6 Oct 21 01:24 mnt
    drwxr-xr-x  2 root root 4096 Oct 21 01:24 tmp
    drwxr-xr-x  2 root root   59 Oct 21 01:34 run
    drwxr-xr-x  2 root root  151 Oct 21 02:39 lock
    drwxr-xr-x  2 root root 4096 Oct 21 09:35 bin



# 实例所在物理机宕机后，在spare pool中进行实例的启动：
  hyper <=10    	sparePool = 1
  10 < hyper <= 50	sparePool = 3
  hyper > 50		sparePool = 5
  为奇数是为了进行选举Leader


# 分布式文件系统
  1. 存放虚拟文件备份，当某台hyper宕机后，实例会在spare pool中的服务器上启动，实例文件是存放在分布式系统上的。
  2. 存放镜像(当虚机启动在一个没有拷贝镜像的hyper上时，可以先启动实例，再后台异步同步镜像，再将实例磁盘link到新的backend)
  3. 采用容量型磁盘


# 实例的高可用
  物理机宕机后，实例运行到spare pool中
  物理机修复后，实例"在线迁移"回物理机
  	1. 后台检测到物理机心跳不可达，(3次*6秒 检测) 这个可以用分布式自带的的监控来做
	2. 后台数据库中更新物理机状态信息为"disk error"或"offline"
	3. 找一台spare pool中的服务器spare tempserver做为接管服务器
	4. 更新spare 数据库中的spare server信息中的"active"为true
	4. spare server接到命令后，挂载DFS盘，启动虚机
	5. 物理服务器恢复后，


# 监控

  Monitor服务在OPS中，它主要功能有：
    在hyper上进行上、中、下联的总体流量监控
      KS区
      ECS区
      DFS区
      SPARE区


# 自动化
  可以使用qemu-nbd或是挂载临时盘的方式将相关的文件输送给客户（这二种方式需要重新启动吗？）
  每个虚拟机和管控平台之前都是通过sap进行通讯
  虚机内有个agent，可以提供给客户：
	 自动建立虚拟机之间的信任关系
	 进行devOps相关操作（类似fit2cloud）
	 自动化安装软件
	 修改密码  -- 这个只提供给超级管理员
  
  虚机内默认安装好以下软件：
	ntp
	iptables
	
	
# 虚机的管理维护
  统一使用qemu-nbd进行虚拟机内、外部维护
  
# Test
   1. create vm with basic network
      1. join network
      2. leave network
      3. attach volume
      4. detach volume
      5. reboot vm
      6. create snap from vm
      7. reset vm
      8. capture vm to image
      9. create alias domain name
      10. assicate alias name to vm
      11. ping alias-name
  2. network
     1. create router
     2. create vxnet
     3. join the vxnet to router
     4. launch vm with vxnet
  3. EIP
     1. create internet EIP
     2. create externet EIP
     3. assicate in-EIP to vm
     4. assicate ex-EIP to vm
  4. loadblancer
     1. create externel lb
        1. create listener
        2. add backend to lb
     2. create internel lb
        1. creat listener
        2. add backend to lb
   5. rdb/cache
   6. mongodb

