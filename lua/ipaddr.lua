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

-- helper: tries to parse a string into a table only containing octets + cidr
--   in:  string
--   out: {[1..8]=, cidr=}
--        or nil on error
local doctet_from_string = function(inp)
  local inp = inp
  local doctet = {}, o

  local i, _, outp, cidr = inp:find('^(.+)/(%d+)$')
  if not i then outp = inp end

  -- start parsing from the beginning
  o = 1
  while not (outp == "") do
    if o > 8 then
      return nil
    end
    inp = outp
    i, _, token, outp = inp:find('^(%x%x?%x?%x?):(.*)$')
    --print(o, i, token, outp)
    if i then
      doctet[o] = tonumber(token, 16)
      o = o + 1
    else
      outp = inp
      break
    end
  end

  -- either we encountered an error or :: because of zero compression
  -- continue parsing from the end of the address
  -- if we find colliding doctet indexes, we have a faulty address
  o = 8
  while not (outp == "") do
    inp = outp
    i, _, outp, token = inp:find('^(.+):(%x%x?%x?%x?)$')
    --print(o, i, token, outp)
    if i then
      if doctet[o] == nil then
        doctet[o] = tonumber(token, 16)
      else
        return nil
      end
      o = o - 1
    else
      outp = inp
      break
    end
  end

  if outp == ":" then
    -- we came here by parsing from the end of the input
    -- ":" this is fine, zero compression
  elseif not (outp == "") then
    -- we came here by parsing from the beginning
    i, _, token = outp:find('^:?(%x%x?%x?%x?)$')
    --print(o, i, token, outp)
    if i then
      if doctet[o] == nil then
        doctet[o] = tonumber(token, 16)
      else
        return nil
      end
    else
      return nil
    end
  end

  for o = 1, 8 do
    if doctet[o] == nil then
      doctet[o] = "0"
    end
  end
  doctet.cidr = cidr
  return doctet
end

local doctet_expandv6 = function(doctet)
  local str = ""
  for o = 1,8 do
    if not (str == "")  then
      str = str .. ":"
    end
    str = str .. string.format("%x", doctet[o])
  end
  return str
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
    return "ipv4+cidr", addr, pfx
  end

  local doctet = doctet_from_string(str)
  if doctet then
    addr = doctet_expandv6(doctet)
    if doctet.cidr then
      return "ipv6+cidr", addr, doctet.cidr
    else
      return "ipv6", addr, "128"
    end
  end

  return type(str)
end

return ipaddr

-- vim: ts=2 et sw=2 fdm=indent ft=lua
