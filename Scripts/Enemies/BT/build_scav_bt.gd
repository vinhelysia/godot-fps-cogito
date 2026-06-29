extends SceneTree

func _init():
	var bt = BehaviorTree.new()
	var root = BTSelector.new()
	bt.root_task = root

	# Combat Branch
	var combat_seq = BTSequence.new()
	combat_seq.name = "CombatSequence"

	var cond_combat = load("res://Scripts/Enemies/BT/Tasks/btc_alert_at_least.gd").new()
	cond_combat.min_level = 3 # AlertState.COMBAT
	cond_combat.name = "IsCombatAlert"

	var face = load("res://Scripts/Enemies/BT/Tasks/bt_face_target.gd").new()
	face.name = "FaceTarget"

	var combat_actions = BTSelector.new()
	combat_actions.name = "CombatActions"

	var strafe = load("res://Scripts/Enemies/BT/Tasks/bt_strafe.gd").new()
	strafe.name = "CombatStrafe"

	var shoot = load("res://Scripts/Enemies/BT/Tasks/bt_shoot.gd").new()
	shoot.name = "ShootTarget"

	# Load default assets if they exist
	if ResourceLoader.exists("res://addons/cogito/Assets/Audio/Kenney/Pistol_Shot.wav"):
		shoot.shoot_sound = load("res://addons/cogito/Assets/Audio/Kenney/Pistol_Shot.wav")

	if ResourceLoader.exists("res://addons/cogito/PackedScenes/VFX/muzzle_flash.tscn"):
		shoot.muzzle_flash_scene = load("res://addons/cogito/PackedScenes/VFX/muzzle_flash.tscn")

	var reload = load("res://Scripts/Enemies/BT/Tasks/bt_reload.gd").new()
	reload.name = "ReloadWeapon"
	if ResourceLoader.exists("res://addons/cogito/Assets/Audio/Kenney/Handle_Click.wav"):
		reload.reload_sound = load("res://addons/cogito/Assets/Audio/Kenney/Handle_Click.wav")

	var move_to_target = load("res://Scripts/Enemies/BT/Tasks/bt_move_to.gd").new()
	move_to_target.name = "MoveToTarget"
	move_to_target.position_var = &"last_known_position"

	combat_actions.add_child(strafe)
	combat_actions.add_child(shoot)
	combat_actions.add_child(reload)
	combat_actions.add_child(move_to_target)

	combat_seq.add_child(cond_combat)
	combat_seq.add_child(face)
	combat_seq.add_child(combat_actions)

	root.add_child(combat_seq)

	# Investigate Branch
	var invest_seq = BTSequence.new()
	invest_seq.name = "InvestigateSequence"

	var cond_invest = load("res://Scripts/Enemies/BT/Tasks/btc_has_last_known.gd").new()
	cond_invest.name = "HasInvestigationTarget"

	var move_to_invest = load("res://Scripts/Enemies/BT/Tasks/bt_move_to.gd").new()
	move_to_invest.name = "MoveToInvestigation"
	move_to_invest.position_var = &"last_known_position"

	var look_around = load("res://Scripts/Enemies/BT/Tasks/bt_look_around.gd").new()
	look_around.name = "LookAround"

	invest_seq.add_child(cond_invest)
	invest_seq.add_child(move_to_invest)
	invest_seq.add_child(look_around)

	root.add_child(invest_seq)

	# Patrol Branch
	var patrol = load("res://Scripts/Enemies/BT/Tasks/bt_patrol.gd").new()
	patrol.name = "PatrolPath"
	root.add_child(patrol)

	# Create dir and save
	DirAccess.make_dir_recursive_absolute("res://Scene/Enemies/BT")

	var err = ResourceSaver.save(bt, "res://Scene/Enemies/BT/scav_brain.tres")
	print("Saved scav_brain.tres: ", err)
	quit()
