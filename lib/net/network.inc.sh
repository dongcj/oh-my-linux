function _mark_fibre()
{
    devname=$1
    ethtool $devname | grep Port | grep FIBRE
    if [ $? -eq 0 ]; then
        echo "ip link set dev $devname up" >> /etc/rc.local.head

        # need to disable eip's rx checksuming, otherwise offload error will occur for Windows guests
        echo "ethtool -K $devname rx off lro off" >> /etc/rc.local.head

        if [ "x${feature_conntrack}" = "xon" ]; then
           echo "set_irq_affinity -x $devname" >> /etc/rc.local.head
        fi

        return
    fi
}

function _create_network()
{
    prefix=$1
    
    # no need to configure?
    varname=${prefix}_network_nocfg
    nocfg=${!varname}
    if [ "x$nocfg" = "xyes" ]; then
        return 0
    fi

    varname=${prefix}_network_interface
    interface=${!varname}
    varname=${prefix}_network_mac_addr
    mac_addr=${!varname}
    varname=${prefix}_network_address
    address=${!varname}
    varname=${prefix}_network_netmask
    netmask=${!varname}
    varname=${prefix}_network_hwaddr
    hwaddr=${!varname}
    varname=${prefix}_network_gateway
    gateway=${!varname}
    varname=${prefix}_network_internal_gateway
    internal_gateway=${!varname}
    varname=${prefix}_network_dns_servers
    dns_servers=${!varname}
    varname=${prefix}_network_gateway_policy_subnet
    gateway_policy_subnet=${!varname}
    varname=${prefix}_network_gateway_policy_id
    gateway_policy_id=${!varname}
    varname=${prefix}_network_gateway_policy_name
    gateway_policy_name=${!varname}
    varname=${prefix}_network_bridge_ports
    bridge_ports=${!varname}
    varname=${prefix}_network_routing_rule
    routing_rule=${!varname}
    varname=${prefix}_network_bond_interface
    bond_interface=${!varname}
    varname=${prefix}_network_bond_mode
    bond_mode=${!varname}
    varname=${prefix}_network_bond_slaves
    bond_slaves=${!varname}
    varname=${prefix}_network_vlan_raw_device
    vlan_raw_device=${!varname}

    iffile=/etc/network/interfaces
    # no ip address, no need to config 
    if [ "x$address" = "x" ]; then
        return 0 
    fi
    echo "" >> $iffile

    # config bond slaves
    if [ "x$bond_slaves" != "x" -a "x$bond_interface" != "x" ]; then
        IFS=',' read -a slaves <<< "$bond_slaves"
        for slave in "${slaves[@]}"
        do
            echo "auto $slave" >> $iffile 
            echo "iface $slave inet manual" >> $iffile 
            echo "bond-master $bond_interface" >> $iffile 
            echo "" >> $iffile

            _mark_fibre $slave
        done    
    fi

    # config bond interface
    if [ "x$bond_interface" != "x$interface" -a "x$bond_slaves" != "x" ]; then
        echo "auto $bond_interface" >> $iffile 
        echo "iface $bond_interface inet manual" >> $iffile 
        echo "bond-mode $bond_mode" >> $iffile
        echo "bond-miimon 100" >> $iffile 
        if [[ $bond_mode -eq 4 ]]; then
            echo "bond-lacp-rate 1" >> ${interfaces}
        fi
        echo "bond-slaves ${bond_slaves/,/ }" >> $iffile         
        echo "" >> $iffile
    fi

    # config vlan raw device
    if [ "x$vlan_raw_device" != "x" ]; then
        # don't config twice
        grep "iface $vlan_raw_device inet manual" $iffile >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "auto $vlan_raw_device" >> $iffile 
            echo "iface $vlan_raw_device inet manual" >> $iffile 
            echo "" >> $iffile

            _mark_fibre $vlan_raw_device
        fi
    fi

    # config bridge ports, for now only one port is allowed
    if [ "x$bridge_ports" != "x" -a "x$bridge_ports" != "xnone" -a "x$bridge_ports" != "x$bond_interface" ]; then
        echo "auto $bridge_ports" >> $iffile
        echo "iface $bridge_ports inet manual" >> $iffile
        echo "" >> $iffile

        _mark_fibre $bridge_ports
    fi

    # this is not a bridge, we have to make sure interface name exists
    if [ "x$bridge_ports" = "x" ]; then
       # test if this interface name is already valid
       ifconfig $interface >/dev/null 2>&1
       if [ $? -ne 0 ]; then
           # if interface not exits, may need to rename interface according to mac addr
           if [ "x$mac_addr" != "x" ]; then
               ifconfig -a | grep $mac_addr   
               if [ $? -ne 0 ]; then
                   log "invalid mac [$mac_addr]"
                   return 1
               fi
               
               # we have to rename the interface 
               oldname=`cat /etc/udev/rules.d/70-persistent-net.rules | grep $mac_addr | awk -F'NAME="' '{print $2}' | awk -F'"' '{print $1}'`
               if [ "x$oldname" = "x" ]; then
                   echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$mac_addr\", ATTR{dev_id}==\"0x0\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"$interface\"" >> /etc/udev/rules.d/70-persistent-net.rules
               else
                   sed -i "s/$oldname/$interface/g" /etc/udev/rules.d/70-persistent-net.rules
               fi
           fi
       fi 
    fi

    # main sector
    echo "# ${prefix} network" >> $iffile
    echo "auto $interface" >> $iffile
    echo "iface $interface inet static" >> $iffile
    echo "  address $address" >> $iffile
    echo "  netmask $netmask" >> $iffile
    if [ "x$hwaddr" != "x" ]; then 
         echo "  hwaddress $hwaddr" >> $iffile
    fi
    if [ "x$dns_servers" != "x" ]; then 
         echo "  dns-nameservers $dns_servers" >> $iffile
    fi

    # gateway, there is only one default gateway, the others have to be configured as policy routing
    if [ "x$gateway" != "x" ]; then
        if [ "x$gateway_policy_id" = "x" ]; then
            echo "  gateway $gateway" >> $iffile 
        else
            cat /etc/iproute2/rt_tables | grep $gateway_policy_name >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "$gateway_policy_id $gateway_policy_name" >> /etc/iproute2/rt_tables
            fi
            cat /etc/rc.local.tail | grep "src $address table $gateway_policy_name"  >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "# ${prefix} network routing policy" >> /etc/rc.local.tail
                if [ "x$gateway_policy_subnet" != "x" ]; then
                    echo "ip route add ${gateway_policy_subnet} dev $interface src $address table $gateway_policy_name" >> /etc/rc.local.tail
                else
                    subnet=`echo $address | awk -F'.' '{print $1"."$2"."$3}'`
                    echo "ip route add ${subnet}.0/24 dev $interface src $address table $gateway_policy_name" >> /etc/rc.local.tail
                fi
                echo "ip route add default via $gateway dev $interface table $gateway_policy_name" >> /etc/rc.local.tail
                echo "ip rule add from $address table $gateway_policy_name" >> /etc/rc.local.tail
                echo "ip rule add to $address table $gateway_policy_name" >> /etc/rc.local.tail
                echo "" >> /etc/rc.local.tail 
            fi
        fi
    fi

    # routing rule
    if [ "x$routing_rule" != "x" ]; then
        echo "# ${prefix} network routing rule" >> /etc/rc.local.tail
        echo "$routing_rule" >> /etc/rc.local.tail
        echo "" >> /etc/rc.local.tail 
    fi

    if [ "x$bond_interface" = "x$interface" ]; then
        echo "  bond-mode $bond_mode" >> $iffile
        echo "  bond-miimon 100" >> $iffile 
        if [[ $eip_network_bond_mode -eq 4 ]]; then
            echo "bond-lacp-rate 1" >> ${interfaces}
        fi
        echo "  bond-slaves ${bond_slaves/,/ }" >> $iffile         
    fi

    # bridge attributes
    if [ "x$bridge_ports" != "x" ]; then
        echo "  bridge_ports $bridge_ports" >> $iffile
        echo "  bridge_stp off" >> $iffile
        echo "  bridge_waitport 0" >> $iffile
        echo "  bridge_fd 0" >> $iffile
    fi

    # config vlan raw device
    if [ "x$vlan_raw_device" != "x" ]; then
        echo "  vlan_raw_device $vlan_raw_device" >> $iffile
    fi

    _mark_fibre $interface
    return 0
}

