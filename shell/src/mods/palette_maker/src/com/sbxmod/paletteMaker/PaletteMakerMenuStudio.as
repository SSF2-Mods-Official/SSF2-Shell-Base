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

    /** Studio chrome: setup, freeze, palette math, tool settings and popups, pause/rest area, highlights, MC name dropdown. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuStudio extends PaletteMakerMenuUniqueStrip
    {
        public function PaletteMakerMenuStudio()
        {
            super();
        }

		internal static var sessionActive:Boolean = false;

		/** In-game costume accessory clip names (mcName) for the open character. */
		protected var availableMcNames:Array = [];

		protected var selectedMcName:String = null;

		protected var mcNameDropdown:Sprite = null;

		protected var mcNameDropdownLabel:TextField = null;

		protected var mcNameDropdownList:Sprite = null;

		protected var mcNameDropdownOpen:Boolean = false;

		protected var importCodePastePopup:ImportCodePastePopup = null;

		protected var magnifierOverlay:Sprite;

		protected var toolSquares:Array = [];

		protected var freezeChordWasDown:Boolean = false;

		/** Nudge unique-sprite cluster up/left from Back-button anchor. */
		private static const UNIQUE_ANCHOR_NUDGE_X:Number = -10;

		private static const UNIQUE_ANCHOR_NUDGE_Y:Number = -8;

		internal static var settingAlwaysIsolate:Boolean = false;

		internal static var settingShowUniquePaSprites:Boolean = true;

		internal static var settingDontAutoGenerateColorGroups:Boolean = true;

		internal static var settingDiscordCostumePreview:Boolean = true;

		internal static var settingDebugPaletteMaker:Boolean = false;

		/** On first select, briefly paint bases as primary (or alt if already that shade). */
		internal static var settingSelectHighlight:Boolean = false;

		internal static var settingSelectHighlightPrimary:uint = 0xFFFF0000;

		internal static var settingSelectHighlightAlt:uint = 0xFFFFFFFF;

		internal static var settingRestAreaTodIndex:int = 1;

		internal static var settingRestAreaMusicIndex:int = -1;

		internal static var settingsLoaded:Boolean = false;

		protected var m_game:*;

		protected var toolSettingsPopup:ToolSettingsPopup = null;

		protected var shortcutsPopup:ShortcutsPopup = null;

		protected var achievementsPopup:AchievementsPopup = null;

		protected var showUiButton:Sprite = null;

		protected var changeTodButton:Sprite = null;

		protected var changeMusicButton:Sprite = null;

		protected var uiHidden:Boolean = false;

		/** Pause screenshot toys "hide art" — keeps unique sprites / PA off while set. */
		private var pauseArtHidden:Boolean = false;

		protected var restAreaTodIndex:int = 1;

		protected var restAreaMusicIndex:int = 0;

		internal static const REST_AREA_TOD_FRAMES:Array = [1, 7, 9, 11, 13, 15, 17];

		private static const REST_AREA_TOD_NAMES:Array = ["Dawn", "Day", "Afternoon", "Sunset", "Dusk", "Night", "Late Night"];

		internal static const REST_AREA_MUSIC:Array = ["bgm_restareasmash4", "bgm_restareabrawl", "bgm_restareamelee", "bgm_restarea"];

		/** Re-run unique layout for N frames so portrait rail settles (not same-frame as refresh). */
		protected var uniquePaRelayoutFrames:int = 0;

		/** Cached opaque-edge outline bitmaps keyed by source BitmapData. */
		private var unchangedOutlineBdCache:Dictionary = new Dictionary(true);

		/** One-time base-color sets per display for cheap unchanged-art checks. */
		private var displayBaseColorCache:Dictionary = new Dictionary(true);

		protected var unchangedHighlightsDirty:Boolean = true;

		private var unchangedHighlightsCleared:Boolean = false;

		/** Last outline tint per target; 0 means hidden. */
		private var unchangedOutlineState:Dictionary = new Dictionary(true);

		protected var pmPauseLetGo:Boolean = true;

		protected var pauseToys:PauseScreenshotToys = null;

		protected var snapshotUiWasVisible:Boolean = true;

		protected function ensureCopyToClipboardBtn():void
		{
			var i:int;
			var child:DisplayObject;
			var className:String;
			for (i = 0; i < m_subMenu.numChildren; i++)
			{
				child = m_subMenu.getChildAt(i);
				className = getQualifiedClassName(child);
				if (className && className.indexOf("CopyToClipboardBtn") != -1)
				{
					copyToClipboardBtn = child as MovieClip;
					break;
				};
			};
			if (!copyToClipboardBtn)
			{
				copyToClipboardBtn = Ssf2.ResourceManager.getLibraryMC("palette_editor_fla.CopyToClipboardBtn");
				if (!copyToClipboardBtn)
				{
					copyToClipboardBtn = Ssf2.ResourceManager.getLibraryMC("CopyToClipboardBtn");
				};
				if (copyToClipboardBtn && m_subMenu.save_btn)
				{
					copyToClipboardBtn.x = m_subMenu.save_btn.x + m_subMenu.save_btn.width + 8;
					copyToClipboardBtn.y = m_subMenu.save_btn.y;
					m_subMenu.addChild(copyToClipboardBtn);
				};
			};
		}

		protected function ensureImportFromOnlineBtn():void
		{
			var i:int;
			var child:DisplayObject;
			var className:String;
			for (i = 0; i < m_subMenu.numChildren; i++)
			{
				child = m_subMenu.getChildAt(i);
				className = getQualifiedClassName(child);
				if (className && className.indexOf("ImportFromOnlineBtn") != -1)
				{
					importFromOnlineBtn = child as MovieClip;
					break;
				};
			};
			if (!importFromOnlineBtn)
			{
				importFromOnlineBtn = Ssf2.ResourceManager.getLibraryMC("palette_editor_fla.ImportFromOnlineBtn");
				if (!importFromOnlineBtn)
				{
					importFromOnlineBtn = Ssf2.ResourceManager.getLibraryMC("ImportFromOnlineBtn");
				};
				if (importFromOnlineBtn)
				{
					var anchor:MovieClip = copyToClipboardBtn || m_subMenu.save_btn;
					if (anchor)
					{
						importFromOnlineBtn.x = anchor.x + anchor.width + 8;
						importFromOnlineBtn.y = anchor.y;
					};
					m_subMenu.addChild(importFromOnlineBtn);
				};
			};
		}

		protected function ensureMagnifierOverlay():void
		{
			if (magnifierOverlay)
			{
				return;
			};
			magnifierOverlay = new Sprite();
			magnifierOverlay.mouseEnabled = false;
			magnifierOverlay.mouseChildren = false;
			magnifierOverlay.visible = false;
			m_container.addChild(magnifierOverlay);
		}

		protected var m_padFocus:int = 0;

		protected function movePadFocus(delta:int):void
		{
			var btn:MovieClip;
			if (!m_buttons || m_buttons.length == 0)
			{
				return;
			};
			btn = m_buttons[m_padFocus % m_buttons.length];
			resetButtonFocus(btn);
			m_padFocus = (m_padFocus + delta + m_buttons.length) % m_buttons.length;
			setButtonFocus(m_buttons[m_padFocus]);
		}

		protected function activatePadFocus():void
		{
			var btn:MovieClip;
			if (!m_buttons || m_buttons.length == 0)
			{
				return;
			};
			btn = m_buttons[m_padFocus % m_buttons.length];
			btn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		}

		protected function syncPauseEnabledWithUi():void
		{
			var enablePause:Boolean = uiHidden;
			if (m_game)
			{
				m_game.PauseEnabled = enablePause;
				if (m_game.LevelData)
				{
					m_game.LevelData.pauseEnabled = enablePause;
				};
			};
			if (!enablePause && Ssf2.GameController.stageData && Ssf2.GameController.stageData.Paused)
			{
				try
				{
					Ssf2.GameController.stageData.Paused = false;
				}
				catch (err:Error)
				{
				};
			};
		}

		protected function editingTextStart(e:FocusEvent):void
		{
			setUiKeysFrozen(true);
			pmPauseLetGo = false;
			if (m_game)
			{
				m_game.PauseEnabled = false;
				if (m_game.LevelData)
				{
					m_game.LevelData.pauseEnabled = false;
				};
			};
		}

		protected function editingTextEnd(e:FocusEvent):void
		{
			setUiKeysFrozen(false);
			syncPauseEnabledWithUi();
			pmPauseLetGo = false;
		}

		protected function checkCostumeName(e:Event):void
		{
			if(m_subMenu.slotName.text == "\t")
			{
				e.preventDefault();
			};
			// Save is allowed for any non-empty name (including "In-Game" / "No Recolor").
			Ssf2.Utils.setBrightness(m_subMenu.save_btn, 0);
		}

		protected function setUiKeysFrozen(apply:Boolean):void
		{
			uiKeysFrozen = apply;
			updateStageFreeze();
		}

		protected function updateStageFreeze():void
		{
			var freeze:Boolean = uiKeysFrozen || magnifierInputActive || characterFrozen;
			if (!Ssf2.GameController.stageData)
			{
				return;
			};
			if (Ssf2.GameController.stageData.FreezeKeys == freeze)
			{
				return;
			};
			Ssf2.GameController.stageData.FreezeKeys = freeze;
			if (freeze)
			{
				Ssf2.GameController.hud.killEvents();
			}
			else
			{
				Ssf2.GameController.hud.makeEvents();
			};
		}

		protected function freezeKeys(apply:Boolean):void
		{
			setUiKeysFrozen(apply);
		}

		protected function setCharacterFrozen(on:Boolean, silent:Boolean = false):void
		{
			if (characterFrozen == on)
			{
				if (on && player)
				{
					try
					{
						player.FreezePlayback = true;
					}
					catch (keepErr:Error)
					{
					};
				};
				return;
			};
			characterFrozen = on;
			if (player)
			{
				try
				{
					player.FreezePlayback = on;
					if (on)
					{
						characterFreezeX = player.getX();
						characterFreezeY = player.getY();
						characterFreezeScale = player.SizeRatio;
					};
				}
				catch (posErr:Error)
				{
				};
			};
			updateStageFreeze();
			refreshFreezeToolVisual();
			if (!silent)
			{
				Ssf2.MultiplayerManager.notify(on ? "Character frozen" : "Character unfrozen");
				Ssf2.SoundQueue.instance.playSoundEffect(on ? "menu_select" : "menu_back");
			};
			PaletteMakerAchievements.track("freeze", { "on": on });
			if (on && isolateMode)
			{
				PaletteMakerAchievements.unlock("secret_freeze_isolate");
			};
		}

		private function refreshFreezeToolVisual():void
		{
			refreshToggleToolVisuals();
		}

		protected function refreshToggleToolVisuals():void
		{
			var tool:PaletteToolSquare;
			var i:int;
			var ct:ColorTransform;
			var level:Number;
			var on:Boolean;
			if (!toolSquares)
			{
				return;
			};
			i = 0;
			while (i < toolSquares.length)
			{
				tool = toolSquares[i] as PaletteToolSquare;
				if (!tool)
				{
					i++;
					continue;
				};
				on = false;
				if (tool.toolId == "FZ")
				{
					on = characterFrozen;
					level = on ? 45 : 0;
					ct = new ColorTransform();
					ct.redOffset = level * 2.55;
					ct.greenOffset = level * 2.55;
					ct.blueOffset = level * 2.55;
					tool.transform.colorTransform = ct;
					tool.alpha = on ? 1 : 0.92;
				}
				else if (tool.toolId == "RE")
				{
					on = recolorEffectsMode;
					level = on ? 45 : 0;
					ct = new ColorTransform();
					ct.redOffset = level * 2.55;
					ct.greenOffset = level * 2.55;
					ct.blueOffset = level * 2.55;
					tool.transform.colorTransform = ct;
					tool.alpha = on ? 1 : 0.92;
				};
				i++;
			};
		}

		protected function handleFreezeChord():void
		{
			var ctrl:*;
			var status:*;
			var chordDown:Boolean;
			var pid:int;
			if (uiKeysFrozen)
			{
				freezeChordWasDown = false;
				return;
			};
			if (!Ssf2.GameController.stageData)
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
			chordDown = status.TAUNT && status.GRAB;
			if (chordDown && !freezeChordWasDown)
			{
				setCharacterFrozen(!characterFrozen);
			};
			freezeChordWasDown = chordDown;
		}

		protected function mixArrays(array1:Array, array2:Array):Array
		{
			var combined:Array = (array1 ? array1 : []).concat(array2 ? array2 : []);
			var mixed:Array = [];
			var value:*;
			var color:uint;
			var exists:Boolean;
			var existing:*;
			for each (value in combined)
			{
				color = PaletteMakerUtils.coerceColorValue(value);
				exists = false;
				for each (existing in mixed)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(existing), color))
					{
						exists = true;
						break;
					};
				};
				if (!exists)
				{
					mixed.push(color);
				};
			};
			return mixed;
		}

		protected function colorExistsInBasePalette(colorValue:*):Boolean
		{
			var existing:*;
			var color:uint = PaletteMakerUtils.coerceColorValue(colorValue);
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

		/** Force a usable alpha on palette replacements, then nudge pure W/B off extremes. */
		protected function normalizePaletteReplacement(color:uint, fallbackBase:uint):uint
		{
			var a:uint = (color >> 24) & 0xFF;
			var normalized:uint;
			if (a != 0)
			{
				normalized = color;
			}
			else
			{
				a = (fallbackBase >> 24) & 0xFF;
				if (a == 0)
				{
					a = 0xFF;
				};
				normalized = (a << 24) | (color & 0x00FFFFFF);
			};
			return PaletteMakerUtils.nudgeReplacementIfExtreme(normalized, fallbackBase);
		}

		protected function notifyFlashSafeNudgeIfNeeded(nudgeCount:int):void
		{
			if (nudgeCount > 0)
			{
				Ssf2.MultiplayerManager.notify("FYI: fixed " + nudgeCount
					+ " pure black/white replacements for flash safety");
			};
		}

		/** Keep a single exact-ARGB entry for target with writeRepl; drop later duplicates. */
		protected function collapseExactPaletteKeys(oldArr:Array, newArr:Array, target:uint, writeRepl:uint):void
		{
			var i:int;
			var kept:int;
			if (!oldArr || !newArr)
			{
				return;
			};
			kept = -1;
			i = 0;
			while (i < oldArr.length)
			{
				if (uint(oldArr[i]) != target)
				{
					i++;
					continue;
				};
				if (kept < 0)
				{
					kept = i;
					while (newArr.length <= i)
					{
						newArr.push(uint(oldArr[newArr.length]));
					};
					newArr[i] = writeRepl;
					i++;
					continue;
				};
				oldArr.splice(i, 1);
				if (i < newArr.length)
				{
					newArr.splice(i, 1);
				};
			};
		}

		/** Discord Rich Presence while editing in Palette Maker (not Training). */
		protected function pushPaletteMakerDiscordPresence():void
		{
			var displayName:String;
			var largeText:String;
			var charId:String;
			if (!sessionActive)
			{
				return;
			};
			charId = statsName ? String(statsName) : "character";
			displayName = charId;
			try
			{
				if (statsName && Ssf2.Stats.getStats(statsName))
				{
					displayName = String(Ssf2.Stats.getStats(statsName).DisplayName);
				};
			}
			catch (nameErr:Error)
			{
			};
			largeText = displayName;
			if (m_subMenu && m_subMenu.slotName && String(m_subMenu.slotName.text).length > 0)
			{
				largeText = displayName + " — " + String(m_subMenu.slotName.text);
			};
			Ssf2.MenuController.updateDiscordPresence(
				"Editing " + displayName,
				"Palette Maker",
				Ssf2.MenuController.getCurrentTimestamp(),
				0,
				charId,
				largeText,
				"vault",
				"Palette Maker",
				null, 0, 0, null, null
			);
		}

		/** Rest area stage script requires a valid allstar_mode_match_count (waterbit/tod frames). */
		protected function ensureRestAreaGlobals():void
		{
			var frame:int = 7;
			if (restAreaTodIndex >= 0 && restAreaTodIndex < REST_AREA_TOD_FRAMES.length)
			{
				frame = int(REST_AREA_TOD_FRAMES[restAreaTodIndex]);
			};
			if (frame != 1 && frame != 7 && frame != 9 && frame != 11 && frame != 13 && frame != 15 && frame != 17)
			{
				frame = 7;
				restAreaTodIndex = 1;
			};
			Ssf2.SSF2API.setGlobalVar("allstar_mode_match_count", frame);
		}

		/** Stop companion projectiles that retry forever in the rest-area editor (e.g. Chibi Telly). */
		protected function suppressPaletteMakerCompanions(c:*):void
		{
			if (!c || statsName != "chibirobo")
			{
				return;
			};
			try
			{
				if (c.getGlobalVariable("telly"))
				{
					return;
				};
				// Sentinel stops ChibiExt's fireTelly timer condition (!getGlobalVariable("telly")).
				c.setGlobalVariable("telly", true);
				c.setGlobalVariable("telly_timer", true);
			}
			catch (err:Error)
			{
			};
		}

		protected function importFromOnline_CLICK(e:MouseEvent):void
		{
			if (!statsName)
			{
				return;
			};
			Ssf2.MenuController.costumeSelectorDisplay.returnToLocalListOnVaultExit = false;
			Ssf2.MultiplayerManager.notify("Loading Color Vault costumes...");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.unlock("ritual_online_import");
			ColorVaultSync.fetchColorVaultCostumes(statsName,
			{
				"onComplete": onColorVaultFetchComplete,
				"onError": onColorVaultFetchError,
				"onParseError": onColorVaultParseError
			});
		}

		private function onColorVaultFetchComplete(costumes:Array):void
		{
			var displayName:String = statsName;
			try
			{
				displayName = Ssf2.Stats.getStats(statsName).DisplayName;
			}
			catch (err:Error)
			{
			};
			Ssf2.MultiplayerManager.notify("Loaded " + costumes.length + " online costumes for " + displayName);
			Ssf2.MenuController.costumeSelectorDisplay.setOnlineImportCostumes(statsName, costumes);
			Ssf2.MenuController.costumeSelectorDisplay.onCloseMenu = _onCloseMenu;
			freezeKeys(true);
		}

		private function onColorVaultFetchError():void
		{
			Ssf2.MultiplayerManager.notify("No Color Vault file for " + statsName);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
		}

		private function onColorVaultParseError():void
		{
			Ssf2.MultiplayerManager.notify("Color Vault file parse error for " + statsName);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
		}

		/** Single-form stock base (no Zelda/Sheik partner merge). */
		private function getSingleFormBaseCostumeData(charName:String, fallback:Object):Object
		{
			var resolved:Object = null;
			var baseCostume:Object = null;
			var firstNonTeam:Object = null;
			var template:Object = null;
			var ps:Object;
			var psPA:Object;
			try {
				var metadata:Object = Ssf2.ResourceManager.getResourceByID("misc").getProp("metadata");
				var costumeList:Array = (metadata && metadata.costume_data) ? metadata.costume_data[charName] : null;
				if (costumeList && costumeList.length > 0)
				{
					for each (var costume:Object in costumeList)
					{
						if (!costume || costume.team)
						{
							continue;
						};
						if (!firstNonTeam)
						{
							firstNonTeam = costume;
						};
						if (costume.base)
						{
							baseCostume = costume;
							break;
						};
					}
					if (baseCostume)
					{
						// Coded base:true (Mario, Zamus, etc.)
						resolved = baseCostume;
					}
					else if (firstNonTeam || costumeList[0])
					{
						// No coded base (Peach, Fox, Marth…): default is uncoded /
						// No Recolor. Keep palette color keys from an alt, but
						// force identity replacements + identity color transform.
						template = firstNonTeam || costumeList[0];
						resolved = Ssf2.Utils.cloneObject(template);
						if (resolved)
						{
							resolved.base = false;
							if (resolved.hasOwnProperty("team"))
							{
								delete resolved.team;
							};
							ps = resolved.paletteSwap;
							psPA = resolved.paletteSwapPA;
							if (ps && (ps.colors is Array))
							{
								ps.replacements = Ssf2.Utils.cloneObject(ps.colors);
							};
							if (psPA && (psPA.colors is Array))
							{
								psPA.replacements = Ssf2.Utils.cloneObject(psPA.colors);
							};
							resolved = Ssf2.Utils.getCostumeObject({
								paletteSwap: ps,
								paletteSwapPA: psPA,
								profile: resolved.profile
							});
						};
					}
				}
			} catch(err:Error) {
			}
			if (!resolved)
			{
				resolved = fallback;
			};
			if (!resolved)
			{
				resolved = Ssf2.Utils.getCostumeObject({});
			};
			resolved = PaletteMakerUtils.repairCostumeData(Ssf2.Utils.cloneObject(resolved));
			resolved.paletteSwap = normalizePaletteBlock(resolved.paletteSwap);
			resolved.paletteSwapPA = normalizePaletteBlock(resolved.paletteSwapPA);
			return resolved;
		}

		protected function getPaletteMakerBaseCostumeData(charName:String, fallback:Object):Object
		{
			return getSingleFormBaseCostumeData(charName, fallback);
		}

		protected function _onCloseMenu():void
		{
			// Costume locker return — do not clear character freeze.
			freezeKeys(false);
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
				catch (keepFreezeErr:Error)
				{
				};
				updateStageFreeze();
				refreshFreezeToolVisual();
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
		}

		/**
		 * If a base exists in only one of paletteSwap / paletteSwapPA, append the same
		 * pair to the other block so later paints cannot diverge.
		 */
		protected function mirrorPalettePairAcrossBlocks(baseColor:uint, replacement:uint):void
		{
			var inSwap:Boolean;
			var inPA:Boolean;
			if (!currentPaletteData)
			{
				return;
			};
			inSwap = paletteBlockHasColor(currentPaletteData.paletteSwap, baseColor);
			inPA = paletteBlockHasColor(currentPaletteData.paletteSwapPA, baseColor);
			if (inSwap && !inPA)
			{
				appendExactPair(currentPaletteData.paletteSwapPA, baseColor, replacement);
			}
			else if (inPA && !inSwap)
			{
				appendExactPair(currentPaletteData.paletteSwap, baseColor, replacement);
			};
		}

		protected function saveCostume_CLICK(e:MouseEvent):void
		{
			var costumeName:String;
			var displayName:String;
			var toSave:Object;
			var author:String;
			var flashCycle:Boolean;
			costumeName = (m_subMenu && m_subMenu.slotName) ? String(m_subMenu.slotName.text || "") : "";
			costumeName = PaletteMakerUtils.trimString(costumeName);
			if (!costumeName)
			{
				Ssf2.MultiplayerManager.notify("Rename costume before saving");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				PaletteMakerAchievements.unlock("secret_save_blank_name");
				return;
			};
			try
			{
				var saveBoth:Boolean = false;
				toSave = Ssf2.Utils.cloneObject(currentPaletteData);
				applySelectedMcNameToCostumeData(toSave);
				var isNewCostume:Boolean = !PaletteMakerUtils.costumeProfileExists(statsName, costumeName);
				if (e && e.shiftKey && PaletteMakerUtils.isFormLinked(statsName))
				{
					saveBoth = true;
				};
				PaletteMakerUtils.saveCostume(statsName, costumeName, toSave, getAuthorNameText(), false, saveBoth);
				// Keep live editor data in sync with what was written.
				applySelectedMcNameToCostumeData(currentPaletteData);
				author = getAuthorNameText();
				displayName = PaletteMakerUtils.formatCostumeDisplayName(costumeName, author);
				Ssf2.MultiplayerManager.notify(displayName + (saveBoth ? " saved to both forms" : " saved"));
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				flashCycle = PaletteMakerAchievements.hasFlashCycle(currentPaletteData);
				PaletteMakerAchievements.track("costume_saved", {
					"statsName": statsName,
					"costumeName": costumeName,
					"author": author,
					"flashCycle": flashCycle,
					"isNew": isNewCostume
				});
				if (flashCycle)
				{
					PaletteMakerAchievements.track("palette_flash_cycle");
				};
			}
			catch (err:Error)
			{
				Ssf2.MultiplayerManager.notify("Save failed");
				trace("[Palette Maker] Save failed:", err.message);
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		protected function exportCostume_CLICK(e:MouseEvent):void
		{
			var costumeName:String = m_subMenu.slotName.text;
			var toExport:Object;
			if (!costumeName || costumeName.length == 0)
			{
				costumeName = "Custom Costume";
			};
			toExport = Ssf2.Utils.cloneObject(currentPaletteData);
			applySelectedMcNameToCostumeData(toExport);
			CostumePackIO.copyCostumeToClipboard(costumeName, toExport, getAuthorNameText(), statsName);
			Ssf2.MultiplayerManager.notify(PaletteMakerUtils.formatCostumeDisplayName(costumeName, getAuthorNameText()) + " code copied to clipboard");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.unlock("ritual_clipboard_export");
		}

		protected function closeImportCodePastePopup():void
		{
			if (importCodePastePopup)
			{
				importCodePastePopup.hide();
			};
		}

		protected function getAuthorNameText():String
		{
			try
			{
				if (m_subMenu && m_subMenu.authorName)
				{
					return String(m_subMenu.authorName.text || "");
				};
			}
			catch (err:Error)
			{
			};
			return "";
		}

		protected function setAuthorNameText(value:String):void
		{
			try
			{
				if (m_subMenu && m_subMenu.authorName)
				{
					m_subMenu.authorName.text = value ? value : "";
				};
			}
			catch (err:Error)
			{
			};
		}

		/**
		 * For match-all: append missing exact ARGB palette keys that soft-match
		 * (same RGB, any alpha) an existing group member. Does not expand membership
		 * with unrelated unique-cover colors.
		 * Returns how many new exact keys were appended.
		 */
		protected function ensureMatchAllExactKeysForGroupMembers(group:PaletteGroupSquare):int
		{
			var coverColors:Array;
			var cover:uint;
			var member:uint;
			var matched:Boolean;
			var ensured:int;
			if (!group || !group.memberColors || group.memberColors.length == 0)
			{
				return 0;
			};
			if (!currentPaletteData)
			{
				return 0;
			};
			ensurePaletteBlocks(currentPaletteData);
			coverColors = collectAllUniqueCoverColors();
			if (!coverColors || coverColors.length == 0)
			{
				return 0;
			};
			ensured = 0;
			for each (cover in coverColors)
			{
				matched = false;
				for each (member in group.memberColors)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(cover), uint(member)))
					{
						matched = true;
						break;
					};
				};
				if (!matched)
				{
					continue;
				};
				if (appendExactPair(currentPaletteData.paletteSwap, uint(cover), uint(cover)))
				{
					ensured++;
				};
				if (currentPaletteData.paletteSwapPA)
				{
					appendExactPair(currentPaletteData.paletteSwapPA, uint(cover), uint(cover));
				};
			};
			return ensured;
		}

		protected function onCsTextFocusChange(focused:Boolean):void
		{
			if (focused)
			{
				editingTextStart(null);
			}
			else
			{
				editingTextEnd(null);
			};
		}

		protected function refreshAllSwatchTriangles():void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare && !(child is PaletteGroupSquare))
				{
					box = child as ColorSquare;
					box.updateIndicator(getCurrentReplacementForColor(uint(box.colorValue)));
				};
				i++;
			};
			refreshUnchangedHighlights();
		}

		protected function loadToolSettings():void
		{
			var so:SharedObject;
			if (settingsLoaded)
			{
				DiscordCostumePresence.setEnabled(settingDiscordCostumePreview);
				PaletteMakerUtils.ensureCssNoRecolorSettingLoaded();
				return;
			};
			settingsLoaded = true;
			try
			{
				so = SharedObject.getLocal("ssf2_palette_maker_settings");
				if (so && so.data)
				{
					migrateColorGroupsSchema(so);
					settingAlwaysIsolate = so.data.alwaysIsolate == true;
					settingShowUniquePaSprites = true;
					settingHighlightUnchanged = so.data.highlightUnchanged == true;
					settingUnchangedVsOriginal = so.data.unchangedVsOriginal == true;
					if (so.data.hasOwnProperty("dontAutoGenerateColorGroups"))
					{
						settingDontAutoGenerateColorGroups = so.data.dontAutoGenerateColorGroups == true;
					};
					settingSortByOriginalColor = so.data.sortByOriginalColor == true;
					if (so.data.hasOwnProperty("discordCostumePreview"))
					{
						settingDiscordCostumePreview = so.data.discordCostumePreview != false;
					}
					else
					{
						settingDiscordCostumePreview = true;
					};
					DiscordCostumePresence.setEnabled(settingDiscordCostumePreview);
					settingDebugPaletteMaker = so.data.debugPaletteMaker == true;
					settingSelectHighlight = so.data.selectHighlight == true;
					if (so.data.hasOwnProperty("selectHighlightPrimary") && (so.data.selectHighlightPrimary is Number))
					{
						settingSelectHighlightPrimary = uint(so.data.selectHighlightPrimary) | 0xFF000000;
					};
					if (so.data.hasOwnProperty("selectHighlightAlt") && (so.data.selectHighlightAlt is Number))
					{
						settingSelectHighlightAlt = uint(so.data.selectHighlightAlt) | 0xFF000000;
					};
					if (so.data.hasOwnProperty("cssShowNoRecolorWhenNoBase"))
					{
						PaletteMakerUtils.setCssShowNoRecolorWhenNoBase(so.data.cssShowNoRecolorWhenNoBase != false);
					}
					else
					{
						PaletteMakerUtils.ensureCssNoRecolorSettingLoaded();
					};
					if (so.data.hasOwnProperty("restAreaTodIndex") && (so.data.restAreaTodIndex is Number))
					{
						settingRestAreaTodIndex = int(so.data.restAreaTodIndex);
						if (settingRestAreaTodIndex < 0 || settingRestAreaTodIndex >= REST_AREA_TOD_FRAMES.length)
						{
							settingRestAreaTodIndex = 1;
						};
					};
					if (so.data.hasOwnProperty("restAreaMusicIndex") && (so.data.restAreaMusicIndex is Number))
					{
						settingRestAreaMusicIndex = int(so.data.restAreaMusicIndex);
						if (settingRestAreaMusicIndex < 0 || settingRestAreaMusicIndex >= REST_AREA_MUSIC.length)
						{
							settingRestAreaMusicIndex = -1;
						};
					};
				};
			}
			catch (err:Error)
			{
			};
			DiscordCostumePresence.setEnabled(settingDiscordCostumePreview);
		}

		protected function saveToolSettings():void
		{
			var so:SharedObject;
			try
			{
				so = SharedObject.getLocal("ssf2_palette_maker_settings");
				so.data.alwaysIsolate = settingAlwaysIsolate;
				so.data.uniquePaSprites = true;
				so.data.highlightUnchanged = settingHighlightUnchanged;
				so.data.unchangedVsOriginal = settingUnchangedVsOriginal;
				so.data.dontAutoGenerateColorGroups = settingDontAutoGenerateColorGroups;
				so.data.sortByOriginalColor = settingSortByOriginalColor;
				so.data.discordCostumePreview = settingDiscordCostumePreview;
				so.data.debugPaletteMaker = settingDebugPaletteMaker;
				so.data.selectHighlight = settingSelectHighlight;
				so.data.selectHighlightPrimary = settingSelectHighlightPrimary;
				so.data.selectHighlightAlt = settingSelectHighlightAlt;
				so.data.cssShowNoRecolorWhenNoBase = PaletteMakerUtils.cssShowNoRecolorWhenNoBase;
				so.data.restAreaTodIndex = settingRestAreaTodIndex;
				so.data.restAreaMusicIndex = settingRestAreaMusicIndex;
				so.flush();
			}
			catch (err:Error)
			{
			};
		}

		protected function isToolSettingsVisible():Boolean
		{
			return toolSettingsPopup != null && toolSettingsPopup.visible;
		}

		protected function closeToolSettings():void
		{
			if (toolSettingsPopup)
			{
				toolSettingsPopup.hide();
			};
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onToolSettingsStageDown, true);
			};
		}

		protected function onToolSettingsStageDown(e:MouseEvent):void
		{
			// Full-screen overlays handle their own backdrop dismiss.
			if (shortcutsPopup && shortcutsPopup.visible)
			{
				return;
			};
			if (achievementsPopup && achievementsPopup.visible)
			{
				return;
			};
			if (!isToolSettingsVisible() || !toolSettingsPopup)
			{
				return;
			};
			if (toolSettingsPopup.hitTestPoint(e.stageX, e.stageY, true))
			{
				return;
			};
			closeToolSettings();
			PaletteMakerAchievements.unlock("flavor_close_settings_clickout");
		}

		protected function refreshToolSettingsToggles():void
		{
			if (toolSettingsPopup)
			{
				toolSettingsPopup.refreshToggles(settingAlwaysIsolate, settingHighlightUnchanged,
					settingDontAutoGenerateColorGroups, settingSortByOriginalColor, settingUnchangedVsOriginal,
					settingDiscordCostumePreview, settingDebugPaletteMaker, PaletteMakerAchievements.getCookies(),
					settingSelectHighlight, PaletteMakerUtils.cssShowNoRecolorWhenNoBase);
				toolSettingsPopup.setSelectHighlightColors(settingSelectHighlightPrimary, settingSelectHighlightAlt);
			};
		}

		protected function onToggleCssNoRecolorSetting():void
		{
			PaletteMakerUtils.setCssShowNoRecolorWhenNoBase(!PaletteMakerUtils.cssShowNoRecolorWhenNoBase);
			saveToolSettings();
			refreshToolSettingsToggles();
			Ssf2.MultiplayerManager.notify(PaletteMakerUtils.cssShowNoRecolorWhenNoBase
				? "CSS: show No Recolor when character has no base costume"
				: "CSS: hide No Recolor fallback");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		protected function openShortcutsPopup():void
		{
			if (!shortcutsPopup)
			{
				shortcutsPopup = new ShortcutsPopup();
				shortcutsPopup.onClose = closeShortcutsPopup;
			};
			// Full-stage overlay (m_subMenu is only the bottom UI and was cropping the panel).
			if (shortcutsPopup.parent != m_container)
			{
				if (shortcutsPopup.parent)
				{
					shortcutsPopup.parent.removeChild(shortcutsPopup);
				};
				m_container.addChild(shortcutsPopup);
			};
			closeAchievementsPopup();
			shortcutsPopup.showAt(0, 0);
			m_container.setChildIndex(shortcutsPopup, m_container.numChildren - 1);
			PaletteMakerAchievements.unlock("secret_open_shortcuts");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		protected function closeShortcutsPopup():void
		{
			if (shortcutsPopup)
			{
				shortcutsPopup.hide();
			};
		}

		protected function openAchievementsPopup():void
		{
			if (!achievementsPopup)
			{
				achievementsPopup = new AchievementsPopup();
				achievementsPopup.onClose = closeAchievementsPopup;
				achievementsPopup.onBuyHint = onBuyAchievementHint;
			};
			if (achievementsPopup.parent != m_container)
			{
				if (achievementsPopup.parent)
				{
					achievementsPopup.parent.removeChild(achievementsPopup);
				};
				m_container.addChild(achievementsPopup);
			};
			closeShortcutsPopup();
			achievementsPopup.showAt(0, 0);
			m_container.setChildIndex(achievementsPopup, m_container.numChildren - 1);
			PaletteMakerAchievements.track("achievements_opened");
			PaletteMakerAchievements.unlock("secret_achievements_cookie_label");
			if (PaletteMakerAchievements.getCookies() == 0)
			{
				PaletteMakerAchievements.unlock("secret_zero_cookie_hint");
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			refreshToolSettingsToggles();
		}

		protected function closeAchievementsPopup():void
		{
			if (achievementsPopup)
			{
				achievementsPopup.hide();
			};
			refreshToolSettingsToggles();
		}

		private function onBuyAchievementHint(id:String):void
		{
			var before:int = PaletteMakerAchievements.getCookies();
			var cost:int;
			var catalog:Array;
			var def:Object;
			var i:int;
			catalog = PaletteMakerAchievements.getCatalog();
			i = 0;
			while (i < catalog.length)
			{
				def = catalog[i];
				if (def && String(def.id) == id)
				{
					cost = int(def.cookieHintCost);
					break;
				};
				i++;
			};
			if (PaletteMakerAchievements.buyHint(id))
			{
				if (cost >= 20)
				{
					PaletteMakerAchievements.unlock("secret_hint_hard");
				};
				if (before > 0 && PaletteMakerAchievements.getCookies() == 0)
				{
					PaletteMakerAchievements.unlock("secret_spend_last_cookie");
					PaletteMakerAchievements.unlock("secret_cookie_broke");
				};
				if (achievementsPopup)
				{
					achievementsPopup.refresh();
				};
				refreshToolSettingsToggles();
			};
		}

		protected function onToggleDiscordCostumePreviewSetting():void
		{
			settingDiscordCostumePreview = !settingDiscordCostumePreview;
			DiscordCostumePresence.setEnabled(settingDiscordCostumePreview);
			saveToolSettings();
			refreshToolSettingsToggles();
			Ssf2.MultiplayerManager.notify(settingDiscordCostumePreview ? "Discord costume preview on" : "Discord costume preview off");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			if (settingDiscordCostumePreview)
			{
				PaletteMakerAchievements.unlock("ritual_match_preview");
			};
		}

		protected function onExportColorGroupsSetting():void
		{
			var so:SharedObject;
			var groups:Object;
			var path:String;
			var count:int;
			var key:String;
			saveColorGroups();
			groups = {};
			count = 0;
			try
			{
				so = SharedObject.getLocal("ssf2_palette_maker_settings");
				if (so && so.data && so.data.colorGroups)
				{
					groups = so.data.colorGroups;
				};
			}
			catch (err:Error)
			{
			};
			for (key in groups)
			{
				if (groups[key] is Array)
				{
					count++;
				};
			};
			path = CostumePackIO.exportAllColorGroupsToFile(groups);
			if (path)
			{
				Ssf2.MultiplayerManager.notify("Exported color groups (" + count + " chars)\n" + path);
				Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
				PaletteMakerAchievements.unlock("group_export_json");
			}
			else
			{
				Ssf2.MultiplayerManager.notify("Color groups export failed");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
			};
		}

		protected function ensurePauseToys():void
		{
			if (pauseToys)
			{
				return;
			};
			pauseToys = new PauseScreenshotToys(Ssf2.Main.Width, Ssf2.Main.Height);
			pauseToys.onToggleHideArt = onPauseToggleHideArt;
			m_container.addChild(pauseToys);
		}

		protected function onPauseToggleHideArt(hidden:Boolean):void
		{
			pauseArtHidden = hidden;
			try
			{
				if (PAContainer)
				{
					PAContainer.visible = !hidden;
				};
			}
			catch (paErr:Error)
			{
			};
			syncUniquePaHostVisibility();
		}

		/**
		 * Unique sprites: hidden with PM UI; visible when UI shown or on pause
		 * (unless pause "hide art" is on).
		 */
		protected function syncUniquePaHostVisibility():void
		{
			var paused:Boolean;
			paused = Boolean(Ssf2.GameController.stageData && Ssf2.GameController.stageData.Paused);
			if (uniquePaHost)
			{
				if (pauseArtHidden)
				{
					uniquePaHost.visible = false;
				}
				else if (paused)
				{
					uniquePaHost.visible = true;
				}
				else
				{
					uniquePaHost.visible = !uiHidden;
				};
			};
		}

		protected function destroyPauseToys():void
		{
			if (!pauseToys)
			{
				return;
			};
			pauseToys.onToggleHideArt = null;
			onPauseToggleHideArt(false);
			pauseToys.destroy();
			if (pauseToys.parent)
			{
				pauseToys.parent.removeChild(pauseToys);
			};
			pauseToys = null;
		}

		protected function onPaletteMakerBeforeSnapshot():void
		{
			snapshotUiWasVisible = m_subMenu ? m_subMenu.visible : false;
			if (m_subMenu)
			{
				m_subMenu.visible = false;
			};
			if (showUiButton) showUiButton.visible = false;
			if (changeTodButton) changeTodButton.visible = false;
			if (changeMusicButton) changeMusicButton.visible = false;
			if (pauseToys)
			{
				pauseToys.prepareForSnapshot();
			};
			try
			{
				var hudMenu:* = Ssf2.GameController.hud;
				if (hudMenu && hudMenu.SubMenu)
				{
					if (hudMenu.SubMenu.pause_menu) hudMenu.SubMenu.pause_menu.visible = false;
					if (hudMenu.SubMenu.camIcon) hudMenu.SubMenu.camIcon.visible = false;
				};
			}
			catch (err:Error)
			{
			};
		}

		protected function cycleRestAreaMusic():void
		{
			var nextId:String;
			var needsLoad:Boolean;
			restAreaMusicIndex = (restAreaMusicIndex + 1) % REST_AREA_MUSIC.length;
			nextId = String(REST_AREA_MUSIC[restAreaMusicIndex]);
			if (m_game && m_game.LevelData)
			{
				m_game.LevelData.musicOverride = nextId;
			};
			needsLoad = false;
			try
			{
				needsLoad = (Ssf2.ResourceManager.getResourceByID(nextId, true) == null) || (Ssf2.ResourceManager.getLibrarySound(nextId) == null);
			}
			catch (loadErr:Error)
			{
				needsLoad = true;
			};
			if (needsLoad)
			{
				Ssf2.ResourceManager.queueResources([nextId]);
				Ssf2.ResourceManager.load({
					"oncomplete": function(e:*=null):void
					{
						playRestAreaMusic(nextId);
						saveRestAreaAmbienceSettings();
					}
				});
				Ssf2.MultiplayerManager.notify("Loading " + nextId + "...");
				return;
			};
			playRestAreaMusic(nextId);
			saveRestAreaAmbienceSettings();
		}

		private function saveRestAreaAmbienceSettings():void
		{
			settingRestAreaTodIndex = restAreaTodIndex;
			settingRestAreaMusicIndex = restAreaMusicIndex;
			saveToolSettings();
		}

		private function playRestAreaMusic(songId:String):void
		{
			var musicResource:Object;
			var id3:Object;
			var songName:String;
			try
			{
				if (Ssf2.GameController.stageData && Ssf2.GameController.stageData.SoundQueueRef)
				{
					Ssf2.GameController.stageData.SoundQueueRef.playMusic(songId, 0);
				}
				else
				{
					Ssf2.SoundQueue.instance.playMusic(songId, 0);
				};
			}
			catch (err:Error)
			{
				trace("[Palette Maker] Music change failed:", err.message);
				Ssf2.MultiplayerManager.notify("Music load failed");
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
				return;
			};
			songName = songId;
			try
			{
				musicResource = Ssf2.ResourceManager.getResourceByID(songId, true);
				if (musicResource && musicResource.getProp("id3"))
				{
					id3 = musicResource.getProp("id3");
					if (id3 && id3.songName)
					{
						songName = String(id3.songName);
					};
				};
			}
			catch (id3Err:Error)
			{
			};
			try
			{
				if (Ssf2.GameController.hud)
				{
					Ssf2.GameController.hud.displayMusicInfo(songName);
				};
			}
			catch (hudErr:Error)
			{
				trace("[Palette Maker] Music HUD failed:", hudErr.message);
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		protected function cycleRestAreaTimeOfDay():void
		{
			restAreaTodIndex = (restAreaTodIndex + 1) % REST_AREA_TOD_FRAMES.length;
			applyRestAreaTimeOfDay(int(REST_AREA_TOD_FRAMES[restAreaTodIndex]));
			saveRestAreaAmbienceSettings();
			Ssf2.MultiplayerManager.notify("Time of day: " + REST_AREA_TOD_NAMES[restAreaTodIndex]);
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		/** Re-apply rest area sky/lighting for the given allstar_mode_match_count frame. */
		protected function applyRestAreaTimeOfDay(matchCount:int):void
		{
			var stageApi:*;
			var bg:MovieClip;
			var fg:MovieClip;
			var mg:MovieClip;
			var camBgs:Array;
			var tintMidground:ColorTransform;
			var tintWhite:ColorTransform;
			var tintWater:ColorTransform;
			var imageClass:Class;
			var bitDataEdit:BitmapData;
			var bitmap:Bitmap;
			var thingy:MovieClip;
			Ssf2.SSF2API.setGlobalVar("allstar_mode_match_count", matchCount);
			try
			{
				if (!Ssf2.GameController.stageData || !Ssf2.GameController.stageData.APIInstance)
				{
					return;
				};
				stageApi = Ssf2.GameController.stageData.APIInstance;
				bg = stageApi.getBackground();
				fg = stageApi.getForeground();
				mg = stageApi.getMidground();
				camBgs = stageApi.getCameraBackgrounds();
				if (camBgs && camBgs.length > 0 && camBgs[0] && camBgs[0].mc)
				{
					MovieClip(camBgs[0].mc).gotoAndStop(matchCount);
				};
				if (bg)
				{
					if (bg.trophies) bg.trophies.gotoAndStop(matchCount);
					if (bg.bgs) bg.bgs.gotoAndStop(matchCount);
				};
				if (fg)
				{
					if (fg.trophies) fg.trophies.gotoAndStop(matchCount);
					if (fg.fgs) fg.fgs.gotoAndStop(matchCount);
				};
				tintMidground = new ColorTransform();
				tintWhite = new ColorTransform();
				tintWater = new ColorTransform();
				if (matchCount == 1)
				{
					tintMidground.redOffset = -45;
					tintMidground.greenOffset = -25;
					tintMidground.blueOffset = -10;
					tintWhite.redOffset = -60;
					tintWhite.greenOffset = -40;
					tintWhite.blueOffset = -20;
				}
				else if (matchCount == 7)
				{
					tintWater.redOffset = 40;
					tintWater.greenOffset = 40;
				}
				else if (matchCount == 9)
				{
					tintMidground.greenOffset = -10;
					tintMidground.blueOffset = -25;
					tintWhite.greenOffset = -10;
					tintWhite.blueOffset = -40;
					tintWater.redOffset = 70;
					tintWater.greenOffset = 70;
				}
				else if (matchCount == 11)
				{
					tintMidground.redOffset = -15;
					tintMidground.greenOffset = -55;
					tintMidground.blueOffset = -40;
					tintWhite.greenOffset = -55;
					tintWhite.blueOffset = -70;
					tintWater.redOffset = 180;
					tintWater.greenOffset = 70;
				}
				else if (matchCount == 13)
				{
					tintMidground.redMultiplier = 0.8;
					tintMidground.greenMultiplier = 0.8;
					tintMidground.blueMultiplier = 0.8;
					tintMidground.redOffset = -85;
					tintMidground.greenOffset = -45;
					tintWhite.redMultiplier = 0.5;
					tintWhite.greenMultiplier = 0.6;
					tintWhite.blueMultiplier = 0.7;
				}
				else if (matchCount == 15)
				{
					tintMidground.redOffset = -100;
					tintMidground.greenOffset = -60;
					tintWhite.redMultiplier = 0.5;
					tintWhite.greenMultiplier = 0.75;
					tintWhite.blueMultiplier = 0.9;
				}
				else if (matchCount == 17)
				{
					tintMidground.redOffset = -50;
					tintMidground.greenOffset = -50;
					tintWhite.redMultiplier = 0.8;
					tintWhite.greenMultiplier = 0.7;
					tintWhite.blueMultiplier = 0.8;
					tintWater.redOffset = 100;
					tintWater.greenOffset = -50;
				};
				if (mg)
				{
					mg.transform.colorTransform = tintMidground;
				};
				if (bg)
				{
					if (bg.trophies) bg.trophies.transform.colorTransform = tintMidground;
					if (bg.waterfalls) bg.waterfalls.transform.colorTransform = tintWater;
					if (bg.waterlights) bg.waterlights.transform.colorTransform = tintWhite;
					if (bg.mist) bg.mist.transform.colorTransform = tintWhite;
					thingy = bg.thingy as MovieClip;
					if (thingy)
					{
						try
						{
							var stageScript:* = stageApi.instance;
							if (stageScript)
							{
								stageScript.setWaterTimeOfDay(matchCount);
							}
							else
							{
								imageClass = getDefinitionByName("waterbit" + matchCount.toString()) as Class;
								bitDataEdit = new imageClass() as BitmapData;
								bitmap = new Bitmap(bitDataEdit);
								while (thingy.numChildren > 0)
								{
									thingy.removeChildAt(0);
								};
								thingy.addChild(bitmap);
							};
						}
						catch (syncErr:Error)
						{
							try
							{
								imageClass = getDefinitionByName("waterbit" + matchCount.toString()) as Class;
								bitDataEdit = new imageClass() as BitmapData;
								bitmap = new Bitmap(bitDataEdit);
								while (thingy.numChildren > 0)
								{
									thingy.removeChildAt(0);
								};
								thingy.addChild(bitmap);
							}
							catch (fallbackErr:Error)
							{
							};
						};
					};
				};
				if (fg && fg.trophies)
				{
					fg.trophies.transform.colorTransform = tintMidground;
				};
			}
			catch (todErr:Error)
			{
				trace("[Palette Maker] Time of day apply failed:", todErr.message);
			};
		}

		protected function onToggleHighlightUnchangedSetting():void
		{
			if (!settingHighlightUnchanged)
			{
				settingHighlightUnchanged = true;
				settingUnchangedVsOriginal = false;
				Ssf2.MultiplayerManager.notify("Unchanged highlight: vs loaded costume");
			}
			else if (!settingUnchangedVsOriginal)
			{
				settingUnchangedVsOriginal = true;
				Ssf2.MultiplayerManager.notify("Unchanged highlight: vs original colors");
			}
			else
			{
				settingHighlightUnchanged = false;
				settingUnchangedVsOriginal = false;
				Ssf2.MultiplayerManager.notify("Unchanged highlight off");
			};
			saveToolSettings();
			refreshToolSettingsToggles();
			refreshUnchangedHighlights();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			PaletteMakerAchievements.track("highlight_unchanged", { "on": settingHighlightUnchanged });
			if (settingHighlightUnchanged && settingUnchangedVsOriginal)
			{
				PaletteMakerAchievements.unlock("flavor_compare_original");
			}
			else if (settingHighlightUnchanged)
			{
				PaletteMakerAchievements.unlock("flavor_compare_loaded");
			};
		}

		protected function refreshUnchangedHighlights():void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var group:PaletteGroupSquare;
			var color:uint;
			var unchanged:Boolean;
			var anyUnchanged:Boolean;
			if (!m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			if (!settingHighlightUnchanged && unchangedHighlightsCleared)
			{
				unchangedHighlightsDirty = false;
				return;
			};
			rebuildUnchangedColorLookup();
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is PaletteGroupSquare)
				{
					group = child as PaletteGroupSquare;
					anyUnchanged = false;
					if (settingHighlightUnchanged)
					{
						for each (color in group.memberColors)
						{
							if (isReplacementUnchanged(uint(color)))
							{
								anyUnchanged = true;
								break;
							};
						};
					};
					group.setUnchangedHighlight(anyUnchanged);
				}
				else if (child is ColorSquare)
				{
					box = child as ColorSquare;
					unchanged = settingHighlightUnchanged && isReplacementUnchanged(uint(box.colorValue));
					box.setUnchangedHighlight(unchanged);
				};
				i++;
			};
			if (!pulseActive)
			{
				refreshArtUnchangedOutlines();
			};
			unchangedHighlightsCleared = !settingHighlightUnchanged;
			unchangedHighlightsDirty = false;
		}

		/** Yellow silhouette for unchanged art; red on unique sprites that contain a selected unchanged swatch. */
		protected function refreshArtUnchangedOutlines():void
		{
			var unchangedLookup:Object;
			var selectedUnchanged:Object;
			var baseColor:uint;
			var disp:DisplayObject;
			var hasUnchanged:Boolean;
			var box:ColorSquare;
			var tint:uint;
			if (unchangedHighlightsDirty)
			{
				rebuildUnchangedColorLookup();
			};
			if (!settingHighlightUnchanged)
			{
				setDisplayUnchangedOutline(PixelArt, false);
				if (uniquePaSprites)
				{
					for each (disp in uniquePaSprites)
					{
						setDisplayUnchangedOutline(disp, false);
					};
				};
				return;
			};
			unchangedLookup = unchangedColorLookup;
			selectedUnchanged = {};
			hasUnchanged = hasAnyKey(unchangedLookup);
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				baseColor = uint(box.colorValue);
				if (unchangedLookup[String(baseColor)])
				{
					selectedUnchanged[String(baseColor)] = true;
				};
			};
			// Portrait stays yellow for any unchanged palette colors.
			setDisplayUnchangedOutline(PixelArt, hasUnchanged, 0xFFFFDD00);
			if (uniquePaSprites)
			{
				for each (disp in uniquePaSprites)
				{
					tint = hasUnchanged
						? getDisplayUnchangedOutlineTint(disp, selectedUnchanged, unchangedLookup)
						: 0;
					setDisplayUnchangedOutline(disp, tint != 0, tint);
				};
			};
		}

		/** One cached membership pass: red beats yellow when a selected unchanged base is present. */
		private function getDisplayUnchangedOutlineTint(root:DisplayObject, selected:Object, unchanged:Object):uint
		{
			var bases:Array;
			var color:uint;
			var yellow:Boolean = false;
			if (!root || !unchanged)
			{
				return 0;
			};
			bases = getCachedDisplayBaseColors(root);
			if (!bases || bases.length == 0)
			{
				return 0;
			};
			for each (color in bases)
			{
				if (selected && selected[String(uint(color))])
				{
					return 0xFFFF3333;
				};
				if (unchanged[String(uint(color))])
				{
					yellow = true;
				};
			};
			return yellow ? 0xFFFFDD00 : 0;
		}

		private function getCachedDisplayBaseColors(root:DisplayObject):Array
		{
			var cached:*;
			var bitmaps:Array;
			var bmp:Bitmap;
			var bd:BitmapData;
			var colors:Array;
			var color:uint;
			var baseColor:uint;
			var out:Array;
			var seen:Object;
			var bitmapRgb:Object;
			if (!root)
			{
				return [];
			};
			cached = displayBaseColorCache[root];
			if (cached is Array)
			{
				return cached as Array;
			};
			out = [];
			seen = {};
			bitmapRgb = {};
			bitmaps = [];
			if (root is Bitmap)
			{
				bitmaps.push(root);
			}
			else if (root is MovieClip)
			{
				PaletteColorAnalysis.collectBitmapsLikeReplacePalette(root as MovieClip, bitmaps, 2);
			}
			else if (root is DisplayObjectContainer)
			{
				collectBitmapsShallow(root as DisplayObjectContainer, bitmaps, 3);
			};
			for each (bmp in bitmaps)
			{
				if (!(bmp is Bitmap))
				{
					continue;
				};
				bd = (bmp as Bitmap).bitmapData;
				if (!bd)
				{
					continue;
				};
				colors = PaletteColorAnalysis.collectOpaqueColorsInBitmapData(bd, 1);
				for each (color in colors)
				{
					color = uint(color);
					bitmapRgb[String(color & 0x00FFFFFF)] = true;
				};
			};
			if (mixedBasePaletteData)
			{
				for each (baseColor in mixedBasePaletteData)
				{
					baseColor = uint(baseColor);
					if (!seen[baseColor] && bitmapRgb[String(baseColor & 0x00FFFFFF)])
					{
						seen[baseColor] = true;
						out.push(baseColor);
					};
				};
			};
			displayBaseColorCache[root] = out;
			return out;
		}

		private function collectBitmapsShallow(node:DisplayObjectContainer, out:Array, depth:int):void
		{
			var i:int;
			var child:DisplayObject;
			if (!node || depth < 0)
			{
				return;
			};
			i = 0;
			while (i < node.numChildren)
			{
				child = node.getChildAt(i);
				if (child is Bitmap)
				{
					out.push(child);
				}
				else if (child is DisplayObjectContainer)
				{
					collectBitmapsShallow(child as DisplayObjectContainer, out, depth - 1);
				};
				i++;
			};
		}

		/**
		 * Silhouette around opaque pixel edges (not a bounding box).
		 * Outline BitmapData is cached per source BitmapData (white); tinted via ColorTransform.
		 */
		private function setDisplayUnchangedOutline(target:DisplayObject, on:Boolean, tint:uint=0xFFFFDD00):void
		{
			var bmp:Bitmap;
			var host:DisplayObjectContainer;
			var outline:Bitmap;
			var outlineBd:BitmapData;
			var idx:int;
			var ct:ColorTransform;
			if (!target)
			{
				return;
			};
			if (on && uint(unchangedOutlineState[target]) == tint)
			{
				return;
			};
			if (!on && uint(unchangedOutlineState[target]) == 0)
			{
				return;
			};
			bmp = findFirstBitmapInDisplay(target);
			if (!bmp || !bmp.bitmapData || !bmp.parent)
			{
				clearNamedOutline(target);
				unchangedOutlineState[target] = 0;
				return;
			};
			host = bmp.parent;
			outline = host.getChildByName("_unchangedOutline") as Bitmap;
			if (!on)
			{
				if (outline && outline.parent)
				{
					outline.parent.removeChild(outline);
				};
				unchangedOutlineState[target] = 0;
				return;
			};
			outlineBd = unchangedOutlineBdCache[bmp.bitmapData] as BitmapData;
			if (!outlineBd)
			{
				outlineBd = buildOpaqueEdgeOutline(bmp.bitmapData);
				if (!outlineBd)
				{
					return;
				};
				unchangedOutlineBdCache[bmp.bitmapData] = outlineBd;
			};
			if (!outline)
			{
				outline = new Bitmap(outlineBd);
				outline.name = "_unchangedOutline";
				outline.smoothing = false;
				host.addChild(outline);
			}
			else
			{
				outline.bitmapData = outlineBd;
			};
			outline.x = bmp.x;
			outline.y = bmp.y;
			outline.scaleX = bmp.scaleX;
			outline.scaleY = bmp.scaleY;
			outline.rotation = bmp.rotation;
			outline.visible = true;
			// White silhouette → tint to yellow / red / etc.
			ct = new ColorTransform(0, 0, 0, 1,
				(tint >> 16) & 0xFF,
				(tint >> 8) & 0xFF,
				tint & 0xFF,
				0);
			outline.transform.colorTransform = ct;
			unchangedOutlineState[target] = tint;
			try
			{
				idx = host.getChildIndex(bmp);
				host.setChildIndex(outline, Math.min(idx + 1, host.numChildren - 1));
			}
			catch (err:Error)
			{
			};
		}

		private function clearNamedOutline(target:DisplayObject):void
		{
			var bmp:Bitmap;
			var outline:Bitmap;
			if (!target)
			{
				return;
			};
			bmp = findFirstBitmapInDisplay(target);
			if (bmp && bmp.parent)
			{
				outline = bmp.parent.getChildByName("_unchangedOutline") as Bitmap;
				if (outline && outline.parent)
				{
					outline.parent.removeChild(outline);
				};
			};
		}

		/** Build a white ring on transparent pixels that touch opaque ones (and on opaque edge pixels). */
		private function buildOpaqueEdgeOutline(src:BitmapData):BitmapData
		{
			var w:int;
			var h:int;
			var out:BitmapData;
			var srcVec:Vector.<uint>;
			var outVec:Vector.<uint>;
			var i:int;
			var x:int;
			var y:int;
			var len:int;
			var opaque:Boolean;
			var edge:Boolean;
			var white:uint = 0xFFFFFFFF;
			if (!src)
			{
				return null;
			};
			w = src.width;
			h = src.height;
			if (w < 1 || h < 1)
			{
				return null;
			};
			srcVec = src.getVector(src.rect);
			len = srcVec.length;
			outVec = new Vector.<uint>(len, true);
			i = 0;
			while (i < len)
			{
				opaque = ((srcVec[i] >>> 24) & 0xFF) > 8;
				x = i % w;
				y = int(i / w);
				edge = false;
				if (opaque)
				{
					if (x == 0 || y == 0 || x == w - 1 || y == h - 1)
					{
						edge = true;
					}
					else if (((srcVec[i - 1] >>> 24) & 0xFF) <= 8
						|| ((srcVec[i + 1] >>> 24) & 0xFF) <= 8
						|| ((srcVec[i - w] >>> 24) & 0xFF) <= 8
						|| ((srcVec[i + w] >>> 24) & 0xFF) <= 8)
					{
						edge = true;
					};
				}
				else
				{
					if (x > 0 && ((srcVec[i - 1] >>> 24) & 0xFF) > 8) edge = true;
					else if (x < w - 1 && ((srcVec[i + 1] >>> 24) & 0xFF) > 8) edge = true;
					else if (y > 0 && ((srcVec[i - w] >>> 24) & 0xFF) > 8) edge = true;
					else if (y < h - 1 && ((srcVec[i + w] >>> 24) & 0xFF) > 8) edge = true;
				};
				if (edge)
				{
					outVec[i] = white;
				};
				i++;
			};
			out = new BitmapData(w, h, true, 0x00000000);
			out.setVector(out.rect, outVec);
			return out;
		}

		protected function clearUniquePaSprites():void
		{
			var disp:DisplayObject;
			if (uniquePaSprites)
			{
				for each (disp in uniquePaSprites)
				{
					if (disp && disp.parent)
					{
						disp.parent.removeChild(disp);
					};
				};
			};
			uniquePaSprites = [];
			fxStripLinkageMap = new Dictionary(true);
			fxStripPristineBd = new Dictionary(true);
			uniquePaScrollRow = 0;
			uniquePaRowCount = 0;
			uniquePaFixedTrackH = 24;
			uniquePaRelayoutFrames = 0;
			displayBaseColorCache = new Dictionary(true);
			unchangedOutlineBdCache = new Dictionary(true);
			unchangedOutlineState = new Dictionary(true);
			unchangedHighlightsDirty = true;
			if (uniquePaMask && uniquePaMask.parent)
			{
				uniquePaMask.parent.removeChild(uniquePaMask);
			};
			uniquePaMask = null;
			if (uniquePaContent && uniquePaContent.parent)
			{
				uniquePaContent.parent.removeChild(uniquePaContent);
			};
			uniquePaContent = null;
			if (uniquePaScrollBar && uniquePaScrollBar.parent)
			{
				uniquePaScrollBar.parent.removeChild(uniquePaScrollBar);
			};
			uniquePaScrollBar = null;
			uniquePaScrollThumb = null;
			if (uniquePaHost && uniquePaHost.parent)
			{
				uniquePaHost.parent.removeChild(uniquePaHost);
			};
			uniquePaHost = null;
		}

		/** Local point in m_container just under the palette maker Back button (top-left). */
		protected function getUniqueSpritesTopLeftLocal():Point
		{
			var backBtn:DisplayObject;
			var g:Point;
			var local:Point;
			try
			{
				if (m_subMenu && m_subMenu.bg_top && m_subMenu.bg_top.back_btn)
				{
					backBtn = m_subMenu.bg_top.back_btn as DisplayObject;
					// Tight under Back; nudge further up/left for opaque packing origin.
					g = backBtn.localToGlobal(new Point(UNIQUE_ANCHOR_NUDGE_X, backBtn.height + UNIQUE_ANCHOR_NUDGE_Y));
					local = m_container.globalToLocal(g);
					if (local.x < 2) local.x = 2;
					if (local.y < 2) local.y = 2;
					return local;
				};
			}
			catch (err:Error)
			{
			};
			return new Point(2, 24);
		}

		protected function onMcNameRetryFrame(e:Event):void
		{
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, onMcNameRetryFrame);
			};
			if (selectedMcName)
			{
				applyMcNameVisibility(selectedMcName);
			};
		}

		/** Keep accessory dropdown above unique sprites; magnifier stays on top when present. */
		protected function bringMcNameDropdownToFront():void
		{
			var idx:int;
			if (!mcNameDropdown || !m_container || mcNameDropdown.parent != m_container)
			{
				return;
			};
			try
			{
				if (magnifierOverlay && magnifierOverlay.parent == m_container)
				{
					idx = m_container.getChildIndex(magnifierOverlay);
					if (idx > 0)
					{
						m_container.setChildIndex(mcNameDropdown, idx);
					}
					else
					{
						m_container.setChildIndex(mcNameDropdown, m_container.numChildren - 1);
					};
				}
				else
				{
					m_container.setChildIndex(mcNameDropdown, m_container.numChildren - 1);
				};
			}
			catch (err:Error)
			{
			};
		}

		protected function destroyMcNameDropdown():void
		{
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, onMcNameRetryFrame);
			};
			closeMcNameDropdownList();
			if (mcNameDropdown && mcNameDropdown.parent)
			{
				mcNameDropdown.parent.removeChild(mcNameDropdown);
			};
			mcNameDropdown = null;
			mcNameDropdownLabel = null;
			mcNameDropdownList = null;
			mcNameDropdownOpen = false;
			availableMcNames = [];
			selectedMcName = null;
		}

		protected function closeMcNameDropdownList():void
		{
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMcNameStageDown, true);
			};
			if (mcNameDropdownList && mcNameDropdownList.parent)
			{
				mcNameDropdownList.parent.removeChild(mcNameDropdownList);
			};
			mcNameDropdownList = null;
			mcNameDropdownOpen = false;
		}

		protected function onMcNameStageDown(e:MouseEvent):void
		{
			var t:DisplayObject = e.target as DisplayObject;
			while (t)
			{
				if (t == mcNameDropdown)
				{
					return;
				};
				t = t.parent;
			};
			closeMcNameDropdownList();
		}

		/** Write or clear costume.mcName from the accessory dropdown selection. */
		protected function applySelectedMcNameToCostumeData(data:Object):void
		{
			if (!data)
			{
				return;
			};
			if (selectedMcName && selectedMcName.length > 0)
			{
				data["mcName"] = selectedMcName;
			}
			else
			{
				delete data["mcName"];
			};
		}

		protected function refreshMcNameDropdownLabel():void
		{
			if (!mcNameDropdownLabel)
			{
				return;
			};
			mcNameDropdownLabel.text = selectedMcName ? selectedMcName : "Default";
		}

		/** Opt-in only: show accessory when activeName is set. Default leaves Ext alone. */
		protected function applyMcNameVisibility(activeName:String):void
		{
			var costume:Object;
			var lookup:String;
			if (!activeName || !statsName || !player || !player.MC)
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
			costume = { "mcName": activeName };
			Ssf2.Utils.applyCostumeMcName(player.MC as DisplayObject, lookup, costume);
			if (player.HasStance && player.Stance)
			{
				Ssf2.Utils.applyCostumeMcName(player.Stance as DisplayObject, lookup, costume);
			};
		}

		protected function appendExactPair(block:Object, color:uint, replacement:uint):Boolean
		{
			if (!block || !(block.colors is Array) || !(block.replacements is Array))
			{
				return false;
			};
			if (paletteBlockHasExactColor(block, color))
			{
				return false;
			};
			block.colors.push(color);
			block.replacements.push(normalizePaletteReplacement(replacement, color));
			return true;
		}
    }
}
