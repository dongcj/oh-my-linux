#!/usr/bin/perl
#copy dongchaojun@gmail.com
# Usage $0 <OLD_IP> <NEW_IP>
$IPAddress=$ARGV[0];
$NewIPAddress=$ARGV[1];

print "This is $IPAddress\n";
print "This is the new ipaddress $NewIPAddress\n";
chomp($IPAddress);
system(`sed 's/$IPAddress/$NewIPAddress/g' ~/.ssh/known_hosts > /tmp/known_hosts.old`);
system(`cp /tmp/known_hosts.old ~/.ssh/known_hosts`);
