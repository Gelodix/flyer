local installer = require("installer")

local SPINNER = { "\\", "|", "/", "-"}

local function withSpinner(label, fn)
    local screens = { term.current() }
    local monitor = peripheral.find("monitor")
    if monitor then table.insert(screens, monitor) end

    for _, screen in ipairs(screens) do
        screen.clear()
        screen.setCursorPos(1, 1)
        screen.write(label)
    end

    local result
    parallel.waitForAny(
        function()
            result = table.pack(pcall(fn))
        end,
        function()
            local i = 1
            while true do
                for _, screen in ipairs(screens) do
                    screen.setCursorPos(#label + 1, 1)
                    screen.write(SPINNER[i])
                end
                i = i % #SPINNER + 1
                sleep(0.1)
            end
        end
    )

    if monitor then monitor.clear() end
    term.setCursorPos(1, 2)
    return table.unpack(result, 1, result.n)
end

local function report(what, ok, updated, message)
    if not ok then
        printError(what .. " update crashed: " .. tostring(updated))
    elseif updated then
        print(what .. " updated to " .. message)
        return true
    else
        printError(what .. " update failed: " .. message)
    end
    return false
end

local config = installer.loadUpdateConfig()

if config.autoUpdate then
    print("Checking for updates (" .. config.branch .. ")...")
    local fetched, manifest, err = pcall(installer.fetchManifest, config)

    if not fetched then
        printError("Update check crashed: " .. tostring(manifest))
    elseif not manifest then
        printError("Update check failed: " .. err)
    else
        if installer.checkForInstallerUpdate(manifest) then
            local updated = report("Installer", withSpinner("Update installer... ", function()
                return installer.updateInstaller(config, manifest)
            end))
            if updated then
                sleep(1)
                os.reboot()
            end
        end

        local hasUpdate, info = installer.checkForUpdate(config, manifest)
        if hasUpdate then
            report("Flyer", withSpinner("Update... ", function()
                return installer.update(config, manifest)
            end))
            sleep(1)
        else
            print(info)
        end
    end
end

installer.ensureBasalt()

local program = installer.programName()
if not fs.exists(program) then
    printError(program .. " not found, run 'installer' to reinstall.")
    return
end

shell.run(program)