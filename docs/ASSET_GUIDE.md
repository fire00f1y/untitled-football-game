# Asset Creation Guide

How every piece of art in this project was made, so new assets (characters,
props, UI, textures) come out in the same retro pixel-art style. Written for
whoever — human or AI — picks this project up next.

If you're an AI agent with MCP tool access to a local ComfyUI (`comfy-mcp`)
and to this Godot project (`godot-mcp-pro`), you can follow this guide
literally, step by step, tool call by tool call. If you don't have those
tools, the prompts and processing logic below are plain enough to reproduce
by hand in any image editor.

## The target look

- **Pixel art, but not literally tiny.** The source generations come back at
  normal diffusion resolution (~512–1024px) rendered in a pixel-art *style*
  (chunky flat shapes, hard edges). We then force real low-res pixelation by
  resizing down with nearest-neighbor interpolation — that's what gives the
  final crunchy, blocky look, not the prompt alone.
  - Full-body character sprites end up **72px tall** before in-scene scaling.
  - Icon-style props (the first-down marker) end up **128px tall**.
  - Tileable textures end up **128×128**.
  - See "Sizing conventions" below for exactly how those map to in-game size.
- **Flat colors with clear (not subtle) shading.** Ask for "flat solid colors
  with clear shading," not painterly gradients — gradients survive the
  nearest-neighbor downsample badly and turn to mush.
- **No text, no logos, no UI chrome baked into the art.** All of that is
  built separately in Godot.
- **Every non-tiling sprite is generated on a plain, roughly-solid dark
  background** so it can be chroma-keyed to transparency afterward (see
  Pipeline step 3). Tiling textures (turf) are the one exception — those have
  no background to remove, the whole image *is* the content.
- **Nearest-neighbor filtering everywhere.** The project sets
  `rendering/textures/canvas_textures/default_texture_filter = 0` (Nearest)
  at the project level, so any texture you add renders crisp/blocky by
  default — you don't need to set filtering per-node.

## Tools

- **Generation:** `mcp__comfy-mcp__generate_image(prompt)` — a local,
  free, fast SD-based template (`z-image-turbo`) running against a local
  ComfyUI instance. No need to touch `run_workflow`/templates/checkpoints for
  assets this simple; the default template has done every asset in this
  project well.
