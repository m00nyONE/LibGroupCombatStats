## 2025.08.16
- add SkillLine sharing as an option
- fix a bug where the ult get sent if requested even though the local player has no addon using it

## 2025.07.24
- fix a potential bug that can occur when relogging with a different char

## 2025.05.05
- fix a race condition that could occur when leaving or entering an instance. Thanks to everyone reporting this :-)
- merge optimizations by @DakJaniels

## 2025.04.16
- dump LibCombat dependency up to 81

## 2025.04.13
- fix an issue when the player has an ult equipped that has no internal ID thanks to @DakJaniels
- fix undefined global variables found by @DakJaniels

## 2025.04.09
- update documentation
- use new .addon file instead of the old .txt

## 2025.04.06
- fix issue with not changing unitTags
- reformatting code structure
- fire player events on group update

## 2025.03.12
- dump dependencies:
  - LibCombat>=79
  - LibGroupBroadcast>=88
- merging https://github.com/m00nyONE/LibGroupCombatStats/pull/1 from @M0RGaming fixing an issue with the newest LibCombat api change in version 79
- merging https://github.com/m00nyONE/LibGroupCombatStats/pull/2 from @Treuce adding sanity checks for LibCombat to avoid these issues in the future
- api refinement
- add LGB description for Addon menu
- add HasUnitUltimatesSlotted(unitTag, listOfAbilityIDs) api function

## 2025.03.06
- include syncRequest after reloadui
- remove unneeded dependencies
- add /lgcs test
- code cleanup

## 2025.02.10
- finalize LGB Protocol

## 2025.02.09
- update to new LGB API
- compress ultIDs, ultCost more
- all communication is now async
- performance improvements
- adding _lastUpdated & _lastChanged fields

## 2025.01.27
- performance improvements
- only register updates when stats are requested by an addon
- update ult cost periodically to account for some situations where a debuff affects the ult cost of a player ( ex. Cloudrest excecute )

## 2025.01.23
- first draft of the library. Still missing LibGroupBroadcast connection