---
name: godot-mcp-pro
description: Master skill for godot-mcp-pro MCP server. Use when building, debugging, inspecting, testing, animating, shading, navigating, or exporting Godot 4.x projects. Covers every tool in the mcp__godot-mcp-pro__ namespace with routing logic, sequencing rules, and verification patterns.
---

Use the godot-mcp-pro toolset as a structured operator. Identify the task category, inspect current state, make the minimal effective change, verify the result, and report what changed and how it was verified.

## Core Operating Rules

1. **Inspect before mutating.** Use `get_scene_tree`, `get_node_properties`, or `read_script` before any edit. Never guess paths or property names.
2. **Save after every structural change.** Call `save_scene` after node/property edits. Unsaved scenes do not persist.
3. **Verify after every change.** Use `validate_script` after script edits, `get_editor_errors` after scene changes, `get_game_screenshot` after runtime changes.
4. **Prefer batch tools.** Use `batch_get_properties` / `batch_set_property` over repeated single-property calls.
5. **Distinguish editor from runtime.** Scene tools operate on authored data. `get_game_*` and `simulate_*` tools operate on the running game. Do not mix contexts.
6. **Clear output before running.** Call `clear_output` before `play_scene` to get a clean log, then read `get_output_log` for evidence.

---

## Tool Catalog by Category

### Scene Management
| Tool | When to use |
|------|-------------|
| `create_scene` | New scene file needed |
| `open_scene` | Switch editor to a scene |
| `save_scene` | Persist all edits to disk |
| `delete_scene` | Remove scene file permanently |
| `get_scene_tree` | Read the full node hierarchy (editor) |
| `get_scene_file_content` | Read raw .tscn text |
| `get_scene_dependencies` | List all resources a scene references |
| `get_scene_exports` | List exported variables on the root node |
| `analyze_scene_complexity` | Detect performance issues (node count, depth, drawcalls) |
| `add_scene_instance` | Instantiate another scene as a child node |

**Sequence — build a new scene:**
1. `create_scene` → 2. `add_node` (root) → 3. `add_node` (children) → 4. `attach_script` → 5. `save_scene` → 6. `play_scene` → 7. `get_output_log`

---

### Node Operations
| Tool | When to use |
|------|-------------|
| `add_node` | Add any node type to the tree |
| `delete_node` | Remove a node (irreversible without undo) |
| `rename_node` | Change node name |
| `move_node` | Reparent a node |
| `duplicate_node` | Copy a node and its children |
| `get_node_properties` | Read all properties of a node |
| `update_property` | Set a single property on a node |
| `batch_get_properties` | Read multiple properties in one call |
| `batch_set_property` | Set multiple properties in one call |
| `cross_scene_set_property` | Set a property on a node in another scene |
| `find_nodes_by_type` | Find all nodes of a class (e.g., all `MeshInstance3D`) |
| `find_nodes_by_script` | Find nodes using a specific script |
| `find_nodes_in_group` | Find nodes belonging to a group |
| `find_nearby_nodes` | Find nodes spatially close to a position |
| `find_node_references` | Find where a node is referenced in scripts |
| `get_node_groups` | List groups a node belongs to |
| `set_node_groups` | Assign groups to a node |
| `assert_node_state` | Assert a property has a specific value (testing) |
| `wait_for_node` | Wait until a node exists at path (runtime) |
| `add_raycast` | Add a RayCast3D/2D node with configured parameters |

**Sequence — modify an existing node:**
1. `get_scene_tree` → find path
2. `get_node_properties` → read current state
3. `batch_set_property` → apply changes
4. `save_scene`
5. `get_editor_errors` → confirm no errors

---

### Script Operations
| Tool | When to use |
|------|-------------|
| `create_script` | Write a new .gd file |
| `edit_script` | Modify an existing script |
| `read_script` | Read script source |
| `list_scripts` | List all scripts in project |
| `validate_script` | Check for syntax/type errors |
| `attach_script` | Assign a script to a node |
| `get_open_scripts` | See scripts currently open in editor |
| `find_script_references` | Find where a script is used |
| `execute_editor_script` | Run a `@tool` script in the editor context |
| `execute_game_script` | Run GDScript in the running game context |

