extends SceneTree


func _init() -> void:
	var generator_script = load("res://Scripts/Tool/generate_codebase_map.gd")
	var generator = generator_script.new()
	var result = generator.generate()
	print(JSON.stringify(result))
	quit()
