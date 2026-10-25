local RSIO = {}

local SIDES = {}

for _, side in ipairs(redstone.getSides()) do
    SIDES[side] = true
end

local inputs, outputs, lastValues = {}, {}, {}

local relays = {}

local function resolveName(cfg, device)
    return (cfg.relays and cfg.relays[device]) or device
end

local function wrapRelay(name)
    if relays[name] then return relays[name] end
    if not peripheral.isPresent(name) then return nil, "no peripheral on '" .. name .."'" end
    if not peripheral.hasType(name, "redstone_relay") then return nil, "'" .. name .. "' isn't a redstone_relay" end
    relays[name] = peripheral.wrap(name)
    return relays[name]
end

local function bind(kind, pins, dest, cfg, used)
    for name, pin in pairs(pins) do
        if pin then
            local label = kind .. " '" .. name .. "'"
            if not SIDES[pin.side] then
                error(label .. ": invalid side '" .. tostring(pin.side) .. "'", 0)
            end


            local device, deviceName
            if pin.device == "computer" then
                device, deviceName = redstone, "computer"
            elseif type(pin.device) == "string" then
                deviceName = resolveName(cfg, pin.device)
                local err
                device, err = wrapRelay(deviceName)
                if not device then error(label .. ": " .. err, 0) end
            else
                error(label .. ": device missing", 0)
            end
            

            local key = deviceName .. ":" .. pin.side
            if used[key] then
                error(("%s: %s is already used by %s"):format(label, key, used[key]), 0)
            end
            used[key] = label
            dest[name] = { device = device, side = pin.side }
        end
    end
end

function RSIO.init(cfg)
    inputs, outputs, lastValues, relays = {},{},{},{}

    bind("input", cfg.inputs, inputs, cfg, {})
    bind("output", cfg.outputs, outputs, cfg, {})
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