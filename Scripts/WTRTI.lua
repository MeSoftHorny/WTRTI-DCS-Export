--------------------------------------------------------------------------------
-- 2024 - avb
-- v0.2.1
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
   ["A-10A"]            = "a_10a_late",
   ["A-10C"]            = "a_10a_late",
   ["AH-64D"]           = "ah_64d",
   ["AH-64D_BLK_II"]    = "ah_64d",
   ["AJS37"]            = "saab_ajs37",
   ["AV8BNA"]           = "av_8b_plus",
   ["Bf-109K-4"]        = "bf-109k-4",
   ["F-14B"]            = "f_14b",
   ["F-14A-135-GR"]     = "f_14a_early",
   ["F-15C"]            = "f_15c_baz_msip",
   ["F-15ESE"]          = "f_15a",
   ["F-16C_50"]         = "f_16c_block_50",
   ["F-16D_50_NS"]      = "f_16d_block_40_barak_2",
   ["F-16D_50"]         = "f_16d_block_40_barak_2",
   ["F-16D_52_NS"]      = "f_16d_block_40_barak_2",
   ["F-16D_52"]         = "f_16d_block_40_barak_2",
   ["F-16D_Barak_30"]   = "f_16d_block_40_barak_2",
   ["F-16D_Barak_40"]   = "f_16d_block_40_barak_2",
   ["F-16I"]            = "f_16c_block_50", -- ?
   ["F-4E"]             = "f-4e",
   ["F-5E-3"]           = "f-5e",
   ["F-86F Sabre"]      = "f-86f-2",
   ["FW-190A8"]         = "fw-190a-8",
   ["FW-190D9"]         = "fw-190a-9",
   ["Ka-50"]            = "ka_50",
   ["M-2000C"]          = "mirage_2000_5f",
   ["MH-60R"]           = "mh_60l_dap",
   ["Mi-24P"]           = "mi_24p",
   ["Mi-8MT"]           = "mi_8tv",
   ["MiG-15bis"]        = "mig-15bis_ish",
   ["MiG-19P"]          = "mig-19pt",
   ["MiG-21Bis"]        = "mig-21_bis",
   ["MirageF1"]         = "mirage_f1c",
   ["Mosquito"]         = "mosquito_fb_mk6",
   ["OH-58D"]           = "oh_58d",
   ["P-47D-30"]         = "p-47d_30_italy",
   ["P-47D-30bl1"]      = "p-47d_30_italy",
   ["P-47D-40"]         = "p-47d_30_italy",
   ["P-51D"]            = "p-51d-30_usaaf_korea",
   ["P-51D-30-NA"]      = "p-51d-30_usaaf_korea",
   ["TF-51D"]           = "p-51d-30_usaaf_korea",
   ["SA342"]            = "sa_342m",
   ["SpitfireLFMkIX"]   = "spitfire_ix",
   ["UH-1H"]            = "uh_1b",
   ["Su-25T"]           = "su_25t",
   ["Su-25"]            = "su_25",
   ["Su-27"]            = "su_27",
   ["J-11"]             = "j_11",
   ["I-16"]             = "i-16_type24",
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
