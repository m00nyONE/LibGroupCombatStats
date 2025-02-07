--[[
    LibGroupCombatStats

    Usage:
        - register your addon by calling:
            local lgcs = LibGroupCombatStats.RegisterAddon("addonName", {"ULT", "DPS", "HPS"})
        - use the newly created lgcs object to interact with the library either by defining callbacks or by directly querrying the library with API calls
        - define callbacks:
            lgcs:RegisterForEvent(EVENT_NAME, callback)
            the following events are available:
            - LibGroupCombatStats.EVENT_GROUP_DPS_UPDATE -- Event triggered when group DPS stats are updated
            - LibGroupCombatStats.EVENT_GROUP_HPS_UPDATE -- Event triggered when group HPS stats are updated
            - LibGroupCombatStats.EVENT_GROUP_ULT_UPDATE -- Event triggered when group ultimate stats are updated
            - LibGroupCombatStats.EVENT_PLAYER_DPS_UPDATE -- Event triggered when player DPS stats are updated
            - LibGroupCombatStats.EVENT_PLAYER_HPS_UPDATE -- Event triggered when player HPS stats are updated
            - LibGroupCombatStats.EVENT_PLAYER_ULT_UPDATE -- Event triggered when player ultimate stats are updated
        - use API functions:
            lgsc:Example_API_Function()
            the following API calls are provided:
            - GetGroupStats() -- should only be used in rare occasions -- it returns all data of all group members as a table with characterName as the key
            - GetGroupSize() /#lgcs -- returns the amount of the group members with data available
            - Iterate() / pairs(lgsc) -- iterate over group members
            - GetStatsShared() -- Returns a list of functionalities currently enabled in the library
            - GetUnitStats(unitTag) -- Retrieves statistics for a specific unit in the group
            - GetUnitDPS(unitTag) -- Retrieves DPS information for a specific unit in the group
            - GetUnitHPS(unitTag) -- Retrieves HPS information for a specific unit in the group
            - GetUnitULT(unitTag) -- Retrieves ultimate information for a specific unit in the group
]]--

--- general initialization
local lib = {
    name = "LibGroupCombatStats",
    version = "dev",
}
local lib_debug = false
local lib_name = lib.name
local lib_version = lib.version
_G[lib_name] = lib

local HPS = "HPS"
local DPS = "DPS"
local ULT = "ULT"

local LGB = LibGroupBroadcast
local EM = EVENT_MANAGER
local LocalEM = ZO_CallbackObject:New()
local strmatch = string.match
local _isFirstOnPlayerActivated = true
local _LGBProtocols = {}
local _registeredAddons = {}
local _statsShared = {
    [ULT] = false,
    [DPS] = false,
    [HPS] = false,
}
local _ultIdMap = {}
local _ultInternalIdMap = {}


--- logging setup
local mainLogger
local subLoggers = {}
local LOG_LEVEL_ERROR = "E"
local LOG_LEVEL_WARNING ="W"
local LOG_LEVEL_INFO = "I"
local LOG_LEVEL_DEBUG = "D"
local LOG_LEVEL_VERBOSE = "V"

if LibDebugLogger then
    mainLogger = LibDebugLogger.Create(lib_name)

    LOG_LEVEL_ERROR = LibDebugLogger.LOG_LEVEL_ERROR
    LOG_LEVEL_WARNING = LibDebugLogger.LOG_LEVEL_WARNING
    LOG_LEVEL_INFO = LibDebugLogger.LOG_LEVEL_INFO
    LOG_LEVEL_DEBUG = LibDebugLogger.LOG_LEVEL_DEBUG
    LOG_LEVEL_VERBOSE = LibDebugLogger.LOG_LEVEL_VERBOSE

    subLoggers["broadcast"] = mainLogger:Create("broadcast")
    subLoggers["encoding"] = mainLogger:Create("encoding")
    subLoggers["events"] = mainLogger:Create("events")
    subLoggers["menu"] = mainLogger:Create("menu")
    subLoggers["debug"] = mainLogger:Create("debug")
end


--- utility functions
local function IsCallable(callback)
    return type(callback) == "function"
end
local function Log(category, level, ...)
    if not mainLogger then return end
    if category == "debug" and not lib_debug then return end

    local logger = subLoggers[category] or mainLogger
    if type(logger.Log)=="function" then logger:Log(level, ...) end
end


--- constants
local localPlayer = "player"

local MESSAGE_ID_SYNC = 9
local MESSAGE_ID_ULTTYPE = 10
local MESSAGE_ID_ULTVALUE = 11
local MESSAGE_ID_DPS = 12
local MESSAGE_ID_HPS = 13

local PLAYER_ULT_VALUE_UPDATE_INTERVAL = 1000
local PLAYER_DPS_UPDATE_INTERVAL = 1000
local PLAYER_HPS_UPDATE_INTERVAL = 1000

local PLAYER_ULT_TYPE_SEND_ON_GROUP_CHANGE_DELAY = 1000
local PLAYER_ULT_VALUE_SEND_ON_GROUP_CHANGE_DELAY = 1000
local PLAYER_ULT_VALUE_SEND_INTERVAL = 2000
local PLAYER_DPS_SEND_INTERVAL = 2000
local PLAYER_HPS_SEND_INTERVAL = 2000

local ULT_ACTIVATED_SET_LIST = {
    {
        name = "saxhleel",
        link = "|H0:item:173857:364:50:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
        minEquipped = 3, -- we assume player has full set if he wears at least 3 items (2 can be on backbar)
    },
    {
        name = "pillager",
        link = "|H0:item:187028:364:50:0:0:0:2:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h",
        minEquipped = 3, -- we assume player has full set if he wears at least 3 items (2 can be on backbar)
    },
    {
        name = "cryptcanon",
        link = "|H0:item:194509:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
        minEquipped = 1,
    },
    {
      name = "MA", -- master architect
      link = "|H0:item:124294:362:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
      minEquipped = 3,
    },
    {
      name = "WM", -- warmachine
      link = "|H0:item:124112:362:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
      minEquipped = 3,
    },
}
--- export set list, so it can be used to map the ultActivatedSetID to a real set
lib.ULT_ACTIVATED_SET_LIST = ULT_ACTIVATED_SET_LIST


