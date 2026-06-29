# Codebase Map (auto-generated)

> Quay về [[🎯 Project Index]]
>
> **AUTO-GENERATED — đừng sửa tay.** Regenerate: `bash tools/gen_codebase_map.sh` từ project root.
> Generated: 2026-06-28 23:32
>
> ⚠️ Đây là SNAPSHOT. Verify path / func / line ở file thật trước khi sửa code.

## Autoloads (project.godot)
```ini
Audio="*uid://cujwm7u5pvogl"
InputHelper="*uid://cholww48njaeh"
CogitoGlobals="*uid://d0q71mnw6am11"
CogitoQuestManager="*uid://c33l80dv3c6c5"
CogitoSceneManager="*uid://dwd61hyssfy55"
MenuTemplateManager="*uid://dru131jwwih1y"
MCPScreenshot="*res://addons/godot_mcp/mcp_screenshot_service.gd"
MCPInputService="*res://addons/godot_mcp/mcp_input_service.gd"
MCPGameInspector="*res://addons/godot_mcp/mcp_game_inspector_service.gd"
```

## Input actions (project.godot)
```
forward
back
left
right
jump
crouch
sprint
menu
free_look
interact
interact2
action_primary
action_secondary
inventory
inventory_move_item
inventory_use_item
inventory_drop_item
inventory_assign_item
inventory_rotate_item
quickslot_1
quickslot_2
quickslot_3
quickslot_4
reload
ui_next_tab
ui_prev_tab
quickslot_prev_wieldable
quickslot_next_wieldable
free_cursor
```

## Project scripts — `Scripts/` (detailed: class_name · extends · funcs)

### `Scripts/Enemies/States/npc_state_shoot.gd`
- extends: `Node`
- funcs:
```gdscript
    34:func _state_enter(_args = null) -> void:
    46:func _state_exit() -> void:
    50:func _physics_process(delta: float) -> void:
    87:func _brake(delta: float) -> void:
    96:func _get_muzzle_pos() -> Vector3:
    103:func _cast_ray(from: Vector3, to: Vector3) -> Dictionary:
    111:func _result_hits_target(result: Dictionary) -> bool:
    118:func _shoot() -> void:
    141:func _apply_damage() -> void:
```

### `Scripts/Enemies/scav.gd`
- class_name: `Scav`
- extends: `CogitoNPC`
- funcs:
```gdscript
    9:func _ready() -> void:
    14:func _connect_security_camera() -> void:
    24:func _on_detection_lost() -> void:
```

### `Scripts/Player/player_interaction_component_delayed_reload.gd`
- class_name: `PlayerInteractionComponentDelayedReload`
- extends: `PlayerInteractionComponent`
- funcs:
```gdscript
    4:func attempt_reload() -> void:
```

### `Scripts/Tool/capture_icon.gd`
- extends: `Node3D`
- funcs:
```gdscript
    24:func _ready() -> void:
    35:func _process(_delta: float) -> void:
    47:func _normalize_save_path() -> String:
    57:func _get_icon_modified_time(resource_path: String) -> int:
    64:func _refresh_saved_icon_in_editor(resource_path: String) -> void:
    80:func _save_icon() -> void:
```

### `Scripts/Weapons/Helpers/ads_controller.gd`
- class_name: `ADSController`
- extends: `RefCounted`
- funcs:
```gdscript
    17:func _init(owner: Node3D) -> void:
    21:func enter(weapon_data: Weapon_Resource, ads_fov: float, ads_time: float,
    43:func exit(weapon_data: Weapon_Resource, ads_fov: float, ads_time: float,
    63:func cancel_tweens_and_snap(weapon_data: Weapon_Resource, ads_fov: float,
    77:func get_rest_position(weapon_data: Weapon_Resource, ads_position: Vector3,
    84:func _play_transition(weapon_data: Weapon_Resource, ads_fov: float, ads_time: float,
    121:func _cancel_tweens() -> void:
    130:func _apply_scope_sensitivity(pic: PlayerInteractionComponent) -> void:
    147:func _restore_scope_sensitivity(pic: PlayerInteractionComponent) -> void:
```

### `Scripts/Weapons/Helpers/ammo_manager.gd`
- class_name: `AmmoManager`
- extends: `RefCounted`
- funcs:
```gdscript
    9:func _init(pic: PlayerInteractionComponent) -> void:
    13:func set_pic(pic: PlayerInteractionComponent) -> void:
    17:func get_inventory() -> CogitoInventory:
    23:func get_available_ammo(item_ref: WieldableItemPD) -> int:
    40:func consume_ammo(item_ref: WieldableItemPD, ammo_needed: int) -> int:
    71:func return_ammo(item_ref: WieldableItemPD, amount: int) -> void:
    98:func finish_reload(item_ref: WieldableItemPD) -> void:
```

### `Scripts/Weapons/Helpers/firearm_debug_ui.gd`
- class_name: `FirearmDebugUI`
- extends: `CanvasLayer`
- funcs:
```gdscript
    7:func _ready() -> void:
    31:func update_debug_info(weapon_name: String, state_str: String, mechanics: FirearmMechanicalState) -> void:
```

