#!/usr/bin/expect
set IP [lindex $argv 0]
spawn ssh  root@${IP}
expect "*yes/no*" { send "yes\r" }
expect "*assword*" { exit 1 }
