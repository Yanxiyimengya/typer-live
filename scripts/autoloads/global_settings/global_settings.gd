extends Node;

signal settings_changed;

const SAVE_PATH : String = "user://settings.cfg";
const DEFAULT_FONT_PATH : String = "";
const DEFAULT_FONT_SIZE : int = 24;
const DEFAULT_FONT_COLOR : Color = Color.WHITE;
const DEFAULT_VOICE_PATH : String = "";
const DEFAULT_FADE_OUT_TIME : float = 2.0;
const DEFAULT_BUBBLE_STYLE : Dictionary = {
	"mode": 0, "background": Color(0.20, 0.13, 0.25, 0.96),
	"border_color": Color(1, 0.81, 0.87, 0.96), "border_width": 2, "radius": 24,
	"margins": [18.0, 24.0, 18.0, 14.0],
	"shadow_color": Color(0.10, 0.05, 0.14, 0.20), "shadow_size": 8,
	"shadow_offset": Vector2(0, 4), "draw_center": true, "decorations": true,
	"texture_path": "", "texture_margins": [24.0, 24.0, 24.0, 24.0], "tint": Color.WHITE
};
const DEFAULT_SENDER_STYLE : Dictionary = {
	"mode": 0, "background": Color(0.49, 0.29, 0.42, 1),
	"border_color": Color(1, 0.84, 0.89, 1), "border_width": 2, "radius": 18,
	"margins": [24.0, 8.0, 24.0, 12.0],
	"shadow_color": Color(0.12, 0.05, 0.15, 0.20), "shadow_size": 4,
	"shadow_offset": Vector2(0, 2), "draw_center": true,
	"texture_path": "", "texture_margins": [18.0, 18.0, 18.0, 18.0], "tint": Color.WHITE
};

var font_path : String = DEFAULT_FONT_PATH;
var font_family : String = "";
var font_size : int = DEFAULT_FONT_SIZE;
var font_color : Color = DEFAULT_FONT_COLOR;
var voice_path : String = DEFAULT_VOICE_PATH;
var fade_out_time : float = DEFAULT_FADE_OUT_TIME;
var default_font : Font;
var default_voice : AudioStream;
var live_window_size : Vector2i = Vector2i(800, 300);
var live_window_position : Vector2i = Vector2i.ZERO;
var has_live_window_rect : bool = false;
var bubble_style : Dictionary = DEFAULT_BUBBLE_STYLE.duplicate(true);
var sender_style : Dictionary = DEFAULT_SENDER_STYLE.duplicate(true);

func _ready() -> void:
	load_settings();

func load_font(path : String, family : String = "") -> Font:
	if (not family.is_empty()):
		var system_font : SystemFont = SystemFont.new();
		system_font.font_names = PackedStringArray([family]);
		return system_font;
	if (path.begins_with("res://")):
		return load(path) as Font if ResourceLoader.exists(path) else null;
	var result : FontFile = FontFile.new();
	return result if (result.load_dynamic_font(path)) == OK else null;

func load_voice(path : String) -> AudioStream:
	if (path.is_empty()):
		return null;
	if (path.begins_with("res://")):
		return load(path) as AudioStream if ResourceLoader.exists(path) else null;
	match path.get_extension().to_lower():
		"wav": return AudioStreamWAV.load_from_file(path);
		"ogg": return AudioStreamOggVorbis.load_from_file(path);
		"mp3": return AudioStreamMP3.load_from_file(path);
	return null;

func load_settings() -> void:
	var config : ConfigFile = ConfigFile.new();
	if config.load(SAVE_PATH) == OK:
		font_path = str(config.get_value("font", "path", font_path));
		font_family = str(config.get_value("font", "family", ""));
		font_size = clampi(int(config.get_value("font", "size", font_size)), 1, 200);
		var color : Variant = config.get_value("font", "color", font_color);
		if color is Color:
			font_color = color;
		voice_path = str(config.get_value("general", "voice_path", config.get_value("font", "voice_path", voice_path)));
		fade_out_time = maxf(float(config.get_value("general", "fade_out_time", DEFAULT_FADE_OUT_TIME)), 0.0);
		has_live_window_rect = config.has_section_key("live_window", "position");
		live_window_size = config.get_value("live_window", "size", Vector2i(800, 300));
		live_window_position = config.get_value("live_window", "position", Vector2i.ZERO);
		bubble_style = DEFAULT_BUBBLE_STYLE.duplicate(true);
		bubble_style.merge(config.get_value("bubble", "body", {}), true);
		sender_style = DEFAULT_SENDER_STYLE.duplicate(true);
		sender_style.merge(config.get_value("bubble", "sender", {}), true);
	default_font = load_font(font_path, font_family);
	default_voice = load_voice(voice_path);
	settings_changed.emit();

