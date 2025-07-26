-- Modules/UI/Settings/Modules/About.lua
local addonName, ns = ...

ns.Settings.Modules.About = {}
local About = ns.Settings.Modules.About

function About:Initialize()
    -- Placeholder
end

function About:IsEnabled()
    return true -- About is always enabled
end

function About:GetConfigTable()
    return {
        name = "About",
        type = 'group',
        args = {
            header = {
                order = 1,
                name = "Fast Guild Recruiter",
                type = 'header',
            },
            version = {
                order = 2,
                name = "Version: " .. (FGR.version or "Unknown"),
                type = 'description',
                fontSize = 'medium',
            },
            author = {
                order = 3,
                name = "Author: " .. (FGR.author or "Unknown"),
                type = 'description',
                fontSize = 'medium',
            },
            links = {
                order = 4,
                name = "Links",
                type = 'header',
            },
            discord = {
                order = 5,
                name = "Discord: " .. (ns.Links.DISCORD or ""),
                type = 'description',
            },
            curseforge = {
                order = 6,
                name = "CurseForge: " .. (ns.Links.CURSE_FORGE or ""),
                type = 'description',
            },
        }
    }
end