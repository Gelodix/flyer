local utils = require("flyer_files.utils")

local ALTITUDE = {}

local function computeLegacyThrust(state)
    local heightDelta = (state.currentHeight - 1) - state.aimedHeight
    if heightDelta > 0 then -- above aimedHeight
        if heightDelta > 100 then return state.lowStablePower - 5 end
        if heightDelta > 10 then return state.lowStablePower - 3 end
        if heightDelta > 5 then return state.lowStablePower - 1 end
        return state.lowStablePower
    end

    if heightDelta < -100 then return state.highStablePower + 5 end
    if heightDelta < -10 then return state.highStablePower + 3 end
    if heightDelta < -5 then return state.highStablePower + 1 end
    return state.highStablePower
end

local residual = 0

local function computeThrust(state, settings, dt)
    local heightError = state.aimedHeight - (state.currentHeight - 1)
    local targetSpeed = utils.clamp(heightError * settings.heightGain, -settings.maxDescentSpeed, settings.maxClimbSpeed)
    local speedError = targetSpeed - state.yVelocity

    local level = state.hoverLevel + speedError * settings.speedGain
    if level > 0 and level < 15 then
        state.hoverLevel = utils.clamp(state.hoverLevel + speedError * settings.learningRate * dt, 0, 15)
    end
    level = utils.clamp(level, 0, 15)
    residual = residual + level
    local output = math.floor(residual)
    residual = residual - output
    return output
end

local function computeStablePowers(settings)
    local gravity = aero.getGravity()
    local g = gravity.length and gravity:length() or math.abs(gravity.y or gravity)
    local weight = sublevel.getMass() * g

    local forcePerLevel = settings.thrusterMaxForce / 15

    local level = weight / (settings.thrusterCount * forcePerLevel)

    local low = math.floor(level + 1e-9)
    local high = low + 1

    if level >= 15 then
        print("Missing thrust, add more thrusters")
    end

    return utils.clamp(low, 0, 15),
           utils.clamp(high, 0, 15),
           utils.clamp(level, 0, 15)
end

function ALTITUDE.run(ctx)
    local state, rsio = ctx.state, ctx.rsio
    local settings = ctx.cfg.altitudeController

    local exactLevel
    local auto = ctx.cfg.autoStablePower
    if auto.enabled then
        local ok, low, high, level = pcall(computeStablePowers, auto)
        if ok then
            state.lowStablePower, state.highStablePower = low, high
            exactLevel = level
        end
    end

    state.hoverLevel = exactLevel or (state.lowStablePower + state.highStablePower) /2

    local lastTime = os.clock()
    while true do 
        local now = os.clock()
        local dt = math.max(now - lastTime, 0.05)
        lastTime = now
        if not state.heightControlEnabled then
            residual = 0
            state.thrustersStrength = rsio.get("increaseAltitude") and 15 or 0
              
        elseif settings.useLegacy then
            state.thrustersStrength = computeLegacyThrust(state) 
        else
            state.thrustersStrength = computeThrust(state, settings, dt)
        end
        sleep(0.05)
    end
end

return ALTITUDE