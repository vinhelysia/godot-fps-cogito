extends RefCounted

const OUTPUT_PATH := "res://docs/codebase-map.html"
const TEXT_EXTENSIONS := {
	"cfg": true,
	"gd": true,
	"gdshader": true,
	"godot": true,
	"html": true,
	"js": true,
	"json": true,
	"md": true,
	"po": true,
	"pot": true,
	"py": true,
	"res": true,
	"rst": true,
	"tex": true,
	"toml": true,
	"tres": true,
	"tscn": true,
	"txt": true,
}
const SLICE_DEFINITIONS := [
	{"label": "Main scene composition", "path": "res://Scene/Town.tscn", "depth": 1},
	{"label": "AK-47 pickup chain", "path": "res://Scene/Weapom/Firearms/AR/AK47/pickup_ak47.tscn", "depth": 3},
	{"label": "M700 pickup chain", "path": "res://Scene/Weapom/Firearms/Bolt-action/M700/pickup_m700.tscn", "depth": 3},
	{"label": "USP pickup chain", "path": "res://Scene/Weapom/Firearms/Pistol/USP/pickup_usp.tscn", "depth": 3},
	{"label": "Multiplayer test slice", "path": "res://Scene/Multiplayer/Test/mp_main.tscn", "depth": 2},
]

var _reference_regex := RegEx.new()
var _extends_regex := RegEx.new()
var _class_regex := RegEx.new()
var _node_regex := RegEx.new()
var _attr_regex := RegEx.new()


func _init() -> void:
	_reference_regex.compile("res://[^\"'\\s\\)\\]\\}>,]+")
	_extends_regex.compile("(?m)^extends\\s+([^\\n\\r]+)")
	_class_regex.compile("(?m)^class_name\\s+([A-Za-z0-9_]+)")
	_node_regex.compile("\\[node\\s+([^\\]]+)\\]")
	_attr_regex.compile("([A-Za-z_]+)=\"([^\"]*)\"")


func generate(output_path: String = OUTPUT_PATH) -> Dictionary:
	var files := _collect_files("res://")
	files.sort_custom(_sort_file_entries)

	var reference_graph := _build_reference_graph(files)
	var config := _load_project_config()
	var main_scene_raw := str(config.get_value("application", "run/main_scene", ""))
	var main_scene_path := _normalize_resource_ref(main_scene_raw)
	var data := {
		"project": _build_project_summary(files, config, main_scene_raw, main_scene_path),
		"files": files,
		"autoloads": _collect_autoloads(config),
		"input_actions": _collect_input_actions(config),
		"scripts": _collect_script_inventory(files, reference_graph),
		"references": reference_graph,
		"hotspots": _build_hotspots(reference_graph),
		"main_scene": _summarize_scene(main_scene_path),
		"slices": _collect_reference_slices(reference_graph),
		"boundaries": _build_boundaries(files),
		"notes": [
			"Generated from the current project tree under res://.",
			"Excluded generated artifacts: docs/_build and docs/codebase-map.html.",
			"Framework boundaries are marked so project-local logic is easier to spot.",
		],
	}

	var html := _build_html(data)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"output_path": output_path,
			"absolute_output_path": ProjectSettings.globalize_path(output_path),
			"error": "Unable to open output file for writing.",
		}

	file.store_string(html)
	file.close()

	return {
		"ok": true,
		"output_path": output_path,
		"absolute_output_path": ProjectSettings.globalize_path(output_path),
		"file_count": files.size(),
		"script_count": data["scripts"].size(),
		"scene_count": data["project"]["scene_count"],
	}


func _collect_files(root_path: String) -> Array:
	var files = []
	_walk_directory(root_path, files)
	return files


