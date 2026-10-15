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

    /** Pack browser rows and preview, pack meta form, pack import/export flatten. Part of the CostumeSelectorDisplay chain. */
    public class CostumeSelectorPacks extends CostumeSelectorNav
    {
        public function CostumeSelectorPacks()
        {
            super();
        }

		protected var m_allowDelete:Boolean;

		protected var lastAnchorIndex:int = -1;

		protected var importPendingCostumes:Array = null;

		/** Flat pack verify entries: { statsName, costume }. */
		protected var packPendingEntries:Array = null;

		protected var m_packPadIndex:int = 0;

		protected var packMetaOverlay:Sprite = null;

		protected var packMetaNameField:TextField = null;

		protected var packMetaDescField:TextField = null;

		protected var packMetaAuthorField:TextField = null;

		protected var packMetaPending:Object = null;

		protected var packBrowserRows:Array = null;

		protected var packBrowserLoadingOnline:Boolean = false;

		/** When set, pack browser only shows packs containing this character (Import Costume). */
		protected var packBrowserCharFilter:String = null;

		private var packBrowserPreviewLine:TextField = null;

		protected var packBrowserHoveredRow:MovieClip = null;

		/** Local tile: pixel art in ph and stock icon in ph2, recolored for this costume. */
		protected function fillCostumeTileArt(btn:*, costume:Object, i:int):void
		{
			var previewIndex:int;
			var PA:MovieClip;
			var charStock:MovieClip;
			var ph:MovieClip;
			var ph2:MovieClip;
			var previewChar:String = previewStatsNameForCostume(costume);
			PA = PaletteMakerUtils.getPixelArt(previewChar);
			if (PA)
			{
				ph = MovieClip(btn.ButtonInstance.getChildByName("ph"));
				if (ph)
				{
					ph.addChild(PA);
					try { PA.gotoAndStop(10); } catch (ignorePAFrame:Error) {};
					if (costume && costume.noRecolor)
					{
						// Identity / pristine art — do not run palette or HSB filters.
					}
					else if (costume)
					{
						applyCostumePreview(PA, costume, true);
					}
					else
					{
						previewIndex = includeNoRecolorSlot ? (i - 2) : (i - 1);
						Ssf2.Utils.setColorFilterCharacter(PA, -1, previewChar, previewIndex, true);
					};
				};
			};
			charStock = PaletteMakerUtils.getStockIcon(previewChar);
			if (charStock)
			{
				ph2 = MovieClip(btn.ButtonInstance.getChildByName("ph2"));
				if (ph2)
				{
					ph2.addChild(charStock);
					if (costume && costume.noRecolor)
					{
					}
					else if (costume)
					{
						applyCostumePreview(charStock, costume, false);
					}
					else
					{
						previewIndex = includeNoRecolorSlot ? (i - 2) : (i - 1);
						Ssf2.Utils.setColorFilterCharacter(charStock, -1, previewChar, previewIndex, false);
					};
				};
			};
		}

		public function padMove(dCol:int, dRow:int):void
		{
			var cols:int = COSTUME_COLS;
			var n:int;
			var col:int;
			var row:int;
			var rows:int;
			var next:int;
			if (selectionMode == MODE_PACK_BROWSER || selectionMode == MODE_PACK_DELETE)
			{
				padMovePack(dCol, dRow);
				return;
			};
			if (m_padToolbar)
			{
				padMoveToolbar(dCol, dRow);
				return;
			};
			if (!containerButton || containerButton.length == 0)
			{
				if (dRow < 0)
				{
					enterToolbar();
				};
				return;
			};
			n = containerButton.length;
			col = selectedCostume % cols;
			row = int(selectedCostume / cols);
			if (dRow < 0 && row <= 0)
			{
				enterToolbar();
				return;
			};
			col = Math.max(0, Math.min(cols - 1, col + dCol));
			rows = Math.ceil(n / cols);
			row = Math.max(0, Math.min(rows - 1, row + dRow));
			next = row * cols + col;
			if (next >= n)
			{
				next = n - 1;
			};
			if (next < 0)
			{
				next = 0;
			};
			next = skipTakenCostume(next, dCol, dRow, cols, n);
			if (next < 0)
			{
				return;
			};
			focusCostume(next);
		}

		private function padMoveToolbar(dCol:int, dRow:int):void
		{
			var buttons:Array = visibleToolbarButtons();
			if (!buttons || buttons.length == 0)
			{
				m_padToolbar = false;
				return;
			};
			if (dRow > 0)
			{
				clearToolbarFocus(buttons);
				m_padToolbar = false;
				if (selectionMode == MODE_PACK_BROWSER || selectionMode == MODE_PACK_DELETE)
				{
					focusPackRow(m_packPadIndex);
				}
				else
				{
					focusCostume(selectedCostume);
				};
				return;
			};
			if (dCol != 0)
			{
				m_padToolbarIndex = (m_padToolbarIndex + (dCol > 0 ? 1 : -1) + buttons.length) % buttons.length;
				focusToolbar(buttons);
			};
		}

		private function padMovePack(dCol:int, dRow:int):void
		{
			var n:int = packBrowserRows ? packBrowserRows.length : 0;
			var step:int;
			if (m_padToolbar)
			{
				padMoveToolbar(dCol, dRow);
				return;
			};
			if (n <= 0)
			{
				if (dRow < 0 || dCol != 0)
				{
					enterToolbar();
				};
				return;
			};
			if (dRow < 0 && m_packPadIndex <= 0)
			{
				enterToolbar();
				return;
			};
			step = dRow != 0 ? dRow : dCol;
			if (step == 0)
			{
				return;
			};
			m_packPadIndex = Math.max(0, Math.min(n - 1, m_packPadIndex + step));
			focusPackRow(m_packPadIndex);
		}

		private function focusPackRow(index:int):void
		{
			var i:int = 0;
			var row:MovieClip;
			var n:int;
			var maxScroll:Number;
			var scroll:Number;
			if (!packBrowserRows || packBrowserRows.length == 0)
			{
				return;
			};
			n = packBrowserRows.length;
			if (index < 0)
			{
				index = 0;
			};
			if (index >= n)
			{
				index = n - 1;
			};
			m_packPadIndex = index;
			while (i < n)
			{
				row = packBrowserRows[i] as MovieClip;
				setPackRowHighlight(row, i == index);
				i++;
			};
			row = packBrowserRows[index] as MovieClip;
			packBrowserHoveredRow = row;
			if (packBrowserList && index < packBrowserList.length)
			{
				updatePackBrowserPreview(packBrowserList[index]);
			};
			if (!packBrowserLayer)
			{
				return;
			};
			maxScroll = getPackBrowserTotalScroll();
			scroll = Math.max(0, Math.min(maxScroll, index * PACK_BROWSER_ROW_H));
			packBrowserLayer.y = packBrowserListY - scroll;
			if (maxScroll > 0 && m_subMenu && m_subMenu.scrollbarMC && scrollTop && scrollHeight > 0)
			{
				m_subMenu.scrollbarMC.y = scrollTop.y + (scroll / maxScroll) * scrollHeight;
			};
		}

		protected function handleMultiSelectClick(index:int, shift:Boolean):void
		{
			if (!isIndexSelectable(index))
			{
				Ssf2.SoundQueue.instance.playSoundEffect("menu_error");
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

		/** Mode / scenario copy for infoplate.reason_txt (hover hints temporarily override). */
		protected function updateGuideFromMode():void
		{
			var n:int = selectedIndices ? selectedIndices.length : 0;
			if (onlineImportMode)
			{
				setGuideMessage("Click a costume to add or remove. Close returns to your list.");
				return;
			};
			if (selectionMode == MODE_EXPORT || selectionMode == MODE_PACK_EXPORT)
			{
				if (chainImportAfterPackSave && selectionMode == MODE_PACK_EXPORT)
				{
					setGuideMessage(n > 0
						? (n + " selected — Confirm to save as a pack, then choose which to add to your build. Close cancels.")
						: "Select costumes from color sheets to save as a pack. Shift+click for a range.");
					return;
				};
				setGuideMessage(n > 0
					? (n + " selected — Confirm to export. Online icon adds Color Vault costumes. Close cancels.")
					: "Select costumes to export. Online icon loads Color Vault. Shift+click for a range.");
				return;
			};
			if (selectionMode == MODE_PACK_BROWSER)
			{
				hoverMessage = null;
				guideMessage = null;
				stopReasonBillboard();
				ensurePackBrowserPreview();
				updatePackBrowserPreview(null);
				return;
			};
			if (selectionMode == MODE_PACK_DELETE)
			{
				setGuideMessage(n > 0
					? (n + " selected — Confirm to discard local packs. Close cancels.")
					: "Select local packs to discard. Online packs cannot be deleted.");
				return;
			};
			if (selectionMode == MODE_IMPORT || selectionMode == MODE_PACK_IMPORT)
			{
				setGuideMessage(n > 0
					? (n + " selected — Confirm to import. Close cancels.")
					: "Select costumes to import. Shift+click for a range.");
				return;
			};
			if (selectionMode == MODE_SORT)
			{
				setGuideMessage(n > 0
					? "Click a target costume to move before it, or Move to end. Close exits sort."
					: "Select costumes to reorder. Shift+click for a range.");
				return;
			};
			if (selectionMode == MODE_DELETE)
			{
				setGuideMessage(n > 0
					? (n + " selected — Confirm to discard. Close cancels.")
					: "Select custom costumes to discard. Shift+click for a range.");
				return;
			};
			setGuideMessage(null);
		}

		protected function refreshToolbarVisibility():void
		{
			var local:Boolean = !onlineImportMode;
			var pending:Boolean = importPendingCostumes != null || packPendingEntries != null;
			var showTools:Boolean = local && selectionMode == MODE_NONE && !pending;
			if (importBtn) importBtn.visible = showTools;
			if (exportBtn) exportBtn.visible = showTools;
			if (packImportBtn) packImportBtn.visible = showTools;
			if (packExportBtn) packExportBtn.visible = showTools;
			if (sortBtn) sortBtn.visible = showTools;
			MovieClip(m_subMenu.delete_btn).visible = local && (
				(m_allowDelete && (selectionMode == MODE_NONE || selectionMode == MODE_DELETE))
				|| selectionMode == MODE_PACK_BROWSER || selectionMode == MODE_PACK_DELETE
			);
			MovieClip(m_subMenu.refresh_btn).visible = local && selectionMode == MODE_NONE && !pending;
			if (m_subMenu.openFile_btn)
			{
				MovieClip(m_subMenu.openFile_btn).visible = false;
			};
			if (m_subMenu.addonline_btn)
			{
				MovieClip(m_subMenu.addonline_btn).visible = local && !pending
					&& (selectionMode == MODE_NONE || selectionMode == MODE_EXPORT || selectionMode == MODE_PACK_EXPORT);
			};
			refreshModeChrome();
		}

		protected function refreshModeChrome():void
		{
			var multi:Boolean = isMultiSelectMode();
			if (confirmBtn)
			{
				confirmBtn.visible = (selectionMode == MODE_EXPORT || selectionMode == MODE_IMPORT
					|| selectionMode == MODE_PACK_EXPORT || selectionMode == MODE_PACK_IMPORT
					|| (selectionMode == MODE_DELETE && selectedIndices.length > 0)
					|| (selectionMode == MODE_PACK_DELETE && selectedIndices.length > 0));
				confirmBtn.alpha = selectedIndices.length > 0 ? 1 : 0.55;
			};
			if (selectAllBtn)
			{
				selectAllBtn.visible = multi;
			};
			if (deselectAllBtn)
			{
				deselectAllBtn.visible = multi && selectedIndices.length > 0;
			};
			if (moveToEndBtn)
			{
				moveToEndBtn.visible = selectionMode == MODE_SORT && selectedIndices.length > 0;
				if (moveToEndBtn.visible)
				{
					updateMoveToEndPosition();
				};
			};
			updateNameplate();
			updateGuideFromMode();
		}

		protected function ensurePackBrowserPreview():void
		{
			var plate:MovieClip;
			var tf:TextField;
			plate = getInfoPlate();
			if (!plate)
			{
				return;
			};
			tf = plate.reason_txt as TextField;
			if (!tf)
			{
				return;
			};
			reasonTxtBaseWidth = -1;
			packBrowserPreviewLine = tf;
			bringInfoPlateToFront();
			plate.visible = true;
			tf.visible = true;
			stopReasonBillboard();
			if (!tf.filters || tf.filters.length == 0)
			{
				tf.filters = [new DropShadowFilter(2, 45, 0x000000, 0.95, 3, 3, 2, 2)];
			};
		}

		protected function destroyPackBrowserPreview():void
		{
			var plate:MovieClip = getInfoPlate();
			var tf:TextField;
			if (packBrowserPreviewLine)
			{
				packBrowserPreviewLine.filters = null;
			};
			packBrowserPreviewLine = null;
			if (plate)
			{
				tf = plate.reason_txt as TextField;
				if (tf)
				{
					tf.filters = null;
				};
			};
			if (selectionMode != MODE_PACK_BROWSER)
			{
				hideInfoPlate();
			};
		}

		protected function updatePackBrowserPreview(meta:Object):void
		{
			var parts:Array;
			var src:String;
			var line:String;
			var plate:MovieClip;
			var tf:TextField;
			ensurePackBrowserPreview();
			plate = getInfoPlate();
			tf = plate ? (plate.reason_txt as TextField) : null;
			if (!plate || !tf)
			{
				return;
			};
			stopReasonBillboard();
			plate.visible = true;
			tf.visible = true;
			if (!meta)
			{
				if (packBrowserLoadingOnline)
				{
					line = "Loading online packs…";
				}
				else if (packBrowserList && packBrowserList.length > 0)
				{
					line = packBrowserCharFilter
						? ("Hover a pack with " + packBrowserCharFilter + " costumes.")
						: "Hover a pack for details.";
				}
				else
				{
					line = packBrowserCharFilter
						? ("No packs found for " + packBrowserCharFilter + ".")
						: "No packs found — export one or add JSON under SSF2 Custom Colors/packs/";
				};
			}
			else
			{
				src = (meta.source == "local") ? "LOCAL" : "ONLINE";
				parts = [];
				parts.push(meta.name ? String(meta.name) : "Pack");
				parts.push(src);
				if (meta.author && String(meta.author).length > 0)
				{
					parts.push("by " + meta.author);
				};
				if (int(meta.costumeCount) > 0 || int(meta.characterCount) > 0)
				{
					parts.push(int(meta.costumeCount) + " costumes / " + int(meta.characterCount) + " chars");
				};
				if (meta.description && String(meta.description).length > 0)
				{
					parts.push(String(meta.description));
				};
				line = parts.join("  ·  ");
			};
			tf.text = line;
			updateReasonBillboard(tf);
		}

		protected function setPackRowHighlight(row:MovieClip, highlighted:Boolean):void
		{
			if (!row)
			{
				return;
			};
			try
			{
				Ssf2.Utils.tryToGotoAndStop(row, highlighted ? "_over" : "_up");
			}
			catch (labelErr:Error)
			{
			};
			try
			{
				if (row.currentLabel != (highlighted ? "_over" : "_up") && row.totalFrames >= 2)
				{
					row.gotoAndStop(highlighted ? 2 : 1);
				};
			}
			catch (err:Error)
			{
				try
				{
					row.gotoAndStop(highlighted ? 2 : 1);
				}
				catch (err2:Error)
				{
				};
			};
			row.filters = highlighted ? [new GlowFilter(0xFFDD66, 0.85, 8, 8, 1.4, 1)] : null;
		}

		/** Truncate eventName so its right edge stays at/under maxTextRight (layer-local). */
		protected function truncatePackRowName(row:MovieClip, maxTextRight:Number):void
		{
			var tf:TextField;
			var raw:String;
			var s:String;
			if (!row || !row.eventName)
			{
				return;
			};
			tf = row.eventName as TextField;
			if (!tf)
			{
				return;
			};
			raw = tf.text ? String(tf.text) : "";
			if (!raw || raw.length == 0)
			{
				return;
			};
			s = raw;
			while (s.length > 3 && (tf.x + tf.textWidth) > maxTextRight)
			{
				s = s.substring(0, s.length - 1);
				tf.text = s + "…";
			};
			if ((tf.x + tf.textWidth) > maxTextRight && raw.length > 0)
			{
				tf.text = raw.charAt(0) + "…";
			};
		}

		protected function onPackBrowserOnlineError(msg:String):void
		{
			packBrowserLoadingOnline = false;
			if (selectionMode != MODE_PACK_BROWSER)
			{
				return;
			};
			Ssf2.MultiplayerManager.notify(msg ? msg : "Online packs unavailable");
			updateGuideFromMode();
			updatePackBrowserPreview(null);
		}

		protected function packBrowserRowIndex(target:Object):int
		{
			var row:MovieClip = target as MovieClip;
			var i:int;
			if (!row || !packBrowserRows)
			{
				return -1;
			};
			i = 0;
			while (i < packBrowserRows.length)
			{
				if (packBrowserRows[i] == row)
				{
					return i;
				};
				i++;
			};
			return -1;
		}

		protected function packBrowserRow_OUT(e:MouseEvent):void
		{
			var row:MovieClip = e.currentTarget as MovieClip;
			var index:int;
			if (packBrowserHoveredRow == row)
			{
				packBrowserHoveredRow = null;
			};
			index = packBrowserRowIndex(row);
			if (selectionMode == MODE_PACK_DELETE && selectedIndices.indexOf(index) >= 0)
			{
				setPackRowHighlight(row, true);
			}
			else
			{
				setPackRowHighlight(row, false);
			};
			if (selectionMode != MODE_PACK_DELETE)
			{
				updatePackBrowserPreview(null);
			};
		}

		protected function makePackMetaInput(panel:Sprite, label:String, y:Number, multiline:Boolean, dark:Boolean=false):TextField
		{
			var lf:TextField;
			var tf:TextField;
			var bg:Shape;
			var fieldH:Number = multiline ? 72 : 26;
			lf = new TextField();
			lf.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, false);
			lf.text = label;
			lf.x = 16;
			lf.y = y;
			lf.width = 320;
			lf.height = 18;
			lf.selectable = false;
			panel.addChild(lf);
			bg = new Shape();
			bg.graphics.beginFill(dark ? 0x3a3a3a : 0xFFFFFF, 1);
			bg.graphics.drawRect(16, y + 18, 328, fieldH);
			bg.graphics.endFill();
			panel.addChild(bg);
			tf = new TextField();
			tf.defaultTextFormat = new TextFormat("_sans", 14, dark ? 0xFFFFFF : 0x111111, false);
			tf.type = TextFieldType.INPUT;
			tf.x = 18;
			tf.y = y + 18;
			tf.width = 324;
			tf.height = fieldH;
			tf.multiline = multiline;
			tf.wordWrap = multiline;
			tf.background = false;
			tf.border = false;
			panel.addChild(tf);
			return tf;
		}

		protected function makePackMetaButton(panel:Sprite, label:String, x:Number, y:Number, color:uint):Sprite
		{
			var btn:Sprite;
			var tf:TextField;
			btn = new Sprite();
			btn.buttonMode = true;
			btn.mouseChildren = false;
			btn.graphics.beginFill(color, 1);
			btn.graphics.drawRect(0, 0, 100, 32);
			btn.graphics.endFill();
			btn.x = x;
			btn.y = y;
			tf = new TextField();
			tf.defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF, true, null, null, null, null, TextFormatAlign.CENTER);
			tf.text = label;
			tf.width = 100;
			tf.height = 28;
			tf.y = 4;
			tf.selectable = false;
			btn.addChild(tf);
			panel.addChild(btn);
			return btn;
		}

		protected function onPackMetaCancelClick(e:MouseEvent):void
		{
			e.stopPropagation();
			dismissPackMetaOverlay();
			Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
		}

		protected function dismissPackMetaOverlay():void
		{
			if (packMetaOverlay && packMetaOverlay.parent)
			{
				packMetaOverlay.parent.removeChild(packMetaOverlay);
			};
			packMetaOverlay = null;
			packMetaNameField = null;
			packMetaDescField = null;
			packMetaAuthorField = null;
			packMetaPending = null;
			if (Ssf2.Main.Root && Ssf2.Main.Root.stage)
			{
				Ssf2.Main.Root.stage.focus = null;
			};
		}

		protected function trimPackMetaText(value:String):String
		{
			if (!value)
			{
				return "";
			};
			return value.replace(new RegExp("^\\s+|\\s+$", "g"), "");
		}

		protected function flattenPackObjectToEntries(pack:Object):Array
		{
			var out:Array = [];
			var characters:Object;
			var statsName:String;
			var list:Array;
			var costume:Object;
			var clone:Object;
			if (!pack || !(pack.characters is Object))
			{
				return out;
			};
			characters = pack.characters;
			for (statsName in characters)
			{
				list = characters[statsName] as Array;
				if (!list)
				{
					continue;
				};
				for each (costume in list)
				{
					if (!costume)
					{
						continue;
					};
					clone = Ssf2.Utils.cloneObject(costume);
					clone._packStatsName = statsName;
					out.push({ "statsName": statsName, "costume": clone });
				};
			};
			return out;
		}

		protected function flattenPackPendingCostumes():Array
		{
			var out:Array = [];
			var entry:Object;
			var costume:Object;
			if (!packPendingEntries)
			{
				return out;
			};
			for each (entry in packPendingEntries)
			{
				if (!entry || !entry.costume)
				{
					continue;
				};
				costume = entry.costume;
				costume._packStatsName = entry.statsName;
				out.push(costume);
			};
			return out;
		}

		protected function buildPackObjectFromSelection():Object
		{
			var characters:Object = {};
			var idx:int;
			var costume:Object;
			var clone:Object;
			var statsName:String;
			var count:int = 0;
			for each (idx in selectedIndices)
			{
				if (idx < 0 || !allCostumes || idx >= allCostumes.length)
				{
					continue;
				};
				costume = allCostumes[idx];
				if (!costume)
				{
					continue;
				};
				statsName = costume._packStatsName ? String(costume._packStatsName) : m_statsName;
				if (!statsName)
				{
					continue;
				};
				if (!(characters[statsName] is Array))
				{
					characters[statsName] = [];
					count++;
				};
				clone = Ssf2.Utils.cloneObject(costume);
				try { delete clone._packStatsName; } catch (stripErr:Error) { };
				CostumePackIO.stripColorVaultIdFromCostume(clone);
				CostumePackIO.applyFlashSafeNudgeToCostume(clone);
				(characters[statsName] as Array).push(clone);
			};
			return {
				"format": "ssf2_costume_pack",
				"version": 2,
				"characterCount": count,
				"characters": characters
			};
		}

		/** Character id used for PA/stock preview (pack verify can mix characters). */
		private function previewStatsNameForCostume(costume:Object):String
		{
			if (costume && costume._packStatsName)
			{
				return String(costume._packStatsName);
			};
			return m_statsName;
		}
    }
}
