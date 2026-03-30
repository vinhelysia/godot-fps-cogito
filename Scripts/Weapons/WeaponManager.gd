extends Node3D

signal weaponChanged
signal updateAmmo
signal updateWeaponStack
signal recoilApplied
signal adsToggled
signal heat_changed(fraction: float)
signal scope_changed(is_scoped: bool, texture: Texture2D)

@onready var RecoilNode = $"../.."
@onready var Animation_Player = $FPS_Rig/AnimationPlayer
@onready var BulletPoint = $"FPS_Rig/Bullet Point"

var currentWeapon: Weapon_Resource = null
var weaponStack = []
var weaponIndicator = 0
var nextWeapon: String
var weaponList = {}
var IsAiming: bool = false

# ── Type state ─────────────────────────────────────────────────────────────────
var _fire_cooldown: float = 0.0
var _is_trigger_held: bool = false
var _is_reloading: bool = false

var _bolt_is_cycled: bool = true       # BoltAction
var _pump_ready: bool = true           # Shotgun pump

var _current_heat: float = 0.0        # LMG
var _is_venting: bool = false          # LMG vent

var _tube_reload_active: bool = false  # Shotgun tube reload
var _gate_load_active: bool = false    # Revolver gate load

@export var weaponResources: Array[Weapon_Resource]
@export var startWeapon: Array[String]

enum { NULL, HITSCAN, PROJECTILE }




func _ready():
	Initialize(startWeapon)


func _process(delta: float) -> void:
	_fire_cooldown = max(0.0, _fire_cooldown - delta)

	# Auto fire while trigger held
	if _is_trigger_held and currentWeapon != null and !_is_reloading:
		var mode = currentWeapon.get_fire_mode()
		if mode == Weapon_Resource.FireMode.AUTO and _fire_cooldown <= 0.0:
			if currentWeapon.currentAmmo > 0:
				shoot()

	# LMG passive heat cooldown
	if currentWeapon is LMG_Resource and !_is_trigger_held and !_is_venting:
		_current_heat = max(0.0, _current_heat - currentWeapon.cooldownRate * delta)
		emit_signal("heat_changed", _current_heat)

	# LMG active vent
	if currentWeapon is LMG_Resource and _is_venting:
		_current_heat = max(0.0, _current_heat - currentWeapon.ventRate * delta)
		emit_signal("heat_changed", _current_heat)
		if _current_heat <= 0.0:
			_is_venting = false
			_is_reloading = false


func _input(event):
	if event.is_action_pressed("weaponUp"):
		weaponIndicator = min(weaponIndicator + 1, weaponStack.size() - 1)
		exit(weaponStack[weaponIndicator])
	if event.is_action_pressed("weaponDown"):
		weaponIndicator = max(weaponIndicator - 1, 0)
		exit(weaponStack[weaponIndicator])

	if event.is_action_pressed("Shoot"):
		_is_trigger_held = true
		shoot()
	if event.is_action_released("Shoot"):
		_is_trigger_held = false

	if event.is_action_pressed("Reload"):
		reload()
	if event.is_action_pressed("ADS"):
		ToggleADS()


# ── Initialization ─────────────────────────────────────────────────────────────

func Initialize(_start_weapons: Array):
	for weapon in weaponResources:
		weaponList[weapon.weaponName] = weapon
	print(weaponList.keys())
	print(_start_weapons)
	for i in _start_weapons:
		weaponStack.push_back(i)
	currentWeapon = weaponList[weaponStack[0]]
	emit_signal("updateWeaponStack", weaponStack)
	enter()


func _reset_type_state() -> void:
	_fire_cooldown = 0.0
	_bolt_is_cycled = true
	_pump_ready = true
	_current_heat = 0.0
	_is_venting = false
	_is_reloading = false
	_tube_reload_active = false
	_gate_load_active = false


# ── Equip / Unequip ────────────────────────────────────────────────────────────

func enter():
	_reset_type_state()
	Animation_Player.queue(currentWeapon.equipAnimation)
	emit_signal("weaponChanged", currentWeapon.weaponName)
	emit_signal("updateAmmo", [currentWeapon.currentAmmo, currentWeapon.reserveAmmo])


func exit(_next_weapon: String):
	if IsAiming:
		IsAiming = false
		emit_signal("adsToggled", false)
	if _next_weapon != currentWeapon.weaponName:
		if Animation_Player.get_current_animation() != currentWeapon.unequipAniamtion:
			Animation_Player.play(currentWeapon.unequipAniamtion)
			nextWeapon = _next_weapon


