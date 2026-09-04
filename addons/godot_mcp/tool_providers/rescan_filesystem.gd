@tool
## Tool provider for "rescan_filesystem" — Rescan filesystem and reimport changed assets.
class_name ToolProviderRescanFilesystem
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"rescan_filesystem",
		"Rescan filesystem and reimport changed assets. Use when files are modified externally.",
		{
			"type": "object",
			"properties": {
				"paths": {
					"type": "array",
					"items": {
						"type": "string",
					},
					"description": "Optional file paths to reimport (e.g. 'res://icon.svg')",
				},
				"sources": {
					"type": "boolean",
					"description": "Also re-scan script sources for import changes (default: true)",
				},
			},
		},
		"rescan_filesystem",
	)


func execute(params: Dictionary) -> Dictionary:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var filesystem = editor_interface.get_resource_filesystem()

	var target_paths: Array = params.get("paths", [])
	var scan_src: bool = params.get("sources", true)

	var start_ms := Time.get_ticks_msec()
	var reimported_count := 0
	var actions_performed: Array[String] = []

	# Step 1: Reimport specific files if paths provided
	if not target_paths.is_empty():
		var packed := PackedStringArray()
		var skipped := 0
		for p in target_paths:
			var path_str: String = str(p).strip_edges()
			if path_str.is_empty():
				skipped += 1
				continue
			if not path_str.begins_with("res://"):
				path_str = "res://" + path_str
			# Accept both files and directories (reimport_files handles import groups)
			if FileAccess.file_exists(path_str) or DirAccess.dir_exists_absolute(path_str):
				packed.append(path_str)
			else:
				skipped += 1

		if not packed.is_empty():
			# reimport_files() blocks until done — no polling needed
			filesystem.reimport_files(packed)
			reimported_count = packed.size()
			actions_performed.append("reimported %d files" % reimported_count)
		if skipped > 0:
			actions_performed.append("skipped %d nonexistent paths" % skipped)
		else:
			actions_performed.append("all %d paths were invalid or nonexistent" % skipped)
	else:
		# Step 2: Full filesystem scan (detects new/changed files, triggers reimports)
		filesystem.scan()
		actions_performed.append("initiated full filesystem scan")

	# Step 3: Scan script sources for import changes (e.g. .gd files that affect .import)
	if scan_src:
		filesystem.scan_sources()
		actions_performed.append("scanned script sources")

	# Step 4: Wait for background scan to complete (scan() is async)
	if filesystem.has_method("is_scanning") and filesystem.is_scanning():
		var main_loop = Engine.get_main_loop()
		var timeout_ms: int = 30000
		while filesystem.is_scanning() and (Time.get_ticks_msec() - start_ms) < timeout_ms:
			if main_loop:
				await main_loop.process_frame

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	var still_scanning: bool = filesystem.has_method("is_scanning") and filesystem.is_scanning()

	return _ok(
		{
			"status": "timeout" if still_scanning else "complete",
			"reimported_count": reimported_count,
			"scan_complete": not still_scanning,
			"elapsed_ms": elapsed_ms,
			"actions": actions_performed,
			"message": (
					"Filesystem rescan %s in %d ms — %s"
					% [
						"completed" if not still_scanning else "timed out",
						elapsed_ms,
						", ".join(actions_performed),
					]
			),
		},
	)
