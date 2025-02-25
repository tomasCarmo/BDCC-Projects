#!/bin/bash

init_container_service() {
    TEMPLATE_NAME="container-cluster-vm-template"
    VM_NAME="container-service-vm"
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
    output=$(onevm list --no-header | grep "$VM__NAME")
    if [ -z "$output" ]; then
        # Debug msg 
        echo "No VMs found. Creating container cluster VM template..."

        onetemplate create <<EOF
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
                START_SCRIPT="IyEvYmluL2Jhc2gKCiMgVXBkYXRlIHBhY2thZ2UgbGlzdCBhbmQgaW5zdGFsbCBwcmVyZXF1aXNpdGUgcGFja2FnZXMKc3VkbyBhcHQtZ2V0IHVwZGF0ZSAteQpzdWRvIGFwdC1nZXQgaW5zdGFsbCAteSBhcHQtdHJhbnNwb3J0LWh0dHBzIGNhLWNlcnRpZmljYXRlcyBjdXJsIHNvZnR3YXJlLXByb3BlcnRpZXMtY29tbW9uCgojIEFkZCBEb2NrZXIncyBvZmZpY2lhbCBHUEcga2V5CmN1cmwgLWZzU0wgaHR0cHM6Ly9kb3dubG9hZC5kb2NrZXIuY29tL2xpbnV4L3VidW50dS9ncGcgfCBzdWRvIGdwZyAtLWRlYXJtb3IgLW8gL3Vzci9zaGFyZS9rZXlyaW5ncy9kb2NrZXItYXJjaGl2ZS1rZXlyaW5nLmdwZwoKIyBBZGQgRG9ja2VyJ3Mgb2ZmaWNpYWwgQVBUIHJlcG9zaXRvcnkKZWNobyBcCiAgImRlYiBbYXJjaD1hbWQ2NCBzaWduZWQtYnk9L3Vzci9zaGFyZS9rZXlyaW5ncy9kb2NrZXItYXJjaGl2ZS1rZXlyaW5nLmdwZ10gaHR0cHM6Ly9kb3dubG9hZC5kb2NrZXIuY29tL2xpbnV4L3VidW50dSBcCiAgJChsc2JfcmVsZWFzZSAtY3MpIHN0YWJsZSIgfCBzdWRvIHRlZSAvZXRjL2FwdC9zb3VyY2VzLmxpc3QuZC9kb2NrZXIubGlzdCA+IC9kZXYvbnVsbAoKIyBVcGRhdGUgcGFja2FnZSBsaXN0IHRvIGluY2x1ZGUgRG9ja2VyIHBhY2thZ2VzIGZyb20gdGhlIG5ld2x5IGFkZGVkIHJlcG8Kc3VkbyBhcHQtZ2V0IHVwZGF0ZQoKIyBJbnN0YWxsIERvY2tlcgpzdWRvIGFwdC1nZXQgaW5zdGFsbCAteSBkb2NrZXItY2UKCiMgU3RhcnQgRG9ja2VyIHNlcnZpY2UKc3VkbyBzeXN0ZW1jdGwgc3RhcnQgZG9ja2VyCgojIEVuYWJsZSBEb2NrZXIgc2VydmljZSB0byBzdGFydCBvbiBib290CnN1ZG8gc3lzdGVtY3RsIGVuYWJsZSBkb2NrZXIKt"
            ] 
EOF
        echo "VM template created: $TEMPLATE_NAME"
    else
        echo "VM template already exists."
    fi

    # Instantiate the VM template
    onetemplate instantiate "$TEMPLATE_NAME" --name "$VM_NAME"

}

deploy_container(){
    PS3='Select an option: '
    options=("Run Dockerhub Image" "Deploy App" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Run Dockerhub Image")
                read -p "Enter the Dockerhub image name (e.g., nginx): " image_name
                read -p "Enter the Docker image local name (e.g., mynginx): " local_name
                read -p "Enter the port mapping (e.g., 8080:80): " port_mapping
                
                docker run -d --name "$local_name" -p "$port_mapping" "$image_name"

                # Check if the container started successfully
                if [ $? -eq 0 ]; then
                    echo "Docker container is running."
                    echo "Image: $local_name"
                    echo "Port Mapping: $port_mapping"
                else
                    echo "Failed to start Docker container."
                fi
                ;;
            "Deploy App")
                echo "Building Docker image from Dockerfile..."
                read -p "Enter the Dockerfile path (e.g. /my/path/to/project ): " docker_path
                read -p "Enter the Dockerhub image name (e.g., nginx): " image_name
                read -p "Enter the Docker image local name (e.g., mynginx): " local_name
                read -p "Enter the port mapping (e.g., 8080:80): " port_mapping

                if [ ! -f "$docker_path/Dockerfile" ]; then
                    echo "Docker path is invalid."
                    break
                fi

                docker build -t "$image_name" "$docker_path"

                # Check if the image build was successful
                if [ $? -ne 0 ]; then
                    echo "Failed to build Docker image."
                    exit 1
                fi

                docker run -d --name "$local_name" -p "$port_mapping" "$image_name"

                # Check if the container started successfully
                if [ $? -eq 0 ]; then
                    echo "Docker container is running."
                    echo "Image: $local_name"
                    echo "Port Mapping: $port_mapping"
                else
                    echo "Failed to start Docker container."
                fi

                ;;
            "Quit")
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

manage_container(){
    echo "YOUR DOCKER CONTAINERS:"
    echo "-----------------------"
    output=$(docker ps -a)
    echo $output
    echo "-----------------------"

    echo 'Select container: '
    while true; do
        read $container_id
        output=$(docker ps -a --format "{{.ID}}" | grep -q "^${container_id}$")
        if [ ! -z "$output" ]; then
            container_menu "$container_id"
            break 
        else
            echo "Invalid ID, try again."
        fi
    done
}

container_menu(){
    PS3='Select an option: '
    options=("Start" "Stop" "Restart" "Access Shell" "Inspect" "Delete" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Start")
                docker start $1
                ;;
            "Stop")
                docker stop $1
                ;;
            "Restart")
                docker restart $1
                ;;
            "Access Shell")
                docker exec -it $1 /bin/bash
                ;;
            "Inspect")
                docker inspect $1
                ;;
            "Delete")
                docker rm $1
                ;;
            "Quit")
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

cs_menu() {
    PS3='Select an option: '
    options=("Deploy Container" "Manage Container" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Deploy Container")
                deploy_container
                ;;
            "Manage Container")
                manage_container
                ;;
            "Quit")
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Main 
# Check for container service VM, create if not exist
output=$(onevm list --no-header | grep "container-service-vm")
if [ -z "output" ]; then
    init_container_service
else
    cs_menu
fi
