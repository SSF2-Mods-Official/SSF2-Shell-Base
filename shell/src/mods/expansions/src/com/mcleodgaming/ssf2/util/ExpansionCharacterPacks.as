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

   public class ExpansionCharacterPacks
   {
      public static function discoverDroppedExpansions() : void
      {
         var folder:File = null;
         try
         {
            ExpansionStageResources.discoverStageExpansions();
         }
         catch(stageErr:*)
         {
            ExpansionResourceLog.rmLog("[ResourceManager] Stage expansion discovery threw: " + stageErr);
         }
         try
         {
            folder = File.applicationDirectory.resolvePath("expansions/character");
            if(!folder.exists)
            {
               try
               {
                  folder.createDirectory();
                  ExpansionResourceLog.rmLog("[ResourceManager] Created expansions folder: " + folder.nativePath);
               }
               catch(createErr:Error)
               {
                  ExpansionResourceLog.rmLog("[ResourceManager] Could not create expansions folder: " + createErr.message);
               }
               if(!folder.exists)
               {
                  return;
               }
            }
            if(!folder.isDirectory)
            {
               return;
            }
            discoverExpansionEntries(folder,"expansions");
         }
         catch(err:Error)
         {
            ExpansionResourceLog.rmLog("[ResourceManager] Expansion discovery failed: " + err.message);
         }
      }

      public static function discoverExpansionEntries(folder:File, relativeDir:String) : void
      {
         var listing:Array = null;
         var file:File = null;
         var name:String = null;
         var i:int = 0;
         var stockFile:File = null;
         var paFile:File = null;
         var costumesFile:File = null;
         var settingsFile:File = null;
         var announcerFile:File = null;
         var subRel:String = null;
         var isRealExpansionFolder:Boolean = false;
         if(!folder || !folder.exists || !folder.isDirectory)
         {
            return;
         }
         listing = folder.getDirectoryListing();
         listing.sort(compareExpansionListingFiles);
         stockFile = folder.resolvePath("stock.png");
         paFile = folder.resolvePath("PA.png");
         if(!paFile.exists)
         {
            paFile = folder.resolvePath("pa.png");
         }
         costumesFile = folder.resolvePath("costumes.json");
         if(!costumesFile.exists)
         {
            costumesFile = folder.resolvePath("costumes.as");
         }
         settingsFile = folder.resolvePath("settings.json");
         announcerFile = folder.resolvePath("announcer.mp3");
         isRealExpansionFolder = relativeDir != "expansions" && Boolean(folder.resolvePath("assets.swf").exists);
         i = 0;
         while(i < listing.length)
         {
            file = listing[i] as File;
            if(Boolean(file))
            {
               name = file.name;
               if(file.isDirectory)
               {
                  if(name.charAt(0) == "_" || !ModHost.folderInfoEnabled(file.nativePath))
                  {
                  }
                  else if(relativeDir == "expansions")
                  {
                     subRel = relativeDir + "/" + name;
                     discoverExpansionEntries(file,subRel);
                  }
               }
               else if(!isRealExpansionFolder && Boolean(isExpansionPackFileName(name)))
               {
                  registerDiscoveredExpansion(relativeDir,name,stockFile.exists ? stockFile : null,paFile.exists ? paFile : null,costumesFile.exists ? costumesFile : null,settingsFile.exists ? settingsFile : null,announcerFile.exists ? announcerFile : null);
               }
            }
            i++;
         }
      }

      public static function isExpansionPackFileName(name:String) : Boolean
      {
         var lower:String = null;
         if(!name || name.length < 5)
         {
            return false;
         }
         lower = name.toLowerCase();
         if(lower == "assets.swf" || lower == "character_template.swf")
         {
            return false;
         }
         return lower.lastIndexOf(".ssf") == name.length - 4 || lower.lastIndexOf(".swf") == name.length - 4;
      }

      public static function registerDiscoveredExpansion(relativeDir:String, fileName:String, stockPng:File, paPng:File, costumesJson:File = null, settingsJson:File = null, announcerMp3:File = null) : void
      {
         var dot:int = 0;
         var base:String = null;
         var id:String = null;
         var relFile:String = null;
         var tmpResource:Resource = null;
         var folderKey:String = null;
         dot = fileName.lastIndexOf(".");
         base = dot > 0 ? fileName.substring(0,dot) : fileName;
         folderKey = relativeDir.replace(/\\/g,"/");
         if(folderKey != "expansions")
         {
            id = "xp_" + folderKey.substring("expansions/".length);
            id = id.replace(/[^a-zA-Z0-9_]/g,"_");
            if(Boolean(ResourceManager.poolHash[id]))
            {
               id = id + "_" + base.replace(/[^a-zA-Z0-9_]/g,"_");
            }
         }
         else
         {
            id = "xp_" + base;
         }
         if(Boolean(ResourceManager.poolHash[id]))
         {
            GameLog.write("[ResourceManager] Skipping expansion (id already in pool): " + id);
            return;
         }
         relFile = folderKey + "/" + fileName;
         tmpResource = new Resource(id,relFile,fileName,"",Resource.CHARACTER_EXPANSION);
         tmpResource.SoftFail = true;
         ResourceManager.addResource(tmpResource);
         if(Boolean(stockPng))
         {
            ResourceManager.m_pendingExpansionStockFile[id] = stockPng;
         }
         if(Boolean(paPng))
         {
            ResourceManager.m_pendingExpansionPAFile[id] = paPng;
         }
         if(Boolean(costumesJson))
         {
            ResourceManager.m_pendingExpansionCostumesFile[id] = costumesJson;
         }
         if(Boolean(settingsJson))
         {
            ResourceManager.m_pendingExpansionSettingsFile[id] = settingsJson;
         }
         if(Boolean(announcerMp3))
         {
            ResourceManager.m_pendingExpansionAnnouncerFile[id] = announcerMp3;
         }
         GameLog.write("[ResourceManager] Discovered expansion: " + id + " (" + relFile + ")");
      }

      public static function compareExpansionListingFiles(a:*, b:*) : int
      {
         var na:String = null;
         var nb:String = null;
         na = a is File ? String((a as File).name).toLowerCase() : "";
         nb = b is File ? String((b as File).name).toLowerCase() : "";
         if(na < nb)
         {
            return -1;
         }
         if(na > nb)
         {
            return 1;
         }
         return 0;
      }

      public static function sortExpansionDataSlots() : void
      {
         var arr:Array = null;
         var i:int = 0;
         var sorted:Vector.<Vector.<Object>> = null;
         if(!ResourceManager.m_expansionData || ResourceManager.m_expansionData.length < 2)
         {
            return;
         }
         arr = [];
         i = 0;
         while(i < ResourceManager.m_expansionData.length)
         {
            arr.push(ResourceManager.m_expansionData[i]);
            i++;
         }
         arr.sort(compareExpansionDataSlots);
         sorted = new Vector.<Vector.<Object>>();
         i = 0;
         while(i < arr.length)
         {
            sorted.push(arr[i] as Vector.<Object>);
            i++;
         }
         ResourceManager.m_expansionData = sorted;
      }

      public static function getExpansionSlotSortKey(slot:Vector.<Object>) : String
      {
         var obj:Object = null;
         var statsName:String = null;
         var resourceId:String = null;
         if(!slot || slot.length <= 0)
         {
            return "";
         }
         obj = slot[0];
         if(Boolean(obj) && Boolean(obj.cData) && Boolean(obj.cData.statsName))
         {
            statsName = String(obj.cData.statsName);
            resourceId = ResourceManager.m_expansionStatsToResourceId[statsName] != null ? String(ResourceManager.m_expansionStatsToResourceId[statsName]) : statsName;
            return resourceId.toLowerCase();
         }
         return "";
      }

      public static function compareExpansionDataSlots(a:*, b:*) : int
      {
         var ka:String = getExpansionSlotSortKey(a as Vector.<Object>);
         var kb:String = getExpansionSlotSortKey(b as Vector.<Object>);
         if(ka < kb)
         {
            return -1;
         }
         if(ka > kb)
         {
            return 1;
         }
         return 0;
      }

      public static function isExpansionStatsName(statsName:String) : Boolean
      {
         return Boolean(statsName) && ResourceManager.m_expansionStatsToResourceId[statsName] != null;
      }

      public static function getResourceIdForCharacter(statsName:String) : String
      {
         if(Boolean(statsName) && Boolean(ResourceManager.poolHash[statsName]))
         {
            return statsName;
         }
         if(Boolean(statsName) && Boolean(ResourceManager.m_expansionStatsToResourceId[statsName]))
         {
            return String(ResourceManager.m_expansionStatsToResourceId[statsName]);
         }
         return statsName;
      }

      public static function sanitizeExpansionUiLinkages(cData:Object) : void
      {
         var statsName:String = null;
         var linkage:String = null;
         if(!cData)
         {
            return;
         }
         statsName = cData.statsName != null ? String(cData.statsName) : null;
         linkage = cData.linkage_id != null ? String(cData.linkage_id) : null;
         if(Boolean(!cData.seriesIcon) || Boolean(statsName && cData.seriesIcon == statsName) || Boolean(linkage) && Boolean(cData.seriesIcon == linkage))
         {
            cData.seriesIcon = "smash_symbol";
         }
         if(Boolean(!cData.thumbnail) || Boolean(statsName && cData.thumbnail == statsName) || Boolean(linkage) && Boolean(cData.thumbnail == linkage))
         {
            cData.thumbnail = Boolean(statsName) ? statsName + "_stock" : "smash_symbol";
         }
      }

      public static function bindExpansionStatsToResource(resource:Resource, expansionChars:Array) : void
      {
         var j:int = 0;
         var statsName:String = null;
         var stockFile:File = null;
         var paFile:File = null;
         var costumesFile:File = null;
         var settingsFile:File = null;
         var announcerFile:File = null;
         if(!resource || !expansionChars)
         {
            return;
         }
         stockFile = Boolean(ResourceManager.m_pendingExpansionStockFile[resource.ID]) ? ResourceManager.m_pendingExpansionStockFile[resource.ID] as File : null;
         paFile = Boolean(ResourceManager.m_pendingExpansionPAFile[resource.ID]) ? ResourceManager.m_pendingExpansionPAFile[resource.ID] as File : null;
         costumesFile = Boolean(ResourceManager.m_pendingExpansionCostumesFile[resource.ID]) ? ResourceManager.m_pendingExpansionCostumesFile[resource.ID] as File : null;
         settingsFile = Boolean(ResourceManager.m_pendingExpansionSettingsFile[resource.ID]) ? ResourceManager.m_pendingExpansionSettingsFile[resource.ID] as File : null;
         announcerFile = Boolean(ResourceManager.m_pendingExpansionAnnouncerFile[resource.ID]) ? ResourceManager.m_pendingExpansionAnnouncerFile[resource.ID] as File : null;
         j = 0;
         while(j < expansionChars.length)
         {
            statsName = Boolean(expansionChars[j]) && Boolean(expansionChars[j]["cData"]) ? expansionChars[j]["cData"]["statsName"] : null;
            if(Boolean(statsName))
            {
               sanitizeExpansionUiLinkages(expansionChars[j]["cData"]);
               ResourceManager.m_expansionStatsToResourceId[statsName] = resource.ID;
               if(Boolean(stockFile))
               {
                  loadExpansionPng(statsName,stockFile,false);
               }
               if(Boolean(paFile))
               {
                  loadExpansionPng(statsName,paFile,true);
               }
               if(Boolean(costumesFile))
               {
                  ExpansionCostumeResources.loadExpansionCostumesJson(statsName,costumesFile);
               }
               if(Boolean(settingsFile))
               {
                  loadExpansionSettingsJson(statsName,settingsFile);
               }
               if(Boolean(announcerFile))
               {
                  ExpansionAudioResources.loadExpansionAnnouncer(statsName,announcerFile);
               }
            }
            j++;
         }
      }

      public static function loadExpansionSettingsJson(statsName:String, file:File) : void
      {
         var stream:FileStream = null;
         var text:String = null;
         var raw:* = undefined;
         var nudge:* = undefined;
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
            GameLog.write("[ResourceManager] settings.json read failed for " + statsName + ": " + readErr.message);
            return;
         }
         try
         {
            raw = JSON.parse(text);
         }
         catch(parseErr:Error)
         {
            GameLog.write("[ResourceManager] settings.json parse failed for " + statsName + ": " + parseErr.message);
            return;
         }
         if(!raw || !(raw is Object))
         {
            return;
         }
         nudge = raw["CSS_PA_Y_NUDGE"];
         if(nudge != null && nudge != undefined && !isNaN(Number(nudge)))
         {
            ResourceManager.m_expansionCssPaYNudge[statsName] = Number(nudge);
            GameLog.write("[ResourceManager] settings.json CSS_PA_Y_NUDGE=" + Number(nudge) + " for " + statsName);
         }
         nudge = raw["CLASSIC_PA_Y_NUDGE"];
         if(nudge != null && nudge != undefined && !isNaN(Number(nudge)))
         {
            ResourceManager.m_expansionClassicPaYNudge[statsName] = Number(nudge);
            GameLog.write("[ResourceManager] settings.json CLASSIC_PA_Y_NUDGE=" + Number(nudge) + " for " + statsName);
         }
      }

      public static function loadExpansionPng(statsName:String, file:File, isPA:Boolean) : void
      {
         var label:String = null;
         label = null;
         label = null;
         label = null;
         var stream:FileStream = null;
         var bytes:ByteArray = null;
         var loader:Loader = null;
         var ctx:LoaderContext = null;
         label = null;
         label = isPA ? "PA.png" : "stock.png";
         if(!statsName || !file || !file.exists)
         {
            return;
         }
         try
         {
            stream = new FileStream();
            stream.open(file,FileMode.READ);
            bytes = new ByteArray();
            stream.readBytes(bytes);
            stream.close();
            loader = new Loader();
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void
            {
               var content:* = undefined;
               var bd:BitmapData = null;
               try
               {
                  content = e.target.content;
                  if(content is Bitmap)
                  {
                     bd = (content as Bitmap).bitmapData;
                  }
                  else if(Boolean(content) && content is DisplayObject)
                  {
                     bd = new BitmapData(Math.max(1,content.width),Math.max(1,content.height),true,0);
                     bd.draw(content as DisplayObject);
                  }
                  if(Boolean(bd))
                  {
                     if(isPA)
                     {
                        ResourceManager.m_expansionPABitmapData[statsName] = bd;
                     }
                     else
                     {
                        ResourceManager.m_expansionStockBitmapData[statsName] = bd;
                     }
                     GameLog.write("[ResourceManager] Loaded expansion " + label + " for " + statsName);
                  }
               }
               catch(decodeErr:Error)
               {
                  GameLog.write("[ResourceManager] " + label + " decode failed for " + statsName + ": " + decodeErr.message);
               }
            });
            loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void
            {
               GameLog.write("[ResourceManager] " + label + " load error for " + statsName);
            });
            ctx = new LoaderContext();
            ctx.checkPolicyFile = false;
            loader.loadBytes(bytes,ctx);
         }
         catch(err:Error)
         {
            GameLog.write("[ResourceManager] " + label + " read failed for " + statsName + ": " + err.message);
         }
      }

      public static function loadPendingExpansions(onDone:Function = null) : void
      {
         var i:int = 0;
         var res:Resource = null;
         var ids:Array = null;
         ids = [];
         for(i = 0; i < ResourceManager.pool.length; i++)
         {
            res = ResourceManager.pool[i];
            if(!(!res || res.Type != Resource.CHARACTER_EXPANSION))
            {
               if(!res.Loaded && !ResourceManager.queueHash[res.ID])
               {
                  ids.push(res.ID);
               }
            }
         }
         if(ids.length == 0)
         {
            try
            {
               Stats.syncExpansionsFromResources();
            }
            catch(syncErr:*)
            {
               ExpansionResourceLog.step("loadPendingExpansions syncExpansionsFromResources",syncErr);
            }
            if(onDone != null)
            {
               onDone();
            }
            return;
         }
         ResourceManager.queueResources(ids);
         ResourceManager.load({
            "oncomplete":function():void
            {
               try
               {
                  Stats.syncExpansionsFromResources();
               }
               catch(syncErr2:*)
               {
                  ExpansionResourceLog.step("loadPendingExpansions syncExpansionsFromResources",syncErr2);
               }
               if(onDone != null)
               {
                  onDone();
               }
            },
            "onerror":function():void
            {
               try
               {
                  Stats.syncExpansionsFromResources();
               }
               catch(syncErr3:*)
               {
                  ExpansionResourceLog.step("loadPendingExpansions syncExpansionsFromResources",syncErr3);
               }
               if(onDone != null)
               {
                  onDone();
               }
            }
         });
      }

      public static function applyClassicJsonPacks() : void
      {
         var folder:File = null;
         folder = null;
         folder = null;
         folder = null;
         var classicRes:Resource = null;
         var domain:ApplicationDomain = null;
         var ClassicModeDataClass:Class = null;
         var ClassicModeClass:Class = null;
         var seriesList:Object = null;
         var teammateList:Object = null;
         var seriesCharList:Object = null;
         var stagesList:Object = null;
         var root:File = null;
         var listing:Array = null;
         var i:int = 0;
         folder = null;
         var classicFile:File = null;
         var stream:FileStream = null;
         var text:String = null;
         var raw:Object = null;
         var statsName:String = null;
         var series:String = null;
         var teammates:String = null;
         var stages:String = null;
         var existingSeriesChars:String = null;
         var mappings:Object = null;
         var chars:Array = null;
         var cid:String = null;
         if(ResourceManager.m_classicDataMerged)
         {
            return;
         }
         classicRes = ResourceManager.getResourceByID("classic_mode");
         if(!classicRes || !classicRes.Loaded || !classicRes.MC || !classicRes.MC.loaderInfo)
         {
            return;
         }
         domain = classicRes.MC.loaderInfo.applicationDomain;
         if(!domain || !domain.hasDefinition("ClassicModeData"))
         {
            return;
         }
         ClassicModeDataClass = domain.getDefinition("ClassicModeData") as Class;
         seriesList = ClassicModeDataClass.seriesList;
         teammateList = ClassicModeDataClass.teammateList;
         seriesCharList = ClassicModeDataClass.seriesCharList;
         stagesList = ClassicModeDataClass.stagesList;
         if(!seriesList || !teammateList || !stagesList)
         {
            return;
         }
         try
         {
            root = File.applicationDirectory.resolvePath("expansions/character");
            if(Boolean(root) && Boolean(root.exists) && Boolean(root.isDirectory))
            {
               listing = root.getDirectoryListing();
               listing.sort(compareExpansionListingFiles);
               i = 0;
               while(i < listing.length)
               {
                  mergeClassicJsonFolder(listing[i] as File,seriesList,teammateList,seriesCharList,stagesList);
                  i++;
               }
            }
         }
         catch(scanErr:Error)
         {
            ExpansionResourceLog.step("applyClassicJsonPacks scan",scanErr);
         }
         try
         {
            fillRandomCharacterClassic(seriesList,teammateList);
         }
         catch(fillErr:*)
         {
            ExpansionResourceLog.step("applyClassicJsonPacks fill",fillErr);
         }
         ResourceManager.m_classicDataMerged = true;
      }

      /** classic.json in one expansions/character folder: series, teammates and stages for that character. */
      private static function mergeClassicJsonFolder(folder:File, seriesList:Object, teammateList:Object, seriesCharList:Object, stagesList:Object) : void
      {
         var classicFile:File = null;
         var stream:FileStream = null;
         var text:String = null;
         var raw:Object = null;
         var statsName:String = null;
         var series:String = null;
         var teammates:String = null;
         var stages:String = null;
         var existingSeriesChars:String = null;
         if(Boolean(folder) && Boolean(folder.isDirectory))
         {
            classicFile = folder.resolvePath("classic.json");
            if(classicFile.exists)
            {
               try
               {
                  stream = new FileStream();
                  stream.open(classicFile,FileMode.READ);
                  text = stream.readUTFBytes(stream.bytesAvailable);
                  stream.close();
                  raw = JSON.parse(text) as Object;
               }
               catch(parseErr:Error)
               {
                  raw = null;
               }
               if(Boolean(raw))
               {
                  statsName = folder.name.replace(/[^a-zA-Z0-9_]/g,"_");
                  series = raw["series"] != null ? String(raw["series"]) : "misc";
                  teammates = raw["teammates"] != null ? String(raw["teammates"]) : "mario,kirby,link,pikachu";
                  stages = raw["stages"] != null ? String(raw["stages"]) : null;
                  seriesList[statsName] = series;
                  teammateList[statsName] = teammates;
                  if(Boolean(stages) && Boolean(stages.length > 0) && !stagesList[series])
                  {
                     stagesList[series] = stages;
                  }
                  if(Boolean(raw["addToSeriesCharacters"]) && Boolean(seriesCharList))
                  {
                     existingSeriesChars = seriesCharList[series] != null ? String(seriesCharList[series]) : "";
                     if(existingSeriesChars.indexOf(statsName) < 0)
                     {
                        seriesCharList[series] = existingSeriesChars.length > 0 ? existingSeriesChars + "," + statsName : statsName;
                     }
                  }
               }
            }
         }
      }

      /** Random-select characters without classic data get the misc series and default teammates. */
      private static function fillRandomCharacterClassic(seriesList:Object, teammateList:Object) : void
      {
         var mappings:Object = null;
         var chars:Array = null;
         var cid:String = null;
         var i:int = 0;
         mappings = ResourceManager.getResourceByID("mappings").getProp("metadata");
         if(Boolean(mappings) && Boolean(mappings.random_characters) && Boolean(mappings.random_characters.characters))
         {
            chars = mappings.random_characters.characters as Array;
            i = 0;
            while(i < chars.length)
            {
               cid = String(chars[i]);
               if(Boolean(cid) && seriesList[cid] == null)
               {
                  seriesList[cid] = "misc";
                  if(teammateList[cid] == null)
                  {
                     teammateList[cid] = "mario,kirby,link,pikachu";
                  }
               }
               i++;
            }
         }
      }

      public static function queuePlayerCharacterResource(setting:Object, randIndex:int = -1) : void
      {
         var statsName:String = null;
         var resId:String = null;
         if(!setting || setting.exist === false || setting.character == null)
         {
            return;
         }
         if(setting.character == "xp")
         {
            if(Boolean(isNaN(setting.expansion)) || setting.expansion < 0)
            {
               setting.expansion = 0;
            }
            setActiveXpExpansion(setting.expansion);
            statsName = Stats.resolveExpansionStatsName(setting.expansion);
            if(!statsName)
            {
               GameLog.write("[ResourceManager] Could not resolve expansion stats for slot " + setting.expansion);
               return;
            }
            resId = getResourceIdForCharacter(statsName);
            if(Boolean(resId))
            {
               ResourceManager.queueResources([resId]);
            }
            return;
         }
         if(setting.character == "random")
         {
            if(Boolean(randIndex >= 0 && Main.RandCharList) && Boolean(randIndex < Main.RandCharList.length) && Boolean(Main.RandCharList[randIndex]))
            {
               ResourceManager.queueResources([Main.RandCharList[randIndex].StatsName]);
            }
            return;
         }
         ResourceManager.queueResources([setting.character]);
      }

      public static function registerLoadedResource(res:Resource) : void
      {
         if(!res || !res.Loaded || !res.ID)
         {
            return;
         }
         if(!ResourceManager.resourcesHash[res.ID])
         {
            ResourceManager.resourcesHash[res.ID] = res;
            ResourceManager.resources.push(res);
            ResourceManager.cacheLibrary(res);
            ModHost.runHook(ModHooks.RESOURCE_LOADED,{
               "id":res.ID,
               "resource":res
            });
         }
      }

      public static function checkMissingEmptyFrameOnes() : void
      {
         var i:int = 0;
         while(Boolean(MenuController.debugConsole) && Boolean(!Main.preloader) && i < ResourceManager.resources.length)
         {
            if(ResourceManager.resources[i].numChildren > 0)
            {
               MenuController.debugConsole.alert("Warning! Loaded resource " + ResourceManager.resources[i].ID + " contains contents on the timeline on frame 1. Must always insert a blank frame first at the root of an SSF2 resource SWF to prevent MovieClip content from potentially playing in the background and causing desyncs!");
            }
            i++;
         }
      }

      public static function setActiveXpExpansion(expansionID:Number) : void
      {
         if(!isNaN(expansionID) && expansionID >= 0)
         {
            ResourceManager.m_activeXpExpansion = int(expansionID);
         }
      }

      public static function get ActiveXpExpansion() : int
      {
         return ResourceManager.m_activeXpExpansion;
      }

      public static function expansionHasTargetTest(statsName:String) : Boolean
      {
         var stageId:String = null;
         var res:Resource = null;
         var mappings_original:Object = null;
         if(!statsName)
         {
            return false;
         }
         stageId = "targettest_" + statsName;
         res = ResourceManager.getResourceByID(stageId);
         if(!res)
         {
            return false;
         }
         try
         {
            mappings_original = ResourceManager.getResourceByID("mappings").getProp("metadata_original");
         }
         catch(e:Error)
         {
            mappings_original = null;
         }
         if(!mappings_original || !mappings_original.stage || !mappings_original.stage[stageId])
         {
            return false;
         }
         if(Boolean(res.EncryptedFileName))
         {
            return true;
         }
         if(Boolean(res.FileName))
         {
            return true;
         }
         return false;
      }

      public static function anyExpansionHasTargetTest() : Boolean
      {
         var i:int = 0;
         var statsName:String = null;
         i = 0;
         while(i < ResourceManager.m_expansionData.length)
         {
            statsName = Stats.resolveExpansionStatsName(i);
            if(Boolean(statsName) && expansionHasTargetTest(statsName))
            {
               return true;
            }
            i++;
         }
         return false;
      }

      public static function getNextExpansionWithTargetTest(idNumber:Number) : Number
      {
         var start:int = 0;
         var next:Number = NaN;
         var guard:int = 0;
         if(ResourceManager.m_expansionData.length <= 0)
         {
            return 0;
         }
         start = int(idNumber);
         next = idNumber;
         guard = 0;
         while(guard < ResourceManager.m_expansionData.length)
         {
            next = ResourceManager.getNextExpansionCharacter(next);
            if(expansionHasTargetTest(Stats.resolveExpansionStatsName(next)))
            {
               return next;
            }
            guard++;
         }
         return start;
      }

      public static function getPrevExpansionWithTargetTest(idNumber:Number) : Number
      {
         var start:int = 0;
         var prev:Number = NaN;
         var guard:int = 0;
         if(ResourceManager.m_expansionData.length <= 0)
         {
            return 0;
         }
         start = int(idNumber);
         prev = idNumber;
         guard = 0;
         while(guard < ResourceManager.m_expansionData.length)
         {
            prev = ResourceManager.getPrevExpansionCharacter(prev);
            if(expansionHasTargetTest(Stats.resolveExpansionStatsName(prev)))
            {
               return prev;
            }
            guard++;
         }
         return start;
      }

      public static function getFirstExpansionWithTargetTest() : Number
      {
         var i:int = 0;
         i = 0;
         while(i < ResourceManager.m_expansionData.length)
         {
            if(expansionHasTargetTest(Stats.resolveExpansionStatsName(i)))
            {
               return i;
            }
            i++;
         }
         return 0;
      }
   }
}
