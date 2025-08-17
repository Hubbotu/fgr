-- Modules/UI/WindowManager.lua
local addonName, ns = ...

ns.WindowManager = {}
local WindowManager = ns.WindowManager

-- Registry of all addon windows
local registeredWindows = {}

function WindowManager:Initialize()
    if ns.Logger then
        ns.Logger:Debug("WindowManager initialized")
    end
end

-- Register a window with the manager
function WindowManager:RegisterWindow(windowId, frameObject, showMethod, hideMethod)
    registeredWindows[windowId] = {
        frame = frameObject,
        showMethod = showMethod,
        hideMethod = hideMethod,
        isOpen = false
    }
    
    if ns.Logger then
        ns.Logger:Debug("Registered window: %s", windowId)
    end
end

-- Show a window and hide all others
function WindowManager:ShowWindow(windowId)
    local targetWindow = registeredWindows[windowId]
    if not targetWindow then
        if ns.Logger then
            ns.Logger:Warn("Attempted to show unregistered window: %s", windowId)
        end
        return false
    end
    
    -- Close all other windows first
    for id, window in pairs(registeredWindows) do
        if id ~= windowId and window.isOpen then
            self:HideWindow(id)
        end
    end
    
    -- Show the target window
    if targetWindow.showMethod then
        targetWindow.showMethod()
    elseif targetWindow.frame and targetWindow.frame.Show then
        targetWindow.frame:Show()
    end
    
    targetWindow.isOpen = true
    
    print("|cFF3EB9D8[FGR]|r Opened: " .. windowId)
    return true
end

-- Hide a specific window
function WindowManager:HideWindow(windowId)
    local window = registeredWindows[windowId]
    if not window then
        return false
    end
    
    if window.hideMethod then
        window.hideMethod()
    elseif window.frame and window.frame.Hide then
        window.frame:Hide()
    end
    
    window.isOpen = false
    return true
end

-- Hide all windows
function WindowManager:HideAllWindows()
    for id, window in pairs(registeredWindows) do
        if window.isOpen then
            self:HideWindow(id)
        end
    end
end

-- Check if a window is open
function WindowManager:IsWindowOpen(windowId)
    local window = registeredWindows[windowId]
    return window and window.isOpen or false
end

-- Get list of open windows
function WindowManager:GetOpenWindows()
    local openWindows = {}
    for id, window in pairs(registeredWindows) do
        if window.isOpen then
            table.insert(openWindows, id)
        end
    end
    return openWindows
end

-- Toggle a window (show if hidden, hide if shown)
function WindowManager:ToggleWindow(windowId)
    if self:IsWindowOpen(windowId) then
        self:HideWindow(windowId)
    else
        self:ShowWindow(windowId)
    end
end
