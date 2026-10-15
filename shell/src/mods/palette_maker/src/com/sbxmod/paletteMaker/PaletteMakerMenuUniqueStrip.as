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

    /** Unique PA sprite strip: layout, scroll, fit and repaint. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuUniqueStrip extends PaletteMakerMenuSprites
    {
        public function PaletteMakerMenuUniqueStrip()
        {
            super();
        }

		protected var PAContainer:MovieClip;

		private static const UNIQUE_SPRITE_GAP:Number = 4;

		private static const UNIQUE_VISIBLE_ROWS:int = 3;

		private static const UNIQUE_SCROLLBAR_WIDTH:Number = 18;

		/** Debounce unique-strip paint while dragging sliders / after hover churn. */
		internal static const UNIQUE_PAINT_DEBOUNCE_MS:int = 75;

		/** Gap between unique pack area and portrait (scrollbar sits in between). */
		private static const UNIQUE_PORTRAIT_GAP:Number = 6;

		protected var uniquePaintDebounceAt:int = 0;

		protected var uniquePaintDebouncePending:Boolean = false;

		protected var uniquePaintDebounceSwap:Object = null;

		protected var uniquePaintDebounceSwapPA:Object = null;

		protected var uniquePaSprites:Array = [];

		protected var uniquePaHost:Sprite = null;

		/** Holds unique sprites; host.mask cannot be shared per-sprite in AS3, so mask this instead. */
		protected var uniquePaContent:Sprite = null;

		protected var uniquePaCoverCache:Array = null;

		/** RE toolbar: effect-strip gallery + fxGroups (color + HSBC per group). */
		protected var recolorEffectsMode:Boolean = false;

		protected var uniquePaScrollRow:int = 0;

		protected var uniquePaMask:Sprite = null;

		protected var uniquePaScrollBar:Sprite = null;

		protected var uniquePaScrollThumb:Sprite = null;

		private var uniquePaScrollDragging:Boolean = false;

		private var uniquePaScrollDragOffset:Number = 0;

		protected var uniquePaRowCount:int = 0;

		/** Fixed scrollbar / mask height for the 3-row viewport (independent of scroll position). */
		protected var uniquePaFixedTrackH:Number = 24;

		/** Opaque colors across all unique-sprite cover bitmaps / MCs (min 1 pixel). */
		protected function collectAllUniqueCoverColors():Array
		{
			var out:Array = [];
			var seen:Object = {};
			var cand:Object;
			var colors:Array;
			var color:uint;
			var mc:MovieClip;
			if (!uniquePaCoverCache)
			{
				return out;
			};
			for each (cand in uniquePaCoverCache)
			{
				if (!cand)
				{
					continue;
				};
				colors = null;
				if (cand.bitmapData is BitmapData)
				{
					colors = PaletteColorAnalysis.collectOpaqueColorsInBitmapData(cand.bitmapData as BitmapData, 1);
				}
				else
				{
					mc = tryResolveUniqueCoverMovieClip(cand);
					if (mc)
					{
						colors = PaletteColorAnalysis.collectOpaqueColorsInMC(mc, 4, 1, false);
					};
				};
				if (!colors)
				{
					continue;
				};
				for each (color in colors)
				{
					if (!seen[String(uint(color))])
					{
						seen[String(uint(color))] = true;
						out.push(uint(color));
					};
				};
			};
			return out;
		}

		/** Best-effort MC from a unique cover candidate (live sprite or linkage). */
		protected function tryResolveUniqueCoverMovieClip(cand:Object):MovieClip
		{
			var i:int;
			var root:DisplayObject;
			if (!cand)
			{
				return null;
			};
			if (cand.mc is MovieClip)
			{
				return cand.mc as MovieClip;
			};
			if (uniquePaSprites && uniquePaCoverCache)
			{
				i = 0;
				while (i < uniquePaCoverCache.length && i < uniquePaSprites.length)
				{
					if (uniquePaCoverCache[i] == cand)
					{
						root = uniquePaSprites[i] as DisplayObject;
						if (root is MovieClip)
						{
							return root as MovieClip;
						};
						break;
					};
					i++;
				};
			};
			if (cand.linkage)
			{
				return tryGetLibraryMC(String(cand.linkage));
			};
			return null;
		}

		/** If every replacement in the block is the same RGB, return it; else null. */
		protected function getUniformPaletteReplacement(block:Object):*
		{
			var i:int;
			var r:uint;
			var first:* = null;
			if (!block || !(block.replacements is Array) || block.replacements.length == 0)
			{
				return null;
			};
			i = 0;
			while (i < block.replacements.length)
			{
				r = uint(block.replacements[i]);
				if (first == null)
				{
					first = r;
				}
				else if (!PaletteColorAnalysis.colorsMatch(uint(first), r))
				{
					return null;
				};
				i++;
			};
			return first;
		}

		protected function syncSwatchIndicators(colors:Array, replacement:uint):void
		{
			var color:uint;
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			if (!colors || !m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			for each (color in colors)
			{
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
						if (uint(box.colorValue) == color)
						{
							box.updateIndicator(replacement);
							break;
						};
					};
					i++;
				};
			};
		}

		protected function mixedBaseHasColorMatch(color:uint):Boolean
		{
			var existing:*;
			var rgb:uint;
			rgb = uint(color) & 0x00FFFFFF;
			if (mixedBaseRgbSet)
			{
				return mixedBaseRgbSet[rgb] == true;
			};
			if (!mixedBasePaletteData)
			{
				return false;
			};
			for each (existing in mixedBasePaletteData)
			{
				if (PaletteColorAnalysis.colorsMatch(uint(existing), color))
				{
					return true;
				};
			};
			return false;
		}

		protected function paletteBlockHasExactColor(block:Object, color:uint):Boolean
		{
			var i:int;
			if (!block || !(block.colors is Array))
			{
				return false;
			};
			i = 0;
			while (i < block.colors.length)
			{
				if (uint(block.colors[i]) == color)
				{
					return true;
				};
				i++;
			};
			return false;
		}

		protected function ensurePaletteBlocks(costume:Object):void
		{
			if (!costume)
			{
				return;
			};
			if (!costume.paletteSwap)
			{
				costume.paletteSwap = { colors: [], replacements: [] };
			};
			if (!(costume.paletteSwap.colors is Array))
			{
				costume.paletteSwap.colors = [];
			};
			if (!(costume.paletteSwap.replacements is Array))
			{
				costume.paletteSwap.replacements = [];
			};
			if (!costume.paletteSwapPA)
			{
				costume.paletteSwapPA = { colors: [], replacements: [] };
			};
			if (!(costume.paletteSwapPA.colors is Array))
			{
				costume.paletteSwapPA.colors = [];
			};
			if (!(costume.paletteSwapPA.replacements is Array))
			{
				costume.paletteSwapPA.replacements = [];
			};
			if (!costume.paletteSwapFX)
			{
				costume.paletteSwapFX = { colors: [], replacements: [] };
			};
			if (!(costume.paletteSwapFX.colors is Array))
			{
				costume.paletteSwapFX.colors = [];
			};
			if (!(costume.paletteSwapFX.replacements is Array))
			{
				costume.paletteSwapFX.replacements = [];
			};
		}

		/** Gap between unique-sprite content boxes. */
		/** On-screen opaque max side above this → treat as large and halvescale. */
		private static const UNIQUE_PA_LARGE_SIDE:Number = 48;

		/** Hard cap for RE effect-strip cells so tall beams cannot blow layout/highlights. */
		internal static const UNIQUE_FX_CELL_MAX:Number = 40;

		/**
		 * Pack unique sprites under the Back button by each sprite's opaque bounds.
		 * Rows fill available width up to (fixed scrollbar | portrait); 3 rows visible.
		 */
		protected function layoutAllUniquePaSprites(paBounds:Rectangle):void
		{
			var i:int;
			var total:int;
			var gap:Number = UNIQUE_SPRITE_GAP;
			var disp:DisplayObject;
			var cand:Object;
			var sizes:Array;
			var sizeObj:Object;
			var row:int;
			var maxScroll:int;
			var visible:Boolean;
			var rowX:Number;
			var rowY:Number;
			var rowH:Number;
			var itemsInRow:int;
			var currentRow:int;
			var rowHeights:Array;
			var scrollOffsetY:Number;
			var viewH:Number;
			var packMaxW:Number;
			var scrollTrackX:Number;
			var r:int;
			var start:int;
			var windowH:Number;
			total = uniquePaSprites ? uniquePaSprites.length : 0;
			if (total <= 0 || !uniquePaHost)
			{
				return;
			};
			packMaxW = getUniqueSpritePackMaxWidth();
			scrollTrackX = packMaxW + 2;
			sizes = [];
			i = 0;
			while (i < total)
			{
				disp = uniquePaSprites[i] as DisplayObject;
				cand = (uniquePaCoverCache && i < uniquePaCoverCache.length) ? uniquePaCoverCache[i] : null;
				disp.x = 0;
				disp.y = 0;
				sizeObj = measureUniqueSpritePackSize(disp, cand);
				sizes.push(sizeObj);
				i++;
			};
			// Pack left→right; wrap when the next opaque box would pass the portrait scrollbar.
			rowX = 0;
			rowY = 0;
			rowH = 0;
			itemsInRow = 0;
			currentRow = 0;
			rowHeights = [];
			i = 0;
			while (i < total)
			{
				sizeObj = sizes[i];
				if (itemsInRow > 0 && (rowX + sizeObj.w) > packMaxW)
				{
					rowHeights.push(rowH);
					rowY += rowH + gap;
					rowX = 0;
					rowH = 0;
					itemsInRow = 0;
					currentRow++;
				};
				sizeObj.packX = rowX;
				sizeObj.packY = rowY;
				sizeObj.row = currentRow;
				rowX += sizeObj.w + gap;
				if (sizeObj.h > rowH)
				{
					rowH = sizeObj.h;
				};
				itemsInRow++;
				i++;
			};
			if (itemsInRow > 0)
			{
				rowHeights.push(rowH);
			};
			uniquePaRowCount = rowHeights.length;
			maxScroll = Math.max(0, uniquePaRowCount - UNIQUE_VISIBLE_ROWS);
			if (uniquePaScrollRow > maxScroll) uniquePaScrollRow = maxScroll;
			if (uniquePaScrollRow < 0) uniquePaScrollRow = 0;
			// Fixed track/mask height = tallest consecutive UNIQUE_VISIBLE_ROWS window.
			uniquePaFixedTrackH = 0;
			start = 0;
			while (start <= maxScroll)
			{
				windowH = 0;
				r = start;
				while (r < start + UNIQUE_VISIBLE_ROWS && r < rowHeights.length)
				{
					if (windowH > 0)
					{
						windowH += gap;
					};
					windowH += Number(rowHeights[r]);
					r++;
				};
				if (windowH > uniquePaFixedTrackH)
				{
					uniquePaFixedTrackH = windowH;
				};
				start++;
			};
			if (uniquePaFixedTrackH < 24)
			{
				uniquePaFixedTrackH = 24;
			};
			scrollOffsetY = 0;
			r = 0;
			while (r < uniquePaScrollRow && r < rowHeights.length)
			{
				scrollOffsetY += Number(rowHeights[r]) + gap;
				r++;
			};
			viewH = uniquePaFixedTrackH;
			ensureUniquePaMaskRect(packMaxW, viewH);
			i = 0;
			while (i < total)
			{
				disp = uniquePaSprites[i] as DisplayObject;
				sizeObj = sizes[i];
				row = int(sizeObj.row);
				// Top-left align opaque bounds into the pack cell (avoids center-overflow crop).
				disp.x = sizeObj.packX - sizeObj.ox;
				disp.y = (sizeObj.packY - scrollOffsetY) - sizeObj.oy;
				visible = (row >= uniquePaScrollRow) && (row < uniquePaScrollRow + UNIQUE_VISIBLE_ROWS);
				disp.visible = visible;
				disp.mask = null;
				i++;
			};
			// One mask on the content container (AS3 cannot share one mask across many sprites).
			if (uniquePaContent)
			{
				uniquePaContent.mask = uniquePaMask;
			};
			// Scrollbar X always at portrait rail (even when hidden / unused).
			updateUniquePaScrollbar(scrollTrackX, uniquePaFixedTrackH, 0);
		}

		/**
		 * Stage X of the portrait art's leftmost opaque pixels (fallback: PAContainer origin).
		 */
		private function getPortraitArtLeftStageX():Number
		{
			var bmp:Bitmap;
			var opaque:Rectangle;
			var bb:Rectangle;
			var stageRef:DisplayObject;
			if (!Ssf2.Main.Root || !Ssf2.Main.Root.stage)
			{
				return Ssf2.Main.Width * 0.40;
			};
			stageRef = Ssf2.Main.Root.stage;
			try
			{
				if (PixelArt)
				{
					bmp = findFirstBitmapInDisplay(PixelArt);
					if (bmp && bmp.bitmapData)
					{
						opaque = bmp.bitmapData.getColorBoundsRect(0xFF000000, 0x00000000, false);
						if (opaque && opaque.width > 0 && opaque.height > 0)
						{
							return bmp.localToGlobal(new Point(opaque.left, opaque.top)).x;
						};
					};
					bb = PixelArt.getBounds(stageRef);
					if (bb && bb.width > 0 && !isNaN(bb.left))
					{
						return bb.left;
					};
				};
				if (PAContainer)
				{
					return PAContainer.localToGlobal(new Point(0, 0)).x;
				};
			}
			catch (err:Error)
			{
			};
			return Ssf2.Main.Width * 0.40;
		}

		/**
		 * Pack width in uniquePaHost local space: host origin → left of portrait,
		 * always reserving the scrollbar rail. Hard-capped so a bad measure cannot
		 * push the rail past mid-screen / into the control panel.
		 */
		private function getUniqueSpritePackMaxWidth():Number
		{
			var leftStage:Number;
			var hostOriginStage:Number;
			var maxW:Number;
			var hardCap:Number;
			if (!uniquePaHost)
			{
				return 160;
			};
			leftStage = getPortraitArtLeftStageX();
			hostOriginStage = uniquePaHost.localToGlobal(new Point(0, 0)).x;
			maxW = leftStage - hostOriginStage - UNIQUE_SCROLLBAR_WIDTH - UNIQUE_PORTRAIT_GAP;
			hardCap = (Ssf2.Main.Width * 0.46) - hostOriginStage - UNIQUE_SCROLLBAR_WIDTH - UNIQUE_PORTRAIT_GAP;
			if (hardCap < 80)
			{
				hardCap = 80;
			};
			if (maxW > hardCap)
			{
				maxW = hardCap;
			};
			if (maxW < 48)
			{
				maxW = 48;
			};
			return maxW;
		}

		private function ensureUniquePaMaskRect(w:Number, h:Number):void
		{
			if (!uniquePaHost)
			{
				return;
			};
			if (!uniquePaMask)
			{
				uniquePaMask = new Sprite();
				uniquePaMask.mouseEnabled = false;
				uniquePaMask.mouseChildren = false;
				uniquePaHost.addChildAt(uniquePaMask, 0);
			};
			if (w < 8) w = 8;
			if (h < 8) h = 8;
			uniquePaMask.graphics.clear();
			uniquePaMask.graphics.beginFill(0xFFFFFF, 1);
			uniquePaMask.graphics.drawRect(0, 0, w, h);
			uniquePaMask.graphics.endFill();
			if (uniquePaContent)
			{
				uniquePaContent.mask = uniquePaMask;
			};
		}

		private function updateUniquePaScrollbar(trackX:Number, trackH:Number, rowPitch:Number):void
		{
			var maxScroll:int;
			var thumbH:Number;
			var thumbY:Number;
			var ratio:Number;
			if (!uniquePaHost)
			{
				return;
			};
			maxScroll = Math.max(0, uniquePaRowCount - UNIQUE_VISIBLE_ROWS);
			if (!uniquePaScrollBar)
			{
				uniquePaScrollBar = new Sprite();
				uniquePaScrollBar.buttonMode = true;
				uniquePaScrollBar.useHandCursor = true;
				uniquePaScrollThumb = new Sprite();
				uniquePaScrollThumb.buttonMode = true;
				uniquePaScrollThumb.useHandCursor = true;
				uniquePaScrollBar.addChild(uniquePaScrollThumb);
				uniquePaScrollBar.addEventListener(MouseEvent.MOUSE_DOWN, onUniquePaScrollTrackDown);
				uniquePaScrollThumb.addEventListener(MouseEvent.MOUSE_DOWN, onUniquePaScrollThumbDown);
				uniquePaHost.addChild(uniquePaScrollBar);
			};
			uniquePaScrollBar.x = trackX;
			uniquePaScrollBar.y = 0;
			uniquePaScrollBar.graphics.clear();
			uniquePaScrollBar.graphics.beginFill(0x2A2A33, 0.95);
			uniquePaScrollBar.graphics.lineStyle(1, 0x666677, 1);
			uniquePaScrollBar.graphics.drawRoundRect(0, 0, UNIQUE_SCROLLBAR_WIDTH, trackH, 6, 6);
			uniquePaScrollBar.graphics.endFill();
			uniquePaScrollBar.visible = maxScroll > 0;
			if (maxScroll <= 0)
			{
				uniquePaScrollThumb.graphics.clear();
				return;
			};
			ratio = UNIQUE_VISIBLE_ROWS / Number(uniquePaRowCount);
			thumbH = Math.max(24, trackH * ratio);
			thumbY = (uniquePaScrollRow / Number(maxScroll)) * (trackH - thumbH);
			uniquePaScrollThumb.graphics.clear();
			uniquePaScrollThumb.graphics.beginFill(0x8899AA, 1);
			uniquePaScrollThumb.graphics.drawRoundRect(2, 0, UNIQUE_SCROLLBAR_WIDTH - 4, thumbH, 6, 6);
			uniquePaScrollThumb.graphics.endFill();
			uniquePaScrollThumb.y = thumbY;
			uniquePaHost.addChild(uniquePaScrollBar);
		}

		protected function onUniquePaMouseWheel(e:MouseEvent):void
		{
			var maxScroll:int = Math.max(0, uniquePaRowCount - UNIQUE_VISIBLE_ROWS);
			if (maxScroll <= 0)
			{
				return;
			};
			if (e.delta > 0)
			{
				uniquePaScrollRow = Math.max(0, uniquePaScrollRow - 1);
			}
			else
			{
				uniquePaScrollRow = Math.min(maxScroll, uniquePaScrollRow + 1);
			};
			layoutAllUniquePaSprites(null);
			e.stopPropagation();
		}

		private function onUniquePaScrollTrackDown(e:MouseEvent):void
		{
			var trackH:Number;
			var maxScroll:int;
			if (e.target == uniquePaScrollThumb || !uniquePaScrollBar)
			{
				return;
			};
			trackH = uniquePaFixedTrackH > 0 ? uniquePaFixedTrackH : (uniquePaScrollBar.height > 0 ? uniquePaScrollBar.height : 1);
			maxScroll = Math.max(0, uniquePaRowCount - UNIQUE_VISIBLE_ROWS);
			uniquePaScrollRow = int(Math.round((uniquePaScrollBar.mouseY / trackH) * maxScroll));
			if (uniquePaScrollRow < 0) uniquePaScrollRow = 0;
			if (uniquePaScrollRow > maxScroll) uniquePaScrollRow = maxScroll;
			layoutAllUniquePaSprites(null);
		}

		private function onUniquePaScrollThumbDown(e:MouseEvent):void
		{
			uniquePaScrollDragging = true;
			uniquePaScrollDragOffset = uniquePaScrollThumb.mouseY;
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_MOVE, onUniquePaScrollThumbMove, false, 0, true);
				Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_UP, onUniquePaScrollThumbUp, false, 0, true);
			};
			e.stopPropagation();
		}

		private function onUniquePaScrollThumbMove(e:MouseEvent):void
		{
			var trackH:Number;
			var thumbH:Number;
			var maxScroll:int;
			var y:Number;
			if (!uniquePaScrollDragging || !uniquePaScrollBar)
			{
				return;
			};
			trackH = uniquePaFixedTrackH > 0 ? uniquePaFixedTrackH : (uniquePaScrollBar.height > 0 ? uniquePaScrollBar.height : 1);
			thumbH = uniquePaScrollThumb.height > 0 ? uniquePaScrollThumb.height : 24;
			maxScroll = Math.max(0, uniquePaRowCount - UNIQUE_VISIBLE_ROWS);
			y = uniquePaScrollBar.mouseY - uniquePaScrollDragOffset;
			if (y < 0) y = 0;
			if (y > trackH - thumbH) y = trackH - thumbH;
			uniquePaScrollRow = (trackH - thumbH) > 0
				? int(Math.round((y / (trackH - thumbH)) * maxScroll))
				: 0;
			layoutAllUniquePaSprites(null);
		}

		private function onUniquePaScrollThumbUp(e:MouseEvent):void
		{
			uniquePaScrollDragging = false;
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onUniquePaScrollThumbMove);
				Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_UP, onUniquePaScrollThumbUp);
			};
		}

		/**
		 * Opaque content size and top-left (ox/oy) in uniquePaHost space (disp at 0,0).
		 * Trims transparent padding from BitmapData so empty SWF canvases don't create huge gaps.
		 */
		private function measureUniqueSpritePackSize(disp:DisplayObject, cand:Object):Object
		{
			var bmp:Bitmap;
			var bd:BitmapData;
			var opaque:Rectangle;
			var tl:Point;
			var br:Point;
			var bb:Rectangle;
			var w:Number;
			var h:Number;
			var fallback:Object = {"w": 16, "h": 16, "ox": 0, "oy": 0, "packX": 0, "packY": 0, "row": 0};
			if (!disp)
			{
				return fallback;
			};
			bmp = findFirstBitmapInDisplay(disp);
			if (bmp && bmp.bitmapData)
			{
				bd = bmp.bitmapData;
				try
				{
					opaque = bd.getColorBoundsRect(0xFF000000, 0x00000000, false);
				}
				catch (err:Error)
				{
					opaque = null;
				};
				if (opaque && opaque.width > 0 && opaque.height > 0)
				{
					tl = uniquePaHost.globalToLocal(bmp.localToGlobal(new Point(opaque.left, opaque.top)));
					br = uniquePaHost.globalToLocal(bmp.localToGlobal(new Point(opaque.right, opaque.bottom)));
					w = Math.abs(br.x - tl.x);
					h = Math.abs(br.y - tl.y);
					if (w >= 1 && h >= 1)
					{
						if (recolorEffectsMode)
						{
							if (w > UNIQUE_FX_CELL_MAX) w = UNIQUE_FX_CELL_MAX;
							if (h > UNIQUE_FX_CELL_MAX) h = UNIQUE_FX_CELL_MAX;
						};
						return {
							"w": w,
							"h": h,
							"ox": Math.min(tl.x, br.x),
							"oy": Math.min(tl.y, br.y),
							"packX": 0,
							"packY": 0,
							"row": 0
						};
					};
				};
				bb = bmp.getBounds(uniquePaHost);
				if (bb && bb.width > 0 && bb.height > 0)
				{
					w = bb.width;
					h = bb.height;
					if (recolorEffectsMode)
					{
						if (w > UNIQUE_FX_CELL_MAX) w = UNIQUE_FX_CELL_MAX;
						if (h > UNIQUE_FX_CELL_MAX) h = UNIQUE_FX_CELL_MAX;
					};
					return {
						"w": w,
						"h": h,
						"ox": bb.x,
						"oy": bb.y,
						"packX": 0,
						"packY": 0,
						"row": 0
					};
				};
			};
			bb = disp.getBounds(uniquePaHost);
			if (bb && bb.width > 0 && bb.height > 0)
			{
				w = bb.width;
				h = bb.height;
				if (recolorEffectsMode)
				{
					if (w > UNIQUE_FX_CELL_MAX) w = UNIQUE_FX_CELL_MAX;
					if (h > UNIQUE_FX_CELL_MAX) h = UNIQUE_FX_CELL_MAX;
				};
				return {
					"w": w,
					"h": h,
					"ox": bb.x,
					"oy": bb.y,
					"packX": 0,
					"packY": 0,
					"row": 0
				};
			};
			return fallback;
		}

		/** Same on-screen pixel scale as portrait art (PAContainer). */
		private function getPortraitArtScale():Number
		{
			var s:Number = 0.598;
			try
			{
				if (PAContainer && Math.abs(PAContainer.scaleX) > 0.01)
				{
					s = Math.abs(PAContainer.scaleX);
				};
			}
			catch (err:Error)
			{
			};
			return s;
		}

		protected function fitUniquePaSprite(disp:DisplayObject, cand:Object, maxSize:Number=0):void
		{
			var scale:Number;
			var bmp:Bitmap;
			var opaque:Rectangle;
			var side:Number;
			var maxSide:Number;
			var bw:Number;
			var bh:Number;
			if (!disp)
			{
				return;
			};
			setBitmapSmoothingDeep(disp, false);
			scale = getPortraitArtScale() * 1.2;
			if (cand && cand.kind == "stock")
			{
				scale = getPortraitArtScale() * 1.15 * 1.2;
			};
			bmp = findFirstBitmapInDisplay(disp);
			if (bmp && bmp.bitmapData)
			{
				try
				{
					opaque = bmp.bitmapData.getColorBoundsRect(0xFF000000, 0x00000000, false);
				}
				catch (err:Error)
				{
					opaque = null;
				};
				if (opaque && opaque.width > 0 && opaque.height > 0)
				{
					bw = opaque.width;
					bh = opaque.height;
					side = Math.max(bw, bh) * scale;
					if (side > UNIQUE_PA_LARGE_SIDE)
					{
						scale *= 0.5;
						side = Math.max(bw, bh) * scale;
					};
					// RE strip: force into a fixed cell so tall beams cannot dominate.
					maxSide = recolorEffectsMode ? UNIQUE_FX_CELL_MAX : 0;
					if (maxSize > 0)
					{
						maxSide = maxSize;
					};
					if (maxSide > 0 && side > maxSide)
					{
						scale *= (maxSide / side);
					};
				};
			}
			else if (recolorEffectsMode)
			{
				try
				{
					bw = Math.abs(disp.width);
					bh = Math.abs(disp.height);
					side = Math.max(bw, bh);
					if (side > UNIQUE_FX_CELL_MAX && side > 0)
					{
						scale = UNIQUE_FX_CELL_MAX / side;
					};
				}
				catch (szErr:Error)
				{
				};
			};
			disp.scaleX = scale;
			disp.scaleY = scale;
		}

		protected function findFirstBitmapInDisplay(root:DisplayObject):Bitmap
		{
			var container:DisplayObjectContainer;
			var i:int;
			var child:DisplayObject;
			var nested:Bitmap;
			if (root is Bitmap)
			{
				return root as Bitmap;
			};
			container = root as DisplayObjectContainer;
			if (!container)
			{
				return null;
			};
			i = 0;
			while (i < container.numChildren)
			{
				child = container.getChildAt(i);
				if (child is Bitmap)
				{
					return child as Bitmap;
				};
				nested = findFirstBitmapInDisplay(child);
				if (nested)
				{
					return nested;
				};
				i++;
			};
			return null;
		}

		private function setBitmapSmoothingDeep(root:DisplayObject, smoothing:Boolean):void
		{
			var container:DisplayObjectContainer;
			var i:int;
			var child:DisplayObject;
			var bmp:Bitmap;
			if (root is Bitmap)
			{
				bmp = root as Bitmap;
				bmp.smoothing = smoothing;
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
				child = container.getChildAt(i);
				setBitmapSmoothingDeep(child, smoothing);
				i++;
			};
		}

		protected function scheduleDebouncedUniquePaint(swap:Object, swapPA:Object):void
		{
			uniquePaintDebounceSwap = swap;
			uniquePaintDebounceSwapPA = swapPA;
			uniquePaintDebounceAt = getTimer() + UNIQUE_PAINT_DEBOUNCE_MS;
			uniquePaintDebouncePending = true;
		}

		/**
		 * Live unique-sprite paint (bitmap clone + replacePaletteHelper, stance/PA/MC branches).
		 * Shared by the editor strip and color-sheet EC / Ctrl+Shift+C exporters.
		 */
		protected function paintUniqueSpritesForSheet(sprites:Array, coverCache:Array, formStatsName:String,
			paletteData:Object, swapOverride:Object=null, swapPAOverride:Object=null, useIsolate:Boolean=false):void
		{
			var i:int;
			var cand:Object;
			var mc:MovieClip;
			var target:MovieClip;
			var swap:Object;
			var holder:Sprite;
			var bmp:Bitmap;
			var bd:BitmapData;
			var bodySwap:Object;
			var paSwap:Object;
			if (!sprites || !coverCache || !paletteData)
			{
				return;
			};
			bodySwap = paletteData.paletteSwap;
			paSwap = paletteData.paletteSwapPA;
			i = 0;
			while (i < sprites.length && i < coverCache.length)
			{
				cand = coverCache[i];
				if (!cand)
				{
					i++;
					continue;
				};
				if (cand.kind == "bitmap")
				{
					holder = sprites[i] as Sprite;
					if (holder && holder.numChildren > 0)
					{
						bmp = holder.getChildAt(0) as Bitmap;
						if (bmp && cand.bitmapData is BitmapData)
						{
							try
							{
								bd = (cand.bitmapData as BitmapData).clone();
								if (cand.isPA)
								{
									swap = swapPAOverride != null
										? swapPAOverride
										: (useIsolate ? buildIsolatedPalette(paSwap) : paSwap);
									if (PaletteMakerUtils.shouldCombineFormPalette(formStatsName))
									{
										swap = Ssf2.Utils.combinePaletteBlocks(
											swapOverride != null ? swapOverride : bodySwap,
											swap);
									};
								}
								else
								{
									swap = swapOverride != null
										? swapOverride
										: (useIsolate ? buildIsolatedPalette(bodySwap) : bodySwap);
								};
								if (swap)
								{
									PaletteDeep.replacePaletteHelper(bd, swap, false);
								};
								bmp.bitmapData = bd;
							}
							catch (bmpErr:Error)
							{
							};
						};
					};
					i++;
					continue;
				};
				mc = sprites[i] as MovieClip;
				if (!mc)
				{
					i++;
					continue;
				};
				if (cand.kind == "stance" || cand.kind == "anim")
				{
					target = (mc.stance is MovieClip) ? MovieClip(mc.stance) : mc;
					swap = swapOverride != null
						? swapOverride
						: (useIsolate ? buildIsolatedPalette(bodySwap) : bodySwap);
					Ssf2.Utils.replacePalette(target, swap, 2, true);
				}
				else if (cand.kind == "charselect" || cand.kind == "trophy" || cand.isPA)
				{
					swap = swapPAOverride != null
						? swapPAOverride
						: (useIsolate ? buildIsolatedPalette(paSwap) : paSwap);
					if (PaletteMakerUtils.shouldCombineFormPalette(formStatsName))
					{
						swap = Ssf2.Utils.combinePaletteBlocks(
							swapOverride != null ? swapOverride : bodySwap,
							swap);
					};
					Ssf2.Utils.restoreDeepPaletteOriginals(mc);
					Ssf2.Utils.replacePaletteDeep(mc, swap, 12, true, false, false);
				}
				else
				{
					swap = swapOverride != null
						? swapOverride
						: (useIsolate ? buildIsolatedPalette(bodySwap) : bodySwap);
					Ssf2.Utils.replacePalette(mc, swap, 2, true);
				};
				i++;
			};
		}
    }
}
