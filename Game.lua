local _, DDZ = ...

DDZ.Game = DDZ.Game or {}
local HostApplyPlay
local HostApplyPass
local FindPlayerIndex
local ShuffleDeck

DDZ.Game.session = {
    id = nil,
    host = nil,
    players = {},
    started = false,
    phase = "idle",
    landlord = nil,
    bids = {},
    currentBid = 0,
    highestBidder = nil,
    bidActions = 0,
    bidTurnIndex = 1,
    dealCount = 0,
    hands = {},
    handCounts = {},
    bottomCards = {},
    lastPlay = nil,
    recentPlays = {},
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
        return "♠", false
    end
    if suitIndex == 2 then
        return "♥", true
    end
    if suitIndex == 3 then
        return "♣", false
    end
    return "♦", true
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

local function GetAddonVersion()
    return tostring((DDZ and DDZ.version) or "unknown")
end

local function CheckVersionCompatible(remoteVersion)
    local localVersion = GetAddonVersion()
    local peerVersion = tostring(remoteVersion or "")
    if peerVersion == "" then
        return false, "Missing addon version."
    end
    if peerVersion ~= localVersion then
        return false, "Addon version mismatch. Local=" .. localVersion .. ", Remote=" .. peerVersion
    end
    return true, nil
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

local function ComboLabel(combo)
    local labels = {
        single = "Single",
        pair = "Pair",
        triple = "Triple",
        triple_single = "Triple+Single",
        triple_pair = "Triple+Pair",
        straight = "Straight",
        pair_straight = "Pair Straight",
        plane = "Plane",
        plane_single = "Plane+Singles",
        plane_pair = "Plane+Pairs",
        bomb = "Bomb",
        four_two_single = "Four+Two",
        four_two_pair = "Four+TwoPairs",
        rocket = "Rocket",
    }
    return labels[combo.type] or combo.type
end

local function BuildStatePayload()
    local s = DDZ.Game.session
    local payload = {
        session = s.id or "",
        version = GetAddonVersion(),
        phase = s.phase or "idle",
        host = s.host or "",
        turn = s.currentTurn or "",
        landlord = s.landlord or "",
        bid = tostring(s.currentBid or 0),
        highest_bidder = s.highestBidder or "",
        bid_actions = tostring(s.bidActions or 0),
        pass = tostring(s.passCount or 0),
        winner = s.winner or "",
        last_player = s.lastPlay and s.lastPlay.player or "",
        last_type = s.lastPlay and s.lastPlay.type or "",
        last_rank = s.lastPlay and tostring(s.lastPlay.mainRank or 0) or "",
        last_chain = s.lastPlay and tostring(s.lastPlay.chainLen or 0) or "",
        last_count = s.lastPlay and tostring(s.lastPlay.cardCount or 0) or "",
        last_cards = s.lastPlay and JoinCSV(s.lastPlay.cards or {}) or "",
        players = JoinCSV(s.players),
    }
    for i, p in ipairs(s.players) do
        payload["p" .. i] = p
        payload["c" .. i] = tostring(s.handCounts[p] or 0)
        payload["b" .. i] = tostring(s.bids[p] or -1)
        local recent = s.recentPlays and s.recentPlays[p]
        payload["rp_type_" .. i] = recent and recent.type or ""
        payload["rp_rank_" .. i] = recent and tostring(recent.mainRank or 0) or ""
        payload["rp_chain_" .. i] = recent and tostring(recent.chainLen or 0) or ""
        payload["rp_count_" .. i] = recent and tostring(recent.cardCount or 0) or ""
        payload["rp_cards_" .. i] = recent and JoinCSV(recent.cards or {}) or ""
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
        version = GetAddonVersion(),
        host = DDZ.Game.session.host or "",
        players = JoinCSV(DDZ.Game.session.players),
        started = DDZ.Game.session.started and "1" or "0",
    }
    Broadcast("lobby_sync", payload)
    DDZ.Game.ApplyLobbySync(payload)
end

