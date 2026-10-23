-- installer.lua
-- Installs and updates the flyer from GitHub.
--
-- Fresh install (stable): wget run https://raw.githubusercontent.com/Gelodix/flyer/main/installer.lua
-- Fresh install (beta):   wget run https://raw.githubusercontent.com/Gelodix/flyer/beta/installer.lua beta
-- Reinstall / switch:     installer [main|beta]
--
-- Also loaded as a module by startup.lua.
-- This file must stay self-contained: it runs before anything else is installed.

local args = { ... }

local INSTALLER = {}

local SETTINGS_FILE = "flyer_settings.cfg"
local MAIN_FILE = "flyer.lua"
local FILES_DIR = "flyer_files"
local LOCAL_MANIFEST = fs.combine(FILES_DIR, ".manifest")
local INSTALLER_VERSION_FILE = ".installer_version"
local BACKUP_DIR = "backup/flyer"
local INSTALLER_BACKUP_DIR = "backup/installer"
local BASALT_URL = "https://basalt.madefor.cc/2.5/install.lua"

local DEFAULT = {
    autoUpdate = true,
    beta = false,
    gitUser = "Gelodix",
    repo = "flyer",
    mainBranch = "main",
    betaBranch = "beta",
}


local function readFile(path)
    if not fs.exists(path) then return nil end
    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()
    return content
end

local function writeFile(path, content)
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

local function backup(backupDir, paths)
    fs.delete(backupDir)
    fs.makeDir(backupDir)
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            fs.move(path, fs.combine(backupDir, path))
        end
    end
end

local function downloadAll(baseUrl, files)
    local bodies = {}
    for _, file in ipairs(files) do
        local body, err = download(baseUrl .. file)
        if not body then return nil, file .. ": " .. err end
        local ok, syntaxErr = load(body, "=" .. file)
        if not ok then return nil, syntaxErr end
        bodies[file] = body
    end
    return bodies
end

local function readSettings()
    local content = readFile(SETTINGS_FILE)
    if not content then return {} end
    local settings = textutils.unserialize(content)
    if type(settings) ~= "table" then
        return nil, SETTINGS_FILE .. " is invalid, using default update settings"
    end
    return settings
end

local function readLocalManifest()
    local content = readFile(LOCAL_MANIFEST)
    local manifest = content and textutils.unserialize(content)
    return type(manifest) == "table" and manifest or nil
end

function INSTALLER.loadUpdateConfig(overrides)
    local config = {}
    for k, v in pairs(DEFAULT) do config[k] = v end

    local settings, err = readSettings()
    if settings then
        local section = type(settings.update) == "table" and settings.update or {}
        local changed = settings.update ~= section
        for k, v in pairs(overrides or {}) do
            if section[k] ~= v then
                section[k] = v
                changed = true
            end
        end
        for k, v in pairs(DEFAULT) do
            if section[k] == nil then
                section[k] = v
                changed = true
            end
            config[k] = section[k]
        end
        if changed then
            settings.update = section
            writeFile(SETTINGS_FILE, textutils.serialize(settings))
        end
    else
        printError(err)
        for k, v in pairs(overrides or {}) do config[k] = v end
    end

    config.branch = config.beta and config.betaBranch or config.mainBranch
    config.baseUrl = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(config.gitUser, config.repo, config.branch)
    return config
end

function INSTALLER.programName()
    return MAIN_FILE
end

function INSTALLER.installedVersion()
    return readFile(INSTALLER_VERSION_FILE)
end

function INSTALLER.fetchManifest(config)
    local source, err = download(config.baseUrl .. "manifest.lua")
    if not source then return nil, "manifest.lua: " .. err end
    local chunk, syntaxErr = load(source, "=manifest.lua", "t", {})
    if not chunk then return nil, syntaxErr end
    local ok, manifest = pcall(chunk)
    if not ok or type(manifest) ~= "table" or not manifest.version or not manifest.files
        or type(manifest.installer) ~= "table" or not manifest.installer.version then
        return nil, "manifest.lua is invalid"
    end
    return manifest
end

function INSTALLER.checkForInstallerUpdate(manifest)
    return INSTALLER.installedVersion() ~= manifest.installer.version
end

function INSTALLER.updateInstaller(config, manifest)
    local files = manifest.installer.files
    local bodies, err = downloadAll(config.baseUrl, files)
    if not bodies then return false, err end

    backup(INSTALLER_BACKUP_DIR, files)
    for _, file in ipairs(files) do
        writeFile(file, bodies[file])
    end
    writeFile(INSTALLER_VERSION_FILE, manifest.installer.version)
    return true, manifest.installer.version
end

function INSTALLER.checkForUpdate(config, manifest)
    config = config or INSTALLER.loadUpdateConfig()
    if not manifest then
        local err
        manifest, err = INSTALLER.fetchManifest(config)
        if not manifest then return false, "Update check failed: " .. err end
    end

    local installed = readLocalManifest()
    if installed and installed.version == manifest.version and installed.beta == config.beta
        and fs.exists(MAIN_FILE) then
        return false, "Up to date (" .. manifest.version .. ")"
    end
    return true, manifest
end

function INSTALLER.update(config, manifest)
    config = config or INSTALLER.loadUpdateConfig()
    if not manifest then
        local err
        manifest, err = INSTALLER.fetchManifest(config)
        if not manifest then return false, err end
    end

    local remoteFiles = { MAIN_FILE }
    for _, file in ipairs(manifest.files) do
        table.insert(remoteFiles, FILES_DIR .. "/" .. file)
    end

    local bodies, err = downloadAll(config.baseUrl, remoteFiles)
    if not bodies then return false, err end


    fs.makeDir(FILES_DIR)
    for _, file in ipairs(remoteFiles) do
        writeFile(file, bodies[file])
    end

    local installed = readLocalManifest()
    if installed and installed.beta and not config.beta then
        fs.delete(MAIN_FILE)
        fs.delete(FILES_DIR)
    else
        backup(BACKUP_DIR, { MAIN_FILE, FILES_DIR })
    end

    for _, file in ipairs(remoteFiles) do
        writeFile(file, bodies[file])
    end
    manifest.beta = config.beta
    writeFile(LOCAL_MANIFEST, textutils.serialize(manifest))
    return true, manifest.version .. (config.beta and " (beta)" or "")
end

function INSTALLER.ensureBasalt()
    if not fs.exists("basalt.lua") then
        print("Installing Basalt...")
        shell.run("wget", "run", BASALT_URL, "minified")
    end
end

function INSTALLER.install(channel)
    local overrides
    if channel == "beta" then
        overrides = { beta = true }
    elseif channel == "main" then
        overrides = { beta = false }
    end
    local config = INSTALLER.loadUpdateConfig(overrides)

    print("Installing flyer (" .. config.branch .. ")...")
    local manifest, err = INSTALLER.fetchManifest(config)
    if not manifest then
        printError("Installation failed: " .. err)
        return false
    end

    local ok, info = INSTALLER.updateInstaller(config, manifest)
    if not ok then
        printError("Installer update failed: " .. info)
        return false
    end
    print("Installer version " .. info)

    ok, info = INSTALLER.update(config, manifest)
    if not ok then
        printError("Installation failed: " .. info)
        return false
    end
    print("Flyer version " .. info)

    INSTALLER.ensureBasalt()

    print("Check the wiring in " .. SETTINGS_FILE .. " (edit " .. SETTINGS_FILE .. "), then reboot.")
    return true
end

if args[1] ~= "installer" then
    INSTALLER.install(args[1])
end

return INSTALLER