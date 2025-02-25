#!/bin/bash

# Update package list
echo "Updating package list..."
sudo apt-get update

# Install MySQL server
echo "Installing MySQL server..."
sudo apt-get install -y mysql-server

sudo systemctl enable mysql
sudo systemctl start mysql

echo "MySQL installation script finished."
