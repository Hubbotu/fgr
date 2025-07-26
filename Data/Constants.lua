-- Data/Constants.lua
local addonName, ns = ...

-- Make sure namespace exists
ns = ns or {}

-- Addon Information
ns.ADDON_NAME = addonName
ns.ICON_PATH = 'Interface\\AddOns\\'..addonName..'\\Images\\'

-- Database
FGR = FGR or {}
FGR.commPrefix = 'FGRSync'
FGR.dbVersion = 5

-- Release Information
FGR.enableFilter = false
FGR.isPreRelease = false
FGR.preReleaseType = 'Beta'

-- Colors
ns.Colors = {
    GM = 'FFAF640C',
    DEBUG = 'FFD845D8',
    ERROR = 'FFFF0000',
    SYSTEM = 'FFFFFF40',
    DEFAULT = 'FF3EB9D8',
    SUCCESS = 'FF00FF00',
    WARNING = 'FFFFFF00',
}

-- Legacy color constants for backward compatibility
ns.COLOR_GM = ns.Colors.GM
ns.COLOR_DEBUG = ns.Colors.DEBUG
ns.COLOR_ERROR = ns.Colors.ERROR
ns.COLOR_SYSTEM = ns.Colors.SYSTEM
ns.COLOR_DEFAULT = ns.Colors.DEFAULT

-- Icons
ns.Icons = {
    MAIN = ns.ICON_PATH..'FGR_Icon',
    LOCKED = ns.ICON_PATH..'FGR_Locked',
    UNLOCKED = ns.ICON_PATH..'FGR_Unlocked',
    ABOUT = ns.ICON_PATH..'FGR_About',
    BACK = ns.ICON_PATH..'FGR_Back',
    BLACKLIST = ns.ICON_PATH..'FGR_Blacklist',
    FILTER = ns.ICON_PATH..'FGR_Filter',
    FILTER_COLOR = ns.ICON_PATH..'FGR_FilterColor',
    COMPACT = ns.ICON_PATH..'FGR_Compact',
    EXPAND = ns.ICON_PATH..'FGR_Expand',
    EXIT = ns.ICON_PATH..'FGR_Exit',
    EXIT_EMPTY = ns.ICON_PATH..'FGR_ExitEmpty',
    NEW = ns.ICON_PATH..'FGR_New',
    RESET = ns.ICON_PATH..'FGR_Reset',
    STATS = ns.ICON_PATH..'FGR_Stats',
    SYNC_ON = ns.ICON_PATH..'FGR_SyncOn',
    SYNC = ns.ICON_PATH..'FGR_Sync',
    SETTINGS = ns.ICON_PATH..'FGR_Settings',
}

-- Legacy icon constants
ns.FGR_ICON = ns.Icons.MAIN
ns.BUTTON_LOCKED = ns.Icons.LOCKED
ns.BUTTON_UNLOCKED = ns.Icons.UNLOCKED
ns.BUTTON_ABOUT = ns.Icons.ABOUT
ns.BUTTON_BACK = ns.Icons.BACK
ns.BUTTON_BLACKLIST = ns.Icons.BLACKLIST
ns.BUTTON_FILTER = ns.Icons.FILTER
ns.BUTTON_FILTER_COLOR = ns.Icons.FILTER_COLOR
ns.BUTTON_COMPACT = ns.Icons.COMPACT
ns.BUTTON_EXPAND = ns.Icons.EXPAND
ns.BUTTON_EXIT = ns.Icons.EXIT
ns.BUTTON_EXIT_EMPTY = ns.Icons.EXIT_EMPTY
ns.BUTTON_NEW = ns.Icons.NEW
ns.BUTTON_RESET = ns.Icons.RESET
ns.BUTTON_STATS = ns.Icons.STATS
ns.BUTTON_SYNC_ON = ns.Icons.SYNC_ON
ns.BUTTON_SYNC = ns.Icons.SYNC
ns.BUTTON_SETTINGS = ns.Icons.SETTINGS

