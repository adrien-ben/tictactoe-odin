package client

import "core:log"
import "core:net"

import rl "vendor:raylib"

import "../common"

OnlineGameState :: struct {
	socket:             net.TCP_Socket,
	payloads:           [dynamic]common.Payload,
	pawn:               common.Pawn,
	game_state:         GameState,
	anination_board:    AnimationBoard,
	crossing_animation: Animation,
	hovered_cell:       [2]int,
}

create_online_state :: proc() -> (s: OnlineGameState) {
	ack: common.ConnectAck
	err: net.Network_Error
	s.socket, ack, err = connect(net.IP4_Address{127, 0, 0, 1}, 9090)
	log.assertf(err == nil, "Failed to connect to server: %v.", err)

	s.pawn = ack.pawn
	s.game_state = to_local_state(ack.state, s.pawn)
	log.infof("Connected. Received pawn %v.", s.pawn)

	// if joined a running game, animation start animation for placed pawns
	#partial switch st in s.game_state {
	case PlayState:
		for i in 0 ..= 2 {
			for j in 0 ..= 2 {
				if st.board[i][j] != .None {
					s.anination_board[i][j] = create_pawn_animation()
				}
			}
		}
	}

	return
}

destroy_online_state :: proc(s: ^OnlineGameState) {
	send(s.socket, common.ClientPayload{pawn = s.pawn, type = common.Disconnect{}})
	net.close(s.socket)
	delete(s.payloads)
}

update_online_state :: proc(s: ^OnlineGameState) {
	frametime_s := rl.GetFrameTime()
	mouse_pos := rl.GetMousePosition()

	// Update animations
	for i in 0 ..= 2 {
		for j in 0 ..= 2 {
			advance_animation(&s.anination_board[i][j], frametime_s)
		}
	}

	// Listen net messages
	clear(&s.payloads)
	buf: [1024]byte
	read: int
	read_err: net.Network_Error
	for read, read_err = net.recv(s.socket, buf[:]);
	    read > 0 && read_err == nil;
	    read, read_err = net.recv(s.socket, buf[:]) {

		common.deserialize_packets(buf[:read], &s.payloads)
	}

	// process net messages
	for p in s.payloads {
		spl := p.(common.ServerPayload) or_continue
		server_state := spl.(common.State) or_continue

		s.game_state = to_local_state(server_state, s.pawn)

		switch st in s.game_state {
		case PlayState:
			for x in 0 ..= 2 {
				for y in 0 ..= 2 {
					if s.anination_board[x][y].duration_s == 0 && st.board[x][y] != .None {
						s.anination_board[x][y] = create_pawn_animation()
					}
					if st.turn == 0 {
						s.anination_board[x][y].duration_s = 0
					}
				}
			}

			if st.turn == 0 {
				s.crossing_animation.duration_s = 0
			}
		case WinState:
			if s.crossing_animation.duration_s == 0 {
				s.crossing_animation = create_crossing_animation()
			}
		}
	}

	// Logic
	switch &st in s.game_state {
	case PlayState:
		if (rl.GetMouseDelta() != {0, 0} || rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) &&
		   mouse_pos.y > HEADER_HEIGHT {
			s.hovered_cell.x = int(mouse_pos.x) / (WINDOW_WIDTH / 3)
			s.hovered_cell.y = (int(mouse_pos.y) - HEADER_HEIGHT) / (WINDOW_WIDTH / 3)
		}

		if rl.IsKeyPressed(rl.KeyboardKey.UP) {
			s.hovered_cell.y -= 1
		} else if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
			s.hovered_cell.y += 1
		} else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
			s.hovered_cell.x -= 1
		} else if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
			s.hovered_cell.x += 1
		}

		s.hovered_cell.x = clamp(s.hovered_cell.x, 0, 2)
		s.hovered_cell.y = clamp(s.hovered_cell.y, 0, 2)

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) || rl.IsKeyPressed(rl.KeyboardKey.ENTER) {

			payload := common.ClientPayload {
				pawn = s.pawn,
				type = common.Move {
					turn = st.turn,
					x = u8(s.hovered_cell.x),
					y = u8(s.hovered_cell.y),
				},
			}
			send_err := send(s.socket, payload)
			if send_err != nil {
				log.errorf("Failed to send data to server: %v.", send_err)
				// TODO: handle disconnection
			}
		}
	case WinState:
		if (mouse_pos.y < HEADER_HEIGHT && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) ||
		   rl.IsKeyPressed(rl.KeyboardKey.ENTER) {

			send_err := send(
				s.socket,
				common.ClientPayload{pawn = s.pawn, type = common.Restart{}},
			)
			if send_err != nil {
				log.errorf("Failed to send data to server: %v.", send_err)
			}
		} else {
			advance_animation(&s.crossing_animation, frametime_s)
		}
	}
}

render_online_state :: proc(s: ^OnlineGameState) {
	rl.ClearBackground(BG_COLOR)

	render_header(&s.game_state, s.pawn)
	render_grid()

	switch &st in s.game_state {
	case PlayState:
		render_board(&st.board, &s.anination_board)
		if st.my_turn {
			render_hovered_cell(s.hovered_cell)
		}
	case WinState:
		render_board(&st.board, &s.anination_board)
		if st.winner != .None {
			render_crossing_line(st.line, s.crossing_animation, pawn_color[st.winner])
		}
	}
}
