package com.sbxmod.paletteMaker 
{ 
    import ssf2mm.shared.HsvWheel;
    import flash.events.MouseEvent;
    import flash.events.Event;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
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

    public class PaletteMakerMenu extends PaletteMakerMenuFx  
    {

		/** True while Palette Maker is open (show → back). Used for Discord presence. */
		public static function get isSessionActive():Boolean
		{
			return sessionActive;
		}

		private var studioPickingStage:Boolean = false;

		private var stagePickBackBtn:* = null;

		private var stagePickBack:Function = null;

		/** Stage select Attack while the studio is choosing a stage. */
		public static function onStudioStageSelect(ctx:Object):void
		{
			var menu:PaletteMakerMenu;
			var stageId:String;
			menu = Ssf2.MenuController.paletteMakerMenu as PaletteMakerMenu;
			if (!menu || !menu.studioPickingStage)
			{
				return;
			};
			stageId = "";
			if (ctx && ctx.stageId)
			{
				stageId = String(ctx.stageId);
			};
			if (ctx)
			{
				ctx.cancel = true;
			};
			setTimeout(function():void
			{
				if (ctx && ctx.consume)
				{
					return;
				};
				menu.studioPickingStage = false;
				menu.finishStudioStagePick(stageId);
			}, 1);
		}

		/** Shifts the view 24px right on non-restarea studio stages; keeps the character in frame. */
		public static function nudgeStudioCamera(ctx:Object):void
		{
			var cam:*;
			var game:*;
			var stageData:*;
			var actor:*;
			var sprite:*;
			var shift:Number = 24;
			var margin:Number = 40;
			var left:Number;
			var px:Number;
			if (!sessionActive)
			{
				return;
			};
			try
			{
				game = Ssf2.GameController.currentGame;
				if (!game || !game.LevelData || String(game.LevelData.stage) == "restarea")
				{
					return;
				};
				stageData = Ssf2.GameController.stageData;
				cam = ctx ? ctx.camera : null;
				if (!cam && stageData)
				{
					cam = stageData.CamRef;
				};
				if (!cam)
				{
					return;
				};
				left = cam.CornerX + shift;
				actor = (stageData && stageData.Players) ? stageData.Players[0] : null;
				sprite = actor ? actor.m_sprite : null;
				if (!sprite && actor)
				{
					sprite = actor.MC;
				};
				if (sprite && sprite.parent)
				{
					px = sprite.x + sprite.parent.x;
					if (px < left + margin)
					{
						left = px - margin;
					};
				};
				cam.CornerX = left;
				cam.forceInBounds();
			}
			catch (camErr:Error)
			{
			};
		}
		
		private var lastLiveStatsName:String = null;
		private var historyLockedForDrag:Boolean = false;
		private var lastSelectionCount:int = 0;
		private var lastSelectedColorSet:Object = {};
		private var pendingAutoGroups:Boolean = false;
		private var autoGroupsGenerated:Boolean = false;
		private var skipSliderApplyOnce:Boolean = false;
		private var pendingUnrecoloredGroupReset:Boolean = false;
		private var pulseStartTime:int = 0;
		private var selectHighlightStartTime:int = 0;
		/** Extra plant/racket/projectile tiles beyond greedy cover. */
		private static const MAX_UNIQUE_PROP_EXTRAS:int = 10;
		/** Held props are small; skip full-body attack sheets when force-including. */
		private static const UNIQUE_PROP_MAX_AREA:int = 192 * 192;
		private const MAG_PROBE_STEP_WALK:Number = 1;
		private const PULSE_DURATION_MS:int = 1600;
		private const TOOL_IDS:Array = ["UD", "RD", "DI", "FZ", "SA", "DA", "IS", "RA", "RB", "RO", "UQ", "NG", "CS", "ST", "IC", "EC", "CO"];
		private static const SELECT_HIGHLIGHT_DURATION_MS:int = 1100;
		
		private var wasGamePaused:Boolean = false;
		private var uniquePaScanStatsName:String = null;
		private var uniquePaScanMTime:Number = 0;
		private var pendingUniquePaRefresh:Boolean = false;
		private var s_lastLoggedBakedMc:String = "";
		private var s_lastLoggedBakedHadPixels:Boolean = false;
		private var fxGroupSeq:int = 1;
		/** Cached effect-linkage cover while RE mode is on. */
		private var effectPaCoverCache:Array = null;
		
		private var colorArrowStartX:Number;
		private var colorArrowStartY:Number;
		private var brightnessArrowStartX:Number;
		private var brightnessArrowStartY:Number;
		private var saturationArrowStartX:Number;
		private var saturationArrowStartY:Number;
		private var alphaArrowStartX:Number;
		private var alphaArrowStartY:Number;
		
        public function PaletteMakerMenu()
        {
			var self:PaletteMakerMenu = this;
			openPairList = function():void
			{
				self.openPartnerPairing();
			};
            m_subMenu = Ssf2.ResourceManager.getLibraryMC("VCostumeCreatorMenu");
			m_fillBackground = false;
            m_backgroundID = "space";
            m_container.addChild(m_subMenu);
			m_subMenu.x = (Ssf2.Main.Width / 2);
            m_subMenu.y = (Ssf2.Main.Height / 2);    
			colorBoxBGStartY = m_subMenu.colorBoxBG.y;
			colorArrow = m_subMenu.colors.arrow;
			colorArrowStartX = colorArrow.x;
			colorArrowStartY = colorArrow.y;
            colorArrow.x = colorArrowStartX;
            colorArrow.y = colorArrowStartY;
			colorBounds = m_subMenu.colors.bounds;
			brightnessArrow = m_subMenu.brightness.arrow;
			brightnessArrowStartX = brightnessArrow.x;
			brightnessArrowStartY = brightnessArrow.y;
            brightnessArrow.x = brightnessArrowStartX;
            brightnessArrow.y = brightnessArrowStartY;
			brightnessBounds = m_subMenu.brightness.bounds;
			saturationArrow = m_subMenu.saturation.arrow;
			saturationArrowStartX = saturationArrow.x;
			saturationArrowStartY = saturationArrow.y;
			saturationArrow.x = saturationArrowStartX;
			saturationArrow.y = saturationArrowStartY;
			saturationBounds = m_subMenu.saturation.bounds;
			alphaArrow = m_subMenu._alpha.arrow;
			alphaArrowStartX = alphaArrow.x;
			alphaArrowStartY = alphaArrow.y;
			alphaArrow.x = alphaArrowStartX;
			alphaArrow.y = alphaArrowStartY;
			alphaBounds = m_subMenu._alpha.bounds;
			colorArrow.x = colorBounds.width;
			brightnessArrow.x = m_subMenu.brightness.width / 2;
			saturationArrow.x = m_subMenu.saturation.width / 2;
			alphaArrow.x = alphaBounds.width;
			ensureCopyToClipboardBtn();
			ensureImportFromOnlineBtn();
			ensureMagnifierOverlay();
			syncColorBoxBGStartY();
        }

        override public function show():void
        {
        	try
        	{
        		showStudio();
        	}
        	catch (err:*)
        	{
        		PaletteGuard.fail("menu show", err);
        		throw err;
        	};
        }

        private function showStudio():void
        {
			// Vault (character grid) stays live until removed — it was still clickable over the studio.
			try
			{
				if (Ssf2.MenuController && Ssf2.MenuController.vaultMenu)
				{
					Ssf2.MenuController.vaultMenu.removeSelf();
					Ssf2.gameLog("[Palette Maker] vault closed");
				};
			}
			catch (vaultErr:Error)
			{
				Ssf2.gameLog("[Palette Maker] vault close fail " + vaultErr.message);
			};
            super.show();
			loadToolSettings();
			CostumePackIO.ensureColorSheetsExtracted();
			resetColorBoxes();
			ENABLE_PIXEL_ART_LIVE_UPDATE = false;
			if (player)
			{
				player.studioDeepPalettePaint = false;
			};
			player = null;
			isolateMode = false;
			recolorEffectsMode = false;
			fxStripSelectedLinkages = {};
			activeFxGroupId = null;
			fxColorSettingsMode = false;
			clearFxGroupSquares();
			effectPaCoverCache = null;
			CostumeFxPaletteRuntime.studioAttachHarvest = null;
			magnifierHit = null;
			hideMagnifier();
			characterFrozen = false;
			freezeChordWasDown = false;
			if (Ssf2.GameController.stageData)
			{
				updateStageFreeze();
			};
			clearHistory();
			activeGroup = null;
			groupSquares = [];
			autoGroupsGenerated = false;
			pendingAutoGroups = true;
			lastSelectionCount = 0;
			lastSelectedColorSet = {};
			selectionEntryReplacements = {};
			historyLockedForDrag = false;
			hueSliderTouched = false;
			palettePADirty = true;
			characterPaletteDirty = true;
			uiHidden = false;
			clearUniquePaSprites();
			uniquePaCoverCache = null;
			uniquePaScanStatsName = null;
			uniquePaScanMTime = 0;
			var rmCostume:Object = null;
			try { rmCostume = Ssf2.ResourceManager.getCostume(statsName, null); } catch(err:Error) { }
			var loadedBaseCostumeData:Object = getPaletteMakerBaseCostumeData(statsName, rmCostume);
			baseCostumeData = Ssf2.Utils.cloneObject(loadedBaseCostumeData);
			mixedBasePaletteData = mixArrays(loadedBaseCostumeData.paletteSwap.colors, loadedBaseCostumeData.paletteSwapPA.colors);
			currentPaletteData = Ssf2.Utils.cloneObject(loadedBaseCostumeData);
			PaletteMakerUtils.cacheDebugLog("Editor show stats=" + statsName
				+ " declinedBatch=" + PaletteMakerUtils.userDeclinedBatchCache);
			mixedBaseRgbSet = null;
			invalidateHotPalettes();
			discoverAndMergeMissingSwatchColors();
			refreshSheetPaletteOrder();
			// One form on screen. Partner palette comes from pairing on save.
			altSwatchColors = null;
			makeColorBoxes(mixedBasePaletteData);
			rebuildMixedBaseRgbSet();
			sessionBaselineData = clonePaletteSnapshot(currentPaletteData);
			m_subMenu.slotName.text = PaletteMakerUtils.DEFAULT_COSTUME_NAME;
			setAuthorNameText("");
			refreshAllSwatchTriangles();
			Ssf2.Utils.setBrightness(m_subMenu.save_btn, -75);
			startGame(null);
			sessionActive = true;
			pushPaletteMakerDiscordPresence();
			if (settingAlwaysIsolate)
			{
				setIsolateMode(true);
			};
			updateDefaultToolHint();
			pmPauseLetGo = true;
			m_padFocus = 0;
			syncPauseEnabledWithUi();
			studioSessionSuppress = true;
			beginStudioErrorSuppress();
			PaletteMakerAchievements.resetSession();
        }

        override public function makeEvents():void
        {
            if (m_showCount == 0)
            {
                findSubMenuButtons();
                findSpecificMenuButtons(m_subMenu.bg_top);
            };
            super.makeEvents();
            resetAllButtons();
			m_subMenu.bg_top.back_btn.addEventListener(MouseEvent.CLICK, this.back_CLICK);
			m_subMenu.save_btn.addEventListener(MouseEvent.CLICK, this.saveCostume_CLICK);
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				// High capture priority so Ctrl+S beats game/UI KEY_DOWN handlers.
				Ssf2.Main.Root.stage.addEventListener(KeyboardEvent.KEY_DOWN, onPmKeyDown, true, 100, true);
			};
			if (copyToClipboardBtn)
			{
				copyToClipboardBtn.addEventListener(MouseEvent.CLICK, this.exportCostume_CLICK);
			};
			if (importFromOnlineBtn)
			{
				importFromOnlineBtn.addEventListener(MouseEvent.CLICK, this.importFromOnline_CLICK);
			};
			m_subMenu.locker_btn.addEventListener(MouseEvent.CLICK, this.locker_CLICK);
			m_subMenu.slotName.addEventListener(FocusEvent.FOCUS_IN, editingTextStart);
			m_subMenu.slotName.addEventListener(FocusEvent.FOCUS_OUT, editingTextEnd);
			m_subMenu.slotName.addEventListener(Event.CHANGE, checkCostumeName);
			if (m_subMenu.authorName)
			{
				m_subMenu.authorName.addEventListener(FocusEvent.FOCUS_IN, editingTextStart);
				m_subMenu.authorName.addEventListener(FocusEvent.FOCUS_OUT, editingTextEnd);
			};
			colorArrow.addEventListener(MouseEvent.MOUSE_DOWN, startDragColorArrow);
			brightnessArrow.addEventListener(MouseEvent.MOUSE_DOWN, startDragBrightnessArrow);
			saturationArrow.addEventListener(MouseEvent.MOUSE_DOWN, startDragSaturationArrow);
			alphaArrow.addEventListener(MouseEvent.MOUSE_DOWN, startDragAlphaArrow);
			wireSliderDoubleClick(true);
            m_subMenu.addEventListener(MouseEvent.MOUSE_UP, stopDragArrow);
			Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_UP, stopDragArrow);
            Ssf2.Main.Root.stage.addEventListener(Event.ENTER_FRAME, manageMenuMappings);
			Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_MOVE, stage_MOUSE_MOVE);
			Ssf2.Main.Root.stage.addEventListener(MouseEvent.CLICK, stage_CLICK);
			ColorSquare.onSelectionChanged = onColorSelectionChanged;
			ColorSquare.onHoverChanged = onSwatchHoverChanged;
			ColorSquare.canInteract = isSwatchInteractionAllowed;
			Ssf2.HudMenu.beforeSnapshot = onPaletteMakerBeforeSnapshot;
			Ssf2.HudMenu.afterSnapshot = onPaletteMakerAfterSnapshot;
			studioSessionSuppress = true;
			beginStudioErrorSuppress();
        }

        override public function killEvents():void
        {
            super.killEvents();
			sessionActive = false;
			endStudioErrorSuppress();
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onPmKeyDown, true);
			};
			closeShortcutsPopup();
			closeAchievementsPopup();
			destroyMcNameDropdown();
			m_subMenu.bg_top.back_btn.removeEventListener(MouseEvent.CLICK, this.back_CLICK);
			m_subMenu.save_btn.removeEventListener(MouseEvent.CLICK, this.saveCostume_CLICK);
			if (copyToClipboardBtn)
			{
				copyToClipboardBtn.removeEventListener(MouseEvent.CLICK, this.exportCostume_CLICK);
			};
			if (importFromOnlineBtn)
			{
				importFromOnlineBtn.removeEventListener(MouseEvent.CLICK, this.importFromOnline_CLICK);
			};
			closeImportCodePastePopup();
			m_subMenu.locker_btn.removeEventListener(MouseEvent.CLICK, this.locker_CLICK);
			m_subMenu.slotName.removeEventListener(FocusEvent.FOCUS_IN, editingTextStart);
			m_subMenu.slotName.removeEventListener(FocusEvent.FOCUS_OUT, editingTextEnd);
			m_subMenu.slotName.removeEventListener(Event.CHANGE, checkCostumeName);
			if (m_subMenu.authorName)
			{
				m_subMenu.authorName.removeEventListener(FocusEvent.FOCUS_IN, editingTextStart);
				m_subMenu.authorName.removeEventListener(FocusEvent.FOCUS_OUT, editingTextEnd);
			};
			colorArrow.removeEventListener(MouseEvent.MOUSE_DOWN, startDragColorArrow);
			brightnessArrow.removeEventListener(MouseEvent.MOUSE_DOWN, startDragBrightnessArrow);
			saturationArrow.removeEventListener(MouseEvent.MOUSE_DOWN, startDragSaturationArrow);
			alphaArrow.removeEventListener(MouseEvent.MOUSE_DOWN, startDragAlphaArrow);
			wireSliderDoubleClick(false);
			m_subMenu.removeEventListener(MouseEvent.MOUSE_UP, stopDragArrow);
			Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_UP, stopDragArrow);
			Ssf2.Main.Root.stage.removeEventListener(Event.ENTER_FRAME, manageMenuMappings);
			Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_MOVE, stage_MOUSE_MOVE);
			Ssf2.Main.Root.stage.removeEventListener(MouseEvent.CLICK, stage_CLICK);
			ColorSquare.onSelectionChanged = null;
			ColorSquare.onHoverChanged = null;
			ColorSquare.canInteract = null;
			clearPaletteHoverIsolate();
			if (Ssf2.HudMenu.beforeSnapshot == onPaletteMakerBeforeSnapshot)
			{
				Ssf2.HudMenu.beforeSnapshot = null;
			};
			if (Ssf2.HudMenu.afterSnapshot == onPaletteMakerAfterSnapshot)
			{
				Ssf2.HudMenu.afterSnapshot = null;
			};
			destroyPauseToys();
			closeColorSettings();
			cancelSelectionPulse(false);
			hideMagnifier();
			if (isolateMode)
			{
				isolateMode = false;
				refreshIsolateSwatchVisuals();
			};

			for(var i:int = 0; i < m_subMenu.colorBoxBG.numChildren; i++) 
			{
				var colorBox:ColorSquare = m_subMenu.colorBoxBG.getChildAt(i) as ColorSquare;
				if (colorBox)
				{
					colorBox.killEvents();
				};
			};
			
        }

		private function wireSliderDoubleClick(enable:Boolean):void
		{
			var targets:Array = [colorArrow, brightnessArrow, saturationArrow, alphaArrow, colorBounds, brightnessBounds, saturationBounds, alphaBounds];
			var target:MovieClip;
			for each (target in targets)
			{
				if (!target)
				{
					continue;
				};
				target.doubleClickEnabled = enable;
				if (enable)
				{
					target.addEventListener(MouseEvent.DOUBLE_CLICK, slider_DOUBLE_CLICK);
				}
				else
				{
					target.removeEventListener(MouseEvent.DOUBLE_CLICK, slider_DOUBLE_CLICK);
				};
			};
		}

		private function updateCharacter(e:Event):void
		{
			try
			{
				updateCharacterFrame(e);
			}
			catch (err:*)
			{
				PaletteGuard.fail("menu updateCharacter", err);
			};
		}

		private function updateCharacterFrame(e:Event):void
		{
			try {
				var stagePlayer:* = ((Ssf2.GameController.stageData) && (Ssf2.GameController.stageData.Players)) ? Ssf2.GameController.stageData.Players[0] : null;
				if(stagePlayer == null)
				{
					return;
				};
				if(player !== stagePlayer)
				{
					player = stagePlayer;
					player.studioDeepPalettePaint = true;
					try
					{
						if (selectedMcName)
						{
							syncPlayerCostumeForMcName(selectedMcName);
						}
						else
						{
							player.setCostumeAPI(-2);
							if (studioGameCostumeIndex >= -1)
							{
								player.CostumeID = studioGameCostumeIndex;
							};
						};
					}
					catch(ignore:Error) { }
					suppressPaletteMakerCompanions(player);
					characterPaletteDirty = true;
					lastLiveStatsName = null;
					tryGenerateAutoGroups();
					if (characterFrozen)
					{
						try
						{
							player.FreezePlayback = true;
							characterFreezeX = player.getX();
							characterFreezeY = player.getY();
						}
						catch (rebindFreezeErr:Error)
						{
						};
						updateStageFreeze();
					};
					if (studioSessionSuppress)
					{
						beginStudioErrorSuppress();
					};
				}
				else
				{
					suppressPaletteMakerCompanions(player);
				}
				try
				{
					var liveBefore:String = activeFighterForm;
					refreshActiveFighterForm();
					if (activeFighterForm != liveBefore)
					{
						lastLiveStatsName = activeFighterForm;
						characterPaletteDirty = true;
						palettePADirty = true;
					};
				}
				catch (statsErr:Error)
				{
				};
				maintainGigaStudioForm();
				syncStudioPartnerCostume(player);
				syncStudioPartnerBody(player);
				if (pendingSkipCountdown)
				{
					trySkipPostEntranceCountdown();
				};
				try {
					if (m_game && m_game.LevelData && String(m_game.LevelData.stage) == "restarea" && player.getX() > 434.25) { player.setX(-24.4); }
					// Pulse ENTER_FRAME owns its temporary repaint; do not duplicate it here.
					if (!pulseActive)
					{
						applyActivePalettes(palettePADirty);
						palettePADirty = false;
					};
					// RE studio: projectiles/stage + linkage-gated fighter FX children (never root MC).
					if (recolorEffectsMode)
					{
						applyRecolorEffectsFiltersToStrip();
						applyRecolorEffectsFiltersToLiveProjectiles();
						applyRecolorEffectsFiltersToFighterChildren();
					};
				} catch(err:Error) {
				}
				rememberStudioSong();
				if (m_game && m_game.LevelData && String(m_game.LevelData.stage) != "restarea")
				{
					matchRestAreaZoom();
					anchorPortraitOnce();
				};
				if (pendingAutoGroups && !autoGroupsGenerated)
				{
					tryGenerateAutoGroups();
				};
				if (pendingUniquePaRefresh && settingShowUniquePaSprites && player)
				{
					pendingUniquePaRefresh = false;
					refreshUniquePaSprites(false);
				}
				else if (uniquePaRelayoutFrames > 0 && uniquePaHost && uniquePaSprites && uniquePaSprites.length > 0)
				{
					uniquePaRelayoutFrames--;
					layoutAllUniquePaSprites(null);
				};
				if (unchangedHighlightsDirty && !draggingSlider && !pulseActive)
				{
					refreshUnchangedHighlights();
				};
				flushDebouncedUniquePaint();
				if (magnifierInputActive && player)
				{
					if (Ssf2.GameController.stageData)
					{
						Ssf2.GameController.stageData.FreezeKeys = true;
					};
					try
					{
						player.setX(magnifierFreezeX);
						player.setY(magnifierFreezeY);
					}
					catch (freezeErr:Error)
					{
					};
				};
				if (characterFrozen && player)
				{
					try
					{
						player.FreezePlayback = true;
						player.setX(characterFreezeX);
						player.setY(characterFreezeY);
						if (characterFreezeScale > 0)
						{
							player.SizeRatio = characterFreezeScale;
						};
					}
					catch (charFreezeErr:Error)
					{
					};
				};
				updateMagnifierControls();
				handleFreezeChord();
				handleFrozenStudioControls();
				if (settingDiscordCostumePreview && PixelArt)
				{
					DiscordCostumePresence.tickPaletteMaker(PixelArt,
						(statsName ? statsName : "character") + " — " + String(m_subMenu && m_subMenu.slotName ? m_subMenu.slotName.text : "Editing"));
				};
				handlePaletteMakerPauseToggle();
				syncPauseOverlayUi();
			} catch(errAll:Error) {
			}
		}

		private function handlePaletteMakerPauseToggle():void
		{
			var startDown:Boolean;
			if (uiKeysFrozen || !player || !player.ControlSettings)
			{
				return;
			};
			try
			{
				startDown = player.ControlSettings.IsDown(player.ControlSettings._START);
			}
			catch (err:Error)
			{
				return;
			};
			if (!startDown)
			{
				pmPauseLetGo = true;
				return;
			};
			if (!pmPauseLetGo)
			{
				return;
			};
			pmPauseLetGo = false;
			if (!uiHidden)
			{
				hidePaletteMakerUi();
				try
				{
					player.PauseLetGo = false;
				}
				catch (plErr:Error)
				{
				};
			};
		}

		public static function setCharacter(charName:String):void
		{
			statsName = charName;
		}

		private function setRecolorEffectsMode(on:Boolean):void
		{
			var groups:Array;
			recolorEffectsMode = on;
			if (!on)
			{
				// Keep effectPaCoverCache for fast RE re-enter; clear body cover so it reloads.
				uniquePaCoverCache = null;
				fxStripSelectedLinkages = {};
				fxColorSettingsMode = false;
				activeFxGroupId = null;
				CostumeFxPaletteRuntime.studioAttachHarvest = null;
			}
			else
			{
				// Drop body unique cover so refresh loads effect strip (session/disk cache).
				// Also drop stale session effect cover so beam rescan can run.
				uniquePaCoverCache = null;
				effectPaCoverCache = null;
				CostumeFxPaletteRuntime.studioAttachHarvest = harvestStudioAttachFxLinkage;
			};
			refreshToggleToolVisuals();
			// forceRescan=false: hit disk/session effect cache when fresh.
			refreshUniquePaSprites(false);
			if (on)
			{
				hueSliderTouched = true;
				if (currentPaletteData)
				{
					FxRecolorUtils.ensureFxGroups(currentPaletteData);
					groups = currentPaletteData.fxGroups as Array;
					if (groups && groups.length > 0 && !activeFxGroupId)
					{
						activeFxGroupId = String(groups[0].id);
					};
				};
				ensureActiveFxGroup();
				syncRecolorEffectsSlidersFromFxFields();
				writeRecolorEffectsFxFields();
				wireFxStripClickHandlers();
				refreshFxStripHighlights();
				syncEffectsModeSwatchUi(true);
				applyRecolorEffectsFiltersPreview();
				
			}
			else
			{
				clearRecolorEffectsFiltersPreview();
				syncEffectsModeSwatchUi(false);
				
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		/** RE slider path: write active fx group + filter preview. */
		private function reapplyRecolorEffectsFxFromSliders(onlyColors:Object = null):void
		{
			if (!currentPaletteData)
			{
				return;
			};
			if (!ensureActiveFxGroup())
			{
				
				return;
			};
			writeRecolorEffectsFxFields();
			applyRecolorEffectsFiltersPreview();
			
		}

		/** Filter preview on effect strip + owned projectiles — never player.MC / body swatches. */
		private function applyRecolorEffectsFiltersPreview():void
		{
			var fields:Object;
			applyRecolorEffectsFiltersToStrip();
			applyRecolorEffectsFiltersToLiveProjectiles();
			fields = getRecolorEffectsEngineAdjust();
			
		}

		/** Studio: tint fighter FX children matching fxGroups (same path as match runtime). */
		private function applyRecolorEffectsFiltersToFighterChildren():void
		{
			var root:DisplayObject;
			var aliases:Object;
			var tinted:int;
			var baked:int;
			var linkageTinted:Dictionary;
			if (!recolorEffectsMode || !currentPaletteData || !player)
			{
				return;
			};
			if (!FxRecolorUtils.costumeHasFxAdjust(currentPaletteData))
			{
				return;
			};
			root = null;
			try
			{
				if (player.MC is DisplayObject)
				{
					root = player.MC as DisplayObject;
				};
			}
			catch (mcErr:Error)
			{
				root = null;
			};
			if (!root)
			{
				return;
			};
			aliases = getProjectileFxAliasMapCached();
			linkageTinted = new Dictionary(true);
			tinted = FxRecolorUtils.applyFxGroupsToFighterDisplayTree(
				root, currentPaletteData, aliases, 8, 250, statsName, linkageTinted);
			baked = FxRecolorUtils.applyFxGroupsToFighterBakedMc(
				root, currentPaletteData, linkageTinted, 10, 500, statsName);
			if (tinted > 0)
			{
				
			};
			// Rate-limit studio fx-swap spam: once per mc name, again when bitmaps painted.
			if (FxRecolorUtils.lastFxSwapName
				&& (FxRecolorUtils.lastFxSwapName != s_lastLoggedBakedMc
					|| (FxRecolorUtils.lastFxSwapBitmaps > 0 && !s_lastLoggedBakedHadPixels)))
			{
				if (FxRecolorUtils.lastFxSwapName != s_lastLoggedBakedMc)
				{
					s_lastLoggedBakedHadPixels = false;
				};
				s_lastLoggedBakedMc = FxRecolorUtils.lastFxSwapName;
				if (FxRecolorUtils.lastFxSwapBitmaps > 0)
				{
					s_lastLoggedBakedHadPixels = true;
				};
				
			}
			else if (FxRecolorUtils.lastFxSwapSkipReason
				&& FxRecolorUtils.lastFxSwapSkipReason != s_lastLoggedBakedMc)
			{
				s_lastLoggedBakedMc = FxRecolorUtils.lastFxSwapSkipReason;
				
			};
		}

		private function wireFxStripClickHandlers():void
		{
			var i:int;
			var disp:DisplayObject;
			if (!uniquePaSprites)
			{
				return;
			};
			i = 0;
			while (i < uniquePaSprites.length)
			{
				disp = uniquePaSprites[i] as DisplayObject;
				if (disp)
				{
					disp.addEventListener(MouseEvent.CLICK, onFxStripSpriteClick, false, 0, true);
					try
					{
						disp.buttonMode = true;
						disp.mouseEnabled = true;
						if (disp is DisplayObjectContainer)
						{
							(disp as DisplayObjectContainer).mouseChildren = false;
						};
					}
					catch (err:Error)
					{
					};
				};
				i++;
			};
		}

		private function onFxStripSpriteClick(e:MouseEvent):void
		{
			var disp:DisplayObject;
			var linkage:String;
			var group:Object;
			if (!recolorEffectsMode)
			{
				return;
			};
			disp = e.currentTarget as DisplayObject;
			if (!disp)
			{
				return;
			};
			e.stopPropagation();
			linkage = resolveFxStripLinkage(disp);
			if (!linkage)
			{
				return;
			};
			if (fxStripSelectedLinkages[linkage])
			{
				delete fxStripSelectedLinkages[linkage];
			}
			else
			{
				fxStripSelectedLinkages[linkage] = true;
			};
			// If this linkage already belongs to a saved group, activate that group.
			if (currentPaletteData)
			{
				group = FxRecolorUtils.findFxGroupForLinkage(currentPaletteData, linkage);
				if (group && (group.linkages as Array) && (group.linkages as Array).indexOf(linkage) >= 0)
				{
					activeFxGroupId = String(group.id);
					syncRecolorEffectsSlidersFromFxFields();
					rebuildFxGroupSquares();
				};
			};
			refreshFxStripHighlights();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			
		}

		private function createFxGroupFromStripSelection():void
		{
			var links:Array;
			var k:String;
			var group:Object;
			var groups:Array;
			if (!currentPaletteData)
			{
				return;
			};
			links = [];
			for (k in fxStripSelectedLinkages)
			{
				if (fxStripSelectedLinkages[k] && links.indexOf(k) < 0)
				{
					links.push(k);
				};
			};
			if (links.length == 0)
			{
				Ssf2.MultiplayerManager.notify("Select effect sprites first");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			FxRecolorUtils.ensureFxGroups(currentPaletteData);
			groups = currentPaletteData.fxGroups as Array;
			group = {
				id: "fxg_" + (fxGroupSeq++),
				name: "FX group " + (groups.length + 1),
				linkages: links,
				color: 0,
				hue: getRecolorEffectsHueDegrees(),
				saturation: pmLevelToEngineAdjust(getCurrentSaturationLevel()),
				brightness: 0,
				contrast: pmLevelToEngineAdjust(getCurrentBrightnessLevel())
			};
			group = FxRecolorUtils.coerceFxGroup(group, groups.length);
			groups.push(group);
			currentPaletteData.fxGroups = groups;
			activeFxGroupId = String(group.id);
			fxStripSelectedLinkages = {};
			writeRecolorEffectsFxFields();
			syncRecolorEffectsSlidersFromFxFields();
			rebuildFxGroupSquares();
			refreshFxStripHighlights();
			applyRecolorEffectsFiltersPreview();
			Ssf2.MultiplayerManager.notify("FX group: " + group.name + " (" + links.length + ")");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			
		}

		private function selectAllFxStripSprites():void
		{
			var i:int;
			var disp:DisplayObject;
			var linkage:String;
			fxStripSelectedLinkages = {};
			if (!uniquePaSprites)
			{
				return;
			};
			i = 0;
			while (i < uniquePaSprites.length)
			{
				disp = uniquePaSprites[i] as DisplayObject;
				linkage = resolveFxStripLinkage(disp);
				if (linkage)
				{
					fxStripSelectedLinkages[linkage] = true;
				};
				i++;
			};
			refreshFxStripHighlights();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			
		}

		/** Hide body swatches/color groups in RE; show FX group chips instead. */
		private function syncEffectsModeSwatchUi(effectsOn:Boolean):void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var group:PaletteGroupSquare;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is PaletteToolSquare)
				{
					i++;
					continue;
				};
				if (child is PaletteGroupSquare)
				{
					group = child as PaletteGroupSquare;
					// Body color groups vs FX chips (tagged).
					if (group.pmFxGroupId)
					{
						group.visible = effectsOn;
					}
					else
					{
						group.visible = !effectsOn;
					};
				}
				else if (child is ColorSquare)
				{
					box = child as ColorSquare;
					box.visible = !effectsOn;
				};
				i++;
			};
			if (effectsOn)
			{
				rebuildFxGroupSquares();
			}
			else
			{
				clearFxGroupSquares();
				layoutGroupRow();
			};
			layoutToolRow();
			refreshColorBoxScroll();
		}

		private function rebuildFxGroupSquares():void
		{
			var groups:Array;
			var i:int;
			var entry:Object;
			var chip:PaletteGroupSquare;
			var face:uint;
			var rowY:Number;
			clearFxGroupSquares();
			if (!recolorEffectsMode || !currentPaletteData || !m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			FxRecolorUtils.ensureFxGroups(currentPaletteData);
			groups = currentPaletteData.fxGroups as Array;
			if (!groups)
			{
				return;
			};
			rowY = fixedRowBelowSwatches();
			i = 0;
			while (i < groups.length)
			{
				entry = groups[i];
				if (!entry)
				{
					i++;
					continue;
				};
				face = PaletteMakerUtils.coerceColorValue(entry.color);
				if ((face & 0x00FFFFFF) == 0)
				{
					face = 0xFF44CCFF;
				};
				chip = new PaletteGroupSquare([face], BOX_SIZE, onFxGroupChipActivate,
					entry.name ? String(entry.name) : ("FX " + (i + 1)), null, null);
				chip.pmFxGroupId = String(entry.id);
				chip.primaryColor = face;
				chip.hasSwatchColor = (PaletteMakerUtils.coerceColorValue(entry.color) & 0x00FFFFFF) != 0;
				chip.swatchColor = face;
				chip.useSwatch = chip.hasSwatchColor;
				chip.redrawFace(face, face);
				chip.x = BOX_POS_X + i * (BOX_SIZE + BOX_OFFSET);
				chip.y = rowY;
				chip.visible = true;
				if (activeFxGroupId && String(entry.id) == String(activeFxGroupId))
				{
					chip.setSelected(true);
				};
				m_subMenu.colorBoxBG.addChild(chip);
				fxGroupSquares.push(chip);
				i++;
			};
			layoutToolRow();
		}

		private function onFxGroupChipActivate(group:PaletteGroupSquare):void
		{
			var i:int;
			var chip:PaletteGroupSquare;
			var id:String;
			if (!group)
			{
				return;
			};
			id = group.pmFxGroupId ? String(group.pmFxGroupId) : null;
			if (!id)
			{
				return;
			};
			activeFxGroupId = id;
			i = 0;
			while (i < fxGroupSquares.length)
			{
				chip = fxGroupSquares[i] as PaletteGroupSquare;
				if (chip)
				{
					chip.setSelected(String(chip.pmFxGroupId) == id);
				};
				i++;
			};
			syncRecolorEffectsSlidersFromFxFields();
			refreshFxStripHighlights();
			applyRecolorEffectsFiltersPreview();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function buildEffectSpriteCover():Array
		{
			var linkages:Array;
			var out:Array;
			var projFirst:Array;
			var vfxFirst:Array;
			var other:Array;
			var linkage:String;
			var cand:Object;
			var i:int;
			var seen:Object;
			var low:String;
			seen = {};
			projFirst = [];
			vfxFirst = [];
			other = [];
			linkages = collectEffectRecolorLinkages();
			i = 0;
			while (i < linkages.length)
			{
				linkage = String(linkages[i]);
				i++;
				if (!linkage)
				{
					continue;
				};
				low = linkage.toLowerCase();
				if (seen[low])
				{
					continue;
				};
				seen[low] = true;
				if (isUnsafeUniqueSpriteLinkage(linkage))
				{
					continue;
				};
				if (isBodyOrPortraitUniqueLinkage(linkage) || isLocomotionOrHurtUniqueLinkage(linkage)
					|| isPaDuplicateLinkage(linkage))
				{
					continue;
				};
				cand = {
					"kind": "linkage",
					"linkage": linkage,
					"used": false
				};
				if (isProjectileStatsLinkage(linkage))
				{
					projFirst.push(cand);
				}
				else if (isVfxUniqueLinkage(linkage)
					|| low.indexOf("effect_") == 0 || low.indexOf("trail_") == 0)
				{
					vfxFirst.push(cand);
				}
				else
				{
					other.push(cand);
				};
			};
			out = projFirst.concat(vfxFirst).concat(other);
			if (out.length > MAX_EFFECT_COVER_SPRITES)
			{
				out = out.slice(0, MAX_EFFECT_COVER_SPRITES);
			};
			
			return out;
		}

		/** Pad 2 uses pad 1's bindings for this match. Leaving the studio puts pad 2 back. */
		private function bindStudioMirrorInput():void
		{
			var pads:*;
			var leadPad:*;
			var followPad:*;
			try
			{
				pads = Ssf2.SaveData.Controllers;
				if (!pads || pads.length < 1 || !pads[0])
				{
					return;
				};
				leadPad = pads[0];
				Ssf2.ModHost.mirrorInput = leadPad;
				if (pads.length < 2 || !pads[1])
				{
					Ssf2.gameLog("[Palette Maker] pair puppet pad n=0");
					return;
				};
				followPad = pads[1];
				if (!studioPad2Saved)
				{
					studioPadBackup = followPad.getControls();
					studioPad2Gamepad = followPad.GamepadInstance;
					studioPad2Saved = true;
				};
				followPad.setControls(leadPad.getControls());
				followPad.GamepadInstance = leadPad.GamepadInstance;
				Ssf2.gameLog("[Palette Maker] pair puppet pad n=" + pads.length);
			}
			catch (err:Error)
			{
				Ssf2.gameLog("[Palette Maker] pair puppet mirror missing");
			};
		}

		private function clearStudioMirrorInput():void
		{
			var pads:*;
			try
			{
				Ssf2.ModHost.mirrorInput = null;
			}
			catch (err:Error)
			{
			};
			if (!studioPad2Saved)
			{
				return;
			};
			try
			{
				pads = Ssf2.SaveData.Controllers;
				if (pads && pads.length > 1 && pads[1])
				{
					pads[1].setControls(studioPadBackup);
					pads[1].GamepadInstance = studioPad2Gamepad;
				};
			}
			catch (err2:Error)
			{
			};
			studioPadBackup = null;
			studioPad2Gamepad = null;
			studioPad2Saved = false;
		}

		/** Same costume index on the partner is that form's side of the pair. */
		private function syncStudioPartnerCostume(lead:*):void
		{
			var stageData:*;
			var partner:*;
			var slot:int;
			if (!lead || !LinkedFormPaint.studioMirrorPartner(statsName))
			{
				return;
			};
			stageData = Ssf2.GameController.stageData;
			if (!stageData || !stageData.Players || stageData.Players.length < 2)
			{
				return;
			};
			partner = stageData.Players[1];
			if (!partner || partner == lead)
			{
				return;
			};
			try
			{
				slot = int(lead.CostumeID);
				if (int(partner.CostumeID) == slot)
				{
					return;
				};
				partner.setCostumeAPI(slot);
				partner.CostumeID = slot;
				Ssf2.gameLog("[Palette Maker] pair puppet costume=" + slot);
			}
			catch (err:Error)
			{
			};
		}

		/** Training puts player 2 on team 2 at a different spawn. Both stay on team 1 at player 1's spot. */
		private function syncStudioPartnerBody(lead:*):void
		{
			var stageData:*;
			var partner:*;
			var settings:*;
			if (!lead || !LinkedFormPaint.studioMirrorPartner(statsName))
			{
				return;
			};
			stageData = Ssf2.GameController.stageData;
			if (!stageData || !stageData.Players || stageData.Players.length < 2)
			{
				return;
			};
			partner = stageData.Players[1];
			if (!partner || partner == lead)
			{
				return;
			};
			try
			{
				if (int(lead.Team) != 1)
				{
					lead.Team = 1;
				};
				if (int(partner.Team) != 1)
				{
					partner.Team = 1;
				};
				if (m_game && m_game.LevelData)
				{
					m_game.LevelData.teamDamage = false;
				};
				if (m_game && m_game.PlayerSettings && m_game.PlayerSettings.length > 1)
				{
					m_game.PlayerSettings[0].team = 1;
					m_game.PlayerSettings[1].team = 1;
					settings = m_game.PlayerSettings;
				};
				partner.setHumanControl(true, 1);
				if (!studioPartnerTeamLogged)
				{
					studioPartnerTeamLogged = true;
					Ssf2.gameLog("[Palette Maker] pair puppet team=1 attack=0 human=1");
				};
				if (!studioPartnerSpawned)
				{
					partner.setX(lead.getX());
					partner.setY(lead.getY());
					if (settings)
					{
						settings[1].x_start = settings[0].x_start;
						settings[1].y_start = settings[0].y_start;
						settings[1].x_respawn = settings[0].x_respawn;
						settings[1].y_respawn = settings[0].y_respawn;
					};
					studioPartnerSpawned = true;
					Ssf2.gameLog("[Palette Maker] pair puppet spawn");
				};
			}
			catch (bodyErr:Error)
			{
			};
		}

		private function startGame(e:MouseEvent):void
		{
			var mirrorPartner:String = LinkedFormPaint.studioMirrorPartner(statsName);
			m_game = new (Ssf2.Game as Class)(mirrorPartner ? 2 : 1, Ssf2.Mode.TRAINING);
			loadToolSettings();
			if (settingRestAreaMusicIndex >= 0 && settingRestAreaMusicIndex < REST_AREA_MUSIC.length)
			{
				restAreaMusicIndex = settingRestAreaMusicIndex;
			}
			else
			{
				restAreaMusicIndex = Ssf2.Utils.randomInteger(0, REST_AREA_MUSIC.length - 1);
			};
			applyCharacterStudio(statsName);
			m_game.LevelData.stage = settingStudioStage ? settingStudioStage : "restarea";
			if (settingStudioSong)
			{
				m_game.LevelData.musicOverride = settingStudioSong;
				try { Ssf2.ModHost.door("applyStudioSong", [settingStudioSong], false); } catch (songErr:Error) {}
			}
			else if (String(m_game.LevelData.stage) == "restarea")
			{
				m_game.LevelData.musicOverride = REST_AREA_MUSIC[restAreaMusicIndex];
			}
			else
			{
				m_game.LevelData.musicOverride = "";
				try { Ssf2.ModHost.door("clearStudioSong", [], false); } catch (clearErr:Error) {}
			};
			m_game.LevelData.randSeed = Ssf2.Utils.randomInteger(1, 1000);
			m_game.UsingLives = false;
			m_game.UsingTime = false;
			m_game.UsingStamina = false;
			m_game.DamageRatio = 1;
			m_game.StartDamage = 0;
			m_game.FinalSmashMeter = (statsName == "gigabowser");
			armStudioMatchKeep();
			m_game.ScoreDisplay = false;
			m_game.HudDisplay = false;
			m_game.PauseEnabled = false;
			if (m_game.LevelData)
			{
				m_game.LevelData.pauseEnabled = false;
			};
			m_game.LevelData.showEntrances = true;
			m_game.LevelData.showCountdown = false;
			m_game.LevelData.showCountdownType = 2;
			pendingSkipCountdown = true;
			m_game.ItemFrequency = 0;
			Ssf2.Utils.setRandSeed(m_game.LevelData.randSeed);
			m_game.PlayerSettings[0].character = LinkedFormPaint.spawnStatsName(statsName);
			m_game.PlayerSettings[0].costume = -1;
			m_game.PlayerSettings[0].team = 1;
			m_game.LevelData.teamDamage = false;
			studioPartnerSpawned = false;
			studioPartnerTeamLogged = false;
			if (mirrorPartner)
			{
				m_game.PlayerSettings[1].character = mirrorPartner;
				m_game.PlayerSettings[1].costume = -1;
				m_game.PlayerSettings[1].human = true;
				m_game.PlayerSettings[1].team = 1;
				bindStudioMirrorInput();
				Ssf2.gameLog("[Palette Maker] pair puppet partner=" + mirrorPartner);
			}
			else
			{
				clearStudioMirrorInput();
			};
			gigaStudioFinal = false;
			gigaPrevInRevival = false;
			gigaFinalDelayFrames = 0;
			if (settingRestAreaTodIndex >= 0 && settingRestAreaTodIndex < REST_AREA_TOD_FRAMES.length)
			{
				restAreaTodIndex = settingRestAreaTodIndex;
			}
			else
			{
				restAreaTodIndex = 1;
			};
			ensureRestAreaGlobals();
			var toLoad:Array = [m_game.LevelData.stage].concat(REST_AREA_MUSIC);
			// Always reload the studio character (and linked partner). Rest-area load can
			// unload older character SSFs via ResourceManager CHARACTER_LIMIT, which left
			// getLibraryMC(LinkageID) null → InteractiveSprite addChild crash.
			// Expansions use xp_* pool ids (e.g. sonic_clone → xp_SFC_sonic), not statsName.
			if (statsName)
			{
				var charIds:Array = [statsName];
				var partner:String = PaletteMakerUtils.getLinkedFormPartner(statsName);
				if (partner)
				{
					charIds.push(partner);
				};
				var scanName:String = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
				if (scanName && scanName != statsName && charIds.indexOf(scanName) < 0)
				{
					charIds.push(scanName);
				};
				toLoad = toLoad.concat(PaletteMakerUtils.toCharacterResourceIds(charIds));
			};
			Ssf2.ResourceManager.queueResources(toLoad);
			// Outro covers stage load (Vault already started intro with show=true).
			PaletteMakerUtils.showPaletteMakerLoadingScreen(statsName, false);
			Ssf2.ResourceManager.load({"oncomplete":startMatch,"flushUnused":true});
		}

		private function startMatch(e:*=null):void
		{
			ensureRestAreaGlobals();
			try {
				Ssf2.GameController.startMatch(m_game);
			} catch(err:Error) {
				trace("[Palette Maker] startMatch error:", err.message);
			}
			if (player)
			{
				player.studioDeepPalettePaint = false;
			};
			player = null;
			PaletteMakerUtils.removeAllChildrenMC(m_backgroundContainer);
			PaletteMakerUtils.ensureFront(m_subMenu, Ssf2.GameController.stage);
			restAreaMod();
			if (m_game && m_game.LevelData && String(m_game.LevelData.stage) == "restarea")
			{
				if (restAreaTodIndex >= 0 && restAreaTodIndex < REST_AREA_TOD_FRAMES.length)
				{
					applyRestAreaTimeOfDay(int(REST_AREA_TOD_FRAMES[restAreaTodIndex]));
				};
			}
			else
			{
				matchRestAreaZoom();
			};
			// Studio ready — clear cover so entrance isn't buried by black outro frames.
			PaletteLoadingScreen.revealStudioFromLoadingScreen();
			pushPaletteMakerDiscordPresence();
		}


		private var studioPadsLogged:Boolean = false;

		private var studioMatchListenerArmed:Boolean = false;

		private var gigaStudioFinal:Boolean = false;

		private var gigaLiveLogged:String = "";

		private var studioGameCostumeIndex:int = -1000;

		private var gigaPrevInRevival:Boolean = false;

		private var gigaFinalDelayFrames:int = 0;

		private static const GIGA_FINAL_DELAY_FRAMES:int = 45;

		private var portraitAnchored:Boolean = false;

		private var portraitStillY:Number = NaN;

		private var portraitStillFrames:int = 0;

		private var spawnNudged:Boolean = false;

		private var spawnNudgeWait:int = 0;

		private var spawnNudgeBase:Number = 0;

		private var spawnNudgeBaseY:Number = 0;

		private var studioHideEndBanner:Boolean = false;

		private function restAreaMod():void
		{
			try
			{
				_restAreaModBody();
			}
			catch (restModErr:Error)
			{
				Ssf2.gameLog("[Palette Maker] restAreaMod err=" + restModErr.message);
			};
		}

		private function _restAreaModBody():void
		{
			var samplesContainer:MovieClip = Ssf2.ResourceManager.getLibraryMC("samplesContainer");
			var stageClip:* = Ssf2.GameController.stage;
			var stageTerrain:* = stageClip ? stageClip.terrain : null;
			var stageForeground:* = stageClip ? stageClip.foreground : null;
			var stageBackground:* = stageClip ? stageClip.background : null;
			var restArea:Boolean = m_game && m_game.LevelData && String(m_game.LevelData.stage) == "restarea";
			var host:* = stageBackground ? stageBackground : stageClip;
			if (!samplesContainer)
			{
				Ssf2.gameLog("[Palette Maker] restAreaMod no samplesContainer");
				return;
			};
			samplesContainer.name = "samplesContainer";
			PixelArtPartner = null;
			if (statsName == "gigabowser")
			{
				PixelArt = null;
			}
			else
			{
				PixelArt = Ssf2.ResourceManager.getExpansionPortraitMC(statsName, Ssf2.ResourceManager.ALIGN_BOTTOM)
					|| Ssf2.ResourceManager.getLibraryMC(statsName + "_classic_trophy")
					|| Ssf2.ResourceManager.getLibraryMC("placeholder_classic_trophy");
			};
			if (restArea && stageTerrain)
			{
				try
				{
					if (stageTerrain.telepad) stageTerrain.telepad.x = 1200;
					if (stageTerrain.camBoundary)
					{
						stageTerrain.camBoundary.y = -116.7;
						stageTerrain.camBoundary.height = 394;
						stageTerrain.camBoundary.width = 478.15;
					};
				}
				catch (restTerrainErr:Error)
				{
				};
				if (stageForeground && stageForeground.trophies)
				{
					stageForeground.trophies.x = 1200;
				};
				if (stageBackground && stageBackground.trophies)
				{
					stageBackground.trophies.x = 1200;
				};
			}
			else
			{
				studioPadsLogged = false;
				portraitAnchored = false;
				portraitStillFrames = 0;
				portraitStillY = NaN;
				spawnNudged = false;
				spawnNudgeWait = 0;
				spawnNudgeBase = 0;
				spawnNudgeBaseY = 0;
				parkTelepads();
			};
			if (host)
			{
				host.addChild(samplesContainer);
			};
			PAContainer = samplesContainer;
			PAContainer.scaleX = 0.598;
			PAContainer.scaleY = 0.598;
			if (restArea)
			{
				PAContainer.x = 120.45;
				PAContainer.y = -66;
			}
			else
			{
				placePortraitOnStage(PAContainer, host, stageTerrain);
			};
			try {
				var placeholder:MovieClip = MovieClip(PAContainer.placeholder);
				while (placeholder && placeholder.numChildren > 0)
				{
					placeholder.removeChildAt(0);
				};
				if (PixelArt)
				{
					if (PixelArt.hasOwnProperty("stop"))
					{
						try { PixelArt.stop(); } catch(ignore:Error) {}
					};
					if (PixelArt.hasOwnProperty("gotoAndStop"))
					{
						try { PixelArt.gotoAndStop(1); } catch(ignore:Error) {}
					};
					preparePortraitClip(PixelArt);
					PixelArt.x = 0;
					PixelArt.y = 0;
					placeholder.addChild(PixelArt);
				};
			} catch (err:Error) {
				if (statsName != "gigabowser")
				{
					try {
						PixelArt = Ssf2.ResourceManager.getLibraryMC("placeholder_classic_trophy");
						PixelArtPartner = null;
						var placeholder2:MovieClip = MovieClip(PAContainer.placeholder);
						while (placeholder2 && placeholder2.numChildren > 0)
						{
							placeholder2.removeChildAt(0);
						};
						placeholder2.addChild(PixelArt);
					} catch (err2:Error) {
					};
				};
			}
			Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, updateCharacter);
			Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, updateCharacter);
			palettePADirty = true;
			characterPaletteDirty = true;
			lastLiveStatsName = null;
			if (currentPaletteData && PixelArt)
			{
				applyActivePalettes(true);
			};
			tryGenerateAutoGroups();
			uniquePaCoverCache = null;
			uniquePaCoverAll = null;
			uniquePaScanStatsName = null;
			uniquePaScanMTime = 0;
			if (settingShowUniquePaSprites)
			{
				pendingUniquePaRefresh = true;
			};
			setupMcNameDropdown();

		}

		private function placePortraitOnStage(portrait:MovieClip, host:*, terrain:*):void
		{
			if (!portrait)
			{
				return;
			};
			portrait.x = 80;
			portrait.y = -20;
			portrait.visible = false;
		}

		private function parkTelepads():void
		{
			var stageClip:* = Ssf2.GameController.stage;
			var moved:int = 0;
			if (!stageClip)
			{
				return;
			};
			moved += parkTelepadNode(stageClip, 0);
			try { moved += parkTelepadNode(stageClip.terrain, 0); } catch (terrainErr:Error) {}
			try { moved += parkTelepadNode(stageClip.foreground, 0); } catch (foreErr:Error) {}
			try { moved += parkTelepadNode(stageClip.background, 0); } catch (backErr:Error) {}
			if (!studioPadsLogged)
			{
				studioPadsLogged = true;
				Ssf2.gameLog("[Palette Maker] studio pads moved=" + moved + " stage=" + (m_game && m_game.LevelData ? m_game.LevelData.stage : ""));
			};
		}

		private function parkTelepadNode(node:*, depth:int):int
		{
			var i:int;
			var n:int;
			var child:*;
			var name:String;
			var moved:int = 0;
			if (!node || depth > 5)
			{
				return 0;
			};
			try
			{
				if (node.telepad)
				{
					node.telepad.x = 10000;
					node.telepad.y = 10000;
					moved++;
				};
			}
			catch (propErr:Error)
			{
			};
			n = 0;
			try
			{
				n = int(node.numChildren);
			}
			catch (countErr:Error)
			{
				return moved;
			};
			i = 0;
			while (i < n)
			{
				child = node.getChildAt(i);
				name = child && child.name ? String(child.name).toLowerCase() : "";
				if (name.indexOf("telepad") >= 0 || name.indexOf("teleporter") >= 0)
				{
					child.x = 10000;
					child.y = 10000;
					moved++;
				}
				else
				{
					moved += parkTelepadNode(child, depth + 1);
				};
				i++;
			};
			return moved;
		}

		private function anchorPortraitOnce():void
		{
			var host:*;
			var sprite:*;
			var sx:Number;
			var sy:Number;
			if (portraitAnchored || !PAContainer || !player)
			{
				return;
			};
			sprite = null;
			try
			{
				sprite = player.m_sprite;
			}
			catch (spriteErr:Error)
			{
			};
			if (!sprite)
			{
				try
				{
					sprite = player.MC;
				}
				catch (mcErr:Error)
				{
				};
			};
			if (!sprite || !sprite.parent)
			{
				return;
			};
			sx = sprite.x;
			sy = sprite.y;
			try
			{
				if (!player.inState(Ssf2.CState.IDLE) || Math.abs(Number(player.getYSpeed())) > 2)
				{
					portraitStillFrames = 0;
					portraitStillY = sy;
					PAContainer.visible = false;
					return;
				};
			}
			catch (landErr:Error)
			{
				PAContainer.visible = false;
				return;
			};
			if (isNaN(portraitStillY) || Math.abs(sy - portraitStillY) > 2)
			{
				portraitStillY = sy;
				portraitStillFrames = 0;
				PAContainer.visible = false;
				return;
			};
			portraitStillFrames++;
			if (!LinkedFormPaint.portraitHoldReady(true, 0, sy - portraitStillY, portraitStillFrames))
			{
				PAContainer.visible = false;
				return;
			};
			host = sprite.parent;
			if (PAContainer.parent)
			{
				PAContainer.parent.removeChild(PAContainer);
			};
			host.addChild(PAContainer);
			var paOffset:Number = 12;
			if (statsName == "dedede")
			{
				paOffset = 32;
			};
			if (statsName == "ichigo")
			{
				paOffset = -6;
			};
			PAContainer.x = sx + paOffset;
			PAContainer.y = sy;
			try
			{
				var box:Rectangle = PAContainer.getBounds(host);
				PAContainer.y += sy - box.bottom;
				box = PAContainer.getBounds(host);
				var marker:MovieClip = new MovieClip();
				marker.x = box.x + box.width * 0.5;
				marker.y = box.bottom;
				marker.cam_width = box.width > 220 ? 220 : box.width;
				marker.cam_height = box.height > 260 ? 260 : box.height;
				marker.mouseEnabled = false;
				marker.mouseChildren = false;
				host.addChild(marker);
				var stageClip:* = Ssf2.GameController.stage;
				if (stageClip && stageClip != host)
				{
					var world:Point = host.localToGlobal(new Point(PAContainer.x, PAContainer.y));
					var local:Point = stageClip.globalToLocal(world);
					stageClip.addChild(PAContainer);
					PAContainer.x = local.x;
					PAContainer.y = local.y;
				};
				var cam:* = Ssf2.GameController.stageData ? Ssf2.GameController.stageData.CamRef : null;
				if (cam)
				{
					cam.addTarget(marker);
				};
			}
			catch (boundsErr:Error)
			{
			};
			PAContainer.visible = true;
			PAContainer.mouseEnabled = false;
			PAContainer.mouseChildren = false;
			if (!spawnNudged)
			{
				spawnNudged = true;
				try
				{
					if (studioSpawnNudge(statsName) != 0)
					{
						player.setX(sx + studioSpawnNudge(statsName));
					};
				}
				catch (nudgeErr:Error)
				{
				};
			};
			portraitAnchored = true;
			uniquePaLayoutPasses = 0;
			uniquePaLastPackW = 0;
			uniquePaRelayoutFrames = 8;
			Ssf2.gameLog("[Palette Maker] studio portrait x=" + int(PAContainer.x) + " y=" + int(PAContainer.y) + " spawn=" + int(sx) + "," + int(sy) + " pa=" + paOffset + " nudge=" + studioSpawnNudge(statsName));
		}

		private function matchRestAreaZoom():void
		{
			var cam:*;
			var minZoom:Number;
			try
			{
				cam = Ssf2.GameController.stageData ? Ssf2.GameController.stageData.CamRef : null;
				minZoom = statsName == "gigabowser" ? 560 : 300;
				if (cam && cam.MinZoomHeight != minZoom)
				{
					cam.MinZoomHeight = minZoom;
					Ssf2.gameLog("[Palette Maker] studio zoom min=" + minZoom);
				};
			}
			catch (zoomErr:Error)
			{
			};
		}

		private function studioSpawnNudge(who:String):Number
		{
			if (who == "bowser")
			{
				return -56;
			};
			if (who == "dedede")
			{
				return -32;
			};
			if (who == "ichigo")
			{
				return -91;
			};
			if (who == "chibirobo" || who == "captainfalcon" || who == "tails" || who == "ganondorf")
			{
				return -16;
			};
			if (who == "samus")
			{
				return 8;
			};
			return 0;
		}

		private function rememberStudioSong():void
		{
			var song:* = Ssf2.ModHost.door("studioSongId", [], "");
			var id:String = song ? String(song) : "";
			if (!id || id == "null" || id == settingStudioSong)
			{
				return;
			};
			settingStudioSong = id;
			saveCharacterStudio(statsName, settingStudioStage, id);
			trace("[Palette Maker] studio song " + id);
		}

		private function openStudioJukebox():void
		{
			var opened:* = false;
			try
			{
				opened = Ssf2.ModHost.door("openMatchJukebox", [], false);
			}
			catch (jukeboxErr:Error)
			{
				opened = false;
			};
			if (opened != true)
			{
				Ssf2.MultiplayerManager.notify("Jukebox is not available");
			};
		}

		private function widenStudioBounds():void
		{
			var stageData:*;
			var bounds:*;
			stageData = Ssf2.GameController.stageData;
			bounds = stageData ? stageData.DeathBounds : null;
			if (!bounds)
			{
				return;
			};
			try
			{
				if (!studioPadsLogged)
				{
					Ssf2.gameLog("[Palette Maker] studio bounds x=" + int(bounds.x) + " w=" + int(bounds.width));
				};
				bounds.x = -20000;
				bounds.width = 40000;
			}
			catch (boundsErr:Error)
			{
			};
		}

		private function refreshActiveFighterForm():String
		{
			var currentName:String;
			var characterName:String;
			var form:String;
			currentName = "";
			characterName = "";
			try
			{
				if (player && player.CurrentStatsName)
				{
					currentName = String(player.CurrentStatsName);
				};
			}
			catch (currentErr:*)
			{
			};
			try
			{
				if (player && player.CharacterStats && player.CharacterStats.StatsName)
				{
					characterName = String(player.CharacterStats.StatsName);
				};
			}
			catch (characterErr:*)
			{
			};
			form = LinkedFormPaint.fighterForm(currentName, characterName, statsName, PaletteMakerUtils.getLinkedFormPartner(statsName));
			if (form != activeFighterForm)
			{
				activeFighterForm = form;
				Ssf2.gameLog("[Palette Maker] live form=" + form);
			};
			return form;
		}

		private function armStudioMatchKeep():void
		{
			var stage:*;
			if (studioMatchListenerArmed)
			{
				return;
			};
			stage = Ssf2.GameController.stageData;
			if (!stage)
			{
				return;
			};
			try
			{
				stage.addEventListener("gameEnded", keepStudioMatch);
				studioMatchListenerArmed = true;
			}
			catch (armErr:Error)
			{
			};
		}

		private function keepStudioMatch(e:* = null):void
		{
			var stage:*;
			if (!sessionActive)
			{
				return;
			};
			stage = Ssf2.GameController.stageData;
			if (!stage)
			{
				return;
			};
			stage.GameEnded = false;
			stage.GameEndedExit = false;
			studioHideEndBanner = true;
			Ssf2.gameLog("[Palette Maker] studio match kept");
		}


		private function locker_CLICK(e:MouseEvent):void
		{
			Ssf2.MenuController.costumeSelectorDisplay.returnToLocalListOnVaultExit = false;
			Ssf2.MenuController.costumeSelectorDisplay.setCharacter(statsName, 0, true, true);
			Ssf2.MenuController.costumeSelectorDisplay.forceRefresh();
			Ssf2.MenuController.costumeSelectorDisplay.onClickContainer = _onClickContainer;
			Ssf2.MenuController.costumeSelectorDisplay.onCloseMenu = _onCloseMenu;
			freezeKeys(true);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.unlock("ritual_locker");
		}

		private function _onClickContainer():void
		{
			var getSelectedCostume:int;
			var loadedCostume:Object;
			var partnerCostume:Object;
			var partner:String;
			var costumeName:String;
			var ps:Object;
			var psPA:Object;
			var mixedPairs:Array;
			var matches:Array;
			cancelSelectionPulse(false);
			if (Ssf2.MenuController.costumeSelectorDisplay.isNoRecolorSelected())
			{
				rememberStudioCostumeIndex(-1);
				pushUndoSnapshot();
				applyIdentityPaletteFromCurrentBases();
				sessionBaselineData = clonePaletteSnapshot(currentPaletteData);
				m_subMenu.slotName.text = PaletteMakerUtils.NO_RECOLOR_COSTUME_NAME;
				setAuthorNameText("");
				checkCostumeName(null);
				clearSelectionEntryReplacements();
				deselectActiveGroupsOnCostumeSwitch();
				resortColorSwatchLayout();
				// Keep live color groups — do not clear/reload on recolor switch.
				layoutGroupRow();
				syncMcNameFromCostume(null);
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				Ssf2.MenuController.costumeSelectorDisplay.closeAfterPick();
				return;
			};
			// Prefer the selector's costume object (covers team / metal slots appended in browse mode).
			loadedCostume = Ssf2.MenuController.costumeSelectorDisplay.getSelectedCostumeData();
			getSelectedCostume = Ssf2.MenuController.costumeSelectorDisplay.getSelectedCostume();
			if (!loadedCostume)
			{
				loadedCostume = Ssf2.ResourceManager.getCostume(statsName, null, getSelectedCostume);
			};
			if (!loadedCostume)
			{
				loadedCostume = getPaletteMakerBaseCostumeData(statsName, null);
			};

			costumeName = (loadedCostume && loadedCostume.hasOwnProperty("profile")) ? loadedCostume.profile : PaletteMakerUtils.DEFAULT_COSTUME_NAME;
			ps   = normalizePaletteBlock(loadedCostume.paletteSwap);
			psPA = normalizePaletteBlock(loadedCostume.paletteSwapPA);
			notifyFlashSafeNudgeIfNeeded(
				CostumePackIO.nudgeExtremeReplacementsForVanilla(ps)
				+ CostumePackIO.nudgeExtremeReplacementsForVanilla(psPA));
			mixedPairs = mixColorPairs(ps.colors.concat(psPA.colors), ps.replacements.concat(psPA.replacements));
			matches = [];
			pushUndoSnapshot();
			// No-recolor first (paint now), then the new costume — otherwise the
			// previous recolor sticks on cached sprite art until a later frame.
			resetStudioVisualToNoRecolor();
			rememberStudioCostumeIndex(getSelectedCostume);
			if (currentPaletteData)
			{
				ensurePaletteBlocks(currentPaletteData);
				currentPaletteData.paletteSwapFX = normalizePaletteBlock(loadedCostume.paletteSwapFX);
				syncFxColorsIntoSwatches(currentPaletteData.paletteSwapFX);
			};
			for each(var pair:Object in mixedPairs)
			{
				var colorValue:uint = uint(pair.color);
				var replacementValue:uint = uint(pair.replacement);
				if (currentPaletteData)
				{
					if (!paletteBlockHasColor(currentPaletteData.paletteSwap, colorValue))
					{
						appendExactPair(currentPaletteData.paletteSwap, colorValue, replacementValue);
					};
					if (!paletteBlockHasColor(currentPaletteData.paletteSwapPA, colorValue))
					{
						appendExactPair(currentPaletteData.paletteSwapPA, colorValue, replacementValue);
					};
				};
				matches.push({color: colorValue, replacement: replacementValue});
			};
			trace("[palette_maker] costume pairs=" + mixedPairs.length);
			for each(var match:Object in matches)
			{
				// recordLayer false — locker paint is the costume, not group layer.
				updatePaletteColor(match.color, match.replacement, false);
				for(var i:int = 0; i < m_subMenu.colorBoxBG.numChildren; i++)
				{
					var child:DisplayObject = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						var colorBox:ColorSquare = child as ColorSquare;
						if (PaletteColorAnalysis.colorsMatch(uint(colorBox.colorValue), uint(match.color)))
						{
							colorBox.updateIndicator(match.replacement);
						};
					};
				};
			}
			clearGroupSessionPaintAfterCostumeLoad();
			sessionBaselineData = clonePaletteSnapshot(currentPaletteData);
			m_subMenu.slotName.text = costumeName;
			setAuthorNameText(PaletteMakerUtils.extractAuthorFromCostume(loadedCostume));
			checkCostumeName(null);
			clearSelectionEntryReplacements();
			deselectActiveGroupsOnCostumeSwitch();
			resortColorSwatchLayout();
			// Keep live color groups — do not clear/reload on recolor switch.
			layoutGroupRow();
			characterPaletteDirty = true;
			applyActivePalettes(true);
			syncMcNameFromCostume(loadedCostume);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			Ssf2.MenuController.costumeSelectorDisplay.closeAfterPick();
		}

		/** Locker / costume switch: clear to no-recolor on the fighter before the next costume paints. */
		private function resetStudioVisualToNoRecolor():void
		{
			rememberStudioCostumeIndex(-1);
			try
			{
				if (player)
				{
					player.setCostumeAPI(-2);
					player.CostumeID = -1;
				};
			}
			catch (resetErr:Error)
			{
			};
			applyIdentityPaletteFromCurrentBases(true);
		}

		/** Drop group swatch/layer paint so enable cannot re-bake the prior costume. */
		private function clearGroupSessionPaintAfterCostumeLoad():void
		{
			var group:PaletteGroupSquare;
			if (!groupSquares)
			{
				return;
			};
			for each (group in groupSquares)
			{
				ColorGroupPersist.clearSessionPaint(group);
			};
		}

		/**
		 * Locker pick: stop editing any color group. Chips stay; membership stays.
		 * deselectAll must be suppressed or sync empties the group.
		 */
		private function deselectActiveGroupsOnCostumeSwitch():void
		{
			activeGroup = null;
			clearGroupSelections();
			suppressSelectionSideEffects = true;
			ColorSquare.deselectAll();
			suppressSelectionSideEffects = false;
			refreshPrimaryBadges();
			refreshPriorityMarkers();
			updateDefaultToolHint();
		}

		private function applyIdentityPaletteFromCurrentBases(paintNow:Boolean = true):void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var baseColor:uint;
			if (!currentPaletteData)
			{
				return;
			};
			if (currentPaletteData.paletteSwap && currentPaletteData.paletteSwap.colors)
			{
				currentPaletteData.paletteSwap.replacements = Ssf2.Utils.cloneObject(currentPaletteData.paletteSwap.colors);
			};
			if (currentPaletteData.paletteSwapPA && currentPaletteData.paletteSwapPA.colors)
			{
				currentPaletteData.paletteSwapPA.replacements = Ssf2.Utils.cloneObject(currentPaletteData.paletteSwapPA.colors);
			};
			if (currentPaletteData.paletteSwapFX && currentPaletteData.paletteSwapFX.colors)
			{
				currentPaletteData.paletteSwapFX.replacements = Ssf2.Utils.cloneObject(currentPaletteData.paletteSwapFX.colors);
			};
			characterPaletteDirty = true;
			palettePADirty = true;
			unchangedHighlightsDirty = true;
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare && !(child is PaletteGroupSquare))
				{
					box = child as ColorSquare;
					baseColor = uint(box.colorValue);
					box.updateIndicator(baseColor);
				};
				i++;
			};
			if (paintNow)
			{
				applyActivePalettes(true);
			};
		}

        private function startDragColorArrow(event:MouseEvent):void
		{
			if (isColorSettingsVisible() && !recolorEffectsMode)
			{
				return;
			};
			hueSliderTouched = true;
			beginSliderDrag();
            colorArrow.startDrag(false, new Rectangle(colorArrowStartX, colorArrowStartY, colorBounds.width, 0));
            m_subMenu.addEventListener(MouseEvent.MOUSE_MOVE, updateColor);
        }
	
        private function updateColor(e:MouseEvent):void 
		{
            reapplyAllSlidersFromSessionSeeds();
        }
	
        private function startDragBrightnessArrow(event:MouseEvent):void 
		{
			if (isColorSettingsVisible() && !recolorEffectsMode)
			{
				return;
			};
			beginSliderDrag();
            brightnessArrow.startDrag(false, new Rectangle(brightnessArrowStartX, brightnessArrowStartY, brightnessBounds.width, 0));
			m_subMenu.addEventListener(MouseEvent.MOUSE_MOVE, updateBrightness);
        }
	
		private function updateBrightness(e:MouseEvent) : void
		{
			var level:Number = getCurrentBrightnessLevel();
			reapplyAllSlidersFromSessionSeeds();
			TextField(m_subMenu.brightness.lvl_txt).text = level.toFixed(2);
		}
	
        private function startDragSaturationArrow(event:MouseEvent):void
		{
			if (isColorSettingsVisible() && !recolorEffectsMode)
			{
				return;
			};
			beginSliderDrag();
            saturationArrow.startDrag(false, new Rectangle(saturationArrowStartX, saturationArrowStartY, saturationBounds.width, 0));
			m_subMenu.addEventListener(MouseEvent.MOUSE_MOVE, updateSaturation);
        }
	
		private function updateSaturation(e:MouseEvent) : void
		{
			var level:Number = getCurrentSaturationLevel();
			reapplyAllSlidersFromSessionSeeds();
			TextField(m_subMenu.saturation.lvl_txt).text = level.toFixed(2);
		}
	
        private function startDragAlphaArrow(event:MouseEvent):void
		{
			if (isColorSettingsVisible())
			{
				return;
			};
			beginSliderDrag();
            alphaArrow.startDrag(false, new Rectangle(alphaArrowStartX, alphaArrowStartY, alphaBounds.width, 0));
			m_subMenu.addEventListener(MouseEvent.MOUSE_MOVE, updateAlpha);
        }
	
		private function updateAlpha(e:MouseEvent) : void
		{
			var level:Number = getCurrentAlphaLevel();
			reapplyAllSlidersFromSessionSeeds();
			TextField(m_subMenu._alpha.lvl_txt).text = level.toFixed(2);
		}
	
        private function stopDragArrow(event:MouseEvent):void 
		{
			if (!draggingSlider)
			{
				return;
			};
			draggingSlider = false;
			dragSeedColors = null;
            colorArrow.stopDrag();
            brightnessArrow.stopDrag();
			saturationArrow.stopDrag();
			alphaArrow.stopDrag();
            m_subMenu.removeEventListener(MouseEvent.MOUSE_MOVE, updateColor);
            m_subMenu.removeEventListener(MouseEvent.MOUSE_MOVE, updateBrightness);
			m_subMenu.removeEventListener(MouseEvent.MOUSE_MOVE, updateSaturation);
			m_subMenu.removeEventListener(MouseEvent.MOUSE_MOVE, updateAlpha);
			invalidateHotPalettes();
			if(!ENABLE_PIXEL_ART_LIVE_UPDATE)
			{
				applyActivePalettes(true);
			};
			ensureGroupAfterRecolor();
			refreshUnchangedHighlights();
		}

		private function beginSliderDrag():void
		{
			var i:int;
			var box:ColorSquare;
			var baseColor:uint;
			// RE mode: allow HSBC while ColorSettings is open (FX color + sliders together).
			if (isColorSettingsVisible() && !recolorEffectsMode)
			{
				return;
			};
			cancelSelectionPulse(true);
			cancelSelectHighlightFlash(true);
			pushUndoSnapshot();
			draggingSlider = true;
			dragSeedColors = {};
			i = 0;
			while (i < ColorSquare.selectedBoxes.length)
			{
				box = ColorSquare.selectedBoxes[i];
				if (box && !(box is PaletteGroupSquare))
				{
					baseColor = uint(box.colorValue);
					dragSeedColors[String(baseColor)] = getSessionReplacementForColor(baseColor);
				};
				i++;
			};
		}

		private function reapplyAllSlidersFromSessionSeeds(onlyColors:Object = null):void
		{
			var i:int;
			var box:ColorSquare;
			var selectedBoxColor:*;
			var seedColor:*;
			var replacement:*;
			var brightnessLevel:Number;
			var saturationLevel:Number;
			var alphaLevel:Number;
			var hueFactor:*;
			var baseColor:uint;
			var dbgSkipNull:int = 0;
			var dbgSkipOnly:int = 0;
			var dbgSkipNotInBase:int = 0;
			var dbgSkipLocked:int = 0;
			var dbgSkipOwned:int = 0;
			var dbgApplied:int = 0;
			var dbgSample:String = "";
			var owner:PaletteGroupSquare;
			if (pulseActive)
			{
				cancelSelectionPulse(false);
			};
			if (selectHighlightFlashActive)
			{
				cancelSelectHighlightFlash(false);
			};
			if (!mixedBasePaletteData || !currentPaletteData)
			{
				return;
			};
			if (recolorEffectsMode)
			{
				reapplyRecolorEffectsFxFromSliders(onlyColors);
				return;
			};
			brightnessLevel = getCurrentBrightnessLevel();
			saturationLevel = getCurrentSaturationLevel();
			alphaLevel = getCurrentAlphaLevel();
			hueFactor = hueSliderTouched ? getCurrentHueFactor() : null;
			i = 0;
			while (i < ColorSquare.selectedBoxes.length)
			{
				box = ColorSquare.selectedBoxes[i];
				if (!box || (box is PaletteGroupSquare))
				{
					dbgSkipNull++;
					i++;
					continue;
				};
				selectedBoxColor = box.colorValue;
				baseColor = uint(selectedBoxColor);
				if (onlyColors && !onlyColors[baseColor])
				{
					dbgSkipOnly++;
					i++;
					continue;
				};
				if (!colorExistsInBasePalette(selectedBoxColor))
				{
					dbgSkipNotInBase++;
					i++;
					continue;
				};
				if (isBaseInSwatchLockedGroup(baseColor))
				{
					dbgSkipLocked++;
					i++;
					continue;
				};
				if (!canActiveGroupEditBase(baseColor))
				{
					dbgSkipOwned++;
					
					i++;
					continue;
				};
				seedColor = getSeedColorForBox(box);
				replacement = seedColor;
				if (hueSliderTouched)
				{
					replacement = adjustColor(seedColor, hueFactor);
				};
				replacement = adjustBrightness(replacement, brightnessLevel);
				replacement = adjustSaturation(replacement, saturationLevel);
				replacement = adjustAlpha(replacement, alphaLevel);
				box.drawTriangle(replacement);
				updatePaletteColor(selectedBoxColor, replacement);
				dbgApplied++;
				i++;
			};
			if (dbgSkipOwned > 0)
			{
				notifyOwnershipSkips(dbgSkipOwned);
			};
			
			
			applyActivePalettes(true);
			if (recolorEffectsMode)
			{
				
				applyRecolorEffectsFiltersPreview();
			};
		}

		private function updatePaletteColor(trueColor:uint, replacement:uint, recordLayer:Boolean = true, editingGroup:PaletteGroupSquare = null):void
		{
			var gateGroup:PaletteGroupSquare;
			if(trueColor !== undefined && replacement !== undefined)
			{
				checkLivePAUpdate();
				ensurePaletteBlocks(currentPaletteData);
				invalidateHotPalettes();
				if (recolorEffectsMode)
				{
					// RE is filter-only (fxHue/etc.) — do not paint body or paletteSwapFX.
					writeRecolorEffectsFxFields();
					applyRecolorEffectsFiltersPreview();
					return;
				};
				gateGroup = editingGroup;
				if (!gateGroup && activeGroup && activeGroup.hasMember(uint(trueColor)))
				{
					gateGroup = activeGroup;
				};
				if (!gateGroup)
				{
					gateGroup = getOwnerGroupForBase(uint(trueColor));
				};
				replaceBracket(trueColor, replacement, currentPaletteData.paletteSwapPA.colors, currentPaletteData.paletteSwapPA.replacements, gateGroup);
				replaceBracket(trueColor, replacement, currentPaletteData.paletteSwap.colors, currentPaletteData.paletteSwap.replacements, gateGroup);
				// Unique-sprite merges may add a key to swap only. Mirror into PA (and
				// the reverse) so studio sprites and portrait stay on the same edit.
				mirrorPalettePairAcrossBlocks(uint(trueColor), uint(replacement));
				palettePADirty = true;
				characterPaletteDirty = true;
				unchangedHighlightsDirty = true;
				if (recordLayer && activeGroup && activeGroup.hasMember(uint(trueColor)) && canActiveGroupEditBase(uint(trueColor)))
				{
					recordGroupLayerReplacement(activeGroup, uint(trueColor), uint(replacement));
				};
			};
		}

		/** After reorder / enable / new higher-priority group: paint each base from its owner. */
		private function reapplyOwnerLayerPalette():void
		{
			var seen:Object;
			var group:PaletteGroupSquare;
			var member:*;
			var baseColor:uint;
			var owner:PaletteGroupSquare;
			var repl:uint;
			var key:String;
			var child:DisplayObject;
			var box:ColorSquare;
			var i:int;
			var any:Boolean;
			var layerVal:*;
			var restoredBaseline:int;
			if (!currentPaletteData || !groupSquares)
			{
				return;
			};
			seen = {};
			any = false;
			restoredBaseline = 0;
			for each (group in groupSquares)
			{
				if (!group || !group.memberColors)
				{
					continue;
				};
				for each (member in group.memberColors)
				{
					baseColor = uint(member);
					seen[String(baseColor)] = baseColor;
				};
			};
			for (key in seen)
			{
				baseColor = uint(seen[key]);
				owner = getOwnerGroupForBase(baseColor);
				if (!owner)
				{
					// All claimants disabled (or none enabled) — clear stuck layer paint.
					repl = getSessionReplacementForColor(baseColor);
					if (uint(getCurrentReplacementForColor(baseColor)) == uint(repl))
					{
						continue;
					};
					restoredBaseline++;
				}
				else
				{
					layerVal = lookupGroupLayerReplacement(owner, baseColor);
					if (layerVal != null)
					{
						repl = uint(layerVal);
					}
					else if (owner.hasSwatchColor && (owner.useSwatch || owner.matchAllMode))
					{
						repl = computeGroupSwatchReplacement(owner, baseColor);
					}
					else
					{
						// Owner has no stored paint — pull session baseline so a later group's
						// leftover recolor cannot keep winning after ownership moves.
						repl = getSessionReplacementForColor(baseColor);
						if (uint(getCurrentReplacementForColor(baseColor)) == uint(repl))
						{
							continue;
						};
						restoredBaseline++;
					};
				};
				updatePaletteColor(baseColor, repl, false);
				any = true;
				if (m_subMenu && m_subMenu.colorBoxBG)
				{
					i = 0;
					while (i < m_subMenu.colorBoxBG.numChildren)
					{
						child = m_subMenu.colorBoxBG.getChildAt(i);
						if (child is ColorSquare && !(child is PaletteGroupSquare))
						{
							box = child as ColorSquare;
							if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), baseColor))
							{
								box.updateIndicator(repl);
							};
						};
						i++;
					};
				};
			};
			
			if (any)
			{
				applyActivePalettes(true);
				refreshAllGroupFaces();
			};
			refreshPriorityMarkers();
		}
	
        private function makeFormLabel(text:String, color:uint):flash.text.TextField
		{
			var label:flash.text.TextField;
			label = new flash.text.TextField();
			label.defaultTextFormat = new flash.text.TextFormat("_sans", 11, color, true);
			label.autoSize = flash.text.TextFieldAutoSize.LEFT;
			label.selectable = false;
			label.mouseEnabled = false;
			label.text = text;
			return label;
		}

        private function makeColorBoxes(colors:Array, altColors:Array = null, baseName:String = null, altName:String = null):void 
		{
			var boxSize:Number = BOX_SIZE;
			var posX:Number = BOX_POS_X;
			var posY:Number = BOX_POS_Y;
			var perRow:int = BOX_PER_ROW;
			var offset:Number = BOX_OFFSET;
			var row:int = 0;
			var i:int;
			var sorted:Array;
			var altSorted:Array;
			var box:ColorSquare;
			var space:int;
			colorRowCount = 0;
			swatchScrollRow = 0;
			sorted = sortSwatchBasesForDisplay(colors);
			mixedBasePaletteData = sorted;
			if (baseFormLabel && baseFormLabel.parent)
			{
				baseFormLabel.parent.removeChild(baseFormLabel);
			};
			if (altFormLabel && altFormLabel.parent)
			{
				altFormLabel.parent.removeChild(altFormLabel);
			};
			baseFormLabel = null;
			altFormLabel = null;
			if (altColors && altColors.length > 0)
			{
				baseFormLabel = makeFormLabel(baseName ? baseName : String(statsName), 0xFFFFFF);
				m_subMenu.colorBoxBG.addChild(baseFormLabel);
			};
            for (i = 0; i < sorted.length; i++) 
			{
                box = new ColorSquare(sorted[i], boxSize, i);
                space = i % perRow;
					box.altForm = false;
                box.x = posX + space * (boxSize + offset);
                box.y = posY + Math.floor(i / perRow) * (boxSize + offset);
					m_subMenu.colorBoxBG.addChild(box);
            };
			colorRowCount = (sorted.length > 0) ? (Math.floor((sorted.length - 1) / perRow) + 1) : 0;
			if (altColors && altColors.length > 0)
			{
				altFormLabel = makeFormLabel(altName ? altName : "alt", 0xFFD27A);
				m_subMenu.colorBoxBG.addChild(altFormLabel);
				altSorted = sortSwatchBasesForDisplay(altColors);
				for (i = 0; i < altSorted.length; i++)
				{
					box = new ColorSquare(altSorted[i], boxSize, sorted.length + i);
					box.altForm = true;
					space = i % perRow;
					box.x = posX + space * (boxSize + offset);
					box.y = posY + (colorRowCount + Math.floor(i / perRow)) * (boxSize + offset);
					m_subMenu.colorBoxBG.addChild(box);
				};
				colorRowCount += (altSorted.length > 0) ? (Math.floor((altSorted.length - 1) / perRow) + 1) : 0;
			};
			layoutGroupRow();
			layoutToolRow();
			refreshColorBoxScroll();
			ensureSwatchScrollListeners();
        }

		/** Re-layout existing ColorSquares in hue/neutral order after late swatch adds. */
		private function resortColorSwatchLayout():void
		{
			var boxes:Array;
			var indicators:Object;
			var i:int;
			var box:ColorSquare;
			var sorted:Array;
			var color:uint;
			var repl:uint;
			var missing:Array;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			// Ensure every mixedBase key has a ColorSquare (linked PA inject used to push keys without boxes).
			missing = [];
			boxes = getPaletteSwatchBoxes();
			if (mixedBasePaletteData && mixedBasePaletteData.length > 0)
			{
				for each (color in mixedBasePaletteData)
				{
					var foundBox:Boolean = false;
					for each (box in boxes)
					{
						if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), uint(color)))
						{
							foundBox = true;
							break;
						};
					};
					if (!foundBox)
					{
						missing.push(uint(color));
					};
				};
				if (missing.length > 0)
				{
					appendColorBoxes(missing);
				};
			};
			boxes = getPaletteSwatchBoxes();
			indicators = {};
			for each (box in boxes)
			{
				indicators[uint(box.colorValue)] = getCurrentReplacementForColor(uint(box.colorValue));
			};
			if (boxes.length == 0)
			{
				return;
			};
			sorted = sortSwatchBasesForDisplay(mixedBasePaletteData);
			mixedBasePaletteData = sorted;
			var byColor:Object = {};
			for each (box in boxes)
			{
				byColor[uint(box.colorValue)] = box;
			};
			i = 0;
			while (i < sorted.length)
			{
				color = uint(sorted[i]);
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
					repl = uint(indicators[uint(box.colorValue)]);
					if (repl)
					{
						box.updateIndicator(repl);
					};
					m_subMenu.colorBoxBG.addChild(box);
				};
				i++;
			};
			for each (box in boxes)
			{
				m_subMenu.colorBoxBG.addChild(box);
			};
			colorRowCount = (sorted.length > 0) ? (Math.floor((sorted.length - 1) / BOX_PER_ROW) + 1) : 0;
			layoutGroupRow();
			layoutToolRow();
			refreshColorBoxScroll();
		}

		override protected function afterSwatchRowScroll():void
		{
			layoutToolRow();
		}

		private function layoutToolRow():void
		{
			var i:int;
			var tool:PaletteToolSquare;
			var rowY:Number = fixedRowBelowSwatches();
			var groupCount:int;
			groupCount = recolorEffectsMode
				? (fxGroupSquares ? fxGroupSquares.length : 0)
				: (groupSquares ? groupSquares.length : 0);
			if (groupCount > 0)
			{
				rowY += (BOX_SIZE + BOX_OFFSET);
			};
			if (!toolSquares || toolSquares.length != TOOL_IDS.length)
			{
				// Rebuild when tool set changes (e.g. IC/EC added).
				if (toolSquares)
				{
					i = 0;
					while (i < toolSquares.length)
					{
						tool = toolSquares[i] as PaletteToolSquare;
						if (tool)
						{
							tool.killEvents();
							if (tool.parent)
							{
								tool.parent.removeChild(tool);
							};
						};
						i++;
					};
				};
				toolSquares = [];
				i = 0;
				while (i < TOOL_IDS.length)
				{
					tool = new PaletteToolSquare(TOOL_IDS[i], BOX_SIZE, onToolClick, onToolHover, onToolHoverOut);
					toolSquares.push(tool);
					m_subMenu.colorBoxBG.addChild(tool);
					i++;
				};
			};
			i = 0;
			while (i < toolSquares.length)
			{
				tool = toolSquares[i] as PaletteToolSquare;
				if (tool)
				{
					tool.x = BOX_POS_X + i * (BOX_SIZE + BOX_OFFSET);
					tool.y = rowY;
					m_subMenu.colorBoxBG.addChild(tool);
				};
				i++;
			};
			if (!toolHintText)
			{
				toolHintText = new TextField();
				toolHintText.defaultTextFormat = new flash.text.TextFormat("_sans", 10, 0xDDDDDD, false);
				toolHintText.autoSize = flash.text.TextFieldAutoSize.LEFT;
				toolHintText.selectable = false;
				toolHintText.mouseEnabled = false;
				toolHintText.text = "";
				m_subMenu.colorBoxBG.addChild(toolHintText);
			};
			toolHintText.x = BOX_POS_X + toolSquares.length * (BOX_SIZE + BOX_OFFSET) + 6;
			toolHintText.y = rowY + 1;
			m_subMenu.colorBoxBG.addChild(toolHintText);
			updateDefaultToolHint();
			refreshToggleToolVisuals();
		}

		private function importCode_CLICK(e:MouseEvent):void
		{
			var clipText:String = "";
			try
			{
				if (Clipboard.generalClipboard.hasFormat(ClipboardFormats.TEXT_FORMAT))
				{
					clipText = String(Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT) || "");
				};
			}
			catch (clipErr:Error)
			{
				clipText = "";
			};
			if (clipText && PaletteMakerUtils.trimString(clipText).length > 0)
			{
				applyImportedCostumeJsonText(clipText);
				return;
			};
			openImportCodePastePopup("");
		}

		private function openImportCodePastePopup(initialText:String):void
		{
			if (!importCodePastePopup)
			{
				importCodePastePopup = new ImportCodePastePopup();
				importCodePastePopup.onSubmit = applyImportedCostumeJsonText;
				importCodePastePopup.onCancel = closeImportCodePastePopup;
				m_subMenu.addChild(importCodePastePopup);
			};
			importCodePastePopup.show(initialText);
		}

		private function applyImportedCostumeJsonText(text:String):void
		{
			var parsed:Object;
			var costume:Object;
			closeImportCodePastePopup();
			parsed = PaletteMakerUtils.parseCostumeJsonFromString(text);
			if (!parsed || !parsed.ok)
			{
				Ssf2.MultiplayerManager.notify(parsed && parsed.error ? String(parsed.error) : "Import failed");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			costume = parsed.costume;
			if (!applyImportedCostumeObject(costume))
			{
				Ssf2.MultiplayerManager.notify("Import failed — no active palette");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			Ssf2.MultiplayerManager.notify("Imported costume code");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function applyImportedCostumeObject(imported:Object):Boolean
		{
			var ps:Object;
			var psPA:Object;
			var mixedPairs:Array;
			var matches:Array;
			var pair:Object;
			var match:Object;
			var colorValue:uint;
			var replacementValue:uint;
			var inBase:Boolean;
			var baseVal:*;
			var i:int;
			var child:DisplayObject;
			var colorBox:ColorSquare;
			var costumeName:String;
			var nudgeCount:int;
			if (!imported || !currentPaletteData)
			{
				return false;
			};
			pushUndoSnapshot();
			ps = normalizePaletteBlock(imported.paletteSwap);
			psPA = normalizePaletteBlock(imported.paletteSwapPA);
			nudgeCount = CostumePackIO.nudgeExtremeReplacementsForVanilla(ps)
				+ CostumePackIO.nudgeExtremeReplacementsForVanilla(psPA);
			ensurePaletteBlocks(currentPaletteData);
			currentPaletteData.paletteSwap = ps;
			currentPaletteData.paletteSwapPA = psPA;
			mixedPairs = mixColorPairs(ps.colors.concat(psPA.colors), ps.replacements.concat(psPA.replacements));
			matches = [];
			applyIdentityPaletteFromCurrentBases();
			for each (pair in mixedPairs)
			{
				colorValue = uint(pair.color);
				replacementValue = uint(pair.replacement);
				inBase = false;
				for each (baseVal in mixedBasePaletteData)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(baseVal), colorValue))
					{
						inBase = true;
						break;
					};
				};
				if (inBase)
				{
					matches.push({ color: colorValue, replacement: replacementValue });
				};
			};
			for each (match in matches)
			{
				updatePaletteColor(match.color, match.replacement, false);
			};
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare && !(child is PaletteGroupSquare))
				{
					colorBox = child as ColorSquare;
					colorBox.updateIndicator(getCurrentReplacementForColor(uint(colorBox.colorValue)));
				};
				i++;
			};
			costumeName = imported.profile ? String(imported.profile) : "";
			if (!costumeName && imported.info)
			{
				costumeName = String(imported.info);
				if (costumeName.indexOf(" by ") != -1)
				{
					costumeName = costumeName.substring(0, costumeName.indexOf(" by "));
				};
			};
			if (costumeName && costumeName.length > 0)
			{
				m_subMenu.slotName.text = costumeName;
			};
			if (imported.author)
			{
				setAuthorNameText(String(imported.author));
			};
			checkCostumeName(null);
			sessionBaselineData = clonePaletteSnapshot(currentPaletteData);
			characterPaletteDirty = true;
			palettePADirty = true;
			unchangedHighlightsDirty = true;
			applyActivePalettes(true);
			refreshUnchangedHighlights();
			notifyFlashSafeNudgeIfNeeded(nudgeCount);
			return true;
		}

		private function back_CLICK(e:MouseEvent = null):void
		{
			clearStudioMirrorInput();
			sessionActive = false;
			destroyMcNameDropdown();
			ColorSquare.onSelectionChanged = null;
			ColorSquare.onHoverChanged = null;
			ColorSquare.canInteract = null;
			clearPaletteHoverIsolate();
			if (Ssf2.HudMenu.beforeSnapshot == onPaletteMakerBeforeSnapshot)
			{
				Ssf2.HudMenu.beforeSnapshot = null;
			};
			if (Ssf2.HudMenu.afterSnapshot == onPaletteMakerAfterSnapshot)
			{
				Ssf2.HudMenu.afterSnapshot = null;
			};
			destroyPauseToys();
			suppressSelectionSideEffects = true;
			resetColorBoxes();
			ColorSquare.deselectAll();
			suppressSelectionSideEffects = false;
			statsName = null;
			if (player)
			{
				try
				{
					player.FreezePlayback = false;
				}
				catch (unfreezeErr:Error)
				{
				};
				player.studioDeepPalettePaint = false;
			};
			player = null;
			currentPaletteData = null;
			baseCostumeData = null;
			sessionBaselineData = null;
			mixedBasePaletteData = [];
			isolateMode = false;
			recolorEffectsMode = false;
			fxStripSelectedLinkages = {};
			activeFxGroupId = null;
			fxColorSettingsMode = false;
			clearFxGroupSquares();
			effectPaCoverCache = null;
			CostumeFxPaletteRuntime.studioAttachHarvest = null;
			magnifierHit = null;
			characterFrozen = false;
			freezeChordWasDown = false;
			PAContainer = null;
			PixelArt = null;
			PixelArtPartner = null;
			portraitBitmapCaches = new Dictionary(true);
			clearHoverDimBuffers();
			palettePADirty = true;
			characterPaletteDirty = true;
			activeGroup = null;
			pendingAutoGroups = false;
			autoGroupsGenerated = false;
			clearUniquePaSprites();
			uniquePaCoverCache = null;
			uniquePaScanStatsName = null;
			uniquePaScanMTime = 0;
			pendingUniquePaRefresh = false;
			mixedBaseRgbSet = null;
			invalidateHotPalettes();
			clearHistory();
			uiKeysFrozen = false;
			uiHidden = false;
			wasGamePaused = false;
			if (showUiButton)
			{
				showUiButton.visible = false;
			};
			if (changeTodButton)
			{
				changeTodButton.visible = false;
			};
			if (changeMusicButton)
			{
				changeMusicButton.visible = false;
			};
			if (changeStageButton)
			{
				changeStageButton.visible = false;
			};
			if (restAreaButton)
			{
				restAreaButton.visible = false;
			};
			if (m_subMenu)
			{
				m_subMenu.visible = true;
			};
			closeToolSettings();
			hideMagnifier();
			updateStageFreeze();
			Ssf2.GameController.stageData.endGame();
			Ssf2.MenuController.disposeAllMenus(true);
			Ssf2.MenuController.vaultMenu.show();
			Ssf2.MenuController.vaultMenu.showManageCostumesGrid();
			Ssf2.SSF2API.setGlobalVar("allstar_mode_match_count", 7);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
			Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, updateCharacter);
		}

		private function updateMagnifierControls():void
		{
			var ctrl:*;
			var status:*;
			var moved:Boolean;
			var selectDown:Boolean;
			var pid:int;
			var step:Number;
			var prevX:Number;
			var prevY:Number;
			var dirDown:Boolean;
			var allowMove:Boolean;
			var dStageX:int;
			var dStageY:int;
			var prevBmpDbg:Bitmap;
			var prevLXDbg:int;
			var prevLYDbg:int;
			if (!magnifierOverlay || !magnifierOverlay.visible || !Ssf2.GameController.stageData)
			{
				return;
			};
			if (isMagnifierBlocked(magnifierProbeX, magnifierProbeY))
			{
				return;
			};
			ctrl = null;
			try
			{
				if (player && player.ControlSettings)
				{
					ctrl = player.ControlSettings;
				};
				if (!ctrl)
				{
					pid = (player && player.ID) ? int(player.ID) : 1;
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
			moved = false;
			// Run speed is only when the dash button is actively held. AUTO_DASH is a
			// stored control preference (always on for many players), so using it here
			// would force every nudge to the 4px run step and skip pixels.
			step = status.DASH ? MAG_PROBE_STEP_RUN : MAG_PROBE_STEP_WALK;
			// Tap = one step; hold = wait, then crawl. Prevents a short tap (which spans
			// several frames) from advancing multiple pixels.
			dirDown = status.LEFT || status.RIGHT || status.UP || status.DOWN;
			allowMove = false;
			if (dirDown)
			{
				if (!magDirWasDown)
				{
					allowMove = true;
					magRepeatFrames = 0;
				}
				else
				{
					magRepeatFrames++;
					if (magRepeatFrames >= MAG_REPEAT_DELAY && ((magRepeatFrames - MAG_REPEAT_DELAY) % MAG_REPEAT_INTERVAL) == 0)
					{
						allowMove = true;
					};
				};
			}
			else
			{
				magRepeatFrames = 0;
			};
			magDirWasDown = dirDown;
			if (allowMove)
			{
				dStageX = 0;
				dStageY = 0;
				if (status.LEFT)
				{
					dStageX -= int(step);
				};
				if (status.RIGHT)
				{
					dStageX += int(step);
				};
				if (status.UP)
				{
					dStageY -= int(step);
				};
				if (status.DOWN)
				{
					dStageY += int(step);
				};
				if (dStageX != 0 || dStageY != 0)
				{
					prevX = magnifierProbeX;
					prevY = magnifierProbeY;
					prevBmpDbg = (magnifierHit && magnifierHit.bitmap is Bitmap)
						? (magnifierHit.bitmap as Bitmap) : null;
					prevLXDbg = magnifierHit ? int(magnifierHit.localX) : -1;
					prevLYDbg = magnifierHit ? int(magnifierHit.localY) : -1;
					// Walk/run step is in magnifier cells (local texels), not stage pixels.
					if (tryNudgeMagnifierByLocal(dStageX, dStageY)
						|| tryNudgeMagnifierByStage(dStageX, dStageY))
					{
						moved = true;
					}
					
				};
			};
			if (moved)
			{
				magnifierControlDriven = true;
				magControlProbeX = magnifierProbeX;
				magControlProbeY = magnifierProbeY;
				// Local nudges already chose the exact texel — re-sampling stage can
				// jump again (the SKIP in the Lucario log). Only stage fallback re-hits.
				if (magLastNudgeVia == "local")
				{
					refreshMagnifierFromCurrentHit();
				}
				else
				{
					updateMagnifier(magnifierProbeX, magnifierProbeY, true);
				};
				
			};
			// Attack/special select the current map probe. While frozen, Attack+dirs /
			// Special+dirs are studio move/scale — don't treat those as color select.
			selectDown = status.BUTTON1 || status.BUTTON2;
			if (characterFrozen && (status.LEFT || status.RIGHT || status.UP || status.DOWN))
			{
				selectDown = false;
			};
			if (selectDown && !magnifierAttackWasDown)
			{
				if (!magnifierSelectConsumed)
				{
					selectMagnifierHit();
					magnifierSelectConsumed = true;
				};
			};
			if (!selectDown)
			{
				magnifierSelectConsumed = false;
			};
			magnifierAttackWasDown = selectDown;
		}

		private function stage_CLICK(e:MouseEvent):void
		{
			var mapOpen:Boolean;
			var overUi:Boolean;
			mapOpen = Boolean(magnifierOverlay && magnifierOverlay.visible && magnifierHit);
			overUi = Boolean(m_subMenu && m_subMenu.hitTestPoint(e.stageX, e.stageY, true));
			// Map open: select the current crosshair. Magnifier often overlaps the right
			// panel — treat clicks on the magnifier map (or off the palette UI) as select.
			// Clicks on UI controls outside the map still go to those controls only.
			if (mapOpen)
			{
				if (overUi && !isClickOnMagnifierOverlay(e.stageX, e.stageY))
				{
					return;
				};
				if (magnifierSelectConsumed)
				{
					
					return;
				};
				selectMagnifierHit();
				magnifierSelectConsumed = true;
				magnifierAttackWasDown = true;
				return;
			};
			if (overUi)
			{
				return;
			};
			if (ColorSquare.primaryPickMode || csEyedropperMode)
			{
				if (isMagnifierBlocked(e.stageX, e.stageY))
				{
					return;
				};
				magnifierProbeX = e.stageX;
				magnifierProbeY = e.stageY;
				updateMagnifier(magnifierProbeX, magnifierProbeY);
				if (!magnifierSelectConsumed && magnifierHit)
				{
					selectMagnifierHit();
					magnifierSelectConsumed = true;
					magnifierAttackWasDown = true;
				};
				return;
			};
			if (isMagnifierBlocked(e.stageX, e.stageY))
			{
				return;
			};
			magnifierProbeX = e.stageX;
			magnifierProbeY = e.stageY;
			updateMagnifier(magnifierProbeX, magnifierProbeY);
			if (!magnifierOverlay || !magnifierOverlay.visible || !magnifierHit)
			{
				return;
			};
			if (magnifierSelectConsumed)
			{
				return;
			};
			selectMagnifierHit();
			magnifierSelectConsumed = true;
			magnifierAttackWasDown = true;
		}

		private function selectMagnifierHit():void
		{
			var bases:Array;
			var matchedBoxes:Array;
			var hit:Object;
			var resumePulse:Boolean;
			var hasOriginalBase:Boolean;
			var origBaseColor:uint;
			var rawHit:Object;
			if (!magnifierOverlay || !magnifierOverlay.visible || !magnifierHit || isMagnifierBlocked())
			{
				
				return;
			};
			// Pulse paints complementary colors into the bitmap; pause so the sample matches
			// the real palette color under the cursor.
			resumePulse = false;
			if (pulseActive)
			{
				resumePulse = ColorSquare.selectedBoxes.length > 0;
				cancelSelectionPulse(true);
				updateMagnifier(magnifierProbeX, magnifierProbeY);
				if (!magnifierHit)
				{
					resumePulseAfterPick(resumePulse, false);
					return;
				};
			};
			// Exact magnifier texel BEFORE neighbor-resolve. Near-black / AA snap must not
			// steal deselect identity from a different adjacent base.
			rawHit = {
				"color": magnifierHit.color,
				"bitmap": magnifierHit.bitmap,
				"localX": magnifierHit.localX,
				"localY": magnifierHit.localY
			};
			// Distrust-aware identity first — raw portrait orig can claim a bright base
			// under a near-black texel and deselect the wrong swatch on click.
			var earlyPick:Object = resolveSpritePickIdentity(rawHit, uint(rawHit.color));
			if (spriteSelectDeselectRawOrig(rawHit, earlyPick, resumePulse))
			{
				return;
			};
			hit = resolveSelectionHit(magnifierHit);
			if (!hit)
			{
				
				resumePulseAfterPick(resumePulse, false);
				return;
			};
			magnifierHit = hit;
			// Reuse distrust-aware identity from the exact raw texel (never a neighbor).
			var pickInfo:Object = earlyPick || resolveSpritePickIdentity(rawHit, uint(rawHit.color));
			hasOriginalBase = pickInfo && pickInfo.hasOrig;
			origBaseColor = hasOriginalBase ? uint(pickInfo.orig) : 0;
			bases = spriteSelectBases(rawHit, pickInfo, hasOriginalBase, origBaseColor);
			if (csEyedropperMode)
			{
				csEyedropperMode = false;
				applyCsSwatchColor(uint(hit.color), true);
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				resumePulseAfterPick(resumePulse, false);
				return;
			};
			if (ColorSquare.primaryPickMode)
			{
				spriteSelectPrimaryPick(bases, hasOriginalBase, origBaseColor, resumePulse);
				return;
			};
			if ((!bases || bases.length == 0) && !hasOriginalBase)
			{
				
				resumePulseAfterPick(resumePulse, false);
				return;
			};
			if (!bases || bases.length == 0)
			{
				bases = [origBaseColor];
			};
			matchedBoxes = spriteSelectMatchBases(bases, hasOriginalBase, origBaseColor);
			if (matchedBoxes.length == 0)
			{
				
				resumePulseAfterPick(resumePulse, false);
				return;
			};
			if (!anyBoxUnselected(matchedBoxes))
			{
				// Already selected — should have been handled by the orig raw-texel path.
				// Without orig, peel one exact display match; never soft pickBest.
				matchedBoxes = spriteSelectToggleOff(hit, rawHit, pickInfo, bases, hasOriginalBase, origBaseColor, resumePulse);
				if (!matchedBoxes)
				{
					return;
				};
			};
			if (matchedBoxes.length == 0)
			{
				
				PaletteMakerAchievements.unlock("secret_mag_miss");
				resumePulseAfterPick(resumePulse, false);
				return;
			};
			setBoxesSelected(matchedBoxes, true);
			// Keep the active group (e.g. Group B) — do not auto-switch to an earlier
			// owner group. Shared colors can belong to multiple layers; ownership only
			// gates recolor writes, not membership / selection while B is active.
			
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.track("magnifier_select");
			resumePulseAfterPick(resumePulse, true);
		}

		/** Restart the selection pulse paused by selectMagnifierHit; requireSelection skips it when nothing stays selected. */
		private function resumePulseAfterPick(resumePulse:Boolean, requireSelection:Boolean):void
		{
			if (resumePulse && (!requireSelection || ColorSquare.selectedBoxes.length > 0))
			{
				startSelectionPulse(captureSelectedColorSet());
			};
		}

		/** Swatch boxes (not group squares) whose color matches; selectedOnly keeps those in ColorSquare.selectedBoxes. */
		private function swatchBoxesForColor(color:uint, selectedOnly:Boolean):Array
		{
			var out:Array = [];
			var i:int = 0;
			var child:DisplayObject;
			var box:ColorSquare;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare && !(child is PaletteGroupSquare))
				{
					box = child as ColorSquare;
					if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), color)
						&& (!selectedOnly || ColorSquare.selectedBoxes.indexOf(box) != -1))
					{
						out.push(box);
					};
				};
				i++;
			};
			return out;
		}

		private function setBoxesSelected(boxes:Array, selected:Boolean):void
		{
			var box:ColorSquare;
			ColorSquare.beginBulkUpdate();
			for each (box in boxes)
			{
				box.setSelected(selected);
			};
			ColorSquare.endBulkUpdate();
		}

		private function anyBoxUnselected(boxes:Array):Boolean
		{
			var box:ColorSquare;
			for each (box in boxes)
			{
				if (ColorSquare.selectedBoxes.indexOf(box) == -1)
				{
					return true;
				};
			};
			return false;
		}

		/** Step 1: the raw texel's original base is already selected — deselect that base only. True when handled. */
		private function spriteSelectDeselectRawOrig(rawHit:Object, earlyPick:Object, resumePulse:Boolean):Boolean
		{
			var hasOriginalBase:Boolean = earlyPick && earlyPick.hasOrig == true;
			var origBaseColor:uint = hasOriginalBase ? uint(earlyPick.orig) : 0;
			var matchedBoxes:Array;
			// Do not deselect on painted-display match here — that would steal additive
			// selects when another same-display swatch is already selected.
			if (csEyedropperMode || ColorSquare.primaryPickMode
				|| !hasOriginalBase || !colorIsCurrentlySelected(origBaseColor))
			{
				return false;
			};
			matchedBoxes = swatchBoxesForColor(origBaseColor, true);
			if (matchedBoxes.length == 0)
			{
				return false;
			};
			setBoxesSelected(matchedBoxes, false);
			
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			resumePulseAfterPick(resumePulse, true);
			return true;
		}

		/** Step 2: candidate base colors for the picked texel. */
		private function spriteSelectBases(rawHit:Object, pickInfo:Object, hasOriginalBase:Boolean, origBaseColor:uint):Array
		{
			var bases:Array;
			if (pickInfo && pickInfo.found && !csEyedropperMode)
			{
				bases = [uint(pickInfo.base)];
			}
			else if (hasOriginalBase && !csEyedropperMode)
			{
				bases = [origBaseColor];
			}
			else if (isNearBlackRgb(uint(rawHit.color))
				&& !csEyedropperMode && !ColorSquare.primaryPickMode)
			{
				bases = findNearBlackSelectFallback(uint(rawHit.color));
			}
			else
			{
				bases = findBasesForSpriteHit(uint(rawHit.color));
				if (bases && bases.length > 1)
				{
					bases = collapseBasesToClosest(bases, uint(rawHit.color));
				};
			};
			
			return bases;
		}

		/** Step 3 (primary pick mode): the picked base becomes the group primary, or the pick is cancelled. */
		private function spriteSelectPrimaryPick(bases:Array, hasOriginalBase:Boolean, origBaseColor:uint, resumePulse:Boolean):void
		{
			var group:PaletteGroupSquare;
			var baseColor:uint;
			var pickedPrimary:uint;
			var foundPrimary:Boolean;
			if ((!bases || bases.length == 0) && hasOriginalBase)
			{
				bases = [origBaseColor];
			};
			if (!bases || bases.length == 0)
			{
				cancelPrimaryPick("Primary change cancelled");
				resumePulseAfterPick(resumePulse, false);
				return;
			};
			group = getColorSettingsGroup() || activeGroup;
			if (!group)
			{
				cancelPrimaryPick("Primary change cancelled");
				resumePulseAfterPick(resumePulse, false);
				return;
			};
			foundPrimary = false;
			pickedPrimary = 0;
			for each (baseColor in bases)
			{
				if (group.hasMember(uint(baseColor)))
				{
					pickedPrimary = uint(baseColor);
					foundPrimary = true;
					break;
				};
			};
			if (!foundPrimary)
			{
				cancelPrimaryPick("Primary change cancelled");
				resumePulseAfterPick(resumePulse, false);
				return;
			};
			finishPrimaryPick(pickedPrimary);
			resumePulseAfterPick(resumePulse, false);
		}

		/** Step 4: every swatch matching a base (shade / match-all families), falling back to the original under the crosshair. */
		private function spriteSelectMatchBases(bases:Array, hasOriginalBase:Boolean, origBaseColor:uint):Array
		{
			var matchedBoxes:Array = [];
			var baseColor:uint;
			// Use selectedBoxes membership (not only box.isSelected) — deselectAll can
			// leave stale isSelected=true when the array is mutated during iteration.
			for each (baseColor in bases)
			{
				matchedBoxes = matchedBoxes.concat(swatchBoxesForColor(uint(baseColor), false));
			};
			if (matchedBoxes.length == 0 && hasOriginalBase)
			{
				matchedBoxes = swatchBoxesForColor(origBaseColor, false);
			};
			return matchedBoxes;
		}

		/**
		 * Step 5: every matched swatch is already selected. Deselects and returns null when handled;
		 * otherwise returns the boxes to force-select (stale borders / empty selectedBoxes).
		 */
		private function spriteSelectToggleOff(hit:Object, rawHit:Object, pickInfo:Object, bases:Array, hasOriginalBase:Boolean, origBaseColor:uint, resumePulse:Boolean):Array
		{
			var matchedBoxes:Array;
			var baseColor:uint;
			if (hasOriginalBase)
			{
				// Fallthrough safety: deselect orig members still in selectedBoxes.
				matchedBoxes = swatchBoxesForColor(origBaseColor, true);
				if (matchedBoxes.length > 0)
				{
					setBoxesSelected(matchedBoxes, false);
					
					Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
					resumePulseAfterPick(resumePulse, true);
					return null;
				};
				// Stale borders / empty selectedBoxes — rebuild and force select.
				return swatchBoxesForColor(origBaseColor, false);
			};
			// Match-all whites share one display — need original identity.
			// Prefer distrust-aware pickInfo / selected near-black identity.
			if (pickInfo && pickInfo.found && colorIsCurrentlySelected(uint(pickInfo.base)))
			{
				baseColor = uint(pickInfo.base);
			}
			else
			{
				baseColor = pickDeselectBaseForRawHit(rawHit,
					hasOriginalBase ? origBaseColor : 0);
			};
			if (baseColor == 0 || !colorIsCurrentlySelected(baseColor))
			{
				
				resumePulseAfterPick(resumePulse, false);
				return null;
			};
			matchedBoxes = swatchBoxesForColor(baseColor, true);
			if (matchedBoxes.length == 0)
			{
				resumePulseAfterPick(resumePulse, false);
				return null;
			};
			setBoxesSelected(matchedBoxes, false);
			
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.track("magnifier_select");
			PaletteMakerAchievements.unlock("secret_mag_deselect");
			resumePulseAfterPick(resumePulse, true);
			return null;
		}

		private function slider_DOUBLE_CLICK(e:MouseEvent):void
		{
			e.stopPropagation();
			setIsolateMode(!isolateMode);
		}

		private function setIsolateMode(on:Boolean):void
		{
			if (isolateMode == on)
			{
				return;
			};
			isolateMode = on;
			refreshIsolateSwatchVisuals();
			applyActivePalettes(true);
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				updateMagnifier(Ssf2.Main.Root.stage.mouseX, Ssf2.Main.Root.stage.mouseY);
			};
			Ssf2.MultiplayerManager.notify(isolateMode ? "Color isolate mode on" : "Color isolate mode off");
			PaletteMakerAchievements.track("isolate", { "on": on });
			if (on && characterFrozen)
			{
				PaletteMakerAchievements.unlock("secret_freeze_isolate");
			};
		}

		private function onSwatchHoverChanged(box:ColorSquare):void
		{
			if (box && ColorSquare.canInteract != null && !ColorSquare.canInteract())
			{
				box = null;
			};
			if (paletteHoverBox && paletteHoverBox != box)
			{
				paletteHoverBox.setPaletteHoverHighlight(false);
			};
			paletteHoverBox = box;
			if (!box)
			{
				hoverBaseActive = false;
				if (pixelHexShown)
				{
					pixelHexShown = false;
					updateDefaultToolHint();
				};
				scheduleHoverDim();
				return;
			};
			box.setPaletteHoverHighlight(true);
			hoverBaseColor = uint(box.colorValue);
			hoverBaseActive = true;
			showSwatchHex(uint(box.colorValue));
			scheduleHoverDim();
		}

		private function onColorSelectionChanged():void
		{
			var prevCount:int;
			var count:int;
			var skipApply:Boolean;
			var resetForGroup:Boolean;
			var prevSelected:Object;
			var newlySelected:Object;
			var deselected:Object;
			var box:ColorSquare;
			var baseColor:uint;
			if (suppressSelectionSideEffects || !currentPaletteData)
			{
				lastSelectionCount = ColorSquare.selectedBoxes.length;
				lastSelectedColorSet = captureSelectedColorSet();
				
				return;
			};
			if (activeGroup && activeGroup.locked && !selectionMatchesActiveGroup())
			{
				Ssf2.MultiplayerManager.notify("Group is locked — go into color settings to unlock");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				PaletteMakerAchievements.unlock("group_lock_then_edit");
				PaletteMakerAchievements.unlock("secret_lock_notify");
				suppressSelectionSideEffects = true;
				restoreSelectionToActiveGroup();
				suppressSelectionSideEffects = false;
				lastSelectionCount = ColorSquare.selectedBoxes.length;
				lastSelectedColorSet = captureSelectedColorSet();
				return;
			};
			prevSelected = lastSelectedColorSet || {};
			prevCount = lastSelectionCount;
			count = ColorSquare.selectedBoxes.length;
			skipApply = skipSliderApplyOnce;
			skipSliderApplyOnce = false;
			resetForGroup = pendingUnrecoloredGroupReset;
			pendingUnrecoloredGroupReset = false;
			newlySelected = {};
			deselected = {};
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				baseColor = uint(box.colorValue);
				if (!colorInSelectionSet(prevSelected, baseColor))
				{
					newlySelected[baseColor] = true;
				};
			};
			var prevKey:String;
			for (prevKey in prevSelected)
			{
				baseColor = uint(prevKey);
				if (!colorIsCurrentlySelected(baseColor))
				{
					deselected[baseColor] = true;
				};
			};
			
			syncActiveGroupMembership(newlySelected, deselected);
			if (skipApply)
			{
				// Group select/deselect: keep recolors; drop entry tracking only.
				clearSelectionEntriesFor(deselected);
				if (resetForGroup)
				{
					resetSlidersToDefault();
				};
			}
			else
			{
				revertDeselectedColors(deselected);
				captureSelectionEntryColors(newlySelected);
				if (count > prevCount)
				{
					if (applyCsSwatchToNewlySelected(newlySelected, prevCount == 0 && count == 1))
					{
						// CS wheel/swatch active — same parity as slider apply on grow.
					}
					else if (prevCount == 0 && count == 1)
					{
						if (!historyLockedForDrag)
						{
							pushUndoSnapshot();
							if (ColorSquare.isDragSelecting)
							{
								historyLockedForDrag = true;
							};
						};
						resetSlidersToDefault();
						applyCurrentSlidersToSelection();
					}
					else if (prevCount >= 1)
					{
						applyCurrentSlidersToColors(newlySelected);
					};
				};
			};
			if (!ColorSquare.isDragSelecting)
			{
				historyLockedForDrag = false;
			};
			lastSelectionCount = count;
			lastSelectedColorSet = captureSelectedColorSet();
			if (isolateMode)
			{
				refreshIsolateSwatchVisuals();
				applyActivePalettes(true);
			};
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				updateMagnifier(magnifierProbeX || Ssf2.Main.Root.stage.mouseX, magnifierProbeY || Ssf2.Main.Root.stage.mouseY);
			};
			refreshAllGroupFaces();
			if (count <= 0)
			{
				cancelSelectionPulse(true);
				cancelSelectHighlightFlash(true);
			}
			else if (settingSelectHighlight)
			{
				// Brief flash on first select only — not while keeping the selection to recolor.
				cancelSelectionPulse(false);
				if (skipApply && activeGroup && activeGroup.isSelected)
				{
					startSelectHighlightFlash(lastSelectedColorSet);
				}
				else if ((!skipApply) && hasAnyKey(newlySelected))
				{
					startSelectHighlightFlash(newlySelected);
				};
			}
			else if (skipApply && activeGroup && activeGroup.isSelected)
			{
				// Glow whole active group so the user sees what they are recoloring.
				startSelectionPulse(lastSelectedColorSet);
			}
			else if ((!skipApply) && hasAnyKey(newlySelected))
			{
				startSelectionPulse(newlySelected);
			};
			if (settingHighlightUnchanged)
			{
				refreshArtUnchangedOutlines();
			};
		}

		private function revertDeselectedColors(colorSet:Object):void
		{
			var key:String;
			var baseColor:uint;
			var entryKey:String;
			var repl:uint;
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var any:Boolean;
			if (!colorSet || !currentPaletteData)
			{
				return;
			};
			any = false;
			for (key in colorSet)
			{
				baseColor = uint(key);
				entryKey = String(baseColor);
				if (!selectionEntryReplacements.hasOwnProperty(entryKey))
				{
					continue;
				};
				repl = uint(selectionEntryReplacements[entryKey]);
				updatePaletteColor(baseColor, repl);
				any = true;
				delete selectionEntryReplacements[entryKey];
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
						if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), baseColor))
						{
							box.updateIndicator(repl);
						};
					};
					i++;
				};
			};
			if (any)
			{
				applyActivePalettes(true);
				refreshAllGroupFaces();
				refreshUnchangedHighlights();
			};
		}

		private function refreshSelectionVisualsOnly():void
		{
			lastSelectionCount = ColorSquare.selectedBoxes.length;
			lastSelectedColorSet = captureSelectedColorSet();
			if (isolateMode)
			{
				refreshIsolateSwatchVisuals();
				applyActivePalettes(true);
			};
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				updateMagnifier(Ssf2.Main.Root.stage.mouseX, Ssf2.Main.Root.stage.mouseY);
			};
			refreshAllGroupFaces();
		}

		private function applyCurrentSlidersToSelection():void
		{
			applyCurrentSlidersToColors(null);
		}

		/**
		 * When Color Settings has an active wheel/swatch, apply it to newly selected
		 * colors (parity with slider apply on selection grow).
		 */
		private function applyCsSwatchToNewlySelected(newlySelected:Object, isFirstSingle:Boolean):Boolean
		{
			var group:PaletteGroupSquare;
			var members:Array;
			var key:String;
			var hasAny:Boolean;
			var popupActive:Boolean;
			group = getColorSettingsGroup();
			popupActive = Boolean(colorSettingsPopup && colorSettingsPopup.visible && colorSettingsPopup.hasActiveSwatch);
			if (!group || !newlySelected)
			{
				return false;
			};
			if (!(group.useSwatch && group.hasSwatchColor) && !popupActive)
			{
				return false;
			};
			if (popupActive && !(group.useSwatch && group.hasSwatchColor))
			{
				group.swatchColor = colorSettingsPopup.activeSwatchColor;
				group.hasSwatchColor = true;
				group.useSwatch = true;
			};
			members = [];
			hasAny = false;
			for (key in newlySelected)
			{
				members.push(uint(key));
				hasAny = true;
			};
			if (!hasAny)
			{
				return false;
			};
			if (isFirstSingle && !historyLockedForDrag)
			{
				pushUndoSnapshot();
				if (ColorSquare.isDragSelecting)
				{
					historyLockedForDrag = true;
				};
			};
			applySwatchToGroupMembers(group, members, false);
			return true;
		}

		private function applyCurrentSlidersToColors(onlyColors:Object):void
		{
			var i:int;
			var box:ColorSquare;
			var baseColor:uint;
			var hasFilter:Boolean = (onlyColors != null);
			var any:Boolean = !hasFilter;
			dragSeedColors = {};
			i = 0;
			while (i < ColorSquare.selectedBoxes.length)
			{
				box = ColorSquare.selectedBoxes[i];
				if (box && !(box is PaletteGroupSquare))
				{
					baseColor = uint(box.colorValue);
					if (!hasFilter || onlyColors[baseColor])
					{
						dragSeedColors[String(baseColor)] = getSessionReplacementForColor(baseColor);
						any = true;
					};
				};
				i++;
			};
			if (!any)
			{
				dragSeedColors = null;
				return;
			};
			reapplyAllSlidersFromSessionSeeds(onlyColors);
			dragSeedColors = null;
			ensureGroupAfterRecolor();
		}

		private function restoreSnapshot(snapshot:Object):void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var repl:uint;
			var selectedLookup:Object;
			var color:uint;
			if (!snapshot || !currentPaletteData)
			{
				return;
			};
			cancelSelectionPulse(false);
			suppressHistory = true;
			suppressSelectionSideEffects = true;
			currentPaletteData.paletteSwap = Ssf2.Utils.cloneObject(snapshot.paletteSwap);
			currentPaletteData.paletteSwapPA = Ssf2.Utils.cloneObject(snapshot.paletteSwapPA);
			unchangedHighlightsDirty = true;
			selectedLookup = {};
			if (snapshot.selectedColors)
			{
				i = 0;
				while (i < snapshot.selectedColors.length)
				{
					selectedLookup[uint(snapshot.selectedColors[i])] = true;
					i++;
				};
			};
			ColorSquare.beginBulkUpdate();
			ColorSquare.selectedBoxes.length = 0;
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare)
				{
					box = child as ColorSquare;
					repl = getCurrentReplacementForColor(uint(box.colorValue));
					box.updateIndicator(repl);
					if (selectedLookup[uint(box.colorValue)])
					{
						box.setSelected(true);
						if (ColorSquare.selectedBoxes.indexOf(box) == -1)
						{
							ColorSquare.selectedBoxes.push(box);
						};
					}
					else
					{
						box.setSelected(false);
					};
				};
				i++;
			};
			ColorSquare.endBulkUpdate();
			suppressSelectionSideEffects = false;
			lastSelectionCount = ColorSquare.selectedBoxes.length;
			lastSelectedColorSet = captureSelectedColorSet();
			applyActivePalettes(true);
			refreshIsolateSwatchVisuals();
			refreshAllGroupFaces();
			refreshUnchangedHighlights();
			suppressHistory = false;
		}

		private function undoPalette():void
		{
			var snapshot:Object;
			if (undoStack.length == 0)
			{
				return;
			};
			redoStack.push(captureSnapshot());
			snapshot = undoStack.pop();
			restoreSnapshot(snapshot);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function redoPalette():void
		{
			var snapshot:Object;
			if (redoStack.length == 0)
			{
				return;
			};
			undoStack.push(captureSnapshot());
			snapshot = redoStack.pop();
			restoreSnapshot(snapshot);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function onToolClick(toolId:String):void
		{
			var selectedBeforeDa:int;
			if (ColorSquare.primaryPickMode)
			{
				cancelPrimaryPick("Primary change cancelled");
			};
			if (toolId != "CS" && isColorSettingsVisible())
			{
				closeColorSettings();
			};
			if (toolId != "ST" && isToolSettingsVisible())
			{
				closeToolSettings();
			};
			switch (toolId)
			{
				case "UD":
					if (undoStack.length == 0)
					{
						PaletteMakerAchievements.unlock("secret_undo_empty");
					};
					undoPalette();
					break;
				case "RD":
					if (redoStack.length == 0)
					{
						PaletteMakerAchievements.unlock("secret_redo_empty");
					};
					redoPalette();
					break;
				case "DI":
					setIsolateMode(!isolateMode);
					break;
				case "FZ":
					setCharacterFrozen(!characterFrozen);
					break;
				case "SA":
					if (recolorEffectsMode)
					{
						selectAllFxStripSprites();
					}
					else
					{
						selectAllColorSquares();
					};
					PaletteMakerAchievements.track("select_all");
					break;
				case "DA":
					if (recolorEffectsMode)
					{
						fxStripSelectedLinkages = {};
						refreshFxStripHighlights();
						Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
						break;
					};
					selectedBeforeDa = ColorSquare.selectedBoxes ? ColorSquare.selectedBoxes.length : 0;
					skipSliderApplyOnce = true;
					activeGroup = null;
					clearGroupSelections();
					ColorSquare.deselectAll();
					refreshPrimaryBadges();
					refreshPriorityMarkers();
					updateDefaultToolHint();
					Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
					PaletteMakerAchievements.track("deselect_all", { "selectedCount": selectedBeforeDa });
					if (selectedBeforeDa > 0)
					{
						PaletteMakerAchievements.unlock("ritual_deselect_all");
					};
					break;
				case "IS":
					if (!ColorSquare.selectedBoxes || ColorSquare.selectedBoxes.length == 0)
					{
						PaletteMakerAchievements.unlock("secret_invert_empty");
					};
					inverseSelectionColorSquares();
					PaletteMakerAchievements.track("selection_inverted");
					break;
				case "RA":
					resetActiveColors();
					break;
				case "RB":
					recolorSelectedToBase();
					break;
				case "RO":
					recolorSelectedToOriginal();
					break;
				case "UQ":
					toggleUniqueOwned();
					break;
				case "NG":
					if (recolorEffectsMode)
					{
						createFxGroupFromStripSelection();
						break;
					};
					if (!ColorSquare.selectedBoxes || ColorSquare.selectedBoxes.length == 0)
					{
						PaletteMakerAchievements.unlock("secret_ng_empty");
					};
					createGroupFromSelection();
					break;
				case "CS":
					if (recolorEffectsMode)
					{
						openFxGroupColorSettings();
						break;
					};
					openColorSettings();
					break;
				case "ST":
					openToolSettings();
					break;
				case "IC":
					importColorSheet();
					break;
				case "EC":
					exportColorSheet();
					break;
				case "CO":
					importCode_CLICK(null);
					break;
			};
			PaletteMakerAchievements.track("tool_used", {
				"toolId": toolId,
				"on": (toolId == "DI" ? isolateMode : (toolId == "FZ" ? characterFrozen : (toolId == "UQ" ? uniqueOwnedHighlight : (toolId == "RE" ? recolorEffectsMode : false)))),
				"selectedCount": ColorSquare.selectedBoxes ? ColorSquare.selectedBoxes.length : 0
			});
		}

		/** The locker pick is the game costume index. CostumeID stays -2 until this runs, and -2 is the base. */
		private function rememberStudioCostumeIndex(gameIndex:int):void
		{
			studioGameCostumeIndex = gameIndex;
			if (!player)
			{
				return;
			};
			try
			{
				player.CostumeID = gameIndex;
			}
			catch (idErr:*)
			{
			};
		}

		override protected function applySavedCostumeSlot(fileIndex:int):void
		{
			var gameIndex:int;
			if (fileIndex < 0)
			{
				return;
			};
			gameIndex = PaletteMakerUtils.gameSlotForFileIndex(statsName, fileIndex);
			rememberStudioCostumeIndex(gameIndex);
			Ssf2.gameLog("[Palette Maker] pair slot id=" + gameIndex + " file=" + fileIndex);
		}

		private function studioCostumeSlot():int
		{
			var slot:int;
			if (studioGameCostumeIndex >= -1)
			{
				return studioGameCostumeIndex;
			};
			slot = -1;
			try
			{
				slot = int(player.CostumeID);
			}
			catch (slotErr:*)
			{
			};
			if (slot < -1)
			{
				return -1;
			};
			return slot;
		}

		/** Partner form on screen uses that form's palette. Null means leave the transform paint alone. */
		private function liveBodySwap(opened:Object, pa:Boolean):Object
		{
			var partnerName:String;
			var partnerCostume:Object;
			var block:Object;
			var slot:int;
			partnerName = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (!LinkedFormPaint.fighterUsesPartnerPalette(activeFighterForm, partnerName))
			{
				return opened;
			};
			partnerCostume = null;
			if (partnerPaletteData && partnerPaletteData.paletteSwap)
			{
				partnerCostume = partnerPaletteData;
			};
			if (!partnerCostume && (partnerName == "gigabowser" || activeFighterForm == "gigabowser"))
			{
				slot = studioCostumeSlot();
				partnerCostume = GigaStockPalettes.costume(LinkedFormPaint.gigaPaletteIndex(slot));
				if (gigaLiveLogged != String(slot))
				{
					gigaLiveLogged = String(slot);
					Ssf2.gameLog("[Palette Maker] giga live index=" + LinkedFormPaint.gigaPaletteIndex(slot));
				};
			};
			if (!partnerCostume)
			{
				slot = studioCostumeSlot();
				partnerCostume = PaletteMakerUtils.pairedPaletteForSlot(statsName, slot);
				if (!partnerCostume || !LinkedFormPaint.blockHasRecolor(partnerCostume.paletteSwap))
				{
					try
					{
						partnerCostume = Ssf2.ResourceManager.getCostume(partnerName, null, slot);
					}
					catch (costumeErr:*)
					{
						partnerCostume = null;
					};
				};
			};
			block = null;
			if (partnerCostume)
			{
				block = pa ? partnerCostume.paletteSwapPA : partnerCostume.paletteSwap;
				if (!block)
				{
					block = partnerCostume.paletteSwap;
				};
			};
			return LinkedFormPaint.livePaintBlock(true, opened, block);
		}

		private function toggleUniqueOwned():void
		{
			var i:int;
			var tool:PaletteToolSquare;
			uniqueOwnedHighlight = !uniqueOwnedHighlight;
			invalidateHotPalettes();
			if (currentPaletteData)
			{
				updateUniquePaPalettes(currentPaletteData.paletteSwap, currentPaletteData.paletteSwapPA);
			}
			else
			{
				updateUniquePaPalettes();
			};
			if (toolSquares)
			{
				i = 0;
				while (i < toolSquares.length)
				{
					tool = toolSquares[i] as PaletteToolSquare;
					if (tool && tool.toolId == "UQ")
					{
						tool.setActive(uniqueOwnedHighlight);
					};
					i++;
				};
			};
			try
			{
				Ssf2.MultiplayerManager.notify(uniqueOwnedHighlight ? "Unique colors shown" : "Unique colors restored");
			}
			catch (notifyErr:Error)
			{
			};
		}

		private function onPmKeyDown(e:KeyboardEvent):void
		{
			var resolved:Object;
			var focusObj:*;
			if (!e || !sessionActive || !e.ctrlKey)
			{
				return;
			};
			resolved = PaletteMakerShortcuts.resolve(e);
			if (!resolved)
			{
				return;
			};
			// Ctrl+S should save even while renaming (slot/author TextField focused).
			// Other shortcuts still defer to typing.
			focusObj = Ssf2.Main.Root && Ssf2.Main.Root.stage ? Ssf2.Main.Root.stage.focus : null;
			if ((focusObj is TextField) && !resolved.save)
			{
				return;
			};
			if (resolved.copyHex && !pixelHexShown)
			{
				return;
			};
			e.stopImmediatePropagation();
			e.stopPropagation();
			e.preventDefault();
			PaletteMakerAchievements.track("shortcut_used");
			if (resolved.save)
			{
				saveCostume_CLICK(null);
				return;
			};
			if (resolved.copyHex)
			{
				try
				{
					Clipboard.generalClipboard.clear();
					Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, toolHintText.text);
					Ssf2.MultiplayerManager.notify("Copied " + toolHintText.text);
				}
				catch (copyErr:Error)
				{
				};
				return;
			};
			if (resolved.uniqueOwned)
			{
				toggleUniqueOwned();
				return;
			};
			if (resolved.toolId)
			{
				onToolClick(String(resolved.toolId));
				if (toolHintText && TOOL_HINTS[resolved.toolId])
				{
					toolHintText.text = String(TOOL_HINTS[resolved.toolId]);
				};
			};
		}

		private function exportColorSheet():void
		{
			var bases:Array;
			var repls:Array;
			var applied:Array;
			var rawBases:Array;
			var i:int;
			var portraits:Array;
			var sheet:BitmapData;
			var sheetUniques:Array;
			var sheetCover:Array;
			refreshSheetPaletteOrder();
			rawBases = sheetPaletteOrder ? sheetPaletteOrder.concat() : [];
			if (!rawBases || rawBases.length == 0)
			{
				Ssf2.MultiplayerManager.notify("No palette colors to export");
				return;
			};
			bases = ColorSheetIO.dedupeRgb(rawBases);
			repls = [];
			i = 0;
			while (i < rawBases.length)
			{
				repls.push(getSheetReplacementForBase(uint(rawBases[i])));
				i++;
			};
			applied = ColorSheetIO.alignAppliedColors(rawBases, repls);
			if (!applied || applied.length == 0)
			{
				applied = bases.concat();
			};
			portraits = [];
			if (PixelArt)
			{
				portraits.push(PixelArt);
			};
			if (PixelArtPartner)
			{
				portraits.push(PixelArtPartner);
			};
			try
			{
				// Keep studio character in sync; sheet art uses the shared live painter.
				applyActivePalettes(true);
				sheetUniques = uniquePaSprites ? uniquePaSprites.concat() : [];
				sheetCover = uniquePaCoverCache ? uniquePaCoverCache.concat() : [];
				sheet = buildColorSheetBitmap(portraits, sheetUniques, sheetCover,
					currentPaletteData, applied, true, statsName);
				if (!sheet)
				{
					Ssf2.MultiplayerManager.notify("Color sheet export failed");
					return;
				};
				ColorSheetIO.exportPng(sheet, (statsName ? statsName : "costume") + "_colorsheet.png");
				sheet.dispose();
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				Ssf2.MultiplayerManager.notify("Color sheet export ready (" + applied.length + " colors)");
				PaletteMakerAchievements.track("sheet_export", { "colorCount": applied.length });
				if (applied.length >= 40)
				{
					PaletteMakerAchievements.unlock("sheet_export_heavy");
				};
				if (characterFrozen)
				{
					PaletteMakerAchievements.unlock("flavor_freeze_export");
				};
				if (PaletteMakerUtils.isLinkedFormPair(statsName))
				{
					PaletteMakerAchievements.unlock("sheet_linked_export");
				};
			}
			catch (err:Error)
			{
				Ssf2.MultiplayerManager.notify("Color sheet export error: " + err.message);
				PaletteGuard.fail("color sheet export", err);
			};
		}

		private function importColorSheet():void
		{
			var self:PaletteMakerMenu = this;
			ColorSheetIO.importPngs(function(items:Array):void
			{
				try
				{
					self.onColorSheetsPicked(items);
				}
				catch (err:*)
				{
					PaletteGuard.fail("color sheet import", err);
				};
			});
		}

		private function onColorSheetsPicked(items:Array):void
		{
			var item:Object;
			if (!items || items.length == 0)
			{
				return;
			};
			if (items.length == 1)
			{
				item = items[0];
				onColorSheetImported(item && item.bitmapData ? (item.bitmapData as BitmapData) : null);
				return;
			};
			onColorSheetsImportedAsPack(items);
		}

		/**
		 * Convert multiple color sheets into costumes for the current character,
		 * then open costume selector to save as a pack and optionally import to build.
		 */
		private function onColorSheetsImportedAsPack(items:Array):void
		{
			var costumes:Array;
			var item:Object;
			var bd:BitmapData;
			var strip:Object;
			var colors:Array;
			var costume:Object;
			var profile:String;
			var pack:Object;
			var characters:Object;
			var skipped:int;
			var i:int;
			if (!statsName)
			{
				disposeSheetImportItems(items);
				Ssf2.MultiplayerManager.notify("Color sheet pack import failed: no character");
				return;
			};
			if (!baseCostumeData)
			{
				disposeSheetImportItems(items);
				Ssf2.MultiplayerManager.notify("Color sheet pack import failed: no base palette");
				return;
			};
			costumes = [];
			skipped = 0;
			i = 0;
			while (i < items.length)
			{
				item = items[i];
				bd = (item && item.bitmapData is BitmapData) ? (item.bitmapData as BitmapData) : null;
				profile = ColorSheetIO.basenameNoExtension(item ? String(item.name) : "");
				if (!profile || profile.length == 0)
				{
					profile = "Sheet " + (i + 1);
				};
				if (!bd)
				{
					skipped++;
					i++;
					continue;
				};
				strip = ColorSheetIO.readPaletteStrip(bd);
				bd.dispose();
				if (!strip || !(strip.colors is Array) || (strip.colors as Array).length == 0)
				{
					skipped++;
					i++;
					continue;
				};
				colors = strip.colors as Array;
				costume = buildCostumeFromPaletteStrip(colors, profile);
				if (!costume)
				{
					skipped++;
					i++;
					continue;
				};
				costumes.push(costume);
				i++;
			};
			if (costumes.length == 0)
			{
				Ssf2.MultiplayerManager.notify("No valid color sheets to import"
					+ (skipped > 0 ? (" (" + skipped + " skipped)") : ""));
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			characters = {};
			characters[statsName] = costumes;
			pack = {
				"format": "ssf2_costume_pack",
				"version": 2,
				"characterCount": 1,
				"characters": characters
			};
			Ssf2.MenuController.costumeSelectorDisplay.returnToLocalListOnVaultExit = false;
			Ssf2.MenuController.costumeSelectorDisplay.setCharacter(statsName, 0, true, true);
			Ssf2.MenuController.costumeSelectorDisplay.onClickContainer = _onClickContainer;
			Ssf2.MenuController.costumeSelectorDisplay.onCloseMenu = _onCloseMenu;
			Ssf2.MenuController.costumeSelectorDisplay.beginColorSheetPackExport(pack);
			freezeKeys(true);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			Ssf2.MultiplayerManager.notify("Prepared " + costumes.length + " costume(s) from color sheets"
				+ (skipped > 0 ? (" (" + skipped + " skipped)") : "")
				+ " — select & save as pack");
			PaletteMakerAchievements.track("sheet_import", { "multi": true });
			PaletteMakerAchievements.unlock("sheet_pack_save");
		}

		private function onColorSheetImported(bd:BitmapData):void
		{
			var strip:Object;
			var colors:Array;
			var bases:Array;
			var i:int;
			var n:int;
			var base:uint;
			var repl:uint;
			var box:ColorSquare;
			var applied:int;
			if (!bd)
			{
				Ssf2.MultiplayerManager.notify("Color sheet import failed: no image");
				return;
			};
			if (!currentPaletteData)
			{
				bd.dispose();
				Ssf2.MultiplayerManager.notify("Color sheet import failed: no active palette");
				return;
			};
			strip = ColorSheetIO.readPaletteStrip(bd);
			bd.dispose();
			if (!strip || !(strip.colors is Array))
			{
				Ssf2.MultiplayerManager.notify("Not a valid color sheet (no bottom palette row)");
				return;
			};
			colors = strip.colors as Array;
			if (colors.length == 0)
			{
				Ssf2.MultiplayerManager.notify("Color sheet palette is empty");
				return;
			};
			refreshSheetPaletteOrder();
			bases = sheetPaletteOrder ? sheetPaletteOrder.concat() : [];
			if (!bases || bases.length == 0)
			{
				Ssf2.MultiplayerManager.notify("No in-game palette swatches to apply to");
				return;
			};
			pushUndoSnapshot();
			applied = 0;
			n = Math.min(colors.length, bases.length);
			i = 0;
			while (i < n)
			{
				base = uint(bases[i]);
				repl = uint(colors[i]);
				updatePaletteColor(base, repl);
				for each (box in getPaletteSwatchBoxes())
				{
					if (box && PaletteColorAnalysis.colorsMatch(uint(box.colorValue), base))
					{
						box.drawTriangle(repl);
						box.updateIndicator(repl);
					};
				};
				applied++;
				i++;
			};
			characterPaletteDirty = true;
			palettePADirty = true;
			applyActivePalettes(true);
			refreshAllSwatchTriangles();
			refreshAllGroupFaces();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			Ssf2.MultiplayerManager.notify("Imported palette (" + applied + " of " + bases.length
				+ " swatches, sheet had " + colors.length + ")");
			PaletteMakerAchievements.track("sheet_import", { "multi": false });
			PaletteMakerAchievements.unlock("sheet_import_apply");
			if (isolateMode)
			{
				PaletteMakerAchievements.unlock("flavor_isolate_import");
			};
			if (applied < bases.length)
			{
				PaletteMakerAchievements.unlock("sheet_import_partial");
			};
			if (PaletteMakerAchievements.hasFlashCycle(currentPaletteData))
			{
				PaletteMakerAchievements.track("palette_flash_cycle");
			};
		}

		private function selectAllColorSquares():void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			activeGroup = null;
			clearGroupSelections();
			suppressSelectionSideEffects = true;
			ColorSquare.beginBulkUpdate();
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare)
				{
					box = child as ColorSquare;
					box.setSelected(true);
					if (ColorSquare.selectedBoxes.indexOf(box) == -1)
					{
						ColorSquare.selectedBoxes.push(box);
					};
				};
				i++;
			};
			ColorSquare.endBulkUpdate();
			suppressSelectionSideEffects = false;
			skipSliderApplyOnce = true;
			onColorSelectionChanged();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function inverseSelectionColorSquares():void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var nextSelected:Array = [];
			var previouslySelected:Array;
			var prevBox:ColorSquare;
			var wasSelected:Boolean;
			// Snapshot first — replaceBracket links same-RGB / different-alpha keys, so
			// invert must treat a whole RGB family as selected. Otherwise one sibling
			// lands in the inverted set, recolor updates both, and the original
			// selection appears to change too.
			previouslySelected = ColorSquare.selectedBoxes.concat();
			activeGroup = null;
			clearGroupSelections();
			suppressSelectionSideEffects = true;
			ColorSquare.beginBulkUpdate();
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (!(child is ColorSquare))
				{
					i++;
					continue;
				};
				box = child as ColorSquare;
				wasSelected = previouslySelected.indexOf(box) != -1;
				if (!wasSelected)
				{
					for each (prevBox in previouslySelected)
					{
						if (prevBox && PaletteColorAnalysis.colorsMatch(uint(box.colorValue), uint(prevBox.colorValue)))
						{
							wasSelected = true;
							break;
						};
					};
				};
				if (wasSelected)
				{
					box.setSelected(false);
				}
				else
				{
					box.setSelected(true);
					nextSelected.push(box);
				};
				i++;
			};
			ColorSquare.selectedBoxes.length = 0;
			i = 0;
			while (i < nextSelected.length)
			{
				ColorSquare.selectedBoxes.push(nextSelected[i]);
				i++;
			};
			ColorSquare.endBulkUpdate();
			suppressSelectionSideEffects = false;
			skipSliderApplyOnce = true;
			onColorSelectionChanged();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function resetActiveColors():void
		{
			var box:ColorSquare;
			var baseColor:uint;
			var repl:uint;
			var source:Object;
			var skipped:int;
			if (ColorSquare.selectedBoxes.length == 0)
			{
				return;
			};
			source = sessionBaselineData || baseCostumeData || currentPaletteData;
			cancelSelectionPulse(false);
			cancelSelectHighlightFlash(false);
			pushUndoSnapshot();
			skipped = 0;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				baseColor = uint(box.colorValue);
				if (!canActiveGroupEditBase(baseColor))
				{
					skipped++;
					continue;
				};
				repl = applyReplacementsFromSource(source, baseColor);
				box.updateIndicator(repl);
				selectionEntryReplacements[String(baseColor)] = repl;
			};
			notifyOwnershipSkips(skipped);
			applyActivePalettes(true);
			refreshAllGroupFaces();
			ensureGroupAfterRecolor();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			trackFlashCycleIfAny();
		}

		private function recolorSelectedToBase():void
		{
			var box:ColorSquare;
			var baseColor:uint;
			var repl:uint;
			var source:Object;
			var skipped:int;
			if (ColorSquare.selectedBoxes.length == 0)
			{
				return;
			};
			source = baseCostumeData || currentPaletteData;
			cancelSelectionPulse(false);
			cancelSelectHighlightFlash(false);
			pushUndoSnapshot();
			skipped = 0;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				baseColor = uint(box.colorValue);
				if (!canActiveGroupEditBase(baseColor))
				{
					skipped++;
					continue;
				};
				repl = applyReplacementsFromSource(source, baseColor);
				box.updateIndicator(repl);
				selectionEntryReplacements[String(baseColor)] = repl;
			};
			notifyOwnershipSkips(skipped);
			applyActivePalettes(true);
			refreshAllGroupFaces();
			ensureGroupAfterRecolor();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			trackFlashCycleIfAny();
		}

		/** Recolor to OG: identity replacements (No Recolor / original art keys). */
		private function recolorSelectedToOriginal():void
		{
			var box:ColorSquare;
			var baseColor:uint;
			var skipped:int;
			if (ColorSquare.selectedBoxes.length == 0)
			{
				return;
			};
			cancelSelectionPulse(false);
			cancelSelectHighlightFlash(false);
			pushUndoSnapshot();
			skipped = 0;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				baseColor = uint(box.colorValue);
				if (!canActiveGroupEditBase(baseColor))
				{
					skipped++;
					continue;
				};
				updatePaletteColor(baseColor, baseColor);
				box.updateIndicator(baseColor);
				selectionEntryReplacements[String(baseColor)] = baseColor;
			};
			notifyOwnershipSkips(skipped);
			applyActivePalettes(true);
			refreshAllGroupFaces();
			ensureGroupAfterRecolor();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			trackFlashCycleIfAny();
		}

		private function createGroupFromSelection():void
		{
			var members:Array = [];
			var box:ColorSquare;
			var group:PaletteGroupSquare;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (box && !(box is PaletteGroupSquare) && members.indexOf(uint(box.colorValue)) == -1)
				{
					members.push(uint(box.colorValue));
				};
			};
			if (members.length == 0)
			{
				
				Ssf2.MultiplayerManager.notify("Select colors first");
				return;
			};
			// Colors may belong to multiple groups. Leftmost enabled group that
			// contains a base owns its paint; shared membership is intentional.
			group = new PaletteGroupSquare(members, BOX_SIZE, onGroupActivate, nextGroupName(), onGroupDragReorder, onGroupDragEnd);
			group.autoGenerated = false;
			group.userModified = false;
			if (ColorSquare.selectedBoxes.length > 0 && ColorSquare.selectedBoxes[0])
			{
				group.primaryColor = uint(ColorSquare.selectedBoxes[0].colorValue);
			}
			else
			{
				group.primaryColor = uint(members[0]);
			};
			groupSquares.push(group);
			refreshGroupFace(group);
			layoutGroupRow();
			layoutToolRow();
			refreshColorBoxScroll();
			cancelSelectionPulse(true);
			onGroupActivate(group);
			
			saveColorGroups();
			// Membership is exactly what the user selected; nothing is auto-moved.
			PaletteMakerAchievements.track("group_created", { "groupCount": groupSquares.length });
			PaletteMakerAchievements.unlock("ritual_new_group_tool");
			if (members.length == 1)
			{
				PaletteMakerAchievements.unlock("group_solo_member");
			};
			if (members.length >= 20)
			{
				PaletteMakerAchievements.unlock("group_big_members");
			};
			if (isolateMode)
			{
				PaletteMakerAchievements.unlock("group_after_isolate");
			};
			if (characterFrozen)
			{
				PaletteMakerAchievements.unlock("group_while_frozen");
			};
		}

		private function onGroupActivate(group:PaletteGroupSquare):void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var color:uint;
			if (!group)
			{
				return;
			};
			if (activeGroup == group && group.isSelected)
			{
				activeGroup = null;
				clearGroupSelections();
				skipSliderApplyOnce = true;
				cancelSelectionPulse(true);
				ColorSquare.deselectAll();
				refreshPrimaryBadges();
				refreshPriorityMarkers();
				updateDefaultToolHint();
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				return;
			};
			clearGroupSelections();
			activeGroup = group;
			group.setSelected(true);
			updateDefaultToolHint();
			ensureGroupPrimary(group);
			suppressSelectionSideEffects = true;
			ColorSquare.beginBulkUpdate();
			ColorSquare.selectedBoxes.length = 0;
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare)
				{
					box = child as ColorSquare;
					box.setSelected(false);
				};
				i++;
			};
			for each (color in group.memberColors)
			{
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare)
					{
						box = child as ColorSquare;
						// Exact member only — colorsMatch would also select same-RGB
						// siblings owned by earlier groups and inflate the edit set.
						if (uint(box.colorValue) == uint(color))
						{
							box.setSelected(true);
							if (ColorSquare.selectedBoxes.indexOf(box) == -1)
							{
								ColorSquare.selectedBoxes.push(box);
							};
							break;
						};
					};
					i++;
				};
			};
			ColorSquare.endBulkUpdate();
			suppressSelectionSideEffects = false;
			skipSliderApplyOnce = true;
			pendingUnrecoloredGroupReset = isGroupUnrecolored(group);
			lastSelectionCount = ColorSquare.selectedBoxes.length;
			onColorSelectionChanged();
			refreshPrimaryBadges();
			refreshPriorityMarkers();
			
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		/**
		 * Apply selection delta to the active unlocked group.
		 * Only adds newlySelected and removes deselected — never re-diffs full membership
		 * against selectedBoxes (that wiped groups on single-member clicks).
		 */
		private function syncActiveGroupMembership(newlySelected:Object, deselected:Object):void
		{
			var color:uint;
			var key:String;
			var added:Array;
			var orphaned:Array;
			if (!activeGroup)
			{
				return;
			};
			if (activeGroup.locked)
			{
				return;
			};
			orphaned = [];
			if (deselected)
			{
				for (key in deselected)
				{
					color = uint(key);
					if (!activeGroup.hasMember(color))
					{
						continue;
					};
					activeGroup.removeMember(color);
					clearGroupLayerKeysForColor(activeGroup, color);
					if (!isColorInAnyGroup(color))
					{
						orphaned.push(color);
					};
				};
			};
			if (orphaned.length > 0)
			{
				revertColorsToSessionBaseline(orphaned);
			};
			added = [];
			if (newlySelected)
			{
				for (key in newlySelected)
				{
					color = uint(key);
					// Shared membership allowed — later groups may also list earlier
					// bases. Paint still gated by canGroupEditBase (leftmost enabled).
					if (activeGroup.addMember(color))
					{
						// Truly new members only — do NOT swatch-apply on group activate
						// (that was re-painting the whole catch-all group every click).
						added.push(color);
					};
				};
			};
			if (activeGroup.memberColors.length == 0)
			{
				removeGroupSquare(activeGroup);
				activeGroup = null;
			}
			else
			{
				ensureGroupPrimary(activeGroup);
				// Re-apply swatch to the whole group when membership grows. Applying
				// only `added` (shade path) left the primary's exact ARGB mapping stale
				// behind duplicate keys — first color looked unrecolored in-game.
				if (added.length > 0 && activeGroup.hasSwatchColor
					&& (activeGroup.useSwatch || activeGroup.matchAllMode))
				{
					applySwatchToGroupMembers(activeGroup, activeGroup.memberColors.concat(), true);
				}
				else if (added.length > 0 || (deselected && hasAnyKey(deselected)))
				{
					refreshGroupFace(activeGroup);
				};
				refreshColorSettingsHeader();
			};
			// Membership changes can hand ownership to another layer (or orphan a base).
			if ((deselected && hasAnyKey(deselected)) || added.length > 0)
			{
				reapplyOwnerLayerPalette();
			};
			refreshPrimaryBadges();
			saveColorGroups();
		}

		private function revertColorsToSessionBaseline(colors:Array):void
		{
			var member:uint;
			var repl:uint;
			var source:Object;
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			if (!colors || colors.length == 0)
			{
				return;
			};
			// Prefer stock/base over sessionBaseline: costume load snapshots session
			// AFTER applying file replacements (including prior match-all whites), so
			// reverting orphans to session re-whites pupils that were just deselected.
			source = baseCostumeData || sessionBaselineData || currentPaletteData;
			cancelSelectionPulse(false);
			for each (member in colors)
			{
				repl = applyReplacementsFromSource(source, uint(member));
				if (selectionEntryReplacements)
				{
					selectionEntryReplacements[String(uint(member))] = repl;
				};
				i = 0;
				while (m_subMenu && m_subMenu.colorBoxBG && i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
						if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), uint(member)))
						{
							box.updateIndicator(repl);
						};
					};
					i++;
				};
			};
			applyActivePalettes(true);
			refreshAllGroupFaces();
		}

		private function applySwatchToGroupMembers(group:PaletteGroupSquare, members:Array, pushUndo:Boolean):int
		{
			var member:uint;
			var newRepl:uint;
			var child:DisplayObject;
			var box:ColorSquare;
			var i:int;
			var skipped:int;
			var skippedOwner:int;
			var wrote:int;
			var flatCount:int;
			var skipSample:Array;
			var owner:PaletteGroupSquare;
			if (!group || !members || members.length == 0 || !group.hasSwatchColor)
			{
				return 0;
			};
			if (pushUndo)
			{
				pushUndoSnapshot();
			};
			rememberPreSwatchForMembers(group, members);
			skipped = 0;
			skippedOwner = 0;
			wrote = 0;
			flatCount = 0;
			skipSample = [];
			
			for each (member in members)
			{
				if (!canGroupEditBase(group, uint(member)))
				{
					skipped++;
					skippedOwner++;
					
					continue;
				};
				// No near-skip here: membership is exactly what the user selected,
				// so every member this group lists must be painted. Cross-group pixel
				// bleed is prevented in Ssf2.Utils.replacePaletteHelper (original-pixel match).
				if (shouldFlatMatchSwatch(group, uint(member)))
				{
					flatCount++;
				};
				newRepl = computeGroupSwatchReplacement(group, uint(member));
				updatePaletteColor(uint(member), newRepl, false, group);
				recordGroupLayerReplacement(group, uint(member), newRepl);
				wrote++;
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
						if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), uint(member)))
						{
							box.updateIndicator(newRepl);
						};
					};
					i++;
				};
			};
			if (!group.matchAllMode)
			{
				notifyOwnershipSkips(skippedOwner);
			};
			
			// Repaint only earlier groups — full reapply was re-matchAll'ing stolen
			// neighbors onto the wrong group after membership churn.
			reapplyHigherPriorityLayers(group);
			refreshGroupFace(group);
			refreshPriorityMarkers();
			applyActivePalettes(true);
			return wrote;
		}

		/** Re-apply layer/swatch paint for groups to the left of `afterGroup` only. */
		private function reapplyHigherPriorityLayers(afterGroup:PaletteGroupSquare):void
		{
			var idx:int;
			var i:int;
			var owner:PaletteGroupSquare;
			var member:*;
			var baseColor:uint;
			var repl:uint;
			var layerVal:*;
			var child:DisplayObject;
			var box:ColorSquare;
			var j:int;
			var any:Boolean;
			if (!afterGroup || !currentPaletteData || !groupSquares)
			{
				return;
			};
			idx = groupSquares.indexOf(afterGroup);
			if (idx <= 0)
			{
				return;
			};
			any = false;
			i = 0;
			while (i < idx)
			{
				owner = groupSquares[i] as PaletteGroupSquare;
				if (!owner || !owner.memberColors || owner.groupEnabled == false)
				{
					i++;
					continue;
				};
				for each (member in owner.memberColors)
				{
					baseColor = uint(member);
					if (getOwnerGroupForBase(baseColor) != owner)
					{
						continue;
					};
					layerVal = lookupGroupLayerReplacement(owner, baseColor);
					if (layerVal != null)
					{
						repl = uint(layerVal);
					}
					else if (owner.hasSwatchColor && (owner.useSwatch || owner.matchAllMode))
					{
						repl = computeGroupSwatchReplacement(owner, baseColor);
					}
					else
					{
						continue;
					};
					if (uint(getCurrentReplacementForColor(baseColor)) == uint(repl))
					{
						continue;
					};
					updatePaletteColor(baseColor, repl, false, owner);
					any = true;
					if (m_subMenu && m_subMenu.colorBoxBG)
					{
						j = 0;
						while (j < m_subMenu.colorBoxBG.numChildren)
						{
							child = m_subMenu.colorBoxBG.getChildAt(j);
							if (child is ColorSquare && !(child is PaletteGroupSquare))
							{
								box = child as ColorSquare;
								if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), baseColor))
								{
									box.updateIndicator(repl);
								};
							};
							j++;
						};
					};
				};
				i++;
			};
			
		}

		private function restorePreSwatchReplacements(group:PaletteGroupSquare):void
		{
			var member:uint;
			var repl:uint;
			var child:DisplayObject;
			var box:ColorSquare;
			var i:int;
			if (!group || !group.preSwatchReplacements)
			{
				return;
			};
			for each (member in group.memberColors)
			{
				if (group.preSwatchReplacements[uint(member)] == null)
				{
					continue;
				};
				repl = uint(group.preSwatchReplacements[uint(member)]);
				updatePaletteColor(uint(member), repl);
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
						if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), uint(member)))
						{
							box.updateIndicator(repl);
						};
					};
					i++;
				};
			};
			refreshGroupFace(group);
			applyActivePalettes(true);
		}

		private function removeGroupSquare(group:PaletteGroupSquare):void
		{
			var idx:int;
			if (!group)
			{
				return;
			};
			idx = groupSquares.indexOf(group);
			if (idx != -1)
			{
				groupSquares.splice(idx, 1);
			};
			group.killEvents();
			if (m_subMenu.colorBoxBG.contains(group))
			{
				m_subMenu.colorBoxBG.removeChild(group);
			};
			layoutGroupRow();
			layoutToolRow();
			refreshColorBoxScroll();
			saveColorGroups();
		}

		override protected function onClearAllGroupsClick(e:MouseEvent):void
		{
			var count:int;
			if (!groupSquares || groupSquares.length == 0)
			{
				return;
			};
			count = groupSquares.length;
			try
			{
				Ssf2.MenuController.onlinePromptMenu.message = "Delete all " + count + " color group(s)?\nThis cannot be undone.";
				Ssf2.MenuController.onlinePromptMenu.onAccept = executeClearAllGroups;
				Ssf2.MenuController.onlinePromptMenu.onDismiss = cancelClearAllGroupsPrompt;
				Ssf2.MenuController.onlinePromptMenu.show();
			}
			catch (promptErr:Error)
			{
				Ssf2.MultiplayerManager.notify("Could not open confirm");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		private function cancelClearAllGroupsPrompt():void
		{
			try
			{
				Ssf2.MenuController.onlinePromptMenu.removeSelf();
			}
			catch (err:Error)
			{
			};
		}

		private function executeClearAllGroups():void
		{
			var i:int;
			var group:PaletteGroupSquare;
			var members:Array;
			var member:*;
			var seen:Object;
			var allMembers:Array;
			try
			{
				Ssf2.MenuController.onlinePromptMenu.removeSelf();
			}
			catch (err:Error)
			{
			};
			if (!groupSquares || groupSquares.length == 0)
			{
				return;
			};
			pushUndoSnapshot();
			seen = {};
			allMembers = [];
			i = 0;
			while (i < groupSquares.length)
			{
				group = groupSquares[i] as PaletteGroupSquare;
				if (group && group.memberColors)
				{
					for each (member in group.memberColors)
					{
						if (!seen[String(uint(member))])
						{
							seen[String(uint(member))] = true;
							allMembers.push(uint(member));
						};
					};
				};
				i++;
			};
			resetGroupMembersToBase(allMembers);
			activeGroup = null;
			closeColorSettings();
			i = groupSquares.length - 1;
			while (i >= 0)
			{
				group = groupSquares[i] as PaletteGroupSquare;
				if (group)
				{
					group.killEvents();
					if (m_subMenu.colorBoxBG.contains(group))
					{
						m_subMenu.colorBoxBG.removeChild(group);
					};
				};
				i--;
			};
			groupSquares = [];
			layoutGroupRow();
			layoutToolRow();
			refreshColorBoxScroll();
			saveColorGroups();
			reapplyOwnerLayerPalette();
			skipSliderApplyOnce = true;
			suppressSelectionSideEffects = true;
			ColorSquare.deselectAll();
			suppressSelectionSideEffects = false;
			clearSelectionEntryReplacements();
			refreshPrimaryBadges();
			refreshSelectionVisualsOnly();
			Ssf2.MultiplayerManager.notify("All color groups deleted");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.track("group_deleted");
		}

		private function onGroupDragEnd(group:PaletteGroupSquare):void
		{
			reapplyOwnerLayerPalette();
			
			saveColorGroups();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.track("group_reordered");
			if (groupSquares.length > 0 && groupSquares[0] == group)
			{
				PaletteMakerAchievements.unlock("group_priority_top");
			};
		}

		/** Load costume / open editor: restore saved group membership only. */
		private function applyColorGroupsForLoadedCostume():void
		{
			pendingAutoGroups = false;
			autoGroupsGenerated = true;
			clearAutoGroupSquares();
			if (restorePersistedColorGroups())
			{
				layoutGroupRow();
				layoutToolRow();
				refreshColorBoxScroll();
				// Do not reapplyOwnerLayerPalette — replacements are session-only.
				Ssf2.MultiplayerManager.notify("Color groups loaded");
				return;
			};
			layoutGroupRow();
			layoutToolRow();
			refreshColorBoxScroll();
		}

		private function tryGenerateAutoGroups():void
		{
			if (!pendingAutoGroups || autoGroupsGenerated)
			{
				return;
			};
			if (!PixelArt && !(player && player.MC))
			{
				return;
			};
			applyColorGroupsForLoadedCostume();
		}

		private function clearAutoGroupSquares():void
		{
			var i:int;
			var group:PaletteGroupSquare;
			activeGroup = null;
			i = groupSquares.length - 1;
			while (i >= 0)
			{
				group = groupSquares[i] as PaletteGroupSquare;
				if (group)
				{
					group.killEvents();
					if (m_subMenu.colorBoxBG.contains(group))
					{
						m_subMenu.colorBoxBG.removeChild(group);
					};
				};
				i--;
			};
			groupSquares = [];
			layoutToolRow();
			refreshColorBoxScroll();
		}

		private function restorePersistedColorGroups():Boolean
		{
			var so:SharedObject;
			var key:String;
			var saved:*;
			var entry:Object;
			var members:Array;
			var filtered:Array;
			var color:uint;
			var i:int;
			var group:PaletteGroupSquare;
			var hadEntries:Boolean;
			var restoredCount:int;
			if (!statsName || !m_subMenu || !m_subMenu.colorBoxBG)
			{
				return false;
			};
			key = String(statsName);
			try
			{
				so = SharedObject.getLocal("ssf2_palette_maker_settings");
				if (!so || !so.data || !so.data.colorGroups || !so.data.colorGroups.hasOwnProperty(key))
				{
					return false;
				};
				saved = so.data.colorGroups[key];
			}
			catch (err:Error)
			{
				return false;
			};
			if (!(saved is Array))
			{
				return false;
			};
			hadEntries = (saved as Array).length > 0;
			restoredCount = 0;
			for each (entry in saved as Array)
			{
				if (!entry)
				{
					continue;
				};
				if (entry.autoGenerated == true)
				{
					continue;
				};
				members = (entry.memberColors is Array) ? (entry.memberColors as Array) : [];
				filtered = [];
				i = 0;
				while (i < members.length)
				{
					color = uint(members[i]);
					resolveMemberAgainstMixedBase(color, filtered);
					i++;
				};
				filtered = ColorGroupPersist.membersForRestore(members, filtered);
				if (filtered.length == 0)
				{
					continue;
				};
				group = new PaletteGroupSquare(filtered, BOX_SIZE, onGroupActivate, entry.groupName ? String(entry.groupName) : nextGroupName(), onGroupDragReorder, onGroupDragEnd);
				ColorGroupPersist.applyMembershipOnly(group, {
					"groupName": entry.groupName,
					"memberColors": filtered,
					"primaryColor": entry.primaryColor,
					"locked": entry.locked,
					"enabled": entry.enabled,
					"autoGenerated": false,
					"userModified": entry.userModified,
					"formName": entry.formName,
					"matchAllMode": entry.matchAllMode
				});
				groupSquares.push(group);
				refreshGroupFace(group);
				restoredCount++;
			};
			if (restoredCount > 0)
			{
				return true;
			};
			// Intentional empty save (user deleted all groups) must stick.
			return !hadEntries;
		}

		private function ensureGroupForColorSettings():PaletteGroupSquare
		{
			var group:PaletteGroupSquare = findExactGroupForSelection();
			if (group)
			{
				if (activeGroup != group || !group.isSelected)
				{
					onGroupActivate(group);
				}
				else
				{
					ensureGroupPrimary(group);
					refreshPrimaryBadges();
				};
				return group;
			};
			createGroupFromSelection();
			return activeGroup;
		}

		/** After a recolor, add same-form colors to the active group. A new group is only for a form that has none active. */
		private function ensureGroupAfterRecolor():void
		{
			var group:PaletteGroupSquare;
			if (!ColorSquare.selectedBoxes || ColorSquare.selectedBoxes.length == 0)
			{
				return;
			};
			group = findExactGroupForSelection();
			if (group)
			{
				if (activeGroup != group || !group.isSelected)
				{
					onGroupActivate(group);
				};
				return;
			};
			createGroupFromSelection();
		}

		/** True when the active group is this form, so the selection joins it instead of starting another group. */

		private function openColorSettings():void
		{
			var group:PaletteGroupSquare;
			var px:Number;
			var py:Number;
			if (ColorSquare.selectedBoxes.length == 0)
			{
				Ssf2.MultiplayerManager.notify("Select colors first");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				PaletteMakerAchievements.unlock("secret_cs_no_group");
				return;
			};
			group = ensureGroupForColorSettings();
			if (!group)
			{
				return;
			};
			ensureGroupPrimary(group);
			refreshPrimaryBadges();
			if (!colorSettingsPopup)
			{
				colorSettingsPopup = new ColorSettingsPopup();
				colorSettingsPopup.onClose = closeColorSettings;
				colorSettingsPopup.onPickSwatchColor = onCsPickSwatchColor;
				colorSettingsPopup.onPickSwatchPreview = onCsPickSwatchPreview;
				colorSettingsPopup.onWheelOpen = onCsWheelOpen;
				colorSettingsPopup.onWheelCancel = onCsWheelCancel;
				colorSettingsPopup.onEyedropper = onCsEyedropper;
				colorSettingsPopup.onChangePrimary = onCsChangePrimary;
				colorSettingsPopup.onCancelPrimaryPick = onCsCancelPrimaryPick;
				colorSettingsPopup.onMatchAll = onCsMatchAll;
				colorSettingsPopup.onUndoMatchAll = onCsUndoMatchAll;
				colorSettingsPopup.onDontUseSwatchKeep = onCsDontUseSwatchKeep;
				colorSettingsPopup.onDontUseSwatchUndo = onCsDontUseSwatchUndo;
				colorSettingsPopup.onRenameGroup = onCsRenameGroup;
				colorSettingsPopup.onDeleteGroup = onCsDeleteGroup;
				colorSettingsPopup.onToggleLock = onCsToggleLock;
				colorSettingsPopup.onToggleEnabled = onCsToggleEnabled;
				colorSettingsPopup.onTextFocusChange = onCsTextFocusChange;
				m_subMenu.addChild(colorSettingsPopup);
			};
			fxColorSettingsMode = false;
			px = m_subMenu.colors ? m_subMenu.colors.x - 8 : 420;
			py = m_subMenu.colors ? m_subMenu.colors.y + 4 : 40;
			colorSettingsPopup.showAt(
				px,
				py,
				group.memberColors.length,
				getCurrentReplacementForColor(uint(group.primaryColor)),
				group.hasSwatchColor ? group.swatchColor : getCurrentReplacementForColor(uint(group.primaryColor)),
				group.hasSwatchColor,
				group.useSwatch,
				group.matchAllMode,
				group.groupName,
				group.locked,
				group.groupEnabled != false
			);
			colorSettingsGroup = group;
			hideMagnifier();
			if (Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_DOWN, onColorSettingsStageDown, true, 0, true);
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		/** RE mode: reuse ColorSettingsPopup to pick a solid color for the active FX group. */
		private function openFxGroupColorSettings():void
		{
			var group:Object;
			var px:Number;
			var py:Number;
			var swatch:uint;
			group = ensureActiveFxGroup();
			if (!group)
			{
				Ssf2.MultiplayerManager.notify("Make an FX group first (select sprites + NG)");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			if (!colorSettingsPopup)
			{
				colorSettingsPopup = new ColorSettingsPopup();
				colorSettingsPopup.onClose = closeColorSettings;
				colorSettingsPopup.onPickSwatchColor = onCsPickSwatchColor;
				colorSettingsPopup.onPickSwatchPreview = onCsPickSwatchPreview;
				colorSettingsPopup.onWheelOpen = onCsWheelOpen;
				colorSettingsPopup.onWheelCancel = onCsWheelCancel;
				colorSettingsPopup.onEyedropper = onCsEyedropper;
				colorSettingsPopup.onChangePrimary = onCsChangePrimary;
				colorSettingsPopup.onCancelPrimaryPick = onCsCancelPrimaryPick;
				colorSettingsPopup.onMatchAll = onCsMatchAll;
				colorSettingsPopup.onUndoMatchAll = onCsUndoMatchAll;
				colorSettingsPopup.onDontUseSwatchKeep = onCsDontUseSwatchKeep;
				colorSettingsPopup.onDontUseSwatchUndo = onCsDontUseSwatchUndo;
				colorSettingsPopup.onRenameGroup = onCsRenameGroup;
				colorSettingsPopup.onDeleteGroup = onCsDeleteGroup;
				colorSettingsPopup.onToggleLock = onCsToggleLock;
				colorSettingsPopup.onToggleEnabled = onCsToggleEnabled;
				colorSettingsPopup.onTextFocusChange = onCsTextFocusChange;
				m_subMenu.addChild(colorSettingsPopup);
			};
			fxColorSettingsMode = true;
			colorSettingsGroup = null;
			swatch = PaletteMakerUtils.coerceColorValue(group.color);
			if ((swatch & 0x00FFFFFF) == 0)
			{
				swatch = 0xFFFF0000;
			};
			px = m_subMenu.colors ? m_subMenu.colors.x - 8 : 420;
			py = m_subMenu.colors ? m_subMenu.colors.y + 4 : 40;
			colorSettingsPopup.showAt(
				px,
				py,
				(group.linkages as Array) ? (group.linkages as Array).length : 0,
				swatch,
				swatch,
				true,
				true,
				false,
				String(group.name || "FX group"),
				false,
				true
			);
			hideMagnifier();
			if (Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_DOWN, onColorSettingsStageDown, true, 0, true);
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			
		}

		private function applyCsSwatchColor(color:uint, pushUndo:Boolean):void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			var targets:Array;
			var member:uint;
			var fxGroup:Object;
			if (fxColorSettingsMode)
			{
				fxGroup = ensureActiveFxGroup();
				if (!fxGroup)
				{
					return;
				};
				// First solid color pick: desaturate so tint reads cleanly.
				if ((PaletteMakerUtils.coerceColorValue(fxGroup.color) & 0x00FFFFFF) == 0)
				{
					if ((Number(fxGroup.saturation) || 0) != -100)
					{
						fxGroup.saturation = -100;
						syncRecolorEffectsSlidersFromFxFields();
					};
				};
				fxGroup.color = PaletteMakerUtils.coerceColorValue(color);
				if (colorSettingsPopup)
				{
					colorSettingsPopup.setSwatchColor(color, true);
				};
				// Do not writeRecolorEffectsFxFields here — that re-reads sliders and can
				// clobber sat=-100 / color before arrows settle. Mirror legacy only.
				mirrorLegacyFxFromActiveGroup();
				rebuildFxGroupSquares();
				applyRecolorEffectsFiltersPreview();
				
				return;
			};
			if (!group)
			{
				return;
			};
			cancelSelectHighlightFlash(false);
			if (pushUndo)
			{
				pushUndoSnapshot();
			};
			capturePreSwatchReplacements(group);
			if (group.preSwatchReplacements && group.preSwatchReplacements[uint(group.primaryColor)] != null)
			{
				group.swatchRelativePrimary = uint(group.preSwatchReplacements[uint(group.primaryColor)]);
			}
			else
			{
				group.swatchRelativePrimary = getCurrentReplacementForColor(uint(group.primaryColor));
			};
			group.swatchColor = color;
			group.hasSwatchColor = true;
			group.useSwatch = true;
			if (group.matchAllMode)
			{
				// Merge missing exact keys into the palette, but do NOT expand
				// group membership with every unique-cover color (that recolored
				// the whole character on Match All).
				mergeMissingColorsFromUniqueSprites();
				ensureMatchAllExactKeysForGroupMembers(group);
			};
			targets = [];
			for each (member in group.memberColors)
			{
				if (colorIsCurrentlySelected(uint(member)))
				{
					targets.push(uint(member));
				};
			};
			if (targets.length == 0 || group.matchAllMode)
			{
				targets = group.memberColors.concat();
			};
			applySwatchToGroupMembers(group, targets, false);
			refreshColorSettingsHeader();
			if (colorSettingsPopup)
			{
				colorSettingsPopup.setSwatchColor(color, true);
			};
			saveColorGroups();
		}

		private function onCsWheelCancel():void
		{
			if (csWheelSnapshot)
			{
				restoreSnapshot(csWheelSnapshot);
				csWheelSnapshot = null;
			};
			refreshColorSettingsHeader();
			var group:PaletteGroupSquare = getColorSettingsGroup();
			if (group && colorSettingsPopup)
			{
				colorSettingsPopup.setSwatchColor(
					group.hasSwatchColor ? group.swatchColor : getCurrentReplacementForColor(uint(group.primaryColor)),
					group.hasSwatchColor
				);
			};
		}

		private function onCsPickSwatchPreview(color:uint):void
		{
			applyCsSwatchColor(color, false);
		}

		private function onCsPickSwatchColor(color:uint):void
		{
			if (csWheelSnapshot)
			{
				undoStack.push(csWheelSnapshot);
				if (undoStack.length > UNDO_LIMIT)
				{
					undoStack.shift();
				};
				redoStack.length = 0;
				csWheelSnapshot = null;
				applyCsSwatchColor(color, false);
			}
			else
			{
				applyCsSwatchColor(color, true);
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function finishPrimaryPick(primaryBase:uint):void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup() || activeGroup;
			if (!group)
			{
				cancelPrimaryPick("Primary change cancelled");
				return;
			};
			if (!group.hasMember(primaryBase))
			{
				cancelPrimaryPick("Primary change cancelled");
				return;
			};
			pushUndoSnapshot();
			group.primaryColor = primaryBase;
			refreshPrimaryBadges();
			exitPrimaryPickMode();
			if (colorSettingsPopup)
			{
				colorSettingsPopup.setPrimaryPickMode(false);
				colorSettingsPopup.visible = true;
				colorSettingsPopup.mouseEnabled = true;
				colorSettingsPopup.mouseChildren = true;
			};
			if (group.hasSwatchColor)
			{
				group.useSwatch = true;
				if (group.preSwatchReplacements && group.preSwatchReplacements[primaryBase] != null)
				{
					group.swatchRelativePrimary = uint(group.preSwatchReplacements[primaryBase]);
				}
				else
				{
					group.swatchRelativePrimary = getSessionReplacementForColor(primaryBase);
				};
				applySwatchToGroupMembers(group, group.memberColors.concat(), false);
			};
			refreshColorSettingsHeader();
			Ssf2.MultiplayerManager.notify("Primary color changed");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			saveColorGroups();
		}

		private function onCsChangePrimary():void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			if (!group)
			{
				return;
			};
			csEyedropperMode = false;
			ColorSquare.primaryPickMode = true;
			ColorSquare.canPrimaryPick = function(box:ColorSquare):Boolean {
				return group && box && group.hasMember(uint(box.colorValue));
			};
			ColorSquare.onPrimaryPick = function(box:ColorSquare):void {
				if (!group || !box)
				{
					cancelPrimaryPick("Primary change cancelled");
					return;
				};
				finishPrimaryPick(uint(box.colorValue));
			};
			ColorSquare.onPrimaryPickCancel = function():void {
				cancelPrimaryPick("Primary change cancelled");
			};
			if (colorSettingsPopup)
			{
				colorSettingsPopup.setPrimaryPickMode(true);
				colorSettingsPopup.visible = false;
				colorSettingsPopup.mouseEnabled = false;
				colorSettingsPopup.mouseChildren = false;
			};
			Ssf2.MultiplayerManager.notify("Click swatch, sprite, or PA for primary");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function onCsMatchAll():void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			var members:Array;
			var wrote:int;
			var skipped:int;
			var pulled:int;
			if (!group)
			{
				return;
			};
			if (!group.hasSwatchColor)
			{
				Ssf2.MultiplayerManager.notify("Pick a swatch color first");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			pushUndoSnapshot();
			// Ensure same-RGB exact keys from unique sprites exist in the palette
			// (Beat pupils / alpha siblings). Never add unrelated unique colors
			// as new group members — that was painting half the character.
			mergeMissingColorsFromUniqueSprites();
			pulled = ensureMatchAllExactKeysForGroupMembers(group);
			capturePreSwatchReplacements(group);
			group.useSwatch = true;
			group.matchAllMode = true;
			members = group.memberColors.concat();
			wrote = applySwatchToGroupMembers(group, members, false);
			skipped = members.length - wrote;
			refreshColorSettingsHeader();
			if (skipped > 0)
			{
				Ssf2.MultiplayerManager.notify("Matched " + wrote + " to swatch (skipped " + skipped
					+ " owned by earlier groups)");
			}
			else
			{
				Ssf2.MultiplayerManager.notify("Matched " + wrote + " colors to swatch"
					+ (pulled > 0 ? (" (+" + pulled + " exact keys)") : ""));
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			saveColorGroups();
			PaletteMakerAchievements.track("group_match_all");
		}

		private function onCsUndoMatchAll():void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			if (!group)
			{
				return;
			};
			if (!group.matchAllMode)
			{
				return;
			};
			pushUndoSnapshot();
			group.matchAllMode = false;
			group.useSwatch = true;
			applyShadesFromPreSwatch(group);
			refreshColorSettingsHeader();
			Ssf2.MultiplayerManager.notify("Match-all undone");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			saveColorGroups();
			PaletteMakerAchievements.unlock("group_match_undo");
		}

		private function applyShadesFromPreSwatch(group:PaletteGroupSquare):void
		{
			var member:uint;
			var seed:uint;
			var newRepl:uint;
			var oldPrimaryRepl:uint;
			var child:DisplayObject;
			var box:ColorSquare;
			var i:int;
			var skipped:int;
			if (!group || !group.hasSwatchColor)
			{
				return;
			};
			oldPrimaryRepl = group.swatchRelativePrimary != 0 ? group.swatchRelativePrimary : getSessionReplacementForColor(uint(group.primaryColor));
			skipped = 0;
			for each (member in group.memberColors)
			{
				if (!canGroupEditBase(group, uint(member)))
				{
					skipped++;
					continue;
				};
				if (group.preSwatchReplacements && group.preSwatchReplacements[uint(member)] != null)
				{
					seed = uint(group.preSwatchReplacements[uint(member)]);
				}
				else
				{
					seed = getCurrentReplacementForColor(uint(member));
				};
				if (PaletteColorAnalysis.colorsMatch(uint(member), uint(group.primaryColor)))
				{
					newRepl = group.swatchColor;
				}
				else
				{
					newRepl = PaletteColorAnalysis.recolorGroupAsShades(oldPrimaryRepl, group.swatchColor, seed);
				};
				updatePaletteColor(uint(member), newRepl, false, group);
				recordGroupLayerReplacement(group, uint(member), newRepl);
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
						if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), uint(member)))
						{
							box.updateIndicator(newRepl);
						};
					};
					i++;
				};
			};
			notifyOwnershipSkips(skipped);
			reapplyHigherPriorityLayers(group);
			refreshGroupFace(group);
			applyActivePalettes(true);
		}

		private function onCsDontUseSwatchUndo():void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			if (!group)
			{
				Ssf2.MultiplayerManager.notify("No active group");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			pushUndoSnapshot();
			restorePreSwatchReplacements(group);
			group.clearSwatchState();
			adoptCurrentAsSessionSeedsForColors(group.memberColors);
			resetSlidersToDefault();
			refreshColorSettingsHeader();
			Ssf2.MultiplayerManager.notify("Swatch undone");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			saveColorGroups();
		}

		private function onCsRenameGroup(newName:String):void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			var fxGroup:Object;
			if (fxColorSettingsMode)
			{
				fxGroup = getActiveFxGroup();
				if (fxGroup && newName)
				{
					fxGroup.name = newName;
					rebuildFxGroupSquares();
				};
				return;
			};
			if (!group)
			{
				return;
			};
			group.setGroupName(newName);
			updateDefaultToolHint();
			saveColorGroups();
		}

		private function onCsToggleEnabled():void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			if (fxColorSettingsMode)
			{
				return;
			};
			if (!group)
			{
				Ssf2.MultiplayerManager.notify("No active group");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			group.setGroupEnabled(!group.groupEnabled);
			if (colorSettingsPopup)
			{
				colorSettingsPopup.setGroupEnabledState(group.groupEnabled);
			};
			reapplyOwnerLayerPalette();
			saveColorGroups();
			Ssf2.MultiplayerManager.notify(group.groupEnabled ? "Group enabled" : "Group disabled");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function onCsDeleteGroup():void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			var members:Array;
			var groups:Array;
			var i:int;
			var fxGroup:Object;
			if (fxColorSettingsMode)
			{
				if (!currentPaletteData || !activeFxGroupId)
				{
					return;
				};
				groups = FxRecolorUtils.ensureFxGroups(currentPaletteData);
				i = 0;
				while (i < groups.length)
				{
					fxGroup = groups[i];
					if (fxGroup && String(fxGroup.id) == String(activeFxGroupId))
					{
						groups.splice(i, 1);
						break;
					};
					i++;
				};
				currentPaletteData.fxGroups = groups;
				activeFxGroupId = (groups.length > 0) ? String(groups[0].id) : null;
				closeColorSettings();
				syncRecolorEffectsSlidersFromFxFields();
				rebuildFxGroupSquares();
				applyRecolorEffectsFiltersPreview();
				Ssf2.MultiplayerManager.notify("FX group deleted");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				return;
			};
			if (!group)
			{
				Ssf2.MultiplayerManager.notify("No active group");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			members = group.memberColors ? group.memberColors.concat() : [];
			pushUndoSnapshot();
			resetGroupMembersToBase(members);
			if (activeGroup == group)
			{
				activeGroup = null;
			};
			closeColorSettings();
			removeGroupSquare(group);
			skipSliderApplyOnce = true;
			suppressSelectionSideEffects = true;
			ColorSquare.deselectAll();
			suppressSelectionSideEffects = false;
			clearSelectionEntryReplacements();
			refreshPrimaryBadges();
			refreshSelectionVisualsOnly();
			Ssf2.MultiplayerManager.notify("Group deleted");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.track("group_deleted");
		}

		private function resetGroupMembersToBase(members:Array):void
		{
			var member:uint;
			var repl:uint;
			var source:Object;
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			if (!members || members.length == 0)
			{
				return;
			};
			source = baseCostumeData || sessionBaselineData || currentPaletteData;
			cancelSelectionPulse(false);
			for each (member in members)
			{
				repl = applyReplacementsFromSource(source, uint(member));
				if (selectionEntryReplacements)
				{
					delete selectionEntryReplacements[String(uint(member))];
				};
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
						if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), uint(member)))
						{
							box.updateIndicator(repl);
						};
					};
					i++;
				};
			};
			applyActivePalettes(true);
			refreshAllGroupFaces();
		}

		/** CurrentStatsName wins when it is Zelda or Sheik. CharacterStats stays on the form you opened. */

		private function applyActivePalettes(updatePA:Boolean):void
		{
			var swap:Object;
			var swapPA:Object;
			var stripSwap:Object;
			var stripPA:Object;
			var pulsing:Boolean;
			var shouldRefreshPa:Boolean;
			if (!currentPaletteData)
			{
				return;
			};
			var selectHl:Boolean = isSelectHighlightActive();
			if (!pulseActive && !selectHl && !characterPaletteDirty && !updatePA && !palettePADirty)
			{
				if (selectedMcName)
				{
					applyMcNameVisibility(selectedMcName);
				};
				return;
			};
			pulsing = pulseActive && !draggingSlider && pulseBrightenFactor != 1 && !selectHl;
			if (isolateMode)
			{
				swap = buildIsolatedPalette(currentPaletteData.paletteSwap);
				swapPA = buildIsolatedPalette(currentPaletteData.paletteSwapPA);
				if (pulsing || selectHl)
				{
					swap = Ssf2.Utils.cloneObject(swap);
					swapPA = Ssf2.Utils.cloneObject(swapPA);
					if (selectHl)
					{
						applySelectHighlightToPaletteBlock(swap);
						applySelectHighlightToPaletteBlock(swapPA);
					}
					else
					{
						applyPulseToPaletteBlock(swap);
						applyPulseToPaletteBlock(swapPA);
					};
				};
			}
			else if (pulsing || selectHl)
			{
				swap = Ssf2.Utils.cloneObject(currentPaletteData.paletteSwap);
				swapPA = Ssf2.Utils.cloneObject(currentPaletteData.paletteSwapPA);
				if (selectHl)
				{
					applySelectHighlightToPaletteBlock(swap);
					applySelectHighlightToPaletteBlock(swapPA);
				}
				else
				{
					applyPulseToPaletteBlock(swap);
					applyPulseToPaletteBlock(swapPA);
				};
			}
			else
			{
				swap = currentPaletteData.paletteSwap;
				swapPA = currentPaletteData.paletteSwapPA;
			};
			shouldRefreshPa = pulsing || selectHl || characterPaletteDirty || updatePA || palettePADirty;
			if (updatePA)
			{
				trace("[palette_maker] paint player=" + (player ? 1 : 0) + " dirty=" + (characterPaletteDirty ? 1 : 0));
			};
			if (player && (pulsing || selectHl || characterPaletteDirty || updatePA))
			{
				try
				{
					// A transformed partner keeps its own recolor. The opened form's
					// identity block must not replace it. Portraits stay on the opened block.
					var bodySwap:Object = liveBodySwap(swap, false);
					var bodyPA:Object = liveBodySwap(swapPA, true);
					if (bodySwap)
					{
						player.setPaletteSwap(bodySwap, bodyPA ? bodyPA : bodySwap);
						if (player.HasStance)
						{
							player.updatePaletteSwap();
						};
					};
					if (!pulsing && !selectHl)
					{
						characterPaletteDirty = false;
					};
				}
				catch (err:Error)
				{
					try
					{
						Ssf2.MultiplayerManager.notify("Palette paint error: " + err.message);
					}
					catch (ignore:Error)
					{
					};
				};
			};
			// Portraits: same as CSS PAPalette (PA only, or combine for linked forms).
			if (shouldRefreshPa)
			{
				applyLinkedPortraitPalettes(swap, swapPA);
			};
			if (updatePA)
			{
				palettePADirty = false;
			};
			// Keep unique sprites on the same paint cadence as the portrait.
			// Swatch hover dims those bitmaps itself. The fighter stays on the active costume.
			// Debounce while dragging sliders so large palettes stay responsive.
			if (settingShowUniquePaSprites && (updatePA || shouldRefreshPa))
			{
				if (!player)
				{
					pendingUniquePaRefresh = true;
				}
				else if (!uniquePaHost || uniquePaScanStatsName != PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName))
				{
					// Prefer disk/memory cache — do not force Library scan every enter.
					refreshUniquePaSprites(false);
				}
				else if (draggingSlider)
				{
					scheduleDebouncedUniquePaint(swap, swapPA);
				}
				else
				{
					updateUniquePaPalettes(swap, swapPA);
				};
			}
			else if (updatePA && !settingShowUniquePaSprites)
			{
				clearUniquePaSprites();
			};
			if (selectedMcName)
			{
				applyMcNameVisibility(selectedMcName);
			};
			if (settingDiscordCostumePreview)
			{
				DiscordCostumePresence.markPaletteMakerDirty();
			};
			if (isHoverIsolateActive())
			{
				scheduleHoverDim();
			};
		}

		private function startSelectionPulse(targets:Object=null):void
		{
			var key:String;
			var copy:Object;
			if (!Ssf2.Main.Root || draggingSlider)
			{
				return;
			};
			cancelSelectHighlightFlash(false);
			copy = {};
			if (targets)
			{
				for (key in targets)
				{
					copy[uint(key)] = true;
					copy[String(uint(key))] = true;
				};
			};
			if (!hasAnyKey(copy))
			{
				return;
			};
			pulseTargetColors = copy;
			pulseActive = true;
			pulseStartTime = getTimer();
			pulseBrightenFactor = 1;
			Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, tickSelectionPulse);
			Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, tickSelectionPulse);
			tickSelectionPulse(null);
		}

		private function cancelSelectionPulse(reapply:Boolean):void
		{
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, tickSelectionPulse);
			};
			pulseActive = false;
			pulseBrightenFactor = 1;
			pulseTargetColors = null;
			if (reapply)
			{
				applyActivePalettes(true);
				refreshSelectedSwatchTriangles();
			};
		}

		private function startSelectHighlightFlash(targets:Object=null):void
		{
			var key:String;
			var copy:Object;
			if (!settingSelectHighlight || !Ssf2.Main.Root || draggingSlider)
			{
				return;
			};
			cancelSelectionPulse(false);
			copy = {};
			if (targets)
			{
				for (key in targets)
				{
					copy[uint(key)] = true;
					copy[String(uint(key))] = true;
				};
			};
			if (!hasAnyKey(copy))
			{
				return;
			};
			selectHighlightTargets = copy;
			selectHighlightFlashActive = true;
			selectHighlightStartTime = getTimer();
			Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, tickSelectHighlightFlash);
			Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, tickSelectHighlightFlash);
			applyActivePalettes(true);
			refreshSelectedSwatchTriangles();
		}

		private function cancelSelectHighlightFlash(reapply:Boolean):void
		{
			var wasActive:Boolean = selectHighlightFlashActive;
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, tickSelectHighlightFlash);
			};
			selectHighlightFlashActive = false;
			selectHighlightTargets = null;
			selectHighlightStartTime = 0;
			if (reapply && wasActive)
			{
				applyActivePalettes(true);
				refreshSelectedSwatchTriangles();
			};
		}

		private function tickSelectHighlightFlash(e:Event):void
		{
			if (!selectHighlightFlashActive || draggingSlider)
			{
				cancelSelectHighlightFlash(true);
				return;
			};
			if ((getTimer() - selectHighlightStartTime) >= SELECT_HIGHLIGHT_DURATION_MS)
			{
				cancelSelectHighlightFlash(true);
			};
		}

		private function tickSelectionPulse(e:Event):void
		{
			var elapsed:int;
			var t:Number;
			var up:Number;
			if (!pulseActive || draggingSlider)
			{
				cancelSelectionPulse(true);
				return;
			};
			elapsed = getTimer() - pulseStartTime;
			if (elapsed >= PULSE_DURATION_MS)
			{
				cancelSelectionPulse(true);
				return;
			};
			t = elapsed / PULSE_DURATION_MS;
			if (t < 0.45)
			{
				up = t / 0.45;
				pulseBrightenFactor = 1 + (PULSE_PEAK - 1) * up;
			}
			else
			{
				up = (t - 0.45) / 0.55;
				pulseBrightenFactor = PULSE_PEAK + (1 - PULSE_PEAK) * up;
			};
			refreshSelectedSwatchTriangles();
			applyActivePalettes(true);
		}

		private function openToolSettings():void
		{
			var px:Number;
			var py:Number;
			if (!toolSettingsPopup)
			{
				toolSettingsPopup = new ToolSettingsPopup();
				toolSettingsPopup.onClose = closeToolSettings;
				toolSettingsPopup.onToggleAlwaysIsolate = onToggleAlwaysIsolateSetting;
				toolSettingsPopup.onHideUi = onHidePaletteMakerUi;
				toolSettingsPopup.onToggleHighlightUnchanged = onToggleHighlightUnchangedSetting;
				toolSettingsPopup.onToggleSortByOriginal = onToggleSortByOriginalSetting;
				toolSettingsPopup.onToggleDiscordCostumePreview = onToggleDiscordCostumePreviewSetting;
				toolSettingsPopup.onToggleSelectHighlight = onToggleSelectHighlightSetting;
				toolSettingsPopup.onSelectHighlightPrimaryChanged = onSelectHighlightPrimaryChanged;
				toolSettingsPopup.onSelectHighlightAltChanged = onSelectHighlightAltChanged;
				toolSettingsPopup.onExportColorGroups = onExportColorGroupsSetting;
				toolSettingsPopup.onImportColorGroups = onImportColorGroupsSetting;
				toolSettingsPopup.onOpenShortcuts = openShortcutsPopup;
				toolSettingsPopup.onOpenAchievements = openAchievementsPopup;
				m_subMenu.addChild(toolSettingsPopup);
			};
			px = m_subMenu.colors ? m_subMenu.colors.x - 8 : 420;
			py = 18;
			toolSettingsPopup.showAt(px, py, settingAlwaysIsolate, settingHighlightUnchanged,
				settingSortByOriginalColor, settingUnchangedVsOriginal,
				settingDiscordCostumePreview, PaletteMakerAchievements.getCookies(),
				settingSelectHighlight, settingSelectHighlightPrimary, settingSelectHighlightAlt);
			hideMagnifier();
			if (Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_DOWN, onToolSettingsStageDown, true, 0, true);
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.track("settings_opened");
		}

		private function onToggleSelectHighlightSetting():void
		{
			settingSelectHighlight = !settingSelectHighlight;
			saveToolSettings();
			refreshToolSettingsToggles();
			cancelSelectHighlightFlash(true);
			Ssf2.MultiplayerManager.notify(settingSelectHighlight
				? "Select highlight on — flashes highlight colors on first select"
				: "Select highlight off");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function onSelectHighlightPrimaryChanged(color:uint):void
		{
			settingSelectHighlightPrimary = uint(color) | 0xFF000000;
			saveToolSettings();
			if (isSelectHighlightActive())
			{
				applyActivePalettes(true);
			};
		}

		private function onSelectHighlightAltChanged(color:uint):void
		{
			settingSelectHighlightAlt = uint(color) | 0xFF000000;
			saveToolSettings();
			if (isSelectHighlightActive())
			{
				applyActivePalettes(true);
			};
		}

		private function onToggleAlwaysIsolateSetting():void
		{
			settingAlwaysIsolate = !settingAlwaysIsolate;
			saveToolSettings();
			refreshToolSettingsToggles();
			if (settingAlwaysIsolate && !isolateMode)
			{
				setIsolateMode(true);
			};
			Ssf2.MultiplayerManager.notify(settingAlwaysIsolate ? "Always isolate on" : "Always isolate off");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			if (settingAlwaysIsolate)
			{
				PaletteMakerAchievements.unlock("flavor_always_isolate");
			};
		}

		private function onToggleSortByOriginalSetting():void
		{
			settingSortByOriginalColor = !settingSortByOriginalColor;
			saveToolSettings();
			refreshToolSettingsToggles();
			resortColorSwatchLayout();
			Ssf2.MultiplayerManager.notify(settingSortByOriginalColor
				? "Sort by original on"
				: "Sort by replacement on");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			if (settingSortByOriginalColor)
			{
				PaletteMakerAchievements.unlock("ritual_sort_original");
			};
		}

		private function onHidePaletteMakerUi():void
		{
			closeToolSettings();
			hidePaletteMakerUi();
			PaletteMakerAchievements.unlock("ritual_hide_ui");
		}

		private function onImportColorGroupsSetting():void
		{
			var file:File = new File();
			file.addEventListener(Event.SELECT, function(e:Event):void
			{
				var chosen:File = e.target as File;
				var result:Object;
				var so:SharedObject;
				if (!chosen)
				{
					return;
				};
				result = CostumePackIO.importColorGroupsFromFile(chosen);
				if (!result || !result.ok)
				{
					Ssf2.MultiplayerManager.notify((result && result.error) ? String(result.error) : "Color groups import failed");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					return;
				};
				try
				{
					so = SharedObject.getLocal("ssf2_palette_maker_settings");
					if (!so.data.colorGroups)
					{
						so.data.colorGroups = {};
					};
					so.data.colorGroups = result.colorGroups;
					so.flush();
				}
				catch (flushErr:Error)
				{
					Ssf2.MultiplayerManager.notify("Import parsed but SharedObject failed");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					return;
				};
				clearAutoGroupSquares();
				if (restorePersistedColorGroups())
				{
					layoutGroupRow();
					layoutToolRow();
					refreshColorBoxScroll();
				};
				Ssf2.MultiplayerManager.notify("Imported color groups (" + int(result.characterCount) + " chars)");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				PaletteMakerAchievements.unlock("group_import_json");
			});
			try
			{
				file.browseForOpen("Import color groups", [new FileFilter("Color groups JSON", "*.json")]);
			}
			catch (browseErr:Error)
			{
				Ssf2.MultiplayerManager.notify("Could not open file browser");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		private function hidePaletteMakerUi():void
		{
			uiHidden = true;
			if (m_subMenu)
			{
				m_subMenu.visible = false;
			};
			hideMagnifier();
			ensureHiddenUiButtons();
			updateHiddenUiButtonVisibility();
			syncUniquePaHostVisibility();
			syncPauseEnabledWithUi();
			Ssf2.MultiplayerManager.notify("UI hidden — press Pause again for pause menu");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function showPaletteMakerUi():void
		{
			uiHidden = false;
			if (m_subMenu)
			{
				m_subMenu.visible = true;
			};
			updateHiddenUiButtonVisibility();
			syncUniquePaHostVisibility();
			syncPauseEnabledWithUi();
			pmPauseLetGo = false;
			Ssf2.MultiplayerManager.notify("UI shown");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function updateHiddenUiButtonVisibility():void
		{
			var show:Boolean = uiHidden && !(Ssf2.GameController.stageData && Ssf2.GameController.stageData.Paused);
			var rest:Boolean = m_game && m_game.LevelData && String(m_game.LevelData.stage) == "restarea";
			layoutHiddenUiButtons(rest);
			if (showUiButton)
			{
				showUiButton.visible = show;
			};
			if (changeTodButton)
			{
				changeTodButton.visible = show && rest;
			};
			if (changeMusicButton)
			{
				changeMusicButton.visible = show;
			};
			if (changeStageButton)
			{
				changeStageButton.visible = show;
			};
			if (restAreaButton)
			{
				restAreaButton.visible = show && !rest;
			};
		}

		/** Show UI stays at x 12. Each later button sits 8 pixels after the previous one that is on this stage. */
		private function layoutHiddenUiButtons(rest:Boolean):void
		{
			var x:Number = 12;
			var y:Number = Ssf2.Main.Height - 36;
			if (showUiButton)
			{
				showUiButton.x = x;
				showUiButton.y = y;
				x += 78 + 8;
			};
			if (changeTodButton)
			{
				changeTodButton.x = x;
				changeTodButton.y = y;
				if (rest)
				{
					x += 148 + 8;
				};
			};
			if (changeMusicButton)
			{
				changeMusicButton.x = x;
				changeMusicButton.y = y;
				x += 118 + 8;
			};
			if (changeStageButton)
			{
				changeStageButton.x = x;
				changeStageButton.y = y;
				x += 118 + 8;
			};
			if (restAreaButton)
			{
				restAreaButton.x = x;
				restAreaButton.y = y;
			};
		}

		private function syncPauseOverlayUi():void
		{
			var paused:Boolean;
			var hudMenu:*;
			if (!Ssf2.GameController.stageData)
			{
				return;
			};
			paused = Boolean(Ssf2.GameController.stageData.Paused);
			if (paused)
			{
				try
				{
					hudMenu = Ssf2.GameController.hud;
					if (hudMenu && hudMenu.SubMenu && hudMenu.SubMenu.pause_menu)
					{
						hudMenu.SubMenu.pause_menu.visible = false;
					};
				}
				catch (hudErr:Error)
				{
				};
			};
			if (paused == wasGamePaused)
			{
				return;
			};
			wasGamePaused = paused;
			if (paused)
			{
				hideMagnifier();
				setUiKeysFrozen(false);
				ensurePauseToys();
				if (pauseToys)
				{
					pauseToys.setNames(
						m_subMenu && m_subMenu.slotName ? String(m_subMenu.slotName.text || "") : "",
						getAuthorNameText()
					);
					pauseToys.showToys();
					if (pauseToys.parent)
					{
						pauseToys.parent.setChildIndex(pauseToys, pauseToys.parent.numChildren - 1);
					};
				};
			}
			else
			{
				if (pauseToys)
				{
					pauseToys.hideToys();
				};
				onPauseToggleHideArt(false);
			};
			updateHiddenUiButtonVisibility();
			syncUniquePaHostVisibility();
		}

		private function onPaletteMakerAfterSnapshot():void
		{
			if (m_subMenu)
			{
				m_subMenu.visible = snapshotUiWasVisible && !uiHidden;
			};
			if (pauseToys)
			{
				pauseToys.restoreAfterSnapshot();
			};
			updateHiddenUiButtonVisibility();
			try
			{
				var hudMenu:* = Ssf2.GameController.hud;
				if (hudMenu && Ssf2.GameController.stageData && Ssf2.GameController.stageData.Paused)
				{
					if (hudMenu.SubMenu && hudMenu.SubMenu.camIcon)
					{
						hudMenu.SubMenu.camIcon.visible = true;
					};
				};
			}
			catch (err:Error)
			{
			};
		}

		private function ensureHiddenUiButtons():void
		{
			var tf:TextField;
			if (!showUiButton)
			{
				showUiButton = new Sprite();
				showUiButton.graphics.beginFill(0x1A1A22, 0.95);
				showUiButton.graphics.lineStyle(1, 0x888899, 1);
				showUiButton.graphics.drawRoundRect(0, 0, 78, 24, 6, 6);
				showUiButton.graphics.endFill();
				tf = new TextField();
				tf.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFFFF, true);
				tf.autoSize = TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.mouseEnabled = false;
				tf.text = "Show UI";
				tf.x = 10;
				tf.y = 3;
				showUiButton.addChild(tf);
				showUiButton.buttonMode = true;
				showUiButton.useHandCursor = true;
				showUiButton.x = 12;
				showUiButton.y = Ssf2.Main.Height - 36;
				showUiButton.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
					e.stopPropagation();
					showPaletteMakerUi();
				});
				showUiButton.visible = false;
				m_container.addChild(showUiButton);
			};
			if (!changeTodButton)
			{
				changeTodButton = new Sprite();
				changeTodButton.graphics.beginFill(0x1A1A22, 0.95);
				changeTodButton.graphics.lineStyle(1, 0x888899, 1);
				changeTodButton.graphics.drawRoundRect(0, 0, 148, 24, 6, 6);
				changeTodButton.graphics.endFill();
				tf = new TextField();
				tf.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFFFF, true);
				tf.autoSize = TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.mouseEnabled = false;
				tf.text = "Change time of day";
				tf.x = 8;
				tf.y = 3;
				changeTodButton.addChild(tf);
				changeTodButton.buttonMode = true;
				changeTodButton.useHandCursor = true;
				changeTodButton.x = 98;
				changeTodButton.y = Ssf2.Main.Height - 36;
				changeTodButton.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
					e.stopPropagation();
					cycleRestAreaTimeOfDay();
				});
				changeTodButton.visible = false;
				m_container.addChild(changeTodButton);
			};
			if (!changeMusicButton)
			{
				changeMusicButton = new Sprite();
				changeMusicButton.graphics.beginFill(0x1A1A22, 0.95);
				changeMusicButton.graphics.lineStyle(1, 0x888899, 1);
				changeMusicButton.graphics.drawRoundRect(0, 0, 118, 24, 6, 6);
				changeMusicButton.graphics.endFill();
				tf = new TextField();
				tf.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFFFF, true);
				tf.autoSize = TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.mouseEnabled = false;
				tf.text = "Change music";
				tf.x = 8;
				tf.y = 3;
				changeMusicButton.addChild(tf);
				changeMusicButton.buttonMode = true;
				changeMusicButton.useHandCursor = true;
				changeMusicButton.x = 254;
				changeMusicButton.y = Ssf2.Main.Height - 36;
				changeMusicButton.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
					e.stopPropagation();
					openStudioJukebox();
				});
				changeMusicButton.visible = false;
				m_container.addChild(changeMusicButton);
			};
			if (!changeStageButton)
			{
				changeStageButton = new Sprite();
				changeStageButton.graphics.beginFill(0x1A1A22, 0.95);
				changeStageButton.graphics.lineStyle(1, 0x888899, 1);
				changeStageButton.graphics.drawRoundRect(0, 0, 118, 24, 6, 6);
				changeStageButton.graphics.endFill();
				tf = new TextField();
				tf.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFFFF, true);
				tf.autoSize = TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.mouseEnabled = false;
				tf.text = "Change stage";
				tf.x = 8;
				tf.y = 3;
				changeStageButton.addChild(tf);
				changeStageButton.buttonMode = true;
				changeStageButton.useHandCursor = true;
				changeStageButton.x = 380;
				changeStageButton.y = Ssf2.Main.Height - 36;
				changeStageButton.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
					e.stopPropagation();
					openStudioStagePick();
				});
				changeStageButton.visible = false;
				m_container.addChild(changeStageButton);
			};
			if (!restAreaButton)
			{
				restAreaButton = new Sprite();
				restAreaButton.graphics.beginFill(0x1A1A22, 0.95);
				restAreaButton.graphics.lineStyle(1, 0x888899, 1);
				restAreaButton.graphics.drawRoundRect(0, 0, 128, 24, 6, 6);
				restAreaButton.graphics.endFill();
				tf = new TextField();
				tf.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFFFF, true);
				tf.autoSize = TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.mouseEnabled = false;
				tf.text = "Go to rest area";
				tf.x = 8;
				tf.y = 3;
				restAreaButton.addChild(tf);
				restAreaButton.buttonMode = true;
				restAreaButton.useHandCursor = true;
				restAreaButton.x = 506;
				restAreaButton.y = Ssf2.Main.Height - 36;
				restAreaButton.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
					e.stopPropagation();
					finishStudioStagePick("restarea");
				});
				restAreaButton.visible = false;
				m_container.addChild(restAreaButton);
			};
		}

		private function openStudioStagePick():void
		{
			var menu:*;
			menu = Ssf2.MenuController.stageSelectMenu;
			if (!menu || !m_game)
			{
				Ssf2.MultiplayerManager.notify("Stage select is not available");
				return;
			};
			studioPickingStage = true;
			try
			{
				menu.setCurrentGame(m_game);
			}
			catch (gameErr:Error)
			{
			};
			if (m_subMenu)
			{
				m_subMenu.visible = false;
			};
			if (showUiButton) showUiButton.visible = false;
			if (changeTodButton) changeTodButton.visible = false;
			if (changeMusicButton) changeMusicButton.visible = false;
			if (changeStageButton) changeStageButton.visible = false;
			if (restAreaButton) restAreaButton.visible = false;
			menu.show();
			Ssf2.GameController.isStarted = false;
			attachStagePickBack(menu);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function attachStagePickBack(menu:*):void
		{
			var back:*;
			detachStagePickBack();
			try
			{
				back = menu.SubMenu.bg_top.back_btn;
			}
			catch (backErr:Error)
			{
				back = null;
			};
			if (!back)
			{
				return;
			};
			stagePickBackBtn = back;
			stagePickBack = function(e:MouseEvent):void
			{
				if (!stagePickBackBtn || !stagePickBackBtn.hitTestPoint(e.stageX, e.stageY, true))
				{
					return;
				};
				e.stopImmediatePropagation();
				finishStudioStagePick("");
			};
			Ssf2.Main.Root.stage.addEventListener(MouseEvent.CLICK, stagePickBack, true);
		}

		private function detachStagePickBack():void
		{
			if (stagePickBack)
			{
				Ssf2.Main.Root.stage.removeEventListener(MouseEvent.CLICK, stagePickBack, true);
			};
			stagePickBackBtn = null;
			stagePickBack = null;
		}

		private function finishStudioStagePick(stageId:String):void
		{
			var toLoad:Array;
			var previousStage:String;
			studioPickingStage = false;
			detachStagePickBack();
			try
			{
				if (Ssf2.MenuController.stageSelectMenu)
				{
					Ssf2.MenuController.stageSelectMenu.removeSelf();
				};
			}
			catch (hideErr:Error)
			{
			};
			try
			{
				Ssf2.GameController.isStarted = false;
			}
			catch (startedErr:Error)
			{
			};
			if (!stageId || stageId == "random")
			{
				restoreStudioAfterStagePick();
				return;
			};
			trace("[Palette Maker] studio stage " + stageId);
			try
			{
				Ssf2.GameController.endMatch();
			}
			catch (endErr:Error)
			{
				trace("[Palette Maker] studio stage end " + endErr.message);
			};
			try
			{
				Ssf2.GameController.destroyStageData();
			}
			catch (destroyErr:Error)
			{
				trace("[Palette Maker] studio stage destroy " + destroyErr.message);
			};
			previousStage = (m_game && m_game.LevelData) ? String(m_game.LevelData.stage) : "";
			if (stageId != previousStage)
			{
				settingStudioSong = "";
				try
				{
					Ssf2.ModHost.door("clearStudioSong", [], false);
				}
				catch (clearErr:Error)
				{
				};
			};
			settingStudioStage = stageId;
			saveCharacterStudio(statsName, stageId, settingStudioSong);
			if (m_game && m_game.LevelData)
			{
				m_game.LevelData.stage = stageId;
				m_game.LevelData.musicOverride = settingStudioSong ? settingStudioSong : "";
			};
			if (settingStudioSong)
			{
				try
				{
					Ssf2.ModHost.door("applyStudioSong", [settingStudioSong], false);
				}
				catch (songErr:Error)
				{
				};
			};
			Ssf2.MultiplayerManager.notify("Loading " + stageId + "...");
			toLoad = [stageId];
			if (settingStudioSong)
			{
				toLoad.push(settingStudioSong);
			};
			if (statsName)
			{
				toLoad = toLoad.concat(PaletteMakerUtils.toCharacterResourceIds([statsName]));
			};
			Ssf2.ResourceManager.queueResources(toLoad);
			Ssf2.ResourceManager.load({"oncomplete":startMatch,"flushUnused":false});
		}

		private function restoreStudioAfterStagePick():void
		{
			if (uiHidden)
			{
				updateHiddenUiButtonVisibility();
				return;
			};
			if (m_subMenu)
			{
				m_subMenu.visible = true;
			};
		}

		private function selectedGameCostumeIndex():int
		{
			try
			{
				if (Ssf2.MenuController.costumeSelectorDisplay)
				{
					return int(Ssf2.MenuController.costumeSelectorDisplay.getSelectedCostume());
				};
			}
			catch (indexErr:*)
			{
			};
			return -1;
		}

		private function readPendingSaveName():String
		{
			var slot:*;
			var typed:String;
			typed = "";
			try
			{
				slot = (m_subMenu && m_subMenu.getChildByName) ? m_subMenu.getChildByName("slotName") : null;
				if (slot)
				{
					typed = PaletteMakerUtils.trimString(String(slot.text || ""));
				};
			}
			catch (nameErr:Error)
			{
				typed = "";
			};
			return typed;
		}

		/** Opens the costume palette menu on the partner so the user can pick the paired costume. */
		protected function openPartnerPairing():void
		{
			var partner:String;
			var locker:*;
			Ssf2.gameLog("[Palette Maker] pair menu enter");
			partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (!partner)
			{
				pendingSaveAfterPair = false;
				pendingExportAfterPair = false;
				Ssf2.MultiplayerManager.notify("This character has no paired form");
				return;
			};
			locker = Ssf2.MenuController.costumeSelectorDisplay;
			if (!locker)
			{
				pendingSaveAfterPair = false;
				pendingExportAfterPair = false;
				Ssf2.gameLog("[Palette Maker] pair menu err no locker");
				Ssf2.MultiplayerManager.notify("Palette menu unavailable");
				return;
			};
			pairingPickMode = true;
			pairingOpenedIndex = selectedGameCostumeIndex();
			if (pairingOpenedIndex < 0)
			{
				pairingOpenedIndex = 0;
			};
			PaletteMakerUtils.ensureCostumeFileLoaded(partner);
			locker.returnToLocalListOnVaultExit = false;
			locker.onClickContainer = _onPairingClickContainer;
			locker.onCloseMenu = _onPairingCloseMenu;
			if (PaletteMakerUtils.isLinkedFormPair(statsName))
			{
				locker.pairOnlyFileIndexes = PaletteMakerUtils.openPairFileIndexes(statsName);
				locker.offerPairBaseChoice = pendingSaveAfterPair;
			}
			else
			{
				locker.pairOnlyFileIndexes = null;
				locker.offerPairBaseChoice = false;
			};
			locker.setCharacter(partner, 0, true, true);
			// Caller sets pendingSaveAfterPair / pendingExportAfterPair before openPairList.
			if (!pendingSaveName)
			{
				pendingSaveName = readPendingSaveName();
			};
			freezeKeys(true);
			Ssf2.gameLog("[Palette Maker] pair flag save=" + (pendingSaveAfterPair ? 1 : 0) + " export=" + (pendingExportAfterPair ? 1 : 0) + " name=" + (pendingSaveName ? pendingSaveName.length : 0));
			Ssf2.gameLog("[Palette Maker] pair menu partner=" + partner);
			Ssf2.MultiplayerManager.notify(locker.offerPairBaseChoice ? ("Pick an open " + PaletteMakerUtils.displayNameFor(partner) + " costume, or Base") : (locker.pairOnlyFileIndexes ? ("Pick an open " + PaletteMakerUtils.displayNameFor(partner) + " costume") : ("Pick a " + PaletteMakerUtils.displayNameFor(partner) + " costume")));
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function _onPairingClickContainer():void
		{
			var partner:String;
			var loadedCostume:Object;
			var sourceIndex:int;
			var profile:String;
			var doSave:Boolean;
			partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (!partner)
			{
				endPartnerPairing();
				return;
			};
			if (Ssf2.MenuController.costumeSelectorDisplay.isNoRecolorSelected())
			{
				loadedCostume = getPaletteMakerBaseCostumeData(partner, null);
				sourceIndex = -1;
			}
			else
			{
				loadedCostume = Ssf2.MenuController.costumeSelectorDisplay.getSelectedCostumeData();
				if (loadedCostume && loadedCostume.pairChooseBase == true)
				{
					Ssf2.gameLog("[Palette Maker] pair base choice");
					pendingSaveAfterPair = false;
					pendingExportAfterPair = false;
					saveWithTemporaryBase();
					try
					{
						Ssf2.MenuController.costumeSelectorDisplay.closeAfterPick();
					}
					catch (baseCloseErr:Error)
					{
					};
					endPartnerPairing();
					return;
				};
				loadedCostume = Ssf2.MenuController.costumeSelectorDisplay.getSelectedCostumeData();
				sourceIndex = Ssf2.MenuController.costumeSelectorDisplay.getSelectedCostume();
				if (!loadedCostume)
				{
					try
					{
						loadedCostume = Ssf2.ResourceManager.getCostume(partner, null, sourceIndex);
					}
					catch (pairErr:Error)
					{
						loadedCostume = null;
					};
				};
				if (!loadedCostume && partner == "gigabowser")
				{
					loadedCostume = GigaStockPalettes.costume(LinkedFormPaint.gigaPaletteIndex(sourceIndex));
				};
				if (!loadedCostume)
				{
					loadedCostume = getPaletteMakerBaseCostumeData(partner, null);
				};
			};
			if (!loadedCostume)
			{
				Ssf2.MultiplayerManager.notify("Could not load that costume");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			if (loadedCostume && loadedCostume.hasOwnProperty("_catalogIndex"))
			{
				fillingOpenFileIndex = int(loadedCostume._catalogIndex);
			};
			partnerPaletteData = Ssf2.Utils.cloneObject(loadedCostume);
			partnerPaletteData.paletteSwap = normalizePaletteBlock(partnerPaletteData.paletteSwap);
			partnerPaletteData.paletteSwapPA = normalizePaletteBlock(partnerPaletteData.paletteSwapPA);
			LinkedFormStance.setLiveBlock(partnerPaletteData.paletteSwap);
			partnerPairIndex = sourceIndex;
			profile = partnerPaletteData.profile ? String(partnerPaletteData.profile) : "Paired";
			Ssf2.gameLog("[Palette Maker] pair partner=" + partner + " from=" + sourceIndex + " to=" + pairingOpenedIndex);
			doSave = pendingSaveAfterPair;
			pendingSaveAfterPair = false;
			Ssf2.gameLog("[Palette Maker] pair save do=" + (doSave ? 1 : 0) + " export=" + (pendingExportAfterPair ? 1 : 0) + " name=" + (pendingSaveName ? pendingSaveName.length : 0));
			if (doSave)
			{
				performSaveCostume();
			}
			else if (pendingExportAfterPair)
			{
				pendingExportAfterPair = false;
				performExportCostume();
			}
			else
			{
				Ssf2.MultiplayerManager.notify("Paired " + profile);
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			};
			try
			{
				Ssf2.MenuController.costumeSelectorDisplay.closeAfterPick();
			}
			catch (pairCloseErr:Error)
			{
				Ssf2.gameLog("[Palette Maker] pair close err=" + pairCloseErr.message);
			};
			endPartnerPairing();
		}

		private function _onPairingCloseMenu():void
		{
			Ssf2.gameLog("[Palette Maker] pair flag clear");
			pendingSaveAfterPair = false;
			pendingExportAfterPair = false;
			pendingSaveName = "";
			endPartnerPairing();
			_onCloseMenu();
		}

		private function endPartnerPairing():void
		{
			var locker:*;
			pairingPickMode = false;
			freezeKeys(false);
			try
			{
				locker = Ssf2.MenuController.costumeSelectorDisplay;
				if (locker)
				{
					locker.pairOnlyFileIndexes = null;
					locker.offerPairBaseChoice = false;
					locker.onClickContainer = _onClickContainer;
					locker.onCloseMenu = _onCloseMenu;
				};
			}
			catch (pairEndErr:Error)
			{
			};
		}

		private function refreshUniquePaSprites(forceRescan:Boolean=false):void
		{
			var selected:Array;
			var i:int;
			var disp:DisplayObject;
			var cand:Object;
			var anchor:Point;
			clearUniquePaSprites();
			if (!settingShowUniquePaSprites || !PAContainer || !currentPaletteData || !statsName)
			{
				return;
			};
			if (!player)
			{
				pendingUniquePaRefresh = true;
				return;
			};
			if (forceRescan || !uniquePaCoverCache || uniquePaScanStatsName != PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName)
				|| uniquePaScanMTime != PaletteMakerUtils.getCharacterResourceMTime(PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName)))
			{
				if (recolorEffectsMode)
				{
					if (forceRescan || !effectPaCoverCache
						|| uniquePaScanStatsName != PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName)
						|| uniquePaScanMTime != PaletteMakerUtils.getCharacterResourceMTime(PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName)))
					{
						effectPaCoverCache = loadOrBuildEffectSpriteCover(forceRescan);
					};
					uniquePaCoverCache = effectPaCoverCache;
				}
				else
				{
					uniquePaCoverCache = loadOrBuildUniqueSpriteCover(forceRescan);
				};
				uniquePaScanStatsName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
				uniquePaScanMTime = PaletteMakerUtils.getCharacterResourceMTime(uniquePaScanStatsName);
			}
			else if (recolorEffectsMode && effectPaCoverCache)
			{
				uniquePaCoverCache = effectPaCoverCache;
			};
			// Shared scan SWF (zelda/sheik, bowser/giga) can hold both forms — keep opened form only.
			if (!recolorEffectsMode && uniquePaCoverCache && statsName)
			{
				uniquePaCoverCache = LinkedFormPaint.filterCoverToForm(uniquePaCoverCache, statsName);
				Ssf2.gameLog("[Palette Maker] unique form filter=" + statsName
					+ " n=" + uniquePaCoverCache.length);
			};
			if (!uniquePaCoverCache || uniquePaCoverCache.length == 0)
			{
				return;
			};
			uniquePaHost = new Sprite();
			uniquePaHost.mouseEnabled = true;
			uniquePaHost.mouseChildren = true;
			anchor = getUniqueSpritesTopLeftLocal();
			uniquePaHost.x = anchor.x;
			uniquePaHost.y = anchor.y;
			uniquePaHost.scaleX = 1;
			uniquePaHost.scaleY = 1;
			m_container.addChild(uniquePaHost);
			uniquePaContent = new Sprite();
			uniquePaContent.mouseEnabled = true;
			uniquePaContent.mouseChildren = true;
			uniquePaHost.addChild(uniquePaContent);
			selected = [];
			i = 0;
			while (i < uniquePaCoverCache.length)
			{
				cand = uniquePaCoverCache[i];
				disp = createSpriteFromCoverCandidate(cand);
				if (disp)
				{
					fitUniquePaSprite(disp, cand);
					uniquePaContent.addChild(disp);
					uniquePaSprites.push(disp);
					selected.push(cand);
				};
				i++;
			};
			uniquePaCoverCache = selected;
			layoutAllUniquePaSprites(null);
			// Portrait metrics need later frames — else-if in updateCharacter skips same frame.
			uniquePaRelayoutFrames = 4;
			uniquePaHost.addEventListener(MouseEvent.MOUSE_WHEEL, onUniquePaMouseWheel, false, 0, true);
			syncUniquePaHostVisibility();
			if (!recolorEffectsMode)
			{
				mergeMissingColorsFromUniqueSprites();
				updateUniquePaPalettes();
			}
			else
			{
				// Effect strip only — no paletteSwapFX merge / body swatch pollution.
				wireFxStripClickHandlers();
				applyRecolorEffectsFiltersToStrip();
				
			};
			// Unique host is added last on m_container — keep accessory dropdown above it.
			bringMcNameDropdownToFront();
		}

		/** Scan in-game costumes for unique mcName accessories and build dropdown beside Back. */
		private function setupMcNameDropdown():void
		{
			destroyMcNameDropdown();
			availableMcNames = PaletteDeep.collectMcNamesForCharacter(statsName);
			selectedMcName = null;
			if (!availableMcNames || availableMcNames.length == 0)
			{
				return;
			};
			buildMcNameDropdownUi();
			refreshMcNameDropdownLabel();
			// Stance may not be ready on first frame — only if user already picked an accessory.
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, onMcNameRetryFrame, false, 0, true);
			};
		}

		private function buildMcNameDropdownUi():void
		{
			var backBtn:DisplayObject;
			var hit:Sprite;
			var chevron:TextField;
			var boxW:Number = 72;
			var boxH:Number = 16;
			var g:Point;
			var local:Point;
			if (!m_container || !m_subMenu || !m_subMenu.bg_top)
			{
				return;
			};
			backBtn = m_subMenu.bg_top.back_btn as DisplayObject;
			mcNameDropdown = new Sprite();
			mcNameDropdown.name = "mcNameDropdown";
			mcNameDropdown.graphics.beginFill(0x2a2a2a, 0.95);
			mcNameDropdown.graphics.lineStyle(1, 0x666666, 1);
			mcNameDropdown.graphics.drawRect(0, 0, boxW, boxH);
			mcNameDropdown.graphics.endFill();
			// Parent on m_container (same layer as unique sprites) so the open list can sit above them.
			if (backBtn)
			{
				g = backBtn.localToGlobal(new Point(34, 6));
				local = m_container.globalToLocal(g);
				mcNameDropdown.x = local.x;
				mcNameDropdown.y = local.y;
			}
			else
			{
				mcNameDropdown.x = 28;
				mcNameDropdown.y = 2;
			};
			mcNameDropdownLabel = new TextField();
			mcNameDropdownLabel.defaultTextFormat = new TextFormat("_sans", 9, 0xFFFFFF, false);
			mcNameDropdownLabel.x = 3;
			mcNameDropdownLabel.y = 1;
			mcNameDropdownLabel.width = 52;
			mcNameDropdownLabel.height = 14;
			mcNameDropdownLabel.selectable = false;
			mcNameDropdownLabel.mouseEnabled = false;
			mcNameDropdown.addChild(mcNameDropdownLabel);
			chevron = new TextField();
			chevron.defaultTextFormat = new TextFormat("_sans", 8, 0xCCCCCC, true, null, null, null, null, TextFormatAlign.CENTER);
			chevron.text = "▼";
			chevron.x = 54;
			chevron.y = 1;
			chevron.width = 16;
			chevron.height = 14;
			chevron.selectable = false;
			chevron.mouseEnabled = false;
			mcNameDropdown.addChild(chevron);
			hit = new Sprite();
			hit.graphics.beginFill(0xFFFFFF, 0);
			hit.graphics.drawRect(0, 0, boxW, boxH);
			hit.graphics.endFill();
			hit.buttonMode = true;
			hit.mouseChildren = false;
			hit.addEventListener(MouseEvent.CLICK, onMcNameDropdownToggle, false, 0, true);
			mcNameDropdown.addChild(hit);
			m_container.addChild(mcNameDropdown);
			bringMcNameDropdownToFront();
			mcNameDropdownOpen = false;
		}

		private function onMcNameDropdownToggle(e:MouseEvent):void
		{
			e.stopPropagation();
			if (mcNameDropdownOpen)
			{
				closeMcNameDropdownList();
			}
			else
			{
				openMcNameDropdownList();
			};
		}

		private function openMcNameDropdownList():void
		{
			var options:Array;
			var i:int;
			var opt:String;
			var row:Sprite;
			var tf:TextField;
			var rowH:Number = 16;
			var w:Number = 72;
			closeMcNameDropdownList();
			if (!mcNameDropdown)
			{
				return;
			};
			options = ["Default"].concat(availableMcNames ? availableMcNames : []);
			mcNameDropdownList = new Sprite();
			mcNameDropdownList.graphics.beginFill(0x1e1e1e, 0.98);
			mcNameDropdownList.graphics.lineStyle(1, 0x555555, 1);
			mcNameDropdownList.graphics.drawRect(0, 0, w, options.length * rowH + 2);
			mcNameDropdownList.graphics.endFill();
			mcNameDropdownList.y = 16;
			i = 0;
			while (i < options.length)
			{
				opt = String(options[i]);
				row = new Sprite();
				row.graphics.beginFill(0x2a2a2a, i % 2 == 0 ? 0.9 : 0.75);
				row.graphics.drawRect(1, 1, w - 2, rowH - 1);
				row.graphics.endFill();
				row.y = 1 + i * rowH;
				row.buttonMode = true;
				row.mouseChildren = false;
				row.name = "mcOpt_" + opt;
				tf = new TextField();
				tf.defaultTextFormat = new TextFormat("_sans", 9, 0xFFFFFF, false);
				tf.text = opt;
				tf.x = 4;
				tf.y = 1;
				tf.width = w - 8;
				tf.height = rowH - 2;
				tf.selectable = false;
				tf.mouseEnabled = false;
				row.addChild(tf);
				row.addEventListener(MouseEvent.CLICK, onMcNameOptionClick, false, 0, true);
				mcNameDropdownList.addChild(row);
				i++;
			};
			mcNameDropdown.addChild(mcNameDropdownList);
			mcNameDropdownOpen = true;
			bringMcNameDropdownToFront();
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMcNameStageDown, true, 0, true);
			};
		}

		private function onMcNameOptionClick(e:MouseEvent):void
		{
			var row:Sprite = e.currentTarget as Sprite;
			var name:String;
			e.stopPropagation();
			if (!row || !row.name)
			{
				return;
			};
			name = String(row.name);
			if (name.indexOf("mcOpt_") == 0)
			{
				name = name.substring(6);
			};
			if (name == "Default")
			{
				selectedMcName = null;
			}
			else
			{
				selectedMcName = name;
			};
			applySelectedMcNameToCostumeData(currentPaletteData);
			closeMcNameDropdownList();
			refreshMcNameDropdownLabel();
			syncPlayerCostumeForMcName(selectedMcName);
			if (selectedMcName)
			{
				applyMcNameVisibility(selectedMcName);
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function syncMcNameFromCostume(costume:Object):void
		{
			var name:String;
			if (!availableMcNames || availableMcNames.length == 0)
			{
				return;
			};
			name = null;
			if (costume && costume.mcName)
			{
				name = String(costume.mcName);
				name = name.replace(new RegExp("^\\s+|\\s+$", "g"), "");
				if (availableMcNames.indexOf(name) < 0)
				{
					name = null;
				};
			};
			selectedMcName = name;
			refreshMcNameDropdownLabel();
			applySelectedMcNameToCostumeData(currentPaletteData);
			// Match in-game load: set CostumeID so Ext scripts see getCostumeData().mcName.
			syncPlayerCostumeForMcName(selectedMcName);
			if (selectedMcName)
			{
				applyMcNameVisibility(selectedMcName);
			};
		}

		/**
		 * Expansions show accessories from Ext scripts that read costume index / mcName.
		 * Default studio stays CostumeID -2 (pre-mcName behavior). Selecting an accessory
		 * switches to a stock slot with that mcName, then re-paints the PM palette.
		 */
		private function syncPlayerCostumeForMcName(activeName:String):void
		{
			var lookup:String;
			var idx:int;
			var target:int;
			if (!player)
			{
				return;
			};
			lookup = statsName;
			try
			{
				if (player.CostumeName)
				{
					lookup = player.CostumeName;
				};
			}
			catch (nameErr:Error)
			{
			};
			target = -2;
			if (activeName)
			{
				idx = PaletteDeep.findCostumeIndexByMcName(lookup, activeName);
				if (idx < 0 && lookup != statsName)
				{
					idx = PaletteDeep.findCostumeIndexByMcName(statsName, activeName);
				};
				if (idx >= 0)
				{
					target = idx;
				};
			};
			try
			{
				if (player.CostumeID != target)
				{
					player.setCostumeAPI(target);
					characterPaletteDirty = true;
					palettePADirty = true;
					applyActivePalettes(true);
				};
			}
			catch (costErr:Error)
			{
			};
		}

		/**
		 * Pull opaque colors from selected unique-sprite bitmaps into the swatch
		 * list / palette when they were missing.
		 * Exact ARGB + min 1 pixel (threshold needs full match; sparse pixels count).
		 * If every existing swap replacement is already the same color (e.g. user
		 * painted all swatches red), new keys inherit that replacement immediately.
		 * Enabled match-all groups also absorb the new keys so late-discovered
		 * pupils (Beat eyes) get the same flat swatch.
		 */
		private function mergeMissingColorsFromUniqueSprites():Boolean
		{
			var cand:Object;
			var colors:Array;
			var color:uint;
			var addedColors:Array;
			var exactAdded:Array;
			var repl:uint;
			var uniformRepl:* = null;
			var mc:MovieClip;
			if (!uniquePaCoverCache || !currentPaletteData || !mixedBasePaletteData)
			{
				return false;
			};
			ensurePaletteBlocks(currentPaletteData);
			if (baseCostumeData)
			{
				ensurePaletteBlocks(baseCostumeData);
			};
			if (sessionBaselineData)
			{
				ensurePaletteBlocks(sessionBaselineData);
			};
			uniformRepl = recolorEffectsMode
				? getUniformPaletteReplacement(currentPaletteData.paletteSwapFX)
				: getUniformPaletteReplacement(currentPaletteData.paletteSwap);
			addedColors = [];
			exactAdded = [];
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
				else if (cand.kind == "mc" || cand.kind == "stance" || cand.kind == "anim" || cand.kind == "linkage")
				{
					mc = tryResolveUniqueCoverMovieClip(cand);
					if (mc)
					{
						colors = PaletteColorAnalysis.collectOpaqueColorsInMC(mc, 4, 1, false);
					};
				};
				if (cand.colors is Array)
				{
					if (!colors)
					{
						colors = [];
					};
					for each (color in (cand.colors as Array))
					{
						colors.push(uint(color));
					};
				};
				if (!colors)
				{
					continue;
				};
				for each (color in colors)
				{
					if (recolorEffectsMode)
					{
						if (paletteBlockHasExactColor(currentPaletteData.paletteSwapFX, color))
						{
							continue;
						};
						repl = (uniformRepl != null) ? uint(uniformRepl) : color;
						exactAdded.push(color);
						// FX-only: never push into body swatch row / mixedBase.
						appendExactPair(currentPaletteData.paletteSwapFX, color, repl);
						if (baseCostumeData)
						{
							appendExactPair(baseCostumeData.paletteSwapFX, color, color);
						};
						if (sessionBaselineData)
						{
							appendExactPair(sessionBaselineData.paletteSwapFX, color, repl);
						};
						continue;
					};
					// Unique sprites are recolored with paletteSwap.
					if (paletteBlockHasExactColor(currentPaletteData.paletteSwap, color))
					{
						continue;
					};
					repl = (uniformRepl != null) ? uint(uniformRepl) : color;
					exactAdded.push(color);
					// One swatch per RGB; every exact ARGB still goes into the palette arrays.
					if (!mixedBaseHasColorMatch(color))
					{
						mixedBasePaletteData.push(color);
						addedColors.push(color);
					};
					appendExactPair(currentPaletteData.paletteSwap, color, repl);
					if (baseCostumeData)
					{
						appendExactPair(baseCostumeData.paletteSwap, color, color);
					};
					if (sessionBaselineData)
					{
						appendExactPair(sessionBaselineData.paletteSwap, color, repl);
					};
					// Always mirror into PA so unique-only keys cannot be match-all'd on
					// sprites while the portrait block stays untouched / black.
					appendExactPair(currentPaletteData.paletteSwapPA, color, repl);
					if (baseCostumeData)
					{
						appendExactPair(baseCostumeData.paletteSwapPA, color, color);
					};
					if (sessionBaselineData)
					{
						appendExactPair(sessionBaselineData.paletteSwapPA, color, repl);
					};
				};
			};
			if (exactAdded.length > 0)
			{
				if (recolorEffectsMode)
				{
					// FX-only merge — no body swatches / match-all absorption.
					
					return true;
				};
				if (addedColors.length > 0)
				{
					appendColorBoxes(addedColors);
					rebuildMixedBaseRgbSet();
					if (uniformRepl != null)
					{
						// New swatches should show the already-applied uniform color.
						syncSwatchIndicators(addedColors, uint(uniformRepl));
					};
					resortColorSwatchLayout();
				};
				absorbNewColorsIntoMatchAllGroups(exactAdded);
				invalidateHotPalettes();
				characterPaletteDirty = true;
				palettePADirty = true;
				unchangedHighlightsDirty = true;
				
				return true;
			};
			return false;
		}

		/**
		 * Paint newly discovered exact keys that soft-match (same RGB) an existing
		 * member of an enabled match-all group. Does not add unrelated colors as
		 * members — only alpha/exact siblings of colors already in the group.
		 */
		private function absorbNewColorsIntoMatchAllGroups(colors:Array):void
		{
			var group:PaletteGroupSquare;
			var color:uint;
			var absorbed:Array;
			if (!colors || colors.length == 0 || !groupSquares)
			{
				return;
			};
			for each (group in groupSquares)
			{
				if (!group || group.groupEnabled == false || !group.matchAllMode
					|| !group.hasSwatchColor || !(group.useSwatch || group.matchAllMode))
				{
					continue;
				};
				absorbed = [];
				for each (color in colors)
				{
					// hasMember uses colorsMatch (same RGB) — never addMember for
					// brand-new hues that merely appear on unique sprites.
					if (group.hasMember(uint(color)))
					{
						absorbed.push(uint(color));
					};
				};
				if (absorbed.length > 0)
				{
					applySwatchToGroupMembers(group, absorbed, false);
					
				};
			};
			saveColorGroups();
		}

		/** Add ColorSquares for newly discovered colors without rebuilding the grid. */
		private function appendColorBoxes(colors:Array):void
		{
			var color:uint;
			var box:ColorSquare;
			var i:int;
			var idx:int;
			var space:int;
			var row:int;
			var child:DisplayObject;
			var exists:Boolean;
			var boxes:Array;
			if (!colors || !m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			boxes = getPaletteSwatchBoxes();
			idx = boxes.length;
			for each (color in colors)
			{
				exists = false;
				for each (box in boxes)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(box.colorValue), color))
					{
						exists = true;
						break;
					};
				};
				if (exists)
				{
					continue;
				};
				box = new ColorSquare(color, BOX_SIZE, idx);
				space = idx % BOX_PER_ROW;
				row = Math.floor(idx / BOX_PER_ROW);
				box.x = BOX_POS_X + space * (BOX_SIZE + BOX_OFFSET);
				box.y = BOX_POS_Y + row * (BOX_SIZE + BOX_OFFSET);
				box.updateIndicator(color);
				m_subMenu.colorBoxBG.addChild(box);
				boxes.push(box);
				idx++;
			};
			colorRowCount = (idx > 0) ? (Math.floor((idx - 1) / BOX_PER_ROW) + 1) : 0;
			layoutGroupRow();
			layoutToolRow();
			refreshColorBoxScroll();
		}

		/** Load RE effect strip from disk bitmaps, or discover + rasterize + save. */
		private function loadOrBuildEffectSpriteCover(forceRescan:Boolean):Array
		{
			var mtime:Number;
			var cached:Array;
			var hydrated:Array;
			var selected:Array;
			var scanName:String;
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scanName);
			if (!forceRescan)
			{
				cached = SpriteCacheStore.loadEffectSpriteCacheForUse(statsName, mtime);
				if (cached != null)
				{
					if (cached.length == 0)
					{
						PaletteMakerUtils.cacheDebugLog("effect EMPTY cache stats=" + statsName);
						return [];
					};
					hydrated = SpriteCacheStore.hydrateEffectSpriteCache(statsName, cached);
					if (hydrated && hydrated.length > 0 && !effectCoverMissingKnownBeams(hydrated))
					{
						PaletteMakerUtils.cacheDebugLog("effect USE cache stats=" + statsName
							+ " n=" + hydrated.length);
						return hydrated;
					};
					if (hydrated && effectCoverMissingKnownBeams(hydrated))
					{
						PaletteMakerUtils.cacheDebugLog("effect RESCAN missing beams stats=" + statsName);
					};
				};
			};
			PaletteMakerUtils.cacheDebugLog("RESCAN effect stats=" + statsName + " scanName=" + scanName
				+ " forceRescan=" + forceRescan);
			selected = rasterizeEffectCoverCandidates(buildEffectSpriteCover());
			persistEffectSpriteCache(selected, mtime);
			return selected;
		}

		/**
		 * Studio harvest: while RE is on, append newly seen attach/projectile linkages
		 * into the effect cover + disk cache.
		 */
		private function harvestStudioAttachFxLinkage(linkage:String):void
		{
			var low:String;
			var i:int;
			var cand:Object;
			var bd:BitmapData;
			var mtime:Number;
			var scanName:String;
			if (!recolorEffectsMode || !linkage)
			{
				return;
			};
			low = String(linkage).toLowerCase();
			if (!low || isUnsafeUniqueSpriteLinkage(low) || isSharedHarvestSkip(low))
			{
				return;
			};
			if (isBodyOrPortraitUniqueLinkage(low) || isLocomotionOrHurtUniqueLinkage(low))
			{
				return;
			};
			if (!effectPaCoverCache)
			{
				effectPaCoverCache = [];
			};
			i = 0;
			while (i < effectPaCoverCache.length)
			{
				cand = effectPaCoverCache[i];
				if (cand && cand.linkage && String(cand.linkage).toLowerCase() == low)
				{
					return;
				};
				i++;
			};
			if (effectPaCoverCache.length >= MAX_EFFECT_COVER_SPRITES)
			{
				return;
			};
			bd = rasterizeLibraryLinkageMultiFrame(String(linkage));
			if (!bd)
			{
				bd = makeEffectPlaceholderBitmap(String(linkage));
			};
			if (!bd)
			{
				return;
			};
			cand = {
				"kind": "bitmap",
				"linkage": String(linkage),
				"bitmapData": bd,
				"used": false
			};
			effectPaCoverCache.push(cand);
			uniquePaCoverCache = effectPaCoverCache;
			scanName = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			mtime = PaletteMakerUtils.getCharacterResourceMTime(scanName);
			persistEffectSpriteCache(effectPaCoverCache, mtime);
			
			// Soft refresh strip so the new cell appears without full forceRescan.
			refreshUniquePaSprites(false);
		}



		private function maintainGigaStudioForm():void
		{
			var inRevival:Boolean;
			var inEntrance:Boolean;
			if (statsName != "gigabowser" || !player)
			{
				return;
			};
			try
			{
				inRevival = Boolean(player.inState(CState.REVIVAL));
			}
			catch (revErr:Error)
			{
				inRevival = false;
			};
			try
			{
				inEntrance = Boolean(player.inState(CState.ENTRANCE));
			}
			catch (entErr:Error)
			{
				inEntrance = false;
			};
			if (gigaPrevInRevival && !inRevival)
			{
				gigaStudioFinal = false;
				gigaFinalDelayFrames = 0;
			};
			gigaPrevInRevival = inRevival;
			if (gigaStudioFinal || inRevival || inEntrance)
			{
				return;
			};
			gigaFinalDelayFrames++;
			if (gigaFinalDelayFrames < GIGA_FINAL_DELAY_FRAMES)
			{
				return;
			};
			try
			{
				if (m_game && m_game.PlayerSettings && m_game.PlayerSettings[0])
				{
					m_game.PlayerSettings[0].unlimitedFinal = true;
				};
				player.forceAttack("special");
				gigaStudioFinal = true;
				Ssf2.gameLog("[Palette Maker] giga studio final delay=" + gigaFinalDelayFrames);
			}
			catch (finalErr:Error)
			{
				gigaFinalDelayFrames = 0;
			};
		}
    }
}
