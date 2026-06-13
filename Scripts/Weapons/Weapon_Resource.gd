extends Resource
class_name Weapon_Resource


@export var weaponName: String
@export_group("Recoil")
@export var recoilVertical: float
@export var recoilHorizontal: float
@export var recoilRecovery: float


@export_flags("Hitscan", "Projectile") var Type
@export var bulletProjectileToLoad: PackedScene
@export var weaponVelocity: int

@export_group("Firearm Mechanics")
@export var magazine_capacity: int = 30
@export var chamber_capacity: int = 1
@export var supports_chamber_plus_one: bool = true
@export var starts_chambered: bool = true
@export var closed_bolt: bool = true
@export var locks_open_on_empty: bool = false
@export var auto_chambers_on_empty_reload: bool = true
@export var manual_cycle_required: bool = false

func get_mechanics_config() -> Dictionary:
	return {
		"magazine_capacity": magazine_capacity,
		"chamber_capacity": chamber_capacity,
		"supports_chamber_plus_one": supports_chamber_plus_one,
		"auto_chambers_on_empty_reload": auto_chambers_on_empty_reload,
		"locks_open_on_empty": locks_open_on_empty,
	}


# ── Fire Type (matches @export_flags bit positions) ───────────────────────────
enum FireType { HITSCAN = 1, PROJECTILE = 2 }

# ── Fire Mode ──────────────────────────────────────────────────────────────────
enum FireMode { SEMI, AUTO, BOLT_ACTION, PUMP, REVOLVER }

func get_fire_mode() -> FireMode:
	return FireMode.SEMI


# ── Virtual: Fire cooldown ─────────────────────────────────────────────────────
## Seconds between shots. Subclasses override for RPM-based or trigger-reset values.
func get_fire_cooldown() -> float:
	return 0.1


# ── Virtual: Fire dispatch ─────────────────────────────────────────────────────
## Execute the actual shot. Default dispatches hitscan or projectile based on Type.
## ctx keys: bullet_point, camera_collision, is_aiming, item_ref,
##           player_interaction_component, world_3d, viewport, scene_tree
func fire(ctx: Dictionary) -> void:
	match Type:
		FireType.HITSCAN: _hitscan_fire(ctx)
		FireType.PROJECTILE: _projectile_fire(ctx)


# ── Virtual: Post-fire actions (bolt cycle, pump, LMG heat) ───────────────────
## Return true if a post-fire cycle was requested. Set keys in ctx as needed.
func on_post_fire(_ctx: Dictionary) -> bool:
	return false


# ── Virtual: Can fire? (LMG heat, bolt not cycled, etc.) ──────────────────────
## state keys: current_heat
func can_fire(_state: Dictionary) -> bool:
	return true


# ── Virtual: Reload behavior ──────────────────────────────────────────────────
## Return true if this resource handled reload specially (e.g. LMG vent).
## ctx keys: current_heat, animation_player
func on_reload(_ctx: Dictionary) -> bool:
	return false


# ── Virtual: Per-frame tick ───────────────────────────────────────────────────
## Called every physics frame from the weapon. Used for heat decay, etc.
func tick(_weapon: Node, _delta: float) -> void:
	pass


# ── Virtual: Post-fire visual ─────────────────────────────────────────────────
## Called after a confirmed shot. Run any type-specific visual side-effects
## (bolt root tween, hammer tween, slide-lock detection).
func play_post_fire_visual(_weapon: Node) -> void:
	pass


# ── Virtual: Animation finished ───────────────────────────────────────────────
## Called from the weapon's _on_anim_finished. Use to react to bolt/pump/vent
## animations completing without polluting the orchestrator with type checks.
func on_anim_finished(_weapon: Node, _anim_name: StringName) -> void:
	pass


# ── Virtual: Reset state on equip ─────────────────────────────────────────────
## Called from the weapon's _reset_state. Snap mechanical parts to rest pose.
func on_reset(_weapon: Node) -> void:
	pass


# ── Virtual: Shell ejection ownership ─────────────────────────────────────────
## True if this resource drives its own shell-eject timing (e.g. bolt-action
## with a timed shell_eject_delay). When true, the orchestrator skips its
## ON_FIRE shell spawn so the resource can do it at the right moment.
func handles_own_shell_eject(_weapon: Node) -> bool:
	return false


# ── Virtual: ADS overrides ────────────────────────────────────────────────────
## Negative = use weapon's ads_fov export.
func get_ads_fov_override() -> float:
	return -1.0

## Negative = use weapon's ads_time export.
func get_ads_duration_override() -> float:
	return -1.0

func is_scope_weapon() -> bool:
	return false


# ── Shared fire implementations ───────────────────────────────────────────────

const COLLISION_MASK_DAMAGE: int = 0b0111
const HITSCAN_OVERSHOOT: float = 2.0

func _hitscan_fire(ctx: Dictionary) -> void:
	var bullet_point: Marker3D = ctx["bullet_point"]
	var collision_point: Vector3 = ctx["camera_collision"]
	var pic: PlayerInteractionComponent = ctx["player_interaction_component"]
	var item_ref: WieldableItemPD = ctx["item_ref"]
	var origin := bullet_point.global_position
	var direction := (collision_point - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(
		origin, collision_point + direction * HITSCAN_OVERSHOOT
	)
	if pic.player_rid:
		query.exclude = [pic.player_rid]
	query.collision_mask = COLLISION_MASK_DAMAGE
	var world: World3D = ctx["world_3d"]
	var result := world.direct_space_state.intersect_ray(query)
	if result:
		_deal_damage(result.collider, direction, result.position, item_ref)


func _projectile_fire(ctx: Dictionary) -> void:
	if bulletProjectileToLoad == null:
		return
	var bullet_point: Marker3D = ctx["bullet_point"]
	var target_point: Vector3 = ctx["camera_collision"]
	var item_ref: WieldableItemPD = ctx["item_ref"]
	var scene_tree: SceneTree = ctx["scene_tree"]
	var direction := (target_point - bullet_point.global_position).normalized()
	var proj := bulletProjectileToLoad.instantiate()
	scene_tree.current_scene.add_child(proj)
	proj.global_position = bullet_point.global_position
	if "damage_amount" in proj:
		proj.damage_amount = item_ref.wieldable_damage
	if proj.has_method("set_linear_velocity"):
		proj.set_linear_velocity(direction * weaponVelocity)
	if "Direction" in proj:
		proj.Direction = direction


static func _deal_damage(collider: Node, direction: Vector3, hit_position: Vector3, item_ref: WieldableItemPD) -> void:
	if collider.has_signal("damage_received"):
		collider.damage_received.emit(item_ref.wieldable_damage, direction, hit_position)
