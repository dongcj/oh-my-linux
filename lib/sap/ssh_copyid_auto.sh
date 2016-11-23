#!/bin/sh
 

auto_login_ssh() {
        ip=$1
        username=$2
        password=$3
        
        expect -c "
        set timeout -1;
        spawn ssh-copy-id $username@$ip
        expect {
            yes/no {
                    send \"yes\n\"
                    expect password
                    send \"$password\n\"
            }
            password {send \"$password\n\"}
            denied {send_user \"Password error\"; exit 1}
        }
        interact;
        "
}
 