# godot-mcp-pro Tool Catalog

Complete reference of every `mcp__godot-mcp-pro__*` tool, grouped by domain, with key parameters and common pairings.

---

## Scene Management

### `create_scene`
Creates a new .tscn file.
- **params:** `path` (res:// path), `root_type` (node class for root), `root_name`
- **pairs with:** `add_node`, `save_scene`

### `open_scene`
Opens a scene in the editor.
- **params:** `path`
- **pairs with:** `get_scene_tree`

### `save_scene`
Saves the current scene to disk.
- **params:** none (saves active scene) or `path`
- **call after:** every structural or property change

### `delete_scene`
Deletes a .tscn file permanently.
- **params:** `path`
- **check first:** `get_scene_dependencies` to find anything that instances it

### `get_scene_tree`
Returns the full node hierarchy as structured data.
- **params:** `scene_path` (optional, defaults to current)
- **returns:** nested node tree with names, types, and paths

### `get_scene_file_content`
Returns the raw text of a .tscn file.
- **params:** `path`
- **use for:** debugging resource references, ext_resource IDs

### `get_scene_dependencies`
Lists all resources (.tres, .gd, sub-scenes) referenced by a scene.
- **params:** `path`

### `get_scene_exports`
Lists `@export` variables on the root node's script.
- **params:** `scene_path`

### `analyze_scene_complexity`
Reports node count, tree depth, mesh count, collision shapes, particle systems.
- **params:** `scene_path`
- **use for:** pre-optimization audits

### `add_scene_instance`
Instantiates a scene as a child of a node.
- **params:** `parent_path`, `scene_path`, `node_name`

---

## Node Operations

### `add_node`
Adds a node to the scene tree.
- **params:** `parent_path`, `node_type`, `node_name`, `properties` (dict, optional)

### `delete_node`
Removes a node and all its children.
- **params:** `node_path`
- **irreversible:** confirm path with `get_scene_tree` first

### `rename_node`
Renames a node.
- **params:** `node_path`, `new_name`
- **warning:** invalidates any hardcoded paths in scripts

### `move_node`
Reparents a node to a new parent.
- **params:** `node_path`, `new_parent_path`

### `duplicate_node`
Copies a node and all children.
- **params:** `node_path`, `new_name` (optional)

### `get_node_properties`
Returns all properties and their values.
- **params:** `node_path`, `scene_path` (optional)

### `update_property`
Sets one property on a node.
- **params:** `node_path`, `property`, `value`
- **prefer:** `batch_set_property` for multiple properties

### `batch_get_properties`
Reads multiple properties in one call.
- **params:** `node_path`, `properties` (array of property names)

### `batch_set_property`
Sets multiple properties in one call.
- **params:** `node_path`, `properties` (dict: property → value)

### `cross_scene_set_property`
Sets a property on a node in a *different* scene without opening it.
- **params:** `scene_path`, `node_path`, `property`, `value`

### `find_nodes_by_type`
Finds all nodes of a given class in a scene.
- **params:** `node_type`, `scene_path` (optional)

### `find_nodes_by_script`
Finds nodes using a specific script.
- **params:** `script_path`, `scene_path` (optional)

### `find_nodes_in_group`
Finds nodes in a named group.
- **params:** `group_name`, `scene_path` (optional)

### `find_nearby_nodes`
Finds nodes within a spatial radius.
- **params:** `node_path`, `radius`, `node_type` (optional filter)

### `find_node_references`
Finds script/scene locations that reference a node path.
- **params:** `node_path`

### `get_node_groups`
Returns groups a node belongs to.
- **params:** `node_path`

### `set_node_groups`
Assigns groups to a node.
- **params:** `node_path`, `groups` (array of strings)

### `assert_node_state`
Asserts a property equals an expected value. Fails test if not.
- **params:** `node_path`, `property`, `expected_value`

### `wait_for_node`
Waits until a node exists at path (runtime only).
- **params:** `node_path`, `timeout_seconds`

### `add_raycast`
Adds a RayCast3D or RayCast2D node.
- **params:** `parent_path`, `name`, `target_position`, `collision_mask`

---

## Script Operations

### `create_script`
Writes a new GDScript file.
- **params:** `path`, `content`, `node_type` (for `extends`)

### `edit_script`
Overwrites or patches a script.
- **params:** `path`, `content`

### `read_script`
Returns the current content of a script.
- **params:** `path`

### `list_scripts`
Lists all .gd files in the project.
- **params:** `directory` (optional, defaults to `res://`)

### `validate_script`
Checks for syntax and type errors.
- **params:** `path`
- **returns:** list of errors with line numbers, or success

### `attach_script`
Assigns a .gd file to a node.
- **params:** `node_path`, `script_path`

### `get_open_scripts`
Returns scripts currently open in the script editor.
- **params:** none

### `find_script_references`
Finds all scenes and scripts that reference a specific script.
- **params:** `script_path`

### `execute_editor_script`
Runs a `@tool` script or expression in the editor context.
- **params:** `code` or `script_path`
- **use for:** bulk operations, migration scripts

### `execute_game_script`
Runs GDScript expression in the running game.
- **params:** `code`
- **requires:** game to be running via `play_scene`

---

## Signals

### `get_signals`
Lists all signals defined on a node (including from script).
- **params:** `node_path`

### `connect_signal`
Connects a signal to a method.
- **params:** `source_path`, `signal_name`, `target_path`, `method_name`, `flags` (optional)

### `disconnect_signal`
Removes a signal connection.
- **params:** `source_path`, `signal_name`, `target_path`, `method_name`

### `find_signal_connections`
Shows all connections for a signal.
- **params:** `node_path`, `signal_name`

### `analyze_signal_flow`
Maps all signal connections in the scene tree.
- **params:** `scene_path`
- **returns:** graph of emitters → receivers

---

## Animation

### `create_animation`
Adds a new animation to an AnimationPlayer.
- **params:** `node_path`, `animation_name`, `length`, `loop_mode`

### `list_animations`
Lists all animations in an AnimationPlayer.
- **params:** `node_path`

### `get_animation_info`
Returns tracks, length, loop mode for an animation.
- **params:** `node_path`, `animation_name`

### `remove_animation`
Deletes an animation.
- **params:** `node_path`, `animation_name`

### `add_animation_track`
Adds a track to an animation.
- **params:** `node_path`, `animation_name`, `track_type` (property/method/bezier), `track_path`, `interpolation`

### `set_animation_keyframe`
Sets a keyframe value at a time position.
- **params:** `node_path`, `animation_name`, `track_index`, `time`, `value`

### `create_animation_tree`
Adds an AnimationTree node.
- **params:** `parent_path`, `animation_player_path`, `root_type` (StateMachine/BlendTree)

### `get_animation_tree_structure`
Returns the blend tree or state machine layout.
- **params:** `node_path`

### `set_blend_tree_node`
Configures a node within a BlendTree.
- **params:** `node_path`, `blend_node_name`, `type`, `properties`

### `set_tree_parameter`
Sets a parameter value (blend amount, condition, float).
- **params:** `node_path`, `parameter`, `value`

### `add_state_machine_state`
Adds a state to an AnimationNodeStateMachine.
- **params:** `node_path`, `state_name`, `animation_name`

### `add_state_machine_transition`
Adds a transition between two states.
- **params:** `node_path`, `from_state`, `to_state`, `advance_condition`, `switch_mode`

### `remove_state_machine_state`
Removes a state.
- **params:** `node_path`, `state_name`

### `remove_state_machine_transition`
Removes a transition.
- **params:** `node_path`, `from_state`, `to_state`

---

## Physics

### `setup_physics_body`
Configures a CharacterBody3D/RigidBody3D/StaticBody3D.
- **params:** `node_path`, `body_type`, `motion_mode`, `floor_max_angle`

### `setup_collision`
Adds CollisionShape3D with shape.
- **params:** `parent_path`, `shape_type` (box/sphere/capsule/convex/trimesh), `size`

### `get_collision_info`
Returns layers, masks, shapes.
- **params:** `node_path`

### `get_physics_layers`
Returns all physics layer names from project settings.
- **params:** none

### `set_physics_layers`
Renames physics layers globally.
- **params:** `layers` (dict: index → name)

---

## Navigation

### `setup_navigation_region`
Adds NavigationRegion3D and NavigationMesh.
- **params:** `parent_path`, `geometry_source`

### `setup_navigation_agent`
Adds NavigationAgent3D to a character.
- **params:** `parent_path`, `name`, `max_speed`, `path_desired_distance`

### `bake_navigation_mesh`
Bakes the navmesh from scene geometry.
- **params:** `node_path` (NavigationRegion3D)

### `get_navigation_info`
Returns bake status and navmesh parameters.
- **params:** `node_path`

### `set_navigation_layers`
Configures navigation layer names.
- **params:** `layers` (dict: index → name)

---

## Audio

### `add_audio_player`
Adds AudioStreamPlayer/2D/3D.
- **params:** `parent_path`, `name`, `type`, `stream_path`, `autoplay`, `bus`

### `add_audio_bus`
Adds a new audio bus.
- **params:** `name`, `volume_db`, `send`

### `add_audio_bus_effect`
Adds an effect to a bus.
- **params:** `bus_name`, `effect_type` (Reverb/Compressor/EQ/Chorus/etc.), `properties`

### `get_audio_bus_layout`
Returns all buses and their effects.
- **params:** none

### `set_audio_bus`
Configures a bus volume, mute, solo, send.
- **params:** `bus_name`, `volume_db`, `mute`, `solo`, `send`

### `get_audio_info`
Returns stream path, playback state, volume.
- **params:** `node_path`

---

## Particles

### `create_particles`
Adds GPUParticles3D or CPUParticles3D.
- **params:** `parent_path`, `name`, `type`, `amount`, `lifetime`

### `apply_particle_preset`
Applies a named preset.
- **params:** `node_path`, `preset` (fire/smoke/sparks/rain/snow/muzzle_flash/etc.)

### `get_particle_info`
Returns emission parameters, material, lifetime.
- **params:** `node_path`

### `set_particle_material`
Assigns a ParticleProcessMaterial.
- **params:** `node_path`, `material_path`

### `set_particle_color_gradient`
Sets the color over lifetime.
- **params:** `node_path`, `gradient` (array of [offset, color] pairs)

---

## Shaders

### `create_shader`
Creates a new .gdshader file.
- **params:** `path`, `shader_type` (spatial/canvas_item/particles), `content`

### `edit_shader`
Rewrites shader source.
- **params:** `path`, `content`

### `read_shader`
Returns shader source code.
- **params:** `path`

### `assign_shader_material`
Attaches a shader to a MeshInstance3D.
- **params:** `node_path`, `shader_path`, `surface_index`

### `get_shader_params`
Lists uniform parameters.
- **params:** `shader_path` or `node_path`

### `set_shader_param`
Sets a uniform value.
- **params:** `node_path`, `param_name`, `value`

---

## Materials & 3D Environment

### `set_material_3d`
Assigns a material resource to a mesh surface.
- **params:** `node_path`, `material_path`, `surface_index`

### `add_mesh_instance`
Adds a MeshInstance3D with a specified mesh.
- **params:** `parent_path`, `name`, `mesh_type` (box/sphere/capsule/plane/cylinder/custom)

### `add_gridmap`
Adds a GridMap node.
- **params:** `parent_path`, `name`, `mesh_library_path`, `cell_size`

### `setup_camera_3d`
Configures Camera3D.
- **params:** `node_path`, `fov`, `near`, `far`, `projection`

### `setup_lighting`
Adds a light node.
- **params:** `parent_path`, `light_type` (directional/omni/spot), `color`, `energy`, `shadows`

### `setup_environment`
Configures WorldEnvironment.
- **params:** `node_path`, `sky_type`, `ambient_light`, `fog_enabled`, `ssao_enabled`, `exposure`

---

## UI & Themes

### `find_ui_elements`
Finds Control nodes in a scene.
- **params:** `scene_path`, `element_type` (optional filter)

### `click_button_by_text`
Clicks a Button by its text label (runtime).
- **params:** `text`, `scene_path` (optional)

### `set_anchor_preset`
Sets anchor and margin preset.
- **params:** `node_path`, `preset` (full_rect/top_left/top_right/center/etc.)

### `create_theme`
Creates a new .tres Theme resource.
- **params:** `path`

### `get_theme_info`
Returns theme colors, constants, fonts, styleboxes.
- **params:** `theme_path`

### `set_theme_color`
Sets a color item in the theme.
- **params:** `theme_path`, `control_type`, `property`, `color`

### `set_theme_constant`
Sets an integer constant.
- **params:** `theme_path`, `control_type`, `property`, `value`

### `set_theme_font_size`
Sets a font size.
- **params:** `theme_path`, `control_type`, `property`, `size`

### `set_theme_stylebox`
Sets a StyleBox on a control type.
- **params:** `theme_path`, `control_type`, `property`, `stylebox_type`, `stylebox_properties`

---

## Resources

### `create_resource`
Creates a new .tres file.
- **params:** `path`, `class_name`

### `add_resource`
Appends a resource to an array property on a node.
- **params:** `node_path`, `property`, `resource_path`

### `edit_resource`
Modifies properties of a .tres file.
- **params:** `path`, `properties` (dict)

### `read_resource`
Returns all property values of a .tres file.
- **params:** `path`

### `get_resource_preview`
Returns a visual thumbnail preview.
- **params:** `path`

### `find_unused_resources`
Lists resources not referenced anywhere.
- **params:** `directory` (optional)

---

## Project Settings

### `get_project_info`
Returns project name, version, main scene, display settings.
- **params:** none

### `get_project_settings`
Returns all project.godot settings as a dict.
- **params:** `filter` (optional prefix)

### `set_project_setting`
Changes a project.godot setting.
- **params:** `setting`, `value`

### `get_project_statistics`
Returns counts of scenes, scripts, resources, nodes.
- **params:** none

### `get_input_actions`
Lists all input map actions and their bindings.
- **params:** none

### `set_input_action`
Adds or modifies an input action.
- **params:** `action_name`, `events` (array of key/button specs), `deadzone`

### `add_autoload`
Registers a global singleton.
- **params:** `name`, `path`

### `get_autoload`
Lists all registered autoloads.
- **params:** none

### `remove_autoload`
Unregisters a singleton.
- **params:** `name`

### `get_filesystem_tree`
Returns the res:// directory structure.
- **params:** `path` (optional subdirectory)

### `search_files`
Finds files by name pattern.
- **params:** `pattern`, `directory`

### `search_in_files`
Searches file contents.
- **params:** `text`, `file_types` (optional), `directory`

### `project_path_to_uid`
Converts res:// path to UID string.
- **params:** `path`

### `uid_to_project_path`
Converts UID to res:// path.
- **params:** `uid`

---

## Game Runtime

### `play_scene`
Starts the game (current or specified scene).
- **params:** `scene_path` (optional)

### `stop_scene`
Stops the running game.
- **params:** none

### `get_game_scene_tree`
Returns runtime node tree.
- **params:** none (game must be running)

### `get_game_node_properties`
Returns property values of a runtime node.
- **params:** `node_path`

### `set_game_node_property`
Sets a property on a runtime node.
- **params:** `node_path`, `property`, `value`

### `get_game_screenshot`
Captures the game viewport as an image.
- **params:** none

---

## Input Simulation

### `simulate_action`
Fires a named input action.
- **params:** `action`, `pressed` (true/false), `strength` (0.0–1.0)

### `simulate_key`
Presses or releases a key.
- **params:** `keycode`, `pressed`, `modifiers`

### `simulate_mouse_click`
Clicks at screen coordinates.
- **params:** `position` ([x, y]), `button` (left/right/middle), `pressed`

### `simulate_mouse_move`
Moves mouse to coordinates.
- **params:** `position` ([x, y])

### `simulate_sequence`
Executes a timed series of input events.
- **params:** `events` (array of {type, params, delay_ms})

---

## Testing

### `run_test_scenario`
Runs a named test scenario.
- **params:** `scenario_name`, `scene_path`

### `get_test_report`
Returns results from the last test run.
- **params:** none

### `assert_node_state`
Asserts node property value. Fails if mismatch.
- **params:** `node_path`, `property`, `expected_value`

### `assert_screen_text`
Asserts text appears in the viewport.
- **params:** `text`, `timeout_seconds`

### `capture_frames`
Captures N frames as images.
- **params:** `count`, `interval_ms`, `output_path`

### `start_recording`
Begins recording game frames.
- **params:** `output_path`, `fps`

### `stop_recording`
Ends recording and saves file.
- **params:** none

### `record_frames`
Records and saves in one call.
- **params:** `duration_seconds`, `output_path`

### `replay_recording`
Plays back a recording.
- **params:** `recording_path`

### `compare_screenshots`
Computes pixel diff between two images.
- **params:** `image_a_path`, `image_b_path`, `tolerance`

### `run_stress_test`
Runs the game under load.
- **params:** `duration_seconds`, `scene_path`

---

## Performance & Debugging

### `get_editor_errors`
Returns errors shown in editor output.
- **params:** none

### `get_editor_performance`
Returns editor memory and CPU stats.
- **params:** none

### `get_performance_monitors`
Returns runtime FPS, draw calls, physics time, memory.
- **params:** none (game must be running)

### `monitor_properties`
Watches property values change over time.
- **params:** `node_paths`, `properties`, `interval_ms`, `duration_ms`

### `get_output_log`
Returns full output log text.
- **params:** `lines` (optional, last N lines)

### `clear_output`
Clears the output log.
- **params:** none

### `get_editor_screenshot`
Captures the editor UI.
- **params:** none

---

## Tilemap

### `tilemap_get_info`
Returns layers, tileset, and cell size.
- **params:** `node_path`

### `tilemap_set_cell`
Places a tile.
- **params:** `node_path`, `layer`, `coords` ([x, y]), `source_id`, `atlas_coords`, `alternative_tile`

### `tilemap_get_cell`
Reads the tile at coordinates.
- **params:** `node_path`, `layer`, `coords`

### `tilemap_fill_rect`
Fills a rectangle of cells.
- **params:** `node_path`, `layer`, `start`, `end`, `source_id`, `atlas_coords`

### `tilemap_clear`
Clears all cells (or a layer).
- **params:** `node_path`, `layer` (optional)

### `tilemap_get_used_cells`
Returns all occupied cell coordinates.
- **params:** `node_path`, `layer`

---

## Export

### `list_export_presets`
Lists all configured export presets.
- **params:** none

### `get_export_info`
Returns preset platform, path, and options.
- **params:** `preset_name`

### `export_project`
Builds the project.
- **params:** `preset_name`, `output_path`, `debug` (true/false)

---

## Editor & Plugin Management

### `reload_plugin`
Reloads a plugin.
- **params:** `plugin_name`

### `reload_project`
Full project reload. Use sparingly.
- **params:** none

### `navigate_to`
Opens a file in the editor.
- **params:** `path`

### `move_to`
Moves the 3D viewport camera to a position.
- **params:** `position`, `scene_path` (optional)
