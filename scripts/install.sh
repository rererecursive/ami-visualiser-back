#!/bin/bash
set -e
echo "Installing Packages..."
sleep 20
sudo apt-get update && sudo apt-get install -f -y ansible ohai docker.io
echo "Installed."
