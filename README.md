1. yum -y install openvpn 
2. Place the ca folder at /usr/local
3. place the other shell scripts in /etc/openvpn/server
4. Run the /etc/openvpn/server/build-server.sh script, answer the questions and you now have a fully functional VPN server!

Assumptions:
This script assumes you will be using an internal and external network interface along with firewalld.
Your external network should be accesible from the internet. 
This will not set up split tunneling and assumes you want all traffic over the VPN.

You may of course edit configs after the fact however you please ;)
