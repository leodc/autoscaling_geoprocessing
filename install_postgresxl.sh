#!/bin/bash

# update system
sudo apt-get update -y

# isntall dependencies
sudo apt-get install -y bison flex jade libreadline-dev zlib1g-dev make libperl-dev

# get source code
wget https://www.postgres-xl.org/downloads/postgres-xl-9.5r1.6.tar.bz2
tar xvjf postgres-xl-9.5r1.6.tar.bz2

# build postgresxl
cd postgres-xl-9.5r1.6
./configure

make

sudo make install

# install all
# make world
# sudo make install-world

# add postgresxl to path
# echo export PATH=/usr/local/pgsql/bin:$PATH >> ~/.bashrc

# cd contrib
# make
# make install
# ln -sf /usr/local/pgsql/bin/* /usr/bin/
