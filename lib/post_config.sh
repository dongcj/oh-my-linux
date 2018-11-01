#!/usr/bin/env bash
#
# Author: krrish <krrishdo@gmail.com>
# description: Linux Service config
#

######################################################################
# 作用: 配置 Linux 系统语言
# 用法: Config_Lang
# 注意：
######################################################################
Config_Lang() {

    Log DEBUG "Config language..."
    
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    locale-gen en_US.UTF-8

    PROFILE_CONF=/etc/profile
    if ! grep -q "LANG=en_US.UTF-8" $PROFILE_CONF; then
        echo "export LANG=en_US.UTF-8" >>$PROFILE_CONF
        echo "export LC=en_US.UTF-8" >>$PROFILE_CONF
        echo "export LC_ALL=en_US.UTF-8" >>$PROFILE_CONF
    fi
    source $PROFILE_CONF
    
    Log DEBUG "Config language successful."
}

######################################################################
# 作用: 配置时区
# 用法: Config_Timezone
# 注意：
######################################################################
Config_Timezone() {

    Log DEBUG "Config timezone..."
    
    localtime_file=/etc/localtime
    clock_file=/etc/sysconfig/clock
    if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
        # remove the old localtime file
        rm -rf ${localtime_file}.old && mv ${localtime_file} ${localtime_file}.old
        ln -s /usr/share/zoneinfo/Asia/Shanghai ${localtime_file}

        if [ -f $clock_file ]; then
            sed -i '/^[^#]/d' $clock_file
            echo "ZONE=\"Asia/Shanghai\"" >>$clock_file
            echo "UTC=true" >>$clock_file
        fi
        # update the systime to hardware clock
        hwclock --systohc
    fi
    
    Log DEBUG "Config timezone successful."
}



