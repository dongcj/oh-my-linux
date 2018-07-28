#!/bin/sh
PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/data/home/test//bin.
export PATH
mysql_par="mysql -uroot --socket=/home/dbdata_raw/prod/3306/mysql.sock  -Dearly_warn"
temp_file=.temp$$
for table in t_ewp_daydata_DB t_ewp_daydata_OS t_ewp_daydata_apply t_ewp_daydata_hardware t_ewp_rawdata_DB t_ewp_rawdata_OS t_ewp_rawdata_apply t_ewp_rawdata_hardware
do
        $mysql_par -N -e  "show create table $table\G" |grep "VALUES LESS THAN"> $temp_file
        drop_partiiton=`cat $temp_file|head -1|awk '{print $2}'`
        add_partiiton_day=`cat $temp_file|tail -1|awk '{print $2}'|sed 's/p//'`
        if [ m_$drop_partiiton == m_ -o m_$add_partiiton_day == m_ ];then
                exit
        fi
        time_fiter=`date -d "-1 days ago $add_partiiton_day" +"%Y%m%d"`
        time_create=`date -d "-1 days ago $add_partiiton_day" +"%Y-%m-%d"`
        ${mysql_par} -N -e "ALTER table $table DROP PARTITION $drop_partiiton;"
        ${mysql_par} -N -e "ALTER TABLE  $table ADD PARTITION (PARTITION p${time_fiter} VALUES LESS THAN (TO_DAYS('$time_create')));"
        rm $temp_file
done

