package client

import "core:log"

import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 700
TITLE :: "Tic Tac Toe"

main :: proc() {
	logger := log.create_console_logger()
	defer log.destroy_console_logger(logger)
	context.logger = logger

	log.info("Starting client.")

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, TITLE)
	rl.SetExitKey(.KEY_NULL)

	states: [dynamic]AppState
	defer delete(states)

	append(&states, create_main_menu_state())

	mainloop: for !rl.WindowShouldClose() {

		// update current state and apply transition
		switch update_app_state(&states[len(states) - 1]) {
		case .Back:
			s := pop(&states)
			destroy_app_state(&s)

			if len(states) < 1 {
				break mainloop
			}

			resume_app_state(&states[len(states) - 1])
		case .ToOfflineGame:
			append(&states, create_offline_state())
		case .ToOnlineGame:
			append(&states, create_online_state())
		case .None:
		}

		// render
		rl.BeginDrawing()
		rl.ClearBackground(BG_COLOR)
		render_app_state(&states[len(states) - 1])
		rl.EndDrawing()
	}

	for &s in states {
		destroy_app_state(&s)
	}

	rl.CloseWindow()

	log.info("Closing client.")
}
