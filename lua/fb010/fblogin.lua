#!/usr/bin/env lua

-- http://lua-users.org/wiki/LuaXml

require "simplexml"

local md5 = require "md5"

local io = require("io")
local http = require("socket.http")
local ltn12 = require("ltn12")

function fb_response(ch, pw)
  local pre = ch .. "-" .. pw
  local n = ""
  local i = 0
  for i = 1, #pre do
    n = n .. pre:sub(i,i) .. string.char(0)
  end
  local resp = ch .. "-" .. md5.sumhexa(n)
  return resp
end

function fb_login(user, pw, url) 
  -- Fetch login page
  local resp = {}
  local b, code, resp_h, s = http.request{
    url = url .. "/login_sid.lua",
    method = "GET",
    sink = ltn12.sink.table(resp)
  }
  --#print("-- Fetch challege via login page")
  --#print("HTTP Status", code)

  -- XML parse
  local x = sxml_tree(table.concat(resp))
  --#dump(x)
  local t = sxml_find_element(x, "Challenge")
  --#dump(t)
  local challenge = t[1]
  --#print("Challenge", challenge)
  --#print()

  local fb_r = fb_response(challenge, pw)

  post_data = "response=".. fb_r .. "&username=" .. user
  --#print("'".. post_data .."'")

  resp = {}
  local b, code, resp_h, status = http.request {
    url = url .. "/login_sid.lua",
    method = "POST",
    source = ltn12.source.string(post_data),
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Content-Length"] = #post_data
    },
    sink = ltn12.sink.table(resp)
  }
  --#print("-- Fetch SID via login page")
  --#print("HTTP Status", code)
  
  x = sxml_tree(table.concat(resp))
  --#dump(x)
  t = sxml_find_element(x, "SID")
  --#dump(t)

  return t[1], x
end

-- vim: ts=2 et sw=2 fdm=indent ft=lua

