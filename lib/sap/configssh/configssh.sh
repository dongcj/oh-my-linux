#!/bin/bash

################################################################################
#
#  variable
#
################################################################################

LOGDIR=/opt/installtmp/installstep
LOGFILE=${LOGDIR}/configssh.log
mkdir -p ${LOGDIR} >/dev/null 2>&1
[ -f $LOGFILE ] && rm -rf $LOGFILE >/dev/null 2>&1

################################################################################
#
#   Function: validate IP 
#   Desctiption: IPOK=1 the IP is valid or is invalid
#
################################################################################
IsIP()
{
    IP=$1
    echo $IP | grep "\<[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\>" >/dev/null 2>&1
    if [ $? -ne 0 ]
    then
    	IPOK=0
    	return 1
    fi
    for ((i=1; i<=4; i++))
    do
    	IP_sec[$i]=`echo $IP | awk -F. '{print $"'$i'"}'`
    	
    	IP_sec_first=`echo ${IP_sec[$i]} | cut -c1`
    	IP_sec_length=`echo ${#IP_sec[$i]}`
    	if [ ${IP_sec_length} -ne 1 ] && [ ${IP_sec_first} -eq 0 ]
    	then
    	    IPOK=0
    	    return 1
        fi
    	 	  
    	if [ ${IP_sec[$i]} -gt 255 ]
    	then
    	    IPOK=0
    	    return 1
    	fi
    done
    IPOK=1   
}

    
yesno()
{
	while true
	do
	 	clear
	 	echo ""
	 	echo "This script will set up the SSH trust relation for user root and omcuser"
	 	printf "Are you sure you want to continue? [y/n]: "
	 	read yesno
	 	if [ "$yesno" = "N" -o "$yesno" = "n" ]
	 	then
	 		echo ""
	 		exit 1
	 	elif [ "$yesno" = "Y" -o "$yesno" = "y" ]
	 	then	 
	 		break
	 	else
	 		echo ""
	 		echo "Please enter \"y\" or \"n\""
	 		sleep 1
	 		continue
	 	fi
	done
	
	while true
	do	
		echo ""
	 	echo "Notes: If you enter many IP addresses, please separate the IP addresses by spaces"
	 	printf "Please enter the IP address: "
	 	read ipaddrlist
	    [ "$ipaddrlist" = "" ] && continue
	    HOSTNAME=`hostname`
        if ! ping $HOSTNAME >>$LOGFILE 2>&1
        then
    	    echo ""
    	    echo "Error: Failed to ping local system ${HOSTNAME}, please check network"
    	    echo ""
    	    exit 1
        fi 	
	 	badip=""
	 	for ipaddr in $ipaddrlist
	 	do
	 		IsIP $ipaddr
	    	if [ $? -ne 0 ]
	    	then
	    		badip="$badip $ipaddr"	    			  
	    		continue
	    	fi	    		    		    	
	    done
	    if [ "$badip" != "" ]
	    then
	    	echo ""
	    	echo "Error: the IP address $badip you enter is illegal"
	    	continue
	    fi
	    
	    aliveip=$ipaddrlist
	    deadip=""
	    for ipaddr in $ipaddrlist
	 	do
	    	ping $ipaddr >>$LOGFILE 2>&1
    		if [ $? -ne 0 ]
    		then
    			aliveip=`echo $aliveip | sed 's/\<'$ipaddr'\>//'`
    			deadip="$deadip $ipaddr"    	
    		fi	
    	done
    	
    	localip=""
    	for ipaddr in $aliveip
    	do	    	
    		if ifconfig -a | grep -w inet | grep -w "$ipaddr" >>$LOGFILE 2>&1
    		then
    			localip="$localip $ipaddr"
    			aliveip=`echo $aliveip | sed 's/\<'$ipaddr'\>//'`   		 		
    		fi
    	done
    	break
    done
}

