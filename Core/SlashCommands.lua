-- Core/SlashCommands.lua
local addonName, ns = ...
local L = LibStub and LibStub:GetLibrary("AceLocale-3.0", true)
if L then
    L = L:GetLocale(addonName, true)
end
L = L or {}

ns.SlashCommands = {}
local SlashCommands = ns.SlashCommands

function SlashCommands:Initialize()
    self:RegisterCommands()
    if ns.Logger and ns.Logger.Debug then
        ns.Logger:Debug("Slash commands initialized")
    end
end

function SlashCommands:RegisterCommands()
    local function slashCommand(msg)
        msg = msg and strtrim(strlower(msg)) or ""

        if not msg or msg == '' then
            self:HandleEmptyCommand()
        elseif msg == strlower(L['HELP'] or 'help') then
            self:ShowHelp()
        elseif msg == strlower(L['CONFIG'] or 'config') or msg == 'config' or msg == 'settings' then
            self:OpenSettings()
        elseif msg:match(strlower(L['BLACKLIST'] or 'blacklist')) or msg:match('blacklist') then
            self:HandleBlacklistCommand(msg)
        elseif msg == 'debug' then
            self:ToggleDebug()
        elseif msg == 'status' then
            self:ShowStatus()
        elseif msg == 'dbdebug' or msg == 'database' then
                self:HandleDatabaseDebug()
        else
            self:ShowHelp()
        end
    end

    -- Register multiple command variants
    local commands = {'fgr', 'gr', 'recruiter', 'guildrecruiter'}
    for _, cmd in ipairs(commands) do
        if FGR and FGR.RegisterChatCommand then
            FGR:RegisterChatCommand(cmd, slashCommand)
        else
            -- Fallback registration
            _G["SLASH_" .. strupper(cmd) .. "1"] = "/" .. cmd
            SlashCmdList[strupper(cmd)] = slashCommand
        end
    end
    
    print("|cFF3EB9D8[FGR]|r Slash commands registered: /fgr, /gr, /recruiter")
end

function SlashCommands:HandleEmptyCommand()
    -- Check if MainFrame exists and is available
    if ns.UI and ns.UI.MainFrame and ns.UI.MainFrame.Toggle then
        ns.UI.MainFrame:Toggle()
    else
        print("|cFF3EB9D8[FGR]|r Main UI not available yet. Use /fgr config to open settings.")
        print("|cFF3EB9D8[FGR]|r Available commands: /fgr help")
    end
end

function SlashCommands:ShowHelp()
    local help = {
        "|cFF3EB9D8Fast Guild Recruiter Commands:|r",
        "/fgr - Toggle main window",
        "/fgr config - Open settings",
        "/fgr help - Show this help",
        "/fgr status - Show addon status",
        "/fgr debug - Toggle debug mode",
        "/fgr blacklist <name> - Add player to blacklist",
    }
    
    for _, line in ipairs(help) do
        print(line)
    end
end

function SlashCommands:OpenSettings()
    if ns.SettingsManager and ns.SettingsManager.OpenSettings then
        ns.SettingsManager:OpenSettings()
    elseif Settings and Settings.OpenToCategory then
        Settings.OpenToCategory('Fast Guild Recruiter')
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory('Fast Guild Recruiter')
    else
        print("|cFFFF0000[FGR]|r Settings not available - addon may not be fully loaded")
    end
end

function SlashCommands:TestOpenSettings()
    print("|cFF3EB9D8[FGR] Direct settings test...")
    
    if ns.SettingsManager then
        print("SettingsManager exists: " .. tostring(ns.SettingsManager.isInitialized))
        
        -- Check the new property names
        if ns.SettingsManager.category then
            local cat = ns.SettingsManager.category
            print("Category found: " .. tostring(cat))
            print("Category ID: " .. tostring(cat.ID))
            print("Category name: " .. tostring(cat.name))
            
            -- Try direct approach
            if Settings and Settings.OpenToCategory then
                print("Trying direct Settings.OpenToCategory with our category...")
                local success, err = pcall(Settings.OpenToCategory, cat)
                print("Result: " .. tostring(success) .. ", Error: " .. tostring(err))
            end
        elseif ns.SettingsManager.settingsCategory then
            print("Found old settingsCategory property")
            local cat = ns.SettingsManager.settingsCategory
            print("Category: " .. tostring(cat))
        else
            print("No category found in SettingsManager")
            print("Available properties:")
            for k, v in pairs(ns.SettingsManager) do
                print("  " .. k .. ": " .. type(v))
            end
        end
    else
        print("SettingsManager not available")
    end
end

