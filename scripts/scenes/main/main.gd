extends Node;

const LIVE : PackedScene = preload("uid://vfy15iuwkbvj");
const SPEECH_TEXT = preload("res://scripts/core/bbcode_speech_text.gd");

var live_dialog_window : DefaultWindow = null;
var live_scene : Control = null;
@onready var editor : Editor = %Editor;
var _last_live_rect : Rect2i;
var _save_live_timer : float = -1.0;
var _live_window_ready : bool = false;

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
		_live_window_ready = true;

func _process(delta : float) -> void:
	if (not _live_window_ready || not is_instance_valid(live_dialog_window)):
		return;
	var rect : Rect2i = Rect2i(live_dialog_window.position, live_dialog_window.size);
	if (rect != _last_live_rect):
		_last_live_rect = rect;
		_save_live_timer = 0.5;
	elif (_save_live_timer >= 0):
		_save_live_timer -= delta;
		if (_save_live_timer <= 0):
			GlobalSettings.save_live_window(rect.size, rect.position);
			_save_live_timer = -1.0;

func _exit_tree() -> void:
	if (_live_window_ready && is_instance_valid(live_dialog_window)):
		GlobalSettings.save_live_window(live_dialog_window.size, live_dialog_window.position);

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
