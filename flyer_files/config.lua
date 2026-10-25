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
        arrivalSpeed = 0.5,
        minApproachSpeed = 3,
    },

    autoStablePower = {
        enabled = true,
        thrusterCount = 4,
        thrusterMaxForce = 800,
    },

    altitudeController = {
        useLegacy = true,
        heightGain = 0.5,
        maxClimbSpeed = 10,
        maxDescentSpeed = 8,
        speedGain = 1,
        learningRate = 0.2,
    },

    bluemapUrl ="https://projectcrowbar.com/bluemap/maps/s3_overworld/live/players.json",

    -- optional aliases for the relays used for I/O. Ex: { front_relay = "redstone_relay_35"}
    relays = {},

    inputs = {
        toggleAltitude   = { device = "computer", side = "top" },
        toggleAutopilot  = { device = "computer", side = "bottom" },
        changeAPMode     = { device = "computer", side = "left" },
        increaseAltitude = { device = "front", side = "left" },
        decreaseAltitude = { device = "front", side = "right" },
        scrollUp         = { device = "front", side = "top" },
        scrollDown       = { device = "front", side = "bottom" },
        confirmDest      = { device = "front", side = "front" },
    },
    outputs = {
        upward   = { device = "front", side = "front" },
        forward  = { device = "front", side = "top" },
        backward = { device = "front", side = "bottom" },
        left     = { device = "front", side = "left" },
        right    = { device = "front", side = "right" },
    },
    persistence = {
        enabled = true,
        interval = 1,
        altitude = true,
        destination = true,
        autopilot = false,
    },
    rednet = {
        enabled = false,
        modem = "left",
        protocol = "flyer",
        password = "",
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

local function migrate(user)
    if type(user.relay) ~= "string" then return false end
    for _, pins in ipairs({user.inputs or {}, user.outputs or {}}) do
        for _, pin in pairs(pins) do
            if type(pin) == "table" and pin.device == "relay" then 
                pin.device = user.relay 
            end
        end
    end
    user.relay = nil
    return true
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
            error(CONFIG.FILE_NAME .. " is invalid (syntax error?)", 0)
        end
    end
    
    local migrated = migrate(user)
    local cfg, changed = merge(CONFIG.DEFAULTS, user)
    if changed or migrated then CONFIG.save(cfg) end
    return cfg
end

return CONFIG