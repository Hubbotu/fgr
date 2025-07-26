-- Modules/UI/Settings/Modules/Recruitment.lua
local addonName, ns = ...

ns.Settings.Modules.Recruitment = {}
local Recruitment = ns.Settings.Modules.Recruitment

function Recruitment:Initialize()
    -- Placeholder
end

function Recruitment:IsEnabled()
    return false -- Disabled for now
end

function Recruitment:GetConfigTable()
    return {
        name = "Recruitment (Coming Soon)",
        type = 'group',
        args = {
            placeholder = {
                order = 1,
                name = "Recruitment settings will be available in a future update.",
                type = 'description',
            }
        }
    }
end