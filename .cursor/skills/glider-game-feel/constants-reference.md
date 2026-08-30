# Glider Feel — Constants Reference

**Physics kernel:** `scripts/player/glider_physics.gd`  
**Orchestration / orientation:** `scripts/player/glider_player.gd`

## Height bands (meters)

| Constant | Value | Role |
|----------|-------|------|
| `BASE_HEIGHT` | 0.75 | Hover repulsion target center |
| `BASE_HEIGHT_NOISE_RATIO` | 0.10 | ±10% smooth noise on grounded target |
| `GLIDE_ENTER_HEIGHT` | 0.90 | Air→terrain deck blend starts (~BASE × 1.2) |
| `HOVER_ZONE` | 1.12 | GROUNDED → GLIDING launch boundary |
| `GLIDE_EXIT_HEIGHT` | 1.10 | GLIDING → GROUNDED land boundary (hysteresis) |
| `TOUCH_CLEARANCE` | 0.05 | Emergency repulsion boost when compressed |

## Manual jump (`apply_inertia_jump`)

| Constant | Default | Effect |
|----------|---------|--------|
| `JUMP_MAX_CLEARANCE` | 1.35 | Target clearance for standstill/low-clearance jump pop (decoupled from `HOVER_ZONE`) |
| `JUMP_UP_BASE` | 1.15 | Minimum upward speed component before speed scaling |
| `JUMP_UP_SPEED_SCALE` | 0.12 | Extra up-speed per m/s tangent speed |
| `JUMP_UP_MAX` | 3.0 | Up-speed cap |
| `JUMP_COOLDOWN` | 0.4 | Grounded re-jump lockout (s) |

Charge pose: hold jump on ground → `jump_charge` anim state (0.5s xfade in/out); release → launch.

## Repulsive hover (`compute_hover_force` + `apply_velocity_constraints` + player noise)

One-sided cushion: repulsion only when **below** target (`penetration = max(0, target − clearance)`). Constant **weight** when rear-supported — no clearance-proportional chase. Clearance spikes from void under the nose disable weight, use supported clearance for physics, and detach to **GLIDING**; momentum carries you off the lip.

| Constant | Default | Effect |
|----------|---------|--------|
| `HOVER_REPULSION_K` | 4200 | Quadratic stiffness (`k × penetration²`) |
| `HOVER_REPULSION_POWER` | 2.0 | Repulsion curve exponent (magnet-like) |
| `HOVER_WEIGHT_GRAVITY` | 12.5 | Constant weight when supported (not clearance-chase); tuned near `AIR_GRAVITY` |
| `HOVER_REPULSION_SOFT_START` | 0.04 | Smooth repulsion onset band at target (m) |
| `HOVER_DAMPING` | 21 | Vertical oscillation damping |
| `HOVER_IDLE_DAMPING_SCALE` | 2.2 | Extra damping when idle |
| `HOVER_SPRING_DEADBAND` | 0.03 | Freeze micro-corrections at rest |
| `HOVER_MOVING_REPULSION_SCALE` | 1.28 | Stiffer repulsion while cruising |
| `HOVER_SLOW_SPEED_REF` | 5.0 | Speed reference for upward follow cap |
| `HOVER_CLEARANCE_RATE_SOFTEN` | 1.8 | Soften repulsion when clearance changes fast (crest lips) |
| `HOVER_CLEARANCE_RATE_MIN_SCALE` | 0.42 | Repulsion scale floor during fast clearance changes |
| `HOVER_MAX_NORMAL_SPEED` | 2.75 | Cap upward follow speed along ground normal |
| `HOVER_SLOW_MAX_NORMAL_SPEED` | 1.85 | Tighter upward cap at crawl speed |
| `HOVER_CLEARANCE_AVG_BLEND` | 0.62 | Player: blend min corner + footprint avg when min drops fast |
| `HOVER_CLEARANCE_BLEND_RATE` | 0.85 | Player: min-clearance drop rate (m/s) that triggers footprint blend |

