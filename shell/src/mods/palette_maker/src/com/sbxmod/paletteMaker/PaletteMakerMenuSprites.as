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

    /** Unique-sprite and effect-cover scan, linkage lists, sprite cache warm and persist. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuSprites extends PaletteMakerMenuGroups
    {
        public function PaletteMakerMenuSprites()
        {
            super();
        }

		protected var pendingSkipCountdown:Boolean = false;

		/** Skip photo-like sheets as unique-sprite candidates. */
		private static const UNIQUE_MAX_DISTINCT_COLORS:int = 100;

		/** Safety cap so a 351-candidate expansion cannot emit a filmstrip. */
		private static const MAX_UNIQUE_COVER_SPRITES:int = 48;

		/** RE strip only — higher than body unique so Peach/Lucario VFX fit. */
		internal static const MAX_EFFECT_COVER_SPRITES:int = 96;

		/** Rasterize RE strip cells for disk cache (matches UNIQUE_FX_CELL_MAX-ish). */
		private static const EFFECT_CACHE_RASTER_MAX:int = 64;

		/** Kirby-style leftover attach only. Hundreds of leftovers × huge sheets freeze ENTER_FRAME. */
		private static const MAX_UNIQUE_FUZZY_LEFTOVERS:int = 32;

		/** DisplayObject -> linkage string (Sprite is sealed; cannot stamp dynamic props). */
		protected var fxStripLinkageMap:Dictionary = new Dictionary(true);

		/** Strip holder -> pristine BitmapData for bake-tint preview. */
		protected var fxStripPristineBd:Dictionary = new Dictionary(true);

		/** StageData may not expose Items/Projectiles on all builds — never direct-get. */
		protected function tryGetStageObjectList(stageData:*, prop:String):*
		{
			var list:*;
			if (!stageData || !prop)
			{
				return null;
			};
			try
			{
				list = stageData[prop];
				if (list != null)
				{
					return list;
				};
			}
			catch (err:Error)
			{
			};
			return null;
		}

		/** RE-only: ProjectilesArray + domain MovieClips + resources.movieclips (body excluded). */
		protected function collectEffectRecolorLinkages():Array
		{
			var out:Array;
			var seen:Object;
			var res:*;
			var resources:Object;
			var linkage:String;
			var scan:String;
			out = [];
			seen = {};
			scan = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			addProjectileLinkagesForEffects(scan, out, seen);
			addDomainEffectMovieClipLinkages(scan, out, seen);
			try
			{
				res = PaletteMakerUtils.getCharacterResource(scan, true);
			}
			catch (resErr:Error)
			{
				res = null;
			};
			if (res)
			{
				try
				{
					resources = res.getProp("resources");
					if (resources && resources.movieclips is Array)
					{
						for each (linkage in resources.movieclips)
						{
							addEffectLinkageIfAllowed(String(linkage), out, seen);
						};
					};
				}
				catch (propErr:Error)
				{
				};
			};
			addKnownBeamLinkagesForEffects(scan, out, seen);
			return out;
		}

		/**
		 * Goku/Cloney Kamehameha beams exist in library movieclips but are missing from
		 * shipped ProjectilesArray pData — force them into the RE strip when present.
		 */
		private function addKnownBeamLinkagesForEffects(scanStatsName:String, out:Array, seen:Object):void
		{
			var scan:String;
			var beams:Array;
			var i:int;
			var lid:String;
			var cls:Class;
			if (!out || !seen)
			{
				return;
			};
			scan = scanStatsName ? String(scanStatsName).toLowerCase() : "";
			if (scan.indexOf("goku") < 0 && scan.indexOf("cloney") < 0 && scan != "kgoku" && scan != "ssgoku")
			{
				return;
			};
			beams = [
				"b1", "b2", "b3", "b4", "b25",
				"blast", "kiblast",
				"goku_b_effect", "goku_b2_effect", "goku_b_fullEffectBack",
				"goku_djump_effect", "goku_dair_proj"
			];
			i = 0;
			while (i < beams.length)
			{
				lid = String(beams[i]);
				i++;
				try
				{
					cls = Ssf2.ResourceManager.getLibraryClass(lid);
				}
				catch (clsErr:Error)
				{
					cls = null;
				};
				if (!cls)
				{
					continue;
				};
				addEffectLinkageIfAllowed(lid, out, seen);
			};
		}

		private function addProjectileLinkagesForEffects(scanStatsName:String, out:Array, seen:Object):void
		{
			var st:*;
			var key:*;
			var proj:*;
			var lid:String;
			try
			{
				st = Ssf2.Stats.getStats(scanStatsName);
			}
			catch (stErr:Error)
			{
				st = null;
			};
			if (!st || !st.Attacks || !st.Attacks.ProjectilesArray)
			{
				return;
			};
			for (key in st.Attacks.ProjectilesArray)
			{
				proj = st.Attacks.ProjectilesArray[key];
				lid = "";
				if (proj && proj.LinkageID)
				{
					lid = String(proj.LinkageID);
				}
				else if (key)
				{
					lid = String(key);
				};
				addEffectLinkageIfAllowed(lid, out, seen);
			};
		}

		protected function isProjectileStatsLinkage(linkage:String):Boolean
		{
			var st:*;
			var key:*;
			var proj:*;
			var lid:String;
			var low:String;
			if (!linkage || !statsName)
			{
				return false;
			};
			low = linkage.toLowerCase();
			try
			{
				st = Ssf2.Stats.getStats(PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName));
			}
			catch (stErr:Error)
			{
				return false;
			};
			if (!st || !st.Attacks || !st.Attacks.ProjectilesArray)
			{
				return false;
			};
			for (key in st.Attacks.ProjectilesArray)
			{
				proj = st.Attacks.ProjectilesArray[key];
				lid = "";
				if (proj && proj.LinkageID)
				{
					lid = String(proj.LinkageID).toLowerCase();
				}
				else if (key)
				{
					lid = String(key).toLowerCase();
				};
				if (lid && lid == low)
				{
					return true;
				};
			};
			return false;
		}

		/**
		 * Domain SymbolClass MovieClips for RE — exclude body / locomotion / unsafe.
		 * Does not feed body unique cover.
		 */
		private function addDomainEffectMovieClipLinkages(scanStatsName:String, out:Array, seen:Object):void
		{
			var res:*;
			var domain:ApplicationDomain;
			var names:*;
			var name:String;
			var cls:Class;
			var i:int;
			var preferred:Array;
			try
			{
				res = PaletteMakerUtils.getCharacterResource(PaletteMakerUtils.getUniqueSpriteScanStatsName(scanStatsName), true);
			}
			catch (resErr:Error)
			{
				res = null;
			};
			if (!res || !res.MC || !res.MC.loaderInfo)
			{
				return;
			};
			try
			{
				domain = res.MC.loaderInfo.applicationDomain;
				if (!domain || !domain.hasOwnProperty("getQualifiedDefinitionNames"))
				{
					return;
				};
				names = domain["getQualifiedDefinitionNames"]();
			}
			catch (domainErr:Error)
			{
				return;
			};
			if (!names)
			{
				return;
			};
			preferred = [];
			i = 0;
			while (i < names.length)
			{
				name = String(names[i]);
				i++;
				if (!name || name.indexOf("_fla::") != -1 || name.indexOf(".fla::") != -1)
				{
					continue;
				};
				if (name.indexOf("::") != -1)
				{
					name = name.split("::").pop();
				};
				if (!name || name == "Main" || name.indexOf("SSF2") == 0)
				{
					continue;
				};
				if (name.toLowerCase().indexOf("giga") != -1)
				{
					continue;
				};
				if (isUnsafeUniqueSpriteLinkage(name)
					|| isBodyOrPortraitUniqueLinkage(name)
					|| isLocomotionOrHurtUniqueLinkage(name)
					|| isPaDuplicateLinkage(name))
				{
					continue;
				};
				try
				{
					if (!domain.hasDefinition(name))
					{
						continue;
					};
					cls = domain.getDefinition(name) as Class;
					if (!cls || classIsBitmapAsset(cls) || !classIsMovieClipOrSpriteExport(cls))
					{
						continue;
					};
				}
				catch (clsErr:Error)
				{
					continue;
				};
				preferred.push(name);
			};
			// Prefer safe exports (peach_turnip0) when a _fla sibling exists — unsafe already drops _fla.
			i = 0;
			while (i < preferred.length)
			{
				addEffectLinkageIfAllowed(String(preferred[i]), out, seen);
				i++;
			};
		}

		private function addEffectLinkageIfAllowed(linkage:String, out:Array, seen:Object):void
		{
			var low:String;
			if (!linkage || !out || !seen)
			{
				return;
			};
			low = linkage.toLowerCase();
			if (!low || seen[low])
			{
				return;
			};
			if (isUnsafeUniqueSpriteLinkage(linkage)
				|| isBodyOrPortraitUniqueLinkage(linkage)
				|| isLocomotionOrHurtUniqueLinkage(linkage)
				|| isPaDuplicateLinkage(linkage))
			{
				return;
			};
			seen[low] = true;
			out.push(linkage);
		}

		/** True when class extends MovieClip or Sprite (library timeline export). */
		private function classIsMovieClipOrSpriteExport(cls:Class):Boolean
		{
			var t:String;
			var depth:int;
			var parentCls:Class;
			if (!cls)
			{
				return false;
			};
			t = null;
			depth = 0;
			try
			{
				t = getQualifiedSuperclassName(cls);
			}
			catch (err:Error)
			{
				return false;
			};
			while (t && depth < 6)
			{
				if (t == "flash.display::MovieClip" || t == "flash.display.MovieClip"
					|| t == "flash.display::Sprite" || t == "flash.display.Sprite")
				{
					return true;
				};
				if (t == "flash.display::BitmapData" || t == "flash.display.BitmapData"
					|| t == "flash.display::Bitmap" || t == "flash.display.Bitmap"
					|| t == "Object" || t == "flash.display::DisplayObject")
				{
					return false;
				};
				try
				{
					parentCls = getDefinitionByName(t) as Class;
					if (!parentCls)
					{
						return false;
					};
					t = getQualifiedSuperclassName(parentCls);
				}
				catch (parentErr:Error)
				{
					return false;
				};
				depth++;
			};
			return false;
		}

		/** When true, unique-sprite scan skips MultiplayerManager toasts (batch warm). */
		protected var suppressUniqueSpriteNotify:Boolean = false;

		private static const WARM_LINKAGE_SLICE:int = 48;

		private var warmIncrementalState:Object = null;

		protected var warmIncrementalRestore:Object = null;

		/**
		 * Build/save discover color cache for a character without opening the editor.
		 * Used by Manage Costumes background warm.
		 */
		public function warmDiscoverCache(charName:String):Object
		{
			var mtime:Number;
			var discovered:Object;
			var cacheKey:String;
			var scanName:String;
			if (!charName)
			{
				return null;
			};
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(charName);
			cacheKey = PaletteMakerUtils.getDiscoverCacheKey(charName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scanName);
			discovered = SpriteCacheStore.loadDiscoverCacheForUse(charName, mtime);
			if (discovered)
			{
				SpriteCacheStore.memoDiscoverSessionCache(cacheKey, discovered);
				return discovered;
			};
			try
			{
				beginDiscoverErrorSuppress();
				discovered = collectOpaqueColorsFromRecolorTargets(charName);
				if (discovered)
				{
					SpriteCacheStore.saveDiscoverCache(cacheKey, mtime,
						discovered.swap as Array, discovered.swapPA as Array);
					SpriteCacheStore.memoDiscoverSessionCache(cacheKey, discovered);
				};
			}
			catch (err:Error)
			{
				trace("[PaletteMaker] warmDiscoverCache failed:", charName, err.message);
			}
			finally
			{
				endDiscoverErrorSuppress();
			};
			return discovered;
		}

		/** One ENTER_FRAME slice of incremental unique warm. */
		public function warmUniqueSpriteCacheIncrementalStep():Boolean
		{
			var state:Object;
			state = warmIncrementalState;
			if (!state)
			{
				return false;
			};
			if (pumpIncrementalCandidateScan())
			{
				return true;
			};
			finalizeIncrementalWarm();
			return false;
		}

		private function finalizeIncrementalWarm():void
		{
			var restore:Object;
			var selected:Array;
			var paletteColors:Array;
			var candidates:Array;
			restore = warmIncrementalRestore;
			warmIncrementalRestore = null;
			if (!restore)
			{
				return;
			};
			try
			{
				paletteColors = restore.paletteColors as Array;
				candidates = warmIncrementalState ? warmIncrementalState.out as Array : [];
				trace("[PMCache] unique cover START stats=" + statsName
					+ " candidates=" + (candidates ? candidates.length : 0)
					+ " colors=" + (paletteColors ? paletteColors.length : 0));
				selected = selectCoveringFromCandidates(paletteColors, candidates);
				trace("[PMCache] unique cover DONE stats=" + statsName
					+ " selected=" + (selected ? selected.length : 0));
				persistUniqueSpriteCache(selected, Number(restore.mtime));
			}
			catch (err:Error)
			{
				trace("[PaletteMaker] finalizeIncrementalWarm failed:", err.message);
			}
			finally
			{
				warmIncrementalState = null;
				suppressUniqueSpriteNotify = false;
				statsName = restore.prevStats;
				currentPaletteData = restore.prevPalette;
				mixedBasePaletteData = restore.prevMixed;
				baseCostumeData = restore.prevBase;
			};
		}

		/**
		 * Opaque colors on gameplay recolor targets.
		 * Returns { swap:Array, swapPA:Array }.
		 * Never seeks scripted timelines — frame scripts (e.g. Chibi-Robo) crash
		 * outside a live match and bypass try/catch.
		 */
		protected function collectOpaqueColorsFromRecolorTargets(charName:String):Object
		{
			var swapColors:Array = [];
			var swapPAColors:Array = [];
			var seenSwap:Object = {};
			var seenPA:Object = {};
			var seenLinkages:Object = {};
			var linkages:Array;
			var linkage:String;
			var mc:MovieClip;
			var charStats:*;
			var partnerName:String;
			linkages = [];
			addUniqueLinkage(charName, linkages, seenLinkages);
			try
			{
				charStats = Ssf2.Stats.getStats(charName);
				if (charStats && charStats.LinkageID)
				{
					addUniqueLinkage(String(charStats.LinkageID), linkages, seenLinkages);
				};
				if (charStats && charStats.LinkageID2)
				{
					addUniqueLinkage(String(charStats.LinkageID2), linkages, seenLinkages);
				};
				if (charStats && charStats.LinkageIDSpecial)
				{
					addUniqueLinkage(String(charStats.LinkageIDSpecial), linkages, seenLinkages);
				};
			}
			catch (statsErr:Error)
			{
			};
			// Character body / stance current frame only (depth 2) → paletteSwap
			for each (linkage in linkages)
			{
				if (!linkage || isPaDuplicateLinkage(linkage))
				{
					continue;
				};
				mc = tryGetLibraryMC(linkage);
				if (!mc)
				{
					continue;
				};
				mergeDiscoveredColors(scanCharacterRecolorColors(mc), swapColors, seenSwap);
			};
			// Raw BitmapData exports from the character SWF (no frame scripts).
			mergeDiscoveredColors(scanCharacterDomainBitmapDataColors(PaletteMakerUtils.getUniqueSpriteScanStatsName(charName)), swapColors, seenSwap);
			// Stock → paletteSwap
			mc = Ssf2.ResourceManager.getExpansionStockMC(charName);
			if (!mc)
			{
				mc = tryGetLibraryMC(charName + "_stock");
			};
			if (mc)
			{
				mergeDiscoveredColors(PaletteColorAnalysis.collectOpaqueColorsInMC(mc, 2, -1, false), swapColors, seenSwap);
			};
			// Expansion PA.png → paletteSwapPA
			mc = Ssf2.ResourceManager.getExpansionPortraitMC(charName);
			if (mc)
			{
				mergeDiscoveredColors(PaletteColorAnalysis.collectOpaqueColorsInMC(mc, 2, -1, false), swapPAColors, seenPA);
			};
			// PA / charselect / classic trophy / HUD thumbnail → paletteSwapPA (both forms for Zelda/Sheik)
			linkages = [
				charName + "_classic_trophy",
				charName + "_classic",
				"placeholder_classic_trophy",
				charName + "_charselect"
			];
			try
			{
				charStats = Ssf2.Stats.getStats(charName);
				if (charStats && charStats.Thumbnail)
				{
					linkages.push(String(charStats.Thumbnail));
				};
			}
			catch (thumbErr:Error)
			{
			};
			if (PaletteMakerUtils.isLinkedFormPair(charName))
			{
				partnerName = PaletteMakerUtils.getLinkedFormPartner(charName);
				linkages.push(partnerName + "_classic_trophy");
				linkages.push(partnerName + "_classic");
				linkages.push(partnerName + "_charselect");
				try
				{
					charStats = Ssf2.Stats.getStats(partnerName);
					if (charStats && charStats.Thumbnail)
					{
						linkages.push(String(charStats.Thumbnail));
					};
				}
				catch (partnerThumbErr:Error)
				{
				};
			};
			for each (linkage in linkages)
			{
				mc = tryGetLibraryMC(linkage);
				if (!mc)
				{
					continue;
				};
				// Depth 8 — trophy/charselect often nest Bitmaps under Sprites beyond depth 2.
				mergeDiscoveredColors(collectOpaqueColorsDeep(mc, 8), swapPAColors, seenPA);
			};
			return { "swap": swapColors, "swapPA": swapPAColors };
		}

		protected function createSpriteFromCoverCandidate(cand:Object):DisplayObject
		{
			var clone:MovieClip;
			var bmp:Bitmap;
			var holder:Sprite;
			var bd:BitmapData;
			if (!cand)
			{
				return null;
			};
			if (cand.kind == "bitmap" && cand.bitmapData is BitmapData)
			{
				try
				{
					bd = (cand.bitmapData as BitmapData).clone();
					bmp = new Bitmap(bd, "auto", false);
					bmp.smoothing = false;
					holder = new Sprite();
					holder.addChild(bmp);
					fxStripPristineBd[holder] = bd.clone();
					if (cand.linkage)
					{
						fxStripLinkageMap[holder] = String(cand.linkage).toLowerCase();
					};
					return holder;
				}
				catch (bmpErr:Error)
				{
					return null;
				};
			};
			// Live MovieClips (esp. expansion *_gif_* timelines) run frame scripts that
			// NPE outside a match — never display them; bitmap path only.
			if (((cand.linkage) && (!(isUnsafeUniqueSpriteLinkage(String(cand.linkage))))))
			{
				try
				{
					clone = Ssf2.ResourceManager.getLibraryMC(String(cand.linkage));
				}
				catch (mcErr:Error)
				{
					clone = null;
				};
			};
			if (!clone)
			{
				return null;
			};
			try
			{
				Ssf2.Utils.removeActionScriptDeep(clone, 12);
				clone.stop();
				clone.gotoAndStop(1);
			}
			catch (err:Error)
			{
			};
			if (cand.linkage)
			{
				fxStripLinkageMap[clone] = String(cand.linkage).toLowerCase();
			};
			return clone;
		}

		protected function loadOrBuildUniqueSpriteCover(forceRescan:Boolean):Array
		{
			var mtime:Number;
			var cached:Array;
			var hydrated:Array;
			var selected:Array;
			var scanName:String;
			var prevStats:String;
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scanName);
			if (!forceRescan)
			{
				cached = SpriteCacheStore.loadUniqueSpriteCacheForUse(statsName, mtime);
				if (cached != null)
				{
					if (cached.length == 0)
					{
						PaletteMakerUtils.cacheDebugLog("unique EMPTY cache stats=" + statsName);
						return [];
					};
					hydrated = hydrateUniqueSpriteCache(cached);
					if (hydrated && hydrated.length > 0)
					{
						if (!suppressUniqueSpriteNotify)
						{
							try
							{
								Ssf2.MultiplayerManager.notify("Unique sprites: loaded cache (" + hydrated.length + ")");
							}
							catch (notifyErr:Error)
							{
								trace("[PaletteMaker] unique cache notify failed:", notifyErr.message);
							};
						};
						return hydrated;
					};
				};
			};
			PaletteMakerUtils.cacheDebugLog("RESCAN unique stats=" + statsName + " scanName=" + scanName
				+ " forceRescan=" + forceRescan + " declinedBatch=" + PaletteMakerUtils.userDeclinedBatchCache);
			// Build covering set under Zelda scan id so Sheik gets the same sprite pool.
			prevStats = statsName;
			statsName = scanName;
			try
			{
				selected = selectCoveringSprites();
			}
			catch (scanErr:Error)
			{
				selected = [];
			};
			statsName = prevStats;
			persistUniqueSpriteCache(selected, mtime);
			return selected;
		}

		/** True when Goku-family strip cache lacks library beam linkages (b1/b2/…). */
		protected function effectCoverMissingKnownBeams(cover:Array):Boolean
		{
			var scan:String;
			var need:Array;
			var seen:Object;
			var i:int;
			var cand:Object;
			var low:String;
			var cls:Class;
			scan = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			scan = scan ? scan.toLowerCase() : "";
			if (scan.indexOf("goku") < 0 && scan.indexOf("cloney") < 0 && scan != "kgoku" && scan != "ssgoku")
			{
				return false;
			};
			seen = {};
			i = 0;
			while (cover && i < cover.length)
			{
				cand = cover[i];
				i++;
				if (cand && cand.linkage)
				{
					seen[String(cand.linkage).toLowerCase()] = true;
				};
			};
			need = ["b1", "b2", "b25", "b3", "blast", "kiblast"];
			i = 0;
			while (i < need.length)
			{
				low = String(need[i]).toLowerCase();
				i++;
				if (seen[low])
				{
					continue;
				};
				try
				{
					cls = Ssf2.ResourceManager.getLibraryClass(low);
				}
				catch (clsErr:Error)
				{
					cls = null;
				};
				if (cls)
				{
					return true;
				};
			};
			return false;
		}

		/** Instantiate linkage MCs once, rasterize to BitmapData candidates. Never drop ProjectilesArray ids. */
		protected function rasterizeEffectCoverCandidates(candidates:Array):Array
		{
			var out:Array;
			var i:int;
			var cand:Object;
			var linkage:String;
			var bd:BitmapData;
			var seen:Object;
			var projList:Array;
			var low:String;
			out = [];
			seen = {};
			if (!candidates)
			{
				candidates = [];
			};
			i = 0;
			while (i < candidates.length)
			{
				cand = candidates[i];
				i++;
				if (!cand)
				{
					continue;
				};
				if (cand.kind == "bitmap" && cand.bitmapData is BitmapData)
				{
					linkage = cand.linkage ? String(cand.linkage) : "";
					low = linkage.toLowerCase();
					if (low)
					{
						seen[low] = true;
					};
					out.push({
						"kind": "bitmap",
						"linkage": linkage,
						"bitmapData": (cand.bitmapData as BitmapData).clone(),
						"used": false
					});
					continue;
				};
				linkage = cand.linkage ? String(cand.linkage) : "";
				if (!linkage || isUnsafeUniqueSpriteLinkage(linkage))
				{
					continue;
				};
				low = linkage.toLowerCase();
				if (seen[low])
				{
					continue;
				};
				bd = rasterizeLibraryLinkageMultiFrame(linkage);
				if (!bd)
				{
					bd = makeEffectPlaceholderBitmap(linkage);
				};
				if (!bd)
				{
					continue;
				};
				seen[low] = true;
				out.push({
					"kind": "bitmap",
					"linkage": linkage,
					"bitmapData": bd,
					"used": false
				});
			};
			// Force-keep ProjectilesArray + known beam movieclips (Goku b1/b2 missing from pData).
			projList = [];
			addProjectileLinkagesForEffects(PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName), projList, {});
			addKnownBeamLinkagesForEffects(PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName), projList, {});
			i = 0;
			while (i < projList.length)
			{
				linkage = String(projList[i]);
				i++;
				low = linkage.toLowerCase();
				if (!low || seen[low] || isUnsafeUniqueSpriteLinkage(linkage))
				{
					continue;
				};
				if (out.length >= MAX_EFFECT_COVER_SPRITES)
				{
					break;
				};
				bd = rasterizeLibraryLinkageMultiFrame(linkage);
				if (!bd)
				{
					bd = makeEffectPlaceholderBitmap(linkage);
				};
				if (!bd)
				{
					continue;
				};
				seen[low] = true;
				out.push({
					"kind": "bitmap",
					"linkage": linkage,
					"bitmapData": bd,
					"used": false
				});
			};
			return out;
		}

		/** Try several timeline frames so empty frame-1 beams (Goku b1/b2) still rasterize. */
		protected function rasterizeLibraryLinkageMultiFrame(linkage:String):BitmapData
		{
			var clone:MovieClip;
			var bd:BitmapData;
			var frame:int;
			var maxFrames:int;
			if (!linkage)
			{
				return null;
			};
			clone = null;
			try
			{
				clone = Ssf2.ResourceManager.getLibraryMC(linkage);
			}
			catch (mcErr:Error)
			{
				clone = null;
			};
			if (!clone)
			{
				return null;
			};
			try
			{
				Ssf2.Utils.removeActionScriptDeep(clone, 12);
				clone.stop();
			}
			catch (stripErr:Error)
			{
			};
			maxFrames = 1;
			try
			{
				maxFrames = int(clone.totalFrames);
			}
			catch (tfErr:Error)
			{
				maxFrames = 1;
			};
			if (maxFrames < 1)
			{
				maxFrames = 1;
			};
			if (maxFrames > 12)
			{
				maxFrames = 12;
			};
			bd = null;
			frame = 1;
			while (frame <= maxFrames)
			{
				try
				{
					clone.gotoAndStop(frame);
				}
				catch (gotoErr:Error)
				{
				};
				bd = SpriteCacheStore.rasterizeDisplayToBitmapData(clone, EFFECT_CACHE_RASTER_MAX);
				if (bd && effectBitmapHasOpaquePixels(bd))
				{
					break;
				};
				if (bd)
				{
					try { bd.dispose(); } catch (dErr:Error) {};
					bd = null;
				};
				frame++;
			};
			try
			{
				if (clone.parent)
				{
					clone.parent.removeChild(clone);
				};
			}
			catch (remErr:Error)
			{
			};
			return bd;
		}

		private function effectBitmapHasOpaquePixels(bd:BitmapData):Boolean
		{
			var x:int;
			var y:int;
			var step:int;
			if (!bd || bd.width < 1 || bd.height < 1)
			{
				return false;
			};
			step = Math.max(1, int(Math.min(bd.width, bd.height) / 8));
			y = 0;
			while (y < bd.height)
			{
				x = 0;
				while (x < bd.width)
				{
					if (((bd.getPixel32(x, y) >> 24) & 0xFF) > 8)
					{
						return true;
					};
					x += step;
				};
				y += step;
			};
			return false;
		}

		/** Selectable strip cell when library MC has empty bounds at sample frames. */
		protected function makeEffectPlaceholderBitmap(linkage:String):BitmapData
		{
			var bd:BitmapData;
			var tf:TextField;
			var label:String;
			var hash:uint;
			var color:uint;
			var i:int;
			if (!linkage)
			{
				return null;
			};
			hash = 0;
			i = 0;
			while (i < linkage.length)
			{
				hash = ((hash * 33) + linkage.charCodeAt(i)) & 0xFFFFFF;
				i++;
			};
			color = 0xFF000000 | (0x404040 + (hash & 0x3F3F3F));
			bd = new BitmapData(40, 40, true, 0x00000000);
			bd.fillRect(new Rectangle(2, 2, 36, 36), color);
			bd.fillRect(new Rectangle(4, 4, 32, 32), 0xFF1A1A1A);
			label = linkage;
			if (label.length > 8)
			{
				label = label.substr(0, 8);
			};
			tf = new TextField();
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.text = label;
			tf.setTextFormat(new TextFormat("_sans", 9, 0xFFFFFF, true));
			tf.x = 4;
			tf.y = 12;
			bd.draw(tf);
			return bd;
		}

		protected function persistEffectSpriteCache(selected:Array, mtime:Number):void
		{
			var items:Array;
			var bitmaps:Array;
			var cand:Object;
			var scanName:String;
			var i:int;
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			if (!scanName)
			{
				return;
			};
			if (!selected)
			{
				selected = [];
			};
			items = [];
			bitmaps = [];
			i = 0;
			while (i < selected.length)
			{
				cand = selected[i];
				i++;
				if (!cand || cand.kind != "bitmap" || !cand.linkage || !(cand.bitmapData is BitmapData))
				{
					continue;
				};
				items.push({
					"linkage": String(cand.linkage),
					"bitmapIndex": bitmaps.length
				});
				bitmaps.push(cand.bitmapData as BitmapData);
			};
			SpriteCacheStore.saveEffectSpriteCache(scanName, mtime, items, bitmaps);
		}

		protected function isSharedHarvestSkip(low:String):Boolean
		{
			if (!low)
			{
				return true;
			};
			return FxRecolorUtils.isSharedStageEffectId(low);
		}

		protected function persistUniqueSpriteCache(selected:Array, mtime:Number):void
		{
			var items:Array;
			var cand:Object;
			var bitmapId:String;
			var hashIdx:int;
			var bitmapIndex:int;
			var scanName:String;
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			if (!scanName)
			{
				return;
			};
			if (!selected)
			{
				selected = [];
			};
			items = [];
			for each (cand in selected)
			{
				if (!cand || cand.kind != "bitmap" || !cand.linkage)
				{
					continue;
				};
				bitmapIndex = 0;
				bitmapId = cand.bitmapId != null ? String(cand.bitmapId) : "";
				hashIdx = bitmapId.lastIndexOf("#");
				if (hashIdx != -1)
				{
					bitmapIndex = int(bitmapId.substring(hashIdx + 1));
				};
				items.push({
					"linkage": String(cand.linkage),
					"bitmapIndex": bitmapIndex,
					"colors": cand.colors ? (cand.colors as Array).concat() : []
				});
			};
			SpriteCacheStore.saveUniqueSpriteCache(scanName, mtime, items);
		}

		protected function hydrateUniqueSpriteCache(items:Array):Array
		{
			var out:Array = [];
			var item:Object;
			var cand:Object;
			if (!items)
			{
				return out;
			};
			for each (item in items)
			{
				cand = resolveCachedBitmapCandidate(item);
				if (cand)
				{
					out.push(cand);
				};
			};
			return out;
		}

		private function resolveCachedBitmapCandidate(item:Object):Object
		{
			var linkage:String;
			var bitmapIndex:int;
			var cls:Class;
			var obj:*;
			var mc:MovieClip;
			var bitmaps:Array;
			var bmp:Bitmap;
			var bd:BitmapData;
			var bdClone:BitmapData;
			if (!item)
			{
				return null;
			};
			linkage = String(item.linkage || "");
			bitmapIndex = int(item.bitmapIndex);
			if (!linkage)
			{
				return null;
			};
			// Skip timeline/gif exports — constructing them runs frame scripts that NPE offline.
			if (isUnsafeUniqueSpriteLinkage(linkage))
			{
				return null;
			};
			try
			{
				cls = Ssf2.ResourceManager.getLibraryClass(linkage);
			}
			catch (clsErr:Error)
			{
				cls = null;
			};
			if (!cls)
			{
				return null;
			};
			try
			{
				obj = new cls();
			}
			catch (newErr:Error)
			{
				return null;
			};
			if (obj is BitmapData)
			{
				bd = obj as BitmapData;
			}
			else if (obj is Bitmap)
			{
				bd = (obj as Bitmap).bitmapData;
			}
			else if (obj is MovieClip)
			{
				mc = obj as MovieClip;
				try
				{
					Ssf2.Utils.removeActionScriptDeep(mc, 12);
					mc.stop();
					mc.gotoAndStop(1);
				}
				catch (stripErr:Error)
				{
				};
				bitmaps = [];
				try
				{
					PaletteColorAnalysis.collectBitmaps(mc, bitmaps, 10);
				}
				catch (bmpWalkErr:Error)
				{
					bitmaps = [];
				};
				if (bitmapIndex >= 0 && bitmapIndex < bitmaps.length)
				{
					bmp = bitmaps[bitmapIndex] as Bitmap;
					bd = bmp ? bmp.bitmapData : null;
				};
			};
			if (!bd)
			{
				return null;
			};
			try
			{
				bdClone = bd.clone();
			}
			catch (cloneErr:Error)
			{
				bdClone = bd;
			};
			return {
				"kind": "bitmap",
				"linkage": linkage,
				"bitmapId": linkage + "#" + bitmapIndex,
				"bitmapData": bdClone,
				"colors": item.colors is Array ? item.colors : [],
				"isPA": false,
				"used": false
			};
		}

		/** Expansion animated GIF / timeline clips — unsafe to new() outside a match. */
		protected function isUnsafeUniqueSpriteLinkage(linkage:String):Boolean
		{
			var lower:String;
			if (!linkage)
			{
				return true;
			};
			lower = linkage.toLowerCase();
			if (lower.indexOf("_gif_") >= 0)
			{
				return true;
			};
			if (lower.indexOf("gif_") == 0)
			{
				return true;
			};
			// Common Flash export suffix for imported animated GIFs.
			if (((lower.length > 4) && (lower.lastIndexOf("_gif") == (lower.length - 4))))
			{
				return true;
			};
			// Timeline script / document classes (buu_fla_*, vegeta_fla_*) — expensive
			// to instantiate and almost never hold unique palette bitmaps.
			if (lower.indexOf("_fla_") >= 0 || lower.indexOf("_fla.") >= 0)
			{
				return true;
			};
			// Afterimages / trails often NRE in frame scripts outside a real Character owner
			// (e.g. Ichigo DSpec_Afterimage/frame5).
			if (lower.indexOf("afterimage") >= 0 || lower.indexOf("after_image") >= 0
				|| lower.indexOf("afterimg") >= 0)
			{
				return true;
			};
			return false;
		}

		protected function selectCoveringSprites(paletteColorsOverride:Array=null):Array
		{
			var paletteColors:Array;
			var candidates:Array;
			if (paletteColorsOverride)
			{
				paletteColors = paletteColorsOverride;
			}
			else
			{
				try
				{
					paletteColors = collectUniquePaletteColors();
				}
				catch (err:Error)
				{
					return [];
				};
			};
			if (!paletteColors || paletteColors.length == 0)
			{
				return [];
			};
			try
			{
				candidates = buildSpriteColorCandidates(paletteColors);
			}
			catch (scanErr:Error)
			{
				if (!suppressUniqueSpriteNotify)
				{
					try
					{
						Ssf2.MultiplayerManager.notify("Unique sprite scan failed");
					}
					catch (notifyErr:Error)
					{
					};
				};
				return [];
			};
			return selectCoveringFromCandidates(paletteColors, candidates);
		}

		/** One tile per sprite: keep the root with the most palette colors, then smaller area. */
		private function dedupUniqueCandidatesByLinkageRoot(candidates:Array):Array
		{
			var bestByRoot:Object;
			var roots:Array;
			var out:Array;
			var cand:Object;
			var root:String;
			var existing:Object;
			var candCount:int;
			var existCount:int;
			out = [];
			if (!candidates)
			{
				return out;
			};
			bestByRoot = {};
			roots = [];
			for each (cand in candidates)
			{
				if (!cand || cand.isPA)
				{
					continue;
				};
				root = accessoryLinkageRoot(String(cand.linkage));
				if (!root)
				{
					root = cand.linkage ? String(cand.linkage) : "";
				};
				if (!root)
				{
					out.push(cand);
					continue;
				};
				existing = bestByRoot[root];
				if (!existing)
				{
					bestByRoot[root] = cand;
					roots.push(root);
					continue;
				};
				candCount = cand.colors ? (cand.colors as Array).length : 0;
				existCount = existing.colors ? (existing.colors as Array).length : 0;
				if (candCount > existCount)
				{
					bestByRoot[root] = cand;
				}
				else if (candCount == existCount && accessoryCandidateArea(cand) < accessoryCandidateArea(existing))
				{
					bestByRoot[root] = cand;
				};
			};
			for each (root in roots)
			{
				out.push(bestByRoot[root]);
			};
			return out;
		}

		private function selectCoveringFromCandidates(paletteColors:Array, candidates:Array):Array
		{
			var remaining:Object = {};
			var remainingCount:int;
			var selected:Array = [];
			var best:Object;
			var bestGain:int;
			var cand:Object;
			var gain:int;
			var color:uint;
			var uncovered:Array;
			var paCovered:int;
			var paBds:Array;
			if (!paletteColors || paletteColors.length == 0)
			{
				return selected;
			};
			for each (color in paletteColors)
			{
				remaining[uint(color)] = true;
			};
			remainingCount = paletteColors.length;
			paBds = collectPaSourceBitmaps();
			paCovered = markPaColorsCovered(remaining, paletteColors, paBds);
			remainingCount -= paCovered;
			if (!candidates)
			{
				candidates = [];
			};
			candidates = dedupUniqueCandidatesByLinkageRoot(candidates);
			while (remainingCount > 0 && selected.length < MAX_UNIQUE_COVER_SPRITES)
			{
				best = null;
				bestGain = 0;
				for each (cand in candidates)
				{
					if (cand.used || cand.isPA)
					{
						continue;
					};
					gain = countRemainingCoverage(cand.colors as Array, remaining);
					if (gain > bestGain)
					{
						bestGain = gain;
						best = cand;
					};
				};
				if (!best || bestGain <= 0)
				{
					break;
				};
				best.used = true;
				selected.push(best);
				for each (color in best.colors)
				{
					if (remaining[uint(color)])
					{
						delete remaining[uint(color)];
						remainingCount--;
					};
				};
			};
			if (remainingCount > 0 && remainingCount <= MAX_UNIQUE_FUZZY_LEFTOVERS && !suppressUniqueSpriteNotify)
			{
				remainingCount = fuzzyCoverRemainingColors(remaining, remainingCount, selected);
			};
			uncovered = [];
			for each (color in paletteColors)
			{
				if (remaining[uint(color)])
				{
					uncovered.push(uint(color));
				};
			};
			if (!suppressUniqueSpriteNotify)
			{
				try
				{
					Ssf2.MultiplayerManager.notify("Unique sprites: " + selected.length
						+ " shown, " + (paletteColors.length - uncovered.length) + "/" + paletteColors.length + " colors covered");
				}
				catch (notifyErr:Error)
				{
					trace("[PaletteMaker] unique cover notify failed:", notifyErr.message);
				};
			};
			return selected;
		}

		protected function beginIncrementalCandidateScan(paletteColors:Array):Boolean
		{
			var linkages:Array;
			var paBds:Array;
			var bd:BitmapData;
			var seenBitmaps:Dictionary;
			var paFingerprints:Object;
			if (!paletteColors || paletteColors.length == 0)
			{
				return false;
			};
			linkages = buildCharacterLinkageList(statsName);
			if (!linkages || linkages.length == 0)
			{
				return false;
			};
			seenBitmaps = new Dictionary(true);
			paFingerprints = {};
			paBds = collectPaSourceBitmaps();
			for each (bd in paBds)
			{
				if (!bd)
				{
					continue;
				};
				seenBitmaps[bd] = true;
				paFingerprints[bitmapFingerprint(bd)] = true;
			};
			warmIncrementalState = {
				"paletteColors": paletteColors,
				"linkages": linkages,
				"linkageIndex": 0,
				"out": [],
				"seenBitmaps": seenBitmaps,
				"covered": {},
				"need": paletteColors.length,
				"paFingerprints": paFingerprints,
				"nextLogAt": 48
			};
			trace("[PMCache] unique scan START stats=" + statsName
				+ " linkages=" + linkages.length
				+ " colors=" + paletteColors.length);
			return true;
		}

		private function pumpIncrementalCandidateScan():Boolean
		{
			var state:Object;
			var linkages:Array;
			var paletteColors:Array;
			var linkage:String;
			var processed:int;
			var i:int;
			var covered:int;
			state = warmIncrementalState;
			if (!state)
			{
				return false;
			};
			linkages = state.linkages as Array;
			paletteColors = state.paletteColors as Array;
			if (!linkages || !paletteColors)
			{
				warmIncrementalState = null;
				return false;
			};
			processed = 0;
			i = int(state.linkageIndex);
			while (i < linkages.length && processed < WARM_LINKAGE_SLICE)
			{
				linkage = String(linkages[i]);
				if (linkage && !isPaDuplicateLinkage(linkage))
				{
					scanLibraryLinkageBitmaps(linkage, paletteColors, state.out as Array,
						state.seenBitmaps as Dictionary, state.covered as Object,
						int(state.need), state.paFingerprints as Object);
				};
				i++;
				processed++;
				if (uniqueScanCanStop(linkages, i, state.covered as Object, int(state.need)))
				{
					break;
				};
			};
			state.linkageIndex = i;
			covered = countCoveredKeys(state.covered as Object);
			if (i >= int(state.nextLogAt) || uniqueScanCanStop(linkages, i, state.covered as Object, int(state.need)) || i >= linkages.length)
			{
				trace("[PMCache] unique scan progress stats=" + statsName
					+ " " + i + "/" + linkages.length
					+ " covered=" + covered + "/" + int(state.need)
					+ " candidates=" + ((state.out as Array) ? (state.out as Array).length : 0));
				state.nextLogAt = i + 96;
			};
			if (i < linkages.length && !uniqueScanCanStop(linkages, i, state.covered as Object, int(state.need)))
			{
				return true;
			};
			trace("[PMCache] unique scan DONE stats=" + statsName
				+ " scanned=" + i + "/" + linkages.length
				+ " covered=" + covered + "/" + int(state.need)
				+ " candidates=" + ((state.out as Array) ? (state.out as Array).length : 0));
			return false;
		}

		/** Add LinkageID / LinkageID2 / LinkageIDSpecial / stock for one stats form. */
		private function addFormLinkagesToList(statsName:String, priority:Array, seenLinkages:Object):void
		{
			var st:*;
			if (!statsName)
			{
				return;
			};
			addUniqueLinkage(statsName, priority, seenLinkages);
			try
			{
				st = Ssf2.Stats.getStats(statsName);
				if (st && st.LinkageID)
				{
					addUniqueLinkage(String(st.LinkageID), priority, seenLinkages);
				};
				if (st && st.LinkageID2)
				{
					addUniqueLinkage(String(st.LinkageID2), priority, seenLinkages);
				};
				if (st && st.LinkageIDSpecial)
				{
					addUniqueLinkage(String(st.LinkageIDSpecial), priority, seenLinkages);
				};
			}
			catch (statsErr:Error)
			{
			};
			addUniqueLinkage(statsName + "_stock", priority, seenLinkages);
			addAccessoryLinkagesToList(statsName, priority, seenLinkages);
		}

		/** Projectile / enemy accessories (waluigi_plant, pots, dice, stats linkage_ids). */
		private function addAccessoryLinkagesToList(formStatsName:String, priority:Array, seenLinkages:Object):void
		{
			var st:*;
			var key:*;
			var proj:*;
			var lid:String;
			var i:int;
			if (!formStatsName)
			{
				return;
			};
			addUniqueLinkage(formStatsName + "_plant", priority, seenLinkages);
			addUniqueLinkage(formStatsName + "_pot", priority, seenLinkages);
			addUniqueLinkage(formStatsName + "_dice", priority, seenLinkages);
			i = 0;
			while (i < 10)
			{
				addUniqueLinkage(formStatsName + "_plant" + i, priority, seenLinkages);
				i++;
			};
			try
			{
				st = Ssf2.Stats.getStats(formStatsName);
				if (st && st.Attacks && st.Attacks.ProjectilesArray)
				{
					for (key in st.Attacks.ProjectilesArray)
					{
						proj = st.Attacks.ProjectilesArray[key];
						lid = "";
						if (proj && proj.LinkageID)
						{
							lid = String(proj.LinkageID);
						}
						else if (key)
						{
							lid = String(key);
						};
						if (lid)
						{
							addUniqueLinkage(lid, priority, seenLinkages);
						};
					};
				};
			}
			catch (projErr:Error)
			{
			};
		}

		/**
		 * Multi-char expansion packs: collect linkages from every form in the pack
		 * (primary scanStatsName still keys the cache; content is pack-wide).
		 */
		private function addExpansionPackFormLinkages(scanStatsName:String, priority:Array, seenLinkages:Object):Boolean
		{
			var ei:int;
			var ej:int;
			var expChars:*;
			var expObj:Object;
			var formName:String;
			var foundPack:Boolean;
			if (!scanStatsName)
			{
				return false;
			};
			ei = 0;
			while (ei < Ssf2.ResourceManager.TotalExpansions)
			{
				expChars = Ssf2.ResourceManager.getExpansionCharacter(ei);
				foundPack = false;
				if (expChars)
				{
					ej = 0;
					while (ej < expChars.length)
					{
						expObj = expChars[ej];
						formName = ((expObj && expObj.cData) ? expObj.cData.statsName : null);
						if (formName && (formName == scanStatsName
							|| PaletteMakerUtils.getUniqueSpriteScanStatsName(formName) == scanStatsName))
						{
							foundPack = true;
							break;
						};
						ej++;
					};
				};
				if (foundPack)
				{
					ej = 0;
					while (ej < expChars.length)
					{
						expObj = expChars[ej];
						formName = ((expObj && expObj.cData) ? expObj.cData.statsName : null);
						if (formName)
						{
							addFormLinkagesToList(formName, priority, seenLinkages);
						};
						ej++;
					};
					return true;
				};
				ei++;
			};
			return false;
		}

		/** Priority: body linkages, stock, then remaining exported symbols. */
		private function buildCharacterLinkageList(scanStatsName:String):Array
		{
			var linkages:Array = [];
			var priority:Array = [];
			var rest:Array = [];
			var seenLinkages:Object = {};
			var res:*;
			var resources:Object;
			var linkage:String;
			try
			{
				res = PaletteMakerUtils.getCharacterResource(PaletteMakerUtils.getUniqueSpriteScanStatsName(scanStatsName), true);
			}
			catch (resErr:Error)
			{
				res = null;
			};
			if (!addExpansionPackFormLinkages(scanStatsName, priority, seenLinkages))
			{
				addFormLinkagesToList(scanStatsName, priority, seenLinkages);
			};
			if (res)
			{
				try
				{
					resources = res.getProp("resources");
					if (resources && resources.movieclips is Array)
					{
						for each (linkage in resources.movieclips)
						{
							addUniqueLinkage(String(linkage), rest, seenLinkages);
						};
					};
				}
				catch (propErr:Error)
				{
				};
				// Always enqueue exported Bitmap/BitmapData (same surface as discover).
				// Do not dump timeline MovieClip classes — those are unsafe / huge.
				addDomainBitmapLinkagesToList(res, rest, seenLinkages);
			};
			linkages = priority.concat(rest);
			return linkages;
		}

		/**
		 * Discover already finds colors on every exported bitmap. Unique scan must
		 * visit those same symbols or attack props (racket, etc.) never become candidates.
		 * Must-visit props are inserted before locomotion/VFX sheets so early-stop
		 * can skip idle dumps after props are scanned.
		 */
		private function addDomainBitmapLinkagesToList(res:*, rest:Array, seenLinkages:Object):void
		{
			var domain:ApplicationDomain;
			var names:*;
			var name:String;
			var cls:Class;
			var i:int;
			var props:Array;
			var other:Array;
			if (!res || !rest || !seenLinkages)
			{
				return;
			};
			try
			{
				if (!res.MC || !res.MC.loaderInfo)
				{
					return;
				};
				domain = res.MC.loaderInfo.applicationDomain;
				if (!domain || !domain.hasOwnProperty("getQualifiedDefinitionNames"))
				{
					return;
				};
				names = domain["getQualifiedDefinitionNames"]();
			}
			catch (domainErr:Error)
			{
				return;
			};
			if (!names)
			{
				return;
			};
			props = [];
			other = [];
			i = 0;
			while (i < names.length)
			{
				name = String(names[i]);
				i++;
				if (!name || name.indexOf("_fla::") != -1 || name.indexOf(".fla::") != -1)
				{
					continue;
				};
				if (name.indexOf("::") != -1)
				{
					name = name.split("::").pop();
				};
				if (!name || name == "Main" || name.indexOf("SSF2") == 0)
				{
					continue;
				};
				if (name.toLowerCase().indexOf("giga") != -1)
				{
					continue;
				};
				if (isUnsafeUniqueSpriteLinkage(name) || isVfxUniqueLinkage(name))
				{
					continue;
				};
				try
				{
					if (!domain.hasDefinition(name))
					{
						continue;
					};
					cls = domain.getDefinition(name) as Class;
					if (!cls || !classIsBitmapAsset(cls))
					{
						continue;
					};
				}
				catch (clsErr:Error)
				{
					continue;
				};
				if (isMustVisitPropLinkage(name))
				{
					addUniqueLinkage(name, props, seenLinkages);
				}
				else
				{
					addUniqueLinkage(name, other, seenLinkages);
				};
			};
			i = 0;
			while (i < props.length)
			{
				rest.push(props[i]);
				i++;
			};
			i = 0;
			while (i < other.length)
			{
				rest.push(other[i]);
				i++;
			};
		}

		/**
		 * Some palette entries are slightly off the real SWF pixels (Kirby has two
		 * within manhattan 6). Attach leftovers to already-selected sprites only.
		 * Never walks unused candidates — that path froze Buu cache warm.
		 */
		private function fuzzyCoverRemainingColors(remaining:Object, remainingCount:int, selected:Array):int
		{
			var remColors:Array;
			var color:uint;
			var cand:Object;
			var order:Array;
			var found:Array;
			var key:*;
			var tol:int;
			var i:int;
			if (!remaining || remainingCount <= 0 || remainingCount > MAX_UNIQUE_FUZZY_LEFTOVERS)
			{
				return remainingCount;
			};
			tol = SpriteCacheStore.UNIQUE_SPRITE_COLOR_TOLERANCE;
			remColors = [];
			for (key in remaining)
			{
				remColors.push(uint(key));
			};
			order = [];
			if (selected)
			{
				for each (cand in selected)
				{
					order.push(cand);
				};
			};
			i = 0;
			while (i < order.length && remainingCount > 0)
			{
				cand = order[i];
				if (cand && (cand.bitmapData is BitmapData))
				{
					found = PaletteColorAnalysis.getPaletteColorsInBitmapData(
						cand.bitmapData as BitmapData, remColors, tol);
					if (found && found.length > 0)
					{
						if (!cand.colors)
						{
							cand.colors = [];
						};
						for each (color in found)
						{
							if (remaining[uint(color)])
							{
								cand.colors.push(color);
								delete remaining[uint(color)];
								remainingCount--;
							};
						};
						if (!cand.used)
						{
							cand.used = true;
							selected.push(cand);
						};
						remColors = [];
						for (key in remaining)
						{
							remColors.push(uint(key));
						};
					};
				};
				i++;
			};
			return remainingCount;
		}

		private function countRemainingCoverage(colors:Array, remaining:Object):int
		{
			var count:int = 0;
			var color:uint;
			if (!colors || !remaining)
			{
				return 0;
			};
			for each (color in colors)
			{
				if (remaining[uint(color)])
				{
					count++;
				};
			};
			return count;
		}

		/**
		 * Enumerate ALL exported library symbols and scan embedded BitmapData.
		 * No timeline seeks. Skips PA duplicates by fingerprint. Early-exit when covered.
		 */
		private function buildSpriteColorCandidates(paletteColors:Array):Array
		{
			var out:Array = [];
			var linkages:Array;
			var linkage:String;
			var seenBitmaps:Dictionary;
			var paFingerprints:Object;
			var paBds:Array;
			var bd:BitmapData;
			var covered:Object;
			var need:int;
			var i:int;
			if (!paletteColors || paletteColors.length == 0)
			{
				return out;
			};
			seenBitmaps = new Dictionary(true);
			paFingerprints = {};
			covered = {};
			need = paletteColors.length;
			linkages = buildCharacterLinkageList(statsName);
			paBds = collectPaSourceBitmaps();
			for each (bd in paBds)
			{
				if (!bd)
				{
					continue;
				};
				seenBitmaps[bd] = true;
				paFingerprints[bitmapFingerprint(bd)] = true;
			};
			i = 0;
			while (i < linkages.length)
			{
				linkage = String(linkages[i]);
				if (!isPaDuplicateLinkage(linkage))
				{
					scanLibraryLinkageBitmaps(linkage, paletteColors, out, seenBitmaps, covered, need, paFingerprints);
				};
				i++;
				if (uniqueScanCanStop(linkages, i, covered, need))
				{
					break;
				};
			};
			return out;
		}

		/** Colors already visible on the PA do not need unique sprites. */
		private function markPaColorsCovered(remaining:Object, paletteColors:Array, paBds:Array=null):int
		{
			var removed:int = 0;
			var bd:BitmapData;
			var found:Array;
			var color:uint;
			var bds:Array;
			if (!remaining || !paletteColors)
			{
				return 0;
			};
			bds = paBds ? paBds : collectPaSourceBitmaps();
			for each (bd in bds)
			{
				found = PaletteColorAnalysis.getPaletteColorsInBitmapData(bd, paletteColors);
				if (!found)
				{
					continue;
				};
				for each (color in found)
				{
					if (remaining[uint(color)])
					{
						delete remaining[uint(color)];
						removed++;
					};
				};
			};
			return removed;
		}

		/** Fresh library trophy/charselect + live PixelArt bitmaps used for PA dedupe/coverage. */
		private function collectPaSourceBitmaps():Array
		{
			var out:Array = [];
			var seen:Dictionary = new Dictionary(true);
			var mc:MovieClip;
			var bmps:Array;
			var bmp:Bitmap;
			var bd:BitmapData;
			var linkages:Array;
			var linkage:String;
			linkages = [
				statsName + "_classic_trophy",
				"placeholder_classic_trophy",
				statsName + "_charselect"
			];
			if (PaletteMakerUtils.isLinkedFormPair(statsName))
			{
				linkages.push(PaletteMakerUtils.getLinkedFormPartner(statsName) + "_classic_trophy");
				linkages.push(PaletteMakerUtils.getLinkedFormPartner(statsName) + "_charselect");
			};
			mc = Ssf2.ResourceManager.getExpansionPortraitMC(statsName);
			if (mc)
			{
				try
				{
					bmps = [];
					PaletteColorAnalysis.collectBitmaps(mc, bmps, 10);
					for each (bmp in bmps)
					{
						if (!bmp || !bmp.bitmapData || seen[bmp.bitmapData])
						{
							continue;
						};
						seen[bmp.bitmapData] = true;
						out.push(bmp.bitmapData);
					};
				}
				catch (xpPaErr:Error)
				{
				};
			};
			for each (linkage in linkages)
			{
				try
				{
					mc = Ssf2.ResourceManager.getLibraryMC(linkage);
				}
				catch (mcErr:Error)
				{
					mc = null;
				};
				if (!mc)
				{
					continue;
				};
				try
				{
					Ssf2.Utils.removeActionScript(mc);
					mc.stop();
				}
				catch (stripErr:Error)
				{
				};
				bmps = [];
				PaletteColorAnalysis.collectBitmaps(mc, bmps, 10);
				for each (bmp in bmps)
				{
					bd = bmp ? bmp.bitmapData : null;
					if (bd && !seen[bd])
					{
						seen[bd] = true;
						out.push(bd);
					};
				};
			};
			if (PixelArt)
			{
				bmps = [];
				try
				{
					PaletteColorAnalysis.collectBitmaps(PixelArt, bmps, 10);
					for each (bmp in bmps)
					{
						bd = bmp ? bmp.bitmapData : null;
						if (bd && !seen[bd])
						{
							seen[bd] = true;
							out.push(bd);
						};
					};
				}
				catch (paErr:Error)
				{
				};
			};
			return out;
		}

		private function bitmapFingerprint(bd:BitmapData):String
		{
			var hash:uint;
			var step:int;
			var x:int;
			var y:int;
			var p:uint;
			if (!bd || bd.width <= 0 || bd.height <= 0)
			{
				return "0x0:0";
			};
			hash = 2166136261;
			step = Math.max(1, int(Math.sqrt(bd.width * bd.height) / 24));
			y = 0;
			while (y < bd.height)
			{
				x = 0;
				while (x < bd.width)
				{
					p = bd.getPixel32(x, y);
					hash = (hash ^ p) * 16777619;
					x += step;
				};
				y += step;
			};
			return bd.width + "x" + bd.height + ":" + hash.toString(16);
		}

		protected function isPaDuplicateLinkage(linkage:String):Boolean
		{
			var lower:String;
			if (!linkage)
			{
				return true;
			};
			lower = linkage.toLowerCase();
			return lower.indexOf("classic_trophy") != -1
				|| lower.indexOf("charselect") != -1
				|| lower == "placeholder_classic_trophy";
		}

		private function addUniqueLinkage(linkage:String, linkages:Array, seen:Object):void
		{
			if (!linkage || seen[linkage] || isUnsafeUniqueSpriteLinkage(linkage))
			{
				return;
			};
			seen[linkage] = true;
			linkages.push(linkage);
		}

		private function scanLibraryLinkageBitmaps(linkage:String, paletteColors:Array, out:Array, seenBitmaps:Dictionary, covered:Object=null, need:int=0, paFingerprints:Object=null):void
		{
			var mc:MovieClip;
			var bitmaps:Array;
			var bmp:Bitmap;
			var bmpId:int;
			var obj:*;
			var cls:Class;
			if (isUnsafeUniqueSpriteLinkage(linkage))
			{
				return;
			};
			try
			{
				cls = Ssf2.ResourceManager.getLibraryClass(linkage);
			}
			catch (clsErr:Error)
			{
				cls = null;
			};
			if (!cls)
			{
				return;
			};
			try
			{
				obj = new cls();
			}
			catch (newErr:Error)
			{
				return;
			};
			if (obj is BitmapData)
			{
				pushBitmapCandidate(obj as BitmapData, linkage, linkage, paletteColors, out, seenBitmaps, covered, paFingerprints);
				return;
			};
			if (obj is Bitmap)
			{
				bmp = obj as Bitmap;
				if (bmp.bitmapData)
				{
					pushBitmapCandidate(bmp.bitmapData, linkage, linkage, paletteColors, out, seenBitmaps, covered, paFingerprints);
				};
				return;
			};
			if (!(obj is MovieClip))
			{
				return;
			};
			mc = obj as MovieClip;
			try
			{
				Ssf2.Utils.removeActionScriptDeep(mc, 12);
				mc.stop();
				mc.gotoAndStop(1);
			}
			catch (stripErr:Error)
			{
			};
			bitmaps = [];
			try
			{
				PaletteColorAnalysis.collectBitmaps(mc, bitmaps, 10);
			}
			catch (walkErr:Error)
			{
				return;
			};
			bitmaps.sort(compareBitmapSizeDesc);
			bmpId = 0;
			for each (bmp in bitmaps)
			{
				if (!bmp || !bmp.bitmapData)
				{
					continue;
				};
				pushBitmapCandidate(bmp.bitmapData, linkage, linkage + "#" + bmpId, paletteColors, out, seenBitmaps, covered, paFingerprints);
				bmpId++;
				if (covered && need > 0 && countCoveredKeys(covered) >= need)
				{
					return;
				};
			};
		}

		private function pushBitmapCandidate(bd:BitmapData, linkage:String, bitmapId:String, paletteColors:Array, out:Array, seenBitmaps:Dictionary, covered:Object, paFingerprints:Object=null):void
		{
			var found:Array;
			var color:uint;
			var fp:String;
			if (!bd || seenBitmaps[bd] || bd.width * bd.height < 4)
			{
				return;
			};
			seenBitmaps[bd] = true;
			fp = bitmapFingerprint(bd);
			if (paFingerprints && paFingerprints[fp])
			{
				return;
			};
			if (countDistinctOpaqueColors(bd) > UNIQUE_MAX_DISTINCT_COLORS)
			{
				return;
			};
			found = PaletteColorAnalysis.getPaletteColorsInBitmapData(bd, paletteColors);
			if (!found || found.length == 0)
			{
				return;
			};
			out.push({
				"kind": "bitmap",
				"linkage": linkage,
				"bitmapId": bitmapId,
				"bitmapData": bd,
				"colors": found,
				"isPA": false,
				"used": false
			});
			if (covered)
			{
				for each (color in found)
				{
					covered[uint(color)] = true;
				};
			};
		}

		/** Distinct opaque RGB count; early-outs past UNIQUE_MAX_DISTINCT_COLORS. */
		private function countDistinctOpaqueColors(bd:BitmapData):int
		{
			var seen:Object;
			var vec:Vector.<uint>;
			var i:int;
			var p:uint;
			var rgb:uint;
			var n:int;
			if (!bd || bd.width <= 0 || bd.height <= 0)
			{
				return 0;
			};
			seen = {};
			n = 0;
			try
			{
				vec = bd.getVector(bd.rect);
				i = 0;
				while (i < vec.length)
				{
					p = vec[i];
					if ((p >>> 24) > 0)
					{
						rgb = p & 0x00FFFFFF;
						if (!seen[rgb])
						{
							seen[rgb] = true;
							n++;
							if (n > UNIQUE_MAX_DISTINCT_COLORS)
							{
								return n;
							};
						};
					};
					i++;
				};
			}
			catch (err:Error)
			{
				return 0;
			};
			return n;
		}

		private function countCoveredKeys(covered:Object):int
		{
			var n:int = 0;
			var key:*;
			if (!covered)
			{
				return 0;
			};
			for (key in covered)
			{
				n++;
			};
			return n;
		}

		/** Stop unique scan once every palette color has a covering candidate. */
		private function uniqueScanCanStop(linkages:Array, nextIndex:int, covered:Object, need:int):Boolean
		{
			if (!linkages || need <= 0)
			{
				return false;
			};
			return countCoveredKeys(covered) >= need;
		}

		protected function isVfxUniqueLinkage(linkage:String):Boolean
		{
			return FxRecolorUtils.isVfxRecolorLinkage(linkage);
		}

		protected function isBodyOrPortraitUniqueLinkage(linkage:String):Boolean
		{
			var low:String;
			var scan:String;
			var partner:String;
			var st:*;
			if (!linkage)
			{
				return true;
			};
			if (isPaDuplicateLinkage(linkage))
			{
				return true;
			};
			low = linkage.toLowerCase();
			scan = statsName ? String(statsName).toLowerCase() : "";
			if (scan && (low == scan || low == scan + "_stock" || low == scan + "_head"
				|| accessoryLinkageRoot(linkage) == scan))
			{
				return true;
			};
			try
			{
				st = Ssf2.Stats.getStats(statsName);
				if (st)
				{
					if (st.LinkageID && low == String(st.LinkageID).toLowerCase())
					{
						return true;
					};
					if (st.LinkageID2 && low == String(st.LinkageID2).toLowerCase())
					{
						return true;
					};
					if (st.LinkageIDSpecial && low == String(st.LinkageIDSpecial).toLowerCase())
					{
						return true;
					};
				};
			}
			catch (stErr:Error)
			{
			};
			partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (partner)
			{
				partner = partner.toLowerCase();
				if (low == partner || low == partner + "_stock" || low == partner + "_head"
					|| accessoryLinkageRoot(linkage) == partner)
				{
					return true;
				};
			};
			return false;
		}

		/** Idle / walk / hurt sheets — body art, not held props. */
		protected function isLocomotionOrHurtUniqueLinkage(linkage:String):Boolean
		{
			var root:String;
			var tags:Array;
			var tag:String;
			var i:int;
			if (!linkage)
			{
				return false;
			};
			root = accessoryLinkageRoot(linkage);
			tags = [
				"_idle", "_idleb", "_walk", "_run", "_jump", "_jumpsquat",
				"_fall", "_landing", "_land", "_hurt", "_tumble", "_wait",
				"_dash", "_crouch", "_guard", "_shield", "_dodge", "_roll",
				"_skid", "_turn", "_sleep", "_dizzy", "_breath", "_stand",
				"_sprite", "_hitstun"
			];
			i = 0;
			while (i < tags.length)
			{
				tag = String(tags[i]);
				if (root.length >= tag.length && root.lastIndexOf(tag) == (root.length - tag.length))
				{
					return true;
				};
				i++;
			};
			return false;
		}

		/** Attack / item / projectile bitmaps that greedy cover would otherwise drop. */
		private function isMustVisitPropLinkage(linkage:String):Boolean
		{
			if (!linkage || isUnsafeUniqueSpriteLinkage(linkage) || isVfxUniqueLinkage(linkage))
			{
				return false;
			};
			if (isBodyOrPortraitUniqueLinkage(linkage) || isLocomotionOrHurtUniqueLinkage(linkage))
			{
				return false;
			};
			return true;
		}

		private function accessoryLinkageRoot(linkage:String):String
		{
			var low:String;
			var code:int;
			if (!linkage)
			{
				return "";
			};
			low = linkage.toLowerCase();
			while (low.length > 0)
			{
				code = low.charCodeAt(low.length - 1);
				if (code < 48 || code > 57)
				{
					break;
				};
				low = low.substr(0, low.length - 1);
			};
			return low;
		}

		private function accessoryCandidateArea(cand:Object):int
		{
			var bd:BitmapData;
			if (!cand || !(cand.bitmapData is BitmapData))
			{
				return int.MAX_VALUE;
			};
			bd = cand.bitmapData as BitmapData;
			return bd.width * bd.height;
		}

		private function compareBitmapSizeDesc(a:Bitmap, b:Bitmap):int
		{
			var aSize:int;
			var bSize:int;
			aSize = (a && a.bitmapData) ? (a.bitmapData.width * a.bitmapData.height) : 0;
			bSize = (b && b.bitmapData) ? (b.bitmapData.width * b.bitmapData.height) : 0;
			if (aSize > bSize)
			{
				return -1;
			};
			if (aSize < bSize)
			{
				return 1;
			};
			return 0;
		}

		protected function collectUniquePaletteColors():Array
		{
			var out:Array = [];
			var seen:Object = {};
			var block:Object;
			var i:int;
			var c:uint;
			var child:DisplayObject;
			var box:ColorSquare;
			if (m_subMenu && m_subMenu.colorBoxBG)
			{
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
						c = uint(box.colorValue);
						if (!seen[c])
						{
							seen[c] = true;
							out.push(c);
						};
					};
					i++;
				};
			};
			if (out.length > 0)
			{
				return out;
			};
			for each (block in [currentPaletteData.paletteSwapPA, currentPaletteData.paletteSwap])
			{
				if (!block || !block.colors)
				{
					continue;
				};
				i = 0;
				while (i < block.colors.length)
				{
					c = uint(block.colors[i]);
					if (!seen[c])
					{
						seen[c] = true;
						out.push(c);
					};
					i++;
				};
			};
			return out;
		}

		protected function trySkipPostEntranceCountdown():void
		{
			var stageData:*;
			var inEntrance:Boolean;
			var timer:*;
			if (!pendingSkipCountdown || !player || !Ssf2.GameController.stageData)
			{
				return;
			};
			stageData = Ssf2.GameController.stageData;
			try
			{
				inEntrance = (player.State == Ssf2.CState.ENTRANCE);
			}
			catch (err:Error)
			{
				inEntrance = false;
			};
			if (inEntrance)
			{
				return;
			};
			try
			{
				timer = stageData.m_countdownTimer;
			}
			catch (err2:Error)
			{
				timer = null;
			};
			if (timer)
			{
				try
				{
					timer.bypassTicker = true;
					timer.stop();
					timer.visible = false;
					if (timer.parent)
					{
						timer.parent.removeChild(timer);
					};
				}
				catch (err3:Error)
				{
				};
			};
			try
			{
				stageData.stopNarratorSpeech();
			}
			catch (err4:Error)
			{
			};
			if (stageData.StageEvent)
			{
				Ssf2.SSF2API.matchGo();
			};
			pendingSkipCountdown = false;
		}
    }
}
