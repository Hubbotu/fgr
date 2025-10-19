    -- Modules/UI/MainFrame.lua
    local addonName, ns = ...

    ns.UI = ns.UI or {}
    ns.UI.MainFrame = {}
    local MainFrame = ns.UI.MainFrame

    local frame = nil

    function MainFrame:Initialize()
        if frame then return end -- Already initialized
        
        self:CreateFrame()
        
        if ns.Logger and ns.Logger.Debug then
            ns.Logger:Debug("Main frame initialized")
        end
    end

    function MainFrame:CreateFrame()
        -- Create main frame
        frame = CreateFrame("Frame", "FGRMainFrame", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(400, 500)
        frame:SetPoint("LEFT")
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
        frame.title:SetText("Fast Guild Recruiter")
        
        -- Create content area
        local content = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        content:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 4, -4)
        content:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -3, 4)
        
        local contentChild = CreateFrame("Frame")
        contentChild:SetSize(content:GetWidth(), 1000)
        content:SetScrollChild(contentChild)
        
        frame.content = content
        frame.contentChild = contentChild
        
        self:CreateContent()
        
        -- Close button functionality
        frame:SetScript("OnHide", function()
            if ns.Logger then
                ns.Logger:Debug("Main frame hidden")
            end
        end)
    end

    function MainFrame:CreateContent()
        local content = frame.contentChild
        local yOffset = -10
        
        -- Status section (keep existing code)
        local statusLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        statusLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        statusLabel:SetText("Addon Status")
        yOffset = yOffset - 30
        
        local statusText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        statusText:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        statusText:SetJustifyH("LEFT")
        statusText:SetWidth(350)
        
        local function updateStatus()
            local status = {}
            table.insert(status, "In Guild: " .. (IsInGuild() and "Yes" or "No"))
            table.insert(status, "Can Invite: " .. (CanGuildInvite() and "Yes" or "No"))
            
            if ns.tblBlackList then
                local count = 0
                for _ in pairs(ns.tblBlackList) do count = count + 1 end
                table.insert(status, "Blacklisted Players: " .. count)
            end
            
            if ns.tblAntiSpamList then
                local count = 0
                for _ in pairs(ns.tblAntiSpamList) do count = count + 1 end
                table.insert(status, "Anti-Spam Entries: " .. count)
            end
            
            statusText:SetText(table.concat(status, "\n"))
        end
        
        updateStatus()
        frame.updateStatus = updateStatus
        yOffset = yOffset - 120
        
        -- RECRUITMENT SECTION
        local recruitmentLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        recruitmentLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        recruitmentLabel:SetText("Guild Recruitment")
        recruitmentLabel:SetTextColor(0.24, 0.73, 0.85)
        yOffset = yOffset - 30
        
        -- Regular recruitment button
        local recruitBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        recruitBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        recruitBtn:SetSize(200, 35)
        recruitBtn:SetText("Normal Mode")
        recruitBtn:SetScript("OnClick", function()
            print("[FGR] Opening recruitment window...")
            if ns.RecruitmentFrame then
                if ns.pSettings then
                    ns.pSettings.isCompact = false
                end
                ns.RecruitmentFrame.compactMode = false
                ns.RecruitmentFrame:Show()
                MainFrame:Hide()
            else
                print("|cFFFF0000[FGR]|r Recruitment system not available")
            end
        end)
        
        recruitBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Guild Recruitment", 1, 1, 1)
            GameTooltip:AddLine("Scan for and recruit new guild members", nil, nil, nil, true)
            GameTooltip:AddLine("Full interface with all features", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        recruitBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        local compactRecruitBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        compactRecruitBtn:SetPoint("LEFT", recruitBtn, "RIGHT", 10, 0) -- Place it to the right of the regular button
        compactRecruitBtn:SetSize(180, 35)
        compactRecruitBtn:SetText("Compact Mode")
        compactRecruitBtn:SetScript("OnClick", function()
            print("[FGR] Opening recruitment window in compact mode...")
            if ns.RecruitmentFrame then
                -- Set compact mode flag before showing
                if ns.pSettings then
                    ns.pSettings.isCompact = true
                end
                ns.RecruitmentFrame.compactMode = true
                ns.RecruitmentFrame:Show()
                MainFrame:Hide()
            else
                print("|cFFFF0000[FGR]|r Recruitment system not available")
            end
        end)
        
        -- Tooltip for compact recruitment button
        compactRecruitBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Compact Recruitment", 0.8, 0.8, 1)
            GameTooltip:AddLine("Streamlined interface for quick recruiting", nil, nil, nil, true)
            GameTooltip:AddLine("Takes up less screen space", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        compactRecruitBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        yOffset = yOffset - 50
        
        -- Rest of your existing code (Buttons section, etc.)
        local buttonsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        buttonsLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        buttonsLabel:SetText("Quick Actions")
        yOffset = yOffset - 30
        
        -- Settings button (keep existing)
        local settingsBtn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
        settingsBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        settingsBtn:SetSize(120, 22)
        settingsBtn:SetText("Settings")
        settingsBtn:SetNormalFontObject("GameFontNormal")
        settingsBtn:SetScript("OnClick", function()
            if ns.SettingsManager and ns.SettingsManager.OpenSettings then
                ns.SettingsManager:OpenSettings()
                MainFrame:Hide()
            elseif Settings and Settings.OpenToCategory then
                local success = pcall(Settings.OpenToCategory, "AddOns")
                if success then
                    print("|cFFFFFF00[FGR]|r Opened AddOns settings. Look for Fast Guild Recruiter.")
                else
                    print("|cFFFF0000[FGR]|r Settings not available")
                end
            else
                print("|cFFFF0000[FGR]|r Settings not available")
            end
        end)

        yOffset = yOffset - 35

        local helpLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        helpLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        helpLabel:SetText("Commands")
        yOffset = yOffset - 25
        
        local helpText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        helpText:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        helpText:SetJustifyH("LEFT")
        helpText:SetWidth(350)
        
        local commands = {
            "/fgr - Toggle this window",
            "/fgr config - Open settings",
            "/fgr help - Show help in chat",
            "/fgr status - Show status in chat",
            "/fgr debug - Toggle debug mode",
            "/fgr blacklist <name> - Blacklist player",
        }
        
        helpText:SetText(table.concat(commands, "\n"))
    end

    function MainFrame:Show()
        if not frame then
            self:Initialize()
        end
        
        if frame then
            frame:Show()
            if frame.updateStatus then
                frame.updateStatus()
            end
            if ns.Logger then
                ns.Logger:Debug("Main frame shown")
            end
        end
    end

    function MainFrame:Hide()
        if frame then
            frame:Hide()
            if ns.Logger then
                ns.Logger:Debug("Main frame hidden")
            end
        end
    end

    function MainFrame:Toggle()
        if not frame then
            self:Initialize()
        end
        
        if frame then
            if frame:IsShown() then
                self:Hide()
            else
                self:Show()
            end
        end
    end

    function MainFrame:IsShown()
        return frame and frame:IsShown() or false
    end

    function MainFrame:CreateRecruitmentButton(parent, yOffset)
        local recruitBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        recruitBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset or -100)
        recruitBtn:SetSize(200, 35)
        recruitBtn:SetText("Recruit Players")
        recruitBtn:SetScript("OnClick", function()
            if ns.RecruitmentFrame then
                ns.RecruitmentFrame:Show()
                MainFrame:Hide()
            else
                print("|cFFFF0000[FGR]|r Recruitment system not available")
            end
        end)
        
        return recruitBtn
    end