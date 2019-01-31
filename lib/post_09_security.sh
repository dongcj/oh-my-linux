#!/usr/bin/env bash
#
# Author: krrish <krrishdo@gmail.com>
# description: Linux Service config
#

######################################################################
# 作用: 配置 SELINUX
# 用法: Config_Selinux
# 注意：
######################################################################
Config_Selinux() {

    Log DEBUG "Config selinux..."
    
    SELINUX_CONF=/etc/selinux/config
    CURRENT_SELINUX_VALUE=`awk -F"=" '/^SELINUX=/ {print $2}' $SELINUX_CONF`
    if [ -f $SELINUX_CONF ]; then
        if [ "$CURRENT_SELINUX_VALUE" != "disabled" ]; then
            sed -i "/^SELINUX=/s/$CURRENT_SELINUX_VALUE/disabled/g" $SELINUX_CONF
        fi
    fi
    setenforce 0 >&/dev/null
    
    Log DEBUG "Config selinux successful."
}

######################################################################
# 作用: 配置 Security
# 用法: Config_Security
# 注意：
######################################################################
Config_Security() {

    Log DEBUG "Config security..."
    
    sed -i s'/Defaults.*requiretty/#Defaults requiretty'/g /etc/sudoers
    
    # sshd config
    sed -i "s/#MaxAuthTries 6/MaxAuthTries 6/" /etc/ssh/sshd_config 
    
    # add continue input failure 3 ,passwd unlock time 5 minite
    # this 
    #sed -i 's#auth        required      pam_env.so#auth        required      pam_env.so\nauth       required       pam_tally.so  onerr=fail deny=3 unlock_time=300\nauth           required     /lib/security/$ISA/pam_tally.so onerr=fail deny=3 unlock_time=300#' /etc/pam.d/system-auth

    Log DEBUG "Config security successful."
}


######################################################################
# 作用: 配置 Limits
# 用法: Config_Limits
# 注意：
######################################################################
Config_Limits() {

    Log DEBUG "Config limits..."
    
    ulimit -n 65536
     
    #/etc/security/limits.conf
    LIMITS_CONF=/etc/security/limits.conf
    grep -q "^[^#].*soft.*nofile" $LIMITS_CONF || echo "*       soft    nofile   32768" >>$LIMITS_CONF
    grep -q "^[^#].*hard.*nofile" $LIMITS_CONF || echo "*       hard    nofile   65536" >>$LIMITS_CONF
    grep -q " *root *- *nofile" $LIMITS_CONF   || echo "root    -       nofile   65536" >>$LIMITS_CONF

    Log DEBUG "Config limits successful."
}

######################################################################
# 作用: 配置 Quota
# 用法: Config_Quota
# 注意：
######################################################################
Config_Quota () {
  QUOTADIRS="/ /var /var/www /home /home/mail"
  for i in $QUOTADIRS
  do
    Q_ENTRY=$(grep -o "^.*[[:space:]]\+${i}[[:space:]]\+.*[[:space:]]\+.*[[:space:]]\+[0-9][[:space:]]\+[0-9].*$" /etc/fstab)
    if [ "$Q_ENTRY" != "" ] && [ "$(echo $Q_ENTRY|grep -o 'usrquota')" = "" ]; then
      Q_OPTIONS=$(echo $Q_ENTRY|awk '{print $4}')
      Q_NEWENTRY=$(echo "$Q_ENTRY"|sed "s/$Q_OPTIONS/$Q_OPTIONS,usrquota/")
      sed -i "s%$Q_ENTRY%$Q_NEWENTRY%" /etc/fstab
    fi
  done
debug "Set up quota"
return 0
}



clean_efiboot ()
{
    for i in "windows" "debian" "ubuntu" "centos"
    do
        BOOT=$(efibootmgr| grep -i $i | egrep -o "[A-Z0-9]{4}")
        if [ "${BOOT}" != "" ]; then
            for ENTRY in $BOOT
            do
                efibootmgr -q -b ${ENTRY} -B
            done
        else
            echo "No more boot entrys present."
        fi
    done

    return 0
}