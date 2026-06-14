extends Control

const PALETTE_COLORS: Array[Color] = [
	Color(1, 0, 0), Color(1, 0.5, 0), Color(1, 1, 0), Color(0.5, 1, 0),
	Color(0, 1, 0), Color(0, 1, 0.5), Color(0, 1, 1), Color(0, 0.5, 1),
	Color(0, 0, 1), Color(0.5, 0, 1), Color(1, 0, 1), Color(1, 0, 0.5),
	Color(1, 0.7, 0.7), Color(0.7, 1, 0.7), Color(0.7, 0.7, 1), Color(1, 1, 0.7),
	Color(1, 0.85, 0.7), Color(0.7, 0.9, 1), Color(0.9, 0.7, 1), Color(1, 0.7, 0.9),
	Color(0.55, 0.27, 0.07), Color(0.82, 0.62, 0.42), Color(0.7, 0.7, 0.7), Color(0.1, 0.1, 0.1),
]

var canvas_image: Image = null
var coloring_image: Image = null
var canvas_texture: ImageTexture = null
var selected_color: Color = Color(1, 0.4, 0.4)
var outline_threshold: float = 0.2

var texture_rect: TextureRect
var palette_grid: GridContainer
var image_colors_grid: GridContainer
var selected_display: ColorRect
var threshold_label: Label
var zoom_label: Label
var status_label: Label
var file_dialog: FileDialog
var scroll_container: ScrollContainer
var pbn_active: bool = false
var pbn_overlay: Control = null
var image_colors_cache: Array[Color] = []
var pbn_regions: Array = []
var zoom_level: float = 1.0

func _ready() -> void:
	_build_ui()
	_populate_palette()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size.y = 44
	toolbar.add_theme_constant_override("separation", 8)
	vbox.add_child(toolbar)

	_make_button(toolbar, "Load Image", _on_load_pressed)
	_make_button(toolbar, "Reset Colors", _on_clear_pressed)
	_make_button(toolbar, "Save PNG", _on_save_pressed)

	var pbn_btn := Button.new()
	pbn_btn.text = "Paint by Numbers"
	pbn_btn.toggle_mode = true
	pbn_btn.toggled.connect(_on_pbn_toggled)
	toolbar.add_child(pbn_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var tl := Label.new()
	tl.text = "Edge Sensitivity:"
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(tl)

	var slider := HSlider.new()
	slider.min_value = 0.05
	slider.max_value = 0.95
	slider.step = 0.05
	slider.value = outline_threshold
	slider.custom_minimum_size = Vector2(160, 0)
	slider.value_changed.connect(_on_threshold_changed)
	toolbar.add_child(slider)

	threshold_label = Label.new()
	threshold_label.text = "%.2f" % outline_threshold
	threshold_label.custom_minimum_size.x = 44
	threshold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(threshold_label)

	var zoom_sep := VSeparator.new()
	toolbar.add_child(zoom_sep)

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "−"
	zoom_out_btn.pressed.connect(_zoom_by.bind(0.8))
	toolbar.add_child(zoom_out_btn)

	zoom_label = Label.new()
	zoom_label.text = "100%"
	zoom_label.custom_minimum_size.x = 52
	zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(zoom_label)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.pressed.connect(_zoom_by.bind(1.25))
	toolbar.add_child(zoom_in_btn)

	var fit_btn := Button.new()
	fit_btn.text = "Fit"
	fit_btn.pressed.connect(_fit_image_to_view)
	toolbar.add_child(fit_btn)

	# Main split: canvas left, palette right
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hsplit)

	# Canvas scroll area
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.resized.connect(_fit_image_to_view)
	hsplit.add_child(scroll_container)

	texture_rect = TextureRect.new()
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	texture_rect.gui_input.connect(_on_canvas_input)
	scroll_container.add_child(texture_rect)

	# Right panel — scrollable so both palettes always fit
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(212, 0)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hsplit.add_child(right_scroll)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right)

	var palette_title := Label.new()
	palette_title.text = "Color Palette"
	palette_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(palette_title)
	right.add_child(HSeparator.new())

	var sel_row := HBoxContainer.new()
	right.add_child(sel_row)
	var sl := Label.new()
	sl.text = "Active Color:"
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_row.add_child(sl)
	selected_display = ColorRect.new()
	selected_display.color = selected_color
	selected_display.custom_minimum_size = Vector2(56, 28)
	sel_row.add_child(selected_display)

	right.add_child(HSeparator.new())

	palette_grid = GridContainer.new()
	palette_grid.columns = 4
	palette_grid.add_theme_constant_override("h_separation", 4)
	palette_grid.add_theme_constant_override("v_separation", 4)
	right.add_child(palette_grid)

	right.add_child(HSeparator.new())

	var img_colors_label := Label.new()
	img_colors_label.text = "Image Colors"
	img_colors_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(img_colors_label)

	image_colors_grid = GridContainer.new()
	image_colors_grid.columns = 4
	image_colors_grid.add_theme_constant_override("h_separation", 4)
	image_colors_grid.add_theme_constant_override("v_separation", 4)
	right.add_child(image_colors_grid)

	right.add_child(HSeparator.new())

	status_label = Label.new()
	status_label.text = "Load an image to start painting!"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(status_label)

	# File dialog (shared, mode switches per use)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.size = Vector2i(900, 600)
	add_child(file_dialog)

