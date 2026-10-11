extends PanelContainer;

signal emoji_selected(emoji : String);

const EMOJIS : PackedStringArray = [
	"😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "🙂", "😉", "😍",
	"🥰", "😘", "😎", "🤔", "😐", "🙄", "😴", "😢", "😭", "😤", "😡", "🤯",
	"🥺", "🤗", "🤫", "🤭", "👍", "👎", "👏", "🙌", "🙏", "💪", "👋", "👌",
	"❤️", "💔", "✨", "🔥", "🎉", "🎂", "🎁", "🌸", "🌈", "☀️", "🌙", "⭐",
	"🐱", "🐶", "🐼", "🍎", "🍰", "☕", "🎵", "💡", "✅", "❌", "💯", "🚀"
];

func _ready() -> void:
	for emoji : String in EMOJIS:
		var button : Button = Button.new();
		button.custom_minimum_size = Vector2(44, 44);
		button.text = emoji;
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND;
		button.add_theme_font_size_override("font_size", 28);
		button.pressed.connect(func(): hide(); emoji_selected.emit(emoji));
		%EmojiGrid.add_child(button);
	GlobalSettings.settings_changed.connect(_apply_settings);
	_apply_settings();

func _apply_settings() -> void:
	for button : Button in %EmojiGrid.get_children():
		button.add_theme_font_override("font", GlobalSettings.default_emoji_font);

func show_panel() -> void:
	if (visible):
		hide();
		return;
	size = Vector2(326, 300);
	var button : Control = get_parent();
	var viewport_size : Vector2 = get_viewport_rect().size;
	global_position = Vector2(clampf(button.get_global_rect().position.x, 0, maxf(0, viewport_size.x - size.x)), clampf(button.get_global_rect().end.y + 6, 0, maxf(0, viewport_size.y - size.y)));
	show();

func _input(event : InputEvent) -> void:
	if (not visible || not (event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed)):
		return;
	var point : Vector2 = get_canvas_transform().affine_inverse() * event.position;
	if (not get_global_rect().has_point(point) && not get_parent().get_global_rect().has_point(point)):
		hide();
