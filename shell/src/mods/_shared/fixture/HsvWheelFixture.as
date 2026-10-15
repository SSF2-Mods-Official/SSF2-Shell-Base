package
{
	import flash.desktop.NativeApplication;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ssf2mm.shared.HsvWheel;

	/** HsvWheel: primaries, grays, hue wrap, hex parse/format, point mapping, and the strip/square pixels. */
	public class HsvWheelFixture extends Sprite
	{
		public function HsvWheelFixture()
		{
			addEventListener(Event.ADDED_TO_STAGE, onStage);
		}

		private function onStage(e:Event):void
		{
			var failure:String;
			removeEventListener(Event.ADDED_TO_STAGE, onStage);
			try
			{
				failure = check();
			}
			catch (err:*)
			{
				failure = "threw " + err;
			};
			trace(failure ? ("FIXTURE FAIL " + failure) : "FIXTURE OK");
			try
			{
				writeResult(failure);
			}
			catch (writeErr:*)
			{
				trace("FIXTURE write " + writeErr);
			};
			NativeApplication.nativeApplication.exit(failure ? 1 : 0);
		}

		private function check():String
		{
			var fail:String;
			var colors:Array = [0xFF0000, 0x00FF00, 0x0000FF, 0xFFFFFF, 0x000000, 0x808080,
				0xFF8000, 0x123456, 0xABCDEF, 0x7F7F80, 0x010203, 0xFEFDFC];
			var c:uint;
			var hsv:Object;
			var bd:BitmapData;
			if ((fail = hsvIs(0xFF0000, 0, 1, 1)) || (fail = hsvIs(0x00FF00, 120, 1, 1))
				|| (fail = hsvIs(0x0000FF, 240, 1, 1)) || (fail = hsvIs(0xFFFFFF, 0, 0, 1))
				|| (fail = hsvIs(0x000000, 0, 0, 0)) || (fail = hsvIs(0x808080, 0, 0, 128 / 255)))
			{
				return fail;
			};
			if ((fail = rgbIs("red", HsvWheel.hsvToRgb(0, 1, 1, 0), 0xFF0000))
				|| (fail = rgbIs("green", HsvWheel.hsvToRgb(120, 1, 1, 0), 0x00FF00))
				|| (fail = rgbIs("blue", HsvWheel.hsvToRgb(240, 1, 1, 0), 0x0000FF))
				|| (fail = rgbIs("white", HsvWheel.hsvToRgb(77, 0, 1, 0), 0xFFFFFF))
				|| (fail = rgbIs("black", HsvWheel.hsvToRgb(200, 1, 0, 0), 0x000000))
				|| (fail = rgbIs("gray", HsvWheel.hsvToRgb(0, 0, 128 / 255, 0), 0x808080))
				|| (fail = rgbIs("hue 360", HsvWheel.hsvToRgb(360, 1, 1, 0), 0xFF0000))
				|| (fail = rgbIs("hue 480", HsvWheel.hsvToRgb(480, 1, 1, 0), 0x00FF00))
				|| (fail = rgbIs("hue -120", HsvWheel.hsvToRgb(-120, 1, 1, 0), 0x0000FF))
				|| (fail = rgbIs("hue 359.999", HsvWheel.hsvToRgb(359.999, 1, 1, 0), 0xFF0000))
				|| (fail = rgbIs("default alpha", HsvWheel.hsvToRgb(0, 1, 1), 0xFFFF0000))
				|| (fail = rgbIs("s/v clamp", HsvWheel.hsvToRgb(0, 2, 5, 0), 0xFF0000)))
			{
				return fail;
			};
			for each (c in colors)
			{
				hsv = HsvWheel.rgbToHsv(0xFF000000 | c);
				if ((fail = rgbIs("round trip " + HsvWheel.formatHex(c), HsvWheel.hsvToRgb(hsv.h, hsv.s, hsv.v, 0), c)))
				{
					return fail;
				};
				if (HsvWheel.parseHex(HsvWheel.formatHex(c)) != int(c))
				{
					return "hex round trip " + HsvWheel.formatHex(c);
				};
			};
			if ((fail = hexIs("#FF8000", 0xFF8000)) || (fail = hexIs("ff8000", 0xFF8000))
				|| (fail = hexIs("#abc", 0xAABBCC)) || (fail = hexIs("ABC", 0xAABBCC))
				|| (fail = hexIs(" #12 34 56 ", 0x123456)) || (fail = hexIs("#000000", 0))
				|| (fail = hexIs("#GG0000", -1)) || (fail = hexIs("#1234", -1))
				|| (fail = hexIs("##123456", -1)) || (fail = hexIs("", -1)) || (fail = hexIs(null, -1)))
			{
				return fail;
			};
			if (HsvWheel.formatHex(0xFF00FF00) != "#00FF00" || HsvWheel.formatHex(0xA) != "#00000A")
			{
				return "formatHex " + HsvWheel.formatHex(0xFF00FF00) + " " + HsvWheel.formatHex(0xA);
			};
			if (HsvWheel.hueAt(70, 140) != 180 || HsvWheel.hueAt(-5, 140) != 0 || HsvWheel.hueAt(500, 140) != 360
				|| HsvWheel.satAt(200, 140) != 1 || HsvWheel.satAt(35, 140) != 0.25
				|| HsvWheel.valAt(0, 140) != 1 || HsvWheel.valAt(140, 140) != 0 || HsvWheel.valAt(NaN, 140) != 0)
			{
				return "point mapping";
			};
			bd = new BitmapData(2, 6, false, 0x123456);
			HsvWheel.drawHueStrip(bd);
			if ((fail = rgbIs("strip top", bd.getPixel(1, 0), 0xFF0000)) || (fail = rgbIs("strip y2", bd.getPixel(0, 2), 0x00FF00))
				|| (fail = rgbIs("strip y4", bd.getPixel(1, 4), 0x0000FF)))
			{
				return fail;
			};
			bd = new BitmapData(3, 3, false, 0x123456);
			HsvWheel.drawSvSquare(bd, 120);
			if ((fail = rgbIs("sv top-left", bd.getPixel(0, 0), 0xFFFFFF)) || (fail = rgbIs("sv top-right", bd.getPixel(2, 0), 0x00FF00))
				|| (fail = rgbIs("sv bottom-left", bd.getPixel(0, 2), 0x000000)) || (fail = rgbIs("sv bottom-right", bd.getPixel(2, 2), 0x000000)))
			{
				return fail;
			};
			return "";
		}

		private static function hsvIs(color:uint, h:Number, s:Number, v:Number):String
		{
			var hsv:Object = HsvWheel.rgbToHsv(color);
			if (Math.abs(hsv.h - h) > 1e-9 || Math.abs(hsv.s - s) > 1e-9 || Math.abs(hsv.v - v) > 1e-9)
			{
				return "rgbToHsv " + HsvWheel.formatHex(color) + " = " + hsv.h + "," + hsv.s + "," + hsv.v;
			};
			return "";
		}

		private static function rgbIs(what:String, got:uint, want:uint):String
		{
			return got == want ? "" : (what + " got 0x" + got.toString(16) + " want 0x" + want.toString(16));
		}

		private static function hexIs(text:String, want:int):String
		{
			var got:int = HsvWheel.parseHex(text);
			return got == want ? "" : ("parseHex " + text + " got " + got + " want " + want);
		}

		private function writeResult(failure:String):void
		{
			var file:File = File.applicationStorageDirectory.resolvePath("hsv-wheel-fixture.txt");
			var stream:FileStream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(failure ? ("FAIL " + failure) : "OK");
			stream.close();
		}
	}
}
