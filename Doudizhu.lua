local addonName, DDZ = ...

DDZ = DDZ or {}
_G.Doudizhu = DDZ

DDZ.version = "0.1.0-alpha"
DDZ.state = {
    loaded = false,
    channel = "PARTY",
    debug = true,
}

DoudizhuDB = DoudizhuDB or {}
DoudizhuCharDB = DoudizhuCharDB or {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local function Log(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Doudizhu]|r " .. tostring(msg))
end

local function Debug(msg)
    if DDZ.state.debug then
        Log(msg)
    end
end

DDZ.Log = Log
DDZ.Debug = Debug

local function HandleSlashCommand(input)
    local text = (input or ""):match("^%s*(.-)%s*$")
    local cmd, rest = text:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "debug" then
        DDZ.state.debug = not DDZ.state.debug
        Log("Debug mode: " .. (DDZ.state.debug and "ON" or "OFF"))
        return
    end

    if cmd == "ui" then
        if DDZ.UI and DDZ.UI.Toggle then
            DDZ.UI.Toggle()
        end
        return
    end

    if cmd == "create" and DDZ.Game and DDZ.Game.CreateSession then
        DDZ.Game.CreateSession()
        return
    end

    if cmd == "join" and DDZ.Game and DDZ.Game.JoinSession then
        DDZ.Game.JoinSession(rest)
        return
    end

    if cmd == "share" and DDZ.Game and DDZ.Game.ShareJoinLinkParty then
        DDZ.Game.ShareJoinLinkParty()
        return
    end

    if cmd == "start" and DDZ.Game and DDZ.Game.StartMVPRound then
        DDZ.Game.StartMVPRound()
        return
    end

    if cmd == "local" and DDZ.Game and DDZ.Game.StartLocalTestMode then
        DDZ.Game.StartLocalTestMode()
        return
    end

    if cmd == "play" and DDZ.Game then
        if rest ~= "" and DDZ.Game.PlayByIndex then
            DDZ.Game.PlayByIndex(rest)
        elseif DDZ.Game.PlayLowestCard then
            DDZ.Game.PlayLowestCard()
        end
        return
    end

    if cmd == "pass" and DDZ.Game and DDZ.Game.PassTurn then
        DDZ.Game.PassTurn()
        return
    end

    if cmd == "hand" and DDZ.Game and DDZ.Game.PrintMyHand then
        DDZ.Game.PrintMyHand()
        return
    end

    if cmd == "state" and DDZ.Game and DDZ.Game.GetInfoText then
        Log((DDZ.Game.GetStatusText and DDZ.Game.GetStatusText()) or "Status: Unknown")
        local info = DDZ.Game.GetInfoText()
        for line in info:gmatch("[^\n]+") do
            Log(line)
        end
        return
    end

    Log("Commands: /ddz ui, /ddz debug, /ddz create, /ddz share, /ddz join <host>, /ddz start, /ddz local, /ddz hand, /ddz play [i,j,k], /ddz pass, /ddz state")
end

SLASH_DOUDIZHU1 = "/ddz"
SlashCmdList.DOUDIZHU = HandleSlashCommand

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            DDZ.state.loaded = true
            Debug("Addon loaded: " .. addonName .. " v" .. DDZ.version)
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        Debug("Player login complete.")
        if not DDZ._joinLinkHooked then
            hooksecurefunc("SetItemRef", function(link)
                local host, sessionId = (link or ""):match("^ddzjoin:([^:]+):(.+)$")
                if not host then
                    return
                end
                if DDZ.Game and DDZ.Game.JoinSession then
                    DDZ.Game.JoinSession(host)
                    DDZ.Log("Joining session " .. tostring(sessionId) .. " hosted by " .. tostring(host))
                end
            end)
            DDZ._joinLinkHooked = true
        end
        if DDZ.UI and DDZ.UI.Init then
            DDZ.UI.Init()
        end
    end
end)
