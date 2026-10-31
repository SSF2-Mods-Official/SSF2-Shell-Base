package ssf2mm.shared
{
	import flash.filesystem.File;

	/**
	 * The player's own data (controller profiles, playlists, menu music, song cache) lives in
	 * expansions/user. Nothing is read from or written under data/.
	 */
	public class UserStateFile
	{
		public static const USER_DIR:String = "expansions/user/";

		public static function writeFile(name:String, appDir:File = null):File
		{
			return (resolve(USER_DIR + name, appDir));
		}

		public static function readFile(name:String, appDir:File = null):File
		{
			return (writeFile(name, appDir));
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
