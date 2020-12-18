#!/bin/bash

confs=($(ls /etc/openvpn/server/*.conf))

for conf in ${confs[@]}; do
  systemctl stop openvpn-server@${conf##*/}
  systemctl disable openvpn-server@${conf##*/}
  systemctl stop openvpnstat@${conf##*/}
  systemctl disable openvpnstat@${conf##*/}
  rm -f /etc/rsyslog.d/${conf##*/}-history.conf
  rm -f "$conf"
done

rm -rf /var/log/openvpn
rm -rf /etc/openvpn/server/jail
rm -f /etc/openvpn/server/*.orig*
rm -rf /etc/openvpn/client/configs

/usr/local/ca/clear-all.sh

external_ifaces=($(firewall-cmd --zone=external --list-interfaces))
for external_iface in ${external_ifaces[@]}; do
  firewall-cmd --permanent --remove-interface=${external_iface} --zone=external
done
external_services=($(firewall-cmd --zone=external --list-services))
external_ports=($(firewall-cmd --zone=external --list-ports))
for external_port in ${external_ports[@]}; do
  firewall-cmd --permanent --remove-port=${external_port} --zone=external
done
for external_service in ${external_services[@]}; do
  firewall-cmd --permanent --remove-service=openvpn --zone=external
done
firewall-cmd --permanent --remove-masquerade --zone=internal
rm -f /etc/firewalld/direct.xml

systemctl restart firewalld
systemctl restart rsyslog

cat /dev/null > ~/.bash_history
history -c
history -w
auditctl -e0
/bin/bash /var/log/init-logs.sh
