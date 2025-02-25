#!/bin/bash

# Function to log into the system with role checking
login() {
    read -p "Enter username: " username
    read -sp "Enter password: " password
    echo

    # Fetch user details to determine role, assuming that the .one/one_auth contains valid credentials
    user_info=$(sudo oneuser show $username)
    if [ $? -eq 0 ]; then
        user_id=$(echo "$user_info" | awk -F': ' '/^ID/{print $2}')

        export USER_ID=$user_id
        user_info=$(sudo oneuser show $username)
        group_name=$(echo "$user_info" | awk -F': ' '/^GROUP/{print $2}')
        echo "GROUP is: $group_name"

         group_name="${group_name// /}"  # Using Bash parameter expansion to remove all spaces
         if [[ "$group_name" == "Admin" ]]; then
            echo "Admin login successful!"
            user_group_id=100  # Admin user
        else
            echo "Login successful!"
            user_group_id=101  # Regular user
        fi
    else
        echo "Login failed!"
        user_group_id=2
    fi
    export user_group_id
}

# Function to register a user with username and password and handle admin role assignment
register_user() {
    read -p "Enter username: " username
    read -sp "Enter password: " password
    echo
    read -p "Is this an admin user? (yes/no): " is_admin

    # Attempt to create the user and directly capture the output
    output=$(sudo oneuser create $username $password)
    echo "Create user output: $output"  # For debugging

    # Extract user ID using awk based on the output format observed
    user_id=$(echo "$output" | awk -F'ID: ' '{print $2}' | awk '{print $1}')
    echo "Extracted ID: $user_id"  # Debug output

    if [[ "$user_id" ]]; then
        echo "User created successfully with ID: $user_id"
        
        # Determine group based on admin status
        if [ "$is_admin" = "yes" ]; then
            oneuser chgrp $user_id "Admin"  # Use group name for assignment
            echo "Admin privileges granted to $username."
        else
            oneuser chgrp $user_id "Regular User"  # Use group name for assignment
            echo "$username registered as a regular user."
        fi
    else
        echo "Failed to create user: $output"
    fi
}

#Initial menu for registration or login
initial_menu() {
    PS3='Please enter your choice: '
    options=("Register" "Login" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Register")
                register_user  # Call the registration function here
                ;;
            "Login")
                login
                return
                ;;
            "Quit")
                exit 0
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Menu after successful login
post_login_menu() {
    PS3='Please enter your choice: '
    options=("Account Management" "Virtual Machines (VMs)" "Disk Storage" "Logout")

    select opt in "${options[@]}"
    do
        case $opt in
            "Account Management")
                bash ./account_management.sh
                ;;
            "Virtual Machines (VMs)")
                bash ./vm_management.sh
                ;;
            "Disk Storage")
                # bash ./disk_storage.sh
                echo "To be implemented.."
                ;;
            "Database Service")
                bash ./db_service.sh
                ;;    
            "Container Service")
                bash ./container_service.sh
                ;;
            "Logout")
                echo "Logging out..."
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Main script execution

while true; do
    initial_menu
    if [[ $user_group_id -ne 2 ]]; then  # If login is successful
        post_login_menu
    fi
done
