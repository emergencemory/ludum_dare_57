extends CanvasLayer
class_name Menu

@onready var resume: Button = $MenuDivider/TitleScreen/GameControls/Resume
@onready var action_list: VBoxContainer = $MenuDivider/TitleScreen/ControlContainer/Controls/ActionList
@onready var quit: Button = $MenuDivider/TitleScreen/GameControls/Quit
@onready var touchscreen_toggle: CheckButton = $MenuDivider/TitleScreen/ControlContainer/Controls/TouchscreenToggle

var resume_modulate : float

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SignalBus.hide_hud.connect(_on_hide)
	if OS.get_name() != "Web":
		quit.show()

func _on_start_pressed() -> void:
	SignalBus.start_game.emit()
	resume.show()

func _on_resume_pressed() -> void:
	SignalBus.emit_signal("change_pause")

func _on_hide(hidden : bool) -> void:
	##If the HUD is hidden, flash the resume button to indicate that the game is paused
	if hidden:
		set_physics_process(true)
	else:
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	##If the HUD is hidden, flash the resume button to indicate that the game is paused
	if resume.is_visible():
		resume.modulate.r = sin(resume_modulate)
		resume_modulate += delta*3
	else:
		set_physics_process(false)

func _on_touchscreen_toggle_toggled(toggled_on : bool) -> void:
	if toggled_on:
		SignalBus.touchscreen_toggled.emit(true)
	else:
		SignalBus.touchscreen_toggled.emit(false)

func _on_fullscreen_toggled(toggled_on : bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_sfx_volume_value_changed(value:float) -> void:
	SignalBus.sfx_volume_slider_changed.emit(value)

func _on_music_volume_value_changed(value:float) -> void:
	SignalBus.music_volume_slider_changed.emit(value)

func _on_quit_pressed() -> void:
	SignalBus.quit_game.emit()
