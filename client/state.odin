package client

AppState :: union #no_nil {
	MainMenuState,
	OfflineGameState,
	OnlineGameState,
}

update_app_state :: proc(state: ^AppState) -> (t: Transition) {
	switch &s in state {
	case OnlineGameState:
		t = update_online_state(&s)
	case OfflineGameState:
		t = update_offline_state(&s)
	case MainMenuState:
		t = update_main_menu_state(&s)
	}
	return
}

resume_app_state :: proc(state: ^AppState) {
	switch &s in state {
	case OnlineGameState:
		resume_online_state(&s)
	case OfflineGameState:
		resume_offline_state(&s)
	case MainMenuState:
		resume_main_menu_state(&s)
	}
}

render_app_state :: proc(state: ^AppState) {
	switch &s in state {
	case OnlineGameState:
		render_online_state(&s)
	case OfflineGameState:
		render_offline_state(&s)
	case MainMenuState:
		render_main_menu_state(&s)
	}
}

destroy_app_state :: proc(state: ^AppState) {
	switch &s in state {
	case OnlineGameState:
		destroy_online_state(&s)
	case OfflineGameState:
		destroy_offline_state(&s)
	case MainMenuState:
		destroy_main_menu_state(&s)
	}
}

Transition :: union {
	ToOfflineGame,
	ToOnlineGame,
	Back,
}

ToOfflineGame :: struct {}

ToOnlineGame :: struct {
	addr: ServerAddress,
}

Back :: struct {}
