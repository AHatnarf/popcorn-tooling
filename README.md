# popcorn-tooling
Files and scripts for working with the popcorn kernel (http://popcornlinux.org/)


The docker-compose file is what I'm using to create the container that run tests.
It runs the compile.sh script that's included here (make sure the bind mounts are correct in the docker-compose file).

The init.d folder containers a service that sets each nodes' IP on boot. Once it's put in `/etc/init.d` it should be abel to be enabled on a vm with `sudo update-rc.d pop-ip enable`.

Once the init.d service is enabled the vm image can be copied from 0.img to however many nodes you want to work with.
