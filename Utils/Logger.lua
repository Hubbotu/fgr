-- Utils/Logger.lua
local addonName, ns = ...

ns.Logger = {}
local Logger = ns.Logger

local LOG_LEVELS = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
}

local LOG_LEVEL_NAMES = {
    [LOG_LEVELS.ERROR] = "ERROR",
    [LOG_LEVELS.WARN] = "WARN", 
    [LOG_LEVELS.INFO] = "INFO",
    [LOG_LEVELS.DEBUG] = "DEBUG",
}

-- Initialize immediately when the file loads
Logger.isInitialized = false

function Logger:Initialize()
    self.isInitialized = true
    return true
end

function Logger:Log(level, message, ...)
    -- Fallback to print if not fully initialized
    if not self.isInitialized then
        print(string.format("[FGR] " .. message, ...))
        return
    end
    
    -- Don't show debug messages unless debug mode is on
    if level == LOG_LEVELS.DEBUG and not (FGR and FGR.debug) then
        return
    end
    
    local formattedMessage = string.format(message, ...)
    local timestamp = date("%H:%M:%S")
    local levelName = LOG_LEVEL_NAMES[level] or "UNKNOWN"
    local fullMessage = string.format("[%s] [FGR-%s] %s", timestamp, levelName, formattedMessage)
    
    -- Color code based on level
    local color = (ns.Colors and ns.Colors.DEFAULT) or 'FF3EB9D8'
    if level == LOG_LEVELS.ERROR then
        color = (ns.Colors and ns.Colors.ERROR) or 'FFFF0000'
    elseif level == LOG_LEVELS.WARN then
        color = (ns.Colors and ns.Colors.WARNING) or 'FFFFFF00'
    elseif level == LOG_LEVELS.DEBUG then
        color = (ns.Colors and ns.Colors.DEBUG) or 'FFD845D8'
    end
    
    -- Only output to chat if settings allow or if settings aren't loaded yet
    local shouldShow = true
    if ns.pSettings and ns.pSettings.ui then
        shouldShow = ns.pSettings.ui.showAppMsgs
    end
    
    if shouldShow then
        if ns.Utils and ns.Utils.ColorText then
            print(ns.Utils:ColorText(color, fullMessage))
        else
            print("|c" .. color .. fullMessage .. "|r")
        end
    end
    
    -- Always log errors to default UI error frame
    if level == LOG_LEVELS.ERROR then
        UIErrorsFrame:AddMessage(formattedMessage, 1, 0, 0, 1)
    end
end

function Logger:Error(message, ...)
    self:Log(LOG_LEVELS.ERROR, message, ...)
end

function Logger:Warn(message, ...)
    self:Log(LOG_LEVELS.WARN, message, ...)
end

function Logger:Info(message, ...)
    self:Log(LOG_LEVELS.INFO, message, ...)
end

function Logger:Debug(message, ...)
    self:Log(LOG_LEVELS.DEBUG, message, ...)
end

-- Convenience method for backward compatibility with existing ns.code:fOut calls
function Logger:Output(message, color, forceShow)
    local shouldShow = forceShow
    if not shouldShow and ns.pSettings and ns.pSettings.ui then
        shouldShow = ns.pSettings.ui.showAppMsgs
    elseif not ns.pSettings then
        shouldShow = true -- Show by default if settings aren't loaded
    end
    
    if shouldShow then
        local colorCode = color or ((ns.Colors and ns.Colors.DEFAULT) or 'FF3EB9D8')
        if ns.Utils and ns.Utils.ColorText then
            print(ns.Utils:ColorText(colorCode, message))
        else
            print("|c" .. colorCode .. message .. "|r")
        end
    end
end

-- Safe logging functions that can be used before full initialization
function Logger:SafeError(message, ...)
    local msg = string.format("[FGR-ERROR] " .. message, ...)
    print("|cFFFF0000" .. msg .. "|r")
    UIErrorsFrame:AddMessage(msg, 1, 0, 0, 1)
end

function Logger:SafeInfo(message, ...)
    local msg = string.format("[FGR-INFO] " .. message, ...)
    print("|cFF3EB9D8" .. msg .. "|r")
end

-- Initialize the logger immediately
Logger:Initialize()