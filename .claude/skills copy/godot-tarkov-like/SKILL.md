---
name: godot-tarkov-like
description: >
  Expert guidance for building an Escape from Tarkov-style tactical extraction shooter in Godot 4.x
  using a C# + GDScript hybrid architecture. Use this skill whenever the user is working on:
  a tactical shooter, extraction game, survival FPS, looter-shooter, inventory system, ballistics,
  AI soldiers/enemies, raid mechanics, hideout systems, weapon attachments, or any Godot game that
  benefits from mixing C# (performance-critical) and GDScript (gameplay scripting). Always trigger
  this skill when the user asks about C# vs GDScript decision-making in Godot, or when building
  any system inspired by Tarkov, DayZ, Hunt: Showdown, or similar hardcore tactical games.
compatibility: Godot 4.x, C# (.NET 8+), GDScript. Requires Mono/C# support enabled in Godot build.
metadata:
  author: agent-skills
  version: "1.0"
  godot_version: "4.x"
---

# Godot Tarkov-Like Game — C# + GDScript Hybrid Skill

This skill guides you in building a hardcore tactical extraction shooter (Escape from Tarkov style)
in Godot 4.x using the right language at the right time: **C# for performance-critical systems**,
**GDScript for rapid gameplay scripting and scene logic**.

---

## 🧠 The Golden Rule: When to Use C# vs GDScript

Use this decision table for EVERY new system:

| System | Language | Why |
|--------|----------|-----|
| Ballistics / raycasting math | **C#** | Float-heavy math, called every frame per bullet |
| Inventory data structures | **C#** | Complex nested data, serialization, LINQ |
| AI pathfinding & perception | **C#** | Large agent counts, heavy computation |
| Networking (sync, packets) | **C#** | Low-level control, byte manipulation |
| Animation state machines | **GDScript** | Tightly coupled to AnimationTree nodes |
| UI / HUD logic | **GDScript** | Rapid iteration, signal-heavy, node-bound |
| Scene-specific gameplay flow | **GDScript** | Trigger zones, cutscenes, objectives |
| Sound / audio management | **GDScript** | Simple event-driven calls |
| Config/export variables | **GDScript** | Designer-facing, editor-friendly |
| Save/load coordination | **C#** | JSON serialization, binary packing |

### The Simple Mental Model

```
Is it math-heavy or data-heavy and called frequently? → C#
Is it node-glue, editor-facing, or event-driven? → GDScript
```

---

## 📁 Project Structure

```
res://
├── src/                        # All C# source files
│   ├── Core/
│   │   ├── GameManager.cs
│   │   └── EventBus.cs
│   ├── Player/
│   │   ├── PlayerController.cs
│   │   └── StaminaSystem.cs
│   ├── Weapons/
│   │   ├── WeaponBase.cs
│   │   ├── BallisticsEngine.cs
│   │   └── WeaponAttachmentSystem.cs
│   ├── Inventory/
│   │   ├── InventoryGrid.cs
│   │   ├── ItemData.cs
│   │   └── LootTable.cs
│   ├── AI/
│   │   ├── AIAgent.cs
│   │   ├── AIPerception.cs
│   │   └── AISquadManager.cs
│   └── Networking/
│       └── RaidSyncManager.cs
│
├── scripts/                    # All GDScript files
│   ├── player/
│   │   ├── player_hud.gd
│   │   ├── player_animation.gd
│   │   └── player_audio.gd
│   ├── ui/
│   │   ├── inventory_ui.gd
│   │   ├── map_ui.gd
│   │   └── death_screen.gd
│   ├── world/
│   │   ├── extraction_zone.gd
│   │   ├── loot_container.gd
│   │   └── raid_timer.gd
│   └── autoloads/
│       ├── audio_manager.gd
│       └── ui_manager.gd
│
├── resources/                  # .tres / .res resource files
│   ├── items/
│   ├── weapons/
│   └── ai_configs/
│
└── scenes/
    ├── player/
    ├── enemies/
    ├── world/
    └── ui/
```

---

## 🔫 Core Systems

### 1. Ballistics Engine (C#) — Heavy Math → C#

