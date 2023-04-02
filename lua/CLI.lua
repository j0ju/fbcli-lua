#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local CLI = {
  --verbose = true,
}
require "table"

-- helper: for selecting objects or actions from commandline out of an table
local CLI_select = function(table, opin)
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
  local obj = table
  local i = start
  local rs, err
  while argv[i] do
    obj = CLI_select(table, argv[i])
    if type(obj) == "table" then
      table = obj
    elseif type(obj) == "function" then
      rs, err = obj(argv, i+1)
      return rs, err
    elseif type(obj) == "nil" then
      break
    end
    i=i+1
  end
  if type(obj) == "table" then
    if obj["DEFAULT"] then
      rs, err = obj["DEFAULT"](argv, i)
      return rs, err
    end
  end
  local err = {
    errmsg = string.format("no CLI function implemented for ${%d} = '%s'", i, argv[i] or "(null)"),
    exitcode = 1
  }
  return nil, err
end

local toboolean_map = {
  ["yes"]     = true,
  [1]         = true,
  ["1"]       = true,
  ["true"]    = true,
  ["enable"]  = true,
  ["en"]      = true,
  --
  ["no"]      = false,
  [0]         = false,
  ["0"]       = false,
  ["true"]    = false,
  ["disable"] = false,
  ["dis"]     = false,
}
function toboolean(str)
  return toboolean_map[str]
end

-- iterates of "argv", beginning with element "start"
--
function CLI.parse_into_table(table, argv, start)
  if start == nil then start = 1 end
  local i = start
  while argv[i] do
    for k, v in pairs(table) do
      local m, _ = k:gsub('(.)', '%1?')
      m, _ = m:gsub('^(.)[?]', '%1')
      m = "^" .. m .. "$"
      if argv[i]:find(m) then
        local t=type(v)
        local val
        --print ("type: ", t)
        if t == "string" then
          if argv[i+1] == nil then
            -- expected a string
            local error = {
              errmsg = string.format("missing argument on position %d for '%s'.", i+1, k),
              exitcode = 1,
              position = i+1,
            }
            if CLI.verbose then pstderr(string.format("E: CLI.parse_into_table: %s", error.errmsg)) end
            return nil, error
          else
            table[k] = argv[i+1]
            i=i+1
          end
        elseif t == "number" then
          if argv[i+1] == nil then
            -- expected a string
            local error = {
              errmsg = string.format("missing argument on position %d for '%s'.", i+1, k),
              exitcode = 1,
              position = i+1,
            }
            if CLI.verbose then pstderr(string.format("E: CLI.parse_into_table: %s", error.errmsg)) end
            return nil, error
          else
            val = tonumber(argv[i+1])
            if val == nil then
              local error = {
                errmsg = string.format("expected number, got string '%s' for argument on position %d for '%s'.", argv[i+1], i+1, k),
                exitcode = 1,
                position = i+1,
              }
              if CLI.verbose then pstderr(string.format("E: CLI.parse_into_table: %s", error.errmsg)) end
              return nil, error
            end
            table[k] = tonumber(argv[i+1])
            i=i+1
          end
        elseif t == "boolean" then
          if argv[i+1] == nil then -- if specified without arguments as last argument: assume "true"
            val = true
          else
            val = toboolean(argv[i+1])
            if val == nil then -- assume "true", do not advance further i argument parsing
              val = true
            else
              i=i+1
            end
          end
          table[k] = val
        elseif t == "table" then
          if argv[i+1] == nil then
            -- expected a string
            local error = {
              errmsg = string.format("missing argument on position %d for '%s'.", i+1, k),
              exitcode = 1,
              position = i+1,
            }
            if CLI.verbose then pstderr(string.format("E: CLI.parse_into_table: %s", error.errmsg)) end
            return nil, error
          else
            table[k][#table[k]+1] = argv[i+1]
            i=i+1
          end
        end
        break
      end
    end
    i=i+1
  end
  return table, nil
end

function pstderr(str)
  io.stderr:write(str)
  io.stderr:write("\n")
end

function die_on_err(err)
  if err then
    pstderr(string.format("E: %s", err.errmsg ))
    os.exit(err.exitcode or 1)
  end
end

return CLI

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
