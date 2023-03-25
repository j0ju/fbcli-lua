#!/usr/bin/env lua

-- local
local fb = require("fritzbox")

-- http://lua-users.org/wiki/DataDumper
require "dump"

-- Config
local fb_url = "http://fritz.box"
local fb_user = "root"
local fb_pw = "(uFqe[Wg\\6b\\mUA[g}*0auiB].=]vqdb"
--local fb_pw = "wrong"

-- Login
local fbhandle = fb.login(fb_user, fb_pw, fb_url)

local r = fb.route.ipv4.list(fbhandle)
dump (r)
local r = fb.route.ipv6.list(fbhandle)
dump (r)

-- vim: ts=2 et sw=2 fdm=indent ft=lua
