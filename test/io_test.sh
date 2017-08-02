#!/bin/bash
export DATE=$(date +"%Y%m%d")

function cleanup #清空缓存
{
	sync && echo 3 > /proc/sys/vm/drop_caches
}

function dd_nodirect ()	#$1为测试目录	$2为块大小 $3为块数量	$4为保存测试数据的文件名
{
	echo dd-nodirect >>$4
	dd if=/dev/zero of=$1 bs=$2 count=$3 &>/tmp/test
	echo  -e "`grep bytes /tmp/test|cut -d ' ' -f 8,9`\n" >/tmp/test
	grep GB /tmp/test >/dev/null 2>&1
	if [ $? -ne 0 ];then
		grep MB /tmp/test >/dev/null 2>&1
		if [ $? -ne 0 ];then
			echo -e "`grep KB /tmp/test`\n" >>$4
		else 
			n=`grep MB /tmp/test|cut -d ' ' -f 1`
			m=$(($n * 1024))
			sed -i -e "1 s/$n/$m/" /tmp/test
			sed -i -e '1 s/MB/KB/' /tmp/test
			echo -e "dd-write: `grep KB /tmp/test`\n" >>$4
		fi
	else
		n=`grep GB  /tmp/test|cut -d ' ' -f 1`
		m=$(($n * 1024 *1024))
		sed -i -e "1 s/$n/$m/" /tmp/test
		sed -i -e '1 s/GB/KB/' /tmp/test
		echo -e "dd-write: `grep KB /tmp/test`\n" >>$4
	fi
	cleanup
}

function dd_direct ()	#$1为测试目录	$2为块大小 $3为块数量	$4为保存测试数据的文件名
{
	echo dd-direct >>$4
	dd if=/dev/zero	of=$1 bs=$2 count=$3 oflag=direct &>/tmp/test
	echo  -e "`grep bytes /tmp/test | cut -d ' ' -f 8,9`\n" >/tmp/test
	grep GB /tmp/test >/dev/null 2>&1
	if [ $? -ne 0 ];then
		grep MB /tmp/test >/dev/null 2>&1
		if [ $? -ne 0 ];then
			echo -e "`grep KB /tmp/test`\n" >>$4
		else 
			n=`grep MB /tmp/test|cut -d ' ' -f 1`
			m=$(($n * 1024))
			sed -i -e "1 s/$n/$m/" /tmp/test
			sed -i -e '1 s/MB/KB/' /tmp/test
			echo -e "dd-write: `grep KB /tmp/test`\n" >>$4
		fi
	else
		n=`grep GB  /tmp/test|cut -d ' ' -f 1`
			m=$(($n * 1024 *1024))
			sed -i -e "1 s/$n/$m/" /tmp/test
			sed -i -e '1 s/GB/KB/' /tmp/test
			echo -e "dd-write: `grep KB /tmp/test`\n" >>$4
	fi
	cleanup
}

function fio_order_read ()	#$1为测试目录	$2为块大小	$3为测试文件大小	$4为保存测试数据的文件名
{
	echo fio-order-read >>$4
	fio -filename=$1 -direct=1 -iodepth 1 -thread -rw=read -ioengine=psync -bs=$2 -size=$3 -numjobs=30 -runtime=1000 -group_reporting -name=my$4 &>/tmp/test
	echo -e "`grep read /tmp/test | grep bw=`\n" >>$4
	cleanup
}

function fio_order_write ()	#$1为测试目录	$2为块大小	$3为测试文件大小	$4为保存测试数据的文件名
{
	echo fio-order-write >>$4
	fio -filename=$1 -direct=1 -iodepth 1 -thread -rw=write -ioengine=psync -bs=$2 -size=$3 -numjobs=30 -runtime=1000 -group_reporting -name=my$4 &>/tmp/test
	echo -e "`grep write /tmp/test | grep bw=`\n" >>$4
	cleanup
}

function fio_random_write ()	#$1为测试目录	$2为块大小	$3为测试容量	$4为保存测试数据的文件名
{
	echo fio-random-write >>$4
	fio -filename=$1 -direct=1 -iodepth 1 -thread -rw=randwrite -ioengine=psync -bs=$2 -size=$3 -numjobs=30 -runtime=1000 -group_reporting -name=my$4 &>/tmp/test
	echo -e "`grep write /tmp/test | grep bw=`\n" >>$4
	cleanup
}