func changeWeapons(weaponName: String):
	currentWeapon = weaponList[weaponName]
	nextWeapon = ""
	enter()


# ── Shoot ──────────────────────────────────────────────────────────────────────

func shoot():
	if currentWeapon == null or currentWeapon.currentAmmo <= 0:
		return
	if _fire_cooldown > 0.0:
		return
	if _is_reloading:
		return

	var mode = currentWeapon.get_fire_mode()

	# Type-specific fire guards
	if mode == Weapon_Resource.FireMode.BOLT_ACTION and !_bolt_is_cycled:
		return
	if mode == Weapon_Resource.FireMode.PUMP and !_pump_ready:
		return
	if currentWeapon is LMG_Resource and _current_heat >= 1.0:
		return

	if !Animation_Player.is_playing():
		var anim = currentWeapon.ADSShootAnimation \
			if (IsAiming and currentWeapon.ADSShootAnimation != "") \
			else currentWeapon.shootAnimation
		Animation_Player.play(anim)
		currentWeapon.currentAmmo -= 1
		emit_signal("updateAmmo", [currentWeapon.currentAmmo, currentWeapon.reserveAmmo])

		# Fire dispatch
		if currentWeapon is Shotgun_Resource:
			_fire_shotgun()
		elif currentWeapon is GrenadeLauncher_Resource:
			_fire_grenade()
		else:
			var cam_col = Get_Camera_Collision()
			match currentWeapon.Type:
				NULL:
					print("Weapon Type Not Chosen")
				HITSCAN:
					Hit_Scam_Collision(cam_col)
				PROJECTILE:
					_fire_projectile(cam_col)

		# Recoil
		RecoilNode.setRecoil(Vector3(currentWeapon.recoilVertical, currentWeapon.recoilHorizontal, 0))
		RecoilNode.recoilFire()
		emit_signal("recoilApplied", currentWeapon.recoilVertical, currentWeapon.recoilHorizontal)

		# Fire cooldown per type
		if currentWeapon is AssaultRifle_Resource or currentWeapon is LMG_Resource:
			_fire_cooldown = 60.0 / currentWeapon.fireRate
		elif currentWeapon is Pistol_Resource:
			_fire_cooldown = currentWeapon.triggerResetTime
		else:
			_fire_cooldown = 0.1

		# Post-fire state per type
		if mode == Weapon_Resource.FireMode.BOLT_ACTION:
			_bolt_is_cycled = false
		if mode == Weapon_Resource.FireMode.PUMP:
			_pump_ready = false
		if currentWeapon is LMG_Resource:
			_current_heat = min(1.0, _current_heat + currentWeapon.heatPerShot)
			if _current_heat >= 1.0:
				_is_trigger_held = false
			emit_signal("heat_changed", _current_heat)


# ── Fire Implementations ───────────────────────────────────────────────────────

func _fire_shotgun():
	var res := currentWeapon as Shotgun_Resource
	var spread := res.adsSpreadAngle if IsAiming else res.spreadAngle
	var camera = get_viewport().get_camera_3d()
	var vp = get_viewport().get_size()
	var center = vp / 2.0

	for i in res.pelletCount:
		var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() \
			* tan(deg_to_rad(spread))
		var spread_point = center + Vector2(offset.x, offset.y) * vp.x * 0.1
		var ray_origin = camera.project_ray_origin(spread_point)
		var ray_end = ray_origin + camera.project_ray_normal(spread_point) * res.weaponRange
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collision_mask = 0b111
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			Hit_Scan_Damage(hit.collider)


func _fire_grenade():
	var res := currentWeapon as GrenadeLauncher_Resource
	var camera = get_viewport().get_camera_3d()
	var forward = -camera.global_transform.basis.z
	var launch_dir = (forward + Vector3.UP * tan(deg_to_rad(res.launchAngle))).normalized()
	var grenade = res.grenadeScene.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = BulletPoint.global_position
	if grenade.has_method("set_linear_velocity"):
		grenade.set_linear_velocity(launch_dir * res.launchVelocity)
	if "damage_amount" in grenade:
		grenade.damage_amount = res.weaponDamage
	if "fuse_duration" in grenade:
		grenade.fuse_duration = res.fuseDuration
	if "blast_radius" in grenade:
		grenade.blast_radius = res.blastRadius


