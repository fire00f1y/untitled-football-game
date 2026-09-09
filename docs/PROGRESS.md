# Progress Log

Working log of what's been built, in order, plus every bug hit and how it was
fixed. See [DESIGN.md](DESIGN.md) for the full design; this doc is the "how we
got here" and "what to watch out for" reference.

## Environment

- **Engine:** Godot 4.6.3 (Forward+ renderer, Jolt physics, D3D12 on this
  machine).
- **Editor control:** the Godot MCP Pro plugin (`addons/godot_mcp/`), copied
  in from an existing `simple-scene` project and enabled in `project.godot`.
  It exposes editor/runtime control (scene editing, script editing, live game
  inspection, screenshots, input simulation) over a local WebSocket, which is
  how this entire project was built and playtested without a human at the
  keyboard.
- **Art generation:** ComfyUI running locally (`127.0.0.1:8188`, RTX 5090),
  driven via the `comfy-mcp` tool's `generate_image` (a fast local
  `z-image-turbo` template).

## Timeline

### 1. Tool connectivity + plugin install

Confirmed Blender and ComfyUI were already connected; Godot's MCP Pro plugin
was not (wrong/no project loaded). Located the plugin already installed in a
sibling project (`C:/Code/godot/simple-scene`), copied
`addons/godot_mcp/` into this project, and enabled it via
`project.godot`'s `[editor_plugins]` section. Confirmed connection via
`get_project_info`.

### 2. Concept + genre mapping

The user's initial pitch ("Vampire Survivors crawler but football, selectable
teams with improvable stats, down markers get longer, downs per series
increases") was disambiguated via three clarifying questions before writing
any code:

- Core loop → **runner vs. swarm** (not a hands-off auto-runner, not manual
  everything).
- Session shape → **endless single drive** (not discrete drives, not a full
  4-quarter simulation).
- Upgrade target → **player/team attributes** (stat upgrades), which later
  grew to include unlockable abilities too (see below).

### 3. Core prototype build

Built in one pass and playtested end-to-end before moving on:

- Autoloads: `Teams` (4 teams' base stats/colors/blurbs), `GameState` (down/
  series/yardage/stats state machine + signals).
- Scenes: `team_select.tscn`, `main.tscn` (the run), `player.tscn`,
  `defender.tscn`.
- Down/series/upgrade-on-conversion loop, turnover-on-downs game over,
  restart back to team select.
- Verified via live playtest: team select → run → convert downs → pick
  upgrades → forced a turnover via script → confirmed game-over screen and
  restart flow.

**Bugs hit and fixed during the build:**

- `setup_collision` names its generated node `CollisionShape`, not
  `CollisionShape2D` as assumed — fixed the `@onready` path in `player.gd`.
- Newly-added autoloads (`Teams`, `GameState`) aren't recognized as global
  identifiers by the editor's own script-language server until a real editor
  restart — but the actual **running game** (a fresh process via "Play")
  loads `project.godot` fresh and works fine. This "Identifier not found:
  GameState" error recurred throughout the project every time a script was
  edited; it is **not** a real bug as long as the game itself runs — it's
  noise from `get_editor_errors`/`validate_script`/`edit_script`'s own parse
  check, and is ignored throughout this log unless it appears while the game
  is actually *running*.
- `get_first_node_in_group()` returns a plain `Node`; using its result to
  read `.global_position` needs an explicit `as Node2D` cast or the strict
  type-checker throws (surfaced as "Cannot infer the type of ... variable").
- The project's GDScript settings treat some type-inference warnings as hard
  errors — `var x := floor(...)` and similar patterns needed explicit `:
  float` annotations instead of `:=` in a few places (`field.gd`, `main.gd`).

**Balance observation (not a bug):** standing still with high Power can let
the stiff-arm kill weak defenders right at the edge of its radius before they
ever reach tackle range, making the player briefly untouchable. Flagged, not
addressed.

### 4. Retro pixel-art field + UI art

Generated via ComfyUI, processed in Godot (chroma-key flood-fill to
transparency + nearest-neighbor resize) using `execute_editor_script`:

- Turf tile (`assets/textures/turf_tile.png`) — first attempt came back as a
  soccer pitch with a center circle/penalty box baked in (doesn't tile for an
  endless scroll); regenerated with an explicit "no lines/markings" prompt.
