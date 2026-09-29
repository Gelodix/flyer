local TRACKER = {}

local REFRESH_DELAY = 3 -- in seconds

local function fetchLivePlayers(ctx)
    local body = ctx.utils.download(ctx.cfg.bluemapUrl)
    local parsed = body and textutils.unserializeJSON(body)
    return parsed and parsed.players or {}
end

local function followPlayer(state, player)
    local currentTime = os.clock()
    local dt_track = currentTime - state.lastTrackTime

    if dt_track > 0 and dt_track < 10 and state.hasSetDestination then
        local vx = (player.position.x - state.destination_x) / dt_track
        local vz = (player.position.z - state.destination_z) / dt_track

        if math.abs(vx) < 150 and math.abs(vz) < 150 then
            state.target_velocityX = vx
            state.target_velocityZ = vz
        else
            state.target_velocityX = 0
            state.target_velocityZ = 0
        end
    end

    state.lastTrackTime = currentTime
    state.destination_x = player.position.x
    state.destination_z = player.position.z
    state.destination_y = player.position.y + state.trackerYOffset
end

function TRACKER.run(ctx)
    local state = ctx.state
    while true do
        if state.isTrackerUI or state.trackerEnabled then
            ctx.players  = fetchLivePlayers(ctx)
            state.playersUpdates = true

            if state.trackerEnabled and state.trackedPlayerName then
                for _, player in ipairs(ctx.players) do
                    if player.name == state.trackedPlayerName then
                        followPlayer(state, player)
                        break
                    end
                end
            end
        end
        sleep(REFRESH_DELAY)
    end
end

return TRACKER