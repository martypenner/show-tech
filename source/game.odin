/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
	pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g` global
	variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
import "core:log"
import "core:net"
import sdl "vendor:sdl3"

_ :: log
_ :: fmt

gm: ^GameMemory

GameMemory :: struct {
	should_run:     bool,
	active_tab:     Tab,
	ui:             UIControls,
	sound_settings: ^SoundSettings,
	lighting:       struct {
		socket:         Maybe(net.UDP_Socket),
		endpoint:       net.Endpoint,
		active_look:    LightingLook,
		fx:             [LightingFxKind]LightingFx,
		fx_osc_address: [LightingFxKind]string,
	},
}

window: ^sdl.Window
renderer: ^sdl.Renderer
window_width: i32 = 1280
window_height: i32 = 720

update :: proc() {
	event: sdl.Event
	for sdl.PollEvent(&event) {
		if event.type == .QUIT ||
		   (event.type == .WINDOW_CLOSE_REQUESTED &&
				   event.window.windowID == sdl.GetWindowID(window)) {
			gm.should_run = false
		}
		when ODIN_DEBUG {
			if event.type == .KEY_DOWN && event.key.key == sdl.K_ESCAPE {
				gm.should_run = false
			}
		}

		if event.type == .WINDOW_RESIZED {
			sdl.GetWindowSizeInPixels(window, &window_width, &window_height)
			controls_prepare_for_render(gm.ui.items[:], window_width, window_height)
		}
	}

	sound_update()
	ui_control_set_value(&gm.ui, .Music_Volume, sound_music_current_volume())
	lighting_update()
}

draw :: proc() {
	// TODO:
	// sdl.SetRenderScale(renderer, io.DisplayFramebufferScale.x, io.DisplayFramebufferScale.y)
	sdl.SetRenderDrawColor(renderer, 16, 16, 16, 255)
	sdl.RenderClear(renderer)
	sdl.RenderPresent(renderer)

	// controls_draw()
}

@(export)
game_update :: proc() {
	update()
	draw()

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	ensure(sdl.SetAppMetadata("Showtime", "1.0", "showtime"), string(sdl.GetError()))

	ensure(sdl.Init({.VIDEO, .AUDIO}))
	window = sdl.CreateWindow(
		"Showtime",
		window_width,
		window_height,
		{.RESIZABLE, .HIGH_PIXEL_DENSITY},
	)
	ensure(window != nil, string(sdl.GetError()))
	// Might need to change this for mac
	renderer = sdl.CreateRenderer(window, "vulkan")
	ensure(renderer != nil, string(sdl.GetError()))
	// Might need a way to limit this further to 60 fps consistently
	sdl.SetRenderVSync(renderer, 1)
	sdl.SetWindowPosition(window, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED)
}

game_memory_make :: proc() -> ^GameMemory {
	memory := new(GameMemory)
	memory^ = GameMemory {
		should_run = true,
	}
	return memory
}

@(export)
game_init :: proc() {
	gm = game_memory_make()

	gm.sound_settings = sound_settings_init()

	gm.ui = ui_controls_make(layout_build())
	ui_control_set_value(&gm.ui, .Use_House_Music, gm.sound_settings.use_house_music)
	for &control in gm.ui.items {
		control.ui_type = ui_resolve_type(control.name_id)
	}

	music_browser_playlists_refresh()
	music_browser_tracks_refresh()

	endpoint, endpoint_ok := net.parse_endpoint("127.0.0.1:42000")
	log.ensuref(endpoint_ok, "Error parsing endpoint", endpoint)
	socket, socket_err := net.make_unbound_udp_socket(.IP4)
	log.ensuref(socket_err == nil, "Error making udp socket: %v", socket_err)
	gm.lighting.socket = socket
	gm.lighting.endpoint = endpoint

	lighting_init()

	game_hot_reloaded(gm)
}

@(export)
game_should_run :: proc() -> bool {
	return gm.should_run
}

@(export)
game_shutdown :: proc() {
	sound_shutdown()

	if socket, ok := gm.lighting.socket.?; ok {
		net.close(socket)
		gm.lighting.socket = nil
	}

	gm = nil
}

@(export)
game_shutdown_window :: proc() {
	sdl.DestroyRenderer(renderer)
	sdl.DestroyWindow(window)
	sdl.Quit()
}

@(export)
game_memory :: proc() -> rawptr {
	return gm
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(GameMemory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	gm = (^GameMemory)(mem)

	// Restore Module-level pointers that point into `gm`. A freshly loaded DLL
	// starts these globals nil, so they must be re-pointed here before the next
	// frame uses them.
	sound_hot_reloaded(gm.sound_settings)
}

@(export)
game_force_reload :: proc() -> bool {
	return false
}

@(export)
game_force_restart :: proc() -> bool {
	return false
}

// In a web build, this is called when browser changes size.
game_parent_window_size_changed :: proc(w, h: int) {
	sdl.GetWindowSizeInPixels(window, &window_width, &window_height)
}
