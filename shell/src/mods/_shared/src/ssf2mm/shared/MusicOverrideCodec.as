package ssf2mm.shared
{
	/**
	 * LevelData.musicOverride is the only host-chosen string vanilla sends to every online player,
	 * so it carries the host's camera background too: "trackId|bg=stageId".
	 * A value without "|" is a plain track id (offline values, old replays, vanilla).
	 */
	public class MusicOverrideCodec
	{
		public static const BG_KEY:String = "bg";

		/** {track, bg}; either may be "". */
		public static function decode(raw:*):Object
		{
			var out:Object = {"track": "", "bg": ""};
			var s:String = clean(raw);
			var parts:Array;
			var i:int;
			var eq:int;
			if (!s)
			{
				return out;
			};
			parts = s.split("|");
			out.track = String(parts[0]);
			i = 1;
			while (i < parts.length)
			{
				eq = String(parts[i]).indexOf("=");
				if (eq > 0 && String(parts[i]).substr(0, eq) == BG_KEY)
				{
					out.bg = String(parts[i]).substr(eq + 1);
				};
				i++;
			};
			return out;
		}

		/** Plain track when bg is empty; null when both are empty. */
		public static function encode(track:*, bg:*):String
		{
			var t:String = clean(track);
			var b:String = clean(bg);
			if (!b)
			{
				return t ? t : null;
			};
			return t + "|" + BG_KEY + "=" + b;
		}

		public static function withTrack(raw:*, track:*):String
		{
			return encode(track, decode(raw).bg);
		}

		public static function withBg(raw:*, bg:*):String
		{
			return encode(decode(raw).track, bg);
		}

		private static function clean(v:*):String
		{
			var s:String;
			if (v == null)
			{
				return "";
			};
			s = String(v);
			return (s == "null" || s == "undefined") ? "" : s;
		}
	}
}
