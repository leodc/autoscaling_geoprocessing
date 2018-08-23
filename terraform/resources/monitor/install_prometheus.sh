#!/bin/bash

echo "Installing prometheus"
wget https://github.com/prometheus/prometheus/releases/download/v2.3.2/prometheus-2.3.2.linux-amd64.tar.gz
tar xvfz prometheus-*.tar.gz
cd prometheus-*

echo "Setting basic configuration"
mv /home/ubuntu/prometheus.yml ./prometheus.yml

echo -n "Starting prometheus..."
nohup ./prometheus --config.file=prometheus.yml --web.enable-lifecycle &
echo "OK"

# cleanning
rm prometheus-*.tar.gz

sleep 1
