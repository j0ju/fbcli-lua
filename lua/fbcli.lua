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
FBcli = {
  --verbose = true,
}
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
  }
  local _, err = CLI.parse_into_table(args, argv, i)
  die_on_err(err)

  dump(args)
end


-- set FritzBox session & CLI call
FBhandle = {
  url = os.getenv("FRITZBOX_URL") or "http://fritz.box",
  sid = os.getenv("FRITZBOX_SESSION") or "",
}
FB.verbose = false
CLI.action(FBcli, arg)

-- vim: ts=2 et sw=2 fdm=indent ft=lua
