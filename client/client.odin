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

	app_state: AppState = create_online_state()

	for !rl.WindowShouldClose() {

		update_app_state(&app_state)

		rl.BeginDrawing()
		rl.ClearBackground(BG_COLOR)
		render_app_state(&app_state)
		rl.EndDrawing()
	}

	destroy_app_state(&app_state)

	rl.CloseWindow()

	log.info("Closing client.")
}
