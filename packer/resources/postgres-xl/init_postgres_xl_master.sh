#!/bin/bash

echo "Starting init_postgres_xl_master..."

# set ssh key permissions
chmod 400 /home/ubuntu/.ssh/id_ecdsa

echo "Creating basic configuration..."
# prepare configuration file
mkdir $HOME/pgxc_ctl
mv /home/ubuntu/pgxc_ctl.conf $HOME/pgxc_ctl/pgxc_ctl.conf

echo "Setting up master..."
cd $XLSRC/contrib/pgxc_ctl
make
sudo make install
