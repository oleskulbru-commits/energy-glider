# Glider Feel — Tuning Checklist

## verify_glider test map

| Test | What it guards |
|------|----------------|
| `_verify_slope_contact` | No terrain clip on steep slope; body upright; visual tilts |
| `_verify_downhill_contact` | No stair-step Y hops (≤5 hops); bounce window |
| `_verify_hover_rest` | Idle settles near 0.75 m clearance |
| `_verify_hover_height_noise` | Grounded height offset stays within ±10% of base |
| `_verify_soft_landing` | Drop from height: recovers fast, bounce ≤0.20 m |
| `_verify_landing_attitude` | Board aligns to slope pitch on approach and land |
| `_verify_hard_landing_dust` | Impact dust on hard land; reaches surf zone |
| `_verify_uphill_climb` | Maintains speed and gains elevation when boosting uphill |
| `_verify_downhill_momentum` | Builds speed going downhill |
| `_verify_shallow_downhill_surf` | Flows on gentle slopes |
| `_verify_crest_momentum` | Carries speed over crests |
| `_verify_cliff_launch_tilt` | Readable tilt on cliff launch |
| `_verify_aerial_momentum` | Airborne momentum preserved |
| `_verify_smooth_visual_tilt` | Visual tilt changes smoothly frame-to-frame |
| `_verify_charge_system` | Boost drain/recharge behavior |
| `_verify_readability_helpers` | `is_grounded()`, `get_clearance()` thresholds |
| `_verify_camera_floor` | Camera stays above terrain floor |

Run order is defined in `verify_glider.gd` `_run_test()`.

## Manual F5 checklist

After headless pass, play in editor:

- [ ] **Idle hover** — release input on flat sand; board hovers ~0.75 m with smooth organic drift, no rail-snapping
- [ ] **Downhill surf** — hold forward on moderate slope; smooth flow, no stair-step bounce
- [ ] **Steep downhill** — speed builds, board follows terrain visually
- [ ] **Uphill + boost** — can climb moderate dunes without stalling
- [ ] **Crest launch / land** — board leaves sand, transitions to glide naturally; soft settle on return
- [ ] **Hard land** — impact dust visible, no deep clip
- [ ] **Steer** — bank/readable turn at speed; no camera floor poke
- [ ] **Charge** — boost feels punchy; recharges while gliding/coasting

## Tuning discipline

1. **One subsystem per iteration** — e.g. only hover spring, or only land damp
2. **Log before/after** — note which constants changed and by how much (%)
3. **Revert fast** — if two unrelated tests fail, undo and try smaller step
4. **Prefer rates over thresholds** — slerp/lerp rates are safer than hard snaps
5. **Separate physics from juice** — get clearance/landing right before camera/particles

## Complaint → first knobs to try

| User says | Start here |
|-----------|------------|
| "Choppy / bouncy downhill" | `HOVER_DESCENT_SPRING_SCALE`, `DESCENT_PENETRATION_LIMIT`, `CONTACT_SMOOTH_RATE`, `CLEARANCE_SMOOTH_RATE` |
| "Clips into sand" | `HOVER_REPULSION_K`, `SURF_CONTACT_FORCE_K` in `glider_physics.gd` |
| "Floaty" | `HOVER_REPULSION_K` ↓, `HOVER_DAMPING` ↑ |
| "Slams down on land" | `LAND_DAMP_SCALE` ↑, `LAND_SPRING_SCALE` ↓, `LAND_DAMP_DURATION` ↑ |
| "Lands crooked" | `DECK_ALIGN_STRENGTH`, `TERRAIN_BASIS_RATE`, `DECK_ALIGN_NOISE_DEG` |
| "Can't climb" | `CLIMB_ACCEL_SCALE`, `UPHILL_GRAVITY_SCALE`, `CLIMB_BOOST_SCALE` |
| "Feels slow downhill" | `GROUND_SLOPE_GRAVITY`, `SLOPE_ACCEL_SCALE`, `GROUND_ROLLING_DRAG` ↓ |
| "Camera weird" | `FOCUS_RATE_Y`, `CLEARANCE_FOCUS_BLEND`, `MIN_CAMERA_GROUND_CLEARANCE` |

See [constants-reference.md](constants-reference.md) for full knob descriptions.
