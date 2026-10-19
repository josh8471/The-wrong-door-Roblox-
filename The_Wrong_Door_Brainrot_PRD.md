# Product Requirements Document (PRD)
## The Wrong Door — Brainrot Edition

**Platform:** Roblox  
**Genre:** Multiplayer survival, comedy, and challenge game  
**Version:** 1.1  
**Status:** MVP specification  
**Target server size:** Up to 10 players  
**Technology:** Roblox Studio + Luau; optional Rojo

---

## 1. Product Summary

### Vision
The Wrong Door is a multiplayer Roblox game where players enter a strange building and vote for one of three doors. Each door leads to a ridiculous challenge room featuring hazards, puzzles, traps, or absurd characters.

Players survive each room, earn coins, and attempt to complete a run of four rooms.

**Core promise:** Vote for a door. Regret your decision. Survive the chaos. Do it again.

### Goals
- Create a fun, easy-to-understand multiplayer game loop.
- Make door voting suspenseful.
- Provide varied, replayable challenge rooms.
- Create funny moments players want to share.
- Save coins and cosmetic ownership.
- Support desktop, mobile, and tablet.
- Keep scope manageable for a solo developer using Claude Code and Roblox Studio.

### Non-goals for the MVP
No AI-generated rooms, trading, pets, ranked matchmaking, huge open world, external backend, paid random rewards, or Robux purchases. Prove the core game is fun first.

## 2. Audience and Design Principles

### Audience
Roblox players who enjoy survival games, obstacle courses, absurd comedy, mystery, short rounds, playing with friends, and collecting cosmetics.

### Principles
- **Easy to understand:** One or two sentences explain each challenge.
- **Funny, not confusing:** Visual jokes must not hide hazards or objectives.
- **Fair:** Players understand why they succeeded or failed.
- **Fast:** Most rooms last around 20–60 seconds.
- **Replayable:** Vary room order and door choices.
- **Cosmetic-first:** Purchases never become necessary to survive.
- **Mobile-friendly:** All essential actions work with touch controls.

## 3. Core Gameplay Loop

1. Players spawn in the lobby.
2. An intermission countdown begins.
3. Three doors become available.
4. Players vote.
5. The server resolves the vote.
6. Players enter the selected room.
7. The objective and timer appear.
8. The server determines success or failure.
9. Eligible players earn coins.
10. Survivors proceed to the next room.
11. After four rooms, the results screen appears.
12. Players return to the lobby.

### Initial settings

| Setting | Target |
|---|---|
| Maximum players | 10 |
| Minimum players | 1 for solo testing |
| Doors per vote | 3 |
| Voting duration | 10 seconds |
| Rooms per run | 4 |
| Initial room types | 3 |
| Typical room duration | 20–60 seconds |
| Currency | Coins |
| Saved progression | Coins, owned cosmetics, selected cosmetics, basic stats |

These values should be configurable and adjusted after playtesting.

## 4. Lobby

The lobby must include:
- Player spawn point.
- Three-door voting area.
- Round countdown.
- Coin balance.
- Cosmetic shop access.
- Brief game instructions.
- Optional basic leaderboard.
- Clear paths between spawn, doors, and shop.

Use a mysterious, exaggerated comedy style with original props and readable layouts.

**Acceptance criteria:** Players spawn safely, can find the doors, understand the countdown, and return to the lobby after a run.

## 5. Door Voting

### Requirements
- Display three valid door choices.
- Show a door number and vague theme/risk hint.
- Allow one active vote per player.
- Let players change their vote before voting closes.
- Display vote counts and countdown.
- Stop accepting votes when the timer ends.
- Resolve the winning door on the server.
- Select randomly among tied doors.
- Select a valid random door if nobody votes.
- Reject invalid or late votes.

### Door hints
Examples: “Probably safe,” “Looks suspicious,” and “Absolutely cursed.” Hints should build anticipation without revealing the exact room.

### Security
The server validates player eligibility, voting state, door ID, and request frequency. The client must never determine the winning door or select the room template.

## 6. Shared Room Framework

Each room must follow the same lifecycle:
1. Select and load a valid room.
2. Move active players to room spawn points.
3. Display the objective and controls.
4. Start the timer and challenge.
5. Track each player's result.
6. Award eligible rewards once.
7. Stop timers and disconnect room-specific events.
8. Remove temporary objects and reset state.
9. Transition to the next state.

Suggested player states: `Active`, `Succeeded`, `Failed`, `Disconnected`, and `Spectating`.

Keep room-specific logic separate from the main game manager. A room module may expose methods such as `Setup`, `Start`, `GetPlayerResult`, and `Cleanup`; exact names can be adapted during implementation.

