package
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/** Boot-time logger — same file as engine GameLog (expansions/state/game.log). */
	public class GameLog
	{
		private static var m_absPath:String = "";
		private static const DEFAULT_REL:String = "expansions/state/game.log";

		public static function setPath(absPath:String):void
		{
			m_absPath = absPath ? absPath : "";
		}

		public static function write(text:String, ...rest):void
		{
			var line:String = text == null ? "" : String(text);
			var i:int = 0;
			while (i < rest.length)
			{
				line += " " + rest[i];
				i++;
			};
			trace(line);
			append(line);
		}

		public static function append(text:String):void
		{
			var file:File;
			var stream:FileStream;
			var line:String = text == null ? "" : String(text);
			try
			{
				if (m_absPath && m_absPath.length > 0)
				{
					file = new File(m_absPath);
				}
				else
				{
					file = File.applicationDirectory.resolvePath(DEFAULT_REL);
				};
				if (file.parent && !file.parent.exists)
				{
					file.parent.createDirectory();
				};
				stream = new FileStream();
				stream.open(file, FileMode.APPEND);
				stream.writeUTFBytes(line + "\n");
				stream.close();
			}
			catch (err:*)
			{
			};
		}
	}
}
