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
		1: _hitscan_fire(ctx)
		2: _projectile_fire(ctx)


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
