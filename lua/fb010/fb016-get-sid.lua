#!/usr/bin/env lua

-- http://lua-users.org/wiki/DataDumper
require "dump"

-- http://lua-users.org/wiki/LuaXml
require "simplexml"

-- local
require "fblogin"

-- Config
local fb_url = "http://fritz.box"
local fb_user = "root"
local fb_pw = "(uFqe[Wg\\6b\\mUA[g}*0auiB].=]vqdb"

local sid, xml = fb_login(fb_user, fb_pw, fb_url)

dump(sid)
dump(xml)