**Sequence — add gameplay logic:**
1. `read_script` (if existing) → understand current code
2. `edit_script` or `create_script` → write logic
3. `validate_script` → confirm no errors
4. `attach_script` (if new)
5. `play_scene` → `get_output_log` → verify behavior

**Key rule:** Always `validate_script` before `play_scene`. A script with errors prevents the scene from running and produces confusing output.

---

### Signals
| Tool | When to use |
|------|-------------|
| `get_signals` | List all signals on a node |
| `connect_signal` | Wire a signal to a callable |
| `disconnect_signal` | Remove a signal connection |
| `find_signal_connections` | Find all connections involving a signal |
| `analyze_signal_flow` | Map signal propagation across the scene tree |

**Sequence — wire a signal:**
1. `get_signals` on emitter → confirm signal name
2. `get_node_properties` on receiver → confirm method exists
3. `connect_signal` with exact signal name, target path, and method name
4. `save_scene`
5. `play_scene` → trigger condition → `get_output_log` to verify

**Key rule:** Signal names are case-sensitive. Method names must exist on the target node at connection time. Use `analyze_signal_flow` to audit complex signal webs for cycles or missing connections.

---

### Animation
| Tool | When to use |
|------|-------------|
| `create_animation` | Add a new animation to an AnimationPlayer |
| `list_animations` | List all animations in an AnimationPlayer |
| `get_animation_info` | Read tracks, length, and loop settings |
| `remove_animation` | Delete an animation |
| `add_animation_track` | Add a property, method, or bezier track |
| `set_animation_keyframe` | Set a keyframe value at a time position |
| `create_animation_tree` | Add an AnimationTree node |
| `get_animation_tree_structure` | Read the blend tree / state machine layout |
| `set_blend_tree_node` | Configure a node in a BlendTree |
| `set_tree_parameter` | Set a parameter (e.g., blend amount, condition) |
| `add_state_machine_state` | Add a state to an AnimationNodeStateMachine |
| `add_state_machine_transition` | Add a transition between states |
| `remove_state_machine_state` | Remove a state |
| `remove_state_machine_transition` | Remove a transition |

**Sequence — simple animation:**
1. Ensure `AnimationPlayer` exists (`add_node` if not)
2. `create_animation` with name, length, loop setting
3. `add_animation_track` for each property to animate
4. `set_animation_keyframe` at each time point
5. `save_scene` → `play_scene` → visually verify

**Sequence — state machine animation:**
1. `create_animation_tree` on the character node
2. `add_state_machine_state` for each state (Idle, Walk, Run, Jump)
3. `add_state_machine_transition` with condition parameters
4. `set_tree_parameter` at runtime via `execute_game_script` to test transitions
5. Verify with `get_animation_tree_structure`

**Key rule:** Animation library names in this project use the format `"LibraryName/AnimationName"`. The library name may contain spaces even if the node name does not (e.g., `"Mosin Nagent/Mosin Nagent Equip"`).

---

### Physics
| Tool | When to use |
|------|-------------|
| `setup_physics_body` | Configure a CharacterBody3D/RigidBody3D/StaticBody3D |
| `setup_collision` | Add CollisionShape3D with a specific shape |
| `get_collision_info` | Read collision layers, masks, and shapes |
| `get_physics_layers` | Read the project's physics layer names |
| `set_physics_layers` | Rename physics layers globally |

**Sequence — add a physics object:**
1. `add_node` (CharacterBody3D, RigidBody3D, or StaticBody3D)
2. `setup_physics_body` with motion mode and parameters
3. `setup_collision` with shape type (box, sphere, capsule, convex, trimesh)
4. `get_collision_info` → confirm layers and masks
5. `attach_script` if movement logic needed
6. `save_scene` → `play_scene` → verify collision behavior

**Key rule:** `setup_collision` on a CharacterBody3D requires the collision shape to be a *child*, not the body itself. Confirm the node path hierarchy with `get_scene_tree` after setup.

---