```csharp
// src/Weapons/BallisticsEngine.cs
using Godot;

public partial class BallisticsEngine : Node
{
    // Called per-bullet, per-frame — needs C# speed
    public static HitResult SimulateBullet(
        Vector3 origin,
        Vector3 direction,
        float velocity,
        float drag,
        float mass,
        float maxDistance,
        ulong collisionMask,
        Node3D shooter)
    {
        var spaceState = shooter.GetWorld3D().DirectSpaceState;
        Vector3 pos = origin;
        Vector3 vel = direction * velocity;
        float distanceTraveled = 0f;

        while (distanceTraveled < maxDistance)
        {
            // Apply gravity drop
            vel.Y -= 9.8f * 0.016f;
            // Apply drag
            vel *= (1f - drag * 0.016f);

            Vector3 nextPos = pos + vel * 0.016f;
            distanceTraveled += vel.Length() * 0.016f;

            var query = PhysicsRayQueryParameters3D.Create(pos, nextPos, collisionMask);
            query.Exclude = new Godot.Collections.Array<Rid> { shooter.GetRid() };

            var result = spaceState.IntersectRay(query);
            if (result.Count > 0)
            {
                float penetrationForce = CalculatePenetration(vel.Length(), mass);
                return new HitResult
                {
                    Hit = true,
                    Position = result["position"].AsVector3(),
                    Normal = result["normal"].AsVector3(),
                    Collider = result["collider"].AsGodotObject(),
                    Energy = penetrationForce,
                    Distance = distanceTraveled,
                };
            }
            pos = nextPos;
        }
        return new HitResult { Hit = false };
    }

    private static float CalculatePenetration(float speed, float mass) =>
        0.5f * mass * speed * speed; // Kinetic energy
}

public struct HitResult
{
    public bool Hit;
    public Vector3 Position;
    public Vector3 Normal;
    public GodotObject Collider;
    public float Energy;
    public float Distance;
}
```

### 2. Weapon System (C# base, GDScript for animation)

```csharp
// src/Weapons/WeaponBase.cs
using Godot;
using System.Collections.Generic;

public partial class WeaponBase : Node3D
{
    [Export] public WeaponData Data { get; set; }

    // Performance-critical state — C#
    private float _currentRecoil;
    private float _heatAccumulation;
    private int _chamberRound;
    private Queue<float> _recoilPattern = new();

    [Signal] public delegate void WeaponFiredEventHandler(Vector3 muzzlePos, Vector3 direction);
    [Signal] public delegate void AmmoChangedEventHandler(int current, int max);
    [Signal] public delegate void WeaponJammedEventHandler();

    public void TryFire(Vector3 aimDirection)
    {
        if (_chamberRound <= 0) { EmitSignal(SignalName.WeaponJammed); return; }

        Vector3 spread = ApplySpread(aimDirection);
        _chamberRound--;
        _heatAccumulation += Data.HeatPerShot;
        _currentRecoil += Data.RecoilForce;

        EmitSignal(SignalName.WeaponFired, GlobalPosition, spread);
        EmitSignal(SignalName.AmmoChanged, _chamberRound, Data.MagazineSize);

        // Ballistics handled by C# engine
        BallisticsEngine.SimulateBullet(
            GlobalPosition, spread, Data.MuzzleVelocity,
            Data.BulletDrag, Data.BulletMass, Data.MaxRange,
            Data.CollisionMask, this);
    }

    private Vector3 ApplySpread(Vector3 dir)
    {
        float spread = Data.BaseSpread + _currentRecoil * Data.RecoilSpreadMultiplier;
        return dir.Rotated(Vector3.Up, (float)GD.RandRange(-spread, spread))
                  .Rotated(Vector3.Right, (float)GD.RandRange(-spread, spread))
                  .Normalized();
    }

    public override void _Process(double delta)
    {
        _currentRecoil = Mathf.MoveToward(_currentRecoil, 0f, Data.RecoilRecovery * (float)delta);
        _heatAccumulation = Mathf.MoveToward(_heatAccumulation, 0f, Data.CoolRate * (float)delta);
    }
}
```

