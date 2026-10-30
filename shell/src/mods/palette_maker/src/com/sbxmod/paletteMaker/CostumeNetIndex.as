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

		/**
		 * Partner file slot that shares the opened costume's game index.
		 * Game index is catalogSlotOrigin plus the file index. -1 is a builtin alt, not a file slot.
		 */
		public static function partnerFileIndex(openedFileIndex:int, openedOrigin:int, partnerOrigin:int):int
		{
			if (openedFileIndex < 0)
			{
				return -1;
			};
			return openedFileIndex + openedOrigin - partnerOrigin;
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

		/**
		 * Color Vault merge drops a repeated info name. A pairBase slot shares the name Base
		 * with every other empty pair slot, and each of those slots stays.
		 */
		/** An empty pairBase slot is a no-recolor. It still needs the stock base palette. */
		public static function pairBaseNeedsRecolor(entry:Object):Boolean
		{
			var colors:Array;
			if (!entry || entry.pairBase != true)
			{
				return false;
			};
			colors = (entry.paletteSwap && entry.paletteSwap.colors is Array) ? entry.paletteSwap.colors as Array : null;
			return !colors || colors.length == 0;
		}

		/** Copy the stock base costume's blocks onto an empty pairBase slot. */
		public static function assignPairBaseRecolor(entry:Object, baseCostume:Object):Boolean
		{
			var block:Object;
			var pa:Object;
			if (!pairBaseNeedsRecolor(entry) || !baseCostume)
			{
				return false;
			};
			block = baseCostume.paletteSwap;
			if (!block || !(block.colors is Array) || (block.colors as Array).length == 0)
			{
				return false;
			};
			pa = baseCostume.paletteSwapPA ? baseCostume.paletteSwapPA : block;
			entry.paletteSwap = {
				colors: (block.colors as Array).concat(),
				replacements: (block.replacements is Array) ? (block.replacements as Array).concat() : []
			};
			entry.paletteSwapPA = {
				colors: (pa.colors is Array) ? (pa.colors as Array).concat() : [],
				replacements: (pa.replacements is Array) ? (pa.replacements as Array).concat() : []
			};
			return true;
		}

		public static function shouldKeepVaultEntry(entry:Object, key:String, seenKeys:Object):Boolean
		{
			if (entry && entry.pairBase == true)
			{
				return true;
			};
			if (!key || (seenKeys && seenKeys[key]))
			{
				return false;
			};
			if (seenKeys)
			{
				seenKeys[key] = true;
			};
			return true;
		}
	}
}
