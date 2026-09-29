local STATE = {}

local METHODS = {}

function METHODS:toggleAutopilot()
    if not self.hasSetDestination then return end
    self.autopilotEnabled = not self.autopilotEnabled
    if self.autopilotEnabled then
        self.aimedHeight = self.travelHeight
        self.heightControlEnabled = true
    end
end

function METHODS:setDestination(name, x, z, y)
    self.destination_x = x
    self.destination_z = z
    self.destination_y = y or self.currentHeight
    self.hasSetDestination = true
    self.trackerEnabled = false
    self.trackedPlayerName = nil
    self.destName = name
end

function METHODS:trackPlayer(name)
    self.trackedPlayerName = name
    self.trackerEnabled = true
    self.hasSetDestination = true
    self.destName = name
end

function STATE.new(cfg)
    local state = {
        -- telemetry
        x = 0,
        currentHeight = 0,
        z = 0,
        yaw = 0,
        speed = 0,
        xVelocity = 0,
        zVelocity = 0,

        -- altitude control
        aimedHeight = 60,
        thrustersStrength = 0,
        heightControlEnabled = false,
        increaseAltitude = false,
        decreaseAltitude = false,

        -- autopilot logic
        autopilotEnabled = false,
        hasSetDestination = false,
        destination_x = 0,
        destination_y = 0, -- height at which set the altitude control when the destination is reached
        destination_z = 0,
        destinationDistance = 0,
        aimedAngle = 0,
        lastAngleError = 0,
        lastTime = os.clock(),

        -- player tracker
        isTrackerUI = false,
        trackedPlayerName = nil,
        trackerEnabled = false,
        playersUpdates = false,
        target_velocityX = 0,
        target_velocityZ = 0,
        lastTrackTime = os.clock(),

        -- actuator values
        forwardThrust = 0,
        backwardThrust = 0,
        leftThrust = 0,
        rightThrust = 0,

        -- monitor selection
        selectedTargetName = nil,
        destName = nil,
        monitorSelectedDest = "None",
    }

    for k, v in pairs(cfg.tuning) do state[k] = v end
    return setmetatable(state, {__index = METHODS })
end

return STATE