# Changelog

## 1.0.4
- Talents are now read correctly on the WoW Forever client, which uses the trait system (C_ClassTalents / C_Traits). Stats, the Defense cap and Fury crit use your real ranks instead of the defaults.
- Talents are matched by spell ID (Anticipation, Deflection, Shield Specialization, Cruelty), so it works in any client language.
- Toughness is no longer assumed: it does not exist in the Forever Warrior tree.
- Talent changes are picked up right away (TRAIT_CONFIG_UPDATED).
- `/difu talents` prints a short summary; full diagnostics only when nothing can be read.

## 1.0.3
- Gear is now the first tab, Route the second; bigger tab buttons with icons. The last tab used is remembered.
- Character sheet: each slot label shows the slot, the item name in its quality colour, its EP and a check mark when you own it.
- Route: step descriptions only mention the items you chose for the current spec (no Protection items in the Fury route).

## 1.0.2
- Link to the web guide: `## X-Website` in the .toc, new `/difu web` command and a discreet line in the Sync box.
- Readme files in English.

## 1.0.1
- `/difu talents` no longer throws an API error: talent reading works across client versions and prints diagnostics in chat.

## 1.0.0
- First public release: Warrior Protection and Fury, dependency-ordered route, up to 5 options per slot, caps optimizer (440 Def + 8% hit / 8% hit + EP), presets, stats panel, WoWSims link and sync with the web guide.
