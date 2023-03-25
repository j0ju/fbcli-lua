#!/usr/bin/env lua

-- http://lua-users.org/wiki/DataDumper
require "./dump"

-- http://lua-users.org/wiki/LuaXml
require "./simplexml"

-- Config
fb_url = "http://fritz.box"
fb_user = "root"
fb_pw = "(uFqe[Wg\6b\mUA[g}*0auiB].=]vqdb"

-- Code
io = require("io")
http = require("socket.http")
ltn12 = require("ltn12")

resp = {}
b, st, resp_h, s = http.request{
  url = fb_url .. "/login_sid.lua",
  method = "GET",
  sink = ltn12.sink.table(resp)
}


print("HTTP Status", st)
print(s)

print("HTTP Response")
s = ""
for k,v in pairs(resp) do
  s = s .. v
end
print(s)
x = sxml_tree(s)

dump(x)
t = sxml_find_element(x, "Challenge")
dump(t)
dump(t[1])
