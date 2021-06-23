# popcorn-tooling
Files and scripts for working with the popcorn kernel (http://popcornlinux.org/)

It is intended for development, but could be expanded to showcase release features, automate testing, etc.

## Usage 
This tooling requires docker-compose, docker, and the tun mdoule to be loaded in the kernel.
The tun driver can be checked with the following: `lsmod | grep tun`. `apt install docker-compose` will install docker-compose and docker.

The docker-compose file is what I'm using to create the container that run tests.
It runs the compile.sh script that's included here (make sure the bind mounts are correct in the docker-compose file).

Bind mounts for the popcorn kernel, popcorn lib, vm disks, compiler caches, the compile script, and VM logs are included in the example docker-compose.yml.
By default the docker-compose.yml will pass through /dev/kvm for accelerated x86 VMs. If this isn't desired that line can be removed from the docker-compose.yml. It is recommended to download the disk images from the github releases, and to expand them for your purposes.

Once all of these are set up everything can be run with `docker-compose up`.

Node counts are set via the enviromental variables `NUMx86` and `NUMARM`.

## Interacting with the VMs/Debugging
Sometimes being able to interact with the VMs is desired. Future iterations will include publishing qemu gdb servers. At the end of the compile.sh script that is included the VMs will stay alive once tests run.
Running docker images can be checked with `docker ps`. Once you have the name of the running container you can use `docker exec -it $CONTAINERNAME /bin/bash` (replace $CONTAINERNAME with the name) to interact with the container. From then you can use `screen -x $VMNUMBER` to get an interact with the chosen VM. For example `screen -x 0` will bring up the shell for node 0.

GDB is made available in the two_nodes branch as an example. It spawns a screen for gdb to interact with the x86 node. Note that there is a bit of shuffling around vmlinuz files for x86 and arm when using gdb.

Additionally all console logs & stdout from the boot terminal will be stored in the logs folder. Other stages such as kernel, driver, and library compiliation will be stored in that folder.


## Modifying automated tests/functionality
Within the helpers folder there are two Ansible playbook files, nfs_deploy.yml and popcorn_tests.yml. With both groups of x86 nodes, arm nodes, a single node, or all nodes can be targeted for commands/other functionality. The nfs_deploy.yml is intended to mount an nfs server from the container to the VMs (reducing overhead from SCPing files live). It also will attempt to mount the msg_socket kernel module. The popcorn_tests.yml can be exapnded to start tests from specific nodes and get otuput reported back. 
