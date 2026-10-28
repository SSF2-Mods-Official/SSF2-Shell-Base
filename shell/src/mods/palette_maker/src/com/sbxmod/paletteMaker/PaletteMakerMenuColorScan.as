package com.sbxmod.paletteMaker
{
    import ssf2mm.shared.HsvWheel;
    import flash.events.MouseEvent;
    import flash.events.Event;
	import flash.utils.getTimer;
    import flash.display.MovieClip;
    import flash.text.TextField;
    import flash.events.FocusEvent;
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

    /** Discover/scan character colors, hot palette blocks, studio error suppress, portrait paint. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuColorScan extends PaletteMenuBase
    {
        public function PaletteMakerMenuColorScan()
        {
            super();
        }

		internal static var statsName:String;

		protected var currentPaletteData:Object;

		protected var mixedBasePaletteData:Array = [];

		/** Colors that belong only to the alt form. Shown under their own label. */
		protected var altSwatchColors:Array = null;

		protected var player:*;

		protected var PixelArt:MovieClip;

		protected var PixelArtPartner:MovieClip = null;

		/** root portrait MC -> (Bitmap -> original BitmapData) for deep recolor restore. */
		protected var portraitBitmapCaches:Dictionary = new Dictionary(true);
		/** Bright painted bitmap for each display Bitmap. Hover dim draws from this. */
		protected var hoverBright:Dictionary = new Dictionary(true);
		/** Reused darkened buffer for each display Bitmap. */
		protected var hoverDim:Dictionary = new Dictionary(true);

		/** O(1) RGB membership for mixedBase (key = color & 0xFFFFFF). */
		protected var mixedBaseRgbSet:Object = null;

		/** Cached non-identity paletteSwap / PA for hot paint paths. */
		private var hotPaletteSwap:Object = null;

		private var hotPaletteSwapPA:Object = null;

		private var hotPaletteSourceSwap:Object = null;

		private var hotPaletteSourceSwapPA:Object = null;

		protected function rebuildMixedBaseRgbSet():void
		{
			var c:*;
			mixedBaseRgbSet = {};
			if (!mixedBasePaletteData)
			{
				return;
			};
			for each (c in mixedBasePaletteData)
			{
				mixedBaseRgbSet[uint(c) & 0x00FFFFFF] = true;
			};
		}

		protected function invalidateHotPalettes():void
		{
			hotPaletteSwap = null;
			hotPaletteSwapPA = null;
			hotPaletteSourceSwap = null;
			hotPaletteSourceSwapPA = null;
		}

		/** Non-identity-only palette for hot paint; null if nothing to paint. */
		protected function getHotPaletteBlock(block:Object):Object
		{
			var colors:Array;
			var repls:Array;
			var outColors:Array;
			var outRepls:Array;
			var i:int;
			if (!block || !(block.colors is Array) || !(block.replacements is Array))
			{
				return null;
			};
			if (block == currentPaletteData.paletteSwap && hotPaletteSwap && hotPaletteSourceSwap == block)
			{
				return hotPaletteSwap;
			};
			if (block == currentPaletteData.paletteSwapPA && hotPaletteSwapPA && hotPaletteSourceSwapPA == block)
			{
				return hotPaletteSwapPA;
			};
			colors = block.colors as Array;
			repls = block.replacements as Array;
			outColors = [];
			outRepls = [];
			i = 0;
			while (i < colors.length && i < repls.length)
			{
				if (uint(colors[i]) != uint(repls[i]))
				{
					outColors.push(colors[i]);
					outRepls.push(repls[i]);
				};
				i++;
			};
			if (outColors.length == 0)
			{
				if (block == currentPaletteData.paletteSwap)
				{
					hotPaletteSwap = null;
					hotPaletteSourceSwap = block;
				}
				else if (block == currentPaletteData.paletteSwapPA)
				{
					hotPaletteSwapPA = null;
					hotPaletteSourceSwapPA = block;
				};
				return null;
			};
			if (block == currentPaletteData.paletteSwap)
			{
				hotPaletteSwap = { colors: outColors, replacements: outRepls };
				hotPaletteSourceSwap = block;
				return hotPaletteSwap;
			};
			if (block == currentPaletteData.paletteSwapPA)
			{
				hotPaletteSwapPA = { colors: outColors, replacements: outRepls };
				hotPaletteSourceSwapPA = block;
				return hotPaletteSwapPA;
			};
			return { colors: outColors, replacements: outRepls };
		}

		protected function paletteBlockHasColor(block:Object, color:uint):Boolean
		{
			var i:int;
			if (!block || !(block.colors is Array))
			{
				return false;
			};
			i = 0;
			while (i < block.colors.length)
			{
				if (PaletteColorAnalysis.colorsMatch(uint(block.colors[i]), color))
				{
					return true;
				};
				i++;
			};
			return false;
		}

		/**
		 * LoaderInfos whose uncaught errors we suppress in Palette Maker.
		 * Expansion frame scripts (e.g. vegeta_fla_finalExplosion) often NRE outside a
		 * full match; AIR still surfaces those as UncaughtErrorEvent even when nextFrame
		 * is wrapped in try/catch.
		 */
		private var studioSuppressLoaderInfos:Array = null;

		/** True while the Palette Maker menu is open (session-wide suppress). */
		protected var studioSessionSuppress:Boolean = false;

		private function suppressStudioUncaughtError(e:UncaughtErrorEvent):void
		{
			try
			{
				e.preventDefault();
			}
			catch (err:*)
			{
			};
		}

		protected function beginStudioErrorSuppress():void
		{
			var infos:Array = [];
			var li:LoaderInfo;
			var res:*;
			var seen:Object = {};
			var key:String;
			endStudioErrorSuppressListeners();
			try
			{
				if (Ssf2.Main.Root && Ssf2.Main.Root.loaderInfo)
				{
					infos.push(Ssf2.Main.Root.loaderInfo);
				};
			}
			catch (err0:*)
			{
			};
			try
			{
				res = PaletteMakerUtils.getCharacterResource(PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName), true);
				if (res && res.MC && res.MC.loaderInfo)
				{
					infos.push(res.MC.loaderInfo);
				};
			}
			catch (err1:*)
			{
			};
			try
			{
				if (player && player.MC && player.MC.loaderInfo)
				{
					infos.push(player.MC.loaderInfo);
				};
			}
			catch (err2:*)
			{
			};
			studioSuppressLoaderInfos = [];
			for each (li in infos)
			{
				if (!li)
				{
					continue;
				};
				try
				{
					key = String(li.url);
				}
				catch (urlErr:*)
				{
					key = String(li);
				};
				if (seen[key])
				{
					continue;
				};
				seen[key] = true;
				try
				{
					li.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, suppressStudioUncaughtError, false, int.MAX_VALUE, false);
					studioSuppressLoaderInfos.push(li);
				}
				catch (err3:*)
				{
				};
			};
		}

		private function endStudioErrorSuppressListeners():void
		{
			var li:LoaderInfo;
			if (!studioSuppressLoaderInfos)
			{
				return;
			};
			for each (li in studioSuppressLoaderInfos)
			{
				try
				{
					li.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, suppressStudioUncaughtError);
				}
				catch (err:*)
				{
				};
			};
			studioSuppressLoaderInfos = null;
		}

		protected function endStudioErrorSuppress():void
		{
			studioSessionSuppress = false;
			endStudioErrorSuppressListeners();
		}

		/** Discover-time alias — do not tear down session-wide studio suppress. */
		protected function beginDiscoverErrorSuppress():void
		{
			beginStudioErrorSuppress();
		}

		protected function endDiscoverErrorSuppress():void
		{
			if (studioSessionSuppress)
			{
				return;
			};
			endStudioErrorSuppressListeners();
		}

		/** Deep opaque color collect (DisplayObjectContainer walk, not MovieClip-only). */
		protected function collectOpaqueColorsDeep(root:DisplayObject, maxDepth:int):Array
		{
			var out:Array = [];
			var seen:Object = {};
			collectOpaqueColorsDeepWalk(root, maxDepth, out, seen);
			return out;
		}

		private function collectOpaqueColorsDeepWalk(node:DisplayObject, depth:int, out:Array, seen:Object):void
		{
			var bmp:Bitmap;
			var bd:BitmapData;
			var container:DisplayObjectContainer;
			var i:int;
			var x:int;
			var y:int;
			var px:uint;
			var key:String;
			var step:int;
			var maxPixels:int;
			var fastColors:Array;
			var fc:uint;
			if (!node || depth < 0)
			{
				return;
			};
			if (node is Bitmap)
			{
				bmp = node as Bitmap;
				if (bmp.name == "_unchangedOutline")
				{
					return;
				};
				bd = bmp.bitmapData;
				if (!bd || bd.width <= 0 || bd.height <= 0)
				{
					return;
				};
				maxPixels = bd.width * bd.height;
				if (maxPixels > 900000)
				{
					return;
				};
				if (maxPixels <= 180000)
				{
					fastColors = PaletteColorAnalysis.collectOpaqueColorsInBitmapData(bd, 1, 200);
					for each (fc in fastColors)
					{
						key = String(fc);
						if (!seen[key])
						{
							seen[key] = true;
							out.push(fc);
						};
					};
					return;
				};
				step = 2;
				y = 0;
				while (y < bd.height)
				{
					x = 0;
					while (x < bd.width)
					{
						px = bd.getPixel32(x, y);
						if (((px >> 24) & 0xFF) >= 200)
						{
							key = String(px);
							if (!seen[key])
							{
								seen[key] = true;
								out.push(px);
							};
						};
						x += step;
					};
					y += step;
				};
				return;
			};
			container = node as DisplayObjectContainer;
			if (!container)
			{
				return;
			};
			i = 0;
			while (i < container.numChildren)
			{
				collectOpaqueColorsDeepWalk(container.getChildAt(i), depth - 1, out, seen);
				i++;
			};
		}

		/**
		 * Current-frame stance/body bitmaps only. Timeline seeking is unsafe:
		 * nested clips run frame1() on spawn and throw outside try/catch.
		 */
		protected function scanCharacterRecolorColors(charMC:MovieClip):Array
		{
			var out:Array = [];
			var seen:Object = {};
			var stance:MovieClip;
			var target:MovieClip;
			if (!charMC)
			{
				return out;
			};
			try
			{
				Ssf2.Utils.removeActionScriptDeep(charMC, 12);
			}
			catch (stripErr:*)
			{
			};
			stance = (charMC.stance is MovieClip) ? MovieClip(charMC.stance) : null;
			target = stance ? stance : charMC;
			if (stance)
			{
				try
				{
					Ssf2.Utils.removeActionScriptDeep(stance, 12);
				}
				catch (stanceStripErr:*)
				{
				};
			};
			mergeDiscoveredColors(PaletteColorAnalysis.collectOpaqueColorsInMC(target, 2, -1, false), out, seen);
			return out;
		}

		/** Opaque colors from exported BitmapData/Bitmap symbols in the character SWF. */
		protected function scanCharacterDomainBitmapDataColors(charName:String):Array
		{
			var out:Array = [];
			var seen:Object = {};
			var seenBd:Dictionary = new Dictionary(true);
			var res:*;
			var domain:ApplicationDomain;
			var names:*;
			var name:String;
			var i:int;
			var cls:Class;
			var obj:*;
			var bd:BitmapData;
			var bmp:Bitmap;
			var colors:Array;
			try
			{
				res = PaletteMakerUtils.getCharacterResource(PaletteMakerUtils.getUniqueSpriteScanStatsName(charName), true);
			}
			catch (resErr:Error)
			{
				res = null;
			};
			if (!res || !res.MC || !res.MC.loaderInfo)
			{
				return out;
			};
			domain = res.MC.loaderInfo.applicationDomain;
			if (!domain || !domain.hasOwnProperty("getQualifiedDefinitionNames"))
			{
				return out;
			};
			try
			{
				names = domain["getQualifiedDefinitionNames"]();
			}
			catch (nameErr:Error)
			{
				return out;
			};
			if (!names)
			{
				return out;
			};
			i = 0;
			while (i < names.length)
			{
				name = String(names[i]);
				i++;
				// Timeline script packages (CharacterName_fla::...) are unsafe / useless.
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
				// Skip known giant FS form assets embedded in the same SWF (Giga Bowser, etc.).
				if (name.toLowerCase().indexOf("giga") != -1)
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
					obj = new cls();
				}
				catch (newErr:*)
				{
					continue;
				};
				bd = null;
				if (obj is BitmapData)
				{
					bd = obj as BitmapData;
				}
				else if (obj is Bitmap)
				{
					bmp = obj as Bitmap;
					bd = bmp ? bmp.bitmapData : null;
				}
				else
				{
					continue;
				};
				if (!bd || seenBd[bd] || bd.width * bd.height < 4)
				{
					continue;
				};
				// Bowser SWF embeds enormous Giga frames — full opaque scans OOMs / hang the editor.
				if ((bd.width * bd.height) > 350000)
				{
					continue;
				};
				seenBd[bd] = true;
				// minPixels=1 — projectile/unique sheets often have 1–2px pupils.
				colors = PaletteColorAnalysis.collectOpaqueColorsInBitmapData(bd, 1);
				mergeDiscoveredColors(colors, out, seen);
			};
			return out;
		}

		/** True when cls extends BitmapData or Bitmap — safe to new() without frame scripts. */
		protected function classIsBitmapAsset(cls:Class):Boolean
		{
			var t:String;
			var parentCls:Class;
			if (!cls)
			{
				return false;
			};
			try
			{
				t = getQualifiedSuperclassName(cls);
			}
			catch (err:Error)
			{
				return false;
			};
			if (!t)
			{
				return false;
			};
			if (t == "flash.display::BitmapData" || t == "flash.display::Bitmap"
				|| t == "flash.display.BitmapData" || t == "flash.display.Bitmap")
			{
				return true;
			};
			// One more parent level for uncommon BitmapData subclasses.
			try
			{
				parentCls = getDefinitionByName(t) as Class;
				if (!parentCls)
				{
					return false;
				};
				t = getQualifiedSuperclassName(parentCls);
				if (t == "flash.display::BitmapData" || t == "flash.display::Bitmap"
					|| t == "flash.display.BitmapData" || t == "flash.display.Bitmap")
				{
					return true;
				};
			}
			catch (parentErr:Error)
			{
			};
			return false;
		}

		protected function mergeDiscoveredColors(colors:Array, into:Array, seen:Object):void
		{
			var color:uint;
			if (!colors || !into || !seen)
			{
				return;
			};
			for each (color in colors)
			{
				if (!seen[color])
				{
					seen[color] = true;
					into.push(color);
				};
			};
		}

		protected function tryGetLibraryMC(linkage:String):MovieClip
		{
			var mc:MovieClip;
			if (!linkage)
			{
				return null;
			};
			try
			{
				mc = Ssf2.ResourceManager.getLibraryMC(linkage);
			}
			catch (err:Error)
			{
				mc = null;
			};
			if (!mc)
			{
				return null;
			};
			try
			{
				Ssf2.Utils.removeActionScriptDeep(mc, 12);
				mc.stop();
			}
			catch (stripErr:*)
			{
			};
			return mc;
		}

		protected function preparePortraitClip(mc:MovieClip):void
		{
			if (!mc)
			{
				return;
			};
			try { Ssf2.Utils.removeActionScriptDeep(mc, 12); } catch (e1:Error) {};
			try
			{
				if (mc.hasOwnProperty("stop")) mc.stop();
			}
			catch (e2:Error) {};
			try
			{
				if (mc.hasOwnProperty("gotoAndStop")) mc.gotoAndStop(1);
			}
			catch (e3:Error) {};
		}

		private function getPortraitPaintPaletteFor(formStatsName:String, swap:Object, swapPA:Object):Object
		{
			if (PaletteMakerUtils.shouldCombineFormPalette(formStatsName))
			{
				return Ssf2.Utils.combinePaletteBlocks(swap, swapPA);
			};
			return swapPA;
		}

		protected function applyLinkedPortraitPalettes(swap:Object, swapPA:Object):void
		{
			var partner:String;
			var partnerCostume:Object;
			var idx:int;
			if (PixelArt)
			{
				paintPortraitPartsForSheet([PixelArt], swap, swapPA, statsName);
			};
			if (PaletteMakerUtils.isLinkedFormPair(statsName) && PixelArtPartner)
			{
				partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
				partnerCostume = null;
				idx = -1;
				try
				{
					if (Ssf2.MenuController.costumeSelectorDisplay)
					{
						idx = int(Ssf2.MenuController.costumeSelectorDisplay.getSelectedCostume());
					};
					if (partner && idx >= 0)
					{
						partnerCostume = Ssf2.ResourceManager.getCostume(partner, null, idx);
					};
				}
				catch (partnerPaintErr:Error)
				{
					partnerCostume = null;
				};
				if (partnerCostume && PaletteMakerUtils.isCustomCostume(partnerCostume))
				{
					paintPortraitPartsForSheet(
						[PixelArtPartner],
						normalizePaletteBlock(partnerCostume.paletteSwap),
						normalizePaletteBlock(partnerCostume.paletteSwapPA),
						partner);
				}
				else
				{
					// Partner slot is stock/default — leave authored portrait colors.
					paintPortraitPartsForSheet([PixelArtPartner], null, null, partner);
				};
			};
		}

		/** Live PA path for arbitrary portrait DisplayObjects (EC + stock batch). */
		protected function paintPortraitPartsForSheet(portraits:Array, swap:Object, swapPA:Object, formStatsName:String):void
		{
			var paint:Object;
			var root:DisplayObject;
			paint = getPortraitPaintPaletteFor(formStatsName, swap, swapPA);
			if (!paint || !portraits)
			{
				return;
			};
			for each (root in portraits)
			{
				if (root)
				{
					paintPortraitBitmaps(root, paint);
				};
			};
		}

		/**
		 * Deep bitmap palette paint (Sprite nesting included). Ssf2.Utils.replacePalette only
		 * recurses MovieClips, so Sheik/Zelda trophies nested under Sprites never recolored.
		 * Uses exact ARGB (vanilla CSS), not rgbOnly.
		 */
		/** Remember the bitmap a full paint just showed, so hover can dim it without rebuilding the palette. */
		protected function noteHoverBright(bmp:Bitmap):void
		{
			var current:BitmapData;
			var prev:BitmapData;
			var dim:BitmapData;
			if (!bmp || !bmp.bitmapData)
			{
				return;
			};
			current = bmp.bitmapData;
			dim = hoverDim[bmp] as BitmapData;
			if (dim && current == dim)
			{
				return;
			};
			prev = hoverBright[bmp] as BitmapData;
			if (prev && prev != current)
			{
				prev.dispose();
			};
			hoverBright[bmp] = current;
		}

		/** Put the bright bitmap back on every display Bitmap hover had dimmed. */
		protected function restoreHoverBright():void
		{
			var key:*;
			var bmp:Bitmap;
			var bright:BitmapData;
			for (key in hoverBright)
			{
				bmp = key as Bitmap;
				bright = hoverBright[key] as BitmapData;
				if (bmp && bright)
				{
					bmp.bitmapData = bright;
				};
			};
		}

		protected function clearHoverDimBuffers():void
		{
			var key:*;
			var dim:BitmapData;
			restoreHoverBright();
			for (key in hoverDim)
			{
				dim = hoverDim[key] as BitmapData;
				if (dim)
				{
					dim.dispose();
				};
			};
			hoverDim = new Dictionary(true);
			hoverBright = new Dictionary(true);
		}

		/** Dim every pixel except the hovered replacement. */
		protected function dimCachedBitmap(bmp:Bitmap, repl:uint, repl2:uint, restore:Boolean):void
		{
			var bright:BitmapData;
			var dim:BitmapData;
			if (!bmp)
			{
				return;
			};
			bright = hoverBright[bmp] as BitmapData;
			if (!bright)
			{
				return;
			};
			dim = hoverDim[bmp] as BitmapData;
			if (!dim || dim.width != bright.width || dim.height != bright.height)
			{
				if (dim)
				{
					dim.dispose();
				};
				dim = new BitmapData(bright.width, bright.height, true, 0);
				hoverDim[bmp] = dim;
			};
			HoverDim.paint(dim, bright, repl, repl2, restore);
			bmp.bitmapData = dim;
		}

		protected function dimCachedTree(root:DisplayObject, repl:uint, repl2:uint, restore:Boolean, depth:int):void
		{
			var container:DisplayObjectContainer;
			var i:int;
			if (!root || depth < 0)
			{
				return;
			};
			if (root is Bitmap)
			{
				dimCachedBitmap(root as Bitmap, repl, repl2, restore);
				return;
			};
			container = root as DisplayObjectContainer;
			if (!container)
			{
				return;
			};
			i = 0;
			while (i < container.numChildren)
			{
				dimCachedTree(container.getChildAt(i), repl, repl2, restore, depth - 1);
				i++;
			};
		}

		private function paintPortraitBitmaps(root:DisplayObject, paletteData:Object):void
		{
			var cache:Dictionary;
			if (!root || !paletteData)
			{
				return;
			};
			restoreHoverBright();
			cache = portraitBitmapCaches[root] as Dictionary;
			if (!cache)
			{
				cache = new Dictionary(true);
				portraitBitmapCaches[root] = cache;
			};
			paintPortraitBitmapsWalk(root, paletteData, cache, 16);
		}

		private function paintPortraitBitmapsWalk(node:DisplayObject, paletteData:Object, cache:Dictionary, depth:int):void
		{
			var bmp:Bitmap;
			var bd:BitmapData;
			var original:BitmapData;
			var container:DisplayObjectContainer;
			var i:int;
			if (!node || depth < 0)
			{
				return;
			};
			if (node is Bitmap)
			{
				bmp = node as Bitmap;
				bd = bmp.bitmapData;
				if (!bd)
				{
					return;
				};
				original = cache[bmp] as BitmapData;
				if (!original)
				{
					original = bd.clone();
					cache[bmp] = original;
				}
				else
				{
					bd.lock();
					bd.fillRect(bd.rect, 0);
					bd.draw(original);
					bd.unlock();
				};
				PaletteDeep.replacePaletteHelper(bd, paletteData, false);
				noteHoverBright(bmp);
				return;
			};
			container = node as DisplayObjectContainer;
			if (!container)
			{
				return;
			};
			i = 0;
			while (i < container.numChildren)
			{
				paintPortraitBitmapsWalk(container.getChildAt(i), paletteData, cache, depth - 1);
				i++;
			};
		}

		protected function normalizePaletteBlock(block:Object):Object
		{
			if (!block) return { colors: [], replacements: [] };
			var colors:Array = (block.colors is Array) ? block.colors : [];
			var repls:Array  = (block.replacements is Array) ? block.replacements : [];
			var n:int = Math.min(colors.length, repls.length);
			var outColors:Array = [];
			var outRepls:Array  = [];
			for(var i:int = 0; i < n; i++)
			{
				outColors.push(PaletteMakerUtils.coerceColorValue(colors[i]));
				outRepls.push(PaletteMakerUtils.coerceColorValue(repls[i]));
			};
			if(colors.length > repls.length)
			{
				for (var j:int = repls.length; j < colors.length; j++)
				{
					outColors.push(PaletteMakerUtils.coerceColorValue(colors[j]));
					outRepls.push(PaletteMakerUtils.coerceColorValue(colors[j]));
				};
			};
			if(repls.length > colors.length)
			{
				for (var k:int = colors.length; k < repls.length; k++)
				{
					outColors.push(PaletteMakerUtils.coerceColorValue(repls[k]));
					outRepls.push(PaletteMakerUtils.coerceColorValue(repls[k]));
				};
			};
			return {colors:outColors, replacements:outRepls};
		}

		protected function clonePaletteSnapshot(paletteData:Object):Object
		{
			var cloned:Object;
			if (!paletteData)
			{
				return null;
			};
			cloned = PaletteMakerUtils.repairCostumeData(Ssf2.Utils.cloneObject(paletteData));
			cloned.paletteSwap = normalizePaletteBlock(cloned.paletteSwap);
			cloned.paletteSwapPA = normalizePaletteBlock(cloned.paletteSwapPA);
			cloned.paletteSwapFX = normalizePaletteBlock(cloned.paletteSwapFX);
			return cloned;
		}

		protected function mixColorPairs(colors:Array, replacements:Array):Array
		{
			var result:Array = [];
			for (var i:int = 0; i < colors.length; i++)
			{
				result.push({color:colors[i], replacement:replacements[i]});
			};
			return result;
		}
    }
}
