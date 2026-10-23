local SAVE_STATE = {}

SAVE_STATE.initialized = false

SAVE_STATE.FILENAME = "flyer_state.dat"
SAVE_STATE.TEMP_FILENAME = SAVE_STATE.FILENAME .. ".tmp"

local GROUPS = {
    altitude = { "aimedHeight", "heightControlEnabled"},
    destination = { "hasSetDestination", "destination_x", "destination_y", "destination_z", "destName"},
    autopilot = { "autopilotEnabled"}
}   

function SAVE_STATE.init(ctx)
    if not SAVE_STATE.initialized then
        if ctx then
            SAVE_STATE.utils, SAVE_STATE.state = ctx.utils, ctx.state
            SAVE_STATE.initialized = true
        end
    end

    return SAVE_STATE.initialized
end

local saved = {}

local function readTable(path)
    local content = SAVE_STATE.utils.secureReadFile(path, false)
    local data = content and textutils.unserialize(content)
    return type(data) == "table" and data or nil
end

local function writeFile(data)
    SAVE_STATE.utils.secureWriteFile(SAVE_STATE.TEMP_FILENAME, false, textutils.serialize(data), true)
    if fs.exists(SAVE_STATE.FILENAME) then fs.delete(SAVE_STATE.FILENAME) end
    fs.move(SAVE_STATE.TEMP_FILENAME, SAVE_STATE.FILENAME)
end

function SAVE_STATE.variablesFor(settings)
    local names = {}
    if not settings.enabled then return names end
    for group, variables in pairs(GROUPS) do
        local wanted = settings[group] or (group == "destination" and settings.autopilot)
        if wanted then
            for _, name in ipairs(variables) do table.insert(names, name) end
        end
    end
    return names
end

function SAVE_STATE.load(variablesNames)
    if not SAVE_STATE.initialized then return end
    local data = readTable(SAVE_STATE.FILENAME) or readTable(SAVE_STATE.TEMP_FILENAME) or {}
    saved = {}
    for _, name in ipairs(variablesNames) do
        local value = data[name]
        if value ~= nil and (SAVE_STATE.state[name] == nil or type(value) == type(SAVE_STATE.state[name])) then
            SAVE_STATE.state[name] = value
            saved[name] = value
        end
    end
end

function SAVE_STATE.saveEntries(state, variablesNames)
    if not SAVE_STATE.initialized then return false end
    local snapshot, changed = {}, false
    for _, name in ipairs(variablesNames) do
        snapshot[name] = state[name]
        if saved[name] ~= state[name] then changed = true end
    end
    if not changed then return false end
    saved = snapshot
    writeFile(saved)
    return true
end

function SAVE_STATE.saveEntry(name, value)
    if not SAVE_STATE.initialized then return false end
    if saved[name] == value then return false end
    saved[name] = value
    writeFile(saved)
    return true
end

function SAVE_STATE.run(ctx)
    if not SAVE_STATE.initialized then return end
    local names = ctx.persistedVariables
    if #names == 0 then return end
    local interval = ctx.cfg.persistence.interval
    while true do
        sleep(interval)
        SAVE_STATE.saveEntries(ctx.state, names)
    end
end

return SAVE_STATE