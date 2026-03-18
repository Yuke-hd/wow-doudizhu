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
    local selectedGap = 10
    local cardsPerRow = 8
    local cardWidth = 38
    local cardHeight = 54
    local cardGapX = 7
    local cardGapY = 8
    local cardRowHeight = cardHeight + cardGapY
    local gutter = 18
    local leftColumnWidth = 320
    local rightStartX = margin + leftColumnWidth + gutter
    local rightWidth = frameWidth - rightStartX - margin

    local rows = math.max(1, math.ceil((handCount or 0) / cardsPerRow))
    local cardsHeight = rows * cardRowHeight - cardGapY
    local bottomReserved = bottomButtonsY + bottomButtonsHeight

    mainFrame.status:ClearAllPoints()
    mainFrame.status:SetPoint("TOPLEFT", margin, -titleBottom)
    mainFrame.status:SetWidth(leftColumnWidth)

    mainFrame.info:ClearAllPoints()
    mainFrame.info:SetPoint("TOPLEFT", mainFrame.status, "BOTTOMLEFT", 0, -10)
    mainFrame.info:SetWidth(leftColumnWidth)

    mainFrame.selectedText:ClearAllPoints()
    mainFrame.selectedText:SetPoint("BOTTOMLEFT", margin, bottomReserved + hostRowGap + 24 + selectedGap)
    mainFrame.selectedText:SetWidth(frameWidth - (margin * 2))

    mainFrame.hostLabel:ClearAllPoints()
    mainFrame.hostLabel:SetPoint("BOTTOMLEFT", margin, bottomReserved + hostRowGap)

    mainFrame.cardsHeader:ClearAllPoints()
    mainFrame.cardsHeader:SetPoint("TOPLEFT", rightStartX, -titleBottom)

    mainFrame.cardsArea:ClearAllPoints()
    mainFrame.cardsArea:SetPoint("TOPLEFT", rightStartX, -(titleBottom + 20))
    mainFrame.cardsArea:SetSize(rightWidth, cardsHeight)

    local statusBottomY = titleBottom
        + mainFrame.status:GetStringHeight()
        + 10
        + mainFrame.info:GetStringHeight()
    local cardsBottomY = titleBottom + 20 + cardsHeight
    local contentBottomY = math.max(statusBottomY, cardsBottomY)
    local minHeight = contentBottomY + 120 + bottomReserved

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
    mainFrame.title:SetText("Doudizhu (MVP)")

    mainFrame.status = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.status:SetWidth(320)
    mainFrame.status:SetJustifyH("LEFT")
    mainFrame.status:SetJustifyV("TOP")
    mainFrame.status:SetText("Status: Idle")

    mainFrame.info = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.info:SetWidth(320)
    mainFrame.info:SetJustifyH("LEFT")
    mainFrame.info:SetJustifyV("TOP")
    mainFrame.info:SetText("No session.")

    mainFrame.hostLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.hostLabel:SetText("Host:")

    mainFrame.hostInput = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
    mainFrame.hostInput:SetSize(145, 24)
    mainFrame.hostInput:SetPoint("LEFT", mainFrame.hostLabel, "RIGHT", 4, 0)
    mainFrame.hostInput:SetAutoFocus(false)
    mainFrame.hostInput:SetText("")

    mainFrame.joinBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.joinBtn:SetPoint("LEFT", mainFrame.hostInput, "RIGHT", 8, 0)
    mainFrame.joinBtn:SetSize(70, 24)
    mainFrame.joinBtn:SetText("Join")
    mainFrame.joinBtn:SetScript("OnClick", function()
        DDZ.Game.JoinSession(mainFrame.hostInput:GetText())
    end)

    mainFrame.shareBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    mainFrame.shareBtn:SetPoint("LEFT", mainFrame.joinBtn, "RIGHT", 8, 0)
    mainFrame.shareBtn:SetSize(110, 24)
    mainFrame.shareBtn:SetText("Share Party Link")
    mainFrame.shareBtn:SetScript("OnClick", function()
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
        local cards = BuildSelectedCards()
        if #cards > 0 then
            DDZ.Game.PlayCards(cards)
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
    mainFrame.selectedText:SetWidth(500)
    mainFrame.selectedText:SetJustifyH("LEFT")
    mainFrame.selectedText:SetJustifyV("TOP")
    mainFrame.selectedText:SetText("Selected: none")

    mainFrame.cardsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.cardsHeader:SetText("My Hand (click card to select)")

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
    if #selectedCards > 0 and DDZ.Game and DDZ.Game.GetCardText then
        local labels = {}
        for _, card in ipairs(selectedCards) do
            labels[#labels + 1] = DDZ.Game.GetCardText(card)
        end
        local preview = nil
        if DDZ.Game and DDZ.Game.GetComboPreview then
            local ok, text = DDZ.Game.GetComboPreview(selectedCards)
            preview = ok and text or ("Invalid: " .. tostring(text))
        end
        mainFrame.selectedText:SetText("Selected[" .. tostring(#selectedCards) .. "]: "
            .. table.concat(labels, ", ") .. (preview and (" | " .. preview) or ""))
    else
        mainFrame.selectedText:SetText("Selected: none")
    end
    mainFrame.playSelectedBtn:SetEnabled(#selectedCards > 0)
end