### Navigation
| Tool | When to use |
|------|-------------|
| `setup_navigation_region` | Add a NavigationRegion3D with a NavigationMesh |
| `setup_navigation_agent` | Add a NavigationAgent3D to an NPC |
| `bake_navigation_mesh` | Bake the navmesh from geometry |
| `get_navigation_info` | Read navmesh parameters and bake state |
| `set_navigation_layers` | Configure navigation layer names |

**Sequence — add NPC navigation:**
1. `setup_navigation_region` on the level geometry node
2. `bake_navigation_mesh` after geometry is final
3. `get_navigation_info` → confirm bake succeeded
4. `setup_navigation_agent` on the NPC CharacterBody3D
5. Write movement script using `NavigationAgent3D.get_next_path_position()`
6. `validate_script` → `play_scene` → verify pathfinding

---

### Audio
| Tool | When to use |
|------|-------------|
| `add_audio_player` | Add an AudioStreamPlayer/2D/3D to a node |
| `add_audio_bus` | Add a new audio bus |
| `add_audio_bus_effect` | Add an effect (Reverb, Compressor, EQ) to a bus |
| `get_audio_bus_layout` | Read all buses and their effects |
| `set_audio_bus` | Configure a bus's volume, mute, solo, send |
| `get_audio_info` | Read audio stream and playback properties |

**Sequence — add 3D spatial audio:**
1. `add_audio_player` with type `AudioStreamPlayer3D` on the emitting node
2. `update_property` to assign the stream file path
3. `add_audio_bus` if a dedicated bus is needed (e.g., "SFX", "Music")
4. `set_audio_bus` for volume and send chain
5. `add_audio_bus_effect` for spatial reverb or compression
6. `play_scene` → `get_game_screenshot` to confirm player exists

---

### Particles
| Tool | When to use |
|------|-------------|
| `create_particles` | Add a GPUParticles3D or CPUParticles3D node |
| `apply_particle_preset` | Apply a preset (fire, smoke, sparks, blood, etc.) |
| `get_particle_info` | Read emission shape, lifetime, and material |
| `set_particle_material` | Assign a ParticleProcessMaterial |
| `set_particle_color_gradient` | Set the color over lifetime gradient |

**Sequence — gunshot muzzle flash:**
1. `create_particles` at the `Bullet Point` node path
2. `apply_particle_preset` with "sparks" or "muzzle_flash"
3. `get_particle_info` → read defaults
4. `update_property` → set `one_shot = true`, `explosiveness = 1.0`, `amount`
5. `set_particle_color_gradient` for color ramp
6. Trigger via `execute_game_script` on shoot event → `capture_frames` to review

---

### Shaders
| Tool | When to use |
|------|-------------|
| `create_shader` | Write a new .gdshader file |
| `edit_shader` | Modify shader source |
| `read_shader` | Read current shader code |
| `assign_shader_material` | Attach a shader to a MeshInstance3D |
| `get_shader_params` | List uniform parameters |
| `set_shader_param` | Set a uniform value |

**Sequence — add a custom shader to a weapon:**
1. `read_shader` if existing, else `create_shader`
2. `edit_shader` with GLSL-like shader code
3. `assign_shader_material` to the target MeshInstance3D
4. `get_shader_params` → confirm uniforms are detected
5. `set_shader_param` for values (colors, textures, floats)
6. `get_editor_screenshot` → visual confirmation

---

### Materials & 3D Environment
| Tool | When to use |
|------|-------------|
| `set_material_3d` | Assign a StandardMaterial3D or resource to a surface |
| `add_mesh_instance` | Add a MeshInstance3D with a specific mesh |
| `add_gridmap` | Add a GridMap for modular level design |
| `setup_camera_3d` | Configure Camera3D FOV, near, far, projection |
| `setup_lighting` | Add DirectionalLight3D, OmniLight3D, or SpotLight3D |
| `setup_environment` | Configure WorldEnvironment (sky, fog, exposure, SSAO) |

