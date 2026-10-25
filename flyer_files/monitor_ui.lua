local MONITOR_UI = {}

function MONITOR_UI.create(ctx)
    local state, basalt = ctx.state, ctx.basalt
    local frame = basalt.createFrame():setTerm(ctx.monitor)

    local labelCurrentAltitude = frame:addLabel():setPosition(2, 1)
    local labelAimedAltitude = frame:addLabel():setPosition(2, 2)
    
    local labelSelection = frame:addLabel():setPosition(2,3):setText("Sel: --")
    
    local labelAutopilot = frame:addLabel():setPosition(2,4)
    local labelHeightControl = frame:addLabel():setPosition(10,4)
    
    local labelSpeed = frame:addLabel():setPosition(2,5)

    basalt.schedule(function()
        while true do
            labelCurrentAltitude:setText("Current Y : " .. math.floor(state.currentHeight))
            labelAimedAltitude:setText(("Aimed Y : %.1f"):format(state.aimedHeight))

            local prefix = state.isTrackerUI and "[P]" or "[D]"
            labelSelection:setText(prefix .. (state.monitorSelectedDest or "None"))

            if state.monitorSelectedDest == state.destName then
                labelSelection:setForeground(colors.lightBlue)
            else
                labelSelection:setForeground(colors.white)
            end

            if state.heightControlEnabled then
                labelHeightControl:setBackground(colors.green):setText("AC: ON")
            else
                labelHeightControl:setBackground(colors.red):setText("AC: OFF")
            end

            if state.autopilotEnabled then
                labelAutopilot:setBackground(colors.green):setText("AP: ON")
            else
                labelAutopilot:setBackground(colors.red):setText("AP: OFF")
            end
            labelSpeed:setText(string.format("Speed: %1.f m/s", state.speed))
            sleep(0.1)
        end
    end)
end

return MONITOR_UI