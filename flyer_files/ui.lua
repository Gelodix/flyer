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

local function place(element, pos)
    element:setPosition(pos[1], pos[2])
    if pos[3] then element:setSize(pos[3], pos[4] or 1) end
    return element
end

local LAYOUTS = {}

LAYOUTS.base = {
    flight = {
        current = {2, 2},
        currentText = "Current altitude : %d",

        aimed = {2, 3},
        aimedText = "Aimed altitude : %.1f",

        newLabel = {2, 4},
        newText = "New altitude :",
        newInput = {17, 4, 7},

        heightControl = {2, 6, 22},
        heightControlText = "Altitude control: ",

        autopilot = {2, 12, 16},
        autopilotText = "Autopilot: ",

        distance = {2, 14},
        distanceText = "Dist: %dm",

        yaw = {2, 15},
        yawText = "Yaw/Aim: %1.f / %1.f",

        status = {2, 16},
        statusText = "Target: %d, %d",
        noTargetText = "NO TARGET",
    },

    manual = { x = {2, 8}, z = {2, 9}, y = {2, 10}, inputX = 10, inputWidth = 8},

    list = {
        label = {27, 2}, list = {27, 3, 22, 12}, mode = {27, 16, 22},
        playersText = "TrackPlayerMode", savedText = " Saved destinations",
    },

    manager = {
        rows = {name = 2, xz = 5, y = 8, addEdit = 11, del = 12, upDown = 13, pos = 15},
        yLabel = "Y (optional):", yInline = false,
        open = {2, 18, 22}
    },
}

LAYOUTS.compact = {
    tabs = {"Fly", "Coords", "Manage"},
    flight = {
        current = {2, 1},
        currentText = "Y now: %d",

        aimed = {2, 2},
        aimedText = "Y aim: %.1f",

        newLabel = {2, 3},
        newText = "Set y:",
        newInput = {9, 3, 7},

        heightControl = {2, 5, 17},
        heightControlText = "Altitude: ",

        autopilot = {2, 6, 17},
        autopilotText = "Autopilot: ",

        distance = {2, 8},
        distanceText = "Dist: %dm",

        yaw = {2, 9},
        yawText = "Yaw %1.f / %1.f",

        status = {2, 10},
        statusText = "Tgt: %d, %d",
        noTargetText = "NO TARGET",
    },

    manual = { 
        x = {2, 2}, z = {2, 3}, y = {2, 4}, inputX = 10, inputWidth = 8,
        button = {2, 6, 16}, hint = {2, 8},
    },

    list = {
        label = {21, 1}, list = {21, 2, 18, 9}, mode = {21, 11, 18},
        playersText = "Players", savedText = " Saved",
    },

    manager = {
        rows = {name = 1, xz = 3, y = 5, addEdit = 6, del = 7, upDown = 8, pos = 9, status = 11,},
        yLabel = "Y:", yInline = true,
    },
}

local function isCompact()
    local w, h = term.getSize()
    return w < 51 or h < 19
end


local function createFlightUI(ctx, frame, L)
    local state = ctx.state

    local labelCurrentAltitude = place(frame:addLabel(), L.current)
    local labelAimedAltitude = place(frame:addLabel(), L.aimed)

    place(frame:addLabel(), L.newLabel):setText(L.newText)
    local inputAltitude = place(frame:addInput(), L.newInput)
    inputAltitude:onChange(cleanAltitudeInput)
    inputAltitude:onEnter(function()
        local newAltitude = tonumber(inputAltitude:getText())
        if newAltitude then
            state.aimedHeight = math.min(5000, newAltitude)
            inputAltitude:setText("")
        end
    end)

    local btnToggleAC = place(frame:addButton(), L.heightControl)
    btnToggleAC:onClick(function()
        state.heightControlEnabled = not state.heightControlEnabled
    end)

    local btnToggleAP = place(frame:addButton(), L.autopilot)
    btnToggleAP:onClick(function()
        state:toggleAutopilot()
    end)

    local labelDist = place(frame:addLabel(), L.distance)
    local labelYaw = place(frame:addLabel(), L.yaw)
    local labelStatus = place(frame:addLabel(), L.status):setText(L.noTargetText):setForeground(colors.gray)

    return function()
        labelCurrentAltitude:setText(L.currentText:format(math.floor(state.currentHeight)))
        labelAimedAltitude:setText(L.aimedText:format(state.aimedHeight))
        labelDist:setText(L.distanceText:format(math.floor(state.destinationDistance)))
        labelYaw:setText(L.yawText:format(state.yaw, state.aimedAngle))

        if state.hasSetDestination then
            labelStatus:setText(L.statusText:format(math.floor(state.destination_x), math.floor(state.destination_z)))
                :setForeground(colors.lightBlue)
        end

        btnToggleAC:setText(L.heightControlText .. (state.heightControlEnabled and "ON" or "OFF"))
            :setBackground(state.heightControlEnabled and colors.green or colors.red)

        btnToggleAP:setText(L.autopilotText .. (state.autopilotEnabled and "ON" or "OFF"))
            :setBackground(state.autopilotEnabled and colors.green or colors.red)
    end