func _make_button(parent: Node, label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func _populate_palette() -> void:
	for color: Color in PALETTE_COLORS:
		var swatch := ColorRect.new()
		swatch.color = color
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		swatch.gui_input.connect(_on_swatch_input.bind(color))
		palette_grid.add_child(swatch)
	_update_swatch_highlights()

func _on_swatch_input(event: InputEvent, color: Color) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_color = color
		selected_display.color = color
		_update_swatch_highlights()
		status_label.text = "Color: #" + color.to_html(false)

func _update_swatch_highlights() -> void:
	for grid in [palette_grid, image_colors_grid]:
		for child in grid.get_children():
			if child is ColorRect:
				child.modulate = Color(1.5, 1.5, 1.5) if child.color.is_equal_approx(selected_color) else Color.WHITE

func _on_load_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.bmp,*.webp ; Images"])
	if not file_dialog.file_selected.is_connected(_on_file_selected):
		file_dialog.file_selected.connect(_on_file_selected)
	_disconnect_signal_if_connected(file_dialog.file_selected, _on_save_path_selected)
	file_dialog.popup_centered()

func _on_save_pressed() -> void:
	if coloring_image == null:
		status_label.text = "Nothing to save yet."
		return
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = PackedStringArray(["*.png ; PNG Image"])
	if not file_dialog.file_selected.is_connected(_on_save_path_selected):
		file_dialog.file_selected.connect(_on_save_path_selected)
	_disconnect_signal_if_connected(file_dialog.file_selected, _on_file_selected)
	file_dialog.popup_centered()

func _disconnect_signal_if_connected(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)

func _on_file_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		status_label.text = "Failed to load: " + path.get_file()
		return
	canvas_image = img
	_apply_coloring_book_style()
	var colors: Array[Color] = _extract_image_colors(canvas_image)
	_populate_image_palette(colors)
	pbn_regions.clear()
	call_deferred("_fit_image_to_view")
	if pbn_active:
		call_deferred("_build_pbn_overlay")
	status_label.text = "Loaded! Click areas to paint."

func _on_save_path_selected(path: String) -> void:
	if not path.ends_with(".png"):
		path += ".png"
	var err := coloring_image.save_png(path)
	if err == OK:
		status_label.text = "Saved to:\n" + path.get_file()
	else:
		status_label.text = "Save failed (error %d)" % err

func _apply_coloring_book_style() -> void:
	if canvas_image == null:
		return
	var src: Image = canvas_image.duplicate()
	src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()

	# Precompute per-channel arrays — faster than repeated get_pixel calls and
	# needed for per-channel Sobel which catches iso-luminant edges (red vs green etc.)
	var chan_r: PackedFloat32Array = PackedFloat32Array()
	var chan_g: PackedFloat32Array = PackedFloat32Array()
	var chan_b: PackedFloat32Array = PackedFloat32Array()
	var chan_a: PackedFloat32Array = PackedFloat32Array()
	chan_r.resize(w * h); chan_g.resize(w * h)
	chan_b.resize(w * h); chan_a.resize(w * h)
	for y in h:
		for x in w:
			var c: Color = src.get_pixel(x, y)
			var idx: int = y * w + x
			chan_r[idx] = c.r; chan_g[idx] = c.g
			chan_b[idx] = c.b; chan_a[idx] = c.a

	# Pass 1 — per-channel Sobel: run on R, G, B separately and take max magnitude
	const KX: Array[int] = [-1, 0, 1, -2, 0, 2, -1, 0, 1]
	const KY: Array[int] = [-1, -2, -1, 0, 0, 0, 1, 2, 1]
	var edge_map: PackedByteArray = PackedByteArray()
	edge_map.resize(w * h)
	for y in h:
		for x in w:
			var gx_r: float = 0.0; var gy_r: float = 0.0
			var gx_g: float = 0.0; var gy_g: float = 0.0
			var gx_b: float = 0.0; var gy_b: float = 0.0
			var ki: int = 0
			for ky in range(-1, 2):
				for kx in range(-1, 2):
					var idx: int = clampi(y + ky, 0, h - 1) * w + clampi(x + kx, 0, w - 1)
					var wx: int = KX[ki]; var wy: int = KY[ki]
					gx_r += chan_r[idx] * wx; gy_r += chan_r[idx] * wy
					gx_g += chan_g[idx] * wx; gy_g += chan_g[idx] * wy
					gx_b += chan_b[idx] * wx; gy_b += chan_b[idx] * wy
					ki += 1
			var mag: float = maxf(maxf(
					sqrt(gx_r * gx_r + gy_r * gy_r),
					sqrt(gx_g * gx_g + gy_g * gy_g)),
					sqrt(gx_b * gx_b + gy_b * gy_b)) / 4.0
			edge_map[y * w + x] = 1 if mag > outline_threshold else 0

	# Pass 2 — dilate edges by 1 pixel to seal anti-aliasing gaps that let flood fill bleed
	var dilated: PackedByteArray = edge_map.duplicate()
	for y in h:
		for x in w:
			if edge_map[y * w + x] == 0:
				continue
			if x > 0: dilated[y * w + x - 1] = 1
			if x < w - 1: dilated[y * w + x + 1] = 1
			if y > 0: dilated[(y - 1) * w + x] = 1
			if y < h - 1: dilated[(y + 1) * w + x] = 1

	# Pass 3 — write final coloring-book image
	coloring_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var idx: int = y * w + x
			if dilated[idx] == 1:
				coloring_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, chan_a[idx]))
			else:
				coloring_image.set_pixel(x, y, Color(1.0, 1.0, 1.0, chan_a[idx]))
	_refresh_texture()

