local UI = {}

local function cleanAltitudeInput(self)
    local value = self:getText()
    if type(value) ~= "string" then return end
    local cleanValue = value:gsub(",", "."):gsub("[^%d%.]", "")
    local integer, dot, decimals = cleanValue:match("^(%d*)(%.?)(%d*)")
    cleanValue = integer:sub(1, 4) .. dot .. decimals:sub(1, 2)
    if value ~= cleanValue then
        self:setText(cleanValue)
    end
end

local function cleanCoordinateInput(self)
    local value = self:getText()
    if type(value) ~= "string" then return end
    local cleanValue = value:gsub("[^%d%-]", "")
    local isNegative = (string.sub(cleanValue, 1, 1) == "-")
    cleanValue = cleanValue:gsub("-","")
    cleanValue = string.sub(cleanValue, 1, 5)
    if isNegative then
        cleanValue = "-" .. cleanValue
    end
    if value ~= cleanValue then
        self:setText(cleanValue)
    end
end

local function createMainUI(ctx, main, shared)
    local state, basalt = ctx.state, ctx.basalt

    local labelCurrentAltitude = main:addLabel():setPosition(2, 2):setText("Current altitude : --")
    local labelAimedAltitude = main:addLabel():setPosition(2, 3):setText("Aimed altitude : " .. state.aimedHeight)

    main:addLabel():setPosition(2, 4):setText("New altitude :")
    local inputAltitude = main:addInput():setPosition(17, 4):setSize(7, 1)
    inputAltitude:onChange(cleanAltitudeInput)
    inputAltitude:onEnter(function()
        local newAltitude = tonumber(inputAltitude:getText())
        if newAltitude then
            state.aimedHeight = math.min(5000, newAltitude)
            inputAltitude:setText("")
        end
    end)

    local btnToggleAC = main:addButton():setPosition(2, 6):setSize(22, 1):setText("Altitude Control: OFF")

    btnToggleAC:onClick(function()
        state.heightControlEnabled = not state.heightControlEnabled
    end)

    main:addLabel():setPosition(2,8):setText("Dest X:")
    local inputDestX = main:addInput():setPosition(10, 8):setSize(8,1)
    main:addLabel():setPosition(2,9):setText("Dest Z:")
    local inputDestZ = main:addInput():setPosition(10, 9):setSize(8,1)
    main:addLabel():setPosition(2,10):setText("Dest Y:")
    local inputDestY = main:addInput():setPosition(10, 10):setSize(8,1)

    local function setDestination()
        local x = tonumber(inputDestX:getText())
        local z = tonumber(inputDestZ:getText())
        local y = tonumber(inputDestY:getText())

        if x and z then
            state:setDestination(nil, x, z, y)
            inputDestX:setText("")
            inputDestZ:setText("")
            inputDestY:setText("")
        end
    end

    for _, input in ipairs({ inputDestX, inputDestZ, inputDestY }) do
        input:onChange(cleanCoordinateInput)
        input:onEnter(setDestination)
    end

    local btnToggleAP = main:addButton():setPosition(2, 12):setSize(16, 1):setText("Autopilot: OFF"):setBackground(colors.red)
    btnToggleAP:onClick(function()
        state:toggleAutopilot()
    end)

    local labelDist = main:addLabel():setPosition(2, 14):setText("Dist: --")
    local labelYaw = main:addLabel():setPosition(2, 15):setText("Yaw/Aim: --/--")
    local labelStatus = main:addLabel():setPosition(2, 16):setText("NO TARGET"):setForeground(colors.gray)
    
    local listLabel = main:addLabel():setPosition(27, 2):setText("Destinations")
    local listDestinations = main:addList():setPosition(27, 3):setSize(22, 12):setBackground(colors.gray)

    function shared.fillSavedDest()
        listDestinations:clear()
        for _, dest in ipairs(ctx.savedDestinations) do
            listDestinations:addItem(dest.name)
        end
    end
    shared.fillSavedDest()

    listDestinations:onChange(function(self, event, item)
        if not (item and item.text) or item.text == "Loading..." then return end
        if state.isTrackerUI then
            state:trackPlayer(item.text)
        else
            for _, dest in ipairs(ctx.savedDestinations) do
                if dest.name == item.text then
                    state:setDestination(dest.name, dest.x, dest.z, dest.y)
                    break
                end
            end
        end
    end)

    local btnToggleTrackMode = main:addButton():setPosition(27, 16):setSize(22,1):setText("TrackPlayerMode"):setBackground(colors.cyan)
    btnToggleTrackMode:onClick(function()
        state.isTrackerUI = not state.isTrackerUI
        if state.isTrackerUI then
            btnToggleTrackMode:setText("Saved destinations"):setBackground(colors.orange)
            listLabel:setText("Live Players")
            listDestinations:clear()
            listDestinations:addItem("Loading...")
            state.playersUpdates =  true
        else
            btnToggleTrackMode:setText("TrackPlayerMode"):setBackground(colors.cyan)
            listLabel:setText("Destinations")
            state.trackerEnabled = false
            state.trackedPlayerName = nil
            shared.fillSavedDest()
        end

    end)


    basalt.schedule(function()
        while true do
            labelCurrentAltitude:setText("Current altitude : " .. math.floor(state.currentHeight))
            labelAimedAltitude:setText(("Aimed altitude : %.1f"):format(state.aimedHeight))
            labelDist:setText("Dist: " .. math.floor(state.destinationDistance) .. "m")
            labelYaw:setText(string.format("Yaw/Aim: %1.f / %1.f", state.yaw, state.aimedAngle))

            if state.hasSetDestination then
                labelStatus:setText(string.format("Target: %d, %d", state.destination_x, state.destination_z)):setForeground(colors.lightBlue)
            end
            
            if state.autopilotEnabled then
                btnToggleAP:setText("Autopilot: ON"):setBackground(colors.green)
            else
                btnToggleAP:setText("Autopilot: OFF"):setBackground(colors.red)
            end

            if state.heightControlEnabled then
                btnToggleAC:setText("Altitude Control: ON"):setBackground(colors.green)
            else
                btnToggleAC:setText("Altitude Control: OFF"):setBackground(colors.red)
            end

            if state.isTrackerUI and state.playersUpdates then
                state.playersUpdates = false

                listDestinations:clear()
                for _,p in ipairs(ctx.players) do
                    listDestinations:addItem(p.name)
                end
                if state.trackedPlayerName then listDestinations:selectItem(state.trackedPlayerName, false) end
            end

            sleep(0.1)
        end
    end)
