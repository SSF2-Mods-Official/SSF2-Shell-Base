package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	import ssf2mm.shared.StageBackgroundGif;
	import ssf2mm.shared.StageBackgroundPick;

	/** StageBackgroundPick.resolve and a 1x1 red GIF frame. */
	public class StageBackgroundPickFixture extends Sprite
	{
		public function StageBackgroundPickFixture()
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
			var catalog:Object;
			var row:Object;
			var bytes:ByteArray;
			var pixel:uint;
			catalog = {
				"sunset": {"defaultStage": "battlefield", "asset": "C:/bg/background.png"}
			};
			row = StageBackgroundPick.resolve("sunset", catalog);
			if (!row)
			{
				return ("resolve known id was null");
			};
			if (row.defaultStage != "battlefield")
			{
				return ("defaultStage got " + row.defaultStage);
			};
			if (row.asset != "C:/bg/background.png")
			{
				return ("asset got " + row.asset);
			};
			if (StageBackgroundPick.resolve("missing", catalog) != null)
			{
				return ("resolve unknown id was not null");
			};
			if (StageBackgroundPick.resolve("", catalog) != null)
			{
				return ("resolve empty id was not null");
			};
			if (StageBackgroundPick.resolve("sunset", null) != null)
			{
				return ("resolve null catalog was not null");
			};
			bytes = new ByteArray();
			bytes.writeByte(0x47); bytes.writeByte(0x49); bytes.writeByte(0x46); bytes.writeByte(0x38); bytes.writeByte(0x39); bytes.writeByte(0x61);
			bytes.writeByte(0x01); bytes.writeByte(0x00); bytes.writeByte(0x01); bytes.writeByte(0x00); bytes.writeByte(0x80); bytes.writeByte(0x00); bytes.writeByte(0x00);
			bytes.writeByte(0xFF); bytes.writeByte(0x00); bytes.writeByte(0x00); bytes.writeByte(0x00); bytes.writeByte(0x00); bytes.writeByte(0x00);
			bytes.writeByte(0x21); bytes.writeByte(0xF9); bytes.writeByte(0x04); bytes.writeByte(0x00); bytes.writeByte(0x00); bytes.writeByte(0x00); bytes.writeByte(0x00); bytes.writeByte(0x00);
			bytes.writeByte(0x2C); bytes.writeByte(0x00); bytes.writeByte(0x00); bytes.writeByte(0x00); bytes.writeByte(0x00);
			bytes.writeByte(0x01); bytes.writeByte(0x00); bytes.writeByte(0x01); bytes.writeByte(0x00); bytes.writeByte(0x00);
			bytes.writeByte(0x02); bytes.writeByte(0x02); bytes.writeByte(0x44); bytes.writeByte(0x01); bytes.writeByte(0x00);
			bytes.writeByte(0x3B);
			pixel = StageBackgroundGif.firstPixel(bytes);
			if (pixel != 0xFFFF0000)
			{
				return ("gif pixel got " + pixel.toString(16));
			};
			return ("");
		}

		private function writeResult(failure:String):void
		{
			var file:File;
			var stream:FileStream;
			file = File.applicationStorageDirectory.resolvePath("stage-background-pick-fixture.txt");
			stream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(failure ? ("FAIL " + failure) : "OK");
			stream.close();
		}
	}
}