Player `_update_base_height_noise` adds layered sin noise to `ctx.base_height_offset` while grounded. **No Y teleports** on flat ground — repulsion + weight own vertical motion. Steep downhill surf uses a normal spring force (`compute_surf_contact_force` in `_integrate_forces`).

## RigidBody integration (`glider.tscn` + `_integrate_forces`)

| Property / constant | Default | Effect |
|---------------------|---------|--------|
| `mass` | 90 | Board+rider inertia; scales all `compute_*_force` outputs |
| `gravity_scale` | 0 | World gravity off; custom air/hover gravity via forces |
| `axis_lock_angular_x/z` | true | Pitch/roll stay on Visual |
| `apply_velocity_constraints` | — | Single post-force pass for speed caps, surf normal absorb, hover idle settle |
| `SURF_CONTACT_FORCE_K` | 800 | Surf spring stiffness × mass |
| `SURF_CONTACT_TOLERANCE` | 0.04 | Deadband before surf spring applies |
| `SURF_CONTACT_MAX_FORCE` | 12000 | Per-step surf spring cap |

## Forward support loss (crest / cliff)

When the nose/ahead probes see a drop but the tail is still supported, hover weight turns off, physics reads rear-supported clearance, and the glider detaches to **GLIDING** — coasting off naturally instead of chasing the void.

| Constant | Default | Effect |
|----------|---------|--------|
| `CREST_LIP_NOSE_DROP` | 0.25 | Tail-vs-nose clearance gap that signals support loss (m) |
| `CREST_LIP_AHEAD_DROP` | 0.45 | Center-vs-forward-probe cliff gap for support loss (m) |
| `SUPPORT_LOST_CLEARANCE_RATE` | 1.0 | Min-clearance rise rate (m/s) that signals support loss |

Behavior: `_forward_support_lost()` disables hover weight, reads rear-supported clearance for physics, skips board-level Y snaps, and enters **GLIDING** on gentle terrain. Repulsive hover never chases a dropping probe reading.

## Slope skim landing

| Constant | Default | Effect |
|----------|---------|--------|
| `SLOPE_SKIM_LAND_CLEARANCE` | `CONTACT_MAX_DROP + 0.18` (~1.38 m) | GLIDING→GROUNDED skim latch on steep downhill (uses downhill speed, not flat-yaw facing) |

## Ground horizontal (`compute_ground_force`)

| Constant | Default | Effect |
|----------|---------|--------|
| `GROUND_ACCEL` | 10.5 | Base thrust |
| `CRUISE_GROUND_ACCEL` | derived | Sail cruise thrust |
| `MAX_GROUND_SPEED` | 22.0 | Boost speed cap |
| `CRUISE_SPEED_SCALE` | 0.88 | Cruise cap as fraction of max (was 0.75) |
| `CRUISE_MAX_GROUND_SPEED` | derived | Cruise speed cap (~19.4 m/s) |
| `GROUND_SLOPE_GRAVITY` | 17.5 | Downhill pull (× sin θ) |
| `SLOPE_DRIVE_BLEND` | 0.52 | Thrust mixed toward downhill |
| `GROUND_ROLLING_DRAG` | 0.36 | Rolling resistance |
| `CRUISE_THRUST_DRAG_SCALE` | 0.42 | Lower drag while sail thrust active |
| `COAST_FRICTION` | 1.05 | Coast-down friction on flat |
| `BRAKE_GROUND_FRICTION` | 5.0 | Brake deceleration |

## Air (`compute_air_force`) — speed-balanced glide

Lift scales with forward speed; gravity always on. Fast crest launches hang longer, then arc steepens as speed bleeds off (induced drag).

