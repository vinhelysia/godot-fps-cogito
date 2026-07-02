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
## If `loadout` is assigned, this gets OVERWRITTEN in _ready() by the rolled
## weapon (a per-instance duplicate) — leave unset when using a loadout.
@export var equipped_wieldable: WieldableItemPD
## Provides get_fire_cooldown() / get_fire_mode() (ballistics config).
## Same overwrite rule as equipped_wieldable when `loadout` is assigned.
@export var equipped_weapon_data: Weapon_Resource
## Who this NPC is. Determines hostility via faction.get_disposition_towards().
@export var faction: Faction
## Which Faction resource represents the player. Same .tres assigned across
## all NPCs — kept per-instance (not a singleton) so this stays simple and
## doesn't require touching CogitoPlayer.
@export var player_faction: Faction
## Optional spawn kit: rolls a weapon + gear + reserve ammo + pocket loot at
## _ready() into `equipment`/`pockets` below. Unset = legacy behavior — this
## NPC just uses whatever equipped_wieldable/equipped_weapon_data are set to
## in the editor, exactly as before this system existed.
@export var loadout: NPCLoadout
@export var debug_loadout: bool = false

@onready var bt_player: Node = $BTPlayer

## Timestamp (Time.get_ticks_msec()/1000.0) of the last time this NPC took
## damage. ScavPerception polls this (comparing against its own
## last-processed copy) to react to being shot even from outside FOV/hearing
## range, without HostileNPC touching the blackboard itself — handing the
## event to the sensor "via a variable", keeping perception the sole
## blackboard writer.
var last_hit_time: float = -999.0

## Only populated when `loadout` is assigned (see _apply_loadout()). Reused
## as-is (CogitoEquipment is owner-agnostic: equip()/unequip()/get_equipped()
## don't care whether the owner is the player or an NPC).
var equipment: CogitoEquipment
## Plain 4x2 grid, NOT PocketInventory — see _apply_loadout()'s comment for
## why the player-specific PocketInventory isn't reused here.
var pockets: CogitoInventory

var _loadout_rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	var health := get_node_or_null("CogitoHealthAttribute")
	if health:
		health.death.connect(_on_death)
	# damage_received(damage_value, bullet_direction, bullet_position) — 3 args,
	# matching Weapon_Resource._deal_damage() (the player's shared hitscan/
	# damage code) and HitboxComponent.damage(), the two other places that
	# receive this signal.
	damage_received.connect(_on_damage_received)

	if loadout:
		_loadout_rng.randomize()
		_apply_loadout()

	# BTPlayer (a child) is ready before its parent, so its blackboard already
	# exists here. The BlackboardPlan's baked-in "ammo" default won't reflect
	# whichever weapon is actually equipped, so set the real starting mag here.
	# Must run AFTER _apply_loadout() so a rolled weapon's real charge_max is
	# what seeds the starting magazine.
	if bt_player and bt_player.blackboard:
		bt_player.blackboard.set_var(&"ammo", magazine_size())


## Rolls `loadout` and wires the result into equipped_wieldable/
## equipped_weapon_data (the flat vars the BT tasks actually read),
## `equipment` (weapon + gear, slotted like the player's), and `pockets`
## (spare ammo + rolled junk).
##
## pockets is a plain CogitoInventory grid, not PocketInventory: PocketInventory's
## can_pick_up_slot_data()/pick_up_slot_data() auto-equip routing IS genuinely
## owner-agnostic (reads owner.equipment generically) and would work here too,
## but it's pure unused surface for this use case since weapon/gear are equipped
## directly via equipment.equip() below, never through pick_up_slot_data(). Its
## use_slot_data() sentinel-index path, however, calls
## slot_data.inventory_item.use(owner) for equipped items, which for a
## WieldableItemPD reaches into owner.player_interaction_component — an NPC has
## no such property, so that specific path would break if anything ever called
## it on an NPC's pockets. Nothing currently does (no NPC pocket-viewing UI
## exists — see npc_loot_component.gd's death-drop container, which is a
## separate non-grid inventory instead), but a plain grid carries none of that
## latent risk and needs none of PocketInventory's player-UI-oriented behavior.
func _apply_loadout() -> void:
	equipment = CogitoEquipment.new()
	pockets = CogitoInventory.new()
	pockets.grid = true
	pockets.inventory_size = Vector2i(4, 2)
	pockets.inventory_slots.resize(8)
	pockets.owner = self

	var result := loadout.roll(_loadout_rng)
	var weapon_option := result.get("weapon_option") as NPCWeaponOption
	var spare_magazines: int = result.get("spare_magazines", 0)

	if weapon_option and weapon_option.wieldable:
		var duped_wieldable: WieldableItemPD = pockets._duplicate_wieldable_item_for_inventory(weapon_option.wieldable)
		equipped_wieldable = duped_wieldable
		equipped_weapon_data = weapon_option.weapon_data

		var weapon_slot_data := InventorySlotPD.new()
		weapon_slot_data.inventory_item = duped_wieldable
		weapon_slot_data.quantity = 1
		equipment.equip(_weapon_slot_to_equipment_slot(duped_wieldable.weapon_slot), weapon_slot_data)

		if spare_magazines > 0 and weapon_option.ammo_item:
			var ammo_slot_data := InventorySlotPD.new()
			ammo_slot_data.inventory_item = weapon_option.ammo_item
			ammo_slot_data.quantity = spare_magazines * int(duped_wieldable.charge_max)
			pockets.pick_up_slot_data(ammo_slot_data)

	var gear_items: Array = result.get("gear_items", [])
	for gear_item: GearItemPD in gear_items:
		var gear_equipment_slot := _gear_slot_to_equipment_slot(gear_item.gear_slot)
		if gear_equipment_slot == &"":
			continue
		var gear_slot_data := InventorySlotPD.new()
		gear_slot_data.inventory_item = gear_item
		gear_slot_data.quantity = 1
		equipment.equip(gear_equipment_slot, gear_slot_data)

	var pocket_loot_rolls: int = result.get("pocket_loot_rolls", 0)
	if pocket_loot_rolls > 0 and loadout.pocket_loot_table:
		# LootGenerator needs to be added to the tree (get_tree() inside its
		# own _set_up_references()) — but _ready() runs while the scene tree
		# is still mid-setup for this whole subtree ("Parent node is busy
		# setting up children"), so a synchronous add_child() here fails.
		# Defer the whole roll to run once that setup finishes.
		_roll_pocket_loot.call_deferred(pocket_loot_rolls)

	if debug_loadout:
		var gear_names: Array = []
		for gear_item: GearItemPD in gear_items:
			gear_names.append(gear_item.name)
		print("[%s] Rolled loadout: weapon=%s gear=%s spare_mags=%d pocket_loot_rolls=%d" % [
			name,
			weapon_option.wieldable.name if weapon_option and weapon_option.wieldable else "none",
			gear_names,
			spare_magazines,
			pocket_loot_rolls,
		])


