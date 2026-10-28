package com.sbxmod.paletteMaker
{
	/** Which linked form a unique-sprite linkage belongs to. */
	public class LinkedFormSprite
	{
		public static function isGigaLinkage(linkage:String):Boolean
		{
			var low:String;
			if (!linkage)
			{
				return false;
			};
			low = linkage.toLowerCase();
			return low.indexOf("gigabowser") >= 0 || low.indexOf("giga_bowser") >= 0 || low.indexOf("gbow_") == 0;
		}

		public static function isSheikLinkage(linkage:String):Boolean
		{
			var low:String;
			if (!linkage)
			{
				return false;
			};
			low = linkage.toLowerCase();
			return low == "sheik" || low.indexOf("sheik_") == 0 || low.indexOf("sdairland") == 0;
		}

		public static function isZeldaLinkage(linkage:String):Boolean
		{
			var low:String;
			if (!linkage)
			{
				return false;
			};
			low = linkage.toLowerCase();
			return low == "zelda" || low.indexOf("zelda_") == 0;
		}

		/** The partner portrait and a partner linkage highlight the partner swatch. */
		public static function hitUsesPartnerSwatch(partnerPortrait:Boolean, linkage:String, partnerName:String):Boolean
		{
			if (partnerPortrait)
			{
				return true;
			};
			if (!linkage || !partnerName)
			{
				return false;
			};
			return matchesForm(linkage, partnerName);
		}

		/** Giga Bowser linkages are not Bowser's. Sheik and Zelda stay on their own names. */
		public static function matchesForm(linkage:String, formName:String, extraIds:Array = null):Boolean
		{
			var low:String;
			var formLow:String;
			var i:int;
			var extra:String;
			if (!linkage || !formName)
			{
				return false;
			};
			low = linkage.toLowerCase();
			formLow = String(formName).toLowerCase();
			if (isGigaLinkage(low))
			{
				return formLow == "gigabowser" || formLow == "giga_bowser";
			};
			if (formLow == "gigabowser" || formLow == "giga_bowser")
			{
				return false;
			};
			if (isSheikLinkage(low))
			{
				return formLow == "sheik";
			};
			if (isZeldaLinkage(low))
			{
				return formLow == "zelda";
			};
			if (low == formLow || low.indexOf(formLow + "_") == 0)
			{
				return true;
			};
			if (!extraIds)
			{
				return false;
			};
			i = 0;
			while (i < extraIds.length)
			{
				extra = extraIds[i] ? String(extraIds[i]).toLowerCase() : "";
				if (extra && (extra == low || low.indexOf(extra + "_") == 0))
				{
					return true;
				};
				i++;
			};
			return false;
		}

		/** Partner sprites keep their own cover set so shared colors still show. */
		public static function coverSetId(linkage:String, partnerName:String):String
		{
			if (partnerName && matchesForm(linkage, partnerName))
			{
				return partnerName;
			};
			return "base";
		}

		/** Update a source key that is already in the block. Does not add keys. */
		public static function writeReplacementIfPresent(colors:Array, replacements:Array, source:uint, replacement:uint):Boolean
		{
			var i:int;
			var wrote:Boolean;
			if (!colors || !replacements)
			{
				return false;
			};
			wrote = false;
			i = 0;
			while (i < colors.length)
			{
				if (uint(colors[i]) == source)
				{
					while (replacements.length <= i)
					{
						replacements.push(uint(colors[replacements.length]));
					};
					replacements[i] = replacement;
					wrote = true;
				};
				i++;
			};
			return wrote;
		}

		/** Which form's source colors are still in a bitmap after the active palette was applied. */
		public static function formForRemainingColors(hasCurrent:Boolean, hasPartner:Boolean):String
		{
			if (hasPartner)
			{
				return "partner";
			};
			if (hasCurrent)
			{
				return "current";
			};
			return "";
		}
	}
}
