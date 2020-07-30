#!/bin/bash

# Check to see if we have node count
if ! [[ -z "$NUMNODES" ]]
then
  echo "Found x86 node count"
else
  NUMNODES=2
fi

echo "Number of x86 nodes: $NUMNODES"
NUMNODES="$(($NUMNODES-1))"

# Check for kvm support
KVMFLAGS='-smp 2 -m 1024 -no-reboot -nographic -kernel /app/linux/arch/x86/boot/bzImage'
if [ $(ls /dev | grep kvm | wc -l) -eq 1 ]; then
    echo "KVM found!"
    KVMFLAGS="$KVMFLAGS -enable-kvm -cpu host"
    echo "KVM flags: $KVMFLAGS"
fi

# Run build tests
echo "Compiling the kernel"
cd linux
make CCACHE_DIR=/app/ccache CC="ccache gcc" -j$(nproc) &> /app/logs/kernel_compiliation
EXITCODE=$?
test $EXITCODE -eq 0 && echo "Kernel compiliation successful!" || exit -1;

# Build msg_layer drivers
echo "Building drivers/msg_layer drivers"
cd drivers/msg_layer && make CCACHE_DIR=/app/ccache CC="ccache gcc" -j$(nproc) &> /app/logs/msg_compiliation
EXITCODE=$?
test $EXITCODE -eq 0 && echo "msg_layer compiliation successful!" || exit -2;

# Creating disks
cd /app/disks
for ((i=0; i <= $NUMNODES; i++)); do
  qemu-img create -f qcow2 -o backing_file=base.img ${i}.img > /dev/null
done

# Create nodes list
echo "" > /app/nodes
for ((i=0; i <= $NUMNODES; i++)); do
  echo "10.4.4.$(($i+100))" >> /app/nodes
done

sudo mkdir -p /etc/ansible
sudo cp /app/nodes /etc/ansible/hosts

# Start Virtual Machines & Networking
echo "Starting virtual machines"
sudo brctl addbr br0
sudo ifconfig br0 10.4.4.1 netmask 255.255.255.0

cd /app
for ((i=0; i <= $NUMNODES; i++)); do
  echo 'sudo qemu-system-x86_64 '${KVMFLAGS}' -gdb tcp::123'${i}' -drive id=root,media=disk,file=/app/disks/'${i}'.img -net nic,macaddr=00:da:bc:de:00:1'$((3+${i}))' -net tap,ifname=tap'${i}' -append "root=/dev/sda1 console=ttyS0 ip=10.4.4.'$((100+${i}))'" 2>&1 | tee /app/logs/vm'${i} > launchVM${i}.sh
  chmod +x launchVM${i}.sh && screen -S ${i} -d -m ./launchVM${i}.sh
done

sleep 2

for ((i=0; i <= $NUMNODES; i++)); do
  sudo brctl addif br0 tap${i}
  EXITCODE=$?
  test $EXITCODE -eq 0 && echo "Node "${i}" started!" || exit 10;
done

# Build popcorn-lib - note that make is currently single threaded (race condition)
echo "Building popcorn-lib"
cd /app/popcorn-lib
make CCACHE_DIR=/app/ccache CC='ccache gcc' -j1 &> /app/logs/lib_compiliation
EXITCODE=$?
test $EXITCODE -eq 0 && echo "Popcorn-lib compiliation successful!" || exit -3;

# Wait for both Virtual Machines to start
for ((i=0; i <= $NUMNODES; i++)); do
  while ! (exec 3<>/dev/tcp/10.4.4.$((100+${i}))/22) &> /dev/null
  do
    echo "Waiting for node "${i}" to come online" && sleep 2
  done
done

sleep 2

# Insert modules and run popcorn tests
for ((i=0; i <= $NUMNODES; i++)); do
  sshpass -p "popcorn" scp -o StrictHostKeyChecking=no /app/linux/drivers/msg_layer/msg_socket.ko popcorn@10.4.4.$((100+${i})):/home/popcorn
  sshpass -p "popcorn" scp -o StrictHostKeyChecking=no -r /app/popcorn-lib popcorn@10.4.4.$((100+${i})):/home/popcorn
  sshpass -p "popcorn" scp -o StrictHostKeyChecking=no -r /app/nodes popcorn@10.4.4.$((100+${i})):/etc/popcorn/nodes
  sshpass -p "popcorn" ssh -o StrictHostKeyChecking=no  popcorn@10.4.4.$((100+${i})) "sudo insmod msg_socket.ko" &
done

echo -e "Running tests\n=============="
cd /app
ansible-playbook -e "ansible_ssh_pass=popcorn" popcorn_tests.yml

# Wait at the end for interactive testing
if ! [[ -z "$INTERACTIVE" ]]
then
  echo "Interactive variable set, pausing"
  echo "Check docs on how to interact with the container"
  tail -f /dev/null
else
  echo "Ending tests, set INTERACTIVE to debug/interact with containers"
fi
