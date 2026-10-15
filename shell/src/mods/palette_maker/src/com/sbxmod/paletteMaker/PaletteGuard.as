package com.sbxmod.paletteMaker
{
	/** One game.log line when a critical step throws out of an engine callback or a frame/timer loop. */
	public class PaletteGuard
	{
		/** step -> last logged error text; a frame loop that keeps failing the same way logs once. */
		private static var s_last:Object = {};

		public static function fail(step:String, err:*):void
		{
			var text:String = String(err);
			if (s_last[step] === text)
			{
				return;
			};
			s_last[step] = text;
			try
			{
				Ssf2.gameLog("[palette_maker] " + step + " failed: " + text);
			}
			catch (logErr:*)
			{
				trace("[palette_maker] " + step + " failed: " + text);
			};
		}
	}
}
