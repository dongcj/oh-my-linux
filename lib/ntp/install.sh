#!/bin/bash
## CopyRight  dongchaojun@GreatWall
## Author:dongcj dongcj@greatwall.com.cn
## Usage: install.sh ------install & configure the software
## Modify Log:
    # 

## Define the directory and file location
LOG_DIR=/opt/installtmp/
DEPLOY_LOGNAME=install.log
DEPLOY_CONFNAME=deploy.conf
SCRIPT_NAME=`basename $0`
CUR_DIR=$(echo `dirname $0` |sed -n 's/$/\//p')
export CUR_DIR; cd ${CUR_DIR}
export TERM=xterm LANG=C
PWD_DIR=`pwd`
[ ! -d "$LOG_DIR" ] && mkdir -p $LOG_DIR
SCRIPT_START_TIME=`date "+%Y-%m-%d %H:%M:%S"`

## Import the conf from file deploy.conf
if [ -f ${LOG_DIR}${DEPLOY_CONFNAME} ];then
    if ! source ${LOG_DIR}${DEPLOY_CONFNAME} >/dev/null 2>&1;then
        echo "   Please check the ${LOG_DIR}${DEPLOY_CONFNAME}!"; exit 1
    fi
else
    exec ./deploy.sh
fi

if [ "$DEPLOY_IS_SUCCESSFUL" != "yes" ]; then
    exec ./deploy.sh
fi

tmpdir=/tmp/$$
mkdir -p $tmpdir

##
CLOUD_FORWARDER=`echo $CLOUD_SERVER_DNSSERVER | tr ',' ';'`
DHCP_LEFT=`echo $CLOUD_DHCP_RANGE | awk -F"-" '{print $1}'`
DHCP_RIGHT=`echo $CLOUD_DHCP_RANGE | awk -F"-" '{print $2}'` 
FIRST=`echo $CLOUD_NETWORK | cut -d'.' -f1`
SECOND=`echo $CLOUD_NETWORK | cut -d'.' -f2`
THIRD=`echo $CLOUD_NETWORK | cut -d'.' -f3`
FOURTH=`echo $CLOUD_NETWORK | cut -d'.' -f4`
MASK_FIRST=`echo $CLOUD_SERVER_NETMASK | cut -d'.' -f1`
MASK_SECOND=`echo $CLOUD_SERVER_NETMASK | cut -d'.' -f2`
MASK_THIRD=`echo $CLOUD_SERVER_NETMASK | cut -d'.' -f3`
MASK_FOURTH=`echo $CLOUD_SERVER_NETMASK | cut -d'.' -f4`
let NET_FIRST="$FIRST&$MASK_FIRST"
let NET_SECOND="$SECOND&$MASK_SECOND"
let NET_THIRD="$THIRD&$MASK_THIRD"
let NET_FOURTH="$FOURTH&$MASK_FOURTH"
CLOUD_NETWORK=$NET_FIRST.$NET_SECOND.$NET_THIRD.$NET_FOURTH
if [ "$MASK_THIRD" = "255" ]; then
	CLOUD_REVERSE_NETWORK=$THIRD.$SECOND.$FIRST
	RIGHT=`echo $DHCP_RIGHT | cut -d'.' -f4`
	LEFT=`echo $DHCP_LEFT | cut -d'.' -f4`
elif [ "$MASK_SECOND" = "255" ]; then
	CLOUD_REVERSE_NETWORK=$SECOND.$FIRST
	let RIGHT=`echo $DHCP_RIGHT | cut -d'.' -f3`*256+`echo $DHCP_RIGHT | cut -d'.' -f4`
	let LEFT=`echo $DHCP_LEFT | cut -d'.' -f3`*256+`echo $DHCP_LEFT | cut -d'.' -f4`
elif [ "$MASK_FIRST" = "255" ]; then
	CLOUD_REVERSE_NETWORK=$FIRST
	let RIGHT=`echo $DHCP_RIGHT | cut -d'.' -f2`*256*256+`echo $DHCP_RIGHT | cut -d'.' -f3`*256+`echo $DHCP_RIGHT | cut -d'.' -f4`
	let LEFT=`echo $DHCP_LEFT | cut -d'.' -f2`*256*256+`echo $DHCP_LEFT | cut -d'.' -f3`*256+`echo $DHCP_LEFT | cut -d'.' -f4`
else
	echo "   Unsupported netmask special in deploy.sh!"
	exit 1
