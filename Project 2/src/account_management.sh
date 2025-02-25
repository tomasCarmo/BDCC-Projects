#!/bin/bash

# Function to update user password
update_password() {
    read -p "Enter your old password: " old_password
    read -sp "Enter your new password: " new_password
    echo
    # Command to update password in OpenNebula
    sudo oneuser passwd $USER_ID $new_password  # Assuming USER_ID is exported from the main script
    echo "Password updated successfully."
}

# Function to delete user account
delete_account() {
    read -p "Are you sure you want to delete your account? (yes/no): " confirm
    if [[ $confirm == "yes" ]]; then
        sudo oneuser delete $USER_ID
        echo "Account deleted successfully."
        exit 0
    fi
}

# Account Management Menu
account_management_menu() {
    PS3='Select an option: '
    options=("Update Password" "Delete My Account" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Update Password")
                update_password
                ;;
            "Delete My Account")
                delete_account
                ;;
            "Quit")
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Run the account management menu
account_management_menu
