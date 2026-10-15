package com.sbxmod.paletteMaker
{
	/**
	 * Online costumes are a plain index into stock + Color Vault catalog + locally made costumes.
	 * Stock and catalog entries match on every PC; a remote player's local costume does not exist here,
	 * so it shows as base (-1) instead of this player's own local costume at that index.
	 */
	public class CostumeNetIndex
	{
		/**
		 * Merged-list position ResourceManager.getCostume(name, null, costume) reads:
		 * team entries skipped, the base entry skipped for 0 and up. -1 when no entry matches.
		 */
		public static function entryPosition(list:Array, costume:int):int
		{
			var i:int;
			var count:int = 0;
			var entry:Object;
			if (!list || costume < 0)
			{
				return -1;
			};
			i = 0;
			while (i < list.length)
			{
				entry = list[i] as Object;
				if (entry && !entry["team"] && !entry["base"])
				{
					if (count == costume)
					{
						return i;
					};
					count++;
				};
				i++;
			};
			return -1;
		}

		/** Costume index to use for this player. */
		public static function resolve(costume:int, list:Array, stockLength:int, onlineCount:int, isLocal:Boolean):int
		{
			var pos:int;
			if (isLocal || costume < 0)
			{
				return costume;
			};
			pos = entryPosition(list, costume);
			if (pos >= stockLength && pos - stockLength >= onlineCount)
			{
				return -1;
			};
			return costume;
		}
	}
}
