class_name DialogBubble;
extends Control;

signal print_char(char : String);

@export_multiline() var text : String = "";
@export var delay : float = 1;
@export var voice : AudioStream;
@export var font : Font;
@export var font_color : Color = Color.WHITE;
@export var font_size : int = 16;

var _progress : int = 0;
var _print_timer : float = 0.0;
var _han_regex : RegEx = RegEx.create_from_string("\\p{Han}");

var dialog_text_label : RichTextLabel = null;
var sender_text_label : RichTextLabel = null;
var continue_indicator : Control = null;

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

func _ready() -> void:
	dialog_text_label = self.get_node("%DialogTextLabel");
	sender_text_label = self.get_node("%SenderTextLabel");
	continue_indicator = self.get_node("%ContinueIndicator");
	var pulse : Tween = create_tween().set_loops();
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
	pulse.tween_property(continue_indicator, "modulate:a", 0.35, 0.8);
	pulse.tween_property(continue_indicator, "modulate:a", 1.0, 0.8);
	_progress = 0;
	GlobalSettings.settings_changed.connect(_apply_settings);
	_apply_settings();

func _apply_settings() -> void:
	font = GlobalSettings.default_font;
	font_size = GlobalSettings.font_size;
	font_color = GlobalSettings.font_color;
	voice = GlobalSettings.default_voice;
	apply_bubble_styles(GlobalSettings.bubble_style, GlobalSettings.sender_style);
	dialog_text_label.add_theme_color_override("default_color", font_color);
	for label : RichTextLabel in [dialog_text_label, sender_text_label]:
		for style : String in ["normal", "bold", "italics", "bold_italics"]:
			if font != null:
				label.add_theme_font_override(style + "_font", font);
			else:
				label.remove_theme_font_override(style + "_font");
			label.add_theme_font_size_override(style + "_font_size", font_size);

func apply_bubble_styles(body : Dictionary, sender : Dictionary) -> void:
	get_node("VBoxContainer/PanelContainer").add_theme_stylebox_override("panel", GlobalSettings.make_style(body));
	get_node("VBoxContainer/SenderPanelContainer").add_theme_stylebox_override("panel", GlobalSettings.make_style(sender));
	var decorations : bool = body.get("decorations", true);
	get_node("DecorationLayer").visible = decorations;
	get_node("VBoxContainer/PanelContainer/InnerFrame").visible = decorations and int(body.get("mode", 0)) == 0;
	get_node("VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/Footer/Stars").visible = decorations;

func _process(delta: float) -> void:
	continue_indicator.visible = not text.is_empty() and is_completed();
	_print_timer -= delta;
	if (_print_timer <= 0) :
		_print_timer = delay;
		var text_len : int = text.length();
		while (_progress < text_len) : 
			while(_progress < text_len && text[_progress] == '[') : 
				var start_pos : int = _progress + 1;
				var end_pos : int = _bbcode_end(_progress);
				if end_pos == -1:
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
		if escaped:
			escaped = false;
		elif quoted and c == "\\":
			escaped = true;
		elif c == '"':
			quoted = not quoted;
		elif c == "]" and not quoted:
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
					if texture == null:
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
