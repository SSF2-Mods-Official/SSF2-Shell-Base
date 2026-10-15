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
				GameLog.setPath(File.applicationDirectory.resolvePath("data/ssf2mm/game.log").nativePath);
				GameLog.write("[Bootstrap] loading engine1");
			}
			catch (logErr:*)
			{
			};
			stage.align = "";
			stage.scaleMode = StageScaleMode.SHOW_ALL;
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
