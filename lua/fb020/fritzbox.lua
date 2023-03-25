#!/usr/bin/env lua

local XML = require("simplexml")
local JSON = require("JSON")
local MD5 = require("md5")

local IP = require("ipaddr")

local io = require("io")
local http = require("socket.http")
local ltn12 = require("ltn12")

local fb = { 
  route = {
    ipv4 = {},
    ipv6 = {},
  }
}

-- Helper: 
--   for login, generates response on challange for authentication
function fb_response(ch, pw)
  local pre = ch .. "-" .. pw
  local n = ""
  local i = 0
  for i = 1, #pre do
    n = n .. pre:sub(i,i) .. string.char(0)
  end
  local resp = ch .. "-" .. MD5.sumhexa(n)
  return resp
end

function fb.login(user, pw, url) 
  local url = url
  if url == nil then
    url = "http://fritz.box" 
  end
  -- TODO: error handling on HTTP
  -- Fetch login page and challenge
  local resp = {}
  local b, code, resp_h, s = http.request{
    url = url .. "/login_sid.lua",
    method = "GET",
    sink = ltn12.sink.table(resp)
  }

  -- Calculate response from challenge
  local x = XML.parse(table.concat(resp))
  local t = XML.find_element(x, "Challenge")
  local resp = fb_response(t[1], pw)
  local post_data = "response=".. resp .. "&username=" .. user

  -- Present challenge to fritzbox to authenticate
  local resp = {}
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
  
  x = XML.parse(table.concat(resp))
  t = XML.find_element(x, "SID")

  return { url=url, user=user, sid=t[1], login_info=x }
end

-- Helper: 
--   fetches a page of data.lua
function fb_POST_json_data_lua(fbhandle, page, args)
  if args == nil then
    args = {}
  end

  -- TODO: error handling on HTTP
  local post_data = "sid=".. fbhandle.sid .."&page=".. page
  local k, v
  for k, v in pairs(args) do
    post_data = post_data .. "&" .. k .. "=" .. v
  end
  --print(post_data)

  local resp = {}
  local b, code, resp_h, status = http.request {
    url = fbhandle.url .. "/data.lua",
    method = "POST",
    source = ltn12.source.string(post_data),
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Content-Length"] = #post_data
    },
    sink = ltn12.sink.table(resp)
  }

  -- TODO: error handling on JSON
  --print (resp[1])
  return JSON:decode(resp[1])
end

-- Lists routes, routes are in .data.staticRoutes.route
function fb.route.ipv4.list(fbhandle)
  return fb_POST_json_data_lua(fbhandle, "static_route_table")
end

function fb.route.ipv6.list(fbhandle)
  return fb_POST_json_data_lua(fbhandle, "static_IPv6_route_table")
end

-- Adds routes, does not check for existing routes with same prefix
function fb.route.ipv4.add(fbhandle, prefix, via, active)
  return fb.route.ipv4.set(fbhandle, prefix, via, active)
end

-- Adds and update routes, does not check for existing routes with same prefix
function fb.route.ipv4.set(fbhandle, prefix, via, active, name)
  local active = active
  if active == nil then -- defaults
    active = 1
  end
  local name = name
  if name == nil then
    name = ""
  end

  -- split prefix in oktets and cidr
  local i, _, ip1, ip2, ip3, ip4, cidr = prefix:find('(%d+).(%d+).(%d+).(%d+)/(%d+)')
  if not i then
    return nil
  end
  
  print (prefix)
  print (cidr)

  -- convert cidr to netmask
  local netmask=IP.cidr2netmask(cidr)
  -- netmask to oktets
  local i, _ , nm1, nm2, nm3, nm4 = netmask:find('(%d+).(%d+).(%d+).(%d+)')
  if not i then
    return nil
  end
  print (netmask)
  
  -- via to oktets
  local i, _ , via1, via2, via3, via4 = via:find('(%d+).(%d+).(%d+).(%d+)')
  if not i then
    return nil
  end
  print (via)

  -- api call to create a new route
  local args = {
    ipaddr0  = ip1,  ipaddr1  = ip2,  ipaddr2  = ip3,  ipaddr3  = ip4,
    netmask0 = nm1,  netmask1 = nm2,  netmask2 = nm3,  netmask3 = nm4,
    gateway0 = via1, gateway1 = via2, gateway2 = via3, gateway3 = via4,
    isActive = active,
    route = name,
    apply = "",
  }

  return fb_POST_json_data_lua(fbhandle, "new_static_route", args)
end

function fb.route.ipv4.delete(fbhandle, name, via) -- name can be prefix or route name
  -- if name is "routeN" then 
  --   delete route by name
  -- else name is prefix then
  --   fetch list of all routes
  --   delete all matching routes with prefix and via (if set)
  -- end
end

return fb

-- vim: ts=2 et sw=2 fdm=indent ft=lua
