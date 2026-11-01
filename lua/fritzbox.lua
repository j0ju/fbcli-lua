#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

-- functions to call the FritzBox API

local XML = require("simplexml")
local JSON = require("JSON")
local MD5 = require("md5")

local IP = require("ipaddr")

local io = require("io")
local http = require("socket.http")
local ltn12 = require("ltn12")

require ("luautil")

local fb = {
  verbose = true,
  route = { ipv4 = {}, ipv6 = {}, },
  host = {},
  mesh = {},
}

-- Helper:
--   URL-encodes a value for application/x-www-form-urlencoded bodies
local urlencode = function(str)
  str = tostring(str)
  str = str:gsub("\n", "\r\n")
  str = str:gsub("([^%w%-%._~ ])", function(c) return string.format("%%%02X", string.byte(c)) end)
  str = str:gsub(" ", "+")
  return str
end

-- Helper:
--   for login, generates response on challange for authentication
local fb_response = function(ch, pw)
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
  -- Fetch login page and challenge
  local resp = {}
  local b, code, resp_h, s = http.request{
    url = url .. "/login_sid.lua",
    method = "GET",
    sink = ltn12.sink.table(resp)
  }
  if b == nil then
    return nil, { errmsg = string.format("HTTP call to %s/login_sid.lua failed: %s", url, tostring(code)), exitcode = 1 }
  end

  -- Calculate response from challenge
  local x = XML.parse(table.concat(resp))
  local t = XML.find_element(x, "Challenge")
  if t == nil or t[1] == nil then
    return nil, { errmsg = string.format("no login challenge found at %s/login_sid.lua (HTTP status: %s)", url, tostring(code)), exitcode = 1 }
  end
  local resp = fb_response(t[1], pw)
  local post_data = "response=".. urlencode(resp) .. "&username=" .. urlencode(user)

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
  if b == nil then
    return nil, { errmsg = string.format("HTTP call to %s/login_sid.lua failed: %s", url, tostring(code)), exitcode = 1 }
  end

  x = XML.parse(table.concat(resp))
  t = XML.find_element(x, "SID") or {}

  if (not (t==nil)) and (code == 200) and (not (t[1]==nil)) and ((tonumber(t[1], 16) or 0) > 0) then
    return { url=url, user=user, sid=t[1], login_info=x }, nil
  end
  local blocktime = XML.find_element(x, "BlockTime") or {}
  return nil, {
    errmsg = string.format("could not get a valid session Id (HTTP status: %s, SID: %s, blocktime: %s seconds)", tostring(code), t[1] or "", blocktime[1] or "(unknown)"),
    exitcode = 1
  }
end

-- Helper:
--   fetches a page of data.lua
local fb_POST_json_data_lua = function(fbhandle, page, args)
  if fb.verbose then
    PStdErr("I: fb_POST_json_data_lua(page = '".. page .."', [...])")
  end
  if args == nil then
    args = {}
  end

  local post_data = "sid=".. urlencode(fbhandle.sid) .."&page=".. urlencode(page)
  local k, v
  for k, v in pairs(args) do
    post_data = post_data .. "&" .. urlencode(k) .. "=" .. urlencode(v)
  end
  --print(post_data)

  local resp = {}
  local url = fbhandle.url .. "/data.lua"
  local b, code, resp_h, status = http.request {
    url = url,
    method = "POST",
    source = ltn12.source.string(post_data),
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Content-Length"] = #post_data
    },
    sink = ltn12.sink.table(resp)
  }

  if b == nil then
    return nil, { errmsg = string.format("HTTP call to %s (%s) failed: %s", url, page, tostring(code)), exitcode = 1 }
  end
  if fb.verbose then
    PStdErr("I: fb_POST_json_data_lua: HTTP status: ".. code)
  end
  if not (code == 200) then
    local err = { code = code, exitcode = 1, errmsg = string.format("HTTP call to %s (%s) unsuccessful %s. Check credentials!", url, page, tostring(code)) }
    if fb.verbose then
      PStdErr("E: fb_POST_json_data_lua: ".. err.errmsg)
    end
    return nil, err
  end

  local body = table.concat(resp)
  local ok, data = pcall(JSON.decode, JSON, body)
  if not ok or data == nil then
    return nil, { exitcode = 1, errmsg = string.format("cannot decode JSON reply of %s (%s): %s", url, page, tostring(data)) }
  end
  return data, nil
end

