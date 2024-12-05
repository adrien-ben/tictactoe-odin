package main

import "core:math/rand"
import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 700
TITLE :: "Tic Tac Toe"

FONT_SIZE :: 50

BG_COLOR :: rl.Color{200, 200, 200, 255}
LINES_COLOR :: rl.BLACK
TEXT_COLOR :: rl.BLACK

HEADER_HEIGHT :: 100
GRID_HEIGHT :: WINDOW_HEIGHT - HEADER_HEIGHT
GRID_THICKNESS :: 3

PAWN_SIZE :: WINDOW_WIDTH / 10
PAWN_THICKNESS :: 6

RESTART_MSG: cstring : "Click here/press Enter to restart"

Board :: distinct [3][3]Pawn

Pawn :: enum {
	None,
	X,
	O,
}

State :: union #no_nil {
	PlayState,
	WinState,
}

PlayState :: struct {
	player: Pawn,
}

WinState :: struct {
	winner:             Pawn,
	line:               [2][2]int,
	crossing_animation: Animation,
}

player_turn_msg := #partial [Pawn]cstring {
	.O = "O's turn",
	.X = "X's turn",
}
win_msg := [Pawn]cstring {
	.None = "Draw!",
	.O    = "O wins!",
	.X    = "X wins!",
}
pawn_color := #partial [Pawn]rl.Color {
	.O = rl.RED,
	.X = rl.BLUE,
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, TITLE)

	logic_board: Board
	anination_board: AnimationBoard

	state := create_play_state()

	hovered_cell: [2]int

	for !rl.WindowShouldClose() {
		frametime_s := rl.GetFrameTime()
		mouse_pos := rl.GetMousePosition()

		// Update animations
		for i in 0 ..= 2 {
			for j in 0 ..= 2 {
				advance_animation(&anination_board[i][j], frametime_s)
			}
		}

		// Logic
		switch &s in state {
		case PlayState:
			if (rl.GetMouseDelta() != {0, 0} || rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) &&
			   mouse_pos.y > HEADER_HEIGHT {
				hovered_cell.x = int(mouse_pos.x) / (WINDOW_WIDTH / 3)
				hovered_cell.y = (int(mouse_pos.y) - HEADER_HEIGHT) / (WINDOW_WIDTH / 3)
			}

			if rl.IsKeyPressed(rl.KeyboardKey.UP) {
				hovered_cell.y -= 1
			} else if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
				hovered_cell.y += 1
			} else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
				hovered_cell.x -= 1
			} else if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
				hovered_cell.x += 1
			}

			hovered_cell.x = clamp(hovered_cell.x, 0, 2)
			hovered_cell.y = clamp(hovered_cell.y, 0, 2)

			if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) ||
			   rl.IsKeyPressed(rl.KeyboardKey.ENTER) {

				p := s.player
				if logic_board[hovered_cell.y][hovered_cell.x] == .None {
					logic_board[hovered_cell.y][hovered_cell.x] = p
					anination_board[hovered_cell.y][hovered_cell.x] = create_pawn_animation()

					if won, line := has_won(&logic_board, p, hovered_cell.x, hovered_cell.y); won {
						state = WinState {
							winner             = p,
							line               = line,
							crossing_animation = create_crossing_animation(),
						}
					} else if is_board_full(&logic_board) {
						state = WinState {
							winner = .None,
						}
					} else {
						s.player = s.player == .O ? .X : .O
					}
				}
			}
		case WinState:
			if (mouse_pos.y < HEADER_HEIGHT && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) ||
			   rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
				logic_board = Board{}
				anination_board = AnimationBoard{}
				state = create_play_state()
			} else {
				advance_animation(&s.crossing_animation, frametime_s)
			}
		}

		// Render 
		rl.BeginDrawing()
		rl.ClearBackground(BG_COLOR)

		render_header(&state)
		render_grid()
		render_board(&logic_board, &anination_board)
		if ps, ok := state.(PlayState); ok {
			render_hovered_cell(hovered_cell, ps.player)
		}
		if vs, ok := state.(WinState); ok && vs.winner != .None {
			render_crossing_line(vs.line, vs.crossing_animation, pawn_color[vs.winner])
		}

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