--- often used variables
local PLAYER_CHARACTER_NAME = GetUnitName(localPlayer)
local PLAYER_DISPLAY_NAME = GetUnitDisplayName(localPlayer)


--- exported constants
local DAMAGE_UNKNOWN = 0
local DAMAGE_TOTAL = 1
local DAMAGE_BOSS = 2

lib.DAMAGE_UNKNOWN = DAMAGE_UNKNOWN
lib.DAMAGE_TOTAL = DAMAGE_TOTAL
lib.DAMAGE_BOSS = DAMAGE_BOSS


--- Events exposed by the library for group and player-specific combat statistics. These can be used to register for updates from the library
local EVENT_GROUP_DPS_UPDATE = "EVENT_GROUP_DPS_UPDATE" -- Event triggered when group DPS stats are updated
local EVENT_GROUP_HPS_UPDATE = "EVENT_GROUP_HPS_UPDATE" -- Event triggered when group HPS stats are updated
local EVENT_GROUP_ULT_UPDATE = "EVENT_GROUP_ULT_UPDATE" -- Event triggered when group ultimate stats are updated
local EVENT_PLAYER_DPS_UPDATE = "EVENT_PLAYER_DPS_UPDATE" -- Event triggered when player DPS stats are updated
local EVENT_PLAYER_HPS_UPDATE = "EVENT_PLAYER_HPS_UPDATE" -- Event triggered when player HPS stats are updated
local EVENT_PLAYER_ULT_UPDATE = "EVENT_PLAYER_ULT_UPDATE" -- Event triggered when player ultimate stats are updated
local EVENT_PLAYER_ULT_VALUE_UPDATE = "EVENT_PLAYER_ULT_VALUE_UPDATE" -- Event triggered when player ultimate value stats are updated
local EVENT_PLAYER_ULT_TYPE_UPDATE = "EVENT_PLAYER_ULT_TYPE_UPDATE" -- Event triggered when player ultimate type stats are updated

lib.EVENT_GROUP_DPS_UPDATE = EVENT_GROUP_DPS_UPDATE
lib.EVENT_GROUP_HPS_UPDATE = EVENT_GROUP_HPS_UPDATE
lib.EVENT_GROUP_ULT_UPDATE = EVENT_GROUP_ULT_UPDATE
lib.EVENT_PLAYER_DPS_UPDATE = EVENT_PLAYER_DPS_UPDATE
lib.EVENT_PLAYER_HPS_UPDATE = EVENT_PLAYER_HPS_UPDATE
lib.EVENT_PLAYER_ULT_UPDATE = EVENT_PLAYER_ULT_UPDATE
lib.EVENT_PLAYER_ULT_VALUE_UPDATE = EVENT_PLAYER_ULT_VALUE_UPDATE --- usually not needed
lib.EVENT_PLAYER_ULT_TYPE_UPDATE = EVENT_PLAYER_ULT_TYPE_UPDATE --- usually not needed


--- The ObservableTable allows for firing callbacks when values are updated
local ObservableTable = {}
ObservableTable.__index = ObservableTable
-- Constructor for the ObservableTable class
-- @param onChangeCallback (function): A callback function triggered when the table is changed
-- @param fireAfterLastChangeMS (number): Delay in milliseconds to wait after the last change before firing the callback (default is 0, which triggers immediately)
-- @param initTable (table): An optional initial table to populate the observable table
-- @return (table): A new instance of ObservableTable
function ObservableTable:New(onChangeCallback, fireAfterLastChangeMS, initTable)
    -- Validate that the callback is a function
    if not IsCallable(onChangeCallback) then
        Log("debug", LOG_LEVEL_ERROR, "onChangeCallback must be a function")
        return nil
    end

    -- Define the internal onChange function to handle delayed callbacks
    local onChange = function(self)
        -- If no delay is specified, trigger the callback immediately
        if self._fireAfterLastChangeMS == 0 then
            self._onChangeCallback(self._data)
            return
        end

        -- Unique update event name for this instance
        local updateName = self._eventId

        -- Unregister any previous delayed callback
        EM:UnregisterForUpdate(updateName)

        -- Register a new delayed callback
        EM:RegisterForUpdate(updateName, self._fireAfterLastChangeMS, function()
            self._onChangeCallback(self._data) -- Trigger the callback with the current table data
            EM:UnregisterForUpdate(updateName) -- Ensure the callback is unregistered after execution
        end)
    end

    -- Create the new instance
    local instance = {
        _data = initTable or {}, -- Internal data storage (backing table)
        _onChange = onChange, -- Internal function to handle changes
        _onChangeCallback = onChangeCallback, -- User-provided callback function
        _fireAfterLastChangeMS = fireAfterLastChangeMS or 0, -- Delay in milliseconds before firing the callback
        _lastUpdated = 0, -- Timestamp of the last update (in milliseconds)
        _lastChanged = 0, -- Timestamp of the last update (in milliseconds)
        _eventId = "" -- Unique update event name for this instance
    }

    -- Set the metatable for the new instance
    local newObservableTable = setmetatable(instance, self)

    -- create unique _eventId by getting the address of the table
    newObservableTable._eventId = "ObservableTable_" .. strmatch(tostring(newObservableTable), "0%x+")

    return newObservableTable
end
-- Override __index to read values from the internal data storage
-- @param key (string): The key being accessed
-- @return (any): The value associated with the key in the internal data table
function ObservableTable:__index(key)
    return self._data[key]
end
-- Override __newindex to detect changes to the table
-- @param key (string): The key being modified
-- @param value (any): The new value being assigned to the key
function ObservableTable:__newindex(key, value)
    -- It's important to check if the values are different otherwise every write fires the callback
    local oldValue = rawget(self._data, key)
    local t = GetGameTimeMilliseconds()
    rawset(self, "_lastUpdated", t) -- Update the last modification attempt timestamp

    if oldValue ~= value then
        rawset(self, "_lastChanged", t) -- Update the last modification timestamp
        rawset(self._data, key, value) -- Update the value in the internal data storage
        self._onChange(self) -- Trigger the internal onChange handler
    end
end

