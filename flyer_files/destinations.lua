local utils = require("flyer_files.utils")
local DESTINATIONS = {}


local FILE = "destinations.json"

local DEFAULTS = {
    {name = "Base", x = 1223, z = 520, y = 90},
    {name = "SD", x = 1288, z = -440, y = 80},
    {name = "Element_Liga's Base", x = 1407, z = -2241, y = 320},
    {name = "Airport", x = 1343, z = -1131, y = 70},
}

function DESTINATIONS.save(list)
    utils.secureWriteFile(FILE, false, textutils.serializeJSON(list), true)
end

function DESTINATIONS.load()
    local content = utils.secureReadFile(FILE, false)
    if content then
        return textutils.unserializeJSON(content) or {}
    end
    DESTINATIONS.save(DEFAULTS)
    return DEFAULTS
end

return DESTINATIONS