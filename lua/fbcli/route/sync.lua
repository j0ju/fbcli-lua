#!/usr/bin/env lua5.1
-- LICENSE: GPL v2, see LICENSE.txt

local unistd = require('posix.unistd')
local posix = require('posix')

-- TODO:
--  * signal handling
--  * cleanup
local parse_ip_route = function(line)
  local r = {}
  local tokenizer = string.gmatch(line, '%S+')
  local token = tokenizer()
  while token do
    if token == "Deleted" then
      r.op = "del"
    elseif token == "unreachable" or token == "prohibit" or token == "blackhole" then
      r.type = token
    elseif r.prefix == nil then
      r.prefix = token
    elseif token == "via" then
      local n = tokenizer()
      if n == "inet6" then
        r[token] = n .. " " .. tokenizer()
      else
        r[token] = n
      end
    else
      r[token] = tokenizer()
    end
    token = tokenizer()
  end
  if r.op == nil then r.op = "add" end
  return r
end

local route_queue_process = function(q, noop)
  if FBcli.verbose then
    pstrerr("I: route_queue_process()")
  end
  for pfx, r in pairs(q) do
    if r.op == "add" then
      if noop then
        PStdErr(string.format("I: would add route %s via %s", r.prefix, r.via))
      else
        local rs, err = FB.route.add(FBhandle, r)
        DieOnErr(err)
        PStdErr(string.format("I: added route %s via %s", r.prefix, r.via))
      end
    elseif r.op == "del" then
      if noop then
        PStdErr(string.format("I: would add route %s via %s", r.prefix))
      else
      -- TODO
      end
    end
    q[pfx]=nil
  end
end

local fbcli_route_sync = function(argv, i)
  if FBcli.verbose then
    PStdErr("fbcli_route_sync()")
  end

  -- CLI Parse
  local args = {
    ip = "/sbin/ip",
    table = "",
    v4via = "",
    v6via = "",
    follow = false,  -- if set do continueuos sync
    pollms = 5000, -- milliseconds to wait for pools, input and bursts
    allow = {},
    deny = {},
    policy = "allow",
    noop = false,
  }
  CLI.parse_into_table(args, argv, i)
  args.pollms = tonumber(args.pollms) -- ensure this is a number
  dump(args)

  local pid, errmsg, errno, st, line
  local pipe = {}

  if args.v4via == "" and args.v6via == "" then
    PStdErr(string.format("E: fbcli_route_sync: router endpoint for IPv4 or IPv6 not set"))
    os.exit(1)
  end

  -- create pipe
  pipe.r, pipe.w, errno = unistd.pipe()
  if pipe.r == nil then
    -- error message is in pipe.w
    PStdErr(string.format("E: fbcli_route_sync: cannot create pipe to 'ip route monitor': %s"), pipe.w)
    os.exit(1)
  end

  -- fork ip route monitor
  local pid, errmsg, errno = unistd.fork()
  if pid == 0 then
  -- Child
    unistd.close(pipe.r)
    -- redirect STDOUT to pipe
    unistd.dup2(pipe.w, unistd.STDOUT_FILENO)
    PStdErr(string.format("I: fork PID: %s", unistd.getpid()))
  -- coldplug - popen and output "ip -$IPVER route show"
    for _, ipver in pairs({ "4", "6"  }) do
      local table = ""
      if not (args.table == "") then
        table = "table " .. args.table
      end
      local cmdline  = string.format("%s -%s route show %s", args.ip, ipver, table)
      print("-- coldplug: ".. cmdline)
      local ip_output = io.popen(cmdline)
      repeat
        line = ip_output:read()
        if line then print(line .. " " .. table) end
      until line == nil
      io.close(ip_output)
    end
  -- hotplug - fork out to "ip route monitor" (if args.follow is set)
    if args.follow then
      print("-- hotplug: ".. args.ip .." monitor route")
      io.stdout:flush()
      st, errmsg, errno = unistd.exec(args.ip, {"monitor", "route"})
      -- fallthrough if exec fails
      if st == nil then
        PStdErr(string.format("E: fbcli_route_sync: cannot exec command: '%s monitor route': %s", args.ip, errmsg))
        os.exit(1)
      end
    end
    -- this will never be reached, when follow is true
    print("-- end")
    io.stdout:flush()
    os.exit(0)
  elseif pid > 0 then
  -- Main
    PStdErr(string.format("I: main PID: %s", unistd.getpid()))
    PStdErr(string.format("I: main fork PID: %s", pid))
    unistd.close(pipe.w)
    -- redirect STDIN to read from pipe
    unistd.dup2(pipe.r, unistd.STDIN_FILENO)
  else
    PStdErr(string.format("E: fbcli_route_sync: cannot fork: %s", errmsg))
    os.exit(1)
  end

  -- only main fork will reach this line of code, STDIN is STDOUT of fork
  local poll_fds = { [unistd.STDIN_FILENO] = { events = { IN = true } } }
  local q = {}
  local r = {}
  repeat
    local type, line = nil

    -- wait for input from child
    -- Ideas & Assumptions
    --  * most route changes come in bursts
    --  * as long we have input on STDIN (ip route monitor),
    --    put all new route events in a q(ueue) indexed by prefix
    --  * if we have at one time no input, (events == 0 after the poll) process the queue
    --  ==> this way we have on multiple event changes for the same prefix, the latest route in queue per prefix
    --  ==> if we get only a small number of route change events, this works, too
    --  TODO: relogin on credential fails
    local events, errmsg, errno = posix.poll(poll_fds, args.pollms)
    if events == nil then
      PStdErr(string.format("E: fbcli_route_sync: cannot poll from pipe: %s monitor route: %s", args.ip, errmsg))
      os.exit(1)
    elseif events == 0 then
      route_queue_process(q, args.noop)
    elseif events > 0 then
      if poll_fds[unistd.STDIN_FILENO].revents.IN then
        line = io.read()
        r = {}
      elseif poll_fds[unistd.STDIN_FILENO].revents.HUP then
        -- STDIN closed
        break
      end

      line = io.read()
    end

    if not (line == nil) then
      if line:match("^-- end") then
        PStdErr(string.format("I: end of child.", line))
        break
      elseif line:match("^-- ") then
        PStdErr(string.format("I: %s", line))
      else
        r = parse_ip_route(line)
        if r.prefix == "default" then
          -- skip, we do not push default routes to fritzbox
        elseif not ((r.table or "") == args.table) then
          -- skip, this route event was not in the desired table
        elseif args.policy == "deny" and not IP.contains(args.allow, r.prefix) then
          -- skip, this route is not in the allowed net ranges
        elseif args.policy == "allow" and IP.contains(args.deny, r.prefix) then
          -- skip, this route is the denied net ranges
        elseif r.type == nil then
          -- check AF of route, if valid set appropiate via/endpoint
          r.af = IP.type(r.prefix)
          if r.af:match("^ipv4") then
            r.via = args.v4via
          elseif r.af:match("^ipv6") then
            r.via = args.v6via
          else
            r.via = ""
          end
          -- if via is set process this route
          if not (r.via == "") then
            -- augment some attributes of routes in FritzBoxes and enqueue
            r.name = ""
            r.active = 1
            q[r.prefix] = r
          end
        end
      end
    end
  until false
  -- tail processing of queued routes
  route_queue_process(q, args.noop)
end

return fbcli_route_sync

-- LICENSE: GPL v2, see LICENSE.txt
-- vim: ts=2 et sw=2 fdm=indent ft=lua
