extends TabContainer;

@onready var body_editor : VBoxContainer = $Styles/StyleTabs/BodyEditor;
@onready var sender_editor : VBoxContainer = $Styles/StyleTabs/SenderEditor;
@onready var preview : DialogBubble = $Styles/PreviewColumn/Frame/AspectRatioContainer/SubViewportContainer/SubViewport/DialogBubble;

@onready var decoration_editor : Container = $Decorations;

func _ready() -> void:
	preview.set_process(false);
	body_editor.style_changed.connect(_update_preview);
	sender_editor.style_changed.connect(_update_preview);
	decoration_editor.decorations_changed.connect(_update_preview);
	refresh();

func refresh() -> void:
	body_editor.set_data(GlobalSettings.bubble_style);
	sender_editor.set_data(GlobalSettings.sender_style);
	decoration_editor.set_data(GlobalSettings.decoration_items);
	_update_preview();

func _update_preview() -> void:
	preview.apply_bubble_styles(body_editor.get_data(), sender_editor.get_data());

	preview.apply_item_decorations(decoration_editor.get_data());
	decoration_editor.set_styles(body_editor.get_data(), sender_editor.get_data());
