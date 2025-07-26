local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

ns.Migration = {}
local Migration = ns.Migration

function Migration:MigrateDatabase(db)
    local currentVersion = db.global.version or 0
    local success = true
    
    ns.Logger:Info("Starting database migration from version %d to %d", currentVersion, 1)
   
    return success
end
