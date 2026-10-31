package
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.media.Sound;
	import flash.media.SoundTransform;
	import flash.net.URLRequest;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Local file playback (uploads / folders) through flash.media.Sound.
	 */
	public class MusicModLocalPlayback
	{
		private var mod:MusicPlayerMod;

		public function MusicModLocalPlayback(owner:MusicPlayerMod)
		{
			mod = owner;
		}

		internal function localFileFor(trackId:String):String
		{
			var meta:Object;
			var file:File;
			var dir:File;
			var list:Array;
			var i:int;
			var name:String;
			if (!trackId)
			{
				return (null);
			};
			meta = mod.m_catalog && mod.m_catalog.songMeta ? mod.m_catalog.songMeta[trackId] : null;
			if (meta && meta.file)
			{
				file = new File(String(meta.file));
				if (file.exists)
				{
					return (file.nativePath);
				};
			};
			try
			{
				dir = MusicSongLibrary.uploadedDir();
				if (!dir.exists)
				{
					return (null);
				};
				list = dir.getDirectoryListing();
				i = 0;
				while (list && i < list.length)
				{
					file = list[i] as File;
					i++;
					if (!file)
					{
						continue;
					};
					name = file.name ? String(file.name) : "";
					if (name.indexOf(trackId + ".") == 0)
					{
						if (mod.m_catalog && mod.m_catalog.songMeta)
						{
							if (!mod.m_catalog.songMeta[trackId])
							{
								mod.m_catalog.songMeta[trackId] = {
									"title": name,
									"artist": "",
									"linkage": trackId,
									"hydrated": true,
									"file": file.nativePath
								};
							}
							else
							{
								mod.m_catalog.songMeta[trackId].file = file.nativePath;
							};
						};
						return (file.nativePath);
					};
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function stopLocalPlayback():void
		{
			if (mod.m_localChannel)
			{
				try
				{
					mod.m_localChannel.removeEventListener(Event.SOUND_COMPLETE, onLocalSoundDone);
				}
				catch (rmErr:*)
				{
				};
				try
				{
					mod.m_localChannel.stop();
				}
				catch (err:*)
				{
				};
				mod.m_localChannel = null;
			};
			if (mod.m_localSound && mod.m_localSound.hasEventListener(Event.COMPLETE))
			{
				mod.m_localSound.removeEventListener(Event.COMPLETE, onLocalSoundReady);
				mod.m_localSound.removeEventListener(Event.ID3, onLocalId3);
				mod.m_localSound.removeEventListener(IOErrorEvent.IO_ERROR, onLocalSoundError);
				if (mod.m_localSound.bytesTotal <= 0 || mod.m_localSound.bytesLoaded < mod.m_localSound.bytesTotal)
				{
					try
					{
						mod.m_localSound.close();
					}
					catch (closeErr:*)
					{
					};
				};
			};
			mod.m_localSound = null;
		}

		internal function playLocalTrack(trackId:String, path:String, startPos:Number = 0):void
		{
			try
			{
				loadLocalTrack(trackId, path, startPos);
			}
			catch (err:*)
			{
				trace("[music_player] local load failed (" + trackId + "): " + err);
			};
		}

		private function loadLocalTrack(trackId:String, path:String, startPos:Number):void
		{
			var file:File;
			var title:String;
			var SQ:*;
			var playable:File;
			if (!path)
			{
				mod.notify("Music Player: missing file for " + trackId);
				return;
			};
			file = new File(path);
			if (!file.exists)
			{
				mod.notify("Music Player: missing file for " + trackId);
				return;
			};
			if (!MusicUploadTranscode.isFlashMp3(file))
			{
				playable = new File(file.nativePath.replace(/\.[^.]+$/, "") + ".mp3");
				if (playable.nativePath == file.nativePath)
				{
					playable = new File(file.nativePath + ".flash.mp3");
				};
				mod.notify("Converting to MP3…");
				MusicUploadTranscode.ensureFlashMp3(file, playable, function (out:File):void
				{
					if (mod.m_catalog && mod.m_catalog.songMeta && mod.m_catalog.songMeta[trackId])
					{
						mod.m_catalog.songMeta[trackId].file = out.nativePath;
						mod.m_catalog.songMeta[trackId].durationMs = 0;
					};
					playLocalTrack(trackId, out.nativePath, startPos);
				}, function (msg:String):void
				{
					mod.notify(msg || "Could not convert audio");
				});
				return;
			};
			stopLocalPlayback();
			mod.m_expectAdvance = false;
			mod.m_nowPlaying.setBgmHold(true);
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
			title = mod.m_catalog ? mod.m_catalog.songTitle(trackId) : "";
			if (!title || title == trackId)
			{
				title = path.split("\\").pop().split("/").pop();
			};
			mod.m_currentMusicId = trackId;
			mod.m_currentTitle = title;
			mod.m_paused = false;
			mod.m_pausePos = startPos;
			mod.m_duration = 0;
			mod.m_nowPlaying.publishNowPlaying();
			mod.m_localSound = new Sound();
			mod.m_localSound.addEventListener(Event.COMPLETE, onLocalSoundReady);
			mod.m_localSound.addEventListener(Event.ID3, onLocalId3);
			mod.m_localSound.addEventListener(IOErrorEvent.IO_ERROR, onLocalSoundError);
			try
			{
				mod.m_localSound.load(new URLRequest(file.url));
			}
			catch (err:*)
			{
				trace("[music_player] local play failed: " + err);
				mod.notify("Music Player: could not play " + title);
			};
		}

		private function onLocalSoundReady(e:Event):void
		{
			var loops:int;
			if (!mod.m_localSound || e.target != mod.m_localSound)
			{
				return;
			};
			mod.m_duration = mod.m_localSound.length;
			if (mod.m_catalog && mod.m_currentMusicId && mod.m_catalog.songMeta[mod.m_currentMusicId] && mod.m_duration > 0)
			{
				mod.m_catalog.songMeta[mod.m_currentMusicId].durationMs = mod.m_duration;
			};
			loops = mod.m_matchLoopMs >= 0 ? 0 : (mod.m_repeatOne ? 9999 : 0);
			try
			{
				playLocalSound(mod.m_localSound, mod.m_pausePos, loops);
				mod.m_expectAdvance = !mod.m_repeatOne && mod.m_matchLoopMs < 0;
			}
			catch (err:*)
			{
				trace("[music_player] local channel failed: " + err);
			};
			mod.m_expectAdvance = mod.m_matchLoopMs < 0 && !mod.m_repeatOne;
			mod.m_nowPlaying.publishNowPlaying();
			mod.registerMenu();
			if (mod.m_announceHud)
			{
				mod.m_announceHud = false;
				mod.m_nowPlaying.announceSongHud(mod.m_currentTitle || mod.m_currentMusicId);
			};
		}

		private function onLocalId3(e:Event):void
		{
			var info:*;
			var meta:Object;
			if (!mod.m_localSound || !mod.m_currentMusicId || !mod.m_catalog)
			{
				return;
			};
			try
			{
				info = mod.m_localSound.id3;
			}
			catch (err:*)
			{
				return;
			};
			if (!info)
			{
				return;
			};
			meta = mod.m_catalog.songMeta[mod.m_currentMusicId];
			if (!meta)
			{
				return;
			};
			if (!meta.renamed && info.songName && String(info.songName).length > 0)
			{
				meta.title = String(info.songName);
				mod.m_currentTitle = meta.title;
			};
			if (info.artist && String(info.artist).length > 0)
			{
				meta.artist = String(info.artist);
			};
			mod.m_nowPlaying.publishNowPlaying();
		}

		private function onLocalSoundError(e:IOErrorEvent):void
		{
			trace("[music_player] local io error: " + (e ? e.text : ""));
			mod.notify("Music Player: could not read uploaded song");
		}

		private function onLocalSoundDone(e:Event):void
		{
			if (mod.m_paused)
			{
				return;
			};
			// Channel was swapped/stopped for an intentional skip — ignore late complete.
			if (!mod.m_localSound || (e && e.target && e.target != mod.m_localChannel))
			{
				return;
			};
			if (mod.m_matchLoopMs >= 0 && mod.m_localSound)
			{
				try
				{
					if (mod.m_localChannel)
					{
						mod.m_localChannel.removeEventListener(Event.SOUND_COMPLETE, onLocalSoundDone);
					};
					playLocalSound(mod.m_localSound, mod.m_matchLoopMs, 0);
				}
				catch (err:*)
				{
				};
				return;
			};
			if (mod.m_holdAdvance && (mod.m_match.isInMatch() || mod.m_match.isResultsMenuOnscreen()))
			{
				return;
			};
			if (mod.m_repeatOne || menuSongRestarts())
			{
				if (mod.m_localSound)
				{
					try
					{
						if (mod.m_localChannel)
						{
							mod.m_localChannel.removeEventListener(Event.SOUND_COMPLETE, onLocalSoundDone);
						};
						playLocalSound(mod.m_localSound, 0, 0);
					}
					catch (repErr:*)
					{
					};
				};
				return;
			};
			if (!mod.m_transport.ensurePlaybackQueue())
			{
				mod.m_nowPlaying.setBgmHold(false);
				return;
			};
			mod.m_announceHud = true;
			mod.m_transport.playNext();
		}

		/** Menu BGM restarts the song that just ended. A jukebox pick still advances. */
		private function menuSongRestarts():Boolean
		{
			var id:String;
			if (!mod.m_menuPlayback)
			{
				return (false);
			};
			id = mod.m_currentMusicId ? String(mod.m_currentMusicId) : "";
			return (id.length > 0 && (id == mod.m_pinnedMenuId || MenuReplay.isStockMenu(id)));
		}

		/** Start a local BGM Sound at startMs on the bgm transform; SOUND_COMPLETE drives playlist advance / loop. */
		internal function playLocalSound(snd:*, startMs:Number, loops:int):void
		{
			mod.m_localChannel = snd.play(startMs, loops, bgmTransform());
			if (mod.m_localChannel)
			{
				mod.m_localChannel.addEventListener(Event.SOUND_COMPLETE, onLocalSoundDone);
			};
		}

		/** Match SoundQueue BGM level — bare Sound.play defaults to 1.0 and jumps louder. */
		private function bgmTransform():SoundTransform
		{
			var vol:Number;
			var SD:*;
			vol = 1;
			try
			{
				SD = EngineRefs.ssf2("util.SaveData");
				if (SD && SD["BGVolumeLevel"] != null)
				{
					vol = Number(SD["BGVolumeLevel"]);
				};
			}
			catch (err:*)
			{
			};
			if (!(vol >= 0))
			{
				vol = 1;
			};
			if (vol > 1)
			{
				vol = 1;
			};
			return (new SoundTransform(vol));
		}
	}
}
