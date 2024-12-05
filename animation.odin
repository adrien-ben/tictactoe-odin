package main

import rl "vendor:raylib"

PAWN_ANIMATION_TIME_S :: 0.2
CROSSING_ANIMATION_TIME_S :: 0.3

AnimationBoard :: distinct [3][3]Animation

Animation :: struct {
	elapsed_s:  f32,
	duration_s: f32,
}

is_animation_completed :: proc(anim: Animation) -> bool {
	return anim.elapsed_s >= anim.duration_s
}

get_animation_progression :: proc(anim: Animation) -> f32 {
	return clamp(anim.elapsed_s / anim.duration_s, 0, 1)
}

advance_animation :: proc(anim: ^Animation, elapsed_s: f32) {
	anim.elapsed_s = clamp(anim.elapsed_s + elapsed_s, 0, anim.duration_s)
}

create_crossing_animation :: proc() -> Animation {
	return {duration_s = CROSSING_ANIMATION_TIME_S}
}

create_pawn_animation :: proc() -> Animation {
	return {duration_s = PAWN_ANIMATION_TIME_S}
}

render_pawn_animation :: proc(anim: Animation, pawn: Pawn, center: rl.Vector2) {
	if pawn == .X {
		render_cross_animation(anim, center, PAWN_SIZE, PAWN_THICKNESS, pawn_color[pawn])
	} else if pawn == .O {
		render_circle_animation(anim, center, PAWN_SIZE, PAWN_THICKNESS, pawn_color[pawn])
	}
}

render_cross_animation :: proc(
	anim: Animation,
	center: rl.Vector2,
	size: f32,
	thickness: f32,
	color: rl.Color,
) {
	progression := get_animation_progression(anim)

	if progression > 0 {
		start := center - rl.Vector2{size, size}
		end := center + rl.Vector2{size, size}
		render_animated_line_with_progression(
			clamp(progression * 2, 0, 1),
			start,
			end,
			color,
			thickness,
		)
	}

	if progression > 0.5 {
		start := center - rl.Vector2{PAWN_SIZE, -PAWN_SIZE}
		end := center + rl.Vector2{PAWN_SIZE, -PAWN_SIZE}
		render_animated_line_with_progression(
			clamp((progression - 0.5) * 2, 0, 1),
			start,
			end,
			color,
			thickness,
		)
	}
}

render_circle_animation :: proc(
	anim: Animation,
	center: rl.Vector2,
	radius: f32,
	thickness: f32,
	color: rl.Color,
) {
	progression := get_animation_progression(anim)
	rl.DrawCircleSector(center, radius, 0, progression * 360, i32(progression * 36), color)
	rl.DrawCircle(i32(center.x), i32(center.y), radius - thickness, BG_COLOR)
}

render_animated_line :: proc(
	anim: Animation,
	start: rl.Vector2,
	end: rl.Vector2,
	color: rl.Color,
	thickness: f32,
) {
	render_animated_line_with_progression(
		get_animation_progression(anim),
		start,
		end,
		color,
		thickness,
	)
}

@(private = "file")
render_animated_line_with_progression :: proc(
	progression: f32,
	start: rl.Vector2,
	end: rl.Vector2,
	color: rl.Color,
	thickness: f32,
) {
	v := (end - start) * progression
	current_end := start + v

	rl.DrawLineEx(start, current_end, thickness, color)
}
