# Balatro Football — Design Doc

A "Vampire Survivors"-style roguelike crawler set on a football field. You control
one ball-carrier on an endless drive downfield, auto-clearing swarms of defenders
while gaining yards, converting first downs, and picking permanent upgrades —
until you finally fail to convert and the drive ends.

## Core pillars

- **Runner vs. swarm.** One controlled character, top-down, auto-attacking nearby
  enemies (Vampire Survivors' auto-fire weapon, reskinned as a stiff-arm) while
  the player manually dodges incoming defenders.
- **Endless single drive.** No discrete levels — one continuous possession that
  runs until you turn the ball over on downs. Difficulty escalates continuously
  the longer you survive.
- **Football's down-and-distance structure as the wave/level system.** Converting
  a first down is the "level up" moment (Vampire Survivors' level-up screen),
  and the down/series counters are the difficulty curve.

## Genre mapping (why football mechanics work as a survivors-like)

| Football concept | Survivors-like equivalent |
|---|---|
| Gaining yards | Surviving/progressing through a wave |
| Defenders swarming | Enemy horde |
| Stiff-arm (auto-attack) | Auto-fire weapon |
| Converting a first down | Leveling up → pick an upgrade |
| Downs per series running out | Player HP hitting zero (death) |
| Series/down progression | Wave number / elapsed-time difficulty scaling |

## Session structure

One endless drive per run:

1. **Team select** — pick one of 4 teams, each with a different base stat
   spread. This is the "character select" screen.
2. **The drive** — continuous top-down running. Downs and series chain forever;
   yardage required and defender pressure both escalate the longer the drive
   goes.
3. **Turnover on downs** — when a down is used up (via a failed tackle-break)
   and no downs remain in the series, the run ends. Game-over screen shows
   total yards and series reached, then returns to team select.

## Systems

### Movement & the stiff-arm

The player has full 8-directional movement (WASD/arrows). Forward progress
(moving toward the far end of the field) is what counts as yardage — moving
sideways or backward doesn't gain yards, and moving backward actually costs
you ground you already gained on the current down (see "Downs & yardage"
below).

An automatic "stiff-arm" fires on a cooldown, damaging/staggering every
defender within a radius around the player. This is the auto-attack:

- **Radius** scales with **Awareness**.
- **Cooldown** shortens with **Agility**.
- **Damage** (and tackle-break odds) scales with **Power**.

### Downs & yardage

- Each down attempt has a fixed **line of scrimmage** (a world position) and a
  **marker distance** (`yards_to_go`) ahead of it. The marker is anchored to
  that fixed world position — it does **not** move as the player moves back
  and forth. Only the "yards remaining" readout changes as the player's
  distance from the fixed marker changes.
- Reaching the marker **converts** the down: the line of scrimmage resets to
  the player's current position, the marker distance grows, current down
  resets to 1st, and the game pauses for an upgrade pick.
- Getting **tackled** (see below) uses up a down (`current_down += 1`) without
  moving the marker or the line of scrimmage — exactly like real football,
  the next down continues from wherever you are, chasing the same marker.
- Running out of downs in a series (current down exceeds `downs_per_series`)
  ends the run — turnover on downs.
- **Total yards** (shown in the HUD and on the game-over screen) is net
  downfield distance from the start of the run, not a one-way accumulator —
  it can go down if you retreat.

### Series & escalating distance

- Every 3 conversions, the **series** advances: `downs_per_series` increases
  by 1 (you get more attempts per series as it gets harder), matching the
  request that "the number of downs you get per series increases."
- The amount the marker distance grows **per conversion** (`yards_to_go_step`)
  also increases by 1 every series (1.5 → 2.5 → 3.5 → 4.5 yards per
  conversion, and so on) — so the distance between downs compounds over time
  instead of growing at a flat rate.

### Tackling

Defenders have a small "tackle" range around themselves. When the player
enters it, a break-chance roll happens:

- Break chance = `0.08 + power*0.02 + agility*0.025` (capped at 0.85).
- **Success:** the defender is knocked back and staggered; no down is used.
- **Failure:** if the **Hurdle** ability is unlocked and off cooldown, the
  player automatically hurdles over the defender instead (brief invulnerability
  + hop animation) — no down used, defender is bumped aside rather than
  destroyed. Otherwise, the tackle succeeds: a down is used and the player
  gets a brief invulnerability window.

### Stats (all teams share the same 4 stats, different base values)

| Stat | Effect |
|---|---|
| **Speed** | Movement speed |
| **Power** | Stiff-arm damage; contributes to tackle-break chance |
| **Agility** | Stiff-arm cooldown (attack rate); contributes to tackle-break chance |
| **Awareness** | Stiff-arm radius |

### Teams (team select)

| Team | Color | Identity |
|---|---|---|
| Comets | Blue | Fast, agile, fragile — high speed/agility, low power |
| Anvils | Red | Bulldozer — high power, low speed/agility |
| Ironclads | Green | Balanced, longest stiff-arm reach (highest awareness) |
| Wraiths | Purple | High-risk juke specialist — very high agility |

Team color is used only for the team-select button art; the in-game player
sprite is a plain off-white uniform for every team (an early version tinted
the sprite with the team color via `modulate`, which read as a neon glow on
saturated colors like the Wraiths' purple — removed in favor of a fixed
off-white look).

### Upgrades

On every first-down conversion, the game pauses and offers 3 random picks
from a shared pool of stat boosts and abilities. Picking the same entry again
levels it up (shown as "Lv X → Y" or "x N" in the picker and in the HUD
upgrade grid).

**Stat upgrades** (flat, repeatable, no cap):

- Speed +12, Power +2, Agility +2, Awareness +15

**Abilities** (unlockable, level up, capped):

- **Hurdle** (max level 5) — auto-hurdle instead of getting tackled, on a
  cooldown that shrinks each level (2.5s down to a 1.0s floor).
- **Offensive Lineman** (max level 2) — spawns a permanent escort ally (reuses
  the player's own sprite) that runs alongside the player and instantly
  flattens any defender that touches it. A second pick adds a second lineman
  on the other flank.
- **Spin Move** (max level 4) — a periodic automatic burst that knocks back
  every defender within radius 90 and grants a 1.5x speed boost for 1 second;
  the cadence speeds up each level (4.0s down to a 1.5s floor).

Once an ability hits its max level, it stops appearing in the upgrade pool.

### Defenders & difficulty scaling

Defenders spawn continuously ahead of the player and chase toward his current
position. Difficulty is driven by **whichever is higher** of two curves:

- Elapsed real time in the drive (ramps over ~90 seconds to max).
- Down progress (`conversions`, ramps over 10 conversions to max).

This means a fast player who converts downs quickly ramps difficulty just as
much as one who simply survives a long time. Difficulty controls defender HP
(1 up to 4 hits to kill) and speed (60–110 px/s), and — separately — the
**number of defenders spawned per wave** increases with the series count
(`1 + series_count / 2` defenders per spawn tick), so pushing deep into a run
means facing genuinely larger waves, not just tougher individual defenders.

### Non-interactive dressing

Two referees (sideline and on-field, sharing one sprite) jog along with the
play at fixed offsets from the player. They're purely decorative — no
collision or gameplay interaction — there to make the field feel alive.

## Visual style

Retro pixel art throughout, generated via ComfyUI (local SD-based
`z-image-turbo` template) and post-processed inside Godot (chroma-key
flood-fill to transparency, crop to content, nearest-neighbor downsample for
a chunky low-res look). Project-wide nearest-neighbor texture filtering keeps
everything crisp instead of blurry when scaled.

- **Field:** tileable mowed-grass turf texture (infinitely repeating via a
  huge `region_rect` + `texture_repeat`), procedural white yard lines/sidelines,
  and a pair of generated first-down marker pylons (with flags) planted at
  both sidelines on the fixed marker line, connected by a yellow line.
- **Characters:** full-body running sprites, not just heads —
  - Player: modern helmet + off-white uniform.
  - Defenders: vintage leather helmet (no facemask requested, though the
    model kept drawing a modern-style cage anyway — accepted since the worn
    leather texture and cream/brown palette still read as clearly distinct
    from the player) + wool jersey/pads.
  - Offensive Lineman ally reuses the player's own body sprite.
  - Referees: black-and-white striped ref sprite, shared by both instances.
- **UI:** a single retro navy/orange checkered panel style and rounded-orange
  button style (both `StyleBoxTexture`, 9-sliced) reused across team select,
  the HUD panels, the upgrade picker, and the game-over screen. Small HUD
  badges (the upgrades grid) use a separate flat navy/orange `StyleBoxFlat` —
  the big checkered texture looked muddy stretched down to badge size.

## HUD layout (run scene)

- **Top-left:** down & distance, series/downs-per-series, total yards.
- **Below that:** an "UPGRADES" panel with a 2-column grid of badges, one per
  distinct upgrade/ability picked so far, showing its current count/level.
- **Top-right:** a "STATS" panel with live Speed/Power/Agility/Awareness
  values, updating immediately as upgrades land.

## Known balance note (not yet addressed)

Early Power/Agility upgrades can let the stiff-arm one-shot defenders right at
the edge of its radius, before they ever reach tackle range — a stationary
player can become briefly untouchable. Likely fix: have defender HP scaling
outpace power scaling more aggressively, and/or increase spawn density faster
early on.

## Out of scope / not implemented

- No sound.
- No actual "Balatro" card-based mechanics despite the project name — the
  brief settled on a Vampire-Survivors-style crawler instead.
- No 3D assets from Blender were used in the end (2D top-down was chosen for
  speed of iteration); Blender and ComfyUI were both confirmed connected at
  the start but only ComfyUI ended up in the production pipeline.
