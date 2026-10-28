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

   public class ExpansionLibraryResources
   {
      internal static var s_oldAssetId:Object = {};

      private static var s_oldAssetLogged:Object = {};

      private static var s_oldAssetResolving:Object = {};

      public static function noteOldAssets(statsName:String, meta:Object) : void
      {
         var donor:String = null;
         if(!statsName || !meta || meta.oldassets != true || !meta.oldassetid)
         {
            return;
         }
         donor = String(meta.oldassetid);
         if(!donor || donor == statsName)
         {
            return;
         }
         s_oldAssetId[statsName] = donor;
         logOldAsset(statsName,"[ResourceManager] oldassets " + statsName + " id=" + donor);
         applyOldAssetCostumes(statsName);
      }

      public static function applyOldAssetCostumes(statsName:String) : void
      {
         var donor:String = oldAssetId(statsName);
         var misc:Resource = null;
         var costumeList:Array = null;
         var metalCostumeList:Object = null;
         if(!donor)
         {
            return;
         }
         misc = ResourceManager.getResourceByID("misc");
         if(!misc || !misc.getProp("metadata"))
         {
            return;
         }
         costumeList = misc.getProp("metadata").costume_data as Array;
         metalCostumeList = misc.getProp("metadata").metal_costume_data as Object;
         if(Boolean(costumeList) && Boolean(costumeList[donor]))
         {
            costumeList[statsName] = costumeList[donor];
         }
         if(Boolean(metalCostumeList) && Boolean(metalCostumeList[donor]))
         {
            metalCostumeList[statsName] = metalCostumeList[donor];
         }
      }

      public static function noteOldAssetsFile(statsName:String, file:File) : void
      {
         var stream:FileStream = null;
         var parsed:Object = null;
         if(!statsName || !file || !file.exists)
         {
            return;
         }
         try
         {
            stream = new FileStream();
            stream.open(file,FileMode.READ);
            parsed = JSON.parse(stream.readUTFBytes(stream.bytesAvailable)) as Object;
            stream.close();
            if(Boolean(parsed) && Boolean(parsed.id))
            {
               statsName = String(parsed.id);
            }
            noteOldAssets(statsName,parsed);
         }
         catch(err:*)
         {
         }
      }

      public static function oldAssetId(statsName:String) : String
      {
         if(!statsName || !s_oldAssetId[statsName])
         {
            return null;
         }
         return String(s_oldAssetId[statsName]);
      }

      public static function logOldAsset(key:String, line:String) : void
      {
         if(!key || s_oldAssetLogged[key])
         {
            return;
         }
         s_oldAssetLogged[key] = true;
         GameLog.write(line);
      }

      public static function oldAssetLibraryName(mcName:String) : String
      {
         var suffixes:Array = ["_allstar_congrats","_classic_trophy","_charselect","_congrats","_allstar","_classic","_stock","_cssp","_event","_select","_icon"];
         var i:int = 0;
         var suffix:String = null;
         var statsName:String = null;
         var donor:String = null;
         if(!mcName)
         {
            return null;
         }
         while(i < suffixes.length)
         {
            suffix = String(suffixes[i]);
            if(mcName.length > suffix.length && mcName.substr(mcName.length - suffix.length) == suffix)
            {
               statsName = mcName.substring(0,mcName.length - suffix.length);
               donor = oldAssetId(statsName);
               if(Boolean(donor) && donor != statsName)
               {
                  return donor + suffix;
               }
               return null;
            }
            i++;
         }
         return null;
      }

      public static function donorLibraryMC(statsName:String, suffix:String) : MovieClip
      {
         var donor:String = oldAssetId(statsName);
         var clip:MovieClip = null;
         if(!donor || !suffix)
         {
            return null;
         }
         clip = ExpansionPortraitResources.instantiateLibraryClass(donor + suffix);
         if(!clip)
         {
            return null;
         }
         logOldAsset(statsName + suffix,"[ResourceManager] oldassets " + statsName + suffix + " -> " + donor + suffix);
         return clip;
      }

      public static function tryGetLibraryMCPatch(mcName:String) : MovieClip
      {
         var redirected:String = null;
         var donorClip:MovieClip = null;
         if(!s_oldAssetResolving[mcName])
         {
            redirected = oldAssetLibraryName(mcName);
            if(Boolean(redirected))
            {
               s_oldAssetResolving[mcName] = true;
               try
               {
                  donorClip = ResourceManager.getLibraryMC(redirected);
               }
               finally
               {
                  delete s_oldAssetResolving[mcName];
               }
               if(Boolean(donorClip))
               {
                  logOldAsset(mcName,"[ResourceManager] oldassets " + mcName + " -> " + redirected);
                  return donorClip;
               }
            }
         }
         return RealExpansionsMod.resolveLibraryMC(mcName);
      }

      public static function tryGetPlaceholderClassic() : MovieClip
      {
         var myClass:Class = ResourceManager.getLibraryClass("placeholder_classic");
         if(Boolean(myClass))
         {
            return new myClass() as MovieClip;
         }
         return null;
      }

      public static function resolveXpStatsNameForLibrary() : String
      {
         var settings:* = undefined;
         var game:* = undefined;
         var expansionID:Number = Number(ResourceManager.m_activeXpExpansion);
         try
         {
            if(Boolean(MenuController.CurrentCharacterSelectMenu && MenuController.CurrentCharacterSelectMenu.GameObj) && Boolean(MenuController.CurrentCharacterSelectMenu.GameObj.PlayerSettings) && MenuController.CurrentCharacterSelectMenu.GameObj.PlayerSettings.length > 0)
            {
               settings = MenuController.CurrentCharacterSelectMenu.GameObj.PlayerSettings[0];
               if(Boolean(settings && settings.character == "xp") && Boolean(!isNaN(settings.expansion)) && settings.expansion >= 0)
               {
                  expansionID = Number(settings.expansion);
               }
            }
         }
         catch(e1:Error)
         {
         }
         try
         {
            game = EngineRefs.ssf2("controllers.GameController");
            if(Boolean(game) && Boolean(game.currentGame) && Boolean(game.currentGame.PlayerSettings) && game.currentGame.PlayerSettings.length > 0)
            {
               settings = game.currentGame.PlayerSettings[0];
               if(Boolean(settings && settings.character == "xp") && Boolean(!isNaN(settings.expansion)) && settings.expansion >= 0)
               {
                  expansionID = Number(settings.expansion);
               }
            }
         }
         catch(e2:Error)
         {
         }
         return Stats.resolveExpansionStatsName(expansionID);
      }

      public static function tryExpansionLibraryMC(mcName:String) : MovieClip
      {
         var statsName:String = null;
         var suffix:String = null;
         var linkageMC:MovieClip = null;
         var stageId:String = null;
         if(!mcName || mcName.length < 2)
         {
            return null;
         }
         if(mcName.length > 13 && mcName.substr(mcName.length - 13) == "_stage_select")
         {
            stageId = mcName.substring(0,mcName.length - 13);
            if(ExpansionStageResources.isExpansionStageId(stageId))
            {
               return ExpansionStageResources.makeStageSelectClip(stageId);
            }
            return null;
         }
         suffix = null;
         if(mcName == "xp")
         {
            statsName = resolveXpStatsNameForLibrary();
            if(!statsName || !ExpansionCharacterPacks.isExpansionStatsName(statsName))
            {
               return null;
            }
            return ExpansionPortraitResources.wrapClassicPortraitMC(ExpansionPortraitResources.getExpansionPortraitMC(statsName,ResourceManager.ALIGN_BOTTOM),statsName);
         }
         if(mcName.indexOf("_classic_trophy") == mcName.length - "_classic_trophy".length)
         {
            suffix = "_classic_trophy";
         }
         else if(mcName.indexOf("_classic") == mcName.length - "_classic".length)
         {
            suffix = "_classic";
         }
         else if(mcName.indexOf("_charselect") == mcName.length - "_charselect".length)
         {
            suffix = "_charselect";
         }
         else if(mcName.indexOf("_stock") == mcName.length - "_stock".length)
         {
            suffix = "_stock";
         }
         else
         {
            if(mcName.indexOf("_icon") != mcName.length - "_icon".length)
            {
               return null;
            }
            suffix = "_icon";
         }
         statsName = mcName.substring(0,mcName.length - suffix.length);
         if(statsName == "xp")
         {
            statsName = resolveXpStatsNameForLibrary();
         }
         linkageMC = donorLibraryMC(statsName,suffix);
         if(Boolean(linkageMC))
         {
            if(suffix == "_classic" || suffix == "_classic_trophy")
            {
               return ExpansionPortraitResources.wrapClassicPortraitMC(linkageMC,oldAssetId(statsName));
            }
            return linkageMC;
         }
         if(Boolean(oldAssetId(statsName)))
         {
            if(suffix == "_stock")
            {
               return ExpansionPortraitResources.instantiateLibraryClass("random_stock");
            }
            return null;
         }
         if(!statsName || !ExpansionCharacterPacks.isExpansionStatsName(statsName))
         {
            return null;
         }
         if(suffix == "_stock")
         {
            linkageMC = ExpansionPortraitResources.getExpansionStockMC(statsName);
            if(Boolean(linkageMC))
            {
               return linkageMC;
            }
            return ExpansionPortraitResources.instantiateLibraryClass("random_stock");
         }
         if(suffix == "_charselect")
         {
            return ExpansionPortraitResources.getExpansionCharSelectMC(statsName);
         }
         if(suffix == "_icon")
         {
            return null;
         }
         return ExpansionPortraitResources.wrapClassicPortraitMC(ExpansionPortraitResources.getExpansionPortraitMC(statsName,ResourceManager.ALIGN_BOTTOM),statsName);
      }
   }
}
