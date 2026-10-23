local ACTUATORS = {}

function ACTUATORS.run(ctx)
    local state, rsio = ctx.state, ctx.rsio
    local signal = ctx.utils.safeRsSignal
    
    while true do
        rsio.set("upward", state.heightControlEnabled and signal(state.thrustersStrength) or 0)

        if state.increaseAltitude then
            state.aimedHeight = state.aimedHeight + 1
        elseif state.decreaseAltitude then
            state.aimedHeight = state.aimedHeight - 1
        end

        rsio.set("forward", signal(state.forwardThrust))
        rsio.set("backward", signal(state.backwardThrust))
        rsio.set("left", signal(state.leftThrust))
        rsio.set("right", signal(state.rightThrust))

        sleep(0.05)
    end
end

return ACTUATORS