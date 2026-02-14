local _, DDZ = ...

DDZ.Net = DDZ.Net or {}

local PREFIX = "DDZ12"

local function Encode(tbl)
    if type(tbl) ~= "table" then
        return tostring(tbl or "")
    end
    local parts = {}
    for k, v in pairs(tbl) do
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
    end
    return table.concat(parts, "&")
end

local function Decode(str)
    local out = {}
    for pair in (str or ""):gmatch("[^&]+") do
        local k, v = pair:match("([^=]+)=(.*)")
        if k then
            out[k] = v
        end
    end
    return out
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end

function DDZ.Net.Send(msgType, payload, channel, target)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        DDZ.Log("Addon messaging API unavailable.")
        return
    end
    local message = "t=" .. tostring(msgType or "unknown") .. "&" .. Encode(payload or {})
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel or DDZ.state.channel, target)
end

eventFrame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= PREFIX then
        return
    end
    local decoded = Decode(message)
    local msgType = decoded.t
    decoded.t = nil

    if DDZ.Game and DDZ.Game.OnNetworkMessage then
        DDZ.Game.OnNetworkMessage(msgType, decoded, channel, sender)
    end
end)
