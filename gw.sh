#!/bin/bash

gateway=$1
choke="10.0.0.2"
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

iptables -F
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -t nat -F
iptables -t mangle -F
iptables -X
iptables -N DMZ
iptables -N DNS
iptables -N SSH
iptables -N FTP

#Your iptables commands here!
iptables -A DNS -j ACCEPT

# LOG SSH connections, see the logs in /var/log/kern.log
#iptables -I INPUT -p tcp --dport 22 -m limit --limit 2/s -j LOG

# Accept established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Deny and LOG spoofed packets
iptables -A INPUT -i eth0 -s $dmz_zone,$laptop_net,$desktop_net,$class_A_priv,$class_B_priv,$class_C_priv,$class_D_multicast,$class_E_reserved_net -j LOG

iptables -A INPUT -i eth0 -s $dmz_zone,$laptop_net,$desktop_net,$class_A_priv,$class_B_priv,$class_C_priv,$class_D_multicast,$class_E_reserved_net -j DROP

iptables -A INPUT -i eth0 -s $gateway -j DROP
iptables -A INPUT -i eth0 -s $LOOPBACK -j LOG
iptables -A INPUT -i eth0 -s $LOOPBACK -j DROP

# SSH Rules For External Net
iptables -A INPUT -s 0/0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT

# SSH Rules for Internal Network
iptables -A INPUT -i eth1 -p tcp -s $dmz_zone,$desktop_net,$laptop_net --sport 22 -j ACCEPT
iptables -A OUTPUT -o eth1 -p tcp -d $dmz_zone,$desktop_net,$laptop_net --dport 22 -j ACCEPT

#################### Open port for DNS ######################################
iptables -A FORWARD -p udp -i eth1 --dport 53 -j DNS
iptables -A FORWARD -p udp -i eth0 --sport 53 -j DNS
iptables -A POSTROUTING -t nat -p udp --dport 53 -o eth0 -j MASQUERADE
#############################################################################

################## INPUT CHAIN ##########################
$IPT -A INPUT -i eth1 -p udp --dport 1415 -s $desktop -j ACCEPT 
#$IPT -A INPUT -i eth0 -p tcp --dport 123456 --syn -j ACCEPT
#$IPT -A INPUT -i eth0 -p udp --dport 123456 -j ACCEPT
$IPT -A INPUT -i eth1 -p tcp --sport 888 -s $windows_server -j ACCEPT

################## OUTPUT CHAIN ##########################
$IPT -A OUTPUT -o eth1 -p udp --dport 1415 -d $desktop -j ACCEPT
#$IPT -A OUTPUT -o eth0 -p udp --sport 123456 -j ACCEPT
$IPT -A OUTPUT -o eth1 -p tcp --dport 888 -d $windows_server -j ACCEPT


################## SNAT for DMZ ##################################
iptables -t nat -A POSTROUTING -s $dmz_zone -o eth0 -j SNAT --to-source $gateway
##################################################################

################# SNAT FOR LAPTOP AND DESKTOP NETWORKS ############
iptables -t nat -A POSTROUTING -s $laptop_net,$desktop_net -p tcp --dport 22 -j MASQUERADE
###################################################################

########## Allow Desktop to Access Web ############################
iptables -A FORWARD -i eth1 -o eth0 -p tcp -s $desktop_net --dport 80 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -p tcp -d $desktop_net ! --syn -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -p tcp -s $desktop_net -j MASQUERADE
#####################################################################

########### Allow Access to web server on server1 from the Internet #######
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to $linux_server
iptables -A FORWARD -i eth0 -o eth1 -p tcp -d $linux_server --dport 80 --syn -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
############################################################################

# Allow port 8933,3389 port forwarding and DNAT
iptables -A FORWARD -i eth0 -o eth1 -p tcp -m state --state NEW -m multiport --dports 8933,3389 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -p tcp -m state --state ESTABLISHED,RELATED -s $windows_server --sport 3389 -j ACCEPT
iptables -t nat -A PREROUTING -i eth0 -p tcp -m state --state NEW -m multiport --dports 8933,3389 -j DNAT --to-destination $windows_server:3389

