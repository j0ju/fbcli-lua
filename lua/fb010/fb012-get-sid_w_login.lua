#!/usr/bin/env lua

-- http://lua-users.org/wiki/DataDumper
require "./dump"

-- http://lua-users.org/wiki/LuaXml
require "./simplexml"

local md5 = require "md5"

-- Config
local fb_url = "http://fritz.box"
local fb_user = "root"
local fb_pw = "(uFqe[Wg\\6b\\mUA[g}*0auiB].=]vqdb"

-- Code
local io = require("io")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Fetch login page
local resp = {}
local b, code, resp_h, s = http.request{
  url = fb_url .. "/login_sid.lua",
  method = "GET",
  sink = ltn12.sink.table(resp)
}
print("-- Fetch challege via login page")
print("HTTP Status", code)


-- XML parse
local x = sxml_tree(table.concat(resp))
--dump(x)
local t = sxml_find_element(x, "Challenge")
--dump(t)
challenge = t[1]
print("Challenge", challenge)
print()

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

local fb_r = fb_response(challenge, fb_pw)

post_data = "response=".. fb_r .. "&username=" .. fb_user
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
