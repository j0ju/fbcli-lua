#!/usr/bin/env lua

-- get local path of script and take care of symlinks
-- add it to package path
local lfs = require("lfs")
local base_dir = function (fn)
  local cwd = lfs.currentdir()
  local s = {}
  local dir = cwd
  repeat
    dir, fn, _ = fn:match('(.-)([^\\/]-%.?([^%.\\/]*))$')
    if dir == "" then
      dir = cwd
    end
    lfs.chdir(dir)
    dir = lfs.currentdir()
    s = lfs.symlinkattributes(fn)
    if s.target then
      fn = s.target
    end
  until s.target == nil
  lfs.chdir(cwd)
  return dir
end
package.path = base_dir(arg[0]) .. "/?.lua;" .. package.path

-- local
local CLI = require("CLI")
local IP = require("ipaddr")
local FB = require("fritzbox")
require "dump"

-- defintion of CLI functions
FBcli = { route = {} }

function FBcli.login(argv, i) 
  local fb = {
    url = os.getenv("FRITZBOX_URL") or "http://fritz.box",
    password = os.getenv("FRITZBOX_PASSWORD") or "",
    user = os.getenv("FRITZBOX_USER") or "",
  }
  CLI.parse_into_table(fb, argv, i)
  FBhandle = FB.login(fb.user, fb.password, fb.url)
  print(FBhandle.sid)
end

function FBcli.route.show()
  routes, err = FB.route.list(FBhandle)
  if err then
    pstderr(string.format("E: %s route show: %s ", arg[0], err.message))
    os.exit(1)
  else
    for pfx, r in pairs(routes) do
      if pfx:match("^.*/.*$") then
        print(string.format("%s via %s name %s active %s", pfx, r.via, r.name, r.active))
      end
    end
  end
end
FBcli.route.DEFAULT = FBcli.route.show
FBcli.route.list = FBcli.route.show

function FBcli.route.add(argv, i)
  local r = {
    prefix = argv[i] or "",
    via = "",
    name = "",
    active = "1",
  }
  CLI.parse_into_table(r, argv, i)
  dump(
    FB.route.add(FBhandle, r)
  )
end
FBcli.route.replace = FBcli.route.add

function FBcli.route.delete(argv, i)
  local r = {
    prefix = argv[i] or "",
    via = "",
    name = "",
    active = "",
  }
  CLI.parse_into_table(r, argv, i)
  if r.name == "" then r.name = nil end
  dump(
    FB.route.delete(FBhandle, r.name or r.prefix, r.via)
  )
end


-- set FritzBox session & CLI call
FBhandle = {
  url = os.getenv("FRITZBOX_URL") or "http://fritz.box",
  sid = os.getenv("FRITZBOX_SESSION") or "",
}
--FB.verbose = false
CLI.action(FBcli, arg)

-- vim: ts=2 et sw=2 fdm=indent ft=lua
