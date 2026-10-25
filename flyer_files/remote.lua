local auth = require("flyer_files.auth")

local REMOTE = {}

local MIN_PASSWORD_LENGHT = 12
local MIN_HEIGHT, MAX_HEIGHT = -64, 5000
local MAX_COORDINATE = 10000

local enabled = false

local function isNumber(value)
    return type(value) == "number" and value == value 
end

local function clampHeight(value)
    return math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, value))
end

local function isCoordinates(value)
    return isNumber(value) and math.abs(value) <= MAX_COORDINATE
end

local COMMANDS = {}

function COMMANDS.status()
    return true
end

function COMMANDS.setHeightControl(ctx, value)
    if type(value) ~= "boolean" then return false, "boolean expected" end
    local state = ctx.state
    if value and not state.heightControlEnabled then
        state.aimedHeight = state.currentHeight
    end

    state.heightControlEnabled = value
    return true
end

function COMMANDS.setAimedHeight(ctx, value)
    if not isNumber(value) then return false, "number expected" end
    ctx.state.aimedHeight = clampHeight(value)
    return true
end

function COMMANDS.setAutopilot(ctx, value)
    if type(value) ~= "boolean" then return false, "boolean expected" end
    local state = ctx.state
    if state.autopilotEnabled == value then return true end
    if value and not state.hasSetDestination then return false, "no destination" end
    state:toggleAutopilot()
    return true
end


function COMMANDS.setTravelHeight(ctx, value)
    if not isNumber(value) then return false, "number expected" end
    ctx.state.travelHeight = clampHeight(value)
    return true
end

function COMMANDS.setDestination(ctx, value)
    if type(value) == "string" then
        for _, dest in ipairs(ctx.savedDestinations) do
            if dest.name == value then
                ctx.state:setDestination(value, dest.x, dest.z, dest.y)
                return true
            end
        end
        return false, "unknown destination"
    end

    if type(value) ~= "table" or not isCoordinates(value.x) or not isCoordinates(value.z) or (value.y ~= nil and not isNumber(value.y)) then
        return false, "{x, z, y?} expected"
    end
    local name = type(value.name) == "string" and value.name or nil
    ctx.state:setDestination(name, value.x, value.z, value.y and clampHeight(value.y))
    return true
end

local function status(state)
    return {
        x = state.x,
        z = state.z,
        currentHeight = state.currentHeight,
        speed = state.speed,
        heightControlEnabled = state.heightControlEnabled,
        aimedHeight = state.aimedHeight,
        autopilotEnabled = state.autopilotEnabled,
        travelHeight = state.travelHeight,
        hasSetDestination = state.hasSetDestination,
        destinations = state.hasSetDestination and {
            name = state.destName,
            x = state.destination_x,
            z = state.destination_z,
            y = state.destination_y,
            distance = state.destinationDistance,
        } or nil,
    }
end

function REMOTE.init(cfg)
    local settings = cfg.rednet
    enabled = false

    if not settings.enabled then return false end

    if #settings.password < MIN_PASSWORD_LENGHT then
        printError(("Rednet off: password must be at least %d characters"):format(MIN_PASSWORD_LENGHT))
        return false
    end

    local modem = settings.modem
    if not (modem and peripheral.hasType(modem, "modem")) then
        printError(("Rednet off: no modem on '" .. tostring(modem) .. "'"))
        return false
    end

    rednet.open(modem)
    enabled = true
    print(("Rednet on (#%d, protocol '%s')"):format(os.getComputerID(), settings.protocol))
    return true
end

function REMOTE.run(ctx)
    if not enabled then return end
    local settings = ctx.cfg.rednet

    while true do
        local sender, request = rednet.receive(settings.protocol)
        if auth.verify(request, settings.password) then
            local handler =  COMMANDS[request.command]
            local ok, message

            if handler then
                local success, result, info = pcall(handler, ctx, request.value)
                if success then
                    ok, message =  result, info
                else
                    ok, message = false, "error: " .. tostring(result)
                end
            else
                ok, message = false, "unknown command"
            end

            local reply = auth.sign({
                target = sender,
                command = "reply",
                value = { ok = ok, message = message, status = status(ctx.state)},
            }, settings.password)
            rednet.send(sender, reply, settings.protocol)
        end
    end

end

return REMOTE