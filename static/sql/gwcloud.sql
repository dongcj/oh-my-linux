-- phpMyAdmin SQL Dump
-- version 3.3.9
-- http://www.phpmyadmin.net
--
-- 主机: localhost
-- 生成日期: 2012 年 04 月 10 日 11:20
-- 服务器版本: 5.5.8
-- PHP 版本: 5.3.5

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- 数据库: `gwcloud`
--

-- --------------------------------------------------------

--
-- 表的结构 `cronjob`
--

CREATE TABLE IF NOT EXISTS `cronjob` (
  `job_id` int(10) NOT NULL AUTO_INCREMENT,
  `job_time` varchar(100) NOT NULL,
  `job_content` mediumtext,
  `job_file_location_on_server` varchar(200) DEFAULT NULL,
  `job_starttime` date NOT NULL,
  `job_stoptime` date NOT NULL,
  `job_description` varchar(500) NOT NULL,
  PRIMARY KEY (`job_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `cronjob`
--


-- --------------------------------------------------------

--
-- 表的结构 `ha`
--

CREATE TABLE IF NOT EXISTS `ha` (
  `ha_id` int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`ha_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `ha`
--


-- --------------------------------------------------------

--
-- 表的结构 `hostplatform`
--

CREATE TABLE IF NOT EXISTS `hostplatform` (
  `hostplatform_id` int(10) NOT NULL AUTO_INCREMENT,
  `hostplatform_type` varchar(20) NOT NULL COMMENT 'KVM|Xen ?',
  `serial_number` varchar(50) DEFAULT NULL COMMENT 'dmidecode from the hostplat',
  `host_id` varchar(20) NOT NULL COMMENT 'hostid from the hostplatform',
  `alias_name` varchar(20) DEFAULT NULL,
  `ip_address` varchar(50) NOT NULL,
  `mac_address` varchar(20) NOT NULL,
  `cpu_type` varchar(10) NOT NULL,
  `cpu_size` int(6) NOT NULL,
  `cpu_speed` int(10) NOT NULL,
  `memory_size` int(20) NOT NULL COMMENT 'MB',
  `memory_speed` int(10) NOT NULL COMMENT '内存速率',
  `nic_number` int(5) NOT NULL,
  `nic_name` varchar(10) NOT NULL,
  `nic_speed` int(10) NOT NULL COMMENT 'MB',
  `br_name` varchar(20) NOT NULL,
  `cdrom_path` varchar(100) NOT NULL,
  `hostname` varchar(20) NOT NULL,
  `os_version` varchar(20) NOT NULL,
  `username` varchar(20) NOT NULL,
  `password` varchar(20) NOT NULL,
  `add_time` date NOT NULL,
  `location` varchar(100) NOT NULL COMMENT '该hypervisor位置',
  `description` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`hostplatform_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `hostplatform`
--


-- --------------------------------------------------------

--
-- 表的结构 `imagetemplate`
--

CREATE TABLE IF NOT EXISTS `imagetemplate` (
  `imagetemplate_id` int(10) NOT NULL AUTO_INCREMENT,
  `imagetemplate_name` varchar(50) NOT NULL,
  `imagetemplate_alias` varchar(50) NOT NULL,
  `file_source_location` varchar(200) NOT NULL,
  `file_destination_dir` varchar(200) NOT NULL,
  `imagetemplate_hypervisor_type` varchar(20) NOT NULL COMMENT 'KVM|Xen ?',
  `imagetemplate_size` int(20) NOT NULL COMMENT 'MB',
  `imagetemplate_cpu` int(10) NOT NULL,
  `imagetemplate_memory` int(10) NOT NULL COMMENT 'MB',
  `imagetemplate_os_type` varchar(20) NOT NULL COMMENT 'Windows? Linux? or ?',
  `imagetemplate_ceate_time` date NOT NULL,
  `imagetemplate_description` varchar(500) NOT NULL,
  PRIMARY KEY (`imagetemplate_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `imagetemplate`
--


-- --------------------------------------------------------

--
-- 表的结构 `ippool`
--

CREATE TABLE IF NOT EXISTS `ippool` (
  `ippool_id` int(10) NOT NULL AUTO_INCREMENT,
  `ippool_type` varchar(20) NOT NULL COMMENT 'KVM|Xen ?',
  `ippool_begin` varchar(20) NOT NULL,
  `ippool_end` varchar(20) NOT NULL,
  `ippool_temp_begin` varchar(20) NOT NULL,
  `ippool_temp_end` varchar(20) NOT NULL,
  `ippool_network` varchar(20) NOT NULL,
  `ippool_netmask` varchar(20) NOT NULL,
  `ippool_gateway` varchar(20) NOT NULL,
  `ippool_dns1` varchar(20) NOT NULL,
  `ippool_dns2` varchar(20) NOT NULL,
  `ippool_outer_address` varchar(20) DEFAULT NULL,
  `ippool_outer_domain` varchar(50) DEFAULT NULL,
  `ippool_create_time` date NOT NULL,
  PRIMARY KEY (`ippool_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `ippool`
--


-- --------------------------------------------------------

--
-- 表的结构 `loadbalance`
--

CREATE TABLE IF NOT EXISTS `loadbalance` (
  `loadbalance_id` int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`loadbalance_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `loadbalance`
--


-- --------------------------------------------------------

--
-- 表的结构 `physicalserver`
--

CREATE TABLE IF NOT EXISTS `physicalserver` (
  `physicalserver_id` int(10) NOT NULL AUTO_INCREMENT,
  `is_dx_create` int(2) NOT NULL,
  `creater` varchar(20) NOT NULL,
  `create_date` date NOT NULL,
  `expire_date` date NOT NULL,
  `nic_number` int(5) NOT NULL,
  `nic_name` varchar(20) NOT NULL,
  `ip_address` varchar(20) NOT NULL,
  `ip_netmask` varchar(20) NOT NULL,
  `ip_gateway` varchar(20) NOT NULL,
  `dnsserver_ip` varchar(50) NOT NULL,
  `host_id` varchar(100) NOT NULL,
  `host_name` varchar(20) NOT NULL,
  `host_os_release` varchar(100) NOT NULL,
  `host_root_username` varchar(20) NOT NULL,
  `host_root_password` int(11) NOT NULL,
  PRIMARY KEY (`physicalserver_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `physicalserver`
--


-- --------------------------------------------------------

--
-- 表的结构 `resourcepool`
--

CREATE TABLE IF NOT EXISTS `resourcepool` (
  `pool_id` int(10) NOT NULL AUTO_INCREMENT,
  `pool_name` varchar(10) NOT NULL,
  `pool_type` varchar(20) NOT NULL COMMENT 'KVM|Xen ?',
  `pool_location` varchar(100) NOT NULL,
  `pool_admin_phone` int(30) NOT NULL,
  `pool_admin_email` varchar(50) NOT NULL,
  `pool_description` varchar(500) DEFAULT NULL,
  `pool_create_time` date NOT NULL,
  PRIMARY KEY (`pool_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `resourcepool`
--


-- --------------------------------------------------------

--
-- 表的结构 `virtualserver`
--

CREATE TABLE IF NOT EXISTS `virtualserver` (
  `virtualserver_id` int(10) NOT NULL AUTO_INCREMENT,
  `is_dx_create` int(2) NOT NULL,
  `is_auto_select_hostplatform` int(2) NOT NULL COMMENT '是否自动选择hostplatform',
  `container_id` int(10) NOT NULL,
  `creater` varchar(20) NOT NULL,
  `create_date` date NOT NULL,
  `expire_date` date NOT NULL,
  `os_type` varchar(20) NOT NULL COMMENT 'Linux? Windows',
  `virt_uuid` varchar(100) NOT NULL,
  `virt_cpu` int(5) NOT NULL,
  `virt_disk_number` int(5) NOT NULL COMMENT 'the number of disk',
  `virt_disk_size` int(50) NOT NULL COMMENT 'MB',
  `virt_memory_size` int(50) NOT NULL COMMENT 'MB',
  `virt_br_name` varchar(20) NOT NULL,
  `virt_name` varchar(50) NOT NULL,
  `virt_disk_location` varchar(200) NOT NULL,
  `virt_mac` varchar(50) NOT NULL,
  `host_nic_number` int(5) NOT NULL,
  `host_nic_name` varchar(20) NOT NULL,
  `host_ip_address` varchar(20) NOT NULL,
  `host_ip_netmask` varchar(20) NOT NULL,
  `host_ip_gateway` varchar(20) NOT NULL,
  `host_dnsserver_ip` varchar(50) NOT NULL,
  `host_dns_searchdomain` varchar(50) NOT NULL,
  `host_id` varchar(20) NOT NULL,
  `host_name` varchar(20) NOT NULL,
  `host_os_release` varchar(100) NOT NULL,
  `host_root_username` varchar(20) NOT NULL,
  `host_root_password` varchar(20) NOT NULL,
  PRIMARY KEY (`virtualserver_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

--
-- 转存表中的数据 `virtualserver`
--