func _fire_projectile(target_point: Vector3):
	var dir = (target_point - BulletPoint.global_position).normalized()
	var proj = currentWeapon.bulletProjectileToLoad.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = BulletPoint.global_position
	if "damage_amount" in proj:
		proj.damage_amount = currentWeapon.weaponDamage
	if proj.has_method("set_linear_velocity"):
		proj.set_linear_velocity(dir * currentWeapon.weaponVelocity)


# ── Reload ─────────────────────────────────────────────────────────────────────

func reload():
	if _is_reloading:
		return

	# LMG: hold reload to vent heat instead of reload when hot
	if currentWeapon is LMG_Resource and _current_heat > 0.0 and !_is_venting:
		if !Animation_Player.is_playing():
			_is_venting = true
			_is_reloading = true
			Animation_Player.play(currentWeapon.ventAnimation)
		return

	var maxLoaded = currentWeapon.GetMaxLoadedAmmo()
	if currentWeapon.currentAmmo >= maxLoaded:
		return
	if currentWeapon.reserveAmmo <= 0:
		return
	if Animation_Player.is_playing():
		return

	# Revolver gate load (individual rounds)
	if currentWeapon is Revolver_Resource and currentWeapon.gateLoad:
		_start_gate_load_reload()
		return

	# Shotgun tube reload (one shell at a time)
	if currentWeapon is Shotgun_Resource and currentWeapon.tubeReload:
		_start_tube_reload()
		return

	# Standard magazine reload
	_is_reloading = true
	if currentWeapon.currentAmmo == 0 and currentWeapon.reloadEmptyAnimation != "":
		Animation_Player.play(currentWeapon.reloadEmptyAnimation)
	else:
		Animation_Player.play(currentWeapon.reloadAnimation)


func _finish_standard_reload():
	var maxLoaded = currentWeapon.GetMaxLoadedAmmo()
	var amount = min(maxLoaded - currentWeapon.currentAmmo, currentWeapon.reserveAmmo)
	currentWeapon.currentAmmo += amount
	currentWeapon.reserveAmmo -= amount
	_is_reloading = false
	emit_signal("updateAmmo", [currentWeapon.currentAmmo, currentWeapon.reserveAmmo])


func _start_gate_load_reload():
	# Load one round, then animation_finished will call again until full
	if currentWeapon.reserveAmmo <= 0 or currentWeapon.currentAmmo >= currentWeapon.cylinderCapacity:
		_is_reloading = false
		return
	_is_reloading = true
	_gate_load_active = true
	Animation_Player.play((currentWeapon as Revolver_Resource).singleRoundAnimation)


func _start_tube_reload():
	if currentWeapon.reserveAmmo <= 0 or currentWeapon.currentAmmo >= currentWeapon.GetMaxLoadedAmmo():
		_is_reloading = false
		return
	_is_reloading = true
	_tube_reload_active = true
	Animation_Player.play(currentWeapon.reloadAnimation)


# ── Animation Finished ─────────────────────────────────────────────────────────

