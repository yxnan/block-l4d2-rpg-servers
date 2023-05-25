#!/bin/bash

ListFile="$1"
IPListName=l4d2-rpg-blacklist

if [ $(iptables -L | grep -c $IPListName) -eq 0 ]; then
    ipset create $IPListName hash:ip hashsize 4096
    iptables -I OUTPUT -p UDP -m set --match-set $IPListName dst -j DROP
else
    ipset flush $IPListName
fi

jq -r '.data[].raddr' $ListFile | xargs -L1 ipset add $IPListName

printf "Done.\n"

read -p "Whether to save the configuration permanently? (y/N) " answer
case $answer in
  y|Y) 
	iptables-save -f /etc/iptables/iptables.rules
	ipset save > /etc/ipset.conf
	echo "Make this configuration permanently!"
    ;;
  *) echo "This configuration will be invalid after reboot.";;
esac
