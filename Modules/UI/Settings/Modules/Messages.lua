-- Modules/UI/Settings/Modules/Messages.lua
local addonName, ns = ...

ns.Settings.Modules.Messages = {}
local Messages = ns.Settings.Modules.Messages

function Messages:Initialize()
    -- Placeholder
end

function Messages:IsEnabled()
    return false -- Disabled for now
end

function Messages:GetConfigTable()
    return {
        name = "Messages (Coming Soon)",
        type = 'group',
        args = {
            placeholder = {
                order = 1,
                name = "Message settings will be available in a future update.",
                type = 'description',
            }
        }
    }
end