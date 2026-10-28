package ssf2mm.shared
{
	import flash.filesystem.File;

	/**
	 * The player's own data (controller profiles, playlists, menu music, song cache) lives in
	 * expansions/user so it moves with the expansions folder. Older builds kept it in
	 * data/ssf2mm/state; reads fall back there until the next save writes the new copy.
	 */
	public class UserStateFile
	{
		public static const USER_DIR:String = "expansions/user/";
		public static const LEGACY_DIR:String = "data/ssf2mm/state/";

		public static function writeFile(name:String, appDir:File = null):File
		{
			return (resolve(USER_DIR + name, appDir));
		}

		public static function readFile(name:String, appDir:File = null):File
		{
			var user:File = writeFile(name, appDir);
			var legacy:File;
			if (user && user.exists)
			{
				return (user);
			};
			legacy = resolve(LEGACY_DIR + name, appDir);
			return (legacy && legacy.exists ? legacy : user);
		}

		private static function resolve(rel:String, appDir:File):File
		{
			try
			{
				return (new File((appDir || File.applicationDirectory).resolvePath(rel).nativePath));
			}
			catch (err:*)
			{
			};
			return (null);
		}
	}
}