### `Scripts/Weapons/Helpers/firearm_mechanical_state.gd`
- class_name: `FirearmMechanicalState`
- extends: `RefCounted`
- funcs:
```gdscript
    19:func configure(config: Dictionary) -> void:
    28:func reconstruct_from_total(total: int) -> void:
    52:func to_save_dict() -> Dictionary:
    62:func restore_from_save_dict(state: Dictionary) -> bool:
    72:func can_fire() -> bool:
    76:func fire_round() -> void:
    81:func cycle_action() -> void:
    89:func finish_reload_tactical(reserve_rounds: int) -> int:
    97:func finish_reload_empty(reserve_rounds: int) -> int:
    127:func get_loaded_total() -> int:
    131:func is_empty() -> bool:
    135:func _clamp_dynamic_state() -> void:
```

### `Scripts/Weapons/Helpers/shoot_motion_controller.gd`
- class_name: `ShootMotionController`
- extends: `RefCounted`
- funcs:
```gdscript
    31:func _init(owner: Node3D) -> void:
    35:func play(rest_position: Vector3, rest_rotation: Vector3, is_aiming: bool) -> void:
    66:func get_duration() -> float:
    74:func cancel(_restore_rest: bool) -> void:
    89:func release_fire_part_lock() -> void:
    102:func _on_finished() -> void:
```

### `Scripts/Weapons/Helpers/trigger_animator.gd`
- class_name: `TriggerAnimator`
- extends: `RefCounted`
- funcs:
```gdscript
    14:func _init(owner: Node3D) -> void:
    19:func has_trigger() -> bool:
    23:func pull(target_z_deg: float) -> void:
    32:func release_delayed(target_z_deg: float, delay: float) -> void:
    43:func _kill_tween() -> void:
```

### `Scripts/Weapons/Types/AssaultRifle_Resource.gd`
- class_name: `AssaultRifle_Resource`
- extends: `Weapon_Resource`
- funcs:
```gdscript
    10:func _init() -> void:
    17:func get_fire_mode() -> FireMode:
    20:func get_fire_cooldown() -> float:
```

### `Scripts/Weapons/Types/BoltAction_Resource.gd`
- class_name: `BoltAction_Resource`
- extends: `Weapon_Resource`
- funcs:
```gdscript
    5:func _init() -> void:
    48:func get_fire_mode() -> FireMode:
    52:func handles_own_shell_eject(weapon: Node) -> bool:
    59:func play_post_fire_visual(weapon: Node) -> void:
    69:func on_anim_finished(weapon: Node, anim_name: StringName) -> void:
    82:func on_reset(weapon: Node) -> void:
    91:func _start_cycle(firearm: CogitoFirearm) -> void:
    106:func _finish_cycle(firearm: CogitoFirearm) -> void:
    113:func _get_cycle_anim_name(firearm: CogitoFirearm) -> String:
    120:func _is_bolt_cycle_anim(firearm: CogitoFirearm, anim_name: StringName) -> bool:
```

### `Scripts/Weapons/Types/GrenadeLauncher_Resource.gd`
- class_name: `GrenadeLauncher_Resource`
- extends: `Weapon_Resource`
- funcs:
```gdscript
    19:func get_fire_mode() -> FireMode:
    22:func fire(ctx: Dictionary) -> void:
```

### `Scripts/Weapons/Types/LMG_Resource.gd`
- class_name: `LMG_Resource`
- extends: `Weapon_Resource`
- funcs:
```gdscript
    17:func get_fire_mode() -> FireMode:
    20:func get_fire_cooldown() -> float:
    23:func can_fire(state: Dictionary) -> bool:
    26:func on_reload(ctx: Dictionary) -> bool:
    36:func tick(weapon: Node, delta: float) -> void:
    49:func play_post_fire_visual(weapon: Node) -> void:
    57:func on_anim_finished(weapon: Node, anim_name: StringName) -> void:
```

### `Scripts/Weapons/Types/MarksmanRifle_Resource.gd`
- class_name: `MarksmanRifle_Resource`
- extends: `Weapon_Resource`
- funcs:
```gdscript
    15:func get_fire_mode() -> FireMode:
    18:func get_ads_fov_override() -> float:
    21:func get_ads_duration_override() -> float:
    24:func is_scope_weapon() -> bool:
```

### `Scripts/Weapons/Types/Pistol_Resource.gd`
- class_name: `Pistol_Resource`
- extends: `Weapon_Resource`
- funcs:
```gdscript
    5:func _init() -> void:
    29:func get_fire_mode() -> FireMode:
    32:func get_fire_cooldown() -> float:
    36:func play_post_fire_visual(weapon: Node) -> void:
    47:func on_anim_finished(weapon: Node, anim_name: StringName) -> void:
    54:func on_reset(weapon: Node) -> void:
```

### `Scripts/Weapons/Types/Revolver_Resource.gd`
- class_name: `Revolver_Resource`
- extends: `Weapon_Resource`
- funcs:
```gdscript
    16:func get_fire_mode() -> FireMode:
    19:func get_fire_cooldown() -> float:
```

