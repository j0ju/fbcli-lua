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
      return nil, { exitcode = 1, errmsg = string.format("cannot sort for coloumn '%s'.", opts.sort) }
    end
  end

  local r, err = FB.host.list(FBhandle)
  DieOnErr(err)

  local hostlist = {}
  local online
  for _, v in pairs({"active", "passive", "fbox"}) do
    for _, h in pairs(r.data[v]) do
      online = "no"
      if h.model == "active" then
        online = "yes"
      elseif h.model == "fbox" then
        online = "yes"
      end
      local n = {
        name = h.name,
        mac = h.mac,
        ipv4 = h.ipv4.ip or "(UNKNOWN)",
        dhcp = h.ipv4.dhcp or "(UNKNOWN)",
        online = online,
        port = h.port,
        internal_name = h.UID,
        last_used = ( ipv4 or { lastused = -1 } ).lastused,
      }
      table.add(hostlist, n)
    end
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

function host.delete(argv, i)
  local opts = {
    name = argv[i] or "",
  }
  CLI.parse_into_table(opts, argv, i)
  if opts.name == "" then
    return nil, { exitcode = 1, errmsg = "no hostname to delete given" }
  end

  local r, err = FB.host.list(FBhandle)
  DieOnErr(err)

  -- only passive/offline devices can be deleted
  local deleted_host = 0
  for _, h in pairs(r.data.passive) do
    if opts.name == h.name then
      r, err = FB.host.delete(FBhandle, h.UID, h.name)
      if err then
        return nil, { exitcode = 1, errmsg = string.format("error deleting host %s", h.name) }
      end
      print(string.format("I: deleted host %s", h.name))
      deleted_host = deleted_host + 1
    end
  end
  if deleted_host == 0 then
    return nil, { exitcode = 1, errmsg = "no hosts deleted" }
  else
    print(string.format("I: deleted %d hosts", deleted_host))
  end

  return nil, nil
end
host.remove = host.delete
host.rm = host.delete

-- # debugging aid
function host.dump(argv, i) -- dump return of fritzbox unmodified
  local opts = {
    name = argv[i] or "",
  }
  CLI.parse_into_table(opts, argv, i)

  local r, err = FB.host.list(FBhandle)
  --local r, err = FB.mesh.list(FBhandle)
  DieOnErr(err)
  if opts.name == "" then
    dump(r)
  else
    for _, v in pairs({"active", "passive", "fbox"}) do
      for _, h in pairs(r.data[v]) do
        if opts.name == h.name then
          dump(h)
        end
      end
    end
  end

  return r, err
end

return host

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
