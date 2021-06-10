#!/bin/bash

# Check to see if we have node count
if ! [[ -z "$NUMx86" ]]
then
  echo "Found x86 node count"
else
  NUMx86=1
fi

if ! [[ -z "$NUMARM" ]]
then
  echo "Found arm node count"
else
  NUMARM=1
fi

echo "Number of x86 nodes: $NUMx86"
echo "Number of arm nodes: $NUMARM"
NUMNODES="$(($NUMx86-1))"
NUMTOTAL="$((NUMx86+NUMARM))"
echo "Total nodes: $NUMTOTAL"

# Check for kvm support - removing -kernel /app/linux/arch/x86/boot/bzImage
KVMFLAGS='-smp 2 -m 1024 -no-reboot -nographic'
X86KVMFLAGS="$KVMFLAGS"
if [ $(ls /dev | grep kvm | wc -l) -eq 1 ]; then
    echo "KVM found!"
    X86KVMFLAGS="$KVMFLAGS -enable-kvm -cpu host"
    echo "KVM flags: $KVMFLAGS"
fi

# Run build tests
echo "Compiling the kernel"
cd linux
cp /app/configs/x86.config .config
make CCACHE_DIR=/app/ccache CC="ccache gcc" -j$(nproc) &> /app/logs/kernel_compiliation
EXITCODE=$?
test $EXITCODE -eq 0 && echo "x86 compiliation successful!" || exit -2;
mv /app/linux/msg_layer/msg_socket.ko /app/share/msg_socketx86.ko
cp vmlinux x86.vmlinux
ln -s /app/linux/scripts/gdb/vmlinux-gdb.py /app/linux/vmlinux-gdb.py > /dev/null 2>&1

# Arm compiliaition
cd /app/linux
cp /app/configs/arm.config .config
ARCH="arm64" CROSS_COMPILE="aarch64-linux-gnu-" make CCACHE_DIR=/app/ccache CC="ccache aarch64-linux-gnu-gcc" -C . -j $(nproc) &> /app/logs/arm_kernel_compiliation
EXITCODE=$?
#test test $EXITCODE -eq 0 && echo "Arm compiliation successful!" || exit -1;
mv /app/linux/msg_layer/msg_socket.ko /app/share/msg_socketarm.ko
cp vmlinux arm.vmlinux

# Creating disks
cd /app/disks
for ((i=0; i<$NUMx86; i++)); do
  qemu-img create -f qcow2 -o backing_file=base_x86.img ${i}.img > /dev/null
done

for ((i=$NUMx86; i<$NUMTOTAL; i++)); do
  qemu-img create -f qcow2 -o backing_file=base_arm.img ${i}.img > /dev/null
done


# Create nodes list
touch /app/nodes
for ((i=0; i <= $((NUMNODES+NUMARM)); i++)); do
  echo "10.4.4.$(($i+100))" >> /app/nodes
done

sudo mkdir -p /etc/ansible
echo "[x86]" > ansible_hosts
for ((i=0; i<$NUMx86; i++)); do
  echo "10.4.4.$(($i+100))" >> ansible_hosts
done

echo "" >> ansible_hosts
echo "[arm]" >> ansible_hosts

for ((i=$NUMx86; i<$NUMTOTAL; i++)); do
  echo "10.4.4.$(($i+100))" >> ansible_hosts
done
sudo mv ansible_hosts /etc/ansible/hosts

# Start Virtual Machines & Networking
echo "Starting virtual machines"
sudo brctl addbr br0
sudo ifconfig br0 10.4.4.1 netmask 255.255.255.0
rm /home/popcorn-dev/.ssh/known_hosts > /dev/null 2>&1

cd /app
for ((i=0; i<$NUMx86; i++)); do
  echo 'sudo qemu-system-x86_64 '${X86KVMFLAGS}' -kernel /app/linux/arch/x86_64/boot/bzImage -gdb tcp::123'${i}' -drive id=root,if=none,media=disk,file=disk,file=/app/disks/'${i}'.img -device virtio-blk-pci,drive=root -net nic,model=virtio,macaddr=00:da:bc:de:00:1'$((3+${i}))' -net tap,ifname=tap'${i}' -append "root=/dev/vda1 console=ttyS0 ip=10.4.4.'$((100+${i}))' nokaslr" 2>&1 | tee /app/logs/vm'${i} > launchVM${i}.sh
  chmod +x launchVM${i}.sh && screen -S ${i} -d -m ./launchVM${i}.sh
  echo "Starting X86: $i"
