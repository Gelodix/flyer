package.path = package.path .. ";/?.lua"
local function import(name)
    return require("flyer_files." .. name)
end

if not sublevel then
    print("CC: Sable isn't available, can't get current height")
    return
end

if not sublevel.isInPlotGrid() then
    print("Not on a assembled ship")
end

local basalt = require("basalt")
local config = import("config")
local stateLib = import("state")
local rsio = import("rsio")
local utils = import("utils")
local destinations = import("destinations")
local telemetry = import("telemetry")
local tracker = import("tracker")
local controls = import("controls")
local altitude = import("altitude")
local autopilot = import("autopilot")
local actuators = import("actuators")
local ui = import("ui")
local monitorUI = import("monitor_ui")
local saveState = import("save_state")
local remote = import("remote")


local cfg = config.load()
rsio.init(cfg)



local monitor = peripheral.find("monitor")
if not monitor then
    print("No monitor found, monitorUI disabled")
end

local ctx = {
    cfg = cfg,
    state = stateLib.new(cfg),
    rsio = rsio,
    utils = utils,
    destinations = destinations,
    savedDestinations = destinations.load(),
    players = {},
    basalt = basalt,
    monitor = monitor,
}

saveState.init(ctx)
remote.init(ctx.cfg)

ctx.persistedVariables = saveState.variablesFor(cfg.persistence)
saveState.load(ctx.persistedVariables)

local function taskUI()
    ui.create(ctx)
    if monitor then monitorUI.create(ctx) end
    basalt.run()
end

local ok, err = pcall(parallel.waitForAll,
    function() telemetry.run(ctx) end,
    function() tracker.run(ctx) end,
    function() controls.run(ctx) end,
    function() altitude.run(ctx) end,
    function() autopilot.run(ctx) end,
    function() actuators.run(ctx) end,
    function() saveState.run(ctx) end,
    function() remote.run(ctx) end,
    taskUI
)

rsio.reset()
if not ok then printError(err) end