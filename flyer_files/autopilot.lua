local utils = require("flyer_files.utils")

local AUTOPILOT = {}

local function stopHorizontal(state)
    state.forwardThrust = 0
    state.backwardThrust = 0
    state.leftThrust = 0
    state.rightThrust = 0
end

local function forwardSpeed(state)
    local heading = math.rad(90 - state.yaw + state.yawOffset)
    return state.xVelocity * math.cos(heading) + state.zVelocity * math.sin(heading)
end

local function brakeToStop(state)
    stopHorizontal(state)
    local speed = forwardSpeed(state)

    if math.abs(speed) <= state.arrivalSpeed then return true end

    local force = math.ceil(utils.clamp(math.abs(speed) * 2, 0, 15))
    if speed > 0 then 
        state.backwardThrust = force
    else
        state.forwardThrust = force
    end
    return false
end

local function steerLegacy(state, angleError, dt)
    local errorDelta = (angleError - state.lastAngleError + 180) % 360 - 180
    local errorRate = errorDelta / dt
    state.lastAngleError = angleError


    local speedMultiplier = 1 + (math.min(state.speed, 120)/20)
    local errorMultiplier = 1 + (math.abs(angleError)/45)
    local Kp = state.kpYaw * errorMultiplier * math.min(3, speedMultiplier)
    local Kd = state.kdYaw * speedMultiplier * 1.8
    local baseYawCorrection = (angleError * Kp) + (errorRate * Kd)

    local speedRatio = math.min(state.speed / 40, 1)
    local turnSeverityRatio = math.min(math.abs(angleError) / 60, 1)
    local maxTurnPower = 1 + (14* math.max(speedRatio, turnSeverityRatio))
    local yawCorrection = math.max(-maxTurnPower, math.min(maxTurnPower, baseYawCorrection))

    local dragCompensation = math.min(15, state.speed / 10)
    local errorFade = math.min(1, math.abs(angleError) / 25)
    local minTurnThrust = math.min(15, math.max(1, math.floor(dragCompensation * errorFade)))

    local deadband = 2 + math.min(5, state.speed / 50)

    state.leftThrust = 0
    state.rightThrust = 0
    if math.abs(angleError) > deadband then
        if yawCorrection > 0 then
            state.leftThrust = math.max(minTurnThrust,math.floor(yawCorrection))
        else
            state.rightThrust = math.max(minTurnThrust,math.floor(math.abs(yawCorrection)))
        end
    end
end

local turnResidual = 0

local function steerRate(state, settings, angleError)
    state.leftThrust = 0
    state.rightThrust = 0
    if math.abs(angleError) < settings.headingDeadBand and math.abs(state.yawRate) < settings.rateDeadband then
        turnResidual = 0
        return
    end

    local targetRate = utils.clamp(angleError * settings.headingGain, -settings.maxYawRate, settings.maxYawRate)
    local thrust = utils.clamp((targetRate - state.yawRate) * settings.rateGain, -settings.maxTurnThrust, settings.maxTurnThrust)

    turnResidual = turnResidual + math.abs(thrust)
    local level = math.floor(turnResidual)
    turnResidual = turnResidual - level
    if thrust > 0 then
        state.leftThrust = level
    else
        state.rightThrust = level
    end
end

local function hover(state, approachSpeed, targetSpeed, isTargetBehind)
    state.forwardThrust = 0
    state.backwardThrust = 0
    if isTargetBehind then
        if approachSpeed > targetSpeed then
            state.forwardThrust = math.floor(math.min(15, (approachSpeed - targetSpeed) * 5))
        else
            state.backwardThrust = math.floor(math.min(15, (targetSpeed - approachSpeed) * 2))
        end
    else
        if approachSpeed < targetSpeed then
            state.forwardThrust = math.floor(math.min(15, (targetSpeed - approachSpeed) * 2))
        else
            state.backwardThrust = math.floor(math.min(15, (approachSpeed - targetSpeed) * 5))
        end
    end
