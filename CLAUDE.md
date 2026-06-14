# Kawaii-Art — Claude Code Notes

## Architecture

Single scene (`Scenes/Main.tscn`) with a single script (`Scripts/Main.gd`). The entire UI is built programmatically in `_build_ui()` called from `_ready()`. No sub-scenes, no external dependencies beyond the godot_ai addon.

## Key functions

| Function | Purpose |
|---|---|
| `_build_ui()` | Builds toolbar, HSplitContainer, canvas ScrollContainer, right panel |
| `_populate_palette()` | Adds 24 kawaii color swatches to `palette_grid` |
| `_flatten_alpha(img)` | Composites transparent pixels onto white in-place; call before processing any image |
| `_apply_coloring_book_style()` | Runs per-channel Sobel on `canvas_image`, dilates edges, writes to `coloring_image` |
| `_flood_fill(x, y, target)` | BFS flood fill on `coloring_image`; stops only at black outlines — fills all connected non-outline pixels so any region can be recolored |
| `_paint_at(local_pos)` | Converts canvas-local position to pixel coords and calls `_flood_fill` |
| `_on_canvas_input(event)` | Handles mouse clicks, touch taps, single-finger pan, two-finger pinch zoom |
| `_build_pbn_overlay()` | Builds color map and finds region centroids for Paint by Numbers mode |
| `_find_region_centroids(...)` | BFS flood fill on color map; picks fattest interior point per region via `_interior_radius()` |
| `_interior_radius(...)` | Returns minimum clearance in 4 cardinal directions from a point — used to place PBN labels in wide spots |
| `_fit_image_to_view()` | Sets zoom so image fills the scroll container |
| `_load_builtin(path)` | Loads a built-in asset via `Image.load_from_file(globalized_path)` (bypasses import pipeline), flattens alpha, runs the full pipeline |

## State

- `canvas_image` — original loaded image (alpha-flattened, unmodified after load)
- `coloring_image` — the live coloring-book image; modified by painting
- `zoom_level` — current zoom multiplier applied to `texture_rect.custom_minimum_size`
- `pbn_regions` — `Array` of `[color_num, cx, cy]` built once per image/threshold change
- `_active_touches` — `Dictionary` tracking live touch positions by index (for pinch/pan)

## Paint by Numbers notes

- `_build_color_map()` maps each non-outline pixel of `canvas_image` to the nearest of the 16 extracted image colors (1-indexed; 0 = outline)
- Region centroid placement: samples every 30th BFS pixel, evaluates `_interior_radius` for each sample plus the mean centroid, picks the highest-scoring position
- Regions with `best_r < 3` (corridors/hairlines) are silently skipped
- `min_size = max(50, w*h/2000)` pre-filters tiny specks before interior scoring

## Gotchas

- `Transform2D.xform()` does not exist in Godot 4 — use the `*` operator: `transform * vector`
- `: Type =` not `:=` when the RHS type is ambiguous (int consts, untyped loop vars, Node method returns)
- `right_scroll_panel` is the class variable for the right panel; the "Colors" toolbar button toggles its visibility
- `_flatten_alpha` modifies the image in-place and must be called before `_apply_coloring_book_style` (which reads `canvas_image`)
- Touch positions from `InputEventScreenTouch`/`InputEventScreenDrag` in `gui_input` are in global viewport space — convert with `texture_rect.get_global_transform().affine_inverse() * position`
- Built-in assets use `Image.load_from_file(ProjectSettings.globalize_path(res_path))` not `load() as Texture2D` — the latter requires a `.import`+`.ctex` pair that may be missing after file renames
- Supported input formats: PNG, JPG/JPEG, BMP, WEBP (via `Image.load_from_file` for builtins; FileDialog filter for user images)
