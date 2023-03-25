#!/usr/bin/env lua

-- get local path of script and take care of symlinks
-- add it to package path
local lfs = require("lfs")
function base_dir(fn)
  local cwd = lfs.currentdir()
  local s = {}
  local tmpdir = cwd
  repeat
    tmpdir, fn, _ = fn:match('(.-)([^\\/]-%.?([^%.\\/]*))$')
    if tmpdir == "" then
      tmpdir = cwd
    end
    lfs.chdir(tmpdir)
    tmpdir = lfs.currentdir()
    s = lfs.symlinkattributes(fn)
    if s.target then
      fn = s.target
    end
  until s.target == nil
  lfs.chdir(cwd)
  return tmpdir
end
package.path = base_dir(arg[0]) .. "/?.lua;" .. package.path


-- local
local CLI = require("CLI")
local FB = require("fritzbox")
require "dump"


-- defintion of cli arguemnts
FBcli = { route = {} }

function FBcli.login(argv, i) 
  local fb = {
    url = "http://fritz.box",
    password = os.getenv("FRITZBOX_PASSWORD") or "",
    user = os.getenv("FRITZBOX_USER") or "",
  }
  CLI.parse_into_table(fb, argv, i)
  fbhandle = FB.login(fb.user, fb.password, fb.url)
  print("session", fbhandle.sid)
end

function FBcli.route.DEFAULT()
  return FBcli.route.show()
end
function FBcli.route.add()
  print("FBcli.route.add")
end
function FBcli.route.delete()
  print("FBcli.route.delete")
end
function FBcli.route.show()
  print("FBcli.route.show")
end

CLI.action(FBcli, arg)

-- vim: ts=2 et sw=2 fdm=indent ft=lua
