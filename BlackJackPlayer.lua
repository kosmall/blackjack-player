-- BlackJack Player Addon
-- For players joining BlackJack casino games

BlackJackPlayer = {}
BlackJackPlayer.version = "1.5.1"

-- Default saved variables
local defaults = {
    minimapPos = 180,
    enableAnimations = false,
    enableConfetti = false,
}

-- Card names mapping
local cardNames = {
    ["Ace"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5,
    ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["10"] = 10,
    ["Jack"] = 11, ["Queen"] = 12, ["King"] = 13,
}

local cardSymbols = {
    [1] = "A", [2] = "2", [3] = "3", [4] = "4", [5] = "5",
    [6] = "6", [7] = "7", [8] = "8", [9] = "9", [10] = "10",
    [11] = "J", [12] = "Q", [13] = "K",
}

-- Sound effects
local SOUNDS = {
    NEW_CARD = 1184,
    YOUR_TURN = 3175,
    LOSE = 847,
    PUSH = 867,
}

-- Voice announcements
local VOICE_SOUNDS = {
    WIN = "Interface\\AddOns\\BlackJackPlayer\\Sounds\\player_wins.mp3",
    BLACKJACK = "Interface\\AddOns\\BlackJackPlayer\\Sounds\\blackjack.mp3",
}

-- Game state
local gameState = {
    active = false,
    myTurn = false,
    betAmount = 0,
    myCards = {},
    dealerCards = {},  -- Only first card visible initially
    myValue = 0,
    dealerValue = 0,
    result = nil,      -- "win", "lose", "push", "blackjack"
    winAmount = 0,
    dealerName = nil,  -- Name of the dealer
    phase = "waiting", -- waiting, dealing, playerTurn, dealerTurn, finished
    currentPlayer = nil,  -- Name of the player currently being served by dealer
    isMyGame = false,  -- Whether the current game is mine
    lastPlayerCardCount = 0,  -- Track number of cards shown for animations
    lastDealerCardCount = 0,  -- Track number of cards shown for animations
}

-- Calculate hand value
local function CalculateHandValue(cards)
    local value = 0
    local aces = 0

    for _, card in ipairs(cards) do
        if card == 1 then
            aces = aces + 1
            value = value + 11
        elseif card >= 11 then
            value = value + 10
        else
            value = value + card
        end
    end

    while value > 21 and aces > 0 do
        value = value - 10
        aces = aces - 1
    end

    return value
end

-- Reset game state
local function ResetGame()
    gameState = {
        active = false,
        myTurn = false,
        betAmount = 0,
        myCards = {},
        dealerCards = {},
        myValue = 0,
        dealerValue = 0,
        result = nil,
        winAmount = 0,
        dealerName = nil,
        phase = "waiting",
        currentPlayer = nil,
        isMyGame = false,
        lastPlayerCardCount = 0,
        lastDealerCardCount = 0,
    }
    BlackJackPlayer:UpdateDisplay()
end

-- Create main frame
local mainFrame = CreateFrame("Frame", "BlackJackPlayerFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(320, 480)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetFrameStrata("DIALOG")
mainFrame:Hide()

-- Title
local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", mainFrame, "TOP", 0, -15)
title:SetText("|cFFFFD700BlackJack|r")

-- Close button
local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function()
    mainFrame:Hide()
end)

-- Status text
local statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("TOP", title, "BOTTOM", 0, -10)
statusText:SetText("|cFF888888Waiting for game...|r")

-- Current player info text (shown when someone else is playing)
local currentPlayerText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
currentPlayerText:SetPoint("TOP", statusText, "BOTTOM", 0, -5)
currentPlayerText:SetText("")

-- Bet display
local betText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
betText:SetPoint("TOP", currentPlayerText, "BOTTOM", 0, -5)
betText:SetText("")

-- Dealer section
local dealerLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
dealerLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -80)
dealerLabel:SetText("|cFFFF6600Dealer:|r")

