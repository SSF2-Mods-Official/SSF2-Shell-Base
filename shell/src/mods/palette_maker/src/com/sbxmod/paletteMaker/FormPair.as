package com.sbxmod.paletteMaker
{
	/** Stock forms that save through the Zelda pair list. */
	public class FormPair
	{
		public static function opensPairList(statsName:String):Boolean
		{
			var name:String;
			name = statsName ? statsName.toLowerCase() : "";
			return (name == "zelda" || name == "sheik" || name == "bowser" || name == "gigabowser" || name == "giga_bowser");
		}

		/** Giga Bowser has no costume_data base. The pair Base tile is Giga 1. */
		public static function baseCostume(statsName:String):Object
		{
			var name:String;
			name = statsName ? statsName.toLowerCase() : "";
			if (name == "gigabowser" || name == "giga_bowser")
			{
				return GigaStockPalettes.costume(0);
			};
			return null;
		}
	}
}
