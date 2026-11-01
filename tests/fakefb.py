#!/usr/bin/env python3
# LICENSE: GPL v2, see lua/LICENSE.txt
#
# Minimal fake FritzBox web interface for testing fbcli without a real box.
# Mimics /login_sid.lua, the /data.lua pages and the /api/v0 REST calls used
# by lua/fritzbox.lua, keeps state in memory and logs every request to stderr
# ("REQ ...").
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
        dict(name="kid", mac="AA:00:00:00:00:04", ipv4=dict(ip="192.168.178.21", dhcp="1"),
             port="LAN 2 mit 1 Gbit/s ", UID="landevice4", model="active"),
        dict(name="adapter", mac="AA:00:00:00:00:05", ipv4=dict(ip="192.168.178.22", dhcp="1"),
             port="LAN 3 mit 1 Gbit/s ", UID="landevice5", model="active"),
    ],
    "passive": [
        dict(name="old&box", mac="AA:00:00:00:00:02", ipv4=dict(ip="192.168.178.3"),
             port="", UID="landevice2", model="passive"),
        dict(name="noip", mac="AA:00:00:00:00:03",
             port="LAN 1 mit 1 Gbit/s ", UID="landevice3", model="passive"),
        dict(name="dupip", mac="AA:00:00:00:00:06", ipv4=dict(ip="192.168.178.20"),
             port="", UID="landevice6", model="passive"),
    ],
    "fbox": [
        dict(name="fritz.box", mac="AA:00:00:00:00:00", ipv4=dict(ip="192.168.178.1"),
             port="", UID="landevice0", model="fbox"),
    ],
}
next_id = [10]
# test switch: GET /fake/rest_fail/on|off, the REST API then answers like a
# FritzBox that denies the session
rest_fail = [False]

# access profiles and settings of the "edit device" page (page=edit_device),
# structure as captured in docs/dumps/fb_host_set.pcap.zst
profiles = [
    dict(value="filtprof1", text="Standard"),
    dict(value="filtprof2", text="Gast"),
    dict(value="filtprof3", text="Unbeschränkt"),
    dict(value="filtprof1457", text="kein Internet"),
]
# older FRITZ!OS has a profile "Gesperrt", newer ones block the device instead;
# only "kid" sees it, to test both variants with one fake box
profiles_kid = profiles + [dict(value="filtprof4", text="Gesperrt")]
# blocked: "Internetnutzung gesperrt" on the edit device page
# locked:   device lock of the parental control list (REST API, user
#           "disallowed"), visible as isDeviceBlocked, not lifted by the edit
#           device page
# ipconflict: blocked in the home network, IP address already in use
settings = {
    uid: dict(profile="filtprof1", blocked=False, locked=False, ipconflict=False, realtime=False,
              static_dhcp=False, allow_forwarding=False, auto_wakeup=False)
    for uid in ("landevice1", "landevice2", "landevice3", "landevice4", "landevice5", "landevice6")
}
settings["landevice1"]["static_dhcp"] = True
settings["landevice3"].update(locked=True, realtime=True)
settings["landevice6"]["ipconflict"] = True
# fields the web interface always sends for a plain host
required_fields = ["dev_name", "internetdetail", "allow_pcp_and_upnp", "dev_ip0", "dev_ip1", "dev_ip2",
                   "dev_ip3", "dev_ip", "static_dhcp", "interface_id1", "interface_id2", "interface_id3",
                   "interface_id4", "auto_wakeup", "back_to_page", "dev", "apply"]


def find_host(uid):
    for hl in hosts.values():
        for h in hl:
            if h["UID"] == uid:
                return h
    return None


def edit_device_vars(uid):
    h, st = find_host(uid), settings[uid]
    plist = profiles_kid if h["name"] == "kid" else profiles
    rights = dict(msgid="blocked", msg="Gesperrt") if st["blocked"] else dict(msgid="unlimited", msg="")
    dev = {
        "UID": uid, "devType": "lan", "mac": h["mac"], "isGuest": False,
        "page": {"own": False, "editable": True},
        "name": {"displayName": h["name"], "editable": True},
        "realtime": {"state": st["realtime"]},
        "wakeOnLan": {"show": True, "checked": st["auto_wakeup"]},
        "ipv4": {"show": True, "editable": True,
                 "current": {"ip": h.get("ipv4", {}).get("ip", "192.168.178.99")},
                 "dhcp": {"show": True, "alwaysSameIp": st["static_dhcp"]},
                 "portForwarding": {"show": True, "allowForwarding": st["allow_forwarding"]}},
        "ipv6": {"show": True, "iface": {"show": True, "ifaceid": "::48cd:3fda:825b:6b38"}},
        "netAccess": {"show": True, "connectionAssignment": [],
                      "kisi": {"show": True, "selectedRights": rights, "showWarning": st["ipconflict"],
                               "isDeviceBlocked": st["blocked"] or st["locked"],
                               "profiles": {"list": plist, "selected": st["profile"]}}},
    }
    if h["name"] == "adapter":
        dev["plc"] = {"enabled": True}
    return {"ipv6_enabled": True, "ipMask": "255.255.255.0", "backToPage": "netDev", "dev_node": uid, "dev": dev}


