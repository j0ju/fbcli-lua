io = require("io")
http = require("socket.http")
ltn12 = require("ltn12")

resp = {}

b, st, resp_h, s = http.request{
  url = "http://fritz.box/login_sid.lua",
  method = "GET",
  sink = ltn12.sink.table(resp)
}

print(resp)
print(st)
print(resp_h)
print(s)

for k,v in pairs(resp) do
  print(k,v)
end

