--------------------------------------------------------------------------------
-- 2023 - avb
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
local TO_DEG = 180.0 / 3.141516
local socket_lib = nil

local RTI = {}
RTI.SOCKET_PORT = 9111
RTI.REPEAT_CONNECTION_INTERVAL = 2.0
RTI.UPDATE_INTERVAL = 0.025

RTI.log_file = nil
RTI.socket = nil
RTI.data_str = ""

--------------------------------------------------------------------------------
-- Util
--------------------------------------------------------------------------------
function connectTCPSocket()
   RTI.socket = socket_lib.connect("127.0.0.1", RTI.SOCKET_PORT)

   if RTI.socket ~= nil then
      RTI.socket:settimeout(1)
      RTI.socket:setoption("tcp-nodelay", true)

      writeToLog("INFO: Connected to the port: " .. RTI.SOCKET_PORT)

      s_no_conection = false

      return true
   else
      if not s_no_conection then
         writeToLog("ERROR: No Connection with WTRTI")
         s_no_conection = true
      end

      return false
   end
end

--------------------------------------------------------------------------------
function sendData(data)
   local ret = RTI.socket:send(data)
   if ret == nil then
      writeToLog("ERROR: Can't send data to WTRTI")

      RTI.socket:close()
      RTI.socket = nil
   end
end

--------------------------------------------------------------------------------
function writeToLog(str)
   if RTI.log_file == nil then return end

   RTI.log_file:write(str .. "\r\n")
end

--------------------------------------------------------------------------------
function addParam(name, format, value)
   if value ~= nil then
      RTI.data_str = RTI.data_str .. string.format("\"%s\" : %s, ", name, string.format(format, value))
   end
end

--------------------------------------------------------------------------------
-- DCS
--------------------------------------------------------------------------------
function LuaExportStart()
   RTI.log_file = io.open(lfs.writedir() .. [[Logs\WTRTI_Export.log]], "w")

   writeToLog("INFO: Start Export Script")

   ---
   local version = LoGetVersionInfo() --request current version info (as it showed by Windows Explorer fo DCS.exe properties)
   if version and RTI.log_file then
      writeToLog("INFO: ProductName: "..version.ProductName)
      writeToLog(string.format("  FileVersion: %d.%d.%d.%d",
                               version.FileVersion[1],
                               version.FileVersion[2],
                               version.FileVersion[3],
                               version.FileVersion[4]))
      writeToLog(string.format("  ProductVersion: %d.%d.%d.%d",
                               version.ProductVersion[1],
                               version.ProductVersion[2],
                               version.ProductVersion[3],  -- head  revision (Continuously growth)
                               version.ProductVersion[4])) -- build number   (Continuously growth)
   end

   ---
   package.path  = package.path .. ";" .. lfs.currentdir() .. "/LuaSocket/?.lua"
   package.cpath = package.cpath .. ";" .. lfs.currentdir() .. "/LuaSocket/?.dll"

   socket_lib = require("socket")
   if socket_lib == nil then
      writeToLog("ERROR: LuaSocket not loaded")
   end
end

--------------------------------------------------------------------------------
function LuaExportStop()
   writeToLog("INFO: Stop Export Script")

   ---
   if RTI.log_file then
      RTI.log_file:close()
      RTI.log_file = nil
   end

   ---
   if RTI.socket then
      RTI.socket:close()
      RTI.socket = nil
   end
end

--------------------------------------------------------------------------------
function LuaExportBeforeNextFrame()

end

--------------------------------------------------------------------------------
function LuaExportAfterNextFrame()

end

--------------------------------------------------------------------------------
function LuaExportActivityNextEvent(t)
   if (RTI.socket == nil) and (not connectTCPSocket()) then
      return (t + RTI.REPEAT_CONNECTION_INTERVAL)
   end

   RTI.data_str = "{ "

   local mdata = LoGetSelfData()
   if mdata then
      RTI.data_str = RTI.data_str .. "\"type\" : \"" .. mdata.Name .. "\", "
   else
      RTI.data_str = RTI.data_str .. "\"type\" : \"TestPlane\", "
   end

   local panel = LoGetControlPanel_HSI()
   if panel then
      addParam("compass", "%.3f", panel.Course * TO_DEG)
   end

   local ALT = LoGetAltitudeAboveSeaLevel()
   addParam("H, m", "%.3f", ALT)

   local RALT = LoGetAltitudeAboveGroundLevel()
   addParam("radio_altitude, m", "%.3f", RALT)

   local TAS = LoGetTrueAirSpeed()
   addParam("TAS, km/h", "%.3f", TAS * 3.6)

   local IAS = LoGetIndicatedAirSpeed()
   addParam("IAS, km/h", "%.3f", IAS * 3.6)

   local Mach = LoGetMachNumber()
   addParam("M", "%.3f", Mach)

   local Ny = LoGetAccelerationUnits()["y"]
   addParam("Ny", "%.3f", Ny)

   local Vy = LoGetVerticalVelocity()
   addParam("Vy, m/s", "%.3f", Vy)

   local AoA = LoGetAngleOfAttack()
   addParam("AoA, deg", "%.3f", AoA)

   local AoS = LoGetSlipBallPosition()
   addParam("AoS, deg", "%.3f", AoS)

   --
   local pitch, bank, yaw = LoGetADIPitchBankYaw()
   addParam("aviahorizon_roll", "%.3f", bank * TO_DEG)
   addParam("aviahorizon_pitch", "%.3f", pitch * TO_DEG)

   ---
   local engine = LoGetEngineInfo()
   if engine then
      --
      addParam("RPM throttle 1, %", "%.2f", engine.RPM.left)
      if engine.RPM.right then
         addParam("RPM throttle 2, %", "%.2f", engine.RPM.right)
      end

      local fuel = engine["fuel_internal"]
      fuel = fuel + engine["fuel_external"]
      addParam("fuel", "%.5f", fuel)

      --
      local fuel_consume = 0
      for key,value in pairs(engine.FuelConsumption) do
         fuel_consume = fuel_consume + value
      end
      fuel_consume = 60 * fuel_consume -- kg/sec -> kg/min
      addParam("fuel_consume", "%.3f", fuel_consume)
   end

   ----
   local mech = LoGetMechInfo()
   if mech then
      --
      addParam("gear, %", "%.2f", 100 * mech.gear.value)
      --
      addParam("flaps, %", "%.2f", 100 * mech.flaps.value)
      --
      addParam("airbrake, %", "%.2f", 100 * mech.speedbrakes.value)
   end

   ---
   RTI.data_str = RTI.data_str .. "\"valid\" : true }\0"


   ---
   sendData(RTI.data_str)

   return (t + RTI.UPDATE_INTERVAL)
end
