#!/bin/bash

# This script configures Podman to allow insecure (HTTP) connections 
# to the local Docker registry on Hierophant.

set -e

REGISTRY_DIR="/etc/containers/registries.conf.d"

# Ensure the configuration directory exists
if [ ! -d "$REGISTRY_DIR" ]; then
    echo "Creating directory $REGISTRY_DIR"
    sudo mkdir -p "$REGISTRY_DIR"
fi

create_insecure_registry_config() {
    local registry_addr=$1
    local config_file="${REGISTRY_DIR}/${registry_addr%%:*}.conf"

    echo "Configuring insecure registry for $registry_addr in $config_file"
    
    printf "[[registry]]\nlocation = \"%s\"\ninsecure = true\n" "$registry_addr" | sudo tee "$config_file" > /dev/null
}

# Configure known registry addresses
create_insecure_registry_config "192.168.200.19:443"
create_insecure_registry_config "192.168.200.18:5000"

echo "Podman configuration updated successfully."
echo "You can now try to login using:"
echo "podman login 192.168.200.19:443 --username admin --password 1qaz@WSX3edc"
