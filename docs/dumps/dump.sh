#!/bin/sh
set -eux

dev=br-lan
unset fb_mac
unset client_mac

[ -r dump.config ] && . ./dump.config

# no broadcasts
# no dns resolve
# no dump of traffic the fb does not speak by itself
# no https, otherwise hard to dump ;)

exec tcpdump -pnvvi br-lan \
      ether host $fb_mac \
  and ether host $client_mac \
  and not port 53 and not port 5353 \
  and not port 443 \
  and not port 445 and not port 137 and not port 138 and not port 139 \
  and not port 22 \
  and not port 179 and not proto 89 \
  and not proto 112 \
  and not port 1194 and not port 11940 and not port 11941 and not port 11942 and not port 11943 and not port 11944 and not port 11945 and not port 11946 and not port 11947 and not port 11948 and not port 11949 \
  and not port 51820 \
  "$@"
  
