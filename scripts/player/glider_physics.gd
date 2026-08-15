class_name GliderPhysics
extends RefCounted

## Minimal force kernel for the glider. No nodes, no raycasts.

# Height bands
const BASE_HEIGHT := 0.75
const GLIDE_ENTER_HEIGHT := 0.90
const GLIDE_EXIT_HEIGHT := 1.10
const HOVER_ZONE := 1.12
const TOUCH_CLEARANCE := 0.05
const GROUND_CONTACT_CLEARANCE := 0.0
const GROUND_CLIP_MAX := -0.06
const HOVER_COMPRESS_START := 0.42
const HOVER_YIELD_SPEED := 5.0
const HOVER_BREAK_SPEED := 7.5
const CONTACT_DAMAGE_SPEED_SOFT := 6.0
const CONTACT_DAMAGE_PER_MPS := 0.035
const CONTACT_MAX_DAMAGE := 0.35
const CONTACT_RECOVER_DURATION := 0.4
const CONTACT_SCRAPE_DRAG := 2.8

# Ground
const GROUND_ACCEL := 10.5
const MAX_GROUND_SPEED := 22.0
const MAX_SURF_SPEED := 28.0
const BOOST_MULTIPLIER := 1.85
## Boost top-speed ceiling relative to cruise (accel still uses BOOST_MULTIPLIER).
const BOOST_SPEED_FACTOR := 1.3
## Hard ceiling for any horizontal speed (boost or cruise). Upgrades cannot exceed this.
const BOOST_ABSOLUTE_MAX := 100.0
## Cruise ceiling so cruise * BOOST_SPEED_FACTOR never exceeds BOOST_ABSOLUTE_MAX.
const CRUISE_ABSOLUTE_MAX := BOOST_ABSOLUTE_MAX / BOOST_SPEED_FACTOR
const AIR_BOOST_EXTRA_SCALE := 1.15
const CRUISE_SPEED_SCALE := 0.95
# Ground — XZ target-speed model (slope component along travel)
## Flat cruise max (= MAX_SURF_SPEED * CRUISE_SPEED_SCALE ≈ 26.6).
const FLAT_MAX_SPEED := MAX_SURF_SPEED * CRUISE_SPEED_SCALE
const CLIMB_MIN_SPEED := 4.0
const FLAT_ACCEL := 14.0
## Strong enough to reach boost max on any climb before charge runs out.
const BOOST_ACCEL := 36.0
const COAST_DECEL := 3.0
const BRAKE_DECEL := 18.0
## Bleed from boost surplus down to cruise target (W still held, Shift released).
const SURPLUS_DECEL := 5.5
## Climb grade that fully drops cruise max to CLIMB_MIN_SPEED; also scales downhill accel bonus.
const UPHILL_GRADE_REF := 0.35
const DOWNHILL_ACCEL_BONUS := 0.85
const CONTACT_SCRAPE_DIG_SCALE := 0.25
const COAST_DURATION := 4.0
const STEEP_CLIMB_GRADE := 0.13
const CLIMB_DRAG_MIN_GRADE := 0.10
const CLIMB_FACING_THRESHOLD := -0.08
## Legacy aliases used by caps / player state.
const CRUISE_MAX_GLIDE_SPEED := FLAT_MAX_SPEED
const CARRY_MAX_GROUND_SPEED := FLAT_MAX_SPEED
const CRUISE_MAX_GROUND_SPEED := MAX_GROUND_SPEED * CRUISE_SPEED_SCALE
const BOOST_MAX_GROUND_SPEED := CRUISE_MAX_GROUND_SPEED * BOOST_SPEED_FACTOR
const BOOST_MAX_SURF_SPEED := FLAT_MAX_SPEED * BOOST_SPEED_FACTOR
const CRUISE_GROUND_ACCEL := FLAT_ACCEL

