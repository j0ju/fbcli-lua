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

 * v4via
 * v6via
 * table
 * follow
 * pollms
 * ip

## Examples

### Login

```
FRITZBOX_PASSWORD="secret"
export FRITZBOX_SESSION="$(FRITZBOX_PASSWORD="$FRITZBOX_PASSWORD" fbcli login user root | tee /proc/self/fd/2 )"
```