## Deferred half of the pocket-loot roll (see _apply_loadout()) — needs the
## NPC to actually be inside the tree, which isn't guaranteed yet at _ready()
## time.
func _roll_pocket_loot(pocket_loot_rolls: int) -> void:
	var lootgen := LootGenerator.new()
	get_tree().current_scene.add_child(lootgen)
	var rolled_loot: Array[LootDropEntry] = lootgen.generate(loadout.pocket_loot_table, pocket_loot_rolls)
	lootgen.call_deferred("queue_free")
	for entry in rolled_loot:
		if entry.inventory_item == null:
			continue
		var loot_slot_data := InventorySlotPD.new()
		loot_slot_data.inventory_item = entry.inventory_item
		loot_slot_data.quantity = randi_range(entry.quantity_min, entry.quantity_max)
		pockets.pick_up_slot_data(loot_slot_data)


## True if this NPC has at least 1 round of reserve ammo for its equipped
## weapon in pockets. Peek-only, doesn't consume anything — bt_reload.gd
## checks this BEFORE starting the reload wait so a doomed reload never
## plays out. NPCs without pockets (no loadout assigned) always report
## false here, but that's fine: bt_reload.gd only enforces finite ammo when
## pockets exist, so legacy NPCs never call this in the first place.
func has_reserve_ammo() -> bool:
	if pockets == null or equipped_wieldable == null:
		return false
	var ammo_name: String = equipped_wieldable.ammo_item_name
	for slot: InventorySlotPD in pockets.inventory_slots:
		if slot and slot.inventory_item and slot.inventory_item.name == ammo_name and slot.quantity > 0:
			return true
	return false


## Draws up to `rounds_needed` rounds from this NPC's pockets (matching
## equipped_wieldable.ammo_item_name), shrinking/removing the ammo stack via
## the inventory's own removal path (remove_slot_data — never hand-nulling a
## slot). Returns rounds actually taken, which may be less than requested
## (partial reload) or 0 (no pockets, or reserve ran out between the
## has_reserve_ammo() check and this call — nothing currently causes that,
## but the caller shouldn't assume it can't happen).
func take_reserve_ammo(rounds_needed: int) -> int:
	if pockets == null or equipped_wieldable == null or rounds_needed <= 0:
		return 0

	var ammo_name: String = equipped_wieldable.ammo_item_name
	var taken: int = 0
	for slot: InventorySlotPD in pockets.inventory_slots:
		if taken >= rounds_needed:
			break
		if slot == null or slot.inventory_item == null:
			continue
		if slot.inventory_item.name != ammo_name:
			continue
		var take_now: int = mini(rounds_needed - taken, slot.quantity)
		slot.quantity -= take_now
		taken += take_now
		if slot.quantity <= 0:
			pockets.remove_slot_data(slot)

	return taken


func _weapon_slot_to_equipment_slot(weapon_slot: int) -> StringName:
	match weapon_slot:
		0: return &"primary_1" # WieldableItemPD.WeaponSlot.PRIMARY
		1: return &"holster"   # WeaponSlot.HOLSTER
		2: return &"melee"     # WeaponSlot.MELEE
	return &"primary_1"


func _gear_slot_to_equipment_slot(gear_slot: int) -> StringName:
	match gear_slot:
		0: return &"body_armor" # GearItemPD.GearSlot.BODY_ARMOR
		1: return &"helmet"     # GearSlot.HELMET
		2: return &"eyewear"    # GearSlot.EYEWEAR
		3: return &"face_cover" # GearSlot.FACE_COVER
		4: return &"earpiece"   # GearSlot.EARPIECE
	return &""


func _on_damage_received(_damage_value: float, _direction: Vector3, _hit_position: Vector3) -> void:
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
