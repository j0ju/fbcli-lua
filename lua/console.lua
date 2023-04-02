#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

function console_table_dump(t, display_opts)
  -- set default format if not specified
  -- calculate max length per coloumn
  local order = 1
  local heading = {}
  for f, opt in pairs(display_opts) do repeat
    if type(f) == "number" then
	  break
	end

    if opt.format == nil then
	  opt.format = "s"
	end
    if opt.heading == nil then
	  opt.heading = string.upper(f)
	end
    if opt.len == nil then
	  opt.len = #opt.heading
	end
	if display_opts[order] == nil then
	  display_opts[order] = f
	  order = order+1
	end
	for k, v in pairs(t) do
      if #(v[f] or "(nil)") > opt.len then
	    opt.len = #(v[f] or "(nil)")
	  end
	end
  	heading[f] = opt.heading
  until true end
  -- table heading as element #0
  t[0] = heading
  
  local i=0
  while t[i] do
    order = 1
    while display_opts[order] do
	  f = display_opts[order]
	  opt = display_opts[f]
	  if opt._fmt == nil then
	  	opt._fmt = " %".. opt.len .. opt.format
	  end
  	  io.write(string.format(opt._fmt, t[i][f]))
	  order=order+1
    end
    io.write('\n')
	i=i+1
  end
end

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua fml=1
