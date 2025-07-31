-- Modules/UI/RecruitmentFrame.lua
local addonName, ns = ...

ns.RecruitmentFrame = {}
local RecruitmentFrame = ns.RecruitmentFrame

-- Local variables for state management
local isScanning = false
local foundPlayers = {}
local selectedPlayers = {}
local currentFilter = "ALL"
local lastScanTime = 0
local scanCooldown = 15 -- Fixed at 15 seconds
local playerCheckboxes = {}

-- Reliable, one-time event frame for WHO_LIST_UPDATE (do not register per-scan)
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("WHO_LIST_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "WHO_LIST_UPDATE" and RecruitmentFrame._whoResultsExpected then
        RecruitmentFrame:_OnWhoListUpdate()
    end
end)
RecruitmentFrame._whoResultsExpected = false

-- WHO query with event-driven results, single event model
function RecruitmentFrame:SendActualWhoQuery(query, className)
    self._whoResultsExpected = true
    self.currentQueryClass = className
    self.whoQueryStartTime = GetTime()
    self.lastWhoQuery = query
    self.awaitingResults = true

    local timeSinceLastQuery = GetTime() - (self.lastWhoTime or 0)
    if timeSinceLastQuery < 5 then
        local waitTime = 5 - timeSinceLastQuery
        print("|cFF3EB9D8[FGR-DEBUG]|r WHO query on cooldown, waiting " .. string.format("%.1f", waitTime) .. " seconds")
        C_Timer.After(waitTime, function()
            self:SendActualWhoQuery(query, className)
        end)
        return
    end

    print("|cFF3EB9D8[FGR-DEBUG]|r Sending WHO query: " .. query)
    C_FriendList.SetWhoToUi(true)
    local success = pcall(function() C_FriendList.SendWho(query) end)
    if not success then
        print("|cFF3EB9D8[FGR-DEBUG]|r SendWho failed with pcall protection")
        self:HandleWhoQueryFailure("SendWho failed")
        self.awaitingResults = false
        self._whoResultsExpected = false
        return
    end

    self.lastWhoTime = GetTime()

    -- Failsafe: After 8 seconds, if not processed, treat as failure
    C_Timer.After(8, function()
        if self._whoResultsExpected then
            print("|cFF3EB9D8[FGR-DEBUG]|r WHO query timed out after 8 seconds (no event received)")
            self:HandleWhoQueryFailure("Polling timeout")
            self.awaitingResults = false
            self._whoResultsExpected = false
        end
    end)
end

function RecruitmentFrame:_OnWhoListUpdate()
    -- Only process if we expected results
    if not self._whoResultsExpected then return end
    print("|cFF3EB9D8[FGR-DEBUG]|r WHO_LIST_UPDATE event received. Processing results!")
    self._whoResultsExpected = false
    self.awaitingResults = false
    self:ProcessWhoResults_Polling()
end

