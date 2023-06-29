#!/bin/bash
# starting wireguard
wg-quick up wg0

# generate DNS spoofing list
echo "" > /etc/dnsmasq.d/spoofed.list.conf
for file in "/tmp/dnsmasq/"/*; do
    while read line || [[ -n ${line} ]]; do
        if [ "${line:0:1}" == "#" ]; then
            continue
        fi
        echo "address=/${line}/$VPN_SERVER_IP" >> /etc/dnsmasq.d/spoofed.list.conf
    done < "$file"
done

# starting dnsmasq
dnsmasq --conf-file=/etc/dnsmasq.conf --no-daemon &

# starting sniproxy
sniproxy -f &

wait -n