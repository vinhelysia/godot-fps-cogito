# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Claude Code guide for D:\Godot\FPS

Use this file as the root operating prompt for Claude Code in this workspace.

## Workspace reality

- The workspace root is `D:\Godot\FPS`.
- The active Godot project root is `D:\Godot\FPS\godot-fps-cogito-master`.
- Godot MCP reports `project_path = D:/Godot/FPS/godot-fps-cogito-master/`.
- Treat every `res://...` path as mapping into `godot-fps-cogito-master`, not the workspace root.
- If workspace-root folders and `res://` paths disagree, trust `res://` and `project.godot`.

## Core rules

- Inspect the repository before patching.
- Read `.tscn`, `.gd`, and `.tres` together when behavior is spread across scenes and resources.
- Use Godot MCP Pro to inspect editor state, scene structure, runtime state, and validation.
- Prefer project-local extensions over editing `addons/cogito`.
- Keep diffs narrow and verify changed behavior.
- Never invent node paths, autoload names, input actions, or resource chains.
- Use `uid_to_project_path` when Godot returns `uid://...` values.

## User-specific rules

- Do not edit files by default unless the user explicitly asks or the edit is clearly necessary.
- `.html`, `.tex`, and `.gd` files may be edited when needed.
- Never edit `addons/cogito` unless the user explicitly asks or there is no safe project-local extension path.
- Use Godot MCP Pro to inspect and teach, not only to patch.
- When the user asks to explain source code, explain in detailed Vietnamese.
- Keep technical terms in English: `node`, `signal`, `autoload`, `singleton`, `resource`, `shader`, `state machine`, `collision layer`, `PackedScene`, `SubViewport`, and similar terms should stay in English.

## First-pass inspection order

1. Read `res://project.godot`.
2. Read `res://Scene/Town.tscn` because it is the current main scene.
3. Inspect `res://addons/cogito` to understand framework boundaries before changing gameplay code.
4. Read the target `.tscn` with its attached `.gd` scripts and linked `.tres` resources together.
5. Check autoloads, input actions, and scene dependencies before making assumptions.

## Actual project structure

### Main scene

- Main scene: `res://Scene/Town.tscn`
- Root node: `Town`
- Root script: `res://addons/cogito/SceneManagement/cogito_scene.gd`
- `Town.tscn` is mostly a composition scene. It instances Cogito systems plus project content.
- Important instances in `Town.tscn`:
  - `Player` -> `res://addons/cogito/PackedScenes/cogito_player.tscn`
  - `House1` -> `res://Scene/Object/House1.tscn`
  - grouped AK-47 ammo + pickup under `Pickup1`
  - several `7.62x51mm_Item` pickups
  - a standalone M700 pickup scene

### Addon-owned framework layer

Treat these as framework or tool layers unless the user explicitly asks to edit them:

- `res://addons/cogito/`
- `res://addons/godot_mcp/`
- `res://addons/input_helper/`
- `res://addons/quick_audio/`

Important autoloads currently enabled:

- `Audio` -> `res://addons/quick_audio/Audio.gd`
- `CogitoGlobals` -> `res://addons/cogito/cogito_globals.gd`
- `CogitoQuestManager` -> `res://addons/cogito/QuestSystem/cogito_quest_manager.gd`
- `CogitoSceneManager` -> `res://addons/cogito/SceneManagement/cogito_scene_manager.gd`
- `InputHelper` -> `res://addons/input_helper/input_helper.gd`
- `MenuTemplateManager` -> `res://addons/cogito/EasyMenus/Nodes/menu_template_manager.tscn`
- `MCPGameInspector` -> `res://addons/godot_mcp/mcp_game_inspector_service.gd`
- `MCPInputService` -> `res://addons/godot_mcp/mcp_input_service.gd`
- `MCPScreenshot` -> `res://addons/godot_mcp/mcp_screenshot_service.gd`

### Project-local gameplay layer

Project-local gameplay logic is concentrated here:

- `res://Scripts/Weapons/cogito_weapon.gd`
  - Main adapter that bridges project weapon resources into Cogito's `CogitoWieldable` flow.
  - Expects `%Bullet_Point`, `AnimationPlayer`, and `AudioStreamPlayer3D` in each weapon scene.
  - Talks to player-side nodes such as `Body/Neck/Head/CameraRecoil` and `Body/Neck/Head/WeaponCameraAnimator` if they exist.
- `res://Scripts/Weapons/Weapon_Resource.gd`
  - Base `Resource` for weapon data.
- `res://Scripts/Weapons/Types/*.gd`
  - Type-specific weapon resources such as `AssaultRifle_Resource`, `BoltAction_Resource`, `Shotgun_Resource`, and others.
- `res://Scripts/Weapons/scope_controller.gd`
  - Controls magnification, reticle mode, shader parameters, and the scope `SubViewport` camera.
  - Relies on node names like `$Scope`, `$Scope/Camera3D`, and `$MeshInstance3D` inside the scope scene.
- `res://Scripts/Weapons/weapon_recoil.gd`
  - Referenced by `res://addons/cogito/PackedScenes/cogito_player.tscn`.
- `res://Scripts/Weapons/shell_casing_fx.gd`
  - Shell casing ejection visual effect.
