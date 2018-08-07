#!/bin/bash

# update system
# sudo apt-get update -y

# dependencies
sudo apt-get install -y libboost-all-dev libcgal-dev cmake

# get source code
wget -O pgrouting-2.3.1.tar.gz https://github.com/pgRouting/pgrouting/archive/v2.3.1.tar.gz

# extract
tar xvfz pgrouting-2.3.1.tar.gz

# build
mkdir pgrouting-2.3.1/build
cd pgrouting-2.3.1/build
cmake ..

# install
make
sudo make install

# clean
cd ../../
rm -rf pgrouting-2.3.1 pgrouting-2.3.1.tar.gz

##################### pgrouting 2.6
# wget -O pgrouting-2.6.0.tar.gz https://github.com/pgRouting/pgrouting/archive/v2.6.0.tar.gz
#tar xvfz pgrouting-2.6.0.tar.gz
# mkdir pgrouting-2.6.0/build
# cd pgrouting-2.6.0/build
