package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/** LaunchScreen.menuKey maps cssedit to versus_css, sssedit to sss, and leaves other screens alone. */
	public class LaunchScreenFixture extends Sprite
	{
		public function LaunchScreenFixture()
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
			if (LaunchScreen.menuKey("cssedit") != "versus_css")
			{
				return "cssedit key " + LaunchScreen.menuKey("cssedit");
			};
			if (LaunchScreen.menuKey("CSSEDIT") != "versus_css")
			{
				return "CSSEDIT key " + LaunchScreen.menuKey("CSSEDIT");
			};
			if (LaunchScreen.menuKey("classic") != "classic")
			{
				return "classic changed";
			};
			if (LaunchScreen.menuKey("css") != "css")
			{
				return "css changed";
			};
			if (LaunchScreen.menuKey("sssedit") != "sss")
			{
				return "sssedit key " + LaunchScreen.menuKey("sssedit");
			};
			if (LaunchScreen.menuKey("SSSEDIT") != "sss")
			{
				return "SSSEDIT key " + LaunchScreen.menuKey("SSSEDIT");
			};
			if (LaunchScreen.menuKey("sss") != "sss")
			{
				return "sss changed";
			};
			if (LaunchScreen.menuKey("") != "")
			{
				return "empty screen changed";
			};
			if (LaunchScreen.menuKey(null) != "")
			{
				return "null screen changed";
			};
			return "";
		}

		private function writeResult(failure:String):void
		{
			var file:File;
			var stream:FileStream;
			file = File.applicationStorageDirectory.resolvePath("launch-screen-fixture.txt");
			stream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(failure ? ("FAIL " + failure) : "OK");
			stream.close();
		}
	}
}
