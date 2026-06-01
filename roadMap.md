# 🧟 Multiplayer Zombie Wave Game: Developer Checklist

This document tracks engineering progress. Items marked `[x]` are complete.

---

## ✅ Completed Beyond Original Scope

These features were fully built but are not covered by the phases below.

### 🏛️ Multi-Place Architecture
- [x] Separate Lobby place (`lobby/`) with its own `default.project.json` and server runtime.
- [x] `MatchmakingService` + `MatchQueueService` manage player queue server-side.
- [x] `Matchmaker.server.luau` drives the fill-and-launch loop; `TeleportHelperService` teleports filled parties to the match place via reserved servers.
- [x] `LobbyClient.client.luau` + `MatchmakingController` + `PadProximityModule` handle lobby UX and queue entry.

### 🔧 Custom Framework & Logger
- [x] `Framework.luau` — `CreateService`, `CreateController`, `GetRemote`, `CreateRemote`, `Start()` with enforced Init-before-Start ordering across all modules.
- [x] `Logger.luau` — `wrapServerEvent` (pcall-isolated handlers), `fireClient` (traced fires), `info`, `warn`, `verbose`. `DEBUG_NETWORKING` traces all remote payloads.

### ⚙️ Split Config System
- [x] Constants split into `EconomyConfig`, `CombatConfig`, `ZombieConfig`, `WaveConfig`, `PlayerConfig`, `MapConfig`, `DebugConfig` under `src/shared/Configs/`.
- [x] `Config.luau` merges all sub-configs into one flat table — all existing code uses `Config.KEY` unchanged.

### 💰 Dual Currency & Physical Bolt Pickups
- [x] **Silver** (run currency): awarded per zombie kill, scales with wave number via `SILVER_WAVE_MULTIPLIER_STEP`, resets to 0 with client sync on lobby return (`EconomyService.finalizeRun`).
- [x] **Gold** (persistent): random drop per zombie kill, saved to DataStore, used to permanently unlock weapons.
- [x] Physical bolt pickup models scatter at zombie death positions. Bolts rise (CFrame animation — no physics), hover, then accelerate toward the player within `BOLT_ATTRACT_RADIUS` studs.

### 🔓 Weapon Unlock System
- [x] Gold-gated permanent unlocks: Deagle/M82 free, M60 120g, M240B 180g — persisted via `DataService`.
- [x] `REQUEST_WEAPON_UNLOCK` / `WEAPON_UNLOCK_RESULT` remotes with server-side gold validation, deduction, and DataStore write.

### 🔫 Multiple Gun Types Catalog
- [x] Four guns with individual stats in `CombatConfig.GUN_STATS`: Deagle, M82, M60, M240B — each with `damage`, `fireCooldown`, `magSize`, `reloadTime`.
- [x] `GunCatalogModule` surfaces per-gun stats to `GunController`; ammo and reload state tracked per gun.

### 🛒 In-Match Gun Shop (Wave Clerk)
- [x] `ClerkInteractionModule` attaches a `ProximityPrompt` to the map's clerk NPC; triggering it fires `OPEN_GUN_SHOP` with live shop data to that player only.
- [x] Players hold up to 2 guns. Buying a 3rd shows a swap-picker overlay to choose which gun to drop.
- [x] Silver-priced guns: Deagle/M82 free, M60 80◈, M240B 100◈ (from `EconomyConfig.SHOP_GUN_PRICES`).
- [x] `GunShopModule` — dark-themed ScreenGui with current loadout slots, available guns, affordability indicators, swap-picker overlay, and a "Get Free Loadout" fallback button.
- [x] `ShopController` wires `OPEN_GUN_SHOP`, `REQUEST_GUN_PURCHASE`, `GUN_PURCHASE_RESULT`, and `REQUEST_FREE_LOADOUT` remotes to the shop UI.
- [x] Server handler in `WaveService:Start()` validates gun name, silver balance, and swap slot, then calls `EconomyService.spendSilver` and `LoadoutGrantModule.grant`.

