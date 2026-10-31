package
{
	import flash.display.Sprite;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	import ssf2mm.shared.EngineRefs;

	/**
	 * My Jukebox: Options > Sounds entry, Stage Select button/GRAB deep-link, F3 hotkey, live SoundQueue sync.
	 */
	public class MusicPlayerMod extends Sprite
	{
		internal static const FLAG_OVERRIDE:String = "music_player.override";
		/** Shared match-music claim (jukebox last pick). */
		internal static const FLAG_CLAIM_ID:String = "match_music.claim_id";
		internal static const FLAG_CLAIM_AT:String = "match_music.claim_at";
		private static const NOTES:String = "My Jukebox — Options > Sounds, Stage Select button, F3, Taunt while paused, or Taunt+Grab in menus. GRAB on a stage also opens match pick.";

		internal var m_host:*;
		internal var m_catalog:MusicCatalog;
		internal var m_store:MusicPlaylistStore;
		internal var m_ui:MusicPlayerUi;
		internal var m_currentMusicId:String;
		internal var m_currentTitle:String;
		internal var m_musicOverrideId:String;
		internal var m_musicClaimAt:int;
		internal var m_armUploadId:String;
		internal var m_paused:Boolean;
		internal var m_pausePos:Number;
		internal var m_duration:Number;
		private var m_returnToSounds:Boolean;
		private var m_matchPickOpen:Boolean;
		internal var m_repeatOne:Boolean;
		internal var m_expectAdvance:Boolean;
		/** Match-end / results: keep the current song; do not treat scene MUSIC_STOP as skip. */
		internal var m_holdAdvance:Boolean;
		/** Menu BGM stays on this track. A later menumusic request does not pick another one. */
		internal var m_pinnedMenuId:String;
		/** The live BGM is menu music, so the song ending restarts it. */
		internal var m_menuPlayback:Boolean;
		/** Flash in-game music_info HUD on playlist auto-advance (jukebox UI closed). */
		internal var m_announceHud:Boolean;
		internal var m_localSound:Sound;
		internal var m_localChannel:SoundChannel;
		internal var m_matchLoopMs:Number;
		private var m_bgmMuted:Boolean;
		private var m_bgmMuteWas:Number;
		/** Recently loaded stock BGM ids — unload older ones on skip to cap RAM. */
		internal var m_loadedMusicIds:Array;
		internal var m_soundsMenu:*;
		internal var m_sssMenu:*;
		/** Arena/custom: jukebox pick still loading when StageData starts. */
		internal var m_pendingMatchMusicId:String;
		internal var m_sssHandSaved:Boolean;
		internal var m_menu:JukeboxMenu;

		internal var m_buttons:MusicModButtons;
		internal var m_input:MusicModInput;
		internal var m_menuFlow:MusicModMenuFlow;
		internal var m_match:MusicModMatchMusic;
		internal var m_loader:MusicModTrackLoader;
		internal var m_local:MusicModLocalPlayback;
		internal var m_transport:MusicModTransport;
		internal var m_nowPlaying:MusicModNowPlaying;

		public function MusicPlayerMod()
		{
			super();
			m_buttons = new MusicModButtons(this);
			m_input = new MusicModInput(this);
			m_menuFlow = new MusicModMenuFlow(this);
			m_match = new MusicModMatchMusic(this);
			m_loader = new MusicModTrackLoader(this);
			m_local = new MusicModLocalPlayback(this);
			m_transport = new MusicModTransport(this);
			m_nowPlaying = new MusicModNowPlaying(this);
			m_currentMusicId = null;
			m_currentTitle = "";
			m_musicOverrideId = null;
			m_musicClaimAt = 0;
			m_armUploadId = null;
			m_paused = true;
			m_pausePos = 0;
			m_duration = 0;
			m_returnToSounds = false;
			m_matchPickOpen = false;
			m_repeatOne = true;
			m_loadedMusicIds = [];
			m_expectAdvance = false;
			m_holdAdvance = false;
			m_pinnedMenuId = "";
			m_menuPlayback = false;
			m_announceHud = false;
			m_soundsMenu = null;
			m_sssMenu = null;
			m_pendingMatchMusicId = null;
			m_sssHandSaved = false;
			m_menu = null;
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			if (!host)
			{
				return;
			};
			m_catalog = new MusicCatalog();
			m_catalog.rebuildIfNeeded();
			m_store = new MusicPlaylistStore(host, m_catalog);
			m_ui = new MusicPlayerUi(host, m_catalog, m_store);
			m_ui.setPlaybackController({
				"setQueue": m_transport.setQueue,
				"prev": m_transport.playPrev,
				"next": m_transport.playNext,
				"togglePause": m_transport.togglePause,
				"getState": m_transport.getPlaybackState,
				"getRepeatOne": m_transport.getRepeatOne,
				"toggleRepeat": m_transport.toggleRepeat,
				"cyclePlayMode": m_transport.cyclePlayMode,
				"getShuffle": m_transport.getShuffle,
				"toggleShuffle": m_transport.toggleShuffle,
				"preview": m_transport.playTrack,
				"seek": m_transport.seekRatio,
				"registerUpload": m_loader.registerUploadResource,
				"registerFolders": m_loader.registerKnownFolders,
				"applyBgmVolume": applyBgmVolume
			});
			try
			{
				EngineRefs.ssf2("modhost.ModHost")["patch"]("playMusic", onPatchedPlayMusic);
				host.patch("playPitchShiftedEffect", PitchShiftBridge.play);
				host.patch("updatePitchShift", PitchShiftBridge.updatePitch);
				host.patch("updatePitchShiftVolume", PitchShiftBridge.updateVolume);
				host.patch("stopPitchShiftedEffect", PitchShiftBridge.stop);
				host.patch("isPitchShiftedEffectPlaying", PitchShiftBridge.isPlaying);
				host.patch("openMatchJukebox", openMatchJukebox);
				host.patch("studioSongId", studioSongId);
				host.patch("applyStudioSong", applyStudioSong);
				host.patch("clearStudioSong", clearStudioSong);
				host.patch("managerPlay", managerPlay);
				host.patch("managerPause", managerPause);
				host.patch("managerResume", managerResume);
				host.patch("managerSeek", managerSeek);
				host.patch("managerState", managerState);
			}
			catch (patchErr:*)
			{
				trace("[music_player] playMusic patch failed: " + patchErr);
			};
			host.addHook("STAGE_SELECT_GESTURE", m_match.onStageGesture);
			host.addHook("STAGE_SELECT", m_match.onStageSelect);
			host.addHook("QUEUE_MATCH_RESOURCES", m_match.onQueueResources);
			host.addHook("MODE_START", m_match.onModeStart);
			host.addHook("MATCH_START", m_match.onMatchStartStamp);
			host.addHook("SETTINGS_APPLY", m_match.onSettingsApply);
			host.addHook("BEFORE_SEND_ROOM_DATA", m_match.onBeforeSendRoomData);
			host.addHook("ROOM_DATA_RECEIVED", m_match.onRoomDataReceived);
			host.addHook("MATCH_END", m_match.onMatchEnd);
			host.addHook("MODE_END", m_match.onMatchEnd);
			host.addHook("MATCH_PAUSE", m_input.onMatchPause);
			host.addHook("MATCH_RESUME", m_input.onMatchResume);
			host.addHook("AFTER_BOOT", onAfterBoot);
			host.addHook("RESOURCE_POOL_READY", m_menuFlow.onResourcePoolReady);
			host.addHook("RESOURCE_LOADED", m_menuFlow.onResourceLoaded);
			host.addHook("MENU_SHOW", m_menuFlow.onMenuShow);
			host.addHook("MENU_HIDE", m_menuFlow.onMenuHide);
			host.addHook("KEY_EVENT", m_input.onKeyEvent);
			host.addHook("MUSIC_STOP", m_transport.onMusicStop);
			host.addHook("ATTRACT_MEDIA", m_menuFlow.onAttractMedia);
			host.addEventListener("mod_menu.ready", m_menuFlow.onMenuReady);
			registerMenu();
			m_input.armMenuJukeboxChord();
			trace("[music_player] boot");
		}

		public function onBootEnd():void
		{
			closePlayer();
			m_transport.stopAllPlayback();
			m_buttons.detachSoundsButton();
			m_buttons.detachSssButton();
			m_input.disarmPauseTaunt();
			m_input.disarmMenuJukeboxChord();
			MusicStageVisuals.clearPreviewBitmaps();
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("STAGE_SELECT_GESTURE", m_match.onStageGesture);
					m_host["removeHook"]("STAGE_SELECT", m_match.onStageSelect);
					m_host["removeHook"]("QUEUE_MATCH_RESOURCES", m_match.onQueueResources);
					m_host["removeHook"]("MODE_START", m_match.onModeStart);
					m_host["removeHook"]("MATCH_START", m_match.onMatchStartStamp);
					m_host["removeHook"]("SETTINGS_APPLY", m_match.onSettingsApply);
					m_host["removeHook"]("BEFORE_SEND_ROOM_DATA", m_match.onBeforeSendRoomData);
					m_host["removeHook"]("ROOM_DATA_RECEIVED", m_match.onRoomDataReceived);
					m_host["removeHook"]("MATCH_END", m_match.onMatchEnd);
					m_host["removeHook"]("MODE_END", m_match.onMatchEnd);
					m_host["removeHook"]("MATCH_PAUSE", m_input.onMatchPause);
					m_host["removeHook"]("MATCH_RESUME", m_input.onMatchResume);
					m_host["removeHook"]("AFTER_BOOT", onAfterBoot);
					m_host["removeHook"]("RESOURCE_POOL_READY", m_menuFlow.onResourcePoolReady);
					m_host["removeHook"]("RESOURCE_LOADED", m_menuFlow.onResourceLoaded);
					m_host["removeHook"]("MENU_SHOW", m_menuFlow.onMenuShow);
					m_host["removeHook"]("MENU_HIDE", m_menuFlow.onMenuHide);
					m_host["removeHook"]("KEY_EVENT", m_input.onKeyEvent);
					m_host["removeHook"]("MUSIC_STOP", m_transport.onMusicStop);
					m_host["removeHook"]("ATTRACT_MEDIA", m_menuFlow.onAttractMedia);
					m_host["removeEventListener"]("mod_menu.ready", m_menuFlow.onMenuReady);
					m_host.emit("mod_menu.unregister", {"id": "music_player"});
				}
				catch (err:*)
				{
				};
			};
			m_host = null;
		}

		private function onAfterBoot(ctx:Object):void
		{
			m_menuFlow.warmCatalog();
		}

		internal function registerMenu():void
		{
			if (!m_host)
			{
				return;
			};
			try
			{
				m_host.emit("mod_menu.register", {
					"id": "music_player",
					"label": "My Jukebox",
					"section": "Essentials",
					"notes": NOTES,
					"nowPlaying": getNowPlaying,
					"onNowPlaying": openPlayer,
					"onSelect": openPlayer
				});
			}
			catch (err:*)
			{
			};
		}

		private function getNowPlaying():String
		{
			m_transport.syncFromSoundQueue();
			return m_currentTitle || "";
		}

		public function studioSongId():String
		{
			return m_musicOverrideId ? String(m_musicOverrideId) : "";
		}

		public function applyStudioSong(trackId:String):Boolean
		{
			if (!trackId)
			{
				return false;
			};
			m_musicOverrideId = String(trackId);
			m_musicClaimAt = getTimer();
			try
			{
				if (m_host)
				{
					m_host.setSessionFlag(FLAG_OVERRIDE, m_musicOverrideId);
					m_host.setSessionFlag(FLAG_CLAIM_ID, m_musicOverrideId);
					m_host.setSessionFlag(FLAG_CLAIM_AT, m_musicClaimAt);
				};
			}
			catch (flagErr:*)
			{
			};
			return true;
		}

		public function managerPlay(trackId:String, positionMs:Number = 0, announce:Boolean = false):Boolean
		{
			return m_transport.managerPlay(trackId, positionMs, announce);
		}

		public function managerPause():Boolean
		{
			return m_transport.managerPause();
		}

		public function managerResume(positionMs:Number = 0):Boolean
		{
			return m_transport.managerResume(positionMs);
		}

		public function managerSeek(positionMs:Number):Boolean
		{
			return m_transport.managerSeek(positionMs);
		}

		public function managerState():Object
		{
			return m_transport.managerState();
		}

		public function clearStudioSong():Boolean
		{
			m_musicOverrideId = null;
			m_musicClaimAt = 0;
			try
			{
				if (m_host)
				{
					m_host.setSessionFlag(FLAG_OVERRIDE, null);
					m_host.setSessionFlag(FLAG_CLAIM_ID, null);
					m_host.setSessionFlag(FLAG_CLAIM_AT, 0);
				};
			}
			catch (flagErr:*)
			{
			};
			return true;
		}

		public function openMatchJukebox():Boolean
		{
			var stageId:String = null;
			try
			{
				stageId = m_match.currentStageId();
			}
			catch (stageErr:*)
			{
			};
			openDeepLink(stageId, true, false);
			return (true);
		}

		internal function openPlayer():void
		{
			openDeepLink(null, false, false);
		}

		internal function openDeepLink(stageId:String, matchPick:Boolean, returnToSounds:Boolean = false):void
		{
			if (!m_ui)
			{
				return;
			};
			if (m_ui.isOpen() || (m_menu && m_menu.isOpen()))
			{
				return;
			};
			m_returnToSounds = false;
			try
			{
				m_catalog.rebuildIfNeeded();
			}
			catch (rebuildErr:*)
			{
			};
			m_matchPickOpen = matchPick;
			m_returnToSounds = returnToSounds && !matchPick;
			// Sync now-playing metadata only — never start/advance playback on open.
			m_transport.syncFromSoundQueue();
			m_match.ensureMatchPaused();
			if (!m_menu)
			{
				m_menu = new JukeboxMenu();
			};
			m_menu.open(m_ui, stageId, matchPick, m_match.onSongPicked, onUiClosed);
		}

		private function closePlayer():void
		{
			if (m_ui && m_ui.isOpen())
			{
				m_ui.close();
			};
		}

		private function onUiClosed():void
		{
			if (m_menu)
			{
				m_menu.onUiClosed();
			};
			m_match.releaseMatchPause();
			if (m_sssHandSaved)
			{
				m_buttons.restoreStageSelectHand();
				setTimeout(m_buttons.restoreStageSelectHand, 0);
				setTimeout(m_buttons.restoreStageSelectHand, 50);
				setTimeout(function ():void
				{
					m_buttons.restoreStageSelectHand();
					m_sssHandSaved = false;
				}, 120);
			};
			if (m_returnToSounds && !m_matchPickOpen)
			{
				showSoundMenu();
			};
			m_returnToSounds = false;
			m_matchPickOpen = false;
		}

		private function showSoundMenu():void
		{
			var MC:*;
			var menu:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController");
				if (!MC)
				{
					return;
				};
				menu = MC["soundMenu"];
				if (menu && menu["show"] is Function)
				{
					menu["show"]();
				};
			}
			catch (err:*)
			{
				trace("[music_player] showSoundMenu: " + err);
			};
		}

		private function onPatchedPlayMusic(soundName:String, loopLoc:Number):void
		{
			var SQ:*;
			var path:String;
			var loop:Number;
			if ((!soundName || soundName == "null") && m_armUploadId)
			{
				soundName = m_armUploadId;
			};
			if (isMenuBgm(soundName) && playMenuPlaylist())
			{
				return;
			};
			try
			{
				path = m_local.localFileFor(soundName);
				if (path || (soundName && String(soundName).indexOf("bgm_upload_") == 0))
				{
					loop = loopLoc;
					if (!(loop > 0) && m_catalog)
					{
						loop = m_catalog.loopMs(soundName);
					};
					m_matchLoopMs = loop >= 0 ? loop : 0;
					m_expectAdvance = false;
					m_armUploadId = null;
					m_local.playLocalTrack(soundName, path, 0);
					return;
				};
			}
			catch (localErr:*)
			{
				trace("[music_player] playMusic local step failed (" + soundName + "): " + localErr);
				return;
			};
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
				if (SQ && SQ.instance && SQ.instance.playMusicStock)
				{
					SQ.instance.playMusicStock(soundName, loopLoc);
				};
				if (isMenuBgm(soundName))
				{
					pinMenuFromQueue(SQ);
				};
			}
			catch (err:*)
			{
				trace("[music_player] stock play failed: " + err);
			};
		}

		public function toggleBgmMute():void
		{
			var SD:*;
			var vol:Number;
			if (!m_bgmMuted)
			{
				m_bgmMuteWas = 1;
				try
				{
					SD = EngineRefs.ssf2("util.SaveData");
					if (SD && SD["BGVolumeLevel"] != null)
					{
						vol = Number(SD["BGVolumeLevel"]);
						if (vol > 0)
						{
							m_bgmMuteWas = vol;
						};
					};
				}
				catch (readErr:*)
				{
				};
				applyBgmVolume(0, false);
				m_bgmMuted = true;
				trace("[music_player] mute");
			}
			else
			{
				applyBgmVolume(m_bgmMuteWas, false);
				m_bgmMuted = false;
				trace("[music_player] unmute vol=" + m_bgmMuteWas);
			};
			if (m_localChannel)
			{
				m_localChannel.soundTransform = new SoundTransform(m_bgmMuted ? 0 : m_bgmMuteWas);
			};
		}

		private function isMenuBgm(id:String):Boolean
		{
			return (id == "menumusic" || id == "menumusic1" || id == "menumusic2" || id == "meleemenu2");
		}

		private function playMenuPlaylist():Boolean
		{
			var songs:Array;
			var SQ:*;
			var inst:*;
			var current:String;
			var tid:String;
			var hold:*;
			if (!m_store)
			{
				return (false);
			};
			try
			{
				if (m_host && m_host.getSessionFlag is Function)
				{
					hold = m_host.getSessionFlag("music_player.bgm_hold", null);
					if (hold === true || hold === 1 || hold === "true")
					{
						return (true);
					};
				};
			}
			catch (holdErr:*)
			{
			};
			m_store.syncMenuMusicFromDisk();
			songs = m_store.songsForPlaylist(MusicPlaylistStore.MENU_PLAYLIST_ID);
			if (!m_store.menuMusicEnabled())
			{
				songs = null;
			};
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
				inst = SQ ? SQ.instance : null;
				current = inst && inst.CurrentSongID ? String(inst.CurrentSongID) : "";
			}
			catch (curErr:*)
			{
				current = "";
				inst = null;
			};
			if (!songs || songs.length < 1)
			{
				tid = MenuReplay.keepId(current, m_pinnedMenuId, null);
				if (!tid)
				{
					return (false);
				};
				if (tid == current)
				{
					noteMenuPlaying(tid);
					return (true);
				};
				return (playPinnedMenu(inst, tid));
			};
			tid = MenuReplay.keepId(current, m_pinnedMenuId, songs);
			if (!tid)
			{
				tid = String(songs[int(Math.random() * songs.length)]);
			};
			if (tid == current)
			{
				noteMenuPlaying(tid);
				return (true);
			};
			return (playPinnedMenu(inst, tid));
		}

		/** Stock menumusic just started. Remember which of the three is up so the next request keeps it. */
		private function pinMenuFromQueue(SQ:*):void
		{
			var id:String;
			try
			{
				id = (SQ && SQ.instance && SQ.instance.CurrentSongID) ? String(SQ.instance.CurrentSongID) : "";
			}
			catch (err:*)
			{
				id = "";
			};
			if (MenuReplay.isStockMenu(id) && id != "menumusic")
			{
				noteMenuPlaying(id);
			};
		}

		private function playPinnedMenu(inst:*, id:String):Boolean
		{
			var loop:Number;
			if (!id)
			{
				return (false);
			};
			loop = 0;
			if (m_catalog)
			{
				loop = m_catalog.loopMs(id);
			};
			if (!(loop >= 0))
			{
				loop = 0;
			};
			trace("[music_player] menu playlist id=" + id);
			try
			{
				if (inst && inst.playMusicStock)
				{
					inst.playMusicStock(id, loop);
				};
			}
			catch (err:*)
			{
				trace("[music_player] menu playlist failed: " + err);
				return (false);
			};
			noteMenuPlaying(id);
			return (true);
		}

		private function noteMenuPlaying(id:String):void
		{
			m_pinnedMenuId = id;
			m_menuPlayback = true;
			m_expectAdvance = false;
		}

		/** Same value the Sounds menu writes: SaveData.BGVolumeLevel plus SoundQueue.setMusicVolume. */
		public function applyBgmVolume(vol:Number, save:Boolean = false):void
		{
			var SD:*;
			var SQ:*;
			if (!(vol >= 0))
			{
				vol = 0;
			};
			if (vol > 1)
			{
				vol = 1;
			};
			if (save)
			{
				trace("[music_player] volume=" + vol);
			};
			try
			{
				SD = EngineRefs.ssf2("util.SaveData");
				if (SD)
				{
					SD.BGVolumeLevel = vol;
					if (save)
					{
						SD.saveGame();
					};
				};
			}
			catch (err:*)
			{
			};
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
				if (SQ && SQ.instance)
				{
					SQ.instance.setMusicVolume(vol);
					SQ.instance.updateVolumeLevel();
				};
			}
			catch (err2:*)
			{
			};
			try
			{
				PitchShiftBridge.updateVolume(vol);
			}
			catch (err3:*)
			{
			};
			if (m_localChannel)
			{
				m_localChannel.soundTransform = new SoundTransform(vol);
			};
		}

		internal function notify(msg:String):void
		{
			try
			{
				var MM:* = EngineRefs.ssf2("net.MultiplayerManager");
				if (MM && MM["notify"])
				{
					MM["notify"](msg);
					return;
				};
			}
			catch (err:*)
			{
			};
			trace("[music_player] " + msg);
		}
	}
}
