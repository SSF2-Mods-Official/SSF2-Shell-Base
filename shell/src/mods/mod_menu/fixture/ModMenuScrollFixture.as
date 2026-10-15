package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/** ModMenuScroll.maxScrollIndex counts SECTION_H headers: at max scroll the last row fits, one less cuts it. */
	public class ModMenuScrollFixture extends Sprite
	{
		public function ModMenuScrollFixture()
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

		private static function buildView(sections:Array):Array
		{
			var view:Array = [];
			var s:int;
			var i:int;
			for (s = 0; s < sections.length; s++)
			{
				for (i = 0; i < sections[s].n; i++)
				{
					view.push({"section": sections[s].section, "label": sections[s].section + ":" + i});
				};
			};
			return (view);
		}

		private static function span(view:Array, from:int, bottom:int):int
		{
			return (bottom - ModMenuScroll.itemTopY(view, from) + (ModMenuScroll.sectionStartsAt(view, from) ? ModMenuScroll.SECTION_H : 0));
		}

		private function check():String
		{
			var ROW_H:int = ModMenuScroll.ROW_H;
			var SECTION_H:int = ModMenuScroll.SECTION_H;
			var view:Array;
			var track:Number;
			var last:int;
			var bottom:int;
			var s:int;

			view = buildView([{"section": "A", "n": 2}, {"section": "B", "n": 2}]);
			if (ModMenuScroll.itemTopY(view, 0) != SECTION_H) return ("itemTopY 0 = " + ModMenuScroll.itemTopY(view, 0));
			if (ModMenuScroll.itemTopY(view, 1) != SECTION_H + ROW_H) return ("itemTopY 1");
			if (ModMenuScroll.itemTopY(view, 2) != 2 * SECTION_H + 2 * ROW_H) return ("itemTopY 2 = " + ModMenuScroll.itemTopY(view, 2));
			if (ModMenuScroll.itemTopY(view, 3) != 2 * SECTION_H + 3 * ROW_H) return ("itemTopY 3");
			if (!ModMenuScroll.sectionStartsAt(view, 2) || ModMenuScroll.sectionStartsAt(view, 1)) return ("sectionStartsAt");

			if (ModMenuScroll.maxScrollIndex([], 100) != 0) return ("empty list scrolls");
			if (ModMenuScroll.maxScrollIndex(buildView([{"section": "A", "n": 1}]), 10) != 0) return ("one row scrolls");
			if (ModMenuScroll.maxScrollIndex(buildView([{"section": "A", "n": 3}]), 10000) != 0) return ("short list scrolls");

			// openMenu: m_listBottom = m_gh - 40, m_listTop = 56, m_gh = 480
			track = (480 - 40) - 56;
			view = buildView([{"section": "Display", "n": 8}, {"section": "Essentials", "n": 6}, {"section": "Roster", "n": 5}]);
			last = view.length - 1;
			bottom = ModMenuScroll.itemTopY(view, last) + ROW_H;
			if (bottom <= track) return ("list not taller than track");
			s = ModMenuScroll.maxScrollIndex(view, track);
			if (s <= 0 || s >= last) return ("max scroll out of range " + s);
			if (span(view, s, bottom) > track) return ("last row cut at max scroll " + s);
			if (span(view, s - 1, bottom) <= track) return ("max scroll " + s + " is not the first that fits");

			// headers alone push the list past the track: rows-only math would stop one short
			view = buildView([{"section": "A", "n": 1}, {"section": "B", "n": 1}, {"section": "C", "n": 1}, {"section": "D", "n": 1}]);
			bottom = ModMenuScroll.itemTopY(view, 3) + ROW_H;
			track = 4 * ROW_H;
			s = ModMenuScroll.maxScrollIndex(view, track);
			if (span(view, s, bottom) > track) return ("headers: last row cut at " + s);
			if (s != 2) return ("headers: max scroll " + s + " want 2");
			return ("");
		}

		private function writeResult(failure:String):void
		{
			var file:File;
			var stream:FileStream;
			file = File.applicationStorageDirectory.resolvePath("mod-menu-scroll-fixture.txt");
			stream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(failure ? ("FAIL " + failure) : "OK");
			stream.close();
		}
	}
}
