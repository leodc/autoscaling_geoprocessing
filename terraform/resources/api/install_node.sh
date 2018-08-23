#!/bin/bash

echo "Setting up node repository"
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -

echo "Installing nodejs"
sudo apt-get install -y nodejs

echo "Installing npm:forever"
sudo npm install forever -g
