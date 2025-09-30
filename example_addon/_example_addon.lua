-- SPDX-FileCopyrightText: 2025 m00nyONE
-- SPDX-License-Identifier: Artistic-2.0

-- ExampleAddon.lua
local ExampleAddon = {} -- Main table for the add-on
ExampleAddon.name = "ExampleAddon" -- Name of the add-on

local strfmt = string.format -- Shortcut for the string.format function
local lgcs = nil -- Placeholder for the library object

-- define constants
local EVENT_GROUP_DPS_UPDATE = LibGroupCombatStats.EVENT_GROUP_DPS_UPDATE
local EVENT_GROUP_HPS_UPDATE = LibGroupCombatStats.EVENT_GROUP_HPS_UPDATE
local EVENT_GROUP_ULT_UPDATE = LibGroupCombatStats.EVENT_GROUP_ULT_UPDATE

-- Callback function for group DPS updates
-- Triggered whenever group DPS stats are updated
local function OnGroupDPSUpdate(unitTag, dpsData)
    local characterName = GetUnitName(unitTag) or "Unknown" -- Get the name of the unit (player or group member)
    local dmgType = dpsData.dmgType == 1 and "Boss" or "Total" -- Determine if the damage type is for bosses or total
    d(strfmt("[%s] %s DPS: %d (Type: %s)", ExampleAddon.name, characterName, dpsData.dps, dmgType)) -- Display the DPS data in the chat
end

-- Callback function for group HPS updates
-- Triggered whenever group HPS stats are updated
local function OnGroupHPSUpdate(unitTag, hpsData)
    local characterName = GetUnitName(unitTag) or "Unknown" -- Get the name of the unit
    d(strfmt("[%s] %s HPS: %d (Overheal: %d)", ExampleAddon.name, characterName, hpsData.hps, hpsData.overheal)) -- Display HPS and overheal stats in the chat
end

-- Callback function for group ULT updates
-- Triggered whenever group ultimate stats are updated
local function OnGroupULTUpdate(unitTag, ultData)
    local characterName = GetUnitName(unitTag) or "Unknown" -- Get the name of the unit
    d(strfmt("[%s] %s ULT Value: %d | Ult1ID: %d | Ult2ID: %d | Ult1Needed: %d | Ult2Needed: %d", ExampleAddon.name, characterName, ultData.ultValue, ultData.ult1ID, ultData.ult2ID, ultData.ult1Needed, ultData.ult2Needed)) -- Display ultimate stats in the chat
end

-- Function to display detailed statistics for a specific unit (e.g., player or group member)
local function DisplayUnitStats(unitTag)
    local stats = lgcs:GetUnitStats(unitTag) -- Retrieve stats for the specified unit tag
    if stats then
        -- Display stats for the unit in the chat
        d(strfmt("[%s] Unit Stats for %s:", ExampleAddon.name, GetUnitName(unitTag)))
        d(strfmt("DPS: %d | HPS: %d | ULT Value: %d", stats.dps.dps or 0, stats.hps.hps or 0, stats.ult.ultValue or 0))
    else
        -- Handle the case where no stats are available
        d(strfmt("[%s] No stats available for unitTag %s", ExampleAddon.name, unitTag))
    end
end

-- Function called when the player activates (after the loading screen)
-- Used here to delay the display of player stats until all data is ready
local function OnPlayerActivated()
    zo_callLater(function()
        DisplayUnitStats("player") -- Show the player's current stats after a 2-second delay
    end, 2000)
end

-- Function to initialize the add-on and register with the library
local function Initialize()
    -- Register the add-on with LibGroupCombatStats for DPS, HPS, and ULT tracking
    lgcs = LibGroupCombatStats.RegisterAddon(ExampleAddon.name, { "DPS", "HPS", "ULT" })
    if not lgcs then
        -- If registration fails, display an error message in the chat
        d("Failed to register ExampleAddon with LibGroupCombatStats.")
        return
    end

    d("ExampleAddon initialized and registered with LibGroupCombatStats.") -- Confirmation message

    -- Register callbacks for group DPS, HPS, and ULT updates
    lgcs:RegisterForEvent(EVENT_GROUP_DPS_UPDATE, OnGroupDPSUpdate)
    lgcs:RegisterForEvent(EVENT_GROUP_HPS_UPDATE, OnGroupHPSUpdate)
    lgcs:RegisterForEvent(EVENT_GROUP_ULT_UPDATE, OnGroupULTUpdate)

    -- Register for the EVENT_PLAYER_ACTIVATED event to display player stats after the player activates
    EVENT_MANAGER:RegisterForEvent(ExampleAddon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end


-- Main event handler for when the add-on is loaded
EVENT_MANAGER:RegisterForEvent(ExampleAddon.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ExampleAddon.name then return end -- Ensure the event is for this add-on
    EVENT_MANAGER:UnregisterForEvent(ExampleAddon.name, EVENT_ADD_ON_LOADED) -- Unregister to avoid duplicate calls

    Initialize() -- Call the initialization function
end)