function SlashCommands:HandleBlacklistCommand(msg)
    local name = msg:gsub('blacklist', ''):trim()
    if name and name ~= '' then
        name = strupper(strsub(name,1,1))..strlower(strsub(name,2))
        if ns.BlacklistManager then
            ns.BlacklistManager:Add(name, "Added via slash command")
            print("|cFF3EB9D8[FGR]|r Added " .. name .. " to blacklist")
        else
            print("|cFFFF0000[FGR]|r Blacklist manager not available")
        end
    else
        print("|cFFFF0000[FGR]|r Usage: /fgr blacklist <playername>")
    end
end

function SlashCommands:ToggleDebug()
    FGR.debug = not FGR.debug
    print("|cFF3EB9D8[FGR]|r Debug mode: " .. (FGR.debug and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
end

function SlashCommands:ShowStatus()
    local status = {
        "|cFF3EB9D8Fast Guild Recruiter Status:|r",
        "Version: " .. (FGR.version or "Unknown"),
        "Core Enabled: " .. (ns.Core and ns.Core.isEnabled and "Yes" or "No"),
        "In Guild: " .. (IsInGuild() and "Yes" or "No"),
        "Can Invite: " .. (CanGuildInvite() and "Yes" or "No"),
        "Debug Mode: " .. (FGR.debug and "On" or "Off"),
        "Main UI Available: " .. (ns.UI and ns.UI.MainFrame and "Yes" or "No"),
    }
    
    if ns.tblBlackList then
        local blCount = 0
        for _ in pairs(ns.tblBlackList) do blCount = blCount + 1 end
        table.insert(status, "Blacklisted Players: " .. blCount)
    end
    
    if ns.tblAntiSpamList then
        local asCount = 0
        for _ in pairs(ns.tblAntiSpamList) do asCount = asCount + 1 end
        table.insert(status, "Anti-Spam Entries: " .. asCount)
    end
    
    for _, line in ipairs(status) do
        print(line)
    end
end

-- Helper function for string trimming
function string:trim()
    return self:match("^%s*(.-)%s*$")
end

-- Initialize slash commands when this file loads, but with a delay to ensure FGR exists
local function InitializeSlashCommands()
    if FGR then
        SlashCommands:Initialize()
    else
        -- If FGR doesn't exist yet, wait and try again
        C_Timer.After(0.1, InitializeSlashCommands)
    end
end

function SlashCommands:TestSettings()
    print("|cFF3EB9D8[FGR]|r Testing settings registration...")
    
    if ns.SettingsManager then
        print("SettingsManager exists: " .. tostring(ns.SettingsManager.isInitialized))
        print("Settings name: " .. tostring(ns.SettingsManager.settingsName))
        print("Settings category: " .. tostring(ns.SettingsManager.settingsCategory))
        
        if Settings then
            print("Modern Settings API available")
        end
        if AceConfig then
            print("AceConfig available")
        end
        if InterfaceOptionsFrame_OpenToCategory then
            print("Legacy Interface Options available")
        end
    else
        print("SettingsManager not available")
    end
end

function SlashCommands:HandleDatabaseDebug()
    print("|cFF00FFFF[FGR-DB-DEBUG]|r === DATABASE STRUCTURE DEBUG ===")
    print("FGR.db name: " .. tostring(FGR.db))
    print("Database initialized: " .. tostring(ns.Database and ns.Database.isInitialized))
    
    if ns.Database and ns.Database.db then
        print("Database object exists: true")
        print("Global data exists: " .. tostring(ns.Database.db.global ~= nil))
        
        if ns.Database.db.global then
            print("Guilds table exists: " .. tostring(ns.Database.db.global.guilds ~= nil))
            
            if ns.Database.db.global.guilds then
                local guildCount = 0
                for _ in pairs(ns.Database.db.global.guilds) do guildCount = guildCount + 1 end
                print("Number of guilds: " .. guildCount)
                
                for guildId, guildData in pairs(ns.Database.db.global.guilds) do
                    print("Guild ID: " .. tostring(guildId))
                    if guildData.data and guildData.data.messageList then
                        print("  Messages: " .. #guildData.data.messageList)
                        for i, msg in ipairs(guildData.data.messageList) do
                            print("    " .. i .. ": " .. (msg.desc or "No desc"))
                        end
                    else
                        print("  No message list found")
                    end
                end
            end
        end
    else
        print("Database object: false")
    end
    
    print("ns.guild exists: " .. tostring(ns.guild ~= nil))
    if ns.guild and ns.guild.data and ns.guild.data.messageList then
        print("ns.guild messageList count: " .. #ns.guild.data.messageList)
    end
    
    -- Check current club ID
    local clubID = C_Club.GetGuildClubId()
    print("Current club ID: " .. tostring(clubID))
    print("FGR.clubID: " .. tostring(FGR.clubID))
end

InitializeSlashCommands()