# Air
const AIR_GRAVITY := 14.5
const LIFT_COEFF := 1.0
const LIFT_STALL_SPEED := 4.5
const LIFT_FULL_SPEED := 11.0
const MAX_LIFT := 17.0
const SAIL_LIFT_SCALE := 1.08
const BOOST_LIFT_SCALE := 1.32
const PASSIVE_MAX_LIFT_RATIO := 0.60
const BOOST_MAX_LIFT_RATIO := 0.90
const STALL_GRAVITY_SCALE := 1.35
const PASSIVE_AIR_DRAG := 0.10
const SAIL_AIR_DRAG := 0.09
const INDUCED_DRAG_COEFF := 0.014
const GLIDE_POWERED_DRAG := 0.22
const MIN_GLIDE_SPEED := 6.0
const BRAKE_GLIDE_DRAG_SCALE := 2.25

# Hover
const HOVER_REPULSION_K := 4200.0
const HOVER_REPULSION_POWER := 2.0
const HOVER_WEIGHT_GRAVITY := 12.5
const HOVER_REPULSION_SOFT_START := 0.04
const HOVER_DAMPING := 21.0
const HOVER_RECOVERY_K := 80.0
const HOVER_IDLE_DAMPING_SCALE := 2.2
const HOVER_SPRING_DEADBAND := 0.03
const HOVER_MOVING_REPULSION_SCALE := 1.28
const HOVER_SLOW_SPEED_REF := 5.0
const HOVER_IDLE_SETTLE_NVEL := 0.12
const HOVER_MAX_NORMAL_SPEED := 2.75
const HOVER_SLOW_MAX_NORMAL_SPEED := 1.85
const HOVER_CLEARANCE_RATE_SOFTEN := 1.8
const HOVER_CLEARANCE_RATE_MIN_SCALE := 0.42
# Per-corner suspension — tuned so flat-ground total ≈ central quadratic hover.
const HOVER_POINT_SPRING_K := 84.0
const HOVER_POINT_DAMPING := 5.25
const HOVER_POINT_MAX_ACCEL := 42.0
const HOVER_POINT_MAX_ACCEL_CLIMB_SCALE := 1.65
const HOVER_POINT_REFERENCE_PENETRATION := 0.06
const CLIMB_NORMAL_SPEED_SCALE := 1.28
const CLIMB_MAX_NORMAL_SPEED := 8.25
const CLIMB_REPULSION_GRADE_REF := 0.22

# Air — crest lip detach ramps gravity in over this duration (≈25% longer float).
const AIR_GRAVITY_RAMP_DURATION := 0.25

# Manual jump — upward pop scales with tangent speed; momentum is preserved.
const JUMP_COOLDOWN := 0.4
const JUMP_MAX_CLEARANCE := HOVER_ZONE
const JUMP_MIN_TANGENT_SPEED := 1.5
const JUMP_UP_BASE := 0.95
const JUMP_UP_SPEED_SCALE := 0.12
const JUMP_UP_MAX := 3.0

# Landing
const HARD_LAND_SPEED := 8.5
const LAND_DAMP_APPROACH := 2.8
const LAND_NORMAL_ABSORB := 0.58
const LAND_NORMAL_ABSORB_SOFT := 0.72
const LAND_IMPACT_ABSORB := 0.78
const LAND_TANGENT_KEEP := 0.94
const LAND_TOUCHDOWN_FLATTEN_GRADE := 0.35
const LAND_TOUCHDOWN_FLATTEN_SPEED := 18.0
const LAND_HORIZONTAL_SPEED_CAP := 1.05
const LAND_MAX_INWARD_NORMAL_SOFT := 0.08
const LAND_MAX_INWARD_NORMAL_HARD := 0.35
const LAND_IMPACT_REPULSION_CAP := 3400.0

const MODE_GROUNDED := 0
const MODE_GLIDING := 1


class HoverPointSample:
	var local_offset := Vector3.ZERO
	var clearance: float = 0.0
	var normal := Vector3.UP
	var valid: bool = false


