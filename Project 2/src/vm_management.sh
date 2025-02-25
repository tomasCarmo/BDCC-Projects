#!/bin/bash

# Function to create a new VM
create_vm() {
    read -p "Enter VM template ID: " template_id
    
    # Assuming user_id is available and VM quota is to check
    max_vms_allowed=2  # This value could be defined per user in a configuration file or fetched dynamically
    current_vms=$(onevm list --user $USER_ID | grep -c "^ [0-9] ")  # This counts VMs associated with $USER_ID

    if (( current_vms < max_vms_allowed )); then
        output=$(onetemplate instantiate $template_id --name "New VM")
        if [[ "$output" =~ "ID:" ]]; then
            echo "VM created successfully."
            echo "$output"
        else
            echo "Failed to create VM: $output"
        fi
    else
        echo "VM creation failed: User has reached the quota limit of $max_vms_allowed VMs."
    fi
}

# Function to delete a VM
delete_vm() {
    read -p "Enter VM ID to delete: " vm_id
    onevm terminate $vm_id
    echo "VM deleted successfully."
}

# Function to monitor a VM
monitor_vm() {
    read -p "Enter VM ID to monitor: " vm_id
    onevm show $vm_id
}

# Function to scale a VM
scale_vm() {
    read -p "Enter VM ID to scale: " vm_id
    read -p "Enter new CPU or Memory settings: " settings
    onevm resize $vm_id $settings
    echo "VM scaled successfully."
}

# Function to see all VMs (admin only)
see_all_vms() {
    onevm list
}

# Function to set global VM quotas (admin only)
set_global_vm_quota() {
    read -p "Enter maximum number of VMs each user can create: " max_vms
    read -p "Enter maximum CPU units each user can use: " max_cpu
    read -p "Enter maximum memory (in MB) each user can use: " max_mem

    # Assuming hypothetical command syntax for setting global quotas
    oneuser update default --vm-quota "VM=[CPU=\"$max_cpu\", MEMORY=\"$max_mem\", VMS=\"$max_vms\"]"
    echo "Global VM quotas set successfully for all users."
}

# VM Management Menu
vm_management_menu() {
    PS3='Select an option: '
    options=("Create VM" "Delete VM" "Monitor VM" "Scale VM" "See All VMs" "Set Global VM Quota" "Quit")
    
    select opt in "${options[@]}"
    do
        case $opt in
            "Create VM")
                create_vm
                ;;
            "Delete VM")
                delete_vm
                ;;
            "Monitor VM")
                monitor_vm
                ;;
            "Scale VM")
                scale_vm
                ;;
            "See All VMs")
                if [ $user_group_id -eq 100 ]; then  # Admin only
                    see_all_vms
                else
                    echo "Unauthorized access."
                fi
                ;;
            "Set Global VM Quota")
                if [ $user_group_id -eq 100 ]; then  # Admin only
                    set_global_vm_quota
                else
                    echo "Unauthorized access."
                fi
                ;;
            "Quit")
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Initial user group id and menu setup
user_group_id=100  # This should be set based on actual login logic that determines user role

# Run the VM management menu
vm_management_menu
