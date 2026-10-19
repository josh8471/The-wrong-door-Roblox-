# The Wrong Door

Multiplayer Roblox comedy-survival game: vote for a door, survive the room behind it, clear four rooms per run. Full spec: [The_Wrong_Door_Brainrot_PRD.md](The_Wrong_Door_Brainrot_PRD.md).

## Status

- [x] **Phase 1 — Foundation:** lobby, server game-state loop, round HUD, placeholder room
- [x] **Phase 2 — Door voting:** tap/click cards, live counts, server-checked votes, tie and no-vote handling
- [x] **Phase 3 — First room:** Angry Grandma chase, shared room lifecycle, server-checked results, coins (not saved yet)
- [x] **Phase 4 — Reusable rooms:** Giant Chicken, Reverse Gravity, harder Angry Grandma, elimination, spectating, run bonus
- [x] **Phase 5 — Progression:** saving (coins, stats, cosmetics), results card, coin shop with trails/titles/victory bursts
- [ ] Phase 6 — Polish and testing
- [ ] Phase 7 — Public testing

## How to run

1. Open `The Wrong door Roblux.rbxl` in Roblox Studio. The place file holds the lobby and room builds; the code also lives in `src/`.
2. Press **Play** (F5). A run starts after the 15-second intermission.
3. To test several players: **Test** tab → **Clients and Servers** → pick 2+ players → **Start**.
4. To test one room over and over: select `ServerStorage.RoomTemplates`, add a string attribute `ForceRoom` (e.g. `GiantChicken`), and press Play. Delete the attribute afterwards.

## Turning on saving

Roblox only allows DataStores in a **published** game. Until then the game runs in test mode: everything works, but the HUD says *"Progress isn't being saved (test mode)"* and nothing persists.

1. **File → Publish to Roblox** (create a new experience; keep it private while testing).
2. **Home → Game Settings → Security → Enable Studio Access to API Services → Save.**
3. Press Play. The red notice disappears. Studio sessions save to a separate `PlayerData_Studio` store; live servers use `PlayerData`, so testing never touches real players' progress.

## Where things live

| In Studio | On disk | What it does |
|---|---|---|
| `ReplicatedStorage.Shared.GameConfig` | `src/shared/GameConfig.luau` | Tuning numbers (timers, rooms per run, rewards) and state names |
| `ReplicatedStorage.Shared.RoomDefinitions` | `src/shared/RoomDefinitions.luau` | Each room's name, objective, time limit and difficulty per door risk |
| `ReplicatedStorage.Shared.PathFollower` | `src/shared/PathFollower.luau` | Path math shared by server (catch checks) and client (drawing chasers) |
| `ReplicatedStorage.Shared.Cosmetics` | `src/shared/Cosmetics.luau` | Shop catalog: every cosmetic, its slot, price and colors |
| `ServerScriptService.Server.Main` | `src/server/Main.server.luau` | Starts the server |
| `ServerScriptService.Server.GameManager` | `src/server/GameManager.luau` | Round loop and state machine |
| `ServerScriptService.Server.DoorVoting` | `src/server/DoorVoting.luau` | Door offers, vote checks, counting, winner pick |
| `ServerScriptService.Server.RoomManager` | `src/server/RoomManager.luau` | Loads/runs/unloads rooms, owns the timer and each player's result |
| `ServerScriptService.Server.Rooms.AngryGrandma` | `src/server/Rooms/AngryGrandma.luau` | Grandma chase: speeds up, throws slippers, mirrored layout |
| `ServerScriptService.Server.Rooms.GiantChicken` | `src/server/Rooms/GiantChicken.luau` | Key hunt; chicken patrols, aims, charges, rests |
| `ServerScriptService.Server.Rooms.ReverseGravity` | `src/server/Rooms/ReverseGravity.luau` | Blue/orange layers swap floor and ceiling on a timer |
| `ServerScriptService.Server.RewardManager` | `src/server/RewardManager.luau` | Pays coins through DataManager, each reward at most once |
| `ServerScriptService.Server.DataManager` | `src/server/DataManager.luau` | Loads/saves progress with session locking; mirrors it to leaderstats + attributes |
| `ServerScriptService.Server.ProfileSchema` | `src/server/ProfileSchema.luau` | Saved-data shape, version, and repair of old/broken saves |
| `ServerScriptService.Server.ShopManager` | `src/server/ShopManager.luau` | Checks every buy/equip request |
| `ServerScriptService.Server.CosmeticEffects` | `src/server/CosmeticEffects.luau` | Puts trails/titles on characters; plays victory bursts |
| `ServerScriptService.Server.PlayerEffects` | `src/server/PlayerEffects.luau` | Temporary slows (e.g. slipper BONK), always undone at room end |
| `ServerScriptService.Server.Teleport` | `src/server/Teleport.luau` | Moves a player onto a pad |
| `StarterPlayer.StarterPlayerScripts.Client.Main` | `src/client/Main.client.luau` | Starts the client |
| `StarterPlayer.StarterPlayerScripts.Client.UIController` | `src/client/UIController.luau` | Round HUD, room status line, center banner |
| `StarterPlayer.StarterPlayerScripts.Client.VotingUI` | `src/client/VotingUI.luau` | Door voting cards |
| `StarterPlayer.StarterPlayerScripts.Client.SpectateController` | `src/client/SpectateController.luau` | Knocked-out players watch survivors (arrows to switch) |
| `StarterPlayer.StarterPlayerScripts.Client.ChaserRenderer` | `src/client/ChaserRenderer.luau` | Draws Grandma (path math) and the chicken (smoothed server position) |
| `StarterPlayer.StarterPlayerScripts.Client.ProjectileRenderer` | `src/client/ProjectileRenderer.luau` | Flies slippers along their arc |
| `StarterPlayer.StarterPlayerScripts.Client.ScreenEffects` | `src/client/ScreenEffects.luau` | Flash + camera roll when gravity flips |
| `StarterPlayer.StarterPlayerScripts.Client.ShopUI` | `src/client/ShopUI.luau` | Shop window, SHOP button, purchase confirmation |
| `StarterPlayer.StarterPlayerScripts.Client.ResultsUI` | `src/client/ResultsUI.luau` | End-of-run results card |
| `Workspace.Lobby` | place file only | Lobby, doors, signs, spawn |
| `ServerStorage.RoomTemplates.*` | place file only | `AngryGrandma`, `GiantChicken`, `ReverseGravity` room builds; copied in when their door opens |

