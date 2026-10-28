package com.sbxmod.paletteMaker
{
	import ssf2mm.shared.JsonFile;
	import ssf2mm.shared.HsvWheel;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.display.DisplayObjectContainer;
	import flash.utils.Dictionary;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.media.SoundMixer;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.display.BitmapData;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	import flash.utils.getQualifiedClassName;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	import flash.net.SharedObject;
	import flash.filters.ColorMatrixFilter;
	import com.mcleodgaming.ssf2.util.PaletteDeep;

    public class PaletteMakerUtils
    {
		public static const DEFAULT_COSTUME_NAME:String = "In-Game";
		public static const NO_RECOLOR_COSTUME_NAME:String = "No Recolor";
		private static const PM_SETTINGS_SO_NAME:String = "ssf2_palette_maker_settings";
		/** CSS: prepend No Recolor when the character has no coded base:true. Default on. */
		public static var cssShowNoRecolorWhenNoBase:Boolean = true;
		private static var cssNoRecolorSettingLoaded:Boolean = false;
		public static const COSTUME_FOLDER:File = File.documentsDirectory.resolvePath("SSF2 Custom Colors");
		internal static const COSTUME_FILE_EXTENSION:String = ".json";
		internal static var costumesDictionary:Dictionary = new Dictionary();
		/** statsName -> Array of catalog indexes. Null until that character is read. */
		private static var favoritesCache:Object = {};
		/** statsName -> shield/grab slot list. Dropped when the catalog or favorites change. */
		internal static var costumeCycleCache:Object = {};
		/** Set by VaultMenu — avoids circular import with PaletteMakerMenu. */
		public static var warmDiscoverHandler:Function = null;
		/** Builds `_unique_sprite_cache` during Manage Costumes warm. */
		public static var warmUniqueHandler:Function = null;
		/** Starts incremental unique warm; returns true when more ENTER_FRAME steps needed. */
		public static var warmUniqueIncrementalStartHandler:Function = null;
		/** One ENTER_FRAME slice of incremental unique warm; returns true while still running. */
		public static var warmUniqueIncrementalStepHandler:Function = null;
		
		public static function init():void 
		{
			var allCharacters:Array;
			var i:int;
			trace("[PaletteMakerUtils] Importing costumes...");
			ensureCssNoRecolorSettingLoaded();
			allCharacters = CacheWarmPreload.listPaletteMakerCharacters();
			i = 0;
			while (i < allCharacters.length)
			{
				if (allCharacters[i] && allCharacters[i] != "random")
				{
					loadCostumeFile(String(allCharacters[i]));
				};
				i++;
			};
		}
		
		public static function loadCostumeFile(statsName:String, options:Object=null):void
		{
			unloadCostumeFile(statsName);
			var costumeFile:URLRequest = new URLRequest(COSTUME_FOLDER.url + "/" + statsName + COSTUME_FILE_EXTENSION);
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(Event.COMPLETE, function(e:Event):void
			{
				try 
				{
					var costumeData:Array = JSON.parse(e.target.data) as Array;
					if (!costumeData)
					{
						costumeData = [];
					};
					for (var ci:int = 0; ci < costumeData.length; ci++)
					{
						costumeData[ci] = repairCostumeData(costumeData[ci]);
					};
					costumesDictionary[statsName] = costumeData;
					if(options && options.onComplete != null) 
					{
						options.onComplete();
					};
					trace("[PaletteMakerUtils] Successful loaded", costumeFile.url);
				}
				catch(e:Error) 
				{
					if(options && options.onParseError != null)
					{
						options.onParseError();
					};
					trace("[PaletteMakerUtils] Parse error in", costumeFile.url);
				};
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void
			{
				if(options && options.onError != null)
				{
					options.onError();
				};
				trace("[PaletteMakerUtils] Error while loading", costumeFile.url);
			});
			loader.load(costumeFile);
		}

		/**
		 * Sync-read Documents costume JSON into memory if missing.
		 * Needed for expansion chars (not in CSS init list at boot) and CSS costume selector.
		 */
		public static function ensureCostumeFileLoaded(statsName:String):Boolean
		{
			var file:File;
			var stream:FileStream;
			var content:String;
			var costumeData:Array;
			var ci:int;
			if (!statsName)
			{
				return false;
			};
			if (costumesDictionary[statsName])
			{
				return true;
			};
			file = COSTUME_FOLDER.resolvePath(statsName + COSTUME_FILE_EXTENSION);
			if (((!(file)) || (!(file.exists))))
			{
				costumesDictionary[statsName] = [];
				return false;
			};
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				content = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				costumeData = (JSON.parse(content) as Array);
				if (!costumeData)
				{
					costumeData = [];
				};
				ci = 0;
				while (ci < costumeData.length)
				{
					costumeData[ci] = repairCostumeData(costumeData[ci]);
					ci++;
				};
				costumesDictionary[statsName] = costumeData;
				trace("[PaletteMakerUtils] Sync-loaded", file.nativePath, "(" + costumeData.length + ")");
				return (costumeData.length > 0);
			}
			catch (err:Error)
			{
				trace("[PaletteMakerUtils] ensureCostumeFileLoaded failed:", statsName, err.message);
				costumesDictionary[statsName] = [];
				return false;
			};
		}
	
		public static function getCostume(statsName:String):Array
		{
			if(!costumesDictionary[statsName])
			{
				return [];
			};
			return costumesDictionary[statsName];
		}

		private static function favoritesFile(statsName:String):File
		{
			return COSTUME_FOLDER.resolvePath(statsName + ".favorites.json");
		}

		public static function favoritesFileExists(statsName:String):Boolean
		{
			var file:File;
			if (!statsName)
			{
				return false;
			};
			file = favoritesFile(statsName);
			return file != null && file.exists;
		}

		/** Catalog indexes the palette menu shows, in menu order. */
		public static function getFavoriteIndexes(statsName:String):Array
		{
			var file:File;
			var stream:FileStream;
			var raw:String;
			var parsed:*;
			var out:Array;
			var i:int;
			var n:int;
			if (!statsName)
			{
				return [];
			};
			if (favoritesCache[statsName] is Array)
			{
				return favoritesCache[statsName];
			};
			out = [];
			file = favoritesFile(statsName);
			if (file.exists)
			{
				try
				{
					parsed = JsonFile.read(file);
					if (parsed is Array)
					{
						i = 0;
						while (i < parsed.length)
						{
							n = int(parsed[i]);
							if (n >= 0)
							{
								out.push(n);
							};
							i++;
						};
					};
				}
				catch (err:Error)
				{
					out = [];
				};
			};
			favoritesCache[statsName] = out;
			return out;
		}

		public static function setFavoriteIndexes(statsName:String, indexes:Array):void
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			var out:Array;
			var seen:Object;
			var i:int;
			var n:int;
			if (!statsName)
			{
				return;
			};
			out = [];
			seen = {};
			i = 0;
			while (indexes && i < indexes.length)
			{
				n = int(indexes[i]);
				if (n >= 0 && !seen[n])
				{
					seen[n] = true;
					out.push(n);
				};
				i++;
			};
			folder = COSTUME_FOLDER;
			if (!folder.exists)
			{
				folder.createDirectory();
			};
			file = favoritesFile(statsName);
			JsonFile.write(file, out);
			favoritesCache[statsName] = out;
			delete costumeCycleCache[statsName];
		}

		public static function addFavoriteIndex(statsName:String, catalogIndex:int):void
		{
			var favs:Array;
			if (!statsName || catalogIndex < 0)
			{
				return;
			};
			favs = getFavoriteIndexes(statsName).concat();
			if (favs.indexOf(catalogIndex) >= 0)
			{
				return;
			};
			favs.push(catalogIndex);
			setFavoriteIndexes(statsName, favs);
		}

		public static function removeFavoriteIndex(statsName:String, catalogIndex:int):void
		{
			var favs:Array;
			var i:int;
			if (!statsName || catalogIndex < 0)
			{
				return;
			};
			favs = getFavoriteIndexes(statsName).concat();
			i = favs.indexOf(catalogIndex);
			if (i < 0)
			{
				return;
			};
			favs.splice(i, 1);
			setFavoriteIndexes(statsName, favs);
		}

		public static function isFavoriteIndex(statsName:String, catalogIndex:int):Boolean
		{
			if (catalogIndex < 0)
			{
				return false;
			};
			return getFavoriteIndexes(statsName).indexOf(catalogIndex) >= 0;
		}

		/** How many leading catalog entries came from the repo on the last successful fetch. */
		public static function getOnlineCostumeCount(statsName:String):int
		{
			var meta:Object;
			meta = ColorVaultSync.getVaultCacheMeta();
			if (meta && statsName && meta[statsName] && meta[statsName].hasOwnProperty("onlineCount"))
			{
				return int(meta[statsName].onlineCount);
			};
			return 0;
		}

		public static function catalogIndexOfReference(statsName:String, costume:Object):int
		{
			var list:Array;
			var i:int;
			if (!costume)
			{
				return -1;
			};
			list = getCostume(statsName);
			i = 0;
			while (list && i < list.length)
			{
				if (list[i] == costume)
				{
					return i;
				};
				i++;
			};
			return -1;
		}

		/**
		 * Shield/grab may land on stock slots and favorited catalog slots.
		 * A catalog costume that is not favorited stays paintable by number, but is not a cycle stop.
		 */
		public static function isCostumeSlotInCycle(statsName:String, slot:int):Boolean
		{
			var origin:int;
			var catalog:Array;
			if (!statsName || slot < 0)
			{
				return true;
			};
			try
			{
				ensureCostumeFileLoaded(statsName);
			}
			catch (err:Error)
			{
			};
			origin = catalogSlotOrigin(statsName);
			if (slot < origin)
			{
				return true;
			};
			catalog = getCostume(statsName);
			if (!catalog || slot >= origin + catalog.length)
			{
				return true;
			};
			return isFavoriteIndex(statsName, slot - origin);
		}

		/** Next shield/grab stop: stock slots in order, then favorites in favorites-file order. */
		public static function stepCostumeCycle(statsName:String, current:int, direction:int):int
		{
			var slots:Array;
			var i:int;
			var pos:int;
			if (!statsName)
			{
				return current;
			};
			slots = buildCostumeCycle(statsName);
			if (!slots || slots.length == 0)
			{
				return current;
			};
			pos = -1;
			i = 0;
			while (i < slots.length)
			{
				if (int(slots[i]) == current)
				{
					pos = i;
					break;
				};
				i++;
			};
			if (pos < 0)
			{
				return direction < 0 ? int(slots[slots.length - 1]) : int(slots[0]);
			};
			pos = pos + (direction < 0 ? -1 : 1);
			if (pos < 0)
			{
				pos = slots.length - 1;
			}
			else if (pos >= slots.length)
			{
				pos = 0;
			};
			return int(slots[pos]);
		}

		private static function buildCostumeCycle(statsName:String):Array
		{
			var cached:Array;
			var slots:Array;
			var seen:Object;
			var count:int;
			var origin:int;
			var catalog:Array;
			var catalogEnd:int;
			var slot:int;
			var favs:Array;
			var i:int;
			var shared:int;
			cached = costumeCycleCache[statsName] as Array;
			if (cached)
			{
				return cached;
			};
			slots = [];
			seen = {};
			try
			{
				ensureCostumeFileLoaded(statsName);
			}
			catch (err:Error)
			{
			};
			try
			{
				count = Ssf2.ResourceManager.getCostumeCount(statsName);
			}
			catch (countErr:Error)
			{
				return [-1];
			};
			origin = catalogSlotOrigin(statsName);
			catalog = getCostume(statsName);
			catalogEnd = origin + (catalog ? catalog.length : 0);
			slot = -1;
			while (slot < count - 1)
			{
				if (slot < origin || slot >= catalogEnd)
				{
					slots.push(slot);
					seen[slot] = true;
				};
				slot++;
			};
			favs = getFavoriteIndexes(statsName);
			i = 0;
			while (favs && i < favs.length)
			{
				shared = origin + int(favs[i]);
				if (catalog && int(favs[i]) < catalog.length && shared >= origin && !seen[shared])
				{
					seen[shared] = true;
					slots.push(shared);
				};
				i++;
			};
			if (slots.length == 0)
			{
				slots.push(-1);
			};
			costumeCycleCache[statsName] = slots;
			return slots;
		}

		/** File slot for a game costume index. Builtin alts occupy 0 .. origin-1. */
		public static function fileIndexForGameSlot(statsName:String, gameSlot:int):int
		{
			return gameSlot - catalogSlotOrigin(statsName);
		}

		/** Partner file slot that shares the opened costume's game index. -1 means that slot is a builtin alt. */
		public static function partnerSaveFileIndex(openedStats:String, openedFileIndex:int, partnerStats:String):int
		{
			return CostumeNetIndex.partnerFileIndex(openedFileIndex, catalogSlotOrigin(openedStats), catalogSlotOrigin(partnerStats));
		}

		/** Picked partner palette stored on the opened costume at this game index. */
		public static function pairedPaletteForSlot(statsName:String, gameSlot:int):Object
		{
			var list:Array;
			var at:int;
			var item:Object;
			if (!statsName || gameSlot < 0)
			{
				return null;
			};
			ensureCostumeFileLoaded(statsName);
			at = fileIndexForGameSlot(statsName, gameSlot);
			list = getCostume(statsName);
			if (!list || at < 0 || at >= list.length)
			{
				return null;
			};
			item = list[at];
			if (item && item.pairedPalette && item.pairedPalette.paletteSwap)
			{
				return item.pairedPalette;
			};
			return null;
		}

		/** First shared-list slot of the documents catalog. Builtin alts occupy 0 .. origin-1, and -1 is the base. */
		private static function catalogSlotOrigin(statsName:String):int
		{
			var costumeData:Object;
			var list:Array;
			var costume:Object;
			var n:int;
			n = 0;
			try
			{
				costumeData = Ssf2.ResourceManager.getResourceByID("misc").getProp("metadata").costume_data;
				list = costumeData && costumeData[statsName] is Array ? costumeData[statsName] as Array : null;
			}
			catch (err:Error)
			{
				list = null;
			};
			if (!list)
			{
				return 0;
			};
			for each (costume in list)
			{
				if (!costume || costume.team || costume.base)
				{
					continue;
				};
				n++;
			};
			return n;
		}

		/** True when a costume with this profile name already exists for the character. */
		public static function costumeProfileExists(statsName:String, costumeName:String):Boolean
		{
			var list:Array;
			var item:Object;
			costumeName = trimString(costumeName);
			if (!statsName || !costumeName)
			{
				return false;
			};
			list = getCostume(statsName) || [];
			for each (item in list)
			{
				if (item && String(item.profile || "") == costumeName)
				{
					return true;
				};
			};
			return false;
		}

		/**
		 * Shared both:true costume list for linked CSS pairs — same objects/order for either form
		 * so CSS/transform don't pair by mismatched per-character indexes.
		 */
		public static function getSharedLinkedFormBothCostumes(statsName:String=null):Array
		{
			var partner:String;
			var aName:String;
			var bName:String;
			var aList:Array;
			var bList:Array;
			var aBoth:Array = [];
			var bBoth:Array = [];
			var item:Object;
			var link:Object;
			var includePrivateAsShared:Boolean;
			if (statsName)
			{
				partner = getLinkedFormPartner(statsName);
				if (!partner)
				{
					return [];
				};
				aName = statsName < partner ? statsName : partner;
				bName = statsName < partner ? partner : statsName;
			}
			else
			{
				// Back-compat default for Zelda/Sheik callers with no arg.
				aName = "zelda";
				bName = "sheik";
			};
			link = getFormLink(statsName || aName);
			// Auto-detected expansion pairs: legacy customs often lack both:true — share them.
			includePrivateAsShared = (link && link.autoDetected == true && link.shareBoth == true);
			aList = getCostume(aName) || [];
			bList = getCostume(bName) || [];
			for each (item in aList)
			{
				if (item && (item.both || includePrivateAsShared))
				{
					aBoth.push(Ssf2.Utils.cloneObject(item));
				};
			};
			for each (item in bList)
			{
				if (item && (item.both || includePrivateAsShared))
				{
					bBoth.push(Ssf2.Utils.cloneObject(item));
				};
			};
			return mergeLinkedFormCostumeLists(aBoth, bBoth);
		}

		/** Non-both customs that stay private to one form. */
		public static function getPrivateLinkedFormCostumes(statsName:String):Array
		{
			var list:Array;
			var out:Array = [];
			var item:Object;
			var link:Object;
			link = getFormLink(statsName);
			// Auto shareBoth pairs already expose all customs via getSharedLinkedFormBothCostumes.
			if (link && link.autoDetected == true && link.shareBoth == true)
			{
				return out;
			};
			list = getCostume(statsName) || [];
			for each (item in list)
			{
				if (item && !item.both)
				{
					out.push(item);
				};
			};
			return out;
		}

		/**
		 * Find CSS costume index (Ssf2.ResourceManager.getCostume num) for a costume identity
		 * on the given character — vault id first, then profile for both:true.
		 */
		public static function findMergedCostumeIndexByIdentity(statsName:String, costume:Object):int
		{
			var vaultId:int;
			var profile:String;
			var merged:Array;
			var i:int;
			var current:int;
			var entry:Object;
			var entryProfile:String;
			if (!statsName || !costume)
			{
				return -1;
			};
			if (statsName == "zelda" || statsName == "sheik")
			{
				trace("[Palette Maker] carry-merge char=" + statsName + " both=" + (costume.both ? 1 : 0));
			};
			vaultId = getColorVaultIdFromCostume(costume);
			if (vaultId >= 0)
			{
				return getMergedCostumeIndexByColorVaultId(statsName, vaultId);
			};
			profile = costume.profile ? String(costume.profile).toLowerCase() : "";
			if (!profile || profile.length == 0)
			{
				return -1;
			};
			try
			{
				merged = Ssf2.ResourceManager.getAllCostumes(statsName, null, true);
			}
			catch (err:Error)
			{
				return -1;
			};
			if (!merged)
			{
				return -1;
			};
			current = 0;
			i = 0;
			while (i < merged.length)
			{
				entry = merged[i];
				if (entry && !entry.team && !entry.base)
				{
					entryProfile = entry.profile ? String(entry.profile).toLowerCase() : "";
					if (entry.both && entryProfile == profile)
					{
						return current;
					};
					current++;
				};
				i++;
			};
			// Stock alts share profile names across Zelda/Sheik (Red, Blue, …) without both:true.
			current = 0;
			i = 0;
			while (i < merged.length)
			{
				entry = merged[i];
				if (entry && !entry.team && !entry.base)
				{
					entryProfile = entry.profile ? String(entry.profile).toLowerCase() : "";
					if (entryProfile && entryProfile == profile)
					{
						return current;
					};
					current++;
				};
				i++;
			};
			return -1;
		}

		/** True when metadata has a coded base:true costume (Mario), not identity-only (Peach, Fox). */
		public static function hasCodedBaseCostume(statsName:String):Boolean
		{
			var list:Array;
			var i:int;
			var entry:Object;
			if (!statsName)
			{
				return false;
			};
			try
			{
				list = Ssf2.ResourceManager.getAllCostumes(statsName, null, true);
			}
			catch (err:Error)
			{
				return false;
			};
			if (!list)
			{
				return false;
			};
			i = 0;
			while (i < list.length)
			{
				entry = list[i];
				if (entry && entry.base && !entry.team)
				{
					return true;
				};
				i++;
			};
			return false;
		}

		public static function ensureCssNoRecolorSettingLoaded():void
		{
			cssNoRecolorSettingLoaded = true;
			cssShowNoRecolorWhenNoBase = true;
		}

		public static function setCssShowNoRecolorWhenNoBase(value:Boolean):void
		{
			cssShowNoRecolorWhenNoBase = true;
			cssNoRecolorSettingLoaded = true;
		}

		/**
		 * Merge custom lists for linked forms: own customs + partner both:true, deduped by vault id then profile.
		 */
		public static function mergeLinkedFormCostumeLists(primary:Array, partnerBoth:Array):Array
		{
			var out:Array;
			var seenVault:Object;
			var seenProfile:Object;
			var item:Object;
			var vaultId:int;
			var profile:String;
			out = [];
			seenVault = {};
			seenProfile = {};
			function consider(costume:Object):void
			{
				if (!costume)
				{
					return;
				};
				vaultId = getColorVaultIdFromCostume(costume);
				profile = costume.profile ? String(costume.profile).toLowerCase() : "";
				if (vaultId >= 0)
				{
					if (seenVault[vaultId])
					{
						return;
					};
					seenVault[vaultId] = true;
				}
				else if (profile.length > 0)
				{
					if (seenProfile[profile])
					{
						return;
					};
					seenProfile[profile] = true;
				};
				out.push(costume);
			};
			for each (item in primary)
			{
				consider(item);
			};
			for each (item in partnerBoth)
			{
				consider(item);
			};
			return out;
		}

		public static function unloadCostumeFile(statsName:String):void
		{
			if(costumesDictionary[statsName])
			{
				delete costumesDictionary[statsName];
				trace("[PaletteMakerUtils] Unloaded", statsName, "costume file!");
			};
		}
	
		public static function getStockIcon(statsName:String, applyDefaultColor:Boolean=false):MovieClip
		{
			var stockIcon:MovieClip;
			var paintName:String;
			paintName = statsName == "gigabowser" ? "bowser" : statsName;
			if (statsName == "gigabowser")
			{
				stockIcon = Ssf2.ResourceManager.getLibraryMC("giga_bowser_stock")
					|| Ssf2.ResourceManager.getLibraryMC("gigabowser_stock")
					|| Ssf2.ResourceManager.getLibraryMC("gbow_stock")
					|| Ssf2.ResourceManager.getLibraryMC("bowser_stock");
			};
			if (!stockIcon)
			{
				stockIcon = Ssf2.ResourceManager.getExpansionStockMC(statsName);
			};
			if (stockIcon)
			{
				if (applyDefaultColor)
				{
					try
					{
						Ssf2.Utils.setColorFilterCharacter(stockIcon, -1, paintName, -1, false);
					}
					catch (paintErr:Error)
					{
					};
				};
				return (stockIcon);
			};
			if (!stockIcon)
			{
				stockIcon = Ssf2.ResourceManager.getLibraryMC(statsName + "_stock");
			};
			if(stockIcon)
			{
				if(applyDefaultColor)
				{
					Ssf2.Utils.setColorFilterCharacter(stockIcon, -1, paintName, -1, false);
				};
				return stockIcon;
			};
			return Ssf2.ResourceManager.getLibraryMC("random_stock");
		}
		
		public static function getSeriesIcon(statsName:String):MovieClip
		{
			var st:*;
			var icon:String;
			try
			{
				st = Ssf2.Stats.getStats(statsName == "gigabowser" ? "bowser" : statsName);
				icon = st && st.SeriesIcon ? String(st.SeriesIcon) : "";
				if (icon)
				{
					return Ssf2.ResourceManager.getLibraryMC(icon) || Ssf2.ResourceManager.getLibraryMC("smash_icon");
				};
			}
			catch (seriesErr:Error)
			{
			};
			return Ssf2.ResourceManager.getLibraryMC("smash_icon");
		}
	
		public static function getPixelArt(statsName:String, applyDefaultColor:Boolean=false):MovieClip
		{
			var PA:MovieClip = Ssf2.ResourceManager.getExpansionPortraitMC(statsName);
			var paintName:String = statsName;
			if (PA)
			{
				if (applyDefaultColor)
				{
					Ssf2.Utils.setColorFilterCharacter(PA, -1, paintName, -1, false);
				};
				return (PA);
			};
			if (statsName == "gigabowser")
			{
				PA = Ssf2.ResourceManager.getLibraryMC("gbow_jab4")
					|| Ssf2.ResourceManager.getLibraryMC("giga_bowser_classic_trophy")
					|| Ssf2.ResourceManager.getLibraryMC("gigabowser_classic_trophy");
				paintName = "bowser";
			};
			if (!PA)
			{
				PA = Ssf2.ResourceManager.getLibraryMC(statsName + "_charselect");
			};
			if(PA)
			{
				if(applyDefaultColor)
				{
					Ssf2.Utils.setColorFilterCharacter(PA, -1, paintName, -1, false);
				};
				return PA;
			};
			return Ssf2.ResourceManager.getLibraryMC("rand_mc");
		}
		
		public static function getCharsCompatibleWithCostumes():Array
		{
			var compatibleList:Array = []; 
            var mappings:Object = Ssf2.ResourceManager.getResourceByID("mappings").getProp("metadata");
            var charactersObj:Object = mappings.character_select_screen.rows;
            var allCharacters:Array = Ssf2.Utils.flatten(charactersObj as Array);
			var expChars:*;
			var expObj:Object;
			var expName:String;
			var ei:int;
			var bowserAt:int;
			for (var i:int = 0; i < allCharacters.length; i++) 
			{
				var statsName:String = allCharacters[i];
				if(statsName !== "random")
				{
					var obj:Object = Ssf2.ResourceManager.getCostume(statsName, null, 1);
					if (obj && ("paletteSwap" in obj)) 
					{
						compatibleList.push(statsName);
					};
				};
			};
			// Loaded expansion packs: primary form only (first characters[] entry).
			// Secondary forms (e.g. Super Vegeta) stay in Stats for transforms.
			ei = 0;
			while (ei < Ssf2.ResourceManager.TotalExpansions)
			{
				expChars = Ssf2.ResourceManager.getExpansionCharacter(ei);
				if (((expChars) && (expChars.length > 0)))
				{
					expObj = expChars[0];
					expName = ((expObj && expObj.cData) ? expObj.cData.statsName : null);
					if (((expName) && (compatibleList.indexOf(expName) < 0)))
					{
						compatibleList.push(expName);
					};
				};
				ei++;
			};
			bowserAt = compatibleList.indexOf("bowser");
			if (bowserAt >= 0 && compatibleList.indexOf("gigabowser") < 0)
			{
				compatibleList.splice(bowserAt + 1, 0, "gigabowser");
			};
			return compatibleList;
		}
		
		/** Vault hover and locker title. Giga is not in Stats. */
		public static function displayNameFor(statsName:String):String
		{
			var st:*;
			if (statsName == "gigabowser")
			{
				return "Giga Bowser";
			};
			try
			{
				st = Ssf2.Stats.getStats(statsName);
				if (st && st.DisplayName)
				{
					return String(st.DisplayName);
				};
			}
			catch (nameErr:Error)
			{
			};
			return statsName ? statsName : "";
		}

		public static function isCharRegistered(statsName:String):Boolean
		{
			if (statsName == "gigabowser")
			{
				return true;
			};
			if (((statsName) && (Ssf2.ResourceManager.isExpansionStatsName(statsName))))
			{
				return (true);
			};
			if(statsName in Ssf2.ResourceManager.getResourceByID("mappings").getProp("metadata").character)
			{
				return true;
			};
			return false;
		}
		
		public static function saveCostume(statsName:String, costumeName:String, paletteData:Object, authorName:String=null, keepColorVaultId:Boolean=true, saveToPartnerForms:Boolean=false, atIndex:int=-1):int 
		{
			var folder:File = COSTUME_FOLDER;
			paletteData = repairCostumeData(paletteData);
			delete paletteData["team"];
			delete paletteData["cssTeam"];
			delete paletteData["base"];
			delete paletteData["noRecolor"];
			delete paletteData["metal"];
			delete paletteData["colorVaultId"];
			delete paletteData["_catalogIndex"];
			delete paletteData["_gameCostumeIndex"];
			delete paletteData["_vaultFile"];
			stripDefaultCostumeKeys(paletteData);
			delete paletteData["both"];
			paletteData["profile"] = costumeName;
			if (statsName && statsName.length > 0)
			{
				paletteData["character"] = statsName;
			};
			authorName = trimString(authorName);
			if (authorName && authorName.length > 0)
			{
				paletteData["author"] = authorName;
				paletteData["info"] = costumeName + " by " + authorName;
			}
			else
			{
				delete paletteData["author"];
				paletteData["info"] = costumeName;
			};
			if (!folder.exists) 
			{
				folder.createDirectory();
			};
			var file:File = folder.resolvePath(statsName + COSTUME_FILE_EXTENSION);
			var stream:FileStream = new FileStream();
			var list:Array;
			if (file.exists) 
			{
				stream.open(file, FileMode.READ);
				var content:String = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				try 
				{
					list = JSON.parse(content) as Array;
				} 
				catch (e:Error) 
				{
					list = [];
				};
			} 
			else 
			{
				list = [];
			};
			if (!list)
			{
				list = [];
			};
			for (var ri:int = 0; ri < list.length; ri++)
			{
				list[ri] = stripDefaultCostumeKeys(repairCostumeData(list[ri]));
			};
			var replaced:Boolean = false;
			var savedIndex:int = -1;
			var pad:Object;
			if (atIndex > list.length)
			{
				while (list.length < atIndex)
				{
					pad = {
						"profile": "",
						"character": statsName,
						"paletteSwap": { "colors": [], "replacements": [] },
						"paletteSwapPA": { "colors": [], "replacements": [] }
					};
					list.push(pad);
				};
			};
			if (atIndex >= 0 && atIndex <= list.length)
			{
				if (atIndex == list.length)
				{
					list.push(paletteData);
				}
				else
				{
					list[atIndex] = paletteData;
				};
				replaced = true;
				savedIndex = atIndex;
			};
			if (!replaced)
			{
			for (var i:int = 0; i < list.length; i++) 
			{
				var item:Object = list[i];
				if (item && item.profile == paletteData.profile)
				{
					list[i] = paletteData; 
					replaced = true;
					savedIndex = i;
					break;
				};
			};
			if (!replaced) 
			{
				list.push(paletteData);
				savedIndex = list.length - 1;
			};
			};
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(stringifyPretty(list));
			stream.close();
			costumesDictionary[statsName] = list;
			if (savedIndex >= 0)
			{
				addFavoriteIndex(statsName, savedIndex);
			};
			if (saveToPartnerForms)
			{
				saveCostumeCloneToPartner(statsName, costumeName, paletteData, authorName, keepColorVaultId);
			};
			trace("[Palette Maker] save char=" + statsName + " index=" + savedIndex);
			return savedIndex;
		}

		/**
		 * Remap a custom costume onto a transform form's source ARGB keys (e.g. Bowser custom → Giga chroma).
		 * Template colors are the form’s pixels / markers; replacements carry the form’s default look.
		 * Custom mappings win when they share a source key, or when they remapped the template’s default look color.
		 */
		public static function remapCostumeOntoFormTemplate(costume:Object, template:Object):Object
		{
			var map:Object;
			var block:Object;
			var templateBlock:Object;
			var i:int;
			var key:String;
			var src:uint;
			var repl:uint;
			var defaultLook:uint;
			var outColors:Array;
			var outRepl:Array;
			var seen:Object;
			var built:Object;
			if (!costume)
			{
				return template;
			};
			if (!template)
			{
				return {
					paletteSwap: costume.paletteSwap,
					paletteSwapPA: costume.paletteSwapPA
				};
			};
			map = {};
			for each (block in [costume.paletteSwap, costume.paletteSwapPA])
			{
				if (!block || !(block.colors is Array) || !(block.replacements is Array))
				{
					continue;
				};
				i = 0;
				while (i < block.colors.length && i < block.replacements.length)
				{
					map[String(uint(block.colors[i]))] = uint(block.replacements[i]);
					i++;
				};
			};
			outColors = [];
			outRepl = [];
			seen = {};
			templateBlock = ((template.paletteSwap) || (template.paletteSwapPA));
			if (templateBlock && (templateBlock.colors is Array) && (templateBlock.replacements is Array))
			{
				i = 0;
				while (i < templateBlock.colors.length && i < templateBlock.replacements.length)
				{
					src = uint(templateBlock.colors[i]);
					defaultLook = uint(templateBlock.replacements[i]);
					key = String(src);
					if (map[key] !== undefined)
					{
						repl = uint(map[key]);
					}
					else
					{
						if (map[String(defaultLook)] !== undefined)
						{
							repl = uint(map[String(defaultLook)]);
						}
						else
						{
							repl = defaultLook;
						};
					};
					outColors.push(src);
					outRepl.push(repl);
					seen[key] = true;
					i++;
				};
			};
			// Keep extra discovered custom keys — they may still appear in form art.
			for (key in map)
			{
				if (seen[key])
				{
					continue;
				};
				outColors.push(uint(key));
				outRepl.push(uint(map[key]));
			};
			built = { "colors": outColors, "replacements": outRepl };
			return {
				paletteSwap: built,
				paletteSwapPA: built
			};
		}

		/** True for palette-maker / vault costumes (not stock base/team/metal/no-recolor slots). */
		public static function isCustomCostume(data:Object):Boolean
		{
			if (!data)
			{
				return false;
			};
			if (isSystemCostumeSlot(data))
			{
				return false;
			};
			if (data.profile || data.author || data.info || data.both)
			{
				return true;
			};
			if (data.hasOwnProperty("colorVaultId") && (data.colorVaultId is Number) && int(data.colorVaultId) >= 0)
			{
				return true;
			};
			return false;
		}

		/** System/stock slots identified by flags only — never by profile display name. */
		public static function isSystemCostumeSlot(data:Object):Boolean
		{
			if (!data)
			{
				return true;
			};
			return data.base === true || data.noRecolor === true
				|| Boolean(data.team) || Boolean(data.cssTeam) || Boolean(data.metal);
		}

		/**
		 * Authored form source keys + default look (from stock Giga Bowser palette #1).
		 * Used so customs can remap onto Giga chroma before character scripts apply stock maps.
		 */
		public static function getFormPaletteTemplate(statsName:String):Object
		{
			var block:Object;
			var partner:String;
			var stockBase:Object;
			// Bowser grow/transform frames already use Giga chroma while statsName is still "bowser".
			if (statsName == "bowser" || statsName == "gigabowser")
			{
				partner = "gigabowser";
			}
			else if (statsName == "ganondorf" || statsName == "beastganon")
			{
				partner = "beastganon";
			}
			else
			{
				partner = statsName;
			};
			if (partner == "gigabowser")
			{
				block = {
					colors: [0xfff37e45,0xffe94b1e,0xff9d290d,0xff5e180d,0xff390f08,0xff220a04,0xff4cff00,0xff39bf00,0xff267f00,0xff133f00,0xff00ffff,0xff00bfbf,0xff007f7f,0xffffe97f,0xffe5bb00,0xff7f6800,0xfff5dc97,0xffecbc7a,0xffb98e5a,0xff916946,0xff4f3c24,0xffb200ff,0xff8200bf,0xff57007f,0xff420060,0xff2b003f,0xff4d97ff,0xff006aff,0xff004fbf,0xff00357f,0xff511e2c,0xff30111a,0xfff1dca3,0xffc3b87a,0xffa99963,0xff856a45,0xff504029,0xffffbfda,0xffff7fb6,0xffff3f92,0xffbf0052,0xff698738,0xff526a2c,0xff253b13,0xff16210c,0xffff00dc,0xffdb00be,0xffbf00a5,0xff7f006e,0xff3f0037,0xffffe08d,0xffffce58,0xfffcb628,0xffd58f25,0xffa36717,0xff6d4811,0xff4f340c,0xff352207,0xff605a59,0xff3b3635,0xff282322,0xff000000,0xff7fffc5,0xff59b88b,0xff397d5d,0xff193327,0xffff8f49,0xffcc723b,0xff99562c,0xff66391d,0xff331c0e,0xffff0000,0xffbf0000,0xff7f0000,0xff3f0000,0xffb47fff,0xff9066cc,0xff6c4c99,0xff322347],
					replacements: [0xfff5590d,0xffca2b0c,0xff871108,0xff480608,0xff390f08,0xff250304,0xff478c73,0xff305a4b,0xff1d3d32,0xff0f211b,0xfff4e2de,0xffdeaea4,0xff928076,0xffac391a,0xffca2b0c,0xff480608,0xffc8c291,0xffaf9b71,0xff826e4d,0xff5e4c36,0xff332a1b,0xfffeffec,0xffd6c8cb,0xff98777f,0xff725058,0xff301c22,0xfff6f6e1,0xffc5c29d,0xff888564,0xff2c2e2b,0xff511e2c,0xff30111a,0xffeaeac4,0xffc5c2a5,0xffa7a37e,0xff767154,0xff343224,0xff61554e,0xff433a35,0xff271f1d,0xff130f0e,0xff37614f,0xff223a2e,0xff13201a,0xff0b130f,0xffc5c2a5,0xffa7a37e,0xff85815a,0xff767154,0xff26281d,0xfff6cc98,0xffdaa96d,0xffae853e,0xff775e34,0xff4a3a22,0xff2c2316,0xff1d1710,0xff17120c,0xff2d2d25,0xff1b1b16,0xff0b0b09,0xff030302,0xff2d2d25,0xff1b1b16,0xff0b0b09,0xff030302,0xffbdad9e,0xff8f7d69,0xff6e6150,0xff3d372e,0xff211e19,0xffe5edff,0xff949faf,0xff6d7076,0xff2e2e33,0xffe6d058,0xffb99736,0xff765f17,0xff392c06]
				};
				return {
					paletteSwap: block,
					paletteSwapPA: block
				};
			};
			if (partner == "beastganon")
			{
				// Template = stock Ganon base source keys (projectile remaps owner PM onto these).
				try
				{
					stockBase = Ssf2.ResourceManager.getCostume("ganondorf", null, -1);
				}
				catch (err:Error)
				{
					stockBase = null;
				};
				if (stockBase && (stockBase.paletteSwap || stockBase.paletteSwapPA))
				{
					return {
						paletteSwap: stockBase.paletteSwap,
						paletteSwapPA: ((stockBase.paletteSwapPA) || (stockBase.paletteSwap))
					};
				};
			};
			return null;
		}

		/**
		 * Shared API for character Exts (BowserExt) and projectile inherit.
		 * costumeIndex uses BowserExt.currentCostume() style: getCostume() + 1 (or team slot).
		 * Prefer the *form* vault/ResourceManager costume at the same CSS slot.
		 * If the form has no custom at that index, return null so Ext keeps stock/authored colors.
		 */
		public static function getTransformCostumePalette(baseStatsName:String, formStatsName:String, costumeIndex:int):Object
		{
			var gameCostumeIndex:int;
			var formName:String;
			var costume:Object;
			var template:Object;
			var remapped:Object;
			formName = formStatsName ? formStatsName : baseStatsName;
			if (!formName)
			{
				return null;
			};
			gameCostumeIndex = costumeIndex - 1;
			try
			{
				costume = Ssf2.ResourceManager.getCostume(formName, null, gameCostumeIndex);
			}
			catch (err:Error)
			{
				costume = null;
			};
			if (!isCustomCostume(costume))
			{
				return null;
			};
			// Optional key alignment onto form template when source keys differ.
			template = getFormPaletteTemplate(formName);
			if (template && template.paletteSwap)
			{
				remapped = remapCostumeOntoFormTemplate(costume, template);
				if (remapped && remapped.paletteSwap)
				{
					return remapped;
				};
			};
			return {
				paletteSwap: costume.paletteSwap,
				paletteSwapPA: ((costume.paletteSwapPA) || (costume.paletteSwap))
			};
		}

		/**
		 * Linked / transform form registry.
		 * shareBoth + cssSelectable: palette-maker dual PA / discover (Zelda↔Sheik only).
		 * carryOnTransform: in-match replaceCharacter / FS form swap palette carry.
		 * Do NOT set shareBoth for FS giants (Giga Bowser) — discover would pixel-scan enormous art.
		 * Explicit entries always win over AUTO_FORM_LINKS (see getFormLink).
		 */
		private static const LINKED_FORM_LINKS:Object = {
			"zelda": { partner: "sheik", scanStatsName: "zelda", shareBoth: false, carryOnTransform: false, combinePalette: false, cssSelectable: true },
			"sheik": { partner: "zelda", scanStatsName: "zelda", shareBoth: false, carryOnTransform: false, combinePalette: false, cssSelectable: true },
			"bowser": { partner: "gigabowser", scanStatsName: "bowser", shareBoth: false, carryOnTransform: false, combinePalette: false, cssSelectable: false },
			"gigabowser": { partner: "bowser", scanStatsName: "bowser", shareBoth: false, carryOnTransform: false, combinePalette: false, cssSelectable: false },
			"wario": { partner: "Wario_Man", scanStatsName: "wario", shareBoth: false, carryOnTransform: true, combinePalette: false, cssSelectable: false },
			"Wario_Man": { partner: "wario", scanStatsName: "wario", shareBoth: false, carryOnTransform: true, combinePalette: false, cssSelectable: false },
			"sonic": { partner: "supersonic", scanStatsName: "sonic", shareBoth: false, carryOnTransform: true, combinePalette: false, cssSelectable: false },
			"supersonic": { partner: "sonic", scanStatsName: "sonic", shareBoth: false, carryOnTransform: true, combinePalette: false, cssSelectable: false }
		};

		/** Expansion dual forms discovered via DeathSwitch / ForceTransform / NormalStatsID. */
		private static var AUTO_FORM_LINKS:Object = {};
		private static var autoFormLinksReady:Boolean = false;

		/**
		 * Scan expansion packs for sibling forms linked by DeathSwitch / ForceTransform /
		 * NormalStatsID (not SpecialStatsID — that footgun broke Mario deep-paint).
		 * Registers Zelda-shaped shareBoth+carry+combine entries into AUTO_FORM_LINKS.
		 */
		public static function ensureAutoFormLinks(force:Boolean=false):void
		{
			var ei:int;
			var ej:int;
			var forms:Array;
			var expChars:*;
			var expObj:Object;
			var formName:String;
			var data:*;
			var a:*;
			var b:*;
			var id:String;
			var i:int;
			var j:int;
			if (autoFormLinksReady && !force)
			{
				return;
			};
			try
			{
				if (!Ssf2 || !Ssf2.ResourceManager)
				{
					autoFormLinksReady = true;
					return;
				};
			}
			catch (ssf2Err:*)
			{
				autoFormLinksReady = true;
				return;
			};
			AUTO_FORM_LINKS = {};
			ei = 0;
			while (Ssf2.ResourceManager.getExpansionCharacter(ei) != null)
			{
				try
				{
				expChars = Ssf2.ResourceManager.getExpansionCharacter(ei);
				forms = [];
				if (expChars && expChars.length >= 2)
				{
					ej = 0;
					while (ej < expChars.length)
					{
						expObj = expChars[ej];
						formName = ((expObj && expObj.cData) ? String(expObj.cData.statsName || "") : "");
						if (formName)
						{
							data = Ssf2.Stats.getStats(formName, ei);
							if (data && data.StatsName)
							{
								forms.push(data);
							};
						};
						ej++;
					};
				};
				if (forms.length >= 2)
				{
					i = 0;
					while (i < forms.length)
					{
						try
						{
							a = (forms[i] as Object);
							id = a.DeathSwitchID;
							if (id)
							{
								b = findExpansionSiblingForm(forms, id, a.StatsName);
								if (b)
								{
									registerAutoFormPair(a, b);
								};
							};
							id = a.ForceTransformID;
							if (id)
							{
								b = findExpansionSiblingForm(forms, id, a.StatsName);
								if (b)
								{
									registerAutoFormPair(a, b);
								};
							};
							id = a.NormalStatsID;
							if (id && id != a.StatsName)
							{
								b = findExpansionSiblingForm(forms, id, a.StatsName);
								if (b)
								{
									registerAutoFormPair(a, b);
								};
							};
						}
						catch (formErr:*)
						{
							trace("[palette_maker] auto form link fail i=" + ei + " form=" + i + " " + formErr);
						};
						i++;
					};
				};
				}
				catch (expErr:*)
				{
					trace("[palette_maker] auto form link fail i=" + ei + " " + expErr);
				};
				ei++;
			};
			autoFormLinksReady = true;
		}

		private static function findExpansionSiblingForm(forms:Array, id:String, excludeStats:String):*
		{
			var i:int;
			var f:*;
			var linkage:String;
			if (!id || !forms)
			{
				return null;
			};
			i = 0;
			while (i < forms.length)
			{
				f = (forms[i] as Object);
				if (f && f.StatsName != excludeStats)
				{
					linkage = linkageId(f);
					if (f.StatsName == id || (linkage && linkage == id))
					{
						return f;
					};
				};
				i++;
			};
			return null;
		}

		private static function registerAutoFormPair(a:*, b:*):void
		{
			var scan:String;
			var aName:String;
			var bName:String;
			if (!a || !b || !a.StatsName || !b.StatsName || a.StatsName == b.StatsName)
			{
				return;
			};
			aName = a.StatsName;
			bName = b.StatsName;
			// Prefer NormalStatsID when it names one of the pair (base form).
			scan = null;
			if (a.NormalStatsID && (a.NormalStatsID == aName || a.NormalStatsID == bName))
			{
				scan = a.NormalStatsID;
			}
			else if (b.NormalStatsID && (b.NormalStatsID == aName || b.NormalStatsID == bName))
			{
				scan = b.NormalStatsID;
			}
			else
			{
				scan = (aName < bName) ? aName : bName;
			};
			putAutoFormLink(aName, bName, scan);
			putAutoFormLink(bName, aName, scan);
			if (linkageId(a) && linkageId(a) != aName)
			{
				putAutoFormLink(linkageId(a), bName, scan);
			};
			if (linkageId(b) && linkageId(b) != bName)
			{
				putAutoFormLink(linkageId(b), aName, scan);
			};
		}

		/** CharacterData exposes LinkageID2 and LinkageIDSpecial. LinkageID is not a property and throws Error #1065. */
		private static function linkageId(stats:*):String
		{
			if (!stats)
			{
				return "";
			};
			try
			{
				if (stats.LinkageID2)
				{
					return String(stats.LinkageID2);
				};
			}
			catch (id2Err:*)
			{
			};
			try
			{
				if (stats.LinkageIDSpecial)
				{
					return String(stats.LinkageIDSpecial);
				};
			}
			catch (specialErr:*)
			{
			};
			return "";
		}

		private static function putAutoFormLink(statsName:String, partner:String, scanStatsName:String):void
		{
			if (!statsName || !partner)
			{
				return;
			};
			// Never overwrite an explicit registry key in AUTO (getFormLink prefers explicit anyway).
			if (LINKED_FORM_LINKS[statsName])
			{
				return;
			};
			AUTO_FORM_LINKS[statsName] = {
				partner: partner,
				scanStatsName: scanStatsName,
				shareBoth: false,
				carryOnTransform: true,
				combinePalette: false,
				cssSelectable: true,
				autoDetected: true
			};
		}

		public static function getFormLink(statsName:String):Object
		{
			if (!statsName)
			{
				return null;
			};
			try
			{
				ensureAutoFormLinks();
			}
			catch (scanErr:*)
			{
				trace("[palette_maker] auto form scan " + scanErr);
			};
			// Explicit registry always wins — do NOT auto-link every SpecialStatsID fighter.
			if (LINKED_FORM_LINKS[statsName])
			{
				return LINKED_FORM_LINKS[statsName];
			};
			return AUTO_FORM_LINKS[statsName];
		}

		/** CSS dual-portrait linked forms (Zelda↔Sheik). Customs stay per-form JSON; pair by slot index. */
		public static function isLinkedFormPair(statsName:String):Boolean
		{
			var link:Object = getFormLink(statsName);
			return link != null && link.cssSelectable == true;
		}

		/** Any registered/auto transform or CSS linked form. */
		public static function isFormLinked(statsName:String):Boolean
		{
			return getFormLink(statsName) != null;
		}

		/** Bowser's final form uses stock reapplyCostume. The inject door stays off. */
		public static function engineFormLinked(statsName:String):Boolean
		{
			if (LinkedFormPaint.matchUsesStockTransform(statsName))
			{
				return false;
			};
			return isFormLinked(statsName);
		}

		public static function shouldCarryCostumeOnTransform(fromStats:String, toStats:String):Boolean
		{
			var link:Object;
			var toLink:Object;
			var carry:Boolean;
			if (!fromStats || !toStats || fromStats == toStats)
			{
				trace("[Palette Maker] carry from=" + fromStats + " to=" + toStats + " result=false");
				return false;
			};
			ensureAutoFormLinks();
			link = getFormLink(fromStats);
			if (!link || link.carryOnTransform != true)
			{
				trace("[Palette Maker] carry from=" + fromStats + " to=" + toStats + " result=false");
				return false;
			};
			if (String(link.partner) == toStats || getLinkedFormPartner(toStats) == fromStats)
			{
				trace("[Palette Maker] carry from=" + fromStats + " to=" + toStats + " result=true");
				return true;
			};
			// DeathSwitch may pass linkage id; partner row may alias linkage → base.
			toLink = getFormLink(toStats);
			if (toLink && toLink.carryOnTransform == true)
			{
				if (String(toLink.partner) == fromStats)
				{
					trace("[Palette Maker] carry from=" + fromStats + " to=" + toStats + " result=true");
					return true;
				};
				if (link.scanStatsName && toLink.scanStatsName && String(link.scanStatsName) == String(toLink.scanStatsName))
				{
					trace("[Palette Maker] carry from=" + fromStats + " to=" + toStats + " result=true");
					return true;
				};
			};
			carry = false;
			trace("[Palette Maker] carry from=" + fromStats + " to=" + toStats + " result=" + carry);
			return carry;
		}

		public static function shouldCombineFormPalette(statsName:String):Boolean
		{
			var link:Object = getFormLink(statsName);
			return link != null && link.combinePalette == true;
		}

		public static function getLinkedFormPartner(statsName:String):String
		{
			var link:Object = getFormLink(statsName);
			return link ? String(link.partner) : null;
		}

		/** Unique-sprite / SWF scan target for linked forms. */
		public static function getUniqueSpriteScanStatsName(statsName:String):String
		{
			var link:Object = getFormLink(statsName);
			if (link && link.scanStatsName)
			{
				return String(link.scanStatsName);
			};
			return statsName;
		}

		/** Stable discover-cache key for a linked pair (shared either direction). */
		public static function getLinkedDiscoverCacheKey(statsName:String):String
		{
			var partner:String = getLinkedFormPartner(statsName);
			var a:String;
			var b:String;
			if (!partner)
			{
				return statsName;
			};
			a = statsName < partner ? statsName : partner;
			b = statsName < partner ? partner : statsName;
			return a + "_" + b + "_linked";
		}

		/** Canonical on-disk discover cache key (linked CSS pairs share one file). */
		public static function getDiscoverCacheKey(statsName:String):String
		{
			return isLinkedFormPair(statsName)
				? getLinkedDiscoverCacheKey(statsName)
				: statsName;
		}

		/** Strip identity tint/matrix keys so exports stay lean. */
		public static function stripDefaultCostumeKeys(costume:Object):Object
		{
			var defaults:Object;
			var key:String;
			var fx:Object;
			if (!costume)
			{
				return costume;
			};
			defaults = {
				hue: 0,
				saturation: 0,
				brightness: 0,
				contrast: 0,
				fxHue: 0,
				fxSaturation: 0,
				fxBrightness: 0,
				fxContrast: 0,
				redMultiplier: 1,
				greenMultiplier: 1,
				blueMultiplier: 1,
				alphaMultiplier: 1,
				redOffset: 0,
				greenOffset: 0,
				blueOffset: 0,
				alphaOffset: 0
			};
			for (key in defaults)
			{
				if (costume.hasOwnProperty(key) && (costume[key] is Number) && Number(costume[key]) == Number(defaults[key]))
				{
					delete costume[key];
				};
			};
			fx = costume.paletteSwapFX;
			if (fx && (fx.colors is Array) && (fx.colors as Array).length == 0)
			{
				delete costume.paletteSwapFX;
			};
			FxRecolorUtils.stripFxGroups(costume);
			return costume;
		}

		/**
		 * Explicit "Save to both forms": clone current costume into partner vault at matching
		 * profile / vault id. Later edits to one form do not auto-sync.
		 */
		private static function saveCostumeCloneToPartner(statsName:String, costumeName:String, paletteData:Object, authorName:String, keepColorVaultId:Boolean):void
		{
			var partner:String = getLinkedFormPartner(statsName);
			var clone:Object;
			if (!partner || !paletteData)
			{
				return;
			};
			clone = repairCostumeData(Ssf2.Utils.cloneObject(paletteData));
			delete clone["both"];
			delete clone["team"];
			delete clone["base"];
			stripDefaultCostumeKeys(clone);
			// Recurse with saveToPartnerForms=false to avoid ping-pong.
			saveCostume(partner, costumeName, clone, authorName, keepColorVaultId, false);
		}

		/**
		 * Costume slot index for Ssf2.ResourceManager.getCostume (skips team/base like game indexing).
		 * Returns -1 if not found.
		 */
		public static function getMergedCostumeIndexByColorVaultId(statsName:String, vaultId:int):int
		{
			var merged:Array;
			var i:int;
			var current:int;
			var costume:Object;
			try
			{
				merged = Ssf2.ResourceManager.getAllCostumes(statsName, null, true);
			}
			catch (err:Error)
			{
				return -1;
			};
			if (!merged)
			{
				return -1;
			};
			current = 0;
			i = 0;
			while (i < merged.length)
			{
				costume = merged[i];
				if (costume && !costume.team && !costume.base)
				{
					if (costume.hasOwnProperty("colorVaultId") && int(costume.colorVaultId) == vaultId)
					{
						return current;
					};
					current++;
				};
				i++;
			};
			return -1;
		}

		/** Read colorVaultId from a costume object, or -1 if absent. */
		public static function getColorVaultIdFromCostume(costume:Object):int
		{
			if (costume && costume.hasOwnProperty("colorVaultId") && (costume.colorVaultId is Number))
			{
				return int(costume.colorVaultId);
			};
			return -1;
		}

		/**
		 * Online: a remote player's index past stock + Color Vault catalog is their own local costume,
		 * which this PC does not have, so it becomes base (-1). The local player keeps theirs.
		 */
		public static function applyResolvedCostumeToSetting(setting:*, statsName:String=null, isLocal:Boolean=true):void
		{
			var stats:String;
			var from:int;
			var to:int;
			var list:Array;
			var custom:Array;
			var online:int;
			if (!setting || isLocal)
			{
				return;
			};
			stats = statsName ? statsName : resolveStatsNameFromSetting(setting);
			from = int(setting.costume);
			if (!stats || from < 0)
			{
				return;
			};
			try
			{
				list = Ssf2.ResourceManager.getMergedCostumeList(stats) as Array;
				custom = getCostume(stats);
				online = getOnlineCostumeCount(stats);
				to = CostumeNetIndex.resolve(from, list, (list ? list.length : 0) - (custom ? custom.length : 0), online, false);
				if (to != from)
				{
					setting.costume = to;
				};
				trace("[palette_maker] net costume char=" + stats + " idx=" + from + "->" + to + " online=" + online);
			}
			catch (err:Error)
			{
				trace("[palette_maker] net costume failed char=" + stats + ": " + err.message);
			};
		}

		/** True once a Color Vault fetch for this character has finished (onlineCount may be 0). */
		public static function hasOnlineCostumeCount(statsName:String):Boolean
		{
			var meta:Object = ColorVaultSync.getVaultCacheMeta();
			return Boolean(meta && statsName && meta[statsName] && meta[statsName].hasOwnProperty("onlineCount"));
		}

		private static function resolveStatsNameFromSetting(setting:*):String
		{
			if (!setting || !setting.character || setting.character == "random")
			{
				return null;
			};
			if (setting.character == "xp")
			{
				try
				{
					return Ssf2.Stats.getStats("xp", setting.expansion).StatsName;
				}
				catch (err:Error)
				{
					return null;
				};
			};
			return setting.character;
		}

		/**
		 * After online importSettings: fetch the Color Vault catalog for any match character never synced,
		 * then map each remote player's local-made costume index to base (applyResolvedCostumeToSetting).
		 */
		public static function resolvePlayerSettingsCostumes(settings:*, onComplete:Function=null):void
		{
			var i:int;
			var setting:*;
			var statsName:String;
			var pending:Array;
			var remaining:int;
			var charName:String;
			var localId:int = -1;
			function finalizeResolve():void
			{
				i = 0;
				while (i < settings.length)
				{
					applyResolvedCostumeToSetting(settings[i] as Object, null, i + 1 == localId);
					i++;
				};
				if (onComplete != null)
				{
					onComplete();
				};
			};
			if (!settings)
			{
				if (onComplete != null)
				{
					onComplete();
				};
				return;
			};
			try
			{
				localId = int(Ssf2.MultiplayerManager.PlayerID);
			}
			catch (idErr:Error)
			{
				localId = -1;
			};
			pending = [];
			i = 0;
			while (i < settings.length)
			{
				setting = settings[i] as Object;
				if (setting && Ssf2.MultiplayerManager.Connected)
				{
					statsName = resolveStatsNameFromSetting(setting);
					if (statsName && !hasOnlineCostumeCount(statsName) && pending.indexOf(statsName) < 0)
					{
						pending.push(statsName);
					};
				};
				i++;
			};
			trace("[palette_maker] net costume resolve players=" + settings.length + " localId=" + localId + " unsynced=" + pending.join(","));
			if (pending.length == 0 || !Ssf2.MultiplayerManager.Connected)
			{
				finalizeResolve();
				return;
			};
			remaining = pending.length;
			for each (charName in pending)
			{
				(function(fetchName:String):void
				{
					ColorVaultSync.fetchColorVaultCostumes(fetchName, {
						"upsert": true,
						"skipIfUnchanged": true,
						"onComplete": function(list:Array):void
						{
							remaining--;
							if (remaining <= 0)
							{
								finalizeResolve();
							};
						},
						"onError": function():void
						{
							remaining--;
							if (remaining <= 0)
							{
								finalizeResolve();
							};
						},
						"onParseError": function():void
						{
							remaining--;
							if (remaining <= 0)
							{
								finalizeResolve();
							};
						}
					});
				})(charName);
			};
		}

		/**
		 * Hold the 0-100% bar while the catalog is checked.
		 * Returns true and calls onDone when the check finishes.
		 */
		public static function syncDuringLoad(onProgress:Function, onDone:Function):Boolean
		{
			ColorVaultSync.preloadProgressFn = onProgress;
			ColorVaultSync.preloadDoneFn = onDone;
			if (onProgress != null)
			{
				onProgress(0);
			};
			ColorVaultSync.armPreloadIndexTimer();
			ColorVaultSync.ensureVaultRootFileIndex(function(index:Object):void
			{
				var any:Boolean = false;
				var key:String;
				if (ColorVaultSync.preloadDoneFn == null)
				{
					return;
				};
				if (index)
				{
					for (key in index)
					{
						any = true;
						break;
					};
				};
				if (!any)
				{
					ColorVaultSync.finishPreload();
					return;
				};
				ColorVaultSync.ensureExpansionVaultBundle(function():void
				{
					ColorVaultSync.stopPreloadIndexTimer();
					if (ColorVaultSync.preloadDoneFn == null)
					{
						return;
					};
					preloadAllColorVaultCostumes();
				});
			});
			return true;
		}

		internal static function simpleContentHash(raw:String):String
		{
			return fnv1aHex(raw);
		}

		/** Full FNV-1a of the whole string. Used for skip-rewrite and for palette equality. */
		internal static function fnv1aHex(value:String):String
		{
			var hash:uint = 2166136261;
			var i:int = 0;
			var n:int;
			var c:uint;
			if (!value)
			{
				return "0";
			};
			n = value.length;
			if (n == 0)
			{
				return "0";
			};
			while (i < n)
			{
				c = uint(value.charCodeAt(i)) & 0xFFFF;
				hash ^= c;
				hash = uint(hash * 16777619);
				i++;
			};
			return hash.toString(16);
		}

		private static function paletteBlockKey(block:Object):String
		{
			var colors:Array;
			var repls:Array;
			var parts:Array;
			var i:int;
			var n:int;
			if (!block)
			{
				return "";
			};
			colors = block.colors as Array;
			repls = block.replacements as Array;
			if (!colors && !repls)
			{
				return "";
			};
			n = colors ? colors.length : 0;
			if (repls && repls.length > n)
			{
				n = repls.length;
			};
			parts = [];
			i = 0;
			while (i < n)
			{
				parts.push(String(colors && i < colors.length ? uint(colors[i]) : 0) + ":" + String(repls && i < repls.length ? uint(repls[i]) : 0));
				i++;
			};
			return parts.join(",");
		}

		/** Stable colors+replacements text for both the fighter palette and the portrait palette. */
		public static function paletteSignature(costume:Object):String
		{
			if (!costume)
			{
				return "";
			};
			return paletteBlockKey(costume.paletteSwap) + "#" + paletteBlockKey(costume.paletteSwapPA) + "#" + paletteBlockKey(costume.paletteSwapFX);
		}

		public static function catalogIndexOfCostume(statsName:String, costume:Object):int
		{
			var list:Array;
			var sig:String;
			var i:int;
			var direct:int;
			if (!costume)
			{
				return -1;
			};
			if (costume.hasOwnProperty("_catalogIndex") && (costume._catalogIndex is Number))
			{
				return int(costume._catalogIndex);
			};
			direct = catalogIndexOfReference(statsName, costume);
			if (direct >= 0)
			{
				return direct;
			};
			sig = paletteSignature(costume);
			if (!sig)
			{
				return -1;
			};
			list = getCostume(statsName);
			i = 0;
			while (list && i < list.length)
			{
				if (paletteSignature(list[i]) == sig)
				{
					return i;
				};
				i++;
			};
			return -1;
		}

		public static function normalizeColorVaultCostume(raw:Object):Object
		{
			var costume:Object = repairCostumeData(Ssf2.Utils.cloneObject(raw || {}));
			var infoName:String = null;
			if (costume.hasOwnProperty("info") && costume.info)
			{
				infoName = String(costume.info);
			}
			else if (costume.hasOwnProperty("profile") && costume.profile)
			{
				infoName = String(costume.profile);
			};
			if (!infoName || infoName.length == 0)
			{
				infoName = "Custom Costume";
			};
			costume["info"] = infoName;
			var byIndex:int = infoName.lastIndexOf(" by ");
			var profileName:String = infoName;
			var authorName:String = "";
			if (byIndex != -1)
			{
				profileName = infoName.substring(0, byIndex);
				authorName = infoName.substring(byIndex + 4);
			};
			profileName = trimString(profileName);
			authorName = trimString(authorName);
			if (!profileName || profileName.length == 0)
			{
				profileName = "Custom Costume";
			};
			costume["profile"] = profileName;
			if (authorName && authorName.length > 0)
			{
				costume["author"] = authorName;
			}
			else
			{
				delete costume["author"];
			};
			delete costume["team"];
			delete costume["base"];
			// Preserve colorVaultId if already stamped by fetch (array index).
			if (raw && raw.hasOwnProperty("colorVaultId") && (raw.colorVaultId is Number))
			{
				costume["colorVaultId"] = int(raw.colorVaultId);
			};
			return costume;
		}

		public static function repairCostumeData(costume:Object):Object
		{
			if (!costume)
			{
				costume = {};
			};
			var vaultId:* = null;
			if (costume.hasOwnProperty("colorVaultId") && (costume.colorVaultId is Number))
			{
				vaultId = int(costume.colorVaultId);
			};
			var defaults:Object = {
				hue: 0,
				saturation: 0,
				brightness: 0,
				contrast: 0,
				fxHue: 0,
				fxSaturation: 0,
				fxBrightness: 0,
				fxContrast: 0,
				redMultiplier: 1,
				greenMultiplier: 1,
				blueMultiplier: 1,
				alphaMultiplier: 1,
				redOffset: 0,
				greenOffset: 0,
				blueOffset: 0,
				alphaOffset: 0
			};
			for (var key:String in defaults)
			{
				if (!(costume[key] is Number))
				{
					costume[key] = defaults[key];
				};
			};
			costume.paletteSwap = coercePaletteColors(costume.paletteSwap);
			costume.paletteSwapPA = coercePaletteColors(costume.paletteSwapPA);
			costume.paletteSwapFX = coercePaletteColors(costume.paletteSwapFX);
			FxRecolorUtils.ensureFxGroups(costume);
			var infoName:String = "";
			delete costume["both"];
			if (costume.hasOwnProperty("info") && costume.info)
			{
				infoName = String(costume.info);
			}
			else if (costume.hasOwnProperty("profile") && costume.profile)
			{
				infoName = String(costume.profile);
			};
			if (infoName && infoName.length > 0)
			{
				costume["info"] = infoName;
				var byIndex:int = infoName.lastIndexOf(" by ");
				if (byIndex != -1 && !(costume.hasOwnProperty("author") && costume.author))
				{
					var profileName:String = trimString(infoName.substring(0, byIndex));
					var authorName:String = trimString(infoName.substring(byIndex + 4));
					if (profileName.length > 0)
					{
						costume["profile"] = profileName;
					};
					if (authorName.length > 0)
					{
						costume["author"] = authorName;
					};
				}
				else if (!(costume.hasOwnProperty("profile") && costume.profile))
				{
					costume["profile"] = infoName;
				};
			};
			if (vaultId != null)
			{
				costume["colorVaultId"] = vaultId;
			};
			return costume;
		}

		public static function coercePaletteColors(block:Object):Object
		{
			if (!block)
			{
				return { colors: [], replacements: [] };
			};
			var colorsIn:Array = (block.colors is Array) ? block.colors : [];
			var replsIn:Array = (block.replacements is Array) ? block.replacements : [];
			var colors:Array = [];
			var replacements:Array = [];
			var i:int;
			var n:int = Math.max(colorsIn.length, replsIn.length);
			i = 0;
			while (i < n)
			{
				if (i < colorsIn.length)
				{
					colors.push(coerceColorValue(colorsIn[i]));
				}
				else
				{
					colors.push(coerceColorValue(replsIn[i]));
				};
				if (i < replsIn.length)
				{
					replacements.push(coerceColorValue(replsIn[i]));
				}
				else
				{
					replacements.push(coerceColorValue(colorsIn[i]));
				};
				i++;
			};
			return { colors: colors, replacements: replacements };
		}

		public static function coerceColorValue(value:*):uint
		{
			if (value is String)
			{
				return uint(parseInt(String(value)));
			};
			return uint(value);
		}

		public static function trimString(value:String):String
		{
			if (!value)
			{
				return "";
			};
			return value.replace(/^\s+|\s+$/g, "");
		}

		/** Parse clipboard / pasted costume JSON (single object or one-element array). */
		public static function parseCostumeJsonFromString(text:String):Object
		{
			var trimmed:String;
			var parsed:*;
			var costume:Object;
			trimmed = trimString(text);
			if (!trimmed || trimmed.length == 0)
			{
				return { "ok": false, "error": "Empty JSON text" };
			};
			try
			{
				parsed = JSON.parse(trimmed);
			}
			catch (parseErr:Error)
			{
				return { "ok": false, "error": "JSON parse error: " + parseErr.message };
			};
			if (parsed is Array)
			{
				if ((parsed as Array).length == 0)
				{
					return { "ok": false, "error": "Costume array is empty" };
				};
				costume = (parsed as Array)[0];
			}
			else
			{
				costume = parsed as Object;
			};
			if (!costume || !(costume is Object))
			{
				return { "ok": false, "error": "Expected a costume object" };
			};
			if (!costume.paletteSwap && !costume.paletteSwapPA)
			{
				return { "ok": false, "error": "Missing paletteSwap / paletteSwapPA" };
			};
			costume = repairCostumeData(Ssf2.Utils.cloneObject(costume));
			return { "ok": true, "costume": costume };
		}

		public static function nudgeReplacementIfExtreme(repl:uint, identitySource:* = null):uint
		{
			var rgb:uint = repl & 0xFFFFFF;
			var a:uint = (repl >> 24) & 0xFF;
			var srcRgb:uint;
			if (a == 0)
			{
				return repl;
			};
			if (identitySource != null)
			{
				srcRgb = coerceColorValue(identitySource) & 0xFFFFFF;
				if (rgb == srcRgb)
				{
					return repl;
				};
			};
			if (rgb == 0x000000)
			{
				return (a << 24) | 0x010101;
			};
			if (rgb == 0xFFFFFF)
			{
				return (a << 24) | 0xFEFEFF;
			};
			return repl;
		}

		/**
		 * Vanilla in-place threshold can drop fully transparent replacements when the
		 * source key is opaque. Force opaque alpha in that case.
		 */
		public static function normalizeReplacementAlphaForVanilla(repl:uint, src:uint):uint
		{
			var srcA:uint = (src >> 24) & 0xFF;
			var replA:uint = (repl >> 24) & 0xFF;
			if (srcA == 0xFF && replA == 0)
			{
				return (0xFF << 24) | (repl & 0xFFFFFF);
			};
			return repl;
		}

		public static function formatCostumeDisplayName(profile:String, author:String=null):String
		{
			profile = trimString(profile);
			author = trimString(author);
			if (!profile || profile.length == 0)
			{
				profile = "Custom Costume";
			};
			if (author && author.length > 0)
			{
				return profile + " by " + author;
			};
			return profile;
		}

		public static function extractAuthorFromCostume(costume:Object):String
		{
			var infoName:String;
			var byIndex:int;
			var author:String;
			if (!costume)
			{
				return "";
			};
			if (costume.hasOwnProperty("author") && costume.author)
			{
				return trimString(String(costume.author));
			};
			if (costume.hasOwnProperty("username") && costume.username)
			{
				return trimString(String(costume.username));
			};
			if (costume.hasOwnProperty("creator") && costume.creator)
			{
				return trimString(String(costume.creator));
			};
			infoName = null;
			if (costume.hasOwnProperty("info") && costume.info)
			{
				infoName = String(costume.info);
			}
			else if (costume.hasOwnProperty("profile") && costume.profile)
			{
				infoName = String(costume.profile);
			};
			if (!infoName)
			{
				return "";
			};
			byIndex = infoName.lastIndexOf(" by ");
			if (byIndex == -1)
			{
				return "";
			};
			author = trimString(infoName.substring(byIndex + 4));
			return author;
		}

		private static var fileHashMemo:Object = {};

		/**
		 * FNV-1a of the character file. A copy with a new modification time keeps the same hash.
		 * Empty when the file cannot be read.
		 */
		public static function characterFileHash(statsName:String):String
		{
			var file:File;
			var key:String;
			var stream:FileStream;
			var buf:ByteArray;
			var h0:uint;
			var h1:uint;
			var prime:uint;
			var n:uint;
			var b:int;
			var memoKey:String;
			file = getCharacterResourceFile(statsName);
			if (!file || !file.exists)
			{
				return "";
			};
			try
			{
				memoKey = file.nativePath + "|" + file.size + "|" + file.modificationDate.time;
			}
			catch (keyErr:Error)
			{
				memoKey = file.nativePath;
			};
			if (fileHashMemo.hasOwnProperty(memoKey))
			{
				return String(fileHashMemo[memoKey]);
			};
			h0 = 2166136261;
			h1 = 2166136261 ^ 0x9E3779B9;
			prime = 16777619;
			stream = new FileStream();
			buf = new ByteArray();
			try
			{
				stream.open(file, FileMode.READ);
				while (stream.bytesAvailable > 0)
				{
					n = stream.bytesAvailable > 65536 ? 65536 : stream.bytesAvailable;
					buf.length = 0;
					stream.readBytes(buf, 0, n);
					buf.position = 0;
					while (buf.bytesAvailable > 0)
					{
						b = buf.readUnsignedByte();
						h0 = uint((h0 ^ b) * prime);
						h1 = uint((h1 ^ b) * prime);
					};
				};
				stream.close();
			}
			catch (err:Error)
			{
				try { stream.close(); } catch (closeErr:Error) {};
				return "";
			};
			key = hex8(h0) + hex8(h1);
			fileHashMemo[memoKey] = key;
			return key;
		}

		private static function hex8(n:uint):String
		{
			var s:String;
			s = n.toString(16);
			while (s.length < 8)
			{
				s = "0" + s;
			};
			return s;
		}

		/** Character SWF/SSF modification time, or 0 if unavailable. */
		public static function getCharacterResourceMTime(statsName:String):Number
		{
			var file:File = getCharacterResourceFile(statsName);
			if (file && file.exists)
			{
				try
				{
					return file.modificationDate.time;
				}
				catch (err:Error)
				{
				};
			};
			return 0;
		}

		/** Character .ssf byte size, or 0 if unavailable. Primary freshness check for builtin pack. */
		public static function getCharacterResourceSize(statsName:String):Number
		{
			var file:File = getCharacterResourceFile(statsName);
			if (file && file.exists)
			{
				try
				{
					return file.size;
				}
				catch (err:Error)
				{
				};
			};
			return 0;
		}

		private static function getCharacterResourceFile(statsName:String):File
		{
			var res:*;
			var loc:String;
			var file:File;
			var resId:String;
			if (!statsName)
			{
				return null;
			};
			resId = Ssf2.ResourceManager.getResourceIdForCharacter(statsName);
			try
			{
				res = Ssf2.ResourceManager.getResourceByID(resId, false);
			}
			catch (err:Error)
			{
				res = null;
			};
			if (!res)
			{
				try
				{
					res = Ssf2.ResourceManager.getResourceByID(resId, true);
				}
				catch (err2:Error)
				{
					res = null;
				};
			};
			if (!res)
			{
				return null;
			};
			try
			{
				loc = res.Location;
				if (!loc || loc.indexOf("http") == 0)
				{
					return null;
				};
				file = File.applicationDirectory.resolvePath(loc);
				if (file.exists)
				{
					return file;
				};
			}
			catch (fileErr:Error)
			{
			};
			return null;
		}

		/** Resolve statsName → Resource (handles expansion xp_* pool IDs). */
		public static function getCharacterResource(statsName:String, mustBeLoaded:Boolean=false):*
		{
			var resId:String;
			if (!statsName)
			{
				return null;
			};
			resId = Ssf2.ResourceManager.getResourceIdForCharacter(statsName);
			try
			{
				return Ssf2.ResourceManager.getResourceByID(resId, mustBeLoaded);
			}
			catch (err:Error)
			{
				return null;
			};
		}

		/** Map roster/stats names to pool resource IDs for queueResources. */
		public static function toCharacterResourceIds(statsNames:Array):Array
		{
			var out:Array = [];
			var seen:Object = {};
			var i:int;
			var id:String;
			if (!statsNames)
			{
				return out;
			};
			i = 0;
			while (i < statsNames.length)
			{
				id = Ssf2.ResourceManager.getResourceIdForCharacter(String(statsNames[i]));
				if (((id) && (!(seen[id]))))
				{
					seen[id] = true;
					out.push(id);
				};
				i++;
			};
			return out;
		}

		public static function pickBestColor(colors:Array):uint
		{
			var target:Number = 128;
			var bestColor:uint = colors[0];
			var bestDiff:Number = 9999;
			for each(var color:uint in colors)
			{
				var r:int = (color >> 16) & 0xFF;
				var g:int = (color >> 8) & 0xFF;
				var b:int = color & 0xFF;
				var y:Number = 0.299 * r + 0.587 * g + 0.114 * b;
				if (y >= 90 && y <= 180)
				{
					return color;
				};
				var diff:Number = Math.abs(y - target);
				if (diff < bestDiff)
				{
					bestDiff = diff;
					bestColor = color;
				};
			};
			return bestColor;
		}
		
		/** palette.* doors call these by name on PaletteMakerUtils. */
		public static function preloadAllColorVaultCostumes():void
		{
			ColorVaultSync.preloadAllColorVaultCostumes();
		}

		public static function cacheDebugLog(msg:String):void
		{
			SpriteCacheStore.cacheDebugLog(msg);
		}

		public static function invalidateCharacterCachesBatch(names:Array):void
		{
			SpriteCacheStore.invalidateCharacterCachesBatch(names);
		}

		public static function showPaletteMakerLoadingScreen(statsName:String, show:Boolean):void
		{
			PaletteLoadingScreen.showPaletteMakerLoadingScreen(statsName, show);
		}

		/**
		 * The stock grid confirms whichever icon is under the cursor when it appears.
		 * Ignore that click until the mouse has had a moment to be released.
		 */
		public static function holdCostumeGrid(menu:*):void
		{
			var sub:DisplayObjectContainer;
			var i:int;
			var child:DisplayObject;
			var grid:DisplayObject;
			if (!menu)
			{
				return;
			};
			try
			{
				menu.resetControlsLetGo(true);
			}
			catch (letGoErr:Error)
			{
			};
			sub = menu.SubMenu as DisplayObjectContainer;
			if (!sub)
			{
				return;
			};
			grid = null;
			i = 0;
			while (i < sub.numChildren)
			{
				child = sub.getChildAt(i);
				if (child.x == -295 && child.y == -120)
				{
					grid = child;
				};
				i++;
			};
			if (!grid)
			{
				return;
			};
			trace("[PaletteMakerUtils] costume grid hold");
			MovieClip(grid).mouseEnabled = false;
			MovieClip(grid).mouseChildren = false;
			setTimeout(function():void
			{
				MovieClip(grid).mouseEnabled = true;
				MovieClip(grid).mouseChildren = true;
				try
				{
					menu.resetControlsLetGo(true);
				}
				catch (armErr:Error)
				{
				};
			}, 400);
		}

		public static function startPaletteMakerFreshnessCheck(onComplete:Function):void
		{
			CacheWarmPreload.startPaletteMakerFreshnessCheck(onComplete);
		}

		public static function cancelPaletteMakerFreshnessCheck():void
		{
			CacheWarmPreload.cancelPaletteMakerFreshnessCheck();
		}

		public static function startPaletteMakerPreload(options:Object = null):void
		{
			CacheWarmPreload.startPaletteMakerPreload(options);
		}

		/** Live disable: stop every pump, timer and input swallow this class added to the game root. */
		public static function shutdown():void
		{
			var overlay:Boolean = CacheWarmPreload.cacheWarmOverlay != null;
			cancelPaletteMakerFreshnessCheck();
			ColorVaultSync.stopPreloadIndexTimer();
			PaletteLoadingScreen.cancelLoadingScreenEarlyDismiss();
			CacheWarmPreload.discoverPreloadRunning = false;
			CacheWarmPreload.discoverPreloadOnProgress = null;
			CacheWarmPreload.discoverPreloadOnComplete = null;
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, CacheWarmPreload.pumpDiscoverPreload);
			};
			if (overlay)
			{
				CacheWarmPreload.dismissCacheWarmBlockingUI();
			}
			else if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(KeyboardEvent.KEY_DOWN, CacheWarmPreload.swallowCacheWarmKey, true);
				Ssf2.Main.Root.stage.removeEventListener(KeyboardEvent.KEY_UP, CacheWarmPreload.swallowCacheWarmKey, true);
			};
			trace("[palette_maker] utils shutdown overlay=" + overlay);
		}
		
		public static function setTint(mc:MovieClip, color:uint):void
		{
			var ct:ColorTransform = mc.transform.colorTransform;
			ct.color = color;
			mc.transform.colorTransform = ct;
		}
		
		public static function fadeIn(mc:MovieClip, duration:int):void 
		{
			mc.alpha = 0;
			var startTime:int = getTimer();
			mc.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			function onEnterFrame(e:Event):void
			{
				var elapsed:int = getTimer() - startTime;
				var progress:Number = Math.min(elapsed / duration, 1);
				mc.alpha = progress;
				if (progress >= 1) 
				{
					mc.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
				};
			};
		}
		
		public static function ensureFront(mc1:DisplayObject, mc2:DisplayObject):void
		{
            if (mc1.parent != null && mc2.parent != null) 
			{
                mc1.parent.swapChildren(mc1, mc1.parent.getChildAt(mc1.parent.numChildren - 1));
                mc2.parent.swapChildren(mc2, mc2.parent.getChildAt(mc2.parent.numChildren - 1));
                var parent1:DisplayObjectContainer = mc1.parent;
                var parent2:DisplayObjectContainer = mc2.parent;
                if (parent1.parent != null && parent2.parent != null) 
				{
                    parent1.parent.swapChildren(parent1, parent1.parent.getChildAt(parent1.parent.numChildren - 1));
                    parent2.parent.swapChildren(parent2, parent2.parent.getChildAt(parent2.parent.numChildren - 1));
                }
            }
        }
		
		public static function removeAllChildrenMC(mc:MovieClip):MovieClip
		{
			if (mc.numChildren > 0) 
			{ 
				while(mc.numChildren > 0)
				{ 
					mc.removeChildAt(0); 
				};
			};
			return mc;
		}
		
		internal static function stringifyPretty(obj:*, indent:String = " ", level:int = 0):String
		{
			var result:String = "";
			var tabs:String = "";
			for (var i:int = 0; i < level; i++)
			{
				tabs += indent;
			};
			if (obj == null)
			{
				result += "null";
			}
			else if (obj is Number || obj is int || obj is uint)
			{
				// Filter fields and other scalars must stay numeric (AS3: Number is Object).
				result += String(obj);
			}
			else if (obj is Boolean)
			{
				result += obj ? "true" : "false";
			}
			else if (obj is String)
			{
				result += "\"" + obj + "\"";
			}
			else if (obj is Array)
			{
				var arr:Array = obj as Array;
				result += "[";
				for (var ai:int = 0; ai < arr.length; ai++)
				{
					var item:* = arr[ai];

					if (item is Number || item is int || item is uint)
					{
						result += "\"0x" + uint(item).toString(16).toUpperCase() + "\"";
					}
					else if (item is String)
					{
						result += "\"" + item + "\"";
					}
					else
					{
						result += "\n" + tabs + indent + stringifyPretty(item, indent, level + 1);
					}

					if (ai < arr.length - 1)
					{
						result += ",";
						if (item is Number || item is int || item is uint || item is String)
						{
							result += " ";
						}
						else
						{
							result += "\n";
						}
					}
				};

				if (arr.length > 0 && (arr[arr.length - 1] is Number || arr[arr.length - 1] is String || arr[arr.length - 1] is int || arr[arr.length - 1] is uint))
				{
					result += "]";
				}
				else
				{
					result += "\n" + tabs + "]";
				};
			}
			else if (obj is Object)
			{
				var keys:Array = [];
				for (var key:String in obj)
				{
					keys.push(key);
				};
				if (keys.indexOf("profile") != -1)
				{
					keys.splice(keys.indexOf("profile"), 1);
					keys.unshift("profile");    
				};
				if (keys.indexOf("info") != -1)
				{
					keys.splice(keys.indexOf("info"), 1);
					keys.unshift("info");
				};
				if (keys.length == 0)
				{
					result += "{}";
				}
				else
				{
					result += "{\n";
					for (var k:int = 0; k < keys.length; k++)
					{
						var campo:String = keys[k];
						result += tabs + indent + "\"" + campo + "\": ";
						if (campo == "profile" || campo == "info" || campo == "author")
						{
							result += "\"" + String(obj[campo]) + "\"";
						}
						else
						{
							result += stringifyPretty(obj[campo], indent, level + 1);
						}

						if (k < keys.length - 1)
						{
							result += ",";
						}
						result += "\n";
					};
					result += tabs + "}";
				};
			}
			else
			{
				result += String(obj);
			};
			return result;
		};

		/** Set when user clicks No on the batch cache prompt (session). */
		public static var userDeclinedBatchCache:Boolean = false;
		/** User already answered Yes/No on batch cache prompt this app session. */
		public static var batchCachePromptAnswered:Boolean = false;

    }
}
