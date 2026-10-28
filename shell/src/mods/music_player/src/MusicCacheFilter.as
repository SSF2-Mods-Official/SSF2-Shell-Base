package
{
	import flash.filesystem.File;

	/**
	 * Which songcache.json tracks survive a rebuild. Stock tracks come from list.json; anything else
	 * needs its own audio (pack `swf` or upload `file`), so an uninstalled pack drops out.
	 */
	public class MusicCacheFilter
	{
		/** A row with no sound file, no loaded library sound, and no pack audio is a removed song. */
		public static function listed(fileExists:Boolean, librarySound:Boolean, packAudio:Boolean):Boolean
		{
			return (fileExists || librarySound || packAudio);
		}

		public static function soundOnDisk(trackId:String):Boolean
		{
			var base:File;
			var i:int;
			var rel:Array;
			if (!trackId)
			{
				return (false);
			};
			rel = [
				"data/sound/" + trackId + ".swf",
				"data/sound/" + trackId + ".ssf",
				"data/music/" + trackId + ".swf",
				"data/music/" + trackId + ".ssf"
			];
			try
			{
				base = File.applicationDirectory;
			}
			catch (dirErr:*)
			{
				return (false);
			};
			i = 0;
			while (i < rel.length)
			{
				try
				{
					if (base.resolvePath(String(rel[i])).exists)
					{
						return (true);
					};
				}
				catch (fileErr:*)
				{
				};
				i++;
			};
			return (false);
		}

		public static function keep(meta:Object, stock:Boolean):Boolean
		{
			if (stock)
			{
				return (true);
			};
			if (!meta)
			{
				return (false);
			};
			return (sourceExists(meta.swf) || sourceExists(meta.file));
		}

		private static function sourceExists(path:*):Boolean
		{
			if (!path || String(path).length < 1)
			{
				return (false);
			};
			try
			{
				return (new File(String(path)).exists);
			}
			catch (err:*)
			{
			};
			return (false);
		}
	}
}
