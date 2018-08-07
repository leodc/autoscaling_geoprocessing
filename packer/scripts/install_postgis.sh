#!/bin/bash

# update system
# sudo apt-get update -y

# dependencies
sudo apt-get install -y gcc make libxml2-dev libgeos-dev proj-bin libproj-dev libgdal-dev

# get source code
wget https://download.osgeo.org/postgis/source/postgis-2.3.1.tar.gz

# extract
tar xvzf postgis-2.3.1.tar.gz

# build
cd postgis-2.3.1/
./configure

# install
make
sudo make install

# clean
cd ..
rm -rf postgis-2.3.1 postgis-2.3.1.tar.gz
