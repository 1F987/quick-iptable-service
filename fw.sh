#!/bin/bash

echo "Check if ipset is intalled (apt install ipset)"

declare -a COUNTRIES
declare -A PORTS
########################################################################
# Countries to block
COUNTRIES=["cn" "af"]

# Whitelist PORTS & IP 
# example : PORTS[22]="192.168.1.13,10.10.0.1"
# example no IP restriction : PORTS[22]="0.0.0.0./0"
#PORTS[22]=192.168.1.17/32
#PORTS[5432]=0.0.0.0/0

PORTS[22]="192.168.1.1/24"
PORTS[5432]="0.0.0.0./0"

# PING 1 or 0
PING=0
########################################################################


IPT=/sbin/iptables
IP6T=/sbin/ip6tables

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

do_start() {
    
    # Prepare CIDR list
    echo > blockcountry.sh
    # Loop for each countries
	for C in "${COUNTRIES[@]}"
	do
    curl -sS --insecure "https://www.ipdeny.com/ipblocks/data/aggregated/${C}-aggregated.zone" >> /tmp/blockcountry.sh
		printf  "${YELLOW}- ${C} blocked ! ${NC}\n"
	done
    
    sed -i '/^#/d' /tmp/blockcountry.sh
    sed -i 's/^/ipset add countryblocker /g' /tmp/blockcountry.sh
    sed  -i '1i ipset create countryblocker nethash' /tmp/blockcountry.sh
    chmod +x blockcountry.sh
    bash blockcountry.sh
    
	#####################
	# Delete old rules #
	#####################
	$IPT -t filter -F
	$IPT -t filter -X
	$IPT -t nat -F
	$IPT -t nat -X
	$IPT -t mangle -F
	$IPT -t mangle -X
	$IP6T -t filter -F
	$IP6T -t filter -X
	$IP6T -t mangle -F
	$IP6T -t mangle -X
    
	##############################
	# Set default policy to DROP #
	##############################
	$IPT -t filter -P INPUT DROP
	$IPT -t filter -P FORWARD DROP
    	$IPT -t filter -P OUTPUT DROP # Drop OUTPUT too...
	$IP6T -t filter -P INPUT DROP
	$IP6T -t filter -P FORWARD DROP
	$IP6T -t filter -P OUTPUT DROP
    
	###########
	# ACCEPT #
	###########
	# Allow connections that are already established or related to an established connection
	$IPT -t filter -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    	$IPT -t filter -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
	# Allow trafic on internal network
	$IPT -t filter -A INPUT -i lo -j ACCEPT
	$IPT -t filter -A OUTPUT -o lo -j ACCEPT
	$IP6T -t filter -A INPUT -i lo -j ACCEPT
	$IP6T -t filter -A OUTPUT -o lo -j ACCEPT
    
	# Allow DNS on 53
	$IPT -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
	$IPT -t filter -A INPUT -p udp --dport 53 -j ACCEPT
    	$IPT -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
    	$IPT -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT

	# Allow NTP on 123
	$IPT -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT

	############################
	# Specific ports for apps  #
	############################

	# Loop for each ports and ip addresses listed above
	for K in "${!PORTS[@]}"
	do
		$IPT -t filter -A INPUT -p tcp -s ${PORTS[$K]} --dport $K -j ACCEPT
		printf  "${YELLOW}Open port ${GREEN} $K ${YELLOW} for ${GREEN} ${PORTS[$K]} ${NC}\n"
	done

	len=${#PORTS[@]}
	if [ $len = 0 ]
	then
		printf "${YELLOW}No INPUT allowed${NC}\n"
	fi

	# Allow Ping ?
	if [ $PING = 1 ]
	then
		$IPT -A INPUT -p icmp -j ACCEPT
        $IPT -A OUTPUT -p icmp -j ACCEPT
		printf "${GREEN}Ping autorisé${NC}\n"
	else
		printf "${RED}Ping interdit${NC}\n"
	fi
    

	#########
	# DROP #
	#########
	# Block common attacks
	$IPT -A INPUT -m conntrack --ctstate INVALID -j DROP # Drop non-conforming packets, such as malformed headers, etc.
	$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j DROP # Drop all incoming malformed NULL packets 
	$IPT -A INPUT -p tcp ! --syn -m conntrack --ctstate NEW -j DROP # Drop syn-flood attack packets
	$IPT -A INPUT -p tcp --tcp-flags ALL ALL -j DROP # Drop incoming malformed XMAS packets
    
    # Block CIDR for banned countries
    $IPT -A INPUT -m set --match-set countryblocker src -j DROP
    
	printf "${GREEN}Firewall started [OK]${NC}\n"

	# Optional Log 
	# $IPT -A INPUT -m limit --limit 5/min -j LOG  --log-prefix "+++ IPv4 packet rejected +++ "
}

do_stop() {
	################################
	# Set default policy to ACCEPT #
	################################
	$IPT -t filter -P INPUT ACCEPT
	$IPT -t filter -P FORWARD ACCEPT
	$IPT -t filter -P OUTPUT ACCEPT
	$IP6T -t filter -P INPUT ACCEPT
	$IP6T -t filter -P FORWARD ACCEPT
	$IP6T -t filter -P OUTPUT ACCEPT
    
	#####################
	# Delete old rules #
	#####################
	$IPT -t filter -F
	$IPT -t filter -X
	$IPT -t nat -F
	$IPT -t nat -X
	$IPT -t mangle -F
	$IPT -t mangle -X
	$IP6T -t filter -F
	$IP6T -t filter -X
	$IP6T -t mangle -F
	$IP6T -t mangle -X
	printf "${RED}Firewall stopped [OK]${NC}\n"
}

do_status() {
	# Display rules
	clear
	printf "${YELLOW}-----------------------------------------------${NC}\n"
	printf "${YELLOW}Status IPV4${NC}\n"
	printf "${YELLOW}-----------------------------------------------${NC}\n"
	$IPT -L -n -v
	echo
	printf "${YELLOW}-----------------------------------------------${NC}\n"
	printf "${YELLOW}Status IPV6${NC}\n"
	printf "${YELLOW}-----------------------------------------------${NC}\n"
	$IP6T -L -n -v
	printf "${YELLOW}-----------------------------------------------${NC}\n"
}

case "$1" in
    start)
        do_start
        exit 0
    ;;
    stop)
        do_stop
        exit 0
    ;;
    restart)
        do_stop
        do_start
        exit 0
    ;;
    status)
        do_status
        exit 0
    ;;
    *)
        echo "Usage: {start|stop|restart|status}"
        exit 1
    ;;
esac
