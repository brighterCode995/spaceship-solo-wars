class_name UITheme
extends RefCounted
## Builds the shared sci-fi UI theme in code so no theme resource file is needed.

const ACCENT := Color(0.3, 0.85, 1.0)
const PANEL_BG := Color(0.03, 0.06, 0.14, 0.92)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 36

	theme.set_stylebox("normal", "Button", _box(Color(0.08, 0.16, 0.3, 0.92), ACCENT, 3, 16, 28, 14))
	theme.set_stylebox("hover", "Button", _box(Color(0.12, 0.26, 0.48, 0.96), Color(0.7, 0.96, 1.0), 3, 16, 28, 14))
	theme.set_stylebox("pressed", "Button", _box(Color(0.2, 0.5, 0.75, 1.0), Color.WHITE, 3, 16, 28, 14))
	theme.set_stylebox("focus", "Button", _box(Color(0.12, 0.26, 0.48, 0.96), Color(0.7, 0.96, 1.0), 3, 16, 28, 14))
	theme.set_stylebox("disabled", "Button", _box(Color(0.1, 0.1, 0.14, 0.7), Color(0.4, 0.4, 0.5), 2, 16, 28, 14))
	theme.set_font_size("font_size", "Button", 40)
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)

	theme.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, ACCENT, 3, 24, 48, 36))

	theme.set_stylebox("background", "ProgressBar", _box(Color(0.0, 0.0, 0.0, 0.55), Color(1, 1, 1, 0.35), 2, 8, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, ACCENT, 0, 8, 0, 0))
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	theme.set_constant("outline_size", "Label", 6)
	return theme


static func _box(bg: Color, border: Color, border_width: int, radius: int, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box
