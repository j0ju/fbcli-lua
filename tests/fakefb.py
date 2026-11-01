#!/usr/bin/env python3
# LICENSE: GPL v2, see lua/LICENSE.txt
#
# Minimal fake FritzBox web interface for testing fbcli without a real box.
# Mimics /login_sid.lua and the /data.lua pages used by lua/fritzbox.lua,
# keeps state in memory and logs every request to stderr ("REQ ...").
#
# usage: fakefb.py [port]    (default: 18080, listens on 127.0.0.1)
#
# credentials: user "root", password PW below, session id SID below

import hashlib
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

CH, PW, SID = "1234567z", "s&cret+pw", "0123456789abcdef"

# 10.1.0.0/16 is present twice on purpose, to test deduplication in route add
v4 = [
    dict(ipaddr="10.1.0.0", netmask="255.255.0.0", gateway="192.168.178.5", _node="route0", activated="1"),
    dict(ipaddr="10.1.0.0", netmask="255.255.0.0", gateway="192.168.178.6", _node="route1", activated="1"),
    dict(ipaddr="10.2.0.0", netmask="255.255.255.0", gateway="192.168.178.5", _node="route2", activated="0"),
]
v6 = [
    dict(ipv6Address="2001:db8:1::", prefixLength="48", gateway="fe80::5", id="ip6route0", isActive="1"),
]
hosts = {
    "active": [
        dict(name="laptop", mac="AA:00:00:00:00:01", ipv4=dict(ip="192.168.178.20", dhcp="1", lastused=17),
             port="WLAN", UID="landevice1", model="active"),
    ],
    "passive": [
        dict(name="old&box", mac="AA:00:00:00:00:02", ipv4=dict(ip="192.168.178.3"),
             port="", UID="landevice2", model="passive"),
        dict(name="noip", mac="AA:00:00:00:00:03",
             port="LAN 1 mit 1 Gbit/s ", UID="landevice3", model="passive"),
    ],
    "fbox": [
        dict(name="fritz.box", mac="AA:00:00:00:00:00", ipv4=dict(ip="192.168.178.1"),
             port="", UID="landevice0", model="fbox"),
    ],
}
next_id = [10]


def session_info(sid):
    return f"<SessionInfo><SID>{sid}</SID><Challenge>{CH}</Challenge><BlockTime>0</BlockTime></SessionInfo>"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, body, ct="application/json", code=200):
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ct)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        self.reply(session_info("0" * 16), "text/xml")

    def do_POST(self):
        raw = self.rfile.read(int(self.headers["Content-Length"])).decode()
        f = {k: v[0] for k, v in parse_qs(raw, keep_blank_values=True).items()}
        print("REQ", self.path, {k: v for k, v in sorted(f.items()) if k != "sid"}, file=sys.stderr, flush=True)

        if self.path == "/login_sid.lua":
            expected = CH + "-" + hashlib.md5((CH + "-" + PW).encode("utf-16le")).hexdigest()
            ok = f.get("response") == expected and f.get("username") == "root"
            return self.reply(session_info(SID if ok else "0" * 16), "text/xml")
        if self.path != "/data.lua":
            return self.reply("not found", "text/plain", 404)
        if f.get("sid") != SID:
            return self.reply("forbidden", "text/plain", 403)

        page = f.get("page")
        if page == "static_route_table":
            if "delete" in f:
                v4[:] = [r for r in v4 if r["_node"] != f["id"]]
            return self.reply(json.dumps({"data": {"staticRoutes": {"route": v4}}}))
        if page == "static_IPv6_route_table":
            if "delete" in f:
                v6[:] = [r for r in v6 if r["id"] != f["id"]]
            return self.reply(json.dumps({"data": {"staticRoutes": v6}}))
        if page == "new_static_route":
            r = dict(
                ipaddr=".".join(f[f"ipaddr{i}"] for i in range(4)),
                netmask=".".join(f[f"netmask{i}"] for i in range(4)),
                gateway=".".join(f[f"gateway{i}"] for i in range(4)),
                activated=f["isActive"],
            )
            existing = [x for x in v4 if x["_node"] == f["route"]]
            if existing:
                existing[0].update(r)
            else:
                r["_node"] = f"route{next_id[0]}"
                next_id[0] += 1
                v4.append(r)
            return self.reply("{}")
        if page == "new_IPv6_static_route":
            r = dict(ipv6Address=f["ipv6Address"], prefixLength=f["prefixLength"],
                     gateway=f["gateway"], isActive=f["isActive"])
            existing = [x for x in v6 if x["id"] == f["route"]]
            if existing:
                existing[0].update(r)
            else:
                r["id"] = f"ip6route{next_id[0]}"
                next_id[0] += 1
                v6.append(r)
            return self.reply("{}")
        if page == "netDev":
            if "delete" in f:
                hosts["passive"][:] = [h for h in hosts["passive"] if h["UID"] != f["delete"]]
            return self.reply(json.dumps({"data": hosts}))
        if page == "netMoni":
            return self.reply(json.dumps({"data": {"connections": [{"name": "internet", "connected": True}]}}))
        self.reply("{}", code=404)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18080
    server = HTTPServer(("127.0.0.1", port), Handler)
    print(f"ready on 127.0.0.1:{port}", file=sys.stderr, flush=True)
    server.serve_forever()
