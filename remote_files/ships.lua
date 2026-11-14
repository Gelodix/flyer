local SHIPS = {}

SHIPS.FILE = "remote_ships.cfg"

function SHIPS.load()
    if not fs.exists(SHIPS.FILE) then return {} end
    local file = fs.open(SHIPS.FILE, "r")
    local content = file.readAll()
    file.close()
    local list = textutils.unserialize(content)
    return type(list) == "table" and list or {}
end

function SHIPS.save(list)
    local file = fs.open(SHIPS.FILE, "w")
    file.write(textutils.serialize(list))
    file.close()
end

return SHIPS