# Plan: Local Weapon Attachment System — Sights & Muzzle (v1)



## Context



`godot-fps-cogito-master` already has a clean `cogito_weapon.gd` orchestrator

(`Scripts/Weapons/cogito_weapon.gd`) that delegates fire dispatch to

`Weapon_Resource` subclasses through a `ctx: Dictionary`. Optics today are

hard-wired: the TAC30 riflescope is authored as a direct child of `m700.tscn`

and `ADSController` finds it by walking the weapon's **direct** children.



What is missing:



- a data class describing an attachment,

- named mount points on weapon scenes (sight rail, muzzle thread),

- a modifier pipeline that can scale damage / spread / recoil / muzzle

  velocity / sound without touching each `Type/*.gd`,

- a way to declare "this M700 has this scope" without editing the weapon scene

  each time.



Goal of v1: a **declarative, project-local** attachment system for two slots

— **Sight** and **Muzzle** — that never touches `addons/cogito`. The user

assigns a `.tres` resource to a slot on a weapon scene; at `_ready()` the

system instantiates the attachment's model into a mount point and collects its

modifiers. Runtime inventory swap, UI, and per-weapon_data subclass

consumption of modifiers are **out of scope**.



## Verified assumptions (from reading the code)



- `cogito_weapon.gd` already builds a `ctx` dict in `_build_fire_context()`

  (`cogito_weapon.gd:360`). Adding one more key is the cheapest possible hook.

- Recoil is configured in one place — `_configure_recoil()`

  (`cogito_weapon.gd:485`) — which calls `rn.setRecoil(hip)` / `setAimRecoil`.

  Multiplying `hip` there is a one-line change.

- Shot sound is played in `_try_fire()` at `cogito_weapon.gd:321-323`.

- `ADSController` lives at `Scripts/Weapons/Helpers/ads_controller.gd`

  (project-local, **not** in `addons/cogito` as the draft claimed) — so we are

  free to edit it.

- `ADSController._apply_scope_sensitivity()` (`ads_controller.gd:127-141`)

  only scans **direct children** for `ScopeController`. Instancing a scope

  under a `%SightMount` Marker3D makes it a grandchild; the scan must become

  recursive or scope sensitivity stops working.

- The TAC30 scope scene

  (`Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_1-4x24_riflescope.tscn`)

  defaults to `magnification = 6.0`, `base_fov_at_1x = 75.0`, but `m700.tscn`

  currently inline-overrides `base_fov_at_1x = 60.0` on the scope node. If the

  scope becomes an attachment instantiated fresh from the PackedScene, that

  inline override must migrate onto the attachment resource or it silently

  regresses.

- `M700.tres` uses `BoltAction_Resource` (not `MarksmanRifle_Resource`), so

  `weapon_data.is_scope_weapon()` returns **false** for M700 today. The

  existing ADS position tween behaviour must not change; the scope just

  renders through its own `SubViewport` camera. Keep this as-is.

- `M700_Drop.tscn` also instances the TAC30 scope scene, so pickup/world-model

  parity is a separate concern from first-person attachment wiring.

- `_apply_recoil()` / `recoilFire()` on `weapon_recoil.gd` reads the vectors

  that `_configure_recoil` pushed in, so multiplying at configure time is

  sufficient — no per-shot plumbing needed.

- `cogito_weapon.gd` already uses the `X = XClass.new(self)` helper pattern

  (`_trigger`, `_ads`, `_shoot_motion`), so a `WeaponAttachmentController`

  that is `RefCounted` fits the existing shape.



## Shape of the change



```

                         ┌─ sight_attachment (.tres) ───────┐

                         │  attachment_scene: PackedScene   │

                         │  base_fov_at_1x_override         │

                         │  magnification_override          │

                         │  ads_offset_override             │

                         └──────────────────────────────────┘

                                       │

Weapon scene (.tscn)                   │  assigned in Inspector

  ├── %Bullet_Point                    ▼

  ├── %SightMount   ◀── WeaponAttachmentController.apply_all()

  │     └── (instanced scope scene, ScopeController inside)

  ├── %MuzzleMount ◀───────┐

  │     └── (instanced muzzle model)

  └── cogito_weapon.gd     │

        ._ready()          │

          _attachments = WeaponAttachmentController.new(self)

          _attachments.apply_all()        ─┘

        ._configure_recoil()

          hip *= _attachments.recoil_multiplier

        ._try_fire()

          sound_shoot ← _attachments.sound_shoot_override or sound_shoot

          ctx["attachment_modifiers"] = _attachments.modifiers



                                    │

                                    ▼

                      ADSController._apply_scope_sensitivity()

                      now scans DESCENDANTS (not just direct children)

                      so the grandchild ScopeController is found.

```



