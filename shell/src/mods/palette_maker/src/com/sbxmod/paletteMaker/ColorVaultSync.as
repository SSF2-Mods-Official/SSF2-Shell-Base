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

	/** Color Vault fetch, preload queue, root index, expansion bundles and catalog merge. */
	public class ColorVaultSync
	{
		private static const COLOR_VAULT_BASE_URL:String = "https://raw.githubusercontent.com/masterwebx/Color-Vault/master/";

		private static const COLOR_VAULT_ROOT_API_URL:String = "https://api.github.com/repos/masterwebx/Color-Vault/contents?ref=master";

		internal static const COLOR_VAULT_PACKS_API_URL:String = "https://api.github.com/repos/masterwebx/Color-Vault/contents/packs?ref=master";

		internal static const COLOR_VAULT_PACKS_RAW_BASE:String = COLOR_VAULT_BASE_URL + "packs/";

		private static const VAULT_CACHE_SO_NAME:String = "ssf2_color_vault_meta";

		private static const PRELOAD_CONCURRENCY:int = 2;

		/** Shared Color Vault file. Each costume object names its character. */
		private static const EXPANSIONS_VAULT_FILE:String = "expansions.as";

		/** slug (alnum only) -> Array of vault filenames like "meta_knight.as". */
		private static var vaultRootFileIndex:Object = null;

		/** slug -> Array of costumes from expansions.as. Null until this launch's check finishes. */
		private static var expansionVaultBySlug:Object = null;

		/** Hash of the expansions.as body from this launch, folded into each character's catalog hash. */
		private static var expansionVaultContentHash:String = "";

		private static var expansionVaultLoading:Boolean = false;

		private static var expansionVaultWaiters:Array = [];

		/** vault filename -> GitHub contents size, used to skip an unchanged catalog. */
		private static var vaultRootFileSizes:Object = null;

		private static var vaultRootIndexLoading:Boolean = false;

		private static var vaultRootIndexWaiters:Array = [];

		private static var preloadQueue:Array = [];

		private static var preloadActive:int = 0;

		private static var preloadRunning:Boolean = false;
		private static const ONLINE_REFRESH_MS:Number = 600000;
		private static var lastOnlineRefreshAt:Number = 0;

		private static var preloadDone:int = 0;

		private static var preloadTotal:int = 0;

		internal static var preloadProgressFn:Function = null;

		internal static var preloadDoneFn:Function = null;

		private static var preloadIndexTimer:Timer = null;

		/** Queue a vault fetch for every costume-compatible character. Does not require the online lobby. */
		public static function preloadAllColorVaultCostumes():void
		{
			var chars:Array;
			if (preloadRunning)
			{
				return;
			};
			try
			{
				chars = PaletteMakerUtils.getCharsCompatibleWithCostumes();
			}
			catch (err:Error)
			{
				trace("[PaletteMakerUtils] preloadAllColorVaultCostumes failed to list characters:", err.message);
				finishPreload();
				return;
			};
			if (!chars || chars.length == 0)
			{
				finishPreload();
				return;
			};
			preloadRunning = true;
			preloadQueue = chars.concat();
			preloadActive = 0;
			preloadDone = 0;
			preloadTotal = preloadQueue.length;
			trace("[PaletteMakerUtils] Preloading Color Vault for", preloadQueue.length, "characters");
			pumpColorVaultPreload();
		}

		/**
		 * Fetch vault costumes for one character, or all compatible characters when statsName is null/empty.
		 * Each costume is tagged with _packStatsName. Batched — safe for export UI merge.
		 * options: onComplete(Array), onError(), onProgress(done,total)
		 */
		public static function fetchColorVaultCostumesForExport(statsName:String, options:Object=null):void
		{
			var chars:Array;
			var queue:Array;
			var active:int;
			var results:Array;
			var total:int;
			var done:int;
			var pump:Function;
			options = options || {};
			results = [];
			if (statsName && String(statsName).length > 0)
			{
				fetchColorVaultCostumes(statsName, {
					"onComplete": function(list:Array):void
					{
						var costume:Object;
						var out:Array = [];
						for each (costume in (list || []))
						{
							if (!costume)
							{
								continue;
							};
							costume = Ssf2.Utils.cloneObject(costume);
							costume._packStatsName = statsName;
							out.push(costume);
						};
						if (options.onComplete != null)
						{
							options.onComplete(out);
						};
					},
					"onError": options.onError,
					"onParseError": options.onParseError || options.onError
				});
				return;
			};
			try
			{
				chars = PaletteMakerUtils.getCharsCompatibleWithCostumes();
			}
			catch (err:Error)
			{
				chars = [];
			};
			if (!chars || chars.length == 0)
			{
				if (options.onComplete != null)
				{
					options.onComplete([]);
				};
				return;
			};
			queue = chars.concat();
			total = queue.length;
			done = 0;
			active = 0;
			pump = function():void
			{
				var name:String;
				while (active < 2 && queue.length > 0)
				{
					name = String(queue.shift());
					active++;
					(function(charName:String):void
					{
						fetchColorVaultCostumes(charName, {
							"onComplete": function(list:Array):void
							{
								var costume:Object;
								for each (costume in (list || []))
								{
									if (!costume)
									{
										continue;
									};
									costume = Ssf2.Utils.cloneObject(costume);
									costume._packStatsName = charName;
									results.push(costume);
								};
								active--;
								done++;
								if (options.onProgress != null)
								{
									options.onProgress(done, total);
								};
								if (queue.length == 0 && active <= 0)
								{
									if (options.onComplete != null)
									{
										options.onComplete(results);
									};
								}
								else
								{
									pump();
								};
							},
							"onError": function():void
							{
								active--;
								done++;
								if (options.onProgress != null)
								{
									options.onProgress(done, total);
								};
								if (queue.length == 0 && active <= 0)
								{
									if (options.onComplete != null)
									{
										options.onComplete(results);
									};
								}
								else
								{
									pump();
								};
							},
							"onParseError": function():void
							{
								active--;
								done++;
								if (queue.length == 0 && active <= 0)
								{
									if (options.onComplete != null)
									{
										options.onComplete(results);
									};
								}
								else
								{
									pump();
								};
							}
						});
					})(name);
				};
			};
			pump();
		}

		private static function pumpColorVaultPreload():void
		{
			var statsName:String;
			while (preloadActive < PRELOAD_CONCURRENCY && preloadQueue.length > 0)
			{
				statsName = String(preloadQueue.shift());
				if (repoFileBytes(statsName) < 0)
				{
					portLocalPicksIfNeeded(statsName);
					preloadDone++;
					reportPreloadProgress();
					continue;
				};
				if (localVaultIndexMatches(statsName))
				{
					preloadDone++;
					reportPreloadProgress();
					trace("[PaletteMakerUtils] Skip", statsName, "costume index count unchanged");
					continue;
				};
				preloadActive++;
				(function(name:String):void
				{
					fetchColorVaultCostumes(name, {
						"upsert": true,
						"skipIfUnchanged": true,
						"onComplete": function(list:Array):void
						{
							notePreloadCharacterDone();
						},
						"onError": function():void
						{
							notePreloadCharacterDone();
						},
						"onParseError": function():void
						{
							notePreloadCharacterDone();
						}
					});
				})(statsName);
			};
			if (preloadQueue.length == 0 && preloadActive <= 0)
			{
				trace("[PaletteMakerUtils] Color Vault preload complete");
				finishPreload();
			};
		}

		private static function notePreloadCharacterDone():void
		{
			preloadActive--;
			preloadDone++;
			reportPreloadProgress();
			if (preloadQueue.length == 0 && preloadActive <= 0)
			{
				trace("[PaletteMakerUtils] Color Vault preload complete");
				finishPreload();
			}
			else
			{
				pumpColorVaultPreload();
			};
		}

		private static function reportPreloadProgress():void
		{
			var pct:Number;
			if (preloadProgressFn == null)
			{
				return;
			};
			pct = preloadTotal > 0 ? (preloadDone / preloadTotal) * 100 : 100;
			preloadProgressFn(pct);
		}

		internal static function finishPreload():void
		{
			var done:Function = preloadDoneFn;
			stopPreloadIndexTimer();
			preloadRunning = false;
			preloadDoneFn = null;
			preloadProgressFn = null;
			if (done != null)
			{
				done();
			};
		}

		internal static function armPreloadIndexTimer():void
		{
			stopPreloadIndexTimer();
			preloadIndexTimer = new Timer(20000, 1);
			preloadIndexTimer.addEventListener(TimerEvent.TIMER, onPreloadIndexTimeout);
			preloadIndexTimer.start();
		}

		private static function onPreloadIndexTimeout(e:TimerEvent):void
		{
			trace("[PaletteMakerUtils] Color Vault index timed out, continuing boot");
			finishPreload();
		}

		internal static function stopPreloadIndexTimer():void
		{
			if (!preloadIndexTimer)
			{
				return;
			};
			preloadIndexTimer.stop();
			preloadIndexTimer.removeEventListener(TimerEvent.TIMER, onPreloadIndexTimeout);
			preloadIndexTimer = null;
		}

		/** Sum of GitHub file sizes for this character, or -1 when the repo has no file. */
		private static function repoFileBytes(statsName:String):int
		{
			var names:Array;
			var fileName:String;
			var total:int = 0;
			var found:int = 0;
			if (!vaultRootFileSizes)
			{
				return -1;
			};
			names = resolveVaultFilenames(statsName, vaultRootFileIndex);
			for each (fileName in names)
			{
				if (vaultRootFileSizes.hasOwnProperty(fileName))
				{
					total += int(vaultRootFileSizes[fileName]);
					found++;
				};
			};
			if (expansionSliceFor(statsName) != null && vaultRootFileSizes.hasOwnProperty(EXPANSIONS_VAULT_FILE))
			{
				total += int(vaultRootFileSizes[EXPANSIONS_VAULT_FILE]);
				found++;
			};
			return found > 0 ? total : -1;
		}

		/**
		 * True when the saved catalog's online index count still matches the repo file.
		 * The contents listing has no array length, so an unchanged file size means the index count is unchanged.
		 */
		private static function localVaultIndexMatches(statsName:String):Boolean
		{
			var meta:Object;
			var remote:int;
			var saved:int;
			var file:File;
			remote = repoFileBytes(statsName);
			if (remote <= 0)
			{
				return false;
			};
			file = PaletteMakerUtils.COSTUME_FOLDER.resolvePath(statsName + PaletteMakerUtils.COSTUME_FILE_EXTENSION);
			if (!file.exists)
			{
				return false;
			};
			meta = getVaultCacheMeta();
			if (!meta || !meta[statsName] || !meta[statsName].hasOwnProperty("onlineCount"))
			{
				return false;
			};
			if (int(meta[statsName].onlineCount) <= 0)
			{
				return false;
			};
			if (meta[statsName].hasOwnProperty("remoteSize") && int(meta[statsName].remoteSize) > 0)
			{
				saved = int(meta[statsName].remoteSize);
			}
			else
			{
				saved = int(meta[statsName].length);
			};
			return saved == remote;
		}

		/** Documents file with no favorites yet is the palette menu. Keep those indexes. */
		private static function portLocalPicksIfNeeded(statsName:String):void
		{
			var list:Array;
			var favs:Array;
			var i:int;
			if (!statsName || PaletteMakerUtils.favoritesFileExists(statsName))
			{
				return;
			};
			PaletteMakerUtils.ensureCostumeFileLoaded(statsName);
			list = PaletteMakerUtils.getCostume(statsName);
			if (!list || list.length == 0)
			{
				return;
			};
			favs = [];
			i = 0;
			while (i < list.length)
			{
				favs.push(i);
				i++;
			};
			PaletteMakerUtils.setFavoriteIndexes(statsName, favs);
			trace("[PaletteMakerUtils] Ported", favs.length, "picked costumes for", statsName);
		}

		internal static function getVaultCacheMeta():Object
		{
			var so:SharedObject;
			try
			{
				so = SharedObject.getLocal(VAULT_CACHE_SO_NAME);
				if (!so.data.meta)
				{
					so.data.meta = {};
				};
				return so.data.meta;
			}
			catch (err:Error)
			{
				return {};
			};
			return {};
		}

		private static function setVaultCacheMeta(statsName:String, hash:String, length:int, onlineCount:int, remoteSize:int = 0):void
		{
			var so:SharedObject;
			try
			{
				so = SharedObject.getLocal(VAULT_CACHE_SO_NAME);
				if (!so.data.meta)
				{
					so.data.meta = {};
				};
				so.data.meta[statsName] = {
					"hash": hash,
					"length": length,
					"onlineCount": onlineCount,
					"remoteSize": remoteSize,
					"fetchedAt": getTimer()
				};
				so.flush();
			}
			catch (err:Error)
			{
			};
		}

		/** Bust AIR/client URL cache; also helps when raw.githubusercontent.com edges hold stale copies. */
		internal static function withCacheBust(url:String):String
		{
			if (!url)
			{
				return url;
			};
			return url + ((url.indexOf("?") >= 0) ? "&" : "?") + "_=" + new Date().time;
		}

		internal static function applyNoCacheHeaders(req:URLRequest, extra:Array=null):void
		{
			var headers:Array;
			if (!req)
			{
				return;
			};
			headers = [
				new URLRequestHeader("Cache-Control", "no-cache"),
				new URLRequestHeader("Pragma", "no-cache")
			];
			if (extra && extra.length > 0)
			{
				headers = headers.concat(extra);
			};
			try
			{
				req.requestHeaders = headers;
			}
			catch (hdrErr:Error)
			{
			};
		}

		public static function fetchColorVaultCostumes(statsName:String, options:Object=null):void
		{
			ensureVaultRootFileIndex(function(index:Object):void
			{
				ensureExpansionVaultBundle(function():void
				{
					var candidates:Array = resolveVaultFilenames(statsName, index);
					fetchAndMergeVaultCandidates(statsName, candidates, 0, [], "", 0, options);
				});
			});
		}

		/** Browser open: drop the cached repo file list so this character refetches the latest catalog. */
		public static function fetchColorVaultCostumesFresh(statsName:String, options:Object=null):void
		{
			if (!vaultRootIndexLoading && (!vaultRootIndexWaiters || vaultRootIndexWaiters.length == 0))
			{
				vaultRootFileIndex = null;
				vaultRootFileSizes = null;
			};
			if (!expansionVaultLoading && (!expansionVaultWaiters || expansionVaultWaiters.length == 0))
			{
				expansionVaultBySlug = null;
				expansionVaultContentHash = "";
			};
			fetchColorVaultCostumes(statsName, options);
		}

		/**
		 * Online menu: refetch the repo file list and re-run the preload so every player online
		 * indexes the same catalog. At most once per ONLINE_REFRESH_MS (api.github.com is rate limited).
		 */
		public static function refreshForOnline():void
		{
			var now:Number = new Date().time;
			if (preloadRunning || (lastOnlineRefreshAt > 0 && now - lastOnlineRefreshAt < ONLINE_REFRESH_MS))
			{
				return;
			};
			lastOnlineRefreshAt = now;
			if (!vaultRootIndexLoading && (!vaultRootIndexWaiters || vaultRootIndexWaiters.length == 0))
			{
				vaultRootFileIndex = null;
				vaultRootFileSizes = null;
			};
			if (!expansionVaultLoading && (!expansionVaultWaiters || expansionVaultWaiters.length == 0))
			{
				expansionVaultBySlug = null;
				expansionVaultContentHash = "";
			};
			trace("[palette_maker] online menu: refreshing Color Vault catalog");
			preloadAllColorVaultCostumes();
		}

		private static function normalizeVaultSlug(name:String):String
		{
			if (!name)
			{
				return "";
			};
			return String(name).toLowerCase().replace(/\.as$/i, "").replace(/[_-]/g, "");
		}

		/** Costumes in expansions.as for this character, or null when this launch's file has none. */
		private static function expansionSliceFor(statsName:String):Array
		{
			var slug:String;
			var slice:Array;
			if (!expansionVaultBySlug || !statsName)
			{
				return null;
			};
			slug = normalizeVaultSlug(statsName);
			slice = expansionVaultBySlug[slug] as Array;
			if (!slice || slice.length == 0)
			{
				return null;
			};
			return slice;
		}

		/**
		 * Download expansions.as once per launch, after the repo file list is known.
		 * Every later character check reads the grouped cache instead of fetching the file again.
		 */
		internal static function ensureExpansionVaultBundle(onReady:Function):void
		{
			var loader:URLLoader;
			var req:URLRequest;
			if (expansionVaultBySlug)
			{
				if (onReady != null)
				{
					onReady();
				};
				return;
			};
			if (onReady != null)
			{
				expansionVaultWaiters.push(onReady);
			};
			if (expansionVaultLoading)
			{
				return;
			};
			expansionVaultLoading = true;
			if (!vaultRootFileSizes || !vaultRootFileSizes.hasOwnProperty(EXPANSIONS_VAULT_FILE))
			{
				finishExpansionVaultBundle({}, "");
				return;
			};
			loader = new URLLoader();
			req = new URLRequest(withCacheBust(COLOR_VAULT_BASE_URL + EXPANSIONS_VAULT_FILE));
			applyNoCacheHeaders(req);
			loader.addEventListener(Event.COMPLETE, function(e:Event):void
			{
				var raw:String;
				var parsed:*;
				var list:Array;
				var map:Object;
				var i:int;
				var entry:Object;
				var characterName:String;
				var slug:String;
				raw = "";
				try
				{
					raw = String(e.target.data);
					parsed = JSON.parse(raw);
					list = parsed as Array;
					map = {};
					if (list)
					{
						i = 0;
						while (i < list.length)
						{
							entry = PaletteMakerUtils.normalizeColorVaultCostume(list[i]);
							characterName = entry && entry.hasOwnProperty("character") ? PaletteMakerUtils.trimString(String(entry.character)) : "";
							slug = normalizeVaultSlug(characterName);
							if (!slug)
							{
								i++;
								continue;
							};
							entry["character"] = characterName;
							delete entry["colorVaultId"];
							if (!(map[slug] is Array))
							{
								map[slug] = [];
							};
							(map[slug] as Array).push(entry);
							i++;
						};
					};
					finishExpansionVaultBundle(map, PaletteMakerUtils.simpleContentHash(raw));
				}
				catch (err:Error)
				{
					trace("[PaletteMakerUtils] expansions.as parse failed:", err.message);
					finishExpansionVaultBundle({}, "");
				};
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void
			{
				trace("[PaletteMakerUtils] expansions.as fetch failed");
				finishExpansionVaultBundle({}, "");
			});
			loader.load(req);
		}

		private static function finishExpansionVaultBundle(map:Object, contentHash:String):void
		{
			var waiters:Array;
			var cb:Function;
			expansionVaultBySlug = map || {};
			expansionVaultContentHash = contentHash || "";
			expansionVaultLoading = false;
			waiters = expansionVaultWaiters;
			expansionVaultWaiters = [];
			for each (cb in waiters)
			{
				if (cb != null)
				{
					cb();
				};
			};
		}

		/** Append this character's expansions.as slice. Returns the hash accumulator with the shared-file hash folded in. */
		private static function appendExpansionSlice(statsName:String, buckets:Array, hashAcc:String):String
		{
			var slice:Array;
			var list:Array;
			var i:int;
			var entry:Object;
			slice = expansionSliceFor(statsName);
			if (!slice)
			{
				return hashAcc;
			};
			list = [];
			i = 0;
			while (i < slice.length)
			{
				entry = PaletteMakerUtils.normalizeColorVaultCostume(Ssf2.Utils.cloneObject(slice[i]));
				entry["character"] = statsName;
				delete entry["colorVaultId"];
				delete entry["_vaultFile"];
				list.push(entry);
				i++;
			};
			buckets.push({
				"fileName": EXPANSIONS_VAULT_FILE,
				"list": list,
				"primary": false
			});
			if (expansionVaultContentHash && expansionVaultContentHash.length > 0)
			{
				hashAcc = hashAcc + "|exp:" + expansionVaultContentHash;
			};
			return hashAcc;
		}

		/** List Color Vault root .as files once so metaknight / meta_knight both resolve. */
		internal static function ensureVaultRootFileIndex(onReady:Function):void
		{
			var loader:URLLoader;
			var req:URLRequest;
			if (vaultRootFileIndex)
			{
				if (onReady != null)
				{
					onReady(vaultRootFileIndex);
				};
				return;
			};
			if (onReady != null)
			{
				vaultRootIndexWaiters.push(onReady);
			};
			if (vaultRootIndexLoading)
			{
				return;
			};
			vaultRootIndexLoading = true;
			loader = new URLLoader();
			req = new URLRequest(withCacheBust(COLOR_VAULT_ROOT_API_URL));
			applyNoCacheHeaders(req, [
				new URLRequestHeader("Accept", "application/vnd.github.v3+json"),
				new URLRequestHeader("User-Agent", "SSF2-PaletteMaker")
			]);
			loader.addEventListener(Event.COMPLETE, function(e:Event):void
			{
				var list:*;
				var entry:Object;
				var fileName:String;
				var slug:String;
				var index:Object = {};
				var sizes:Object = {};
				var waiters:Array;
				var cb:Function;
				try
				{
					list = JSON.parse(String(e.target.data));
					if (list is Array)
					{
						for each (entry in list)
						{
							if (!entry || entry.type != "file")
							{
								continue;
							};
							fileName = entry.name ? String(entry.name) : "";
							if (fileName.toLowerCase().indexOf(".as") < 0)
							{
								continue;
							};
							slug = normalizeVaultSlug(fileName);
							if (!slug)
							{
								continue;
							};
							if (!(index[slug] is Array))
							{
								index[slug] = [];
							};
							(index[slug] as Array).push(fileName);
							sizes[fileName] = int(entry.size);
						};
					};
				}
				catch (parseErr:Error)
				{
					trace("[PaletteMakerUtils] Color Vault root index parse failed:", parseErr.message);
					index = {};
					sizes = {};
				};
				vaultRootFileIndex = index;
				vaultRootFileSizes = sizes;
				vaultRootIndexLoading = false;
				waiters = vaultRootIndexWaiters;
				vaultRootIndexWaiters = [];
				for each (cb in waiters)
				{
					if (cb != null)
					{
						cb(vaultRootFileIndex);
					};
				};
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void
			{
				var waiters:Array;
				var cb:Function;
				trace("[PaletteMakerUtils] Color Vault root index fetch failed — using filename guesses");
				vaultRootFileIndex = {};
				vaultRootFileSizes = {};
				vaultRootIndexLoading = false;
				waiters = vaultRootIndexWaiters;
				vaultRootIndexWaiters = [];
				for each (cb in waiters)
				{
					if (cb != null)
					{
						cb(vaultRootFileIndex);
					};
				};
			});
			try
			{
				loader.load(req);
			}
			catch (loadErr:Error)
			{
				var failWaiters:Array = vaultRootIndexWaiters;
				var failCb:Function;
				vaultRootFileIndex = {};
				vaultRootFileSizes = {};
				vaultRootIndexLoading = false;
				vaultRootIndexWaiters = [];
				for each (failCb in failWaiters)
				{
					if (failCb != null)
					{
						failCb(vaultRootFileIndex);
					};
				};
			};
		}

		private static function getColorVaultFilenameCandidates(statsName:String):Array
		{
			var names:Array = [];
			var seen:Object = {};
			function addName(name:String):void
			{
				if (!name || seen[name])
				{
					return;
				};
				seen[name] = true;
				names.push(name + ".as");
			};
			addName(statsName);
			addName(statsName.replace(/_/g, ""));
			addName(statsName.replace(/_/g, "-"));
			addName(statsName.replace(/-/g, "_"));
			addName(statsName.replace(/-/g, ""));
			return names;
		}

		private static function resolveVaultFilenames(statsName:String, index:Object):Array
		{
			var names:Array = [];
			var seen:Object = {};
			var slug:String = normalizeVaultSlug(statsName);
			var fromIndex:Array;
			var fileName:String;
			var guess:Array;
			function addFile(name:String):void
			{
				if (!name || seen[name])
				{
					return;
				};
				if (name.toLowerCase() == EXPANSIONS_VAULT_FILE)
				{
					return;
				};
				seen[name] = true;
				names.push(name);
			};
			// Prefer the exact game id file first (keeps colorVaultId indices stable).
			addFile(statsName + ".as");
			fromIndex = (index && index[slug] is Array) ? (index[slug] as Array) : null;
			if (fromIndex)
			{
				for each (fileName in fromIndex)
				{
					addFile(fileName);
				};
			};
			guess = getColorVaultFilenameCandidates(statsName);
			for each (fileName in guess)
			{
				addFile(fileName);
			};
			return names;
		}

		private static function costumeMergeKey(costume:Object):String
		{
			var info:String;
			var profile:String;
			var author:String;
			if (!costume)
			{
				return "";
			};
			if (costume.hasOwnProperty("info") && costume.info)
			{
				info = PaletteMakerUtils.trimString(String(costume.info)).toLowerCase();
				if (info.length > 0)
				{
					return info;
				};
			};
			profile = costume.hasOwnProperty("profile") ? PaletteMakerUtils.trimString(String(costume.profile)).toLowerCase() : "";
			author = PaletteMakerUtils.extractAuthorFromCostume(costume).toLowerCase();
			return profile + "|" + author;
		}

		/**
		 * Fetch every matching vault filename and merge unique costumes.
		 * Fixes splits like metaknight.as vs meta_knight.as where new pals land in the underscore file.
		 */
		private static function fetchAndMergeVaultCandidates(statsName:String, candidates:Array, index:int, buckets:Array, hashAcc:String, byteAcc:int, options:Object):void
		{
			var fileName:String;
			var url:String;
			var loader:URLLoader;
			var req:URLRequest;
			var sizeKey:String;
			var hasSizes:Boolean;
			if (index >= candidates.length)
			{
				hashAcc = appendExpansionSlice(statsName, buckets, hashAcc);
				finalizeMergedVaultFetch(statsName, buckets, hashAcc, byteAcc, options);
				return;
			};
			fileName = candidates[index];
			if (vaultRootFileSizes)
			{
				hasSizes = false;
				for (sizeKey in vaultRootFileSizes)
				{
					hasSizes = true;
					break;
				};
				if (hasSizes && !vaultRootFileSizes.hasOwnProperty(fileName))
				{
					fetchAndMergeVaultCandidates(statsName, candidates, index + 1, buckets, hashAcc, byteAcc, options);
					return;
				};
			};
			url = withCacheBust(COLOR_VAULT_BASE_URL + fileName);
			loader = new URLLoader();
			req = new URLRequest(url);
			applyNoCacheHeaders(req);
			loader.addEventListener(Event.COMPLETE, function(e:Event):void
			{
				var raw:String;
				var parsed:*;
				var list:Array;
				var normalized:Array;
				var i:int;
				var entry:Object;
				try
				{
					raw = String(e.target.data);
					parsed = JSON.parse(raw);
					list = parsed as Array;
					if (!list)
					{
						throw new Error("Color Vault payload was not an array");
					};
					normalized = [];
					for (i = 0; i < list.length; i++)
					{
						entry = PaletteMakerUtils.normalizeColorVaultCostume(list[i]);
						if (entry.hasOwnProperty("character") && PaletteMakerUtils.trimString(String(entry.character)).length > 0)
						{
							if (normalizeVaultSlug(String(entry.character)) != normalizeVaultSlug(statsName))
							{
								continue;
							};
						};
						entry["character"] = statsName;
						entry["_vaultFile"] = fileName;
						normalized.push(entry);
					};
					buckets.push({
						"fileName": fileName,
						"list": normalized,
						"primary": fileName.toLowerCase() == (statsName + ".as").toLowerCase()
					});
					hashAcc = hashAcc + "|" + PaletteMakerUtils.simpleContentHash(raw);
					byteAcc = byteAcc + raw.length;
				}
				catch (err:Error)
				{
				};
				fetchAndMergeVaultCandidates(statsName, candidates, index + 1, buckets, hashAcc, byteAcc, options);
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void
			{
				fetchAndMergeVaultCandidates(statsName, candidates, index + 1, buckets, hashAcc, byteAcc, options);
			});
			loader.load(req);
		}

		private static function finalizeMergedVaultFetch(statsName:String, buckets:Array, hashAcc:String, byteAcc:int, options:Object):void
		{
			var merged:Array = [];
			var seenKeys:Object = {};
			var bucket:Object;
			var list:Array;
			var entry:Object;
			var key:String;
			var i:int;
			var hash:String;
			var meta:Object;
			var unchanged:Boolean;
			var remoteSize:int;
			var primaryFirst:Array = [];
			var others:Array = [];
			if (!buckets || buckets.length == 0)
			{
				if (options && options.onError != null)
				{
					options.onError();
				};
				trace("[PaletteMakerUtils] No Color Vault file for", statsName);
				return;
			};
			for each (bucket in buckets)
			{
				if (bucket && bucket.primary)
				{
					primaryFirst.push(bucket);
				}
				else
				{
					others.push(bucket);
				};
			};
			for each (bucket in primaryFirst.concat(others))
			{
				list = bucket.list as Array;
				if (!list)
				{
					continue;
				};
				for (i = 0; i < list.length; i++)
				{
					entry = list[i];
					key = costumeMergeKey(entry);
					if (!key || seenKeys[key])
					{
						continue;
					};
					seenKeys[key] = true;
					delete entry["colorVaultId"];
					delete entry["_vaultFile"];
					merged.push(entry);
				};
			};
			hash = PaletteMakerUtils.simpleContentHash(hashAcc + "#" + merged.length);
			meta = getVaultCacheMeta();
			unchanged = (options && options.skipIfUnchanged && meta && meta[statsName] && meta[statsName].hash == hash && int(meta[statsName].length) == byteAcc && meta[statsName].hasOwnProperty("onlineCount"));
			remoteSize = repoFileBytes(statsName);
			if (remoteSize < 0)
			{
				remoteSize = 0;
			};
			if (!unchanged || PaletteMakerUtils.getCostume(statsName).length == 0)
			{
				commitVaultCatalog(statsName, merged);
				setVaultCacheMeta(statsName, hash, byteAcc, merged.length, remoteSize);
				trace("[PaletteMakerUtils] Saved Color Vault catalog", statsName, "entries=", merged.length, "files=", buckets.length);
			}
			else
			{
				if (remoteSize > 0 && int(meta[statsName].remoteSize) != remoteSize)
				{
					setVaultCacheMeta(statsName, hash, byteAcc, merged.length, remoteSize);
				};
				trace("[PaletteMakerUtils] Color Vault unchanged, skip rewrite", statsName);
			};
			i = 0;
			while (i < merged.length)
			{
				if (merged[i])
				{
					merged[i]._catalogIndex = i;
					delete merged[i]["colorVaultId"];
				};
				i++;
			};
			if (options && options.onComplete != null)
			{
				options.onComplete(merged);
			};
			trace("[PaletteMakerUtils] Loaded Color Vault", statsName, "entries=", merged.length, "files=", buckets.length);
		}

		/**
		 * Online costumes occupy catalog indexes 0..n-1 in repo order.
		 * A local entry is removed only when its colors and replacements exactly match an online index.
		 * That favorite slot then points at the online index. Other locals stay at the end.
		 */
		private static function commitVaultCatalog(statsName:String, online:Array):void
		{
			var existing:Array;
			var hadFavorites:Boolean;
			var previousFavs:Array;
			var onlineSigs:Array;
			var buckets:Object;
			var kept:Array;
			var newList:Array;
			var retarget:Object;
			var oldToNew:Object;
			var i:int;
			var j:int;
			var sig:String;
			var hash:String;
			var bucket:Array;
			var match:int;
			var entry:Object;
			var outFav:Array;
			var mapped:int;
			var seenFav:Object;
			if (!statsName)
			{
				return;
			};
			PaletteMakerUtils.ensureCostumeFileLoaded(statsName);
			existing = PaletteMakerUtils.getCostume(statsName);
			if (!existing)
			{
				existing = [];
			};
			hadFavorites = PaletteMakerUtils.favoritesFileExists(statsName);
			previousFavs = hadFavorites ? PaletteMakerUtils.getFavoriteIndexes(statsName).concat() : [];
			onlineSigs = [];
			buckets = {};
			kept = [];
			newList = [];
			retarget = {};
			oldToNew = {};
			i = 0;
			while (online && i < online.length)
			{
				entry = stripCatalogMeta(online[i]);
				entry["character"] = statsName;
				newList.push(entry);
				sig = PaletteMakerUtils.paletteSignature(entry);
				onlineSigs.push(sig);
				hash = PaletteMakerUtils.fnv1aHex(sig);
				if (!(buckets[hash] is Array))
				{
					buckets[hash] = [];
				};
				(buckets[hash] as Array).push(i);
				i++;
			};
			i = 0;
			while (i < existing.length)
			{
				sig = PaletteMakerUtils.paletteSignature(existing[i]);
				hash = PaletteMakerUtils.fnv1aHex(sig);
				match = -1;
				bucket = buckets[hash] as Array;
				if (bucket && sig)
				{
					j = 0;
					while (j < bucket.length)
					{
						if (onlineSigs[int(bucket[j])] == sig)
						{
							match = int(bucket[j]);
							break;
						};
						j++;
					};
				};
				if (match >= 0)
				{
					retarget[i] = match;
				}
				else
				{
					entry = stripCatalogMeta(existing[i]);
					entry["character"] = statsName;
					kept.push({
						"oldIndex": i,
						"costume": entry
					});
				};
				i++;
			};
			i = 0;
			while (i < kept.length)
			{
				oldToNew[kept[i].oldIndex] = newList.length;
				newList.push(kept[i].costume);
				i++;
			};
			CostumePackIO.replaceCostumeList(statsName, newList);
			outFav = [];
			seenFav = {};
			if (!hadFavorites)
			{
				// The documents file was the palette menu. Keep every picked costume, in that order.
				i = 0;
				while (i < existing.length)
				{
					if (retarget.hasOwnProperty(String(i)))
					{
						mapped = int(retarget[i]);
					}
					else if (oldToNew.hasOwnProperty(String(i)))
					{
						mapped = int(oldToNew[i]);
					}
					else
					{
						i++;
						continue;
					};
					if (mapped >= 0 && mapped < newList.length && !seenFav[mapped])
					{
						seenFav[mapped] = true;
						outFav.push(mapped);
					};
					i++;
				};
			}
			else
			{
				i = 0;
				while (i < previousFavs.length)
				{
					mapped = int(previousFavs[i]);
					if (retarget.hasOwnProperty(String(mapped)))
					{
						mapped = int(retarget[mapped]);
					}
					else if (oldToNew.hasOwnProperty(String(mapped)))
					{
						mapped = int(oldToNew[mapped]);
					}
					else
					{
						i++;
						continue;
					};
					if (mapped >= 0 && mapped < newList.length && !seenFav[mapped])
					{
						seenFav[mapped] = true;
						outFav.push(mapped);
					};
					i++;
				};
			};
			PaletteMakerUtils.setFavoriteIndexes(statsName, outFav);
		}

		private static function stripCatalogMeta(costume:Object):Object
		{
			var copy:Object = PaletteMakerUtils.repairCostumeData(Ssf2.Utils.cloneObject(costume || {}));
			delete copy["colorVaultId"];
			delete copy["_vaultFile"];
			delete copy["_catalogIndex"];
			delete copy["_gameCostumeIndex"];
			delete copy["_packStatsName"];
			delete copy["team"];
			delete copy["cssTeam"];
			delete copy["base"];
			delete copy["noRecolor"];
			delete copy["metal"];
			return copy;
		}
	}
}
