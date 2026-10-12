class_name Editor;
extends Control;

signal send_text(text : String);

var text_color : Color = Color.RED;
var text_bg_color : Color = Color.GRAY;
var text_size : float = 24;

@onready var text_edit : TextEdit = %TextEdit;
@onready var send_button : BaseButton = %SendButton;
@onready var reset_button : BaseButton = %ResetButton;
@onready var text_bold_button : BaseButton = %TextBoldButton;
@onready var text_italic_button : BaseButton = %TextItalicButton;
@onready var text_underline_button : BaseButton = %TextUnderlineButton;
@onready var text_delete_button : BaseButton = %TextDeleteButton;
@onready var text_color_button : BaseButton = %TextColorButton;
@onready var text_color_rect : TextureRect = %TextColorTextureRect;
@onready var text_color_picker_view : Control = %TextColorPickerView;
@onready var text_bg_color_button : BaseButton = %TextBgColorButton;
@onready var text_bg_color_rect : TextureRect = %TextBgColorTextureRect;
@onready var text_bg_color_picker_view : Control = %TextBgColorPickerView;
@onready var text_size_button : BaseButton = %TextSizeButton;
@onready var text_size_spinbox : SpinBox = %TextSizeSpinBox;
var image_file_dialog : FileDialog = null;

var settings_window : DefaultWindow = null;
var settings_scene : Control = null;
var _applied_emoji_font : Font;

const SETTINGS : PackedScene = preload("uid://dfu5lwhq2wcda");

@onready var gallery : Control = %ImageGallery;
@onready var emoji_panel : Control = %EmojiPanelContainer;
@onready var setting_button : Button = %SettingButton;
@onready var text_color_dropdown_button : Button = %TextColorDropdownButton;
@onready var text_bg_color_dropdown_button : Button = %TextBgColorDropdownButton;
@onready var image_button : Button = %ImageButton;
@onready var emoji_button : Button = %EmojiButton;

func _ready() -> void:
	var wid : int = GlobalWindowManager.new_window();
	if (wid > 0) : 
		settings_window = GlobalWindowManager.find_window(wid);
		settings_window.title = "设置";
		settings_window.theme = theme;
		settings_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN;
		settings_window.size = Vector2i(980, 680);
		settings_window.min_size = Vector2i(860, 600);
		settings_window.transient = true;
		settings_window.exclusive = true;
		settings_window.minimize_disabled = true;
		settings_window.close_request = false;
		settings_window.close_requested.connect(settings_window.hide);
		settings_window.visible = false;
		
		settings_scene = SETTINGS.instantiate();
		settings_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL;
		settings_scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		settings_window.add_child(settings_scene);
		await settings_scene.ready;
		settings_scene.confirmed.connect(settings_window.hide);
		setting_button.pressed.connect(_show_settings);
	
	send_button.pressed.connect(_on_send_button);
	reset_button.pressed.connect(_on_reset_button)
	
	# 文字颜色选择
	text_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	text_color_rect.self_modulate = text_color;
	text_color_picker_view.color_picker.color = text_color;
	text_color_picker_view.changer_func = func(col : Color) :
		if (text_color != col) : 
			text_color = col;
			text_color_rect.self_modulate = col;
	# 背景颜色选择
	text_bg_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	text_bg_color_rect.modulate = Color.WHITE;
	text_bg_color_rect.self_modulate = text_bg_color;
	text_bg_color_picker_view.color_picker.color = text_bg_color;
	text_bg_color_picker_view.changer_func = func(col : Color) :
		if (text_bg_color != col) : 
			text_bg_color = col;
			text_bg_color_rect.self_modulate = col;
	
	text_size_spinbox.value_changed.connect(func(value : float):
		text_size = value;
		);
	text_size_spinbox.value = text_size;
	text_bold_button.pressed.connect(insert_bbcode_style.bind("b"));
	text_italic_button.pressed.connect(insert_bbcode_style.bind("i"));
	text_underline_button.pressed.connect(insert_bbcode_style.bind("u"));
	text_delete_button.pressed.connect(insert_bbcode_style.bind("s"));
	text_color_button.pressed.connect(func() : insert_bbcode_style("color", "#" + text_color.to_html()));
	text_bg_color_button.pressed.connect(func() : insert_bbcode_style("bgcolor", "#" + text_bg_color.to_html()));
	text_color_dropdown_button.pressed.connect(text_color_picker_view.show_picker);
	text_bg_color_dropdown_button.pressed.connect(text_bg_color_picker_view.show_picker);
	text_size_button.pressed.connect(func() : insert_bbcode_style("font_size", str(text_size)));
	
	image_file_dialog = FileDialog.new();
	image_file_dialog.theme = theme;
	image_file_dialog.title = "插入图片";
	image_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE;
	image_file_dialog.access = FileDialog.ACCESS_FILESYSTEM;
	image_file_dialog.use_native_dialog = true;
	image_file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.svg;图片"]);
	add_child(image_file_dialog);
	image_file_dialog.file_selected.connect(insert_image);
	image_button.pressed.connect(gallery.show_gallery);
	gallery.import_requested.connect(image_file_dialog.popup_centered.bind(Vector2i(900, 600)));
	gallery.image_selected.connect(insert_image);
	emoji_button.pressed.connect(emoji_panel.show_panel);
	emoji_panel.emoji_selected.connect(insert_emoji);
	GlobalSettings.settings_changed.connect(_apply_settings);
	_apply_settings();

