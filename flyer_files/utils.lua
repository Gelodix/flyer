local UTILS = {}

function UTILS.secureReadFile(fileName, binary)
    if fs.exists(fileName) then
        local file = fs.open(fileName, binary and "rb" or "r")
        if not file then return nil end
        local content = file.readAll()
        file.close()
        return content
    end
    return nil
end

function UTILS.secureWriteFile(fileName, binary, content, overwrite)
    if fs.exists(fileName) and not overwrite then
        return nil
    else
        local file =  fs.open(fileName, binary and "wb" or "w")
        if not file then return nil end
        file.write(content)
        file.close()
    end 
end

function UTILS.download(url)
    if not http then return nil, "HTTP disabled" end
    local separator = url:find("?", 1, true) and "&" or "?"
    local res, err = http.get(url .. separator .. "t=" .. os.epoch("utc"), { ["Cache-Control"] = "no-cache" }, true)
    if not res then return nil, tostring(err) end
    local code = res.getResponseCode()
    local body = res.readAll()
    res.close()
    if code ~= 200 then return nil, "HTTP" .. tostring(code) end
    return body
end

function UTILS.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function UTILS.safeRsSignal(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.floor(UTILS.clamp(value, 0, 15))
end

function UTILS.yawFromQuaternion(w, x, y, z)
    local siny_cosp = 2 * (w * y - z * x)
    local cosy_cosp = 1 - 2 * (x * x + y * y)
    local yawRad =  math.atan2(siny_cosp, cosy_cosp)
    return math.deg(yawRad)
end

return UTILS