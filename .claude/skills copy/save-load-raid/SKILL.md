# Save / Load — PMC Inventory Persistence Between Raids

## Strategy: C# for serialization, GDScript for triggering save events

---

## C# — Binary Save System

```csharp
// src/Core/SaveManager.cs
using Godot;
using System.Collections.Generic;
using System.Text.Json;

public partial class SaveManager : Node
{
    private const string SavePath = "user://pmc_data.json";

    public static void SaveProfile(PmcProfile profile)
    {
        var json = JsonSerializer.Serialize(profile, new JsonSerializerOptions
        {
            WriteIndented = false
        });
        using var file = FileAccess.Open(SavePath, FileAccess.ModeFlags.Write);
        file.StoreString(json);
    }

    public static PmcProfile? LoadProfile()
    {
        if (!FileAccess.FileExists(SavePath)) return null;
        using var file = FileAccess.Open(SavePath, FileAccess.ModeFlags.Read);
        string json = file.GetAsText();
        return JsonSerializer.Deserialize<PmcProfile>(json);
    }
}

public class PmcProfile
{
    public string PmcName { get; set; } = "PMC";
    public int Level { get; set; } = 1;
    public int Rubles { get; set; } = 100_000;
    public List<ItemSaveData> StashItems { get; set; } = new();
    public List<ItemSaveData> EquippedItems { get; set; } = new();
}

public class ItemSaveData
{
    public string ItemId { get; set; } = "";
    public int GridX { get; set; }
    public int GridY { get; set; }
    public int Durability { get; set; } = 100;
    public Dictionary<string, string> Attachments { get; set; } = new();
}
```

## GDScript — Trigger save at right moments

```gdscript
# scripts/autoloads/game_lifecycle.gd
extends Node

@onready var save_manager: SaveManager = $SaveManager  # C# node

func _ready() -> void:
    get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_and_quit()

func on_raid_extracted(player: Node) -> void:
    # Only save on successful extraction
    var profile := _build_profile_from_player(player)
    save_manager.save_profile(profile)
    get_tree().change_scene_to_file("res://scenes/hideout.tscn")

func on_raid_died(player: Node) -> void:
    # Wipe equipped gear (Tarkov-style loss)
    var profile := _build_profile_from_player(player)
    profile.equipped_items.clear()
    save_manager.save_profile(profile)
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _save_and_quit() -> void:
    save_manager.save_profile(_build_profile_from_player(
        get_tree().get_first_node_in_group("player")))
    get_tree().quit()
```