local dealerCardsFrame = CreateFrame("Frame", nil, mainFrame)
dealerCardsFrame:SetSize(240, 60)
dealerCardsFrame:SetPoint("TOPLEFT", dealerLabel, "BOTTOMLEFT", 0, -5)

local dealerValueText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dealerValueText:SetPoint("TOPLEFT", dealerCardsFrame, "BOTTOMLEFT", 0, -5)
dealerValueText:SetText("")

-- Player section
local playerLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
playerLabel:SetPoint("TOPLEFT", dealerValueText, "BOTTOMLEFT", 0, -15)
playerLabel:SetText("|cFF00FF00Your Cards:|r")

local playerCardsFrame = CreateFrame("Frame", nil, mainFrame)
playerCardsFrame:SetSize(280, 60)
playerCardsFrame:SetPoint("TOPLEFT", playerLabel, "BOTTOMLEFT", 0, -5)

local playerValueText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
playerValueText:SetPoint("TOPLEFT", playerCardsFrame, "BOTTOMLEFT", 0, -8)
playerValueText:SetText("")

-- Result text (positioned higher, between value and buttons)
local resultText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
resultText:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 80)
resultText:SetText("")

-- Card frames
local dealerCardFrames = {}
local playerCardFrames = {}

local function CreateCardFrame(parent, index)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(45, 63)  -- Slightly larger for textures
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    card:SetBackdropColor(1, 1, 1, 1)
    card:SetBackdropBorderColor(0, 0, 0, 1)

    -- Card texture (for PNG images)
    local texture = card:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", card, "TOPLEFT", 3, -3)
    texture:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -3, 3)
    texture:Hide()
    card.texture = texture

    -- Fallback text
    local text = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", card, "CENTER", 0, 0)
    text:SetTextColor(0, 0, 0, 1)
    card.text = text

    -- Animation group for flip effect
    card.animGroup = card:CreateAnimationGroup()

    -- Scale down (first half of flip)
    local scale1 = card.animGroup:CreateAnimation("Scale")
    scale1:SetDuration(0.15)
    scale1:SetScale(0.1, 1.0)
    scale1:SetOrigin("CENTER", 0, 0)
    scale1:SetOrder(1)

    -- Scale up (second half of flip)
    local scale2 = card.animGroup:CreateAnimation("Scale")
    scale2:SetDuration(0.15)
    scale2:SetScale(10, 1.0)
    scale2:SetOrigin("CENTER", 0, 0)
    scale2:SetOrder(2)

    card:Hide()
    return card
end

-- Create card frames
for i = 1, 10 do
    dealerCardFrames[i] = CreateCardFrame(dealerCardsFrame, i)
    dealerCardFrames[i]:SetPoint("TOPLEFT", dealerCardsFrame, "TOPLEFT", (i-1) * 48, 0)

    playerCardFrames[i] = CreateCardFrame(playerCardsFrame, i)
    playerCardFrames[i]:SetPoint("TOPLEFT", playerCardsFrame, "TOPLEFT", (i-1) * 48, 0)
end

-- Hidden card (back of card for dealer)
local function ShowHiddenCard(frame)
    frame:SetBackdropColor(0.2, 0.2, 0.6, 1)
    if frame.texture then
        frame.texture:Hide()
    end
    frame.text:SetText("?")
    frame.text:SetTextColor(1, 1, 1, 1)
    frame:Show()
end

-- Show card with flip animation
local function ShowCardWithFlip(frame, cardValue)
    if not BlackJackPlayerDB.enableAnimations then
        -- No animation, just show
        frame:SetBackdropColor(1, 1, 1, 1)
        frame.text:SetText(cardSymbols[cardValue])
        frame.text:SetTextColor(0, 0, 0, 1)
        frame:Show()
        return
    end

    -- Start with card hidden (back side)
    frame:SetBackdropColor(0.2, 0.2, 0.6, 1)
    frame.text:SetText("?")
    frame.text:SetTextColor(1, 1, 1, 1)
    frame:Show()

    -- After half the animation, change to front
    C_Timer.After(0.15, function()
        frame:SetBackdropColor(1, 1, 1, 1)
        frame.text:SetText(cardSymbols[cardValue])
        frame.text:SetTextColor(0, 0, 0, 1)
    end)

    -- Play flip animation
    frame.animGroup:Play()
