#!/bin/bash

server_name=$(hostname)
dhcp_network="192.168.1.0"
dhcp_netmask="255.255.255.0"
dns_servers=()
protocol="udp"
port="1194"
ip_addrs=($(ip addr | grep -w 'inet' | grep -v 127.0.0.1 | awk '{print $2}' | awk -F/ '{print $1}'))
listen_addr=
tun_num=0

echo "Use hostname: $server_name [y/n]?"
read ans

if [[ "$ans" =~ ^[Nn][Oo]?$ ]]; then
  echo "Enter a hostname:"
  read ans_
  server_name="$ans_" 
fi

if [[ 0 -eq ${#ip_addrs[@]} ]]; then
  echo "No configured IP Addresses, enter one now, or leave blank to config later:"
  read ans
  listen_addr="$ans"
else
  echo "Which IP Address do you want to listen on?"
  i=1
  for ip_addr in ${ip_addrs[@]}; do
    echo "${i}. ${ip_addr}"
    i=$((i+1))
  done
  read ans
  listen_addr=${ip_addrs[$((ans-1))]}
fi

echo "Choose a protocol udp or tcp (default: udp)"
read ans
if [[ -n "$ans" ]]; then
  protocol="$ans"
else
  echo -en "\033[1A\033[2K"
  echo "$protocol"
fi

echo "Enter a port number (default: 1194)"
read ans
if [[ -n "$ans" ]]; then
  port="$ans"
else
  echo -en "\033[1A\033[2k"
  echo "$port"
fi

echo "Enter a tun interface number (default: 0)"
read ans
if [[ -n "$ans" ]]; then
  tun_num="$ans"
else
  echo -en "\033[1A\033[2k"
  echo "$tun_num"
fi

echo "Enter DHCP network for clients (default: 192.168.1.0):"
read ans
if [[ -n "$ans" ]]; then
  dhcp_network="$ans"
else
  echo -en "\033[1A\033[2K"
  echo "$dhcp_network"
fi

echo "Enter DHCP netmask (default: 255.255.255.0):"
read ans
if [[ -n "$ans" ]]; then
  dhcp_netmask="$ans"
else
  echo -en "\033[1A\033[2K"
  echo "$dhcp_netmask"
fi

echo "Enter a DNS server address to push to clients (leave blank for none):"
read ans
while [[ -n "$ans" ]]; do
  dns_servers+=( "$ans" )
  echo "Enter another DNS server address (leave blank if none):"
  read ans
done 

echo "Generate vpn conf with the following settings:"
echo
echo -e "\tlocal ${listen_addr}"
echo -e "\tdev tun${tun_num}"
echo -e "\tport ${port}"
echo -e "\tproto ${protocol}"
echo -e "\tserver ${dhcp_network} ${dhcp_netmask}"
for dns_server in ${dns_servers[@]}; do
  echo -e "\tpush \"dhcp-option DNS ${dns_server}\""
done
echo

echo "confirm [y/n]?"
read ans
if [[ "$ans" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
  if [[ -f "./${server_name}.conf" ]]; then
    echo "./${server_name}.conf already exists; overwrite [y/n]?"
    read ans
    if [[ "$ans" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
      cat /dev/null > ./${server_name}.conf
    else
      mv ./${server_name}.conf ./${server_name}.orig.$(date +'%Y%m%d%H%M%S')
    fi
  fi
  mkdir -p /var/log/openvpn
  touch /var/log/openvpn/${server_name}-status.log
  touch /var/log/openvpn/${server_name}-server.log
  touch /var/log/openvpn/${server_name}-history.log
  mkdir -p /etc/openvpn/server/jail/tmp
  [ -f /usr/local/ca/pki/crl.pem ] && /bin/cp /usr/local/ca/pki/crl.pem /etc/openvpn/server/jail
  chown -R nobody:nobody /etc/openvpn/server/jail
  chcon -R -t openvpn_etc_t /etc/openvpn/server/jail
  chcon -R -t openvpn_var_log_t /var/log/openvpn
  chmod 644 /var/log/openvpn/*.log

  echo "local ${listen_addr}" >> ./${server_name}.conf
  echo "dev tun${tun_num}" >> ./${server_name}.conf
  echo "port ${port}" >> ./${server_name}.conf
  echo "proto ${protocol}" >> ./${server_name}.conf
  echo "topology subnet" >> ./${server_name}.conf
  echo "tls-cipher TLS-DHE-RSA-WITH-AES-128-GCM-SHA256" >> ./${server_name}.conf
  echo "remote-cert-tls client" >> ./${server_name}.conf
  echo "server ${dhcp_network} ${dhcp_netmask}" >> ./${server_name}.conf
  echo "push \"redirect-gateway def1\"" >> ./${server_name}.conf
  for dns_server in ${dns_servers[@]}; do
    echo "push \"dhcp-option DNS ${dns_server}\"" >> ./${server_name}.conf
  done
  echo "cipher AES-256-GCM" >> ./${server_name}.conf
  echo "auth SHA256" >> ./${server_name}.conf
  echo "tls-version-min 1.2" >> ./${server_name}.conf
  echo "keepalive 10 120" >> ./${server_name}.conf
  echo "log-append /var/log/openvpn/${server_name}-server.log" >> ./${server_name}.conf
  echo "status /var/log/openvpn/${server_name}-status.log" >> ./${server_name}.conf
  echo "verify-x509-name ${server_name} name-prefix" >> ./${server_name}.conf
  echo "key-direction 0" >> ./${server_name}.conf
  echo "mssfix 1374" >> ./${server_name}.conf
  echo "replay-window 128 30" >> ./${server_name}.conf
  echo "chroot jail" >> ./${server_name}.conf
  echo "ifconfig-pool-persist ipp.txt 400" >> ./${server_name}.conf
  echo "comp-lzo no" >> ./${server_name}.conf
  echo "push \"comp-lzo no\"" >> ./${server_name}.conf
  echo "persist-key" >> ./${server_name}.conf
  echo "persist-tun" >> ./${server_name}.conf
  echo "user nobody" >> ./${server_name}.conf
  echo "group nobody" >> ./${server_name}.conf
  echo "verb 4" >> ./${server_name}.conf
  echo "mute 5" >> ./${server_name}.conf
  echo "crl-verify crl.pem" >> ./${server_name}.conf 
fi
