package com.mcleodgaming.ssf2.util
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.api.*;
   import com.mcleodgaming.ssf2.controllers.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.modhost.*;
   import flash.display.*;
   import flash.events.*;
   import flash.filesystem.*;
   import flash.media.*;
   import flash.system.*;
   import flash.utils.ByteArray;
   import ssf2mm.shared.EngineRefs;

   /** Op table behind ExpansionResources.dispatch: one switch per resource area. */
   public class ExpansionResourceOps
   {
      private static const UNHANDLED:Object = {};

      public static function run(op:String, a:*, b:*, c:*, d:*, e:*, f:*, g:*) : *
      {
         var r:* = UNHANDLED;
         r = runStageResources(op, a, b, c, d, e, f, g);
         if(r === UNHANDLED) r = runCharacterPacks(op, a, b, c, d, e, f, g);
         if(r === UNHANDLED) r = runPortraitResources(op, a, b, c, d, e, f, g);
         if(r === UNHANDLED) r = runCostumeResources(op, a, b, c, d, e, f, g);
         if(r === UNHANDLED) r = runCssSidecars(op, a, b, c, d, e, f, g);
         if(r === UNHANDLED) r = runLibraryResources(op, a, b, c, d, e, f, g);
         if(r === UNHANDLED) r = runAudioResources(op, a, b, c, d, e, f, g);
         return r === UNHANDLED ? null : r;
      }

      private static function runStageResources(op:String, a:*, b:*, c:*, d:*, e:*, f:*, g:*) : *
      {
         switch(op)
         {
         case "getStageExpansions":
            return ExpansionStageResources.getStageExpansions();
         case "discoverStageExpansions":
            ExpansionStageResources.discoverStageExpansions();
            return null;
         case "readStageExpansionName":
            return ExpansionStageResources.readStageExpansionName(a, b);
         case "isExpansionStageId":
            return ExpansionStageResources.isExpansionStageId(a);
         case "applyBigStagePreview":
            ExpansionStageResources.applyBigStagePreview(a, b);
            return null;
         case "clearBigStagePreview":
            ExpansionStageResources.clearBigStagePreview(a);
            return null;
         case "ensureStageClip":
            return ExpansionStageResources.ensureStageClip(a);
            default:
               return UNHANDLED;
         }
      }

      private static function runCharacterPacks(op:String, a:*, b:*, c:*, d:*, e:*, f:*, g:*) : *
      {
         switch(op)
         {
         case "discoverDroppedExpansions":
            ExpansionCharacterPacks.discoverDroppedExpansions();
            return null;
         case "discoverExpansionEntries":
            ExpansionCharacterPacks.discoverExpansionEntries(a, b);
            return null;
         case "isExpansionPackFileName":
            return ExpansionCharacterPacks.isExpansionPackFileName(a);
         case "registerDiscoveredExpansion":
            ExpansionCharacterPacks.registerDiscoveredExpansion(a, b, c, d, e, f, g);
            return null;
         case "compareExpansionListingFiles":
            return ExpansionCharacterPacks.compareExpansionListingFiles(a, b);
         case "sortExpansionDataSlots":
            ExpansionCharacterPacks.sortExpansionDataSlots();
            return null;
         case "getExpansionSlotSortKey":
            return ExpansionCharacterPacks.getExpansionSlotSortKey(a);
         case "compareExpansionDataSlots":
            return ExpansionCharacterPacks.compareExpansionDataSlots(a, b);
         case "isExpansionStatsName":
            return ExpansionCharacterPacks.isExpansionStatsName(a);
         case "getResourceIdForCharacter":
            return ExpansionCharacterPacks.getResourceIdForCharacter(a);
         case "sanitizeExpansionUiLinkages":
            ExpansionCharacterPacks.sanitizeExpansionUiLinkages(a);
            return null;
         case "bindExpansionStatsToResource":
            ExpansionCharacterPacks.bindExpansionStatsToResource(a, b);
            return null;
         case "loadExpansionSettingsJson":
            ExpansionCharacterPacks.loadExpansionSettingsJson(a, b);
            return null;
         case "loadExpansionPng":
            ExpansionCharacterPacks.loadExpansionPng(a, b, c);
            return null;
         case "loadPendingExpansions":
            ExpansionCharacterPacks.loadPendingExpansions(a);
            return null;
         case "applyClassicJsonPacks":
            ExpansionCharacterPacks.applyClassicJsonPacks();
            return null;
         case "queuePlayerCharacterResource":
            ExpansionCharacterPacks.queuePlayerCharacterResource(a, b);
            return null;
         case "registerLoadedResource":
            ExpansionCharacterPacks.registerLoadedResource(a);
            return null;
         case "checkMissingEmptyFrameOnes":
            ExpansionCharacterPacks.checkMissingEmptyFrameOnes();
            return null;
         case "setActiveXpExpansion":
            ExpansionCharacterPacks.setActiveXpExpansion(a);
            return null;
         case "get_ActiveXpExpansion":
            return ExpansionCharacterPacks.ActiveXpExpansion;
         case "expansionHasTargetTest":
            return ExpansionCharacterPacks.expansionHasTargetTest(a);
         case "anyExpansionHasTargetTest":
            return ExpansionCharacterPacks.anyExpansionHasTargetTest();
         case "getNextExpansionWithTargetTest":
            return ExpansionCharacterPacks.getNextExpansionWithTargetTest(a);
         case "getPrevExpansionWithTargetTest":
            return ExpansionCharacterPacks.getPrevExpansionWithTargetTest(a);
         case "getFirstExpansionWithTargetTest":
            return ExpansionCharacterPacks.getFirstExpansionWithTargetTest();
            default:
               return UNHANDLED;
         }
      }

      private static function runPortraitResources(op:String, a:*, b:*, c:*, d:*, e:*, f:*, g:*) : *
      {
         switch(op)
         {
         case "getExpansionStockBitmapData":
            return ExpansionPortraitResources.getExpansionStockBitmapData(a);
         case "getExpansionPABitmapData":
            return ExpansionPortraitResources.getExpansionPABitmapData(a);
         case "getExpansionStockMC":
            return ExpansionPortraitResources.getExpansionStockMC(a);
         case "wrapStockBitmapData":
            return ExpansionPortraitResources.wrapStockBitmapData(a);
         case "tryRealExpansionFolderStockMC":
            return ExpansionPortraitResources.tryRealExpansionFolderStockMC(a);
         case "tryInstantiateRealExpansionAssets":
            return ExpansionPortraitResources.tryInstantiateRealExpansionAssets(a, b);
         case "wrapClassicPortraitMC":
            return ExpansionPortraitResources.wrapClassicPortraitMC(a, b);
         case "getExpansionPortraitMC":
            return ExpansionPortraitResources.getExpansionPortraitMC(a, b);
         case "getExpansionCharSelectMC":
            return ExpansionPortraitResources.getExpansionCharSelectMC(a);
         case "getCssPaYNudge":
            return ExpansionPortraitResources.getCssPaYNudge(a);
         case "getClassicPaYNudge":
            return ExpansionPortraitResources.getClassicPaYNudge(a);
         case "bitmapDataToFittedMC":
            return ExpansionPortraitResources.bitmapDataToFittedMC(a, b, c, d);
         case "getLiveSeriesIconMC":
            return ExpansionPortraitResources.getLiveSeriesIconMC(a);
         case "getRosterSeriesIconMC":
            return ExpansionPortraitResources.getRosterSeriesIconMC(a);
         case "vectorIcon":
            return ExpansionPortraitResources.vectorIcon(a, b, c);
         case "shouldTraceUiLink":
            return ExpansionPortraitResources.shouldTraceUiLink(a);
         case "refreshCssPortraitIfSelected":
            ExpansionPortraitResources.refreshCssPortraitIfSelected(a);
            return null;
         case "instantiateLibraryClass":
            return ExpansionPortraitResources.instantiateLibraryClass(a);
         case "getSafeUiIconMC":
            return ExpansionPortraitResources.getSafeUiIconMC(a);
            default:
               return UNHANDLED;
         }
      }

      private static function runCostumeResources(op:String, a:*, b:*, c:*, d:*, e:*, f:*, g:*) : *
      {
         switch(op)
         {
         case "loadExpansionCostumesJson":
            ExpansionCostumeResources.loadExpansionCostumesJson(a, b);
            return null;
         case "parseCostumesAsScript":
            return ExpansionCostumeResources.parseCostumesAsScript(a, b);
         case "findMatchingBrace":
            return ExpansionCostumeResources.findMatchingBrace(a, b);
         case "tryParseCostumeObjectLiteral":
            return ExpansionCostumeResources.tryParseCostumeObjectLiteral(a);
         case "loadRealExpansionCostumesSidecars":
            ExpansionCostumeResources.loadRealExpansionCostumesSidecars();
            return null;
         case "resolveCostumeStatsName":
            return ExpansionCostumeResources.resolveCostumeStatsName(a);
         case "getMergedCostumeList":
            return ExpansionCostumeResources.getMergedCostumeList(a);
         case "buildSelectableTeamMetalSlots":
            return ExpansionCostumeResources.buildSelectableTeamMetalSlots(a, b);
         case "metalCostumeHasPalette":
            return ExpansionCostumeResources.metalCostumeHasPalette(a);
         case "appendExpansionCostumes":
            ExpansionCostumeResources.appendExpansionCostumes();
            return null;
         case "registerExpansionCostumeData":
            ExpansionCostumeResources.registerExpansionCostumeData(a, b);
            return null;
            default:
               return UNHANDLED;
         }
      }

      private static function runCssSidecars(op:String, a:*, b:*, c:*, d:*, e:*, f:*, g:*) : *
      {
         switch(op)
         {
         case "readExpansionCssCache":
            return ExpansionCssSidecars.readExpansionCssCache(a);
         case "expansionPackFolder":
            return ExpansionCssSidecars.expansionPackFolder(a);
         case "applyCssMetaToStats":
            return ExpansionCssSidecars.applyCssMetaToStats(a, b);
         case "writableFile":
            return ExpansionCssSidecars.writableFile(a);
         case "loadRosterSeriesIconSvg":
            return ExpansionCssSidecars.loadRosterSeriesIconSvg(a, b);
         case "writeExpansionCssSidecars":
            ExpansionCssSidecars.writeExpansionCssSidecars(a, b, c);
            return null;
         case "captureAndDisposeExpansionCss":
            ExpansionCssSidecars.captureAndDisposeExpansionCss(a);
            return null;
         case "hydrateAndExtractExpansionCss":
            ExpansionCssSidecars.hydrateAndExtractExpansionCss(a);
            return null;
         case "loadRealExpansionUiTemplates":
            ExpansionCssSidecars.loadRealExpansionUiTemplates(a);
            return null;
            default:
               return UNHANDLED;
         }
      }

      private static function runLibraryResources(op:String, a:*, b:*, c:*, d:*, e:*, f:*, g:*) : *
      {
         switch(op)
         {
         case "tryGetLibraryMCPatch":
            return ExpansionLibraryResources.tryGetLibraryMCPatch(a);
         case "tryGetPlaceholderClassic":
            return ExpansionLibraryResources.tryGetPlaceholderClassic();
         case "resolveXpStatsNameForLibrary":
            return ExpansionLibraryResources.resolveXpStatsNameForLibrary();
         case "tryExpansionLibraryMC":
            return ExpansionLibraryResources.tryExpansionLibraryMC(a);
            default:
               return UNHANDLED;
         }
      }

      private static function runAudioResources(op:String, a:*, b:*, c:*, d:*, e:*, f:*, g:*) : *
      {
         switch(op)
         {
         case "getExpansionAnnouncerId":
            return ExpansionAudioResources.getExpansionAnnouncerId(a);
         case "tryGetExpansionAnnouncerSound":
            return ExpansionAudioResources.tryGetExpansionAnnouncerSound(a);
         case "tryLoadExpansionAnnouncerFromFolder":
            ExpansionAudioResources.tryLoadExpansionAnnouncerFromFolder(a, b);
            return null;
         case "loadExpansionAnnouncer":
            ExpansionAudioResources.loadExpansionAnnouncer(a, b);
            return null;
            default:
               return UNHANDLED;
         }
      }
   }
}
