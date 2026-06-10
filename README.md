# Alien Invasion — Developer README

A Roblox wave-survival shooter built with Rojo and Luau. Players fight off escalating zombie waves with a Desert Eagle on their own isolated map. Designed to scale to thousands of concurrent players via a two-place matchmaking architecture.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [How the Game Works](#how-the-game-works)
   - [Lobby Flow](#lobby-flow)
   - [Battle Flow](#battle-flow)
   - [Wave System](#wave-system)
   - [Gun System](#gun-system)
   - [Zombie AI](#zombie-ai)
   - [Per-Player Maps](#per-player-maps)
3. [Multiplayer Architecture](#multiplayer-architecture)
   - [Match Place (the game)](#match-place-the-game)
   - [Lobby Place (matchmaking)](#lobby-place-matchmaking)
   - [How Matchmaking Works End-to-End](#how-matchmaking-works-end-to-end)
4. [File Reference](#file-reference)
5. [Config Reference](#config-reference)
6. [Roblox Studio Setup](#roblox-studio-setup)
7. [Publishing to Live](#publishing-to-live)
8. [Known Limitations](#known-limitations)

---

## Project Structure

```
AlienInvasion/
│
├── places/
│   ├── match/
│   │   ├── default.project.json ← Rojo project for the Match Place
│   │   └── src/
│   │       ├── shared/
│   │       ├── server/
│   │       └── client/
│   └── lobby/
│       ├── default.project.json ← Rojo project for the Lobby Place
│       └── src/
│           ├── shared/
│           ├── server/
│           └── client/
├── tools/
├── AgentInstructions.md
├── README.md
└── roadMap.md
```

---

## How the Game Works

### Lobby Flow

1. A player joins the Match Place and their character spawns at the `Spawn_In` part inside the `Lobby_Football` model in Workspace.
2. They walk onto the **GoToGame** pad (a part named `GoToGame` inside the lobby model).
3. The client detects the `Touched` event, shows a confirmation UI ("ALIEN INVASION" title + "PLAY GAME" button).
4. The player clicks **PLAY GAME** → the client fires `RequestPlay` to the server.
5. The server validates the player isn't already in a battle, then calls `WaveManager.startBattle`.

### Battle Flow

1. `WaveManager.startBattle` clones the `Map_FastFood` model from `ServerStorage` and places it at a unique world position (4000 studs apart per player on the X axis).
2. The player's character is teleported to the map's `Spawn_In` part.
3. The `Deagle` gun is cloned from `ServerStorage` into the player's Backpack.
4. The wave loop begins.
5. When the player dies or disconnects:
   - All zombies tagged with their name are destroyed.
   - Their map clone is destroyed.
   - The gun is removed from the Backpack (Roblox clears it on character reset).
6. `WaveManager.startBattle` returns the wave number reached. `GameManager` (in production) saves this to DataStore and, once all players are done, teleports everyone back to the Lobby.
7. The player's character respawns in the lobby. They can walk onto the GoToGame pad and click **PLAY GAME** to start a completely new battle.

> **Note on death detection:** `startBattle` captures the battle character's `Humanoid` at the start of the session and checks that specific reference throughout the wave loop. This ensures that even if Roblox respawns the player before cleanup finishes, the battle correctly detects the death (the old humanoid's `Health` stays `0` after death) and exits cleanly.

### Wave System

- Waves start at `STARTING_WAVE` (default: 2).
- Each wave spawns exactly `waveNumber` zombies, one per second (`WAVE_SPAWN_INTERVAL`).
- The wave loop waits until all zombies are dead before starting the next wave.
- Between waves there is a `WAVE_BETWEEN_DELAY` (default: 5 seconds) cooldown.
- The current wave number is fired to the client via the `WaveAnnounce` RemoteEvent so the HUD updates.

```
Wave 2 → 2 zombies
Wave 3 → 3 zombies
Wave 4 → 4 zombies
... and so on indefinitely until the player dies
```

### Gun System

The gun is a Roblox **Tool** named `Deagle` stored in `ServerStorage` (not StarterPack), so players only have it during a battle.

| Property | Value |
|---|---|
| Damage per shot | 34 HP |
| Magazine size | 7 rounds |
| Fire cooldown | 0.15 s |
| Reload time | 2.0 s |
| Effective range | 1000 studs |

**Client-side flow:**
1. `Tool.Activated` fires when the player clicks/taps.
2. Client casts a ray from the camera through the mouse position.
3. If a zombie is hit, client fires `ShootGun` RemoteEvent to the server.
4. Server validates and calls `ZombieManager.damageZombie`.
5. Muzzle flash (`PointLight` named `FlashLight` inside the `Muzzle` part) is shown briefly on the client.
6. Ammo HUD (bottom-right of screen) decrements and shows a reload bar when `R` is pressed.

**Security note:** The server never trusts the client's damage calculation. The client only sends which zombie model was hit; the server applies the fixed `GUN_DAMAGE` value from Config.

### Zombie AI

Each zombie is cloned from a `Zombie` template in `ServerStorage`. Key behaviours:

- **Ownership tagging:** `zombie:SetAttribute("Owner", playerName)` — used to clean up only this player's zombies on death.
- **Collision group:** Every zombie part is assigned to the `Zombies` collision group on spawn. This allows specific map parts (set to `ZombiePassthrough`) to be walked through by zombies while still blocking players. Zombies collide with floors, walls, and everything else normally.
- **Chase:** A `task.spawn` loop calls `humanoid:MoveTo(playerRoot.Position)` every `ZOMBIE_CHASE_INTERVAL` seconds (0.1 s).
- **Spider/wall-climb logic:** A forward raycast detects walls; if blocked, the zombie's root is nudged upward, allowing it to climb ramps and obstacles.
- **Touch damage:** Every `BasePart` on the zombie has a `Touched` connection. On contact with a player's character, `TakeDamage(ZOMBIE_TOUCH_DAMAGE)` is called (10 HP) with a 1-second cooldown to prevent rapid damage stacking.
- **Death:** `humanoid.Died` fires → brief 0.5 s delay → zombie destroyed → `onDied()` callback decrements `zombiesRemaining` in WaveManager.

### Collision Groups

Set up in `Main.server.luau` at server start:

| Group | Assigned to | Collides with `Default` | Collides with `Zombies` | Collides with `ZombiePassthrough` |
|---|---|---|---|---|
| `Default` | Players, map floors/walls | ✅ | ✅ | ✅ |
| `Zombies` | All zombie parts | ✅ | ✅ | ❌ |
| `ZombiePassthrough` | Parts zombies should ignore | ✅ | ❌ | ✅ |

To make a part zombie-passthrough in Studio: select the part → **Model tab → Collision Groups** → set group to `ZombiePassthrough`. Players are still blocked by it.

### Per-Player Maps

Each battle clones the map model and places it at a completely different world position:

```
Player 1 → slot 0 → X = 0,    Z = 5000
Player 2 → slot 1 → X = 4000, Z = 5000
Player 3 → slot 2 → X = 8000, Z = 5000
...
```

This means players on the same server never see each other's zombies, can't accidentally interfere, and the zombie touch-damage system doesn't need filtering (physical separation is enough). Maps are destroyed when the battle ends to keep the server clean.

---

## Multiplayer Architecture

The game is split into **two separate Roblox Places** that live under the same game universe:

| Place | Rojo Project | Purpose |
|---|---|---|
| **Match Place** | `places/match/default.project.json` | The actual game (lobby pad + waves) |
| **Lobby Place** | `places/lobby/default.project.json` | Queue UI + matchmaker |

### Match Place (the game)

Scripts under `places/match/src/server/`:

| Script | Runs when | Does |
|---|---|---|
| `Main.server.luau` | Always | Creates `ShootGun`, `WaveAnnounce`, `RequestPlay` RemoteEvents; handles GoToGame pad |
| `WaveManager.luau` | Required by Main/GameManager | Clones map, gives gun, runs wave loop |
| `ZombieManager.luau` | Required by WaveManager | Spawns and manages individual zombies |
| `GameManager.luau` | Required by MatchInit | Tracks WAITING→ACTIVE→ENDED state; saves DataStore stats; returns players to lobby |
| `MatchInit.server.luau` | Always (but exits instantly in Studio) | Waits for `MATCH_SIZE` players to arrive via teleport, then calls `GameManager.startMatch` |

**In Studio (dev mode):** `MatchInit` exits immediately. You use the GoToGame pad + `RequestPlay` flow. `GameManager` is not involved (Main calls WaveManager directly).

**In production (live server):** Players arrive via `TeleportService`. `MatchInit` auto-starts the match. `GameManager` tracks state, saves stats, and teleports everyone back to the Lobby when all battles finish.

### Lobby Place (matchmaking)

Scripts under `places/lobby/src/server/`:

#### MatchmakerService.luau

Wraps **MemoryStoreService SortedMap** — a cross-server key-value store shared by all lobby servers simultaneously.

- **Key:** `tostring(player.UserId)` — allows removing a specific player if they cancel.
- **Value:** `{ userId, name }` — the data passed to the matchmaker.
- **Sort key:** `os.time()` — ensures FIFO ordering (earliest queued player gets matched first).
- **Expiry:** 120 seconds — queue entries auto-delete if the player disconnects without cancelling.

| Function | What it does |
|---|---|
| `enqueue(player)` | Adds player to global cross-server queue |
| `dequeue(player)` | Removes player by UserId (e.g. they cancelled) |
| `tryFormMatch()` | Reads oldest `MATCH_SIZE` entries; removes them; returns data array or nil |

#### TeleportHelper.luau

Wraps `TeleportService` with up to 3 automatic retries and a 2-second delay between attempts.

| Function | What it does |
|---|---|
| `teleportToMatch(players)` | `ReserveServer` → creates `TeleportOptions` with access code → `TeleportAsync` to Match Place |
| `returnToLobby(players)` | `TeleportAsync` back to Lobby Place |

Using `ReserveServer` means each matched group of players gets their own private server instance — they are completely isolated from other groups.

#### Matchmaker.server.luau

The main matchmaking script. Runs a polling loop every `QUEUE_POLL_RATE` seconds (default: 3 s).

**RemoteEvents created:**

| Event | Direction | Purpose |
|---|---|---|
| `JoinQueue` | Client → Server | Player clicked Find Match |
| `LeaveQueue` | Client → Server | Player clicked Cancel |
| `MatchFound` | Server → Client | Triggers the countdown UI |

**Loop logic:**
1. `MatchmakerService.tryFormMatch()` — returns `nil` if fewer than `MATCH_SIZE` players are queued.
2. Resolves UserId → live Player objects (filters out anyone who disconnected since queuing).
3. Fires `MatchFound` to each matched client (shows 3-second countdown).
4. After 3 seconds, calls `TeleportHelper.teleportToMatch`.
5. If teleport fails after 3 retries, re-queues the surviving players automatically.

### How Matchmaking Works End-to-End

```
[Player joins Lobby Place]
        │
        ▼
[LobbyClient shows "Find Match" button]
        │  click
        ▼
[JoinQueue → Matchmaker.server → MatchmakerService.enqueue]
   (entry written to MemoryStoreService across ALL lobby servers)
        │
        │  every 3 seconds on every lobby server...
        ▼
[MatchmakerService.tryFormMatch]
   ┌── fewer than 4 players? → wait
   └── 4+ players found → remove from queue
        │
        ▼
[MatchFound fired to 4 clients → 3-second countdown]
        │
        ▼
[TeleportHelper.teleportToMatch]
   → ReserveServer(MATCH_PLACE_ID) → private access code
   → TeleportAsync(all 4 players, options with access code)
        │
        ▼
[4 players arrive in a fresh reserved Match Place server]
        │
        ▼
[MatchInit.server.luau polls until MATCH_SIZE players joined or 15s timeout]
        │
        ▼
[GameManager.startMatch → WaveManager.startBattle per player (concurrent)]
        │
        │  (each player fights their own waves on their own map)
        │
        ▼
[All players die / finish → GameManager saves DataStore stats]
        │  5 second delay
        ▼
[TeleportService sends all players back to Lobby Place]
        │
        ▼
[Back to "Find Match" screen]
```

---

## File Reference

### Match Place

| File | Service in Roblox |
|---|---|
| `places/match/src/shared/Config.luau` | `ReplicatedStorage.Shared.Config` |
| `places/match/src/server/Main.server.luau` | `ServerScriptService.Server` |
| `places/match/src/server/WaveManager.luau` | `ServerScriptService.Server.WaveManager` |
| `places/match/src/server/ZombieManager.luau` | `ServerScriptService.Server.ZombieManager` |
| `places/match/src/server/GameManager.luau` | `ServerScriptService.Server.GameManager` |
| `places/match/src/server/MatchInit.server.luau` | `ServerScriptService.Server.MatchInit` |
| `places/match/src/client/init.client.luau` | `StarterPlayer.StarterPlayerScripts.Client` |

### Lobby Place

| File | Service in Roblox |
|---|---|
| `places/lobby/src/shared/Config.luau` | `ReplicatedStorage.Shared.Config` |
| `places/lobby/src/server/Matchmaker.server.luau` | `ServerScriptService.LobbyServer` |
| `places/lobby/src/server/MatchmakerService.luau` | `ServerScriptService.LobbyServer.MatchmakerService` |
| `places/lobby/src/server/TeleportHelper.luau` | `ServerScriptService.LobbyServer.TeleportHelper` |
| `places/lobby/src/client/init.client.luau` | `StarterPlayer.StarterPlayerScripts.LobbyClient` |

---

## Config Reference

Match-place values live in `places/match/src/shared/Config.luau`. Lobby-place values live in `places/lobby/src/shared/Config.luau`. Change numbers there — no logic files need touching.

### Zombie

| Key | Default | Description |
|---|---|---|
| `ZOMBIE_MAX_HEALTH` | 50 | HP per zombie |
| `ZOMBIE_WALK_SPEED` | 14 | Studs/s chase speed |
| `ZOMBIE_TOUCH_DAMAGE` | 10 | HP removed on contact |
| `ZOMBIE_DAMAGE_COOLDOWN` | 1 | Seconds between hits from same zombie |
| `ZOMBIE_CHASE_INTERVAL` | 0.1 | How often MoveTo refreshes |
| `ZOMBIE_SPAWN_HEIGHT` | 3 | Studs above ground at `Spawn_Mob` part |

### Gun

| Key | Default | Description |
|---|---|---|
| `GUN_NAME` | `"Deagle"` | Must match the Tool name in ServerStorage |
| `GUN_DAMAGE` | 34 | HP per shot (server-authoritative) |
| `GUN_RANGE` | 1000 | Max raycast distance in studs |
| `GUN_FIRE_COOLDOWN` | 0.15 | Seconds between shots |
| `GUN_MAG_SIZE` | 7 | Rounds before forced reload |
| `GUN_RELOAD_TIME` | 2.0 | Seconds to reload |
| `GUN_MUZZLE_DELAY` | 0.05 | How long the muzzle flash is visible |

### Waves

| Key | Default | Description |
|---|---|---|
| `STARTING_WAVE` | 2 | First wave number (also zombie count for wave 1) |
| `WAVE_START_DELAY` | 3 | Seconds before first wave starts |
| `WAVE_BETWEEN_DELAY` | 5 | Seconds between cleared waves |
| `WAVE_SPAWN_INTERVAL` | 1 | Seconds between individual zombie spawns per wave |

### Player Movement

| Key | Default | Description |
|---|---|---|
| `PLAYER_WALK_SPEED` | 16 | Default walk speed |
| `PLAYER_SPRINT_SPEED` | 30 | Speed while holding Shift |
| `PLAYER_JUMP_POWER` | 70 | Jump height |

### Map / Lobby

| Key | Default | Description |
|---|---|---|
| `LOBBY_NAME` | `"Lobby_Football"` | Name of lobby model in Workspace |
| `MAP_NAME` | `"Map_FastFood"` | Name of map template in ServerStorage |
| `LOBBY_PAD_NAME` | `"GoToGame"` | Name of the trigger part inside the lobby |

### Matchmaking

| Key | Default | Description |
|---|---|---|
| `LOBBY_PLACE_ID` | 0 | **TODO:** Replace with your Lobby Place ID |
| `MATCH_PLACE_ID` | 0 | **TODO:** Replace with your Match Place ID |
| `MATCH_SIZE` | 4 | Players grouped into each reserved server |
| `QUEUE_POLL_RATE` | 3 | Seconds between matchmaker checks |
| `MATCH_WAIT_TIMEOUT` | 15 | Seconds to wait for players before auto-starting |
| `MEMORY_STORE_NAME` | `"MatchQueue"` | MemoryStoreService key name |
| `DATA_STORE_NAME` | `"PlayerStats"` | DataStoreService key name for saving scores |

---

## Roblox Studio Setup

### Required objects in the Place

| Location | Object | Notes |
|---|---|---|
| `Workspace` | `Lobby_Football` model | Must contain a `BasePart` named `Spawn_In` and a `BasePart` named `GoToGame` |
| `ServerStorage` | `Map_FastFood` model | The battle arena; cloned per player at runtime. Must contain a `BasePart` named `Spawn_Mob` — this is where zombies appear each wave |
| `ServerStorage` | `Deagle` (Tool) | The gun; must have a `Handle`, a `Muzzle` part, and a `PointLight` named `FlashLight` inside Muzzle |
| `ServerStorage` | `Zombie` (Model) | The zombie template; must have a `Humanoid` and a `HumanoidRootPart` |

### Testing in Studio

1. Open the match place with `rojo serve places/match/default.project.json`.
2. Click **Play** or use **Team Test** for multiplayer.
3. Walk onto the GoToGame pad and click **PLAY GAME** to start a battle.
4. `MatchInit.server.luau` exits immediately in Studio — the GoToGame pad is the only way to start.
5. Enable **Studio Access to API Services** (File → Studio Settings → Security) to test DataStore saves.

The lobby matchmaking scripts (`places/lobby/`) are not part of the match-place Studio session. Serve `places/lobby/default.project.json` when you need the lobby place.

---

## Publishing to Live

### Step 1 — Build both places

```powershell
# Match Place
rojo build places/match/default.project.json --output Match.rbxlx

# Lobby Place
rojo build places/lobby/default.project.json --output Lobby.rbxlx
```

### Step 2 — Publish to Roblox

1. Open `Match.rbxlx` in Studio → **File → Publish to Roblox** → create a new game.
2. Open `Lobby.rbxlx` in Studio → **File → Publish to Roblox As** → add as a new Place inside the **same game** (not a new game).

### Step 3 — Get the Place IDs

- Open Creator Dashboard → your game → **Places**.
- Copy the numeric ID from each place's URL.

### Step 4 — Fill in the IDs

Update both Config files with the real numbers:

**`places/match/src/shared/Config.luau`** (Match Place):
```lua
LOBBY_PLACE_ID = 12345678,
MATCH_PLACE_ID = 87654321,
```

**`places/lobby/src/shared/Config.luau`** (Lobby Place):
```lua
LOBBY_PLACE_ID = 12345678,
MATCH_PLACE_ID = 87654321,
```

Then rebuild and re-publish both places.

### Step 5 — Enable Roblox APIs

In Creator Dashboard → your game → **Settings → Security**:

- Enable **Allow HTTP Requests** if needed.
- MemoryStoreService and DataStoreService are enabled by default for published games.

---

## Known Limitations

| Issue | Detail |
|---|---|
| **Race condition in matchmaking** | Two lobby servers polling simultaneously could both read the same queue entries. The probability is very low at a 3-second poll rate, but at extremely high player counts a distributed lock would be more correct. |
| **`nextMapSlot` not persistent** | The slot counter resets if the Match Place server restarts. With 4000-stud spacing this is fine in practice. |
| **Main.server.luau bypasses GameManager** | The GoToGame pad calls `WaveManager.startBattle` directly. In production the GoToGame pad is replaced by `MatchInit`'s auto-start which routes through `GameManager`. |
| **No reconnection handling** | If a player disconnects mid-battle their map and zombies are cleaned up, but they cannot rejoin the same session. |
| **Stats only save best wave** | DataStore tracks `bestWave` and `totalGames` per player. Kill count and time-survived are not tracked. |

## Light Show Tool
You can generate new light shows from MP3 files using the provided tool:
```bash
.venv/bin/python tools/generate_light_show.py path/to/song.mp3 --name MyNewSong --output src/shared/Configs/LightShowConfig.luau
```
Arguments:
- `input`: Path to the MP3 file.
- `--name`: The name for the Luau functions (e.g., `GetMyNewSongShow`).
- `--output`: File to append the generated code to.
