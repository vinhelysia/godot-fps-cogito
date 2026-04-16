---
name: tarkov-3d-csharp-pipeline
description: Build and iterate a Tarkov-like 3D extraction shooter in Godot 4.6+ using a C# + GDScript hybrid architecture. Use when designing or implementing raid flow, inventory and loot systems, weapon ballistics, AI squads, extraction zones, persistence, multiplayer authority, and performance profiling for tactical shooters.
---

# Tarkov 3D C# Pipeline

Use this skill to produce practical implementation plans and code scaffolding for a hardcore extraction shooter in Godot.

## Read First
1. Treat version facts in this file as reviewed on `2026-02-25`.
2. If the user asks for "latest", re-check the cited links before finalizing.

## Technical Baseline
- Prefer Godot `4.6.x` stable unless the user pins another version.
- Use the `.NET` build of Godot when C# is required.
- Require `.NET SDK 8+` for desktop builds.
- If Android export is required with C#, require `.NET 9+`.
- Do not promise C# web export support.

## C# vs GDScript Contract
Use C# for:
- Ballistics simulation, penetration math, and recoil spread generation.
- Data-heavy inventory/stash logic and serialization.
- AI perception, threat scoring, squad coordination.
- Multiplayer authority checks and anti-cheat validation.
- Performance-critical loops executed every frame or physics tick.

Use GDScript for:
- Scene orchestration, extraction triggers, quest flow.
- UI/HUD and inventory presentation logic.
- Audio and animation event wiring.
- Rapid iteration on non-critical gameplay glue.

## Project Layout
```text
res://
  src/                  # C# systems
    Core/
    Raid/
    Combat/
    Inventory/
    AI/
    Network/
    Save/
  scripts/              # GDScript scene glue
    player/
    ui/
    world/
    audio/
  scenes/
    raid/
    player/
    enemies/
    ui/
  resources/
    items/
    weapons/
    loot_tables/
```

## Delivery Workflow
1. Scope
- Confirm target: single-player first or networked from day one.
- Confirm win condition: extraction loop, economy, or combat feel priority.

2. Slice plan
- Build vertical slices in this order:
  1. Playable movement + gunfeel sandbox.
  2. Loot container + grid inventory.
  3. One extraction flow with timer and fail states.
  4. Enemy AI patrol, detect, engage, disengage.
  5. Raid summary + persistence between raids.
  6. Optional multiplayer authority pass.

3. System decisions
- For each requested feature, declare:
  - Main language (`C#` or `GDScript`).
  - Data model owner.
  - Performance budget (frame-time target and update frequency).
  - Test strategy.

4. Implementation output
- Always provide:
  - File tree with concrete paths.
  - Minimal runnable code for changed files.
  - Node setup and signal wiring notes.
  - Profiling checkpoints and acceptance criteria.

## Multiplayer Guardrails
- Use SceneTree multiplayer API as the default entry point.
- Use RPC annotations/attributes consistently on both sides.
- Keep server-authoritative inventory, damage, loot claims, and extraction state.
- Avoid synchronizing Object/Resource references directly through MultiplayerSynchronizer.
- Use stable IDs and replicated plain data structs instead.

## Performance Guardrails
- Keep gameplay movement and combat logic in `_physics_process` when interpolation is enabled.
- Use `reset_physics_interpolation()` after teleports or hard position corrections.
- Use MultiMesh or server-level APIs for large repeated world props.
- Avoid scene-tree writes from worker threads; queue deferred operations on main thread.
- Run ray query-heavy systems in `_physics_process`, not `_input`.

## Internet Research Notes (Reviewed 2026-02-25)

### Engine and release status
- Godot `4.6.1-stable` is listed as released on **2026-02-16**.
- Godot `4.6-stable` is listed as released on **2026-01-26**.
- Godot `4.7-dev1` is a development build (not production baseline).
- Release policy marks `4.6` as supported and `4.7` as development.

### C# and .NET constraints
- The standard editor build does not include C#; use the `.NET` build.
- Godot C# basics state: `.NET 8+` required; Android C# export requires `.NET 9+`.
- C# projects currently cannot be exported to web.
- C# API naming is `PascalCase`; string-based calls still use Godot `snake_case` names.

### Cross-language interop
- Mixing C# and GDScript in one project is supported.
- Connecting from C# to GDScript-defined signals requires `Connect()`.
- Cross-language inheritance is not supported.

### Multiplayer facts for extraction shooters
- High-level multiplayer is managed by `SceneTree` and `MultiplayerAPI`.
- Server peer ID is always `1`.
- RPC methods must be explicitly annotated (`@rpc` / `[Rpc]`).
- `ENetMultiplayerPeer` uses UDP.
- `MultiplayerSynchronizer` cannot sync `Object`-type properties (for example `Resource`) or peer-unique IDs/RIDs.

### Navigation, physics, and timing constraints
- NavigationServer batches updates and syncs at the end of physics frames.
- During `_input()`, physics space may be locked; run ray queries in `_physics_process()`.
- Scene tree interaction is not thread-safe; use deferred calls across thread boundaries.
- Interpolation guidance: move gameplay logic to `_physics_process()` and call `reset_physics_interpolation()` on teleports.
- Interpolation can increase input lag; adjust physics tick configuration.

### Performance approaches for dense 3D raids
- MultiMesh can drastically reduce draw-call overhead for repeated geometry.
- MultiMesh tradeoff: no per-instance frustum culling (all-or-none visibility behavior).
- Server-level APIs can bypass scene-node overhead for bottlenecked systems.

### Practical community references
Use these as starter references, not authoritative engine behavior:
- https://github.com/godotengine/godot-demo-projects
- https://github.com/Whimfoome/godot-FirstPersonStarter
- https://github.com/Dodoveloper/godot4-fps-prototype
- https://github.com/alpapaydin/Godot-4-Grid-Inventory-with-Patterns
- https://github.com/chickensoft-games/GameDemo
- https://github.com/devmoreir4/godot-3d-multiplayer-template

### Sources
- https://godotengine.org/download/archive/
- https://docs.godotengine.org/en/stable/about/release_policy.html
- https://godotengine.org/article/maintenance-release-godot-4-6-1/
- https://godotengine.org/releases/4.6/
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/cross_language_scripting.html
- https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html
- https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationservers.html
- https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html
- https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html
- https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html
- https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html
- https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html

## Output Template
When responding with this skill, end with:
1. What was implemented now.
2. What to profile next.
3. The next 3 tasks for the user to approve.
