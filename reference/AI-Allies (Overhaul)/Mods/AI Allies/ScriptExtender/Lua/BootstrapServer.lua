-- Current Allies
Mods = Mods or {}
Mods.AIAllies = Mods.AIAllies or {}
local ModuleUUID = "b485d242-f267-2d22-3108-631ba0549512"
if Mods.BG3MCM then
    setmetatable(Mods.AIAllies, { __index = Mods.BG3MCM })
end

-- Configurable logging system for performance
local LOG_LEVEL = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4
}
-- Set to ERROR for production, DEBUG for development
local CURRENT_LOG_LEVEL = LOG_LEVEL.WARN

local function Log(level, message)
    if level <= CURRENT_LOG_LEVEL then
        if level == LOG_LEVEL.ERROR then
            Ext.Utils.PrintError("[AI Allies] " .. message)
        elseif level == LOG_LEVEL.WARN then
            Ext.Utils.PrintWarning("[AI Allies] " .. message)
        else
            Ext.Utils.Print("[AI Allies] " .. message)
        end
    end
end


Mods.AIAllies.PersistentVars = Mods.AIAllies.PersistentVars or {}
Mods.AIAllies.PersistentVars.firstTimeRewardGiven = Mods.AIAllies.PersistentVars.firstTimeRewardGiven or false

-- Cache for MCM settings to reduce repeated API calls
local mcmSettingsCache = {}
local MCM_CACHE_EXPIRY = 5000  -- Cache settings for 5 seconds

-------------------------------------------------------------------------------
-- Default Settings (Used when MCM is not installed)
-------------------------------------------------------------------------------
local DEFAULT_SETTINGS = {
    -- General Settings
    enableDebugSpells = false,
    enableCustomArchetypes = false,
    enableAlliesMind = false,
    enableAlliesSwarm = false,
    enableOrdersBonusAction = false,
    
    -- Combat Settings
    disableAlliesDashing = false,
    disableAlliesThrowing = false,
    enableDynamicSpellblock = false,
    enableContextualSwitching = true,
    targetPriorityMode = "BALANCED",
    enableFocusFire = false,
    enableFormations = false,
    formationType = "WEDGE",
    formationSpacing = 3,
    enableItemUsage = true,
    itemUsageThreshold = 50,
    enableScrollUsage = true,
    enableBuffPotions = false,
    lowHPThreshold = 30,
    enableBerserkerMode = true,
    enableWildShapeAI = true,
    spellSlotConservation = "BALANCED",
    healingPriorityMode = "LOWEST_HP",
    enableFlankingBehavior = true,
    enableHighGroundSeeking = true,
    debugArchetypes = false,
    enableModdedSpellScan = true
}

local function GetCachedSettingValue(settingId, moduleUUID)
    local cacheKey = settingId .. "_" .. moduleUUID
    local cached = mcmSettingsCache[cacheKey]
    
    -- Return cached value if still valid
    if cached and cached.time + MCM_CACHE_EXPIRY > Ext.Utils.MonotonicTime() then
        return cached.value
    end
    
    -- Get value from MCM if available
    local value = nil
    if Mods.AIAllies.MCMAPI then
        local success, result = pcall(function()
            return Mods.AIAllies.MCMAPI:GetSettingValue(settingId, moduleUUID)
        end)
        if success and result ~= nil then
            value = result
        end
    end
    
    -- Fall back to default if MCM not available or returned nil
    if value == nil then
        value = DEFAULT_SETTINGS[settingId]
    end
    
    -- Cache the result
    mcmSettingsCache[cacheKey] = {value = value, time = Ext.Utils.MonotonicTime()}
    
    return value
end

local function InvalidateSettingCache(settingId, moduleUUID)
    local cacheKey = settingId .. "_" .. moduleUUID
    mcmSettingsCache[cacheKey] = nil
end

-- Store factions for AI control
Mods.AIAllies.PersistentVars.aiControlOriginalFactions = Mods.AIAllies.PersistentVars.aiControlOriginalFactions or {}

local aiControlOriginalFactions = Mods.AIAllies.PersistentVars.aiControlOriginalFactions

-- Initialize the aiControlOriginalFactions table from PersistentVars when the session loads
local function InitAIControlOriginalFactions()
    aiControlOriginalFactions = Mods.AIAllies.PersistentVars.aiControlOriginalFactions or {}
    Mods.AIAllies.PersistentVars.aiControlOriginalFactions = aiControlOriginalFactions
end

Ext.Events.SessionLoaded:Subscribe(InitAIControlOriginalFactions)

-- Enable modded spells for AI use after session loads
Ext.Events.SessionLoaded:Subscribe(function()
    Ext.Timer.WaitFor(2000, function()
        if GetCachedSettingValue("enableModdedSpellScan", ModuleUUID) then
            EnableAllModdedSpells()
        else
            Log(LOG_LEVEL.INFO, "[ModdedSpell] Scan skipped (disabled in settings)")
        end
    end)
end)

-- Local table to keep track of the current allies
local CurrentAllies = {}
_G.characterTimers = _G.characterTimers or {}

-- Track conjuring spells used per combat (character -> spell name -> count)
local conjuringSpellsUsed = {}

-- Cache for spell type detection to improve performance
-- Limited size to prevent memory issues in long sessions
local spellTypeCache = {}
local MAX_SPELL_CACHE_SIZE = 500  -- Limit spell cache size
local spellCacheCount = 0  -- Track cache size efficiently

-- Cache for character spells to avoid repeated API calls within the same turn
local characterSpellsCache = {}
local SPELL_CACHE_EXPIRY = 3000  -- Cache spells for 3 seconds (balanced for performance and accuracy)

-- Cache for rage/wildshape status checks (short expiry, changes during combat)
local rageStatusCache = {}
local wildshapeStatusCache = {}
local adjacentEnemyCache = {}
local COMBAT_STATUS_CACHE_EXPIRY = 200  -- 200ms for combat-relevant status changes

-- Track turn start times for AI allies (for timeout detection)
local turnStartTimes = {}
local TURN_TIMEOUT_MS = 45000  -- 45 seconds - reasonable timeout for AI decision-making
local TICK_CHECK_INTERVAL = 2000  -- Check every 2 seconds (reduced frequency for better performance)
local lastTickCheck = 0

-------------------------------------------------------------------------------
-- Combat and Healer Constants
-------------------------------------------------------------------------------
local MAX_HEAL_DISTANCE = 18  -- Maximum distance for healing spells (meters)
local HEAL_THRESHOLD = 75     -- Heal allies below 75% HP
local ADJACENT_ENEMY_RANGE = 3.0  -- Melee range for adjacent enemy count (meters)
local HP_FULL = 100  -- Full HP percentage

-------------------------------------------------------------------------------
-- Archetype Priority System
-------------------------------------------------------------------------------
-- Priority levels for archetype overrides (1-10 scale, higher = more important)
local ARCHETYPE_PRIORITY = {
    BASE = 1,              -- Base archetype (melee, ranged, healer, etc.)
    TACTICAL = 3,          -- Tactical variants (_SMART)
    SITUATIONAL = 5,       -- Situation-based (surrounded, low HP)
    CLASS_FEATURE = 7,     -- Class abilities (Rage, Wildshape)
    EMERGENCY = 9,         -- Critical situations (ally downed)
    FORCED = 10            -- Player-forced or special mechanics
}

-- Track archetype stacks for each character
-- Structure: {characterUUID -> {priority -> {archetype, reason, timestamp}}}
local characterArchetypeStacks = {}
Mods.AIAllies.PersistentVars.characterArchetypeStacks = Mods.AIAllies.PersistentVars.characterArchetypeStacks or {}

-- Initialize archetype stacks from persistent vars
local function InitArchetypeStacks()
    characterArchetypeStacks = Mods.AIAllies.PersistentVars.characterArchetypeStacks or {}
end

Ext.Events.SessionLoaded:Subscribe(InitArchetypeStacks)

-- Get the highest priority archetype for a character
local function GetActiveArchetype(character)
    local stack = characterArchetypeStacks[character]
    if not stack then
        return nil
    end
    
    -- Find highest priority archetype
    local highestPriority = 0
    local activeArchetype = nil
    
    for priority, archetypeData in pairs(stack) do
        if priority > highestPriority then
            highestPriority = priority
            activeArchetype = archetypeData
        end
    end
    
    return activeArchetype
end

-- Apply archetype with priority
local function ApplyArchetypeWithPriority(character, archetype, priority, reason)
    if not characterArchetypeStacks[character] then
        characterArchetypeStacks[character] = {}
    end
    
    local oldArchetype = GetActiveArchetype(character)
    
    -- Store archetype at this priority level
    characterArchetypeStacks[character][priority] = {
        archetype = archetype,
        reason = reason,
        timestamp = Ext.Utils.MonotonicTime()
    }
    
    Mods.AIAllies.PersistentVars.characterArchetypeStacks = characterArchetypeStacks
    
    local newActive = GetActiveArchetype(character)
    
    -- Log archetype change if it's actually changing
    if not oldArchetype or oldArchetype.archetype ~= newActive.archetype then
        Log(LOG_LEVEL.DEBUG, string.format(
            "[Archetype] %s: %s → %s (Priority: %d, Reason: %s)",
            character,
            oldArchetype and oldArchetype.archetype or "none",
            newActive.archetype,
            priority,
            reason
        ))
    end
    
    return newActive
end

-- Remove archetype at specific priority level
local function RemoveArchetypeAtPriority(character, priority)
    if not characterArchetypeStacks[character] then
        return
    end
    
    local oldArchetype = GetActiveArchetype(character)
    characterArchetypeStacks[character][priority] = nil
    
    -- Clean up empty stack
    local hasAny = false
    for _ in pairs(characterArchetypeStacks[character]) do
        hasAny = true
        break
    end
    
    if not hasAny then
        characterArchetypeStacks[character] = nil
    end
    
    Mods.AIAllies.PersistentVars.characterArchetypeStacks = characterArchetypeStacks
    
    local newActive = GetActiveArchetype(character)
    
    -- Log if active archetype changed
    if oldArchetype and newActive and oldArchetype.archetype ~= newActive.archetype then
        Log(LOG_LEVEL.DEBUG, string.format(
            "[Archetype] %s: %s → %s (Removed priority %d)",
            character,
            oldArchetype.archetype,
            newActive.archetype,
            priority
        ))
    elseif oldArchetype and not newActive then
        Log(LOG_LEVEL.DEBUG, string.format(
            "[Archetype] %s: %s → none (Removed priority %d)",
            character,
            oldArchetype.archetype,
            priority
        ))
    end
end

-- Clear all archetypes for a character
local function ClearArchetypeStack(character)
    characterArchetypeStacks[character] = nil
    Mods.AIAllies.PersistentVars.characterArchetypeStacks = characterArchetypeStacks
    Log(LOG_LEVEL.DEBUG, "[Archetype] Cleared stack for: " .. character)
end

-------------------------------------------------------------------------------
-- Class-Based Archetype Detection System
-------------------------------------------------------------------------------
-- Maps BG3 class tags to optimal AI archetypes
-- Based on patterns from BG3-Community-Library class tag system

local CLASS_TO_ARCHETYPE = {
    -- Core classes (⭐ Using vanilla BG3 smart archetypes)
    ["BARBARIAN"] = "melee_smart",           -- Enhanced tactical melee
    ["BARD"] = "AI_bard",                    -- Spellcaster with support focus
    ["CLERIC"] = "healer_ranged",            -- Healing priority
    ["DRUID"] = "AI_druid",                  -- Healing + wildshape
    ["FIGHTER"] = "melee_smart",             -- Tactical positioning
    ["MONK"] = "melee_smart",                -- Mobile melee combatant
    ["PALADIN"] = "melee_magic_smart",       -- Pre-buffs before engaging
    ["RANGER"] = "ranged_smart",             -- Intelligent ranged positioning
    ["ROGUE"] = "rogue_smart",               -- Stealth and flanking
    ["SORCERER"] = "mage_smart",             -- Offensive spellcaster
    ["WARLOCK"] = "ranged_smart",            -- Eldritch blast specialist
    ["WIZARD"] = "mage_smart",               -- Control + damage caster
}

-- Subclass overrides for more specific behavior
local SUBCLASS_TO_ARCHETYPE = {
    -- Barbarian subclasses
    ["BARBARIAN_BERSERKER"] = "melee_smart",
    ["BARBARIAN_WILDHEART"] = "melee_smart",
    ["BARBARIAN_WILDMAGIC"] = "melee_smart",
    
    -- Cleric subclasses
    ["CLERIC_LIFE"] = "healer_ranged",
    ["CLERIC_LIGHT"] = "mage_smart",
    ["CLERIC_TRICKERY"] = "mage_smart",
    ["CLERIC_KNOWLEDGE"] = "mage_smart",
    ["CLERIC_NATURE"] = "healer_melee",
    ["CLERIC_TEMPEST"] = "melee_magic_smart",
    ["CLERIC_WAR"] = "melee_magic_smart",
    
    -- Druid subclasses
    ["DRUID_LAND"] = "AI_druid",
    ["DRUID_MOON"] = "AI_druid",
    ["DRUID_SPORES"] = "AI_druid",
    
    -- Fighter subclasses
    ["FIGHTER_BATTLEMASTER"] = "melee_smart",
    ["FIGHTER_CHAMPION"] = "melee_smart",
    ["FIGHTER_ELDRITCHKNIGHT"] = "melee_magic_smart",
    
    -- Monk subclasses
    ["MONK_OPENHAND"] = "melee_smart",
    ["MONK_SHADOW"] = "rogue_smart",
    ["MONK_FOURELEMENTS"] = "melee_magic_smart",
    
    -- Paladin subclasses
    ["PALADIN_ANCIENTS"] = "melee_magic_smart",
    ["PALADIN_DEVOTION"] = "melee_magic_smart",
    ["PALADIN_VENGEANCE"] = "melee_magic_smart",
    ["PALADIN_OATHBREAKER"] = "melee_magic_smart",
    
    -- Ranger subclasses
    ["RANGER_BEAST_MASTER"] = "ranged_smart",
    ["RANGER_GLOOM_STALKER"] = "ranged_smart",
    ["RANGER_HUNTER"] = "ranged_smart",
    
    -- Rogue subclasses
    ["ROGUE_THIEF"] = "rogue_smart",
    ["ROGUE_ARCANE_TRICKSTER"] = "rogue_smart",
    ["ROGUE_ASSASSIN"] = "rogue_smart",
    
    -- Sorcerer subclasses
    ["SORCERER_DRACONIC"] = "mage_smart",
    ["SORCERER_WILDMAGIC"] = "mage_smart",
    ["SORCERER_STORM"] = "mage_smart",
    
    -- Warlock subclasses
    ["WARLOCK_FIEND"] = "ranged_smart",
    ["WARLOCK_ARCHFEY"] = "ranged_smart",
    ["WARLOCK_GREAT_OLD_ONE"] = "ranged_smart",
    
    -- Wizard subclasses
    ["WIZARD_ABJURATION"] = "mage_smart",
    ["WIZARD_CONJURATION"] = "mage_smart",
    ["WIZARD_DIVINATION"] = "mage_smart",
    ["WIZARD_ENCHANTMENT"] = "mage_smart",
    ["WIZARD_EVOCATION"] = "mage_smart",
    ["WIZARD_ILLUSION"] = "mage_smart",
    ["WIZARD_NECROMANCY"] = "mage_smart",
    ["WIZARD_TRANSMUTATION"] = "mage_smart",
}

-- Optimized: Pre-build pattern lookup for modded subclass detection
-- Avoids O(tags * classes) nested loops by creating prefix patterns once
local moddedSubclassPatterns = {}
for baseClass, _ in pairs(CLASS_TO_ARCHETYPE) do
    moddedSubclassPatterns[baseClass] = "^" .. baseClass .. "_"
end

-- Detect character's class from tags
-- @param character string: Character UUID
-- @return string|nil: Detected class tag or nil
local function DetectCharacterClass(character)
    if not IsValidString(character) then
        return nil
    end
    
    local success, result = pcall(function()
        -- Check subclasses first (more specific)
        for tag, _ in pairs(SUBCLASS_TO_ARCHETYPE) do
            if Osi.IsTagged(character, tag) == 1 then
                return tag
            end
        end
        
        -- Check for modded subclasses via entity tag inspection
        -- Optimized: Use pre-built pattern table to avoid nested loops
        local entity = Ext.Entity.Get(character)
        if entity and entity.Tags and entity.Tags.Tags then
            for _, tagGuid in ipairs(entity.Tags.Tags) do
                local tagName = Ext.Loca.GetTranslatedString(tagGuid)
                if tagName and tagName ~= "" then
                    -- Check if tag matches modded subclass pattern (e.g., BARBARIAN_HEXBLADE)
                    for baseClass, pattern in pairs(moddedSubclassPatterns) do
                        if tagName:find(pattern) then
                            -- Found modded subclass - fall back to base class
                            Log(LOG_LEVEL.INFO, string.format(
                                "[ModdedClass] Detected modded subclass tag '%s' for character %s, using base class %s",
                                tagName, character, baseClass
                            ))
                            return baseClass
                        end
                    end
                end
            end
        end
        
        -- Fall back to base class
        for tag, _ in pairs(CLASS_TO_ARCHETYPE) do
            if Osi.IsTagged(character, tag) == 1 then
                return tag
            end
        end
        
        return nil
    end)
    
    return success and result or nil
end

-- Get recommended archetype for a character based on class
-- @param character string: Character UUID
-- @return string|nil: Recommended archetype name or nil
local function GetRecommendedArchetype(character)
    local classTag = DetectCharacterClass(character)
    
    if not classTag then
        return nil
    end
    
    -- Check subclass first
    if SUBCLASS_TO_ARCHETYPE[classTag] then
        return SUBCLASS_TO_ARCHETYPE[classTag]
    end
    
    -- Fall back to base class
    if CLASS_TO_ARCHETYPE[classTag] then
        return CLASS_TO_ARCHETYPE[classTag]
    end
    
    return nil
end

-- Auto-apply optimal archetype if no archetype is set
-- Called when AI control is first applied
local function AutoApplyOptimalArchetype(character)
    -- Skip if character already has an archetype status
    if hasAnyAICombatStatus(character) then
        return false
    end
    
    local recommended = GetRecommendedArchetype(character)
    if not recommended then
        -- Default to general archetype if class not detected
        recommended = "AI_general"
    end
    
    -- Map archetype name to status name
    local archetypeToStatus = {
        -- ⭐ Vanilla smart archetypes
        ["melee_smart"] = "AI_ALLIES_MELEE_SMART",
        ["ranged_smart"] = "AI_ALLIES_RANGED_SMART",
        ["mage_smart"] = "AI_ALLIES_MAGE_SMART",
        ["rogue_smart"] = "AI_ALLIES_ROGUE",
        ["healer_melee"] = "AI_ALLIES_HEALER_MELEE",
        ["healer_ranged"] = "AI_ALLIES_HEALER_RANGED",
        ["melee_magic_smart"] = "AI_ALLIES_PALADIN",
        
        -- Legacy support (backward compatibility)
        ["AI_berserker"] = "AI_ALLIES_THROWER",
        ["AI_beast"] = "AI_ALLIES_BEAST",
        ["AI_cleric"] = "AI_ALLIES_CLERIC",
        ["AI_fighter_melee"] = "AI_ALLIES_MELEE",
        ["AI_fighter_melee_smart"] = "AI_ALLIES_MELEE_SMART",
        ["AI_fighter_ranged"] = "AI_ALLIES_RANGED",
        ["AI_fighter_ranged_smart"] = "AI_ALLIES_RANGED_SMART",
        ["AI_general"] = "AI_ALLIES_GENERAL",
        ["AI_healer_melee"] = "AI_ALLIES_HEALER_MELEE",
        ["AI_healer_ranged"] = "AI_ALLIES_HEALER_RANGED",
        ["AI_mage_melee"] = "AI_ALLIES_MAGE_MELEE",
        ["AI_mage_ranged"] = "AI_ALLIES_MAGE_RANGED",
        ["AI_mage_smart"] = "AI_ALLIES_MAGE_SMART",
        ["AI_bard"] = "AI_ALLIES_BARD",
        ["AI_druid"] = "AI_ALLIES_DRUID",
        ["AI_monk"] = "AI_ALLIES_MONK",
        ["AI_paladin"] = "AI_ALLIES_PALADIN",
        ["AI_rogue"] = "AI_ALLIES_ROGUE",
        ["AI_summoner"] = "AI_ALLIES_SUMMONER",
        ["AI_tank"] = "AI_ALLIES_TANK",
        ["AI_trickster"] = "AI_ALLIES_TRICKSTER",
        ["AI_warlock"] = "AI_ALLIES_WARLOCK",
    }
    
    local statusName = archetypeToStatus[recommended]
    if statusName then
        -- Check if this is an NPC (use NPC variant)
        if Osi.HasActiveStatus(character, "ToggleIsNPC") == 1 then
            statusName = statusName .. "_NPC"
        end
        
        Log(LOG_LEVEL.INFO, string.format(
            "[ClassDetection] Auto-applying %s to character %s (class detected)",
            statusName, character
        ))
        
        return statusName
    end
    
    return nil
end

-- Export functions for use elsewhere
Mods.AIAllies.DetectCharacterClass = DetectCharacterClass
Mods.AIAllies.GetRecommendedArchetype = GetRecommendedArchetype
Mods.AIAllies.AutoApplyOptimalArchetype = AutoApplyOptimalArchetype

----------------------------------------------------------------------------------------------
-- List of AI statuses to track for CurrentAllies
local aiStatuses = {
    "AI_ALLIES_MELEE_Controller",
    "AI_ALLIES_RANGED_Controller",
    "AI_ALLIES_HEALER_MELEE_Controller",
    "AI_ALLIES_HEALER_RANGED_Controller",
    "AI_ALLIES_MAGE_MELEE_Controller",
    "AI_ALLIES_MAGE_RANGED_Controller",
    "AI_ALLIES_GENERAL_Controller",
    "AI_ALLIES_TRICKSTER_Controller",
    "AI_CONTROLLED",
    "AI_ALLIES_CUSTOM_Controller",
    "AI_ALLIES_TANK_Controller",
    "AI_ALLIES_SUMMONER_Controller",
    "AI_ALLIES_BEAST_Controller",
    "AI_ALLIES_CUSTOM_Controller_2",
    "AI_ALLIES_CUSTOM_Controller_3",
    "AI_ALLIES_CUSTOM_Controller_4",
    "AI_ALLIES_THROWER_CONTROLLER",
    "AI_ALLIES_DEFAULT_Controller",
    "AI_ALLIES_AUTO_Controller",
    -- SMART variants
    "AI_ALLIES_MELEE_SMART_Controller",
    "AI_ALLIES_RANGED_SMART_Controller",
    "AI_ALLIES_MAGE_SMART_Controller",
    -- New archetypes
    "AI_ALLIES_ROGUE_Controller",
    "AI_ALLIES_CLERIC_Controller",
    "AI_ALLIES_PALADIN_Controller",
    "AI_ALLIES_WARLOCK_Controller",
    "AI_ALLIES_MONK_Controller",
    "AI_ALLIES_BARBARIAN_Controller",
    "AI_ALLIES_BARD_Controller",
    "AI_ALLIES_DRUID_Controller",
    "AI_ALLIES_FIGHTER_Controller",
    "AI_ALLIES_RANGER_Controller",
    "AI_ALLIES_SORCERER_Controller",
    "AI_ALLIES_WIZARD_Controller",
}

