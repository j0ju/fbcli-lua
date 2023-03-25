#!/usr/bin/env lua

local ipaddr = {}

-- convert cidr to netmask
function ipaddr.cidr2netmask(cidr)
  local netmask=""
  local cidr = tonumber(cidr)
  for i = 4,1,-1 do
    if 8 <= cidr then
      netmask = netmask .. "255"
      cidr = cidr - 8
    else
      local map = { [0] = 0, [1] = 128, [2] = 192, [3] = 224, [4] = 240, [5] = 248, [6] = 252, [7] = 254, }
      netmask = netmask .. map[cidr]
      cidr = 0
    end
    if i > 1 then
      netmask = netmask .. "."
    end
  end
  return netmask
end

function ipaddr.netmask2cidr(netmask)
  local cidr=0
  local map = { [0] = 0, [128] = 1, [192] = 2, [224] = 3, [240] = 4, [248] = 5, [252] = 6, [254] = 7, [255] = 8, }
  local i, _ , nm1, nm2, nm3, nm4 = netmask:find('(%d+).(%d+).(%d+).(%d+)')
  if not i then
    return -1
  end

  cidr = cidr + map[tonumber(nm1)]
  cidr = cidr + map[tonumber(nm2)]
  cidr = cidr + map[tonumber(nm3)]
  cidr = cidr + map[tonumber(nm4)]
  return cidr
end

function ipaddr.address(str)
  local t, a, p = ipaddr.type(str)
  if t:find("^ipv[46]") then
    return a
  end
  return nil
end

function ipaddr.prefix(str)
  local t, a, p = ipaddr.type(str)
  if t:find("^ipv4") then
    p = p or "32"
    return a .. "/" .. p
  elseif t:find("^ipv6") then
    p = p or "128"
    return a .. "/" .. p
  end
  return nil
end

function ipaddr.cidr(str)
  local t, a, p = ipaddr.type(str)
  if t:find("^ipv4") then
    return p or "32"
  elseif t:find("^ipv6") then
    return p or "128"
  end
  return nil
end

function ipaddr.type(str)
  local i, _, addr = (str or ""):find('^(%d+[.]%d+[.]%d+[.]%d+)$')
  if i then
    return "ipv4", addr, "32"
  end
  local i, _, addr, pfx = (str or ""):find('^(%d+[.]%d+[.]%d+[.]%d+)/(%d+)$')
  if i then
    return "ipv4+cidr", addr, pfx
  end
  i, _, addr, pfx = (str or ""):find('^(%d+[.]%d+[.]%d+[.]%d+)/(%d+[.]%d+[.]%d+[.]%d+)$')
  if i then
    pfx = ipaddr.netmask2cidr(pfx)
    return "ipv4+prefix", addr, pfx
  end
  return type(str)
end

return ipaddr

-- vim: ts=2 et sw=2 fdm=indent ft=lua
