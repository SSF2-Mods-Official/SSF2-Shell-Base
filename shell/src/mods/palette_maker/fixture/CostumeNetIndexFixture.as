package
{
	import com.sbxmod.paletteMaker.CostumeNetIndex;
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import ssf2mm.shared.JsonFile;

	/**
	 * CostumeNetIndex: stock and Color Vault indexes stay as sent; a remote player's locally made
	 * costume becomes base (-1); the local player's own costume is never changed.
	 */
	public class CostumeNetIndexFixture extends Sprite
	{
		private var m_lines:Array = [];
		private var m_failed:Boolean = false;

		public function CostumeNetIndexFixture()
		{
			addEventListener(Event.ADDED_TO_STAGE, onStage);
		}

		private function onStage(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onStage);
			try
			{
				check();
			}
			catch (err:*)
			{
				fail("threw", String(err));
			};
			m_lines.push(m_failed ? "FAIL" : "OK");
			JsonFile.writeText(File.applicationStorageDirectory.resolvePath("costume-net-fixture.txt"), m_lines.join("\n"));
			NativeApplication.nativeApplication.exit(m_failed ? 1 : 0);
		}

		private function check():void
		{
			// Stock: base, 3 alts, 1 team entry (6 entries incl. a 2nd team). Then 2 vault, then 2 local.
			var stock:Array = [{"base": true}, {"n": "s0"}, {"team": "red"}, {"n": "s1"}, {"n": "s2"}, {"team": "blue"}];
			var list:Array = stock.concat([{"n": "v0"}, {"n": "v1"}, {"n": "l0"}, {"n": "l1"}]);
			var sl:int = stock.length;

			expect("position skips base and team", CostumeNetIndex.entryPosition(list, 1) == 3 && CostumeNetIndex.entryPosition(list, 3) == 6, String(CostumeNetIndex.entryPosition(list, 3)));
			expect("stock pick", CostumeNetIndex.resolve(2, list, sl, 2, false) == 2, "");
			expect("vault pick", CostumeNetIndex.resolve(4, list, sl, 2, false) == 4, "");
			expect("remote local made", CostumeNetIndex.resolve(5, list, sl, 2, false) == -1, String(CostumeNetIndex.resolve(5, list, sl, 2, false)));
			expect("own local made", CostumeNetIndex.resolve(5, list, sl, 2, true) == 5, "");
			expect("base stays base", CostumeNetIndex.resolve(-1, list, sl, 2, false) == -1, "");
			expect("unsynced catalog", CostumeNetIndex.resolve(3, list, sl, 0, false) == -1, String(CostumeNetIndex.resolve(3, list, sl, 0, false)));
			expect("past end left to engine", CostumeNetIndex.resolve(40, list, sl, 2, false) == 40, "");
		}

		private function expect(name:String, ok:Boolean, why:String):void
		{
			if (ok)
			{
				m_lines.push("OK " + name);
			}
			else
			{
				fail(name, why);
			};
		}

		private function fail(name:String, why:String):void
		{
			m_failed = true;
			m_lines.push("FAIL " + name + ": " + why);
		}
	}
}
