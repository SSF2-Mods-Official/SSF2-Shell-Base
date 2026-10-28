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

    /** Magnifier, sprite hit sampling and color pick resolution. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuMagnifier extends PaletteMakerMenuStudio
    {
		/** The form currently on the studio fighter. CurrentStatsName, not the form the editor opened. */
		protected var activeFighterForm:String = "";

        public function PaletteMakerMenuMagnifier()
        {
            super();
        }

		private const MAG_RADIUS:int = 5;

		private const MAG_CELL:int = 8;

		protected var magnifierHit:Object;

		/** Red marker over the hovered art texel (not drawn into the magnifier map). */
		private var magHoverPixelMarker:Sprite = null;

		private var magHoverSwatch:ColorSquare = null;

		private var m_lastMagHoverDebugKey:String = "";

		/** Passive swatch-hover isolate (does not change selection). */
		protected var hoverBaseColor:uint = 0;
		/** True while the next frame will apply or clear the swatch-hover dim. */
		private var hoverDimFrame:Boolean = false;

		/** The hovered swatch belongs to the linked form, not the opened one. */
		protected var hoverAltForm:Boolean = false;

		protected var suppressSelectionSideEffects:Boolean = false;

		protected var magnifierProbeX:Number = 0;

		protected var magnifierProbeY:Number = 0;

		protected var magnifierAttackWasDown:Boolean = false;

		protected var magnifierSelectConsumed:Boolean = false;

		protected var magnifierControlDriven:Boolean = false;

		protected var magnifierFreezeX:Number = 0;

		protected var magnifierFreezeY:Number = 0;

		protected var magDirWasDown:Boolean = false;

		protected var magRepeatFrames:int = 0;

		protected var magControlProbeX:Number = 0;

		protected var magControlProbeY:Number = 0;

		/** Last controller nudge search distance (local texels or stage px) — for PM debug. */
		private var magLastNudgeDist:int = 0;

		private var magLastNudgeTried:int = 0;

		protected var magLastNudgeVia:String = "";

		private var magDebugLastNotifyMs:int = 0;

		protected var draggingSlider:Boolean = false;

		/** Brief select-highlight flash (not while recoloring). */
		protected var selectHighlightFlashActive:Boolean = false;

		protected var selectHighlightTargets:Object = null;

		protected const MAG_PROBE_STEP_RUN:Number = 4;

		private const MAG_MOUSE_HANDOFF:Number = 3;

		private static const SELECT_HIGHLIGHT_RGB_SIMILAR:Number = 70;

		private static const SELECT_HIGHLIGHT_HUE_SIMILAR:Number = 28;

		/** Debug snapshot of earlier-group replacements around a swatch apply. */
		private var m_ownerReplSnapshot:Object = null;

		override public function manageMenuMappings(e:Event):void
		{
			var selector:* = Ssf2.MenuController.costumeSelectorDisplay;
			if (!m_hasEvents)
			{
				return;
			};
			if (selector && selector.isOnscreen())
			{
				return;
			};
			pollPad(
				function():void { movePadFocus(-1); },
				function():void { movePadFocus(1); },
				function():void { movePadFocus(-1); },
				function():void { movePadFocus(1); },
				function():void { activatePadFocus(); },
				function():void { padBack(); }
			);
		}

		private function padBack():void
		{
			if (isColorSettingsVisible() || isToolSettingsVisible())
			{
				closeToolSettings();
				return;
			};
			if (shortcutsPopup && shortcutsPopup.visible)
			{
				closeShortcutsPopup();
				return;
			};
			if (achievementsPopup && achievementsPopup.visible)
			{
				closeAchievementsPopup();
				return;
			};
			// Special stays on the character so they can attack while editing.
			// Leave the studio from the on-screen Back button.
		}

		/**
		 * @param editingGroup when set, refuse to rewrite palette keys owned by a
		 * different group (stops RGB-family expand from clobbering higher-priority bases).
		 */
		protected function replaceBracket(oldBracket:*, newBracket:*, oldArr:Array, newArr:Array, editingGroup:PaletteGroupSquare = null):void 
		{
			var i:int;
			var target:uint;
			var writeRepl:uint;
			var matched:Boolean;
			var exactPresent:Boolean;
			var exactFirst:int;
			var keyColor:uint;
			var keyOwner:PaletteGroupSquare;
			var targetOwner:PaletteGroupSquare;
			var blocked:int;
			if (!oldArr || !newArr)
			{
				return;
			};
			target = uint(oldBracket);
			writeRepl = normalizePaletteReplacement(uint(newBracket), target);
			targetOwner = editingGroup ? editingGroup : getOwnerGroupForBase(target);
			matched = false;
			exactPresent = false;
			exactFirst = -1;
			blocked = 0;
			i = 0;
			while (i < oldArr.length)
			{
				keyColor = uint(oldArr[i]);
				if (keyColor == target)
				{
					exactPresent = true;
					if (exactFirst < 0)
					{
						exactFirst = i;
					};
				};
				if (PaletteColorAnalysis.colorsMatch(keyColor, target))
				{
					keyOwner = getOwnerGroupForBase(keyColor);
					if (targetOwner && keyOwner && keyOwner != targetOwner)
					{
						blocked++;
						
						i++;
						continue;
					};
					while (newArr.length <= i)
					{
						newArr.push(uint(oldArr[newArr.length]));
					};
					newArr[i] = writeRepl;
					matched = true;
					// Update every matching key (same RGB, possibly different alpha).
				};
				i++;
			};
			
			// Exact-ARGB paint (unique sprites / replacePaletteHelper) needs the precise
			// key. Soft colorsMatch can update an alpha sibling while the live texel
			// key is missing — wrote=1 in swatchApply but pupils never recolor.
			if (!exactPresent)
			{
				oldArr.push(target);
				newArr.push(writeRepl);
				exactFirst = oldArr.length - 1;
				matched = true;
				
			}
			else if (exactFirst >= 0 && exactFirst < newArr.length)
			{
				newArr[exactFirst] = writeRepl;
			};
			if (!matched)
			{
				return;
			};
			// Collapse duplicate exact keys so stale early entries cannot shadow the write.
			collapseExactPaletteKeys(oldArr, newArr, target, writeRepl);
		}

		protected function resetColorBoxes():void
		{
			var i:int;
			var child:DisplayObject;
			suppressSelectionSideEffects = true;
			ColorSquare.deselectAll();
			suppressSelectionSideEffects = false;
			activeGroup = null;
			swatchScrollRow = 0;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			}
			for (i = m_subMenu.colorBoxBG.numChildren - 1; i >= 0; i--)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare)
				{
					ColorSquare(child).mask = null;
					ColorSquare(child).killEvents();
					m_subMenu.colorBoxBG.removeChildAt(i);
				}
				else if (child is PaletteGroupSquare)
				{
					PaletteGroupSquare(child).killEvents();
					m_subMenu.colorBoxBG.removeChildAt(i);
				}
				else if (child is PaletteToolSquare)
				{
					PaletteToolSquare(child).killEvents();
					m_subMenu.colorBoxBG.removeChildAt(i);
				}
				else if (child == toolHintText || child == swatchMask || child == swatchScrollBar)
				{
					m_subMenu.colorBoxBG.removeChildAt(i);
				}
			}
			groupSquares = [];
			toolSquares = [];
			toolHintText = null;
			swatchMask = null;
			swatchScrollBar = null;
			swatchScrollThumb = null;
			closeColorSettings();
			m_subMenu.colorBoxBG.y = colorBoxBGStartY;
		}

		protected function isColorSettingsVisible():Boolean
		{
			return colorSettingsPopup != null && colorSettingsPopup.visible;
		}

		/** Settings / hide-UI / pause — blocks swatches and normal magnifier select. */
		private function isOverlayBlockingPalette():Boolean
		{
			if (uiKeysFrozen || uiHidden)
			{
				return true;
			};
			if (Ssf2.GameController.stageData && Ssf2.GameController.stageData.Paused)
			{
				return true;
			};
			if (isToolSettingsVisible() || isColorSettingsVisible())
			{
				return true;
			};
			return false;
		}

		protected function isSwatchInteractionAllowed():Boolean
		{
			if (ColorSquare.primaryPickMode)
			{
				return true;
			};
			return !isOverlayBlockingPalette();
		}

		protected function isMagnifierBlocked(probeX:Number = NaN, probeY:Number = NaN):Boolean
		{
			var hx:Number;
			var hy:Number;
			var pickMode:Boolean = ColorSquare.primaryPickMode || csEyedropperMode;
			if (Ssf2.GameController.stageData && Ssf2.GameController.stageData.Paused)
			{
				return true;
			};
			if (uiHidden)
			{
				return true;
			};
			if (!pickMode && isOverlayBlockingPalette())
			{
				return true;
			};
			if (uiKeysFrozen && !pickMode)
			{
				return true;
			};
			if (magnifierInputActive)
			{
				return false;
			};
			hx = isNaN(probeX) ? Ssf2.Main.Root.stage.mouseX : probeX;
			hy = isNaN(probeY) ? Ssf2.Main.Root.stage.mouseY : probeY;
			if (m_subMenu && Ssf2.Main.Root.stage)
			{
				if (m_subMenu.hitTestPoint(hx, hy, false) && !pointerOnPaletteArt(hx, hy))
				{
					return true;
				};
			};
			return false;
		}

		/** The fighter, the portrait, and the unique sprites are art, so the magnifier stays open. */
		private function pointerOnPaletteArt(hx:Number, hy:Number):Boolean
		{
			var disp:DisplayObject;
			var i:int;
			if (shapeHit(player ? player.MC : null, hx, hy))
			{
				return true;
			};
			if (shapeHit(PixelArt, hx, hy))
			{
				return true;
			};
			if (shapeHit(PixelArtPartner, hx, hy))
			{
				return true;
			};
			if (uniquePaSprites)
			{
				i = uniquePaSprites.length - 1;
				while (i >= 0)
				{
					disp = uniquePaSprites[i] as DisplayObject;
					if (shapeHit(disp, hx, hy))
					{
						return true;
					};
					i--;
				};
			};
			return false;
		}

		/** Bounds first. The shape test runs only when the box contains the point. */
		private function shapeHit(disp:DisplayObject, hx:Number, hy:Number):Boolean
		{
			return Boolean(disp && disp.hitTestPoint(hx, hy, false) && disp.hitTestPoint(hx, hy, true));
		}

		private function sampleDisplayColorAt(globalX:Number, globalY:Number):Object
		{
			var hit:Object = null;
			var disp:DisplayObject;
			var i:int;
			if (player && player.MC)
			{
				hit = PaletteColorAnalysis.sampleDisplayPixel(player.MC, globalX, globalY, 12);
				if (hit)
				{
					return hit;
				};
			};
			if (uniquePaSprites && uniquePaSprites.length > 0)
			{
				i = uniquePaSprites.length - 1;
				while (i >= 0)
				{
					disp = uniquePaSprites[i] as DisplayObject;
					if (disp is DisplayObjectContainer && disp.visible)
					{
						hit = PaletteColorAnalysis.sampleDisplayPixel(disp as DisplayObjectContainer, globalX, globalY, 12);
						if (hit)
						{
							return hit;
						};
					};
					i--;
				};
			};
			if (PixelArtPartner)
			{
				hit = PaletteColorAnalysis.sampleDisplayPixel(PixelArtPartner, globalX, globalY, 12);
				if (hit)
				{
					return hit;
				};
			};
			if (PixelArt)
			{
				return PaletteColorAnalysis.sampleDisplayPixel(PixelArt, globalX, globalY, 12);
			};
			return null;
		}

		/** True only while the manage-costumes grid is on the stage. */
		protected function costumeMenuOpen():Boolean
		{
			var menu:*;
			try
			{
				menu = Ssf2.MenuController.costumeSelectorDisplay;
				return Boolean(menu && menu.isOnscreen());
			}
			catch (menuErr:*)
			{
				return false;
			};
		}

		protected function stage_MOUSE_MOVE(e:MouseEvent):void
		{
			if (costumeMenuOpen())
			{
				return;
			};
			// While the stick/keyboard is driving the probe, ignore tiny mouse jitter so it
			// doesn't fight controller nudges. The mouse only takes back over once it moves
			// past a small threshold from the last control-driven position.
			if (magnifierControlDriven)
			{
				if (Math.abs(e.stageX - magControlProbeX) < MAG_MOUSE_HANDOFF && Math.abs(e.stageY - magControlProbeY) < MAG_MOUSE_HANDOFF)
				{
					return;
				};
			};
			magnifierControlDriven = false;
			magnifierProbeX = e.stageX;
			magnifierProbeY = e.stageY;
			updateMagnifier(magnifierProbeX, magnifierProbeY);
		}

		protected function updateMagnifier(globalX:Number, globalY:Number, fromControl:Boolean = false):void
		{
			var hit:Object;
			var prevBmp:Bitmap;
			var prevLX:int;
			var prevLY:int;
			prevBmp = (magnifierHit && magnifierHit.bitmap is Bitmap) ? (magnifierHit.bitmap as Bitmap) : null;
			prevLX = magnifierHit ? int(magnifierHit.localX) : -99999;
			prevLY = magnifierHit ? int(magnifierHit.localY) : -99999;
			magnifierProbeX = Math.round(globalX);
			magnifierProbeY = Math.round(globalY);
			if (!magnifierOverlay || !currentPaletteData || isMagnifierBlocked(magnifierProbeX, magnifierProbeY))
			{
				hideMagnifier();
				return;
			};
			hit = sampleDisplayColorAt(magnifierProbeX, magnifierProbeY);
			if (!hit || (((uint(hit.color) >> 24) & 0xFF) == 0))
			{
				hideMagnifier();
				return;
			};
			magnifierHit = hit;
			if (fromControl)
			{
				snapMagnifierProbeToHitIfChanged(prevBmp, prevLX, prevLY);
			}
			else
			{
				snapMagnifierProbeToHit();
			};
			refreshMagnifierFromCurrentHit();
		}

		/** Redraw/position the magnifier from magnifierHit + probe (no stage re-sample). */
		protected function refreshMagnifierFromCurrentHit():void
		{
			var localPos:Point;
			var bmp:Bitmap;
			var lx:int;
			var ly:int;
			if (!magnifierOverlay || !magnifierHit || !(magnifierHit.bitmap is Bitmap))
			{
				return;
			};
			bmp = magnifierHit.bitmap as Bitmap;
			lx = int(magnifierHit.localX);
			ly = int(magnifierHit.localY);
			redrawMagnifier(bmp, lx, ly);
			updateMagHoverPaletteHighlight();
			updateMagHoverPixelMarker(bmp, lx, ly);
			localPos = m_container.globalToLocal(new Point(magnifierProbeX, magnifierProbeY));
			magnifierOverlay.x = localPos.x + 18;
			magnifierOverlay.y = localPos.y + 18;
			magnifierOverlay.visible = true;
			if (!magnifierInputActive)
			{
				magnifierInputActive = true;
				if (player)
				{
					try
					{
						magnifierFreezeX = player.getX();
						magnifierFreezeY = player.getY();
					}
					catch (posErr:Error)
					{
					};
				};
				updateStageFreeze();
			};
			if (magHoverPixelMarker && m_container.contains(magHoverPixelMarker))
			{
				m_container.setChildIndex(magHoverPixelMarker, m_container.numChildren - 1);
			};
			if (m_container.contains(magnifierOverlay))
			{
				// Map on top so the red art marker is never sampled into the zoom grid.
				m_container.setChildIndex(magnifierOverlay, m_container.numChildren - 1);
			};
		}

		protected function hideMagnifier():void
		{
			clearMagHoverPixelMarker();
			clearMagHoverPaletteHighlight();
			magnifierHit = null;
			if (magnifierOverlay)
			{
				magnifierOverlay.visible = false;
				magnifierOverlay.graphics.clear();
			};
			if (magnifierInputActive)
			{
				magnifierInputActive = false;
				magnifierAttackWasDown = false;
				magnifierSelectConsumed = false;
				magnifierControlDriven = false;
				magDirWasDown = false;
				magRepeatFrames = 0;
				updateStageFreeze();
			};
		}

		private function clearMagHoverPixelMarker():void
		{
			if (magHoverPixelMarker)
			{
				magHoverPixelMarker.visible = false;
			};
		}

		/**
		 * Draw a 1-texel red square over the hovered art pixel in stage space.
		 * Does not modify BitmapData, so the magnifier map stays true-color.
		 */
		private function updateMagHoverPixelMarker(bmp:Bitmap, lx:int, ly:int):void
		{
			var tl:Point;
			var br:Point;
			var localTL:Point;
			var w:Number;
			var h:Number;
			if (!bmp || !m_container)
			{
				clearMagHoverPixelMarker();
				return;
			};
			if (!magHoverPixelMarker)
			{
				magHoverPixelMarker = new Sprite();
				magHoverPixelMarker.mouseEnabled = false;
				magHoverPixelMarker.mouseChildren = false;
				m_container.addChild(magHoverPixelMarker);
			};
			tl = bmp.localToGlobal(new Point(lx, ly));
			br = bmp.localToGlobal(new Point(lx + 1, ly + 1));
			localTL = m_container.globalToLocal(tl);
			w = Math.max(1, Math.abs(br.x - tl.x));
			h = Math.max(1, Math.abs(br.y - tl.y));
			magHoverPixelMarker.graphics.clear();
			magHoverPixelMarker.graphics.beginFill(0xFF0000, 1);
			magHoverPixelMarker.graphics.drawRect(0, 0, w, h);
			magHoverPixelMarker.graphics.endFill();
			magHoverPixelMarker.x = localTL.x;
			magHoverPixelMarker.y = localTL.y;
			magHoverPixelMarker.visible = true;
		}

		private function magnifierHitIsGiga():Boolean
		{
			var i:int;
			var disp:DisplayObject;
			var cand:Object;
			if (!magnifierHit || !(magnifierHit.bitmap is Bitmap) || !uniquePaSprites || !uniquePaCoverCache)
			{
				return false;
			};
			i = 0;
			while (i < uniquePaSprites.length && i < uniquePaCoverCache.length)
			{
				disp = uniquePaSprites[i] as DisplayObject;
				if (disp && displayHasBitmap(disp, magnifierHit.bitmap as Bitmap))
				{
					cand = uniquePaCoverCache[i];
					return cand && LinkedFormSprite.matchesForm(String(cand.linkage), "gigabowser");
				};
				i++;
			};
			return false;
		}

		private function magnifierHitIsPartner():Boolean
		{
			var i:int;
			var disp:DisplayObject;
			var cand:Object;
			var partnerName:String;
			var linkage:String;
			var partnerPortrait:Boolean;
			if (!magnifierHit || !(magnifierHit.bitmap is Bitmap))
			{
				return false;
			};
			partnerName = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (!partnerName)
			{
				return false;
			};
			partnerPortrait = PixelArtPartner && displayHasBitmap(PixelArtPartner, magnifierHit.bitmap as Bitmap);
			linkage = null;
			if (!partnerPortrait && player && player.MC && displayHasBitmap(player.MC as DisplayObject, magnifierHit.bitmap as Bitmap))
			{
				return LinkedFormPaint.fighterUsesPartnerPalette(activeFighterForm, partnerName);
			};
			if (!partnerPortrait && uniquePaSprites && uniquePaCoverCache)
			{
				i = 0;
				while (i < uniquePaSprites.length && i < uniquePaCoverCache.length)
				{
					disp = uniquePaSprites[i] as DisplayObject;
					if (disp && disp.visible && displayHasBitmap(disp, magnifierHit.bitmap as Bitmap))
					{
						cand = uniquePaCoverCache[i];
						linkage = (cand && cand.linkage) ? String(cand.linkage) : null;
						break;
					};
					i++;
				};
			};
			return LinkedFormSprite.hitUsesPartnerSwatch(partnerPortrait, linkage, partnerName);
		}

		private function displayHasBitmap(root:DisplayObject, bitmap:Bitmap):Boolean
		{
			var box:DisplayObjectContainer;
			var i:int;
			if (!root || !bitmap)
			{
				return false;
			};
			if (root == bitmap)
			{
				return true;
			};
			if (!(root is DisplayObjectContainer))
			{
				return false;
			};
			box = root as DisplayObjectContainer;
			i = 0;
			while (i < box.numChildren)
			{
				if (displayHasBitmap(box.getChildAt(i), bitmap))
				{
					return true;
				};
				i++;
			};
			return false;
		}

		private function clearMagHoverPaletteHighlight():void
		{
			if (magHoverSwatch)
			{
				magHoverSwatch.setMagHoverHighlight(false);
				magHoverSwatch = null;
			};
			clearShownPixelHex();
		}

		protected function showSwatchHex(color:uint):void
		{
			if (!toolHintText)
			{
				return;
			};
			pixelHexShown = true;
			toolHintText.text = LinkedFormPaint.hexLabel(color);
		}

		private function clearShownPixelHex():void
		{
			if (!pixelHexShown || paletteHoverBox)
			{
				return;
			};
			pixelHexShown = false;
			updateDefaultToolHint();
		}

		private function updateMagHoverPaletteHighlight():void
		{
			var baseColor:uint;
			var boxes:Array;
			var box:ColorSquare;
			var match:ColorSquare;
			var i:int;
			var idx:int;
			var row:int;
			var maxScroll:int;
			clearMagHoverPaletteHighlight();
			var hoverInfo:Object = resolveSpritePickIdentity(magnifierHit,
				magnifierHit ? uint(magnifierHit.color) : 0);
			
			if (!hoverInfo || !hoverInfo.found)
			{
				return;
			};
			baseColor = uint(hoverInfo.base);
			boxes = getPaletteSwatchBoxes();
			match = null;
			var wantAlt:Boolean = magnifierHitIsPartner();
			for each (box in boxes)
			{
				if (box && box.altForm == wantAlt && PaletteColorAnalysis.colorsMatch(uint(box.colorValue), baseColor))
				{
					match = box;
					break;
				};
			};
			if (!match)
			{
				return;
			};
			magHoverSwatch = match;
			magHoverSwatch.setMagHoverHighlight(true);
			showSwatchHex(uint(match.colorValue));
			if (wantAlt)
			{
				revealFormSwatch(true, baseColor);
				return;
			};
			// Scroll palette so the highlighted swatch row is visible.
			idx = -1;
			i = 0;
			while (i < mixedBasePaletteData.length)
			{
				if (PaletteColorAnalysis.colorsMatch(uint(mixedBasePaletteData[i]), baseColor))
				{
					idx = i;
					break;
				};
				i++;
			};
			if (idx < 0)
			{
				return;
			};
			row = Math.floor(idx / BOX_PER_ROW);
			maxScroll = Math.max(0, colorRowCount - VISIBLE_SWATCH_ROWS);
			if (row < swatchScrollRow)
			{
				swatchScrollRow = row;
				applySwatchRowScroll();
				updateSwatchScrollbar();
			}
			else if (row >= swatchScrollRow + VISIBLE_SWATCH_ROWS)
			{
				swatchScrollRow = Math.min(maxScroll, row - VISIBLE_SWATCH_ROWS + 1);
				applySwatchRowScroll();
				updateSwatchScrollbar();
			};
		}

		/**
		 * Resolve which palette base the magnifier texel maps to.
		 * Returns { found, base, orig, hasOrig, via, cacheStatus, boxFound, debugKey }.
		 * Do NOT use 0xFFFFFFFF as a sentinel — that is opaque white.
		 */
		protected function resolveSpritePickIdentity(hit:Object, painted:uint):Object
		{
			var origObj:Object;
			var orig:uint;
			var hasOrig:Boolean;
			var bases:Array;
			var base:uint;
			var found:Boolean;
			var via:String;
			var cacheStatus:String;
			var boxFound:Boolean;
			var box:ColorSquare;
			var out:Object;
			var liveRepl:uint;
			found = false;
			base = 0;
			via = "none";
			cacheStatus = "n/a";
			hasOrig = false;
			orig = 0;
			if (!hit)
			{
				return {
					"found": false, "base": 0, "orig": 0, "hasOrig": false, "via": "noHit",
					"cacheStatus": "n/a", "boxFound": false, "debugKey": "noHit"
				};
			};
			origObj = sampleOriginalColorAtHitDetailed(hit);
			if (origObj)
			{
				hasOrig = origObj.color != null;
				if (hasOrig)
				{
					orig = uint(origObj.color);
				};
				cacheStatus = String(origObj.cacheStatus);
			}
			else
			{
				cacheStatus = "null";
			};
			// Stale/wrong cache: live near-black vs bright orig is invalid UNLESS the
			// live palette already paints that base near-black (intentional recolor).
			// Without this gate, distrust + reverse-lookup steals a different bright
			// base (e.g. painted=0x0 → base=0x2656ae) when clicking true black.
			if (hasOrig && isNearBlackRgb(painted) && !isNearBlackRgb(orig)
				&& PaletteColorAnalysis.rgbDistance(painted & 0xFFFFFF, orig & 0xFFFFFF) > 80)
			{
				liveRepl = replacementInPalette(magnifierHitIsPartner() && partnerPaletteData ? partnerPaletteData : currentPaletteData, orig);
				if (!(isNearBlackRgb(liveRepl)
					|| PaletteColorAnalysis.colorsMatch(liveRepl, painted)
					|| PaletteColorAnalysis.rgbDistance(liveRepl & 0xFFFFFF, painted & 0xFFFFFF) <= 40))
				{
					hasOrig = false;
					orig = 0;
					cacheStatus = String(cacheStatus) + ">distrust";
				};
			};
			if (hasOrig)
			{
				base = orig;
				found = true;
				via = "orig";
			}
			else if (isNearBlackRgb(painted))
			{
				// Near-black with no trusted orig: only near-black palette identities.
				// Never reverse-map through findBasesForSpriteHit — match-all / display
				// piles map black paint onto unrelated bright members.
				bases = findNearBlackSelectFallback(painted);
				if (bases && bases.length > 0)
				{
					base = uint(bases[0]);
					found = true;
					via = "nearBlackFallback";
				};
			}
			else
			{
				bases = findBasesForSpriteHit(painted);
				if (bases && bases.length > 0)
				{
					base = uint(bases[0]);
					found = true;
					via = "displayOrIdentity";
				};
			};
			boxFound = false;
			if (found && m_subMenu && m_subMenu.colorBoxBG)
			{
				for each (box in getPaletteSwatchBoxes())
				{
					if (box && PaletteColorAnalysis.colorsMatch(uint(box.colorValue), base))
					{
						boxFound = true;
						break;
					};
				};
			};
			out = {
				"found": found,
				"base": base,
				"orig": orig,
				"hasOrig": hasOrig,
				"via": via,
				"cacheStatus": cacheStatus,
				"boxFound": boxFound,
				"debugKey": (int(hit.localX) + "," + int(hit.localY) + ":"
					+ (painted & 0xFFFFFF).toString(16) + ":" + via + ":"
					+ (found ? (base & 0xFFFFFF).toString(16) : "none"))
			};
			return out;
		}

		/** Snap stage probe to the center of the current sampled texel. */
		private function snapMagnifierProbeToHit():void
		{
			var bmp:Bitmap;
			var global:Point;
			if (!magnifierHit || !(magnifierHit.bitmap is Bitmap))
			{
				return;
			};
			bmp = magnifierHit.bitmap as Bitmap;
			if (!bmp)
			{
				return;
			};
			global = bmp.localToGlobal(new Point(int(magnifierHit.localX) + 0.5, int(magnifierHit.localY) + 0.5));
			magnifierProbeX = Math.round(global.x);
			magnifierProbeY = Math.round(global.y);
			if (magnifierControlDriven)
			{
				magControlProbeX = magnifierProbeX;
				magControlProbeY = magnifierProbeY;
			};
		}

		/** Snap only when the sampled texel identity changed (avoids canceling stage nudges). */
		private function snapMagnifierProbeToHitIfChanged(prevBmp:Bitmap, prevLX:int, prevLY:int):void
		{
			var bmp:Bitmap;
			var beforeX:Number;
			var beforeY:Number;
			if (!magnifierHit || !(magnifierHit.bitmap is Bitmap))
			{
				return;
			};
			bmp = magnifierHit.bitmap as Bitmap;
			if (bmp == prevBmp && int(magnifierHit.localX) == prevLX && int(magnifierHit.localY) == prevLY)
			{
				return;
			};
			beforeX = magnifierProbeX;
			beforeY = magnifierProbeY;
			snapMagnifierProbeToHit();
			
		}

		/**
		 * Nudge one magnifier cell at a time on the current bitmap (local texel space).
		 * Stage-space nudges can skip texels when the bitmap isn't 1:1 with stage pixels
		 * (parent transforms / subpixel placement) — see MagMove SKIP dLocal=2 at scale=1.
		 */
		protected function tryNudgeMagnifierByLocal(dLocalX:int, dLocalY:int):Boolean
		{
			var bmp:Bitmap;
			var bd:BitmapData;
			var startLX:int;
			var startLY:int;
			var sx:int;
			var sy:int;
			var targetDist:int;
			var maxSearch:int = 12;
			var i:int;
			var dist:int;
			var nx:int;
			var ny:int;
			var color:uint;
			var order:Array;
			var tried:int;
			var missAlpha:int;
			var missOob:int;
			var global:Point;
			if (!magnifierHit || !(magnifierHit.bitmap is Bitmap))
			{
				return false;
			};
			bmp = magnifierHit.bitmap as Bitmap;
			bd = bmp ? bmp.bitmapData : null;
			if (!bd)
			{
				return false;
			};
			startLX = int(magnifierHit.localX);
			startLY = int(magnifierHit.localY);
			sx = (dLocalX > 0) ? 1 : ((dLocalX < 0) ? -1 : 0);
			sy = (dLocalY > 0) ? 1 : ((dLocalY < 0) ? -1 : 0);
			magLastNudgeDist = 0;
			magLastNudgeTried = 0;
			magLastNudgeVia = "local";
			if (sx == 0 && sy == 0)
			{
				return false;
			};
			targetDist = Math.max(Math.abs(dLocalX), Math.abs(dLocalY));
			if (targetDist < 1)
			{
				targetDist = 1;
			};
			order = [];
			i = targetDist;
			while (i <= maxSearch)
			{
				order.push(i);
				i++;
			};
			i = targetDist - 1;
			while (i >= 1)
			{
				order.push(i);
				i--;
			};
			tried = 0;
			missAlpha = 0;
			missOob = 0;
			for each (dist in order)
			{
				nx = startLX + sx * dist;
				ny = startLY + sy * dist;
				if (sx == 0)
				{
					nx = startLX;
				};
				if (sy == 0)
				{
					ny = startLY;
				};
				tried++;
				if (nx < 0 || ny < 0 || nx >= bd.width || ny >= bd.height)
				{
					missOob++;
					continue;
				};
				color = bd.getPixel32(nx, ny);
				if (((color >> 24) & 0xFF) > 0)
				{
					magnifierHit = {
						"color": color,
						"bitmap": bmp,
						"localX": nx,
						"localY": ny
					};
					global = bmp.localToGlobal(new Point(nx + 0.5, ny + 0.5));
					magnifierProbeX = Math.round(global.x);
					magnifierProbeY = Math.round(global.y);
					magLastNudgeDist = dist;
					magLastNudgeTried = tried;
					
					return true;
				};
				missAlpha++;
			};
			magLastNudgeTried = tried;
			return false;
		}

		/**
		 * Fallback: nudge probe in stage/screen space along the stick axes.
		 * Used when there is no current bitmap hit, or local search hit the sprite edge.
		 */
		protected function tryNudgeMagnifierByStage(dStageX:int, dStageY:int):Boolean
		{
			var startX:Number;
			var startY:Number;
			var sx:int;
			var sy:int;
			var targetDist:int;
			var maxSearch:int = 12;
			var i:int;
			var dist:int;
			var nx:Number;
			var ny:Number;
			var hit:Object;
			var order:Array;
			var tried:int;
			var missAlpha:int;
			var missNull:int;
			startX = magnifierProbeX;
			startY = magnifierProbeY;
			sx = (dStageX > 0) ? 1 : ((dStageX < 0) ? -1 : 0);
			sy = (dStageY > 0) ? 1 : ((dStageY < 0) ? -1 : 0);
			magLastNudgeDist = 0;
			magLastNudgeTried = 0;
			magLastNudgeVia = "stage";
			if (sx == 0 && sy == 0)
			{
				return false;
			};
			targetDist = Math.max(Math.abs(dStageX), Math.abs(dStageY));
			if (targetDist < 1)
			{
				targetDist = 1;
			};
			order = [];
			i = targetDist;
			while (i <= maxSearch)
			{
				order.push(i);
				i++;
			};
			i = targetDist - 1;
			while (i >= 1)
			{
				order.push(i);
				i--;
			};
			tried = 0;
			missAlpha = 0;
			missNull = 0;
			for each (dist in order)
			{
				nx = Math.round(startX + sx * dist);
				ny = Math.round(startY + sy * dist);
				if (sx == 0)
				{
					nx = startX;
				};
				if (sy == 0)
				{
					ny = startY;
				};
				tried++;
				hit = sampleDisplayColorAt(nx, ny);
				if (hit && (((uint(hit.color) >> 24) & 0xFF) > 0))
				{
					magnifierProbeX = nx;
					magnifierProbeY = ny;
					magLastNudgeDist = dist;
					magLastNudgeTried = tried;
					
					return true;
				};
				if (!hit)
				{
					missNull++;
				}
				else
				{
					missAlpha++;
				};
			};
			magLastNudgeTried = tried;
			
			return false;
		}

		/** Pass-through: selection uses the exact magnifier texel (no neighbor snap). */
		protected function resolveSelectionHit(hit:Object):Object
		{
			return hit;
		}

		private function isPremultipliedBlackFringe(color:uint):Boolean
		{
			var alpha:uint = (color >> 24) & 0xFF;
			return alpha > 0 && alpha < 255 && ((color & 0x00FFFFFF) == 0);
		}

		protected function isNearBlackRgb(color:uint):Boolean
		{
			var r:uint = (color >> 16) & 0xFF;
			var g:uint = (color >> 8) & 0xFF;
			var b:uint = color & 0xFF;
			return (r + g + b) <= 30;
		}

		private function redrawMagnifier(bitmap:Bitmap, localX:int, localY:int):void
		{
			var g:*;
			var size:int;
			var dx:int;
			var dy:int;
			var px:int;
			var py:int;
			var color:uint;
			var cellX:Number;
			var cellY:Number;
			if (!magnifierOverlay || !bitmap || !bitmap.bitmapData)
			{
				return;
			};
			g = magnifierOverlay.graphics;
			g.clear();
			size = (MAG_RADIUS * 2) + 1;
			g.beginFill(0x000000, 0.9);
			g.drawRect(-1, -1, (size * MAG_CELL) + 2, (size * MAG_CELL) + 2);
			g.endFill();
			dy = -MAG_RADIUS;
			while (dy <= MAG_RADIUS)
			{
				dx = -MAG_RADIUS;
				while (dx <= MAG_RADIUS)
				{
					px = localX + dx;
					py = localY + dy;
					cellX = (dx + MAG_RADIUS) * MAG_CELL;
					cellY = (dy + MAG_RADIUS) * MAG_CELL;
					if (px >= 0 && py >= 0 && px < bitmap.bitmapData.width && py < bitmap.bitmapData.height)
					{
						color = bitmap.bitmapData.getPixel32(px, py);
						if (((color >> 24) & 0xFF) == 0)
						{
							g.beginFill(0x222222, 1);
						}
						else
						{
							g.beginFill(color & 0x00FFFFFF, 1);
						};
					}
					else
					{
						g.beginFill(0x111111, 1);
					};
					g.drawRect(cellX, cellY, MAG_CELL, MAG_CELL);
					g.endFill();
					dx++;
				};
				dy++;
			};
			g.lineStyle(2, 0xFF0000, 1);
			g.drawRect(MAG_RADIUS * MAG_CELL, MAG_RADIUS * MAG_CELL, MAG_CELL, MAG_CELL);
		}

		/** True when stage coords land inside the on-screen magnifier pixel map. */
		protected function isClickOnMagnifierOverlay(stageX:Number, stageY:Number):Boolean
		{
			var size:Number;
			var tl:Point;
			if (!magnifierOverlay || !magnifierOverlay.visible || !magnifierOverlay.parent)
			{
				return false;
			};
			size = ((MAG_RADIUS * 2) + 1) * MAG_CELL;
			tl = magnifierOverlay.localToGlobal(new Point(0, 0));
			return stageX >= tl.x && stageX <= (tl.x + size)
				&& stageY >= tl.y && stageY <= (tl.y + size);
		}

		/**
		 * Classic palette lookup for near-black sprite picks when orig sampling failed
		 * and findBasesForSpriteHit intentionally returned empty.
		 */
		protected function findNearBlackSelectFallback(sample:uint):Array
		{
			var classic:Array;
			var best:uint;
			var bestDist:Number;
			var baseColor:uint;
			var dist:Number;
			var out:Array;
			var block:Object;
			var colors:Array;
			var i:int;
			var candidates:Array;
			if (!currentPaletteData || !isNearBlackRgb(sample))
			{
				return [];
			};
			// 1) Exact / replacement reverse lookup — keep only near-black bases so a
			// bright member painted to black cannot win the pick.
			classic = PaletteColorAnalysis.findBaseColorsForReplacement(currentPaletteData, sample, isolateMode);
			candidates = [];
			if (classic)
			{
				for each (baseColor in classic)
				{
					if (isNearBlackRgb(uint(baseColor)) && candidates.indexOf(uint(baseColor)) == -1)
					{
						candidates.push(uint(baseColor));
					};
				};
			};
			// 2) Near-black palette bases by identity (unpainted dark outline pixels).
			for each (block in [currentPaletteData.paletteSwap, currentPaletteData.paletteSwapPA])
			{
				if (!block || !block.colors)
				{
					continue;
				};
				colors = block.colors as Array;
				i = 0;
				while (i < colors.length)
				{
					baseColor = uint(colors[i]);
					if (isNearBlackRgb(baseColor) && candidates.indexOf(baseColor) == -1)
					{
						candidates.push(baseColor);
					};
					i++;
				};
			};
			if (!candidates || candidates.length == 0)
			{
				return [];
			};
			if (candidates.length == 1)
			{
				return [uint(candidates[0])];
			};
			best = uint(candidates[0]);
			bestDist = PaletteColorAnalysis.rgbDistance(best, sample);
			for each (baseColor in candidates)
			{
				dist = PaletteColorAnalysis.rgbDistance(uint(baseColor), sample);
				if (dist < bestDist)
				{
					bestDist = dist;
					best = uint(baseColor);
				};
			};
			// Reject absurd matches (e.g. sample black → random dark navy far away).
			if (bestDist > 40)
			{
				return [];
			};
			out = [best];
			return out;
		}

		/**
		 * Choose which selected base to drop for a raw magnifier texel.
		 * Identity is the unpainted original when that swatch is selected; otherwise the
		 * selected swatch whose live display exactly matches the painted texel (prefer
		 * the base closest to the original). Never soft-match pulse/white to the whole
		 * selection — that produced bases=60 wrong picks.
		 */
		protected function pickDeselectBaseForRawHit(rawHit:Object, origBase:uint):uint
		{
			var painted:uint;
			var box:ColorSquare;
			var baseColor:uint;
			var repl:uint;
			var paintMatches:Array;
			var best:uint;
			var bestDist:Number;
			var dist:Number;
			var hasOrig:Boolean;
			if (!rawHit)
			{
				return 0;
			};
			hasOrig = (origBase != 0);
			if (hasOrig && colorIsCurrentlySelected(origBase))
			{
				return origBase;
			};
			painted = uint(rawHit.color);
			if (isNearBlackRgb(painted))
			{
				// Prefer a selected near-black identity under the crosshair.
				paintMatches = [];
				for each (box in ColorSquare.selectedBoxes)
				{
					if (!box || (box is PaletteGroupSquare))
					{
						continue;
					};
					baseColor = uint(box.colorValue);
					if (isNearBlackRgb(baseColor)
						&& PaletteColorAnalysis.rgbDistance(baseColor & 0xFFFFFF, painted & 0xFFFFFF) <= 40)
					{
						if (paintMatches.indexOf(baseColor) == -1)
						{
							paintMatches.push(baseColor);
						};
					};
				};
				if (paintMatches.length == 1)
				{
					return uint(paintMatches[0]);
				};
				if (paintMatches.length > 1)
				{
					best = uint(paintMatches[0]);
					bestDist = PaletteColorAnalysis.rgbDistance(best, painted);
					for each (baseColor in paintMatches)
					{
						dist = PaletteColorAnalysis.rgbDistance(uint(baseColor), painted);
						if (dist < bestDist)
						{
							bestDist = dist;
							best = uint(baseColor);
						};
					};
					return best;
				};
				return 0;
			};
			paintMatches = [];
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				baseColor = uint(box.colorValue);
				repl = getDisplayedReplacementForBase(baseColor);
				if (PaletteColorAnalysis.colorsMatch(repl, painted))
				{
					if (paintMatches.indexOf(baseColor) == -1)
					{
						paintMatches.push(baseColor);
					};
				};
			};
			if (paintMatches.length == 0)
			{
				return 0;
			};
			if (paintMatches.length == 1)
			{
				return uint(paintMatches[0]);
			};
			// Match-all flats share one display. Without orig, never peel "most recent" —
			// that dropped 0x31a22 (and reverted its paint) when clicking white.
			if (!hasOrig)
			{
				return 0;
			};
			best = uint(paintMatches[0]);
			bestDist = PaletteColorAnalysis.rgbDistance(best, origBase);
			for each (baseColor in paintMatches)
			{
				dist = PaletteColorAnalysis.rgbDistance(uint(baseColor), origBase);
				if (dist < bestDist)
				{
					bestDist = dist;
					best = uint(baseColor);
				};
			};
			return best;
		}

		/** True when node is root or nested under root. */
		private function displayObjectIsDescendantOf(node:DisplayObject, root:DisplayObject):Boolean
		{
			var cur:DisplayObject;
			if (!node || !root)
			{
				return false;
			};
			cur = node;
			while (cur)
			{
				if (cur == root)
				{
					return true;
				};
				cur = cur.parent;
			};
			return false;
		}

		/**
		 * True when sample matches an active/enabled match-all group's flat swatch.
		 * Those pixels cannot be identified by RGB alone (every member looks the same).
		 */
		private function sampleMatchesFlatMatchAllSwatch(sample:uint):Boolean
		{
			var group:PaletteGroupSquare;
			if (isNearBlackRgb(sample))
			{
				return false;
			};
			if (activeGroup && activeGroup.matchAllMode && activeGroup.hasSwatchColor
				&& PaletteColorAnalysis.colorsMatch(uint(activeGroup.swatchColor), sample))
			{
				return true;
			};
			for each (group in groupSquares)
			{
				if (!group || group.groupEnabled == false || !group.matchAllMode
					|| !group.hasSwatchColor)
				{
					continue;
				};
				if (PaletteColorAnalysis.colorsMatch(uint(group.swatchColor), sample))
				{
					return true;
				};
			};
			return false;
		}

		/**
		 * Read the pre-palette-swap color at the hit texel from __cachedPalette /
		 * portraitBitmapCaches / deep palette cache. Returns { color:uint } or null.
		 */
		private function sampleOriginalColorAtHit(hit:Object):Object
		{
			var detailed:Object = sampleOriginalColorAtHitDetailed(hit);
			if (!detailed || detailed.color == null)
			{
				return null;
			};
			return { "color": uint(detailed.color) };
		}

		/**
		 * Like sampleOriginalColorAtHit, but includes cacheStatus for debug:
		 * "studio" | "pixelArt" | "portrait" | "unique" | "miss" | "alpha0" | "badHit".
		 */
		private function sampleOriginalColorAtHitDetailed(hit:Object):Object
		{
			var bmp:Bitmap;
			var lx:int;
			var ly:int;
			var original:BitmapData;
			var cache:Dictionary;
			var color:uint;
			var liveW:int;
			var liveH:int;
			var status:String;
			if (!hit || !(hit.bitmap is Bitmap))
			{
				return { "color": null, "cacheStatus": "badHit" };
			};
			bmp = hit.bitmap as Bitmap;
			lx = int(hit.localX);
			ly = int(hit.localY);
			if (!bmp.bitmapData || lx < 0 || ly < 0
				|| lx >= bmp.bitmapData.width || ly >= bmp.bitmapData.height)
			{
				return { "color": null, "cacheStatus": "badHit" };
			};
			liveW = bmp.bitmapData.width;
			liveH = bmp.bitmapData.height;
			original = null;
			status = "miss";
			// Prefer studio / deep caches first — portrait bags can key the same Bitmap
			// with a mismatched size and falsely kill identity (orig=none → wrong base).
			original = PaletteDeep.getCachedOriginalBitmapData(bmp, (player && player.MC) ? player.MC : null);
			if (original && original.width == liveW && original.height == liveH)
			{
				status = "studio";
			}
			else
			{
				original = null;
				if (PixelArt)
				{
					original = PaletteDeep.getCachedOriginalBitmapData(bmp, PixelArt);
					if (original && original.width == liveW && original.height == liveH)
					{
						status = "pixelArt";
					}
					else
					{
						original = null;
					};
				};
				if (!original && PixelArtPartner)
				{
					original = PaletteDeep.getCachedOriginalBitmapData(bmp, PixelArtPartner);
					if (original && original.width == liveW && original.height == liveH)
					{
						status = "pixelArtPartner";
					}
					else
					{
						original = null;
					};
				};
			};
			// Unique strip: cover cache holds pristine bitmaps; live bmp.bitmapData is the
			// painted clone and is never registered in studio/portrait caches (orig=none).
			if (!original)
			{
				original = getUniqueSpriteCoverOriginal(bmp);
				if (original && original.width == liveW && original.height == liveH)
				{
					status = "unique";
				}
				else
				{
					original = null;
				};
			};
			// Never fall back to portrait caches for bitmaps under the studio character —
			// PA bags can share Bitmap instances / sizes and yield absurd orig (e.g.
			// live near-black + cyan orig) that steals identity for Group B picks.
			if (!original && !(player && player.MC && displayObjectIsDescendantOf(bmp, player.MC)))
			{
				for each (cache in portraitBitmapCaches)
				{
					if (cache && (cache[bmp] is BitmapData))
					{
						original = cache[bmp] as BitmapData;
						if (original && original.width == liveW && original.height == liveH)
						{
							status = "portrait";
							break;
						};
						original = null;
					};
				};
			};
			if (!original || lx >= original.width || ly >= original.height)
			{
				return { "color": null, "cacheStatus": "miss" };
			};
			color = original.getPixel32(lx, ly);
			if (((color >> 24) & 0xFF) == 0)
			{
				return { "color": null, "cacheStatus": "alpha0" };
			};
			return { "color": color, "cacheStatus": status };
		}

		/**
		 * Pristine cover BitmapData for a unique-strip live Bitmap (pre-palette clone).
		 * Bitmap-kind covers keep originals in uniquePaCoverCache; MC-kind may use
		 * Utils deep / __cachedPalette via getCachedOriginalBitmapData instead.
		 */
		private function getUniqueSpriteCoverOriginal(bmp:Bitmap):BitmapData
		{
			var i:int;
			var root:DisplayObject;
			var holder:DisplayObjectContainer;
			var child:DisplayObject;
			var cand:Object;
			var j:int;
			if (!bmp || !uniquePaSprites || !uniquePaCoverCache)
			{
				return null;
			};
			if (uniquePaHost && !displayObjectIsDescendantOf(bmp, uniquePaHost))
			{
				return null;
			};
			i = 0;
			while (i < uniquePaSprites.length && i < uniquePaCoverCache.length)
			{
				root = uniquePaSprites[i] as DisplayObject;
				cand = uniquePaCoverCache[i];
				if (root && cand && (cand.bitmapData is BitmapData))
				{
					if ((root is Bitmap) && root == bmp)
					{
						return (cand.bitmapData as BitmapData);
					};
					holder = root as DisplayObjectContainer;
					if (holder)
					{
						// Typical bitmap cover: Sprite → Bitmap child.
						if (holder.numChildren > 0 && holder.getChildAt(0) == bmp)
						{
							return (cand.bitmapData as BitmapData);
						};
						j = 0;
						while (j < holder.numChildren)
						{
							child = holder.getChildAt(j);
							if (child == bmp || displayObjectIsDescendantOf(bmp, child))
							{
								return (cand.bitmapData as BitmapData);
							};
							j++;
						};
					};
				};
				i++;
			};
			return null;
		}

		/**
		 * Resolve palette base colors for a sprite/magnifier sample.
		 * Prefers live display matches (pulse + isolate) so clicking a pulsing selection
		 * doesn't fall through to an unrelated neighbor color.
		 */
		protected function findBasesForSpriteHit(sample:uint):Array
		{
			var displayed:Array;
			var classic:Array;
			var exact:Array;
			var selectedExact:Array;
			var identity:Array;
			var baseColor:uint;
			var repl:uint;
			var box:ColorSquare;
			var block:Object;
			var colors:Array;
			var i:int;
			if (isPremultipliedBlackFringe(sample))
			{
				return [];
			};
			// Near-black paint must not reverse-map onto bright bases (match-all flats /
			// wrong portrait cache). Callers use findNearBlackSelectFallback instead.
			if (isNearBlackRgb(sample))
			{
				return [];
			};
			// Unpainted / identity pixels: sample RGB IS the palette base. Prefer that
			// over display reverse-lookup (match-all white piles) or neighbor shades.
			// Exception: match-all swatch flats every member to the same RGB — treating
			// that RGB as palette identity (e.g. white) steals picks and deselections.
			identity = [];
			if (currentPaletteData && !sampleMatchesFlatMatchAllSwatch(sample))
			{
				for each (block in [currentPaletteData.paletteSwap, currentPaletteData.paletteSwapPA])
				{
					if (!block || !block.colors)
					{
						continue;
					};
					colors = block.colors as Array;
					i = 0;
					while (i < colors.length)
					{
						baseColor = uint(colors[i]);
						if (PaletteColorAnalysis.colorsMatch(baseColor, sample)
							&& identity.indexOf(baseColor) == -1)
						{
							identity.push(baseColor);
						};
						i++;
					};
				};
			};
			if (identity.length == 1)
			{
				return identity;
			};
			if (identity.length > 1)
			{
				return collapseBasesToClosest(identity, sample);
			};
			// Prefer currently selected colors whose live display exactly matches the sample.
			// Soft RGB distance here returned bases=60 on pulse/white and stole the wrong swatch.
			selectedExact = [];
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				baseColor = uint(box.colorValue);
				repl = getDisplayedReplacementForBase(baseColor);
				if (PaletteColorAnalysis.colorsMatch(repl, sample))
				{
					if (selectedExact.indexOf(baseColor) == -1)
					{
						selectedExact.push(baseColor);
					};
				};
			};
			if (selectedExact.length == 1)
			{
				return selectedExact;
			};
			// Multiple selected with the same display — do not return the whole pile;
			// fall through so callers with an original texel can pick identity.
			displayed = findBasesMatchingDisplayedSample(sample);
			if (displayed.length > 0)
			{
				// Match-all / pulse-white can share one display across dozens of bases.
				// Without an original texel, never return the whole pile (bases=78 →
				// selectedBoxes=180 and swap/PA group desync). Collapsing a flat swatch
				// pile to "closest to white" falsely picks the white palette entry.
				if (displayed.length > 1 && sampleMatchesFlatMatchAllSwatch(sample))
				{
					return [];
				};
				return collapseBasesToClosest(displayed, sample);
			};
			classic = PaletteColorAnalysis.findBaseColorsForReplacement(currentPaletteData, sample, isolateMode);
			if (classic.length <= 1)
			{
				return classic;
			};
			// Prefer exact replacement matches over "base color equals sample" hits so a
			// recolored pixel doesn't also pull in unrelated bases that merely share RGB.
			exact = [];
			for each (baseColor in classic)
			{
				repl = getCurrentReplacementForColor(uint(baseColor));
				if (PaletteColorAnalysis.colorsMatch(repl, sample)
					|| (isolateMode && PaletteColorAnalysis.colorsMatch(PaletteColorAnalysis.darkenForIsolate(repl), sample)))
				{
					exact.push(uint(baseColor));
				};
			};
			return collapseBasesToClosest(exact.length > 0 ? exact : classic, sample);
		}

		/** When reverse-lookup finds many bases, keep the one closest to the sample RGB. */
		protected function collapseBasesToClosest(bases:Array, sample:uint):Array
		{
			var best:uint;
			var bestDist:Number;
			var baseColor:uint;
			var dist:Number;
			var repl:uint;
			if (!bases || bases.length == 0)
			{
				return [];
			};
			if (bases.length == 1)
			{
				return [uint(bases[0])];
			};
			best = uint(bases[0]);
			repl = getDisplayedReplacementForBase(best);
			bestDist = PaletteColorAnalysis.rgbDistance(repl, sample);
			for each (baseColor in bases)
			{
				repl = getDisplayedReplacementForBase(uint(baseColor));
				dist = PaletteColorAnalysis.rgbDistance(repl, sample);
				if (dist < bestDist)
				{
					bestDist = dist;
					best = uint(baseColor);
				};
			};
			return [best];
		}

		/** Bases whose current on-screen color (isolate + pulse) matches the sample. */
		private function findBasesMatchingDisplayedSample(sample:uint):Array
		{
			var out:Array = [];
			var near:Array = [];
			var block:Object;
			var colors:Array;
			var i:int;
			var baseColor:uint;
			var display:uint;
			var dist:Number;
			var bestDist:Number;
			if (!currentPaletteData)
			{
				return out;
			};
			bestDist = Number.POSITIVE_INFINITY;
			for each (block in [currentPaletteData.paletteSwap, currentPaletteData.paletteSwapPA])
			{
				if (!block || !block.colors)
				{
					continue;
				};
				colors = block.colors as Array;
				i = 0;
				while (i < colors.length)
				{
					baseColor = uint(colors[i]);
					if (out.indexOf(baseColor) != -1 || near.indexOf(baseColor) != -1)
					{
						i++;
						continue;
					};
					display = getDisplayedReplacementForBase(baseColor);
					if (PaletteColorAnalysis.colorsMatch(display, sample))
					{
						out.push(baseColor);
					}
					else
					{
						dist = PaletteColorAnalysis.rgbDistance(display, sample);
						if (dist <= 10)
						{
							near.push(baseColor);
							if (dist < bestDist)
							{
								bestDist = dist;
							};
						};
					};
					i++;
				};
			};
			if (out.length > 0)
			{
				return out;
			};
			// Soft match only while pulsing — brighten can drift a few RGB units.
			if (pulseActive && near.length > 0)
			{
				out = [];
				for each (baseColor in near)
				{
					display = getDisplayedReplacementForBase(baseColor);
					if (PaletteColorAnalysis.rgbDistance(display, sample) <= bestDist + 0.01)
					{
						out.push(uint(baseColor));
					};
				};
				return out;
			};
			return out;
		}

		/** Live studio color for a base: isolate darken + selection pulse when applicable. */
		private function getDisplayedReplacementForBase(baseColor:uint):uint
		{
			var repl:uint = getCurrentReplacementForColor(baseColor);
			var selected:Boolean;
			var pulseT:Number;
			var hl:uint;
			selected = colorIsCurrentlySelected(baseColor);
			if (isolateMode && !selected)
			{
				repl = PaletteColorAnalysis.darkenForIsolate(repl);
			}
			else if (isHoverIsolateActive() && uint(baseColor) != hoverBaseColor)
			{
				repl = PaletteColorAnalysis.darkenForIsolate(repl);
			};
			if (selectHighlightFlashActive && settingSelectHighlight && selectHighlightTargets
				&& (selectHighlightTargets[baseColor] || selectHighlightTargets[String(baseColor)]))
			{
				hl = getSelectHighlightColorForReplacement(repl);
				repl = (repl & 0xFF000000) | (hl & 0x00FFFFFF);
				if (((repl >> 24) & 0xFF) == 0)
				{
					repl = 0xFF000000 | (hl & 0x00FFFFFF);
				};
				return repl;
			};
			if (pulseActive && pulseBrightenFactor != 1 && pulseTargetColors
				&& (pulseTargetColors[baseColor] || pulseTargetColors[String(baseColor)]))
			{
				pulseT = Math.max(0, Math.min(1, (pulseBrightenFactor - 1) / (PULSE_PEAK - 1)));
				repl = PaletteColorAnalysis.blendColors(repl, PaletteColorAnalysis.complementaryColor(repl), pulseT);
			};
			return repl;
		}

		/** True during the brief first-select highlight flash. */
		protected function isSelectHighlightActive():Boolean
		{
			return settingSelectHighlight && selectHighlightFlashActive
				&& selectHighlightTargets && hasAnyKey(selectHighlightTargets);
		}

		/**
		 * Pick primary highlight, or alt when the live color is already a shade of primary
		 * (so selecting red still shows a contrast color — white by default).
		 */
		private function getSelectHighlightColorForReplacement(repl:uint):uint
		{
			if (isSelectHighlightSimilar(repl, settingSelectHighlightPrimary))
			{
				return settingSelectHighlightAlt;
			};
			return settingSelectHighlightPrimary;
		}

		private function isSelectHighlightSimilar(color:uint, highlight:uint):Boolean
		{
			var a:Object;
			var b:Object;
			var dHue:Number;
			if (PaletteColorAnalysis.colorsMatch(color, highlight))
			{
				return true;
			};
			if (PaletteColorAnalysis.rgbDistance(color & 0xFFFFFF, highlight & 0xFFFFFF) <= SELECT_HIGHLIGHT_RGB_SIMILAR)
			{
				return true;
			};
			a = HsvWheel.rgbToHsv(color);
			b = HsvWheel.rgbToHsv(highlight);
			// Neutrals (white/gray/black): only RGB proximity counts.
			if (a.s < 0.18 || b.s < 0.18 || a.v < 0.12 || b.v < 0.12)
			{
				return false;
			};
			dHue = Math.abs(Number(a.h) - Number(b.h)) % 360;
			if (dHue > 180)
			{
				dHue = 360 - dHue;
			};
			return dHue <= SELECT_HIGHLIGHT_HUE_SIMILAR;
		}

		protected function applySelectHighlightToPaletteBlock(block:Object):void
		{
			var i:int;
			var baseColor:uint;
			var repl:uint;
			var hl:uint;
			if (!block || !block.colors || !block.replacements || !selectHighlightTargets)
			{
				return;
			};
			block.replacements = (block.replacements as Array).concat();
			i = 0;
			while (i < block.colors.length && i < block.replacements.length)
			{
				baseColor = uint(block.colors[i]);
				if (selectHighlightTargets[baseColor] || selectHighlightTargets[String(baseColor)])
				{
					repl = uint(block.replacements[i]);
					hl = getSelectHighlightColorForReplacement(repl);
					block.replacements[i] = ((repl & 0xFF000000) != 0 ? (repl & 0xFF000000) : 0xFF000000)
						| (hl & 0x00FFFFFF);
				};
				i++;
			};
		}

		/** Magnifier controller-move debug. Trace always; toast only on skips / failures (throttled). */
		protected function magMoveDebug(msg:String, notify:Boolean = false):void
		{
			var now:int;
			trace("[PM MagMove] " + msg);
			if (!notify)
			{
				return;
			};
			now = getTimer();
			if ((now - magDebugLastNotifyMs) < 350)
			{
				return;
			};
			magDebugLastNotifyMs = now;
			try
			{
				Ssf2.MultiplayerManager.notify("[Mag] " + msg.substr(0, 160));
			}
			catch (err:Error)
			{
			};
		}

		protected function logMagnifierControlMove(step:Number, dStageX:int, dStageY:int,
			prevX:Number, prevY:Number, prevBmp:Bitmap, prevLX:int, prevLY:int):void
		{
			var newLX:int;
			var newLY:int;
			var dLocalX:int;
			var dLocalY:int;
			var dProbeX:int;
			var dProbeY:int;
			var sameBmp:Boolean;
			var skipped:Boolean;
			var scaleX:Number;
			var scaleY:Number;
			newLX = magnifierHit ? int(magnifierHit.localX) : -1;
			newLY = magnifierHit ? int(magnifierHit.localY) : -1;
			dLocalX = newLX - prevLX;
			dLocalY = newLY - prevLY;
			dProbeX = int(magnifierProbeX) - int(prevX);
			dProbeY = int(magnifierProbeY) - int(prevY);
			sameBmp = prevBmp != null && magnifierHit && magnifierHit.bitmap == prevBmp;
			// Walk expects ±1 texel on the same bitmap; anything larger is a skip.
			skipped = !sameBmp
				|| Math.abs(dLocalX) > 1
				|| Math.abs(dLocalY) > 1
				|| magLastNudgeDist > int(step)
				|| Math.abs(dProbeX) > int(step)
				|| Math.abs(dProbeY) > int(step);
			scaleX = 0;
			scaleY = 0;
			if (magnifierHit && magnifierHit.bitmap is Bitmap)
			{
				try
				{
					scaleX = (magnifierHit.bitmap as Bitmap).scaleX;
					scaleY = (magnifierHit.bitmap as Bitmap).scaleY;
				}
				catch (scaleErr:Error)
				{
				};
			};
			magMoveDebug("ctrlMove step=" + step
				+ " ask=(" + dStageX + "," + dStageY + ")"
				+ " via=" + magLastNudgeVia
				+ " nudgeDist=" + magLastNudgeDist
				+ " tried=" + magLastNudgeTried
				+ " probe (" + int(prevX) + "," + int(prevY) + ")->("
				+ int(magnifierProbeX) + "," + int(magnifierProbeY) + ")"
				+ " dProbe=(" + dProbeX + "," + dProbeY + ")"
				+ " texel " + prevLX + "," + prevLY + "->" + newLX + "," + newLY
				+ " dLocal=(" + dLocalX + "," + dLocalY + ")"
				+ " sameBmp=" + sameBmp
				+ " scale=" + scaleX.toFixed(2) + "x" + scaleY.toFixed(2)
				+ " dash=" + (step >= MAG_PROBE_STEP_RUN)
				+ " repeat=" + magRepeatFrames
				+ (skipped ? " SKIP" : " ok"), skipped);
		}

		/** A fast scrub across swatches applies only the last color, on the next frame. */
		protected function scheduleHoverDim():void
		{
			if (hoverDimFrame)
			{
				return;
			};
			if (!Ssf2.Main || !Ssf2.Main.Root)
			{
				return;
			};
			hoverDimFrame = true;
			Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, onHoverDimFrame);
		}

		private function onHoverDimFrame(e:Event):void
		{
			if (Ssf2.Main && Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, onHoverDimFrame);
			};
			hoverDimFrame = false;
			if (!isHoverIsolateActive())
			{
				restoreHoverBright();
				return;
			};
			applyHoverDim(hoverBaseColor);
		}

		/** Hover isolate paint: only the hovered base stays bright. Skipped during DI / sliders / pulse / select flash. */
		protected function isHoverIsolateActive():Boolean
		{
			return hoverBaseActive && !isolateMode && !draggingSlider
				&& !pulseActive && !isSelectHighlightActive();
		}

		/**
		 * Copy source costume replacements into current palette for one base color.
		 * Applies paletteSwap and paletteSwapPA independently when both define the color.
		 * Returns the value used for the swatch triangle (swap preferred, else PA).
		 */
		protected function applyReplacementsFromSource(source:Object, baseColor:uint):uint
		{
			var swapRepl:*;
			var paRepl:*;
			var display:uint;
			if (!source || !currentPaletteData)
			{
				return baseColor;
			};
			swapRepl = lookupReplacementInBlock(source.paletteSwap, baseColor);
			paRepl = lookupReplacementInBlock(source.paletteSwapPA, baseColor);
			if (swapRepl == null && paRepl == null)
			{
				return getCurrentReplacementForColor(baseColor);
			};
			if (swapRepl == null)
			{
				swapRepl = paRepl;
			};
			if (paRepl == null)
			{
				paRepl = swapRepl;
			};
			if (currentPaletteData.paletteSwap)
			{
				replaceBracket(baseColor, uint(swapRepl), currentPaletteData.paletteSwap.colors, currentPaletteData.paletteSwap.replacements);
			};
			if (currentPaletteData.paletteSwapPA)
			{
				replaceBracket(baseColor, uint(paRepl), currentPaletteData.paletteSwapPA.colors, currentPaletteData.paletteSwapPA.replacements);
			};
			palettePADirty = true;
			characterPaletteDirty = true;
			unchangedHighlightsDirty = true;
			display = uint(swapRepl);
			if (activeGroup && activeGroup.hasMember(baseColor) && canActiveGroupEditBase(baseColor))
			{
				recordGroupLayerReplacement(activeGroup, baseColor, display);
			};
			return display;
		}

		/**
		 * Costume load: keep group definitions but force disabled so layers/match-all
		 * do not paint until the user explicitly enables a group.
		 */
		protected function disableAllColorGroupsForCostumeLoad():void
		{
			var group:PaletteGroupSquare;
			var n:int;
			n = 0;
			for each (group in groupSquares)
			{
				if (group)
				{
					group.setGroupEnabled(false);
					n++;
				};
			};
			
		}

		/** Debug: detect if a later group's write mutated an earlier group's replacements. */
		protected function snapshotHigherPriorityReplacements(editingGroup:PaletteGroupSquare, label:String):void
		{
			var idx:int;
			var i:int;
			var g:PaletteGroupSquare;
			var member:*;
			var baseColor:uint;
			var repl:uint;
			var changed:int;
			var sample:Array;
			var key:String;
			if (!editingGroup || !groupSquares)
			{
				return;
			};
			idx = groupSquares.indexOf(editingGroup);
			if (idx <= 0)
			{
				return;
			};
			if (label == "preSwatch")
			{
				m_ownerReplSnapshot = {};
				i = 0;
				while (i < idx)
				{
					g = groupSquares[i] as PaletteGroupSquare;
					// Disabled earlier groups are not owners — painting their shared
					// members from a later enabled group is legitimate, not a leak.
					if (g && g.memberColors && g.groupEnabled != false)
					{
						for each (member in g.memberColors)
						{
							baseColor = uint(member);
							if (getOwnerGroupForBase(baseColor) != g)
							{
								continue;
							};
							m_ownerReplSnapshot[String(baseColor)] = getCurrentReplacementForColor(baseColor);
						};
					};
					i++;
				};
				trace("[PM Debug] " + label + " higherPriorityBases=" + countKeys(m_ownerReplSnapshot)
					+ " before " + editingGroup.groupName);
				return;
			};
			if (!m_ownerReplSnapshot)
			{
				return;
			};
			changed = 0;
			sample = [];
			for (key in m_ownerReplSnapshot)
			{
				baseColor = uint(key);
				repl = getCurrentReplacementForColor(baseColor);
				if (uint(m_ownerReplSnapshot[key]) != uint(repl))
				{
					changed++;
					if (sample.length < 8)
					{
						sample.push("0x" + baseColor.toString(16)
							+ ":" + uint(m_ownerReplSnapshot[key]).toString(16)
							+ "→" + uint(repl).toString(16));
					};
				};
			};
			
			m_ownerReplSnapshot = null;
		}

		protected function notifyOwnershipSkips(skipped:int):void
		{
			if (skipped > 0)
			{
				Ssf2.MultiplayerManager.notify("Skipped " + skipped + " colors owned by a higher layer");
				
			};
		}

		/**
		 * Dump group membership, pairwise overlap, and who owns shared bases.
		 * Trace always details; toast is a short summary (PM debug toggle).
		 */
		protected function dumpGroupOwnershipDebug(reason:String):void
		{
			var i:int;
			var j:int;
			var g:PaletteGroupSquare;
			var h:PaletteGroupSquare;
			var member:*;
			var baseColor:uint;
			var owner:PaletteGroupSquare;
			var overlap:int;
			var ownedByOther:int;
			var sample:Array;
			var line:String;
			var memberCount:int;
			if (!groupSquares)
			{
				return;
			};
			line = "ownership[" + reason + "] groups=" + groupSquares.length
				+ " active=" + (activeGroup ? activeGroup.groupName : "none");
			trace("[PM Debug] " + line);
			i = 0;
			while (i < groupSquares.length)
			{
				g = groupSquares[i] as PaletteGroupSquare;
				memberCount = g && g.memberColors ? g.memberColors.length : 0;
				trace("[PM Debug]   #" + i + " " + (g ? g.groupName : "?")
					+ " short=" + (g ? g.getShortName() : "?")
					+ " members=" + memberCount
					+ " enabled=" + (g ? g.groupEnabled : false)
					+ " matchAll=" + (g ? g.matchAllMode : false)
					+ " swatch=" + (g ? g.useSwatch : false));
				i++;
			};
			i = 0;
			while (i < groupSquares.length)
			{
				g = groupSquares[i] as PaletteGroupSquare;
				j = i + 1;
				while (j < groupSquares.length)
				{
					h = groupSquares[j] as PaletteGroupSquare;
					overlap = 0;
					ownedByOther = 0;
					sample = [];
					if (g && h && g.memberColors)
					{
						for each (member in g.memberColors)
						{
							baseColor = uint(member);
							if (!h.hasMember(baseColor))
							{
								continue;
							};
							overlap++;
							owner = getOwnerGroupForBase(baseColor);
							if (owner && owner != g)
							{
								ownedByOther++;
							};
							if (sample.length < 6)
							{
								sample.push("0x" + baseColor.toString(16)
									+ "→" + (owner ? owner.getShortName() : "?"));
							};
						};
					};
					if (overlap > 0)
					{
						trace("[PM Debug]   overlap " + (g ? g.getShortName() : "?")
							+ "∩" + (h ? h.getShortName() : "?")
							+ "=" + overlap
							+ " (notOwnedByFirst=" + ownedByOther + ")"
							+ " sample=[" + sample.join(",") + "]");
					};
					j++;
				};
				i++;
			};
			if (activeGroup && activeGroup.memberColors)
			{
				ownedByOther = 0;
				overlap = 0;
				sample = [];
				for each (member in activeGroup.memberColors)
				{
					baseColor = uint(member);
					owner = getOwnerGroupForBase(baseColor);
					overlap++;
					if (owner && owner != activeGroup)
					{
						ownedByOther++;
						if (sample.length < 8)
						{
							sample.push("0x" + baseColor.toString(16)
								+ "→" + owner.getShortName());
						};
					};
				};
				trace("[PM Debug]   activeEditable=" + (overlap - ownedByOther)
					+ "/" + overlap
					+ " blocked=" + ownedByOther
					+ (sample.length > 0 ? (" blockedSample=[" + sample.join(",") + "]") : ""));
				
			}
			else
			{
				
			};
		}

		protected function onColorSettingsStageDown(e:MouseEvent):void
		{
			if (!isColorSettingsVisible() || !colorSettingsPopup)
			{
				return;
			};
			if (colorSettingsPopup.hitTestPoint(e.stageX, e.stageY, true))
			{
				return;
			};
			if (ColorSquare.primaryPickMode)
			{
				return;
			};
			if (csEyedropperMode)
			{
				return;
			};
			closeColorSettings();
		}

		protected function closeColorSettings():void
		{
			exitPrimaryPickMode();
			csEyedropperMode = false;
			csWheelSnapshot = null;
			colorSettingsGroup = null;
			fxColorSettingsMode = false;
			if (uiKeysFrozen)
			{
				editingTextEnd(null);
			};
			if (Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onColorSettingsStageDown, true);
			};
			if (colorSettingsPopup)
			{
				colorSettingsPopup.hide();
			};
		}

		protected function adoptCurrentAsSessionSeedsForColors(colors:Array):void
		{
			var color:uint;
			var repl:uint;
			if (!sessionBaselineData || !colors)
			{
				return;
			};
			for each (color in colors)
			{
				repl = getCurrentReplacementForColor(uint(color));
				if (sessionBaselineData.paletteSwap)
				{
					replaceBracket(uint(color), repl, sessionBaselineData.paletteSwap.colors, sessionBaselineData.paletteSwap.replacements);
				};
				if (sessionBaselineData.paletteSwapPA)
				{
					replaceBracket(uint(color), repl, sessionBaselineData.paletteSwapPA.colors, sessionBaselineData.paletteSwapPA.replacements);
				};
			};
		}

		protected function onCsDontUseSwatchKeep():void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			if (!group)
			{
				Ssf2.MultiplayerManager.notify("No active group");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			group.useSwatch = false;
			group.matchAllMode = false;
			group.preSwatchReplacements = null;
			adoptCurrentAsSessionSeedsForColors(group.memberColors);
			resetSlidersToDefault();
			refreshColorSettingsHeader();
			Ssf2.MultiplayerManager.notify("Swatch off — colors kept");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			saveColorGroups();
		}
    }
}
