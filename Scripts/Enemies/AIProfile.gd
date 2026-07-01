extends Resource
class_name AIProfile

## Faction/disposition/skill-level AI tuning — independent of whichever weapon
## is equipped. Damage, fire rate, magazine size, and range come from the
## equipped WieldableItemPD / Weapon_Resource instead (see HostileNPC). This
## Resource only holds "who are they towards the player, and how good/alert/
## careful are they", so the same weapon feels different in different hands.
##
## Create one .tres per archetype (e.g. scav_profile.tres, elite_profile.tres)
## and assign it to a HostileNPC's `ai_profile` export — no script changes needed
## to add a new faction, just a new profile (and optionally a different weapon).

enum Alignment {
	HOSTILE,  ## Attacks the player on sight/sound, per the stats below.
	NEUTRAL,  ## Never attacks; currently identical to FRIENDLY (see scav_perception.gd).
	FRIENDLY, ## Never attacks; currently identical to NEUTRAL.
}

@export_group("Disposition")
@export var alignment: Alignment = Alignment.HOSTILE

@export_group("Vision")
@export_range(10.0, 360.0, 1.0, "suffix:°") var fov_degrees: float = 110.0
@export var sight_range: float = 25.0
@export var eye_height: float = 1.6

@export_group("Hearing")
## Effective hearing range = sound loudness * hear_k. Higher = better ears.
@export var hear_k: float = 0.6
## In COMBAT, ignore sounds quieter than this (own footsteps/movement chatter).
@export var combat_hearing_loudness: float = 30.0

@export_group("Alertness")
## Seconds after losing sight before COMBAT decays to SUSPICIOUS.
@export var combat_hold: float = 4.0

@export_group("Combat Skill")
## Marksmanship, 0-1. 0.0 = terrible (max spread), 1.0 = perfect (no spread).
## Converted internally to a spread magnitude: spread = max_spread * (1 - accuracy).
@export_range(0.0, 1.0, 0.01) var accuracy: float = 0.2
## Spread magnitude (~tan of deviation angle) at accuracy = 0.0 — i.e. the
## worst-case spread a 0-skill shooter has. Tune this once per weapon "class"
## feel; accuracy is what you actually dial per-faction.
@export var max_spread: float = 0.6
## One-time pause before the first shot of an engagement.
@export var reaction_delay: float = 0.3
## Multiplies the equipped weapon's cyclic rate. 1.0 = fires as fast as the gun
## allows; <1.0 = hesitant/poor trigger control (fires slower than the weapon
## is capable of); >1.0 is not physically meaningful and should be avoided.
@export_range(0.1, 1.0, 0.01) var fire_rate_skill: float = 1.0
## Seconds to reload (skill/training, independent of magazine size).
@export var reload_time: float = 2.5
## Seconds of tolerated line-of-sight loss before bailing from a shot to chase.
@export var los_grace: float = 0.4
## Extra distance tolerated past preferred_engage_range before bailing to chase.
@export var range_margin: float = 2.0
## Tactical engagement distance this AI tries to hold/fight from. Deliberately
## NOT derived from the weapon's wieldable_range (which represents max
## theoretical travel/falloff distance, not a sane in-level engagement choice).
@export var preferred_engage_range: float = 18.0


## Spread magnitude used by bt_shoot — derived from accuracy so higher always
## means "better shooter" regardless of how spread is implemented internally.
func spread() -> float:
	return max_spread * (1.0 - accuracy)
