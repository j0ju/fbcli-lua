#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local host = {}

function host.list(argv, i)
  local r, err = FB.host.list(FBhandle)
  for _, v in pairs({"active", "passive"}) do
  	for _, h in pairs(r.data[v]) do
	  dump(h)
	end
  end
  return r, err
end
host.DEFAULT = host.list

return host

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
