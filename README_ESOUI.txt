[SIZE="5"][B]LibGroupCombatStats[/B][/SIZE]

[COLOR="DarkOrange"][SIZE="4"]Overview[/SIZE][/COLOR]
[B]LibGroupCombatStats [/B]is a library designed for Elder Scrolls Online (ESO) addons to provide group combat statistics such as damage per second (DPS), healing per second (HPS), and ultimate (ULT) status updates. It enables developers to register their addons to receive combat data, broadcast statistics, and interact with group and player-specific stats.

[COLOR="DarkOrange"][SIZE="4"]Dependencies[/SIZE][/COLOR]
- [URL="https://www.esoui.com/downloads/info2528-LibCombat.html"]LibCombat[/URL] - by [URL="https://www.esoui.com/forums/member.php?action=getinfo&userid=12780"]@Solinur[/URL]
- [URL="https://www.esoui.com/downloads/info1337-LibGroupBroadcastformerlyLibGroupSocket.html"]LibGroupBroadcast[/URL] - by [URL="https://www.esoui.com/forums/member.php?action=getinfo&userid=5815"]@sirinsidiator[/URL]


[COLOR="darkorange"][SIZE="4"]Key Features[/SIZE][/COLOR]
- [B]Observable Data[/B]: Automatically tracks changes in combat stats and triggers callbacks when updates occur.
- [B]Event Broadcasting[/B]: Sends and receives periodic updates for group DPS, HPS, and ULT stats.
- [B]Custom Callbacks[/B]: Allows addons to register and unregister for library-provided events.
- [B]Efficient Encoding[/B]: Encodes and decodes combat data for network-efficient communication.
- [B]Addon Registration[/B]: Addons can register to use specific features (DPS, HPS, ULT).


[COLOR="darkorange"][SIZE="4"]For Addon Devs who want to use this Library, have a look here: [URL="https://github.com/m00nyONE/LibGroupCombatStats"]https://github.com/m00nyONE/LibGroupCombatStats[/URL][/SIZE][/COLOR]