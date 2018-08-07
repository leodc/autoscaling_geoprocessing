#!/bin/bash

# set ssh key permissions
chmod 400 /home/ubuntu/.ssh/id_ecdsa

# input variables
echo "gtmSlaveServer=$gtmSlaveServer" >> /etc/environment
echo "gtmProxyServers=$gtmProxyServers" >> /etc/environment
echo "gtmMasterServer=$gtmMasterServer" >> /etc/environment
echo "coordMasterServers_ips=$coordMasterServers_ips" >> /etc/environment
echo "datanodeMasterServers_ips=$datanodeMasterServers_ips" >> /etc/environment

# add cluster machines to known_hosts
ssh-keyscan -H -T 20 $gtmMasterServer >> ~/.ssh/known_hosts
ssh-keyscan -H -T 20 $gtmProxyServers >> ~/.ssh/known_hosts
ssh-keyscan -H -T 20 $gtmSlaveServer >> ~/.ssh/known_hosts
ssh-keyscan -H -T 20 $coordMasterServers_ips >> ~/.ssh/known_hosts
ssh-keyscan -H -T 20 $datanodeMasterServers_ips >> ~/.ssh/known_hosts

# prepare configuration file
mkdir $HOME/pgxc_ctl
mv /home/ubuntu/pgxc_ctl.conf $HOME/pgxc_ctl

# setup GTM master
cd $XLSRC/contrib/pgxc_ctl
make
sudo make install

# init cluster
pgxc_ctl init all

# validate cluster
pgxc_ctl monitor all
