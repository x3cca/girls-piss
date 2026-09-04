@tool
## Tool provider for "get_script_metadata" — Get script metadata.
class_name ToolProviderGetScriptMetadata
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_script_metadata",
		"Get metadata about a script (class_name, extends, methods, signals).",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path to the script file",
				},
			},
			"required": ["path"],
		},
		"get_script_metadata",
	)


func execute(params: Dictionary) -> Dictionary:
	var path = params.get("path", "")

	# Validation
	if path.is_empty():
		return _error("Script path cannot be empty")

	if not path.begins_with("res://"):
		path = "res://" + path

	# Try to find the script if it's not found directly
	if not FileAccess.file_exists(path):
		var found_path = _find_script_file(path)
		if not found_path.is_empty():
			path = found_path
		else:
			return _error("Script file not found: " + path)

	# Load the script
	var script = load(path)
	if not script:
		return _error("Failed to load script: " + path)

	# Extract script metadata
	var metadata = {
		"path": path,
		"language": (
				"gdscript" if path.ends_with(".gd")
				else "csharp" if path.ends_with(".cs")
				else "unknown"
		),
	}

	# Attempt to get script class info
	var class_name_str = ""
	var extends_class = ""

	# Read the file to extract class_name and extends info
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()

		# Extract class_name
		var class_regex = RegEx.new()
		class_regex.compile("class_name\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
		var result = class_regex.search(content)
		if result:
			class_name_str = result.get_string(1)

		# Extract extends
		var extends_regex = RegEx.new()
		extends_regex.compile("extends\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
		result = extends_regex.search(content)
		if result:
			extends_class = result.get_string(1)

		# Add to metadata
		metadata["class_name"] = class_name_str
		metadata["extends"] = extends_class

		# Try to extract methods and signals
		var methods = []
		var signals = []

		var method_regex = RegEx.new()
		method_regex.compile("func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
		var method_matches = method_regex.search_all(content)

		for match_result in method_matches:
			methods.append(match_result.get_string(1))

		var signal_regex = RegEx.new()
		signal_regex.compile("signal\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
		var signal_matches = signal_regex.search_all(content)

		for match_result in signal_matches:
			signals.append(match_result.get_string(1))

		metadata["methods"] = methods
		metadata["signals"] = signals

	return _ok(metadata)