## 7. MVP Rooms

### Room A: Angry Grandma
**Genre:** Chase and obstacle survival  
**Objective:** Reach the exit before Grandma catches you.

Gameplay:
- Players spawn in a compact kitchen, supermarket, or hallway.
- A short instruction explains the objective.
- Grandma begins chasing after a brief warning.
- Players dodge obstacles and reach a safe exit.
- A slipper projectile can be added after basic chasing works.
- Players caught or still outside the exit when time expires fail.

**MVP scope:** Start with a predictable route or simple chase logic. Avoid complex AI and multiple enemies initially.

**Acceptance criteria:** Chase starts and stops correctly, catch detection is consistent, the exit is reachable, results are server-validated, and cleanup leaves no active hazards.

### Room B: Giant Chicken
**Genre:** Exploration and light horror-comedy  
**Objective:** Find keys and open the exit without getting caught.

Gameplay:
- Players enter a small farm-like area.
- Keys appear in known locations.
- The exit remains locked until the objective is met.
- One giant chicken patrols or reacts to nearby players.
- Players can cooperate to find keys.
- Players caught by the chicken fail; players reaching the valid exit succeed.

**MVP scope:** One chicken, a small map, simple patrol behavior, and a clear key-and-exit system.

**Acceptance criteria:** Keys work, the exit cannot be opened early, catch detection is consistent, success requires reaching the exit, and room state resets correctly.

### Room C: Reverse Gravity
**Genre:** Obstacle course and physics challenge  
**Objective:** Reach safety while gravity changes direction.

Gameplay:
- Players navigate platforms toward a goal.
- Gravity changes at configured intervals, with a warning first.
- The room provides enough space to avoid unavoidable instant deaths.
- Players reaching the safe platform succeed; players falling into hazards or running out of time fail.

**Implementation note:** Prefer a controlled, room-specific gravity mechanic. If per-player gravity is unreliable, use scripted launch pads, moving platforms, or force effects to create the same feeling without changing the entire server's physics.

**Acceptance criteria:** Warnings appear, the challenge is completable, fall/success detection works, and effects are removed during cleanup.

## 8. Future Room Ideas

These are not MVP blockers.

| Room | Mechanic |
|---|---|
| Bouncing Toilet Room | Dodge bouncing hazards |
| Chicken Dance Trial | Copy dance prompts |
| Giant Duck Flood | Climb as ducks fill the room |
| Fake Exit | Identify the real exit |
| Dark Hallway | Navigate with limited visibility |
| Treasure Trap | Collect optional treasure while avoiding hazards |
| Invisible Maze | Use clues to navigate a hidden maze |
| Giant Shoe | Dodge timed stomps |
| Tiny Players | Complete an obstacle course after shrinking |
| Giant Head | Navigate with exaggerated character proportions |

Each new room should introduce a distinct mechanic, not merely a new visual theme.

## 9. Run Progression and Spectating

- A run contains four room stages.
- Difficulty should rise gradually.
- Avoid selecting the same room consecutively when possible.
- A failed player spectates for the rest of the run.
- Spectators cannot interact with objectives or earn rewards for challenges they did not complete.
- If all active players fail, end the run early.
- Disconnects must not block transitions or award future rewards.

## 10. Coins and Rewards

### Initial reward configuration

| Activity | Coins |
|---|---:|
| Complete an easy room | 10 |
| Complete a medium room | 20 |
| Complete a hard room | 35 |
| Complete a full four-room run | 100 bonus |

Keep reward values in a shared configuration module and tune them after testing.

### Reward rules
- The server awards coins.
- Each room reward can be granted only once per eligible player.
- The server verifies success.
- Clients cannot request arbitrary coin amounts.
- The run bonus is awarded only when the run completion condition is met.

### Saved statistics
Save coins, rooms completed, full runs completed, successful escapes, owned cosmetics, and selected cosmetics. Keep the schema small and version it for future changes.

## 11. Cosmetic Shop and Monetization

### MVP
Sell cosmetics for coins earned through gameplay:
- Character trails.
- Flashlight skins.
- Victory effects.
- Emotes.
- Funny accessories.
- Lobby name-tag styles.

Robux monetization is excluded until the core game is stable and feedback shows demand.

### Possible post-launch revenue
- Premium cosmetic bundles.
- Cosmetic game passes.
- More emotes and effects.
- Private servers, free or paid as appropriate.
- Repeatable purchases only if they fit the economy.

Keep purchases optional and avoid pay-to-win mechanics or aggressive prompts. Review current Roblox policies before adding paid features.

## 12. UI and Visual Design

