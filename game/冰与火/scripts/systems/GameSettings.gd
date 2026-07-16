extends Node

signal settings_changed

const DEFAULT_CONFIG_PATH := "user://settings.cfg"
const DEFAULT_BATTLE_ANIMATIONS := true
const DEFAULT_AUTO_CAMERA := true
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_FULLSCREEN := false

var config_path: String = DEFAULT_CONFIG_PATH
var battle_animations_enabled: bool = DEFAULT_BATTLE_ANIMATIONS
var auto_camera_enabled: bool = DEFAULT_AUTO_CAMERA
var master_volume: float = DEFAULT_MASTER_VOLUME
var fullscreen_enabled: bool = DEFAULT_FULLSCREEN

func _ready() -> void:
	load_settings()

func load_settings(apply_runtime: bool = true) -> void:
	var config := ConfigFile.new()
	if config.load(config_path) == OK:
		battle_animations_enabled = bool(config.get_value(
			"gameplay", "battle_animations", DEFAULT_BATTLE_ANIMATIONS))
		auto_camera_enabled = bool(config.get_value(
			"gameplay", "auto_camera", DEFAULT_AUTO_CAMERA))
		master_volume = clampf(float(config.get_value(
			"audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
		fullscreen_enabled = bool(config.get_value(
			"display", "fullscreen", DEFAULT_FULLSCREEN))
	if apply_runtime:
		apply_runtime_settings()

func save_settings(apply_runtime: bool = true) -> void:
	master_volume = clampf(master_volume, 0.0, 1.0)
	var config := ConfigFile.new()
	config.set_value("gameplay", "battle_animations", battle_animations_enabled)
	config.set_value("gameplay", "auto_camera", auto_camera_enabled)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen_enabled)
	config.save(config_path)
	if apply_runtime:
		apply_runtime_settings()
	settings_changed.emit()

func reset_to_defaults(apply_runtime: bool = true) -> void:
	battle_animations_enabled = DEFAULT_BATTLE_ANIMATIONS
	auto_camera_enabled = DEFAULT_AUTO_CAMERA
	master_volume = DEFAULT_MASTER_VOLUME
	fullscreen_enabled = DEFAULT_FULLSCREEN
	save_settings(apply_runtime)

func clear_saved_settings() -> void:
	if FileAccess.file_exists(config_path):
		DirAccess.remove_absolute(config_path)

func apply_runtime_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus,
			linear_to_db(master_volume) if master_volume > 0.0 else -80.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if fullscreen_enabled
			else DisplayServer.WINDOW_MODE_WINDOWED)
