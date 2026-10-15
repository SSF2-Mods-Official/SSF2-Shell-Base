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

    /** Gamepad navigation, toolbar focus, costume selection and CSS pick. Part of the CostumeSelectorDisplay chain. */
    public class CostumeSelectorNav extends CostumeSelectorChrome
    {
        public function CostumeSelectorNav()
        {
            super();
        }

		internal static const ALPHA_DIM:Number = 0.45;

		internal static const ALPHA_FULL:Number = 1;

		private static const ALPHA_TAKEN:Number = 0.28;

		protected var selectedIndices:Array = [];

		protected var includeNoRecolorSlot:Boolean = false;

		protected var m_padToolbar:Boolean = false;

		protected var m_padToolbarIndex:int = 0;

		protected function getTargetTileAlpha(index:int, costume:Object):Number
		{
			var selected:Boolean = selectedIndices.indexOf(index) != -1;
			if (onlineImportMode)
			{
				return isVaultCostumeOwned(costume) ? ALPHA_FULL : ALPHA_DIM;
			};
			if (selectionMode == MODE_DELETE || selectionMode == MODE_EXPORT || selectionMode == MODE_IMPORT || selectionMode == MODE_SORT)
			{
				if (!isIndexSelectable(index))
				{
					return ALPHA_FULL;
				};
				return selected ? ALPHA_FULL : ALPHA_DIM;
			};
			if (isCssCostumeTaken(index))
			{
				return ALPHA_TAKEN;
			};
			return ALPHA_FULL;
		}

		protected function enterToolbar():void
		{
			var buttons:Array = visibleToolbarButtons();
			if (!buttons || buttons.length == 0)
			{
				return;
			};
			m_padToolbar = true;
			m_padToolbarIndex = 0;
			focusToolbar(buttons);
		}

		protected function visibleToolbarButtons():Array
		{
			var raw:Array = [];
			var sorted:Array = [];
			var btn:MovieClip;
			var i:int = 0;
			var j:int;
			pushToolbar(raw, m_subMenu ? m_subMenu.close_btn as MovieClip : null);
			pushToolbar(raw, m_subMenu ? m_subMenu.refresh_btn as MovieClip : null);
			pushToolbar(raw, m_subMenu ? m_subMenu.delete_btn as MovieClip : null);
			pushToolbar(raw, (m_subMenu && m_subMenu.addonline_btn) ? m_subMenu.addonline_btn as MovieClip : null);
			pushToolbar(raw, importBtn);
			pushToolbar(raw, exportBtn);
			pushToolbar(raw, packImportBtn);
			pushToolbar(raw, packExportBtn);
			pushToolbar(raw, sortBtn);
			pushToolbar(raw, confirmBtn);
			pushToolbar(raw, selectAllBtn);
			pushToolbar(raw, deselectAllBtn);
			pushToolbar(raw, moveToEndBtn);
			while (i < raw.length)
			{
				btn = raw[i] as MovieClip;
				j = 0;
				while (j < sorted.length && (sorted[j] as MovieClip).x <= btn.x)
				{
					j++;
				};
				sorted.splice(j, 0, btn);
				i++;
			};
			return sorted;
		}

		private function pushToolbar(list:Array, btn:MovieClip):void
		{
			if (btn && btn.visible && btn.parent)
			{
				list.push(btn);
			};
		}

		protected function focusToolbar(buttons:Array):void
		{
			var i:int = 0;
			var btn:MovieClip;
			if (!buttons || buttons.length == 0)
			{
				return;
			};
			if (m_padToolbarIndex < 0)
			{
				m_padToolbarIndex = 0;
			};
			if (m_padToolbarIndex >= buttons.length)
			{
				m_padToolbarIndex = buttons.length - 1;
			};
			while (i < buttons.length)
			{
				btn = buttons[i] as MovieClip;
				if (btn)
				{
					Ssf2.Utils.tryToGotoAndStop(btn, i == m_padToolbarIndex ? "_over" : "_up");
				};
				i++;
			};
		}

		protected function clearToolbarFocus(buttons:Array):void
		{
			var i:int = 0;
			var btn:MovieClip;
			if (!buttons)
			{
				return;
			};
			while (i < buttons.length)
			{
				btn = buttons[i] as MovieClip;
				if (btn)
				{
					Ssf2.Utils.tryToGotoAndStop(btn, "_up");
				};
				i++;
			};
		}

		protected function focusCostume(index:int):void
		{
			var i:int = 0;
			var btn:*;
			var clip:MovieClip;
			if (!containerButton)
			{
				return;
			};
			while (i < containerButton.length)
			{
				btn = containerButton[i];
				clip = btn ? btn.ButtonInstance as MovieClip : null;
				if (clip)
				{
					Ssf2.Utils.tryToGotoAndStop(clip, i == index ? "_over" : "_up");
				};
				i++;
			};
			selectedCostume = index;
			updateNameplate();
			scrollCostumeIntoView(index);
		}

		private function scrollCostumeIntoView(index:int):void
		{
			var row:int = int(index / COSTUME_COLS);
			var visible:int = getCostumeVisibleRows();
			var total:Number = getCostumeTotalScroll();
			var rowTop:Number = row * COSTUME_ROW_H;
			var viewH:Number = visible * COSTUME_ROW_H;
			var viewTop:Number = 0;
			var scroll:Number = 0;
			if (container)
			{
				viewTop = listLocation.y - container.y;
			};
			scroll = viewTop;
			if (rowTop < viewTop)
			{
				scroll = rowTop;
			}
			else if (rowTop + COSTUME_ROW_H > viewTop + viewH)
			{
				scroll = rowTop + COSTUME_ROW_H - viewH;
			};
			if (scroll < 0)
			{
				scroll = 0;
			};
			if (scroll > total)
			{
				scroll = total;
			};
			if (container)
			{
				container.y = listLocation.y - scroll;
			};
			if (total > 0 && m_subMenu && m_subMenu.scrollbarMC && scrollTop && scrollHeight > 0)
			{
				m_subMenu.scrollbarMC.y = scrollTop.y + (scroll / total) * scrollHeight;
			};
		}

		/** Menu whose changePic just ran. CurrentCharacterSelectMenu can be the one Back already cleared. */
		internal static var s_liveMenu:*;

		protected function cssMenuForPick(current:*):*
		{
			if (menuHasMatch(current))
			{
				return current;
			};
			if (menuHasMatch(s_liveMenu))
			{
				return s_liveMenu;
			};
			return current;
		}

		private function menuHasMatch(menu:*):Boolean
		{
			try
			{
				return menu && menu.changePic != null && menu.GameObj && menu.GameObj.PlayerSettings;
			}
			catch (matchErr:*)
			{
				return false;
			};
		}

		private function isProtectedCostume(costume:Object):Boolean
		{
			return PaletteMakerUtils.isSystemCostumeSlot(costume);
		}

		/**
		 * Browse / versus list: stock → team/metal → customs.
		 * Team/metal live at end of ResourceManager index space (after customs) so PM indices stay stable;
		 * display order puts them after in-game alts. Each entry carries _gameCostumeIndex for selection.
		 */
		protected function buildBrowseCostumeList():Array
		{
			var raw:Array;
			var stock:Array = [];
			var teamMetal:Array = [];
			var custom:Array = [];
			var i:int;
			var costume:Object;
			var tagged:Object;
			var hasBase:Boolean = false;
			raw = Ssf2.ResourceManager.getAllCostumes(m_statsName, null, true);
			i = 0;
			while (i < raw.length)
			{
				costume = raw[i];
				if (costume && costume.base && !costume.team)
				{
					hasBase = true;
					break;
				};
				i++;
			};
			i = 0;
			while (i < raw.length)
			{
				costume = raw[i];
				if (!costume || PaletteMakerUtils.isCustomCostume(costume))
				{
					i++;
					continue;
				};
				tagged = Ssf2.Utils.cloneObject(costume);
				// No coded base (Peach/Fox): in-game -1 is identity. When the No Recolor
				// tile is prepended, stock alts start at 0 so Red is not shared with -1.
				if (includeNoRecolorSlot && !hasBase)
				{
					tagged._gameCostumeIndex = i;
				}
				else
				{
					tagged._gameCostumeIndex = (i - 1);
				};
				if (tagged.metal || tagged.cssTeam || tagged.team)
				{
					teamMetal.push(tagged);
				}
				else
				{
					stock.push(tagged);
				};
				i++;
			};
			appendFavoriteCostumes(custom, raw, hasBase);
			raw = stock.concat(teamMetal).concat(custom);
			if (includeNoRecolorSlot)
			{
				tagged = buildNoRecolorCostumeSlot(raw.length > 0 ? raw[0] : null);
				tagged._gameCostumeIndex = -1;
				raw.unshift(tagged);
			};
			return raw;
		}

		/** Palette menu customs, in favorites-file order. Each tile keeps the shared-list costume number. */
		private function appendFavoriteCostumes(dest:Array, raw:Array, hasBase:Boolean):void
		{
			var favs:Array;
			var catalog:Array;
			var fi:int;
			var catIndex:int;
			var costume:Object;
			var tagged:Object;
			var rawIndex:int;
			var i:int;
			favs = PaletteMakerUtils.getFavoriteIndexes(m_statsName);
			catalog = PaletteMakerUtils.getCostume(m_statsName);
			fi = 0;
			while (favs && fi < favs.length)
			{
				catIndex = int(favs[fi]);
				if (!catalog || catIndex < 0 || catIndex >= catalog.length || !catalog[catIndex])
				{
					fi++;
					continue;
				};
				costume = catalog[catIndex];
				tagged = Ssf2.Utils.cloneObject(costume);
				tagged._catalogIndex = catIndex;
				rawIndex = -1;
				i = 0;
				while (raw && i < raw.length)
				{
					if (raw[i] == costume)
					{
						rawIndex = i;
						break;
					};
					i++;
				};
				if (includeNoRecolorSlot && !hasBase)
				{
					tagged._gameCostumeIndex = rawIndex;
				}
				else
				{
					tagged._gameCostumeIndex = rawIndex - 1;
				};
				dest.push(tagged);
				fi++;
			};
		}

		protected function buildFavoriteCustomList():Array
		{
			var raw:Array;
			var hasBase:Boolean = false;
			var out:Array = [];
			var i:int;
			raw = Ssf2.ResourceManager.getAllCostumes(m_statsName, null, true);
			i = 0;
			while (raw && i < raw.length)
			{
				if (raw[i] && raw[i].base && !raw[i].team)
				{
					hasBase = true;
					break;
				};
				i++;
			};
			appendFavoriteCostumes(out, raw, hasBase);
			return out;
		}

		protected function isCustomCostumeIndex(index:int):Boolean
		{
			if (index < 0 || !allCostumes || index >= allCostumes.length)
			{
				return false;
			};
			return !isProtectedCostume(allCostumes[index]);
		}

		protected function isIndexSelectable(index:int):Boolean
		{
			if (selectionMode == MODE_IMPORT || selectionMode == MODE_PACK_IMPORT || selectionMode == MODE_PACK_EXPORT)
			{
				return index >= 0 && allCostumes && index < allCostumes.length;
			};
			return isCustomCostumeIndex(index);
		}

		protected function isMultiSelectMode():Boolean
		{
			return selectionMode == MODE_DELETE || selectionMode == MODE_EXPORT || selectionMode == MODE_IMPORT
				|| selectionMode == MODE_SORT || selectionMode == MODE_PACK_EXPORT || selectionMode == MODE_PACK_IMPORT
				|| selectionMode == MODE_PACK_DELETE;
		}

		protected function toggleIndexSelection(index:int):void
		{
			var pos:int = selectedIndices.indexOf(index);
			if (pos == -1)
			{
				selectedIndices.push(index);
			}
			else
			{
				selectedIndices.splice(pos, 1);
			};
		}

		protected function selectIndexRange(a:int, b:int, additive:Boolean):void
		{
			var from:int = Math.min(a, b);
			var to:int = Math.max(a, b);
			var i:int;
			if (!additive)
			{
				selectedIndices = [];
			};
			i = from;
			while (i <= to)
			{
				if (isIndexSelectable(i) && selectedIndices.indexOf(i) == -1)
				{
					selectedIndices.push(i);
				};
				i++;
			};
		}

		private function applyTileAlpha(index:int):void
		{
			var btn:*;
			var costume:Object;
			if (!containerButton || index < 0 || index >= containerButton.length)
			{
				return;
			};
			btn = containerButton[index];
			costume = allCostumes[index];
			btn.ButtonInstance.alpha = getTargetTileAlpha(index, costume);
		}

		protected function avoidTakenSelection():void
		{
			var i:int;
			if (!isCssCostumeTaken(selectedCostume))
			{
				return;
			};
			i = 0;
			while (allCostumes && i < allCostumes.length)
			{
				if (!isCssCostumeTaken(i))
				{
					selectedCostume = i;
					updateNameplate();
					return;
				};
				i++;
			};
		}

		protected function refreshTileAlphas():void
		{
			var i:int = 0;
			while (containerButton && i < containerButton.length)
			{
				applyTileAlpha(i);
				i++;
			};
		}
    }
}
