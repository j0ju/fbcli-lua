#!/usr/bin/env lua5.1
-- taken and inspired by http://lua-users.org/wiki/LuaXml
-- LICENSE: Public Domain

local sxml = {}

local sxml_parseargs = function(s)
  local arg = {}
  string.gsub(s, "([%-%w]+)=([\"'])(.-)%2", function (w, _, a)
    arg[w] = a
  end)
  return arg
end

function sxml.parse(s)
  local stack = {}
  local top = {}
  table.insert(stack, top)
  local ni,c,label,xarg, empty
  local i = 1
  local j = 1
  while true do
    ni,j,c,label,xarg, empty = string.find(s, "<(%/?)([%w:]+)(.-)(%/?)>", i)
    if not ni then break end
    local text = string.sub(s, i, ni-1)
    if not string.find(text, "^%s*$") then
      table.insert(top, text)
    end
    if empty == "/" then  -- empty element tag
      table.insert(top, {label=label, xarg=sxml_parseargs(xarg), empty=1})
    elseif c == "" then   -- start tag
      top = {label=label, xarg=sxml_parseargs(xarg)}
      table.insert(stack, top)   -- new level
    else  -- end tag
      local toclose = table.remove(stack)  -- remove top
      top = stack[#stack]
      if #stack < 1 then
        error("nothing to close with "..label)
      end
      if toclose.label ~= label then
        error("trying to close "..toclose.label.." with "..label)
      end
      table.insert(top, toclose)
    end
    i = j+1
  end
  local text = string.sub(s, i)
  if not string.find(text, "^%s*$") then
    table.insert(stack[#stack], text)
  end
  if #stack > 1 then
    error("unclosed "..stack[#stack].label)
  end
  return stack[1]
end

function sxml.find_element(xmltree, name)
  if xmltree.label and xmltree.label == name then
    return xmltree
  end
  if xmltree == nil then
  elseif type(xmltree) == "string" then
  else
    for _, subtree in pairs(xmltree) do
      local rs = sxml.find_element(subtree, name)
      if rs then
        return rs
      end
    end
    return nil
  end
end

return sxml

-- vim: ts=2 et sw=2 fdm=indent ft=lua
