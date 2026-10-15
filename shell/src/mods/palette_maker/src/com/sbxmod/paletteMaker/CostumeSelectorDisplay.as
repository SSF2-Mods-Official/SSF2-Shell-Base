package com.sbxmod.paletteMaker
{
	import flash.events.MouseEvent;
    import flash.events.Event;
    import flash.display.MovieClip;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.display.Sprite;
	import flash.display.Shape;
	import flash.filters.BlurFilter;
	import flash.filters.GlowFilter;
	import flash.filters.DropShadowFilter;
	import flash.utils.getDefinitionByName;
	import flash.utils.getTimer;
	import flash.utils.getQualifiedClassName;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import com.mcleodgaming.ssf2.util.PaletteDeep;

    public class CostumeSelectorDisplay extends CostumeSelectorPacks 
    {

		public var onCloseMenu:Function = null;
		public var onClickContainer:Function = null;
		private var exportVaultLoading:Boolean = false;
		private var exportVaultAugmented:Boolean = false;
		private var savedAllowDelete:Boolean = false;
		private var savedIncludeNoRecolor:Boolean = false;
		private var lastAddedVaultCostumeName:String = null;
		private var lastAddedVaultCostume:Object = null;
		private var buildIndex:int = 0;
		private var batchSize:int = 3;
		private var packBrowserSelectBusy:Boolean = false;
		private var packBrowserMask:MovieClip = null;
		private static const PACK_BROWSER_LAYER_X:Number = 72;
		private static const PACK_BROWSER_MASK_W:Number = 560;
		private static const PACK_BROWSER_STOCK_MAX:int = 18;
		private static const PACK_BROWSER_STOCK_H:Number = 17;
		private static const PACK_BROWSER_STOCK_GAP:Number = 3;
		private static const PACK_BROWSER_STOCK_START_X:Number = 160;

        public function CostumeSelectorDisplay()
        {
            m_subMenu = Ssf2.ResourceManager.getLibraryMC("costumeSubMenu_r2");
            m_container.addChild(m_subMenu);
            m_fillBackground = false;
			scrollTop = new Point(m_subMenu.scrollbarMC.x, m_subMenu.scrollbarMC.y);
			ensureOwnedInfoPlate();
			hideInfoPlate();
			bindToolbarButtons();
        }

		override public function show():void
        {
            super.show();
			if(m_statsName)
			{
				ensureOwnedInfoPlate();
				showWarningMessage(null);
				clearSelectionMode(false);
				PaletteMakerUtils.fadeIn(m_subMenu, 80);
				toggleBlurBackground(true);
			}
			else
			{
				removeSelf();
			};

        }

        override public function makeEvents():void
        {
            super.makeEvents();
			m_subMenu.scrollbarMC.addEventListener(MouseEvent.MOUSE_DOWN, startDragBar);
            m_subMenu.stage.addEventListener(MouseEvent.MOUSE_UP, stopDragBar);
            m_subMenu.addEventListener(MouseEvent.MOUSE_MOVE, moveDragBar);
			m_subMenu.addEventListener(MouseEvent.MOUSE_WHEEL, onCostumeSelectorMouseWheel);
			m_subMenu.close_btn.addEventListener(MouseEvent.CLICK, closeMenu);
			m_subMenu.refresh_btn.addEventListener(MouseEvent.CLICK, refresh_CLICK);
			m_subMenu.delete_btn.addEventListener(MouseEvent.CLICK, deleteMode_CLICK);
			if (m_subMenu.addonline_btn)
			{
				m_subMenu.addonline_btn.addEventListener(MouseEvent.CLICK, addOnline_CLICK);
			};
			wireChromeHintEvents(true);
			wireToolbarEvents(true);
			var padStage:* = (Ssf2.Main && Ssf2.Main.Root && Ssf2.Main.Root.stage) ? Ssf2.Main.Root.stage : (m_subMenu ? m_subMenu.stage : null);
			if (padStage)
			{
				padStage.removeEventListener(Event.ENTER_FRAME, onCostumePadFrame);
				padStage.addEventListener(Event.ENTER_FRAME, onCostumePadFrame);
			};
        }

        override public function killEvents():void
        {
            super.killEvents();
			m_subMenu.scrollbarMC.removeEventListener(MouseEvent.MOUSE_DOWN, startDragBar);
            m_subMenu.removeEventListener(MouseEvent.MOUSE_UP, stopDragBar);
            m_subMenu.removeEventListener(MouseEvent.MOUSE_MOVE, moveDragBar);
			m_subMenu.removeEventListener(MouseEvent.MOUSE_WHEEL, onCostumeSelectorMouseWheel);
			m_subMenu.refresh_btn.removeEventListener(MouseEvent.CLICK, refresh_CLICK);
			m_subMenu.delete_btn.removeEventListener(MouseEvent.CLICK, deleteMode_CLICK);
			if (m_subMenu.addonline_btn)
			{
				m_subMenu.addonline_btn.removeEventListener(MouseEvent.CLICK, addOnline_CLICK);
			};
			wireChromeHintEvents(false);
			wireToolbarEvents(false);
			var padStage:* = (Ssf2.Main && Ssf2.Main.Root && Ssf2.Main.Root.stage) ? Ssf2.Main.Root.stage : (m_subMenu ? m_subMenu.stage : null);
			if (padStage)
			{
				padStage.removeEventListener(Event.ENTER_FRAME, onCostumePadFrame);
			};
			stopReasonBillboard();
			dismissPackMetaOverlay();
			m_subMenu.removeEventListener(Event.ENTER_FRAME, buildStep);
			m_subMenu.removeEventListener(Event.ENTER_FRAME, previewCatchUpStep);
			onCloseMenu = null;
			onClickContainer = null;
			m_cssPick = false;
		}

		public function setCharacter(statsName:String, pid:int, allowDelete:Boolean=false, showNoRecolorSlot:Boolean=false, cssPick:Boolean=false):void
		{
			m_cssPick = cssPick;
			if(PaletteMakerUtils.isCharRegistered(statsName))
			{
				onlineImportMode = false;
				ownedVaultIds = null;
				clearVaultPreviewSource();
				importPendingCostumes = null;
				packPendingEntries = null;
				includeNoRecolorSlot = showNoRecolorSlot;
				m_statsName = statsName;
				m_pid = pid;
				m_allowDelete = allowDelete;
				// Expansions / late-added chars may not be in the boot costume import list.
				PaletteMakerUtils.ensureCostumeFileLoaded(statsName);
				clearSelectionMode(false);
				startCreatingContainers();
				show();
			}
			else
			{
				trace("[Palette Maker]", statsName, "is not registered!");
			};
		}

		public function setOnlineImportCostumes(statsName:String, costumes:Array):void
		{
			if(!PaletteMakerUtils.isCharRegistered(statsName))
			{
				trace("[Palette Maker]", statsName, "is not registered!");
				return;
			};
			savedAllowDelete = m_allowDelete;
			savedIncludeNoRecolor = includeNoRecolorSlot;
			onlineImportMode = true;
			includeNoRecolorSlot = false;
			m_statsName = statsName;
			m_allowDelete = false;
			importPendingCostumes = null;
			packPendingEntries = null;
			allCostumes = costumes || [];
			try
			{
				rebuildOwnedVaultIdCache();
			}
			catch (cacheErr:Error)
			{
				ownedVaultIds = {};
			};
			clearSelectionMode(false);
			if (containerButton && containerButton.length > 0)
			{
				removeAllContainers();
			};
			// Show/fade first, then build — overlapping fadeIn + 127 addChilds was stalling mid-list.
			show();
			startCreatingContainers();
			updateGuideFromMode();
		}
		
		private function startCreatingContainers():void 
		{
			m_subMenu.removeEventListener(Event.ENTER_FRAME, buildStep);
			m_subMenu.removeEventListener(Event.ENTER_FRAME, previewCatchUpStep);
			previewCatchUpIndex = 0;
			if (onlineImportMode)
			{
				clearVaultPreviewSource();
			};
			if (container && container.parent)
			{
				container.parent.removeChild(container);
			};
			clearStockIcon();
			// Keep exportVaultAugmented lists (local + Color Vault merges); do not reload from disk.
			if (!onlineImportMode && !exportVaultAugmented)
			{
				if (packPendingEntries && packPendingEntries.length > 0)
				{
					allCostumes = flattenPackPendingCostumes();
				}
				else if (importPendingCostumes)
				{
					allCostumes = importPendingCostumes.concat();
				}
				else if (shouldFilterProtectedCostumes())
				{
					allCostumes = buildFavoriteCustomList();
				}
				else
				{
					allCostumes = buildBrowseCostumeList();
				};
			};
			selectedCostume = 0;
			container = new MovieClip();
			container.x = 48;
			container.y = 37;
			containerButton = new Array();
			m_subMenu.addChild(container);
			container.mask = m_subMenu.masker;
			updateNameplate();
			refreshToolbarVisibility();
			buildIndex = 0;
			// Vault shells are cheap (no PA) — blaze through; local keeps small batches.
			batchSize = onlineImportMode ? 40 : 3;
			m_subMenu.addEventListener(Event.ENTER_FRAME, buildStep);
		}
		
		private function buildStep(e:Event):void
		{
			var steps:int = batchSize;
			var i:int;
			var idx:int;
			for (i = 0; i < steps && buildIndex < allCostumes.length; i++)
			{
				idx = buildIndex;
				try
				{
					createCostumeButton(idx);
				}
				catch (err:Error)
				{
					trace("[CostumeSelector] Failed button", idx, err);
				};
				buildIndex++;
			};
			if (buildIndex >= allCostumes.length)
			{
				m_subMenu.removeEventListener(Event.ENTER_FRAME, buildStep);
				try
				{
					refreshTileAlphas();
					avoidTakenSelection();
					updateMoveToEndPosition();
				}
				catch (finErr:Error)
				{
				};
				if (onlineImportMode)
				{
					previewCatchUpIndex = 0;
					m_subMenu.addEventListener(Event.ENTER_FRAME, previewCatchUpStep);
				};
			};
		}

		private function createCostumeButton(i:int):void
		{
			var btn:*;
			var costume:Object = allCostumes[i];
			var bestBackgroundColor:uint;
			var costumeName:String;
			var shell:MovieClip;
			if (!costume)
			{
				costume = {};
				allCostumes[i] = costume;
			};
			try
			{
				shell = Ssf2.ResourceManager.getLibraryMC("costume_selector_fla.container") as MovieClip;
				if (!shell)
				{
					return;
				};
				btn = new (Ssf2.EventButton as Class)(shell);
				if (!btn || !btn.ButtonInstance)
				{
					return;
				};
				costumeName = (costume && costume.hasOwnProperty("profile")) ? String(costume.profile) : PaletteMakerUtils.DEFAULT_COSTUME_NAME;
				if (costumeName.length > 28)
				{
					costumeName = costumeName.substring(0, 28);
				};
				bestBackgroundColor = costumeTileColor(costume);
				containerButton.push(btn);
				container.addChild(btn.ButtonInstance);
				btn.ButtonInstance.alpha = getTargetTileAlpha(i, costume);
				btn.ButtonInstance.x = (i % 7) * 82;
				btn.ButtonInstance.y = int(i / 7) * 111.7;
				btn.ButtonInstance.addEventListener(MouseEvent.MOUSE_OVER, containerButton_OVER);
				btn.ButtonInstance.addEventListener(MouseEvent.MOUSE_OUT, containerButton_OUT);
				btn.ButtonInstance.addEventListener(MouseEvent.CLICK, containerButton_CLICK);
				if (onlineImportMode)
				{
					fillVaultCostumeTile(btn, costume, costumeName, bestBackgroundColor);
					return;
				};
				fillCostumeTileArt(btn, costume, i);
				fillCostumeTileLabels(btn, costume, costumeName);
				tintCostumeTile(btn, bestBackgroundColor);
			}
			catch (err:Error)
			{
				throw err;
			};
		}

		public function closeFromPad():void
		{
			closeMenu(null);
		}

		private function onCostumePadFrame(e:Event):void
		{
			if (!m_hasEvents || !isOnscreen())
			{
				return;
			};
			pollPad(
				function():void { padMove(0, -1); },
				function():void { padMove(0, 1); },
				function():void { padMove(-1, 0); },
				function():void { padMove(1, 0); },
				function():void { padConfirm(); },
				function():void { closeFromPad(); }
			);
		}

		public function padConfirm():void
		{
			var buttons:Array;
			var btn:MovieClip;
			if (m_padToolbar)
			{
				buttons = visibleToolbarButtons();
				if (buttons && m_padToolbarIndex >= 0 && m_padToolbarIndex < buttons.length)
				{
					btn = buttons[m_padToolbarIndex] as MovieClip;
					if (btn)
					{
						btn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
					};
				};
				return;
			};
			if (selectionMode == MODE_PACK_BROWSER || selectionMode == MODE_PACK_DELETE)
			{
				if (packBrowserRows && m_packPadIndex >= 0 && m_packPadIndex < packBrowserRows.length)
				{
					btn = packBrowserRows[m_packPadIndex] as MovieClip;
					if (btn)
					{
						btn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
					};
				};
				return;
			};
			if (!containerButton || selectedCostume < 0 || selectedCostume >= containerButton.length)
			{
				return;
			};
			confirmCostume(selectedCostume, false);
		}

		private function containerButton_CLICK(e:MouseEvent = null):void
		{
			var clickedIndex:int = e ? findEvent(e.currentTarget as MovieClip) : selectedCostume;
			var shift:Boolean = e ? e.shiftKey : false;
			if(clickedIndex < 0)
			{
				return;
			};
			confirmCostume(clickedIndex, shift);
		}

		private function confirmCostume(clickedIndex:int, shift:Boolean):void
		{
			var takenClick:Boolean = isCssCostumeTaken(clickedIndex);
			PaletteDeep.note("[palette_maker] costume confirm idx=" + clickedIndex + " pid=" + m_pid + " mode=" + selectionMode + " online=" + (onlineImportMode ? 1 : 0) + " click=" + (onClickContainer != null ? 1 : 0) + " css=" + (m_cssPick ? 1 : 0) + " taken=" + (takenClick ? 1 : 0));
			if (takenClick)
			{
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			selectedCostume = clickedIndex;
			if(onlineImportMode)
			{
				ensureVaultTilePreview(clickedIndex);
				handleVaultClick(clickedIndex, shift);
				return;
			};
			if(selectionMode == MODE_DELETE || selectionMode == MODE_EXPORT || selectionMode == MODE_IMPORT
				|| selectionMode == MODE_PACK_EXPORT || selectionMode == MODE_PACK_IMPORT)
			{
				handleMultiSelectClick(clickedIndex, shift);
				return;
			};
			if(selectionMode == MODE_SORT)
			{
				handleSortClick(clickedIndex, shift);
				return;
			};
			if (m_cssPick)
			{
				applyCssCostumePick();
				closeAfterPick();
				return;
			};
			try
			{
				if(onClickContainer != null)
				{
					onClickContainer();
				};
			}
			catch(pickErr:Error)
			{
			};
			closeAfterPick();
		}

		/** CSS grid confirm. Replay the select slide on the menu that still has a match. */
		private function applyCssCostumePick():void
		{
			var menu:*;
			var settings:*;
			var costumeID:int;
			var ModHost:*;
			var ModHooks:*;
			var current:*;
			costumeID = getSelectedCostume();
			current = Ssf2.MenuController.CurrentCharacterSelectMenu;
			menu = cssMenuForPick(current);
			PaletteDeep.note("[palette_maker] costume apply game=" + costumeID + " pid=" + m_pid + " menu=" + (menu ? 1 : 0) + " live=" + ((menu && menu == s_liveMenu && menu != current) ? 1 : 0));
			var gameOk:int = 0;
			var settingsOk:int = 0;
			var len:int = -1;
			var hasPic:int = 0;
			try
			{
				gameOk = (menu && menu.GameObj) ? 1 : 0;
				settingsOk = (gameOk && menu.GameObj.PlayerSettings) ? 1 : 0;
				if (settingsOk)
				{
					len = int(menu.GameObj.PlayerSettings.length);
				};
				hasPic = (menu && menu.changePic != null) ? 1 : 0;
			}
			catch (gateErr:*)
			{
				PaletteDeep.note("[palette_maker] costume gate fail " + gateErr);
				return;
			};
			PaletteDeep.note("[palette_maker] costume gate game=" + gameOk + " settings=" + settingsOk + " len=" + len + " pid=" + m_pid + " pic=" + hasPic);
			if (!gameOk || !settingsOk)
			{
				return;
			};
			if (m_pid < 0 || m_pid >= len)
			{
				return;
			};
			settings = menu.GameObj.PlayerSettings[m_pid];
			if (!settings)
			{
				PaletteDeep.note("[palette_maker] costume gate row=0");
				return;
			};
			settings.costume = costumeID;
			PaletteDeep.note("[palette_maker] costume replay enter char=" + settings.character + " exp=" + settings.expansion + " costume=" + costumeID);
			try
			{
				menu.changePic((m_pid + 1), String(settings.character || ""), Number(settings.expansion));
				PaletteDeep.note("[palette_maker] costume replay port=" + (m_pid + 1) + " costume=" + costumeID);
			}
			catch (picErr:*)
			{
				PaletteDeep.note("[palette_maker] costume replay fail " + picErr);
			};
			ModHost = Ssf2.ModHost;
			ModHooks = Ssf2.ModHooks;
			if (ModHost && ModHooks)
			{
				ModHost.runHook(ModHooks.CSS_CHANGE_COSTUME_INDEX, {
					"port":(m_pid + 1),
					"costume":costumeID,
					"menu":menu
				});
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		public static function noteCssMenu(menu:*):void
		{
			if (menu)
			{
				s_liveMenu = menu;
			};
		}

		private function handleVaultClick(index:int, shift:Boolean):void
		{
			var from:int;
			var to:int;
			var i:int;
			if (shift && lastAnchorIndex >= 0)
			{
				from = Math.min(lastAnchorIndex, index);
				to = Math.max(lastAnchorIndex, index);
				i = from;
				while (i <= to)
				{
					toggleOnlineImportCostume(i, false);
					i++;
				};
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			}
			else
			{
				toggleOnlineImportCostume(index, true);
				lastAnchorIndex = index;
			};
		}

		private function handleSortClick(index:int, shift:Boolean):void
		{
			if (!isCustomCostumeIndex(index))
			{
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			if (selectedIndices.length > 0 && !shift && selectedIndices.indexOf(index) == -1)
			{
				moveSelectedBeforeIndex(index);
				return;
			};
			if (shift && lastAnchorIndex >= 0)
			{
				selectIndexRange(lastAnchorIndex, index, true);
			}
			else
			{
				toggleIndexSelection(index);
				lastAnchorIndex = index;
			};
			refreshTileAlphas();
			refreshModeChrome();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		/** Select every index currently eligible for the active mode. */
		private function selectAllEligible():void
		{
			var i:int;
			var meta:Object;
			selectedIndices = [];
			if (selectionMode == MODE_PACK_DELETE)
			{
				i = 0;
				while (packBrowserList && i < packBrowserList.length)
				{
					meta = packBrowserList[i];
					if (meta && meta.source == "local" && meta.filePath)
					{
						selectedIndices.push(i);
					};
					i++;
				};
				refreshPackDeleteRowAlphas();
				refreshModeChrome();
				updateGuideFromMode();
				lastAnchorIndex = selectedIndices.length > 0 ? int(selectedIndices[selectedIndices.length - 1]) : -1;
				return;
			};
			if (!allCostumes)
			{
				refreshTileAlphas();
				refreshModeChrome();
				return;
			};
			i = 0;
			while (i < allCostumes.length)
			{
				if (isIndexSelectable(i))
				{
					selectedIndices.push(i);
				};
				i++;
			};
			refreshTileAlphas();
			refreshModeChrome();
			updateGuideFromMode();
			lastAnchorIndex = selectedIndices.length > 0 ? int(selectedIndices[selectedIndices.length - 1]) : -1;
		}

		private function deselectAllEligible():void
		{
			selectedIndices = [];
			lastAnchorIndex = -1;
			if (selectionMode == MODE_PACK_DELETE)
			{
				refreshPackDeleteRowAlphas();
			}
			else
			{
				refreshTileAlphas();
			};
			refreshModeChrome();
			updateGuideFromMode();
		}

		private function clearSelectionMode(playSound:Boolean):void
		{
			var wasFiltering:Boolean = shouldFilterProtectedCostumes();
			selectionMode = MODE_NONE;
			selectedIndices = [];
			lastAnchorIndex = -1;
			exportVaultAugmented = false;
			exportVaultLoading = false;
			chainImportAfterPackSave = false;
			try
			{
				if (m_subMenu && m_subMenu.delete_btn && m_subMenu.delete_btn.activated)
				{
					MovieClip(m_subMenu.delete_btn.activated).visible = false;
				};
			}
			catch (err:Error)
			{
			};
			if (wasFiltering && !onlineImportMode && !importPendingCostumes)
			{
				rebuildCostumeGrid();
			}
			else
			{
				refreshTileAlphas();
			};
			refreshToolbarVisibility();
			updateGuideFromMode();
			if (playSound)
			{
				Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
			};
		}

		private function enterSelectionMode(mode:String):void
		{
			var wasFiltering:Boolean = shouldFilterProtectedCostumes();
			selectionMode = mode;
			selectedIndices = [];
			lastAnchorIndex = -1;
			exportVaultAugmented = false;
			exportVaultLoading = false;
			if (wasFiltering != shouldFilterProtectedCostumes() && !onlineImportMode && !importPendingCostumes)
			{
				rebuildCostumeGrid();
			}
			else
			{
				refreshTileAlphas();
			};
			refreshToolbarVisibility();
			updateGuideFromMode();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		/** Hide default / no-recolor / team / base slots in delete, sort, and export. */
		private function shouldFilterProtectedCostumes():Boolean
		{
			return selectionMode == MODE_DELETE || selectionMode == MODE_SORT || selectionMode == MODE_EXPORT;
		}

		private function rebuildCostumeGrid():void
		{
			clearStockIcon();
			if (containerButton)
			{
				removeAllContainers();
			};
			startCreatingContainers();
		}

		private function getSelectedCostumeObjects():Array
		{
			var out:Array = [];
			var idx:int;
			for each (idx in selectedIndices)
			{
				if (idx >= 0 && allCostumes && idx < allCostumes.length && allCostumes[idx])
				{
					out.push(allCostumes[idx]);
				};
			};
			return out;
		}

		private function toggleOnlineImportCostume(index:int, notify:Boolean=true):void
		{
			var costume:Object;
			var costumeName:String;
			var btn:*;
			var owned:Boolean;
			var catIndex:int;
			if (index < 0 || index >= allCostumes.length)
			{
				return;
			};
			costume = allCostumes[index];
			costumeName = (costume && costume.hasOwnProperty("profile")) ? String(costume.profile) : "";
			if (!costume || PaletteMakerUtils.isSystemCostumeSlot(costume))
			{
				return;
			};
			catIndex = catalogIndexOfTile(costume);
			if (catIndex < 0)
			{
				return;
			};
			btn = containerButton[index];
			owned = isVaultCostumeOwned(costume);
			if (owned)
			{
				PaletteMakerUtils.removeFavoriteIndex(m_statsName, catIndex);
				setVaultCostumeOwned(costume, false);
				if (btn)
				{
					btn.ButtonInstance.alpha = ALPHA_DIM;
				};
				if (notify)
				{
					Ssf2.MultiplayerManager.notify(costumeName + " removed");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
				};
			}
			else
			{
				PaletteMakerUtils.addFavoriteIndex(m_statsName, catIndex);
				setVaultCostumeOwned(costume, true);
				if (btn)
				{
					btn.ButtonInstance.alpha = ALPHA_FULL;
				};
				lastAddedVaultCostumeName = costumeName;
				lastAddedVaultCostume = costume;
				if (returnToLocalListOnVaultExit)
				{
					applyImportedCostumeToCaller(costumeName, costume);
				};
				if (notify)
				{
					Ssf2.MultiplayerManager.notify(costumeName + " added");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				};
			};
		}

		/** Apply a local costume by profile name / vault ID through onClickContainer (CSS / locker preview). */
		private function applyImportedCostumeToCaller(costumeName:String, vaultCostume:Object=null):void
		{
			var catalog:Array;
			var raw:Array;
			var catIndex:int;
			var rawIndex:int;
			var slot:int;
			var i:int;
			var hasBase:Boolean;
			var prevAll:Array;
			var prevSelected:int;
			var prevInclude:Boolean;
			if (onClickContainer == null)
			{
				return;
			};
			catIndex = catalogIndexOfTile(vaultCostume);
			catalog = PaletteMakerUtils.getCostume(m_statsName);
			if (catIndex < 0 || !catalog || catIndex >= catalog.length)
			{
				return;
			};
			raw = Ssf2.ResourceManager.getAllCostumes(m_statsName, null, true);
			rawIndex = -1;
			hasBase = false;
			i = 0;
			while (raw && i < raw.length)
			{
				if (raw[i] && raw[i].base && !raw[i].team)
				{
					hasBase = true;
				};
				if (raw[i] == catalog[catIndex])
				{
					rawIndex = i;
					break;
				};
				i++;
			};
			if (rawIndex < 0)
			{
				return;
			};
			if (savedIncludeNoRecolor && !hasBase)
			{
				slot = rawIndex;
			}
			else
			{
				slot = rawIndex - 1;
			};
			prevAll = allCostumes;
			prevSelected = selectedCostume;
			prevInclude = includeNoRecolorSlot;
			allCostumes = [{ "_gameCostumeIndex": slot }];
			selectedCostume = 0;
			onClickContainer();
			allCostumes = prevAll;
			selectedCostume = prevSelected;
			includeNoRecolorSlot = prevInclude;
		}

		private function exitOnlineImportToLocalList():void
		{
			var keepClose:Function = onCloseMenu;
			var keepClick:Function = onClickContainer;
			var preferName:String = lastAddedVaultCostumeName;
			onlineImportMode = false;
			ownedVaultIds = null;
			clearVaultPreviewSource();
			restoreScrollbarPos();
			clearSelectionMode(false);
			clearStockIcon();
			if (containerButton && containerButton.length > 0)
			{
				removeAllContainers();
			};
			setCharacter(m_statsName, m_pid, savedAllowDelete, savedIncludeNoRecolor, m_cssPick);
			onCloseMenu = keepClose;
			onClickContainer = keepClick;
			if (preferName)
			{
				selectLocalCostumeByProfile(preferName);
				if (returnToLocalListOnVaultExit)
				{
					applyImportedCostumeToCaller(preferName, lastAddedVaultCostume);
				};
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
		}

		private function selectLocalCostumeByProfile(costumeName:String):void
		{
			var i:int;
			if (!costumeName || !allCostumes)
			{
				return;
			};
			i = 0;
			while (i < allCostumes.length)
			{
				if (allCostumes[i] && String(allCostumes[i].profile) == costumeName)
				{
					selectedCostume = i;
					updateNameplate();
					return;
				};
				i++;
			};
		}

		private function addOnline_CLICK(e:MouseEvent):void
		{
			var charName:String = m_statsName;
			if (exportVaultLoading)
			{
				return;
			};
			if (selectionMode == MODE_EXPORT || selectionMode == MODE_PACK_EXPORT)
			{
				beginExportVaultFetch();
				return;
			};
			if (!charName)
			{
				return;
			};
			Ssf2.MultiplayerManager.notify("Loading Color Vault costumes...");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			ColorVaultSync.fetchColorVaultCostumesFresh(charName,
			{
				"onComplete": function(costumes:Array):void
				{
					var keepClose:Function = onCloseMenu;
					try
					{
						setOnlineImportCostumes(charName, costumes);
						onCloseMenu = keepClose;
					}
					catch (err:Error)
					{
						Ssf2.MultiplayerManager.notify("Color Vault open failed");
						Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					};
				},
				"onError": function():void
				{
					Ssf2.MultiplayerManager.notify("No Color Vault file for " + charName);
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				},
				"onParseError": function():void
				{
					Ssf2.MultiplayerManager.notify("Color Vault file parse error for " + charName);
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				}
			});
		}

		/** During export modes: merge Color Vault costumes into the selectable list (char-specific for costume export). */
		private function beginExportVaultFetch():void
		{
			var charFilter:String;
			if (exportVaultLoading)
			{
				return;
			};
			exportVaultLoading = true;
			charFilter = (selectionMode == MODE_EXPORT) ? m_statsName : null;
			Ssf2.MultiplayerManager.notify(charFilter
				? ("Loading Color Vault for " + charFilter + "…")
				: "Loading Color Vault for all characters…");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			ColorVaultSync.fetchColorVaultCostumesForExport(charFilter, {
				"onProgress": function(done:int, total:int):void
				{
					if (total > 1 && (done == total || done % 5 == 0))
					{
						Ssf2.MultiplayerManager.notify("Color Vault " + done + "/" + total + " characters…");
					};
				},
				"onComplete": function(costumes:Array):void
				{
					exportVaultLoading = false;
					try
					{
						mergeVaultCostumesIntoExportList(costumes);
					}
					catch (err:Error)
					{
						Ssf2.MultiplayerManager.notify("Color Vault merge failed");
						Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					};
				},
				"onError": function():void
				{
					exportVaultLoading = false;
					Ssf2.MultiplayerManager.notify("Color Vault load failed");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				}
			});
		}

		private function mergeVaultCostumesIntoExportList(vaultList:Array):void
		{
			var costume:Object;
			var clone:Object;
			var vaultId:int;
			var existingIds:Object;
			var existing:Object;
			var added:int;
			var i:int;
			if (!allCostumes)
			{
				allCostumes = [];
			};
			existingIds = {};
			i = 0;
			while (i < allCostumes.length)
			{
				existing = allCostumes[i];
				vaultId = PaletteMakerUtils.getColorVaultIdFromCostume(existing);
				if (vaultId >= 0)
				{
					existingIds[String(vaultId) + "|" + (existing && existing._packStatsName ? existing._packStatsName : m_statsName)] = true;
				};
				i++;
			};
			added = 0;
			for each (costume in (vaultList || []))
			{
				if (!costume)
				{
					continue;
				};
				vaultId = PaletteMakerUtils.getColorVaultIdFromCostume(costume);
				clone = Ssf2.Utils.cloneObject(costume);
				if (costume._packStatsName)
				{
					clone._packStatsName = costume._packStatsName;
				}
				else if (selectionMode == MODE_EXPORT)
				{
					clone._packStatsName = m_statsName;
				};
				if (vaultId >= 0 && existingIds[String(vaultId) + "|" + (clone._packStatsName || m_statsName)])
				{
					continue;
				};
				allCostumes.push(clone);
				if (vaultId >= 0)
				{
					existingIds[String(vaultId) + "|" + (clone._packStatsName || m_statsName)] = true;
				};
				added++;
			};
			exportVaultAugmented = true;
			if (containerButton && containerButton.length > 0)
			{
				removeAllContainers();
			};
			batchSize = 24;
			startCreatingContainers();
			refreshToolbarVisibility();
			updateGuideFromMode();
			Ssf2.MultiplayerManager.notify(added > 0
				? ("Added " + added + " Color Vault costume(s) to export list")
				: "No new Color Vault costumes to add");
			Ssf2.SoundQueue.instance.playSoundEffect(added > 0 ? "menu_select" : "menu_back");
		}
		
		private function refresh_CLICK(e:MouseEvent):void
		{
			if (onlineImportMode || importPendingCostumes)
			{
				return;
			};
			clearSelectionMode(false);
			PaletteMakerUtils.loadCostumeFile(m_statsName,
			{
				"onComplete":onCompleteAfterRefresh, 
				"onError":errorAfterRefresh, 
				"onParseError":parseErrAfterRefresh
			});
		}
		
		private function deleteMode_CLICK(e:MouseEvent):void
		{
			var customs:Array;
			var localCount:int;
			var meta:Object;
			var i:int;
			if(onlineImportMode)
			{
				return;
			};
			if (selectionMode == MODE_PACK_DELETE)
			{
				if (selectedIndices.length > 0)
				{
					Ssf2.MenuController.onlinePromptMenu.message = "Delete " + selectedIndices.length + " local pack(s)?\nThis cannot be undone.";
					Ssf2.MenuController.onlinePromptMenu.onAccept = executeDeleteSelectedPacks;
					Ssf2.MenuController.onlinePromptMenu.onDismiss = cancelPackDeletePrompt;
					Ssf2.MenuController.onlinePromptMenu.show();
					return;
				};
				exitPackDeleteMode(true);
				return;
			};
			if (selectionMode == MODE_PACK_BROWSER)
			{
				localCount = 0;
				i = 0;
				while (packBrowserList && i < packBrowserList.length)
				{
					meta = packBrowserList[i];
					if (meta && meta.source == "local" && meta.filePath)
					{
						localCount++;
					};
					i++;
				};
				if (localCount <= 0)
				{
					Ssf2.MultiplayerManager.notify("No local packs to discard");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					return;
				};
				selectionMode = MODE_PACK_DELETE;
				selectedIndices = [];
				lastAnchorIndex = -1;
				refreshPackDeleteRowAlphas();
				refreshToolbarVisibility();
				updateNameplate();
				updateGuideFromMode();
				try
				{
					MovieClip(m_subMenu.delete_btn.activated).visible = true;
				}
				catch (actErr:Error)
				{
				};
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				return;
			};
			if (!m_allowDelete)
			{
				return;
			};
			if(selectionMode == MODE_DELETE)
			{
				if(selectedIndices.length > 0)
				{
					Ssf2.MenuController.onlinePromptMenu.message = "You will delete " + selectedIndices.length + " costume(s)... \n Are you sure?";
					Ssf2.MenuController.onlinePromptMenu.onAccept = executeDeleteSelected;
					Ssf2.MenuController.onlinePromptMenu.onDismiss = cancelDeletePrompt;
					Ssf2.MenuController.onlinePromptMenu.show();
					return;
				};
				clearSelectionMode(true);
				return;
			};
			if (selectionMode != MODE_NONE && selectionMode != MODE_DELETE)
			{
				clearSelectionMode(false);
			};
			customs = PaletteMakerUtils.getCostume(m_statsName);
			if (!customs || customs.length == 0)
			{
				Ssf2.MultiplayerManager.notify("No custom costumes to discard");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			enterSelectionMode(MODE_DELETE);
			try
			{
				MovieClip(m_subMenu.delete_btn.activated).visible = true;
			}
			catch (err:Error)
			{
			};
		}

		private function executeDeleteSelected():void
		{
			var objs:Array = getSelectedCostumeObjects();
			CostumePackIO.deleteCostumeObjects(m_statsName, objs);
			clearSelectionMode(false);
			Ssf2.MenuController.onlinePromptMenu.removeSelf();
			refresh_CLICK(null);
			Ssf2.MultiplayerManager.notify("Deleted " + objs.length + " costume(s)");
		}

		private function cancelDeletePrompt():void
		{
			Ssf2.MenuController.onlinePromptMenu.removeSelf();
			clearSelectionMode(true);
		}

		private function executeDeleteSelectedPacks():void
		{
			var idx:int;
			var meta:Object;
			var deleted:int = 0;
			var path:String;
			Ssf2.MenuController.onlinePromptMenu.removeSelf();
			for each (idx in selectedIndices)
			{
				if (!packBrowserList || idx < 0 || idx >= packBrowserList.length)
				{
					continue;
				};
				meta = packBrowserList[idx];
				if (!meta || meta.source != "local" || !meta.filePath)
				{
					continue;
				};
				path = String(meta.filePath);
				if (CostumePackIO.deleteLocalCostumePack(path))
				{
					deleted++;
				};
			};
			selectedIndices = [];
			lastAnchorIndex = -1;
			try
			{
				MovieClip(m_subMenu.delete_btn.activated).visible = false;
			}
			catch (actErr:Error)
			{
			};
			packBrowserList = CostumePackIO.listLocalCostumePacks(packBrowserCharFilter);
			selectionMode = MODE_PACK_BROWSER;
			buildPackBrowserRows();
			updateNameplate();
			refreshToolbarVisibility();
			updateGuideFromMode();
			packBrowserLoadingOnline = true;
			CostumePackIO.fetchOnlineCostumePackList(onPackBrowserOnlineReady, onPackBrowserOnlineError);
			if (deleted > 0)
			{
				Ssf2.MultiplayerManager.notify("Deleted " + deleted + " local pack(s)");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			}
			else
			{
				Ssf2.MultiplayerManager.notify("No packs deleted");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		private function cancelPackDeletePrompt():void
		{
			Ssf2.MenuController.onlinePromptMenu.removeSelf();
			exitPackDeleteMode(true);
		}

		private function exitPackDeleteMode(playSound:Boolean):void
		{
			selectedIndices = [];
			lastAnchorIndex = -1;
			selectionMode = MODE_PACK_BROWSER;
			try
			{
				MovieClip(m_subMenu.delete_btn.activated).visible = false;
			}
			catch (actErr:Error)
			{
			};
			refreshPackDeleteRowAlphas();
			refreshToolbarVisibility();
			updateNameplate();
			updateGuideFromMode();
			if (playSound)
			{
				Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
			};
		}

		private function refreshPackDeleteRowAlphas():void
		{
			var i:int;
			var row:MovieClip;
			var meta:Object;
			var selected:Boolean;
			var local:Boolean;
			if (!packBrowserRows)
			{
				return;
			};
			i = 0;
			while (i < packBrowserRows.length)
			{
				row = packBrowserRows[i] as MovieClip;
				meta = (packBrowserList && i < packBrowserList.length) ? packBrowserList[i] : null;
				local = meta && meta.source == "local" && meta.filePath;
				selected = selectedIndices.indexOf(i) >= 0;
				if (row)
				{
					if (selectionMode == MODE_PACK_DELETE)
					{
						row.alpha = local ? (selected ? ALPHA_FULL : ALPHA_DIM) : 0.25;
						setPackRowHighlight(row, selected);
					}
					else
					{
						row.alpha = ALPHA_FULL;
						if (packBrowserHoveredRow != row)
						{
							setPackRowHighlight(row, false);
						};
					};
				};
				i++;
			};
		}
		
		private function onCompleteAfterRefresh():void
		{
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			reset();
		}
		
		private function errorAfterRefresh():void
		{
			Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			reset();
			showWarningMessage("File Error");
		}
		
		private function parseErrAfterRefresh():void
		{
			Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			reset();
			showWarningMessage("Parse Error");
		}
		
		private function reset():void
		{
			importPendingCostumes = null;
			packPendingEntries = null;
			clearStockIcon();
			removeAllContainers();
			startCreatingContainers();
			restoreScrollbarPos();
			showWarningMessage(null);
		}
	
		private function reset2():void
		{
			importPendingCostumes = null;
			packPendingEntries = null;
			clearStockIcon();
			removeAllContainers();
			startCreatingContainers();
			restoreScrollbarPos();
		}
	
		private function removeAllContainers():void
		{
			for (var i:int = 0; i < containerButton.length; i++)
			{
				var btn:* = containerButton[i];
				btn.ButtonInstance.removeEventListener(MouseEvent.MOUSE_OVER, containerButton_OVER);
				btn.ButtonInstance.removeEventListener(MouseEvent.MOUSE_OUT, containerButton_OUT);
				btn.ButtonInstance.removeEventListener(MouseEvent.CLICK, containerButton_CLICK);
				if (btn.ButtonInstance.parent != null)
				{
					btn.ButtonInstance.parent.removeChild(btn.ButtonInstance);
				};
			};
			containerButton = null;
		}

		/** Close the costume grid after a normal pick (not multi-select or vault import). */
		public function closeAfterPick():void
		{
			if (!isOnscreen())
			{
				return;
			};
			if (onlineImportMode || selectionMode != MODE_NONE)
			{
				return;
			};
			closeMenu(null);
		}

		private function closeMenu(e:MouseEvent):*
		{
			m_padToolbar = false;
			m_subMenu.removeEventListener(Event.ENTER_FRAME, buildStep);
			m_subMenu.removeEventListener(Event.ENTER_FRAME, previewCatchUpStep);
			if (selectionMode == MODE_PACK_DELETE)
			{
				exitPackDeleteMode(true);
				return;
			};
			if (selectionMode == MODE_PACK_BROWSER)
			{
				exitPackBrowser(true);
				return;
			};
			if (selectionMode != MODE_NONE)
			{
				if ((selectionMode == MODE_IMPORT && importPendingCostumes)
					|| ((selectionMode == MODE_PACK_IMPORT || selectionMode == MODE_PACK_EXPORT) && packPendingEntries))
				{
					importPendingCostumes = null;
					packPendingEntries = null;
					clearSelectionMode(false);
					reset();
					return;
				};
				clearSelectionMode(true);
				return;
			};
			if (onlineImportMode && returnToLocalListOnVaultExit)
			{
				exitOnlineImportToLocalList();
				return;
			};
			if(onCloseMenu != null)
			{
				onCloseMenu();
			};
			restoreScrollbarPos();
			clearSelectionMode(false);
			dismissPackMetaOverlay();
			destroyPackBrowserLayer();
			toggleBlurBackground(false);
			clearStockIcon();
			removeAllContainers();
			onlineImportMode = false;
			ownedVaultIds = null;
			clearVaultPreviewSource();
			importPendingCostumes = null;
			packPendingEntries = null;
			lastAddedVaultCostumeName = null;
			lastAddedVaultCostume = null;
			MovieClip(m_subMenu.delete_btn).visible = true;
			MovieClip(m_subMenu.refresh_btn).visible = true;
			if (m_subMenu.openFile_btn)
			{
				MovieClip(m_subMenu.openFile_btn).visible = true;
			};
			removeSelf();
		}
		
		/* ---- Toolbar / I/O / Sort ---- */

		private function wireToolbarEvents(enable:Boolean):void
		{
			bindToolbarButtons();
			wireOne(importBtn, onImportClick, enable);
			wireOne(exportBtn, onExportClick, enable);
			wireOne(packImportBtn, onPackImportClick, enable);
			wireOne(packExportBtn, onPackExportClick, enable);
			wireOne(sortBtn, onSortClick, enable);
			wireOne(confirmBtn, onConfirmClick, enable);
			wireOne(selectAllBtn, onSelectAllClick, enable);
			wireOne(deselectAllBtn, onDeselectAllClick, enable);
			wireOne(moveToEndBtn, onMoveToEndClick, enable);
			wireHoverHint(importBtn, "Browse packs for this character and import its costumes", enable);
			wireHoverHint(exportBtn, "Export selected costumes as a single-character pack", enable);
			wireHoverHint(packImportBtn, "Browse local and online costume packs", enable);
			wireHoverHint(packExportBtn, "Export selected costumes to SSF2 Custom Colors/packs/", enable);
			wireHoverHint(sortBtn, "Reorder custom costumes", enable);
			wireHoverHint(confirmBtn, null, enable);
			wireHoverHint(selectAllBtn, "Select all costumes in this list", enable);
			wireHoverHint(deselectAllBtn, "Clear the current selection", enable);
			wireHoverHint(moveToEndBtn, "Move selected costumes to the end of the list", enable);
		}

		private function onImportClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (onlineImportMode || selectionMode != MODE_NONE)
			{
				return;
			};
			enterPackBrowser(m_statsName);
		}

		private function onExportClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (onlineImportMode)
			{
				return;
			};
			enterSelectionMode(MODE_EXPORT);
			selectAllEligible();
		}

		private function onPackImportClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (onlineImportMode)
			{
				return;
			};
			enterPackBrowser(null);
		}

		private function onPackExportClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (onlineImportMode)
			{
				return;
			};
			beginPackExportVerify();
		}

		private function onSortClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (onlineImportMode)
			{
				return;
			};
			enterSelectionMode(MODE_SORT);
		}

		private function onSelectAllClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!isMultiSelectMode())
			{
				return;
			};
			selectAllEligible();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function onDeselectAllClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!isMultiSelectMode())
			{
				return;
			};
			deselectAllEligible();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
		}

		private function onMoveToEndClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (selectionMode != MODE_SORT || selectedIndices.length == 0)
			{
				return;
			};
			moveSelectedToEnd();
		}

		private function onConfirmClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (selectedIndices.length == 0)
			{
				updateGuideFromMode();
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			if (selectionMode == MODE_EXPORT)
			{
				confirmExportSelected();
			}
			else if (selectionMode == MODE_IMPORT)
			{
				confirmImportSelected();
			}
			else if (selectionMode == MODE_PACK_EXPORT)
			{
				confirmPackExportSelected();
			}
			else if (selectionMode == MODE_PACK_IMPORT)
			{
				confirmPackImportSelected();
			}
			else if (selectionMode == MODE_PACK_DELETE)
			{
				deleteMode_CLICK(null);
			}
			else if (selectionMode == MODE_DELETE)
			{
				deleteMode_CLICK(null);
			};
		}

		private function onImportFileSelected(e:Event):void
		{
			var file:File = e.target as File;
			var stream:FileStream;
			var raw:String;
			var list:Array;
			cleanupFileListeners(file);
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				raw = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				list = CostumePackIO.parseCostumesArray(raw);
				if (!list || list.length == 0)
				{
					Ssf2.MultiplayerManager.notify("No costumes in file");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					return;
				};
				importPendingCostumes = list;
				packPendingEntries = null;
				clearSelectionMode(false);
				removeAllContainers();
				startCreatingContainers();
				enterSelectionMode(MODE_IMPORT);
				selectAllEligible();
			}
			catch (err:Error)
			{
				Ssf2.MultiplayerManager.notify("Import failed");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		private function confirmImportSelected():void
		{
			var objs:Array = getSelectedCostumeObjects();
			var costume:Object;
			var name:String;
			for each (costume in objs)
			{
				name = costume.profile ? String(costume.profile) : "Custom Costume";
				PaletteMakerUtils.saveCostume(m_statsName, name, Ssf2.Utils.cloneObject(costume), PaletteMakerUtils.extractAuthorFromCostume(costume), true);
			};
			importPendingCostumes = null;
			clearSelectionMode(false);
			refresh_CLICK(null);
			Ssf2.MultiplayerManager.notify("Imported " + objs.length + " costume(s)");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function confirmExportSelected():void
		{
			var objs:Array = getSelectedCostumeObjects();
			var pack:Object;
			var list:Array;
			var costume:Object;
			var clone:Object;
			if (!objs || objs.length == 0 || !m_statsName)
			{
				Ssf2.MultiplayerManager.notify("Nothing selected");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			list = [];
			for each (costume in objs)
			{
				if (!costume)
				{
					continue;
				};
				clone = Ssf2.Utils.cloneObject(costume);
				try { delete clone._packStatsName; } catch (stripErr:Error) { };
				CostumePackIO.stripColorVaultIdFromCostume(clone);
				CostumePackIO.applyFlashSafeNudgeToCostume(clone);
				list.push(clone);
			};
			pack = {
				"format": "ssf2_costume_pack",
				"version": 2,
				"characterCount": 1,
				"characters": {}
			};
			pack.characters[m_statsName] = list;
			showPackExportMetaForm(pack);
		}

		private function onExportFileSelected(e:Event):void
		{
			var file:File = e.target as File;
			var objs:Array = getSelectedCostumeObjects();
			cleanupFileListeners(file);
			if (!file.name || file.name.toLowerCase().indexOf(".json") < 0)
			{
				file = new File(file.nativePath + (file.nativePath.toLowerCase().indexOf(".json") >= 0 ? "" : ".json"));
			};
			if (CostumePackIO.writeCostumesArrayToFile(file, objs))
			{
				Ssf2.MultiplayerManager.notify("Exported " + objs.length + " costume(s)");
				clearSelectionMode(false);
				refreshToolbarVisibility();
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			}
			else
			{
				Ssf2.MultiplayerManager.notify("Export failed");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		/** Build local pack verify list (all customs, all characters), then Confirm writes the file. */
		private function beginPackExportVerify():void
		{
			var pack:Object;
			var entries:Array;
			pack = CostumePackIO.buildCostumePackObject();
			entries = flattenPackObjectToEntries(pack);
			if (!entries || entries.length == 0)
			{
				Ssf2.MultiplayerManager.notify("No custom costumes to export");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			packPendingEntries = entries;
			importPendingCostumes = null;
			clearSelectionMode(false);
			removeAllContainers();
			startCreatingContainers();
			enterSelectionMode(MODE_PACK_EXPORT);
			selectAllEligible();
		}

		/** In-place pack list using eventIconMC rows + infoplate preview (no Events menu).
		 *  charFilter: when set (Import Costume), only packs containing that character. */
		private function enterPackBrowser(charFilter:String=null):void
		{
			clearSelectionMode(false);
			removeAllContainers();
			if (container && container.parent)
			{
				container.parent.removeChild(container);
			};
			container = null;
			containerButton = new Array();
			packBrowserSelectBusy = false;
			packBrowserCharFilter = charFilter;
			packBrowserList = CostumePackIO.listLocalCostumePacks(packBrowserCharFilter);
			selectionMode = MODE_PACK_BROWSER;
			selectedIndices = [];
			buildPackBrowserRows();
			updateNameplate();
			refreshToolbarVisibility();
			packBrowserLoadingOnline = true;
			updateGuideFromMode();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			CostumePackIO.fetchOnlineCostumePackList(onPackBrowserOnlineReady, onPackBrowserOnlineError);
		}

		private function exitPackBrowser(playSound:Boolean):void
		{
			destroyPackBrowserLayer();
			packBrowserList = null;
			packBrowserCharFilter = null;
			packBrowserSelectBusy = false;
			packBrowserLoadingOnline = false;
			selectionMode = MODE_NONE;
			selectedIndices = [];
			hideInfoPlate();
			refreshToolbarVisibility();
			if (playSound)
			{
				Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
			};
			reset();
		}

		private function destroyPackBrowserLayer():void
		{
			var row:MovieClip;
			packBrowserHoveredRow = null;
			if (packBrowserRows)
			{
				for each (row in packBrowserRows)
				{
					if (!row)
					{
						continue;
					};
					row.removeEventListener(MouseEvent.CLICK, packBrowserRow_CLICK);
					row.removeEventListener(MouseEvent.ROLL_OVER, packBrowserRow_OVER);
					row.removeEventListener(MouseEvent.ROLL_OUT, packBrowserRow_OUT);
					row.removeEventListener(MouseEvent.MOUSE_OVER, packBrowserRow_OVER);
					row.removeEventListener(MouseEvent.MOUSE_OUT, packBrowserRow_OUT);
				};
			};
			packBrowserRows = null;
			if (packBrowserLayer && packBrowserLayer.parent)
			{
				packBrowserLayer.parent.removeChild(packBrowserLayer);
			};
			packBrowserLayer = null;
			if (packBrowserMask && packBrowserMask.parent)
			{
				packBrowserMask.parent.removeChild(packBrowserMask);
			};
			packBrowserMask = null;
			destroyPackBrowserPreview();
		}

		private function buildPackBrowserRows():void
		{
			var i:int;
			var meta:Object;
			var row:MovieClip;
			var yOffset:Number;
			var rowBounds:Rectangle;
			destroyPackBrowserLayer();
			packBrowserLayer = new MovieClip();
			packBrowserLayer.x = PACK_BROWSER_LAYER_X;
			packBrowserLayer.y = packBrowserListY;
			packBrowserMask = new MovieClip();
			packBrowserMask.graphics.beginFill(0xFF0000, 1);
			packBrowserMask.graphics.drawRect(0, 0, PACK_BROWSER_MASK_W, PACK_BROWSER_LIST_H);
			packBrowserMask.graphics.endFill();
			packBrowserMask.x = PACK_BROWSER_LAYER_X - 4;
			packBrowserMask.y = packBrowserListY;
			packBrowserMask.visible = false;
			packBrowserRows = [];
			yOffset = 0;
			i = 0;
			while (packBrowserList && i < packBrowserList.length)
			{
				meta = packBrowserList[i];
				row = Ssf2.ResourceManager.getLibraryMC("eventIconMC") as MovieClip;
				if (!row)
				{
					i++;
					continue;
				};
				row.name = "packRow_" + i;
				row.x = 0;
				row.y = yOffset * PACK_BROWSER_ROW_H;
				row.buttonMode = true;
				row.mouseChildren = false;
				setPackRowHighlight(row, false);
				if (row.eventName)
				{
					row.eventName.text = meta && meta.name ? String(meta.name) : "Pack";
					row.eventName.mouseEnabled = false;
				};
				if (row.complete)
				{
					row.complete.visible = false;
				};
				// Nudge only enough so the pack name isn't clipped (avoid huge getBounds shifts).
				try
				{
					if (row.eventName)
					{
						rowBounds = row.eventName.getBounds(row);
						if (rowBounds && rowBounds.x < 2)
						{
							row.x = 2 - rowBounds.x;
						};
					};
				}
				catch (boundErr:Error)
				{
					row.x = 8;
				};
				attachPackRowStockIcons(row, meta, i);
				row.addEventListener(MouseEvent.CLICK, packBrowserRow_CLICK);
				row.addEventListener(MouseEvent.ROLL_OVER, packBrowserRow_OVER);
				row.addEventListener(MouseEvent.ROLL_OUT, packBrowserRow_OUT);
				packBrowserLayer.addChild(row);
				packBrowserRows.push(row);
				yOffset++;
				i++;
			};
			m_subMenu.addChild(packBrowserMask);
			m_subMenu.addChild(packBrowserLayer);
			packBrowserLayer.mask = packBrowserMask;
			ensurePackBrowserPreview();
			updatePackBrowserPreview(null);
			restoreScrollbarPos();
			if (m_subMenu.nameplate && m_subMenu.nameplate.counter_txt)
			{
				m_subMenu.nameplate.counter_txt.text = packBrowserList ? packBrowserList.length : 0;
			};
		}

		private function attachPackRowStockIcons(row:MovieClip, meta:Object, rowIndex:int):void
		{
			var samples:Array;
			var startX:Number;
			var cursorX:Number;
			var scale:Number;
			var b:Rectangle;
			var i:int;
			var sample:Object;
			var stock:MovieClip;
			var statsName:String;
			var costume:Object;
			var child:DisplayObject;
			var toRemove:Array;
			if (!row || !meta)
			{
				return;
			};
			samples = meta.previewSamples as Array;
			if ((!samples || samples.length == 0) && meta.filePath)
			{
				samples = CostumePackIO.extractPackPreviewSamples(
					CostumePackIO.loadLocalCostumePackByPath(String(meta.filePath)),
					PACK_BROWSER_STOCK_MAX,
					packBrowserCharFilter
				);
				meta.previewSamples = samples;
			};
			if ((!samples || samples.length == 0) && meta.downloadUrl && meta.source == "online")
			{
				requestOnlinePackPreview(meta, rowIndex);
				return;
			};
			if (!samples || samples.length == 0)
			{
				return;
			};
			toRemove = [];
			i = 0;
			while (i < row.numChildren)
			{
				child = row.getChildAt(i);
				if (child && child.name && String(child.name).indexOf("packStock_") == 0)
				{
					toRemove.push(child);
				};
				i++;
			};
			for each (child in toRemove)
			{
				if (child.parent)
				{
					child.parent.removeChild(child);
				};
			};
			// Keep pack name short so stock icons start near STOCK_START_X and fit the mask.
			if (row.eventName)
			{
				truncatePackRowName(row, PACK_BROWSER_STOCK_START_X - 14);
			};
			startX = PACK_BROWSER_STOCK_START_X;
			if (row.eventName)
			{
				startX = Math.max(PACK_BROWSER_STOCK_START_X, row.eventName.x + row.eventName.textWidth + 14);
			};
			cursorX = startX;
			i = 0;
			while (i < samples.length && i < PACK_BROWSER_STOCK_MAX)
			{
				sample = samples[i];
				if (!sample)
				{
					i++;
					continue;
				};
				statsName = sample.statsName ? String(sample.statsName) : "";
				costume = sample.costume;
				if (!statsName)
				{
					i++;
					continue;
				};
				stock = PaletteMakerUtils.getStockIcon(statsName, false);
				if (!stock)
				{
					i++;
					continue;
				};
				stock.name = "packStock_" + i;
				stock.mouseEnabled = false;
				stock.mouseChildren = false;
				stock.scaleX = 1;
				stock.scaleY = 1;
				if (stock.height > 0)
				{
					scale = PACK_BROWSER_STOCK_H / stock.height;
					stock.scaleX = scale;
					stock.scaleY = scale;
				}
				else
				{
					stock.scaleX = 0.22;
					stock.scaleY = 0.22;
				};
				if (costume)
				{
					applyCostumePreview(stock, costume, false);
				};
				try
				{
					b = stock.getBounds(stock);
					if (cursorX + (b.width * stock.scaleX) > PACK_BROWSER_MASK_W - 8)
					{
						break;
					};
					stock.x = cursorX - (b.x * stock.scaleX);
					stock.y = 8 - (b.y * stock.scaleY);
					cursorX = cursorX + (b.width * stock.scaleX) + PACK_BROWSER_STOCK_GAP;
				}
				catch (posErr:Error)
				{
					if (cursorX + PACK_BROWSER_STOCK_H > PACK_BROWSER_MASK_W - 8)
					{
						break;
					};
					stock.x = cursorX;
					stock.y = 8;
					cursorX = cursorX + PACK_BROWSER_STOCK_H + PACK_BROWSER_STOCK_GAP;
				};
				row.addChild(stock);
				i++;
			};
		}

		private function requestOnlinePackPreview(meta:Object, rowIndex:int):void
		{
			if (!meta || !meta.downloadUrl || meta._previewFetchStarted)
			{
				return;
			};
			meta._previewFetchStarted = true;
			CostumePackIO.fetchCostumePackFromUrl(String(meta.downloadUrl), function(pack:Object):void
			{
				var row:MovieClip;
				var enriched:Object;
				if (selectionMode != MODE_PACK_BROWSER || !packBrowserList || rowIndex < 0 || rowIndex >= packBrowserList.length)
				{
					return;
				};
				if (!pack)
				{
					return;
				};
				enriched = packBrowserList[rowIndex];
				if (!enriched)
				{
					return;
				};
				if (pack.name)
				{
					enriched.name = String(pack.name);
				};
				if (pack.author)
				{
					enriched.author = String(pack.author);
				};
				if (pack.description)
				{
					enriched.description = String(pack.description);
				};
				enriched.costumeCount = packBrowserCharFilter
					? CostumePackIO.countCostumesForCharacterInPack(pack, packBrowserCharFilter)
					: CostumePackIO.countCostumesInPack(pack);
				enriched.characterCount = packBrowserCharFilter
					? (CostumePackIO.packHasCharacter(pack, packBrowserCharFilter) ? 1 : 0)
					: CostumePackIO.countCharactersInPack(pack);
				enriched.previewSamples = CostumePackIO.extractPackPreviewSamples(pack, PACK_BROWSER_STOCK_MAX, packBrowserCharFilter);
				if (packBrowserCharFilter && enriched.characterCount <= 0)
				{
					packBrowserList.splice(rowIndex, 1);
					buildPackBrowserRows();
					return;
				};
				if (packBrowserRows && rowIndex < packBrowserRows.length)
				{
					row = packBrowserRows[rowIndex] as MovieClip;
					if (row)
					{
						if (row.eventName && enriched.name)
						{
							row.eventName.text = String(enriched.name);
						};
						attachPackRowStockIcons(row, enriched, rowIndex);
					};
				};
			}, null);
		}

		private function onPackBrowserOnlineReady(onlineList:Array):void
		{
			var localIds:Object;
			var meta:Object;
			var id:String;
			packBrowserLoadingOnline = false;
			if (selectionMode != MODE_PACK_BROWSER)
			{
				return;
			};
			localIds = {};
			if (!packBrowserList)
			{
				packBrowserList = [];
			};
			for each (meta in packBrowserList)
			{
				if (meta && meta.id)
				{
					localIds[String(meta.id)] = true;
				};
				if (meta && meta.fileName)
				{
					localIds[String(meta.fileName).toLowerCase()] = true;
				};
			};
			if (onlineList)
			{
				for each (meta in onlineList)
				{
					if (!meta)
					{
						continue;
					};
					id = meta.id ? String(meta.id) : "";
					if (id && localIds[id])
					{
						continue;
					};
					if (meta.fileName && localIds[String(meta.fileName).toLowerCase()])
					{
						continue;
					};
					packBrowserList.push(meta);
				};
			};
			buildPackBrowserRows();
			updateGuideFromMode();
			updatePackBrowserPreview(null);
		}

		private function packBrowserRow_OVER(e:MouseEvent):void
		{
			var index:int = packBrowserRowIndex(e.currentTarget);
			var meta:Object;
			var refreshed:Object;
			var row:MovieClip = e.currentTarget as MovieClip;
			if (index < 0 || !packBrowserList || index >= packBrowserList.length)
			{
				return;
			};
			if (packBrowserHoveredRow && packBrowserHoveredRow != row)
			{
				setPackRowHighlight(packBrowserHoveredRow, false);
			};
			packBrowserHoveredRow = row;
			setPackRowHighlight(row, true);
			meta = packBrowserList[index];
			if (meta && meta.source == "local" && meta.filePath)
			{
				refreshed = CostumePackIO.refreshLocalPackMetaFromDisk(String(meta.filePath), packBrowserCharFilter);
				if (refreshed)
				{
					packBrowserList[index] = refreshed;
					meta = refreshed;
					try
					{
						if (row.eventName)
						{
							row.eventName.text = meta.name ? String(meta.name) : "Pack";
						};
					}
					catch (nameErr:Error)
					{
					};
					attachPackRowStockIcons(row, meta, index);
				};
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_hover");
			clearHoverHint();
			updatePackBrowserPreview(meta);
		}

		private function packBrowserRow_CLICK(e:MouseEvent):void
		{
			var index:int;
			var meta:Object;
			e.stopPropagation();
			if (packBrowserSelectBusy)
			{
				return;
			};
			index = packBrowserRowIndex(e.currentTarget);
			if (index < 0 || !packBrowserList || index >= packBrowserList.length)
			{
				return;
			};
			meta = packBrowserList[index];
			if (selectionMode == MODE_PACK_DELETE)
			{
				if (!meta || meta.source != "local" || !meta.filePath)
				{
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					return;
				};
				toggleIndexSelection(index);
				lastAnchorIndex = index;
				refreshPackDeleteRowAlphas();
				refreshModeChrome();
				updateGuideFromMode();
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				return;
			};
			if (selectionMode != MODE_PACK_BROWSER)
			{
				return;
			};
			packBrowserSelectBusy = true;
			Ssf2.SoundQueue.instance.playSoundEffect("menu_selectstage");
			if (meta.source == "local" && meta.filePath)
			{
				finishPackBrowserOpen(CostumePackIO.loadLocalCostumePackByPath(String(meta.filePath)), meta);
			}
			else if (meta.downloadUrl)
			{
				Ssf2.MultiplayerManager.notify("Downloading pack…");
				CostumePackIO.fetchCostumePackFromUrl(String(meta.downloadUrl), function(pack:Object):void
				{
					finishPackBrowserOpen(pack, meta);
				}, function(msg:String):void
				{
					packBrowserSelectBusy = false;
					Ssf2.MultiplayerManager.notify(msg ? msg : "Pack download failed");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				});
			}
			else
			{
				packBrowserSelectBusy = false;
				Ssf2.MultiplayerManager.notify("Pack source missing");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		private function finishPackBrowserOpen(pack:Object, meta:Object):void
		{
			var charFilter:String;
			packBrowserSelectBusy = false;
			if (!pack)
			{
				Ssf2.MultiplayerManager.notify("Invalid costume pack");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			if (meta)
			{
				if ((!pack.name || String(pack.name).length == 0) && meta.name)
				{
					pack["name"] = meta.name;
				};
				if ((!pack.id || String(pack.id).length == 0) && meta.id)
				{
					pack["id"] = meta.id;
				};
			};
			charFilter = packBrowserCharFilter;
			if (charFilter)
			{
				pack = CostumePackIO.sliceCostumePackToCharacter(pack, charFilter);
				if (!pack)
				{
					Ssf2.MultiplayerManager.notify("Pack has no costumes for " + charFilter);
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					return;
				};
			};
			destroyPackBrowserLayer();
			packBrowserList = null;
			packBrowserLoadingOnline = false;
			packBrowserCharFilter = null;
			selectionMode = MODE_NONE;
			beginPackImportVerify(pack);
		}

		private function confirmPackExportSelected():void
		{
			var pack:Object = buildPackObjectFromSelection();
			if (!pack || int(pack.characterCount) <= 0)
			{
				Ssf2.MultiplayerManager.notify("Nothing selected");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			showPackExportMetaForm(pack);
		}

		private function showPackExportMetaForm(pack:Object):void
		{
			var host:Sprite;
			var panel:Sprite;
			var header:Sprite;
			var title:TextField;
			var saveHit:Sprite;
			var cancelHit:Sprite;
			dismissPackMetaOverlay();
			packMetaPending = pack;
			host = new Sprite();
			host.name = "packMetaOverlay";
			host.graphics.beginFill(0x000000, 0.65);
			host.graphics.drawRect(0, 0, Ssf2.Main.Width, Ssf2.Main.Height);
			host.graphics.endFill();
			panel = new Sprite();
			panel.graphics.beginFill(0x2a2a2a, 0.95);
			panel.graphics.lineStyle(1, 0x555555, 1);
			panel.graphics.drawRect(0, 0, 360, 300);
			panel.graphics.endFill();
			panel.x = (Ssf2.Main.Width - 360) / 2;
			panel.y = (Ssf2.Main.Height - 300) / 2;
			header = new Sprite();
			header.graphics.beginFill(0x1e1e1e, 1);
			header.graphics.drawRect(0, 0, 360, 36);
			header.graphics.endFill();
			panel.addChild(header);
			title = new TextField();
			title.defaultTextFormat = new TextFormat("_sans", 16, 0xFFFFFF, true);
			title.text = "Pack Meta Data";
			title.x = 12;
			title.y = 8;
			title.width = 330;
			title.height = 24;
			title.selectable = false;
			panel.addChild(title);
			packMetaNameField = makePackMetaInput(panel, "Pack Name", 48, false, true);
			packMetaAuthorField = makePackMetaInput(panel, "Author", 100, false, true);
			packMetaDescField = makePackMetaInput(panel, "Description", 152, true, true);
			saveHit = makePackMetaButton(panel, "Save", 70, 250, 0x2d6a3e);
			cancelHit = makePackMetaButton(panel, "Cancel", 190, 250, 0x6a2d2d);
			saveHit.addEventListener(MouseEvent.CLICK, onPackMetaSaveClick);
			cancelHit.addEventListener(MouseEvent.CLICK, onPackMetaCancelClick);
			host.addChild(panel);
			packMetaOverlay = host;
			Ssf2.Main.Root.addChild(host);
			if (Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.focus = packMetaNameField;
			};
		}

		private function onPackMetaSaveClick(e:MouseEvent):void
		{
			var name:String;
			var path:String;
			var pack:Object;
			var shouldChainImport:Boolean;
			var nudgeCount:int;
			e.stopPropagation();
			name = packMetaNameField ? trimPackMetaText(packMetaNameField.text) : "";
			if (!name || name.length == 0)
			{
				Ssf2.MultiplayerManager.notify("Pack name is required");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			pack = packMetaPending;
			if (!pack)
			{
				dismissPackMetaOverlay();
				return;
			};
			shouldChainImport = chainImportAfterPackSave;
			CostumePackIO.applyPackMetadata(
				pack,
				name,
				packMetaDescField ? packMetaDescField.text : "",
				packMetaAuthorField ? packMetaAuthorField.text : ""
			);
			nudgeCount = CostumePackIO.applyFlashSafeNudgeToPack(pack);
			path = CostumePackIO.writeCostumePackToPacksFolder(pack);
			dismissPackMetaOverlay();
			if (path)
			{
				Ssf2.MultiplayerManager.notify("Costume pack saved\n" + path);
				if (nudgeCount > 0)
				{
					Ssf2.MultiplayerManager.notify("FYI: fixed " + nudgeCount
						+ " pure black/white replacements for flash safety");
				};
				packPendingEntries = null;
				chainImportAfterPackSave = false;
				clearSelectionMode(false);
				if (shouldChainImport)
				{
					beginPackImportVerify(pack);
				}
				else
				{
					refresh_CLICK(null);
				};
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			}
			else
			{
				Ssf2.MultiplayerManager.notify("Pack export failed");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		/** Entry point from Pack Browser (and legacy callers). Filters already-owned costumes. */
		public function beginPackImportVerify(pack:Object):void
		{
			var filtered:Object;
			var entries:Array;
			if (!pack)
			{
				Ssf2.MultiplayerManager.notify("Invalid costume pack");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			filtered = CostumePackIO.filterOwnedCostumesFromPack(pack);
			if (filtered && int(filtered.skipped) > 0)
			{
				Ssf2.MultiplayerManager.notify("Skipped " + int(filtered.skipped) + " already-owned costume(s)");
			};
			if (!filtered || int(filtered.remaining) <= 0)
			{
				Ssf2.MultiplayerManager.notify("Nothing new to import");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			entries = flattenPackObjectToEntries(filtered.pack);
			if (!entries || entries.length == 0)
			{
				Ssf2.MultiplayerManager.notify("Pack has no costumes");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			packPendingEntries = entries;
			importPendingCostumes = null;
			clearSelectionMode(false);
			removeAllContainers();
			startCreatingContainers();
			enterSelectionMode(MODE_PACK_IMPORT);
			selectAllEligible();
		}

		/**
		 * Color-sheet multi-import: show costumes for pack save, then chain to import verify after meta save.
		 */
		public function beginColorSheetPackExport(pack:Object):void
		{
			var entries:Array;
			if (!pack)
			{
				Ssf2.MultiplayerManager.notify("Invalid costume pack");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			entries = flattenPackObjectToEntries(pack);
			if (!entries || entries.length == 0)
			{
				Ssf2.MultiplayerManager.notify("No costumes from color sheets");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			packPendingEntries = entries;
			importPendingCostumes = null;
			clearSelectionMode(false);
			chainImportAfterPackSave = true;
			removeAllContainers();
			startCreatingContainers();
			enterSelectionMode(MODE_PACK_EXPORT);
			selectAllEligible();
		}

		private function confirmPackImportSelected():void
		{
			var pack:Object = buildPackObjectFromSelection();
			if (!pack || int(pack.characterCount) <= 0)
			{
				Ssf2.MultiplayerManager.notify("Nothing selected");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			Ssf2.MenuController.onlinePromptMenu.message = "Import selected costumes:\nYES = Append\nNO = Backup + Replace those characters";
			Ssf2.MenuController.onlinePromptMenu.onAccept = function():void
			{
				finishPackImport(pack, false);
			};
			Ssf2.MenuController.onlinePromptMenu.onDismiss = function():void
			{
				finishPackImport(pack, true);
			};
			Ssf2.MenuController.onlinePromptMenu.show();
		}

		private function finishPackImport(pack:Object, replace:Boolean):void
		{
			var backupPath:String;
			var count:int;
			Ssf2.MenuController.onlinePromptMenu.removeSelf();
			if (replace)
			{
				backupPath = CostumePackIO.backupCurrentCostumePack();
				if (!backupPath)
				{
					Ssf2.MultiplayerManager.notify("Backup failed; replace aborted");
					Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
					return;
				};
			};
			count = CostumePackIO.importCostumePack(pack, replace);
			packPendingEntries = null;
			clearSelectionMode(false);
			refresh_CLICK(null);
			if (replace)
			{
				Ssf2.MultiplayerManager.notify("Replaced costumes (" + count + "). Backup:\n" + backupPath);
			}
			else
			{
				Ssf2.MultiplayerManager.notify("Appended " + count + " costume(s)");
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		private function onFileBrowseCancel(e:Event):void
		{
			cleanupFileListeners(e.target as File);
		}

		private function cleanupFileListeners(file:File):void
		{
			if (!file)
			{
				return;
			};
			file.removeEventListener(Event.SELECT, onImportFileSelected);
			file.removeEventListener(Event.SELECT, onExportFileSelected);
			file.removeEventListener(Event.CANCEL, onFileBrowseCancel);
		}

		private function moveSelectedBeforeIndex(targetIndex:int):void
		{
			var favs:Array;
			var moving:Array;
			var result:Array;
			var idx:int;
			var n:int;
			var before:int;
			var insertAt:int;
			var i:int;
			if (!isCustomCostumeIndex(targetIndex) || selectedIndices.indexOf(targetIndex) != -1)
			{
				return;
			};
			before = catalogIndexOfTile(allCostumes[targetIndex]);
			if (before < 0)
			{
				return;
			};
			moving = [];
			for each (idx in selectedIndices)
			{
				if (!isCustomCostumeIndex(idx))
				{
					continue;
				};
				n = catalogIndexOfTile(allCostumes[idx]);
				if (n >= 0 && moving.indexOf(n) < 0)
				{
					moving.push(n);
				};
			};
			if (moving.length == 0)
			{
				return;
			};
			favs = PaletteMakerUtils.getFavoriteIndexes(m_statsName);
			result = [];
			i = 0;
			while (favs && i < favs.length)
			{
				n = int(favs[i]);
				if (moving.indexOf(n) < 0)
				{
					result.push(n);
				};
				i++;
			};
			insertAt = result.indexOf(before);
			if (insertAt < 0)
			{
				insertAt = result.length;
			};
			i = 0;
			while (i < moving.length)
			{
				result.splice(insertAt + i, 0, moving[i]);
				i++;
			};
			PaletteMakerUtils.setFavoriteIndexes(m_statsName, result);
			reloadSortGridAfterMove(moving.length, false);
		}

		private function moveSelectedToEnd():void
		{
			var favs:Array;
			var moving:Array;
			var result:Array;
			var idx:int;
			var n:int;
			var i:int;
			moving = [];
			for each (idx in selectedIndices)
			{
				if (!isCustomCostumeIndex(idx))
				{
					continue;
				};
				n = catalogIndexOfTile(allCostumes[idx]);
				if (n >= 0 && moving.indexOf(n) < 0)
				{
					moving.push(n);
				};
			};
			if (moving.length == 0)
			{
				return;
			};
			favs = PaletteMakerUtils.getFavoriteIndexes(m_statsName);
			result = [];
			i = 0;
			while (favs && i < favs.length)
			{
				n = int(favs[i]);
				if (moving.indexOf(n) < 0)
				{
					result.push(n);
				};
				i++;
			};
			result = result.concat(moving);
			PaletteMakerUtils.setFavoriteIndexes(m_statsName, result);
			reloadSortGridAfterMove(moving.length, true);
		}

		/** Stay in sort mode after a reorder; only close_btn exits. */
		private function reloadSortGridAfterMove(count:int, toEnd:Boolean):void
		{
			selectedIndices = [];
			lastAnchorIndex = -1;
			rebuildCostumeGrid();
			refreshToolbarVisibility();
			updateGuideFromMode();
			Ssf2.MultiplayerManager.notify(toEnd ? ("Moved " + count + " to end") : ("Moved " + count + " costume(s)"));
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		public function getSelectedCostume():int
		{
			var data:Object;
			if (allCostumes && selectedCostume >= 0 && selectedCostume < allCostumes.length)
			{
				data = allCostumes[selectedCostume];
				if (data && data.hasOwnProperty("_gameCostumeIndex") && (data._gameCostumeIndex is Number))
				{
					return int(data._gameCostumeIndex);
				};
			};
			if (includeNoRecolorSlot)
			{
				return selectedCostume - 2;
			};
			return selectedCostume - 1;
		}

		/** Selected costume object from the current list (includes team / metal browse slots). */
		public function getSelectedCostumeData():Object
		{
			if (!allCostumes || selectedCostume < 0 || selectedCostume >= allCostumes.length)
			{
				return null;
			};
			return allCostumes[selectedCostume];
		}

		public function isNoRecolorSelected():Boolean
		{
			if (!includeNoRecolorSlot || !allCostumes || selectedCostume < 0 || selectedCostume >= allCostumes.length)
			{
				return false;
			};
			return Boolean(allCostumes[selectedCostume] && allCostumes[selectedCostume].noRecolor);
		}
	
		public function forceRefresh():void
		{
			PaletteMakerUtils.loadCostumeFile(m_statsName,
			{
				"onComplete":reset2
			});
		}

    }
}