### `Scripts/Weapons/Types/Shotgun_Resource.gd`
- class_name: `Shotgun_Resource`
- extends: `Weapon_Resource`
- funcs:
```gdscript
    5:func _init() -> void:
    30:func get_fire_mode() -> FireMode:
    33:func fire(ctx: Dictionary) -> void:
    60:func play_post_fire_visual(weapon: Node) -> void:
    72:func on_anim_finished(weapon: Node, anim_name: StringName) -> void:
    89:func _start_pump(firearm: CogitoFirearm) -> void:
    98:func _finish_pump(firearm: CogitoFirearm) -> void:
```

### `Scripts/Weapons/Weapon_Resource.gd`
- class_name: `Weapon_Resource`
- extends: `Resource`
- funcs:
```gdscript
    26:func get_mechanics_config() -> Dictionary:
    42:func get_fire_mode() -> FireMode:
    48:func get_fire_cooldown() -> float:
    56:func fire(ctx: Dictionary) -> void:
    64:func on_post_fire(_ctx: Dictionary) -> bool:
    70:func can_fire(_state: Dictionary) -> bool:
    77:func on_reload(_ctx: Dictionary) -> bool:
    83:func tick(_weapon: Node, _delta: float) -> void:
    90:func play_post_fire_visual(_weapon: Node) -> void:
    97:func on_anim_finished(_weapon: Node, _anim_name: StringName) -> void:
    103:func on_reset(_weapon: Node) -> void:
    111:func handles_own_shell_eject(_weapon: Node) -> bool:
    117:func get_ads_fov_override() -> float:
    121:func get_ads_duration_override() -> float:
    124:func is_scope_weapon() -> bool:
    133:func _hitscan_fire(ctx: Dictionary) -> void:
    152:func _projectile_fire(ctx: Dictionary) -> void:
    171:static func _deal_damage(collider: Node, direction: Vector3, hit_position: Vector3, item_ref: WieldableItemPD) -> void:
```

### `Scripts/Weapons/cogito_weapon.gd`
- class_name: `CogitoFirearm`
- extends: `CogitoWieldable`
- funcs:
```gdscript
    142:func _ready() -> void:
    163:func _physics_process(delta: float) -> void:
    194:func equip(_player_interaction_component: PlayerInteractionComponent) -> void:
    222:func unequip() -> void:
    259:func action_primary(_passed_item_reference: InventoryItemPD, _is_released: bool) -> void:
    296:func action_secondary(_is_released: bool) -> void:
    317:func reload() -> void:
    350:func cancel_ads_for_sprint() -> void:
    363:func is_ads_active() -> bool:
    367:func should_suspend_container_motion() -> bool:
    376:func _try_fire() -> void:
    441:func _build_fire_context() -> Dictionary:
    456:func _play_shoot_visual() -> bool:
    465:func _on_shoot_visual_finished() -> void:
    469:func _get_shoot_visual_duration() -> float:
    476:func _schedule_post_fire_cycle(delay: float, on_cycle: Callable) -> void:
    487:func _complete_cycle_after_delay(delay: float, on_done: Callable) -> void:
    498:func _on_anim_finished(anim_name: StringName) -> void:
    515:func _finish_reload_with_mechanics() -> void:
    545:func on_cycle_complete() -> void:
    555:func _commit_mechanics_to_item() -> void:
    569:func _restore_mechanics_from_item() -> void:
    585:func _apply_mechanics_visual_state() -> void:
    600:func _configure_recoil() -> void:
    616:func _apply_recoil() -> void:
    625:func _get_recoil_node() -> Node3D:
    634:func _is_player_sprinting() -> bool:
    641:func _get_reload_animation_name() -> String:
    655:func _is_reload_animation(anim_name: StringName) -> bool:
    662:func _uses_animation_shoot_motion() -> bool:
    669:func _get_shoot_animation_name() -> String:
    675:func _is_shoot_animation_name(anim_name: StringName) -> bool:
    679:func _is_shoot_animation_playing() -> bool:
    683:func _run_bolt_tween() -> void:
    745:func _run_pistol_parts_tween() -> void:
    758:func _sync_shoot_motion_config() -> void:
    771:func _resolve_fire_part() -> void:
    779:func _capture_rest_state() -> void:
    786:func _apply_rest_pose() -> void:
    793:func _reset_state() -> void:
    815:func _play_reload_sound() -> void:
    822:func _spawn_muzzle_flash_fpv() -> void:
    843:func _spawn_shell_casing() -> void:
```

### `Scripts/Weapons/scope_controller.gd`
- class_name: `ScopeController`
- extends: `Node3D`
- funcs:
```gdscript
    63:func get_sensitivity_multiplier() -> float:
    211:func _ready() -> void:
    225:func set_magnification(value: float) -> void:
    229:func get_scope_fov() -> float:
    236:func switch_reticle(type: ReticleType) -> void:
    243:func _apply_magnification() -> void:
    254:func _apply_reticle_type() -> void:
    269:func _setup_reticle_layer() -> void:
    280:func _load_reticle_scene() -> void:
    292:func _rebuild_reticle_layer() -> void:
    296:func _remove_reticle_layer() -> void:
    305:func _set_shader(param: String, value: Variant) -> void:
```

### `Scripts/Weapons/shell_casing_fx.gd`
- class_name: `ShellCasingFx`
- extends: `RigidBody3D`
- funcs:
```gdscript
    15:func _ready() -> void:
    23:func _eject() -> void:
```

