#!/usr/bin/env sh

_utf8_to_utf16le() {
  #iconv --from-code=UTF-8 --to-code=UTF-16LE
  #lua -e 'while true do r = io.read(1); if not r then break end; io.write(r, string.char(0)); end'
  sed -e 's,.,&\n,g' | tr '\n' '\0'
}

_md5sum() {
  md5sum | ( read sum _; echo -n "$sum" )
}

str=asdf
str='1d8d3f9c-(uFqe[WgbmUA[g}*0auiB].=]vqdb'
#set -x
echo -n "$str" | _md5sum
echo
echo -n "$str" | _utf8_to_utf16le | _md5sum
echo

