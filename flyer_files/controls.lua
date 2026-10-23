local CONTROLS = {}

local function selectedIndex(state, list)
    if #list == 0 then
        state.selectedTargetName = nil
        return nil
    end
    for i, item in ipairs(list) do 
        if item.name == state.selectedTargetName then return i end
    end

    state.selectedTargetName = list[1].name
    return 1
end

function CONTROLS.run(ctx)
    local state, rsio = ctx.state, ctx.rsio
    while true do
        os.pullEvent("redstone")

        if state.heightControlEnabled then
            local increaseSignal = rsio.get("increaseAltitude")
            local decreaseSignal = rsio.get("decreaseAltitude")
            state.increaseAltitude = increaseSignal and not decreaseSignal
            state.decreaseAltitude = not increaseSignal and decreaseSignal
        else
            state.increaseAltitude = false
            state.decreaseAltitude = false
        end

        if rsio.pressed("toggleAltitude") then
            state.heightControlEnabled = not state.heightControlEnabled
            if state.heightControlEnabled then
                state.aimedHeight = state.currentHeight
            end
        end

        if rsio.pressed("toggleAutopilot") then
            state:toggleAutopilot()
        end

        if rsio.pressed("changeAPMode") then
            state.isTrackerUI = not state.isTrackerUI
            state.selectedTargetName = nil
            state.playersUpdates = state.isTrackerUI
        end

        local scrollUp = rsio.pressed("scrollUp")
        local scrollDown = rsio.pressed("scrollDown")
        local confirm = rsio.pressed("confirmDest")

        local list = state.isTrackerUI and ctx.players or ctx.savedDestinations
        local index = selectedIndex(state, list)
        if index then
            if scrollUp then
                index = index > 1 and index -1 or #list
            end
            if scrollDown then
                index = index < #list and index + 1 or 1
            end

            local item = list[index]
            state.selectedTargetName = item.name
            
            if confirm then
                if state.isTrackerUI then
                    state:trackPlayer(item.name)
                else
                    state:setDestination(item.name, item.x, item.z, item.y)
                end
            end
        end
        state.monitorSelectedDest = state.selectedTargetName or "empty"
    end
end

return CONTROLS