class AppliedHoverForce:
	var force := Vector3.ZERO
	var local_offset := Vector3.ZERO

	func _init(force_vec: Vector3 = Vector3.ZERO, offset: Vector3 = Vector3.ZERO) -> void:
		force = force_vec
		local_offset = offset


class Context:
	var velocity: Vector3 = Vector3.ZERO
	var ground_normal: Vector3 = Vector3.UP
	var board_forward: Vector3 = Vector3.FORWARD
	var thrust_forward: Vector3 = Vector3.FORWARD
	var downhill: Vector3 = Vector3.ZERO
	var clearance: float = 0.0
	var hover_clearance: float = 0.0
	var clearance_change_rate: float = 0.0
	var slope_grade: float = 0.0
	var climbing: bool = false
	var forward_held: bool = false
	var sail_deployed: bool = false
	var boost_active: bool = false
	var braking: bool = false
	var brake_strength: float = 0.0
	var coast_blend: float = 0.0
	var hover_at_rest: bool = false
	var steering: bool = false
	var landing_impact: float = 0.0
	var landing_blend: float = 0.0
	var landing_approach: float = 0.0
	var hover_yield: float = 1.0
	var ground_contact: bool = false
	var contact_recover: float = 1.0
	var air_gravity_scale: float = 1.0
	var ground_drag_scale: float = 1.0
	var glide_drag_scale: float = 1.0
	var thruster_accel: float = 0.0
	var air_thruster_accel: float = 0.0


static func horizontal_velocity(velocity: Vector3) -> Vector3:
	return MathUtil.horizontal(velocity)


static func clamp_tangent_speed(tangent_vel: Vector3, max_speed: float) -> Vector3:
	var speed := tangent_vel.length()
	if speed <= max_speed:
		return tangent_vel
	return tangent_vel * (max_speed / speed)


static func flat_max_speed(boost_active: bool) -> float:
	var max_speed := FLAT_MAX_SPEED
	if boost_active:
		max_speed *= BOOST_SPEED_FACTOR
	return minf(max_speed, BOOST_ABSOLUTE_MAX)


static func cruise_drive_cap(boost_active: bool) -> float:
	return flat_max_speed(boost_active)


static func carry_speed_cap(boost_active: bool) -> float:
	return flat_max_speed(boost_active)


## Hard velocity ceiling (boost max). Soft cruise/boost targets ease via forces — never snap here.
static func hard_speed_cap() -> float:
	return flat_max_speed(true)


## Positive = traveling downhill, negative = uphill, ~0 = flat or side-hill.
static func signed_travel_grade(ctx: Context) -> float:
	if ctx.slope_grade <= 0.0001:
		return 0.0
	var travel := horizontal_velocity(ctx.velocity)
	if travel.length_squared() < 0.25:
		travel = MathUtil.horizontal(ctx.board_forward)
	if travel.length_squared() < 0.0001:
		return 0.0
	var downhill_h := MathUtil.horizontal(ctx.downhill)
	if downhill_h.length_squared() < 0.0001:
		return 0.0
	return ctx.slope_grade * travel.normalized().dot(downhill_h.normalized())


static func target_horizontal_speed(ctx: Context) -> float:
	var thrusting := ctx.forward_held or ctx.boost_active
	var brake := clampf(ctx.brake_strength, 0.0, 1.0)
	if not thrusting:
		# Coast / brake toward a stop (brake handled via higher decel rate).
		return 0.0

	var max_speed := flat_max_speed(ctx.boost_active)
	var signed_g := signed_travel_grade(ctx)
	## Boost ignores climb caps — escape card limited only by charge duration.
	if signed_g < 0.0 and not ctx.boost_active:
		var climb_t := clampf((-signed_g) / UPHILL_GRADE_REF, 0.0, 1.0)
		max_speed = maxf(max_speed - FLAT_MAX_SPEED * climb_t, CLIMB_MIN_SPEED)

	if brake > 0.0:
		max_speed *= 1.0 - brake
	return maxf(max_speed, 0.0)