**Sequence — set up a lit 3D scene:**
1. `setup_lighting` → add DirectionalLight3D (sun)
2. `setup_environment` → configure sky and ambient
3. `add_mesh_instance` for geometry
4. `set_material_3d` for surfaces
5. `get_editor_screenshot` → visual check

---

### UI & Themes
| Tool | When to use |
|------|-------------|
| `find_ui_elements` | Locate Control nodes (labels, buttons, panels) |
| `click_button_by_text` | Click a Button by its visible text (runtime testing) |
| `set_anchor_preset` | Set anchors/margins using a preset name |
| `create_theme` | Create a new Theme resource |
| `get_theme_info` | Read theme colors, fonts, constants, styleboxes |
| `set_theme_color` | Set a color in the theme |
| `set_theme_constant` | Set an integer constant in the theme |
| `set_theme_font_size` | Set a font size in the theme |
| `set_theme_stylebox` | Set a StyleBox on a control type |

**Sequence — style a HUD:**
1. `find_ui_elements` → map current Control nodes
2. `create_theme` if no theme exists
3. `set_theme_color` for font colors
4. `set_theme_stylebox` for panel backgrounds
5. `set_theme_font_size` for label sizes
6. `update_property` to assign theme to root CanvasLayer
7. `get_editor_screenshot` → confirm visual

---

### Resources
| Tool | When to use |
|------|-------------|
| `create_resource` | Create a new .tres file from a class |
| `add_resource` | Add a resource to a node property array |
| `edit_resource` | Modify a .tres file's properties |
| `read_resource` | Read current resource property values |
| `get_resource_preview` | Get a visual preview of a resource |
| `find_unused_resources` | List .tres/.res files not referenced anywhere |

**Sequence — create a new weapon resource:**
1. `create_resource` with class `Weapon_Resource`
2. `edit_resource` → set `weaponName`, animation names, ammo values, `autoFire`
3. `read_resource` → verify all fields
4. `find_unused_resources` periodically → clean up orphans

---

### Project Settings & Configuration
| Tool | When to use |
|------|-------------|
| `get_project_info` | Read project name, main scene, version |
| `get_project_settings` | Read all project.godot settings |
| `set_project_setting` | Change a project setting |
| `get_project_statistics` | Get counts of scenes, scripts, assets |
| `get_input_actions` | List all input map actions and bindings |
| `set_input_action` | Add or modify an input action |
| `add_autoload` | Register a global singleton |
| `get_autoload` | List registered autoloads |
| `remove_autoload` | Unregister a singleton |
| `get_filesystem_tree` | Browse the `res://` directory tree |
| `search_files` | Find files by name pattern |
| `search_in_files` | Search file contents by text/regex |
| `project_path_to_uid` | Convert `res://` path to UID |
| `uid_to_project_path` | Convert UID to `res://` path |

**Sequence — add a new input action:**
1. `get_input_actions` → confirm action doesn't already exist
2. `set_input_action` with action name and key/button binding
3. `get_input_actions` → verify registration

---

### Game Runtime Control
| Tool | When to use |
|------|-------------|
| `play_scene` | Start the current or specified scene |
| `stop_scene` | Stop the running game |
| `get_game_scene_tree` | Read the runtime node tree |
| `get_game_node_properties` | Read a node's property values at runtime |
| `set_game_node_property` | Modify a node property while game is running |
| `get_game_screenshot` | Capture the game viewport |
| `execute_game_script` | Run arbitrary GDScript in the running game |

**Sequence — inspect runtime state:**
1. `play_scene`
2. Wait for scene to load
3. `get_game_scene_tree` → confirm node structure matches editor
4. `get_game_node_properties` on a specific node
5. `execute_game_script` to call methods or read values
6. `stop_scene`

**Key rule:** `get_game_*` tools require the game to be running. Always `play_scene` first. Use `get_output_log` alongside runtime tools for log evidence.

---

### Input Simulation
| Tool | When to use |
|------|-------------|
| `simulate_action` | Fire a named InputMap action (e.g., "Shoot", "Reload") |
| `simulate_key` | Press/release a specific key |
| `simulate_mouse_click` | Click at screen coordinates |
| `simulate_mouse_move` | Move mouse to screen coordinates |
| `simulate_sequence` | Execute a timed sequence of input events |

