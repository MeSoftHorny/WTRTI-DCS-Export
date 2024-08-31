--- Copy these lines to the end of the Export.lua file.
local wtrti_res, wtrti_err = pcall(function() local lfs=require('lfs'); dofile(lfs.writedir() .. 'Scripts/WTRTI.lua'); end)
if not wtrti_res then log.write("WTRTI:EXPORT", log.ERROR, wtrti_err) end
