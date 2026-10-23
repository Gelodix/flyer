local RSIO = {}

local SIDES = {}

for _, side in ipairs(redstone.getSides()) do
    SIDES[side] = true
end

local inputs, outputs, lastValues = {}, {}, {}

local function wrapRelay(name)
    if not name then return nil, "no relay configured" end
    if not peripheral.isPresent(name) then return nil, "no peripheral on '" .. name .."'" end
    if not peripheral.hasType(name, "redstone_relay") then return nil, "'" .. name .. "' isn't a redstone_relay" end
    return peripheral.wrap(name)
end

local function bind(kind, pins, dest, relay, relayErr, used)
    for name, pin in pairs(pins) do
        if pin then
            local label = kind .. " '" .. name .. "'"
            local device
            if pin.device == "computer" then
                device = redstone
            elseif pin.device == "relay" then
                device = relay or error(label .. " uses the relay: " .. relayErr, 0)
            else
                error(label .. ": unknown device '" .. tostring(pin.device) .. "' (computer or relay)", 0)
            end
            if not SIDES[pin.side] then
                error(label .. ": invalid side '" .. tostring(pin.side) .. "'", 0)
            end

            local key = pin.device .. ":" .. pin.side
            if used[key] then
                error(("%s: %s is already used by %s"):format(label, key, used[key]), 0)
            end
            used[key] = label
            dest[name] = { device = device, side = pin.side }
        end
    end
end

function RSIO.init(cfg)
    local relay, relayErr = wrapRelay(cfg.relay)

    local reserved = {}
    if cfg.relay and SIDES[cfg.relay] then
        reserved["computer:" .. cfg.relay] = "the relay"
    end

    inputs, outputs, lastValues = {}, {}, {}
    bind("input", cfg.inputs, inputs, relay, relayErr, setmetatable({}, { __index = reserved }))
    bind("output", cfg.outputs, outputs, relay, relayErr, setmetatable({}, { __index = reserved }))
    RSIO.reset()
end

function RSIO.get(name)
    local pin = inputs[name]
    return pin ~= nil and pin.device.getInput(pin.side)
end

function RSIO.pressed(name)
    local now = RSIO.get(name)
    local before = lastValues[name]
    lastValues[name] = now
    return now and not before
end

function RSIO.set(name, value)
    local pin = outputs[name]
    if pin then pin.device.setAnalogOutput(pin.side, value) end
end

function RSIO.reset()
    for _, pin in pairs(outputs) do
        pin.device.setOutput(pin.side, false)
    end
end

return RSIO