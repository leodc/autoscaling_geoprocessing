#!/bin/bash

echo -n "Installing node_exporter... "
wget https://github.com/prometheus/node_exporter/releases/download/v0.16.0/node_exporter-0.16.0.linux-amd64.tar.gz
tar xvfz node_exporter-0.16.0.linux-amd64.tar.gz
echo "Done"

# cleaning
rm node_exporter-0.16.0.linux-amd64.tar.gz