local function CountByRank(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        local rank = CardRank(card)
        counts[rank] = (counts[rank] or 0) + 1
    end
    return counts
end

local function SortedRanksFromCounts(counts)
    local ranks = {}
    for rank, _ in pairs(counts) do
        ranks[#ranks + 1] = rank
    end
    table.sort(ranks)
    return ranks
end

local function IsConsecutive(ranks)
    if #ranks <= 1 then
        return true
    end
    for i = 2, #ranks do
        if ranks[i] ~= ranks[i - 1] + 1 then
            return false
        end
    end
    return true
end

local function FindRankWithCount(counts, target)
    for rank, count in pairs(counts) do
        if count == target then
            return rank
        end
    end
    return nil
end

local function ClassifyCombo(cards)
    if #cards == 0 then
        return nil, "No cards selected."
    end

    local sortedCards = CopyList(cards)
    SortHand(sortedCards)

    local n = #sortedCards
    local counts = CountByRank(sortedCards)
    local uniqueRanks = SortedRanksFromCounts(counts)

    if n == 2 then
        local a, b = sortedCards[1], sortedCards[2]
        if (a == 53 and b == 54) or (a == 54 and b == 53) then
            return { type = "rocket", mainRank = 17, chainLen = 1, cardCount = 2 }
        end
    end

    local fourRank = FindRankWithCount(counts, 4)
    if n == 4 and fourRank then
        return { type = "bomb", mainRank = fourRank, chainLen = 1, cardCount = 4 }
    end

    if n == 1 then
        return { type = "single", mainRank = CardRank(sortedCards[1]), chainLen = 1, cardCount = 1 }
    end
    if n == 2 and #uniqueRanks == 1 and counts[uniqueRanks[1]] == 2 then
        return { type = "pair", mainRank = uniqueRanks[1], chainLen = 1, cardCount = 2 }
    end
    if n == 3 and #uniqueRanks == 1 and counts[uniqueRanks[1]] == 3 then
        return { type = "triple", mainRank = uniqueRanks[1], chainLen = 1, cardCount = 3 }
    end

    if n == 4 then
        for rank, count in pairs(counts) do
            if count == 3 then
                return { type = "triple_single", mainRank = rank, chainLen = 1, cardCount = 4 }
            end
        end
    end

    if n == 5 then
        local tripleRank, pairRank = nil, nil
        for rank, count in pairs(counts) do
            if count == 3 then
                tripleRank = rank
            elseif count == 2 then
                pairRank = rank
            end
        end
        if tripleRank and pairRank then
            return { type = "triple_pair", mainRank = tripleRank, chainLen = 1, cardCount = 5 }
        end
    end

    if n >= 5 and #uniqueRanks == n and uniqueRanks[#uniqueRanks] <= 14 and IsConsecutive(uniqueRanks) then
        return { type = "straight", mainRank = uniqueRanks[#uniqueRanks], chainLen = n, cardCount = n }
    end

    if n >= 6 and n % 2 == 0 and #uniqueRanks == (n / 2) and uniqueRanks[#uniqueRanks] <= 14 and IsConsecutive(uniqueRanks) then
        local valid = true
        for _, rank in ipairs(uniqueRanks) do
            if counts[rank] ~= 2 then
                valid = false
                break
            end
        end
        if valid then
            return { type = "pair_straight", mainRank = uniqueRanks[#uniqueRanks], chainLen = #uniqueRanks, cardCount = n }
        end
    end

    local tripleRanks = {}
    for rank, count in pairs(counts) do
        if count == 3 and rank <= 14 then
            tripleRanks[#tripleRanks + 1] = rank
        end
    end
    table.sort(tripleRanks)

    if #tripleRanks >= 2 and IsConsecutive(tripleRanks) then
        local chain = #tripleRanks
        if n == chain * 3 and #uniqueRanks == chain then
            return { type = "plane", mainRank = tripleRanks[#tripleRanks], chainLen = chain, cardCount = n }
        end

        if n == chain * 4 then
            local singles = 0
            local ok = true
            for rank, count in pairs(counts) do
                if not Contains(tripleRanks, rank) then
                    if count ~= 1 then
                        ok = false
                        break
                    end
                    singles = singles + 1
                end
            end
            if ok and singles == chain then
                return { type = "plane_single", mainRank = tripleRanks[#tripleRanks], chainLen = chain, cardCount = n }
            end
        end

        if n == chain * 5 then
            local pairs = 0
            local ok = true
            for rank, count in pairs(counts) do
                if not Contains(tripleRanks, rank) then
                    if count ~= 2 then
                        ok = false
                        break
                    end
                    pairs = pairs + 1
                end
            end
            if ok and pairs == chain then
                return { type = "plane_pair", mainRank = tripleRanks[#tripleRanks], chainLen = chain, cardCount = n }
            end
        end
    end

    if n == 6 and fourRank then
        return { type = "four_two_single", mainRank = fourRank, chainLen = 1, cardCount = 6 }
    end
    if n == 8 and fourRank then
        local pairCount = 0
        local ok = true
        for rank, count in pairs(counts) do
            if rank ~= fourRank then
                if count ~= 2 then
                    ok = false
                    break
                end
                pairCount = pairCount + 1
            end
        end
        if ok and pairCount == 2 then
            return { type = "four_two_pair", mainRank = fourRank, chainLen = 1, cardCount = 8 }
        end
    end

    return nil, "Invalid combo."
end

local function CanBeat(newCombo, lastCombo)
    if not lastCombo then
        return true
    end
    if newCombo.type == "rocket" then
        return true
    end
    if lastCombo.type == "rocket" then
        return false, "Rocket cannot be beaten."
    end
    if newCombo.type == "bomb" and lastCombo.type ~= "bomb" then
        return true
    end
    if newCombo.type ~= lastCombo.type then
        return false, "Combo type mismatch."
    end

    if newCombo.type == "straight" or newCombo.type == "pair_straight" or newCombo.type == "plane"
        or newCombo.type == "plane_single" or newCombo.type == "plane_pair" then
        if newCombo.chainLen ~= lastCombo.chainLen then
            return false, "Combo length mismatch."
        end
    end

    if newCombo.cardCount ~= lastCombo.cardCount then
        return false, "Card count mismatch."
    end

    if newCombo.mainRank > lastCombo.mainRank then
        return true
    end
    return false, "Combo does not beat last play."
end

local function QueueBotTurn()
    if not IsLocalTest() then
        return
    end
    local s = DDZ.Game.session
    if (s.phase ~= "play" and s.phase ~= "bid") or not IsBot(s.currentTurn) then
        return
    end

    local function EstimateBid(hand, currentBid)
        local score = 0
        for _, card in ipairs(hand) do
            local rank = CardRank(card)
            if rank >= 16 then
                score = score + 4
            elseif rank == 15 then
                score = score + 3
            elseif rank == 14 then
                score = score + 2
            elseif rank >= 11 then
                score = score + 1
            end
        end

        local counts = CountByRank(hand)
        for _, count in pairs(counts) do
            if count == 4 then
                score = score + 4
            elseif count == 3 then
                score = score + 2
            elseif count == 2 then
                score = score + 1
            end
        end

        local targetBid = 0
        if score >= 20 then
            targetBid = 3
        elseif score >= 15 then
            targetBid = 2
        elseif score >= 10 then
            targetBid = 1
        end

        if targetBid <= (currentBid or 0) then
            return 0
        end
        return targetBid
    end

    local function BotTurn()
        local session = DDZ.Game.session
        if (session.phase ~= "play" and session.phase ~= "bid") or not IsBot(session.currentTurn) then
            return
        end
        if session.phase == "bid" then
            local bot = session.currentTurn
            local hand = session.hands[bot] or {}
            DDZ.Game.PlaceBid(EstimateBid(hand, session.currentBid), bot)
            return
        end
        local bot = session.currentTurn
        local hand = session.hands[bot] or {}
        if #hand == 0 then
            return
        end
        SortHand(hand)

        local chosen = nil
        if not session.lastPlay or session.lastPlay.player == bot then
            chosen = { hand[1] }
        elseif session.lastPlay.type == "single" then
            for _, card in ipairs(hand) do
                if CardRank(card) > session.lastPlay.mainRank then
                    chosen = { card }
                    break
                end
            end
        end

        if chosen then
            HostApplyPlay(bot, chosen)
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
        bids = {},
        currentBid = 0,
        highestBidder = nil,
        bidActions = 0,
        bidTurnIndex = 1,
        dealCount = 0,
        hands = {},
        handCounts = {},
        bottomCards = {},
        lastPlay = nil,
        recentPlays = {},
        passCount = 0,
        turnIndex = 1,
        currentTurn = nil,
        winner = nil,
        localTest = false,
    }
end

local function AdvanceBidTurn()
    local s = DDZ.Game.session
    s.bidTurnIndex = (s.bidTurnIndex % #s.players) + 1
    s.currentTurn = s.players[s.bidTurnIndex]
end

local function FinalizeLandlord(landlord)
    local s = DDZ.Game.session
    s.landlord = landlord
    for i = 1, #s.bottomCards do
        s.hands[landlord][#s.hands[landlord] + 1] = s.bottomCards[i]
    end
    for _, p in ipairs(s.players) do
        SortHand(s.hands[p])
        s.handCounts[p] = #(s.hands[p] or {})
    end
    s.phase = "play"
    s.lastPlay = nil
    s.recentPlays = {}
    s.passCount = 0
    s.turnIndex = FindPlayerIndex(landlord) or 1
    s.currentTurn = landlord
    DDZ.Log("Bidding complete. Landlord: " .. tostring(landlord) .. " (bid " .. tostring(s.currentBid or 0) .. ")")
    SendHandsToPlayers()
    SendStateToAll()
    QueueBotTurn()
end

local function BeginBidPhase()
    local s = DDZ.Game.session
    s.landlord = nil
    s.phase = "bid"
    s.started = true
    s.bids = {}
    s.currentBid = 0
    s.highestBidder = nil
    s.bidActions = 0
    s.lastPlay = nil
    s.recentPlays = {}
    s.passCount = 0
    s.winner = nil
    s.bidTurnIndex = 1
    s.currentTurn = s.players[s.bidTurnIndex]
end

local function DealHandsForRound()
    local s = DDZ.Game.session
    s.dealCount = (s.dealCount or 0) + 1
    local baseSeed = tonumber(string.sub(s.id or tostring(time()), -7)) or time()
    local seed = baseSeed + (s.dealCount * 997)
    local deck = ShuffleDeck(seed)
    s.hands = {}
    s.handCounts = {}

    for _, p in ipairs(s.players) do
        s.hands[p] = {}
    end

    local idx = 1
    for _ = 1, 17 do
        for _, p in ipairs(s.players) do
            s.hands[p][#s.hands[p] + 1] = deck[idx]
            idx = idx + 1
        end
    end

    s.bottomCards = { deck[idx], deck[idx + 1], deck[idx + 2] }
    for _, p in ipairs(s.players) do
        SortHand(s.hands[p])
        s.handCounts[p] = #s.hands[p]
    end

    BeginBidPhase()
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
    DDZ.Net.Send("join_request", { name = PlayerName(), version = GetAddonVersion() }, "WHISPER", host)
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

ShuffleDeck = function(seed)
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

FindPlayerIndex = function(name)
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

    DealHandsForRound()
    DDZ.Log("Round dealt. Bidding started." .. (IsLocalTest() and " [LocalBot]" or ""))
    if not IsLocalTest() then
        Broadcast("game_start", {
            session = DDZ.Game.session.id or "",
            version = GetAddonVersion(),
            host = DDZ.Game.session.host or "",
            players = JoinCSV(DDZ.Game.session.players),
            phase = DDZ.Game.session.phase or "bid",
            turn = DDZ.Game.session.currentTurn or "",
        })
    end
    SendHandsToPlayers()
    SendStateToAll()
    QueueBotTurn()
end

local function ValidateBid(player, amount)
    local s = DDZ.Game.session
    local bid = tonumber(amount)
    if s.phase ~= "bid" then
        return false, "Round is not in bidding phase."
    end
    if s.currentTurn ~= player then
        return false, "Not your turn to bid."
    end
    if not bid or bid < 0 or bid > 3 or math.floor(bid) ~= bid then
        return false, "Bid must be an integer from 0 to 3."
    end
    if bid > 0 and bid <= (s.currentBid or 0) then
        return false, "Bid must be higher than current bid."
    end
    return true, bid
end

local function ResolveBidTurn(player, bid)
    local s = DDZ.Game.session
    s.bids[player] = bid
    s.bidActions = (s.bidActions or 0) + 1

    if bid > 0 then
        s.currentBid = bid
        s.highestBidder = player
        DDZ.Log(player .. " bid " .. tostring(bid) .. ".")
    else
        DDZ.Log(player .. " passed bidding.")
    end

    if bid == 3 then
        FinalizeLandlord(player)
        return
    end

    if s.bidActions >= #s.players then
        if s.highestBidder then
            FinalizeLandlord(s.highestBidder)
        else
            DDZ.Log("All players passed. Redealing for a new bidding round.")
            DealHandsForRound()
            SendHandsToPlayers()
            SendStateToAll()
            QueueBotTurn()
        end
        return
    end

    AdvanceBidTurn()
    SendStateToAll()
    QueueBotTurn()
end

local function ValidatePlay(player, cards)
    local s = DDZ.Game.session
    if s.phase ~= "play" then
        return false, "Round is not in play phase."
    end
    if s.currentTurn ~= player then
        return false, "Not your turn."
    end
    if type(cards) ~= "table" or #cards == 0 then
        return false, "No cards selected."
    end

    local hand = s.hands[player] or {}
    local temp = CopyList(hand)
    for _, card in ipairs(cards) do
        local has, idx = Contains(temp, card)
        if not has then
            return false, "Card not in hand."
        end
        table.remove(temp, idx)
    end

    local combo, comboErr = ClassifyCombo(cards)
    if not combo then
        return false, comboErr
    end

    if s.lastPlay and s.lastPlay.player ~= player then
        local beatOk, beatErr = CanBeat(combo, s.lastPlay)
        if not beatOk then
            return false, beatErr
        end
    end

    return true, combo
end

HostApplyPlay = function(player, cards)
    local ok, comboOrErr = ValidatePlay(player, cards)
    if not ok then
        SendTo(player, "action_reject", { reason = tostring(comboOrErr) })
        return
    end

    local combo = comboOrErr
    local hand = DDZ.Game.session.hands[player]
    for _, card in ipairs(cards) do
        local _, idx = Contains(hand, card)
        if idx then
            table.remove(hand, idx)
        end
    end

    DDZ.Game.session.handCounts[player] = #hand
    DDZ.Game.session.lastPlay = {
        player = player,
        type = combo.type,
        mainRank = combo.mainRank,
        chainLen = combo.chainLen,
        cardCount = combo.cardCount,
        cards = CopyList(cards),
    }
    DDZ.Game.session.recentPlays = DDZ.Game.session.recentPlays or {}
    DDZ.Game.session.recentPlays[player] = {
        player = player,
        type = combo.type,
        mainRank = combo.mainRank,
        chainLen = combo.chainLen,
        cardCount = combo.cardCount,
        cards = CopyList(cards),
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
    DDZ.Log(player .. " played " .. ComboLabel(combo) .. " (" .. RankToText(combo.mainRank) .. ")")
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
    DDZ.Game.PlayCards({ hand[1] })
end

function DDZ.Game.PlaceBid(amount, playerOverride)
    local bidder = playerOverride or PlayerName()
    local bid = tonumber(amount)
    if bid == nil then
        DDZ.Log("Usage: /ddz bid <0-3>")
        return
    end
    if IsHost() then
        local ok, bidOrErr = ValidateBid(bidder, bid)
        if not ok then
            if bidder == PlayerName() then
                DDZ.Log(tostring(bidOrErr))
            else
                SendTo(bidder, "action_reject", { reason = tostring(bidOrErr) })
            end
            return
        end
        ResolveBidTurn(bidder, bidOrErr)
    else
        SendTo(DDZ.Game.session.host, "bid_action", {
            session = DDZ.Game.session.id or "",
            bid = tostring(bid),
        })
    end
end

function DDZ.Game.PlayCards(cards)
    if type(cards) ~= "table" or #cards == 0 then
        DDZ.Log("No cards selected.")
        return
    end
    local clean = {}
    for _, card in ipairs(cards) do
        local n = tonumber(card)
        if n then
            clean[#clean + 1] = n
        end
    end
    if #clean == 0 then
        DDZ.Log("No valid cards selected.")
        return
    end
    if IsHost() then
        HostApplyPlay(PlayerName(), clean)
    else
        SendTo(DDZ.Game.session.host, "play_action", {
            session = DDZ.Game.session.id or "",
            cards = JoinCSV(clean),
        })
    end
end

function DDZ.Game.PlayCard(card)
    local numericCard = tonumber(card)
    if not numericCard then
        DDZ.Log("Invalid card.")
        return
    end
    DDZ.Game.PlayCards({ numericCard })
end

function DDZ.Game.PlayByIndex(indexText)
    if not indexText or indexText == "" then
        DDZ.Log("Usage: /ddz play <index or i,j,k>")
        return
    end
    local tokens = ParseCSV(indexText)
    local indexes = {}
    for _, token in ipairs(tokens) do
        local idx = tonumber(token)
        if idx then
            indexes[#indexes + 1] = idx
        end
    end
    if #indexes == 0 then
        DDZ.Log("Usage: /ddz play <index or i,j,k>")
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
    local cards = {}
    for _, idx in ipairs(indexes) do
        local card = sorted[idx]
        if not card then
            DDZ.Log("Invalid index: " .. tostring(idx))
            return
        end
        cards[#cards + 1] = card
    end

    DDZ.Game.PlayCards(cards)
end

function DDZ.Game.PassTurn()
    local me = PlayerName()
    if DDZ.Game.session.phase == "bid" then
        DDZ.Game.PlaceBid(0, me)
        return
    end
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

function DDZ.Game.GetRecentPlay(player)
    if not player or player == "" then
        return nil
    end
    local recentPlays = DDZ.Game.session and DDZ.Game.session.recentPlays
    return recentPlays and recentPlays[player] or nil
end

function DDZ.Game.GetComboPreview(cards)
    local combo, err = ClassifyCombo(cards or {})
    if not combo then
        return false, err
    end
    return true, ComboLabel(combo) .. " (" .. RankToText(combo.mainRank) .. ")"
end

function DDZ.Game.ApplyLobbySync(payload)
    DDZ.Game.session.id = payload.session ~= "" and payload.session or DDZ.Game.session.id
    DDZ.Game.session.host = payload.host ~= "" and payload.host or DDZ.Game.session.host
    DDZ.Game.session.players = ParseCSV(payload.players or "")
    DDZ.Game.session.phase = (payload.started == "1") and (DDZ.Game.session.phase == "ended" and "ended" or "bid") or "lobby"
    DDZ.Game.session.started = payload.started == "1"
    DDZ.Game.session.handCounts = DDZ.Game.session.handCounts or {}
    DDZ.Game.session.bids = DDZ.Game.session.bids or {}
    DDZ.Game.session.recentPlays = DDZ.Game.session.recentPlays or {}
    for _, p in ipairs(DDZ.Game.session.players) do
        DDZ.Game.session.handCounts[p] = DDZ.Game.session.handCounts[p] or 0
        DDZ.Game.session.bids[p] = DDZ.Game.session.bids[p] or -1
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
    s.currentBid = tonumber(payload.bid or "0") or 0
    s.highestBidder = payload.highest_bidder ~= "" and payload.highest_bidder or nil
    s.bidActions = tonumber(payload.bid_actions or "0") or 0
    s.passCount = tonumber(payload.pass or "0") or 0
    s.winner = payload.winner ~= "" and payload.winner or nil
    s.players = ParseCSV(payload.players or "")
    s.started = s.phase == "bid" or s.phase == "play" or s.phase == "ended"
    if payload.last_player ~= "" and payload.last_type ~= "" then
        s.lastPlay = {
            player = payload.last_player,
            type = payload.last_type,
            mainRank = tonumber(payload.last_rank or "0") or 0,
            chainLen = tonumber(payload.last_chain or "0") or 0,
            cardCount = tonumber(payload.last_count or "0") or 0,
            cards = ToNumberList(payload.last_cards),
        }
    else
        s.lastPlay = nil
    end
    s.handCounts = s.handCounts or {}
    s.bids = s.bids or {}
    s.recentPlays = {}
    for i, p in ipairs(s.players) do
        s.handCounts[p] = tonumber(payload["c" .. i] or "0") or 0
        s.bids[p] = tonumber(payload["b" .. i] or "-1") or -1
        if payload["rp_type_" .. i] ~= "" then
            s.recentPlays[p] = {
                player = p,
                type = payload["rp_type_" .. i],
                mainRank = tonumber(payload["rp_rank_" .. i] or "0") or 0,
                chainLen = tonumber(payload["rp_chain_" .. i] or "0") or 0,
                cardCount = tonumber(payload["rp_count_" .. i] or "0") or 0,
                cards = ToNumberList(payload["rp_cards_" .. i]),
            }
        end
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
    if s.phase == "bid" then
        local turn = s.currentTurn or "?"
        local mode = s.localTest and " [LocalBot]" or ""
        return "Status: Bidding" .. mode .. ".\nTurn: " .. turn .. ". Current Bid: " .. tostring(s.currentBid or 0)
    end
    if s.phase == "play" then
        local turn = s.currentTurn or "?"
        local mode = s.localTest and " [LocalBot]" or ""
        return "Status: Playing" .. mode .. ".\nTurn: " .. turn
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
    if s.phase == "bid" or s.currentBid > 0 or s.highestBidder then
        lines[#lines + 1] = "Current bid: " .. tostring(s.currentBid or 0)
        lines[#lines + 1] = "Highest bidder: " .. tostring(s.highestBidder or "none")
        for _, p in ipairs(s.players) do
            local bid = s.bids[p]
            if bid and bid >= 0 then
                lines[#lines + 1] = "Bid - " .. p .. ": " .. tostring(bid)
            end
        end
    end
    if s.lastPlay then
        lines[#lines + 1] = "Last: " .. s.lastPlay.player .. " played " .. ComboLabel(s.lastPlay)
            .. " (" .. RankToText(s.lastPlay.mainRank or 0) .. ")"
    end
    return table.concat(lines, "\n")
end

function DDZ.Game.OnNetworkMessage(msgType, payload, channel, sender)
    if msgType == "join_request" then
        if not IsHost() then
            return
        end
        local okVersion, versionErr = CheckVersionCompatible(payload.version)
        if not okVersion then
            SendTo(sender, "join_reject", { reason = versionErr .. " Host=" .. GetAddonVersion() })
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
            version = GetAddonVersion(),
        })
        BroadcastLobby()
        return
    end

    if msgType == "join_accept" then
        local okVersion, versionErr = CheckVersionCompatible(payload.version)
        if not okVersion then
            DDZ.Log("Join rejected locally: " .. versionErr)
            return
        end
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
        local okVersion, versionErr = CheckVersionCompatible(payload.version)
        if not okVersion then
            DDZ.Log("Ignoring lobby sync: " .. versionErr)
            return
        end
        DDZ.Game.ApplyLobbySync(payload)
        return
    end

    if msgType == "game_start" then
        local okVersion, versionErr = CheckVersionCompatible(payload.version)
        if not okVersion then
            DDZ.Log("Ignoring game start: " .. versionErr)
            return
        end
        DDZ.Game.session.id = payload.session
        DDZ.Game.session.host = payload.host
        DDZ.Game.session.players = ParseCSV(payload.players or "")
        DDZ.Game.session.landlord = payload.landlord ~= "" and payload.landlord or nil
        DDZ.Game.session.currentTurn = payload.turn
        DDZ.Game.session.bottomCards = payload.bottom and payload.bottom ~= "" and ToNumberList(payload.bottom) or {}
        DDZ.Game.session.phase = payload.phase ~= "" and payload.phase or "bid"
        DDZ.Game.session.started = true
        DDZ.Game.session.currentBid = 0
        DDZ.Game.session.highestBidder = nil
        DDZ.Game.session.bidActions = 0
        DDZ.Game.session.handCounts = DDZ.Game.session.handCounts or {}
        DDZ.Game.session.bids = DDZ.Game.session.bids or {}
        for _, p in ipairs(DDZ.Game.session.players) do
            DDZ.Game.session.handCounts[p] = DDZ.Game.session.handCounts[p] or 0
            DDZ.Game.session.bids[p] = DDZ.Game.session.bids[p] or -1
        end
        NotifyUI()
        DDZ.Log("Round started. Phase: " .. tostring(DDZ.Game.session.phase))
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
        local okVersion, versionErr = CheckVersionCompatible(payload.version)
        if not okVersion then
            DDZ.Log("Ignoring state sync: " .. versionErr)
            return
        end
        DDZ.Game.ApplyStateSync(payload)
        return
    end

    if msgType == "play_action" then
        if IsHost() then
            local cards = {}
            if payload.cards and payload.cards ~= "" then
                cards = ToNumberList(payload.cards)
            elseif payload.card and payload.card ~= "" then
                cards = { tonumber(payload.card) }
            end
            HostApplyPlay(sender, cards)
        end
        return
    end

    if msgType == "bid_action" then
        if IsHost() then
            local bid = tonumber(payload.bid or "")
            local ok, bidOrErr = ValidateBid(sender, bid)
            if not ok then
                SendTo(sender, "action_reject", { reason = tostring(bidOrErr) })
                return
            end
            ResolveBidTurn(sender, bidOrErr)
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

    DDZ.Debug("Unknown net message: " .. tostring(msgType) .. " via " .. tostring(channel))
end