The diagram shows the only three places existing logic is touched:

`_configure_recoil`, `_try_fire` audio block, and `_build_fire_context`. All

new code lives under `Scripts/Weapons/Attachments/`.



## Files to create



### 1. `Scripts/Weapons/Attachments/attachment_resource.gd`

```gdscript

class_name AttachmentResource

extends Resource



@export var display_name: String = ""

@export var icon: Texture2D                  # reserved for v2 UI

@export var attachment_scene: PackedScene    # instantiated into the mount

```

Base class only. No logic.



### 2. `Scripts/Weapons/Attachments/sight_attachment_resource.gd`

```gdscript

class_name SightAttachmentResource

extends AttachmentResource



@export var is_optic: bool = true



## Additive offset applied on top of CogitoWeapon.ads_position when this

## sight is mounted. Vector3.ZERO = use weapon default.

@export var ads_offset_override: Vector3 = Vector3.ZERO



## If > 0, pushes into the spawned ScopeController after instantiation.

## These exist so the existing M700 inline override (base_fov_at_1x = 60)

## can be preserved when the scope becomes an attachment resource.

@export var magnification_override: float = -1.0

@export var base_fov_at_1x_override: float = -1.0

```



### 3. `Scripts/Weapons/Attachments/muzzle_attachment_resource.gd`

```gdscript

class_name MuzzleAttachmentResource

extends AttachmentResource



@export var damage_mul: float = 1.0

@export var spread_add_deg: float = 0.0

@export var recoil_mul: float = 1.0

@export var velocity_mul: float = 1.0

@export var range_mul: float = 1.0

@export var sound_shoot_override: AudioStream    # null = no override


```



### 4. `Scripts/Weapons/Attachments/weapon_attachment_controller.gd`

```gdscript

class_name WeaponAttachmentController

extends RefCounted



var _owner

var _sight_instance: Node3D

var _muzzle_instance: Node3D

var modifiers: Dictionary = {}         # merged numeric modifiers

var recoil_multiplier: float = 1.0



func _init(owner) -> void:

    _owner = owner



func apply_all() -> void:

    modifiers = _default_modifiers()

    _apply_sight()

    _apply_muzzle()



func get_sound_shoot_override() -> AudioStream:

    var muzzle: MuzzleAttachmentResource = _owner.muzzle_attachment

    return muzzle.sound_shoot_override if muzzle else null



func _default_modifiers() -> Dictionary:

    return {

        "damage_mul": 1.0,

        "spread_add_deg": 0.0,

        "recoil_mul": 1.0,

        "velocity_mul": 1.0,

        "range_mul": 1.0,

    }



func _apply_sight() -> void:

    var sight: SightAttachmentResource = _owner.sight_attachment

    var mount: Marker3D = _owner.sight_mount

    if sight == null or sight.attachment_scene == null or mount == null:

        return

    _sight_instance = sight.attachment_scene.instantiate()

    mount.add_child(_sight_instance)

    # Push scope overrides if present.

    var sc: ScopeController = _sight_instance as ScopeController

    if sc == null:

        sc = _find_scope_controller(_sight_instance)

    if sc:

        if sight.magnification_override > 0.0:

            sc.magnification = sight.magnification_override

        if sight.base_fov_at_1x_override > 0.0:

            sc.base_fov_at_1x = sight.base_fov_at_1x_override



func _apply_muzzle() -> void:

    var muzzle: MuzzleAttachmentResource = _owner.muzzle_attachment

    var mount: Marker3D = _owner.muzzle_mount

    if muzzle == null:

        return

    if muzzle.attachment_scene and mount:

        _muzzle_instance = muzzle.attachment_scene.instantiate()

        mount.add_child(_muzzle_instance)

    modifiers["damage_mul"]     = muzzle.damage_mul

    modifiers["spread_add_deg"] = muzzle.spread_add_deg

    modifiers["recoil_mul"]     = muzzle.recoil_mul

    modifiers["velocity_mul"]   = muzzle.velocity_mul

    modifiers["range_mul"]      = muzzle.range_mul

    recoil_multiplier = muzzle.recoil_mul

```

`RefCounted` mirrors how `ADSController` / `TriggerAnimator` are constructed

from `cogito_weapon.gd` today.



### 5. `Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_Sight.tres` (example)

A `SightAttachmentResource` pointing at the existing TAC30 scope scene with