end

local function cruise(state, angleError, approachSpeed, targetSpeed)
    local distanceClamped = math.max(50, math.min(500, state.destinationDistance))
    local acceptedAngle = 5 + (25 * (distanceClamped - 50) /450)
    state.forwardThrust = 0
    state.backwardThrust = 0
    if math.abs(angleError) <= acceptedAngle then
        if approachSpeed > targetSpeed then
            local brakeForce = (approachSpeed - targetSpeed) * 2
            state.backwardThrust = math.floor(math.max(0, math.min(15, brakeForce)))
        else
            local accelForce = (targetSpeed - approachSpeed) * 2
            state.forwardThrust = math.floor(math.max(0, math.min(15, accelForce)))
        end
    elseif approachSpeed > 3 then
        state.backwardThrust = math.floor(math.min(15, state.speed * 2))
    end
end

local function update(state, cfg)
    local dx = state.destination_x - state.x
    local dz = state.destination_z - state.z
    state.destinationDistance =  math.sqrt(dx^2 + dz^2)

    local approachSpeed = 0
    local targetAwaySpeed = 0
    if state.destinationDistance > 0 then
        local dirX = dx / state.destinationDistance
        local dirZ = dz / state.destinationDistance
        approachSpeed = (state.xVelocity * dirX) + (state.zVelocity * dirZ)

        if state.trackerEnabled then
            targetAwaySpeed = (state.target_velocityX * dirX) + (state.target_velocityZ * dirZ)
        end
    end

    state.aimedAngle = (90 - math.deg(math.atan2(dz, dx)) + state.yawOffset) % 360

    local currentTime = os.clock()
    local dt = currentTime - state.lastTime
    if dt <= 0 then dt = 0.05 end
    state.lastTime = currentTime

    if state.trackerEnabled and state.destinationDistance < 250 then
        state.aimedHeight = state.destination_y
    else
        state.aimedHeight = state.travelHeight
    end

    if state.destinationDistance <= state.destinationRadius and not state.trackerEnabled then
        state.aimedHeight = state.destination_y
        if brakeToStop(state) then
            state.autopilotEnabled = false
        end        
        return
    end
        
    local currentAngle = state.yaw
    local targetAngle = state.aimedAngle
    local rawAngleError = (targetAngle - currentAngle + 180) % 360 - 180
    local angleError = rawAngleError

    local isTargetBehind = math.abs(rawAngleError) > 90
    local isHovering = state.trackerEnabled and state.trackedPlayerName ~= nil and state.destinationDistance < 40

    if isHovering then
        state.aimedAngle = state.yaw
        state.lastAngleError = 0
        state.leftThrust = 0
        state.rightThrust = 0
        if isTargetBehind then
            if angleError > 0 then
                state.leftThrust = 1
            else
                state.rightThrust = 1
            end
        end
        angleError = 0
    elseif cfg.steering.useLegacy then
        steerLegacy(state, angleError, dt)
    else
        steerRate(state, cfg.steering, angleError)
    end

    local baseTargetSpeed = math.max(0, (state.destinationDistance - state.destinationRadius) * state.brakingFactor)
    if baseTargetSpeed > 0 and baseTargetSpeed < state.minApproachSpeed then
        baseTargetSpeed = state.minApproachSpeed
    end

    local targetSpeed = math.min(state.maxTravelSpeed, baseTargetSpeed + targetAwaySpeed)

    if isHovering then
        hover(state, approachSpeed, targetSpeed, isTargetBehind)
    else
        cruise(state, angleError, approachSpeed, targetSpeed)
    end
end

function AUTOPILOT.run(ctx)
    local state = ctx.state
    while true do
        if not state.hasSetDestination then
            state.autopilotEnabled = false
        end

        if state.autopilotEnabled and (state.hasSetDestination or state.trackerEnabled) then
            update(state, ctx.cfg)
        else
            stopHorizontal(state)
        end
        sleep(0.05)
    end
end

return AUTOPILOT