- **Fetching:** `mcp__comfy-mcp__fetch_outputs(prompt_id, out_dir)` — pull the
  generated PNG down to `assets/raw/` in this project (that folder is
  gitignored; it's scratch space for source generations, not shipped art).
- **Processing:** `mcp__godot-mcp-pro__execute_editor_script(code)` — runs
  GDScript inside the Godot editor process, with full filesystem access via
  `Image` and `ProjectSettings.globalize_path()`. This is where chroma-key,
  cropping, and the nearest-neighbor resize all happen. See the reusable
  script in Pipeline step 3.
- **Wiring in:** the usual `godot-mcp-pro` scene tools (`add_node`,
  `update_property`, etc.) to point a `Sprite2D.texture` or a
  `StyleBoxTexture.texture` at the processed file in `assets/textures/`.

## Pipeline

### 1. Generate

Call `generate_image` with a prompt built from the formulas below. Keep
`wait: true` (default) — it's fast enough (2–3s typically) that there's no
reason to poll.

### 2. Fetch

```
fetch_outputs(prompt_id, out_dir="<project>/assets/raw", inline_images=true)
```

`inline_images: true` lets you see the result immediately and judge whether
to regenerate before spending time processing it. **Look at it before
processing.** Diffusion models miss the brief often enough that eyeballing
first saves a round trip — see "Known model quirks" below for the specific
ways this project's generations went wrong.

### 3. Process

This is the one piece of real logic in the pipeline, and it's the same for
every non-tiling asset (character sprites, props, UI panels/buttons): resize
down for pixelation, flood-fill the background to transparent starting from
the image edges (so interior light-colored pixels — a white jersey stripe, a
helmet highlight — don't get wrongly keyed out), crop to the actual content,
resize again to the final target height. Run this via
`execute_editor_script`:

```gdscript
var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/raw/<file>.png"))
img.resize(256, 256, Image.INTERPOLATE_NEAREST)   # pixelate first — do this before keying
img.convert(Image.FORMAT_RGBA8)
var w := img.get_width()
var h := img.get_height()
var bg := img.get_pixel(1, 1)                      # sample the background from a corner
var threshold := 0.12                              # raise if background isn't fully flat
var visited := PackedByteArray()
visited.resize(w * h)
var stack: Array = []
for x in range(w):
	stack.append(Vector2i(x, 0))
	stack.append(Vector2i(x, h - 1))
for y in range(h):
	stack.append(Vector2i(0, y))
	stack.append(Vector2i(w - 1, y))
while stack.size() > 0:
	var p: Vector2i = stack.pop_back()
	if p.x < 0 or p.x >= w or p.y < 0 or p.y >= h:
		continue
	var idx := p.y * w + p.x
	if visited[idx] == 1:
		continue
	visited[idx] = 1
	var c := img.get_pixel(p.x, p.y)
	var diff: float = abs(c.r - bg.r) + abs(c.g - bg.g) + abs(c.b - bg.b)
	if diff > threshold:
		continue                                    # not background — stop the flood here
	img.set_pixel(p.x, p.y, Color(c.r, c.g, c.b, 0.0))
	stack.append(Vector2i(p.x + 1, p.y))
	stack.append(Vector2i(p.x - 1, p.y))
	stack.append(Vector2i(p.x, p.y + 1))
	stack.append(Vector2i(p.x, p.y - 1))
var used := img.get_used_rect()
var cropped := img.get_region(used)
var target_h := 72                                  # see Sizing conventions
var scale_factor: float = float(target_h) / float(cropped.get_height())
var tw := int(round(cropped.get_width() * scale_factor))
cropped.resize(tw, target_h, Image.INTERPOLATE_NEAREST)
cropped.save_png(ProjectSettings.globalize_path("res://assets/textures/<name>.png"))
_mcp_print({"used": [used.position.x, used.position.y, used.size.x, used.size.y], "final": [tw, target_h]})
```

Notes:

- **This is a flood fill from the edges, not a global color-key.** That
  distinction matters: a naive "make every near-black pixel transparent"
  pass will eat black pixel-art outlines and dark interior details (a
  helmet's ear hole, a jersey number's shadow). Flooding in from the border
  only removes background that's *connected* to the edge.
- `threshold` (sum of per-channel diffs, so effectively 0–3 scale) — `0.1–
  0.16` has worked for every asset so far. Raise it if the background has
  visible noise/grain and isn't being fully keyed; lower it if the flood is
  eating into the subject.
- **Tileable textures (turf) skip keying and cropping entirely** — there's no
  background to remove. Just resize down for pixelation and save:
  ```gdscript
  var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/raw/<file>.png"))
  img.resize(128, 128, Image.INTERPOLATE_NEAREST)
  img.save_png(ProjectSettings.globalize_path("res://assets/textures/<name>.png"))
  ```
- **`execute_editor_script` doesn't allow top-level nested `func` defs** — if
  you need to process two images in one call, put the logic in a loop over
  an array of `[src, dst]` pairs (as done for the character-body pass), not
  a helper function.
- Batch-editing tools like `edit_script` will refuse to write a script that's
  open in the editor unless you pass `force: true`. `execute_editor_script`
  itself will refuse direct file-write API calls (`ResourceSaver.save`,
  `FileAccess` in write mode, `DirAccess` mutations) as a safety guard —
  pass `allow_unsafe_editor_io: true` when you genuinely need one (e.g.
  saving a new `.tres` theme resource), and make sure nothing you're writing
  is currently open in an editor tab.

### 4. **Reload and verify before wiring in — every time**

This bit the project four separate times: a texture written to disk and
immediately assigned to a `Sprite2D.texture` (or a `StyleBoxTexture.texture`)
in the same tool-call sequence silently resolves to `null`, because Godot's
filesystem watcher hasn't imported the new PNG yet. The fix is cheap and
should just always be done:

```gdscript
# after saving the PNG, and after calling reload_project:
var t = load("res://assets/textures/<name>.png")
_mcp_print(t != null)
```

Only wire the texture into a node/resource once this prints `true`. If you
skip this and something ends up looking blank in-game, this is the first
thing to check (`get_node_properties(node_path, category="texture")` on the
`Sprite2D` in question — if `texture` comes back `null`, re-run
`update_property` now that the file is indexed).

### 5. Wire it in

- **Character/prop sprite:** add a `Sprite2D` child, set `texture`, set
  `scale` to hit the target in-world size (see Sizing conventions), set
  `centered` (default `true` is fine for characters).
- **Team/generic tint:** set `modulate` on the `Sprite2D`, not a texture
  variant per team. A `Color.WHITE.lerp(team_color, x)` blend is much less
  "neon" than assigning the raw team color directly — and for the *player*
  specifically, tinting was removed altogether after feedback that even a
  blended tint read as neon on saturated colors. Default to **no tint**
  (fixed off-white `Color(0.93, 0.92, 0.88)`) unless asked for team color.
- **Tiling background:** a `Sprite2D` with `region_enabled = true`, a
  `region_rect` much larger than the source texture, and `texture_repeat`
  set to `2` (`CanvasItem.TEXTURE_REPEAT_ENABLED`) will tile the small
  texture across that whole region — see `Field/Turf` in `main.tscn` for a
  working example (a 480×200000 region covers the whole field width and
  effectively any drive length).
- **UI panel/button:** wrap the processed PNG in a `StyleBoxTexture`
  resource (`res://theme/*.tres`), set `texture_margin_*` to roughly the
  border thickness in the source art (24px worked for the ~128px panel, 40px
  for the ~180px button), and save with `ResourceSaver.save(sb, path)`
  (`allow_unsafe_editor_io: true`). Apply via
  `node.add_theme_stylebox_override("normal"/"panel"/etc., stylebox)` — for
  runtime-created controls (buttons built in a script's `_ready()`) do this
  in code with `load()`; for static scene nodes, `add_theme_stylebox_override`
  via `execute_editor_script` on the already-placed node.
  **Don't reuse a big panel style at small sizes** — a 9-sliced texture
  designed for a large panel looks muddy and loses text legibility when
  stretched down to something like a small HUD badge. Make a dedicated
  small `StyleBoxFlat` (flat fill + border color + corner radius) for
  anything under roughly 100px — see `theme/badge_style.tres`.

## Prompt formulas by asset type

Keep every prompt to one paragraph, comma-separated clauses, always ending
with the same "no-blur/no-gradient/no-text" boilerplate. Below are the
formulas that have worked, ready to adapt.

**Full-body character sprite** (player, defender, referee):

> pixel art sprite of a full body [description] running, [equipment/clothing
> details], [color palette], three-quarter view, retro 16-bit sports video
> game style, centered on plain dark background, flat solid colors with
> clear shading, crisp hard pixel edges, no blur, no text, game asset sprite

- Ask explicitly for a **light gray/white base** if the sprite will be tinted
  via `modulate` later — a flat pure-white base tints as a garish flat
  color; a *shaded* light-gray base (the model adds its own highlights/
  shadows/folds by default when you ask for "clear shading") tints much more
  naturally since the multiply preserves the shading pattern.
- "Three-quarter view" reads much better in this top-down game than a
  literal top-down view — a strict top-down shot of a person shows mostly a
  helmet and loses all character read. Every character sprite in this
  project is three-quarter/side view despite the game being top-down; they
  don't rotate to face movement direction, they just flip horizontally
  (`Sprite2D.flip_h`) based on left/right movement.

**Icon-style prop** (first-down marker, any standalone object sprite):

> pixel art sprite icon of a [object], [description/colors], retro 16-bit
> sports video game style, [view angle], centered on plain dark background,
> flat solid colors, crisp hard pixel edges, no blur, no gradients, no text,
> game asset icon

**Tileable texture** (turf, or any future ground/wall texture):

> seamless tileable pixel art texture of [plain material only — call out
> explicitly what NOT to include], top-down view, retro 16-bit video game
> style, flat solid colors, crisp hard pixel edges, no blur, no gradients,
> no text, no logos, game asset texture

If the subject has an obvious "sport" association (grass → soccer pitch),
explicitly forbid the markings you don't want (`no lines, no field markings,
no circles`) or the model will draw them anyway — see "Known model quirks."

**UI panel/button:**

> pixel art UI [panel frame / button], retro 16-bit sports video game style,
> [colors and border description], flat solid colors, crisp hard pixel
> edges, no blur, no gradients, no text, [centered / symmetrical border on
> all sides], game asset

## Sizing conventions

Everything is generated big and pixelated down, then scaled again inside
Godot. Current conventions, so new assets sit at a consistent visual size
next to existing ones:

| Asset type | Processed PNG height | In-scene `scale` | Effective in-world size |
|---|---|---|---|
| Player / defender / referee / lineman body | 72px | 0.5–0.55 | ~36–40px tall |
| First-down marker pylon | 128px | 0.3 | ~38px tall |
| Turf tile | 128×128 (no scale needed) | 1.0, tiled | 128px world units per tile |
| UI panel texture | 128×128 | n/a (`StyleBoxTexture`, stretched) | — |
| UI button texture | ~180×180 (cropped) | n/a (`StyleBoxTexture`, stretched) | — |
| HUD badge | n/a — flat `StyleBoxFlat`, not a texture | — | ~74×44px box |

The player's collision/attack radii (16px body, ~46–68px stiff-arm radius
depending on Awareness) were tuned around the *original* placeholder circle
size and haven't needed to change since character sprites were sized to
roughly match that same footprint — if you generate a noticeably bigger or
smaller character sprite, sanity-check it against the defender/lineman
collision shapes so hitboxes still feel right relative to what's drawn.

## Known model quirks (don't waste a regeneration rediscovering these)

- **Anything shaped like a ball field defaults to soccer markings.** A
  "grass texture" prompt came back as a soccer pitch (center circle, penalty
  box) on the first try. Fix: explicitly list what to exclude — "no lines,
  no field markings, no circles, plain grass only."
- **"No facemask" on a vintage/leather helmet gets ignored.** Asked twice,
  worded differently each time, both times the model drew a modern metal
  facemask cage on the "1920s leatherhead" helmet anyway. Not worth a third
  attempt — the leather texture and cream/brown palette already read as
  clearly distinct from the player's modern white helmet, so this was
  accepted as-is. If you hit this again, don't loop on it; judge by whether
  the *silhouette/palette* reads as different enough, not by strict prompt
  compliance.
- **"Viewed from directly above / top-down"** on a character produces a
  three-quarter/side view in practice, not a literal bird's-eye shot. This
  turned out to be *better* for readability than a true top-down view would
  have been — see the character-sprite prompt formula above, which now asks
  for three-quarter view directly instead of fighting for top-down.
- **The background is never perfectly flat** — there's always a little
  grain/noise even on a "plain dark background" request. That's why the
  flood-fill uses a threshold (sum-of-channel-diffs, not exact match) rather
  than an exact color match.

## Checklist for adding a new asset

1. Write the prompt using the right formula above; explicitly exclude
   anything the model is likely to add unprompted (see quirks).
2. `generate_image`, then `fetch_outputs(inline_images=true)` into
   `assets/raw/` and actually look at it.
3. Regenerate with a more explicit prompt if it's wrong in an obvious way
   (wrong markings, wrong pose) — don't try to fix that in post.
4. Process with the flood-fill/crop/resize script (or the no-crop version
   for tileables), saving to `assets/textures/`.
5. `reload_project`, then confirm `load()` on the new path returns non-null.
6. Wire the texture into the relevant `Sprite2D`/`StyleBoxTexture`, matching
   the sizing conventions table.
7. Reload and playtest in the actual running game (`play_scene`,
   `get_game_screenshot`) — don't just trust the editor view.