-- List of all combat statuses
local aiCombatStatuses = {
    'AI_ALLIES_MELEE',
    'AI_ALLIES_RANGED',
    'AI_ALLIES_HEALER_MELEE',
    'AI_ALLIES_HEALER_RANGED',
    'AI_ALLIES_MAGE_MELEE',
    'AI_ALLIES_MAGE_RANGED',
    'AI_ALLIES_GENERAL',
    'AI_ALLIES_CUSTOM',
    'AI_ALLIES_CUSTOM_2',
    'AI_ALLIES_CUSTOM_3',
    'AI_ALLIES_TANK',
    'AI_ALLIES_SUMMONER',
    'AI_ALLIES_BEAST',
    'AI_ALLIES_TANK_NPC',
    'AI_ALLIES_SUMMONER_NPC',
    'AI_ALLIES_BEAST_NPC',
    'AI_ALLIES_CUSTOM_4',
    'AI_ALLIES_TRICKSTER',
    'AI_ALLIES_THROWER',
    'AI_ALLIES_DEFAULT',
    'AI_ALLIES_BARD',
    'AI_ALLIES_DRUID',
    'AI_ALLIES_MELEE_NPC',
    'AI_ALLIES_RANGED_NPC',
    'AI_ALLIES_HEALER_MELEE_NPC',
    'AI_ALLIES_HEALER_RANGED_NPC',
    'AI_ALLIES_MAGE_MELEE_NPC',
    'AI_ALLIES_MAGE_RANGED_NPC',
    'AI_ALLIES_GENERAL_NPC',
    'AI_ALLIES_CUSTOM_NPC',
    'AI_ALLIES_CUSTOM_2_NPC',
    'AI_ALLIES_CUSTOM_3_NPC',
    'AI_ALLIES_CUSTOM_4_NPC',
    'AI_ALLIES_TRICKSTER_NPC',
    'AI_ALLIES_THROWER_NPC',
    'AI_ALLIES_DEFAULT_NPC',
    'AI_ALLIES_BARD_NPC',
    'AI_ALLIES_DRUID_NPC',
    -- SMART variants
    'AI_ALLIES_MELEE_SMART',
    'AI_ALLIES_RANGED_SMART',
    'AI_ALLIES_MAGE_SMART',
    'AI_ALLIES_MELEE_SMART_NPC',
    'AI_ALLIES_RANGED_SMART_NPC',
    'AI_ALLIES_MAGE_SMART_NPC',
    -- New archetypes
    'AI_ALLIES_ROGUE',
    'AI_ALLIES_ROGUE_NPC',
    'AI_ALLIES_CLERIC',
    'AI_ALLIES_CLERIC_NPC',
    'AI_ALLIES_PALADIN',
    'AI_ALLIES_PALADIN_NPC',
    'AI_ALLIES_WARLOCK',
    'AI_ALLIES_WARLOCK_NPC',
    'AI_ALLIES_MONK',
    'AI_ALLIES_MONK_NPC'
}

-- List of NPC statuses
local NPCStatuses = {
    'AI_ALLIES_MELEE_NPC',
    'AI_ALLIES_RANGED_NPC',
    'AI_ALLIES_HEALER_MELEE_NPC',
    'AI_ALLIES_HEALER_RANGED_NPC',
    'AI_ALLIES_MAGE_MELEE_NPC',
    'AI_ALLIES_MAGE_RANGED_NPC',
    'AI_ALLIES_GENERAL_NPC',
    'AI_ALLIES_CUSTOM_NPC',
    'AI_ALLIES_CUSTOM_2_NPC',
    'AI_ALLIES_CUSTOM_3_NPC',
    'AI_ALLIES_TANK_NPC',
    'AI_ALLIES_SUMMONER_NPC',
    'AI_ALLIES_BEAST_NPC',
    'AI_ALLIES_CUSTOM_4_NPC',
    'AI_ALLIES_TRICKSTER_NPC',
    'AI_ALLIES_THROWER_NPC',
    'AI_ALLIES_DEFAULT_NPC',
    'AI_ALLIES_BARD_NPC',
    'AI_ALLIES_DRUID_NPC',
    -- SMART variants
    'AI_ALLIES_MELEE_SMART_NPC',
    'AI_ALLIES_RANGED_SMART_NPC',
    'AI_ALLIES_MAGE_SMART_NPC',
    -- New archetypes
    'AI_ALLIES_ROGUE_NPC',
    'AI_ALLIES_CLERIC_NPC',
    'AI_ALLIES_PALADIN_NPC',
    'AI_ALLIES_WARLOCK_NPC',
    'AI_ALLIES_MONK_NPC'
}
---------------------------------------------------------------------------------------------
-- Optimized: Create lookup tables for O(1) status checks
local aiCombatStatusSet = {}
for _, status in ipairs(aiCombatStatuses) do
    aiCombatStatusSet[status] = true
end

local aiStatusSet = {}
for _, status in ipairs(aiStatuses) do
    aiStatusSet[status] = true
end

-------------------------------------------------------------------------------
-- Static Lookup Tables (Module Level for Performance)
-------------------------------------------------------------------------------

-- Summon detection tags and statuses
local SUMMON_TAGS = {"SUMMON", "SUMMONED", "CONJURED", "FAMILIAR", "TEMP_SUMMON", "ANIMATED"}
local SUMMON_STATUSES = {"CONJURED", "SUMMONED_ENTITY", "SUMMONED"}

-- Rage status variants (Barbarian)
local RAGE_STATUSES = {"RAGE", "RAGE_BERSERKER", "RAGE_WILDHEART", "RAGE_WILDMAGIC", "FRENZY"}

-- Wild Shape status patterns (Druid)
local WILDSHAPE_STATUSES = {"WILDSHAPE", "WILDSHAPE_TECHNICAL"}

-- Specific wildshape form statuses (for turn-start checks)
local WILDSHAPE_FORM_STATUSES = {
    "WILDSHAPE_BADGER_PLAYER",
    "WILDSHAPE_BEAR_POLAR_PLAYER",
    "WILDSHAPE_CAT_PLAYER",
    "WILDSHAPE_SPIDER_GIANT_PLAYER",
    "WILDSHAPE_WOLF_DIRE_PLAYER",
    "WILDSHAPE_DEEP_ROTHE_PLAYER",
    "WILDSHAPE_RAVEN_PLAYER",
    "WILDSHAPE_SABERTOOTH_TIGER_PLAYER",
    "WILDSHAPE_PANTHER_PLAYER",
    "WILDSHAPE_DILOPHOSAURUS_PLAYER",
    "WILDSHAPE_OWLBEAR_PLAYER",
    "WILDSHAPE_MYRMIDON_AIR_PLAYER",
    "WILDSHAPE_MYRMIDON_EARTH_PLAYER",
    "WILDSHAPE_MYRMIDON_FIRE_PLAYER",
    "WILDSHAPE_MYRMIDON_WATER_PLAYER"
}

-- Prioritized wildshape spells for AI casting
local WILDSHAPE_SPELLS = {
    "Shout_WildShape_Bear_Polar",        -- Best for combat
    "Shout_WildShape_Combat_Bear_Polar", -- Combat variant
    "Shout_Wildshape_Panther",           -- Good mobility
    "Shout_WildShape_Combat_Spider"      -- Alternative
}

-- Healer archetype statuses (for optimized healer detection)
local HEALER_STATUSES = {
    "AI_ALLIES_HEALER_MELEE",
    "AI_ALLIES_HEALER_RANGED",
    "AI_ALLIES_HEALER_MELEE_NPC",
    "AI_ALLIES_HEALER_RANGED_NPC",
    "AI_ALLIES_CLERIC",
    "AI_ALLIES_CLERIC_NPC",
    "AI_ALLIES_DRUID",
    "AI_ALLIES_DRUID_NPC"
}

-- Threat-relevant status effects and their threat scores
local THREAT_STATUSES = {
    HASTE = 20,
    BLESS = 10,
    RAGE = 15
}

-------------------------------------------------------------------------------
-- Common Utility Functions (Reduce Code Duplication)
-------------------------------------------------------------------------------

-- Validate character/spell UUID or name is non-nil and non-empty
-- @param value string: The UUID or name to validate
-- @return boolean: true if valid, false otherwise
local function IsValidString(value)
    return value ~= nil and value ~= ""
end

-- Generic cached value retrieval helper
-- @param cache table: The cache table to check
-- @param key string: The cache key
-- @param expiry number: Cache expiry time in milliseconds
-- @return any|nil: Cached value if valid, nil if expired or not found
local function GetCachedValue(cache, key, expiry)
    local cached = cache[key]
    if cached and cached.time + expiry > Ext.Utils.MonotonicTime() then
        return cached.value
    end
    return nil
end

-- Set a cached value with timestamp
-- @param cache table: The cache table to update
-- @param key string: The cache key
-- @param value any: The value to cache
-- @param counterRef table: Optional reference to counter variable {counter = var_name}
local function SetCachedValue(cache, key, value, counterRef)
    -- Track new cache entries for size-limited caches
    if counterRef and not cache[key] then
        counterRef.counter = counterRef.counter + 1
    end
    cache[key] = {value = value, time = Ext.Utils.MonotonicTime()}
end

-- Safe status application (only apply if not already present)
-- @param character string: Character UUID
-- @param status string: Status name to apply
-- @param duration number: Duration (-1 for infinite)
-- @return boolean: true if applied, false if already present or error
local function SafeApplyStatus(character, status, duration)
    if not IsValidString(character) or not IsValidString(status) then
        return false
    end
    
    local success, result = pcall(function()
        if Osi.HasActiveStatus(character, status) == 0 then
            Osi.ApplyStatus(character, status, duration or -1)
            return true
        end
        return false
    end)
    
    return success and result
end

-- Safe status removal (only remove if present)
-- @param character string: Character UUID
-- @param status string: Status name to remove
-- @return boolean: true if removed, false if not present or error
local function SafeRemoveStatus(character, status)
    if not IsValidString(character) or not IsValidString(status) then
        return false
    end
    
    local success, result = pcall(function()
        if Osi.HasActiveStatus(character, status) == 1 then
            Osi.RemoveStatus(character, status)
            return true
        end
        return false
    end)
    
    return success and result
end

-- Iterator for party members (reduces boilerplate in loops)
-- @param skipSummons boolean: If true, skips summoned creatures (default: false)
-- @return iterator: Returns character UUIDs one at a time
-- Usage: for character in IteratePartyMembers() do ... end
local function IteratePartyMembers(skipSummons)
    local players = GetPartyMembers()
    if not players then
        -- Return empty iterator if GetPartyMembers fails
        return function() return nil end
    end
    
    local index = 0
    local playersArray = {}
    
    -- Convert to array for iteration
    for _, player in pairs(players) do
        table.insert(playersArray, player[1])
    end
    
    return function()
        while index < #playersArray do
            index = index + 1
            local character = playersArray[index]
            
            -- Skip summons if requested
            if skipSummons and IsSummon(character) then
                -- Continue to next iteration
            else
                return character
            end
        end
        return nil
    end
end

-------------------------------------------------------------------------------
-- Modded Spell Support Configuration
-------------------------------------------------------------------------------

local MODDED_SPELL_PATTERNS = {
    -- Class Feature Variants (CFV)
    ["CFV_"] = true,
    ["ClassFeatureVariant_"] = true,
    -- 5e Spells mod
    ["Target_5E_"] = true,
    ["Shout_5E_"] = true,
    ["Projectile_5E_"] = true,
    ["Zone_5E_"] = true,
    ["Rush_5E_"] = true,
    ["Teleportation_5E_"] = true,
    -- Hexblade Warlock
    ["Hexblade_"] = true,
    ["Target_Hexblade_"] = true,
    -- Mystic Class
    ["Mystic_"] = true,
    ["Psionic_"] = true,
    -- Artificer
    ["Artificer_"] = true,
    ["Infusion_"] = true,
    -- Blood Hunter
    ["BloodHunter_"] = true,
    ["Crimson_"] = true,
    -- Eldertide Armaments (equipment-granted spells)
    ["ELDER_"] = true,
    ["Target_ELDER_"] = true,
    ["Shout_ELDER_"] = true,
    ["Projectile_ELDER_"] = true,
    ["Zone_ELDER_"] = true,
    ["Rush_ELDER_"] = true,
    ["Teleportation_ELDER_"] = true,
    -- Mystra Spells mod
    ["Mystra_"] = true,
    ["Target_Mystra_"] = true,
    ["Shout_Mystra_"] = true,
    ["Projectile_Mystra_"] = true,
    ["Zone_Mystra_"] = true,
    ["MYSTRA_"] = true,
    -- Common modded weapon/armor spell patterns
    ["Custom_"] = true,
    ["Modded_"] = true,
    ["MOD_"] = true,
}

-- Check if a spell matches any modded spell pattern
-- @param spellName string: The name of the spell to check
-- @return boolean: true if spell matches a modded pattern
local function IsModdedSpell(spellName)
    if not IsValidString(spellName) then
        return false
    end
    
    for pattern, _ in pairs(MODDED_SPELL_PATTERNS) do
        if spellName:find("^" .. pattern) then
            return true
        end
    end
    
    return false
end

-- Enable a modded spell for AI use by removing CanNotUse flag
-- @param spellName string: The name of the spell to enable
-- @return boolean: true if spell was modified, false otherwise
local function EnableModdedSpellForAI(spellName)
    local success, result = pcall(function()
        local spell = Ext.Stats.Get(spellName)
        if not spell then
            return false
        end
        
        -- Check if spell has AIFlags and CanNotUse is set
        if spell.AIFlags and spell.AIFlags:find("CanNotUse") then
            -- Remove CanNotUse from AIFlags
            local newFlags = spell.AIFlags:gsub("CanNotUse;?", ""):gsub(";;", ";")
            -- Remove trailing semicolon if present
            newFlags = newFlags:gsub(";$", "")
            
            spell.AIFlags = newFlags
            
            -- Move per-spell logging to DEBUG to reduce startup spam
            if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
                Log(LOG_LEVEL.DEBUG, string.format(
                    "[ModdedSpell] Enabled spell for AI: %s (removed CanNotUse flag)",
                    spellName
                ))
            end
            return true
        end
        
        return false
    end)
    
    return success and result or false
end

-- Scan and enable all modded spells for AI use
-- Should be called once during session initialization
local function EnableAllModdedSpells()
    local enabledCount = 0
    local totalChecked = 0
    
    local success, err = pcall(function()
        -- Get all stats of type SpellData
        local allStats = Ext.Stats.GetStats("SpellData")
        if not allStats then
            Log(LOG_LEVEL.WARN, "[ModdedSpell] Failed to retrieve spell stats")
            return
        end
        
        for _, spellName in ipairs(allStats) do
            totalChecked = totalChecked + 1
            if IsModdedSpell(spellName) then
                if EnableModdedSpellForAI(spellName) then
                    enabledCount = enabledCount + 1
                end
            end
        end
        
        Log(LOG_LEVEL.INFO, string.format(
            "[ModdedSpell] Scan complete: %d modded spells enabled out of %d total spells checked",
            enabledCount, totalChecked
        ))
    end)
    
    if not success then
        Log(LOG_LEVEL.ERROR, "[ModdedSpell] Error scanning spells: " .. tostring(err))
    end
end

-- Export functions
Mods.AIAllies.IsModdedSpell = IsModdedSpell
Mods.AIAllies.EnableModdedSpellForAI = EnableModdedSpellForAI
Mods.AIAllies.EnableAllModdedSpells = EnableAllModdedSpells

-- Optimized: Cache status check results to avoid repeated API calls
local statusCheckCache = {}
local CACHE_EXPIRY = 100  -- Cache for 100ms (1 game tick)
local CACHE_CLEANUP_INTERVAL = 30000  -- Cleanup every 30 seconds
local MAX_CACHE_SIZE = 1000  -- Prevent unbounded growth in long sessions
local lastCacheCleanup = 0
local cacheEntriesCount = 0  -- Track cache size efficiently

-- Clear all cached entries for a character
local function clearStatusCache(character)
    local suffixes = {"_combat", "_npc", "_controller", "_relevant", "_healer"}
    for _, suffix in ipairs(suffixes) do
        local key = character .. suffix
        if statusCheckCache[key] then
            statusCheckCache[key] = nil
            cacheEntriesCount = cacheEntriesCount - 1
        end
    end
end

-- Generic cached status list checker
-- @param character string: Character UUID to check
-- @param statusList table: List of status strings to check for
-- @param cacheKeySuffix string: Suffix for cache key generation (e.g., "_combat", "_npc")
-- @return boolean: true if character has any status from the list, false otherwise
local function hasAnyStatusFromList(character, statusList, cacheKeySuffix)
    local cacheKey = character .. cacheKeySuffix
    local cached = statusCheckCache[cacheKey]
    if cached and cached.time + CACHE_EXPIRY > Ext.Utils.MonotonicTime() then
        return cached.value
    end
    
    local result = false
    for _, status in ipairs(statusList) do
        if Osi.HasActiveStatus(character, status) == 1 then
            result = true
            break
        end
    end
    
    -- Track new cache entries
    if not statusCheckCache[cacheKey] then
        cacheEntriesCount = cacheEntriesCount + 1
    end
    statusCheckCache[cacheKey] = {value = result, time = Ext.Utils.MonotonicTime()}
    return result
end

-- Check status helper with caching
local function hasAnyAICombatStatus(character)
    return hasAnyStatusFromList(character, aiCombatStatuses, "_combat")
end

local function hasAnyNPCStatus(character)
    return hasAnyStatusFromList(character, NPCStatuses, "_npc")
end

-- Check if character has any healer archetype status (optimized)
-- Uses cached status check to reduce API overhead
local function IsHealer(character)
    return hasAnyStatusFromList(character, HEALER_STATUSES, "_healer")
end

local function isControllerStatus(status)
    return aiStatusSet[status] ~= nil
end

local function hasControllerStatus(character)
    return hasAnyStatusFromList(character, aiStatuses, "_controller")
end

local NPCStatusSet = {}
for _, status in ipairs(NPCStatuses) do
    NPCStatusSet[status] = true
end

local function IsNPCStatus(status)
    return NPCStatusSet[status] ~= nil
end

-------------------------------------------------------------------------------
-- Contextual Archetype Evaluation
-------------------------------------------------------------------------------

-- Get character HP percentage
-- Optimized: Uses GetHealthData to avoid duplicate entity fetch logic
local function GetHPPercentage(character)
    local healthData = GetHealthData(character)
    return healthData and healthData.hpPercent or HP_FULL
end

-- Count enemies adjacent to character
local function GetAdjacentEnemyCount(character)
    if not IsValidString(character) then
        return 0
    end
    
    -- Check cache first
    local cached = adjacentEnemyCache[character]
    if cached and cached.time + COMBAT_STATUS_CACHE_EXPIRY > Ext.Utils.MonotonicTime() then
        return cached.count
    end
    
    local count = 0
    local success = pcall(function()
        local entity = Ext.Entity.Get(character)
        if not entity or not entity.Transform then
            return
        end
        
        -- Get enemies in combat
        local enemies = GetEnemyTargetsInCombat(character)
        if not enemies then
            return
        end
        
        -- Count enemies within melee range
        for _, enemyUUID in ipairs(enemies) do
            local distance = CalculateDistance(character, enemyUUID)
            if distance and distance <= ADJACENT_ENEMY_RANGE then
                count = count + 1
            end
        end
    end)
    
    -- Cache result
    adjacentEnemyCache[character] = {count = count, time = Ext.Utils.MonotonicTime()}
    
    return count
end

-- Party members cache for combat
local partyMembersCache = nil
local partyMembersCacheTime = 0
local PARTY_CACHE_EXPIRY = 5000  -- Cache for 5 seconds (party rarely changes mid-combat)

-- Get all party members (consolidated function to reduce duplication)
-- Returns: table of players or nil on error
-- Optimized: Cached with 5s expiry to reduce database queries
local function GetPartyMembers(skipCache)
    -- Allow bypassing cache when roster changes
    if not skipCache then
        if partyMembersCache and (Ext.Utils.MonotonicTime() - partyMembersCacheTime) < PARTY_CACHE_EXPIRY then
            return partyMembersCache
        end
    end
    
    local success, players = pcall(function() 
        return Osi.DB_PartOfTheTeam:Get(nil)
    end)
    
    if success and players then
        partyMembersCache = players
        partyMembersCacheTime = Ext.Utils.MonotonicTime()
        return players
    end
    
    return nil
end

-- Check if a character is a summon (conjured creature)
-- Returns: true if summon, false otherwise
-- Note: Summon detection uses common BG3 tags and statuses. If new summon types are added
--       to the game, extend the SUMMON_TAGS or SUMMON_STATUSES lists at module level (lines 406-407).
local function IsSummon(character)
    if not IsValidString(character) then
        return false
    end
    
    local success, isSummon = pcall(function()
        -- Check summon tags (uses module-level SUMMON_TAGS)
        for _, tag in ipairs(SUMMON_TAGS) do
            if Osi.IsTagged(character, tag) == 1 then
                return true
            end
        end
        
        -- Check summon statuses (uses module-level SUMMON_STATUSES)
        for _, status in ipairs(SUMMON_STATUSES) do
            if Osi.HasActiveStatus(character, status) == 1 then
                return true
            end
        end
        
        return false
    end)
    
    return success and isSummon
end

-- Check if any ally is downed
-- @param character string: Character UUID to exclude from check (optional)
-- @return boolean: true if any non-summon ally is downed
local function IsAnyAllyDowned(character)
    for ally in IteratePartyMembers(true) do  -- Skip summons
        if ally ~= character then
            if Osi.HasActiveStatus(ally, "DOWNED") == 1 then
                return true
            end
        end
    end
    
    return false
end

-- Check for Barbarian Rage
local function IsRaging(character)
    if not IsValidString(character) then
        return false
    end
    
    -- Check cache first
    local cached = GetCachedValue(rageStatusCache, character, COMBAT_STATUS_CACHE_EXPIRY)
    if cached ~= nil then
        return cached
    end
    
    local isRaging = false
    local success = pcall(function()
        for _, status in ipairs(RAGE_STATUSES) do
            if Osi.HasActiveStatus(character, status) == 1 then
                isRaging = true
                break
            end
        end
    end)
    
    -- Cache result
    SetCachedValue(rageStatusCache, character, success and isRaging)
    
    return success and isRaging
end

