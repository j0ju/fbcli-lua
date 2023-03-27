#!/usr/bin/env lua5.1

local route = {}

function route.show()
  routes, err = FB.route.list(FBhandle)
  if err then
    pstderr(string.format("E: %s route show: %s ", arg[0], err.message))
    os.exit(1)
  else
    for pfx, r in pairs(routes) do
      if pfx:match("^.*/.*$") then
        print(string.format("%s via %s name %s active %s", pfx, r.via, r.name, r.active))
      end
    end
  end
end
route.DEFAULT = route.show
route.list = route.show

function route.add(argv, i)
  local r = {
    prefix = argv[i] or "",
    via = "",
    name = "",
    active = "1",
  }
  CLI.parse_into_table(r, argv, i)
  dump(
    FB.route.add(FBhandle, r)
  )
end
route.replace = route.add

function route.delete(argv, i)
  local r = {
    prefix = argv[i] or "",
    via = "",
    name = "",
    active = "",
  }
  CLI.parse_into_table(r, argv, i)
  if r.name == "" then r.name = nil end
  dump(
    FB.route.delete(FBhandle, r.name or r.prefix, r.via)
  )
end

return route

-- vim: ts=2 et sw=2 fdm=indent ft=lua
