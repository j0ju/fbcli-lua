#!/usr/bin/env lua5.1

function fbcli_login(argv, i) 
  local fb = {
    url = os.getenv("FRITZBOX_URL") or "http://fritz.box",
    password = os.getenv("FRITZBOX_PASSWORD") or "",
    user = os.getenv("FRITZBOX_USER") or "",
  }
  CLI.parse_into_table(fb, argv, i)
  FBhandle = FB.login(fb.user, fb.password, fb.url)
  print(FBhandle.sid)
end
return fbcli_login

-- vim: ts=2 et sw=2 fdm=indent ft=lua
