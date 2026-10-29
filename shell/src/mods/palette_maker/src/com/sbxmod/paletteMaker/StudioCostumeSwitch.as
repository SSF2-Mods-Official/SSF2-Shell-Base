package com.sbxmod.paletteMaker
{
	/**
	 * Locker costume switch order. The fighter must hit no-recolor before the
	 * next costume's pairs paint, or cached art keeps the previous recolor.
	 * Clearing swatch selection after the pick must suppress membership sync,
	 * or an active group empties and orphan colors revert to the base costume.
	 */
	public class StudioCostumeSwitch
	{
		public static const PHASE_NO_RECOLOR:String = "no_recolor";
		public static const PHASE_APPLY_COSTUME:String = "apply_costume";

		/** Phases in the order `_onClickContainer` runs them. */
		public static function phases():Array
		{
			return [PHASE_NO_RECOLOR, PHASE_APPLY_COSTUME];
		}

		/** True when identity must paint before the new costume index is set. */
		public static function paintsIdentityBeforeCostumeIndex():Boolean
		{
			return true;
		}

		/**
		 * Locker pick calls ColorSquare.deselectAll. That must run under
		 * suppressSelectionSideEffects so syncActiveGroupMembership does not
		 * strip the active group and revert orphans to baseCostumeData.
		 */
		public static function suppressesSelectionOnDeselect():Boolean
		{
			return true;
		}

		/** Locker pick clears activeGroup editing; group chips stay in the row. */
		public static function deselectsActiveGroupsOnPick():Boolean
		{
			return true;
		}

		/**
		 * Simulate the data half of an identity reset, then apply costume pairs.
		 * Returns the final replacements for `colors` (same length).
		 */
		public static function applyAfterNoRecolor(colors:Array, identityReplacements:Array, costumeReplacements:Array):Array
		{
			var out:Array;
			var i:int;
			if (!colors)
			{
				return [];
			};
			out = [];
			i = 0;
			while (i < colors.length)
			{
				// Phase no_recolor: each base maps to itself (or supplied identity).
				if (identityReplacements && i < identityReplacements.length)
				{
					out.push(uint(identityReplacements[i]));
				}
				else
				{
					out.push(uint(colors[i]));
				};
				i++;
			};
			i = 0;
			while (i < colors.length)
			{
				// Phase apply_costume: costume pairs overwrite.
				if (costumeReplacements && i < costumeReplacements.length)
				{
					out[i] = uint(costumeReplacements[i]);
				};
				i++;
			};
			return out;
		}
	}
}