# Log all new SSH
#iptables -I INPUT -p tcp --dport 22 -m limit --limit 2/s -j LOG


#Allow ICMP echo request
iptables -A INPUT -i eth0 -p icmp --icmp-type 8 -j ACCEPT
iptables -A OUTPUT -o eth1 -p icmp --icmp-type 8 -j ACCEPT

#Allow Tracert from Windows Server
iptables -A FORWARD -i eth1 -o eth0 -p icmp -s $windows_server -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -p icmp -d $windows_server -j ACCEPT
iptables -t nat -A POSTROUTING -s $windows_server -o eth0 -j SNAT --to-source $gateway

############### SSH PORT FORWARDING #########################
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 10003 --syn -j DNAT --to-destination $windows_server:22
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 10004 --syn -j DNAT --to-destination $linux_server:22
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 10002 --syn -j DNAT --to-destination $choke:22
iptables -t nat -A PREROUTING -i eth0 -p tcp -s 128.39.120.101 --dport 10012 --syn -j DNAT --to-destination $laptop:22
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 10022 --syn -j DNAT --to-destination $desktop:22

############## PORT FORWARDING FOR ALLMEDIA SERVER ##########
$IPT -t nat -A PREROUTING -i eth0 -p tcp --dport 888 -m state --state NEW -j DNAT --to-destination $windows_server
#############################################################

############## FORWARD TO ALLMEDIAsERVER port ###############
$IPT -A FORWARD -i eth0 -p tcp --dport 888 -m state --state NEW -j ACCEPT
$IPT -A FORWARD -i eth1 -p tcp --sport 888 -m state --state ESTABLISHED,RELATED -j ACCEPT
#############################################################

################### FORWARD TO SSH #####################
iptables -A FORWARD -i eth0 -p tcp --dport 22 --syn -j SSH
iptables -A FORWARD -i eth1 -p tcp --sport 22 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -p tcp --dport 22 --syn -j SSH

##############SSH Chain ##############################
iptables -A SSH -d $choke,$laptop_net,$desktop_net,$windows_server,$linux_server -j ACCEPT
iptables -A SSH -s $laptop_net,$desktop_net -j ACCEPT
iptables -A SSH -j DROP

################# ALLOW OUTGOING FTP FROM Desktop_net #####################
iptables -t nat -A POSTROUTING -o eth0 -s $desktop_net -p tcp -m multiport --dport 20,21,1024 -j MASQUERADE
###########################################################################

################ FTP Chain ########################
$IPT -A FTP -p tcp -s $desktop_net --syn -o eth0 -j ACCEPT
$IPT -A FTP -p tcp -s $desktop_net -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A FTP -j DROP
###################################################

#################### FORWARD CHAIN #######################################
$IPT -A FORWARD -p tcp -m multiport --dports 20,21,1024 -j FTP
$IPT -A FORWARD -p tcp --syn -d 10.0.1.2 --dport 3306 -j ACCEPT
##########################################################################

#################### FORWARD MYSQL Connections on port 3306 ##############
$IPT -t nat -A PREROUTING -i eth0 -p tcp --dport 3306 --syn -j DNAT --to-destination $laptop
###########################################################################

#################### SNAT FOR MYSQL Connections ###########################
$IPT -t nat -A POSTROUTING -o eth0 -p tcp --sport 3306 -m state --state ESTABLISHED,RELATED -j MASQUERADE
###########################################################################

#################### SNAT FOR ALLMEDIA SERVER ############################
$IPT -t nat -A POSTROUTING -o eth0 -p tcp --sport 888 -m state --state ESTABLISHED,RELATED -j MASQUERADE
##########################################################################


iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
                                                                                               