function RecruitmentFrame:ProcessWhoResults_Polling()
    if FriendsFrame then FriendsFrame:Hide() end
    
    local results = {}
    local numResults = C_FriendList.GetNumWhoResults()

    print("|cFF3EB9D8[FGR-DEBUG]|r Processing " .. numResults .. " WHO results via event")

    for i = 1, numResults do
        local info = C_FriendList.GetWhoInfo(i)
        if info then
            local playerClass = info.filename or info.classStr or "Unknown"
            local playerName = info.fullName or info.name

            if playerName and playerName ~= "" then
                local playerData = {
                    name = playerName,
                    level = info.level or 1,
                    class = playerClass,
                    race = info.raceStr or "Unknown",
                    guild = info.fullGuildName,
                    zone = info.area or GetZoneText(),
                    queryTime = GetTime()
                }
                table.insert(results, playerData)
                print("|cFF3EB9D8[FGR-DEBUG]|r   Added: " .. playerName .. " (" .. playerClass .. ")")
            end
        end
    end

    print("|cFF3EB9D8[FGR]|r Processing " .. #results .. " valid players")

    if #results > 0 then
        local validCount = 0
        local filteredCount = 0
        for _, playerInfo in ipairs(results) do
            if playerInfo.name and playerInfo.name ~= UnitName("player") then
                if self:PassesFilters(playerInfo) then
                    foundPlayers[playerInfo.name] = playerInfo
                    validCount = validCount + 1
                    print("|cFF3EB9D8[FGR-DEBUG]|r   -> Added to found players: " .. playerInfo.name)
                else
                    filteredCount = filteredCount + 1
                    print("|cFF3EB9D8[FGR-DEBUG]|r   -> Filtered out: " .. playerInfo.name)
                end
            end
        end

        self:RefreshPlayerList()
        self:UpdatePlayerCount()
        self:UpdateSessionStats()

        local statusMsg = string.format("Found %d valid players (%d filtered out)", validCount, filteredCount)
        self:UpdateStatus(statusMsg, validCount > 0 and "green" or "orange")
    else
        self:UpdateStatus("No valid WHO results", "orange")
    end

    self:UpdateActionButtonVisibility()
    self:ReEnableScanButton()
end

function RecruitmentFrame:HandleWhoQueryFailure(reason)
    self._whoResultsExpected = false
    self.awaitingResults = false

    self:UpdateStatus("WHO query failed: " .. reason, "orange")

    if self.scanButton then
        self.scanButton:SetEnabled(true)
        if self.isClassScanMode then
            local nextIndex = (self.currentClassIndex or 1) + 1
            if nextIndex <= #self.selectedClassList then
                local nextClass = self.selectedClassList[nextIndex]
                self.scanButton:SetText("Next: " .. nextClass)
            else
                self.scanButton:SetText("Scan for Players")
            end
        else
            self.scanButton:SetText("Scan for Players")
        end
    end
end

function RecruitmentFrame:ReEnableScanButton()
    if self.scanButton then
        self.scanButton:SetEnabled(true)
        if self.isClassScanMode then
            local nextIndex = (self.currentClassIndex or 1) + 1
            if nextIndex <= #self.selectedClassList then
                local nextClass = self.selectedClassList[nextIndex]
                self.scanButton:SetText("Next: " .. nextClass)
            else
                self.scanButton:SetText("Scan for Players")
                self:ResetClassScanMode()
            end
        else
            self.scanButton:SetText("Scan for Players")
        end
    end
    self:StartCooldownTimer()
end

function RecruitmentFrame:ExecuteWhoQuery(query, className)
    print("|cFF3EB9D8[FGR]|r Executing WHO query: " .. query)

    -- Level range (from settings)
    local minLevel = (ns.pSettings and ns.pSettings.minLevel) or 1
    local maxLevel = (ns.pSettings and ns.pSettings.maxLevel) or GetMaxPlayerLevel()

    print("|cFF3EB9D8[FGR-DEBUG]|r Settings check:")
    print("|cFF3EB9D8[FGR-DEBUG]|r   ns.pSettings exists: " .. tostring(ns.pSettings ~= nil))
    if ns.pSettings then
        print("|cFF3EB9D8[FGR-DEBUG]|r   minLevel setting: " .. tostring(ns.pSettings.minLevel))
        print("|cFF3EB9D8[FGR-DEBUG]|r   maxLevel setting: " .. tostring(ns.pSettings.maxLevel))
    end
    print("|cFF3EB9D8[FGR-DEBUG]|r   Final minLevel: " .. minLevel)
    print("|cFF3EB9D8[FGR-DEBUG]|r   Final maxLevel: " .. maxLevel)

    local finalQuery = query
    if className then
        finalQuery = "c-" .. string.lower(className) .. " " .. minLevel .. "-" .. maxLevel
        -- Some retail versions require: finalQuery = "class:" .. string.lower(className) .. " " .. minLevel .. "-" .. maxLevel
        -- Uncomment and test the above if needed.
    end

    print("|cFF3EB9D8[FGR-DEBUG]|r Final query with level range: " .. finalQuery)
    self:SendActualWhoQuery(finalQuery, className)
end

function RecruitmentFrame:Show()
    if not self.isInitialized then
        self:CreateFrame()
    end
    
    if self.frame then
        self.frame:Show()
        self:RefreshUI()
    end
end

function RecruitmentFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function RecruitmentFrame:CreateFrame()
    local frame = CreateFrame("Frame", "FGRRecruitmentFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(800, 600)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
    frame.title:SetText("Fast Guild Recruiter - Recruitment")
    
    -- Close button
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            self:Hide()
        end)
    end
    
    self.frame = frame
    self:CreateScanSection()
    self:CreateFilterSection()
    self:CreateMessageSection()
    self:CreatePlayerList()
    self:CreateActionButtons()
    self:CreateStatusSection()
    
    self.isInitialized = true
    print("[FGR] Recruitment frame created successfully")
end

function RecruitmentFrame:CreateScanSection()
    local frame = self.frame
    local yOffset = -80

    local scanHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scanHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    scanHeader:SetText("Player Scanning:")
    scanHeader:SetTextColor(0.24, 0.73, 0.85)
    yOffset = yOffset - 25

    -- Scan button
    local scanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    scanBtn:SetSize(120, 30)
    scanBtn:SetText("Scan for Players")
    scanBtn:SetScript("OnClick", function()
        self:StartPlayerScan()
    end)
    self.scanButton = scanBtn

    -- Cooldown timer
    local cooldownText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cooldownText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset - 35)
    cooldownText:SetText("")
    cooldownText:SetTextColor(1, 0.5, 0)
    self.cooldownText = cooldownText
end

function RecruitmentFrame:CreateFilterSection()
    local frame = self.frame
    local yOffset = -160

    -- Filters header, left-aligned on its own line
    local filterHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    filterHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    filterHeader:SetText("Filters:")
    filterHeader:SetTextColor(0.24, 0.73, 0.85)

    -- Level range label, range, settings on own row
    yOffset = yOffset - 25
    local levelLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    levelLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 34, yOffset)
    levelLabel:SetText("Level Range:")

    local levelDisplay = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    levelDisplay:SetPoint("LEFT", levelLabel, "RIGHT", 6, 0)
    levelDisplay:SetTextColor(0.8, 0.8, 1)
    self.levelDisplay = levelDisplay

    -- Next row: checkboxes column
    yOffset = yOffset - 24
    local zoneFilterCheck = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    zoneFilterCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 34, yOffset)
    zoneFilterCheck.Text:SetText("Exclude invalid zones")
    zoneFilterCheck:SetChecked(true)
    self.zoneFilterCheck = zoneFilterCheck

    yOffset = yOffset - 24
    -- Class filter
    local classFilterCheck = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    classFilterCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 34, yOffset)
    classFilterCheck.Text:SetText("Enable class filter")
    classFilterCheck:SetChecked((ns.pSettings and ns.pSettings.enableClassFilter) or false)
    classFilterCheck:SetScript("OnClick", function(self)
        if not ns.pSettings then ns.pSettings = {} end
        ns.pSettings.enableClassFilter = self:GetChecked()
        print("|cFF3EB9D8[FGR]|r Class filter: " .. (ns.pSettings.enableClassFilter and "ON" or "OFF"))
    end)
    self.classFilterCheck = classFilterCheck

    -- Class filter info, to the right of the last checkbox
    local classFilterInfo = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    classFilterInfo:SetPoint("LEFT", classFilterCheck.Text, "RIGHT", 10, 0)
    classFilterInfo:SetTextColor(0.8, 0.8, 1)
    self.classFilterInfo = classFilterInfo

    self:UpdateClassFilterDisplay()
    self:UpdateLevelDisplay()
end

