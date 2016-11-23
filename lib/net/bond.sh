#!/bin/bash

Bond_Remove() {
    [ ! -d /proc/net/bonding ] && return 0
    eval `cat /var/clone/cloneinfo  | awk -F__ '/ALROOM/ {print $1}'`
    if [ "${ALROOM}" = "yh" -o "${ALROOM}" = "dg" -o "${ALROOM}" = "xy2" ]; then
        source /var/clone/initrdconf.log
    source /etc/sysconfig/network-scripts/ifcfg-bond0
    sed -i -e '/MASTER=bond/d' -e '/SLAVE=yes/d' /etc/sysconfig/network-scripts/ifcfg-${ETHERNET}
    sed -i "3 iIPADDR=${IPADDR}" /etc/sysconfig/network-scripts/ifcfg-${ETHERNET}
    sed -i "3 iNETMASK=${NETMASK}" /etc/sysconfig/network-scripts/ifcfg-${ETHERNET}
    rm -f /etc/sysconfig/network-scripts/ifcfg-bond0
    rm -f /etc/sysconfig/network-scripts/ifcfg-eth1
    rm -f /etc/modprobe.d/bonding.conf
    rmmod bonding
    service network restart
    fi
}



is_10glink() {
    local dev=$1
    if [ -L /sys/class/net/$dev/device ] ; then
        if ethtool $dev | grep Port | grep -q FIBRE ; then
            return 0
        else
            return 1
        fi
    else
        return 2
    fi
}


