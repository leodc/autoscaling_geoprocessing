#!/bin/bash

echo "Starting init_postgres_xl_master..."

# set ssh key permissions
# chmod 400 /home/ubuntu/.ssh/id_ecdsa

HOME="/home/ubuntu"

echo "Creating basic configuration..."
# prepare configuration file
mkdir $HOME/pgxc_ctl
mv /home/ubuntu/pgxc_ctl.conf $HOME/pgxc_ctl/pgxc_ctl.conf
chown ubuntu $HOME/pgxc_ctl

echo "Setting up master..."
cd $HOME/postgres-xl-9.5r1.6/contrib/pgxc_ctl
make
sudo make install
