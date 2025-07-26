-- Modules/Lists/BlacklistManager.lua
local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

ns.BlacklistManager = {}
local BlacklistManager = ns.BlacklistManager

function BlacklistManager:Initialize()
    -- Create cache with fallback if Performance module isn't available
    if ns.Performance and ns.Performance.CreateCache then
        self.cache = ns.Performance:CreateCache(500, 300) -- 5 minute cache
    else
        -- Simple fallback cache implementation
        self.cache = self:CreateSimpleCache()
        if ns.Logger and ns.Logger.Warn then
            ns.Logger:Warn("Performance module not available, using simple cache")
        end
    end
    
    if ns.Logger and ns.Logger.Debug then
        ns.Logger:Debug("Blacklist manager initialized")
    end
end

function BlacklistManager:CreateSimpleCache()
    -- Simple cache fallback if Performance module isn't loaded
    local cache = {
        data = {},
        maxSize = 500,
    }
    
    function cache:Get(key)
        return self.data[key]
    end
    
    function cache:Set(key, value)
        -- Simple size management
        if self:Size() >= self.maxSize then
            local count = 0
            for k, _ in pairs(self.data) do
                self.data[k] = nil
                count = count + 1
                if count >= 100 then break end -- Remove 100 entries
            end
        end
        self.data[key] = value
    end
    
    function cache:Remove(key)
        self.data[key] = nil
    end
    
    function cache:Size()
        local count = 0
        for _ in pairs(self.data) do
            count = count + 1
        end
        return count
    end
    
    return cache
end

function BlacklistManager:Add(playerName, reason, isPrivate)
    if not playerName or playerName == '' then
        if ns.Logger then
            ns.Logger:Error("Cannot blacklist: no player name provided")
        end
        return false
    end
    
    local key = self:CreateKey(playerName)
    
    if ns.tblBlackList and ns.tblBlackList[key] then
        if ns.Logger then
            ns.Logger:Warn("Player %s is already blacklisted", playerName)
        end
        return false
    end
    
    -- Initialize blacklist table if it doesn't exist
    ns.tblBlackList = ns.tblBlackList or {}
    
    local blacklistEntry = {
        key = key,
        name = playerName,
        reason = reason or 'No reason provided',
        blBy = UnitName('player'),
        date = time(),
        private = isPrivate or false,
    }
    
    ns.tblBlackList[key] = blacklistEntry
    
    -- Save to database
    if ns.Database and ns.Database.SaveCompressedData then
        ns.Database:SaveCompressedData('blackList', ns.tblBlackList)
    end
    
    if ns.Logger then
        ns.Logger:Info("Blacklisted player: %s (Reason: %s)", playerName, blacklistEntry.reason)
    end
    
    -- Clear cache
    if self.cache then
        self.cache:Remove(key)
    end
    
    return true
end

function BlacklistManager:Remove(playerName)
    local key = self:CreateKey(playerName)
    
    if not ns.tblBlackList or not ns.tblBlackList[key] then
        if ns.Logger then
            ns.Logger:Warn("Player %s is not blacklisted", playerName)
        end
        return false
    end
    
    -- Initialize global blacklist removed table
    ns.g = ns.g or {}
    ns.g.blackListRemoved = ns.g.blackListRemoved or {}
    table.insert(ns.g.blackListRemoved, ns.tblBlackList[key])
    
    -- Remove from blacklist
    ns.tblBlackList[key] = nil
    
    -- Save to database
    if ns.Database and ns.Database.SaveCompressedData then
        ns.Database:SaveCompressedData('blackList', ns.tblBlackList)
    end
    
    if ns.Logger then
        ns.Logger:Info("Removed player from blacklist: %s", playerName)
    end
    
    -- Clear cache
    if self.cache then
        self.cache:Remove(key)
    end
    
    return true
end