function fb.route.list(fbhandle)
  if fb.verbose then
    PStdErr("I: fb.route.list()")
  end
  local extraroutes = {}
  -- IPv4
  local fb_routes, err = fb.route.ipv4.list(fbhandle)
  if err then
    return nil, err
  end

  for _, fb_r in pairs(fb_routes.data.staticRoutes.route) do
    local cidr = IP.netmask2cidr(fb_r.netmask)
    local r = {
      prefix = IP.prefix(fb_r.ipaddr .. "/" .. cidr),
      via = IP.address(fb_r.gateway),
      name = fb_r._node,
      active = fb_r.activated,
    }
    -- we add this route by refernce indexed in multiple ways
    -- by
    --  * prefix
    --  * FritzBox's internal name
    -- and with lua list indexes for sort
    extraroutes[r.prefix] = r
    extraroutes[r.name] = extraroutes[r.prefix]
    table.add(extraroutes, r)
  end
  -- IPv6
  fb_routes, err = fb.route.ipv6.list(fbhandle)
  if err then
    return nil, err
  end
  for _, fb_r in pairs(fb_routes.data.staticRoutes) do
    local r = {
      prefix = IP.prefix(fb_r.ipv6Address .. "/" .. fb_r.prefixLength),
      via =  IP.address(fb_r.gateway),
      name = fb_r.id,
      active = fb_r.isActive,
    }
    extraroutes[r.prefix] = r
    extraroutes[r.name] = extraroutes[r.prefix]
    table.add(extraroutes, r)
  end
  --
  return extraroutes, nil
end

function fb.route.list_filter(in_routes, r)
  local routes = in_routes
  for k, v in pairs(routes) do
    if r.type then
      local t, _, _ = IP.type(k)
      if not (t == r.type) then
        routes[k] = nil
      end
    end
    if r.prefix then
      if not (k == r.prefix) then
        routes[k] = nil
      end
    end
    if not ((r.via or "") == "") then
      if not (v.via == r.via) then
        routes[k] = nil
      end
    end
    if not ((r.name or "") == "") then
      if not (v.name == r.name) then
        routes[k] = nil
      end
    end
  end
  return routes
end

-- Helper:
--   returns all routes (as list) for a prefix, the list from fb.route.list
--   indexes routes by prefix only once, duplicates are only visible in the
--   integer indexed part
local fb_route_list_by_prefix = function(fbhandle, prefix)
  local routes, err = fb.route.list(fbhandle)
  if err then
    return nil, err
  end
  local rs = {}
  for _, r in ipairs(routes) do
    if r.prefix == prefix then
      table.add(rs, r)
    end
  end
  return rs, nil
end

