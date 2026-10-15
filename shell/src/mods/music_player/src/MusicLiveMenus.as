package
{
	/**
	 * Tracks Menu instances from MENU_SHOW / MENU_HIDE so the jukebox can
	 * killEvents without touching MenuController getters (those fire Discord RP).
	 */
	public class MusicLiveMenus
	{
		private static var s_menus:Array = [];

		public static function noteShow(menu:*):void
		{
			var i:int;
			if (!menu)
			{
				return;
			};
			i = s_menus.indexOf(menu);
			if (i < 0)
			{
				s_menus.push(menu);
			};
		}

		public static function noteHide(menu:*):void
		{
			var i:int;
			if (!menu)
			{
				return;
			};
			i = s_menus.indexOf(menu);
			if (i >= 0)
			{
				s_menus.splice(i, 1);
			};
		}

		public static function onscreen():Array
		{
			var out:Array;
			var i:int;
			var menu:*;
			out = [];
			i = 0;
			while (i < s_menus.length)
			{
				menu = s_menus[i];
				i++;
				if (!menu)
				{
					continue;
				};
				try
				{
					if (menu["isOnscreen"] is Function && !Boolean(menu["isOnscreen"]()))
					{
						continue;
					};
				}
				catch (err:*)
				{
				};
				out.push(menu);
			};
			return (out);
		}
	}
}