- `res://Scripts/Weapons/Helpers/`
  - Helper utilities shared across weapon types. Check this folder before duplicating weapon logic.
- `res://Scripts/Weapons/weapon_camera_animator.gd`
  - Present in the project, but no static scene reference was found. Verify runtime usage before assuming it is active.
- `res://Scripts/Weapons/camera_shake.gd`
  - Present in the project, but no static scene reference was found.
- `res://Scripts/Player/player_interaction_component_delayed_reload.gd`
  - Present in the project, but no static scene reference was found.

### Content folders

These are the main project-owned content locations:

- `res://Scene/Object/` for map props and structures such as `House1.tscn`
- `res://Scene/Items/Bullets/` for ammo pickup scenes
- `res://Scene/Attachment/Scope/` for optic attachments and scope scenes
- `res://Scene/Weapom/Firearms/` for firearm content
- `res://Scene/Weapom/BulletProjectil&shelle/` for projectile and shell scenes
- `res://Assets/` for imported meshes and SFX used by project-owned content

## Weapon architecture

Do not treat weapons as a single file feature. The actual chain is usually:

1. pickup scene
2. wieldable item `.tres`
3. wieldable weapon scene `.tscn`
4. weapon data `.tres`
5. projectile scene or hitscan behavior
6. optional attachment scenes such as scopes

Current examples:

- AK-47 chain:
  - `res://Scene/Weapom/Firearms/AR/AK47/pickup_ak47.tscn`
  - `res://Scene/Weapom/Firearms/AR/AK47/Ak-47_Wieldable.tres`
  - `res://Scene/Weapom/Firearms/AR/AK47/AK47.tscn`
  - `res://Scene/Weapom/Firearms/AR/AK47/AK47.tres`
  - `res://Scene/Weapom/BulletProjectil&shelle/7.62x39/7.62x39 projectile.tscn`
- M700 chain:
  - `res://Scene/Weapom/Firearms/Bolt-action/M700/pickup_m700.tscn`
  - `res://Scene/Weapom/Firearms/Bolt-action/M700/M700_Wieldable.tres`
  - `res://Scene/Weapom/Firearms/Bolt-action/M700/m700.tscn`
  - `res://Scene/Weapom/Firearms/Bolt-action/M700/M700.tres`
  - `res://Scene/Weapom/BulletProjectil&shelle/7.62x51/7.62x51 projectile.tscn`
  - `res://Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_1-4x24_riflescope.tscn`

When changing weapon behavior, inspect the whole chain before patching.

## Input actions to verify before gameplay changes

High-value project actions from `project.godot` include:

- movement: `forward`, `back`, `left`, `right`, `jump`, `sprint`, `crouch`, `free_look`
- interaction: `interact`, `interact2`, `reload`, `inventory`, `inventory_drop_item`
- combat: `action_primary`, `action_secondary`
- quickslots: `quickslot_1`, `quickslot_2`, `quickslot_3`, `quickslot_4`, `quickslot_next_wieldable`, `quickslot_prev_wieldable`

Always confirm the actual binding in `project.godot` before changing input-sensitive behavior.

## Naming traps and assumptions to avoid

- The folder is named `Weapom`, not `Weapon`.
- The folder is named `BulletProjectil&shelle`, not `BulletProjectileShell`.
- `Town.tscn` includes a standalone M700 pickup whose instantiated node name appears as `Pickup_AK47`; do not assume node names are semantically correct.
- Use scene paths, script paths, and scene dependencies as source of truth when names look copied or inconsistent.
- Because `cogito_weapon.gd` looks for `WeaponCameraAnimator`, confirm whether that node actually exists before modifying equip or reload camera motion logic.

## Godot MCP Pro workflow

Use MCP as an inspection and verification layer, not a replacement for repository reading.

- Use `get_scene_dependencies`, `read_script`, `read_resource`, and `get_scene_file_content` to trace scene-resource-script wiring.
- Use `open_scene` plus `get_scene_tree` for editor hierarchy inspection.
- Use `play_scene`, `get_game_scene_tree`, `get_game_node_properties`, screenshots, and assertions for runtime validation.
- Editor scene paths include editor wrapper nodes; for live runtime node paths, use `get_game_scene_tree` after playing the scene.

## Prompt routing

If the task matches one of these categories, load the matching file from the skill references directory:

- visual issues -> `.agents/skills/godot-mcp-pro-cogito-agents/references/visual-qa.md`
- scene hierarchy, transforms, collision, cameras, ownership -> `.agents/skills/godot-mcp-pro-cogito-agents/references/scene-debugger.md`
- gameplay bugs or feature work -> `.agents/skills/godot-mcp-pro-cogito-agents/references/gameplay-fixer.md`
- content integration and level wiring -> `.agents/skills/godot-mcp-pro-cogito-agents/references/level-integrator.md`
- regression or smoke testing -> `.agents/skills/godot-mcp-pro-cogito-agents/references/regression-tester.md`

When ownership is ambiguous, read these first:

- `.agents/skills/godot-mcp-pro-cogito-agents/references/cogito-boundaries.md`
- `.agents/skills/godot-mcp-pro-cogito-agents/references/mcp-pro-rules.md`
- `.agents/skills/godot-mcp-pro-cogito-agents/references/output-contract.md`