function RecruitmentFrame:UpdateClassFilterDisplay()
    if not self.classFilterInfo then return end

    if not ns.pSettings or not ns.pSettings.enableClassFilter or not ns.pSettings.classFilter then
        self.classFilterInfo:SetText("(All classes)")
        return
    end

    local selectedClasses = {}
    for className, enabled in pairs(ns.pSettings.classFilter) do
        if enabled then
            table.insert(selectedClasses, className)
        end
    end

    if #selectedClasses == 0 then
        self.classFilterInfo:SetText("(No classes selected)")
        self.classFilterInfo:SetTextColor(1, 0.5, 0.5)
    else
        local displayText = ""
        if self.isClassScanMode and self.currentClassIndex <= #self.selectedClassList then
            displayText = "(" .. self.currentClassIndex .. "/" .. #selectedClasses .. ": " .. 
                         (self.selectedClassList[self.currentClassIndex] or "Unknown") .. ")"
        elseif #selectedClasses > 5 then
            displayText = "(" .. #selectedClasses .. " classes selected)"
        else
            displayText = "(" .. table.concat(selectedClasses, ", ") .. ")"
        end

        self.classFilterInfo:SetText(displayText)
        self.classFilterInfo:SetTextColor(0.8, 0.8, 1)
    end
end

function RecruitmentFrame:UpdateLevelDisplay()
    if not self.levelDisplay then return end
    local minLevel = (ns.pSettings and ns.pSettings.minLevel) or 1
    local maxLevel = (ns.pSettings and ns.pSettings.maxLevel) or GetMaxPlayerLevel()
    self.levelDisplay:SetText(string.format("%d - %d", minLevel, maxLevel))
    print("|cFF3EB9D8[FGR-DEBUG]|r Level display updated to: " .. minLevel .. "-" .. maxLevel)
end

function RecruitmentFrame:RefreshFromSettings()
    if not self.isInitialized then return end
    self:ResetClassScanMode()
    self:UpdateLevelDisplay()
    self:UpdateClassFilterDisplay()

    if self.classFilterCheck then
        self.classFilterCheck:SetChecked((ns.pSettings and ns.pSettings.enableClassFilter) or false)
    end

    if self.messageDropdown then
        local recruitmentFrameRef = self
        UIDropDownMenu_Initialize(self.messageDropdown, function(dropdown, level)
            local messageList = recruitmentFrameRef:GetMessageList()
            local inviteOnlyInfo = UIDropDownMenu_CreateInfo()
            inviteOnlyInfo.text = "Invite Only (No Message)"
            inviteOnlyInfo.value = "invite_only"
            inviteOnlyInfo.func = function()
                UIDropDownMenu_SetSelectedValue(recruitmentFrameRef.messageDropdown, "invite_only")
                recruitmentFrameRef.selectedMessage = nil
                recruitmentFrameRef.inviteMode = "invite_only"
            end
            UIDropDownMenu_AddButton(inviteOnlyInfo, level)

            for i, msgData in ipairs(messageList) do
                local inviteAndMsgInfo = UIDropDownMenu_CreateInfo()
                inviteAndMsgInfo.text = "Invite & send message: " .. (msgData.desc or ("Message " .. i))
                inviteAndMsgInfo.value = "invite_and_message_" .. i
                inviteAndMsgInfo.func = function()
                    UIDropDownMenu_SetSelectedValue(recruitmentFrameRef.messageDropdown, "invite_and_message_" .. i)
                    recruitmentFrameRef.selectedMessage = msgData
                    recruitmentFrameRef.inviteMode = "invite_and_message"
                end
                UIDropDownMenu_AddButton(inviteAndMsgInfo, level)

                local justMsgInfo = UIDropDownMenu_CreateInfo()
                justMsgInfo.text = "Just send message: " .. (msgData.desc or ("Message " .. i))
                justMsgInfo.value = "just_message_" .. i
                justMsgInfo.func = function()
                    UIDropDownMenu_SetSelectedValue(recruitmentFrameRef.messageDropdown, "just_message_" .. i)
                    recruitmentFrameRef.selectedMessage = msgData
                    recruitmentFrameRef.inviteMode = "just_message"
                end
                UIDropDownMenu_AddButton(justMsgInfo, level)
            end
        end)
    end

    if self.sendInviteBtn then
        self.sendInviteBtn:SetShown(self.inviteMode == "invite_only" or self.inviteMode == "invite_and_message")
    end

    print("|cFF3EB9D8[FGR]|r Recruitment frame refreshed from settings")
end

function RecruitmentFrame:CreateMessageSection()
    local frame = self.frame
    local yOffset = -260

    local msgHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    msgHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    msgHeader:SetText("Invite style:")
    msgHeader:SetTextColor(0.24, 0.73, 0.85)

    local msgDropdown = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
    msgDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 140, -300)
    msgDropdown:SetScale(0.85)
    UIDropDownMenu_SetWidth(msgDropdown, 300)

    local recruitmentFrameRef = self
    UIDropDownMenu_Initialize(msgDropdown, function(dropdown, level)
        local messageList = recruitmentFrameRef:GetMessageList()
        local inviteOnlyInfo = UIDropDownMenu_CreateInfo()
        inviteOnlyInfo.text = "Invite Only (No Message)"
        inviteOnlyInfo.value = "invite_only"
        inviteOnlyInfo.func = function()
            UIDropDownMenu_SetSelectedValue(msgDropdown, "invite_only")
            recruitmentFrameRef.selectedMessage = nil
            recruitmentFrameRef.inviteMode = "invite_only"
        end
        UIDropDownMenu_AddButton(inviteOnlyInfo, level)

        for i, msgData in ipairs(messageList) do
            local inviteAndMsgInfo = UIDropDownMenu_CreateInfo()
            inviteAndMsgInfo.text = "Invite & send message: " .. (msgData.desc or ("Message " .. i))
            inviteAndMsgInfo.value = "invite_and_message_" .. i
            inviteAndMsgInfo.func = function()
                UIDropDownMenu_SetSelectedValue(msgDropdown, "invite_and_message_" .. i)
                recruitmentFrameRef.selectedMessage = msgData
                recruitmentFrameRef.inviteMode = "invite_and_message"
            end
            UIDropDownMenu_AddButton(inviteAndMsgInfo, level)

            local justMsgInfo = UIDropDownMenu_CreateInfo()
            justMsgInfo.text = "Just send message: " .. (msgData.desc or ("Message " .. i))
            justMsgInfo.value = "just_message_" .. i
            justMsgInfo.func = function()
                UIDropDownMenu_SetSelectedValue(msgDropdown, "just_message_" .. i)
                recruitmentFrameRef.selectedMessage = msgData
                recruitmentFrameRef.inviteMode = "just_message"
            end
            UIDropDownMenu_AddButton(justMsgInfo, level)
        end
    end)

    UIDropDownMenu_SetSelectedValue(msgDropdown, "invite_only")
    self.messageDropdown = msgDropdown
    self.inviteMode = "invite_only"
