if not fs.exists("basalt.lua") then
    shell.run("wget", "run", "https://basalt.madefor.cc/2.5/install.lua", "minified")
end

local basalt = require("basalt")
local ships = require("remote_files.ships")
local client = require("remote_files.client")

local opened, openError = client.open()
if not opened then
    printError(openError)
    return
end

local STATUS_REFRESH = 5
local MIN_PASSWORD_LENGTH = 12

local main = basalt.getMainFrame()
local w, h = main:getSize()

local savedShips = ships.load()
local current = nil
local status = nil
local busy = false

local screens = {}
local shown = nil

local function newScreen(name)
    screens[name] = main:addFrame():setPosition(1, 1):setSize(w, h)
        :setBackground(colors.black):setVisible(false)
    return screens[name]
end

local function show(name)
    for screenName, frame in pairs(screens) do
        frame:setVisible(screenName == name)
    end
    shown = name
end

local function messageLine(frame)
    local label = frame:addLabel():setPosition(2, h):setText("")
    return function(text, color)
        label:setText(text or ""):setForeground(color or colors.white)
    end
end

local refreshControl, refreshDestinations

local function send(command, value, setMessage, quiet)
    if busy or not current then return end
    busy = true

    if not quiet then setMessage("Sending ...", colors.yellow) end

    basalt.schedule(function()
        local reply, err = client.request(current, command, value)
        busy = false
        if not reply then
            setMessage(err, colors.red)
            return
        end

        if type(reply.status) == "table" then status = reply.status end
        if not reply.ok then
            setMessage("Refused: " .. tostring(reply.message), colors.red)
        elseif not quiet then
            setMessage("OK", colors.lime)
        end
        refreshControl()
        refreshDestinations()
    end)
end

local listScreen = newScreen("list")
local listMessage = messageLine(listScreen)
listScreen:addLabel():setPosition(2, 1):setText("Flyer remote"):setForeground(colors.yellow)

local shipList = listScreen:addList():setPosition(2, 3):setSize(w - 2, h - 7):setBackground(colors.gray)
local selectedShip = nil

local function fillShips()
    shipList:clear()
    for i, ship in ipairs(savedShips) do
        shipList:addItem({text = ("%s #%d"):format(ship.name, ship.id), value = i})
    end
    selectedShip = nil
end

shipList:onSelect(function (self, index)
    selectedShip = index
end)

local openEditor, openControl

local buttonW = math.floor((w - 5) / 4)
local function listButton(i, text, color)
    return listScreen:addButton():setPosition(2 + (i - 1) * (buttonW + 1), h - 3):setSize(buttonW, 1)
        :setText(text):setBackground(color)
end

listButton(1, "Open", colors.green):onClick(function()
    if not savedShips[selectedShip] then return listMessage("Select a ship", colors.red) end
    openControl(savedShips[selectedShip])
end)

listButton(2, "Add", colors.blue):onClick(function()
    openEditor(nil)
end)

listButton(3, "Edit", colors.lightGray):onClick(function()
    if not savedShips[selectedShip] then return listMessage("Select a ship", colors.red) end
    openEditor(selectedShip)
end)

listButton(4, "Del", colors.red):onClick(function()
    if not savedShips[selectedShip] then return listMessage("Select a ship", colors.red) end
    table.remove(savedShips, selectedShip)
    ships.save(savedShips)
    fillShips()
    listMessage("Deleted", colors.orange)
end)

local editScreen = newScreen("edit")
local editMessage = messageLine(editScreen)
local editTitle = editScreen:addLabel():setPosition(2, 1):setForeground(colors.yellow)

editScreen:addLabel():setPosition(2, 3):setText("Name:")
local inName = editScreen:addInput():setPosition(2, 4):setSize(w - 2, 1)
editScreen:addLabel():setPosition(2, 6):setText("Computer ID:")
local inId = editScreen:addInput():setPosition(2, 7):setSize(8, 1)
editScreen:addLabel():setPosition(2, 9):setText("Password:")
local inPassword = editScreen:addInput():setPosition(2, 10):setSize(w - 2, 1):setReplaceChar("*")

local editingIndex = nil

function openEditor(index)
    editingIndex = index
    local ship = index and savedShips[index] or {}
    editTitle:setText(index and "Edit ship" or "New ship")
    inName:setText(ship.name or "")
    inId:setText(ship.id and tostring(ship.id) or "")
    inPassword:setText(ship.password or "")
    editMessage("")
    show("edit")
end

local halfW  =math.floor((w - 3)/2)

editScreen:addButton():setPosition(2, 12):setSize(halfW, 1):setText("Save"):setBackground(colors.green)
    :onClick(function ()
        local name, id, password = inName:getText(), tonumber(inId:getText()), inPassword:getText()
        if name == "" or not id then return editMessage("Name and ID required", colors.red) end
        if #password < MIN_PASSWORD_LENGTH then
            return editMessage(("Password: %d chars min"):format(MIN_PASSWORD_LENGTH), colors.red)
        end
        local ship = {name = name, id = id, password = password}
        if editingIndex then
            savedShips[editingIndex] = ship
        else
            table.insert(savedShips, ship)
        end
        ships.save(savedShips)
        fillShips()
        show("list")
    end)
editScreen:addButton():setPosition(3 + halfW, 12):setSize(halfW, 1):setText("Cancel"):setBackground(colors.gray)
    :onClick(function ()
        show("list")
    end)

local controlScreen = newScreen("control")
local controlMessage = messageLine(controlScreen)
local controlTitle = controlScreen:addLabel():setPosition(2, 1):setForeground(colors.yellow)