func _walk_directory(current_path: String, files: Array) -> void:
	var dir := DirAccess.open(current_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := current_path.path_join(entry)
			if dir.current_is_dir():
				if not _should_skip_directory(child_path):
					_walk_directory(child_path, files)
			elif not _should_skip_file(child_path):
				files.append(_build_file_entry(child_path))
		entry = dir.get_next()
	dir.list_dir_end()


func _should_skip_directory(path: String) -> bool:
	return path == "res://.godot" or path == "res://.git" or path == "res://docs/_build"


func _should_skip_file(path: String) -> bool:
	return path == OUTPUT_PATH


func _build_file_entry(path: String) -> Dictionary:
	return {
		"path": path,
		"name": path.get_file(),
		"extension": path.get_extension().to_lower(),
		"size": _get_file_size(path),
		"category": _classify_path(path),
	}


func _get_file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := file.get_length()
	file.close()
	return size


func _classify_path(path: String) -> String:
	if path.begins_with("res://addons/cogito"):
		return "framework"
	if path.begins_with("res://addons/"):
		return "tooling"
	if path.begins_with("res://Scripts/"):
		return "project-script"
	if path.begins_with("res://Scene/"):
		return "content-scene"
	if path.begins_with("res://Assets/"):
		return "asset"
	if path.begins_with("res://docs/"):
		return "docs"
	return "project-root"


func _sort_file_entries(a: Dictionary, b: Dictionary) -> bool:
	return String(a["path"]).nocasecmp_to(String(b["path"])) < 0


func _build_reference_graph(files: Array) -> Dictionary:
	var outbound := {}
	var inbound := {}

	for file in files:
		var path := String(file["path"])
		outbound[path] = []
		inbound[path] = []

	for file in files:
		var path := String(file["path"])
		if not _is_text_file(file):
			continue

		var content := FileAccess.get_file_as_string(path)
		if content.is_empty():
			continue

		var seen := {}
		for match in _reference_regex.search_all(content):
			var reference := match.get_string()
			if reference == path:
				continue
			seen[reference] = true

		var references = seen.keys()
		references.sort()
		outbound[path] = references
		for reference in references:
			if not inbound.has(reference):
				inbound[reference] = []
			inbound[reference].append(path)

	for reference in inbound.keys():
		inbound[reference].sort()

	return {"outbound": outbound, "inbound": inbound}


func _is_text_file(file: Dictionary) -> bool:
	return TEXT_EXTENSIONS.has(String(file["extension"]))


func _load_project_config() -> ConfigFile:
	var config := ConfigFile.new()
	var result := config.load("res://project.godot")
	if result != OK:
		push_warning("Unable to load project.godot, some sections may be missing.")
	return config


func _build_project_summary(files: Array, config: ConfigFile, main_scene_raw: String, main_scene_path: String) -> Dictionary:
	var extension_counts := _count_by_extension(files)
	var top_level_counts := _count_by_top_level(files)
	var directory_count := _count_unique_directories(files)
	var datetime := Time.get_datetime_dict_from_system()

	return {
		"name": String(config.get_value("application", "config/name", "Godot Project")),
		"generated_at": "%04d-%02d-%02d %02d:%02d:%02d" % [
			int(datetime.get("year", 0)),
			int(datetime.get("month", 0)),
			int(datetime.get("day", 0)),
			int(datetime.get("hour", 0)),
			int(datetime.get("minute", 0)),
			int(datetime.get("second", 0)),
		],
		"main_scene_raw": main_scene_raw,
		"main_scene_path": main_scene_path,
		"renderer": String(config.get_value("rendering", "renderer/rendering_method", "forward_plus")),
		"viewport_width": int(config.get_value("display", "window/size/viewport_width", 0)),
		"viewport_height": int(config.get_value("display", "window/size/viewport_height", 0)),
		"total_files": files.size(),
		"directory_count": directory_count,
		"scene_count": int(extension_counts.get("tscn", 0)),
		"resource_count": int(extension_counts.get("tres", 0)),
		"script_count": int(extension_counts.get("gd", 0)),
		"shader_count": int(extension_counts.get("gdshader", 0)),
		"extension_counts": extension_counts,
		"top_level_counts": top_level_counts,
	}


func _count_by_extension(files: Array) -> Dictionary:
	var counts := {}
	for file in files:
		var extension := String(file["extension"])
		if extension.is_empty():
			extension = "<noext>"
		counts[extension] = int(counts.get(extension, 0)) + 1
	return counts


func _count_by_top_level(files: Array) -> Array:
	var counts := {}
	for file in files:
		var path := String(file["path"]).trim_prefix("res://")
		var top := "<root>"
		if path.contains("/"):
			top = path.get_slice("/", 0)
		elif not path.is_empty():
			top = path
		counts[top] = int(counts.get(top, 0)) + 1

	var rows = []
	for key in counts.keys():
		rows.append({"label": key, "count": counts[key]})
	rows.sort_custom(_sort_count_rows)
	return rows


func _sort_count_rows(a: Dictionary, b: Dictionary) -> bool:
	if int(a["count"]) == int(b["count"]):
		return String(a["label"]).nocasecmp_to(String(b["label"])) < 0
	return int(a["count"]) > int(b["count"])


func _count_unique_directories(files: Array) -> int:
	var directories := {"res://": true}
	for file in files:
		var path := String(file["path"]).trim_prefix("res://")
		var parts := path.split("/")
		if parts.size() <= 1:
			continue
		var current := "res://"
		for index in range(parts.size() - 1):
			current = current.path_join(parts[index])
			directories[current] = true
	return directories.size()


func _normalize_resource_ref(value: String) -> String:
	var text := value.trim_prefix("*")
	if text.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(text)
		var resolved := ResourceUID.get_id_path(uid)
		if not resolved.is_empty():
			return resolved
	return text


func _collect_autoloads(config: ConfigFile) -> Array:
	var rows = []
	if not config.has_section("autoload"):
		return rows

	var keys := config.get_section_keys("autoload")
	keys.sort()
	for key in keys:
		var raw := str(config.get_value("autoload", key))
		var path := _normalize_resource_ref(raw)
		rows.append({
			"name": key,
			"raw": raw,
			"path": path,
			"category": _classify_path(path),
		})
	return rows


func _collect_input_actions(config: ConfigFile) -> Array:
	var rows = []
	if not config.has_section("input"):
		return rows

	var keys := config.get_section_keys("input")
	keys.sort()
	for key in keys:
		var value = config.get_value("input", key, {})
		var bindings = []
		for event in value.get("events", []):
			if event == null:
				continue
			if event is InputEvent:
				bindings.append(event.as_text())
			else:
				bindings.append(str(event))

		rows.append({"action": key, "bindings": bindings, "count": bindings.size()})
	return rows


func _collect_script_inventory(files: Array, reference_graph: Dictionary) -> Array:
	var rows = []
	var outbound = reference_graph["outbound"]
	var inbound = reference_graph["inbound"]

	for file in files:
		if String(file["extension"]) != "gd":
			continue

		var path := String(file["path"])
		var content := FileAccess.get_file_as_string(path)
		var extends_name := ""
		var script_class_id := ""
		var extends_match := _extends_regex.search(content)
		if extends_match:
			extends_name = extends_match.get_string(1).strip_edges()
		var class_match := _class_regex.search(content)
		if class_match:
			script_class_id = class_match.get_string(1).strip_edges()

		rows.append({
			"path": path,
			"class_name": script_class_id,
			"extends": extends_name,
			"lines": content.split("\n").size(),
			"outbound_count": outbound.get(path, []).size(),
			"inbound_count": inbound.get(path, []).size(),
			"category": file["category"],
		})

	rows.sort_custom(_sort_script_rows)
	return rows


func _sort_script_rows(a: Dictionary, b: Dictionary) -> bool:
	return String(a["path"]).nocasecmp_to(String(b["path"])) < 0


func _build_hotspots(reference_graph: Dictionary) -> Dictionary:
	var outbound_rows = []
	for path in reference_graph["outbound"].keys():
		outbound_rows.append({
			"path": path,
			"count": reference_graph["outbound"][path].size(),
			"category": _classify_path(path),
		})

	var inbound_rows = []
	for path in reference_graph["inbound"].keys():
		inbound_rows.append({
			"path": path,
			"count": reference_graph["inbound"][path].size(),
			"category": _classify_path(path),
		})

	outbound_rows.sort_custom(_sort_hotspot_rows)
	inbound_rows.sort_custom(_sort_hotspot_rows)

	return {
		"outbound": outbound_rows.slice(0, min(15, outbound_rows.size())),
		"inbound": inbound_rows.slice(0, min(15, inbound_rows.size())),
	}


func _sort_hotspot_rows(a: Dictionary, b: Dictionary) -> bool:
	if int(a["count"]) == int(b["count"]):
		return String(a["path"]).nocasecmp_to(String(b["path"])) < 0
	return int(a["count"]) > int(b["count"])


func _summarize_scene(path: String) -> Dictionary:
	var content := FileAccess.get_file_as_string(path)
	if content.is_empty():
		return {"path": path, "root_name": "", "root_type": "", "direct_children": []}

	var ext_map := _extract_ext_resource_map(content)
	var nodes := _extract_scene_nodes(content, ext_map)
	var root_name := ""
	var root_type := ""
	var direct_children = []

	if nodes.size() > 0:
		root_name = nodes[0]["name"]
		root_type = nodes[0]["type"]
		for index in range(1, nodes.size()):
			var node = nodes[index]
			if String(node["parent"]) == "." or String(node["parent"]).is_empty():
				direct_children.append(node)

	return {
		"path": path,
		"root_name": root_name,
		"root_type": root_type,
		"direct_children": direct_children,
	}


func _extract_ext_resource_map(content: String) -> Dictionary:
	var map := {}
	for line in content.split("\n"):
		if not line.begins_with("[ext_resource"):
			continue
		var identifier := _extract_named_value(line, "id")
		var path := _extract_named_value(line, "path")
		if not identifier.is_empty():
			map[identifier] = path
	return map


func _extract_scene_nodes(content: String, ext_map: Dictionary) -> Array:
	var rows = []
	for match in _node_regex.search_all(content):
		var attributes := match.get_string(1)
		var data := {}
		for attribute in _attr_regex.search_all(attributes):
			data[attribute.get_string(1)] = attribute.get_string(2)

		var instance_ref := ""
		if attributes.contains("instance=ExtResource("):
			instance_ref = _extract_ext_resource_id(attributes)

		rows.append({
			"name": String(data.get("name", "")),
			"type": String(data.get("type", "")),
			"parent": String(data.get("parent", "")),
			"instance_path": String(ext_map.get(instance_ref, "")),
		})
	return rows


func _extract_named_value(text: String, attribute: String) -> String:
	var token := attribute + "=\""
	var start := text.find(token)
	if start == -1:
		return ""
	start += token.length()
	var ending := text.find("\"", start)
	if ending == -1:
		return ""
	return text.substr(start, ending - start)


func _extract_ext_resource_id(text: String) -> String:
	var token := "ExtResource(\""
	var start := text.find(token)
	if start == -1:
		return ""
	start += token.length()
	var ending := text.find("\"", start)
	if ending == -1:
		return ""
	return text.substr(start, ending - start)


func _collect_reference_slices(reference_graph: Dictionary) -> Array:
	var rows = []
	for definition in SLICE_DEFINITIONS:
		rows.append(_build_reference_slice(
			String(definition["label"]),
			String(definition["path"]),
			int(definition["depth"]),
			reference_graph
		))
	return rows


func _build_reference_slice(label: String, root_path: String, depth: int, reference_graph: Dictionary) -> Dictionary:
	var queue = [{"path": root_path, "depth": 0}]
	var visited := {root_path: 0}
	var edges = []

	while queue.size() > 0 and visited.size() < 40:
		var current = queue.pop_front()
		var current_path := String(current["path"])
		var current_depth := int(current["depth"])
		if current_depth >= depth:
			continue

		for target in reference_graph["outbound"].get(current_path, []):
			if not String(target).begins_with("res://"):
				continue
			edges.append({"from": current_path, "to": target})
			if not visited.has(target):
				visited[target] = current_depth + 1
				queue.append({"path": target, "depth": current_depth + 1})
	var nodes = []
	for path in visited.keys():
		nodes.append({"path": path, "depth": visited[path], "category": _classify_path(path)})
	nodes.sort_custom(_sort_slice_nodes)
	edges.sort_custom(_sort_slice_edges)

	return {"label": label, "root_path": root_path, "depth": depth, "nodes": nodes, "edges": edges}


func _sort_slice_nodes(a: Dictionary, b: Dictionary) -> bool:
	if int(a["depth"]) == int(b["depth"]):
		return String(a["path"]).nocasecmp_to(String(b["path"])) < 0
	return int(a["depth"]) < int(b["depth"])


func _sort_slice_edges(a: Dictionary, b: Dictionary) -> bool:
	var left := "%s->%s" % [a["from"], a["to"]]
	var right := "%s->%s" % [b["from"], b["to"]]
	return left.nocasecmp_to(right) < 0


func _build_boundaries(files: Array) -> Array:
	var counts := {
		"framework": 0,
		"tooling": 0,
		"project-script": 0,
		"content-scene": 0,
		"asset": 0,
		"docs": 0,
		"project-root": 0,
	}
	for file in files:
		var category := String(file["category"])
		counts[category] = int(counts.get(category, 0)) + 1

	return [
		{
			"title": "Protected framework",
			"category": "framework",
			"count": counts["framework"],
			"paths": ["res://addons/cogito"],
			"note": "Cogito template layer. Treat as protected unless a project-local extension path is impossible.",
		},
		{
			"title": "Tooling addons",
			"category": "tooling",
			"count": counts["tooling"],
			"paths": ["res://addons/godot_mcp", "res://addons/input_helper", "res://addons/quick_audio"],
			"note": "Editor/runtime tooling, input helpers, and shared addon infrastructure.",
		},
		{
			"title": "Project logic",
			"category": "project-script",
			"count": counts["project-script"],
			"paths": ["res://Scripts/Weapons", "res://Scripts/Player", "res://Scene/Multiplayer/Test"],
			"note": "Project-local adapters, weapon logic, and gameplay-specific code that should carry custom behavior.",
		},
		{
			"title": "Scenes and content",
			"category": "content-scene",
			"count": counts["content-scene"],
			"paths": ["res://Scene", "res://Scene/Weapom", "res://Scene/Attachment"],
			"note": "World composition, pickups, attachments, VFX, and scene-owned content.",
		},
		{
			"title": "Assets and docs",
			"category": "asset",
			"count": counts["asset"] + counts["docs"],
			"paths": ["res://Assets", "res://docs"],
			"note": "Imported assets, textures, audio, and Sphinx documentation sources.",
		},
	]


func _build_html(data: Dictionary) -> String:
	var template_path := "res://docs/codebase-map.template.html"
	var template := FileAccess.get_file_as_string(template_path)
	if template.is_empty():
		template = "<!doctype html><html><body><pre>Template missing.</pre></body></html>"
	var json := JSON.stringify(data)
	return template.replace("__DATA__", json)