func _refresh_texture() -> void:
	if canvas_texture == null:
		canvas_texture = ImageTexture.new()
	canvas_texture.set_image(coloring_image)
	texture_rect.texture = canvas_texture
	_apply_zoom()

func _on_threshold_changed(value: float) -> void:
	outline_threshold = value
	threshold_label.text = "%.2f" % value
	if canvas_image != null:
		_apply_coloring_book_style()
		if pbn_active and not image_colors_cache.is_empty():
			_build_pbn_overlay()

func _on_clear_pressed() -> void:
	if canvas_image != null:
		_apply_coloring_book_style()
		status_label.text = "Colors reset."

func _on_canvas_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(1.25)
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(0.8)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT or coloring_image == null:
		return
	var px: int = int(mb.position.x / zoom_level)
	var py: int = int(mb.position.y / zoom_level)
	if px < 0 or px >= coloring_image.get_width() or py < 0 or py >= coloring_image.get_height():
		return
	var target: Color = coloring_image.get_pixel(px, py)
	if target.r < 0.05 and target.g < 0.05 and target.b < 0.05:
		return
	_flood_fill(px, py, target)
	_refresh_texture()

func _flood_fill(start_x: int, start_y: int, target: Color) -> void:
	if _colors_close(target, selected_color):
		return
	var w := coloring_image.get_width()
	var h := coloring_image.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
	while stack.size() > 0:
		var pos: Vector2i = stack.pop_back()
		var x := pos.x
		var y := pos.y
		if x < 0 or x >= w or y < 0 or y >= h:
			continue
		var idx := y * w + x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		var c := coloring_image.get_pixel(x, y)
		# Stop at black outline pixels
		if c.r < 0.05 and c.g < 0.05 and c.b < 0.05:
			continue
		# Stop at different-colored regions (acts as a fill boundary)
		if not _colors_close(c, target):
			continue
		coloring_image.set_pixel(x, y, Color(selected_color.r, selected_color.g, selected_color.b, c.a))
		stack.append(Vector2i(x + 1, y))
		stack.append(Vector2i(x - 1, y))
		stack.append(Vector2i(x, y + 1))
		stack.append(Vector2i(x, y - 1))