function fb.route.add(fbhandle, route)
  route.prefix = IP.prefix(route.prefix)
  route.type, _, _= IP.type(route.prefix)
  if fb.verbose then
    PStdErr( string.format("I: fb.route.add({ prefix = %s, via = %s, active = %s, name = %s })", route.prefix, route.via, route.active, (route.name or "")))
  end
  local af
  if route.type == "ipv4+cidr" then
    af = fb.route.ipv4
  elseif route.type == "ipv6+cidr" then
    af = fb.route.ipv6
  else
    return nil, { exitcode = 1, errmsg = string.format("fb.route.add - address family of '%s' not supported, yet", tostring(route.prefix)) }
  end

  -- ensure we have only one route per prefix, remove all but 0 or 1 routes for that prefix
  local current_routes, err
  repeat
    current_routes, err = fb_route_list_by_prefix(fbhandle, route.prefix)
    if err then
      return nil, err
    end
    if #current_routes > 1 then
      local _, err = af.delete(fbhandle, current_routes[#current_routes].name)
      if err then
        return nil, err
      end
    end
  until #current_routes <= 1

  -- add or update (by name) current prefix
  local current = current_routes[1]
  if current then
    if    ( current.via == IP.address(route.via) )
      and ( tostring(current.active) == tostring(route.active) ) then
      return true, nil
    end
    return af.set(fbhandle, route.prefix, route.via, route.active, current.name)
  end
  return af.add(fbhandle, route.prefix, route.via, route.active)
end

function fb.route.delete(fbhandle, name, via)
  if fb.verbose then
    PStdErr(string.format("I: fb.route.delete(%s, %s)", name, via or ""))
  end
  local t, a, p = IP.type(name)
  -- IPv4
  if name:find("^route%d+") then
    return fb.route.ipv4.delete(fbhandle, name, nil)
  elseif (t or ""):find("^ipv4") then
    return fb.route.ipv4.delete(fbhandle, name, via)
  -- IPv6
  elseif name:find("^ip6route%d+") then
    return fb.route.ipv6.delete(fbhandle, name, nil)
  elseif (t or ""):find("^ipv6") then
    return fb.route.ipv6.delete(fbhandle, name, via)
  else
    return nil, { exitcode = 1, errmsg = string.format("fb.route.delete - '%s' is neither a route name nor a prefix of a supported address family", tostring(name)) }
  end
end

-- Lists routes, routes are in .data.staticRoutes.route
function fb.route.ipv4.list(fbhandle)
  if fb.verbose then
    PStdErr("I: fb.route.ipv4.list()")
  end
  return fb_POST_json_data_lua(fbhandle, "static_route_table")
end

function fb.route.ipv6.list(fbhandle)
  if fb.verbose then
    PStdErr("I: fb.route.ipv6.list()")
  end
  return fb_POST_json_data_lua(fbhandle, "static_IPv6_route_table")
end

-- Adds and update routes, does not check for existing routes with same prefix
function fb.route.ipv4.set(fbhandle, prefix, via, active, name)
  local active = (active or 1)
  local name = (name or "")

  if fb.verbose then
    PStdErr(string.format("I: fb.route.ipv4.set(%s, %s, %s, %s)", prefix, via, active, name))
  end
  -- split prefix in oktets and cidr
  local i, _, ip1, ip2, ip3, ip4, cidr = prefix:find('(%d+).(%d+).(%d+).(%d+)/(%d+)')
  if not i then
    return nil
  end

  -- convert cidr to netmask
  local netmask=IP.cidr2netmask(cidr)
  -- netmask to oktets
  local i, _ , nm1, nm2, nm3, nm4 = netmask:find('(%d+).(%d+).(%d+).(%d+)')
  if not i then
    return nil
  end

  -- via to oktets
  local i, _ , via1, via2, via3, via4 = via:find('(%d+).(%d+).(%d+).(%d+)')
  if not i then
    return nil
  end

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
fb.route.ipv4.add = fb.route.ipv4.set

-- Adds and update routes, does not check for existing routes with same prefix
function fb.route.ipv6.set(fbhandle, prefix, via, active, name)
  local active = (active or 1)
  local name = (name or "")

  if fb.verbose then
    PStdErr(string.format("I: fb.route.ipv6.set(%s, %s, %s, %s)", prefix, via, active, name))
  end

  -- api call to create a new route
  local args = {
    gateway = IP.address(via),
    isActive = active,
    route = name,
    apply = "",
  }
  _, args.ipv6Address, args.prefixLength = IP.type(prefix)

  return fb_POST_json_data_lua(fbhandle, "new_IPv6_static_route", args)
end
fb.route.ipv6.add = fb.route.ipv6.set

-- Removes a IPv4 route -
--  - "name" can be "prefix" or "route name"
function fb.route.ipv4.delete(fbhandle, name, via)
  if fb.verbose then
    PStdErr(string.format("I: fb.route.ipv4.delete(%s, %s)", name, via or ""))
  end
  local t, a, p = IP.type(name)
  local rs
  if name:find("^route%d+") then
    local args = {
      id = name,
      delete = "",
    }
    return fb_POST_json_data_lua(fbhandle, "static_route_table", args)
  elseif (t or ""):find("^ipv4") then
    local current_routes = {}
    local prefix = name
    local err
    repeat
      current_routes, err = fb_route_list_by_prefix(fbhandle, IP.prefix(prefix))
      if err then
        return nil, err
      end
      if #current_routes > 0 then
        rs, err = fb.route.ipv4.delete(fbhandle, current_routes[1].name)
        if err then
          return nil, err
        end
      end
    until #current_routes == 0
    return (rs or true), nil
  end
end

-- Removes a IPv6 route -
--  - "name" can be "prefix" or "route name"
function fb.route.ipv6.delete(fbhandle, name, via)
  if fb.verbose then
    PStdErr(string.format("I: fb.route.ipv6.delete(%s, %s)", name, via or ""))
  end
  local t, a, p = IP.type(name)
  local rs
  if name:find("^ip6route%d+") then
    local args = {
      id = name,
      delete = "",
    }
    return fb_POST_json_data_lua(fbhandle, "static_IPv6_route_table", args)
  elseif (t or ""):find("^ipv6") then
    local current_routes = {}
    local prefix = name
    local err
    repeat
      current_routes, err = fb_route_list_by_prefix(fbhandle, IP.prefix(prefix))
      if err then
        return nil, err
      end
      if #current_routes > 0 then
        rs, err = fb.route.ipv6.delete(fbhandle, current_routes[1].name)
        if err then
          return nil, err
        end
      end
    until #current_routes == 0
    return (rs or true), nil
  end
end

function fb.host.list(fbhandle)
  local args = {
    xhr="1",
    xhrId="cleanup",
    useajax="1",
  }
  local r, err = fb_POST_json_data_lua(fbhandle, "netDev", args)
  return r, err
end

function fb.host.delete(fbhandle, landevice, devname)
  local args = {
    xhr="1",
    --
    delete=landevice,
    devname=devname,
    confirmed="",
  }
  local r, err = fb_POST_json_data_lua(fbhandle, "netDev", args)
  return r, err
end

function fb.mesh.list(fbhandle)
  local args = {
    xhr="1",
    xhrId="initial",
    useajax="1",
  }
  local r, err = fb_POST_json_data_lua(fbhandle, "homeNet", args)
  return r, err
end

function fb.status(fbhandle) -- online status
  local args = {
    xhr="1",
    xhrId="all",
    useajax="1",
  }
  local r, err = fb_POST_json_data_lua(fbhandle, "netMoni", args)
  return r, err
end

return fb

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua fml=1