### 🗺️ Per-Player Map Cloning & Spawn System
- [x] `WaveService.startBattle` clones the map from `ServerStorage` per player run; map is destroyed when the run ends. `_nextMapSlot` prevents position overlap.
- [x] `PlayerSpawnModule` teleports the player into their cloned map; `PlayerEntryGateModule` manages pre-match staging.

### 🛡️ Player Lifecycle & Physics
- [x] `PhysicsSetupService` — disables collisions between all player characters so they cannot push each other.
- [x] `PlayerService` — player join/leave lifecycle; cleans up run state on disconnect.
- [x] `HudController` — displays silver balance, wave number, and ammo count; silver label updates in real-time via `RUN_CURRENCY_UPDATED` remote.

---

## 🛠️ Phase 1: Project Architecture & Secure Foundations

### 📦 Task 1.1: Environment Setup & Project Directory Structure
- [x] **Version Control:** Initialize a Git repository with a robust `.gitignore` for Roblox binary files.
- [x] **Rojo Configuration:** Configure a standard directory mapping via `default.project.json`.
- [x] **Server Layer:** Create `src/ServerScriptService` for authoritative game state, combat verification controllers, AI directors, and data saving.
- [x] **Shared Layer:** Create `src/ReplicatedStorage` for shared code modules (visual physics engines, configurations) and Remote definitions.
- [x] **Client Layer:** Create `src/StarterPlayer/StarterPlayerScripts` for player input, UI rendering, camera manipulation, and local visual replication.
- [x] **DoD Check:** Code edits inside an external IDE (like VS Code) seamlessly sync to Roblox Studio; running a multi-client team-test throws zero initialization errors.

### 🔒 Task 1.2: Strict Network Layer & Remote Rate-Limiting
- [x] **Centralized Network Module:** Build a centralized network module on the server to dynamically instantiate/reference remotes in a single secure folder.
- [ ] **Sliding-Window Rate Limiter:** Implement a server-side rate-limiter tracking requests per player per second ($RPS$).
- [ ] **Exploit Throttling:** Add verification logic to flag or kick users if they fire the `WeaponFire` remote faster than their gun’s configuration attributes allow.
- [ ] **DoD Check:** Remote-spamming exploiter scripts are completely blocked by the server without causing server frame drops.

### 💾 Task 1.3: Secure Data Lifecycle Management (ProfileService)
- [ ] **Library Integration:** Integrate the open-source **ProfileService** library into `ServerScriptService` (currently using raw `DataStoreService`).
- [x] **Data Template:** `DataService` profile contains `gold` (number) and `unlockedWeapons` (dict). Starter weapons seeded from `CombatConfig.STARTER_UNLOCKED_WEAPONS`.
- [x] **Session Management:** `DataService` loads profile on `PlayerAdded` and saves/releases on `PlayerRemoving`.
- [ ] **Error Handling:** Implement a safe auto-retry/fallback system if the Roblox DataStore service experiences outages.
- [ ] **DoD Check:** A player can join a game, earn cash, leave, join a completely separate server instantly, and their data updates flawlessly with zero session-lock issues.

---

## 🔫 Phase 2: Combat & Hit Registration

### 🎯 Task 2.1: Client-Side Hitscan Gun Controller
- [x] **Input Handling:** `GunController` detects shooting inputs via `UserInputService`.
- [x] **Local Raycasting:** `GunHitScanModule` executes `Workspace:Raycast` from camera center toward mouse position.
- [x] **Client-Side Visuals:** `GunFxModule` renders tracer beam, muzzle flash, and plays local audio.
- [x] **Network Dispatch:** Fires `SHOOT_GUN` remote to server with the hit zombie model and gun name.
- [x] **DoD Check:** Clicking fires a tracer exactly where the crosshair points with zero input lag for the client. ✅

### 🛡️ Task 2.2: Server-Authoritative Hit Verification Engine
- [x] **Network Listener:** `CombatService` listens to `SHOOT_GUN` via `Logger.wrapServerEvent`. Validates that the model is named "Zombie", is in workspace, and has a live Humanoid — invalid models are silently dropped.
- [ ] **Distance Validation:** Calculate the magnitude between the player's character position ($P$) and the reported hit target position ($T$):
  $$d = \|P - T\|$$
  Drop the request if $d$ exceeds the maximum range configured for that weapon.
