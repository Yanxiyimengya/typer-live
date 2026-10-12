extends Node;

signal settings_changed;

const SAVE_PATH : String = "user://settings.cfg";
const DECORATION_IMAGES = preload("res://scripts/core/decoration_image_store.gd");
const DEFAULT_FONT_PATH : String = "";
const DEFAULT_EMOJI_FONT_PATH : String = "";
const BUNDLED_EMOJI_FONT : Font = preload("res://assets/fonts/emoji.ttf");
const DEFAULT_FONT_SIZE : int = 24;
const DEFAULT_FONT_COLOR : Color = Color.WHITE;
const DEFAULT_VOICE_PATH : String = "res://assets/audios/voices/voice.mp3";
const DEFAULT_VOICE_VOLUME : float = 100.0;
const DEFAULT_FADE_OUT_TIME : float = 2.0;
const DEFAULT_SENDER_NAME : String = "忆梦";
const DEFAULT_TTS_SETTINGS : Dictionary = {"enabled": false, "voice": "", "volume": 100, "rate": 1.0};
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
var emoji_font_path : String = DEFAULT_EMOJI_FONT_PATH;
var font_size : int = DEFAULT_FONT_SIZE;
var font_color : Color = DEFAULT_FONT_COLOR;
var voice_path : String = DEFAULT_VOICE_PATH;
var voice_volume : float = DEFAULT_VOICE_VOLUME;
var fade_out_time : float = DEFAULT_FADE_OUT_TIME;
var sender_name : String = DEFAULT_SENDER_NAME;
var default_font : Font;
var default_emoji_font : Font;
var tts_settings : Dictionary = DEFAULT_TTS_SETTINGS.duplicate(true);
var default_voice : AudioStream;
var live_window_size : Vector2i = Vector2i(800, 300);
var live_window_position : Vector2i = Vector2i.ZERO;
var has_live_window_rect : bool = false;
var bubble_style : Dictionary = DEFAULT_BUBBLE_STYLE.duplicate(true);
var sender_style : Dictionary = DEFAULT_SENDER_STYLE.duplicate(true);
var decoration_items : Array = [];
var _emoji_font_cache : Dictionary = {};
var _cached_emoji_font : Font;
var _font_file_cache : Dictionary = {};

func _ready() -> void:
	load_settings();

func load_font(path : String, family : String = "") -> Font:
	if (not family.is_empty()):
		var system_font : SystemFont = SystemFont.new();
		system_font.font_names = PackedStringArray([family]);
		return system_font;
	if (path.begins_with("res://")):
		return load(path) as Font if ResourceLoader.exists(path) else null;
	var file : FileAccess = FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null;
	if (file == null):
		_font_file_cache.erase(path);
		return null;
	var stamp : Vector2i = Vector2i(FileAccess.get_modified_time(path), file.get_length());
	file.close();
	if (_font_file_cache.has(path) && _font_file_cache[path].stamp == stamp):
		return _font_file_cache[path].font;
	var result : FontFile = FontFile.new();
	if (result.load_dynamic_font(path) != OK):
		_font_file_cache.erase(path);
		return null;
	_font_file_cache[path] = {"stamp": stamp, "font": result};
	return result;

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

func load_emoji_font(path : String) -> Font:
	var custom : Font = load_font(path) if not path.is_empty() else null;
	return custom if custom != null else BUNDLED_EMOJI_FONT;

func with_emoji_font(base_font : Font, style : String = "normal") -> Font:
	if (base_font == null || default_emoji_font == null):
		return base_font;
	if (_cached_emoji_font != default_emoji_font):
		_emoji_font_cache.clear();
		_cached_emoji_font = default_emoji_font;
	if (not _emoji_font_cache.has(base_font)):
		_emoji_font_cache[base_font] = {};
	if (_emoji_font_cache[base_font].has(style)):
		return _emoji_font_cache[base_font][style];
	var combined : FontVariation = FontVariation.new();
	combined.base_font = base_font;
	if (style in ["bold", "bold_italics"]):
		combined.variation_embolden = 1.2;
	if (style in ["italics", "bold_italics"]):
		combined.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.2, 1.0), Vector2.ZERO);
	var fallbacks : Array[Font] = [default_emoji_font];
	for fallback : Font in base_font.fallbacks:
		if (fallback != default_emoji_font):
			fallbacks.append(fallback);
	combined.fallbacks = fallbacks;
	_emoji_font_cache[base_font][style] = combined;
	return combined;