done

cd /app
for ((i=$NUMx86; i<$NUMTOTAL; i++)); do
  #echo 'sudo qemu-system-aarch64 '${KVMFLAGS}'  -machine virt -cpu cortex-a57 -kernel /app/linux/arch/arm64/boot/Image -gdb tcp::123'${i}' -drive id=root,if=none,media=disk,file=/app/disks/base_arm.img -device virtio-blk-device,drive=root -netdev type=tap,id=tap'${i}'  -device virtio-net-device,netdev=tap'${i}',mac=00:da:bc:de:00:1'$((3+${i}))' -append "root=/dev/vda console=ttyAMA0 ip=10.4.4.'$((100+${i}))'" 2>&1 | tee /app/logs/vm'${i} > launchVM${i}.sh 
  echo 'sudo qemu-system-aarch64 '${KVMFLAGS}'  -machine virt -cpu cortex-a57 -kernel /app/linux/arch/arm64/boot/Image -gdb tcp::123'${i}' -drive id=root,if=none,media=disk,file=/app/disks/'${i}'.img -device virtio-blk-device,drive=root -netdev type=tap,id=tap'${i}'  -device virtio-net-device,netdev=tap'${i}',mac=00:da:bc:de:00:1'$((3+${i}))' -append "root=/dev/vda console=ttyAMA0 ip=10.4.4.'$((100+${i}))'" 2>&1 | tee /app/logs/vm'${i} > launchVM${i}.sh 
  chmod +x launchVM${i}.sh && screen -S ${i} -d -m ./launchVM${i}.sh
  echo "Starting ARM: $i"
done

sleep 2

for ((i=0; i < $NUMTOTAL; i++)); do
  sudo brctl addif br0 tap${i}
  sudo ifconfig tap${i} up
  EXITCODE=$?
  test $EXITCODE -eq 0 && echo "Node "${i}" started!" || exit 10;
done

# Build popcorn-lib - note that make is currently single threaded (race condition)
echo "Building popcorn-lib"
cd /app/popcorn-lib
#make clean -j$(nproc) &> /dev/null && 
make CCACHE_DIR=/app/ccache CC='ccache gcc' -j1 &> /app/logs/lib_compiliation
EXITCODE=$?
test $EXITCODE -eq 0 && echo "Popcorn-lib compiliation successful!" || exit -3;

# Wait for both Virtual Machines to start
for ((i=0; i<$NUMTOTAL; i++)); do
  while ! (exec 3<>/dev/tcp/10.4.4.$((100+${i}))/22) &> /dev/null
  do
    echo "Waiting for node "${i}" to come online" && sleep 2
  done
done

sleep 2

# Set up NFS server
sudo service rpcbind restart
sudo service nfs-kernel-server restart
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Trust fingerprint of each node & add in mount helper script for now
for ((i=0; i<$NUMTOTAL; i++)); do
  sshpass -p "popcorn" ssh -o StrictHostKeyChecking=no  popcorn@10.4.4.$((100+${i})) "mkdir /home/popcorn/test"
  sshpass -p "popcorn" scp /app/mount.sh popcorn@10.4.4.$((100+${i})):/home/popcorn/
done

# Set up GDB instances for two nodes - NOTE this isn't officially supported
cd /app/linux && echo 'add-auto-load-safe-path /app/linux/scripts/gdb/vmlinux-gdb.py' \
  | sudo tee -a /root/.gdbinit && \
  screen -d -m -S arm_gdb sudo gdb-multiarch vmlinux -ex "lx-symbols" -ex "target remote :1231" -ex "c"

sleep 7

cd /app/linux && sudo cp x86.vmlinux vmlinux && \
  screen -d -m -S x86_gdb sudo gdb-multiarch vmlinux -ex "lx-symbols" -ex "target remote :1230" -ex "c"

# Set up files in VMs
cd /app
mv /app/nodes /app/share/nodes
sleep 3
ansible-playbook -e "ansible_ssh_pass=popcorn" nfs_deploy.yml

# Run tests
echo -e "Running tests\n=============="
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