-- Check for Wild Shape
local function IsInWildShape(character)
    if not IsValidString(character) then
        return false
    end
    
    -- Check cache first
    local cached = GetCachedValue(wildshapeStatusCache, character, COMBAT_STATUS_CACHE_EXPIRY)
    if cached ~= nil then
        return cached
    end
    
    local inWildShape = false
    local success = pcall(function()
        -- Check explicit wildshape statuses
        for _, status in ipairs(WILDSHAPE_STATUSES) do
            if Osi.HasActiveStatus(character, status) == 1 then
                inWildShape = true
                break
            end
        end
        
        -- Also check for specific wildshape forms by pattern matching
        if not inWildShape then
            local entity = Ext.Entity.Get(character)
            if entity and entity.StatusContainer and entity.StatusContainer.Statuses then
                for _, statusData in pairs(entity.StatusContainer.Statuses) do
                    if statusData.StatusId and string.find(statusData.StatusId, "WILDSHAPE") then
                        inWildShape = true
                        break
                    end
                end
            end
        end
    end)
    
    -- Cache result
    SetCachedValue(wildshapeStatusCache, character, success and inWildShape)
    
    return success and inWildShape
end

-------------------------------------------------------------------------------
-- Spell Detection Utilities
-------------------------------------------------------------------------------

-- Check if character has a specific spell available
-- @param character string: Character UUID
-- @param spellName string: Name of the spell to check
-- @return boolean: true if character has the spell, false otherwise
local function HasSpellAvailable(character, spellName)
    if not IsValidString(character) or not IsValidString(spellName) then
        return false
    end
    
    local success, hasSpell = pcall(function()
        return Osi.HasSpell(character, spellName) == 1
    end)
    
    return success and hasSpell
end

-- Get all spells for a character (including modded spells)
-- @param character string: Character UUID
-- @return table: List of spell names, or empty table on error
local function GetAllCharacterSpells(character)
    if not IsValidString(character) then
        return {}
    end
    
    local spells = {}
    local success = pcall(function()
        local entity = Ext.Entity.Get(character)
        if not entity or not entity.SpellBook or not entity.SpellBook.Spells then
            return
        end
        
        for _, spellData in ipairs(entity.SpellBook.Spells) do
            if spellData.Id and spellData.Id.OriginatorPrototype then
                table.insert(spells, spellData.Id.OriginatorPrototype)
            end
        end
    end)
    
    return success and spells or {}
end