function BlacklistManager:IsBlacklisted(playerName)
    local key = self:CreateKey(playerName)
    
    -- Check cache first
    if self.cache then
        local cached = self.cache:Get(key)
        if cached ~= nil then
            return cached
        end
    end
    
    -- Check blacklist
    local isBlacklisted = (ns.tblBlackList and ns.tblBlackList[key]) ~= nil
    
    -- Cache the result
    if self.cache then
        self.cache:Set(key, isBlacklisted)
    end
    
    return isBlacklisted
end

function BlacklistManager:GetEntry(playerName)
    local key = self:CreateKey(playerName)
    return ns.tblBlackList and ns.tblBlackList[key] or nil
end

function BlacklistManager:UpdateReason(playerName, newReason, isPrivate)
    local key = self:CreateKey(playerName)
    local entry = ns.tblBlackList and ns.tblBlackList[key] or nil
    
    if not entry then
        if ns.Logger then
            ns.Logger:Error("Cannot update reason: player %s is not blacklisted", playerName)
        end
        return false
    end
    
    -- Only allow the person who blacklisted them to update (unless GM)
    if entry.blBy ~= UnitName('player') and not ns.isGM then
        if ns.Logger then
            ns.Logger:Error("Cannot update reason: you did not blacklist this player")
        end
        return false
    end
    
    entry.reason = newReason or entry.reason
    entry.private = isPrivate ~= nil and isPrivate or entry.private
    entry.lastModified = time()
    entry.modifiedBy = UnitName('player')
    
    -- Save to database
    if ns.Database and ns.Database.SaveCompressedData then
        ns.Database:SaveCompressedData('blackList', ns.tblBlackList)
    end
    
    if ns.Logger then
        ns.Logger:Info("Updated blacklist reason for %s", playerName)
    end
    
    -- Clear cache
    if self.cache then
        self.cache:Remove(key)
    end
    
    return true
end

function BlacklistManager:TogglePrivate(playerName)
    local entry = self:GetEntry(playerName)
    if not entry then return false end
    
    return self:UpdateReason(playerName, entry.reason, not entry.private)
end

function BlacklistManager:GetSortedList()
    local sorted = {}
    
    if ns.tblBlackList then
        for key, entry in pairs(ns.tblBlackList) do
            table.insert(sorted, entry)
        end
        
        table.sort(sorted, function(a, b)
            return strlower(a.name) < strlower(b.name)
        end)
    end
    
    return sorted
end

function BlacklistManager:CreateKey(playerName)
    return strlower(playerName:match('-') and playerName or playerName..'-'..GetRealmName())
end

function BlacklistManager:ManualBlacklist(playerName, reason, showDialog)
    if showDialog then
        -- Create a dialog for entering the reason
        local dialog = {
            text = reason or ("Enter reason for blacklisting " .. playerName),
            button1 = "Blacklist",
            button2 = "Cancel",
            OnAccept = function(self)
                local reason = self.editBox:GetText()
                BlacklistManager:Add(playerName, reason, false)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            hasEditBox = true,
            editBoxWidth = 250,
        }
        
        StaticPopup_Show("FGR_BLACKLIST_REASON", playerName, nil, dialog)
    else
        return self:Add(playerName, reason, false)
    end
end

function BlacklistManager:GetStatistics()
    local total = 0
    local byUser = {}
    local privateCount = 0
    
    if ns.tblBlackList then
        for _, entry in pairs(ns.tblBlackList) do
            total = total + 1
            
            byUser[entry.blBy] = (byUser[entry.blBy] or 0) + 1
            
            if entry.private then
                privateCount = privateCount + 1
            end
        end
    end
    
    return {
        total = total,
        byUser = byUser,
        privateCount = privateCount,
    }
end

-- Create the static popup for blacklist reasons
StaticPopupDialogs["FGR_BLACKLIST_REASON"] = {
    text = "Enter reason for blacklisting %s:",
    button1 = "Blacklist",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local reason = self.editBox:GetText()
        if data and data.OnAccept then
            data.OnAccept(self)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    hasEditBox = true,
    editBoxWidth = 250,
}

-- Initialize the blacklist manager
BlacklistManager:Initialize()