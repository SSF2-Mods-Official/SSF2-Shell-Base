package com.sbxmod.paletteMaker
{
	import flash.display.Graphics;
	import ssf2mm.shared.LucideIcons;

	/** Palette Maker tool ids mapped to the shared Lucide icons. */
	public class LucideIconRenderer
	{
		public static function drawToolIcon(g:Graphics, toolId:String, boxSize:Number, color:uint = 0xFFFFFF):void
		{
			var cls:Class = resolveToolSvg(toolId);
			if (!cls)
			{
				g.lineStyle(1.2, color, 1, false, "normal", "round", "round");
				g.drawCircle(boxSize * 0.5, boxSize * 0.5, boxSize * 0.18);
				return;
			};
			drawEmbeddedSvg(g, cls, boxSize, color, 1.5);
		}

		private static function resolveToolSvg(toolId:String):Class
		{
			switch (toolId)
			{
				case "UD": return LucideIcons.UNDO_2;
				case "RD": return LucideIcons.REDO_2;
				case "DI": return LucideIcons.CONTRAST;
				case "FZ": return LucideIcons.SQUARE; // Freeze Character (pause square)
				case "SA": return LucideIcons.SQUARE_CHECK;
				case "DA": return LucideIcons.SQUARE_X;
				case "IS": return LucideIcons.FLIP_H2;
				case "RA": return LucideIcons.ROTATE_CCW;
				case "RB": return LucideIcons.SLIDERS; // Recolor to Base
				case "RO": return LucideIcons.ERASER; // Recolor to OG (identity)
				case "NG": return LucideIcons.FOLDER_PLUS;
				case "CS": return LucideIcons.PALETTE; // Color Settings
				case "ST": return LucideIcons.SETTINGS;
				case "IC": return LucideIcons.FILE_DOWN;
				case "EC": return LucideIcons.FILE_UP;
				case "CO": return LucideIcons.TYPE;
				case "RE": return LucideIcons.SLIDERS;
			};
			return null;
		}

		public static const PAUSE_TYPE:Class = LucideIcons.TYPE;
		public static const PAUSE_PENCIL:Class = LucideIcons.PENCIL;
		public static const PAUSE_ERASER:Class = LucideIcons.ERASER;
		public static const PAUSE_EYE_OFF:Class = LucideIcons.EYE_OFF;
		public static const PAUSE_PIPETTE:Class = LucideIcons.PIPETTE;
		public static const PAUSE_SQUARE:Class = LucideIcons.SQUARE;

		public static function drawEmbeddedSvg(g:Graphics, svgClass:Class, boxSize:Number, color:uint = 0xFFFFFF, pad:Number = 2):void
		{
			LucideIcons.drawEmbeddedSvg(g, svgClass, boxSize, color, pad);
		}
	}
}
