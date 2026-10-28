package
{
	import flash.display.Loader;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.ByteArray;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;

	/**
	 * AIR document class for SSF2.swf.
	 * Loads engine1, then engine2, into the current ApplicationDomain,
	 * then shows Main at (0, 0).
	 */
	public class Bootstrap extends Sprite
	{
		[Embed(source="build-file-lists.txt", mimeType="application/octet-stream")]
		private static const FileLists:Class;
		private var m_status:TextField;
		private var m_libLoader:Loader;
		private var m_engine2Loader:Loader;

		public function Bootstrap()
		{
			super();
			if (stage)
			{
				onAdded(null);
			}
			else
			{
				addEventListener(Event.ADDED_TO_STAGE, onAdded);
			};
		}

		private function onAdded(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAdded);
			try
			{
				GameLog.setPath(File.applicationDirectory.resolvePath("expansions/state/game.log").nativePath);
				GameLog.write("[Bootstrap] loading engine1");
			}
			catch (logErr:*)
			{
			};
			stage.align = "";
			stage.scaleMode = StageScaleMode.SHOW_ALL;
			stage.frameRate = 30;
			GameLog.write("[Bootstrap] frameRate=30");
			this.x = 0;
			this.y = 0;
			opaqueBackground = 0x000000;
			m_status = new TextField();
			m_status.x = 0;
			m_status.y = 0;
			m_status.width = 640;
			m_status.height = 360;
			m_status.wordWrap = true;
			m_status.multiline = true;
			m_status.defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF, true);
			m_status.text = "Loading engine1…";
			addChild(m_status);
			if (!modsAreSafe())
			{
				return;
			};
			GameLog.write("[Bootstrap] file hash check is the manager's");
			m_libLoader = new Loader();
			m_engine2Loader = new Loader();
			loadSwf("data/engine/engine1.swf", m_libLoader, onLibComplete, "engine1");
		}

		private function onLibComplete(e:Event):void
		{
			m_status.text = "Loading engine2…";
			GameLog.write("[Bootstrap] loading engine2");
			loadSwf("data/engine/engine2.swf", m_engine2Loader, onEngine2Complete, "engine2");
		}

		private function onEngine2Complete(e:Event):void
		{
			var MainClass:Class;
			var main:DisplayObject;
			var qname:String;
			try
			{
				if (m_status && m_status.parent)
				{
					removeChild(m_status);
				};
				m_engine2Loader.x = 0;
				m_engine2Loader.y = 0;
				qname = ((m_engine2Loader.content) ? getQualifiedClassName(m_engine2Loader.content) : "");
				if (qname.indexOf("ssf2::Main") >= 0)
				{
					GameLog.write("[Bootstrap] engine2 loaded");
					addChild(m_engine2Loader);
					return;
				};
				MainClass = (getDefinitionByName("com.mcleodgaming.ssf2.Main") as Class);
				main = (new MainClass() as DisplayObject);
				main.x = 0;
				main.y = 0;
				GameLog.write("[Bootstrap] engine2 loaded");
				addChild(main);
			}
			catch (err:Error)
			{
				fail("Engine2 loaded but Main failed:\n" + err.message);
			};
		}

		private function noteFileHashes():void
		{
			var raw:ByteArray = new FileLists() as ByteArray;
			var text:String = raw.readUTFBytes(raw.length);
			var lines:Array = text.split("\n");
			var trust:Object = readTrust();
			var i:int = 0;
			var section:String = "";
			var line:String;
			var space:int;
			var rel:String;
			var expect:String;
			var file:File;
			var got:String;
			var row:Object;
			while (i < lines.length)
			{
				line = String(lines[i]).split("\r").join("");
				i++;
				if (line == "SSF2MM-VANILLA" || line == "SSF2MM-SHELL")
				{
					section = line;
					continue;
				};
				if (!line || (section == "SSF2MM-SHELL" && SwfGuard.devSkip()))
				{
					continue;
				};
				space = line.lastIndexOf(" ");
				if (space <= 0)
				{
					continue;
				};
				rel = line.substring(0, space);
				expect = line.substring(space + 1).toLowerCase();
				file = File.applicationDirectory.resolvePath(rel);
				if (!file.exists)
				{
					GameLog.write("[Bootstrap] caution missing " + rel);
					continue;
				};
				var rootPath:String = File.applicationDirectory.nativePath;
				while (rootPath.length && (rootPath.charAt(rootPath.length - 1) == "\\" || rootPath.charAt(rootPath.length - 1) == "/"))
				{
					rootPath = rootPath.substr(0, rootPath.length - 1);
				};
				row = trust[rootPath + "|" + rel];
				if (row && Math.abs(Number(row.unix) - Math.floor(file.modificationDate.time / 1000)) <= 2
					&& Number(row.length) == file.size && String(row.sha256).toLowerCase() == expect)
				{
					continue;
				};
				got = shaFile(file);
				if (got != expect)
				{
					GameLog.write("[Bootstrap] caution hash " + rel);
				};
			};
		}

		private function readTrust():Object
		{
			var file:File = File.userDirectory.resolvePath("AppData/Roaming/SSF2ModManager/build-trust.json");
			var stream:FileStream;
			var text:String;
			var parsed:Object;
			if (!file.exists)
			{
				return {};
			};
			stream = new FileStream();
			try
			{
				stream.open(file, FileMode.READ);
				text = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				parsed = JSON.parse(text);
				return parsed && parsed.files ? parsed.files : {};
			}
			catch (err:*)
			{
				return {};
			};
			return {};
		}

		private function shaFile(file:File):String
		{
			var stream:FileStream = new FileStream();
			var bytes:ByteArray = new ByteArray();
			stream.open(file, FileMode.READ);
			stream.readBytes(bytes);
			stream.close();
			return Sha256.hex(bytes);
		}

		private function modsAreSafe():Boolean
		{
			var roots:Array = ["expansions"];
			var r:int = 0;
			var bad:String;
			while (r < roots.length)
			{
				bad = firstUnsafe(File.applicationDirectory.resolvePath(String(roots[r])));
				if (bad)
				{
					fail("Unsafe mod:\n" + bad);
					return false;
				};
				r++;
			};
			return true;
		}

		private function firstUnsafe(dir:File):String
		{
			var list:Array;
			var i:int = 0;
			var child:File;
			var bytes:ByteArray;
			var stream:FileStream;
			var text:String;
			if (!dir || !dir.exists || !dir.isDirectory)
			{
				return null;
			};
			list = dir.getDirectoryListing();
			while (i < list.length)
			{
				child = list[i] as File;
				i++;
				if (!child)
				{
					continue;
				};
				if (child.isDirectory)
				{
					if (child.name == "ignore" || child.name == "_template")
					{
						continue;
					};
					text = firstUnsafe(child);
					if (text)
					{
						return text;
					};
					continue;
				};
				if (child.name != "mod.swf")
				{
					continue;
				};
				stream = new FileStream();
				bytes = new ByteArray();
				try
				{
					stream.open(child, FileMode.READ);
					stream.readBytes(bytes);
					stream.close();
				}
				catch (readErr:*)
				{
					return child.nativePath;
				};
				text = swfText(bytes);
				var why:String = SwfGuard.reasons(bytes);
				if (why)
				{
					GameLog.write("[Bootstrap] refused " + child.nativePath + " " + why);
					return child.name;
				};
			};
			return null;
		}

		private function swfText(bytes:ByteArray):String
		{
			var body:ByteArray;
			var kind:String = bytes.readUTFBytes(3);
			if (kind != "CWS")
			{
				bytes.position = 0;
				return bytes.readUTFBytes(bytes.length);
			};
			body = new ByteArray();
			bytes.position = 8;
			bytes.readBytes(body);
			try
			{
				body.uncompress();
			}
			catch (zipErr:*)
			{
			};
			return body.readUTFBytes(body.length);
		}

		private function loadSwf(relPath:String, loader:Loader, onComplete:Function, label:String):void
		{
			var file:File;
			var stream:FileStream;
			var bytes:ByteArray;
			var ctx:LoaderContext;
			file = resolveEngineFile(relPath);
			if (((!(file)) || (!(file.exists))))
			{
				fail("Missing " + relPath + ".\nRun Decompile Engine2 then Compile Engine2, then this shell.");
				return;
			};
			try
			{
				bytes = new ByteArray();
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				stream.readBytes(bytes);
				stream.close();
			}
			catch (ioErr:Error)
			{
				fail("Could not read " + label + ":\n" + ioErr.message);
				return;
			};
			bytes.position = 0;
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onComplete);
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onEngineIOError);
			ctx = new LoaderContext(false, ApplicationDomain.currentDomain);
			try
			{
				ctx.allowCodeImport = true;
			}
			catch (allowErr:*)
			{
			};
			try
			{
				loader.loadBytes(bytes, ctx);
			}
			catch (loadErr:Error)
			{
				fail(label + " loadBytes failed:\n" + loadErr.message);
			};
		}

		private function resolveEngineFile(relPath:String):File
		{
			var a:File;
			try
			{
				a = File.applicationDirectory.resolvePath(relPath);
			}
			catch (err:*)
			{
				a = null;
			};
			return (a);
		}

		private function onEngineIOError(e:IOErrorEvent):void
		{
			fail("Engine IO error:\n" + e.text);
		}

		private function fail(msg:String):void
		{
			GameLog.write("[Bootstrap] " + msg);
			if (m_status)
			{
				m_status.text = msg;
			};
		}
	}
}
