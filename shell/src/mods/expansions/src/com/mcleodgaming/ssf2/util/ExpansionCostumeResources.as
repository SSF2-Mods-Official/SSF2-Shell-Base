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

   public class ExpansionCostumeResources
   {
      public static function loadExpansionCostumesJson(statsName:String, file:File) : void
      {
         var stream:FileStream = null;
         var text:String = null;
         var raw:* = undefined;
         var costumes:Array = null;
         var metal:Object = null;
         var list:Array = null;
         var i:int = 0;
         var entry:Object = null;
         var metalFlag:* = undefined;
         var k:String = null;
         var cleanMetal:Object = null;
         var parsed:Object = null;
         if(!statsName || !file || !file.exists)
         {
            return;
         }
         try
         {
            stream = new FileStream();
            stream.open(file,FileMode.READ);
            text = stream.readUTFBytes(stream.bytesAvailable);
            stream.close();
         }
         catch(readErr:Error)
         {
            GameLog.write("[ResourceManager] costumes file read failed for " + statsName + ": " + readErr.message);
            return;
         }
         costumes = [];
         metal = null;
         list = null;
         raw = null;
         try
         {
            raw = JSON.parse(text);
         }
         catch(jsonErr:Error)
         {
            raw = null;
         }
         if(raw == null)
         {
            parsed = parseCostumesAsScript(text,statsName);
            if(!Boolean(parsed))
            {
               GameLog.write("[ResourceManager] costumes file parse failed for " + statsName);
               return;
            }
            list = parsed.costumes as Array;
            metal = parsed.metal as Object;
         }
         else if(raw is Array)
         {
            list = raw as Array;
         }
         else if(Boolean(raw))
         {
            if(raw.costumes is Array)
            {
               list = raw.costumes as Array;
            }
            else if(raw.costume_data is Array)
            {
               list = raw.costume_data as Array;
            }
            else if(raw[statsName] is Array)
            {
               list = raw[statsName] as Array;
            }
            if(Boolean(raw.metal))
            {
               metal = raw.metal as Object;
            }
            else if(Boolean(raw.metal_costume))
            {
               metal = raw.metal_costume as Object;
            }
            else if(Boolean(raw.metal_costume_data))
            {
               metal = raw.metal_costume_data as Object;
            }
         }
         if(Boolean(list))
         {
            i = 0;
            while(i < list.length)
            {
               entry = list[i] as Object;
               if(Boolean(entry))
               {
                  metalFlag = entry["metal"];
                  if(metalFlag === true || metalFlag === "true" || metalFlag === 1)
                  {
                     cleanMetal = {};
                     for(k in entry)
                     {
                        if(k != "metal")
                        {
                           cleanMetal[k] = entry[k];
                        }
                     }
                     metal = cleanMetal;
                  }
                  else
                  {
                     costumes.push(entry);
                  }
               }
               i++;
            }
         }
         if(costumes.length > 0)
         {
            ResourceManager.m_expansionCostumeData[statsName] = costumes;
            GameLog.write("[ResourceManager] Loaded costumes (" + costumes.length + ") for " + statsName + " from " + file.name);
         }
         if(Boolean(metal))
         {
            ResourceManager.m_expansionMetalCostumeData[statsName] = metal;
            GameLog.write("[ResourceManager] Loaded metal costume for " + statsName + " from " + file.name);
         }
         else
         {
            delete ResourceManager.m_expansionMetalCostumeData[statsName];
         }
      }

      public static function parseCostumesAsScript(text:String, statsName:String) : Object
      {
         var byKey:Object = null;
         var key:String = null;
         var pushIdx:int = 0;
         var keyStart:int = 0;
         var keyEnd:int = 0;
         var braceStart:int = 0;
         var braceEnd:int = 0;
         var objText:String = null;
         var obj:* = undefined;
         var preferred:Array = null;
         var onlyKey:String = null;
         var keyCount:int = 0;
         var metal:Object = null;
         var costumes:Array = null;
         var i:int = 0;
         var entry:Object = null;
         var metalFlag:* = undefined;
         var k:String = null;
         var cleanMetal:Object = null;
         if(!text || text.length < 8)
         {
            return null;
         }
         if(text.indexOf(".push(") < 0 && text.indexOf("_loc1_") < 0)
         {
            return null;
         }
         byKey = {};
         pushIdx = 0;
         while(true)
         {
            pushIdx = text.indexOf(".push(",pushIdx);
            if(pushIdx < 0)
            {
               break;
            }
            key = null;
            keyEnd = pushIdx;
            keyStart = text.lastIndexOf("[",keyEnd);
            if(keyStart >= 0 && keyStart > pushIdx - 80)
            {
               if(text.charAt(keyStart + 1) == "\"" || text.charAt(keyStart + 1) == "\'")
               {
                  keyEnd = text.indexOf(text.charAt(keyStart + 1),keyStart + 2);
                  if(keyEnd > keyStart)
                  {
                     key = text.substring(keyStart + 2,keyEnd);
                  }
               }
            }
            braceStart = text.indexOf("{",pushIdx + 5);
            if(braceStart < 0)
            {
               pushIdx += 6;
            }
            else
            {
               braceEnd = int(findMatchingBrace(text,braceStart));
               if(braceEnd < 0)
               {
                  pushIdx += 6;
               }
               else
               {
                  objText = text.substring(braceStart,braceEnd + 1);
                  obj = tryParseCostumeObjectLiteral(objText);
                  if(Boolean(obj))
                  {
                     if(!key || key.length == 0)
                     {
                        key = statsName || "_default";
                     }
                     if(!(byKey[key] is Array))
                     {
                        byKey[key] = [];
                     }
                     (byKey[key] as Array).push(obj);
                  }
                  pushIdx = braceEnd + 1;
               }
            }
         }
         preferred = null;
         if(byKey[statsName] is Array)
         {
            preferred = byKey[statsName] as Array;
         }
         else
         {
            keyCount = 0;
            onlyKey = null;
            for(key in byKey)
            {
               keyCount++;
               onlyKey = key;
            }
            if(keyCount == 1 && byKey[onlyKey] is Array)
            {
               preferred = byKey[onlyKey] as Array;
               GameLog.write("[ResourceManager] costumes.as key \"" + onlyKey + "\" mapped to statsName \"" + statsName + "\"");
            }
         }
         if(!preferred || preferred.length == 0)
         {
            return null;
         }
         costumes = [];
         metal = null;
         i = 0;
         while(i < preferred.length)
         {
            entry = preferred[i] as Object;
            if(Boolean(entry))
            {
               metalFlag = entry["metal"];
               if(metalFlag === true || metalFlag === "true" || metalFlag === 1)
               {
                  cleanMetal = {};
                  for(k in entry)
                  {
                     if(k != "metal")
                     {
                        cleanMetal[k] = entry[k];
                     }
                  }
                  metal = cleanMetal;
               }
               else
               {
                  costumes.push(entry);
               }
            }
            i++;
         }
         return {
            "costumes":costumes,
            "metal":metal
         };
      }

      public static function findMatchingBrace(text:String, openIdx:int) : int
      {
         var depth:int = 0;
         var i:int = 0;
         var c:String = null;
         var quote:String = null;
         if(!text || openIdx < 0 || openIdx >= text.length || text.charAt(openIdx) != "{")
         {
            return -1;
         }
         depth = 0;
         quote = null;
         i = openIdx;
         while(i < text.length)
         {
            c = text.charAt(i);
            if(Boolean(quote))
            {
               if(c == "\\")
               {
                  i += 2;
                  continue;
               }
               if(c == quote)
               {
                  quote = null;
               }
            }
            else if(c == "\"" || c == "\'")
            {
               quote = c;
            }
            else if(c == "{")
            {
               depth++;
            }
            else if(c == "}")
            {
               depth--;
               if(depth == 0)
               {
                  return i;
               }
            }
            i++;
         }
         return -1;
      }

      public static function tryParseCostumeObjectLiteral(objText:String) : Object
      {
         var cleaned:String = null;
         var result:* = undefined;
         if(!objText || objText.length < 2)
         {
            return null;
         }
         cleaned = objText;
         cleaned = cleaned.replace(/\/\*[\s\S]*?\*\//g,"");
         cleaned = cleaned.replace(/\/\/[^\r\n]*/g,"");
         cleaned = cleaned.replace(/([\{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:/g,"$1\"$2\":");
         cleaned = cleaned.replace(/,\s*([\}\]])/g,"$1");
         try
         {
            result = JSON.parse(cleaned);
            if(result is Object)
            {
               return result as Object;
            }
         }
         catch(err:Error)
         {
         }
         return null;
      }

      public static function loadRealExpansionCostumesSidecars() : void
      {
         var root:File = null;
         var listing:Array = null;
         var i:int = 0;
         var folder:File = null;
         var costumesFile:File = null;
         var folderName:String = null;
         try
         {
            root = File.applicationDirectory.resolvePath("expansions/character");
            if(!root || !root.exists || !root.isDirectory)
            {
               return;
            }
            listing = root.getDirectoryListing();
            listing.sort(ExpansionCharacterPacks.compareExpansionListingFiles);
            i = 0;
            while(i < listing.length)
            {
               folder = listing[i] as File;
               if(Boolean(folder) && Boolean(folder.isDirectory))
               {
                  folderName = folder.name.replace(/[^a-zA-Z0-9_]/g,"_");
                  costumesFile = folder.resolvePath("costumes.json");
                  if(!costumesFile.exists)
                  {
                     costumesFile = folder.resolvePath("costumes.as");
                  }
                  if(costumesFile.exists)
                  {
                     loadExpansionCostumesJson(folderName,costumesFile);
                  }
                  ExpansionLibraryResources.noteOldAssetsFile(folderName,folder.resolvePath("css_meta.json"));
                  ExpansionAudioResources.tryLoadExpansionAnnouncerFromFolder(folderName,folder);
               }
               i++;
            }
         }
         catch(err:*)
         {
         }
      }

      public static function resolveCostumeStatsName(charName:String) : String
      {
         var donor:String = null;
         if(charName == "xp")
         {
            return ExpansionLibraryResources.resolveXpStatsNameForLibrary() || charName;
         }
         donor = ExpansionLibraryResources.oldAssetId(charName);
         if(Boolean(donor))
         {
            ExpansionLibraryResources.logOldAsset("costumes:" + charName,"[ResourceManager] oldassets costumes " + charName + " -> " + donor);
            return donor;
         }
         return charName;
      }

      public static function getMergedCostumeList(charName:String) : Array
      {
         var baseList:Array = null;
         var merged:Array = null;
         var costumeData:Object = ResourceManager.getResourceByID("misc").getProp("metadata").costume_data;
         charName = resolveCostumeStatsName(charName);
         baseList = Boolean(costumeData) && costumeData[charName] is Array ? costumeData[charName] as Array : [];
         merged = ModHost.applyPatch(ModPatches.MERGE_COSTUME_LIST,[charName,baseList],function(n:String, b:Array):Array
         {
            var out:* = b || [];
            var customs:* = ModHost.door(ModPatches.PALETTE_GET_COSTUME,[n],null) as Array;
            var shared:* = ModHost.door(ModPatches.PALETTE_GET_SHARED_LINKED_FORM_BOTH_COSTUMES,[n],null) as Array;
            var priv:* = ModHost.door(ModPatches.PALETTE_GET_PRIVATE_LINKED_FORM_COSTUMES,[n],null) as Array;
            if(Boolean(customs))
            {
               out = out.concat(customs);
            }
            if(Boolean(shared))
            {
               out = out.concat(shared);
            }
            if(Boolean(priv))
            {
               out = out.concat(priv);
            }
            return out;
         }) as Array;
         if(!merged)
         {
            merged = baseList;
         }
         merged = merged.concat(buildSelectableTeamMetalSlots(charName,costumeData));
         ModHost.runHook(ModHooks.COSTUME_LIST_MERGE,{
            "charName":charName,
            "list":merged
         });
         return merged;
      }

      public static function buildSelectableTeamMetalSlots(charName:String, costumeData:Object) : Array
      {
         var list:Array = null;
         var costume:Object = null;
         var clone:Object = null;
         var teamLabel:String = null;
         var metal:Object = null;
         var out:Array = [];
         if(!charName)
         {
            return out;
         }
         list = Boolean(costumeData) && costumeData[charName] is Array ? costumeData[charName] as Array : null;
         if(Boolean(list))
         {
            for each(costume in list)
            {
               if(!(!costume || !costume.team))
               {
                  clone = Utils.cloneObject(costume);
                  teamLabel = String(clone.team);
                  delete clone.team;
                  clone.cssTeam = teamLabel;
                  if(!clone.profile)
                  {
                     clone.profile = "Team " + (Boolean(teamLabel) ? teamLabel.charAt(0).toUpperCase() + teamLabel.substring(1) : "Color");
                  }
                  out.push(clone);
               }
            }
         }
         metal = ResourceManager.getMetalCostume(charName);
         if(Boolean(metal) && Boolean(metalCostumeHasPalette(metal)))
         {
            clone = Utils.cloneObject(metal);
            clone.metal = true;
            if(clone.hasOwnProperty("team"))
            {
               delete clone.team;
            }
            if(!clone.profile)
            {
               clone.profile = "Metal";
            }
            out.push(clone);
         }
         return out;
      }

      public static function metalCostumeHasPalette(metal:Object) : Boolean
      {
         var ps:Object = null;
         var pa:Object = null;
         if(!metal)
         {
            return false;
         }
         ps = metal.paletteSwap;
         pa = metal.paletteSwapPA;
         if(Boolean(ps) && Boolean(ps.colors is Array) && ps.colors.length > 0)
         {
            return true;
         }
         if(Boolean(pa) && Boolean(pa.colors is Array) && pa.colors.length > 0)
         {
            return true;
         }
         if(metal.hue != 0 && metal.hue != null || metal.saturation != 0 && metal.saturation != null || metal.brightness != 0 && metal.brightness != null)
         {
            return true;
         }
         if(metal.redMultiplier != 1 && metal.redMultiplier != null || metal.greenMultiplier != 1 && metal.greenMultiplier != null || metal.blueMultiplier != 1 && metal.blueMultiplier != null)
         {
            return true;
         }
         return false;
      }

      public static function appendExpansionCostumes() : void
      {
         var id:String = null;
         var costumeList:Array = ResourceManager.getResourceByID("misc").getProp("metadata").costume_data;
         var metalCostumeList:Object = ResourceManager.getResourceByID("misc").getProp("metadata").metal_costume_data;
         for(id in ResourceManager.m_expansionCostumeData)
         {
            if(Boolean(ExpansionLibraryResources.oldAssetId(id)))
            {
               continue;
            }
            costumeList[id] = ResourceManager.m_expansionCostumeData[id];
         }
         for(id in ResourceManager.m_expansionMetalCostumeData)
         {
            if(Boolean(ExpansionLibraryResources.oldAssetId(id)))
            {
               continue;
            }
            metalCostumeList[id] = ResourceManager.m_expansionMetalCostumeData[id];
         }
         for(id in ExpansionLibraryResources.s_oldAssetId)
         {
            if(Boolean(costumeList[ExpansionLibraryResources.s_oldAssetId[id]]))
            {
               costumeList[id] = costumeList[ExpansionLibraryResources.s_oldAssetId[id]];
            }
            if(Boolean(metalCostumeList[ExpansionLibraryResources.s_oldAssetId[id]]))
            {
               metalCostumeList[id] = metalCostumeList[ExpansionLibraryResources.s_oldAssetId[id]];
            }
         }
         Stats.syncExpansionsFromResources();
      }

      public static function registerExpansionCostumeData(statsName:String, costumes:Array) : void
      {
         if(!statsName || !costumes)
         {
            return;
         }
         ResourceManager.m_expansionCostumeData[statsName] = costumes;
      }
   }
}
