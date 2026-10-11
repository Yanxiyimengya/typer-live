extends SceneTree

# Run in an isolated TyperLiveImageStoreTests project.
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
	var settings : Node = root.get_node("GlobalSettings")
	var legacy := ConfigFile.new()
	legacy.save(settings.SAVE_PATH)
	settings.load_settings()
	check(settings.emoji_font_path.is_empty(), "Legacy settings must default Emoji path to empty")
	check(settings.default_emoji_font == settings.BUNDLED_EMOJI_FONT, "Empty path must use bundled Emoji font")
	var editor = load("res://scenes/editor/editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(8):
		await process_frame
	var panel : Control = editor.settings_scene
	check(panel != null && editor.text_edit != null, "Editor settings must initialize")
	var field : LineEdit = panel.get_node("%EmojiFontPathEdit")
	check(field.text.is_empty(), "General settings Emoji field must initially be empty")
	var picker : Control = editor.get_node("%EmojiButton/EmojiPanelContainer")
	var emoji_button : Button = picker.get_node("%EmojiGrid").get_child(0)
	check(emoji_button.get_theme_font("font") == settings.default_emoji_font, "Emoji palette must use bundled font by default")
	var bubble = load("res://scenes/live/dialog/dialog_bubble.tscn").instantiate()
	root.add_child(bubble)
	check(editor.text_edit.get_theme_font("font").fallbacks.has(settings.default_emoji_font), "Editor input must include Emoji fallback")
	for label : RichTextLabel in [bubble.dialog_text_label, bubble.sender_text_label]:
		for style in ["normal", "bold", "italics", "bold_italics"]:
			check(label.get_theme_font(style + "_font").fallbacks.has(settings.default_emoji_font), "Bubble font style must include Emoji fallback")
	check(DirAccess.copy_absolute("res://assets/fonts/emoji.ttf", "user://custom_emoji.ttf") == OK, "Must create custom font fixture")
	field.text = "  user://custom_emoji.ttf  "
	panel._confirm()
	check(settings.emoji_font_path == "user://custom_emoji.ttf", "Confirm must save trimmed custom Emoji path")
	check(settings.default_emoji_font != settings.BUNDLED_EMOJI_FONT, "Custom Emoji font must replace bundled choice")
	check(emoji_button.get_theme_font("font") == settings.default_emoji_font, "Emoji palette must update after confirm")
	check(editor.text_edit.get_theme_font("font").fallbacks.has(settings.default_emoji_font), "Editor input must update Emoji fallback")
	check(bubble.dialog_text_label.get_theme_font("normal_font").fallbacks.has(settings.default_emoji_font), "Live bubble must update Emoji fallback")
	var saved := ConfigFile.new()
	saved.load(settings.SAVE_PATH)
	check(saved.get_value("general", "emoji_font_path") == "user://custom_emoji.ttf", "Custom path must persist in general settings")
	settings.load_settings()
	panel.refresh()
	check(field.text == "user://custom_emoji.ttf", "Reload must restore custom path in UI")
	panel.get_node("%EmojiFontResetButton").pressed.emit()
	check(field.text.is_empty(), "Reset must clear field")
	panel._confirm()
	check(settings.emoji_font_path.is_empty() && settings.default_emoji_font == settings.BUNDLED_EMOJI_FONT, "Confirm reset must restore bundled font")
	saved.load(settings.SAVE_PATH)
	check(saved.get_value("general", "emoji_font_path") == "", "Reset must persist an empty configured path")
	var combined : Font = editor.text_edit.get_theme_font("font")
	var fallback_count : int = combined.fallbacks.size()
	settings.settings_changed.emit()
	check(editor.text_edit.get_theme_font("font").fallbacks.size() == fallback_count, "Repeated refresh must not accumulate font fallbacks")
	check(settings.apply_settings("", 24, Color.WHITE, "", "", {}, {}, -1, null, -1, [], "user://missing_emoji.ttf") != OK, "Invalid explicit font must not save")
	check(settings.emoji_font_path.is_empty(), "Failed save must preserve prior Emoji setting")
	check(settings.load_emoji_font("user://missing_emoji.ttf") == settings.BUNDLED_EMOJI_FONT, "Missing saved font must fall back to bundled font")
	DirAccess.remove_absolute("user://custom_emoji.ttf")
	bubble.queue_free()
	editor.queue_free()
	await process_frame
	print("EMOJI_FONT_SETTINGS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
