package client

import rl "vendor:raylib"

MainMenuState :: struct {
	go_offline: bool,
	go_online:  bool,
	exit:       bool,
}

create_main_menu_state :: proc() -> (s: MainMenuState) {
	return
}

destroy_main_menu_state :: proc(s: ^MainMenuState) {
}

update_main_menu_state :: proc(s: ^MainMenuState) -> (t: Transition) {
	if s.go_offline {
		t = .ToOfflineGame
	}

	if s.go_online {
		t = .ToOnlineGame
	}

	if rl.IsKeyPressed(.ESCAPE) || s.exit {
		t = .Back
	}

	return
}

resume_main_menu_state :: proc(s: ^MainMenuState) {
	s.go_offline = false
	s.go_online = false
	s.exit = false
}

render_main_menu_state :: proc(s: ^MainMenuState) {
	rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), FONT_SIZE)
	rl.GuiSetStyle(
		.DEFAULT,
		i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL),
		i32(rl.ColorToInt(TEXT_COLOR)),
	)
	rl.GuiSetStyle(
		.LABEL,
		i32(rl.GuiControlProperty.TEXT_ALIGNMENT),
		i32(rl.GuiTextAlignment.TEXT_ALIGN_CENTER),
	)
	rl.GuiLabel({width = WINDOW_WIDTH, height = 100}, TITLE)
	s.go_offline = rl.GuiLabelButton({y = 100, width = WINDOW_WIDTH, height = 100}, "Offline")
	s.go_online = rl.GuiLabelButton({y = 200, width = WINDOW_WIDTH, height = 100}, "Online")
	s.exit = rl.GuiLabelButton({y = 300, width = WINDOW_WIDTH, height = 100}, "Quit")
}
