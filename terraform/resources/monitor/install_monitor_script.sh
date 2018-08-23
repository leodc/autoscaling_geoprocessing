#!/bin/bash

echo -n "Installing monitor script..."
mkdir /home/ubuntu/daemon
mv /home/ubuntu/monitor.pl /home/ubuntu/daemon/monitor.pl
echo "OK"

cd /home/ubuntu/daemon

echo -n "Starting monitor.."
nohup perl ./monitor.pl &
echo "OK"

sleep 1
