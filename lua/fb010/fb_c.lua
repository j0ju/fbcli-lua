#!/usr/bin/env lua

argv = {...}

local md5 = require "md5"

function fb_response(ch, pw)
  local pre = ch .. "-" .. pw
  local n = ""
  local i = 0
  for i = 1, #pre do
    n = n .. pre:sub(i,i) .. string.char(0)
  end
  local resp = ch .. "-" .. md5.sumhexa(n)
  return resp
end


local ch    = argv[1]
local fb_pw = "(uFqe[WgbmUA[g}*0auiB].=]vqdb"

print(fb_response(ch, fb_pw))
