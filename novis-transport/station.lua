os.loadAPI("bin/libs/touchpoint.lua")

if not fs.exists("config/station.cfg") then
  print("Config file not avaiable!")
  return false
end

local cfgFile = fs.open("config/station.cfg", "r")

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

send("registerStation", config["stationName"])
print("Station " .. config["stationName"] .. " connected to Novis Transport Main Server on: <" .. server .. ">")

local t = touchpoint.new(config["monitorSide"])

t:draw()

stations = {}
function addStation(station)
  stations[#stations + 1] = station

  col = (#stations - 1) % 2
  row = math.floor((#stations - 1) / 2)

  t:add(station, function()
    send("routeTo", station)
  end,
  1 + col * 9, 1 + (row * 3), (col + 1) * 9, 3 + (row * 3),
  colors.red, colors.lime)
end

rednetFunc = {}
rednetFunc["addStations"] = function (sender, args)
  for _, station in ipairs(args) do
    addStation(station)
  end
  t:draw()
end

rednetFunc["stationActive"] = function (sender, args)
  local activeStation = args[1]

  for _, station in ipairs(stations) do
    t.buttonList[station].active = false
  end

  t.buttonList[activeStation].active = true

  t:draw()
end

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

function guiLoop()
  t:run()
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

parallel.waitForAny(guiLoop, controlLoop, rednetLoop)

monitor = peripheral.wrap(config["monitorSide"])

monitor.setBackgroundColor(colors.black)
monitor.clear()

redstone.setAnalogOutput(config["outputSide"], 0)

rednet.close()

return true