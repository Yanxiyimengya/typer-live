extends PanelContainer;

signal confirmed;

var file_dialog : FileDialog;
var path_field : LineEdit;

func _ready() -> void:
	var picker : ColorPicker = %FontColorButton.get_picker();
	%FontColorButton.get_popup().theme = get_window().theme;
	picker.edit_intensity = false;
	picker.picker_shape = ColorPicker.SHAPE_VHS_CIRCLE;
	picker.sampler_visible = false;
	picker.color_modes_visible = false;
	%FontOptionButton.add_item("文件字体");
	%FontOptionButton.set_item_metadata(0, "");
	var families : PackedStringArray = OS.get_system_fonts();
	families.sort();
	for family in families:
		%FontOptionButton.add_item(family);
		%FontOptionButton.set_item_metadata(%FontOptionButton.item_count - 1, family);
	%FontOptionButton.get_popup().theme = get_window().theme;
	%FontOptionButton.item_selected.connect(_select_font);
	file_dialog = %ResourceFileDialog;
	file_dialog.theme = get_window().theme;
	file_dialog.file_selected.connect(func(path : String): path_field.text = path);
	%FontBrowseButton.pressed.connect(_browse.bind(%FontPathEdit, PackedStringArray(["*.ttf,*.otf,*.ttc;字体"])));
	%EmojiFontBrowseButton.pressed.connect(_browse.bind(%EmojiFontPathEdit, PackedStringArray(["*.ttf,*.otf,*.ttc;字体"])));
	%EmojiFontResetButton.pressed.connect(func(): %EmojiFontPathEdit.text = GlobalSettings.DEFAULT_EMOJI_FONT_PATH);
	%VoiceBrowseButton.pressed.connect(_browse.bind(%VoicePathEdit, PackedStringArray(["*.wav,*.ogg,*.mp3;音效"])));
	%ConfirmButton.pressed.connect(_confirm);
	%FontResetButton.pressed.connect(_reset_font);
	%SizeResetButton.pressed.connect(func(): %FontSizeSpinBox.value = GlobalSettings.DEFAULT_FONT_SIZE);
	%ColorResetButton.pressed.connect(func(): %FontColorButton.color = GlobalSettings.DEFAULT_FONT_COLOR);
	%VoiceResetButton.pressed.connect(func(): %VoicePathEdit.text = GlobalSettings.DEFAULT_VOICE_PATH);
	%FadeOutResetButton.pressed.connect(func(): %FadeOutTimeSpinBox.value = GlobalSettings.DEFAULT_FADE_OUT_TIME);
	%SenderResetButton.pressed.connect(func(): %SenderNameEdit.text = GlobalSettings.DEFAULT_SENDER_NAME);
	%VoiceVolumeSlider.value_changed.connect(_update_volume_label);
	refresh();

func refresh() -> void:
	var selected : int = 0;
	for index in range(%FontOptionButton.item_count):
		if (%FontOptionButton.get_item_metadata(index) == GlobalSettings.font_family):
			selected = index;
			break;
	%FontOptionButton.select(selected);
	_select_font(selected);
	%FontPathEdit.text = GlobalSettings.font_path;
	%EmojiFontPathEdit.text = GlobalSettings.emoji_font_path;
	%FontSizeSpinBox.value = GlobalSettings.font_size;
	%FontColorButton.color = GlobalSettings.font_color;
	%VoicePathEdit.text = GlobalSettings.voice_path;
	%VoiceVolumeSlider.value = GlobalSettings.voice_volume;
	_update_volume_label(%VoiceVolumeSlider.value);
	%FadeOutTimeSpinBox.value = GlobalSettings.fade_out_time;
	%SenderNameEdit.text = GlobalSettings.sender_name;
	%BubbleSettings.refresh();

func _update_volume_label(value : float) -> void:
	%VoiceVolumeLabel.text = "%d%%" % int(value);

func _select_font(index : int) -> void:
	%FontPathEdit.get_parent().visible = index == 0;

func _reset_font() -> void:
	%FontOptionButton.select(0);
	_select_font(0);
	%FontPathEdit.text = GlobalSettings.DEFAULT_FONT_PATH;

func _browse(field : LineEdit, filters : PackedStringArray) -> void:
	path_field = field;
	file_dialog.filters = filters;
	file_dialog.popup_centered(Vector2i(900, 600));

func _confirm() -> void:
	var emoji_path : String = %EmojiFontPathEdit.text.strip_edges();
	if (not emoji_path.is_empty() && GlobalSettings.load_font(emoji_path) == null):
		_show_save_error("无法载入 Emoji 字体，请选择有效的字体文件，或留空使用默认字体。");
		return;
	var error : Error = GlobalSettings.apply_settings( \
		%FontPathEdit.text.strip_edges(), \
		int(%FontSizeSpinBox.value), \
		%FontColorButton.color, \
		%VoicePathEdit.text.strip_edges(), \
		%FontOptionButton.get_selected_metadata(), \
		%BubbleSettings.body_editor.get_data(), \
		%BubbleSettings.sender_editor.get_data(), \
		%FadeOutTimeSpinBox.value, \
		%SenderNameEdit.text, \
		%VoiceVolumeSlider.value, \
		%BubbleSettings.decoration_editor.get_data(), \
		emoji_path);
	if (error != OK):
		_show_save_error("无法保存设置，请检查文件及存储目录的访问权限。\n" + error_string(error));
		return;
	confirmed.emit();

func _show_save_error(message : String) -> void:
	var dialog : AcceptDialog = AcceptDialog.new();
	dialog.theme = theme;
	dialog.title = "设置保存失败";
	dialog.dialog_text = message;
	dialog.ok_button_text = "确定";
	add_child(dialog);
	dialog.confirmed.connect(dialog.queue_free);
	dialog.canceled.connect(dialog.queue_free);
	dialog.popup_centered();
