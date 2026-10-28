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

    /** Scrollbar, blur, nameplate, info plate, reason billboard, guide text and toolbar wiring. Part of the CostumeSelectorDisplay chain. */
    public class CostumeSelectorChrome extends CostumeSelectorTiles
    {
        public function CostumeSelectorChrome()
        {
            super();
        }

		internal static const MODE_DELETE:String = "delete";

		internal static const MODE_EXPORT:String = "export";

		internal static const MODE_IMPORT:String = "import";

		internal static const MODE_SORT:String = "sort";

		internal static const MODE_PACK_EXPORT:String = "pack_export";

		internal static const MODE_PACK_IMPORT:String = "pack_import";

		internal static const MODE_PACK_BROWSER:String = "pack_browser";

		internal static const MODE_PACK_DELETE:String = "pack_delete";

		/** When true (CSS), vault Close returns to local costume list. When false (Palette Maker), Close fully exits. */
		public var returnToLocalListOnVaultExit:Boolean = false;

		private var isDragging:Boolean;

		protected var listLocation:Point = new Point(30, 37);

		protected var scrollTop:Point;

		protected var scrollHeight:Number = 270;

		protected var container:MovieClip;

		protected var selectedCostume:int;

		private var blurOverlay:Bitmap;
		private var m_blur:BlurFilter = new BlurFilter(0, 0, 1);

		protected var importBtn:MovieClip = null;

		protected var exportBtn:MovieClip = null;

		protected var packImportBtn:MovieClip = null;

		protected var packExportBtn:MovieClip = null;

		protected var sortBtn:MovieClip = null;

		protected var confirmBtn:MovieClip = null;

		protected var selectAllBtn:MovieClip = null;

		protected var deselectAllBtn:MovieClip = null;

		protected var moveToEndBtn:MovieClip = null;

		private var toolbarBound:Boolean = false;

		/** After pack meta save (color-sheet multi-import), open pack import verify. */
		protected var chainImportAfterPackSave:Boolean = false;

		protected var packBrowserList:Array = null;

		protected var packBrowserLayer:MovieClip = null;

		protected var packBrowserListY:Number = 37;

		internal static const PACK_BROWSER_ROW_H:Number = 28;

		internal static const PACK_BROWSER_LIST_H:Number = 270;

		internal static const COSTUME_COLS:int = 7;

		internal static const COSTUME_ROW_H:Number = 111.7;

		/** Fallback visible rows when masker height is unavailable (~270px track). */
		private static const COSTUME_VISIBLE_ROWS_FALLBACK:int = 2;

		/** Fallback if the FLA stage instance isn't available to sample. */
		private static const INFO_PLATE_FALLBACK_X:Number = 17;

		private static const INFO_PLATE_FALLBACK_Y:Number = 318;

		/** Library-spawned infoplate kept above costume cards. */
		private var ownedInfoPlate:MovieClip = null;

		protected var guideMessage:String = null;

		protected var hoverMessage:String = null;

		private var hoverHints:flash.utils.Dictionary = new flash.utils.Dictionary(true);

		private var reasonBillboardActive:Boolean = false;

		private var reasonBillboardCycleW:int = 0;

		private var reasonBillboardSource:String = "";

		protected var reasonTxtBaseWidth:Number = -1;

		protected function containerButton_OVER(e:MouseEvent):void
		{
			var i:int = findEvent(e.target as MovieClip);
			var costume:Object;
			var tip:String;
            if (i >= 0 && i < allCostumes.length)
            {
				ensureVaultTilePreview(i);
                Ssf2.SoundQueue.instance.playSoundEffect("menu_hover");
                selectedCostume = i;
				updateNameplate();
				costume = allCostumes[i];
				tip = formatCostumeHoverTip(costume);
				if (tip)
				{
					setHoverHint(tip);
				};
            };
		}

		protected function containerButton_OUT(e:MouseEvent):void
		{
			clearHoverHint();
		}

		protected function restoreScrollbarPos():void
		{
			m_subMenu.scrollbarMC.y = 38;
			if ((selectionMode == MODE_PACK_BROWSER || selectionMode == MODE_PACK_DELETE) && packBrowserLayer)
			{
				packBrowserLayer.y = packBrowserListY;
			};
		}

		protected function startDragBar(e:MouseEvent):void
		{
			if (!isDragging)
			{
				isDragging = true;
				m_subMenu.scrollbarMC.startDrag(false, new Rectangle(scrollTop.x, scrollTop.y, 0, scrollHeight));
			};
		}

		protected function getCostumeVisibleRows():int
		{
			var vh:Number;
			if (m_subMenu && m_subMenu.masker && m_subMenu.masker.height > 0)
			{
				vh = m_subMenu.masker.height;
			}
			else
			{
				vh = scrollHeight;
			};
			if (vh <= 0)
			{
				return (COSTUME_VISIBLE_ROWS_FALLBACK);
			};
			return (Math.max(1, int(vh / COSTUME_ROW_H)));
		}

		protected function getCostumeTotalScroll():Number
		{
			var n:int = allCostumes ? allCostumes.length : 0;
			var rows:int = Math.ceil(n / COSTUME_COLS);
			return (COSTUME_ROW_H * Math.max(0, rows - getCostumeVisibleRows()));
		}

		protected function getPackBrowserTotalScroll():Number
		{
			var count:int = packBrowserList ? packBrowserList.length : 0;
			var visible:int = Math.floor(PACK_BROWSER_LIST_H / PACK_BROWSER_ROW_H);
			return (PACK_BROWSER_ROW_H * Math.max(0, count - visible));
		}

		protected function onCostumeSelectorMouseWheel(e:MouseEvent):void
		{
			var totalScroll:Number;
			var rowH:Number;
			var barDelta:Number;
			var nextY:Number;
			if (!m_subMenu || !m_subMenu.scrollbarMC || scrollHeight <= 0)
			{
				return;
			};
			if (selectionMode == MODE_PACK_BROWSER || selectionMode == MODE_PACK_DELETE)
			{
				totalScroll = getPackBrowserTotalScroll();
				rowH = PACK_BROWSER_ROW_H;
			}
			else
			{
				totalScroll = getCostumeTotalScroll();
				rowH = COSTUME_ROW_H;
			};
			if (totalScroll <= 0)
			{
				return;
			};
			// One content row per wheel notch (maps through thumb percent).
			barDelta = (rowH / totalScroll) * scrollHeight;
			if (barDelta <= 0)
			{
				return;
			};
			nextY = m_subMenu.scrollbarMC.y - (e.delta > 0 ? barDelta : -barDelta);
			nextY = Math.max(scrollTop.y, Math.min(scrollTop.y + scrollHeight, nextY));
			m_subMenu.scrollbarMC.y = nextY;
			applyScrollFromBar();
			e.stopPropagation();
		}

		protected function moveDragBar(e:MouseEvent):void
		{
			if (!isDragging)
			{
				return;
			};
			applyScrollFromBar();
		}

		private function applyScrollFromBar():void
		{
			var percentScrolled:Number;
			var totalScroll:Number;
			percentScrolled = (m_subMenu.scrollbarMC.y - scrollTop.y) / scrollHeight;
			percentScrolled = Math.max(0, Math.min(1, percentScrolled));
			if ((selectionMode == MODE_PACK_BROWSER || selectionMode == MODE_PACK_DELETE) && packBrowserLayer)
			{
				totalScroll = getPackBrowserTotalScroll();
				packBrowserLayer.y = packBrowserListY - percentScrolled * totalScroll;
				return;
			};
			if (!container || !allCostumes)
			{
				return;
			};
			totalScroll = getCostumeTotalScroll();
			container.y = listLocation.y - percentScrolled * totalScroll;
		}

		protected function stopDragBar(e:MouseEvent):void
		{
			if(isDragging)
			{
				isDragging = false;
				m_subMenu.scrollbarMC.stopDrag();
			};
		}

		protected function findEvent(e:MovieClip):int
		{
			var i:int;
			if(e && !e.visible)
			{
				return -1;
			};
			while(i < containerButton.length)
			{
				if(containerButton[i].ButtonInstance == e)
				{
					return i;
				};
				i++;
			};
			return -1;
		};

		protected function toggleBlurBackground(apply:Boolean):void
		{
			var menu:MovieClip;
			var root:*;
			if (apply) 
			{
				if (blurOverlay && blurOverlay.parent) 
				{
					return;
				};
				menu = resolveBlurLayer();
				if (!menu)
				{
					return;
				};
				root = Ssf2.Main && Ssf2.Main.Root ? Ssf2.Main.Root : null;
				if (!root)
				{
					return;
				};
				try
				{
					blurOverlay = new Bitmap(Ssf2.Utils.getSnapshot(root));
				}
				catch (snapErr:Error)
				{
					blurOverlay = null;
					return;
				};
				blurOverlay.x = root.x;
				blurOverlay.y = root.y;
				menu.addChild(blurOverlay);
				animateBlur(blurOverlay, true);
			} 
			else
			{
				if (blurOverlay && blurOverlay.parent)
				{
					animateBlur(blurOverlay, false);
				};
			};
		}

		/** costumeSubMenu_r2.blur — use getChildByName so a missing timeline name is not Error #1065. */
		private function resolveBlurLayer():MovieClip
		{
			var sub:*;
			var layer:*;
			sub = m_subMenu;
			if (!sub)
			{
				return null;
			};
			try
			{
				layer = sub.getChildByName("blur");
			}
			catch (blurErr:Error)
			{
				layer = null;
			};
			if (layer is MovieClip)
			{
				return layer as MovieClip;
			};
			try
			{
				if (sub["blur"] is MovieClip)
				{
					return sub["blur"] as MovieClip;
				};
			}
			catch (propErr:Error)
			{
			};
			return null;
		}

		private function animateBlur(targetBmp:Bitmap, apply:Boolean):void
		{
			var startTime:int = getTimer();
			var duration:int = 100;
			targetBmp.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			function onEnterFrame(e:Event):void 
			{
				var elapsed:int = getTimer() - startTime;
				var progress:Number = Math.min(elapsed / duration, 1);
				if (!apply) progress = 1 - progress;
				var maxBlur:Number = 4;
				var blurValue:Number = maxBlur * progress;
				m_blur.blurX = blurValue;
				m_blur.blurY = blurValue;
				targetBmp.filters = [m_blur];
				if (elapsed >= duration)
				{
					targetBmp.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
					if (!apply)
					{
						if (targetBmp.parent) targetBmp.parent.removeChild(targetBmp);
						blurOverlay = null;
					};
				};
			};
		}

		protected function updateNameplate():void
		{
			clearStockIcon();
			currentStockIcon = PaletteMakerUtils.getStockIcon(m_statsName, true);
			if (currentStockIcon && m_subMenu && m_subMenu.nameplate && m_subMenu.nameplate.stockMain)
			{
				MovieClip(m_subMenu.nameplate.stockMain).addChild(currentStockIcon);
			};
			if (m_subMenu && m_subMenu.nameplate && m_subMenu.nameplate.counter_txt)
			{
				m_subMenu.nameplate.counter_txt.text = allCostumes ? allCostumes.length : 0;
			};
			if (onlineImportMode)
			{
				m_subMenu.nameplate.title_txt.text = "Color Vault";
			}
			else if (selectionMode == MODE_IMPORT)
			{
				m_subMenu.nameplate.title_txt.text = "Import";
			}
			else if (selectionMode == MODE_EXPORT)
			{
				m_subMenu.nameplate.title_txt.text = "Export";
			}
			else if (selectionMode == MODE_PACK_BROWSER)
			{
				m_subMenu.nameplate.title_txt.text = "Costume Packs";
			}
			else if (selectionMode == MODE_PACK_DELETE)
			{
				m_subMenu.nameplate.title_txt.text = "Discard Packs";
			}
			else if (selectionMode == MODE_PACK_IMPORT)
			{
				m_subMenu.nameplate.title_txt.text = "Pack Import";
			}
			else if (selectionMode == MODE_PACK_EXPORT)
			{
				m_subMenu.nameplate.title_txt.text = "Pack Export";
			}
			else if (selectionMode == MODE_SORT)
			{
				m_subMenu.nameplate.title_txt.text = "Sort";
			}
			else if (selectionMode == MODE_DELETE)
			{
				m_subMenu.nameplate.title_txt.text = "Discard";
			}
			else if (m_subMenu && m_subMenu.nameplate && m_subMenu.nameplate.title_txt)
			{
				m_subMenu.nameplate.title_txt.text = PaletteMakerUtils.displayNameFor(m_statsName);
			};
		}

		protected function showWarningMessage(message:String):void
		{
			guideMessage = message;
			hoverMessage = null;
			refreshInfoPlate();
		}

		protected function setGuideMessage(message:String):void
		{
			guideMessage = message;
			refreshInfoPlate();
		}

		private function setHoverHint(message:String):void
		{
			hoverMessage = message;
			refreshInfoPlate();
		}

		protected function clearHoverHint():void
		{
			hoverMessage = null;
			refreshInfoPlate();
		}

		private function sampleInfoPlateStagePosition():Point
		{
			var sample:MovieClip;
			var px:Number = INFO_PLATE_FALLBACK_X;
			var py:Number = INFO_PLATE_FALLBACK_Y;
			var savedFrame:int;
			if (!m_subMenu)
			{
				return new Point(px, py);
			};
			try
			{
				savedFrame = m_subMenu.currentFrame;
				// Frame 3 still has the authored stage instance — sample x/y then restore frame.
				if (m_subMenu.totalFrames >= 3)
				{
					Ssf2.Utils.tryToGotoAndStop(m_subMenu, 3);
				};
				sample = findTimelineInfoPlateInstance();
				if (sample)
				{
					px = sample.x;
					py = sample.y;
					sample.visible = false;
				};
				if (savedFrame > 0 && savedFrame != m_subMenu.currentFrame)
				{
					Ssf2.Utils.tryToGotoAndStop(m_subMenu, savedFrame);
				};
			}
			catch (err:Error)
			{
			};
			return new Point(px, py);
		}

		private function findTimelineInfoPlateInstance():MovieClip
		{
			var child:DisplayObject;
			var i:int;
			if (!m_subMenu)
			{
				return null;
			};
			try
			{
				if (m_subMenu.infoplate is MovieClip)
				{
					return m_subMenu.infoplate as MovieClip;
				};
			}
			catch (err:Error)
			{
			};
			try
			{
				child = m_subMenu.getChildByName("infoplate");
				if (child is MovieClip)
				{
					return child as MovieClip;
				};
			}
			catch (nameErr:Error)
			{
			};
			i = 0;
			while (i < m_subMenu.numChildren)
			{
				child = m_subMenu.getChildAt(i);
				if (child && child.name == "infoplate" && child is MovieClip)
				{
					return child as MovieClip;
				};
				i++;
			};
			return null;
		}

		private function createInfoPlateFromLibrary():MovieClip
		{
			try
			{
				return Ssf2.ResourceManager.getLibraryMC("palette_editor_fla.InfoPlate") as MovieClip;
			}
			catch (err:Error)
			{
			};
			return null;
		}

		/** Spawn infoplate from library and keep it above costume cards. */
		protected function ensureOwnedInfoPlate():MovieClip
		{
			var pos:Point;
			var timelineCopy:MovieClip;
			if (ownedInfoPlate)
			{
				if (ownedInfoPlate.parent != m_subMenu && m_subMenu)
				{
					m_subMenu.addChild(ownedInfoPlate);
				};
				bringInfoPlateToFront();
				return ownedInfoPlate;
			};
			if (!m_subMenu)
			{
				return null;
			};
			pos = sampleInfoPlateStagePosition();
			// Hide any leftover timeline instance so we don't double-draw.
			timelineCopy = findTimelineInfoPlateInstance();
			if (timelineCopy)
			{
				timelineCopy.visible = false;
			};
			ownedInfoPlate = createInfoPlateFromLibrary();
			if (!ownedInfoPlate)
			{
				trace("[CostumeSelectorDisplay] Could not load infoplate from library");
				return null;
			};
			ownedInfoPlate.name = "ownedInfoPlate";
			ownedInfoPlate.x = pos.x;
			ownedInfoPlate.y = pos.y;
			ownedInfoPlate.visible = false;
			ownedInfoPlate.mouseEnabled = false;
			ownedInfoPlate.mouseChildren = false;
			m_subMenu.addChild(ownedInfoPlate);
			bringInfoPlateToFront();
			return ownedInfoPlate;
		}

		protected function bringInfoPlateToFront():void
		{
			if (!ownedInfoPlate || !ownedInfoPlate.parent)
			{
				return;
			};
			try
			{
				ownedInfoPlate.parent.setChildIndex(ownedInfoPlate, ownedInfoPlate.parent.numChildren - 1);
			}
			catch (err:Error)
			{
			};
		}

		protected function getInfoPlate():MovieClip
		{
			return ensureOwnedInfoPlate();
		}

		protected function hideInfoPlate():void
		{
			var plate:MovieClip;
			stopReasonBillboard();
			plate = ownedInfoPlate ? ownedInfoPlate : getInfoPlate();
			if (plate)
			{
				plate.visible = false;
			};
		}

		private function refreshInfoPlate():void
		{
			var msg:String = (hoverMessage != null && hoverMessage.length > 0) ? hoverMessage : guideMessage;
			var plate:MovieClip = getInfoPlate();
			var tf:TextField;
			if (!plate)
			{
				return;
			};
			if (msg)
			{
				bringInfoPlateToFront();
				plate.visible = true;
				tf = plate.reason_txt as TextField;
				if (tf)
				{
					tf.visible = true;
					tf.text = msg;
					updateReasonBillboard(tf);
				};
			}
			else if (selectionMode != MODE_PACK_BROWSER)
			{
				hideInfoPlate();
			};
		}

		/** Continuous marquee: "text  text  text  …" scrolling with no pauses. */
		protected function updateReasonBillboard(tf:TextField):void
		{
			var src:String;
			var unit:String;
			var copies:int;
			var built:String;
			var i:int;
			var scrollOne:int;
			var scrollTwo:int;
			stopReasonBillboard();
			if (!tf)
			{
				return;
			};
			if (reasonTxtBaseWidth < 0)
			{
				reasonTxtBaseWidth = tf.width;
			};
			src = String(tf.text || "");
			reasonBillboardSource = src;
			tf.autoSize = TextFieldAutoSize.NONE;
			tf.wordWrap = false;
			tf.multiline = false;
			tf.width = reasonTxtBaseWidth;
			tf.scrollRect = null;
			tf.text = src;
			try
			{
				tf.scrollH = 0;
			}
			catch (err0:Error)
			{
			};
			// Fits on one line — no marquee needed.
			if (tf.maxScrollH <= 0)
			{
				reasonBillboardCycleW = 0;
				return;
			};
			unit = src + "  ";
			// Measure one cycle in scrollH units (not char bounds — those drift mid-repeat).
			tf.text = unit;
			try { tf.scrollH = 0; } catch (eA:Error) {};
			scrollOne = tf.maxScrollH;
			tf.text = unit + unit;
			try { tf.scrollH = 0; } catch (eB:Error) {};
			scrollTwo = tf.maxScrollH;
			reasonBillboardCycleW = Math.max(1, scrollTwo - scrollOne);
			if (reasonBillboardCycleW <= 0)
			{
				reasonBillboardCycleW = Math.max(1, scrollOne);
			};
			copies = 8;
			built = "";
			i = 0;
			while (i < copies)
			{
				built += unit;
				i++;
			};
			tf.text = built;
			try
			{
				tf.scrollH = 0;
			}
			catch (err1:Error)
			{
			};
			if (tf.maxScrollH <= 0)
			{
				tf.text = src;
				reasonBillboardCycleW = 0;
				return;
			};
			reasonBillboardActive = true;
			m_subMenu.addEventListener(Event.ENTER_FRAME, tickReasonBillboard);
		}

		private function tickReasonBillboard(e:Event):void
		{
			var plate:MovieClip = getInfoPlate();
			var tf:TextField;
			if (!plate || !plate.visible)
			{
				stopReasonBillboard();
				return;
			};
			tf = plate.reason_txt as TextField;
			if (!tf || !tf.visible)
			{
				stopReasonBillboard();
				return;
			};
			if (reasonBillboardCycleW <= 0 || tf.maxScrollH <= 0)
			{
				stopReasonBillboard();
				return;
			};
			tf.scrollH = tf.scrollH + 2;
			if (tf.scrollH >= reasonBillboardCycleW)
			{
				tf.scrollH = tf.scrollH - reasonBillboardCycleW;
			};
		}

		protected function stopReasonBillboard():void
		{
			var plate:MovieClip;
			var tf:TextField;
			if (reasonBillboardActive && m_subMenu)
			{
				m_subMenu.removeEventListener(Event.ENTER_FRAME, tickReasonBillboard);
			};
			reasonBillboardActive = false;
			reasonBillboardCycleW = 0;
			try
			{
				plate = getInfoPlate();
				if (plate && plate.reason_txt)
				{
					tf = TextField(plate.reason_txt);
					tf.scrollRect = null;
					tf.visible = true;
					tf.autoSize = TextFieldAutoSize.NONE;
					if (reasonTxtBaseWidth > 0)
					{
						tf.width = reasonTxtBaseWidth;
					};
					if (reasonBillboardSource && reasonBillboardSource.length > 0)
					{
						tf.text = reasonBillboardSource;
					};
					try { tf.scrollH = 0; } catch (e:Error) {};
				};
			}
			catch (err:Error)
			{
			};
			reasonBillboardSource = "";
		}

		private function getConfirmHint():String
		{
			if (selectionMode == MODE_PACK_EXPORT)
			{
				if (chainImportAfterPackSave)
				{
					return "Save selected color-sheet costumes as a pack, then choose which to add to your build";
				};
				return "Confirm to name the pack and save under SSF2 Custom Colors/packs/";
			};
			if (selectionMode == MODE_EXPORT)
			{
				return "Confirm to name the pack and save under SSF2 Custom Colors/packs/";
			};
			if (selectionMode == MODE_IMPORT || selectionMode == MODE_PACK_IMPORT)
			{
				return "Import the selected costumes";
			};
			if (selectionMode == MODE_DELETE)
			{
				return "Permanently discard the selected costumes";
			};
			if (selectionMode == MODE_PACK_DELETE)
			{
				return "Permanently discard the selected local packs";
			};
			return "Confirm the current action";
		}

		private function getCloseHint():String
		{
			if (selectionMode == MODE_SORT)
			{
				return "Exit sort mode";
			};
			if (selectionMode == MODE_PACK_DELETE)
			{
				return "Cancel pack discard";
			};
			if (selectionMode == MODE_PACK_BROWSER)
			{
				return "Return to costume list";
			};
			if (selectionMode == MODE_IMPORT || selectionMode == MODE_PACK_IMPORT
				|| selectionMode == MODE_EXPORT || selectionMode == MODE_PACK_EXPORT)
			{
				return "Cancel and discard this selection";
			};
			if (selectionMode != MODE_NONE)
			{
				return "Cancel and return to the costume list";
			};
			if (onlineImportMode)
			{
				return returnToLocalListOnVaultExit ? "Return to your costume list" : "Close Color Vault";
			};
			return "Close costume manager";
		}

		/**
		 * Bind FLA buttons on costumeSubMenu (or instantiate from library).
		 * Expected: Import/Export/Pack/Sort/Confirm + SelectAll/DeselectAll/MoveToEnd.
		 * Exit-sort uses existing close_btn.
		 */
		protected function bindToolbarButtons():void
		{
			if (toolbarBound)
			{
				return;
			};
			toolbarBound = true;
			importBtn = resolveToolbarButton(["importCostume_btn", "ImportCostume", "import_costume_btn", "ImportCostumeBtn"], ["palette_editor_fla.ImportCostumeBtn", "ImportCostumeBtn"]);
			exportBtn = resolveToolbarButton(["exportCostume_btn", "ExportCostume", "export_costume_btn", "ExportCostumeBtn"], ["palette_editor_fla.ExportCostumeBtn", "ExportCostumeBtn"]);
			packImportBtn = resolveToolbarButton(["packImport_btn", "PackImport", "pack_import_btn", "PackImportBtn"], ["palette_editor_fla.PackImportBtn", "PackImportBtn"]);
			packExportBtn = resolveToolbarButton(["packExport_btn", "PackExport", "pack_export_btn", "PackExportBtn"], ["palette_editor_fla.PackExportBtn", "PackExportBtn"]);
			sortBtn = resolveToolbarButton(["sort_btn", "Sort", "SortBtn"], ["palette_editor_fla.SortBtn", "SortBtn"]);
			confirmBtn = resolveToolbarButton(["confirm_btn", "Confirm", "ConfirmBtn"], ["palette_editor_fla.ConfirmBtn", "ConfirmBtn"]);
			selectAllBtn = resolveToolbarButton(["selectAll_btn", "SelectAll", "SelectAllBtn"], ["palette_editor_fla.SelectAllBtn", "SelectAllBtn"]);
			deselectAllBtn = resolveToolbarButton(["deselectAll_btn", "DeselectAll", "DeselectAllBtn"], ["palette_editor_fla.DeselectAllBtn", "DeselectAllBtn"]);
			moveToEndBtn = resolveToolbarButton(["moveToEnd_btn", "MoveToEnd", "MoveToEndBtn"], ["palette_editor_fla.MoveToEndBtn", "MoveToEndBtn"]);
			layoutFallbackToolbar();
			if (confirmBtn) confirmBtn.visible = false;
			if (selectAllBtn) selectAllBtn.visible = false;
			if (deselectAllBtn) deselectAllBtn.visible = false;
			if (moveToEndBtn) moveToEndBtn.visible = false;
		}

		private function resolveToolbarButton(instanceNames:Array, libraryIds:Array):MovieClip
		{
			var i:int;
			var name:String;
			var child:DisplayObject;
			var className:String;
			var btn:MovieClip;
			var id:String;
			if (!m_subMenu)
			{
				return null;
			};
			for each (name in instanceNames)
			{
				try
				{
					if (m_subMenu[name] is MovieClip)
					{
						return m_subMenu[name] as MovieClip;
					};
				}
				catch (err:Error)
				{
				};
			};
			i = 0;
			while (i < m_subMenu.numChildren)
			{
				child = m_subMenu.getChildAt(i);
				className = getQualifiedClassName(child);
				for each (id in libraryIds)
				{
					if (className && (className == id || className.indexOf(id.split(".").pop()) != -1))
					{
						return child as MovieClip;
					};
				};
				if (child && child.name)
				{
					for each (name in instanceNames)
					{
						if (child.name == name)
						{
							return child as MovieClip;
						};
					};
				};
				i++;
			};
			for each (id in libraryIds)
			{
				btn = Ssf2.ResourceManager.getLibraryMC(id) as MovieClip;
				if (btn)
				{
					m_subMenu.addChild(btn);
					return btn;
				};
			};
			return null;
		}

		/** If buttons were spawned from library with no stage position, park them near refresh/delete. */
		private function layoutFallbackToolbar():void
		{
			var anchor:MovieClip;
			var xCursor:Number;
			var yPos:Number;
			var gap:Number = 6;
			var buttons:Array;
			var btn:MovieClip;
			try
			{
				anchor = m_subMenu.refresh_btn as MovieClip;
			}
			catch (err:Error)
			{
				anchor = null;
			};
			if (!anchor)
			{
				try
				{
					anchor = m_subMenu.delete_btn as MovieClip;
				}
				catch (err2:Error)
				{
					anchor = null;
				};
			};
			xCursor = anchor ? (anchor.x + anchor.width + 10) : 40;
			yPos = anchor ? anchor.y : 10;
			buttons = [importBtn, exportBtn, packImportBtn, packExportBtn, sortBtn, confirmBtn];
			for each (btn in buttons)
			{
				if (!btn || btn.parent != m_subMenu)
				{
					continue;
				};
				// Only auto-place if still at origin (fresh library instance).
				if (Math.abs(btn.x) < 1 && Math.abs(btn.y) < 1)
				{
					btn.x = xCursor;
					btn.y = yPos;
					xCursor = xCursor + btn.width + gap;
				};
				btn.buttonMode = true;
				btn.mouseChildren = false;
			};
		}

		/** Place Move to end to the right of the last costume tile (when FLA has no fixed stage slot). */
		protected function updateMoveToEndPosition():void
		{
			var last:*;
			var local:Point;
			if (!moveToEndBtn || !container || !containerButton || containerButton.length == 0)
			{
				return;
			};
			// Keep FLA layout if the button was authored off the default origin.
			if (moveToEndBtn.x > 4 || moveToEndBtn.y > 4)
			{
				return;
			};
			last = containerButton[containerButton.length - 1];
			if (!last || !last.ButtonInstance)
			{
				return;
			};
			local = container.localToGlobal(new Point(last.ButtonInstance.x + last.ButtonInstance.width + 8, last.ButtonInstance.y + (last.ButtonInstance.height - 22) * 0.5));
			local = m_subMenu.globalToLocal(local);
			moveToEndBtn.x = local.x;
			moveToEndBtn.y = local.y;
		}

		protected function wireChromeHintEvents(enable:Boolean):void
		{
			wireHoverHint(m_subMenu.close_btn as DisplayObject, null, enable);
			wireHoverHint(m_subMenu.refresh_btn as DisplayObject, "Reload costumes from disk", enable);
			wireHoverHint(m_subMenu.delete_btn as DisplayObject, "Discard custom costumes or local packs", enable);
			if (m_subMenu.addonline_btn)
			{
				wireHoverHint(m_subMenu.addonline_btn as DisplayObject,
					(selectionMode == MODE_EXPORT || selectionMode == MODE_PACK_EXPORT)
						? "Include Color Vault costumes in this export list"
						: "Browse Color Vault costumes for this character",
					enable);
			};
		}

		protected function wireOne(btn:MovieClip, handler:Function, enable:Boolean):void
		{
			if (!btn)
			{
				return;
			};
			btn.removeEventListener(MouseEvent.CLICK, handler);
			if (enable)
			{
				btn.addEventListener(MouseEvent.CLICK, handler);
			};
		}

		protected function wireHoverHint(target:DisplayObject, description:String, enable:Boolean):void
		{
			if (!target)
			{
				return;
			};
			if (description)
			{
				hoverHints[target] = description;
			}
			else
			{
				delete hoverHints[target];
			};
			target.removeEventListener(MouseEvent.MOUSE_OVER, onToolbarHintOver);
			target.removeEventListener(MouseEvent.MOUSE_OUT, onToolbarHintOut);
			if (enable)
			{
				target.addEventListener(MouseEvent.MOUSE_OVER, onToolbarHintOver);
				target.addEventListener(MouseEvent.MOUSE_OUT, onToolbarHintOut);
			};
		}

		private function onToolbarHintOver(e:MouseEvent):void
		{
			var target:Object = e.currentTarget;
			var desc:String = hoverHints[target] as String;
			if (!desc)
			{
				if (target == confirmBtn)
				{
					desc = getConfirmHint();
				}
				else if (m_subMenu && target == m_subMenu.close_btn)
				{
					desc = getCloseHint();
				};
			};
			if (desc)
			{
				setHoverHint(desc);
			};
		}

		private function onToolbarHintOut(e:MouseEvent):void
		{
			clearHoverHint();
		}
    }
}