end

function RecruitmentFrame:CreatePlayerList()
    local frame = self.frame
    local yOffset = -280

    local listHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)
    listHeader:SetText("Found Players: 0")
    listHeader:SetTextColor(0.24, 0.73, 0.85)
    self.listHeader = listHeader

    local selectAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAllBtn:SetPoint("LEFT", listHeader, "RIGHT", 20, 0)
    selectAllBtn:SetSize(90, 22)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetScript("OnClick", function()
        RecruitmentFrame:SelectAllPlayersButton()
    end)
    self.selectAllBtn = selectAllBtn

    local deselectAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 5, 0)
    deselectAllBtn:SetSize(90, 22)
    deselectAllBtn:SetText("Deselect All")
    deselectAllBtn:SetScript("OnClick", function()
        RecruitmentFrame:DeselectAllPlayersButton()
    end)
    self.deselectAllBtn = deselectAllBtn

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset - 30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 80)
    local scrollBg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    scrollBg:SetAllPoints(scrollFrame)
    scrollBg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    local scrollBorder = scrollFrame:CreateTexture(nil, "BORDER")
    scrollBorder:SetAllPoints(scrollFrame)
    scrollBorder:SetColorTexture(0.5, 0.5, 0.5, 1)
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 1, -1)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -1, 1)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth() - 20, 1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = current - (delta * 20)
        if newScroll < 0 then
            newScroll = 0
        elseif newScroll > maxScroll then
            newScroll = maxScroll
        end
        self:SetVerticalScroll(newScroll)
    end)

    self.playerScrollFrame = scrollFrame
    self.playerScrollChild = scrollChild
end

function RecruitmentFrame:CreateActionButtons()
    local frame = self.frame

    local sendInviteBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sendInviteBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 20)
    sendInviteBtn:SetSize(120, 30)
    sendInviteBtn:SetText("Send Invite")
    sendInviteBtn:SetScript("OnClick", function()
        self:SendNextInvite()
    end)
    sendInviteBtn:Hide()
    self.sendInviteBtn = sendInviteBtn

    local blacklistBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    blacklistBtn:SetPoint("LEFT", sendInviteBtn, "RIGHT", 10, 0)
    blacklistBtn:SetSize(120, 30)
    blacklistBtn:SetText("Blacklist Selected")
    blacklistBtn:SetScript("OnClick", function()
        self:BlacklistSelectedPlayers()
    end)
    blacklistBtn:Hide()
    self.blacklistBtn = blacklistBtn

    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetPoint("LEFT", blacklistBtn, "RIGHT", 10, 0)
    clearBtn:SetSize(80, 30)
    clearBtn:SetText("Clear List")
    clearBtn:SetScript("OnClick", function()
        self:ClearPlayerList()
    end)
    clearBtn:Hide()
    self.clearBtn = clearBtn

    local settingsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settingsBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
    settingsBtn:SetSize(80, 30)
    settingsBtn:SetText("Settings")
    settingsBtn:SetScript("OnClick", function()
        if ns.SettingsManager then
            ns.SettingsManager:OpenSettings()
        end
    end)
end

function RecruitmentFrame:UpdateActionButtonVisibility()
    local hasPlayers = false
    for _ in pairs(foundPlayers) do hasPlayers = true; break end

    if self.sendInviteBtn then
        self.sendInviteBtn:SetShown(hasPlayers and (self.inviteMode == "invite_only" or self.inviteMode == "invite_and_message"))
        self:UpdateSendInviteButtonState()
    end
    if self.blacklistBtn then self.blacklistBtn:SetShown(hasPlayers) end
    if self.clearBtn then self.clearBtn:SetShown(hasPlayers) end
end

function RecruitmentFrame:UpdateSendInviteButtonState()
    local enabled = false
    for _ in pairs(selectedPlayers) do enabled = true; break end
    if self.sendInviteBtn then
        self.sendInviteBtn:SetEnabled(enabled)
    end
end

function RecruitmentFrame:SendNextInvite()
    -- Only enable this button for invite modes that send invites
    if self.inviteMode ~= "invite_only" and self.inviteMode ~= "invite_and_message" then
        self:UpdateStatus("Invite mode not selected", "orange")
        return
    end

    -- Get the next selected player from the table
    local nextToInvite = nil
    for name, data in pairs(selectedPlayers) do
        nextToInvite = { name = name, data = data }
        break  -- Only the first one
    end

    if not nextToInvite then
        self:UpdateStatus("No players selected", "orange")
        return
    end

     -- Get the "first" player in foundPlayers (top of list)
    local topName, topData
    for name, data in pairs(foundPlayers) do  -- use foundPlayers for deterministic "top" of UI
        topName = name
        topData = data
        break
    end
    if not topName or not topData then
        self:UpdateStatus("No players selected", "orange")
        self:UpdateActionButtonVisibility()
        return
    end

    -- Remove from selection & player list beforehand
    selectedPlayers[topName] = nil
    foundPlayers[topName] = nil

    -- Invite (as before)
    GuildInvite(topName)
    self.sessionStats.invitesSent = (self.sessionStats.invitesSent or 0) + 1
    print("|cFF3EB9D8[FGR]|r Sent guild invite to: " .. topName)

    -- If also message:
    if self.inviteMode == "invite_and_message" and self.selectedMessage and self.selectedMessage.message then
        local message = self:FormatMessage(self.selectedMessage.message, topName)
        SendChatMessage(message, "WHISPER", nil, topName)
        print("|cFF3EB9D8[FGR]|r Sent guild invite and message to: " .. topName)
    end

    -- Add to anti-spam
    if not ns.tblAntiSpamList then ns.tblAntiSpamList = {} end
    ns.tblAntiSpamList[string.lower(topName)] = {
        name = topName,
        time = time()
    }

    self:RefreshPlayerList()
    self:UpdatePlayerCount()
    self:UpdateSessionStats()
    self:UpdateActionButtonVisibility()
