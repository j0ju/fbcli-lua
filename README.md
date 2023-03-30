# fbcli - a CLI utility for FritzBoxes

## Requirements

 * lua 5.1
 * lfs - LuaFilesystem
 * luaposix
 * lua-md5
 * ip CLI utility from iproute2 suite (the busybox variant does not work in all cases)

Q: Why lua 5.1?
A: - This is per default installed on OpenWrt boxes.

### OpenWrt

Tested with OpenWrt 21.02 and 22.03
```
opkg install lua-md5 luafilesystem luaposix ip-full
```

### Debian/Ubuntu

Tested with Ubuntu 22.04 and Bebian Bullseye
```
apt-get install lua5.1 lua-posix lua-filesystem lua-md5
```

## Installation

Put all lua files in a directory eg. `/usr/local/lib/fbcli`.
`fbcli` can now be executed inside of that directory via `lua5.1 fbcli.lua`.

If additionally a link in PATH exist it is executable as `fbcli`.

eg.
```
ln -s /usr/local/lib/fbcli/fbcli.lua /usr/local/bin/fbcli
chmod 0755 /usr/local/bin/fbcli
```

## Usage

This utility behaves a bit like `ip` from iproute2 suite.

### fbcli login

This outputs a valid session id to STDOUT, when provided credentials are correct.
This session id can be stored and reused in environment `FRITZBOX_SESSION`.

 * `user <user>`
 * `password <pass>`
 * `url <url>` - defaults to `http://fritz.box`

#### Environment

 * `FRITZBOX_URL` defaults to `http://fritz.box`
 * `FRITZBOX_USER`
 * `FRITZBOX_PASSWORD`
 * `FRITZBOX_SESSION`

All but `FRITZBOX_SESSION` can be used by `login` op.

### fbcli route show

This output extra routes set in the FritzBoxes web interface.

### fbcli route add

This operation adds a route to the FritzBox.
Installed routes are set to "active".
This util ensures that only one route per prefix is added to the FritzBox.
It should behave similar to `ip route add ...`

 * `prefix <prefix>`
 * `via <via>`
 * `active <0|1>` - if the route is activated on the FritzBox

### fbcli route delete

This operation deletes a route from the FritzBox.
It should behave similar to `ip route del ...`

 * `prefix <prefix>`
 * `name <name>` - if specified delete a route named like <name> (see route show)

### fbcli route flush

This deletes all extra routes from the FritzBox.

### fbcli route sync

This syncs extra routes on FritzBox with routes in routing table on current host.

 * `v4via` - where should the FritzBox should route to for extra routes (IPv4). IPv4 routes are only synced if this is set.
 * `v6via` - ... the same for (IPv6)
 * `table` - name of the local routing table to sync with (default: main)

 * `policy` - policy to enforce if no allow or deny rule matches. deny - allow list, 'rest' deny by policy, 'allow' - deny list, rest allow by policy
 * `deny` - specifies a prefix to be denied in policy `allow`, can be specified multiple times
 * `allow` - specifies a prefix to be allowed in policy `deny`, can be specified multiple times

 * `pollms` - milliseconds to wait for input, before act on another batch (default: 5000ms)
 * `follow` - do a continous sync (boolean: default: false)
 * `noop` - dry run (boolean: false)
 * `ip` - full path of "ip" binary (default: /sbin/ip)

## Examples

### Login

This fetches a session id from FritzBox reachable via http://fritz.box/, with user `root`.


```
FRITZBOX_PASSWORD="secret"
export FRITZBOX_SESSION="$(FRITZBOX_PASSWORD="$FRITZBOX_PASSWORD" fbcli login user root | tee /proc/self/fd/2 )"
```

All following examples assume a valid `FRITZBOX_SESSION` in environment.

### Route show

```
# fbcli route show
201.0.113.42/32 via 192.168.178.2 name route0 active 1
10.80.80.0/32 via 192.168.141.18 name route1 active 1
[...]
```

### Route add

```
fbcli route add 201.0.113.0/24 via 192.168.178.2
```

### Route del

```
fbcli route del 201.0.113.0/24
```