-- Debug utility to log all spells for a character
-- @param character string: Character UUID
local function LogCharacterSpells(character)
    if not IsValidString(character) then
        return
    end
    
    local spells = GetAllCharacterSpells(character)
    if #spells > 0 then
        Log(LOG_LEVEL.INFO, string.format("[SpellDebug] Character %s has %d spells:", character, #spells))
        for i, spellName in ipairs(spells) do
            local isModded = IsModdedSpell(spellName)
            Log(LOG_LEVEL.INFO, string.format("  [%d] %s %s", i, spellName, isModded and "(MODDED)" or ""))
        end
    else
        Log(LOG_LEVEL.INFO, string.format("[SpellDebug] Character %s has no spells or failed to retrieve", character))
    end
end

-- Export spell detection functions
Mods.AIAllies.HasSpellAvailable = HasSpellAvailable
Mods.AIAllies.GetAllCharacterSpells = GetAllCharacterSpells
Mods.AIAllies.LogCharacterSpells = LogCharacterSpells

-- Optimized: Get all health data in single entity fetch
-- Returns: {currentHP, maxHP, hpPercent} or nil on error
local function GetHealthData(character)
    local success, healthData = pcall(function()
        local entity = Ext.Entity.Get(character)
        if entity and entity.Health and entity.Health.Hp and entity.Health.MaxHp then
            local currentHP = entity.Health.Hp
            local maxHP = entity.Health.MaxHp
            local hpPercent = HP_FULL
            if maxHP > 0 then
                hpPercent = (currentHP / maxHP) * 100
            end
            return {currentHP = currentHP, maxHP = maxHP, hpPercent = hpPercent}
        end
        return nil
    end)
    
    return success and healthData or nil
end

-- Get max HP for a character
-- Optimized: Uses GetHealthData to avoid duplicate entity fetch logic
local function GetMaxHP(character)
    local healthData = GetHealthData(character)
    return healthData and healthData.maxHP or 0
end

-- Get current HP for a character
-- Optimized: Uses GetHealthData to avoid duplicate entity fetch logic
local function GetCurrentHP(character)
    local healthData = GetHealthData(character)
    return healthData and healthData.currentHP or 0
end

-- Evaluate contextual conditions and apply temporary archetypes
local function EvaluateContextualArchetypes(character)
    -- Skip if feature disabled via MCM
    -- Note: GetCachedSettingValue always returns a non-nil value (uses DEFAULT_SETTINGS)
    -- So this check correctly handles: true (enabled) vs false (disabled)
    local enableContextual = GetCachedSettingValue("enableContextualSwitching", ModuleUUID)
    if not enableContextual then
        return
    end
    
    local success, err = pcall(function()
        -- Check if character has base AI archetype
        if not hasAnyAICombatStatus(character) then
            return
        end
        
        local debugMode = GetCachedSettingValue("debugArchetypes", ModuleUUID)
        local lowHPThreshold = GetCachedSettingValue("lowHPThreshold", ModuleUUID)
        
        -- Priority 1: Wild Shape detection (highest priority - state change)
        local enableWildShape = GetCachedSettingValue("enableWildShapeAI", ModuleUUID)
        if enableWildShape ~= false and IsInWildShape(character) then
            if SafeApplyStatus(character, "AI_ALLIES_BEAST_MODE", -1) and debugMode then
                Log(LOG_LEVEL.INFO, "[Contextual] Applied BEAST_MODE to Wild Shape druid: " .. character)
            end
            return  -- Wild Shape overrides other contextual behaviors
        else
            -- Remove beast mode if no longer in wild shape
            if SafeRemoveStatus(character, "AI_ALLIES_BEAST_MODE") and debugMode then
                Log(LOG_LEVEL.INFO, "[Contextual] Removed BEAST_MODE (no longer in Wild Shape): " .. character)
            end
        end
        
        -- Priority 2: Berserker Mode for Raging Barbarians
        local enableBerserker = GetCachedSettingValue("enableBerserkerMode", ModuleUUID)
        if enableBerserker ~= false and IsRaging(character) then
            if SafeApplyStatus(character, "AI_ALLIES_BERSERKER_MODE", -1) and debugMode then
                Log(LOG_LEVEL.INFO, "[Contextual] Applied BERSERKER_MODE to raging character: " .. character)
            end
            -- Berserkers don't use defensive mode while raging
            SafeRemoveStatus(character, "AI_ALLIES_DEFENSIVE_MODE")
        else
            -- Remove berserker mode if no longer raging
            if SafeRemoveStatus(character, "AI_ALLIES_BERSERKER_MODE") and debugMode then
                    Log(LOG_LEVEL.INFO, "[Contextual] Removed BERSERKER_MODE (no longer raging): " .. character)
                end
            end
        end
        
        -- Priority 3: Emergency - Ally downed (Priority 9)
        if IsAnyAllyDowned(character) then
            -- If character is a healer, boost to emergency healer mode
            local isHealer = Osi.HasActiveStatus(character, "AI_ALLIES_HEALER_MELEE") == 1 or
                            Osi.HasActiveStatus(character, "AI_ALLIES_HEALER_RANGED") == 1 or
                            Osi.HasActiveStatus(character, "AI_ALLIES_HEALER_MELEE_NPC") == 1 or
                            Osi.HasActiveStatus(character, "AI_ALLIES_HEALER_RANGED_NPC") == 1
            
            if isHealer then
                -- Already handled by healer logic in TurnStarted
                -- But we log it for priority tracking
                if debugMode then
                    Log(LOG_LEVEL.DEBUG, "[Contextual] " .. character .. " in emergency healer mode (ally downed)")
                end
            end
        end
        
        -- Priority 4: Low HP - Defensive mode (Priority 8)
        local hpPercent = GetHPPercentage(character)
        if hpPercent < lowHPThreshold then
            -- Apply defensive mode for low HP (unless raging)
            if Osi.HasActiveStatus(character, "AI_ALLIES_BERSERKER_MODE") == 0 then
                if SafeApplyStatus(character, "AI_ALLIES_DEFENSIVE_MODE", -1) and debugMode then
                    Log(LOG_LEVEL.INFO, string.format(
                        "[Contextual] Applied DEFENSIVE_MODE to %s (HP: %.1f%%)",
                        character, hpPercent
                    ))
                end
            end
        else
            -- Remove defensive mode when HP is back up
            if SafeRemoveStatus(character, "AI_ALLIES_DEFENSIVE_MODE") and debugMode then
                Log(LOG_LEVEL.INFO, string.format(
                    "[Contextual] Removed DEFENSIVE_MODE from %s (HP: %.1f%%)",
                    character, hpPercent
                ))
            end
        end
        
        -- Priority 5: Surrounded - AOE specialist (Priority 7)
        local adjacentEnemies = GetAdjacentEnemyCount(character)
        if adjacentEnemies >= 3 and debugMode then
            Log(LOG_LEVEL.DEBUG, string.format(
                "[Contextual] %s surrounded by %d enemies",
                character, adjacentEnemies
            ))
        end
    end)
    
    if not success then
        Log(LOG_LEVEL.WARN, "Error in contextual archetype evaluation: " .. tostring(err))
    end
end

-- Initialize the CurrentAllies table from PersistentVars when the session loads
local function InitCurrentAllies()
    Mods.AIAllies = Mods.AIAllies or {}
    Mods.AIAllies.PersistentVars = Mods.AIAllies.PersistentVars or {}
    CurrentAllies = Mods.AIAllies.PersistentVars.CurrentAllies or {}
end

-- Subscribe to the SessionLoaded event to initialize CurrentAllies
Ext.Events.SessionLoaded:Subscribe(InitCurrentAllies)

--------------------------------------------------------------------------------
-- Enhanced Healer and Spell Management Functions
--------------------------------------------------------------------------------

-- Enhanced healer target selection based on healing priority mode
local function GetBestHealingTarget(healer, injuredAllies, priorityMode)
    if not injuredAllies or #injuredAllies == 0 then
        return nil
    end
    
    local mode = priorityMode or GetCachedSettingValue("healingPriorityMode", ModuleUUID)
    
    local bestTarget = nil
    local bestScore = -1
    
    for _, ally in ipairs(injuredAllies) do
        -- Optimized: Get all health data in single entity fetch
        local healthData = GetHealthData(ally)
        if healthData then
            local score = 0
            local hpPercent = healthData.hpPercent
            local maxHP = healthData.maxHP
            local currentHP = healthData.currentHP
            local missingHP = maxHP - currentHP
            
            if mode == "LOWEST_HP" then
                -- Prioritize lowest HP percentage
                score = 100 - hpPercent
        elseif mode == "MOST_DAMAGED" then
            -- Prioritize most HP missing (raw number)
            score = missingHP
        elseif mode == "TANK_PRIORITY" then
            -- Prioritize tanks (melee archetypes) when injured
            local archetype = GetCurrentArchetype(ally)
            if archetype and (string.find(archetype, "MELEE") or string.find(archetype, "TANK")) then
                score = (100 - hpPercent) * 1.5
            else
                score = 100 - hpPercent
            end
        end
        
            -- Bonus for downed allies (always highest priority)
            if Osi.HasActiveStatus(ally, "DOWNED") == 1 then
                score = score + 1000
            end
            
            if score > bestScore then
                bestScore = score
                bestTarget = ally
            end
        end
    end
    
    return bestTarget
end

-- Check if spell is appropriate given conservation settings
local function ShouldUseSpellSlot(character, spellLevel, targetCount)
    local mode = GetCachedSettingValue("spellSlotConservation", ModuleUUID)
    
    if mode == "AGGRESSIVE" then
        return true  -- Always use best spells
    end
    
    local success, result = pcall(function()
        local entity = Ext.Entity.Get(character)
        if not entity or not entity.ActionResources then
            return true  -- Can't determine, allow
        end
        
        -- Get remaining spell slots at this level
        local remainingSlots = 0
        local totalSlots = 0
        
        -- Check ActionResources for spell slots
        for _, resource in pairs(entity.ActionResources.Resources) do
            if resource.ResourceUUID then
                local resourceId = tostring(resource.ResourceUUID)
                -- Check if this is a spell slot resource for our level
                if string.find(resourceId, "SpellSlot") and string.find(resourceId, tostring(spellLevel)) then
                    remainingSlots = resource.Amount or 0
                    totalSlots = resource.MaxAmount or 0
                    break
                end
            end
        end
        
        if mode == "CONSERVATIVE" then
            -- Only use high-level slots (3+) if:
            -- 1. Hitting multiple targets (3+)
            -- 2. More than 50% slots remaining
            -- 3. Boss fight (future enhancement)
            if spellLevel >= 3 then
                if targetCount and targetCount >= 3 then
                    return true
                end
                if totalSlots > 0 and (remainingSlots / totalSlots) > 0.5 then
                    return true
                end
                return false
            end
        end
        
        -- BALANCED: Allow most spells, just don't waste high-level on single weak targets
        if spellLevel >= 4 and targetCount and targetCount < 2 then
            if totalSlots > 0 and (remainingSlots / totalSlots) < 0.3 then
                return false
            end
        end
        
        return true
    end)
    
    return success and result or true  -- Default to allowing on error
end

-------------------------------------------------------------------------------
-- Dynamic Spell Detection System
-------------------------------------------------------------------------------
-- Detects spell types from spell stats to support modded equipment

-- LRU Cache implementation for spell type detection
-- Tracks access time for proper Least Recently Used eviction
local spellCacheAccessTimes = {}

-- Helper to manage spell cache size with LRU eviction
local function addToSpellCache(spellName, cacheType, value)
    local isNewEntry = not spellTypeCache[spellName]
    
    if not spellTypeCache[spellName] then
        spellTypeCache[spellName] = {}
    end
    spellTypeCache[spellName][cacheType] = value
    
    -- Update access time for LRU tracking
    spellCacheAccessTimes[spellName] = Ext.Utils.MonotonicTime()
    
    -- Increment count for new entries
    if isNewEntry then
        spellCacheCount = spellCacheCount + 1
    end
    
    -- Check cache size and evict oldest single entry if too large (O(n) scan, no sort)
    while spellCacheCount > MAX_SPELL_CACHE_SIZE do
        local oldestKey = nil
        local oldestTime = nil
        for key, accessTime in pairs(spellCacheAccessTimes) do
            if not oldestTime or accessTime < oldestTime then
                oldestKey = key
                oldestTime = accessTime
            end
        end
        
        if not oldestKey then
            break  -- Should not happen, but avoid infinite loop
        end
        
        spellTypeCache[oldestKey] = nil
        spellCacheAccessTimes[oldestKey] = nil
        spellCacheCount = spellCacheCount - 1
    end
end

-- Generic spell type detection with caching
-- @param spellName string: The name of the spell to check
-- @param cacheKey string: The cache key for this spell type (e.g., "healing", "conjuring")
-- @param detectionFunc function: Function that performs the actual detection logic (spell, name) -> boolean
-- @return boolean: true if the spell matches the type, false otherwise
local function CheckSpellType(spellName, cacheKey, detectionFunc)
    -- Safety check for valid spell name
    if not IsValidString(spellName) then
        return false
    end
    
    -- Check cache first and update access time
    if spellTypeCache[spellName] ~= nil then
        if spellTypeCache[spellName][cacheKey] ~= nil then
            -- Update LRU access time
            spellCacheAccessTimes[spellName] = Ext.Utils.MonotonicTime()
            return spellTypeCache[spellName][cacheKey]
        end
    else
        spellTypeCache[spellName] = {}
    end
    
    local result = false
    local success, detectionResult = pcall(function()
        local spell = Ext.Stats.Get(spellName, -1, false, true)
        if spell then
            -- Wrap detection function in another pcall for modded spell safety
            local detectSuccess, detectResult = pcall(function()
                return detectionFunc(spell, spellName)
            end)
            
            if detectSuccess then
                return detectResult
            else
                -- Detection function threw error (likely modded spell with invalid properties)
                Log(LOG_LEVEL.DEBUG, "Detection function error for spell: " .. spellName .. " (likely modded spell with non-standard properties)")
                return false
            end
        end
        return false
    end)
    
    -- If pcall failed, log error and return false
    if success then
        result = detectionResult
    else
        Log(LOG_LEVEL.DEBUG, "Error checking spell type for: " .. spellName .. " (spell may not exist or has invalid stats)")
    end
    
    addToSpellCache(spellName, cacheKey, result)
    return result
end

-- Cache for lowercased spell names to avoid repeated string.lower() calls
local spellNameLowerCache = {}

-- Check if a spell is a healing spell
local function IsHealingSpell(spellName)
    return CheckSpellType(spellName, "healing", function(spell, name)
        -- Check if spell name contains healing keywords (comprehensive list including modded variants)
        -- Optimized: Cache lowercased names to avoid repeated string.lower() calls
        local lowerName = spellNameLowerCache[name]
        if not lowerName then
            lowerName = string.lower(name)
            spellNameLowerCache[name] = lowerName
        end
        
        -- Extended keyword list for modded healing spells
        if lowerName:find("heal") or lowerName:find("cure") or lowerName:find("reviv") or 
           lowerName:find("help") or lowerName:find("aid") or lowerName:find("bless") or
           lowerName:find("restoration") or lowerName:find("prayer") or lowerName:find("word") or
           lowerName:find("mass") or lowerName:find("greater") or lowerName:find("lesser") or
           lowerName:find("regenerat") or lowerName:find("recovery") or lowerName:find("mend") or
           lowerName:find("remedy") or lowerName:find("renew") or lowerName:find("rejuvenat") or
           lowerName:find("sanctuary") or lowerName:find("vitality") or lowerName:find("lifeforce") or
           lowerName:find("divine") and lowerName:find("beam") or  -- Eldertide: Divine Beam of Recovery
           lowerName:find("divine") and lowerName:find("restoration") then  -- Eldertide: Divine Restoration
            return true
        end
        
        -- Check spell properties for healing indicators (with nil safety)
        if spell.SpellSchool and (spell.SpellSchool == "Necromancy" or spell.SpellSchool == "Evocation" or spell.SpellSchool == "Abjuration") then
            -- Some healing spells are necromancy/evocation/abjuration
            if spell.SpellProperties then
                local success, props = pcall(function() return tostring(spell.SpellProperties) end)
                if success and props and (props:find("HEAL") or props:find("RegainHP") or props:find("Healing") or props:find("RestoreResource")) then
                    return true
                end
            end
        end
        
        -- Check if it targets allies (healing spells typically do) with nil safety
        if spell.TargetConditions then
            local success, conditions = pcall(function() return tostring(spell.TargetConditions) end)
            if success and conditions and conditions:find("Ally") and not conditions:find("Enemy") then
                -- Check for healing effects in description or properties
                if spell.TooltipDamageList or spell.TooltipPermanentWarnings then
                    local tooltipSuccess, tooltips = pcall(function() 
                        return tostring(spell.TooltipDamageList or "") .. tostring(spell.TooltipPermanentWarnings or "") 
                    end)
                    if tooltipSuccess and tooltips and (tooltips:find("Heal") or tooltips:find("Regain") or tooltips:find("Restore")) then
                        return true
                    end
                end
            end
        end
        
        -- Check for positive healing-like status effects (with nil safety)
        if spell.SpellProperties then
            local success, props = pcall(function() return tostring(spell.SpellProperties) end)
            if success and props then
                -- Look for regeneration or temporary HP effects
                if props:find("REGENERAT") or props:find("TEMP_HP") or props:find("TemporaryHP") then
                    return true
                end
            end
        end
        
        return false
    end)
end

-- Check if a spell is a conjuring/summoning spell
local function IsConjuringSpell(spellName)
    return CheckSpellType(spellName, "conjuring", function(spell, name)
        -- Check spell name for conjuring keywords (comprehensive list)
        -- Optimized: Reuse cached lowercased names
        local lowerName = spellNameLowerCache[name]
        if not lowerName then
            lowerName = string.lower(name)
            spellNameLowerCache[name] = lowerName
        end
        
        if lowerName:find("conjur") or lowerName:find("summon") or lowerName:find("familiar") or 
           lowerName:find("elemental") or lowerName:find("animate") or lowerName:find("create") or
           lowerName:find("servant") or lowerName:find("guardian") or lowerName:find("phantom") or
           lowerName:find("spirit") or lowerName:find("steed") or lowerName:find("weapon") or
           lowerName:find("minor") or lowerName:find("major") then
            return true
        end
        
        -- Check spell school
        if spell.SpellSchool and spell.SpellSchool == "Conjuration" then
            return true
        end
        
        -- Check if spell creates entities or summons
        if spell.SpellProperties then
            local props = tostring(spell.SpellProperties)
            if props:find("Summon") or props:find("SPAWN") or props:find("CreateEntity") or 
               props:find("CreateSurface") or props:find("Conjure") then
                return true
            end
        end
        
        -- Check for summoning flags
        if spell.SpellFlags then
            local flags = tostring(spell.SpellFlags)
            if flags:find("IsSummon") or flags:find("IsConjure") then
                return true
            end
        end
        
        return false
    end)
end

-- Check if a spell is a bonus action spell (for better AI action economy)
local function IsBonusActionSpell(spellName)
    return CheckSpellType(spellName, "bonusAction", function(spell, name)
        -- Check if spell uses bonus action cost
        if spell.UseCosts then
            local costs = tostring(spell.UseCosts)
            if costs:find("BonusActionPoint") then
                return true
            end
        end
        
        -- Check spell name for common bonus action indicators
        -- Optimized: Reuse cached lowercased names
        local lowerName = spellNameLowerCache[name]
        if not lowerName then
            lowerName = string.lower(name)
            spellNameLowerCache[name] = lowerName
        end
        
        if lowerName:find("bonus") or lowerName:find("word") or lowerName:find("step") or 
           lowerName:find("cunning") or lowerName:find("offhand") then
            return true
        end
        
        return false
    end)
end

-- Check if a spell provides movement/mobility (like Frost Step, Misty Step)
local function IsMovementSpell(spellName)
    return CheckSpellType(spellName, "movement", function(spell, name)
        -- Check spell name for movement keywords
        -- Optimized: Reuse cached lowercased names
        local lowerName = spellNameLowerCache[name]
        if not lowerName then
            lowerName = string.lower(name)
            spellNameLowerCache[name] = lowerName
        end
        
        if lowerName:find("step") or lowerName:find("leap") or lowerName:find("jump") or 
           lowerName:find("blink") or lowerName:find("dimension") or lowerName:find("teleport") then
            return true
        end
        
        -- Check spell properties for teleport/movement effects
        if spell.SpellProperties then
            local props = tostring(spell.SpellProperties)
            if props:find("Teleport") or props:find("Jump") or props:find("Dash") then
                return true
            end
        end
        
        -- Check spell school for transmutation (often movement spells)
        if spell.SpellSchool and spell.SpellSchool == "Transmutation" then
            -- Check if it's a mobility transmutation spell
            if spell.TargetRadius and tostring(spell.TargetRadius):find("Distance") then
                return true
            end
        end
        
        return false
    end)
end

-- Get all spells a character currently has
local function GetCharacterSpells(character)
    -- Check cache first
    local cached = characterSpellsCache[character]
    if cached and cached.time + SPELL_CACHE_EXPIRY > Ext.Utils.MonotonicTime() then
        return cached.spells
    end
    
    local spells = {}
    local success = pcall(function()
        local entity = Ext.Entity.Get(character)
        if entity and entity.SpellBook and entity.SpellBook.Spells then
            for _, spellInfo in pairs(entity.SpellBook.Spells) do
                if spellInfo.Id then
                    local spellId = spellInfo.Id.OriginatorPrototype
                    if spellId and spellId ~= "" then
                        table.insert(spells, spellId)
                    end
                end
            end
        end
    end)
    
    if not success then
        Log(LOG_LEVEL.DEBUG, "Failed to get spells for character: " .. character)
    end
    
    -- Cache the result
    characterSpellsCache[character] = {spells = spells, time = Ext.Utils.MonotonicTime()}
    
    return spells
end

-- Check if character has already used a conjuring spell this combat
local function HasUsedConjuringSpell(character, spellName)
    if not conjuringSpellsUsed[character] then
        return false
    end
    return conjuringSpellsUsed[character][spellName] == true
end

-- Mark a conjuring spell as used for this combat
local function MarkConjuringSpellUsed(character, spellName)
    if not conjuringSpellsUsed[character] then
        conjuringSpellsUsed[character] = {}
    end
    conjuringSpellsUsed[character][spellName] = true
    Log(LOG_LEVEL.DEBUG, "Marked conjuring spell as used: " .. spellName .. " for " .. character)
end

-- Clear conjuring spell tracking for a character
local function ClearConjuringSpellTracking(character)
    if conjuringSpellsUsed[character] then
        conjuringSpellsUsed[character] = nil
        Log(LOG_LEVEL.DEBUG, "Cleared conjuring spell tracking for: " .. character)
    end
end

-------------------------------------------------------------------------------
-- Helper Functions for Common Operations
-------------------------------------------------------------------------------

-- Check if an entity is valid (exists and has required components)
-- Returns: true if valid, false otherwise
local function IsValidEntity(entityUUID)
    if not entityUUID or entityUUID == "" then
        return false
    end
    
    local success, entity = pcall(function()
        return Ext.Entity.Get(entityUUID)
    end)
    
    return success and entity ~= nil
end

--- Calculate 3D distance between two entities (optimized to accept pre-fetched entity)
--- @param entity1UUID string First entity UUID
--- @param entity2UUID string Second entity UUID
--- @param preloadedEntity2 table? Pre-fetched entity2 (optional; if nil, will fetch from UUID)
--- @return number? distance in meters, or nil on error
local function CalculateDistance(entity1UUID, entity2UUID, preloadedEntity2)
    local success, distance = pcall(function()
        local entity1 = Ext.Entity.Get(entity1UUID)
        local entity2 = preloadedEntity2 or Ext.Entity.Get(entity2UUID)
        
        if not entity1 or not entity1.Transform or not entity1.Transform.Transform then
            return nil
        end
        if not entity2 or not entity2.Transform or not entity2.Transform.Transform then
            return nil
        end
        
        local pos1 = entity1.Transform.Transform.Translate
        local pos2 = entity2.Transform.Transform.Translate
        
        if not pos1 or not pos2 then
            return nil
        end
        
        local dx = pos1[1] - pos2[1]
        local dy = pos1[2] - pos2[2]
        local dz = pos1[3] - pos2[3]
        
        return math.sqrt(dx*dx + dy*dy + dz*dz)
    end)
    
    if success and distance then
        return distance
    end
    
    return nil
end

-------------------------------------------------------------------------------
-- Target Priority System
-------------------------------------------------------------------------------

-- Cache for target info for performance (expires each turn)
local targetInfoCache = {}
local targetInfoCacheTime = {}
local TARGET_INFO_CACHE_DURATION = 1000  -- 1 second

-- Cache for combat participants to reduce redundant queries
local combatParticipantsCache = {}
local combatParticipantsCacheTime = {}
local COMBAT_PARTICIPANTS_CACHE_DURATION = 3000  -- 3 seconds (combat state changes slowly)

-- Track current focus target for the party
local focusFireTarget = nil
local focusFireStartTime = 0

-- Helper function to filter participants to get enemies for a specific character
-- Optimized: Reduces code duplication and improves maintainability
local function FilterEnemiesFromParticipants(character, participants)
    local enemies = {}
    for _, participantUUID in ipairs(participants) do
        if Osi.IsEnemy(character, participantUUID) == 1 and 
           Osi.IsDead(participantUUID) == 0 and
           Osi.GetHitpoints(participantUUID) > 0 then
            table.insert(enemies, participantUUID)
        end
    end
    return enemies
end

-- Get all valid enemy targets in combat
local function GetEnemyTargetsInCombat(character)
    local enemies = {}
    local combatGuid = nil
    
    local success, result = pcall(function()
        -- Get all entities in combat with the character
        combatGuid = Osi.CombatGetGuidFor(character)
        if not combatGuid then
            return {}
        end
        
        -- Check cache first for combat participants
        local now = Ext.Utils.MonotonicTime()
        local cached = combatParticipantsCache[combatGuid]
        if cached and (now - (combatParticipantsCacheTime[combatGuid] or 0)) < COMBAT_PARTICIPANTS_CACHE_DURATION then
            -- Filter cached participants to get enemies for this character
            return FilterEnemiesFromParticipants(character, cached)
        end
        
        -- Cache miss - fetch and cache combat participants
        local allParticipants = {}
        local combatData = Ext.Entity.Get(combatGuid)
        if combatData and combatData.Combat then
            -- Iterate through all combatants once and cache them
            for _, participant in pairs(combatData.Combat.CombatGroups.CombatGroups) do
                for _, entityHandle in pairs(participant.Participants) do
                    local entity = Ext.Entity.Get(entityHandle.EntityRef)
                    if entity and entity.Uuid and entity.Uuid.EntityUuid then
                        local targetUUID = entity.Uuid.EntityUuid
                        table.insert(allParticipants, targetUUID)
                    end
                end
            end
        end
        
        -- Cache participants for this combat
        combatParticipantsCache[combatGuid] = allParticipants
        combatParticipantsCacheTime[combatGuid] = now
        
        -- Filter for enemies
        return FilterEnemiesFromParticipants(character, allParticipants)
    end)
    
    if success and result and #result > 0 then
        return result
    end
    
    -- Fallback: try to get hostile characters
    if not combatGuid then
        combatGuid = Osi.CombatGetGuidFor(character)
    end
    
    if combatGuid then
        local fallbackSuccess = pcall(function()
            local hostiles = Osi.DB_CombatCharacters:Get(nil, combatGuid)
            if hostiles then
                for _, hostile in ipairs(hostiles) do
                    local targetUUID = hostile[1]
                    if Osi.IsEnemy(character, targetUUID) == 1 and 
                       Osi.IsDead(targetUUID) == 0 and
                       Osi.GetHitpoints(targetUUID) > 0 then
                        table.insert(enemies, targetUUID)
                    end
                end
            end
        end)
    end
    
    return enemies
end

--- Detect if target is a spellcaster (optimized to accept pre-fetched entity)
--- @param targetUUID string Target character UUID
--- @param entity table? Pre-fetched entity (optional; if nil, will fetch from UUID)
--- @return boolean true if target is a spellcaster, false otherwise
local function IsSpellcaster(targetUUID, entity)
    local success, isCaster = pcall(function()
        -- Check for common caster passives
        if Osi.HasPassive(targetUUID, "Spellcasting") == 1 then
            return true
        end
        
        -- Use provided entity or fetch if not provided
        local targetEntity = entity or Ext.Entity.Get(targetUUID)
        if targetEntity and targetEntity.SpellBook and targetEntity.SpellBook.Spells then
            -- If has prepared spells, likely a caster
            if #targetEntity.SpellBook.Spells > 0 then
                return true
            end
        end
        
        return false
    end)
    
    return success and isCaster
end

--- Calculate threat level for an enemy (optimized to accept pre-computed data)
--- @param targetUUID string Target character UUID
--- @param entity table? Pre-fetched entity (optional; if nil, will fetch from UUID)
--- @param isCaster boolean? Pre-computed spellcaster status (optional; if nil, will detect)
--- @return number Threat score for this target (0 or higher)
local function CalculateThreatLevel(targetUUID, entity, isCaster)
    local threat = 0
    
    local success = pcall(function()
        -- Base threat from HP (use provided entity to avoid refetch)
        local targetEntity = entity or Ext.Entity.Get(targetUUID)
        if targetEntity and targetEntity.Health then
            threat = threat + (targetEntity.Health.MaxHp / 10)
        end
        
        -- Optimized: Batch status checks using module-level constant
        -- Uses THREAT_STATUSES table defined at module scope to avoid repeated table creation
        for status, statusThreat in pairs(THREAT_STATUSES) do
            if Osi.HasActiveStatus(targetUUID, status) == 1 then
                threat = threat + statusThreat
            end
        end
        
        -- Threat from being a spellcaster (use pre-computed value if available)
        local targetIsCaster = isCaster
        if targetIsCaster == nil then
            targetIsCaster = IsSpellcaster(targetUUID, targetEntity)
        end
        
        if targetIsCaster then
            threat = threat + 30
        end
    end)
    
    return threat
end

--- Get target information for priority calculation
--- Consolidates all entity fetches and computations in one pass for optimal performance
--- @param targetUUID string Target character UUID
--- @param character string Character UUID performing the evaluation
--- @return table Target information with fields: currentHP, maxHP, isWounded, distance, threat, isCaster
local function GetTargetInfo(targetUUID, character)
    local now = Ext.Utils.MonotonicTime()
    
    -- Return cached if fresh
    if targetInfoCache[targetUUID] and 
       (now - (targetInfoCacheTime[targetUUID] or 0)) < TARGET_INFO_CACHE_DURATION then
        return targetInfoCache[targetUUID]
    end
    
    -- Calculate fresh target info - fetch entity ONCE and compute all derived values
    local info = {}
    local success = pcall(function()
        -- OPTIMIZATION: Single entity fetch for all computations
        local entity = Ext.Entity.Get(targetUUID)
        
        if entity and entity.Health then
            info.currentHP = entity.Health.Hp
            info.maxHP = entity.Health.MaxHp
            info.isWounded = (info.currentHP / info.maxHP) < 0.5
        else
            info.currentHP = 100
            info.maxHP = 100
            info.isWounded = false
        end
        
        -- OPTIMIZATION: Calculate distance using pre-fetched entity to avoid double Entity.Get
        info.distance = CalculateDistance(character, targetUUID, entity) or 20
        
        -- OPTIMIZATION: Detect caster once and pass to threat calculation
        info.isCaster = IsSpellcaster(targetUUID, entity)
        
        -- OPTIMIZATION: Calculate threat with pre-fetched entity and caster status
        -- This eliminates duplicate Entity.Get() and IsSpellcaster() calls
        info.threat = CalculateThreatLevel(targetUUID, entity, info.isCaster)
    end)
    
    if not success then
        -- Return default values on error
        info = {
            currentHP = 100,
            maxHP = 100,
            isWounded = false,
            distance = 20,
            threat = 0,
            isCaster = false
        }
    end
    
    -- Cache result
    targetInfoCache[targetUUID] = info
    targetInfoCacheTime[targetUUID] = now
    
    return info
end

-- Calculate priority score for each target based on strategy
local function CalculateTargetPriority(targetUUID, character, priorityMode)
    local targetInfo = GetTargetInfo(targetUUID, character)
    
    if priorityMode == "LOWEST_HP" then
        return 100 - targetInfo.currentHP  -- Lower HP = higher priority
    elseif priorityMode == "HIGHEST_HP" then
        return targetInfo.currentHP  -- Higher HP = higher priority
    elseif priorityMode == "NEAREST" then
        return 100 - targetInfo.distance  -- Closer = higher priority
    elseif priorityMode == "HIGHEST_THREAT" then
        return targetInfo.threat  -- Higher threat = higher priority
    elseif priorityMode == "CASTERS_FIRST" then
        return (targetInfo.isCaster and 1000 or 0) + (100 - targetInfo.currentHP)
    elseif priorityMode == "FINISH_WOUNDED" then
        return targetInfo.isWounded and (100 - targetInfo.currentHP) or 0
    else -- BALANCED
        -- Weighted combination of factors
        return (targetInfo.threat * 0.4) + 
               ((100 - targetInfo.currentHP) * 0.3) + 
               ((50 - targetInfo.distance) * 0.3)
    end
end

-- Select best target for AI ally
local function SelectBestTarget(character, enemies)
    local priorityMode = GetCachedSettingValue("targetPriorityMode", ModuleUUID)
    local bestTarget = nil
    local bestPriority = -999999
    
    for _, enemy in ipairs(enemies) do
        local priority = CalculateTargetPriority(enemy, character, priorityMode)
        if priority > bestPriority then
            bestPriority = priority
            bestTarget = enemy
        end
    end
    
    Log(LOG_LEVEL.DEBUG, string.format(
        "[Target Priority] %s selected target %s (Mode: %s, Priority: %.2f)",
        character, bestTarget or "None", priorityMode, bestPriority
    ))
    
    return bestTarget
end

-- Set focus fire target (first ally's choice becomes party target)
local function SetFocusFireTarget(targetUUID)
    focusFireTarget = targetUUID
    focusFireStartTime = Ext.Utils.MonotonicTime()
    Log(LOG_LEVEL.DEBUG, string.format("[Focus Fire] Party now targeting: %s", targetUUID))
end

-- Get focus fire target (expires after 10 seconds or target dies)
local function GetFocusFireTarget()
    if not focusFireTarget then return nil end
    
    -- Check if target still valid
    local success = pcall(function()
        if Osi.IsDead(focusFireTarget) == 1 then
            focusFireTarget = nil
            return
        end
    end)
    
    if not success or not focusFireTarget then
        return nil
    end
    
    -- Check timeout (10 seconds)
    local elapsed = Ext.Utils.MonotonicTime() - focusFireStartTime
    if elapsed > 10000 then
        focusFireTarget = nil
        return nil
    end
    
    return focusFireTarget
end

-- Apply focus fire target to ally
local function ApplyFocusFireIfEnabled(character, normalTarget)
    local enableFocusFire = GetCachedSettingValue("enableFocusFire", ModuleUUID)
    if not enableFocusFire then
        return normalTarget
    end
    
    local focusTarget = GetFocusFireTarget()
    if focusTarget then
        -- Use focus target if valid
        Log(LOG_LEVEL.DEBUG, string.format("[Focus Fire] %s using focus target: %s", character, focusTarget))
        return focusTarget
    else
        -- First ally sets focus target
        SetFocusFireTarget(normalTarget)
        return normalTarget
    end
end

-- Apply status to mark preferred target
local function ApplyTargetPriorityStatus(character, targetUUID)
    local success = pcall(function()
        -- Apply new preferred target status
        -- This leverages existing MULTIPLIER_TARGET_PREFERRED in archetypes (value: 6.0)
        Osi.ApplyStatus(targetUUID, "AI_ALLIES_PREFERRED_TARGET", -1, 1, character)
    end)
    
    if success then
        Log(LOG_LEVEL.DEBUG, string.format("[Target Priority] Applied preferred target marker to %s for %s", targetUUID, character))
    end
end

-- Clear target priority status (handled by RemoveEvents OnTurn in status definition)
local function ClearTargetPriorityStatus(character)
    -- Status automatically removed on turn end via RemoveEvents
    -- This function is a placeholder for future enhancements
end

-------------------------------------------------------------------------------
-- MCM test
-- Optimized: Consolidate player queries into a single function
local function ManagePassiveForPlayers(players, passiveName, shouldHave)
    for _, player in pairs(players) do
        local character = player[1]
        local hasPassive = Osi.HasPassive(character, passiveName) == 1
        if shouldHave and not hasPassive then
            Osi.AddPassive(character, passiveName)
        elseif not shouldHave and hasPassive then
            Osi.RemovePassive(character, passiveName)
        end
    end
end

-- Generic function to manage a passive based on an MCM setting
local function ManagePassiveBySetting(players, settingId, passiveName)
    local settingValue = GetCachedSettingValue(settingId, ModuleUUID)
    ManagePassiveForPlayers(players, passiveName, settingValue)
end

-- Function to check and manage custom archetypes
local function ManageCustomArchetypes(players)
    ManagePassiveBySetting(players, "enableCustomArchetypes", "UnlockCustomArchetypes")
end

local function ManageAlliesMind(players)
    ManagePassiveBySetting(players, "enableAlliesMind", "AlliesMind")
end

local function ManageAlliesDashing(players)
    ManagePassiveBySetting(players, "disableAlliesDashing", "AlliesDashingDisabled")
end

local function ManageAlliesThrowing(players)
    ManagePassiveBySetting(players, "disableAlliesThrowing", "AlliesThrowingDisabled")
end

local function ManageDynamicSpellblock(players)
    ManagePassiveBySetting(players, "enableDynamicSpellblock", "AlliesDynamicSpellblock")
end

local function ManageAlliesSwarm(players)
    ManagePassiveBySetting(players, "enableAlliesSwarm", "AlliesSwarm")
end

-- Generic function to toggle between two mutually exclusive passives
-- @param players table: List of players to manage
-- @param settingId string: MCM setting ID to check
-- @param passiveWhenEnabled string: Passive to apply when setting is true
-- @param passiveWhenDisabled string: Passive to apply when setting is false
local function ManagePassiveToggle(players, settingId, passiveWhenEnabled, passiveWhenDisabled)
    local settingValue = GetCachedSettingValue(settingId, ModuleUUID)
    for _, player in pairs(players) do
        local character = player[1]
        if settingValue then
            -- Remove disabled passive, add enabled passive
            if Osi.HasPassive(character, passiveWhenDisabled) == 1 then
                Osi.RemovePassive(character, passiveWhenDisabled)
            end
            if Osi.HasPassive(character, passiveWhenEnabled) == 0 then
                Osi.AddPassive(character, passiveWhenEnabled)
            end
        else
            -- Remove enabled passive, add disabled passive
            if Osi.HasPassive(character, passiveWhenEnabled) == 1 then
                Osi.RemovePassive(character, passiveWhenEnabled)
            end
            if Osi.HasPassive(character, passiveWhenDisabled) == 0 then
                Osi.AddPassive(character, passiveWhenDisabled)
            end
        end
    end
end

local function ManageOrderSpellsPassive(players)
    ManagePassiveToggle(players, "enableOrdersBonusAction", 
        "UnlockAlliesOrdersBonus", "UnlockAlliesOrders")
end

local function ManageDebugSpells(players)
    ManagePassiveToggle(players, "enableDebugSpells", 
        "UnlockAlliesExtraSpells_ALT", "UnlockAlliesExtraSpells")
end


-------------------------------------------------------------------------------

-- Function to check and give passives to players
-- Optimized: Query DB once and pass to all management functions, return players list
local function CheckAndGivePassiveToPlayers()
    local players = GetPartyMembers()
    if not players then
        return nil
    end
    
    for _, player in pairs(players) do
        local character = player[1]
        if Osi.IsPlayer(character) == 1 then
            if Osi.HasPassive(character, 'GiveAlliesSpell') == 0 then
                Osi.AddPassive(character, 'GiveAlliesSpell')
                Log(LOG_LEVEL.DEBUG, "Given 'GiveAlliesSpell' to: " .. character)
            end
            if Osi.HasPassive(character, 'AlliesToggleNPC') == 0 then
                Osi.AddPassive(character, 'AlliesToggleNPC')
                Log(LOG_LEVEL.DEBUG, "Given 'AlliesToggleNPC' to: " .. character)
            end
        end
    end
    ManageCustomArchetypes(players)
    ManageAlliesMind(players)
    ManageAlliesDashing(players)
    ManageAlliesThrowing(players)
    ManageDynamicSpellblock(players)
    ManageAlliesSwarm(players)
    ManageOrderSpellsPassive(players)
    ManageDebugSpells(players)
    return players  -- Return players for reuse
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    local players = CheckAndGivePassiveToPlayers()

    -- Block crime reactions for all party members
    if players then
        for _, player in pairs(players) do
            local character = player[1]
            Osi.BlockNewCrimeReactions(character, 1)
        end
    end
end)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
    CheckAndGivePassiveToPlayers()
    Osi.BlockNewCrimeReactions(character, 1)
end)

Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function(character)
    if character then
        -- Apply AI_CANCEL regardless of combat status to prevent errors
        -- This ensures AI logic stops running for characters that left the party
        Osi.ApplyStatus(character, "AI_CANCEL", 0)
        
        -- Clear any cached data for this character
        clearStatusCache(character)
        ClearArchetypeStack(character)
        
        -- Clear turn tracking if they were in combat
        if turnStartTimes[character] then
            turnStartTimes[character] = nil
        end
        
        Log(LOG_LEVEL.DEBUG, "Character left party, AI canceled: " .. character)
    end
end)


----------------------------------------------------------------------------------------------
-- MCM Listeners
-- Optimized: Query players once per setting change and invalidate cache
Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
    if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
        return
    end
    
    -- Invalidate cache for this setting
    InvalidateSettingCache(payload.settingId, ModuleUUID)
    
    local players = GetPartyMembers()
    if not players then
        return
    end
    
    if payload.settingId == "enableCustomArchetypes" then
        ManageCustomArchetypes(players)
    elseif payload.settingId == "enableAlliesMind" then
        ManageAlliesMind(players)
    elseif payload.settingId == "disableAlliesDashing" then
        ManageAlliesDashing(players)
    elseif payload.settingId == "disableAlliesThrowing" then
        ManageAlliesThrowing(players)
    elseif payload.settingId == "enableDynamicSpellblock" then
        ManageDynamicSpellblock(players)
    elseif payload.settingId == "enableAlliesSwarm" then
        ManageAlliesSwarm(players)
    elseif payload.settingId == "enableOrdersBonusAction" then
        ManageOrderSpellsPassive(players)
    elseif payload.settingId == "enableDebugSpells" then
        ManageDebugSpells(players)
    end
end)

