
# Requirements
# debian/ubuntu

apt-get -y update && apt-get -y upgrade
apt-get -y install strongswan xl2tpd libstrongswan-standard-plugins libstrongswan-extra-plugins

# Setup variables for L2TP connestion
VPN_SERVER_IP=''
VPN_IPSEC_PSK='y'
VPN_USER=''
VPN_PASSWORD=''
VPN_CONNETCTION_NAME='VPN1'

cat > /etc/ipsec.conf <<EOF
config setup
conn %default
  ikelifetime=60m
  keylife=20m
  rekeymargin=3m
  keyingtries=1
  keyexchange=ikev1
  authby=secret

conn $VPN_CONNETCTION_NAME
  keyexchange=ikev1
  left=%defaultroute
  auto=add
  authby=secret
  type=transport
  leftprotoport=17/1701
  rightprotoport=17/1701
  right=$VPN_SERVER_IP
EOF

cat > /etc/ipsec.secrets <<EOF
: PSK "$VPN_IPSEC_PSK"
EOF

chmod 600 /etc/ipsec.secrets

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[lac $VPN_CONNETCTION_NAME]
lns = $VPN_SERVER_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

cat > /etc/ppp/options.l2tpd.client <<EOF
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-chap
noccp
noauth
mtu 1280
mru 1280
noipdefault
defaultroute
usepeerdns
connect-delay 5000
name $VPN_USER
# Better to use /etc/ppp/chap-secrets file for storing password
#password $VPN_PASSWORD
remotename L2TP
EOF

chmod 600 /etc/ppp/options.l2tpd.client

echo "${VPN_USER} L2TP ${VPN_PASSWORD} *" >> /etc/ppp/chap-secrets

service strongswan restart
service xl2tpd restart

cat > /usr/local/bin/start-vpn <<EOF
#!/bin/bash

(service strongswan start ;
sleep 2 ;
service xl2tpd start) &&
 
(echo -e "\nConnecting to ${VPN_CONNETCTION_NAME} ....... \n") && (

ipsec up $VPN_CONNETCTION_NAME
echo "c ${VPN_CONNETCTION_NAME}" > /var/run/xl2tpd/l2tp-control
sleep 5
#ip route add 10.0.0.0/24 dev ppp0
) && (echo -e "\nConnected to ${VPN_CONNETCTION_NAME} ! \n")
EOF
chmod +x /usr/local/bin/start-vpn

cat > /usr/local/bin/stop-vpn <<EOF
#!/bin/bash

(echo "d ${VPN_CONNETCTION_NAME}" > /var/run/xl2tpd/l2tp-control
ipsec down $VPN_CONNETCTION_NAME) && (
service xl2tpd stop ;
service strongswan stop) && (echo -e "\nConnection to ${VPN_CONNETCTION_NAME} closed \n") 
EOF

chmod +x /usr/local/bin/stop-vpn
echo "To stop VPN type: stop-vpn"
