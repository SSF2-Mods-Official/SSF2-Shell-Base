package
{
	/**
	 * Mod menu list geometry. view is the visible item list; each item has an optional "section".
	 * A section header (SECTION_H) sits above the first item of each non-empty section.
	 */
	public class ModMenuScroll
	{
		public static const ROW_H:int = 26;
		public static const SECTION_H:int = 20;

		/** Top of item itemIndex, counting rows and section headers above it. */
		public static function itemTopY(view:Array, itemIndex:int):int
		{
			var i:int;
			var y:int;
			var lastSec:String;
			var sec:String;
			y = 0;
			lastSec = "\x00";
			i = 0;
			while (i < view.length && i <= itemIndex)
			{
				sec = String(view[i].section || "");
				if (sec != lastSec)
				{
					lastSec = sec;
					if (sec.length > 0)
					{
						y += SECTION_H;
					};
				};
				if (i == itemIndex)
				{
					return (y);
				};
				y += ROW_H;
				i++;
			};
			return (y);
		}

		public static function sectionStartsAt(view:Array, itemIndex:int):Boolean
		{
			var sec:String;
			if (itemIndex < 0 || itemIndex >= view.length)
			{
				return (false);
			};
			sec = String(view[itemIndex].section || "");
			if (sec.length < 1)
			{
				return (false);
			};
			if (itemIndex == 0)
			{
				return (true);
			};
			return (sec != String(view[itemIndex - 1].section || ""));
		}

		/** First scroll index that still shows the last row in a track of this height, counting section headers. */
		public static function maxScrollIndex(view:Array, track:Number):int
		{
			var last:int;
			var bottom:int;
			var s:int;
			last = view.length - 1;
			if (last < 1)
			{
				return (0);
			};
			bottom = itemTopY(view, last) + ROW_H;
			s = 0;
			while (s < last && bottom - itemTopY(view, s) + (sectionStartsAt(view, s) ? SECTION_H : 0) > track)
			{
				s++;
			};
			return (s);
		}
	}
}