```gdscript
# scripts/player/weapon_animation.gd — GDScript handles animation, feels, audio
extends Node

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer3D = $Audio
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream

var _weapon: WeaponBase  # C# node referenced from GDScript

func _ready() -> void:
    _weapon = get_parent() as WeaponBase
    _weapon.weapon_fired.connect(_on_fired)
    _weapon.weapon_jammed.connect(_on_jammed)

func _on_fired(_pos: Vector3, _dir: Vector3) -> void:
    animation_player.play("fire")
    audio.stream = fire_sound
    audio.play()

func _on_jammed() -> void:
    animation_player.play("jam_react")
```

### 3. Inventory Grid (C#) — Data-Heavy → C#

```csharp
// src/Inventory/InventoryGrid.cs
using Godot;
using System.Collections.Generic;
using System.Linq;

public partial class InventoryGrid : Node
{
    private ItemData?[,] _grid;
    private int _width;
    private int _height;

    [Signal] public delegate void ItemAddedEventHandler(ItemData item, Vector2I position);
    [Signal] public delegate void ItemRemovedEventHandler(ItemData item);

    public void Initialize(int width, int height)
    {
        _width = width;
        _height = height;
        _grid = new ItemData[width, height];
    }

    public bool TryAddItem(ItemData item, Vector2I position)
    {
        if (!CanFit(item, position)) return false;

        for (int x = 0; x < item.GridSize.X; x++)
            for (int y = 0; y < item.GridSize.Y; y++)
                _grid[position.X + x, position.Y + y] = item;

        EmitSignal(SignalName.ItemAdded, item, position);
        return true;
    }

    public bool TryAutoPlace(ItemData item)
    {
        for (int y = 0; y < _height - item.GridSize.Y + 1; y++)
            for (int x = 0; x < _width - item.GridSize.X + 1; x++)
                if (TryAddItem(item, new Vector2I(x, y))) return true;
        return false;
    }

    private bool CanFit(ItemData item, Vector2I at)
    {
        if (at.X + item.GridSize.X > _width || at.Y + item.GridSize.Y > _height) return false;
        for (int x = 0; x < item.GridSize.X; x++)
            for (int y = 0; y < item.GridSize.Y; y++)
                if (_grid[at.X + x, at.Y + y] != null) return false;
        return true;
    }

    public List<ItemData> GetAllItems() =>
        _grid.Cast<ItemData?>().Where(i => i != null).Distinct().ToList()!;
}
```

```gdscript
# scripts/ui/inventory_ui.gd — GDScript renders the grid
extends Control

@onready var grid_container: GridContainer = $GridContainer
var _inventory: InventoryGrid  # C# node

func setup(inventory: InventoryGrid) -> void:
    _inventory = inventory
    _inventory.item_added.connect(_on_item_added)
    _inventory.item_removed.connect(_on_item_removed)
    _rebuild_grid()

func _on_item_added(item: ItemData, position: Vector2i) -> void:
    var slot := preload("res://scenes/ui/inventory_slot.tscn").instantiate()
    slot.setup(item, position)
    grid_container.add_child(slot)

func _on_item_removed(_item: ItemData) -> void:
    _rebuild_grid()

func _rebuild_grid() -> void:
    for child in grid_container.get_children():
        child.queue_free()
    for item in _inventory.get_all_items():
        _spawn_item_icon(item)
```

### 4. AI Agent (C#) — Complex Perception → C#

