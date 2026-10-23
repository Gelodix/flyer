local ALTITUDE = {}

local function computeThrust(state)
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

    return math.max(0, math.min(15, low)),
           math.max(0, math.min(15, high))
end

function ALTITUDE.run(ctx)
    local state, rsio = ctx.state, ctx.rsio
    local auto = ctx.cfg.autoStablePower
    if auto.enabled then
        local ok, low, high = pcall(computeStablePowers, auto)
        if ok then
            state.lowStablePower, state.highStablePower = low, high
        end
    end

    while true do 
        if state.heightControlEnabled then
            state.thrustersStrength = computeThrust(state)   
        else 
            state.thrustersStrength = rsio.get("increaseAltitude") and 15 or 0
        end
        sleep(0.05)
    end
end

return ALTITUDE