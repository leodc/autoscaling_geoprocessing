#!/bin/bash

# update system
# sudo su -s /bin/bash -c 'sleep 30 && apt-get update' root

# isntall dependencies
sudo apt-get install -y bison flex jade libreadline-dev zlib1g-dev make libperl-dev postgresql-server-dev-9.5 unzip

# get source code
wget https://www.postgres-xl.org/downloads/postgres-xl-9.5r1.6.tar.bz2
tar xvjf postgres-xl-9.5r1.6.tar.bz2

# build postgresxl
cd postgres-xl-9.5r1.6
./configure -prefix=/usr/lib/postgresql/9.5

# install
make
sudo make install

# clean
cd ..
rm postgres-xl-9.5r1.6.tar.bz2
