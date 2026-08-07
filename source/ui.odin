package game

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:strings"
import mixer "vendor:sdl3/mixer"

_ :: imgui
_ :: log
_ :: fmt

UI_Type :: enum u8 {
	SoundAndLighting,
	Destructive,
	Sound,
	Lighting,
	Game,
	Innuendo,
}

Tab :: enum u8 {
	Controls,
	Music,
	All,
}

Button_Style :: struct {
	base, hovered, active: imgui.Vec4,
}

button_styles := [UI_Type]Button_Style {
	.SoundAndLighting = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}, // default: no push
	.Destructive      = {{0.40, 0.08, 0.08, 1}, {0.60, 0.15, 0.15, 1}, {0.75, 0.20, 0.20, 1}}, // red
	.Sound            = {{0.08, 0.30, 0.10, 1}, {0.15, 0.45, 0.15, 1}, {0.20, 0.55, 0.20, 1}}, // green
	.Lighting         = {{0.38, 0.32, 0.06, 1}, {0.55, 0.48, 0.08, 1}, {0.70, 0.60, 0.10, 1}}, // yellow
	.Game             = {{0.08, 0.16, 0.40, 1}, {0.15, 0.24, 0.60, 1}, {0.20, 0.30, 0.75, 1}}, // blue
	.Innuendo         = {{0.40, 0.16, 0.40, 1}, {0.60, 0.22, 0.60, 1}, {0.75, 0.30, 0.75, 1}}, // pink
}

lighting_look_labels := [LightingLook]cstring {
	.House             = "House",
	.Scene             = "Scene",
	.SceneWithFullFade = "Scene - fade",
	.CenterFocus       = "Center focus",
}

lighting_fx_labels := [LightingFxKind]cstring {
	.Blackout     = "Blackout",
	.RainbowSting = "Rainbow sting",
	.Rain         = "Rain",
	.Innuendo     = "Innuendo",
	.AveMaria     = "Ave Maria",
}

sounds_like_a_song_playlist_retained: ^Playlist

controls_button :: proc(label: cstring, kind: UI_Type, width: f32) -> bool {
	style := button_styles[kind]
	colored := kind != .SoundAndLighting
	height := imgui.GetFrameHeight() * 2
	if colored do imgui.PushStyleColorImVec4(.Button, style.base)
	if colored do imgui.PushStyleColorImVec4(.ButtonHovered, style.hovered)
	if colored do imgui.PushStyleColorImVec4(.ButtonActive, style.active)
	clicked := imgui.Button(label, {width, height})
	if colored do imgui.PopStyleColor(3)
	return clicked
}

controls_group_begin :: proc(label: cstring) {
	imgui.BeginChild(label, child_flags = {.AutoResizeY, .Borders, .NavFlattened})
	imgui.TextUnformatted(label)
}

controls_group_end :: proc() {
	imgui.EndChild()
}

music_browser_playlist_selected :: proc() -> ^Playlist {
	ensure(
		sound_settings.music_browser_playlist_index >= 0 &&
		sound_settings.music_browser_playlist_index < i32(len(sound_settings.playlists)),
	)
	return &sound_settings.playlists[sound_settings.music_browser_playlist_index]
}

music_browser_track_selected :: proc() -> ^Track {
	playlist := music_browser_playlist_selected()
	ensure(
		sound_settings.music_browser_track_index >= 0 &&
		sound_settings.music_browser_track_index < i32(len(playlist.tracks)),
	)
	return &playlist.tracks[sound_settings.music_browser_track_index]
}

