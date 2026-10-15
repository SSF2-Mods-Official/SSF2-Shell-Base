package
{
	import flash.filesystem.File;

	/**
	 * Canonical song folders under expansions/songs.
	 * Uploaded Songs: user mp3s (and files dropped in while the game is closed).
	 * Legacy Format: Pressor blobs — zlib-only, or zlib plus the garbage-int header.
	 */
	public class MusicSongLibrary
	{
		public static const UPLOADED_REL:String = "expansions/songs/Uploaded Songs";
		public static const LEGACY_REL:String = "expansions/songs/Legacy Format";
		public static const UNPACKED_REL:String = "expansions/songs/Legacy Format/.unpacked";
		private static const OLD_UPLOADS_REL:String = "data/ssf2mm/music_player/uploads";

		public static function uploadedDir():File
		{
			return (writableDir(UPLOADED_REL));
		}

		public static function legacyDir():File
		{
			return (writableDir(LEGACY_REL));
		}

		public static function destForUpload(trackId:String):File
		{
			var dir:File;
			var dest:File;
			dir = uploadedDir();
			if (!dir.exists)
			{
				dir.createDirectory();
			};
			dest = dir.resolvePath(trackId + ".mp3");
			return (new File(dest.nativePath));
		}

		/** Copy the old music_player/uploads folder into Uploaded Songs once. */
		public static function migrateOldUploads():void
		{
			var oldDir:File;
			var destDir:File;
			var list:Array;
			var i:int;
			var file:File;
			var dest:File;
			var name:String;
			try
			{
				oldDir = writableDir(OLD_UPLOADS_REL);
				if (!oldDir.exists)
				{
					return;
				};
				destDir = uploadedDir();
				if (!destDir.exists)
				{
					destDir.createDirectory();
				};
				list = oldDir.getDirectoryListing();
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
					if (shouldSkipName(name))
					{
						continue;
					};
					dest = new File(destDir.resolvePath(name).nativePath);
					if (!dest.exists)
					{
						file.copyTo(dest, false);
					};
				};
			}
			catch (err:*)
			{
				trace("[music_player] migrate uploads failed: " + err);
			};
		}

		/**
		 * Register files already sitting in Uploaded Songs.
		 * Non-mp3 files are transcoded in the background.
		 */
		public static function syncUploads(catalog:MusicCatalog, onChange:Function):void
		{
			var dir:File;
			var list:Array;
			var i:int;
			var file:File;
			var name:String;
			var tid:String;
			var seen:Object;
			var pending:Array;
			var ready:File;
			migrateOldUploads();
			dir = uploadedDir();
			if (!dir.exists)
			{
				dir.createDirectory();
			};
			seen = {};
			pending = [];
			try
			{
				list = dir.getDirectoryListing();
			}
			catch (listErr:*)
			{
				list = [];
			};
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
				if (shouldSkipName(name))
				{
					continue;
				};
				tid = idForUploadName(name);
				if (!tid || seen[tid])
				{
					continue;
				};
				seen[tid] = true;
				if (MusicUploadTranscode.isFlashMp3(file))
				{
					adopt(catalog, tid, file, titleFromName(name));
				}
				else
				{
					ready = destForUpload(tid);
					if (ready.exists && ready.nativePath != file.nativePath && MusicUploadTranscode.isFlashMp3(ready))
					{
						adopt(catalog, tid, ready, titleFromName(name));
					}
					else
					{
						pending.push({"id": tid, "file": file, "title": titleFromName(name)});
					};
				};
			};
			pumpTranscode(catalog, pending, onChange);
		}

		/** Unpack Legacy Format blobs into real SWFs. Returns track ids. */
		public static function syncLegacy(catalog:MusicCatalog):Array
		{
			var dir:File;
			var list:Array;
			var i:int;
			var file:File;
			var name:String;
			var tid:String;
			var ids:Array;
			var seen:Object;
			ids = [];
			seen = {};
			dir = legacyDir();
			if (!dir.exists)
			{
				return (ids);
			};
			try
			{
				list = dir.getDirectoryListing();
			}
			catch (listErr:*)
			{
				return (ids);
			};
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
				if (name.charAt(0) == "." || shouldSkipName(name))
				{
					continue;
				};
				tid = idForLegacyName(name);
				if (!tid || seen[tid])
				{
					continue;
				};
				// Pack-owned files — do not keep a parallel bgm_legacy_* entry.
				if (MusicPacks.canonicalTrackId(tid) != tid)
				{
					continue;
				};
				seen[tid] = true;
				ids.push(tid);
				if (catalog && !catalog.songMeta[tid])
				{
					catalog.songMeta[tid] = {
						"title": MusicCatalog.stripCredit(titleFromName(name)),
						"artist": "",
						"linkage": "",
						"durationMs": 0,
						"hydrated": false,
						"legacy": true,
						"swf": file.nativePath
					};
				}
				else if (catalog && catalog.songMeta[tid])
				{
					catalog.songMeta[tid].legacy = true;
					catalog.songMeta[tid].swf = file.nativePath;
				};
			};
			if (catalog)
			{
				catalog.legacyIds = ids;
				catalog.saveSongCache();
			};
			return (ids);
		}

		public static function swfFileFor(trackId:String):File
		{
			var file:File;
			if (!trackId)
			{
				return (null);
			};
			file = writableDir(UNPACKED_REL).resolvePath(trackId + ".swf");
			file = new File(file.nativePath);
			return (file.exists ? file : null);
		}

		public static function idForUploadName(name:String):String
		{
			return (idForName(name, "bgm_upload_"));
		}

		public static function idForLegacyName(name:String):String
		{
			return (idForName(name, "bgm_legacy_"));
		}

		public static function shouldSkipName(name:String):Boolean
		{
			if (!name)
			{
				return (true);
			};
			if (name.indexOf(".tmp.") >= 0 || name.indexOf(".src.") >= 0)
			{
				return (true);
			};
			if (name.length > 4 && name.substr(name.length - 4) == ".tmp")
			{
				return (true);
			};
			return (false);
		}

		private static function pumpTranscode(catalog:MusicCatalog, pending:Array, onChange:Function):void
		{
			var item:Object;
			var dest:File;
			if (!pending || pending.length < 1)
			{
				return;
			};
			item = pending.shift();
			dest = destForUpload(String(item.id));
			MusicUploadTranscode.ensureFlashMp3(item.file as File, dest, function (out:File):void
			{
				adopt(catalog, String(item.id), out, String(item.title || ""));
				if (onChange != null)
				{
					onChange();
				};
				pumpTranscode(catalog, pending, onChange);
			}, function (msg:String):void
			{
				trace("[music_player] folder convert failed: " + msg);
				pumpTranscode(catalog, pending, onChange);
			});
		}

		private static function adopt(catalog:MusicCatalog, trackId:String, file:File, title:String):void
		{
			var meta:Object;
			if (!catalog || !trackId || !file)
			{
				return;
			};
			meta = catalog.songMeta[trackId];
			if (!meta)
			{
				catalog.rememberLocalTrack(trackId, title, file.nativePath);
				return;
			};
			meta.file = file.nativePath;
			if (!meta.title || String(meta.title) == trackId)
			{
				meta.title = title || trackId;
			};
			meta.hydrated = true;
			catalog.saveSongCache();
		}

		private static function idForName(name:String, prefix:String):String
		{
			var base:String;
			var dot:int;
			var id:String;
			if (!name)
			{
				return ("");
			};
			dot = name.lastIndexOf(".");
			base = dot > 0 ? name.substring(0, dot) : name;
			if (base.indexOf(prefix) == 0)
			{
				return (sanitize(base));
			};
			id = sanitize(prefix + base.toLowerCase());
			if (id.length <= prefix.length)
			{
				return ("");
			};
			return (id);
		}

		private static function titleFromName(name:String):String
		{
			var dot:int;
			var base:String;
			dot = name ? name.lastIndexOf(".") : -1;
			base = dot > 0 ? name.substring(0, dot) : String(name || "");
			if (base.indexOf("bgm_upload_") == 0)
			{
				base = base.substr(11);
			};
			if (base.indexOf("bgm_legacy_") == 0)
			{
				base = base.substr(11);
			};
			return (base.split("_").join(" "));
		}

		private static function sanitize(raw:String):String
		{
			var out:String;
			var i:int;
			var code:int;
			out = "";
			i = 0;
			while (raw && i < raw.length)
			{
				code = raw.charCodeAt(i);
				if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90)
					|| (code >= 97 && code <= 122) || raw.charAt(i) == "_")
				{
					out += raw.charAt(i);
				}
				else
				{
					out += "_";
				};
				i++;
			};
			return (out);
		}

		private static function writableDir(rel:String):File
		{
			var dir:File;
			dir = File.applicationDirectory.resolvePath(rel);
			return (new File(dir.nativePath));
		}
	}
}