end

-- Confetti particle system for blackjack wins
local confettiParticles = {}

local function CreateConfettiParticle(parent, x, y)
    local particle = parent:CreateTexture(nil, "OVERLAY")
    particle:SetSize(8, 8)
    particle:SetTexture("Interface\\Buttons\\WHITE8x8")

    -- Random gold/yellow color
    local colorVariant = math.random()
    if colorVariant < 0.33 then
        particle:SetVertexColor(1, 0.84, 0) -- Gold
    elseif colorVariant < 0.66 then
        particle:SetVertexColor(1, 1, 0) -- Yellow
    else
        particle:SetVertexColor(1, 0.65, 0) -- Orange
    end

    particle:SetPoint("CENTER", parent, "BOTTOMLEFT", x, y)

    return particle
end

local function ShowConfetti()
    if not BlackJackPlayerDB.enableConfetti then
        return
    end

    -- Clear old particles
    for _, p in ipairs(confettiParticles) do
        p:Hide()
    end
    confettiParticles = {}

    -- Create particles
    local numParticles = 30
    for i = 1, numParticles do
        local startX = math.random(50, 270)
        local startY = 480 + math.random(0, 50)
        local particle = CreateConfettiParticle(mainFrame, startX, startY)
        table.insert(confettiParticles, particle)

        -- Animate particle falling
        local duration = 2.0 + math.random() * 1.0
        local endY = -50
        local deltaX = math.random(-80, 80)

        particle:Show()
        particle:SetAlpha(1)

        -- Animation using timer
        local startTime = GetTime()
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(self)
            local elapsed = GetTime() - startTime
            local progress = elapsed / duration

            if progress >= 1 then
                particle:Hide()
                self:SetScript("OnUpdate", nil)
                return
            end

            -- Ease out quad
            local easeProgress = 1 - (1 - progress) * (1 - progress)
            local currentY = startY + (endY - startY) * easeProgress
            local currentX = startX + deltaX * math.sin(progress * math.pi * 3)

            particle:SetPoint("CENTER", mainFrame, "BOTTOMLEFT", currentX, currentY)
            particle:SetAlpha(1 - progress)
        end)
    end
end

-- Hit button
local hitBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
hitBtn:SetSize(80, 35)
hitBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 15, 25)
hitBtn:SetText("HIT")
hitBtn:SetScript("OnClick", function()
    if gameState.active and gameState.myTurn and gameState.isMyGame then
        SendChatMessage("hit", "PARTY")
    end
end)

-- Trade button (uses SecureActionButton to target dealer)
local tradeBtn = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate, UIPanelButtonTemplate")
tradeBtn:SetSize(80, 35)
tradeBtn:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 25)
tradeBtn:SetText("TRADE")

-- Update secure button attributes when dealer changes
local function UpdateTradeButtonTarget()
    if gameState.dealerName and not InCombatLockdown() then
        tradeBtn:SetAttribute("type", "macro")
        tradeBtn:SetAttribute("macrotext", "/target " .. gameState.dealerName .. "\n/run InitiateTrade('target')")
    end
end

-- Hook to initiate trade after targeting
tradeBtn:HookScript("OnClick", function()
    if gameState.dealerName and UnitName("target") == gameState.dealerName then
        InitiateTrade("target")
    end
end)

-- Function to update trade button state
local function UpdateTradeButton()
    if gameState.dealerName then
        tradeBtn:Enable()
        UpdateTradeButtonTarget()
    else
        tradeBtn:Disable()
    end
end

-- Initialize trade button as disabled
tradeBtn:Disable()

