#!/usr/bin/env lua

fb_url = "fritz.box"
fb_user = "root"
fb_pw = "(uFqe[Wg\6b\mUA[g}*0auiB].=]vqdb"

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
for k,v in pairs(resp) do
  print("  ",k, ": ", v)
  for i in string.gmatch(k, "<") do
    print(i)
  end
end

