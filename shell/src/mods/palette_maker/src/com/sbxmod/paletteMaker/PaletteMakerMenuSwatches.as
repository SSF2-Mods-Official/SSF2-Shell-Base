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

    /** Color sliders, swatch boxes layout and scroll, tool row. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuSwatches extends PaletteMakerMenuColorScan
    {
        public function PaletteMakerMenuSwatches()
        {
            super();
        }

		private const COLOR_BOX_PA_LIMIT:int = 20;

		protected var ENABLE_PIXEL_ART_LIVE_UPDATE:Boolean = false;

		/** Temporary: diagnose Mario (and others) where sliders skip swatches/paint. */
		private var sliderDebugLastNotifyMs:int = 0;

		private var sliderDebugLastStats:String = null;

		protected var copyToClipboardBtn:MovieClip;

		protected var importFromOnlineBtn:MovieClip;

		protected var groupSquares:Array = [];

		protected var activeGroup:PaletteGroupSquare = null;

		protected var colorRowCount:int = 0;

		protected var uiKeysFrozen:Boolean = false;

		protected var magnifierInputActive:Boolean = false;

		protected var characterFrozen:Boolean = false;

		protected var characterFreezeX:Number = 0;

		protected var characterFreezeY:Number = 0;

		protected var characterFreezeScale:Number = 1;

		private var freezeStudioDirWasDown:Boolean = false;

		private var freezeStudioRepeatFrames:int = 0;

		protected const BOX_SIZE:Number = 15;

		protected const BOX_POS_X:Number = 15;

		protected const BOX_POS_Y:Number = 17;

		protected const BOX_PER_ROW:int = 39;

		protected const BOX_OFFSET:Number = 0.9;

		/** How many swatch rows stay visible; the rest scroll. */
		internal static const VISIBLE_SWATCH_ROWS:int = 3;

		/** Wide easy-grab scrollbar next to swatches. */
		private static const SWATCH_SCROLLBAR_WIDTH:Number = 22;

		/** Gap under the action buttons before the swatch panel top. */
		private static const SWATCH_BELOW_BUTTONS_GAP:Number = 8;

		protected const MAG_REPEAT_DELAY:int = 14;

		protected const MAG_REPEAT_INTERVAL:int = 2;

		protected const TOOL_HINTS:Object = {
			"UD": "Undo",
			"RD": "Redo",
			"DI": "Isolate Mode",
			"FZ": "Freeze Character",
			"SA": "Select All",
			"DA": "Deselect All",
			"IS": "Invert Selection",
			"RA": "Reset Active",
			"RB": "Recolor to Base",
			"RO": "Recolor to OG",
			"NG": "New Group",
			"CS": "Color Settings",
			"ST": "Settings",
			"IC": "Import Color Sheet(s)",
			"EC": "Export Color Sheet",
			"CO": "Import Code",
			"RE": "Recolor Effects"
		};

		protected var toolHintText:TextField = null;

		protected var palettePADirty:Boolean = true;

		protected var characterPaletteDirty:Boolean = true;

		protected var swatchScrollRow:int = 0;

		protected var swatchMask:Sprite = null;

		protected var swatchScrollBar:Sprite = null;

		protected var swatchScrollThumb:Sprite = null;

		private var swatchScrollDragging:Boolean = false;

		private var swatchScrollDragOffset:Number = 0;

		protected var colorBoxBGStartY:Number;

		/**
		 * While frozen: L/R frame scrub; Attack+dirs move; Special+Up/Down scale.
		 */
		protected function handleFrozenStudioControls():void
		{
			var ctrl:*;
			var status:*;
			var pid:int;
			var dirDown:Boolean;
			var allowStep:Boolean;
			var attackHeld:Boolean;
			var specialHeld:Boolean;
			var step:Number;
			var frame:int;
			var total:int;
			var next:int;
			var scale:Number;
			if (!characterFrozen || uiKeysFrozen || !player || !Ssf2.GameController.stageData)
			{
				freezeStudioDirWasDown = false;
				freezeStudioRepeatFrames = 0;
				return;
			};
			ctrl = null;
			try
			{
				if (player.ControlSettings)
				{
					ctrl = player.ControlSettings;
				};
				if (!ctrl)
				{
					pid = player.ID ? int(player.ID) : 1;
					ctrl = Ssf2.GameController.stageData.getControllerNum(pid);
				};
				if (!ctrl)
				{
					ctrl = Ssf2.GameController.stageData.getControllerNum(1);
				};
			}
			catch (err:Error)
			{
				return;
			};
			if (!ctrl)
			{
				return;
			};
			status = ctrl.getControlStatus();
			if (!status)
			{
				return;
			};
			attackHeld = status.BUTTON2;
			specialHeld = status.BUTTON1;
			// Bare d-pad while magnifier is up belongs to the probe, not frame scrub.
			if (magnifierInputActive && !attackHeld && !specialHeld)
			{
				freezeStudioDirWasDown = status.LEFT || status.RIGHT || status.UP || status.DOWN;
				return;
			};
			dirDown = status.LEFT || status.RIGHT || status.UP || status.DOWN;
			allowStep = false;
			if (dirDown)
			{
				if (!freezeStudioDirWasDown)
				{
					allowStep = true;
					freezeStudioRepeatFrames = 0;
				}
				else
				{
					freezeStudioRepeatFrames++;
					if (freezeStudioRepeatFrames >= MAG_REPEAT_DELAY
						&& ((freezeStudioRepeatFrames - MAG_REPEAT_DELAY) % MAG_REPEAT_INTERVAL) == 0)
					{
						allowStep = true;
					};
				};
			}
			else
			{
				freezeStudioRepeatFrames = 0;
			};
			freezeStudioDirWasDown = dirDown;
			if (!allowStep)
			{
				return;
			};
			step = status.DASH ? 4 : 1;
			if (attackHeld)
			{
				if (status.LEFT)
				{
					characterFreezeX -= step;
				};
				if (status.RIGHT)
				{
					characterFreezeX += step;
				};
				if (status.UP)
				{
					characterFreezeY -= step;
				};
				if (status.DOWN)
				{
					characterFreezeY += step;
				};
				try
				{
					player.setX(characterFreezeX);
					player.setY(characterFreezeY);
				}
				catch (moveErr:Error)
				{
				};
				return;
			};
			if (specialHeld)
			{
				scale = characterFreezeScale > 0 ? characterFreezeScale : player.SizeRatio;
				if (status.UP)
				{
					scale *= 1.05;
				};
				if (status.DOWN)
				{
					scale /= 1.05;
				};
				if (scale < 0.25)
				{
					scale = 0.25;
				};
				if (scale > 3)
				{
					scale = 3;
				};
				characterFreezeScale = scale;
				try
				{
					player.SizeRatio = scale;
				}
				catch (scaleErr:Error)
				{
				};
				return;
			};
			// Bare Left/Right: scrub stance frame while staying frozen.
			if (status.LEFT || status.RIGHT)
			{
				try
				{
					frame = int(player.CurrentFrameNum);
					total = 0;
					if (player.HasStance && player.Stance)
					{
						total = int(player.Stance.totalFrames);
					};
					if (total <= 0)
					{
						total = 1;
					};
					next = status.RIGHT ? (frame + 1) : (frame - 1);
					if (next < 1)
					{
						next = total;
					};
					if (next > total)
					{
						next = 1;
					};
					player.FreezePlayback = true;
					player.stancePlayFrame(next);
					characterPaletteDirty = true;
					palettePADirty = true;
				}
				catch (frameErr:Error)
				{
				};
			};
		}

		private function blendColors(color1:*, color2:*, ratio:Number):*
		{
            var r1:* = (color1 >> 16) & 0xFF;
            var g1:* = (color1 >> 8) & 0xFF;
            var b1:* = color1 & 0xFF;
            var r2:* = (color2 >> 16) & 0xFF;
            var g2:* = (color2 >> 8) & 0xFF;
            var b2:* = color2 & 0xFF;
            var r:* = r1 + ratio * (r2 - r1);
            var g:* = g1 + ratio * (g2 - g1);
            var b:* = b1 + ratio * (b2 - b1);
            return (r << 16) | (g << 8) | b;
        }

        protected function getColorAtRatio(ratio:Number):*
		{ 
            var colors:Array = [0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF, 0xFF0000];
            var numColors:int = colors.length;
            var colorIndex:int = Math.floor(ratio * (numColors - 1));
            var nextColorIndex:int = Math.ceil(ratio * (numColors - 1));
            var blendRatio:Number = (ratio * (numColors - 1)) % 1;
            var startColor:* = colors[colorIndex];
            var endColor:* = colors[nextColorIndex];
            return blendColors(startColor, endColor, blendRatio);
        }

		protected function adjustColor(colorRef:*, newColor:*):* 
		{
			var refR:Number = (colorRef >> 16) & 0xFF;
			var refG:Number = (colorRef >> 8) & 0xFF;
			var refB:Number = colorRef & 0xFF;
			var refA:* = (colorRef >> 24) & 0xFF;
			var refLum:Number = (refR + refG + refB) / 3;
			var maxRGB:Number = Math.max(refR, refG, refB);
			var minRGB:Number = Math.min(refR, refG, refB);
			var refSat:Number = (maxRGB == 0) ? 0 : (maxRGB - minRGB) / maxRGB;
			var baseR:Number = (newColor >> 16) & 0xFF;
			var baseG:Number = (newColor >> 8) & 0xFF;
			var baseB:Number = newColor & 0xFF;
			var baseLum:Number = (baseR + baseG + baseB) / 3;
			var escalaLum:Number = (refLum == 0) ? 1 : ((baseLum == 0) ? 0 : refLum / baseLum);
			baseR *= escalaLum;
			baseG *= escalaLum;
			baseB *= escalaLum;
			var avg:Number = (baseR + baseG + baseB) / 3;
			baseR = avg + (baseR - avg) * refSat;
			baseG = avg + (baseG - avg) * refSat;
			baseB = avg + (baseB - avg) * refSat;
			var finalR:* = Math.min(255, Math.max(0, baseR));
			var finalG:* = Math.min(255, Math.max(0, baseG));
			var finalB:* = Math.min(255, Math.max(0, baseB));
			return (refA << 24) | (finalR << 16) | (finalG << 8) | finalB;
		}

		function adjustBrightness(color:*, factor:Number):* 
		{
			if (!color && color !== 0)
			{
				return 0;
			}
			factor = Math.max(0, Math.min(2, factor));
			var a:* = (color >> 24) & 0xFF;
			var hsv:Object = HsvWheel.rgbToHsv(uint(color));
			var h:Number = hsv.h;
			var s:Number = hsv.s;
			var v:Number = hsv.v;
			
			// Adjust brightness (V component)
			if (v <= 0 && factor > 0)
			{
				v = Math.min(1, factor * 0.5);
				if (s <= 0)
				{
					s = 1;
				};
			}
			else
			{
				v *= factor;
			};
			return HsvWheel.hsvToRgb(h, s, v, a);
		}

		function adjustSaturation(color:*, factor:Number):* 
		{
			if (!color && color !== 0)
			{
				return 0;
			}
			var a:* = (color >> 24) & 0xFF;
			var r:Number = (color >> 16) & 0xFF;
			var g:Number = (color >> 8) & 0xFF;
			var b:Number = color & 0xFF;
			var avg:Number = (r + g + b) / 3;
			r = avg + (r - avg) * factor;
			g = avg + (g - avg) * factor;
			b = avg + (b - avg) * factor;
			r = Math.min(255, Math.max(0, r));
			g = Math.min(255, Math.max(0, g));
			b = Math.min(255, Math.max(0, b));
			return (a << 24) | (r << 16) | (g << 8) | b;
		}

		function adjustAlpha(color:*, alphaFactor:Number):* 
		{
			if (!color && color !== 0)
			{
				return 0;
			}
			return (alphaFactor * 255 << 24) | (color & 0x00FFFFFF);
		}

		private function countObjectKeys(obj:Object):int
		{
			var n:int = 0;
			var k:String;
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

		/**
		 * Trace (+ throttled notify) why slider reapply applied or skipped swatches.
		 */
		protected function sliderDebugLog(msg:String, forceNotify:Boolean = false):void
		{
			var now:int;
			var shouldNotify:Boolean;
			PaletteMakerUtils.cacheDebugLog("[Slider] " + msg);
			trace("[PMSlider] " + msg);
			shouldNotify = forceNotify || msg.indexOf("notify=1") >= 0;
			if (!shouldNotify)
			{
				return;
			};
			now = getTimer();
			if (sliderDebugLastStats == statsName && (now - sliderDebugLastNotifyMs) < 600)
			{
				return;
			};
			sliderDebugLastNotifyMs = now;
			sliderDebugLastStats = statsName;
			try
			{
				Ssf2.MultiplayerManager.notify("PMSlider " + statsName + ": " + msg.substr(0, 140));
			}
			catch (err:Error)
			{
			};
		}

		protected function checkLivePAUpdate():void
		{
			ENABLE_PIXEL_ART_LIVE_UPDATE = ColorSquare.selectedBoxes.length <= COLOR_BOX_PA_LIMIT;
		}

		protected function recordGroupLayerReplacement(group:PaletteGroupSquare, baseColor:uint, replacement:uint):void
		{
			if (!group)
			{
				return;
			};
			if (!group.layerReplacements)
			{
				group.layerReplacements = {};
			};
			group.layerReplacements[String(baseColor)] = replacement;
			group.userModified = true;
		}

		/** Look up a group's layer replacement for base, matching same-RGB alpha siblings. */
		protected function lookupGroupLayerReplacement(group:PaletteGroupSquare, baseColor:uint):*
		{
			var key:String;
			var storedBase:uint;
			if (!group || !group.layerReplacements)
			{
				return null;
			};
			key = String(baseColor);
			if (group.layerReplacements[key] != null)
			{
				return group.layerReplacements[key];
			};
			for (key in group.layerReplacements)
			{
				storedBase = uint(key);
				if (PaletteColorAnalysis.colorsMatch(storedBase, baseColor))
				{
					return group.layerReplacements[key];
				};
			};
			return null;
		}

		/** Ordered palette swatches currently on colorBoxBG (excludes groups/tools). */
		protected function getPaletteSwatchBoxes():Array
		{
			var boxes:Array = [];
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return boxes;
			};
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare && !(child is PaletteGroupSquare))
				{
					boxes.push(child as ColorSquare);
				};
				i++;
			};
			return boxes;
		}

		private function swatchRowPitch():Number
		{
			return BOX_SIZE + BOX_OFFSET;
		}

		/**
		 * Sit the swatch panel so the top of the swatch rows is just under
		 * Copy to Clipboard / the action-button cluster.
		 */
		protected function syncColorBoxBGStartY():void
		{
			var bottom:Number;
			var candidate:DisplayObject;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			bottom = Number.NEGATIVE_INFINITY;
			candidate = copyToClipboardBtn as DisplayObject;
			if (candidate)
			{
				bottom = Math.max(bottom, candidate.y + candidate.height);
			};
			candidate = importFromOnlineBtn as DisplayObject;
			if (candidate)
			{
				bottom = Math.max(bottom, candidate.y + candidate.height);
			};
			if (m_subMenu.save_btn)
			{
				bottom = Math.max(bottom, m_subMenu.save_btn.y + m_subMenu.save_btn.height);
			};
			if (m_subMenu.locker_btn)
			{
				bottom = Math.max(bottom, m_subMenu.locker_btn.y + m_subMenu.locker_btn.height);
			};
			if (bottom == Number.NEGATIVE_INFINITY || isNaN(bottom))
			{
				return;
			};
			// Swatch content top is at BOX_POS_Y inside colorBoxBG.
			colorBoxBGStartY = bottom + SWATCH_BELOW_BUTTONS_GAP - BOX_POS_Y;
			m_subMenu.colorBoxBG.y = colorBoxBGStartY;
		}

		/** Fixed Y under the visible 3-row swatch viewport (groups + tools). */
		protected function fixedRowBelowSwatches():Number
		{
			return BOX_POS_Y + VISIBLE_SWATCH_ROWS * swatchRowPitch() + 4;
		}

		protected function refreshColorBoxScroll():void
		{
			syncColorBoxBGStartY();
			if (m_subMenu && m_subMenu.colorBoxBG)
			{
				m_subMenu.colorBoxBG.y = colorBoxBGStartY;
			};
			applySwatchRowScroll();
			updateSwatchScrollbar();
		}

		private function ensureSwatchMask():void
		{
			var pitch:Number;
			var w:Number;
			var h:Number;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			if (!swatchMask)
			{
				swatchMask = new Sprite();
				swatchMask.mouseEnabled = false;
				swatchMask.mouseChildren = false;
				m_subMenu.colorBoxBG.addChild(swatchMask);
			};
			pitch = swatchRowPitch();
			w = BOX_PER_ROW * pitch + 2;
			h = VISIBLE_SWATCH_ROWS * pitch + 2;
			swatchMask.graphics.clear();
			swatchMask.graphics.beginFill(0xFFFFFF, 1);
			swatchMask.graphics.drawRect(BOX_POS_X - 1, BOX_POS_Y - 1, w, h);
			swatchMask.graphics.endFill();
			if (m_subMenu.colorBoxBG.contains(swatchMask))
			{
				m_subMenu.colorBoxBG.setChildIndex(swatchMask, 0);
			};
		}

		protected function applySwatchRowScroll():void
		{
			var boxes:Array;
			var byColor:Object;
			var i:int;
			var color:uint;
			var box:ColorSquare;
			var row:int;
			var col:int;
			var pitch:Number;
			var maxScroll:int;
			var visible:Boolean;
			pitch = swatchRowPitch();
			maxScroll = Math.max(0, colorRowCount - VISIBLE_SWATCH_ROWS);
			if (swatchScrollRow > maxScroll)
			{
				swatchScrollRow = maxScroll;
			};
			if (swatchScrollRow < 0)
			{
				swatchScrollRow = 0;
			};
			ensureSwatchMask();
			boxes = getPaletteSwatchBoxes();
			byColor = {};
			for each (box in boxes)
			{
				byColor[uint(box.colorValue)] = box;
			};
			i = 0;
			while (i < mixedBasePaletteData.length)
			{
				color = uint(mixedBasePaletteData[i]);
				box = byColor[color] as ColorSquare;
				if (!box)
				{
					for each (box in boxes)
					{
						if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), color))
						{
							break;
						};
						box = null;
					};
				};
				if (box)
				{
					row = Math.floor(i / BOX_PER_ROW);
					col = i % BOX_PER_ROW;
					box.x = BOX_POS_X + col * pitch;
					box.y = BOX_POS_Y + (row - swatchScrollRow) * pitch;
					visible = (row >= swatchScrollRow) && (row < swatchScrollRow + VISIBLE_SWATCH_ROWS);
					box.visible = visible;
					box.mask = visible ? swatchMask : null;
				};
				i++;
			};
		}

		protected function updateSwatchScrollbar():void
		{
			var pitch:Number;
			var trackH:Number;
			var trackX:Number;
			var maxScroll:int;
			var thumbH:Number;
			var thumbY:Number;
			var ratio:Number;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			pitch = swatchRowPitch();
			trackH = VISIBLE_SWATCH_ROWS * pitch;
			trackX = BOX_POS_X + BOX_PER_ROW * pitch + 4;
			maxScroll = Math.max(0, colorRowCount - VISIBLE_SWATCH_ROWS);
			if (!swatchScrollBar)
			{
				swatchScrollBar = new Sprite();
				swatchScrollBar.buttonMode = true;
				swatchScrollBar.useHandCursor = true;
				swatchScrollThumb = new Sprite();
				swatchScrollThumb.buttonMode = true;
				swatchScrollThumb.useHandCursor = true;
				swatchScrollBar.addChild(swatchScrollThumb);
				swatchScrollBar.addEventListener(MouseEvent.MOUSE_DOWN, onSwatchScrollTrackDown);
				swatchScrollThumb.addEventListener(MouseEvent.MOUSE_DOWN, onSwatchScrollThumbDown);
				m_subMenu.colorBoxBG.addChild(swatchScrollBar);
			};
			swatchScrollBar.x = trackX;
			swatchScrollBar.y = BOX_POS_Y;
			swatchScrollBar.graphics.clear();
			swatchScrollBar.graphics.beginFill(0x2A2A33, 0.95);
			swatchScrollBar.graphics.lineStyle(1, 0x666677, 1);
			swatchScrollBar.graphics.drawRoundRect(0, 0, SWATCH_SCROLLBAR_WIDTH, trackH, 6, 6);
			swatchScrollBar.graphics.endFill();
			swatchScrollBar.visible = maxScroll > 0;
			if (maxScroll <= 0)
			{
				swatchScrollThumb.graphics.clear();
				return;
			};
			ratio = VISIBLE_SWATCH_ROWS / Number(colorRowCount);
			thumbH = Math.max(28, trackH * ratio);
			thumbY = (maxScroll > 0) ? (swatchScrollRow / Number(maxScroll)) * (trackH - thumbH) : 0;
			swatchScrollThumb.graphics.clear();
			swatchScrollThumb.graphics.beginFill(0x8899AA, 1);
			swatchScrollThumb.graphics.drawRoundRect(2, 0, SWATCH_SCROLLBAR_WIDTH - 4, thumbH, 6, 6);
			swatchScrollThumb.graphics.endFill();
			swatchScrollThumb.y = thumbY;
			if (m_subMenu.colorBoxBG.contains(swatchScrollBar))
			{
				m_subMenu.colorBoxBG.addChild(swatchScrollBar);
			};
		}

		protected function ensureSwatchScrollListeners():void
		{
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			m_subMenu.colorBoxBG.removeEventListener(MouseEvent.MOUSE_WHEEL, onSwatchMouseWheel);
			m_subMenu.colorBoxBG.addEventListener(MouseEvent.MOUSE_WHEEL, onSwatchMouseWheel, false, 0, true);
		}

		private function onSwatchMouseWheel(e:MouseEvent):void
		{
			var maxScroll:int = Math.max(0, colorRowCount - VISIBLE_SWATCH_ROWS);
			if (maxScroll <= 0)
			{
				return;
			};
			if (e.delta > 0)
			{
				swatchScrollRow = Math.max(0, swatchScrollRow - 1);
			}
			else
			{
				swatchScrollRow = Math.min(maxScroll, swatchScrollRow + 1);
			};
			applySwatchRowScroll();
			updateSwatchScrollbar();
			e.stopPropagation();
		}

		private function onSwatchScrollTrackDown(e:MouseEvent):void
		{
			var localY:Number;
			var trackH:Number;
			var thumbH:Number;
			var maxScroll:int;
			if (e.target == swatchScrollThumb)
			{
				return;
			};
			trackH = VISIBLE_SWATCH_ROWS * swatchRowPitch();
			maxScroll = Math.max(0, colorRowCount - VISIBLE_SWATCH_ROWS);
			if (maxScroll <= 0)
			{
				return;
			};
			thumbH = swatchScrollThumb.height > 0 ? swatchScrollThumb.height : 28;
			localY = swatchScrollBar.mouseY;
			swatchScrollRow = int(Math.round((localY / trackH) * maxScroll));
			if (swatchScrollRow < 0) swatchScrollRow = 0;
			if (swatchScrollRow > maxScroll) swatchScrollRow = maxScroll;
			applySwatchRowScroll();
			updateSwatchScrollbar();
		}

		private function onSwatchScrollThumbDown(e:MouseEvent):void
		{
			swatchScrollDragging = true;
			swatchScrollDragOffset = swatchScrollThumb.mouseY;
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_MOVE, onSwatchScrollThumbMove, false, 0, true);
				Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_UP, onSwatchScrollThumbUp, false, 0, true);
			};
			e.stopPropagation();
		}

		private function onSwatchScrollThumbMove(e:MouseEvent):void
		{
			var trackH:Number;
			var thumbH:Number;
			var maxScroll:int;
			var y:Number;
			if (!swatchScrollDragging || !swatchScrollBar)
			{
				return;
			};
			trackH = VISIBLE_SWATCH_ROWS * swatchRowPitch();
			thumbH = swatchScrollThumb.height > 0 ? swatchScrollThumb.height : 28;
			maxScroll = Math.max(0, colorRowCount - VISIBLE_SWATCH_ROWS);
			y = swatchScrollBar.mouseY - swatchScrollDragOffset;
			if (y < 0) y = 0;
			if (y > trackH - thumbH) y = trackH - thumbH;
			swatchScrollRow = (trackH - thumbH) > 0
				? int(Math.round((y / (trackH - thumbH)) * maxScroll))
				: 0;
			applySwatchRowScroll();
			updateSwatchScrollbar();
		}

		private function onSwatchScrollThumbUp(e:MouseEvent):void
		{
			swatchScrollDragging = false;
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onSwatchScrollThumbMove);
				Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_UP, onSwatchScrollThumbUp);
			};
		}

		protected function layoutGroupRow():void
		{
			var i:int;
			var group:PaletteGroupSquare;
			var rowY:Number = fixedRowBelowSwatches();
			i = 0;
			while (i < groupSquares.length)
			{
				group = groupSquares[i] as PaletteGroupSquare;
				if (group)
				{
					group.x = BOX_POS_X + i * (BOX_SIZE + BOX_OFFSET);
					group.y = rowY;
					group.mask = null;
					group.visible = true;
					if (!m_subMenu.colorBoxBG.contains(group))
					{
						m_subMenu.colorBoxBG.addChild(group);
					};
				};
				i++;
			};
		}

		protected function onToolHover(toolId:String):void
		{
			if (toolHintText)
			{
				toolHintText.text = TOOL_HINTS[toolId] ? String(TOOL_HINTS[toolId]) : toolId;
			};
		}

		protected function onToolHoverOut(toolId:String):void
		{
			updateDefaultToolHint();
		}

		protected function updateDefaultToolHint():void
		{
			if (!toolHintText)
			{
				return;
			};
			if (activeGroup)
			{
				toolHintText.text = "Active Group: " + (activeGroup.groupName ? activeGroup.groupName : "Group");
			}
			else
			{
				toolHintText.text = "";
			};
		}
    }
}