end

local function createManualTargetUI(ctx, frame, L)
    local state = ctx.state
    local inputs = {}

    for _, axis in ipairs({"x", "z", "y"}) do
        local pos = L[axis]
        frame:addLabel():setPosition(pos[1], pos[2]): setText("Dest " .. axis:upper() .. ":")
        inputs[axis] = frame:addInput():setPosition(L.inputX, pos[2]):setSize(L.inputWidth, 1)
    end

    local function setDestination()
        local x = tonumber(inputs.x:getText())
        local z = tonumber(inputs.z:getText())
        local y = tonumber(inputs.y:getText())

        if x and z then
            state:setDestination(nil, x, z, y)
            for _, input in pairs(inputs) do input:setText("") end
        end
    end

    for _, input in pairs(inputs) do
        input:onChange(cleanCoordinateInput)
        input:onEnter(setDestination)
    end

    if L.button then
        place(frame:addButton(), L.button):setText("Set target"):setBackground(colors.blue)
            :onClick(setDestination)
    end

    if L.hint then
        place(frame:addLabel(), L.hint):setText("Y is optional"):setForeground(colors.gray)
    end
end

local function createTargetList(ctx, frame, L, shared)
    local state = ctx.state

    local listLabel = place(frame:addLabel(), L.label):setText("Destinations")
    local listDestinations = place(frame:addList(), L.list):setBackground(colors.gray)
    
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

    local btnToggleTrackMode = place(frame:addButton(), L.mode):setText(L.playersText):setBackground(colors.cyan)
    btnToggleTrackMode:onClick(function()
        state.isTrackerUI = not state.isTrackerUI
        if state.isTrackerUI then
            btnToggleTrackMode:setText(L.savedText):setBackground(colors.orange)
            listLabel:setText("Live Players")
            listDestinations:clear()
            listDestinations:addItem("Loading...")
            state.playersUpdates =  true
        else
            btnToggleTrackMode:setText(L.playersText):setBackground(colors.cyan)
            listLabel:setText("Destinations")
            state.trackerEnabled = false
            state.trackedPlayerName = nil
            shared.fillSavedDest()
        end

    end)

    return function()
        if state.isTrackerUI and state.playersUpdates then
            state.playersUpdates = false

            listDestinations:clear()
            for _,p in ipairs(ctx.players) do
                listDestinations:addItem(p.name)
            end
            if state.trackedPlayerName then listDestinations:selectItem(state.trackedPlayerName, false) end
        end
    end
end

