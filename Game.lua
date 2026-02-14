local _, DDZ = ...

DDZ.Game = DDZ.Game or {}
local HostApplyPlay
local HostApplyPass

DDZ.Game.session = {
    id = nil,
    host = nil,
    players = {},
    started = false,
    phase = "idle",
    landlord = nil,
    hands = {},
    handCounts = {},
    bottomCards = {},
    lastPlay = nil,
    passCount = 0,
    turnIndex = 1,
    currentTurn = nil,
    winner = nil,
    localTest = false,
}

local function PlayerName()
    local name, realm = UnitFullName("player")
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function ParseCSV(value)
    local out = {}
    for part in (value or ""):gmatch("[^,]+") do
        out[#out + 1] = part
    end
    return out
end

local function JoinCSV(list)
    return table.concat(list or {}, ",")
end

local function ToNumberList(csv)
    local out = {}
    for _, v in ipairs(ParseCSV(csv)) do
        out[#out + 1] = tonumber(v)
    end
    return out
end

local function Contains(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true, i
        end
    end
    return false, nil
end

local function CopyList(list)
    local out = {}
    for i = 1, #list do
        out[i] = list[i]
    end
    return out
end

local function CardRank(card)
    if card == 53 then
        return 16
    end
    if card == 54 then
        return 17
    end
    local idx = ((card - 1) % 13) + 1
    if idx == 1 then
        return 14
    end
    if idx == 2 then
        return 15
    end
    return idx
end

local function CardSuit(card)
    if card == 53 then
        return "", false
    end
    if card == 54 then
        return "", true
    end
    local suitIndex = math.floor((card - 1) / 13) + 1
    if suitIndex == 1 then
        return "S", false
    end
    if suitIndex == 2 then
        return "H", true
    end
    if suitIndex == 3 then
        return "C", false
    end
    return "D", true
end

local function SortHand(hand)
    table.sort(hand, function(a, b)
        local ra, rb = CardRank(a), CardRank(b)
        if ra == rb then
            return a < b
        end
        return ra < rb
    end)
end

local function RankToText(rank)
    local labels = {
        [3] = "3", [4] = "4", [5] = "5", [6] = "6", [7] = "7", [8] = "8", [9] = "9",
        [10] = "10", [11] = "J", [12] = "Q", [13] = "K", [14] = "A", [15] = "2",
        [16] = "SJ", [17] = "BJ",
    }
    return labels[rank] or tostring(rank)
end

local function HandDisplayEntries(hand)
    local sorted = CopyList(hand or {})
    SortHand(sorted)
    local entries = {}
    for i, card in ipairs(sorted) do
        entries[#entries + 1] = tostring(i) .. ":" .. RankToText(CardRank(card)) .. CardSuit(card)
    end
    return sorted, entries
end

local function CardText(card)
    if card == 53 then
        return "SJ"
    end
    if card == 54 then
        return "BJ"
    end
    return RankToText(CardRank(card)) .. CardSuit(card)
end

local function IsHost()
    return DDZ.Game.session.host == PlayerName()
end

local function IsBot(name)
    return type(name) == "string" and name:match("^DDZ_BOT_") ~= nil
end

local function IsLocalTest()
    return DDZ.Game.session.localTest == true
end

local function NotifyUI()
    if DDZ.UI and DDZ.UI.Refresh then
        DDZ.UI.Refresh()
    end
end

local function SendTo(target, msgType, payload)
    if IsLocalTest() then
        return
    end
    DDZ.Net.Send(msgType, payload, "WHISPER", target)
end

local function Broadcast(msgType, payload)
    if IsLocalTest() then
        return
    end
    for _, p in ipairs(DDZ.Game.session.players) do
        if p ~= PlayerName() then
            SendTo(p, msgType, payload)
        end
    end
end

local function BuildStatePayload()
    local s = DDZ.Game.session
    local payload = {
        session = s.id or "",
        phase = s.phase or "idle",
        host = s.host or "",
        turn = s.currentTurn or "",
        landlord = s.landlord or "",
        pass = tostring(s.passCount or 0),
        winner = s.winner or "",
        last_player = s.lastPlay and s.lastPlay.player or "",
        last_card = s.lastPlay and tostring(s.lastPlay.card) or "",
        players = JoinCSV(s.players),
    }
    for i, p in ipairs(s.players) do
        payload["p" .. i] = p
        payload["c" .. i] = tostring(s.handCounts[p] or 0)
    end
    return payload
end

local function SendStateToAll()
    local payload = BuildStatePayload()
    Broadcast("state_sync", payload)
    DDZ.Game.ApplyStateSync(payload)
end

local function SendHandsToPlayers()
    for _, p in ipairs(DDZ.Game.session.players) do
        local hand = DDZ.Game.session.hands[p] or {}
        if IsBot(p) then
            DDZ.Game.session.handCounts[p] = #hand
        elseif p == PlayerName() then
            DDZ.Game.session.hands[p] = hand
            DDZ.Game.session.handCounts[p] = #hand
            NotifyUI()
        else
            SendTo(p, "hand_sync", {
                session = DDZ.Game.session.id or "",
                cards = JoinCSV(hand),
            })
        end
    end
end

local function BroadcastLobby()
    local payload = {
        session = DDZ.Game.session.id or "",
        host = DDZ.Game.session.host or "",
        players = JoinCSV(DDZ.Game.session.players),
        started = DDZ.Game.session.started and "1" or "0",
    }
    Broadcast("lobby_sync", payload)
    DDZ.Game.ApplyLobbySync(payload)
end

local function QueueBotTurn()
    if not IsLocalTest() then
        return
    end
    local s = DDZ.Game.session
    if s.phase ~= "play" then
        return
    end
    if not IsBot(s.currentTurn) then
        return
    end

    local function BotTurn()
        if DDZ.Game.session.phase ~= "play" then
            return
        end
        local bot = DDZ.Game.session.currentTurn
        if not IsBot(bot) then
            return
        end
        local hand = DDZ.Game.session.hands[bot] or {}
        if #hand == 0 then
            return
        end
        SortHand(hand)

        local chosenCard = nil
        if not DDZ.Game.session.lastPlay or DDZ.Game.session.lastPlay.player == bot then
            chosenCard = hand[1]
        else
            local targetRank = DDZ.Game.session.lastPlay.rank
            for _, card in ipairs(hand) do
                if CardRank(card) > targetRank then
                    chosenCard = card
                    break
                end
            end
        end

        if chosenCard then
            HostApplyPlay(bot, chosenCard)
        else
            HostApplyPass(bot)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.6, BotTurn)
    else
        BotTurn()
    end
end

local function ResetSession()
    DDZ.Game.session = {
        id = tostring(math.floor(GetServerTime() or time())),
        host = nil,
        players = {},
        started = false,
        phase = "idle",
        landlord = nil,
        hands = {},
        handCounts = {},
        bottomCards = {},
        lastPlay = nil,
        passCount = 0,
        turnIndex = 1,
        currentTurn = nil,
        winner = nil,
        localTest = false,
    }
end

function DDZ.Game.CreateSession()
    ResetSession()
    local me = PlayerName()
    DDZ.Game.session.host = me
    DDZ.Game.session.players = { me }
    DDZ.Game.session.phase = "lobby"
    DDZ.Log("Created session " .. DDZ.Game.session.id)
    NotifyUI()
end

function DDZ.Game.StartLocalTestMode()
    ResetSession()
    local me = PlayerName()
    DDZ.Game.session.host = me
    DDZ.Game.session.players = { me, "DDZ_BOT_A", "DDZ_BOT_B" }
    DDZ.Game.session.phase = "lobby"
    DDZ.Game.session.localTest = true
    DDZ.Log("Local bot test mode ready.")
    DDZ.Game.StartMVPRound()
end

function DDZ.Game.JoinSession(host)
    if not host or host == "" then
        DDZ.Log("Usage: /ddz join <hostName>")
        return
    end
    DDZ.Net.Send("join_request", { name = PlayerName() }, "WHISPER", host)
    DDZ.Log("Join request sent to " .. tostring(host))
end

function DDZ.Game.ShareJoinLinkParty()
    if IsLocalTest() then
        DDZ.Log("Local test mode does not support party join links.")
        return
    end

    if DDZ.Game.session.phase == "idle" then
        DDZ.Game.CreateSession()
    end

    local host = DDZ.Game.session.host or PlayerName()
    local sessionId = DDZ.Game.session.id or tostring(math.floor(GetServerTime() or time()))
    local hostShort = host:match("^[^-]+") or host
    local link = "|cff66ccff|Hddzjoin:" .. host .. ":" .. sessionId .. "|h[Join Doudizhu]|h|r"
    local msg = "Doudizhu lobby by " .. hostShort .. " " .. link

    if IsInGroup() and not IsInRaid() then
        SendChatMessage(msg, "PARTY")
        DDZ.Log("Party join link shared.")
    else
        DDZ.Log("Not in a party. Click this link locally: " .. link)
    end
end

local function ShuffleDeck(seed)
    local deck = {}
    for i = 1, 54 do
        deck[#deck + 1] = i
    end
    local x = tonumber(seed) or 1
    local function Next()
        x = (1103515245 * x + 12345) % 2147483647
        return x
    end
    for i = #deck, 2, -1 do
        local j = (Next() % i) + 1
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

local function AdvanceTurn()
    local s = DDZ.Game.session
    s.turnIndex = (s.turnIndex % #s.players) + 1
    s.currentTurn = s.players[s.turnIndex]
end

local function FindPlayerIndex(name)
    for i, p in ipairs(DDZ.Game.session.players) do
        if p == name then
            return i
        end
    end
    return nil
end

function DDZ.Game.StartMVPRound()
    if not IsHost() then
        DDZ.Log("Only host can start the round.")
        return
    end
    if #DDZ.Game.session.players ~= 3 then
        DDZ.Log("Need exactly 3 players for MVP round.")
        return
    end

    local seed = tonumber(string.sub(DDZ.Game.session.id or tostring(time()), -7)) or time()
    local deck = ShuffleDeck(seed)
    DDZ.Game.session.hands = {}
    DDZ.Game.session.handCounts = {}

    for _, p in ipairs(DDZ.Game.session.players) do
        DDZ.Game.session.hands[p] = {}
    end

    local idx = 1
    for _ = 1, 17 do
        for _, p in ipairs(DDZ.Game.session.players) do
            DDZ.Game.session.hands[p][#DDZ.Game.session.hands[p] + 1] = deck[idx]
            idx = idx + 1
        end
    end

    DDZ.Game.session.bottomCards = { deck[idx], deck[idx + 1], deck[idx + 2] }
    DDZ.Game.session.landlord = DDZ.Game.session.players[1]
    for i = 1, 3 do
        DDZ.Game.session.hands[DDZ.Game.session.landlord][#DDZ.Game.session.hands[DDZ.Game.session.landlord] + 1] = DDZ.Game.session.bottomCards[i]
    end

    for _, p in ipairs(DDZ.Game.session.players) do
        SortHand(DDZ.Game.session.hands[p])
        DDZ.Game.session.handCounts[p] = #DDZ.Game.session.hands[p]
    end

    DDZ.Game.session.started = true
    DDZ.Game.session.phase = "play"
    DDZ.Game.session.lastPlay = nil
    DDZ.Game.session.passCount = 0
    DDZ.Game.session.winner = nil
    DDZ.Game.session.turnIndex = FindPlayerIndex(DDZ.Game.session.landlord) or 1
    DDZ.Game.session.currentTurn = DDZ.Game.session.players[DDZ.Game.session.turnIndex]

    DDZ.Log("MVP round started. Landlord: " .. DDZ.Game.session.landlord .. (IsLocalTest() and " (local test)" or ""))
    if not IsLocalTest() then
        Broadcast("game_start", {
            session = DDZ.Game.session.id or "",
            host = DDZ.Game.session.host or "",
            players = JoinCSV(DDZ.Game.session.players),
            landlord = DDZ.Game.session.landlord or "",
            turn = DDZ.Game.session.currentTurn or "",
            bottom = JoinCSV(DDZ.Game.session.bottomCards),
        })
    end
    SendHandsToPlayers()
    SendStateToAll()
    QueueBotTurn()
end

local function ValidatePlay(player, card)
    local s = DDZ.Game.session
    if s.phase ~= "play" then
        return false, "Round is not in play phase."
    end
    if s.currentTurn ~= player then
        return false, "Not your turn."
    end
    local hand = s.hands[player] or {}
    local has, idx = Contains(hand, card)
    if not has then
        return false, "Card not in hand."
    end
    local rank = CardRank(card)
    if s.lastPlay and s.lastPlay.player ~= player and rank <= s.lastPlay.rank then
        return false, "Card must beat last play (" .. RankToText(s.lastPlay.rank) .. ")."
    end
    return true, idx, rank
end

HostApplyPlay = function(player, card)
    local ok, idx, rankOrErr = ValidatePlay(player, card)
    if not ok then
        SendTo(player, "action_reject", { reason = tostring(idx or rankOrErr) })
        return
    end

    local rank = rankOrErr
    local hand = DDZ.Game.session.hands[player]
    table.remove(hand, idx)
    DDZ.Game.session.handCounts[player] = #hand
    DDZ.Game.session.lastPlay = {
        player = player,
        card = card,
        rank = rank,
    }
    DDZ.Game.session.passCount = 0

    if #hand == 0 then
        DDZ.Game.session.phase = "ended"
        DDZ.Game.session.winner = player
        DDZ.Game.session.currentTurn = nil
        DDZ.Log("Round over. Winner: " .. player)
        SendHandsToPlayers()
        SendStateToAll()
        return
    end

    AdvanceTurn()
    DDZ.Log(player .. " played " .. RankToText(rank))
    SendHandsToPlayers()
    SendStateToAll()
    QueueBotTurn()
end

HostApplyPass = function(player)
    local s = DDZ.Game.session
    if s.phase ~= "play" then
        SendTo(player, "action_reject", { reason = "Round is not in play phase." })
        return
    end
    if s.currentTurn ~= player then
        SendTo(player, "action_reject", { reason = "Not your turn." })
        return
    end
    if not s.lastPlay or s.lastPlay.player == player then
        SendTo(player, "action_reject", { reason = "Cannot pass on a fresh trick." })
        return
    end

    s.passCount = s.passCount + 1
    if s.passCount >= 2 then
        local leader = s.lastPlay.player
        s.lastPlay = nil
        s.passCount = 0
        s.turnIndex = FindPlayerIndex(leader) or s.turnIndex
        s.currentTurn = leader
        DDZ.Log("Trick reset. " .. leader .. " leads.")
    else
        AdvanceTurn()
        DDZ.Log(player .. " passed.")
    end
    SendStateToAll()
    QueueBotTurn()
end

function DDZ.Game.PlayLowestCard()
    local me = PlayerName()
    local hand = DDZ.Game.session.hands[me] or {}
    if #hand == 0 then
        DDZ.Log("No cards available to play.")
        return
    end
    SortHand(hand)
    local card = hand[1]
    if IsHost() then
        HostApplyPlay(me, card)
    else
        SendTo(DDZ.Game.session.host, "play_action", {
            session = DDZ.Game.session.id or "",
            card = tostring(card),
        })
    end
end

function DDZ.Game.PlayCard(card)
    local numericCard = tonumber(card)
    if not numericCard then
        DDZ.Log("Invalid card.")
        return
    end
    local me = PlayerName()
    local hand = DDZ.Game.session.hands[me] or {}
    local has = Contains(hand, numericCard)
    if not has then
        DDZ.Log("Selected card is not in your hand.")
        return
    end

    if IsHost() then
        HostApplyPlay(me, numericCard)
    else
        SendTo(DDZ.Game.session.host, "play_action", {
            session = DDZ.Game.session.id or "",
            card = tostring(numericCard),
        })
    end
end

function DDZ.Game.PlayByIndex(index)
    local idx = tonumber(index)
    if not idx then
        DDZ.Log("Usage: /ddz play <index>")
        return
    end

    local me = PlayerName()
    local hand = DDZ.Game.session.hands[me] or {}
    if #hand == 0 then
        DDZ.Log("No cards available to play.")
        return
    end

    local sorted = CopyList(hand)
    SortHand(sorted)
    local card = sorted[idx]
    if not card then
        DDZ.Log("Invalid index. Use /ddz hand or /ddz state to view indexes.")
        return
    end

    DDZ.Game.PlayCard(card)
end

function DDZ.Game.PassTurn()
    local me = PlayerName()
    if IsHost() then
        HostApplyPass(me)
    else
        SendTo(DDZ.Game.session.host, "pass_action", {
            session = DDZ.Game.session.id or "",
        })
    end
end

function DDZ.Game.PrintMyHand()
    local me = PlayerName()
    local hand = DDZ.Game.session.hands[me] or {}
    if #hand == 0 then
        DDZ.Log("My hand: (empty)")
        return
    end
    local _, entries = HandDisplayEntries(hand)
    DDZ.Log("My hand: " .. table.concat(entries, "  "))
end

function DDZ.Game.GetMySortedHand()
    local me = PlayerName()
    local hand = DDZ.Game.session.hands[me] or {}
    local sorted = CopyList(hand)
    SortHand(sorted)
    return sorted
end

function DDZ.Game.GetCardText(card)
    return CardText(card)
end

function DDZ.Game.GetCardColor(card)
    local _, isRed = CardSuit(card)
    if isRed then
        return 0.85, 0.2, 0.2
    end
    return 0.15, 0.15, 0.15
end

function DDZ.Game.ApplyLobbySync(payload)
    DDZ.Game.session.id = payload.session ~= "" and payload.session or DDZ.Game.session.id
    DDZ.Game.session.host = payload.host ~= "" and payload.host or DDZ.Game.session.host
    DDZ.Game.session.players = ParseCSV(payload.players or "")
    DDZ.Game.session.phase = (payload.started == "1") and "play" or "lobby"
    DDZ.Game.session.started = payload.started == "1"
    DDZ.Game.session.handCounts = DDZ.Game.session.handCounts or {}
    for _, p in ipairs(DDZ.Game.session.players) do
        DDZ.Game.session.handCounts[p] = DDZ.Game.session.handCounts[p] or 0
    end
    NotifyUI()
end

function DDZ.Game.ApplyStateSync(payload)
    local s = DDZ.Game.session
    s.id = payload.session ~= "" and payload.session or s.id
    s.host = payload.host ~= "" and payload.host or s.host
    s.phase = payload.phase ~= "" and payload.phase or s.phase
    s.currentTurn = payload.turn ~= "" and payload.turn or nil
    s.landlord = payload.landlord ~= "" and payload.landlord or nil
    s.passCount = tonumber(payload.pass or "0") or 0
    s.winner = payload.winner ~= "" and payload.winner or nil
    s.players = ParseCSV(payload.players or "")
    s.started = s.phase == "play" or s.phase == "ended"
    if payload.last_player ~= "" and payload.last_card ~= "" then
        local card = tonumber(payload.last_card)
        if card then
            s.lastPlay = {
                player = payload.last_player,
                card = card,
                rank = CardRank(card),
            }
        end
    else
        s.lastPlay = nil
    end
    s.handCounts = s.handCounts or {}
    for i, p in ipairs(s.players) do
        s.handCounts[p] = tonumber(payload["c" .. i] or "0") or 0
    end
    NotifyUI()
end

function DDZ.Game.GetStatusText()
    local s = DDZ.Game.session
    if not s.id then
        return "Status: Idle"
    end
    if s.phase == "lobby" then
        return "Status: Lobby (" .. tostring(#s.players) .. "/3)"
    end
    if s.phase == "play" then
        local turn = s.currentTurn or "?"
        local mode = s.localTest and " [LocalBot]" or ""
        return "Status: Playing" .. mode .. ". Turn: " .. turn
    end
    if s.phase == "ended" then
        return "Status: Ended. Winner: " .. tostring(s.winner or "?")
    end
    return "Status: " .. tostring(s.phase)
end

function DDZ.Game.GetInfoText()
    local s = DDZ.Game.session
    if not s.id then
        return "No session."
    end
    local lines = {
        "Session: " .. tostring(s.id),
        "Host: " .. tostring(s.host or "?"),
        "Mode: " .. (s.localTest and "Local Bot Test" or "Multiplayer"),
        "Players:",
    }
    for _, p in ipairs(s.players) do
        lines[#lines + 1] = " - " .. p .. " (" .. tostring(s.handCounts[p] or 0) .. ")"
    end
    local me = PlayerName()
    local myHand = s.hands[me] or {}
    lines[#lines + 1] = "My cards: " .. tostring(#myHand)
    if #myHand > 0 then
        local _, entries = HandDisplayEntries(myHand)
        lines[#lines + 1] = "Hand: " .. table.concat(entries, " ")
    end
    if s.lastPlay then
        lines[#lines + 1] = "Last: " .. s.lastPlay.player .. " played " .. RankToText(s.lastPlay.rank)
    end
    return table.concat(lines, "\n")
end

function DDZ.Game.OnNetworkMessage(msgType, payload, channel, sender)
    if msgType == "join_request" then
        if not IsHost() then
            return
        end
        if DDZ.Game.session.phase ~= "lobby" then
            SendTo(sender, "join_reject", { reason = "Game already started." })
            return
        end
        local exists = Contains(DDZ.Game.session.players, sender)
        if not exists then
            if #DDZ.Game.session.players >= 3 then
                SendTo(sender, "join_reject", { reason = "Lobby is full." })
                return
            end
            DDZ.Game.session.players[#DDZ.Game.session.players + 1] = sender
            DDZ.Game.session.handCounts[sender] = 0
            DDZ.Log("Player joined: " .. sender)
        end
        SendTo(sender, "join_accept", {
            session = DDZ.Game.session.id or "",
            host = DDZ.Game.session.host or "",
        })
        BroadcastLobby()
        return
    end

    if msgType == "join_accept" then
        DDZ.Log("Join accepted by " .. tostring(sender))
        DDZ.Game.session.id = payload.session
        DDZ.Game.session.host = payload.host ~= "" and payload.host or sender
        DDZ.Game.session.phase = "lobby"
        NotifyUI()
        return
    end

    if msgType == "join_reject" then
        DDZ.Log("Join rejected: " .. tostring(payload.reason or "unknown"))
        return
    end

    if msgType == "lobby_sync" then
        DDZ.Game.ApplyLobbySync(payload)
        return
    end

    if msgType == "game_start" then
        DDZ.Game.session.id = payload.session
        DDZ.Game.session.host = payload.host
        DDZ.Game.session.players = ParseCSV(payload.players or "")
        DDZ.Game.session.landlord = payload.landlord
        DDZ.Game.session.currentTurn = payload.turn
        DDZ.Game.session.bottomCards = ToNumberList(payload.bottom)
        DDZ.Game.session.phase = "play"
        DDZ.Game.session.started = true
        DDZ.Game.session.handCounts = DDZ.Game.session.handCounts or {}
        for _, p in ipairs(DDZ.Game.session.players) do
            DDZ.Game.session.handCounts[p] = DDZ.Game.session.handCounts[p] or 0
        end
        NotifyUI()
        DDZ.Log("Round started. Landlord: " .. tostring(payload.landlord))
        return
    end

    if msgType == "hand_sync" then
        local me = PlayerName()
        DDZ.Game.session.hands[me] = ToNumberList(payload.cards)
        SortHand(DDZ.Game.session.hands[me])
        DDZ.Game.session.handCounts[me] = #DDZ.Game.session.hands[me]
        NotifyUI()
        return
    end

    if msgType == "state_sync" then
        DDZ.Game.ApplyStateSync(payload)
        return
    end

    if msgType == "play_action" then
        if IsHost() then
            HostApplyPlay(sender, tonumber(payload.card))
        end
        return
    end

    if msgType == "pass_action" then
        if IsHost() then
            HostApplyPass(sender)
        end
        return
    end

    if msgType == "action_reject" then
        DDZ.Log("Action rejected: " .. tostring(payload.reason))
        return
    end

    DDZ.Debug("Unknown net message: " .. tostring(msgType))
end
