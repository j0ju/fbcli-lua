#!/usr/bin/env lua5.1

local XML = require("simplexml")
local JSON = require("JSON")
local MD5 = require("md5")

local IP = require("ipaddr")

local io = require("io")
local http = require("socket.http")
local ltn12 = require("ltn12")

local fb = { 
  verbose = true,
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

  if (not (t==nil)) and (code == 200) and (not (t[1]==nil)) and ((tonumber(t[1], 16) or 0) > 0) then
    return { url=url, user=user, sid=t[1], login_info=x }, nil
  end
  local blocktime = XML.find_element(x, "BlockTime")
  return nil, {
    errmsg = string.format("could not get a valid session Id (HTTP status: %d, SID: %s, blocktime: %s seconds)", code, t[1] or "", blocktime[1] or "(unknown)"),
    exitcode = 1
  }
end

-- Helper: 
--   fetches a page of data.lua
local fb_POST_json_data_lua = function(fbhandle, page, args)
  if fb.verbose then
    pstderr("I: fb_POST_json_data_lua(page = '".. page .."', [...])")
  end
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

  if fb.verbose then
    pstderr("I: fb_POST_json_data_lua: HTTP status: ".. code)
  end
  error = nil
  if not (code == 200) then
    error = { code = code, message = string.format("HTTP call to %s (%s) unsuccessful %d. Check credentials!", url, page, code) }
    pstderr("E: fb_POST_json_data_lua: ".. error.message)
  end

  -- TODO: error handling on JSON
  local body = ""
  for _, v in pairs(resp) do
    body = body .. v
  end
  return JSON:decode(body), error
end

function fb.route.list(fbhandle)
  if fb.verbose then
    pstderr("I: fb.route.list()")
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
    extraroutes[r.prefix] = r
    extraroutes[r.name] = extraroutes[r.prefix]
    if extraroutes.via == nil then
      extraroutes.via = {}
    end
    extraroutes.via[r.prefix] = extraroutes[r.prefix]
  end
  -- IPv6
  fb_routes, e = fb.route.ipv6.list(fbhandle)
  for _, fb_r in pairs(fb_routes.data.staticRoutes) do
    local r = { 
      prefix = IP.prefix(fb_r.ipv6Address .. "/" .. fb_r.prefixLength),
      via =  IP.address(fb_r.gateway),
      name = fb_r.id,
      active = fb_r.isActive,
    }
    extraroutes[r.prefix] = r
    extraroutes[r.name] = extraroutes[r.prefix]
    if extraroutes.via == nil then
      extraroutes.via = {}
    end
    extraroutes.via[r.prefix] = extraroutes[r.prefix]
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
  end
  return routes
end

function fb.route.add(fbhandle, route)
  route.prefix = IP.prefix(route.prefix)
  route.type, _, _= IP.type(route.prefix)
  if fb.verbose then
    pstderr( string.format("I: fb.route.add({ prefix = %s, via = %s, active = %s, name = %s })", route.prefix, route.via, route.active, (route.name or "")))
  end
  if route.type == "ipv4+cidr" then
  -- IPv4
    -- ensure we have only one active route for per prefix, remove all but 0 or 1 routes for that prefix
    local current_routes = {}
    repeat
      current_routes = fb.route.list(fbhandle)
      current_routes = fb.route.list_filter(current_routes, { prefix = route.prefix, name = route.name })
      local l = table.len(current_routes)
      if l > 1 then
        if current_routes[route.prefix] then
          fb.route.del(fbhandle, current_routes[route.prefix].name)
        end
      end
    until l <= 1
    -- add or update (by name) current prefix
    if current_routes[route.prefix] then
      if not (     ( current_routes[route.prefix].prefix == route.prefix )
               and ( current_routes[route.prefix].via == route.via )
               and ( current_routes[route.prefix].active == route.active ) ) then
        route.name = current_routes[route.prefix].name
        return fb.route.ipv4.set(fbhandle, route.prefix, route.via, route.active, route.name)
      else
        return true
      end
    else
      return fb.route.ipv4.add(fbhandle, route.prefix, route.via, route.active)
    end
  elseif route.type == "ipv6+cidr" then
  -- IPv6
    local current_routes = {}
    repeat
      current_routes = fb.route.list(fbhandle)
      current_routes = fb.route.list_filter(current_routes, { prefix = route.prefix, name = route.name })
      local l = table.len(current_routes)
      if l > 1 then
        if current_routes[route.prefix] then
          fb.route.del(fbhandle, current_routes[route.prefix].name)
        end
      end
    until l <= 1
    if current_routes[route.prefix] then
      if not (     ( current_routes[route.prefix].prefix == route.prefix )
               and ( current_routes[route.prefix].via == route.via )
               and ( current_routes[route.prefix].active == route.active ) ) then
        route.name = current_routes[route.prefix].name
        return fb.route.ipv6.set(fbhandle, route.prefix, route.via, route.active, route.name)
      else
        return true
      end
    else
      return fb.route.ipv6.add(fbhandle, route.prefix, route.via, route.active)
    end
  else 
    pstderr("E: fb.route.add - AF not supported, yet")
    dump(route)
  end
end

function table.len(t)
  local l=0
  for k, _ in pairs(t) do
    l = l + 1
  end
  return l 
end

function fb.route.delete(fbhandle, name, via)
  if fb.verbose then
    pstderr(string.format("I: fb.route.delete(%s, %s)", name, via or ""))
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
    pstderr("E: fb.route.del - address family not supported, yet")
    dump({ name = name, via = via})
  end
end

-- Lists routes, routes are in .data.staticRoutes.route
function fb.route.ipv4.list(fbhandle)
  if fb.verbose then
    pstderr("I: fb.route.ipv4.list()")
  end
  return fb_POST_json_data_lua(fbhandle, "static_route_table")
end

function fb.route.ipv6.list(fbhandle)
  if fb.verbose then
    pstderr("I: fb.route.ipv6.list()")
  end
  return fb_POST_json_data_lua(fbhandle, "static_IPv6_route_table")
end

-- Adds and update routes, does not check for existing routes with same prefix
function fb.route.ipv4.set(fbhandle, prefix, via, active, name)
  local active = (active or 1)
  local name = (name or "")

  if fb.verbose then
    pstderr(string.format("I: fb.route.ipv4.set(%s, %s, %s, %s)", prefix, via, active, name))
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
    pstderr(string.format("I: fb.route.ipv6.set(%s, %s, %s, %s)", prefix, via, active, name))
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
    pstderr(string.format("I: fb.route.ipv4.delete(%s, %s)", name, via or ""))
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
    repeat
      current_routes = fb.route.list(fbhandle)
      current_routes = fb.route.list_filter(current_routes, { prefix = name })
      local l = table.len(current_routes)
      if l > 0 then
        if current_routes[prefix] then
          rs = fb.route.ipv4.delete(fbhandle, current_routes[prefix].name)
        end
      end
    until l == 0
    return (rs or true)
  end
end

-- Removes a IPv6 route - 
--  - "name" can be "prefix" or "route name"
function fb.route.ipv6.delete(fbhandle, name, via) 
  if fb.verbose then
    pstderr(string.format("I: fb.route.ipv6.delete(%s, %s)", name, via or ""))
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
    repeat
      current_routes = fb.route.list(fbhandle)
      current_routes = fb.route.list_filter(current_routes, { prefix = name })
      local l = table.len(current_routes)
      if l > 0 then
        if current_routes[prefix] then
          rs = fb.route.ipv6.delete(fbhandle, current_routes[prefix].name)
        end
      end
    until l == 0
    return (rs or true)
  end
end

return fb

-- vim: ts=2 et sw=2 fdm=indent ft=lua fml=1
