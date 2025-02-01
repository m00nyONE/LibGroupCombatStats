# LibGroupCombatStats Documentation

## Overview
**LibGroupCombatStats** is a library designed for Elder Scrolls Online (ESO) addons to provide group combat statistics such as damage per second (DPS), healing per second (HPS), and ultimate (ULT) status updates. It enables developers to register their addons to receive combat data, broadcast statistics, and interact with group and player-specific stats.

## Dependencies
- LibCombat - by @Solinur
- LibGroupBroadcast ( under development ) - by @sirinsidiator

## Key Features
- **Observable Data**: Automatically tracks changes in combat stats and triggers callbacks when updates occur.
- **Event Broadcasting**: Sends and receives periodic updates for group DPS, HPS, and ULT stats.
- **Custom Callbacks**: Allows addons to register and unregister for library-provided events.
- **Efficient Encoding**: Encodes and decodes combat data for network-efficient communication.
- **Addon Registration**: Addons can register to use specific features (DPS, HPS, ULT).

---

## Getting Started
To use the library in your addon, you need to:
1. Register your addon with the library.
2. Use events to receive updates or API functions to query specific data.

---

## Registering an Addon
To register your addon, call:
```lua
local combatStats = LibGroupCombatStats

local lgcs = combatStats.RegisterAddon("MyAddonName", {"DPS", "HPS", "ULT"})
if not myAddon then
  d("Failed to register addon with LibGroupCombatStats.")
  return
end
```
- **addonName**: A unique name for your addon.
- **neededStats**: A list of stats your addon requires. Options are:
    - `"ULT"`: For ultimate stats.
    - `"DPS"`: For damage per second stats.
    - `"HPS"`: For healing per second stats.

The function returns a `_CombatStatsObject` object that provides API calls and event registration for your addon.

Example:
```lua
local lgcs = LibGroupCombatStats.RegisterAddon("MyCombatAddon", {"DPS", "ULT"})
```

---

## Events
All events have two parameters for their callback functions `unitTag` and `data`. This includes all events based on the local player.

You can register callbacks to listen for specific events using:
```lua
lgcs:RegisterForEvent(EVENT_NAME, callback)
```
The following events are available:

### Group Events
| Event Name                          | Description                                       |
|-------------------------------------|---------------------------------------------------|
| `LibGroupCombatStats.EVENT_GROUP_DPS_UPDATE` | Triggered when group DPS stats are updated.       |
| `LibGroupCombatStats.EVENT_GROUP_HPS_UPDATE` | Triggered when group HPS stats are updated.       |
| `LibGroupCombatStats.EVENT_GROUP_ULT_UPDATE` | Triggered when group ultimate stats are updated.  |

### Player Events
| Event Name                          | Description                                     |
|-------------------------------------|-------------------------------------------------|
| `LibGroupCombatStats.EVENT_PLAYER_DPS_UPDATE` | Triggered when player DPS stats are updated.    |
| `LibGroupCombatStats.EVENT_PLAYER_HPS_UPDATE` | Triggered when player HPS stats are updated.    |
| `LibGroupCombatStats.EVENT_PLAYER_ULT_UPDATE` | Triggered when player ultimate stats are updated.|

### Mostly not needed Events ( internal )
| Event Name                                                     | Description                                                          |
|----------------------------------------------------------------|----------------------------------------------------------------------|
| `LibGroupCombatStats.EVENT_PLAYER_ULT_VALUE_UPDATE`            | Triggered when player ultimate value is updated.                     |
| `LibGroupCombatStats.EVENT_PLAYER_ULT_TYPE_UPDATE`             | Triggered when player ultimate type is updated.                      |


Example:
```lua
local function myCallbackFunction(unitTag, data)
  d("Group DPS updated for: " .. unitTag)
  d(data.dps)
end

lgcs:RegisterForEvent(LibGroupCombatStats.EVENT_GROUP_DPS_UPDATE, myCallbackFunction)
```

You can also unregister your event's again using:

```lua
lgcs:RegisterForEvent(EVENT_NAME, callback)
```

