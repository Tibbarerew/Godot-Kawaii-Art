# Kawaii-Art

A kawaii coloring app built in Godot 4.6. Load any image, convert it to a coloring-book outline, and paint it with a curated kawaii palette. Works on desktop and mobile.

## Features

- **Built-in sample images** — seven kawaii images (bunny, deer, fox, koala, penguin, pig, logo) load with one tap
- **Load your own image** — PNG, JPG/JPEG, BMP, WEBP; transparent backgrounds are composited to white automatically
- **Coloring-book conversion** — per-channel Sobel edge detection with dilation produces clean outlines
- **Adjustable edge sensitivity** — slider (0.05–0.95) to tune outline thickness
- **24-color kawaii palette** — swatches in the side panel; tap to select
- **Image color extraction** — top 16 colors sampled from the loaded image, shown as numbered swatches
- **Flood-fill painting** — tap/click any region to fill it with the selected color; outlines act as boundaries; painted regions can be recolored at any time
- **Paint by Numbers mode** — toggle overlays numbered labels on each region using the image's color map; labels are placed at each region's fattest interior point
- **Zoom** — mouse wheel, +/− buttons, or pinch-to-zoom on touch; Fit button to reset
- **Pan** — scroll bars on desktop; single-finger drag on touch
- **Pinch to zoom** — two-finger pinch on mobile
- **Colors panel toggle** — "Colors" button hides/shows the right palette panel for more canvas space
- **Reset Colors** — restores the image to its black-and-white outline state
- **Save PNG** — exports the current colored image

## Controls

| Action | Desktop | Mobile |
|---|---|---|
| Paint region | Left-click | Tap |
| Pan canvas | Scroll bars / drag scrollbars | Single-finger drag |
| Zoom in/out | Mouse wheel or +/− buttons | Pinch or +/− buttons |
| Fit to view | Fit button | Fit button |
| Select color | Click swatch | Tap swatch |

## Project Structure

```
Kawaii-Art/
├── Assets/           # Built-in coloring images
├── Scenes/
│   └── Main.tscn     # Single scene — Control root
├── Scripts/
│   └── Main.gd       # All UI and logic built programmatically
├── addons/
│   └── godot_ai/     # MCP plugin for Claude Code integration
└── project.godot
```

## Running

Open the project in Godot 4.3+ and press F5, or run `Scenes/Main.tscn` directly. The window starts at 1280×720 and is freely resizable.

## MCP / Claude Code Integration

The project includes the [Godot AI](https://github.com/hi-godot/godot-ai) plugin. With the plugin enabled in **Project > Project Settings > Plugins**, Claude Code can control the live editor via MCP tools.
