extends Node;

signal history_changed;

const SAVE_PATH : String = "user://image_history.cfg";
const MAX_HISTORY : int = 50;

var resource_cache : Dictionary[String, Resource] = {};
var image_history : Array[String] = [];
var _image_jobs : Dictionary[String, Dictionary] = {};

func _ready() -> void:
	load_history();

func load_history() -> void:
	var config : ConfigFile = ConfigFile.new();
	image_history.clear();
	if config.load(SAVE_PATH) != OK:
		return;
	for path : String in config.get_value("gallery", "images", PackedStringArray()):
		var key : String = _cache_key(path);
		if not image_history.has(key):
			image_history.append(key);
		if image_history.size() == MAX_HISTORY:
			break;

func save_history() -> void:
	var config : ConfigFile = ConfigFile.new();
	config.set_value("gallery", "images", PackedStringArray(image_history));
	config.save(SAVE_PATH);

func remember_image(path : String) -> void:
	var key : String = _cache_key(path);
	image_history.erase(key);
	image_history.push_front(key);
	while image_history.size() > MAX_HISTORY:
		remove_resource(image_history.pop_back());
	save_history();
	history_changed.emit();

func remove_image(path : String) -> void:
	var key : String = _cache_key(path);
	image_history.erase(key);
	remove_resource(key);
	save_history();
	history_changed.emit();

func load_image(path : String) -> ImageTexture:
	var key : String = _cache_key(path);
	if resource_cache.has(key):
		return resource_cache[key] as ImageTexture;
	var image : Image = Image.load_from_file(key);
	if image == null or image.is_empty():
		return null;
	var texture : ImageTexture = ImageTexture.create_from_image(image);
	resource_cache[key] = texture;
	return texture;

func load_image_async(path : String) -> ImageTexture:
	var key : String = _cache_key(path);
	if resource_cache.has(key):
		return resource_cache[key] as ImageTexture;
	if not _image_jobs.has(key):
		var result : Array[Image] = [];
		var task : int = WorkerThreadPool.add_task(func(): result.append(Image.load_from_file(key)));
		_image_jobs[key] = {"task": task, "result": result, "cancelled": false, "finished": false, "texture": null};
	var job : Dictionary = _image_jobs[key];
	while not job.finished and not WorkerThreadPool.is_task_completed(job.task):
		await get_tree().process_frame;
	if job.finished:
		return null if job.cancelled else job.texture;
	WorkerThreadPool.wait_for_task_completion(job.task);
	job.finished = true;
	if _image_jobs.has(key) and _image_jobs[key].task == job.task:
		_image_jobs.erase(key);
	if job.cancelled:
		return null;
	if resource_cache.has(key):
		job.texture = resource_cache[key] as ImageTexture;
		return job.texture;
	var image : Image = job.result[0];
	if image == null or image.is_empty():
		return null;
	var texture : ImageTexture = ImageTexture.create_from_image(image);
	resource_cache[key] = texture;
	job.texture = texture;
	return texture;

func remove_resource(path : String) -> void:
	var key : String = _cache_key(path);
	resource_cache.erase(key);
	if _image_jobs.has(key):
		_image_jobs[key].cancelled = true;
		_image_jobs.erase(key);

func clear_cache() -> void:
	resource_cache.clear();
	for job : Dictionary in _image_jobs.values():
		job.cancelled = true;
	_image_jobs.clear();

func _cache_key(path : String) -> String:
	return ProjectSettings.globalize_path(path.replace("\\", "/")).simplify_path();
