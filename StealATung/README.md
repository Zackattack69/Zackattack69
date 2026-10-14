# Steal a Tung

A Roblox tycoon-heist game for 8 players per server. You buy Tung Tung Tung Sahur characters off a conveyor belt, put them on pads in your base to earn money, and steal rarer Tungs from other players while defending your own. Every Tung, effect and system is original. It's built from the *Steal a Tung — Game Design Doc* (Oct 14, 2026).

The core loop, every 1–5 minutes:
1. **Earn.** Tungs on your pads build up money (each pad holds at most 1 hour of its income).
2. **Buy.** Walk to the belt and hold **Buy – $X** for a quarter of a second. The Tung follows you home.
3. **Place.** Walk into your base and it hops onto a free pad. Walk up to any of your Tungs to **Pick Up** (it follows you, then **Place Here** on another pad, or swap with a Tung already there) or **Sell** it right there.
4. **Collect.** Step on or tap each pad's round Collect button.
5. **Steal and defend.** Hold **Steal** for 1.5 s on someone else's Tung and run it home. Bonk thieves with your bat, lock your laser wall, and set traps.
6. **Rebirth.** When your base is full, rebirth at the altar for a permanent multiplier, more slots, a bigger base and a perk.

## Quick start

1. Install [Rojo](https://rojo.space) 7.x and the Rojo Studio plugin.
2. From this folder (`StealATung/`), build the place:
   ```bash
   rojo build default.project.json -o StealATung.rbxl
   ```
   Or run `rojo serve` and connect from Studio for live sync.
3. Open the place in Studio and press **Play**. The server generates the whole arena, all 8 bases and the belt in code, so there's no map to build by hand.
4. To test stealing and trading, use **Test → Clients and Servers** with 2+ players. The new-player shield blocks steals for the first 10 minutes of playtime. To skip it while testing, lower `Economy.SHIELD_SECONDS`, or use `/money` and `/give` to set up a scenario.

### Studio / game settings
| Setting | Where | Value |
|---|---|---|
| Max players | Game Settings → Places → Server Fill | **8** (one base per player) |
| DataStores in Studio | Game Settings → Security → *Enable Studio Access to API Services* | On (without it, data only lasts for the session; the game still runs) |
| Avatar | Game Settings → Avatar | R15 or R6 both work |
| Chat | TextChatService (default) | Used for VIP tags, Mythic broadcasts and admin commands |

### Fill in before publishing
| What | File | Notes |
|---|---|---|
| Game Pass / Developer Product IDs | [`src/shared/Config/Products.luau`](src/shared/Config/Products.luau) | Create each item on the Creator Dashboard and paste its ID into `assetId`. Items left at `0` show *Coming soon*. |
| Roblox group for the free Group Tung | [`src/shared/Config/GameConfig.luau`](src/shared/Config/GameConfig.luau) → `GroupId` | `0` turns it off. |
| Admins | `GameConfig.Admins` | The place owner (or group owner) is always an admin. Everyone is an admin in Studio. |
| Badges (Index rewards) | `GameConfig.Badges` | One per rarity tab, plus *TungMaster*. |
| Main theme | 👑 Admin → **Music** (or `GameConfig.MusicId`) | Upload `Bills_Keep_Rolling.mp3` in Studio (Window → Asset Manager → Import), right-click it → *Copy Asset ID*, and paste it in the Admin panel's Music tab. It's saved in a DataStore for every server, so new versions of the place file keep it. The song only plays once Roblox approves it, in a place published by the account that uploaded it. |
| Event music | `GameConfig.EventMusic` | Optional song per event. Leave one empty and the main theme is re-mixed to fit that event instead. |
| Admin code | [`src/server/AdminConfig.luau`](src/server/AdminConfig.luau) | Code for the in-game ADMIN panel (server-only, so players can't read it). |
| Sounds | [`src/shared/Config/Sounds.luau`](src/shared/Config/Sounds.luau) | Soft cues using sounds bundled with the Roblox client, plus the classic Roblox cash-register *cha-ching* (`rbxassetid://7112275565`) for collecting. If that ID ever stops loading, it falls back to a built-in ping. Swap in your uploads. |

## What's in the game (Design Doc → implementation)

| Design Doc section | Implementation |
|---|---|
| **Lobby, map & server** | A big arena (about 300 × 450 studs) boxed in by tall grey walls, about 10 Roblox characters high. It has a striped grass floor, blue sky, drifting cartoon clouds, and lanterns and flowers along the middle. The belt runs down the middle from one end wall to the other, with 4 bases on each side facing it, spread 104 studs apart. The owner's name floats above each base's roof. You spawn in your own base. A leaderboard pillar straddles the belt in the middle, with shop and sell stands on either side. There's a 20-minute day/night cycle: stars, glowing lanterns, auras twice as bright at night, butterflies by day and fireflies by night. |
| **Conveyor belt & buying** | A big drum machine by one end wall spits out a Tung every 3 s. Each one rides the full-length belt for 40 s (about 10 studs/s) and then drops into the hole by the other end wall. Small, clear nameplates show name, rarity, price and $/s. Hold *Buy – $X* for 0.25 s. The prompt greys out with *Base full* / *Need $X*. Spawn odds are exactly the doc's (55 / 25 / 12 / 5 / 2.2 / 0.6 / 0.2 %). **Hype:** Legendary+ shakes the drum and shows a small banner with a soft fanfare. Secret also darkens the sky for 5 s and puts a spotlight on the Tung. Mythic also ducks the music, floods the arena with its colour and sends a cross-server chat message (MessagingService). |
| **Tung roster** | All 22 Tungs with their outfits and signature effects (bat taps, Zzz bubbles, squeaky Mini Tung, bouncing hat, falling leaves, drum beat, bubblegum pops, icy breath, ninja fade, disco ball, lava drips, robo laser scan, sand swirls, royal fanfare, galaxy stars, coin bursts, shadow smoke, glitch teleports, moon halo, water ripples, orbiting runes + lightning, Mythic Red bat-bang shock rings). Rarity auras follow the doc's table. Mythics carry a 1/2/3 🔥 sub-tier badge (70 / 25 / 5 %). |
| **Mutations** | Gold 3% ×2, Diamond 1% ×3, Rainbow 0.3% ×5 (colour cycling) and Cursed 0.1% ×8 (red eyes, creepy laugh). A mutation multiplies both income and price. |
| **Base, slots, collect** | Each base is a **closed box building** (54 × 70 studs: walls, framed window bands, a roof) and its **whole ground-floor front is a laser wall**, the only way in or out. When locked, red laser bars block everyone except the owner (collision groups). Thieves have to be inside to steal. It has up to **4 floors**. Every floor holds **8 Tungs: 4 along the left wall and 4 along the right wall**, facing the middle aisle. Stairs run along the inside of the back wall, and the Rebirth Altar sits at the back in the middle of the ground floor with the **Skins stand** next to it. Lock / shield time shows above the lasers. The camera fades walls that get in the way (Invisicam). **Your own Tungs:** *Pick Up* (it follows you; it earns nothing and can't be stolen while off its pad, and hops home after 60 s outside the base or if you respawn), *Place Here* on any pad (swaps if the pad is taken) and *Sell* right from the pad. You start with 1 floor (8 slots), and rebirths add slots, which add floors (10 slots = 2 floors … 31 = 4 floors). Pads glow; empty ones show a ghost Tung and a "+". The floating counter shows money waiting. The round Collect button is in the rarity colour: step on it or tap it, and coins fly into you with the classic Roblox cha-ching and a "+$X" pop. Each pad caps at 1 hour of income. **Collect All** unlocks at Rebirth 1 or with the pass. |
| **Stealing** | Hold *Steal* (1.5 s) and the Tung goes over your head. You walk 30% slower with a red outline everyone can see. Reach your own base and it's yours. If you get bonked or trapped, you drop it and it walks back home. The owner gets a siren and *"Someone is stealing your King Tung!"* |
| **Base skins** | Rebirths never change your base's look. At the Skins stand you pick a skin: 11 free colours (Classic, Red, Yellow with cat ears, Blue, Green, Purple, Pink, Orange, White, Black, Candy Cane), a style for each rarity that unlocks when you've collected enough Tungs of it (Common 25, Uncommon 15, Rare 10, Epic 6, Legendary 3, Secret 1, Mythic 1; trades don't count), and the Tung Master temple for a full Index. Defined in [`Config/BaseSkins.luau`](src/shared/Config/BaseSkins.luau). |
| **Defence** | Laser-wall base lock for 60 s (90 s at Rebirth 3) with a 2-minute cooldown. Every player has a bat (bonk = drop + knockback; better bats in the shop). Traps: banana peel (slip + drop), sticky honey (−60% speed) and Tung alarm (siren + alert). The new-player shield protects your first 10 minutes. |
| **Rebirth** | A glowing altar at the back of every base opens the lose (red) vs gain (green) screen, with a confirm tap. The cinematic: white flash, Tungs fly into the sky, fireworks, and the base rebuilds with more room (new floors) in the same skin. The full rebirth table and all 6 perks are in, including the Rebirth 5 trail and the Rebirth 6 personal belt. |
| **Index** | A wooden-book collection with All / per-rarity / Mutations tabs. Found Tungs are animated 3D cards with the date first found. Missing ones are black silhouettes with "???", and Mythics get a flame-outlined "?". Progress bar: "14 / 22 Tungs found (64%)". **Rewards:** each completed rarity tab gives +5% money forever plus a badge, each complete mutation set unlocks that avatar aura, and 100% gives the *Tung Master* title and the Tung Master base skin. |
| **Art style** | Bright toy-plastic Roblox look in the spirit of Steal a Brainrot / Steal an Egg. Every builder runs materials through [`src/shared/Style.luau`](src/shared/Style.luau), so wood, stone and fabric become smooth plastic, while neon and glass stay for glows. You get a striped plastic lawn, tall grey arena walls, puffy cartoon clouds, a big red conveyor, a candy drum machine with chasing bulbs, checkerboard base floors with neon trims, and cartoon Tungs, each with its own face (shouting, winking, sleepy, derpy, angry, star-eyed, monocle and mustache, fangs…; see [`TungFace.luau`](src/shared/TungFace.luau)). Nameplates are small with solid rarity colours and float just above each Tung's head (hats included); only Secret (and the Rainbow mutation) keep a rainbow shimmer. |
| **UI/UX** | Candy UI: 3D gradient buttons with a dark lip and a shine that sweeps across them, thick dark outlines, Luckiest Guy titles and Fredoka One text, striped animated window headers with icon bubbles, rotating light rays behind banners and rare Index cards, twinkling sparkles, and "PURCHASED!" / "STOLEN!" pops. Rarity colours are the accents. Buttons squash to 0.9 and bounce to 1.05 → 1.0, menus slide in from the side in 0.25 s, numbers count up, every tap pops and menus whoosh. The HUD has money + income/s at the very top centre (it shakes and glows when money rises), event / luck / boost chips stacked against the right edge, the rebirth badge at top right, round menu buttons on the left, and Lock Base with a circular cooldown at bottom right. Compact banners slide down under the money counter and leave after 2.6 s. Everything is drawn at 86% of the design size (`Lib.UI_SCALE`). On mobile, Buy and Steal prompts become big tappable on-screen buttons, nothing important sits in the thumb corners, and buttons are at least 60 px. |
| **Settings** | Music volume, SFX volume, low graphics mode (auras/effects off, cheaper lighting) and *hide other players' auras*. Saved to your data. |
| **Events** | A random event every 15 minutes, lasting 3. The music changes to fit each one (its own song from `GameConfig.EventMusic`, or the main theme re-mixed: dreamy for Sahur Hour, light for Tung Rain, shiny for Golden Belt, faster for Speed Belt, slow and muffled for Thief Night, loud and bassy for Admin Abuse). Sahur Hour (purple sky, Secret/Mythic ×3), Tung Rain (free Tungs fall from the sky), Golden Belt, Speed Belt and Thief Night (0.75 s steals, locks off). Admin Abuse runs weekly on a schedule (Saturday 18:00 UTC, set in `Events.ADMIN_ABUSE`), and admins can start it any time. |
| **Social & retention** | 7-day login streak (day 7 = free Legendary), 3 daily quests, trading (friends-only; both sides accept, then both confirm), server and global leaderboards (earners, thieves, highest rebirth), friend boost (+10% per friend, max +30%) and the group reward Tung. |
| **Monetization** | Passes: 2x Money, VIP (chat tag, gold name, +1 slot, VIP Tung), Collect All, Auto Lock, Lucky Belt. Products: Server Luck Potion (3x for everyone for 10 min; chat thanks the buyer), Instant Tung, Skip Rebirth Cost. Nothing sold lets you steal without risk, and Mythics are never directly buyable. |
| **Must-not-break rules** | All money, buying, stealing and rebirth logic runs on the server through one validated `Request` dispatcher. Data saves every 60 s and when you leave, with a DataStore session lock. Low graphics mode is aimed at 60 FPS on mid-range phones. |

### Admin panel (owner / admins only)
Admins (you as the place owner, anyone in `GameConfig.Admins`, and everyone while testing in Studio) see a red **👑 Admin** button on the left of the HUD. Enter the admin code (default `goldklumpen`, set in `src/server/AdminConfig.luau`) to unlock it:
- **Money:** give yourself any amount. Type `5000`, `2.5M`, `10B` or `1e15`, or tap a quick amount.
- **Tungs:** spawn any Tung with any mutation, either into your base or onto the belt.
- **Events:** start any server event or Admin Abuse, or stop them.

The server checks both that you're an admin and the code, so other players can't use the panel even if they learn the code.

### Admin commands (chat)
`/spawn <tung> [mutation]` · `/give <tung> [mutation]` · `/event <SahurHour|TungRain|GoldenBelt|SpeedBelt|ThiefNight|stop>` · `/adminabuse [minutes|stop]` · `/luck <mult> [minutes]` · `/money <amount>` · `/help`

Tung names are matched loosely, so `/spawn mythic red gold` works.

### Design decisions where the doc left room
- **Luck on a shared belt:** the main belt uses the *best* personal luck in the server (Rebirth 4, Lucky Belt, Luck Potions) times server-wide luck. Your own luck applies fully to your Rebirth 6 personal belt.
- **Instant Tung** puts a Legendary on the belt that only the buyer can grab, and it's free to grab.
- **VIP Tung and Group Tung** are *bound*: they can't be stolen, traded or sold, and they're kept through rebirths.
- **Full base:** gifts (daily Legendary, Group/VIP Tung, Tung Rain) wait in a queue and drop into the next free slot. You can't buy or steal with a full base.
- **Slots** stop at 30 from rebirths (31 with VIP), so bases fit in the arena. The multiplier and cost keep scaling.
- **Thieves** get an 8 s cooldown after each steal attempt. A stolen Tung's waiting pad money is lost.
- **Trading** is friends-only as written, except in Studio so you can test it with local players.

## Project layout
```
StealATung/
  default.project.json
  src/
    shared/                  → ReplicatedStorage.Shared
      Config/
        Rarities, Tungs, Mutations   roster, odds, colours (add new Tungs in Tungs.luau)
        Economy                      rebirth table, multipliers, luck, steal/lock timings
        Items, Quests, Events        shop items & bats, daily quests + login, server events
        Products, GameConfig         Robux items, group/admins/badges/music
        Layout                       arena & base geometry (shared by server and client)
        BaseSkins                    base colours / rarity styles and how they unlock
        Sounds
      TungModel.luau         builds any Tung (log, face, bat, outfit, aura, mutation skin)
      TungFace.luau          every Tung's expression (eyes, brows, nose, mouth, extras)
      Remotes.luau
    server/                  → ServerScriptService.Server
      Main.server.luau       boot + the single validated request dispatcher
      ArenaBuilder.luau      arena, belt, drum, hole, pillar, stands, lighting
      BaseBuilder.luau       closed multi-floor themed bases: walls, windows, roof, pads, buttons, stairs, altar, lasers, traps
      AdminConfig.luau       server-only admin panel code
      Services/              Data, Economy, Player, Base, Steal, Belt, Event,
                             Shop (Robux), Trade, Leaderboard, Admin
    client/                  → StarterPlayerScripts.Client
      Main.client.luau
      State, Belt, PromptUI, WorldFx, Music
      UI/                    Lib (UI kit), HUD, Effects, Index/Shop/Rebirth/
                             Settings/Quests/Trade/Sell panels
```

### Security model
The client never sends amounts, prices or odds. Each action is a named request that the server re-validates: distance to the belt Tung, money, free slots, base lock and shield, hold time on steal prompts, cooldowns, and trade contents at the moment of the swap. Requests are limited to one state-changing action at a time per player, and 30 per second.

## Status and next steps
This was written outside Roblox Studio. It passes `luau-lsp` strict type-checking against the Roblox API, builds with Rojo 7.4, and the spawn/mutation odds, rebirth table and schedules were checked with the standalone Luau runtime. It has **not been play-tested in Studio yet**, so expect some tuning on the first run.
- Play-test pacing (belt prices vs. income, rebirth costs, quest goals) and tweak `Economy.luau`.
- Swap the procedural greybox art for hand-built models. Gameplay only relies on the part names listed at the top of `ArenaBuilder.luau` and `BaseBuilder.luau`.
- Upload the theme (and any event songs) and put their IDs in `GameConfig.MusicId` / `GameConfig.EventMusic`.
- Add 1–2 new Tungs every update in `Tungs.luau`. The belt, Index and nameplates pick them up automatically.
