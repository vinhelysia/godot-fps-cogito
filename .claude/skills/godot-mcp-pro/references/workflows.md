# godot-mcp-pro Extended Workflows

Step-by-step sequences for common multi-tool tasks.

---

## Workflow 1: Bootstrap — Inspect an Unknown Project

Goal: Understand the structure of any Godot project before making changes.

```
1. get_project_info           → name, main scene, display settings
2. get_project_statistics     → scene count, script count, asset count
3. get_filesystem_tree        → directory layout
4. get_autoload               → global singletons
5. get_input_actions          → input bindings
6. open_scene (main scene)
7. get_scene_tree             → node hierarchy
8. list_scripts               → all .gd files
9. get_editor_errors          → any existing errors
```

---

## Workflow 2: Add a New Weapon (FPS Project)

```
1. search_files (pattern: "*.glb") → confirm model is imported
2. create_scene → Sences/Weapons/Firearms/AR/NewGun/NewGun.tscn
3. add_node (MeshInstance3D root)
4. add_mesh_instance → assign .glb mesh
5. open_scene → Sences/Player/FPS_Character.tscn
6. get_scene_tree → find FPS_Rig path
7. add_scene_instance (parent: FPS_Rig, scene: NewGun.tscn)
8. get_scene_tree → confirm node added
9. list_animations → on FPS_Rig/AnimationPlayer → inspect existing
10. create_animation (Equip, Unequip, Shoot, Reload)
11. add_animation_track → per animation per property
12. set_animation_keyframe → per track per time
13. create_resource → Resources/Weapons/Firearm/NewGun.tres (class: Weapon_Resource)
14. edit_resource → set weaponName, equipAnimation, unequipAniamtion, etc.
15. read_resource → verify all fields
16. get_scene_exports → on WeaponManager node
17. update_property → add .tres to weaponResources array
18. update_property → add weaponName to startWeapon array
19. save_scene
20. validate_script → Script/Weapons/weapon_manager.gd
21. get_editor_errors
22. clear_output → play_scene → get_output_log → verify weapon equips
```

---

## Workflow 3: Debug a Runtime Crash

```
1. clear_output
2. play_scene
3. get_output_log (last 50 lines) → find error message and stack trace
4. stop_scene
5. get_editor_errors → cross-reference with editor
6. get_scene_tree → confirm node paths in error match actual paths
7. read_script (script named in stack trace) → find line number
8. validate_script → check for type errors
9. edit_script → fix the issue
10. validate_script → confirm clean
11. clear_output → play_scene → get_output_log → confirm no error
```

---

## Workflow 4: Wire Weapon Signals to HUD

```
1. get_scene_tree → find WeaponManager path and HUD path
2. get_signals (node: WeaponManager) → list all signals
3. get_node_properties (HUD) → confirm receiver methods exist in script
   OR read_script (HUD.gd) → search for method names
4. connect_signal (source: WeaponManager, signal: "weaponChanged",
                   target: HUD, method: "_on_weapon_manager_weapon_changed")
5. connect_signal (signal: "updateAmmo",    method: "_on_weapon_manager_update_ammo")
6. connect_signal (signal: "updateWeaponStack", method: "_on_weapon_manager_update_weapon_stack")
7. find_signal_connections (node: WeaponManager, signal: "weaponChanged") → verify
8. save_scene
9. play_scene → simulate_action "weaponUp" → get_game_screenshot → confirm HUD updates
```

---

## Workflow 5: Add NPC with Navigation and Animation

```
1. add_node (parent: level, type: CharacterBody3D, name: NPC)
2. setup_physics_body (node: NPC, body_type: CharacterBody3D, motion_mode: grounded)
3. setup_collision (parent: NPC, shape_type: capsule, height: 1.8, radius: 0.4)
4. add_mesh_instance (parent: NPC, name: Mesh, mesh_type: capsule)
5. setup_navigation_region (parent: level, geometry_source: static_bodies)
6. bake_navigation_mesh → get_navigation_info → confirm success
7. setup_navigation_agent (parent: NPC, max_speed: 3.5)
8. create_script → Script/NPC/npc_controller.gd
   (extends CharacterBody3D, uses NavigationAgent3D.get_next_path_position())
9. validate_script
10. attach_script (node: NPC, script: npc_controller.gd)
11. add_node (parent: NPC, type: AnimationPlayer)
12. create_animation (idle, walk)
13. add_animation_track + set_animation_keyframe for each
14. create_animation_tree (parent: NPC, type: StateMachine)
15. add_state_machine_state (idle, walk)
16. add_state_machine_transition (idle → walk, condition: moving)
17. save_scene → play_scene → simulate_sequence (wait 2s) → get_game_screenshot
```

---

## Workflow 6: Performance Audit and Optimization

```
1. open_scene (main scene or problematic scene)
2. analyze_scene_complexity → record baseline node count and mesh count
3. clear_output → play_scene
4. run_stress_test (60 seconds)
5. get_performance_monitors → record FPS, draw calls, physics time
6. find_nodes_by_type (MeshInstance3D) → identify high-poly meshes
7. find_nodes_by_type (GPUParticles3D) → check particle counts
8. stop_scene
9. batch_set_property → reduce particle amounts, enable LOD on meshes
10. play_scene → run_stress_test (60 seconds)
11. get_performance_monitors → compare to baseline
12. find_unused_resources → clean up orphaned assets
13. save_scene
```

