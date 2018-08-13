#===  FUNCTION  ================================================================
#          NAME:  setup_disks
#   DESCRIPTION:  format unused disks and add them to /etc/fstab
#    PARAMETERS:  none
#       RETURNS:  0
#===============================================================================
function setup_disks ()
{
  DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get -qq -y install parted
  debug "Formating other devices if present"
  if [ -n "$(grep -o 'md[0-9]$' /proc/partitions)" ]; then
    debug "md devices found, looking for sd[c-f] devices"
    DEVICES=$(grep -o 'sd[c-f]$' /proc/partitions)
  else
    debug "no md devices found, looking for sd[b-f] devices"
    DEVICES=$(grep -o 'sd[b-f]$' /proc/partitions)
  fi
  if [ -z $DEVICES ]; then
    debug "no drives found"
  else
    debug "found drives to partition and format"
    for i in $DEVICES; do
      j=$(( $j + 1 ))
      debug "create partition table on /dev/$i"
      parted -s /dev/$i mktable gpt
      debug "create partition on /dev/$i"
      parted -s /dev/$i mkpart primary ext2 0 100%
      debug format partition /dev/"$i"1
      sync
      sleep 1
      mkfs.ext4 -q /dev/"$i"1 && \
        mkdir -p /mnt/disk"$j"  && \
        echo -e "/dev/"$i"1\t\t/mnt/disk$j\t\text4\tdefaults\t0 0" >> /etc/fstab
    done
  fi
set_progress "60" "Formatting additional harddisks"
debug "Finished setting up additional devices"
return 0
}






