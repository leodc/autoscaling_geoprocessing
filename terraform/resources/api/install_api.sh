#!/bin/bash

echo "Setting up node repository"
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -

echo "Installing node"
sudo apt-get install -y nodejs

echo "Installing npm:forever"
sudo npm install forever -g

echo -n "Installing geofox API.."
mkdir api
mv *.js* api
cd api
npm install
echo "OK"

echo "Starting geofox API"
PGHOST=$PGHOST PGPORT=80 PGDATABASE=test_db forever start api.js

echo "Done"
