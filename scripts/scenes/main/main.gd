extends Node;

const LIVE : PackedScene = preload("uid://vfy15iuwkbvj");
const SPEECH_TEXT = preload("res://scripts/core/bbcode_speech_text.gd");

var live_dialog_window : DefaultWindow = null;
var live_scene : Control = null;
@onready var editor : Editor = %Editor;
var _last_live_rect : Rect2i;
var _save_live_timer : float = -1.0;
var _live_window_ready : bool = false;
var _capture_parked : bool = false;
var _capture_parking : bool = false;
var _capture_window_mode : Window.Mode = Window.MODE_WINDOWED;

func _ready() -> void:
	GlobalSettings.settings_changed.connect(_apply_speech_settings);
	editor.send_text.connect(_on_editor_send_text);
	
	var wid : int = GlobalWindowManager.new_window();
	if (wid > 0) : 
		live_dialog_window = GlobalWindowManager.find_window(wid);
		live_dialog_window.title = "##Dialog##";
		live_dialog_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN;
		live_dialog_window.size = GlobalSettings.live_window_size;
		if (GlobalSettings.has_live_window_rect):
			live_dialog_window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE;
			live_dialog_window.position = GlobalSettings.live_window_position;
		live_dialog_window.transparent = true;
		live_dialog_window.transparent_bg = true;
		live_dialog_window.close_request = false;
		
		live_scene = LIVE.instantiate();
		live_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL;
		live_scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		live_dialog_window.add_child(live_scene);
		await live_scene.ready;
		_last_live_rect = Rect2i(live_dialog_window.position, live_dialog_window.size);
		live_dialog_window.focus_entered.connect(_restore_capture_window);
		_live_window_ready = true;

func _process(delta : float) -> void:
	if (not _live_window_ready || not is_instance_valid(live_dialog_window)):
		return;
	if (_capture_parking):
		return;
	if (live_dialog_window.mode == Window.MODE_MINIMIZED):
		if (_capture_parked):
			_restore_capture_window();
		else:
			_park_capture_window();
		return;
	if (_capture_parked):
		return;
	_capture_window_mode = live_dialog_window.mode;
	var rect : Rect2i = Rect2i(live_dialog_window.position, live_dialog_window.size);
	if (rect != _last_live_rect):
		_last_live_rect = rect;
		_save_live_timer = 0.5;
	elif (_save_live_timer >= 0):
		_save_live_timer -= delta;
		if (_save_live_timer <= 0):
			GlobalSettings.save_live_window(rect.size, rect.position);
			_save_live_timer = -1.0;

func _park_capture_window() -> void:
	# 真正最小化会中断 OBS 游戏捕获；保留原窗口，在桌面外继续提交画面。
	var desktop_right : int = 0;
	for screen : int in range(DisplayServer.get_screen_count()):
		desktop_right = maxi(desktop_right, DisplayServer.screen_get_position(screen).x + DisplayServer.screen_get_size(screen).x);
	_capture_parked = true;
	_capture_parking = true;
	var was_unfocusable : bool = live_dialog_window.unfocusable;
	live_dialog_window.unfocusable = true;
	live_dialog_window.mode = Window.MODE_WINDOWED;
	live_dialog_window.size = _last_live_rect.size;
	live_dialog_window.position = Vector2i(desktop_right + 64, _last_live_rect.position.y);
	live_dialog_window.unfocusable = was_unfocusable;
	# 忽略系统还原窗口过程中产生的延迟焦点事件。
	await live_dialog_window.get_tree().process_frame;
	await live_dialog_window.get_tree().process_frame;
	_capture_parking = false;

func _restore_capture_window() -> void:
	if (not _capture_parked || _capture_parking):
		return;
	_capture_parked = false;
	live_dialog_window.mode = Window.MODE_WINDOWED;
	live_dialog_window.size = _last_live_rect.size;
	live_dialog_window.position = _last_live_rect.position;
	live_dialog_window.mode = _capture_window_mode;

func _exit_tree() -> void:
	if (_live_window_ready && is_instance_valid(live_dialog_window)):
		var rect : Rect2i = _last_live_rect if _capture_parked || live_dialog_window.mode == Window.MODE_MINIMIZED else Rect2i(live_dialog_window.position, live_dialog_window.size);
		GlobalSettings.save_live_window(rect.size, rect.position);

func _apply_speech_settings() -> void:
	if (not GlobalSettings.tts_settings.enabled):
		GlobalTTS.stop();

func _on_editor_send_text(text : String) -> void : 
	if (GlobalSettings.tts_settings.enabled):
		var speech : Dictionary = GlobalSettings.tts_settings;
		GlobalTTS.speak(SPEECH_TEXT.plain_text(text), GlobalTTS.select_voice(speech.voice, "zh"), speech.volume, speech.rate);
	live_scene.print_text(GlobalSettings.sender_name, text);
	live_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL;
	live_scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