### Required screens
**Lobby:** coin balance, countdown, instructions, shop access.  
**Voting:** three doors, vote counts, hints, timer, selected vote.  
**Challenge:** short objective, timer, relevant status such as keys collected.  
**Results:** success/failure, coins earned, rooms completed, run outcome.  
**Shop:** cosmetic preview, price, ownership state, purchase confirmation.

### Visual direction
Use expressive props, strong hazard silhouettes, visible exits, brief warnings, original characters, and uncluttered layouts. Humor should come from characters, timing, and situations—not unreadable objectives.

### Mobile/accessibility
- Touch-friendly buttons and readable text.
- Avoid reliance on keyboard input.
- Keep critical UI away from screen edges.
- Provide visual warnings in addition to audio.
- Test camera and controls in narrow rooms.
- Ensure hazards and exits are visible.

## 13. Technical Architecture

### Stack

| Component | Technology |
|---|---|
| Engine | Roblox Studio |
| Language | Luau |
| Server gameplay | `ServerScriptService` |
| Shared modules/remotes | `ReplicatedStorage` |
| Client UI/input | `StarterGui`, `StarterPlayer` |
| Room templates | `ServerStorage` |
| Persistent data | `DataStoreService` |
| Version control | Git |
| Optional code synchronization | Rojo |

No separate Node.js, React, or external database is needed for the MVP.

### Suggested project structure

```text
TheWrongDoor/
├── default.project.json
├── src/
│   ├── server/
│   │   ├── Main.server.luau
│   │   ├── GameManager.luau
│   │   ├── DoorVoting.luau
│   │   ├── RoomManager.luau
│   │   ├── RewardManager.luau
│   │   ├── DataManager.luau
│   │   └── ShopManager.luau
│   ├── client/
│   │   ├── Main.client.luau
│   │   ├── UIController.luau
│   │   └── InputController.luau
│   └── shared/
│       ├── GameConfig.luau
│       └── RoomDefinitions.luau
└── README.md
```

If Rojo is not installed, start in Roblox Studio and introduce Rojo only if it improves the workflow.

### Game states
1. `WaitingForPlayers`
2. `Intermission`
3. `DoorVoting`
4. `LoadingRoom`
5. `PlayingRoom`
6. `RoomCompleted`
7. `RunCompleted`
8. `ReturningToLobby`

Only valid transitions are allowed. Do not start voting while a previous room is still active or cleaning up.

### Server/client responsibilities
**Server:** game state, voting results, room selection, challenge outcomes, elimination, rewards, purchases, persistent data.  
**Client:** UI, input, local visual effects, requests such as voting.

Validate every client request on the server. Never trust a client to declare a win or award currency.

### Persistence
Use `DataStoreService` from server scripts. Handle failures safely, use protected calls and appropriate retries, avoid excessive writes, and never overwrite existing data with defaults when a load fails. Use a separate test experience or test data store during development.

### Performance and cleanup
- Keep active room object counts reasonable.
- Clean up temporary hazards, event connections, and timers.
- Avoid unnecessary loops and remote traffic.
- Load only the active room.
- Test on real mobile devices and with multiple players.

## 14. Analytics and Validation

Track available, appropriate aggregate metrics:

| Metric | Purpose |
|---|---|
| First-room completion | Whether new players understand the game |
| Four-room run completion | Overall difficulty |
| Return-session rate | Whether players want to play again |
| Room failure rate | Identify unfair or confusing rooms |
| Disconnect rate | Identify stability problems |
| Cosmetic purchase rate | Evaluate shop interest after monetization |

### Initial internal targets
- At least 80% of testers understand voting without assistance.
- At least 80% of test runs finish without a critical error.
- A full run completes without developer intervention.
- Rewards are granted exactly once per eligible completion.
- Saved progress survives leaving and rejoining.
- Core gameplay works on desktop and mobile.
- Testers can name at least one room they want to replay.

These are internal targets, not industry benchmarks. Do not optimize for playtime alone; prioritize fun and fairness.

## 15. Testing Plan

### Functional tests
Joining/leaving, intermission, voting, changed votes, ties, no votes, room loading, timers, success/failure, elimination, spectating, rewards, saving/loading, shop purchases, and returning to the lobby.

### Multiplayer tests
Verify consistent voting results, correct handling of deaths and disconnects, no duplicate rewards, rejection of late votes, no client-side currency manipulation, and correct run termination when all players fail.

### Room tests
- **Angry Grandma:** chase, catch detection, exit, cleanup.
- **Giant Chicken:** key collection, locked exit, catch detection, reset.
- **Reverse Gravity:** warnings, completable physics, fall detection, cleanup.

### Data tests
Verify defaults for new players, retention of existing data, safe load failures, duplicate reward prevention, and safe handling of save errors.

