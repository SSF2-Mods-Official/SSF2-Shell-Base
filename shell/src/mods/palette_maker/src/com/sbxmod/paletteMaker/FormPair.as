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
	}
}
