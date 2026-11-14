return {
    installer = {
        version = "1.0.1",
        files = { "installer.lua", "startup.lua" },
    },

    version = "2.2.7",
    files = {
        "config.lua",
        "state.lua",
        "rsio.lua",
        "utils.lua",
        "destinations.lua",
        "telemetry.lua",
        "tracker.lua",
        "controls.lua",
        "altitude.lua",
        "autopilot.lua",
        "actuators.lua",
        "ui.lua",
        "monitor_ui.lua",
        "save_state.lua",
        "auth.lua",
        "remote.lua",
        "libraries/SHA256.lua",
    },
    remote = {
        version = "1.0.0",
        files = {
            ["remote_installer.lua"] = "remote_installer.lua",
            ["remote_files/startup.lua"] = "startup.lua",
            ["remote_files/flyer_remote.lua"] = "flyer_remote.lua",
            ["remote_files/client.lua"] = "remote_files/client.lua",
            ["remote_files/ships.lua"] = "remote_files/ships.lua",
            ["flyer_files/auth.lua"] = "flyer_files/auth.lua",
            ["flyer_files/libraries/SHA256.lua"] = "flyer_files/libraries/SHA256.lua",
        }
    }
}