### Adding a room

1. Build its template in `ServerStorage.RoomTemplates` (needs a `Spawn` pad).
2. Add an entry to `RoomDefinitions` with the same Id.
3. Add `Server/Rooms/<Id>.luau` with `new`, `Start`, `Update` and `Cleanup` (copy ReverseGravity's shape; it's the shortest), and register it in `RoomManager`'s `ROOM_MODULES`.

Code exists in two places: `src/` (tracked by git) and the place file. Without Rojo, edits made directly in Studio do not flow back to `src/`, so make code changes in one place only.

## Game states

```text
WaitingForPlayers → Intermission → DoorVoting → LoadingRoom → PlayingRoom → RoomCompleted
                                       ↑                                          │
                                       └──────────── next room (×4) ──────────────┤
                                                                                  ↓
                         Intermission / WaitingForPlayers ← ReturningToLobby ← RunCompleted
```

The server rejects any transition not in this diagram (`VALID_TRANSITIONS` in `GameManager`).

## Design decisions (gaps the PRD left open)

- **Voting location:** every vote happens at the door area in the lobby; players are teleported back there between rooms.
- **Late joiners:** players who join mid-run wait in the lobby for the next run; the HUD tells them so.
- **Streaming off:** `Workspace.StreamingEnabled = false`. The map is small, and this stops teleports from landing on parts that haven't loaded yet.
- **Countdown:** the server sends one end time (`EndsAt`); each client counts down locally, so there is no per-second network traffic.
- **Door risk:** every vote offers one safe, one suspicious and one cursed door in random order. Risk will set room difficulty and coin reward (easy/medium/hard = 10/20/35), so players trade danger for coins.
- **Who votes:** only players in the current run. Votes are rejected when voting is closed, for invalid door numbers, or more often than every 0.25 s.
- **Ties and no votes:** a random pick among the tied doors (no votes = all three tied). The HUD says which happened, so the result never feels rigged.
- **Grandma moves on a fixed path** but accelerates (e.g. safe: 11 → 17 studs/s; players run at 16), so mistakes get punished. Her position is pure math, so clients draw her smoothly and the server checks catches with identical numbers. No pathfinding AI to misbehave.
- **Slippers:** Grandma throws at where you'll *be* (leads your movement). A red circle marks the landing spot for its whole 1 s flight; a hit slows you to 6 for 1.2 s ("BONK!"). Throw rate rises with door risk.
- **Mirrored kitchen:** each visit has a 50% chance to flip left/right, so the route isn't memorized.
- **Caught (Grandma)** = within 5 studs, or she has gone past you down the hall.
- **Escape anti-cheat:** escapes only count after passing a mid-room checkpoint / minimum time (Grandma, Chicken) or after the required number of flips (Reverse Gravity). Teleporting to the exit gets nothing.
- **Giant Chicken:** the "!" wind-up aims at where you're heading, then locks 0.35 s before the charge. Change direction after the lock and it misses; stand still or run straight and it gets you. Keys are shared by the group; the barn gate opens only when all are found.
- **Reverse Gravity** flips the *room*, not gravity: the blue and orange layers swap floor/ceiling. Character physics stay normal, which is far more reliable than per-player gravity. The HUD says which color to stand under next.
- **Elimination:** fail a room and you're out for the rest of the run; your camera follows survivors. Only survivors vote. The run ends early if nobody's left.
- **Run bonus:** +100 coins for surviving all four rooms.
- **Coins** are paid once per room per player per run (reward keys), plus the run bonus.
- **Saving** (DataManager): one record per player with a session lock, so two servers can never write the same player. A failed load gives a temporary profile that is never saved, so real progress can't be overwritten with zeros. Autosave every 60 s, plus on leave and on server shutdown. The data shape is versioned (`ProfileSchema`) and repaired on load.
- **Saved stats:** rooms cleared, runs played, runs survived. "Survived" also shows in the player list.
- **Shop:** coins only, cosmetics only (trails, titles, victory bursts), no Robux. The client only *asks*; the server checks the item exists, you can afford it, you don't already own it, and that you're not spamming. Purchases are confirmed first and auto-equip. Emotes and accessories need uploaded animation/mesh assets, so they wait for a later phase.

## Optional: Rojo

`default.project.json` is ready. To make `src/` the live source of truth: install [Rojo](https://rojo.space), install its Studio plugin, run `rojo serve`, and click **Connect** in the plugin.
