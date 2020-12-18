#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="${EASYRSA}/pki"

confs=($(ls /etc/openvpn/server/*.conf))

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

if [[ -f "${EASYRSA_PKI}/ca.crt" ]]; then
  echo '<ca>' > ./${server_name}.tmp
  cat "${EASYRSA_PKI}/ca.crt" >> ./${server_name}.tmp
  echo '</ca>' >> ./${server_name}.tmp
else
  echo "no CA cert found!"
  rm -f ./${server_name}.tmp
  exit 1
fi

if [[ -f "${EASYRSA_PKI}/issued/${server_name}.crt" ]]; then
  echo '<cert>' >> ./${server_name}.tmp
  sed -n '/BEGIN.*-/,/END.*-/p' "${EASYRSA_PKI}/issued/${server_name}.crt" >> ./${server_name}.tmp
  echo '</cert>' >> ./${server_name}.tmp
else
  echo "no Server cert found!"
  rm -f ./${server_name}.tmp
  exit 1
fi

if [[ ! -f "${EASYRSA_PKI}/dh.pem" ]]; then
  /usr/local/ca/easyrsa gen-dh
fi

if [[ -f "${EASYRSA_PKI}/dh.pem" ]]; then
  echo '<dh>' >> ./${server_name}.tmp
  cat "${EASYRSA_PKI}/dh.pem" >> ./${server_name}.tmp
  echo '</dh>' >> ./${server_name}.tmp
else
  echo "no DH Params found!"
  rm -f ./${server_name}.tmp
  exit 1
fi

if [[ -f "${EASYRSA_PKI}/private/${server_name}.key" ]]; then
  echo '<key>' >> ./${server_name}.tmp
  cat "${EASYRSA_PKI}/private/${server_name}.key" >> ./${server_name}.tmp
  echo '</key>' >> ./${server_name}.tmp
else
  echo "no Private Key found!"
  rm -f ./${server_name}.tmp
  exit 1
fi

if [[ ! -f "${EASYRSA_PKI}/private/ta.key" ]]; then
  openvpn --genkey --secret "${EASYRSA_PKI}/private/ta.key"
fi

if [[ -f "${EASYRSA_PKI}/private/ta.key" ]]; then
  echo '<tls-auth>' >> ./${server_name}.tmp
  cat "${EASYRSA_PKI}/private/ta.key" >> ./${server_name}.tmp
  echo '</tls-auth>' >> ./${server_name}.tmp
else
  echo "no TLS Auth Key found!"
  rm -f ./${server_name}.tmp
  exit 1
fi

cat ./${server_name}.tmp >> /etc/openvpn/server/${conf}
/bin/bash ${EASYRSA}/make-crl.sh
rm -f ./${server_name}.tmp
