#!/usr/bin/env lua

local ipaddr = {
}

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

return ipaddr

-- vim: ts=2 et sw=2 fdm=indent ft=lua
