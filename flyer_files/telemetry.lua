local TELEMETRY = {}

function TELEMETRY.run(ctx)
    local state, utils = ctx.state, ctx.utils
        while true do 
        if sublevel and sublevel.isInPlotGrid() then
            local pose = sublevel.getLogicalPose()

            if pose.position then
                state.x = pose.position.x
                state.currentHeight = pose.position.y
                state.z = pose.position.z
            end

            if pose.orientation and pose.orientation.v then
                local w = pose.orientation.a
                local x = pose.orientation.v.x
                local y = pose.orientation.v.y
                local z = pose.orientation.v.z

                local rawYawDeg = utils.yawFromQuaternion(w, x, y, z)
                state.yaw = (rawYawDeg + 360) % 360
            end

            local velocity = sublevel.getLinearVelocity()
            if velocity then
                state.speed = math.sqrt(velocity.x^2 + velocity.z^2)
                state.xVelocity = velocity.x
                state.yVelocity = velocity.y
                state.zVelocity = velocity.z
            end
        end
        sleep(0.05)
    end
end

return TELEMETRY