################################################################################
#
#   Function: # 建立 ssh key
#   Desctiption: 
#
################################################################################
create_ssh_key()
{	
	rootdir=`cat /etc/passwd | grep "^root:" | awk -F: '{print $6}'`
	cd $rootdir
	mkdir -p .ssh
	chmod 755 .ssh
	cd .ssh
	
	#比较是否是全球私钥
	echo '-----BEGIN RSA PRIVATE KEY-----
MIIEoQIBAAKCAQEAvUOaSB3LWYsGjmdf/PbIew1Xd+rHB7rPGAoYDdj1n9LHQPO7
HMmj4C62XBboRLCCc9OfFuFrexa2qSjVLSQW9pYsfY3L+ag9IxVK3MRa1eMvPSHs
Ho1/rNp5OpS7l3xBVFkrkjXoBQNA39PLRA7ruDSI802EVB1fj10jmq6WXBsDFxSQ
8RUsFdZ2PN+RyPJEcGMSdnAysNfX+GqW9sgznw/l8tc4S7pOV/OeazW13riDWkvi
r/T//SYcASNjTOElxJY4AeSKXzr5sad6lDuMCfceVnv073NE7aPGmrYmd7Qkgdff
ICVeYndMrFlXbVsHmvzDygv5+de37ShhOSgbIQIBIwKCAQEAnNGdFy6hLO+JFufw
coNVp8k52GNxtfKOVb84gICRAMSWd6VghZEhYfrRnMKF78VzZ0jxh/ya4lSl+eAB
FsYhp75CHuMz+r6ZDnC6XyZZ5GvIDhTK9L5ieUdOgP7kk3WVN0KR0OrWMAoCjZI6
tLvn4cUhBBuoKHAb+nG+ajji+9pwxbL1k17J4KIsfQeDp7iSiqVLDMLR3RTpufMq
XaML7PmnS8PurJnM3GOGF90h2/psbdX7uAve/3GceyqUMY0yFvzp0W2PqpFCrdk6
rpj+4LeXuOq2WQPdB4+Imx/rZiHkRkpoJ5CP05hu7SCSbE4/QOWCcQ870NKWs+XA
9yzlWwKBgQDnVrNBnZ8BVBIQwbkUTK6LN879zgI0X6FCphiMwYDP37vx3kBE0jQ6
doLZTuDkiVV37dduquoVhaU4zfg6M/NckG4rxQTHnCOPTnObjJh4ilSE6OcqKjig
Ki/fZN77wVOsQ4ZvPtVJXCwAimXLvXmIb3GWue0ZKG3oIm6JZqhXNQKBgQDRcKyi
hx4/8HNtlM35EvI0f5efmQdHp35yaRIU3sBnAm1Ep35X1VmytCTK/4e6H8IM+Yyu
Juru/JaqwdR2PjqMwCLyCyaQ9Tv2mjaGjTEMBn5muossfRt/hVy97WEx66pTFZ9c
G35M9UPgvSSCsZS3PlLfFOkushNgh61hsQL1vQKBgBPUO0AjdAdtmyYB+evMDvX9
eCRiHXI0FSL4Sz9DyTZjomUwTqbQMFzIVFvE7rSAzM/D7eTqFBB5K2tE2sMpBjsi
UpYJkrIGEa0ynDHnesiA4qxOejbQa0DtrFT6BHv6oMWfY0tdKDl87dQpHqsQPZ36
7HqiOOTmNU5pWe6FJF8/AoGAC/fPWb6UA6dXDZN5e/J0PYOiQ6JYL/rxSF3GhNmH
Vlfo/JvbVXnn3lNv0RXqf6oLFq8snDy897aphhm0Xoc2i7M1MmcJhKBMkb+rWCVT
QoQHORH5Uv/Vr4P2q8Rr9DlaMKImXQjipU/X/jaxoRF2NltVMVGm7Lm39uMuepxm
kbMCgYBn1Frc93mdVVKQFDdj6WbRN7wOvwLmh3jJpqjQoWGIyp+U+N4+peWOOz+a
Oj4iCfLs9qCSRsNVVhvVQG335zMeB4jcOZMgk32SWsRNIIFDKuwiMnPkHYCGvvBG
P0x9wjBAfARNNJqzE7zrDPYgkC2sFxBLkQlCGEGJdHFSAH2mKg==
-----END RSA PRIVATE KEY-----'>/tmp/id_rsa
    
    globalkey=0
    if [ -f id_rsa -a -f authorized_keys ]
    then
        if diff /tmp/id_rsa id_rsa >>$LOGFILE 2>&1
		then
		    globalkey=1
		fi
	else
	    globalkey=1
	fi
    #rm -rf id_rsa.pub >>$LOGFILE 2>&1
	if [ $globalkey -eq 1 ]
	then
		rm -rf {id_rsa,id_rsa.pub,authorized_keys} >>$LOGFILE 2>&1
		[ -d /tmp/SSHKEY/.ssh ] && rm -rf /tmp/SSHKEY/.ssh
		mkdir -p /tmp/SSHKEY/.ssh 
		chmod 755 /tmp/SSHKEY/.ssh && cd /tmp/SSHKEY/.ssh
		ssh-keygen -t rsa -b 1024 -f id_rsa -N "" >>$LOGFILE 2>&1
		if [ $? -ne 0 ]
		then
			echo ""
			echo "Error: Failed to create SSH key"
			echo ""
			exit 1
		fi
		cp id_rsa.pub authorized_keys
		chmod 600 authorized_keys
		chmod 600 id_rsa.pub
		chmod 400 id_rsa
		cd - >>$LOGFILE 2>&1
		cp -p /tmp/SSHKEY/.ssh/{authorized_keys,id_rsa,id_rsa.pub} .
		[ ! -f known_hosts ] && touch known_hosts
		cp -p known_hosts /tmp/SSHKEY/.ssh/ >>$LOGFILE 2>&1
	else		
		[ -d /tmp/SSHKEY/.ssh ] && rm -rf /tmp/SSHKEY/.ssh
		mkdir -p /tmp/SSHKEY/.ssh 
		chmod 755 /tmp/SSHKEY/.ssh
		chmod 600 id_rsa.pub
		chmod 600 authorized_keys
		chmod 400 id_rsa
		[ ! -f known_hosts ] && touch known_hosts
		cp -p ./{authorized_keys,id_rsa.pub,id_rsa,known_hosts} /tmp/SSHKEY/.ssh >>$LOGFILE 2>&1		
	fi
	
	#增加omcuser 的公私钥
	if [ ! -d /etc/SSHBACKUP/.ssh ] 
	then
    	[ -d /tmp/SSHKEY_OMC/.ssh ] && rm -rf /tmp/SSHKEY_OMC/.ssh
    	mkdir -p /tmp/SSHKEY_OMC/.ssh 
    	chmod 755 /tmp/SSHKEY_OMC/.ssh && cd /tmp/SSHKEY_OMC/.ssh
    	ssh-keygen -t rsa -b 1024 -f id_rsa -N "" >>$LOGFILE 2>&1
    	if [ $? -ne 0 ]
    	then
    		echo ""
    		echo "Error: Failed to create SSH key for omcuser"
    		echo ""
    		exit 1
    	fi
    	cp id_rsa.pub authorized_keys
    	chmod 600 authorized_keys
    	chmod 600 id_rsa.pub
    	chmod 400 id_rsa
    	touch known_hosts
    	cd - >>$LOGFILE 2>&1 
    else
        [ -d /tmp/SSHKEY_OMC/.ssh ] && rm -rf /tmp/SSHKEY_OMC/.ssh
        mkdir -p /tmp/SSHKEY_OMC
        cp -rp /etc/SSHBACKUP/.ssh /tmp/SSHKEY_OMC
    fi
    
    # 如果不存在/usr/sfw/lib/libcrypto_extra.so.0.9.7 则复制一份
    currdir=`cd $(dirname $0);pwd`
    [ ! -f /usr/sfw/lib/libcrypto_extra.so.0.9.7 ] && cp ${currdir}/libcrypto_extra.so.0.9.7 /usr/sfw/lib/ >>$LOGFILE 2>&1
    chmod 755 /usr/sfw/lib/libcrypto_extra.so.0.9.7 >>$LOGFILE 2>&1
    
    #设置免输yes
    grep -v StrictHostKeyChecking /etc/ssh/ssh_config >/etc/ssh/ssh_config-bk 2>&1
    echo "StrictHostKeyChecking no" >>/etc/ssh/ssh_config-bk 2>&1
    mv /etc/ssh/ssh_config-bk /etc/ssh/ssh_config >>$LOGFILE 2>&1
    chmod 644 /etc/ssh/ssh_config >>$LOGFILE 2>&1
    
}


