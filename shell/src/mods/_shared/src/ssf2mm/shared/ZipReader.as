package ssf2mm.shared
{
	import flash.utils.ByteArray;

	/**
	 * Minimal ZIP reader: walks the central directory and returns stored (method 0)
	 * and deflated (method 8) entries. Everything else is skipped.
	 * log(msg:String) receives "unzip: ..." lines when it is not null.
	 */
	public class ZipReader
	{
		/**
		 * Central directory entries { name, method, compSize, uncompSize, localOffset }.
		 * Names use "/" separators. Unsafe paths (.., absolute, drive) are dropped.
		 * Returns null when the bytes are not a zip.
		 */
		public static function entries(zip:ByteArray, log:Function = null):Array
		{
			var eocd:int;
			var count:int;
			var dirOffset:int;
			var i:int;
			var out:Array = [];
			var entry:Object;
			if (!zip)
			{
				return null;
			};
			zip.endian = "littleEndian";
			eocd = findEOCD(zip);
			if (eocd < 0)
			{
				say(log, "unzip: no EOCD, not a zip");
				return null;
			};
			zip.position = eocd + 10;
			count = zip.readUnsignedShort();
			zip.position = eocd + 16;
			dirOffset = int(zip.readUnsignedInt());
			say(log, "unzip: " + count + " entries, dir@" + dirOffset);

			zip.position = dirOffset;
			i = 0;
			while (i < count && zip.bytesAvailable > 46)
			{
				i++;
				if (zip.readUnsignedInt() != 0x02014b50)
				{
					break;
				};
				entry = readCentralEntry(zip, log);
				if (entry)
				{
					out.push(entry);
				};
			};
			return out;
		}

		/** Uncompressed bytes of one entry from entries(), or null on a bad header, unknown method or inflate error. */
		public static function read(zip:ByteArray, entry:Object, log:Function = null):ByteArray
		{
			var nameLen:int;
			var extraLen:int;
			var raw:ByteArray;

			zip.endian = "littleEndian";
			zip.position = uint(entry.localOffset);
			if (zip.readUnsignedInt() != 0x04034b50)
			{
				say(log, "unzip: bad local header for " + entry.name);
				return null;
			};
			zip.position = uint(entry.localOffset) + 26;
			nameLen = zip.readUnsignedShort();
			extraLen = zip.readUnsignedShort();
			zip.position = uint(entry.localOffset) + 30 + nameLen + extraLen;

			raw = new ByteArray();
			if (uint(entry.compSize) > 0)
			{
				zip.readBytes(raw, 0, uint(entry.compSize));
			};
			if (int(entry.method) == 0)
			{
				return raw;
			};
			if (int(entry.method) != 8)
			{
				say(log, "unzip: unsupported method " + entry.method + " for " + entry.name);
				return null;
			};
			try
			{
				raw.inflate();
				raw.position = 0;
				return raw;
			}
			catch (err:*)
			{
				say(log, "unzip: inflate failed for " + entry.name + ": " + err);
			};
			return null;
		}

		/** The shared top-level folder name, or null if any entry sits at the zip root. */
		public static function commonTopFolder(entries:Array):String
		{
			var i:int;
			var name:String;
			var slash:int;
			var top:String = null;
			i = 0;
			while (i < entries.length)
			{
				name = String(entries[i].name);
				i++;
				slash = name.indexOf("/");
				if (slash <= 0)
				{
					return null;
				};
				if (top == null)
				{
					top = name.substring(0, slash);
				}
				else if (top != name.substring(0, slash))
				{
					return null;
				};
			};
			return top;
		}

		private static function readCentralEntry(zip:ByteArray, log:Function):Object
		{
			var method:int;
			var compSize:uint;
			var uncompSize:uint;
			var nameLen:int;
			var extraLen:int;
			var commentLen:int;
			var localOffset:uint;
			var name:String;

			zip.position += 6;              // version made by, version needed, flags
			method = zip.readUnsignedShort();
			zip.position += 8;              // mod time, mod date, crc32
			compSize = zip.readUnsignedInt();
			uncompSize = zip.readUnsignedInt();
			nameLen = zip.readUnsignedShort();
			extraLen = zip.readUnsignedShort();
			commentLen = zip.readUnsignedShort();
			zip.position += 8;              // disk number, internal/external attrs
			localOffset = zip.readUnsignedInt();
			name = zip.readUTFBytes(nameLen);
			zip.position += extraLen + commentLen;

			if (name.indexOf("..") >= 0 || name.charAt(0) == "/" || name.charAt(1) == ":")
			{
				say(log, "unzip: skipping unsafe path " + name);
				return null;
			};
			return {
				"name": name.split("\\").join("/"),
				"method": method,
				"compSize": compSize,
				"uncompSize": uncompSize,
				"localOffset": localOffset
			};
		}

		private static function findEOCD(zip:ByteArray):int
		{
			var start:int = zip.length - 22;
			var limit:int = zip.length - 22 - 65535;
			var i:int;
			if (zip.length < 22)
			{
				return -1;
			};
			if (limit < 0)
			{
				limit = 0;
			};
			i = start;
			while (i >= limit)
			{
				zip.position = i;
				if (zip.readUnsignedInt() == 0x06054b50)
				{
					return i;
				};
				i--;
			};
			return -1;
		}

		private static function say(log:Function, msg:String):void
		{
			if (log != null)
			{
				log(msg);
			};
		}
	}
}