func normalize_tts_settings(value : Dictionary) -> Dictionary:
	return {"enabled": bool(value.get("enabled", false)), "voice": str(value.get("voice", "")), "volume": clampi(int(value.get("volume", 100)), 0, 100), "rate": clampf(float(value.get("rate", 1.0)), 0.5, 2.0)};

func load_settings() -> void:
	_font_file_cache.clear();
	var config : ConfigFile = ConfigFile.new();
	if (config.load(SAVE_PATH) == OK):
		font_path = str(config.get_value("font", "path", font_path));
		font_family = str(config.get_value("font", "family", ""));
		emoji_font_path = str(config.get_value("general", "emoji_font_path", DEFAULT_EMOJI_FONT_PATH)).strip_edges();
		font_size = clampi(int(config.get_value("font", "size", font_size)), 1, 200);
		var color : Variant = config.get_value("font", "color", font_color);
		if (color is Color):
			font_color = color;
		voice_path = str(config.get_value("general", "voice_path", config.get_value("font", "voice_path", voice_path)));
		voice_volume = clampf(float(config.get_value("general", "voice_volume", DEFAULT_VOICE_VOLUME)), 0.0, 100.0);
		fade_out_time = maxf(float(config.get_value("general", "fade_out_time", DEFAULT_FADE_OUT_TIME)), 0.0);
		sender_name = str(config.get_value("general", "sender_name", DEFAULT_SENDER_NAME));
		tts_settings = normalize_tts_settings(config.get_value("general", "tts", DEFAULT_TTS_SETTINGS));
		has_live_window_rect = config.has_section_key("live_window", "position");
		live_window_size = config.get_value("live_window", "size", Vector2i(800, 300));
		live_window_position = config.get_value("live_window", "position", Vector2i.ZERO);
		bubble_style = DEFAULT_BUBBLE_STYLE.duplicate(true);
		bubble_style.merge(config.get_value("bubble", "body", {}), true);
		sender_style = DEFAULT_SENDER_STYLE.duplicate(true);
		sender_style.merge(config.get_value("bubble", "sender", {}), true);
		decoration_items = config.get_value("bubble", "decorations", []).duplicate(true);
		var migrated : bool = false;
		for item : Dictionary in decoration_items:
			var original : String = item.get("path", "");
			if (DECORATION_IMAGES.is_managed(original)):
				continue;
			var stored : String = DECORATION_IMAGES.import_image(original);
			if (not stored.is_empty()):
				item.path = stored;
				migrated = true;
		if (migrated):
			config.set_value("bubble", "decorations", decoration_items);
			var error : Error = config.save(SAVE_PATH);
			if (error != OK):
				push_warning("保存物件图片迁移结果失败：" + error_string(error));
	default_font = load_font(font_path, font_family);
	default_emoji_font = load_emoji_font(emoji_font_path);
	default_voice = load_voice(voice_path);
	settings_changed.emit();
	call_deferred("cleanup_decoration_images");

func cleanup_decoration_images() -> void:
	var references : Array = decoration_items.duplicate(true);
	# Keep disk references too: a failed save must never invalidate saved images.
	var config : ConfigFile = ConfigFile.new();
	var error : Error = config.load(SAVE_PATH);
	if (error == OK):
		references.append_array(config.get_value("bubble", "decorations", []));
	elif (error != ERR_FILE_NOT_FOUND):
		return;
	for editor : Node in get_tree().get_nodes_in_group("decoration_image_editors"):
		references.append_array(editor.get_data());
	DECORATION_IMAGES.collect_unused(references);

