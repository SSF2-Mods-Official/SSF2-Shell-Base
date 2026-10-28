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
	import flash.desktop.NativeApplication;
	import flash.net.SharedObject;
	import flash.filters.ColorMatrixFilter;
	import com.mcleodgaming.ssf2.util.PaletteDeep;

	/** Cache warm: freshness check, discover preload queue, blocking warm UI. */
	public class CacheWarmPreload
	{
		private static var discoverPreloadQueue:Array = [];

		private static var discoverPreloadWorkQueue:Array = [];

		private static var discoverPreloadBusy:Boolean = false;

		internal static var discoverPreloadRunning:Boolean = false;

		private static var discoverPreloadTotal:int = 0;

		private static var discoverPreloadDone:int = 0;

		internal static var discoverPreloadOnProgress:Function = null;

		internal static var discoverPreloadOnComplete:Function = null;

		private static var paletteMakerWarmSessionDone:Boolean = false;

		/** scanStatsName -> roster character IDs sharing that SWF scan. */
		private static var discoverPreloadRosterByScan:Object = {};

		/** Next SWF prefetch (overlaps CPU warm of current char). */
		private static var discoverPreloadPrefetchName:String = null;

		private static var discoverPreloadPrefetchBusy:Boolean = false;

		private static var discoverPreloadPrefetchReady:Boolean = false;

		private static var warmIncrementalPendingName:String = null;

		/** One character SWF load at a time — avoids mid-warm crashes. */
		private static const DISCOVER_PRELOAD_BATCH_SIZE:int = 1;

		/** Background freshness scan: chars checked per frame. */
		private static const FRESHNESS_SLICE:int = 5;

		private static var freshnessCheckQueue:Array = null;

		private static var freshnessCheckPending:Array = null;

		private static var freshnessCheckCallback:Function = null;

		internal static var warmFreshnessMemo:Object = {};

		internal static var cacheWarmOverlay:Sprite = null;

		private static var cacheWarmTitle:TextField = null;

		private static var cacheWarmDetail:TextField = null;

		private static var cacheWarmStartMs:int = 0;

		private static var cacheWarmSavedMusicMuted:Boolean = false;

		private static var cacheWarmAudioHeld:Boolean = false;

		private static var cacheWarmAwaitingDismiss:Boolean = false;

		private static var cacheWarmRootMouseChildren:Boolean = true;

		/** Needs warm if discover and/or unique-sprite disk cache is missing/stale. */
		public static function invalidateWarmFreshnessMemo(statsName:String=null):void
		{
			var scanName:String;
			var cacheKey:String;
			if (!statsName)
			{
				warmFreshnessMemo = {};
				return;
			};
			delete warmFreshnessMemo[statsName];
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			if (scanName && scanName != statsName)
			{
				delete warmFreshnessMemo[scanName];
			};
			cacheKey = PaletteMakerUtils.getDiscoverCacheKey(statsName);
			if (cacheKey && cacheKey != statsName)
			{
				delete warmFreshnessMemo[cacheKey];
			};
		}

		private static function computeNeedsPaletteMakerWarm(statsName:String):Boolean
		{
			var discoverFresh:Boolean;
			var uniqueFresh:Boolean;
			var cacheKey:String;
			var scanName:String;
			var mtime:Number;
			if (!statsName || statsName == "random")
			{
				return false;
			};
			discoverFresh = SpriteCacheStore.isDiscoverCacheFresh(statsName);
			uniqueFresh = SpriteCacheStore.isUniqueSpriteCacheFresh(statsName);
			if (SpriteCacheStore.CACHE_DEBUG && (!discoverFresh || !uniqueFresh))
			{
				cacheKey = PaletteMakerUtils.getDiscoverCacheKey(statsName);
				scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
				mtime = PaletteMakerUtils.getCharacterResourceMTime(scanName);
				SpriteCacheStore.cacheDebugLog("needsWarm?" + statsName
					+ " discoverFresh=" + discoverFresh + " uniqueFresh=" + uniqueFresh
					+ " discoverKey=" + cacheKey + " scanName=" + scanName
					+ " swfMtime=" + mtime
					+ " ssfSize=" + PaletteMakerUtils.getCharacterResourceSize(scanName)
					+ " builtinDiscover=" + SpriteCacheStore.isBuiltinDiscoverFresh(statsName)
					+ " builtinUnique=" + SpriteCacheStore.isBuiltinUniqueFresh(statsName)
					+ " declinedBatch=" + PaletteMakerUtils.userDeclinedBatchCache
					+ " discoverFile=" + (SpriteCacheStore.discoverCacheFile(cacheKey) && SpriteCacheStore.discoverCacheFile(cacheKey).exists)
					+ " uniqueFile=" + (SpriteCacheStore.uniqueCacheFile(scanName) && SpriteCacheStore.uniqueCacheFile(scanName).exists));
			};
			return !discoverFresh || !uniqueFresh;
		}

		public static function needsPaletteMakerWarm(statsName:String):Boolean
		{
			var needs:Boolean;
			if (!statsName || statsName == "random")
			{
				return false;
			};
			if (warmFreshnessMemo.hasOwnProperty(statsName))
			{
				return Boolean(warmFreshnessMemo[statsName]);
			};
			needs = computeNeedsPaletteMakerWarm(statsName);
			warmFreshnessMemo[statsName] = needs;
			return needs;
		}

		/** Mark a character as freshly cached (skip repeat disk checks this session). */
		public static function markPaletteMakerWarmFresh(statsName:String):void
		{
			if (statsName)
			{
				warmFreshnessMemo[statsName] = false;
			};
		}

		/** After warming one scanStatsName, mark every roster ID that shares it. */
		public static function markPaletteMakerWarmFreshForScan(scanName:String):void
		{
			var roster:Array;
			var i:int;
			if (!scanName)
			{
				return;
			};
			markPaletteMakerWarmFresh(scanName);
			roster = discoverPreloadRosterByScan ? discoverPreloadRosterByScan[scanName] as Array : null;
			if (!roster)
			{
				return;
			};
			i = 0;
			while (i < roster.length)
			{
				markPaletteMakerWarmFresh(String(roster[i]));
				i++;
			};
		}

		/** Collapse roster names to unique scanStatsName load targets. */
		private static function buildDedupedWarmQueue(rosterNames:Array):Array
		{
			var queue:Array = [];
			var seenScan:Object = {};
			var roster:Array;
			var name:String;
			var scanName:String;
			var i:int;
			discoverPreloadRosterByScan = {};
			if (!rosterNames)
			{
				return queue;
			};
			i = 0;
			while (i < rosterNames.length)
			{
				name = String(rosterNames[i]);
				if (name)
				{
					scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(name);
					roster = discoverPreloadRosterByScan[scanName] as Array;
					if (!roster)
					{
						roster = [];
						discoverPreloadRosterByScan[scanName] = roster;
					};
					if (roster.indexOf(name) < 0)
					{
						roster.push(name);
					};
					if (!seenScan[scanName] && needsPaletteMakerWarm(name))
					{
						seenScan[scanName] = true;
						queue.push(scanName);
					};
				};
				i++;
			};
			return queue;
		}

		/** List CSS + loaded expansion character IDs for costume import / cache warm. */
		public static function listPaletteMakerCharacters():Array
		{
			var mappings:Object;
			var charactersObj:Object;
			var allCharacters:Array;
			var expChars:*;
			var expObj:Object;
			var expName:String;
			var ei:int;
			try
			{
				mappings = Ssf2.ResourceManager.getResourceByID("mappings").getProp("metadata");
				charactersObj = mappings.character_select_screen.rows;
				allCharacters = Ssf2.Utils.flatten(charactersObj as Array);
			}
			catch (err:Error)
			{
				allCharacters = [];
			};
			if (!allCharacters)
			{
				allCharacters = [];
			};
			// Primary form only per pack — unique-sprite warm still scans the whole SWF.
			ei = 0;
			while (ei < Ssf2.ResourceManager.TotalExpansions)
			{
				expChars = Ssf2.ResourceManager.getExpansionCharacter(ei);
				if (((expChars) && (expChars.length > 0)))
				{
					expObj = expChars[0];
					expName = ((expObj && expObj.cData) ? expObj.cData.statsName : null);
					if (((expName) && (allCharacters.indexOf(expName) < 0)))
					{
						allCharacters.push(expName);
					};
				};
				ei++;
			};
			return allCharacters;
		}

		/**
		 * The costume gallery asks for this list before it opens.
		 * Setup owns the warm, so the gallery is not asked to cache the roster.
		 */
		public static function startPaletteMakerFreshnessCheck(onComplete:Function):void
		{
			cancelPaletteMakerFreshnessCheck();
			if (onComplete != null)
			{
				onComplete([]);
			};
		}

		public static function cancelPaletteMakerFreshnessCheck():void
		{
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, pumpPaletteMakerFreshnessCheck);
			};
			freshnessCheckQueue = null;
			freshnessCheckPending = null;
			freshnessCheckCallback = null;
		}

		private static function pumpPaletteMakerFreshnessCheck(e:Event):void
		{
			try
			{
				pumpFreshnessCheckStep(e);
			}
			catch (err:*)
			{
				PaletteGuard.fail("cache freshness pump", err);
			};
		}

		private static function pumpFreshnessCheckStep(e:Event):void
		{
			var i:int;
			var n:int;
			var name:String;
			if (!freshnessCheckQueue)
			{
				finishPaletteMakerFreshnessCheck();
				return;
			};
			n = Math.min(FRESHNESS_SLICE, freshnessCheckQueue.length);
			i = 0;
			while (i < n)
			{
				name = String(freshnessCheckQueue.shift());
				if (name && needsPaletteMakerWarm(name))
				{
					freshnessCheckPending.push(name);
				};
				i++;
			};
			if (freshnessCheckQueue.length == 0)
			{
				finishPaletteMakerFreshnessCheck();
			};
		}

		private static function finishPaletteMakerFreshnessCheck():void
		{
			var cb:Function;
			var pending:Array;
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, pumpPaletteMakerFreshnessCheck);
			};
			pending = freshnessCheckPending ? freshnessCheckPending.concat() : [];
			cb = freshnessCheckCallback;
			freshnessCheckQueue = null;
			freshnessCheckPending = null;
			freshnessCheckCallback = null;
			if (cb != null)
			{
				cb(pending);
			};
		}

		private static var cacheWarmExitWhenDone:Boolean = false;

		/**
		 * Warm discover + unique-sprite caches.
		 * Skips chars whose character-file hash already matches.
		 * options: { pendingChars:Array, exitWhenDone:Boolean, onProgress, onComplete() }
		 */
		public static function startPaletteMakerPreload(options:Object=null):void
		{
			var chars:Array;
			var pending:Array;
			var name:String;
			var i:int;
			var doneCb:Function;
			discoverPreloadOnProgress = (options && options.onProgress is Function) ? options.onProgress as Function : null;
			discoverPreloadOnComplete = (options && options.onComplete is Function) ? options.onComplete as Function : null;
			cacheWarmExitWhenDone = options && options.exitWhenDone;
			if (discoverPreloadRunning)
			{
				return;
			};
			discoverPreloadWorkQueue = [];
			discoverPreloadPrefetchName = null;
			discoverPreloadPrefetchBusy = false;
			discoverPreloadPrefetchReady = false;
			warmIncrementalPendingName = null;
			if (options && options.pendingChars is Array)
			{
				pending = options.pendingChars as Array;
				discoverPreloadQueue = buildDedupedWarmQueue(pending);
			}
			else
			{
				chars = listPaletteMakerCharacters();
				discoverPreloadQueue = buildDedupedWarmQueue(chars);
			};
			discoverPreloadTotal = discoverPreloadQueue.length;
			discoverPreloadDone = 0;
			if (discoverPreloadTotal == 0)
			{
				trace("[PaletteMakerUtils] Palette Maker cache warm — all fresh");
				if (discoverPreloadOnProgress != null)
				{
					discoverPreloadOnProgress(1, 1, "");
				};
				if (!paletteMakerWarmSessionDone)
				{
					finishDiscoverPreload();
				}
				else
				{
					doneCb = discoverPreloadOnComplete;
					discoverPreloadOnProgress = null;
					discoverPreloadOnComplete = null;
					if (doneCb != null)
					{
						doneCb();
					};
				};
				return;
			};
			discoverPreloadRunning = true;
			discoverPreloadBusy = false;
			SpriteCacheStore.cacheDebugLog("Batch warm START total=" + discoverPreloadTotal
				+ " declinedBatch=" + PaletteMakerUtils.userDeclinedBatchCache
				+ " queue=" + discoverPreloadQueue.join(","));
			trace("[PaletteMakerUtils] Palette Maker cache warm —", discoverPreloadTotal, "characters");
			beginCacheWarmBlockingUI();
			if (discoverPreloadOnProgress != null)
			{
				discoverPreloadOnProgress(0, discoverPreloadTotal, "");
			};
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, pumpDiscoverPreload, false, 0, true);
			}
			else
			{
				finishDiscoverPreload();
			};
		}

		private static function finishDiscoverPreload():void
		{
			var cb:Function;
			var elapsedMs:int;
			discoverPreloadRunning = false;
			discoverPreloadBusy = false;
			discoverPreloadWorkQueue = [];
			discoverPreloadPrefetchName = null;
			discoverPreloadPrefetchBusy = false;
			discoverPreloadPrefetchReady = false;
			warmIncrementalPendingName = null;
			discoverPreloadRosterByScan = {};
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, pumpDiscoverPreload);
			};
			trace("[PaletteMakerUtils] Palette Maker cache warm complete");
			SpriteCacheStore.traceCacheWarmSummary("kirby");
			SpriteCacheStore.traceCacheWarmSummary("mario");
			SpriteCacheStore.traceCacheWarmSummary("bowser");
			paletteMakerWarmSessionDone = true;
			elapsedMs = (cacheWarmStartMs > 0) ? (getTimer() - cacheWarmStartMs) : 0;
			cb = discoverPreloadOnComplete;
			discoverPreloadOnProgress = null;
			discoverPreloadOnComplete = null;
			if (cacheWarmExitWhenDone)
			{
				cacheWarmExitWhenDone = false;
				endCacheWarmOverlay();
				writeCacheWarmSignal();
				if (cb != null)
				{
					cb();
				};
				try
				{
					NativeApplication.nativeApplication.exit(0);
				}
				catch (exitErr:Error)
				{
					trace("[PaletteMakerUtils] cache warm exit failed:", exitErr.message);
				};
				return;
			};
			if (cacheWarmOverlay)
			{
				completeCacheWarmBlockingUI(elapsedMs, cb);
			}
			else
			{
				Ssf2.MultiplayerManager.notify("Palette Maker caches ready");
				if (cb != null)
				{
					cb();
				};
			};
		}

		private static function endCacheWarmOverlay():void
		{
			holdCacheWarmAudio(false);
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(KeyboardEvent.KEY_DOWN, swallowCacheWarmKey, true);
				Ssf2.Main.Root.stage.removeEventListener(KeyboardEvent.KEY_UP, swallowCacheWarmKey, true);
			};
			if (cacheWarmOverlay)
			{
				cacheWarmOverlay.removeEventListener(MouseEvent.CLICK, onCacheWarmOverlayClick);
				cacheWarmOverlay.removeEventListener(MouseEvent.MOUSE_DOWN, swallowCacheWarmMouse);
				cacheWarmOverlay.removeEventListener(MouseEvent.MOUSE_UP, swallowCacheWarmMouse);
				cacheWarmOverlay.removeEventListener(MouseEvent.MOUSE_WHEEL, swallowCacheWarmMouse);
				cacheWarmOverlay.removeEventListener(MouseEvent.RIGHT_CLICK, swallowCacheWarmMouse);
				if (cacheWarmOverlay.parent)
				{
					cacheWarmOverlay.parent.removeChild(cacheWarmOverlay);
				};
			};
			cacheWarmOverlay = null;
			cacheWarmTitle = null;
			cacheWarmDetail = null;
			cacheWarmAwaitingDismiss = false;
		}

		/** Tells the manager the warm finished. The cache files stay in Documents. */
		private static function writeCacheWarmSignal():void
		{
			var file:File;
			var stream:FileStream;
			try
			{
				file = File.applicationDirectory.resolvePath("expansions/state/palette-cache-warm.signal");
				if (file.parent && !file.parent.exists)
				{
					file.parent.createDirectory();
				};
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				stream.writeUTFBytes("ok");
				stream.close();
				trace("[PaletteMakerUtils] cache warm signal");
			}
			catch (err:Error)
			{
				trace("[PaletteMakerUtils] cache warm signal failed:", err.message);
			};
		}

		private static function reportDiscoverPreloadProgress(batchLabel:String, notify:Boolean):void
		{
			if (discoverPreloadOnProgress != null)
			{
				discoverPreloadOnProgress(discoverPreloadDone, discoverPreloadTotal, batchLabel);
			};
			// Suppress toast spam while the full-screen warm overlay is up.
			if (notify && !cacheWarmOverlay)
			{
				Ssf2.MultiplayerManager.notify("Palette Maker: " + discoverPreloadDone + "/" + discoverPreloadTotal
					+ (batchLabel ? (" (" + batchLabel + ")") : ""));
			}
			else if (cacheWarmOverlay && cacheWarmDetail && !cacheWarmAwaitingDismiss)
			{
				cacheWarmDetail.text = "Caching characters… " + discoverPreloadDone + " / " + discoverPreloadTotal;
			};
		}

		/** Full-screen block: mute audio, no clicks through. */
		private static function beginCacheWarmBlockingUI():void
		{
			var host:DisplayObjectContainer;
			var titleFmt:TextFormat;
			var detailFmt:TextFormat;
			if (cacheWarmOverlay)
			{
				return;
			};
			cacheWarmStartMs = getTimer();
			cacheWarmAwaitingDismiss = false;
			holdCacheWarmAudio(true);
			host = (Ssf2.Main.Root && Ssf2.Main.Root.stage) ? (Ssf2.Main.Root.stage as DisplayObjectContainer) : (Ssf2.Main.Root as DisplayObjectContainer);
			if (!host)
			{
				return;
			};
			cacheWarmRootMouseChildren = host.mouseChildren;
			cacheWarmOverlay = new Sprite();
			cacheWarmOverlay.name = "paletteMakerCacheWarmOverlay";
			cacheWarmOverlay.mouseEnabled = true;
			cacheWarmOverlay.mouseChildren = false;
			cacheWarmOverlay.buttonMode = false;
			cacheWarmOverlay.useHandCursor = false;
			cacheWarmOverlay.graphics.beginFill(0x050508, 1);
			cacheWarmOverlay.graphics.drawRect(0, 0, Ssf2.Main.Width, Ssf2.Main.Height);
			cacheWarmOverlay.graphics.endFill();
			titleFmt = new TextFormat("_sans", 28, 0xFFFFFF, true);
			titleFmt.align = TextFormatAlign.CENTER;
			detailFmt = new TextFormat("_sans", 16, 0xCCCCDD, false);
			detailFmt.align = TextFormatAlign.CENTER;
			cacheWarmTitle = new TextField();
			cacheWarmTitle.defaultTextFormat = titleFmt;
			cacheWarmTitle.width = Ssf2.Main.Width - 40;
			cacheWarmTitle.x = 20;
			cacheWarmTitle.y = Ssf2.Main.Height * 0.38;
			cacheWarmTitle.multiline = true;
			cacheWarmTitle.wordWrap = true;
			cacheWarmTitle.selectable = false;
			cacheWarmTitle.mouseEnabled = false;
			cacheWarmTitle.text = "CACHING IN PROGRESS...\nTHIS WILL TAKE A FEW MINUTES";
			cacheWarmDetail = new TextField();
			cacheWarmDetail.defaultTextFormat = detailFmt;
			cacheWarmDetail.width = Ssf2.Main.Width - 40;
			cacheWarmDetail.x = 20;
			cacheWarmDetail.y = cacheWarmTitle.y + 90;
			cacheWarmDetail.multiline = true;
			cacheWarmDetail.wordWrap = true;
			cacheWarmDetail.selectable = false;
			cacheWarmDetail.mouseEnabled = false;
			cacheWarmDetail.text = "Caching characters… 0 / " + discoverPreloadTotal;
			cacheWarmOverlay.addChild(cacheWarmTitle);
			cacheWarmOverlay.addChild(cacheWarmDetail);
			host.addChild(cacheWarmOverlay);
			// Full-screen top layer swallows all mouse input while warming.
			cacheWarmOverlay.addEventListener(MouseEvent.CLICK, onCacheWarmOverlayClick, false, 0, true);
			cacheWarmOverlay.addEventListener(MouseEvent.MOUSE_DOWN, swallowCacheWarmMouse, false, 0, true);
			cacheWarmOverlay.addEventListener(MouseEvent.MOUSE_UP, swallowCacheWarmMouse, false, 0, true);
			cacheWarmOverlay.addEventListener(MouseEvent.MOUSE_WHEEL, swallowCacheWarmMouse, false, 0, true);
			cacheWarmOverlay.addEventListener(MouseEvent.RIGHT_CLICK, swallowCacheWarmMouse, false, 0, true);
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.addEventListener(KeyboardEvent.KEY_DOWN, swallowCacheWarmKey, true, 99, false);
				Ssf2.Main.Root.stage.addEventListener(KeyboardEvent.KEY_UP, swallowCacheWarmKey, true, 99, false);
			};
		}

		private static function completeCacheWarmBlockingUI(elapsedMs:int, completeCb:Function):void
		{
			var secs:Number;
			var mins:int;
			var rem:int;
			var timeStr:String;
			secs = elapsedMs / 1000;
			mins = int(secs / 60);
			rem = int(secs % 60);
			if (mins > 0)
			{
				timeStr = mins + "m " + rem + "s";
			}
			else
			{
				timeStr = secs.toFixed(1) + "s";
			};
			cacheWarmAwaitingDismiss = true;
			if (cacheWarmTitle)
			{
				cacheWarmTitle.text = "CACHING COMPLETE";
			};
			if (cacheWarmDetail)
			{
				cacheWarmDetail.text = "Finished in " + timeStr + "\n\nClick anywhere to continue";
			};
			// Fire completion callback after dismiss so Manage Costumes stays blocked until then.
			discoverPreloadOnComplete = completeCb;
		}

		private static function onCacheWarmOverlayClick(e:MouseEvent):void
		{
			if (!cacheWarmAwaitingDismiss)
			{
				e.stopImmediatePropagation();
				return;
			};
			e.stopImmediatePropagation();
			dismissCacheWarmBlockingUI();
		}

		private static function swallowCacheWarmMouse(e:MouseEvent):void
		{
			if (!cacheWarmAwaitingDismiss)
			{
				e.stopImmediatePropagation();
			};
		}

		internal static function swallowCacheWarmKey(e:KeyboardEvent):void
		{
			if (!cacheWarmAwaitingDismiss)
			{
				e.stopImmediatePropagation();
				e.preventDefault();
				return;
			};
			// Enter / Space dismiss the completion screen.
			if (e.type == KeyboardEvent.KEY_DOWN && (e.keyCode == 13 || e.keyCode == 32))
			{
				e.stopImmediatePropagation();
				e.preventDefault();
				dismissCacheWarmBlockingUI();
			};
		}

		internal static function dismissCacheWarmBlockingUI():void
		{
			var host:DisplayObjectContainer;
			var cb:Function;
			holdCacheWarmAudio(false);
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(KeyboardEvent.KEY_DOWN, swallowCacheWarmKey, true);
				Ssf2.Main.Root.stage.removeEventListener(KeyboardEvent.KEY_UP, swallowCacheWarmKey, true);
			};
			if (cacheWarmOverlay)
			{
				cacheWarmOverlay.removeEventListener(MouseEvent.CLICK, onCacheWarmOverlayClick);
				cacheWarmOverlay.removeEventListener(MouseEvent.MOUSE_DOWN, swallowCacheWarmMouse);
				cacheWarmOverlay.removeEventListener(MouseEvent.MOUSE_UP, swallowCacheWarmMouse);
				cacheWarmOverlay.removeEventListener(MouseEvent.MOUSE_WHEEL, swallowCacheWarmMouse);
				cacheWarmOverlay.removeEventListener(MouseEvent.RIGHT_CLICK, swallowCacheWarmMouse);
				if (cacheWarmOverlay.parent)
				{
					cacheWarmOverlay.parent.removeChild(cacheWarmOverlay);
				};
			};
			cacheWarmOverlay = null;
			cacheWarmTitle = null;
			cacheWarmDetail = null;
			cacheWarmAwaitingDismiss = false;
			cacheWarmStartMs = 0;
			host = (Ssf2.Main.Root && Ssf2.Main.Root.stage) ? (Ssf2.Main.Root.stage as DisplayObjectContainer) : (Ssf2.Main.Root as DisplayObjectContainer);
			if (host)
			{
				host.mouseChildren = cacheWarmRootMouseChildren;
			};
			cb = discoverPreloadOnComplete;
			discoverPreloadOnComplete = null;
			if (cb != null)
			{
				cb();
			};
		}

		private static function stopCacheWarmEmbeddedSounds():void
		{
			try
			{
				SoundMixer.stopAll();
			}
			catch (mixErr:Error)
			{
			};
		}

		private static function holdCacheWarmAudio(hold:Boolean):void
		{
			if (hold)
			{
				if (cacheWarmAudioHeld)
				{
					return;
				};
				cacheWarmAudioHeld = true;
				try
				{
					cacheWarmSavedMusicMuted = Ssf2.SoundQueue.instance.MusicIsMuted;
					Ssf2.SoundQueue.instance.stopAllSounds();
					Ssf2.SoundQueue.instance.MusicIsMuted = true;
					stopCacheWarmEmbeddedSounds();
				}
				catch (err:Error)
				{
				};
			}
			else
			{
				if (!cacheWarmAudioHeld)
				{
					return;
				};
				cacheWarmAudioHeld = false;
				try
				{
					Ssf2.SoundQueue.instance.MusicIsMuted = cacheWarmSavedMusicMuted;
				}
				catch (err2:Error)
				{
				};
			};
		}

		/** Pull next batch (up to BATCH_SIZE) from the queue. */
		private static function takeDiscoverPreloadBatch():Array
		{
			var batch:Array = [];
			var name:String;
			while (batch.length < DISCOVER_PRELOAD_BATCH_SIZE && discoverPreloadQueue && discoverPreloadQueue.length > 0)
			{
				name = String(discoverPreloadQueue.shift());
				if (!name)
				{
					continue;
				};
				if (!needsPaletteMakerWarm(name))
				{
					discoverPreloadDone++;
					markPaletteMakerWarmFreshForScan(name);
					continue;
				};
				batch.push(name);
			};
			return batch;
		}

		private static function enqueueWarmWork(name:String, phase:String):void
		{
			if (!discoverPreloadWorkQueue)
			{
				discoverPreloadWorkQueue = [];
			};
			discoverPreloadWorkQueue.push({ "name": name, "phase": phase });
		}

		private static function processWarmWorkItem(item:Object):void
		{
			var name:String;
			var phase:String;
			var needsAsync:Boolean;
			if (!item)
			{
				return;
			};
			name = String(item.name);
			phase = String(item.phase);
			if (!name)
			{
				return;
			};
			if (phase == "warm")
			{
				SpriteCacheStore.cacheDebugLog("Batch warm char=" + name + " phase=warm");
				if (PaletteMakerUtils.warmDiscoverHandler != null)
				{
					PaletteMakerUtils.warmDiscoverHandler(name);
				};
				needsAsync = false;
				if (PaletteMakerUtils.getCharacterResource(name, true) && PaletteMakerUtils.warmUniqueIncrementalStartHandler != null)
				{
					try
					{
						needsAsync = Boolean(PaletteMakerUtils.warmUniqueIncrementalStartHandler(name));
					}
					catch (uniqErr:Error)
					{
						trace("[PaletteMakerUtils] warm unique start failed:", name, uniqErr.message);
					};
				}
				else if (PaletteMakerUtils.getCharacterResource(name, true) && PaletteMakerUtils.warmUniqueHandler != null)
				{
					try
					{
						PaletteMakerUtils.warmUniqueHandler(name);
					}
					catch (uniqErr2:Error)
					{
						trace("[PaletteMakerUtils] warm unique failed:", name, uniqErr2.message);
					};
				};
				if (needsAsync)
				{
					warmIncrementalPendingName = name;
					reportDiscoverPreloadProgress(name + " unique…", true);
					tryStartPrefetchSwf();
					return;
				};
				markPaletteMakerWarmFreshForScan(name);
				discoverPreloadDone++;
				reportDiscoverPreloadProgress(name, true);
				tryStartPrefetchSwf();
				return;
			};
			if (phase == "discover")
			{
				if (PaletteMakerUtils.warmDiscoverHandler != null)
				{
					PaletteMakerUtils.warmDiscoverHandler(name);
				};
				enqueueWarmWork(name, "unique");
				reportDiscoverPreloadProgress(name + " discover", true);
				return;
			};
			if (phase == "unique")
			{
				if (PaletteMakerUtils.getCharacterResource(name, true) && PaletteMakerUtils.warmUniqueHandler != null)
				{
					PaletteMakerUtils.warmUniqueHandler(name);
				};
				markPaletteMakerWarmFreshForScan(name);
				discoverPreloadDone++;
				reportDiscoverPreloadProgress(name, true);
			};
		}

		private static function finishWarmWorkItem(name:String):void
		{
			warmIncrementalPendingName = null;
			markPaletteMakerWarmFreshForScan(name);
			discoverPreloadDone++;
			reportDiscoverPreloadProgress(name, true);
			stopCacheWarmEmbeddedSounds();
			tryStartPrefetchSwf();
		}

		private static function tryStartPrefetchSwf():void
		{
			var name:String;
			if (discoverPreloadPrefetchBusy || discoverPreloadPrefetchReady
				|| !discoverPreloadQueue || discoverPreloadQueue.length == 0)
			{
				return;
			};
			name = String(discoverPreloadQueue[0]);
			if (!name)
			{
				discoverPreloadQueue.shift();
				tryStartPrefetchSwf();
				return;
			};
			discoverPreloadPrefetchBusy = true;
			discoverPreloadPrefetchName = name;
			try
			{
				Ssf2.ResourceManager.queueResources(PaletteMakerUtils.toCharacterResourceIds([name]));
				Ssf2.ResourceManager.load({
					"oncomplete": function(ev:*=null):void
					{
						discoverPreloadQueue.shift();
						discoverPreloadPrefetchBusy = false;
						discoverPreloadPrefetchReady = true;
						stopCacheWarmEmbeddedSounds();
					},
					"onerror": function(ev:*=null):void
					{
						trace("[PaletteMakerUtils] Cache warm prefetch error:", name);
						discoverPreloadQueue.shift();
						discoverPreloadPrefetchBusy = false;
						discoverPreloadPrefetchName = null;
						stopCacheWarmEmbeddedSounds();
					}
				});
			}
			catch (prefetchErr:Error)
			{
				trace("[PaletteMakerUtils] Cache warm prefetch queue failed:", prefetchErr.message);
				discoverPreloadQueue.shift();
				discoverPreloadPrefetchBusy = false;
				discoverPreloadPrefetchName = null;
			};
		}

		private static function startPrimarySwfLoad(batch:Array):void
		{
			var batchCopy:Array;
			if (!batch || batch.length == 0)
			{
				return;
			};
			discoverPreloadBusy = true;
			batchCopy = batch.concat();
			try
			{
				Ssf2.ResourceManager.queueResources(PaletteMakerUtils.toCharacterResourceIds(batchCopy));
				Ssf2.ResourceManager.load({
					"oncomplete": function(ev:*=null):void
					{
						var i:int;
						var loadName:String;
						i = 0;
						while (i < batchCopy.length)
						{
							loadName = String(batchCopy[i]);
							enqueueWarmWork(loadName, "warm");
							i++;
						};
						stopCacheWarmEmbeddedSounds();
						discoverPreloadBusy = false;
						tryStartPrefetchSwf();
					},
					"onerror": function(ev:*=null):void
					{
						var j:int;
						var errName:String;
						trace("[PaletteMakerUtils] Cache warm batch load error");
						j = 0;
						while (j < batchCopy.length)
						{
							errName = String(batchCopy[j]);
							if (PaletteMakerUtils.getCharacterResource(errName, true))
							{
								enqueueWarmWork(errName, "warm");
							}
							else
							{
								discoverPreloadDone++;
							};
							j++;
						};
						stopCacheWarmEmbeddedSounds();
						discoverPreloadBusy = false;
						tryStartPrefetchSwf();
					}
				});
			}
			catch (err:Error)
			{
				trace("[PaletteMakerUtils] Discover warm batch queue failed:", err.message);
				discoverPreloadDone += batchCopy.length;
				reportDiscoverPreloadProgress("queue failed", true);
				discoverPreloadBusy = false;
			};
		}

		internal static function pumpDiscoverPreload(e:Event):void
		{
			try
			{
				pumpDiscoverPreloadStep(e);
			}
			catch (err:*)
			{
				PaletteGuard.fail("cache warm pump", err);
			};
		}

		private static function pumpDiscoverPreloadStep(e:Event):void
		{
			var batch:Array;
			var workItem:Object;
			var prefetchName:String;
			var stillRunning:Boolean;
			// Always advance incremental unique warm first — never stall it behind SWF loads.
			if (warmIncrementalPendingName)
			{
				stillRunning = false;
				if (PaletteMakerUtils.warmUniqueIncrementalStepHandler != null)
				{
					try
					{
						stillRunning = Boolean(PaletteMakerUtils.warmUniqueIncrementalStepHandler());
					}
					catch (stepErr:Error)
					{
						trace("[PaletteMakerUtils] Incremental warm step failed:", stepErr.message);
						PaletteGuard.fail("cache warm incremental " + warmIncrementalPendingName, stepErr);
						stillRunning = false;
					};
				};
				if (stillRunning)
				{
					return;
				};
				finishWarmWorkItem(warmIncrementalPendingName);
				if (discoverPreloadDone >= discoverPreloadTotal
					&& (!discoverPreloadQueue || discoverPreloadQueue.length == 0)
					&& (!discoverPreloadWorkQueue || discoverPreloadWorkQueue.length == 0)
					&& !discoverPreloadPrefetchReady)
				{
					finishDiscoverPreload();
				};
				return;
			};
			if (discoverPreloadBusy)
			{
				return;
			};
			if (discoverPreloadWorkQueue && discoverPreloadWorkQueue.length > 0)
			{
				workItem = discoverPreloadWorkQueue.shift();
				try
				{
					processWarmWorkItem(workItem);
				}
				catch (warmErr:Error)
				{
					trace("[PaletteMakerUtils] Cache warm work failed:", warmErr.message);
					PaletteGuard.fail("cache warm " + (workItem ? workItem.phase + " " + workItem.name : "work"), warmErr);
					if (workItem && String(workItem.phase) == "warm")
					{
						finishWarmWorkItem(String(workItem.name));
					}
					else if (workItem && String(workItem.phase) == "unique")
					{
						discoverPreloadDone++;
					}
					else if (workItem && String(workItem.phase) == "discover")
					{
						enqueueWarmWork(String(workItem.name), "unique");
					};
				};
				stopCacheWarmEmbeddedSounds();
				if (discoverPreloadDone >= discoverPreloadTotal
					&& (!discoverPreloadQueue || discoverPreloadQueue.length == 0)
					&& (!discoverPreloadWorkQueue || discoverPreloadWorkQueue.length == 0)
					&& !discoverPreloadPrefetchReady
					&& !warmIncrementalPendingName)
				{
					finishDiscoverPreload();
				};
				return;
			};
			if (discoverPreloadPrefetchReady && discoverPreloadPrefetchName)
			{
				prefetchName = discoverPreloadPrefetchName;
				discoverPreloadPrefetchReady = false;
				discoverPreloadPrefetchName = null;
				enqueueWarmWork(prefetchName, "warm");
				return;
			};
			if (!discoverPreloadQueue || discoverPreloadQueue.length == 0)
			{
				if (discoverPreloadDone >= discoverPreloadTotal)
				{
					finishDiscoverPreload();
				};
				return;
			};
			if (discoverPreloadPrefetchBusy || discoverPreloadPrefetchReady)
			{
				return;
			};
			batch = takeDiscoverPreloadBatch();
			if (batch.length == 0)
			{
				reportDiscoverPreloadProgress("", discoverPreloadDone >= discoverPreloadTotal);
				if (!discoverPreloadQueue || discoverPreloadQueue.length == 0)
				{
					if (!discoverPreloadWorkQueue || discoverPreloadWorkQueue.length == 0)
					{
						finishDiscoverPreload();
					};
				};
				return;
			};
			startPrimarySwfLoad(batch);
		}
	}
}
