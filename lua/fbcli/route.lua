#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local route = {}

local route_sort = function(a,b)
  local a = a
  local b = b
  if a == nil then
    a = { prefix = "0.0.0.0" }
  elseif b == nil then
    b = { prefix = "0.0.0.0" }
  end
  return IP.lesser_than(a.prefix, b.prefix)
end

function route.show()
  local routes, err = FB.route.list(FBhandle)
  if err then
    pstderr(string.format("E: %s route show: %s ", arg[0], err.errmsg))
    os.exit(1)
  else
    table.sort(routes, route_sort)
    local i = 1, r
    while routes[i] do
      r = routes[i]
      print(string.format("%s via %s name %s active %s", r.prefix, r.via, r.name, r.active))
      i = i + 1
    end
  end
end
route.DEFAULT = route.show
route.list = route.show

function route.add(argv, i)
  local r = {
    prefix = argv[i] or "",
    via = "",
    name = "",
    active = "1",
  }
  CLI.parse_into_table(r, argv, i)

  local rs, err = FB.route.add(FBhandle, r)
  return rs, err
end
route.replace = route.add

function route.delete(argv, i)
  local r = {
    prefix = argv[i] or "",
    via = "",
    name = "",
    active = "",
  }
  CLI.parse_into_table(r, argv, i)
  if r.name == "" then r.name = nil end
  local rs, err = FB.route.delete(FBhandle, r.name or r.prefix, r.via)
  return rs, err
end

function route.flush(argv, i)
  repeat
    local routes, rs, err = FB.route.list(FBhandle)
    die_on_err(err)

    local v=nil
    for pfx, r in pairs(routes) do
      local type = IP.type(pfx)
      if type:match("^ipv[46]") then
        print("I: removing route for " .. pfx .. " by name " .. r.name)
        rs, err = FB.route.delete(FBhandle, r.name)
        v = r
        die_on_err(err)
        break
      end
    end
  until v==nil
  return nil, nil
end

return route

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
