# Cogito Multiplayer Integration — Phase & Chunk Roadmap

Each `##` section is a **self-contained prompt** you can paste into a fresh Claude Code session. Each assumes the project root is `D:\Godot\FPS\godot-fps-cogito-master\` and that `CLAUDE.md` has already briefed the agent on project structure.

---

## Completed (reference only — do NOT re-do)

- **Phase 0**: Standalone ENet prototype in `Scene/Multiplayer/Test/`
- **Phase 1 Step 1**: `MPNetworkManager` autoload (ENet lifecycle)
- **Phase 1 Step 2**: Player spawn + `set_multiplayer_authority()` per peer
- **Phase 1 Step 3A**: Input routing — `is_multiplayer_authority()` guards on `_physics_process` / `_unhandled_input`
- **Phase 1 Step 3B**: `MultiplayerSynchronizer` replicating `global_position` / `rotation` / `health`
- **Phase 1 Step 3C**: `TPPWeaponMount` under Body, `current_tpp_weapon_path: String` replicated, spawns `tpp_weapon_scene` on remote
- **Phase 1 Step 3D**: Remote fire FX — `RemoteWeaponFxAnchor` in each `*_Drop.tscn`, `rpc_play_remote_fire_fx()` in `cogito_player.gd`, world-space muzzle flash + 3D audio + shell casings
- **Phase 1 Projectile damage**: Server-authoritative hit via `cogito_projectile.gd` + RPC'd `take_damage`

---

## Phase 1 — Step 4: Player Name Tags + Floating Health Bar

**Goal**: Every remote player has a name label and health bar floating above their head, visible only to non-authority peers (you don't see your own).

**Files to create**:
- `Scripts/Multiplayer/PlayerNameTag.gd` + `Scene/Multiplayer/PlayerNameTag.tscn` (Label3D + SubViewport-based health bar OR Sprite3D with shader)

**Files to modify**:
- `addons/cogito/CogitoObjects/cogito_player.tscn` — add `NameTagMount` Node3D above head
- `addons/cogito/CogitoObjects/cogito_player.gd`:
  - `@export var player_display_name: String` (synced via `MultiplayerSynchronizer`, falls back to `"Player_%d" % peer_id`)
  - `_ready()`: spawn `PlayerNameTag.tscn` under `NameTagMount`, set `visible = not is_multiplayer_authority()`
  - In `rpc_sync_health()` or the existing health setter, emit a signal the name tag listens to

**PlayerNameTag.gd responsibilities**:
- Billboard-face the local camera every frame (`Label3D.billboard = BILLBOARD_ENABLED`)
- Draw health bar as a `TextureProgressBar` inside a `SubViewport` rendered to a `Sprite3D`, OR use a Label3D with a custom shader, OR two Sprite3D's (background + foreground scaled by health ratio)
- Exposes `set_player_name(s: String)` and `set_health(cur: int, max_: int)`

**Acceptance**:
- [ ] Join with 2 peers, see each other's labels
- [ ] Damage a remote peer — their health bar shrinks in real time on your screen
- [ ] Your own label is NOT visible to yourself
- [ ] Labels stay legible at 2–50 m distances (scale with distance if needed)

**Gotchas**: `Label3D.no_depth_test = true` so it renders over walls if desired. Use `fixed_size = true` + `pixel_size` tuning so text doesn't get microscopic far away.

---

## Phase 1 — Step 5: Self HUD Health Bar

**Goal**: The local player sees their own health on the HUD, updating when remote shots hit them.

**Files to inspect**:
- `addons/cogito/PlayerHudComponent/player_hud_manager.gd` (likely already has a health widget for single-player)
- `addons/cogito/Components/HealthAttribute.gd`

**Files to modify**:
- `cogito_player.gd`: when `rpc_sync_health()` runs on the authority, route the value into the existing Cogito `HealthAttribute` via `set_attribute_value()` so the existing HUD widget picks it up automatically
- OR: add a separate `MPHealthHUD.tscn` that listens to a signal from `cogito_player` directly

**Acceptance**:
- [ ] Start match at 100 HP, number shown on HUD
- [ ] Remote player shoots you → HUD drops immediately (no 1-frame desync)
- [ ] Respawn resets HUD to 100

**Key constraint**: Don't double-apply damage locally. Server is authority — damage flows only through the RPC path, never from client-side raycast.

---

## Phase 1 — Step 6: Hit Markers + Damage Numbers

**Goal**: When YOU hit a remote player, a brief crosshair flash + floating damage number appears.

**Files to create**:
- `Scripts/Multiplayer/HitMarkerHUD.gd` + scene (crosshair overlay with tween-driven alpha pulse)
- `Scripts/Multiplayer/DamageNumber3D.gd` + scene (Label3D that spawns at hit location, tweens up + fades out over ~0.8s)

**Files to modify**:
- `Scripts/Weapons/cogito_projectile.gd` (server-side hit resolver):
  - After `take_damage.rpc(...)`, also call back to shooter: `shooter.rpc_id(shooter_peer, "rpc_on_hit_confirmed", damage, hit_position)`
- `cogito_player.gd`:
  - `@rpc("authority", "call_local", "unreliable_ordered") func rpc_on_hit_confirmed(damage: int, hit_pos: Vector3)`
  - On call: if `is_multiplayer_authority()` (shooter), trigger HUD flash + spawn damage number at `hit_pos`

**Acceptance**:
- [ ] Headshots (if supported) show different color damage number
- [ ] Crosshair flashes red for ~0.1s per confirmed hit
- [ ] Damage numbers spawn in world space, float up, fade out
- [ ] Only visible to the shooter, not to other peers

**Gotchas**: `unreliable_ordered` is fine — it's cosmetic feedback. Don't use `reliable` because dropped hit markers are invisible to the player anyway.

---

## Phase 1 — Step 7: Kill Feed + Scoreboard

**Goal**: Corner feed ("Alice killed Bob with AK47"), Tab-held scoreboard with K/D per peer.

**Files to create**:
- `Scripts/Multiplayer/KillFeedHUD.gd` + scene (Control with VBoxContainer, max 5 entries, entries fade after 5s)
- `Scripts/Multiplayer/ScoreboardHUD.gd` + scene (Tab-held overlay, rows per peer)
- `Scripts/Multiplayer/MatchStats.gd` (autoload OR `MPNetworkManager` extension) — tracks `{peer_id: {kills: int, deaths: int, name: String}}`

**Files to modify**:
- `cogito_player.gd`:
  - In death handler: `MPNetworkManager.rpc_broadcast_kill(killer_id, victim_id, weapon_name)`
- `MPNetworkManager.gd`:
  - `@rpc("any_peer", "call_local", "reliable") func rpc_broadcast_kill(killer: int, victim: int, weapon: String)`
  - Updates local `MatchStats`, emits `kill_registered` signal
  - KillFeedHUD + ScoreboardHUD listen to the signal
- `project.godot`: add input action `scoreboard` → Tab key

**Acceptance**:
- [ ] Kill someone → feed entry appears on all peers
- [ ] Hold Tab → scoreboard shows sorted by kills
- [ ] Self-damage death shows "Alice killed themselves"
- [ ] Entries disappear after 5s

---

## Phase 1 — Step 8: Remote Footstep Audio

**Goal**: When a remote player walks, you hear their footsteps 3D-positioned.

**Approach**: Mirror the Step 3D fire-audio pattern — authority emits an RPC on each footstep, remotes spawn a short AudioStreamPlayer3D in world-space at the player's position.

**Files to modify**:
- `addons/cogito/CogitoObjects/cogito_player.gd`:
  - Add footstep timer that ticks based on speed (e.g. `step_interval = 0.45 / (velocity.length() / WALK_SPEED)`)
  - `@rpc("any_peer", "call_local", "unreliable") func rpc_play_footstep(surface: int)` — surface enum for picking the right sound
  - Authority-side: when step timer elapses AND `is_on_floor()` AND `velocity.length() > 0.5`, call `rpc_play_footstep.rpc()`
  - Remote-side: if `is_multiplayer_authority()` return (authority hears their own via Cogito's existing system); else spawn `AudioStreamPlayer3D` at `global_position`, play the right sound, `finished.connect(queue_free)`

**Acceptance**:
- [ ] Walk within 15 m of remote player, clearly hear their steps
- [ ] Running produces faster step cadence than walking
- [ ] Sprinting even faster
- [ ] Crouching produces softer / no sound
- [ ] You don't hear your own steps doubled (Cogito already plays them locally)

**Constraint**: `unreliable` RPC — dropping a single footstep is imperceptible, reliable would waste bandwidth.

---

## Phase 1 — Step 9: Death & Respawn Polish

**Goal**: Proper death camera, respawn countdown, killer name shown, respawn spot selection avoids spawn-camping.

**Files to modify**:
- `addons/cogito/CogitoObjects/cogito_death_screen.gd` (or create MP variant)
- `addons/cogito/CogitoObjects/cogito_player.gd`:
  - On death: disable input, switch camera to spectate killer for 3s, then spawn countdown (3-2-1)
  - Pick spawn point furthest from nearest enemy (not random)

**Acceptance**:
- [ ] Die → camera smoothly moves to killer's over-shoulder
- [ ] Label shows "Killed by Alice"
- [ ] 3-second countdown, then respawn
- [ ] Respawn point is always ≥ 15 m from nearest enemy
- [ ] Brief invuln (1s) on respawn

---

## Phase 2 — Client-Side Prediction & Reconciliation

**Scope**: Currently movement is "client-authority-over-self" — simple but cheat-vulnerable. This phase moves to server-authoritative movement with client prediction.

### Step 1: Input Buffering
- Client records each `_physics_process` input as `{tick: int, input_vec: Vector2, jump: bool, fire: bool}` into a ring buffer
- Client sends unreliable RPC `rpc_input_to_server(tick, input)` every physics tick
- Server stores last N inputs per peer (N = 60, ~1s at 60 Hz)

### Step 2: Server Simulation
- Server runs `_physics_process` for each peer's character using their buffered input
- Server broadcasts authoritative state (`{tick, position, velocity, rotation}`) to all peers at 20 Hz

### Step 3: Client Reconciliation
- Client also runs `_physics_process` locally (prediction) using own input
- When server snapshot arrives with `tick = T`, rewind to tick T, apply server's state, re-run inputs T+1 .. current
- If delta < threshold, smooth via exponential lerp; else hard snap

### Step 4: Weapon Fire Prediction
- Client plays muzzle flash / sound immediately on fire
- Server validates (ammo, cooldown, LOS) and broadcasts authoritative result
- If server rejects, client un-plays effects + shows "desync" feedback

**Reference**: Valve's Source Engine net code paper, Gaffer On Games "Networked Physics" series.

---

## Phase 3 — Lag Compensation (Hit Rewind)

**Scope**: Server records all player positions per tick. When a client shoots, server rewinds world to the tick the client saw when firing, performs the hit test there, then forwards the result.

### Step 1: Position History Ring Buffer
- Server stores `{tick: {peer_id: Transform3D}}` for the last 1 second

### Step 2: Rewound Hit Test
- `cogito_projectile.gd` on server:
  - Receives `rpc_fire_request(tick_seen, origin, forward)`
  - Temporarily teleports all players to their positions at `tick_seen`
  - Runs raycast / physics query
  - Restores positions
  - Applies damage to rewound-hit target

### Step 3: Bounds & Cheat Mitigation
- Clamp rewind to 200 ms max (prevents exploits)
- Reject if `tick_seen` is farther than that from current server tick

**Gotchas**: Raycast against rewound state is read-only — don't move actual players, move copies in a physics subworld OR temporarily set transforms and immediately restore (single-frame, no physics step in between).

---

## Phase 4 — Dedicated Server Build

**Scope**: Headless Godot export that runs without a display, exposes CLI args, auto-restarts on crash.

### Step 1: Export Preset
- Add "Linux Server" + "Windows Server" export presets with `--headless` default feature
- Strip client-only assets (shaders, UI themes, particles can stay but aren't rendered)

### Step 2: CLI Arg Parsing
- `MPNetworkManager` autoload: if `--server` flag present, auto-host on startup
- Args: `--port 7777`, `--max-players 16`, `--map default_arena`

### Step 3: Logging + Metrics
- File logger rotating daily
- Export Prometheus-style metrics on `/metrics` endpoint (optional)

### Step 4: Crash Recovery
- Bash / PowerShell wrapper script that restarts the server if it exits non-zero
- State snapshot to disk every 30s so crashes don't lose match state

---

## Phase 5 — Ship Polish

- **Anti-cheat basics**: speed hack detection (velocity sanity check), rate-limit RPCs per peer, server-side weapon cooldown validation
- **Server browser / matchmaking**: central list server (simple Flask + SQLite), clients query + join by IP
- **NAT traversal**: `ENetMultiplayerPeer.use_encryption = true` + DTLS; fallback to TURN relay for symmetric NAT
- **Persistent accounts**: optional — Steam auth, Epic auth, or custom OAuth
- **Replays**: record all RPCs + authoritative snapshots, playback via headless client

---

## How to use these prompts

1. Pick a phase/step.
2. Copy the `##` section verbatim into a fresh Claude Code session.
3. Agent has full context from `CLAUDE.md` + the step's explicit file list + acceptance criteria.
4. Verify each acceptance checkbox manually in-editor before closing the step.
5. Commit with message `feat(mp): Phase N Step M — <short description>`.
