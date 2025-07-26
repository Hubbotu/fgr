-- Modules/UI/Settings/Modules/AntiSpam.lua
local addonName, ns = ...

ns.Settings.Modules.AntiSpam = {}
local AntiSpam = ns.Settings.Modules.AntiSpam

function AntiSpam:Initialize()
    -- Placeholder
end

function AntiSpam:IsEnabled()
    return false -- Disabled for now
end

function AntiSpam:GetConfigTable()
    return {
        name = "Anti-Spam (Coming Soon)",
        type = 'group',
        args = {
            placeholder = {
                order = 1,
                name = "Anti-spam settings will be available in a future update.",
                type = 'description',
            }
        }
    }
end