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
	var emoji_font : SystemFont = SystemFont.new();
	emoji_font.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"]);
	for emoji : String in EMOJIS:
		var button : Button = Button.new();
		button.custom_minimum_size = Vector2(44, 44);
		button.text = emoji;
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND;
		button.add_theme_font_override("font", emoji_font);
		button.add_theme_font_size_override("font_size", 28);
		button.pressed.connect(func(): hide(); emoji_selected.emit(emoji));
		%EmojiGrid.add_child(button);

func show_panel() -> void:
	if visible:
		hide();
		return;
	size = Vector2(326, 300);
	var button : Control = get_parent();
	var viewport_size : Vector2 = get_viewport_rect().size;
	global_position = Vector2(clampf(button.get_global_rect().position.x, 0, maxf(0, viewport_size.x - size.x)), clampf(button.get_global_rect().end.y + 6, 0, maxf(0, viewport_size.y - size.y)));
	show();

func _input(event : InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return;
	var point : Vector2 = get_canvas_transform().affine_inverse() * event.position;
	if not get_global_rect().has_point(point) and not get_parent().get_global_rect().has_point(point):
		hide();
