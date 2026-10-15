package
{
	import ssf2mm.shared.GameBananaApi;

	/**
	 * Reads the SSF2 "Event" category on GameBanana (apiv11) and installs a chosen
	 * submission into expansions/events/.
	 */
	public class GameBananaClient extends GameBananaApi
	{
		public static const CATEGORY_ID:int = 49482;

		private static const USER_AGENT:String = "SSF2ModManager-EventExpansions/1.0";

		public function GameBananaClient(log:Function = null)
		{
			super(CATEGORY_ID, USER_AGENT, "expansions/events", "Event", log, "[event_expansions]");
		}
	}
}
