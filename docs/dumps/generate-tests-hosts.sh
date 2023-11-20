#!/bin/sh -e
set -x

docker run -ti --rn \
    -h fbcli-test-$$ --name fbcli-test-$$ \
   --network none -l bridge_member=br-lan -l bridge_ips=dhcp \
  debian:bookworm \
    eep 3
