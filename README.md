# Enhanced CDM

Multi-row grid layout for World of Warcraft's Cooldown Manager aura tracker (Tracked Buffs).

Repositions the `BuffIconCooldownViewer` icons into a configurable grid — no new frames created, just smarter positioning of Blizzard's existing ones.

<!-- ![Enhanced CDM Screenshot](screenshot.png) -->

## Features

- **Multi-row grid** — Configure icons per row (1–40)
- **Growth direction** — Grid grows up or down
- **Alignment** — Left, center, or right alignment for incomplete rows
- **Layout modes** — Static (gaps preserved) or Dynamic (tightly packed)
- **Edit Mode integration** — Settings panel appears when selecting Tracked Buffs in Edit Mode
- **Combat safe** — Reflows the grid mid-fight as buffs appear or expire

## Slash Commands

| Command | Description |
|---|---|
| `/ecdm rows <1-40>` | Set icons per row |
| `/ecdm grow <up\|down>` | Set growth direction |
| `/ecdm align <left\|center\|right>` | Set row alignment |
| `/ecdm layout <static\|dynamic>` | Set layout mode |
| `/ecdm` | Print current settings |

## Requirements

- World of Warcraft: The War Within (Interface 120000+)

## License

[MIT](LICENSE)