end

function RecruitmentFrame:UpdateSendInviteButtonState()
    if self.sendInviteBtn then
        local hasSelection = false
        for _, _ in pairs(selectedPlayers) do
            hasSelection = true
            break
        end
        self.sendInviteBtn:SetEnabled(hasSelection)
    end
end

function RecruitmentFrame:CreateStatusSection()
    local frame = self.frame
    local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 50)
    statusText:SetText("Ready")
    statusText:SetTextColor(0, 1, 0)
    self.statusText = statusText
    local statsText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statsText:SetPoint("BOTTOM", statusText, "TOP", 0, 5)
    statsText:SetText("Session: 0 invites sent | 0 players scanned")
    statsText:SetTextColor(0.7, 0.7, 0.7)
    self.statsText = statsText
end

function RecruitmentFrame:StartPlayerScan()
    if not self.scanButton:IsEnabled() then
        return
    end

    if isScanning then
        self:UpdateStatus("Already scanning...", "yellow")
        return
    end

    local currentTime = time()
    if currentTime - lastScanTime < scanCooldown then
        local remaining = scanCooldown - (currentTime - lastScanTime)
        self:UpdateStatus(string.format("Scan cooldown: %d seconds", remaining), "orange")
        return
    end

    if self.isClassScanMode and self.selectedClassList then
        local buttonText = self.scanButton:GetText()
        if buttonText and buttonText:match("^Next:") then
            self.currentClassIndex = (self.currentClassIndex or 1) + 1
            print("|cFF3EB9D8[FGR]|r Manually advancing to class " .. self.currentClassIndex)
        end
    end

    isScanning = true
    lastScanTime = currentTime

    local statusMsg = "Scanning for players"
    if self.isClassScanMode and #self.selectedClassList > 0 then
        local currentClass = self.selectedClassList[self.currentClassIndex or 1]
        statusMsg = "Scanning " .. currentClass .. " (" .. (self.currentClassIndex or 1) .. "/" .. #self.selectedClassList .. ")"
    end
    statusMsg = statusMsg .. "..."

    self:UpdateStatus(statusMsg, "yellow")
    self.scanButton:SetText("Scanning...")
    self.scanButton:SetEnabled(false)

    if not self.isClassScanMode or (self.currentClassIndex or 1) == 1 then
        foundPlayers = {}
        selectedPlayers = {}
    end

    self:PerformPlayerScan()
    isScanning = false
    self:StartCooldownTimer()
end

function RecruitmentFrame:PerformPlayerScan()
    selectedPlayers = {}
    self:ScanNearbyPlayers()
end

function RecruitmentFrame:ScanNearbyPlayers()
    foundPlayers = {}
    selectedPlayers = {}
    self:RefreshPlayerList()
    self:UpdatePlayerCount()
    self:UpdateSelectionCount()

    local minLevel = (ns.pSettings and ns.pSettings.minLevel) or 1
    local maxLevel = (ns.pSettings and ns.pSettings.maxLevel) or GetMaxPlayerLevel()

    if ns.pSettings and ns.pSettings.enableClassFilter and ns.pSettings.classFilter then
        if not self.isClassScanMode then
            self:BuildSelectedClassList()
        end

        if #self.selectedClassList == 0 then
            self:UpdateStatus("No classes selected in filter", "orange")
            print("|cFF3EB9D8[FGR]|r No classes selected - cannot scan")
            return
        end

        self.isClassScanMode = true
        self.currentClassIndex = self.currentClassIndex or 1
        local currentClass = self.selectedClassList[self.currentClassIndex]
        if not currentClass then
            self:ResetClassScanMode()
            return
        end

        local classQuery = "c-" .. string.lower(currentClass)
        print("|cFF3EB9D8[FGR]|r Class scan mode: scanning " .. self.currentClassIndex .. "/" .. #self.selectedClassList .. ": " .. currentClass)
        print("|cFF3EB9D8[FGR]|r Executing class query: " .. classQuery)
        self.currentScanClass = currentClass
        self:ExecuteWhoQuery(classQuery, currentClass)

    else
        print("|cFF3EB9D8[FGR]|r No class filter, using level-only query")
        self.isClassScanMode = false
        self.currentScanClass = nil
        local levelQuery = string.format("%d-%d", minLevel, maxLevel)
        self:ExecuteWhoQuery(levelQuery)
    end
end

function RecruitmentFrame:BuildSelectedClassList()
    if self.selectedClassList and #self.selectedClassList > 0 then
        return
    end

    self.selectedClassList = {}
    self.currentClassIndex = 1

    if ns.pSettings and ns.pSettings.classFilter then
        for className, enabled in pairs(ns.pSettings.classFilter) do
            if enabled then
                table.insert(self.selectedClassList, className)
            end
        end
    end

    table.sort(self.selectedClassList)
end

function RecruitmentFrame:PassesFilters(player)
    local minLevel = (ns.pSettings and ns.pSettings.minLevel) or 1
    local maxLevel = (ns.pSettings and ns.pSettings.maxLevel) or GetMaxPlayerLevel()
    if player.level < minLevel or player.level > maxLevel then
        return false
    end

    if player.guild and player.guild ~= "" then
        return false
    end

    if player.name == UnitName("player") then
        return false
    end

    local blacklistKey = string.lower(player.name)
    local isBlacklisted = ns.tblBlackList and ns.tblBlackList[blacklistKey]
    if isBlacklisted then
        return false
    end

    local antiSpamKey = string.lower(player.name)
    local antiSpamEntry = ns.tblAntiSpamList and ns.tblAntiSpamList[antiSpamKey]
    if antiSpamEntry and antiSpamEntry.time then
        local daysSince = (time() - antiSpamEntry.time) / 86400
        local maxDays = (ns.gSettings and ns.gSettings.antiSpamDays) or 7
        if daysSince < maxDays then
            return false
        end
    end

    if not self.isClassScanMode and ns.pSettings and ns.pSettings.enableClassFilter and ns.pSettings.classFilter then
        local playerClass = player.class or "Unknown"
        local classAllowed = ns.pSettings.classFilter[playerClass] or ns.pSettings.classFilter[string.upper(playerClass)]
        if not classAllowed then
            return false
        end
    end

    return true
end

function RecruitmentFrame:RefreshPlayerList()
    playerCheckboxes = {}
    for i = self.playerScrollChild:GetNumChildren(), 1, -1 do
        local child = select(i, self.playerScrollChild:GetChildren())
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = -5
    local entryHeight = 25

    for playerName, playerData in pairs(foundPlayers) do
        local entry = self:CreatePlayerEntry(playerData, yOffset)
        yOffset = yOffset - entryHeight - 2
    end

    self.playerScrollChild:SetHeight(math.max(100, -yOffset))
    self:UpdateSendInviteButtonState()
    self:UpdateActionButtonVisibility()
end

function RecruitmentFrame:CreatePlayerEntry(playerData, yOffset)
    local entry = CreateFrame("Frame", nil, self.playerScrollChild)
    entry:SetPoint("TOPLEFT", self.playerScrollChild, "TOPLEFT", 5, yOffset)
    entry:SetSize(self.playerScrollChild:GetWidth() - 10, 23)

    local bg = entry:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(entry)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)

    local checkbox = CreateFrame("CheckButton", nil, entry, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("LEFT", entry, "LEFT", 5, 0)
    checkbox:SetSize(20, 20)
    checkbox:SetChecked(selectedPlayers[playerData.name] == playerData)
    checkbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            selectedPlayers[playerData.name] = playerData
        else
            selectedPlayers[playerData.name] = nil
        end
        RecruitmentFrame:UpdateSelectionCount()
        RecruitmentFrame:UpdateSendInviteButtonState()
    end)

    playerCheckboxes[playerData.name] = checkbox

    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    nameText:SetText(playerData.name)
    local levelText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("LEFT", nameText, "RIGHT", 20, 0)
    levelText:SetText("Level " .. playerData.level)
    levelText:SetTextColor(0.8, 0.8, 0.8)
    local classText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classText:SetPoint("LEFT", levelText, "RIGHT", 15, 0)
    classText:SetText(playerData.class)
    classText:SetTextColor(0.6, 0.8, 1)

    self:UpdateSendInviteButtonState()
    return entry
