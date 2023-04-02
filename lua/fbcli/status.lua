#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local status = {}

function status.show(argv, i)
  local r, err = FB.status(FBhandle)
  die_on_err(err)

  -- do not display, erase DSL stats for now
  --r.data.sync_groups = nil
  --dump(r)
  dump(r.data.connections)
  return r, err
end
status.DEFAULT = status.show

return status


-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
