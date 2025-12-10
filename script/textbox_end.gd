extends CanvasLayer

const CHAR_READ_RATE := 0.05

@onready var textbox_container: Control = $textboxContainer
@onready var start_symbol: Label = $textboxContainer/MarginContainer/HBoxContainer/start
@onready var end_symbol: Label = $textboxContainer/MarginContainer/HBoxContainer/end
@onready var label: Label = $textboxContainer/MarginContainer/HBoxContainer/Label2

# Optional: allow auto-start for testing in the editor, default false so it doesn't show on run
@export var auto_start: bool = false
@export var auto_texts: Array = []

# Text queue / state
var texts: Array = []
var current_index: int = 0
var current_text: String = ""
var is_typing: bool = false
var typing_done: bool = false

func _ready() -> void:
	hide_textbox()
	if auto_start and auto_texts.size() > 0:
		start_texts(auto_texts)

# ... (rest unchanged) ...
func _unhandled_input(event: InputEvent) -> void:
	# Use the action 'ui_accept' (Enter/Space by default).
	if event.is_action_pressed("ui_accept"):
		if is_typing:
			# finish immediately: reveal full text
			label.text = current_text
			is_typing = false
			typing_done = true
			if end_symbol:
				end_symbol.text = "v"
		elif typing_done:
			# proceed to next text or close if none left
			current_index += 1
			_show_next_or_close()

func start_texts(text_array: Array) -> void:
	texts = text_array.duplicate()
	current_index = 0
	_show_next_or_close()

func _show_next_or_close() -> void:
	if current_index >= texts.size():
		hide_textbox()
		return
	current_text = texts[current_index]
	typing_done = false
	add_text(current_text)

func hide_textbox() -> void:
	if textbox_container:
		textbox_container.hide()
	if start_symbol:
		start_symbol.text = ""
	if end_symbol:
		end_symbol.text = ""
	if label:
		label.text = ""
	is_typing = false
	typing_done = false

func show_textbox() -> void:
	if start_symbol:
		start_symbol.text = "*"
	if end_symbol:
		end_symbol.text = ""
	if textbox_container:
		textbox_container.show()

func add_text(next_text: String) -> void:
	if not label:
		push_error("Label (Label2) not found")
		return
	show_textbox()
	label.text = ""
	is_typing = true
	typing_done = false

	for i in range(next_text.length()):
		if not is_typing:
			break
		label.text = next_text.substr(0, i + 1)
		await get_tree().create_timer(CHAR_READ_RATE).timeout

	label.text = next_text
	is_typing = false
	typing_done = true
	if end_symbol:
		end_symbol.text = "v"
