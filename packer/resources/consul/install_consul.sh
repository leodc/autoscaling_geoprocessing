#!/usr/bin/env bash
set -e

echo "Installing dependencies..."
sudo su -s /bin/bash -c 'sleep 30 && apt-get update && apt-get install unzip' root

echo "Fetching Consul..."
CONSUL=1.2.2
cd /tmp
wget https://releases.hashicorp.com/consul/${CONSUL}/consul_${CONSUL}_linux_amd64.zip -O consul.zip --quiet

echo "Installing Consul..."
unzip consul.zip >/dev/null
chmod +x consul
sudo mv consul /usr/local/bin/consul
sudo mkdir -p /opt/consul/data