################################################################################
#
#   Function: # 建立 root 的 信任关系
#   Desctiption: 
#
################################################################################
setssh_root()
{	
	local ipaddr=$1
	rerootdir=`ssh $ipaddr "rm -rf {/.ssh,/root/.ssh} >/dev/null 2>&1;cat /etc/passwd" | grep "^root:" | awk -F: '{print $6}'`
	if [ "$rerootdir" = "" ]
	then		
		echo "Failed to get the home directory of user root" >>$LOGFILE 2>&1		
		return 1
	fi		
	scp -rp /tmp/SSHKEY/.ssh $ipaddr:$rerootdir
	if [ $? -ne 0 ]
	then
		echo "Failed to scp SSH keys to $ipaddr:$rerootdir" >>$LOGFILE 2>&1		
		return 1
	fi
	scp -p /etc/ssh/ssh_config $ipaddr:/etc/ssh/ >>$LOGFILE 2>&1
	ssh $ipaddr "chmod 644 /etc/ssh/ssh_config" >>$LOGFILE 2>&1
	ssh_so=`ssh $ipaddr "ls /usr/sfw/lib/libcrypto_extra.so.0.9.7" 2>/dev/null`
	[ "$ssh_so" = "" ] && scp -p /usr/sfw/lib/libcrypto_extra.so.0.9.7 ${ipaddr}:/usr/sfw/lib/ >>$LOGFILE 2>&1
	unset ipaddr
	return 0
}


