#!/bin/bash

# Create Default Network for service VMs
create_network() {
    NET_NAME="Public"
    BRIDGE="virbr0"
    VN_MAD="dummy"
    IPV4_IPSTART="192.168.122.100"
    # Create network on virbr0 interface
    onevnet create <<EOF
NAME = "$NET_NAME"
BRIDGE = "$BRIDGE"
VN_MAD = "$VNMAD"
AR = [
  TYPE = IP4,
  IP = "$IPV4_IPSTART",
  SIZE = 100
]
EOF
}

# Create Default Image for service VMs
create_image() {
    # Download image if necessary
    apt-get update
    apt-get -y wget
    wget -O "/var/tmp/ubuntu-20.04.iso" "https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso" 
    sleep 10

    UBUNTU_IMAGE_NAME="Ubuntu"
    UBUNTU_IMAGE_PATH="/var/tmp/ubuntu-20.04.iso"

    oneimage create --name "$UBUNTU_IMAGE_NAME" --path "$UBUNTU_IMAGE_PATH" # --driver qcow2 --disk
    sleep 5
}

# Create Default Host for service VMs
create_host() {
    output=$(lsmod | grep kvm)
    # If there are no KVM instances download KVM packages
    if [-z "$output"]; then
        apt-get update
        apt-get -y bridge-utils qemu-kvm virtinst libvirt-daemon virt-manager
        apt-get -y install opennebula-node-kvm
        systemctl restart libvirtd
    fi
}

# If list is empty then run funcs
output=$(oneimage list --no-header)
if [-z "$output"]; then
    create_image
fi
output=$(onevnet list --no-header)
if [-z "$output"]; then
    create_network
fi