#!/usr/local/bin/expect

if {$argc!=3}{
    send_user "Usage: $argv0 {Array IP} {Password} {CMD}\n\n"
    exit
}

set IP [lindex $argv 0]
set Password [lindex $argv 1]
set CMD [lindex $argv 2]

spawn ssh administrator@$IP

expect {
	"password:" {
		exec sleep 1
		send "${Password}\r"
			}
	"*continue connecting*" {
			 exec sleep 1
			 send "yes\r"
             exp_continue
			}
    "*No route*" {
        exit 1
    }
    timeout {
        send_user "No response!\n"
        exit 1
    }
}

expect {
"*Password*" { send_user "\n1:Password error!\n"
               exit 1
             }
"*admin is logining*" { send_user "\n2:Repeated login!\n"
              exit 1
            }
"administrator@cli>" { send "${CMD}\r"
	                   }
}

expect {
   	"Error*" {		exit 1
	            }
	  "*>" {	send "exit\r"
		      exit 0
	        }
}
