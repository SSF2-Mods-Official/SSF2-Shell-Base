package
{
	import flash.display.Sprite;
	import com.sbxmod.paletteMaker.PaletteMakerUtils;
	import com.sbxmod.paletteMaker.PaletteMakerMenu;
	import com.sbxmod.paletteMaker.CostumeSelectorDisplay;
	import com.sbxmod.paletteMaker.DiscordCostumePresence;
	import com.sbxmod.paletteMaker.PaletteMakerAchievements;
	import com.sbxmod.paletteMaker.PaletteMakerShortcuts;
	import com.sbxmod.paletteMaker.CostumeFxPaletteRuntime;
	import com.sbxmod.paletteMaker.ColorVaultSync;
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

		public function onBoot(host:*):void
		{
			var _force:* = LINK[0];
			if (host)
			{
				try
				{
					registerPaletteDoors(host);
					host["patch"]("combinePaletteBlocks", PaletteDeep.combinePaletteBlocksStock);
					host["patch"]("applyCostumeMcName", PaletteDeep.applyCostumeMcName);
					host["patch"]("advanceEffectFrame", PaletteDeep.advanceEffectFrame);
					host["patch"]("isFragileTimelineClip", PaletteDeep.isFragileTimelineClip);
					CostumeFxPaletteRuntime.boot(host);
					host.addHook("CSS_SELECT_CHARACTER", onCssSelectMenu);
					host.addHook("ONLINE_MENU_SHOW", onOnlineMenuShow);
				}
				catch (err:*)
				{
					trace("[palette_maker] register doors failed: " + err);
				};
			};
			trace("[palette_maker] boot doors registered linked=" + (_force != null));
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
			host["patch"]("palette.isFormLinked", function(n:String):Boolean { return P.isFormLinked(n); });
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
			host["patch"]("palette.showPaletteMakerLoadingScreen", function(n:String, v:Boolean):void { P.showPaletteMakerLoadingScreen(n, v); });
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
