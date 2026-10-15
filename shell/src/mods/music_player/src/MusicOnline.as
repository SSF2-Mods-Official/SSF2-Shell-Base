package
{
	import ssf2mm.shared.GameBananaApi;

	/**
	 * Reads the SSF2 music pack category on GameBanana (apiv11) and installs a chosen
	 * submission into expansions/songs/packs/.
	 */
	public class MusicOnline extends GameBananaApi
	{
		public static const GAME_ID:int = 5789;
		public static const CATEGORY_ID:int = 49485;
		public static const CATEGORY_URL:String = "https://gamebanana.com/mods/cats/49485";

		private static const USER_AGENT:String = "SSF2ModManager-MusicPacks/1.0";

		public function MusicOnline(log:Function = null)
		{
			super(CATEGORY_ID, USER_AGENT, "expansions/songs/packs", "Music Pack", log, "[music_player]");
		}
	}
}
