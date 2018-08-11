#!/usr/bin/env bash
set -e

# echo "Waiting for the host full start"
# sudo su -s /bin/bash -c 'sleep 30' root


# Read from the file we created
# replaced by environment variable
# SERVER_COUNT=2

# replaced by environment variable
# CONSUL_JOIN=$(cat /tmp/consul-server-addr | tr -d '\n')

# Write the flags to a temporary file

if [[ "$1" == "server" ]]; then
  FLAG_AUX="-server -bootstrap-expect=${SERVER_COUNT}"
else
  FLAG_AUX=""
fi

cat >/tmp/consul_flags << EOF
CONSUL_FLAGS="${FLAG_AUX} -join=${CONSUL_JOIN} -node-meta=profile:$2 -data-dir=/opt/consul/data"
EOF

if [ -f /tmp/upstart.conf ];
then
  echo "Installing Upstart service..."
  sudo mkdir -p /etc/consul.d
  sudo mkdir -p /etc/service
  sudo chown root:root /tmp/upstart.conf
  sudo mv /tmp/upstart.conf /etc/init/consul.conf
  sudo chmod 0644 /etc/init/consul.conf
  sudo mv /tmp/consul_flags /etc/service/consul
  sudo chmod 0644 /etc/service/consul
else
  echo "Installing Systemd service..."
  sudo mkdir -p /etc/sysconfig
  sudo mkdir -p /etc/systemd/system/consul.d
  sudo chown root:root /home/ubuntu/consul.service
  sudo mv /home/ubuntu/consul.service /etc/systemd/system/consul.service
  sudo mv /tmp/consul*json /etc/systemd/system/consul.d/ || echo
  sudo chmod 0644 /etc/systemd/system/consul.service
  sudo mv /tmp/consul_flags /etc/sysconfig/consul
  sudo chown root:root /etc/sysconfig/consul
  sudo chmod 0644 /etc/sysconfig/consul
fi




echo "Starting Consul..."
if [ -x "$(command -v systemctl)" ]; then
  echo "using systemctl"
  sudo systemctl enable consul.service
  sudo systemctl start consul
else
  echo "using upstart"
  sudo start consul
fi

