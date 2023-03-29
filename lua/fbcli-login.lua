#!/usr/bin/env lua5.1

function fbcli_login(argv, i)
  local fb = {
    url = os.getenv("FRITZBOX_URL") or "http://fritz.box",
    password = os.getenv("FRITZBOX_PASSWORD") or "",
    user = os.getenv("FRITZBOX_USER") or "",
  }
  local _, err = CLI.parse_into_table(fb, argv, i)
  die_on_err(err)

  FBhandle, err = FB.login(fb.user, fb.password, fb.url)
  die_on_err(err)

  if FBcli.verbose then dump(FBhandle) end

  print(FBhandle.sid)
  return FBhandle, nil
end
return fbcli_login

-- vim: ts=2 et sw=2 fdm=indent ft=lua
