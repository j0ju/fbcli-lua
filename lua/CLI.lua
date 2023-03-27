#!/usr/bin/env lua5.1

local CLI = {}
require "table"

-- helper: for selecting objects or actions from commandline out of an table
function CLI.select(table, opin)
  local op
  for k,_ in pairs(table) do
    local m, _ = k:gsub('(.)', '%1?')
    m, _ = m:gsub('^(.)[?]', '%1')
    m = "^" .. m .. "$"
    if (opin or "HELP"):find(m) then
      op=k
      break
    end
  end
  if table[op] then
    return table[op]
  else
    return nil
  end
end

function CLI.action(table, argv, start)  
  if start == nil then
    start = 1
  end
  local obj = nil
  local i = start
  while argv[i] do
    obj = CLI.select(table, argv[i])
    --print(i, argv[i], obj)
    if type(obj) == "table" then
      table = obj
    elseif type(obj) == "function" then
      return obj(argv, i+1)
    elseif type(obj) == "nil" then
      break
    end
    i=i+1
  end
  if type(obj) == "table" then
    if obj["DEFAULT"] then
      return obj["DEFAULT"]()
    end
  end
  print("E: no action helper found")
  return nil
end

function CLI.parse_into_table(table, argv, start)
  if start == nil then
    start = 1
  end
  local i = start
  while argv[i] do
    for k,_ in pairs(table) do
      local m, _ = k:gsub('(.)', '%1?')
      m, _ = m:gsub('^(.)[?]', '%1')
      m = "^" .. m .. "$"
      if argv[i]:find(m) then
        --print(argv[i], k, argv[i+1] or "")
        table[k] = (argv[i+1] or "")
        i=i+1
        break
      end
    end
    i=i+1
  end
end

function pstderr(str)
  io.stderr:write(str)
  io.stderr:write("\n")
end

return CLI

-- vim: ts=2 et sw=2 fdm=indent ft=lua
