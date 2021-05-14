#!/bin/bash

while [[ "$(mount | grep /app/share | wc -c)" -le 8 ]]
do
  sudo mount -t nfs -o proto=tcp,port=2049 10.4.4.1:/app/share /home/popcorn/test
  sleep 1
done