######################################################################
# 作用: et needed locales and configure them + timezone accordingly
# 用法: Config_Locales
# 注意：
######################################################################
Config_Locales () {
  local LANGID=$1
  if [ "$LANGID" != "" ]; then
   LANGID_LOCALES="en_US.UTF-8 $(wget -q http://${FILESERVER_IP}/others/scripts/languages/lang-map.txt -O -|grep "^$LANGID"|cut -d \" -f 2)"
  else
   LANGID_LOCALES="en_US.UTF-8"
  fi

  # magic working :o)
  for LOCALE_CURRENT in $LANGID_LOCALES; do
   CHARSET_CURRENT=${LOCALE_CURRENT%%.*}
   ENCODING_CURRENT=${LOCALE_CURRENT##*.}
   LANGUAGE_CURRENT=${CHARSET_CURRENT%%_*}
   COUNTRY_CURRENT=${CHARSET_CURRENT##*_}

   # for old non-belocs locale-gen we need a special formatting
   LOCALEGEN_CURRENT="${LOCALEGEN_CURRENT}\n$LOCALE_CURRENT $ENCODING_CURRENT"

   # if unset, we set the first available locale in list to be default
   [ "$LANG_DEFAULT" = "" ] && LANG_DEFAULT=$CHARSET_CURRENT
   [ "$TZ_DEFAULT" = "" ] && TZ_DEFAULT=$COUNTRY_CURRENT

   # well, if there is a country code identical to the language code
   # we assume that should be a better default than just choosing the first
   # entry in the list
   if echo $LANGUAGE_CURRENT|grep -i $COUNTRY_CURRENT &>/dev/null; then
    LANG_DEFAULT=$CHARSET_CURRENT
    TZ_DEFAULT=$COUNTRY_CURRENT
    ENCODING_DEFAULT=$ENCODING_CURRENT
    LANGUAGE_PRIORITY=$CHARSET_CURRENT
   fi

   # generate languages fallback list for /etc/environment
   if [ "$LANGUAGE_LIST" = "" -a "$CHARSET_CURRENT" != "$LANGUAGE_PRIORITY" ]; then
    LANGUAGE_LIST="$CHARSET_CURRENT"
   elif [ "$CHARSET_CURRENT" != "$LANGUAGE_PRIORITY" ]; then
    LANGUAGE_LIST="${LANGUAGE_LIST}:$CHARSET_CURRENT"
   fi
  done

  # set encoding default if not already set
  [ "$ENCODING_DEFAULT" = "" ] && ENCODING_DEFAULT="UTF-8"

  # if we have detected a language priority, add it in front of the defaults list
  if [ "$LANGUAGE_PRIORITY" != "" ]; then
   LANGUAGE_DEFAULT="${LANGUAGE_PRIORITY}:$LANGUAGE_LIST"
  else
   LANGUAGE_DEFAULT="$LANGUAGE_LIST"
  fi
  echo -en "\n - configuring language environment: "

  ENV_PRE=$(grep -v '^LANG.*=' /etc/environment 2>/dev/null)

  cat << EOC > /etc/environment
$ENV_PRE
LANG="${LANG_DEFAULT}.$ENCODING_DEFAULT"
LANGUAGE="$LANGUAGE_DEFAULT"
EOC
  cat << EOC > /etc/default/locale
LANG="${LANG_DEFAULT}.$ENCODING_DEFAULT"
LANGUAGE="$LANGUAGE_DEFAULT"
EOC

  cat << EOC
>> LANG="${LANG_DEFAULT}.$ENCODING_DEFAULT"
>> LANGUAGE="$LANGUAGE_DEFAULT"
EOC

  # check if we have locale-gen
  if which locale-gen &> /dev/null; then
   echo -en "\n - generating locales: "
   LOCALEGEN_DEFAULT=$(echo -e "$LOCALEGEN_CURRENT")
   echo -e "$LOCALEGEN_DEFAULT" > /etc/locale.gen
   locale-gen $LANGID_LOCALES &>/dev/null
  fi

  TZ_LIST="
  AD Europe/Andorra
  AE Asia/Dubai
  AF Asia/Kabul
  AG America/Antigua
  AI America/Anguilla
  AL Europe/Tirane
  AM Asia/Yerevan
  AN America/Curacao
  AO Africa/Luanda
  AR America/Buenos_Aires
  AS Pacific/Pago_Pago
  AT Europe/Vienna
  AW America/Aruba
  AX Europe/Mariehamn
  AZ Asia/Baku
  BA Europe/Sarajevo
  BB America/Barbados
  BD Asia/Dhaka
  BE Europe/Brussels
  BF Africa/Ouagadougou
  BG Europe/Sofia
  BH Asia/Bahrain
  BI Africa/Bujumbura
  BJ Africa/Porto-Novo
  BM Atlantic/Bermuda
  BN Asia/Brunei
  BO America/La_Paz
  BS America/Nassau
  BT Asia/Thimphu
  BW Africa/Gaborone
  BY Europe/Minsk
  BZ America/Belize
  CC Indian/Cocos
  CF Africa/Bangui
  CG Africa/Brazzaville
  CH Europe/Zurich
  CI Africa/Abidjan
  CK Pacific/Rarotonga
  CM Africa/Douala
  CN Asia/Shanghai
  CO America/Bogota
  CR America/Costa_Rica
  CS Europe/Belgrade
  CU America/Havana
  CV Atlantic/Cape_Verde
  CX Indian/Christmas
  CY Asia/Nicosia
  CZ Europe/Prague
  DE Europe/Berlin
  DJ Africa/Djibouti
  DK Europe/Copenhagen
  DM America/Dominica
  DO America/Santo_Domingo
  DZ Africa/Algiers
  EE Europe/Tallinn
  EG Africa/Cairo
  EH Africa/El_Aaiun
  ER Africa/Asmera
  ET Africa/Addis_Ababa
  FI Europe/Helsinki
  FJ Pacific/Fiji
  FK Atlantic/Stanley
  FO Atlantic/Faeroe
  FR Europe/Paris
  GA Africa/Libreville
  GB Europe/London
  GD America/Grenada
  GE Asia/Tbilisi
  GF America/Cayenne
  GH Africa/Accra
  GI Europe/Gibraltar
  GM Africa/Banjul
  GN Africa/Conakry
  GP America/Guadeloupe
  GQ Africa/Malabo
  GR Europe/Athens
  GS Atlantic/South_Georgia
  GT America/Guatemala
  GU Pacific/Guam
  GW Africa/Bissau
  GY America/Guyana
  HK Asia/Hong_Kong
  HN America/Tegucigalpa
  HR Europe/Zagreb
  HT America/Port-au-Prince
  HU Europe/Budapest
  IE Europe/Dublin
  IL Asia/Jerusalem
  IN Asia/Calcutta
  IO Indian/Chagos
  IQ Asia/Baghdad
  IR Asia/Tehran
  IS Atlantic/Reykjavik
  IT Europe/Rome
  JM America/Jamaica
  JO Asia/Amman
  JP Asia/Tokyo
  KE Africa/Nairobi
  KG Asia/Bishkek
  KH Asia/Phnom_Penh
  KM Indian/Comoro
  KN America/St_Kitts
  KP Asia/Pyongyang
  KR Asia/Seoul
  KW Asia/Kuwait
  KY America/Cayman
  LA Asia/Vientiane
  LB Asia/Beirut
  LC America/St_Lucia
  LI Europe/Vaduz
  LK Asia/Colombo
  LR Africa/Monrovia
  LS Africa/Maseru
  LT Europe/Vilnius
  LU Europe/Luxembourg
  LV Europe/Riga
  LY Africa/Tripoli
  MA Africa/Casablanca
  MC Europe/Monaco
  MD Europe/Chisinau
  MG Indian/Antananarivo
  MH Pacific/Majuro
  MK Europe/Skopje
  ML Africa/Bamako
  MM Asia/Rangoon
  MO Asia/Macau
  MP Pacific/Saipan
  MQ America/Martinique
  MR Africa/Nouakchott
  MS America/Montserrat
  MT Europe/Malta
  MU Indian/Mauritius
  MV Indian/Maldives
  MW Africa/Blantyre
  MY Asia/Kuala_Lumpur
  MZ Africa/Maputo
  NA Africa/Windhoek
  NC Pacific/Noumea
  NE Africa/Niamey
  NF Pacific/Norfolk
  NG Africa/Lagos
  NI America/Managua
  NL Europe/Amsterdam
  NO Europe/Oslo
  NP Asia/Katmandu
  NR Pacific/Nauru
  NU Pacific/Niue
  OM Asia/Muscat
  PA America/Panama
  PE America/Lima
  PG Pacific/Port_Moresby
  PH Asia/Manila
  PK Asia/Karachi
  PL Europe/Warsaw
  PM America/Miquelon
  PN Pacific/Pitcairn
  PR America/Puerto_Rico
  PS Asia/Gaza
  PW Pacific/Palau
  PY America/Asuncion
  QA Asia/Qatar
  RE Indian/Reunion
  RO Europe/Bucharest
  RW Africa/Kigali
  SA Asia/Riyadh
  SB Pacific/Guadalcanal
  SC Indian/Mahe
  SD Africa/Khartoum
  SE Europe/Stockholm
  SG Asia/Singapore
  SH Atlantic/St_Helena
  SI Europe/Ljubljana
  SJ Europe/Oslo
  SK Europe/Bratislava
  SL Africa/Freetown
  SM Europe/San_Marino
  SN Africa/Dakar
  SO Africa/Mogadishu
  SR America/Paramaribo
  ST Africa/Sao_Tome
  SV America/El_Salvador
  SY Asia/Damascus
  SZ Africa/Mbabane
  TC America/Grand_Turk
  TD Africa/Ndjamena
  TF Indian/Kerguelen
  TG Africa/Lome
  TH Asia/Bangkok
  TJ Asia/Dushanbe
  TK Pacific/Fakaofo
  TL Asia/Dili
  TM Asia/Ashgabat
  TN Africa/Tunis
  TO Pacific/Tongatapu
  TR Europe/Istanbul
  TT America/Port_of_Spain
  TV Pacific/Funafuti
  TW Asia/Taipei
  TZ Africa/Dar_es_Salaam
  UA Europe/Kiev
  UG Africa/Kampala
  UY America/Montevideo
  UZ Asia/Samarkand
  VA Europe/Vatican
  VC America/St_Vincent
  VE America/Caracas
  VG America/Tortola
  VI America/St_Thomas
  VN Asia/Saigon
  VU Pacific/Efate
  WF Pacific/Wallis
  WS Pacific/Apia
  YE Asia/Aden
  YT Indian/Mayotte
  ZA Africa/Johannesburg
  ZM Africa/Lusaka
  ZW Africa/Harare
  "
  TZ_REAL=$(echo "$TZ_LIST"|grep "^$TZ_DEFAULT"|cut -d ' ' -f 2)
  if [ -f /usr/share/zoneinfo/$TZ_REAL ]; then
   [ -e /etc/localtime ] && rm -f /etc/localtime
   cp /usr/share/zoneinfo/$TZ_REAL /etc/localtime
   echo $TZ_REAL > /etc/timezone
  fi
debug "Set timezone to ${TZ_REAL}"
return 0
} 



######################################################################
# 作用: 禁用 IPv6
# 用法: Disable_IPv6
# 注意：
######################################################################
Disable_IPv6() {

    Log DEBUG "Disabling IPv6..."
    
    SYSCTL_CONF=/etc/sysctl.conf
    SYSCONFIG_NETWORK=/etc/sysconfig/network
    
    # one method
    [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && echo 1 >/proc/sys/net/ipv6/conf/all/disable_ipv6
    
    # another method
    if [ "`awk -F"=" '/net.ipv6.conf.all.disable_ipv6/ {print $2}' ${SYSCTL_CONF} | xargs`" != "1" ]; then
        sed -i '/net.ipv6.conf.all.disable_ipv6/d' ${SYSCTL_CONF}
        echo " " >>${SYSCTL_CONF}
        echo "# Disable IPv6 Globally" >>${SYSCTL_CONF}
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >>${SYSCTL_CONF}
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >>${SYSCTL_CONF}
        echo "net.ipv6.conf.lo.disable_ipv6 = 1" >>${SYSCTL_CONF}
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1
        sysctl -w net.ipv6.conf.lo.disable_ipv6=1
        sysctl -p >&/dev/null
    fi

    if [ -f $SYSCONFIG_NETWORK ]; then
        if grep -q "NETWORKING_IPV6" $SYSCONFIG_NETWORK; then
            sed -i 's/NETWORKING_IPV6=.*/NETWORKING_IPV6=no/' $SYSCONFIG_NETWORK
        fi
    fi
    
    Log DEBUG "Disable ipv6 successful."
}



######################################################################
# 作用: 配置 NTP 
# 用法: Config_NTP
# 注意：
######################################################################
Config_NTP ()
{
  # configure ntp
  if which ntpdate &> /dev/null; then
      echo "Adding crontab entry for ntpdate"
      HOUR=$(awk 'BEGIN{ print '$RANDOM' % 23}')
      MIN=$(awk 'BEGIN{ print '$RANDOM' % 59}')
      cat << EOC >/etc/crontab
$(cat /etc/crontab)
$MIN  $HOUR * * * root /usr/sbin/ntpdate ntp.${DOMAIN} >/dev/null 2>&1
EOC
      ntpdate ntp.${DOMAIN} >/dev/null 2>&1
  else
      echo "ntpdate not found, skipping..."
  fi

debug "Set up NTP with ntp.${DOMAIN}"
return 0
}

######################################################################
# 作用: 配置 vim 
# 用法: Config_Vim
# 注意：
######################################################################
Config_Vim() {

    Log DEBUG "Config vim..."

    # vim setting
    VIM_CONF=/etc/vim/vimrc
    if ! grep -q "Add by krrish" $VIM_CONF &>/dev/null; then
        echo "\" Add by krrish" >> $VIM_CONF
        echo "set history=1000" >> $VIM_CONF
        echo "set expandtab" >> $VIM_CONF
        echo "set ai" >> $VIM_CONF
        echo "set tabstop=4" >> $VIM_CONF
        echo "set shiftwidth=4" >> $VIM_CONF
        echo "set paste" >> $VIM_CONF
        echo "set hls" >> $VIM_CONF
        echo "colo delek" >> $VIM_CONF
        echo 'syntax on' >> $VIM_CONF
        echo >> $VIM_CONF
    fi

    # vim as default editor
    if ! grep -q "EDITOR=" $PROFILE_CONF; then
        echo "export EDITOR=vim" >>$PROFILE_CONF
    fi
    
    Log DEBUG "Config vim successful."
}   

######################################################################
# 作用: 配置常用命令别名 
# 用法: Config_Alias
# 注意：
######################################################################
Config_Alias() {

    Log DEBUG "Config alias..."
    
    cat <<EOF >~/.bash_aliases
    alias ls='ls --color=always'
    alias dir='dir --color=always'
    alias vdir='vdir --color=always'

    alias grep='grep --color=always'
    alias fgrep='fgrep --color=always'
    alias egrep='egrep --color=always'

    # some more ls aliases
    alias ll='ls -lrt'
    alias vi='vim'
EOF

    PROFILE_CONF=/etc/profile
    if ! grep -q "source ~/.bash_aliases" $PROFILE_CONF; then
        echo "source ~/.bash_aliases" >>$PROFILE_CONF
    fi
    Log DEBUG "Config alias successful."
}




######################################################################
# 作用: 配置源 
# 用法: Config_RepoSource
# 注意：
######################################################################
Config_RepoSource (){

  # enable intergenia mirrors
  cat << EOC > /etc/apt/sources.list
# main repository

deb http://${ACTUAL_MIRROR}/ubuntu xenial main universe multiverse restricted
deb-src http://${ACTUAL_MIRROR}/ubuntu xenial main universe multiverse restricted

# updates

deb http://${ACTUAL_MIRROR}/ubuntu xenial-updates main universe multiverse restricted
deb-src http://${ACTUAL_MIRROR}/ubuntu xenial-updates main universe multiverse restricted

# security updates

deb http://${ACTUAL_MIRROR}/ubuntu xenial-security main universe multiverse restricted
deb-src http://${ACTUAL_MIRROR}/ubuntu xenial-security main universe multiverse restricted
EOC

### Removed due to repo not existing TODO
# ${MIRROR_SITE} additional repositories

#deb http://${IG_MIRROR}/packages/deb/ xenial dedicated
#deb-src http://${IG_MIRROR}/packages/deb/ xenial dedicated
#EOC
    apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 517B2D5802760C2F &> /dev/null
    apt-key adv --recv-keys --keyserver keyserver.ubuntu.com AF294371B05EA496 &> /dev/null
    apt-get -qq update &>/dev/null
}


######################################################################
# 作用: 配置常用命令别名 
# 用法: Config_History
# 注意：
######################################################################
Config_History() {

    Log DEBUG "Config history..."
    
    # 1st Method: install bashhub-client, centralize store & search
    # curl -OL https://bashhub.com/setup && bash setup
    
    USER_IP=`who -u am i 2>/dev/null | awk '{print $NF}' | sed -e 's/[()]//g'`
    LOGNAME=`who -u am i | awk '{print $1}'`
    HISTDIR=/usr/local/.history
    
    if [ -z "$USER_IP" ]; then
        USER_IP=`hostname`
    fi

    if [ ! -d "$HISTDIR" ]; then
        mkdir -p $HISTDIR
        chmod 777 $HISTDIR
    fi

    if [ ! -d $HISTDIR/${LOGNAME} ]; then
        mkdir -p $HISTDIR/${LOGNAME}
        chmod 300 $HISTDIR/${LOGNAME}
    fi

    export HISTSIZE=4000

    DT=`date +"%Y%m%d_%H%M%S"`
    export HISTFILE="$HISTDIR/${LOGNAME}/${USER_IP}.history.$DT"
    export HISTTIMEFORMAT="[%Y.%m.%d %H:%M:%S] "
    chmod 600 $HISTDIR/${LOGNAME}/*.history* 2>/dev/null

    # sum function
    if [ -f ~/.bash_profile ]; then
        if ! grep -q "historysum()" ~/.bash_profile; then
            cat <<EOF >>~/.bash_profile
# historysum function add by Krrish

historysum() {

    #history
    printf "\tCOUNT\t\tCOMMAND\n";

    cat ~/.bash_history | awk '{ list[$1]++; } \
    END{
        for(i in list){
            printf("\t%d\t\t%s\n",list[i],i);
        }
    }' | sort -nrk 2 | head

}

EOF
        source ~/.bash_profile
        fi
    fi

# logrotate the history log
cat <<EOF >/etc/logrotate.d/history
${HISTDIR}/* {
    notifempty
    olddir ${HISTDIR}/old
    missingok
    sharedscripts
    copytruncate
}
EOF

    Log DEBUG "Config history successful."
}    


######################################################################
# 作用: 配置邮件 
# 用法: Config_Mail
# 注意：
######################################################################
Config_Mail() {
    
    Log DEBUG "Config mail..."
    
    # resolve postfix error
    postfix_conf=/etc/postfix/main.cf
    
    # Set up Postfix on local interface
    if [ -e "$postfix_conf" ]; then
      postconf -e 'inet_interfaces = 127.0.0.1'
      postconf -e 'default_transport = smtp'
      postconf -e 'relay_transport = smtp'
      postconf -e 'inet_protocols = ipv4'
    fi
    
    # no check mail
    PROFILE_CONF=/etc/profile
    if ! grep -q "unset MAILCHECK" $PROFILE_CONF; then
        echo "unset MAILCHECK" >> $PROFILE_CONF
    fi
    source $PROFILE_CONF

    Log DEBUG "Config mail successful."
}


######################################################################
# 作用: 配置库 
# 用法: Config_Lib
# 注意：
######################################################################
Config_Lib() {

    Log DEBUG "Config library..."
    
    # Append lib
    if ! grep -q "/usr/local/lib" /etc/ld.so.conf; then
        echo "/usr/local/lib/" >> /etc/ld.so.conf
    fi
    
    Log DEBUG "Config library successful."
}

######################################################################
# 作用: 配置库 
# 用法: Config_Snippets
# 注意：
######################################################################
Config_Snippets() {

    Log DEBUG "Config snippets..."
    
    ########### Config snippets ############
    # 将错误按键的beep声关掉。stop the“beep"
    cp -rLfap /etc/inputrc /etc/inputrc.origin
    sed -i '/#set bell-style none/s/#set bell-style none/set bell-style none/' /etc/inputrc

    Log DEBUG "Config snippets successful."
}

######################################################################
# 作用: 执行清理 
# 用法: CleanUP
# 注意：
######################################################################
CleanUP() {
  apt-get clean
  rm /root/.bash_history
  rm -rf /var/log/installer
  for i in $(find /var/log -type f -not -name "post-install.log" -print|xargs); do echo >$i; done
  debug "Cleaned up after post-install"
return 0
} 

######################################################################
# 作用: 配置静态 IP via /etc/network/interfaces
# 用法: Config_Network
# 注意：
######################################################################
Config_Network () {
  cat << EOF > /usr/local/bin/setup_network.sh
DEVICES="\$(egrep -v "Inter|face|lo" /proc/net/dev | cut -f1 -d':')"

cat << EOC > /etc/network/interfaces
auto lo
  iface lo inet loopback

EOC

dev=0
for dev in \$DEVICES; do
  mac=\$(ip a show \$dev | grep ether | awk '{print \$2}')
  if [[ \${mac^^} == "${MAC_MAIN^^}" ]]; then
    cat << EOC > /etc/network/interfaces
auto lo
  iface lo inet loopback

auto \$dev
  iface \$dev inet static
    address $IP_ADDRESS
    netmask $NETMASK
    gateway $GATEWAY

EOC
    dev=\$(( dev + 1 ))
  else
    cat << EOC >> /etc/network/interfaces
auto \$dev
  iface \$dev inet manual

EOC
      dev=\$(( dev + 1 ))
    fi
done
DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y resolvconf isc-dhcp-common
# Removing isc-dhcp-client also removes the kernel
#isc-dhcp-client
rm /etc/resolv.conf

cat << EOC > /etc/resolv.conf
nameserver $NS1
nameserver $NS2
options rotate
options timeout:3
search $DOMAIN_NAME
EOC

rm /usr/local/bin/setup_network.sh
reboot
sleep 360
EOF
  chmod +x /usr/local/bin/setup_network.sh
  echo "#!/bin/bash -x" >> /etc/rc.local
  echo "/usr/local/bin/setup_network.sh" >> /etc/rc.local
  debug "Configured static networking"
  return 0
}

######################################################################
# 作用: 配置提示 
# 用法: Config_Hosts
# 注意：
######################################################################
Config_Hosts () {

..
}
######################################################################
# 作用: 配置提示 
# 用法: Config_Motd
# 注意：
######################################################################
Config_Motd () {
    local LANGID=$1
    local GRUB_CONF="/etc/default/grub"
    if grep "active raid1" /proc/mdstat &>/dev/null
    then
      HDD_RAID="true"
    fi
# :TODO:06.06.2012:: HDD_RAID definieren per /proc/mdstat o?
    case "$LANGID" in
    0407)
        echo -e "\n\nSehr geehrter Kunde,\n" >/etc/motd

        if [ "$HDD_RAID" == "true" ]; then
        cat << EOC >> /etc/motd
Sie koennen den Raidstatus des Systems ueber das Programm mdadm ueberwachen
lassen.

Ersetzen Sie hierzu bitte in der Datei /etc/mdadm/mdadm.conf bei dem Parameter
MAILADDR den derzeitigen Eintrag 'root' gegen Ihre Emailadresse und starten
Sie den Dienst mit '/etc/init.d/mdadm restart' neu.
EOC
        fi

        if [ -x /usr/local/sbin/dkms-update ]; then
        cat << EOC >> /etc/motd
Auf diesem Server wurde ein aktualisierter e1000e Netzwerktreiber via
dkms installiert. Entfernen Sie das Paket e1000e-dkms nicht! Nach Kernel
Updates müssen Sie das Script /usr/local/sbin/dkms-update auführen um
sicherzustellen dass der Treiber korrekt gebaut und in das initramfs
eingebunden ist. Wenn Sie dies nicht tun, wird das Netzwerk nach dem
n?chsten reboot nicht mehr funktionieren.

EOC
        fi

        cat << EOC >> /etc/motd
Bitte achten Sie darauf, bei Einsatz eines eigenen Kernels die von uns
definierten Boot-Parameter zu übernehmen (siehe $GRUB_CONF),
da einige Hardwarekombinationen zwingend die Parameter acpi=ht bzw. noapic
ben?tigen.
EOC
    ;;
    0413)
        echo -e "\n\nGeachte klant,\n" >/etc/motd

        if [ "$HDD_RAID" == "true" ]; then
        cat << EOC >> /etc/motd
U kunt de raidstatus van het Systeem over het programma mdadm bewaken laten.

Vervang in de file /etc/mdadm/mdadm.conf bij de Parameter MAILADDR de huidige
ingave 'root' tegen uw E-Mailadres en start de dienst
met '/etc/init.d/mdadm restart' opnieuw.
EOC
        fi

        cat << EOC >> /etc/motd
Hierbij treft u aan een advies voor een Kernel update:

Bij het gebruik van een eigen Kernel verzoeken wij u er op te letten dat u onze
Boot-parameter  (siehe $GRUB_CONF), overneemt. De hardwarconfiguratie
heeft namelijk de parameter acpi=ht bzw. noapic echt nodig.

Teneinde de functionaliteit automatische Reboot te kunnen uitvoeren is het ook
vereist dat bij de Intel systemen de Kernel-Parameter "acpi=ht" wordt ingesteld.
Voor Operating Systems ( besturingssystemen) is de Kernel-Parameter "noapic"
noodzakelijk.
EOC
    ;;
    *)
        echo -e "\n\nDear customer,\n" >/etc/motd

        if [ "$HDD_RAID" == "true" ]; then
            cat << EOC >> /etc/motd
You can monitor the Raid status of your operating system using the program mdadm.

In order to do so, replace the current entry 'root' with your email address,
you may do that in the file /etc/mdadm/mdadm.conf  at program parameter MAILADDR.
Then restart the service with  '/etc/init.d/mdadm restart'

EOC
fi

        if [ -x /usr/local/sbin/dkms-update ]; then
            cat << EOC >> /etc/motd
This server comes with a custom e1000e network driver in a dkms package.
Do not remove the e1000e-dkms package. After kernel updates you have to
execute /usr/local/sbin/dkms-update once to make sure the driver is built
correctly and included in initramfs. If you skip this, networking will not
work any longer after the next reboot.

EOC
        fi

        cat << EOC >> /etc/motd
If you want to use your own kernel, please make sure you don\'t touch the
kernel boot parameters (append) as some of our hardware requires the
parameters acpi=ht and/or noapic.
EOC
    ;;
    esac

debug "Set MOTD"
return 0
}



######################################################################
# 作用: 配置 SSL 
# 用法: Config_SSL
# 注意：
######################################################################
function Config_SSL ()
{
  local TARGET=$1

  CERT_DIR=/etc/ssl/certs
  KEY_DIR=/etc/ssl/private
  CERTS=${TARGET}
  DAYS=1826

  COUNTRY_NAME=${LANG%%_*}
  [ "$COUNTRY_NAME" = "" ] && COUNTRY_NAME="de"

  for CERT in $CERTS; do
    SSLEAY=$(tempfile -m600 -pexi)

    cat > $SSLEAY <<EOC
RANDFILE = ~/.rnd
[ req ]
default_bits = 1024
default_keyfile = $CERT.pem
distinguished_name = req_distinguished_name
prompt = no
[ req_distinguished_name ]
countryName = $COUNTRY_NAME
stateOrProvinceName = -
localityName = -
organizationName = -
organizationalUnitName = -
commonName = $(hostname -f)
emailAddress = postmaster@$(hostname -f)
EOC

     openssl req -config $SSLEAY -x509 -newkey rsa:1024 -keyout ${KEY_DIR}/${CERT}.key -out ${CERT_DIR}/${CERT}.pem -days $DAYS -nodes
     [ -f ~/.rnd ] && rm ~/.rnd
     [ -f $SSLEAY ] && rm $SSLEAY
    done
return 0
}



# Config apache
Config_Apache() {
cat << EOF > /etc/apache2/sites-enabled/000-default.conf
<VirtualHost *:80>
  ServerAdmin webmaster@${HOSTNAME}.${DOMAIN_NAME}
  DocumentRoot /var/www/oxid

  <Directory /var/www/oxid>
    AllowOverride All
  </Directory>

  ErrorLog \${APACHE_LOG_DIR}/error.log
  CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF

a2enmod rewrite ssl
a2ensite default-ssl
cat << EOF > /etc/apache2/sites-enabled/default-ssl.conf
<IfModule mod_ssl.c>
  <VirtualHost _default_:443>
    ServerAdmin webmaster@${HOSTNAME}.${DOMAIN_NAME}
    DocumentRoot /var/www/oxid

    <Directory /var/www/oxid>
      AllowOverride All
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    SSLEngine on
    SSLCertificateFile  /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
      SSLOptions +StdEnvVars
    </FilesMatch>

    <Directory /usr/lib/cgi-bin>
      SSLOptions +StdEnvVars
    </Directory>

    BrowserMatch "MSIE [2-6]" \
    nokeepalive ssl-unclean-shutdown \
    downgrade-1.0 force-response-1.0

    BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
  </VirtualHost>
</IfModule>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF

}





#===  FUNCTION  ================================================================
#          NAME:  setup_efiboot
#   DESCRIPTION:  configure efi boot to boot up from network first
#    PARAMETERS:  none
#       RETURNS:  0
#===============================================================================
function setup_efiboot ()
{
  EFI_PART=$(mount | egrep "/boot/efi" | awk '{print $1}')

  efibootmgr -q -c -g -d ${EFI_PART%[0-9]} -p ${EFI_PART: -1} -L "Ubuntu" -l '\EFI\ubuntu\shimx64.efi'

  BOOT_ORDER=$(efibootmgr | egrep -o "Boot.*\*")

  for ENTRY in ${BOOT_ORDER}; do
        STRING=$(efibootmgr | grep ${ENTRY%\*})

        case "${STRING}" in
          *ethernet*|*Ethernet*|*network*|*Network*)
                if [ "${NETWORK}." != "." ]; then
                        NETWORK="${ENTRY%\*},${NETWORK}"
                else
                        NETWORK="${ENTRY%\*}"
                fi
          ;;
          *ubuntu*|*Ubuntu*)
                OS="${ENTRY%\*}"
          ;;
        esac
  done

  ORDER="${NETWORK//Boot},${OS//Boot}"

  efibootmgr -q -o ${ORDER}

  return 0
} 