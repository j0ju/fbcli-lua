#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local fbcli_login = function(argv, i)
  local fb = {
    url = os.getenv("FRITZBOX_URL") or "http://fritz.box",
    password = os.getenv("FRITZBOX_PASSWORD") or "",
    user = os.getenv("FRITZBOX_USER") or "",
  }
  local _, err = CLI.parse_into_table(fb, argv, i)
  DieOnErr(err)

  FBhandle, err = FB.login(fb.user, fb.password, fb.url)
  DieOnErr(err)

  if FBcli.verbose then dump(FBhandle) end

  print(FBhandle.sid)
  return FBhandle, nil
end
return fbcli_login

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
