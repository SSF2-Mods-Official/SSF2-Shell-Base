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

    /** Color groups, layers, ownership and the color settings popup. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuGroups extends PaletteMakerMenuSelection
    {
        public function PaletteMakerMenuGroups()
        {
            super();
        }

		protected var isolateMode:Boolean = false;

		protected var baseCostumeData:Object = null;

		protected var sessionBaselineData:Object = null;

		protected var dragSeedColors:Object = null;

		protected var pulseBrightenFactor:Number = 1;

		protected var pulseActive:Boolean = false;

		/** Bases that get the temporary selection pulse (newly picked only). */
		protected var pulseTargetColors:Object = null;

		protected const PULSE_PEAK:Number = 1.55;

		internal static var settingHighlightUnchanged:Boolean = false;

		/** When true with highlight: compare vs original base colors; else vs loaded costume replacements. */
		internal static var settingUnchangedVsOriginal:Boolean = false;

		internal static var settingSortByOriginalColor:Boolean = false;

		protected var colorSettingsPopup:ColorSettingsPopup = null;

		protected var colorSettingsGroup:PaletteGroupSquare = null;

		protected var csWheelSnapshot:Object = null;

		protected var csEyedropperMode:Boolean = false;

		protected var fxColorSettingsMode:Boolean = false;

		protected function getSeedColorForBox(box:ColorSquare):*
		{
			var baseColor:uint;
			if (!box)
			{
				return 0;
			};
			baseColor = uint(box.colorValue);
			if (dragSeedColors && dragSeedColors.hasOwnProperty(String(baseColor)))
			{
				return uint(dragSeedColors[String(baseColor)]);
			};
			return getSessionReplacementForColor(baseColor);
		}

		/** Sort bases by replacement color (default) or original base when setting is on. */
		protected function sortSwatchBasesForDisplay(bases:Array):Array
		{
			var keys:Array;
			var i:int;
			var base:uint;
			if (!bases || bases.length == 0)
			{
				return [];
			};
			if (settingSortByOriginalColor)
			{
				return PaletteColorAnalysis.sortPaletteColorsForDisplay(bases);
			};
			keys = [];
			i = 0;
			while (i < bases.length)
			{
				base = uint(bases[i]);
				keys.push(getCurrentReplacementForColor(base));
				i++;
			};
			return PaletteColorAnalysis.sortPaletteColorsForDisplay(bases, keys);
		}

		protected function captureSelectionEntryColors(colorSet:Object):void
		{
			var key:String;
			var baseColor:uint;
			if (!colorSet)
			{
				return;
			};
			for (key in colorSet)
			{
				baseColor = uint(key);
				if (!selectionEntryReplacements.hasOwnProperty(String(baseColor)))
				{
					selectionEntryReplacements[String(baseColor)] = getCurrentReplacementForColor(baseColor);
				};
			};
		}

		protected function getCurrentReplacementForColor(baseColor:uint):uint
		{
			return findReplacementInPaletteData(currentPaletteData, baseColor);
		}

		protected function replacementForGroup(group:PaletteGroupSquare, baseColor:uint):uint
		{
			var partner:String;
			partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (group && partner && group.formName == partner && partnerPaletteData)
			{
				return replacementInPalette(partnerPaletteData, baseColor);
			};
			return getCurrentReplacementForColor(baseColor);
		}

		protected function replacementInPalette(paletteData:Object, baseColor:uint):uint
		{
			return findReplacementInPaletteData(paletteData, baseColor);
		}

		protected function getSessionReplacementForColor(baseColor:uint):uint
		{
			if (sessionBaselineData && replacementExistsInPaletteData(sessionBaselineData, baseColor))
			{
				return findReplacementInPaletteData(sessionBaselineData, baseColor);
			};
			return getCurrentReplacementForColor(baseColor);
		}

		private function findReplacementInPaletteData(paletteData:Object, baseColor:uint):uint
		{
			var swapRepl:*;
			var paRepl:*;
			if (!paletteData)
			{
				return baseColor;
			};
			swapRepl = lookupReplacementInBlock(paletteData.paletteSwap, baseColor);
			paRepl = lookupReplacementInBlock(paletteData.paletteSwapPA, baseColor);
			if (swapRepl != null)
			{
				return uint(swapRepl);
			};
			if (paRepl != null)
			{
				return uint(paRepl);
			};
			return baseColor;
		}

		private function replacementExistsInPaletteData(paletteData:Object, baseColor:uint):Boolean
		{
			if (!paletteData)
			{
				return false;
			};
			return lookupReplacementInBlock(paletteData.paletteSwap, baseColor) != null
				|| lookupReplacementInBlock(paletteData.paletteSwapPA, baseColor) != null;
		}

		/** Baseline replacement a color had in the loaded costume (or itself if none). */
		private function getOriginalBaselineForColor(baseColor:uint):uint
		{
			if (baseCostumeData && replacementExistsInPaletteData(baseCostumeData, baseColor))
			{
				return findReplacementInPaletteData(baseCostumeData, baseColor);
			};
			return baseColor;
		}

		protected function rebuildUnchangedColorLookup():void
		{
			var baseColor:uint;
			var current:uint;
			var baseline:uint;
			unchangedColorLookup = {};
			if (!settingHighlightUnchanged || !mixedBasePaletteData || !currentPaletteData)
			{
				return;
			};
			for each (baseColor in mixedBasePaletteData)
			{
				baseColor = uint(baseColor);
				current = getCurrentReplacementForColor(baseColor);
				baseline = settingUnchangedVsOriginal
					? baseColor
					: getOriginalBaselineForColor(baseColor);
				if (PaletteColorAnalysis.colorsMatch(current, baseline))
				{
					unchangedColorLookup[String(baseColor)] = true;
				};
			};
		}

		protected function trackFlashCycleIfAny():void
		{
			if (PaletteMakerAchievements.hasFlashCycle(currentPaletteData))
			{
				PaletteMakerAchievements.track("palette_flash_cycle");
			};
		}

		/** Look up one block's replacement for baseColor; returns null Object wrapper via found out-param. */
		protected function lookupReplacementInBlock(block:Object, baseColor:uint):*
		{
			var i:int;
			if (!block || !block.colors)
			{
				return null;
			};
			i = 0;
			while (i < block.colors.length)
			{
				if (PaletteColorAnalysis.colorsMatch(uint(block.colors[i]), baseColor))
				{
					if (block.replacements && i < block.replacements.length)
					{
						return uint(block.replacements[i]);
					};
					return baseColor;
				};
				i++;
			};
			return null;
		}

		protected function isGroupUnrecolored(group:PaletteGroupSquare):Boolean
		{
			var color:uint;
			var repl:uint;
			if (!group || !group.memberColors)
			{
				return true;
			};
			for each (color in group.memberColors)
			{
				repl = getCurrentReplacementForColor(uint(color));
				if (!PaletteColorAnalysis.colorsMatch(repl, uint(color)))
				{
					return false;
				};
			};
			return true;
		}

		protected function clearGroupSelections():void
		{
			var group:PaletteGroupSquare;
			for each (group in groupSquares)
			{
				if (group)
				{
					group.setSelected(false);
				};
			};
		}

		protected function isColorInAnyGroup(color:uint):Boolean
		{
			var group:PaletteGroupSquare;
			for each (group in groupSquares)
			{
				if (group && group.hasMember(color))
				{
					return true;
				};
			};
			return false;
		}

		/** Drop stale layer/pre-swatch keys for a removed member (all alpha siblings). */
		protected function clearGroupLayerKeysForColor(group:PaletteGroupSquare, color:uint):void
		{
			var key:String;
			var stored:uint;
			if (!group)
			{
				return;
			};
			if (group.layerReplacements)
			{
				for (key in group.layerReplacements)
				{
					stored = uint(key);
					if (PaletteColorAnalysis.colorsMatch(stored, color))
					{
						delete group.layerReplacements[key];
					};
				};
			};
			if (group.preSwatchReplacements)
			{
				for (key in group.preSwatchReplacements)
				{
					stored = uint(key);
					if (PaletteColorAnalysis.colorsMatch(stored, color))
					{
						delete group.preSwatchReplacements[key];
					};
				};
			};
		}

		protected function selectionMatchesActiveGroup():Boolean
		{
			var color:uint;
			var box:ColorSquare;
			var found:Boolean;
			var selectedCount:int;
			if (!activeGroup || !activeGroup.memberColors)
			{
				return true;
			};
			selectedCount = 0;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				selectedCount++;
				if (!activeGroup.hasMember(uint(box.colorValue)))
				{
					return false;
				};
			};
			for each (color in activeGroup.memberColors)
			{
				found = false;
				for each (box in ColorSquare.selectedBoxes)
				{
					if (box && !(box is PaletteGroupSquare) && PaletteColorAnalysis.colorsMatch(uint(box.colorValue), color))
					{
						found = true;
						break;
					};
				};
				if (!found)
				{
					return false;
				};
			};
			return selectedCount == activeGroup.memberColors.length;
		}

		protected function restoreSelectionToActiveGroup():void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var color:uint;
			if (!activeGroup || !m_subMenu || !m_subMenu.colorBoxBG)
			{
				return;
			};
			ColorSquare.beginBulkUpdate();
			ColorSquare.selectedBoxes.length = 0;
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare && !(child is PaletteGroupSquare))
				{
					box = child as ColorSquare;
					box.setSelected(false);
				};
				i++;
			};
			for each (color in activeGroup.memberColors)
			{
				i = 0;
				while (i < m_subMenu.colorBoxBG.numChildren)
				{
					child = m_subMenu.colorBoxBG.getChildAt(i);
					if (child is ColorSquare && !(child is PaletteGroupSquare))
					{
						box = child as ColorSquare;
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
		}

		protected function refreshColorSettingsHeader():void
		{
			var group:PaletteGroupSquare = getColorSettingsGroup();
			if (!colorSettingsPopup || !colorSettingsPopup.visible || !group)
			{
				return;
			};
			colorSettingsPopup.updateHeader(group.memberColors.length, group.useSwatch, group.matchAllMode);
		}

		protected function capturePreSwatchReplacements(group:PaletteGroupSquare):void
		{
			var member:uint;
			if (!group)
			{
				return;
			};
			if (group.preSwatchReplacements)
			{
				return;
			};
			group.preSwatchReplacements = {};
			for each (member in group.memberColors)
			{
				group.preSwatchReplacements[uint(member)] = getCurrentReplacementForColor(uint(member));
			};
		}

		protected function rememberPreSwatchForMembers(group:PaletteGroupSquare, members:Array):void
		{
			var member:uint;
			if (!group || !members)
			{
				return;
			};
			if (!group.preSwatchReplacements)
			{
				group.preSwatchReplacements = {};
			};
			for each (member in members)
			{
				if (group.preSwatchReplacements[uint(member)] == null)
				{
					group.preSwatchReplacements[uint(member)] = getCurrentReplacementForColor(uint(member));
				};
			};
		}

		/**
		 * Match-all: every editable member gets the exact swatch RGB.
		 * Normal swatch: primary is flat; other members keep shade relationships.
		 * Chromatic shade-neighbors of earlier groups are skipped earlier in
		 * applySwatchToGroupMembers (shade drag and match-all).
		 */
		protected function shouldFlatMatchSwatch(group:PaletteGroupSquare, member:uint):Boolean
		{
			if (!group)
			{
				return false;
			};
			if (group.matchAllMode)
			{
				return true;
			};
			return PaletteColorAnalysis.colorsMatch(uint(member), uint(group.primaryColor));
		}

		/**
		 * Earlier enabled group + member that is an exact or chromatic shade match
		 * for baseColor. Swatch/match-all paint skips only — not ownership/reorder.
		 * Returns { owner:PaletteGroupSquare, earlierBase:uint, exact:Boolean } or null.
		 */
		protected function findEarlierChromaticShadeMatch(group:PaletteGroupSquare, baseColor:uint):Object
		{
			var idx:int;
			var i:int;
			var earlier:PaletteGroupSquare;
			var member:*;
			var earlierBase:uint;
			if (!group || !groupSquares)
			{
				return null;
			};
			idx = groupSquares.indexOf(group);
			if (idx <= 0)
			{
				return null;
			};
			i = 0;
			while (i < idx)
			{
				earlier = groupSquares[i] as PaletteGroupSquare;
				if (earlier && earlier.groupEnabled != false && earlier.memberColors)
				{
					for each (member in earlier.memberColors)
					{
						earlierBase = uint(member);
						if (PaletteColorAnalysis.colorsMatch(earlierBase, baseColor))
						{
							return { "owner": earlier, "earlierBase": earlierBase, "exact": true };
						};
						if (PaletteColorAnalysis.isChromaticShadeNeighbor(earlierBase, baseColor))
						{
							return { "owner": earlier, "earlierBase": earlierBase, "exact": false };
						};
					};
				};
				i++;
			};
			return null;
		}

		protected function computeGroupSwatchReplacement(group:PaletteGroupSquare, baseColor:uint):uint
		{
			var oldPrimaryRepl:uint;
			var seedRepl:uint;
			oldPrimaryRepl = group.swatchRelativePrimary != 0
				? group.swatchRelativePrimary
				: getSessionReplacementForColor(uint(group.primaryColor));
			if (shouldFlatMatchSwatch(group, baseColor))
			{
				return applySwatchRgbKeepingAlpha(group.swatchColor);
			};
			seedRepl = replacementForGroup(group, baseColor);
			if (group.preSwatchReplacements && group.preSwatchReplacements[baseColor] != null)
			{
				seedRepl = uint(group.preSwatchReplacements[baseColor]);
			};
			return applySwatchRgbKeepingAlpha(
				PaletteColorAnalysis.recolorGroupAsShades(oldPrimaryRepl, group.swatchColor, seedRepl));
		}

		protected function refreshGroupFace(group:PaletteGroupSquare):void
		{
			var originals:Array;
			var replacements:Array;
			var color:uint;
			if (!group)
			{
				return;
			};
			originals = [];
			replacements = [];
			for each (color in group.memberColors)
			{
				originals.push(color);
				replacements.push(replacementForGroup(group, uint(color)));
			};
			group.redrawFace(PaletteColorAnalysis.averageColors(originals), PaletteColorAnalysis.averageColors(replacements));
		}

		protected function refreshAllGroupFaces():void
		{
			var group:PaletteGroupSquare;
			for each (group in groupSquares)
			{
				refreshGroupFace(group);
			};
			refreshPriorityMarkers();
		}

		/** Empty formName is the opened character. A partner group names Sheik or Giga Bowser. */
		protected function groupFormId(group:PaletteGroupSquare):String
		{
			if (group && group.formName && group.formName.length > 0)
			{
				return group.formName;
			};
			return statsName ? String(statsName) : "";
		}

		protected function boxFormId(box:ColorSquare):String
		{
			var partner:String;
			partner = PaletteMakerUtils.getLinkedFormPartner(statsName);
			if (box && box.altForm && partner)
			{
				return partner;
			};
			return statsName ? String(statsName) : "";
		}

		/** First enabled group of this form (left → right) that contains base owns it. */
		protected function getOwnerGroupForBase(baseColor:uint, formName:String = null):PaletteGroupSquare
		{
			var group:PaletteGroupSquare;
			var i:int;
			i = 0;
			while (i < groupSquares.length)
			{
				group = groupSquares[i] as PaletteGroupSquare;
				if (group && group.groupEnabled != false && group.hasMember(baseColor))
				{
					if (formName != null && groupFormId(group) != formName)
					{
						i++;
						continue;
					};
					return group;
				};
				i++;
			};
			return null;
		}

		/** False when an earlier enabled group owns this base and activeGroup is not that owner. */
		protected function canActiveGroupEditBase(baseColor:uint):Boolean
		{
			var owner:PaletteGroupSquare;
			if (!activeGroup)
			{
				return true;
			};
			// Only active-group members are editable while a group is active. The old
			// "!hasMember → allow" path let RGB-expanded / stray selected boxes recolor
			// colors outside the inverted (or group) set.
			if (!activeGroup.hasMember(baseColor))
			{
				return false;
			};
			// Disabled group: layer/match-all is off, but the user can still edit those
			// members into the costume palette (load starts groups disabled on purpose).
			if (activeGroup.groupEnabled == false)
			{
				return true;
			};
			owner = getOwnerGroupForBase(baseColor, groupFormId(activeGroup));
			if (owner != null && owner != activeGroup)
			{
				return false;
			};
			return true;
		}

		/** False when an earlier enabled group of the same form owns this base. */
		protected function canGroupEditBase(group:PaletteGroupSquare, baseColor:uint):Boolean
		{
			var owner:PaletteGroupSquare;
			if (!group)
			{
				return true;
			};
			if (group.groupEnabled == false)
			{
				return false;
			};
			owner = getOwnerGroupForBase(baseColor, groupFormId(group));
			if (owner != null && owner != group)
			{
				return false;
			};
			return true;
		}

		/**
		 * Exact-owner shortName badge; red ! when the active group lists the color
		 * but an earlier enabled group owns it.
		 */
		protected function refreshPriorityMarkers():void
		{
			var i:int;
			var child:*;
			var box:ColorSquare;
			var baseColor:uint;
			var owner:PaletteGroupSquare;
			var claimCount:int;
			var g:PaletteGroupSquare;
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
					baseColor = uint(box.colorValue);
					owner = getOwnerGroupForBase(baseColor, boxFormId(box));
					claimCount = 0;
					for each (g in groupSquares)
					{
						if (g && g.groupEnabled != false && g.hasMember(baseColor) && groupFormId(g) == boxFormId(box))
						{
							claimCount++;
						};
					};
					if (owner)
					{
						box.setOwnerBadge(owner.getShortName());
					}
					else
					{
						box.setOwnerBadge("");
					};
					if (activeGroup && activeGroup.groupEnabled != false
						&& activeGroup.hasMember(baseColor)
						&& owner && owner != activeGroup)
					{
						box.setPriorityBang(true);
					}
					else if (claimCount > 1 && activeGroup && activeGroup == owner)
					{
						box.setPriorityBang(false);
					}
					else
					{
						box.setPriorityBang(false);
					};
				};
				i++;
			};
		}

		protected function onGroupDragReorder(group:PaletteGroupSquare, stageX:Number):void
		{
			var localX:Number;
			var targetIndex:int;
			var fromIndex:int;
			if (!group || !m_subMenu || !m_subMenu.colorBoxBG || !groupSquares)
			{
				return;
			};
			fromIndex = groupSquares.indexOf(group);
			if (fromIndex < 0)
			{
				return;
			};
			localX = m_subMenu.colorBoxBG.globalToLocal(new Point(stageX, 0)).x;
			targetIndex = int(Math.floor((localX - BOX_POS_X) / (BOX_SIZE + BOX_OFFSET)));
			if (targetIndex < 0)
			{
				targetIndex = 0;
			};
			if (targetIndex > groupSquares.length - 1)
			{
				targetIndex = groupSquares.length - 1;
			};
			if (targetIndex == fromIndex)
			{
				layoutGroupRow();
				return;
			};
			groupSquares.splice(fromIndex, 1);
			if (targetIndex > fromIndex)
			{
				targetIndex--;
			};
			groupSquares.splice(targetIndex, 0, group);
			layoutGroupRow();
			refreshPriorityMarkers();
		}

		private function serializeColorGroups():Array
		{
			var out:Array = [];
			var group:PaletteGroupSquare;
			for each (group in groupSquares)
			{
				if (!group)
				{
					continue;
				};
				out.push(ColorGroupPersist.serializeMembership(group));
			};
			return out;
		}

		protected function saveColorGroups():void
		{
			var so:SharedObject;
			var key:String;
			if (!statsName)
			{
				return;
			};
			key = String(statsName);
			try
			{
				so = SharedObject.getLocal("ssf2_palette_maker_settings");
				if (!so.data.colorGroups)
				{
					so.data.colorGroups = {};
				};
				so.data.colorGroups[key] = serializeColorGroups();
				so.flush();
			}
			catch (err:Error)
			{
				trace("[Palette Maker] Failed to save color groups:", err.message);
			};
		}

		/**
		 * Rebuild groupSquares from SharedObject for current statsName.
		 * Returns true when a saved entry was applied (including intentional empty []).
		 * Returns false when the save is missing or corrupt.
		 */
		/** Match member colors against mixedBase via colorsMatch (not strict uint equality). */
		protected function resolveMemberAgainstMixedBase(color:uint, filtered:Array, list:Array = null):Boolean
		{
			var existing:*;
			var matched:uint;
			var j:int;
			var source:Array;
			source = list != null ? list : mixedBasePaletteData;
			if (!source || source.length == 0)
			{
				if (list != null)
				{
					return false;
				};
				j = 0;
				while (j < filtered.length)
				{
					if (PaletteColorAnalysis.colorsMatch(uint(filtered[j]), color))
					{
						return false;
					};
					j++;
				};
				filtered.push(color);
				return true;
			};
			for each (existing in source)
			{
				matched = uint(existing);
				if (PaletteColorAnalysis.colorsMatch(matched, color))
				{
					j = 0;
					while (j < filtered.length)
					{
						if (PaletteColorAnalysis.colorsMatch(uint(filtered[j]), matched))
						{
							return false;
						};
						j++;
					};
					filtered.push(matched);
					return true;
				};
			};
			return false;
		}

		protected function nextGroupName():String
		{
			return "Group " + indexToGroupLetter(groupSquares.length);
		}

		private function indexToGroupLetter(index:int):String
		{
			var n:int = index;
			var result:String = "";
			var rem:int;
			do
			{
				rem = n % 26;
				result = String.fromCharCode(65 + rem) + result;
				n = int(n / 26) - 1;
			} while (n >= 0);
			return result;
		}

		/** Wipe persisted color groups once so AUTO naming / auto flags apply cleanly going forward. */
		protected function migrateColorGroupsSchema(so:SharedObject):void
		{
			var schema:int = 3;
			if (!so || !so.data)
			{
				return;
			};
			if (int(so.data.colorGroupsSchema) >= schema)
			{
				return;
			};
			so.data.colorGroups = {};
			so.data.colorGroupsSchema = schema;
			try
			{
				so.flush();
			}
			catch (err:Error)
			{
			};
			trace("[Palette Maker] Cleared color group data for AUTO schema migration");
		}

		protected function refreshIsolateSwatchVisuals():void
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
				if (child is ColorSquare)
				{
					box = child as ColorSquare;
					if (!isolateMode || box.isSelected)
					{
						box.alpha = 1;
					}
					else
					{
						box.alpha = 0.35;
					};
				};
				i++;
			};
		}

		protected function buildIsolatedPalette(block:Object, keepLookup:Object=null):Object
		{
			var selectedLookup:Object;
			var box:ColorSquare;
			var colors:Array;
			var replacements:Array;
			var newReplacements:Array;
			var i:int;
			if (!block || !block.colors || !block.replacements)
			{
				return block;
			};
			selectedLookup = keepLookup;
			if (!selectedLookup)
			{
				selectedLookup = {};
				for each (box in ColorSquare.selectedBoxes)
				{
					if (box)
					{
						selectedLookup[uint(box.colorValue)] = true;
					};
				};
			};
			colors = block.colors as Array;
			replacements = block.replacements as Array;
			newReplacements = [];
			i = 0;
			while (i < colors.length)
			{
				if (selectedLookup[uint(colors[i])])
				{
					newReplacements.push(replacements[i]);
				}
				else
				{
					newReplacements.push(PaletteColorAnalysis.darkenForIsolate(uint(replacements[i])));
				};
				i++;
			};
			return {"colors": colors, "replacements": newReplacements};
		}

		protected function isBaseInSwatchLockedGroup(baseColor:uint):Boolean
		{
			var group:PaletteGroupSquare;
			// Only hard-locked groups block per-swatch slider edits.
			// useSwatch alone must not block slider edits.
			for each (group in groupSquares)
			{
				if (group && group.locked && group.hasMember(baseColor))
				{
					return true;
				};
			};
			return false;
		}

		protected function ensureGroupPrimary(group:PaletteGroupSquare):void
		{
			var box:ColorSquare;
			if (!group)
			{
				return;
			};
			if (group.primaryColor && group.hasMember(group.primaryColor))
			{
				return;
			};
			for each (box in ColorSquare.selectedBoxes)
			{
				if (box && !(box is PaletteGroupSquare) && group.hasMember(uint(box.colorValue)))
				{
					group.primaryColor = uint(box.colorValue);
					return;
				};
			};
			if (group.memberColors && group.memberColors.length > 0)
			{
				group.primaryColor = uint(group.memberColors[0]);
			};
		}

		protected function refreshPrimaryBadges():void
		{
			var i:int;
			var child:DisplayObject;
			var box:ColorSquare;
			var primary:uint = 0;
			var hasPrimary:Boolean = false;
			if (activeGroup && activeGroup.primaryColor)
			{
				primary = uint(activeGroup.primaryColor);
				hasPrimary = activeGroup.hasMember(primary);
			};
			i = 0;
			while (i < m_subMenu.colorBoxBG.numChildren)
			{
				child = m_subMenu.colorBoxBG.getChildAt(i);
				if (child is ColorSquare && !(child is PaletteGroupSquare))
				{
					box = child as ColorSquare;
					box.setPrimaryBadge(hasPrimary && PaletteColorAnalysis.colorsMatch(uint(box.colorValue), primary));
				};
				i++;
			};
		}

		protected function findExactGroupForSelection():PaletteGroupSquare
		{
			var selected:Array = [];
			var box:ColorSquare;
			var group:PaletteGroupSquare;
			var color:uint;
			var allIn:Boolean;
			var sameSize:Boolean;
			var formName:String;
			var mixed:Boolean;
			formName = "";
			mixed = false;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (box && !(box is PaletteGroupSquare))
				{
					color = uint(box.colorValue);
					if (selected.indexOf(color) == -1)
					{
						selected.push(color);
					};
					if (formName.length == 0)
					{
						formName = boxFormId(box);
					}
					else if (boxFormId(box) != formName)
					{
						mixed = true;
					};
				};
			};
			if (selected.length == 0 || mixed)
			{
				return null;
			};
			for each (group in groupSquares)
			{
				if (!group || !group.memberColors)
				{
					continue;
				};
				if (groupFormId(group) != formName)
				{
					continue;
				};
				sameSize = group.memberColors.length == selected.length;
				if (!sameSize)
				{
					continue;
				};
				allIn = true;
				for each (color in selected)
				{
					if (!group.hasMember(color))
					{
						allIn = false;
						break;
					};
				};
				if (allIn)
				{
					return group;
				};
			};
			return null;
		}

		protected function getColorSettingsGroup():PaletteGroupSquare
		{
			if (colorSettingsGroup)
			{
				return colorSettingsGroup;
			};
			return activeGroup;
		}

		protected function onCsWheelOpen():void
		{
			if (!csWheelSnapshot)
			{
				csWheelSnapshot = captureSnapshot();
			};
			var group:PaletteGroupSquare = getColorSettingsGroup();
			if (group)
			{
				capturePreSwatchReplacements(group);
			};
		}

		protected function onCsEyedropper():void
		{
			exitPrimaryPickMode();
			csEyedropperMode = true;
			Ssf2.MultiplayerManager.notify("Click sprite or PA to sample");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
		}

		protected function onCsCancelPrimaryPick():void
		{
			cancelPrimaryPick("Primary change cancelled");
		}

		protected function cancelPrimaryPick(message:String):void
		{
			exitPrimaryPickMode();
			if (colorSettingsPopup && colorSettingsGroup)
			{
				colorSettingsPopup.visible = true;
				colorSettingsPopup.mouseEnabled = true;
				colorSettingsPopup.mouseChildren = true;
			};
			if (message)
			{
				Ssf2.MultiplayerManager.notify(message);
			};
			Ssf2.SoundQueue.instance.playSoundEffect("menu_back");
		}

		protected function exitPrimaryPickMode():void
		{
			ColorSquare.primaryPickMode = false;
			ColorSquare.canPrimaryPick = null;
			ColorSquare.onPrimaryPick = null;
			ColorSquare.onPrimaryPickCancel = null;
			if (colorSettingsPopup)
			{
				colorSettingsPopup.setPrimaryPickMode(false);
			};
		}

		protected function onCsToggleLock():void
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
			group.locked = !group.locked;
			if (colorSettingsPopup)
			{
				colorSettingsPopup.setLocked(group.locked);
			};
			saveColorGroups();
			Ssf2.MultiplayerManager.notify(group.locked ? "Group locked" : "Group unlocked");
			Ssf2.SoundQueue.instance.playSoundEffect("menu_select");
			if (group.locked)
			{
				PaletteMakerAchievements.track("group_locked");
			};
		}

		protected function applyPulseToPaletteBlock(block:Object):void
		{
			var i:int;
			var baseColor:uint;
			var repl:uint;
			var pulseT:Number;
			if (!block || !block.colors || !block.replacements || !pulseTargetColors)
			{
				return;
			};
			pulseT = Math.max(0, Math.min(1, (pulseBrightenFactor - 1) / (PULSE_PEAK - 1)));
			i = 0;
			while (i < block.colors.length && i < block.replacements.length)
			{
				baseColor = uint(block.colors[i]);
				if (pulseTargetColors[baseColor] || pulseTargetColors[String(baseColor)])
				{
					repl = uint(block.replacements[i]);
					block.replacements[i] = PaletteColorAnalysis.blendColors(repl, PaletteColorAnalysis.complementaryColor(repl), pulseT);
				};
				i++;
			};
		}

		protected function refreshSelectedSwatchTriangles():void
		{
			var box:ColorSquare;
			var repl:uint;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (!box || (box is PaletteGroupSquare))
				{
					continue;
				};
				repl = getCurrentReplacementForColor(uint(box.colorValue));
				if (pulseActive && pulseBrightenFactor != 1 && pulseTargetColors
					&& (pulseTargetColors[uint(box.colorValue)] || pulseTargetColors[String(uint(box.colorValue))]))
				{
					var pulseT:Number = Math.max(0, Math.min(1, (pulseBrightenFactor - 1) / (PULSE_PEAK - 1)));
					repl = PaletteColorAnalysis.blendColors(repl, PaletteColorAnalysis.complementaryColor(repl), pulseT);
				};
				box.updateIndicator(repl);
			};
		}
    }
}