-- groupStats base table containing all collected data
local groupStats = {
    [PLAYER_CHARACTER_NAME] = {
        tag = localPlayer,
        name = PLAYER_CHARACTER_NAME,
        displayName = PLAYER_DISPLAY_NAME,
        isPlayer = true,
        isOnline = true,

        ult = ObservableTable:New(function(data)
            LocalEM:FireCallbacks(EVENT_PLAYER_ULT_UPDATE, localPlayer, data)
        end, 10, {
            ultValue = 0,
            ult1ID = 0,
            ult2ID = 0,
            ult1Cost = 0,
            ult2Cost = 0,
            ultActivatedSetID = 0,
        }),

        dps = ObservableTable:New(function(data)
            LocalEM:FireCallbacks(EVENT_PLAYER_DPS_UPDATE, localPlayer, data)
        end, 10, {
            dmgType = 0,
            dmg = 0,
            dps = 0,
        }),

        hps = ObservableTable:New(function(data)
            LocalEM:FireCallbacks(EVENT_PLAYER_HPS_UPDATE, localPlayer, data)
        end, 10, {
            overheal = 0,
            hps = 0,
        }),
    }
}
local playerStats = groupStats[PLAYER_CHARACTER_NAME] -- local alias for the stats of the player


--- _CombatStatsObject which can be used by other addons to get data or register callbacks for events - it acts as a communication gateway between addons & the lib
local _CombatStatsObject = {}
_CombatStatsObject.__index = _CombatStatsObject
-- Constructor for the _CombatStatsObject
-- @return (table): A new instance of _CombatStatsObject
function _CombatStatsObject:New()
    local obj = setmetatable({}, _CombatStatsObject)
    return obj
end
-- Returns a list of functionalities currently enabled in the library
-- @return (string, string, string): Currently enabled functionalities ("DPS", "HPS", "ULT")
function _CombatStatsObject:GetStatsShared()
    return ZO_DeepTableCopy(_statsShared)
end
-- Returns key, value of groupStats
-- @return (string, table): key value pairs of groupStats
function _CombatStatsObject:Iterate()
    local key, value
    return function()
        key, value = next(groupStats, key)
        if not key then
            return nil
        end

        local stats = groupStats[key]
        local ult = stats.ult
        local dps = stats.dps
        local hps = stats.hps
        return stats.tag, {
            tag = stats.tag,
            name = stats.name,
            displayName = stats.displayName,
            isPlayer = stats.isPlayer,

            ult = {
                ultValue = ult.ultValue,
                ult1ID = ult.ult1ID,
                ult2ID = ult.ult2ID,
                ult1Cost = ult.ult1Cost,
                ult2Cost = ult.ult2Cost,
                ultActivatedSetID = ult.ultActivatedSetID,
                _lastUpdated = ult._lastUpdated,
                _lastChanged = ult._lastChanged
            },
            dps = {
                dmgType = dps.dmgType,
                dps = dps.dps,
                dmg = dps.dmg,
                _lastUpdated = dps._lastUpdated,
                _lastChanged = dps._lastChanged
            },
            hps = {
                hps = hps.hps,
                overheal = hps.overheal,
                _lastUpdated = hps._lastUpdated,
                _lastChanged = hps._lastChanged
            },
        }
    end
end
-- metatable version of _CombatStatsObject:Iterate()
function _CombatStatsObject:__pairs()
    return self:Iterate()
end
-- Returns the number of group members in "groupStats"
-- @return (number): the number of units in the group
function _CombatStatsObject:GetGroupSize()
    return #groupStats
end
-- metatable version of _CombatStatsObject:GetGroupSize()
function _CombatStatsObject:__len()
    return self:GetGroupSize()
end
-- Retrieves a copy of the current group statistics
-- @return (table): A table containing group statistics (cloned from the internal state)
function _CombatStatsObject:GetGroupStats()
    local result = {}
    for tag, stats in self:Iterate() do
        result[tag] = stats
    end

    return result
end
-- Retrieves statistics for a specific unit in the group
-- @param unitTag (string): The unitTag of the group member (e.g., "group1")
-- @return (table or nil): A table containing the unit's statistics, or nil if the unit is not found
function _CombatStatsObject:GetUnitStats(unitTag)
    local characterName = GetUnitName(unitTag)
    local unit = groupStats[characterName]
    if not unit then
        Log("debug", LOG_LEVEL_DEBUG, "unit does not exist in groupStats")
        return nil
    end
    local ult = unit.ult
    local dps = unit.dps
    local hps = unit.hps
    local result = {
        tag = unit.tag,
        name = unit.name,
        displayName = unit.displayName,
        isPlayer = unit.isPlayer,

        ult = {
            ultValue = ult.ultValue,
            ult1ID = ult.ult1ID,
            ult2ID = ult.ult2ID,
            ult1Cost = ult.ult1Cost,
            ult2Cost = ult.ult2Cost,
            ultActivatedSetID = ult.ultActivatedSetID,
            _lastUpdated = ult._lastUpdated,
        },
        dps = {
            dmgType = dps.dmgType,
            dps = dps.dps,
            dmg = dps.dmg,
            _lastUpdated = dps._lastUpdated,
        },
        hps = {
            hps = hps.hps,
            overheal = hps.overheal,
            _lastUpdated = hps._lastUpdated,
        }
    }

    return result
end
-- Retrieves DPS information for a specific unit in the group
-- @param unitTag (string): The unitTag of the group member
-- @return (string, number, number, number): The type of damage, total damage, DPS value, and the timestamp of the last DPS update
function _CombatStatsObject:GetUnitDPS(unitTag)
    local characterName = GetUnitName(unitTag)
    local unit = groupStats[characterName]
    if not unit then
        Log("debug", LOG_LEVEL_DEBUG, "unit does not exist in groupStats")
        return nil
    end

    return unit.dps.dmgType, unit.dps.dmg, unit.dps.dps, unit.dps._lastUpdated
end
-- Retrieves HPS information for a specific unit in the group
-- @param unitTag (string): The unitTag of the group member
-- @return (number, number, number): The overhealing value, HPS value, and the timestamp of the last HPS update
function _CombatStatsObject:GetUnitHPS(unitTag)
    local characterName = GetUnitName(unitTag)
    local unit = groupStats[characterName]
    if not unit then
        Log("debug", LOG_LEVEL_DEBUG, "unit does not exist in groupStats")
        return nil
    end

    return unit.hps.overheal, unit.hps.hps, unit.hps._lastUpdated
