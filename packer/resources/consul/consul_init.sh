#!/usr/bin/env bash
set -e

if [[ "$1" == "server" ]]; then
  FLAG_AUX="-server -bootstrap-expect=${SERVER_COUNT}"
else
  FLAG_AUX=""
fi

cat >/tmp/consul_flags << EOF
CONSUL_FLAGS="${FLAG_AUX} -join=${CONSUL_JOIN} -node-meta=profile:$2 -data-dir=/opt/consul/data"
EOF

echo -n "Installing Systemd service... "
sudo mkdir -p /etc/sysconfig
sudo mkdir -p /etc/systemd/system/consul.d
sudo chown root:root /home/ubuntu/consul.service
sudo mv /home/ubuntu/consul.service /etc/systemd/system/consul.service
sudo mv /tmp/consul*json /etc/systemd/system/consul.d/ || echo
sudo chmod 0644 /etc/systemd/system/consul.service
sudo mv /tmp/consul_flags /etc/sysconfig/consul
sudo chown root:root /etc/sysconfig/consul
sudo chmod 0644 /etc/sysconfig/consul
echo "OK"

echo -n "Starting Consul..."
sudo systemctl enable consul.service
sudo systemctl start consul
echo "OK"
