#!/bin/bash

echo -n "Starting node_exporter... "
cd /home/ubuntu/node_exporter-0.16.0.linux-amd64/
nohup ./node_exporter &
echo "OK"

sleep 1