-- Pass button
local passBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
passBtn:SetSize(80, 35)
passBtn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -15, 25)
passBtn:SetText("PASS")
passBtn:SetScript("OnClick", function()
    if gameState.active and gameState.myTurn and gameState.isMyGame then
        SendChatMessage("pass", "PARTY")
    end
end)

-- Update card display
local function UpdateCards(cards, cardFrames, showHidden, isPlayer)
    local lastCount = isPlayer and gameState.lastPlayerCardCount or gameState.lastDealerCardCount

    for i, frame in ipairs(cardFrames) do
        if i == 2 and showHidden and #cards >= 1 then
            -- Show hidden card for dealer's second card
            ShowHiddenCard(frame)
        elseif cards[i] then
            local cardValue = cards[i]
            -- Use flip animation for new cards only
            if i > lastCount and BlackJackPlayerDB.enableAnimations then
                ShowCardWithFlip(frame, cardValue)
            else
                -- Card already shown, just update without animation
                frame:SetBackdropColor(1, 1, 1, 1)
                frame.text:SetText(cardSymbols[cardValue])
                frame.text:SetTextColor(0, 0, 0, 1)
                frame:Show()
            end
        else
            frame:Hide()
        end
    end

    -- Update last count
    if isPlayer then
        gameState.lastPlayerCardCount = #cards
    else
        gameState.lastDealerCardCount = #cards
    end
end

