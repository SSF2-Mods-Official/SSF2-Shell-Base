package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	public class SneakFixture extends Sprite
	{
		public function SneakFixture()
		{
			var lines:Array = [];
			lines.push(expect("plain", SwfGuard.reasons(text("FWS....URLLoader....")), "URLLoader"));
			lines.push(expect("split", SwfGuard.reasons(bytesOf("FWS....URL\x00\x00Loader....")), "URLLoader"));
			lines.push(expect("file", SwfGuard.reasons(text("FWS new FileStream()")), "FileStream"));
			lines.push(expect("lookup", SwfGuard.reasons(text("FWS getDefinitionByName")), "getDefinitionByName"));
			lines.push(expect("chars", SwfGuard.reasons(text("FWS String.fromCharCode(70)")), "fromCharCode"));
			lines.push(expect("garbage", SwfGuard.reasons(text("not-a-swf-file!!")), "unreadable"));
			lines.push(expect("clean", SwfGuard.reasons(text("FWS com.mcleodgaming.ssf2.Main")), ""));
			lines.push(expect("dotdot", SwfGuard.pathAllowed("../secrets.txt") ? "allowed" : "refused", "refused"));
			lines.push(expect("drive", SwfGuard.pathAllowed("C:/Users/me/note.txt") ? "allowed" : "refused", "refused"));
			lines.push(expect("inside", SwfGuard.pathAllowed("notes/readme.txt") ? "allowed" : "refused", "allowed"));
			var bad:int = 0;
			var i:int = 0;
			while (i < lines.length)
			{
				if (String(lines[i]).indexOf("FAIL") == 0)
				{
					bad++;
				};
				i++;
			};
			var report:String = (bad == 0 ? "OK" : "FAIL") + "\n" + lines.join("\n");
			var stream:FileStream = new FileStream();
			stream.open(File.applicationStorageDirectory.resolvePath("sneak-fixture.txt"), FileMode.WRITE);
			stream.writeUTFBytes(report);
			stream.close();
			NativeApplication.nativeApplication.exit(bad == 0 ? 0 : 1);
		}

		private function expect(name:String, got:String, part:String):String
		{
			var ok:Boolean = part ? got.indexOf(part) >= 0 : got == "";
			return (ok ? "OK " : "FAIL ") + name + " got=" + got;
		}

		private function text(value:String):ByteArray
		{
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTFBytes(value);
			bytes.position = 0;
			return bytes;
		}

		private function bytesOf(value:String):ByteArray
		{
			return text(value);
		}
	}
}
