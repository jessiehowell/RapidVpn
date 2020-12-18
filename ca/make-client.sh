#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="/usr/local/ca/pki"
export EASYRSA_CERT_EXPIRE="395"

client_dir="/etc/openvpn/client/configs"
conf_dir="/etc/openvpn/server"
conf=
remote_hosts=()
remote_port=
remote_protocol=
remote_cipher=
remote_tls_cipher=
remote_auth=
start_num=$(grep client $EASYRSA_PKI/index.txt |\
            awk '{print $5}' |\
            awk -F- '{print $2}' |\
            tr -d [:alpha:] |\
            sort -n | tail -1)
start_num=$((start_num+1))
count=
suffix=

if [[ ! -f "$conf" ]]; then
  confs=($(ls ${conf_dir}/*.conf 2>/dev/null))
  if [[ 0 -eq ${#confs[@]} ]]; then
    echo "No openvpn configs found!"
    exit 1
  elif [[ 1 -eq ${#confs[@]} ]]; then
   conf=${confs[0]} 
  else 
    echo "Which config are you working with?"
    i=1
    for conf_ in ${confs[@]}; do
      echo "${i}. $conf_"
      $((i+1))
    done
    read ans
  fi
  conf=${confs[$((ans-1))]}
fi

if [[ -f "${conf}" ]]; then
  name_prefix=$(grep "verify-x509-name" $conf | awk '{print $2}')
  remote_protocol=$(grep "^proto" $conf | awk '{print $2}')
  remote_cipher=$(grep "^cipher" $conf | awk '{print $2}')
  remote_tls_cipher=$(grep "^tls-cipher" $conf | awk '{print $2}')
  remote_auth=$(grep "^auth" $conf | awk '{print $2}')
fi

if [[ -z "$name_prefix" ]]; then
  echo "Enter x509 name prefix:"
  read name_prefix
fi

if [[ 0 -eq ${#remote_hosts[@]} ]]; then
  echo "Enter remote vpn host or IP:"
  read ans
  while [[ -n "$ans" ]]; do
    remote_hosts+=("$ans")
    echo "Enter another remote vpn host or IP (leave blank if done):"
    read ans
  done
fi

if [[ -z "$remote_port" ]]; then
  echo "Enter a remote port:"
  read remote_port
fi

if [[ -z "$remote_protocol" ]]; then
  echo "Enter remote vpn protocol:"
  read remote_protocol
fi

if [[ -z "$remote_cipher" ]]; then
  echo "Enter remote vpn cipher (this is in your server config):"
  read remote_cipher
fi

if [[ -z "$remote_auth" ]]; then
  echo "Enter remote vpn auth hash (this is in your server config):"
  read remote_auth
fi

if [[ -z "$remote_tls_cipher" ]]; then
  echo "Enter remote vpn tls cipher (this is in your server config):"
  read remote_tls_cipher
fi

if [[ -z "$start_num" ]]; then
  echo "Enter the starting number (check the number of your last issued client and +1):"
  read start_num
fi

if [[ -z "$count" ]]; then
  echo "Enter the number of clients you wish to make:"
  read count
fi

if [[ -z "$suffix" ]]; then
  echo "Enter a suffix to append to client certs (i.e. vpn-client100a - 'a' is the suffix):"
  read suffix
fi

end_num=$((start_num+count))

mkdir -p $client_dir

for (( i=$start_num; i<$end_num; i++)); do
  $EASYRSA/easyrsa build-client-full ${name_prefix}-client${i}${suffix} nopass 1>/dev/null
  if [[ $? -ne 0 ]]; then
    echo "${name_prefix}-client${i}${suffix} encountered an error... it may already exist."
    exit 1
  fi

  client_config="$client_dir/${name_prefix}-client${i}${suffix}.ovpn"
  if [[ -f "$client_config" ]]; then
    echo "$client_config exists! overwrite [y/n]?"
    read ans
    if [[ "$ans" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
      cat /dev/null > "$client_config"
    else
      continue
    fi
  fi

  #echo all the stuff to ovpn here
  echo "client" >> "$client_config"
  echo "dev tun" >> "$client_config"
  for remote_host in ${remote_hosts[@]}; do
    echo "remote $remote_host $remote_port" >> "$client_config" 
  done
  echo "remote-random" >> "$client_config"
  echo "proto $remote_protocol" >> "$client_config" 
  echo "cipher $remote_cipher" >> "$client_config"
  echo "tls-cipher $remote_tls_cipher" >> "$client_config"
  echo "auth $remote_auth" >> "$client_config"
  echo "keepalive 10 60" >> "$client_config"
  echo "lport 0" >> "$client_config"
  echo "remote-cert-tls server" >> "$client_config"
  echo "log ${name_prefix}-client${i}${suffix}.log" >> "$client_config"
  echo "key-direction 1" >> "$client_config"
  echo "verify-x509-name $name_prefix name-prefix" >> "$client_config"
  echo "comp-lzo no" >> "$client_config"

  #add the certs
  echo '<ca>' >> "$client_config"
  cat "${EASYRSA_PKI}/ca.crt" >> "$client_config" 
  echo '</ca>' >> "$client_config"

  echo '<cert>' >> "$client_config"
    sed -n '/BEGIN.*-/,/END.*-/p' "${EASYRSA_PKI}/issued/${name_prefix}-client${i}${suffix}.crt" >> "$client_config"
  echo '</cert>' >> "$client_config"

  echo '<key>' >> "$client_config"
  cat "${EASYRSA_PKI}/private/${name_prefix}-client${i}${suffix}.key" >> "$client_config"
  echo '</key>' >> "$client_config"

  echo '<tls-auth>' >> "$client_config"
  cat "${EASYRSA_PKI}/private/ta.key" >> "$client_config"
  echo '</tls-auth>' >> "$client_config"
done