end

function RecruitmentFrame:InviteSelectedPlayers()
    local count = 0
    for _ in pairs(selectedPlayers) do count = count + 1 end

    if count == 0 then
        self:UpdateStatus("No players selected", "orange")
        return
    end

    local actionText = ""
    if self.inviteMode == "invite_only" then
        actionText = "Send guild invites to"
    elseif self.inviteMode == "invite_and_message" then
        actionText = "Send guild invites and messages to"
    elseif self.inviteMode == "just_message" then
        actionText = "Send messages to"
    end

    local message = string.format("%s %d selected players?", actionText, count)
    if self.selectedMessage and (self.inviteMode == "invite_and_message" or self.inviteMode == "just_message") then
        message = message .. "\nMessage: " .. (self.selectedMessage.desc or "Custom Message")
    end

    local statusText = ""
    if self.inviteMode == "invite_only" then
        statusText = string.format("Inviting %d players...", count)
    elseif self.inviteMode == "invite_and_message" then
        statusText = string.format("Inviting and messaging %d players...", count)
    elseif self.inviteMode == "just_message" then
        statusText = string.format("Messaging %d players...", count)
    end

    self:UpdateStatus(statusText, "yellow")
    local playersToInvite = {}
    for name, data in pairs(selectedPlayers) do
        table.insert(playersToInvite, {name = name, data = data})
    end
    self:ProcessInviteQueue(playersToInvite)
end

function RecruitmentFrame:ProcessInviteQueue(inviteQueue)
    if #inviteQueue == 0 then
        self:UpdateStatus("All invites processed", "green")
        self:UpdateSessionStats()
        return
    end

    local player = table.remove(inviteQueue, 1)

    if self.inviteMode == "invite_only" then
        GuildInvite(player.name)
        self.sessionStats.invitesSent = (self.sessionStats.invitesSent or 0) + 1
        print("|cFF3EB9D8[FGR]|r Sent guild invite to: " .. player.name)
    elseif self.inviteMode == "invite_and_message" then
        GuildInvite(player.name)
        self.sessionStats.invitesSent = (self.sessionStats.invitesSent or 0) + 1
        if self.selectedMessage and self.selectedMessage.message then
            local message = self:FormatMessage(self.selectedMessage.message, player.name)
            SendChatMessage(message, "WHISPER", nil, player.name)
            print("|cFF3EB9D8[FGR]|r Sent guild invite and message to: " .. player.name)
        end
    elseif self.inviteMode == "just_message" then
        if self.selectedMessage and self.selectedMessage.message then
            local message = self:FormatMessage(self.selectedMessage.message, player.name)
            SendChatMessage(message, "WHISPER", nil, player.name)
            self.sessionStats.messagesOnly = (self.sessionStats.messagesOnly or 0) + 1
            print("|cFF3EB9D8[FGR]|r Sent message to: " .. player.name)
        end
    end

    if not ns.tblAntiSpamList then ns.tblAntiSpamList = {} end
    ns.tblAntiSpamList[string.lower(player.name)] = {
        name = player.name,
        time = time()
    }

    foundPlayers[player.name] = nil
    selectedPlayers[player.name] = nil
    self:UpdateSessionStats()
    local delay = tonumber((ns.g and ns.g.timeBetweenMessages) or "0.2")
    C_Timer.After(delay, function()
        self:ProcessInviteQueue(inviteQueue)
    end)
    self:RefreshPlayerList()
    self:UpdatePlayerCount()