end
-- Retrieves ultimate information for a specific unit in the group
-- @param unitTag (string): The unitTag of the group member
-- @return (number, number, number, number, number, number):
-- The current ultimate value, ultimate 1 ID, ultimate 1 cost, ultimate 2 ID, ultimate 2 cost, and the ID for an ultActivated set
function _CombatStatsObject:GetUnitULT(unitTag)
    local characterName = GetUnitName(unitTag)
    local unit = groupStats[characterName]
    if not unit then
        Log("debug", LOG_LEVEL_DEBUG, "unit does not exist in groupStats")
        return nil
    end

    return unit.ult.ultValue, unit.ult.ult1ID, unit.ult.ult1Cost, unit.ult.ult2ID, unit.ult.ult2Cost, unit.ult.ultActivatedSetID, unit.ult._lastUpdated
end
-- Registers a callback function for a specified event
-- @param eventName (string): The name of the event to register for
-- @param callback (function): The function to be called when the event is triggered
function _CombatStatsObject:RegisterForEvent(eventName, callback)
    if not IsCallable(callback) then Log("events", LOG_LEVEL_ERROR, "callback is not a function") return end
    if type(eventName) ~= "string" then Log("events", LOG_LEVEL_ERROR, "eventName is not a string") return end

    LocalEM:RegisterCallback(eventName, callback)
    Log("events", LOG_LEVEL_DEBUG, "callback for %s registered", eventName)
end
-- Unregisters a callback function for a specified event
-- @param eventName (string): The name of the event to unregister from
-- @param callback (function): The callback function to unregister
function _CombatStatsObject:UnregisterForEvent(eventName, callback)
    if not IsCallable(callback) then Log("events", LOG_LEVEL_ERROR, "callback is not a function") return end
    if type(eventName) ~= "string" then Log("events", LOG_LEVEL_ERROR, "eventName is not a string") return end

    Log("events", LOG_LEVEL_DEBUG, "callback for %s unregistered", eventName)
    LocalEM:UnregisterCallback(eventName, callback)
end



--- Combat extension ( stolen from HodorReflexes - thanks andy.s <3 )
local LC = LibCombat
local combat = {}
local LIBCOMBAT_CALLBACK_NAME = lib_name .. "_Combat"

local combatData = {
    DPSOut = 0,
    HPSOut = 0,
    HPSAOut = 0,
    dpstime = 0,
    hpstime = 0,
    bossfight = false,
    units = {}
}

function combat.InitData()
    combatData = {DPSOut = 0, HPSOut = 0, HPSAOut = 0, dpstime = 0, hpstime = 0, bossfight = false, units = {}}
end
function combat.UnitsCallback(_, units)
    combatData.units = units
end
function combat.FightRecapCallback(_, data)
    combatData.DPSOut = data.DPSOut
    combatData.HPSOut = data.HPSOut
    combatData.HPSAOut = data.HPSAOut
    combatData.dpstime = data.dpstime
    combatData.hpstime = data.hpstime
    combatData.bossfight = data.bossfight
end
function combat.Register()

    combat.InitData()

    LC:RegisterCallbackType(LIBCOMBAT_EVENT_UNITS, combat.UnitsCallback, LIBCOMBAT_CALLBACK_NAME)
    LC:RegisterCallbackType(LIBCOMBAT_EVENT_FIGHTRECAP, combat.FightRecapCallback, LIBCOMBAT_CALLBACK_NAME)
    Log("events", LOG_LEVEL_DEBUG, "registered to LibCombat")

end
function combat.Unregister()

    combat.InitData()

    LC:UnregisterCallbackType(LIBCOMBAT_EVENT_UNITS, combat.UnitsCallback, LIBCOMBAT_CALLBACK_NAME)
    LC:UnregisterCallbackType(LIBCOMBAT_EVENT_FIGHTRECAP, combat.FightRecapCallback, LIBCOMBAT_CALLBACK_NAME)
    Log("events", LOG_LEVEL_DEBUG, "unregistered from LibCombat")

end
function combat.Reset()
    combat.InitData()
end
function combat.GetData()
    return combatData
end
function combat.GetCombatTime()
    return zo_roundToNearest(zo_max(combatData.dpstime, combatData.hpstime), 0.1)
end
-- Returns total damage done to all enemy units in the current fight.
function combat.GetFullDamage()
    local damage = 0
    for _, unit in pairs(combatData.units) do
        local totalUnitDamage = unit.damageOutTotal
        if not unit.isFriendly and totalUnitDamage > 0 then
            damage = damage + totalUnitDamage
        end
    end
    return damage
end
-- Returns total damage done to all bosses in the current fight.
function combat.GetBossTargetDamage()
    if not combatData.bossfight then return 0, 0, 0 end

    local bossUnits, totalBossDamage = 0, 0
    local starttime, endtime

    for _, unit in pairs(combatData.units) do
        local totalUnitDamage = unit.damageOutTotal
        if unit.bossId ~= nil and totalUnitDamage > 0 then
            totalBossDamage = totalBossDamage + totalUnitDamage
            bossUnits = bossUnits + 1
            starttime = zo_min(starttime or unit.dpsstart or 0, unit.dpsstart or 0)
            endtime = zo_max(endtime or unit.dpsend or 0, unit.dpsend or 0)
        end
    end

    if bossUnits == 0 then return 0, 0, 0 end

    local bossTime = (endtime - starttime) / 1000
    bossTime = bossTime > 0 and bossTime or combatData.dpstime

    return bossUnits, totalBossDamage, bossTime
end


--- update player values
local function updatePlayerUltValue()
    playerStats.ult.ultValue = zo_max(0, zo_min(500, GetUnitPower(localPlayer, POWERTYPE_ULTIMATE)))
    LocalEM:FireCallbacks(EVENT_PLAYER_ULT_VALUE_UPDATE, localPlayer, playerStats.ult)
