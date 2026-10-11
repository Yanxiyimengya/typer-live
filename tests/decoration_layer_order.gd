extends SceneTree

# Run with Godot --headless --path . --script res://tests/decoration_layer_order.gd

var failures : int = 0

func check(condition : bool, message : String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var editor = load("res://scenes/editor/settings/decoration_editor.tscn").instantiate()
	editor.theme = load("res://assets/styles/editor/apple_editor.tres")
	root.size = Vector2i(1200, 900)
	root.add_child(editor)
	editor.set_deferred("size", Vector2(1200, 900))
	var fixtures : Array = []
	for label in ["A", "B", "C"]:
		fixtures.append({"name": label, "path": "res://assets/ui/dialog/bow_star.png", "anchor": Vector2.ZERO, "position": Vector2(100, 100), "size": Vector2(80, 80), "scale": Vector2.ONE, "rotation": 0.0, "visible": true})
	editor.set_data(fixtures)
	await process_frame
	await process_frame
	var tree : Tree = editor.get_node("%DecorationNodes")
	var layer : SpinBox = editor.get_node("%DecorationLayer")
	# Keep all fixture rows visible regardless of the saved sidebar split position.
	tree.custom_minimum_size.y = 160
	await process_frame
	await process_frame
	check(tree.get_root().get_child(0).get_text(0) == "C", "Frontmost node must be first in tree")
	editor._select(0)
	layer.value = 3
	check(editor.get_data().map(func(item): return item.name) == ["B", "C", "A"], "Numeric layer must reorder drawing array")
	check(editor.selected_index == 2 && layer.value == 3, "Selected object must follow numeric move")
	editor._reorder(0, 2)
	check(editor.selected_index == 1, "Selection must follow when another object moves forward")
	editor._reorder(2, 0)
	check(editor.selected_index == 2, "Selection must follow when another object moves backward")
	editor.set_data(fixtures)
	editor._select(0)
	await process_frame
	var target : TreeItem = tree.get_root().get_child(0)
	var rect : Rect2 = tree.get_item_area_rect(target)
	var above : Vector2 = Vector2(rect.position.x + 20, rect.position.y + 2)
	check(tree._can_drop_data(above, {"tree": tree, "index": 0}), "Must accept drop above top row")
	tree._drop_data(above, {"tree": tree, "index": 0})
	check(editor.get_data().map(func(item): return item.name) == ["B", "C", "A"], "Dragging above top row must bring object to front")
	await process_frame
	target = tree.get_root().get_child(2)
	tree.scroll_to_item(target, true)
	await process_frame
	rect = tree.get_item_area_rect(target)
	var below : Vector2 = Vector2(rect.position.x + 20, rect.end.y - 2)
	check(tree._can_drop_data(below, {"tree": tree, "index": 2}), "Must accept drop below bottom row")
	tree._drop_data(below, {"tree": tree, "index": 2})
	check(editor.get_data().map(func(item): return item.name) == ["A", "B", "C"], "Dragging below bottom row must send object to back")
	check(not tree._can_drop_data(above, {"tree": null, "index": 0}), "Must reject foreign drag source")
	check(not tree._can_drop_data(above, "invalid"), "Must reject unrelated payload")
	editor._select(0)
	layer.value = 3
	var config := ConfigFile.new()
	config.set_value("bubble", "decorations", editor.get_data())
	var restored := ConfigFile.new()
	check(restored.parse(config.encode_to_text()) == OK, "Layer data must serialize")
	editor.set_data(restored.get_value("bubble", "decorations"))
	check(editor.get_data().map(func(item): return item.name) == ["B", "C", "A"], "Reload must retain layers")
	await process_frame
	var canvas = editor.canvas
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = canvas._origin + Vector2(140, 140) * canvas._display_scale
	canvas._gui_input(click)
	check(editor.selected_index == 2, "Canvas picking must choose reordered frontmost overlapping object")
	editor._remove_selected()
	check(editor.items.size() == 2 && layer.max_value == 2, "Deleting must refresh valid layer range")
	var delete_key := InputEventKey.new()
	delete_key.keycode = KEY_DELETE
	delete_key.pressed = true
	editor.set_data(fixtures)
	editor._select(1)
	tree.grab_focus()
	root.push_input(delete_key)
	check(editor.get_data().map(func(item): return item.name) == ["A", "C"], "Delete with scene tree focused must remove selected object")
	check(canvas.items.size() == 2 && layer.max_value == 2, "Delete shortcut must synchronize preview and layer inspector")
	canvas.grab_focus()
	root.push_input(delete_key)
	check(editor.items.size() == 1, "Delete with canvas focused must remove selected object")
	delete_key.echo = true
	root.push_input(delete_key)
	check(editor.items.size() == 1, "Holding Delete must not remove additional objects")
	delete_key.echo = false
	var name_edit : LineEdit = editor.get_node("%DecorationNameEdit")
	name_edit.grab_focus()
	root.push_input(delete_key)
	check(editor.items.size() == 1, "Delete in name input must not remove object")
	layer.get_line_edit().grab_focus()
	root.push_input(delete_key)
	check(editor.items.size() == 1, "Delete in numeric input must not remove object")
	var other_button := Button.new()
	root.add_child(other_button)
	other_button.grab_focus()
	root.push_input(delete_key)
	check(editor.items.size() == 1, "Delete outside decoration editor must not remove object")
	other_button.queue_free()
	editor.hide()
	root.push_input(delete_key)
	check(editor.items.size() == 1, "Hidden editor must ignore Delete")
	editor.show()
	editor.set_data([])
	canvas.grab_focus()
	root.push_input(delete_key)
	check(tree.get_root().get_child_count() == 0 && editor.selected_index == -1, "Empty scene must clear hierarchy and selection")
	print("LAYER_ORDER_CHECK: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	editor.queue_free()
	await process_frame
	quit(failures)