func _extract_image_colors(img: Image, max_colors: int = 16) -> Array[Color]:
	var src: Image = img.duplicate()
	src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	# Sample at most ~5000 pixels so large images don't stall
	var step: int = maxi(1, int(sqrt(float(w * h) / 5000.0)))
	var color_counts: Dictionary = {}
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			# Quantize to 16 levels per channel to group near-identical colors
			var key := Color(
				roundf(c.r * 16.0) / 16.0,
				roundf(c.g * 16.0) / 16.0,
				roundf(c.b * 16.0) / 16.0
			)
			color_counts[key] = color_counts.get(key, 0) + 1
	# Sort by frequency so most-used colors appear first
	var pairs: Array = []
	for key: Color in color_counts:
		pairs.append([color_counts[key], key])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var result: Array[Color] = []
	for pair: Array in pairs:
		result.append(pair[1] as Color)
		if result.size() >= max_colors:
			break
	return result

func _populate_image_palette(colors: Array[Color]) -> void:
	image_colors_cache = colors
	for child in image_colors_grid.get_children():
		child.queue_free()
	for i in colors.size():
		var color: Color = colors[i]
		var swatch: ColorRect = ColorRect.new()
		swatch.color = color
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		swatch.gui_input.connect(_on_swatch_input.bind(color))
		var num_lbl: Label = Label.new()
		num_lbl.text = str(i + 1)
		num_lbl.add_theme_font_size_override("font_size", 11)
		num_lbl.add_theme_color_override("font_color", _contrasting_color(color))
		num_lbl.add_theme_color_override("font_outline_color", Color.WHITE)
		num_lbl.add_theme_constant_override("outline_size", 2)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num_lbl.position = Vector2(3, 2)
		swatch.add_child(num_lbl)
		image_colors_grid.add_child(swatch)

func _on_pbn_toggled(enabled: bool) -> void:
	pbn_active = enabled
	if pbn_overlay != null:
		pbn_overlay.visible = enabled
	if enabled and coloring_image != null and not image_colors_cache.is_empty():
		if pbn_regions.is_empty():
			_build_pbn_overlay()
		else:
			_render_pbn_overlay()

func _build_pbn_overlay() -> void:
	if image_colors_cache.is_empty() or coloring_image == null:
		return
	var w: int = coloring_image.get_width()
	var h: int = coloring_image.get_height()
	var color_map: PackedInt32Array = _build_color_map(image_colors_cache)
	pbn_regions = _find_region_centroids(color_map, w, h)
	_render_pbn_overlay()