```csharp
// src/AI/AIPerception.cs
using Godot;
using System.Collections.Generic;
using System.Linq;

public partial class AIPerception : Node3D
{
    [Export] public float VisionRange = 50f;
    [Export] public float VisionAngle = 110f;  // degrees
    [Export] public float HearingRange = 30f;
    [Export] public NodePath PlayerPath;

    private Node3D _player;
    private float _suspicionLevel = 0f;
    private List<SoundEvent> _soundQueue = new();

    [Signal] public delegate void PlayerSpottedEventHandler(Node3D player);
    [Signal] public delegate void SuspicionChangedEventHandler(float level);

    public override void _Ready()
    {
        _player = GetNode<Node3D>(PlayerPath);
    }

    public override void _PhysicsProcess(double delta)
    {
        CheckLineOfSight();
        ProcessSoundEvents((float)delta);
    }

    private void CheckLineOfSight()
    {
        Vector3 toPlayer = _player.GlobalPosition - GlobalPosition;
        if (toPlayer.Length() > VisionRange) return;

        float angle = Mathf.RadToDeg(GlobalTransform.Basis.Z.AngleTo(toPlayer.Normalized()));
        if (angle > VisionAngle * 0.5f) return;

        var spaceState = GetWorld3D().DirectSpaceState;
        var query = PhysicsRayQueryParameters3D.Create(GlobalPosition, _player.GlobalPosition);
        var result = spaceState.IntersectRay(query);

        if (result.Count > 0 && result["collider"].AsGodotObject() == _player)
        {
            _suspicionLevel = Mathf.Min(_suspicionLevel + 50f, 100f);
            EmitSignal(SignalName.SuspicionChanged, _suspicionLevel);
            if (_suspicionLevel >= 100f)
                EmitSignal(SignalName.PlayerSpotted, _player);
        }
    }

    public void ReceiveSound(Vector3 origin, float loudness)
    {
        float dist = GlobalPosition.DistanceTo(origin);
        if (dist < HearingRange)
            _soundQueue.Add(new SoundEvent { Origin = origin, Loudness = loudness * (1f - dist / HearingRange) });
    }

    private void ProcessSoundEvents(float delta)
    {
        _suspicionLevel = Mathf.MoveToward(_suspicionLevel, 0f, 5f * delta);
        foreach (var sound in _soundQueue)
            _suspicionLevel = Mathf.Min(_suspicionLevel + sound.Loudness * 10f, 100f);
        _soundQueue.Clear();
        EmitSignal(SignalName.SuspicionChanged, _suspicionLevel);
    }
}

record SoundEvent { public Vector3 Origin; public float Loudness; }
```

```gdscript
# scripts/enemies/ai_behavior.gd — GDScript wires AI behavior to scene nodes
extends Node

@onready var perception: AIPerception = $AIPerception   # C# node
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animator: AnimationTree = $AnimationTree

enum State { PATROL, SUSPICIOUS, COMBAT, SEARCH }
var _state: State = State.PATROL
var _target: Node3D

func _ready() -> void:
    perception.player_spotted.connect(_on_player_spotted)
    perception.suspicion_changed.connect(_on_suspicion_changed)

func _on_player_spotted(player: Node3D) -> void:
    _target = player
    _state = State.COMBAT
    animator.set("parameters/state/transition_request", "combat")

func _on_suspicion_changed(level: float) -> void:
    if level > 50.0 and _state == State.PATROL:
        _state = State.SUSPICIOUS
        animator.set("parameters/state/transition_request", "suspicious")
```

---

## 🗺️ Raid / Extraction System (GDScript) — Event-driven → GDScript

```gdscript
# scripts/world/extraction_zone.gd
class_name ExtractionZone
extends Area3D

signal extraction_started(player: Node3D)
signal extraction_completed(player: Node3D)
signal extraction_failed(player: Node3D, reason: String)

@export var extract_time: float = 7.0
@export var zone_name: String = "Gate V-Ex"

var _extracting_players: Dictionary = {}  # player -> timer

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    extraction_started.emit(body)
    _extracting_players[body] = 0.0

func _on_body_exited(body: Node3D) -> void:
    if body in _extracting_players:
        _extracting_players.erase(body)
        extraction_failed.emit(body, "Left extraction zone")

func _process(delta: float) -> void:
    for player in _extracting_players.keys():
        _extracting_players[player] += delta
        if _extracting_players[player] >= extract_time:
            extraction_completed.emit(player)
            _extracting_players.erase(player)
```

---

## 🔗 C# ↔ GDScript Communication Patterns

### C# emitting signals that GDScript listens to (most common)
```csharp
// C# side — emit the signal
EmitSignal(SignalName.HealthChanged, newHealth, maxHealth);
```
```gdscript
# GDScript side — connect in _ready
health_component.health_changed.connect(_on_health_changed)
func _on_health_changed(current: int, maximum: int) -> void:
    health_bar.value = float(current) / maximum
```

