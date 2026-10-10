extends VBoxContainer;

signal style_changed;

@export var edit_sender : bool = false;

var defaults : Dictionary;
var data : Dictionary;
@onready var mode_button : OptionButton = %ModeButton;
@onready var path_edit : LineEdit = %TexturePathEdit;
@onready var file_dialog : FileDialog = %TextureFileDialog;
@onready var flat_fields : VBoxContainer = %FlatFields;
@onready var texture_fields : VBoxContainer = %TextureFields;
var _fields : Dictionary = {};
var _loading : bool = false;

func _ready() -> void:
	defaults = (GlobalSettings.DEFAULT_SENDER_STYLE if edit_sender else GlobalSettings.DEFAULT_BUBBLE_STYLE).duplicate(true);
	%Decorations.visible = not edit_sender;
	mode_button.get_popup().theme = get_window().theme;
	file_dialog.theme = get_window().theme;
	mode_button.item_selected.connect(func(index : int): _update("mode", index));
	%ResetStyleButton.pressed.connect(func(): set_data(defaults); style_changed.emit());
	path_edit.text_submitted.connect(func(_text : String): _update("texture_path", path_edit.text));
	path_edit.focus_exited.connect(func(): _update("texture_path", path_edit.text));
	%BrowseButton.pressed.connect(file_dialog.popup_centered.bind(Vector2i(900, 600)));
	file_dialog.file_selected.connect(func(path : String): path_edit.text = path; _update("texture_path", path));
	for control : Node in find_children("*", "", true, false):
		if not control.has_meta("style_key"):
			continue;
		var key : String = control.get_meta("style_key");
		if key == "decorations" and edit_sender:
			continue;
		if control.has_meta("side"):
			var side : int = control.get_meta("side");
			if not _fields.has(key):
				_fields[key] = [];
			_fields[key].append(control);
			control.value_changed.connect(_update_side.bind(key, side));
		else:
			_fields[key] = control;
			if control is ColorPickerButton:
				control.get_popup().theme = get_window().theme;
				var picker : ColorPicker = control.get_picker();
				picker.picker_shape = 2;
				picker.color_modes_visible = false;
				picker.sampler_visible = false;
				control.color_changed.connect(func(color : Color): _update(key, color));
			elif control is SpinBox:
				control.value_changed.connect(func(value : float): _update(key, value));
			elif control is CheckBox:
				control.toggled.connect(func(value : bool): _update(key, value));
	set_data(defaults);

func _update_side(value : float, key : String, side : int) -> void:
	if not _loading:
		data[key][side] = value;
		style_changed.emit();

func set_data(value : Dictionary) -> void:
	_loading = true;
	data = defaults.duplicate(true);
	data.merge(value.duplicate(true), true);
	mode_button.select(int(data.mode));
	path_edit.text = data.texture_path;
	for key : String in _fields:
		var control : Variant = _fields[key];
		if control is Array:
			for side in range(4):
				control[side].set_value_no_signal(data[key][side]);
		elif control is ColorPickerButton:
			control.color = data[key];
		elif control is CheckBox:
			control.set_pressed_no_signal(data[key]);
		elif key == "shadow_x" or key == "shadow_y":
			control.set_value_no_signal(data.shadow_offset.x if key == "shadow_x" else data.shadow_offset.y);
		else:
			control.set_value_no_signal(data[key]);
	flat_fields.visible = int(data.mode) == 0;
	texture_fields.visible = int(data.mode) == 2;
	_loading = false;

func get_data() -> Dictionary:
	data.texture_path = path_edit.text.strip_edges();
	return data.duplicate(true);

func _update(key : String, value : Variant) -> void:
	if _loading:
		return;
	if key == "shadow_x":
		data.shadow_offset.x = value;
	elif key == "shadow_y":
		data.shadow_offset.y = value;
	else:
		data[key] = value;
	flat_fields.visible = int(data.mode) == 0;
	texture_fields.visible = int(data.mode) == 2;
	style_changed.emit();
