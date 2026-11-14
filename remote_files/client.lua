local auth = require("flyer_files.auth")

local CLIENT = {}

local DEFAULT_PROTOCOL = "flyer"
local TIMEOUT = 3

function CLIENT.open()
    local modem = peripheral.find("modem", function(_,m) return m.isWireless() end)
    if not modem then return false, "No wireless modem" end
    rednet.open(peripheral.getName(modem))
    return true
end

function CLIENT.request(ship, command, value)
    local protocol = ship.protocol or DEFAULT_PROTOCOL
    local request = auth.sign({target = ship.id, command = command, value = value}, ship.password)
    rednet.send(ship.id, request, protocol)

    local deadline = os.clock() + TIMEOUT
    while true do
        local remaining = deadline - os.clock()
        if remaining <= 0 then break end
        local sender, reply = rednet.receive(protocol, remaining)
        if not sender then break end
        if sender == ship.id and auth.verify(reply, ship.password) and type(reply.value) == "table" then
            return reply.value
        end
    end

    return nil, "No reply (id, password, range?)"
end

return CLIENT