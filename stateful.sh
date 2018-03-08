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

iptables -F
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Accept established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#SSH rule
iptables -A INPUT -i eth0 -p tcp --dport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#Allow DNS, HTTP,and HTTPS
iptables -A INPUT -i eth1 -p udp -s 10.0.0.0/24,10.0.2.0/24,10.0.1.0/24,128.39.120.0/16 --dport 53 -m conntrack --ctstate NEW, ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth1 -p udp -s 10.0.0.0/24,10.0.2.0/24,10.0.1.0/24,128.39.120.0/16 --dport 80 -m conntrack --ctstate NEW, ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth1 -p tcp -s 10.0.0.0/24,10.0.2.0/24,10.0.1.0/24,128.39.120.0/16  --dports 53 -m conntrack --ctstate NEW,ESTABLISHED  -j ACCEPT
iptables -A INPUT -i eth1 -p tcp -s 10.0.0.0/24,10.0.2.0/24,10.0.1.0/24,128.39.120.0/16 --dport 80 -m conntrack --ctstate NEW, ESTABLISHED -j ACCEPT
#Logging and invalid attempt
iptables -A INPUT -m state --state INVALID -j LOG
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A OUTPUT -m state --state INVALID -j LOG
iptables -A OUTPUT -m state --state INVALID -j DROP

# SSH Rules For External Network

iptables -A INPUT -s 0/0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT

# SSH Rules for Internal Network
iptables -A INPUT -i eth1 -p tcp -s 10.0.0.0/24,10.0.2.0/24,10.0.1.0/24 --sport 22 -j ACCEPT
iptables -A OUTPUT -o eth1 -p tcp -d 10.0.0.0/24,10.0.2.0/24,10.0.1.0/24 --dport 22 -j ACCEPT

# Log all new SSH
iptables -I INPUT -p tcp --dport 22 -m limit --limit 2/s -j LOG

# Allow UDP port 120
iptables -A INPUT -i eth1 -p udp -s 10.0.0.4 --dport 120 -j ACCEPT

#Allow ICMP echo request
iptables -A INPUT -i eth0 -p icmp --icmp-type 8 -j ACCEPT
iptables -A OUTPUT -o eth1 -p icmp --icmp-type 8 -j ACCEPT

#Allow Tracert from Windows Server
iptables -A FORWARD -i eth1 -o eth0 -p icmp -s 10.0.0.3 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -p icmp -d 10.0.0.3 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.0.3 -o eth0 -j SNAT --to-source 128.39.120.112

iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP








