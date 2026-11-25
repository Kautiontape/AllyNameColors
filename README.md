# Ally Name Colors

> **Archived in November 2026.** EllesmereUI 9.9.1 and later can color friendly nameplate names for friends, guild members, and party and raid members. Use the cog beside Name Color under Nameplates > Friendly Plates. It needs the Name Only style.
>
> EllesmereUI gives party and raid members one shared color, and it doesn't color names on health bar plates. This addon does both, but it is no longer maintained and later EllesmereUI updates may break it.

A World of Warcraft Forever addon that colors the names on friendly player nameplates by who the player is to you. The default colors are the chat colors for each group:

| Group | Default color |
|---|---|
| Party | party chat blue |
| Raid | raid chat orange |
| Friend (character or Battle.net) | whisper pink |
| Guild | guild chat green |
| Everyone else | light gray, or their class color |

A player in more than one group gets the first match in that order. You can turn each group off.

## Requirements

- The WoW Forever client (Interface 16001).
- EllesmereUI with its Nameplates module. The settings page is in EllesmereUI's options panel.
- It works with Nameplates > Friendly > Name Only on or off. With Name Only on, set Nameplates > Friendly > Name Color to **Class**. In that mode the Custom setting wraps the name in an inline color code, which overrides the color this addon sets. Ally Name Colors warns in chat once per session when it finds one. With the health bar shown, either Name Color setting works.

## Install

Put this folder in `World of Warcraft/_forever_/Interface/AddOns/` and name it exactly `AllyNameColors`. GitHub's "Download ZIP" unpacks to `AllyNameColors-main`; rename it, because WoW only loads a folder whose name matches the `.toc` file inside it.

## Use

- `/allycolors` (short form `/anc`) opens the settings page: an on/off toggle and a color for each group, and a color or class color for everyone else.
- `/anc check` prints each tracked plate's group and colors. Health bar plates are marked `(bar)`.
- `/anc reset` restores the defaults.

## How it works

It colors Blizzard's name text on each friendly plate (`UnitFrame.name`) with `SetTextColor`, and hooks the color setters so it repaints when something else changes them. It never changes the text, so EllesmereUI's Name Only text ("60 | Name", with the level in its difficulty color) stays as EllesmereUI built it.

With Name Only off, EllesmereUI hides Blizzard's plate and draws its own, with a health bar. Ally Name Colors finds those plates through EllesmereUI's global namespace (`EllesmereNameplates_NS.friendlyPlates`) and colors each plate's own name text the same way. It only recolors the name, not the bar. If a future EllesmereUI update moves those internals, this part switches itself off and Name Only mode keeps working.

## Tests

`lua5.1 tests/harness.lua AllyNameColors.lua`, run from this folder, loads the addon against stubbed WoW API functions.
