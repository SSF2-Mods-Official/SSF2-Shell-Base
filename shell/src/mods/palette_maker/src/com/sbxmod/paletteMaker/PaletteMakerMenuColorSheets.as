package com.sbxmod.paletteMaker
{
    import ssf2mm.shared.HsvWheel;
    import flash.events.MouseEvent;
    import flash.events.Event;
	import flash.utils.getTimer;
    import flash.display.MovieClip;
    import flash.text.TextField;
    import flash.events.FocusEvent;
    import flash.geom.Rectangle;
    import flash.geom.Point;
    import flash.geom.ColorTransform;
    import flash.display.DisplayObject;
    import flash.display.Sprite;
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.LoaderInfo;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getQualifiedSuperclassName;
	import flash.utils.getDefinitionByName;
	import flash.net.SharedObject;
	import flash.system.ApplicationDomain;
	import flash.display.DisplayObjectContainer;
	import flash.events.UncaughtErrorEvent;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.utils.Dictionary;
	import flash.filesystem.File;
	import flash.net.FileFilter;
	import flash.events.KeyboardEvent;
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	import com.mcleodgaming.ssf2.util.PaletteDeep;

    /** Color sheet export/import and batch regenerate. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuColorSheets extends PaletteMakerMenuMagnifier
    {
        public function PaletteMakerMenuColorSheets()
        {
            super();
        }

		/** Stable palette order for color sheets (never UI-sorted). */
		protected var sheetPaletteOrder:Array = [];

		/** Ctrl+Shift+C batch color-sheet regenerate state. */
		private var colorSheetBatchQueue:Array = null;

		private var colorSheetBatchIndex:int = 0;

		private var colorSheetBatchBusy:Boolean = false;

		private var colorSheetBatchOk:int = 0;

		private var colorSheetBatchFail:int = 0;

		/**
		 * Build/save unique-sprite cover cache for a character without opening the editor.
		 * Requires character SWF already loaded (warm batch does that).
		 */
		public function warmUniqueSpriteCache(charName:String):void
		{
			runUniqueSpriteWarm(charName, false);
		}

		/** Batch warm entry — returns true when incremental ENTER_FRAME steps are required. */
		public function warmUniqueSpriteCacheIncrementalStart(charName:String):Boolean
		{
			return runUniqueSpriteWarm(charName, true);
		}

		private function runUniqueSpriteWarm(charName:String, allowIncremental:Boolean):Boolean
		{
			var mtime:Number;
			var prevStats:String;
			var prevPalette:Object;
			var prevMixed:Array;
			var prevBase:Object;
			var rmCostume:Object;
			var loaded:Object;
			var selected:Array;
			var scanName:String;
			var discovered:Object;
			var paletteColors:Array;
			if (!charName)
			{
				return false;
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(charName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scanName);
			if (SpriteCacheStore.loadUniqueSpriteCacheForUse(charName, mtime))
			{
				return false;
			};
			prevStats = statsName;
			prevPalette = currentPaletteData;
			prevMixed = mixedBasePaletteData;
			prevBase = baseCostumeData;
			suppressUniqueSpriteNotify = true;
			try
			{
				beginDiscoverErrorSuppress();
				statsName = scanName;
				discovered = warmDiscoverCache(scanName);
				rmCostume = null;
				try { rmCostume = Ssf2.ResourceManager.getCostume(charName, null); } catch (rmErr:Error) { };
				loaded = getPaletteMakerBaseCostumeData(scanName, rmCostume);
				if (!loaded)
				{
					loaded = { "paletteSwap": { "colors": [], "replacements": [] }, "paletteSwapPA": { "colors": [], "replacements": [] } };
				};
				if (!loaded.paletteSwap) loaded.paletteSwap = { "colors": [], "replacements": [] };
				if (!loaded.paletteSwapPA) loaded.paletteSwapPA = { "colors": [], "replacements": [] };
				baseCostumeData = Ssf2.Utils.cloneObject(loaded);
				mixedBasePaletteData = mixArrays(
					loaded.paletteSwap.colors as Array,
					loaded.paletteSwapPA.colors as Array);
				currentPaletteData = Ssf2.Utils.cloneObject(loaded);
				discoverAndMergeMissingSwatchColors(discovered);
				paletteColors = collectUniquePaletteColors();
				if (allowIncremental && beginIncrementalCandidateScan(paletteColors))
				{
					warmIncrementalRestore = {
						"prevStats": prevStats,
						"prevPalette": prevPalette,
						"prevMixed": prevMixed,
						"prevBase": prevBase,
						"scanName": scanName,
						"mtime": mtime,
						"paletteColors": paletteColors
					};
					return true;
				};
				selected = selectCoveringSprites(paletteColors);
				persistUniqueSpriteCache(selected, mtime);
			}
			catch (err:Error)
			{
				trace("[PaletteMaker] warmUniqueSpriteCache failed:", charName, err.message);
			}
			finally
			{
				endDiscoverErrorSuppress();
				if (!warmIncrementalRestore)
				{
					suppressUniqueSpriteNotify = false;
					statsName = prevStats;
					currentPaletteData = prevPalette;
					mixedBasePaletteData = prevMixed;
					baseCostumeData = prevBase;
				};
			};
			return false;
		}

		/**
		 * Scan SSF2-recolorable art for opaque colors missing from the authored
		 * palette; append them as identity swatches / palette pairs.
		 */
		protected function discoverAndMergeMissingSwatchColors(prefetchedDiscover:Object=null):void
		{
			var discovered:Object;
			var color:uint;
			var inAuthored:Boolean;
			var existing:*;
			var addedSwap:int = 0;
			var addedPA:int = 0;
			var scanName:String;
			var mtime:Number;
			var cacheKey:String;
			if (!statsName || !currentPaletteData)
			{
				return;
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scanName);
			cacheKey = PaletteMakerUtils.getDiscoverCacheKey(statsName);
			try
			{
				beginDiscoverErrorSuppress();
				discovered = prefetchedDiscover;
				if (!discovered)
				{
					discovered = SpriteCacheStore.takeDiscoverSessionCache(cacheKey);
				};
				if (!discovered)
				{
					discovered = SpriteCacheStore.loadDiscoverCacheForUse(statsName, mtime);
				};
				if (!discovered)
				{
					PaletteMakerUtils.cacheDebugLog("RESCAN discover stats=" + statsName
						+ " key=" + cacheKey + " declinedBatch=" + PaletteMakerUtils.userDeclinedBatchCache);
					discovered = collectOpaqueColorsFromRecolorTargets(statsName);
					SpriteCacheStore.saveDiscoverCache(cacheKey, mtime,
						discovered.swap as Array, discovered.swapPA as Array);
				};
			}
			catch (scanErr:*)
			{
				trace("[PaletteMaker] Discover scan failed: " + scanErr);
				return;
			}
			finally
			{
				endDiscoverErrorSuppress();
			};
			if (!discovered)
			{
				return;
			};
			if (!currentPaletteData.paletteSwap)
			{
				currentPaletteData.paletteSwap = { colors: [], replacements: [] };
			};
			if (!currentPaletteData.paletteSwapPA)
			{
				currentPaletteData.paletteSwapPA = { colors: [], replacements: [] };
			};
			if (!(currentPaletteData.paletteSwap.colors is Array))
			{
				currentPaletteData.paletteSwap.colors = [];
			};
			if (!(currentPaletteData.paletteSwap.replacements is Array))
			{
				currentPaletteData.paletteSwap.replacements = [];
			};
			if (!(currentPaletteData.paletteSwapPA.colors is Array))
			{
				currentPaletteData.paletteSwapPA.colors = [];
			};
			if (!(currentPaletteData.paletteSwapPA.replacements is Array))
			{
				currentPaletteData.paletteSwapPA.replacements = [];
			};
			for each (color in (discovered.swap as Array))
			{
				inAuthored = false;
				for each (existing in mixedBasePaletteData)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(existing), color))
					{
						inAuthored = true;
						break;
					};
				};
				if (inAuthored || paletteBlockHasColor(currentPaletteData.paletteSwap, color))
				{
					continue;
				};
				currentPaletteData.paletteSwap.colors.push(color);
				currentPaletteData.paletteSwap.replacements.push(color);
				mixedBasePaletteData.push(color);
				addedSwap++;
			};
			for each (color in (discovered.swapPA as Array))
			{
				inAuthored = false;
				for each (existing in mixedBasePaletteData)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(existing), color))
					{
						inAuthored = true;
						break;
					};
				};
				if (paletteBlockHasColor(currentPaletteData.paletteSwapPA, color))
				{
					// Already in PA block; still ensure swatch list has it.
					if (!inAuthored)
					{
						mixedBasePaletteData.push(color);
					};
					continue;
				};
				if (inAuthored)
				{
					// In swatch list via swap already — still add PA identity pair if found on PA.
					currentPaletteData.paletteSwapPA.colors.push(color);
					currentPaletteData.paletteSwapPA.replacements.push(color);
					addedPA++;
					continue;
				};
				currentPaletteData.paletteSwapPA.colors.push(color);
				currentPaletteData.paletteSwapPA.replacements.push(color);
				mixedBasePaletteData.push(color);
				addedPA++;
			};
			if (addedSwap > 0 || addedPA > 0)
			{
				baseCostumeData = Ssf2.Utils.cloneObject(currentPaletteData);
			};
			refreshSheetPaletteOrder();
		}

		/** Snapshot stable base-color order for color sheets (costume array order, not UI sort). */
		protected function refreshSheetPaletteOrder():void
		{
			var swap:Object;
			var swapPA:Object;
			if (!currentPaletteData)
			{
				sheetPaletteOrder = [];
				return;
			};
			swap = currentPaletteData.paletteSwap;
			swapPA = currentPaletteData.paletteSwapPA;
			sheetPaletteOrder = mixArrays(
				(swap && swap.colors is Array) ? swap.colors : [],
				(swapPA && swapPA.colors is Array) ? swapPA.colors : []);
		}

		protected function getSheetReplacementForBase(baseColor:uint):uint
		{
			var block:Object;
			var i:int;
			var colors:Array;
			var repls:Array;
			for each (block in [currentPaletteData ? currentPaletteData.paletteSwap : null,
				currentPaletteData ? currentPaletteData.paletteSwapPA : null])
			{
				if (!block || !(block.colors is Array) || !(block.replacements is Array))
				{
					continue;
				};
				colors = block.colors as Array;
				repls = block.replacements as Array;
				i = 0;
				while (i < colors.length && i < repls.length)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(colors[i]), baseColor))
					{
						return uint(repls[i]);
					};
					i++;
				};
			};
			return baseColor;
		}

		/**
		 * Shared EC / Ctrl+Shift+C sheet builder. When paintArt is true, paints portraits
		 * and uniques with the live editor paths before composing.
		 */
		protected function buildColorSheetBitmap(portraitParts:Array, uniqueSprites:Array, coverCache:Array,
			paletteData:Object, appliedStrip:Array, paintArt:Boolean, formStatsName:String):BitmapData
		{
			var parts:Array;
			var root:DisplayObject;
			var art:BitmapData;
			var sheet:BitmapData;
			var swap:Object;
			var swapPA:Object;
			if (!appliedStrip || appliedStrip.length == 0)
			{
				return null;
			};
			if (paintArt && paletteData)
			{
				swap = paletteData.paletteSwap;
				swapPA = paletteData.paletteSwapPA;
				paintPortraitPartsForSheet(portraitParts, swap, swapPA, formStatsName);
				paintUniqueSpritesForSheet(uniqueSprites, coverCache, formStatsName,
					paletteData, null, null, false);
			};
			parts = [];
			if (portraitParts)
			{
				for each (root in portraitParts)
				{
					if (root)
					{
						parts.push(root);
					};
				};
			};
			if (uniqueSprites)
			{
				for each (root in uniqueSprites)
				{
					if (root)
					{
						parts.push(root);
					};
				};
			};
			art = ColorSheetIO.composePortraitUniqueLayout(parts, 4);
			sheet = ColorSheetIO.buildSheet(art, appliedStrip);
			if (art)
			{
				art.dispose();
			};
			return sheet;
		}

		/** Clone stock base costume and apply sheet strip colors by sheetPaletteOrder index. */
		protected function buildCostumeFromPaletteStrip(colors:Array, profile:String):Object
		{
			var costume:Object;
			var bases:Array;
			var i:int;
			var n:int;
			var base:uint;
			var repl:uint;
			if (!colors || colors.length == 0 || !baseCostumeData)
			{
				return null;
			};
			costume = PaletteMakerUtils.repairCostumeData(Ssf2.Utils.cloneObject(baseCostumeData));
			ensurePaletteBlocks(costume);
			costume.paletteSwap = normalizePaletteBlock(costume.paletteSwap);
			costume.paletteSwapPA = normalizePaletteBlock(costume.paletteSwapPA);
			// Identity replacements so strip maps onto stock bases.
			if (costume.paletteSwap && costume.paletteSwap.colors is Array)
			{
				costume.paletteSwap.replacements = Ssf2.Utils.cloneObject(costume.paletteSwap.colors);
			};
			if (costume.paletteSwapPA && costume.paletteSwapPA.colors is Array)
			{
				costume.paletteSwapPA.replacements = Ssf2.Utils.cloneObject(costume.paletteSwapPA.colors);
			};
			bases = mixArrays(
				(costume.paletteSwap && costume.paletteSwap.colors is Array) ? costume.paletteSwap.colors : [],
				(costume.paletteSwapPA && costume.paletteSwapPA.colors is Array) ? costume.paletteSwapPA.colors : []);
			if (!bases || bases.length == 0)
			{
				return null;
			};
			n = Math.min(colors.length, bases.length);
			i = 0;
			while (i < n)
			{
				base = uint(bases[i]);
				repl = uint(colors[i]);
				replaceBracket(base, repl, costume.paletteSwapPA.colors, costume.paletteSwapPA.replacements);
				replaceBracket(base, repl, costume.paletteSwap.colors, costume.paletteSwap.replacements);
				i++;
			};
			delete costume["team"];
			delete costume["base"];
			delete costume["colorVaultId"];
			costume["profile"] = profile;
			costume["info"] = profile;
			delete costume["author"];
			delete costume["both"];
			return PaletteMakerUtils.repairCostumeData(costume);
		}

		protected function disposeSheetImportItems(items:Array):void
		{
			var item:Object;
			if (!items)
			{
				return;
			};
			for each (item in items)
			{
				if (item && item.bitmapData is BitmapData)
				{
					try
					{
						(item.bitmapData as BitmapData).dispose();
					}
					catch (ignore:Error)
					{
					};
				};
			};
		}

		/**
		 * Skip CSS entries with no Misc costumes, or only hue/tint alts (no real paletteSwap).
		 * Uses raw stock costume_data — not getCostumeCount() (always adds a synthetic -1 slot).
		 */
		private function shouldSkipColorSheetCharacter(charName:String):Boolean
		{
			var list:Array;
			var c:Object;
			var hasPalette:Boolean;
			if (!charName || charName == "random")
			{
				return true;
			};
			try
			{
				list = Ssf2.ResourceManager.getResourceByID("misc").getProp("metadata").costume_data[charName] as Array;
			}
			catch (err:Error)
			{
				return true;
			};
			if (!list || list.length == 0)
			{
				return true;
			};
			hasPalette = false;
			for each (c in list)
			{
				if (!c || c.team)
				{
					continue;
				};
				if (c.paletteSwap && (c.paletteSwap.colors is Array) && c.paletteSwap.colors.length > 0)
				{
					hasPalette = true;
					break;
				};
				if (c.paletteSwapPA && (c.paletteSwapPA.colors is Array) && c.paletteSwapPA.colors.length > 0)
				{
					hasPalette = true;
					break;
				};
			};
			return !hasPalette;
		}

		/**
		 * Vault hotkey (Ctrl+Shift+C): regenerate Documents/.../color sheets for every
		 * costume-compatible character. Uses the same live paint/compose path as EC
		 * (unique cover metadata + updateUniquePaPalettes branches + PA bitmaps).
		 */
		public function batchRegenerateAllColorSheets():void
		{
			var chars:Array;
			var filtered:Array;
			var name:String;
			if (colorSheetBatchBusy)
			{
				Ssf2.MultiplayerManager.notify("Color sheet batch already running…");
				return;
			};
			chars = CacheWarmPreload.listPaletteMakerCharacters();
			if (!chars || chars.length == 0)
			{
				Ssf2.MultiplayerManager.notify("No characters for color sheet batch");
				return;
			};
			filtered = [];
			for each (name in chars)
			{
				if (!shouldSkipColorSheetCharacter(String(name)))
				{
					filtered.push(name);
				};
			};
			if (filtered.length == 0)
			{
				Ssf2.MultiplayerManager.notify("No palette-recolor characters for color sheet batch");
				return;
			};
			CostumePackIO.ensureColorSheetsExtracted();
			try
			{
				CostumePackIO.getColorSheetsNoRecolorFolder().createDirectory();
				CostumePackIO.getColorSheetsBaseRecolorFolder().createDirectory();
			}
			catch (mkErr:Error)
			{
			};
			colorSheetBatchQueue = filtered;
			colorSheetBatchIndex = 0;
			colorSheetBatchOk = 0;
			colorSheetBatchFail = 0;
			colorSheetBatchBusy = true;
			Ssf2.MultiplayerManager.notify("Regenerating color sheets (0/" + colorSheetBatchQueue.length + ")…");
			Ssf2.ResourceManager.queueResources(["misc2"]);
			Ssf2.ResourceManager.load({ "oncomplete": colorSheetBatchPump });
		}

		private function colorSheetBatchPump(e:*=null):void
		{
			var name:String;
			var toLoad:Array;
			var partner:String;
			var scan:String;
			if (!colorSheetBatchBusy || !colorSheetBatchQueue)
			{
				return;
			};
			if (colorSheetBatchIndex >= colorSheetBatchQueue.length)
			{
				colorSheetBatchBusy = false;
				Ssf2.MultiplayerManager.notify("Color sheets done — ok " + colorSheetBatchOk
					+ ", fail " + colorSheetBatchFail);
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				return;
			};
			name = String(colorSheetBatchQueue[colorSheetBatchIndex]);
			toLoad = [name];
			partner = PaletteMakerUtils.getLinkedFormPartner(name);
			if (partner)
			{
				toLoad.push(partner);
			};
			scan = PaletteMakerUtils.getUniqueSpriteScanStatsName(name);
			if (scan && toLoad.indexOf(scan) < 0)
			{
				toLoad.push(scan);
			};
			Ssf2.MultiplayerManager.notify("Color sheets " + (colorSheetBatchIndex + 1)
				+ "/" + colorSheetBatchQueue.length + ": " + name);
			Ssf2.ResourceManager.queueResources(toLoad);
			Ssf2.ResourceManager.load({ "oncomplete": colorSheetBatchOnCharLoaded });
		}

		private function colorSheetBatchOnCharLoaded(e:*=null):void
		{
			try
			{
				colorSheetBatchOnCharLoadedStep(e);
			}
			catch (err:*)
			{
				PaletteGuard.fail("color sheet batch load", err);
			};
		}

		private function colorSheetBatchOnCharLoadedStep(e:*=null):void
		{
			var name:String;
			if (!colorSheetBatchBusy || !colorSheetBatchQueue
				|| colorSheetBatchIndex >= colorSheetBatchQueue.length)
			{
				colorSheetBatchBusy = false;
				return;
			};
			name = String(colorSheetBatchQueue[colorSheetBatchIndex]);
			try
			{
				if (writeStockColorSheetsForCharacter(name))
				{
					colorSheetBatchOk++;
				}
				else
				{
					colorSheetBatchFail++;
				};
			}
			catch (err:Error)
			{
				colorSheetBatchFail++;
				trace("[PaletteMaker] color sheet batch fail", name, err.message);
				PaletteGuard.fail("color sheet batch " + name, err);
			};
			colorSheetBatchIndex++;
			// Yield a frame so UI/notifies keep up.
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, colorSheetBatchNextFrame, false, 0, true);
			}
			else
			{
				colorSheetBatchPump();
			};
		}

		private function colorSheetBatchNextFrame(e:Event):void
		{
			try
			{
				colorSheetBatchNextFrameStep(e);
			}
			catch (err:*)
			{
				PaletteGuard.fail("color sheet batch pump", err);
			};
		}

		private function colorSheetBatchNextFrameStep(e:Event):void
		{
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, colorSheetBatchNextFrame);
			};
			colorSheetBatchPump();
		}

		/** Build + save no-recolor and base-recolor sheets for one character. */
		private function writeStockColorSheetsForCharacter(charName:String):Boolean
		{
			var portraits:Array;
			var uniqueBundle:Object;
			var uniqueSprites:Array;
			var coverCache:Array;
			var sheet:BitmapData;
			var bases:Array;
			var applied:Array;
			var baseCostume:Object;
			var paletteData:Object;
			var ok:Boolean;
			var file:File;
			if (!charName)
			{
				return false;
			};
			portraits = buildColorSheetPortraitParts(charName);
			uniqueBundle = buildColorSheetUniqueBundle(charName);
			uniqueSprites = uniqueBundle && (uniqueBundle.sprites is Array)
				? (uniqueBundle.sprites as Array) : [];
			coverCache = uniqueBundle && (uniqueBundle.cover is Array)
				? (uniqueBundle.cover as Array) : [];
			if ((!portraits || portraits.length == 0) && uniqueSprites.length == 0)
			{
				return false;
			};
			// Same base order as live EC: stock costume colors + discover-merged keys.
			baseCostume = getPaletteMakerBaseCostumeData(charName, null);
			paletteData = buildSheetPaletteDataForCharacter(charName, baseCostume);
			bases = collectSheetBasesForCharacter(charName, paletteData);
			if (!bases || bases.length == 0)
			{
				return false;
			};
			applied = buildSheetAppliedStrip(bases, paletteData);
			ok = false;
			// no recolor: identity strip + unpainted art (same compose as EC)
			sheet = buildColorSheetBitmap(portraits, uniqueSprites, coverCache,
				null, ColorSheetIO.dedupeRgb(bases), false, charName);
			if (sheet)
			{
				file = CostumePackIO.getColorSheetsNoRecolorFolder().resolvePath(charName + ".png");
				ok = ColorSheetIO.writePngFile(sheet, file);
				sheet.dispose();
			};
			// base recolor: stock costume paint + EC-style applied strip
			sheet = buildColorSheetBitmap(portraits, uniqueSprites, coverCache,
				paletteData, applied, paletteData != null, charName);
			if (sheet)
			{
				file = CostumePackIO.getColorSheetsBaseRecolorFolder().resolvePath(charName + ".png");
				if (ColorSheetIO.writePngFile(sheet, file))
				{
					ok = true;
				};
				sheet.dispose();
			};
			return ok;
		}

		/** Portraits matching restAreaMod / live EC (expansion ALIGN_BOTTOM + classic trophy). */
		private function buildColorSheetPortraitParts(charName:String):Array
		{
			var parts:Array = [];
			var trophy:MovieClip;
			var partner:String;
			var partnerTrophy:MovieClip;
			trophy = Ssf2.ResourceManager.getExpansionPortraitMC(charName, Ssf2.ResourceManager.ALIGN_BOTTOM)
				|| Ssf2.ResourceManager.getLibraryMC(charName + "_classic_trophy")
				|| Ssf2.ResourceManager.getLibraryMC("placeholder_classic_trophy");
			if (trophy)
			{
				preparePortraitClip(trophy);
				parts.push(trophy);
			};
			if (PaletteMakerUtils.isLinkedFormPair(charName))
			{
				partner = PaletteMakerUtils.getLinkedFormPartner(charName);
				if (partner)
				{
					partnerTrophy = Ssf2.ResourceManager.getLibraryMC(partner + "_classic_trophy")
						|| Ssf2.ResourceManager.getLibraryMC(partner + "_classic")
						|| Ssf2.ResourceManager.getLibraryMC(partner + "_charselect");
					if (partnerTrophy)
					{
						preparePortraitClip(partnerTrophy);
						parts.push(partnerTrophy);
					};
				};
			};
			return parts;
		}

		/**
		 * Unique sprites + paired cover metadata (kind/isPA/bitmapData) so batch paint
		 * can use the same updateUniquePaPalettes branches as live EC.
		 */
		private function buildColorSheetUniqueBundle(charName:String):Object
		{
			var sprites:Array = [];
			var cover:Array = [];
			var scan:String;
			var mtime:Number;
			var cached:Array;
			var hydrated:Array;
			var cand:Object;
			var disp:DisplayObject;
			scan = PaletteMakerUtils.getUniqueSpriteScanStatsName(charName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scan);
			cached = SpriteCacheStore.loadUniqueSpriteCacheForUse(charName, mtime);
			if (!cached || cached.length == 0)
			{
				return { "sprites": sprites, "cover": cover };
			};
			hydrated = hydrateUniqueSpriteCache(cached);
			if (!hydrated)
			{
				return { "sprites": sprites, "cover": cover };
			};
			for each (cand in hydrated)
			{
				disp = createSpriteFromCoverCandidate(cand);
				if (disp)
				{
					sprites.push(disp);
					cover.push(cand);
				};
			};
			return { "sprites": sprites, "cover": cover };
		}

		/**
		 * Stock base costume cloned and merged with discover cache — same palette shape
		 * as editor show() after discoverAndMergeMissingSwatchColors.
		 */
		private function buildSheetPaletteDataForCharacter(charName:String, baseCostume:Object):Object
		{
			var paletteData:Object;
			var discovered:Object;
			var scan:String;
			var mtime:Number;
			var color:uint;
			if (baseCostume)
			{
				paletteData = Ssf2.Utils.cloneObject(baseCostume);
			}
			else
			{
				paletteData = {
					"paletteSwap": { "colors": [], "replacements": [] },
					"paletteSwapPA": { "colors": [], "replacements": [] }
				};
			};
			if (!paletteData.paletteSwap)
			{
				paletteData.paletteSwap = { "colors": [], "replacements": [] };
			};
			if (!paletteData.paletteSwapPA)
			{
				paletteData.paletteSwapPA = { "colors": [], "replacements": [] };
			};
			if (!(paletteData.paletteSwap.colors is Array))
			{
				paletteData.paletteSwap.colors = [];
			};
			if (!(paletteData.paletteSwap.replacements is Array))
			{
				paletteData.paletteSwap.replacements = [];
			};
			if (!(paletteData.paletteSwapPA.colors is Array))
			{
				paletteData.paletteSwapPA.colors = [];
			};
			if (!(paletteData.paletteSwapPA.replacements is Array))
			{
				paletteData.paletteSwapPA.replacements = [];
			};
			scan = PaletteMakerUtils.getUniqueSpriteScanStatsName(charName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scan);
			discovered = SpriteCacheStore.loadDiscoverCacheForUse(charName, mtime);
			if (!discovered)
			{
				return paletteData;
			};
			for each (color in (discovered.swap as Array))
			{
				if (!paletteBlockHasColor(paletteData.paletteSwap, color)
					&& !paletteBlockHasColor(paletteData.paletteSwapPA, color))
				{
					paletteData.paletteSwap.colors.push(color);
					paletteData.paletteSwap.replacements.push(color);
				};
			};
			for each (color in (discovered.swapPA as Array))
			{
				if (!paletteBlockHasColor(paletteData.paletteSwapPA, color))
				{
					paletteData.paletteSwapPA.colors.push(color);
					paletteData.paletteSwapPA.replacements.push(color);
				};
			};
			return paletteData;
		}

		/** Base order matching refreshSheetPaletteOrder / live EC. */
		private function collectSheetBasesForCharacter(charName:String, paletteData:Object=null):Array
		{
			var data:Object;
			var swap:Array;
			var swapPA:Array;
			data = paletteData || buildSheetPaletteDataForCharacter(charName,
				getPaletteMakerBaseCostumeData(charName, null));
			if (!data)
			{
				return [];
			};
			swap = (data.paletteSwap && data.paletteSwap.colors is Array)
				? data.paletteSwap.colors as Array : [];
			swapPA = (data.paletteSwapPA && data.paletteSwapPA.colors is Array)
				? data.paletteSwapPA.colors as Array : [];
			return mixArrays(swap, swapPA);
		}

		/** Applied strip matching exportColorSheet (alignAppliedColors + per-base lookup). */
		private function buildSheetAppliedStrip(rawBases:Array, paletteData:Object):Array
		{
			var repls:Array;
			var i:int;
			var applied:Array;
			if (!rawBases || rawBases.length == 0)
			{
				return [];
			};
			repls = [];
			i = 0;
			while (i < rawBases.length)
			{
				repls.push(getSheetReplacementForBaseInPalette(uint(rawBases[i]), paletteData));
				i++;
			};
			applied = ColorSheetIO.alignAppliedColors(rawBases, repls);
			if (!applied || applied.length == 0)
			{
				applied = ColorSheetIO.dedupeRgb(rawBases);
			};
			return applied;
		}

		private function getSheetReplacementForBaseInPalette(baseColor:uint, paletteData:Object):uint
		{
			var block:Object;
			var i:int;
			var colors:Array;
			var repls:Array;
			for each (block in [paletteData ? paletteData.paletteSwap : null,
				paletteData ? paletteData.paletteSwapPA : null])
			{
				if (!block || !(block.colors is Array) || !(block.replacements is Array))
				{
					continue;
				};
				colors = block.colors as Array;
				repls = block.replacements as Array;
				i = 0;
				while (i < colors.length && i < repls.length)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(colors[i]), baseColor))
					{
						return uint(repls[i]);
					};
					i++;
				};
			};
			return baseColor;
		}
    }
}
