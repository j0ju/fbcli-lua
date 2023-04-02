#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local ipaddr = {}
local bit = require("bit")

-- convert cidr to netmask
local cidr2netmask_map = { [0] = 0, [1] = 128, [2] = 192, [3] = 224, [4] = 240, [5] = 248, [6] = 252, [7] = 254, }
function ipaddr.cidr2netmask(cidr)
  local netmask=""
  local cidr = tonumber(cidr)
  for i = 4,1,-1 do
    if 8 <= cidr then
      netmask = netmask .. "255"
      cidr = cidr - 8
    else
      netmask = netmask .. cidr2netmask_map[cidr]
      cidr = 0
    end
    if i > 1 then
      netmask = netmask .. "."
    end
  end
  return netmask
end

local netmask2cidr_map = { [0] = 0, [128] = 1, [192] = 2, [224] = 3, [240] = 4, [248] = 5, [252] = 6, [254] = 7, [255] = 8, }
function ipaddr.netmask2cidr(netmask)
  local cidr=0
  local i, _ , nm1, nm2, nm3, nm4 = netmask:find('(%d+).(%d+).(%d+).(%d+)')
  if not i then
    return -1
  end

  cidr = cidr + netmask2cidr_map[tonumber(nm1)]
  cidr = cidr + netmask2cidr_map[tonumber(nm2)]
  cidr = cidr + netmask2cidr_map[tonumber(nm3)]
  cidr = cidr + netmask2cidr_map[tonumber(nm4)]
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

local octet_from_string = function(inp)
  local octet = {}
  local i, outp

  i, _, outp, octet.cidr = inp:find('^(.+)/(%d+)$')
  if not i then
    outp = inp
  end

  i, _, octet[1], octet[2], octet[3], octet[4] = outp:find('(%d+).(%d+).(%d+).(%d+)')
  if i then
    return octet
  end
  return nil
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

local cidr2netmask_v6_map = {
  [0] = 0, [1] = 32768, [2] = 49152, [3] = 57344, [4] = 61440, [5] = 63488, [6] = 64512, [7] = 65024,
  [8] = 65280, [9] = 65408, [10] = 65472, [11] = 65504, [12] = 65520, [13] = 65528, [14] = 65532, [15] = 65534,
}
function ipaddr.contains(net, ip)
  if type(net) == "table" then
    for _, n in pairs(net) do
      if ipaddr.contains(n, ip) then
        return true
      end
    end
    return false
  end

  if type(ip) == "table" then
    for _, i in pairs(ip) do
      if ipaddr.contains(net, i) then
        return true
      end
    end
    return false
  end

  local net_t, net_a, net_cidr = ipaddr.type(net)
  local ip_t, ip_a, ip_cidr = ipaddr.type(ip)

  -- two different address families will not match
  net_t = net_t:sub(1,4)
  if not (net_t == ip_t:sub(1,4)) then
    return false
  end

  if net_t == "ipv4" then
    local net_octet = octet_from_string(net_a)
    if net_octet == nil then return false end

    local netmask_octet = octet_from_string(ipaddr.cidr2netmask(net_cidr))
    if netmask_octet == nil then return false end

    local ip_octet = octet_from_string(ip_a)
    if ip_octet == nil then return false end

    for i = 1,4 do
      if tonumber(netmask_octet[i]) == 0 then
        break
      end
      if not (bit.band(ip_octet[i], netmask_octet[i]) == tonumber(net_octet[i])) then
        return false
      end
    end
  elseif net_t == "ipv6" then
    local net_doctet = doctet_from_string(net_a)
    if net_doctet == nil then return false end

    local ip_doctet = doctet_from_string(ip_a)
    if ip_doctet == nil then return false end

    local mask_cidr = tonumber(net_cidr), mask
    for i = 1,8 do
      if mask_cidr > 15 then
        mask = 65535
        mask_cidr = mask_cidr - 16
      elseif mask_cidr == 0 then
        break
      else
        mask = cidr2netmask_v6_map[mask_cidr]
        mask_cidr = 0
      end
      if not (bit.band(ip_doctet[i], mask) == net_doctet[i]) then
        return false
      end
    end
  else
    -- unknown address family
    return nil
  end
  return true
end

function ipaddr.lesser_than(a, b) -- numerical compare a < b
  local a = { address = a }
  local b = { address = b }
  local max_octets
  a.type, a.address, a.cidr = ipaddr.type(a.address)
  b.type, b.address, b.cidr = ipaddr.type(b.address)
  
  a.type = a.type:sub(1,4)
  if not (a.type == b.type:sub(1,4)) then
    return false
  end
  if a.type == "ipv4" then
    a.octet = octet_from_string(a.address)
    b.octet = octet_from_string(b.address)
    max_octets = 4
  elseif a.type == "ipv6" then
    a.octet = doctet_from_string(a.address)
    b.octet = doctet_from_string(b.address)
    max_octets = 8
  end
  for i = 1, max_octets do
    if tonumber(a.octet[i]) < tonumber(b.octet[i]) then
      return true
    end
  end
  return false

end

return ipaddr

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