`base_fov_at_1x_override = 60.0` (preserves the inline override that exists

in `m700.tscn` today). Leave `magnification_override` unset so the current TAC30

scene default (`magnification = 6.0`) is preserved.



## Files to modify



### A. `Scripts/Weapons/cogito_weapon.gd`



1. Add exports — extend `@export_group("Muzzle")` or add a new

   `@export_group("Attachments")` after it:

   ```gdscript

   @export_group("Attachments")

   @export var sight_attachment: SightAttachmentResource

   @export var muzzle_attachment: MuzzleAttachmentResource

   @onready var sight_mount: Marker3D = get_node_or_null("%SightMount") as Marker3D

   @onready var muzzle_mount: Marker3D = get_node_or_null("%MuzzleMount") as Marker3D

   ```

2. Add state next to `_ads`, `_trigger`, etc. around `cogito_weapon.gd:87`:

   ```gdscript

   var _attachments: WeaponAttachmentController

   ```

3. Append to `_ready()` (`cogito_weapon.gd:109`):

   ```gdscript

   _attachments = WeaponAttachmentController.new(self)

   _attachments.apply_all()

   ```

   Must run **before** `_configure_recoil()` is called in `equip()` — and it

   does, because `_ready` runs before `equip`.

4. Patch `_configure_recoil()` (`cogito_weapon.gd:485-492`):

   ```gdscript

   var mul: float = _attachments.recoil_multiplier if _attachments else 1.0

   var hip := Vector3(weapon_data.recoilVertical, weapon_data.recoilHorizontal, 0.0) * mul

   ...

   var aim := aim_recoil_values if aim_recoil_values.length() > RECOIL_THRESHOLD else hip * ADS_RECOIL_SCALE

   ```

   (hip already carries the multiplier, so aim inherits it via the fallback.)

5. Patch audio block in `_try_fire()` (`cogito_weapon.gd:321-323`):

   ```gdscript

   var stream: AudioStream = null

   if _attachments:

       stream = _attachments.get_sound_shoot_override()

   if stream == null:

       stream = sound_shoot

   if stream:

       audio_stream_player_3d.stream = stream

       audio_stream_player_3d.play()

   ```

6. Patch `_build_fire_context()` (`cogito_weapon.gd:360`):

   ```gdscript

   ctx["attachment_modifiers"] = _attachments.modifiers if _attachments else {}

   ```

   Just injects the dict — **no** `Weapon_Resource` subclass is edited in v1.

7. For the per-sight ADS offset override, add one helper and feed it into the

   three call-sites that pass `ads_position` into `ADSController`:

   ```gdscript

   func _effective_ads_position() -> Vector3:

       if sight_attachment and sight_attachment.ads_offset_override != Vector3.ZERO:

           return ads_position + sight_attachment.ads_offset_override

       return ads_position

   ```

   Replace `ads_position` with `_effective_ads_position()` in `unequip()`

   (`cogito_weapon.gd:170`), `action_secondary()` (`cogito_weapon.gd:219`),

   and `_play_shoot_visual()` (`cogito_weapon.gd:379`). No changes needed

   inside `ADSController` for the offset.



Total hand-edited lines in `cogito_weapon.gd` ≈ 20.



### B. `Scripts/Weapons/Helpers/ads_controller.gd` (project-local, editable)



Rewrite the direct-child scan in `_apply_scope_sensitivity()`

(`ads_controller.gd:130-134`) to walk descendants, so a `ScopeController`

spawned under `%SightMount` is still found:

```gdscript

var sc: ScopeController = _find_scope_controller(_owner)

...



static func _find_scope_controller(root: Node) -> ScopeController:

    var stack: Array = [root]

    while not stack.is_empty():

        var n: Node = stack.pop_back()

        if n is ScopeController:

            return n

        for c in n.get_children():

            stack.append(c)

    return null

```

This is the only edit to `ads_controller.gd` — lines 107/71/77 that check

`weapon_data.is_scope_weapon()` remain untouched, preserving the existing

M700 ADS tween behaviour.



### C. Weapon scenes — add mount points

- `Scene/Weapom/Firearms/Bolt-action/M700/m700.tscn`:

  - Add `%SightMount` (Marker3D, `unique_name_in_owner = true`) at the

    current scope transform

    `Transform3D(1,0,0,0,1,0,0,0,1, -0.11561626, 0.17186859, 0.0009773622)`.

  - Remove the existing inline `Tac3014x24Riflescope` child node and replace

    it with `sight_attachment =`

    `res://Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_Sight.tres`.

  - Add `%MuzzleMount` (Marker3D) at the muzzle, seeded from `%Bullet_Point`

    and tuned in the editor if a muzzle visual is later attached.

  - Do **not** remove the weapon-root `SubViewport` / `Camera3D` in v1 unless

    runtime validation proves they are unused.

