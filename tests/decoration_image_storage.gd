extends SceneTree

# Run in an isolated project with application/config/name starting with TyperLiveImageStoreTests.
var store : GDScript
var failures : int = 0
var settings : Node
var resources : Node

func check(condition : bool, message : String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func save_items(items : Array) -> Error:
	return settings.apply_settings("", 24, Color.WHITE, "", "", {}, {}, -1, null, -1, items)

func make_editor() -> Control:
	var editor = load("res://scenes/editor/settings/decoration_editor.tscn").instantiate()
	root.add_child(editor)
	return editor

func run() -> void:
	settings = root.get_node("GlobalSettings")
	resources = root.get_node("GlobalResourceLoader")
	store = load("res://scripts/core/decoration_image_store.gd")
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("TyperLiveImageStoreTests"):
		push_error("This test requires an isolated project/user data directory.")
		quit(1)
		return
	await process_frame
	var source := "user://original.png"
	var duplicate := "user://renamed.png"
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.6, 0.9, 1))
	check(image.save_png(source) == OK, "Must create image fixture")
	check(DirAccess.copy_absolute(source, duplicate) == OK, "Must create identical renamed image")
	var editor = make_editor()
	editor.add_image(source)
	editor.add_image(duplicate)
	check(editor.items.size() == 2, "Both imports must create objects")
	var path : String = editor.items[0].path
	check(store.is_managed(path), "Object must use managed user directory")
	check(path.get_file().get_basename() == FileAccess.get_sha256(source), "Stored name must be SHA-256 of original bytes")
	check(editor.items[1].path == path && DirAccess.get_files_at(store.DIRECTORY).size() == 1, "Identical images must share one stored file")
	check(editor.items[0].name == "original" && editor.items[1].name == "renamed", "Names must retain source filenames")
	check(resources.load_image("user://missing.png") == null, "Sync loader must skip missing image")
	check(await resources.load_image_async("user://missing.png") == null, "Async loader must skip missing image")
	var empty := FileAccess.open("user://empty.png", FileAccess.WRITE)
	empty.close()
	check(resources.load_image("user://empty.png") == null, "Sync loader must skip empty image")
	check(await resources.load_image_async("user://empty.png") == null, "Async loader must skip empty image")
	DirAccess.remove_absolute("user://empty.png")
	var truncated := FileAccess.open("user://truncated.png", FileAccess.WRITE)
	truncated.store_buffer(PackedByteArray([137, 80, 78, 71]))
	truncated.close()
	check(resources.load_image("user://truncated.png") == null, "Sync loader must reject incomplete external PNG")
	check(await resources.load_image_async("user://truncated.png") == null, "Async loader must reject incomplete external PNG")
	DirAccess.remove_absolute("user://truncated.png")
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	damaged.store_buffer(PackedByteArray([137, 80, 78, 71]))
	damaged.close()
	resources.clear_cache()
	check(resources.load_image(path) == null, "Sync loader must reject truncated managed file before decoding")
	check(await resources.load_image_async(path) == null, "Async loader must reject truncated managed file before decoding")
	check(not resources.resource_cache.has(ProjectSettings.globalize_path(path)), "Invalid image must not enter texture cache")
	check(store.import_image(source) == path, "Reimport must repair damaged file at existing path")
	check(FileAccess.get_sha256(path) == path.get_file().get_basename(), "Repaired image must match content hash")
	check(await resources.load_image_async(path) != null, "Async loader must load repaired valid image")
	editor._remove_selected()
	check(FileAccess.file_exists(path), "Deleting one duplicate must retain shared image")
	check(FileAccess.file_exists(source) && FileAccess.file_exists(duplicate), "Deleting object must not touch originals")
	check(save_items(editor.get_data()) == OK, "Must persist managed image path")
	DirAccess.remove_absolute(source)
	DirAccess.remove_absolute(duplicate)
	resources.clear_cache()
	check(resources.load_image(path) != null, "Image must load after original sources are deleted")
	settings.load_settings()
	check(settings.decoration_items[0].path == path, "Reload must retain managed image path")
	editor._remove_selected()
	check(FileAccess.file_exists(path), "Pending deletion must retain image for saved settings")
	editor.set_data(settings.decoration_items)
	check(editor.items.size() == 1 && FileAccess.file_exists(path), "Discarding edit must restore saved object and image")
	editor._select(0)
	editor._remove_selected()
	check(save_items(editor.get_data()) == OK, "Must commit deletion")
	check(not FileAccess.file_exists(path), "Committed last deletion must remove managed image")
	image.save_png(source)
	editor.add_image(source)
	path = editor.items[0].path
	var other_editor = make_editor()
	other_editor.set_data(editor.get_data())
	editor._remove_selected()
	check(FileAccess.file_exists(path), "Other editor draft must retain shared image")
	other_editor.set_data([])
	check(not FileAccess.file_exists(path), "Discarding last draft must clean unused image")
	editor.add_image(source)
	path = editor.items[0].path
	editor.set_data([])
	check(not FileAccess.file_exists(path), "Reset must clean uncommitted images")
	check(FileAccess.file_exists(source), "Reset must preserve source image")
	editor.add_image(source)
	path = editor.items[0].path
	editor.queue_free()
	await process_frame
	await process_frame
	check(not FileAccess.file_exists(path), "Closing freed editor must clean abandoned imports")
	var legacy := ConfigFile.new()
	legacy.set_value("bubble", "decorations", [{"name": "legacy", "path": source, "anchor": Vector2.ZERO, "position": Vector2.ZERO, "size": Vector2(32, 32), "scale": Vector2.ONE, "rotation": 0.0, "visible": true}])
	check(legacy.save(settings.SAVE_PATH) == OK, "Must create legacy configuration")
	settings.load_settings()
	var migrated : String = settings.decoration_items[0].path
	check(store.is_managed(migrated) && FileAccess.file_exists(migrated), "Legacy images must migrate to managed directory")
	legacy.load(settings.SAVE_PATH)
	check(legacy.get_value("bubble", "decorations")[0].path == migrated, "Migration must persist new path")
	DirAccess.remove_absolute(source)
	resources.clear_cache()
	check(resources.load_image(migrated) != null, "Migrated image must survive source deletion")
	check(store.import_image("user://missing.png").is_empty(), "Missing import must fail without creating file")
	check(not store.is_managed("user://decoration_images/../original.png"), "Cleanup must reject paths outside dedicated directory")
	check(not store.is_managed("user://decoration_images/notes.png"), "Cleanup must only own hash-named images")
	other_editor.queue_free()
	await process_frame
	check(save_items([]) == OK, "Must clear isolated test settings")
	check(not FileAccess.file_exists(migrated), "Must collect migrated file after final deletion")
	print("DECORATION_IMAGE_STORAGE: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
