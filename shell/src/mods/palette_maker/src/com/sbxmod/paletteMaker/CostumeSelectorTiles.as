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

    /** Costume tiles: build, preview recolor, vault ownership, tile alpha, telemetry. Part of the CostumeSelectorDisplay chain. */
    public class CostumeSelectorTiles extends PaletteMenuBase
    {
        public function CostumeSelectorTiles()
        {
            super();
        }

		internal static const MODE_NONE:String = "none";

		protected var m_statsName:String = null;

		protected var m_pid:int;

		/** CSS pick grid: another player on this character already has the slot. */
		protected var m_cssPick:Boolean = false;

		protected var currentStockIcon:MovieClip;

		protected var onlineImportMode:Boolean = false;

		protected var selectionMode:String = MODE_NONE;

		protected var containerButton:Array;

		protected var allCostumes:Array;

		/** colorVaultId -> true for O(1) owned checks while browsing large vault lists. */
		protected var ownedVaultIds:Object = null;

		protected var previewCatchUpIndex:int = 0;

		/** Shared PA used to stamp Bitmap previews (avoids 127 live character clips). */
		private var vaultPreviewSource:MovieClip = null;

		protected function clearStockIcon():void
		{
			var stockMain:MovieClip;
			try
			{
				stockMain = MovieClip(m_subMenu.nameplate.stockMain);
			}
			catch (err:Error)
			{
				stockMain = null;
			};
			if (!stockMain)
			{
				return;
			};
			while (stockMain.numChildren > 0)
			{
				stockMain.removeChildAt(0);
			};
			currentStockIcon = null;
		}

		/** Stamp shared-PA bitmaps onto tiles a few per frame — fast list + real previews. */
		protected function previewCatchUpStep(e:Event):void
		{
			var n:int = 2;
			var i:int;
			var idx:int;
			if (!onlineImportMode || !containerButton)
			{
				m_subMenu.removeEventListener(Event.ENTER_FRAME, previewCatchUpStep);
				return;
			};
			for (i = 0; i < n && previewCatchUpIndex < containerButton.length; i++)
			{
				idx = previewCatchUpIndex;
				try
				{
					ensureVaultTilePreview(idx);
				}
				catch (err:Error)
				{
				};
				previewCatchUpIndex++;
			};
			if (previewCatchUpIndex >= containerButton.length)
			{
				m_subMenu.removeEventListener(Event.ENTER_FRAME, previewCatchUpStep);
			};
		}

		protected function buildNoRecolorCostumeSlot(template:Object):Object
		{
			var slot:Object;
			var ps:Object;
			var psPA:Object;
			slot = template ? Ssf2.Utils.cloneObject(template) : Ssf2.Utils.getCostumeObject({});
			slot.profile = PaletteMakerUtils.NO_RECOLOR_COSTUME_NAME;
			slot.noRecolor = true;
			slot.base = false;
			ps = (slot.paletteSwap) ? slot.paletteSwap : {"colors": [], "replacements": []};
			psPA = (slot.paletteSwapPA) ? slot.paletteSwapPA : {"colors": [], "replacements": []};
			if (ps.colors)
			{
				ps.replacements = Ssf2.Utils.cloneObject(ps.colors);
			};
			if (psPA.colors)
			{
				psPA.replacements = Ssf2.Utils.cloneObject(psPA.colors);
			};
			slot.paletteSwap = ps;
			slot.paletteSwapPA = psPA;
			return slot;
		}

		/** Tile tint. Vault: never call pickBestColor/fitText — huge PA arrays / long names freeze a frame forever. */
		protected function costumeTileColor(costume:Object):uint
		{
			var bestBackgroundColor:uint = 0x232A89;
			var repl:*;
			if (!onlineImportMode)
			{
				try
				{
					if (costume.paletteSwapPA && costume.paletteSwapPA.replacements && costume.paletteSwapPA.replacements.length > 0)
					{
						bestBackgroundColor = PaletteMakerUtils.pickBestColor(costume.paletteSwapPA.replacements);
					};
				}
				catch (colorErr:Error)
				{
					bestBackgroundColor = 0x232A89;
				};
			}
			else
			{
				try
				{
					repl = costume.paletteSwapPA && costume.paletteSwapPA.replacements;
					if (repl is Array && repl.length > 0)
					{
						bestBackgroundColor = uint(repl[0]);
					};
				}
				catch (vaultColorErr:Error)
				{
				};
			};
			return bestBackgroundColor;
		}

		/** Vault tile: name, author and tint only; the preview is filled later (pmNeedsPreview). */
		protected function fillVaultCostumeTile(btn:*, costume:Object, costumeName:String, bestBackgroundColor:uint):void
		{
			btn.ButtonInstance["pmNeedsPreview"] = true;
			if (btn.ButtonInstance.costumeName_txt)
			{
				btn.ButtonInstance.costumeName_txt.text = costumeName;
			};
			try
			{
				var vaultAuthorField:TextField = btn.ButtonInstance.costumeAuthor_txt as TextField;
				var vaultAuthorName:String = PaletteMakerUtils.extractAuthorFromCostume(costume);
				if (vaultAuthorField)
				{
					if (vaultAuthorName && vaultAuthorName.length > 0)
					{
						vaultAuthorField.visible = true;
						vaultAuthorField.text = vaultAuthorName.substring(0, 24);
					}
					else
					{
						vaultAuthorField.text = "";
						vaultAuthorField.visible = false;
					};
				};
			}
			catch (vaultAuthorErr:Error)
			{
				if (btn.ButtonInstance.costumeAuthor_txt)
				{
					btn.ButtonInstance.costumeAuthor_txt.text = "";
					btn.ButtonInstance.costumeAuthor_txt.visible = false;
				};
			};
			tintCostumeTile(btn, bestBackgroundColor);
		}

		protected function fillCostumeTileLabels(btn:*, costume:Object, costumeName:String):void
		{
			if (btn.ButtonInstance.costumeName_txt)
			{
				if (costume && costume._packStatsName)
				{
					btn.ButtonInstance.costumeName_txt.text = String(costume._packStatsName) + ": " + costumeName;
				}
				else
				{
					btn.ButtonInstance.costumeName_txt.text = costumeName;
				};
				safeFitText(btn.ButtonInstance.costumeName_txt, 9, 1);
				if (PaletteMakerUtils.isSystemCostumeSlot(costume))
				{
					btn.ButtonInstance.costumeName_txt.textColor = 0x4A4A4A;
				};
			};
			try
			{
				var authorField:TextField = btn.ButtonInstance.costumeAuthor_txt as TextField;
				var authorName:String = PaletteMakerUtils.extractAuthorFromCostume(costume);
				if (authorField)
				{
					if (authorName && authorName.length > 0)
					{
						authorField.visible = true;
						authorField.text = authorName.substring(0, 24);
						safeFitText(authorField, 8, 1);
					}
					else
					{
						authorField.text = "";
						authorField.visible = false;
					};
				};
			}
			catch (authorErr:Error)
			{
			};
		}

		protected function tintCostumeTile(btn:*, color:uint):void
		{
			if (btn.ButtonInstance.bg)
			{
				if (btn.ButtonInstance.bg.tintedFrontLayout)
				{
					PaletteMakerUtils.setTint(btn.ButtonInstance.bg.tintedFrontLayout, color);
				};
				if (btn.ButtonInstance.bg.tintedBG)
				{
					PaletteMakerUtils.setTint(btn.ButtonInstance.bg.tintedBG, color);
				};
			};
		}

		/** fitText can infinite-loop on pathological names when numLines never drops — cap size. */
		private function safeFitText(field:TextField, origSize:Number, numLines:Number=1):void
		{
			var tFormat:TextFormat;
			var guard:int;
			if (!field)
			{
				return;
			};
			tFormat = field.getTextFormat();
			tFormat.size = origSize;
			field.setTextFormat(tFormat);
			guard = 0;
			while (field.numLines > numLines && Number(tFormat.size) > 6 && guard < 20)
			{
				tFormat.size = Number(tFormat.size) - 1;
				field.setTextFormat(tFormat);
				guard++;
			};
		}

		/** Another CSS player on this character already has this shared costume slot. */
		protected function isCssCostumeTaken(index:int):Boolean
		{
			var menu:*;
			var settings:*;
			var mine:*;
			var other:*;
			var costume:Object;
			var slot:int;
			var i:int;
			if (!m_cssPick || onlineImportMode || selectionMode != MODE_NONE)
			{
				return false;
			};
			if (!allCostumes || index < 0 || index >= allCostumes.length)
			{
				return false;
			};
			costume = allCostumes[index];
			if (!costume || !(costume._gameCostumeIndex is Number))
			{
				return false;
			};
			slot = int(costume._gameCostumeIndex);
			menu = Ssf2.MenuController.CurrentCharacterSelectMenu;
			if (!menu || !menu.GameObj || !menu.GameObj.PlayerSettings)
			{
				return false;
			};
			settings = menu.GameObj.PlayerSettings;
			if (m_pid < 0 || m_pid >= settings.length)
			{
				return false;
			};
			mine = settings[m_pid];
			if (!mine || !mine.character)
			{
				return false;
			};
			i = 0;
			while (i < settings.length)
			{
				other = settings[i];
				if (i != m_pid && other && other.character == mine.character && int(other.costume) == slot)
				{
					if (mine.character != "xp" || Number(other.expansion) == Number(mine.expansion))
					{
						return true;
					};
				};
				i++;
			};
			return false;
		}

		/** Step past costumes another player already has. Returns -1 when every step is taken. */
		protected function skipTakenCostume(next:int, dCol:int, dRow:int, cols:int, n:int):int
		{
			var hops:int;
			var col:int;
			var row:int;
			var rows:int;
			var stepped:int;
			if (!isCssCostumeTaken(next))
			{
				return next;
			};
			rows = Math.ceil(n / cols);
			hops = 0;
			while (isCssCostumeTaken(next) && hops < n)
			{
				col = next % cols;
				row = int(next / cols);
				col = Math.max(0, Math.min(cols - 1, col + dCol));
				row = Math.max(0, Math.min(rows - 1, row + dRow));
				stepped = row * cols + col;
				if (stepped >= n)
				{
					stepped = n - 1;
				};
				if (stepped < 0)
				{
					stepped = 0;
				};
				if (stepped == next)
				{
					break;
				};
				next = stepped;
				hops++;
			};
			return isCssCostumeTaken(next) ? -1 : next;
		}

		protected function rebuildOwnedVaultIdCache():void
		{
			var favs:Array;
			var i:int;
			ownedVaultIds = {};
			favs = PaletteMakerUtils.getFavoriteIndexes(m_statsName);
			i = 0;
			while (favs && i < favs.length)
			{
				ownedVaultIds[int(favs[i])] = true;
				i++;
			};
		}

		protected function catalogIndexOfTile(costume:Object):int
		{
			if (!costume)
			{
				return -1;
			};
			if (costume.hasOwnProperty("_catalogIndex") && (costume._catalogIndex is Number))
			{
				return int(costume._catalogIndex);
			};
			return PaletteMakerUtils.catalogIndexOfCostume(m_statsName, costume);
		}

		protected function isVaultCostumeOwned(costume:Object):Boolean
		{
			var id:int = catalogIndexOfTile(costume);
			if (id < 0)
			{
				return false;
			};
			if (!ownedVaultIds)
			{
				rebuildOwnedVaultIdCache();
			};
			return ownedVaultIds[id] == true;
		}

		protected function setVaultCostumeOwned(costume:Object, owned:Boolean):void
		{
			var id:int = catalogIndexOfTile(costume);
			if (id < 0)
			{
				return;
			};
			if (!ownedVaultIds)
			{
				rebuildOwnedVaultIdCache();
			};
			if (owned)
			{
				ownedVaultIds[id] = true;
			}
			else
			{
				delete ownedVaultIds[id];
			};
		}

		private static var s_paLog:int = 0;

		private static function paLog(msg:String):void
		{
			if (s_paLog >= 8)
			{
				return;
			};
			s_paLog++;
			PaletteDeep.note("[palette_maker] " + msg);
		}

		private static var s_telemetry:*;

		private static var s_telemetryAt:int = -10000;

		private static function telemetryClass():*
		{
			var now:int;
			if (s_telemetry)
			{
				return s_telemetry;
			};
			now = getTimer();
			if (now - s_telemetryAt < 1000)
			{
				return null;
			};
			s_telemetryAt = now;
			try
			{
				s_telemetry = getDefinitionByName("AirTelemetry");
			}
			catch (err:*)
			{
				s_telemetry = null;
			};
			return s_telemetry;
		}

		private static function telemetryStart(name:String):void
		{
			var C:* = telemetryClass();
			if (C)
			{
				C.startTiming(name);
			};
		}

		private static function telemetryEnd(name:String, fields:Object):void
		{
			var C:* = telemetryClass();
			if (C)
			{
				C.endTiming(name, -1, fields);
			};
		}

		protected function applyCostumePreview(mc:MovieClip, costume:Object, usePA:Boolean):void
		{
			var palette:Object;
			var info:Object;
			var rasterInfo:Object;
			var heldFrame:int;
			if (!mc || !costume)
			{
				return;
			};
			Ssf2.Utils.setColorFilter(mc, costume);
			if (usePA)
			{
				palette = PaletteDeep.combinePaletteBlocks(costume.paletteSwap, costume.paletteSwapPA);
				if (((!(palette)) || (!(palette.colors is Array)) || (palette.colors.length <= 0)))
				{
					palette = costume.paletteSwapPA || costume.paletteSwap;
				};
				heldFrame = mc.currentFrame;
				info = PaletteDeep.describeArt(mc);
				if (info && int(info.bitmaps) == 0 && int(info.gfx) == 0 && mc.totalFrames > 1 && mc.currentFrame != 1)
				{
					try
					{
						mc.gotoAndStop(1);
					}
					catch (frameErr:Error)
					{
					};
					info = PaletteDeep.describeArt(mc);
				};
				if (s_paLog < 8)
				{
					paLog("PA frame " + heldFrame + "->" + mc.currentFrame + "/" + mc.totalFrames + " bmp=" + (info ? info.bitmaps : "?") + " shp=" + (info ? info.shapes : "?") + " gfx=" + (info ? info.gfx : "?") + " kids=" + mc.numChildren);
				};
				PaletteDeep.restoreDeepPaletteOriginals(mc);
				telemetryStart("paint.replace");
				PaletteDeep.replacePaletteDeep(mc, palette, 12, true, false, true);
				telemetryEnd("paint.replace", null);
				if (!info || int(info.bitmaps) == 0)
				{
					telemetryStart("paint.raster");
					rasterInfo = PaletteDeep.rasterRecolor(mc, palette);
					telemetryEnd("paint.raster", rasterInfo ? {"w": rasterInfo.w, "h": rasterInfo.h, "hits": rasterInfo.hits} : null);
					paLog("PA raster " + (rasterInfo ? (rasterInfo.w + "x" + rasterInfo.h + " hits=" + rasterInfo.hits + " kids=" + rasterInfo.kids) : "none"));
				};
			}
			else
			{
				palette = costume.paletteSwap;
				if (((!(palette)) || (!(palette.colors is Array)) || (palette.colors.length <= 0)))
				{
					palette = costume.paletteSwapPA;
				};
				Ssf2.Utils.restorePaletteOriginals(mc, 2);
				Ssf2.Utils.replacePalette(mc, palette, 2, true);
			};
		}

		protected function clearVaultPreviewSource():void
		{
			if (vaultPreviewSource && vaultPreviewSource.parent)
			{
				vaultPreviewSource.parent.removeChild(vaultPreviewSource);
			};
			vaultPreviewSource = null;
		}

		/**
		 * Vault previews: stock → ph2, portrait PA → ph (same as local costume tiles).
		 * Catch-up runs a few tiles/frame so 127×kirby_charselect doesn't freeze the build.
		 */
		protected function ensureVaultTilePreview(index:int):void
		{
			var btn:*;
			var costume:Object;
			var ph:MovieClip;
			var ph2:MovieClip;
			var pa:MovieClip;
			var stock:MovieClip;
			var stageLabel:String = "init";
			if (!onlineImportMode || !containerButton || index < 0 || index >= containerButton.length)
			{
				return;
			};
			btn = containerButton[index];
			if (!btn || !btn.ButtonInstance || !btn.ButtonInstance["pmNeedsPreview"])
			{
				return;
			};
			costume = allCostumes[index];
			btn.ButtonInstance["pmNeedsPreview"] = false;
			try
			{
				stageLabel = "ph2-stock";
				ph2 = MovieClip(btn.ButtonInstance.getChildByName("ph2"));
				if (ph2)
				{
					while (ph2.numChildren > 0)
					{
						ph2.removeChildAt(0);
					};
					stock = PaletteMakerUtils.getStockIcon(m_statsName);
					if (stock)
					{
						ph2.addChild(stock);
						applyCostumePreview(stock, costume, false);
					};
				};
				stageLabel = "ph-portrait";
				ph = MovieClip(btn.ButtonInstance.getChildByName("ph"));
				if (ph)
				{
					while (ph.numChildren > 0)
					{
						ph.removeChildAt(0);
					};
					pa = PaletteMakerUtils.getPixelArt(m_statsName);
					if (pa)
					{
						ph.addChild(pa);
						pa.gotoAndStop(10);
						applyCostumePreview(pa, costume, true);
					}
					else
					{
					};
				}
				else
				{
				};
			}
			catch (err:Error)
			{
				btn.ButtonInstance["pmNeedsPreview"] = true;
			};
		}

		protected function formatCostumeHoverTip(costume:Object):String
		{
			var name:String;
			var author:String;
			if (!costume)
			{
				return null;
			};
			if (costume.noRecolor)
			{
				return PaletteMakerUtils.NO_RECOLOR_COSTUME_NAME;
			};
			name = costume.hasOwnProperty("profile") ? PaletteMakerUtils.trimString(String(costume.profile)) : "";
			author = PaletteMakerUtils.extractAuthorFromCostume(costume);
			if (!name || name.length == 0)
			{
				name = PaletteMakerUtils.DEFAULT_COSTUME_NAME;
			};
			return PaletteMakerUtils.formatCostumeDisplayName(name, author);
		}
    }
}
