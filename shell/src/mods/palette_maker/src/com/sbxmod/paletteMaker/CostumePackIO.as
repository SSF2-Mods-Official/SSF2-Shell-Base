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
	import flash.utils.getQualifiedClassName;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	import flash.net.SharedObject;
	import flash.filters.ColorMatrixFilter;
	import com.mcleodgaming.ssf2.util.PaletteDeep;

	/** Costume packs on disk and online: clipboard, color-group files, pack folders, color sheet folders. */
	public class CostumePackIO
	{
		/** Nudge pure black/white replacements off extremes for vanilla in-place engines. */
		public static function nudgeExtremeReplacementsForVanilla(block:Object):int
		{
			var colors:Array;
			var repls:Array;
			var i:int;
			var src:uint;
			var repl:uint;
			var nudged:int = 0;
			var nudgedRepl:uint;
			if (!block || !(block.replacements is Array))
			{
				return 0;
			};
			repls = block.replacements as Array;
			colors = block.colors as Array;
			i = 0;
			while (i < repls.length)
			{
				src = (colors && i < colors.length) ? PaletteMakerUtils.coerceColorValue(colors[i]) : 0;
				repl = PaletteMakerUtils.coerceColorValue(repls[i]);
				repl = PaletteMakerUtils.normalizeReplacementAlphaForVanilla(repl, src);
				if (repl != PaletteMakerUtils.coerceColorValue(repls[i]))
				{
					repls[i] = int(repl);
				};
				nudgedRepl = PaletteMakerUtils.nudgeReplacementIfExtreme(repl, src);
				if (nudgedRepl != repl)
				{
					repls[i] = int(nudgedRepl);
					nudged++;
				};
				i++;
			};
			return nudged;
		}

		/** In-place flash-safe nudge on costume palette blocks. Returns total replacements changed. */
		public static function applyFlashSafeNudgeToCostume(costume:Object):int
		{
			var nudgeCount:int = 0;
			if (!costume)
			{
				return 0;
			};
			if (costume.paletteSwap)
			{
				nudgeCount += nudgeExtremeReplacementsForVanilla(costume.paletteSwap);
			};
			if (costume.paletteSwapPA)
			{
				nudgeCount += nudgeExtremeReplacementsForVanilla(costume.paletteSwapPA);
			};
			return nudgeCount;
		}

		/** Flash-safe nudge every costume in a pack.characters map. Returns total replacements changed. */
		public static function applyFlashSafeNudgeToPack(pack:Object):int
		{
			var characters:Object;
			var statsName:String;
			var list:Array;
			var i:int;
			var total:int = 0;
			if (!pack)
			{
				return 0;
			};
			characters = pack.characters as Object;
			if (!characters)
			{
				return 0;
			};
			for (statsName in characters)
			{
				list = characters[statsName] as Array;
				if (!list)
				{
					continue;
				};
				i = 0;
				while (i < list.length)
				{
					total += applyFlashSafeNudgeToCostume(list[i]);
					i++;
				};
			};
			return total;
		}

		public static function copyCostumeToClipboard(costumeName:String, paletteData:Object, authorName:String=null, statsName:String=null):void
		{
			if (!paletteData)
			{
				return;
			};
			var exportData:Object = PaletteMakerUtils.repairCostumeData(Ssf2.Utils.cloneObject(paletteData));
			var keepBoth:Boolean = paletteData && paletteData.both;
			delete exportData["team"];
			delete exportData["base"];
			delete exportData["profile"];
			delete exportData["colorVaultId"];
			PaletteMakerUtils.stripDefaultCostumeKeys(exportData);
			if (keepBoth)
			{
				exportData["both"] = true;
			};
			var infoName:String = costumeName;
			if (!infoName || infoName.length == 0)
			{
				infoName = "Custom Costume";
			};
			authorName = PaletteMakerUtils.trimString(authorName);
			if (authorName && authorName.length > 0)
			{
				exportData["author"] = authorName;
				exportData["info"] = infoName + " by " + authorName;
			}
			else
			{
				delete exportData["author"];
				exportData["info"] = infoName;
			};
			if (statsName && statsName.length > 0)
			{
				exportData["character"] = statsName;
			};
			Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, PaletteMakerUtils.stringifyPretty(exportData));
		};

		/**
		 * Write all per-character color group settings to Documents/SSF2 Custom Colors/color_groups.json.
		 * Returns the absolute native path, or null on failure.
		 */
		public static function exportAllColorGroupsToFile(colorGroups:Object):String
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			var characters:Object;
			var key:String;
			var count:int;
			var payload:Object;
			if (!colorGroups)
			{
				colorGroups = {};
			};
			characters = {};
			count = 0;
			for (key in colorGroups)
			{
				if (colorGroups[key] is Array)
				{
					characters[key] = Ssf2.Utils.cloneObject(colorGroups[key]);
					count++;
				};
			};
			payload = {
				"format": "ssf2_color_groups",
				"version": 1,
				"characterCount": count,
				"characters": characters
			};
			try
			{
				folder = PaletteMakerUtils.COSTUME_FOLDER;
				if (!folder.exists)
				{
					folder.createDirectory();
				};
				file = folder.resolvePath("color_groups.json");
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				stream.writeUTFBytes(PaletteMakerUtils.stringifyPretty(payload));
				stream.close();
				return file.nativePath;
			}
			catch (err:Error)
			{
				trace("[PaletteMakerUtils] Failed to export color groups:", err.message);
				return null;
			};
			return null;
		}

		/**
		 * Read color_groups.json (or raw characters map). Returns
		 * { ok:Boolean, colorGroups:Object, characterCount:int, error:String }.
		 */
		public static function importColorGroupsFromFile(file:File):Object
		{
			var stream:FileStream;
			var raw:String;
			var parsed:*;
			var characters:Object;
			var key:String;
			var count:int;
			if (!file || !file.exists)
			{
				return { ok: false, error: "File not found" };
			};
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				raw = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				parsed = JSON.parse(raw);
			}
			catch (err:Error)
			{
				return { ok: false, error: "Invalid JSON" };
			};
			characters = null;
			if (parsed && parsed.characters is Object)
			{
				characters = parsed.characters as Object;
			}
			else if (parsed is Object && !(parsed is Array))
			{
				characters = parsed as Object;
			};
			if (!characters)
			{
				return { ok: false, error: "Missing characters map" };
			};
			count = 0;
			for (key in characters)
			{
				if (characters[key] is Array)
				{
					count++;
				};
			};
			if (count == 0)
			{
				return { ok: false, error: "No character groups found" };
			};
			return {
				ok: true,
				colorGroups: Ssf2.Utils.cloneObject(characters),
				characterCount: count,
				error: null
			};
		}

		/**
		 * Online catalog entries are only removed from the favorites list.
		 * A local costume past the online prefix is deleted, and later favorite indexes shift down.
		 */
		public static function deleteCostumeObjects(statsName:String, costumes:Array):void
		{
			var list:Array;
			var onlineCount:int;
			var dropLocal:Object;
			var unfav:Object;
			var idx:int;
			var target:Object;
			var newList:Array;
			var i:int;
			var favs:Array;
			var outFav:Array;
			var shift:int;
			var n:int;
			var key:String;
			var removed:Boolean;
			if (!statsName || !costumes || costumes.length == 0)
			{
				return;
			};
			PaletteMakerUtils.ensureCostumeFileLoaded(statsName);
			list = PaletteMakerUtils.getCostume(statsName);
			if (!list)
			{
				list = [];
			};
			onlineCount = PaletteMakerUtils.getOnlineCostumeCount(statsName);
			dropLocal = {};
			unfav = {};
			for each (target in costumes)
			{
				if (!target)
				{
					continue;
				};
				idx = PaletteMakerUtils.catalogIndexOfCostume(statsName, target);
				if (idx < 0)
				{
					continue;
				};
				if (idx < onlineCount)
				{
					unfav[idx] = true;
				}
				else
				{
					dropLocal[idx] = true;
				};
			};
			newList = [];
			removed = false;
			i = 0;
			while (i < list.length)
			{
				if (dropLocal[i])
				{
					removed = true;
				}
				else if (list[i])
				{
					newList.push(list[i]);
				};
				i++;
			};
			if (removed)
			{
				replaceCostumeList(statsName, newList);
				list = newList;
			};
			favs = PaletteMakerUtils.getFavoriteIndexes(statsName);
			outFav = [];
			i = 0;
			while (favs && i < favs.length)
			{
				n = int(favs[i]);
				if (!unfav[n] && !dropLocal[n])
				{
					shift = 0;
					for (key in dropLocal)
					{
						if (int(key) < n)
						{
							shift++;
						};
					};
					n = n - shift;
					if (n >= 0 && n < list.length)
					{
						outFav.push(n);
					};
				};
				i++;
			};
			PaletteMakerUtils.setFavoriteIndexes(statsName, outFav);
		}

		/** Replace the entire custom costume list for a character. */
		public static function replaceCostumeList(statsName:String, list:Array):void
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			var cleaned:Array;
			var i:int;
			if (!statsName)
			{
				return;
			};
			folder = PaletteMakerUtils.COSTUME_FOLDER;
			if (!folder.exists)
			{
				folder.createDirectory();
			};
			cleaned = [];
			if (list)
			{
				i = 0;
				while (i < list.length)
				{
					if (list[i])
					{
						cleaned.push(PaletteMakerUtils.repairCostumeData(Ssf2.Utils.cloneObject(list[i])));
					};
					i++;
				};
			};
			file = folder.resolvePath(statsName + PaletteMakerUtils.COSTUME_FILE_EXTENSION);
			stream = new FileStream();
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(PaletteMakerUtils.stringifyPretty(cleaned));
			stream.close();
			PaletteMakerUtils.costumesDictionary[statsName] = cleaned;
			delete PaletteMakerUtils.costumeCycleCache[statsName];
		}

		public static function writeCostumesArrayToFile(file:File, costumes:Array):Boolean
		{
			var stream:FileStream;
			var cleaned:Array;
			var i:int;
			var entry:Object;
			if (!file)
			{
				return false;
			};
			cleaned = [];
			i = 0;
			while (costumes && i < costumes.length)
			{
				entry = PaletteMakerUtils.repairCostumeData(Ssf2.Utils.cloneObject(costumes[i] || {}));
				delete entry["team"];
				delete entry["base"];
				delete entry["colorVaultId"];
				PaletteMakerUtils.stripDefaultCostumeKeys(entry);
				applyFlashSafeNudgeToCostume(entry);
				cleaned.push(entry);
				i++;
			};
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				stream.writeUTFBytes(PaletteMakerUtils.stringifyPretty(cleaned));
				stream.close();
				return true;
			}
			catch (err:Error)
			{
				trace("[PaletteMakerUtils] writeCostumesArrayToFile failed:", err.message);
				return false;
			};
			return false;
		}

		public static function parseCostumesArray(raw:String):Array
		{
			var parsed:*;
			var list:Array;
			var i:int;
			if (!raw)
			{
				return null;
			};
			try
			{
				parsed = JSON.parse(raw);
			}
			catch (err:Error)
			{
				return null;
			};
			if (parsed is Array)
			{
				list = parsed as Array;
			}
			else if (parsed && (parsed.characters is Object))
			{
				return null;
			}
			else
			{
				return null;
			};
			i = 0;
			while (i < list.length)
			{
				list[i] = PaletteMakerUtils.repairCostumeData(list[i]);
				i++;
			};
			return list;
		}

		public static function buildCostumePackObject():Object
		{
			var characters:Object;
			var chars:Array;
			var name:String;
			var list:Array;
			var count:int;
			characters = {};
			count = 0;
			try
			{
				chars = PaletteMakerUtils.getCharsCompatibleWithCostumes();
			}
			catch (err:Error)
			{
				chars = [];
			};
			for each (name in chars)
			{
				list = PaletteMakerUtils.getCostume(name);
				if (list && list.length > 0)
				{
					characters[name] = stripColorVaultIdsFromCostumeList(Ssf2.Utils.cloneObject(list) as Array);
					count++;
				};
			};
			return {
				"format": "ssf2_costume_pack",
				"version": 2,
				"characterCount": count,
				"characters": characters
			};
		}

		public static function stripColorVaultIdFromCostume(costume:Object):Object
		{
			if (!costume)
			{
				return costume;
			};
			try
			{
				delete costume["colorVaultId"];
			}
			catch (err:Error)
			{
			};
			return costume;
		}

		public static function stripColorVaultIdsFromCostumeList(list:Array):Array
		{
			var i:int;
			var entry:Object;
			if (!list)
			{
				return [];
			};
			i = 0;
			while (i < list.length)
			{
				entry = list[i];
				if (entry)
				{
					entry = PaletteMakerUtils.repairCostumeData(Ssf2.Utils.cloneObject(entry));
					delete entry["team"];
					delete entry["base"];
					delete entry["colorVaultId"];
					PaletteMakerUtils.stripDefaultCostumeKeys(entry);
					list[i] = entry;
				};
				i++;
			};
			return list;
		}

		public static function stripColorVaultIdsFromPack(pack:Object):Object
		{
			var characters:Object;
			var statsName:String;
			var list:Array;
			if (!pack)
			{
				return pack;
			};
			characters = pack.characters as Object;
			if (!characters)
			{
				return pack;
			};
			for (statsName in characters)
			{
				list = characters[statsName] as Array;
				if (list)
				{
					characters[statsName] = stripColorVaultIdsFromCostumeList(Ssf2.Utils.cloneObject(list) as Array);
				};
			};
			pack["characters"] = characters;
			return pack;
		}

		public static function writeCostumePackToFile(file:File, pack:Object=null):Boolean
		{
			var stream:FileStream;
			var payload:Object;
			if (!file)
			{
				return false;
			};
			payload = pack || buildCostumePackObject();
			payload = stripColorVaultIdsFromPack(Ssf2.Utils.cloneObject(payload));
			if (payload)
			{
				applyFlashSafeNudgeToPack(payload);
				payload["characterCount"] = countCharactersInPack(payload);
			};
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				stream.writeUTFBytes(PaletteMakerUtils.stringifyPretty(payload));
				stream.close();
				return true;
			}
			catch (err:Error)
			{
				trace("[PaletteMakerUtils] writeCostumePackToFile failed:", err.message);
				return false;
			};
			return false;
		}

		public static function getPacksFolder():File
		{
			return PaletteMakerUtils.COSTUME_FOLDER.resolvePath("packs");
		}

		public static function ensurePacksFolder():File
		{
			var folder:File = getPacksFolder();
			if (!folder.exists)
			{
				folder.createDirectory();
			};
			return folder;
		}

		public static function getColorSheetsFolder():File
		{
			return PaletteMakerUtils.COSTUME_FOLDER.resolvePath("color sheets");
		}

		public static function getColorSheetsNoRecolorFolder():File
		{
			return getColorSheetsFolder().resolvePath("no recolor");
		}

		public static function getColorSheetsBaseRecolorFolder():File
		{
			return getColorSheetsFolder().resolvePath("base recolor");
		}

		/**
		 * Ensure Documents/.../color sheets exists and matches the embedded pack version.
		 * Re-extracts when the folder is new or packVersion advances (overwrites stock PNGs).
		 */
		public static function ensureColorSheetsExtracted():void
		{
			var root:File;
			var noRecolor:File;
			var baseRecolor:File;
			var pack:Object;
			var stamp:File;
			var stream:FileStream;
			var localVer:int;
			var packVer:int;
			var needExtract:Boolean;
			root = getColorSheetsFolder();
			if (!root.exists)
			{
				try
				{
					root.createDirectory();
				}
				catch (mkErr:Error)
				{
					return;
				};
			};
			noRecolor = getColorSheetsNoRecolorFolder();
			baseRecolor = getColorSheetsBaseRecolorFolder();
			if (!noRecolor.exists)
			{
				try { noRecolor.createDirectory(); } catch (e1:Error) {}
			};
			if (!baseRecolor.exists)
			{
				try { baseRecolor.createDirectory(); } catch (e2:Error) {}
			};
			pack = getBuiltinColorSheetsPack();
			if (!pack)
			{
				return;
			};
			packVer = int(pack.packVersion);
			if (packVer < 1)
			{
				packVer = 1;
			};
			stamp = root.resolvePath(".pack_version");
			localVer = 0;
			if (stamp.exists)
			{
				try
				{
					stream = new FileStream();
					stream.open(stamp, FileMode.READ);
					localVer = int(String(stream.readUTFBytes(stream.bytesAvailable)).replace(/^\s+|\s+$/g, ""));
					stream.close();
				}
				catch (readErr:Error)
				{
					localVer = 0;
				};
			};
			needExtract = (localVer < packVer);
			if (!needExtract)
			{
				return;
			};
			extractColorSheetMap(pack.no_recolor as Object, noRecolor);
			extractColorSheetMap(pack.base_recolor as Object, baseRecolor);
			try
			{
				stream = new FileStream();
				stream.open(stamp, FileMode.WRITE);
				stream.writeUTFBytes(String(packVer));
				stream.close();
			}
			catch (writeErr:Error)
			{
			};
		}

		private static var builtinColorSheetsPack:Object = null;

		private static var builtinColorSheetsPackLoaded:Boolean = false;

		public static function getBuiltinColorSheetsPack():Object
		{
			var ba:ByteArray;
			var raw:Object;
			if (builtinColorSheetsPackLoaded)
			{
				return builtinColorSheetsPack;
			};
			builtinColorSheetsPackLoaded = true;
			try
			{
				ba = new ColorSheetsPackData();
				ba.uncompress();
				raw = JSON.parse(ba.readUTFBytes(ba.length));
				if (raw && int(raw.packVersion) >= 1)
				{
					builtinColorSheetsPack = raw;
				};
			}
			catch (err:Error)
			{
				builtinColorSheetsPack = null;
			};
			return builtinColorSheetsPack;
		}

		private static function extractColorSheetMap(map:Object, folder:File):void
		{
			var key:String;
			var b64:String;
			var bytes:ByteArray;
			var file:File;
			var stream:FileStream;
			if (!map || !folder)
			{
				return;
			};
			for (key in map)
			{
				b64 = String(map[key]);
				if (!b64)
				{
					continue;
				};
				try
				{
					bytes = Ssf2.Base64.decodeToByteArray(b64);
					if (!bytes || bytes.length == 0)
					{
						continue;
					};
					file = folder.resolvePath(key + ".png");
					stream = new FileStream();
					stream.open(file, FileMode.WRITE);
					stream.writeBytes(bytes);
					stream.close();
				}
				catch (wErr:Error)
				{
				};
			};
		}

		public static function sanitizePackId(name:String):String
		{
			var id:String;
			if (!name)
			{
				return "pack_" + getTimer();
			};
			id = name.toLowerCase();
			id = id.replace(new RegExp("[^a-z0-9]+", "g"), "_");
			while (id.indexOf("__") >= 0)
			{
				id = id.split("__").join("_");
			};
			if (id.length > 0 && id.charAt(0) == "_")
			{
				id = id.substr(1);
			};
			if (id.length > 0 && id.charAt(id.length - 1) == "_")
			{
				id = id.substr(0, id.length - 1);
			};
			if (!id || id.length == 0)
			{
				id = "pack_" + getTimer();
			};
			return id;
		}

		public static function countCostumesInPack(pack:Object):int
		{
			var characters:Object;
			var statsName:String;
			var list:Array;
			var total:int;
			if (!pack || !(pack.characters is Object))
			{
				return 0;
			};
			characters = pack.characters;
			total = 0;
			for (statsName in characters)
			{
				list = characters[statsName] as Array;
				if (list)
				{
					total = total + list.length;
				};
			};
			return total;
		}

		public static function countCharactersInPack(pack:Object):int
		{
			var characters:Object;
			var statsName:String;
			var list:Array;
			var total:int;
			if (!pack || !(pack.characters is Object))
			{
				return 0;
			};
			characters = pack.characters;
			total = 0;
			for (statsName in characters)
			{
				list = characters[statsName] as Array;
				if (list && list.length > 0)
				{
					total++;
				};
			};
			return total;
		}

		public static function packHasCharacter(pack:Object, statsName:String):Boolean
		{
			var list:Array;
			if (!pack || !statsName || !(pack.characters is Object))
			{
				return false;
			};
			list = pack.characters[statsName] as Array;
			return list != null && list.length > 0;
		}

		/** Keep only one character's costumes in a pack clone. */
		public static function sliceCostumePackToCharacter(pack:Object, statsName:String):Object
		{
			var clone:Object;
			var list:Array;
			if (!pack || !statsName)
			{
				return null;
			};
			clone = Ssf2.Utils.cloneObject(pack);
			list = (clone.characters && clone.characters[statsName]) ? (clone.characters[statsName] as Array) : null;
			if (!list || list.length == 0)
			{
				return null;
			};
			clone["characters"] = {};
			clone["characters"][statsName] = list;
			clone["characterCount"] = 1;
			return clone;
		}

		public static function countCostumesForCharacterInPack(pack:Object, statsName:String):int
		{
			var list:Array;
			if (!pack || !statsName || !(pack.characters is Object))
			{
				return 0;
			};
			list = pack.characters[statsName] as Array;
			return list ? list.length : 0;
		}

		public static function applyPackMetadata(pack:Object, name:String, description:String=null, author:String=null, id:String=null):Object
		{
			if (!pack)
			{
				pack = {};
			};
			pack["format"] = "ssf2_costume_pack";
			pack["version"] = 2;
			pack["name"] = name ? String(name) : "Costume Pack";
			pack["description"] = description ? String(description) : "";
			pack["author"] = author ? String(author) : "";
			pack["id"] = id && String(id).length > 0 ? sanitizePackId(String(id)) : sanitizePackId(String(pack["name"]));
			if (!(pack.characters is Object))
			{
				pack["characters"] = {};
			};
			pack["characterCount"] = countCharactersInPack(pack);
			return pack;
		}

		/** Write pack JSON under Documents/SSF2 Custom Colors/packs/{id}.json */
		public static function writeCostumePackToPacksFolder(pack:Object):String
		{
			var folder:File;
			var file:File;
			var id:String;
			if (!pack)
			{
				return null;
			};
			id = pack.id ? sanitizePackId(String(pack.id)) : sanitizePackId(pack.name ? String(pack.name) : "pack");
			pack["id"] = id;
			folder = ensurePacksFolder();
			file = folder.resolvePath(id + PaletteMakerUtils.COSTUME_FILE_EXTENSION);
			if (writeCostumePackToFile(file, pack))
			{
				return file.nativePath;
			};
			return null;
		}

		/** Delete a local pack JSON by absolute path. Returns true if removed. */
		public static function deleteLocalCostumePack(filePath:String):Boolean
		{
			var file:File;
			var packsFolder:File;
			var packsUrl:String;
			var fileUrl:String;
			if (!filePath || filePath.length == 0)
			{
				return false;
			};
			try
			{
				file = new File(filePath);
				if (!file.exists || file.isDirectory)
				{
					return false;
				};
				packsFolder = getPacksFolder();
				if (packsFolder && packsFolder.exists)
				{
					packsUrl = packsFolder.url.toLowerCase();
					fileUrl = file.url.toLowerCase();
					if (fileUrl.indexOf(packsUrl) != 0)
					{
						trace("[PaletteMakerUtils] Refusing to delete pack outside packs folder:", filePath);
						return false;
					};
				};
				file.deleteFile();
				return true;
			}
			catch (err:Error)
			{
				trace("[PaletteMakerUtils] deleteLocalCostumePack failed:", err.message);
				return false;
			};
		}

		/**
		 * Scan local packs/*.json for browser metadata.
		 * Optional statsFilter: only packs that include that character (counts/samples scoped).
		 */
		public static function listLocalCostumePacks(statsFilter:String=null):Array
		{
			var folder:File;
			var files:Array;
			var out:Array;
			var f:File;
			var stream:FileStream;
			var raw:String;
			var pack:Object;
			var meta:Object;
			var baseName:String;
			out = [];
			folder = getPacksFolder();
			if (!folder.exists)
			{
				return out;
			};
			try
			{
				files = folder.getDirectoryListing();
			}
			catch (err:Error)
			{
				return out;
			};
			for each (f in files)
			{
				if (!f || f.isDirectory)
				{
					continue;
				};
				if (!f.name || f.name.toLowerCase().indexOf(".json") < 0)
				{
					continue;
				};
				try
				{
					stream = new FileStream();
					stream.open(f, FileMode.READ);
					raw = stream.readUTFBytes(stream.bytesAvailable);
					stream.close();
					pack = parseCostumePack(raw);
					if (!pack)
					{
						continue;
					};
					if (statsFilter && !packHasCharacter(pack, statsFilter))
					{
						continue;
					};
					baseName = f.name.substr(0, f.name.length - 5);
					meta = packMetaFromParsed(pack, "local", f.name, f.nativePath, null, statsFilter);
					if (!meta.id || meta.id.length == 0)
					{
						meta.id = sanitizePackId(baseName);
					};
					out.push(meta);
				}
				catch (readErr:Error)
				{
					trace("[PaletteMakerUtils] skip pack file:", f.name, readErr.message);
				};
			};
			out.sortOn("name", Array.CASEINSENSITIVE);
			return out;
		}

		/** Re-read a local pack file and rebuild metadata (for mid-session edits). */
		public static function refreshLocalPackMetaFromDisk(filePath:String, statsFilter:String=null):Object
		{
			var pack:Object;
			var file:File;
			var fileName:String;
			if (!filePath)
			{
				return null;
			};
			pack = loadLocalCostumePackByPath(filePath);
			if (!pack)
			{
				return null;
			};
			if (statsFilter && !packHasCharacter(pack, statsFilter))
			{
				return null;
			};
			try
			{
				file = new File(filePath);
				fileName = file.name;
			}
			catch (err:Error)
			{
				fileName = null;
			};
			return packMetaFromParsed(pack, "local", fileName, filePath, null, statsFilter);
		}

		public static function packMetaFromParsed(pack:Object, source:String, fileName:String, filePath:String=null, downloadUrl:String=null, statsFilter:String=null):Object
		{
			var id:String;
			var name:String;
			var meta:Object;
			var characterCount:int;
			var costumeCount:int;
			if (!pack)
			{
				return null;
			};
			id = pack.id ? String(pack.id) : "";
			if ((!id || id.length == 0) && fileName)
			{
				id = sanitizePackId(fileName.replace(new RegExp("\\.json$", "i"), ""));
			};
			name = pack.name ? String(pack.name) : id;
			if (!name || name.length == 0)
			{
				name = id || "Costume Pack";
			};
			if (statsFilter)
			{
				characterCount = packHasCharacter(pack, statsFilter) ? 1 : 0;
				costumeCount = countCostumesForCharacterInPack(pack, statsFilter);
			}
			else
			{
				characterCount = countCharactersInPack(pack);
				costumeCount = countCostumesInPack(pack);
			};
			meta = {
				"id": id,
				"name": name,
				"description": pack.description ? String(pack.description) : "",
				"author": pack.author ? String(pack.author) : "",
				"characterCount": characterCount,
				"costumeCount": costumeCount,
				"source": source,
				"fileName": fileName,
				"filePath": filePath,
				"downloadUrl": downloadUrl,
				"previewSamples": extractPackPreviewSamples(pack, 20, statsFilter)
			};
			return meta;
		}

		/** First N costumes across characters for stock-icon previews: [{statsName, costume}, ...] */
		public static function extractPackPreviewSamples(pack:Object, maxCount:int=20, statsFilter:String=null):Array
		{
			var out:Array;
			var characters:Object;
			var statsName:String;
			var list:Array;
			var costume:Object;
			out = [];
			if (!pack || !(pack.characters is Object) || maxCount <= 0)
			{
				return out;
			};
			characters = pack.characters;
			for (statsName in characters)
			{
				if (statsFilter && statsName != statsFilter)
				{
					continue;
				};
				list = characters[statsName] as Array;
				if (!list)
				{
					continue;
				};
				for each (costume in list)
				{
					if (!costume)
					{
						continue;
					};
					out.push({ "statsName": statsName, "costume": costume });
					if (out.length >= maxCount)
					{
						return out;
					};
				};
			};
			return out;
		}

		/**
		 * List online pack JSON files via GitHub Contents API (no index.json).
		 * onComplete(Array of meta with filename-based names), onError(message).
		 * Full pack JSON is downloaded when the user selects a pack.
		 */
		public static function fetchOnlineCostumePackList(onComplete:Function, onError:Function=null):void
		{
			var loader:URLLoader;
			var req:URLRequest;
			loader = new URLLoader();
			req = new URLRequest(ColorVaultSync.withCacheBust(ColorVaultSync.COLOR_VAULT_PACKS_API_URL));
			ColorVaultSync.applyNoCacheHeaders(req, [
				new URLRequestHeader("Accept", "application/vnd.github.v3+json"),
				new URLRequestHeader("User-Agent", "SSF2-PaletteMaker")
			]);
			loader.addEventListener(Event.COMPLETE, function(e:Event):void
			{
				var list:*;
				var entry:Object;
				var results:Array;
				var fileName:String;
				var dlUrl:String;
				var base:String;
				var id:String;
				try
				{
					list = JSON.parse(String(e.target.data));
				}
				catch (parseErr:Error)
				{
					if (onError != null)
					{
						onError("Online pack list parse failed");
					};
					return;
				};
				if (!(list is Array))
				{
					if (onError != null)
					{
						onError("Online pack list invalid");
					};
					return;
				};
				results = [];
				for each (entry in list)
				{
					if (!entry || entry.type != "file")
					{
						continue;
					};
					fileName = entry.name ? String(entry.name) : "";
					if (fileName.toLowerCase().indexOf(".json") < 0)
					{
						continue;
					};
					dlUrl = entry.download_url ? String(entry.download_url) : (ColorVaultSync.COLOR_VAULT_PACKS_RAW_BASE + fileName);
					base = fileName.replace(new RegExp("\\.json$", "i"), "");
					id = sanitizePackId(base);
					results.push({
						"id": id,
						"name": base.split("_").join(" "),
						"description": "Online pack — select to load details",
						"author": "",
						"characterCount": 0,
						"costumeCount": 0,
						"source": "online",
						"fileName": fileName,
						"filePath": null,
						"downloadUrl": dlUrl
					});
				};
				results.sortOn("name", Array.CASEINSENSITIVE);
				if (onComplete != null)
				{
					onComplete(results);
				};
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void
			{
				if (onError != null)
				{
					onError("Could not reach online packs");
				};
			});
			try
			{
				loader.load(req);
			}
			catch (loadErr:Error)
			{
				if (onError != null)
				{
					onError(loadErr.message);
				};
			};
		}

		/** Load full pack JSON; onComplete(pack), onError(message). */
		public static function fetchCostumePackFromUrl(url:String, onComplete:Function, onError:Function=null):void
		{
			var loader:URLLoader;
			var req:URLRequest;
			if (!url)
			{
				if (onError != null)
				{
					onError("Missing URL");
				};
				return;
			};
			loader = new URLLoader();
			req = new URLRequest(ColorVaultSync.withCacheBust(url));
			ColorVaultSync.applyNoCacheHeaders(req);
			loader.addEventListener(Event.COMPLETE, function(e:Event):void
			{
				var pack:Object = parseCostumePack(String(e.target.data));
				if (!pack)
				{
					if (onError != null)
					{
						onError("Invalid pack JSON");
					};
					return;
				};
				if (onComplete != null)
				{
					onComplete(pack);
				};
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void
			{
				if (onError != null)
				{
					onError("Download failed");
				};
			});
			try
			{
				loader.load(req);
			}
			catch (err:Error)
			{
				if (onError != null)
				{
					onError(err.message);
				};
			};
		}

		public static function loadLocalCostumePackByPath(filePath:String):Object
		{
			var file:File;
			var stream:FileStream;
			var raw:String;
			if (!filePath)
			{
				return null;
			};
			try
			{
				file = new File(filePath);
				if (!file.exists)
				{
					return null;
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				raw = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				return parseCostumePack(raw);
			}
			catch (err:Error)
			{
				return null;
			};
			return null;
		}

		/** True if this costume is already saved for the character (vault id or profile name). */
		public static function isCostumeAlreadyOwned(statsName:String, costume:Object):Boolean
		{
			var list:Array;
			var item:Object;
			var vaultId:int;
			var profile:String;
			var itemProfile:String;
			if (!statsName || !costume)
			{
				return false;
			};
			list = PaletteMakerUtils.getCostume(statsName);
			if (!list || list.length == 0)
			{
				return false;
			};
			vaultId = PaletteMakerUtils.getColorVaultIdFromCostume(costume);
			profile = costume.profile ? String(costume.profile).toLowerCase() : "";
			for each (item in list)
			{
				if (!item)
				{
					continue;
				};
				if (vaultId >= 0 && PaletteMakerUtils.getColorVaultIdFromCostume(item) == vaultId)
				{
					return true;
				};
				if (vaultId < 0 && profile.length > 0)
				{
					itemProfile = item.profile ? String(item.profile).toLowerCase() : "";
					if (itemProfile == profile)
					{
						return true;
					};
				};
			};
			return false;
		}

		/**
		 * Remove already-owned costumes from a pack clone.
		 * Returns { pack, skipped, remaining }.
		 */
		public static function filterOwnedCostumesFromPack(pack:Object):Object
		{
			var characters:Object;
			var statsName:String;
			var list:Array;
			var kept:Array;
			var costume:Object;
			var skipped:int;
			var remaining:int;
			var outChars:Object;
			var charCount:int;
			var clone:Object;
			skipped = 0;
			remaining = 0;
			outChars = {};
			charCount = 0;
			if (!pack || !(pack.characters is Object))
			{
				return { "pack": pack, "skipped": 0, "remaining": 0 };
			};
			clone = Ssf2.Utils.cloneObject(pack);
			characters = pack.characters;
			for (statsName in characters)
			{
				list = characters[statsName] as Array;
				if (!list)
				{
					continue;
				};
				kept = [];
				for each (costume in list)
				{
					if (!costume)
					{
						continue;
					};
					if (isCostumeAlreadyOwned(statsName, costume))
					{
						skipped++;
					}
					else
					{
						kept.push(Ssf2.Utils.cloneObject(costume));
						remaining++;
					};
				};
				if (kept.length > 0)
				{
					outChars[statsName] = kept;
					charCount++;
				};
			};
			clone["characters"] = outChars;
			clone["characterCount"] = charCount;
			return { "pack": clone, "skipped": skipped, "remaining": remaining };
		}

		public static function backupCurrentCostumePack():String
		{
			var folder:File;
			var file:File;
			var stamp:String;
			folder = PaletteMakerUtils.COSTUME_FOLDER;
			if (!folder.exists)
			{
				folder.createDirectory();
			};
			stamp = String(getTimer());
			file = folder.resolvePath("costume_pack_backup_" + stamp + ".json");
			if (writeCostumePackToFile(file, buildCostumePackObject()))
			{
				return file.nativePath;
			};
			return null;
		}

		public static function parseCostumePack(raw:String):Object
		{
			var parsed:*;
			if (!raw)
			{
				return null;
			};
			try
			{
				parsed = JSON.parse(raw);
			}
			catch (err:Error)
			{
				return null;
			};
			if (!parsed || !(parsed.characters is Object))
			{
				return null;
			};
			return parsed;
		}

		/**
		 * Import a costume pack.
		 * replace=false appends/upserts; replace=true wipes then writes per character in the pack.
		 */
		public static function importCostumePack(pack:Object, replace:Boolean):int
		{
			var characters:Object;
			var statsName:String;
			var list:Array;
			var entry:Object;
			var imported:int;
			if (!pack || !(pack.characters is Object))
			{
				return 0;
			};
			characters = pack.characters;
			imported = 0;
			for (statsName in characters)
			{
				list = characters[statsName] as Array;
				if (!list)
				{
					continue;
				};
				if (replace)
				{
					replaceCostumeList(statsName, list);
					var favAll:Array = [];
					var fi:int = 0;
					while (fi < list.length)
					{
						favAll.push(fi);
						fi++;
					};
					PaletteMakerUtils.setFavoriteIndexes(statsName, favAll);
					imported = imported + list.length;
				}
				else
				{
					for each (entry in list)
					{
						if (!entry)
						{
							continue;
						};
						PaletteMakerUtils.saveCostume(statsName, entry.profile ? String(entry.profile) : "Custom Costume", Ssf2.Utils.cloneObject(entry), PaletteMakerUtils.extractAuthorFromCostume(entry), true);
						imported++;
					};
				};
			};
			return imported;
		}
	}
}
