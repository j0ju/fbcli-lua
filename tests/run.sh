#!/bin/sh
# LICENSE: GPL v2, see lua/LICENSE.txt
#
# Runs fbcli against tests/fakefb.py (fake FritzBox) and tests/fake-ip.
# Tests run in order and share the state of one fake FritzBox instance.
#
# usage: tests/run.sh    (env: LUA=lua5.1 PYTHON=python3 PORT=18080 VERBOSE=1)

set -u

tests_dir="$(cd "$(dirname "$0")" && pwd)"
fbcli="$tests_dir/../lua/fbcli.lua"
LUA="${LUA:-lua5.1}"
LUAC="${LUAC:-luac5.1}"
PYTHON="${PYTHON:-python3}"
PORT="${PORT:-18080}"
VERBOSE="${VERBOSE:-}"

tmp="$(mktemp -d)"
server_pid=""
cleanup() {
  [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

passed=0
failed=0

fail() {
  failed=$((failed + 1))
  echo "FAIL: $current: $*"
  sed 's/^/  | /' "$tmp/out"
}

# run <expected exit code> <fbcli args...>
#   runs fbcli, output (stdout+stderr) goes to $tmp/out
run() {
  expected_rc="$1"; shift
  current="fbcli $*"
  "$LUA" "$fbcli" "$@" > "$tmp/out" 2>&1
  rc=$?
  [ -n "$VERBOSE" ] && { echo "\$ $current  [exit $rc]"; cat "$tmp/out"; }
  if [ "$rc" -ne "$expected_rc" ]; then
    fail "exit code $rc, expected $expected_rc"
  else
    passed=$((passed + 1))
  fi
}

# expect <fixed string> - last output must contain it
expect() {
  if grep -qF -- "$1" "$tmp/out"; then
    passed=$((passed + 1))
  else
    fail "output lacks '$1'"
  fi
}

# expect_not <fixed string> - last output must not contain it
expect_not() {
  if grep -qF -- "$1" "$tmp/out"; then
    fail "output contains '$1'"
  else
    passed=$((passed + 1))
  fi
}

# expect_order <first> <second> - both in last output, <first> on an earlier line
expect_order() {
  a="$(grep -nF -- "$1" "$tmp/out" | head -1 | cut -d: -f1)"
  b="$(grep -nF -- "$2" "$tmp/out" | head -1 | cut -d: -f1)"
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then
    passed=$((passed + 1))
  else
    fail "'$1' not before '$2'"
  fi
}

# expect_saved <fixed string> - the last settings saved on the fake box contain it
expect_saved() {
  current="saved settings ($1)"
  grep "'page': 'edit_device'" "$tmp/server.log" | grep "'apply': 'true'" | tail -1 > "$tmp/out"
  if grep -qF -- "$1" "$tmp/out"; then
    passed=$((passed + 1))
  else
    fail "lacks '$1'"
  fi
}

# --- syntax check
for f in "$tests_dir"/../lua/*.lua "$tests_dir"/../lua/fbcli/*.lua "$tests_dir"/../lua/fbcli/route/*.lua; do
  current="luac -p $f"
  if "$LUAC" -p "$f" > "$tmp/out" 2>&1; then passed=$((passed + 1)); else fail "syntax error"; fi
done

# --- start fake FritzBox
"$PYTHON" -I "$tests_dir/fakefb.py" "$PORT" 2> "$tmp/server.log" &
server_pid=$!
i=0
until grep -q "^ready" "$tmp/server.log" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 50 ] || ! kill -0 "$server_pid" 2>/dev/null; then
    echo "E: fake FritzBox did not start:"; cat "$tmp/server.log"; exit 1
  fi
  sleep 0.1
done

export FRITZBOX_URL="http://127.0.0.1:$PORT"
unset FRITZBOX_SESSION FRITZBOX_USER FRITZBOX_PASSWORD

# --- login
run 1 login user root password wrong
expect "could not get a valid session Id"

run 0 login user root password 's&cret+pw'
expect "0123456789abcdef"
export FRITZBOX_SESSION=0123456789abcdef

# --- route
run 0 route show
expect "10.1.0.0/16 via 192.168.178.5 name route0 active 1"
expect "10.1.0.0/16 via 192.168.178.6 name route1 active 1"
expect "2001:db8:1:0:0:0:0:0/48 via fe80:0:0:0:0:0:0:5 name ip6route0 active 1"

run 0 route add 10.1.0.0/16 via 192.168.178.7
run 0 route show
expect "10.1.0.0/16 via 192.168.178.7"
expect_not "192.168.178.6"

run 1 route add 10.5.0.0/24
expect "no via given"

run 0 route add 2001:db8:2::/48 via fe80::2
run 0 route del 2001:db8:1::/48
run 0 ro sh
expect "2001:db8:2:0:0:0:0:0/48 via fe80:0:0:0:0:0:0:2"
expect_not "2001:db8:1:"

run 1 route del nonsense
expect "neither a route name nor a prefix"

# --- host
run 0 host list
expect "laptop    192.168.178.20"
expect "(UNKNOWN)"

run 0 host list passive no sort name
expect "laptop"
expect_not "old&box"

run 0 host list wifi no
expect_not "laptop"
expect "noip"

# fake <path> - switches of tests/fakefb.py, eg. "rest_fail/on"
fake() {
  "$PYTHON" -I -c 'import sys, urllib.request; urllib.request.urlopen(sys.argv[1]).read()' \
    "$FRITZBOX_URL/fake/$1"
}

# --- abbreviations
run 0 h l s ip
expect_order "old&box" "laptop"
run 0 h l s n
expect_order "laptop" "old&box"
run 0 h l w n
expect_not "laptop"
expect "noip"
run 0 h p n
expect "laptop"
expect_not "old&box"
run 0 h l p n w no
expect "fritz.box"
expect_not "laptop"
run 0 h l a d
expect "old&box"
expect_not "laptop"
run 1 h l s x
expect "cannot sort for coloumn 'x'"
run 1 ro s
expect "'s' is ambiguous, could be: show, sync"
run 0 r sh
expect "name route0"
run 1 route sync v4via 192.168.178.2 v 1.2.3.4 noop
expect "'v' is ambiguous, could be: v4via, v6via"
run 1 route sync v4via 192.168.178.2 policy x noop
expect "policy must be 'allow' or 'deny'"
run 1 nonsense
expect "Usage:"

# --- host filter (access profiles)
run 0 host laptop filter
expect "laptop profile Standard internet unlimited"
run 0 host laptop filter allow
expect "I: host laptop: profile Unbeschränkt"
expect_saved "'kisi_profile': 'filtprof3'"
expect_saved "'internetdetail': 'unlimited'"
# unrelated settings are sent unchanged
expect_saved "'static_dhcp': 'on'"
expect_saved "'dev_name': 'laptop'"
expect_saved "'interface_id4': '6b38'"
run 0 h laptop f
expect "laptop profile Unbeschränkt internet unlimited"
# no profile "Gesperrt": the host is blocked
run 0 h laptop f d
expect "I: host laptop: internet usage blocked"
expect_saved "'internetdetail': 'blocked'"
run 0 h laptop f
expect "internet blocked"
run 0 h laptop f r
expect "I: host laptop: profile Standard"
expect_saved "'kisi_profile': 'filtprof1'"
expect_saved "'internetdetail': 'unlimited'"
# with a profile "Gesperrt" it is used
run 0 host kid filter disallow
expect "I: host kid: profile Gesperrt"
expect_saved "'kisi_profile': 'filtprof4'"
expect_saved "'internetdetail': 'unlimited'"
run 0 host AA:00:00:00:00:04 filter reset
expect "I: host kid: profile Standard"
run 0 host 192.168.178.21 filter
expect "kid profile Standard internet unlimited"
run 1 host adapter filter allow
expect "Powerline or VPN settings, this is not supported"
run 1 host nobody filter allow
expect "no host 'nobody' found"
run 1 host laptop filter x
expect "unknown filter action 'x'"
# allow and reset unblock
run 0 h laptop f d
run 0 h laptop f a
expect "I: host laptop: profile Unbeschränkt"
expect_saved "'internetdetail': 'unlimited'"
run 0 h laptop f
expect "laptop profile Unbeschränkt internet unlimited"
run 0 h kid f d
run 0 h kid f a
expect "I: host kid: profile Unbeschränkt"
expect_saved "'kisi_profile': 'filtprof3'"
# device lock of the parental control list, prioritised host
run 0 host noip filter
expect "noip profile Standard internet blocked"
run 0 host noip filter allow
expect "I: host noip: unblocked"
expect "I: host noip: profile Unbeschränkt"
expect_saved "'internetdetail': 'realtime'"
# the unlock request as captured in docs/dumps/fb_kindersicherung_lock_unlock.md
current="unlock request"
grep "^REQ PUT" "$tmp/server.log" | tail -1 > "$tmp/out"
if grep -qxF 'REQ PUT /api/v0/generic/user/user/user3 {"disallowed":"0"}' "$tmp/out"; then
  passed=$((passed + 1))
else
  fail "unexpected unlock request"
fi
run 0 host noip filter
expect "noip profile Unbeschränkt internet realtime"
run 0 host noip filter reset
expect_not "unblocked"
expect "I: host noip: profile Standard"
# REST API errors are reported, not ignored (the device lock would be unknown)
run 0 h noip f d
fake rest_fail/on
run 1 host noip filter
expect "cannot read the device lock of the parental control (REST API)"
expect "permission denied: /api/v0/generic/user (code 3001)"
run 1 host noip filter allow
expect "permission denied"
fake rest_fail/off
run 0 host noip filter allow
expect "I: host noip: profile Unbeschränkt"
FBCLI_VERBOSE=1
export FBCLI_VERBOSE
run 0 host noip filter
expect "I: fb_REST(GET generic/user)"
expect "I: fb_REST: HTTP status 200"
expect "I: state before, host noip (landevice3): selectedRights.msgid=unlimited"
expect "rest.user=user3 disallowed=0"
expect "rest.landevice blocked=-1"
run 0 host noip filter disallow
expect "I: fb.host.set: "
expect "internetdetail=blocked"
expect "I: state after, host noip (landevice3): selectedRights.msgid=blocked"
run 0 host noip filter allow
expect "I: state after, host noip (landevice3): selectedRights.msgid=unlimited"
unset FBCLI_VERBOSE

# blocked in the home network, profiles do not help
run 0 host dupip filter
expect "internet ipconflict"
run 1 host dupip filter allow
expect "IP address is already in use"
run 1 host 192.168.178.20 filter
expect "is ambiguous (2 hosts)"

# "host list" options win over host names
run 0 h wifi f
expect_not "laptop"
expect "kid"

run 0 host del 'old&box'
expect "I: deleted host old&box"
run 1 host del laptop
expect "no hosts deleted"
run 0 host list
expect_not "old&box"

# --- status
run 0 status
expect "internet"

# --- route sync (noop, no FritzBox calls)
run 0 route sync v4via 192.168.178.2 v6via fe80::2 deny 172.16.0.0/12 pollms 300 noop ip "$tests_dir/fake-ip"
expect "would add route 10.1.0.0/16 via 192.168.178.2"
expect "would add route 10.2.0.0/24 via 192.168.178.2"
expect "would add route 2001:db8:1::/48 via fe80::2"
expect_not "172.16.0.0/12"
expect_not "fe80::/64"
expect_not "default"

run 0 r sy v4 192.168.178.2 f pm 300 pc d al 10.0.0.0/8 n ip "$tests_dir/fake-ip"
expect "would add route 10.2.0.0/24 via 192.168.178.2"
expect "would add route 10.3.0.0/24 via 192.168.178.2"
expect_not "172.16.0.0/12"

run 0 route sync v4via 192.168.178.2 follow pollms 300 noop ip "$tests_dir/fake-ip"
expect "would add route 10.3.0.0/24 via 192.168.178.2"
expect "would delete route 10.1.0.0/16 via 192.168.178.2"
expect_not "10.9.0.0/24"
expect_not "would add route 10.1.0.0/16"

# --- route sync (against the fake FritzBox)
run 0 route sync v4via 192.168.178.2 deny 172.16.0.0/12 pollms 300 ip "$tests_dir/fake-ip"
expect "added route 10.2.0.0/24 via 192.168.178.2"
run 0 route show
expect "10.1.0.0/16 via 192.168.178.2"
expect "10.2.0.0/24 via 192.168.178.2 name route2 active 1"

# --- route flush
run 0 route flush
run 0 route show
current="route show after flush"
[ -s "$tmp/out" ] && fail "routes left after flush"

# --- errors
# (no VAR=value prefix on functions: some shells keep the value afterwards)
FRITZBOX_SESSION=bad
run 1 route show
expect "unsuccessful 403"
FRITZBOX_SESSION=0123456789abcdef
FRITZBOX_URL="http://127.0.0.1:1"
run 1 route show
expect "failed"

echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
