local sha256 = require("flyer_files.libraries.SHA256")

local AUTH = {}

local MAX_AGE = 30000

local seen = {}

-- almost equivalent to textutils.serializeJSON() but ensures to have the same order
local function encode(value)
    local kind = type(value)
    if kind == "table" then
        local keys = {}
        for key in pairs(value) do table.insert(keys, key) end
        table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
        local pairs = {}
        for _, key in ipairs(keys) do
            table.insert(pairs, encode(key) .. "=" .. encode(value[key]))
        end
        return "{" .. table.concat(pairs, ",") .. "}"
    elseif kind == "string" then
        return ("%q"):format(value)
    end
    return tostring(value)
end

-- format the needed parts of the message to sign them
local function signedText(message)
    return table.concat({
        encode(message.target),
        encode(message.command),
        encode(message.value),
        encode(message.time),
    }, "|")
end

-- sign the message using sha256
local function signature(message, password)
    return sha256.hmac(signedText(message), password):toHex()
end

-- removes messages older than the max age from the seen table
local function forgetOld(now)
    for sig, time in pairs(seen) do
        if now - time > MAX_AGE then seen[sig] = nil end
    end
end

-- prepare the message to be signed
function AUTH.sign(message, password)
    message.time = os.epoch("utc")
    message.signature = signature(message, password)
    return message
end

-- check a message validity 
function AUTH.verify(message, password)
    if type(message) ~= "table" or type(message.signature) ~= "string" or type(message.time) ~= "number" then
        return false, "malformed"
    end
    if message.target ~= os.getComputerID() then return false, "other target" end

    local now = os.epoch("utc")

    if math.abs(now - message.time) > MAX_AGE then return false, "expired" end
    forgetOld(now)
    if seen[message.signature] then return false, "replayed" end

    if signature(message, password) ~= message.signature then
        return false, "bad signature"
    end
    seen[message.signature] = message.time
    return true
end

return AUTH