#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="$EASYRSA/pki"

ifaces=($(nmcli -t -f device d | grep -v lo))
vpn_server_dir="/etc/openvpn/server"

$EASYRSA/make-ca.sh
$vpn_server_dir/config-settings.sh
  
confs=($(ls ${vpn_server_dir}/*.conf))
if [[ 0 -eq ${#confs[@]} ]]; then
  echo "No openvpn server conf found!"
  exit 1
elif [[ 1 -eq ${#confs[@]} ]]; then
  conf=${confs[0]}
else
  echo "Which config are you working with?"
  i=1
  for conf in ${confs[@]}; do
    echo "$i. ${conf##*/}"
    i=$((i+1))
  done
  read ans
fi

conf=${confs[$((ans-1))]##*/}
server_name=${conf%.*}

tun_iface=$(grep 'tun[0-9]\+$' "${vpn_server_dir}/${conf}" | grep 'tun[0-9]\+$' | awk '{print $2}')
dns_names=()
san_string=
echo "Enter a DNS name - this should be an externally resolvable one! (leave blank for none):"
read ans
while [[ -n "$ans" ]]; do
  dns_names+=("${ans}")
  echo "Enter another DNS name (leave blank if none):"
  read ans
done 
if [[ ${#dns_names[@]} -gt 0 ]]; then
  for ((i=0;i<${#dns_names[@]};i++)); do
    if [[ 0 -eq $i ]]; then
      san_string="DNS:${dns_names[$i]}"
    else
      san_string="${san_string},DNS:${dns_names[$i]}"
    fi
  done
fi

if [[ -n "$san_string" ]]; then
  $EASYRSA/make-server.sh "$server_name" "$san_string"
else
  $EASYRSA/make-server.sh "$server_name"
fi

$vpn_server_dir/config-pki.sh
$vpn_server_dir/copy-crl.sh

echo "Which is your external (vpn) interface (enter number)?"
for ((i=0;i<${#ifaces[@]};i++)); do
  echo "$((i+1)). ${ifaces[$i]}"
done
read ans
external_iface=${ifaces[$((ans-1))]}

echo "Which is your internal (services) interface (enter number)?"
for ((i=0;i<${#ifaces[@]};i++)); do
  echo "$((i+1)). ${ifaces[$i]}"
done
read ans
internal_iface=${ifaces[$((ans-1))]}

echo "What is your services network with /prefix (i.e. 10.0.0.0/16)?"
read service_network

vpn_dhcp_network=$(grep '^server' "${vpn_server_dir}/${conf}" | awk '{print $2}')
vpn_dhcp_netmask=$(grep '^server' "${vpn_server_dir}/${conf}" | awk '{print $3}')
vpn_dhcp_prefix=$(ipcalc -sp ${vpn_dhcp_network} ${vpn_dhcp_netmask} | awk -F= '{print $2}')
vpn_port=$(grep '^port' "${vpn_server_dir}/${conf}" | awk '{print $2}')
vpn_proto=$(grep '^proto' "${vpn_server_dir}/${conf}" | awk '{print $2}')

echo "Creating firewall rules"
firewall-cmd --change-interface=${internal_iface} --zone=internal
firewall-cmd --change-interface=${external_iface} --zone=external
firewall-cmd --change-interface=${tun_iface} --zone=drop
firewall-cmd --add-port=${vpn_port}/${vpn_proto} --zone=external
firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i ${tun_iface} -o ${internal_iface} -s ${vpn_dhcp_network}/${vpn_dhcp_prefix} -d ${service_network} -m conntrack --ctstate NEW -j ACCEPT
firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i ${tun_iface} -o ${internal_iface} -s ${vpn_dhcp_network}/${vpn_dhcp_prefix} -d ${service_network} -p icmp -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i ${tun_iface} -o ${external_iface} -p icmp -m state --state NEW,RELATED,ESTABLISHED -j DROP
firewall-cmd --runtime-to-permanent

echo ":syslogtag, isequal, \"${server_name^^}-STAT:\" /var/log/openvpn/${server_name}-history.log" > "/etc/rsyslog.d/${server_name}-history.conf"
echo '& stop' >> "/etc/rsyslog.d/${server_name}-history.conf"

systemctl restart rsyslog

systemctl enable openvpnstat@${server_name} 
systemctl start openvpnstat@${server_name}
systemctl enable openvpn-server@${server_name}
systemctl start openvpn-server@${server_name}
