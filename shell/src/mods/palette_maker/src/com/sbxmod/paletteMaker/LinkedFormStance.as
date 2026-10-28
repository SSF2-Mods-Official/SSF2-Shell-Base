package com.sbxmod.paletteMaker
{
	import flash.display.MovieClip;

	/** Match and studio: the other Zelda/Sheik body keeps that form's costume. */
	public class LinkedFormStance
	{
		private static var liveBlock:Object = null;
		private static var loggedKey:String = "";

		public static function setLiveBlock(block:Object):void
		{
			liveBlock = block;
		}

		public static function paint(ctx:Object):void
		{
			var statsName:String;
			var character:*;
			var partner:String;
			var slot:int;
			var other:Object;
			var block:Object;
			var root:MovieClip;
			var painted:int;
			var key:String;
			if (!ctx)
			{
				return;
			};
			statsName = ctx.statsName ? String(ctx.statsName) : "";
			if (!PaletteMakerUtils.isLinkedFormPair(statsName))
			{
				return;
			};
			partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
			character = ctx.character;
			if (!partner || !character)
			{
				return;
			};
			block = liveBlock;
			slot = -1;
			if (!block)
			{
				try
				{
					slot = int(character.CostumeID);
				}
				catch (slotErr:*)
				{
				};
				try
				{
					other = Ssf2.ResourceManager.getCostume(partner, null, slot);
				}
				catch (costumeErr:*)
				{
					other = null;
				};
				block = other ? other.paletteSwap : null;
			};
			try
			{
				root = character.MC as MovieClip;
			}
			catch (mcErr:*)
			{
				root = null;
			};
			if (!root)
			{
				return;
			};
			painted = LinkedFormPaint.applyBlock(root, block);
			key = statsName + ":" + slot + ":" + (liveBlock ? "live" : "file");
			if (key != loggedKey)
			{
				loggedKey = key;
				Ssf2.gameLog("[Palette Maker] stance form=" + statsName + " partner=" + partner + " painted=" + painted + " slot=" + slot);
			};
		}
	}
}
