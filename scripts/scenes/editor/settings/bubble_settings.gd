extends HBoxContainer;

@onready var body_editor : VBoxContainer = $StyleTabs/BodyEditor;
@onready var sender_editor : VBoxContainer = $StyleTabs/SenderEditor;
@onready var preview : DialogBubble = $PreviewColumn/Frame/AspectRatioContainer/SubViewportContainer/SubViewport/DialogBubble;

func _ready() -> void:
	preview.set_process(false);
	body_editor.style_changed.connect(_update_preview);
	sender_editor.style_changed.connect(_update_preview);
	refresh();

func refresh() -> void:
	body_editor.set_data(GlobalSettings.bubble_style);
	sender_editor.set_data(GlobalSettings.sender_style);
	_update_preview();

func _update_preview() -> void:
	preview.apply_bubble_styles(body_editor.get_data(), sender_editor.get_data());
