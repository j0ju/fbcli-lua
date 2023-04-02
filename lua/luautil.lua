#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

-- extra help that counts ALL elements in a table
-- -- CPU expensive O(n)!
function table.size(t)
  local l=0
  for k, _ in pairs(t) do
    l = l + 1
  end
  return l
end

table.add = table.insert
table.rm = table.remove

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua fml=1
