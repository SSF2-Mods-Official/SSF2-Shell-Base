package
{
	import com.mcleodgaming.ssf2.util.PaletteDeep;
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/** PaletteDeep.combinePaletteBlocksStock keeps first-seen color order, drops duplicate colors, and lets the later replacement win. */
	public class PaletteDeepFixture extends Sprite
	{
		public function PaletteDeepFixture()
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
			// b repeats a's colors out of order and adds one new color.
			if ((fail = combineIs("overlap out of order",
				block([0xFF000001, 0xFF000002, 0xFF000003], [10, 20, 30]),
				block([0xFF000003, 0xFF000001, 0xFF000004], [33, 11, 44]),
				[0xFF000001, 0xFF000002, 0xFF000003, 0xFF000004], [11, 20, 33, 44])))
			{
				return fail;
			};
			// Duplicates inside one block, out of order: the color keeps its first slot, the last replacement wins.
			if ((fail = combineIs("duplicates within a block",
				block([0xFF000005, 0xFF000006, 0xFF000005, 0xFF000007, 0xFF000006], [50, 60, 55, 70, 66]),
				block([0xFF000007, 0xFF000005], [77, 555]),
				[0xFF000005, 0xFF000006, 0xFF000007], [555, 66, 77])))
			{
				return fail;
			};
			if ((fail = combineIs("null first", null, block([0xFF0000AA, 0xFF0000BB], [1, 2]),
				[0xFF0000AA, 0xFF0000BB], [1, 2])))
			{
				return fail;
			};
			if ((fail = combineIs("bad second", block([0xFF0000AA], [1]), {"colors": "x"},
				[0xFF0000AA], [1])))
			{
				return fail;
			};
			if ((fail = combineIs("length mismatch", block([0xFF000001, 0xFF000002, 0xFF000003], [9]), null,
				[0xFF000001], [9])))
			{
				return fail;
			};
			if ((fail = combineIs("both empty", null, null, [], [])))
			{
				return fail;
			};
			return "";
		}

		private static function block(colors:Array, replacements:Array):Object
		{
			return {"colors": colors, "replacements": replacements};
		}

		private static function combineIs(what:String, a:Object, b:Object, colors:Array, replacements:Array):String
		{
			var got:Object = PaletteDeep.combinePaletteBlocksStock(a, b);
			if (!got || !sameUints(got.colors as Array, colors) || !sameUints(got.replacements as Array, replacements))
			{
				return what + " got colors=" + hexList(got ? got.colors as Array : null)
					+ " replacements=" + (got ? String(got.replacements) : "null");
			};
			return "";
		}

		private static function sameUints(got:Array, want:Array):Boolean
		{
			var i:int;
			if (!got || got.length != want.length)
			{
				return false;
			};
			for (i = 0; i < want.length; i++)
			{
				if (uint(got[i]) != uint(want[i]))
				{
					return false;
				};
			};
			return true;
		}

		private static function hexList(list:Array):String
		{
			var out:Array = [];
			var v:*;
			if (!list)
			{
				return "null";
			};
			for each (v in list)
			{
				out.push("0x" + uint(v).toString(16));
			};
			return "[" + out.join(",") + "]";
		}

		private function writeResult(failure:String):void
		{
			var file:File = File.applicationStorageDirectory.resolvePath("palette-deep-fixture.txt");
			var stream:FileStream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(failure ? ("FAIL " + failure) : "OK");
			stream.close();
		}
	}
}