function configure_serial()
{

  # TODO

  # enable getty on ttyS0 (upstart)
  if [ -d /etc/event.d -a "$(which initctl)" != "" ]; then
    echo -n "Configuring getty on serial console (upstart)... "
    SERIAL_CONF="$(grep -l '^exec.*getty.*ttyS0' /etc/event.d/*)"
    for CONF_FILE in $SERIAL_CONF; do
           initctl stop ${CONF_FILE##*/} &>/dev/null
           rm $CONF_FILE
    done
    cat << EOC > /etc/event.d/ttyS0
# ttyS0 - serial console
#
# This service maintains a getty on serial ttyS0

start on stopped rcS
start on stopped rc1
start on stopped rc2
start on stopped rc3
start on stopped rc4
start on stopped rc5

stop on runlevel 0
stop on runlevel 6

respawn
exec /sbin/getty -L ttyS0 57600 vt100
EOC

    initctl start ttyS0 &>/dev/null
    echo "done"
  fi # end if event.d

  # enable getty on ttyS0 (sysvinit)
  if [ -f /etc/inittab ]; then
   echo -n "Configuring getty on serial console (sysvinit)... "
   if grep '^[^#].*ttyS0' /etc/inittab &>/dev/null; then
    sed -i 's/^[^#].*ttyS0.*/S0:12345:respawn:\/sbin\/getty -L ttyS0 57600 vt100/g' /etc/inittab
   else
    echo "S0:12345:respawn:/sbin/getty -L ttyS0 57600 vt100" >> /etc/inittab
   fi
   init q &>/dev/null
   echo "done"
  fi

  # enable root login on serial console
  if ! grep '^ttyS0' /etc/securetty &>/dev/null; then
   echo -n "Enabling root login on serial console... "
   echo -e "\n# serial console\nttyS0" >> /etc/securetty
   echo "done"
  fi

  # enable sulogin on serial console
  if [ -f /usr/share/recovery-mode/options/root ]; then
    if ! which patch &>/dev/null; then
      echo -n "Installing patch utility... "
      DEBIAN_FRONTEND=noninteractive apt-get -qq -y install patch &>/dev/null
      echo "done"
    fi
    echo -n "Patching recovery-mode scripts... "
    cat << EOC | patch -p0 -s --no-backup-if-mismatch -N -r /tmp/patch.rej &>/dev/null
--- /usr/share/recovery-mode/options/root.orig  2008-05-08 11:39:36.000000000 +0200
+++ /usr/share/recovery-mode/options/root       2008-09-30 11:01:46.000000000 +0200
@@ -5,4 +5,13 @@
    exit 0
 fi

-/sbin/sulogin
+SERIAL_TTY=\`/bin/grep -o 'console=ttyS[0-9]\+' /proc/cmdline|/bin/sed 's/console=//g'\`
+
+if [ "\$SERIAL_TTY" != "" ]; then
+ echo "Executing /sbin/sulogin on \$SERIAL_TTY"
+ echo "If you don't want this, remove \"console=\$SERIAL_TTY\" from kernel boot options"
+ echo ""
+ /sbin/sulogin /dev/\$SERIAL_TTY
+else
+ /sbin/sulogin
+fi
EOC
    echo "done"
  fi # end if sulogin

debug "Set up serial-console support"
return 0
}







function configure_grub()
{
# :TODO:30.05.2012:: an neue grub config anpassen
  local GRUB_CONF="/etc/default/grub"
  if [ -f $GRUB_CONF ]; then
    # grub serial console
    echo -n "Configuring grub on serial console... "
    if grep '^serial.*--unit=0' $GRUB_CONF &>/dev/null; then
           sed -i 's/^serial.*--unit=0.*$/serial --unit=0 --speed=57600/g' $GRUB_CONF
    else
           sed -i 's/^\(### BEGIN AUTOMAGIC KERNELS LIST.*\)/serial --unit=0 --speed=57600\n\n\1/g' $GRUB_CONF
    fi
    if grep '^terminal.*serial' $GRUB_CONF &>/dev/null; then
           sed -i 's/^terminal.*serial.*$/terminal --timeout=5 serial console/g' $GRUB_CONF
    else
           sed -i 's/^\(### BEGIN AUTOMAGIC KERNELS LIST.*\)/terminal --timeout=2 serial console\n\n\1/g' $GRUB_CONF
    fi
    echo "done"

    # enable kernel serial console support for default and failsafe kernel
    echo -n "Configuring kernel messages on serial console... "
    grep '^# defoptions.*console=ttyS0' $GRUB_CONF &>/dev/null || \
            sed -i 's/^\(# defoptions.*\)/\1 console=ttyS0,57600 console=tty0/g' $GRUB_CONF
    grep '^# altoptions.*console=ttyS0' $GRUB_CONF &>/dev/null || \
            sed -i 's/^\(# altoptions.*\)/\1 console=ttyS0,57600 console=tty0/g' $GRUB_CONF

    # quiet and options break serial console kernel msgs so we get rid of them
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/g' $GRUB_CONF
    echo "done"

    # re-create grub configuration
    # really dirty hack because stupid update-grub doesn't work unattended any more
    #WHIPTAIL_BIN=$(which whiptail)
    #mv $WHIPTAIL_BIN ${WHIPTAIL_BIN}.bak
    #ln -s /bin/true $WHIPTAIL_BIN
    #echo "y"|DEBIAN_FRONTEND="noninteractive" UCF_FORCE_CONFFNEW="true" update-grub -y >/dev/null 2>&1
    #rm $WHIPTAIL_BIN
    #mv ${WHIPTAIL_BIN}.bak $WHIPTAIL_BIN
    update-grub
  fi

debug "Set up grub"
return 0
}





function setup_remote ()
{
  which update-pciids &>/dev/null && update-pciids
  which lspci &> /dev/null || install_apt pciutils
  LSPCI_LIST="$(lspci -n|cut -d ' ' -f 3)"
  for HW_ID in $LSPCI_LIST; do
    case $HW_ID in
      1166:0103|1166:0104)
        configure_serial
        configure_grub
        configure_modules "ipmi_devintf" "ipmi_si"
        install_apt ipmitool
        break
      ;;
      8086:d138|8086:244e)
        configure_serial
        configure_modules "ipmi_devintf" "ipmi_si"
        install_apt ipmitool
        break
      ;;
      8086:0108|1002:5a18|8086:3406|8086:0158|8086:0c08)
        configure_modules "ipmi_devintf" "ipmi_si"
        install_apt ipmitool
        break
      ;;
    esac
  done
debug "Set up remote administration via serial console or ipmi"
return 0
} 







setup_hwpatches ()
{
LSPCI_LIST="$(lspci -n|cut -d ' ' -f 3)"
GRUB_CONF="/etc/default/grub"

mount -o proc /proc
mount -t sysfs none /sys

# remove BOOTIF from Kernel-Cmdline
if  grep "GRUB_CMDLINE_LINUX\(_DEFAULT\)\?=.*BOOTIF.*" $GRUB_CONF &> /dev/null
then
  sed -i 's/^\(GRUB_CMDLINE_LINUX\(_DEFAULT\)\?=\".*\)BOOTIF=[^[:space:]]\+\(.*\)\"$/\1 \2\"/g' $GRUB_CONF
fi
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/g' $GRUB_CONF

# Apply 80 second bootdelay for MX130 S1.  FXP-82992-187
sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\".*\)\"$/\1 rootdelay=80\"/g' /etc/default/grub

update-grub

for HW_ID in $LSPCI_LIST; do
 case $HW_ID in
  1002:5a18)
    # HP ProLiant
    # setting grub boot parameter to disable framebuffer
    sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\".*\)\"$/\1 vga16fb.modeset=0\"/g' $GRUB_CONF
  ;;
  8086:10ef)
   install_apt e1000e-dkms
   wget "http://$FILESERVER_IP/others/ubuntu/dkms-update" -O /usr/local/sbin/dkms-update
   chmod 755 /usr/local/sbin/dkms-update
  ;;
  8086:2690|8086:29f0|14e4:164c) # fsc primergy rx100 i.e.
   if [ "$HW_ID" = "14e4:164c" ] && [ ! -f /etc/lsb-release ]; then
    install_apt firmware-bnx2
    sleep 5
    /usr/sbin/update-initramfs -u -t
   fi
  ;;
  1106:3116|1039:0741)
   if ! grep "GRUB_CMDLINE_LINUX\(_DEFAULT\)\?=.*noapic.*" $GRUB_CONF &> /dev/null; then
    echo "hw with broken dsdt detected - adding noapic to boot options... "
    sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\".*\)\"$/\1 noapic\"/g' $GRUB_CONF
    LOCAL_UPDATE_GRUB=true
   fi
  ;;
  10de:0268) # nvidia MCP51 nic
   echo "options forcedeth dma_64bit=0" > /etc/modprobe.d/forcedeth
  ;;
  10de:026f|1166:0104|1166:0103|10de:005c) # fsc primergy econel 130, econel 230, rx 330, rx 100
   # remove noapic and acpi=off/ht stuff from kernel cmdline
   if  grep "GRUB_CMDLINE_LINUX\(_DEFAULT\)\?=.*noapic.*" $GRUB_CONF &> /dev/null; then
    echo "hw requires apic but you disabled it - fixing... "
    sed -i 's/^\(GRUB_CMDLINE_LINUX\(_DEFAULT\)\?=\".*\)noapic\(.*\)\"$/\1\2\"/g' $GRUB_CONF
    LOCAL_UPDATE_GRUB=true
   fi
   if grep "GRUB_CMDLINE_LINUX\(_DEFAULT\)\?=.*acpi.*" $GRUB_CONF &> /dev/null; then
    echo "hw requires acpi - making sure it's not disabled... "
    sed -i 's/^\(GRUB_CMDLINE_LINUX\(_DEFAULT\)\?=\".*\)acpi=[^[:space:]]\+\(.*\)\"$/\1\2\"/g' $GRUB_CONF
    LOCAL_UPDATE_GRUB=true
   fi
  ;;
  1000:0058) # broken lsi sas requires noapic...
   if ! grep "GRUB_CMDLINE_LINUX\(_DEFAULT\)\?=.*noapic.*" $GRUB_CONF &> /dev/null; then
    echo "lsi sas detected w. bad support in some dsdts - added noapic to boot options... "
    sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\".*\)\"$/\1 noapic\"/g' $GRUB_CONF
   fi
   LOCAL_UPDATE_GRUB=true
  ;;
  1106:0571) # patch for VIA VT8237S SATA on old kernels
   KERNEL_VERSION=$(ls /boot/vmlinuz*|awk -F '/' '{ print $NF }'|sed 's/vmlinuz-//')
   if echo $KERNEL_VERSION|grep '2.6.18' &>/dev/null; then
    echo -e "VIA VT8237S detected and kernel $KERNEL_VERSION too old\n"
    if [ "$(cat /proc/cpuinfo|grep '^vendor_id'|awk -F ': ' '{ print $2 }'|head -n1)" == "AuthenticAMD" ]; then
     if [ "$HOSTTYPE" == "x86_64" ]; then
      KARCH=amd64
     else
      KARCH=k7
     fi
    else
     if [ "$HOSTTYPE" == "x86_64" ]; then
      KARCH=amd64
     else
      KARCH=i686
     fi
    fi
    echo "downloading patched VIA VT8237S sata drivers:"
    echo -n " - ahci.ko: "
    wget http://$FILESERVER_IP/others/sigi/via-patch/$KARCH/ahci.ko -O $(find /lib/modules -name ahci.ko|head -n1) &>/dev/null
    echo -n " - sata_via.ko: "
    wget http://$FILESERVER_IP/others/sigi/via-patch/$KARCH/sata_via.ko -O $(find /lib/modules -name sata_via.ko|head -n1) &>/dev/null
    if which mkinitramfs &> /dev/null; then
     [ -d /etc/mkinitramfs ] && INITRD_PATH=/etc/mkinitramfs
     [ -d /etc/initramfs-tools ] && INITRD_PATH=/etc/initramfs-tools
    else
     INITRD_PATH="/etc/mkinitrd"
    fi
    echo -n "adding ahci.ko to ${INITRD_PATH}/modules: "
    [ -d ${INITRD_PATH} ] && \
     echo "ahci" >> ${INITRD_PATH}/modules
    echo -n "re-creating initrd image: "
    for KERNEL_VERSION_CURRENT in $KERNEL_VERSION; do
     if which mkinitramfs &> /dev/null; then
      mkinitramfs -o /boot/initrd.img-$KERNEL_VERSION_CURRENT $KERNEL_VERSION_CURRENT
     else
      mkinitrd -o /boot/initrd.img-$KERNEL_VERSION_CURRENT $KERNEL_VERSION_CURRENT
     fi
    done
   fi
  ;;
 esac
done

# intel nic patches

echo -e "Checking NIC firmware...\n"
if ! which ethtool &> /dev/null; then
 install_apt ethtool
fi

for DEV_CURRENT in $(grep -o 'eth[0-9]\+' /proc/net/dev); do
 DEV_ID=$(ethtool -e $DEV_CURRENT 2>/dev/null| grep 0x0010 | awk '{print "0x"$13$12$15$14}')
 case $DEV_ID in
  0x108b8086)
   DEV_NAME="82573V Gigabit Ethernet Controller"
  ;;
  0x108c8086)
   DEV_NAME="82573E Gigabit Ethernet Controller"
  ;;
  0x109a8086)
   DEV_NAME="82573L Gigabit Ethernet Controller"
  ;;
  *)
   DEV_NAME="unsupported"
  ;;
 esac
 if [ "$DEV_NAME" != "unsupported" ]; then
  FW_CURRENT="$(ethtool -e $DEV_CURRENT 2>/dev/null| grep 0x0010 | awk '{print $16}')"
  FW_NEW="$(echo ${FW_CURRENT:0:1})$(echo ${FW_CURRENT:1} | tr '02468ace' '13579bdf')"
  if [ "${FW_CURRENT:0:1}${FW_CURRENT:1}" == "$FW_NEW" ]; then
   echo "NO - skipping"
  else
   echo "YES"
   echo -n ">> applying patch... "
   ethtool -E $DEV_CURRENT magic $DEV_ID offset 0x1e value 0x$FW_NEW
   echo "DONE"
  fi
 else
  echo "skipping nic patch for $DEV_CURRENT ($DEV_NAME)"
 fi
 echo ""
done

# dkms stuff
if [ -x /usr/sbin/dkms ]; then
 if grep -i ubuntu /etc/lsb-release &>/dev/null; then
  HEADERPKG=$(dpkg --get-selections|cut -f 1|grep -m 1 '\(linux\|kernel\)-image-[0-9]'|sed 's/image-[0-9].*[0-9]/headers/g')
 else
  HEADERPKG=$(dpkg --get-selections|cut -f 1|grep -m 1 '\(linux\|kernel\)-image-[0-9]'|sed 's/-image-/-headers-/g')
 fi
 DEBIAN_FRONTEND=noninteractive apt-get -qq -y install $HEADERPKG
 echo "Checking for newly added dkms modules..."
 dkms status|grep added|cut -d: -f1|tr -d ,|\
 while read DRIVER VERSION; do
  echo " * new driver found: $DRIVER $VERSION"
  for i in /lib/modules/*; do
   echo "   - building for kernel ${i##*/}"
   dkms build -m $DRIVER -v $VERSION -k ${i##*/} >/dev/null
   echo "   - installing for kernel ${i##*/}"
   dkms install -m $DRIVER -v $VERSION -k ${i##*/} --force >/dev/null
  done
 done
 echo "done."
 if [ -x /usr/sbin/update-initramfs ]; then
  update-initramfs -u -t -k all
 fi
fi

if [ "$LOCAL_UPDATE_GRUB" = "true" ]; then
 # really dirty hack because stupid update-grub doesn't work unattended any more
 #WHIPTAIL_BIN=$(which whiptail)
 #mv $WHIPTAIL_BIN ${WHIPTAIL_BIN}.bak
 #ln -s /bin/true $WHIPTAIL_BIN
 #echo "y"|DEBIAN_FRONTEND="noninteractive" UCF_FORCE_CONFFNEW="true" update-grub -y >/dev/null 2>&1
 #rm $WHIPTAIL_BIN
 #mv ${WHIPTAIL_BIN}.bak $WHIPTAIL_BIN
 update-grub &>/dev/null
fi

rm /etc/udev/rules.d/70-persistent-net.rules

#umount /sys > /dev/null 2>&1
#umount /proc > /dev/null 2>&1

set_progress "70" "Applying hardwarepatches"
debug "Finished applying special hardware patches"
return 0
}  