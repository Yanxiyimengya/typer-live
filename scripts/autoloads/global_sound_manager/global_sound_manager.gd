extends AudioStreamPlayer;

func _ready() -> void:
	stream = AudioStreamPolyphonic.new();

func play_sound(s : AudioStream) -> void : 
	if (!s) : return;
	if (!self.playing) : 
		self.play();
	var playback : AudioStreamPlaybackPolyphonic = self.get_stream_playback();
	playback.play_stream(s);
	return;
