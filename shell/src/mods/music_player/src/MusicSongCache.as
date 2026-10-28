package
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import ssf2mm.shared.UserStateFile;

	/**
	 * Song list persistence: immutable stock list.json and the runtime songcache.json (read, merge, write).
	 */
	public class MusicSongCache
	{
		private var cat:MusicCatalog;
		private var m_diskLoaded:Boolean;
		private static const CACHE_NAME:String = "songcache.json";
		/** Immutable stock stage→songs + track meta. Never written at runtime. */
		private static const LIST_REL:String = "data/ssf2mm/music_player/list.json";
		private var m_stockSnapshot:Object;
		private var m_diskSnapshot:Object;

		public function MusicSongCache(owner:MusicCatalog)
		{
			cat = owner;
			m_diskLoaded = false;
		}

		/** Prefer immutable list.json over SWF reads / stale songcache empties. */
		internal function mergeStockList(prevSongs:Object, prevLocked:Object, prevMeta:Object):void
		{
			var data:Object;
			var stages:Object;
			var tracks:Object;
			var id:String;
			var diskList:Array;
			var prevList:Array;
			var meta:Object;
			var existing:Object;
			data = readStockList();
			if (!data)
			{
				return;
			};
			stages = data.stages as Object;
			if (stages)
			{
				for (id in stages)
				{
					diskList = stages[id] as Array;
					if (!diskList || diskList.length < 1)
					{
						continue;
					};
					prevList = prevSongs[id] as Array;
					if (prevLocked[id] && prevList && prevList.length > 0)
					{
						// Keep non-empty in-memory only if it matches stock length or richer.
						if (prevList.length >= diskList.length)
						{
							continue;
						};
					};
					prevSongs[id] = diskList.concat();
					prevLocked[id] = true;
				};
			};
			tracks = data.tracks as Object;
			if (tracks)
			{
				for (id in tracks)
				{
					meta = tracks[id] as Object;
					if (!meta)
					{
						continue;
					};
					existing = prevMeta[id] as Object;
					if (!existing)
					{
						prevMeta[id] = {
							"title": meta.title || id,
							"artist": meta.artist || "",
							"linkage": meta.linkage || id,
							"durationMs": meta.durationMs ? Number(meta.durationMs) : 0,
							"hydrated": Boolean(meta.hydrated) || (meta.title && meta.title != id)
								|| Number(meta.durationMs) > 0,
							"loopMs": meta.loopMs ? Number(meta.loopMs) : 0,
							"stage": meta.stage || ""
						};
					}
					else
					{
						if (!(existing.durationMs > 0) && meta.durationMs > 0)
						{
							existing.durationMs = Number(meta.durationMs);
						};
						if (meta.title && (!existing.title || existing.title == id) && !existing.renamed)
						{
							existing.title = String(meta.title);
						};
						if (meta.artist && !existing.artist)
						{
							existing.artist = String(meta.artist);
						};
						if (Number(existing.durationMs) > 0 || existing.title != id)
						{
							existing.hydrated = true;
						};
					};
				};
			};
			if (data.other is Array && !(cat.m_pendingOther is Array && cat.m_pendingOther.length > 0))
			{
				cat.m_pendingOther = (data.other as Array).concat();
			};
		}

		internal function readStockList():Object
		{
			var file:File;
			var stream:FileStream;
			var raw:String;
			if (m_stockSnapshot)
			{
				return (m_stockSnapshot);
			};
			try
			{
				file = File.applicationDirectory.resolvePath(LIST_REL);
				file = new File(file.nativePath);
				if (!file || !file.exists)
				{
					return (null);
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				raw = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				m_stockSnapshot = JSON.parse(raw);
				return (m_stockSnapshot);
			}
			catch (err:*)
			{
				try
				{
					if (stream)
					{
						stream.close();
					};
				}
				catch (closeErr:*)
				{
				};
			};
			return (null);
		}

		internal static function arraysEqual(a:Array, b:Array):Boolean
		{
			var i:int;
			if (!a && !b)
			{
				return (true);
			};
			if (!a || !b || a.length != b.length)
			{
				return (false);
			};
			i = 0;
			while (i < a.length)
			{
				if (String(a[i]) != String(b[i]))
				{
					return (false);
				};
				i++;
			};
			return (true);
		}

		internal function mergeDiskCache(prevSongs:Object, prevLocked:Object, prevMeta:Object):void
		{
			var data:Object;
			var stages:Object;
			var tracks:Object;
			var id:String;
			var meta:Object;
			var existing:Object;
			var diskList:Array;
			var prevList:Array;
			var dropped:int = 0;
			data = readSongCache();
			if (!data)
			{
				return;
			};
			stages = data.stages as Object;
			if (stages)
			{
				for (id in stages)
				{
					diskList = stages[id] as Array;
					if (!diskList || diskList.length < 1)
					{
						continue;
					};
					prevList = prevSongs[id] as Array;
					// Disk wins over empty in-memory locks (stale SWF-miss sessions).
					if (prevLocked[id] && prevList && prevList.length > 0)
					{
						continue;
					};
					prevSongs[id] = diskList.concat();
					prevLocked[id] = true;
				};
			};
			tracks = data.tracks as Object;
			if (tracks)
			{
				for (id in tracks)
				{
					meta = tracks[id] as Object;
					if (!meta)
					{
						continue;
					};
					existing = prevMeta[id] as Object;
					if (!MusicCacheFilter.keep(meta, existing != null))
					{
						dropped++;
						continue;
					};
					if (!existing)
					{
						prevMeta[id] = meta;
					}
					else
					{
						if (!(existing.durationMs > 0) && meta.durationMs > 0)
						{
							existing.durationMs = Number(meta.durationMs);
						};
						if (meta.title && (!existing.title || existing.title == id))
						{
							existing.title = String(meta.title);
						};
						if (meta.artist && !existing.artist)
						{
							existing.artist = String(meta.artist);
						};
						if (meta.linkage && !existing.linkage)
						{
							existing.linkage = String(meta.linkage);
						};
						if (meta.hydrated)
						{
							existing.hydrated = true;
						};
						if (meta.file && !existing.file)
						{
							existing.file = String(meta.file);
						};
						if (meta.loopMs > 0 && !(existing.loopMs > 0))
						{
							existing.loopMs = Number(meta.loopMs);
						};
						if (meta.renamed)
						{
							existing.renamed = true;
						};
						if (meta.stage && !existing.stage)
						{
							existing.stage = String(meta.stage);
						};
						if (meta.swf && !existing.swf)
						{
							existing.swf = String(meta.swf);
						};
					};
				};
			};
			if (data.other is Array)
			{
				cat.m_pendingOther = (data.other as Array).concat();
			};
			trace("[music_player] songcache merge dropped=" + dropped + " (no stock entry, audio missing)");
		}

		public function saveSongCache():void
		{
			var stages:Object;
			var tracks:Object;
			var id:String;
			var list:Array;
			var meta:Object;
			var slim:Object;
			var payload:Object;
			var prior:Object;
			var priorStages:Object;
			stages = {};
			// Keep python-built entries for stages not currently locked in-memory
			// (Other Stages / non-select), so rebuild does not wipe songcache.json.
			prior = m_diskSnapshot;
			priorStages = prior && prior.stages is Object ? prior.stages as Object : null;
			if (priorStages)
			{
				for (id in priorStages)
				{
					list = priorStages[id] as Array;
					if (list && list.length > 0)
					{
						stages[id] = list.concat();
					};
				};
			};
			tracks = {};
			for (id in cat.m_songsLocked)
			{
				if (!cat.m_songsLocked[id])
				{
					continue;
				};
				list = cat.defaultStageSongs[id] as Array;
				if (list && list.length > 0)
				{
					stages[id] = list.concat();
				};
			};
			for (id in cat.songMeta)
			{
				meta = cat.songMeta[id] as Object;
				if (!meta)
				{
					continue;
				};
				slim = {
					"title": meta.title || id,
					"artist": meta.artist || "",
					"linkage": meta.linkage || "",
					"durationMs": meta.durationMs ? Number(meta.durationMs) : 0,
					"hydrated": Boolean(meta.hydrated),
					"file": meta.file || "",
					"loopMs": meta.loopMs ? Number(meta.loopMs) : 0,
					"renamed": Boolean(meta.renamed),
					"stage": meta.stage || "",
					"swf": meta.swf || ""
				};
				if (slim.file || slim.swf || slim.hydrated || slim.durationMs > 0
					|| (slim.linkage && slim.linkage != id) || slim.stage)
				{
					tracks[id] = slim;
				};
			};
			// Preserve prior track meta the session never hydrated.
			if (prior && prior.tracks is Object)
			{
				for (id in prior.tracks)
				{
					if (!tracks[id] && prior.tracks[id])
					{
						tracks[id] = prior.tracks[id];
					};
				};
			};
			payload = {
				"stages": stages,
				"other": cat.otherSongIds ? cat.otherSongIds.concat() : [],
				"tracks": tracks
			};
			writeSongCache(payload);
		}

		internal function readSongCache():Object
		{
			var file:File;
			var stream:FileStream;
			var raw:String;
			if (m_diskLoaded)
			{
				return (m_diskSnapshot);
			};
			m_diskLoaded = true;
			m_diskSnapshot = null;
			try
			{
				file = UserStateFile.readFile(CACHE_NAME);
				if (!file || !file.exists)
				{
					return (null);
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				raw = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				m_diskSnapshot = JSON.parse(raw);
				return (m_diskSnapshot);
			}
			catch (err:*)
			{
				try
				{
					if (stream)
					{
						stream.close();
					};
				}
				catch (closeErr:*)
				{
				};
			};
			return (null);
		}

		private function writeSongCache(payload:Object):void
		{
			var file:File;
			var stream:FileStream;
			try
			{
				file = UserStateFile.writeFile(CACHE_NAME);
				if (!file)
				{
					return;
				};
				if (file.parent && !file.parent.exists)
				{
					file.parent.createDirectory();
				};
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				stream.writeUTFBytes(JSON.stringify(payload));
				stream.close();
				m_diskSnapshot = payload;
				m_diskLoaded = true;
			}
			catch (err:*)
			{
				try
				{
					if (stream)
					{
						stream.close();
					};
				}
				catch (closeErr:*)
				{
				};
			};
		}
	}
}
