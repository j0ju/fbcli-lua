# Device lock (`fb_kindersicherung_lock_unlokc.pcap`)

Internet > Filter > Kindersicherung, "Internetzugang sperren und entsperren":
locking and unlocking the device "bolt" (`landevice2959`), captured November 2026,
read with `pcap-http.py`.

The capture is not committed: its `generic/wlan_light` replies contain the WiFi
passwords, and the requests contain a session id.

Newer FRITZ!OS web interfaces use a REST API next to `data.lua`. The session id
from `login_sid.lua` goes into a header instead of a form field:

```
AUTHORIZATION: AVM-SID <sid>
Content-Type: application/json
```

## Parental control users

```
GET /api/v0/generic/user
```

```json
{"user":[{"UID":"user8628","landeviceUID":"landevice2959","name":"(landev2959)","type":"1",
          "disallowed":"0","filter_profile_UID":"filtprof3",
          "today_time":"73898","ticket_valid":"0","tickets_in_advance":"0"}, …]}
```

Every host (`landeviceUID`, the UID of `page=netDev`) has one user (`type` 1);
guest users (`type` 4) have no `landeviceUID`. `GET /api/v0/generic/landevice`
links back via `user_UIDs`.

## Lock / unlock

```
PUT /api/v0/generic/user/user/user8628
{"disallowed":"1"}          lock
{"disallowed":"0"}          unlock
```

Reply: `{}` (HTTP 200). The web interface re-reads `generic/user` afterwards.

`filter_profile_UID` in the same object suggests the access profile can be set
the same way, this is not captured yet (`host filter` uses `page=edit_device`).
