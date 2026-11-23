# Changelog

## 1.0.8
- New **Optimize** tab ("Optimize current gear"): reads what you have equipped, in your bags and in the bank (open the bank once so it is remembered) and builds the best set from it: as close as possible to 440 Defense and 8% hit (Fury: 8% hit), then the most EP. It marks which slots to swap and where each item is.
- Fix: choosing an item in an ignored slot (right-click) kept the slot ignored, so the stats did not change. Picking an item now turns the slot back on, in the addon and on the web guide.
- Ignored slots now say "IGNORED (stats not counted)" on the character sheet, and the hover preview counts them.

## 1.0.7
- New Protection preset **Balanced (no Defense cap)**, imported from a WoWSims build: Lionheart Helm, Valiant's Waistguard, Handcrafted Mastersmith Leggings, Furbolg Berserker's Boots, Heroism pieces, Ironfoe and The Immovable Object. About 368 Defense and 8.3% hit: more threat and damage, for when you are not the main tank.

## 1.0.6
- Resistance presets are now strictly pre-raid: no items crafted from the new raid's recipes (Hyjal artisan tier, such as Sabatons of Glory and Grovekeeper Spaulders), no raid reputations (The Watchers), no raid quests (Ocean's Breeze needs Molten Core) and no recipes missing from Forever (Sandstalker).
- Max Nature resistance: 128 · Max Fire resistance: 128, both with 440 Defense and 6-8% hit (+15 with the cloak enchant).

## 1.0.5
- Gear data updated with the latest WoW Forever BiS List and wowtbc.gg lists (21 Nov 2026): new picks such as Legguards of Heroism, Ironfoe and Draconian Deflector (Protection), Flurry Axe and Dragon's Call (Fury).
- Protection EP uses the new WFB tank weights (agility, dodge, parry, block value and armor are worth more).
- New Protection presets: **Max Nature resistance** and **Max Fire resistance**. Both keep 440 Defense and 6-8% hit, then pick the gear with the most resistance.
- Stats panel shows Nature and Fire resistance.
- New route steps: Zul'Farrak, Sunken Temple, The Watchers and Everlook reputations, Drakefire Amulet and other resistance-gear sources.

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
