class_name SkillTreeResetConfirmation
extends PanelContainer

signal confirmed
signal cancelled

@onready var title_label: RichTextLabel = %Title
@onready var message_label: RichTextLabel = %Message
@onready var summary_label: RichTextLabel = %Summary
@onready var refund_title_label: Label = %RefundTitle
@onready var refund_list: VBoxContainer = %RefundList
@onready var cancel_button: Button = %Cancel
@onready var confirm_button: Button = %Confirm

func _ready() -> void:
	cancel_button.pressed.connect(func(): cancelled.emit())
	confirm_button.pressed.connect(func(): confirmed.emit())

func present(title: String, message: String, summary: Dictionary, refund_title: String, cancel_text: String, confirm_text: String) -> void:
	title_label.text = title
	message_label.text = message
	refund_title_label.text = refund_title
	for child in refund_list.get_children():
		child.queue_free()
	for entry in summary.get("entries", []):
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.text = "[color=#e56a6a][s]%d %s[/s][/color]  →  %d %s" % [entry.spent, entry.currency, entry.refund, entry.currency]
		refund_list.add_child(line)
	summary_label.visible = false
	cancel_button.text = cancel_text
	confirm_button.text = confirm_text
	show()