end
local function updatePlayerDps()
    local dmgType = 0
    local dmg = 0
    local dps = 0

    local data = combat.GetData()

    if data.DPSOut == 0 then
        dmgType, dmg, dps = DAMAGE_UNKNOWN, 0, 0
    else
        local bossUnits, bossDamage, bossTime = combat.GetBossTargetDamage()
        if bossUnits > 0 then
            dmgType, dmg, dps = DAMAGE_BOSS, zo_floor(bossDamage / bossTime / 100), zo_floor(data.DPSOut / 1000)
        else
            dmgType, dmg, dps = DAMAGE_TOTAL, zo_floor(combat.GetFullDamage() / 10000), zo_floor(data.DPSOut / 1000)
        end
    end

    playerStats.dps.dmgType = dmgType
    playerStats.dps.dmg = dmg
    playerStats.dps.dps = dps
end
local function updatePlayerHps()
    local overheal = 0
    local hps = 0

    local data = combat.GetData()

    if data.HPSOut == 0 or data.HPSAOut == 0 then
        overheal, hps = 0, 0
    end

    playerStats.hps.overheal = zo_floor(data.HPSAOut / 1000)
    playerStats.hps.hps = zo_floor(data.HPSOut / 1000 )
end
local function updatePlayerSlottedUlts()
    -- reset values
    playerStats.ult.ult1ID = 0
    playerStats.ult.ult2ID = 0
    playerStats.ult.ult1Cost = 0
    playerStats.ult.ult2Cost = 0

    -- populate values
    playerStats.ult.ult1ID = GetSlotBoundId(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_PRIMARY)
    playerStats.ult.ult2ID = GetSlotBoundId(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_BACKUP)
    playerStats.ult.ult1Cost = GetAbilityCost(playerStats.ult.ult1ID)
    playerStats.ult.ult2Cost = GetAbilityCost(playerStats.ult.ult2ID)

    LocalEM:FireCallbacks(EVENT_PLAYER_ULT_TYPE_UPDATE, localPlayer, playerStats.ult)
end
local function updatePlayerUltimateCost()
    local ult1Cost = GetAbilityCost(playerStats.ult.ult1ID)
    local ult2Cost = GetAbilityCost(playerStats.ult.ult2ID)
    if playerStats.ult.ult1Cost == ult1Cost and playerStats.ult.ult2Cost == ult2Cost then return end

    playerStats.ult.ult1Cost = GetAbilityCost(playerStats.ult.ult1ID)
    playerStats.ult.ult2Cost = GetAbilityCost(playerStats.ult.ult2ID)
    LocalEM:FireCallbacks(EVENT_PLAYER_ULT_TYPE_UPDATE, localPlayer, playerStats.ult)
end
local function updatePlayerUltActivatedSets()
    -- reset values
    playerStats.ult.ultActivatedSetID = 0

    -- populate values
    for id, set in ipairs(ULT_ACTIVATED_SET_LIST) do
        local _, _, _, nonPerfectedNum, _, _id, perfectedNum = GetItemLinkSetInfo(set.link, true)
        local num = nonPerfectedNum + (perfectedNum or 0)

        if num >= set.minEquipped then
            playerStats.ult.ultActivatedSetID = id
        end
    end

    LocalEM:FireCallbacks(EVENT_PLAYER_ULT_TYPE_UPDATE, localPlayer, playerStats.ult)