function fio_random_read ()	#$1为测试目录	$2为块大小	$3为测试容量	$4为保存测试数据的文件名
{
	echo fio-random-read >>$4
	fio -filename=$1 -direct=1 -iodepth 1 -thread -rw=randrand -ioengine=psync -bs=$2 -size=$3 -numjobs=30 -runtime=1000 -group_reporting -name=my$4 &>/tmp/test
	echo -e "`grep read /tmp/test | grep bw=`\n" >>$4
	cleanup
}

function iozone_install()	#iozone安装
{
	yum install -y gnuplot* gcc
	wget http://www.iozone.org/src/current/iozone3_327.tar
	tar xvf iozone3_327.tar
	cd ./iozone3_327/src/current
	make linux
	m=`pwd`
	echo "alias iozone=$m/iozone" >>/etc/profile
}

function fio_install()	#fio安装
{
	yum -y install libaio libaio-devel gcc
	wget http://brick.kernel.dk/snaps/fio-2.1.7.tar.bz2
	tar -xjvf fio-2.1.7.tar.bz2 
	cd fio-2.1.7/
	./configure 
	make
	make install
}

function iozone_async ()	#$1文件大小	$2为块大小 $3为测试目录	$4为保存测试数据的文件名
{
	echo async >>$4
	iozone -ceM -s $1 -r $2 -i 0 -i 1 -i 2 -i 3 -i 4 -i 5 -i 6 -i 7 -f $3 &>>$4 
	cleanup
}

function iozone_sync () 	#$1文件大小	$2为块大小	$3为测试目录	$4为保存测试数据的文件名
{
	echo sync >>$4
	iozone -oceM -s $1 -r $2  -i 0 -i 1 -i 2 -i 3 -i 4 -i 5 -i 6 -i 7 -f $3 &>>$4
	cleanup
}

function iops_score()	#iops分数统计
{
	a=`grep iops $4|grep read|cut -d ' ' -f 7|cut -d '=' -f 2|sed -n '1p'`
	b=`grep iops $4|grep read|cut -d ' ' -f 7|cut -d '=' -f 2|sed -n '2p'`
	c=`grep iops $4|grep write|cut -d ' ' -f 6|cut -d '=' -f 2|sed -n '1p'`
	d=`grep iops $4|grep write|cut -d ' ' -f 6|cut -d '=' -f 2|sed -n '2p'`
	e=$(($a + $b + $c + $d))
	echo $e
}

function disk_score()	#磁盘得分统计
{
	a=`grep read $4 | cut -d ' ' -f 6| grep bw | cut -d '=' -f 2 | cut -d 'K' -f 1 | sed -n '1p'`
	b=`grep read $4 | cut -d ' ' -f 6| grep bw | cut -d '=' -f 2 | cut -d 'K' -f 1 | sed -n '2p'`
	c=`grep write $4 | cut -d ' ' -f 5| grep bw | cut -d '=' -f 2 | cut -d 'K' -f 1 | sed -n '1p'`
	d=`grep write $4 | cut -d ' ' -f 5| grep bw | cut -d '=' -f 2 | cut -d 'K' -f 1 | sed -n '2p'`
	e=` grep dd-write $4 | cut -d ' ' -f 2 | sed -n '1p'`
	f=` grep dd-write $4 | cut -d ' ' -f 2 | sed -n '2p'`
	g=$(($a + $b +$c + $d + $e + $f))
	echo $g
}

function total_score	#总分统计	$1为保存测试数据的文件名	$2为IOPS倍数
{
        echo iops-score: >> $1
        iops_score &>> $1
        echo disk-score: >> $1
        disk_score &>> $1
        a=`grep -A 1 'iops-score' $1|sed -n '2p'`
        b=`grep -A 1 'disk-score' $1|sed -n '2p'`
        echo $a
        echo $b
        c=$(($a + $b * $2))
        echo $c
}

dd_nodirect here 1M 1000 test.$DATA
dd_direct here 1M 1000	test.$DATA
#iozone_async 1G 1M
#iozone_sync 1G 1M
fio_order_read /dev/sdb 1M 1G
fio_order_write /dev/sdb 1M 1G
fio_random_read /dev/sdb 1M 1G
fio_random_write /dev/sdb 1M 1G
echo iops-score:
iops_score
echo disk-score:
disk_score
echo total-score:
total_score 100