static func horizontal_speed_accel_rate(ctx: Context, speed: float, target: float) -> float:
	if target > speed + 0.05:
		var accel := BOOST_ACCEL if ctx.boost_active else FLAT_ACCEL
		var signed_g := signed_travel_grade(ctx)
		if signed_g > 0.0:
			var down_t := clampf(signed_g / UPHILL_GRADE_REF, 0.0, 1.0)
			accel *= 1.0 + DOWNHILL_ACCEL_BONUS * down_t
		return accel
	if target < speed - 0.05:
		var brake := clampf(ctx.brake_strength, 0.0, 1.0)
		if brake > 0.05:
			return lerpf(COAST_DECEL, BRAKE_DECEL, brake)
		## Above cruise while still thrusting (e.g. just released boost) — ease down, don't snap.
		if ctx.forward_held or ctx.boost_active:
			return SURPLUS_DECEL
		return COAST_DECEL
	return 0.0


static func compute_ground_force(ctx: Context, mass: float, _delta: float) -> Vector3:
	var h := horizontal_velocity(ctx.velocity)
	var speed := h.length()
	var target := target_horizontal_speed(ctx)
	var rate := horizontal_speed_accel_rate(ctx, speed, target)
	if rate <= 0.0001 and absf(target - speed) <= 0.05:
		return Vector3.ZERO

	var board_h := MathUtil.horizontal(ctx.thrust_forward)
	if board_h.length_squared() < 0.0001:
		board_h = MathUtil.horizontal(ctx.board_forward)
	var desired_dir := board_h
	## Ease speed along travel; only gently bias toward board so yaw/drift stay soft.
	if speed > 0.5:
		var travel := h.normalized()
		if (ctx.forward_held or ctx.boost_active) and board_h.length_squared() > 0.0001:
			desired_dir = travel.lerp(board_h.normalized(), 0.1).normalized()
		else:
			desired_dir = travel
	elif desired_dir.length_squared() < 0.0001:
		return Vector3.ZERO
	else:
		desired_dir = desired_dir.normalized()

	var desired_h := desired_dir * target
	var delta_v := desired_h - h
	if delta_v.length_squared() < 0.000001:
		return Vector3.ZERO
	if delta_v.length() > rate:
		delta_v = delta_v.normalized() * rate

	var force := delta_v * mass
	var tangent := force.slide(ctx.ground_normal)
	if tangent.length_squared() > 0.0001:
		return tangent
	return force


static func apply_inertia_jump(
	velocity: Vector3,
	ground_normal: Vector3,
	tangent_speed: float
) -> Vector3:
	var launch_normal := ground_normal.lerp(Vector3.UP, 0.18).normalized()
	var result := velocity
	var inward := result.dot(launch_normal)
	if inward < 0.0:
		result -= launch_normal * inward
	var speed := maxf(tangent_speed, JUMP_MIN_TANGENT_SPEED * 0.35)
	var up_speed := minf(JUMP_UP_BASE + speed * JUMP_UP_SPEED_SCALE, JUMP_UP_MAX)
	var existing_up := result.dot(launch_normal)
	if up_speed > existing_up:
		result += launch_normal * (up_speed - maxf(existing_up, 0.0))
	return result


static func _hover_clearance_for_force(ctx: Context) -> float:
	if ctx.hover_clearance > 0.0:
		return ctx.hover_clearance
	return ctx.clearance


static func hover_compression_scale(clearance: float) -> float:
	if clearance >= BASE_HEIGHT:
		return 1.0
	if clearance <= HOVER_COMPRESS_START:
		return smoothstep(GROUND_CONTACT_CLEARANCE, HOVER_COMPRESS_START, clearance) * 0.2
	return smoothstep(HOVER_COMPRESS_START, BASE_HEIGHT, clearance)


static func hover_impact_yield_scale(
	approach: float,
	landing_impact: float,
	contact_recover: float
) -> float:
	var impact_yield := 1.0
	if approach > HOVER_YIELD_SPEED:
		impact_yield = 1.0 - smoothstep(HOVER_YIELD_SPEED, HOVER_BREAK_SPEED, approach)
		if landing_impact > 0.0:
			impact_yield = minf(impact_yield, 1.0 - landing_impact * 0.85)
	return lerpf(impact_yield, 1.0, contact_recover)


