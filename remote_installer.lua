-- remote_installer.lua
-- Installs and updates the flyer remote for pocket computer from GitHub.
--
-- Fresh install (stable): wget run https://raw.githubusercontent.com/Gelodix/flyer/main/remote_installer.lua
-- Fresh install (beta):   wget run https://raw.githubusercontent.com/Gelodix/flyer/beta/remote_installer.lua beta
-- Reinstall / switch:     remote_installer [main|beta]
--
-- Also loaded as a module by the remote's startup.lua.
-- This file must stay self-contained: it runs before anything else is installed.


local args = { ... }

local REMOTE_INSTALLER = {}

local REPO_URL = "https://raw.githubusercontent.com/Gelodix/flyer/"
local BRANCH_FILE = ".remote_branch"
local VERSION_FILE = ".remote_version"

local function readFile(path)
    if not fs.exists(path) then return nil end
    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()
    return content
end

local function writeFile(path, content)
    local dir = fs.getDir(path)
    if dir ~= "" then fs.makeDir(dir) end
    local file = fs.open(path, "w")
    file.write(content)
    file.close()
end

local function download(url)
    if not http then return nil, "HTTP API disabled" end
    local separator = url:find("?", 1, true) and "&" or "?"
    local res, err = http.get(url .. separator .. "t=" .. os.epoch("utc"), { ["Cache-Control"] = "no-cache" })
    if not res then return nil, tostring(err) end
    local body = res.readAll()
    res.close()
    return body
end

local function fetchManifest(baseUrl)
    local source, err = download(baseUrl .. "manifest.lua")
    if not source then return nil, "manifest.lua: " .. err end
    local chunk, syntaxErr = load(source, "=manifest.lua", "t", {})
    if not chunk then return nil, syntaxErr end
    local ok, manifest = pcall(chunk)
    if not ok or type(manifest) ~= "table" or type(manifest.remote) ~= "table"
        or not manifest.remote.version or type(manifest.remote.files) ~= "table" then
        return nil, "manifest.lua is invalid"
    end
    return manifest.remote
end

function REMOTE_INSTALLER.branch()
    return readFile(BRANCH_FILE) or "main"
end

function REMOTE_INSTALLER.version()
    return readFile(VERSION_FILE)
end

function REMOTE_INSTALLER.update(force)
    local branch = REMOTE_INSTALLER.branch()
    local baseUrl = REPO_URL .. branch .. "/"

    local remote, err = fetchManifest(baseUrl)
    if not remote then return false, err end
    if not force and REMOTE_INSTALLER.version() == remote.version then
        return false, "Up to date (" .. remote.version .. ")"
    end

    local bodies = {}

    for source, target in pairs(remote.files) do
        local body, downloadErr = download(baseUrl .. source)
        if not body then return false, source .. ": " .. downloadErr end
        local ok, syntaxErr = load(body, "=" .. source)
        if not ok then return false, syntaxErr end
        bodies[target] = body
    end

    for target, body in pairs(bodies) do
        writeFile(target, body)
    end
    writeFile(VERSION_FILE, remote.version)
    return true, remote.version .. (branch ~= "main" and " (" .. branch .. ")" or "")
end

if args[1] ~= "remote_installer" then
    if args[1] == "main" or args[1] == "beta" then
        writeFile(BRANCH_FILE, args[1])
    end

    print("Installing remote (" .. REMOTE_INSTALLER.branch() .. ")...")

    local ok, info = REMOTE_INSTALLER.update(true)
    if ok then
        print("Remote version " .. info)
        print("Reboot to start it.")
    else
        printError("Installation failed: " .. info)
    end
end

return REMOTE_INSTALLER