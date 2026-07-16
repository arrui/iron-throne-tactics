class_name SettingsMenu
extends CanvasLayer

signal closed

@onready var _battle_animations: CheckButton = $Dimmer/Panel/Margin/Content/BattleAnimations
@onready var _auto_camera: CheckButton = $Dimmer/Panel/Margin/Content/AutoCamera
@onready var _master_volume: HSlider = $Dimmer/Panel/Margin/Content/MasterVolume
@onready var _volume_value: Label = $Dimmer/Panel/Margin/Content/VolumeValue
@onready var _fullscreen: CheckButton = $Dimmer/Panel/Margin/Content/Fullscreen
@onready var _defaults: Button = $Dimmer/Panel/Margin/Content/Buttons/Defaults
@onready var _close: Button = $Dimmer/Panel/Margin/Content/Buttons/Close

var _settings: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_settings = get_node_or_null("/root/GameSettings")
	if _settings == null:
		_settings = load("res://scripts/systems/GameSettings.gd").new()
		_settings.load_settings(false)
	_sync_controls()
	_master_volume.value_changed.connect(_on_volume_changed)
	_defaults.pressed.connect(_on_defaults_pressed)
	_close.pressed.connect(close)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if _settings != null:
		_settings.battle_animations_enabled = _battle_animations.button_pressed
		_settings.auto_camera_enabled = _auto_camera.button_pressed
		_settings.master_volume = float(_master_volume.value) / 100.0
		_settings.fullscreen_enabled = _fullscreen.button_pressed
		_settings.save_settings()
	closed.emit()
	queue_free()

func _sync_controls() -> void:
	_battle_animations.button_pressed = _settings.battle_animations_enabled
	_auto_camera.button_pressed = _settings.auto_camera_enabled
	_master_volume.value = _settings.master_volume * 100.0
	_fullscreen.button_pressed = _settings.fullscreen_enabled
	_update_volume_label()

func _on_volume_changed(_value: float) -> void:
	_update_volume_label()

func _update_volume_label() -> void:
	_volume_value.text = "主音量：%d%%" % int(round(_master_volume.value))

func _on_defaults_pressed() -> void:
	_settings.reset_to_defaults()
	_sync_controls()