function install_network_phase_0()
{
    # add set_irq_affinity tool
    SafeExec cp $CWD/data/set_irq_affinity /usr/bin
    SafeExec chmod +x /usr/bin/set_irq_affinity

    # by default, bonding only has 16 queues, while intel 10G shall have 24/32 queues
    cpus=`lscpu | grep "^CPU(s)" | awk '{print $2}'`
    if [ $cpus -gt 1 ]; then  
        echo "options bonding tx_queues=$cpus" > /etc/modprobe.d/bonding.conf
    fi  

    if [ "x${feature_conntrack}" = "xon" ]; then
        # stop irqbalance service, use irq affinity instead
        echo "service irqbalance stop" >> /etc/rc.local.head

        tmpfile=/tmp/.modules.tmp
        cat /etc/modules | grep -v 'nf_conntrack' | grep -v 'nf_nat'  > $tmpfile

        # iptables conntrack
        echo "nf_conntrack hashsize=1048576" >> $tmpfile
        echo "nf_conntrack_ipv4" >> $tmpfile

        # Note: 14.04 requires explicitly add gre/pptp helper to record track
        if [ ${os_version} \> "14.04" ]; then
           echo "nf_conntrack_proto_gre" >> $tmpfile
           echo "nf_conntrack_pptp" >> $tmpfile
        fi

        echo "nf_nat" >> $tmpfile
        SafeExec mv $tmpfile /etc/modules
        SafeExec chmod 644 /etc/modules

        # replace sysctl.conf
        SafeExec cp $CWD/data/sysctl.conf.conntrack /etc/sysctl.conf

        # enable forwarding
        cat /etc/sysctl.conf | grep "net.ipv4.ip_forward=1" | grep -v "#" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        fi
    fi
    
    SafeExec cp $CWD/data/interfaces /etc/network
    SafeExec chmod 644 /etc/network/interfaces

    # create network interfaces, hypernode only
    if [ "x${feature_hypernode}" = "xon" ]; then
         cat $CWD/data/rc.local.tail.hypernode >> /etc/rc.local.tail

        _create_network ctn 

        # for vm bridge, shall add hwaddr with format 42:42:<ww>:<xx>:<yy>:<zz>, while ww.xx.yy.zz is the br0 ip in hex
        #hwtail=`printf '%.2x:%.2x:%.2x:%.2x' ${vm_network_address//./ }`
        #export vm_network_hwaddr="42:42:$hwtail"
        _create_network vm 

        # enable dirty cache control
        echo "vm.dirty_bytes=268435456" >> /etc/sysctl.conf
        echo "vm.dirty_background_bytes=67108864" >> /etc/sysctl.conf
    fi

    # management/user/extra network
    _create_network mgmt
    _create_network user 
    _create_network extra 

    # ceph node only
    if [ "x${feature_cephnode}" = "xon" ]; then
         _create_network public
         _create_network cluster
    fi
}

