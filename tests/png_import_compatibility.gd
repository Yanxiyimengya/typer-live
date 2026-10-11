extends SceneTree

# Run in an isolated TyperLiveImageStoreTests project; optional -- <image path> checks a real image.
var failures : int = 0

func check(condition : bool, message : String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("TyperLiveImageStoreTests"):
		push_error("This test requires an isolated project/user data directory.")
		quit(1)
		return
	await process_frame
	var resources : Node = root.get_node("GlobalResourceLoader")
	var original := Image.create(20, 30, false, Image.FORMAT_RGBA8)
	original.fill(Color(0.2, 0.5, 0.7, 1))
	var bytes : PackedByteArray = original.save_png_to_buffer()
	var with_metadata : PackedByteArray = bytes.duplicate()
	with_metadata.append_array("export metadata after IEND".to_utf8_buffer())
	check(resources._png_payload_size(with_metadata) == bytes.size(), "PNG scanner must locate IEND before trailing metadata")
	check(resources._png_payload_size(bytes.slice(0, bytes.size() - 12)) == 0, "Missing IEND must be rejected")
	var truncated : PackedByteArray = bytes.duplicate()
	truncated[8] = 127
	check(resources._png_payload_size(truncated) == 0, "Chunk length beyond file must be rejected")
	var file := FileAccess.open("user://png_with_metadata.png", FileAccess.WRITE)
	file.store_buffer(with_metadata)
	file.close()
	check(resources.load_image("user://png_with_metadata.png") != null, "Sync loader must accept complete PNG with trailing metadata")
	resources.clear_cache()
	check(await resources.load_image_async("user://png_with_metadata.png") != null, "Async loader must accept complete PNG with trailing metadata")
	var editor = load("res://scenes/editor/settings/decoration_editor.tscn").instantiate()
	root.add_child(editor)
	editor.add_image("user://png_with_metadata.png")
	check(editor.items.size() == 1, "Image with trailing metadata must import as object")
	var stored : String = editor.items[0].path
	check(FileAccess.get_sha256(stored) == FileAccess.get_sha256("user://png_with_metadata.png"), "Managed copy must preserve all original bytes and hash")
	var dialog : AcceptDialog = editor.get_node("%DecorationImportError")
	var apple : Theme = load("res://assets/styles/editor/apple_editor.tres")
	check(dialog.theme == apple, "Import error dialog must use Apple theme even when parent window has no theme")
	check(dialog.get_label().get_theme_color("font_color") == apple.get_color("font_color", "Label"), "Error message must inherit Apple text color")
	check(dialog.get_ok_button().get_theme_stylebox("normal") == apple.get_stylebox("normal", "Button"), "Dialog button must inherit Apple button style")
	check(dialog.get_theme_stylebox("panel") == apple.get_stylebox("panel", "AcceptDialog"), "Dialog background must use Apple panel style")
	for path in OS.get_cmdline_user_args():
		var before : String = FileAccess.get_sha256(path)
		var decoded : Image = resources._read_image_file(path)
		check(decoded != null, "Real image must decode successfully")
		if decoded != null:
			print("REAL_IMAGE_DECODE: ", decoded.get_width(), "x", decoded.get_height())
		var count : int = editor.items.size()
		editor.add_image(path)
		check(editor.items.size() == count + 1, "Real image must import successfully")
		check(FileAccess.get_sha256(path) == before, "Import must preserve the real source image")
	editor.set_data([])
	editor.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://png_with_metadata.png")
	print("PNG_IMPORT_COMPATIBILITY: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