- First-down marker pylon (`first_down_marker.png`).
- UI panel (`ui_panel.png`) and button (`ui_button.png`) styles — navy/orange
  checkered border, 9-sliced via `StyleBoxTexture` resources saved to
  `theme/panel_style.tres` / `theme/button_style.tres`.
- Set the project's default texture filter to Nearest for crisp pixel edges
  everywhere.

**Bug hit:** the very first `button_style.tres`/`panel_style.tres` got saved
with `texture = null` — the editor script created and saved the
`StyleBoxTexture` in the same breath as the PNG was written to disk, before
Godot's filesystem watcher had imported it, so `load()` silently returned
null. Fix (and the general lesson, repeated several times below): after
writing a new image file, call `reload_project` and confirm `load()` returns
non-null *before* wiring it into anything.

### 5. Three new abilities: Hurdle, Offensive Lineman, Spin Move

Added `GameState.abilities` (level-tracked dict) and `apply_ability()`, a
`lineman_ally.gd`/`lineman.tscn` companion actor, and extended the upgrade
pool with ability entries alongside the stat entries. Verified each ability
individually via direct script calls (`try_hurdle()` cooldown behavior,
`apply_ability("spin")` → confirmed the periodic proc fires and sets the
speed-boost window) as well as in normal play.

**Bug hit:** rewriting `player.gd` to add the abilities accidentally
reintroduced the earlier-fixed `CollisionShape2D` vs `CollisionShape` path
mistake (a regression from the fix in step 3). Caught via `get_editor_errors`
and fixed again.

### 6. Character art (helmets → full bodies) + detint

