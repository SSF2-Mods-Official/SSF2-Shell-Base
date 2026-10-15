package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.utils.ByteArray;
	import ssf2mm.shared.JsonFile;
	import ssf2mm.shared.ZipReader;

	/**
	 * JsonFile round trips, rejects broken JSON and skips a BOM. ZipReader lists a stored and a
	 * deflated entry, reads both back byte for byte, and drops unsafe paths. One OK/FAIL line per
	 * check, then OK or FAIL on the last line.
	 */
	public class SharedFixture extends Sprite
	{
		private var m_lines:Array = [];
		private var m_failed:Boolean = false;

		public function SharedFixture()
		{
			addEventListener(Event.ADDED_TO_STAGE, onStage);
		}

		private function onStage(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onStage);
			try
			{
				checkJson();
				checkZip();
			}
			catch (err:*)
			{
				fail("threw", String(err));
			};
			m_lines.push(m_failed ? "FAIL" : "OK");
			trace("FIXTURE\n" + m_lines.join("\n"));
			JsonFile.writeText(File.applicationStorageDirectory.resolvePath("shared-fixture.txt"), m_lines.join("\n"));
			NativeApplication.nativeApplication.exit(m_failed ? 1 : 0);
		}

		private function checkJson():void
		{
			var dir:File = File.applicationStorageDirectory.resolvePath("work");
			var file:File = dir.resolvePath("nested/data.json");
			var back:Object;
			var bom:ByteArray;
			if (dir.exists)
			{
				dir.deleteDirectory(true);
			};
			expect("json write creates folder", JsonFile.write(file, {"name": "Pack", "list": [1, 2, 3], "on": true}, true), "write returned false");
			back = JsonFile.read(file);
			expect("json read back", back != null && back.name == "Pack" && back.list.length == 3 && back.list[2] == 3 && back.on === true, JSON.stringify(back));
			expect("json pretty", String(JsonFile.readText(file)).indexOf("\n") > 0, "no newline in pretty output");

			JsonFile.writeText(dir.resolvePath("broken.json"), "{\"name\": \"Pack\",");
			expect("json broken is null", JsonFile.read(dir.resolvePath("broken.json")) == null, "parsed a broken file");
			expect("json missing is null", JsonFile.read(dir.resolvePath("missing.json")) == null, "read a missing file");
			expect("json folder is null", JsonFile.read(dir) == null, "read a folder");

			bom = new ByteArray();
			bom.writeByte(0xEF);
			bom.writeByte(0xBB);
			bom.writeByte(0xBF);
			bom.writeUTFBytes("{\"id\": \"bom\"}");
			JsonFile.writeBytes(dir.resolvePath("bom.json"), bom);
			back = JsonFile.read(dir.resolvePath("bom.json"));
			expect("json bom file", back != null && back.id == "bom", JSON.stringify(back));
			back = JsonFile.parse("\uFEFF[1,2]");
			expect("json bom text", back is Array && back.length == 2, JSON.stringify(back));
			expect("json empty text is null", JsonFile.parse("") == null && JsonFile.parse(null) == null, "parsed empty");
		}

		private function checkZip():void
		{
			var stored:ByteArray = utf("stored payload\n");
			var plain:ByteArray = utf(repeat("deflate me please. ", 40));
			var zip:ByteArray = buildZip([
				{"name": "Pack/info.json", "data": stored, "method": 0},
				{"name": "Pack/sub/song.txt", "data": plain, "method": 8},
				{"name": "../evil.txt", "data": stored, "method": 0}
			]);
			var entries:Array = ZipReader.entries(zip);
			var a:ByteArray;
			var b:ByteArray;
			var flat:Array;
			expect("zip entries", entries != null && entries.length == 2, entries ? String(entries.length) : "null");
			if (!entries || entries.length != 2)
			{
				return;
			};
			expect("zip names", entries[0].name == "Pack/info.json" && entries[1].name == "Pack/sub/song.txt", entries[0].name + "," + entries[1].name);
			expect("zip methods", entries[0].method == 0 && entries[1].method == 8, entries[0].method + "," + entries[1].method);
			expect("zip deflated is smaller", uint(entries[1].compSize) < plain.length, entries[1].compSize + " vs " + plain.length);
			a = ZipReader.read(zip, entries[0]);
			b = ZipReader.read(zip, entries[1]);
			expect("zip stored bytes", same(a, stored), a ? String(a.length) : "null");
			expect("zip deflated bytes", same(b, plain), b ? String(b.length) : "null");
			expect("zip top folder", ZipReader.commonTopFolder(entries) == "Pack", String(ZipReader.commonTopFolder(entries)));

			flat = ZipReader.entries(buildZip([{"name": "root.txt", "data": stored, "method": 0}, {"name": "Pack/x.txt", "data": stored, "method": 0}]));
			expect("zip mixed root has no top folder", flat != null && ZipReader.commonTopFolder(flat) == null, flat ? String(ZipReader.commonTopFolder(flat)) : "null");
			expect("zip not a zip", ZipReader.entries(utf("just text, no central directory here")) == null, "listed a non-zip");

			zip = buildZip([{"name": "Pack/odd.bin", "data": stored, "method": 12}]);
			flat = ZipReader.entries(zip);
			expect("zip unknown method is null", flat != null && flat.length == 1 && ZipReader.read(zip, flat[0]) == null, "read an unknown method");
		}

		/** Local headers, central directory and end record. method 8 entries are deflated here. */
		private function buildZip(items:Array):ByteArray
		{
			var out:ByteArray = new ByteArray();
			var dir:ByteArray = new ByteArray();
			var i:int;
			var item:Object;
			var name:ByteArray;
			var body:ByteArray;
			var offset:uint;
			var dirStart:uint;
			out.endian = "littleEndian";
			dir.endian = "littleEndian";
			i = 0;
			while (i < items.length)
			{
				item = items[i];
				i++;
				name = utf(String(item.name));
				body = new ByteArray();
				body.writeBytes(item.data as ByteArray);
				if (int(item.method) == 8)
				{
					body.deflate();
				};
				offset = out.position;
				out.writeUnsignedInt(0x04034b50);
				out.writeShort(20);
				out.writeShort(0);
				out.writeShort(int(item.method));
				out.writeShort(0);
				out.writeShort(0);
				out.writeUnsignedInt(0);
				out.writeUnsignedInt(body.length);
				out.writeUnsignedInt((item.data as ByteArray).length);
				out.writeShort(name.length);
				out.writeShort(0);
				out.writeBytes(name);
				out.writeBytes(body);

				dir.writeUnsignedInt(0x02014b50);
				dir.writeShort(20);
				dir.writeShort(20);
				dir.writeShort(0);
				dir.writeShort(int(item.method));
				dir.writeShort(0);
				dir.writeShort(0);
				dir.writeUnsignedInt(0);
				dir.writeUnsignedInt(body.length);
				dir.writeUnsignedInt((item.data as ByteArray).length);
				dir.writeShort(name.length);
				dir.writeShort(0);
				dir.writeShort(0);
				dir.writeShort(0);
				dir.writeShort(0);
				dir.writeUnsignedInt(0);
				dir.writeUnsignedInt(offset);
				dir.writeBytes(name);
			};
			dirStart = out.position;
			out.writeBytes(dir);
			out.writeUnsignedInt(0x06054b50);
			out.writeShort(0);
			out.writeShort(0);
			out.writeShort(items.length);
			out.writeShort(items.length);
			out.writeUnsignedInt(dir.length);
			out.writeUnsignedInt(dirStart);
			out.writeShort(0);
			out.position = 0;
			return out;
		}

		private function expect(name:String, ok:Boolean, detail:String):void
		{
			if (ok)
			{
				m_lines.push("OK " + name);
			}
			else
			{
				fail(name, detail);
			};
		}

		private function fail(name:String, detail:String):void
		{
			m_failed = true;
			m_lines.push("FAIL " + name + ": " + detail);
		}

		private static function utf(text:String):ByteArray
		{
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTFBytes(text);
			bytes.position = 0;
			return bytes;
		}

		private static function repeat(text:String, count:int):String
		{
			var out:String = "";
			while (count-- > 0)
			{
				out += text;
			};
			return out;
		}

		private static function same(a:ByteArray, b:ByteArray):Boolean
		{
			var i:int;
			if (!a || !b || a.length != b.length)
			{
				return false;
			};
			i = 0;
			while (i < a.length)
			{
				if (a[i] != b[i])
				{
					return false;
				};
				i++;
			};
			return true;
		}
	}
}