func _show_settings() -> void:
	gallery.hide();
	emoji_panel.hide();
	text_color_picker_view.hide();
	text_bg_color_picker_view.hide();
	settings_scene.refresh();
	settings_window.popup_centered(Vector2i(980, 680));

func _apply_settings() -> void:
	text_color = GlobalSettings.font_color;
	text_color_rect.self_modulate = text_color;
	text_color_picker_view.color_picker.color = text_color;
	text_size_spinbox.value = GlobalSettings.font_size;
	if (_applied_emoji_font != GlobalSettings.default_emoji_font):
		_applied_emoji_font = GlobalSettings.default_emoji_font;
		text_edit.remove_theme_font_override("font");
		text_edit.add_theme_font_override("font", GlobalSettings.with_emoji_font(text_edit.get_theme_font("font")));

func _on_send_button() -> void : 
	var text : String = text_edit.text;
	send_text.emit(text);

func _on_reset_button() -> void:
	text_edit.text = "";

func insert_image(path : String) -> void:
	GlobalResourceLoader.remember_image(path);
	var escaped_path : String = path.replace("\\", "/").replace('"', '\\"');
	text_edit.insert_text_at_caret('[img path="%s" width=100 height=100]' % escaped_path);
	text_edit.grab_focus();

func insert_emoji(emoji : String) -> void:
	text_edit.insert_text_at_caret(emoji);
	text_edit.grab_focus();

func _get_text_offset(line : int, column : int) -> int:
	for index in range(line):
		column += text_edit.get_line(index).length() + 1;
	return column;

func _get_text_position(offset : int) -> Vector2i:
	var lines : PackedStringArray = text_edit.text.left(offset).split("\n");
	return Vector2i(lines[-1].length(), lines.size() - 1);

func insert_bbcode_style(bbcode : String, content : String = "") -> void :
	if (not text_edit.has_selection()):
		return;
	var start : int = _get_text_offset(text_edit.get_selection_from_line(), text_edit.get_selection_from_column());
	var end : int = _get_text_offset(text_edit.get_selection_to_line(), text_edit.get_selection_to_column());
	var tags : RegEx = RegEx.new();
	tags.compile("\\[(/?)%s(?:=[^\\]\\r\\n]*)?\\]" % bbcode);
	var stack : Array[RegExMatch] = [];
	var pairs : Array[Vector4i] = [];
	for tag in tags.search_all(text_edit.text):
		if (tag.get_string(1).is_empty()):
			stack.append(tag);
		elif (not stack.is_empty()):
			var opening : RegExMatch = stack.pop_back();
			pairs.append(Vector4i(opening.get_start(), opening.get_end(), tag.get_start(), tag.get_end()));
	var formatting : RegEx = RegEx.new();
	formatting.compile("\\[/?[a-zA-Z][^\\]\\r\\n]*\\]");
	var expanded : bool = true;
	while expanded:
		expanded = false;
		for pair in pairs:
			if (pair.y > start || pair.z < end):
				continue;
			var before : String = text_edit.text.substr(pair.y, start - pair.y);
			var after : String = text_edit.text.substr(end, pair.z - end);
			if (formatting.sub(before, "", true).is_empty() && formatting.sub(after, "", true).is_empty()):
				start = pair.x;
				end = pair.w;
				expanded = true;
	var selected : String = text_edit.text.substr(start, end - start);
	var open_tag : String = "[%s]" % bbcode if content.is_empty() else "[%s=%s]" % [bbcode, content];
	var remove_style : bool = false;
	var removals : Array[Vector2i] = [];
	for pair in pairs:
		if (pair.x == start && pair.w == end && text_edit.text.substr(pair.x, pair.y - pair.x) == open_tag):
			remove_style = true;
		if (pair.x >= start && pair.w <= end):
			removals.append(Vector2i(pair.x - start, pair.y - pair.x));
			removals.append(Vector2i(pair.z - start, pair.w - pair.z));
	removals.sort_custom(func(a : Vector2i, b : Vector2i) : return a.x > b.x);
	for removal in removals:
		selected = selected.erase(removal.x, removal.y);
	var replacement : String = selected if remove_style else open_tag + selected + "[/%s]" % bbcode;
	var selection_start : int = start if remove_style else start + open_tag.length();
	var from : Vector2i = _get_text_position(start);
	var to : Vector2i = _get_text_position(end);
	text_edit.begin_complex_operation();
	text_edit.select(from.y, from.x, to.y, to.x);
	text_edit.insert_text_at_caret(replacement);
	text_edit.end_complex_operation();
	from = _get_text_position(selection_start);
	to = _get_text_position(selection_start + selected.length());
	text_edit.select(from.y, from.x, to.y, to.x);
	text_edit.grab_focus();