-- Update display
function BlackJackPlayer:UpdateDisplay()
    if not gameState.active then
        statusText:SetText("|cFF888888Waiting for game...|r")
        currentPlayerText:SetText("")
        betText:SetText("")
        dealerValueText:SetText("")
        playerValueText:SetText("")
        resultText:SetText("")

        -- Hide all cards
        for _, frame in ipairs(dealerCardFrames) do frame:Hide() end
        for _, frame in ipairs(playerCardFrames) do frame:Hide() end

        -- Disable buttons
        hitBtn:Disable()
        passBtn:Disable()
        return
    end

    -- Show current player info if game is active but not mine
    if gameState.currentPlayer and not gameState.isMyGame then
        currentPlayerText:SetText("|cFFFFAA00Dealer playing with: " .. gameState.currentPlayer .. "|r")
    else
        currentPlayerText:SetText("")
    end

    -- Show bet
    if gameState.betAmount > 0 then
        betText:SetText("|cFFFFD700Bet: " .. gameState.betAmount .. "g|r")
    end

    -- Update status
    if gameState.result then
        if gameState.result == "win" then
            statusText:SetText("|cFF00FF00YOU WIN!|r")
            resultText:SetText("|cFF00FF00+" .. gameState.winAmount .. "g|r")
        elseif gameState.result == "blackjack" then
            statusText:SetText("|cFFFFD700BLACKJACK!|r")
            resultText:SetText("|cFF00FF00+" .. gameState.winAmount .. "g|r")
        elseif gameState.result == "push" then
            statusText:SetText("|cFFFFFF00PUSH - Bet returned|r")
            resultText:SetText("|cFFFFFF00" .. gameState.betAmount .. "g|r")
        elseif gameState.result == "lose" then
            statusText:SetText("|cFFFF0000YOU LOSE|r")
            resultText:SetText("|cFFFF0000-" .. gameState.betAmount .. "g|r")
        elseif gameState.result == "bust" then
            statusText:SetText("|cFFFF0000BUST!|r")
            resultText:SetText("|cFFFF0000-" .. gameState.betAmount .. "g|r")
        end
        hitBtn:Disable()
        passBtn:Disable()
    elseif gameState.myTurn and gameState.isMyGame then
        -- Only enable buttons if it's my turn AND my game
        statusText:SetText("|cFF00FF00Your turn - Hit or Pass|r")
        resultText:SetText("")
        hitBtn:Enable()
        passBtn:Enable()
    else
        -- Waiting or not my game
        if not gameState.isMyGame then
            statusText:SetText("|cFFFFFF00Watching...|r")
        else
            statusText:SetText("|cFFFFFF00Waiting...|r")
        end
        resultText:SetText("")
        hitBtn:Disable()
        passBtn:Disable()
    end

    -- Update cards - dealer's second card hidden during player turn
    local hideSecondCard = gameState.myTurn or (not gameState.result and #gameState.dealerCards == 1)
    UpdateCards(gameState.dealerCards, dealerCardFrames, hideSecondCard, false)
    UpdateCards(gameState.myCards, playerCardFrames, false, true)

    -- Update values
    if #gameState.dealerCards > 0 then
        if hideSecondCard and #gameState.dealerCards >= 1 then
            -- Only show first card value
            local firstCardValue = gameState.dealerCards[1]
            if firstCardValue == 1 then
                dealerValueText:SetText("Value: 11 + ?")
            elseif firstCardValue >= 11 then
                dealerValueText:SetText("Value: 10 + ?")
            else
                dealerValueText:SetText("Value: " .. firstCardValue .. " + ?")
            end
        else
            dealerValueText:SetText("Value: " .. gameState.dealerValue)
        end
    else
        dealerValueText:SetText("")
    end

    if #gameState.myCards > 0 then
        playerValueText:SetText("Value: " .. gameState.myValue)
    else
        playerValueText:SetText("")
    end

    -- Update trade button state
    UpdateTradeButton()
end

-- Parse card name to value
local function ParseCard(cardName)
    return cardNames[cardName]
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_PARTY")
eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("TRADE_MONEY_CHANGED")
eventFrame:RegisterEvent("TRADE_CLOSED")

local playerName = nil
local tradeMoney = 0
local goldBeforeTrade = nil

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "BlackJackPlayer" then
            playerName = UnitName("player")

            if not BlackJackPlayerDB then
                BlackJackPlayerDB = {}
            end
            for k, v in pairs(defaults) do
                if BlackJackPlayerDB[k] == nil then
                    BlackJackPlayerDB[k] = v
                end
            end

            print("|cFFFFD700[BlackJack Player]|r v" .. BlackJackPlayer.version .. " loaded! /bjp to toggle.")
        end

    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
        local msg, sender = ...
        sender = string.match(sender, "([^-]+)") or sender

        -- Parse [BJ] messages from dealer
        if string.find(msg, "^%[BJ%]") then
            -- Game started - check if it's for me or someone else
            local startPlayer, bet = string.match(msg, "%[BJ%] Game started! (.+) bet (%d+)g")
            if startPlayer then
                -- A game has started
                local isMyGame = (startPlayer == playerName)

                if isMyGame then
                    -- Game is for me - reset and setup
                    ResetGame()
                    gameState.active = true
                    gameState.betAmount = tonumber(bet)
                    gameState.dealerName = sender
                    gameState.phase = "dealing"
                    gameState.currentPlayer = startPlayer
                    gameState.isMyGame = true
                    if not mainFrame:IsShown() then
                        mainFrame:Show()
                    end
                else
                    -- Game is for someone else - just track who is playing
                    if not gameState.active or gameState.phase == "finished" then
                        ResetGame()
                    end
                    gameState.active = true
                    gameState.currentPlayer = startPlayer
                    gameState.isMyGame = false
                    gameState.dealerName = sender
                end
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- Parse card draws from party messages (works with all deal modes)
            -- Player draws a card: "[BJ] PlayerName draws: CardName"
            local drawPlayer, cardName = string.match(msg, "%[BJ%] (.+) draws: (%w+)")
            if drawPlayer and cardName then
                local cardValue = ParseCard(cardName)
                if cardValue and gameState.active and gameState.isMyGame then
                    -- Only process cards if this is my game
                    if drawPlayer == playerName then
                        -- My card
                        table.insert(gameState.myCards, cardValue)
                        gameState.myValue = CalculateHandValue(gameState.myCards)
                        PlaySound(SOUNDS.NEW_CARD)
                        BlackJackPlayer:UpdateDisplay()
                    elseif drawPlayer == "Dealer" then
                        -- Dealer's card
                        table.insert(gameState.dealerCards, cardValue)
                        gameState.dealerValue = CalculateHandValue(gameState.dealerCards)
                        PlaySound(SOUNDS.NEW_CARD)
                        BlackJackPlayer:UpdateDisplay()
                    end
                end
                return
            end

            -- My turn to act
            local turnPlayer = string.match(msg, "%[BJ%] (.+), type 'hit' or 'pass'")
            if turnPlayer and turnPlayer == playerName and gameState.isMyGame then
                gameState.phase = "playerTurn"
                gameState.myTurn = true
                PlaySound(SOUNDS.YOUR_TURN)
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- I said hit
            local hitPlayer = string.match(msg, "%[BJ%] (.+) says HIT!")
            if hitPlayer and hitPlayer == playerName and gameState.isMyGame then
                -- Stay in playerTurn, wait for next roll
                gameState.myTurn = false
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- I stand
            local standPlayer = string.match(msg, "%[BJ%] (.+) STANDS with")
            if standPlayer and standPlayer == playerName and gameState.isMyGame then
                gameState.phase = "dealerTurn"
                gameState.myTurn = false
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- Dealer's turn message
            if string.find(msg, "Dealer's turn") and gameState.isMyGame then
                gameState.phase = "dealerTurn"
                gameState.myTurn = false
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- I have blackjack
            local bjPlayer = string.match(msg, "%[BJ%] (.+) has BLACKJACK!")
            if bjPlayer and bjPlayer == playerName and gameState.isMyGame then
                gameState.phase = "dealerTurn"
                gameState.myTurn = false
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- I bust
            local bustPlayer = string.match(msg, "%[BJ%] (.+) BUSTS with")
            if bustPlayer and bustPlayer == playerName and gameState.isMyGame then
                gameState.result = "bust"
                gameState.phase = "finished"
                gameState.myTurn = false
                PlaySound(SOUNDS.LOSE)
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- Player wins with blackjack
            if string.find(msg, playerName .. " wins with BLACKJACK") and gameState.isMyGame then
                gameState.result = "blackjack"
                gameState.winAmount = gameState.betAmount + math.floor(gameState.betAmount * 1.5)
                gameState.phase = "finished"
                PlaySoundFile(VOICE_SOUNDS.BLACKJACK, "Master")
                DoEmote("train")
                ShowConfetti()
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- Player wins
            if string.find(msg, playerName .. " wins") and not string.find(msg, "BLACKJACK") and gameState.isMyGame then
                gameState.result = "win"
                gameState.winAmount = gameState.betAmount * 2
                gameState.phase = "finished"
                PlaySoundFile(VOICE_SOUNDS.WIN, "Master")
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- Dealer busts, I win
            if string.find(msg, "Dealer BUSTS") and gameState.active and gameState.isMyGame then
                if not gameState.result then
                    if gameState.myValue == 21 and #gameState.myCards == 2 then
                        gameState.result = "blackjack"
                        gameState.winAmount = gameState.betAmount + math.floor(gameState.betAmount * 1.5)
                        PlaySoundFile(VOICE_SOUNDS.BLACKJACK, "Master")
                        DoEmote("train")
                        ShowConfetti()
                    else
                        gameState.result = "win"
                        gameState.winAmount = gameState.betAmount * 2
                        PlaySoundFile(VOICE_SOUNDS.WIN, "Master")
                    end
                    gameState.phase = "finished"
                    BlackJackPlayer:UpdateDisplay()
                end
                return
            end

            -- Push
            if string.find(msg, "Push") and string.find(msg, playerName) and gameState.isMyGame then
                gameState.result = "push"
                gameState.phase = "finished"
                PlaySound(SOUNDS.PUSH)
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- Dealer wins
            if (string.find(msg, "Dealer wins") or string.find(msg, "Dealer has BLACKJACK")) and gameState.isMyGame then
                if gameState.active and not gameState.result then
                    gameState.result = "lose"
                    gameState.phase = "finished"
                    PlaySound(SOUNDS.LOSE)
                    BlackJackPlayer:UpdateDisplay()
                end
                return
            end

            -- Pay message (game end confirmation)
            local payPlayer, payAmount = string.match(msg, "%[BJ%] Pay (.+): (%d+)g")
            if payPlayer and payPlayer == playerName and gameState.isMyGame then
                gameState.winAmount = tonumber(payAmount)
                if not gameState.result then
                    if gameState.winAmount > gameState.betAmount then
                        gameState.result = "win"
                        PlaySoundFile(VOICE_SOUNDS.WIN, "Master")
                    else
                        gameState.result = "push"
                        PlaySound(SOUNDS.PUSH)
                    end
                end
                gameState.phase = "finished"
                BlackJackPlayer:UpdateDisplay()
                return
            end

            -- I lose message
            if string.find(msg, playerName .. " loses") and gameState.isMyGame then
                gameState.result = "lose"
                gameState.phase = "finished"
                PlaySound(SOUNDS.LOSE)
                BlackJackPlayer:UpdateDisplay()
                return
            end
        end

    elseif event == "TRADE_SHOW" then
        goldBeforeTrade = GetMoney()
        tradeMoney = 0

    elseif event == "TRADE_MONEY_CHANGED" then
        -- Track money I'm giving
        tradeMoney = GetPlayerTradeMoney() or 0

    elseif event == "TRADE_CLOSED" then
        if goldBeforeTrade and mainFrame:IsShown() then
            -- Capture value before it's cleared
            local savedGoldBefore = goldBeforeTrade
            C_Timer.After(0.5, function()
                local goldAfterTrade = GetMoney()
                local goldDiff = goldAfterTrade - savedGoldBefore

                -- If I sent gold (negative diff), prepare for game
                if goldDiff < -5000 then
                    local betGold = math.floor((-goldDiff + 5000) / 10000)
                    if betGold > 0 and not gameState.active then
                        print("|cFFFFD700[BJPlayer]|r Bet placed: " .. betGold .. "g - waiting for dealer...")
                    end
                end
            end)
        end
        goldBeforeTrade = nil
        tradeMoney = 0
    end
end)

