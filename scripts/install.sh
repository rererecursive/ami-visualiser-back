#!/bin/bash
set -e
echo "Installing Packages..."
sudo apt-get update && sudo apt-get install -f -y ansible ohai
echo "Installed."