First pass generated *helmet-only* sprites — a miss, since the intent was
full character art. Regenerated as full-body running sprites (modern uniform
for the player, vintage leather-and-wool uniform for defenders). Also fixed:
the player sprite's team-color tint (`modulate = team_color`) looked "neon"
on saturated colors (called out specifically for the Wraiths' purple);
first tried blending the tint 45% toward white, then — per explicit feedback
that it was still ugly — removed team tinting from the player sprite
entirely in favor of a fixed off-white `Color(0.93, 0.92, 0.88)`.

**Bug hit (twice):** both the helmet sprites and later the full-body sprites
hit the same texture-import race condition as step 4 (Sprite2D `texture`
came back `null` because the PNG wasn't imported yet when the property was
set). Same fix both times: `reload_project`, confirm `load()` resolves, then
re-apply the texture property.

### 7. Referees

Added a shared `referee_actor.gd`/`referee.tscn` (decorative, no collision)
and two instances in `main.tscn` — one held just outside the left sideline,
one out on the field trailing the play — both following the player at a
fixed offset.

### 8. Offensive Lineman was missing its sprite

The lineman ally scene had never been given a body sprite (still using an
old placeholder `_draw()` circle from before character art existed). Fixed
by pointing it at the same `player_body.png` texture the player uses (off-
white, matching modulate), with the same flip-to-face-direction behavior as
the other characters.

### 9. HUD: upgrades grid + stats panel

Restructured the HUD's `CanvasLayer` to add:

- A `LeftColumn` VBox wrapping the existing down/series/yards panel plus a
  new "UPGRADES" panel containing a 2-column `GridContainer` of badges — one
  per distinct upgrade/ability picked, showing its count/level, added or
  updated live via a new `GameState.upgrade_picked` signal.
- A `RightPanel` anchored to the top-right showing live Speed/Power/Agility/
  Awareness values, updated on the existing `GameState.stats_changed` signal.

**Bugs hit:**

- Forgot to update `hud.gd`'s `@onready` node paths after nesting the
  existing down/series panel one level deeper under the new `LeftColumn` —
  this one *did* surface as a real runtime error (`Node not found`) when the
  game actually ran, not just editor-cache noise. Fixed by updating the
  paths.
- The big checkered panel `StyleBoxTexture` (designed for large panels)
  looked muddy and had illegible text when stretched down to small badge
  size (74×44). Fixed by creating a dedicated small `StyleBoxFlat`
  (`theme/badge_style.tres` — flat navy fill, orange border, small corner
  radius) just for the badges, with white/black-shadow text instead of the
  dark text used on the big orange buttons.

### 10. Downline bug fix + escalating difficulty

Two issues reported together:

1. **Bug:** the first-down marker line visually followed the player backward
   when he retreated — because it was being recomputed every frame as
   `player.y − yards_remaining`, i.e. relative to the player's *live*
   position rather than a fixed field position. Root-cause fixed by
   reworking the whole yardage model around a fixed **`scrimmage_y`** world
   position (set once per down-attempt, only updated on conversion) and a
   **`marker_world_y()`** helper derived from it. `total_yards` was changed
   at the same time to be net downfield position from the run's start
   (rather than a forward-only accumulator), for consistency with the same
   fixed-anchor approach. Verified via direct script test: moving forward
   then backward from the same scrimmage point left the marker's world
   position bit-for-bit identical both times, while "yards remaining"
   correctly went back up on retreat.
2. **Escalation requests:** (a) defender *count* per spawn wave now scales
   with `series_count` (1 → 2 → 3 defenders per tick as series climb), and
   the difficulty curve that drives defender HP/speed/spawn-rate now also
   factors in down progress (`conversions`), not just elapsed time; (b) the
   yardage growth *step* itself now increases every series (1.5 → 2.5 → 3.5
   → 4.5 yards added per conversion) instead of a flat rate, verified by
   simulating 9 conversions via script and checking the step value climbed
   on schedule.

### 11. Repo hygiene

Added `.gitignore` (Godot's `.godot/` cache, `*.import` metadata, export
artifacts, the intermediate `assets/raw/` art-generation sources, and the
debug `screenshot_*.png` files dropped at the project root during testing).
Note: this folder is **not yet a git repository** — `.gitignore` has no
effect until `git init` is run.

## Current file map

```
project.godot                  # editor_plugins, autoloads, input map, rendering settings
addons/godot_mcp/              # Godot MCP Pro plugin (editor/runtime control)
scripts/
  autoload/
    teams.gd                   # Teams.LIST — 4 teams' stats/color/blurb
    game_state.gd              # GameState — down/series/yardage/stats/abilities + signals
  player.gd                    # movement, stiff-arm, hurdle, spin, stat hookup
  defender.gd                  # chase AI, stagger/knockback, tackle resolution
  lineman_ally.gd               # escort ally: follow + instant-flatten block area
  referee_actor.gd              # decorative follower, no collision
  field.gd                     # turf/yard-lines draw, marker pylon positioning
  main.gd                      # run scene: spawner, difficulty curve, referees/linemen wiring
  hud.gd                       # down/series/yards, upgrades grid, stats panel
  upgrade_picker.gd             # first-down upgrade pool + pick UI
  game_over.gd                  # turnover-on-downs screen
  team_select.gd                 # team-select screen
scenes/
  team_select.tscn, main.tscn, player.tscn, defender.tscn,
  lineman.tscn, referee.tscn
theme/
  panel_style.tres              # big 9-sliced navy/orange checkered panel (StyleBoxTexture)
  button_style.tres              # 9-sliced orange rounded button (StyleBoxTexture)
  badge_style.tres                # small flat navy/orange badge (StyleBoxFlat)
assets/
  textures/                      # processed, transparent, game-ready PNGs
  raw/                            # gitignored — unprocessed ComfyUI generations
docs/
  DESIGN.md, PROGRESS.md          # this pair of docs
```

## Recurring lessons (read before touching art or autoloads again)

1. **New PNG written to disk → don't wire it into a node/resource in the same
   breath.** Godot needs to import it first. Call `reload_project`, then
   confirm `load("res://path.png") != null` via `execute_editor_script`,
   *then* set the `texture`/similar property. This bit the project four
   separate times before the pattern was internalized.
2. **`GameState`/`Teams` "Identifier not found" from `edit_script`,
   `validate_script`, or `get_editor_errors` right after an edit is usually
   not real** — it's the editor's own script-language server not knowing
   about autoloads added mid-session. Confirm by actually running the game;
   trust that over the static check.
3. **After restructuring a scene's node tree** (moving something under a new
   parent for layout purposes), grep the corresponding script for `@onready
   var ... = $OldPath` — this has caused real runtime errors twice.