---

## Workflow 7: Build and Test a UI Screen

```
1. create_scene → Sences/UI/PauseMenu.tscn (root: CanvasLayer)
2. add_node (parent: root, type: Panel, name: Background)
3. set_anchor_preset (node: Background, preset: full_rect)
4. add_node (parent: Background, type: VBoxContainer, name: ButtonList)
5. set_anchor_preset (node: ButtonList, preset: center)
6. add_node (parent: ButtonList, type: Button, name: ResumeButton)
7. update_property (node: ResumeButton, property: text, value: "Resume")
8. add_node (parent: ButtonList, type: Button, name: QuitButton)
9. update_property (node: QuitButton, property: text, value: "Quit")
10. create_theme → Resources/UI/PauseMenuTheme.tres
11. set_theme_color (control: Button, property: font_color, color: #FFFFFF)
12. set_theme_stylebox (control: Panel, property: panel, type: StyleBoxFlat, bg_color: #000000AA)
13. update_property (node: Background, property: theme, value: PauseMenuTheme.tres path)
14. create_script → Script/UI/pause_menu.gd
15. validate_script → attach_script
16. connect_signal (source: ResumeButton, signal: pressed, target: root, method: "_on_resume")
17. connect_signal (source: QuitButton,   signal: pressed, target: root, method: "_on_quit")
18. save_scene
19. play_scene → find_ui_elements → click_button_by_text "Resume" → get_output_log
```

---

## Workflow 8: Add Gunshot Particle Effects and Audio

```
1. open_scene → Sences/Player/FPS_Character.tscn
2. get_scene_tree → find BulletPoint path (FPS_Rig/Bullet Point)
3. create_particles (parent: BulletPoint, name: MuzzleFlash, type: GPUParticles3D)
4. apply_particle_preset (node: MuzzleFlash, preset: muzzle_flash)
5. batch_set_property (node: MuzzleFlash, {one_shot: true, explosiveness: 1.0, amount: 20, emitting: false})
6. add_audio_player (parent: BulletPoint, name: ShootSound, type: AudioStreamPlayer3D)
7. update_property (node: ShootSound, property: stream, value: res://Assets/Audio/gunshot.wav)
8. add_audio_bus (name: SFX, send: Master)
9. add_audio_bus_effect (bus: SFX, effect_type: Reverb, room_size: 0.3)
10. update_property (node: ShootSound, property: bus, value: SFX)
11. read_script → Script/Weapons/weapon_manager.gd → find shoot() function
12. edit_script → in shoot(): add $MuzzleFlash.restart() and $ShootSound.play()
13. validate_script → get_editor_errors
14. save_scene
15. clear_output → play_scene → simulate_action "Shoot"
16. capture_frames (count: 10) → visual review of muzzle flash
17. get_output_log → confirm no errors
```

---

## Workflow 9: Export Build for Windows

```
1. list_export_presets → find Windows preset name
2. get_export_info (preset: Windows) → confirm output path, architecture, PCK embedding
3. get_editor_errors → fix any errors before exporting
4. validate_script (each script in list_scripts) → fix any errors
5. export_project (preset: Windows, output_path: exports/windows/, debug: false)
6. search_files (pattern: "*.exe", directory: exports/windows) → confirm artifact
```

---

## Workflow 10: Visual Regression Testing After a Change

```
BEFORE change:
1. play_scene
2. simulate_sequence → reach reference game state
3. record_frames (duration: 3s, output: tests/before.ogv)
4. stop_scene

MAKE CHANGE (edit scripts, properties, etc.)

AFTER change:
5. play_scene
6. simulate_sequence → same inputs as before
7. record_frames (duration: 3s, output: tests/after.ogv)
8. stop_scene

COMPARE:
9. capture_frames (from before recording, at t=1.5s) → tests/frame_before.png
10. capture_frames (from after recording, at t=1.5s)  → tests/frame_after.png
11. compare_screenshots (a: tests/frame_before.png, b: tests/frame_after.png, tolerance: 0.01)
12. get_test_report → review diff percentage
```

---

## Common Mistakes and How to Avoid Them

| Mistake | Prevention |
|---------|-----------|
| Setting property before reading node structure | Always `get_scene_tree` → `get_node_properties` first |
| Forgetting to `save_scene` | Add `save_scene` as the last step in every sequence |
| Using node name instead of node path | Use full paths like `FPS_Rig/Bullet Point`, not just `Bullet Point` |
| Animation library name mismatch | Use `list_animations` to get exact `"Library/Name"` strings |
| Using `weaponName` that doesn't match `startWeapon` | `read_resource` → confirm exact string including case |
| `get_game_*` when game not running | Always `play_scene` first, then wait, then call runtime tools |
| Signal method doesn't exist on target | `read_script` on receiver → confirm method name before `connect_signal` |
| Modifying the wrong `unequipAniamtion` typo | Keep the typo — it's in all .tres files and weapon_manager.gd |
