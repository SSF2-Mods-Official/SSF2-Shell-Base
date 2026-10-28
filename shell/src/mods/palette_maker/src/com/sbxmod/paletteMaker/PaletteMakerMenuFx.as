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

    /** Recolor-effects (FX) mode: FX groups, strip selection, filters on fighter/projectiles/stage. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuFx extends PaletteMakerMenuColorSheets
    {
        public function PaletteMakerMenuFx()
        {
            super();
        }

		/** linkage -> true for pending strip selection before NG. */
		protected var fxStripSelectedLinkages:Object = {};

		protected var activeFxGroupId:String = null;

		/** RE mode: PaletteGroupSquare chips for fxGroups (not body color groups). */
		protected var fxGroupSquares:Array = [];

		/** ProjectilesArray key <-> LinkageID alias map for current scan. */
		private var projectileFxAliasCacheStats:String = null;

		private var projectileFxAliasCache:Object = null;

		/** FX keys stay off the body swatch row (preview is strip filters + paletteSwapFX data). */
		protected function syncFxColorsIntoSwatches(fx:Object):void
		{
			return;
		}

		/** Activate first fxGroups entry when RE edits need a target. */
		protected function ensureActiveFxGroup():Object
		{
			var groups:Array;
			var group:Object;
			if (!currentPaletteData)
			{
				return null;
			};
			FxRecolorUtils.ensureFxGroups(currentPaletteData);
			group = getActiveFxGroup();
			if (group)
			{
				return group;
			};
			groups = currentPaletteData.fxGroups as Array;
			if (groups && groups.length > 0 && groups[0])
			{
				activeFxGroupId = String(groups[0].id);
				return groups[0];
			};
			return null;
		}

		/** Mirror active FX group HSBC into legacy fx* without reading sliders. */
		protected function mirrorLegacyFxFromActiveGroup():void
		{
			var group:Object;
			var groups:Array;
			if (!currentPaletteData)
			{
				return;
			};
			groups = currentPaletteData.fxGroups as Array;
			group = getActiveFxGroup();
			if (!group && groups && groups.length > 0)
			{
				group = groups[0];
			};
			currentPaletteData.fxHue = group ? (Number(group.hue) || 0) : 0;
			currentPaletteData.fxSaturation = group ? (Number(group.saturation) || 0) : 0;
			currentPaletteData.fxBrightness = group ? (Number(group.brightness) || 0) : 0;
			currentPaletteData.fxContrast = group ? (Number(group.contrast) || 0) : 0;
			if (currentPaletteData.paletteSwapFX)
			{
				delete currentPaletteData.paletteSwapFX;
			};
		}

		/** Persist active FX group HSBC (+ mirror first adjust into legacy fx* for older readers). */
		protected function writeRecolorEffectsFxFields():void
		{
			var fields:Object;
			var group:Object;
			var groups:Array;
			if (!currentPaletteData)
			{
				return;
			};
			FxRecolorUtils.ensureFxGroups(currentPaletteData);
			fields = {
				hue: getRecolorEffectsHueDegrees(),
				saturation: pmLevelToEngineAdjust(getCurrentSaturationLevel()),
				brightness: 0,
				contrast: pmLevelToEngineAdjust(getCurrentBrightnessLevel())
			};
			group = getActiveFxGroup();
			if (group)
			{
				group.hue = fields.hue;
				group.saturation = fields.saturation;
				group.brightness = fields.brightness;
				group.contrast = fields.contrast;
			};
			// Legacy mirror: first group with adjust, else zeros.
			groups = currentPaletteData.fxGroups as Array;
			group = (groups && groups.length > 0) ? groups[0] : null;
			currentPaletteData.fxHue = group ? (Number(group.hue) || 0) : 0;
			currentPaletteData.fxSaturation = group ? (Number(group.saturation) || 0) : 0;
			currentPaletteData.fxBrightness = group ? (Number(group.brightness) || 0) : 0;
			currentPaletteData.fxContrast = group ? (Number(group.contrast) || 0) : 0;
			if (currentPaletteData.paletteSwapFX)
			{
				delete currentPaletteData.paletteSwapFX;
			};
		}

		protected function getActiveFxGroup():Object
		{
			if (!currentPaletteData)
			{
				return null;
			};
			FxRecolorUtils.ensureFxGroups(currentPaletteData);
			if (activeFxGroupId)
			{
				return FxRecolorUtils.getFxGroupById(currentPaletteData, activeFxGroupId);
			};
			return null;
		}

		/** Place H/S/B arrows from active FX group (or legacy fx*). */
		protected function syncRecolorEffectsSlidersFromFxFields():void
		{
			var hue:Number;
			var sat:Number;
			var contrast:Number;
			var percent:Number;
			var group:Object;
			if (!currentPaletteData)
			{
				return;
			};
			group = getActiveFxGroup();
			if (group)
			{
				hue = Number(group.hue) || 0;
				sat = Number(group.saturation) || 0;
				contrast = Number(group.contrast) || 0;
			}
			else
			{
				hue = Number(currentPaletteData.fxHue) || 0;
				sat = Number(currentPaletteData.fxSaturation) || 0;
				contrast = Number(currentPaletteData.fxContrast) || 0;
			};
			if (colorBounds && colorArrow)
			{
				percent = (hue + 180) / 360;
				colorArrow.x = colorBounds.x + percent * colorBounds.width;
			};
			if (saturationBounds && saturationArrow)
			{
				percent = engineAdjustToPmLevel(sat) / 2;
				saturationArrow.x = saturationBounds.x + percent * saturationBounds.width;
			};
			if (brightnessBounds && brightnessArrow)
			{
				percent = engineAdjustToPmLevel(contrast) / 2;
				brightnessArrow.x = brightnessBounds.x + percent * brightnessBounds.width;
			};
			try
			{
				if (m_subMenu && m_subMenu.brightness && m_subMenu.brightness.lvl_txt)
				{
					TextField(m_subMenu.brightness.lvl_txt).text = contrast.toFixed(0);
				};
				if (m_subMenu && m_subMenu.saturation && m_subMenu.saturation.lvl_txt)
				{
					TextField(m_subMenu.saturation.lvl_txt).text = sat.toFixed(0);
				};
			}
			catch (err:Error)
			{
			};
		}

		private function engineAdjustToPmLevel(value:Number):Number
		{
			return Math.max(0, Math.min(2, 1 + (value || 0) / 100));
		}

		/** Map PM 0..2 slider (1 = identity) to engine AdjustColor -100..100. */
		protected function pmLevelToEngineAdjust(level:Number):Number
		{
			return Math.max(-100, Math.min(100, (level - 1) * 100));
		}

		protected function getRecolorEffectsHueDegrees():Number
		{
			var percent:Number;
			if (!colorBounds || !colorArrow)
			{
				return 0;
			};
			percent = (colorArrow.x - colorBounds.x) / colorBounds.width;
			return Math.max(-180, Math.min(180, percent * 360 - 180));
		}

		/** Engine adjust from active FX group. */
		protected function getRecolorEffectsEngineAdjust():Object
		{
			var group:Object;
			group = getActiveFxGroup();
			if (group)
			{
				return {
					hue: Number(group.hue) || 0,
					saturation: Number(group.saturation) || 0,
					brightness: Number(group.brightness) || 0,
					contrast: Number(group.contrast) || 0
				};
			};
			if (currentPaletteData)
			{
				return {
					hue: Number(currentPaletteData.fxHue) || 0,
					saturation: Number(currentPaletteData.fxSaturation) || 0,
					brightness: Number(currentPaletteData.fxBrightness) || 0,
					contrast: Number(currentPaletteData.fxContrast) || 0
				};
			};
			return {
				hue: getRecolorEffectsHueDegrees(),
				saturation: pmLevelToEngineAdjust(getCurrentSaturationLevel()),
				brightness: 0,
				contrast: pmLevelToEngineAdjust(getCurrentBrightnessLevel())
			};
		}

		protected function clearRecolorEffectsFiltersPreview():void
		{
			var i:int;
			var disp:DisplayObject;
			var stageData:*;
			if (uniquePaSprites)
			{
				i = 0;
				while (i < uniquePaSprites.length)
				{
					disp = uniquePaSprites[i] as DisplayObject;
					if (disp)
					{
						FxRecolorUtils.clearFxDisplayAdjust(disp);
					};
					i++;
				};
			};
			try
			{
				stageData = Ssf2.GameController.stageData;
			}
			catch (err:Error)
			{
				stageData = null;
			};
			clearFxFiltersOnObjectList(tryGetStageObjectList(stageData, "Projectiles"), false);
			clearFxFiltersOnObjectList(tryGetStageObjectList(stageData, "Items"), false);
			applyRecolorEffectsFiltersToStageLayers(stageData, null);
		}

		private function clearFxFiltersOnObjectList(list:*, skipOwnerCheck:Boolean):void
		{
			var i:int;
			var n:int;
			var obj:*;
			var mc:DisplayObject;
			var owner:*;
			if (!list)
			{
				return;
			};
			try
			{
				n = int(list.length);
			}
			catch (lenErr:Error)
			{
				return;
			};
			i = 0;
			while (i < n)
			{
				try
				{
					obj = list[i];
					if (!obj)
					{
						i++;
						continue;
					};
					if (!skipOwnerCheck && player)
					{
						owner = null;
						try { owner = obj.getOwner(); } catch (e1:Error) {
							try { owner = obj.Owner != null ? obj.Owner : obj["m_owner"]; } catch (e2:Error) { owner = null; };
						};
						if (owner != null && owner !== player)
						{
							i++;
							continue;
						};
					};
					mc = (obj is DisplayObject) ? obj as DisplayObject
						: ((obj.MC is DisplayObject) ? obj.MC as DisplayObject
						: ((obj.mc is DisplayObject) ? obj.mc as DisplayObject : null));
					if (mc)
					{
						FxRecolorUtils.clearFxDisplayAdjust(mc);
					};
				}
				catch (itemErr:Error)
				{
				};
				i++;
			};
		}

		/** Preview fxGroups on strip: active group members first, then pending selection, then saved groups. */
		protected function applyRecolorEffectsFiltersToStrip():void
		{
			var i:int;
			var disp:DisplayObject;
			var linkage:String;
			var group:Object;
			var active:Object;
			var preview:Object;
			var aliases:Object;
			if (!recolorEffectsMode || !uniquePaSprites || !currentPaletteData)
			{
				return;
			};
			FxRecolorUtils.ensureFxGroups(currentPaletteData);
			active = getActiveFxGroup();
			preview = buildTransientFxPreviewGroup();
			aliases = getProjectileFxAliasMapCached();
			i = 0;
			while (i < uniquePaSprites.length)
			{
				disp = uniquePaSprites[i] as DisplayObject;
				if (disp)
				{
					linkage = resolveFxStripLinkage(disp);
					group = null;
					if (active && linkageInFxGroup(active, linkage, aliases))
					{
						group = active;
					}
					else if (linkage && fxStripSelectedLinkages[linkage] && preview
						&& FxRecolorUtils.fxGroupHasAdjust(preview))
					{
						group = preview;
					}
					else
					{
						group = FxRecolorUtils.findFxGroupForLinkage(currentPaletteData, linkage, aliases);
					};
					if (group && FxRecolorUtils.fxGroupHasAdjust(group))
					{
						applyFxFiltersToStripDisplay(disp, group);
					}
					else
					{
						applyFxFiltersToStripDisplay(disp, null);
					};
				};
				i++;
			};
			refreshFxStripHighlights();
		}

		/**
		 * Strip cells are Sprite+Bitmap from disk cache — parent ColorMatrixFilter often
		 * does not visibly update. Bake HSBC/color into a clone of pristine BitmapData.
		 */
		private function applyFxFiltersToStripDisplay(disp:DisplayObject, group:Object):void
		{
			var holder:Sprite;
			var bmp:Bitmap;
			var pristine:BitmapData;
			var bd:BitmapData;
			var old:BitmapData;
			if (!disp)
			{
				return;
			};
			holder = disp as Sprite;
			pristine = fxStripPristineBd[disp] as BitmapData;
			if (holder && holder.numChildren > 0 && pristine)
			{
				bmp = holder.getChildAt(0) as Bitmap;
				if (bmp)
				{
					old = bmp.bitmapData;
					if (!group || !FxRecolorUtils.fxGroupHasAdjust(group))
					{
						bmp.bitmapData = pristine.clone();
						if (old && old != pristine)
						{
							try { old.dispose(); } catch (d0:Error) {};
						};
						FxRecolorUtils.clearFxDisplayAdjust(holder);
						FxRecolorUtils.clearFxDisplayAdjust(bmp);
						return;
					};
					bd = pristine.clone();
					FxRecolorUtils.applyFxGroupToBitmapData(bd, group);
					bmp.bitmapData = bd;
					if (old && old != pristine && old != bd)
					{
						try { old.dispose(); } catch (d1:Error) {};
					};
					FxRecolorUtils.clearFxDisplayAdjust(holder);
					FxRecolorUtils.clearFxDisplayAdjust(bmp);
					return;
				};
			};
			if (group && FxRecolorUtils.fxGroupHasAdjust(group))
			{
				FxRecolorUtils.applyFxGroupFilters(disp, group);
			}
			else
			{
				FxRecolorUtils.clearFxDisplayAdjust(disp);
			};
		}

		/** Transient HSBC/color from current RE sliders for selected-but-not-NG strip cells. */
		private function buildTransientFxPreviewGroup():Object
		{
			var active:Object;
			var color:uint;
			active = getActiveFxGroup();
			color = 0;
			if (active)
			{
				color = PaletteMakerUtils.coerceColorValue(active.color);
			};
			return {
				id: "_preview",
				name: "preview",
				linkages: [],
				color: color,
				hue: getRecolorEffectsHueDegrees(),
				saturation: pmLevelToEngineAdjust(getCurrentSaturationLevel()),
				brightness: 0,
				contrast: pmLevelToEngineAdjust(getCurrentBrightnessLevel())
			};
		}

		private function linkageInFxGroup(group:Object, linkage:String, aliases:Object = null):Boolean
		{
			var links:Array;
			var low:String;
			var i:int;
			var link:String;
			if (!group || !linkage)
			{
				return false;
			};
			links = (group.linkages is Array) ? (group.linkages as Array) : [];
			low = String(linkage).toLowerCase();
			i = 0;
			while (i < links.length)
			{
				link = String(links[i] || "").toLowerCase();
				if (link && FxRecolorUtils.fxLinkagesMatch(link, low, aliases))
				{
					return true;
				};
				i++;
			};
			return false;
		}

		protected function getProjectileFxAliasMapCached():Object
		{
			var scan:String;
			scan = PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName);
			if (projectileFxAliasCache && projectileFxAliasCacheStats == scan)
			{
				return projectileFxAliasCache;
			};
			projectileFxAliasCacheStats = scan;
			projectileFxAliasCache = FxRecolorUtils.buildProjectileFxAliasMap(scan);
			return projectileFxAliasCache;
		}

		protected function applyRecolorEffectsFiltersToLiveProjectiles():void
		{
			var stageData:*;
			var list:*;
			if (!recolorEffectsMode || !currentPaletteData)
			{
				return;
			};
			try
			{
				stageData = Ssf2.GameController.stageData;
			}
			catch (err:Error)
			{
				return;
			};
			list = tryGetStageObjectList(stageData, "Projectiles");
			if (list)
			{
				applyFxGroupsToObjectList(list, false);
			};
			list = tryGetStageObjectList(stageData, "Items");
			if (list)
			{
				applyFxGroupsToObjectList(list, false);
			};
			applyRecolorEffectsFiltersToStageLayers(stageData, null);
		}

		private function applyFxGroupsToObjectList(list:*, skipOwnerCheck:Boolean):void
		{
			var i:int;
			var n:int;
			var obj:*;
			var mc:DisplayObject;
			var owner:*;
			var linkage:String;
			var group:Object;
			if (!list || !currentPaletteData)
			{
				return;
			};
			try
			{
				n = int(list.length);
			}
			catch (lenErr:Error)
			{
				return;
			};
			i = 0;
			while (i < n)
			{
				try
				{
					obj = list[i];
					if (!obj)
					{
						i++;
						continue;
					};
					if (!skipOwnerCheck && player)
					{
						owner = null;
						try { owner = obj.getOwner(); } catch (e1:Error) {
							try { owner = obj.Owner != null ? obj.Owner : obj["m_owner"]; } catch (e2:Error) { owner = null; };
						};
						if (owner != null && owner !== player)
						{
							i++;
							continue;
						};
					};
					mc = (obj is DisplayObject) ? obj as DisplayObject
						: ((obj.MC is DisplayObject) ? obj.MC as DisplayObject
						: ((obj.mc is DisplayObject) ? obj.mc as DisplayObject : null));
					if (mc)
					{
						linkage = FxRecolorUtils.resolveDisplayFxLinkage(mc, obj["proj"] || obj["id"]);
						if ((!linkage || linkage.length == 0) && obj)
						{
							try
							{
								if (obj.LinkageID)
								{
									linkage = String(obj.LinkageID).toLowerCase();
								};
							}
							catch (lidErr:Error)
							{
							};
						};
						group = FxRecolorUtils.findFxGroupForLinkage(currentPaletteData, linkage, getProjectileFxAliasMapCached());
						if (group)
						{
							FxRecolorUtils.applyFxSwapOrFilters(
								mc, currentPaletteData, group, 8, 200);
						}
						else
						{
							FxRecolorUtils.clearFxDisplayAdjust(mc);
						};
					};
				}
				catch (itemErr:Error)
				{
				};
				i++;
			};
		}

		protected function resolveFxStripLinkage(disp:DisplayObject):String
		{
			var mapped:*;
			if (!disp)
			{
				return null;
			};
			mapped = fxStripLinkageMap[disp];
			if (mapped != null && String(mapped).length > 0)
			{
				return String(mapped).toLowerCase();
			};
			return FxRecolorUtils.resolveDisplayFxLinkage(disp);
		}

		protected function countFxStripSelection():int
		{
			var k:String;
			var n:int;
			n = 0;
			for (k in fxStripSelectedLinkages)
			{
				if (fxStripSelectedLinkages[k])
				{
					n++;
				};
			};
			return n;
		}

		protected function refreshFxStripHighlights():void
		{
			var i:int;
			var disp:DisplayObject;
			var linkage:String;
			var selected:Boolean;
			var inActive:Boolean;
			var group:Object;
			var hw:Number;
			var hh:Number;
			if (!uniquePaSprites)
			{
				return;
			};
			group = getActiveFxGroup();
			i = 0;
			while (i < uniquePaSprites.length)
			{
				disp = uniquePaSprites[i] as DisplayObject;
				if (!disp)
				{
					i++;
					continue;
				};
				linkage = resolveFxStripLinkage(disp);
				selected = linkage && fxStripSelectedLinkages[linkage];
				inActive = false;
				if (group && linkage && (group.linkages is Array))
				{
					inActive = (group.linkages as Array).indexOf(linkage) >= 0
						|| (group.linkages as Array).length == 0;
				};
				try
				{
					if (disp is Sprite)
					{
						hw = Math.min(Math.abs(disp.width), UNIQUE_FX_CELL_MAX);
						hh = Math.min(Math.abs(disp.height), UNIQUE_FX_CELL_MAX);
						if (hw < 8) hw = 8;
						if (hh < 8) hh = 8;
						(disp as Sprite).graphics.clear();
						if (selected)
						{
							(disp as Sprite).graphics.lineStyle(2, 0x44CCFF, 1);
							(disp as Sprite).graphics.drawRect(-2, -2, hw + 4, hh + 4);
						}
						else if (inActive)
						{
							(disp as Sprite).graphics.lineStyle(1, 0xFFAA44, 0.85);
							(disp as Sprite).graphics.drawRect(-1, -1, hw + 2, hh + 2);
						};
					};
				}
				catch (err:Error)
				{
				};
				i++;
			};
		}

		protected function clearFxGroupSquares():void
		{
			var i:int;
			var group:PaletteGroupSquare;
			if (!fxGroupSquares)
			{
				fxGroupSquares = [];
				return;
			};
			i = 0;
			while (i < fxGroupSquares.length)
			{
				group = fxGroupSquares[i] as PaletteGroupSquare;
				if (group)
				{
					group.killEvents();
					if (group.parent)
					{
						group.parent.removeChild(group);
					};
				};
				i++;
			};
			fxGroupSquares = [];
		}

		/** Stage-attached effects owned by the studio fighter (uid match). */
		private function applyRecolorEffectsFiltersToStageLayers(stageData:*, fields:Object):void
		{
			var uid:int;
			if (!stageData || !player)
			{
				return;
			};
			try
			{
				uid = int(player.UID);
			}
			catch (uidErr:Error)
			{
				try
				{
					uid = int(player["m_uid"]);
				}
				catch (uidErr2:Error)
				{
					return;
				};
			};
			if (uid == 0)
			{
				return;
			};
			applyFxFiltersToStageContainer(tryGetStageDisplayContainer(stageData, "StageRef"), uid, fields);
			applyFxFiltersToStageContainer(tryGetStageDisplayContainer(stageData, "StageEffectsRef"), uid, fields);
		}

		private function tryGetStageDisplayContainer(stageData:*, prop:String):DisplayObjectContainer
		{
			var obj:*;
			if (!stageData || !prop)
			{
				return null;
			};
			try
			{
				obj = stageData[prop];
				if (obj is DisplayObjectContainer)
				{
					return obj as DisplayObjectContainer;
				};
			}
			catch (err:Error)
			{
			};
			return null;
		}

		private function applyFxFiltersToStageContainer(layer:DisplayObjectContainer, ownerUid:int, fields:Object):void
		{
			var i:int;
			var n:int;
			var child:DisplayObject;
			var childUid:int;
			var linkage:String;
			var group:Object;
			if (!layer || ownerUid == 0)
			{
				return;
			};
			try
			{
				n = layer.numChildren;
			}
			catch (err:Error)
			{
				return;
			};
			i = 0;
			while (i < n)
			{
				try
				{
					child = layer.getChildAt(i);
					if (!child)
					{
						i++;
						continue;
					};
					childUid = 0;
					try
					{
						childUid = int(child["uid"]);
					}
					catch (cuErr:Error)
					{
						childUid = 0;
					};
					if (childUid != ownerUid)
					{
						i++;
						continue;
					};
					if (FxRecolorUtils.isSharedStageEffectId(child.name))
					{
						i++;
						continue;
					};
					try
					{
						if (player && player.MC is DisplayObject && child === player.MC)
						{
							i++;
							continue;
						};
					}
					catch (mcErr:Error)
					{
					};
					if (fields == null && currentPaletteData)
					{
						linkage = FxRecolorUtils.resolveDisplayFxLinkage(child, child.name);
						group = FxRecolorUtils.findFxGroupForLinkage(currentPaletteData, linkage);
						if (group)
						{
							FxRecolorUtils.applyFxSwapOrFilters(
								child, currentPaletteData, group, 8, 200);
						}
						else
						{
							FxRecolorUtils.clearFxDisplayAdjust(child);
						};
					}
					else if (fields)
					{
						if ((Number(fields.hue) || 0) == 0
							&& (Number(fields.saturation) || 0) == 0
							&& (Number(fields.brightness) || 0) == 0
							&& (Number(fields.contrast) || 0) == 0)
						{
							FxRecolorUtils.clearFxDisplayAdjust(child);
						}
						else
						{
							FxRecolorUtils.applyAdjustColorFilters(
								child, fields.hue, fields.saturation, fields.brightness, fields.contrast);
						};
					}
					else
					{
						FxRecolorUtils.clearFxDisplayAdjust(child);
					};
				}
				catch (childErr:Error)
				{
				};
				i++;
			};
		}

		/** Editor identity leaves the strip vanilla while the fighter still shows the engine costume. */
		protected function fighterSwapOr(editorBlock:Object, pa:Boolean):Object
		{
			var live:Object;
			var colors:Array;
			var repls:Array;
			var i:int;
			if (!player)
			{
				return editorBlock;
			};
			try
			{
				live = pa ? player.m_paletteSwapPAData : player.m_paletteSwapData;
			}
			catch (err:*)
			{
				live = null;
			};
			if (!live || !(live.colors is Array) || !(live.replacements is Array))
			{
				return editorBlock;
			};
			colors = live.colors as Array;
			repls = live.replacements as Array;
			i = 0;
			while (i < colors.length && i < repls.length)
			{
				if (uint(colors[i]) != uint(repls[i]))
				{
					return live;
				};
				i++;
			};
			return editorBlock;
		}

		protected function updateUniquePaPalettes(swapOverride:Object=null, swapPAOverride:Object=null):void
		{
			var hotSwap:Object;
			var hotPA:Object;
			if (!uniquePaSprites || !uniquePaCoverCache || !currentPaletteData)
			{
				return;
			};
			if (recolorEffectsMode)
			{
				applyRecolorEffectsFiltersToStrip();
				return;
			};
			uniquePaintDebouncePending = false;
			hotSwap = swapOverride;
			hotPA = swapPAOverride;
			if (hotSwap == null && !isolateMode && !pulseActive && !isSelectHighlightActive())
			{
				hotSwap = getHotPaletteBlock(currentPaletteData.paletteSwap);
				if (hotSwap == null && currentPaletteData.paletteSwap)
				{
					// Editor block is identity. The fighter may already be on the engine base recolor.
					hotSwap = fighterSwapOr(currentPaletteData.paletteSwap, false);
				};
			};
			if (hotPA == null && !isolateMode && !pulseActive && !isSelectHighlightActive())
			{
				hotPA = getHotPaletteBlock(currentPaletteData.paletteSwapPA);
				if (hotPA == null && currentPaletteData.paletteSwapPA)
				{
					hotPA = fighterSwapOr(currentPaletteData.paletteSwapPA, true);
				};
			};
			paintUniqueSpritesForSheet(uniquePaSprites, uniquePaCoverCache, statsName,
				currentPaletteData, hotSwap, hotPA, isolateMode, uniqueOwnedHighlight);
			if (hoverBaseActive && !isolateMode && !draggingSlider && !pulseActive)
			{
				scheduleHoverDim();
			};
		}

		protected function flushDebouncedUniquePaint():void
		{
			if (!uniquePaintDebouncePending)
			{
				return;
			};
			if (getTimer() < uniquePaintDebounceAt)
			{
				return;
			};
			if (draggingSlider)
			{
				// Keep deferring until slider release.
				uniquePaintDebounceAt = getTimer() + UNIQUE_PAINT_DEBOUNCE_MS;
				return;
			};
			uniquePaintDebouncePending = false;
			updateUniquePaPalettes(uniquePaintDebounceSwap, uniquePaintDebounceSwapPA);
			uniquePaintDebounceSwap = null;
			uniquePaintDebounceSwapPA = null;
		}
    }
}
