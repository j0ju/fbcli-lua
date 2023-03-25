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

-- Reqs
--local json = require("simplejson")
local JSON = require("JSON")

local io = require("io")
local http = require("socket.http")
local ltn12 = require("ltn12")



-- get IPv4 routes

local post_data = "sid=".. fbhandle.sid .."&page=static_route_table"
local resp = {}
local b, code, resp_h, status = http.request {
  url = fb_url .. "/data.lua",
  method = "POST",
  source = ltn12.source.string(post_data),
  headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
    ["Content-Length"] = #post_data
  },
  sink = ltn12.sink.table(resp)
}

print(resp[1])

--local t = json.parse(resp[1])
local t = JSON:decode(resp[1])
dump (t)



-- get IPv6 routes

local post_data = "sid=".. fbhandle.sid .."&page=static_IPv6_route_table"
local resp = {}
local b, code, resp_h, status = http.request {
  url = fb_url .. "/data.lua",
  method = "POST",
  source = ltn12.source.string(post_data),
  headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
    ["Content-Length"] = #post_data
  },
  sink = ltn12.sink.table(resp)
}

print(resp[1])

--local t = json.parse(resp[1])
local t = JSON:decode(resp[1])
dump (t)

-- vim: ts=2 et sw=2 fdm=indent ft=lua
