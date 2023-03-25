#!/usr/bin/env lua

local md5 = require "md5"

function md5_test(s)
  --print( "md5("..s..") = " .. md5.sumhexa(s))
  print(md5.sumhexa(s))
end

s="asdf"
s="1d8d3f9c-(uFqe[WgbmUA[g}*0auiB].=]vqdb"
md5_test(s)

n = ""
for i = 1, #s do
  n = n .. s:sub(i,i) .. string.char(0)
end
md5_test(n)
