#!/bin/bash

windows_server="10.0.0.3"
linux_server="10.0.0.4"
laptop="10.0.1.2"
desktop="10.0.2.2"
dmz_zone="10.0.0.0/24"
laptop_net="10.0.1.0/24"
desktop_net="10.0.2.0/24"
class_A_priv="10.0.0.0/8"
class_B_priv="172.16.0.0/12"
class_C_priv="192.168.0.0/16"
class_D_multicast="224.0.0.0/4"
class_E_reserved_net="240.0.0.0/5"
LOOPBACK="127.0.0.1"

IPT="/sbin/iptables"

$IPT -F
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT -t nat -F
$IPT -t mangle -F
$IPT -X
$IPT -N SSH
$IPT -N FTP
$IPT -N MYSQL

ipset -N internalAddr iphash
ipset -A internalAddr $windows_server
ipset -A internalAddr $linux_server
ipset -A internalAddr $laptop_net
ipset -A internalAddr $desktop_net
ipset -A internalAddr $dmz_zone

# Accept established connections
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

################### INPUT CHAIN ###########################
$IPT -A INPUT -i eth2 -p udp --dport 1415 -s $desktop -j ACCEPT
###########################################################

################## OUTPUT CHAIN ###########################
$IPT -A OUTPUT -o eth2 -p udp --dport 1415 -d $desktop -j ACCEPT
###########################################################

# SSH Access
$IPT -A INPUT -p tcp --dport 22 --syn -j SSH

############ Mark DNS Packets from Desktop and Laptop net #########
$IPT -t mangle -A PREROUTING ! -i eth0 -p udp --dport 53 -j MARK --set-mark 1
###################################################################


################ SSH Chain ########################
$IPT -A SSH -i eth0 -p tcp -s $linux_server -j ACCEPT
$IPT -A SSH -i eth1 -p tcp -s $desktop_net -j ACCEPT
$IPT -A SSH -p tcp -m set ! --match-set internalAddr src -j ACCEPT
$IPT -A SSH -d $laptop,$desktop -p tcp --syn -j ACCEPT
$IPT -A SSH -i eth1 -o eth2 -s 10.0.1.0/24 -d 10.0.2.0/24 -j ACCEPT
$IPT -A SSH ! -i eth0 -o eth0 -s $laptop_net,$desktop_net -j ACCEPT
$IPT -A SSH -j DROP
###################################################

################ FTP Chain ########################
$IPT -A FTP -p tcp -s $desktop_net --syn -o eth0 -j ACCEPT
$IPT -A FTP -p tcp -s $desktop_net -m state --state ESTABLISHED,RELATED -j ACCE$
$IPT -A FTP -j DROP
###################################################

################ MYSQL CHAIN ######################
$IPT -A MYSQL -p tcp --syn -d $laptop -j ACCEPT
$IPT -A MYSQL -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A MYSQL -j DROP
###################################################

###################FORWARD CHAIN #####################
$IPT -A FORWARD -p tcp --sport 22 --syn -j SSH
$IPT -A FORWARD -p tcp --dport 22 --syn -j SSH
$IPT -A FORWARD -p tcp -m multiport --dports 20,21,1024 -j FTP
$IPT -A FORWARD -p tcp --dport 3306 -j MYSQL
$IPT -A FORWARD -p tcp --sport 3306 -i eth1 -j MYSQL
$IPT -A FORWARD -p udp --dport 1415 -s 10.0.0.1,$windows_server -d $desktop -j $
$IPT -A FORWARD -p udp --dport 1415 -s $desktop -d $windows_server,10.0.0.1 -j $
$IPT -A FORWARD -p udp --dport 53 -s $desktop_net,$laptop_net -j ACCEPT
$IPT -A FORWARD -p udp --sport 53 -d $desktop_net,$laptop_net -i eth0 -j ACCEPT

#$IPT -A FORWARD -j DROP


$IPT -P INPUT DROP
$IPT -P OUTPUT DROP
$IPT -P FORWARD DROP