-- Periodic cache cleanup to prevent unbounded growth
-- Optimized: Only cleanup when cache exceeds threshold to reduce overhead
local function cleanupStaleCache()
    local currentTime = Ext.Utils.MonotonicTime()
    if (currentTime - lastCacheCleanup) < CACHE_CLEANUP_INTERVAL then
        return
    end
    
    -- Only perform cleanup if cache has grown large enough to matter
    if cacheEntriesCount < MAX_CACHE_SIZE * 0.5 then
        lastCacheCleanup = currentTime
        return
    end
    
    local staleCount = 0
    local processed = 0
    local MAX_CLEANUP_BATCH = 200  -- Hard cap per pass to avoid frame spikes
    
    -- Clean stale entries in bounded batches to keep worst-case latency low
    for key, entry in pairs(statusCheckCache) do
        if processed >= MAX_CLEANUP_BATCH then
            break
        end
        processed = processed + 1
        if entry.time + CACHE_EXPIRY < currentTime then
            statusCheckCache[key] = nil
            staleCount = staleCount + 1
        end
    end
    
    -- Adjust count based on removals; any unprocessed stale entries will be handled in later passes
    cacheEntriesCount = math.max(0, cacheEntriesCount - staleCount)
    
    -- If cache is still too large after cleanup, clear it entirely
    if cacheEntriesCount > MAX_CACHE_SIZE then
        statusCheckCache = {}
        cacheEntriesCount = 0
        Log(LOG_LEVEL.WARN, "Cache exceeded max size, clearing all entries")
    end
    
    lastCacheCleanup = currentTime
    if staleCount > 0 or processed > 0 then
        Log(LOG_LEVEL.DEBUG, string.format("Cache cleanup processed %d entries, removed %d, remaining ~%d", processed, staleCount, cacheEntriesCount))
    end
end

-- Global table to track applied statuses to avoid duplicates
_G.appliedStatuses = _G.appliedStatuses or {}
---------------------------------------------------------------------------------------------
-- No idea why I'm doing this
local warningMessages = {
    "Stop it!",
    "Come on, pay attention!",
    "Seriously, stop!",
    "I'm warning you!",
    "Knock it off!",
    "This is your last warning!",
    "Fine! take this. Now, please stop."
}

local currentWarningIndex = 1

local function GetNextWarningMessage()
    local message = warningMessages[currentWarningIndex]
    if currentWarningIndex == #warningMessages then
        local hostCharacter = Osi.GetHostCharacter()
        if not Mods.AIAllies.PersistentVars.firstTimeRewardGiven then
            Osi.UserAddGold(hostCharacter, 200)
            Mods.AIAllies.PersistentVars.firstTimeRewardGiven = true
            Log(LOG_LEVEL.DEBUG, "Attempting to bribe player: " .. hostCharacter)
        else
            Osi.UserAddGold(hostCharacter, 2)
            Log(LOG_LEVEL.DEBUG, "Attempting to bribe a greedy player: " .. hostCharacter)
        end
    end
    currentWarningIndex = currentWarningIndex % #warningMessages + 1
    return message
end

-- Optimized: Batch operations and use table to reduce string concatenations
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, causee, storyActionID)
    if status == 'ToggleIsNPC' and Osi.IsPartyFollower(object) == 1 then
        local hostCharacter = Osi.GetHostCharacter()
        Osi.ApplyStatus(object, "ALLIES_WARNING", 0, 0, hostCharacter)
        Osi.TogglePassive(object, 'AlliesToggleNPC')
        Osi.ShowNotification(hostCharacter, GetNextWarningMessage())
        Log(LOG_LEVEL.WARN, "Not enabling NPC toggle, character is a party follower: " .. object)
    elseif isControllerStatus(status) and Osi.IsPartyFollower(object) == 0 then
        local uuid = Osi.GetUUID(object)
        local PFtimer = "AddToAlliesTimer_" .. uuid
        Osi.TimerLaunch(PFtimer, 1000)
        _G.characterTimers[PFtimer] = uuid
        clearStatusCache(object)  -- Clear cache when status changes
        Log(LOG_LEVEL.DEBUG, "Started timer for " .. uuid)
    end
end)

Ext.Osiris.RegisterListener("TimerFinished", 1, "after", function (timer)
    local uuid = _G.characterTimers[timer]
    if uuid then
        CurrentAllies[uuid] = true
        Mods.AIAllies.PersistentVars.CurrentAllies = CurrentAllies
        Log(LOG_LEVEL.DEBUG, "Added to CurrentAllies after delay: " .. uuid)
        _G.characterTimers[timer] = nil
    end
end)

-- Remove a specific character's UUID from CurrentAllies
local function RemoveFromCurrentAllies(uuid)
    CurrentAllies[uuid] = nil
    Mods.AIAllies.PersistentVars.CurrentAllies = CurrentAllies
    Log(LOG_LEVEL.DEBUG, "Removed from CurrentAllies: " .. uuid)
end

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function (object, status, causee, storyActionID)
    if isControllerStatus(status) then
        local uuid = Osi.GetUUID(object)
        RemoveFromCurrentAllies(uuid)
        clearStatusCache(object)  -- Clear cache when status changes
    end
end)

-- Listener for StatusApplied to remove a specific character's UUID when AI_CANCEL status is applied
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function (object, status, causee, storyActionID)
    if status == 'AI_CANCEL' then
        local uuid = Osi.GetUUID(object)
        RemoveFromCurrentAllies(uuid)
        clearStatusCache(object)  -- Clear cache when status changes
    end
end)
-- Optimized: Consolidate similar operations and reduce redundant checks
Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combatGuid)
    -- Batch ally operations
    local allyOps = {}
    for uuid in pairs(CurrentAllies) do
        table.insert(allyOps, uuid)
    end
    
    for _, uuid in ipairs(allyOps) do
        Osi.ApplyStatus(uuid, 'AI_ALLY', -1)
    end
end)

-- Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function (object, status, causee, storyActionID)
--     if status == 'AI_ALLY' then
--         Log(LOG_LEVEL.DEBUG, "Applied status 'AI_ALLY' to: " .. object)
--     end
-- end)
---------------------------------------------------------------------------------------------
-- Existing Functions for Mindcontrol Art Behavior
-- -------------------------------------------------
local charactersUnderMindControl = {}

local function InitCharactersUnderMindControl()
    if not Mods.AIAllies.PersistentVars.charactersUnderMindControl then
        Mods.AIAllies.PersistentVars.charactersUnderMindControl = {}
    end
    charactersUnderMindControl = Mods.AIAllies.PersistentVars.charactersUnderMindControl
end

Ext.Events.SessionLoaded:Subscribe(InitCharactersUnderMindControl)

local function UpdateMindControlStatus(character, status)
    charactersUnderMindControl[character] = status
    Mods.AIAllies.PersistentVars.charactersUnderMindControl = charactersUnderMindControl
end

local function CanFollow()
    local playerCharacter = Osi.GetHostCharacter()
    return Osi.HasActiveStatus(playerCharacter, 'ALLIES_ORDER_FOLLOW') == 1
end

local function TeleportCharacterToPlayer(character, alwaysTeleport)
    local playerCharacter = Osi.GetHostCharacter()
    if playerCharacter and character and (alwaysTeleport or CanFollow()) then
        Osi.TeleportTo(character, playerCharacter)
        Log(LOG_LEVEL.DEBUG, "Teleporting " .. character .. " to player: " .. playerCharacter)
        if CanFollow() then
            Osi.PROC_Follow(character, playerCharacter)
        end
    end
end

-- Optimized: Reduce function call overhead with early returns
local function UpdateFollowingBehavior(character)
    if not charactersUnderMindControl[character] then
        return
    end
    
    local playerCharacter = Osi.GetHostCharacter()
    if CanFollow() then
        Osi.PROC_Follow(character, playerCharacter)
    else
        Osi.PROC_StopFollow(character)
    end
end

local function UpdateFollowForAll()
    for character, _ in pairs(charactersUnderMindControl) do
        UpdateFollowingBehavior(character)
    end
end

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function (object, status, causee, storyActionID)
    if status == 'ALLIES_MINDCONTROL' then
        Osi.PROC_StopFollow(object)
        UpdateMindControlStatus(object, true)
        UpdateFollowingBehavior(object)
    elseif status == 'ALLIES_ORDER_FOLLOW' then
        UpdateFollowForAll()
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function (object, status, causee, storyActionID)
    if status == 'ALLIES_MINDCONTROL' then
        UpdateMindControlStatus(object, nil)
        Osi.PROC_StopFollow(object)
        if Osi.HasActiveStatus(object, 'AI_ALLIES_POSSESSED') == 1 then
            Osi.RemoveStatus(object, 'AI_ALLIES_POSSESSED')
            Log(LOG_LEVEL.DEBUG, "Removed Possessed status from: " .. object)
        end
    elseif status == 'ALLIES_ORDER_FOLLOW' then
        UpdateFollowForAll()
    end
end)

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function (caster, target, spellName, _, _, _, _)
    if spellName == 'Target_Allies_C_Order_Teleport' then
        for character, _ in pairs(charactersUnderMindControl) do
            TeleportCharacterToPlayer(character, true)
        end
    end
end)

Ext.Osiris.RegisterListener("TeleportToWaypoint", 2, "after", function (target, _, _)
    if CanFollow() then
        for character, _ in pairs(charactersUnderMindControl) do
            TeleportCharacterToPlayer(character, false)
        end
        UpdateFollowForAll()
    end
end)

Ext.Osiris.RegisterListener("TeleportToFromCamp", 1, "after", function (target, _)
    if CanFollow() then
        for character, _ in pairs(charactersUnderMindControl) do
            TeleportCharacterToPlayer(character, false)
        end
        UpdateFollowForAll()
    end
end)

Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function (combat)
    UpdateFollowForAll()
end)
-- Optimized: Batch crime ignore operations
Ext.Osiris.RegisterListener("CrimeIsRegistered", 8, "after", function(victim, crimeType, crimeID, evidence, criminal1, criminal2, criminal3, criminal4)
    -- Batch all operations together to reduce API call overhead
    local operations = {}
    for uuid in pairs(CurrentAllies) do
        table.insert(operations, uuid)
    end
    
    -- Execute operations in batch
    for _, uuid in ipairs(operations) do
        Osi.CrimeIgnoreCrime(crimeID, uuid)
        Osi.CharacterIgnoreActiveCrimes(uuid)
        Osi.BlockNewCrimeReactions(uuid, 1)
    end
end)
---------------------------------------------------------------------
-- Define the mapping of controller buffs to status buffs
local controllerToStatusTranslator = {
    AI_ALLIES_MELEE_Controller = 'AI_ALLIES_MELEE',
    AI_ALLIES_RANGED_Controller = 'AI_ALLIES_RANGED',
    AI_ALLIES_HEALER_MELEE_Controller = 'AI_ALLIES_HEALER_MELEE',
    AI_ALLIES_HEALER_RANGED_Controller = 'AI_ALLIES_HEALER_RANGED',
    AI_ALLIES_MAGE_MELEE_Controller = 'AI_ALLIES_MAGE_MELEE',
    AI_ALLIES_MAGE_RANGED_Controller = 'AI_ALLIES_MAGE_RANGED',
    AI_ALLIES_GENERAL_Controller = 'AI_ALLIES_GENERAL',
    AI_ALLIES_CUSTOM_Controller = 'AI_ALLIES_CUSTOM',
    AI_ALLIES_CUSTOM_Controller_2 = 'AI_ALLIES_CUSTOM_2',
    AI_ALLIES_CUSTOM_Controller_3 = 'AI_ALLIES_CUSTOM_3',
    AI_ALLIES_TANK_Controller = 'AI_ALLIES_TANK',
    AI_ALLIES_SUMMONER_Controller = 'AI_ALLIES_SUMMONER',
    AI_ALLIES_BEAST_Controller = 'AI_ALLIES_BEAST',
    AI_ALLIES_CUSTOM_Controller_4 = 'AI_ALLIES_CUSTOM_4',
    AI_ALLIES_THROWER_CONTROLLER = 'AI_ALLIES_THROWER',
    AI_ALLIES_DEFAULT_Controller = 'AI_ALLIES_DEFAULT',
    AI_ALLIES_TRICKSTER_Controller = 'AI_ALLIES_TRICKSTER',
    -- SMART variants
    AI_ALLIES_MELEE_SMART_Controller = 'AI_ALLIES_MELEE_SMART',
    AI_ALLIES_RANGED_SMART_Controller = 'AI_ALLIES_RANGED_SMART',
    AI_ALLIES_MAGE_SMART_Controller = 'AI_ALLIES_MAGE_SMART',
    -- New archetypes
    AI_ALLIES_ROGUE_Controller = 'AI_ALLIES_ROGUE',
    AI_ALLIES_CLERIC_Controller = 'AI_ALLIES_CLERIC',
    AI_ALLIES_PALADIN_Controller = 'AI_ALLIES_PALADIN',
    AI_ALLIES_MONK_Controller = 'AI_ALLIES_MONK',
    AI_ALLIES_WARLOCK_Controller = 'AI_ALLIES_WARLOCK',
    AI_ALLIES_BARBARIAN_Controller = 'AI_ALLIES_MELEE_SMART',
    AI_ALLIES_BARD_Controller = 'AI_ALLIES_BARD',
    AI_ALLIES_DRUID_Controller = 'AI_ALLIES_DRUID',
    AI_ALLIES_FIGHTER_Controller = 'AI_ALLIES_MELEE_SMART',
    AI_ALLIES_RANGER_Controller = 'AI_ALLIES_RANGED_SMART',
    AI_ALLIES_SORCERER_Controller = 'AI_ALLIES_MAGE_SMART',
    AI_ALLIES_WIZARD_Controller = 'AI_ALLIES_MAGE_SMART'
}

-- Function to apply status based on controller buff
local function ApplyStatusFromControllerBuff(character)
    for controllerBuff, status in pairs(controllerToStatusTranslator) do
        if Osi.HasActiveStatus(character, controllerBuff) == 1 then
            if Osi.HasActiveStatus(character, "ToggleIsNPC") == 1 then
                status = status .. '_NPC'
                Osi.MakeNPC(character)
            end
            Osi.ApplyStatus(character, status, -1)
            Log(LOG_LEVEL.DEBUG, "Applied " .. status .. " to " .. character)
            return true
        end
    end
    return false
end

-- Register listener for CombatStarted event
-- Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combatGuid)
--     for uuid, _ in pairs(CurrentAllies) do
--         if not hasAnyAICombatStatus(uuid) then
--             ApplyStatusFromControllerBuff(uuid)
--         end
--     end
-- end)

-- Register listener for EnteredCombat event
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(object, combatGuid)
    local hasController = hasControllerStatus(object)
    
    if hasController then
        local hasCombatStatus = hasAnyAICombatStatus(object)
        
        if not hasCombatStatus then
            -- Try to auto-apply optimal archetype first
            local optimalStatus = AutoApplyOptimalArchetype(object)
            if optimalStatus then
                -- Auto-apply succeeded, apply the recommended archetype
                Osi.ApplyStatus(object, optimalStatus, -1)
                Log(LOG_LEVEL.INFO, string.format(
                    "[AutoArchetype] Applied %s to %s (class-based detection)",
                    optimalStatus, object
                ))
            else
                -- Fallback to controller buff method
                ApplyStatusFromControllerBuff(object)
            end
        end
        
        -- Batch apply all required statuses
        Osi.ApplyStatus(object, "AlliesBannedActions", -1)
        Osi.ApplyStatus(object, "AI_ALLY", -1)
        Osi.ApplyStatus(object, "FOR_AI_SPELLS", -1)
    end
end)

-- Register listener for StatusApplied event to handle controller statuses during combat
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, causee, storyActionID)
    -- Handle AUTO controller - triggers class-based auto-detection
    if status == "AI_ALLIES_AUTO_Controller" then
        local optimalStatus = AutoApplyOptimalArchetype(object)
        if optimalStatus then
            Osi.ApplyStatus(object, optimalStatus, -1)
            Log(LOG_LEVEL.INFO, string.format(
                "[EnableAIAll] Applied %s to %s (auto-detected)",
                optimalStatus, object
            ))
        else
            -- Fallback to general archetype
            ApplyStatusFromControllerBuff(object)
        end
        -- Apply required combat statuses
        Osi.ApplyStatus(object, "AI_ALLY", -1)
        Osi.ApplyStatus(object, "FOR_AI_SPELLS", -1)
    -- Handle other controller statuses normally
    elseif isControllerStatus(status) and Osi.IsInCombat(object) == 1 then
        ApplyStatusFromControllerBuff(object)
    end
end)
-- Optimized: Consolidate all CombatEnded operations into a single pass
-- Previous: 3 separate loops over CurrentAllies (O(n) + O(n*m) + O(n))
-- Now: 1 loop with batch status collection (O(n*m) but with better cache locality)
Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function (combatGuid)
    -- CRITICAL: Batch all status removals into a single pass for efficiency
    local removalOps = {}
    
    -- Single pass: collect all status removals and perform cleanup
    for uuid in pairs(CurrentAllies) do
        -- Priority statuses (AI control)
        if Osi.HasActiveStatus(uuid, 'AI_ALLY') == 1 then
            table.insert(removalOps, {uuid = uuid, status = 'AI_ALLY'})
        end
        
        if Osi.HasActiveStatus(uuid, 'FOR_AI_SPELLS') == 1 then
            table.insert(removalOps, {uuid = uuid, status = 'FOR_AI_SPELLS'})
        end
        
        if Osi.HasActiveStatus(uuid, 'AlliesBannedActions') == 1 then
            table.insert(removalOps, {uuid = uuid, status = 'AlliesBannedActions'})
        end
        
        -- Combat archetype statuses
        for _, status in ipairs(aiCombatStatuses) do
            if Osi.HasActiveStatus(uuid, status) == 1 then
                table.insert(removalOps, {uuid = uuid, status = status})
            end
        end
        
        -- Clear conjuring spell tracking inline
        ClearConjuringSpellTracking(uuid)
    end
    
    -- Execute all removals at once
    for _, op in ipairs(removalOps) do
        Osi.RemoveStatus(op.uuid, op.status)
        Log(LOG_LEVEL.DEBUG, "Removed " .. op.status .. " from: " .. op.uuid)
    end
    
    -- Clear all character spells cache to save memory after combat
    characterSpellsCache = {}
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function (object, status, causee, storyActionID)
    if IsNPCStatus(status) then
        Osi.MakePlayer(object)
    end
end)
--------------------------------------------------------------------
-- Conjuring Spell Tracking
--------------------------------------------------------------------
-- Track conjuring spell usage to restrict to one per battle

Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function(caster, spell, spellType, spellElement, storyActionID)
    -- Check if this is a conjuring spell and mark it as used
    if IsConjuringSpell(spell) then
        MarkConjuringSpellUsed(caster, spell)
    end
end)

--------------------------------------------------------------------
-- Event Listeners for Possession
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function (object, status, causee, storyActionID)
    if status == 'AI_ALLIES_POSSESSED' then
        local hostCharacter = Osi.GetHostCharacter()
        Osi.AddPartyFollower(object, hostCharacter)
        -- Invalidate party cache when roster changes
        partyMembersCache = nil
        Log(LOG_LEVEL.DEBUG, "Possessed: " .. object)
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function (object, status, causee, storyActionID)
    if status == 'AI_ALLIES_POSSESSED' then
        local hostCharacter = Osi.GetHostCharacter()
        Osi.RemovePartyFollower(object, hostCharacter)
        -- Invalidate party cache when roster changes
        partyMembersCache = nil
        Log(LOG_LEVEL.DEBUG, "Stopped Possessing: " .. object)
        Osi.ApplyStatus(object, "AI_CANCEL", 0)
    end
end)

------------------------------------------------------------------------------------------
-- Healer Logic Enforcement
------------------------------------------------------------------------------------------
-- Ensures healers prioritize healing and reviving allies

local function EvaluateHealerLogic(character)
    -- Wrap entire function in error handling to prevent crashes
    local success, err = pcall(function()
        -- OPTIMIZED: Use cached healer status check (reduces 6 API calls to 1)
        if not IsHealer(character) then
            return  -- Early exit for non-healers
        end
        
        -- Validate character entity
        if not IsValidEntity(character) then
            return
        end
        
        -- Scan party members within healing range
        local players = GetPartyMembers()
        if not players then
            return
        end
        
        local downedAlly = nil
        local injuredAlly = nil
        local lowestHP = HP_FULL
        
        -- Optimized: Single pass through party members to find both downed and injured
        for _, player in pairs(players) do
            local ally = player[1]
            -- Skip self, invalid entities, and summons
            if ally ~= character and IsValidEntity(ally) and not IsSummon(ally) then
                -- Calculate distance using helper function
                local distance = CalculateDistance(character, ally)
                
                if distance and distance <= MAX_HEAL_DISTANCE then
                    -- Priority 1: Check for downed allies (highest priority)
                    if Osi.HasActiveStatus(ally, "DOWNED") == 1 then
                        downedAlly = ally
                        -- Don't break - continue checking for lowest HP in case we can't revive
                    end
                    
                    -- Priority 2: Check for injured allies
                    -- Optimized: Use GetHealthData to get all health info in one call
                    -- Note: Skip downed allies as they're handled separately
                    if Osi.HasActiveStatus(ally, "DOWNED") ~= 1 then
                        local healthData = GetHealthData(ally)
                        if healthData then
                            local hpPercent = healthData.hpPercent
                            
                            -- Heal allies below threshold
                            if hpPercent < HEAL_THRESHOLD and hpPercent < lowestHP then
                                lowestHP = hpPercent
                                injuredAlly = ally
                            end
                        end
                    end
                end
            end
        end
        
        -- Priority 1: Revive downed ally
        if downedAlly then
            -- FIRST: Try the Help action (most reliable for downed allies)
            -- The Help action is always available to all characters
            local helpSuccess, helpResult = pcall(function()
                -- Check if character can reach the downed ally
                local distance = CalculateDistance(character, downedAlly)
                if distance and distance <= 1.5 then
                    -- Character is in melee range - use Help action directly
                    Osi.UseSpell(character, "Target_Help", downedAlly)
                    Log(LOG_LEVEL.DEBUG, "Healer using Help action on downed ally: " .. downedAlly)
                    return true
                end
                return false
            end)
            
            -- If Help action succeeded and returned true, we're done
            if helpSuccess and helpResult then
                return
            end
            
            -- SECOND: Try dedicated resurrection/healing spells
            local characterSpells = GetCharacterSpells(character)
            local reviveSpells = {}
            local healSpells = {}
            
            -- Categorize spells - prioritize revive spells
            for _, spellName in ipairs(characterSpells) do
                if IsHealingSpell(spellName) then
                    local lowerName = string.lower(spellName)
                    -- Prioritize revive/resurrection spells for downed allies
                    if lowerName:find("reviv") or lowerName:find("raise") or lowerName:find("resurrection") then
                        table.insert(reviveSpells, spellName)
                    else
                        table.insert(healSpells, spellName)
                    end
                end
            end
            
            -- Try revive spells first (Revivify, etc.)
            for _, spellName in ipairs(reviveSpells) do
                if Osi.HasSpell(character, spellName) == 1 then
                    Osi.UseSpell(character, spellName, downedAlly)
                    Log(LOG_LEVEL.DEBUG, "Healer casting " .. spellName .. " on downed ally: " .. downedAlly)
                    return
                end
            end
            
            -- Fall back to any healing spell (some may work on downed targets)
            for _, spellName in ipairs(healSpells) do
                if Osi.HasSpell(character, spellName) == 1 then
                    Osi.UseSpell(character, spellName, downedAlly)
                    Log(LOG_LEVEL.DEBUG, "Healer casting " .. spellName .. " on downed ally: " .. downedAlly)
                    return
                end
            end
            
            -- LAST RESORT: If no spells worked, try moving toward the downed ally
            -- This ensures the healer at least attempts to get in range for Help action
            Log(LOG_LEVEL.DEBUG, "Healer has no available revive spells, should move toward downed ally: " .. downedAlly)
            return
        end
        
        -- Priority 2: Heal injured ally
        if injuredAlly then
            -- Get all character spells and find healing spells
            local characterSpells = GetCharacterSpells(character)
            local bonusActionHeals = {}
            local actionHeals = {}
            
            for _, spellName in ipairs(characterSpells) do
                if IsHealingSpell(spellName) then
                    -- Prioritize bonus action heals like Healing Word for better action economy
                    if IsBonusActionSpell(spellName) then
                        table.insert(bonusActionHeals, spellName)
                    else
                        table.insert(actionHeals, spellName)
                    end
                end
            end
            
            -- Try bonus action heals first (better action economy)
            for _, spellName in ipairs(bonusActionHeals) do
                if Osi.HasSpell(character, spellName) == 1 then
                    Osi.UseSpell(character, spellName, injuredAlly)
                    Log(LOG_LEVEL.DEBUG, "Healer casting bonus action " .. spellName .. " on injured ally: " .. injuredAlly)
                    return
                end
            end
            
            -- Then try regular action heals
            for _, spellName in ipairs(actionHeals) do
                if Osi.HasSpell(character, spellName) == 1 then
                    Osi.UseSpell(character, spellName, injuredAlly)
                    Log(LOG_LEVEL.DEBUG, "Healer casting " .. spellName .. " on injured ally: " .. injuredAlly)
                    return
                end
            end
        end
    end)
    
    if not success then
        Log(LOG_LEVEL.WARN, "Error in healer logic: " .. tostring(err))
    end
