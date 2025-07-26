local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

ns.MessageTemplates = {}
local MessageTemplates = ns.MessageTemplates

-- Template variables and their replacements
local TEMPLATE_VARIABLES = {
    ['GUILDNAME'] = function() return ns.guildInfo.guildName or GetGuildInfo('player') or L['NO_GUILD_NAME'] end,
    ['GUILDLINK'] = function() return ns.guildInfo.guildLink or L['GUILD_LINK_NOT_FOUND'] end,
    ['PLAYERNAME'] = function(targetPlayer) return targetPlayer or UnitName('player') end,
    ['DATE'] = function() return date('%m/%d/%Y') end,
    ['TIME'] = function() return date('%H:%M') end,
    ['REALM'] = function() return GetRealmName() end,
    ['LEVEL'] = function() return UnitLevel('player') end,
}

function MessageTemplates:ProcessMessage(message, targetPlayer)
    if not message or message == '' then return '' end
    
    local processedMessage = message
    
    -- Replace each template variable
    for variable, replacementFunc in pairs(TEMPLATE_VARIABLES) do
        if processedMessage:find(variable) then
            local replacement = replacementFunc(targetPlayer)
            processedMessage = processedMessage:gsub(variable, replacement)
        end
    end
    
    return processedMessage
end

function MessageTemplates:ValidateMessage(message)
    if not message then return false, "Message is nil" end
    
    local length = string.len(message)
    if length > 255 then
        return false, "Message too long (" .. length .. "/255)"
    end
    
    if length == 0 then
        return false, "Message is empty"
    end
    
    return true, nil
end

function MessageTemplates:GetMessageLength(message, targetPlayer)
    if not message or message == '' then 
        return false, 0, message 
    end

    local processedMessage = self:ProcessMessage(message, targetPlayer or "SamplePlayer")
    local length = string.len(processedMessage)
    local playerNameFound = message:find('PLAYERNAME') ~= nil
    
    return playerNameFound, length, processedMessage
end

function MessageTemplates:GetVariableList()
    local variables = {}
    for variable, _ in pairs(TEMPLATE_VARIABLES) do
        table.insert(variables, variable)
    end
    table.sort(variables)
    return variables
end

function MessageTemplates:GetVariableDescription(variable)
    local descriptions = {
        ['GUILDNAME'] = L['VARIABLE_GUILDNAME_DESC'] or 'Inserts your guild name',
        ['GUILDLINK'] = L['VARIABLE_GUILDLINK_DESC'] or 'Inserts a clickable guild link (Retail only)',
        ['PLAYERNAME'] = L['VARIABLE_PLAYERNAME_DESC'] or 'Inserts the target player\'s name',
        ['DATE'] = L['VARIABLE_DATE_DESC'] or 'Inserts current date (MM/DD/YYYY)',
        ['TIME'] = L['VARIABLE_TIME_DESC'] or 'Inserts current time (HH:MM)',
        ['REALM'] = L['VARIABLE_REALM_DESC'] or 'Inserts your realm name',
        ['LEVEL'] = L['VARIABLE_LEVEL_DESC'] or 'Inserts your character level',
    }
    
    return descriptions[variable] or 'Unknown variable'
end

function MessageTemplates:CreateNewMessage()
    return {
        desc = '',
        message = '',
        gmSync = ns.isGM or false,
        created = time(),
        lastModified = time(),
    }
end

function MessageTemplates:CopyMessage(originalMessage)
    local newMessage = ns.Utils:DeepCopy(originalMessage)
    newMessage.desc = newMessage.desc .. ' (Copy)'
    newMessage.created = time()
    newMessage.lastModified = time()
    return newMessage
end

function MessageTemplates:GetInstructionsText()
    local instructions = {}
    
    if ns.classic then
        table.insert(instructions, L['MESSAGE_REPLACEMENT_INSTRUCTIONS_CLASSIC'])
    else
        table.insert(instructions, L['MESSAGE_REPLACEMENT_INSTRUCTIONS_PART_1'])
    end
    
    table.insert(instructions, L['MESSAGE_REPLACEMENT_INSTRUCTIONS_PART_2'])
    
    local text = table.concat(instructions, '\n')
    
    -- Color code the variables
    if not ns.classic then
        text = text:gsub('GUILDLINK', ns.Utils:ColorText('FFFFFF00', 'GUILDLINK'))
    end
    text = text:gsub('GUILDNAME', ns.Utils:ColorText('FFFFFF00', 'GUILDNAME'))
    text = text:gsub('PLAYERNAME', ns.Utils:ColorText('FFFFFF00', 'PLAYERNAME'))
    
    return text
end