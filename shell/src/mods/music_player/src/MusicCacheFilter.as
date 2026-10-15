package
{
	import flash.filesystem.File;

	/**
	 * Which songcache.json tracks survive a rebuild. Stock tracks come from list.json; anything else
	 * needs its own audio (pack `swf` or upload `file`), so an uninstalled pack drops out.
	 */
	public class MusicCacheFilter
	{
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
