extends AudioStreamPlayer;

func _ready() -> void:
	stream = AudioStreamPolyphonic.new();
	GlobalSettings.settings_changed.connect(_apply_settings);
	_apply_settings();

func _apply_settings() -> void:
	volume_linear = GlobalSettings.voice_volume / 100.0;

func play_sound(s : AudioStream) -> void : 
	if (!s) : return;
	if (!self.playing) : 
		self.play();
	var playback : AudioStreamPlaybackPolyphonic = self.get_stream_playback();
	playback.play_stream(s);
	return;
