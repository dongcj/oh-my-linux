#!/usr/bin/env bash
#
# Author: dongcj <ntwk@163.com>
# description: 
#

Define_Start_VM(){
if [ "$#" -lt 1 ]; then
    echo "Function Define_VM() is error! Usage: Define_VM <VM_NAME> <XML_FILE>"
    Exit
else
    echo
    echo -n "   Defineing $1 useing xml file $2.."
    if virsh define $2 >/dev/null 2>&1; then
        echo ".OK."
        echo -n "   Starting VM $1.."
        if virsh start $1 >/dev/null 2>&1; then
            # Set the AutoStart
            virsh autostart $1 >/dev/null 2>&1
            echo ".OK."
        else
            echo ".failed!"
            Exit
        fi
    else
        echo ".failed!"
        Exit
    fi
fi
}



Get_VM_Info() {
    PROTOCOL=vnc      # spice or vnc

    virsh list --all | sed -n '1,2!p' | sed -n '/^$/!p' | while read line; do 
        VMNAME=`echo $line | awk '{print $2}' | xargs`
        if [ "$PROTOCOL" = "spice" ]; then
            VMPORT=`ps -ef | grep " $VMNAME " | grep -v grep | grep $PROTOCOL | tr ' .,' '\n' | grep port | awk -F'=' '{print $2}' | xargs`
        elif [ "$PROTOCOL" = "vnc" ]; then
            VMPORT=`ps -ef | grep " $VMNAME " | grep -v grep | grep $PROTOCOL | tr ' ' '\n' | grep -A1 "\-vnc" | sed -n '$p' | awk -F':' '{print $2}' | xargs`
        else
            echo "Error: the PROTOCOL must be spice or vnc"
            exit 1
        fi
        if [ -z "$VMPORT" ]; then 
            VMPORT=None 
        else
            VMPORT=$[VMPORT+5900]
        fi
        echo "$PROTOCOL:$VMPORT $line" | awk '{print $1" "$2" "$3" "$4$5}'
    done

}

Check_And_Make_VM_Xml(){
    
    ## Check the VM FILE
    for i in $VM_TO_BE_INSTALLED; do
        
        # VM Path=UPPER(VM_NAME) with /
        VM_NAME_UPPER=`echo ${i} | tr '[a-z]' '[A-Z]'`
        VM_OOB_PATH=`echo ../${i} | tr '[a-z]' '[A-Z]' | sed -n 's/$/\//p'`
        # Get the VM file name, the vm file name = vmname.img.tar.gz
        VM_FILE_NAME=`awk -F"=" '{if ($1 ~ "'$VM_NAME_UPPER'_VM_FILE") print $2}' ${CONF_NAME} | awk -F'#' '{print $1}' | sort | uniq | xargs`
        VM_DISK_NAME=${VM_FILE_NAME%.tar.gz}
        VM_XML_NAME=`awk -F"=" '{if ($1 ~ "'$VM_NAME_UPPER'_XML_FILE") print $2}' ${CONF_NAME} | awk -F'#' '{print $1}' | sort | uniq | xargs`
        
        # Get the vm mac address
        VM_MAC=`awk -F"=" '{if ($1 ~ "'$VM_NAME_UPPER'_VM_MAC") print $2}' ${CONF_NAME} | awk -F'#' '{print $1}' | sort | uniq | xargs`
        
        if [ ! -f "${VM_OOB_PATH}${VM_FILE_NAME}" ]; then
            echo; echo
            echo "   File ${PWD_DIR}${VM_OOB_PATH}${VM_FILE_NAME} does not exist !"
            Exit
        else
            unset RECOPY
            # If the file already exist in /var/lib/libvirt/images/, ask user for operation
            if [ -f "${VM_DIR}${VM_DISK_NAME}" ]; then
                while true;do
                    echo
                    echo -n "   VM file: ${VM_DIR}${VM_DISK_NAME} already exist, re-copy it? [Y/N]: "
                    read ANS 
                    case ${ANS} in
                        N|n)RECOPY=no;break
                        ;;
                        Y|y|"")RECOPY=yes;break;
                        ;;
                        *)echo "   ${COLOR_RED}Incorrect choice!!${COLOR_CLOSE}";continue;
                    esac
                done
            fi
            
            if [ "$RECOPY" != "no" ]; then
                echo
                echo -n "   Unzip ${VM_OOB_PATH}${VM_FILE_NAME} to $VM_DIR.."
                stty -echo
                if ! tar -xzf ${VM_OOB_PATH}${VM_FILE_NAME} -C $VM_DIR >/dev/null 2>&1; then
                    echo
                    echo "   Run \"tar -xzf ${VM_OOB_PATH}${VM_FILE_NAME} -C $VM_DIR\" failed, please check the file!"
                    Exit
                else
                    echo ".done."
                    stty echo
                fi
            fi

        fi
        
        # XML文件
        if [ ! -f "${VM_OOB_PATH}${VM_XML_NAME}" ]; then
            echo
            echo "   File ${PWD_DIR}${VM_OOB_PATH}${VM_XML_NAME} does not exist !"
            Exit
        else
        
            # Get the disk format
            VM_DISK_FORMAT=`qemu-img info ${VM_DIR}${VM_DISK_NAME} | grep "file format" | awk -F":" '{print $2}' | xargs`
            
            # Get the qemu-kvm support machine
            if [ -x /usr/libexec/qemu-kvm ]; then
                KVM_MACHINE=`/usr/libexec/qemu-kvm -M ? | sed -n '2p' | awk '{print $1}'`
                KVM_EMULATOR="/usr/libexec/qemu-kvm"
            elif [ -x /usr/bin/kvm ]; then
                KVM_MACHINE=`/usr/bin/kvm -M ? | sed -n '3p' | awk '{print $1}'`
                KVM_EMULATOR="/usr/bin/kvm"
            else
                echo "   no kvm binary file found!"
                Exit
            fi
            
            # del the UUID / MAC / ADDRESS /  DISK_FORMAT
            # replace the NAME / DISK LOCATION / BRIDGE
            VM_DIR_CONVERT=$(echo $VM_DIR | sed 's/\//\\\//g')
            sed -e '/uuid/d' -e '/address type/d' ${VM_OOB_PATH}${VM_XML_NAME} -e "/controller type='usb'/,/<\/controller/d" | \
            sed -e "/device='cdrom'/,/<\/disk>/d" | \
            sed "s/machine='.*'/macheine='$KVM_MACHINE'/" | \
            sed "s/driver name='qemu' type='.*' cache='.*'/driver name='qemu' type='$VM_DISK_FORMAT' cache='none'/" | \
            sed "s/<name>.*/<name>$i<\/name>/" | sed "s#<emulator>.*#<emulator>$KVM_EMULATOR<\/emulator>#" | \
            sed "0,/source file/s/source file='.*'/source file='${VM_DIR_CONVERT}${VM_DISK_NAME}'/" | \
            sed "s/<source bridge='.*'/<source bridge='$CLOUD_VM_BRIDGE'/" | sed "s/<mac address='.*'/<mac address='$VM_MAC'/" >${VM_DIR}${VM_XML_NAME}
            
            # 找出所有VM的XML,形成一个数组
            XML_FILE_LIST="$XML_FILE_LIST ${i},${VM_DIR}${VM_XML_NAME}"
            XML_FILE_LIST=($XML_FILE_LIST)
        fi
        
    done
}