package ssf2mm.shared
{
	import flash.utils.getDefinitionByName;

	/**
	 * Engine classes by name, cached. Mods compile without the engine SWCs, so
	 * every engine type is looked up at run time. Each mod SWF gets its own copy
	 * of this class (ModHost loads each mod into a child ApplicationDomain).
	 */
	public class EngineRefs
	{
		private static var s_classes:Object = {};

		/** The class, or null when the engine does not define it. Never throws. */
		public static function cls(name:String):*
		{
			var c:* = s_classes[name];
			if (c != null)
			{
				return c;
			};
			try
			{
				c = getDefinitionByName(name);
			}
			catch (err:*)
			{
				c = null;
			};
			if (c != null)
			{
				s_classes[name] = c;
			};
			return c;
		}

		/** cls("com.mcleodgaming.ssf2." + rel). */
		public static function ssf2(rel:String):*
		{
			return cls("com.mcleodgaming.ssf2." + rel);
		}

		/** One game.log line through ModHost.appendGameLog. Never throws. */
		public static function gameLog(line:String):void
		{
			try
			{
				ModHost.appendGameLog(line);
			}
			catch (err:*)
			{
			};
		}

		public static function get Main():*
		{
			return ssf2("Main");
		}

		public static function get ModHost():*
		{
			return ssf2("modhost.ModHost");
		}

		public static function get ModHooks():*
		{
			return ssf2("modhost.ModHooks");
		}

		public static function get ModPatches():*
		{
			return ssf2("modhost.ModPatches");
		}

		public static function get SaveData():*
		{
			return ssf2("util.SaveData");
		}

		public static function get Utils():*
		{
			return ssf2("util.Utils");
		}

		public static function get ResourceManager():*
		{
			return ssf2("util.ResourceManager");
		}

		public static function get MenuController():*
		{
			return ssf2("controllers.MenuController");
		}

		public static function get GameController():*
		{
			return ssf2("controllers.GameController");
		}

		public static function get SoundQueue():*
		{
			return ssf2("audio.SoundQueue");
		}

		public static function get MultiplayerManager():*
		{
			return ssf2("net.MultiplayerManager");
		}

		public static function get GameLog():*
		{
			return ssf2("util.GameLog");
		}
	}
}