-- Toggle visibility
function BlackJackPlayer:Toggle()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        self:UpdateDisplay()
    end
end

function BlackJackPlayer:Show()
    mainFrame:Show()
    self:UpdateDisplay()
end

function BlackJackPlayer:Hide()
    mainFrame:Hide()
end

function BlackJackPlayer:IsVisible()
    return mainFrame:IsShown()
end

-- Minimap Button
local minimapButton = CreateFrame("Button", "BlackJackPlayerMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 6, -6)
icon:SetTexture("Interface\\Icons\\INV_Misc_Dice_02")

local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapButtonPosition()
    local angle = math.rad(BlackJackPlayerDB and BlackJackPlayerDB.minimapPos or 45)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local isDragging = false
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    isDragging = true
end)

minimapButton:SetScript("OnDragStop", function(self)
    isDragging = false
end)

minimapButton:SetScript("OnUpdate", function(self)
    if isDragging then
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.atan2(cy - my, cx - mx)
        BlackJackPlayerDB.minimapPos = math.deg(angle)
        UpdateMinimapButtonPosition()
    end
end)

minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        BlackJackPlayer:Toggle()
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFFFFD700BlackJack Player|r")
    GameTooltip:AddLine("Left-click to open", 1, 1, 1)
    GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "BlackJackPlayer" then
        C_Timer.After(0.1, function()
            UpdateMinimapButtonPosition()
        end)
    end
end)

-- Slash command
SLASH_BLACKJACKPLAYER1 = "/blackjackplayer"
SLASH_BLACKJACKPLAYER2 = "/bjp"
SlashCmdList["BLACKJACKPLAYER"] = function(msg)
    BlackJackPlayer:Toggle()
end

print("|cFFFFD700[BlackJack Player]|r Loaded.")
