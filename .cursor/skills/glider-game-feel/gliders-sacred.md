# Glider Sacred — design constraints

Non-negotiables for Energy Glider. Filter survival, tower, harvest, and on-foot features through this list.

1. **Momentum is the game.** Cruise forward → carry speed → line the next slope → boost when you need more. Do not add systems that punish normal surfing rhythm. **Slope gravity** scales with steepness on the ground; in the air, **full gravity** plus **speed-dependent lift** (slow hops fall fast, fast crests carry). No clearance-based zero-g — lift comes from forward speed and sail/boost only.

2. **Two modes, one vertical owner.** `GROUNDED` = hover spring owns height. `GLIDING` = ballistic air only. State flips at `HOVER_ZONE` — no glide-in-hover-band overlap.

3. **W is cruise; Shift is boost.** Hold **W** for solar-sail cruise at 75% of legacy thruster speed (no power cost). Hold **Shift** while cruising for a powered boost that drains the meter. Power recharges while holding **W** without **Shift** — no release-to-recharge loop. Empty boost triggers an overheat cooldown (`THRUSTER_OVERHEAT_DURATION`); cruise continues. **W is sail — mildly weaker uphill. Shift is thrusters — full flat-ground drive uphill (no sail penalties). You surf climbs; you don't glide them.**

4. **Launch orientation follows velocity.** On crest takeoff, yaw snaps to travel direction; airborne attitude uses `_align_air_attitude` (not terrain tilt) so the board does not twist ~90° after leaving the sand.

5. **Survival at stops and hub, not mid-flow.** Harvest, install parts, and inventory live at anomalies, ruins, and the tower — not during active traversal.

6. **Failure = recover and glide again** (for now). Stranded states should be recoverable on foot or via recharge lines, not instant hard game-over without player agency.

7. **Boost is always available.** Shift boost works from run start. Tower upgrades may enhance boost later.

8. **On-foot is pit-stop scale.** Dismount for harvest, heat bleed, or cargo — then remount and return to flow. Not a second game mode.

9. **No combat in v1.** Tension from flux, heat, distance from tower, and route choice — not enemy encounters.

10. **Wind is atmosphere, not physics.** A slowly rotating global wind field weathervanes the sail mesh and drives ambient air-streak VFX. It must **not** change glider speed, steering, or route planning — no tail/head/crosswind forces, no compass HUD.

When proposing a feature, ask: *Does this make the next glide leg feel better, or does it interrupt flow?*
