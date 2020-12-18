#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="${EASYRSA}/pki"

conf="${1}"
client_conf_dir="/etc/openvpn/client/configs"
mkdir -p "$client_conf_dir/revoked"

if [[ -z "$conf" ]]; then
  echo "Enter the client name without file extensions (i.e. vpn1-client10a):"
  read conf
fi

if [[ ! -f "${EASYRSA_PKI}/issued/${conf}.crt" ]]; then
   echo "Unable to locate cert for ${ans}..."
  exit 1
fi
