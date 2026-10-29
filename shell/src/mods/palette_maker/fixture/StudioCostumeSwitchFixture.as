package
{
	import com.sbxmod.paletteMaker.StudioCostumeSwitch;
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/** Locker switch paints no-recolor before the next costume. */
	public class StudioCostumeSwitchFixture extends Sprite
	{
		public function StudioCostumeSwitchFixture()
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
			var phases:Array;
			var got:Array;
			phases = StudioCostumeSwitch.phases();
			if (!phases || phases.length != 2
				|| phases[0] != StudioCostumeSwitch.PHASE_NO_RECOLOR
				|| phases[1] != StudioCostumeSwitch.PHASE_APPLY_COSTUME)
			{
				return "phases order";
			};
			if (!StudioCostumeSwitch.paintsIdentityBeforeCostumeIndex())
			{
				return "identity must paint first";
			};
			if (!StudioCostumeSwitch.suppressesSelectionOnDeselect())
			{
				return "locker deselect must suppress membership sync";
			};
			if (!StudioCostumeSwitch.deselectsActiveGroupsOnPick())
			{
				return "locker pick must deselect active groups";
			};
			got = StudioCostumeSwitch.applyAfterNoRecolor(
				[0xFF111111, 0xFF222222],
				[0xFF111111, 0xFF222222],
				[0xFFFF0000, 0xFF00FF00]);
			if (!got || got.length != 2 || uint(got[0]) != 0xFFFF0000 || uint(got[1]) != 0xFF00FF00)
			{
				return "apply after no-recolor";
			};
			got = StudioCostumeSwitch.applyAfterNoRecolor(
				[0xFFAAAAAA],
				null,
				[0xFFBBBBBB]);
			if (!got || uint(got[0]) != 0xFFBBBBBB)
			{
				return "null identity then costume";
			};
			return "";
		}

		private function writeResult(failure:String):void
		{
			var file:File = File.applicationStorageDirectory.resolvePath("studio-costume-switch-fixture.txt");
			var stream:FileStream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(failure ? ("FAIL " + failure) : "OK");
			stream.close();
		}
	}
}