- [ ] **Line-of-Sight (LoS) Validation:** Perform an independent server-side raycast from the player's head to the target position, ensuring solid walls aren't bypassed.
- [ ] **DoD Check:** An exploiter attempting to damage a zombie from across the map or through a solid stone wall has their network requests silently ignored.

### 🩸 Task 2.3: Modular Damage & Attribute Pipeline
- [x] **Damage Service:** `CombatService.resolveDamage` looks up damage by gun name from `Config.GUN_STATS`; `ZombieService.damageZombie` is the authoritative damage gate.
- [ ] **Critical Hit Multipliers:** Check the hit part's name; if `HitPart.Name == "Head"`, apply a headshot multiplier (e.g., $\times 2.0$).
- [x] **Health Modification:** `ZombieService.damageZombie` deducts from `Humanoid.Health` and returns `(killed, zombieType, deathPosition)`.
- [ ] **Client Feedback:** Fire a RemoteEvent back to the attacker containing the damage number and critical status to prompt a screen-space UI pop-up.
- [ ] **DoD Check:** Shooting a zombie in the torso deals base damage, while shooting it in the skull deals double damage and fires a critical hit visual indicator.

---

## 🧟 Phase 3: Zombie AI & Spatial Wave Loop

### 🧠 Task 3.1: High-Performance Zombie Navigation State Machine
- [x] **Distance Check Loop:** Per-zombie chase loop in `ZombieService` evaluates target player position each tick.
- [x] **Direct Chase Bypass:** `Humanoid:MoveTo(targetRoot.Position)` used for direct pursuit; `applyWallClimb` uses an upward raycast to assist over obstacles.
- [ ] **Pathfinding Fallback:** If obstructed by walls, compute paths using `PathfindingService:CreatePath()`.
- [ ] **Throttling Recomputations:** Only recompute pathfinding waypoints if the targeted player has moved more than 15 studs from their previous calculation point.
- [ ] **DoD Check:** 30+ zombies navigate a complex map layout chasing multiple moving players simultaneously without dropping server frame rates below 55 FPS.

### 📍 Task 3.2: Frustum-Aware Spatial Spawning Director
- [x] **Spawn Nodes:** Place invisible parts tagged as `Spawn_Mob` in ht tunnel for mobs to spawn on

### 🔄 Task 3.3: Global Wave Match Controller
- [x] **State Machine Infrastructure:** `WaveService.startBattle` runs the full wave loop per player: spawn → track kills → clear → next wave.
- [x] **Enemy Counter:** `Humanoid.Died` callbacks in `ZombieService` decrement the active zombie count; `runWave` awaits the counter reaching zero.
- [x] **Wave Transitions:** On wave clear, fires `WAVE_CLEAR` to client, waits `WAVE_BETWEEN_DELAY`, advances wave index, and loops. Player death ends the run and triggers `EconomyService.finalizeRun`.
- [x] **DoD Check:** Wave loop runs automatically — spawns enemies, detects when all die, pauses, then starts the next wave. ✅

---

## 👹 Phase 4: Multiplayer Mechanics & Boss Architecture

### 📊 Task 4.1: Algorithmic Dynamic Difficulty Scaler
- [ ] **Spawn Budget Formula:** Program the dynamic wave spawn budget ($B$) based on active player count ($P_c$) and current wave index ($W$):
  $$B = \text{BaseBudget} \times (1 + (W \times 0.15)) \times (1 + (P_c - 1) \times 0.4)$$
- [ ] **Health Scaling Formula:** Calculate the enemy max health multiplier ($H_m$):
  $$H_m = 1 + (W \times 0.1) + (P_c - 1) \times 0.25$$
- [ ] **Runtime Application:** Inject these calculated multipliers into every zombie entity configuration directly upon instantiation.
- [ ] **DoD Check:** Hordes scale dynamically; a 4-player lobby faces significantly larger and tougher waves than a solo player.

