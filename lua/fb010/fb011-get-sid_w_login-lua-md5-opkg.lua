#!/usr/bin/env lua

-- http://lua-users.org/wiki/DataDumper
require "./dump"

-- http://lua-users.org/wiki/LuaXml
require "./simplexml"

local md5 = require "md5"

-- Config
fb_url = "http://fritz.box"
fb_user = "root"
fb_pw = "(uFqe[Wg\6b\mUA[g}*0auiB].=]vqdb"

-- Code
local io = require("io")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Fetch login page
resp = {}
b, code, resp_h, s = http.request{
  url = fb_url .. "/login_sid.lua",
  method = "GET",
  sink = ltn12.sink.table(resp)
}
print("-- Fetch challege via login page")
print("HTTP Status", code)


-- XML parse
x = sxml_tree(table.concat(resp))
--dump(x)
t = sxml_find_element(x, "Challenge")
--dump(t)
challenge = t[1]
print("Challenge", challenge)
print()

response_8bit = challenge .. '-' .. fb_pw
response_16bit = "" 
for i = 1, #response_8bit do
  response_16bit = response_16bit .. response_8bit:sub(i,i) .. string.char(0)
end
response_hashed = md5.sumhexa(response_16bit)

print("'".. response_8bit .."'")
print("'".. response_hashed .."'")

post_data = "response=".. challenge .. "-" .. response_hashed .. "&username=" .. fb_user
print("'".. post_data .."'")

resp = {}
local b, code, resp_h, status = http.request {
  url = fb_url .. "/login_sid.lua",
  method = "POST",
  source = ltn12.source.string(post_data),
  headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
    ["Content-Length"] = #post_data
  },
  sink = ltn12.sink.table(resp)
}
print("-- Fetch SID via login page")
print("HTTP Status", code)

x = sxml_tree(table.concat(resp))
dump(x)

-- RESPONSE="$CHALLANGE-$(echo -n "$CHALLANGE-$PASSWORD" | _utf8_to_utf16le | _md5sum )"
-- 
-- SID="$(
--   curl -s --data "response=$RESPONSE&username=$USER" "$FB_URL/login_sid.lua" | \
--   sed -r -e 's@</[^>]+>@\n@g' -e 's@<[^>]+>@\n\0@g' | \
--   sed -n -r -e "s/^<SID>// p"
-- )"
-- 
-- exec curl -s --output "$OUTPUT" "$FB_URL"/nas/cgi-bin/luacgi_notimeout --data "sid=$SID&script=/api/data.lua&c=files&a=get&path=$FILE"
