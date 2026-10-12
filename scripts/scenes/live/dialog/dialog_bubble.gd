class_name DialogBubble;
extends Control;

signal print_char(char : String);

const DECORATION_ITEM : PackedScene = preload("res://scenes/live/dialog/decoration_item.tscn");
var _decoration_items : Array = [];
var _applied_fonts : Array = [];
var _body_style : Dictionary = {};
var _sender_style : Dictionary = {};

@export_multiline() var text : String = "";
@export var delay : float = 1;
@export var voice : AudioStream;
@export var font : Font;
@export var font_color : Color = Color.WHITE;
@export var font_size : int = 16;

var _progress : int = 0;
var _print_timer : float = 0.0;
var _han_regex : RegEx = RegEx.create_from_string("\\p{Han}");

@onready var dialog_text_label : RichTextLabel = %DialogTextLabel;
@onready var sender_text_label : RichTextLabel = %SenderTextLabel;
@onready var continue_indicator : Control = %ContinueIndicator;
const INNER_BBCODE: PackedStringArray = [
	# 基础样式
	"b", "i", "u", "s", "code",
	# 布局与对齐
	"center", "left", "right", "fill", "indent", "p", "br", "hr",
	# 颜色与字体
	"color", "bgcolor", "fgcolor", "font", "font_size",
	"outline_size", "outline_color", "dropcap", "opentype_features", "lang",
	# 链接与图片
	"url", "hint", "img",
	# 列表与表格
	"ul", "ol", "table", "cell",
	# 转义与特殊字符
	"lb", "rb", "char",
	# Unicode 控制字符
	"lrm", "rlm", "lre", "rle", "lro", "rlo", "pdf", "alm",
	"lri", "rli", "fsi", "pdi", "zwj", "zwnj", "wj", "shy",
	# 文本特效
	"pulse", "wave", "tornado", "shake", "fade", "rainbow"
]

@onready var decoration_items_layer : Control = %DecorationItemsLayer;
@onready var panel_container : PanelContainer = %PanelContainer;
@onready var sender_panel_container : PanelContainer = %SenderPanelContainer;

func _ready() -> void:
	resized.connect(_layout_decorations);
	decoration_items_layer.item_rect_changed.connect(_layout_decorations);
	var pulse : Tween = create_tween().set_loops();
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
	pulse.tween_property(continue_indicator, "modulate:a", 0.35, 0.8);
	pulse.tween_property(continue_indicator, "modulate:a", 1.0, 0.8);
	_progress = 0;
	GlobalSettings.settings_changed.connect(_apply_settings);
	_apply_settings();

func _apply_settings() -> void:
	sender_text_label.text = GlobalSettings.sender_name;
	font = GlobalSettings.default_font;
	font_size = GlobalSettings.font_size;
	font_color = GlobalSettings.font_color;
	voice = GlobalSettings.default_voice;
	apply_bubble_styles(GlobalSettings.bubble_style, GlobalSettings.sender_style);
	apply_item_decorations(GlobalSettings.decoration_items);
	dialog_text_label.add_theme_color_override("default_color", font_color);
	var font_settings : Array = [font, GlobalSettings.default_emoji_font, font_size];
	if (_applied_fonts == font_settings):
		return;
	_applied_fonts = font_settings;
	for label : RichTextLabel in [dialog_text_label, sender_text_label]:
		label.remove_theme_font_override("normal_font");
		var base_font : Font = font if font != null else label.get_theme_font("normal_font");
		for style : String in ["normal", "bold", "italics", "bold_italics"]:
			label.remove_theme_font_override(style + "_font");
			label.add_theme_font_override(style + "_font", GlobalSettings.with_emoji_font(base_font, style));
			label.add_theme_font_size_override(style + "_font_size", font_size);

func apply_bubble_styles(body : Dictionary, sender : Dictionary) -> void:
	if (_body_style != body):
		_body_style = body.duplicate(true);
		panel_container.add_theme_stylebox_override("panel", GlobalSettings.make_style(body));
	if (_sender_style != sender):
		_sender_style = sender.duplicate(true);
		sender_panel_container.add_theme_stylebox_override("panel", GlobalSettings.make_style(sender));
	
func apply_item_decorations(items : Array) -> void:
	if (_decoration_items == items):
		return;
	_decoration_items = items.duplicate(true);
	while decoration_items_layer.get_child_count() > items.size():
		var item : Node = decoration_items_layer.get_child(decoration_items_layer.get_child_count() - 1);
		decoration_items_layer.remove_child(item);
		item.queue_free();
	while decoration_items_layer.get_child_count() < items.size():
		decoration_items_layer.add_child(DECORATION_ITEM.instantiate());
	for index in range(items.size()):
		var item : TextureRect = decoration_items_layer.get_child(index);
		item.texture = GlobalResourceLoader.load_image(items[index].path);
		item.visible = items[index].get("visible", true);
	_layout_decorations();

func _layout_decorations() -> void:
	for index in range(_decoration_items.size()):
		var data : Dictionary = _decoration_items[index];
		var item : TextureRect = decoration_items_layer.get_child(index);
		item.size = data.size;
		item.pivot_offset = item.size / 2.0;
		item.scale = data.scale;
		item.rotation_degrees = data.rotation;
		item.position = size * data.anchor + data.position - decoration_items_layer.position;

