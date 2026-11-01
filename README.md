# fbcli - a CLI utility for FritzBoxes

## Requirements

 * lua 5.1
 * lfs - LuaFilesystem
 * luaposix
 * lua-md5
 * luasocket
 * ip CLI utility from iproute2 suite (the busybox variant does not work in all cases)

Q: Why lua 5.1?
A: - This is per default installed on OpenWrt boxes.

`luaposix` and `ip` are only needed for `route sync`.

### OpenWrt

Tested with OpenWrt 21.02 and 22.03
```
opkg install lua-md5 luafilesystem luaposix luasocket ip-full
```

### Debian/Ubuntu

Tested with Ubuntu 22.04 and Debian Bullseye
```
apt-get install lua5.1 lua-posix lua-filesystem lua-md5 lua-socket
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
Objects, actions and option names can be abbreviated by leaving out characters, eg. `fbcli ro sh`
is `fbcli route show`. Ambiguous abbreviations (`s` could be `show` or `sync`) pick any match.
Boolean options can be given without a value (`true`) or with one of
`yes|no|1|0|true|false|enable|disable`.

`fbcli help` (or no arguments at all) prints a usage summary.

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

This outputs the extra routes (IPv4 and IPv6) set in the FritzBoxes web interface.

### fbcli route add

This operation adds a route to the FritzBox, `route replace` is an alias.
Installed routes are set to "active" by default.
This util ensures that only one route per prefix is added to the FritzBox,
an existing route for the prefix is updated, surplus duplicates are removed.
It should behave similar to `ip route add ...`

 * `prefix <prefix>`
 * `via <via>`
 * `active <0|1>` - if the route is activated on the FritzBox

### fbcli route delete

This operation deletes all routes for a prefix from the FritzBox.
It should behave similar to `ip route del ...`

 * `prefix <prefix>`
 * `name <name>` - if specified delete a route named like <name> (see route show)

### fbcli route flush

This deletes all extra routes from the FritzBox.

### fbcli route sync

This syncs extra routes on FritzBox with routes in routing table on current host.
All routes of the local table (except default, link-local and multicast routes)
are added to the FritzBox pointing to `v4via` / `v6via`.
With `follow` route changes are watched via `ip monitor route`, removed local
routes are deleted on the FritzBox, if they point to `v4via` / `v6via`.
Bursts of changes are collected and pushed after `pollms` of silence.
Routes on the FritzBox not present locally are not removed by the initial sync.

 * `v4via` - where should the FritzBox should route to for extra routes (IPv4). IPv4 routes are only synced if this is set.
 * `v6via` - ... the same for (IPv6)
 * `table` - name of the local routing table to sync with (default: main)

 * `policy` - policy to enforce if no allow or deny rule matches (default: allow).
   `deny` - allow list, rest deny by policy, `allow` - deny list, rest allow by policy
 * `deny` - specifies a prefix to be denied in policy `allow`, can be specified multiple times
 * `allow` - specifies a prefix to be allowed in policy `deny`, can be specified multiple times

 * `pollms` - milliseconds to wait for input, before act on another batch (default: 5000ms)
 * `follow` - do a continous sync (boolean: default: false)
 * `noop` - dry run (boolean: false)
 * `ip` - full path of "ip" binary (default: /sbin/ip)

### fbcli host list

Lists the hosts known to the FritzBox (`host show` is an alias).

 * `active <bool>` - list active hosts (default: true)
 * `passive <bool>` - list passive/offline hosts (default: true)
 * `wifi <bool>` - list hosts connected via WLAN (default: true)
 * `ethernet <bool>` - list hosts connected via LAN (default: true)
 * `sort <coloumn>` - one of `name`, `mac`, `ipv4`, `online`, `port` (default: ipv4)

### fbcli host delete

Deletes a passive/offline host from the FritzBox by name (`host remove`, `host rm` are aliases).
Active hosts cannot be deleted.

 * `name <name>`

### fbcli host dump

Debugging aid: dumps the raw reply of the FritzBox for all hosts or a host given by `name`.

### fbcli status

Shows the state of the internet connections.

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

### Route sync

Push all routes of the local table `main` once, IPv4 routes via `192.168.178.2`,
except RFC1918 ranges:

```
fbcli route sync v4via 192.168.178.2 deny 10.0.0.0/8 deny 172.16.0.0/12 deny 192.168.0.0/16
```

Keep syncing (eg. as a service) and show what would happen first:

```
fbcli route sync v4via 192.168.178.2 v6via fe80::2 follow noop
```

### Host list

```
# fbcli host list passive no sort name
 NAME                IPV4               MAC ONLINE PORT
 fritz.box  192.168.178.1 AA:00:00:00:00:00    yes
 laptop    192.168.178.20 AA:00:00:00:00:01    yes WLAN
```

### Host delete

```
fbcli host del old-laptop
```

## Reverse engineering

The FritzBox web interface API is undocumented. `docs/dumps` contains
`dump.sh` to capture the traffic between a client and the FritzBox (plain HTTP)
and compressed captures (`*.pcap.zst`) of web interface actions.
`docs/fb.api.txt` lists the TR-064 API of a FritzBox 7590 (FRITZ!OS 7.29).

## License

GPL v2, see `lua/LICENSE.txt`. `lua/JSON.lua` is by Jeffrey Friedl, CC-BY.