end

local function createDestManagerUI(ctx, main, shared)
    local state = ctx.state
    local saved = ctx.savedDestinations

    local w, h = main:getSize()
    local leftW = math.floor(w / 2)
    local rightW = w - leftW
    local inputW = leftW - 2
    local halfW = math.floor(inputW / 2)
    local col2 = 2 + halfW + 1
    local col2W = inputW - halfW - 1

    local btnOpen = main:addButton():setPosition(2, 18):setSize(22, 1)
        :setText("Manage destinations"):setBackground(colors.blue)

    local view = main:addFrame():setPosition(1, 1):setSize(w, h)
        :setBackground(colors.black):setVisible(false):toFront()

    local leftPanel = view:addFrame():setPosition(1, 1):setSize(leftW, h):setBackground(colors.gray)
    local rightPanel = view:addFrame():setPosition(leftW + 1, 1):setSize(rightW, h):setBackground(colors.black)

    local list = rightPanel:addList():setPosition(1, 1):setSize(rightW, h):setScrollbar("auto")

    leftPanel:addLabel():setText("Name:"):setPosition(2, 2)
    local inName = leftPanel:addInput():setPosition(2, 3):setSize(inputW, 1)

    leftPanel:addLabel():setText("X:"):setPosition(2, 5)
    local inX = leftPanel:addInput():setPosition(2, 6):setSize(halfW, 1)
        :setMaxLength(5):setPattern("^[-%d]?%d*$")

    leftPanel:addLabel():setText("Z:"):setPosition(col2, 5)
    local inZ = leftPanel:addInput():setPosition(col2, 6):setSize(col2W, 1)
        :setMaxLength(5):setPattern("^[-%d]?%d*$")

    leftPanel:addLabel():setText("Y (optional):"):setPosition(2, 8)
    local inY = leftPanel:addInput():setPosition(2, 9):setSize(inputW, 1)
        :setMaxLength(4):setPattern("^[-%d]?%d*$")

    local btnAdd = leftPanel:addButton():setText("Add"):setPosition(2, 11):setSize(halfW, 1)
        :setBackground(colors.blue):setForeground(colors.white)
    local btnEdit = leftPanel:addButton():setText("Edit"):setPosition(col2, 11):setSize(col2W, 1)
    local btnDel = leftPanel:addButton():setText("Del"):setPosition(2, 12):setSize(inputW, 1)
        :setBackground(colors.red):setForeground(colors.white)
    local btnUp = leftPanel:addButton():setText("/\\ Up"):setPosition(2, 13):setSize(halfW, 1)
    local btnDown = leftPanel:addButton():setText("\\/ Down"):setPosition(col2, 13):setSize(col2W, 1)
    local btnPos = leftPanel:addButton():setText("Current pos"):setPosition(2, 15):setSize(inputW, 1)
        :setBackground(colors.cyan):setForeground(colors.black)

    local status = leftPanel:addLabel():setText(""):setPosition(2, h - 3):setSize(inputW, 1)
    local btnBack = leftPanel:addButton():setText("Back"):setPosition(2, h - 1):setSize(inputW, 1)
        :setBackground(colors.orange)

    local selectedIndex = nil

    local function setStatus(text, color)
        status:setText(text):setForeground(color or colors.white)
    end

    local function clearInputs()
        inName:setText(""); inX:setText(""); inZ:setText(""); inY:setText("")
    end

    local function refresh()
        list:clear()
        for i, d in ipairs(saved) do
            list:addItem({text = d.name, value = i})
        end
        if selectedIndex and saved[selectedIndex] then
            list:selectItem(selectedIndex)
        end
        if not state.isTrackerUI then shared.fillSavedDest() end
    end

    local function persist()
        ctx.destinations.save(saved)
        refresh()
    end

    local function readEntry()
        local name = inName:getText()
        local x, z, y = tonumber(inX:getText()), tonumber(inZ:getText()), tonumber(inY:getText())
        if name == "" or not x or not z then
            setStatus("Name, X and Z required", colors.red)
            return nil
        end
        return {name = name, x = x, z = z, y = y}
    end

    local function nameTaken(name, ignoreIndex)
        for i, d in ipairs(saved) do
            if d.name == name and i ~= ignoreIndex then return true end
        end
        return false
    end

    list:onSelect(function(self, index, item)
        selectedIndex = index
        local dest = saved[index]
        if dest then
            inName:setText(dest.name)
            inX:setText(tostring(dest.x))
            inZ:setText(tostring(dest.z))
            inY:setText(dest.y and tostring(dest.y) or "")
        end
    end)

    btnAdd:onClick(function()
        local entry = readEntry()
        if not entry then return end
        if nameTaken(entry.name) then
            setStatus("Name already Used", colors.red)
            return
        end
        table.insert(saved, entry)
        selectedIndex = #saved
        persist()
        setStatus("Added", colors.lime)
    end)

    btnEdit:onClick(function()
        if not (selectedIndex and saved[selectedIndex]) then
            setStatus("No selection", colors.red)
            return
        end
        local entry = readEntry()
        if not entry then return end
        if nameTaken(entry.name, selectedIndex) then
            setStatus("Name already Used", colors.red)
            return
        end
        saved[selectedIndex] = entry
        persist()
        setStatus("Updated", colors.lime)
    end)

    btnDel:onClick(function()
        if not (selectedIndex and saved[selectedIndex]) then
            setStatus("No selection", colors.red)
            return
        end
        table.remove(saved, selectedIndex)
        selectedIndex = nil
        clearInputs()
        persist()
        setStatus("Deleted", colors.orange)
    end)

    btnUp:onClick(function()
        if selectedIndex and selectedIndex > 1 then
            saved[selectedIndex], saved[selectedIndex - 1] =
                saved[selectedIndex - 1], saved[selectedIndex]
            selectedIndex = selectedIndex - 1
            persist()
        end
    end)

    btnDown:onClick(function()
        if selectedIndex and selectedIndex < #saved then
            saved[selectedIndex], saved[selectedIndex + 1] =
                saved[selectedIndex + 1], saved[selectedIndex]
            selectedIndex = selectedIndex + 1
            persist()
        end
    end)

    btnPos:onClick(function()
        inX:setText(tostring(math.floor(state.x)))
        inZ:setText(tostring(math.floor(state.z)))
        inY:setText(tostring(math.floor(state.currentHeight)))
    end)

    btnBack:onClick(function() view:setVisible(false) end)

    btnOpen:onClick(function()
        selectedIndex = nil
        clearInputs()
        setStatus("")
        refresh()
        view:setVisible(true):toFront()
    end)
end

function UI.create(ctx)
    local main = ctx.basalt.getMainFrame()
    local shared = {}
    createMainUI(ctx, main, shared)
    createDestManagerUI(ctx, main, shared)
end

return UI