local _, DDZ = ...

DDZ.UI = DDZ.UI or {}

local mainFrame
local cardButtons = {}

local function TruncateName(name)
    if not name then
        return "?"
    end
    return tostring(name):match("^[^-]+") or tostring(name)
end

local function UpdateCardSelectionVisual(btn, selectedCard)
    if btn.card and selectedCard and btn.card == selectedCard then
        btn.selection:Show()
    else
        btn.selection:Hide()
    end
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
        mainFrame.selectedCard = self.card
        DDZ.UI.Refresh()
    end)

    return btn
end

local function EnsureCardButtons(parent, count)
    while #cardButtons < count do
        cardButtons[#cardButtons + 1] = CreateCardButton(parent, #cardButtons + 1)
    end
end

local function CreateMainFrame()
    if mainFrame then
        return
    end

    mainFrame = CreateFrame("Frame", "DDZMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(760, 430)
    mainFrame:SetPoint("CENTER")
    mainFrame:Hide()
    mainFrame.selectedCard = nil
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
    mainFrame.title:SetText("Doudizhu (MVP)")

    mainFrame.status = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.status:SetPoint("TOPLEFT", 16, -38)
    mainFrame.status:SetText("Status: Idle")

    mainFrame.info = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.info:SetPoint("TOPLEFT", 16, -58)
    mainFrame.info:SetWidth(330)
    mainFrame.info:SetJustifyH("LEFT")
    mainFrame.info:SetJustifyV("TOP")
    mainFrame.info:SetText("No session.")

    mainFrame.hostLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.hostLabel:SetPoint("TOPLEFT", 16, -175)
    mainFrame.hostLabel:SetText("Host:")

    mainFrame.hostInput = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
    mainFrame.hostInput:SetSize(145, 24)
    mainFrame.hostInput:SetPoint("LEFT", mainFrame.hostLabel, "RIGHT", 4, 0)
    mainFrame.hostInput:SetAutoFocus(false)
    mainFrame.hostInput:SetText("")

    local joinBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    joinBtn:SetPoint("LEFT", mainFrame.hostInput, "RIGHT", 8, 0)
    joinBtn:SetSize(70, 24)
    joinBtn:SetText("Join")
    joinBtn:SetScript("OnClick", function()
        DDZ.Game.JoinSession(mainFrame.hostInput:GetText())
    end)

    local shareBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    shareBtn:SetPoint("LEFT", joinBtn, "RIGHT", 8, 0)
    shareBtn:SetSize(110, 24)
    shareBtn:SetText("Share Party Link")
    shareBtn:SetScript("OnClick", function()
        DDZ.Game.ShareJoinLinkParty()
    end)

    local createBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    createBtn:SetPoint("BOTTOMLEFT", 16, 16)
    createBtn:SetSize(80, 26)
    createBtn:SetText("Create")
    createBtn:SetScript("OnClick", function()
        DDZ.Game.CreateSession()
        DDZ.UI.Refresh()
    end)

    local startBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    startBtn:SetPoint("LEFT", createBtn, "RIGHT", 10, 0)
    startBtn:SetSize(80, 26)
    startBtn:SetText("Start MVP")
    startBtn:SetScript("OnClick", function()
        DDZ.Game.StartMVPRound()
        DDZ.UI.Refresh()
    end)

    local localBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    localBtn:SetPoint("LEFT", startBtn, "RIGHT", 10, 0)
    localBtn:SetSize(80, 26)
    localBtn:SetText("Local Test")
    localBtn:SetScript("OnClick", function()
        DDZ.Game.StartLocalTestMode()
        DDZ.UI.Refresh()
    end)

    local playLowBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    playLowBtn:SetPoint("LEFT", localBtn, "RIGHT", 10, 0)
    playLowBtn:SetSize(80, 26)
    playLowBtn:SetText("Play Low")
    playLowBtn:SetScript("OnClick", function()
        DDZ.Game.PlayLowestCard()
    end)

    mainFrame.playSelectedBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.playSelectedBtn:SetPoint("LEFT", playLowBtn, "RIGHT", 10, 0)
    mainFrame.playSelectedBtn:SetSize(95, 26)
    mainFrame.playSelectedBtn:SetText("Play Selected")
    mainFrame.playSelectedBtn:SetScript("OnClick", function()
        if mainFrame.selectedCard then
            DDZ.Game.PlayCard(mainFrame.selectedCard)
        end
    end)

    local passBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    passBtn:SetPoint("LEFT", mainFrame.playSelectedBtn, "RIGHT", 10, 0)
    passBtn:SetSize(80, 26)
    passBtn:SetText("Pass")
    passBtn:SetScript("OnClick", function()
        DDZ.Game.PassTurn()
    end)

    local closeBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    closeBtn:SetPoint("BOTTOMRIGHT", -16, 16)
    closeBtn:SetSize(80, 26)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)

    mainFrame.selectedText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.selectedText:SetPoint("BOTTOMLEFT", 16, 48)
    mainFrame.selectedText:SetText("Selected: none")

    mainFrame.cardsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.cardsHeader:SetPoint("TOPLEFT", 370, -38)
    mainFrame.cardsHeader:SetText("My Hand (click card to select)")

    mainFrame.cardsArea = CreateFrame("Frame", nil, mainFrame)
    mainFrame.cardsArea:SetSize(370, 350)
    mainFrame.cardsArea:SetPoint("TOPLEFT", 370, -58)
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

    local hasSelected = false
    for _, card in ipairs(myHand) do
        if card == mainFrame.selectedCard then
            hasSelected = true
            break
        end
    end
    if not hasSelected then
        mainFrame.selectedCard = nil
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
            UpdateCardSelectionVisual(btn, mainFrame.selectedCard)
            btn:Show()
        else
            btn.card = nil
            btn:Hide()
        end
    end

    if mainFrame.selectedCard and DDZ.Game and DDZ.Game.GetCardText then
        mainFrame.selectedText:SetText("Selected: " .. DDZ.Game.GetCardText(mainFrame.selectedCard))
    else
        mainFrame.selectedText:SetText("Selected: none")
    end
    mainFrame.playSelectedBtn:SetEnabled(mainFrame.selectedCard ~= nil)
end
