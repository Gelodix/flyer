local utils = require("flyer_files.utils")

local CONFIG = {}

CONFIG.FILE_NAME = "flyer_settings.cfg"




CONFIG.DEFAULTS = {
    tuning = {
        lowStablePower = 8,
        highStablePower = 9,
        travelHeight = 320,
        destinationRadius = 5,
        yawOffset = 0,
        kpYaw = 0.04,
        kdYaw = 0.4,
        maxTravelSpeed = 300,
        brakingFactor = 0.1333,
        trackerYOffset = 50,
    },

    autoStablePower = {
        enabled = true,
        thrusterCount = 4,
        thrusterMaxForce = 800,
    },

    bluemapUrl ="https://projectcrowbar.com/bluemap/maps/s3_overworld/live/players.json",

    relay = "front",

    inputs = {
        toggleAltitude   = { device = "computer", side = "top" },
        toggleAutopilot  = { device = "computer", side = "bottom" },
        changeAPMode     = { device = "computer", side = "left" },
        increaseAltitude = { device = "relay", side = "left" },
        decreaseAltitude = { device = "relay", side = "right" },
        scrollUp         = { device = "relay", side = "top" },
        scrollDown       = { device = "relay", side = "bottom" },
        confirmDest      = { device = "relay", side = "front" },
    },
    outputs = {
        upward   = { device = "relay", side = "front" },
        forward  = { device = "relay", side = "top" },
        backward = { device = "relay", side = "bottom" },
        left     = { device = "relay", side = "left" },
        right    = { device = "relay", side = "right" },
    },
    persistence = {
        enabled = true,
        interval = 1,
        altitude = true,
        destination = true,
        autopilot = false,
    }
}

local function merge(defaults, user)
    local out, changed = {}, false
    for k, default in pairs(defaults) do
        local value = user[k]
        if value == nil then
            changed = true
            value = type(default) == "table" and merge(default, {}) or default
        elseif type(default) == "table" and type(value) == "table" then
            local subChanged
            value, subChanged = merge(default, value)
            changed = changed or subChanged
        end
        out[k] = value
    end
    for k, v in pairs(user) do
        if out[k] == nil then out[k] = v end
    end
    return out, changed
end

function CONFIG.save(cfg)
    utils.secureWriteFile(CONFIG.FILE_NAME, false, textutils.serialize(cfg), true)
end

function CONFIG.load()
    local user = {}
    local content = utils.secureReadFile(CONFIG.FILE_NAME, false)
    if content then
        user = textutils.unserialize(content)
        if type(user) ~= "table" then
            error(CONFIG.FILE_NAME .. "is invalid (syntax error?)", 0)
        end
    end
    

    local cfg, changed = merge(CONFIG.DEFAULTS, user)
    if changed then CONFIG.save(cfg) end
    return cfg
end

return CONFIG