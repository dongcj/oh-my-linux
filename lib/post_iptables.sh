#!/bin/sh
# COPYRIGHT BY dongchaojun@gmail.com
# This script set the security iptables rule.
# Version: 0.6
# CTIME: 2012/08/17
# MTIME: 2018/10/17

IPT=/sbin/iptables
SYSCTL=/sbin/sysctl

# Internet interface, strict zone
# for natted network, ext interface usually the same as lan interface.
# use space to separate, null to ignore
EXT_IF="ens160"

# Lan interface, less security 
# use space to separate, null to ignore
LAN_IF="ens160"

# Fully accessable interface that the be skipped iptables rule.
# if you want to fully open one interface, 
# you can add the lan interface to the following private interface.
# use space to separate, null to ignore
PRIVATE_IF=tun0   

### Set local ssh / web service port
SSH_PORT="22 46178"
WEB_PORT="80 443"

### Set other ports enable. must add protol like tcp or udp
ENABLE_PORTS="1149/tcp"

### Block RFC 1918 private address space range ###
### Block reserved Class D and E IP  ###
### Block the unallocated address range et all ###
SPOOFD_IP="127.0.0.0/8 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8 \
  169.254.0.0/16 0.0.0.0/8 240.0.0.0/4 255.255.255.255/32 \
  168.254.0.0/16 224.0.0.0/4 240.0.0.0/5 248.0.0.0/5 192.0.2.0/24"

# load modules
modules="ip_tables iptable_nat ip_nat_ftp ip_nat_irc \
  ip_conntrack ip_conntrack_ftp ip_conntrack_irc"
  
for mod in $modules; do
    testmod=`lsmod | grep "^${mod} " | awk '{print $1}'`
    if [ "$testmod" == "" ]; then
          modprobe $mod
    fi
done
 
### Clean out old rule
$IPT -F
$IPT -X
$IPT -Z
$IPT -t nat -F
$IPT -t nat -X
$IPT -t nat -Z
$IPT -t mangle -F
$IPT -t mangle -X
$IPT -t mangle -Z


### Block out eveything but input ###
$IPT -P INPUT   DROP
$IPT -P OUTPUT  ACCEPT
$IPT -P FORWARD ACCEPT

### Allow full access to loopback
$IPT -A INPUT -i lo -j ACCEPT

### Enable the icmp of all interfaces
$IPT -A INPUT -p icmp -j ACCEPT

### Allow full access to $PRIVATE_IF
for i in $PRIVATE_IF; do
    $IPT -A INPUT  -i ${PRIVATE_IF} -j ACCEPT
done

# The follow rule will accept the RELATED & ESTABLISHED incoming paceage; 
$IPT -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

### Enable local web server port
for i in $WEB_PORT; do
    $IPT -A INPUT -p TCP --dport $i  --sport 1024:65534 -j ACCEPT
done

### Enable port
for i in $ENABLE_PORTS; do
    port=${i%%/*}
    portocal=${i/\/*/}
    # lower case
    portocal=${portocal,,}
    
    # default tcp protocal
    if [ "$portocal" != "tcp" ] && [ "$portocal" != "udp" ]; then
        portocal=tcp
    fi
    
    $IPT -A INPUT -p $portocal --dport $port -j ACCEPT
done

### Enable sshd server port ###
for i in $SSH_PORT; do 
    $IPT -A INPUT -p TCP --dport $i --sport 1024:65534 -j ACCEPT # SSH
done

### External SMTP Rules ###
# if [ -n "$SMTP_SERVER_IP" ]; then
    # $IPT -A INPUT -i ${EXT_IF} -p tcp --dport ${SMTP_PORT} -m state --state NEW,ESTABLISHED - j ACCEPT
    # $IPT -A OUTPUT -o ${EXT_IF} -p tcp --sport ${SMTP_PORT} -m state --state NEW,ESTABLISHED -j ACCEPT
     
    # ### Internal SMTP Rules ###
    # $IPT -A INPUT -i ${LAN_IF} -p tcp -s ${SMTP_SERVER} --sport ${SMTP_PORT} -m state --state NEW,ESTABLISHED -j ACCEPT
    # $IPT -A OUTPUT -o ${LAN_IF} -p tcp -d ${SMTP_SERVER} --dport ${SMTP_PORT} -m state --state NEW,ESTABLISHED -j ACCEPT
# fi



# DNS Server
#$IPT -A INPUT -i ${EXT_IF} -p udp --dport ${DNS_PORT} -m state --state  NEW,ESTABLISHED -j ACCEPT
#$IPT -A INPUT -i ${EXT_IF} -p tcp --dport ${DNS_PORT} -m state --state  NEW,ESTABLISHED -j ACCEPT


### 限制单个地址/单个 C 类的并发连接数量 ###
# $IPT -A INPUT -p tcp --dport 80 --tcp-flags FIN,SYN,RST,ACK SYN -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT
# $IPT -A INPUT -p tcp --dport 80 --tcp-flags FIN,SYN,RST,ACK SYN -m connlimit --connlimit-above 50 --connlimit-mask 24 -j REJECT
# ### 限制并发连接数不大于 50 ###
# $IPT -I INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 -j DROP
# ### 限制并发ACK不大于 50 ###
# $IPT -A INPUT -p tcp --dport 80 --tcp-flags FIN,SYN,RST,ACK ACK -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT
# $IPT -A INPUT -p tcp --dport 80 --tcp-flags FIN,SYN,RST,ACK ACK -m recent --set --name drop
# ### 限制单位时间内的连接数 ###
# $IPT -A INPUT -p tcp --dport 80 -m --state --state NEW -m recent --set --name access --resource
# $IPT -A INPUT -p tcp --dport 80 -m --state --state NEW -m recent --update --seconds 60 --hitcount 30 --name access -j DROP


### Log ###
$IPT -A INPUT -m state --state INVALID -j LOG --log-prefix " INVAID DROP "
$IPT -A INPUT -m state --state INVALID -j DROP
 
$IPT -A INPUT -j LOG --log-prefix " INPUT DROP "


########################### NAT Rule ############################

### Init the nat rule;
#$IPT -F -t nat
#$IPT -X -t nat
#$IPT -Z -t nat
#$IPT -t nat -P PREROUTING  ACCEPT
#$IPT -t nat -P POSTROUTING ACCEPT
#$IPT -t nat -P OUTPUT      ACCEPT

### NAT
# 1. iptables -t nat -A PREROUTING -d $EXT_SUBNET -p tcp -m tcp --dport 9336 -j DNAT --to-destination 10.160.44.189:3389

# 2. iptables -t nat -A POSTROUTING -d 10.160.44.189/32 -p tcp -m tcp --dport 3389 -j SNAT --to-source 42.120.74.5
 
# otherwize, 2 can be use MASQUERADE instead of SNAT
# iptables -t nat -A POSTROUTING -j MASQUERADE

### Save the rule above
echo "Saving the rules to /etc/scripts."
mkdir -p /etc/scripts
iptables-save >/etc/scripts/iptable-save.`date +%Y%m%d`
iptables-save >/etc/scripts/iptable-save.latest

echo "Success! "


