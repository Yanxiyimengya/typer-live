extends Node;

signal speech_started(utterance_id : int);
signal speech_finished(utterance_id : int);
signal speech_cancelled(utterance_id : int);

var _voices : Array[Dictionary] = [];
var _next_utterance_id : int = 1;

func _ready() -> void:
	refresh_voices();
	if (DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)):
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_STARTED, speech_started.emit);
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, speech_finished.emit);
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, speech_cancelled.emit);

func _exit_tree() -> void:
	stop();
	if (DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)):
		for event in [DisplayServer.TTS_UTTERANCE_STARTED, DisplayServer.TTS_UTTERANCE_ENDED, DisplayServer.TTS_UTTERANCE_CANCELED]:
			DisplayServer.tts_set_utterance_callback(event, Callable());

func refresh_voices() -> void:
	_voices = _get_system_voices();

func get_voices() -> Array[Dictionary]:
	return _voices.duplicate(true);

func is_available() -> bool:
	return not _voices.is_empty();

func select_voice(requested : String = "", language : String = "") -> String:
	for voice : Dictionary in _voices:
		if (str(voice.id) == requested):
			return requested;
	if (not language.is_empty()):
		var preferred_language : String = language.to_lower().replace("_", "-");
		for voice : Dictionary in _voices:
			if (str(voice.get("language", "")).to_lower().replace("_", "-") == preferred_language):
				return str(voice.id);
		for voice : Dictionary in _voices:
			if (str(voice.get("language", "")).to_lower().replace("_", "-").get_slice("-", 0) == preferred_language.get_slice("-", 0)):
				return str(voice.id);
	return str(_voices[0].id) if is_available() else "";

# All synthesis parameters come from the caller; no project settings or text markup are read here.
func speak(text : String, voice : String = "", volume : int = 100, rate : float = 1.0, pitch : float = 1.0, interrupt : bool = true) -> Error:
	if (text.strip_edges().is_empty()):
		return ERR_INVALID_PARAMETER;
	if (not is_available()):
		refresh_voices();
	if (not is_available()):
		return ERR_UNAVAILABLE;
	if (voice.is_empty()):
		voice = select_voice();
	elif (not _voices.any(func(item : Dictionary): return str(item.id) == voice)):
		return ERR_INVALID_PARAMETER;
	_speak_system(text, voice, clampi(volume, 0, 100), clampf(rate, 0.1, 10.0), clampf(pitch, 0.0, 2.0), _next_utterance_id, interrupt);
	_next_utterance_id += 1;
	return OK;

func stop() -> void:
	_stop_system();

func _get_system_voices() -> Array[Dictionary]:
	if (not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)):
		return [];
	return DisplayServer.tts_get_voices();

func _speak_system(text : String, voice : String, volume : int, rate : float, pitch : float, utterance_id : int, interrupt : bool) -> void:
	DisplayServer.tts_speak(text, voice, volume, pitch, rate, utterance_id, interrupt);

func _stop_system() -> void:
	if (DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)):
		DisplayServer.tts_stop();