end
local function unregisterPlayerStatsUpdateFunctions()
    combat.Unregister()
    EM:UnregisterForUpdate(lib_name .. "_ultValueUpdate")
    EM:UnregisterForUpdate(lib_name .. "_ultCostUpdate")
    EM:UnregisterForUpdate(lib_name .. "_dpsUpdate")
    EM:UnregisterForUpdate(lib_name .. "_hpsUpdate")
    EM:UnregisterForEvent(lib_name .. "_ultTypeUpdate", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED)
    EM:UnregisterForEvent(lib_name .. "_ultTypeUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    Log("events", LOG_LEVEL_DEBUG, "playerStatsUpdate functions unregistered")
end
local function registerPlayerStatsUpdateFunctions()
    combat.Register()
    EM:RegisterForUpdate(lib_name .. "_ultValueUpdate", PLAYER_ULT_VALUE_UPDATE_INTERVAL, updatePlayerUltValue)
    EM:RegisterForUpdate(lib_name .. "_ultCostUpdate", PLAYER_ULT_VALUE_UPDATE_INTERVAL, updatePlayerUltimateCost)
    EM:RegisterForUpdate(lib_name .. "_dpsUpdate", PLAYER_DPS_UPDATE_INTERVAL, updatePlayerDps)
    EM:RegisterForUpdate(lib_name .. "_hpsUpdate", PLAYER_HPS_UPDATE_INTERVAL, updatePlayerHps)
    EM:RegisterForEvent(lib_name .. "_ultTypeUpdate", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, updatePlayerSlottedUlts)
    EM:RegisterForEvent(lib_name .. "_ultTypeUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, updatePlayerUltActivatedSets)
    Log("events", LOG_LEVEL_DEBUG, "playerStatsUpdate functions registered")
end


--- receiving broadcast callbacks
local function toNewToProcessWarning()
    Log("events", LOG_LEVEL_WARNING, "someone is trying to send you newer data than you can process with " .. lib_name .. ": " .. lib_version .. ". Please check if there is a newer version available and install it")
end

local function onMessageUltTypeUpdateReceived(unitTag, data)
    if AreUnitsEqual(unitTag, localPlayer) then return end

    local charName = GetUnitName(unitTag)
    if not groupStats[charName] then return end

    groupStats[charName].ult.ult1ID = _ultInternalIdMap[data.ult1ID]
    groupStats[charName].ult.ult2ID = _ultInternalIdMap[data.ult2ID]
    groupStats[charName].ult.ult1Cost = data.ult1Cost * 2
    groupStats[charName].ult.ult2Cost = data.ult2Cost * 2
    groupStats[charName].ult.ultActivatedSetID = data.ultActivatedSetID
end
local function onMessageUltValueUpdateReceived(unitTag, data)
    if AreUnitsEqual(unitTag, localPlayer) then return end

    local charName = GetUnitName(unitTag)
    if not groupStats[charName] then return end

    data.ultValue = data.ultValue * 2

    groupStats[charName].ult.ultValue = data.ultValue
end
local function onMessageDpsUpdateReceived(unitTag, data)
    if AreUnitsEqual(unitTag, localPlayer) then return end

    local charName = GetUnitName(unitTag)
    if not groupStats[charName] then return end

    groupStats[charName].dps.dmgType = data.dmgType
    groupStats[charName].dps.dmg = data.dmg
    groupStats[charName].dps.dps = data.dps
end
local function onMessageHpsUpdateReceived(unitTag, data)
    if AreUnitsEqual(unitTag, localPlayer) then return end

    local charName = GetUnitName(unitTag)
    if not groupStats[charName] then return end

    groupStats[charName].hps.overheal = data.overheal
    groupStats[charName].hps.hps = data.hps
end

local function onMessageUltTypeUpdateReceived_V2(unitTag, data) toNewToProcessWarning() end
local function onMessageUltValueUpdateReceived_V2(unitTag, data) toNewToProcessWarning() end
local function onMessageDpsUpdateReceived_V2(unitTag, data) toNewToProcessWarning() end
local function onMessageHpsUpdateReceived_V2(unitTag, data) toNewToProcessWarning() end


--- periodically sent broadcast messages
local function broadcastPlayerDps(_, force)
    if not IsUnitGrouped(localPlayer) then return end
    if not _statsShared[DPS] then return end
    if not force and GetGameTimeMilliseconds() - playerStats.dps._lastChanged > PLAYER_DPS_SEND_INTERVAL then return end

    local data = {
        dmgType = playerStats.dps.dmgType,
        dmg = playerStats.dps.dmg,
        dps = playerStats.dps.dps
    }

    _LGBProtocols[MESSAGE_ID_DPS]:Send(data)
end
local function broadcastPlayerHps(_, force)
    if not IsUnitGrouped(localPlayer) then return end
    if not _statsShared[HPS] then return end
    if not force and GetGameTimeMilliseconds() - playerStats.hps._lastChanged > PLAYER_HPS_SEND_INTERVAL then return end

    local data = {
        overheal = playerStats.hps.overheal,
        hps = playerStats.hps.hps
    }

    _LGBProtocols[MESSAGE_ID_HPS]:Send(data)
end
local function broadcastPlayerUltValue(_, force)
    if not IsUnitGrouped(localPlayer) then return end
    if not _statsShared[ULT] then return end
    if not force and GetGameTimeMilliseconds() - playerStats.ult._lastChanged > PLAYER_ULT_VALUE_SEND_INTERVAL then return end

    local data = {
        ultValue = zo_floor(playerStats.ult.ultValue / 2)
    }

    _LGBProtocols[MESSAGE_ID_ULTVALUE]:Send(data)
end
local function broadcastPlayerUltType()
    if not IsUnitGrouped(localPlayer) then return end
    if not _statsShared[ULT] then return end

    local ult1InternalId = _ultIdMap[playerStats.ult.ult1ID]
    local ult2InternalId = _ultIdMap[playerStats.ult.ult2ID]

    local data = {
        ult1ID = ult1InternalId,
        ult2ID = ult2InternalId,
        ult1Cost = zo_floor(playerStats.ult.ult1Cost / 2),
        ult2Cost = zo_floor(playerStats.ult.ult2Cost / 2 ),
        ultActivatedSetID = playerStats.ult.ultActivatedSetID
    }

    _LGBProtocols[MESSAGE_ID_ULTTYPE]:Send(data)
end


--- on demand sent broadcast messages
-- this ObservableTable is created to have a callback function waiting on further changes before broadcasting to avoid sending multiple messages when swapping loadouts
local playerUltTypeObservableTable = ObservableTable:New(broadcastPlayerUltType, 2000, {
    lastChange = GetGameTimeMilliseconds(),
})

-- writes to playerUltTypeObservableTable to trigger the broadcastPlayerUltType
local function onPlayerUltTypeUpdate(unitTag, _)
    if unitTag ~= localPlayer then return end
    playerUltTypeObservableTable.lastChange = GetGameTimeMilliseconds()
end


--- sync packet logic
local function broadcastSyncRequest()
    if not IsUnitGrouped(localPlayer) then return end
    _LGBProtocols[MESSAGE_ID_SYNC]:Send({
        syncRequest = true
    })
end
local function onMessageSyncReceived(unitTag, data)
    if AreUnitsEqual(unitTag, localPlayer) then return end

    if data.syncRequest then
        broadcastPlayerUltType()
        broadcastPlayerUltValue(_, true)
        broadcastPlayerDps(_, true)
        broadcastPlayerHps(_, true)
    end
end


--- enable / disable broadcasting of stats
local function disablePlayerBroadcastDPS()
    EM:UnregisterForUpdate(lib_name .. "_SendDps") -- unregister periodic dps broadcast

    Log("events", LOG_LEVEL_DEBUG, "DPS broadcast disabled")
end
local function enablePlayerBroadcastDPS()
    disablePlayerBroadcastDPS()
    EM:RegisterForUpdate(lib_name .. "_SendDps", PLAYER_DPS_SEND_INTERVAL,broadcastPlayerDps) -- register periodic dps broadcast

    Log("events", LOG_LEVEL_DEBUG, "DPS broadcast enabled")
end
local function disablePlayerBroadcastHPS()
    EM:UnregisterForUpdate(lib_name .. "_SendHps")  -- unregister periodic hps broadcast

    Log("events", LOG_LEVEL_DEBUG, "HPS broadcast disabled")
end
local function enablePlayerBroadcastHPS()
    disablePlayerBroadcastHPS()
    EM:RegisterForUpdate(lib_name .. "_SendHps", PLAYER_HPS_SEND_INTERVAL, broadcastPlayerHps) -- register periodic hps broadcast

    Log("events", LOG_LEVEL_DEBUG, "HPS broadcast enabled")
end
local function disablePlayerBroadcastULT()
    EM:UnregisterForUpdate(lib_name .. "_SendUltValue") -- unregister periodic ultValue broadcast
    LocalEM:UnregisterCallback(EVENT_PLAYER_ULT_TYPE_UPDATE, onPlayerUltTypeUpdate) -- unregister async ultType broadcast

    Log("events", LOG_LEVEL_DEBUG, "ULT broadcast disabled")
end
local function enablePlayerBroadcastULT()
    disablePlayerBroadcastULT()
    EM:RegisterForUpdate(lib_name .. "_SendUltValue", PLAYER_ULT_VALUE_SEND_INTERVAL, broadcastPlayerUltValue) -- register periodic ultValue broadcast
    LocalEM:RegisterCallback(EVENT_PLAYER_ULT_TYPE_UPDATE, onPlayerUltTypeUpdate) -- register async ultType broadcast

    Log("events", LOG_LEVEL_DEBUG, "ULT broadcast enabled")
end


--- group change tracking
local function OnGroupChange()
    local _existingGroupCharacters = {} -- create empty table to create a list of all groupmembers after the change
    local _groupSize = GetGroupSize()

    for i = 1, _groupSize do
        local tag = GetGroupUnitTagByIndex(i)

        if IsUnitPlayer(tag) then

            local isPlayer = AreUnitsEqual(tag, localPlayer)
            local characterName = GetUnitName(tag)
            _existingGroupCharacters[characterName] = true

            if not isPlayer then
                groupStats[characterName] = groupStats[characterName] or {
                    name = characterName,
                    displayName = GetUnitDisplayName(tag),
                    isPlayer = isPlayer,
                    isOnline = IsUnitOnline(tag),

                    ult = ObservableTable:New(function(data)
                        LocalEM:FireCallbacks(EVENT_GROUP_ULT_UPDATE, tag, data)
                    end, 10, {
                        ultValue = 0,
                        ult1ID = 0,
                        ult2ID = 0,
                        ult1Cost = 0,
                        ult2Cost = 0,
                        ultActivatedSetID = 0,
                    }),

                    dps = ObservableTable:New(function(data)
                        LocalEM:FireCallbacks(EVENT_GROUP_DPS_UPDATE, tag, data)
                    end, 10, {
                        dmgType = 0,
                        dmg = 0,
                        dps = 0,
                    }),

                    hps = ObservableTable:New(function(data)
                        LocalEM:FireCallbacks(EVENT_GROUP_HPS_UPDATE, tag, data)
                    end, 10, {
                        overheal = 0,
                        hps = 0,
                    }),
                }


            end
            groupStats[characterName].tag = tag
            --groupStats[characterName].isOnline = IsUnitOnline(tag)
        end
    end


    for characterName, _ in pairs(groupStats) do
        if characterName ~= PLAYER_CHARACTER_NAME then
            if not _existingGroupCharacters[characterName] then
                groupStats[characterName] = nil
            end
        end
    end
end
local function OnGroupChangeDelayed()
    zo_callLater(OnGroupChange, 500) -- wait 500ms to avoid any race conditions
    zo_callLater(broadcastPlayerUltType, PLAYER_ULT_TYPE_SEND_ON_GROUP_CHANGE_DELAY) -- broadcast ultType so new members are up to date
    zo_callLater(function() broadcastPlayerUltValue(_, true) end, PLAYER_ULT_VALUE_SEND_ON_GROUP_CHANGE_DELAY) -- broadcast ultValue so new members are up to date
end
local function unregisterGroupEvents()
    EM:UnregisterForEvent(lib_name, EVENT_GROUP_MEMBER_JOINED)
    EM:UnregisterForEvent(lib_name, EVENT_GROUP_MEMBER_LEFT)
    --EM:UnregisterForEvent(lib_name, EVENT_GROUP_UPDATE)
    EM:UnregisterForEvent(lib_name, EVENT_GROUP_MEMBER_CONNECTED_STATUS)
    Log("events", LOG_LEVEL_DEBUG, "group events unregistered")
end
local function registerGroupEvents()
    EM:RegisterForEvent(lib_name, EVENT_GROUP_MEMBER_JOINED, OnGroupChangeDelayed)
    EM:RegisterForEvent(lib_name, EVENT_GROUP_MEMBER_LEFT, OnGroupChangeDelayed)
    --EM:RegisterForEvent(lib_name, EVENT_GROUP_UPDATE, OnGroupChangeDelayed)
    EM:RegisterForEvent(lib_name, EVENT_GROUP_MEMBER_CONNECTED_STATUS, OnGroupChangeDelayed)
    Log("events", LOG_LEVEL_DEBUG, "group events registered")
end


--- exposed API Calls
function lib.RegisterAddon(addonName, neededStats)
    if not addonName or not neededStats then
        Log("main", LOG_LEVEL_ERROR, "addonName & neededStats must be provided")
        return
    end

    if _registeredAddons[addonName] then
        Log("debug", LOG_LEVEL_ERROR, "Addon %s tried to register multiple times", addonName)
        return nil
    end

    _registeredAddons[addonName] = true
    for _, stat in ipairs(neededStats) do
        if not _statsShared[stat] then
            if stat == DPS then
                enablePlayerBroadcastDPS()
            elseif stat == HPS then
                enablePlayerBroadcastHPS()
            elseif stat == ULT then
                enablePlayerBroadcastULT()
            end
            Log("debug", LOG_LEVEL_DEBUG, addonName .. " requested " .. stat)
        end

        _statsShared[stat] = true
    end

    Log("debug", LOG_LEVEL_INFO, "Addon " .. addonName .. " registered.")
    return _CombatStatsObject:New()
end

--- generate Ultimate ID maps
local function generateUltIdMaps()
    _ultInternalIdMap = {}
    _ultIdMap = {}

    local tempUltimates = {}

    for skillType = 1, GetNumSkillTypes() do
        for skillLineIndex = 1, GetNumSkillLines(skillType) do
            for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                local isUltimate = IsSkillAbilityUltimate(skillType, skillLineIndex, skillIndex) -- check if skill is ultimate
                if isUltimate then
                    local _tempIds = {} -- create temporary table for all sill Ids of each morph
                    for morph = 0, 2 do -- there is only 1 base rank and 2 morphs
                        local abilityId, _ = GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, morph, 0)
                        table.insert(_tempIds, abilityId)

                        if abilityId == 0 then _tempIds = {} end -- if the ability Id is 0, clear all previously collected Ids from the temporary table because there is no ultimate without 2 morphs
                    end
                    -- iterate over temporary Id table and write it to our final destination
                    for _, _abilityId in ipairs(_tempIds) do
                        table.insert(tempUltimates, _abilityId)
                    end
                end
            end
        end
    end

    table.sort(tempUltimates)

    for internalID, abilityId in ipairs(tempUltimates) do
        _ultIdMap[abilityId] = internalID
        _ultInternalIdMap[internalID] = abilityId
    end

    _ultInternalIdMap[0] = 0
    _ultIdMap[0] = 0
end

--- Addon initialization
local function onPlayerActivated(_, initial)
   -- check if it's the first call of onPlayerActivated - for example after logging in or after a reloadui
    if not _isFirstOnPlayerActivated then return end

    Log("debug", LOG_LEVEL_DEBUG, "onPlayerActivated called")

    -- trigger group update
    OnGroupChangeDelayed()

    -- request sync from group members
    broadcastSyncRequest()

    -- register group update events
    unregisterGroupEvents()
    registerGroupEvents()

    -- register update functions for values
    unregisterPlayerStatsUpdateFunctions()
    registerPlayerStatsUpdateFunctions()

    -- set player ult & sets
    updatePlayerSlottedUlts()
    updatePlayerUltActivatedSets()

    _isFirstOnPlayerActivated = false
end

--- LibGroupBroadcast
local function declareLGBProtocols()
    local CreateNumericField = LGB.CreateNumericField
    local CreateFlagField = LGB.CreateFlagField

    local protocolOptions = {
        isRelevantInCombat = true
    }
    local handlerId = LGB:RegisterHandler("LibGroupCombatStats", "LibGroupCombatStats")
    d(handlerId)
    local protocolSync = LGB:DeclareProtocol(handlerId, MESSAGE_ID_SYNC, "LibGroupCombatStats Sync Packet")
    protocolSync:AddField(CreateFlagField("syncRequest", {
        defaultValue = false,
    }))
    protocolSync:OnData(onMessageSyncReceived)
    protocolSync:Finalize(protocolOptions)

    local protocolDps = LGB:DeclareProtocol(handlerId, MESSAGE_ID_DPS, "LibGroupCombatStats DPS Share")
    protocolDps:AddField(CreateNumericField("dmgType", {
        minValue = 0,
        maxValue = 2,
    }))
    protocolDps:AddField(CreateNumericField("dmg", {
        minValue = 0,
        maxValue = 9999,
    }))
    protocolDps:AddField(CreateNumericField("dps", {
        minValue = 0,
        maxValue = 999,
    }))
    protocolDps:OnData(onMessageDpsUpdateReceived)
    protocolDps:Finalize(protocolOptions)

    local protocolHps = LGB:DeclareProtocol(handlerId, MESSAGE_ID_HPS, "LibGroupCombatStats HPS Share")
    protocolHps:AddField(CreateNumericField("overheal", {
        minValue = 0,
        maxValue = 999,
    }))
    protocolHps:AddField(CreateNumericField("hps", {
        minValue = 0,
        maxValue = 999,
    }))
    protocolHps:OnData(onMessageHpsUpdateReceived)
    protocolHps:Finalize(protocolOptions)

    local protocolUltType = LGB:DeclareProtocol(handlerId, MESSAGE_ID_ULTTYPE, "LibGroupCombatStats Ult Type Share")
    protocolUltType:AddField(CreateNumericField("ult1ID", {
        minValue = 0,
        maxValue = 127,
        --maxValue = 2^18-1,
    }))
    protocolUltType:AddField(CreateNumericField("ult2ID", {
        minValue = 0,
        maxValue = 127,
    }))
    protocolUltType:AddField(CreateNumericField("ult1Cost", {
        minValue = 0,
        maxValue = 250,
    }))
    protocolUltType:AddField(CreateNumericField("ult2Cost", {
        minValue = 0,
        maxValue = 250,
    }))
    protocolUltType:AddField(CreateNumericField("ultActivatedSetID", {
        minValue = 0,
        maxValue = 2^4-1,
    }))
    protocolUltType:OnData(onMessageUltTypeUpdateReceived)
    protocolUltType:Finalize(protocolOptions)

    local protocolUltValue = LGB:DeclareProtocol(handlerId, MESSAGE_ID_ULTVALUE, "LibGroupCombatStats Ult Value Share")
    protocolUltValue:AddField(CreateNumericField("ultValue", {
        minValue = 0,
        maxValue = 250,
    }))
    protocolUltValue:OnData(onMessageUltValueUpdateReceived)
    protocolUltValue:Finalize(protocolOptions)

    _LGBProtocols[MESSAGE_ID_SYNC] = protocolSync
    _LGBProtocols[MESSAGE_ID_DPS] = protocolDps
    _LGBProtocols[MESSAGE_ID_HPS] = protocolHps
    _LGBProtocols[MESSAGE_ID_ULTTYPE] = protocolUltType
    _LGBProtocols[MESSAGE_ID_ULTVALUE] = protocolUltValue
end


--- register the addon
EM:RegisterForEvent(lib_name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= lib_name then return end
    EM:UnregisterForEvent(lib_name, EVENT_ADD_ON_LOADED)

    generateUltIdMaps()
    declareLGBProtocols()

    -- register onPlayerActivated callback
    EM:UnregisterForEvent(lib_name, EVENT_PLAYER_ACTIVATED)
    EM:RegisterForEvent(lib_name, EVENT_PLAYER_ACTIVATED, onPlayerActivated)
    Log("main", LOG_LEVEL_DEBUG, "Library initialized")
end)

--- cli commands
SLASH_COMMANDS["/libGroupCombatStats"] = function(str)
    if str == "version" then
        d(lib_version)
    end
end



--- debugging & testing
SLASH_COMMANDS["/libshare"] = function(str)
    if str == "debug" then
        lib_debug = true


        lib.groupStats = groupStats
        local instance = lib.RegisterAddon("LibGroupCombatStatsTest", {"ULT", "HPS", "DPS"})


        local function logEvent(eventName)
            LocalEM:RegisterCallback(eventName, function(unitTag, data)
                Log("event", LOG_LEVEL_INFO, eventName, unitTag, data )
            end)
        end

        --logEvent(EVENT_GROUP_DPS_UPDATE)
        --logEvent(EVENT_GROUP_HPS_UPDATE)
        --logEvent(EVENT_GROUP_ULT_UPDATE)
        --logEvent(EVENT_PLAYER_DPS_UPDATE)
        --logEvent(EVENT_PLAYER_HPS_UPDATE)
        --logEvent(EVENT_PLAYER_ULT_UPDATE)
        --logEvent(EVENT_PLAYER_ULT_TYPE_UPDATE)
        --logEvent(EVENT_PLAYER_ULT_VALUE_UPDATE)
    end
end

