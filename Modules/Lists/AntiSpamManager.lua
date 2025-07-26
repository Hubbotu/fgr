-- Modules/Lists/AntiSpamManager.lua
local addonName, ns = ...
local L = LibStub and LibStub:GetLibrary("AceLocale-3.0", true)
if L then
    L = L:GetLocale(addonName, true)
end
L = L or {}

ns.AntiSpamManager = {}
local AntiSpamManager = ns.AntiSpamManager

function AntiSpamManager:Initialize()
    -- Create cache with fallback if Performance module isn't available
    if ns.Performance and ns.Performance.CreateCache then
        self.cache = ns.Performance:CreateCache(1000, 600) -- 10 minute cache
    else
        -- Simple fallback cache implementation
        self.cache = self:CreateSimpleCache()
        if ns.Logger and ns.Logger.Warn then
            ns.Logger:Warn("Performance module not available for AntiSpam, using simple cache")
        end
    end
    
    if ns.Logger and ns.Logger.Debug then
        ns.Logger:Debug("Anti-spam manager initialized")
    end
end

function AntiSpamManager:CreateSimpleCache()
    -- Simple cache fallback if Performance module isn't loaded
    local cache = {
        data = {},
        maxSize = 1000,
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
                if count >= 200 then break end -- Remove 200 entries
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

function AntiSpamManager:Add(playerName, contactTime)
    if not playerName or playerName == '' then
        if ns.Logger then
            ns.Logger:Error("Cannot add to anti-spam: no player name provided")
        end
        return false
    end
    
    local key = self:CreateKey(playerName)
    contactTime = contactTime or time()
    
    -- Initialize anti-spam table if it doesn't exist
    ns.tblAntiSpamList = ns.tblAntiSpamList or {}
    
    local antiSpamEntry = {
        key = key,
        name = playerName,
        time = contactTime,
        date = contactTime, -- For backward compatibility
    }
    
    ns.tblAntiSpamList[key] = antiSpamEntry
    
    -- Save to database
    if ns.Database and ns.Database.SaveCompressedData then
        ns.Database:SaveCompressedData('antiSpamList', ns.tblAntiSpamList)
    end
    
    if ns.Logger then
        ns.Logger:Debug("Added %s to anti-spam list", playerName)
    end
    
    -- Clear cache
    if self.cache then
        self.cache:Remove(key)
    end
    
    return true
end

function AntiSpamManager:Remove(playerName)
    local key = self:CreateKey(playerName)
    
    if not ns.tblAntiSpamList or not ns.tblAntiSpamList[key] then
        if ns.Logger then
            ns.Logger:Warn("Player %s is not in anti-spam list", playerName)
        end
        return false
    end
    
    -- Remove from anti-spam list
    ns.tblAntiSpamList[key] = nil
    
    -- Save to database
    if ns.Database and ns.Database.SaveCompressedData then
        ns.Database:SaveCompressedData('antiSpamList', ns.tblAntiSpamList)
    end
    
    if ns.Logger then
        ns.Logger:Info("Removed player from anti-spam list: %s", playerName)
    end
    
    -- Clear cache
    if self.cache then
        self.cache:Remove(key)
    end
    
    return true
end

function AntiSpamManager:IsInAntiSpam(playerName)
    local key = self:CreateKey(playerName)
    
    -- Check cache first
    if self.cache then
        local cached = self.cache:Get(key)
        if cached ~= nil then
            return cached.inList, cached.timeRemaining
        end
    end
    
    -- Check anti-spam list
    local entry = ns.tblAntiSpamList and ns.tblAntiSpamList[key] or nil
    local inList = false
    local timeRemaining = 0
    
    if entry then
        local currentTime = time()
        local antiSpamDays = self:GetAntiSpamDays()
        local timeDiff = currentTime - entry.time
        local maxTime = antiSpamDays * ns.Time.SECONDS_IN_DAY
        
        if timeDiff < maxTime then
            inList = true
            timeRemaining = maxTime - timeDiff
        else
            -- Entry is expired, remove it
            ns.tblAntiSpamList[key] = nil
            if ns.Database and ns.Database.SaveCompressedData then
                ns.Database:SaveCompressedData('antiSpamList', ns.tblAntiSpamList)
            end
        end
    end
    
    -- Cache the result
    if self.cache then
        self.cache:Set(key, {
            inList = inList,
            timeRemaining = timeRemaining
        })
    end
    
    return inList, timeRemaining
end

function AntiSpamManager:GetEntry(playerName)
    local key = self:CreateKey(playerName)
    return ns.tblAntiSpamList and ns.tblAntiSpamList[key] or nil
end

function AntiSpamManager:GetAntiSpamDays()
    -- Get anti-spam days from settings
    if ns.isGM and ns.gmSettings and ns.gmSettings.antiSpamDays then
        return ns.gmSettings.antiSpamDays
    elseif ns.gSettings and ns.gSettings.antiSpamDays then
        return ns.gSettings.antiSpamDays
    else
        return 7 -- Default to 7 days
    end
end

function AntiSpamManager:GetSortedList()
    local sorted = {}
    
    if ns.tblAntiSpamList then
        for key, entry in pairs(ns.tblAntiSpamList) do
            -- Check if entry is still valid
            local inList, timeRemaining = self:IsInAntiSpam(entry.name)
            if inList then
                entry.timeRemaining = timeRemaining
                table.insert(sorted, entry)
            end
        end
        
        table.sort(sorted, function(a, b)
            return a.time > b.time -- Most recent first
        end)
    end
    
    return sorted
end

function AntiSpamManager:CreateKey(playerName)
    return strlower(playerName:match('-') and playerName or playerName..'-'..GetRealmName())
end

function AntiSpamManager:CleanExpiredEntries()
    if not ns.tblAntiSpamList then return 0 end
    
    local currentTime = time()
    local antiSpamDays = self:GetAntiSpamDays()
    local maxTime = antiSpamDays * ns.Time.SECONDS_IN_DAY
    local removed = 0
    
    local toRemove = {}
    for key, entry in pairs(ns.tblAntiSpamList) do
        if entry and entry.time then
            local timeDiff = currentTime - entry.time
            if timeDiff >= maxTime then
                table.insert(toRemove, key)
            end
        end
    end
    
    for _, key in ipairs(toRemove) do
        ns.tblAntiSpamList[key] = nil
        removed = removed + 1
    end
    
    if removed > 0 then
        -- Save to database
        if ns.Database and ns.Database.SaveCompressedData then
            ns.Database:SaveCompressedData('antiSpamList', ns.tblAntiSpamList)
        end
        
        if ns.Logger then
            ns.Logger:Debug("Cleaned %d expired anti-spam entries", removed)
        end
        
        -- Clear cache since we made changes
        if self.cache then
            for _, key in ipairs(toRemove) do
                self.cache:Remove(key)
            end
        end
    end
    
    return removed
end

function AntiSpamManager:GetStatistics()
    local total = 0
    local expiringSoon = 0 -- Within 24 hours
    local byDay = {}
    
    if ns.tblAntiSpamList then
        local currentTime = time()
        local oneDaySeconds = 86400
        
        for _, entry in pairs(ns.tblAntiSpamList) do
            local inList, timeRemaining = self:IsInAntiSpam(entry.name)
            if inList then
                total = total + 1
                
                if timeRemaining <= oneDaySeconds then
                    expiringSoon = expiringSoon + 1
                end
                
                -- Group by day added
                local dayKey = date("%Y-%m-%d", entry.time)
                byDay[dayKey] = (byDay[dayKey] or 0) + 1
            end
        end
    end
    
    return {
        total = total,
        expiringSoon = expiringSoon,
        byDay = byDay,
    }
end

function AntiSpamManager:FormatTimeRemaining(seconds)
    if not ns.Utils or not ns.Utils.FormatTime then
        -- Fallback time formatting
        if seconds < 3600 then
            return string.format("%.1fm", seconds / 60)
        elseif seconds < 86400 then
            return string.format("%.1fh", seconds / 3600)
        else
            return string.format("%.1fd", seconds / 86400)
        end
    else
        return ns.Utils:FormatTime(seconds)
    end
end

-- Initialize the anti-spam manager
AntiSpamManager:Initialize()