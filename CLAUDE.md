# fbcli – notes for AI assistants

CLI for AVM FritzBox routers in plain **Lua 5.1** (target: OpenWrt). It drives the
undocumented web UI endpoints (`/login_sid.lua`, `/data.lua?page=…`), not TR-064.
User-facing docs: `README.md`. Usage text: `lua/fbcli/help.lua` (keep both in sync).

## Layout

- `lua/fbcli.lua` – entry point; resolves its own dir through symlinks, sets
  `package.path`, defines globals `CLI`, `IP`, `FB`, `FBcli`, `FBhandle`
  (`url`/`sid` from `FRITZBOX_URL`/`FRITZBOX_SESSION`), dispatches via `CLI.action`.
- `lua/CLI.lua` – dispatcher over the nested `FBcli` table; a table key is a
  command, a function is an action, `DEFAULT` is the fallback (also used, with
  the remaining argv as options, when no action matches). Keys starting with an
  uppercase letter are internal and never matched.
  `CLI.match(keys, input)` does all abbreviation matching: an exact match wins,
  otherwise the input must keep the first character and the rest must appear in
  order (`lst` → `list`); returns `key`, `nil, nil` (no match) or `nil, err`
  (ambiguous). Keys in `CLI.exact` (`help`) only match in full. When you add a
  command or option, check that the abbreviations users already type (e.g.
  `h` → `host`, `l` → `list`, `s` → `sort`) still resolve, and add a test.
  `CLI.parse_into_table(defaults, argv, i)` infers option types from the default
  value: string, number, boolean (value optional, abbreviated words like `n`
  are accepted unless they match an option name), table (repeatable). Choice
  values (`host list sort`, `route sync policy`) go through `CLI.match` in the
  action.
  Also defines globals `PStdErr` and `DieOnErr`.
- `lua/fritzbox.lua` – API layer (`FB`): `login`, `route.{list,add,delete}`,
  `route.ipv4.*`/`route.ipv6.*`, `host.{list,delete,get,form,set}`, `mesh.list`,
  `status`. `data.lua` requests go through `fb_POST_json_data_lua`
  (`fb_POST_data_lua` for non-JSON replies), which URL-encodes form values;
  the REST API of newer FRITZ!OS (`/api/v0/…`, JSON bodies, session id in the
  `AUTHORIZATION: AVM-SID <sid>` header) goes through `fb_REST`. Prefer what the
  web UI of the capture uses.
- Settings pages (eg. `edit_device`, used by `host HOST filter`) are saved by
  posting the *whole* form, as the web UI does; fields left out may be reset.
  `fb.host.form()` rebuilds the form from the read reply, following the page's
  JS (`docs/dumps/fb_host_set.md`), and refuses device types whose form is not
  fully known. Keep that rule for new settings: read, change one field, write
  back everything, and document the form under `docs/dumps/`.
- `lua/fbcli/*.lua` – subcommands. `route/sync.lua` forks: the child prints
  `ip -4/-6 route show table X`, then (with `follow`) execs `ip monitor route`;
  the parent polls the pipe, queues events per prefix and flushes on silence.
- `lua/ipaddr.lua` (`IP`) – `type()` returns `"ipv4"|"ipv4+cidr"|"ipv6"|"ipv6+cidr"`
  plus address and cidr, or the Lua type name for anything else; IPv6 is printed
  expanded without zero compression (`2001:db8:0:0:0:0:0:0`). Also has
  `prefix`, `address`, `contains`, `lesser_than`, `cidr2netmask`, `netmask2cidr`.
- `lua/JSON.lua` is third party (Jeffrey Friedl, CC-BY), so don't change it.
  `simplexml.lua`, `dump.lua` (`dump()` pretty printer), `console.lua`
  (`console_table_dump`), `luautil.lua` (`table.size`, `table.add`).
- `docs/dumps/` – tcpdump tooling and `*.pcap.zst` captures of web UI actions;
  the source of truth for request/response formats. Read whole requests and
  replies with `zstdcat f.pcap.zst > /tmp/f.pcap && python3 docs/dumps/pcap-http.py /tmp/f.pcap`;
  `*.md` next to a capture describe it. Uncompressed `*.pcap` are ignored.
  Captures can contain secrets (WiFi passwords in `wlan_light`, session ids):
  check and scrub before committing one.

## Conventions

- Lua 5.1 only: no `goto`, no `//`, no bit operators, no `bit` library
  (`ipaddr.lua` has its own `band`). `string.format("%s", nil)` raises errors
  in 5.1, so use `tostring()`.
- Errors are returned as `nil, { errmsg = "...", exitcode = 1 }`; CLI actions
  return `rs, err` and `fbcli.lua` calls `DieOnErr`. Messages go to stderr,
  prefixed `I:` / `E:`.
- `FB.route.list` returns one table indexed three ways: by prefix, by FritzBox
  route name (`routeN`, `ip6routeN`) and as a list. Duplicate prefixes are
  only visible in the list part (`ipairs`).
- Style: 2-space indent, file header `-- LICENSE: GPL v2, see LICENSE.txt`,
  vim modeline footer. Commits: `<area>: <summary>` (e.g. `fbcli host: …`,
  `fritzbox: …`, `docs/dumps: …`), one logical fix per commit.

## Checking changes

Run the test suite after every change (needs `lua5.1`, `luac5.1`, `python3`):

```sh
tests/run.sh            # VERBOSE=1 shows every command and its output
```

- `tests/run.sh` – syntax-checks all Lua files, starts `tests/fakefb.py` on
  `127.0.0.1:$PORT` (default 18080), runs fbcli commands in order and checks
  exit codes and output with `run <rc> <args…>`, `expect`, `expect_not`,
  `expect_order`, and the last saved `edit_device` form with `expect_saved`.
  All tests share one fake box, so order matters: later tests see what
  earlier ones changed.
- `tests/fakefb.py` – fake FritzBox: `login_sid.lua` (user `root`, password
  and SID in the file) and the `data.lua` pages `fritzbox.lua` uses, state in
  memory, every request logged to stderr. When you use a new page or form
  field, add it here and base the reply shape on `docs/dumps`. Run it alone
  with `python3 tests/fakefb.py [port]` for manual checks.
- `tests/fake-ip` – stands in for `ip` in `route sync … ip tests/fake-ip`
  (fixed routing table, a few `monitor route` events).

`FBCLI_VERBOSE=1` logs every FritzBox call; ask for that output when something
fails on a real box. `tests/run.sh`'s `fake rest_fail/on|off` makes the fake
REST API deny the session. Never ignore errors of a lookup whose result decides
what to change (e.g. the device lock): fail instead of guessing.

Add a test for each fixed bug or new option. Find accidental globals with
`luac5.1 -l -p FILE | grep GETGLOBAL`. Never test destructive commands
(`route flush`, `host delete`, `route sync` without `noop`) on a real box without asking.