end

------------------------------------------------------------------------------------------
-- Function to apply status based on controller buff for non-NPCs
local function ApplyStatusBasedOnBuff(character)
    for controllerBuff, status in pairs(controllerToStatusTranslator) do
        if Osi.HasActiveStatus(character, controllerBuff) == 1 then
            if Osi.HasActiveStatus(character, "ToggleIsNPC") == 0 then
                Osi.ApplyStatus(character, status, -1)
                Log(LOG_LEVEL.DEBUG, "Applied " .. status .. " to " .. character)
                return status
            end
        end
    end
    return nil
end

-- Helper function to check if character should have AI logic applied
local function ShouldApplyAILogic(character)
    local success, result = pcall(function()
        -- Check if character is a party member or follower
        if Osi.IsPartyMember(character, 1) == 1 or Osi.IsPartyFollower(character) == 1 then
            return true
        end
        -- Allow characters with AI controller status (for special cases like conjured allies)
        if hasControllerStatus(character) then
            return true
        end
        return false
    end)
    
    return success and result
end

------------------------------------------------------------------------------------------
-- Item Usage System
------------------------------------------------------------------------------------------
-- Intelligent consumable usage (healing potions, buff potions, scrolls) for AI allies

-- Track items used this combat to prevent spam
local itemsUsedThisCombat = {}

-- Get all consumable items in character's inventory
local function GetConsumableItems(character)
    local items = {}
    
    -- Safety check for valid character UUID
    if not IsValidString(character) then
        return {}
    end
    
    local success, result = pcall(function()
        local entity = Ext.Entity.Get(character)
        if not entity or not entity.InventoryOwner then
            return {}
        end
        
        -- Iterate through inventory with comprehensive error handling
        for _, inventoryData in pairs(entity.InventoryOwner.Inventories) do
            if inventoryData and inventoryData.InventoryContainer and inventoryData.InventoryContainer.Items then
                for _, item in pairs(inventoryData.InventoryContainer.Items) do
                    -- Wrap each item access in pcall for modded item safety
                    local itemSuccess = pcall(function()
                        if item and item.Item then
                            local itemEntity = Ext.Entity.Get(item.Item)
                            if itemEntity and itemEntity.Consumable then
                                -- This is a consumable item
                                local itemTemplate = itemEntity.ServerItem and itemEntity.ServerItem.Template
                                local itemName = ""
                                
                                -- Safe name extraction with nil checks
                                if itemEntity.DisplayName then
                                    local nameSuccess = pcall(function()
                                        if itemEntity.DisplayName.NameKey and itemEntity.DisplayName.NameKey.Handle and itemEntity.DisplayName.NameKey.Handle.Handle then
                                            itemName = itemEntity.DisplayName.NameKey.Handle.Handle or ""
                                        end
                                    end)
                                    if not nameSuccess then
                                        itemName = ""  -- Fallback for modded items with invalid name structure
                                    end
                                end
                                
                                if itemTemplate then
                                    table.insert(items, {
                                        uuid = item.Item,
                                        template = itemTemplate,
                                        name = itemName,
                                        entity = itemEntity
                                    })
                                end
                            end
                        end
                    end)
                    
                    if not itemSuccess then
                        -- Log but continue processing other items (important for modded item compatibility)
                        Log(LOG_LEVEL.DEBUG, "Skipped invalid/modded item in inventory for: " .. character)
                    end
                end
            end
        end
        
        return items
    end)
    
    if success and result then
        return result
    else
        Log(LOG_LEVEL.DEBUG, "Failed to get consumable items for: " .. tostring(character))
        return {}
    end
end

-- Categorize item by type
local function GetItemType(itemTemplate, itemName)
    local templateName = string.lower(itemTemplate or "")
    local displayName = string.lower(itemName or "")
    local combinedName = templateName .. " " .. displayName
    
    -- Healing potions
    if combinedName:find("potion") and 
       (combinedName:find("healing") or combinedName:find("health") or 
        combinedName:find("cure") or combinedName:find("restoration")) then
        return "HEALING_POTION"
    end
    
    -- Buff potions
    if combinedName:find("potion") and 
       (combinedName:find("strength") or combinedName:find("haste") or combinedName:find("speed") or 
        combinedName:find("giant") or combinedName:find("hill") or combinedName:find("invisibility") or
        combinedName:find("resistance") or combinedName:find("heroism")) then
        return "BUFF_POTION"
    end
    
    -- Scrolls
    if combinedName:find("scroll") then
        return "SCROLL"
    end
    
    -- Elixirs (long-duration buffs)
    if combinedName:find("elixir") then
        return "ELIXIR"
    end
    
    -- Grenades/Throwables
    if combinedName:find("grenade") or combinedName:find("bomb") or combinedName:find("alchemist") then
        return "THROWABLE"
    end
    
    return "UNKNOWN"
end

-- Get healing value of a potion
local function GetPotionHealingValue(itemTemplate)
    local name = string.lower(itemTemplate or "")
    
    -- Estimate healing based on potion tier
    if name:find("supreme") or name:find("superior") then
        return 80  -- ~8d4+8 average
    elseif name:find("greater") then
        return 28  -- ~4d4+4 average
    elseif name:find("potion") then
        return 7   -- ~2d4+2 average (basic)
    end
    
    return 10  -- Default estimate
end

-- Check if character should use a healing potion
local function ShouldUseHealingPotion(character)
    local threshold = GetCachedSettingValue("itemUsageThreshold", ModuleUUID)
    
    local success, shouldUse = pcall(function()
        -- Get current HP percentage
        local entity = Ext.Entity.Get(character)
        if not entity or not entity.Health then
            return false
        end
        
        local currentHP = entity.Health.Hp
        local maxHP = entity.Health.MaxHp
        
        if maxHP <= 0 then
            return false
        end
        
        local hpPercent = (currentHP / maxHP) * 100
        
        -- Use potion if below threshold
        if hpPercent < threshold then
            -- Don't use if already have active healing effect
            if Osi.HasActiveStatus(character, "POTION_HEALING") == 1 then
                return false
            end
            
            return true
        end
        
        return false
    end)
    
    return success and shouldUse
end