def rest_users():
    # one parental control user per host, see docs/dumps/fb_kindersicherung_lock_unlock.md
    return {"user": [
        {"UID": "user" + uid[len("landevice"):], "landeviceUID": uid, "type": "1",
         "name": f"(landev{uid[len('landevice'):]})", "disallowed": "1" if st["locked"] else "0",
         "filter_profile_UID": st["profile"], "today_time": "0", "ticket_valid": "0", "tickets_in_advance": "0"}
        for uid, st in settings.items()
    ]}


def edit_device_apply(f):
    uid = f.get("dev")
    missing = [k for k in required_fields if k not in f]
    if f.get("internetdetail") != "blocked" and "kisi_profile" not in f:
        missing.append("kisi_profile")
    if uid not in settings or missing:
        print("REJECT edit_device, missing:", missing, file=sys.stderr, flush=True)
        return {"data": {"apply": "error", "missing": missing}}
    st = settings[uid]
    st["blocked"] = f["internetdetail"] == "blocked"
    st["realtime"] = f["internetdetail"] == "realtime"
    st["profile"] = f.get("kisi_profile", st["profile"])
    st["static_dhcp"] = f["static_dhcp"] == "on"
    st["allow_forwarding"] = f["allow_pcp_and_upnp"] == "on"
    st["auto_wakeup"] = f["auto_wakeup"] == "on"
    find_host(uid)["name"] = f["dev_name"]
    return {"data": {"redirect": {"back": True}, "apply": "ok"}}


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

    def rest_authorized(self):
        if rest_fail[0] or self.headers.get("AUTHORIZATION") != "AVM-SID " + SID:
            # as answered by a real FritzBox
            self.reply(json.dumps({"errors": [{"message": "permission denied: " + self.path.split("?")[0],
                                               "code": 3001}]}), code=400)
            return False
        return True

    def do_GET(self):
        if self.path.startswith("/fake/rest_fail/"):
            rest_fail[0] = self.path.endswith("/on")
            return self.reply("{}")
        if self.path.startswith("/api/v0/"):
            print("REQ GET", self.path, file=sys.stderr, flush=True)
            if not self.rest_authorized():
                return
            if self.path == "/api/v0/generic/user":
                return self.reply(json.dumps(rest_users()))
            if self.path == "/api/v0/generic/landevice":
                return self.reply(json.dumps({"landevice": [
                    {"UID": uid, "name": find_host(uid)["name"], "blocked": "-1", "parental_control_abuse": "0",
                     "kisi_state_hide": "2", "user_UIDs": "user" + uid[len("landevice"):]}
                    for uid in settings]}))
            return self.reply("{}", code=404)
        self.reply(session_info("0" * 16), "text/xml")

    def do_PUT(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        print("REQ PUT", self.path, raw, file=sys.stderr, flush=True)
        if not self.rest_authorized():
            return
        prefix = "/api/v0/generic/user/user/user"
        uid = "landevice" + self.path[len(prefix):] if self.path.startswith(prefix) else None
        if uid not in settings:
            return self.reply("{}", code=404)
        data = json.loads(raw)
        if "disallowed" in data:
            settings[uid]["locked"] = data["disallowed"] == "1"
        return self.reply("{}")

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
        if page == "edit_device":
            if f.get("apply") == "true":
                return self.reply(json.dumps(edit_device_apply(f)))
            if f.get("dev") not in settings:
                return self.reply(json.dumps({"data": {}}))
            return self.reply(json.dumps({"pid": "edit_device", "data": {"vars": edit_device_vars(f["dev"])}}))
        if page == "netMoni":
            return self.reply(json.dumps({"data": {"connections": [{"name": "internet", "connected": True}]}}))
        self.reply("{}", code=404)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18080
    server = HTTPServer(("127.0.0.1", port), Handler)
    print(f"ready on 127.0.0.1:{port}", file=sys.stderr, flush=True)
    server.serve_forever()