end

function RecruitmentFrame:FormatMessage(message, playerName)
    local formattedMessage = message
    formattedMessage = formattedMessage:gsub("PLAYERNAME", playerName)
    local guildName = GetGuildInfo("player") or "[Guild]"
    formattedMessage = formattedMessage:gsub("GUILDNAME", guildName)
    local guildLink = "[Guild]"
    if ns.guildInfo and ns.guildInfo.guildLink and ns.guildInfo.guildLink ~= "" then
        guildLink = ns.guildInfo.guildLink
    elseif ns.guild and ns.guild.info and ns.guild.info.guildLink and ns.guild.info.guildLink ~= "" then
        guildLink = ns.guild.info.guildLink
    else
        local clubID = ns.guildInfo and ns.guildInfo.clubID
        if not clubID and ns.guild and ns.guild.info then
            clubID = ns.guild.info.clubID
        end
        if clubID and not ns.classic then
            local club = ClubFinderGetCurrentClubListingInfo(clubID)
            if club and club.clubFinderGUID then
                guildLink = "|cffffd200|HclubFinder:" .. club.clubFinderGUID .. "|h[" .. (club.name or guildName) .. "]|h|r"
            else
                guildLink = "[" .. guildName .. "]"
            end
        else
            guildLink = "[" .. guildName .. "]"
        end
    end
    formattedMessage = formattedMessage:gsub("GUILDLINK", guildLink)
    print("|cFF3EB9D8[FGR-DEBUG]|r Formatted message: " .. formattedMessage)
    print("|cFF3EB9D8[FGR-DEBUG]|r Guild link used: " .. guildLink)
    return formattedMessage
end

function RecruitmentFrame:EnsureGuildLink()
    if not ns.guildInfo then ns.guildInfo = {} end
    if not ns.guild then ns.guild = {info = {}} end
    if not ns.guild.info then ns.guild.info = {} end
    local guildName = GetGuildInfo("player")
    if not guildName then return end
    ns.guildInfo.guildName = guildName
    ns.guild.info.guildName = guildName
    if ns.classic then
        ns.guildInfo.guildLink = "[" .. guildName .. "]"
        ns.guild.info.guildLink = "[" .. guildName .. "]"
        return
    end
    local clubID = C_Club.GetGuildClubId()
    if clubID then
        ns.guildInfo.clubID = clubID
        ns.guild.info.clubID = clubID
        local club = ClubFinderGetCurrentClubListingInfo(clubID)
        if club and club.clubFinderGUID then
            local guildLink = "|cffffd200|HclubFinder:" .. club.clubFinderGUID .. "|h[" .. club.name .. "]|h|r"
            ns.guildInfo.guildLink = guildLink
            ns.guild.info.guildLink = guildLink
            print("|cFF3EB9D8[FGR]|r Guild link created: " .. guildLink)
        else
            C_Timer.After(2, function()
                self:EnsureGuildLink()
            end)
        end
    end
end

function RecruitmentFrame:BlacklistSelectedPlayers()
    local count = 0
    for _ in pairs(selectedPlayers) do count = count + 1 end
    if count == 0 then
        self:UpdateStatus("No players selected", "orange")
        return
    end
    if not ns.tblBlackList then ns.tblBlackList = {} end

    for name, data in pairs(selectedPlayers) do
        local key = string.lower(name)
        ns.tblBlackList[key] = {
            name = name,
            reason = "Blacklisted via recruitment interface",
            blBy = UnitName("player"),
            date = date("%m/%d/%Y %H:%M"),
            private = false
        }
        foundPlayers[name] = nil
    end

    selectedPlayers = {}
    self:RefreshPlayerList()
    self:UpdatePlayerCount()
    self:UpdateActionButtonVisibility()
    self:UpdateStatus(string.format("%d players blacklisted", count), "green")
end

function RecruitmentFrame:ClearPlayerList()
    foundPlayers = {}
    selectedPlayers = {}
    self:RefreshPlayerList()
    self:UpdatePlayerCount()
    self:UpdateActionButtonVisibility()
    self:UpdateStatus("Player list cleared", "green")
end

function RecruitmentFrame:GetMessageList()
    if ns.Database and ns.Database.GetMessageList then
        return ns.Database:GetMessageList()
    elseif ns.guild and ns.guild.data and ns.guild.data.messageList then
        return ns.guild.data.messageList
    elseif ns.guild and ns.guild.messageList then
        return ns.guild.messageList
    else
        return {}
    end
end

function RecruitmentFrame:UpdatePlayerCount()
    local count = 0
    for _ in pairs(foundPlayers) do count = count + 1 end
    if self.listHeader then
        self.listHeader:SetText("Found Players: " .. count)
    end
end

function RecruitmentFrame:UpdateSelectionCount()
    local selectedCount = 0
    for _ in pairs(selectedPlayers) do selectedCount = selectedCount + 1 end
    if self.selectAllCheck and self.selectAllCheck.Text then
        self.selectAllCheck.Text:SetText("Select All (" .. selectedCount .. ")")
    end
end

function RecruitmentFrame:UpdateStatus(text, color)
    if not self.statusText then return end
    self.statusText:SetText(text)
    if color == "red" then
        self.statusText:SetTextColor(1, 0, 0)
    elseif color == "yellow" or color == "orange" then
        self.statusText:SetTextColor(1, 1, 0)
    elseif color == "green" then
        self.statusText:SetTextColor(0, 1, 0)
    else
        self.statusText:SetTextColor(1, 1, 1)
    end
end

