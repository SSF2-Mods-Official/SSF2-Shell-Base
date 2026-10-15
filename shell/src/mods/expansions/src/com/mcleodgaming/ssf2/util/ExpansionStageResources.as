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

   public class ExpansionStageResources
   {
      private static var m_stageById:Object = {};

      public static function getStageExpansions() : Array
      {
         return ResourceManager.m_stageExpansions;
      }

      public static function isExpansionStageId(id:String) : Boolean
      {
         return Boolean(id && m_stageById && m_stageById[id]);
      }

      public static function discoverStageExpansions() : void
      {
         var root:File = null;
         var listing:Array = null;
         var folder:File = null;
         var swf:File = null;
         var preview:File = null;
         var info:Object = null;
         var id:String = null;
         var name:String = null;
         var rel:String = null;
         var tmp:Resource = null;
         var existing:Resource = null;
         var entry:Object = null;
         var i:int = 0;
         var stageType:int = 6;
         var ResCls:* = undefined;
         ResourceManager.m_stageExpansions = [];
         m_stageById = {};
         try
         {
            root = File.applicationDirectory.resolvePath("expansions/stages");
            if(!root.exists || !root.isDirectory)
            {
               return;
            }
            listing = root.getDirectoryListing();
            i = 0;
            while(i < listing.length)
            {
               folder = listing[i] as File;
               i++;
               if(!folder || !folder.isDirectory)
               {
                  continue;
               }
               if(folder.name.charAt(0) == "_" || folder.name.charAt(0) == ".")
               {
                  continue;
               }
               try
               {
                  info = readStageExpansionInfo(folder.resolvePath("info.json"),folder.name);
                  id = info.id && isValidStageFolderId(String(info.id)) ? String(info.id) : folder.name;
                  if(!isValidStageFolderId(id))
                  {
                     ExpansionResourceLog.rmLog("[ResourceManager] Skipped stage folder (id must be [A-Za-z][A-Za-z0-9_]*): " + folder.name);
                     continue;
                  }
                  if(id == "xpstage" || id == "random" || id == "sxp")
                  {
                     ExpansionResourceLog.rmLog("[ResourceManager] Skipped reserved stage folder: " + id);
                     continue;
                  }
                  if(!info.enabled)
                  {
                     ExpansionResourceLog.rmLog("[ResourceManager] Stage expansion disabled: " + id);
                     continue;
                  }
                  swf = pickStageExpansionSwf(folder,id);
                  if(!swf)
                  {
                     ExpansionResourceLog.rmLog("[ResourceManager] Stage folder has no SWF: " + id);
                     continue;
                  }
                  rel = "expansions/stages/" + folder.name + "/" + swf.name;
                  existing = ResourceManager.getResourceByID(id) as Resource;
                  if(existing && String(existing.FileName || "").indexOf("expansions/stages/") != 0)
                  {
                     ExpansionResourceLog.rmLog("[ResourceManager] Stage folder id collides with stock resource: " + id);
                     continue;
                  }
                  if(!existing)
                  {
                     stageType = 6;
                     try
                     {
                        ResCls = EngineRefs.ssf2("util.Resource");
                        if(ResCls && "STAGE_EXPANSION" in ResCls)
                        {
                           stageType = int(ResCls.STAGE_EXPANSION);
                        }
                     }
                     catch(typeErr:*)
                     {
                     }
                     tmp = new Resource(id,rel,rel,"",stageType);
                     tmp.SoftFail = true;
                     ResourceManager.addResource(tmp);
                     ExpansionResourceLog.rmLog("[ResourceManager] Discovered stage expansion: " + id + " (" + rel + ")");
                  }
                  preview = folder.resolvePath("stagepreview.png");
                  name = info.name;
                  entry = {
                     "id":id,
                     "name":name,
                     "file":rel,
                     "preview":preview.exists ? preview : null,
                     "enabled":true
                  };
                  m_stageById[id] = entry;
                  ResourceManager.m_stageExpansions.push(entry);
                  injectStageMapping(id,name,rel);
               }
               catch(folderErr:Error)
               {
                  ExpansionResourceLog.rmLog("[ResourceManager] Stage folder failed " + (folder ? folder.name : "?") + ": " + folderErr.message);
               }
            }
         }
         catch(err:Error)
         {
            ExpansionResourceLog.rmLog("[ResourceManager] Stage expansion discovery failed: " + err.message);
         }
      }

      public static function readStageExpansionName(file:File, fallback:String) : String
      {
         var info:Object = readStageExpansionInfo(file,fallback);
         return info.name;
      }

      private static function isValidStageFolderId(id:String) : Boolean
      {
         var i:int = 0;
         var ch:String = null;
         if(!id || id.length < 1)
         {
            return false;
         }
         ch = id.charAt(0);
         if(ch < "A" || ch > "z" || ch > "Z" && ch < "a")
         {
            return false;
         }
         i = 1;
         while(i < id.length)
         {
            ch = id.charAt(i);
            i++;
            if(!(ch >= "A" && ch <= "Z" || ch >= "a" && ch <= "z" || ch >= "0" && ch <= "9" || ch == "_"))
            {
               return false;
            }
         }
         return true;
      }

      private static function pickStageExpansionSwf(folder:File, id:String) : File
      {
         var preferred:File = null;
         var files:Array = null;
         var i:int = 0;
         var file:File = null;
         var lower:String = null;
         preferred = folder.resolvePath(id + ".swf");
         if(preferred.exists)
         {
            return preferred;
         }
         files = folder.getDirectoryListing();
         i = 0;
         while(i < files.length)
         {
            file = files[i] as File;
            i++;
            if(!file || file.isDirectory)
            {
               continue;
            }
            lower = file.name.toLowerCase();
            if(lower.length >= 4 && lower.substr(lower.length - 4) == ".swf")
            {
               ExpansionResourceLog.rmLog("[ResourceManager] Stage " + id + " using " + file.name + " (expected " + id + ".swf)");
               return file;
            }
         }
         return null;
      }

      private static function readStageExpansionInfo(file:File, fallback:String) : Object
      {
         var stream:FileStream = null;
         var text:String = null;
         var parsed:Object = null;
         var raw:* = undefined;
         var name:String = fallback;
         var enabled:Boolean = true;
         var id:String = fallback;
         if(file && file.exists)
         {
            try
            {
               stream = new FileStream();
               stream.open(file,FileMode.READ);
               text = stream.readUTFBytes(stream.bytesAvailable);
               stream.close();
               parsed = JSON.parse(text);
               if(parsed && parsed.name)
               {
                  name = String(parsed.name);
               }
               if(parsed && parsed.id)
               {
                  id = String(parsed.id);
               }
               if(parsed && parsed.enabled != null)
               {
                  raw = parsed.enabled;
                  enabled = !(raw === false || String(raw).toLowerCase() == "false" || String(raw) == "0" || String(raw).toLowerCase() == "off");
               }
            }
            catch(err:Error)
            {
            }
         }
         return {
            "name":name,
            "enabled":enabled,
            "id":id
         };
      }

      private static function injectStageMapping(id:String, name:String, rel:String) : void
      {
         var mappings:Object = null;
         var MenuCls:* = undefined;
         try
         {
            mappings = ResourceManager.getResourceByID("mappings").getProp("metadata");
         }
         catch(mapErr:Error)
         {
            mappings = null;
         }
         if(mappings)
         {
            if(!mappings.stage)
            {
               mappings.stage = {};
            }
            if(!mappings.stage[id])
            {
               mappings.stage[id] = {
                  "name":name,
                  "file":rel,
                  "file_pub":rel
               };
            }
            else if(!mappings.stage[id].name)
            {
               mappings.stage[id].name = name;
            }
         }
         try
         {
            MenuCls = EngineRefs.ssf2("menus.StageSelectMenu");
            if(MenuCls && MenuCls.rememberStageName is Function)
            {
               MenuCls.rememberStageName(id,name);
            }
         }
         catch(nameErr:Error)
         {
         }
      }

      public static function makeStageSelectClip(id:String) : MovieClip
      {
         var icon:MovieClip = null;
         var entry:Object = null;
         var w:Number = 48;
         var h:Number = 36;
         var size:Object = null;
         var mappings:Object = null;
         icon = new MovieClip();
         icon.stageID = id;
         icon.mouseChildren = false;
         try
         {
            mappings = ResourceManager.getResourceByID("mappings").getProp("metadata");
            size = mappings && mappings.stage_select_screen && mappings.stage_select_screen.normal ? mappings.stage_select_screen.normal.icon_size : null;
            if(size)
            {
               if(Number(size.width) > 0)
               {
                  w = Number(size.width);
               }
               if(Number(size.height) > 0)
               {
                  h = Number(size.height);
               }
            }
         }
         catch(sizeErr:Error)
         {
         }
         icon.graphics.beginFill(2763306);
         icon.graphics.drawRoundRect(-w * 0.5,-h * 0.5,w,h,4,4);
         icon.graphics.endFill();
         entry = m_stageById[id];
         if(entry && entry.preview is File && File(entry.preview).exists)
         {
            paintStagePreview(icon,File(entry.preview),w,h);
         }
         return icon;
      }

      private static function paintStagePreview(icon:MovieClip, file:File, w:Number, h:Number) : void
      {
         var stream:FileStream = null;
         var bytes:ByteArray = null;
         var loader:Loader = null;
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
               var bmp:Bitmap = loader.content as Bitmap;
               if(!bmp)
               {
                  return;
               }
               bmp.smoothing = true;
               bmp.width = w;
               bmp.height = h;
               bmp.x = -w * 0.5;
               bmp.y = -h * 0.5;
               icon.addChild(bmp);
            });
            loader.loadBytes(bytes);
         }
         catch(err:Error)
         {
         }
      }

      public static function applyBigStagePreview(previewer:MovieClip, stageId:String) : void
      {
         var stock:DisplayObject = null;
         var overlay:MovieClip = null;
         var entry:Object = null;
         var w:Number = 220;
         var h:Number = 140;
         var ox:Number = 0;
         var oy:Number = 0;
         if(!previewer)
         {
            return;
         }
         clearBigStagePreview(previewer);
         if(!isExpansionStageId(stageId))
         {
            return;
         }
         stock = previewer.getChildByName("mc");
         if(stock)
         {
            if(stock.width > 8)
            {
               w = stock.width;
            }
            if(stock.height > 8)
            {
               h = stock.height;
            }
            ox = stock.x;
            oy = stock.y;
            stock.visible = false;
         }
         overlay = new MovieClip();
         overlay.name = "expPreview";
         overlay.mouseEnabled = false;
         overlay.mouseChildren = false;
         overlay.x = ox;
         overlay.y = oy;
         overlay.graphics.beginFill(2763306);
         overlay.graphics.drawRoundRect(-w * 0.5,-h * 0.5,w,h,4,4);
         overlay.graphics.endFill();
         entry = m_stageById[stageId];
         if(entry && entry.preview is File && File(entry.preview).exists)
         {
            paintStagePreview(overlay,File(entry.preview),w,h);
         }
         previewer.addChild(overlay);
      }

      public static function clearBigStagePreview(previewer:MovieClip) : void
      {
         var overlay:DisplayObject = null;
         var stock:DisplayObject = null;
         if(!previewer)
         {
            return;
         }
         overlay = previewer.getChildByName("expPreview");
         if(overlay && overlay.parent)
         {
            overlay.parent.removeChild(overlay);
         }
         stock = previewer.getChildByName("mc");
         if(stock)
         {
            stock.visible = true;
         }
      }

      public static function ensureStageClip(id:String) : MovieClip
      {
         var linkage:String = null;
         var clip:MovieClip = null;
         var res:Resource = null;
         var cls:Class = null;
         var domain:* = undefined;
         if(!id)
         {
            ExpansionResourceLog.rmLog("[GameController] startMatch: missing stage id");
            return new MovieClip();
         }
         linkage = "stage_" + id;
         try
         {
            clip = ResourceManager.getLibraryMC(linkage);
            if(clip)
            {
               return clip;
            }
         }
         catch(firstErr:*)
         {
         }
         ExpansionResourceLog.rmLog("[GameController] startMatch: missing linkage " + linkage);
         try
         {
            if(ResourceManager.resourceCache && ResourceManager.resourceCache[linkage])
            {
               ResourceManager.resourceCache[linkage] = null;
            }
         }
         catch(cacheErr:*)
         {
         }
         res = ResourceManager.getResourceByID(id) as Resource;
         if(res && res.Loaded)
         {
            try
            {
               if(!ResourceManager.resourcesHash[id])
               {
                  ResourceManager.resourcesHash[id] = res;
                  ResourceManager.resources.push(res);
               }
            }
            catch(hashErr:*)
            {
            }
         }
         if(res && res.Loaded && res.MC && res.MC.loaderInfo)
         {
            try
            {
               domain = res.MC.loaderInfo.applicationDomain;
               if(domain && domain.hasDefinition(linkage))
               {
                  cls = domain.getDefinition(linkage) as Class;
                  if(cls)
                  {
                     clip = new cls() as MovieClip;
                     if(clip)
                     {
                        return clip;
                     }
                  }
               }
            }
            catch(domainErr:*)
            {
            }
         }
         if(isExpansionStageId(id))
         {
            ExpansionResourceLog.rmLog("[GameController] startMatch: expansion " + id + (res && res.Loaded ? " marked loaded but clip missing; retrying" : " not loaded; retrying"));
            try
            {
               clip = ResourceManager.getLibraryMC(linkage);
               if(clip)
               {
                  return clip;
               }
            }
            catch(retryErr:*)
            {
            }
         }
         ExpansionResourceLog.rmLog("[GameController] startMatch: using empty stage clip for " + id);
         return new MovieClip();
      }
   }
}
