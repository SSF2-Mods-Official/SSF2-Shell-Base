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

	/** Unique/effect sprite and discover caches on disk, builtin cache pack and cache manifest. */
	public class SpriteCacheStore
	{
		/** Lazy-load zlib-compressed stock cache pack embedded in SSF2.swf. */
		public static function getBuiltinCachePack():Object
		{
			var ba:ByteArray;
			var raw:Object;
			if (builtinCachePackLoaded)
			{
				return builtinCachePack;
			};
			builtinCachePackLoaded = true;
			try
			{
				ba = new PaletteMakerCachePackData();
				ba.uncompress();
				raw = JSON.parse(ba.readUTFBytes(ba.length));
				if (raw && int(raw.packVersion) == CACHE_PACK_VERSION
					&& int(raw.discoverVer) == DISCOVER_CACHE_VERSION
					&& int(raw.uniqueVer) == UNIQUE_SPRITE_CACHE_VERSION
					&& raw.discover is Object && raw.unique is Object)
				{
					builtinCachePack = raw;
					cacheDebugLog("Builtin cache pack loaded — discover="
						+ countObjectKeys(raw.discover) + " unique=" + countObjectKeys(raw.unique));
				}
				else
				{
					cacheDebugLog("Builtin cache pack rejected (version mismatch)");
					builtinCachePack = null;
				};
			}
			catch (err:Error)
			{
				cacheDebugLog("Builtin cache pack load failed: " + err.message);
				builtinCachePack = null;
			};
			return builtinCachePack;
		}

		private static function countObjectKeys(obj:Object):int
		{
			var n:int = 0;
			var k:*;
			if (!obj)
			{
				return 0;
			};
			for (k in obj)
			{
				n++;
			};
			return n;
		}

		public static function isBuiltinDiscoverFresh(statsName:String):Boolean
		{
			var pack:Object;
			var cacheKey:String;
			var scanName:String;
			var entry:Object;
			var size:Number;
			pack = getBuiltinCachePack();
			if (!pack || !statsName)
			{
				return false;
			};
			cacheKey = PaletteMakerUtils.getDiscoverCacheKey(statsName);
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			entry = pack.discover[cacheKey];
			if (!entry || !(entry.swap is Array) || !(entry.swapPA is Array))
			{
				return false;
			};
			size = PaletteMakerUtils.getCharacterResourceSize(scanName);
			return size > 0 && Number(entry.ssfSize) == size;
		}

		public static function isBuiltinUniqueFresh(statsName:String):Boolean
		{
			var pack:Object;
			var scanName:String;
			var entry:Object;
			var size:Number;
			pack = getBuiltinCachePack();
			if (!pack || !statsName)
			{
				return false;
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			entry = pack.unique[scanName];
			if (!entry || !(entry.items is Array))
			{
				return false;
			};
			size = PaletteMakerUtils.getCharacterResourceSize(scanName);
			return size > 0 && Number(entry.ssfSize) == size;
		}

		public static function loadDiscoverFromBuiltinPack(statsName:String):Object
		{
			var pack:Object;
			var cacheKey:String;
			var entry:Object;
			if (!isBuiltinDiscoverFresh(statsName))
			{
				return null;
			};
			pack = getBuiltinCachePack();
			cacheKey = PaletteMakerUtils.getDiscoverCacheKey(statsName);
			entry = pack.discover[cacheKey];
			cacheDebugLog("discover HIT builtin stats=" + statsName + " key=" + cacheKey
				+ " ssfSize=" + entry.ssfSize);
			return { "swap": entry.swap as Array, "swapPA": entry.swapPA as Array };
		}

		public static function loadUniqueFromBuiltinPack(statsName:String):Array
		{
			var pack:Object;
			var scanName:String;
			var entry:Object;
			if (!isBuiltinUniqueFresh(statsName))
			{
				return null;
			};
			pack = getBuiltinCachePack();
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			entry = pack.unique[scanName];
			cacheDebugLog("unique HIT builtin stats=" + statsName + " key=" + scanName
				+ " ssfSize=" + entry.ssfSize + " items=" + (entry.items as Array).length);
			return entry.items as Array;
		}

		public static function loadUniqueSpriteCache(statsName:String, mtime:Number):Array
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			var raw:Object;
			if (!statsName)
			{
				return null;
			};
			try
			{
				folder = PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_unique_sprite_cache");
				file = folder.resolvePath(statsName + ".json");
				if (!file.exists)
				{
					return null;
				};
				raw = JsonFile.read(file);
				if (!raw || Number(raw.mtime) != mtime || int(raw.version) != UNIQUE_SPRITE_CACHE_VERSION || !(raw.items is Array))
				{
					return null;
				};
				updateCacheManifestUnique(statsName, mtime);
				return raw.items as Array;
			}
			catch (err:Error)
			{
			};
			return null;
		}

		public static function saveUniqueSpriteCache(statsName:String, mtime:Number, items:Array):void
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			if (!statsName || !items)
			{
				return;
			};
			try
			{
				folder = PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_unique_sprite_cache");
				if (!folder.exists)
				{
					folder.createDirectory();
				};
				file = folder.resolvePath(statsName + ".json");
				JsonFile.write(file, {
					"version": UNIQUE_SPRITE_CACHE_VERSION,
					"mtime": mtime,
					"hash": characterHash(statsName),
					"items": items
				});
				invalidateUniqueCacheMemo(statsName);
				updateCacheManifestUnique(statsName, mtime, characterHash(statsName));
			}
			catch (err:Error)
			{
			};
		}

		private static function effectCacheJsonFile(scanName:String):File
		{
			if (!scanName)
			{
				return null;
			};
			return PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_effect_sprite_cache/" + scanName + ".json");
		}

		private static function effectCachePackFile(scanName:String):File
		{
			if (!scanName)
			{
				return null;
			};
			return PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_effect_sprite_cache/" + scanName + ".bdpack");
		}

		private static function parseEffectCacheRaw(raw:Object, mtime:Number, strictMtime:Boolean):Array
		{
			if (!raw || int(raw.version) != EFFECT_SPRITE_CACHE_VERSION || !(raw.items is Array))
			{
				return null;
			};
			if (strictMtime && Number(raw.mtime) != mtime)
			{
				return null;
			};
			return raw.items as Array;
		}

		private static function readEffectCacheRaw(scanName:String):Object
		{
			var file:File;
			var stream:FileStream;
			var raw:Object;
			if (!scanName)
			{
				return null;
			};
			try
			{
				file = effectCacheJsonFile(scanName);
				if (!file || !file.exists)
				{
					return null;
				};
				raw = JsonFile.read(file);
				return raw;
			}
			catch (err:Error)
			{
			};
			return null;
		}

		/** Rasterize a display object to BitmapData (max side capped). */
		public static function rasterizeDisplayToBitmapData(target:DisplayObject, maxSide:int = 64):BitmapData
		{
			var bounds:Rectangle;
			var bd:BitmapData;
			var m:Matrix;
			var scale:Number;
			var tw:int;
			var th:int;
			if (!target)
			{
				return null;
			};
			if (maxSide < 8)
			{
				maxSide = 8;
			};
			try
			{
				bounds = target.getBounds(target);
				if (!bounds || bounds.width < 1 || bounds.height < 1)
				{
					return null;
				};
				scale = 1;
				if (bounds.width > maxSide || bounds.height > maxSide)
				{
					scale = Math.min(Number(maxSide) / bounds.width, Number(maxSide) / bounds.height);
				};
				tw = Math.max(1, Math.ceil(bounds.width * scale));
				th = Math.max(1, Math.ceil(bounds.height * scale));
				bd = new BitmapData(tw, th, true, 0x00000000);
				m = new Matrix();
				m.translate(-bounds.x, -bounds.y);
				if (scale != 1)
				{
					m.scale(scale, scale);
				};
				bd.draw(target, m, null, null, null, false);
				return bd;
			}
			catch (err:Error)
			{
				return null;
			};
		}

		/** Write ARGB pixels blob (zlib) for one BitmapData into stream. */
		private static function writeBitmapDataBlob(stream:FileStream, bd:BitmapData):Boolean
		{
			var pixels:ByteArray;
			var packed:ByteArray;
			if (!stream || !bd)
			{
				return false;
			};
			try
			{
				pixels = bd.getPixels(bd.rect);
				packed = new ByteArray();
				packed.writeUnsignedInt(bd.width);
				packed.writeUnsignedInt(bd.height);
				packed.writeBytes(pixels);
				packed.compress();
				stream.writeUnsignedInt(packed.length);
				stream.writeBytes(packed);
				return true;
			}
			catch (err:Error)
			{
			};
			return false;
		}

		/** Read one zlib ARGB blob from pack bytes at offset; returns {bd, nextOffset}. */
		private static function readBitmapDataBlob(pack:ByteArray, offset:uint):Object
		{
			var blobLen:uint;
			var packed:ByteArray;
			var w:uint;
			var h:uint;
			var bd:BitmapData;
			var pixels:ByteArray;
			if (!pack || offset + 4 > pack.length)
			{
				return null;
			};
			try
			{
				pack.position = offset;
				blobLen = pack.readUnsignedInt();
				if (blobLen == 0 || offset + 4 + blobLen > pack.length)
				{
					return null;
				};
				packed = new ByteArray();
				pack.readBytes(packed, 0, blobLen);
				packed.uncompress();
				packed.position = 0;
				w = packed.readUnsignedInt();
				h = packed.readUnsignedInt();
				if (w < 1 || h < 1 || w > 2048 || h > 2048)
				{
					return null;
				};
				pixels = new ByteArray();
				packed.readBytes(pixels);
				bd = new BitmapData(w, h, true, 0x00000000);
				bd.setPixels(bd.rect, pixels);
				return {
					"bd": bd,
					"nextOffset": offset + 4 + blobLen
				};
			}
			catch (err:Error)
			{
			};
			return null;
		}

		/**
		 * Persist RE effect strip bitmaps.
		 * items: [{ linkage, bitmapIndex }] matching order of bitmaps array.
		 */
		public static function saveEffectSpriteCache(statsName:String, mtime:Number, items:Array, bitmaps:Array):void
		{
			var folder:File;
			var file:File;
			var packFile:File;
			var stream:FileStream;
			var i:int;
			var bd:BitmapData;
			var scanName:String;
			if (!statsName || !items || !bitmaps)
			{
				return;
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			if (!scanName)
			{
				scanName = statsName;
			};
			try
			{
				folder = PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_effect_sprite_cache");
				if (!folder.exists)
				{
					folder.createDirectory();
				};
				packFile = effectCachePackFile(scanName);
				stream = new FileStream();
				stream.open(packFile, FileMode.WRITE);
				stream.writeUnsignedInt(EFFECT_SPRITE_CACHE_VERSION);
				stream.writeUnsignedInt(bitmaps.length);
				i = 0;
				while (i < bitmaps.length)
				{
					bd = bitmaps[i] as BitmapData;
					if (!bd || !writeBitmapDataBlob(stream, bd))
					{
						stream.close();
						try { if (packFile.exists) packFile.deleteFile(); } catch (delErr:Error) {};
						return;
					};
					i++;
				};
				stream.close();
				file = effectCacheJsonFile(scanName);
				JsonFile.write(file, {
					"version": EFFECT_SPRITE_CACHE_VERSION,
					"mtime": mtime,
					"hash": characterHash(statsName),
					"items": items
				});
				cacheDebugLog("effect SAVE stats=" + statsName + " key=" + scanName
					+ " items=" + items.length + " mtime=" + mtime);
			}
			catch (err:Error)
			{
				cacheDebugLog("effect SAVE fail stats=" + statsName + " err=" + err.message);
			};
		}

		/**
		 * Load effect strip cache for editor use (strict mtime; lenient if user declined batch).
		 * Returns items array or null. Bitmaps loaded via hydrateEffectSpriteCache.
		 */
		public static function loadEffectSpriteCacheForUse(statsName:String, mtime:Number):Array
		{
			var keys:Array;
			var i:int;
			var key:String;
			var raw:Object;
			var parsed:Array;
			keys = getUniqueCacheKeyCandidates(statsName);
			i = 0;
			while (i < keys.length)
			{
				key = String(keys[i]);
				raw = readEffectCacheRaw(key);
				if (!raw)
				{
					i++;
					continue;
				};
				if (raw.hash)
				{
					if (!storedHashMatches(raw, statsName))
					{
						i++;
						continue;
					};
					parsed = parseEffectCacheRaw(raw, mtime, false);
					if (parsed)
					{
						cacheDebugLog("effect HIT hash stats=" + statsName + " key=" + key
							+ " items=" + parsed.length);
						return parsed;
					};
				}
				else if (adoptUnhashedCache(raw, statsName, effectCacheJsonFile(key)))
				{
					parsed = parseEffectCacheRaw(raw, mtime, false);
					if (parsed)
					{
						cacheDebugLog("effect HIT adopt stats=" + statsName + " key=" + key
							+ " items=" + parsed.length);
						return parsed;
					};
				};
				parsed = parseEffectCacheRaw(raw, mtime, true);
				if (parsed)
				{
					cacheDebugLog("effect HIT strict stats=" + statsName + " key=" + key
						+ " items=" + parsed.length);
					return parsed;
				};
				if (PaletteMakerUtils.userDeclinedBatchCache)
				{
					parsed = parseEffectCacheRaw(raw, mtime, false);
					if (parsed)
					{
						cacheDebugLog("effect HIT lenient stats=" + statsName + " key=" + key
							+ " items=" + parsed.length);
						return parsed;
					};
				};
				cacheDebugLog("effect MISS stats=" + statsName + " key=" + key
					+ " swfMtime=" + mtime + " fileMtime=" + (raw ? raw.mtime : "n/a"));
				i++;
			};
			return null;
		}

		/**
		 * Hydrate effect cache items into { kind:"bitmap", linkage, bitmapData } candidates.
		 * Clones BitmapData from the .bdpack companion file.
		 */
		public static function hydrateEffectSpriteCache(statsName:String, items:Array):Array
		{
			var out:Array;
			var scanName:String;
			var packFile:File;
			var stream:FileStream;
			var pack:ByteArray;
			var count:uint;
			var ver:uint;
			var offset:uint;
			var i:int;
			var item:Object;
			var idx:int;
			var blob:Object;
			var bd:BitmapData;
			var bitmaps:Array;
			out = [];
			if (!statsName || !items || items.length == 0)
			{
				return out;
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			packFile = effectCachePackFile(scanName);
			if (!packFile || !packFile.exists)
			{
				packFile = effectCachePackFile(statsName);
			};
			if (!packFile || !packFile.exists)
			{
				return out;
			};
			try
			{
				stream = new FileStream();
				stream.open(packFile, FileMode.READ);
				pack = new ByteArray();
				stream.readBytes(pack);
				stream.close();
				pack.position = 0;
				ver = pack.readUnsignedInt();
				count = pack.readUnsignedInt();
				if (ver != EFFECT_SPRITE_CACHE_VERSION)
				{
					return out;
				};
				bitmaps = [];
				offset = pack.position;
				i = 0;
				while (i < count)
				{
					blob = readBitmapDataBlob(pack, offset);
					if (!blob)
					{
						break;
					};
					bitmaps.push(blob.bd);
					offset = uint(blob.nextOffset);
					i++;
				};
				i = 0;
				while (i < items.length)
				{
					item = items[i];
					i++;
					if (!item || !item.linkage)
					{
						continue;
					};
					idx = int(item.bitmapIndex);
					if (idx < 0 || idx >= bitmaps.length)
					{
						continue;
					};
					bd = bitmaps[idx] as BitmapData;
					if (!bd)
					{
						continue;
					};
					out.push({
						"kind": "bitmap",
						"linkage": String(item.linkage),
						"bitmapData": bd.clone(),
						"used": false
					});
				};
				i = 0;
				while (i < bitmaps.length)
				{
					bd = bitmaps[i] as BitmapData;
					if (bd)
					{
						try { bd.dispose(); } catch (dispErr:Error) {};
					};
					i++;
				};
			}
			catch (err:Error)
			{
				cacheDebugLog("effect hydrate fail stats=" + statsName + " err=" + err.message);
			};
			return out;
		}

		public static const UNIQUE_SPRITE_COLOR_TOLERANCE:int = 6;

		/**
		 * Min opaque pixels a color must have to count as a discovered swatch.
		 * 1 keeps single-pixel pupils / highlights on projectile unique sprites
		 * (Mega Man Beat eyes were dropped at the old threshold of 4).
		 */
		public static const DISCOVERED_COLOR_MIN_PIXELS:int = 1;

		/** Bump when unique-sprite cover inputs change (e.g. discovered swatches). */
		public static const UNIQUE_SPRITE_CACHE_VERSION:int = 29;

		/** Bump when RE effect-strip discovery / raster cache format changes. */
		public static const EFFECT_SPRITE_CACHE_VERSION:int = 3;

		/** Bump when discover scan logic / min-pixel rules change. */
		public static const DISCOVER_CACHE_VERSION:int = 4;

		public static const CACHE_MANIFEST_VERSION:int = 1;

		/** Trace cache warm / freshness / on-demand decisions to the debug console. */
		public static var CACHE_DEBUG:Boolean = false;

		/** Embedded stock cache pack (zlib JSON). */
		public static const CACHE_PACK_VERSION:int = 1;

		private static var builtinCachePack:Object = null;

		private static var builtinCachePackLoaded:Boolean = false;

		private static var discoverSessionCache:Object = {};

		private static var cacheManifestData:Object = null;

		private static var cacheManifestLoaded:Boolean = false;

		private static function ensureCacheManifestLoaded():void
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			var raw:Object;
			if (cacheManifestLoaded)
			{
				return;
			};
			cacheManifestLoaded = true;
			cacheManifestData = { "version": CACHE_MANIFEST_VERSION, "entries": {} };
			try
			{
				folder = PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_discover_cache");
				file = folder.resolvePath("_cache_manifest.json");
				if (!file.exists)
				{
					return;
				};
				raw = JsonFile.read(file);
				if (raw && int(raw.version) == CACHE_MANIFEST_VERSION && raw.entries is Object)
				{
					cacheManifestData = raw;
				};
			}
			catch (err:Error)
			{
			};
		}

		private static function saveCacheManifest():void
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			if (!cacheManifestData)
			{
				return;
			};
			try
			{
				folder = PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_discover_cache");
				if (!folder.exists)
				{
					folder.createDirectory();
				};
				file = folder.resolvePath("_cache_manifest.json");
				JsonFile.write(file, cacheManifestData);
			}
			catch (err:Error)
			{
			};
		}

		private static function getManifestEntry(key:String):Object
		{
			var entries:Object;
			ensureCacheManifestLoaded();
			if (!cacheManifestData || !key)
			{
				return null;
			};
			entries = cacheManifestData.entries;
			if (!entries || !entries.hasOwnProperty(key))
			{
				return null;
			};
			return entries[key];
		}

		private static function updateCacheManifestDiscover(cacheKey:String, mtime:Number, hash:String = null):void
		{
			var entry:Object;
			if (!cacheKey)
			{
				return;
			};
			ensureCacheManifestLoaded();
			if (!cacheManifestData.entries)
			{
				cacheManifestData.entries = {};
			};
			entry = cacheManifestData.entries[cacheKey];
			if (!entry)
			{
				entry = {};
				cacheManifestData.entries[cacheKey] = entry;
			};
			entry.discoverMtime = mtime;
			entry.discoverVer = DISCOVER_CACHE_VERSION;
			if (hash)
			{
				entry.discoverHash = hash;
			};
			saveCacheManifest();
		}

		private static function updateCacheManifestUnique(scanName:String, mtime:Number, hash:String = null):void
		{
			var entry:Object;
			if (!scanName)
			{
				return;
			};
			ensureCacheManifestLoaded();
			if (!cacheManifestData.entries)
			{
				cacheManifestData.entries = {};
			};
			entry = cacheManifestData.entries[scanName];
			if (!entry)
			{
				entry = {};
				cacheManifestData.entries[scanName] = entry;
			};
			entry.uniqueMtime = mtime;
			entry.uniqueVer = UNIQUE_SPRITE_CACHE_VERSION;
			if (hash)
			{
				entry.uniqueHash = hash;
			};
			saveCacheManifest();
		}

		/** Hash of the character file the cache was built from. Empty when the file is missing. */
		private static function characterHash(statsName:String):String
		{
			var scanName:String;
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			if (!scanName)
			{
				scanName = statsName;
			};
			return PaletteMakerUtils.characterFileHash(scanName);
		}

		private static function storedHashMatches(raw:Object, statsName:String):Boolean
		{
			var hash:String;
			if (!raw || !raw.hash)
			{
				return false;
			};
			hash = characterHash(statsName);
			return hash.length > 0 && String(raw.hash) == hash;
		}

		/** A cache saved before hashes existed is kept, and the current file hash is written into it. */
		private static function adoptUnhashedCache(raw:Object, statsName:String, file:File):Boolean
		{
			var hash:String;
			if (!raw || raw.hash)
			{
				return false;
			};
			hash = characterHash(statsName);
			if (!hash)
			{
				return false;
			};
			raw.hash = hash;
			try
			{
				if (file)
				{
					JsonFile.write(file, raw);
				};
			}
			catch (err:Error)
			{
			};
			cacheDebugLog("cache ADOPT hash stats=" + statsName + " hash=" + hash);
			return true;
		}

		private static function isManifestDiscoverFresh(cacheKey:String, hash:String):Boolean
		{
			var entry:Object;
			entry = getManifestEntry(cacheKey);
			return entry != null
				&& hash
				&& String(entry.discoverHash) == hash
				&& int(entry.discoverVer) == DISCOVER_CACHE_VERSION;
		}

		private static function isManifestUniqueFresh(scanName:String, hash:String):Boolean
		{
			var entry:Object;
			entry = getManifestEntry(scanName);
			return entry != null
				&& hash
				&& String(entry.uniqueHash) == hash
				&& int(entry.uniqueVer) == UNIQUE_SPRITE_CACHE_VERSION;
		}

		public static function memoDiscoverSessionCache(cacheKey:String, data:Object):void
		{
			if (cacheKey && data)
			{
				discoverSessionCache[cacheKey] = data;
			};
		}

		public static function takeDiscoverSessionCache(cacheKey:String):Object
		{
			var data:Object;
			if (!cacheKey || !discoverSessionCache.hasOwnProperty(cacheKey))
			{
				return null;
			};
			data = discoverSessionCache[cacheKey];
			delete discoverSessionCache[cacheKey];
			return data;
		}

		public static function cacheDebugLog(msg:String):void
		{
			if (CACHE_DEBUG)
			{
				trace("[PMCache]", msg);
			};
		}

		internal static function discoverCacheFile(cacheKey:String):File
		{
			if (!cacheKey)
			{
				return null;
			};
			return PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_discover_cache/" + cacheKey + ".json");
		}

		internal static function uniqueCacheFile(scanName:String):File
		{
			if (!scanName)
			{
				return null;
			};
			return PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_unique_sprite_cache/" + scanName + ".json");
		}

		private static function parseDiscoverCacheRaw(raw:Object, mtime:Number, strictMtime:Boolean):Object
		{
			if (!raw || int(raw.version) != DISCOVER_CACHE_VERSION
				|| !(raw.swap is Array) || !(raw.swapPA is Array))
			{
				return null;
			};
			if (strictMtime && Number(raw.mtime) != mtime)
			{
				return null;
			};
			return { "swap": raw.swap as Array, "swapPA": raw.swapPA as Array, "alt": (raw.alt is Array ? raw.alt as Array : []) };
		}

		private static function parseUniqueCacheRaw(raw:Object, mtime:Number, strictMtime:Boolean):Array
		{
			if (!raw || int(raw.version) != UNIQUE_SPRITE_CACHE_VERSION || !(raw.items is Array))
			{
				return null;
			};
			if (strictMtime && Number(raw.mtime) != mtime)
			{
				return null;
			};
			return raw.items as Array;
		}

		private static function readDiscoverCacheRaw(cacheKey:String):Object
		{
			var file:File;
			var stream:FileStream;
			var raw:Object;
			if (!cacheKey)
			{
				return null;
			};
			try
			{
				file = discoverCacheFile(cacheKey);
				if (!file || !file.exists)
				{
					return null;
				};
				raw = JsonFile.read(file);
				return raw;
			}
			catch (err:Error)
			{
			};
			return null;
		}

		private static function readUniqueCacheRaw(scanName:String):Object
		{
			var file:File;
			var stream:FileStream;
			var raw:Object;
			if (!scanName)
			{
				return null;
			};
			try
			{
				file = uniqueCacheFile(scanName);
				if (!file || !file.exists)
				{
					return null;
				};
				raw = JsonFile.read(file);
				return raw;
			}
			catch (err:Error)
			{
			};
			return null;
		}

		/** Keys to try when loading discover cache (canonical + legacy filenames). */
		public static function getDiscoverCacheKeyCandidates(statsName:String):Array
		{
			var keys:Array = [];
			var seen:Object = {};
			var cacheKey:String;
			var scanName:String;
			var linkedKey:String;
			var partner:String;
			function addKey(key:String):void
			{
				if (key && !seen[key])
				{
					seen[key] = true;
					keys.push(key);
				};
			};
			if (!statsName)
			{
				return keys;
			};
			cacheKey = PaletteMakerUtils.getDiscoverCacheKey(statsName);
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			linkedKey = PaletteMakerUtils.getLinkedDiscoverCacheKey(statsName);
			addKey(cacheKey);
			addKey(statsName);
			addKey(scanName);
			addKey(linkedKey);
			partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (partner)
			{
				addKey(partner);
			};
			return keys;
		}

		/** Keys to try when loading unique cache (canonical scan id + legacy roster ids). */
		public static function getUniqueCacheKeyCandidates(statsName:String):Array
		{
			var keys:Array = [];
			var seen:Object = {};
			var scanName:String;
			var partner:String;
			function addKey(key:String):void
			{
				if (key && !seen[key])
				{
					seen[key] = true;
					keys.push(key);
				};
			};
			if (!statsName)
			{
				return keys;
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			addKey(scanName);
			addKey(statsName);
			partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (partner)
			{
				addKey(partner);
			};
			return keys;
		}

		/**
		 * Load discover cache for editor/on-demand use.
		 * When user declined batch warm, accepts existing on-disk cache even if mtime differs.
		 */
		public static function loadDiscoverCacheForUse(statsName:String, mtime:Number):Object
		{
			var keys:Array;
			var i:int;
			var key:String;
			var raw:Object;
			var parsed:Object;
			var file:File;
			keys = getDiscoverCacheKeyCandidates(statsName);
			i = 0;
			while (i < keys.length)
			{
				key = String(keys[i]);
				raw = readDiscoverCacheRaw(key);
				if (!raw)
				{
					i++;
					continue;
				};
				if (raw.hash)
				{
					if (!storedHashMatches(raw, statsName))
					{
						i++;
						continue;
					};
					parsed = parseDiscoverCacheRaw(raw, mtime, false);
					if (parsed)
					{
						cacheDebugLog("discover HIT hash stats=" + statsName + " key=" + key);
						updateCacheManifestDiscover(key, mtime, String(raw.hash));
						migrateDiscoverCacheToCanonicalKey(statsName, key, mtime, parsed);
						return parsed;
					};
				}
				else if (adoptUnhashedCache(raw, statsName, discoverCacheFile(key)))
				{
					parsed = parseDiscoverCacheRaw(raw, mtime, false);
					if (parsed)
					{
						cacheDebugLog("discover HIT adopt stats=" + statsName + " key=" + key);
						updateCacheManifestDiscover(key, mtime, String(raw.hash));
						return parsed;
					};
				};
				parsed = parseDiscoverCacheRaw(raw, mtime, true);
				if (parsed)
				{
					cacheDebugLog("discover HIT strict stats=" + statsName + " key=" + key
						+ " mtime=" + mtime + " fileMtime=" + raw.mtime);
					updateCacheManifestDiscover(key, mtime);
					migrateDiscoverCacheToCanonicalKey(statsName, key, mtime, parsed);
					return parsed;
				};
				if (PaletteMakerUtils.userDeclinedBatchCache)
				{
					parsed = parseDiscoverCacheRaw(raw, mtime, false);
					if (parsed)
					{
						file = discoverCacheFile(key);
						cacheDebugLog("discover HIT lenient stats=" + statsName + " key=" + key
							+ " swfMtime=" + mtime + " fileMtime=" + raw.mtime
							+ " (user declined batch — using existing file"
							+ (file ? ", bytes=" + file.size : "") + ")");
						return parsed;
					};
				};
				cacheDebugLog("discover MISS stats=" + statsName + " key=" + key
					+ " swfMtime=" + mtime + " fileMtime=" + (raw ? raw.mtime : "n/a")
					+ " version=" + (raw ? raw.version : "n/a"));
				i++;
			};
			cacheDebugLog("discover MISS all keys stats=" + statsName + " declined=" + PaletteMakerUtils.userDeclinedBatchCache);
			return loadDiscoverFromBuiltinPack(statsName);
		}

		/**
		 * Load unique cache for editor/on-demand use.
		 * When user declined batch warm, accepts existing on-disk cache even if mtime differs.
		 */
		public static function loadUniqueSpriteCacheForUse(statsName:String, mtime:Number):Array
		{
			var keys:Array;
			var i:int;
			var key:String;
			var raw:Object;
			var parsed:Array;
			var file:File;
			keys = getUniqueCacheKeyCandidates(statsName);
			i = 0;
			while (i < keys.length)
			{
				key = String(keys[i]);
				raw = readUniqueCacheRaw(key);
				if (!raw)
				{
					i++;
					continue;
				};
				if (raw.hash)
				{
					if (!storedHashMatches(raw, statsName))
					{
						i++;
						continue;
					};
					parsed = parseUniqueCacheRaw(raw, mtime, false);
					if (parsed)
					{
						cacheDebugLog("unique HIT hash stats=" + statsName + " key=" + key
							+ " items=" + parsed.length);
						updateCacheManifestUnique(key, mtime, String(raw.hash));
						return parsed;
					};
				}
				else if (adoptUnhashedCache(raw, statsName, uniqueCacheFile(key)))
				{
					parsed = parseUniqueCacheRaw(raw, mtime, false);
					if (parsed)
					{
						cacheDebugLog("unique HIT adopt stats=" + statsName + " key=" + key
							+ " items=" + parsed.length);
						updateCacheManifestUnique(key, mtime, String(raw.hash));
						return parsed;
					};
				};
				parsed = parseUniqueCacheRaw(raw, mtime, true);
				if (parsed)
				{
					cacheDebugLog("unique HIT strict stats=" + statsName + " key=" + key
						+ " mtime=" + mtime + " fileMtime=" + raw.mtime + " items=" + parsed.length);
					updateCacheManifestUnique(key, mtime);
					return parsed;
				};
				if (PaletteMakerUtils.userDeclinedBatchCache)
				{
					parsed = parseUniqueCacheRaw(raw, mtime, false);
					if (parsed)
					{
						file = uniqueCacheFile(key);
						cacheDebugLog("unique HIT lenient stats=" + statsName + " key=" + key
							+ " swfMtime=" + mtime + " fileMtime=" + raw.mtime
							+ " items=" + parsed.length
							+ " (user declined batch — using existing file"
							+ (file ? ", bytes=" + file.size : "") + ")");
						return parsed;
					};
				};
				cacheDebugLog("unique MISS stats=" + statsName + " key=" + key
					+ " swfMtime=" + mtime + " fileMtime=" + (raw ? raw.mtime : "n/a")
					+ " version=" + (raw ? raw.version : "n/a"));
				i++;
			};
			cacheDebugLog("unique MISS all keys stats=" + statsName + " declined=" + PaletteMakerUtils.userDeclinedBatchCache);
			return loadUniqueFromBuiltinPack(statsName);
		}

		public static function loadDiscoverCache(statsName:String, mtime:Number):Object
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			var raw:Object;
			if (!statsName)
			{
				return null;
			};
			try
			{
				folder = PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_discover_cache");
				file = folder.resolvePath(statsName + ".json");
				if (!file.exists)
				{
					return null;
				};
				raw = JsonFile.read(file);
				if (!raw || Number(raw.mtime) != mtime || int(raw.version) != DISCOVER_CACHE_VERSION
					|| !(raw.swap is Array) || !(raw.swapPA is Array))
				{
					return null;
				};
				updateCacheManifestDiscover(statsName, mtime);
				return { "swap": raw.swap as Array, "swapPA": raw.swapPA as Array, "alt": (raw.alt is Array ? raw.alt as Array : []) };
			}
			catch (err:Error)
			{
			};
			return null;
		}

		/**
		 * Delete discover / unique disk caches for a character and clear
		 * freshness memos so the next warm rebuilds from the SWF.
		 */
		public static function invalidateCharacterCaches(statsName:String):void
		{
			var keys:Array;
			var key:String;
			var i:int;
			var scanName:String;
			if (!statsName)
			{
				return;
			};
			keys = getDiscoverCacheKeyCandidates(statsName);
			i = 0;
			while (i < keys.length)
			{
				key = String(keys[i]);
				i++;
				tryDeleteCacheFile(discoverCacheFile(key));
				delete discoverSessionCache[key];
				invalidateDiscoverCacheMemo(key);
			};
			keys = getUniqueCacheKeyCandidates(statsName);
			i = 0;
			while (i < keys.length)
			{
				key = String(keys[i]);
				i++;
				tryDeleteCacheFile(uniqueCacheFile(key));
				invalidateUniqueCacheMemo(key);
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			if (!scanName)
			{
				scanName = statsName;
			};
			CacheWarmPreload.invalidateWarmFreshnessMemo(statsName);
			cacheDebugLog("invalidateCharacterCaches stats=" + statsName + " scan=" + scanName);
		}

		public static function invalidateCharacterCachesBatch(names:Array):void
		{
			var name:String;
			if (!names)
			{
				return;
			};
			for each (name in names)
			{
				invalidateCharacterCaches(String(name));
			};
			PaletteMakerUtils.userDeclinedBatchCache = false;
			PaletteMakerUtils.batchCachePromptAnswered = true;
		}

		private static function tryDeleteCacheFile(file:File):void
		{
			if (!file || !file.exists)
			{
				return;
			};
			try
			{
				file.deleteFile();
			}
			catch (delErr:Error)
			{
			};
		}

		public static function saveDiscoverCache(statsName:String, mtime:Number, swap:Array, swapPA:Array, alt:Array = null):void
		{
			var folder:File;
			var file:File;
			var stream:FileStream;
			if (!statsName)
			{
				return;
			};
			try
			{
				folder = PaletteMakerUtils.COSTUME_FOLDER.resolvePath("_discover_cache");
				if (!folder.exists)
				{
					folder.createDirectory();
				};
				file = folder.resolvePath(statsName + ".json");
				JsonFile.write(file, {
					"version": DISCOVER_CACHE_VERSION,
					"mtime": mtime,
					"hash": characterHash(statsName),
					"swap": swap ? swap : [],
					"swapPA": swapPA ? swapPA : [],
					"alt": alt ? alt : []
				});
				invalidateDiscoverCacheMemo(statsName);
				updateCacheManifestDiscover(statsName, mtime, characterHash(statsName));
			}
			catch (err:Error)
			{
			};
		}

		private static function invalidateDiscoverCacheMemo(cacheKey:String):void
		{
			var chars:Array;
			var i:int;
			var name:String;
			if (!cacheKey)
			{
				return;
			};
			delete CacheWarmPreload.warmFreshnessMemo[cacheKey];
			chars = CacheWarmPreload.listPaletteMakerCharacters();
			i = 0;
			while (i < chars.length)
			{
				name = String(chars[i]);
				if (name && PaletteMakerUtils.getDiscoverCacheKey(name) == cacheKey)
				{
					delete CacheWarmPreload.warmFreshnessMemo[name];
				};
				i++;
			};
		}

		private static function invalidateUniqueCacheMemo(scanName:String):void
		{
			var chars:Array;
			var i:int;
			var name:String;
			if (!scanName)
			{
				return;
			};
			delete CacheWarmPreload.warmFreshnessMemo[scanName];
			chars = CacheWarmPreload.listPaletteMakerCharacters();
			i = 0;
			while (i < chars.length)
			{
				name = String(chars[i]);
				if (name && PaletteMakerUtils.getUniqueSpriteScanStatsName(name) == scanName)
				{
					delete CacheWarmPreload.warmFreshnessMemo[name];
				};
				i++;
			};
		}

		/** Debug: log discover/unique cache sizes for manual parity checks. */
		public static function traceCacheWarmSummary(charName:String):void
		{
			var cacheKey:String;
			var scanName:String;
			var mtime:Number;
			var discover:Object;
			var unique:Array;
			if (!charName)
			{
				return;
			};
			cacheKey = PaletteMakerUtils.getDiscoverCacheKey(charName);
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(charName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scanName);
			discover = loadDiscoverCache(cacheKey, mtime);
			unique = loadUniqueSpriteCache(scanName, mtime);
			trace("[PaletteMakerUtils] Cache summary", charName,
				"discoverKey=" + cacheKey,
				"scanName=" + scanName,
				"swap=" + (discover ? (discover.swap as Array).length : -1),
				"swapPA=" + (discover ? (discover.swapPA as Array).length : -1),
				"uniqueItems=" + (unique ? unique.length : -1),
				"needsWarm=" + CacheWarmPreload.needsPaletteMakerWarm(charName));
		}

		/**
		 * When auto-link changes the canonical discover key (e.g. vegeta →
		 * super_vegeta_vegeta_linked), copy an existing legacy hit so freshness
		 * checks stop forcing a full re-warm.
		 */
		private static function migrateDiscoverCacheToCanonicalKey(statsName:String, hitKey:String, mtime:Number, parsed:Object):void
		{
			var canonical:String;
			if (!statsName || !hitKey || !parsed)
			{
				return;
			};
			canonical = PaletteMakerUtils.getDiscoverCacheKey(statsName);
			if (!canonical || canonical == hitKey)
			{
				return;
			};
			if (discoverCacheFile(canonical) && discoverCacheFile(canonical).exists)
			{
				updateCacheManifestDiscover(canonical, mtime);
				return;
			};
			try
			{
				saveDiscoverCache(canonical, mtime, parsed.swap as Array, parsed.swapPA as Array, parsed.alt as Array);
				cacheDebugLog("discover MIGRATE " + hitKey + " -> " + canonical);
			}
			catch (migErr:Error)
			{
			};
		}

		public static function isDiscoverCacheFresh(statsName:String):Boolean
		{
			var hash:String;
			var keys:Array;
			var i:int;
			var key:String;
			var raw:Object;
			if (!statsName)
			{
				return false;
			};
			hash = characterHash(statsName);
			if (!hash)
			{
				return false;
			};
			keys = getDiscoverCacheKeyCandidates(statsName);
			i = 0;
			while (i < keys.length)
			{
				key = String(keys[i]);
				if (isManifestDiscoverFresh(key, hash))
				{
					return true;
				};
				raw = readDiscoverCacheRaw(key);
				if (raw && String(raw.hash) == hash && int(raw.version) == DISCOVER_CACHE_VERSION
					&& (raw.swap is Array) && (raw.swapPA is Array))
				{
					return true;
				};
				if (raw && !raw.hash && int(raw.version) == DISCOVER_CACHE_VERSION
					&& (raw.swap is Array) && (raw.swapPA is Array)
					&& adoptUnhashedCache(raw, statsName, discoverCacheFile(key)))
				{
					return true;
				};
				i++;
			};
			return false;
		}

		public static function isUniqueSpriteCacheFresh(statsName:String):Boolean
		{
			var hash:String;
			var scanName:String;
			var raw:Object;
			if (!statsName)
			{
				return false;
			};
			hash = characterHash(statsName);
			if (!hash)
			{
				return false;
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			if (!scanName)
			{
				scanName = statsName;
			};
			if (isManifestUniqueFresh(scanName, hash))
			{
				return true;
			};
			raw = readUniqueCacheRaw(scanName);
			if (raw && !raw.hash && int(raw.version) == UNIQUE_SPRITE_CACHE_VERSION && (raw.items is Array)
				&& adoptUnhashedCache(raw, statsName, uniqueCacheFile(scanName)))
			{
				return true;
			};
			return raw != null && String(raw.hash) == hash && int(raw.version) == UNIQUE_SPRITE_CACHE_VERSION
				&& (raw.items is Array);
		}
	}
}
