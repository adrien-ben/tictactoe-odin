package client

import "core:log"
import "core:net"

import rl "vendor:raylib"

import "../common"

OnlineGameState :: struct {
	socket:          net.TCP_Socket,
	payloads:        [dynamic]common.Payload,
	pawn:            common.Pawn,
	game_state:      GameState,
	anination_board: AnimationBoard,
}

create_online_state :: proc(addr: ServerAddress) -> (s: OnlineGameState) {
	ack: common.ConnectAck
	err: net.Network_Error
	s.socket, ack, err = connect(addr)
	log.assertf(err == nil, "Failed to connect to server: %v.", err)

	s.pawn = ack.pawn
	update_local_state(ack.state, s.pawn, &s.game_state)
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

update_online_state :: proc(s: ^OnlineGameState) -> Transition {

	if rl.IsKeyPressed(.ESCAPE) {
		return Back{}
	}

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

		update_local_state(server_state, s.pawn, &s.game_state)

		switch &st in s.game_state {
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

		case WinState:
			if st.crossing_animation.duration_s == 0 {
				st.crossing_animation = create_crossing_animation()
			}
		}
	}

	// Logic
	switch &st in s.game_state {
	case PlayState:
		if (rl.GetMouseDelta() != {0, 0} || rl.IsMouseButtonPressed(.LEFT)) &&
		   mouse_pos.y > HEADER_HEIGHT {
			st.hovered_cell.x = int(mouse_pos.x) / (WINDOW_WIDTH / 3)
			st.hovered_cell.y = (int(mouse_pos.y) - HEADER_HEIGHT) / (WINDOW_WIDTH / 3)
		}

		if rl.IsKeyPressed(.UP) {
			st.hovered_cell.y -= 1
		} else if rl.IsKeyPressed(.DOWN) {
			st.hovered_cell.y += 1
		} else if rl.IsKeyPressed(.LEFT) {
			st.hovered_cell.x -= 1
		} else if rl.IsKeyPressed(.RIGHT) {
			st.hovered_cell.x += 1
		}

		st.hovered_cell.x = clamp(st.hovered_cell.x, 0, 2)
		st.hovered_cell.y = clamp(st.hovered_cell.y, 0, 2)

		if st.my_turn && (rl.IsMouseButtonPressed(.LEFT) || rl.IsKeyPressed(.ENTER)) {

			payload := common.ClientPayload {
				pawn = s.pawn,
				type = common.Move {
					turn = st.turn,
					x = u8(st.hovered_cell.x),
					y = u8(st.hovered_cell.y),
				},
			}
			send_err := send(s.socket, payload)
			if send_err != nil {
				log.errorf("Failed to send data to server: %v.", send_err)
				// TODO: handle disconnection
			}
			// update state to prevent percieved lag
			// will be corrected by server's response if needed
			if st.board[st.hovered_cell.x][st.hovered_cell.y] == .None {
				st.board[st.hovered_cell.x][st.hovered_cell.y] = s.pawn
				s.anination_board[st.hovered_cell.x][st.hovered_cell.y] = create_pawn_animation()
				st.my_turn = false
			}
		}
	case WinState:
		if (mouse_pos.y < HEADER_HEIGHT && rl.IsMouseButtonPressed(.LEFT)) ||
		   rl.IsKeyPressed(.ENTER) {

			send_err := send(
				s.socket,
				common.ClientPayload{pawn = s.pawn, type = common.Restart{}},
			)
			if send_err != nil {
				log.errorf("Failed to send data to server: %v.", send_err)
			}
		} else {
			advance_animation(&st.crossing_animation, frametime_s)
		}
	}

	return nil
}

resume_online_state :: proc(s: ^OnlineGameState) {
}

render_online_state :: proc(s: ^OnlineGameState) {
	rl.ClearBackground(BG_COLOR)

	render_online_header(&s.game_state, s.pawn)
	render_grid()

	switch &st in s.game_state {
	case PlayState:
		render_board(&st.board, &s.anination_board)
		if st.my_turn {
			render_hovered_cell(st.hovered_cell)
		}
	case WinState:
		render_board(&st.board, &s.anination_board)
		if st.winner != .None {
			render_crossing_line(st.line, st.crossing_animation, pawn_color[st.winner])
		}
	}
}

@(private = "file")
render_online_header :: proc(state: ^GameState, pawn: common.Pawn) {
	text: cstring
	switch s in state {
	case PlayState:
		other_pawn: common.Pawn = .O if pawn == .X else .X
		text = "Your turn" if s.my_turn else player_turn_msg[other_pawn]
	case WinState:
		text = win_msg[s.winner]
	}

	message: Maybe(cstring)
	if s, ok := state.(WinState); ok {
		message = WAITING_MSG if s.ready else RESTART_MSG
	}

	render_ingame_header(text, message)
}

@(private = "file")
GameState :: union #no_nil {
	PlayState,
	WinState,
}

@(private = "file")
PlayState :: struct {
	board:        common.Board,
	my_turn:      bool,
	turn:         u8,
	hovered_cell: [2]int,
}

@(private = "file")
WinState :: struct {
	board:              common.Board,
	line:               [2][2]u8,
	ready:              bool,
	winner:             common.Pawn,
	crossing_animation: Animation,
}

@(private = "file")
update_local_state :: proc(
	server_state: common.State,
	pawn: common.Pawn,
	local_state: ^GameState,
) {
	switch ss in server_state {
	case common.PlayState:
		switch &ls in local_state {
		case PlayState:
			ls.board = ss.board
			ls.turn = ss.turn
			ls.my_turn = ss.player == pawn
		case WinState:
			local_state^ = PlayState {
				board   = ss.board,
				turn    = ss.turn,
				my_turn = ss.player == pawn,
			}
		}
	case common.WinState:
		switch &ls in local_state {
		case PlayState:
			local_state^ = WinState {
				board              = ss.board,
				line               = ss.line,
				winner             = ss.winner,
				ready              = bool(ss.player_ready[int(pawn) - 1]),
				crossing_animation = create_crossing_animation(),
			}
		case WinState:
			ls.board = ss.board
			ls.line = ss.line
			ls.winner = ss.winner
			ls.ready = bool(ss.player_ready[int(pawn) - 1])
		}
	}
	return
}
