---
name: weapon-attachment-system
description: Build and iterate a Tarkov-like 3D weapon attachment system in Godot 4.6+ using a C# + GDScript hybrid architecture. Use when designing or implementing weapon customization, attachment slots, visual model swapping, stat calculations, and inventory integration.
---

# Weapon Attachment System — C# + GDScript Split

## Architecture Overview

The attachment system uses a **tree of slots** defined in C# (data + validation),
with GDScript handling the visual 3D model swapping and UI rendering.

---

## C# — Attachment Data & Validation

```csharp
// src/Weapons/WeaponAttachmentSystem.cs
using Godot;
using System.Collections.Generic;

public enum AttachmentSlot
{
    Barrel, Muzzle, HandGuard, Stock, Grip, Scope, Magazine, Underbarrel
}

public partial class WeaponAttachmentSystem : Node
{
    private Dictionary<AttachmentSlot, ItemData?> _slots = new();
    private WeaponData _baseWeapon;

    [Signal] public delegate void AttachmentChangedEventHandler(string slotName, ItemData item);
    [Signal] public delegate void StatsRecalculatedEventHandler(WeaponStatBlock stats);

    public bool TryAttach(AttachmentSlot slot, ItemData item)
    {
        if (item.AttachmentStats == null) return false;
        if (!item.AttachmentStats.ValidSlots.Contains(slot)) return false;
        if (!IsCompatible(slot, item)) return false;

        _slots[slot] = item;
        EmitSignal(SignalName.AttachmentChanged, slot.ToString(), item);
        EmitSignal(SignalName.StatsRecalculated, RecalculateStats());
        return true;
    }

    public WeaponStatBlock RecalculateStats()
    {
        var stats = _baseWeapon.BaseStats.Clone();
        foreach (var (_, item) in _slots)
        {
            if (item?.AttachmentStats == null) continue;
            stats.Recoil      += item.AttachmentStats.RecoilMod;
            stats.Accuracy    += item.AttachmentStats.AccuracyMod;
            stats.AimSpeed    += item.AttachmentStats.AimSpeedMod;
            stats.Ergonomics  += item.AttachmentStats.ErgonomicsMod;
        }
        return stats;
    }

    private bool IsCompatible(AttachmentSlot slot, ItemData item)
    {
        // Check if a barrel-mounted item conflicts with muzzle device, etc.
        if (slot == AttachmentSlot.Muzzle && _slots.ContainsKey(AttachmentSlot.Barrel))
        {
            var barrel = _slots[AttachmentSlot.Barrel];
            return barrel?.AttachmentStats?.AllowsMuzzleDevice ?? true;
        }
        return true;
    }
}
```

## GDScript — Visual Model Swap & UI

```gdscript
# scripts/player/weapon_visual.gd
extends Node3D

@onready var attachment_system: WeaponAttachmentSystem = $WeaponAttachmentSystem
@export var attachment_scene_map: Dictionary = {}  # item_id -> PackedScene

var _attached_nodes: Dictionary = {}

func _ready() -> void:
    attachment_system.attachment_changed.connect(_on_attachment_changed)
    attachment_system.stats_recalculated.connect(_on_stats_changed)

func _on_attachment_changed(slot_name: String, item: ItemData) -> void:
    # Remove old visual
    if slot_name in _attached_nodes:
        _attached_nodes[slot_name].queue_free()
        _attached_nodes.erase(slot_name)

    # Spawn new visual
    if item and item.item_id in attachment_scene_map:
        var scene: PackedScene = attachment_scene_map[item.item_id]
        var node := scene.instantiate()
        var mount := find_child(slot_name + "Mount")
        if mount:
            mount.add_child(node)
            _attached_nodes[slot_name] = node

func _on_stats_changed(stats: WeaponStatBlock) -> void:
    # Notify HUD — GDScript signal up to UI
    pass
```