## 16. Development Roadmap

### Phase 1 — Foundation
Create the Studio project, Git repository, optional Rojo setup, lobby, game-state manager, and README.  
**Exit criteria:** A test round starts and transitions between states.

### Phase 2 — Door voting
Build three door choices, voting UI, server validation, tie/no-vote handling, and transitions.  
**Exit criteria:** Multiple test players see consistent results.

### Phase 3 — First room
Build Angry Grandma, timer, objective UI, success/failure detection, cleanup, and rewards.  
**Exit criteria:** The room can be replayed without manual reset.

### Phase 4 — Reusable room system
Add Giant Chicken, Reverse Gravity, four-room runs, elimination, spectating, and room rotation.  
**Exit criteria:** Full runs complete correctly.

### Phase 5 — Progression and UI
Add coins, persistence, results screens, basic stats, and a coin-based cosmetic shop.  
**Exit criteria:** Players can earn, save, spend, leave, and rejoin with progress intact.

### Phase 6 — Polish and testing
Add mobile polish, sound and visual feedback, multiplayer testing, performance fixes, icon, thumbnail, and critical bug fixes.  
**Exit criteria:** No known critical issue blocks a full run.

### Phase 7 — Public testing and expansion
Release a small playable version, collect feedback, and fix problems before adding more rooms or monetization.

## 17. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Funny once, not replayable | Players leave quickly | Vary mechanics and room combinations |
| Scope grows too large | Delayed launch | Start with three polished rooms |
| Chase AI is unreliable | Unfair challenge | Use simple predictable movement |
| Physics varies across devices | Frustrating room | Use controlled room-specific mechanics |
| Objectives are unclear | Early exits | Short instructions and visible exits |
| Coin exploits | Broken economy | Server-authoritative rewards |
| Data loss | Lost progression | Safe load/save handling and testing |
| Poor mobile UX | Mobile players struggle | Test small screens early |
| Unfair monetization | Loss of player trust | Keep purchases optional and cosmetic |

## 18. MVP Acceptance Checklist

- [ ] Players spawn safely in the lobby.
- [ ] Rounds start and end correctly.
- [ ] Three doors are available for voting.
- [ ] Vote changes, ties, and no-vote cases work.
- [ ] All three MVP rooms are playable.
- [ ] Each room has a clear objective and timer.
- [ ] The server determines success and failure.
- [ ] Failed players spectate and cannot earn future room rewards.
- [ ] Runs contain four rooms or end early if all players fail.
- [ ] Coins are awarded correctly and only once.
- [ ] Results screens work.
- [ ] Data saves and loads safely.
- [ ] The coin shop validates purchases.
- [ ] Clients cannot manipulate currency or declare wins.
- [ ] Disconnects do not block game progress.
- [ ] Desktop and mobile controls are usable.
- [ ] Temporary objects, timers, and event connections are cleaned up.
- [ ] No critical bug prevents completing a full run.

## 19. Instructions for Claude Code

Build incrementally; do not ask Claude Code to implement the whole game in one pass.

1. Inspect the current project and installed tools. Do not overwrite existing work.
2. Set up the smallest working Roblox project.
3. Implement the lobby and game states.
4. Implement server-authoritative door voting.
5. Build Angry Grandma as the first complete room.
6. Test multiplayer behavior and cleanup.
7. Add Giant Chicken and Reverse Gravity using the shared room lifecycle.
8. Add four-room runs, elimination, and spectating.
9. Add coins and persistence.
10. Add UI polish and the coin-based cosmetic shop.
11. Run the acceptance checklist and fix critical issues before expanding scope.

Claude Code can edit source files, but the game still needs to be run and visually tested in Roblox Studio. If using Rojo, verify project configuration and synchronization before relying on it. Do not publish or overwrite a live experience without explicit approval.

## 20. Final Product Direction

The Wrong Door should be a small, replayable comedy-survival game built around one strong mechanic: players vote for a door and discover a ridiculous challenge.

**Recommended first release:** One lobby, three doors, three complete rooms, four rooms per run, server-controlled voting and outcomes, coins and saved progression, a small coin-based cosmetic shop, and desktop/mobile support.

Prove that players enjoy the core loop before adding more rooms or monetization. Three fun, reliable rooms are better than twenty unfinished ones.

---

## Official Roblox References

- [Roblox Creator Hub](https://create.roblox.com/)
- [Monetization documentation](https://create.roblox.com/docs/production/monetization)
- [Data stores documentation](https://create.roblox.com/docs/cloud-services/data-stores)
- [Remote events and callbacks](https://create.roblox.com/docs/scripting/events/remote)
