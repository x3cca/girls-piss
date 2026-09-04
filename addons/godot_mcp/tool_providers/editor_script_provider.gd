@tool
## Editor script execution provider — runs GDScript code in the editor context.
class_name EditorScriptProvider
extends MCPNodeToolProviderBase

const TIMEOUT_SEC := 1.5

var _pending: Dictionary = { }


func get_definitions() -> Array:
	return [
		ToolDefinition.new(
			"execute_editor_script",
			"Execute GDScript code in the editor context.",
			{
				"type": "object",
				"properties": {
					"code": { "type": "string", "description": "GDScript code to execute" },
				},
				"required": ["code"],
			},
			"execute_editor_script",
		),
	]


func execute_tool(_tool_name: String, params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	if code.is_empty():
		return _error("Code cannot be empty")

	# Build temporary script
	var sn := Node.new()
	sn.name = "ESExecutor"
	add_child(sn)
	var script := GDScript.new()
	var mc := _replace_prints(code)

	var sc := """@tool
extends Node
signal done
var result = null
var output_array = []
var error_msg = ""

func cp(vals):
	var s = ""
	if vals is Array:
		for i in range(vals.size()):
			if i > 0: s += " "
			s += str(vals[i])
	else: s = str(vals)
	output_array.append(s)
	print(s)

func run():
	_exec()
	done.emit()

func _exec():
%s
	return OK
""" % _indent(mc, "\t")

	script.source_code = sc
	var err := script.reload()
	if err != OK:
		remove_child(sn)
		sn.queue_free()
		return _error("Script parsing error: %d" % err)

	sn.set_script(script)
	var eid := sn.get_instance_id()
	_pending[eid] = { "node": sn, "timer": _mk_timer(eid) }
	sn.connect("done", _on_done.bind(eid))
	sn.run()
	return await _wait(eid)


func _indent(code: String, prefix: String) -> String:
	var lines := code.split("\n")
	var r := ""
	for line in lines:
		r += prefix + line + "\n"
	return r


func _replace_prints(code: String) -> String:
	var r := ""
	var i := 0
	while i < code.length():
		var m := code.find("print", i)
		if m == -1:
			r += code.substr(i)
			break
		r += code.substr(i, m - i)
		var pc := code.substr(m - 1, 1) if m > 0 else ""
		var nc := code.substr(m + 5, 1) if m + 5 < code.length() else ""
		if pc.is_valid_identifier() or nc.is_valid_identifier():
			r += "print"
			i = m + 5
			continue
		var pi := _skip_ws(code, m + 5)
		if pi >= code.length() or code[pi] != "(":
			r += "print"
			i = m + 5
			continue
		var ci := _match_paren(code, pi)
		if ci == -1:
			r += code.substr(m)
			break
		r += "cp([" + code.substr(pi + 1, ci - pi - 1) + "])"
		i = ci + 1
	return r


func _skip_ws(text: String, start: int) -> int:
	var i := start
	while i < text.length():
		var c := text[i]
		if c != " " and c != "\t" and c != "\n" and c != "\r":
			break
		i += 1
	return i


func _match_paren(text: String, open: int) -> int:
	var d := 1
	var i := open + 1
	var ins := false
	var sd := ""
	var esc := false
	while i < text.length():
		var c := text[i]
		if ins:
			if esc:
				esc = false
			elif c == "\\":
				esc = true
			elif c == sd:
				ins = false
		else:
			if c == "\"" or c == "'":
				ins = true
				sd = c
			elif c == "(":
				d += 1
			elif c == ")":
				d -= 1
			if d == 0:
				return i
		i += 1
	return -1


func _on_done(eid: int) -> void:
	if not _pending.has(eid):
		return
	var p: Dictionary = _pending[eid]
	var sn: Node = p["node"]
	var output: Array = sn.output_array
	var em: String = sn.error_msg
	var tmr: Timer = p["timer"]
	if tmr and is_instance_valid(tmr):
		tmr.stop()
		remove_child(tmr)
		tmr.queue_free()
	remove_child(sn)
	sn.queue_free()
	p["_result"] = _ok(
		{
			"success": em.is_empty(),
			"output": output,
			"error": em if not em.is_empty() else "",
		},
	)


func _wait(eid: int) -> Dictionary:
	var dl := Time.get_ticks_msec() + (TIMEOUT_SEC + 1) * 1000
	while Time.get_ticks_msec() < dl:
		if not _pending.has(eid):
			return _error("Executor state lost")
		var p: Dictionary = _pending[eid]
		if p.has("_result"):
			return p["_result"]
		await get_tree().process_frame
	return _error("Script execution timed out")


func _mk_timer(eid: int) -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = TIMEOUT_SEC
	t.timeout.connect(_on_timeout.bind(eid))
	add_child(t)
	t.start()
	return t


func _on_timeout(eid: int) -> void:
	if not _pending.has(eid):
		return
	var p: Dictionary = _pending[eid]
	var sn: Node = p["node"]
	var tmr: Timer = p["timer"]
	if tmr and is_instance_valid(tmr):
		tmr.stop()
		remove_child(tmr)
		tmr.queue_free()
	if sn and is_instance_valid(sn):
		if sn.is_inside_tree():
			remove_child(sn)
		sn.queue_free()
	_pending.erase(eid)