| Constant | Default | Effect |
|----------|---------|--------|
| `AIR_GRAVITY` | 14.5 | Downward acceleration (tuned near hover weight for smoother ground↔air transitions) |
| `LIFT_COEFF` | 1.0 | Lift per m/s forward speed |
| `LIFT_STALL_SPEED` / `LIFT_FULL_SPEED` | 4.5 / 11 | Lift ramp (stall below min speed) |
| `MAX_LIFT` | 17 | Lift cap |
| `SAIL_LIFT_SCALE` | 1.08 | Sail lift multiplier |
| `BOOST_LIFT_SCALE` | 1.32 | Boost lift multiplier |
| `PASSIVE_MAX_LIFT_RATIO` | 0.60 | Max lift as fraction of gravity (passive) |
| `PASSIVE_MAX_LIFT_RATIO × SAIL_LIFT_SCALE` | ~0.65 | Max lift cap when sail deployed |
| `BOOST_MAX_LIFT_RATIO` | 0.90 | Max lift as fraction of gravity (boost) |
| `STALL_GRAVITY_SCALE` | 1.35 | Extra gravity below stall speed |
| `INDUCED_DRAG_COEFF` | 0.014 | Speed bleed when generating lift |
| `PASSIVE_AIR_DRAG` | 0.10 | Horizontal coast decay |
| `MIN_GLIDE_SPEED` | 6.0 | Speed floor **only when boosting** |

No forward thrust in air except **boost** (jet exception). Physics keys off `ctx.sail_deployed`.

## Touchdown (`apply_touchdown`)

| Constant | Default | Effect |
|----------|---------|--------|
| `LAND_SOFT_NORMAL_KEEP` | 0.4 | Fraction of downward normal kept on soft land |
| `LAND_SKIM_DOWNHILL_CONVERT` | 0.35 | Downhill skim: extra normal → tangent on steep slopes |
| `LAND_NORMAL_TO_TANGENT` | 0.78 | Skim: convert inward normal speed into tangent momentum |
| `LAND_TANGENT_KEEP_MIN` | 1.0 | Skim/fall: never drop below pre-land tangent speed |
| `LAND_FALL_TANGENT_KEEP` | 0.88 | Fall landings: minimum tangent vs approach speed |
| `LAND_IMPACT_TO_SLIDE_SKIM` | 1.0 | Skim impact-to-slide scale (vs 0.85 default) |
| `LAND_FALL_NORMAL_ABSORB` | 0.28 | Fall slide impulse |
| `LAND_HARD_SPEED` | 5.5 | Soft vs hard normal absorption |
| `LAND_ALIGN_DURATION` | 0.25 | Brief deck align after land |

## Pre-land alignment (`_prepare_landing_approach`)

Starts while gliding with valid board probes and air gap ≤ start height. Blend is height-driven (not timed): 0% at start height, 100% at done height, hard snap at/below snap height.

| Constant | Default | Effect |
|----------|---------|--------|
| `LAND_ALIGN_START_HEIGHT` | 5.0 | Begin terrain deck align (m above ground) |
| `LAND_ALIGN_DONE_HEIGHT` | 1.0 | Target fully aligned by this height (m) |
| `LAND_ALIGN_SNAP_HEIGHT` | = done | Hard snap deck + ground normal at/below |
| `LANDING_APPROACH_HEIGHT` | 2.0 | Final flare + board-level band (m) |
| `LAND_ALIGN_APPROACH_MAX_STEP_DEG` | 18 | Max deck basis step near touchdown |

While **gliding**, predictive probes use **unclamped** terrain heights so high-air landings read real slope (grounded probes still clamp via `CONTACT_MAX_DROP`). Pre-land align runs between start/done heights when descending (or throughout the final `LANDING_APPROACH_HEIGHT` band).
## Slope surf (Skate-inspired ramp stick)

Active when grounded on steep downhill (`ctx.slope_surf_active`). Replaces hover-band negotiation with surface-slide constraint.

| Constant | Default | Effect |
|----------|---------|--------|
| `SURF_LOW_CLEARANCE` | 0.35 | Compressed hover target at full surf speed |
| `SURF_SPRING_SCALE` | 0.12 | Weak upward spring while surfing |
| `SURF_DAMP_SCALE` | 1.8 | Extra normal damping on slopes |
| `SURF_SPEED_MIN` / `SURF_SPEED_FULL` | 2.0 / 10.0 | Speed ramp for surf target clearance |
| `SLOPE_SURF_LOCK_DURATION` | 0.6 | Post-skim relaunch guard (player re-export) |