func apply_settings(path : String, size : int, color : Color, sound_path : String, family : String = "", body_style : Dictionary = {}, name_style : Dictionary = {}, stay_time : float = -1.0, speaker : Variant = null, sound_volume : float = -1.0, items : Variant = null, emoji_path : Variant = null, tts_options : Variant = null) -> Error:
	var new_tts : Dictionary = normalize_tts_settings(tts_settings if tts_options == null else tts_options);
	var new_emoji_path : String = emoji_font_path if emoji_path == null else str(emoji_path).strip_edges();
	var new_emoji_font : Font = BUNDLED_EMOJI_FONT;
	if (not new_emoji_path.is_empty()):
		if (not FileAccess.file_exists(new_emoji_path)):
			return ERR_FILE_CANT_OPEN;
		new_emoji_font = load_font(new_emoji_path);
	if (new_emoji_font == null):
		return ERR_FILE_CANT_OPEN;
	var new_items : Array = (decoration_items if items == null else items).duplicate(true);
	var imported_paths : Dictionary = {};
	for item : Dictionary in new_items:
		var original : String = item.get("path", "");
		if (not imported_paths.has(original)):
			imported_paths[original] = DECORATION_IMAGES.import_image(original);
		var stored : String = imported_paths[original];
		if (stored.is_empty()):
			return ERR_CANT_CREATE;
		item.path = stored;
	sound_volume = voice_volume if sound_volume < 0.0 else clampf(sound_volume, 0.0, 100.0);
	var new_sender : String = sender_name if speaker == null else str(speaker);
	if (stay_time < 0.0):
		stay_time = fade_out_time;
	if (body_style.is_empty()):
		body_style = bubble_style;
	if (name_style.is_empty()):
		name_style = sender_style;
	var new_font : Font = default_font if not family.is_empty() && family == font_family else load_font(path, family);
	var new_voice : AudioStream = default_voice if sound_path == voice_path else load_voice(sound_path);
	var items_changed : bool = new_items != decoration_items;
	var changed : bool = path != font_path || family != font_family || new_emoji_path != emoji_font_path || new_emoji_font != default_emoji_font || new_font != default_font || clampi(size, 1, 200) != font_size || color != font_color || sound_path != voice_path || sound_volume != voice_volume || stay_time != fade_out_time || new_sender != sender_name || new_tts != tts_settings || body_style != bubble_style || name_style != sender_style || items_changed;
	var config : ConfigFile = ConfigFile.new();
	config.load(SAVE_PATH);
	config.set_value("font", "path", path);
	config.set_value("font", "family", family);
	config.set_value("font", "size", clampi(size, 1, 200));
	config.set_value("font", "color", color);
	config.set_value("general", "voice_path", sound_path);
	config.set_value("general", "voice_volume", sound_volume);
	config.set_value("general", "fade_out_time", stay_time);
	config.set_value("general", "sender_name", new_sender);
	config.set_value("general", "emoji_font_path", new_emoji_path);
	config.set_value("general", "tts", new_tts);
	if (config.has_section_key("font", "voice_path")):
		config.erase_section_key("font", "voice_path");
	config.set_value("bubble", "body", body_style);
	config.set_value("bubble", "sender", name_style);
	config.set_value("bubble", "decorations", new_items);
	var error : Error = config.save(SAVE_PATH);
	if (error != OK):
		return error;
	font_path = path;
	font_family = family;
	emoji_font_path = new_emoji_path;
	default_emoji_font = new_emoji_font;
	tts_settings = new_tts;
	font_size = clampi(size, 1, 200);
	font_color = color;
	voice_path = sound_path;
	voice_volume = sound_volume;
	fade_out_time = stay_time;
	sender_name = new_sender;
	default_font = new_font;
	default_voice = new_voice;
	bubble_style = body_style.duplicate(true);
	sender_style = name_style.duplicate(true);
	decoration_items = new_items.duplicate(true);
	if (changed):
		settings_changed.emit();
	if (items_changed):
		cleanup_decoration_images();
	return OK;

func save_live_window(size : Vector2i, position : Vector2i) -> Error:
	var config : ConfigFile = ConfigFile.new();
	config.load(SAVE_PATH);
	config.set_value("live_window", "size", size);
	config.set_value("live_window", "position", position);
	var error : Error = config.save(SAVE_PATH);
	if (error == OK):
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
			if (not path.is_empty()):
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