fi

## Install the Ruby & livecd-creator
if ! yum -y --disablerepo=\* --enablerepo=$DVD_FILE_REPO install ruby >/dev/null 2>&1;then
    echo "   Install ruby failed! "
    exit 1
else
     rpm -i common/rpms/*.rpm >/dev/null 2>&1
fi



## Install the Apache HTTP server
if ! yum -y --disablerepo=\* --enablerepo=$DVD_FILE_REPO install httpd createrepo >/dev/null 2>&1;then
    echo "   Install httpd createrepo failed! "
    exit 1
fi
# configure the httpd.conf
HTTPD_CONF=/etc/httpd/conf/httpd.conf
if [ -f $HTTPD_CONF ]; then
    sed -i "s/\(^[#]*ServerName\) .*..*:80/\1 ${CLOUD_SERVER_HOSTNAME}.${CLOUD_DOMAIN}:80/" $HTTPD_CONF
fi
chkconfig httpd on
if ! /etc/init.d/httpd restart >/dev/null 2>&1; then
    echo "   The command: /etc/init.d/httpd restart failed! "
    exit 1
fi

## Make a http repo from dvd, called "DVD-HTTP.repo"
DVDLINK=/var/www/html/dvdrepo
DVD_HTTP_REPO=DVD-HTTP
[ -L $DVDLINK ] && unlink $DVDLINK
ln -s $DVD_MOUNT_DIR $DVDLINK
cat <<EOF >/etc/yum.repos.d/${DVD_HTTP_REPO}.repo
[$DVD_HTTP_REPO]
name=RHEL - $OS_VERSION - $DVD_HTTP_REPO
baseurl=http://$CLOUD_SERVER_IP/dvdrepo
enable=1
gpgcheck=0
EOF

## Make a gwcloud repo,called "GWCLOUD-HTTP.repo"
GWCLOUD_POINT=/opt/gwrepo
GW_HTTP_REPO=GWCLOUD-HTTP
mkdir -p $GWCLOUD_POINT
[ -L /var/www/html/gwrepo ] && unlink /var/www/html/gwrepo
ln -s $GWCLOUD_POINT /var/www/html/gwrepo
cat <<EOF >/etc/yum.repos.d/${GW_HTTP_REPO}.repo
[$GW_HTTP_REPO]
name=RHEL - $OS_VERSION - $GW_HTTP_REPO
baseurl=http://$CLOUD_SERVER_IP/gwrepo
enable=1
gpgcheck=0
EOF
. /etc/sysconfig/clock
ESCAPE_ZONE=$(echo $ZONE | tr ' ' '_' | sed 's/\//\\\//g')
[ "$UTC" = "true" -o "$UTC" = "yes" ] && ESCAPE_ZONE=$(echo $ESCAPE_ZONE | sed 's/^/--utc /g')
cat ./dhcp-dns/vmks.cfg | sed "s/CLOUD_SERVER_IP/$CLOUD_SERVER_IP/g" | sed "s/CLOUD_TIMEZONE/$ESCAPE_ZONE/g" > $GWCLOUD_POINT/vmks.cfg
cat ./dhcp-dns/storage-ks.cfg | sed "s/CLOUD_SERVER_IP/$CLOUD_SERVER_IP/g" | sed "s/CLOUD_TIMEZONE/$ESCAPE_ZONE/g" > $GWCLOUD_POINT/storage-ks.cfg
cp -rf ibm-rpms $GWCLOUD_POINT
if ! createrepo $GWCLOUD_POINT; then
    echo "   command: createrepo $GWCLOUD_POINT failed"
    exit 1
fi
chmod -R a+r $GWCLOUD_POINT


## Install & configure NTP(make localhost to be ntp server)
NTP_Setup(){
	if [ -f /etc/init.d/ntpd ]; then
		/etc/init.d/ntpd stop >/dev/null 2>&1
		[ $? -ne 0 ] && killall -9 ntpd
	fi
	if ! yum -y --disablerepo=\* --enablerepo=$DVD_FILE_REPO install ntp >/dev/null 2>&1;then
	    echo "   Install ntp failed! "
	    exit 1
	fi
		# Some ntp servers provided, disable default ntp servers
		sed -i 's/^server 0.rhel.pool.ntp.org/#server 0.rhel.pool.ntp.org/g' /etc/ntp.conf
		sed -i 's/^server 1.rhel.pool.ntp.org/#server 1.rhel.pool.ntp.org/g' /etc/ntp.conf
		sed -i 's/^server 2.rhel.pool.ntp.org/#server 2.rhel.pool.ntp.org/g' /etc/ntp.conf

	# Enable sync with localhost in case of failure of all servers provided
	sed -i 's/#server	127.127.1.0/server	127.127.1.0/g' /etc/ntp.conf
	sed -i 's/#fudge	127.127.1.0/fudge	127.127.1.0/g' /etc/ntp.conf

	if [ -n "$CLOUD_NTP_SERVER" -a "$CLOUD_NTP_SERVER" != "localhost" \
	-a "$CLOUD_NTP_SERVER" != "127.0.0.1" -a "$CLOUD_NTP_SERVER" != "$CLOUD_SERVER_IP" ]; then
		if ! grep -q $(echo "$CLOUD_NTP_SERVER" | cut -d ',' -f 1) /etc/ntp.conf; then
			echo "$CLOUD_NTP_SERVER" | sed "s/127.0.0.1//" | tr -d 'localhost' | tr "," "\n" | sed 's/^/server /g' >> /etc/ntp.conf
		fi
	fi
	chkconfig ntpd on
	if ! /etc/init.d/ntpd start >/dev/null 2>&1; then
	    echo "   command: /etc/init.d/ntpd start failed"
	    exit 1
	fi
}


function ntp_check(){
	/etc/init.d/ntpd status
	[ $? -ne 0 ] && return
	for i in {1..60}; do	# force initial ntp synchronization
		echo -n ". " 1>&3
		ntpstat > /dev/null
		rc=$?
		[ $rc -eq 0 ] && echo "" 1>&3 && ntpstat && break
		sleep 10
	done
	if [ $rc -ne 0 ]; then
		lprint "ntp_check" "Initial NTP synchronization failed. Following steps may experience weird errors." && sleep 10
	else
		lprint "ntp_check" "The ntp server is synchronized and ready for service."
	fi
}

Create_Image(){
    FSLABEL=compute
	IMG_DIR=$1/$FSLABEL
	rm -rf $IMG_DIR
	mkdir -p $IMG_DIR

#############################
#############################
############################# not done
	yum -y install util-linux-ng syslinux patch livecd-tools
	mkdir -p $IMG_DIR
	. /etc/sysconfig/clock
	ESCAPE_ZONE=$(echo $ZONE | tr ' ' '_' | sed 's/\//\\\//g')
	[ "$UTC" = "true" -o "$UTC" = "yes" ] && ESCAPE_ZONE=$(echo $ESCAPE_ZONE | sed 's/^/--utc /g')
	cat tftpboot/ramks.cfg | sed "s/CLOUD_SERVER_IP/$CLOUD_SERVER_IP/g" | sed "s/CLOUD_TIMEZONE/$ESCAPE_ZONE/g" > $tmpdir/ramks.cfg

	cd $tmpdir
	lprint "create_image" "Waiting for livecd-creator to finish. This may take up to 15 minutes or more depending on your hardware performance and network condition. Please wait and \033[01;31mDO NOT\033[00m terminate this process."

	doing "LANG=C livecd-creator --config=$tmpdir/ramks.cfg --fslabel=$FSLABEL"
	[ $? -ne 0 ] && die "create_image" "Failed to create the ramdisk for compute nodes."

	mkdir iso && mount -o loop $FSLABEL.iso iso
	mkdir initrd && cd initrd
	gunzip -dc $tmpdir/iso/isolinux/initrd0.img | cpio -i --make-directories
	cp /sbin/sfdisk sbin
	(cd sbin && patch -p0 < $workpwd/tftpboot/ramdisk.diff)
	mkdir ../output; find . | cpio --create --format='newc' > ../output/initrd0.img
	( cd $tmpdir && echo $FSLABEL.iso | cpio -H newc --quiet -L -o ) | gzip -9 | cat $tmpdir/output/initrd0.img - > $IMG_DIR/initrd0.img
	[ $? -ne 0 ] && die "create_image" "Failed to patch the ramdisk for compute nodes."
	cp $tmpdir/iso/isolinux/vmlinuz0 $IMG_DIR
	umount $tmpdir/iso
	lprint "create_image" "The ramdisk has been generated successfully."
}

## Install TFTP
TFTP_Setup(){
TFTPBOOT=/opt/tftpboot/rhel6
rm -rf $TFTPBOOT
mkdir -p $TFTPBOOT
cp $DVD_MOUNT_DIR/images/pxeboot/initrd.img $TFTPBOOT
cp $DVD_MOUNT_DIR/images/pxeboot/vmlinuz $TFTPBOOT
if ! yum -y --disablerepo=\* --enablerepo=$DVD_FILE_REPO install tftp-server >/dev/null 2>&1;then
    echo "   Install tftp failed! "
fi
	sed -i "s/\(disable.*\)= yes/\1= no/" /etc/xinetd.d/tftp 
	sed -i "s:server_args.*=.*:server_args             = -s $TFTPBOOT:" /etc/xinetd.d/tftp
	cp -f /etc/yum.repos.d/$DVD_HTTP_REPO.repo /etc/yum.repos.d/$GW_HTTP_REPO.repo tftpboot/keys.tar.gz tftpboot/deps.tar.gz $TFTPBOOT
	create_image $TFTPBOOT
	##################
	###################
	#####################
	mkdir $TFTPBOOT/pxelinux.cfg
	cd $workpwd
	cp $workpwd/tftpboot/default $workpwd/tftpboot/vmbase $tmpdir
	sed -i "s/CLOUD_FSLABEL/$FSLABEL/g" $tmpdir/default
	sed -i "s:CLOUD_TFTPBOOT_DIR:$TFTPBOOT:g" $tmpdir/vmbase
	sed -i "s/CLOUD_FIRST_BOX_IP/$CLOUD_FIRST_BOX_IP/g" $tmpdir/default $tmpdir/vmbase
	cp -f $tmpdir/default $TFTPBOOT/pxelinux.cfg
	cp -f $tmpdir/vmbase $TFTPBOOT/pxelinux.cfg/01-52-54-52-54-52-54
	cp -f $workpwd/tftpboot/startup.sh $TFTPBOOT
	cp -f $workpwd/tftpboot/kervm $TFTPBOOT
	cp -f $workpwd/tftpboot/cleanup $TFTPBOOT
	cp -f /usr/share/syslinux/pxelinux.0 $TFTPBOOT
	cp -f /usr/share/syslinux/menu.c32 $TFTPBOOT
	tftp_genfiles $TFTPBOOT
	mkdir ~/.ssh
	cd ~/.ssh
	tar -zxvf $workpwd/tftpboot/keys.tar.gz
	cd -
	/etc/init.d/xinetd restart
	[ $? -ne 0 ] && die "tftp_setup" "Failed to run start tftp service."
	iptables -F
	lprint "tftp_setup" "The tftp service is configured and running succesfully."
}

################################## Install SNMP , for base monitor(UPTIME...), also the hypervisor need
# SNMP USAGE:
# snmpwalk 192.168.11.111 -v1 -c public | grep -i eth0

# Edit the /etc/snmp/snmpd.conf, for example: location... 



## Install DDNS
function DDNS_Setup(){
if [ -f /etc/init.d/dhcpd ]; then
	/etc/init.d/dhcpd stop >/dev/null 2>&1
	[ $? -ne 0 ] && killall -9 dhcpd
	#yum remove dhcp
fi

if [ -f /etc/init.d/named ]; then
	/etc/init.d/named stop >/dev/null 2>&1
	[ $? -ne 0 ] && killall -9 named
	#yum remove bind
fi

if ! yum -y --disablerepo=\* --enablerepo=$DVD_FILE_REPO install bind dhcp >/dev/null 2>&1; then
     echo "   Install bind and dhcp failed! "
     exit 1
fi
DNSCFG=$tmpdir/named.conf
DHCPCFG=$tmpdir/dhcpd.local
FORWARD_DB=$tmpdir/forward-lookup.db
REVERSE_DB=$tmpdir/reverse-lookup.db
LOCALHOST_DB=$tmpdir/localhost.db
cp -f dhcp-dns/named.conf $DNSCFG
cp -f dhcp-dns/dhcpd.local $DHCPCFG
cp -f dhcp-dns/forward-lookup.db $FORWARD_DB
cp -f dhcp-dns/reverse-lookup.db $REVERSE_DB
cp -f dhcp-dns/localhost.db $LOCALHOST_DB
sed -i "s/CLOUD_DOMAIN_NAME/$CLOUD_DOMAIN/g" $DNSCFG $DHCPCFG $FORWARD_DB $REVERSE_DB $LOCALHOST_DB
sed -i "s/CLOUD_NETWORK/$CLOUD_NETWORK/g" $DNSCFG $DHCPCFG $FORWARD_DB $REVERSE_DB $LOCALHOST_DB
sed -i "s/CLOUD_NETMASK/$CLOUD_SERVER_NETMASK/g" $DNSCFG $DHCPCFG $FORWARD_DB $REVERSE_DB $LOCALHOST_DB
sed -i "s/CLOUD_FORWARDER/${CLOUD_FORWARDER}/g" $DNSCFG $DHCPCFG $FORWARD_DB $REVERSE_DB $LOCALHOST_DB
sed -i "s/CLOUD_GATEWAY/$CLOUD_SERVER_GATEWAY/g" $DNSCFG $DHCPCFG $FORWARD_DB $REVERSE_DB $LOCALHOST_DB
sed -i "s/CLOUD_SERVER_IP/$CLOUD_SERVER_IP/g" $DNSCFG $DHCPCFG $FORWARD_DB $REVERSE_DB $LOCALHOST_DB
sed -i "s/CLOUD_DHCP_RANGE/$DHCP_LEFT $DHCP_RIGHT/g" $DNSCFG $DHCPCFG $FORWARD_DB $REVERSE_DB $LOCALHOST_DB
sed -i "s/CLOUD_REVERSE_NETWORK/$CLOUD_REVERSE_NETWORK/g" $DNSCFG $DHCPCFG $FORWARD_DB $REVERSE_DB $LOCALHOST_DB
cp -f $DNSCFG /etc/
cp -f -p $DHCPCFG /etc/dhcp/
cp -f dhcp-dns/dhcpd.conf /etc/dhcp/
cp -f $FORWARD_DB /var/named
cp -f $REVERSE_DB /var/named
cp -f $LOCALHOST_DB /var/named
touch /var/named/cache.db
chown named.named -R /var/named

if [ ! -f /etc/rndc.key ]; then	# no rndc.key exists, generating a new one
	rndc-confgen -a
fi
chmod a+r /etc/rndc.key

/etc/init.d/named start >/dev/null 2>&1
[ $? -ne 0 ] && echo "   DNS service start failed " && exit 1
/etc/init.d/dhcpd start >/dev/null 2>&1
[ $? -ne 0 ] && echo "   DHCP service start failed " && exit 1
chkconfig named on
chkconfig dhcpd on
}

# Usage: dhcp_addentry mac
DHCP_AddEntry(){
    DHCP_STATIC_FILE=/etc/dhcp/dhcpd.static
	echo "host $1 {" >> $DHCP_STATIC_FILE
	echo "	hardware ethernet $2;" >> $DHCP_STATIC_FILE
	echo "	ddns-hostname = pick (option host-name, \"$1\");" >> $DHCP_STATIC_FILE
	echo "	fixed-address $DHCP_LEFT;" >> $DHCP_STATIC_FILE
	echo "}" >> $DHCP_STATIC_FILE
	echo "$DHCP_LEFT	$1	$1.$CLOUD_DOMAIN" >> $TFTPBOOT/hosts
	DHCP_LEFT_FOURTH=`echo $DHCP_LEFT | cut -d'.' -f4`
	DHCP_LEFT_THIRD=`echo $DHCP_LEFT | cut -d'.' -f3`
	DHCP_LEFT_SECOND=`echo $DHCP_LEFT | cut -d'.' -f2`
	DHCP_LEFT_FIRST=`echo $DHCP_LEFT | cut -d'.' -f1`
	let DHCP_LEFT_FOURTH=$DHCP_LEFT_FOURTH+1
	if [ $DHCP_LEFT_FOURTH -ge 255 ]; then
		DHCP_LEFT_FOURTH=1
		let DHCP_LEFT_THIRD=$DHCP_LEFT_THIRD+1
		if [ $DHCP_LEFT_THIRD -ge 255 ]; then
			DHCP_LEFT_THIRD=1
			let DHCP_LEFT_SECOND=$DHCP_LEFT_SECOND+1
		fi
	fi
	DHCP_LEFT=$DHCP_LEFT_FIRST.$DHCP_LEFT_SECOND.$DHCP_LEFT_THIRD.$DHCP_LEFT_FOURTH
}


## Install the monitor agent



## Check_NTP


NTP_Setup

DDNS_Setup

DHCP_AddEntry dongchaojun 52:54:00:00:00:11