**Sequence — test weapon firing:**
1. `play_scene`
2. `simulate_action` with `"Shoot"` → `get_output_log` → confirm shot logged
3. `simulate_action` with `"Reload"` → `get_output_log` → confirm reload
4. `get_game_node_properties` on WeaponManager → check `currentAmmo` value
5. `stop_scene`

---

### Testing & QA
| Tool | When to use |
|------|-------------|
| `run_test_scenario` | Execute a named test scenario |
| `get_test_report` | Read test results |
| `assert_node_state` | Assert a node property equals an expected value |
| `assert_screen_text` | Assert text appears on screen |
| `capture_frames` | Capture N frames as images |
| `start_recording` | Begin recording game frames |
| `stop_recording` | End recording |
| `replay_recording` | Play back a recording |
| `record_frames` | Record and save frames in one call |
| `compare_screenshots` | Pixel-diff two screenshots |
| `run_stress_test` | Run the game under load for performance data |

**Sequence — visual regression test:**
1. `play_scene`
2. `simulate_sequence` to reach the target state
3. `capture_frames` → save reference screenshot
4. Make changes
5. `play_scene` again → `simulate_sequence` same inputs
6. `compare_screenshots` → check pixel diff is within tolerance

---

### Performance & Debugging
| Tool | When to use |
|------|-------------|
| `get_editor_errors` | Read errors shown in the Godot editor output |
| `get_editor_performance` | Read editor CPU/memory usage |
| `get_performance_monitors` | Read runtime FPS, draw calls, physics time |
| `monitor_properties` | Watch property values change over time |
| `get_output_log` | Read the full editor/game print output |
| `clear_output` | Clear the output log |
| `get_editor_screenshot` | Capture the editor viewport |

**Sequence — diagnose frame drops:**
1. `clear_output`
2. `play_scene`
3. `run_stress_test` for 30 seconds
4. `get_performance_monitors` → read FPS, draw calls, object count
5. `analyze_scene_complexity` → identify expensive nodes
6. `stop_scene` → apply optimizations → repeat

---

### Analysis & Refactoring Tools
| Tool | When to use |
|------|-------------|
| `analyze_scene_complexity` | Count nodes, depth, draw calls |
| `analyze_signal_flow` | Map all signal connections in a scene |
| `detect_circular_dependencies` | Find cyclic autoload or scene dependencies |
| `find_unused_resources` | List orphaned .tres/.res files |
| `find_node_references` | Find script/scene references to a node |
| `find_script_references` | Find where a script is used |

**Run these periodically** before major refactors to understand the scope of changes. `detect_circular_dependencies` is critical before adding a new autoload.

---

### Tilemap Operations
| Tool | When to use |
|------|-------------|
| `tilemap_get_info` | Read TileMap layers, tileset, and cell size |
| `tilemap_set_cell` | Place a tile at a coordinate |
| `tilemap_get_cell` | Read the tile at a coordinate |
| `tilemap_fill_rect` | Fill a rectangle with a tile |
| `tilemap_clear` | Clear all tiles (or a layer) |
| `tilemap_get_used_cells` | List all occupied cell coordinates |

**Sequence — fill a floor section:**
1. `tilemap_get_info` → confirm layer index and tileset
2. `tilemap_fill_rect` with layer, start coord, end coord, tile ID
3. `tilemap_get_used_cells` → verify coverage
4. `save_scene`

---

### Export
| Tool | When to use |
|------|-------------|
| `list_export_presets` | List configured export presets |
| `get_export_info` | Read a preset's platform and settings |
| `export_project` | Build the project for a target platform |

**Sequence — export for Windows:**
1. `list_export_presets` → find the Windows preset name
2. `get_export_info` → confirm output path and architecture
3. `export_project` with preset name and output directory
4. Check file system for build artifacts

---

