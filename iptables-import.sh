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