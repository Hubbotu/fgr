-- Modules/UI/Settings/Modules/Zones.lua
local addonName, ns = ...

ns.Settings.Modules.Zones = {}
local Zones = ns.Settings.Modules.Zones

function Zones:Initialize()
    -- Placeholder
end

function Zones:IsEnabled()
    return false -- Disabled for now
end

function Zones:GetConfigTable()
    return {
        name = "Zones (Coming Soon)",
        type = 'group',
        args = {
            placeholder = {
                order = 1,
                name = "Zone settings will be available in a future update.",
                type = 'description',
            }
        }
    }
end