package
{
	/** Which menu track stays up. An empty result means the caller picks once. */
	public class MenuReplay
	{
		public static function keepId(currentId:String, pinnedId:String, songs:Array):String
		{
			if (listed(pinnedId, songs))
			{
				return (pinnedId);
			};
			if (listed(currentId, songs))
			{
				return (currentId);
			};
			if (!songs || songs.length < 1)
			{
				if (isStockMenu(pinnedId))
				{
					return (pinnedId);
				};
				if (isStockMenu(currentId))
				{
					return (currentId);
				};
			};
			return ("");
		}

		public static function isStockMenu(id:String):Boolean
		{
			return (id == "menumusic" || id == "menumusic1" || id == "menumusic2" || id == "meleemenu2");
		}

		private static function listed(id:String, songs:Array):Boolean
		{
			var i:int;
			if (!id || id.length < 1 || !songs)
			{
				return (false);
			};
			i = 0;
			while (i < songs.length)
			{
				if (String(songs[i]) == id)
				{
					return (true);
				};
				i++;
			};
			return (false);
		}
	}
}
