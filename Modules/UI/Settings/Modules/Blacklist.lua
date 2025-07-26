-- Modules/UI/Settings/Modules/Blacklist.lua
local addonName, ns = ...

ns.Settings.Modules.Blacklist = {}
local Blacklist = ns.Settings.Modules.Blacklist

function Blacklist:Initialize()
    -- Placeholder
end

function Blacklist:IsEnabled()
    return false -- Disabled for now
end

function Blacklist:GetConfigTable()
    return {
        name = "Blacklist (Coming Soon)",
        type = 'group',
        args = {
            placeholder = {
                order = 1,
                name = "Blacklist settings will be available in a future update.",
                type = 'description',
            }
        }
    }
end