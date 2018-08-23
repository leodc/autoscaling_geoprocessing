#!/bin/bash

sudo rm -rf /var/lib/dpkg/lock

echo "Installing grafana repo"
echo 'deb https://packagecloud.io/grafana/stable/debian/ jessie main' > /tmp/grafana.list
sudo mv /tmp/grafana.list /etc/apt/sources.list.d/grafana.list
curl https://packagecloud.io/gpg.key >> grafana_key
sudo apt-key add grafana_key

echo "Updating repos tables"
sudo apt-get update -y
# sudo apt-get upgrade -y

echo "Installing grafana"
sudo apt-get install -y grafana

echo "Starting grafana"
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

echo "Adding prometheus source... $PROMETHEUS_SOURCE"
sleep 3
curl -u admin:admin 'http://127.0.0.1:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"prometheus_source","type":"prometheus","url":"http://'"$PROMETHEUS_SOURCE"':9090","access":"proxy","isDefault":true,"user":"admin","password":"admin"}'
