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
  local _, err = CLI.parse_into_table(opts, argv, i)
  DieOnErr(err)

  local table_display_opts = {
    name = { prefix = "-"},
    mac = {},
    ipv4 = {},
    port = {},
    online = {},
    -- display order, left to right
    "name", "ipv4", "mac", "online", "port",
  }

  if (opts.sort == "") then
    opts.sort = "ipv4"
  else
    local columns = {}
    for _, c in ipairs(table_display_opts) do table.add(columns, c) end
    local column, err = CLI.match(columns, opts.sort)
    DieOnErr(err)
    if column == nil then
      return nil, { exitcode = 1, errmsg = string.format("cannot sort for coloumn '%s'.", opts.sort) }
    end
    opts.sort = column
  end

  local r, err = FB.host.list(FBhandle)
  DieOnErr(err)

  local hostlist = {}
  local online
  for _, v in pairs({"active", "passive", "fbox"}) do repeat
    if v == "passive" and not opts.passive then break end
    if not (v == "passive") and not opts.active then break end
    for _, h in pairs(r.data[v] or {}) do repeat
      local port = h.port or ""
      if port:find("^WLAN") and not opts.wifi then break end
      if port:find("^LAN") and not opts.ethernet then break end
      online = "no"
      if h.model == "active" then
        online = "yes"
      elseif h.model == "fbox" then
        online = "yes"
      end
      local ipv4 = h.ipv4 or {}
      local n = {
        name = h.name or "",
        mac = h.mac or "",
        ipv4 = ipv4.ip or "(UNKNOWN)",
        dhcp = ipv4.dhcp or "(UNKNOWN)",
        online = online,
        port = port,
        internal_name = h.UID,
        last_used = ipv4.lastused or -1,
      }
      table.add(hostlist, n)
    until true end
  until true end

  if opts.sort == "name" then
    table.sort(hostlist, function (a, b) return a.name < b.name end )
  elseif opts.sort == "mac" then
    table.sort(hostlist, function (a, b) return a.mac < b.mac end )
  elseif opts.sort == "port" then
    table.sort(hostlist, function (a, b) return a.port < b.port end )
  elseif opts.sort == "online" then
    table.sort(hostlist, function (a, b) return a.online < b.online end )
  elseif opts.sort == "ipv4" then
    table.sort(hostlist, function (a, b) return IP.lesser_than(a.ipv4, b.ipv4) end)
  end

  console_table_dump(hostlist, table_display_opts)
  return r, err
end
host.show = host.list

function host.delete(argv, i)
  local opts = {
    name = argv[i] or "",
  }
  local _, err = CLI.parse_into_table(opts, argv, i)
  DieOnErr(err)
  if opts.name == "" then
    return nil, { exitcode = 1, errmsg = "no hostname to delete given" }
  end

  local r, err = FB.host.list(FBhandle)
  DieOnErr(err)

  -- only passive/offline devices can be deleted
  local deleted_host = 0
  for _, h in pairs(r.data.passive or {}) do
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