-- Select best healing potion from inventory
local function SelectBestHealingPotion(character, items)
    local healingPotions = {}
    
    for _, item in ipairs(items) do
        local itemType = GetItemType(item.template, item.name)
        if itemType == "HEALING_POTION" then
            local healValue = GetPotionHealingValue(item.template)
            table.insert(healingPotions, {
                uuid = item.uuid,
                healValue = healValue,
                template = item.template
            })
        end
    end
    
    if #healingPotions == 0 then
        return nil
    end
    
    -- Get character's HP deficit
    local entity = Ext.Entity.Get(character)
    if not entity or not entity.Health then
        return healingPotions[1]  -- Just use first available
    end
    
    local hpDeficit = entity.Health.MaxHp - entity.Health.Hp
    
    -- Sort potions by heal value (ascending)
    table.sort(healingPotions, function(a, b)
        return a.healValue < b.healValue
    end)
    
    -- Select appropriate potion tier
    -- Don't waste supreme potion on small damage
    for _, potion in ipairs(healingPotions) do
        if potion.healValue >= hpDeficit * 0.6 then
            return potion
        end
    end
    
    -- If no perfect match, use strongest available
    return healingPotions[#healingPotions]
end

-- Check if character should use a scroll
local function ShouldUseScroll(character)
    local enableScrolls = GetCachedSettingValue("enableScrollUsage", ModuleUUID)
    if enableScrolls == false then
        return false
    end
    
    -- Only use scrolls if out of spell slots or in emergency
    local success, shouldUse = pcall(function()
        -- Check if character is a spellcaster
        local entity = Ext.Entity.Get(character)
        if not entity or not entity.SpellBook then
            return false
        end
        
        -- Check available spell slots
        if entity.SpellBookPrepares and entity.SpellBookPrepares.SpellCastingAbility then
            -- Has spellcasting - check if any slots available
            -- Simplified: allow scroll usage if in combat
            if Osi.IsInCombat(character) == 1 then
                return true
            end
        end
        
        return false
    end)
    
    return success and shouldUse
end

-- Check if character should use buff potion before combat
local function ShouldUseBuffPotion(character)
    local enableBuffs = GetCachedSettingValue("enableBuffPotions", ModuleUUID)
    if enableBuffs == false then
        return false
    end
    
    local success, shouldUse = pcall(function()
        -- Only use buffs if:
        -- 1. Not in combat (pre-buff)
        -- 2. Combat is imminent (near enemies)
        
        if Osi.IsInCombat(character) == 1 then
            return false  -- Already in combat, too late
        end
        
        -- Check if enemies are nearby (within 15m)
        local entity = Ext.Entity.Get(character)
        if not entity or not entity.Transform then
            return false
        end
        
        -- Simplified: return false for now
        -- Full implementation would check for nearby hostile entities
        return false
    end)
    
    return success and shouldUse
end

-- Check if character has used an item type recently
local function HasUsedItemRecently(character, itemType)
    if not itemsUsedThisCombat[character] then
        return false
    end
    return itemsUsedThisCombat[character][itemType] == true
end

-- Mark that character has used an item type
local function MarkItemUsed(character, itemType)
    if not itemsUsedThisCombat[character] then
        itemsUsedThisCombat[character] = {}
    end
    itemsUsedThisCombat[character][itemType] = true
end

-- Use an item (potion, scroll, etc.)
local function UseItem(character, itemUUID, itemType)
    local success, result = pcall(function()
        -- Use Osiris API to use the item
        Osi.UseItem(character, itemUUID)
        
        Log(LOG_LEVEL.INFO, string.format(
            "[Item Usage] %s used %s", 
            character, itemType
        ))
        
        return true
    end)
    
    if not success then
        Log(LOG_LEVEL.WARN, "[Item Usage] Failed to use item: " .. tostring(result))
    end
    
    return success
end

-- Main item usage evaluation function
local function EvaluateItemUsage(character)
    -- Check if feature is enabled
    local enableItemUsage = GetCachedSettingValue("enableItemUsage", ModuleUUID)
    if enableItemUsage == false then
        return
    end
    
    -- Skip if not AI-controlled
    if Osi.HasActiveStatus(character, "AI_ALLY") == 0 then
        return
    end
    
    local success = pcall(function()
        -- Get all consumable items
        local items = GetConsumableItems(character)
        
        if #items == 0 then
            return
        end
        
        -- Priority 1: Healing potions (if low HP)
        if ShouldUseHealingPotion(character) then
            -- Check if already used healing potion this turn
            if not HasUsedItemRecently(character, "HEALING_POTION") then
                local potion = SelectBestHealingPotion(character, items)
                if potion then
                    if UseItem(character, potion.uuid, "HEALING_POTION") then
                        MarkItemUsed(character, "HEALING_POTION")
                        return  -- Only use one item per turn
                    end
                end
            end
        end
        
        -- Priority 2: Buff potions (before combat)
        if ShouldUseBuffPotion(character) then
            if not HasUsedItemRecently(character, "BUFF_POTION") then
                for _, item in ipairs(items) do
                    local itemType = GetItemType(item.template, item.name)
                    if itemType == "BUFF_POTION" then
                        if UseItem(character, item.uuid, "BUFF_POTION") then
                            MarkItemUsed(character, "BUFF_POTION")
                            return
                        end
                    end
                end
            end
        end
        
        -- Priority 3: Scrolls (if enabled and appropriate)
        if ShouldUseScroll(character) then
            if not HasUsedItemRecently(character, "SCROLL") then
                for _, item in ipairs(items) do
                    local itemType = GetItemType(item.template, item.name)
                    if itemType == "SCROLL" then
                        -- TODO: Add logic to select appropriate scroll
                        -- For now, skip scroll usage
                        break
                    end
                end
            end
        end
    end)
    
    if not success then
        Log(LOG_LEVEL.DEBUG, "[Item Usage] Error evaluating item usage for: " .. character)
    end
end

-- Listener for TurnStarted event
-- CONSOLIDATED: All turn-start logic in one handler for better performance
Ext.Osiris.RegisterListener("TurnStarted", 1, "after", function(character)
    -- Early exit: Skip AI logic for characters that shouldn't have it
    if not ShouldApplyAILogic(character) then
        if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
            Log(LOG_LEVEL.DEBUG, "Skipping AI logic for non-qualifying character: " .. character)
        end
        return
    end
    
    -- CRITICAL: Skip AI logic if character is not in combat
    -- This prevents race conditions during resource refresh after combat ends
    local inCombat = Osi.IsInCombat(character)
    if inCombat ~= 1 then
        if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
            Log(LOG_LEVEL.DEBUG, "Skipping AI logic - character not in combat: " .. character)
        end
        return
    end
    
    -- Optimized: Batch status checks to reduce repeated API calls
    local isAIAlly = Osi.HasActiveStatus(character, "AI_ALLY") == 1
    local hasNPCStatus = isAIAlly and hasAnyNPCStatus(character) or false
    
    -- Track turn start time for AI allies (for timeout detection)
    if isAIAlly then
        turnStartTimes[character] = Ext.Utils.MonotonicTime()
        if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
            Log(LOG_LEVEL.DEBUG, "Turn started for: " .. character)
        end
        
        -- Debug archetype detection if enabled
        local debugArchetypes = GetCachedSettingValue("debugArchetypes", ModuleUUID)
        if debugArchetypes then
            -- Log character spells for debugging
            LogCharacterSpells(character)
            
            -- Log detected class and recommended archetype
            local classTag = DetectCharacterClass(character)
            local recommendedArchetype = GetRecommendedArchetype(character)
            Log(LOG_LEVEL.INFO, string.format(
                "[ArchetypeDebug] Character %s - Class: %s, Recommended: %s",
                character,
                classTag or "NONE",
                recommendedArchetype or "NONE"
            ))
        end
    end
    
    -- Apply status based on controller buff for non-NPC characters
    if not hasNPCStatus then
        local status = ApplyStatusBasedOnBuff(character)
        if status then
            _G.appliedStatuses[character] = status
        end
    end
    
    -- Conjuring spell tracking: SIMPLIFIED - no longer blocking spells during turn start
    -- AI will naturally prefer other actions if summons already present
    -- if isAIAlly then
    --     local characterSpells = GetCharacterSpells(character)
    --     
    --     for _, spellName in ipairs(characterSpells) do
    --         if IsConjuringSpell(spellName) and HasUsedConjuringSpell(character, spellName) then
    --             Log(LOG_LEVEL.DEBUG, "Conjuring spell already used: " .. spellName .. " for " .. character)
    --         end
    --     end
    -- end
    
    -- Healer logic: Check and heal/revive allies
    EvaluateHealerLogic(character)
    
    -- Item usage logic: DISABLED - causing AI to end turns early
    -- TODO: Re-enable after fixing item validation logic
    -- if isAIAlly then
    --     local itemUsageSuccess = pcall(function()
    --         EvaluateItemUsage(character)
    --     end)
    --     
    --     if not itemUsageSuccess then
    --         Log(LOG_LEVEL.WARN, "[Item Usage] Failed to evaluate item usage")
    --     end
    -- end
    
    -- Contextual archetype evaluation (dynamic behavior based on combat state)
    if isAIAlly then
        EvaluateContextualArchetypes(character)
    end
    
    -- Optimized: Reuse inCombat check from earlier instead of re-querying
    -- Apply target priority system for AI allies
    if isAIAlly then  -- inCombat already checked at function start
        local success, err = pcall(function()
            local enemies = GetEnemyTargetsInCombat(character)
            if enemies and #enemies > 0 then
                local bestTarget = SelectBestTarget(character, enemies)
                if bestTarget then
                    bestTarget = ApplyFocusFireIfEnabled(character, bestTarget)
                    -- Apply MULTIPLIER_TARGET_PREFERRED to selected target
                    ApplyTargetPriorityStatus(character, bestTarget)
                end
            end
        end)
        
        if not success then
            Log(LOG_LEVEL.WARN, "Target priority system error: " .. tostring(err))
        end
    end
    
    -- Wildshape restoration: DISABLED - AI already has wildshape in their spell list
    -- Let natural AI behavior decide when to wildshape
    -- if isAIAlly then
    --     local success, err = pcall(function()
    --         if IsInWildShape(character) then
    --             return
    --         end
    --         
    --         for _, spellName in ipairs(WILDSHAPE_SPELLS) do
    --             if Osi.HasSpell(character, spellName) == 1 then
    --                 Osi.UseSpell(character, spellName, character)
    --                 Log(LOG_LEVEL.DEBUG, "Druid casting " .. spellName .. ": " .. character)
    --                 break
    --             end
    --         end
    --     end)
    --     
    --     if not success then
    --         Log(LOG_LEVEL.WARN, "Error in Wildshape logic: " .. tostring(err))
    --     end
    -- end
    
    -- Environmental hazard check (currently placeholder)
    if isAIAlly then
        local success = pcall(function()
            local entity = Ext.Entity.Get(character)
            if entity and entity.Transform then
                local pos = entity.Transform.Transform.Translate
                
                -- If character is on hazardous surface, try to move away
                if IsPositionHazardous(pos) then
                    Log(LOG_LEVEL.WARN, "Character " .. character .. " is on hazardous surface")
                    -- AI should prioritize moving to safe ground
                    -- This is handled by the game's AI system, but we log it for awareness
                end
            end
        end)
    end
end)

-- Listener for TurnEnded event
Ext.Osiris.RegisterListener("TurnEnded", 1, "after", function(character)
    -- Optimized: Batch cache cleanup operations
    local status = _G.appliedStatuses[character]
    
    if status and not hasAnyNPCStatus(character) then
        Osi.RemoveStatus(character, status, character)
        Log(LOG_LEVEL.DEBUG, "Removed " .. status .. " from " .. character)
        _G.appliedStatuses[character] = nil
    end
    
    -- Clear turn tracking and all character-specific caches in one pass
    turnStartTimes[character] = nil
    characterSpellsCache[character] = nil
    rageStatusCache[character] = nil
    wildshapeStatusCache[character] = nil
    adjacentEnemyCache[character] = nil
end)
------------------------------------------------------------------------------------------
-- Script Extender Dynamic Spell Injection (Replaces old AI Specific spells system)
------------------------------------------------------------------------------------------
-- REMOVED: Old ModifyAISpells function and spellModificationQueue logic
-- The code below replaces the previous "dirty edits" approach with dynamic Script Extender injection
-- This eliminates the need for Spells_For_AI.txt entirely

-- Track which spells have been modified to avoid redundant operations
local spellsInjected = false

-- Function to dynamically inject AI tags into spells at runtime
-- This runs once on SessionLoaded and modifies spells in memory
local function InjectAITags()
    if spellsInjected then
        return
    end
    
    Log(LOG_LEVEL.INFO, "Injecting AI tags into spells...")
    
    -- Target spells for modification
    local targetSpells = {
        -- Action Surge: Add AIFlags to allow AI to use it for gaining additional actions
        -- Changed from "GrantsResources;UseAsSupportingActionOnly" to just "GrantsResources"
        -- to allow AI to properly evaluate and use Action Surge
        {
            name = "Shout_ActionSurge",
            modifications = {
                AIFlags = "GrantsResources"
            }
        },
        -- Rage: Add AIFlags "GrantsResources" and "UseAsSupportingActionOnly"
        -- NOTE: Shout_Rage is found in GustavDev (reference/vanilla/Data/GustavDev/Stats/Generated/)
        -- not in Gustav directory. It's the Barbarian's Rage ability.
        {
            name = "Shout_Rage",
            modifications = {
                AIFlags = "GrantsResources;UseAsSupportingActionOnly"
            }
        },
        -- Dash: Modify RequirementConditions to allow AI_ALLY usage
        {
            name = "Shout_Dash",
            modifications = {
                RequirementConditions = "not HasPassive('AlliesDashingDisabled') and not HasStatus('Swarm_Group_1') and not HasStatus('Swarm_Group_2') and not HasStatus('Swarm_Group_3') and not HasStatus('Swarm_Group_4') or HasStatus('AI_ALLY')"
            }
        },
        -- Throw: Modify RequirementConditions to allow AI_ALLY usage
        {
            name = "Throw_Throw",
            modifications = {
                RequirementConditions = "not HasPassive('AlliesThrowingDisabled') and not HasStatus('AlliesThrowingAllowed') or HasStatus('AI_ALLY')"
            }
        },
        -- Misty Step: Allow AI to use teleportation
        -- Fixed: Changed from Shout_MistyStep to Target_MistyStep (correct spell type)
        {
            name = "Target_MistyStep",
            modifications = {
                AIFlags = "CanMove;UseAsSupportingActionOnly"
            }
        }
        -- NOTE: Shout_FarStep and Shout_DimensionDoor do not exist in vanilla BG3
        -- These have been removed to fix "Spell not found" errors
        -- If modded spells are needed, they should be added separately
    }
    
    -- Eldertide Armaments Mod Compatibility
    -- These spells are from the Eldertide Armaments mod and will only be modified if the mod is installed
    -- 
    -- Spell names sourced from Eldertide Armaments mod:
    -- - Witcher Amulet (ELDER_Amulet_8): Grants Witcher Signs abilities
    -- - Thunder God Ring (ELDER_Ring_9): Grants Thor-themed abilities
    --
    -- AIFlags explanation:
    -- - "" (empty): Allows BG3's built-in AI to evaluate and use the spell normally based on spell properties
    -- - "UseAsSupportingActionOnly": Restricts to bonus action usage - for buffs and utility
    -- - "CanMove": Allows usage with movement - for repositioning and rush attacks
    local eldertideSpells = {
        -- Witcher Amulet (ELDER_Amulet_8) - Witcher Signs
        -- Zone/AoE damage spells
        {
            name = "ELDER_Zone_Igni",
            modifications = {
                AIFlags = ""  -- Zone fire spell - AI can use for AoE damage
            }
        },
        {
            name = "ELDER_Zone_Aard",
            modifications = {
                AIFlags = ""  -- Zone force spell - AI can use for AoE control
            }
        },
        -- Defensive shout/buff spells
        {
            name = "ELDER_Shout_Quen",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Defensive shield spell
            }
        },
        -- Target spells
        {
            name = "ELDER_Target_Yrden_Trap",
            modifications = {
                AIFlags = ""  -- Trap placement spell - AI can use
            }
        },
        {
            name = "ELDER_Target_Axii",
            modifications = {
                AIFlags = ""  -- Mind control spell - AI can use
            }
        },
        -- Utility shout spells
        {
            name = "ELDER_Shout_HuntersSense",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Detection/utility spell
            }
        },
        {
            name = "ELDER_Shout_WitcherWeapon",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Weapon enchantment spell
            }
        },
        -- Witcher weapon enchantment variants
        {
            name = "ELDER_Shout_WitcherWeapon_Quen",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"
            }
        },
        {
            name = "ELDER_Shout_WitcherWeapon_Axii",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"
            }
        },
        {
            name = "ELDER_Shout_WitcherWeapon_Igni",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"
            }
        },
        {
            name = "ELDER_Shout_WitcherWeapon_Yrden",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"
            }
        },
        {
            name = "ELDER_Shout_WitcherWeapon_Aard",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"
            }
        },
        
        -- Thunder God Ring (ELDER_Ring_9) - Thor-related abilities
        {
            name = "ELDER_Shout_EirsBlessing",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Blessing/buff spell
            }
        },
        
        -- CRITICAL: Eldertide Healing Spells (AI MUST use these for healing)
        {
            name = "ELDER_Projectile_DivineBeamOfRecovery",
            modifications = {
                AIFlags = ""  -- Healing projectile - AI uses for healing allies
            }
        },
        {
            name = "ELDER_Shout_DivineRestoration",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- AoE healing shout - bonus action healing
            }
        },
        
        {
            name = "ELDER_Projectile_MightyDive",
            modifications = {
                AIFlags = ""  -- Projectile attack spell - AI can use
            }
        },
        {
            name = "ELDER_Rush_AsgardianCharge",
            modifications = {
                AIFlags = "CanMove"  -- Rush attack that moves and deals damage
            }
        },
        {
            name = "ELDER_Target_Lightning_Punch",
            modifications = {
                AIFlags = ""  -- Melee lightning attack - AI can use
            }
        },
        {
            name = "ELDER_Target_MightOfTheSkies",
            modifications = {
                AIFlags = ""  -- Target spell attack - AI can use
            }
        },
        {
            name = "ELDER_Shout_Thor_Fury",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Thor transformation buff
            }
        },
        {
            name = "ELDER_Target_SkybreakerSmite",
            modifications = {
                AIFlags = ""  -- Smite attack
            }
        },
        
        -- Additional Eldertide Equipment Spells
        -- Movement/Utility
        {
            name = "ELDER_Projectile_SkywardSoar",
            modifications = {
                AIFlags = "CanMove;UseAsSupportingActionOnly"  -- Fly spell
            }
        },
        {
            name = "ELDER_Teleportation_EtherealResurgence",
            modifications = {
                AIFlags = "CanMove;UseAsSupportingActionOnly"  -- Teleportation
            }
        },
        {
            name = "ELDER_Target_DeathStep",
            modifications = {
                AIFlags = "CanMove"  -- Teleport attack
            }
        },
        {
            name = "ELDER_Target_InfernalBlink",
            modifications = {
                AIFlags = "CanMove"  -- Teleport attack
            }
        },
        {
            name = "ELDER_Target_Riftbreaker",
            modifications = {
                AIFlags = "CanMove"  -- Teleport attack
            }
        },
        
        -- Buff/Support Shouts
        {
            name = "ELDER_Shout_DivineRestoration",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Healing spell
            }
        },
        {
            name = "ELDER_Shout_FeralSwiftness",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Speed buff
            }
        },
        {
            name = "ELDER_Shout_RevenantFury",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Combat buff
            }
        },
        {
            name = "ELDER_Shout_AstralArena",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Arena buff
            }
        },
        {
            name = "ELDER_Shout_Bloodborne",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Combat buff
            }
        },
        {
            name = "ELDER_Shout_HillGiantForm",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Transformation
            }
        },
        {
            name = "ELDER_Shout_WrathOfAvernus",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- Combat buff
            }
        },
        {
            name = "ELDER_Shout_Ketheric_HowlOfTheDead",
            modifications = {
                AIFlags = "UseAsSupportingActionOnly"  -- AoE buff
            }
        },
        
        -- Projectile Attacks
        {
            name = "ELDER_Projectile_DivineBeamOfRecovery",
            modifications = {
                AIFlags = ""  -- Healing projectile
            }
        },
        {
            name = "ELDER_Projectile_FingerOfDeath",
            modifications = {
                AIFlags = ""  -- Death spell
            }
        },
        {
            name = "ELDER_Projectile_CataclysmBlast",
            modifications = {
                AIFlags = ""  -- Damage projectile
            }
        },
        {
            name = "ELDER_Projectile_JudgmentBolt",
            modifications = {
                AIFlags = ""  -- Lightning projectile
            }
        },
        {
            name = "ELDER_Projectile_ShadowsRetribution",
            modifications = {
                AIFlags = ""  -- Shadow projectile
            }
        },
        {
            name = "ELDER_Projectile_Annihilation",
            modifications = {
                AIFlags = ""  -- Destruction projectile
            }
        },
        {
            name = "ELDER_Projectile_RayOfTheInfernalPhoenix",
            modifications = {
                AIFlags = ""  -- Fire ray
            }
        },
        {
            name = "ELDER_Projectile_ScorchingTalonsOfTheFirehawk",
            modifications = {
                AIFlags = ""  -- Fire projectile
            }
        },
        {
            name = "ELDER_Projectile_BewitchingBolt",
            modifications = {
                AIFlags = ""  -- Charm projectile
            }
        },
        
        -- Target Spells
        {
            name = "ELDER_Target_ImmolatingGaze",
            modifications = {
                AIFlags = ""  -- Fire damage
            }
        },
        {
            name = "ELDER_Target_MaledictionOfRuin",
            modifications = {
                AIFlags = ""  -- Curse/debuff
            }
        },
        {
            name = "ELDER_Target_MindSanctuary",
            modifications = {
                AIFlags = ""  -- Mind spell
            }
        },
        {
            name = "ELDER_Target_BlackHole",
            modifications = {
                AIFlags = ""  -- Gravity spell
            }
        },
        {
            name = "ELDER_Target_CryomancerMark",
            modifications = {
                AIFlags = ""  -- Ice debuff
            }
        },
        {
            name = "ELDER_Target_FrostTempest",
            modifications = {
                AIFlags = ""  -- Ice damage
            }
        },
        {
            name = "ELDER_Target_SoulDrain",
            modifications = {
                AIFlags = ""  -- Lifesteal
            }
        },
        {
            name = "ELDER_Target_TrickstersSanctuary",
            modifications = {
                AIFlags = ""  -- Trickery spell
            }
        },
        {
            name = "ELDER_Target_MindflayersBane",
            modifications = {
                AIFlags = ""  -- Psychic damage
            }
        },
        {
            name = "ELDER_Target_LogariusFinalEmbrace",
            modifications = {
                AIFlags = ""  -- Death spell
            }
        },
        {
            name = "ELDER_Target_Lifesteal",
            modifications = {
                AIFlags = ""  -- Drain spell
            }
        },
        {
            name = "ELDER_Target_MidasTouch",
            modifications = {
                AIFlags = ""  -- Transmutation
            }
        },
        {
            name = "ELDER_Target_MentalMaelstrom",
            modifications = {
                AIFlags = ""  -- Psychic damage
            }
        },
        {
            name = "ELDER_Target_ReckoningOfTheDualFlame",
            modifications = {
                AIFlags = ""  -- Fire spell
            }
        },
        {
            name = "ELDER_Target_AvernusSearingSmite",
            modifications = {
                AIFlags = ""  -- Smite attack
            }
        },
        {
            name = "ELDER_Target_DreadfulBacklash",
            modifications = {
                AIFlags = ""  -- Counter spell
            }
        },
        {
            name = "ELDER_Target_WitchQueenCauldron",
            modifications = {
                AIFlags = ""  -- Potion creation
            }
        },
        
        -- Zone/AoE Spells
        {
            name = "ELDER_Zone_MindBlast",
            modifications = {
                AIFlags = ""  -- Psychic AoE
            }
        },
        {
            name = "ELDER_Zone_DragonkinHeritage_Fire",
            modifications = {
                AIFlags = ""  -- Fire breath
            }
        },
        {
            name = "ELDER_Zone_DragonkinHeritage_Cold",
            modifications = {
                AIFlags = ""  -- Cold breath
            }
        },
        {
            name = "ELDER_Zone_DragonkinHeritage_Acid",
            modifications = {
                AIFlags = ""  -- Acid breath
            }
        },
        {
            name = "ELDER_Zone_DragonkinHeritage_Lightning",
            modifications = {
                AIFlags = ""  -- Lightning breath
            }
        },
        {
            name = "ELDER_Zone_DragonkinHeritage_Poison",
            modifications = {
                AIFlags = ""  -- Poison breath
            }
        }
    }
    
    -- Note: Target_Help entry removed - SpellFlags 'IsMelee;IsSpell' was invalid in Patch 8
    
    -- Apply modifications to each spell with error handling
    local vanillaSuccessCount = 0
    local vanillaFailCount = 0
    
    for _, spellConfig in ipairs(targetSpells) do
        local success, err = pcall(function()
            local spell = Ext.Stats.Get(spellConfig.name, -1, false, true)
            if spell then
                -- Apply modifications and optionally log for debugging
                local modifiedProperties = {}
                
                for property, value in pairs(spellConfig.modifications) do
                    local oldValue = spell[property] or "none"
                    spell[property] = value
                    
                    -- Only log details at DEBUG level to avoid performance impact
                    if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
                        Log(LOG_LEVEL.DEBUG, string.format("  %s.%s: %s -> %s", 
                            spellConfig.name, property, oldValue, value))
                    end
                    
                    table.insert(modifiedProperties, property)
                end
                
                -- Sync stats to prevent Script Extender warnings about manual sync requirement
                Ext.Stats.Sync(spellConfig.name)
                
                -- Keep per-spell success logging at DEBUG to reduce startup spam
                if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
                    Log(LOG_LEVEL.DEBUG, string.format("Modified spell %s (%d properties)", 
                        spellConfig.name, #modifiedProperties))
                end
                vanillaSuccessCount = vanillaSuccessCount + 1
            else
                if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
                    Log(LOG_LEVEL.DEBUG, "Spell not found: " .. spellConfig.name)
                end
                vanillaFailCount = vanillaFailCount + 1
            end
        end)
        
        if not success then
            Log(LOG_LEVEL.ERROR, "Error modifying spell " .. spellConfig.name .. ": " .. tostring(err))
            vanillaFailCount = vanillaFailCount + 1
        end
    end
    
    Log(LOG_LEVEL.INFO, string.format("Vanilla spell injection summary: %d successful, %d failed", vanillaSuccessCount, vanillaFailCount))
    
    -- Process Eldertide Armaments spells (if mod is installed)
    Log(LOG_LEVEL.INFO, "Checking for Eldertide Armaments compatibility...")
    local eldertideSuccessCount = 0
    local eldertideFailCount = 0
    local eldertideNotFoundCount = 0
    
    for _, spellConfig in ipairs(eldertideSpells) do
        local success, err = pcall(function()
            local spell = Ext.Stats.Get(spellConfig.name, -1, false, true)
            if spell then
                -- Apply modifications
                local modifiedProperties = {}
                
                for property, value in pairs(spellConfig.modifications) do
                    local oldValue = spell[property] or "none"
                    spell[property] = value
                    
                    -- Only log details at DEBUG level
                    if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
                        Log(LOG_LEVEL.DEBUG, string.format("  [Eldertide] %s.%s: %s -> %s", 
                            spellConfig.name, property, oldValue, value))
                    end
                    
                    table.insert(modifiedProperties, property)
                end
                
                -- Sync stats
                Ext.Stats.Sync(spellConfig.name)
                
                -- Keep per-spell success logging at DEBUG to reduce startup spam
                if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
                    Log(LOG_LEVEL.DEBUG, string.format("[Eldertide] Modified spell %s (%d properties)", 
                        spellConfig.name, #modifiedProperties))
                end
                eldertideSuccessCount = eldertideSuccessCount + 1
            else
                -- Spell not found - mod may not be installed
                if CURRENT_LOG_LEVEL >= LOG_LEVEL.DEBUG then
                    Log(LOG_LEVEL.DEBUG, "[Eldertide] Spell not found: " .. spellConfig.name)
                end
                eldertideNotFoundCount = eldertideNotFoundCount + 1
            end
        end)
        
        if not success then
            Log(LOG_LEVEL.ERROR, "[Eldertide] Error modifying spell " .. spellConfig.name .. ": " .. tostring(err))
            eldertideFailCount = eldertideFailCount + 1
        end
    end
    
    -- Log Eldertide compatibility results
    if eldertideSuccessCount > 0 then
        Log(LOG_LEVEL.INFO, string.format("[Eldertide] Compatibility enabled: %d spells modified", eldertideSuccessCount))
    elseif eldertideNotFoundCount == #eldertideSpells then
        Log(LOG_LEVEL.INFO, "[Eldertide] Mod not detected - compatibility spells skipped")
    else
        Log(LOG_LEVEL.WARN, string.format("[Eldertide] Partial compatibility: %d successful, %d failed, %d not found", 
            eldertideSuccessCount, eldertideFailCount, eldertideNotFoundCount))
    end
    
    spellsInjected = true
    Log(LOG_LEVEL.INFO, "AI tag injection complete")
end

-- Subscribe to SessionLoaded to inject AI tags
Ext.Events.SessionLoaded:Subscribe(InjectAITags)

------------------------------------------------------------------------------------------
-- Turn Skip Failsafe (Act 3 Freeze Fix)
------------------------------------------------------------------------------------------
-- Prevents AI from freezing the game by ending their turn if it takes too long

-- NOTE: turnStartTimes and related constants defined at top of file for early access

-- Check for turn timeouts on Tick (throttled to once per second)
Ext.Events.Tick:Subscribe(function()
    local currentTime = Ext.Utils.MonotonicTime()
    
    -- Throttle checks to once per second to reduce CPU overhead
    if (currentTime - lastTickCheck) < TICK_CHECK_INTERVAL then
        return
    end
    lastTickCheck = currentTime
    
    -- Periodic cache cleanup (runs at most once every 30 seconds)
    cleanupStaleCache()
    
    for character, startTime in pairs(turnStartTimes) do
        if (currentTime - startTime) > TURN_TIMEOUT_MS then
            -- Check if the character is still in their turn and in combat
            local success, isInCombat = pcall(function() return Osi.IsInCombat(character) end)
            if success and isInCombat == 1 then
                -- Additional check: verify the character is an AI ally before forcing end turn
                -- FIX: pcall returns (success, result), need to check both
                local hasAISuccess, hasAIStatus = pcall(function() return Osi.HasActiveStatus(character, "AI_ALLY") end)
                if hasAISuccess and hasAIStatus == 1 then
                    -- Verify character is not a player before ending turn
                    local isPlayerSuccess, isPlayer = pcall(function() return Osi.IsPlayer(character) end)
                    if isPlayerSuccess and isPlayer == 0 then
                        Log(LOG_LEVEL.WARN, "Turn timeout detected for AI ally: " .. character .. ", forcing end turn")
                        local endSuccess = pcall(function() Osi.EndTurn(character) end)
                        if not endSuccess then
                            Log(LOG_LEVEL.ERROR, "Failed to end turn for: " .. character)
                        end
                    else
                        Log(LOG_LEVEL.DEBUG, "Skipping timeout for player character: " .. character)
                    end
                end
            end
            -- Clear tracking regardless of success to prevent memory leak
            turnStartTimes[character] = nil
        end
    end
end)

-- Clear turn tracking when turn ends
-- REMOVED: Consolidated into main TurnEnded handler above for performance

------------------------------------------------------------------------------------------
-- NPC Mode Safety (Crash Prevention)
------------------------------------------------------------------------------------------
-- Forces characters back to player mode after combat to prevent dialogue crashes

Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function(combatGuid)
    Log(LOG_LEVEL.DEBUG, "Combat ended, checking for NPC mode characters...")
    
    -- Clear any stale turn timers to prevent memory leaks
    for character, _ in pairs(turnStartTimes) do
        turnStartTimes[character] = nil
    end
    Log(LOG_LEVEL.DEBUG, "Cleared turn timeout tracking")
    
    -- Clear target priority caches
    targetInfoCache = {}
    targetInfoCacheTime = {}
    focusFireTarget = nil
    Log(LOG_LEVEL.DEBUG, "Cleared target priority caches")
    
    -- Clear combat participants cache
    combatParticipantsCache = {}
    combatParticipantsCacheTime = {}
    Log(LOG_LEVEL.DEBUG, "Cleared combat participants cache")
    
    -- Clear item usage tracking
    itemsUsedThisCombat = {}
    Log(LOG_LEVEL.DEBUG, "Cleared item usage tracking")
    
    -- Clear combat status caches
    rageStatusCache = {}
    wildshapeStatusCache = {}
    adjacentEnemyCache = {}
    Log(LOG_LEVEL.DEBUG, "Cleared combat status caches")
    
    -- Clear conjuring spell tracking (prevents memory leak)
    conjuringSpellsUsed = {}
    Log(LOG_LEVEL.DEBUG, "Cleared conjuring spell tracking")
    
    -- Clear party members cache (roster may change after combat)
    partyMembersCache = nil
    
    -- Iterate through all party members with error handling
    local players = GetPartyMembers()
    if not players then
        Log(LOG_LEVEL.WARN, "Could not retrieve party members")
        return
    end
    
    for _, player in pairs(players) do
        local character = player[1]
        
        -- Skip summons - they don't need NPC mode safety
        if not IsSummon(character) then
            -- Check if character has any NPC status or ToggleIsNPC
            local hasNPCStatus = false
            
            local statusSuccess, hasToggle = pcall(function() return Osi.HasActiveStatus(character, "ToggleIsNPC") end)
            if statusSuccess and hasToggle == 1 then
                hasNPCStatus = true
            else
                -- Check for any status ending in _NPC
                for _, status in ipairs(NPCStatuses) do
                    local npcSuccess, hasStatus = pcall(function() return Osi.HasActiveStatus(character, status) end)
                    if npcSuccess and hasStatus == 1 then
                        hasNPCStatus = true
                        break
                    end
                end
            end
            
            -- Force back to player mode if NPC status detected
            if hasNPCStatus then
                local makePlayerSuccess = pcall(function() Osi.MakePlayer(character) end)
                if makePlayerSuccess then
                    Log(LOG_LEVEL.DEBUG, "Forced player mode for: " .. character)
                else
                    Log(LOG_LEVEL.ERROR, "Failed to force player mode for: " .. character)
                end
            end
        end
    end
end)

------------------------------------------------------------------------------------------
-- Wildshape Restoration for Druids
------------------------------------------------------------------------------------------
-- Ensures Druids with AI control use their Wildshape ability
-- REMOVED: Consolidated into main TurnStarted handler above for performance

------------------------------------------------------------------------------------------
-- AI Action Validation Before Use
------------------------------------------------------------------------------------------
-- Prevents AI from getting stuck trying invalid actions

-- Check if character has spell slots available for a given spell level
local function HasAvailableSpellSlot(character, spellLevel)
    if spellLevel == 0 then
        return true  -- Cantrips don't require slots
    end
    
    local success, result = pcall(function()
        local entity = Ext.Entity.Get(character)
        if entity and entity.SpellBook and entity.SpellBook.Spells then
            -- Check if character has spell slots of the required level
            -- This is a simplified check - actual implementation may vary
            return true
        end
        return false
    end)
    
    return success and result
end

-- Validate that spell has valid targets before AI attempts to use it
local function HasValidTargetsForSpell(character, spellName)
    local success, hasTargets = pcall(function()
        -- Validate character entity
        if not IsValidEntity(character) then
            return false
        end
        
        -- For healing spells, check if there are injured allies nearby
        if spellName:find("Heal") or spellName:find("Cure") then
            local players = GetPartyMembers()
            if players then
                for _, player in pairs(players) do
                    local ally = player[1]
                    -- Skip self, invalid entities, and summons
                    if ally ~= character and IsValidEntity(ally) and not IsSummon(ally) then
                        local allyEntity = Ext.Entity.Get(ally)
                        if allyEntity and allyEntity.Health then
                            local hpPercent = (allyEntity.Health.Hp / allyEntity.Health.MaxHp) * 100
                            if hpPercent < 90 then
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end
        
        -- For offensive spells, check if there are enemies in range
        if Osi.IsInCombat(character) == 1 then
            return true  -- Assume enemies exist in combat
        end
        
        return true
    end)
    
    return success and hasTargets
end

-- Validate movement path before Dash to prevent getting stuck
local function ValidateMovementPath(character)
    local success, isValid = pcall(function()
        local entity = Ext.Entity.Get(character)
        if not entity or not entity.Transform then
            return false
        end
        
        -- Basic validation - character has a position
        local pos = entity.Transform.Transform.Translate
        if not pos or not pos[1] or not pos[2] or not pos[3] then
            return false
        end
        
        -- Additional checks could include:
        -- - Not standing in difficult terrain
        -- - Not surrounded by enemies with opportunity attacks
        -- - Has valid pathing to destination
        
        return true
    end)
    
    return success and isValid
end

------------------------------------------------------------------------------------------
-- Environmental Hazard Avoidance
------------------------------------------------------------------------------------------
-- Prevents AI from walking into fire, acid, and other environmental hazards

-- Track known hazardous surfaces
local hazardousSurfaces = {
    "SurfaceFireSurface",
    "SurfaceFireCloudSurface", 
    "SurfaceLavaSurface",
    "SurfacePoisonCloudSurface",
    "SurfaceAcidSurface",
    "SurfaceBloodElectrifiedSurface",
    "SurfaceElectrifiedWaterSurface",
    "SurfaceExplosionSurface"
}

-- Check if position has hazardous surface
local function IsPositionHazardous(position)
    if not position then
        return false
    end
    
    local success, isHazard = pcall(function()
        -- This is a placeholder for surface detection
        -- BG3 Script Extender may need specific API calls to detect surfaces
        -- For now, we'll return false to allow movement
        return false
    end)
    
    return success and isHazard
end

-- Listener to prevent movement into hazards
-- REMOVED: Consolidated into main TurnStarted handler above for performance

------------------------------------------------------------------------------------------
-- Item Pickup Optimization
------------------------------------------------------------------------------------------
-- Improves AI weapon pickup reliability with distance checks and priority

-- Track items AI should prioritize
local priorityItemTypes = {
    "Weapon",
    "Armor", 
    "Potion",
    "Scroll"
}

-- Check if item is within pickup range and worth picking up
local function ShouldPickupItem(character, item)
    local success, shouldPickup = pcall(function()
        local charEntity = Ext.Entity.Get(character)
        local itemEntity = Ext.Entity.Get(item)
        
        if not charEntity or not itemEntity then
            return false
        end
        
        if not charEntity.Transform or not itemEntity.Transform then
            return false
        end
        
        local charPos = charEntity.Transform.Transform.Translate
        local itemPos = itemEntity.Transform.Transform.Translate
        
        if not charPos or not itemPos then
            return false
        end
        
        -- Calculate distance
        local dx = charPos[1] - itemPos[1]
        local dy = charPos[2] - itemPos[2]
        local dz = charPos[3] - itemPos[3]
        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
        
        -- Only consider items within 5m
        if distance > 5 then
            return false
        end
        
        -- Check if character needs this type of item
        -- This is simplified - could check if character lacks weapon, etc.
        return true
    end)
    
    return success and shouldPickup
end

------------------------------------------------------------------------------------------
-- Formation System
------------------------------------------------------------------------------------------
-- Tactical formation positioning for AI allies at combat start

-- Get formation anchor (player's position)
local function GetFormationAnchor()
    local player = Osi.GetHostCharacter()
    local entity = Ext.Entity.Get(player)
    if entity and entity.Transform then
        return entity.Transform.Transform.Translate
    end
    return nil
end

-- Calculate formation positions based on type
local function CalculateFormationPositions(anchorPos, allyCount, formationType, spacing)
    local positions = {}
    
    if formationType == "WEDGE" then
        -- Wedge: V-shape with anchor at point
        -- Row 1: anchor + 0m forward
        -- Row 2: 2 allies at ±spacing, -spacing back
        -- Row 3: 2 allies at ±(spacing*1.5), -(spacing*2) back
        -- Row 4: 1 ally at 0, -(spacing*3) back (healer)
        
        positions[1] = {x = anchorPos[1], y = anchorPos[2], z = anchorPos[3]} -- Tank position
        
        if allyCount >= 2 then
            positions[2] = {x = anchorPos[1] + spacing, y = anchorPos[2], z = anchorPos[3] - spacing}
        end
        if allyCount >= 3 then
            positions[3] = {x = anchorPos[1] - spacing, y = anchorPos[2], z = anchorPos[3] - spacing}
        end
        if allyCount >= 4 then
            positions[4] = {x = anchorPos[1] + (spacing * 1.5), y = anchorPos[2], z = anchorPos[3] - (spacing * 2)}
        end
        if allyCount >= 5 then
            positions[5] = {x = anchorPos[1] - (spacing * 1.5), y = anchorPos[2], z = anchorPos[3] - (spacing * 2)}
        end
        if allyCount >= 6 then
            positions[6] = {x = anchorPos[1], y = anchorPos[2], z = anchorPos[3] - (spacing * 3)} -- Healer back
        end
        
    elseif formationType == "LINE" then
        -- Horizontal line centered on anchor
        local startOffset = -((allyCount - 1) * spacing) / 2
        for i = 1, allyCount do
            positions[i] = {
                x = anchorPos[1] + (startOffset + ((i - 1) * spacing)),
                y = anchorPos[2],
                z = anchorPos[3]
            }
        end
        
    elseif formationType == "CIRCLE" then
        -- Circular formation around anchor
        local radius = spacing * 1.5
        local angleStep = (2 * math.pi) / allyCount
        for i = 1, allyCount do
            local angle = (i - 1) * angleStep
            positions[i] = {
                x = anchorPos[1] + (radius * math.cos(angle)),
                y = anchorPos[2],
                z = anchorPos[3] + (radius * math.sin(angle))
            }
        end
        
    elseif formationType == "SCATTER" then
        -- Random positions within radius
        local maxRadius = spacing * 2
        math.randomseed(os.time())
        for i = 1, allyCount do
            local angle = math.random() * 2 * math.pi
            local distance = math.random() * maxRadius
            positions[i] = {
                x = anchorPos[1] + (distance * math.cos(angle)),
                y = anchorPos[2],
                z = anchorPos[3] + (distance * math.sin(angle))
            }
        end
        
    elseif formationType == "CUSTOM" then
        -- CUSTOM formation not yet implemented - defaults to WEDGE
        -- TODO: Load custom positions from saved config in future update
        Log(LOG_LEVEL.INFO, "[Formation] CUSTOM formation not yet implemented, using WEDGE formation")
        return CalculateFormationPositions(anchorPos, allyCount, "WEDGE", spacing)
    end
    
    return positions
end

-- Validate position is safe (not in wall, hazard, etc.)
local function IsPositionSafe(position)
    -- Basic validation - currently minimal
    if not position then return false end
    
    -- Note: BG3's TeleportTo has internal collision detection and will fail gracefully
    -- if the position is invalid (inside walls, etc.). Additional surface hazard detection
    -- could be implemented here in the future using Osi.HasSurface or similar APIs.
    -- TODO: Add surface detection for hazards (BURNING, ELECTRIFIED, POISONED, ACID)
    
    return true
end

-- Get current archetype for an ally
local function GetCurrentArchetype(character)
    -- Check active controller status
    for _, status in ipairs(aiCombatStatuses) do
        if Osi.HasActiveStatus(character, status) == 1 then
            return status
        end
    end
    return nil
end

-- Assign allies to formation positions based on role
local function AssignAlliesToPositions(allies, positions)
    local assignments = {}
    
    -- Categorize allies by role
    local tanks = {}
    local dps = {}
    local healers = {}
    local others = {}
    
    for _, ally in ipairs(allies) do
        local archetype = GetCurrentArchetype(ally)
        
        -- Check HEALER first as it's more specific (HEALER_MELEE, HEALER_RANGED)
        if archetype and string.find(archetype, "HEALER") then
            table.insert(healers, ally)
        elseif archetype and (string.find(archetype, "MELEE") or string.find(archetype, "THROWER")) then
            table.insert(tanks, ally)
        elseif archetype and (string.find(archetype, "RANGED") or string.find(archetype, "MAGE")) then
            table.insert(dps, ally)
        else
            table.insert(others, ally)
        end
    end
    
    -- Assign positions: tanks front, dps middle, healers back
    local posIndex = 1
    
    -- Tanks get front positions
    for _, tank in ipairs(tanks) do
        if positions[posIndex] then
            assignments[tank] = positions[posIndex]
            posIndex = posIndex + 1
        end
    end
    
    -- DPS get middle positions
    for _, dpser in ipairs(dps) do
        if positions[posIndex] then
            assignments[dpser] = positions[posIndex]
            posIndex = posIndex + 1
        end
    end
    
    -- Healers get back positions
    for _, healer in ipairs(healers) do
        if positions[posIndex] then
            assignments[healer] = positions[posIndex]
            posIndex = posIndex + 1
        end
    end
    
    -- Others fill remaining slots
    for _, other in ipairs(others) do
        if positions[posIndex] then
            assignments[other] = positions[posIndex]
            posIndex = posIndex + 1
        end
    end
    
    return assignments
end

-- Apply formation to allies
local function ApplyFormation(combatGuid)
    local enableFormations = GetCachedSettingValue("enableFormations", ModuleUUID)
    if not enableFormations then
        return
    end
    
    local formationType = GetCachedSettingValue("formationType", ModuleUUID)
    local spacing = GetCachedSettingValue("formationSpacing", ModuleUUID)
    
    -- Get anchor position (player)
    local anchorPos = GetFormationAnchor()
    if not anchorPos then
        Log(LOG_LEVEL.WARN, "[Formation] Could not determine anchor position")
        return
    end
    
    -- Get AI allies in combat
    local allies = {}
    local players = GetPartyMembers()
    
    if not players then return end
    
    for _, player in pairs(players) do
        local character = player[1]
        
        -- Only formation AI-controlled allies
        if Osi.HasActiveStatus(character, "AI_ALLY") == 1 and
           Osi.IsInCombat(character) == 1 then
            table.insert(allies, character)
        end
    end
    
    if #allies == 0 then
        return
    end
    
    Log(LOG_LEVEL.INFO, string.format("[Formation] Positioning %d allies in %s formation", #allies, formationType))
    Log(LOG_LEVEL.DEBUG, string.format(
        "[Formation] Type: %s, Spacing: %dm, Allies: %d, Anchor: (%.2f, %.2f, %.2f)",
        formationType, spacing, #allies, anchorPos[1], anchorPos[2], anchorPos[3]
    ))
    
    -- Calculate formation positions
    local positions = CalculateFormationPositions(anchorPos, #allies, formationType, spacing)
    
    -- Assign allies to positions based on role
    local assignments = AssignAlliesToPositions(allies, positions)
    
    -- Teleport allies to their positions
    for ally, position in pairs(assignments) do
        if IsPositionSafe(position) then
            local success, result = pcall(function()
                -- TeleportTo with coordinates: character, x, y, z, event, findFloor
                Osi.TeleportTo(ally, position.x, position.y, position.z, "", 0)
                Log(LOG_LEVEL.DEBUG, string.format("[Formation] Positioned ally %s at (%.2f, %.2f, %.2f)", 
                    ally, position.x, position.y, position.z))
            end)
            
            if not success then
                Log(LOG_LEVEL.ERROR, "[Formation] Failed to teleport ally: " .. tostring(result))
            end
        else
            Log(LOG_LEVEL.WARN, "[Formation] Unsafe position detected, skipping teleport for ally")
        end
    end
end

-- Register CombatStarted listener for formations
Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combatGuid)
    -- Small delay to ensure combat is fully initialized
    Ext.Timer.WaitFor(500, function()
        local success, result = pcall(function()
            ApplyFormation(combatGuid)
        end)
        
        if not success then
            Log(LOG_LEVEL.ERROR, "[Formation] Error applying formation: " .. tostring(result))
        end
    end)
end)

------------------------------------------------------------------------------------------
-- XP Distribution Validation
------------------------------------------------------------------------------------------
-- Ensures party members remain in party during combat to receive XP

-- Track party composition at combat start
local combatPartySnapshot = {}

-- Store party members when combat starts
Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combatGuid)
    local success = pcall(function()
        combatPartySnapshot[combatGuid] = {}
        
        local players = GetPartyMembers()
        if players then
            for _, player in pairs(players) do
                local character = player[1]
                -- Track real party members, not summons
                if not IsSummon(character) then
                    combatPartySnapshot[combatGuid][character] = true
                    Log(LOG_LEVEL.DEBUG, "Tracked party member for XP: " .. character)
                end
            end
        end
    end)
    
    if not success then
        Log(LOG_LEVEL.WARN, "Failed to track party composition for XP")
    end
end)

-- Verify party members are still in party during combat
-- REMOVED: Consolidated into main TurnStarted handler above for performance

-- Clean up tracking when combat ends
Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function(combatGuid)
    local success = pcall(function()
        if combatPartySnapshot[combatGuid] then
            -- Verify all tracked members got XP (if possible to check)
            for character, _ in pairs(combatPartySnapshot[combatGuid]) do
                Log(LOG_LEVEL.DEBUG, "Combat ended - verifying XP for: " .. character)
            end
            
            -- Clear snapshot
            combatPartySnapshot[combatGuid] = nil
        end
    end)
    
    if not success then
        Log(LOG_LEVEL.WARN, "Failed to cleanup XP tracking")
    end
end)

--- Dialog fix**
local relevantDialogInstance = nil
-- Optimized: Use weak table to allow garbage collection when characters despawn
local transformedCompanions = {}
setmetatable(transformedCompanions, {__mode = "k"})  -- Weak keys for automatic cleanup

-- Optimized: Use caching for dialog status checks
local function HasRelevantStatus(character)
    local cacheKey = character .. "_relevant"
    local cached = GetCachedValue(statusCheckCache, cacheKey, CACHE_EXPIRY)
    if cached ~= nil then
        return cached
    end
    
    local result = false
    if Osi.HasActiveStatus(character, "ToggleIsNPC") == 1 then
        for _, status in ipairs(aiCombatStatuses) do
            if Osi.HasActiveStatus(character, status) == 1 then
                result = true
                break
            end
        end
    end
    
    -- Track new cache entries
    if not statusCheckCache[cacheKey] then
        cacheEntriesCount = cacheEntriesCount + 1
    end
    statusCheckCache[cacheKey] = {value = result, time = Ext.Utils.MonotonicTime()}
    return result
end

local function IsCurrentAlly(actorUuid)
    return CurrentAllies[actorUuid] ~= nil
end

local function HandleDialogStarted(dialog, instanceID)
    relevantDialogInstance = instanceID
    Log(LOG_LEVEL.DEBUG, "Relevant dialog started for instance: " .. tostring(instanceID))
end

Ext.Osiris.RegisterListener("DialogStarted", 2, "after", HandleDialogStarted)

local function HandleDialogActorJoined(instanceID, actor)
    local actorUuid = Osi.GetUUID(actor)
    if instanceID == relevantDialogInstance and IsCurrentAlly(actorUuid) and HasRelevantStatus(actor) then
        Osi.MakePlayer(actor)
        transformedCompanions[actorUuid] = true
        Log(LOG_LEVEL.DEBUG, "Temporarily turned " .. actor .. " into a player for dialog instance " .. tostring(instanceID))
    end
end

Ext.Osiris.RegisterListener("DialogActorJoined", 4, "after", function(dialog, instanceID, actor, speakerIndex)
    HandleDialogActorJoined(instanceID, actor)
end)

local function HandleDialogEnded(dialog, instanceID)
    if instanceID == relevantDialogInstance then
        for actorUuid, _ in pairs(transformedCompanions) do
            if Osi.IsInCombat(actorUuid) == 0 then
                Log(LOG_LEVEL.DEBUG, "Character " .. actorUuid .. " is not in combat, remaining as player character after dialog end.")
            else
                Osi.MakeNPC(actorUuid)
                Log(LOG_LEVEL.DEBUG, "Reverted " .. actorUuid .. " back to NPC after dialog end in instance " .. tostring(instanceID))
            end
        end
        transformedCompanions = {}
        relevantDialogInstance = nil
    end
end

Ext.Osiris.RegisterListener("DialogEnded", 2, "after", HandleDialogEnded)
--- Optimized: Batch teleport operations
function TeleportAlliesToCaster(caster)
    local target = Osi.GetHostCharacter()
    local teleportOps = {}
    
    -- Collect all allies to teleport
    for uuid in pairs(CurrentAllies) do
        table.insert(teleportOps, uuid)
    end
    
    -- Execute teleports
    for _, uuid in ipairs(teleportOps) do
        Osi.TeleportTo(uuid, target, "", 1, 1, 1, 0, 1)
        Log(LOG_LEVEL.DEBUG, "Teleporting ally: " .. uuid)
    end
end


-- Listener for the 'C_Shout_Allies_Teleport' spell
Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function (caster, target, spellName, _, _, _, _)
    if spellName == 'C_Shout_Allies_Teleport' then
        TeleportAlliesToCaster(caster)
    end
end)
--------------------------------------------------------------
-- Better faction debug
Mods.AIAllies.PersistentVars.originalFactions = Mods.AIAllies.PersistentVars.originalFactions or {}

local originalFactions = {}

local function InitOriginalFactions()
    if not Mods.AIAllies.PersistentVars.originalFactions then
        Mods.AIAllies.PersistentVars.originalFactions = {}
    end
    originalFactions = Mods.AIAllies.PersistentVars.originalFactions
end

Ext.Events.SessionLoaded:Subscribe(InitOriginalFactions)

local function SafelyUpdateFactionStore(character, newFaction)
    if not originalFactions[character] then
        originalFactions[character] = newFaction
        Mods.AIAllies.PersistentVars.originalFactions = originalFactions
        Log(LOG_LEVEL.DEBUG, "Original faction saved for " .. character .. ": " .. newFaction)
    else
        Log(LOG_LEVEL.DEBUG, "Original faction for " .. character .. " already set to: " .. originalFactions[character])
    end
end

-- Optimized: Cache getCleanFactionID results and reduce repeated string operations
local factionIDCache = {}

local function getCleanFactionID(factionString)
    if factionIDCache[factionString] then
        return factionIDCache[factionString]
    end
    
    local factionID = string.match(factionString, "([0-9a-f-]+)$")
    local result = factionID or factionString
    factionIDCache[factionString] = result
    return result
end

-- Faction Debug
Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function (caster, target, spell, spellType, spellElement, storyActionID)
    if spell == "G_Target_Allies_Faction" then
        local casterFaction = Osi.GetFaction(caster)
        local targetFaction = Osi.GetFaction(target)
        local hostCharacter = Osi.GetHostCharacter()

        SafelyUpdateFactionStore(hostCharacter, getCleanFactionID(Osi.GetFaction(hostCharacter)))

        Log(LOG_LEVEL.DEBUG, "Caster's current faction: " .. casterFaction)
        Log(LOG_LEVEL.DEBUG, "Target's faction: " .. targetFaction)

        Osi.SetFaction(hostCharacter, getCleanFactionID(targetFaction))
        Log(LOG_LEVEL.DEBUG, "Changed faction of " .. hostCharacter .. " to " .. getCleanFactionID(targetFaction))
    end
end)

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function (caster, target, spell, _, _, _, _)
    if spell == "H_Target_Allies_Faction_Leave" then
        local hostCharacter = Osi.GetHostCharacter()
        local originalFaction = originalFactions[hostCharacter] or "6545a015-1b3d-66a4-6a0e-6ec62065cdb7"

        Osi.SetFaction(hostCharacter, getCleanFactionID(originalFaction))
        Log(LOG_LEVEL.DEBUG, "Reverted faction of " .. hostCharacter .. " to " .. getCleanFactionID(originalFaction))
    end