func _process(delta: float) -> void:
	continue_indicator.visible = not text.is_empty() && is_completed();
	_print_timer -= delta;
	if (_print_timer <= 0) :
		_print_timer = delay;
		var text_len : int = text.length();
		while (_progress < text_len) : 
			while(_progress < text_len && text[_progress] == '[') : 
				var start_pos : int = _progress + 1;
				var end_pos : int = _bbcode_end(_progress);
				if (end_pos == -1):
					break;
				var bbcode_content : String = text.substr(start_pos, end_pos - start_pos);
				_progress = end_pos + 1;
				if (bbcode_content.is_empty()) : 
					continue;
				var cmd_infos : Dictionary[String, Variant] = _proc_args(bbcode_content);
				var cmd : String = cmd_infos["cmd"];
				if (!cmd.is_empty()) : 
					var args : Dictionary[String, Variant] = cmd_infos["args"];
					if (!_proc_bbcode(cmd, args)) :
						var bare_cmd : String = cmd.trim_prefix("/");
						if (bare_cmd in INNER_BBCODE) :
							dialog_text_label.append_text("[%s]" % [bbcode_content]);
				else :
					_progress = end_pos + 1;
			
			if (_progress >= text_len) : return;
			var c : String = text[_progress];
			_print_timer = delay * (2.0 if _han_regex.search(c) != null else 1.0);
			dialog_text_label.append_text(c);
			print_char.emit(c);
			if (voice && !c.strip_edges().is_empty()) : 
				GlobalSoundManager.play_sound(voice);
			_progress += 1;
			break;

func _bbcode_end(start : int) -> int:
	var quoted : bool = false;
	var escaped : bool = false;
	for index in range(start + 1, text.length()):
		var c : String = text[index];
		if (escaped):
			escaped = false;
		elif (quoted && c == "\\"):
			escaped = true;
		elif (c == '"'):
			quoted = not quoted;
		elif (c == "]" && not quoted):
			return index;
	return -1;

func _proc_args(bb : String) -> Dictionary[String, Variant]:
	var bbcode : String = bb.strip_edges();
	var v_args : Dictionary[String, Variant] = {};
	var result : Dictionary[String, Variant] = {
		"cmd" : bbcode,
		"args" : v_args,
	};
	
	var sp : int = bbcode.find(" ");
	var eq : int = bbcode.find("=");
	
	if (sp == -1 && eq == -1) : return result;
	
	var sep : int = -1;
	var is_eq : bool = false;
	if (sp == -1) :
		sep = eq;
		is_eq = true;
	elif (eq == -1) :
		sep = sp;
		is_eq = false;
	elif (eq < sp) :
		sep = eq;
		is_eq = true;
	else :
		sep = sp;
		is_eq = false;
	
	var cmd : String = bbcode.substr(0, sep).strip_edges();
	result["cmd"] = cmd;
	
	var rest : String = bbcode.substr(sep + 1).strip_edges();
	if (rest.is_empty()) : return result;
	
	if (is_eq) :
		var space_after : int = rest.find(" ");
		if (space_after == -1) :
			v_args.set("__value__", _parse_value(rest));
			return result;
		else :
			var first_value : String = rest.substr(0, space_after).strip_edges();
			v_args.set("__value__", _parse_value(first_value));
			rest = rest.substr(space_after + 1).strip_edges();
			if (rest.is_empty()) : return result;
	
	var token_regex := RegEx.new();
	token_regex.compile(
			'([\\p{L}_][\\p{L}\\p{N}_]*)' +
			'(?:\\s*=\\s*("(?:[^"\\\\]|\\\\.)*"|[^\\s"\\]]+))?'
		);
	
	for m in token_regex.search_all(rest):
		var key : String = m.get_string(1);
		var raw_value : String = m.get_string(2);
		if (raw_value.is_empty()) :
			v_args.set(key, null);
		else :
			v_args.set(key, _parse_value(raw_value));
	
	return result;

func _parse_value(raw: String) -> Variant:
	if (raw.begins_with('"') && raw.ends_with('"')):
		var inner : String = raw.substr(1, raw.length() - 2);
		return inner.replace('\\"', '"').replace('\\\\', '\\');
	if (raw.is_valid_int()):
		return raw.to_int();
	if (raw.is_valid_float()):
		return raw.to_float();
	if (raw.is_valid_html_color()):
		return Color.from_string(raw, Color.WHITE);
	return raw;

func _proc_bbcode(cmd : String, _args : Dictionary[String, Variant]) -> bool:
	if (cmd) : 
		match (cmd) : 
			"emoji" : 
				if (_args.has("__value__")) : 
					pass;
			"img" : 
				if (_args.has("path")) : 
					var img_path : String = _args["path"];
					var texture : ImageTexture = GlobalResourceLoader.load_image(img_path);
					if (texture == null):
						return true;
					var img_size : Vector2 = Vector2.ZERO;
					
					if (_args.has("__value__")) : 
						var value : String = _args["__value__"];
						var w : float = value.get_slice("x", 0).to_float();
						var h : float = value.get_slice("x", 1).to_float();
						img_size = Vector2(w, h);
					if (_args.has("width")) : 
						img_size.x = float(_args["width"]);
					if (_args.has("height")) : 
						img_size.y = float(_args["height"]);
					
					dialog_text_label.add_image(texture, img_size.x, img_size.y);
					return true;
				pass;
	return false;

func is_completed() -> bool : 
	return _progress >= text.length();

func clear_text() -> void : 
	continue_indicator.hide();
	self.text = "";
	self.dialog_text_label.text = "";
	self.sender_text_label.text = "";

func print_text(s : String, t : String) -> void : 
	continue_indicator.hide();
	self.text = t;
	self.dialog_text_label.text = "";
	self.sender_text_label.text = s;
	_progress = 0;
	_print_timer = 0.0;