################################################################################
#
#   Function: # 建立 omcuser 的 信任关系
#   Desctiption: 
#
################################################################################
setssh_omcuser()	
{
	local ipaddr=$1
	omcuserdir=`cat /etc/passwd | grep "^omcuser:" | awk -F: '{print $6}'`
	if [ "$omcuserdir" = "" ]
	then
		echo "Failed to get the home directory of user omcuser" >>$LOGFILE 2>&1
		return 1
	fi
	if ls -l $omcuserdir | grep "^l" >>$LOGFILE 2>&1
	then
	    omcuserdir=`ls -l $omcuserdir | awk '{print $NF}'`
	    localregsr=1
	fi
	#mkdir -p $omcuserdir >>$LOGFILE 2>&1	
	#[ -d $omcuserdir/.ssh ] && rm -rf $omcuserdir/.ssh 
	#cd $rootdir		
	#cp -rp .ssh $omcuserdir/
	omcusergroupid=`cat /etc/passwd | grep "^omcuser:" | awk -F: '{print $4}'`
	omcusergroup=`cat /etc/group | awk -F: '$3=="'$omcusergroupid'" {print $1}'`
	if [ "$omcusergroup" = "" ]
	then
		echo "Failed to get the group name of user omcuser" >>$LOGFILE 2>&1
		return 1
	fi 
	#chown -R omcuser:$omcusergroup $omcuserdir
	
	reomcuserdir=`ssh $ipaddr "cat /etc/passwd" | grep "^omcuser" | awk -F: '{print $6}'`
	if [ "$reomcuserdir" = "" ]
	then
		echo "Failed to get the home directory of user omcuser from the remote system" >>$LOGFILE 2>&1
		return 2
	fi
	ISLINK=`ssh $ipaddr "ls -l $reomcuserdir" | grep "^l"`
	if [ "$ISLINK" != "" ]
	then
	    reomcuserdir=`ssh $ipaddr "ls -l $reomcuserdir" | awk '{print $NF}'`
	    remoteregsr=1
	fi
	
	ssh $ipaddr "mkdir -p $reomcuserdir; [ -d $reomcuserdir/.ssh ] && rm -rf $reomcuserdir/.ssh" >>$LOGFILE 2>&1
	scp -rp /tmp/SSHKEY_OMC/.ssh $ipaddr:$reomcuserdir >>$LOGFILE 2>&1
	ssh $ipaddr "chown -R omcuser:$omcusergroup $reomcuserdir; [ -d /etc/SSHBACKUP ] && rm -rf /etc/SSHBACKUP; mkdir -p /etc/SSHBACKUP; cp -rp $reomcuserdir/.ssh /etc/SSHBACKUP/" >>$LOGFILE 2>&1
	
	LOMOUNT=`dirname $omcuserdir`
	#REMOUNT=`ssh $ipaddr "dirname $reomcuserdir"`
	
	
	#针对于suncluster，还需进行如下操作
    if pkginfo | grep SUNWsczu >>$LOGFILE 2>&1
    then     
        if df -h | grep "$LOMOUNT" >>$LOGFILE 2>&1
        then
            echo '#!/bin/bash
. /.profile-EIS
if ! df -h | grep "'$LOMOUNT'" >/dev/null 2>&1
then
    mkdir -p '$omcuserdir'
    cd '$rootdir'
    [ -d '$omcuserdir'/.ssh ] && rm -rf '$omcuserdir'/.ssh
    cp -rp /etc/SSHBACKUP/.ssh '$omcuserdir'
    chmod 755 '$omcuserdir'
    chown -R omcuser:'$omcusergroup' '$omcuserdir'
    grep -v "/usr/bin/SC_createssh.sh" /var/spool/cron/crontabs/root >/tmp/crontab-bk
    crontab /tmp/crontab-bk
    rm -rf /tmp/crontab-bk
    rm -rf /usr/bin/SC_createssh.sh
fi'>/usr/bin/SC_createssh.sh

            chmod 755 /usr/bin/SC_createssh.sh
            if ! cat /var/spool/cron/crontabs/root | grep "/usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
            then
                cat /var/spool/cron/crontabs/root >/tmp/crontab-bk 
                echo '* * * * * /usr/bin/SC_createssh.sh' >>/tmp/crontab-bk
                crontab /tmp/crontab-bk
                [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
            fi           
        else
            echo '#!/bin/bash
. /.profile-EIS
if ! df -h | grep "'$LOMOUNT'" >/dev/null 2>&1
then
    mkdir -p '$reomcuserdir'
    cd '$rerootdir'
    [ -d '$reomcuserdir'/.ssh ] && rm -rf '$reomcuserdir'/.ssh
    cp -rp /etc/SSHBACKUP/.ssh '$reomcuserdir'
    chmod 755 '$reomcuserdir'
    chown -R omcuser:'$omcusergroup' '$reomcuserdir'
    grep -v "/usr/bin/SC_createssh.sh" /var/spool/cron/crontabs/root >/tmp/crontab-bk
    crontab /tmp/crontab-bk
    rm -rf /tmp/crontab-bk
    rm -rf /usr/bin/SC_createssh.sh
fi'>/tmp/SC_createssh.sh
            scp /tmp/SC_createssh.sh $ipaddr:/usr/bin/ >>$LOGFILE 2>&1
            ssh $ipaddr "chmod 755 /usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
            [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
            scp $ipaddr:/var/spool/cron/crontabs/root /tmp/crontab-bk >>$LOGFILE 2>&1
            [ ! -f /tmp/crontab-bk ] && return 2 
            if ! cat /tmp/crontab-bk 2>/dev/null | grep "/usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
            then             
                echo '* * * * * /usr/bin/SC_createssh.sh' >>/tmp/crontab-bk          
                scp /tmp/crontab-bk $ipaddr:/tmp/ >>$LOGFILE 2>&1
                ssh $ipaddr "crontab /tmp/crontab-bk; rm -rf /tmp/crontab-bk" >>$LOGFILE 2>&1
            fi
            [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
        fi
        
    fi
    
    #针对于VCS方案，还需进行如下操作
       
    if ! cat /opt/sybase/interfaces | grep "^SYB[0-9]" >>$LOGFILE 2>&1 && pkginfo VRTSvcs >>$LOGFILE 2>&1
    then     
        if [ $localregsr -eq 1 -o $remoteregsr -eq 1 ]
        then
            if df -h | grep "/export/sync" >>$LOGFILE 2>&1
            then
                echo '#!/bin/bash
. /.profile-EIS
if ! df -h | grep "/export/sync" >/dev/null 2>&1
then
    mkdir -p /export/home/omc
    cd '$rootdir'
    [ -d /export/home/omc/.ssh ] && rm -rf /export/home/omc/.ssh
    cp -rp /etc/SSHBACKUP/.ssh /export/home/omc
    chmod 755 /export/home/omc
    chown -R omcuser:'$omcusergroup' /export/home/omc
    grep -v "/usr/bin/SC_createssh.sh" /var/spool/cron/crontabs/root >/tmp/crontab-bk
    crontab /tmp/crontab-bk
    rm -rf /tmp/crontab-bk
    rm -rf /usr/bin/SC_createssh.sh
fi'>/usr/bin/SC_createssh.sh

                chmod 755 /usr/bin/SC_createssh.sh
                if ! cat /var/spool/cron/crontabs/root | grep "/usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
                then
                    cat /var/spool/cron/crontabs/root >/tmp/crontab-bk 
                    echo '* * * * * /usr/bin/SC_createssh.sh' >>/tmp/crontab-bk
                    crontab /tmp/crontab-bk
                fi
                [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk 
            else
                echo '#!/bin/bash
. /.profile-EIS
if df -h | grep "/export/sync" >/dev/null 2>&1
then
    mkdir -p /export/sync/omc
    cd '$rootdir'
    [ -d /export/sync/omc/.ssh ] && rm -rf /export/sync/omc/.ssh
    cp -rp /etc/SSHBACKUP/.ssh /export/sync/omc
    chmod 755 /export/sync/omc
    chown -R omcuser:'$omcusergroup' /export/sync/omc
    grep -v "/usr/bin/SC_createssh.sh" /var/spool/cron/crontabs/root >/tmp/crontab-bk
    crontab /tmp/crontab-bk
    rm -rf /tmp/crontab-bk
    rm -rf /usr/bin/SC_createssh.sh
fi'>/usr/bin/SC_createssh.sh

                chmod 755 /usr/bin/SC_createssh.sh
                if ! cat /var/spool/cron/crontabs/root | grep "/usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
                then
                    cat /var/spool/cron/crontabs/root >/tmp/crontab-bk 
                    echo '* * * * * /usr/bin/SC_createssh.sh' >>/tmp/crontab-bk
                    crontab /tmp/crontab-bk
                fi
                [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk 
            fi
        
            ISLS=`ssh $ipaddr "cat /opt/sybase/interfaces" | grep "^SYB[0-9]"`
            ISVCS=`ssh $ipaddr "pkginfo VRTSvcs"`
            if [ "$ISLS" = "" -a "$ISVCS" != "" ]
            then
                MOUNTEXPORT=`ssh $ipaddr "df -h" 2>/dev/null | grep "/export/sync"`
                if [ "$MOUNTEXPORT" != "" ]
                then
                    echo '#!/bin/bash
. /.profile-EIS
if ! df -h | grep "/export/sync" >/dev/null 2>&1
then
    mkdir -p /export/home/omc
    cd '$rerootdir'
    [ -d /export/home/omc/.ssh ] && rm -rf /export/home/omc/.ssh
    cp -rp /etc/SSHBACKUP/.ssh /export/home/omc
    chmod 755 /export/home/omc
    chown -R omcuser:'$omcusergroup' /export/home/omc
    grep -v "/usr/bin/SC_createssh.sh" /var/spool/cron/crontabs/root >/tmp/crontab-bk
    crontab /tmp/crontab-bk
    rm -rf /tmp/crontab-bk
    rm -rf /usr/bin/SC_createssh.sh
fi'>/tmp/SC_createssh.sh
                    scp /tmp/SC_createssh.sh $ipaddr:/usr/bin/ >>$LOGFILE 2>&1
                    ssh $ipaddr "chmod 755 /usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
                    [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
                    scp $ipaddr:/var/spool/cron/crontabs/root /tmp/crontab-bk >>$LOGFILE 2>&1
                    [ ! -f /tmp/crontab-bk ] && return 2 
                    if ! cat /tmp/crontab-bk 2>/dev/null | grep "/usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
                    then               
                        echo '* * * * * /usr/bin/SC_createssh.sh' >>/tmp/crontab-bk          
                        scp /tmp/crontab-bk $ipaddr:/tmp/ >>$LOGFILE 2>&1
                        ssh $ipaddr "crontab /tmp/crontab-bk; rm -rf /tmp/crontab-bk" >>$LOGFILE 2>&1
                    fi
                    [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
                else
                    echo '#!/bin/bash
. /.profile-EIS
if df -h | grep "/export/sync" >/dev/null 2>&1
then
    mkdir -p /export/sync/omc
    cd '$rerootdir'
    [ -d /export/sync/omc/.ssh ] && rm -rf /export/sync/omc/.ssh
    cp -rp /etc/SSHBACKUP/.ssh /export/sync/omc
    chmod 755 /export/sync/omc
    chown -R omcuser:'$omcusergroup' /export/sync/omc
    grep -v "/usr/bin/SC_createssh.sh" /var/spool/cron/crontabs/root >/tmp/crontab-bk
    crontab /tmp/crontab-bk
    rm -rf /tmp/crontab-bk
    rm -rf /usr/bin/SC_createssh.sh
fi'>/tmp/SC_createssh.sh
                    scp /tmp/SC_createssh.sh $ipaddr:/usr/bin/ >>$LOGFILE 2>&1
                    ssh $ipaddr "chmod 755 /usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
                    [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
                    scp $ipaddr:/var/spool/cron/crontabs/root /tmp/crontab-bk >>$LOGFILE 2>&1
                    [ ! -f /tmp/crontab-bk ] && return 2 
                    if ! cat /tmp/crontab-bk 2>/dev/null | grep "/usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
                    then               
                        echo '* * * * * /usr/bin/SC_createssh.sh' >>/tmp/crontab-bk          
                        scp /tmp/crontab-bk $ipaddr:/tmp/ >>$LOGFILE 2>&1
                        ssh $ipaddr "crontab /tmp/crontab-bk; rm -rf /tmp/crontab-bk" >>$LOGFILE 2>&1
                    fi
                    [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
                fi
            fi
        fi           
    fi
    
    
    #针对于SLS 分布式方案，还需进行如下操作
       
    if cat /opt/sybase/interfaces 2>/dev/null | grep "^SYB[0-9]" >>$LOGFILE 2>&1
    then     
        if df -h | grep "$LOMOUNT" >>$LOGFILE 2>&1
        then
            echo '#!/bin/bash
. /.profile-EIS
if ! df -h | grep "'$LOMOUNT'" >/dev/null 2>&1
then
    mkdir -p '$omcuserdir'
    cd '$rootdir'
    [ -d '$omcuserdir'/.ssh ] && rm -rf '$omcuserdir'/.ssh
    cp -rp /etc/SSHBACKUP/.ssh '$omcuserdir'
    chmod 755 '$omcuserdir'
    chown -R omcuser:'$omcusergroup' '$omcuserdir'
    grep -v "/usr/bin/SC_createssh.sh" /var/spool/cron/crontabs/root >/tmp/crontab-bk
    crontab /tmp/crontab-bk
    rm -rf /tmp/crontab-bk
    rm -rf /usr/bin/SC_createssh.sh
fi'>/usr/bin/SC_createssh.sh

            chmod 755 /usr/bin/SC_createssh.sh
            if ! cat /var/spool/cron/crontabs/root | grep "/usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
            then
                cat /var/spool/cron/crontabs/root >/tmp/crontab-bk 
                echo '* * * * * /usr/bin/SC_createssh.sh' >>/tmp/crontab-bk
                crontab /tmp/crontab-bk
            fi
            [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk  
        fi
        
        ISLS=`ssh $ipaddr "cat /opt/sybase/interfaces" 2>/dev/null | grep "^SYB[0-9]"`
        if [ "$ISLS" != "" ]    
        then   
            MOUNTEXPORT=`ssh $ipaddr "df -h" 2>/dev/null | grep "$LOMOUNT"`
            if [ "$MOUNTEXPORT" != "" ]
            then
                echo '#!/bin/bash
. /.profile-EIS
if ! df -h | grep "'$LOMOUNT'" >/dev/null 2>&1
then
    mkdir -p '$reomcuserdir'
    cd '$rerootdir'
    [ -d '$reomcuserdir'/.ssh ] && rm -rf '$reomcuserdir'/.ssh
    cp -rp /etc/SSHBACKUP/.ssh '$reomcuserdir'
    chmod 755 '$reomcuserdir'
    chown -R omcuser:'$omcusergroup' '$reomcuserdir'
    grep -v "/usr/bin/SC_createssh.sh" /var/spool/cron/crontabs/root >/tmp/crontab-bk
    crontab /tmp/crontab-bk
    rm -rf /tmp/crontab-bk
    rm -rf /usr/bin/SC_createssh.sh
fi'>/tmp/SC_createssh.sh
                scp /tmp/SC_createssh.sh $ipaddr:/usr/bin/ >>$LOGFILE 2>&1
                ssh $ipaddr "chmod 755 /usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
                [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
                scp $ipaddr:/var/spool/cron/crontabs/root /tmp/crontab-bk >>$LOGFILE 2>&1
                [ ! -f /tmp/crontab-bk ] && return 2 
                if ! cat /tmp/crontab-bk 2>/dev/null | grep "/usr/bin/SC_createssh.sh" >>$LOGFILE 2>&1
                then               
                    echo '* * * * * /usr/bin/SC_createssh.sh' >>/tmp/crontab-bk          
                    scp /tmp/crontab-bk $ipaddr:/tmp/ >>$LOGFILE 2>&1
                    ssh $ipaddr "crontab /tmp/crontab-bk; rm -rf /tmp/crontab-bk" >>$LOGFILE 2>&1
                fi
                [ -f /tmp/crontab-bk ] && rm -rf /tmp/crontab-bk
            fi
        fi           
    fi
    
	unset ipaddr
	return 0
}


main()
{
	if [ "`id | awk '{print $1}'`" != "uid=0(root)" ]
    then
    	echo ""
    	echo "Error: You must be root,please login by root and then run this script"
    	echo ""
    	exit 1
    fi
    
    if [ "`uname -s`" != "SunOS" ]
    then
    	echo ""
    	echo "Error: I'm sorry, this script must be run in SunOS platform"
    	echo ""
    	exit 1
    fi 
 	      
    yesno   
    create_ssh_key
    i=1
    rootsuip=""
    omcusersuip=""
    for localIP in $localip
    do
        ipaddrlist=`echo $ipaddrlist | sed 's/\<'$localIP'\>//'`
    done 
    ipaddrlist="$ipaddrlist $HOSTNAME"
    for ipaddr in $ipaddrlist
    do
    	echo ""
    	echo "------------------------------------------------------------------"
    	if [ "$ipaddr" = "$HOSTNAME" ]
    	then
    	    echo -e "\033[1;33m$i. Setting up the SSH trust relation for local system, please wait...\033[m"
    	else   	    
    	    echo -e "\033[1;33m$i. Setting up the SSH trust relation for IP address $ipaddr, please wait...\033[m"  	    
    	fi
    	    
    	if echo "$deadip" | grep -w "$ipaddr" >/dev/null 2>&1
    	then
    		echo -e "\033[1;31mSetting up the SSH trust relation for user root failed\033[m"   			
    		echo -e "\033[1;31mSetting up the SSH trust relation for user omcuser failed\033[m"
    		echo "Reason: Faild to ping IP address $ipaddr"
    		echo "------------------------------------------------------------------"
    		i=`expr $i + 1`
    		continue
    	elif [ "$ipaddr" = "$HOSTNAME" ]
    	then 
    	    ssh $ipaddr "echo" >/dev/null 2>&1    	     		
    		echo -e "\033[1;32mSetting up the SSH trust relation for user root succeeded\033[m"
    		omcuserdir=`cat /etc/passwd | grep "^omcuser:" | awk -F: '{print $6}'`
	        if [ "$omcuserdir" = "" ]
	        then
		        echo -e "\033[1;31mSetting up the SSH trust relation for user omcuser failed\033[m"
		        echo "Reason: User omcuser may not be created in the local system"
    		    echo "------------------------------------------------------------------"
    		    i=`expr $i + 1`
    		    continue
	        fi
	        if ls -l $omcuserdir | grep "^l" >>$LOGFILE 2>&1
	        then
	            omcuserdir=`ls -l $omcuserdir | awk '{print $NF}'`
	        fi
	        mkdir -p $omcuserdir >>$LOGFILE 2>&1 	
	        [ -d $omcuserdir/.ssh ] && rm -rf $omcuserdir/.ssh	        		
	        cp -rp /tmp/SSHKEY_OMC/.ssh $omcuserdir/
	        [ -d /etc/SSHBACKUP ] && rm -rf /etc/SSHBACKUP
	        mkdir -p /etc/SSHBACKUP
	        cp -rp /tmp/SSHKEY_OMC/.ssh /etc/SSHBACKUP
	        omcusergroupid=`cat /etc/passwd | grep "^omcuser:" | awk -F: '{print $4}'`
	        omcusergroup=`cat /etc/group | awk -F: '$3=="'$omcusergroupid'" {print $1}'`
	        if [ "$omcusergroup" = "" ]
	        then
		        echo -e "\033[1;31mSetting up the SSH trust relation for user omcuser failed\033[m"
		        echo "Reason: User omcuser may not be created in the local system"
    		    echo "------------------------------------------------------------------"
    		    i=`expr $i + 1`
    		    continue
	        fi 
	        chown -R omcuser:$omcusergroup $omcuserdir
	        chmod 755 $omcuserdir  		     			
    		echo -e "\033[1;32mSetting up the SSH trust relation for user omcuser succeeded\033[m"  		
    		echo "------------------------------------------------------------------"
    		i=`expr $i + 1`
    		continue
    	else   		
    		setssh_root $ipaddr
    		if [ $? -ne 0 ]
    		then
    			echo -e "\033[1;31mSetting up the SSH trust relation for user root failed\033[m"   			
    			echo -e "\033[1;31mSetting up the SSH trust relation for user omcuser failed\033[m"
    			echo "Reason: Failed to ssh IP address $ipaddr"
    			echo "------------------------------------------------------------------"
    			i=`expr $i + 1`
    			continue
    		else
    		    rootsuip="$rootsuip $ipaddr"
    			echo -e "\033[1;32mSetting up the SSH trust relation for user root succeeded\033[m"   			
    		fi
    		setssh_omcuser $ipaddr
    		ret=$?
    		if [ $ret -eq 1 ]
    		then
    			echo -e "\033[1;31mSetting uping the SSH trust relation for user omcuser failed\033[m"
    			echo "Reason: User omcuser may not be created in the local system"
    			echo "------------------------------------------------------------------"
    			i=`expr $i + 1`
    			continue
    		elif [ $ret -eq 2 ]
    		then
    			echo -e "\033[1;31mSetting up the SSH trust relation for user omcuser failed\033[m"
    			echo "Reason: User omcuser may not be created in the remote system"
    			echo "------------------------------------------------------------------"
    			i=`expr $i + 1`
    			continue
    		elif [ $ret -eq 0 ]
    		then
    			omcusersuip="$omcusersuip $ipaddr"
    			echo -e "\033[1;32mSetting up the SSH trust relation for user omcuser succeeded\033[m"
    			echo "------------------------------------------------------------------"
    			i=`expr $i + 1`
    			continue
    		else
    			echo "------------------------------------------------------------------"
    			i=`expr $i + 1`
    			continue
    		fi
    	fi
    done
   
    echo ""
 	[ -d /tmp/SSHKEY/.ssh ] && rm -rf /tmp/SSHKEY/.ssh
 	[ -d /tmp/SSHKEY_OMC/.ssh ] && rm -rf /tmp/SSHKEY_OMC/.ssh
 	exit 0
}

main
