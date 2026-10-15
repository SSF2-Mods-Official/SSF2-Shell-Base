package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Real Expansions — register packs from expansions/<id>/assets.swf.
	 * Roster membership is owned by the CSS editor save. This mod does not append slots.
	 * Engine doors: loadRealExpansionUi, getLibraryMC, instantiateFromResource,
	 * addExtraResource, registerMappedCharacter, acceptCharacterGuid.
	 */
	public class RealExpansionsMod extends Sprite
	{
		private static const SUFFIXES:Array = [
			"allstar_congrats",
			"classic_trophy",
			"charselect",
			"allstar",
			"congrats",
			"classic",
			"select",
			"event",
			"cssp",
			"icon",
			"stock"
		];

		/** Trace UI linkage HIT/MISS for every pack clip lookup. */
		private static const UI_DEBUG:Boolean = false;

		private static var s_packIds:Object = {};
		private static var s_seriesIcon:Object = {};
		private static var s_uiIds:Array = [];

		private var m_host:*;

		public function RealExpansionsMod()
		{
			super();
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			if (host)
			{
				try
				{
					host.patch("acceptCharacterGuid", onAcceptCharacterGuid);
					host.patch("getLibraryMC", function (mcName:String):MovieClip
					{
						return (resolveLibraryMC(mcName));
					});
					host.patch("loadRealExpansionUi", function (onDone:Function):void
					{
						loadRealExpansionUi(onDone);
					});
				}
				catch (patchErr:*)
				{
					trace("[real_expansions] patch failed: " + patchErr);
				};
			};
			autoRegisterPacks();
			trace("[real_expansions] boot — drag-and-drop roster slots packs=" + s_uiIds.length);
		}

		public function onBootEnd():void
		{
			m_host = null;
			s_packIds = {};
			s_seriesIcon = {};
			s_uiIds = [];
			s_dumpedUi = {};
			trace("[real_expansions] onBootEnd");
		}

		private function autoRegisterPacks():void
		{
			var mappings:Object;
			var root:File;
			var listing:Array;
			var i:int;
			var folder:File;
			var id:String;
			var fighter:File;
			var rel:String;
			var RM:Class;
			var uiId:String;
			try
			{
				RM = (EngineRefs.ssf2("util.ResourceManager") as Class);
				mappings = RM["getResourceByID"]("mappings").getProp("metadata");
			}
			catch (mapErr:*)
			{
				trace("[real_expansions] mappings unavailable: " + mapErr);
				return;
			};
			if (((!(mappings)) || (!(mappings.character))))
			{
				return;
			};
			try
			{
				root = File.applicationDirectory.resolvePath("expansions/character");
				if (((!(root)) || (!(root.exists)) || (!(root.isDirectory))))
				{
					return;
				};
				listing = root.getDirectoryListing();
				i = 0;
				while (i < listing.length)
				{
					folder = (listing[i] as File);
					if (((folder) && (folder.isDirectory) && (folder.name.charAt(0) != "_") && folder.resolvePath("assets.swf").exists))
					{
						try
						{
							var MH:Class = (EngineRefs.ssf2("modhost.ModHost") as Class);
							if (((MH) && (MH["folderInfoEnabled"]) && (!(MH["folderInfoEnabled"](folder.nativePath)))))
							{
								i++;
								continue;
							};
						}
						catch (enErr:*)
						{
						};
						id = folder.name.replace(/[^a-zA-Z0-9_]/g, "_");
						if (id)
						{
							uiId = ("ui_tpl_" + id);
							if (m_host)
							{
								m_host.addExtraResource(uiId, (("expansions/character/" + folder.name) + "/assets.swf"));
							};
							if (s_uiIds.indexOf(uiId) < 0)
							{
								s_uiIds.push(uiId);
							};
							s_packIds[id] = uiId;
							noteSeriesIconFromFolder(folder, id);
							fighter = resolveFighterFile(folder, id);
							if (fighter)
							{
								rel = (("expansions/" + folder.name) + "/" + fighter.name);
								ensureCharacterEntry(mappings, id, rel);
								if (((mappings.character[id]) && (mappings.character[id].seriesIcon)))
								{
									s_seriesIcon[id] = String(mappings.character[id].seriesIcon);
								};
								trace("[real_expansions] auto-register " + id + " -> " + rel);
							};
						};
					};
					i++;
				};
			}
			catch (scanErr:*)
			{
				trace("[real_expansions] scan failed: " + scanErr);
			};
		}

		private static function bootLog(msg:String):void
		{
			var line:String;
			var MH:Class;
			line = ("[boot] " + msg);
			try
			{
				MH = (EngineRefs.ssf2("modhost.ModHost") as Class);
				if (((MH) && (MH["appendGameLog"])))
				{
					MH["appendGameLog"](line);
					return;
				};
			}
			catch (hostErr:*)
			{
			};
			trace(line);
		}

		/** Also the loadRealExpansionUi patch; ExpansionResources calls it directly. */
		public static function loadRealExpansionUi(onDone:Function):void
		{
			var host:Class;
			bootLog("real_expansions ui n=" + s_uiIds.length);
			if (s_uiIds.length == 0)
			{
				if (onDone != null)
				{
					onDone();
				};
				return;
			};
			try
			{
				host = (EngineRefs.ssf2("modhost.ModHost") as Class);
				host["ensureResourcesLoaded"](s_uiIds, function ():void
				{
					bootLog("real_expansions ui loaded");
					if (UI_DEBUG)
					{
						trace(("[real_expansions] UI templates loaded: " + s_uiIds.join(",")));
					};
					if (onDone != null)
					{
						onDone();
					};
				}, function ():void
				{
					bootLog("real_expansions ui failed");
					trace("[real_expansions] UI template load failed");
					if (onDone != null)
					{
						onDone();
					};
				});
			}
			catch (loadErr:*)
			{
				trace("[real_expansions] loadRealExpansionUi: " + loadErr);
				if (onDone != null)
				{
					onDone();
				};
			};
		}

		private static function packUiId(id:String):String
		{
			var uiId:*;
			if (!id)
			{
				return (null);
			};
			uiId = s_packIds[id];
			if (((uiId == null) || (uiId == undefined) || (uiId === "")))
			{
				return (null);
			};
			return (String(uiId));
		}

		/** Also the getLibraryMC patch; ExpansionResources calls it directly. */
		public static function resolveLibraryMC(mcName:String):MovieClip
		{
			var i:int;
			var suffix:String;
			var id:String;
			var uiId:String;
			var tagged:String;
			var mc:MovieClip;
			if (!mcName)
			{
				return (null);
			};
			i = 0;
			while (i < SUFFIXES.length)
			{
				suffix = String(SUFFIXES[i]);
				tagged = ("_" + suffix);
				if (((mcName.length > tagged.length) && (mcName.substring((mcName.length - tagged.length)) == tagged)))
				{
					id = mcName.substring(0, (mcName.length - tagged.length));
					uiId = packUiId(id);
					if (uiId)
					{
						mc = instantiatePackClip(uiId, suffix, id, mcName);
						if (mc)
						{
							return (mc);
						};
						if (suffix == "stock")
						{
							mc = tryFolderStockPng(id);
							if (mc)
							{
								return (mc);
							};
						};
					};
					if (shouldUiDebug(mcName, id))
					{
						trace(("[real_expansions] getLibraryMC MISS " + mcName + " uiId=" + uiId));
						if (uiId)
						{
							dumpUiDefinitions(uiId, mcName);
						};
					};
					return (null);
				};
				i++;
			};
			for (id in s_seriesIcon)
			{
				if (String(s_seriesIcon[id]) == mcName)
				{
					uiId = packUiId(id);
					if (uiId)
					{
						mc = instantiatePackClip(uiId, "icon", id, mcName);
						if (mc)
						{
							return (mc);
						};
					};
					if (shouldUiDebug(mcName, id))
					{
						trace(("[real_expansions] seriesIcon MISS " + mcName + " pack=" + id + " uiId=" + uiId));
					};
				};
			};
			return (null);
		}


		private static function tryFolderStockPng(packId:String):MovieClip
		{
			var RM:Class;
			try
			{
				RM = (EngineRefs.ssf2("util.ResourceManager") as Class);
				return ((RM["tryRealExpansionFolderStockMC"](packId) as MovieClip));
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private static var s_dumpedUi:Object = {};

		private static function dumpUiDefinitions(uiId:String, reqName:String):void
		{
			var host:Class;
			if (s_dumpedUi[uiId])
			{
				return;
			};
			s_dumpedUi[uiId] = true;
			try
			{
				host = (EngineRefs.ssf2("modhost.ModHost") as Class);
				host["traceResourceDefinitions"](uiId, reqName);
			}
			catch (err:*)
			{
			};
		}

		private static function instantiatePackClip(uiId:String, suffix:String, packId:String, reqName:String):MovieClip
		{
			var names:Array;
			var ni:int;
			var mc:MovieClip;
			var host:Class;
			names = [suffix, (packId + "_" + suffix), reqName, (suffix.charAt(0).toUpperCase() + suffix.substring(1))];
			try
			{
				host = (EngineRefs.ssf2("modhost.ModHost") as Class);
			}
			catch (hostErr:*)
			{
				return (null);
			};
			ni = 0;
			while (ni < names.length)
			{
				mc = (host["instantiateFromResource"](uiId, String(names[ni])) as MovieClip);
				if (mc)
				{
					if (shouldUiDebug(reqName, packId))
					{
						trace(("[real_expansions] getLibraryMC HIT " + reqName + " -> " + uiId + "." + names[ni]));
					};
					return (mc);
				};
				ni++;
			};
			return (null);
		}

		private static function shouldUiDebug(mcName:String, packId:String):Boolean
		{
			return (UI_DEBUG && Boolean(mcName || packId));
		}

		private function noteSeriesIconFromFolder(folder:File, id:String):void
		{
			var metaFile:File;
			var stream:FileStream;
			var text:String;
			var parsed:Object;
			if (((!(folder)) || (!(id))))
			{
				return;
			};
			try
			{
				metaFile = folder.resolvePath("css_meta.json");
				if (((!(metaFile)) || (!(metaFile.exists))))
				{
					return;
				};
				stream = new FileStream();
				stream.open(metaFile, FileMode.READ);
				text = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				parsed = (JSON.parse(text) as Object);
				if (((parsed) && (parsed.seriesIcon)))
				{
					s_seriesIcon[id] = String(parsed.seriesIcon);
				};
			}
			catch (err:*)
			{
			};
		}

		private function resolveFighterFile(folder:File, id:String):File
		{
			var listing:Array;
			var i:int;
			var file:File;
			var lower:String;
			var preferred:File;
			preferred = folder.resolvePath(id + ".ssf");
			if (preferred.exists)
			{
				return (preferred);
			};
			preferred = folder.resolvePath(id + ".swf");
			if (preferred.exists)
			{
				return (preferred);
			};
			listing = folder.getDirectoryListing();
			i = 0;
			while (i < listing.length)
			{
				file = (listing[i] as File);
				if (((file) && (!(file.isDirectory))))
				{
					lower = file.name.toLowerCase();
					if (((!(lower == "assets.swf")) && (!(lower == "character_template.swf")) && ((lower.lastIndexOf(".ssf") == (file.name.length - 4)) || (lower.lastIndexOf(".swf") == (file.name.length - 4)))))
					{
						return (file);
					};
				};
				i++;
			};
			return (null);
		}

		private function ensureCharacterEntry(mappings:Object, id:String, relFile:String):void
		{
			var entry:Object;
			if (mappings.character[id])
			{
				return;
			};
			entry = {
				"file":relFile,
				"file_pub":relFile
			};
			mappings.character[id] = entry;
			if (m_host)
			{
				m_host.registerMappedCharacter(id, entry);
			};
		}


		private function onAcceptCharacterGuid(resource:*, mapped:*):Boolean
		{
			var file:String;
			var guid:String;
			var chars:Array;
			var cData:Object;
			var mappings:Object;
			var entry:Object;
			var RM:Class;
			if (((!(resource)) || (!(mapped))))
			{
				return (false);
			};
			try
			{
				file = String(((mapped.FileName) || ("")));
				if (file.indexOf("expansions/") != 0)
				{
					return (false);
				};
				if (String(resource.getProp("id")) != String(mapped.ID))
				{
					return (false);
				};
				guid = String(((resource.getProp("guid")) || ("")));
				if (!guid)
				{
					return (false);
				};
				if ("updatePassKey" in mapped)
				{
					mapped.updatePassKey(guid);
				};
				chars = (resource.getProp("characters") as Array);
				if (((chars) && (chars.length > 0) && (chars[0]) && (chars[0].cData)))
				{
					cData = chars[0].cData;
				};
				try
				{
					RM = (EngineRefs.ssf2("util.ResourceManager") as Class);
					mappings = RM["getResourceByID"]("mappings").getProp("metadata");
					if (((mappings) && (mappings.character)))
					{
						entry = mappings.character[mapped.ID];
						if (entry)
						{
							entry.guid = guid;
							if (((cData) && (cData.displayName)))
							{
								entry.name = cData.displayName;
							};
							if (((cData) && (cData.seriesIcon)))
							{
								entry.seriesIcon = cData.seriesIcon;
								s_seriesIcon[mapped.ID] = String(cData.seriesIcon);
							};
						};
					};
				}
				catch (mapErr:*)
				{
				};
				trace("[real_expansions] synced guid for " + mapped.ID);
				return (true);
			}
			catch (err:*)
			{
				trace("[real_expansions] acceptCharacterGuid: " + err);
			};
			return (false);
		}
	}
}