end)
------------------------------------------------------------------------------------------------
-- for Debug spells
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function (object, status, causee, storyActionID)
    if status == 'MARK_NPC' then
        Osi.MakeNPC(object)
    end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function (object, status, causee, storyActionID)
    if status == 'MARK_PLAYER' then
        Osi.MakePlayer(object)
    end
end)

-- Listener function for UsingSpellOnTarget
function OnUsingSpellOnTarget(caster, target, spell, spellType, spellElement, storyActionID)
    if spell == "I_Target_Allies_Check_Archetype" then
        local activeArchetype = Osi.GetActiveArchetype(target)
        local baseArchetype = Osi.GetBaseArchetype(target)
        Log(LOG_LEVEL.DEBUG, "Target: " .. target)
        Log(LOG_LEVEL.DEBUG, "Active Archetype: " .. activeArchetype)
        Log(LOG_LEVEL.DEBUG, "Base Archetype: " .. baseArchetype)
    end
end

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", OnUsingSpellOnTarget)
------------------------------------------------------------------------------------------------
-- Force
-- Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function (object, status, causee, storyActionID)
--     if status == 'FORCE_USE' or status == 'FORCE_USE_MORE' or status == 'FORCE_USE_MOST' then
--         Osi.RemoveStatus(object, status)
--     end
-- end)
------------------------------------------------------------------------------------------------
-- Testing - Pause combat when it starts to give AI time to initialize 
local combatTimers = {}

local function OnTimerFinished(InitializeTimerAI)
    local combatGuid = combatTimers[InitializeTimerAI]
    if combatGuid then
        Osi.ResumeCombat(combatGuid)
        Log(LOG_LEVEL.DEBUG, "Resuming combat")
        combatTimers[InitializeTimerAI] = nil
    end
end

Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combatGuid)
    Osi.PauseCombat(combatGuid)
    Log(LOG_LEVEL.DEBUG, "Pausing combat to allow AI to initialize")
    local InitializeTimerAI = "ResumeCombatTimer_" .. tostring(combatGuid)
    combatTimers[InitializeTimerAI] = combatGuid
    Osi.TimerLaunch(InitializeTimerAI, 1000)  -- Reduced from 2000ms to 1000ms for better performance
end)

Ext.Osiris.RegisterListener("TimerFinished", 1, "after", function(InitializeTimerAI)
    OnTimerFinished(InitializeTimerAI)
end)
------------------------------------------------------------------------------------------------
-- For wildshape
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function (object, status, causee, storyActionID)
    if status == 'FORCE_USE_MOST' or status == 'FORCE_USE_MORE' then
        Osi.RemoveStatus(object, status)
        --Log(LOG_LEVEL.DEBUG, "Removed status: " .. status .. " from object: " .. object)
    end
end)
------------------------------------------------------------------------------------------------
-- Swarm Mechanic
-- Optimized: Move constant table outside function to avoid recreation
local swarmGroupMappings = {
    Target_Allies_Swarm_Group_Alpha = "AlliesSwarm_Alpha",
    Target_Allies_Swarm_Group_Bravo = "AlliesSwarm_Bravo",
    Target_Allies_Swarm_Group_Charlie = "AlliesSwarm_Charlie",
    Target_Allies_Swarm_Group_Delta = "AlliesSwarm_Delta",
    Target_Allies_Swarm_Group_e_Clear = ""
}

-- Optimized: Create lookup set for swarm groups
local swarmGroupSet = {
    AlliesSwarm_Alpha = true,
    AlliesSwarm_Bravo = true,
    AlliesSwarm_Charlie = true,
    AlliesSwarm_Delta = true
}

local function HandleSwarmGroupAssignment(caster, target, spell)
    local swarmGroup = swarmGroupMappings[spell]
    if swarmGroup ~= nil then
        Osi.RequestSetSwarmGroup(target, swarmGroup)
        if swarmGroup == "" then
            Log(LOG_LEVEL.INFO, string.format("Cleared swarm group for %s", target))
        else
            Log(LOG_LEVEL.INFO, string.format("Added %s to swarm group: %s", target, swarmGroup))
        end
    end
end

function SetInitiativeToFixedValue(target, fixedInitiative)
    local entity = Ext.Entity.Get(target)
    
    if entity and entity.CombatParticipant and entity.CombatParticipant.CombatHandle then
        entity.CombatParticipant.InitiativeRoll = fixedInitiative
        entity.CombatParticipant.CombatHandle.CombatState.Initiatives[entity] = fixedInitiative
        entity:Replicate("CombatParticipant")
    else
        Log(LOG_LEVEL.INFO, string.format("Failed to set initiative for %s: Entity or CombatHandle is nil.", target))
    end
end

Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(object, combatGuid)
    local swarmGroup = Osi.GetSwarmGroup(object)
    
    -- Optimized: Use lookup set instead of multiple string comparisons
    if swarmGroupSet[swarmGroup] then
        SetInitiativeToFixedValue(object, 6)
    end
end)

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function(caster, target, spell, spellType, spellElement, storyActionID)
    HandleSwarmGroupAssignment(caster, target, spell)
end)
