package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.StageAssetCatalog;

	/** Stage-select slot for a stage asset swap, and the load of the patched stage buffer. */
	public class StageAssetSlot
	{
		private static var s_synced:Boolean = false;

		public static function invalidate():void
		{
			s_synced = false;
			StageAssetCatalog.invalidate();
		}

		public static function sync(mod:StageEditorMod):void
		{
			var found:Object;
			var id:String;
			var ids:Array;
			var i:int;
			var have:Object;
			if (!mod || !mod.m_grid || !mod.m_book)
			{
				return;
			};
			if (!s_synced)
			{
				StageAssetCatalog.reload();
				s_synced = true;
			};
			found = StageAssetCatalog.map();
			ids = mod.m_book.flattenAllPages();
			have = {};
			i = 0;
			while (ids && i < ids.length)
			{
				have[String(ids[i])] = true;
				i++;
			};
			for (id in found)
			{
				if (have[id])
				{
					continue;
				};
				if (!GridRows.tryAdd(mod.m_book.pageRows(0), id, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS))
				{
					GridRows.placeOnFirstOpenPage(mod.m_grid, id, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS, StageEditorMod.MAX_PAGES);
				};
			};
		}

		public static function decorate(child:DisplayObject, id:String):void
		{
			var row:Object;
			if (!child || !id || child["stageAssetBound"])
			{
				return;
			};
			row = StageAssetCatalog.resolve(id);
			if (!row)
			{
				return;
			};
			child["stageAssetBound"] = true;
			ensureSelectable(id, String(row.sourceStage || ""));
			paint(child as MovieClip, String(row.preview || ""));
		}

		/** Reads the stock stage, swaps the pngs, and loads that buffer as this slot. */
		public static function launch(game:*, slotId:String, row:Object):void
		{
			var images:Array;
			var pending:int;
			var loaded:Object;
			var sizes:Object;
			var i:int;
			var item:Object;
			var armed:Boolean;
			if (!game || !row)
			{
				log("launch abort slot=" + slotId);
				return;
			};
			images = row.images as Array;
			if (!images)
			{
				images = [];
			};
			loaded = {};
			sizes = {};
			pending = images.length;
			armed = false;
			log("launch slot=" + slotId + " source=" + row.sourceStage + " images=" + images.length);
			i = 0;
			while (i < images.length)
			{
				item = images[i];
				i++;
				loadPng(item, loaded, sizes, function ():void
				{
					pending--;
					if (armed && pending <= 0)
					{
						finish(game, slotId, row, loaded, sizes);
					};
				});
			};
			armed = true;
			if (pending <= 0)
			{
				finish(game, slotId, row, loaded, sizes);
			};
		}

		private static function loadPng(item:Object, loaded:Object, sizes:Object, done:Function):void
		{
			var path:String;
			var file:File;
			var stream:FileStream;
			var bytes:ByteArray;
			var loader:Loader;
			var id:String;
			if (!item)
			{
				done();
				return;
			};
			id = String(item.characterId);
			sizes[id] = {"width": int(item.width), "height": int(item.height)};
			path = String(item.file || "");
			file = new File(path);
			if (path.indexOf(":") < 0 && path.indexOf("\\") < 0)
			{
				file = File.applicationDirectory.resolvePath(path);
			};
			try
			{
				if (!file.exists)
				{
					done();
					return;
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				bytes = new ByteArray();
				stream.readBytes(bytes);
				stream.close();
				loader = new Loader();
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (e:Event):void
				{
					var bitmap:Bitmap = loader.content as Bitmap;
					if (bitmap && bitmap.bitmapData)
					{
						loaded[id] = bitmap.bitmapData;
					};
					done();
				});
				loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void
				{
					log("png fail id=" + id);
					done();
				});
				loader.loadBytes(bytes);
			}
			catch (err:*)
			{
				log("png fail id=" + id + " " + err);
				done();
			};
		}

		private static function finish(game:*, slotId:String, row:Object, loaded:Object, sizes:Object):void
		{
			var source:String = String(row.sourceStage || "");
			var file:File;
			var stream:FileStream;
			var raw:ByteArray;
			var patched:ByteArray;
			var temp:File;
			var RM:*;
			var res:*;
			try
			{
				file = sourceFile(source);
				if (!file || !file.exists)
				{
					log("launch missing source=" + source);
					return;
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				raw = new ByteArray();
				stream.readBytes(raw);
				stream.close();
				patched = StageAssetSwap.swap(raw, loaded, sizes);
				temp = File.createTempDirectory().resolvePath(slotId + ".swf");
				stream = new FileStream();
				stream.open(temp, FileMode.WRITE);
				stream.writeBytes(patched);
				stream.close();
				RM = EngineRefs.ssf2("util.ResourceManager");
				res = RM && RM.poolHash ? RM.poolHash[slotId] : null;
				if (res)
				{
					if (res.Loaded && res.unload is Function)
					{
						res.unload(true);
					};
					res.UrlOverride = temp.url;
				};
				log("launch file=" + temp.nativePath + " bytes=" + patched.length);
				try
				{
					if (EngineRefs.ModHost && EngineRefs.ModHost.setSessionFlag is Function)
					{
						EngineRefs.ModHost.setSessionFlag("stage_asset.source." + slotId, source);
					};
				}
				catch (flagErr:*)
				{
				};
				StageAssetCatalog.rememberName(slotId, String(row.name || slotId));
				startMatch(game, slotId);
			}
			catch (err:*)
			{
				log("launch fail " + err);
			};
		}

		private static function sourceFile(sourceStage:String):File
		{
			var RM:* = EngineRefs.ssf2("util.ResourceManager");
			var donor:* = RM && RM.getResourceByID is Function ? RM.getResourceByID(sourceStage) : null;
			var loc:String = donor && donor.Location ? String(donor.Location) : "";
			var file:File;
			if (!loc || loc.indexOf("http") == 0)
			{
				return (null);
			};
			file = File.applicationDirectory.resolvePath(loc);
			if (file.exists)
			{
				return (file);
			};
			if (loc.indexOf(":\\") >= 0)
			{
				file = new File(loc);
				if (file.exists)
				{
					return (file);
				};
			};
			return (null);
		}

		private static function ensureSelectable(id:String, sourceStage:String):void
		{
			var RM:*;
			var Res:Class;
			var donor:*;
			var type:int;
			if (!id)
			{
				return;
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				Res = EngineRefs.ssf2("util.Resource") as Class;
				if (!RM || !RM.poolHash || !Res)
				{
					return;
				};
				if (RM.poolHash[id] && RM.poolHash[id].FileName)
				{
					return;
				};
				donor = sourceStage && RM.getResourceByID is Function ? RM.getResourceByID(sourceStage) : null;
				type = donor ? int(donor.Type) : 2;
				RM.poolHash[id] = new Res(id, "stageasset.swf", "stageasset.swf", "", type);
			}
			catch (err:*)
			{
				log("resource fail id=" + id + " " + err);
			};
		}

		private static function paint(clip:MovieClip, path:String):void
		{
			var loader:Loader;
			var boxW:Number;
			var boxH:Number;
			if (!clip || !path || clip.getChildByName("stageAssetIcon"))
			{
				return;
			};
			boxW = clip.width > 8 ? clip.width : 48;
			boxH = clip.height > 8 ? clip.height : 28;
			loader = new Loader();
			loader.name = "stageAssetIcon";
			loader.mouseEnabled = false;
			loader.mouseChildren = false;
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (ev:Event):void
			{
				var content:DisplayObject = loader.content;
				if (!content)
				{
					return;
				};
				content.width = boxW;
				content.height = boxH;
				content.x = -boxW * 0.5;
				content.y = -boxH * 0.5;
				content.name = "stageAssetIcon";
				clip.addChild(content);
				clip.removeChild(loader);
			});
			try
			{
				loader.load(new URLRequest(new File(path).url));
				clip.addChild(loader);
			}
			catch (err:*)
			{
			};
		}

		private static function startMatch(game:*, stageId:String):void
		{
			var GC:*;
			var RM:*;
			var Main:*;
			var MC:*;
			var Utils:*;
			var n:int;
			var i:int;
			GC = EngineRefs.ssf2("controllers.GameController");
			RM = EngineRefs.ssf2("util.ResourceManager");
			Main = EngineRefs.Main;
			MC = EngineRefs.ssf2("controllers.MenuController");
			Utils = EngineRefs.ssf2("util.Utils");
			if (!GC || !RM || !game)
			{
				return;
			};
			GC["isStarted"] = true;
			game["LevelData"]["stage"] = stageId;
			game["LevelData"]["randSeed"] = 1 + int(Math.random() * 999);
			if (Utils && Utils.setRandSeed is Function)
			{
				Utils.setRandSeed(game["LevelData"]["randSeed"]);
			};
			if (Utils && Utils.shuffleRandom is Function)
			{
				Utils.shuffleRandom();
			};
			n = game["PlayerSettings"] ? game["PlayerSettings"].length : 0;
			if (Main && Main.prepRandomCharacters is Function)
			{
				Main.prepRandomCharacters(n);
			};
			RM.queueResources([stageId]);
			i = 1;
			while (i <= n)
			{
				RM.queuePlayerCharacterResource(game["PlayerSettings"][i - 1], i - 1);
				i++;
			};
			RM.load({
				"oncomplete": function (done:* = null):void
				{
					if (MC && MC.disposeAllMenus is Function)
					{
						MC.disposeAllMenus();
					};
					GC.startMatch(game);
				}
			});
		}

		private static function log(msg:String):void
		{
			trace("[stage_asset] " + msg);
			EngineRefs.gameLog("[stage_asset] " + msg);
		}
	}
}
