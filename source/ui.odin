package game

import imgui "../vendor/odin-imgui"
import "core:log"
import "core:strings"
import mixer "vendor:sdl3/mixer"

_ :: imgui
_ :: log

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

	if imgui.BeginTabBar("TopTabs", {}) {
		music_tab_selected := false
		if imgui.BeginTabItem("Controls") {
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
					// TODO: this is buggy: same playlist might be triggered from other buttons.
					// maybe we want the indirection of a state machine here?
				} else if playlist_is_current(.Kids_on_Bikes_80s_Chill) {
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
				sound_settings_save()
			}
			imgui.SameLine(spacing = 40)

			imgui.SetNextItemWidth(200)
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

			if imgui.Button("Pre-show") {
				playlist := playlist_find_by_name(.Happy_Beats)
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

			if imgui.Button("Post-show") {
				playlist := playlist_find_by_name(.Happy_Beats)
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

			if imgui.Button("To house") {
				if gm.sound_settings.use_house_music {
					playlist := playlist_find_by_name(.Kids_on_Bikes_80s_Chill)
					ensure(playlist != nil, "Couldn't find playlist for To_House")

					track := playlist_pick_random_track(playlist)
					ensure(track != nil, "Couldn't pick track for To_House")

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

			if imgui.Button("Scene - ramp") {
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

			if imgui.Button("Scene - fade") {
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

			if imgui.Button("Drop needle") {
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

			// Games

			if imgui.Button("Innuendo") {
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

			if imgui.Button("Oscar Moment") {
				playlist := playlist_find_by_name(.Oscar_Moment)
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
						0.4,
						gm.sound_settings.fade_in_time,
					)
					ensure(new_playback != nil, "Couldn't start Oscar_Moment playback")
					music_playback_volume_set(
						new_playback,
						{
							{0, 0},
							{gm.sound_settings.fade_in_time, 0.4},
							{gm.sound_settings.fade_in_time + 20, 0.6},
						},
					)

					lighting_look_activate(.CenterFocus)
				}
			}

			buttons := []cstring{"SlasSlowJam", "SlasClub", "SlasUpbeat", "Slas50sPop"}
			for action in buttons {
				if imgui.Button(action) {
					playlist := playlist_find_by_name(.Sounds_Like_a_Song)
					ensure(playlist != nil, "Couldn't find playlist for Sounds_Like_a_Song")

					if track_is_current(action) {
						for &playback in gm.sound_settings.music_playbacks {
							if playback.mixer_track == nil do continue
							audible := music_playback_volume_at(
								&playback,
								mixer.GetTrackPlaybackPosition(playback.mixer_track),
							)
							music_playback_volume_set(&playback, {{0, audible}, {2, 0}})
						}

						lighting_look_activate(.Scene)
					} else {
						track := playlist_pick_specific_track(playlist, action)
						log.ensuref(
							track != nil,
							"Couldn't pick track for Sounds_Like_a_Song: %v",
							action,
						)

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

						lighting_look_activate(.CenterFocus)
					}
				}
			}

			if imgui.Button("Ave Maria") {
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
						1,
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
						{{0, fx.weight_current}, {2, 1}, {21, 1}, {25, 0.7}},
					)
					lighting_look_activate(.Scene)
				}
			}

			// Lighting

			if imgui.Button("House") {
				lighting_fx_deactivate_all()
				lighting_look_activate(.House)
			}
			if imgui.Button("Scene") {
				lighting_fx_deactivate_all()
				lighting_look_activate(.Scene)
			}
			if imgui.Button("Scene with fade") {
				lighting_fx_deactivate_all()
				lighting_look_activate(.SceneWithFullFade)
			}
			if imgui.Button("Rainbow sting") {
				// Toggle: head for the opposite of wherever the last envelope
				// was going, starting from the current weight.
				fx := gm.lighting.fx[.RainbowSting]
				target_prev := fx.key_count > 0 ? fx.keys[fx.key_count - 1].weight : 0
				lighting_fx_run(.RainbowSting, {{0, fx.weight_current}, {2, 1 - target_prev}})
			}

			// Sounds

			if imgui.Button("Break glass") do sound_play(.Glass_Breaking_Sound_Effect_HD_Glass_Shattering_Sound_Effect_TcnufvBffcY, 0.8)
			if imgui.Button("Gunshot") do sound_play(.Single_Gunshot_54_40780, 0.8)
			if imgui.Button("Scream, lady!") do sound_play(.Woman_Screaming_Sfx_Screaming_Sound_Effect_320169, 0.8)
			if imgui.Button("Lightning") do sound_play(.Lightning_237994, 0.8)
			if imgui.Button("Fireworks") do sound_play(.Fireworks_13_419033, 0.4)
			if imgui.Button("Train horn") do sound_play(.Train_Horn_337875, 0.8)
			if imgui.Button("Tick tick ding") do sound_play(.Ticktickding, 0.8)
			if imgui.Button("Ding") do sound_play(.Ding_126626, 0.8)
			if imgui.Button("Rain") do sound_play(.Calming_Rain_257596, 0.8)
			if imgui.Button("Meow") do sound_play(.Cat_Meow, 0.6)
			if imgui.Button("Yeeeaaahhh") do sound_play(.Yeeeeaaaaaaaahh, 1)

			imgui.EndTabItem()
		}

		if imgui.BeginTabItem("Music") {
			music_tab_selected = true
			playlist := music_browser_playlist_selected()
			if imgui.BeginCombo(
				"Playlist",
				strings.clone_to_cstring(playlist.name, context.temp_allocator),
			) {
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
				imgui.EndCombo()
			}

			track := music_browser_track_selected()
			if imgui.BeginCombo(
				"Track",
				strings.clone_to_cstring(track.title, context.temp_allocator),
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
				imgui.EndCombo()
			}

			if wave_editor_preview_is_playing() {
				if imgui.Button("Stop preview") do wave_editor_preview_stop()
			} else if imgui.Button("Preview bounds") {
				wave_editor_preview_start(music_browser_track_selected())
			}
			wave_editor()

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
