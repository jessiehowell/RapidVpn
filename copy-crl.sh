#!/bin/bash

/bin/cp /usr/local/ca/pki/crl.pem /etc/openvpn/server/jail/crl.pem
chown nobody:nobody /etc/openvpn/server/jail/crl.pem
chmod 444 /etc/openvpn/server/jail/crl.pem
chcon -t openvpn_etc_t /etc/openvpn/server/jail/crl.pem
