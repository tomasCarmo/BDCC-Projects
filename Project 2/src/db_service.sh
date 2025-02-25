#!/bin/bash

init_database_service() {
    TEMPLATE_NAME="database-cluster-vm-template"
    VM_NAME="database-service-vm"
    SSH_KEY_PATH="$HOME/.ssh/id_rsa"
    SSH_PUBLIC_KEY_PATH="$SSH_KEY_PATH.pub"
    NETWORK_UNAME="Public"
    UBUNTU_IMAGE_NAME="Ubuntu"

    # Check if SSH key pair exists, generate if it doesn't
    if [[ ! -f "$SSH_KEY_PATH" || ! -f "$SSH_PUBLIC_KEY_PATH" ]]; then
        echo "SSH key pair not found. Generating new SSH key pair..."
        ssh-keygen -t rsa -b 2048 -f "$SSH_KEY_PATH" -N ""
    fi

    SSH_PUBLIC_KEY=$(cat "$SSH_PUBLIC_KEY_PATH")

    # Check for Ubuntu image
    UBUNTU_IMAGE_ID=$(oneimage list --no-header | grep "$UBUNTU_IMAGE_NAME")

    if [ -z "$UBUNTU_IMAGE_ID" ]; then
        echo "Service VM image not found..."
    fi

    # Check for default network
    NETWORK_ID=$(oneimage list --no-header | grep "$NETWORK_UNAME")
    if [ -z "$NETWORK_ID" ]; then
        echo "No network found..."
    fi

    # Create VM if necessary
    output=$(sudo onevm list --no-header | grep "$VM_NAME")
    if [ -z "$output" ]; then
        echo "No VMs found. Creating database cluster VM template..."

        sudo onetemplate create <<EOF
            NAME = "$TEMPLATE_NAME"
            CPU = "1"
            MEMORY = "1024"
            DISK = [
                IMAGE_ID = "$UBUNTU_IMAGE_ID",
                IMAGE_UNAME = "$USER"
            ]
            NIC = [
                NETWORK_ID = "$NETWORK_ID",
                NETWORK_UNAME = "$NETWORK_UNAME"
            ]
            CONTEXT = [
                NETWORK = "YES",
                SSH_PUBLIC_KEY = "$SSH_PUBLIC_KEY",
                START_SCRIPT = "IyEvYmluL2Jhc2gKCiMgVXBkYXRlIHBhY2thZ2UgbGlzdAplY2hvICJVcGRhdGluZyBwYWNrYWdlIGxpc3QuLi4iCnN1ZG8gYXB0LWdldCB1cGRhdGUKCiMgSW5zdGFsbCBNeVNRTCBzZXJ2ZXIKZWNobyAiSW5zdGFsbGluZyBNeVNRTCBzZXJ2ZXIuLi4iCnN1ZG8gYXB0LWdldCBpbnN0YWxsIC15IG15c3FsLXNlcnZlcgoKc3VkbyBzeXN0ZW1jdGwgZW5hYmxlIG15c3FsCnN1ZG8gc3lzdGVtY3RsIHN0YXJ0IG15c3FsCgplY2hvICJNeVNRTCBpbnN0YWxsYXRpb24gc2NyaXB0IGZpbmlzaGVkLiIK"
            ]
EOF
        echo "VM template created: $TEMPLATE_NAME"
    else
        echo "VM template already exists."
    fi

    # Instantiate the VM template
    sudo onetemplate instantiate "$TEMPLATE_NAME" --name "$VM_NAME"

    # Connect to the VM
    # ...   
}

register_user(){
  # Register usee
  echo "Register user first"
  read -p "Enter username:" DB_USER
  read -p "Enter password:" DB_PASS

  export DB_USER DB_PASS
}

dbs_menu() {
    # Menu loop
    PS3='Please enter your choice: '
    options=("Create Database" "List Databases" "Create Table" "Insert Data" "Query Data" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Create Database")
                read -p "Enter database name: " dbname
                mysql -u $DB_USER -p$DB_PASS -e "CREATE DATABASE $dbname;"
                echo "Database '$dbname' created."
                ;;
            "List Databases")
                mysql -u $DB_USER -p$DB_PASS -e "SHOW DATABASES;"
                return
                ;;
            "Create Table")
                read -p "Enter database name: " dbname
                read -p "Enter table name: " tablename
                mysql -u $DB_USER -p$DB_PASS -e "CREATE TABLE $dbname.$tablename (id INT PRIMARY KEY, name VARCHAR(50));"
                echo "Table '$tablename' created in database '$dbname'."
                return
                ;;
            "Insert Data")
                read -p "Enter table name: " tablename
                read -p "Enter ID: " id
                read -p "Enter Name: " name
                mysql -u $DB_USER -p$DB_PASS -e "INSERT INTO $DB_NAME.$tablename (id, name) VALUES ($id, '$name');"
                echo "Data inserted into table '$tablename'."
                return
                ;;
            "Query Data")
                read -p "Enter database name: " dbname
                read -p "Enter table name: " tablename
                mysql -u $DB_USER -p$DB_PASS -e "SELECT * FROM $dbname.$tablename;"
                return
                ;;
            "Quit")
                exit 0
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Main 
# Check for database service VM, create if not exist
output=$(sudo onevm list --no-header | grep "database-service-vm")
if [ -z "$output" ]; then
    init_database_service
    register_user
else
    dbs_menu
fi