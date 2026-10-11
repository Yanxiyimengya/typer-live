extends Control;

var fading_animation_player: AnimationPlayer = null;
var dialog_bubble : DialogBubble = null;

var fade_out_time : float = GlobalSettings.DEFAULT_FADE_OUT_TIME;
var _fade_out_timer : float = 0.0;
var _fading : bool = false;

const FADE_IN_ANIM : StringName = &"fade_in";
const FADE_OUT_ANIM : StringName = &"fade_out";

func _ready() -> void:
	dialog_bubble = self.get_node("%DialogBubble");
	fading_animation_player = self.get_node("%FadingAnimationPlayer");
	fading_animation_player.set_root("%AnimTranslate");
	GlobalSettings.settings_changed.connect(_apply_settings);
	_apply_settings();

func _apply_settings() -> void:
	if (fade_out_time != GlobalSettings.fade_out_time):
		fade_out_time = GlobalSettings.fade_out_time;
		if (visible && not _fading):
			_fade_out_timer = fade_out_time;

func _process(delta: float) -> void:
	if (visible) : 
		if (dialog_bubble.is_completed()) : 
			if (_fade_out_timer > 0) : 
				_fade_out_timer -= delta;
			elif (!_fading) : 
				_fade_out_timer = 0;
				_fading = true;
				fading_animation_player.play(FADE_OUT_ANIM);
				await fading_animation_player.animation_finished;
				visible = false;
				_fading = false;
	else : 
		pass;
	
func print_text(s : String, t : String) -> void : 
	dialog_bubble.print_text(s, "");
	visible = true;
	_fading = true;
	fading_animation_player.play(FADE_IN_ANIM);
	await fading_animation_player.animation_finished;
	_fading = false;
	_fade_out_timer = fade_out_time;
	dialog_bubble.print_text(s, t);
