extends InventoryItemPD
class_name AttachmentItemPD

enum AttachmentSlot { OPTIC, MUZZLE, GRIP, STOCK }

@export var attachment_slot: AttachmentSlot

@export_group("Stat Modifiers")
@export var recoil_multiplier: float = 1.0
@export var ads_time_multiplier: float = 1.0
## Scales the gunshot loudness heard by NPC perception (suppressor < 1).
@export var loudness_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var range_multiplier: float = 1.0

@export_group("Optic")
## Camera FOV while ADS. -1 = keep the weapon's own ads_fov.
@export var ads_fov_override: float = -1.0
## Added to the weapon's ads_position to line the eye up with this optic.
@export var ads_position_offset: Vector3 = Vector3.ZERO

@export_group("Muzzle")
@export var suppresses_muzzle_flash: bool = false

@export_group("Mounting")
## Scene spawned on the weapon when attached. Null = data-only stat mod (grip/stock v1).
@export var mount_scene: PackedScene
## WieldableItemPD.name entries this fits ("AK-47", "M700"...). Empty = fits every weapon.
@export var compatible_weapons: Array[String] = []


func fits(weapon_item: WieldableItemPD) -> bool:
	if weapon_item == null:
		return false
	return compatible_weapons.is_empty() or weapon_item.name in compatible_weapons
