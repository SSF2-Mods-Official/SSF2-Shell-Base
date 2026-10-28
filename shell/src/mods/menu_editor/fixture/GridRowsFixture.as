package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/** GridRows: add/insert/remove/move, row overflow and MAX_ROWS clamp, page resize and page split, empty and full cases. */
	public class GridRowsFixture extends Sprite
	{
		public function GridRowsFixture()
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

		private static function same(label:String, got:*, want:*):String
		{
			var g:String = JSON.stringify(got);
			var w:String = JSON.stringify(want);
			return (g == w ? "" : (label + " got " + g + " want " + w));
		}

		private function check():String
		{
			var f:String;
			var rows:Array;
			var pages:Array;

			// add: empty page, duplicate, spill into a new row, full page
			rows = [[]];
			if (!GridRows.tryAdd(rows, "a", 2, 2)) return ("tryAdd empty page refused");
			if (GridRows.tryAdd(rows, "a", 2, 2)) return ("tryAdd accepted a duplicate");
			GridRows.tryAdd(rows, "b", 2, 2);
			GridRows.tryAdd(rows, "c", 2, 2);
			if ((f = same("tryAdd spill", rows, [["a", "b"], ["c"]]))) return (f);
			GridRows.tryAdd(rows, "d", 2, 2);
			if (GridRows.tryAdd(rows, "e", 2, 2)) return ("tryAdd accepted on a full page");
			if ((f = same("tryAdd full", rows, [["a", "b"], ["c", "d"]]))) return (f);
			if (GridRows.tryAdd([], "a", 2, 0)) return ("tryAdd with maxRows 0 accepted");

			// insert: col clamp, row past end, negative row
			rows = [["a", "b"]];
			GridRows.insertAt(rows, 0, 99, "c");
			GridRows.insertAt(rows, 0, -5, "z");
			GridRows.insertAt(rows, 7, 0, "n");
			GridRows.insertAt(rows, -1, 0, "never");
			if ((f = same("insertAt", rows, [["z", "a", "b", "c"], ["n"]]))) return (f);

			// insertBeforePinned: before random, and on an empty page
			rows = [["a", "random"]];
			GridRows.insertBeforePinned(rows, "b");
			if ((f = same("insertBeforePinned", rows, [["a", "b", "random"]]))) return (f);
			rows = [];
			GridRows.insertBeforePinned(rows, "b");
			if ((f = same("insertBeforePinned empty", rows, [["b"]]))) return (f);

			// remove: keep or drop the emptied row
			rows = [["a"], ["b", "c"]];
			GridRows.removeId(rows, "a");
			if ((f = same("removeId keep", rows, [[], ["b", "c"]]))) return (f);
			rows = [["a"], ["b", "c"]];
			GridRows.removeId(rows, "a", true);
			if ((f = same("removeId dropEmpty", rows, [["b", "c"]]))) return (f);
			rows = [[]];
			GridRows.removeId(rows, "missing", true);
			if ((f = same("removeId empty page", rows, []))) return (f);

			// move: same-row shift, cross-row, new row, new row at MAX_ROWS
			rows = [["a", "b", "c"]];
			GridRows.moveId(rows, "a", 0, 2, false, true, 6);
			if ((f = same("moveId same row shift", rows, [["b", "a", "c"]]))) return (f);
			rows = [["a", "b", "c"]];
			GridRows.moveId(rows, "a", 0, 2, false, false, 6);
			if ((f = same("moveId from bench", rows, [["b", "c", "a"]]))) return (f);
			rows = [["a", "b"], ["c"]];
			GridRows.moveId(rows, "a", 1, 0, false, true, 6);
			if ((f = same("moveId cross row", rows, [["b"], ["a", "c"]]))) return (f);
			rows = [["a", "b"]];
			GridRows.moveId(rows, "a", 0, 0, true, true, 6);
			if ((f = same("moveId new row", rows, [["b"], ["a"]]))) return (f);
			rows = [["a", "b"], ["c"]];
			GridRows.moveId(rows, "a", 0, 0, true, true, 2);
			if ((f = same("moveId new row at max", rows, [["b"], ["c", "a"]]))) return (f);

			// overflow spill and MAX_ROWS clamp
			rows = [["a", "b", "c"], ["d"]];
			GridRows.overflow(rows, 2, 6);
			if ((f = same("overflow spill", rows, [["a", "b"], ["c", "d"]]))) return (f);
			rows = [["a"], ["b"], ["c"], ["d"]];
			GridRows.cap(rows, 13, 2);
			if ((f = same("cap MAX_ROWS", rows, [["a"], ["b"]]))) return (f);
			rows = [];
			GridRows.cap(rows, 13, 6);
			if ((f = same("cap empty", rows, []))) return (f);

			// filterIds keeps row 0, drops other empty rows
			rows = GridRows.filterIds([["css_prev_page"], ["a", "css_next_page"], ["css_next_page"]], function(id:String):Boolean
			{
				return (id.indexOf("css_") != 0);
			});
			if ((f = same("filterIds", rows, [[], ["a"]]))) return (f);
			if ((f = same("filterIds null", GridRows.filterIds(null, null), [[]]))) return (f);

			// page count clamp and resize
			pages = [];
			GridRows.resizePages(pages, 0, 99);
			if (pages.length != 1) return ("resizePages 0 -> " + pages.length);
			GridRows.resizePages(pages, 500, 99);
			if (pages.length != 99) return ("resizePages 500 -> " + pages.length);
			GridRows.resizePages(pages, 2, 99);
			if (pages.length != 2) return ("resizePages 2 -> " + pages.length);

			// saved page list: parse, empty page, cap, nothing saved
			if ((f = same("toPages", GridRows.toPages([[["a"]], [], {"0": ["b"]}], 99), [[["a"]], [[]], [["b"]]]))) return (f);
			if (GridRows.toPages([[["a"]], [["b"]], [["c"]]], 2).length != 2) return ("toPages ignored maxPages");
			if (GridRows.toPages(null, 99) != null) return ("toPages null not null");
			if (GridRows.toPages([], 99) != null) return ("toPages [] not null");
			if ((f = same("parseRows json", GridRows.parseRows('[["a","b"],["c"]]'), [["a", "b"], ["c"]]))) return (f);
			if (GridRows.parseRows("") != null || GridRows.parseRows("{bad") != null) return ("parseRows bad input not null");

			// page split: first open page, next page, new page, all full
			pages = [[["a"]], [[]]];
			if (GridRows.placeOnFirstOpenPage(pages, "b", 1, 1, 3) != 1) return ("place did not pick page 2");
			if (GridRows.placeOnFirstOpenPage(pages, "c", 1, 1, 3) != 2) return ("place did not open page 3");
			if ((f = same("place pages", pages, [[["a"]], [["b"]], [["c"]]]))) return (f);
			if (GridRows.placeOnFirstOpenPage(pages, "d", 1, 1, 3) != -1) return ("place accepted with every page full");
			pages = [];
			if (GridRows.placeOnFirstOpenPage(pages, "a", 13, 6, 99) != 0) return ("place on no pages");
			if ((f = same("place no pages", pages, [[["a"]]]))) return (f);
			return ("");
		}

		private function writeResult(failure:String):void
		{
			var file:File;
			var stream:FileStream;
			file = File.applicationStorageDirectory.resolvePath("grid-rows-fixture.txt");
			stream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(failure ? ("FAIL " + failure) : "OK");
			stream.close();
		}
	}
}
