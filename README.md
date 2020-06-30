# popcorn-tooling
Files and scripts for working with the popcorn kernel (http://popcornlinux.org/)

## Usage
This tooling requires docker-compose, docker, and the tun mdoule to be loaded in the kernel.
The tun driver can be checked with the following: `lsmod | grep tun`. `apt install docker-compose` will install docker-compose and docker.

The docker-compose file is what I'm using to create the container that run tests.
It runs the compile.sh script that's included here (make sure the bind mounts are correct in the docker-compose file).

The init.d folder containers a service that sets each nodes' IP on boot. Once it's put in `/etc/init.d` it should be abel to be enabled on a vm with `sudo update-rc.d pop-ip enable`.

Once the init.d service is enabled the vm image can be copied from 0.img to however many nodes you want to work with.
Lines [38](https://github.com/ahughes12/popcorn-tooling/blob/master/compile.sh#L38) and [53](https://github.com/ahughes12/popcorn-tooling/blob/master/compile.sh#L53) control how many nodes are expected. By default it expects 4 nodes.

Bind mounts for the popcorn kernel, popcorn lib, vm disks, compiler caches, the compile script, and VM logs are included in the example docker-compose.yml.
By default the docker-compose.yml will pass through /dev/kvm for accelerated x86 VMs. If this isn't desired that line can be removed from the docker-compose.yml.

Once all of these are set up everything can be run with `docker-compose up`.


## Interacting with the VMs/Debugging
Sometimes being able to interact with the VMs is desired. Future iterations will include publishing qemu gdb servers. At the end of the compile.sh script that is included the VMs will stay alive once tests run.
Running docker images can be checked with `docker ps`. Once you have the name of the running container you can use `docker exec -it $CONTAINERNAME /bin/bash` (replace $CONTAINERNAME with the name) to interact with the container. From then you can use `screen -x $VMNUMBER` to get an interact with the chosen VM. For example `screen -x 0` will bring up the shell for node 0.

Additionally all console logs & stdout from the boot terminal will be stored in the logs folder. Other stages such as kernel, driver, and library compiliation will be stored in that folder.
