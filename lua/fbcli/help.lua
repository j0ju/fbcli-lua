#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

return function()
  local _, scriptname = arg[0]:match('(.-)([^\\/]-%.?([^%.\\/]*))$')
  PStdErr("Usage: ")
  PStdErr("  ".. scriptname .." [obj] <action?> <options*>")
  PStdErr("")
  PStdErr([[
  * login       - gets session id from FritzBox and outputs it to STDOUT
    - url         - see also environment FRITZBOX_URL
    - user        - see also environment FRITZBOX_USER
    - password    - see also environment FRITZBOX_PASSWORD

  Objects and actions below need a valid session id in FRITZBOX_SESSION
  for FRITZBOX_URL.

  * route show  - shows all extra routes
  * route add   - adds an extra route, it ensure that we have only one route
                  for a prefix
    - prefix
    - via
    - active      - flag determining if the route is "active", (default 1)

  * route del   - deletes all extra route for prefix
    - prefix

  * route flush - remove all extra routes

  * route sync  - sync extra routes on FritzBox with routes in routing table
    - table       - name of the local routing table to sync with
                    (default: main)
    - v4via       - where should the FritzBox should route to for extra
                    routes (IPv4)
                    IPv4 routes are only synced if this is set
    - v6via       - ... the same for (IPv6)
    - follow      - do a continous sync
                    (boolean: default: false)
    - ip          - full path of "ip" binary
                    (default: /sbin/ip)
    - pollms      - milliseconds to wait for input, before act on another
                    batch (default: 5000ms)
    - noop        - dry run
                    (boolean: false)
    - policy      - policy to enforce if no allow or deny rule matches
                    deny - allow list, rest deny by policy
                    allow - deny list, rest allow by policy
    - deny        - specifies a prefix to be denied, can be specified multiple times
    - allow       - specifies a prefix to be denied, can be specified multiple times

  * host list   - lists hosts
    - active      - list active or passive hosts (boolean: true)
    - passive     - list active or passive hosts (boolean: true)
    - sort        - sort options (default: none, use lower case coloumn name: name, mac, ipv4, port)

  * status

  ]])
  os.exit(1)
end

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
