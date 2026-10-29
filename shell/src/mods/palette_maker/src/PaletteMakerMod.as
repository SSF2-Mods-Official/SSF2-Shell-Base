package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import com.sbxmod.paletteMaker.PaletteMakerUtils;
	import com.sbxmod.paletteMaker.LinkedFormPaint;
	import com.sbxmod.paletteMaker.GigaStockPalettes;
	import com.sbxmod.paletteMaker.LinkedFormStance;
	import com.sbxmod.paletteMaker.PaletteMakerMenu;
	import com.sbxmod.paletteMaker.CostumeSelectorDisplay;
	import com.sbxmod.paletteMaker.DiscordCostumePresence;
	import com.sbxmod.paletteMaker.PaletteMakerAchievements;
	import com.sbxmod.paletteMaker.PaletteMakerShortcuts;
	import com.sbxmod.paletteMaker.CostumeFxPaletteRuntime;
	import com.sbxmod.paletteMaker.ColorVaultSync;
	import com.sbxmod.paletteMaker.Ssf2;
	import com.mcleodgaming.ssf2.util.PaletteDeep;

	/**
	 * Palette Maker pack — registers Host patches/hooks only (no getService).
	 */
	public class PaletteMakerMod extends Sprite
	{
		private static const LINK:Array = [
			PaletteMakerUtils,
			PaletteMakerMenu,
			CostumeSelectorDisplay,
			DiscordCostumePresence,
			PaletteMakerAchievements,
			PaletteMakerShortcuts,
			CostumeFxPaletteRuntime
		];


		public function PaletteMakerMod()
		{
			super();
		}

		private var m_host:*;
		private var m_applyingFormCostume:Boolean = false;
		private var m_stockPaintErrLogged:Boolean = false;
		private var m_stanceErrLogged:Boolean = false;
		private var m_formHudKey:String = "";
		private var m_stockHudMark:String = "";

		public function onBoot(host:*):void
		{
			var _force:* = LINK[0];
			m_host = host;
			if (host)
			{
				try
				{
					registerPaletteDoors(host);
					host["patch"]("combinePaletteBlocks", PaletteDeep.combinePaletteBlocksStock);
					host["patch"]("applyCostumeMcName", PaletteDeep.applyCostumeMcName);
					host["patch"]("advanceEffectFrame", PaletteDeep.advanceEffectFrame);
					host["patch"]("isFragileTimelineClip", PaletteDeep.isFragileTimelineClip);
					host.addHook("STAGE_SELECT", PaletteMakerMenu.onStudioStageSelect);
					host.addHook("CAMERA_UPDATE", PaletteMakerMenu.nudgeStudioCamera);
					host.addHook("CSS_SELECT_CHARACTER", onCssSelectMenu);
					host.addHook("AFTER_TRANSFORM", onAfterTransform);
					host.addHook("AFTER_STANCE_PAINT", onAfterStancePaint);
					host.addHook("ONLINE_MENU_SHOW", onOnlineMenuShow);
				}
				catch (err:*)
				{
					trace("[palette_maker] register doors failed: " + err);
				};
			};
			trace("[palette_maker] boot doors registered linked=" + (_force != null));
		}

		private function onAfterStancePaint(ctx:Object):void
		{
			var toName:String;
			var costumeName:String;
			var fromName:String;
			var character:*;
			var index:int;
			var list:Array;
			var costume:Object;
			var paCount:int;
			var swapCount:int;
			var stance:int;
			var fileIndex:int;
			var key:String;
			var linked:Boolean;
			var carry:Boolean;
			var link:Object;
			try
			{
			if (m_applyingFormCostume || !ctx || !ctx.character)
			{
				return;
			};
			toName = String(ctx.statsName);
			character = ctx.character;
			trace("[palette_maker] stance enter stats=" + toName);
			paintStockPortrait(character, toName, ctx.paletteSwapPAData);
			if (LinkedFormPaint.matchUsesStockTransform(toName))
			{
				return;
			};
			costumeName = "";
			fromName = "";
			index = -1;
			try
			{
				costumeName = String(character.CostumeName);
			}
			catch (nameErr:*)
			{
			};
			try
			{
				fromName = String(character.m_characterStats.NormalStatsID);
			}
			catch (fromErr:*)
			{
			};
			try
			{
				index = int(character.CostumeID);
			}
			catch (slotErr:*)
			{
				try
				{
					index = int(character.m_costume);
				}
				catch (slotErr2:*)
				{
				};
			};
			try
			{
			linked = PaletteMakerUtils.isFormLinked(toName);
			carry = PaletteMakerUtils.shouldCarryCostumeOnTransform(fromName, toName);
			link = PaletteMakerUtils.getFormLink(toName);
			if (!linked || !toName)
			{
				return;
			};
			if (link && link.carryOnTransform == true && costumeName == toName)
			{
				PaletteMakerUtils.ensureCostumeFileLoaded(toName);
				list = PaletteMakerUtils.getCostume(toName);
				fileIndex = PaletteMakerUtils.fileIndexForGameSlot(toName, index);
				costume = (list && fileIndex >= 0 && fileIndex < list.length) ? list[fileIndex] : null;
				swapCount = (costume && costume.paletteSwap && costume.paletteSwap.colors) ? costume.paletteSwap.colors.length : 0;
				stance = 0;
				try
				{
					stance = character.HasStance ? 1 : 0;
				}
				catch (stanceErr:*)
				{
				};
				key = "apply:" + toName + ":" + index + ":" + swapCount + ":" + stance;
				if (key != m_formHudKey)
				{
					m_formHudKey = key;
					Ssf2.gameLog("[Palette Maker] costume apply stats=" + toName + " slot=" + index + " swap=" + swapCount + " stance=" + stance);
				};
				if (!costume || (!costume.paletteSwap && !costume.paletteSwapPA))
				{
					return;
				};
				if (ctx.paletteSwapPAData == costume.paletteSwapPA && ctx.paletteSwapData == costume.paletteSwap)
				{
					return;
				};
				m_applyingFormCostume = true;
				try
				{
					character.setPaletteSwap(costume.paletteSwap, costume.paletteSwapPA);
				}
				catch (applyErr:*)
				{
					Ssf2.gameLog("[Palette Maker] costume apply failed stats=" + toName + " " + applyErr);
				};
				m_applyingFormCostume = false;
				return;
			};
			if (carry || costumeName == toName)
			{
				return;
			};
			costume = null;
			if (fromName && PaletteMakerUtils.getLinkedFormPartner(fromName) == toName)
			{
				costume = PaletteMakerUtils.pairedPaletteForSlot(fromName, index);
			};
			if (!costume)
			{
				PaletteMakerUtils.ensureCostumeFileLoaded(toName);
				list = PaletteMakerUtils.getCostume(toName);
				index = PaletteMakerUtils.fileIndexForGameSlot(toName, index);
				costume = (list && index >= 0 && index < list.length) ? list[index] : null;
			};
			paCount = (costume && costume.paletteSwapPA && costume.paletteSwapPA.colors) ? costume.paletteSwapPA.colors.length : 0;
			key = toName + ":" + costumeName + ":" + index + ":" + (list ? list.length : 0) + ":" + paCount;
			if (key != m_formHudKey)
			{
				m_formHudKey = key;
				Ssf2.gameLog("[Palette Maker] form hud stats=" + toName + " costumeName=" + costumeName + " slot=" + index + " file=" + (list ? list.length : 0) + " pa=" + paCount + " linked=1 carry=0");
			};
			if (!costume || (!costume.paletteSwap && !costume.paletteSwapPA))
			{
				return;
			};
			if (ctx.paletteSwapPAData == costume.paletteSwapPA && ctx.paletteSwapData == costume.paletteSwap)
			{
				return;
			};
			m_applyingFormCostume = true;
			try
			{
				character.setPaletteSwap(costume.paletteSwap, costume.paletteSwapPA);
			}
			catch (paintErr:*)
			{
				Ssf2.gameLog("[Palette Maker] form hud paint failed stats=" + toName + " " + paintErr);
			};
			m_applyingFormCostume = false;
			}
			catch (hookErr:*)
			{
				logStancePaintErr(toName, hookErr);
			};
			}
			catch (outerErr:*)
			{
				logStancePaintErr(toName, outerErr);
			};
		}

		private function logStancePaintErr(statsName:String, err:*):void
		{
			var typed:Error;
			var msg:String;
			if (m_stanceErrLogged)
			{
				return;
			};
			m_stanceErrLogged = true;
			msg = String(err);
			try
			{
				typed = err as Error;
				if (typed && typed.message)
				{
					msg = typed.message;
				};
			}
			catch (msgErr:*)
			{
			};
			try
			{
				trace("[palette_maker] stance err " + msg);
				Ssf2.gameLog("[Palette Maker] stance paint err stats=" + statsName + " " + msg);
			}
			catch (logErr:*)
			{
			};
			try
			{
				if (typed)
				{
					Ssf2.gameLog("[Palette Maker] stance paint stack " + typed.getStackTrace());
				};
			}
			catch (stackErr:*)
			{
			};
		}

		private function paintStockPortrait(character:*, statsName:String, paletteSwapPA:Object):void
		{
			var box:*;
			var head:*;
			var painted:int;
			var mark:String;
			var first:String;
			if (!character || !LinkedFormPaint.matchUsesStockTransform(statsName))
			{
				return;
			};
			box = null;
			head = null;
			try
			{
				box = character.HealthBox;
				head = box ? box.charHead : null;
			}
			catch (boxErr:*)
			{
				head = null;
			};
			painted = 0;
			try
			{
				painted = LinkedFormPaint.paintLivePortrait(statsName, head as MovieClip, paletteSwapPA);
			}
			catch (paintErr:*)
			{
				if (!m_stockPaintErrLogged)
				{
					m_stockPaintErrLogged = true;
					Ssf2.gameLog("[Palette Maker] form hud pa fail " + paintErr);
				};
			};
			first = "0";
			if (paletteSwapPA && (paletteSwapPA.replacements is Array) && paletteSwapPA.replacements.length > 0)
			{
				first = String(uint(paletteSwapPA.replacements[0]));
			};
			mark = statsName + ":" + first + ":" + painted;
			if (mark != m_stockHudMark)
			{
				m_stockHudMark = mark;
				Ssf2.gameLog("[Palette Maker] form hud pa stats=" + statsName + " first=" + first + " painted=" + painted);
			};
		}

		private function onAfterTransform(ctx:Object):void
		{
			var fromName:String;
			var toName:String;
			var character:*;
			var index:int;
			var costume:Object;
			var list:Array;
			var item:Object;
			var bothFlag:String;
			var swap:int;
			if (!ctx)
			{
				return;
			};
			fromName = String(ctx.previousStatsName);
			toName = String(ctx.statsName);
			character = ctx.character;
			if (character && toName && PaletteMakerUtils.isFormLinked(toName) && !PaletteMakerUtils.shouldCarryCostumeOnTransform(fromName, toName))
			{
				index = -1;
				try
				{
					index = int(character.CostumeID);
				}
				catch (slotErr:*)
				{
				};
				costume = null;
				if (fromName && PaletteMakerUtils.getLinkedFormPartner(fromName) == toName)
				{
					costume = PaletteMakerUtils.pairedPaletteForSlot(fromName, index);
				};
				if (!costume)
				{
					try
					{
						costume = Ssf2.ResourceManager.getCostume(toName, null, index);
					}
					catch (costumeErr:*)
					{
						costume = null;
					};
				}
				else
				{
					Ssf2.gameLog("[Palette Maker] pair apply owner=" + fromName + " slot=" + index);
				};
				if (toName == "gigabowser" && !LinkedFormPaint.blockHasRecolor(costume ? costume.paletteSwap : null))
				{
					costume = GigaStockPalettes.costume(LinkedFormPaint.gigaPaletteIndex(index));
				};
				if (costume && (LinkedFormPaint.blockHasRecolor(costume.paletteSwap) || LinkedFormPaint.blockHasRecolor(costume.paletteSwapPA)))
				{
					try
					{
						character.setPaletteSwap(costume.paletteSwap, costume.paletteSwapPA);
						Ssf2.gameLog("[Palette Maker] form costume stats=" + toName + " slot=" + index + " pa=" + (costume.paletteSwapPA ? 1 : 0));
					}
					catch (paintErr:*)
					{
					};
				};
			};
			if (fromName != "zelda" && fromName != "sheik" && toName != "zelda" && toName != "sheik")
			{
				return;
			};
			index = -1;
			bothFlag = "missing";
			swap = 0;
			try
			{
				index = int(character.m_costume);
			}
			catch (indexErr:*)
			{
			};
			list = PaletteMakerUtils.getCostume(toName);
			if (list && index >= 0 && index < list.length)
			{
				item = list[index];
				bothFlag = (item && item.both) ? "1" : "0";
				swap = (item && item.paletteSwap) ? 1 : 0;
			};
			trace("[Palette Maker] transform from=" + fromName + " to=" + toName + " index=" + index + " both=" + bothFlag + " swap=" + swap);
		}

		private function onOnlineMenuShow(ctx:Object):void
		{
			try
			{
				ColorVaultSync.refreshForOnline();
			}
			catch (err:*)
			{
				trace("[palette_maker] online menu refresh failed: " + err);
			};
		}

		public function onBootEnd():void
		{
			try
			{
				if (m_host)
				{
					m_host["removeHook"]("STAGE_SELECT", PaletteMakerMenu.onStudioStageSelect);
					m_host["removeHook"]("CAMERA_UPDATE", PaletteMakerMenu.nudgeStudioCamera);
				};
			}
			catch (hookErr:*)
			{
			};
			try
			{
				CostumeFxPaletteRuntime.shutdown();
			}
			catch (err:*)
			{
			};
			try
			{
				PaletteMakerUtils.shutdown();
			}
			catch (utilsErr:*)
			{
				trace("[palette_maker] utils shutdown failed: " + utilsErr);
			};
		}

		/** CSS_SELECT_CHARACTER passes the menu that just called changePic. CurrentCharacterSelectMenu can be a different object. */
		private function onCssSelectMenu(ctx:Object):void
		{
			var menu:*;
			var game:int;
			menu = (ctx ? ctx.menu : null);
			game = 0;
			try
			{
				game = (menu && menu.GameObj && menu.GameObj.PlayerSettings) ? 1 : 0;
			}
			catch (err:*)
			{
			};
			if (game)
			{
				CostumeSelectorDisplay.noteCssMenu(menu);
			};
		}

		private function registerPaletteDoors(host:*):void
		{
			var P:Class = PaletteMakerUtils;
			host["patch"]("palette.init", function():void { P.init(); });
			host["patch"]("palette.getCostume", function(charName:String):Array { return P.getCostume(charName); });
			host["patch"]("palette.isLinkedFormPair", function(n:String):Boolean { return P.isLinkedFormPair(n); });
			host["patch"]("palette.isFormLinked", function(n:String):Boolean { return P.engineFormLinked(n); });
			host["patch"]("palette.shouldCombineFormPalette", function(n:String):Boolean { return P.shouldCombineFormPalette(n); });
			host["patch"]("palette.shouldCarryCostumeOnTransform", function(a:*, b:*):Boolean { return P.shouldCarryCostumeOnTransform(a, b); });
			host["patch"]("palette.isCustomCostume", function(c:Object):Boolean { return P.isCustomCostume(c); });
			host["patch"]("palette.getFormPaletteTemplate", function(n:String):Object { return P.getFormPaletteTemplate(n); });
			host["patch"]("palette.remapCostumeOntoFormTemplate", function(c:Object, t:Object):Object { return P.remapCostumeOntoFormTemplate(c, t); });
			host["patch"]("palette.getTransformCostumePalette", function(a:String, b:String, i:int):Object { return P.getTransformCostumePalette(a, b, i); });
			host["patch"]("palette.getMergedCostumeIndexByColorVaultId", function(n:String, id:String):int { return P.getMergedCostumeIndexByColorVaultId(n, id); });
			host["patch"]("palette.findMergedCostumeIndexByIdentity", function(n:String, c:Object):int { return P.findMergedCostumeIndexByIdentity(n, c); });
			host["patch"]("palette.getColorVaultIdFromCostume", function(c:Object):String { return P.getColorVaultIdFromCostume(c); });
			host["patch"]("palette.getSharedLinkedFormBothCostumes", function(n:String):Array { return P.getSharedLinkedFormBothCostumes(n); });
			host["patch"]("palette.getPrivateLinkedFormCostumes", function(n:String):Array { return P.getPrivateLinkedFormCostumes(n); });
			host["patch"]("palette.ensureAutoFormLinks", function(v:Boolean):void { P.ensureAutoFormLinks(v); });
			host["patch"]("palette.ensureCssNoRecolorSettingLoaded", function():void { P.ensureCssNoRecolorSettingLoaded(); });
			host["patch"]("palette.cssShowNoRecolorWhenNoBase", function():Boolean { return P.cssShowNoRecolorWhenNoBase; });
			host["patch"]("palette.hasCodedBaseCostume", function(n:String):Boolean { return P.hasCodedBaseCostume(n); });
			host["patch"]("palette.applyResolvedCostumeToSetting", function(s:*, n:String):void { P.applyResolvedCostumeToSetting(s, n); });
			host["patch"]("palette.resolvePlayerSettingsCostumes", function(ps:*, cb:Function):void { P.resolvePlayerSettingsCostumes(ps, cb); });
			host["patch"]("palette.isCostumeSlotInCycle", function(n:String, slot:int):Boolean { return P.isCostumeSlotInCycle(n, slot); });
			host["patch"]("palette.stepCostumeCycle", function(n:String, slot:int, direction:int):int { return P.stepCostumeCycle(n, slot, direction); });
			host["patch"]("palette.syncDuringLoad", function(onProgress:Function, onDone:Function):Boolean { return P.syncDuringLoad(onProgress, onDone); });
			host["patch"]("palette.preloadAllColorVaultCostumes", function():void { P.preloadAllColorVaultCostumes(); });
			host["patch"]("palette.getCharsCompatibleWithCostumes", function():Array { return P.getCharsCompatibleWithCostumes(); });
			host["patch"]("palette.getStockIcon", function(n:String, b:Boolean):* { return P.getStockIcon(n, b); });
			host["patch"]("palette.getDisplayName", function(n:String):String { return P.displayNameFor(n); });
			host["patch"]("palette.showPaletteMakerLoadingScreen", function(n:String, v:Boolean):void { P.showPaletteMakerLoadingScreen(n, v); });
			host["patch"]("palette.holdCostumeGrid", function(menu:*):Boolean { P.holdCostumeGrid(menu); return (true); });
			host["patch"]("palette.loadCostumeFile", function(n:String):void { P.loadCostumeFile(n); });
			host["patch"]("palette.cancelPaletteMakerFreshnessCheck", function():void { P.cancelPaletteMakerFreshnessCheck(); });
			host["patch"]("palette.startPaletteMakerFreshnessCheck", function(cb:Function):void { P.startPaletteMakerFreshnessCheck(cb); });
			host["patch"]("palette.startPaletteMakerPreload", function(o:Object):void { P.startPaletteMakerPreload(o); });
			host["patch"]("palette.invalidateCharacterCachesBatch", function(a:Array):void { P.invalidateCharacterCachesBatch(a); });
			host["patch"]("palette.cacheDebugLog", function(m:String):void { P.cacheDebugLog(m); });
			host["patch"]("palette.get_batchCachePromptAnswered", function():Boolean { return P.batchCachePromptAnswered; });
			host["patch"]("palette.set_batchCachePromptAnswered", function(v:Boolean):void { P.batchCachePromptAnswered = v; });
			host["patch"]("palette.get_userDeclinedBatchCache", function():Boolean { return P.userDeclinedBatchCache; });
			host["patch"]("palette.set_userDeclinedBatchCache", function(v:Boolean):void { P.userDeclinedBatchCache = v; });
			host["patch"]("palette.set_warmDiscoverHandler", function(fn:Function):void { P.warmDiscoverHandler = fn; });
			host["patch"]("palette.set_warmUniqueHandler", function(fn:Function):void { P.warmUniqueHandler = fn; });
			host["patch"]("palette.set_warmUniqueIncrementalStartHandler", function(fn:Function):void { P.warmUniqueIncrementalStartHandler = fn; });
			host["patch"]("palette.set_warmUniqueIncrementalStepHandler", function(fn:Function):void { P.warmUniqueIncrementalStepHandler = fn; });
			host["patch"]("palette.menuClass", function():Class { return PaletteMakerMenu; });
			host["patch"]("palette.menu.setCharacter", function(n:String):void { PaletteMakerMenu.setCharacter(n); });
			host["patch"]("palette.menu.isSessionActive", function():Boolean { return PaletteMakerMenu.isSessionActive; });
			host["patch"]("palette.costumeSelectorClass", function():Class { return CostumeSelectorDisplay; });
			host["patch"]("palette.discordClass", function():Class { return DiscordCostumePresence; });
			host["patch"]("palette.discord.resolveLargeImage", function(k:String, t:String, ps:*):* { return DiscordCostumePresence.resolveLargeImage(k, t, ps); });
			host["patch"]("mergeCostumeList", function(charName:String, baseList:Array):Array
			{
				// Per-form vault JSON only; Zelda/Sheik/Bowser/Giga pair by CSS slot index.
				var custom:Array = P.getCostume(charName);
				return (((baseList) || ([]))).concat((custom) || ([]));
			});
		}
	}
}