Example:
```lua
lgcs:UnregisterForEvent(LibGroupCombatStats.EVENT_GROUP_DPS_UPDATE, myCallbackFunction)
```
---
#### Event data structure:
```lua
ultData = {
  ultValue = number, -- ultimate points ( 0-500 )
  ult1ID = number, -- frontbar ultimate skill ID
  ult2ID = number, -- backbar ultimate skill ID
  ult1Cost = number, -- frontbar ultimate cost
  ult2Cost = number, -- backbar ultimate cost
  ultActivatedSetId = number, -- the id of a set that is activated with an ultimate ( see LibGroupCombatStats.ULT_ACTIVATED_SETS_LIST )
  _lastUpdated = number, -- timestamp of last update
}

dpsData = {
  dmgType = number, -- (0-3) LibGroupCombatStats.DAMAGE_UNKNOWN / LibGroupCombatStats.DAMAGE_TOTAL / LibGroupCombatStats.DAMAGE_BOSS
  dmg = number, -- (0-999) overall damage in Millions when dmgType = DAMAGE_TOTAL / overall dps when dmgType = DAMAGE_BOSS
  dps = number, -- (0-9999 -- 0k-999.9k) overall dps in Thousands when dmgType = DAMAGE_TOTAL / boss singletarget dps when dmgType = DAMAGE_BOSS  
  _lastUpdated = number, -- timestamp of last update
}

hpsData = {
  overheal = number, -- (0-999 -- 0k-999k) overheal/raw hps 
  hps = number, -- (0-999 -- 0-999k) real hps
}
```


---

## API Functions
The following API functions are available through the `lgcs` object:

### `lgcs:Iterate() / pairs(lgcs)`
It is possible to iterate over the internal groupStats table with `pairs(lgcs)` or `lgcs:Iterate()`.

Returns:
`iterator`

Example:
```lua
for unitTag, stats in lgcs:Iterate() do
  d(unitTag)
  d(stats)
end

for unitTag, stats in pairs(lgcs) do
  d(unitTag)
  d(stats)
end 
```


### `lgcs:GetGroupStats()`
Retrieves all group stats as a table.

#### Returns:
A table with the following structure:
```lua
{
    ["unitTag"] = {
        tag = "unitTag",
        name = "characterName",
        displayName = "accountName",
        isPlayer = true/false,
        ult = {
            ultValue = number,
            ult1ID = number,
            ult1Needed = number,
            ult2ID = number,
            ult2Needed = number,
            ultActivatedSetId = number,
            _lastUpdated = timestamp,
        },
        dps = {
            dmgType = number, -- 0 (Unknown), 1 (Total), 2 (Boss)
            dmg = number,
            dps = number,
            _lastUpdated = timestamp,
        },
        hps = {
            overheal = number,
            hps = number,
            _lastUpdated = timestamp,
        },
    },
    ...
}
```

Example:
```lua
local groupStats = lgcs:GetGroupStats()
for tag, stats in pairs(groupStats) do
    d("Stats for: " .. stats.name)
    d(stats.dps.dps)
end
```

---

### `lgcs:GetGroupSize() / #lgcs`
Retrieves the number of group members with available stats.

#### Returns:
- **number**: The number of group members.

Example:
```lua
local groupSize = lgcs:GetGroupSize()
d("Group size: " .. groupSize)

local groupSizeViaMetatableMethod = #lgcs
d("Group size: " .. groupSizeViaMetatableMethod)
```

---

### `lgcs:Iterate()`
Iterates over all group members.

#### Returns:
An iterator for key-value pairs where the key is the `unitTag` and the value is the stats table.

Example:
```lua
for tag, stats in lgcs:Iterate() do
    d("Stats for: " .. stats.name .. " - DPS: " .. stats.dps.dps)
end
```

---

### `lgcs:GetStatsShared()`
Retrieves a list of functionalities currently enabled in the library.

#### Returns:
A table:
```lua
{
    ["ULT"] = true/false,
    ["DPS"] = true/false,
    ["HPS"] = true/false,
}
```