func apply_settings(path : String, size : int, color : Color, sound_path : String, family : String = "", body_style : Dictionary = {}, name_style : Dictionary = {}, stay_time : float = -1.0) -> Error:
	if stay_time < 0.0:
		stay_time = fade_out_time;
	if body_style.is_empty():
		body_style = bubble_style;
	if name_style.is_empty():
		name_style = sender_style;
	var new_font : Font = load_font(path, family);
	var new_voice : AudioStream = load_voice(sound_path);
	var config : ConfigFile = ConfigFile.new();
	config.load(SAVE_PATH);
	config.set_value("font", "path", path);
	config.set_value("font", "family", family);
	config.set_value("font", "size", clampi(size, 1, 200));
	config.set_value("font", "color", color);
	config.set_value("general", "voice_path", sound_path);
	config.set_value("general", "fade_out_time", stay_time);
	if config.has_section_key("font", "voice_path"):
		config.erase_section_key("font", "voice_path");
	config.set_value("bubble", "body", body_style);
	config.set_value("bubble", "sender", name_style);
	var error : Error = config.save(SAVE_PATH);
	if error != OK:
		return error;
	font_path = path;
	font_family = family;
	font_size = clampi(size, 1, 200);
	font_color = color;
	voice_path = sound_path;
	fade_out_time = stay_time;
	default_font = new_font;
	default_voice = new_voice;
	bubble_style = body_style.duplicate(true);
	sender_style = name_style.duplicate(true);
	settings_changed.emit();
	return OK;

func save_live_window(size : Vector2i, position : Vector2i) -> Error:
	var config : ConfigFile = ConfigFile.new();
	config.load(SAVE_PATH);
	config.set_value("live_window", "size", size);
	config.set_value("live_window", "position", position);
	var error : Error = config.save(SAVE_PATH);
	if error == OK:
		live_window_size = size;
		live_window_position = position;
		has_live_window_rect = true;
	return error;

func make_style(data : Dictionary) -> StyleBox:
	var style : StyleBox;
	match int(data.get("mode", 0)):
		1:
			style = StyleBoxEmpty.new();
		2:
			var texture_style : StyleBoxTexture = StyleBoxTexture.new();
			var path : String = data.get("texture_path", "");
			if not path.is_empty():
				texture_style.texture = GlobalResourceLoader.load_image(path);
			texture_style.modulate_color = data.get("tint", Color.WHITE);
			texture_style.draw_center = data.get("draw_center", true);
			var slices : Array = data.get("texture_margins", [0.0, 0.0, 0.0, 0.0]);
			for side in range(4):
				texture_style.set_texture_margin(side, slices[side]);
			style = texture_style;
		_:
			var flat : StyleBoxFlat = StyleBoxFlat.new();
			flat.bg_color = data.get("background", Color.WHITE);
			flat.border_color = data.get("border_color", Color.WHITE);
			flat.set_border_width_all(int(data.get("border_width", 0)));
			flat.set_corner_radius_all(int(data.get("radius", 0)));
			flat.shadow_color = data.get("shadow_color", Color.TRANSPARENT);
			flat.shadow_size = int(data.get("shadow_size", 0));
			flat.shadow_offset = data.get("shadow_offset", Vector2.ZERO);
			flat.draw_center = data.get("draw_center", true);
			style = flat;
	var margins : Array = data.get("margins", [0.0, 0.0, 0.0, 0.0]);
	for side in range(4):
		style.set_content_margin(side, margins[side]);
	return style;
