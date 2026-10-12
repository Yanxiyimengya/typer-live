extends PanelContainer;

var changer_func : Callable;
@onready var color_picker : ColorPicker = %ColorPicker;
func _ready() -> void:
	color_picker.color_changed.connect(_on_color_changed);

func show_picker() -> void :
	self.visible = not self.visible;

func hide_picker() -> void : 
	self.visible = false;
	color_picker.release_focus();

func _input(event : InputEvent) -> void :
	if (not visible || not (event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed)):
		return;
	var button : Control = get_parent();
	var mouse_position : Vector2 = get_canvas_transform().affine_inverse() * event.position;
	if (not get_global_rect().has_point(mouse_position) && not button.get_global_rect().has_point(mouse_position)):
		hide_picker();

func _on_color_changed(col : Color) -> void : 
	if (changer_func.is_valid()) : 
		changer_func.call(col);
