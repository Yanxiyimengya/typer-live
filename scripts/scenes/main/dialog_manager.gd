class_name GlobalDialogManager;
extends Node;

## 当信息发送时触发一次
signal dialog_sending(text : DialogMessage);

static var _instance : GlobalDialogManager = null;
var _dialog_list : Array[DialogMessage] = [];

func _enter_tree() -> void:
	if (_instance != null && is_instance_valid(_instance)) : 
		self.queue_free();
		return;
	_instance = self;

func _exit_tree() -> void:
	_instance = null;

func get_instance() -> GlobalDialogManager : 
	return _instance;

func send(text : String) -> void : 
	if (text.is_empty()) : 
		return;
	var _inst : DialogMessage = DialogMessage.new();
	_inst.text = text;
	dialog_sending.emit(_inst);
	_dialog_list.push_back(_inst);