## Predictive terrain probes (`terrain_probes.gd` + player)

Multi-direction downward samples each frame. Competing normals resolve by **vector average** (`average_normals`); deck pitch uses **plane-fit** normal through probe hit points (`fit_plane_normal`).

| Constant | Default | Effect |
|----------|---------|--------|
| `PREDICT_PROBE_FORWARD_DISTANCE_NEAR` | 1.5 | Forward fan near ring (m) |
| `PREDICT_PROBE_FORWARD_DISTANCE_MID` | 3.0 | Forward fan mid ring (m) |
| `PREDICT_PROBE_FORWARD_DISTANCE_FAR` | 5.0 | Forward fan far ring (m) |
| `PREDICT_PROBE_LATERAL` | 0.35 | Left/right offset on forward fan (m) |
| `PREDICT_PROBE_VELOCITY_LOOKAHEAD` | 3.0 | Extra probe along horizontal velocity (m) |

Probe layout per frame: 4 board corners + nose/tail/center + 3×3 forward fan + optional velocity probe. Outputs feed `_predictive_normal` (averaged) and `_predictive_pitch_normal` (plane-fit) for grounded align, surf, landing approach, and post-land. Airborne gap detection (`_raw_clearance`) still uses **unclamped** corner rays.

## Crest launch

| Constant | Default | Effect |
|----------|---------|--------|
| `LAUNCH_NORMAL_SPEED` | 2.8 | Crest launch upward threshold |
| `AIR_LAUNCH_HOLD` | 0.45 | Post-launch orientation window |

## Orientation (player script)

| Constant | Default | Effect |
|----------|---------|--------|
| `TERRAIN_BASIS_RATE` | 10 | Grounded deck→terrain |
| `AIR_VELOCITY_ALIGN_RATE` | 6 | Air deck→velocity |
| `DECK_ALIGN_STRENGTH` | 1.0 | Max terrain alignment blend (full at/below hover band) |
| `SLOPE_ALIGN_FULL_STRENGTH` | 1.0 | Full conform on steep slopes / surf |
| `DECK_ALIGN_NOISE_DEG` | 0.6 | Small pitch/roll wobble (suppressed near ground) |
| `DECK_ALIGN_NOISE_RATE` | 0.25 | Deck alignment noise frequency |
| `TERRAIN_ALIGN_HEIGHT` | = HOVER_ZONE | Terrain blend start |
| `TERRAIN_ALIGN_FULL_HEIGHT` | = GLIDE_ENTER | Full terrain blend |

## Verify tests (`verify_glider.gd`)

1. `hover_rest` — idle settles at 0.75 ± 0.12 m
2. `terrain_probes_math` — averaged normals + plane-fit ramp
3. `predictive_surface_sampling` — grounded probe fan + bounded deck basis steps
4. `hover_height_noise` — grounded offset stays within ±10% of base over 120 frames
5. `ground_cruise` — flat W-held stays grounded, builds speed, keeps clearance
6. `slope_no_clip` — downhill 60 frames, clearance ≥ −0.08 m
7. `slope_skim_stays_grounded` — steep downhill holds GROUNDED after building speed
8. `touchdown_skim_momentum` — skim landing retains ≥90% tangent speed
9. `touchdown_flat_momentum` — fast flat skim keeps ≥95% horizontal speed
10. `glide_gravity` — passive glide loses altitude
11. `glide_lift` — sail meaningfully reduces descent vs passive
12. `glide_speed_balance` — faster speed loses less height than slow over same airtime
13. `glide_ballistic` — passive arc carries forward with gravity-led drop
14. `glide_no_cruise_thrust` — no W: horizontal speed decays in air
15. `brake_stop` — brake cuts speed on ground
16. `touchdown_soft` — small hop, low oscillation
17. `charge_boost` — boost ≥ cruise speed
