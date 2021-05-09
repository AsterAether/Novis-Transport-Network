if not fs.exists("config/switch.cfg") then
    print("Config file not avaiable!")
    return false
  end
  
  local cfgFile = fs.open("config/switch.cfg", "r")
  
  local config = textutils.unserializeJSON(cfgFile.readAll())
  
  cfgFile.close()
  
  local prot = "NOVIS_TRANSPORT"
  rednet.open(config["modemSide"])
  server = rednet.lookup(prot, "NOVIS_SERVER")
  
  if server == nil then
    print("Server not found")
    return false
  end
  
  function split(str, delim)
    local t = {}
    for i in str:gmatch("([^" .. delim .. "]+)") do
        t[#t + 1] = i
    end
    return t
  end
  
  function join(list, delim)
     local len = #list
     if len == 0 then
        return ""
     end
     local string = list[1]
     for i = 2, len do
        string = string .. delim .. list[i]
     end
     return string
  end
  
  function send(message, arg)
    if type(arg) == "table" then
      arg = join(arg, ',')
    end
    if arg ~= nil then
      message = message .. ":" .. arg
    end
    rednet.send(server, message, prot)
  end
  
  send("registerSwitch", config["switchName"])
  print("Switch " .. config["switchName"] .. " connected to Novis Transport Main Server on: <" .. server .. ">")
  
  rednetFunc = {}
  
  rednetFunc["setOutput"] = function (sender, args)
    local strength = args[1]
    redstone.setAnalogOutput(config["outputSide"], tonumber(strength))
  end
  
  rednetFunc["stop"] = function (sender, args)
    return false
  end
  
  function rednetLoop()
    while true do
      local sender, message = rednet.receive(prot)
      message = split(message, ":")
      local cmd = message[1]
      if rednetFunc[cmd] then
        if rednetFunc[cmd](sender, #message == 2 and split(message[2], ",") or nil) ~= nil then
          break
        end
      end
    end
  end
  
  controlFunc = {}
  controlFunc["stop"] = function ()
    return false;
  end
  
  function controlLoop()
    while true do
      input = read()
      if controlFunc[input] and not controlFunc[input]() then
        -- Stop code execution
        break
      end
    end
  end
  
  parallel.waitForAny(controlLoop, rednetLoop)
  
  redstone.setAnalogOutput(config["outputSide"], 0)
  
  rednet.close()
  return true