static func hover_strength_scale(ctx: Context) -> float:
	var clearance := _hover_clearance_for_force(ctx)
	var compress := hover_compression_scale(clearance)
	var impact := hover_impact_yield_scale(
		ctx.landing_approach,
		ctx.landing_impact,
		ctx.contact_recover
	)
	if ctx.ground_contact:
		impact = minf(impact, 0.12 + ctx.contact_recover * 0.88)
	return compress * impact * ctx.hover_yield


static func compute_contact_damage(approach: float) -> float:
	if approach <= CONTACT_DAMAGE_SPEED_SOFT:
		return 0.0
	var excess := approach - CONTACT_DAMAGE_SPEED_SOFT
	return clampf(excess * CONTACT_DAMAGE_PER_MPS, 0.0, CONTACT_MAX_DAMAGE)


static func compute_ground_scrape_force(ctx: Context, mass: float) -> Vector3:
	var clearance := _hover_clearance_for_force(ctx)
	if clearance > TOUCH_CLEARANCE:
		return Vector3.ZERO
	var tangent := horizontal_velocity(ctx.velocity).slide(ctx.ground_normal)
	if tangent.length_squared() < 0.01:
		return Vector3.ZERO
	var depth := clampf((TOUCH_CLEARANCE - clearance) / maxf(TOUCH_CLEARANCE, 0.001), 0.0, 1.0)
	var dig := lerpf(CONTACT_SCRAPE_DIG_SCALE, 1.0, depth)
	## Soft scrape only when truly digging — avoid killing XZ momentum near hover height.
	return -tangent.normalized() * tangent.length() * CONTACT_SCRAPE_DRAG * 0.15 * dig * mass


static func touchdown_normal(ground_normal: Vector3, slope_grade: float, horizontal_speed: float) -> Vector3:
	var flatten := clampf(slope_grade / LAND_TOUCHDOWN_FLATTEN_GRADE, 0.0, 0.65)
	flatten += clampf(horizontal_speed / LAND_TOUCHDOWN_FLATTEN_SPEED, 0.0, 0.25) * 0.4
	return ground_normal.lerp(Vector3.UP, flatten).normalized()


static func compute_hover_force(ctx: Context, mass: float, _delta: float) -> Vector3:
	var hover_clearance := _hover_clearance_for_force(ctx)
	var normal_vel := ctx.velocity.dot(ctx.ground_normal)
	var penetration := maxf(0.0, BASE_HEIGHT - hover_clearance)
	var force := Vector3.ZERO
	var strength := hover_strength_scale(ctx)

	if hover_clearance > BASE_HEIGHT + HOVER_SPRING_DEADBAND:
		force -= ctx.ground_normal * HOVER_WEIGHT_GRAVITY * mass * strength
		if absf(normal_vel) > 0.0001:
			force -= ctx.ground_normal * HOVER_DAMPING * normal_vel * mass * strength
		return force

	var repulsion_k := HOVER_REPULSION_K
	var damp := HOVER_DAMPING
	var tangent_speed := horizontal_velocity(ctx.velocity).length()
	if tangent_speed > 1.0 and penetration > 0.0:
		repulsion_k *= HOVER_MOVING_REPULSION_SCALE
	if ctx.hover_at_rest:
		damp *= HOVER_IDLE_DAMPING_SCALE

	if penetration > 0.0 or absf(normal_vel) > 0.0001:
		var repulsion := 0.0
		if penetration > 0.0:
			repulsion = repulsion_k * pow(penetration, HOVER_REPULSION_POWER)
			if HOVER_REPULSION_SOFT_START > 0.0:
				repulsion *= smoothstep(0.0, HOVER_REPULSION_SOFT_START, penetration)
			if (
				hover_clearance >= BASE_HEIGHT
				and ctx.clearance_change_rate > HOVER_CLEARANCE_RATE_SOFTEN
				and not ctx.climbing
				and not ctx.boost_active
			):
				var soften := lerpf(
					HOVER_CLEARANCE_RATE_MIN_SCALE,
					1.0,
					HOVER_CLEARANCE_RATE_SOFTEN / ctx.clearance_change_rate
				)
				repulsion *= soften
			if ctx.landing_impact > 0.0:
				var cap := LAND_IMPACT_REPULSION_CAP * ctx.landing_impact
				repulsion = minf(repulsion, cap)
		force += ctx.ground_normal * (repulsion - damp * normal_vel) * mass * strength

	return force


