package com.sbxmod.paletteMaker
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/** The skin that was open when Palette Maker closed or the game quit. */
	public class SkinDraft
	{
		public static function shouldOffer(draft:Object, statsName:String):Boolean
		{
			if (!draft || !statsName)
			{
				return false;
			};
			if (String(draft.character) != statsName)
			{
				return false;
			};
			return draft.palette != null && draft.palette.paletteSwap != null;
		}

		public static function read(statsName:String):Object
		{
			var file:File;
			var stream:FileStream;
			var text:String;
			var draft:Object;
			if (!statsName)
			{
				return null;
			};
			file = fileFor(statsName);
			if (!file || !file.exists)
			{
				return null;
			};
			stream = new FileStream();
			try
			{
				stream.open(file, FileMode.READ);
				text = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				draft = JSON.parse(text);
			}
			catch (err:Error)
			{
				try { stream.close(); } catch (closeErr:Error) { }
				return null;
			};
			if (!shouldOffer(draft, statsName))
			{
				return null;
			};
			return draft;
		}

		public static function write(statsName:String, costumeName:String, author:String, palette:Object, partner:Object):void
		{
			var file:File;
			var stream:FileStream;
			var draft:Object;
			if (!statsName || !palette)
			{
				return;
			};
			draft = {
				"character": statsName,
				"name": costumeName ? costumeName : "",
				"author": author ? author : "",
				"palette": palette,
				"partner": partner
			};
			file = fileFor(statsName);
			if (!file.parent.exists)
			{
				file.parent.createDirectory();
			};
			stream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(JSON.stringify(draft));
			stream.close();
		}

		public static function clear(statsName:String):void
		{
			var file:File;
			file = fileFor(statsName);
			if (file && file.exists)
			{
				file.deleteFile();
			};
		}

		private static function fileFor(statsName:String):File
		{
			return File.documentsDirectory.resolvePath("SSF2 Custom Colors/_skin_draft/" + statsName + ".json");
		}
	}
}