### Editor & Plugin Management
| Tool | When to use |
|------|-------------|
| `reload_plugin` | Reload a specific editor plugin |
| `reload_project` | Full project reload (use sparingly) |
| `navigate_to` | Open a file in the editor |
| `move_to` | Move editor view to a scene position |
| `get_editor_screenshot` | Capture the editor UI for visual verification |

---

## Task Routing

Choose the first matching path:

| User request | Primary tools | Verification |
|---|---|---|
| Create a new scene | `create_scene` → `add_node` → `save_scene` | `get_editor_errors` |
| Add a node | `get_scene_tree` → `add_node` → `save_scene` | `get_scene_tree` again |
| Add a script | `create_script` → `validate_script` → `attach_script` | `get_editor_errors` |
| Fix a script error | `read_script` → `edit_script` → `validate_script` | `get_editor_errors` |
| Connect a signal | `get_signals` → `connect_signal` → `save_scene` | `find_signal_connections` |
| Add physics | `setup_physics_body` → `setup_collision` → `save_scene` | `get_collision_info` |
| Add audio | `add_audio_player` → `set_audio_bus` → `save_scene` | `get_audio_info` |
| Add particles | `create_particles` → `apply_particle_preset` → `save_scene` | `capture_frames` |
| Add navigation | `setup_navigation_region` → `bake_navigation_mesh` → `setup_navigation_agent` | `get_navigation_info` |
| Add animation | `create_animation` → `add_animation_track` → `set_animation_keyframe` | `get_animation_info` |
| Add a state machine | `create_animation_tree` → `add_state_machine_state` → `add_state_machine_transition` | `get_animation_tree_structure` |
| Debug runtime crash | `clear_output` → `play_scene` → `get_output_log` | `get_editor_errors` |
| Test input | `play_scene` → `simulate_action` → `get_output_log` | `get_game_node_properties` |
| Visual regression | `capture_frames` → change → `capture_frames` → `compare_screenshots` | pixel diff |
| Performance audit | `run_stress_test` → `get_performance_monitors` → `analyze_scene_complexity` | FPS baseline |
| Tilemap level | `tilemap_get_info` → `tilemap_fill_rect` → `save_scene` | `tilemap_get_used_cells` |
| Export build | `list_export_presets` → `export_project` | artifact file check |

---

## Project-Specific Context (this project)

- **Godot version:** 4.6, Forward Plus renderer, Jolt Physics, D3D12 on Windows
- **Project root:** `new-game-project/` → `res://`
- **Main character scene:** `Sences/Player/FPS_Character.tscn`
- **Weapon scripts:** `Script/Weapons/weapon_manager.gd`, `Script/Weapons/weapon_resource.gd`
- **Animation library format:** `"LibraryName/AnimationName"` (library may contain spaces)
- **Known typo — do not fix:** `unequipAniamtion` in weapon_resource.gd and all .tres files
- **MCP bridge port:** WebSocket 6551 (not default 6550)
- **Autoloads:** `NotificationManager`, `MCPGameBridge`, `DiscordRPCLoader`
- **Naming convention:** PascalCase for variables and nodes (project-specific, not standard GDScript)

---

## Failure Escalation Order

When blocked:
1. `get_editor_errors` → read the exact error message
2. `get_output_log` → find the stack trace
3. `get_scene_tree` → confirm node paths are correct
4. `read_script` → confirm method names and variable names
5. `validate_script` → find syntax errors
6. `get_game_scene_tree` → compare runtime tree to editor tree
7. `execute_game_script` → probe runtime state directly
8. `analyze_scene_complexity` / `detect_circular_dependencies` → systemic issues

Never make a second change before understanding why the first one failed.

---

## Response Format

### Goal
One sentence stating the target outcome.

### Inspected
What was read: scene tree, node properties, script content, log output.

### Actions
Ordered list of tool calls with targets and key parameters.

### Result
What changed, what was created, what was deleted.

### Verification
Which verification tool was used and what it confirmed.

### Blocker / Next step (only if needed)
Specific unresolved issue and the next diagnostic step.

---

## References

- [tool-catalog.md](references/tool-catalog.md) — Full tool list with parameters summary
- [workflows.md](references/workflows.md) — Extended step-by-step workflows per domain
