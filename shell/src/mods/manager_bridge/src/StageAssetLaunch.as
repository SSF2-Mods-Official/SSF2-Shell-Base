package
{
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.StageAssetCatalog;

	/**
	 * Direct CSS match does not fire STAGE_SELECT. Hold the queue until the
	 * slot file is patched and stage_asset.source is set.
	 */
	internal class StageAssetLaunch
	{
		private static var s_started:Object = {};
		private static var s_ready:Object = {};
		private static var s_failed:Object = {};

		/** True while a swap slot is still being patched. The caller retries. */
		public static function hold(slotId:String):Boolean
		{
			var row:Object;
			if (!slotId)
			{
				return (false);
			};
			row = StageAssetCatalog.resolve(slotId);
			if (!row)
			{
				return (false);
			};
			if (s_ready[slotId] || s_failed[slotId])
			{
				return (false);
			};
			if (!s_started[slotId])
			{
				begin(slotId, row);
			};
			return (true);
		}

		private static function begin(slotId:String, row:Object):void
		{
			var images:Array;
			var loaded:Object;
			var sizes:Object;
			var pending:int;
			var armed:Boolean;
			var i:int;
			var item:Object;
			s_started[slotId] = true;
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
						finish(slotId, row, loaded, sizes);
					};
				});
			};
			armed = true;
			if (pending <= 0)
			{
				finish(slotId, row, loaded, sizes);
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

		private static function finish(slotId:String, row:Object, loaded:Object, sizes:Object):void
		{
			var source:String = String(row.sourceStage || "");
			var file:File;
			var stream:FileStream;
			var raw:ByteArray;
			var patched:ByteArray;
			var temp:File;
			var RM:*;
			var Res:Class;
			var res:*;
			var donor:*;
			var type:int;
			try
			{
				file = sourceFile(source);
				if (!file || !file.exists)
				{
					log("launch missing source=" + source);
					s_failed[slotId] = true;
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
				Res = EngineRefs.ssf2("util.Resource") as Class;
				res = RM && RM.poolHash ? RM.poolHash[slotId] : null;
				if (!res && RM && RM.poolHash && Res)
				{
					donor = RM.getResourceByID is Function ? RM.getResourceByID(source) : null;
					type = donor ? int(donor.Type) : 2;
					res = new Res(slotId, "stageasset.swf", "stageasset.swf", "", type);
					RM.poolHash[slotId] = res;
				};
				if (res)
				{
					if (res.Loaded && res.unload is Function)
					{
						res.unload(true);
					};
					res.UrlOverride = temp.url;
				};
				if (EngineRefs.ModHost && EngineRefs.ModHost.setSessionFlag is Function)
				{
					EngineRefs.ModHost.setSessionFlag("stage_asset.source." + slotId, source);
				};
				StageAssetCatalog.rememberName(slotId, String(row.name || slotId));
				log("launch file=" + temp.nativePath + " bytes=" + patched.length);
				s_ready[slotId] = true;
			}
			catch (err:*)
			{
				s_failed[slotId] = true;
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

		private static function log(msg:String):void
		{
			trace("[stage_asset] " + msg);
			EngineRefs.gameLog("[stage_asset] " + msg);
		}
	}
}