create_play_state :: proc() -> State {
	return PlayState{player = Pawn(rand.int_max(len(Pawn) - 1) + 1)}
}

has_won :: proc(board: ^Board, p: Pawn, x: int, y: int) -> (won: bool = true, line: [2][2]int) {
	if board[y][0] == p && board[y][1] == p && board[y][2] == p {
		line = {{y, 0}, {y, 2}}
		return
	}
	if board[0][x] == p && board[1][x] == p && board[2][x] == p {
		line = {{0, x}, {2, x}}
		return
	}
	if board[0][0] == p && board[1][1] == p && board[2][2] == p {
		line = {{0, 0}, {2, 2}}
		return
	}
	if board[2][0] == p && board[1][1] == p && board[0][2] == p {
		line = {{2, 0}, {0, 2}}
		return
	}

	won = false
	return
}

is_board_full :: proc(board: ^Board) -> bool {
	for r in 0 ..= 2 {
		for c in 0 ..= 2 {
			if board[r][c] == .None {
				return false
			}
		}
	}
	return true
}

render_header :: proc(state: ^State) {
	rl.DrawRectangleLines(0, 0, WINDOW_WIDTH, HEADER_HEIGHT, LINES_COLOR)

	text: cstring
	switch s in state {
	case PlayState:
		text = player_turn_msg[s.player]
	case WinState:
		text = win_msg[s.winner]
	}

	text_width := rl.MeasureText(text, FONT_SIZE)
	text_x: i32 = WINDOW_WIDTH / 2 - text_width / 2
	text_y: i32 = HEADER_HEIGHT / 2 - FONT_SIZE / 2
	rl.DrawText(text, text_x, text_y, FONT_SIZE, TEXT_COLOR)

	if _, ok := state.(WinState); ok {
		font_size: i32 = (FONT_SIZE / 5) * 3
		text_width := rl.MeasureText(RESTART_MSG, font_size)
		text_x: i32 = WINDOW_WIDTH / 2 - text_width / 2
		text_y: i32 = HEADER_HEIGHT - font_size
		rl.DrawText(RESTART_MSG, text_x, text_y, font_size, TEXT_COLOR)
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

render_board :: proc(board: ^Board, animations: ^AnimationBoard) {
	for r in 0 ..= 2 {
		for c in 0 ..= 2 {
			p := board[r][c]
			if p != .None {
				anim := animations[r][c]
				center_x := f32(c * WINDOW_WIDTH / 3) + WINDOW_WIDTH / 6
				center_y := f32(r * GRID_HEIGHT / 3) + GRID_HEIGHT / 6 + HEADER_HEIGHT
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

render_pawn :: proc(center: rl.Vector2, pawn: Pawn) {
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

render_hovered_cell :: proc(pos: [2]int, p: Pawn) {
	if pos.x < 0 || pos.x > 2 || pos.y < 0 || pos.y > 2 {
		return
	}
	rl.DrawRectangleLinesEx(
		rl.Rectangle {
			x = f32(pos.x * WINDOW_WIDTH / 3),
			y = f32(HEADER_HEIGHT + pos.y * GRID_HEIGHT / 3),
			width = WINDOW_WIDTH / 3,
			height = GRID_HEIGHT / 3,
		},
		PAWN_THICKNESS,
		pawn_color[p],
	)
}

render_crossing_line :: proc(line: [2][2]int, anim: Animation, color: rl.Color) {
	start_x := f32(line[0].y * WINDOW_WIDTH / 3) + WINDOW_WIDTH / 6
	start_y := f32(line[0].x * GRID_HEIGHT / 3) + GRID_HEIGHT / 6 + HEADER_HEIGHT
	start := rl.Vector2{start_x, start_y}

	end_x := f32(line[1].y * WINDOW_WIDTH / 3) + WINDOW_WIDTH / 6
	end_y := f32(line[1].x * GRID_HEIGHT / 3) + GRID_HEIGHT / 6 + HEADER_HEIGHT
	end := rl.Vector2{end_x, end_y}

	render_animated_line(anim, start, end, color, PAWN_THICKNESS)
}
