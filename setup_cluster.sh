#!/bin/bash

# add cluster machines to known_hosts
ssh-keyscan -H 172.31.45.190 >> ~/.ssh/known_hosts
ssh-keyscan -H 172.31.45.191 >> ~/.ssh/known_hosts
ssh-keyscan -H 172.31.45.192 >> ~/.ssh/known_hosts
ssh-keyscan -H 172.31.45.193 >> ~/.ssh/known_hosts

# setup GTM master
cd $XLSRC/contrib/pgxc_ctl
make
sudo make install

# prepare configuration file
mkdir $HOME/pgxc_ctl
mv /home/ubuntu/pgxc_ctl.conf $HOME/pgxc_ctl

# init cluster
pgxc_ctl init all