static func _hover_point_normal(normal: Vector3, reference: Vector3 = Vector3.UP) -> Vector3:
	if normal.length_squared() < 0.0001:
		return reference
	var aligned := normal.normalized()
	if aligned.dot(reference) < 0.0:
		aligned = -aligned
	return aligned


static func _hover_point_repulsion_scale(ctx: Context, penetration: float) -> float:
	var scale := 1.0
	if HOVER_REPULSION_SOFT_START > 0.0:
		scale *= smoothstep(0.0, HOVER_REPULSION_SOFT_START, penetration)
	if (
		penetration > 0.0
		and ctx.clearance_change_rate > HOVER_CLEARANCE_RATE_SOFTEN
		and not ctx.climbing
		and not ctx.boost_active
	):
		scale *= lerpf(
			HOVER_CLEARANCE_RATE_MIN_SCALE,
			1.0,
			HOVER_CLEARANCE_RATE_SOFTEN / ctx.clearance_change_rate
		)
	if ctx.landing_impact > 0.0:
		var cap := LAND_IMPACT_REPULSION_CAP * ctx.landing_impact
		var max_accel := cap / maxf(penetration, 0.001)
		scale = minf(scale, max_accel / maxf(HOVER_POINT_SPRING_K, 0.001))
	return scale


static func compute_corner_hover_forces(
	ctx: Context,
	mass: float,
	_delta: float,
	points: Array
) -> Array:
	var results: Array[AppliedHoverForce] = []
	var valid_count := 0
	for point in points:
		if point is HoverPointSample and point.valid:
			valid_count += 1
	if valid_count == 0:
		return results

	var tangent_speed := horizontal_velocity(ctx.velocity).length()
	var moving_scale := (
		HOVER_MOVING_REPULSION_SCALE
		if tangent_speed > 1.0
		else 1.0
	)
	var idle_damp_scale := HOVER_IDLE_DAMPING_SCALE if ctx.hover_at_rest else 1.0
	var strength := hover_strength_scale(ctx)
	var max_accel := HOVER_POINT_MAX_ACCEL
	if ctx.climbing and (ctx.forward_held or ctx.boost_active):
		max_accel *= lerpf(
			1.0,
			HOVER_POINT_MAX_ACCEL_CLIMB_SCALE,
			clampf(ctx.slope_grade / CLIMB_REPULSION_GRADE_REF, 0.0, 1.0)
		)

	for point in points:
		if not point is HoverPointSample or not point.valid:
			continue

		var normal := _hover_point_normal(point.normal, ctx.ground_normal)
		var normal_vel := ctx.velocity.dot(normal)
		var penetration := maxf(0.0, BASE_HEIGHT - point.clearance)
		var accel := 0.0

		if point.clearance > BASE_HEIGHT + HOVER_SPRING_DEADBAND:
			accel -= HOVER_WEIGHT_GRAVITY / float(valid_count) * strength
			if absf(normal_vel) > 0.0001:
				accel -= HOVER_POINT_DAMPING * idle_damp_scale * normal_vel * strength
		elif penetration > 0.0 or absf(normal_vel) > 0.0001:
			if penetration > 0.0:
				accel += (
					HOVER_POINT_SPRING_K
					* penetration
					* moving_scale
					* _hover_point_repulsion_scale(ctx, penetration)
					* strength
				)
			accel -= HOVER_POINT_DAMPING * idle_damp_scale * normal_vel * strength
			accel = clampf(accel, -max_accel, max_accel)

		if absf(accel) <= 0.0001:
			continue
		results.append(AppliedHoverForce.new(normal * accel * mass, point.local_offset))

	return results


