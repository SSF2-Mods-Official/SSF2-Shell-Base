package ssf2mm.shared
{
	import flash.display.BitmapData;
	import flash.geom.Rectangle;

	/**
	 * HSV color math and the hue strip / saturation-value square drawing used by
	 * the color pickers. h is degrees [0, 360), s and v are [0, 1].
	 */
	public class HsvWheel
	{
		/** {h, s, v} for the RGB bits of color; alpha is ignored. */
		public static function rgbToHsv(color:uint):Object
		{
			var r:Number = ((color >> 16) & 0xFF) / 255.0;
			var g:Number = ((color >> 8) & 0xFF) / 255.0;
			var b:Number = (color & 0xFF) / 255.0;
			var max:Number = Math.max(r, g, b);
			var min:Number = Math.min(r, g, b);
			var delta:Number = max - min;
			var h:Number = 0;
			var s:Number = (max == 0) ? 0 : delta / max;
			var v:Number = max;
			if (delta != 0)
			{
				if (max == r)
				{
					h = 60 * (((g - b) / delta) % 6);
				}
				else if (max == g)
				{
					h = 60 * (((b - r) / delta) + 2);
				}
				else
				{
					h = 60 * (((r - g) / delta) + 4);
				};
				if (h < 0)
				{
					h += 360;
				};
			};
			return {"h": h, "s": s, "v": v};
		}

		/** 0xAARRGGBB with alphaByte on top. h wraps; s and v are clamped. */
		public static function hsvToRgb(h:Number, s:Number, v:Number, alphaByte:uint = 0xFF):uint
		{
			var c:Number;
			var x:Number;
			var m:Number;
			var r2:Number = 0;
			var g2:Number = 0;
			var b2:Number = 0;
			var hh:Number;
			s = Math.max(0, Math.min(1, s));
			v = Math.max(0, Math.min(1, v));
			h = h % 360;
			if (h < 0)
			{
				h += 360;
			};
			c = v * s;
			hh = h / 60;
			x = c * (1 - Math.abs((hh % 2) - 1));
			m = v - c;
			if (hh >= 0 && hh < 1)
			{
				r2 = c; g2 = x; b2 = 0;
			}
			else if (hh < 2)
			{
				r2 = x; g2 = c; b2 = 0;
			}
			else if (hh < 3)
			{
				r2 = 0; g2 = c; b2 = x;
			}
			else if (hh < 4)
			{
				r2 = 0; g2 = x; b2 = c;
			}
			else if (hh < 5)
			{
				r2 = x; g2 = 0; b2 = c;
			}
			else
			{
				r2 = c; g2 = 0; b2 = x;
			};
			return ((alphaByte & 0xFF) << 24) |
				(Math.round((r2 + m) * 255) << 16) |
				(Math.round((g2 + m) * 255) << 8) |
				Math.round((b2 + m) * 255);
		}

		/** "#RRGGBB" for the RGB bits of color. */
		public static function formatHex(color:uint):String
		{
			var s:String = (color & 0x00FFFFFF).toString(16).toUpperCase();
			while (s.length < 6)
			{
				s = "0" + s;
			};
			return "#" + s;
		}

		/** 0xRRGGBB from "#RGB" / "#RRGGBB" (the '#' and whitespace are optional), or -1. */
		public static function parseHex(text:String):int
		{
			var s:String;
			if (!text)
			{
				return -1;
			};
			s = text.replace(/\s+/g, "");
			if (s.charAt(0) == "#")
			{
				s = s.substr(1);
			};
			s = s.toUpperCase();
			if (s.length == 3)
			{
				s = s.charAt(0) + s.charAt(0) + s.charAt(1) + s.charAt(1) + s.charAt(2) + s.charAt(2);
			};
			if (s.length != 6 || s.search(/^[0-9A-F]{6}$/) != 0)
			{
				return -1;
			};
			return int(uint("0x" + s));
		}

		/** Hue for a point localY pixels down a hue strip span pixels tall. */
		public static function hueAt(localY:Number, span:Number):Number
		{
			return clamp01(localY / span) * 360;
		}

		/** Saturation for a point localX pixels across a square span pixels wide. */
		public static function satAt(localX:Number, span:Number):Number
		{
			return clamp01(localX / span);
		}

		/** Value for a point localY pixels down a square span pixels tall (top is 1). */
		public static function valAt(localY:Number, span:Number):Number
		{
			return clamp01(1 - (localY / span));
		}

		/** Fills bd top to bottom with hue 0..360 at full s and v. */
		public static function drawHueStrip(bd:BitmapData):void
		{
			var y:int = 0;
			if (!bd)
			{
				return;
			};
			while (y < bd.height)
			{
				bd.fillRect(new Rectangle(0, y, bd.width, 1), hsvToRgb((y / bd.height) * 360, 1, 1, 0xFF) & 0x00FFFFFF);
				y++;
			};
		}

		/** Fills bd with saturation left to right and value top (1) to bottom (0) at hue. */
		public static function drawSvSquare(bd:BitmapData, hue:Number):void
		{
			var x:int;
			var y:int = 0;
			var v:Number;
			if (!bd)
			{
				return;
			};
			bd.lock();
			while (y < bd.height)
			{
				v = 1 - (y / Math.max(1, bd.height - 1));
				x = 0;
				while (x < bd.width)
				{
					bd.setPixel(x, y, hsvToRgb(hue, x / Math.max(1, bd.width - 1), v, 0xFF) & 0x00FFFFFF);
					x++;
				};
				y++;
			};
			bd.unlock();
		}

		private static function clamp01(n:Number):Number
		{
			return (n < 0 || isNaN(n)) ? 0 : (n > 1 ? 1 : n);
		}
	}
}
