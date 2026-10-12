extends PanelContainer;

signal confirmed;

@onready var file_dialog : FileDialog = %ResourceFileDialog;
var path_field : LineEdit;

@onready var font_color_button : ColorPickerButton = %FontColorButton;
@onready var font_option_button : OptionButton = %FontOptionButton;
@onready var font_browse_button : Button = %FontBrowseButton;
@onready var font_path_edit : LineEdit = %FontPathEdit;
@onready var emoji_font_browse_button : Button = %EmojiFontBrowseButton;
@onready var emoji_font_path_edit : LineEdit = %EmojiFontPathEdit;
@onready var emoji_font_reset_button : Button = %EmojiFontResetButton;
@onready var voice_browse_button : Button = %VoiceBrowseButton;
@onready var voice_path_edit : LineEdit = %VoicePathEdit;
@onready var confirm_button : Button = %ConfirmButton;
@onready var font_reset_button : Button = %FontResetButton;
@onready var size_reset_button : Button = %SizeResetButton;
@onready var font_size_spin_box : SpinBox = %FontSizeSpinBox;
@onready var color_reset_button : Button = %ColorResetButton;
@onready var voice_reset_button : Button = %VoiceResetButton;
@onready var fade_out_reset_button : Button = %FadeOutResetButton;
@onready var fade_out_time_spin_box : SpinBox = %FadeOutTimeSpinBox;
@onready var sender_reset_button : Button = %SenderResetButton;
@onready var sender_name_edit : LineEdit = %SenderNameEdit;
@onready var voice_volume_slider : HSlider = %VoiceVolumeSlider;
@onready var tts_voice_option : OptionButton = %TTSVoiceOption;
@onready var tts_test_button : Button = %TTSTestButton;
@onready var tts_stop_button : Button = %TTSStopButton;
@onready var bubble_settings : TabContainer = %BubbleSettings;
@onready var tts_enabled : CheckButton = %TTSEnabled;
@onready var tts_volume : SpinBox = %TTSVolume;
@onready var tts_rate : SpinBox = %TTSRate;
@onready var tts_unavailable_hint : Label = %TTSUnavailableHint;
@onready var voice_volume_label : Label = %VoiceVolumeLabel;

func _ready() -> void:
	var picker : ColorPicker = font_color_button.get_picker();
	font_color_button.get_popup().theme = get_window().theme;
	picker.edit_intensity = false;
	picker.picker_shape = ColorPicker.SHAPE_VHS_CIRCLE;
	picker.sampler_visible = false;
	picker.color_modes_visible = false;
	font_option_button.add_item("文件字体");
	font_option_button.set_item_metadata(0, "");
	var families : PackedStringArray = OS.get_system_fonts();
	families.sort();
	for family in families:
		font_option_button.add_item(family);
		font_option_button.set_item_metadata(font_option_button.item_count - 1, family);
	font_option_button.get_popup().theme = get_window().theme;
	font_option_button.item_selected.connect(_select_font);
	file_dialog.theme = get_window().theme;
	file_dialog.file_selected.connect(func(path : String): path_field.text = path);
	font_browse_button.pressed.connect(_browse.bind(font_path_edit, PackedStringArray(["*.ttf,*.otf,*.ttc;字体"])));
	emoji_font_browse_button.pressed.connect(_browse.bind(emoji_font_path_edit, PackedStringArray(["*.ttf,*.otf,*.ttc;字体"])));
	emoji_font_reset_button.pressed.connect(func(): emoji_font_path_edit.text = GlobalSettings.DEFAULT_EMOJI_FONT_PATH);
	voice_browse_button.pressed.connect(_browse.bind(voice_path_edit, PackedStringArray(["*.wav,*.ogg,*.mp3;音效"])));
	confirm_button.pressed.connect(_confirm);
	font_reset_button.pressed.connect(_reset_font);
	size_reset_button.pressed.connect(func(): font_size_spin_box.value = GlobalSettings.DEFAULT_FONT_SIZE);
	color_reset_button.pressed.connect(func(): font_color_button.color = GlobalSettings.DEFAULT_FONT_COLOR);
	voice_reset_button.pressed.connect(func(): voice_path_edit.text = GlobalSettings.DEFAULT_VOICE_PATH);
	fade_out_reset_button.pressed.connect(func(): fade_out_time_spin_box.value = GlobalSettings.DEFAULT_FADE_OUT_TIME);
	sender_reset_button.pressed.connect(func(): sender_name_edit.text = GlobalSettings.DEFAULT_SENDER_NAME);
	voice_volume_slider.value_changed.connect(_update_volume_label);
	tts_voice_option.get_popup().theme = theme;
	tts_test_button.pressed.connect(_test_tts);
	tts_stop_button.pressed.connect(GlobalTTS.stop);
	refresh();

