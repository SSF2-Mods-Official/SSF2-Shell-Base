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

   public class ExpansionCssSidecars
   {
      public static function readExpansionCssCache(relFile:String) : Object
      {
         var folder:File = null;
         var metaFile:File = null;
         var stream:FileStream = null;
         var text:String = null;
         var parsed:Object = null;
         if(!relFile)
         {
            return null;
         }
         try
         {
            if(relFile.indexOf("expansions/") == 0)
            {
               folder = File.applicationDirectory.resolvePath("expansions/character/" + relFile.substring("expansions/".length)).parent;
            }
            else
            {
               folder = File.applicationDirectory.resolvePath("data/character/" + relFile).parent;
            }
            if(!folder || !folder.exists)
            {
               return null;
            }
            metaFile = folder.resolvePath("css_meta.json");
            if(!metaFile || !metaFile.exists)
            {
               return null;
            }
            stream = new FileStream();
            stream.open(metaFile,FileMode.READ);
            text = stream.readUTFBytes(stream.bytesAvailable);
            stream.close();
            parsed = JSON.parse(text) as Object;
            if(Boolean(parsed))
            {
               ExpansionLibraryResources.noteOldAssets(Boolean(parsed.id) ? String(parsed.id) : folder.name.replace(/[^a-zA-Z0-9_]/g,"_"),parsed);
            }
            if(Boolean(parsed) && (Boolean(parsed.displayName) || Boolean(parsed.seriesIcon) || Boolean(parsed.oldassets)))
            {
               return parsed;
            }
         }
         catch(err:*)
         {
         }
         return null;
      }

      public static function expansionPackFolder(res:Resource) : File
      {
         var file:String = null;
         if(!res)
         {
            return null;
         }
         file = String(res.FileName || "");
         if(file.indexOf("expansions/") != 0)
         {
            return null;
         }
         try
         {
            return File.applicationDirectory.resolvePath("expansions/character/" + file.substring("expansions/".length)).parent;
         }
         catch(err:*)
         {
         }
         return null;
      }

      public static function applyCssMetaToStats(id:String, folder:File) : Boolean
      {
         var cache:Object = null;
         if(!id || !folder)
         {
            return false;
         }
         cache = readExpansionCssCache("expansions/" + folder.name + "/x.ssf");
         if(!cache)
         {
            return false;
         }
         Stats.writeStats({"cData":{
            "statsName":id,
            "displayName":(Boolean(cache.displayName) ? cache.displayName : id),
            "seriesIcon":cache.seriesIcon || null
         }});
         return true;
      }

      public static function writableFile(file:File) : File
      {
         if(!file)
         {
            return null;
         }
         try
         {
            return new File(file.nativePath);
         }
         catch(err:*)
         {
         }
         return file;
      }

      public static function loadRosterSeriesIconSvg(statsName:String, file:File) : Boolean
      {
         var stream:FileStream = null;
         var text:String = null;
         var src:File = null;
         if(!statsName || !file)
         {
            return false;
         }
         try
         {
            src = writableFile(file);
            if(!src || !src.exists)
            {
               return false;
            }
            stream = new FileStream();
            stream.open(src,FileMode.READ);
            text = stream.readUTFBytes(stream.bytesAvailable);
            stream.close();
            if(Boolean(text) && Boolean(text.indexOf("<svg") >= 0) && Boolean(ExpansionPortraitResources.vectorIcon("hasVisibleContent",text)))
            {
               ResourceManager.m_rosterSeriesIconSvg[statsName] = text;
               try
               {
                  GameLog.write("[ResourceManager] Loaded series_icon.svg for " + statsName);
               }
               catch(logErr:*)
               {
               }
               return true;
            }
         }
         catch(err:*)
         {
            try
            {
               GameLog.write("[ResourceManager] series_icon.svg read failed for " + statsName + ": " + err);
            }
            catch(logErr:*)
            {
            }
         }
         return false;
      }

      public static function writeExpansionCssSidecars(res:Resource, stats:CharacterData, svg:String) : void
      {
         var folder:File = null;
         var dest:File = null;
         var metaFile:File = null;
         var svgFile:File = null;
         var stream:FileStream = null;
         var payload:Object = null;
         var existing:Object = null;
         folder = expansionPackFolder(res);
         if(!folder || !stats)
         {
            return;
         }
         dest = writableFile(folder);
         if(!dest)
         {
            return;
         }
         payload = {
            "displayName":(Boolean(stats.DisplayName) ? stats.DisplayName : res.ID),
            "seriesIcon":(Boolean(stats.SeriesIcon) ? stats.SeriesIcon : null)
         };
         try
         {
            metaFile = dest.resolvePath("css_meta.json");
            if(Boolean(metaFile.exists))
            {
               stream = new FileStream();
               stream.open(metaFile,FileMode.READ);
               existing = JSON.parse(stream.readUTFBytes(stream.bytesAvailable)) as Object;
               stream.close();
            }
         }
         catch(readMeta:*)
         {
            existing = null;
         }
         if(Boolean(existing) && Boolean(existing.id))
         {
            payload.id = existing.id;
         }
         if(Boolean(existing) && existing.oldassets == true && Boolean(existing.oldassetid))
         {
            payload.oldassets = true;
            payload.oldassetid = String(existing.oldassetid);
         }
         try
         {
            metaFile = dest.resolvePath("css_meta.json");
            stream = new FileStream();
            stream.open(metaFile,FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify(payload));
            stream.close();
            GameLog.write("[ResourceManager] Wrote " + metaFile.nativePath);
         }
         catch(metaErr:*)
         {
            GameLog.write("[ResourceManager] css_meta.json write failed for " + res.ID + ": " + metaErr);
         }
         if(!svg || !ExpansionPortraitResources.vectorIcon("hasVisibleContent",svg))
         {
            return;
         }
         try
         {
            svgFile = dest.resolvePath("series_icon.svg");
            stream = new FileStream();
            stream.open(svgFile,FileMode.WRITE);
            stream.writeUTFBytes(svg);
            stream.close();
            GameLog.write("[ResourceManager] Wrote " + svgFile.nativePath);
         }
         catch(svgErr:*)
         {
            GameLog.write("[ResourceManager] series_icon.svg write failed for " + res.ID + ": " + svgErr);
         }
      }

      public static function captureAndDisposeExpansionCss(res:Resource) : void
      {
         var stats:CharacterData = null;
         var iconName:String = null;
         var iconClass:Class = null;
         var icon:DisplayObject = null;
         var captured:Object = null;
         var domain:* = undefined;
         if(!res)
         {
            return;
         }
         try
         {
            if(res.Loaded)
            {
               ResourceManager.validateResource(res);
            }
         }
         catch(valErr:*)
         {
         }
         try
         {
            stats = Stats.getStats(res.ID,-1);
         }
         catch(statsErr:*)
         {
            stats = null;
            GameLog.write("[ResourceManager] expansion stats skip id=" + res.ID + " err=" + statsErr);
         }
         iconName = Boolean(stats) && Boolean(stats.SeriesIcon) ? stats.SeriesIcon : null;
         if(Boolean(iconName && iconName != "smash_symbol") && Boolean(iconName != res.ID) && !ResourceManager.m_rosterSeriesIconSvg[res.ID])
         {
            try
            {
               if(Boolean(res.MC) && Boolean(res.MC.loaderInfo) && Boolean(res.MC.loaderInfo.applicationDomain))
               {
                  domain = res.MC.loaderInfo.applicationDomain;
                  if(Boolean(domain.hasDefinition(iconName)))
                  {
                     iconClass = domain.getDefinition(iconName) as Class;
                  }
               }
               if(!iconClass)
               {
                  iconClass = ResourceManager.getLibraryClass(iconName);
               }
               if(Boolean(iconClass))
               {
                  icon = new iconClass() as DisplayObject;
               }
               if(Boolean(icon))
               {
                  captured = ExpansionPortraitResources.vectorIcon("captureIcon",icon);
                  if(Boolean(captured) && Boolean(captured.svg) && Boolean(ExpansionPortraitResources.vectorIcon("hasVisibleContent",captured.svg)))
                  {
                     ResourceManager.m_rosterSeriesIconSvg[res.ID] = captured.svg;
                     if(Boolean(captured.blit))
                     {
                        ResourceManager.m_rosterSeriesIconBlit[res.ID] = captured.blit;
                     }
                  }
               }
            }
            catch(snapErr:*)
            {
               GameLog.write("[ResourceManager] series SVG capture failed for " + res.ID + ": " + snapErr);
            }
         }
         writeExpansionCssSidecars(res,stats,String(ResourceManager.m_rosterSeriesIconSvg[res.ID] || ""));
         if(res.Loaded)
         {
            ResourceManager.unloadResource(res);
            GameLog.write("[ResourceManager] Disposed expansion fighter after CSS capture: " + res.ID);
         }
      }

      public static function hydrateAndExtractExpansionCss(onDone:Function) : void
      {
         var needSwf:Array = null;
         var pendingDecodes:int = 0;
         var swfPhaseDone:Boolean = false;
         var finished:Boolean = false;
         needSwf = null;
         pendingDecodes = 0;
         swfPhaseDone = false;
         finished = false;
         needSwf = null;
         pendingDecodes = 0;
         swfPhaseDone = false;
         finished = false;
         needSwf = null;
         pendingDecodes = 0;
         swfPhaseDone = false;
         finished = false;
         var i:int = 0;
         var res:Resource = null;
         var file:String = null;
         var folder:File = null;
         var svgFile:File = null;
         needSwf = null;
         var afterSwf:Function = null;
         pendingDecodes = 0;
         swfPhaseDone = false;
         finished = false;
         var maybeFinish:Function = null;
         var queueSvgDecode:Function = null;
         needSwf = [];
         pendingDecodes = 0;
         swfPhaseDone = false;
         finished = false;
         maybeFinish = function():void
         {
            if(finished)
            {
               return;
            }
            if(!swfPhaseDone)
            {
               return;
            }
            finished = true;
            if(onDone != null)
            {
               onDone();
            }
         };
         queueSvgDecode = function(id:String):void
         {
            var text:String = null;
            text = String(ResourceManager.m_rosterSeriesIconSvg[id] || "");
            if(!ExpansionPortraitResources.vectorIcon("hasEmbeddedImage",text))
            {
               return;
            }
            ++pendingDecodes;
            ExpansionPortraitResources.vectorIcon("decodeFirstImage",text,function(blit:Object):void
            {
               if(Boolean(blit))
               {
                  ResourceManager.m_rosterSeriesIconBlit[id] = blit;
               }
               --pendingDecodes;
               maybeFinish();
            });
         };
         i = 0;
         while(i < ResourceManager.pool.length)
         {
            res = ResourceManager.pool[i];
            if(Boolean(res) && res.Type == Resource.CHARACTER)
            {
               try
               {
                  file = String(res.FileName || "");
                  if(file.indexOf("expansions/") == 0)
                  {
                     folder = expansionPackFolder(res);
                     svgFile = Boolean(folder) ? folder.resolvePath("series_icon.svg") : null;
                     if(Boolean(folder && applyCssMetaToStats(res.ID,folder) && svgFile) && Boolean(svgFile.exists) && Boolean(loadRosterSeriesIconSvg(res.ID,svgFile)))
                     {
                        queueSvgDecode(res.ID);
                     }
                     else if(res.Loaded)
                     {
                        captureAndDisposeExpansionCss(res);
                     }
                     else
                     {
                        needSwf.push(res.ID);
                     }
                  }
               }
               catch(cssErr:*)
               {
                  try
                  {
                     GameLog.write("[ResourceManager] expansion css skip " + res.ID + ": " + cssErr);
                  }
                  catch(logErr:*)
                  {
                  }
               }
            }
            i++;
         }
         afterSwf = function():void
         {
            var j:int = 0;
            var loaded:Resource = null;
            j = 0;
            while(j < needSwf.length)
            {
               loaded = ResourceManager.getResourceByID(String(needSwf[j]),false);
               if(Boolean(loaded))
               {
                  captureAndDisposeExpansionCss(loaded);
               }
               j++;
            }
            swfPhaseDone = true;
            maybeFinish();
         };
         if(needSwf.length == 0)
         {
            swfPhaseDone = true;
            maybeFinish();
            return;
         }
         ModHost.ensureResourcesLoaded(needSwf,afterSwf,afterSwf);
      }

      public static function loadRealExpansionUiTemplates(onDone:Function = null) : void
      {
         var finish:Function = null;
         var afterUi:Function = null;
         if(ResourceManager.m_realExpansionUiLoadCallbacks != null)
         {
            if(onDone != null)
            {
               ResourceManager.m_realExpansionUiLoadCallbacks.push(onDone);
            }
            return;
         }
         ResourceManager.m_realExpansionUiLoadCallbacks = [];
         if(onDone != null)
         {
            ResourceManager.m_realExpansionUiLoadCallbacks.push(onDone);
         }
         finish = function():void
         {
            var cbs:Array = null;
            var ci:int = 0;
            try
            {
               ExpansionCostumeResources.appendExpansionCostumes();
            }
            catch(appendErr:*)
            {
            }
            try
            {
               ExpansionCharacterPacks.applyClassicJsonPacks();
            }
            catch(classicErr:*)
            {
            }
            cbs = ResourceManager.m_realExpansionUiLoadCallbacks;
            ResourceManager.m_realExpansionUiLoadCallbacks = null;
            if(Boolean(cbs))
            {
               ci = 0;
               while(ci < cbs.length)
               {
                  try
                  {
                     if(cbs[ci] != null)
                     {
                        cbs[ci]();
                     }
                  }
                  catch(cbErr:*)
                  {
                  }
                  ci++;
               }
            }
         };
         afterUi = function():void
         {
            ExpansionCostumeResources.loadRealExpansionCostumesSidecars();
            hydrateAndExtractExpansionCss(finish);
         };
         RealExpansionsMod.loadRealExpansionUi(afterUi);

      }
   }
}
