package
{
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.system.System;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Playback queue and transport: play/prev/next, pause/seek, repeat/shuffle, SoundQueue sync.
	 */
	public class MusicModTransport
	{
		private var mod:MusicPlayerMod;
		private var m_queue:Array;
		private var m_queueIndex:int;
		private var m_shuffle:Boolean;
		private var m_shuffleOrder:Array;
		private var m_shufflePos:int;
		/** Bumps on every playTrack so stale ensureResourcesLoaded callbacks no-op + unload. */
		private var m_playGen:int;
		/** Track id currently loading via ensureResourcesLoaded (null when idle). */
		private var m_pendingLoadId:String;
		/** Manager asked to start this many ms into the track once playTrack finishes. */
		private var m_pendingSeekMs:Number;

		public function MusicModTransport(owner:MusicPlayerMod)
		{
			mod = owner;
			m_queue = [];
			m_queueIndex = 0;
			m_shuffle = false;
			m_shuffleOrder = null;
			m_shufflePos = 0;
			m_playGen = 0;
			m_pendingLoadId = null;
			m_pendingSeekMs = 0;
		}

		internal function managerPlay(trackId:String, positionMs:Number, announce:Boolean = false):Boolean
		{
			var linked:String;
			trackId = MusicPacks.canonicalTrackId(trackId);
			if (mod.m_catalog)
			{
				linked = mod.m_catalog.trackForLinkage(trackId);
				if (linked)
				{
					trackId = linked;
				};
			};
			trace("[music_player] managerPlay id=" + trackId + " pos=" + int(positionMs));
			if (!trackId)
			{
				return false;
			};
			if (mod.m_currentMusicId == trackId && !m_pendingLoadId)
			{
				if (positionMs > 0 && mod.m_duration > 0)
				{
					seekRatio(positionMs / mod.m_duration);
				}
				else if (mod.m_paused)
				{
					togglePause();
				};
				return true;
			};
			m_pendingSeekMs = positionMs > 0 ? positionMs : 0;
			mod.m_paused = false;
			if (announce && !(mod.m_ui && mod.m_ui.isOpen()))
			{
				mod.m_announceHud = true;
			};
			playTrack(trackId);
			return true;
		}

		internal function managerPause():Boolean
		{
			trace("[music_player] managerPause");
			if (!mod.m_paused)
			{
				togglePause();
			};
			return true;
		}

		internal function managerResume(positionMs:Number):Boolean
		{
			trace("[music_player] managerResume pos=" + int(positionMs));
			if (positionMs > 0 && mod.m_duration > 0)
			{
				seekRatio(positionMs / mod.m_duration);
				return true;
			};
			if (mod.m_paused)
			{
				togglePause();
			};
			return true;
		}

		internal function managerSeek(positionMs:Number):Boolean
		{
			if (!(positionMs >= 0))
			{
				return false;
			};
			if (mod.m_paused || !(mod.m_duration > 0))
			{
				mod.m_pausePos = positionMs;
				trace("[music_player] managerSeek pos=" + int(positionMs) + " paused=1");
				return true;
			};
			trace("[music_player] managerSeek pos=" + int(positionMs) + " paused=0");
			seekRatio(positionMs / mod.m_duration);
			return true;
		}

		internal function managerState():Object
		{
			return getPlaybackState();
		}

		private function applyPendingSeek():void
		{
			var ms:Number;
			ms = m_pendingSeekMs;
			if (!(ms > 0))
			{
				return;
			};
			m_pendingSeekMs = 0;
			if (mod.m_duration > 0)
			{
				seekRatio(ms / mod.m_duration);
			}
			else
			{
				mod.m_pausePos = ms;
			};
		}

		internal function playTrack(trackId:String):void
		{
			var linkage:String;
			var loop:Number;
			var title:String;
			var localPath:String;
			var announce:Boolean;
			var prevId:String;
			var superseded:String;
			var gen:int;
			mod.m_menuPlayback = false;
			announce = mod.m_announceHud;
			mod.m_announceHud = false;
			trackId = MusicPacks.canonicalTrackId(trackId);
			if (mod.m_menuFlow.isAttractActive())
			{
				MusicMem.snap("playTrack:blocked-attract", "id=" + trackId);
				return;
			};
			prevId = mod.m_currentMusicId;
			superseded = m_pendingLoadId;
			MusicMem.snap("playTrack:before", "id=" + trackId + " prev=" + (prevId || "-")
				+ " pending=" + (superseded || "-"));
			localPath = mod.m_local.localFileFor(trackId);
			if (localPath || (trackId && trackId.indexOf("bgm_upload_") == 0))
			{
				m_playGen++;
				m_pendingLoadId = null;
				mod.m_matchLoopMs = -1;
				mod.m_expectAdvance = false;
				mod.m_nowPlaying.setBgmHold(true);
				if (announce)
				{
					mod.m_announceHud = true;
				};
				var startAt:Number = m_pendingSeekMs > 0 ? m_pendingSeekMs : 0;
				m_pendingSeekMs = 0;
				mod.m_local.playLocalTrack(trackId, localPath, startAt);
				mod.m_loader.releaseStaleMusic(prevId, trackId);
				MusicMem.snap("playTrack:local", "id=" + trackId);
				return;
			};
			if (!mod.m_host || !mod.m_host.ensureResourcesLoaded)
			{
				return;
			};
			// Rapid next/prev used to re-fire the same ensureResourcesLoaded while
			// m_currentMusicId was still the previous song — stack orphan SWFs.
			if (superseded == trackId && trackId != prevId)
			{
				MusicMem.snap("playTrack:dedupe", "id=" + trackId);
				return;
			};
			m_playGen++;
			gen = m_playGen;
			m_pendingLoadId = trackId;
			haltPlaybackForSkip();
			// Free previous track before loading next so private RAM cannot stack.
			if (prevId && prevId != trackId)
			{
				mod.m_currentMusicId = null;
				mod.m_loader.unloadMusicResource(prevId, true);
				mod.m_loader.forgetLoadedMusic(prevId);
			};
			if (superseded && superseded != trackId && superseded != prevId)
			{
				mod.m_loader.unloadMusicResource(superseded, true);
				mod.m_loader.forgetLoadedMusic(superseded);
			};
			mod.m_host.ensureResourcesLoaded([trackId], function():void
			{
				if (gen != m_playGen)
				{
					mod.m_loader.unloadMusicResource(trackId, true);
					mod.m_loader.forgetLoadedMusic(trackId);
					try
					{
						System.gc();
					}
					catch (staleGc:*)
					{
					};
					MusicMem.snap("playTrack:stale", "id=" + trackId
						+ " gen=" + gen + "/" + m_playGen);
					return;
				};
				m_pendingLoadId = null;
				linkage = mod.m_loader.resolveMusicLinkage(trackId);
				loop = mod.m_loader.resolveMusicLoop(trackId);
				if (!linkage)
				{
					mod.notify("Music Player: no linkage on " + trackId);
					return;
				};
				if (mod.m_catalog)
				{
					mod.m_catalog.refreshTrackMeta(trackId);
				};
				title = mod.m_catalog ? mod.m_catalog.songTitle(trackId) : "";
				if (!title)
				{
					title = trackId;
				};
				mod.m_currentMusicId = trackId;
				mod.m_currentTitle = title;
				mod.m_paused = false;
				mod.m_pausePos = 0;
				mod.m_duration = mod.m_loader.resolveDurationMs(linkage);
				if (mod.m_catalog && mod.m_duration > 0 && mod.m_catalog.songMeta[trackId])
				{
					mod.m_catalog.songMeta[trackId].durationMs = mod.m_duration;
				};
				try
				{
					if (mod.m_host && mod.m_host.setSessionFlag is Function)
					{
						mod.m_host.setSessionFlag("music_player.now_playing", title);
						mod.m_host.setSessionFlag("music_player.now_id", trackId);
					};
				}
				catch (flagErr:*)
				{
				};
				mod.m_nowPlaying.setBgmHold(true);
				mod.m_matchLoopMs = mod.m_repeatOne ? loop : -1;
				playNow(linkage, mod.m_matchLoopMs);
				applyPendingSeek();
				mod.m_loader.rememberLoadedMusic(trackId);
				mod.m_loader.releaseStaleMusic(prevId, trackId);
				mod.registerMenu();
				MusicMem.snap("playTrack:loaded", "id=" + trackId + " kept=" + mod.m_loadedMusicIds.length);
				if (announce)
				{
					mod.m_nowPlaying.announceSongHud(title);
				};
			}, function():void
			{
				if (gen != m_playGen)
				{
					return;
				};
				m_pendingLoadId = null;
				mod.notify("Music Player: failed to load " + trackId);
			});
		}

		internal function setQueue(ids:Array, index:int):void
		{
			m_queue = ids ? ids.concat() : [];
			m_shuffleOrder = null;
			m_queueIndex = index;
			if (m_queueIndex < 0)
			{
				m_queueIndex = 0;
			};
		}

		/** When no jukebox queue is set (e.g. stream menu music), use Menu Music playlist. */
		internal function ensurePlaybackQueue():Boolean
		{
			var songs:Array;
			var i:int;
			var tid:String;
			var cur:String;
			if (m_queue && m_queue.length > 0)
			{
				return (true);
			};
			if (!mod.m_store)
			{
				return (false);
			};
			try
			{
				if (mod.m_store.syncMenuMusicFromDisk is Function)
				{
					mod.m_store.syncMenuMusicFromDisk();
				};
			}
			catch (syncErr:*)
			{
			};
			songs = mod.m_store.songsForPlaylist(MusicPlaylistStore.MENU_PLAYLIST_ID);
			if (!songs || songs.length < 1)
			{
				return (false);
			};
			m_queue = [];
			m_shuffleOrder = null;
			i = 0;
			while (i < songs.length)
			{
				tid = MusicPacks.canonicalTrackId(String(songs[i]));
				i++;
				if (tid && tid.length > 0)
				{
					m_queue.push(tid);
				};
			};
			if (m_queue.length < 1)
			{
				return (false);
			};
			m_queueIndex = 0;
			cur = mod.m_currentMusicId ? MusicPacks.canonicalTrackId(mod.m_currentMusicId) : "";
			if (cur)
			{
				i = m_queue.indexOf(cur);
				if (i < 0 && mod.m_catalog)
				{
					i = indexInQueueByLinkage(cur);
				};
				if (i >= 0)
				{
					m_queueIndex = i;
				};
			};
			return (true);
		}

		private function indexInQueueByLinkage(trackOrLink:String):int
		{
			var i:int;
			var tid:String;
			var link:String;
			var want:String;
			if (!m_queue || !mod.m_catalog || !trackOrLink)
			{
				return (-1);
			};
			want = mod.m_loader.resolveMusicLinkage(trackOrLink) || trackOrLink;
			i = 0;
			while (i < m_queue.length)
			{
				tid = String(m_queue[i]);
				link = mod.m_loader.resolveMusicLinkage(tid) || tid;
				if (tid == trackOrLink || link == want || link == trackOrLink
					|| tid == want)
				{
					return (i);
				};
				i++;
			};
			return (-1);
		}

		internal function getRepeatOne():Boolean
		{
			return (mod.m_repeatOne);
		}

		internal function getShuffle():Boolean
		{
			return (m_shuffle);
		}

		internal function toggleShuffle():void
		{
			m_shuffle = !m_shuffle;
			if (m_shuffle)
			{
				mod.m_repeatOne = false;
				buildShuffleOrder();
			}
			else
			{
				m_shuffleOrder = null;
			};
		}

		/** Loop on, then loop off, then shuffle the current list, then loop on. */
		internal function cyclePlayMode():void
		{
			if (mod.m_repeatOne)
			{
				toggleRepeat();
				m_shuffle = false;
				m_shuffleOrder = null;
				return;
			};
			if (!m_shuffle)
			{
				m_shuffle = true;
				buildShuffleOrder();
				return;
			};
			m_shuffle = false;
			m_shuffleOrder = null;
			toggleRepeat();
		}

		/** One pass through the current queue, current song first, the rest shuffled. */
		private function buildShuffleOrder():void
		{
			var rest:Array;
			var i:int;
			var n:int;
			var j:int;
			var tmp:int;
			m_shuffleOrder = [];
			m_shufflePos = 0;
			if (!m_queue || m_queue.length < 1)
			{
				return;
			};
			rest = [];
			i = 0;
			while (i < m_queue.length)
			{
				if (i != m_queueIndex)
				{
					rest.push(i);
				};
				i++;
			};
			n = rest.length;
			i = n - 1;
			while (i > 0)
			{
				j = int(Math.random() * (i + 1));
				tmp = int(rest[i]);
				rest[i] = rest[j];
				rest[j] = tmp;
				i--;
			};
			m_shuffleOrder.push(m_queueIndex);
			i = 0;
			while (i < rest.length)
			{
				m_shuffleOrder.push(int(rest[i]));
				i++;
			};
		}

		internal function toggleRepeat():void
		{
			mod.m_repeatOne = !mod.m_repeatOne;
			if (mod.m_repeatOne)
			{
				// Resume loop-point behavior on next natural restart / seek.
				if (mod.m_currentMusicId)
				{
					mod.m_matchLoopMs = mod.m_loader.resolveMusicLoop(mod.m_currentMusicId);
					if (!(mod.m_matchLoopMs >= 0))
					{
						mod.m_matchLoopMs = 0;
					};
				};
				mod.m_expectAdvance = false;
				return;
			};
			// Loop off: rebind at current position so SoundQueue mid-loop ends can advance.
			// Clear expectAdvance first — seekRatio/stopMusic must not auto-skip.
			mod.m_matchLoopMs = -1;
			mod.m_expectAdvance = false;
			if (mod.m_paused || !mod.m_currentMusicId)
			{
				return;
			};
			syncFromSoundQueue();
			if (mod.m_localChannel)
			{
				try
				{
					mod.m_pausePos = mod.m_localChannel.position;
				}
				catch (posErr:*)
				{
				};
			};
			if (mod.m_duration > 0)
			{
				seekRatio(Math.min(1, Math.max(0, mod.m_pausePos / mod.m_duration)));
			};
		}

		internal function onMusicStop(ctx:Object):void
		{
			var stopped:String;
			stopped = ctx && ctx.songId ? String(ctx.songId) : "";
			if (mod.m_menuPlayback && stopped && (stopped == mod.m_pinnedMenuId || MenuReplay.isStockMenu(stopped)))
			{
				return;
			};
			if (mod.m_holdAdvance || mod.m_localChannel || !mod.m_expectAdvance || mod.m_repeatOne || mod.m_paused)
			{
				return;
			};
			mod.m_expectAdvance = false;
			mod.m_announceHud = true;
			playNext();
		}

		/** Scrub to ratio 0..1 for local Sound or stock SoundQueue library sound. */
		internal function seekRatio(ratio:Number):void
		{
			var pos:Number;
			var SQ:*;
			var RM:*;
			var linkage:String;
			var snd:*;
			var loopMs:Number;
			if (!mod.m_currentMusicId)
			{
				return;
			};
			if (!(mod.m_duration > 0))
			{
				syncFromSoundQueue();
			};
			if (!(mod.m_duration > 0))
			{
				return;
			};
			if (ratio < 0)
			{
				ratio = 0;
			};
			if (ratio > 1)
			{
				ratio = 1;
			};
			pos = ratio * mod.m_duration;
			mod.m_pausePos = pos;
			mod.m_paused = false;
			mod.m_nowPlaying.setBgmHold(true);
			// Already have a local Sound loaded for this track — seek in-place (no reload).
			if (mod.m_localSound && mod.m_currentMusicId)
			{
				try
				{
					if (mod.m_localChannel)
					{
						mod.m_localChannel.stop();
					};
				}
				catch (stopCh:*)
				{
				};
				mod.m_localChannel = null;
				try
				{
					loopMs = mod.m_loader.resolveMusicLoop(mod.m_currentMusicId);
					if (!(loopMs >= 0))
					{
						loopMs = 0;
					};
					// Repeat-one (and game loop point) must survive scrub; playlist mode advances on end.
					mod.m_matchLoopMs = mod.m_repeatOne ? loopMs : -1;
					mod.m_local.playLocalSound(mod.m_localSound, pos, 0);
					mod.m_expectAdvance = !mod.m_repeatOne;
				}
				catch (reuseErr:*)
				{
					trace("[music_player] seek reuse failed: " + reuseErr);
				};
				return;
			};
			if (mod.m_local.localFileFor(mod.m_currentMusicId)
				|| (mod.m_currentMusicId && mod.m_currentMusicId.indexOf("bgm_upload_") == 0))
			{
				mod.m_local.playLocalTrack(mod.m_currentMusicId, mod.m_local.localFileFor(mod.m_currentMusicId), pos);
				return;
			};
			linkage = mod.m_loader.resolveMusicLinkage(mod.m_currentMusicId);
			if (!linkage)
			{
				linkage = mod.m_currentMusicId;
			};
			mod.m_local.stopLocalPlayback();
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
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				snd = RM.getLibrarySound(linkage);
				if ((!snd || !(snd.length > 0)) && linkage != mod.m_currentMusicId)
				{
					snd = RM.getLibrarySound(mod.m_currentMusicId);
				};
				if (!snd)
				{
					return;
				};
				mod.m_localSound = snd as Sound;
				loopMs = mod.m_loader.resolveMusicLoop(mod.m_currentMusicId);
				if (!(loopMs >= 0))
				{
					loopMs = 0;
				};
				mod.m_matchLoopMs = mod.m_repeatOne ? loopMs : -1;
				mod.m_local.playLocalSound(snd, pos, 0);
				if (snd.length > 0)
				{
					mod.m_duration = Number(snd.length);
				};
				mod.m_expectAdvance = !mod.m_repeatOne;
			}
			catch (seekErr:*)
			{
				trace("[music_player] seek failed: " + seekErr);
			};
		}

		internal function playPrev():void
		{
			releasePlaylistHold();
			syncFromSoundQueue();
			if (!ensurePlaybackQueue())
			{
				return;
			};
			// While a skip is still loading, advance from the pending target —
			// syncing to m_currentMusicId would re-request the same next song.
			if (!m_pendingLoadId)
			{
				syncQueueIndexToCurrent();
			};
			stepQueue(-1);
			haltPlaybackForSkip();
			playTrack(String(m_queue[m_queueIndex]));
		}

		internal function playNext():void
		{
			releasePlaylistHold();
			syncFromSoundQueue();
			if (!ensurePlaybackQueue())
			{
				return;
			};
			if (!m_pendingLoadId)
			{
				syncQueueIndexToCurrent();
			};
			stepQueue(1);
			haltPlaybackForSkip();
			playTrack(String(m_queue[m_queueIndex]));
		}

		/** Stop immediately so a loop restart can't beat an in-flight Next/Prev. */
		private function haltPlaybackForSkip():void
		{
			var SQ:*;
			mod.m_expectAdvance = false;
			mod.m_local.stopLocalPlayback();
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

		/** Keep skip targets relative to what's actually playing (stale index restarts current). */
		private function syncQueueIndexToCurrent():void
		{
			var cur:String;
			var i:int;
			if (!m_queue || m_queue.length < 1)
			{
				return;
			};
			cur = m_pendingLoadId || mod.m_currentMusicId;
			cur = cur ? MusicPacks.canonicalTrackId(cur) : "";
			if (!cur)
			{
				return;
			};
			i = m_queue.indexOf(cur);
			if (i < 0)
			{
				i = indexInQueueByLinkage(cur);
			};
			if (i >= 0)
			{
				m_queueIndex = i;
			};
		}

		internal function togglePause():void
		{
			var SQ:*;
			var ch:*;
			var resumeAt:Number;
			if (mod.m_localChannel || (mod.m_paused && mod.m_currentMusicId && mod.m_local.localFileFor(mod.m_currentMusicId)))
			{
				if (!mod.m_paused && mod.m_localChannel)
				{
					mod.m_pausePos = mod.m_localChannel.position;
					try
					{
						mod.m_localChannel.stop();
					}
					catch (stopLocal:*)
					{
					};
					mod.m_localChannel = null;
					mod.m_paused = true;
					mod.m_expectAdvance = false;
					mod.m_nowPlaying.setBgmHold(false);
					return;
				};
				if (mod.m_paused && mod.m_currentMusicId)
				{
					resumeAt = mod.m_pausePos;
					mod.m_nowPlaying.setBgmHold(true);
					mod.m_local.playLocalTrack(mod.m_currentMusicId, mod.m_local.localFileFor(mod.m_currentMusicId), resumeAt);
					return;
				};
			};
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
			}
			catch (err:*)
			{
				return;
			};
			if (!SQ || !SQ.instance)
			{
				return;
			};
			if (!mod.m_paused)
			{
				ch = SQ.instance.CurrentSong;
				if (ch)
				{
					mod.m_pausePos = Number(ch.position);
				};
				mod.m_expectAdvance = false;
				try
				{
					SQ.instance.stopMusic();
				}
				catch (stopErr:*)
				{
				};
				mod.m_paused = true;
				mod.m_nowPlaying.setBgmHold(false);
			}
			else if (mod.m_currentMusicId)
			{
				mod.m_nowPlaying.setBgmHold(true);
				mod.m_paused = false;
				if (mod.m_duration > 0)
				{
					seekRatio(Math.min(1, Math.max(0, mod.m_pausePos / mod.m_duration)));
				}
				else
				{
					// Duration unknown after stopMusic — resume via library Sound at pause pos.
					resumeStockAtPausePos();
				};
			};
		}

		/** Resume stock BGM from m_pausePos without reloading / restarting at 0. */
		private function resumeStockAtPausePos():void
		{
			var SQ:*;
			var RM:*;
			var linkage:String;
			var snd:*;
			var loopMs:Number;
			var pos:Number;
			pos = mod.m_pausePos > 0 ? mod.m_pausePos : 0;
			linkage = mod.m_loader.resolveMusicLinkage(mod.m_currentMusicId);
			if (!linkage)
			{
				linkage = mod.m_currentMusicId;
			};
			mod.m_local.stopLocalPlayback();
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
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				snd = RM.getLibrarySound(linkage);
				if ((!snd || !(snd.length > 0)) && linkage != mod.m_currentMusicId)
				{
					snd = RM.getLibrarySound(mod.m_currentMusicId);
				};
				if (!snd)
				{
					playTrack(mod.m_currentMusicId);
					return;
				};
				mod.m_localSound = snd as Sound;
				if (snd.length > 0)
				{
					mod.m_duration = Number(snd.length);
				};
				loopMs = mod.m_loader.resolveMusicLoop(mod.m_currentMusicId);
				if (!(loopMs >= 0))
				{
					loopMs = 0;
				};
				mod.m_matchLoopMs = mod.m_repeatOne ? loopMs : -1;
				mod.m_local.playLocalSound(snd, pos, 0);
				mod.m_expectAdvance = !mod.m_repeatOne;
			}
			catch (resumeErr:*)
			{
				playTrack(mod.m_currentMusicId);
			};
		}

		/** Mirror whatever SoundQueue is actually playing (menu or match). */
		internal function syncFromSoundQueue():void
		{
			var SQ:*;
			var ch:*;
			var songId:String;
			var tid:String;
			var title:String;
			var dur:Number;
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
				if (!SQ || !SQ.instance)
				{
					return;
				};
				songId = SQ.instance.CurrentSongID ? String(SQ.instance.CurrentSongID) : "";
				ch = SQ.instance.CurrentSong;
				if (m_pendingLoadId)
				{
					return;
				};
				if (ch)
				{
					mod.m_pausePos = Number(ch.position);
					mod.m_paused = false;
				}
				else if (songId.length < 1)
				{
					return;
				};
				if (songId.length < 1)
				{
					return;
				};
				tid = mod.m_catalog ? mod.m_catalog.trackForLinkage(songId) : null;
				if (!tid)
				{
					tid = songId;
				};
				if (tid != mod.m_currentMusicId)
				{
					if (mod.m_localChannel)
					{
						mod.m_local.stopLocalPlayback();
					};
					mod.m_nowPlaying.setBgmHold(false);
					trace("[music_player] sync adopt id=" + tid);
					mod.m_currentMusicId = tid;
					if (mod.m_catalog)
					{
						mod.m_catalog.refreshTrackMeta(tid);
						title = mod.m_catalog.songTitle(tid);
					};
					mod.m_currentTitle = title && title.length > 0 ? title : tid;
					try
					{
						if (mod.m_host && mod.m_host.setSessionFlag is Function)
						{
							mod.m_host.setSessionFlag("music_player.now_playing", mod.m_currentTitle);
							mod.m_host.setSessionFlag("music_player.now_id", tid);
						};
					}
					catch (flagErr:*)
					{
					};
				};
				dur = mod.m_loader.resolveDurationMs(songId);
				if (dur <= 0 && tid)
				{
					dur = mod.m_loader.resolveDurationMs(mod.m_loader.resolveMusicLinkage(tid) || tid);
				};
				if (dur > 0)
				{
					mod.m_duration = dur;
				};
			}
			catch (err:*)
			{
			};
		}

		internal function getPlaybackState():Object
		{
			var playing:Boolean;
			syncFromSoundQueue();
			playing = false;
			if (mod.m_localChannel)
			{
				mod.m_pausePos = mod.m_localChannel.position;
				mod.m_paused = false;
				playing = true;
			}
			else if (!mod.m_paused && mod.m_currentMusicId)
			{
				playing = true;
			};
			return ({
				"paused": !playing,
				"posMs": mod.m_pausePos,
				"durMs": mod.m_duration,
				"trackId": mod.m_currentMusicId,
				"title": mod.m_currentTitle
			});
		}

		/** Hard stop for boot teardown / process exit — local + SoundQueue. */
		internal function stopAllPlayback():void
		{
			var SQ:*;
			mod.m_expectAdvance = false;
			mod.m_announceHud = false;
			mod.m_paused = true;
			mod.m_local.stopLocalPlayback();
			mod.m_nowPlaying.setBgmHold(false);
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
				if (SQ)
				{
					if (SQ["stopMusic"] is Function)
					{
						SQ["stopMusic"]();
					}
					else if (SQ["INSTANCE"] && SQ["INSTANCE"].stopMusic is Function)
					{
						SQ["INSTANCE"].stopMusic();
					};
				};
			}
			catch (err:*)
			{
			};
			try
			{
				if (mod.m_host && mod.m_host.setSessionFlag is Function)
				{
					mod.m_host.setSessionFlag("music_player.now_playing", "");
					mod.m_host.setSessionFlag("music_player.now_id", "");
				};
			}
			catch (flagErr:*)
			{
			};
		}

		private function playNow(id:String, loop:Number):void
		{
			var SQ:*;
			var RM:*;
			var snd:*;
			mod.m_local.stopLocalPlayback();
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
				if (SQ && SQ.instance)
				{
					mod.m_expectAdvance = false;
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
					// Playlist mode (loop < 0): play via local SoundChannel so SOUND_COMPLETE
					// advances — SoundQueue's loopMusic does not fire MUSIC_STOP on natural end.
					if (loop < 0 || !mod.m_repeatOne)
					{
						try
						{
							RM = EngineRefs.ssf2("util.ResourceManager");
							snd = RM.getLibrarySound(id);
							if (snd)
							{
								mod.m_localSound = snd as Sound;
								mod.m_matchLoopMs = -1;
								mod.m_local.playLocalSound(snd, 0, 0);
								if (snd.length > 0)
								{
									mod.m_duration = Number(snd.length);
								};
								mod.m_expectAdvance = true;
								return;
							};
						}
						catch (localErr:*)
						{
							trace("[music_player] local stock play failed: " + localErr);
						};
					};
					if (SQ.instance.playMusicStock)
					{
						SQ.instance.playMusicStock(id, loop);
					};
					mod.m_matchLoopMs = loop;
					mod.m_expectAdvance = !mod.m_repeatOne && loop < 0;
				};
			}
			catch (err:*)
			{
				trace("[music_player] play failed: " + err);
			};
		}

		internal function freezePlaylistAdvance():void
		{
			mod.m_holdAdvance = true;
			mod.m_expectAdvance = false;
			// Do not hold BGM — victory theme and menu music must still play.
			// Local overlay would keep covering those, and MUSIC_STOP skip is already blocked.
			mod.m_local.stopLocalPlayback();
			mod.m_nowPlaying.setBgmHold(false);
		}

		internal function releasePlaylistHold():void
		{
			mod.m_holdAdvance = false;
		}

		/** Shuffle walks the current list once in a shuffled order, then reshuffles. */
		private function stepQueue(delta:int):void
		{
			var n:int;
			if (!m_queue || m_queue.length < 1)
			{
				return;
			};
			if (m_shuffle && m_queue.length > 1)
			{
				if (!m_shuffleOrder || m_shuffleOrder.length != m_queue.length
					|| m_shufflePos < 0 || m_shufflePos >= m_shuffleOrder.length
					|| int(m_shuffleOrder[m_shufflePos]) != m_queueIndex)
				{
					buildShuffleOrder();
				};
				if (delta > 0)
				{
					m_shufflePos++;
					if (m_shufflePos >= m_shuffleOrder.length)
					{
						buildShuffleOrder();
						if (m_shuffleOrder.length > 1)
						{
							m_shufflePos = 1;
						};
					};
				}
				else
				{
					m_shufflePos--;
					if (m_shufflePos < 0)
					{
						m_shufflePos = m_shuffleOrder.length - 1;
					};
				};
				m_queueIndex = int(m_shuffleOrder[m_shufflePos]);
				return;
			};
			n = m_queue.length;
			m_queueIndex = (m_queueIndex + delta % n + n) % n;
		}
	}
}
