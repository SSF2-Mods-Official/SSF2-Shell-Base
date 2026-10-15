package
{
	import flash.system.System;
	import ssf2mm.shared.EngineRefs;

	/** Lightweight memory snapshots for jukebox skip / browse leaks. */
	public class MusicMem
	{
		private static var s_last:Number = 0;

		public static function snap(tag:String, extra:String = ""):void
		{
			var total:Number;
			var priv:Number;
			var delta:Number;
			var msg:String;
			try
			{
				total = Number(System.totalMemory);
				priv = 0;
				try
				{
					priv = Number(System["privateMemory"]);
				}
				catch (pErr:*)
				{
				};
				delta = s_last > 0 ? (total - s_last) : 0;
				s_last = total;
			msg = "[music_player][mem] " + tag
				+ " flashMb=" + int(total / 1048576)
				+ " dFlash=" + (delta >= 0 ? "+" : "") + int(delta / 1048576);
			if (priv > 0)
			{
				msg += " privateMb=" + int(priv / 1048576);
			};
				if (extra)
				{
					msg += " " + extra;
				};
				print(msg);
			}
			catch (err:*)
			{
			};
		}

		private static function print(msg:String):void
		{
			var Api:*;
			var Host:*;
			try
			{
				Api = EngineRefs.ssf2("api.SSF2API");
				if (Api && Api["print"] is Function)
				{
					Api["print"](msg);
					return;
				};
			}
			catch (apiErr:*)
			{
			};
			try
			{
				Host = EngineRefs.ssf2("modhost.ModHost");
				if (Host && Host["appendGameLog"] is Function)
				{
					Host["appendGameLog"](msg);
					return;
				};
			}
			catch (hostErr:*)
			{
			};
			trace(msg);
		}
	}
}