-- Helper:
--   finds exactly one host by name, MAC or IPv4 address in the host list
local host_find = function(r, name)
  local found = {}
  for _, v in pairs({"active", "passive", "fbox"}) do
    for _, h in pairs(r.data[v] or {}) do
      if h.name == name or (h.mac or ""):upper() == name:upper() or (h.ipv4 or {}).ip == name then
        table.add(found, h)
      end
    end
  end
  if #found == 0 then
    return nil, { exitcode = 1, errmsg = string.format("no host '%s' found", name) }
  elseif #found > 1 then
    return nil, { exitcode = 1, errmsg = string.format("host name '%s' is ambiguous (%d hosts), use MAC or IP address", name, #found) }
  end
  return found[1], nil
end

-- access profiles, by names in the web interface (german, english), with the
-- IDs of the built-in profiles as fallback
local filter_profiles = {
  allow = { names = { "Unbeschränkt", "Unrestricted" }, id = "filtprof3" },
  reset = { names = { "Standard" }, id = "filtprof1" },
  disallow = { names = { "Gesperrt", "Blocked" } },
}

-- Helper:
--   returns the value of a profile by name, or the fallback id if present
local profile_find = function(profiles, p)
  for _, n in ipairs(p.names) do
    for _, item in ipairs(profiles.list or {}) do
      if item.text == n then
        return item.value
      end
    end
  end
  for _, item in ipairs(profiles.list or {}) do
    if item.value == p.id then
      return item.value
    end
  end
  return nil
end

-- Helper:
--   name of a profile by value
local profile_name = function(profiles, value)
  for _, item in ipairs(profiles.list or {}) do
    if item.value == value then
      return item.text
    end
  end
  return value
end

-- Helper:
--   parental control user of a host, holds the device lock; nil if the
--   FritzBox has no REST API (older FRITZ!OS) or no user for this host.
--   Other errors are fatal, the device lock would be unknown.
local host_user = function(uid)
  local user, err = FB.host.user(FBhandle, uid)
  if err and not (err.code == 404 or err.nouser) then
    DieOnErr({ exitcode = 1, errmsg = "cannot read the device lock of the parental control (REST API): " .. err.errmsg })
  end
  return user
end

-- host <host> filter [allow|disallow|reset|show]
--   allow    - access profile "Unbeschränkt"
--   disallow - access profile "Gesperrt", newer FRITZ!OS versions have no such
--              profile, internet usage of the host is blocked instead
--   reset    - access profile "Standard", unblocks internet usage
function host.filter(argv, i)
  local name = argv[i] or ""
  if name == "" then
    return nil, { exitcode = 1, errmsg = "no host given" }
  end
  local op, err = CLI.match({ "allow", "disallow", "reset", "show" }, argv[i+2] or "show")
  DieOnErr(err)
  if op == nil then
    return nil, { exitcode = 1, errmsg = string.format("unknown filter action '%s', use allow, disallow, reset or show", argv[i+2]) }
  end

  local r, err = FB.host.list(FBhandle)
  DieOnErr(err)
  local h, err = host_find(r, name)
  DieOnErr(err)

  local settings, err = FB.host.get(FBhandle, h.UID)
  DieOnErr(err)
  local vars = settings.data.vars
  local profiles = (((vars.dev.netAccess or {}).kisi or {}).profiles) or {}

  -- the device lock is only in the REST API of newer FRITZ!OS versions
  local user = host_user(h.UID)

  if op == "show" then
    print(string.format("%s profile %s internet %s", h.name, profile_name(profiles, profiles.selected), FB.host.internet(vars, user)))
    return nil, nil
  end

  local form, err = FB.host.form(vars)
  DieOnErr(err)

  -- leave a blocked host, keep "prioritised"
  if form.internetdetail == "blocked" then
    if vars.dev.realtime and vars.dev.realtime.state then
      form.internetdetail = "realtime"
    else
      form.internetdetail = "unlimited"
    end
  end

  local profile = profile_find(profiles, filter_profiles[op])
  if profile then
    form.kisi_profile = profile
  elseif op == "disallow" then
    form.internetdetail = "blocked"
  else
    return nil, { exitcode = 1, errmsg = string.format("no access profile '%s' found", filter_profiles[op].names[1]) }
  end

  local _, err = FB.host.set(FBhandle, h.UID, form)
  DieOnErr(err)

  if form.internetdetail == "blocked" then
    print(string.format("I: host %s: internet usage blocked", h.name))
    return nil, nil
  end

  -- the device lock of the parental control list is not lifted by the
  -- edit device page, check and unlock
  settings, err = FB.host.get(FBhandle, h.UID)
  DieOnErr(err)
  user = host_user(h.UID)
  if FB.host.internet(settings.data.vars, user) == "blocked" then
    if user then
      local _, err = FB.host.lock(FBhandle, h.UID, false)
      DieOnErr(err)
      settings, err = FB.host.get(FBhandle, h.UID)
      DieOnErr(err)
      user = host_user(h.UID)
    end
    if FB.host.internet(settings.data.vars, user) == "blocked" then
      return nil, { exitcode = 1, errmsg = string.format("host %s: profile set, but its internet access is still blocked", h.name) }
    end
    print(string.format("I: host %s: unblocked", h.name))
  end
  print(string.format("I: host %s: profile %s", h.name, profile_name(profiles, form.kisi_profile)))
  return nil, nil
end

-- "host <host> filter ..." is not an action, everything else lists hosts,
-- options of "host list" win (eg. "host wifi f" is "host list wifi false")
local host_list_options = { "active", "passive", "wifi", "ethernet", "sort" }
function host.DEFAULT(argv, i)
  local opt, opt_err = CLI.match(host_list_options, argv[i])
  if opt == nil and opt_err == nil and argv[i+1] and CLI.match({ "filter" }, argv[i+1]) then
    return host.filter(argv, i)
  end
  return host.list(argv, i)
end

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
      for _, h in pairs(r.data[v] or {}) do
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
