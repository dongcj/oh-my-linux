#!/bin/bash
# COPYRIGHT BY dongcj@greatwall.com.cn
# This script set the default iptables rule.
# Version: 0.2
# CTIME: 2012/08/17

### User setup here;
  INIF="eth4"
  INNET="192.168.0.0/24"	
  EXTIF="eth4"
  SSH_PORT="12345"
  WEB_PORT="8080"

  export EXTIF INIF INNET


# Get the EXTIF IP address;
GW_IP_ADDRESS=`ifconfig $EXTIF | grep "inet addr" | sed "s/inet addr:\(.*\) Bcast:.* Mask:\(.*\)/\1/"  | sed -n '1p' | xargs`


# 1. Set the tcp syncookies;
  sysctl -w net.ipv4.ip_forward=1
  echo "1" > /proc/sys/net/ipv4/tcp_syncookies
  echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
  for i in /proc/sys/net/ipv4/conf/*/{rp_filter,log_martians}; do
    echo "1" > $i
  done
  for i in /proc/sys/net/ipv4/conf/*/{accept_source_route,accept_redirects,send_redirects}; do
    echo "0" > $i
  done

# 2. init the filter rule;
  iptables -F
  iptables -X
  iptables -Z
  iptables -P INPUT   DROP
  iptables -P OUTPUT  ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -A INPUT -i lo -j ACCEPT
  # The follow rule will accept the RELATED & ESTABLISHED incoming paceage; 
  iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT


# 3. Enable the icmp;
  iptables -A INPUT -i $INIF  -p icmp -j ACCEPT

# 4. Eneable your application port;
# iptables -A INPUT -p TCP -i $EXTIF --dport  21 --sport 1024:65534 -j ACCEPT # FTP

#modprobe ip_nat_ftp
#echo 1 > /proc/sys/net/ipv4/ip_forward
# #then, configure IpTables:
#iptables -A INPUT -p tcp --dport 1024:65535 -j ACCEPT
#iptables -A FORWARD -i eth0 -p tcp --dport 1024:65535 -j ACCEPT
#iptables -t nat -A PREROUTING -i eth0 -p tcp -d NatPrivateIp --dport 1024:65535 -j DNAT --to-destination FtpPrivateIp:1024-65535
#iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 21 -j DNAT --to-destination FtpPrivateIp:21
#iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE [duplicate]


iptables -A INPUT -p TCP -i $INIF --dport  $SSH_PORT --sport 1024:65534 -j ACCEPT # SSH from INNET, but can not ssh localhost
# iptables -A INPUT -p TCP -i $INIF --dport  $WEB_PORT --sport 1024:65534 -j ACCEPT # WWW from INNET

# iptables -A INPUT -p TCP -i $EXTIF --dport  25 --sport 1024:65534 -j ACCEPT # SMTP
# iptables -A INPUT -p UDP -i $EXTIF --dport  53 --sport 1024:65534 -j ACCEPT # DNS
# iptables -A INPUT -p TCP -i $EXTIF --dport  53 --sport 1024:65534 -j ACCEPT # DNS
# iptables -A INPUT -p TCP -i $EXTIF --dport 110 --sport 1024:65534 -j ACCEPT # POP3
# iptables -A INPUT -p TCP -i $EXTIF --dport 443 --sport 1024:65534 -j ACCEPT # HTTPS

if [ "$INIF" != "$EXTIF" ]; then
    iptables -A INPUT -p TCP -i $EXTIF --dport  $SSH_PORT --sport 1024:65534 -j ACCEPT # SSH from EXTNET
    # iptables -A INPUT -p TCP -i $EXTIF --dport  $WEB_PORT --sport 1024:65534 -j ACCEPT # WWW from EXTNET
  	iptables -A INPUT -i $EXTIF -p icmp -j ACCEPT

fi

# 5. load the module;
  modules="ip_tables iptable_nat ip_nat_ftp ip_nat_irc ip_conntrack ip_conntrack_ftp ip_conntrack_irc"
  for mod in $modules
  do
      testmod=`lsmod | grep "^${mod} " | awk '{print $1}'`
      if [ "$testmod" == "" ]; then
            modprobe $mod
      fi
  done

# 6. Init the nat rule;
  iptables -F -t nat
  iptables -X -t nat
  iptables -Z -t nat
  iptables -t nat -P PREROUTING  ACCEPT
  iptables -t nat -P POSTROUTING ACCEPT
  iptables -t nat -P OUTPUT      ACCEPT

# Example: 
# 如果你的 MSN 一直無法連線，或者是某些網站 OK 某些網站不 OK，
# 可能是 MTU 的問題，那你可以將底下這一行給他取消註解來啟動 MTU 限制範圍
# iptables -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss \
#          --mss 1400:1536 -j TCPMSS --clamp-mss-to-pmtu

# Example:
# NAT 伺服器後端的 LAN 內對外之伺服器設定
# iptables -t nat -A PREROUTING -p tcp -i $EXTIF --dport 80 \
#          -j DNAT --to-destination 192.168.1.210:80 # WWW

# Example:
# 特殊的功能，包括 Windows 遠端桌面所產生的規則，假設桌面主機為 1.2.3.4
# iptables -t nat -A PREROUTING -p tcp -s 1.2.3.4  --dport 6000 \
#          -j DNAT --to-destination 192.168.100.10
# iptables -t nat -A PREROUTING -p tcp -s 1.2.3.4  --sport 3389 \
#          -j DNAT --to-destination 192.168.100.20

# 7. MASQUERADE THE POSTROUTING CHAIN, USED TO LOCAL CAN CONNECT TO THE PORT
iptables -t nat -A POSTROUTING -j MASQUERADE

# For example(connect to FIREWALL:2000 will direct to REALSERVER:80):
# iptables -t nat -A PREROUTING -p tcp --dport 2000 -j DNAT --to-destination 192.168.88.11:80 

# 8. Save the rules;
  /etc/init.d/iptables save

echo "  Success! "
