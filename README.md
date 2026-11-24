# Difu'sBisProRoute

[![CurseForge downloads](https://img.shields.io/curseforge/dt/1816912?label=CurseForge&color=f16436)](https://www.curseforge.com/wow/addons/difusbisproroute) [![Latest release](https://img.shields.io/github/v/release/DifusBisProRoute/difusbisproroute.github.io?label=release)](https://github.com/DifusBisProRoute/difusbisproroute.github.io/releases/latest)

Pre-raid route for **Warrior (Protection, Fury)** and **Warlock (Affliction, Demonology, Destruction)** on **WoW Forever**: a free in-game addon plus a web guide.

**Web guide:** https://difusbisproroute.github.io/
**Download:** [CurseForge](https://www.curseforge.com/wow/addons/difusbisproroute) · [GitHub releases](https://github.com/DifusBisProRoute/difusbisproroute.github.io/releases/latest)

## Features
- **Dependency-ordered route**: what to do first (keys, attunements, quests, dungeons, reputations) to get your pre-raid BiS. Mark each step as Complete, Later or Skip.
- **Up to 5 options per slot**, based on WoW Forever BiS List, wowtbc.gg and sixtyupgrades.
- **Caps optimizer**: Protection = 440 Defense + 8% hit; Fury = 8% hit + maximum EP; Warlock = 17% spell hit (with Suppression) + maximum EP. Presets: Optimal, Tank, No crafts / AH, Max Nature resistance, Max Fire resistance, plus your own.
- **Optimize current gear**: builds the best set from the items you own (equipped, bags and bank), as close as possible to 440 Defense and 8% hit.
- **Character-sheet stats panel** comparing what you have now with your plan, using your real talents.
- **WoWSims link** for your chosen set (`/difu sim`).
- **Tracks your progress automatically**: quests, items, reputation and professions.
- **English and Spanish** (`/difu lang en` · `/difu lang es`).

## Installation
1. Download the zip from [Releases](https://github.com/DifusBisProRoute/difusbisproroute.github.io/releases/latest).
2. Copy the `DifusBisProRoute` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
   The result must be `...\AddOns\DifusBisProRoute\DifusBisProRoute.toc` (no nested folders).
3. In game, type `/difu`. If it does not show up, enable "Load out of date AddOns" in the AddOns list.

## Commands
| Command | What it does |
|---|---|
| `/difu` | Open / close the window |
| `/difu spec prot` · `/difu spec fury` · `/difu spec aff` · `/difu spec demo` · `/difu spec destro` | Switch spec (the ones of your class) |
| `/difu sim` | WoWSims link for your set |
| `/difu web` | Link to the web guide |
| `/difu talents` | Show which talents the addon reads |
| `/difu export` · `/difu import` | Sync with the web guide |
| `/difu lang en` · `/difu lang es` | Language |
| `/difu scale 0.6-1.4` | Window size |
| `/difu reset` | Reset this character's progress |

## Sources and credits
[WoW Forever BiS List](https://wowforeverbislist.com/) · [wowtbc.gg](https://wowtbc.gg/warcraftforever/) · [sixtyupgrades](https://sixtyupgrades.com/forever/) · [WoWSims](https://www.wowsims.com/forever/) · [Wowhead Forever](https://www.wowhead.com/forever)

## Policy
The addon is and will stay **free**, with readable source code, no ads and no donation requests inside the game, following
[Blizzard's UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534).
If you want to support the project, see "Support the project" on the [web guide](https://difusbisproroute.github.io/).

## Support the project
The addon is free and will stay free. If it helps you, you can support it:

- ⭐ Star this repository and share the [web guide](https://difusbisproroute.github.io/).
- **PayPal:** https://paypal.me/DifuWoW
- **Binance Pay ID:** `128341418` (DifuWoW). No fee between Binance users: Pay → Send, paste the Pay ID and check the name is DifuWoW.
- **USDT (TRC20 / Tron network):** `TF6aQxhahtLNtFqEDRpeGASgn92hUDEYoo`
  Send **only USDT on the TRC20 network** to this address. Any other coin or network will be lost.

Donations are optional and never unlock anything inside the addon.

## License
© 2026 Difu (DifusBisProRoute). All rights reserved. See [LICENSE](LICENSE).
