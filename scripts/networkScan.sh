	#!/usr/bin/env bash
    
    if ! command -v nmap >/dev/null; then
		echo "nmap not found"
		echo " sudo apt install nmap"
		return 1
	fi

	interface=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
	network=$(ip -o -f inet addr show "$interface" | awk '{print $4}')

	echo "Scanning network $network on interface $interface..."
	nmap -sn "$network"