local labelHeight = controlScreen:addLabel():setPosition(2, 2):setText("Y --")
local labelSpeed = controlScreen:addLabel():setPosition(2, 3):setText("Speed --")

local btnAltitude = controlScreen:addButton():setPosition(2, 5):setSize(w - 2, 1):setText("Altitude: --")
controlScreen:addLabel():setPosition(2, 6):setText("Set Y:")
local inAimed = controlScreen:addInput():setPosition(16, 6):setSize(8,1)

local btnAutopilot = controlScreen:addButton():setPosition(2, 8):setSize(w - 2, 1):setText("Autopilot: --")
local labelTravel = controlScreen:addLabel():setPosition(2, 9):setText("Travel Y:")
local inTravel = controlScreen:addInput():setPosition(16, 9):setSize(8, 1)

local labelDest = controlScreen:addLabel():setPosition(2, 11):setText("Dest: --")
local labelDist = controlScreen:addLabel():setPosition(2, 12):setText("")

btnAltitude:onClick(function()
    if not status then return controlMessage("No status yet", colors.red) end
    send("setHeightControl", not status.heightControlEnabled, controlMessage)
end)

btnAutopilot:onClick(function()
    if not status then return controlMessage("No status yet", colors.red) end
    send("setAutopilot", not status.autopilotEnabled, controlMessage)
end)

local function numberCommand(input, command)
    input:onEnter(function()
        local value = tonumber(input:getText())
        if not value then return controlMessage("Number expected", colors.red) end
        input:setText("")
        send(command, value, controlMessage)
    end)
end

numberCommand(inAimed, "setAimedHeight")
numberCommand(inTravel, "setTravelHeight")

controlScreen:addButton():setPosition(2, 14):setSize(w - 2, 1):setText("Destinations"):setBackground(colors.blue)
    :onClick(function()
        show("destinations")
        send("status", nil, controlMessage, true)
    end)
controlScreen:addButton():setPosition(2, 16):setSize(halfW, 1):setText("Refresh"):setBackground(colors.cyan)
    :onClick(function() send("status", nil, controlMessage) end)
controlScreen:addButton():setPosition(3 + halfW, 16):setSize(halfW, 1):setText("Back"):setBackground(colors.orange)
    :onClick(function()
        current, status = nil, nil
        show("list")
    end)

function refreshControl()
    if not status then return end
    labelHeight:setText(("Y %d > %.1f"):format(math.floor(status.currentHeight), status.aimedHeight))
    labelSpeed:setText(("Speed %d m/s"):format(math.floor(status.speed)))
    labelTravel:setText(("Travel %d"):format(math.floor(status.travelHeight)))

    btnAltitude:setText("Altitude: " .. (status.heightControlEnabled and "ON" or "OFF"))
        :setBackground(status.heightControlEnabled and colors.green or colors.red)
    btnAutopilot:setText("Autopilot: " .. (status.autopilotEnabled and "ON" or "OFF"))
        :setBackground(status.autopilotEnabled and colors.green or colors.red)

    local dest = status.destination
    if dest then
        labelDest:setText("Dest: " .. (dest.name or ("%d, %d"):format(math.floor(dest.x), math.floor(dest.z))))
        labelDist:setText(("Dist: %dm"):format(math.floor(dest.distance)))
    else
        labelDest:setText("Dest: none")
        labelDist:setText("")
    end
end

function openControl(ship)
    current, status = ship, nil
    controlTitle:setText(("%s #%d"):format(ship.name, ship.id))
    labelHeight:setText("Y --")
    controlMessage("")
    show("control")
    send("status", nil, controlMessage)
end

local destScreen = newScreen("destinations")
local destMessage = messageLine(destScreen)
destScreen:addLabel():setPosition(2, 1):setText("Destinations"):setForeground(colors.yellow)

local destList = destScreen:addList():setPosition(2, 3):setSize(w - 2, 10):setBackground(colors.gray)
local shownDestinations = {}

function refreshDestinations()
    if not (status and status.savedDestinations) then return end
    shownDestinations = status.savedDestinations
    destList:clear()
    for i, dest in ipairs(shownDestinations) do
        destList:addItem({ text = dest.name, value = i})
    end
end

destList:onSelect(function(self, index)
    local dest = shownDestinations[index]
    if dest then send("setDestination", dest.name, destMessage) end
end)

destScreen:addLabel():setPosition(2, 13):setText("X:")
local inX = destScreen:addInput():setPosition(4, 13):setSize(6, 1)
destScreen:addLabel():setPosition(11, 13):setText("Z:")
local inZ = destScreen:addInput():setPosition(13, 13):setSize(6, 1)
destScreen:addLabel():setPosition(20, 13):setText("Y:")
local inY = destScreen:addInput():setPosition(22, 13):setSize(w - 22, 1)

destScreen:addButton():setPosition(2, 15):setSize(w -2, 1):setText("Go to coordinates"):setBackground(colors.blue)
    :onClick(function()
        local x, z, y = tonumber(inX:getText()), tonumber(inZ:getText()), tonumber(inY:getText())
        if not (x and z) then return destMessage("X and Z required", colors.red) end
        send("setDestination", {x = x, z = z, y = y}, destMessage)
    end)
destScreen:addButton():setPosition(2, 17):setSize(w - 2, 1):setText("Back"):setBackground(colors.orange)
    :onClick(function()
        show("control")
        refreshControl()
    end)

basalt.schedule(function()
    while true do
        sleep(STATUS_REFRESH)
        if shown == "control" then send("status", nil, controlMessage, true) end
    end
end)

fillShips()
show("list")
basalt.run()