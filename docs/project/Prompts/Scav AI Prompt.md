# Scav AI Prompt (→ Sonnet)

> Quay về [[🎯 Project Index]] · nền tảng kỹ thuật ở [[Architecture]] · vị trí trong kế hoạch ở [[Roadmap]] (Phase 1)

Prompt build enemy đầu tiên (scav) cho extraction shooter. Đã nhúng sẵn các phát hiện về NPC system để Sonnet không dò lại sai.

## TL;DR findings (chi tiết ở [[Architecture]])
- Base `cogito_npc.tscn` có sẵn nav/anim/SM/hitbox/health/detection — phần lớn scav đã tồn tại.
- **3 gap thật:** (1) detection→chase chưa wire, (2) attack là melee → cần ranged shoot state, (3) chưa có loot-on-death + navmesh trong map.
- Damage IN đã chạy; death+loot có sẵn qua `CogitoHealthAttribute.death` + `LootComponent`.

## Full prompt

```text
# Task: Build the first hostile "Scav" enemy AI for a single-player extraction shooter (Godot 4.6 / Cogito)

## ⚡ READ FIRST (before scanning the repo)
Read these in-repo knowledge files to orient — they save you from re-scanning the whole codebase:
- `docs/project/Codebase Map.md` — index of autoloads, input actions, every Scripts/*.gd (class_name/funcs), cogito class table, scene roots.
- `docs/project/Architecture.md` — esp. the "NPC / AI system" section: state machine API, chase state (reusable), attack is MELEE, detection->chase NOT wired, damage in/out, death+loot, known base bugs.
Then read ONLY the specific files you will edit. The map is a snapshot — verify any path/func/line against the live file before editing.

## Project
- Godot project root: C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/ (project.godot here; all res:// map here). Engine: Godot 4.6.
- Genre/goal: Tarkov-like extraction shooter, SP first. This task adds the FIRST working hostile enemy so combat systems finally have a target. Scope = a playable vertical-slice scav: patrols, detects the player by line-of-sight, chases, SHOOTS from range, can be killed, and DROPS LOOT on death.

## Hard rules
- COGITO BOUNDARY: prefer PROJECT-LOCAL extensions under Scripts/ and Scene/. Do NOT edit files in addons/cogito/ unless there is no project-local path; if you must, keep the edit minimal and call it out explicitly in your summary.
- Typed GDScript, signals over polling where reasonable. Parse-check every script.
- Do NOT break the existing addons/cogito/CogitoNPC/cogito_npc.tscn demo.
- Verify my architecture notes below against the real code before relying on them.

## Architecture facts (already investigated — verify before trusting)
Base enemy = addons/cogito/CogitoNPC/cogito_npc.tscn, script cogito_npc.gd (class_name CogitoNPC extends CharacterBody3D). Scene already has: NavigationAgent3D, AnimationTree+AnimationPlayer, CollisionShape3D, FootstepPlayer, alert indicator, LookAtModifier3D, NPC_State_Machine (states: idle, move_to_random_pos, patrol_on_path, switch_stance, chase, attack), HitboxComponent (+CogitoHealthAttribute), SecurityCamera (Area3D+RayCast = perception).

State machine API (npc_state_machine.gd): states are child Nodes; only the current state is mounted so it receives _physics_process. States implement _state_enter(args), _state_exit(), _physics_process(delta). SM injects Host (the CogitoNPC) and States (the SM). Transition with States.goto("name"[, args]); load_previous_state(); save_state_as_previous(name).

chase state (npc_state_chase.gd) is REUSABLE: reads Host.attention_target, navigates to it, when within target_action_distance calls States.goto(action_when_caught) (default "attack"). Has give-up timer.

attack state (npc_state_attack.gd) is MELEE (RaisedFists anim, range <=1.5, target.decrease_attribute("health", attack_damage)). DO NOT use for a scav — build a ranged shoot state instead.

Damage IN (player -> scav): player hitscan calls Weapon_Resource._deal_damage -> collider.damage_received.emit(dmg, dir, pos); projectiles set damage_amount. HitboxComponent listens to parent's damage_received and calls health_attribute.subtract(). Works if scav has damage_received signal (CogitoNPC has it) + HitboxComponent + CogitoHealthAttribute (demo scene has these).

Damage OUT (scav -> player): CogitoPlayer (group "Player") exposes take_damage(amount), decrease_attribute("health", value), apply_external_force(vec). Player head node = $Body/Neck/Head (aim at torso/head, not feet).

Death + loot: CogitoHealthAttribute emits signal death() at 0 HP. Components/LootComponent.gd monitors a health attribute's death signal and spawns loot (SPAWN_ITEM or SPAWN_CONTAINER) from a LootTable. Ragdoll scene: addons/cogito/CogitoNPC/mannequin_ragdoll.tscn.

KNOWN BASE BUGS (do not depend on them):
1. Detection -> chase is NOT wired anywhere: goto("chase") exists in NO file. _on_security_camera_object_detected only sets attention_target; nothing transitions the SM into chase. YOU must wire this.
2. cogito_security_camera.gd::stop_detecting() uses self.get_parent() == CogitoNPC (compares instance to class — always false), so attention_target is never cleared by it. Clear/lose target robustly yourself.
3. SecurityCamera emits both object_detected (no arg) and send_detected_object(obj); connect to the one that passes the object.

## DELIVERABLES
1. Scav scene (project-local): Scene/Enemies/Scav.tscn based on CogitoNPC structure (inherit/instance cogito_npc.tscn or compose a CharacterBody3D reusing it) so it gets nav/anim/SM/hitbox/health/detection. Configure: CogitoHealthAttribute HP ~60-100; add a LootComponent wired to the scav's health attribute (health_component_to_monitor) with a small LootTable (ammo + a low-value item), SPAWN_CONTAINER recommended; a muzzle Marker3D (%Muzzle) for the shoot origin; collision layers/masks so player hitscan/projectiles hit it and its LOS ray hits world+player.

2. Wire perception -> chase (fix gap #1): project-local (small scav.gd extending CogitoNPC, or a perception helper). When SecurityCamera detects the player and sets attention_target, if current state is idle/patrol_on_path/move_to_random_pos call States.goto("chase"). When target lost (no LOS for N sec / out of range), clear attention_target and return to patrol. Reuse the SecurityCamera Area3D+RayCast for LOS; tune range/FOV. (Optional: replace with a cleaner vision cone — document it.)

3. New RANGED shoot state (project-local): Scripts/Enemies/States/npc_state_shoot.gd, added as a shoot child of the scav's NPC_State_Machine. Set chase action_when_caught = "shoot" and chase target_action_distance suited to a shooter (~8-15 m). Shoot state must: on enter cache attention_target (null -> load_previous_state); each tick face target, if too far / LOS blocked go back to chase, if lost return to patrol; fire on a cadence (fire_rate) only when LOS clear (raycast muzzle->player head, mask world+player, abort if wall hit first); apply damage via player.take_damage(damage) or decrease_attribute("health", damage) with accuracy/spread so it isn't a laser; optional tracer/muzzle flash + reload pause (keep damage application direct/reliable). Export tunables: fire_rate, damage, accuracy, min_engage_range, max_engage_range, reload_time, burst_count.

4. Death handling: on CogitoHealthAttribute.death stop the SM / disable AI, stop collision with player, play death anim or swap to mannequin_ragdoll.tscn, let LootComponent spawn loot. Dead scav can't shoot.

5. Make it playable: add ONE scav to a reachable scene (Town.tscn or new graybox Scene/Enemies/ScavTest.tscn). Add a NavigationRegion3D with a BAKED NavigationMesh over the floor (without it the scav won't path). Add a CogitoPatrolPath (2-3 points) assigned to the scav's patrol_path.

6. Tuning: expose detection range/FOV, HP, fire_rate, damage, accuracy, give-up time as @export. Reasonable starting values for a readable, fair fight.

## ACCEPTANCE CRITERIA
- Scav patrols when player unseen.
- On LOS to player, alerts and switches to chase (no detection through walls).
- Closes to engagement range, SHOOTS dealing visible health damage, misses sometimes per accuracy.
- Player can kill it with existing weapons; on death it stops fighting and DROPS a lootable bag/container the player can open.
- If it loses the player (LOS blocked / out of range for give-up time), stops chasing and returns to patrol.
- No regressions to the cogito_npc demo; all scripts parse.

## REPORTING
- List every file created/changed and why. Flag ANY edit inside addons/cogito and justify.
- State assumptions (HP, damage, ranges) and how to tune.
- Note anything not verifiable at runtime (editor may be closed).
```

## Sau khi Sonnet xong
- [ ] Review diff (như đã làm với Antigravity — check gap wiring, project-local boundary, parse).
- [ ] Commit riêng (đừng `git add -A` gộp WIP).
- [ ] Cập nhật [[Dev Log]].
