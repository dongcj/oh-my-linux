#!/bin/bash
set_affinity_0()
{
    if [ $VEC -ge 32 ]
    then
        MASK_FILL=""
        MASK_ZERO="00000000"
        let "IDX = $VEC / 32"
        for ((i=1; i<=$IDX;i++))
        do
            MASK_FILL="${MASK_FILL},${MASK_ZERO}"
        done

        let "VEC -= 32 * $IDX"
        MASK_TMP=$((1<<$VEC))
        MASK=`printf "%X%s" $MASK_TMP $MASK_FILL`
    else
        MASK_TMP=$((1<<$VEC))
        MASK=`printf "%X" $MASK_TMP`
    fi

    printf "%s mask=%s for /proc/irq/%d/smp_affinity\n" $DEV $MASK $IRQ
    printf "%s" $MASK > /proc/irq/$IRQ/smp_affinity
}

set_affinity_1()
{
    MASK=${CPUMASK[$VEC]} 
    printf "%s" $MASK > /proc/irq/$IRQ/smp_affinity
}

net_hard_interrupt()
{
    NIC=$(cat /proc/net/bonding/bond0 |grep 'Slave Interface'|awk -F":" {'print $2'}|tr '\n' ' '|xargs -n 10)


# check for irqbalance running
   IRQBALANCE_ON=`ps ax | grep -v grep | grep -q irqbalance; echo $?`
   if [ "$IRQBALANCE_ON" == "0" ] ; then
       exit
   fi

#check for cpu 
   FLAG=0
   if [ $(cat /proc/cpuinfo|grep "physical id"|head -n 2|uniq|wc -l) == 1 ];then
       FLAG=1
       PHYNUM=$(cat /proc/cpuinfo |grep "physical id"|sort|uniq|wc -l)
       CORENUM=$(cat /proc/cpuinfo |grep "core id"|sort|uniq|wc -l)
       i=0
       k=0
       while [ $i -lt $CORENUM ]
       do
           n=$i
           CPUMASK[$k]=$(echo "obase=16;$((2 ** $n))"|bc)
           k=$(expr $k + 1)
           j=0
           while [ $j -lt $PHYNUM ]
           do
               n=$(expr $n + $CORENUM)
               CPUMASK[$k]=$(echo "obase=16;$((2 ** $n))"|bc)
               k=$(expr $k + 1)
               j=$(expr $j + 1)
           done
            i=$(expr $i + 1)
       done
   fi

# Set up the desired devices.
   for DEV in $NIC
   do
      for DIR in rx tx TxRx txrx " "
      do
          MAX=`grep $DEV-${DIR} /proc/interrupts | wc -l`
      	  PRO=`grep processor /proc/cpuinfo |wc -l`
          if [ "$MAX" == "0" ] ; then
          MAX=`egrep -i "$DEV:.*${DIR}" /proc/interrupts | wc -l`
          fi
          if [ "$MAX" == "0" ] ; then
          echo no $DIR vectors found on $DEV
          continue
          fi
          if [ "$MAX" == "$PRO" ]; then
          FLAG=0
          fi
          tmpinter=$DEV-$DIR
          [ `echo "x$DIR"` == "x" ] && tmpinter=$DEV
          for VEC in `seq 0 1 $MAX`
          do
              IRQ=`cat /proc/interrupts | grep -i $tmpinter-$VEC"$"  | cut  -d:  -f1 | sed "s/ //g"`
              if [ -n  "$IRQ" ]; then
              [ "$FLAG" == "1" ]&& set_affinity_1 ||set_affinity_0 
              else
              IRQ=`cat /proc/interrupts | egrep -i $DEV:v$VEC-$DIR"$"  | cut  -d:  -f1 | sed "s/ //g"`
              if [ -n  "$IRQ" ]; then
              [ "$FLAG" == "1" ]&& set_affinity_1 ||set_affinity_0 
              fi
              fi
         done
      done
   done
}
