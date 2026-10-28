package
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import ssf2mm.shared.UserStateFile;

	/** Per-stage playlists, custom playlists, song frequencies — JSON on disk + saveExt mirror. */
	public class MusicPlaylistStore
	{
		public static const SAVE_EXT_KEY:String = "music_player_data";
		public static const FILE_NAME:String = "playlists.json";
		public static const MENU_PLAYLIST_ID:String = "menu_music";
		public static const UPLOAD_PLAYLIST_ID:String = "uploaded_songs";
		public static const LEGACY_PLAYLIST_ID:String = "legacy_format";
		private static const MENU_MUSIC_NAME:String = "menu-music.json";

		private var m_host:*;
		private var m_catalog:MusicCatalog;
		private var m_data:Object;

		public function MusicPlaylistStore(host:*, catalog:MusicCatalog)
		{
			m_host = host;
			m_catalog = catalog;
			m_data = null;
			load();
		}

		public function get visualizerIndex():int
		{
			return int(m_data && m_data.visualizer != null ? m_data.visualizer : 0);
		}

		public function set visualizerIndex(v:int):void
		{
			ensureRoot();
			m_data.visualizer = v;
			save();
		}

		public function songsForStage(stageId:String):Array
		{
			var bag:Object;
			var list:Array;
			var extra:Array;
			var stock:Array;
			var i:int;
			var tid:String;
			var seen:Object;
			var out:Array;
			ensureRoot();
			bag = m_data.stages[stageId];
			seen = {};
			out = [];
			// Custom jukebox list is primary, but never hide newly discovered stock/pack tracks.
			if (bag && bag.songs is Array && (bag.songs as Array).length > 0)
			{
				list = bag.songs as Array;
				i = 0;
				while (i < list.length)
				{
					tid = MusicPacks.canonicalTrackId(String(list[i]));
					i++;
					if (tid && !seen[tid])
					{
						seen[tid] = true;
						out.push(tid);
					};
				};
				stock = stockBaseSongs(stageId);
				i = 0;
				while (stock && i < stock.length)
				{
					tid = MusicPacks.canonicalTrackId(String(stock[i]));
					i++;
					if (tid && !seen[tid])
					{
						seen[tid] = true;
						out.push(tid);
					};
				};
				extra = MusicPacks.tracksForStage(stageId);
				i = 0;
				while (extra && i < extra.length)
				{
					tid = MusicPacks.canonicalTrackId(String(extra[i]));
					i++;
					if (tid && !seen[tid])
					{
						seen[tid] = true;
						out.push(tid);
					};
				};
				return (out);
			};
			list = stockBaseSongs(stageId);
			extra = MusicPacks.tracksForStage(stageId);
			i = 0;
			while (list && i < list.length)
			{
				tid = MusicPacks.canonicalTrackId(String(list[i]));
				i++;
				if (tid && !seen[tid])
				{
					seen[tid] = true;
					out.push(tid);
				};
			};
			i = 0;
			while (extra && i < extra.length)
			{
				tid = MusicPacks.canonicalTrackId(String(extra[i]));
				i++;
				if (tid && !seen[tid])
				{
					seen[tid] = true;
					out.push(tid);
				};
			};
			return (out);
		}

		/** Stock defaults only — never includes MusicPacks (for freezing stage bags). */
		public function stockBaseSongs(stageId:String):Array
		{
			var list:Array;
			if (stageId == MusicStageVisuals.OTHER_STAGE_ID)
			{
				return (m_catalog.otherSongIds ? m_catalog.otherSongIds.concat() : []);
			};
			list = m_catalog.defaultStageSongs[stageId] as Array;
			return (list ? list.concat() : []);
		}

		/**
		 * Drop pack ids that were incorrectly baked into frozen stage bags,
		 * then dedupe. Call after MusicPacks.sync().
		 */
		public function migrateStripPackIds():void
		{
			var sid:String;
			var bag:Object;
			var list:Array;
			var pack:Array;
			var packSet:Object;
			var i:int;
			var tid:String;
			var next:Array;
			var seen:Object;
			var changed:Boolean;
			ensureRoot();
			changed = false;
			for (sid in m_data.stages)
			{
				bag = m_data.stages[sid];
				if (!bag || !(bag.songs is Array))
				{
					continue;
				};
				list = bag.songs as Array;
				pack = MusicPacks.tracksForStage(sid);
				packSet = {};
				i = 0;
				while (pack && i < pack.length)
				{
					packSet[String(pack[i])] = true;
					i++;
				};
				next = [];
				seen = {};
				i = 0;
				while (i < list.length)
				{
					tid = String(list[i]);
					i++;
					if (!tid || packSet[tid] || seen[tid])
					{
						changed = true;
						continue;
					};
					seen[tid] = true;
					next.push(tid);
				};
				if (next.length != list.length)
				{
					changed = true;
				};
				if (next.length < 1)
				{
					delete m_data.stages[sid];
					changed = true;
				}
				else
				{
					bag.songs = next;
				};
			};
			if (changed)
			{
				save();
			};
		}

		/** Rewrite bgm_legacy_* entries to pack ids after MusicPacks.sync(). */
		public function migrateLegacyTrackIds():void
		{
			var sid:String;
			var bag:Object;
			var pid:String;
			var pl:Object;
			var list:Array;
			var i:int;
			var tid:String;
			var canon:String;
			var next:Array;
			var seen:Object;
			var freq:Object;
			var nk:String;
			var changed:Boolean;
			ensureRoot();
			changed = false;
			for (sid in m_data.stages)
			{
				bag = m_data.stages[sid];
				if (!bag)
				{
					continue;
				};
				if (bag.songs is Array)
				{
					next = remapIdList(bag.songs as Array);
					if (next !== bag.songs)
					{
						changed = true;
						bag.songs = next;
					};
				};
				if (bag.freq)
				{
					freq = {};
					for (tid in bag.freq)
					{
						canon = MusicPacks.canonicalTrackId(String(tid));
						if (canon != tid)
						{
							changed = true;
						};
						freq[canon] = bag.freq[tid];
					};
					bag.freq = freq;
				};
			};
			for (pid in m_data.playlists)
			{
				pl = m_data.playlists[pid];
				if (!pl || !(pl.songs is Array))
				{
					continue;
				};
				next = remapIdList(pl.songs as Array);
				if (next !== pl.songs)
				{
					changed = true;
					pl.songs = next;
				};
			};
			if (changed)
			{
				save();
			};
		}

		private function remapIdList(list:Array):Array
		{
			var out:Array;
			var seen:Object;
			var i:int;
			var tid:String;
			var canon:String;
			var touched:Boolean;
			out = [];
			seen = {};
			touched = false;
			i = 0;
			while (list && i < list.length)
			{
				tid = String(list[i]);
				i++;
				canon = MusicPacks.canonicalTrackId(tid);
				if (canon != tid)
				{
					touched = true;
				};
				if (!canon || seen[canon])
				{
					if (canon)
					{
						touched = true;
					};
					continue;
				};
				seen[canon] = true;
				out.push(canon);
			};
			if (!touched && out.length == list.length)
			{
				return (list);
			};
			return (out);
		}

		/** True when the user customized this stage list (not stock defaults). */
		public function hasCustomStageSongs(stageId:String):Boolean
		{
			var bag:Object;
			ensureRoot();
			bag = m_data.stages[stageId];
			return Boolean(bag && bag.songs is Array && (bag.songs as Array).length > 0);
		}

		/** Weighted pick from a stage's jukebox list (custom or default). */
		public function pickWeightedTrack(stageId:String):String
		{
			var list:Array;
			var i:int;
			var tid:String;
			var w:Number;
			var total:Number;
			var roll:Number;
			var acc:Number;
			list = songsForStage(stageId);
			if (!list || list.length < 1)
			{
				return (null);
			};
			total = 0;
			i = 0;
			while (i < list.length)
			{
				tid = String(list[i]);
				i++;
				w = frequency(stageId, tid);
				if (w < 0)
				{
					w = 0;
				};
				total += w;
			};
			if (total <= 0)
			{
				return String(list[int(Math.random() * list.length)]);
			};
			roll = Math.random() * total;
			acc = 0;
			i = 0;
			while (i < list.length)
			{
				tid = String(list[i]);
				acc += frequency(stageId, tid);
				if (roll <= acc)
				{
					return (tid);
				};
				i++;
			};
			return String(list[list.length - 1]);
		}

		public function frequency(stageId:String, trackId:String):Number
		{
			var bag:Object;
			var freq:Object;
			ensureRoot();
			bag = m_data.stages[stageId];
			if (bag && bag.freq && bag.freq[trackId] != null)
			{
				return MusicCatalog.clampFreq(Number(bag.freq[trackId]));
			};
			return (m_catalog.defaultFrequency(trackId, stageId));
		}

		public function setFrequency(stageId:String, trackId:String, value:Number):void
		{
			ensureStage(stageId);
			if (!m_data.stages[stageId].freq)
			{
				m_data.stages[stageId].freq = {};
			};
			m_data.stages[stageId].freq[trackId] = MusicCatalog.clampFreq(value);
			save();
		}

		public function addSong(stageId:String, trackId:String):void
		{
			var list:Array;
			if (!trackId)
			{
				return;
			};
			trackId = MusicPacks.canonicalTrackId(trackId);
			// Already present live (stock, custom, or pack) — do not freeze pack ids.
			if (songsForStage(stageId).indexOf(trackId) >= 0)
			{
				return;
			};
			ensureStage(stageId);
			list = m_data.stages[stageId].songs as Array;
			if (!(list is Array))
			{
				list = stockBaseSongs(stageId);
			};
			if (list.indexOf(trackId) >= 0)
			{
				return;
			};
			list.push(trackId);
			m_data.stages[stageId].songs = list;
			save();
		}

		/** Returns false if track would have zero stage assignments. */
		public function removeSong(stageId:String, trackId:String):Boolean
		{
			var list:Array;
			var i:int;
			var pack:Array;
			if (!canRemoveFromStage(stageId, trackId))
			{
				return (false);
			};
			// Pack-backed tracks are live-merged; cannot remove from frozen bag alone.
			pack = MusicPacks.tracksForStage(stageId);
			if (pack && pack.indexOf(trackId) >= 0)
			{
				return (false);
			};
			ensureStage(stageId);
			list = m_data.stages[stageId].songs as Array;
			if (!(list is Array))
			{
				list = stockBaseSongs(stageId);
			};
			i = list.indexOf(trackId);
			if (i >= 0)
			{
				list.splice(i, 1);
			};
			m_data.stages[stageId].songs = list;
			save();
			return (true);
		}

		public function restoreStageDefaults(stageId:String):void
		{
			ensureRoot();
			if (m_data.stages[stageId])
			{
				delete m_data.stages[stageId];
			};
			save();
		}

		public function customPlaylistIds():Array
		{
			var out:Array;
			var k:String;
			out = [];
			ensureRoot();
			ensureMenuMusicPlaylist();
			if (!m_data.custom)
			{
				return (out);
			};
			// Builtin Menu Music always first.
			if (m_data.custom[MENU_PLAYLIST_ID])
			{
				out.push(MENU_PLAYLIST_ID);
			};
			for (k in m_data.custom)
			{
				if (k == MENU_PLAYLIST_ID)
				{
					continue;
				};
				out.push(k);
			};
			out.sort(function (a:String, b:String):int
			{
				if (a == MENU_PLAYLIST_ID)
				{
					return (-1);
				};
				if (b == MENU_PLAYLIST_ID)
				{
					return (1);
				};
				if (a < b)
				{
					return (-1);
				};
				if (a > b)
				{
					return (1);
				};
				return (0);
			});
			return (out);
		}

		public function isBuiltinPlaylist(id:String):Boolean
		{
			return (id == MENU_PLAYLIST_ID || id == UPLOAD_PLAYLIST_ID
				|| id == LEGACY_PLAYLIST_ID || MusicPacks.isPackId(id));
		}

		/** Next free "Playlist N" label and mix_N id. */
		public function nextPlaylistSlot():Object
		{
			var n:int;
			var id:String;
			var label:String;
			ensureRoot();
			n = 1;
			while (n < 10000)
			{
				id = "mix_" + String(n);
				label = "Playlist " + String(n);
				if (!m_data.custom[id])
				{
					return ({"id": id, "label": label});
				};
				n++;
			};
			id = "mix_" + String(new Date().time);
			return ({"id": id, "label": "Playlist"});
		}

		public function createPlaylist(id:String, label:String, iconKey:String = null):void
		{
			ensureRoot();
			if (!m_data.custom)
			{
				m_data.custom = {};
			};
			if (!id || m_data.custom[id] || id == MENU_PLAYLIST_ID || id == UPLOAD_PLAYLIST_ID
				|| id == LEGACY_PLAYLIST_ID || MusicPacks.isPackId(id))
			{
				return;
			};
			m_data.custom[id] = {
				"label": label || id,
				"songs": [],
				"freq": {},
				"icon": iconKey || MusicSeriesResolver.KEY_ALL
			};
			save();
		}

		public function renamePlaylist(id:String, label:String):Boolean
		{
			ensureRoot();
			if (!id || isBuiltinPlaylist(id) || !m_data.custom || !m_data.custom[id])
			{
				return (false);
			};
			if (!label || label.length < 1)
			{
				return (false);
			};
			m_data.custom[id].label = label;
			save();
			return (true);
		}

		public function deletePlaylist(id:String):Boolean
		{
			ensureRoot();
			if (!id || isBuiltinPlaylist(id) || !m_data.custom || !m_data.custom[id])
			{
				return (false);
			};
			delete m_data.custom[id];
			save();
			return (true);
		}

		/** Drop a track from every stage bag and custom playlist. */
		public function purgeTrack(trackId:String):void
		{
			var sid:String;
			var pid:String;
			var list:Array;
			var i:int;
			var changed:Boolean;
			if (!trackId)
			{
				return;
			};
			ensureRoot();
			changed = false;
			for (sid in m_data.stages)
			{
				list = m_data.stages[sid] && m_data.stages[sid].songs is Array
					? (m_data.stages[sid].songs as Array) : null;
				if (!list)
				{
					continue;
				};
				i = list.indexOf(trackId);
				if (i >= 0)
				{
					list.splice(i, 1);
					m_data.stages[sid].songs = list;
					changed = true;
				};
			};
			for (pid in m_data.custom)
			{
				list = m_data.custom[pid] && m_data.custom[pid].songs is Array
					? (m_data.custom[pid].songs as Array) : null;
				if (!list)
				{
					continue;
				};
				i = list.indexOf(trackId);
				if (i >= 0)
				{
					list.splice(i, 1);
					m_data.custom[pid].songs = list;
					changed = true;
					if (pid == MENU_PLAYLIST_ID)
					{
						writeMenuMusicSongs(list);
					};
				};
			};
			if (changed)
			{
				save();
			};
		}

		public function playlistLabel(id:String):String
		{
			var bag:Object;
			ensureRoot();
			if (id == MENU_PLAYLIST_ID)
			{
				return ("Menu Music");
			};
			bag = m_data.custom ? m_data.custom[id] : null;
			if (bag && bag.label)
			{
				return String(bag.label);
			};
			return (id);
		}

		public function playlistIcon(id:String):String
		{
			var bag:Object;
			ensureRoot();
			bag = m_data.custom ? m_data.custom[id] : null;
			if (bag && bag.icon)
			{
				return String(bag.icon);
			};
			return (MusicSeriesResolver.KEY_ALL);
		}

		public function songsForPlaylist(id:String):Array
		{
			var bag:Object;
			ensureRoot();
			bag = m_data.custom ? m_data.custom[id] : null;
			if (bag && bag.songs is Array)
			{
				return (bag.songs.concat());
			};
			return ([]);
		}

		public function addSongToPlaylist(id:String, trackId:String):void
		{
			var list:Array;
			if (!id || !trackId)
			{
				return;
			};
			trackId = MusicPacks.canonicalTrackId(trackId);
			ensureRoot();
			if (!m_data.custom || !m_data.custom[id])
			{
				return;
			};
			list = songsForPlaylist(id);
			if (list.indexOf(trackId) >= 0)
			{
				return;
			};
			list.push(trackId);
			m_data.custom[id].songs = list;
			save();
			if (id == MENU_PLAYLIST_ID)
			{
				writeMenuMusicSongs(list);
			};
		}

		public function removeSongFromPlaylist(id:String, trackId:String):Boolean
		{
			var list:Array;
			var i:int;
			if (!id || !trackId || !m_data || !m_data.custom || !m_data.custom[id])
			{
				return (false);
			};
			list = songsForPlaylist(id);
			i = list.indexOf(trackId);
			if (i < 0)
			{
				return (false);
			};
			if (list.length <= 1)
			{
				return (false);
			};
			list.splice(i, 1);
			m_data.custom[id].songs = list;
			save();
			if (id == MENU_PLAYLIST_ID)
			{
				writeMenuMusicSongs(list);
			};
			return (true);
		}

		public function assignmentCount(trackId:String):int
		{
			var count:int;
			var sid:String;
			var list:Array;
			var i:int;
			count = 0;
			i = 0;
			while (i < m_catalog.stageIds.length)
			{
				sid = String(m_catalog.stageIds[i]);
				i++;
				list = songsForStage(sid);
				if (list.indexOf(trackId) >= 0)
				{
					count++;
				};
			};
			list = songsForStage(MusicStageVisuals.OTHER_STAGE_ID);
			if (list.indexOf(trackId) >= 0)
			{
				count++;
			};
			return (count);
		}

		public function canRemoveFromStage(stageId:String, trackId:String):Boolean
		{
			var list:Array;
			if (assignmentCount(trackId) > 1)
			{
				return (true);
			};
			list = songsForStage(stageId);
			return (list.indexOf(trackId) >= 0 && list.length > 1);
		}

		private function ensureRoot():void
		{
			if (!m_data)
			{
				m_data = {"version": 1, "visualizer": 0, "stages": {}, "custom": {}};
			};
			if (!m_data.stages)
			{
				m_data.stages = {};
			};
			if (!m_data.custom)
			{
				m_data.custom = {};
			};
		}

		/** Re-read menu-music.json into the builtin Menu Music playlist. */
		public function syncMenuMusicFromDisk():void
		{
			ensureMenuMusicPlaylist();
		}

		/** Keep a default Playlists entry synced to data/ssf2mm/state/menu-music.json. */
		private function ensureMenuMusicPlaylist():void
		{
			var songs:Array;
			var bag:Object;
			var changed:Boolean;
			ensureRoot();
			if (!m_data.custom)
			{
				m_data.custom = {};
			};
			songs = readMenuMusicSongs();
			bag = m_data.custom[MENU_PLAYLIST_ID] as Object;
			if (!bag)
			{
				m_data.custom[MENU_PLAYLIST_ID] = {
					"label": "Menu Music",
					"songs": songs,
					"freq": {},
					"icon": MusicSeriesResolver.KEY_ALL,
					"builtin": true
				};
				save();
				return;
			};
			changed = false;
			if (String(bag.label) != "Menu Music")
			{
				bag.label = "Menu Music";
				changed = true;
			};
			bag.builtin = true;
			if (!bag.icon)
			{
				bag.icon = MusicSeriesResolver.KEY_ALL;
				changed = true;
			};
			if (!arraysEqualStrings(bag.songs as Array, songs))
			{
				bag.songs = songs;
				changed = true;
			};
			if (changed)
			{
				save();
			};
		}

		private function readMenuMusicSongs():Array
		{
			var file:File;
			var stream:FileStream;
			var raw:String;
			var data:Object;
			var list:Array;
			var i:int;
			var id:String;
			var out:Array;
			out = [];
			try
			{
				file = UserStateFile.readFile(MENU_MUSIC_NAME);
				if (!file.exists)
				{
					return (out);
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				raw = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				data = JSON.parse(raw);
				list = data && data.playlist is Array ? (data.playlist as Array) : [];
				i = 0;
				while (i < list.length)
				{
					id = String(list[i]);
					i++;
					if (id && out.indexOf(id) < 0)
					{
						out.push(id);
					};
				};
				if (out.length < 1 && data && data.id)
				{
					out.push(String(data.id));
				};
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
			return (out);
		}

		private function writeMenuMusicSongs(songs:Array):void
		{
			var file:File;
			var stream:FileStream;
			var data:Object;
			var raw:String;
			var parts:Array;
			var i:int;
			var id:String;
			try
			{
				file = UserStateFile.readFile(MENU_MUSIC_NAME);
				data = {"id": "", "name": "Menu Music", "loop": 0, "enabled": true, "playlist": []};
				if (file.exists)
				{
					stream = new FileStream();
					stream.open(file, FileMode.READ);
					raw = stream.readUTFBytes(stream.bytesAvailable);
					stream.close();
					try
					{
						data = JSON.parse(raw);
					}
					catch (parseErr:*)
					{
					};
				};
				data.playlist = songs ? songs.concat() : [];
				if ((!data.id || String(data.id).length < 1) && songs && songs.length > 0)
				{
					data.id = String(songs[0]);
				};
				parts = [];
				i = 0;
				while (songs && i < songs.length)
				{
					id = String(songs[i]);
					i++;
					parts.push("\"" + jsonEscape(id) + "\"");
				};
				if (!data.name)
				{
					data.name = "Menu Music";
				};
				raw = "{\"id\":\"" + jsonEscape(String(data.id || ""))
					+ "\",\"name\":\"" + jsonEscape(String(data.name || "Menu Music"))
					+ "\",\"loop\":" + Number(data.loop || 0)
					+ ",\"enabled\":" + (data.enabled === false ? "false" : "true")
					+ ",\"playlist\":[" + parts.join(",") + "]}";
				file = UserStateFile.writeFile(MENU_MUSIC_NAME);
				if (file.parent && !file.parent.exists)
				{
					file.parent.createDirectory();
				};
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				stream.writeUTFBytes(raw);
				stream.close();
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

		private static function jsonEscape(s:String):String
		{
			if (!s)
			{
				return ("");
			};
			return (s.split("\\").join("\\\\").split("\"").join("\\\""));
		}

		private static function arraysEqualStrings(a:Array, b:Array):Boolean
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

		private function ensureStage(stageId:String):void
		{
			ensureRoot();
			if (!m_data.stages[stageId])
			{
				// Freeze stock only — packs are live-merged at read time.
				m_data.stages[stageId] = {"songs": stockBaseSongs(stageId), "freq": {}};
			};
		}

		private function load():void
		{
			var raw:String;
			m_data = null;
			raw = readFileText();
			if (!raw && m_host)
			{
				try
				{
					raw = m_host.saveExtGet(SAVE_EXT_KEY, null) as String;
				}
				catch (extErr:*)
				{
				};
			};
			if (raw && raw.length > 0)
			{
				try
				{
					m_data = JSON.parse(raw);
				}
				catch (parseErr:*)
				{
					m_data = null;
				};
			};
			ensureRoot();
			ensureMenuMusicPlaylist();
		}

		private function save():void
		{
			var text:String;
			ensureRoot();
			try
			{
				text = JSON.stringify(m_data);
			}
			catch (serErr:*)
			{
				trace("[music_player] playlist save serialize failed: " + serErr);
				return;
			};
			writeFileText(text);
			if (m_host)
			{
				try
				{
					m_host.saveExtSet(SAVE_EXT_KEY, text);
				}
				catch (extErr:*)
				{
					trace("[music_player] playlist save saveExtSet failed: " + extErr);
				};
			};
		}

		private function readFileText():String
		{
			var file:File;
			var stream:FileStream;
			try
			{
				file = UserStateFile.readFile(FILE_NAME);
				if (!file.exists)
				{
					return (null);
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				return stream.readUTFBytes(stream.bytesAvailable);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private function writeFileText(text:String):void
		{
			var file:File;
			var stream:FileStream;
			try
			{
				file = UserStateFile.writeFile(FILE_NAME);
				if (!file.parent.exists)
				{
					file.parent.createDirectory();
				};
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				stream.writeUTFBytes(text);
				stream.close();
			}
			catch (err:*)
			{
				trace("[music_player] playlist save write failed: " + err);
			};
		}
	}
}