### GDScript calling C# methods
```gdscript
# GDScript can call C# methods directly — C# appears as normal nodes
var inventory: InventoryGrid = $InventoryGrid
var placed := inventory.try_auto_place(item_data)   # snake_case in GDScript
```

### Shared Data via Resources (best for config/items)
```csharp
// C# reads a GDScript Resource
[Export] public Resource WeaponDataResource { get; set; }
// Access properties via Variant
float damage = WeaponDataResource.Get("damage").AsSingle();
```

---

## 📦 Item Data Architecture

```csharp
// src/Inventory/ItemData.cs
using Godot;

[GlobalClass]
public partial class ItemData : Resource
{
    [Export] public string ItemId { get; set; } = "";
    [Export] public string DisplayName { get; set; } = "";
    [Export] public Vector2I GridSize { get; set; } = Vector2I.One;
    [Export] public float Weight { get; set; } = 0.1f;
    [Export] public int BaseValue { get; set; } = 0;
    [Export] public Texture2D Icon { get; set; }

    // Subtypes via composition, not inheritance
    [Export] public WeaponStats WeaponStats { get; set; }   // null if not a weapon
    [Export] public MedStats MedStats { get; set; }         // null if not medical
    [Export] public AmmoStats AmmoStats { get; set; }       // null if not ammo
}
```

---

## 🏥 Health / Body Part System (C#)

```csharp
// src/Player/HealthSystem.cs — Tarkov-style hitbox health
public partial class HealthSystem : Node
{
    public record BodyPart(string Name, float MaxHp, float BleedChance);

    private static readonly BodyPart[] Parts =
    [
        new("Head",   35f, 0.3f),
        new("Thorax", 85f, 0.15f),
        new("Stomach",70f, 0.2f),
        new("Left Arm",60f, 0.25f),
        new("Right Arm",60f, 0.25f),
        new("Left Leg",65f, 0.25f),
        new("Right Leg",65f, 0.25f),
    ];

    private float[] _hp;
    private bool[] _bleeding;

    [Signal] public delegate void PartDamagedEventHandler(string partName, float current, float max);
    [Signal] public delegate void PlayerDeadEventHandler(string killedByPart);
    [Signal] public delegate void BleedingStartedEventHandler(string partName);

    public void TakeDamage(int partIndex, float amount, float penetration)
    {
        _hp[partIndex] = Mathf.Max(0f, _hp[partIndex] - amount);
        EmitSignal(SignalName.PartDamaged, Parts[partIndex].Name, _hp[partIndex], Parts[partIndex].MaxHp);

        if (GD.Randf() < Parts[partIndex].BleedChance * (penetration / 100f))
        {
            _bleeding[partIndex] = true;
            EmitSignal(SignalName.BleedingStarted, Parts[partIndex].Name);
        }

        // Head or Thorax at 0 = death
        if ((partIndex == 0 || partIndex == 1) && _hp[partIndex] <= 0f)
            EmitSignal(SignalName.PlayerDead, Parts[partIndex].Name);
    }
}
```

---

## ⚡ Performance Tips for Tarkov-Like Games

1. **Bullets**: Never use physics bodies. Use C# raycasts per-tick with sub-stepping.
2. **AI**: Pool AI agents. Keep perception in C#, behavior trees in GDScript or C# depending on complexity.
3. **Inventory UI**: Only rebuild dirty slots. Never `queue_free()` + re-add everything on each update.
4. **Sound propagation**: Use `Area3D` + C# distance checks rather than per-bullet audio queries.
5. **Loot generation**: Do all loot table math in C# with `System.Random` (faster than GDScript `randi()`).
6. **Network sync**: Always in C#. Godot's ENet/WebSocket bindings are accessible from C#.

---

## 📚 Further Reference

- `references/weapon-attachment-system.md` — Slot-based attachment tree (C# + GDScript split)
- `references/ai-squad-behavior.md` — Coordinated AI squad patterns
- `references/raid-network-sync.md` — Multiplayer raid sync architecture
- `references/save-load-raid.md` — PMC inventory persistence between raids
