local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

ns.MinimapIcon = {}
local MinimapIcon = ns.MinimapIcon

local icon = LibStub('LibDBIcon-1.0')

function MinimapIcon:Initialize()
    self:CreateIcon()
    ns.Logger:Debug("Minimap icon initialized")
end

function MinimapIcon:CreateIcon()
    local iconData = LibStub("LibDataBroker-1.1"):NewDataObject("FGR_Icon", {
        type = 'data source',
        icon = ns.Icons.MAIN,
        OnClick = function(_, button)
            self:HandleClick(button)
        end,
        OnTooltipShow = function()
            self:ShowTooltip()
        end,
        OnLeave = function() 
            GameTooltip:Hide() 
        end,
    })

    icon:Register('FGR_Icon', iconData, ns.pSettings.ui.minimap)
    self.icon = icon
end

function MinimapIcon:HandleClick(button)
    if button == 'LeftButton' and IsShiftKeyDown() then
        self:HandleShiftLeftClick()
    elseif button == 'LeftButton' then
        self:HandleLeftClick()
    elseif button == 'RightButton' then
        self:HandleRightClick()
    end
end

function MinimapIcon:HandleShiftLeftClick()
    if ns.UI and ns.UI.MainFrame then
        if not ns.UI.MainFrame:IsShown() then 
            ns.UI.MainFrame:Show() 
        end
        -- Open scanner if available
        if ns.UI.Scanner and not ns.UI.Scanner:IsShown() then
            ns.UI.MainFrame:OpenScanner()
        end
    end
end

function MinimapIcon:HandleLeftClick()
    if ns.UI and ns.UI.MainFrame then
        ns.UI.MainFrame:Toggle()
    end
end

function MinimapIcon:HandleRightClick()
    Settings.OpenToCategory('Fast Guild Recruiter')
end

function MinimapIcon:ShowTooltip()
    local title = ns.Utils:ColorText(ns.Colors.WARNING, L['TITLE']..' (v'..FGR.version..'):')
    local body = ns.Utils:ColorText('FFFFFFFF', L['MINIMAP_TOOLTIP'])

    -- Anti-spam count
    local antiSpamCount = ns.Utils:TableSize(ns.tblAntiSpamList or {})
    local antiSpamText = ' |cFFFF0000'..antiSpamCount..'|r'

    -- Blacklist count  
    local blacklistCount = ns.Utils:TableSize(ns.tblBlackList or {})
    local blacklistText = ' |cFFFF0000'..blacklistCount..'|r'

    body = body:gsub('%%AntiSpam', antiSpamText):gsub('%%BlackList', blacklistText)

    if ns.Utils and ns.Utils.CreateTooltip then
        ns.Utils:CreateTooltip(title, body, 'FORCE_TOOLTIP')
    else
        GameTooltip:SetText(title)
        GameTooltip:AddLine(body, 1, 1, 1, true)
    end
end

function MinimapIcon:Show()
    if self.icon then
        self.icon:Show('FGR_Icon')
    end
end

function MinimapIcon:Hide()
    if self.icon then
        self.icon:Hide('FGR_Icon')
    end
end

function MinimapIcon:Toggle()
    if ns.pSettings.ui.minimap.hide then
        self:Show()
        ns.pSettings.ui.minimap.hide = false
    else
        self:Hide()
        ns.pSettings.ui.minimap.hide = true
    end
end