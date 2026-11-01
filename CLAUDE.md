# fbcli – notes for AI assistants

CLI for AVM FritzBox routers in plain **Lua 5.1** (target: OpenWrt). It drives the
undocumented web UI endpoints (`/login_sid.lua`, `/data.lua?page=…`), not TR-064.
User-facing docs: `README.md`. Usage text: `lua/fbcli/help.lua` (keep both in sync).

## Layout

- `lua/fbcli.lua` – entry point; resolves its own dir through symlinks, sets
  `package.path`, defines globals `CLI`, `IP`, `FB`, `FBcli`, `FBhandle`
  (`url`/`sid` from `FRITZBOX_URL`/`FRITZBOX_SESSION`), dispatches via `CLI.action`.
- `lua/CLI.lua` – dispatcher over the nested `FBcli` table; a table key is a
  command, a function is an action, `DEFAULT` is the fallback. Abbreviations match
  by regex (first char required, the rest optional) and pick the first `pairs()`
  hit, so ambiguous prefixes are non-deterministic.
  `CLI.parse_into_table(defaults, argv, i)` infers option types from the default
  value: string, number, boolean (value optional), table (repeatable).
  Also defines globals `PStdErr` and `DieOnErr`.
- `lua/fritzbox.lua` – API layer (`FB`): `login`, `route.{list,add,delete}`,
  `route.ipv4.*`/`route.ipv6.*`, `host.{list,delete}`, `mesh.list`, `status`.
  All requests go through `fb_POST_json_data_lua`, which URL-encodes form values.
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
  the source of truth for request/response formats. Read with
  `zstdcat f.pcap.zst | strings` or `tcpdump -r`. Uncompressed `*.pcap` are ignored.

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
  exit codes and output with `run <rc> <args…>`, `expect` and `expect_not`.
  All tests share one fake box, so order matters: later tests see what
  earlier ones changed.
- `tests/fakefb.py` – fake FritzBox: `login_sid.lua` (user `root`, password
  and SID in the file) and the `data.lua` pages `fritzbox.lua` uses, state in
  memory, every request logged to stderr. When you use a new page or form
  field, add it here and base the reply shape on `docs/dumps`. Run it alone
  with `python3 tests/fakefb.py [port]` for manual checks.
- `tests/fake-ip` – stands in for `ip` in `route sync … ip tests/fake-ip`
  (fixed routing table, a few `monitor route` events).

Add a test for each fixed bug or new option. Find accidental globals with
`luac5.1 -l -p FILE | grep GETGLOBAL`. Never test destructive commands
(`route flush`, `host delete`, `route sync` without `noop`) on a real box without asking.
