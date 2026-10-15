package
{
	import flash.media.Sound;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.MusicOverrideCodec;

	/**
	 * Match-music selection: jukebox claim, stage playlist pick at MODE_START, replay stamp, match pause while the jukebox is open.
	 */
	public class MusicModMatchMusic
	{
		private static const ONLINE_MODE:int = 4;
		private static const ONLINE_ARENA_MODE:int = 14;

		private var mod:MusicPlayerMod;
		private var m_pausedForJukebox:Boolean;

		public function MusicModMatchMusic(owner:MusicPlayerMod)
		{
			mod = owner;
			m_pausedForJukebox = false;
		}

		internal function isInMatch():Boolean
		{
			var GC:*;
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				if (GC && GC["stageData"])
				{
					return (true);
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		/** Pause the live match while jukebox is open; leave already-paused matches alone. */
		internal function ensureMatchPaused():void
		{
			var GC:*;
			var sd:*;
			var game:*;
			var Mode:*;
			var training:Boolean;
			m_pausedForJukebox = false;
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				sd = GC ? GC["stageData"] : null;
				if (!sd)
				{
					return;
				};
				game = GC["currentGame"];
				Mode = EngineRefs.ssf2("enums.Mode");
				training = Boolean(Mode && game && game["GameMode"] == Mode["TRAINING"]);
				if (training)
				{
					if (Boolean(sd["FreezeKeys"]))
					{
						return;
					};
					sd["Paused"] = true;
					m_pausedForJukebox = true;
					return;
				};
				if (Boolean(sd["Paused"]))
				{
					return;
				};
				sd["Paused"] = true;
				if (!sd["PausedID"])
				{
					sd["PausedID"] = 1;
				};
				m_pausedForJukebox = true;
			}
			catch (err:*)
			{
				trace("[music_player] ensureMatchPaused: " + err);
				m_pausedForJukebox = false;
			};
		}

		internal function releaseMatchPause():void
		{
			var GC:*;
			var sd:*;
			var game:*;
			var Mode:*;
			var training:Boolean;
			if (!m_pausedForJukebox)
			{
				return;
			};
			m_pausedForJukebox = false;
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				sd = GC ? GC["stageData"] : null;
				if (!sd)
				{
					return;
				};
				game = GC["currentGame"];
				Mode = EngineRefs.ssf2("enums.Mode");
				training = Boolean(Mode && game && game["GameMode"] == Mode["TRAINING"]);
				if (training)
				{
					if (Boolean(sd["FreezeKeys"]))
					{
						sd["Paused"] = true;
					};
					return;
				};
				if (Boolean(sd["Paused"]))
				{
					sd["Paused"] = false;
				};
			}
			catch (err:*)
			{
				trace("[music_player] releaseMatchPause: " + err);
			};
		}

		internal function currentStageId():String
		{
			var GC:*;
			var game:*;
			var stageId:String;
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				game = GC ? GC["currentGame"] : null;
				if (game && game["LevelData"] && game["LevelData"]["stage"])
				{
					stageId = String(game["LevelData"]["stage"]);
					if (stageId && stageId != "random")
					{
						return (stageId);
					};
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function onSongPicked(trackId:String, bucketId:String, matchPick:Boolean):void
		{
			if (!trackId)
			{
				return;
			};
			mod.m_transport.releasePlaylistHold();
			trackId = MusicPacks.canonicalTrackId(trackId);
			if (mod.m_menuFlow.isAttractActive())
			{
				return;
			};
			mod.m_transport.playTrack(trackId);
			if (matchPick)
			{
				claimMatchMusic(trackId);
				mod.notify("Match music: " + matchPickTitle(trackId));
			};
		}

		/** playTrack loads async, so m_currentTitle still names the previous song here. */
		internal function matchPickTitle(trackId:String):String
		{
			var title:String = mod.m_catalog ? mod.m_catalog.songTitle(trackId) : "";
			return (title || trackId);
		}

		/** Last explicit pick (jukebox or camera BG) wins for the upcoming match. */
		private function claimMatchMusic(trackId:String):void
		{
			if (mod.m_menuFlow.isAttractActive())
			{
				return;
			};
			if (!trackId)
			{
				return;
			};
			mod.m_musicOverrideId = trackId;
			mod.m_musicClaimAt = getTimer();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_OVERRIDE, trackId);
					mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_CLAIM_ID, trackId);
					mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_CLAIM_AT, mod.m_musicClaimAt);
				};
			}
			catch (flagErr:*)
			{
			};
		}

		private function readClaimId():String
		{
			var id:*;
			try
			{
				if (mod.m_host)
				{
					id = mod.m_host.getSessionFlag(MusicPlayerMod.FLAG_CLAIM_ID, null);
					if (id)
					{
						return (String(id));
					};
				};
			}
			catch (err:*)
			{
			};
			return (mod.m_musicOverrideId);
		}

		private function readClaimAt():int
		{
			var at:*;
			try
			{
				if (mod.m_host)
				{
					at = mod.m_host.getSessionFlag(MusicPlayerMod.FLAG_CLAIM_AT, 0);
					if (at != null)
					{
						return (int(at));
					};
				};
			}
			catch (err:*)
			{
			};
			return (mod.m_musicClaimAt);
		}

		private function clearMatchMusicClaim():void
		{
			mod.m_musicOverrideId = null;
			mod.m_musicClaimAt = 0;
			try
			{
				if (mod.m_host)
				{
					mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_OVERRIDE, null);
					mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_CLAIM_ID, null);
					mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_CLAIM_AT, 0);
				};
			}
			catch (err:*)
			{
			};
		}

		/**
		 * Match owns BGM. Arena/custom modes skip Stage Select, so apply the jukebox
		 * stage playlist here (MODE_START is after stageMusic pick, before StageData).
		 * If the pick is not loaded yet, leave StageData silent and force-play once the
		 * SWF finishes — otherwise the first arena match gets silence / a stale retry.
		 */
		internal function onModeStart(ctx:Object):void
		{
			var GC:*;
			var game:*;
			var id:String;
			if (mod.m_menuFlow.isAttractActive())
			{
				mod.m_nowPlaying.setBgmHold(false);
				mod.m_local.stopLocalPlayback();
				mod.m_musicOverrideId = null;
				return;
			};
			resetPlaybackForMatch();
			game = ctx ? ctx["game"] : null;
			GC = null;
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				if (!game && GC)
				{
					game = GC.currentGame;
				};
			}
			catch (gcErr:*)
			{
				GC = null;
			};
			id = chooseMatchTrackId(game);
			if (!id)
			{
				return;
			};
			id = MusicPacks.canonicalTrackId(id);
			try
			{
				if (game && game["LevelData"])
				{
					game["LevelData"]["musicOverride"] = id;
				};
			}
			catch (ldErr:*)
			{
			};
			if (mod.m_local.localFileFor(id) || id.indexOf("bgm_upload_") == 0)
			{
				armLocalMatchTrack(id, GC);
				return;
			};
			mod.m_armUploadId = null;
			startStockMatchTrack(id, GC);
		}

		/** MODE_START: drop playlist hold / local Sound / stock BGM before the match picks music. */
		private function resetPlaybackForMatch():void
		{
			var SQ:*;
			mod.m_transport.releasePlaylistHold();
			mod.m_nowPlaying.setBgmHold(false);
			mod.m_local.stopLocalPlayback();
			mod.m_pausePos = 0;
			mod.m_expectAdvance = false;
			mod.m_announceHud = false;
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
				if (SQ && SQ.instance && SQ.instance.stopMusic)
				{
					SQ.instance.stopMusic();
				};
			}
			catch (stopErr:*)
			{
			};
		}

		/**
		 * Track for this match: stamped override, else jukebox claim, else live override,
		 * else weighted stage playlist pick. Null = leave StageData's own music alone.
		 */
		private function chooseMatchTrackId(game:*):String
		{
			var id:String;
			var claimId:String;
			var stageId:String;
			var pick:String;
			id = "";
			if (game && game["LevelData"])
			{
				id = String(game["LevelData"]["musicOverride"] || "");
			};
			// Replay: missing pack/upload music → clear override so stage default plays.
			if (id && id != "null" && game && game["ReplayDataObj"]
				&& !mod.m_local.localFileFor(id) && !musicResourceKnown(id))
			{
				try
				{
					game["LevelData"]["musicOverride"] = null;
				}
				catch (clrErr:*)
				{
				};
				mod.m_armUploadId = null;
				trace("[music_player] replay music missing — using stage default (" + id + ")");
				return (null);
			};
			// Replays must not inject live jukebox claims/playlists — only stamped override.
			if (game && game["ReplayDataObj"] && (!id || id == "null"))
			{
				mod.m_armUploadId = null;
				return (null);
			};
			// Online: only the host's track (musicOverride); a local claim or pick would differ per player.
			if (isOnlineGame(game) && (!id || id == "null"))
			{
				mod.m_armUploadId = null;
				return (null);
			};
			claimId = readClaimId();
			if ((!id || id == "null") && claimId)
			{
				id = claimId;
			};
			if ((!id || id == "null") && mod.m_musicOverrideId)
			{
				id = mod.m_musicOverrideId;
			};
			if ((!id || id == "null") && mod.m_store && game && game["LevelData"])
			{
				stageId = resolvePlaylistStageId(game);
				if (stageId && (mod.m_store.hasCustomStageSongs(stageId) || MusicPacks.hasTracks(stageId)))
				{
					pick = mod.m_store.pickWeightedTrack(stageId);
					if (pick)
					{
						id = pick;
					};
				};
			};
			if (!id || id == "null")
			{
				mod.m_armUploadId = null;
				return (null);
			};
			return (id);
		}

		/** Upload / folder track: arm the playMusic patch and start the local Sound now. */
		private function armLocalMatchTrack(id:String, GC:*):void
		{
			var loop:Number;
			var path:String;
			loop = 0;
			if (mod.m_catalog)
			{
				loop = mod.m_catalog.loopMs(id);
			};
			if (!(loop > 0))
			{
				loop = 0;
			};
			mod.m_armUploadId = id;
			if (GC)
			{
				GC.stageMusic = id;
				GC.loopLoc = loop;
			};
			path = mod.m_local.localFileFor(id);
			if (path)
			{
				mod.m_local.playLocalTrack(id, path, 0);
			};
		}

		/** Stock / pack track: play now when loaded, else silence StageData and play once loaded. */
		private function startStockMatchTrack(id:String, GC:*):void
		{
			var loop:Number;
			var linkage:String;
			var loaded:Boolean;
			loaded = musicResourceReady(id);
			linkage = mod.m_loader.resolveMusicLinkage(id);
			if (!linkage)
			{
				linkage = id;
			};
			loop = mod.m_loader.resolveMusicLoop(id);
			if (!(loop >= 0))
			{
				loop = 0;
			};
			if (loaded)
			{
				mod.m_pendingMatchMusicId = null;
				if (GC)
				{
					GC.stageMusic = linkage;
					GC.loopLoc = loop;
				};
				applyMatchTrackNow(id, true);
				return;
			};
			deferMatchTrack(id, GC);
		}

		// Not loaded yet — StageData would play a broken/default id. Stay silent until
		// the SWF is ready, then force-play after StageData's own playMusic tick.
		private function deferMatchTrack(id:String, GC:*):void
		{
			mod.m_pendingMatchMusicId = id;
			if (GC)
			{
				GC.stageMusic = null;
				GC.loopLoc = 0;
			};
			if (mod.m_host && mod.m_host.ensureResourcesLoaded is Function)
			{
				mod.m_host.ensureResourcesLoaded([id], function():void
				{
					schedulePendingMatchMusic(id);
				}, function():void
				{
					if (mod.m_pendingMatchMusicId == id)
					{
						mod.m_pendingMatchMusicId = null;
					};
					trace("[music_player] MODE_START ensure failed " + id);
				});
				return;
			};
			schedulePendingMatchMusic(id);
		}

		private function musicResourceReady(trackId:String):Boolean
		{
			var RM:*;
			if (!trackId)
			{
				return (false);
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				return Boolean(RM && RM.getResourceByID(trackId, true));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		/** True if the resource exists in this build (loaded or not). */
		private function musicResourceKnown(trackId:String):Boolean
		{
			var RM:*;
			if (!trackId)
			{
				return (false);
			};
			if (mod.m_local.localFileFor(trackId) || trackId.indexOf("bgm_upload_") == 0)
			{
				return Boolean(mod.m_local.localFileFor(trackId));
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				return Boolean(RM && RM.getResourceByID(trackId, false));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		/** After StageData is live, stamp current musicOverride into replay MatchSettings. */
		internal function onMatchStartStamp(ctx:Object):void
		{
			mod.m_input.disarmMenuJukeboxChord();
			mod.m_transport.releasePlaylistHold();
			setTimeout(function ():void
			{
				stampReplayMusicOverride();
			}, 0);
		}

		private function stampReplayMusicOverride():void
		{
			var GC:*;
			var sd:*;
			var rd:*;
			var ms:Object;
			var game:*;
			var id:String;
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				sd = GC ? GC["stageData"] : null;
				if (!sd || sd["ReplayMode"])
				{
					return;
				};
				rd = sd["ReplayDataObj"];
				game = sd["GAME"] || (ctxGameSafe(sd));
				if (!rd)
				{
					return;
				};
				ms = rd["MatchSettings"] as Object;
				if (!ms)
				{
					ms = {};
					rd["MatchSettings"] = ms;
				};
				id = "";
				if (game && game["LevelData"] && game["LevelData"]["musicOverride"])
				{
					id = String(game["LevelData"]["musicOverride"]);
				};
				if ((!id || id == "null") && mod.m_musicOverrideId)
				{
					id = mod.m_musicOverrideId;
				};
				if (id && id != "null")
				{
					ms["musicOverride"] = MusicPacks.canonicalTrackId(id);
				};
			}
			catch (err:*)
			{
			};
		}

		private function ctxGameSafe(sd:*):*
		{
			try
			{
				return sd["GameRef"];
			}
			catch (err:*)
			{
			};
			return null;
		}

		/** Probe: does the MGN server keep a top-level key the host adds to room data? Vanilla reads only version, protocol and matchSettings. */
		internal function onBeforeSendRoomData(ctx:Object):void
		{
			var roomData:Object = ctx ? ctx["roomData"] as Object : null;
			if (!roomData)
			{
				return;
			};
			roomData["ssf2mm"] = {"v": 1, "probe": "hello"};
			trace("[music_player] net room send ssf2mm=" + JSON.stringify(roomData["ssf2mm"]));
		}

		internal function onRoomDataReceived(ctx:Object):void
		{
			var roomData:Object = ctx ? ctx["roomData"] as Object : null;
			var keys:Array = [];
			var k:String;
			if (!roomData)
			{
				trace("[music_player] net room recv none");
				return;
			};
			for (k in roomData)
			{
				keys.push(k);
			};
			keys.sort();
			trace("[music_player] net room recv keys=" + keys.join(",") + " ssf2mm=" + (roomData["ssf2mm"] ? JSON.stringify(roomData["ssf2mm"]) : "none"));
		}

		/** Replay import: drop musicOverride when this build lacks the track. */
		internal function onSettingsApply(ctx:Object):void
		{
			var settings:*;
			var data:Object;
			var id:String;
			if (!ctx)
			{
				return;
			};
			settings = ctx["settings"];
			data = ctx["data"] as Object;
			id = "";
			if (data && String(data["musicOverride"]).indexOf("|") >= 0)
			{
				applyNetOverride(settings, String(data["musicOverride"]));
				return;
			};
			// Prefer raw data; sealed GameSettings only exposes known fields.
			if (data && data["musicOverride"] != null && String(data["musicOverride"]) != "null")
			{
				id = String(data["musicOverride"]);
			}
			else
			{
				try
				{
					if (settings && settings.musicOverride)
					{
						id = String(settings.musicOverride);
					};
				}
				catch (readErr:*)
				{
				};
			};
			if (!id || id == "null")
			{
				return;
			};
			if (mod.m_local.localFileFor(id) || musicResourceKnown(id))
			{
				return;
			};
			try
			{
				if (settings)
				{
					settings.musicOverride = null;
				};
			}
			catch (setErr:*)
			{
			};
			try
			{
				if (data)
				{
					data["musicOverride"] = null;
				};
			}
			catch (dataErr:*)
			{
			};
			trace("[music_player] SETTINGS_APPLY dropped missing musicOverride " + id);
		}

		/**
		 * Host value "track|bg=stage": keep only the track on GameSettings (a missing track leaves
		 * stock stage music from the shared seed). Raw data stays as sent for camera_background.
		 */
		private function applyNetOverride(settings:*, raw:String):void
		{
			var track:String = MusicOverrideCodec.decode(raw).track;
			var local:String = "stock";
			if (track && (mod.m_local.localFileFor(track) || musicResourceKnown(track)))
			{
				local = track;
			};
			try
			{
				if (settings)
				{
					settings.musicOverride = local == "stock" ? null : local;
				};
			}
			catch (setErr:*)
			{
				trace("[music_player] net music apply failed: " + setErr);
			};
			trace("[music_player] net music raw=" + raw + " track=" + track + " local=" + local);
		}

		private static function isOnlineGame(game:*):Boolean
		{
			var mode:int;
			try
			{
				mode = int(game ? game["GameMode"] : -1);
			}
			catch (modeErr:*)
			{
				return false;
			};
			return mode == ONLINE_MODE || mode == ONLINE_ARENA_MODE;
		}

		/** After StageData.startGame2 (2-frame delay) so playMusic(null) cannot clobber us. */
		private function schedulePendingMatchMusic(trackId:String):void
		{
			if (!trackId)
			{
				return;
			};
			setTimeout(function ():void
			{
				if (mod.m_pendingMatchMusicId != trackId)
				{
					return;
				};
				mod.m_pendingMatchMusicId = null;
				applyMatchTrackNow(trackId, true);
			}, 200);
		}

		/** Map arena mode ids (soccer/basketball) onto jukebox Other Stages keys. */
		private function resolvePlaylistStageId(game:*):String
		{
			var stageId:String;
			var modeId:String;
			if (!game || !game["LevelData"])
			{
				return ("");
			};
			stageId = String(game["LevelData"]["stage"] || "");
			if (stageId == "sandbagsoccer" || stageId == "sandbagbasketball")
			{
				return (stageId);
			};
			modeId = String(game["LevelData"]["customModeID"] || "");
			if (modeId == "soccer")
			{
				return ("sandbagsoccer");
			};
			if (modeId == "basketball")
			{
				return ("sandbagbasketball");
			};
			return (stageId);
		}

		/**
		 * @param forcePlay When true, StageData already started (or will start silent) —
		 * start the track via SoundQueue now that the resource is ready.
		 */
		private function applyMatchTrackNow(trackId:String, forcePlay:Boolean = false):void
		{
			var GC:*;
			var SQ:*;
			var linkage:String;
			var loop:Number;
			var title:String;
			if (!trackId)
			{
				return;
			};
			linkage = mod.m_loader.resolveMusicLinkage(trackId);
			if (!linkage)
			{
				linkage = trackId;
			};
			loop = mod.m_loader.resolveMusicLoop(trackId);
			if (!(loop >= 0))
			{
				loop = 0;
			};
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				if (GC)
				{
					GC.stageMusic = linkage;
					GC.loopLoc = loop;
				};
			}
			catch (gcErr:*)
			{
			};
			if (forcePlay)
			{
				try
				{
					SQ = EngineRefs.ssf2("audio.SoundQueue");
					if (SQ && SQ.instance)
					{
						if (SQ.instance.stopMusic)
						{
							try
							{
								SQ.instance.stopMusic();
							}
							catch (stopErr:*)
							{
							};
						};
						if (SQ.instance.playMusicStock)
						{
							SQ.instance.playMusicStock(linkage, loop);
						}
						else if (SQ.instance.playMusic)
						{
							SQ.instance.playMusic(linkage, loop);
						};
					};
				}
				catch (playErr:*)
				{
					trace("[music_player] force match music failed: " + playErr);
				};
			};
			title = mod.m_catalog ? mod.m_catalog.songTitle(trackId) : "";
			if (!title)
			{
				title = trackId;
			};
			mod.m_nowPlaying.announceSongHud(title);
		}

		internal function onStageGesture(ctx:Object):void
		{
			var chords:Array;
			var stageId:String;
			if (!ctx)
			{
				return;
			};
			chords = (ctx.chords as Array) || [];
			if (!mod.m_input.chordHas(chords, "GRAB") || mod.m_input.chordHas(chords, "TAUNT")
				|| mod.m_input.chordHas(chords, "SHIELD") || mod.m_input.chordHas(chords, "SPECIAL"))
			{
				return;
			};
			stageId = ctx.stageId as String;
			if (!stageId && ctx.hoverTarget && mod.m_host && mod.m_host.safeReadProp)
			{
				stageId = mod.m_host.safeReadProp(ctx.hoverTarget, ["StageID", "stageID", "m_stageID", "id"]) as String;
			};
			if (!stageId || stageId == "random")
			{
				return;
			};
			ctx.cancel = true;
			ctx.consume = true;
			mod.m_buttons.saveStageSelectHand();
			mod.openDeepLink(stageId, true);
		}

		internal function onStageSelect(ctx:Object):void
		{
			var game:*;
			var claimId:String;
			var claimAt:int;
			if (!ctx || mod.m_menuFlow.isAttractActive())
			{
				return;
			};
			if (ctx["cancel"] || isCameraBgPicking())
			{
				return;
			};
			game = ctx["game"];
			claimId = readClaimId();
			claimAt = readClaimAt();
			if (claimId && claimAt > 0)
			{
				mod.m_musicOverrideId = claimId;
				mod.m_musicClaimAt = claimAt;
				if (game && game["LevelData"])
				{
					game["LevelData"]["musicOverride"] = MusicOverrideCodec.withTrack(game["LevelData"]["musicOverride"], claimId);
				};
			};
			if (isOnlineGame(game))
			{
				writeHostTrack(game, claimAt > 0 ? claimId : null);
			};
		}

		/** Online host: one track for the room, written where vanilla already sends it. */
		private function writeHostTrack(game:*, claimId:String):void
		{
			var ld:*;
			var pick:String = claimId;
			var stageId:String;
			try
			{
				ld = game["LevelData"];
				if (!ld)
				{
					return;
				};
				if (!pick && mod.m_store)
				{
					stageId = resolvePlaylistStageId(game);
					if (stageId && (mod.m_store.hasCustomStageSongs(stageId) || MusicPacks.hasTracks(stageId)))
					{
						pick = mod.m_store.pickWeightedTrack(stageId);
					};
				};
				if (pick)
				{
					pick = MusicPacks.canonicalTrackId(pick);
				};
				ld["musicOverride"] = MusicOverrideCodec.withTrack(ld["musicOverride"], pick);
				trace("[music_player] net music host pick=" + pick + " value=" + ld["musicOverride"]);
			}
			catch (err:*)
			{
				trace("[music_player] net music host pick failed: " + err);
			};
		}

		internal function onQueueResources(ctx:Object):void
		{
			var queue:*;
			var stageId:String;
			var pick:String;
			var claimId:String;
			var claimAt:int;
			var game:*;
			var existing:String;
			var isReplay:Boolean;
			if (!ctx || mod.m_menuFlow.isAttractActive())
			{
				return;
			};
			game = ctx["game"];
			isReplay = Boolean(game && game["ReplayDataObj"]);
			existing = "";
			try
			{
				if (game && game["LevelData"] && game["LevelData"]["musicOverride"])
				{
					existing = String(game["LevelData"]["musicOverride"]);
					if (existing == "null")
					{
						existing = "";
					};
				};
			}
			catch (exErr:*)
			{
			};
			claimId = readClaimId();
			claimAt = readClaimAt();
			if (claimId && claimAt > 0)
			{
				mod.m_musicOverrideId = claimId;
				mod.m_musicClaimAt = claimAt;
			}
			else if (isReplay && (!mod.m_musicOverrideId || mod.m_musicOverrideId == "null") && existing)
			{
				mod.m_musicOverrideId = MusicPacks.canonicalTrackId(existing);
			}
			else if (!mod.m_musicOverrideId && mod.m_store && !isReplay)
			{
				stageId = "";
				if (ctx["requestedId"] != null && String(ctx["requestedId"]).length > 0)
				{
					stageId = String(ctx["requestedId"]);
				}
				else if (ctx["stageId"] != null)
				{
					stageId = String(ctx["stageId"]);
				};
				if (!stageId && game && game["LevelData"])
				{
					stageId = String(game["LevelData"]["stage"] || "");
				};
				if (stageId && (mod.m_store.hasCustomStageSongs(stageId) || MusicPacks.hasTracks(stageId)))
				{
					pick = mod.m_store.pickWeightedTrack(stageId);
					if (pick)
					{
						mod.m_musicOverrideId = pick;
						try
						{
							if (game && game["LevelData"])
							{
								game["LevelData"]["musicOverride"] = pick;
							};
						}
						catch (ldErr:*)
						{
						};
					};
				};
			};
			if (!mod.m_musicOverrideId)
			{
				return;
			};
			try
			{
				if (game && game["LevelData"])
				{
					game["LevelData"]["musicOverride"] = mod.m_musicOverrideId;
				};
			}
			catch (setErr:*)
			{
			};
			queue = ctx["queue"];
			if (queue is Function)
			{
				queue(mod.m_musicOverrideId);
			}
			else if (queue is Array)
			{
				queue.push(mod.m_musicOverrideId);
			};
		}

		internal function onMatchEnd(ctx:Object):void
		{
			mod.m_input.disarmPauseTaunt();
			mod.m_input.armMenuJukeboxChord();
			mod.m_armUploadId = null;
			mod.m_pendingMatchMusicId = null;
			clearMatchMusicClaim();
			clearLevelMusicOverride(ctx);
			// Loop off used to treat match-teardown MUSIC_STOP as "song ended"
			// (skip at KO, then again on the win screen). Keep the current track.
			mod.m_transport.freezePlaylistAdvance();
		}

		private function isCameraBgPicking():Boolean
		{
			try
			{
				if (mod.m_host && mod.m_host.getSessionFlag is Function)
				{
					return (Boolean(mod.m_host.getSessionFlag("camera_background.picking", false)));
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function clearLevelMusicOverride(ctx:Object):void
		{
			var game:*;
			var GC:*;
			game = ctx ? ctx["game"] : null;
			try
			{
				if (!game)
				{
					GC = EngineRefs.ssf2("controllers.GameController");
					game = GC ? GC.currentGame : null;
				};
				if (game && game["LevelData"])
				{
					game["LevelData"]["musicOverride"] = null;
				};
				if (game && game["GameSettings"])
				{
					game["GameSettings"]["musicOverride"] = null;
				};
			}
			catch (err:*)
			{
			};
		}

		internal function isResultsMenuOnscreen():Boolean
		{
			var menus:Array;
			var i:int;
			var q:String;
			menus = MusicLiveMenus.onscreen();
			i = 0;
			while (i < menus.length)
			{
				q = "";
				try
				{
					q = getQualifiedClassName(menus[i]);
				}
				catch (nameErr:*)
				{
				};
				if (q.indexOf("MatchResultsMenu") >= 0)
				{
					return (true);
				};
				i++;
			};
			return (false);
		}
	}
}
