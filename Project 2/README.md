## FCUP - Big Data and Cloud Computing 
### Project 2 - Cloud Infrastructure

### Setup

For a basic setup, after installing OpenNebula 6.83, execute the bootstrap_resource.sh script.
```bash
$ sudo chmod +x cloud_computing.sh
$ sudo ./bootstrap-scripts/bootstrap_resources.sh
```

### Running

To run the program execute the *cloud_management.sh* script.
```bash
$ sudo chmod +x cloud_computing.sh
$ ./cloud_computing.sh
```

The rest of the scripts will be called from the main *cloud_management.sh* script, each corresponding to their cloud service or infrastructure feature (Account, VMs, Database and Containers).
The startup scripts for the host VM of each Database and Container services, are on the folder *vm-startup-scripts*.