function set_ifcfg_eth() {
>/etc/sysconfig/network-scripts/ifcfg-$1
cat << EOF >> /etc/sysconfig/network-scripts/ifcfg-$1
DEVICE=$1
BOOTPROTO=none
TYPE="Ethernet"
ONBOOT=yes
MASTER=bond0
SLAVE=yes
ETHTOOL_OPTS="speed $3 duplex full autoneg on"
RX_MAX=\`ethtool -g "\$DEVICE" | grep 'Pre-set' -A1 | awk '/RX/{print \$2}'\`
RX_CURRENT=\`ethtool -g "\$DEVICE" | grep "Current" -A1 | awk '/RX/{print \$2}'\`
[[ "\$RX_CURRENT" -lt "\$RX_MAX" ]] && ethtool -G "\$DEVICE" rx "\$RX_MAX"

EOF
}



udev70file="/etc/udev/rules.d/70-persistent-net.rules"
modprobe -r ixgbevf
ifconfig -a|grep Ethernet|awk '{print $1" "$NF}' >tmp.ifconfig
if [  -f /etc/sysconfig/network-scripts/ifcfg-bond0 ];then
	cat /proc/net/bonding/*|grep -E 'Slave Interface|Permanent HW addr'|awk '{print $NF}' >tmp.bonding
	for cur_netdev in `grep -v : tmp.bonding`;do
	  ifconfig_mac=`grep $cur_netdev tmp.ifconfig|awk '{print $NF}'`
	  real_mac=`grep $cur_netdev tmp.bonding -A 1|tail -1`	  
	  echo "sed -i 's/"${cur_netdev} ${ifconfig_mac}"/"${cur_netdev} ${real_mac}"/' tmp.ifconfig"|sh
	done
fi
netdev=`ifconfig -a|grep Ethernet|awk '{print $1}'`
for s in $netdev;do ifconfig $s up;done
for s in $netdev;do echo `ethtool -i $s 2>/dev/null|grep bus-info|awk -F: '{print $3":"$4}'` $s;done>tmp.ethtool-pciid
for s in $netdev;do echo `ethtool  $s 2>/dev/null|grep Speed|awk -F: '{print $2}'` $s;done|sort>tmp.ethtool-speed
lspci|grep Ethernet|grep -ivE '82599EB|SFI|SFP|Virtual|X540-AT2' |awk '{print $1}'|sort>tmp.lspci-1GB
lspci|grep -iE '82599EB|SFI|SFP|X540-AT2'|awk '{print $1}'|sort>tmp.lspci-10GB

>${udev70file}
rm -f /etc/sysconfig/network-scripts/ifcfg-eth* /etc/sysconfig/network-scripts/route-eth*


new_netdev_num=0
grep -q 10000Mb tmp.ethtool-speed && new_netdev_num=4
for pciid in `cat tmp.lspci-1GB|head -4`;do
  cur_netdev=`grep $pciid tmp.ethtool-pciid|awk '{print $2}'`
  [ -z $cur_netdev ] && continue
  netdev_mac=`grep $cur_netdev tmp.ifconfig|awk '{print $2}'|tr '[A-Z]' '[a-z]'`
  
  echo SUBSYSTEM==\"net\", ACTION==\"add\", SYSFS\{address\}==\"${netdev_mac}\", SYSFS{type}==\"1\", KERNEL==\"eth*\", NAME=\"eth${new_netdev_num}\", DRIVER==\"bnx2\|igb\|igb_new\|ixgbe\|tg3\" >>${udev70file}

	if ! grep -q 10000Mb tmp.ethtool-speed ;then
  	grep 1000Mb tmp.ethtool-speed|grep -q $cur_netdev && set_ifcfg_eth eth${new_netdev_num} ${netdev_mac} 1000
  	[ `grep 1000Mb tmp.ethtool-speed|wc -l` -lt 2 ] && set_ifcfg_eth eth${new_netdev_num} ${netdev_mac} 1000
	fi
  ((new_netdev_num++))
done

new_netdev_num=4
grep -q 10000Mb tmp.ethtool-speed && new_netdev_num=0

for pciid in `cat tmp.lspci-10GB|head -4`;do
  cur_netdev=`grep $pciid tmp.ethtool-pciid|awk '{print $2}'`
  [ -z $cur_netdev ] && continue
  netdev_mac=`grep $cur_netdev tmp.ifconfig|awk '{print $2}'|tr '[A-Z]' '[a-z]'`

  echo SUBSYSTEM==\"net\", ACTION==\"add\", SYSFS\{address\}==\"${netdev_mac}\", SYSFS{type}==\"1\", KERNEL==\"eth*\", NAME=\"eth${new_netdev_num}\", DRIVER==\"bnx2\|igb\|igb_new\|ixgbe\|tg3\" >>${udev70file}

	if grep -q 10000Mb tmp.ethtool-speed ;then
  	grep 10000Mb tmp.ethtool-speed|grep -q $cur_netdev && set_ifcfg_eth eth${new_netdev_num} ${netdev_mac} 10000
  	[ `grep 10000Mb tmp.ethtool-speed|wc -l` -lt 2 ] && set_ifcfg_eth eth${new_netdev_num} ${netdev_mac} 10000
	fi
  ((new_netdev_num++))
done


#update ifcfg-bond0 route-bond0
if [ ! -f /etc/sysconfig/network-scripts/ifcfg-bond0 ];then

  echo "alias bond0 bonding" > /etc/modprobe.d/bonding.conf
  
  ipaddr=`ifconfig|grep "inet addr"|grep -v 127.0.0.1|awk '{print $2}'|awk -F: '{print $2}'`
  netmask=`ifconfig|grep "inet addr"|grep -v 127.0.0.1|awk -F: '{print $NF}'`
  cat << EOF >> /etc/sysconfig/network-scripts/ifcfg-bond0
DEVICE=bond0
BOOTPROTO=static
TYPE="ethernet"
IPADDR=${ipaddr}
NETMASK=${netmask}
ONBOOT=yes
USERCTL=no
PEERDNS=no
BONDING_OPTS="miimon=100 mode=4 xmit_hash_policy=layer3+4"
EOF

net_list=( \
"10.0.0.0/8" \
"172.16.0.0/12" \
"192.168.0.0/16" \
"100.64.0.0/10" \
)
gw_ip=`ip route | sed -n 's/.*via \(.*\) dev.*/\1/p' | head -1`
for net in ${net_list[*]};do
    ip route add ${net} via ${gw_ip} dev bond0
    cat << EOF >> /etc/sysconfig/network-scripts/route-bond0
${net} via ${gw_ip} dev bond0
EOF
done

fi

rm -f tmp.*







