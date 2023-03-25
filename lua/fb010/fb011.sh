#!/bin/sh

PASSWORD="(uFqe[WgbmUA[g}*0auiB].=]vqdb"
CHALLANGE="$1"

_utf8_to_utf16le() {
  #iconv --from-code=UTF-8 --to-code=UTF-16LE
  #lua -e 'while true do r = io.read(1); if not r then break end; io.write(r, string.char(0)); end'
  sed -e 's,.,&\n,g' | tr '\n' '\0'
}

_md5sum() {
  md5sum | ( read sum _; echo -n "$sum" )
}

set -x
RESPONSE="$CHALLANGE-$(echo -n "$CHALLANGE-$PASSWORD" | _utf8_to_utf16le | _md5sum )"

