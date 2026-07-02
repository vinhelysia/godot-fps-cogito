extends CogitoNPC
class_name HostileNPC

## Shared base for combat-capable NPCs (Scav, PMC, Raider, etc.).
## Skill "personality" (accuracy, alertness, vision/hearing) lives on
## `ai_profile`; weapon stats (damage, fire rate, magazine size) come from
## `equipped_wieldable` / `equipped_weapon_data` — the SAME resources the
## player's real weapons use. WHO this NPC is and who it's hostile/neutral/
## friendly towards lives on `faction` (see Faction.gd) — disposition is
## looked up against `player_faction`, the same generic lookup future
## NPC-vs-NPC combat will use. Adding a new faction archetype is just a new
## Faction .tres (+ optionally a new AIProfile/weapon) — no script changes.

@export var ai_profile: AIProfile
## Provides wieldable_damage / wieldable_range / charge_max (magazine size).
@export var equipped_wieldable: WieldableItemPD
## Provides get_fire_cooldown() / get_fire_mode() (ballistics config).
@export var equipped_weapon_data: Weapon_Resource
## Who this NPC is. Determines hostility via faction.get_disposition_towards().
@export var faction: Faction
## Which Faction resource represents the player. Same .tres assigned across
## all NPCs — kept per-instance (not a singleton) so this stays simple and
## doesn't require touching CogitoPlayer.
@export var player_faction: Faction

@onready var bt_player: Node = $BTPlayer

## Timestamp (Time.get_ticks_msec()/1000.0) of the last time this NPC took
## damage. ScavPerception polls this (comparing against its own
## last-processed copy) to react to being shot even from outside FOV/hearing
## range, without HostileNPC touching the blackboard itself — handing the
## event to the sensor "via a variable", keeping perception the sole
## blackboard writer.
var last_hit_time: float = -999.0


func _ready() -> void:
	super._ready()
	var health := get_node_or_null("CogitoHealthAttribute")
	if health:
		health.death.connect(_on_death)
	# damage_received(damage_value: float) — 1 arg, no direction/position
	# (verified in addons/cogito/CogitoNPC/cogito_npc.gd). Single-player: the
	# attacker is always the player, so no attacker info is needed here.
	damage_received.connect(_on_damage_received)
	# BTPlayer (a child) is ready before its parent, so its blackboard already
	# exists here. The BlackboardPlan's baked-in "ammo" default won't reflect
	# whichever weapon is actually equipped, so set the real starting mag here.
	if bt_player and bt_player.blackboard:
		bt_player.blackboard.set_var(&"ammo", magazine_size())


func _on_damage_received(_damage_value: float) -> void:
	last_hit_time = Time.get_ticks_msec() / 1000.0


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


## No faction assigned = default to hostile (safe fallback so an unconfigured
## NPC still behaves like the original always-hostile Scav).
func is_hostile_to_player() -> bool:
	if faction == null:
		return true
	return faction.is_hostile_towards(player_faction)
