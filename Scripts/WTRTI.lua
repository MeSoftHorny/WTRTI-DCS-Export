--------------------------------------------------------------------------------
-- 2024 - avb
-- v0.2
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
RTI.connect_try = 0

RTI.vehicle_name = ""

local vehicles = {
   ["Su-25T"] = "su_25t",
}

--------------------------------------------------------------------------------
-- Util
--------------------------------------------------------------------------------
package.path  = package.path..";"..lfs.currentdir().."/LuaSocket/?.lua"
package.cpath = package.cpath..";"..lfs.currentdir().."/LuaSocket/?.dll"

--------------------------------------------------------------------------------
function connectTCPSocket()
   if socket_lib == nil then return end

   local socket = socket_lib.tcp()
   socket:settimeout(0.1)
   socket:setoption("tcp-nodelay", true)

   local ret = socket:connect("127.0.0.1", RTI.SOCKET_PORT)
   if ret ~= nil then
      writeToLog("INFO: Connected to the port: " .. RTI.SOCKET_PORT)

      RTI.socket = socket

      return true
   else
      writeToLog("ERROR: No Connection with WTRTI")

      return false
   end
end

--------------------------------------------------------------------------------
function sendData(data)
   local ret, err, num = RTI.socket:send(data)
   if ret == nil then
      writeToLog("ERROR: " .. err)

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

   socket_lib = require("socket")
   if socket_lib then
      connectTCPSocket()
   else
      writeToLog("ERROR: LuaSocket is not loaded")
   end

   ---
   local mdata = LoGetSelfData()
   if mdata then
      local veh = vehicles[mdata.Name]
      if veh then
         RTI.vehicle_name = veh
      else
         RTI.vehicle_name = mdata.Name
      end
   else
      RTI.vehicle_name = "TestPlane"
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
-- function LuaExportBeforeNextFrame()
--
-- end

--------------------------------------------------------------------------------
-- function LuaExportAfterNextFrame()
--
-- end

--------------------------------------------------------------------------------
function LuaExportActivityNextEvent(t)
   if RTI.socket == nil then
      return (t + RTI.REPEAT_CONNECTION_INTERVAL)
   end

   RTI.data_str = "{ "
   RTI.data_str = RTI.data_str .. "\"type\" : \"" .. RTI.vehicle_name .. "\", "

   -- local panel = LoGetControlPanel_HSI()
   -- if panel then
   --    addParam("compass", "%.3f", panel.Heading_raw * TO_DEG)
   -- end
   local mdata = LoGetSelfData()
   if mdata then
      addParam("compass", "%.3f", mdata.Heading * TO_DEG)
   end

   local ALT = LoGetAltitudeAboveSeaLevel()
   addParam("H, m", "%.3f", ALT)

   local RALT = LoGetAltitudeAboveGroundLevel()
   addParam("radio_altitude, m", "%.3f", RALT)

   local TAS = LoGetTrueAirSpeed()
   if TAS then
      addParam("TAS, km/h", "%.3f", TAS * 3.6)
   end

   local IAS = LoGetIndicatedAirSpeed()
   if IAS then
      addParam("IAS, km/h", "%.3f", IAS * 3.6)
   end

   local Mach = LoGetMachNumber()
   addParam("M", "%.3f", Mach)

   local Acc = LoGetAccelerationUnits()
   if Acc then
      addParam("Ny", "%.3f", Acc["y"])
   end

   local Vy = LoGetVerticalVelocity()
   addParam("Vy, m/s", "%.3f", Vy)

   local AoA = LoGetAngleOfAttack()
   addParam("AoA, deg", "%.3f", AoA)

   local slip = LoGetSlipBallPosition()
   addParam("slip", "%.3f", slip)

   local mYaw = LoGetMagneticYaw()
   addParam("magnetic_yaw", "%.3f", mYaw)

   --
   local pitch, bank, yaw = LoGetADIPitchBankYaw()
   if bank then
      addParam("aviahorizon_roll", "%.3f", -bank * TO_DEG)
   end
   if pitch then
      addParam("aviahorizon_pitch", "%.3f", -pitch * TO_DEG)
   end

   ---
   local engine = LoGetEngineInfo()
   if engine then
      ---
      if engine.RPM then
         addParam("RPM throttle 1, %", "%.2f", engine.RPM.left)
         if engine.RPM.right then
            addParam("RPM throttle 2, %", "%.2f", engine.RPM.right)
         end
      end

      --- fuel
      local fuel = engine["fuel_internal"]
      if fuel then
         ---
         local fuel_ext = engine["fuel_external"]
         if fuel_ext then
            fuel = fuel + fuel_ext
         end

         addParam("fuel", "%.5f", fuel)
         addParam("Mfuel, kg", "%.5f", fuel)
      end

      -- fuel consumption
      local fuel_consume = 0
      for key,value in pairs(engine.FuelConsumption) do
         fuel_consume = fuel_consume + value
      end
      fuel_consume = 60 * fuel_consume -- kg/sec -> kg/min
      addParam("fuel_consume", "%.3f", fuel_consume)

      -- temperature
      if engine.Temperature then
         addParam("head_temperature", "%.2f", engine.Temperature.left)
         if engine.Temperature.right then
            addParam("head_temperature1", "%.2f", engine.Temperature.right)
         end
      end
   end

   ----
   local mech = LoGetMechInfo()
   if mech then
      --
      if mech.gear then
         addParam("gear, %", "%.2f", 100 * mech.gear.value)
      end

      --
      if mech.flaps then
         addParam("flaps, %", "%.2f", 100 * mech.flaps.value)
      end

      --
      if mech.speedbrakes then
         addParam("airbrake, %", "%.2f", 100 * mech.speedbrakes.value)
      end

      ---
      if mech.airintake then
         addParam("radiator 1, %", "%.2f", 100 * mech.airintake.value)
      end
   end

   ---
   RTI.data_str = RTI.data_str .. "\"valid\" : true }\0"


   ---
   sendData(RTI.data_str)

   return (t + RTI.UPDATE_INTERVAL)
end