function install_network_phase_1()
{
    # dhcp service
    if [ "x${feature_hypernode}" = "xon" ]; then
        SafeExec apt-get install -y --force-yes isc-dhcp-server
       
        if [ "x$vm_network_address" = "x" ]; then
            vm_network_address=`ifconfig $vm_network_interface | grep 'inet addr:' | awk -F'inet addr:' '{print $2}' | awk '{print $1}'`
        fi

        # shall block user's visit to VM GW
        echo >> /etc/rc.local.tail
        echo "# block user's visit to VM GW" >> /etc/rc.local.tail
        echo "iptables -I INPUT -d ${vm_network_address} -p tcp -m state --state NEW -j DROP" >> /etc/rc.local.tail

        vm_subnet=`echo $vm_network_address | awk -F'.' '{print $1"."$2"."$3}'` 
        echo """ 
ddns-update-style none;
default-lease-time 60;
max-lease-time 60;
log-facility local7;
subnet ${vm_subnet}.0 netmask 255.255.255.0 {
  range ${vm_subnet}.10 ${vm_subnet}.250;
  option routers $vm_network_address;
  option domain-name-servers $vm_network_dns_servers;  
  option domain-name \"$vm_network_domain_name\";
}
""" > /etc/dhcp/dhcpd.conf

       echo "INTERFACES=\"$vm_network_interface\"" > /etc/default/isc-dhcp-server
       service isc-dhcp-server restart
    fi 

    # no interface shall be left as no hw address
    ret=`ifconfig -a | grep HWaddr | grep 00:00:00:00:00:00 | awk '{print $1}'`
    if [ "x$ret" != "x" ]; then
        echo "WARNING: there are some interfaces with empty hardware address!"
    fi
}