static func air_gravity_force(ctx: Context, mass: float) -> Vector3:
	var gravity_scale := clampf(ctx.air_gravity_scale, 0.0, 1.0)
	return Vector3.DOWN * AIR_GRAVITY * gravity_scale * mass


static func compute_air_force(ctx: Context, mass: float, _delta: float) -> Vector3:
	## Gravity + soft lift. Holding W (or boost) keeps XZ — no air drag while thrusting.
	var force := air_gravity_force(ctx, mass)
	var horizontal := horizontal_velocity(ctx.velocity)
	var forward_speed := horizontal.length()
	if forward_speed <= 0.1:
		return force

	## Soft cushion only — not powered glide lift.
	var lift := minf(forward_speed * 0.45, AIR_GRAVITY * 0.5)
	force += Vector3.UP * lift * mass

	var brake := clampf(ctx.brake_strength, 0.0, 1.0)
	var holding_thrust := ctx.forward_held or ctx.boost_active
	if holding_thrust and brake <= 0.05:
		return force

	var drag := PASSIVE_AIR_DRAG * 0.12
	if brake > 0.0:
		drag = PASSIVE_AIR_DRAG * lerpf(1.0, BRAKE_GLIDE_DRAG_SCALE, brake)
	elif holding_thrust:
		return force
	force -= horizontal.normalized() * forward_speed * drag * mass * ctx.glide_drag_scale
	return force


static func air_speed_lift(forward_speed: float, ctx: Context) -> float:
	## Kept for any callers; lift is no longer applied in compute_air_force.
	return 0.0


static func apply_velocity_constraints(ctx: Context, velocity: Vector3, mode: int, state: PhysicsDirectBodyState3D = null) -> Vector3:
	var v := velocity
	var normal := ctx.ground_normal

	if mode == MODE_GROUNDED:
		var hover_clearance := _hover_clearance_for_force(ctx)
		if ctx.hover_at_rest and hover_clearance >= BASE_HEIGHT - HOVER_SPRING_DEADBAND:
			var normal_vel := v.dot(normal)
			if absf(normal_vel) < HOVER_IDLE_SETTLE_NVEL:
				v -= normal * normal_vel

		var tangent_speed := horizontal_velocity(v).length()
		var max_normal := lerpf(
			HOVER_SLOW_MAX_NORMAL_SPEED,
			HOVER_MAX_NORMAL_SPEED,
			clampf(tangent_speed / HOVER_SLOW_SPEED_REF, 0.0, 1.0)
		)
		if ctx.climbing and (ctx.forward_held or ctx.boost_active):
			var climb_normal := tangent_speed * ctx.slope_grade * CLIMB_NORMAL_SPEED_SCALE
			max_normal = minf(maxf(max_normal, climb_normal), CLIMB_MAX_NORMAL_SPEED)
		if (
			ctx.boost_active
			and ctx.climbing
			and hover_clearance < BASE_HEIGHT
		):
			var escape := lerpf(
				HOVER_MAX_NORMAL_SPEED,
				CLIMB_MAX_NORMAL_SPEED,
				clampf(ctx.slope_grade / CLIMB_REPULSION_GRADE_REF, 0.0, 1.0)
			)
			max_normal = maxf(max_normal, escape)
		if (
			hover_clearance < BASE_HEIGHT - HOVER_SPRING_DEADBAND
			and not (ctx.boost_active and ctx.climbing)
		):
			var compression := clampf(
				(BASE_HEIGHT - hover_clearance) / BASE_HEIGHT,
				0.0,
				1.0
			)
			max_normal = minf(
				max_normal,
				lerpf(max_normal, HOVER_SLOW_MAX_NORMAL_SPEED, compression)
			)
		var out_normal_vel := v.dot(normal)
		if out_normal_vel > max_normal and hover_clearance >= 0.0:
			v -= normal * (out_normal_vel - max_normal)

		var tangent_vel := clamp_tangent_speed(
			v.slide(normal),
			hard_speed_cap()
		)
		v = tangent_vel + normal * v.dot(normal)

	elif mode == MODE_GLIDING:
		var horizontal := horizontal_velocity(v)
		horizontal = clamp_tangent_speed(
			horizontal,
			hard_speed_cap()
		)
		v.x = horizontal.x
		v.z = horizontal.z

	if state != null:
		state.linear_velocity = v
	ctx.velocity = v
	return v


