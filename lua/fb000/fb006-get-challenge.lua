#!/usr/bin/env lua

require "./simplexml"
require "./dump"

-- Config
fb_url = "fritz.box"
fb_user = "root"
fb_pw = "(uFqe[Wg\6b\mUA[g}*0auiB].=]vqdb"

-- Code
io = require("io")
http = require("socket.http")
ltn12 = require("ltn12")

resp = {}
b, st, resp_h, s = http.request{
  url = "http://fritz.box/login_sid.lua",
  method = "GET",
  sink = ltn12.sink.table(resp)
}

print("HTTP Status", st)
print(s)

--# print("HTTP Response Headers")
--# for k,v in pairs(resp_h) do
--#   print("  ",k, ": ", v)
--# end

print("HTTP Response")
s = ""
for k,v in pairs(resp) do
  s = s .. v
end
print(s)
x = collect(s)
dump(x)