controls_draw :: proc() {
	// imgui.ShowDemoWindow()

	vp := imgui.GetMainViewport()
	imgui.SetNextWindowPos(vp.WorkPos)
	imgui.SetNextWindowSize(vp.WorkSize)

	imgui.PushStyleVarImVec2(.WindowPadding, {0, 0})
	imgui.PushStyleVar(.WindowRounding, 0)
	imgui.PushStyleVar(.WindowBorderSize, 0)

	imgui.Begin(
		"Root",
		nil,
		{
			.NoTitleBar,
			.NoResize,
			.NoMove,
			.NoCollapse,
			.NoBackground,
			.NoSavedSettings,
			.NoBringToFrontOnFocus,
			.NoNavFocus,
		},
	)
	imgui.PopStyleVar(3)

	if imgui.BeginTabBar("TopTabs") {
		music_tab_selected := false
		if imgui.BeginTabItem("Controls") {
			xs := strings.clone_to_cstring(
				strings.repeat("X", 15, context.temp_allocator),
				context.temp_allocator,
			)
			button_width := imgui.CalcTextSize(xs).x + imgui.GetStyle().FramePadding.x * 2

			{
				if imgui.Checkbox("Use house music", &gm.sound_settings.use_house_music) {
					if gm.sound_settings.use_house_music {
						if gm.sound_settings.current_playing_playlist == nil {
							playlist := playlist_find_by_name(.Kids_on_Bikes_80s_Chill)
							ensure(playlist != nil, "Couldn't find playlist for Use_House_Music")

							track := playlist_pick_random_track(playlist)
							ensure(track != nil, "Couldn't pick track for Use_House_Music")

							new_playback := music_playback_start_playlist_track(
								playlist,
								track,
								0.2,
								gm.sound_settings.fade_in_time,
							)
							for &playback in gm.sound_settings.music_playbacks {
								if playback.mixer_track == nil || &playback == new_playback do continue
								audible := music_playback_volume_at(
									&playback,
									mixer.GetTrackPlaybackPosition(playback.mixer_track),
								)
								music_playback_volume_set(
									&playback,
									{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
								)
							}
						}
					}
					sound_settings_save()
				}
				imgui.SameLine(spacing = 40)

				music_vol := sound_music_current_volume() * 100
				if imgui.SliderFloat(
					"Volume",
					&music_vol,
					0,
					100,
					"%.1f%%",
					imgui.SliderFlags_AlwaysClamp,
				) {
					gm.sound_settings.music_volume = music_vol / 100
					primary := gm.sound_settings.music_playback_primary
					if primary != nil && primary.mixer_track != nil {
						music_playback_volume_set(primary, {{0, gm.sound_settings.music_volume}})
					}
					sound_settings_save()
				}
			}

			{
				controls_group_begin("Show")

				if controls_button("Pre-show", .SoundAndLighting, button_width) {
					playlist := playlist_find_by_name(.Kids_on_Bikes_80s_Explore)
					ensure(playlist != nil, "Couldn't find playlist for Pre_Show")

					track := playlist_pick_random_track(playlist)
					ensure(track != nil, "Couldn't pick track for Pre_Show")

					new_playback := music_playback_start_playlist_track(
						playlist,
						track,
						0.3,
						gm.sound_settings.fade_in_time,
					)
					for &playback in gm.sound_settings.music_playbacks {
						if playback.mixer_track == nil || &playback == new_playback do continue
						audible := music_playback_volume_at(
							&playback,
							mixer.GetTrackPlaybackPosition(playback.mixer_track),
						)
						music_playback_volume_set(
							&playback,
							{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
						)
					}

					lighting_fx_deactivate_all()
					lighting_look_activate(.House)
				}
				imgui.SameLine()

				if controls_button("Post-show", .SoundAndLighting, button_width) {
					playlist := playlist_find_by_name(.Kids_on_Bikes_80s_Explore)
					ensure(playlist != nil, "Couldn't find playlist for Post_Show")

					track := playlist_pick_random_track(playlist)
					ensure(track != nil, "Couldn't pick track for Post_Show")

					new_playback := music_playback_start_playlist_track(
						playlist,
						track,
						0.7,
						gm.sound_settings.fade_in_time,
					)
					for &playback in gm.sound_settings.music_playbacks {
						if playback.mixer_track == nil || &playback == new_playback do continue
						audible := music_playback_volume_at(
							&playback,
							mixer.GetTrackPlaybackPosition(playback.mixer_track),
						)
						music_playback_volume_set(
							&playback,
							{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
						)
					}

					lighting_fx_deactivate_all()
					lighting_look_activate(.House)
				}

				if controls_button("To house", .SoundAndLighting, button_width) {
					if gm.sound_settings.use_house_music {
						playlist := playlist_find_by_name(.Kids_on_Bikes_80s_Explore)
						ensure(playlist != nil, "Couldn't find playlist for To_House")

						track := playlist_pick_random_track(playlist)
						ensure(track != nil, "Couldn't pick track for To_House")

						new_playback := music_playback_start_playlist_track(
							playlist,
							track,
							0.12,
							gm.sound_settings.fade_in_time,
						)
						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil || &playback == new_playback do continue
							audible := music_playback_volume_at(
								&playback,
								mixer.GetTrackPlaybackPosition(playback.mixer_track),
							)
							music_playback_volume_set(
								&playback,
								{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
							)
						}
					} else {
						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil do continue
							audible := music_playback_volume_at(
								&playback,
								mixer.GetTrackPlaybackPosition(playback.mixer_track),
							)
							music_playback_volume_set(
								&playback,
								{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
							)
						}
					}

					lighting_fx_deactivate_all()
					lighting_look_activate(.House)
				}
				imgui.SameLine()

				if controls_button("Scene - ramp", .SoundAndLighting, button_width) {
					primary := gm.sound_settings.music_playback_primary
					if primary != nil &&
					   primary.mixer_track != nil &&
					   mixer.TrackPlaying(primary.mixer_track) {
						primary_volume := music_playback_volume_at(
							primary,
							mixer.GetTrackPlaybackPosition(primary.mixer_track),
						)
						gm.sound_settings.music_volume = 1
						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil do continue
							if &playback == primary {
								music_playback_volume_set(
									&playback,
									{{0, primary_volume}, {0.5, 1}, {3.5, 1}, {4.5, 0}},
								)
							} else {
								music_playback_stop(&playback)
							}
						}
					}

					lighting_fx_deactivate_all()
					lighting_look_activate(.SceneWithFullFade)
				}
				imgui.SameLine()

				if controls_button("Scene - fade", .SoundAndLighting, button_width) {
					for &playback in gm.sound_settings.music_playbacks {
						if playback.mixer_track == nil do continue
						audible := music_playback_volume_at(
							&playback,
							mixer.GetTrackPlaybackPosition(playback.mixer_track),
						)
						music_playback_volume_set(&playback, {{0, audible}, {2, 0}})
					}

					lighting_fx_deactivate_all()
					lighting_look_activate(.SceneWithFullFade)
				}
				imgui.SameLine()

				if controls_button("Drop needle", .Destructive, button_width) {
					playlist := playlist_find_by_name(.Needle_Droppers)
					ensure(playlist != nil, "Couldn't find playlist for Needle_Droppers")

					track := playlist_pick_random_track(playlist)
					ensure(track != nil, "Couldn't pick track for Needle_Droppers")

					for &playback in gm.sound_settings.music_playbacks {
						music_playback_stop(&playback)
					}
					new_playback := music_playback_start_playlist_track(playlist, track, 1, 0)
					ensure(new_playback != nil)

					lighting_fx_run(.Blackout, {{0, 1}})
				}

				if controls_button("Ave Maria", .SoundAndLighting, button_width) {
					playlist := playlist_find_by_name(.Ave_Maria)
					ensure(playlist != nil)

					if playlist_is_current(.Ave_Maria) {
						for &playback in gm.sound_settings.music_playbacks {
							music_playback_stop(&playback)
						}
					} else {
						track := playlist_pick_random_track(playlist)
						ensure(track != nil, "Couldn't pick track for AveMaria")

						new_playback := music_playback_start_playlist_track(
							playlist,
							track,
							0.8,
							gm.sound_settings.fade_in_time,
						)
						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil || &playback == new_playback do continue
							audible := music_playback_volume_at(
								&playback,
								mixer.GetTrackPlaybackPosition(playback.mixer_track),
							)
							music_playback_volume_set(
								&playback,
								{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
							)
						}
					}

					fx := gm.lighting.fx[.Blackout]
					if fx.weight_current > 0 {
						// Blackout is dark: fade it down.
						lighting_fx_run(.Blackout, {{0, fx.weight_current}, {2, 0}})
						lighting_look_activate(.Scene)
					} else {
						// Full blackout right away, hold while the intro plays,
						// then come partway back up over 4s.
						lighting_fx_run(
							.Blackout,
							{{0, fx.weight_current}, {1, 1}, {17, 1}, {21, 0.7}},
						)
						lighting_look_activate(.Scene)
					}
				}

				controls_group_end()
			}

			{
				controls_group_begin("Games")

				if controls_button("Innuendo", .Innuendo, button_width) {
					playlist := playlist_find_by_name(.Sex_With_Me)
					ensure(playlist != nil, "Couldn't find playlist for Innuendo")

					if playlist_is_current(.Sex_With_Me) {
						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil do continue
							audible := music_playback_volume_at(
								&playback,
								mixer.GetTrackPlaybackPosition(playback.mixer_track),
							)
							music_playback_volume_set(&playback, {{0, audible}, {2, 0}})
						}
					} else {
						track := playlist_pick_random_track(playlist)
						ensure(track != nil, "Couldn't pick track for Innuendo")

						new_playback := music_playback_start_playlist_track(
							playlist,
							track,
							0.6,
							gm.sound_settings.fade_in_time,
						)
						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil || &playback == new_playback do continue
							audible := music_playback_volume_at(
								&playback,
								mixer.GetTrackPlaybackPosition(playback.mixer_track),
							)
							music_playback_volume_set(
								&playback,
								{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
							)
						}
					}

					// Toggle: head for the opposite of wherever the last envelope
					// was going, starting from the current weight.
					fx := gm.lighting.fx[.Innuendo]
					target_prev := fx.key_count > 0 ? fx.keys[fx.key_count - 1].weight : 0
					lighting_fx_run(.Innuendo, {{0, fx.weight_current}, {2, 1 - target_prev}})
				}
				imgui.SameLine()

				if controls_button("Oscar Moment", .Game, button_width) {
					playlist := playlist_find_by_name(.Mood_Heroic_EPIC)
					ensure(playlist != nil, "Couldn't find playlist for Oscar_Moment")

					current_playback := gm.sound_settings.music_playback_primary
					oscar_moment_playing :=
						current_playback != nil &&
						current_playback.mixer_track != nil &&
						current_playback.playlist == playlist &&
						!current_playback.stopping

					for &playback in gm.sound_settings.music_playbacks {
						if playback.mixer_track == nil do continue
						audible := music_playback_volume_at(
							&playback,
							mixer.GetTrackPlaybackPosition(playback.mixer_track),
						)
						music_playback_volume_set(
							&playback,
							{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
						)
					}

					if oscar_moment_playing {
						lighting_look_activate(.Scene)
					} else {
						track := playlist_pick_random_track(playlist)
						ensure(track != nil, "Couldn't pick track for Oscar_Moment")

						new_playback := music_playback_start_playlist_track(
							playlist,
							track,
							0.3,
							gm.sound_settings.fade_in_time,
						)
						ensure(new_playback != nil, "Couldn't start Oscar_Moment playback")
						music_playback_volume_set(
							new_playback,
							{
								{0, 0},
								{gm.sound_settings.fade_in_time, 0.3},
								{gm.sound_settings.fade_in_time + 20, 0.5},
							},
						)

						lighting_look_activate(.CenterFocus)
					}
				}
				imgui.SameLine()

				if controls_button("Sounds Like\n  a Song", .Game, button_width) {
					current_playback := gm.sound_settings.music_playback_primary
					playlist_playing :=
						sounds_like_a_song_playlist_retained != nil &&
						current_playback != nil &&
						current_playback.mixer_track != nil &&
						current_playback.playlist == sounds_like_a_song_playlist_retained &&
						!current_playback.stopping

					if playlist_playing {
						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil do continue
							audible := music_playback_volume_at(
								&playback,
								mixer.GetTrackPlaybackPosition(playback.mixer_track),
							)
							music_playback_volume_set(
								&playback,
								{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
							)
						}
						sounds_like_a_song_playlist_retained = nil

						lighting_look_activate(.Scene)
					} else {
						playlist: ^Playlist
						playlists_seen := 0
						for &candidate in sound_settings.playlists {
							if len(candidate.tracks) == 0 do continue
							playlists_seen += 1
							if rand.int_max(playlists_seen) == 0 do playlist = &candidate
						}
						ensure(playlist != nil, "Couldn't pick playlist for Sounds_Like_a_Song")

						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil do continue
							audible := music_playback_volume_at(
								&playback,
								mixer.GetTrackPlaybackPosition(playback.mixer_track),
							)
							music_playback_volume_set(
								&playback,
								{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
							)
						}

						track := playlist_pick_random_track(playlist)
						ensure(track != nil, "Couldn't pick track for Sounds_Like_a_Song")

						new_playback := music_playback_start_playlist_track(
							playlist,
							track,
							0.6,
							gm.sound_settings.fade_in_time,
						)
						ensure(new_playback != nil, "Couldn't start Sounds_Like_a_Song playback")
						music_playback_volume_set(
							new_playback,
							{{0, 0}, {gm.sound_settings.fade_in_time, 0.5}},
						)
						sounds_like_a_song_playlist_retained = playlist

						lighting_look_activate(.CenterFocus)
					}
				}

				controls_group_end()
			}

			{
				controls_group_begin("Lighting")

				if controls_button("House##Lighting", .Lighting, button_width) {
					lighting_fx_deactivate_all()
					lighting_look_activate(.House)
				}
				imgui.SameLine()
				if controls_button("Scene##Lighting", .Lighting, button_width) {
					lighting_fx_deactivate_all()
					lighting_look_activate(.Scene)
				}
				imgui.SameLine()
				if controls_button("Scene - fade##Lighting", .Lighting, button_width) {
					lighting_fx_deactivate_all()
					lighting_look_activate(.SceneWithFullFade)
				}
				imgui.SameLine()
				if controls_button("Fade to black##Lighting", .Lighting, button_width) {
					lighting_fx_deactivate_all()
					lighting_fx_run(
						.Blackout,
						{{0, gm.lighting.fx[.Blackout].weight_current}, {2, 1}},
					)
				}
				imgui.SameLine()
				if controls_button("Center focus##Lighting", .Lighting, button_width) {
					lighting_fx_deactivate_all()
					lighting_look_activate(.CenterFocus)
				}
				imgui.SameLine()
				{
					fx := gm.lighting.fx[.Innuendo]
					text := "Innuendo"
					target_prev: f32
					if fx.weight_current > 0 {
						text = "Cancel Innuendo"
						target_prev = fx.keys[fx.key_count - 1].weight
					}
					if controls_button(
						strings.clone_to_cstring(
							fmt.tprint(text, "##Lighting"),
							context.temp_allocator,
						),
						.Lighting,
						button_width,
					) {
						// Toggle: head for the opposite of wherever the last envelope
						// was going, starting from the current weight.
						lighting_fx_run(.Innuendo, {{0, fx.weight_current}, {2, 1 - target_prev}})
						lighting_look_activate(.Scene)
					}
				}
				imgui.SameLine()
				{
					fx := gm.lighting.fx[.RainbowSting]
					text := " Rainbow Sting"
					target_prev: f32
					if fx.weight_current > 0 {
						text = "    Cancel\n Rainbow Sting"
						target_prev = fx.keys[fx.key_count - 1].weight
					}
					if controls_button(
						strings.clone_to_cstring(
							fmt.tprint(text, "##Lighting"),
							context.temp_allocator,
						),
						.Lighting,
						button_width,
					) {
						// Toggle: head for the opposite of wherever the last envelope
						// was going, starting from the current weight.
						lighting_fx_run(
							.RainbowSting,
							{{0, fx.weight_current}, {2, 1 - target_prev}},
						)
					}
				}

				controls_group_end()
			}

			{
				controls_group_begin("Sounds")

				if controls_button("Break glass", .Sound, button_width) do sound_play(.Glass_Breaking_Sound_Effect_HD_Glass_Shattering_Sound_Effect_TcnufvBffcY, 0.8)
				imgui.SameLine()
				if controls_button("Gunshot", .Sound, button_width) do sound_play(.Single_Gunshot_54_40780, 0.6)
				imgui.SameLine()
				if controls_button("Scream, lady!", .Sound, button_width) do sound_play(.Woman_Screaming_Sfx_Screaming_Sound_Effect_320169, 0.7)
				imgui.SameLine()
				if controls_button("Fireworks", .Sound, button_width) do sound_play(.Fireworks_13_419033, 0.4)
				if controls_button("Train horn", .Sound, button_width) do sound_play(.Train_Horn_337875, 0.8)
				imgui.SameLine()
				if controls_button("Tick tick ding", .Sound, button_width) do sound_play(.Ticktickding, 0.8)
				imgui.SameLine()
				if controls_button("Ding", .Sound, button_width) do sound_play(.Ding_126626, 0.8)
				imgui.SameLine()
				if controls_button("Lightning", .Sound, button_width) do sound_play(.Lightning_237994, 0.8)
				imgui.SameLine()
				if controls_button("Rain", .Sound, button_width) do sound_play(.Calming_Rain_257596, 0.3)
				imgui.SameLine()
				if controls_button("Meow", .Sound, button_width) do sound_play(.Cat_Meow, 0.6)
				imgui.SameLine()
				if controls_button("Yeeeaaahhh", .Sound, button_width) do sound_play(.Yeeeeaaaaaaaahh, 1)

				controls_group_end()
			}

			{
				imgui.BeginChild(
					"Music",
					{0, imgui.GetContentRegionAvail().y},
					child_flags = {.AutoResizeY, .Borders},
				)

				imgui.AlignTextToFramePadding()
				imgui.TextUnformatted("Music")

				{
					primary := gm.sound_settings.music_playback_primary
					if primary != nil {
						imgui.SameLine()

						style := button_styles[.Sound]
						imgui.PushStyleVarX(.FramePadding, 16)
						imgui.PushStyleColorImVec4(.Button, style.base)
						imgui.PushStyleColorImVec4(.ButtonHovered, style.hovered)
						imgui.PushStyleColorImVec4(.ButtonActive, style.active)
						if imgui.Button("Fade out", {0, 0}) {
							for &playback in gm.sound_settings.music_playbacks {
								if playback.mixer_track == nil do continue
								audible := music_playback_volume_at(
									&playback,
									mixer.GetTrackPlaybackPosition(playback.mixer_track),
								)
								music_playback_volume_set(&playback, {{0, audible}, {2, 0}})
							}
						}
						imgui.PopStyleColor(3)
						imgui.PopStyleVar(1)
					}
				}

				if imgui.BeginChild("Playlists##ControlList", {0, 0}, {.FrameStyle}) {
					for &playlist, index in sound_settings.playlists {
						if imgui.Selectable(
							strings.clone_to_cstring(playlist.name, context.temp_allocator),
							sound_settings.music_playback_primary != nil &&
							sound_settings.music_playback_primary.playlist == &playlist,
						) {
							ensure(len(playlist.tracks) > 0)
							sound_settings.music_browser_playlist_index = i32(index)
							sound_settings.music_browser_track_index = 0
							wave_editor_track_select(&playlist.tracks[0])

							primary := gm.sound_settings.music_playback_primary
							if primary != nil && primary.playlist == &playlist {
								for &playback in gm.sound_settings.music_playbacks {
									if playback.mixer_track == nil do continue
									audible := music_playback_volume_at(
										&playback,
										mixer.GetTrackPlaybackPosition(playback.mixer_track),
									)
									music_playback_volume_set(&playback, {{0, audible}, {2, 0}})
								}
							} else {
								track := playlist_pick_random_track(&playlist)
								ensure(track != nil, "Couldn't pick track for playlist")

								new_playback := music_playback_start_playlist_track(
									&playlist,
									track,
									0.3,
									gm.sound_settings.fade_in_time,
								)
								for &playback in gm.sound_settings.music_playbacks {
									if playback.mixer_track == nil || &playback == new_playback do continue
									audible := music_playback_volume_at(
										&playback,
										mixer.GetTrackPlaybackPosition(playback.mixer_track),
									)
									music_playback_volume_set(
										&playback,
										{{0, audible}, {gm.sound_settings.fade_out_time, 0}},
									)
								}
							}
						}
					}
				}
				imgui.EndChild()

				controls_group_end()
			}

			imgui.EndTabItem()
		}

		if imgui.BeginTabItem("Music editor") {
			music_tab_selected = true

			imgui.BeginGroup()
			imgui.Text("Playlist")
			if imgui.BeginChild("Playlist##List", {300, 0}, {.FrameStyle}) {
				for &candidate, index in sound_settings.playlists {
					if imgui.Selectable(
						strings.clone_to_cstring(candidate.name, context.temp_allocator),
						i32(index) == sound_settings.music_browser_playlist_index,
					) {
						ensure(len(candidate.tracks) > 0)
						sound_settings.music_browser_playlist_index = i32(index)
						sound_settings.music_browser_track_index = 0
						wave_editor_track_select(&candidate.tracks[0])
					}
				}
			}
			imgui.EndChild()
			imgui.EndGroup()

			imgui.SameLine()

			imgui.BeginGroup()
			imgui.Text("Track")
			playlist := music_browser_playlist_selected()
			if imgui.BeginChild(
				"Track##List",
				{
					0,
					-(WAVEFORM_HEIGHT +
						imgui.GetFrameHeightWithSpacing() +
						WAVEFORM_HANDLE_RADIUS +
						imgui.GetStyle().ItemSpacing.y),
				},
				child_flags = {.FrameStyle},
			) {
				for &candidate, index in playlist.tracks {
					if imgui.Selectable(
						strings.clone_to_cstring(candidate.title, context.temp_allocator),
						i32(index) == sound_settings.music_browser_track_index,
					) {
						sound_settings.music_browser_track_index = i32(index)
						wave_editor_track_select(&candidate)
					}
				}
			}
			imgui.EndChild()

			if wave_editor_preview_is_playing() {
				if imgui.Button("Stop preview") do wave_editor_preview_stop()
			} else if imgui.Button("Preview bounds") {
				wave_editor_preview_start(music_browser_track_selected())
			}
			wave_editor()

			imgui.EndGroup()

			imgui.EndTabItem()
		}

		if imgui.BeginViewportSideBar(
			"StatusBar",
			vp,
			.Down,
			imgui.GetFrameHeight() * 2,
			{.NoScrollbar, .NoSavedSettings},
		) {
			imgui.AlignTextToFramePadding()
			imgui.Text(strings.clone_to_cstring(music_current_label(), context.temp_allocator))

			imgui.SameLine()
			imgui.Text("| Lighting: %s", lighting_look_labels[gm.lighting.active_look])

			lighting_fx_count := 0
			for &fx, kind in gm.lighting.fx {
				if fx.weight_current <= 0 do continue

				imgui.SameLine(0, 0)
				if lighting_fx_count == 0 {
					imgui.TextUnformatted(" | FX: ")
				} else {
					imgui.TextUnformatted(", ")
				}

				imgui.SameLine(0, 0)
				imgui.Text("%s %.0f%%", lighting_fx_labels[kind], f64(fx.weight_current * 100))
				lighting_fx_count += 1
			}

			progress_bar_width: f32 = 150
			imgui.SameLine(imgui.GetContentRegionAvail().x - progress_bar_width)

			music_progress := music_current_progress()
			music_played, music_length := music_current_time()
			music_time_text := music_time_pair_label(music_played, music_length)
			imgui.ProgressBar(
				music_progress,
				{progress_bar_width, 0},
				strings.clone_to_cstring(music_time_text, context.temp_allocator),
			)
		}
		imgui.End()

		if !music_tab_selected do wave_editor_preview_stop()

		imgui.EndTabBar()
	}

	imgui.End()
}