func refresh() -> void:
	var selected : int = 0;
	for index in range(font_option_button.item_count):
		if (font_option_button.get_item_metadata(index) == GlobalSettings.font_family):
			selected = index;
			break;
	font_option_button.select(selected);
	_select_font(selected);
	font_path_edit.text = GlobalSettings.font_path;
	emoji_font_path_edit.text = GlobalSettings.emoji_font_path;
	font_size_spin_box.value = GlobalSettings.font_size;
	font_color_button.color = GlobalSettings.font_color;
	voice_path_edit.text = GlobalSettings.voice_path;
	voice_volume_slider.value = GlobalSettings.voice_volume;
	_update_volume_label(voice_volume_slider.value);
	fade_out_time_spin_box.value = GlobalSettings.fade_out_time;
	sender_name_edit.text = GlobalSettings.sender_name;
	_refresh_tts();
	bubble_settings.refresh();

func _refresh_tts() -> void:
	GlobalTTS.refresh_voices();
	tts_enabled.set_pressed_no_signal(GlobalSettings.tts_settings.enabled);
	tts_volume.set_value_no_signal(GlobalSettings.tts_settings.volume);
	tts_rate.set_value_no_signal(GlobalSettings.tts_settings.rate);
	tts_voice_option.clear();
	tts_voice_option.add_item("自动选择（优先中文）");
	tts_voice_option.set_item_metadata(0, "");
	var selected : int = 0;
	for voice : Dictionary in GlobalTTS.get_voices():
		var index : int = tts_voice_option.item_count;
		tts_voice_option.add_item("%s · %s" % [voice.get("name", voice.id), voice.get("language", "")]);
		tts_voice_option.set_item_metadata(index, str(voice.id));
		if (str(voice.id) == GlobalSettings.tts_settings.voice):
			selected = index;
	if (selected == 0 && not GlobalSettings.tts_settings.voice.is_empty()):
		selected = tts_voice_option.item_count;
		tts_voice_option.add_item("已保存音色（当前不可用）");
		tts_voice_option.set_item_metadata(selected, GlobalSettings.tts_settings.voice);
	tts_voice_option.select(selected);
	tts_unavailable_hint.visible = not GlobalTTS.is_available();
	tts_test_button.disabled = not GlobalTTS.is_available();
	tts_stop_button.disabled = not GlobalTTS.is_available();

func _tts_options() -> Dictionary:
	return {"enabled": tts_enabled.button_pressed, "voice": str(tts_voice_option.get_selected_metadata()), "volume": int(tts_volume.value), "rate": tts_rate.value};

func _test_tts() -> void:
	var options : Dictionary = _tts_options();
	var error : Error = GlobalTTS.speak("你好，这是文字转语音试听。", GlobalTTS.select_voice(options.voice, "zh"), options.volume, options.rate);
	if (error != OK):
		_show_save_error("当前没有可用的系统语音，请安装语音包后重新打开设置。", "试听失败");

func _update_volume_label(value : float) -> void:
	voice_volume_label.text = "%d%%" % int(value);

func _select_font(index : int) -> void:
	font_path_edit.get_parent().visible = index == 0;

func _reset_font() -> void:
	font_option_button.select(0);
	_select_font(0);
	font_path_edit.text = GlobalSettings.DEFAULT_FONT_PATH;

func _browse(field : LineEdit, filters : PackedStringArray) -> void:
	path_field = field;
	file_dialog.filters = filters;
	file_dialog.popup_centered(Vector2i(900, 600));

func _confirm() -> void:
	var emoji_path : String = emoji_font_path_edit.text.strip_edges();
	var error : Error = GlobalSettings.apply_settings( \
		font_path_edit.text.strip_edges(), \
		int(font_size_spin_box.value), \
		font_color_button.color, \
		voice_path_edit.text.strip_edges(), \
		font_option_button.get_selected_metadata(), \
		bubble_settings.body_editor.get_data(), \
		bubble_settings.sender_editor.get_data(), \
		fade_out_time_spin_box.value, \
		sender_name_edit.text, \
		voice_volume_slider.value, \
		bubble_settings.decoration_editor.get_data(), \
		emoji_path, \
		_tts_options());
	if (error != OK):
		if (error == ERR_FILE_CANT_OPEN && not emoji_path.is_empty()):
			_show_save_error("无法载入 Emoji 字体，请选择有效的字体文件，或留空使用默认字体。");
		else:
			_show_save_error("无法保存设置，请检查文件及存储目录的访问权限。\n" + error_string(error));
		return;
	confirmed.emit();

func _show_save_error(message : String, title : String = "设置保存失败") -> void:
	var dialog : AcceptDialog = AcceptDialog.new();
	dialog.theme = theme;
	dialog.title = title;
	dialog.dialog_text = message;
	dialog.ok_button_text = "确定";
	add_child(dialog);
	dialog.confirmed.connect(dialog.queue_free);
	dialog.canceled.connect(dialog.queue_free);
	dialog.popup_centered();
