# Ally Name Colors

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
- In EllesmereUI, set Nameplates > Friendly > Name Color to **Class**. The Custom setting wraps the name in an inline color code, which overrides the color this addon sets. Ally Name Colors warns in chat once per session when it finds one.

## Install

Put this folder in `World of Warcraft/_forever_/Interface/AddOns/` and name it exactly `AllyNameColors`. GitHub's "Download ZIP" unpacks to `AllyNameColors-main`; rename it, because WoW only loads a folder whose name matches the `.toc` file inside it.

## Use

- `/allycolors` (short form `/anc`) opens the settings page: an on/off toggle and a color for each group, and a color or class color for everyone else.
- `/anc check` prints each tracked plate's group and colors.
- `/anc reset` restores the defaults.

## How it works

It colors Blizzard's name text on each friendly plate (`UnitFrame.name`) with `SetTextColor`, and hooks the color setters so it repaints when something else changes them. It never changes the text, so EllesmereUI's Name Only text ("60 | Name", with the level in its difficulty color) stays as EllesmereUI built it.

## Tests

`lua5.1 tests/harness.lua AllyNameColors.lua`, run from this folder, loads the addon against stubbed WoW API functions.
