local _, DDZ = ...

DDZ.UI = DDZ.UI or {}

local mainFrame
local cardButtons = {}
local RECENT_PLAY_MAX = 3
local RECENT_CARD_WIDTH = 22
local RECENT_CARD_HEIGHT = 28
local RECENT_CARD_GAP_X = 2
local RECENT_PLAY_LABEL_WIDTH = 132
local RECENT_PLAY_ROW_GAP = 8
local RECENT_PLAY_INNER_GAP = 8
local RECENT_PLAY_TURN_LABEL = "<"
local RECENT_PLAY_TURN_WIDTH = 12
local RECENT_PLAY_LANDLORD_LABEL = "$"
local RECENT_PLAY_LANDLORD_WIDTH = 12
local RECENT_PLAY_ROW_HEIGHT = RECENT_CARD_HEIGHT

local function PlayerName()
    local name, realm = UnitFullName("player")
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function TruncateName(name)
    if not name then
        return "?"
    end
    return tostring(name):match("^[^-]+") or tostring(name)
end

local function IsBotName(name)
    return type(name) == "string" and name:match("^DDZ_BOT_") ~= nil
end

local function FullUnitName(unit)
    local name, realm = UnitFullName(unit)
    if not name then
        return nil
    end
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function PlayerClassColor(name)
    local defaultR, defaultG, defaultB = 1.0, 0.82, 0.0
    if not name or name == "" or IsBotName(name) then
        return defaultR, defaultG, defaultB
    end

    local classToken
    if name == PlayerName() then
        classToken = select(2, UnitClass("player"))
    else
        local units = { "party1", "party2", "party3", "party4" }
        for _, unit in ipairs(units) do
            if UnitExists(unit) and FullUnitName(unit) == name then
                classToken = select(2, UnitClass(unit))
                break
            end
        end
        if not classToken then
            for i = 1, 40 do
                local unit = "raid" .. tostring(i)
                if UnitExists(unit) and FullUnitName(unit) == name then
                    classToken = select(2, UnitClass(unit))
                    break
                end
            end
        end
    end

    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = classToken and colors and colors[classToken]
    if color then
        return color.r, color.g, color.b
    end
    return defaultR, defaultG, defaultB
end

local function UpdateCardSelectionVisual(btn, selectedCards)
    if btn.card and selectedCards and selectedCards[btn.card] then
        btn.selection:Show()
    else
        btn.selection:Hide()
    end
end

