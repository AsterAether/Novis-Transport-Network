if not fs.exists("config/server.cfg") then
    print("Config file not avaiable!")
    return
  end
  
  local cfgFile = fs.open("config/server.cfg", "r")
  
  local config = textutils.unserializeJSON(cfgFile.readAll())
  
  cfgFile.close()
  
  local prot = "NOVIS_TRANSPORT"
  rednet.open(config["modemSide"])
  rednet.host(prot, "NOVIS_SERVER")
  
  print("Novis Transportation Main Server is online!")
  
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
  
  function send(receiver, message, arg)
    if type(arg) == "table" then
      arg = join(arg, ',')
    end
    if arg ~= nil then
      message = message .. ":" .. arg
    end
    rednet.send(receiver, message, prot)
  end
  
  controlFunc = {}
  controlFunc["stop"] = function ()
    return false
  end
  
  
  local stations = {}
  local switches = {}
  local activeStation = nil
  local fromStation = nil
  
  function referseLookupStation(searchRednetId)
    for station, rednetId in pairs(stations) do
      if rednetId == searchRednetId then
        return station
      end
    end
    return nil
  end
  
  function routeTo(from, station)
    local fromRoutes = config["routes"][from]
    if fromRoutes == nil or fromRoutes[station] == nil then
      print("Route to " .. station .. " doesn't exist!")
      return
    end
    local route = fromRoutes[station]
    for target, strength in pairs(route) do
      local rednetId = stations[target] and stations[target] or switches[target]
      if rednetId == nil then
        print("Target " .. target .. " not found!")
        return
      end
      send(rednetId, "setOutput", strength)
    end
  
    for _, rednetId in pairs(stations) do
      send(rednetId, "stationActive", station)
    end
  
    activeStation = station
    fromStation = from
  end
  
  rednetFunc = {}
  rednetFunc["registerStation"] = function (sender, args)
    local toAdd = args[1]
  
    if not stations[toAdd] then
      for station, rednetId in pairs(stations) do
        send(rednetId, "addStations", {toAdd})
      end
      stations[toAdd] = sender
      print("Registered station " .. toAdd .. " as network id " .. sender)
    end
    stationNames = {}
    for station, rednetId in pairs(stations) do
      stationNames[#stationNames + 1] = station
    end
    send(sender, "addStations", stationNames)
  
    if activeStation ~= nil then
      routeTo(fromStation, activeStation)
    end
  end
  
  rednetFunc["registerSwitch"] = function (sender, args)
    switches[args[1]] = sender
    print("Registered switch " .. args[1] .. " as network id " .. sender)
    if activeStation ~= nil then
      routeTo(fromStation, activeStation)
    end
  end
  
  rednetFunc["routeTo"] = function (sender, args)
    local station = args[1]
    print("Routing to station: " .. station)
    routeTo(referseLookupStation(sender), station)
  end
  
  function rednetLoop()
    while true do
      local sender, message = rednet.receive(prot)
      message = split(message, ":")
      local cmd = message[1]
      if rednetFunc[cmd] then
        rednetFunc[cmd](sender, #message == 2 and split(message[2], ",") or nil)
      end
    end
  end
  
  function controlLoop()
    while true do
      input = read()
      if controlFunc[input] and not controlFunc[input]() then
        -- Stop code execution
        for _, rednetId in pairs(stations) do
          send(rednetId, "stop")
        end
        for _, rednetId in pairs(switches) do
          send(rednetId, "stop")
        end
        break
      end
    end
  end
  
  parallel.waitForAny(controlLoop, rednetLoop)
  
  rednet.unhost(prot, "NOVIS_SERVER")
  rednet.close()