#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local host = {}

function host.list(argv, i)
  local opts = {
    active = true,
    passive = true,
    wifi = true,
    ethernet = true,
    sort = "",
  }
  CLI.parse_into_table(opts, argv, i)

  local table_display_opts = {
    name = { prefix = "-"},
    mac = {},
    ipv4 = {},
    port = {},
    online = {},
    -- display order, left to right
    "name", "ipv4", "mac", "online", "port",
  }

  if (not (opts.sort == "")) then
    if table_display_opts[opts.sort] == nil then
      return nil, {
        exitcode = 1,
        errmsg = string.format("cannot sort for coloumn '%s'.", opts.sort),
      }
    end
  end

  local r, err = FB.host.list(FBhandle)
  die_on_err(err)

  local hostlist = {}, online
  for _, v in pairs({"active", "passive"}) do
    for _, h in pairs(r.data[v]) do repeat
      --dump(h)
      online = "no"
      if v == "active" then
        if not opts.active then
          break
        end
        online = "yes"
      else
        if not opts.passive then
          break
        end
      end
      n = {
        name = h.name,
        mac = h.mac,
        ipv4 = h.ipv4.ip or "(UNKNOWN)",
        dhcp = h.ipv4.dhcp or "(UNKNOWN)",
        online = online,
        port = h.port,
      }
      table.add(hostlist, n)

    until true end
  end

  if opts.sort == "name" then
    table.sort(hostlist, function (a, b) return a.name < b.name end )
  elseif opts.sort == "mac" then
    table.sort(hostlist, function (a, b) return a.mac < b.mac end )
  elseif opts.sort == "port" then
    table.sort(hostlist, function (a, b) return a.port < b.port end )
  elseif opts.sort == "ipv4" then
    table.sort(hostlist, function (a, b) return IP.lesser_than(a.ipv4, b.ipv4) end)
  end

  console_table_dump(hostlist, table_display_opts) 
  return r, err
end
host.DEFAULT = host.list
host.show = host.list

function host.dump() -- dump return of fritzbox unmodified
  local r, err = FB.host.list(FBhandle)
  die_on_err(err)
  dump(r)
  return r, err
end

return host

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