### 🚑 Task 4.2: Down-But-Not-Out (DBNO) System
- [ ] **Death Interception:** Hook into `Humanoid.HealthChanged`; at 0 health, force health to 1, assign an attribute `"IsDowned" = true`, and loop a crawling animation.
- [ ] **Revive Prompt:** Attach a `ProximityPrompt` to the downed player’s root part, configuring it to be visible only to teammates.
- [ ] **Interaction Logic:** If held for 4 seconds, clear the downed status, stop the animation, and restore their health to 40%.
- [ ] **Bleedout Timer:** Run a 45-second delay thread; if unrevived, call `:BreakJoints()` to officially eliminate the player for the remainder of the wave.
- [ ] **DoD Check:** Players reaching 0 health enter a down state where they can crawl and be saved by teammates before completely dying.

### 👑 Task 4.3: Modular Boss Ability State Machine
- [ ] **Boss Framework:** Construct a state controller for boss entities utilizing an internal coroutine tracker or module lookup table for custom attacks.
- [ ] **Ability 1 (Ground Slam):** Pause boss movement, play a telegraphed winding animation, check radii using `Workspace:OverlapParams`, apply 50 damage, and execute knockback using `LinearVelocity`.
- [ ] **Ability 2 (Enraged Charge):** Lock onto the furthest player, increase `Humanoid.WalkSpeed` by $+200\%$, and enable a forward-facing hitbox that flings contacted players.
- [ ] **Phase Shifting:** Intercept health updates; when the boss drops below $50\%$ health, swap its visual aura and permanently double its attack speed.
- [ ] **DoD Check:** The Wave 10 Boss dynamically switches between active abilities and noticeably scales up its aggression at half health.

---

## 💰 Phase 5: Economy, UX, & Performance Cleanup

### 💵 Task 5.1: Real-Time Cash/Point Dispatcher
- [ ] **Damage Tracking Dictionary:** Map a sub-dictionary tracking individual damage statistics per player for every active zombie instance (assist tracking not yet implemented).
- [x] **Payout Distribution:** `EconomyService.grantKillRewards` awards silver bolts and a gold roll to the killing player, scaled by `zombieType` and `waveNumber`.
- [x] **UI Synchronization:** `RUN_CURRENCY_UPDATED` remote fires to the client on every silver change, triggering the HUD silver label update in real time.
- [ ] **DoD Check:** Eliminating a zombie correctly splits cash indicators and updates balances across all contributing players in real time.

### 🛒 Task 5.2: In-Game Weapon Purchase Terminal
- [x] **Physical Terminal Models:** `ClerkInteractionModule` attaches a `ProximityPrompt` to the map's shop clerk NPC; fires `OPEN_GUN_SHOP` with live shop data to the triggering player.
- [x] **Transaction Verification:** `WaveService:Start()` handles `REQUEST_GUN_PURCHASE` — validates gun name, checks silver balance via `EconomyService.getRunSilver`, deducts via `EconomyService.spendSilver`, fires `GUN_PURCHASE_RESULT` back to client.
- [x] **Inventory Provisioning:** `LoadoutGrantModule.grant` securely clones the gun from `ServerStorage` and parents it into the player's `Backpack`.
- [x] **DoD Check:** Interacting with the clerk opens the shop UI; purchasing deducts silver and equips the chosen gun. ✅

### 🧹 Task 5.3: Aggressive Memory Garbage Collection
- [ ] **Collision Disabling:** Turn off corpse physics (`CanCollide = false`) immediately upon zombie death to protect player movement navigation.
- [ ] **Debris Queue:** Use the `Debris` service to queue dead zombie models for hard workspace removal exactly 5 seconds post-mortem: `Debris:AddItem(zombieModel, 5)`.
- [x] **Connection Cleanup:** `connectDeathCleanup` in `ZombieService` disconnects all touch connections on `Humanoid.Died`. `ZombieService.cleanupForPlayer` destroys all player-owned zombies on run end. Bolt pickup heartbeat and touch connections are explicitly disconnected on collect/despawn.
- [ ] **DoD Check:** Running long-duration endless wave diagnostic tests displays an entirely flat, non-leaking server memory footprint.