local function BuildSelectedCards()
    local selected = {}
    if not mainFrame or not mainFrame.selectedCards then
        return selected
    end
    local hand = (DDZ.Game and DDZ.Game.GetMySortedHand and DDZ.Game.GetMySortedHand()) or {}
    for _, card in ipairs(hand) do
        if mainFrame.selectedCards[card] then
            selected[#selected + 1] = card
        end
    end
    return selected
end

local function CreateCardButton(parent, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(38, 54)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.97, 0.97, 0.94, 1)

    btn.border = btn:CreateTexture(nil, "BORDER")
    btn.border:SetPoint("TOPLEFT", 0, 0)
    btn.border:SetPoint("TOPRIGHT", 0, 0)
    btn.border:SetHeight(1)
    btn.border:SetColorTexture(0.2, 0.2, 0.2, 1)

    btn.borderBottom = btn:CreateTexture(nil, "BORDER")
    btn.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    btn.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    btn.borderBottom:SetHeight(1)
    btn.borderBottom:SetColorTexture(0.2, 0.2, 0.2, 1)

    btn.borderLeft = btn:CreateTexture(nil, "BORDER")
    btn.borderLeft:SetPoint("TOPLEFT", 0, 0)
    btn.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    btn.borderLeft:SetWidth(1)
    btn.borderLeft:SetColorTexture(0.2, 0.2, 0.2, 1)

    btn.borderRight = btn:CreateTexture(nil, "BORDER")
    btn.borderRight:SetPoint("TOPRIGHT", 0, 0)
    btn.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    btn.borderRight:SetWidth(1)
    btn.borderRight:SetColorTexture(0.2, 0.2, 0.2, 1)

    btn.selection = btn:CreateTexture(nil, "ARTWORK")
    btn.selection:SetAllPoints()
    btn.selection:SetColorTexture(1.0, 0.82, 0.2, 0.35)
    btn.selection:Hide()

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.label:SetPoint("CENTER", 0, 5)
    btn.label:SetText("?")

    btn.idx = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.idx:SetPoint("BOTTOM", 0, 5)
    btn.idx:SetText(tostring(index))

    btn:SetScript("OnClick", function(self)
        if not self.card then
            return
        end
        mainFrame.selectedCards = mainFrame.selectedCards or {}
        mainFrame.selectedCards[self.card] = not mainFrame.selectedCards[self.card]
        DDZ.UI.Refresh()
    end)

    return btn
end

local function EnsureCardButtons(parent, count)
    while #cardButtons < count do
        cardButtons[#cardButtons + 1] = CreateCardButton(parent, #cardButtons + 1)
    end
end

local function CreateRecentPlayCard(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(RECENT_CARD_WIDTH, RECENT_CARD_HEIGHT)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.97, 0.97, 0.94, 1)

    frame.border = frame:CreateTexture(nil, "BORDER")
    frame.border:SetPoint("TOPLEFT", 0, 0)
    frame.border:SetPoint("TOPRIGHT", 0, 0)
    frame.border:SetHeight(1)
    frame.border:SetColorTexture(0.2, 0.2, 0.2, 1)

    frame.borderBottom = frame:CreateTexture(nil, "BORDER")
    frame.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    frame.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.borderBottom:SetHeight(1)
    frame.borderBottom:SetColorTexture(0.2, 0.2, 0.2, 1)

    frame.borderLeft = frame:CreateTexture(nil, "BORDER")
    frame.borderLeft:SetPoint("TOPLEFT", 0, 0)
    frame.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    frame.borderLeft:SetWidth(1)
    frame.borderLeft:SetColorTexture(0.2, 0.2, 0.2, 1)

    frame.borderRight = frame:CreateTexture(nil, "BORDER")
    frame.borderRight:SetPoint("TOPRIGHT", 0, 0)
    frame.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.borderRight:SetWidth(1)
    frame.borderRight:SetColorTexture(0.2, 0.2, 0.2, 1)

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.label:SetPoint("CENTER", 0, 0)
    frame.label:SetText("?")

    return frame
end

local function EnsureRecentPlayCards(row, count)
    row.cards = row.cards or {}
    while #row.cards < count do
        row.cards[#row.cards + 1] = CreateRecentPlayCard(row.cardsArea)
    end
end

local function RecentPlayCardsPerRow()
    if not mainFrame then
        return 10
    end
    local frameWidth = mainFrame:GetWidth()
    local margin = 16
    local gutter = 18
    local leftColumnWidth = 320
    local rightWidth = frameWidth - (margin + leftColumnWidth + gutter) - margin
    local cardsAvailableWidth = math.max(120, rightWidth - RECENT_PLAY_LABEL_WIDTH - RECENT_PLAY_INNER_GAP)
    return math.max(1, math.floor((cardsAvailableWidth + RECENT_CARD_GAP_X) / (RECENT_CARD_WIDTH + RECENT_CARD_GAP_X)))
end

local function LayoutMainFrame(handCount)
    if not mainFrame then
        return
    end

    local frameWidth = mainFrame:GetWidth()
    local frameHeight = mainFrame:GetHeight()
    local margin = 16
    local titleBottom = 38
    local bottomButtonsHeight = 26
    local bottomButtonsY = 16
    local hostRowGap = 12
    local bidRowGap = 8
    local selectedGap = 10
    local cardsPerRow = 8
    local cardHeight = 54
    local cardGapY = 8
    local cardRowHeight = cardHeight + cardGapY
    local gutter = 18
    local leftColumnWidth = 320
    local rightStartX = margin + leftColumnWidth + gutter
    local rightWidth = frameWidth - rightStartX - margin
    local rows = math.max(1, math.ceil((handCount or 0) / cardsPerRow))
    local cardsHeight = rows * cardRowHeight - cardGapY
    local bottomReserved = bottomButtonsY + bottomButtonsHeight
    local lastPlayYOffset = titleBottom + 2 + 22
    local cardsAvailableWidth = math.max(120, rightWidth - RECENT_PLAY_LABEL_WIDTH - RECENT_PLAY_INNER_GAP)
    local recentCardsPerRow = RecentPlayCardsPerRow()
    local nextRowOffset = lastPlayYOffset

    for _, row in ipairs(mainFrame.lastPlayRows or {}) do
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", rightStartX, -nextRowOffset)
        row.frame:SetWidth(rightWidth)

        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", 0, 0)
        row.landlordIndicator:ClearAllPoints()
        row.landlordIndicator:SetPoint("LEFT", row.frame, "LEFT", 0, 0)
        row.landlordIndicator:SetWidth(RECENT_PLAY_LANDLORD_WIDTH)

        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row.landlordIndicator, "RIGHT", 2, 0)
        row.label:SetWidth(RECENT_PLAY_LABEL_WIDTH - RECENT_PLAY_LANDLORD_WIDTH - RECENT_PLAY_TURN_WIDTH - 6)

        row.turnIndicator:ClearAllPoints()
        row.turnIndicator:SetPoint("LEFT", row.label, "RIGHT", 4, 0)
        row.turnIndicator:SetWidth(RECENT_PLAY_TURN_WIDTH)

        row.cardsArea:ClearAllPoints()
        row.cardsArea:SetPoint("LEFT", row.frame, "LEFT", RECENT_PLAY_LABEL_WIDTH + RECENT_PLAY_INNER_GAP, 0)
        row.cardsArea:SetWidth(cardsAvailableWidth)
        row.cardsArea:SetHeight(RECENT_PLAY_ROW_HEIGHT)

        row.emptyText:ClearAllPoints()
        row.emptyText:SetPoint("LEFT", row.cardsArea, "LEFT", 0, 0)

        row.frame:SetHeight(RECENT_PLAY_ROW_HEIGHT)
        row.cardsPerRow = recentCardsPerRow
        nextRowOffset = nextRowOffset + RECENT_PLAY_ROW_HEIGHT + RECENT_PLAY_ROW_GAP
    end

    local cardsTopOffset = nextRowOffset + 10

    mainFrame.status:ClearAllPoints()
    mainFrame.status:SetPoint("TOPLEFT", margin, -titleBottom)
    mainFrame.status:SetWidth(leftColumnWidth)

    mainFrame.info:ClearAllPoints()
    mainFrame.info:SetPoint("TOPLEFT", mainFrame.status, "BOTTOMLEFT", 0, -10)
    mainFrame.info:SetWidth(leftColumnWidth)

    mainFrame.selectedText:ClearAllPoints()
    mainFrame.selectedText:SetPoint("BOTTOMLEFT", margin, bottomReserved + hostRowGap + 24 + bidRowGap + 24 + selectedGap)
    mainFrame.selectedText:SetWidth(frameWidth - (margin * 2))

    mainFrame.hostLabel:ClearAllPoints()
    mainFrame.hostLabel:SetPoint("BOTTOMLEFT", margin, bottomReserved + hostRowGap)

    mainFrame.bidLabel:ClearAllPoints()
    mainFrame.bidLabel:SetPoint("BOTTOMLEFT", margin, bottomReserved + hostRowGap + 24 + bidRowGap)

    mainFrame.lastPlayHeader:ClearAllPoints()
    mainFrame.lastPlayHeader:SetPoint("TOPLEFT", rightStartX, -(titleBottom + 2))

    mainFrame.cardsHeader:ClearAllPoints()
    mainFrame.cardsHeader:SetPoint("TOPLEFT", rightStartX, -cardsTopOffset)

    mainFrame.cardsArea:ClearAllPoints()
    mainFrame.cardsArea:SetPoint("TOPLEFT", rightStartX, -(cardsTopOffset + 20))
    mainFrame.cardsArea:SetSize(rightWidth, cardsHeight)

    local statusBottomY = titleBottom
        + mainFrame.status:GetStringHeight()
        + 10
        + mainFrame.info:GetStringHeight()
    local cardsBottomY = cardsTopOffset + 20 + cardsHeight
    local contentBottomY = math.max(statusBottomY, cardsBottomY)
    local minHeight = contentBottomY + 160 + bottomReserved

    if frameHeight < minHeight then
        mainFrame:SetHeight(minHeight)
    end
end

local function CreateMainFrame()
    if mainFrame then
        return
    end

    mainFrame = CreateFrame("Frame", "DDZMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(760, 470)
    mainFrame:SetPoint("CENTER")
    mainFrame:Hide()
    mainFrame.selectedCards = {}
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)
        DoudizhuDB = DoudizhuDB or {}
        DoudizhuDB.uiPosition = {
            point = point,
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs,
        }
    end)

    if DoudizhuDB and DoudizhuDB.uiPosition then
        local pos = DoudizhuDB.uiPosition
        if pos.point and pos.relativePoint and pos.x and pos.y then
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
        end
    end

    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.title:SetPoint("TOP", 0, -10)
    mainFrame.title:SetText(DDZ.L("UI_TITLE"))

    mainFrame.status = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.status:SetWidth(320)
    mainFrame.status:SetJustifyH("LEFT")
    mainFrame.status:SetJustifyV("TOP")
    mainFrame.status:SetText(DDZ.L("UI_STATUS_IDLE"))

    mainFrame.info = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.info:SetWidth(320)
    mainFrame.info:SetJustifyH("LEFT")
    mainFrame.info:SetJustifyV("TOP")
    mainFrame.info:SetText(DDZ.L("UI_INFO_NO_SESSION"))

    mainFrame.hostLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.hostLabel:SetText(DDZ.L("UI_HOST"))

    mainFrame.hostInput = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
    mainFrame.hostInput:SetSize(145, 24)
    mainFrame.hostInput:SetPoint("LEFT", mainFrame.hostLabel, "RIGHT", 4, 0)
    mainFrame.hostInput:SetAutoFocus(false)
    mainFrame.hostInput:SetText("")

    mainFrame.joinBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.joinBtn:SetPoint("LEFT", mainFrame.hostInput, "RIGHT", 8, 0)
    mainFrame.joinBtn:SetSize(70, 24)
    mainFrame.joinBtn:SetText(DDZ.L("UI_JOIN"))
    mainFrame.joinBtn:SetScript("OnClick", function()
        DDZ.Game.JoinSession(mainFrame.hostInput:GetText())
    end)

    mainFrame.shareBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.shareBtn:SetPoint("LEFT", mainFrame.joinBtn, "RIGHT", 8, 0)
    mainFrame.shareBtn:SetSize(110, 24)
    mainFrame.shareBtn:SetText(DDZ.L("UI_SHARE_PARTY_LINK"))
    mainFrame.shareBtn:SetScript("OnClick", function()
        DDZ.Game.ShareJoinLinkParty()
    end)

    mainFrame.bidLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.bidLabel:SetText(DDZ.L("UI_BID"))

    mainFrame.bidPassBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.bidPassBtn:SetSize(60, 24)
    mainFrame.bidPassBtn:SetPoint("LEFT", mainFrame.bidLabel, "RIGHT", 8, 0)
    mainFrame.bidPassBtn:SetText(DDZ.L("UI_PASS"))
    mainFrame.bidPassBtn:SetScript("OnClick", function()
        DDZ.Game.PassTurn()
    end)

    mainFrame.bidButtons = {}
    local previousBidButton = mainFrame.bidPassBtn
    for bid = 1, 3 do
        local btn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
        btn:SetSize(44, 24)
        btn:SetPoint("LEFT", previousBidButton, "RIGHT", 6, 0)
        btn:SetText(tostring(bid))
        btn:SetScript("OnClick", function()
            DDZ.Game.PlaceBid(bid)
        end)
        mainFrame.bidButtons[bid] = btn
        previousBidButton = btn
    end

    local createBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    createBtn:SetPoint("BOTTOMLEFT", 16, 16)
    createBtn:SetSize(80, 26)
    createBtn:SetText(DDZ.L("UI_CREATE"))
    createBtn:SetScript("OnClick", function()
        DDZ.Game.CreateSession()
        DDZ.UI.Refresh()
    end)

    local startBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    startBtn:SetPoint("LEFT", createBtn, "RIGHT", 10, 0)
    startBtn:SetSize(80, 26)
    startBtn:SetText(DDZ.L("UI_START"))
    startBtn:SetScript("OnClick", function()
        DDZ.Game.StartMVPRound()
        DDZ.UI.Refresh()
    end)

    local localBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    localBtn:SetPoint("LEFT", startBtn, "RIGHT", 10, 0)
    localBtn:SetSize(80, 26)
    localBtn:SetText(DDZ.L("UI_LOCAL_TEST"))
    localBtn:SetScript("OnClick", function()
        DDZ.Game.StartLocalTestMode()
        DDZ.UI.Refresh()
    end)

    mainFrame.playLowBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.playLowBtn:SetPoint("LEFT", localBtn, "RIGHT", 10, 0)
    mainFrame.playLowBtn:SetSize(80, 26)
    mainFrame.playLowBtn:SetText(DDZ.L("UI_PLAY_LOW"))
    mainFrame.playLowBtn:SetScript("OnClick", function()
        DDZ.Game.PlayLowestCard()
    end)

    mainFrame.playSelectedBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.playSelectedBtn:SetPoint("LEFT", mainFrame.playLowBtn, "RIGHT", 10, 0)
    mainFrame.playSelectedBtn:SetSize(95, 26)
    mainFrame.playSelectedBtn:SetText(DDZ.L("UI_PLAY_SELECTED"))
    mainFrame.playSelectedBtn:SetScript("OnClick", function()
        local cards = BuildSelectedCards()
        if #cards > 0 then
            DDZ.Game.PlayCards(cards)
        end
    end)

    mainFrame.passBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.passBtn:SetPoint("LEFT", mainFrame.playSelectedBtn, "RIGHT", 10, 0)
    mainFrame.passBtn:SetSize(80, 26)
    mainFrame.passBtn:SetText(DDZ.L("UI_PASS"))
    mainFrame.passBtn:SetScript("OnClick", function()
        DDZ.Game.PassTurn()
    end)

    local closeBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    closeBtn:SetPoint("BOTTOMRIGHT", -16, 16)
    closeBtn:SetSize(80, 26)
    closeBtn:SetText(DDZ.L("UI_CLOSE"))
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)

    mainFrame.selectedText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.selectedText:SetWidth(500)
    mainFrame.selectedText:SetJustifyH("LEFT")
    mainFrame.selectedText:SetJustifyV("TOP")
    mainFrame.selectedText:SetText(DDZ.L("UI_SELECTED_NONE"))

    mainFrame.lastPlayRows = {}
    mainFrame.lastPlayHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.lastPlayHeader:SetText(DDZ.L("UI_RECENT_PLAYS"))

    for i = 1, RECENT_PLAY_MAX do
        local row = {}
        row.frame = CreateFrame("Frame", nil, mainFrame)
        row.landlordIndicator = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.landlordIndicator:SetJustifyH("LEFT")
        row.landlordIndicator:SetJustifyV("TOP")
        row.landlordIndicator:SetText(RECENT_PLAY_LANDLORD_LABEL)
        row.landlordIndicator:SetTextColor(1.0, 0.2, 0.2)
        row.landlordIndicator:Hide()

        row.label = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.label:SetJustifyH("LEFT")
        row.label:SetJustifyV("TOP")
        row.label:SetText(DDZ.L("UI_SEAT", tostring(i)))
        row.turnIndicator = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.turnIndicator:SetJustifyH("LEFT")
        row.turnIndicator:SetJustifyV("TOP")
        row.turnIndicator:SetText(RECENT_PLAY_TURN_LABEL)
        row.turnIndicator:SetTextColor(0.35, 1.0, 0.35)
        row.turnIndicator:Hide()

        row.cardsArea = CreateFrame("Frame", nil, row.frame)
        row.cardsArea:SetClipsChildren(true)
        row.emptyText = row.cardsArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.emptyText:SetJustifyH("LEFT")
        row.emptyText:SetJustifyV("MIDDLE")
        row.emptyText:SetText(DDZ.L("UI_NO_PLAY_YET"))

        mainFrame.lastPlayRows[i] = row
    end

    mainFrame.cardsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.cardsHeader:SetText(DDZ.L("UI_MY_HAND"))

    mainFrame.cardsArea = CreateFrame("Frame", nil, mainFrame)
    mainFrame.cardsArea:SetSize(370, 320)

    LayoutMainFrame(0)