### `Scripts/Weapons/weapon_recoil.gd`
- extends: `Node3D`
- funcs:
```gdscript
    71:func _ready() -> void:
    78:func _process(delta: float) -> void:
    108:func recoil_fire(is_aiming: bool = false) -> void:
    131:func set_recoil(new_recoil: Vector3) -> void:
    135:func set_aim_recoil(new_recoil: Vector3) -> void:
    141:func add_trauma(amount: float) -> void:
    145:func _apply_shake() -> void:
    175:func recoilFire(is_aiming: bool = false) -> void:
    179:func setRecoil(new_recoil: Vector3) -> void:
    183:func setAimRecoil(new_recoil: Vector3) -> void:
```

## addons/cogito — class index (shallow: class_name · extends · role)

| class_name | extends | file | role (first ## doc) |
|---|---|---|---|
| `ConvertedMaterial` | `ShaderMaterial` | addons/cogito/Assets/Shader/ConvertedStandardMaterial3D.gd | See Material3DConversion. Any changes made to this will not stick if you go back to the regular models by unbaking! |
| `Material3DConversion` | `BaseMaterial3D` | addons/cogito/Assets/Shader/Material3DConversion.gd |  |
| `ShaderPrecompiler` | `Node3D` | addons/cogito/Assets/Shader/ShaderPrecompiler.gd | Returns the node being used to compile shaders |
| `ShaderSpace` | `Node3D` | addons/cogito/Assets/Shader/ShaderSpace.gd | Node to override any materials with a ShaderMaterial -- useful for applying shaders to lots of StandardMaterials |
| `ViewmodelSpace` | `ShaderSpace` | addons/cogito/Assets/Shader/ViewmodelSpace.gd | This node will configure all meshes childed inside of it (recursively) to act without clipping through wall, useful for wieldable viewmodels to keep them in-front |
| `CogitoBodyDrag` | `Node3D` | addons/cogito/CogitoNPC/cogito_body_drag.gd | Name that will displayed when interacting. Leave blank to hide |
| `CogitoNPC` | `CharacterBody3D` | addons/cogito/CogitoNPC/cogito_npc.gd | Emitted when received damage. Used with the HitboxComponent |
| `CogitoPatrolPath` | `Node` | addons/cogito/CogitoNPC/cogito_patrol_path.gd | List of patrol points which the enemy will move to in order. |
| `CogitoButton` | `Node3D` | addons/cogito/CogitoObjects/cogito_button.gd | This sets where interaction prompt gets displayed on the object. |
| `CogitoContainer` | `Node3D` | addons/cogito/CogitoObjects/cogito_container.gd | Name that will displayed when interacting. Leave blank to hide |
| `CogitoDoor` | `Node3D` | addons/cogito/CogitoObjects/cogito_door.gd | Name that will displayed when interacting. Leave blank to hide |
| `CogitoKeypad` | `Node3D` | addons/cogito/CogitoObjects/cogito_keypad.gd | Emitted when the correct code has been entered. |
| `LootDropContainer extends CogitoContainer` | `?` | addons/cogito/CogitoObjects/cogito_loot_drop_container.gd | Enables the debug prints. There are quite a few so output may be crowded. |
| `LootableContainer extends CogitoContainer` | `?` | addons/cogito/CogitoObjects/cogito_lootable_container.gd | Enables the debug prints. There are quite a few so output may be crowded. |
| `CogitoObject` | `Node3D` | addons/cogito/CogitoObjects/cogito_object.gd | Name that will displayed when interacting. Leave blank to hide |
| `CogitoPlayer` | `CharacterBody3D` | addons/cogito/CogitoObjects/cogito_player.gd | The player class controls movement from input from the mouse, keyboard, and gamepad, as well as behavior parameters like stair and ladder handling. |
| `CogitoPressureplate` | `Node3D` | addons/cogito/CogitoObjects/cogito_pressure_plate.gd | Sets this pressure plate as active (can be activated etc) |
| `CogitoProjectile` | `CogitoObject` | addons/cogito/CogitoObjects/cogito_projectile.gd | Derived from CogitoObject, this class handles additional information for projectiles like lifespan, damage, destroy_on_impact. Some of these are inherited from the Wieldable that spawns this projectile. |
| `CogitoSecurityCamera` | `Node3D` | addons/cogito/CogitoObjects/cogito_security_camera.gd | Threshold at which Player is detected |
| `CogitoSittable` | `Node3D` | addons/cogito/CogitoObjects/cogito_sittable.gd | Name that will displayed when interacting. Leave blank to hide |
| `CogitoSnapSlot` | `Node3D` | addons/cogito/CogitoObjects/cogito_snap_slot.gd | PackedScene of the carryable object that this snapslot is expecting. |
| `CogitoStaticInteractable` | `Node3D` | addons/cogito/CogitoObjects/cogito_static_interactable.gd | Name that will displayed when interacting. Leave blank to hide |
| `CogitoSwitch` | `Node3D` | addons/cogito/CogitoObjects/cogito_switch.gd | Name that will displayed when interacting. Leave blank to hide |
| `CogitoVehicle` | `CogitoSittable` | addons/cogito/CogitoObjects/cogito_vehicle.gd |  |
| `CogitoAttribute` | `Node` | addons/cogito/Components/Attributes/cogito_attribute.gd | Triggered whenever any of the attribute values changes. |
| `CogitoHealthAttribute` | `CogitoAttribute` | addons/cogito/Components/Attributes/cogito_health_attribute.gd | Emitted when health is reduced. |
| `CogitoLightmeter` | `CogitoAttribute` | addons/cogito/Components/Attributes/cogito_light_meter_attribute.gd | Should light be updating constantly or only when player moves? Disable to constantly update at the cost of performance |
| `CogitoSanityAttribute` | `CogitoAttribute` | addons/cogito/Components/Attributes/cogito_sanity_attribute.gd | The rate at which sanity decays when decaying. |
| `CogitoStaminaAttribute` | `CogitoAttribute` | addons/cogito/Components/Attributes/cogito_stamina_attribute.gd | If unused, running only drains stamina at the base run exhaustion speed |
| `CogitoVisibilityAttribute` | `CogitoAttribute` | addons/cogito/Components/Attributes/cogito_visibility_attribute.gd |  |
| `AutoConsume` | `Node` | addons/cogito/Components/AutoConsumes/auto_consume.gd | The value beyond which the first valid consumables in inventory will automatically be used. |
| `HealthAutoConsume` | `AutoConsume` | addons/cogito/Components/AutoConsumes/health_auto_consume.gd | The max difference allowed between value_current and full_damage, where auto-consume is permitted |
| `StaminaAutoConsume` | `AutoConsume` | addons/cogito/Components/AutoConsumes/stamina_auto_consume.gd |  |
| `AutoPickUpZone` | `Area3D` | addons/cogito/Components/AutoPickUpZone.gd | Items listed here will be picked up automatically when they enter the area |
| `CurrencyCheck` | `Node` | addons/cogito/Components/CurrencyCheckComponent.gd | How much it costs to use this button, If set to 0 currency interaction will be ignored |
| `DynamicInputIcon` | `Sprite2D` | addons/cogito/Components/DynamicInputIcon.gd | Name of action as called in the Input Map |
| `HitboxComponent` | `Node` | addons/cogito/Components/HitboxComponent.gd | PackedScene that will get spawned on global hit position |
| `ImpactAttributeDamage` | `Node3D` | addons/cogito/Components/ImpactAttributeDamage.gd | This is what will take damage |
| `ImpactSounds` | `Node3D` | addons/cogito/Components/ImpactSounds.gd | This is used to grab sounds to play. |
| `BackpackComponent` | `InteractionComponent` | addons/cogito/Components/Interactions/BackpackComponent.gd | Sound that plays when backpack is interacted with |
| `CogitoCarryableComponent` | `InteractionComponent` | addons/cogito/Components/Interactions/CarryableComponent.gd | Sets whether the object can be carried while wielding a weapon |
| `DualInteraction` | `HoldInteraction` | addons/cogito/Components/Interactions/DualInteraction.gd | Text that joins Press and Hold interaction text, for example:   " | (HOLD) " in  "Open | (HOLD) Unlock" |
| `ExtendedPickupInteraction` | `HoldInteraction` | addons/cogito/Components/Interactions/ExtendedPickupInteraction.gd | Add a linebreak here to separate the pickup interaction text from the hold interaction text |
| `HoldInteraction` | `InteractionComponent` | addons/cogito/Components/Interactions/HoldInteraction.gd |  |
| `InteractionComponent` | `Node3D` | addons/cogito/Components/Interactions/InteractionComponent.gd | Base class for any interactions based on input map actions. |
| `PickupComponent` | `InteractionComponent` | addons/cogito/Components/Interactions/PickupComponent.gd |  |
| `ReadableComponent` | `InteractionComponent` | addons/cogito/Components/Interactions/ReadableComponent.gd |  |
| `LootComponent extends Node3D ` | `?` | addons/cogito/Components/LootComponent.gd | Generates a bag of loot after death. This inventory is not a grid inventory, each dropped item will have its own slot. |
| `LootTable extends Resource` | `?` | addons/cogito/Components/LootTables/BaseLootTable.gd |  |
| `LootDropEntry extends Resource` | `?` | addons/cogito/Components/LootTables/LootDropEntry.gd | Name for this drop, only for human readability. |
| `PlayerInteractionComponent` | `Node3D` | addons/cogito/Components/PlayerInteractionComponent.gd | Raycast3D for interaction check. |
| `CogitoProperties` | `Node3D` | addons/cogito/Components/Properties/cogito_properties.gd | This class handles systeminc properties. Needs to be attached to a CogitoObject to work properly. For proper processing, said Object needs to have a signal hooked up to call check_for_systemic_interactions(collider). |
| `CogitoAttributeUi` | `Control` | addons/cogito/Components/UI/UI_AttributeComponent.gd |  |
| `CogitoAttributeDisplay` | `Control` | addons/cogito/Components/UI/UI_AttributeDisplay.gd |  |
| `UiHoldComponent` | `Control` | addons/cogito/Components/UI/UI_HoldComponent.gd | Buffer time until the hold is first registered, prevents showing Hold UI for presses |
| `UiObjectNameComponent` | `Control` | addons/cogito/Components/UI/UI_ObjectNameComponent.gd |  |
| `UiPromptComponent` | `Control` | addons/cogito/Components/UI/UI_PromptComponent.gd |  |
| `CogitoDynamicBar` | `ProgressBar` | addons/cogito/Components/UI/dynamic_bar.gd |  |
| `CogitoProgressWheel extends Control` | `?` | addons/cogito/Components/UI/ui_progress_wheel.gd |  |
| `FootstepMaterialLibrary` | `Resource` | addons/cogito/DynamicFootstepSystem/Scripts/footstep_material_library.gd |  |
| `FootstepMaterialProfile` | `Resource` | addons/cogito/DynamicFootstepSystem/Scripts/footstep_material_profile.gd |  |
| `FootstepSurface` | `Node3D` | addons/cogito/DynamicFootstepSystem/Scripts/footstep_surface.gd |  |
| `FootstepSurfaceDetector` | `AudioStreamPlayer3D` | addons/cogito/DynamicFootstepSystem/Scripts/footstep_surface_detector.gd |  |
| `CogitoSaveSlotButton` | `CogitoUiButton` | addons/cogito/EasyMenus/Components/SaveSlotButton.gd |  |
| `GamepadBindButton` | `Button` | addons/cogito/EasyMenus/Components/gamepad_bind_button.gd |  |
| `KbmBindButton` | `Button` | addons/cogito/EasyMenus/Components/kbm_bind_button.gd |  |
| `RemapEntry` | `Control` | addons/cogito/EasyMenus/Components/remap_entry.gd |  |
| `OptionsTabMenu` | `Control` | addons/cogito/EasyMenus/Scripts/OptionsTabMenu.gd |  |
| `CogitoDeathScreen` | `Control` | addons/cogito/EasyMenus/Scripts/cogito_death_screen.gd |  |
| `OptionsConstants` | `Node` | addons/cogito/EasyMenus/Scripts/options_constants.gd |  |
| `CogitoPauseMenu` | `Control` | addons/cogito/EasyMenus/Scripts/pause_menu_controller.gd | You can override this class to add buttons to your pause menu |
| `CogitoTabMenu` | `TabContainer` | addons/cogito/EasyMenus/Scripts/tab_menu.gd | This class can be extended to create a tab menu with controller support. |
| `CogitoQuickslots` | `Node` | addons/cogito/InventoryPD/CogitoQuickSlots.gd | # This script directly references the player inventory a lot, so make sure that reference is set correctly before using. |
| `AmmoItemPD` | `InventoryItemPD` | addons/cogito/InventoryPD/CustomResources/AmmoItemPD.gd | The amount one item addes to the target item charge. For bullets this should be 1. |
| `CombinableItemPD` | `InventoryItemPD` | addons/cogito/InventoryPD/CustomResources/CombinableItemPD.gd | The name of the item that this item combines with. Caution: String has to be a perfect match, so watch casing and space. |
| `ConsumableEffect` | `Resource` | addons/cogito/InventoryPD/CustomResources/ConsumableEffect.gd | Name of attribute that the item is going to replenish. (For example "health") |
| `ConsumableItemPD` | `InventoryItemPD` | addons/cogito/InventoryPD/CustomResources/ConsumableItemPD.gd | Name of attribute that the item is going to replenish. (For example "health") |
| `CurrencyItemPD` | `InventoryItemPD` | addons/cogito/InventoryPD/CustomResources/CurrencyItemPD.gd | Name of attribute that the item is going to replenish. (For example "health") |
| `InventoryItemPD` | `Resource` | addons/cogito/InventoryPD/CustomResources/InventoryItemPD.gd | Name of Item as it appears in game. |
| `InventorySlotPD` | `Resource` | addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd |  |
| `ItemValue` | `Resource` | addons/cogito/InventoryPD/CustomResources/ItemValue.gd | Name of currency that this item value represents |
| `KeyItemPD` | `InventoryItemPD` | addons/cogito/InventoryPD/CustomResources/KeyItemPD.gd | If this is checked, the key item will be removed from the inventory after it's been used on the target object. CAUTION: If you set this to true, make sure there are enough keys in your game to open all doors that require them. Otherwise you might softlock your player. |
| `WieldableItemPD` | `InventoryItemPD` | addons/cogito/InventoryPD/CustomResources/WieldableItemPD.gd | Icon that is displayed on the HUD when item is wielded. If NULL, the item icon will be used instead. |
| `CogitoCurrency` | `Node` | addons/cogito/InventoryPD/CustomResources/cogito_currency.gd | Triggered whenever any of the attribute values changes. |
| `CogitoQuickslotContainer` | `Control` | addons/cogito/InventoryPD/UiScenes/CogitoQuickslotContainer.gd | AudioStream that plays when slot gets highlighted. |
| `SlotPanel extends PanelContainer` | `?` | addons/cogito/InventoryPD/UiScenes/Slot.gd | AudioStream that plays when slot gets highlighted. |
| `CogitoInventory` | `Resource` | addons/cogito/InventoryPD/cogito_inventory.gd | Enables grid inventory. If using, make sure player and ALL interactables have this set to true. |
| `LootGenerator extends Node` | `?` | addons/cogito/InventoryPD/cogito_loot_generator.gd | Handles loot generation from passed loot table and returns an array of dictionary. |
| `TranslationKeyDict` | `Resource` | addons/cogito/Localization/scripts/translation_key_dict.gd |  |
| `CogitoQuestUpdater` | `Node3D` | addons/cogito/QuestSystem/Components/cogito_quest_updater.gd | Amount by which the quest counter changes. Can be positive or negative. |
| `QuestEntry` | `Control` | addons/cogito/QuestSystem/Components/quest_entry.gd |  |
| `CogitoQuest` | `Resource` | addons/cogito/QuestSystem/CustomResources/cogito_quest.gd |  |
| `CogitoQuestGroup` | `Node` | addons/cogito/QuestSystem/CustomResources/cogito_quest_group.gd |  |
| `ActiveQuestsGroup` | `CogitoQuestGroup` | addons/cogito/QuestSystem/QuestGroups/active_quests_group.gd |  |
| `AvailableQuestsGroup` | `CogitoQuestGroup` | addons/cogito/QuestSystem/QuestGroups/available_quests_group.gd |  |
| `CompletedQuestsGroup` | `CogitoQuestGroup` | addons/cogito/QuestSystem/QuestGroups/completed_quests_group.gd |  |
| `FailedQuestsGroup` | `CogitoQuestGroup` | addons/cogito/QuestSystem/QuestGroups/failed_quests_group.gd |  |
| `CogitoPlayerState` | `Resource` | addons/cogito/SceneManagement/cogito_player_state.gd |  |
| `CogitoSceneState` | `Resource` | addons/cogito/SceneManagement/cogito_scene_state.gd |  |
| `CogitoWorldPropertySetter` | `Node` | addons/cogito/SceneManagement/world_property_setter.gd | Properties to set when a TRUE bool signal is received. Also used when a void signal is received. |
| `BulletDecalPool` | `?` | addons/cogito/Scripts/bullet_decal_pool.gd | Credit to Majikayo Games SimpleFPSController for this code |
| `CogitoWieldable` | `Node3D` | addons/cogito/Scripts/cogito_wieldable.gd | Item resource that this wieldable refers to. |
| `CogitoWorldState` | `Resource` | addons/cogito/Scripts/cogito_world_state.gd |  |
| `InteractionRayCast` | `RayCast3D` | addons/cogito/Scripts/interaction_raycast.gd |  |
| `InteractionShapeCast` | `ShapeCast3D` | addons/cogito/Scripts/interaction_shapecast.gd |  |
| `CogitoPlayerHudManager` | `Control` | addons/cogito/Scripts/player_hud_manager.gd | Reference to the Node that has the player.gd script. |
| `CogitoUiButton` | `Button` | addons/cogito/Theme/CogitoUiButton.gd |  |
| `CogitoSettings extends Resource` | `?` | addons/cogito/cogito_settings.gd | When this is checked, most Cogito scripts and objects will print messages in the output. Turn this on if you want to track and understand certain behaviors or have issues. |

## Project scenes — `Scene/` (root node + script)

| scene | root node | script ext_resources |
|---|---|---|
| Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_1-4x24_riflescope.tscn | Tac3014x24Riflescope (Node3D) | res://Scripts/Weapons/scope_controller.gd  |
| Scene/Enemies/Scav.tscn | Scav (instanced) | res://Scripts/Enemies/scav.gd res://Scripts/Enemies/States/npc_state_shoot.gd res://addons/cogito/Components/LootComponent.gd  |
| Scene/Items/Bullets/45. ACP/45.ACP_Item.tscn | 7_62x39MmItem (RigidBody3D) | res://addons/cogito/CogitoObjects/cogito_object.gd res://addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd  |
| Scene/Items/Bullets/76239/7.62x39mm_Item.tscn | 7_62x39MmItem (RigidBody3D) | res://addons/cogito/CogitoObjects/cogito_object.gd res://addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd  |
| Scene/Items/Bullets/76251/7_62x_51mm_item.tscn | 7_62x51mm_Item (instanced) | res://addons/cogito/CogitoObjects/cogito_object.gd res://addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd  |
| Scene/Object/Deco/Crate/crate.tscn | Crate (RigidBody3D) |  |
| Scene/Object/Deco/Crate/crate1.tscn | Crate (Node3D) |  |
| Scene/Object/Deco/Crate/crate2.tscn | Crate (Node3D) |  |
| Scene/Object/Deco/Crate/crate3.tscn | Crate (Node3D) |  |
| Scene/Object/Deco/Crate/crate4.tscn | Crate (Node3D) |  |
| Scene/Object/Deco/OfficeProps.tscn | OfficeProps (StaticBody3D) |  |
| Scene/Object/Deco/OfficeProps2.tscn | OfficeProps (StaticBody3D) |  |
| Scene/Object/Deco/PC.tscn | Pc (Node3D) |  |
| Scene/Object/Deco/ksi_counter.tscn | KSI_counter (StaticBody3D) |  |
| Scene/Object/Deco/tactical_gun_wall.tscn | TacticalGunWall (Node3D) |  |
| Scene/Object/House1.tscn | House1 (Node3D) | res://addons/cogito/CogitoObjects/cogito_door.gd res://addons/cogito/CogitoObjects/cogito_button.gd  |
| Scene/Town.tscn | Town (Node3D) | res://addons/cogito/SceneManagement/cogito_scene.gd res://addons/cogito/InventoryPD/cogito_inventory.gd res://addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd res://addons/cogito/CogitoNPC/cogito_patrol_path.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/muzzle_flash/muzzle_flash_01.tscn | MuzzleFlash_01 (Node3D) | res://Scene/VFX/MuzzleFlash/shared/script/vfx_controller.gd res://Scene/VFX/MuzzleFlash/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/muzzle_flash/muzzle_flash_02.tscn | MuzzleFlash_02 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/muzzle_flash/muzzle_flash_03.tscn | MuzzleFlash_03 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/muzzle_flash/muzzle_flash_04.tscn | MuzzleFlash_04 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/muzzle_flash/muzzle_flash_05.tscn | MuzzleFlash_05 (Node3D) | res://Scene/VFX/MuzzleFlash/shared/script/vfx_controller.gd res://Scene/VFX/MuzzleFlash/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/muzzle_flash/muzzle_flash_06.tscn | MuzzleFlash_06 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/short_flash/short_flash_01.tscn | ShortFlash_01 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/short_flash/short_flash_02.tscn | ShortFlash_02 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/short_flash/short_flash_03.tscn | ShortFlash_03 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/short_flash/short_flash_04.tscn | ShortFlash_04 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/short_flash/short_flash_05.tscn | ShortFlash_05 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/short_flash/short_flash_06.tscn | ShortFlash_06 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/VFX/MuzzleFlash/muzzle_flash/effects/wide_flash/wide_flash_01.tscn | WideFlash_01 (Node3D) | res://assets/BinbunVFX/shared/script/vfx_controller.gd res://assets/BinbunVFX/shared/script/vfx_light.gd  |
| Scene/Weapom/BulletProjectil&shelle/45. ACP/45acp projectile.tscn | 45AcpProjectile (RigidBody3D) | res://addons/cogito/CogitoObjects/cogito_projectile.gd  |
| Scene/Weapom/BulletProjectil&shelle/45. ACP/45acpshell_casing_fx.tscn | 7_62x39ShellCasingFx_tscn (RigidBody3D) | res://Scripts/Weapons/shell_casing_fx.gd  |
| Scene/Weapom/BulletProjectil&shelle/45. ACP/7_62x39ShellCasingFx_tscn.tscn | 919 case (MeshInstance3D) |  |
| Scene/Weapom/BulletProjectil&shelle/7.62x39/7.62x39 projectile.tscn | 7_62x39Projectile (RigidBody3D) | res://addons/cogito/CogitoObjects/cogito_projectile.gd  |
| Scene/Weapom/BulletProjectil&shelle/7.62x39/7.62x39shell.tscn | 76239 (MeshInstance3D) |  |
| Scene/Weapom/BulletProjectil&shelle/7.62x39/7.62x39shell_casing_fx.tscn.tscn | 7_62x39ShellCasingFx_tscn (RigidBody3D) | res://Scripts/Weapons/shell_casing_fx.gd  |
| Scene/Weapom/BulletProjectil&shelle/7.62x51/7.62x51 projectile.tscn | 7_62x39Projectile (RigidBody3D) | res://addons/cogito/CogitoObjects/cogito_projectile.gd  |
| Scene/Weapom/BulletProjectil&shelle/7.62x51/7.62x51shell_casing_fx.tscn | 7_62x39ShellCasingFx_tscn (RigidBody3D) | res://Scripts/Weapons/shell_casing_fx.gd  |
| Scene/Weapom/Firearms/AR/AK47/AK47.tscn | Ak47 (Node3D) | res://Scripts/Weapons/cogito_weapon.gd  |
| Scene/Weapom/Firearms/AR/AK47/AK47_Drop.tscn | Ak47 (Node3D) |  |
| Scene/Weapom/Firearms/AR/AK47/pickup_ak47.tscn | Pickup_AK47 (RigidBody3D) | res://addons/cogito/CogitoObjects/cogito_object.gd res://addons/cogito/Components/Interactions/PickupComponent.gd res://addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd  |
| Scene/Weapom/Firearms/Bolt-action/M700/M700_Drop.tscn | m700 (Node3D) |  |
| Scene/Weapom/Firearms/Bolt-action/M700/m700.tscn | m700 (Node3D) | res://Scripts/Weapons/cogito_weapon.gd  |
| Scene/Weapom/Firearms/Bolt-action/M700/pickup_m700.tscn | Pickup_m700 (RigidBody3D) | res://addons/cogito/CogitoObjects/cogito_object.gd res://addons/cogito/Components/Interactions/PickupComponent.gd res://addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd  |
| Scene/Weapom/Firearms/Pistol/USP/USP.tscn | USP (Node3D) | res://Scripts/Weapons/cogito_weapon.gd  |
| Scene/Weapom/Firearms/Pistol/USP/USP_drop.tscn | USP (Node3D) |  |
| Scene/Weapom/Firearms/Pistol/USP/pickup_usp.tscn | Pickup_usp (RigidBody3D) | res://addons/cogito/CogitoObjects/cogito_object.gd res://addons/cogito/Components/Interactions/PickupComponent.gd res://addons/cogito/InventoryPD/CustomResources/InventorySlotPD.gd  |

---
_Stats: 23 project scripts · 179 cogito scripts · 47 project scenes._
