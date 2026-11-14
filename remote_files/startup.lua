package.path = package.path .. ";/?.lua"

local installer = require("remote_installer")

if http then
    print("Checking for updates (" .. installer.branch() .. ")...")
    local ok, updated, info = pcall(installer.update, false)
    if not ok then
        printError("Update crashed: " .. tostring(updated))
    elseif updated then
        print("Remote updated to " .. info)
        sleep(1)
    else
        print(info)
    end
end

shell.run ("flyer_remote")