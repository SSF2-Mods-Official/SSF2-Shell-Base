package com.sbxmod.paletteMaker
{
	import flash.display.BitmapData;
	import flash.geom.ColorTransform;
	import flash.geom.Point;

	/** Swatch hover: every pixel except the hovered RGB is multiplied by 0.1. */
	public class HoverDim
	{
		private static var m_mask:BitmapData;
		private static var m_point:Point = new Point();
		private static var m_transform:ColorTransform = new ColorTransform(0.1, 0.1, 0.1, 1, 0, 0, 0, 0);
		private static const RGB:uint = 0x00FFFFFF;

		public static function paint(dest:BitmapData, bright:BitmapData, repl:uint, repl2:uint, restore:Boolean):void
		{
			var rect:*;
			if (!dest || !bright)
			{
				return;
			};
			rect = bright.rect;
			dest.copyPixels(bright, rect, m_point);
			dest.colorTransform(rect, m_transform);
			if (!restore)
			{
				return;
			};
			ensureMask(bright.width, bright.height);
			m_mask.fillRect(m_mask.rect, 0);
			m_mask.threshold(bright, rect, m_point, "==", repl, 0xFFFFFFFF, RGB, false);
			if ((repl2 & RGB) != (repl & RGB))
			{
				m_mask.threshold(bright, rect, m_point, "==", repl2, 0xFFFFFFFF, RGB, false);
			};
			dest.copyPixels(bright, rect, m_point, m_mask, m_point, true);
		}

		private static function ensureMask(w:int, h:int):void
		{
			if (m_mask && m_mask.width == w && m_mask.height == h)
			{
				return;
			};
			if (m_mask)
			{
				m_mask.dispose();
			};
			m_mask = new BitmapData(w, h, true, 0);
		}
	}
}
