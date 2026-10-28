package
{
	import ssf2mm.shared.EngineRefs;

	/**
	 * Builds stage buckets + track metadata from ResourceManager.
	 * Stage list comes from mappings.stage_select_screen (same as Stage Select).
	 * Each stage's song list is pulled once when that stage resource is loaded
	 * (boot pool or expansion), then cached — no bulk stage SWF preload.
	 */
	public class MusicCatalog
	{
		public var stageIds:Array;
		public var otherSongIds:Array;
		public var songMeta:Object;
		public var defaultStageSongs:Object;
		public var legacyIds:Array;

		private var m_cacheStamp:String;
		/** Stages whose music list was ingested once (do not re-pull). */
		internal var m_songsLocked:Object;
		internal var m_pendingOther:Array;
		/**
		 * Stock orphan tracks that live in the Other bucket but belong to a
		 * specific stage for disc / preview art (SWF music not yet ingested).
		 */
		private static const STOCK_TRACK_STAGE:Object = {
			"bgm_ATBAPM": "saffroncity",
			"bgm_PokemonGyms": "saffroncity",
			"bgm_teamrockethideout": "saffroncity",
			"bgm_pokemoncitymedley": "saffroncity"
		};

		internal var m_tracks:MusicTrackMeta;
		internal var m_cache:MusicSongCache;

		public function MusicCatalog()
		{
			m_tracks = new MusicTrackMeta(this);
			m_cache = new MusicSongCache(this);
			stageIds = [];
			otherSongIds = [];
			songMeta = {};
			defaultStageSongs = {};
			legacyIds = [];
			m_cacheStamp = "";
			m_songsLocked = {};
			m_pendingOther = null;
		}

		/** Force next rebuildIfNeeded() to rebuild roster (keeps locked song lists). */
		public function invalidate():void
		{
			m_cacheStamp = "";
		}

		/** Rebuild only when stage-select roster / mappings change. Returns true if rebuilt. */
		public function rebuildIfNeeded():Boolean
		{
			var stamp:String;
			stamp = computeStamp();
			if (stamp == m_cacheStamp && stageIds.length > 0)
			{
				return (false);
			};
			rebuild();
			m_cacheStamp = stamp;
			return (true);
		}

		public function rebuild():void
		{
			var assigned:Object;
			var mappings:Object;
			var prevSongs:Object;
			var prevLocked:Object;
			var prevMeta:Object;
			prevSongs = defaultStageSongs || {};
			prevLocked = m_songsLocked || {};
			prevMeta = songMeta || {};
			MusicOverrides.load();
			m_cache.mergeStockList(prevSongs, prevLocked, prevMeta);
			m_cache.mergeDiskCache(prevSongs, prevLocked, prevMeta);
			stageIds = [];
			otherSongIds = [];
			songMeta = prevMeta;
			defaultStageSongs = {};
			m_songsLocked = {};
			assigned = {};
			mappings = loadMappings();
			addSelectScreenStages(mappings, prevSongs, assigned);
			foldTrainingGridIntoOther(assigned);
			addMappedStages(mappings, prevSongs);
			sortStagesByName();
			collectUnassignedMusic(assigned);
			mergePendingOther(assigned);
			otherSongIds.sort(onSongSort);
			m_cacheStamp = computeStamp();
			applyTrackOverrides();
			// Never rewrite immutable list.json; songcache is optional meta only.
			m_cache.saveSongCache();
		}

		/** Stage Select roster: song list per stage, lock non-empty lists, register their tracks. */
		private function addSelectScreenStages(mappings:Object, prevSongs:Object, assigned:Object):void
		{
			var selectIds:Array;
			var i:int;
			var j:int;
			var stageId:String;
			var ids:Array;
			var trackId:String;
			selectIds = collectStageSelectIds(mappings);
			i = 0;
			while (i < selectIds.length)
			{
				stageId = String(selectIds[i]);
				i++;
				if (!stageEligible(stageId, mappings))
				{
					continue;
				};
				ids = initialStageSongIds(stageId, prevSongs);
				defaultStageSongs[stageId] = ids.concat();
				if (ids.length > 0)
				{
					m_songsLocked[stageId] = true;
					j = 0;
					while (j < ids.length)
					{
						trackId = String(ids[j]);
						j++;
						if (trackId)
						{
							assigned[trackId] = true;
							if (!songMeta[trackId])
							{
								registerTrack(trackId);
							};
						};
					};
				};
				stageIds.push(stageId);
			};
		}

		// Prefer songcache / prior non-empty lists — never lock empty and
		// never require a stage SWF load at runtime.
		private function initialStageSongIds(stageId:String, prevSongs:Object):Array
		{
			var ids:Array;
			var musicArr:Array;
			var j:int;
			var trackId:String;
			ids = null;
			if (prevSongs[stageId] is Array && (prevSongs[stageId] as Array).length > 0)
			{
				ids = (prevSongs[stageId] as Array).concat();
			}
			else
			{
				musicArr = readStageMusic(stageId);
				if (musicArr)
				{
					ids = [];
					j = 0;
					while (j < musicArr.length)
					{
						trackId = musicEntryId(musicArr[j]);
						if (trackId)
						{
							ids.push(trackId);
						};
						j++;
					};
				};
			};
			if (!ids)
			{
				ids = [];
			};
			return (ids);
		}

		// Guarantee franchise-mapped stages (e.g. lunarcore) appear even if
		// a mappings quirk dropped them from stage_select_screen flatten.
		private function addMappedStages(mappings:Object, prevSongs:Object):void
		{
			var mapped:Array;
			var i:int;
			var stageId:String;
			mapped = MusicSeriesResolver.mappedStageIds();
			i = 0;
			while (mapped && i < mapped.length)
			{
				stageId = String(mapped[i]);
				i++;
				if (!stageId || stageIds.indexOf(stageId) >= 0)
				{
					continue;
				};
				if (!stageEligible(stageId, mappings))
				{
					continue;
				};
				if (!(defaultStageSongs[stageId] is Array) || (defaultStageSongs[stageId] as Array).length < 1)
				{
					if (prevSongs[stageId] is Array && (prevSongs[stageId] as Array).length > 0)
					{
						defaultStageSongs[stageId] = (prevSongs[stageId] as Array).concat();
					}
					else
					{
						applyDiskSongs(stageId);
					};
				};
				if (!(defaultStageSongs[stageId] is Array))
				{
					defaultStageSongs[stageId] = [];
				};
				stageIds.push(stageId);
			};
		}

		private function sortStagesByName():void
		{
			stageIds.sort(function(a:String, b:String):int
			{
				var na:String = MusicStageVisuals.stageDisplayName(a);
				var nb:String = MusicStageVisuals.stageDisplayName(b);
				if (na < nb)
				{
					return (-1);
				};
				if (na > nb)
				{
					return (1);
				};
				return (0);
			});
		}

		// Disk "other" is advisory only — never rehydrate a huge stale dump (lag).
		private function mergePendingOther(assigned:Object):void
		{
			var j:int;
			var trackId:String;
			if (m_pendingOther is Array && m_pendingOther.length > 0)
			{
				j = 0;
				while (j < m_pendingOther.length)
				{
					trackId = String(m_pendingOther[j]);
					j++;
					if (!trackId || assigned[trackId] || otherSongIds.indexOf(trackId) >= 0)
					{
						continue;
					};
					if (songMeta[trackId] && songMeta[trackId].stage)
					{
						continue;
					};
					if (songMeta[trackId])
					{
						otherSongIds.push(trackId);
						assigned[trackId] = true;
					};
				};
			};
		}

		private function applyTrackOverrides():void
		{
			var id:String;
			var ov:Object;
			var m:Object;
			MusicOverrides.load();
			for (id in songMeta)
			{
				ov = MusicOverrides.trackOverride(id);
				if (!ov)
				{
					continue;
				};
				m = songMeta[id];
				if (!m)
				{
					continue;
				};
				if (ov.title)
				{
					m.title = String(ov.title);
					m.renamed = true;
					m.hydrated = true;
				};
				if (ov.artist != null)
				{
					m.artist = String(ov.artist);
				};
				if (ov.loopMs != null)
				{
					m.loopMs = Number(ov.loopMs);
				};
				if (ov.stageArt)
				{
					m.stageArt = String(ov.stageArt);
				};
				if (ov.symbolKey)
				{
					m.symbolKey = String(ov.symbolKey);
				};
				if (ov.seriesKey)
				{
					m.seriesKey = String(ov.seriesKey);
				};
			};
		}

		/**
		 * Pull a stage's music list once when its SWF becomes available
		 * (including expansion stages). No-op if already locked or music unread.
		 */
		public function ingestStageSongsOnce(stageId:String):Boolean
		{
			var mappings:Object;
			var musicArr:Array;
			var j:int;
			var entry:*;
			var trackId:String;
			var existing:Array;
			if (!stageId || stageId == "random" || stageId == "xpstage")
			{
				return (false);
			};
			existing = defaultStageSongs[stageId] as Array;
			if (m_songsLocked[stageId] && existing && existing.length > 0)
			{
				return (false);
			};
			if (m_songsLocked[stageId] && (!existing || existing.length < 1))
			{
				m_songsLocked[stageId] = false;
			};
			if (stageId == MusicStageVisuals.TRAINING_GRID_ID)
			{
				musicArr = readStageMusic(stageId);
				if (!musicArr)
				{
					return applyDiskSongs(stageId);
				};
				j = 0;
				while (j < musicArr.length)
				{
					entry = musicArr[j];
					trackId = musicEntryId(entry);
					j++;
					if (!trackId)
					{
						continue;
					};
					registerTrack(trackId);
					if (otherSongIds.indexOf(trackId) < 0)
					{
						otherSongIds.push(trackId);
					};
				};
				otherSongIds.sort(onSongSort);
				m_songsLocked[stageId] = true;
				m_cache.saveSongCache();
				return (true);
			};
			mappings = loadMappings();
			if (!stageEligible(stageId, mappings))
			{
				if (!(mappings && mappings.stage && mappings.stage[stageId]))
				{
					return (false);
				};
			};
			ensureStageData(stageId);
			if (readStageMusic(stageId))
			{
				refreshStageSongs(stageId);
				m_songsLocked[stageId] = true;
				m_cache.saveSongCache();
				return (true);
			};
			// songcache.json (build_songcache.py) — no runtime stage SWF queue.
			return applyDiskSongs(stageId);
		}

		/** Apply non-empty stage playlist from songcache without touching stageIds. */
		private function applyDiskSongs(stageId:String):Boolean
		{
			var data:Object;
			var list:Array;
			var j:int;
			var trackId:String;
			var existing:Array;
			if (!stageId)
			{
				return (false);
			};
			existing = defaultStageSongs[stageId] as Array;
			if (m_songsLocked[stageId] && existing && existing.length > 0)
			{
				return (false);
			};
			data = m_cache.readSongCache();
			if (!data || !(data.stages is Object) || !(data.stages[stageId] is Array)
				|| (data.stages[stageId] as Array).length < 1)
			{
				data = m_cache.readStockList();
			};
			if (!data || !(data.stages is Object))
			{
				return (false);
			};
			list = data.stages[stageId] as Array;
			if (!list || list.length < 1)
			{
				return (false);
			};
			if (!(defaultStageSongs[stageId] is Array))
			{
				defaultStageSongs[stageId] = [];
			};
			defaultStageSongs[stageId] = list.concat();
			j = 0;
			while (j < list.length)
			{
				trackId = String(list[j]);
				j++;
				if (trackId && !songMeta[trackId])
				{
					registerTrack(trackId);
				};
			};
			m_songsLocked[stageId] = true;
			return (true);
		}

		/**
		 * Ensure song bag exists for a stage without adding it to the main
		 * By Stage roster (Other Stages hub / pack extras).
		 */
		public function ensureStageData(stageId:String):void
		{
			if (!stageId)
			{
				return;
			};
			if (!(defaultStageSongs[stageId] is Array))
			{
				defaultStageSongs[stageId] = [];
			};
			applyDiskSongs(stageId);
		}

		/** Training Grid is not a selectable Music Player stage; its tracks live under Other. */
		private function foldTrainingGridIntoOther(assigned:Object):void
		{
			var musicArr:Array;
			var j:int;
			var entry:*;
			var trackId:String;
			musicArr = readStageMusic(MusicStageVisuals.TRAINING_GRID_ID);
			if (!musicArr)
			{
				return;
			};
			j = 0;
			while (j < musicArr.length)
			{
				entry = musicArr[j];
				trackId = musicEntryId(entry);
				j++;
				if (!trackId || assigned[trackId])
				{
					continue;
				};
				registerTrack(trackId);
				assigned[trackId] = true;
				otherSongIds.push(trackId);
			};
			m_songsLocked[MusicStageVisuals.TRAINING_GRID_ID] = true;
		}

		/**
		 * After a stage SWF loads, refresh that stage's song list without
		 * discarding the rest of the cache. Prefer ingestStageSongsOnce.
		 */
		public function refreshStageSongs(stageId:String):Boolean
		{
			var musicArr:Array;
			var ids:Array;
			var j:int;
			var entry:*;
			var trackId:String;
			var changed:Boolean;
			if (!stageId)
			{
				return (false);
			};
			if (stageIds.indexOf(stageId) < 0)
			{
				ensureStageData(stageId);
			};
			if (stageIds.indexOf(stageId) < 0)
			{
				return (false);
			};
			musicArr = readStageMusic(stageId);
			ids = [];
			if (musicArr)
			{
				j = 0;
				while (j < musicArr.length)
				{
					entry = musicArr[j];
					trackId = musicEntryId(entry);
					if (trackId)
					{
						ids.push(trackId);
						registerTrack(trackId);
					};
					j++;
				};
			};
			changed = !MusicSongCache.arraysEqual(defaultStageSongs[stageId] as Array, ids);
			defaultStageSongs[stageId] = ids;
			j = 0;
			while (j < ids.length)
			{
				trackId = String(ids[j]);
				j++;
				if (trackId && songMeta[trackId] && !songMeta[trackId].stage)
				{
					songMeta[trackId].stage = stageId;
				};
			};
			return (changed);
		}

		public function songTitle(trackId:String):String
		{
			var m:Object;
			var title:String;
			m = songMeta[trackId];
			if (m && m.title && String(m.title) != trackId && m.hydrated)
			{
				return (stripCredit(String(m.title)));
			};
			if (m && m.title && String(m.title) != trackId)
			{
				return (stripCredit(String(m.title)));
			};
			title = "";
			return (title);
		}

		/** Drop a trailing " -Author" credit. Dashes inside () or [] stay. */
		public static function stripCredit(title:String):String
		{
			var cut:int;
			cut = creditSplitIndex(title);
			if (cut > 0)
			{
				return (title.substring(0, cut));
			};
			return (title || "");
		}

		/** Author/credit after the trailing " -" (empty when none). */
		public static function extractCredit(title:String):String
		{
			var cut:int;
			var credit:String;
			cut = creditSplitIndex(title);
			if (cut < 0 || !title)
			{
				return ("");
			};
			credit = title.substring(cut + 2);
			while (credit.length > 0 && (credit.charAt(0) == " " || credit.charAt(0) == "-"))
			{
				credit = credit.substring(1);
			};
			return (credit);
		}

		/** Index of the " -" that starts a trailing credit, or -1. */
		private static function creditSplitIndex(title:String):int
		{
			var i:int;
			var depth:int;
			var last:int;
			var ch:String;
			if (!title)
			{
				return (-1);
			};
			depth = 0;
			last = -1;
			i = 0;
			while (i < title.length - 1)
			{
				ch = title.charAt(i);
				if (ch == "(" || ch == "[")
				{
					depth++;
				}
				else if (ch == ")" || ch == "]")
				{
					if (depth > 0)
					{
						depth--;
					};
				}
				else if (depth == 0 && ch == " " && title.charAt(i + 1) == "-")
				{
					last = i;
				};
				i++;
			};
			return (last);
		}

		/** Every known track id (stage songs + other + cached meta). */
		public function allTrackIds():Array
		{
			var out:Array;
			var seen:Object;
			var sid:String;
			var list:Array;
			var i:int;
			var tid:String;
			var canon:String;
			out = [];
			seen = {};
			for (sid in defaultStageSongs)
			{
				list = defaultStageSongs[sid] as Array;
				i = 0;
				while (list && i < list.length)
				{
					pushUniqueTrack(out, seen, String(list[i]));
					i++;
				};
			};
			i = 0;
			while (otherSongIds && i < otherSongIds.length)
			{
				pushUniqueTrack(out, seen, String(otherSongIds[i]));
				i++;
			};
			for (tid in songMeta)
			{
				canon = MusicPacks.canonicalTrackId(tid);
				if (tid != canon && songMeta[canon])
				{
					continue;
				};
				pushUniqueTrack(out, seen, tid);
			};
			return (out);
		}

		private function pushUniqueTrack(out:Array, seen:Object, raw:String):void
		{
			var tid:String;
			if (!raw)
			{
				return;
			};
			tid = MusicPacks.canonicalTrackId(raw);
			if (!tid || seen[tid])
			{
				return;
			};
			seen[tid] = true;
			out.push(tid);
		}

		public function trackListed(trackId:String):Boolean
		{
			var meta:Object;
			var RM:*;
			var librarySound:Boolean;
			var packAudio:Boolean;
			if (!trackId)
			{
				return (false);
			};
			meta = songMeta[trackId];
			packAudio = meta && MusicCacheFilter.keep(meta, false);
			librarySound = false;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				librarySound = RM && RM.getLibrarySound(trackId);
			}
			catch (soundErr:*)
			{
			};
			return (MusicCacheFilter.listed(MusicCacheFilter.soundOnDisk(trackId), librarySound, packAudio));
		}

		public function songTitleOrPlaceholder(trackId:String):String
		{
			var t:String;
			t = songTitle(trackId);
			return t.length > 0 ? t : "…";
		}

		public function songArtist(trackId:String):String
		{
			var m:Object;
			m = songMeta[trackId];
			if (m && m.artist && String(m.artist).length > 0)
			{
				return String(m.artist);
			};
			// Lazy id3 pull once the SWF is in memory (pack rows skip registerTrack).
			m_tracks.mergeId3IntoMeta(trackId);
			m = songMeta[trackId];
			if (m && m.artist)
			{
				return String(m.artist);
			};
			return ("");
		}

		/** Map SoundQueue CurrentSongID / music linkage back to a catalog track id. */
		public function trackForLinkage(linkage:String):String
		{
			var tid:String;
			var m:Object;
			var RM:*;
			var res:*;
			var music:*;
			if (!linkage)
			{
				return (null);
			};
			if (songMeta[linkage])
			{
				return (linkage);
			};
			for (tid in songMeta)
			{
				m = songMeta[tid];
				if (m && m.linkage && String(m.linkage) == linkage)
				{
					return (tid);
				};
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				for (tid in songMeta)
				{
					res = RM.getResourceByID(tid, true) || RM.getResourceByID(tid, false);
					if (!res)
					{
						continue;
					};
					music = res.getProp("music");
					if (music is String && String(music) == linkage)
					{
						if (songMeta[tid])
						{
							songMeta[tid].linkage = linkage;
						};
						return (tid);
					};
					if (tid == linkage)
					{
						return (tid);
					};
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		/**
		 * Stage for disc/preview art: stock defaults → MusicPacks buckets → songMeta.stage.
		 */
		public function stageForTrack(trackId:String):String
		{
			var i:int;
			var sid:String;
			var list:Array;
			var meta:Object;
			var pack:Array;
			var packStages:Array;
			if (!trackId)
			{
				return (null);
			};
			meta = songMeta[trackId];
			if (meta && meta.stageArt && String(meta.stageArt).length > 0)
			{
				return String(meta.stageArt);
			};
			if (STOCK_TRACK_STAGE[trackId])
			{
				return String(STOCK_TRACK_STAGE[trackId]);
			};
			i = 0;
			while (i < stageIds.length)
			{
				sid = String(stageIds[i]);
				i++;
				list = defaultStageSongs[sid] as Array;
				if (list && list.indexOf(trackId) >= 0)
				{
					return (sid);
				};
			};
			// Non-select / Other Stages bags also map art.
			for (sid in defaultStageSongs)
			{
				if (stageIds.indexOf(sid) >= 0)
				{
					continue;
				};
				list = defaultStageSongs[sid] as Array;
				if (list && list.indexOf(trackId) >= 0)
				{
					return (sid);
				};
			};
			i = 0;
			while (i < stageIds.length)
			{
				sid = String(stageIds[i]);
				i++;
				pack = MusicPacks.tracksForStage(sid);
				if (pack && pack.indexOf(trackId) >= 0)
				{
					return (sid);
				};
			};
			// Pack stages not on Stage Select (arena soccer/basketball, etc.).
			packStages = MusicPacks.packStageIds();
			i = 0;
			while (packStages && i < packStages.length)
			{
				sid = String(packStages[i]);
				i++;
				if (stageIds.indexOf(sid) >= 0)
				{
					continue;
				};
				pack = MusicPacks.tracksForStage(sid);
				if (pack && pack.indexOf(trackId) >= 0)
				{
					return (sid);
				};
			};
			meta = songMeta[trackId];
			if (meta && meta.stage && String(meta.stage).length > 0
				&& String(meta.stage) != MusicStageVisuals.OTHER_STAGE_ID)
			{
				return String(meta.stage);
			};
			// Loose / Other-bucket orphans: franchise art before falling back to Other.
			sid = stageGuessFromTrackFranchise(trackId);
			if (sid)
			{
				return (sid);
			};
			pack = MusicPacks.tracksForStage(MusicStageVisuals.OTHER_STAGE_ID);
			if ((pack && pack.indexOf(trackId) >= 0)
				|| (otherSongIds && otherSongIds.indexOf(trackId) >= 0))
			{
				return (MusicStageVisuals.OTHER_STAGE_ID);
			};
			return (null);
		}

		/** Prefer a real stage icon/preview over Waiting Room for franchise-matched orphans. */
		private function stageGuessFromTrackFranchise(trackId:String):String
		{
			var key:String;
			var stages:Array;
			var i:int;
			var sid:String;
			var fallback:String;
			key = MusicSeriesResolver.seriesKeyForTrack(trackId, songTitle(trackId));
			if (!key)
			{
				return (null);
			};
			stages = MusicSeriesResolver.stagesForSeries(key);
			fallback = null;
			i = 0;
			while (stages && i < stages.length)
			{
				sid = String(stages[i]);
				i++;
				if (!sid)
				{
					continue;
				};
				if (MusicStageVisuals.hasStageSelectIcon(sid))
				{
					return (sid);
				};
				if (!fallback && MusicStageVisuals.stageAppearsOnSelect(sid))
				{
					fallback = sid;
				};
			};
			if (fallback)
			{
				return (fallback);
			};
			return stages && stages.length > 0 ? String(stages[0]) : null;
		}

		public function defaultFrequency(trackId:String, stageId:String):Number
		{
			var musicArr:*;
			var i:int;
			var entry:*;
			musicArr = readStageMusic(stageId);
			if (!(musicArr is Array))
			{
				return (3);
			};
			i = 0;
			while (i < musicArr.length)
			{
				entry = musicArr[i];
				if (musicEntryId(entry) == trackId && entry && entry.frequency != null)
				{
					return (clampFreq(Number(entry.frequency)));
				};
				i++;
			};
			return (3);
		}

		/** Flatten stage_select_screen.normal/past rows into unique stage ids. */
		public static function collectStageSelectIds(mappings:Object):Array
		{
			var out:Array;
			var seen:Object;
			var screen:Object;
			var keys:Array;
			var k:int;
			var section:Object;
			var rows:Array;
			var r:int;
			var row:*;
			var c:int;
			var id:String;
			out = [];
			seen = {};
			if (!mappings || !mappings.stage_select_screen)
			{
				// Fallback: every stage in mappings.stage
				if (mappings && mappings.stage)
				{
					for (id in mappings.stage)
					{
						if (!seen[id])
						{
							seen[id] = true;
							out.push(id);
						};
					};
				};
				return (out);
			};
			screen = mappings.stage_select_screen;
			keys = ["normal", "past"];
			k = 0;
			while (k < keys.length)
			{
				section = screen[keys[k]];
				k++;
				if (!section || !(section.rows is Array))
				{
					continue;
				};
				rows = section.rows as Array;
				r = 0;
				while (r < rows.length)
				{
					row = rows[r];
					r++;
					if (row is Array)
					{
						c = 0;
						while (c < row.length)
						{
							id = String(row[c]);
							c++;
							if (id && id != "null" && !seen[id])
							{
								seen[id] = true;
								out.push(id);
							};
						};
					}
					else if (row != null)
					{
						id = String(row);
						if (id && !seen[id])
						{
							seen[id] = true;
							out.push(id);
						};
					};
				};
			};
			return (out);
		}

		public static function stageIdAllowed(stageId:String):Boolean
		{
			if (!stageId)
			{
				return (false);
			};
			if (stageId == "random" || stageId == "xpstage"
				|| stageId == MusicStageVisuals.TRAINING_GRID_ID)
			{
				return (false);
			};
			return (true);
		}

		private function computeStamp():String
		{
			var mappings:Object;
			var selectIds:Array;
			var idsKey:String;
			try
			{
				mappings = loadMappings();
				selectIds = collectStageSelectIds(mappings);
				idsKey = selectIds ? selectIds.join(",") : "";
				// Roster only — do not stamp on per-stage music availability
				// (that caused rebuild thrash / empty badges until click).
				return (String(selectIds.length) + ":" + idsKey);
			}
			catch (err:*)
			{
			};
			return ("0");
		}

		private function onSongSort(a:String, b:String):int
		{
			var ta:String = songTitle(a);
			var tb:String = songTitle(b);
			if (ta < tb)
			{
				return (-1);
			};
			if (ta > tb)
			{
				return (1);
			};
			return (0);
		}

		private function collectUnassignedMusic(assigned:Object):void
		{
			var RM:*;
			var pool:Array;
			var i:int;
			var res:*;
			var id:String;
			var music:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				pool = RM["pool"] as Array;
				if (!pool)
				{
					return;
				};
				i = 0;
				while (i < pool.length)
				{
					res = pool[i];
					i++;
					if (!res || !res.ID)
					{
						continue;
					};
					id = String(res.ID);
					if (assigned[id] || defaultStageSongs[id])
					{
						continue;
					};
					if (otherSongIds.indexOf(id) >= 0)
					{
						continue;
					};
					music = res.getProp ? res.getProp("music") : null;
					if (music is String || res.Type == 8)
					{
						registerTrack(id);
						otherSongIds.push(id);
						assigned[id] = true;
					};
				};
			}
			catch (err:*)
			{
			};
		}

		/**
		 * Stock/pack tracks that match a series by title/id but are not already
		 * on any stage playlist (e.g. Aim to Be a Pokémon Master → Pokémon).
		 */
		public function looseTracksForSeries(seriesKey:String):Array
		{
			var out:Array;
			var seen:Object;
			var assigned:Object;
			var sid:String;
			var list:Array;
			var i:int;
			var tid:String;
			var all:Array;
			var key:String;
			var title:String;
			out = [];
			if (!seriesKey || seriesKey == MusicSeriesResolver.KEY_ALL
				|| seriesKey == MusicSeriesResolver.KEY_OTHER
				|| seriesKey == MusicSeriesResolver.KEY_UNKNOWN)
			{
				return (out);
			};
			assigned = {};
			for (sid in defaultStageSongs)
			{
				list = defaultStageSongs[sid] as Array;
				i = 0;
				while (list && i < list.length)
				{
					tid = MusicPacks.canonicalTrackId(String(list[i]));
					i++;
					if (tid)
					{
						assigned[tid] = true;
					};
				};
			};
			seen = {};
			all = allTrackIds();
			i = 0;
			while (i < all.length)
			{
				tid = MusicPacks.canonicalTrackId(String(all[i]));
				i++;
				if (!tid || seen[tid] || assigned[tid])
				{
					continue;
				};
				seen[tid] = true;
				title = songTitle(tid);
				key = MusicSeriesResolver.seriesKeyForTrack(tid, title);
				if (key && key == seriesKey)
				{
					out.push(tid);
				};
			};
			out.sort(onSongSort);
			return (out);
		}

		internal function registerTrack(trackId:String):void
		{
			var RM:*;
			var res:*;
			var id3:Object;
			var title:String;
			var artist:String;
			var linkage:String;
			var music:*;
			var existing:Object;
			if (!trackId)
			{
				return;
			};
			existing = songMeta[trackId];
			// Keep cached real title/artist; only skip if already hydrated past the raw id.
			if (existing && existing.title && String(existing.title) != trackId && existing.hydrated)
			{
				return;
			};
			title = trackId;
			artist = "";
			linkage = "";
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				res = RM.getResourceByID(trackId, true) || RM.getResourceByID(trackId, false);
				if (res)
				{
					id3 = res.getProp("id3");
					if (id3)
					{
						if (id3.songName)
						{
							title = MusicCatalog.stripCredit(String(id3.songName));
						};
						if (id3.artist)
						{
							artist = String(id3.artist);
						};
					};
					music = res.getProp("music");
					if (music is String)
					{
						linkage = String(music);
					};
				};
			}
			catch (err:*)
			{
			};
			songMeta[trackId] = {
				"title": title,
				"artist": artist,
				"linkage": linkage,
				"durationMs": existing && existing.durationMs ? Number(existing.durationMs) : 0,
				"hydrated": title != trackId || artist.length > 0
			};
			m_tracks.cacheTrackDuration(trackId);
			if (songMeta[trackId].hydrated || songMeta[trackId].durationMs > 0)
			{
				m_cache.saveSongCache();
			};
		}

		/** Resolve and cache Sound.length for a track when the library sound is available. */
		public function cacheTrackDuration(trackId:String):Number
		{
			return m_tracks.cacheTrackDuration(trackId);
		}

		public function rememberLocalTrack(trackId:String, title:String, filePath:String):void
		{
			m_tracks.rememberLocalTrack(trackId, title, filePath);
		}

		public function isUploadTrack(trackId:String):Boolean
		{
			return m_tracks.isUploadTrack(trackId);
		}

		public function uploadTrackIds():Array
		{
			return m_tracks.uploadTrackIds();
		}

		public function legacyTrackIds():Array
		{
			return m_tracks.legacyTrackIds();
		}

		public function renameLocalTrack(trackId:String, title:String):void
		{
			m_tracks.renameLocalTrack(trackId, title);
		}

		public function setTrackArtist(trackId:String, artist:String):void
		{
			m_tracks.setTrackArtist(trackId, artist);
		}

		public function setTrackSeriesKey(trackId:String, seriesKey:String):void
		{
			m_tracks.setTrackSeriesKey(trackId, seriesKey);
		}

		public function setTrackStageArt(trackId:String, stageId:String):void
		{
			m_tracks.setTrackStageArt(trackId, stageId);
		}

		public function setTrackSymbolKey(trackId:String, symbolKey:String):void
		{
			m_tracks.setTrackSymbolKey(trackId, symbolKey);
		}

		public function setLoopMs(trackId:String, ms:Number):void
		{
			m_tracks.setLoopMs(trackId, ms);
		}

		public function loopMs(trackId:String):Number
		{
			return m_tracks.loopMs(trackId);
		}

		/** Override loop if set, else stock resource musicLoop (ms). */
		public function effectiveLoopMs(trackId:String):Number
		{
			return m_tracks.effectiveLoopMs(trackId);
		}

		/**
		 * One-time background fill of title/artist/duration for pack tracks missing
		 * duration — writes songcache.json as each batch completes.
		 * Never bulk-load stock bgm_* (that was stacking hundreds of SWFs → ~1GB).
		 */
		public function startPackMetaCache(host:*):void
		{
			m_tracks.startPackMetaCache(host);
		}

		public function pausePackMetaCache(paused:Boolean):void
		{
			m_tracks.pausePackMetaCache(paused);
		}

		public function forgetLocalTrack(trackId:String):void
		{
			m_tracks.forgetLocalTrack(trackId);
		}

		public function trackNeedsLoad(trackId:String):Boolean
		{
			return m_tracks.trackNeedsLoad(trackId);
		}

		public function songDurationLabel(trackId:String):String
		{
			return m_tracks.songDurationLabel(trackId);
		}

		/** Force re-read id3 after a music resource finishes loading. */
		public function refreshTrackMeta(trackId:String):void
		{
			m_tracks.refreshTrackMeta(trackId);
		}

		/** Pull id3 songName/artist from a loaded music resource into songMeta. */
		public function mergeId3IntoMeta(trackId:String):Boolean
		{
			return m_tracks.mergeId3IntoMeta(trackId);
		}

		private function stageEligible(stageId:String, mappings:Object):Boolean
		{
			var stageMap:Object;
			if (!stageIdAllowed(stageId))
			{
				return (false);
			};
			stageMap = mappings && mappings.stage ? mappings.stage : null;
			if (stageMap && !stageMap[stageId])
			{
				return (false);
			};
			return (true);
		}

		private function readStageMusic(stageId:String):Array
		{
			var RM:*;
			var res:*;
			var music:*;
			var out:Array;
			var i:int;
			var entry:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				res = RM.getResourceByID(stageId);
				if (!res)
				{
					return (null);
				};
				music = res.getProp("music");
				if (music is String)
				{
					return ([music]);
				};
				if (!(music is Array))
				{
					return (null);
				};
				out = [];
				i = 0;
				while (i < music.length)
				{
					entry = music[i];
					if (musicEntryId(entry))
					{
						out.push(entry);
					};
					i++;
				};
				return (out.length > 0 ? out : null);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private function musicEntryId(entry:*):String
		{
			if (entry is String)
			{
				return String(entry);
			};
			if (entry && entry.id)
			{
				return String(entry.id);
			};
			return (null);
		}

		private function loadMappings():Object
		{
			var RM:*;
			var mappings:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				mappings = RM.getResourceByID("mappings");
				if (mappings)
				{
					return (mappings.getProp("metadata"));
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		public function saveSongCache():void
		{
			m_cache.saveSongCache();
		}

		public static function clampFreq(v:Number):Number
		{
			if (v < 0)
			{
				return (0);
			};
			if (v > 5)
			{
				return (5);
			};
			return (v);
		}
	}
}
