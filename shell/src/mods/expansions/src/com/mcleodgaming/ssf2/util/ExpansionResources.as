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

   /** Public facade: the static API lives in the Expansion*Resources / ExpansionCharacterPacks / ExpansionCssSidecars classes. */
   public class ExpansionResources
   {
      public static function dispatch(op:String, a:* = null, b:* = null, c:* = null, d:* = null, e:* = null, f:* = null, g:* = null) : *
      {
         try
         {
            return ExpansionResourceOps.run(op, a, b, c, d, e, f, g);
         }
         catch(err:*)
         {
            ExpansionResourceLog.step("dispatch " + op, err);
            throw err;
         }
         return null;
      }

      public static function getStageExpansions() : Array
      {
         return ExpansionStageResources.getStageExpansions();
      }

      public static function isExpansionStageId(id:String) : Boolean
      {
         return ExpansionStageResources.isExpansionStageId(id);
      }

      public static function discoverDroppedExpansions() : void
      {
         ExpansionCharacterPacks.discoverDroppedExpansions();
      }

      public static function discoverStageExpansions() : void
      {
         ExpansionStageResources.discoverStageExpansions();
      }

      public static function readStageExpansionName(file:File, fallback:String) : String
      {
         return ExpansionStageResources.readStageExpansionName(file, fallback);
      }

      public static function makeStageSelectClip(id:String) : MovieClip
      {
         return ExpansionStageResources.makeStageSelectClip(id);
      }

      public static function applyBigStagePreview(previewer:MovieClip, stageId:String) : void
      {
         ExpansionStageResources.applyBigStagePreview(previewer, stageId);
      }

      public static function clearBigStagePreview(previewer:MovieClip) : void
      {
         ExpansionStageResources.clearBigStagePreview(previewer);
      }

      public static function ensureStageClip(id:String) : MovieClip
      {
         return ExpansionStageResources.ensureStageClip(id);
      }

      public static function discoverExpansionEntries(folder:File, relativeDir:String) : void
      {
         ExpansionCharacterPacks.discoverExpansionEntries(folder, relativeDir);
      }

      public static function isExpansionPackFileName(name:String) : Boolean
      {
         return ExpansionCharacterPacks.isExpansionPackFileName(name);
      }

      public static function registerDiscoveredExpansion(relativeDir:String, fileName:String, stockPng:File, paPng:File, costumesJson:File = null, settingsJson:File = null, announcerMp3:File = null) : void
      {
         ExpansionCharacterPacks.registerDiscoveredExpansion(relativeDir, fileName, stockPng, paPng, costumesJson, settingsJson, announcerMp3);
      }

      public static function compareExpansionListingFiles(a:*, b:*) : int
      {
         return ExpansionCharacterPacks.compareExpansionListingFiles(a, b);
      }

      public static function sortExpansionDataSlots() : void
      {
         ExpansionCharacterPacks.sortExpansionDataSlots();
      }

      public static function getExpansionSlotSortKey(slot:Vector.<Object>) : String
      {
         return ExpansionCharacterPacks.getExpansionSlotSortKey(slot);
      }

      public static function compareExpansionDataSlots(a:*, b:*) : int
      {
         return ExpansionCharacterPacks.compareExpansionDataSlots(a, b);
      }

      public static function isExpansionStatsName(statsName:String) : Boolean
      {
         return ExpansionCharacterPacks.isExpansionStatsName(statsName);
      }

      public static function getResourceIdForCharacter(statsName:String) : String
      {
         return ExpansionCharacterPacks.getResourceIdForCharacter(statsName);
      }

      public static function getExpansionStockBitmapData(statsName:String) : BitmapData
      {
         return ExpansionPortraitResources.getExpansionStockBitmapData(statsName);
      }

      public static function getExpansionPABitmapData(statsName:String) : BitmapData
      {
         return ExpansionPortraitResources.getExpansionPABitmapData(statsName);
      }

      public static function getExpansionStockMC(statsName:String) : MovieClip
      {
         return ExpansionPortraitResources.getExpansionStockMC(statsName);
      }

      public static function wrapStockBitmapData(bd:BitmapData) : MovieClip
      {
         return ExpansionPortraitResources.wrapStockBitmapData(bd);
      }

      public static function tryRealExpansionFolderStockMC(statsName:String) : MovieClip
      {
         return ExpansionPortraitResources.tryRealExpansionFolderStockMC(statsName);
      }

      public static function tryInstantiateRealExpansionAssets(statsName:String, suffix:String) : MovieClip
      {
         return ExpansionPortraitResources.tryInstantiateRealExpansionAssets(statsName, suffix);
      }

      public static function wrapClassicPortraitMC(art:MovieClip, statsName:String = null) : MovieClip
      {
         return ExpansionPortraitResources.wrapClassicPortraitMC(art, statsName);
      }

      public static function getExpansionPortraitMC(statsName:String, vAlign:String = null) : MovieClip
      {
         return ExpansionPortraitResources.getExpansionPortraitMC(statsName, vAlign);
      }

      public static function getExpansionCharSelectMC(statsName:String) : MovieClip
      {
         return ExpansionPortraitResources.getExpansionCharSelectMC(statsName);
      }

      public static function getCssPaYNudge(statsName:String) : Number
      {
         return ExpansionPortraitResources.getCssPaYNudge(statsName);
      }

      public static function getClassicPaYNudge(statsName:String) : Number
      {
         return ExpansionPortraitResources.getClassicPaYNudge(statsName);
      }

      public static function bitmapDataToFittedMC(bd:BitmapData, targetW:Number, targetH:Number, vAlign:String = null) : MovieClip
      {
         return ExpansionPortraitResources.bitmapDataToFittedMC(bd, targetW, targetH, vAlign);
      }

      public static function sanitizeExpansionUiLinkages(cData:Object) : void
      {
         ExpansionCharacterPacks.sanitizeExpansionUiLinkages(cData);
      }

      public static function bindExpansionStatsToResource(resource:Resource, expansionChars:Array) : void
      {
         ExpansionCharacterPacks.bindExpansionStatsToResource(resource, expansionChars);
      }

      public static function loadExpansionSettingsJson(statsName:String, file:File) : void
      {
         ExpansionCharacterPacks.loadExpansionSettingsJson(statsName, file);
      }

      public static function loadExpansionCostumesJson(statsName:String, file:File) : void
      {
         ExpansionCostumeResources.loadExpansionCostumesJson(statsName, file);
      }

      public static function parseCostumesAsScript(text:String, statsName:String) : Object
      {
         return ExpansionCostumeResources.parseCostumesAsScript(text, statsName);
      }

      public static function findMatchingBrace(text:String, openIdx:int) : int
      {
         return ExpansionCostumeResources.findMatchingBrace(text, openIdx);
      }

      public static function tryParseCostumeObjectLiteral(objText:String) : Object
      {
         return ExpansionCostumeResources.tryParseCostumeObjectLiteral(objText);
      }

      public static function loadExpansionPng(statsName:String, file:File, isPA:Boolean) : void
      {
         ExpansionCharacterPacks.loadExpansionPng(statsName, file, isPA);
      }

      public static function loadPendingExpansions(onDone:Function = null) : void
      {
         ExpansionCharacterPacks.loadPendingExpansions(onDone);
      }

      public static function readExpansionCssCache(relFile:String) : Object
      {
         return ExpansionCssSidecars.readExpansionCssCache(relFile);
      }

      public static function getLiveSeriesIconMC(seriesIcon:String) : MovieClip
      {
         return ExpansionPortraitResources.getLiveSeriesIconMC(seriesIcon);
      }

      public static function getRosterSeriesIconMC(statsName:String) : MovieClip
      {
         return ExpansionPortraitResources.getRosterSeriesIconMC(statsName);
      }

      public static function vectorIcon(op:String, a:* = null, b:* = null) : *
      {
         return ExpansionPortraitResources.vectorIcon(op, a, b);
      }

      public static function shouldTraceUiLink(name:String) : Boolean
      {
         return ExpansionPortraitResources.shouldTraceUiLink(name);
      }

      public static function refreshCssPortraitIfSelected(statsName:String) : void
      {
         ExpansionPortraitResources.refreshCssPortraitIfSelected(statsName);
      }

      public static function expansionPackFolder(res:Resource) : File
      {
         return ExpansionCssSidecars.expansionPackFolder(res);
      }

      public static function applyCssMetaToStats(id:String, folder:File) : Boolean
      {
         return ExpansionCssSidecars.applyCssMetaToStats(id, folder);
      }

      public static function writableFile(file:File) : File
      {
         return ExpansionCssSidecars.writableFile(file);
      }

      public static function loadRosterSeriesIconSvg(statsName:String, file:File) : Boolean
      {
         return ExpansionCssSidecars.loadRosterSeriesIconSvg(statsName, file);
      }

      public static function writeExpansionCssSidecars(res:Resource, stats:CharacterData, svg:String) : void
      {
         ExpansionCssSidecars.writeExpansionCssSidecars(res, stats, svg);
      }

      public static function captureAndDisposeExpansionCss(res:Resource) : void
      {
         ExpansionCssSidecars.captureAndDisposeExpansionCss(res);
      }

      public static function hydrateAndExtractExpansionCss(onDone:Function) : void
      {
         ExpansionCssSidecars.hydrateAndExtractExpansionCss(onDone);
      }

      public static function loadRealExpansionUiTemplates(onDone:Function = null) : void
      {
         ExpansionCssSidecars.loadRealExpansionUiTemplates(onDone);
      }

      public static function loadRealExpansionCostumesSidecars() : void
      {
         ExpansionCostumeResources.loadRealExpansionCostumesSidecars();
      }

      public static function applyClassicJsonPacks() : void
      {
         ExpansionCharacterPacks.applyClassicJsonPacks();
      }

      public static function queuePlayerCharacterResource(setting:Object, randIndex:int = -1) : void
      {
         ExpansionCharacterPacks.queuePlayerCharacterResource(setting, randIndex);
      }

      public static function registerLoadedResource(res:Resource) : void
      {
         ExpansionCharacterPacks.registerLoadedResource(res);
      }

      public static function checkMissingEmptyFrameOnes() : void
      {
         ExpansionCharacterPacks.checkMissingEmptyFrameOnes();
      }

      public static function instantiateLibraryClass(className:String) : MovieClip
      {
         return ExpansionPortraitResources.instantiateLibraryClass(className);
      }

      public static function getSafeUiIconMC(mcName:String) : MovieClip
      {
         return ExpansionPortraitResources.getSafeUiIconMC(mcName);
      }

      public static function noteOldAssets(statsName:String, meta:Object) : void
      {
         ExpansionLibraryResources.noteOldAssets(statsName, meta);
      }

      public static function applyOldAssetCostumes(statsName:String) : void
      {
         ExpansionLibraryResources.applyOldAssetCostumes(statsName);
      }

      public static function noteOldAssetsFile(statsName:String, file:File) : void
      {
         ExpansionLibraryResources.noteOldAssetsFile(statsName, file);
      }

      public static function oldAssetId(statsName:String) : String
      {
         return ExpansionLibraryResources.oldAssetId(statsName);
      }

      public static function logOldAsset(key:String, line:String) : void
      {
         ExpansionLibraryResources.logOldAsset(key, line);
      }

      public static function oldAssetLibraryName(mcName:String) : String
      {
         return ExpansionLibraryResources.oldAssetLibraryName(mcName);
      }

      public static function donorLibraryMC(statsName:String, suffix:String) : MovieClip
      {
         return ExpansionLibraryResources.donorLibraryMC(statsName, suffix);
      }

      public static function tryGetLibraryMCPatch(mcName:String) : MovieClip
      {
         return ExpansionLibraryResources.tryGetLibraryMCPatch(mcName);
      }

      public static function tryGetPlaceholderClassic() : MovieClip
      {
         return ExpansionLibraryResources.tryGetPlaceholderClassic();
      }

      public static function resolveXpStatsNameForLibrary() : String
      {
         return ExpansionLibraryResources.resolveXpStatsNameForLibrary();
      }

      public static function tryExpansionLibraryMC(mcName:String) : MovieClip
      {
         return ExpansionLibraryResources.tryExpansionLibraryMC(mcName);
      }

      public static function getExpansionAnnouncerId(statsName:String) : String
      {
         return ExpansionAudioResources.getExpansionAnnouncerId(statsName);
      }

      public static function tryGetExpansionAnnouncerSound(soundName:String) : Sound
      {
         return ExpansionAudioResources.tryGetExpansionAnnouncerSound(soundName);
      }

      public static function tryLoadExpansionAnnouncerFromFolder(statsName:String, folder:File) : void
      {
         ExpansionAudioResources.tryLoadExpansionAnnouncerFromFolder(statsName, folder);
      }

      public static function loadExpansionAnnouncer(statsName:String, file:File) : void
      {
         ExpansionAudioResources.loadExpansionAnnouncer(statsName, file);
      }

      public static function resolveCostumeStatsName(charName:String) : String
      {
         return ExpansionCostumeResources.resolveCostumeStatsName(charName);
      }

      public static function getMergedCostumeList(charName:String) : Array
      {
         return ExpansionCostumeResources.getMergedCostumeList(charName);
      }

      public static function buildSelectableTeamMetalSlots(charName:String, costumeData:Object) : Array
      {
         return ExpansionCostumeResources.buildSelectableTeamMetalSlots(charName, costumeData);
      }

      public static function metalCostumeHasPalette(metal:Object) : Boolean
      {
         return ExpansionCostumeResources.metalCostumeHasPalette(metal);
      }

      public static function setActiveXpExpansion(expansionID:Number) : void
      {
         ExpansionCharacterPacks.setActiveXpExpansion(expansionID);
      }

      public static function get ActiveXpExpansion() : int
      {
         return ExpansionCharacterPacks.ActiveXpExpansion;
      }

      public static function expansionHasTargetTest(statsName:String) : Boolean
      {
         return ExpansionCharacterPacks.expansionHasTargetTest(statsName);
      }

      public static function anyExpansionHasTargetTest() : Boolean
      {
         return ExpansionCharacterPacks.anyExpansionHasTargetTest();
      }

      public static function getNextExpansionWithTargetTest(idNumber:Number) : Number
      {
         return ExpansionCharacterPacks.getNextExpansionWithTargetTest(idNumber);
      }

      public static function getPrevExpansionWithTargetTest(idNumber:Number) : Number
      {
         return ExpansionCharacterPacks.getPrevExpansionWithTargetTest(idNumber);
      }

      public static function getFirstExpansionWithTargetTest() : Number
      {
         return ExpansionCharacterPacks.getFirstExpansionWithTargetTest();
      }

      public static function appendExpansionCostumes() : void
      {
         ExpansionCostumeResources.appendExpansionCostumes();
      }

      public static function registerExpansionCostumeData(statsName:String, costumes:Array) : void
      {
         ExpansionCostumeResources.registerExpansionCostumeData(statsName, costumes);
      }
   }
}