Example:
```lua
local enabledStats = lgcs:GetStatsShared()
if enabledStats["ULT"] then
    d("Ultimate tracking is enabled")
end
```

---

### `lgcs:GetUnitStats(unitTag)`
Retrieves stats for a specific unit.

#### Parameters:
- **unitTag**: The unit tag of the group member (e.g., `"group1"`).

#### Returns:
A stats table with the same structure as described in `GetGroupStats()`.

Example:
```lua
local stats = lgcs:GetUnitStats("group1")
if stats then
    d("DPS for " .. stats.name .. ": " .. stats.dps.dps)
end
```

---

### `lgcs:GetUnitDPS(unitTag)`
Retrieves DPS information for a specific unit.

#### Parameters:
- **unitTag**: The unit tag of the group member (e.g., `"group1"`).

#### Returns:
- **number**: Damage type (`0` for Unknown, `1` for Total, `2` for Boss).
- **number**: Total damage.
- **number**: DPS value.
- **number**: Timestamp of the last update.

Example:
```lua
local dmgType, dmg, dps, _lastUpdated = lgcs:GetUnitDPS("group1")
d("DPS: " .. dps .. " Damage: " .. dmg)
```

---

### `lgcs:GetUnitHPS(unitTag)`
Retrieves HPS information for a specific unit.

#### Parameters:
- **unitTag**: The unit tag of the group member (e.g., `"group1"`).

#### Returns:
- **number**: Overheal value.
- **number**: HPS value.
- **number**: Timestamp of the last update.

Example:
```lua
local overheal, hps, _lastUpdated = lgcs:GetUnitHPS("group1")
d("HPS: " .. hps .. " Overheal: " .. overheal)
```

---

### `lgcs:GetUnitULT(unitTag)`
Retrieves ultimate information for a specific unit.

#### Parameters:
- **unitTag**: The unit tag of the group member (e.g., `"group1"`).

#### Returns:
- **number**: Current ultimate value.
- **number**: Ultimate 1 ID.
- **number**: Ultimate 1 cost.
- **number**: Ultimate 2 ID.
- **number**: Ultimate 2 cost.
- **number**: Ultimate activated set ID. -- see `LibGroupCombatStats.ULT_ACTIVATED_SET_LIST` for more info
- **number**: Timestamp of the last update.

Example:
```lua
local ultValue, ult1ID, ult1Cost, ult2ID, ult2Cost, setId, _lastUpdated = lgcs:GetUnitULT("group1")
d("Ultimate value: " .. ultValue)
```

---

## Constants

The setID can be checked by looping over `LibGroupCombatStats.ULT_ACTIVATED_SET_LIST` which looks like this:
```lua
LibGroupCombatStats.ULT_ACTIVATED_SET_LIST = {
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
}
```
The dmgType can be checked with the following constants:
```lua
LibGroupCombatStats.DAMAGE_UNKNOWN = 0
LibGroupCombatStats.DAMAGE_TOTAL = 1
LibGroupCombatStats.DAMAGE_BOSS = 2

```

---

## Example Workflow
Below is an example workflow for using LibGroupCombatStats:

```lua
local lgcs = LibGroupCombatStats.RegisterAddon("MyAddon", {"DPS", "ULT"})

-- Register for group DPS updates
lgcs:RegisterForEvent(LibGroupCombatStats.EVENT_GROUP_DPS_UPDATE, function(unitTag, data)
    d("Group DPS updated: " .. data.dps)
end)

-- Get stats for a specific unit
local stats = lgcs:GetUnitStats("group1")
if stats then
    d("DPS for " .. stats.name .. ": " .. stats.dps.dps)
end

-- Iterate over all group members
for tag, stats in lgcs:Iterate() do
    d("Stats for: " .. stats.name .. ", DPS: " .. stats.dps.dps)
end
```

---

## Notes
- Ensure your addon checks for the existence of `LibGroupCombatStats` before calling any functions.
- Use the `/libGroupCombatStats version` command in-game to check the library version.

---

## Contributing
If you encounter issues or have suggestions, feel free to contribute to the library by submitting pull requests or reporting issues.