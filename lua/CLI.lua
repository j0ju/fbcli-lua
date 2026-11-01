#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local CLI = {
  --verbose = true,
}
require "table"

-- keys that are only selected by their full name, so they do not make
-- abbreviations ambiguous (eg. "h" is "host", not "help")
CLI.exact = { help = true }

-- helper: true if "abbrev" is an abbreviation of "key": same first character,
-- the remaining characters appear in "key" in the same order (eg. "lst" for "list")
local is_abbrev = function(abbrev, key)
  if abbrev == "" or not (abbrev:sub(1,1) == key:sub(1,1)) then
    return false
  end
  local pos = 2
  for c in abbrev:sub(2):gmatch(".") do
    pos = key:find(c, pos, true)
    if pos == nil then
      return false
    end
    pos = pos + 1
  end
  return true
end

-- selects "input" out of the list of names "keys"
--  * an exact match always wins
--  * otherwise "input" has to be an abbreviation of exactly one key
--  returns: key                - on a (unique) match
--           nil, nil           - if nothing matches
--           nil, err           - if "input" is ambiguous
function CLI.match(keys, input)
  if type(input) ~= "string" then
    return nil, nil
  end
  local matches = {}
  for _, k in ipairs(keys) do
    if k == input then
      return k, nil
    end
    if not CLI.exact[k] and is_abbrev(input, k) then
      table.insert(matches, k)
    end
  end
  if #matches == 1 then
    return matches[1], nil
  elseif #matches == 0 then
    return nil, nil
  end
  table.sort(matches)
  return nil, {
    errmsg = string.format("'%s' is ambiguous, could be: %s", input, table.concat(matches, ", ")),
    exitcode = 1,
  }
end

-- helper: names in a table usable on the command line, keys starting
-- with an uppercase letter (eg. DEFAULT) are internal
local CLI_keys = function(t)
  local keys = {}
  for k, _ in pairs(t) do
    if type(k) == "string" and not k:find("^%u") then
      table.insert(keys, k)
    end
  end
  return keys
end

-- helper: for selecting objects or actions from commandline out of an table
local CLI_select = function(t, opin)
  local k, err = CLI.match(CLI_keys(t), opin)
  if k then
    return t[k], nil
  end
  return nil, err
end

function CLI.action(table, argv, start)
  if start == nil then
    start = 1
  end
  local obj = table
  local i = start
  local rs
  local err
  while argv[i] do
    obj, err = CLI_select(table, argv[i])
    if err then
      return nil, err
    end
    if type(obj) == "table" then
      table = obj
    elseif type(obj) == "function" then
      rs, err = obj(argv, i+1)
      return rs, err
    elseif type(obj) == "nil" then
      -- no action matched, pass the rest as options to the DEFAULT action
      break
    end
    i=i+1
  end
  if table["DEFAULT"] then
    rs, err = table["DEFAULT"](argv, i)
    return rs, err
  end
  err = {
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
  ["false"]    = false,
  ["disable"] = false,
  ["dis"]     = false,
}
local toboolean = function(str)
  return toboolean_map[str]
end
-- boolean values that can be abbreviated, eg. "n" for "no"
local boolean_words = { "yes", "no", "true", "false", "enable", "disable" }

-- iterates of "argv", beginning with element "start"
--
function CLI.parse_into_table(table, argv, start)
  if start == nil then start = 1 end
  local i = start
  local keys = CLI_keys(table)
  while argv[i] do
    local k, err = CLI.match(keys, argv[i])
    if err then
      if CLI.verbose then PStdErr(string.format("E: CLI.parse_into_table: %s", err.errmsg)) end
      return nil, err
    end
    if k then
      local v = table[k]
      do
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
            if CLI.verbose then PStdErr(string.format("E: CLI.parse_into_table: %s", error.errmsg)) end
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
            if CLI.verbose then PStdErr(string.format("E: CLI.parse_into_table: %s", error.errmsg)) end
            return nil, error
          else
            val = tonumber(argv[i+1])
            if val == nil then
              local error = {
                errmsg = string.format("expected number, got string '%s' for argument on position %d for '%s'.", argv[i+1], i+1, k),
                exitcode = 1,
                position = i+1,
              }
              if CLI.verbose then PStdErr(string.format("E: CLI.parse_into_table: %s", error.errmsg)) end
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
            if val == nil then
              -- an abbreviated boolean, if it is not an option itself
              local word = CLI.match(boolean_words, argv[i+1])
              local opt, opt_err = CLI.match(keys, argv[i+1])
              if word and opt == nil and opt_err == nil then
                val = toboolean(word)
              end
            end
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
            if CLI.verbose then PStdErr(string.format("E: CLI.parse_into_table: %s", error.errmsg)) end
            return nil, error
          else
            table[k][#table[k]+1] = argv[i+1]
            i=i+1
          end
        end
      end
    end
    i=i+1
  end
  return table, nil
end

function CLI.example_action(argv, i)
  -- CLI Parse
  local args = {
    string = "string",
    bool = false,
    number = 5000,
    table = {},
    ip = ""
  }
  local _, err = CLI.parse_into_table(args, argv, i)
  DieOnErr(err)

  args.ip_type, args.ip_addr, args.ip_cidr = IP.type(args.ip)
  dump(args)
end

function PStdErr(str)
  io.stderr:write(str)
  io.stderr:write("\n")
end

function DieOnErr(err)
  if err then
    PStdErr(string.format("E: %s", err.errmsg ))
    os.exit(err.exitcode or 1)
  end
end

return CLI

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