func _render_pbn_overlay() -> void:
	if pbn_overlay == null:
		pbn_overlay = Control.new()
		pbn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pbn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_rect.add_child(pbn_overlay)
	for child in pbn_overlay.get_children():
		child.queue_free()
	if pbn_regions.is_empty() or coloring_image == null:
		return
	var w: int = coloring_image.get_width()
	var h: int = coloring_image.get_height()
	var font_size: int = clampi(int(float(w) * zoom_level) / 50, 9, 18)
	var img_w: float = float(w) * zoom_level
	var img_h: float = float(h) * zoom_level
	for region: Array in pbn_regions:
		var color_num: int = region[0]
		var cx: int = region[1]
		var cy: int = region[2]
		var lbl: Label = Label.new()
		lbl.text = str(color_num)
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		lbl.add_theme_color_override("font_outline_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var char_w: float = float(font_size) * 0.6 * float(str(color_num).length())
		var lx: float = clampf(float(cx) * zoom_level - char_w * 0.5, 0.0, img_w - char_w)
		var ly: float = clampf(float(cy) * zoom_level - float(font_size) * 0.5, 0.0, img_h - float(font_size))
		lbl.position = Vector2(lx, ly)
		pbn_overlay.add_child(lbl)

func _build_color_map(colors: Array[Color]) -> PackedInt32Array:
	var w: int = canvas_image.get_width()
	var h: int = canvas_image.get_height()
	var src: Image = canvas_image.duplicate()
	src.convert(Image.FORMAT_RGBA8)
	var color_map: PackedInt32Array = PackedInt32Array()
	color_map.resize(w * h)
	for y in h:
		for x in w:
			var outline_c: Color = coloring_image.get_pixel(x, y)
			if outline_c.r < 0.05 and outline_c.g < 0.05 and outline_c.b < 0.05:
				color_map[y * w + x] = 0
				continue
			var orig_c: Color = src.get_pixel(x, y)
			var best_idx: int = 1
			var best_dist: float = INF
			for i in colors.size():
				var ec: Color = colors[i]
				var dr: float = orig_c.r - ec.r
				var dg: float = orig_c.g - ec.g
				var db: float = orig_c.b - ec.b
				var dist: float = dr * dr + dg * dg + db * db
				if dist < best_dist:
					best_dist = dist
					best_idx = i + 1
			color_map[y * w + x] = best_idx
	return color_map

func _find_region_centroids(color_map: PackedInt32Array, w: int, h: int) -> Array:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(w * h)
	var min_size: int = maxi(50, (w * h) / 2000)
	var regions: Array = []
	for sy in h:
		for sx in w:
			var si: int = sy * w + sx
			if visited[si] == 1:
				continue
			var color_num: int = color_map[si]
			visited[si] = 1
			if color_num == 0:
				continue
			var stack: Array[Vector2i] = [Vector2i(sx, sy)]
			var sum_x: int = sx
			var sum_y: int = sy
			var count: int = 1
			var samples: Array[Vector2i] = [Vector2i(sx, sy)]
			while stack.size() > 0:
				var pos: Vector2i = stack.pop_back()
				var bx: int = pos.x
				var by: int = pos.y
				for di in 4:
					var nx: int = bx
					var ny: int = by
					if di == 0:
						nx = bx + 1
					elif di == 1:
						nx = bx - 1
					elif di == 2:
						ny = by + 1
					else:
						ny = by - 1
					if nx < 0 or nx >= w or ny < 0 or ny >= h:
						continue
					var nidx: int = ny * w + nx
					if visited[nidx] == 1:
						continue
					visited[nidx] = 1
					if color_map[nidx] != color_num:
						continue
					sum_x += nx
					sum_y += ny
					count += 1
					if count % 30 == 0:
						samples.append(Vector2i(nx, ny))
					stack.append(Vector2i(nx, ny))
			if count < min_size:
				continue
			# Score each candidate by interior clearance; pick the fattest spot.
			# Include the mean centroid as a candidate (clamped to image bounds).
			var cx: int = clampi(sum_x / count, 0, w - 1)
			var cy: int = clampi(sum_y / count, 0, h - 1)
			var best_pos := Vector2i(cx, cy)
			var best_r: int = _interior_radius(color_map, w, h, cx, cy, color_num)
			for s: Vector2i in samples:
				var r: int = _interior_radius(color_map, w, h, s.x, s.y, color_num)
				if r > best_r:
					best_r = r
					best_pos = s
			# Skip regions too thin to show a visible label (corridors, hairlines).
			if best_r < 3:
				continue
			regions.append([color_num, best_pos.x, best_pos.y])
	return regions

func _interior_radius(color_map: PackedInt32Array, w: int, h: int, x: int, y: int, color_num: int) -> int:
	if x < 0 or x >= w or y < 0 or y >= h or color_map[y * w + x] != color_num:
		return 0
	var min_r: int = 20
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		for r in range(1, 21):
			var nx: int = x + d.x * r
			var ny: int = y + d.y * r
			if nx < 0 or nx >= w or ny < 0 or ny >= h or color_map[ny * w + nx] != color_num:
				min_r = mini(min_r, r - 1)
				break
	return min_r

func _apply_zoom() -> void:
	if coloring_image == null:
		return
	var w: float = float(coloring_image.get_width()) * zoom_level
	var h: float = float(coloring_image.get_height()) * zoom_level
	texture_rect.custom_minimum_size = Vector2(w, h)
	zoom_label.text = "%d%%" % int(zoom_level * 100.0)

func _fit_image_to_view() -> void:
	if coloring_image == null:
		return
	var avail: Vector2 = scroll_container.size
	if avail.x <= 0.0 or avail.y <= 0.0:
		return
	zoom_level = minf(avail.x / float(coloring_image.get_width()),
		avail.y / float(coloring_image.get_height()))
	zoom_level = clampf(zoom_level, 0.05, 8.0)
	_apply_zoom()
	if pbn_active and not pbn_regions.is_empty():
		_render_pbn_overlay()

func _zoom_by(factor: float) -> void:
	zoom_level = clampf(zoom_level * factor, 0.05, 8.0)
	_apply_zoom()
	if pbn_active and not pbn_regions.is_empty():
		_render_pbn_overlay()

func _contrasting_color(c: Color) -> Color:
	var lum: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return Color(0.1, 0.1, 0.1) if lum > 0.5 else Color(0.95, 0.95, 0.95)

func _colors_close(a: Color, b: Color, tol: float = 0.15) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol
