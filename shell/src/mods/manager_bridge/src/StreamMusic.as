package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.utils.Timer;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;

	/**
	 * Music: now-playing.json, menu-music.json, menu playlist patch, forced match
	 * music, previews and the song HUD.
	 */
	internal class StreamMusic
	{
		private var core:Ssf2StreamMod;
		private var m_pendingMusicId:String;
		private var m_menuMusicId:String;
		private var m_lastNowPlayingId:String;
		private var m_nowPlayingFile:File;
		private var m_nowPlayingFileKey:String;
		private var m_menuPlaylist:Array;
		private var m_menuMusicEnabled:Boolean;
		private var m_menuMusicLoop:Number;
		private var m_blockMenuMusic:Boolean;
		private var m_forcePreview:Boolean;
		private var m_syncResourceId:String;
		private var m_syncLinkage:String;
		private var m_seekAfterPlay:Number;
		private var m_syncPaused:Boolean;
		private var m_syncPauseMs:Number;
		private var m_lastNowPlayingPaused:Boolean;
		private var m_songHudTimer:Timer;
		private var m_songHudWrap:Sprite;

		public function StreamMusic(owner:Ssf2StreamMod)
		{
			core = owner;
			m_pendingMusicId = "";
			m_menuMusicId = "";
			m_menuPlaylist = [];
			m_menuMusicEnabled = false;
			m_menuMusicLoop = 0;
			m_blockMenuMusic = false;
		}

		/**
		 * Multiman/CustomMode builds a fresh Game for startMatch and drops musicOverride.
		 * MODE_START fires after GameController picks stageMusic but before StageData —
		 * rewrite stageMusic/loopLoc so the match plays the Match Setup track.
		 */
		internal function onModeStart(ctx:Object):void
		{
			var musicId:String;
			var GC:Class;
			var RM:Class;
			var game:*;
			var res:*;
			core.eventsCtl.applyEventCharacterOverride(ctx);
			m_blockMenuMusic = true;
			if (!core.m_match && !(core.m_musicEverywhere && core.m_forcedMusicId))
			{
				return;
			};
			musicId = core.m_match ? String(core.m_match["music"] || "") : "";
			if (musicId.length < 1 && core.m_musicEverywhere && core.m_forcedMusicId)
			{
				musicId = core.m_forcedMusicId;
			};
			if (musicId.length < 1)
			{
				return;
			};
			try
			{
				GC = EngineRefs.GameController as Class;
				RM = EngineRefs.ResourceManager as Class;
				game = ctx && ctx["game"] ? ctx["game"] : (GC ? GC["currentGame"] : null);
				if (game && game["LevelData"])
				{
					game["LevelData"]["musicOverride"] = musicId;
				};
				if (!RM || !GC)
				{
					return;
				};
				m_pendingMusicId = musicId;
				if (core.m_host && core.m_host.ensureResourcesLoaded)
				{
					core.m_host.ensureResourcesLoaded([musicId], function():void
					{
						applyForcedMusicNow(musicId);
					}, function():void
					{
						log("MODE_START ensure failed " + musicId);
						m_pendingMusicId = "";
					});
					return;
				};
				res = RM["getResourceByID"](musicId, true);
				if (!res)
				{
					RM["queueResources"]([musicId]);
					RM["load"]({"oncomplete": onMusicPreviewLoaded});
					log("MODE_START music queued (not loaded yet) " + musicId);
					return;
				};
				applyForcedMusicNow(musicId);
			}
			catch (err:*)
			{
				log("MODE_START music force: " + err);
			};
		}

		private function applyForcedMusicNow(musicId:String):void
		{
			var GC:Class;
			var RM:Class;
			var res:*;
			var linkage:String;
			var loopLoc:Number;
			var songName:String;
			if (!musicId || musicId.length < 1)
			{
				return;
			};
			try
			{
				GC = EngineRefs.GameController as Class;
				RM = EngineRefs.ResourceManager as Class;
				res = RM ? RM["getResourceByID"](musicId, true) : null;
				if (!res)
				{
					log("MODE_START apply: not loaded " + musicId);
					return;
				};
				linkage = String(res["getProp"]("music") || "");
				if (linkage.length < 1)
				{
					linkage = musicId;
				};
				loopLoc = 0;
				try
				{
					if (res["getProp"]("musicLoop") !== undefined && res["getProp"]("musicLoop") !== null)
					{
						loopLoc = Number(res["getProp"]("musicLoop")) || 0;
					};
				}
				catch (loopErr:*)
				{
				};
				if (GC)
				{
					GC["stageMusic"] = linkage;
					GC["loopLoc"] = loopLoc;
				};
				songName = resolveMusicDisplayName(musicId, res);
				try
				{
					if (GC && GC["hud"] && GC["hud"]["displayMusicInfo"])
					{
						GC["hud"]["displayMusicInfo"](songName);
					};
				}
				catch (hudErr:*)
				{
				};
				log("MODE_START forced music=" + musicId + " linkage=" + linkage + " name=" + songName);
			}
			catch (err:*)
			{
				log("MODE_START applyForcedMusicNow: " + err);
			};
		}

		internal function onMatchEndMusic(ctx:Object):void
		{
			m_blockMenuMusic = false;
		}

		internal function queueStageMusic(RM:Class, stageId:String, toLoad:Array):void
		{
			var res:*;
			var list:*;
			var i:int;
			var id:String;
			if (!RM || !stageId || !toLoad)
			{
				return;
			};
			try
			{
				res = RM["getResourceByID"](stageId);
				list = res ? res["getProp"]("music") : null;
				if (!list)
				{
					return;
				};
				i = 0;
				while (i < list["length"])
				{
					id = String(list[i]["id"] || "");
					if (id.length > 0)
					{
						toLoad.push(id);
					};
					i++;
				};
			}
			catch (err:*)
			{
			};
		}

		private function jukeboxDoor(name:String, args:Array):*
		{
			var host:*;
			try
			{
				host = EngineRefs.ModHost;
				if (host && host.door is Function)
				{
					return host.door(name, args, false);
				};
			}
			catch (err:*)
			{
				log("jukebox " + name + " failed: " + err);
			};
			return null;
		}

		internal function writeNowPlaying():void
		{
			var SQ:Class;
			var id:String;
			var file:File;
			var stream:FileStream;
			var name:String;
			var paused:Boolean;
			var st:*;
			try
			{
				id = "";
				name = "";
				paused = false;
				st = jukeboxDoor("managerState", []);
				if (st && st["trackId"])
				{
					id = String(st["trackId"]);
					name = st["title"] ? String(st["title"]) : "";
					paused = Boolean(st["paused"]);
				}
				else
				{
					SQ = EngineRefs.SoundQueue as Class;
					if (SQ && SQ["instance"])
					{
						id = String(SQ["instance"]["CurrentSongID"] || "");
					};
					if (m_syncPaused && m_syncResourceId)
					{
						id = m_syncResourceId;
					}
					else if (m_syncResourceId && (id == m_syncResourceId || id == m_syncLinkage))
					{
						id = m_syncResourceId;
					};
				};
				if (id.length < 1 && m_pendingMusicId)
				{
					id = m_pendingMusicId;
				};
				if (id == m_lastNowPlayingId && paused == m_lastNowPlayingPaused)
				{
					return;
				};
				m_lastNowPlayingPaused = paused;
				if (!name || name.length < 1)
				{
					name = prettyMusicLabel(id);
				try
				{
					var titled:String = resolveMusicDisplayName(id);
					if (titled && titled.length > 0)
					{
						name = titled;
					};
				}
				catch (nameErr:*)
				{
				};
				};
				var text:String = JSON.stringify({"id": id, "name": name, "paused": paused});
				if (!m_nowPlayingFile || m_nowPlayingFileKey != core.m_logFileAbs)
				{
					m_nowPlayingFile = core.bridgeFile("now-playing.json");
					m_nowPlayingFileKey = core.m_logFileAbs;
				};
				file = m_nowPlayingFile;
				if (!file)
				{
					return;
				};
				if (JsonFile.writeText(file, text))
				{
					m_lastNowPlayingId = id;
				};
			}
			catch (err:*)
			{
				core.logStepError("writeNowPlaying", err, true);
			};
		}

		internal function readMenuMusicFile():void
		{
			var file:File;
			var stream:FileStream;
			var text:String;
			var data:Object;
			try
			{
				file = core.bridgeFile("menu-music.json");
				data = JsonFile.read(file);
				if (!data)
				{
					return;
				};
				m_menuPlaylist = (data["playlist"] is Array) ? (data["playlist"] as Array) : [];
				if (data["id"])
				{
					m_menuMusicId = String(data["id"]);
				}
				else if (m_menuPlaylist && m_menuPlaylist.length > 0)
				{
					m_menuMusicId = String(m_menuPlaylist[0]);
				}
				else
				{
					m_menuMusicId = "";
				};
				// A leftover single-track id must not override the playlist.
				if (m_menuPlaylist && m_menuPlaylist.length > 0 && !menuPlaylistHas(m_menuMusicId))
				{
					m_menuMusicId = String(m_menuPlaylist[0]);
				};
				m_menuMusicLoop = Number(data["loop"]) || 0;
				if (data["enabled"] === undefined || data["enabled"] === null)
				{
					m_menuMusicEnabled = (m_menuMusicId && m_menuMusicId.length > 0)
						|| (m_menuPlaylist && m_menuPlaylist.length > 0);
				}
				else
				{
					m_menuMusicEnabled = Boolean(data["enabled"]);
				};
				log("menu music " + m_menuMusicId + " playlist=" + (m_menuPlaylist ? m_menuPlaylist.length : 0)
					+ " enabled=" + m_menuMusicEnabled);
			}
			catch (err:*)
			{
				core.logStepError("readMenuMusicFile", err);
			};
		}

		private function writeMenuMusicFile():void
		{
			var file:File;
			var stream:FileStream;
			var name:String;
			var i:int;
			var parts:Array;
			try
			{
				name = m_menuPlaylist && m_menuPlaylist.length > 1 ? "" : prettyMusicLabel(m_menuMusicId);
				if (m_menuPlaylist && m_menuPlaylist.length > 1)
				{
					i = 0;
					while (i < m_menuPlaylist.length)
					{
						if (i > 0)
						{
							name += ", ";
						};
						name += prettyMusicLabel(String(m_menuPlaylist[i]));
						i++;
					};
				};
				parts = [];
				i = 0;
				if (m_menuPlaylist)
				{
					while (i < m_menuPlaylist.length)
					{
						parts.push(String(m_menuPlaylist[i]));
						i++;
					};
				};
				file = core.bridgeFile("menu-music.json");
				if (!file)
				{
					return;
				};
				if (!JsonFile.write(file, {
					"id": m_menuMusicId || "",
					"name": name,
					"loop": m_menuMusicLoop,
					"enabled": m_menuMusicEnabled,
					"playlist": parts
				}))
				{
					log("writeMenuMusicFile: write failed");
				};
			}
			catch (err:*)
			{
				log("writeMenuMusicFile: " + err);
			};
		}

		internal function armMenuMusicPatch():void
		{
			var hasMenu:Boolean;
			hasMenu = m_menuMusicEnabled && ((m_menuMusicId && m_menuMusicId.length > 0)
				|| (m_menuPlaylist && m_menuPlaylist.length > 0));
			if (!core.m_host)
			{
				return;
			};
			if (!hasMenu)
			{
				try
				{
					core.m_host.unpatch("playMusic");
				}
				catch (unErr:*)
				{
				};
				return;
			};
			try
			{
				core.m_host.patch("playMusic", onMenuPlayMusic);
			}
			catch (err:*)
			{
				log("menu music patch: " + err);
			};
			try
			{
				core.m_host.saveExtSet("menu_music_id", m_menuMusicId);
				core.m_host.saveExtSet("menu_music_loop", m_menuMusicLoop);
			}
			catch (saveErr:*)
			{
			};
		}

		private function menuPlaylistHas(id:String):Boolean
		{
			var i:int;
			if (!id || !m_menuPlaylist)
			{
				return (false);
			};
			i = 0;
			while (i < m_menuPlaylist.length)
			{
				if (String(m_menuPlaylist[i]) == id)
				{
					return (true);
				};
				i++;
			};
			return (false);
		}

		private function pickMenuTrack():void
		{
			var i:int;
			var next:String;
			if (!m_menuPlaylist || m_menuPlaylist.length < 1)
			{
				return;
			};
			i = int(Math.random() * m_menuPlaylist.length);
			if (m_menuPlaylist.length > 1 && String(m_menuPlaylist[i]) == m_menuMusicId)
			{
				i = (i + 1) % m_menuPlaylist.length;
			};
			next = String(m_menuPlaylist[i] || "");
			if (next.length > 0)
			{
				m_menuMusicId = next;
			};
		}

		private function onMenuPlayMusic(soundName:String, loopLoc:Number):void
		{
			var linkage:String;
			var RM:Class;
			if (m_blockMenuMusic || !isMenuSound(soundName))
			{
				playMusicDirect(soundName, loopLoc);
				return;
			};
			// Menus re-request menumusic on every show — keep the current track if one is up.
			if (isMusicActivelyPlaying())
			{
				return;
			};
			pickMenuTrack();
			if (m_menuMusicId && m_menuMusicId.length > 0)
			{
				linkage = resolveMusicLinkage(m_menuMusicId);
				if (linkage && linkage.length > 0)
				{
					playMusicDirect(linkage, m_menuMusicLoop);
					return;
				};
				try
				{
					RM = EngineRefs.ResourceManager as Class;
					if (RM)
					{
						RM["queueResources"]([m_menuMusicId]);
						RM["load"]({"oncomplete": onMenuMusicLoaded});
						return;
					};
				}
				catch (err:*)
				{
				};
			};
			playMusicDirect(soundName, loopLoc);
		}

		private function isMusicActivelyPlaying():Boolean
		{
			var SQ:Class;
			var inst:*;
			var song:*;
			var id:String;
			var hold:*;
			try
			{
				if (core.m_host && core.m_host.getSessionFlag is Function)
				{
					hold = core.m_host.getSessionFlag("music_player.bgm_hold", null);
					if (hold === true || hold === 1 || hold === "true")
					{
						return (true);
					};
				};
			}
			catch (holdErr:*)
			{
			};
			try
			{
				SQ = EngineRefs.SoundQueue as Class;
				inst = SQ ? SQ["instance"] : null;
				if (!inst)
				{
					return (false);
				};
				song = inst["CurrentSong"];
				if (song)
				{
					return (true);
				};
				id = inst["CurrentSongID"] ? String(inst["CurrentSongID"]) : "";
				return (id.length > 0);
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function onMenuMusicLoaded(e:* = null):void
		{
			var linkage:String;
			// Jukebox may have claimed BGM while this resource was loading.
			if (isMusicActivelyPlaying())
			{
				return;
			};
			linkage = resolveMusicLinkage(m_menuMusicId);
			if (linkage && linkage.length > 0)
			{
				playMusicDirect(linkage, m_menuMusicLoop);
			};
		}

		private function isMenuSound(id:String):Boolean
		{
			return (id == "menumusic" || id == "menumusic1" || id == "menumusic2" || id == "meleemenu2");
		}

		private function resolveMusicLinkage(musicId:String):String
		{
			var RM:Class;
			var res:*;
			var linkage:String;
			try
			{
				RM = EngineRefs.ResourceManager as Class;
				res = (RM && musicId) ? RM["getResourceByID"](musicId, true) : null;
				if (!res)
				{
					return ("");
				};
				linkage = String(res["getProp"]("music") || "");
				if (linkage.length < 1 || linkage == "null")
				{
					linkage = musicId;
				};
				if (res["getProp"]("musicLoop") !== undefined && res["getProp"]("musicLoop") !== null)
				{
					m_menuMusicLoop = Number(res["getProp"]("musicLoop")) || 0;
				};
				return (linkage);
			}
			catch (err:*)
			{
			};
			return ("");
		}

		private function replayPatchedMenu():void
		{
			var SQ:Class;
			try
			{
				SQ = EngineRefs.SoundQueue as Class;
				if (SQ && SQ["instance"] && SQ["instance"]["playMusic"])
				{
					SQ["instance"]["playMusic"]("menumusic", 0);
				};
			}
			catch (err:*)
			{
				log("replayPatchedMenu: " + err);
			};
		}

		/** Deep-link menus can skip the home track — start menu music after soft open if silent. */
		internal function ensureMenuMusicPlaying():void
		{
			var linkage:String;
			try
			{
				if (isMusicActivelyPlaying())
				{
					return;
				};
				if (m_menuPlaylist && m_menuPlaylist.length > 1)
				{
					pickMenuTrack();
				};
				if (m_menuMusicId && m_menuMusicId.length > 0)
				{
					linkage = resolveMusicLinkage(m_menuMusicId);
					if (linkage && linkage.length > 0)
					{
						playMusicDirect(linkage, m_menuMusicLoop);
						return;
					};
					previewMusic(m_menuMusicId);
					return;
				};
				replayPatchedMenu();
			}
			catch (err:*)
			{
				log("ensureMenuMusicPlaying: " + err);
			};
		}

		internal function playMusicDirect(id:String, loop:Number):void
		{
			var SQ:Class;
			var hold:*;
			if (!id || id.length < 1)
			{
				return;
			};
			// Never layer menu/stream BGM over an active jukebox hold (local channel).
			try
			{
				if (core.m_host && core.m_host.getSessionFlag is Function)
				{
					hold = core.m_host.getSessionFlag("music_player.bgm_hold", null);
					if (hold === true || hold === 1 || hold === "true")
					{
						log("playMusicDirect jukebox " + id);
						jukeboxDoor("managerPlay", [id, 0, false]);
						return;
					};
				};
			}
			catch (holdErr:*)
			{
			};
			try
			{
				SQ = EngineRefs.SoundQueue as Class;
				if (SQ && SQ["instance"])
				{
					if (SQ["instance"]["playMusicStock"])
					{
						SQ["instance"]["playMusicStock"](id, loop);
					}
					else if (SQ["instance"]["playMusic"])
					{
						SQ["instance"]["playMusic"](id, loop);
					};
				};
			}
			catch (err:*)
			{
				log("playMusicDirect: " + err);
			};
		}

		internal function ensureMatchMusicQueued(game:*):void
		{
			var musicId:String;
			var RM:Class;
			if (!game || !core.m_match)
			{
				return;
			};
			musicId = String(core.m_match["music"] || "");
			if (musicId.length < 1 && core.m_musicEverywhere && core.m_forcedMusicId)
			{
				musicId = core.m_forcedMusicId;
			};
			if (musicId.length < 1)
			{
				return;
			};
			try
			{
				if (game["LevelData"])
				{
					game["LevelData"]["musicOverride"] = musicId;
				};
				RM = EngineRefs.ResourceManager as Class;
				if (RM)
				{
					RM["queueResources"]([musicId]);
				};
			}
			catch (err:*)
			{
				log("ensureMatchMusicQueued: " + err);
			};
		}

		internal function applyMenuMusicCmd(data:Object):void
		{
			var list:Array;
			m_menuMusicLoop = 0;
			list = data && data["playlist"] is Array ? (data["playlist"] as Array) : null;
			if (list && list.length > 0)
			{
				m_menuPlaylist = list;
				m_menuMusicId = String(list[0] || "");
			}
			else
			{
				m_menuMusicId = String(data["musicId"] || data["id"] || "");
				m_menuPlaylist = m_menuMusicId ? [m_menuMusicId] : [];
			};
			if (data && data["enabled"] !== undefined && data["enabled"] !== null)
			{
				m_menuMusicEnabled = Boolean(data["enabled"]);
			}
			else
			{
				m_menuMusicEnabled = (m_menuPlaylist && m_menuPlaylist.length > 0);
			};
			writeMenuMusicFile();
			armMenuMusicPatch();
			if (!m_menuMusicEnabled)
			{
				playMusicDirect("menumusic", 0);
				return;
			};
			if (m_menuPlaylist && m_menuPlaylist.length > 1)
			{
				pickMenuTrack();
			};
			if (m_menuMusicId)
			{
				previewMusic(m_menuMusicId);
			};
		}

		/** Turn off custom menu music but keep the playlist on disk. */
		internal function disableMenuMusic():void
		{
			m_menuMusicEnabled = false;
			writeMenuMusicFile();
			armMenuMusicPatch();
			try
			{
				if (core.m_host)
				{
					core.m_host.saveExtSet("menu_music_id", null);
					core.m_host.saveExtSet("menu_music_loop", 0);
				};
			}
			catch (err:*)
			{
			};
		}

		internal function playStageDefault():void
		{
			var GC:Class;
			var RM:Class;
			var game:*;
			var stageId:String;
			var res:*;
			var list:*;
			var musicId:String;
			clearForcedMatchMusic();
			m_pendingMusicId = "";
			try
			{
				GC = EngineRefs.GameController as Class;
				RM = EngineRefs.ResourceManager as Class;
				game = GC ? GC["currentGame"] : null;
				if (GC && GC["stageData"] && game && game["LevelData"] && RM)
				{
					m_blockMenuMusic = true;
					stageId = String(game["LevelData"]["stage"] || "");
					res = stageId ? RM["getResourceByID"](stageId) : null;
					list = res ? res["getProp"]("music") : null;
					musicId = (list && list["length"] > 0) ? String(list[0]["id"] || "") : "";
					if (musicId.length > 0)
					{
						previewMusic(musicId);
						log("stage default music " + musicId);
						return;
					};
				};
				m_blockMenuMusic = false;
				replayPatchedMenu();
			}
			catch (err:*)
			{
				log("playStageDefault: " + err);
			};
		}

		/** Drop sticky match override from Configure "use everywhere". */
		internal function clearForcedMatchMusic():void
		{
			var GC:Class;
			var game:*;
			core.m_forcedMusicId = "";
			core.m_musicEverywhere = false;
			try
			{
				GC = EngineRefs.GameController as Class;
				game = GC ? GC["currentGame"] : null;
				if (game && game["LevelData"])
				{
					game["LevelData"]["musicOverride"] = null;
				};
			}
			catch (err:*)
			{
			};
		}

		internal function pauseSynced():void
		{
			m_syncPaused = true;
			jukeboxDoor("managerPause", []);
			log("pauseSynced jukebox");
		}

		internal function holdSyncPause():void
		{
		}

		internal function resumeSynced(ms:Number):void
		{
			var at:Number;
			m_syncPaused = false;
			at = ms > 0 ? ms : m_syncPauseMs;
			m_syncPauseMs = 0;
			jukeboxDoor("managerResume", [at]);
			log("resumeSynced jukebox ms=" + int(at));
		}

		internal function seekMusic(ms:Number):void
		{
			if (!(ms >= 0))
			{
				return;
			};
			if (m_syncPaused)
			{
				m_syncPauseMs = ms;
			};
			jukeboxDoor("managerSeek", [ms]);
			log("seekMusic jukebox ms=" + int(ms));
		}

		internal function previewMusic(id:String, force:Boolean = false, positionMs:Number = 0):void
		{
			var SQ:Class;
			var RM:Class;
			var res:*;
			m_forcePreview = force;
			m_seekAfterPlay = positionMs > 0 ? positionMs : 0;
			if (id && id.length > 0)
			{
				m_syncPaused = false;
			};
			if (!id || id.length < 1)
			{
				m_forcePreview = false;
				m_seekAfterPlay = 0;
				log("previewMusic: empty id");
				return;
			};
			m_pendingMusicId = id;
			m_syncResourceId = id;
			jukeboxDoor("managerPlay", [id, positionMs > 0 ? positionMs : 0, true]);
			log("previewMusic jukebox " + id + " pos=" + int(positionMs));
			m_pendingMusicId = "";
			return;
			try
			{
				RM = EngineRefs.ResourceManager as Class;
				SQ = EngineRefs.SoundQueue as Class;
				res = RM ? RM["getResourceByID"](id) : null;
				if (!res)
				{
					log("previewMusic: unknown resource " + id);
					m_pendingMusicId = "";
					return;
				};
				// Prefer host ensureResourcesLoaded so soft-fail packs finish before play.
				if (core.m_host && core.m_host.ensureResourcesLoaded)
				{
					log("previewMusic ensure " + id);
					core.m_host.ensureResourcesLoaded([id], function():void
					{
						playPendingMusic();
					}, function():void
					{
						log("previewMusic ensure failed " + id);
						m_pendingMusicId = "";
					});
					return;
				};
				if (!Boolean(RM["getResourceByID"](id, true)))
				{
					RM["queueResources"]([id]);
					RM["load"]({"oncomplete": onMusicPreviewLoaded, "onerror": onMusicPreviewFailed});
					log("previewMusic loading " + id);
					return;
				};
				playPendingMusic();
			}
			catch (err:*)
			{
				log("previewMusic failed: " + err);
				m_pendingMusicId = "";
			};
		}

		private function onMusicPreviewFailed(e:* = null):void
		{
			log("previewMusic load error for " + m_pendingMusicId);
			m_pendingMusicId = "";
		}

		private function onMusicPreviewLoaded(e:* = null):void
		{
			playPendingMusic();
		}

		private function playPendingMusic():void
		{
			var SQ:Class;
			var RM:Class;
			var id:String;
			var res:*;
			var linkage:String;
			var loopLoc:Number;
			var songName:String;
			var played:Boolean;
			id = m_pendingMusicId;
			if (!id)
			{
				return;
			};
			if (isMusicActivelyPlaying() && !m_forcePreview)
			{
				log("previewMusic skipped — BGM already held (" + id + ")");
				m_pendingMusicId = "";
				m_forcePreview = false;
				return;
			};
			m_forcePreview = false;
			played = false;
			try
			{
				RM = EngineRefs.ResourceManager as Class;
				SQ = EngineRefs.SoundQueue as Class;
				res = RM ? RM["getResourceByID"](id, true) : null;
				if (!res)
				{
					log("previewMusic play: resource not loaded " + id);
					m_pendingMusicId = "";
					return;
				};
				linkage = id;
				loopLoc = 0;
				try
				{
					if (res["getProp"]("music"))
					{
						linkage = String(res["getProp"]("music"));
					};
				}
				catch (propErr:*)
				{
				};
				try
				{
					if (res["getProp"]("musicLoop") !== undefined && res["getProp"]("musicLoop") !== null)
					{
						loopLoc = Number(res["getProp"]("musicLoop")) || 0;
					};
				}
				catch (loopErr:*)
				{
				};
				if (SQ && SQ["instance"] && SQ["instance"]["playMusicStock"])
				{
					SQ["instance"]["playMusicStock"](linkage, loopLoc);
					played = true;
					m_syncResourceId = id;
					m_syncLinkage = linkage;
					log("previewMusic " + id + " linkage=" + linkage);
				}
				else if (SQ && SQ["instance"] && SQ["instance"]["playMusic"])
				{
					SQ["instance"]["playMusic"](linkage, loopLoc);
					played = true;
					m_syncResourceId = id;
					m_syncLinkage = linkage;
					log("previewMusic(playMusic) " + id + " linkage=" + linkage);
				}
				else
				{
					log("previewMusic: SoundQueue missing");
				};
				if (played && m_seekAfterPlay > 0)
				{
					seekMusic(m_seekAfterPlay);
					m_seekAfterPlay = 0;
				};
				if (!played)
				{
					m_pendingMusicId = "";
					return;
				};
				songName = "";
				try
				{
					songName = resolveMusicDisplayName(id, res);
				}
				catch (nameErr:*)
				{
					songName = prettyMusicLabel(id);
				};
				showSongHud(songName);
			}
			catch (err:*)
			{
				log("previewMusic play failed: " + err);
			};
		}

		/** Same music_info clip HudMenu uses in-match (menu_hud library), not a custom banner. */
		private function showSongHud(songName:String):void
		{
			var GC:Class;
			var MainCls:Class;
			var RM:Class;
			var root:*;
			var musicInfo:MovieClip;
			var hudMC:MovieClip;
			var t:Timer;
			if (!songName || songName.length < 1)
			{
				return;
			};
			try
			{
				GC = EngineRefs.GameController as Class;
				if (GC && GC["hud"] && GC["hud"]["displayMusicInfo"])
				{
					GC["hud"]["displayMusicInfo"](songName);
					return;
				};
			}
			catch (hudErr:*)
			{
			};
			try
			{
				MainCls = EngineRefs.Main as Class;
				RM = EngineRefs.ResourceManager as Class;
				root = MainCls ? MainCls["Root"] : null;
				if (!root || !RM)
				{
					return;
				};
				musicInfo = root.getChildByName("ssf2_stream_music_info") as MovieClip;
				if (musicInfo && musicInfo.parent)
				{
					musicInfo.parent.removeChild(musicInfo);
					musicInfo = null;
				};
				// Also clear prior wrapper sprite if present.
				try
				{
					var oldWrap:Sprite = root.getChildByName("ssf2_stream_music_hud") as Sprite;
					if (oldWrap && oldWrap.parent)
					{
						oldWrap.parent.removeChild(oldWrap);
					};
				}
				catch (wrapRmErr:*)
				{
				};
				hudMC = RM["getLibraryMC"]("menu_hud") as MovieClip;
				if (!hudMC || !hudMC["music_info"])
				{
					log("showSongHud: menu_hud.music_info missing");
					return;
				};
				musicInfo = hudMC["music_info"] as MovieClip;
				if (!musicInfo)
				{
					return;
				};
				try
				{
					if (musicInfo.parent)
					{
						musicInfo.parent.removeChild(musicInfo);
					};
				}
				catch (detachErr:*)
				{
				};
				// Timeline-placed clips cannot be renamed (#2078) — wrap instead.
				var wrap:Sprite = new Sprite();
				wrap.name = "ssf2_stream_music_hud";
				wrap.mouseEnabled = false;
				wrap.mouseChildren = false;
				musicInfo.mouseEnabled = false;
				musicInfo.mouseChildren = false;
				try
				{
					musicInfo["music_info_bar"]["music_info_txt"].text = songName;
				}
				catch (txtErr:*)
				{
					log("showSongHud text: " + txtErr);
				};
				musicInfo.visible = true;
				musicInfo.gotoAndPlay(2);
				wrap.addChild(musicInfo);
				root.addChild(wrap);
				stopSongHudTimer();
				m_songHudWrap = wrap;
				t = new Timer(4000, 1);
				t.addEventListener(TimerEvent.TIMER, onSongHudTimer);
				m_songHudTimer = t;
				t.start();
			}
			catch (menuHudErr:*)
			{
				log("showSongHud: " + menuHudErr);
			};
		}

		private function stopSongHudTimer():void
		{
			if (m_songHudTimer)
			{
				m_songHudTimer.stop();
				m_songHudTimer.removeEventListener(TimerEvent.TIMER, onSongHudTimer);
				m_songHudTimer = null;
			};
		}

		private function onSongHudTimer(e:TimerEvent):void
		{
			var wrap:Sprite = m_songHudWrap;
			stopSongHudTimer();
			m_songHudWrap = null;
			try
			{
				if (wrap && wrap.parent)
				{
					wrap.parent.removeChild(wrap);
				};
			}
			catch (rmErr:*)
			{
			};
		}

		internal function stopPreviewMusic():void
		{
			var SQ:Class;
			try
			{
				SQ = EngineRefs.SoundQueue as Class;
				if (SQ && SQ["instance"] && SQ["instance"]["stopMusic"])
				{
					SQ["instance"]["stopMusic"]();
					log("stopMusic ok");
				};
			}
			catch (err:*)
			{
				log("stopMusic failed: " + err);
			};
			m_pendingMusicId = null;
		}

		internal function prettyMusicLabel(id:String):String
		{
			var s:String;
			s = String(id || "");
			if (s.indexOf("bgm_") == 0)
			{
				s = s.substr(4);
			};
			return (s);
		}

		/** Prefer id3 title; never show a stripped id as if it were the real song name. */
		private function resolveMusicDisplayName(id:String, res:* = null):String
		{
			var id3:*;
			var name:String;
			var RM:Class;
			name = "";
			try
			{
				if (!res)
				{
					RM = EngineRefs.ResourceManager as Class;
					res = RM ? RM["getResourceByID"](id, true) : null;
				};
				if (res)
				{
					id3 = res["getProp"]("id3");
					if (id3 && id3["songName"])
					{
						name = String(id3["songName"]);
					};
					if ((!name || name.length < 1) && res["getProp"]("name"))
					{
						name = String(res["getProp"]("name"));
					};
				};
			}
			catch (err:*)
			{
			};
			if (name && name.length > 0)
			{
				return (name);
			};
			return (String(id || ""));
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
