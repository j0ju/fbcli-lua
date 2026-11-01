# Edit device page (`fb_host_set.pcap.zst`)

Captured from a FRITZ!Box 7590 web UI (November 2023), read with `pcap-http.py`.

## Read settings

```
POST /data.lua
xhr=1&sid=…&lang=de&page=edit_device&xhrId=all&backToPage=netDev&dev=landevice177694
```

The reply has the settings in `.data.vars.dev`, the UID is the one from `page=netDev`.
Access profile ("Zugangsprofil") related parts:

```json
"realtime": {"state": false},
"netAccess": {"kisi": {
  "show": true,
  "selectedRights": {"msgid": "notallowed", "msg": "Gesperrt durch Zugangsprofil"},
  "isDeviceBlocked": false,
  "profiles": {"list": [{"value": "filtprof1", "text": "Standard"},
                        {"value": "filtprof3", "text": "Unbeschränkt"},
                        {"value": "filtprof1457", "text": "kein Internet"}],
               "selected": "filtprof1"}}}
```

`selectedRights.msgid` is `blocked` if internet usage of the device is blocked,
`isDeviceBlocked` is set for the device lock of the parental control list (see below),
`showWarning` if the device is blocked in the home network (IP address already in use,
the page then shows no internet usage settings at all).
`page=kidPro` (see `fb_list_Zugangsprofile.md`) also lists `filtprof2` ("Gast").
There is no "Gesperrt" profile on this FRITZ!OS, blocking is a device setting.

## Save settings

The web UI always sends the full form:

```
POST /data.lua
xhr=1&dev_name=win10&internetdetail=unlimited&kisi_profile=filtprof3
&allow_pcp_and_upnp=off&dev_ip0=192&dev_ip1=168&dev_ip2=141&dev_ip3=138&dev_ip=192.168.141.138
&static_dhcp=off&interface_id1=48cd&interface_id2=3fda&interface_id3=825b&interface_id4=6b38
&auto_wakeup=off&back_to_page=netDev&dev=landevice177694&apply=true&sid=…&lang=de&page=edit_device
```

Reply: `{"data": {"redirect": {"back": true}, "apply": "ok"}}`

* `internetdetail`: `unlimited` (by profile), `realtime` (by profile, prioritised), `blocked`
* `kisi_profile`: profile value; not shown (and not sent) by the UI while blocked
* checkboxes are sent as `on`/`off`
* fields only exist if the matching section is shown (from `net_edit_device.js`):
  `dev_name` (`name.editable`), `allow_pcp_and_upnp` (`ipv4.portForwarding.show`),
  `dev_ip*` (`ipv4.show`, `ipv4.editable`), `static_dhcp` (`ipv4.dhcp.show`),
  `interface_id1..4` (`ipv6.iface.show`), `auto_wakeup` (`wakeOnLan.show`),
  `connection_assignment` (`netAccess.connectionAssignment.show`)
* the device lock is not part of this form, see below
* Powerline adapters (`plc_desc` instead of `dev_name`, `plc_*`, `led`, `greenmode`,
  `netpwd`, `tr069_option`) and devices with VPN users (`vpn_active`) have more
  fields, `fb.host.form()` refuses those.

## Device lock (page `kidLis`, not captured yet)

Internet > Filter > Kindersicherung, "Internetzugang sperren und entsperren".
From the JS of `page=kidLis` (`fb_list_Zugangsprofile.pcap.zst`):

```js
newval.submit({ name: "toBeBlocked", value: <landevice UID> }, { blocked: <true|false> })
```

fbcli sends `xhr=1&toBeBlocked=landeviceN&blocked=false&page=kidLis` and checks the
result via `page=edit_device` (`isDeviceBlocked`). The reply is the HTML page.
A capture of (un)locking a device would confirm the request.
