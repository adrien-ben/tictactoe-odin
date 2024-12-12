package client

import rl "vendor:raylib"

import "../common"

FONT_SIZE :: 50

BG_COLOR :: rl.Color{200, 200, 200, 255}
LINES_COLOR :: rl.BLACK
TEXT_COLOR :: rl.BLACK
HOVER_COLOR :: rl.Color{150, 150, 150, 127}

HEADER_HEIGHT :: 100
GRID_HEIGHT :: WINDOW_HEIGHT - HEADER_HEIGHT
GRID_THICKNESS :: 3

PAWN_SIZE :: WINDOW_WIDTH / 10
PAWN_THICKNESS :: 6

RESTART_MSG: cstring : "Click here/press Enter to restart"
WAITING_MSG: cstring : "Waiting for other players"

player_turn_msg := #partial [common.Pawn]cstring {
	.O = "O's turn",
	.X = "X's turn",
}
win_msg := [common.Pawn]cstring {
	.None = "Draw!",
	.O    = "O wins!",
	.X    = "X wins!",
}
pawn_color := #partial [common.Pawn]rl.Color {
	.O = rl.RED,
	.X = rl.BLUE,
}

render_ingame_header :: proc(text: cstring, message: Maybe(cstring)) {
	rl.DrawRectangleLines(0, 0, WINDOW_WIDTH, HEADER_HEIGHT, LINES_COLOR)
	text_width := rl.MeasureText(text, FONT_SIZE)
	text_x: i32 = WINDOW_WIDTH / 2 - text_width / 2
	text_y: i32 = HEADER_HEIGHT / 2 - FONT_SIZE / 2
	rl.DrawText(text, text_x, text_y, FONT_SIZE, TEXT_COLOR)

	if msg, ok := message.?; ok {
		font_size: i32 = (FONT_SIZE / 5) * 3
		text_width = rl.MeasureText(msg, font_size)
		text_x = WINDOW_WIDTH / 2 - text_width / 2
		text_y = HEADER_HEIGHT - font_size
		rl.DrawText(msg, text_x, text_y, font_size, TEXT_COLOR)
	}
}

render_grid :: proc() {
	grid_pad :: 10
	rl.DrawLineEx(
		rl.Vector2{WINDOW_WIDTH / 3, HEADER_HEIGHT + grid_pad},
		rl.Vector2{WINDOW_WIDTH / 3, WINDOW_HEIGHT - grid_pad},
		GRID_THICKNESS,
		LINES_COLOR,
	)
	rl.DrawLineEx(
		rl.Vector2{2 * WINDOW_WIDTH / 3, HEADER_HEIGHT + grid_pad},
		rl.Vector2{2 * WINDOW_WIDTH / 3, WINDOW_HEIGHT - grid_pad},
		GRID_THICKNESS,
		LINES_COLOR,
	)
	rl.DrawLineEx(
		rl.Vector2{grid_pad, HEADER_HEIGHT + GRID_HEIGHT / 3},
		rl.Vector2{WINDOW_WIDTH - grid_pad, HEADER_HEIGHT + GRID_HEIGHT / 3},
		GRID_THICKNESS,
		LINES_COLOR,
	)
	rl.DrawLineEx(
		rl.Vector2{grid_pad, HEADER_HEIGHT + 2 * GRID_HEIGHT / 3},
		rl.Vector2{WINDOW_WIDTH - grid_pad, HEADER_HEIGHT + 2 * GRID_HEIGHT / 3},
		GRID_THICKNESS,
		LINES_COLOR,
	)
}

render_board :: proc(board: ^common.Board, animations: ^AnimationBoard) {
	for x in 0 ..= 2 {
		for y in 0 ..= 2 {
			p := board[x][y]
			if p != .None {
				anim := animations[x][y]
				center_x := f32(x * WINDOW_WIDTH / 3) + WINDOW_WIDTH / 6
				center_y := f32(y * GRID_HEIGHT / 3) + GRID_HEIGHT / 6 + HEADER_HEIGHT
				center := rl.Vector2{center_x, center_y}

				if is_animation_completed(anim) {
					render_pawn(center, p)
				} else {
					render_pawn_animation(anim, p, center)
				}
			}
		}
	}
}

render_pawn :: proc(center: rl.Vector2, pawn: common.Pawn) {
	if pawn == .X {
		rl.DrawLineEx(
			rl.Vector2{center.x - PAWN_SIZE, center.y - PAWN_SIZE},
			rl.Vector2{center.x + PAWN_SIZE, center.y + PAWN_SIZE},
			PAWN_THICKNESS,
			pawn_color[pawn],
		)
		rl.DrawLineEx(
			rl.Vector2{center.x - PAWN_SIZE, center.y + PAWN_SIZE},
			rl.Vector2{center.x + PAWN_SIZE, center.y - PAWN_SIZE},
			PAWN_THICKNESS,
			pawn_color[pawn],
		)
	} else if pawn == .O {
		rl.DrawCircle(i32(center.x), i32(center.y), PAWN_SIZE, pawn_color[pawn])
		rl.DrawCircle(i32(center.x), i32(center.y), PAWN_SIZE - PAWN_THICKNESS, BG_COLOR)
	}
}

render_hovered_cell :: proc(pos: [2]int) {
	if pos.x < 0 || pos.x > 2 || pos.y < 0 || pos.y > 2 {
		return
	}
	rl.DrawRectangleRec(
		rl.Rectangle {
			x = f32(pos.x * WINDOW_WIDTH / 3),
			y = f32(HEADER_HEIGHT + pos.y * GRID_HEIGHT / 3),
			width = WINDOW_WIDTH / 3,
			height = GRID_HEIGHT / 3,
		},
		HOVER_COLOR,
	)
}

render_crossing_line :: proc(line: [2][2]u8, anim: Animation, color: rl.Color) {
	start_x := f32(int(line[0].x) * WINDOW_WIDTH / 3) + WINDOW_WIDTH / 6
	start_y := f32(int(line[0].y) * GRID_HEIGHT / 3) + GRID_HEIGHT / 6 + HEADER_HEIGHT
	start := rl.Vector2{start_x, start_y}

	end_x := f32(int(line[1].x) * WINDOW_WIDTH / 3) + WINDOW_WIDTH / 6
	end_y := f32(int(line[1].y) * GRID_HEIGHT / 3) + GRID_HEIGHT / 6 + HEADER_HEIGHT
	end := rl.Vector2{end_x, end_y}

	render_animated_line(anim, start, end, color, PAWN_THICKNESS)
}
