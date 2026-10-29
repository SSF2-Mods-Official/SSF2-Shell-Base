package
{
	import flash.filesystem.File;
	import flash.utils.ByteArray;

	/** The same mod-SWF rules the manager uses. An unreadable file is refused. */
	public class SwfGuard
	{
		private static const NAMES:Array = [
			"URLLoader","URLRequest","URLStream","navigateToURL","Socket","ExternalInterface","FileReference",
			"getDefinitionByName","ApplicationDomain","loadBytes","FileStream","FileMode","flash.filesystem","fromCharCode"
		];

		public static function pathAllowed(relative:String):Boolean
		{
			var rel:String;
			if (!relative)
			{
				return false;
			};
			rel = relative.split("\\").join("/");
			if (rel.indexOf("..") >= 0 || rel.indexOf(":") >= 0 || rel.charAt(0) == "/")
			{
				return false;
			};
			return true;
		}

		public static function devSkip():Boolean
		{
			var mark:File = File.userDirectory.resolvePath("AppData/Roaming/SSF2ModManager/dev-build");
			return mark.exists && !mark.isDirectory;
		}

		/** Empty when the bytes are allowed. Otherwise the names that were found. */
		public static function reasons(bytes:ByteArray):String
		{
			var plain:ByteArray = plainBytes(bytes);
			var text:String;
			var i:int = 0;
			var hit:String = "";
			if (!plain)
			{
				return "unreadable";
			};
			text = plain.readUTFBytes(plain.length);
			while (i < NAMES.length)
			{
				if (text.indexOf(String(NAMES[i])) >= 0)
				{
					hit += (hit ? "," : "") + String(NAMES[i]);
				};
				i++;
			};
			hit = splitHits(plain, hit);
			return hit;
		}

		private static function plainBytes(bytes:ByteArray):ByteArray
		{
			var kind:String;
			var body:ByteArray;
			if (!bytes || bytes.length < 8)
			{
				return null;
			};
			bytes.position = 0;
			kind = bytes.readUTFBytes(3);
			if (kind == "FWS")
			{
				bytes.position = 0;
				return bytes;
			};
			if (kind != "CWS")
			{
				return null;
			};
			body = new ByteArray();
			bytes.position = 8;
			bytes.readBytes(body);
			try
			{
				body.uncompress();
			}
			catch (err:*)
			{
				return null;
			};
			body.position = 0;
			return body;
		}

		private static function splitHits(plain:ByteArray, hit:String):String
		{
			var runs:Array = [];
			var starts:Array = [];
			var ends:Array = [];
			var i:int = 0;
			var start:int;
			var text:String;
			var a:int;
			var b:int;
			var joined:String;
			var n:int;
			plain.position = 0;
			while (i < plain.length)
			{
				if (plain[i] < 32 || plain[i] > 126)
				{
					i++;
					continue;
				};
				start = i;
				text = "";
				while (i < plain.length && plain[i] >= 32 && plain[i] <= 126)
				{
					text += String.fromCharCode(plain[i]);
					i++;
				};
				if (text.length >= 2 && text.length <= 80)
				{
					runs.push(text);
					starts.push(start);
					ends.push(i);
				};
			};
			a = 0;
			while (a < runs.length)
			{
				b = a + 1;
				while (b < runs.length && int(starts[b]) - int(ends[a]) <= 8)
				{
					joined = String(runs[a]) + String(runs[b]);
					n = 0;
					while (n < NAMES.length)
					{
						if (joined.indexOf(String(NAMES[n])) >= 0
							&& String(runs[a]).indexOf(String(NAMES[n])) < 0
							&& String(runs[b]).indexOf(String(NAMES[n])) < 0
							&& hit.indexOf(String(NAMES[n])) < 0)
						{
							hit += (hit ? "," : "") + String(NAMES[n]);
						};
						n++;
					};
					b++;
				};
				a++;
			};
			return hit;
		}
	}
}
