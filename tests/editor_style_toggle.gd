extends SceneTree

var failures : int = 0
var editor : Control
var text_edit : TextEdit

func check(condition : bool, message : String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func select_text(value : String, start : int, end : int) -> void:
	text_edit.text = value
	text_edit.clear_undo_history()
	var from : Vector2i = editor._get_text_position(start)
	var to : Vector2i = editor._get_text_position(end)
	text_edit.select(from.y, from.x, to.y, to.x)

func run() -> void:
	editor = load("res://scripts/scenes/editor/editor.gd").new()
	text_edit = TextEdit.new()
	root.add_child(text_edit)
	editor.text_edit = text_edit
	for style in [["b", ""], ["i", ""], ["u", ""], ["s", ""], ["color", "#ff0000"], ["bgcolor", "#808080"], ["font_size", "24"]]:
		var opening : String = "[%s]" % style[0] if style[1].is_empty() else "[%s=%s]" % style
		select_text("前缀文字后缀", 2, 4)
		editor.insert_bbcode_style(style[0], style[1])
		var styled : String = "前缀" + opening + "文字[/%s]后缀" % style[0]
		check(text_edit.text == styled, "First click must apply " + style[0])
		check(text_edit.get_selected_text() == "文字", "Apply must retain text selection")
		editor.insert_bbcode_style(style[0], style[1])
		check(text_edit.text == "前缀文字后缀", "Second click must remove " + style[0])
		check(text_edit.get_selected_text() == "文字", "Remove must retain text selection")
		text_edit.undo()
		check(text_edit.text == styled, "Removal must undo in one step")
		text_edit.redo()
		check(text_edit.text == "前缀文字后缀", "Removal must redo in one step")
	select_text("[b]文字[/b]", 0, 9)
	editor.insert_bbcode_style("b")
	check(text_edit.text == "文字", "Selecting tags and text must also toggle off")
	select_text("[b][i]文字[/i][/b]", 6, 8)
	editor.insert_bbcode_style("b")
	check(text_edit.text == "[i]文字[/i]", "Removing bold must preserve italic")
	select_text("[b][b]文字[/b][/b]", 6, 8)
	editor.insert_bbcode_style("b")
	check(text_edit.text == "文字", "Removing bold must clear duplicate wrappers")
	select_text("[i][b]文字[/b][/i]", 6, 8)
	editor.insert_bbcode_style("b")
	check(text_edit.text == "[i]文字[/i]", "Removing inner bold must preserve outer italic")
	select_text("[b]甲\n乙[/b]", 3, 6)
	editor.insert_bbcode_style("b")
	check(text_edit.text == "甲\n乙" && text_edit.get_selected_text() == "甲\n乙", "Multiline toggle must preserve selection")
	select_text("[b]甲[/b]乙", 0, 9)
	editor.insert_bbcode_style("b")
	check(text_edit.text == "[b]甲乙[/b]", "Mixed formatting must apply uniformly")
	editor.insert_bbcode_style("b")
	check(text_edit.text == "甲乙", "Normalized formatting must toggle off")
	select_text("[color=#ff0000]文字[/color]", 15, 17)
	editor.insert_bbcode_style("color", "#0000ff")
	check(text_edit.text == "[color=#0000ff]文字[/color]", "Changing color must update instead of removing style")
	editor.insert_bbcode_style("color", "#0000ff")
	check(text_edit.text == "文字", "Repeating same color must toggle off")
	select_text("[b]甲[/b] 文字", 9, 11)
	editor.insert_bbcode_style("b")
	check(text_edit.text == "[b]甲[/b] [b]文字[/b]", "Unrelated styled text must remain intact")
	text_edit.deselect()
	var unchanged : String = text_edit.text
	editor.insert_bbcode_style("b")
	check(text_edit.text == unchanged, "No selection must remain unchanged")
	editor.free()
	text_edit.queue_free()
	await process_frame
	print("EDITOR_STYLE_TOGGLE: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
