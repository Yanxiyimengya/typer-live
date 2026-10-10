extends PanelContainer;

signal confirmed;

var file_dialog : FileDialog;
var path_field : LineEdit;

func _ready() -> void:
	var picker : ColorPicker = %FontColorButton.get_picker();
	%FontColorButton.get_popup().theme = get_window().theme;
	picker.edit_intensity = false;
	picker.picker_shape = 2;
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
	%VoiceBrowseButton.pressed.connect(_browse.bind(%VoicePathEdit, PackedStringArray(["*.wav,*.ogg,*.mp3;音效"])));
	%ConfirmButton.pressed.connect(_confirm);
	%FontResetButton.pressed.connect(_reset_font);
	%SizeResetButton.pressed.connect(func(): %FontSizeSpinBox.value = GlobalSettings.DEFAULT_FONT_SIZE);
	%ColorResetButton.pressed.connect(func(): %FontColorButton.color = GlobalSettings.DEFAULT_FONT_COLOR);
	%VoiceResetButton.pressed.connect(func(): %VoicePathEdit.text = GlobalSettings.DEFAULT_VOICE_PATH);
	%FadeOutResetButton.pressed.connect(func(): %FadeOutTimeSpinBox.value = GlobalSettings.DEFAULT_FADE_OUT_TIME);
	refresh();

func refresh() -> void:
	var selected : int = 0;
	for index in range(%FontOptionButton.item_count):
		if %FontOptionButton.get_item_metadata(index) == GlobalSettings.font_family:
			selected = index;
			break;
	%FontOptionButton.select(selected);
	_select_font(selected);
	%FontPathEdit.text = GlobalSettings.font_path;
	%FontSizeSpinBox.value = GlobalSettings.font_size;
	%FontColorButton.color = GlobalSettings.font_color;
	%VoicePathEdit.text = GlobalSettings.voice_path;
	%FadeOutTimeSpinBox.value = GlobalSettings.fade_out_time;
	%BubbleSettings.refresh();

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
	GlobalSettings.apply_settings(%FontPathEdit.text.strip_edges(), int(%FontSizeSpinBox.value), %FontColorButton.color, %VoicePathEdit.text.strip_edges(), %FontOptionButton.get_selected_metadata(), %BubbleSettings.body_editor.get_data(), %BubbleSettings.sender_editor.get_data(), %FadeOutTimeSpinBox.value);
	confirmed.emit();