static func apply_touchdown(ctx: Context, braking: bool) -> Dictionary:
	var horizontal := horizontal_velocity(ctx.velocity)
	var horizontal_speed := horizontal.length()
	var td_normal := touchdown_normal(ctx.ground_normal, ctx.slope_grade, horizontal_speed)
	var pre_horizontal_dir := horizontal.normalized() if horizontal_speed > 0.5 else Vector3.ZERO

	var pre_tangent := ctx.velocity.slide(td_normal)
	var pre_speed := pre_tangent.length()
	var normal_vel := ctx.velocity.dot(td_normal)
	var approach := absf(minf(normal_vel, 0.0))
	var hard := approach >= HARD_LAND_SPEED and not braking

	var velocity := pre_tangent
	var slide_dir := pre_horizontal_dir
	if slide_dir.length_squared() < 0.0001:
		slide_dir = pre_tangent.normalized() if pre_speed > 0.5 else ctx.board_forward.slide(td_normal).normalized()

	if normal_vel < -0.1 and slide_dir.length_squared() > 0.0001:
		var approach_blend := clampf(approach / HARD_LAND_SPEED, 0.0, 1.0)
		var absorb := lerpf(LAND_NORMAL_ABSORB_SOFT, LAND_IMPACT_ABSORB, approach_blend)
		if approach < HARD_LAND_SPEED * 0.5:
			absorb = lerpf(absorb, LAND_NORMAL_ABSORB_SOFT, 1.0 - approach / (HARD_LAND_SPEED * 0.5))
		else:
			absorb = maxf(absorb, LAND_NORMAL_ABSORB)
		if horizontal_speed > 4.0:
			absorb *= clampf(4.0 / horizontal_speed, 0.35, 1.0)
		velocity += slide_dir * absf(normal_vel) * absorb

	if pre_speed > 0.5:
		var out_speed := velocity.slide(td_normal).length()
		if out_speed < pre_speed * LAND_TANGENT_KEEP:
			velocity = (
				slide_dir * pre_speed * LAND_TANGENT_KEEP
				+ td_normal * maxf(velocity.dot(td_normal), 0.0)
			)

	if horizontal_speed > 0.5:
		var out_horizontal := horizontal_velocity(velocity)
		var max_horizontal := horizontal_speed * LAND_HORIZONTAL_SPEED_CAP
		if out_horizontal.length() > max_horizontal:
			out_horizontal = out_horizontal.normalized() * max_horizontal
			velocity = out_horizontal + td_normal * velocity.dot(td_normal)

	var tangent_vel := velocity.slide(td_normal)
	var out_normal := velocity.dot(td_normal)
	var allowed_inward := -lerpf(
		LAND_MAX_INWARD_NORMAL_SOFT,
		LAND_MAX_INWARD_NORMAL_HARD,
		clampf(approach / HARD_LAND_SPEED, 0.0, 1.0)
	)
	velocity = tangent_vel + td_normal * maxf(out_normal, allowed_inward)

	velocity = clamp_tangent_speed(velocity.slide(td_normal), carry_speed_cap(false))
	if not hard:
		var settled_normal := velocity.dot(td_normal)
		if settled_normal > 0.0:
			velocity -= td_normal * settled_normal
	return {
		"velocity": velocity,
		"hard": hard,
		"approach": approach,
	}
