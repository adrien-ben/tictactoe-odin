package client

import rl "vendor:raylib"

DEFAULT_ADDR: string : "127.0.0.1:51235"

ADDR_BUF_SIZE :: 22
AddressBuffer :: [ADDR_BUF_SIZE]byte

create_default_addr_buf :: proc() -> (a: AddressBuffer) {
	#assert(len(DEFAULT_ADDR) <= ADDR_BUF_SIZE, "default address overflows address buffer")
	copy(a[:], DEFAULT_ADDR[:])
	return
}

MainMenuState :: union #no_nil {
	MainMenu,
	OnlineMenu,
}

MainMenu :: struct {
	go_offline: bool,
	go_online:  bool,
	exit:       bool,
}

OnlineMenu :: struct {
	addr_buffer: AddressBuffer,
	addr_err:    bool,
	connect:     bool,
	back:        bool,
}

create_main_menu_state :: proc() -> (s: MainMenuState) {
	return
}

destroy_main_menu_state :: proc(s: ^MainMenuState) {
}

update_main_menu_state :: proc(s: ^MainMenuState) -> (t: Transition) {
	maybe_new_state: Maybe(MainMenuState)

	switch &m in s {
	case MainMenu:
		if m.go_offline {
			t = ToOfflineGame{}
		}

		if m.go_online {
			maybe_new_state = OnlineMenu {
				addr_buffer = create_default_addr_buf(),
			}
		}

		if rl.IsKeyPressed(.ESCAPE) || m.exit {
			t = Back{}
		}
	case OnlineMenu:
		if m.connect {
			addr_buf := m.addr_buffer
			addr := string(cstring(raw_data(addr_buf[:])))

			if parsed_addr, is_valid_addr := parse_address(addr); is_valid_addr {
				t = ToOnlineGame {
					addr = parsed_addr,
				}

			} else {
				m.addr_err = true
			}
		}

		if rl.IsKeyPressed(.ESCAPE) || m.back {
			maybe_new_state = MainMenu{}
		}
	}

	if new_state, has_new_state := maybe_new_state.?; has_new_state {
		s^ = new_state
	}

	return
}


resume_main_menu_state :: proc(s: ^MainMenuState) {
	switch &m in s {
	case MainMenu:
		m.go_offline = false
		m.go_online = false
		m.exit = false
	case OnlineMenu:
		m.connect = false
		m.back = false
	}

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

	switch &m in s {
	case MainMenu:
		m.go_offline = rl.GuiLabelButton({y = 100, width = WINDOW_WIDTH, height = 100}, "Offline")
		m.go_online = rl.GuiLabelButton({y = 200, width = WINDOW_WIDTH, height = 100}, "Online")
		m.exit = rl.GuiLabelButton({y = 300, width = WINDOW_WIDTH, height = 100}, "Quit")
	case OnlineMenu:
		text := cstring(raw_data(&m.addr_buffer))
		text_len := len(text)
		rl.GuiTextBox({y = 100, width = WINDOW_WIDTH, height = 100}, text, ADDR_BUF_SIZE, true)

		if len(text) != text_len {
			// text was changed -> reset error
			m.addr_err = false
		}

		m.connect = rl.GuiLabelButton({y = 200, width = WINDOW_WIDTH, height = 100}, "Connect")
		m.back = rl.GuiLabelButton({y = 300, width = WINDOW_WIDTH, height = 100}, "Back")
		if m.addr_err {
			rl.GuiSetStyle(
				.LABEL,
				i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL),
				i32(rl.ColorToInt(rl.RED)),
			)

			rl.GuiLabel({y = 400, width = WINDOW_WIDTH, height = 100}, "Invalid address")
		}
	}
}
