package
{
	import flash.filesystem.File;
	import flash.utils.setTimeout;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Per-track metadata: uploads/legacy registry, titles/artist/loop edits, duration + ID3 merge, and the pack metadata warm cache.
	 */
	public class MusicTrackMeta
	{
		private var cat:MusicCatalog;
		private var m_metaCacheBusy:Boolean;
		private var m_metaCachePaused:Boolean;
		private var m_metaCacheQueue:Array;

		public function MusicTrackMeta(owner:MusicCatalog)
		{
			cat = owner;
		}

		/** Resolve and cache Sound.length for a track when the library sound is available. */
		public function cacheTrackDuration(trackId:String):Number
		{
			var m:Object;
			var RM:*;
			var snd:*;
			var link:String;
			var ms:Number;
			m = cat.songMeta[trackId];
			if (!m)
			{
				return (0);
			};
			if (m.durationMs && Number(m.durationMs) > 0)
			{
				return Number(m.durationMs);
			};
			link = m.linkage ? String(m.linkage) : trackId;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				snd = RM.getLibrarySound(link);
				if ((!snd || !(snd.length > 0)) && link != trackId)
				{
					snd = RM.getLibrarySound(trackId);
				};
				if (snd && snd.length > 0)
				{
					ms = Number(snd.length);
					m.durationMs = ms;
					return (ms);
				};
			}
			catch (err:*)
			{
			};
			return (0);
		}

		public function rememberLocalTrack(trackId:String, title:String, filePath:String):void
		{
			if (!trackId)
			{
				return;
			};
			cat.songMeta[trackId] = {
				"title": title || trackId,
				"artist": "",
				"linkage": trackId,
				"durationMs": 0,
				"hydrated": true,
				"file": filePath || ""
			};
			cat.m_cache.saveSongCache();
		}

		public function isUploadTrack(trackId:String):Boolean
		{
			var m:Object;
			if (!trackId)
			{
				return (false);
			};
			if (trackId.indexOf("bgm_upload_") == 0)
			{
				return (true);
			};
			m = cat.songMeta[trackId];
			return Boolean(m && m.file);
		}

		public function uploadTrackIds():Array
		{
			var out:Array;
			var seen:Object;
			var dir:File;
			var list:Array;
			var i:int;
			var file:File;
			var name:String;
			var tid:String;
			out = [];
			seen = {};
			try
			{
				dir = MusicSongLibrary.uploadedDir();
				if (dir.exists)
				{
					list = dir.getDirectoryListing();
					i = 0;
					while (list && i < list.length)
					{
						file = list[i] as File;
						i++;
						if (!file || file.isDirectory)
						{
							continue;
						};
						name = String(file.name || "");
						if (MusicSongLibrary.shouldSkipName(name) || !MusicUploadTranscode.isFlashMp3(file))
						{
							continue;
						};
						tid = MusicSongLibrary.idForUploadName(name);
						if (seen[tid])
						{
							continue;
						};
						seen[tid] = true;
						out.push(tid);
						if (!cat.songMeta[tid])
						{
							cat.songMeta[tid] = {
								"title": tid,
								"artist": "",
								"linkage": tid,
								"hydrated": true,
								"file": file.nativePath
							};
						}
						else
						{
							cat.songMeta[tid].file = file.nativePath;
						};
					};
				};
			}
			catch (err:*)
			{
			};
			for (tid in cat.songMeta)
			{
				if (isUploadTrack(tid) && !seen[tid])
				{
					seen[tid] = true;
					out.push(tid);
				};
			};
			return (out);
		}

		public function legacyTrackIds():Array
		{
			return (cat.legacyIds ? cat.legacyIds.concat() : []);
		}

		public function renameLocalTrack(trackId:String, title:String):void
		{
			if (!cat.songMeta[trackId])
			{
				cat.songMeta[trackId] = {"title": title, "linkage": trackId, "hydrated": true, "renamed": true};
			};
			cat.songMeta[trackId].title = title || trackId;
			cat.songMeta[trackId].renamed = true;
			cat.songMeta[trackId].hydrated = true;
			MusicOverrides.setTrackFields(trackId, {"title": title || trackId});
		}

		public function setTrackArtist(trackId:String, artist:String):void
		{
			if (!cat.songMeta[trackId])
			{
				cat.songMeta[trackId] = {"title": trackId, "linkage": trackId, "hydrated": true};
			};
			cat.songMeta[trackId].artist = artist || "";
			MusicOverrides.setTrackFields(trackId, {"artist": artist || ""});
		}

		public function setTrackSeriesKey(trackId:String, seriesKey:String):void
		{
			if (!cat.songMeta[trackId])
			{
				cat.songMeta[trackId] = {"title": trackId, "linkage": trackId, "hydrated": true};
			};
			cat.songMeta[trackId].seriesKey = seriesKey || "";
			MusicOverrides.setTrackFields(trackId, {"seriesKey": seriesKey || ""});
		}

		public function setTrackStageArt(trackId:String, stageId:String):void
		{
			if (!cat.songMeta[trackId])
			{
				cat.songMeta[trackId] = {"title": trackId, "linkage": trackId, "hydrated": true};
			};
			cat.songMeta[trackId].stageArt = stageId || "";
			MusicOverrides.setTrackFields(trackId, {"stageArt": stageId || ""});
		}

		public function setTrackSymbolKey(trackId:String, symbolKey:String):void
		{
			if (!cat.songMeta[trackId])
			{
				cat.songMeta[trackId] = {"title": trackId, "linkage": trackId, "hydrated": true};
			};
			cat.songMeta[trackId].symbolKey = symbolKey || "";
			MusicOverrides.setTrackFields(trackId, {"symbolKey": symbolKey || ""});
		}

		public function setLoopMs(trackId:String, ms:Number):void
		{
			if (!cat.songMeta[trackId])
			{
				cat.songMeta[trackId] = {"title": trackId, "linkage": trackId, "hydrated": true};
			};
			cat.songMeta[trackId].loopMs = ms > 0 ? ms : 0;
			MusicOverrides.setTrackFields(trackId, {"loopMs": ms > 0 ? ms : 0});
		}

		public function loopMs(trackId:String):Number
		{
			var m:Object;
			m = cat.songMeta[trackId];
			if (m && Number(m.loopMs) > 0)
			{
				return Number(m.loopMs);
			};
			return (0);
		}

		/** Override loop if set, else stock resource musicLoop (ms). */
		public function effectiveLoopMs(trackId:String):Number
		{
			var ov:Number;
			var RM:*;
			var trackRes:*;
			ov = loopMs(trackId);
			if (ov > 0)
			{
				return (ov);
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				trackRes = RM.getResourceByID(trackId, true) || RM.getResourceByID(trackId, false);
				if (trackRes)
				{
					return Number(trackRes.getProp("musicLoop") || 0);
				};
			}
			catch (err:*)
			{
			};
			return (0);
		}

		/**
		 * One-time background fill of title/artist/duration for pack tracks missing
		 * duration — writes songcache.json as each batch completes.
		 * Never bulk-load stock bgm_* (that was stacking hundreds of SWFs → ~1GB).
		 */
		public function startPackMetaCache(host:*):void
		{
			var id:String;
			var m:Object;
			var queue:Array;
			if (!host || !(host.ensureResourcesLoaded is Function))
			{
				return;
			};
			if (m_metaCacheBusy)
			{
				return;
			};
			queue = [];
			for (id in cat.songMeta)
			{
				m = cat.songMeta[id];
				if (!m)
				{
					continue;
				};
				if (Number(m.durationMs) > 0)
				{
					continue;
				};
				if (m.file || (id && String(id).indexOf("bgm_upload_") == 0))
				{
					continue;
				};
				// Pack / known SWF only — not every stock bgm_ id in ResourceManager.
				if (m.pack || m.swf)
				{
					queue.push(id);
				};
			};
			if (queue.length < 1)
			{
				return;
			};
			m_metaCacheBusy = true;
			m_metaCachePaused = false;
			m_metaCacheQueue = queue;
			processPackMetaCache(host);
		}

		public function pausePackMetaCache(paused:Boolean):void
		{
			m_metaCachePaused = paused;
		}

		private function processPackMetaCache(host:*):void
		{
			var tid:String;
			var self:MusicCatalog;
			if (m_metaCachePaused)
			{
				setTimeout(function ():void
				{
					processPackMetaCache(host);
				}, 750);
				return;
			};
			if (!m_metaCacheQueue || m_metaCacheQueue.length < 1)
			{
				m_metaCacheBusy = false;
				cat.m_cache.saveSongCache();
				return;
			};
			tid = String(m_metaCacheQueue.shift());
			if (cat.songMeta[tid] && Number(cat.songMeta[tid].durationMs) > 0)
			{
				processPackMetaCache(host);
				return;
			};
			self = cat;
			try
			{
				host.ensureResourcesLoaded([tid], function ():void
				{
					var RM:*;
					var res:*;
					self.mergeId3IntoMeta(tid);
					self.cacheTrackDuration(tid);
					try
					{
						RM = EngineRefs.ssf2("util.ResourceManager");
						res = RM && RM["resourcesHash"] ? RM["resourcesHash"][tid] : null;
						if (res && RM["unloadResource"] is Function)
						{
							RM["unloadResource"](res);
						};
					}
					catch (uErr:*)
					{
					};
					if ((m_metaCacheQueue.length % 8) == 0)
					{
						self.saveSongCache();
					};
					processPackMetaCache(host);
				}, function ():void
				{
					processPackMetaCache(host);
				});
			}
			catch (err:*)
			{
				m_metaCacheBusy = false;
			};
		}

		public function forgetLocalTrack(trackId:String):void
		{
			var file:File;
			if (cat.songMeta[trackId] && cat.songMeta[trackId].file)
			{
				try
				{
					file = new File(String(cat.songMeta[trackId].file));
					if (file.exists)
					{
						file.deleteFile();
					};
				}
				catch (err:*)
				{
				};
			};
			delete cat.songMeta[trackId];
			cat.m_cache.saveSongCache();
		}

		public function trackNeedsLoad(trackId:String):Boolean
		{
			var m:Object;
			m = cat.songMeta[trackId];
			if (m && m.file)
			{
				return (false);
			};
			if (trackId && trackId.indexOf("bgm_upload_") == 0)
			{
				return (false);
			};
			// list.json / songcache already has duration — never bulk-load SWFs for meta.
			if (m && Number(m.durationMs) > 0)
			{
				return (false);
			};
			if (m && m.pack && m.title && String(m.title) != trackId)
			{
				return (false);
			};
			if (!m)
			{
				return (true);
			};
			if (!m.hydrated)
			{
				return (true);
			};
			return (false);
		}

		public function songDurationLabel(trackId:String):String
		{
			var ms:Number;
			var sec:int;
			var m:int;
			var s:int;
			var meta:Object;
			meta = cat.songMeta[trackId];
			ms = meta && meta.durationMs ? Number(meta.durationMs) : 0;
			if (ms <= 0)
			{
				return ("—:—");
			};
			sec = int(ms / 1000);
			m = int(sec / 60);
			s = sec % 60;
			return (String(m) + ":" + (s < 10 ? "0" : "") + String(s));
		}

		/** Force re-read id3 after a music resource finishes loading. */
		public function refreshTrackMeta(trackId:String):void
		{
			var prevDur:Number;
			var meta:Object;
			prevDur = cat.songMeta[trackId] && cat.songMeta[trackId].durationMs
				? Number(cat.songMeta[trackId].durationMs) : 0;
			meta = cat.songMeta[trackId];
			// Pack rows already have a list.json title — still merge SWF id3 (artist).
			if (meta && meta.pack)
			{
				mergeId3IntoMeta(trackId);
				cacheTrackDuration(trackId);
				return;
			};
			if (meta)
			{
				delete cat.songMeta[trackId];
			};
			cat.registerTrack(trackId);
			if (prevDur > 0 && cat.songMeta[trackId])
			{
				cat.songMeta[trackId].durationMs = prevDur;
			}
			else
			{
				cacheTrackDuration(trackId);
			};
		}

		/** Pull id3 songName/artist from a loaded music resource into songMeta. */
		public function mergeId3IntoMeta(trackId:String):Boolean
		{
			var RM:*;
			var res:*;
			var id3:Object;
			var meta:Object;
			var changed:Boolean;
			var rawTitle:String;
			var art:String;
			var title:String;
			if (!trackId)
			{
				return (false);
			};
			meta = cat.songMeta[trackId];
			if (!meta)
			{
				meta = {};
				cat.songMeta[trackId] = meta;
			};
			changed = false;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				res = RM.getResourceByID(trackId, true) || RM.getResourceByID(trackId, false);
				if (!res || !res.Loaded)
				{
					return (false);
				};
				id3 = res.getProp("id3");
				if (!id3)
				{
					return (false);
				};
				if (id3.artist && String(id3.artist).length > 0)
				{
					art = String(id3.artist);
					if (!meta.artist || String(meta.artist).length < 1)
					{
						meta.artist = art;
						changed = true;
					};
				};
				if (id3.songName && String(id3.songName).length > 0)
				{
					rawTitle = String(id3.songName);
					if (!meta.artist || String(meta.artist).length < 1)
					{
						art = MusicCatalog.extractCredit(rawTitle);
						if (art)
						{
							meta.artist = art;
							changed = true;
						};
					};
					// Prefer id3 title when pack only had a placeholder / id-derived name.
					title = MusicCatalog.stripCredit(rawTitle);
					if (title && (!meta.title || String(meta.title) == trackId
						|| String(meta.title).indexOf("bgm_") == 0 || !meta.titleTrusted))
					{
						if (!meta.renamed)
						{
							meta.title = title;
							changed = true;
						};
					};
				};
				if (changed)
				{
					meta.hydrated = true;
				};
			}
			catch (err:*)
			{
			};
			return (changed);
		}
	}
}
