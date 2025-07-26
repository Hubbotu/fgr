-- Core/EventManager.lua
local addonName, ns = ...

ns.EventManager = {}
local EventManager = ns.EventManager

local eventHandlers = {}
local activeEvents = {}

function EventManager:Initialize()
    self.isInitialized = true
    if ns.Logger and ns.Logger.Debug then
        ns.Logger:Debug("EventManager initialized")
    end
end

function EventManager:RegisterHandler(event, handler, priority, module)
    priority = priority or 100
    module = module or "Unknown"
    
    if not eventHandlers[event] then
        eventHandlers[event] = {}
    end
    
    table.insert(eventHandlers[event], {
        handler = handler,
        priority = priority,
        module = module,
    })
    
    -- Sort by priority (lower number = higher priority)
    table.sort(eventHandlers[event], function(a, b)
        return a.priority < b.priority
    end)
    
    self:RegisterEvent(event)
    if ns.Logger and ns.Logger.Debug then
        ns.Logger:Debug("Registered handler for event %s (priority: %d, module: %s)", event, priority, module)
    end
end

function EventManager:RegisterEvent(event)
    if not activeEvents[event] then
        FGR:RegisterEvent(event, function(...)
            self:FireEvent(event, ...)
        end)
        activeEvents[event] = true
        if ns.Logger and ns.Logger.Debug then
            ns.Logger:Debug("Registered event: %s", event)
        end
    end
end

function EventManager:UnregisterEvent(event)
    if activeEvents[event] then
        FGR:UnregisterEvent(event)
        activeEvents[event] = nil
        if ns.Logger and ns.Logger.Debug then
            ns.Logger:Debug("Unregistered event: %s", event)
        end
    end
end

function EventManager:FireEvent(event, ...)
    local handlers = eventHandlers[event]
    if not handlers then return end
    
    for _, handlerData in ipairs(handlers) do
        local success, result = pcall(handlerData.handler, ...)
        if not success then
            if ns.Logger and ns.Logger.Error then
                ns.Logger:Error("Event handler failed for %s in module %s: %s", 
                    event, handlerData.module, tostring(result))
            end
        end
    end
end

function EventManager:StartBaseEvents()
    -- Register core events that the addon needs
    
    -- Guild roster updates
    self:RegisterHandler("GUILD_ROSTER_UPDATE", function()
        if ns.Logger and ns.Logger.Debug then
            ns.Logger:Debug("Guild roster updated")
        end
        -- Handle guild roster changes
    end, 10, "Core")
    
    -- Player level changes
    self:RegisterHandler("PLAYER_LEVEL_UP", function(level)
        if ns.Logger and ns.Logger.Info then
            ns.Logger:Info("Player leveled up to %d", level)
        end
        -- Update filters if needed
    end, 10, "Core")
    
    -- Zone changes
    self:RegisterHandler("ZONE_CHANGED_NEW_AREA", function()
        local zone = GetZoneText()
        if ns.Logger and ns.Logger.Debug then
            ns.Logger:Debug("Zone changed to: %s", zone)
        end
        -- Handle zone change logic
    end, 10, "Core")
    
    -- Chat events for whisper handling
    self:RegisterHandler("CHAT_MSG_WHISPER", function(message, sender)
        if ns.pSettings and ns.pSettings.recruitment and ns.pSettings.recruitment.showWhispers then
            if ns.Logger and ns.Logger.Debug then
                ns.Logger:Debug("Received whisper from %s: %s", sender, message)
            end
            -- Handle whisper logic
        end
    end, 10, "Chat")
    
    -- Club/Guild events
    self:RegisterHandler("CLUB_INVITATION_ADDED_FOR_SELF", function()
        if ns.Logger and ns.Logger.Debug then
            ns.Logger:Debug("Club invitation received")
        end
        -- Handle club invitation
    end, 10, "Guild")
    
    if ns.Logger and ns.Logger.Info then
        ns.Logger:Info("Base events registered")
    end
end

-- Initialize the event manager
EventManager:Initialize()