-- Player Information
ns.PLAYER_PROFILE = UnitName('player')..'-'..GetRealmName()

-- Time Constants
ns.Time = {
    SECONDS_IN_DAY = 86400,
    SECONDS_IN_HOUR = 3600,
    SECONDS_IN_MINUTE = 60,
}

-- Legacy time constants
ns.SECONDS_IN_A_DAY = ns.Time.SECONDS_IN_DAY

-- UI Constants
ns.UI = {
    HIGHLIGHTS = {
        BLUE = 'bags-glow-heirloom',
        BLUE_LONG = 'communitiesfinder_card_highlight',
    },
    FONTS = {
        ARIAL = 'Fonts\\ARIAN.ttf',
        SKURRI = 'Fonts\\SKURRI.ttf',
        DEFAULT = 'Fonts\\FRIZQT__.ttf',
        MORPHEUS = 'Fonts\\MORPHEUS.ttf',
    },
    FONT_SIZE = {
        DEFAULT = 12,
        SMALL = 10,
        LARGE = 14,
    },
}

-- Legacy UI constants
ns.BLUE_HIGHLIGHT = ns.UI.HIGHLIGHTS.BLUE
ns.BLUE_LONG_HIGHLIGHT = ns.UI.HIGHLIGHTS.BLUE_LONG
ns.ARIAL_FONT = ns.UI.FONTS.ARIAL
ns.SKURRI_FONT = ns.UI.FONTS.SKURRI
ns.DEFAULT_FONT = ns.UI.FONTS.DEFAULT
ns.MORPHEUS_FONT = ns.UI.FONTS.MORPHEUS
ns.DEFAULT_FONT_SIZE = ns.UI.FONT_SIZE.DEFAULT

-- Enumerations
ns.Enums = {
    InviteFormat = {
        MESSAGE_ONLY = 1,
        GUILD_INVITE_ONLY = 2,
        GUILD_INVITE_AND_MESSAGE = 3,
        MESSAGE_ONLY_IF_INVITE_DECLINED = 4,
    },
    LogLevel = {
        ERROR = 1,
        WARN = 2,
        INFO = 3,
        DEBUG = 4,
    },
}

-- Legacy enumeration
ns.InviteFormat = ns.Enums.InviteFormat

-- External Links
ns.Links = {
    DISCORD = 'https://discord.gg/kEUCbfySZu',
    CURSE_FORGE = 'https://www.curseforge.com/wow/addons/fast-guild-recruiter',
    BUY_ME_COFFEE = 'https://coff.ee/patricnoxdev',
}

-- Legacy link constants
ns.DISCORD = ns.Links.DISCORD
ns.CURSE_FORGE = ns.Links.CURSE_FORGE
ns.BUY_ME_COFFEE = ns.Links.BUY_ME_COFFEE

-- Settings Categories and Modules - INITIALIZE MODULES TABLE
ns.Settings = {
    Categories = {
        GENERAL = 'general',
        RECRUITMENT = 'recruitment', 
        MESSAGES = 'messages',
        ANTI_SPAM = 'antiSpam',
        BLACKLIST = 'blacklist',
        ZONES = 'zones',
        ABOUT = 'about',
    },
    Modules = {} -- This was missing!
}

-- Register addon communication prefix (safe check)
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(FGR.commPrefix)
end

-- Set max character level safely
local function setMaxLevel()
    if GetMaxPlayerLevel then
        ns.MAX_CHARACTER_LEVEL = GetMaxPlayerLevel()
    else
        -- Fallback values for different expansions
        ns.MAX_CHARACTER_LEVEL = 80 -- Adjust based on current expansion
    end
end

-- Try to set max level, use fallback if API not available yet
local success, _ = pcall(setMaxLevel)
if not success then
    ns.MAX_CHARACTER_LEVEL = 80 -- Safe fallback
end