- `Scene/Weapom/Firearms/AR/AK47/AK47.tscn`:

  - Add `%MuzzleMount` Marker3D at the muzzle brake position around

    `Transform3D(..., -1.8787955e-07, 0.18381743, -4.298183)`.

  - Leave `sight_attachment` and `muzzle_attachment` empty so AK47 behaviour

    remains unchanged by default.

  - Do **not** add `%SightMount` in v1 unless an exact validated transform is

    chosen in-editor; the previous “approximate and tune” wording was not

    decision-complete enough.

- `Scene/Weapom/Firearms/Bolt-action/M700/M700_Drop.tscn`:

  - Not part of v1 first-person attachment wiring.

  - If visual parity for dropped world models is required, treat it as a

    follow-up so pickup/world-model visuals stay in sync with the wieldable.

Not changed: projectile code, `Weapon_Resource.gd`, any `Types/*.gd`, any

addon file, the existing recoil node, player scripts.



## Critical files reference



| Purpose                                  | Path                                                                                              |

|------------------------------------------|---------------------------------------------------------------------------------------------------|

| Main orchestrator to hook                | `Scripts/Weapons/cogito_weapon.gd`                                                                |

| ADS controller (scope discovery fix)     | `Scripts/Weapons/Helpers/ads_controller.gd`                                                       |

| Reused as-is (no edits)                  | `Scripts/Weapons/scope_controller.gd`                                                             |

| Reused as-is (no edits)                  | `Scripts/Weapons/weapon_recoil.gd`                                                                |

| Reused as-is (no edits)                  | `Scripts/Weapons/Weapon_Resource.gd` and `Scripts/Weapons/Types/*.gd`                             |

| Scope scene reused by sight resource     | `Scene/Attachment/Scope/TAC30_1-4x24_riflescope/TAC30_1-4x24_riflescope.tscn`                     |

| Weapon scene edits                       | `Scene/Weapom/Firearms/Bolt-action/M700/m700.tscn`, `Scene/Weapom/Firearms/AR/AK47/AK47.tscn`     |



## Verification

1. **Editor load** — open the project, open `m700.tscn` and `AK47.tscn`;

   there must be no load errors in the Godot output panel. `SightMount` and

   `MuzzleMount` must resolve as unique nodes where present.

2. **M700 scope regression** — run the game, pick up M700, press

   `action_secondary` (ADS). Preserve current behaviour:

   `magnification = 6.0`, `base_fov_at_1x = 60.0`, effective scope camera FOV

   `= 10.0`. If the view changes, `TAC30_Sight.tres` is missing the

   `base_fov_at_1x_override` or is overriding magnification incorrectly.

3. **Scope sensitivity** — while ADS is active on M700, look around. Mouse

   sens must still be multiplied by `0.6` (the TAC30 default). If it isn't,

   the descendant scan in `ads_controller.gd` is broken.

4. **Modifier plumbing sanity** — create a dummy

   `MuzzleAttachmentResource.tres` with

   `damage_mul = 0.85, recoil_mul = 0.7, sound_shoot_override = <any wav>`,

   assign it to AK47's `muzzle_attachment`, run, hold fire. Expect: visibly

   reduced recoil kick, overridden audio, no shot-path exceptions. Damage

   does not change yet in v1; only the modifier dictionary plumbing and recoil

   / audio consumption should change.

5. **Null safety** — remove the sight resource on M700, run. Expect: no

   spawned scope child, no errors, `_attachments.modifiers` equals the default

   modifier dict, and ADS still does a plain position tween as before.

6. **Static check** — `godot --headless --check-only` over the four new

   scripts (or the editor's script validator) must report no parse errors.

7. **World model scope parity** — `pickup_m700.tscn` / `M700_Drop.tscn` should

   still render as before in v1 unless a separate follow-up explicitly updates

   the drop model attachment visuals.

## Out of scope (future work)



- Pickup scene + `AttachmentItemPD` inventory item

- Runtime attach/detach via inventory drag/drop

- Attachment selection UI / stat preview

- Save/load attachment state per weapon

- Barrel / grip / magazine / laser / flashlight slots

- Pickup/world drop visual parity with first-person attachments, including

  `M700_Drop.tscn`

- Actually consuming `ctx["attachment_modifiers"]` inside each

  `Types/*.gd` subclass to scale damage / spread / velocity / range — v1

  only exposes the hook.





