extends CogitoNPC
class_name HostileNPC

## Shared base for combat-capable NPCs (Scav, and future factions).
## Faction "personality" (accuracy, alertness, vision/hearing) lives on
## `ai_profile`; weapon stats (damage, fire rate, magazine size) come from
## `equipped_wieldable` / `equipped_weapon_data` — the SAME resources the
## player's real weapons use. Adding a new faction is just a new script
## extending HostileNPC with its own default .tres assignments, or the same
## script with a different profile/weapon dragged in via the Inspector.

@export var ai_profile: AIProfile
## Provides wieldable_damage / wieldable_range / charge_max (magazine size).
@export var equipped_wieldable: WieldableItemPD
## Provides get_fire_cooldown() / get_fire_mode() (ballistics config).
@export var equipped_weapon_data: Weapon_Resource

@onready var bt_player: Node = $BTPlayer


func _ready() -> void:
	super._ready()
	var health := get_node_or_null("CogitoHealthAttribute")
	if health:
		health.death.connect(_on_death)
	# BTPlayer (a child) is ready before its parent, so its blackboard already
	# exists here. The BlackboardPlan's baked-in "ammo" default won't reflect
	# whichever weapon is actually equipped, so set the real starting mag here.
	if bt_player and bt_player.blackboard:
		bt_player.blackboard.set_var(&"ammo", magazine_size())


func _on_death() -> void:
	if is_instance_valid(bt_player):
		bt_player.active = false
	# Disable collision with player (layer 2) but keep world collision (layer 1)
	collision_layer = 0
	collision_mask = 1


## Magazine size for ammo bookkeeping. Falls back to a sane default if no
## weapon item is assigned yet (e.g. mid-setup in the editor).
func magazine_size() -> int:
	if equipped_wieldable:
		return int(equipped_wieldable.charge_max)
	return 5


## Damage per hit. Falls back to a sane default if unassigned.
func weapon_damage() -> float:
	if equipped_wieldable:
		return equipped_wieldable.wieldable_damage
	return 8.0


## Seconds between shots, adjusted by this AI's trigger skill (ai_profile).
func effective_fire_cooldown() -> float:
	var base_cooldown: float = equipped_weapon_data.get_fire_cooldown() if equipped_weapon_data else 0.8
	var skill: float = ai_profile.fire_rate_skill if ai_profile else 1.0
	return base_cooldown / maxf(skill, 0.01)
