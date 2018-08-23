#!/bin/bash

mkdir /home/ubuntu/locust
cd /home/ubuntu/locust


echo -n "Installing locust..."
sudo apt-get install python-pip -y
pip install locustio
echo "ok"

mv /home/ubuntu/locustfile.py .

echo -n "Starting locust..."
nohup /home/ubuntu/.local/bin/locust --host=http://127.0.0.1:8080 &
echo "OK"

sleep 1
