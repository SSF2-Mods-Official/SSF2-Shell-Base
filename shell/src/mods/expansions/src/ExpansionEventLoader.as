package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
	import ssf2mm.shared.JsonFile;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Scans expansions/events for event packs. A pack is a folder holding one or more .swf
	 * files plus optional previews/ art and series.json, so a downloaded pack can simply be
	 * unzipped into expansions/events. A bare .swf dropped at the top level also works.
	 *
	 * Each pack SWF may declare any number of events via EventPack.eventList2; every entry
	 * is registered. Preview art is read from <pack>/previews/<eventId>.png.
	 */
	public class ExpansionEventLoader
	{
		private var m_host:*;
		private var m_queue:Array;
		private var m_onDone:Function;
		private var m_pending:int;
		private var m_root:File;
		/** Bumped by each scan; loads from an older scan are dropped. */
		private var m_gen:int;

		public function ExpansionEventLoader(host:*)
		{
			m_host = host;
			m_queue = [];
			m_onDone = null;
			m_pending = 0;
			m_root = null;
		}

		public function scanAndLoad(onDone:Function = null):void
		{
			var listing:Array;
			var i:int;
			var entry:File;
			var item:Object;

			m_gen++;
			m_onDone = onDone;
			ExpansionEventRegistry.reset();
			m_queue = [];
			try
			{
				m_root = File.applicationDirectory.resolvePath("expansions/events");
				if (!m_root || !m_root.exists || !m_root.isDirectory)
				{
					finish();
					return;
				};
				listing = m_root.getDirectoryListing();
				i = 0;
				while (i < listing.length)
				{
					entry = listing[i] as File;
					i++;
					if (!entry || isSkipped(entry.name))
					{
						continue;
					};
					if (entry.isDirectory)
					{
						scanPackFolder(entry);
					}
					else if (isSwf(entry.name))
					{
						m_queue.push({"swf": entry, "folder": m_root});
					};
				};
			}
			catch (err:*)
			{
				trace("[event_expansions] scan failed: " + err);
			};
			m_pending = m_queue.length;
			trace("[event_expansions] scan gen=" + m_gen + " packs=" + m_pending);
			if (m_pending <= 0)
			{
				finish();
				return;
			};
			i = 0;
			while (i < m_queue.length)
			{
				item = m_queue[i];
				i++;
				loadPack(item.swf as File, item.folder as File, m_gen);
			};
		}

		private function scanPackFolder(folder:File):void
		{
			var listing:Array;
			var i:int;
			var entry:File;
			try
			{
				loadSeriesManifest(folder);
				listing = folder.getDirectoryListing();
				i = 0;
				while (i < listing.length)
				{
					entry = listing[i] as File;
					i++;
					if (entry && !entry.isDirectory && isSwf(entry.name) && !isSkipped(entry.name))
					{
						m_queue.push({"swf": entry, "folder": folder});
					};
				};
			}
			catch (err:*)
			{
				trace("[event_expansions] scan " + folder.name + ": " + err);
			};
		}

		private function isSwf(name:String):Boolean
		{
			return Boolean(name) && name.length > 4 && name.toLowerCase().lastIndexOf(".swf") == name.length - 4;
		}

		private function isSkipped(name:String):Boolean
		{
			return !name || name.charAt(0) == "_" || name.charAt(0) == ".";
		}

		/** Optional <pack>/series.json: [{ "id", "name", "description", "creator", "events": [...] }]. */
		private function loadSeriesManifest(root:File):void
		{
			var file:File;
			var data:*;
			var list:Array;
			var i:int;
			var info:Object;
			var id:String;

			file = root.resolvePath("series.json");
			if (!file || !file.exists)
			{
				return;
			};
			data = JsonFile.read(file);
			if (data == null)
			{
				trace("[event_expansions] bad json " + file.nativePath);
			};
			list = (data is Array) ? (data as Array) : ((data && data.series is Array) ? (data.series as Array) : null);
			if (!list)
			{
				return;
			};
			i = 0;
			while (i < list.length)
			{
				info = list[i] as Object;
				i++;
				if (!info)
				{
					continue;
				};
				id = info.id ? String(info.id) : null;
				if (!id)
				{
					continue;
				};
				ExpansionEventRegistry.registerSeries(id, info, root);
			};
		}

		private function loadPack(swfFile:File, folder:File, gen:int):void
		{
			var loader:Loader;
			var ctx:LoaderContext;
			var bytes:ByteArray;
			var stream:FileStream;

			loader = new Loader();
			ctx = new LoaderContext(false, new ApplicationDomain(ApplicationDomain.currentDomain));
			try
			{
				ctx.allowCodeImport = true;
			}
			catch (allowErr:*)
			{
			};
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (e:Event):void
			{
				var li:LoaderInfo = e.target as LoaderInfo;
				if (gen != m_gen)
				{
					loader.unloadAndStop();
					return;
				};
				try
				{
					wireChildDomainAPI(li);
					registerFromContent(swfFile, folder, li, gen);
				}
				catch (parseErr:*)
				{
					trace("[event_expansions] parse " + swfFile.name + ": " + parseErr);
				};
				doneOne(gen);
			});
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void
			{
				trace("[event_expansions] load IO " + swfFile.name + ": " + e.text);
				doneOne(gen);
			});
			loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function (e:SecurityErrorEvent):void
			{
				trace("[event_expansions] load security " + swfFile.name + ": " + e.text);
				doneOne(gen);
			});
			try
			{
				stream = new FileStream();
				stream.open(swfFile, FileMode.READ);
				bytes = new ByteArray();
				stream.readBytes(bytes);
				stream.close();
				loader.loadBytes(bytes, ctx);
			}
			catch (err:*)
			{
				trace("[event_expansions] loadBytes " + swfFile.name + ": " + err);
				doneOne(gen);
			};
		}

		/** Register every event declared by the pack, not just the first. */
		private function registerFromContent(swfFile:File, folder:File, li:LoaderInfo, gen:int):void
		{
			var domain:ApplicationDomain;
			var list:Array;
			var entry:Object;
			var info:Object;
			var id:String;
			var classAPI:Class;
			var i:int;

			domain = li ? li.applicationDomain : null;
			list = extractEventList(li ? li.content : null);
			if (!list || list.length == 0)
			{
				trace("[event_expansions] " + swfFile.name + " declares no events");
				return;
			};
			i = 0;
			while (i < list.length)
			{
				entry = list[i] as Object;
				i++;
				if (!entry)
				{
					continue;
				};
				id = entry.id ? String(entry.id) : null;
				if (!id)
				{
					continue;
				};
				classAPI = resolveClassAPI(domain, entry, id);
				if (!classAPI)
				{
					trace("[event_expansions] " + id + ": no classAPI, skipped");
					continue;
				};
				info = {};
				copyProps(entry, info);
				info.id = id;
				info.pack = folder != m_root ? folder.name : swfFile.name;
				ExpansionEventRegistry.registerPack(id, info, folder, classAPI, null);
				loadPreview(folder, id, gen);
			};
		}

		private function resolveClassAPI(domain:ApplicationDomain, entry:Object, id:String):Class
		{
			var matchName:String;
			if (entry.classAPI is Class)
			{
				return entry.classAPI as Class;
			};
			matchName = entry.matchClass ? String(entry.matchClass) : ("EventMode_" + id);
			if (domain && domain.hasDefinition(matchName))
			{
				return domain.getDefinition(matchName) as Class;
			};
			return null;
		}

		/**
		 * Decode <pack>/previews/<id>.png and attach it to the registered event.
		 * Counted against m_pending so scanning only reports done once art is in.
		 */
		private function loadPreview(folder:File, id:String, gen:int):void
		{
			var file:File;
			var loader:Loader;
			var stream:FileStream;
			var bytes:ByteArray;

			if (!folder)
			{
				return;
			};
			file = folder.resolvePath("previews/" + id + ".png");
			if (!file || !file.exists)
			{
				file = folder.resolvePath(id + ".png");
			};
			if (!file || !file.exists)
			{
				return;
			};
			m_pending++;
			loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (e:Event):void
			{
				var bmp:Bitmap;
				try
				{
					bmp = loader.content as Bitmap;
					if (bmp && bmp.bitmapData && gen == m_gen)
					{
						// Clone so BitmapData survives Loader GC.
						ExpansionEventRegistry.setPreview(id, bmp.bitmapData.clone());
					};
					loader.unload();
				}
				catch (imgErr:*)
				{
				};
				doneOne(gen);
			});
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function (e:IOErrorEvent):void
			{
				doneOne(gen);
			});
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				bytes = new ByteArray();
				stream.readBytes(bytes);
				stream.close();
				loader.loadBytes(bytes);
			}
			catch (err:*)
			{
				trace("[event_expansions] preview " + id + ": " + err);
				doneOne(gen);
			};
		}

		/** Wire pack-local SSF2API to the engine SSF2API class (same as ResourceManager.validateResource). */
		private function wireChildDomainAPI(li:LoaderInfo):void
		{
			var domain:ApplicationDomain;
			var ChildAPI:Class;
			var EngineAPI:Class;
			var root:*;
			var initFn:Function;

			domain = li ? li.applicationDomain : null;
			root = li ? li.content : null;
			try
			{
				EngineAPI = EngineRefs.ssf2("api.SSF2API") as Class;
			}
			catch (engErr:*)
			{
				EngineAPI = null;
			};
			if (!EngineAPI)
			{
				trace("[event_expansions] engine SSF2API missing");
				return;
			};
			if (root && ("initAPI" in root) && root["initAPI"] is Function)
			{
				try
				{
					initFn = root["initAPI"] as Function;
					initFn.call(root, EngineAPI);
					return;
				}
				catch (initErr:*)
				{
					trace("[event_expansions] initAPI failed: " + initErr);
				};
			};
			if (domain && domain.hasDefinition("SSF2API"))
			{
				try
				{
					ChildAPI = domain.getDefinition("SSF2API") as Class;
					ChildAPI["init"](EngineAPI);
				}
				catch (domErr:*)
				{
					trace("[event_expansions] domain SSF2API.init: " + domErr);
				};
			};
		}

		private function extractEventList(root:*):Array
		{
			if (!root)
			{
				return null;
			};
			if (root.eventList2 is Array)
			{
				return root.eventList2 as Array;
			};
			if (root.eventList is Array)
			{
				return root.eventList as Array;
			};
			if (root.eventinfo is Array)
			{
				return root.eventinfo as Array;
			};
			return null;
		}

		private function copyProps(src:Object, dst:Object):void
		{
			var k:String;
			if (!src || !dst)
			{
				return;
			};
			for (k in src)
			{
				dst[k] = src[k];
			};
		}

		private function doneOne(gen:int):void
		{
			if (gen != m_gen)
			{
				return;
			};
			m_pending--;
			if (m_pending <= 0)
			{
				finish();
			};
		}

		private function finish():void
		{
			var cb:Function = m_onDone;
			m_onDone = null;
			try
			{
				ExpansionEventRegistry.linkSeriesMembership();
			}
			catch (linkErr:*)
			{
			};
			if (cb != null)
			{
				try
				{
					cb();
				}
				catch (err:*)
				{
					trace("[event_expansions] onDone: " + err);
				};
			};
		}
	}
}