local function createDestManagerUI(ctx, frame, L, shared, onBack)
    local state = ctx.state
    local saved = ctx.savedDestinations
    local rows = L.rows

    local w, h = frame:getSize()
    local leftW = math.floor(w / 2)
    local rightW = w - leftW
    local inputW = leftW - 2
    local halfW = math.floor(inputW / 2)
    local col2 = 2 + halfW + 1
    local col2W = inputW - halfW - 1

    local leftPanel = frame:addFrame():setPosition(1, 1):setSize(leftW, h):setBackground(colors.gray)
    local rightPanel = frame:addFrame():setPosition(leftW + 1, 1):setSize(rightW, h):setBackground(colors.black)

    local list = rightPanel:addList():setPosition(1, 1):setSize(rightW, h):setScrollbar("auto")

    leftPanel:addLabel():setText("Name:"):setPosition(2, rows.name)
    local inName = leftPanel:addInput():setPosition(2, rows.name + 1):setSize(inputW, 1)

    leftPanel:addLabel():setText("X:"):setPosition(2, rows.xz)
    local inX = leftPanel:addInput():setPosition(2, rows.xz + 1):setSize(halfW, 1)
        :setMaxLength(5):setPattern("^[-%d]?%d*$")

    leftPanel:addLabel():setText("Z:"):setPosition(col2, rows.xz)
    local inZ = leftPanel:addInput():setPosition(col2, rows.xz + 1):setSize(col2W, 1)
        :setMaxLength(5):setPattern("^[-%d]?%d*$")

    leftPanel:addLabel():setText(L.yLabel):setPosition(2, rows.y)
    local inY = leftPanel:addInput():setMaxLength(4):setPattern("^[-%d]?%d*$")
    if L.yInline then
        local labelW = #L.yLabel + 1
        inY:setPosition(2 + labelW, rows.y):setSize(inputW - labelW, 1)
    else
        inY:setPosition(2, rows.y + 1):setSize(inputW, 1)
    end



    local btnAdd = leftPanel:addButton():setText("Add"):setPosition(2, rows.addEdit):setSize(halfW, 1)
        :setBackground(colors.blue):setForeground(colors.white)
    local btnEdit = leftPanel:addButton():setText("Edit"):setPosition(col2, rows.addEdit):setSize(col2W, 1)
    local btnDel = leftPanel:addButton():setText("Del"):setPosition(2, rows.del):setSize(inputW, 1)
        :setBackground(colors.red):setForeground(colors.white)
    local btnUp = leftPanel:addButton():setText("/\\ Up"):setPosition(2, rows.upDown):setSize(halfW, 1)
    local btnDown = leftPanel:addButton():setText("\\/ Down"):setPosition(col2, rows.upDown):setSize(col2W, 1)
    local btnPos = leftPanel:addButton():setText("Current pos"):setPosition(2, rows.pos):setSize(inputW, 1)
        :setBackground(colors.cyan):setForeground(colors.black)

    local status = leftPanel:addLabel():setText(""):setPosition(2, rows.status or h - 3):setSize(inputW, 1)

    if onBack then
        leftPanel:addButton():setText("Back"):setPosition(2, h - 1):setSize(inputW, 1)
            :setBackground(colors.orange):onClick(onBack)
    end

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

    return function()
        selectedIndex = nil
        clearInputs()
        setStatus("")
        refresh()
    end
end

local function createBaseUI(ctx, main, shared, updaters)
    local L = LAYOUTS.base
    table.insert(updaters, createFlightUI(ctx, main, L.flight))
    createManualTargetUI(ctx, main, L.manual)
    table.insert(updaters, createTargetList(ctx, main, L.list, shared))

    local btnOpen = place(main:addButton(), L.manager.open):setText("Manage destinations")
        :setBackground(colors.blue)
    
    local w, h = main:getSize()
    local view = main:addFrame():setPosition(1, 1):setSize(w, h)
        :setBackground(colors.black):setVisible(false)
    local openManager = createDestManagerUI(ctx, view, L.manager, shared, function()
        view:setVisible(false)
    end)

    btnOpen:onClick(function()
        openManager()
        view:setVisible(true):toFront()
    end)
end

local function createCompactUI(ctx, main, shared, updaters)
    local L = LAYOUTS.compact
    local w, h = main:getSize()

    local pages, tabButtons = {}, {}
    local x = 1
    for i, name in ipairs(L.tabs) do
        pages[i] = main:addFrame():setPosition(1, 2):setSize(w, h - 1):setBackground(colors.black)
        tabButtons[i] = main:addButton():setPosition(x, 1):setSize(#name + 2, 1):setText(name)
        x = x + #name + 3
    end

    table.insert(updaters, createFlightUI(ctx, pages[1], L.flight))
    table.insert(updaters, createTargetList(ctx, pages[1], L.list, shared))
    createManualTargetUI(ctx, pages[2], L.manual)
    local openManager = createDestManagerUI(ctx, pages[3], L.manager, shared)

    local function selectTab(index)
        for i, page in ipairs(pages) do
            page:setVisible(i == index)
            tabButtons[i]:setBackground(i == index and colors.blue or colors.gray)
        end
        if index == 3 then openManager() end
    end
    
    for i, button in ipairs(tabButtons) do
        button:onClick(function() selectTab(i) end)
    end
    selectTab(1)
end

function UI.create(ctx)
    local main = ctx.basalt.getMainFrame()
    local shared, updaters = {}, {}

    if isCompact() then
        createCompactUI(ctx, main, shared, updaters)
    else
        createBaseUI(ctx, main, shared, updaters)
    end
    ctx.basalt.schedule(function()
        while true do
            for _, update in ipairs(updaters) do update() end
            sleep(0.1)
        end
    end)
end

return UI