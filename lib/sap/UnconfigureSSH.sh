#!/bin/sh
#copy right by dongchaojun@gmail.com
# Useage $0 <IPADDRESS1> [IPADDRESS2...]
if [ "$1" == "" ]; then
  exit 1
fi

IPAddress=$1

if [ -f ~/.ssh/known_hosts ]; then
	sed -e "/$IPAddress/"d ~/.ssh/known_hosts > ~/.ssh/known_hosts.new
	mv -f ~/.ssh/known_hosts.new ~/.ssh/known_hosts
fi
