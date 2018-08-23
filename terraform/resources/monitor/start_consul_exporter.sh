#!/bin/bash

echo -n "Starting consul exporter... "
cd /home/ubuntu/consul_exporter-0.4.0.linux-amd64/
nohup ./consul_exporter &
echo "OK"

sleep 1