function RecruitmentFrame:StartCooldownTimer()
    local function updateCooldown()
        if not self.cooldownText or not self.scanButton then return end
        local currentTime = time()
        local remaining = scanCooldown - (currentTime - lastScanTime)
        if remaining > 0 then
            self.scanButton:SetEnabled(false)
            self.scanButton:SetText(string.format("Wait %ds", math.ceil(remaining)))
            self.cooldownText:SetText(string.format("Next scan available in: %d seconds", math.ceil(remaining)))
            C_Timer.After(1, updateCooldown)
        else
            self.scanButton:SetEnabled(true)
            self.cooldownText:SetText("")
            if self.isClassScanMode and self.selectedClassList and #self.selectedClassList > 0 then
                local nextIndex = (self.currentClassIndex or 1) + 1
                if nextIndex <= #self.selectedClassList then
                    local nextClass = self.selectedClassList[nextIndex]
                    self.scanButton:SetText("Next: " .. nextClass .. " (" .. nextIndex .. "/" .. #self.selectedClassList .. ")")
                    print("|cFF3EB9D8[FGR]|r Ready for next class: " .. nextClass .. " (click to continue)")
                else
                    self.scanButton:SetText("Scan for Players")
                    self:ResetClassScanMode()
                    print("|cFF3EB9D8[FGR]|r All classes completed")
                end
            else
                self.scanButton:SetText("Scan for Players")
            end
            self:UpdateClassFilterDisplay()
        end
    end
    updateCooldown()
end

function RecruitmentFrame:ResetClassScanMode()
    self.isClassScanMode = false
    self.currentClassIndex = 1
    self.selectedClassList = {}
    self.currentScanClass = nil
    print("|cFF3EB9D8[FGR]|r Class scan mode reset")
end

function RecruitmentFrame:RefreshUI()
    if not self.isInitialized then return end
    self:UpdateLevelDisplay()
    self:UpdateSessionStats()
    self:UpdateClassFilterDisplay()
    if self.messageDropdown then
        local recruitmentFrameRef = self
        UIDropDownMenu_Initialize(self.messageDropdown, function(dropdown, level)
            local messageList = recruitmentFrameRef:GetMessageList()
            local inviteOnlyInfo = UIDropDownMenu_CreateInfo()
            inviteOnlyInfo.text = "Invite Only (No Message)"
            inviteOnlyInfo.value = "invite_only"
            inviteOnlyInfo.func = function()
                UIDropDownMenu_SetSelectedValue(recruitmentFrameRef.messageDropdown, "invite_only")
                recruitmentFrameRef.selectedMessage = nil
                recruitmentFrameRef.inviteMode = "invite_only"
            end
            UIDropDownMenu_AddButton(inviteOnlyInfo, level)
            for i, msgData in ipairs(messageList) do
                local inviteAndMsgInfo = UIDropDownMenu_CreateInfo()
                inviteAndMsgInfo.text = "Invite & send message: " .. (msgData.desc or ("Message " .. i))
                inviteAndMsgInfo.value = "invite_and_message_" .. i
                inviteAndMsgInfo.func = function()
                    UIDropDownMenu_SetSelectedValue(recruitmentFrameRef.messageDropdown, "invite_and_message_" .. i)
                    recruitmentFrameRef.selectedMessage = msgData
                    recruitmentFrameRef.inviteMode = "invite_and_message"
                end
                UIDropDownMenu_AddButton(inviteAndMsgInfo, level)
                local justMsgInfo = UIDropDownMenu_CreateInfo()
                justMsgInfo.text = "Just send message: " .. (msgData.desc or ("Message " .. i))
                justMsgInfo.value = "just_message_" .. i
                justMsgInfo.func = function()
                    UIDropDownMenu_SetSelectedValue(recruitmentFrameRef.messageDropdown, "just_message_" .. i)
                    recruitmentFrameRef.selectedMessage = msgData
                    recruitmentFrameRef.inviteMode = "just_message"
                end
                UIDropDownMenu_AddButton(justMsgInfo, level)
            end
        end)
    end
    self:UpdatePlayerCount()
    self:UpdateSelectionCount()

    if self.sendInviteBtn then
    self.sendInviteBtn:SetShown(self.inviteMode == "invite_only" or self.inviteMode == "invite_and_message")
    end
end

function RecruitmentFrame:UpdateSessionStats()
    if not self.statsText then return end
    local invites = self.sessionStats.invitesSent or 0
    local scanned = self.sessionStats.playersScanned or 0
    local messagesOnly = self.sessionStats.messagesOnly or 0
    local statsText = string.format("Session: %d invites sent | %d messages sent | %d players scanned", 
                                   invites, messagesOnly, scanned)
    self.statsText:SetText(statsText)
end

function RecruitmentFrame:Initialize()
    self.isInitialized = false
    self.frame = nil
    self.playerList = {}
    self.scanButton = nil
    self.sendinviteButton = nil
    self.messageDropdown = nil
    self.playerScrollFrame = nil
    self.statusText = nil
    self.selectedMessage = nil
    self.whoResults = nil
    self._whoResultsExpected = false
    self.lastWhoTime = 0
    self.selectedClassList = {}
    self.currentClassIndex = 1
    self.isClassScanMode = false
    self.sessionStats = {
        invitesSent = 0,
        playersScanned = 0,
        messagesOnly = 0
    }
    isScanning = false
    lastScanTime = 0
    if not ns.guild then
        ns.guild = { data = { messageList = {} } }
    end
    if not ns.guild.data then
        ns.guild.data = { messageList = {} }
    end
    if not ns.guild.data.messageList then
        ns.guild.data.messageList = {}
    end
    self:EnsureGuildLink()
    print("[FGR] RecruitmentFrame module initialized")
end

function RecruitmentFrame:SelectAllPlayersButton()
    for name, data in pairs(foundPlayers) do
        selectedPlayers[name] = data
        if playerCheckboxes[name] then
            playerCheckboxes[name]:SetChecked(true)
        end
    end
    self:UpdateSelectionCount()
    self:UpdateSendInviteButtonState()
end

function RecruitmentFrame:DeselectAllPlayersButton()
    for name, data in pairs(foundPlayers) do
        selectedPlayers[name] = nil
        if playerCheckboxes[name] then
            playerCheckboxes[name]:SetChecked(false)
        end
    end
    self:UpdateSelectionCount()
    self:UpdateSendInviteButtonState()
end

RecruitmentFrame:Initialize()