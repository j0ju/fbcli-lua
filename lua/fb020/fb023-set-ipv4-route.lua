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


-- POST /data.lua HTTP/1.1
--   data:
--     ipaddr0=201
--     ipaddr1=0
--     ipaddr2=115
--     ipaddr3=0
--     netmask0=255
--     netmask1=255
--     netmask2=255
--     netmask3=0
--     gateway0=192
--     gateway1=168
--     gateway2=141
--     gateway3=18
--     isActive=0
--     route=              # name this to update a route
--     apply=              # this applies  the route, response has apply = "ok" if successfull
--     page=new_static_route
--     sid=e6917ba911e8e199
--     sidRenew=true

--r = {
--  ipaddr0 = "200",
--  ipaddr1 = "0",
--  ipaddr2 = "115",
--  ipaddr3 = "0",
--  netmask0 = "255",
--  netmask1 = "255",
--  netmask2 = "255",
--  netmask3 = "0",
--  gateway0 = "192",
--  gateway1 = "168",
--  gateway2 = "141",
--  gateway3 = "18",
--  isActive = "0",
--  --#route = "route2",
--  apply = "",
--}
--
--t = fb_POST_json_data_lua(fbhandle, "new_static_route", r)
--dump (t)

-- Login
local fbhandle = fb.login(fb_user, fb_pw, fb_url)

--dump ( fb.route.ipv4.add(fbhandle, "201.0.113.0/32", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.113.0/28", "192.168.141.18") )
dump ( fb.route.ipv4.add(fbhandle, "201.0.113.0/25", "192.168.141.18") )
dump ( fb.route.ipv4.add(fbhandle, "201.0.113.0/24", "192.168.141.18") )
dump ( fb.route.ipv4.add(fbhandle, "201.0.113.0/23", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/17", "192.168.141.18") )
dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/16", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/15", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/8", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/7", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/1", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/9", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/8", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/7", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/2", "192.168.141.18") )
--dump ( fb.route.ipv4.add(fbhandle, "201.0.0.0/1", "192.168.141.18") )

dump(fb.route.ipv4.list(fbhandle))

-- vim: ts=2 et sw=2 fdm=indent ft=lua
