#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

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

-- requirements
CLI = require("CLI")
IP = require("ipaddr")
FB = require("fritzbox")
require "console"
require "luautil"
require "dump"

-- defintion of CLI functions
FBcli = { verbose = false, }
FBcli.help = require ("fbcli.help")
FBcli.DEFAULT = FBcli.help
FBcli.login = require ("fbcli.login")
FBcli.route = require ("fbcli.route")
FBcli.route.help = FBcli.help
FBcli.route.sync = require ("fbcli.route.sync")
FBcli.host = require ("fbcli.host")
FBcli.status = require ("fbcli.status")

-- FBcli.ula -- list, set
-- FBcli.dnsserver -- list == show, set
-- FBcli.allowdnsrebind -- list == show, set, add, remove
-- FBcli.status -- list == show

FBcli.testcli = CLI.example_action


-- set FritzBox session & CLI call
FBhandle = {
  url = os.getenv("FRITZBOX_URL") or "http://fritz.box",
  sid = os.getenv("FRITZBOX_SESSION") or 0,
}
-- disable verbosity
FB.verbose = false
FBcli.verbose = false

local rs, err = CLI.action(FBcli, arg)
die_on_err(err)

os.exit(0)

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