func _on_animation_player_animation_finished(anim_name: StringName):
	# Weapon switch
	if anim_name == currentWeapon.unequipAniamtion:
		changeWeapons(nextWeapon)
		return

	# Standard reload complete
	if anim_name == currentWeapon.reloadAnimation or anim_name == currentWeapon.reloadEmptyAnimation:
		if _tube_reload_active:
			# Tube: add one shell, continue if more needed
			if currentWeapon.reserveAmmo > 0 and currentWeapon.currentAmmo < currentWeapon.GetMaxLoadedAmmo():
				currentWeapon.currentAmmo += 1
				currentWeapon.reserveAmmo -= 1
				emit_signal("updateAmmo", [currentWeapon.currentAmmo, currentWeapon.reserveAmmo])
				# Check interrupt: if trigger held, stop reloading and fire
				if (currentWeapon as Shotgun_Resource).canInterruptReload and _is_trigger_held:
					_tube_reload_active = false
					_is_reloading = false
					shoot()
				else:
					Animation_Player.play(currentWeapon.reloadAnimation)
			else:
				_tube_reload_active = false
				_is_reloading = false
				emit_signal("updateAmmo", [currentWeapon.currentAmmo, currentWeapon.reserveAmmo])
		else:
			_finish_standard_reload()

	# Revolver gate load: one round loaded per animation
	if _gate_load_active and currentWeapon is Revolver_Resource:
		if anim_name == (currentWeapon as Revolver_Resource).singleRoundAnimation:
			currentWeapon.currentAmmo += 1
			currentWeapon.reserveAmmo -= 1
			emit_signal("updateAmmo", [currentWeapon.currentAmmo, currentWeapon.reserveAmmo])
			# Continue loading if not full and reserve available
			if currentWeapon.reserveAmmo > 0 and currentWeapon.currentAmmo < currentWeapon.cylinderCapacity:
				Animation_Player.play((currentWeapon as Revolver_Resource).singleRoundAnimation)
			else:
				_gate_load_active = false
				_is_reloading = false
		return

	# Bolt action: shoot animation triggers bolt cycle
	if currentWeapon is BoltAction_Resource and anim_name == currentWeapon.shootAnimation:
		if currentWeapon.boltCycleAnimation != "":
			Animation_Player.play(currentWeapon.boltCycleAnimation)

	# Bolt cycle complete: ready to fire again
	if currentWeapon is BoltAction_Resource and anim_name == currentWeapon.boltCycleAnimation:
		_bolt_is_cycled = true

	# Shotgun pump: shoot animation triggers pump
	if currentWeapon is Shotgun_Resource and currentWeapon.isPump and anim_name == currentWeapon.shootAnimation:
		if currentWeapon.pumpAnimation != "":
			Animation_Player.play(currentWeapon.pumpAnimation)

	# Pump complete: ready to fire again
	if currentWeapon is Shotgun_Resource and currentWeapon.isPump and anim_name == currentWeapon.pumpAnimation:
		_pump_ready = true

	# LMG vent complete
	if currentWeapon is LMG_Resource and anim_name == currentWeapon.ventAnimation:
		_is_venting = false
		_is_reloading = false

	# Auto fire continuation (base autoFire flag support)
	if (anim_name == currentWeapon.shootAnimation or anim_name == currentWeapon.ADSShootAnimation) \
			and currentWeapon.autoFire:
		if currentWeapon is AssaultRifle_Resource or currentWeapon is LMG_Resource:
			pass  # handled by _process auto-fire loop
		elif Input.is_action_pressed("Shoot"):
			shoot()


# ── Camera Collision ───────────────────────────────────────────────────────────

func Get_Camera_Collision() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	var viewport = get_viewport().get_size()
	var rayOrigin = camera.project_ray_origin(viewport / 2)
	var rayEnd = rayOrigin + camera.project_ray_normal(viewport / 2) * currentWeapon.weaponRange
	var newIntersection = PhysicsRayQueryParameters3D.create(rayOrigin, rayEnd)
	newIntersection.collision_mask = 0b111
	var intersection = get_world_3d().direct_space_state.intersect_ray(newIntersection)
	if not intersection.is_empty():
		return intersection.position
	return rayEnd


func Hit_Scam_Collision(Collision_Point: Vector3):
	var bulletDirection = (Collision_Point - BulletPoint.get_global_transform().origin).normalized()
	var New_Intersection = PhysicsRayQueryParameters3D.create(
		BulletPoint.get_global_transform().origin,
		Collision_Point + bulletDirection * 2
	)
	New_Intersection.collision_mask = 0b111
	var Bullet_Collision = get_world_3d().direct_space_state.intersect_ray(New_Intersection)
	if Bullet_Collision:
		Hit_Scan_Damage(Bullet_Collision.collider)


func Hit_Scan_Damage(Collider):
	if Collider.is_in_group("Target") and Collider.has_method("HitSuccessful"):
		Collider.HitSuccessful(currentWeapon.weaponDamage)


# ── ADS ────────────────────────────────────────────────────────────────────────

func ToggleADS():
	if currentWeapon is MarksmanRifle_Resource:
		_toggle_marksman_scope()
		return

	if currentWeapon.ADSInAnimation == "":
		return
	if Animation_Player.is_playing():
		return

	IsAiming = !IsAiming
	emit_signal("adsToggled", IsAiming)
	if IsAiming:
		Animation_Player.play(currentWeapon.ADSInAnimation, -1, currentWeapon.ADSSpeed)
	else:
		Animation_Player.play(currentWeapon.ADSInAnimation, -1, -currentWeapon.ADSSpeed, true)


func _toggle_marksman_scope():
	if Animation_Player.is_playing():
		return
	var res := currentWeapon as MarksmanRifle_Resource
	var camera = get_viewport().get_camera_3d()
	IsAiming = !IsAiming
	emit_signal("adsToggled", IsAiming)
	var tw = create_tween()
	tw.tween_property(camera, "fov", res.scopedFOV if IsAiming else 75.0, res.scopeInTime)
	if res.useScopeOverlay:
		emit_signal("scope_changed", IsAiming, res.scopeOverlayTexture)
