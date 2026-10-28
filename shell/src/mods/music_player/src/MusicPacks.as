package
{
	import flash.filesystem.File;
	import ssf2mm.shared.JsonFile;
	import ssf2mm.shared.EngineRefs;

	/**
	 * expansions/songs/packs/&lt;id&gt;/list.json
	 * Enabled packs are toggled with info.json (Manage Mods). Packed .ssf files
	 * are registered as-is; the game decompresses them when the song loads.
	 */
	public class MusicPacks
	{
		private static var s_byStage:Object = {};
		private static var s_packSongs:Object = {};
		private static var s_packMeta:Object = {};
		/** bgm_legacy_psm116 → pack bgm_* from list.json file names. */
		private static var s_legacyToCanonical:Object = {};

		public static function sync(catalog:MusicCatalog):void
		{
			var root:File;
			var packs:Array;
			var i:int;
			var pack:File;
			s_byStage = {};
			s_packSongs = {};
			s_packMeta = {};
			s_legacyToCanonical = {};
			root = packsRoot();
			if (!root.exists)
			{
				return;
			};
			try
			{
				packs = root.getDirectoryListing();
			}
			catch (err:*)
			{
				return;
			};
			i = 0;
			while (packs && i < packs.length)
			{
				pack = packs[i] as File;
				i++;
				if (!pack || !pack.isDirectory)
				{
					continue;
				};
				if (!packEnabled(pack))
				{
					continue;
				};
				applyPack(catalog, pack);
			};
			if (catalog)
			{
				catalog.saveSongCache();
			};
		}

		public static function tracksForStage(stageId:String):Array
		{
			var list:Array;
			if (!stageId || !s_byStage)
			{
				return ([]);
			};
			list = s_byStage[stageId] as Array;
			return (list ? list.concat() : []);
		}

		/** Stage ids referenced by enabled packs (includes arena / non-select stages). */
		public static function packStageIds():Array
		{
			var out:Array;
			var sid:String;
			out = [];
			for (sid in s_byStage)
			{
				if (sid)
				{
					out.push(sid);
				};
			};
			return (out);
		}

		public static function hasTracks(stageId:String):Boolean
		{
			return (tracksForStage(stageId).length > 0);
		}

		/** Enabled packs for Playlists-tab cells: {id, label, songs}. */
		public static function enabledPackEntries():Array
		{
			var out:Array;
			var id:String;
			var meta:Object;
			out = [];
			for (id in s_packMeta)
			{
				meta = s_packMeta[id];
				if (!meta)
				{
					continue;
				};
				out.push({
					"id": id,
					"label": String(meta.label || id),
					"songs": songsForPack(id)
				});
			};
			out.sort(function (a:Object, b:Object):int
			{
				var la:String = String(a.label || "").toLowerCase();
				var lb:String = String(b.label || "").toLowerCase();
				if (la < lb)
				{
					return (-1);
				};
				if (la > lb)
				{
					return (1);
				};
				return (0);
			});
			return (out);
		}

		public static function songsForPack(packId:String):Array
		{
			var list:Array;
			if (!packId || !s_packSongs)
			{
				return ([]);
			};
			list = s_packSongs[packId] as Array;
			return (list ? list.concat() : []);
		}

		public static function isPackId(packId:String):Boolean
		{
			return Boolean(packId && s_packMeta && s_packMeta[packId]);
		}

		/** Map frozen legacy ids (bgm_legacy_*) to pack track ids after PSM move to packs. */
		public static function canonicalTrackId(trackId:String):String
		{
			var mapped:String;
			if (!trackId)
			{
				return (trackId);
			};
			mapped = s_legacyToCanonical[trackId];
			if (mapped)
			{
				return (mapped);
			};
			return (trackId);
		}

		/**
		 * Write packs/&lt;slug&gt;/list.json + info.json referencing existing audio files
		 * (no second copy of PSM bytes). Returns the slug used, or null on failure.
		 */
		public static function savePlaylistAsPack(slug:String, label:String, songIds:Array,
			catalog:MusicCatalog):String
		{
			var root:File;
			var dir:File;
			var listFile:File;
			var infoFile:File;
			var songs:Array;
			var i:int;
			var tid:String;
			var meta:Object;
			var path:String;
			var entry:Object;
			var stages:Array;
			var safe:String;
			safe = sanitizeSlug(slug || label || "playlist");
			if (!safe || !songIds || songIds.length < 1)
			{
				return (null);
			};
			root = packsRoot();
			try
			{
				if (!root.exists)
				{
					root.createDirectory();
				};
			}
			catch (mkErr:*)
			{
				return (null);
			};
			dir = root.resolvePath(safe);
			try
			{
				if (!dir.exists)
				{
					dir.createDirectory();
				};
			}
			catch (dirErr:*)
			{
				return (null);
			};
			songs = [];
			i = 0;
			while (i < songIds.length)
			{
				tid = String(songIds[i]);
				i++;
				if (!tid)
				{
					continue;
				};
				meta = catalog && catalog.songMeta ? catalog.songMeta[tid] : null;
				path = resolveTrackAudioPath(tid, meta);
				if (!path)
				{
					continue;
				};
				stages = [];
				if (meta && meta.stage)
				{
					stages.push(String(meta.stage));
				};
				entry = {
					"id": tid,
					"file": path,
					"title": meta && meta.title ? String(meta.title) : prettyId(tid),
					"titleTrusted": true,
					"stages": stages
				};
				songs.push(entry);
			};
			if (songs.length < 1)
			{
				return (null);
			};
			if (!JsonFile.write(dir.resolvePath("list.json"), {
				"name": label || safe,
				"songs": songs
			}))
			{
				return (null);
			};
			if (!JsonFile.write(dir.resolvePath("info.json"), {
				"name": label || safe,
				"enabled": true
			}))
			{
				return (null);
			};
			if (catalog)
			{
				sync(catalog);
			};
			return (safe);
		}

		private static function resolveTrackAudioPath(trackId:String, meta:Object):String
		{
			var file:File;
			if (meta && meta.file)
			{
				file = new File(String(meta.file));
				if (file.exists)
				{
					return (file.nativePath);
				};
			};
			if (meta && meta.swf)
			{
				file = new File(String(meta.swf));
				if (file.exists)
				{
					return (file.nativePath);
				};
			};
			file = MusicSongLibrary.swfFileFor(trackId);
			if (file && file.exists)
			{
				return (file.nativePath);
			};
			return (null);
		}

		private static function applyPack(catalog:MusicCatalog, pack:File):void
		{
			var listFile:File;
			var data:Object;
			var info:Object;
			var songs:Array;
			var i:int;
			var song:Object;
			var id:String;
			var fileName:String;
			var audio:File;
			var stages:Array;
			var title:String;
			var artist:String;
			var rawTitle:String;
			var s:int;
			var sid:String;
			var bucket:Array;
			var packId:String;
			var packLabelStr:String;
			var ids:Array;
			packId = pack.name;
			listFile = pack.resolvePath("list.json");
			if (!listFile.exists)
			{
				return;
			};
			data = JsonFile.read(listFile);
			if (!data || !(data.songs is Array))
			{
				return;
			};
			info = JsonFile.read(pack.resolvePath("info.json"));
			packLabelStr = "";
			if (info && info.name)
			{
				packLabelStr = String(info.name);
			}
			else if (data.name)
			{
				packLabelStr = String(data.name);
			};
			if (!packLabelStr)
			{
				packLabelStr = packId;
			};
			s_packMeta[packId] = {"label": packLabelStr};
			ids = [];
			songs = data.songs as Array;
			i = 0;
			while (i < songs.length)
			{
				song = songs[i];
				i++;
				if (!song || !song.id || !song.file)
				{
					continue;
				};
				id = String(song.id);
				fileName = String(song.file);
				rememberLegacyAlias(fileName, id);
				audio = resolvePackAudio(pack, fileName);
				if (!audio)
				{
					continue;
				};
				title = "";
				artist = "";
				if (song.artist)
				{
					artist = String(song.artist);
				}
				else if (song.author)
				{
					artist = String(song.author);
				};
				rawTitle = song.title ? String(song.title) : "";
				if (rawTitle && song.titleTrusted !== false)
				{
					title = MusicCatalog.stripCredit(rawTitle);
					if (!artist)
					{
						artist = MusicCatalog.extractCredit(rawTitle);
					};
				};
				if (!title)
				{
					title = prettyId(id);
				};
				stages = song.stages as Array;
				remember(catalog, id, title, artist, audio, stages, song.titleTrusted !== false);
				registerPacked(id, audio);
				if (ids.indexOf(id) < 0)
				{
					ids.push(id);
				};
				s = 0;
				while (stages && s < stages.length)
				{
					sid = String(stages[s]);
					s++;
					if (!sid)
					{
						continue;
					};
					bucket = s_byStage[sid] as Array;
					if (!bucket)
					{
						bucket = [];
						s_byStage[sid] = bucket;
					};
					if (bucket.indexOf(id) < 0)
					{
						bucket.push(id);
					};
				};
			};
			s_packSongs[packId] = ids;
		}

		private static function rememberLegacyAlias(fileName:String, canonicalId:String):void
		{
			var base:String;
			var legacyId:String;
			if (!fileName || !canonicalId)
			{
				return;
			};
			base = fileName;
			if (base.lastIndexOf(".") > 0)
			{
				base = base.substring(0, base.lastIndexOf("."));
			};
			if (!base)
			{
				return;
			};
			legacyId = MusicSongLibrary.idForLegacyName(base);
			if (legacyId && legacyId != canonicalId)
			{
				s_legacyToCanonical[legacyId] = canonicalId;
			};
		}

		private static function remember(catalog:MusicCatalog, trackId:String, title:String,
			artist:String, audio:File, stages:Array, titleTrusted:Boolean = true):void
		{
			var meta:Object;
			if (!catalog || !trackId)
			{
				return;
			};
			meta = catalog.songMeta[trackId];
			if (meta && meta.renamed)
			{
				meta.pack = true;
				if (artist && !meta.artist)
				{
					meta.artist = artist;
				};
				if (audio && audio.exists)
				{
					meta.swf = audio.nativePath;
				};
				if (stages && stages.length > 0 && !meta.stage)
				{
					meta.stage = String(stages[0]);
				};
				return;
			};
			if (!meta)
			{
				meta = {};
				catalog.songMeta[trackId] = meta;
			};
			meta.title = title || trackId;
			meta.titleTrusted = titleTrusted;
			if (artist)
			{
				meta.artist = artist;
			}
			else if (!meta.artist)
			{
				meta.artist = "";
			};
			meta.linkage = meta.linkage || trackId;
			meta.hydrated = true;
			meta.pack = true;
			if (audio && audio.exists)
			{
				meta.swf = audio.nativePath;
			};
			if (stages && stages.length > 0)
			{
				meta.stage = String(stages[0]);
			};
		}

		private static function registerPacked(trackId:String, file:File):void
		{
			var RM:*;
			var Res:Class;
			var res:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				Res = EngineRefs.ssf2("util.Resource") as Class;
				res = RM.getResourceByID(trackId);
				if (res)
				{
					res.UrlOverride = packFileUrl(file);
					if (res.Loaded && !(res.getProp && res.getProp("music")))
					{
						res.Loaded = false;
					};
					return;
				};
				res = new Res(trackId, "expansions/songs/packs/psb/" + file.name, null, "", Res["MUSIC"]);
				res.UrlOverride = packFileUrl(file);
				res.SoftFail = true;
				RM.addResource(res);
			}
			catch (err:*)
			{
				trace("[music_player] pack register failed: " + err);
			};
		}

		private static function packEnabled(pack:File):Boolean
		{
			var info:File;
			var data:Object;
			info = pack.resolvePath("info.json");
			if (!info.exists)
			{
				return (true);
			};
			data = JsonFile.read(info);
			if (data && data.enabled === false)
			{
				return (false);
			};
			return (true);
		}

		private static function resolvePackAudio(pack:File, fileName:String):File
		{
			var audio:File;
			var altName:String;
			var alt:File;
			if (!fileName)
			{
				return (null);
			};
			// Absolute / native path (save-as-pack references).
			if (fileName.indexOf(":") >= 0 || fileName.indexOf("\\\\") == 0 || fileName.charAt(0) == "/")
			{
				audio = new File(fileName);
				if (audio.exists)
				{
					return (audio);
				};
			};
			audio = new File(pack.resolvePath(fileName).nativePath);
			if (audio.exists)
			{
				return (audio);
			};
			altName = fileName;
			if (altName.length > 4 && altName.substr(altName.length - 4).toLowerCase() == ".ssf")
			{
				altName = altName.substr(0, altName.length - 4) + ".swf";
			}
			else if (altName.length > 4 && altName.substr(altName.length - 4).toLowerCase() == ".swf")
			{
				altName = altName.substr(0, altName.length - 4) + ".ssf";
			};
			alt = new File(pack.resolvePath(altName).nativePath);
			if (alt.exists)
			{
				return (alt);
			};
			return (null);
		}

		/** Resource.UrlOverride rewrites a trailing .ssf to .swf, so the file on disk must be .swf. */
		private static function packFileUrl(file:File):String
		{
			var swf:File;
			var path:String;
			if (!file)
			{
				return ("");
			};
			path = file.nativePath ? String(file.nativePath) : "";
			if (path.length > 4 && path.substr(path.length - 4).toLowerCase() == ".ssf")
			{
				swf = new File(path.substr(0, path.length - 4) + ".swf");
				if (!swf.exists && file.exists)
				{
					file.moveTo(swf, true);
				};
				return (swf.url);
			};
			return (file.url);
		}

		private static function sanitizeSlug(raw:String):String
		{
			var out:String;
			var i:int;
			var ch:String;
			var code:int;
			out = "";
			i = 0;
			while (raw && i < raw.length)
			{
				ch = raw.charAt(i);
				code = raw.charCodeAt(i);
				i++;
				if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90)
					|| (code >= 97 && code <= 122) || ch == "_" || ch == "-")
				{
					out += ch;
				}
				else if (ch == " ")
				{
					out += "_";
				};
			};
			while (out.indexOf("__") >= 0)
			{
				out = out.split("__").join("_");
			};
			if (out.length < 1)
			{
				out = "playlist";
			};
			return (out.toLowerCase());
		}

		private static function prettyId(trackId:String):String
		{
			var name:String;
			name = trackId || "";
			if (name.indexOf("bgm_") == 0)
			{
				name = name.substr(4);
			};
			return (name.split("_").join(" "));
		}

		private static function packsRoot():File
		{
			var dir:File;
			dir = File.applicationDirectory.resolvePath("expansions/songs/packs");
			return (new File(dir.nativePath));
		}
	}
}
