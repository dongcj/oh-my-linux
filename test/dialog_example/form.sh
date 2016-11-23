TMP=$(mktemp)

bad_ip(){
    echo $1 | grep '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$' > /dev/null 2>&1
    test $? -ne 0
}

while true; do 
    dialog --form \
        "Ulteo Vappliance network configuration" \
        10 50 3 \
        "IP address" 1 1 "$IP" 1 20 16 16   \
        "Netmask" 2 1 "$MASK" 2 20 16 16    \
        "Gateway" 3 1 "$GW" 3 20 16 16 2> $TMP

    test $? -ne 0 && exit 0

    IP=$(awk 'NR==1' $TMP)
    MASK=$(awk 'NR==2' $TMP)
    GW=$(awk 'NR==3' $TMP)

    for PARM in $IP $MASK $GW; do
        if bad_ip $PARM; then
            dialog --msgbox "Invalid network parameter: $PARM" 5 50
            continue 2
        fi
    done

    dialog --yesno \
        "Do you want to confirm the network parameters?     
        IP address: $IP
        Netmask: $MASK
        Gateway: $GW" \
        10 50
    test $? -eq 0 && break
    
done

cat << EOF > /etc/network/interfaces

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $IP
    netmask $MASK
    gateway $GW

EOF

dialog --msgbox "Reboot to apply the changes." 10 50

rm -f $TMP