end

function DDZ.UI.Init()
    CreateMainFrame()
end

function DDZ.UI.Toggle()
    if not mainFrame then
        CreateMainFrame()
    end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
    DDZ.UI.Refresh()
end

function DDZ.UI.Refresh()
    if not mainFrame then
        return
    end

    if DDZ.Game and DDZ.Game.GetStatusText then
        mainFrame.status:SetText(DDZ.Game.GetStatusText())
    end
    if DDZ.Game and DDZ.Game.GetInfoText then
        mainFrame.info:SetText(DDZ.Game.GetInfoText())
    end

    local s = DDZ.Game and DDZ.Game.session
    if s and s.host then
        mainFrame.hostInput:SetText(TruncateName(s.host))
    end

    local myHand = {}
    if DDZ.Game and DDZ.Game.GetMySortedHand then
        myHand = DDZ.Game.GetMySortedHand() or {}
    end

    local players = {}
    for i = 1, RECENT_PLAY_MAX do
        players[i] = (s and s.players and s.players[i]) or nil
    end

    for i, row in ipairs(mainFrame.lastPlayRows or {}) do
        local player = players[i]
        local recent = player and DDZ.Game and DDZ.Game.GetRecentPlay and DDZ.Game.GetRecentPlay(player) or nil
        local cards = (recent and recent.cards) or {}
        local cardsPerRow = RecentPlayCardsPerRow()
        local labelText = player and (TruncateName(player) .. ":") or DDZ.L("UI_SEAT", tostring(i))
        local labelR, labelG, labelB = PlayerClassColor(player)

        row.label:SetText(labelText)
        row.label:SetTextColor(labelR, labelG, labelB)
        row.landlordIndicator:SetShown(player ~= nil and s and s.landlord == player)
        row.turnIndicator:SetShown(player ~= nil and s and s.currentTurn == player)
        row.cardsPerRow = cardsPerRow

        EnsureRecentPlayCards(row, #cards)
        for cardIndex, cardFrame in ipairs(row.cards or {}) do
            if cardIndex <= #cards then
                local card = cards[cardIndex]
                local cardCol = cardIndex - 1
                cardFrame:ClearAllPoints()
                cardFrame:SetPoint("LEFT", row.cardsArea, "LEFT",
                    cardCol * (RECENT_CARD_WIDTH + RECENT_CARD_GAP_X),
                    0)
                if DDZ.Game and DDZ.Game.GetCardText then
                    cardFrame.label:SetText(DDZ.Game.GetCardText(card))
                else
                    cardFrame.label:SetText(tostring(card))
                end
                if DDZ.Game and DDZ.Game.GetCardColor then
                    local r, g, b = DDZ.Game.GetCardColor(card)
                    cardFrame.label:SetTextColor(r, g, b)
                else
                    cardFrame.label:SetTextColor(0.15, 0.15, 0.15)
                end
                cardFrame:Show()
            else
                cardFrame:Hide()
            end
        end
        row.emptyText:SetShown(#cards == 0)
    end

    LayoutMainFrame(#myHand)

    mainFrame.selectedCards = mainFrame.selectedCards or {}
    local exists = {}
    for _, card in ipairs(myHand) do
        exists[card] = true
    end
    for card, _ in pairs(mainFrame.selectedCards) do
        if not exists[card] then
            mainFrame.selectedCards[card] = nil
        end
    end

    EnsureCardButtons(mainFrame.cardsArea, #myHand)
    for i, btn in ipairs(cardButtons) do
        if i <= #myHand then
            local card = myHand[i]
            local row = math.floor((i - 1) / 8)
            local col = (i - 1) % 8
            btn:SetPoint("TOPLEFT", mainFrame.cardsArea, "TOPLEFT", col * 45, -row * 62)
            btn.card = card
            btn.idx:SetText(tostring(i))
            if DDZ.Game and DDZ.Game.GetCardText then
                btn.label:SetText(DDZ.Game.GetCardText(card))
            else
                btn.label:SetText(tostring(card))
            end
            if DDZ.Game and DDZ.Game.GetCardColor then
                local r, g, b = DDZ.Game.GetCardColor(card)
                btn.label:SetTextColor(r, g, b)
            else
                btn.label:SetTextColor(0.15, 0.15, 0.15)
            end
            UpdateCardSelectionVisual(btn, mainFrame.selectedCards)
            btn:Show()
        else
            btn.card = nil
            btn:Hide()
        end
    end

    local selectedCards = BuildSelectedCards()
    local myName = PlayerName()
    local isBidPhase = s and s.phase == "bid"
    local isPlayPhase = s and s.phase == "play"
    local isMyTurn = s and s.currentTurn == myName
    local canPassPlay = isPlayPhase and isMyTurn and s.lastPlay and s.lastPlay.player ~= myName

    if #selectedCards > 0 and DDZ.Game and DDZ.Game.GetCardText then
        local labels = {}
        for _, card in ipairs(selectedCards) do
            labels[#labels + 1] = DDZ.Game.GetCardText(card)
        end
        local preview = nil
        if DDZ.Game and DDZ.Game.GetComboPreview then
            local ok, text = DDZ.Game.GetComboPreview(selectedCards)
            preview = ok and text or DDZ.L("UI_PREVIEW_INVALID", tostring(text))
        end
        local previewSuffix = preview and (" | " .. preview) or ""
        mainFrame.selectedText:SetText(DDZ.L("UI_SELECTED_WITH_CARDS",
            tostring(#selectedCards), table.concat(labels, ", "), previewSuffix))
    else
        mainFrame.selectedText:SetText(DDZ.L("UI_SELECTED_NONE"))
    end

    mainFrame.bidLabel:SetShown(isBidPhase)
    mainFrame.bidPassBtn:SetShown(isBidPhase)
    mainFrame.bidPassBtn:SetEnabled(isBidPhase and isMyTurn)
    for bid, btn in ipairs(mainFrame.bidButtons) do
        btn:SetShown(isBidPhase)
        btn:SetEnabled(isBidPhase and isMyTurn and bid > ((s and s.currentBid) or 0))
    end

    mainFrame.playLowBtn:SetShown(isPlayPhase)
    mainFrame.playLowBtn:SetEnabled(isPlayPhase and isMyTurn)
    mainFrame.playSelectedBtn:SetShown(isPlayPhase)
    mainFrame.playSelectedBtn:SetEnabled(isPlayPhase and isMyTurn and #selectedCards > 0)
    mainFrame.passBtn:SetShown(isPlayPhase)
    mainFrame.passBtn:SetEnabled(canPassPlay)
end
