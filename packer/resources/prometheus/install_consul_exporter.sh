#!/bin/bash

echo -n "Installing consul_exporter... "
wget https://github.com/prometheus/consul_exporter/releases/download/v0.4.0/consul_exporter-0.4.0.linux-amd64.tar.gz
tar xvfz consul_exporter-0.4.0.linux-amd64.tar.gz
echo "Done"

#cleaning
rm consul_exporter-0.4.0.linux-amd64.tar.gz
