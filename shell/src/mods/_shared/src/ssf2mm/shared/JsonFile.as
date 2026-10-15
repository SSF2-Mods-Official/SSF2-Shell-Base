package ssf2mm.shared
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	/** UTF-8 text and JSON files. Read misses return null; writes create the parent folder. Never throws. */
	public class JsonFile
	{
		public static function readText(file:File):String
		{
			var stream:FileStream = null;
			var text:String = null;
			if (!file || !file.exists || file.isDirectory)
			{
				return null;
			};
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				text = stream.readUTFBytes(stream.bytesAvailable);
			}
			catch (err:*)
			{
				text = null;
			};
			close(stream);
			return text;
		}

		public static function writeText(file:File, text:String):Boolean
		{
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTFBytes(text == null ? "" : text);
			return writeBytes(file, bytes);
		}

		public static function writeBytes(file:File, bytes:ByteArray):Boolean
		{
			var stream:FileStream = null;
			var ok:Boolean = false;
			if (!file)
			{
				return false;
			};
			try
			{
				if (file.parent && !file.parent.exists)
				{
					file.parent.createDirectory();
				};
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				if (bytes && bytes.length > 0)
				{
					stream.writeBytes(bytes, 0, bytes.length);
				};
				ok = true;
			}
			catch (err:*)
			{
				ok = false;
			};
			close(stream);
			return ok;
		}

		/** Parsed JSON, or null when the file is missing or does not parse. */
		public static function read(file:File):Object
		{
			return parse(readText(file));
		}

		public static function write(file:File, data:Object, pretty:Boolean = false):Boolean
		{
			var text:String;
			try
			{
				text = pretty ? JSON.stringify(data, null, 2) : JSON.stringify(data);
			}
			catch (err:*)
			{
				return false;
			};
			return writeText(file, text);
		}

		/** JSON.parse that returns null instead of throwing. A leading UTF-8 BOM is skipped. */
		public static function parse(text:String):Object
		{
			if (text == null || text.length == 0)
			{
				return null;
			};
			if (text.charCodeAt(0) == 0xFEFF)
			{
				text = text.substr(1);
			};
			try
			{
				return JSON.parse(text);
			}
			catch (err:*)
			{
			};
			return null;
		}

		private static function close(stream:FileStream):void
		{
			if (!stream)
			{
				return;
			};
			try
			{
				stream.close();
			}
			catch (err:*)
			{
			};
		}
	}
}
