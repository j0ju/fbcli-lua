#!/usr/bin/env lua5.1

-- get local path of script and take care of symlinks
-- add it to package path
local lfs = require("lfs")
local base_dir = function (fn)
  local cwd = lfs.currentdir()
  local s = {}
  local dir = cwd
  repeat
    dir, fn, _ = fn:match('(.-)([^\\/]-%.?([^%.\\/]*))$')
    if dir == "" then dir = cwd end
    lfs.chdir(dir)
    dir = lfs.currentdir()
    s = lfs.symlinkattributes(fn)
    if s.target then fn = s.target end
  until s.target == nil
  lfs.chdir(cwd)
  return dir
end
package.path = base_dir(arg[0]) .. "/?.lua;" .. package.path

-- local
CLI = require("CLI")
IP = require("ipaddr")
FB = require("fritzbox")
require "dump"

-- defintion of CLI functions
FBcli = { verbose = false, }
FBcli.help = function()
  local _, scriptname = arg[0]:match('(.-)([^\\/]-%.?([^%.\\/]*))$')
  pstderr("Usage: ")
  pstderr("  ".. scriptname .." [obj] <action?> <options*>")
  pstderr("")
  pstderr([[
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
  ]])
  os.exit(1)
end
FBcli.DEFAULT = FBcli.help
FBcli.login = require ("fbcli-login")
FBcli.route = require ("fbcli-route")
FBcli.route.sync = require ("fbcli-route-sync")


function FBcli.testcli(argv, i)
  -- CLI Parse
  local args = {
    string = "string",
    bool = false,
    number = 5000,
    table = {},
    ip = ""
  }
  local _, err = CLI.parse_into_table(args, argv, i)
  die_on_err(err)

  args.ip_type, args.ip_addr, args.ip_cidr = IP.type(args.ip)
  dump(args)
end


-- set FritzBox session & CLI call
FBhandle = {
  url = os.getenv("FRITZBOX_URL") or "http://fritz.box",
  sid = os.getenv("FRITZBOX_SESSION") or "",
}

FB.verbose = false
FBcli.verbose = false

local rs, err = CLI.action(FBcli, arg)
die_on_err(err)

os.exit(0)

-- vim: ts=2 et sw=2 fdm=indent ft=lua
